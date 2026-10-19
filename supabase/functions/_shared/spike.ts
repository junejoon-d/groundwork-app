/**
 * Spike (wearable aggregator) helpers shared by the `spike-webhook` and `spike-connect` Edge Functions.
 * Pure functions where possible, so scripts/check-spike.mjs can run them from Node.
 *
 * Spike's API (docs.spikeapi.com, read 2026-10-10):
 *   auth      signature = hex(HMAC-SHA256(secret, application_user_id)); POST /v3/auth/hmac -> access_token
 *   webhook   header X-Body-Signature = hex(HMAC-SHA256(webhook secret, RAW request body)); body is an array of events
 *   workouts  GET /v3/queries/workouts?from_timestamp&to_timestamp  (no pagination: page by time window)
 */

export const SPIKE_BASE = 'https://app-api.spikeapi.com/v3';

const hex = (buf: ArrayBuffer) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');

export async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return hex(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message)));
}

/** Constant-time string comparison, so a wrong signature does not leak how much of it was right. */
export function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i += 1) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** True only when the header is the HMAC-SHA256 of the raw body under the shared secret. A missing header is never valid. */
export async function verifyWebhook(secret: string, rawBody: string, header: string | null): Promise<boolean> {
  if (!secret || !header) return false;
  return safeEqual((await hmacHex(secret, rawBody)).toLowerCase(), header.trim().toLowerCase());
}

/** The id Spike knows a person by: their Groundwork user id (1-128 of letters, digits, - _ .). */
export const spikeUserId = (userId: string) => userId;
export const validSpikeUserId = (id: string) => /^[A-Za-z0-9._-]{1,128}$/.test(id);

/** Exchanges the HMAC for an access token that acts as this one person. */
export async function mintToken(applicationId: number, secret: string, userId: string): Promise<string> {
  const response = await fetch(`${SPIKE_BASE}/auth/hmac`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', accept: 'application/json' },
    body: JSON.stringify({ application_id: applicationId, application_user_id: userId, signature: await hmacHex(secret, userId) }),
  });
  if (!response.ok) throw new Error(`Spike auth failed (${response.status})`);
  const { access_token } = (await response.json()) as { access_token?: string };
  if (!access_token) throw new Error('Spike auth returned no token');
  return access_token;
}
