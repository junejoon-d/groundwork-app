/**
 * Edge Function: push-send
 *
 * Drains the push queue (`push_outbox`, migration 0034) to Expo's push service, which hands each message to Apple. It is woken two
 * ways, both by the database: right after something is queued (so a message arrives in about a second) and once a minute (a safety
 * net, and the plan-reminder job). Nobody signed in calls it, so it has no JWT: the caller proves itself with PUSH_DRAIN_SECRET,
 * the same value the database keeps in Vault (migration 0035). Anything else gets 401 and nothing is read.
 *
 * Each run:
 *   1. claims a batch of unsent rows (an atomic claim, so two overlapping runs never send the same one);
 *   2. drops rows for a recipient who has become banned, and finds each recipient's live tokens;
 *   3. sends one message per token, at most 100 per request, and records Expo's ticket for each;
 *   4. marks the row sent, or - when a person has no sendable token - done with a note (that is a normal state, not a failure);
 *   5. checks the receipts of tickets older than 15 minutes and REVOKES a token Apple says is dead (DeviceNotRegistered), rather than
 *      ever retrying it (§2.13).
 * A row Expo rejects for a reason of ours (bad credentials, too big) is marked failed with the reason, and not retried.
 * A row that could not be sent for a passing reason (Expo down, rate limit) is released to be claimed again.
 *
 * Deploy:  supabase functions deploy push-send --no-verify-jwt
 * Secret:  PUSH_DRAIN_SECRET   (SUPABASE_* are provided by the platform)
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';

import { EXPO_RECEIPTS, EXPO_SEND, chunk, classify, plan, resolveRoute, type OutboxRow, type Planned, type Token } from '../_shared/push.ts';
import { safeEqual } from '../_shared/spike.ts';

const BATCH = 100;
const RECLAIM_AFTER_MS = 2 * 60 * 1000;
const RECEIPT_AFTER_MS = 15 * 60 * 1000;

const text = (status: number, body: string) => new Response(body, { status });

Deno.serve(async (request) => {
  if (request.method !== 'POST') return text(405, 'POST only');
  const secret = Deno.env.get('PUSH_DRAIN_SECRET');
  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!secret || !url || !serviceKey) return text(500, 'Not configured');

  const presented = (request.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!presented || !safeEqual(presented, secret)) return text(401, 'Unauthorized');

  const admin = createClient(url, serviceKey);
  const result = { claimed: 0, sent: 0, noToken: 0, banned: 0, failed: 0, released: 0, revoked: 0 };

  // 1. claim
  const stale = new Date(Date.now() - RECLAIM_AFTER_MS).toISOString();
  const { data: candidates } = await admin
    .from('push_outbox')
    .select('id')
    .is('sent_at', null)
    .is('failed_at', null)
    .or(`claimed_at.is.null,claimed_at.lt.${stale}`)
    .order('id')
    .limit(BATCH);
  const ids = (candidates ?? []).map((r) => r.id as number);
  let rows: OutboxRow[] = [];
  if (ids.length > 0) {
    const { data: claimed } = await admin
      .from('push_outbox')
      .update({ claimed_at: new Date().toISOString() })
      .in('id', ids)
      .is('sent_at', null)
      .is('failed_at', null)
      .or(`claimed_at.is.null,claimed_at.lt.${stale}`)
      .select('id, recipient_id, event, title, body, data');
    rows = (claimed ?? []) as OutboxRow[];
  }
  result.claimed = rows.length;

  if (rows.length > 0) {
    // 2. recipients: not banned, and their live tokens
    const recipients = [...new Set(rows.map((r) => r.recipient_id))];
    const { data: users } = await admin.from('users').select('id, is_banned').in('id', recipients);
    const banned = new Set((users ?? []).filter((u) => u.is_banned).map((u) => u.id as string));
    const { data: tokenRows } = await admin.from('push_tokens').select('id, user_id, token').in('user_id', recipients).is('revoked_at', null);
    const tokensByUser = new Map<string, Token[]>();
    for (const t of (tokenRows ?? []) as Token[]) tokensByUser.set(t.user_id, [...(tokensByUser.get(t.user_id) ?? []), t]);

    const sendable = rows.filter((r) => !banned.has(r.recipient_id));
    for (const r of rows.filter((x) => banned.has(x.recipient_id))) {
      await admin.from('push_outbox').update({ failed_at: new Date().toISOString(), last_error: 'recipient is banned' }).eq('id', r.id);
      result.banned += 1;
    }

    // match_approved opens the chat thread: look the threads up now that the match exists.
    const matchIds = sendable.map((r) => r.data?.match_id).filter((m): m is string => typeof m === 'string');
    const threadByMatch = new Map<string, string>();
    if (matchIds.length > 0) {
      const { data: threads } = await admin.from('chat_threads').select('id, match_id').in('match_id', matchIds);
      for (const t of threads ?? []) if (t.match_id) threadByMatch.set(t.match_id as string, t.id as string);
    }

    // 3. send
    const planned: Planned[] = plan(sendable, tokensByUser, (row) => resolveRoute(row.data ?? {}, (m) => threadByMatch.get(m) ?? null));
    const touched = new Set(planned.map((p) => p.outboxId));
    const outcome = new Map<number, 'sent' | 'retry' | 'rejected'>();
    const rejectedWhy = new Map<number, string>();

    for (const batch of chunk(planned)) {
      let tickets: unknown[] = [];
      try {
        const response = await fetch(EXPO_SEND, {
          method: 'POST',
          headers: { 'content-type': 'application/json', accept: 'application/json', 'accept-encoding': 'gzip, deflate' },
          body: JSON.stringify(batch.map((p) => p.message)),
        });
        if (!response.ok) throw new Error(`Expo ${response.status}`);
        tickets = ((await response.json()) as { data?: unknown[] }).data ?? [];
      } catch {
        for (const p of batch) if (!outcome.has(p.outboxId)) outcome.set(p.outboxId, 'retry');
        continue;
      }
      for (let i = 0; i < batch.length; i += 1) {
        const p = batch[i];
        const verdict = classify(tickets[i]);
        if (verdict.kind === 'ok') {
          if (verdict.ticketId) await admin.from('push_tickets').upsert({ ticket_id: verdict.ticketId, outbox_id: p.outboxId, token_id: p.tokenId });
          if (outcome.get(p.outboxId) !== 'rejected') outcome.set(p.outboxId, 'sent');
        } else if (verdict.kind === 'dead') {
          await admin.from('push_tokens').update({ revoked_at: new Date().toISOString() }).eq('id', p.tokenId);
          result.revoked += 1;
          if (!outcome.has(p.outboxId)) outcome.set(p.outboxId, 'sent');
        } else if (verdict.kind === 'retry') {
          if (!outcome.has(p.outboxId)) outcome.set(p.outboxId, 'retry');
        } else {
          outcome.set(p.outboxId, 'rejected');
          rejectedWhy.set(p.outboxId, verdict.reason);
        }
      }
    }

    // 4. record
    const now = new Date().toISOString();
    for (const r of sendable) {
      if (!touched.has(r.id)) {
        await admin.from('push_outbox').update({ sent_at: now, last_error: 'no sendable device' }).eq('id', r.id);
        result.noToken += 1;
        continue;
      }
      const o = outcome.get(r.id);
      if (o === 'sent') {
        await admin.from('push_outbox').update({ sent_at: now, last_error: null }).eq('id', r.id);
        result.sent += 1;
      } else if (o === 'rejected') {
        await admin.from('push_outbox').update({ failed_at: now, last_error: rejectedWhy.get(r.id) ?? 'rejected' }).eq('id', r.id);
        result.failed += 1;
      } else {
        await admin.from('push_outbox').update({ claimed_at: null }).eq('id', r.id); // release: a passing problem, try again next run
        result.released += 1;
      }
    }
  }

  // 5. receipts for tickets old enough to have an answer
  const cutoff = new Date(Date.now() - RECEIPT_AFTER_MS).toISOString();
  const { data: due } = await admin.from('push_tickets').select('ticket_id, token_id').is('checked_at', null).lt('created_at', cutoff).limit(300);
  for (const group of chunk(due ?? [], BATCH)) {
    try {
      const response = await fetch(EXPO_RECEIPTS, {
        method: 'POST',
        headers: { 'content-type': 'application/json', accept: 'application/json' },
        body: JSON.stringify({ ids: group.map((t) => t.ticket_id) }),
      });
      if (!response.ok) continue;
      const receipts = ((await response.json()) as { data?: Record<string, unknown> }).data ?? {};
      for (const t of group) {
        if (!(t.ticket_id in receipts)) continue; // Expo has not got to it yet; look again next run
        if (classify(receipts[t.ticket_id]).kind === 'dead' && t.token_id) {
          await admin.from('push_tokens').update({ revoked_at: new Date().toISOString() }).eq('id', t.token_id);
          result.revoked += 1;
        }
        await admin.from('push_tickets').update({ checked_at: new Date().toISOString() }).eq('ticket_id', t.ticket_id);
      }
    } catch {
      // try again next run
    }
  }

  return new Response(JSON.stringify(result), { status: 200, headers: { 'content-type': 'application/json' } });
});
