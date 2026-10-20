-- Two small server-only helpers for the invite-guardian and account-erase Edge Functions.

-- One row per guardian invitation email sent, so invite-guardian can cap sends per minor over a day.
-- (guardian_invitations.email_sent_at is overwritten on every resend, so it cannot count them.)
create table public.guardian_email_sends (
  id bigint generated always as identity primary key,
  minor_user_id uuid not null references public.users (id) on delete cascade,
  sent_at timestamptz not null default now()
);

create index guardian_email_sends_minor_sent_idx on public.guardian_email_sends (minor_user_id, sent_at desc);

-- Only the service role (the Edge Function, which bypasses RLS) touches it: RLS on, an explicit deny for every client role,
-- and no client grants.
alter table public.guardian_email_sends enable row level security;
alter table public.guardian_email_sends force row level security;
create policy guardian_email_sends_no_client_access on public.guardian_email_sends
  as restrictive for all to public using (false) with check (false);
revoke all on table public.guardian_email_sends from public, anon, authenticated;
grant select, insert, delete on table public.guardian_email_sends to service_role;

comment on table public.guardian_email_sends is 'One row per guardian invitation email, written by invite-guardian to rate-limit sends per minor. Server-only.';

-- Every activity photo path under one person's folder, in one query, so account-erase does not have to walk
-- folders whose layout the person controls. Returns one array rather than a set of rows, so the API's row cap
-- cannot silently cut the list short.
create function public.account_photo_paths(p_auth_id uuid)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(o.name), '{}')
  from storage.objects o
  where o.bucket_id = 'activity-photos'
    and o.name like p_auth_id::text || '/%';
$$;

revoke all on function public.account_photo_paths(uuid) from public, anon, authenticated;
grant execute on function public.account_photo_paths(uuid) to service_role;

comment on function public.account_photo_paths(uuid) is 'Activity photo paths owned by one auth user, for account-erase. Service role only.';
