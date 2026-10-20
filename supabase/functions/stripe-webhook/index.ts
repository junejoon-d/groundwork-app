/**
 * Edge Function: stripe-webhook
 *
 * Receives Stripe's identity.verification_session.* events and applies them through public.apply_identity_result - the ONLY thing that can
 * make an account an adult (brief 2.8). One purpose, nothing else: payment events and anything unrecognised are acknowledged and ignored.
 *
 *   1. Verify Stripe-Signature (HMAC-SHA256 of "<t>.<raw body>", 5 minute window) BEFORE parsing. A forged request does nothing.
 *   2. verified: read the session ONCE with the restricted key, expanding verified_outputs.dob, work out adult / minor / inconclusive,
 *      and write only that word. The date of birth is never logged, stored, or returned; it does not leave this function.
 *   3. requires_input / canceled: recorded; nothing about the person changes.
 *   4. Answer 200 once the signature is good and the event is understood (or not ours); 500 when WE could not finish, so Stripe retries.
 *
 * Deploy:  supabase functions deploy stripe-webhook --no-verify-jwt     (Stripe cannot send a Supabase JWT)
 * Secrets: STRIPE_WEBHOOK_SIGNING_SECRET, STRIPE_RESTRICTED_IDENTITY_KEY
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';

import { STRIPE_BASE, ageOutcome, parseSessionEvent, verifyStripeSignature } from '../_shared/stripe.ts';

const text = (status: number, body: string) => new Response(body, { status });

Deno.serve(async (request) => {
  if (request.method !== 'POST') return text(405, 'POST only');

  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const signingSecret = Deno.env.get('STRIPE_WEBHOOK_SIGNING_SECRET');
  const restrictedKey = Deno.env.get('STRIPE_RESTRICTED_IDENTITY_KEY');
  if (!url || !serviceKey || !signingSecret || !restrictedKey) return text(500, 'Not configured');

  const raw = await request.text();
  if (!(await verifyStripeSignature(signingSecret, raw, request.headers.get('Stripe-Signature'), Math.floor(Date.now() / 1000)))) {
    return text(401, 'Invalid signature');
  }

  const event = parseSessionEvent(raw);
  if (event.kind === 'ignore') return text(200, 'ignored');

  const admin = createClient(url, serviceKey);

  let ageResult: 'adult' | 'minor' | 'inconclusive' | null = null;
  if (event.kind === 'verified') {
    const response = await fetch(`${STRIPE_BASE}/v1/identity/verification_sessions/${event.sessionId}?expand[]=verified_outputs.dob`, {
      headers: { Authorization: `Bearer ${restrictedKey}` },
    });
    if (!response.ok) return text(500, 'Could not read the verification'); // Stripe retries
    const session = await response.json().catch(() => null);
    // Only the derived word survives this line; the date itself is dropped with the object.
    ageResult = ageOutcome(session?.verified_outputs?.dob, new Date());
  }

  const { error } = await admin.rpc('apply_identity_result', {
    p_session_id: event.sessionId,
    p_status: event.kind,
    p_age_result: ageResult,
  });
  if (error) {
    // A session we never recorded (another integration on the account, or a test event) is not our problem and must not be retried forever.
    if (error.code === 'P0002') return text(200, 'unknown session');
    return text(500, 'Could not record the result');
  }
  return text(200, 'ok');
});
