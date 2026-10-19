/**
 * Edge Function: invite-guardian
 *
 * Mints a single-use token for the calling minor's pending guardian invitation and EMAILS it to the
 * guardian. Amended 2026-10-06 (migration 0013): brief §15.2 said email AND text, but the guardian's
 * phone number was typed in by the minor, and the guardian had not agreed to be texted. The guardian
 * is now texted only if they opt in themselves on the landing page (function guardian-sms-optin).
 * The message names the minor, states plainly what the app does — including that it arranges in-person
 * training meetups — and does not require the guardian to install anything to read it.
 *
 * This is a server function rather than an RPC for two reasons. The raw token must never
 * reach the minor's device — the database stores only its SHA-256 hash, so the plaintext
 * exists solely in the email. And the SendGrid credentials are a server-side secret that would
 * otherwise have to ship in the app bundle.
 *
 * Deploy:  supabase functions deploy invite-guardian
 * Secrets: supabase secrets set SENDGRID_API_KEY=… SENDGRID_FROM_EMAIL=… \
 *            APP_LINK_BASE=https://junejoon-d.github.io/groundwork-site/guardian/
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

/** SHA-256 hex, matching encode(sha256(...), 'hex') in migration 0002. */
async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

async function sendEmail(to: string, minorName: string, link: string): Promise<boolean> {
  const apiKey = Deno.env.get('SENDGRID_API_KEY');
  const from = Deno.env.get('SENDGRID_FROM_EMAIL');
  if (!apiKey || !from) return false;

  const body =
    `${minorName} has signed up for Groundwork and listed you as their parent or guardian.\n\n` +
    `Groundwork helps people find others nearby to train with — runs, gym sessions, rides. ` +
    `Those sessions happen in person, so we don't let anyone under 18 use it without a ` +
    `parent or guardian agreeing first.\n\n` +
    `To confirm, open this link:\n${link}\n\n` +
    `You'll be asked to confirm your identity, and then shown exactly what you're agreeing ` +
    `to. You'll be able to see who ${minorName} connects with, read any conversation ` +
    `between them and an adult, and pause their account at any time.\n\n` +
    `On that page you can also choose to receive text message updates about this account. ` +
    `That is optional, and we will not text you unless you ask us to.\n\n` +
    `This link works once and expires in 14 days. If you weren't expecting this, you can ` +
    `ignore it — the account stays locked until someone confirms.`;

  const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      personalizations: [{ to: [{ email: to }] }],
      from: { email: from, name: 'Groundwork' },
      subject: `${minorName} needs your OK to use Groundwork`,
      content: [{ type: 'text/plain', value: body }],
    }),
  });
  return response.ok;
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  const authorization = request.headers.get('Authorization');
  if (!authorization) {
    return new Response(JSON.stringify({ error: 'Not signed in.' }), {
      status: 401,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  const url = Deno.env.get('SUPABASE_URL')!;

  // Identify the caller from their own token. The service-role client below is used only
  // for the token write, and never to decide WHO is asking.
  const asCaller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: caller } = await asCaller.auth.getUser();
  if (!caller?.user) {
    return new Response(JSON.stringify({ error: 'Not signed in.' }), {
      status: 401,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  const { data: user } = await admin
    .from('users')
    .select('id, age_status, consent_status')
    .eq('auth_id', caller.user.id)
    .maybeSingle();

  // Only a minor still awaiting consent may trigger this, so the endpoint cannot be used
  // to send mail to arbitrary addresses.
  if (!user || user.age_status !== 'minor' || user.consent_status === 'granted') {
    return new Response(JSON.stringify({ error: 'No pending invitation for this account.' }), {
      status: 403,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  const { data: invitation } = await admin
    .from('guardian_invitations')
    .select('id, guardian_first_name, guardian_email')
    .eq('minor_user_id', user.id)
    .is('accepted_at', null)
    .is('superseded_at', null)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!invitation) {
    return new Response(JSON.stringify({ error: 'No pending invitation for this account.' }), {
      status: 404,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  const { data: profile } = await admin
    .from('profiles')
    .select('display_name')
    .eq('user_id', user.id)
    .maybeSingle();
  const minorName = profile?.display_name ?? 'A young person you know';

  // Mint the token, store only its hash, and keep the plaintext for the messages alone.
  const token = crypto.randomUUID() + crypto.randomUUID().replaceAll('-', '');
  await admin
    .from('guardian_invitations')
    .update({ token_hash: await sha256Hex(token) })
    .eq('id', invitation.id);

  const base = Deno.env.get('APP_LINK_BASE') ?? 'https://junejoon-d.github.io/groundwork-site/guardian/';
  const link = `${base}?token=${token}`;

  const emailSent = await sendEmail(invitation.guardian_email, minorName, link).catch(() => false);

  const now = new Date().toISOString();
  await admin
    .from('guardian_invitations')
    .update({
      ...(emailSent ? { email_sent_at: now } : {}),
    })
    .eq('id', invitation.id);

  return new Response(JSON.stringify({ emailSent }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
});
