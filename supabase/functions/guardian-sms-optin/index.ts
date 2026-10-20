/**
 * Edge Function: guardian-sms-optin
 *
 * The ONLY way a guardian phone number enters the database (migration 0013). The guardian opens the
 * emailed link, ticks an unchecked box on the landing page, and types THEIR OWN number. This function
 * records that consent and sends one confirmation text.
 *
 * Who is calling: nobody is signed in — a guardian has no account yet. The credential is the
 * single-use invitation token that only the guardian received by email; its SHA-256 hash is the lookup
 * key, exactly as in claim_guardian_invitation. So the function can only ever text the person who holds
 * the invitation, and only once per invitation (the update refuses a row that already has consent).
 *
 * It cannot be used to text arbitrary numbers: no token, no row, no send.
 *
 * If texting is not configured (campaign not yet approved, secrets unset) it stores NOTHING and says
 * so — consent is never recorded for a message that cannot be delivered. If the confirmation fails to
 * send, the consent it just recorded is withdrawn for the same reason.
 *
 * Deploy:  supabase functions deploy guardian-sms-optin --no-verify-jwt
 *          (no JWT: the guardian is not a user; the token is the credential, checked below.)
 * Secrets: TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type',
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

/** US mobile numbers only — the registered campaign is US 10DLC. Returns +1XXXXXXXXXX or null. */
function normalizeUsNumber(raw: string): string | null {
  const digits = raw.replace(/\D/g, '');
  const ten = digits.length === 11 && digits.startsWith('1') ? digits.slice(1) : digits;
  return /^[2-9]\d{2}[2-9]\d{6}$/.test(ten) ? `+1${ten}` : null;
}

async function sendConfirmation(to: string, minorName: string): Promise<boolean> {
  const sid = Deno.env.get('TWILIO_ACCOUNT_SID');
  const token = Deno.env.get('TWILIO_AUTH_TOKEN');
  const from = Deno.env.get('TWILIO_FROM_NUMBER');
  if (!sid || !token || !from) return false;

  // Must match the sample message registered for the 10DLC campaign. Brand first, STOP/HELP last.
  const message =
    `Groundwork by Danny Chong: You're signed up for text updates about ${minorName}'s Groundwork ` +
    `account. We'll text you only about this account. Message and data rates may apply. ` +
    `Reply STOP to opt out, HELP for help.`;

  const response = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${btoa(`${sid}:${token}`)}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({ To: to, From: from, Body: message }),
  });
  return response.ok;
}

const textingConfigured = () =>
  Boolean(
    Deno.env.get('TWILIO_ACCOUNT_SID') && Deno.env.get('TWILIO_AUTH_TOKEN') && Deno.env.get('TWILIO_FROM_NUMBER')
  );

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (request.method !== 'POST') return json(405, { error: 'POST only.' });

  let body: { token?: unknown; phone?: unknown; consent?: unknown };
  try {
    body = await request.json();
  } catch {
    return json(400, { error: 'Bad request.' });
  }

  // The box must be ticked. The page enforces it too, but the record of consent is made here.
  if (body.consent !== true) return json(400, { error: 'Please tick the box to agree to receive texts.' });

  const token = typeof body.token === 'string' ? body.token : '';
  if (!/^[0-9a-f-]{32,100}$/i.test(token)) {
    return json(400, { error: 'This link looks incomplete. Please use the link exactly as it arrived.' });
  }

  const phone = typeof body.phone === 'string' ? normalizeUsNumber(body.phone) : null;
  if (!phone) return json(400, { error: 'Please enter a US mobile number, for example 703 555 0123.' });

  if (!textingConfigured()) {
    return json(503, { error: 'Text updates are not available yet. Nothing has been saved. You can still approve by email.' });
  }

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const tokenHash = await sha256Hex(token);
  const consentAt = new Date().toISOString();

  // One atomic step: only a live, unclaimed invitation that has NOT already opted in will match.
  const { data: row } = await admin
    .from('guardian_invitations')
    .update({ guardian_phone: phone, guardian_sms_consent_at: consentAt })
    .eq('token_hash', tokenHash)
    .is('accepted_at', null)
    .is('superseded_at', null)
    .is('guardian_sms_consent_at', null)
    .gt('expires_at', consentAt)
    .select('id, minor_user_id')
    .maybeSingle();

  if (!row) {
    return json(404, { error: 'This link is not valid any more, or text updates are already switched on.' });
  }

  const { data: profile } = await admin
    .from('profiles')
    .select('display_name')
    .eq('user_id', row.minor_user_id)
    .maybeSingle();
  const minorName = profile?.display_name ?? 'a young person';

  const sent = await sendConfirmation(phone, minorName).catch(() => false);
  if (!sent) {
    // Withdraw the consent we just recorded: no confirmation reached the guardian.
    await admin
      .from('guardian_invitations')
      .update({ guardian_phone: null, guardian_sms_consent_at: null })
      .eq('id', row.id);
    return json(502, { error: 'We could not send the text. Nothing has been saved. Please check the number and try again.' });
  }

  await admin.from('guardian_invitations').update({ sms_sent_at: new Date().toISOString() }).eq('id', row.id);
  return json(200, { ok: true });
});
