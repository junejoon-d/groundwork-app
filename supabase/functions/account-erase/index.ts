/**
 * Edge Function: account-erase
 *
 * The daily erasure of accounts whose 30-day deletion grace has run out (migration 0042). The database wakes it once a day with a shared
 * secret; it is not callable with a user token. For each due account (at most 20 a run) it removes what lives OUTSIDE Postgres first, and only
 * then asks the database to erase the account, so a failure part-way leaves the account due and tomorrow's run finishes the job:
 *
 *   1. Stripe     redact every Identity verification session the person started (Stripe then deletes the ID photos, selfie and date of birth it
 *                 holds). A temporary Stripe problem (429 / 5xx) skips this account until tomorrow; a session Stripe says does not exist is fine.
 *   2. Storage    delete the person's activity photos (bucket activity-photos, folder <auth id>/).
 *   3. Stream     rename the chat user "Deleted account", remove their picture, and deactivate them so they can no longer connect. Their messages
 *                 stay in the other person's conversation (a founder decision), now attributed to "Deleted account".
 *   4. Postgres   public.erase_account(): deletes the sign-in, which removes everything that cascades from it; messages and reports stay with
 *                 the link to the person cut.
 *
 * NOT done (recorded in docs/decisions.md): deleting the person's data at Spike (the wearable aggregator) - there is no live Spike integration
 * yet, so this must be added when there is.
 *
 * Nothing personal is logged: only counts and the ids of accounts that could not be finished.
 *
 * Deploy:  supabase functions deploy account-erase --no-verify-jwt
 * Secrets: ACCOUNT_ERASE_SECRET (and, if configured, STRIPE_SECRET_KEY, STREAM_API_KEY, STREAM_API_SECRET)
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { StreamChat } from 'npm:stream-chat@9';

import { safeEqual } from '../_shared/spike.ts';
import { STRIPE_BASE } from '../_shared/stripe.ts';

const BUCKET = 'activity-photos';
const text = (status: number, body: unknown) => new Response(typeof body === 'string' ? body : JSON.stringify(body), { status });

type Admin = ReturnType<typeof createClient>;

const PAGE = 1000;

/**
 * Every object path under a folder, however deep (paths look like <auth id>/<log id>/<file>). Pages through each folder, and throws
 * rather than returning a partial list, so an account whose photos cannot all be found stays due instead of being erased around them.
 */
async function listAll(admin: Admin, prefix: string, depth = 0): Promise<string[]> {
  if (depth > 4) throw new Error('storage folders nested deeper than expected');
  const out: string[] = [];
  for (let offset = 0; ; offset += PAGE) {
    const { data, error } = await admin.storage.from(BUCKET).list(prefix, { limit: PAGE, offset });
    if (error || !data) throw new Error('storage list failed');
    for (const entry of data) {
      const path = `${prefix}/${entry.name}`;
      if (entry.id === null) out.push(...(await listAll(admin, path, depth + 1)));
      else out.push(path);
    }
    if (data.length < PAGE) return out;
  }
}

async function removePhotos(admin: Admin, authId: string): Promise<void> {
  const paths = await listAll(admin, authId);
  for (let i = 0; i < paths.length; i += 100) {
    const { error } = await admin.storage.from(BUCKET).remove(paths.slice(i, i + 100));
    if (error) throw new Error('storage remove failed');
  }
}

/** true = done (or nothing to do); false = a temporary problem, try again tomorrow. */
async function redactSessions(admin: Admin, userId: string, stripeKey: string | undefined): Promise<boolean> {
  const { data, error } = await admin.from('verification_records').select('provider_reference_id').eq('user_id', userId);
  if (error) return false; // a failed read is not "no sessions": wait rather than erase without redacting
  const ids = (data ?? []).map((r: { provider_reference_id: string }) => r.provider_reference_id);
  if (ids.length === 0) return true;
  if (!stripeKey) return false; // we cannot promise redaction without the key: wait rather than erase around it
  for (const id of ids) {
    const response = await fetch(`${STRIPE_BASE}/v1/identity/verification_sessions/${id}/redact`, { method: 'POST', headers: { Authorization: `Bearer ${stripeKey}` } });
    if (response.ok || response.status === 404) continue;
    if (response.status === 429 || response.status >= 500) return false;
    // Any other refusal (for example "already redacted") will not change by waiting; do not hold the erasure hostage to it.
  }
  return true;
}

async function anonymiseChatUser(userId: string): Promise<void> {
  const key = Deno.env.get('STREAM_API_KEY');
  const secret = Deno.env.get('STREAM_API_SECRET');
  if (!key || !secret) return;
  const chat = StreamChat.getInstance(key, secret);
  await chat.upsertUser({ id: userId, name: 'Deleted account', image: '' });
  await chat.deactivateUser(userId, { mark_messages_deleted: false });
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return text(405, 'POST only');
  const expected = Deno.env.get('ACCOUNT_ERASE_SECRET');
  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!expected || !url || !serviceKey) return text(500, 'Not configured');
  const given = (request.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!safeEqual(given, expected)) return text(401, 'Unauthorized');

  const admin = createClient(url, serviceKey);
  const { data: due, error } = await admin.rpc('due_account_deletions');
  if (error) return text(500, 'Could not list accounts');

  const stripeKey = Deno.env.get('STRIPE_SECRET_KEY');
  let erased = 0;
  const unfinished: string[] = [];
  for (const account of (due ?? []) as { user_id: string; auth_id: string }[]) {
    try {
      if (!(await redactSessions(admin, account.user_id, stripeKey))) { unfinished.push(account.user_id); continue; }
      await removePhotos(admin, account.auth_id);
      await anonymiseChatUser(account.user_id);
      const { error: eraseError } = await admin.rpc('erase_account', { p_user: account.user_id });
      if (eraseError) { unfinished.push(account.user_id); continue; }
      erased += 1;
    } catch {
      unfinished.push(account.user_id);
    }
  }
  return text(200, { due: (due ?? []).length, erased, unfinished });
});
