/**
 * Edge Function: spike-webhook
 *
 * Receives Spike's webhooks (brief §2.12) and turns completed workouts into activity_logs rows, UNCONFIRMED, for
 * the person to confirm with "Looks right" in the Log tab. Handles both halves of the integration: Garmin and other
 * cloud providers arrive here directly, and Apple Health arrives here after the phone's Spike SDK uploads it.
 *
 *   1. Verify X-Body-Signature (HMAC-SHA256 of the RAW body under the webhook secret). Anything else is rejected
 *      before it is parsed, so a forged request writes nothing.
 *   2. Log the raw payload (wearable_events) BEFORE parsing — §16.5a: first contact with real Garmin payloads will
 *      surprise us, and the raw log is what turns a surprise into a fixable entry instead of an incident.
 *   3. record_change: re-read the workouts in the event's time window from Spike and ingest each through
 *      public.ingest_wearable_workout, which de-duplicates (same provider id = same row; same workout from another
 *      source within 5 minutes = one row) and range-checks every number.
 *      provider_integration_created / _deleted: keep wearable_connections current.
 *   4. Always answer 200 once the signature is good, even when an individual record could not be parsed: Spike
 *      retries anything else for hours, and one malformed record must never block the rest or loop forever.
 *      A failure to REACH Spike (our side or theirs) answers 500 so Spike retries it.
 *
 * Deploy:  supabase functions deploy spike-webhook --no-verify-jwt     (Spike cannot send a Supabase JWT)
 * Secrets: SPIKE_WEBHOOK_SIGNING_SECRET, SPIKE_API_KEY (the auth HMAC secret), SPIKE_APPLICATION_ID
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';

import { SPIKE_BASE, mintToken, validSpikeUserId, verifyWebhook } from '../_shared/spike.ts';
import { mapWorkout, parseEvents, windowFor, type SpikeEvent } from '../_shared/spike-map.ts';

function text(status: number, body: string): Response {
  return new Response(body, { status });
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return text(405, 'POST only');

  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const webhookSecret = Deno.env.get('SPIKE_WEBHOOK_SIGNING_SECRET');
  const authSecret = Deno.env.get('SPIKE_API_KEY');
  const applicationId = Number(Deno.env.get('SPIKE_APPLICATION_ID'));
  if (!url || !serviceKey || !webhookSecret || !authSecret || !Number.isInteger(applicationId) || applicationId <= 0) {
    return text(500, 'Not configured');
  }

  const raw = await request.text();
  const header = request.headers.get('X-Body-Signature');
  if (!header) return text(400, 'Missing signature');
  if (!(await verifyWebhook(webhookSecret, raw, header))) return text(401, 'Invalid signature');

  const admin = createClient(url, serviceKey);
  const events = parseEvents(raw);

  // Raw first, outcome after.
  let eventRowId: number | null = null;
  try {
    const { data } = await admin.from('wearable_events').insert({ payload: events.length > 0 ? events : { unparsed: raw.slice(0, 20000) } }).select('id').single();
    eventRowId = data?.id ?? null;
  } catch {
    // A logging failure must not stop the sync.
  }

  const outcomes: string[] = [];
  let retry = false;
  for (const event of events) {
    try {
      outcomes.push(await handle(admin, applicationId, authSecret, event));
    } catch (error) {
      retry = true;
      outcomes.push(`error: ${error instanceof Error ? error.message : 'unknown'}`);
    }
  }

  if (eventRowId !== null) {
    await admin.from('wearable_events').update({ outcome: outcomes.join('; ').slice(0, 2000) || 'no events' }).eq('id', eventRowId);
  }
  // Only a failure to reach Spike or our database is worth a retry; a bad record is not.
  return retry ? text(500, 'Try again') : text(200, 'ok');
});

async function handle(admin: ReturnType<typeof createClient>, applicationId: number, authSecret: string, event: SpikeEvent): Promise<string> {
  const userId = event.application_user_id ?? '';
  if (!validSpikeUserId(userId)) return 'skipped: no user';
  // The id is ours (users.id); an id that is not a known account is ignored, never created.
  const { data: user } = await admin.from('users').select('id, is_banned').eq('id', userId).maybeSingle();
  if (!user) return 'skipped: unknown user';
  if (user.is_banned) return 'skipped: banned';

  const slug = typeof event.provider_slug === 'string' ? event.provider_slug.toLowerCase().slice(0, 40) : '';

  if (event.event_type === 'provider_integration_created' && slug) {
    await admin.from('wearable_connections').upsert({ user_id: userId, provider_slug: slug }, { onConflict: 'user_id,provider_slug' });
    return `connected ${slug}`;
  }
  if (event.event_type === 'provider_integration_deleted' && slug) {
    await admin.from('wearable_connections').delete().eq('user_id', userId).eq('provider_slug', slug);
    return `disconnected ${slug}`;
  }
  if (event.event_type !== 'record_change') return `ignored ${event.event_type ?? 'event'}`;

  const range = windowFor(event);
  if (!range) return 'record_change: no usable window';

  const token = await mintToken(applicationId, authSecret, userId);
  const query = new URLSearchParams({ from_timestamp: range.from, to_timestamp: range.to });
  if (slug) query.append('providers', slug);
  const response = await fetch(`${SPIKE_BASE}/queries/workouts?${query}`, { headers: { authorization: `Bearer ${token}`, accept: 'application/json' } });
  if (!response.ok) throw new Error(`Spike workouts ${response.status}`);
  const body = (await response.json()) as { workouts?: unknown[] | null };

  const counts: Record<string, number> = {};
  for (const workout of body.workouts ?? []) {
    const args = mapWorkout(workout, slug);
    if (!args) {
      counts.unusable = (counts.unusable ?? 0) + 1;
      continue;
    }
    const { data, error } = await admin.rpc('ingest_wearable_workout', { p_user_id: userId, ...args });
    // A record the database refuses is counted and skipped: retrying it would only fail the same way for hours.
    const result = error ? 'rejected' : String(data);
    counts[result] = (counts[result] ?? 0) + 1;
  }
  return `record_change ${slug}: ${JSON.stringify(counts)}`;
}
