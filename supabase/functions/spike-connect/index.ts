/**
 * Edge Function: spike-connect
 *
 * The app's only door to Spike. It holds the Spike secret so the phone never does (§5.6): the app asks, the
 * function acts as the signed-in person and as nobody else. Authenticated with the caller's own Supabase JWT.
 *
 *   { action: 'token' }
 *     A Spike access token for THIS person (their Groundwork user id is their Spike id). The phone hands it to the
 *     Spike SDK (createConnectionAPIv3WithAuthToken) to connect Apple Health and upload workouts.
 *
 *   { action: 'init_url', provider: 'garmin', redirect_uri? }
 *     The Spike-hosted page where the person authorizes Garmin (or another cloud provider) once.
 *
 *   { action: 'mark_connected', provider: 'apple' }
 *     Records that Apple Health was connected on the phone (the SDK path does not always send an integration
 *     webhook). Only Apple Health, and only for the caller.
 *
 *   { action: 'disconnect', provider }
 *     Removes the provider at Spike and the connection row. The activities already synced stay.
 *
 * Deploy:  supabase functions deploy spike-connect
 * Secrets: SPIKE_API_KEY (the auth HMAC secret), SPIKE_APPLICATION_ID
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';

import { SPIKE_BASE, mintToken, validSpikeUserId } from '../_shared/spike.ts';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
};
const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });

/** Providers a person may connect. A short allowlist so the app cannot be steered to an arbitrary Spike path. */
const PROVIDERS = new Set(['garmin', 'strava', 'fitbit', 'polar', 'coros', 'suunto', 'whoop', 'oura', 'wahoo', 'apple']);

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (request.method !== 'POST') return json(405, { error: 'POST only' });

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const authSecret = Deno.env.get('SPIKE_API_KEY');
  const applicationId = Number(Deno.env.get('SPIKE_APPLICATION_ID'));
  if (!url || !anonKey || !serviceKey || !authSecret || !Number.isInteger(applicationId) || applicationId <= 0) {
    return json(500, { error: 'Device connections are not set up yet.' });
  }

  const authorization = request.headers.get('Authorization') ?? '';
  if (!authorization.toLowerCase().startsWith('bearer ')) return json(401, { error: 'Sign in first.' });
  const asUser = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data: authData, error: authError } = await asUser.auth.getUser();
  if (authError || !authData.user) return json(401, { error: 'Sign in first.' });

  const admin = createClient(url, serviceKey);
  const { data: me } = await admin.from('users').select('id, is_banned').eq('auth_id', authData.user.id).maybeSingle();
  if (!me || me.is_banned || !validSpikeUserId(me.id)) return json(403, { error: 'This account is suspended.' });

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return json(400, { error: 'Bad request.' });
  }
  const provider = typeof body.provider === 'string' ? body.provider.toLowerCase() : '';

  try {
    if (body.action === 'token') {
      return json(200, { access_token: await mintToken(applicationId, authSecret, me.id), application_id: applicationId });
    }

    if (body.action === 'init_url') {
      if (!PROVIDERS.has(provider) || provider === 'apple') return json(400, { error: 'Unknown provider.' });
      const token = await mintToken(applicationId, authSecret, me.id);
      const query = new URLSearchParams();
      if (typeof body.redirect_uri === 'string' && body.redirect_uri.startsWith('https://')) query.set('redirect_uri', body.redirect_uri);
      const response = await fetch(`${SPIKE_BASE}/providers/${provider}/integration/init_url?${query}`, {
        headers: { authorization: `Bearer ${token}`, accept: 'application/json' },
      });
      if (!response.ok) return json(502, { error: `Couldn’t start the connection (${response.status}).` });
      const { path } = (await response.json()) as { path?: string };
      if (!path || !path.startsWith('https://')) return json(502, { error: 'Couldn’t start the connection.' });
      return json(200, { url: path });
    }

    if (body.action === 'mark_connected') {
      if (provider !== 'apple') return json(400, { error: 'Unknown provider.' });
      await admin.from('wearable_connections').upsert({ user_id: me.id, provider_slug: 'apple' }, { onConflict: 'user_id,provider_slug' });
      return json(200, { ok: true });
    }

    if (body.action === 'disconnect') {
      if (!PROVIDERS.has(provider)) return json(400, { error: 'Unknown provider.' });
      if (provider !== 'apple') {
        const token = await mintToken(applicationId, authSecret, me.id);
        const response = await fetch(`${SPIKE_BASE}/providers/${provider}/integration`, {
          method: 'DELETE',
          headers: { authorization: `Bearer ${token}`, accept: 'application/json' },
        });
        // 404 = already gone at Spike; the row should go too.
        if (!response.ok && response.status !== 404) return json(502, { error: `Couldn’t disconnect (${response.status}).` });
      }
      await admin.from('wearable_connections').delete().eq('user_id', me.id).eq('provider_slug', provider);
      return json(200, { ok: true });
    }
  } catch (error) {
    return json(502, { error: error instanceof Error ? error.message : 'Couldn’t reach the device service.' });
  }
  return json(400, { error: 'Unknown action.' });
});
