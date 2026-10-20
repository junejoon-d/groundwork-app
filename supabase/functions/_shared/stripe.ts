/**
 * Stripe Identity helpers shared by the `identity-start` and `stripe-webhook` Edge Functions (brief 2.8, 2.9).
 * Pure functions where possible, so scripts/check-identity.mjs can run them from Node.
 *
 * What is read from Stripe, and what is kept: the date of birth is read ONCE inside the webhook (restricted key, verifications from the
 * last 48 hours), turned into adult / minor / inconclusive by ageOutcome(), and thrown away. Nothing here logs it, returns it, or stores it.
 */

import { hmacHex, safeEqual } from './spike.ts';

export const STRIPE_BASE = 'https://api.stripe.com';
/** The Identity mobile SDK needs its ephemeral key made under this API version (Stripe docs, "Verify your users' identity documents"). */
export const EPHEMERAL_KEY_API_VERSION = '2020-03-02';

/** Stripe-Signature: "t=<unix>,v1=<hex>[,v1=<hex>...]"; v1 = HMAC-SHA256(secret, `${t}.${rawBody}`). Rejects anything older than 5 minutes. */
export async function verifyStripeSignature(secret: string, rawBody: string, header: string | null, nowSeconds: number, toleranceSeconds = 300): Promise<boolean> {
  if (!secret || !header) return false;
  let timestamp = '';
  const candidates: string[] = [];
  for (const part of header.split(',')) {
    const [key, value] = part.trim().split('=');
    if (key === 't') timestamp = value ?? '';
    else if (key === 'v1' && value) candidates.push(value.toLowerCase());
  }
  const t = Number(timestamp);
  if (!Number.isInteger(t) || candidates.length === 0) return false;
  if (Math.abs(nowSeconds - t) > toleranceSeconds) return false;
  const expected = (await hmacHex(secret, `${timestamp}.${rawBody}`)).toLowerCase();
  return candidates.some((c) => safeEqual(expected, c));
}

export type Dob = { day?: number | null; month?: number | null; year?: number | null } | null | undefined;
export type AgeOutcome = 'adult' | 'minor' | 'inconclusive';

/** 18 or over on `today` (UTC), counting the birthday itself as the day they turn 18. Anything not a real date is inconclusive. */
export function ageOutcome(dob: Dob, today: Date): AgeOutcome {
  if (!dob) return 'inconclusive';
  const { day, month, year } = dob;
  if (!Number.isInteger(day) || !Number.isInteger(month) || !Number.isInteger(year)) return 'inconclusive';
  const d = day as number, m = month as number, y = year as number;
  if (y < 1900 || y > today.getUTCFullYear() || m < 1 || m > 12 || d < 1 || d > 31) return 'inconclusive';
  const real = new Date(Date.UTC(y, m - 1, d));
  if (real.getUTCFullYear() !== y || real.getUTCMonth() !== m - 1 || real.getUTCDate() !== d) return 'inconclusive';
  if (real.getTime() > today.getTime()) return 'inconclusive';
  let years = today.getUTCFullYear() - y;
  const birthdayPassed = today.getUTCMonth() > m - 1 || (today.getUTCMonth() === m - 1 && today.getUTCDate() >= d);
  if (!birthdayPassed) years -= 1;
  return years >= 18 ? 'adult' : 'minor';
}

export type SessionEvent = { kind: 'verified' | 'requires_input' | 'canceled'; sessionId: string } | { kind: 'ignore' };

/** Maps a Stripe event to what we do about it. Only identity.verification_session.* events about a vs_ id matter. */
export function parseSessionEvent(raw: string): SessionEvent {
  let event: { type?: unknown; data?: { object?: { id?: unknown; object?: unknown } } };
  try {
    event = JSON.parse(raw);
  } catch {
    return { kind: 'ignore' };
  }
  const id = event?.data?.object?.id;
  if (typeof id !== 'string' || !/^vs_[A-Za-z0-9_]+$/.test(id)) return { kind: 'ignore' };
  switch (event.type) {
    case 'identity.verification_session.verified':
      return { kind: 'verified', sessionId: id };
    case 'identity.verification_session.requires_input':
      return { kind: 'requires_input', sessionId: id };
    case 'identity.verification_session.canceled':
      return { kind: 'canceled', sessionId: id };
    default:
      return { kind: 'ignore' };
  }
}

/** Stripe wants application/x-www-form-urlencoded with bracketed keys for nesting. */
export function form(params: Record<string, string | number | boolean>): string {
  return Object.entries(params)
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`)
    .join('&');
}
