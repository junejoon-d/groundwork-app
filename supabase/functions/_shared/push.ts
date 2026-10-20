/**
 * Push helpers for the `push-send` Edge Function: build Expo messages from queued rows and classify Expo's answers.
 * Pure, so scripts/check-push.mjs runs them from Node.
 *
 * Expo push API (docs.expo.dev/push-notifications/sending-notifications):
 *   POST https://exp.host/--/api/v2/push/send        body: array of up to 100 messages  -> { data: [ticket, ...] } in the same order
 *   POST https://exp.host/--/api/v2/push/getReceipts body: { ids: [...] }                -> { data: { [id]: receipt } }
 *   ticket / receipt: { status: 'ok', id? } | { status: 'error', message, details: { error: 'DeviceNotRegistered' | ... } }
 */

export const EXPO_SEND = 'https://exp.host/--/api/v2/push/send';
export const EXPO_RECEIPTS = 'https://exp.host/--/api/v2/push/getReceipts';
export const MAX_PER_REQUEST = 100;

export type OutboxRow = { id: number; recipient_id: string; event: string; title: string; body: string; data: Record<string, unknown> };
export type Token = { id: string; user_id: string; token: string };
export type Message = { to: string; title: string; body: string; data: Record<string, unknown>; sound: 'default'; priority: 'high'; channelId: 'default' };
/** Which queued row and which device token a message belongs to, in the same order as the messages. */
export type Planned = { message: Message; outboxId: number; tokenId: string };

/** Expo tokens look like ExponentPushToken[...] (or ExpoPushToken[...]); anything else is not sent. */
export const isExpoToken = (t: string) => /^Expo(nent)?PushToken\[[^\]]+\]$/.test(t);

/**
 * One message per live token. A row for a person with no sendable token produces nothing (the caller marks it done, not failed:
 * "no token" is a normal state). The payload data is passed through untouched except that it can never be missing.
 */
export function plan(rows: OutboxRow[], tokensByUser: Map<string, Token[]>, resolveData: (row: OutboxRow) => Record<string, unknown> = (r) => r.data): Planned[] {
  const out: Planned[] = [];
  for (const row of rows) {
    for (const t of tokensByUser.get(row.recipient_id) ?? []) {
      if (!isExpoToken(t.token)) continue;
      out.push({
        outboxId: row.id,
        tokenId: t.id,
        message: { to: t.token, title: row.title, body: row.body, data: resolveData(row) ?? {}, sound: 'default', priority: 'high', channelId: 'default' },
      });
    }
  }
  return out;
}

export function chunk<T>(items: T[], size = MAX_PER_REQUEST): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

export type Verdict = { kind: 'ok'; ticketId: string | null } | { kind: 'dead' } | { kind: 'retry'; reason: string } | { kind: 'rejected'; reason: string };

/**
 * What Expo said about one send (a ticket) or one delivery (a receipt).
 *   DeviceNotRegistered  the phone no longer wants this app's pushes: revoke the token, never retry.
 *   MessageRateExceeded / a missing or malformed answer  try again later.
 *   anything else (InvalidCredentials, MessageTooBig, ...)  a problem with this message or our setup: do not hammer, record it.
 */
export function classify(answer: unknown): Verdict {
  const a = (answer ?? {}) as { status?: string; id?: string; message?: string; details?: { error?: string } };
  if (a.status === 'ok') return { kind: 'ok', ticketId: typeof a.id === 'string' ? a.id : null };
  if (a.status === 'error') {
    const code = a.details?.error ?? '';
    if (code === 'DeviceNotRegistered') return { kind: 'dead' };
    if (code === 'MessageRateExceeded') return { kind: 'retry', reason: code };
    return { kind: 'rejected', reason: (code || a.message || 'error').slice(0, 200) };
  }
  return { kind: 'retry', reason: 'no usable answer' };
}

/**
 * Turns a queued event's route into what the app opens. `match_approved` opens the chat thread, which only exists once the
 * match is made - so it is looked up when sending (`threadForMatch`), falling back to the Matches tab.
 */
export function resolveRoute(data: Record<string, unknown>, threadForMatch: (matchId: string) => string | null): Record<string, unknown> {
  if (data.route === 'match' && typeof data.match_id === 'string') {
    const thread = threadForMatch(data.match_id);
    return thread ? { route: 'chat', thread_id: thread } : { route: 'matches' };
  }
  return data;
}
