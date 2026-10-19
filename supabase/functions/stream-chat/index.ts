/**
 * Edge Function: stream-chat
 *
 * The only bridge between Postgres and Stream. Postgres is the source of truth for who may talk to
 * whom (brief §5, migration 0011); Stream is the delivery layer. Two actions, both authenticated
 * with the caller's own Supabase JWT:
 *
 *   { action: 'session' }
 *     Mints a short-lived Stream token for the caller and makes Stream match Postgres for every
 *     thread the caller can read: the channel exists, its members are exactly the
 *     rows in thread_participants. Returns the channel ids. (S15: channels and tokens come from
 *     thread_participants, never from anything the client claims.)
 *
 *   { action: 'send', thread_id, type, payload }
 *     Writes the message to Postgres first (the messages CHECK constraint validates its shape, and
 *     only the service role can insert), then relays it to Stream as the sender.
 *
 * Why a dedicated channel type: its permission grants contain read-channel and read-channel-members
 * and NOTHING else, so a client holding a valid Stream token can read and mark as read but cannot
 * post, react, edit or delete. Messages exist only if this function writes them, after Postgres has
 * accepted them. That makes a guardian_observer seat read-only by construction (S29) and stops an
 * archived thread receiving messages from a stale client. (Verified against the live Stream app:
 * `frozen: true` alone does NOT stop a member posting, so it is not relied on.)
 *
 * Known gap, recorded in docs/decisions.md: Stream membership is reconciled when a session is
 * minted, and tokens last one hour. A revocation or ban therefore takes effect in Stream within an
 * hour, not instantly. Postgres is unaffected (RLS applies immediately). Closing the window needs a
 * database webhook calling a reconcile action; it is scheduled with push events (phase 12).
 *
 * Deploy:  supabase functions deploy stream-chat
 * Secrets: STREAM_API_KEY, STREAM_API_SECRET (SUPABASE_* are provided by the platform).
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { StreamChat } from 'npm:stream-chat@9';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
};

const CHANNEL_TYPE = 'gw_thread';
const SYSTEM_USER = 'gw-system';
const TOKEN_TTL_SECONDS = 60 * 60;
const MAX_THREADS = 200;

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

let channelTypeReady = false;

/** Idempotent: creates the read-only channel type on first use and re-asserts its grants. */
async function ensureChannelType(stream: StreamChat): Promise<void> {
  if (channelTypeReady) return;
  try {
    await stream.getChannelType(CHANNEL_TYPE);
  } catch {
    await stream.createChannelType({
      name: CHANNEL_TYPE,
      typing_events: false,
      read_events: true,
      connect_events: false,
      reactions: false,
      replies: false,
      search: false,
      uploads: false,
      url_enrichment: false,
      mutes: false,
      push_notifications: true,
    });
  }
  await stream.updateChannelType(CHANNEL_TYPE, {
    grants: { channel_member: ['read-channel', 'read-channel-members'], user: [], guest: [], anonymous: [] },
  });
  channelTypeReady = true;
}

type Seat = { thread_id: string; user_id: string; role: 'member' | 'guardian_observer' };

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (request.method !== 'POST') return json(405, { error: 'POST only' });

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const streamKey = Deno.env.get('STREAM_API_KEY');
  const streamSecret = Deno.env.get('STREAM_API_SECRET');
  if (!url || !anonKey || !serviceKey || !streamKey || !streamSecret) {
    return json(500, { error: 'Chat is not configured.' });
  }

  const authorization = request.headers.get('Authorization') ?? '';
  if (!authorization.toLowerCase().startsWith('bearer ')) return json(401, { error: 'Sign in first.' });

  // The caller's own client: every read below goes through RLS exactly as the app's would.
  const asUser = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data: authData, error: authError } = await asUser.auth.getUser();
  if (authError || !authData.user) return json(401, { error: 'Sign in first.' });

  const admin = createClient(url, serviceKey);
  const { data: me } = await admin
    .from('users')
    .select('id, is_banned')
    .eq('auth_id', authData.user.id)
    .maybeSingle();
  if (!me || me.is_banned) return json(403, { error: 'This account is suspended.' });

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return json(400, { error: 'Bad request.' });
  }

  const stream = StreamChat.getInstance(streamKey, streamSecret);

  if (body.action === 'session') return session(asUser, admin, stream, me.id);
  if (body.action === 'send') return send(asUser, admin, stream, me.id, body);
  return json(400, { error: 'Unknown action.' });
});

async function session(
  asUser: ReturnType<typeof createClient>,
  admin: ReturnType<typeof createClient>,
  stream: StreamChat,
  myId: string,
): Promise<Response> {
  // RLS decides which threads (and seats) the caller can see; a banned member hides the thread.
  const { data: seatRows, error: seatError } = await asUser
    .from('thread_participants')
    .select('thread_id, user_id, role')
    .limit(MAX_THREADS * 3);
  if (seatError) return json(500, { error: 'Could not load conversations.' });
  const seats = (seatRows ?? []) as Seat[];

  const threadIds = [...new Set(seats.map((s) => s.thread_id))].slice(0, MAX_THREADS);
  const { data: threadRows } = threadIds.length
    ? await asUser.from('chat_threads').select('id, stream_channel_id, archived').in('id', threadIds)
    : { data: [] as { id: string; stream_channel_id: string; archived: boolean }[] };
  const threads = threadRows ?? [];

  // Display names for everyone who appears in those threads, read server-side.
  const userIds = [...new Set(seats.map((s) => s.user_id))];
  const { data: profileRows } = userIds.length
    ? await admin.from('profiles').select('user_id, display_name').in('user_id', userIds)
    : { data: [] as { user_id: string; display_name: string }[] };
  const names = new Map((profileRows ?? []).map((p) => [p.user_id, p.display_name]));

  await ensureChannelType(stream);
  await stream.upsertUsers([
    { id: SYSTEM_USER, name: 'Groundwork' },
    ...userIds.map((id) => ({ id, name: names.get(id) ?? 'Member' })),
  ]);

  for (const thread of threads) {
    const wanted = seats.filter((s) => s.thread_id === thread.id).map((s) => s.user_id);
    const channel = stream.channel(CHANNEL_TYPE, thread.stream_channel_id, {
      members: wanted,
      created_by_id: SYSTEM_USER,
      gw_thread_id: thread.id,
      gw_archived: thread.archived,
    });
    await channel.create();

    // The channel may already exist with a stale member list (a seat added or removed since).
    const { members } = await channel.queryMembers({});
    const have = new Set(members.map((m) => m.user_id).filter((id): id is string => !!id));
    const toAdd = wanted.filter((id) => !have.has(id));
    const toRemove = [...have].filter((id) => !wanted.includes(id));
    if (toAdd.length) await channel.addMembers(toAdd);
    if (toRemove.length) await channel.removeMembers(toRemove);
    await channel.updatePartial({ set: { gw_archived: thread.archived } });
  }

  const token = stream.createToken(myId, Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS);
  return json(200, {
    user_id: myId,
    token,
    expires_in: TOKEN_TTL_SECONDS,
    channels: threads.map((t) => ({
      thread_id: t.id,
      channel_id: t.stream_channel_id,
      archived: t.archived,
      role: seats.find((s) => s.thread_id === t.id && s.user_id === myId)?.role ?? 'guardian_observer',
    })),
  });
}

async function send(
  asUser: ReturnType<typeof createClient>,
  admin: ReturnType<typeof createClient>,
  stream: StreamChat,
  myId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const threadId = typeof body.thread_id === 'string' ? body.thread_id : '';
  const type = typeof body.type === 'string' ? body.type : 'text';
  const payload = body.payload;
  if (!threadId || typeof payload !== 'object' || payload === null || Array.isArray(payload)) {
    return json(400, { error: 'Bad request.' });
  }

  // Must be able to read the thread (RLS) AND hold a full member seat in it.
  const { data: thread } = await asUser
    .from('chat_threads')
    .select('id, stream_channel_id, archived')
    .eq('id', threadId)
    .maybeSingle();
  if (!thread) return json(404, { error: 'Conversation not found.' });

  const { data: seat } = await asUser
    .from('thread_participants')
    .select('role')
    .eq('thread_id', threadId)
    .eq('user_id', myId)
    .maybeSingle();
  if (!seat || seat.role !== 'member') return json(403, { error: 'You cannot post in this conversation.' });
  if (thread.archived) return json(409, { error: 'This conversation is archived.' });

  // Clients may send text, a template share and a session proposal. A check-in nudge is produced by the
  // server when two people near a meetup both opted in (a later phase); letting a client post one would let
  // anyone fake "<name> checked in near you".
  if (type !== 'text' && type !== 'template_share' && type !== 'session_proposal') {
    return json(400, { error: 'That kind of message cannot be sent from the app.' });
  }

  // A session proposal must be the SENDER'S OWN open proposal, addressed to the other person in this thread.
  if (type === 'session_proposal') {
    const proposalId = (payload as { session_proposal_id?: unknown }).session_proposal_id;
    const { data: seatRows } = await admin
      .from('thread_participants')
      .select('user_id')
      .eq('thread_id', threadId)
      .eq('role', 'member');
    const other = (seatRows ?? []).map((r) => r.user_id as string).find((id) => id !== myId);
    const { data: proposal } = typeof proposalId === 'string'
      ? await asUser
          .from('session_proposals')
          .select('proposer_id, recipient_id, status')
          .eq('id', proposalId)
          .maybeSingle()
      : { data: null };
    if (!proposal || proposal.proposer_id !== myId || proposal.recipient_id !== other || proposal.status !== 'proposed') {
      return json(403, { error: 'You can only send your own open proposal to the person you are chatting with.' });
    }
  }

  // A template share may only point at one of the SENDER'S OWN templates. workout_templates is readable
  // only by its owner, so asking as the caller is the ownership test. (The database refuses to reveal a
  // mismatched one to the recipient as well; this stops it being sent at all.)
  if (type === 'template_share') {
    const templateId = (payload as { template_id?: unknown }).template_id;
    const { data: owned } = typeof templateId === 'string'
      ? await asUser.from('workout_templates').select('id').eq('id', templateId).maybeSingle()
      : { data: null };
    if (!owned) return json(403, { error: 'You can only share your own templates.' });
  }

  // Postgres first. The CHECK constraint rejects a malformed or state-carrying payload.
  const { data: row, error: insertError } = await admin
    .from('messages')
    .insert({ thread_id: threadId, sender_id: myId, type, payload })
    .select('id, sent_at')
    .single();
  if (insertError || !row) return json(400, { error: 'That message could not be sent.' });

  const channel = stream.channel(CHANNEL_TYPE, thread.stream_channel_id);
  const text = type === 'text' ? String((payload as { text: unknown }).text) : '';
  await channel.sendMessage({
    id: row.id,
    text,
    user_id: myId,
    gw_type: type,
    gw_payload: type === 'text' ? undefined : payload,
  });

  return json(200, { id: row.id, sent_at: row.sent_at });
}
