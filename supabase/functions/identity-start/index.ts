/**
 * Edge Function: identity-start
 *
 * Starts (or resumes) the signed-in person's Stripe Identity check and hands the phone what the Identity sheet needs: a verification
 * session id and a short-lived ephemeral key secret. The Stripe SECRET key stays here; the phone never sees it.
 *
 * Who may start, how many attempts, and reuse of an unfinished session are decided by the database (identity_check_begin), not here:
 * this function only identifies the caller from their own token and does what the database allows. The outcome of the check does NOT come
 * back through this function - Stripe tells the stripe-webhook function, which is the only thing that can make an account an adult.
 *
 * Deploy:  supabase functions deploy identity-start
 * Secrets: STRIPE_SECRET_KEY
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';

import { EPHEMERAL_KEY_API_VERSION, STRIPE_BASE, form } from '../_shared/stripe.ts';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });

async function stripe(path: string, params: Record<string, string | number | boolean>, key: string, extraHeaders: Record<string, string> = {}) {
  const response = await fetch(`${STRIPE_BASE}${path}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/x-www-form-urlencoded', ...extraHeaders },
    body: form(params),
  });
  const data = await response.json().catch(() => ({}));
  return { ok: response.ok, data };
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (request.method !== 'POST') return json(405, { error: 'POST only.' });

  const authorization = request.headers.get('Authorization');
  if (!authorization) return json(401, { error: 'Not signed in.' });

  const url = Deno.env.get('SUPABASE_URL')!;
  const secretKey = Deno.env.get('STRIPE_SECRET_KEY');
  if (!secretKey) return json(503, { error: 'ID verification isn’t available yet.' });

  const asCaller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: authorization } } });
  const { data: caller } = await asCaller.auth.getUser();
  if (!caller?.user) return json(401, { error: 'Not signed in.' });

  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data: user } = await admin.from('users').select('id').eq('auth_id', caller.user.id).maybeSingle();
  if (!user) return json(403, { error: 'No account for this sign-in.' });

  // The database decides. A guardian who is already an ID-verified adult is marked verified inside this call and told "already_verified".
  const { data: decision, error: beginError } = await admin.rpc('identity_check_begin', { p_user: user.id });
  if (beginError || !decision) return json(500, { error: 'We couldn’t start the check. Please try again.' });
  if (!decision.allowed) return json(200, { ok: false, reason: decision.reason, message: decision.message });

  let sessionId: string | null = decision.reuse_session_id ?? null;
  if (!sessionId) {
    const created = await stripe(
      '/v1/identity/verification_sessions',
      {
        type: 'document',
        'options[document][require_matching_selfie]': true,
        'metadata[user_id]': user.id,
      },
      secretKey
    );
    if (!created.ok || typeof created.data?.id !== 'string') return json(502, { error: 'The verification service didn’t answer. Please try again.' });
    sessionId = created.data.id as string;
    const { error: registerError } = await admin.rpc('identity_check_register', { p_user: user.id, p_session_id: sessionId });
    if (registerError) return json(500, { error: 'We couldn’t start the check. Please try again.' });
  }

  const ephemeral = await stripe('/v1/ephemeral_keys', { verification_session: sessionId }, secretKey, { 'Stripe-Version': EPHEMERAL_KEY_API_VERSION });
  if (!ephemeral.ok || typeof ephemeral.data?.secret !== 'string') return json(502, { error: 'The verification service didn’t answer. Please try again.' });

  return json(200, { ok: true, sessionId, ephemeralKeySecret: ephemeral.data.secret });
});
