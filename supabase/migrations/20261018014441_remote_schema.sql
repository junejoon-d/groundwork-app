-- Baseline of groundwork-pilot as of 2026-10-19, generated from the live catalog (pg_get_functiondef,
-- pg_get_constraintdef, pg_get_indexdef, pg_get_triggerdef, pg_policies, ACLs) because `supabase db pull`
-- needs Docker. It recreates everything in the public and private schemas except the four research
-- tables, which come from the next migration (20261018014442_research_reference_tables), exactly as
-- production applied them.
--
-- Production already has all of this. It must never run there: before this file merges, its version is
-- recorded in supabase_migrations.schema_migrations so the GitHub integration skips it. Preview branches
-- replay it from empty.
--
-- Not included, on purpose:
--   * pg_cron jobs (data in the cron schema, not schema). Production runs: push-minute (* * * * *,
--     private.push_minute), push-tidy (17 3 * * *), checkin-purge (41 3 * * *), account-erasure
--     (30 3 * * *, private.kick_account_erasure + private.purge_old_reports), wearable-events-tidy
--     (23 3 * * *). Leaving them out keeps preview branches from calling Edge Functions every minute.
--   * Vault secrets (push_drain_url, push_drain_secret, account_erase_url, account_erase_secret). Values
--     never belong in the repo; the functions that read them do nothing useful on a preview branch.
--   * Default privileges and owners: preview branches already have Supabase's defaults, which match.

set check_function_bodies = false;

-- The compliance role that trust-and-safety policies are granted to. No login; nobody is a member yet.
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'trust_and_safety') then
    create role trust_and_safety nologin;
  end if;
end $$;

create schema if not exists private;
grant usage on schema private to authenticated;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists "uuid-ossp" with schema extensions;
create extension if not exists pg_stat_statements with schema extensions;
create extension if not exists postgis with schema extensions;
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;

-- ======================================================================
-- Enum types
-- ======================================================================
create type public.activity_provider as enum ('healthkit', 'aggregator', 'strava');

create type public.activity_source as enum ('manual', 'live_gps', 'auto_sync');

create type public.activity_type as enum ('run', 'lift', 'ride', 'other');

create type public.age_declared_by as enum ('self', 'guardian');

create type public.age_status as enum ('unverified', 'minor', 'self_attested_adult', 'adult');

create type public.club_join_source as enum ('discover', 'qr_scan', 'invite_code', 'minor_safe_route');

create type public.consent_status as enum ('not_required', 'pending', 'granted', 'revoked');

create type public.experience_level as enum ('beginner', 'intermediate', 'advanced');

create type public.group_size as enum ('one_to_one', 'small_group', 'team');

create type public.guardian_link_status as enum ('pending', 'active', 'revoked');

create type public.guardian_verification_method as enum ('stripe_identity', 'card_authorization');

create type public.leaderboard_visibility as enum ('off', 'matches_and_clubs', 'public');

create type public.match_source as enum ('discover', 'qr_scan', 'plan_partner');

create type public.match_status as enum ('pending', 'matched', 'declined');

create type public.message_type as enum ('text', 'template_share', 'session_proposal', 'checkin_nudge');

create type public.plan_end_condition as enum ('open_ended', 'after_n_weeks');

create type public.plan_partner_status as enum ('invited', 'confirmed', 'declined');

create type public.plan_recurrence as enum ('one_time', 'recurring');

create type public.proposal_status as enum ('proposed', 'accepted', 'declined', 'superseded');

create type public.report_reason as enum ('harassment', 'violence_safety', 'inappropriate', 'other');

create type public.report_status as enum ('under_review', 'actioned', 'dismissed');

create type public.rsvp_status as enum ('going', 'waitlisted', 'cancelled');

create type public.session_length as enum ('short', 'medium', 'long');

create type public.session_rsvp as enum ('invited', 'confirmed', 'declined');

create type public.session_status as enum ('agreed', 'completed', 'cancelled');

create type public.template_response as enum ('accepted', 'declined');

create type public.template_source as enum ('own', 'received');

create type public.thread_role as enum ('member', 'guardian_observer');

create type public.time_block as enum ('morning', 'midday', 'evening');

-- ======================================================================
-- Composite types
-- ======================================================================
create type private.parsed_set as (exercise text, target_detail text, weight numeric, weight_unit text, reps integer, duration_seconds integer, pace_seconds integer, pace_unit text, distance numeric, distance_unit text);

-- ======================================================================
-- Tables (defaults and constraints are added below, after the functions they use)
-- ======================================================================
create table private.reviewers (
  user_id uuid not null,
  added_at timestamp with time zone not null
);

create table public.activity_logs (
  id uuid not null,
  user_id uuid not null,
  plan_id uuid,
  session_id uuid,
  template_id uuid,
  source public.activity_source not null,
  provider public.activity_provider,
  external_activity_id text,
  activity_type public.activity_type not null,
  other_label text,
  title text not null,
  started_at timestamp with time zone not null,
  ended_at timestamp with time zone,
  duration_seconds integer,
  distance numeric(10,3),
  distance_unit text,
  cadence integer,
  avg_hr integer,
  max_hr integer,
  calories integer,
  notes text not null,
  confirmed boolean not null,
  logged_at timestamp with time zone not null,
  device_provider text
);

create table public.activity_photos (
  id uuid not null,
  activity_log_id uuid not null,
  storage_path text not null,
  created_at timestamp with time zone not null
);

create table public.activity_sets (
  id uuid not null,
  activity_log_id uuid not null,
  "position" integer not null,
  exercise text not null,
  detail text not null,
  weight numeric(7,2),
  weight_unit text not null,
  reps integer,
  duration_seconds integer,
  pace_seconds integer,
  pace_unit text,
  distance numeric(10,3),
  distance_unit text
);

create table public.availability (
  profile_id uuid not null,
  day_of_week smallint not null,
  time_block public.time_block not null
);

create table public.chat_threads (
  id uuid not null,
  match_id uuid,
  stream_channel_id text generated always as (('gw_'::text || replace((id)::text, '-'::text, ''::text))) stored,
  archived boolean not null,
  created_at timestamp with time zone not null
);

create table public.checkin_locations (
  id uuid not null,
  session_id uuid not null,
  user_id uuid not null,
  lat double precision not null,
  lng double precision not null,
  recorded_at timestamp with time zone not null,
  purge_after timestamp with time zone not null
);

create table public.checkin_nudges (
  session_id uuid not null,
  thread_id uuid,
  near_label text,
  created_at timestamp with time zone not null
);

create table public.club_event_rsvps (
  club_event_id uuid not null,
  user_id uuid not null,
  status public.rsvp_status not null,
  waitlist_position integer,
  created_at timestamp with time zone not null
);

create table public.club_events (
  id uuid not null,
  club_id uuid not null,
  title text not null,
  starts_at timestamp with time zone not null,
  timezone text not null,
  location_label text not null,
  capacity integer,
  created_by uuid not null,
  cancelled_at timestamp with time zone,
  created_at timestamp with time zone not null
);

create table public.club_leaderboard_opt_outs (
  club_id uuid not null,
  user_id uuid not null,
  created_at timestamp with time zone not null
);

create table public.club_memberships (
  club_id uuid not null,
  user_id uuid not null,
  joined_via public.club_join_source not null,
  joined_at timestamp with time zone not null
);

create table public.clubs (
  id uuid not null,
  name text not null,
  description text not null,
  organizer_label text not null,
  qr_code text not null,
  organizer_id uuid not null,
  show_leaderboard boolean not null,
  created_at timestamp with time zone not null
);

create table public.custom_tags (
  id uuid not null,
  label text not null,
  created_by uuid,
  first_seen_at timestamp with time zone not null,
  usage_count integer not null
);

create table public.discover_filter_state (
  user_id uuid not null,
  filter_state jsonb not null,
  updated_at timestamp with time zone not null
);

create table public.filter_presets (
  id uuid not null,
  user_id uuid not null,
  name text not null,
  filter_state jsonb not null,
  created_at timestamp with time zone not null
);

create table public.guardian_connection_approvals (
  id uuid not null,
  match_id uuid not null,
  guardian_link_id uuid not null,
  minor_user_id uuid not null,
  status text not null,
  created_at timestamp with time zone not null,
  decided_at timestamp with time zone
);

create table public.guardian_invitations (
  id uuid not null,
  minor_user_id uuid not null,
  token_hash text not null,
  guardian_first_name text not null,
  guardian_last_name text not null,
  guardian_email text not null,
  guardian_phone text,
  created_at timestamp with time zone not null,
  email_sent_at timestamp with time zone,
  sms_sent_at timestamp with time zone,
  accepted_at timestamp with time zone,
  expires_at timestamp with time zone not null,
  superseded_at timestamp with time zone,
  guardian_phone_hint text generated always as (('••• ••• '::text || "right"(guardian_phone, 4))) stored,
  guardian_sms_consent_at timestamp with time zone
);

create table public.guardian_links (
  id uuid not null,
  guardian_id uuid not null,
  minor_user_id uuid not null,
  status public.guardian_link_status not null,
  invited_at timestamp with time zone not null,
  consented_at timestamp with time zone,
  revoked_at timestamp with time zone,
  adult_connections_allowed boolean not null,
  per_connection_approval_required boolean not null
);

create table public.guardians (
  id uuid not null,
  user_id uuid not null,
  first_name text not null,
  last_name text not null,
  email text not null,
  phone text,
  verified_at timestamp with time zone,
  verification_method public.guardian_verification_method,
  provider_reference_id text,
  created_at timestamp with time zone not null
);

create table public.leaderboard_settings (
  user_id uuid not null,
  visibility public.leaderboard_visibility not null,
  updated_at timestamp with time zone not null
);

create table public.matches (
  id uuid not null,
  requester_id uuid not null,
  recipient_id uuid not null,
  status public.match_status not null,
  source public.match_source not null,
  requested_at timestamp with time zone not null,
  matched_at timestamp with time zone,
  deleted_at timestamp with time zone,
  recipient_confirmed_at timestamp with time zone
);

create table public.messages (
  id uuid not null,
  thread_id uuid not null,
  sender_id uuid,
  type public.message_type not null,
  payload jsonb not null,
  sent_at timestamp with time zone not null
);

create table public.minor_adult_matches (
  id uuid not null,
  minor_user_id uuid not null,
  adult_user_id uuid not null,
  match_id uuid,
  formed_via text not null,
  shared_club_id uuid not null,
  state text not null,
  reviewed boolean not null,
  reviewed_by uuid,
  created_at timestamp with time zone not null
);

create table public.minor_qr_codes (
  user_id uuid not null,
  code text not null,
  issued_at timestamp with time zone not null,
  expires_at timestamp with time zone not null
);

create table public.neighborhoods (
  slug text not null,
  name text not null,
  centroid extensions.geography(Point,4326),
  kind text not null,
  user_added boolean not null,
  created_by uuid,
  hidden_at timestamp with time zone
);

create table public.notification_settings (
  user_id uuid not null,
  plan_reminder_offset_minutes integer not null,
  updated_at timestamp with time zone not null,
  push_enabled boolean not null
);

create table public.plan_partners (
  plan_id uuid not null,
  user_id uuid not null,
  status public.plan_partner_status not null,
  dismissed boolean not null,
  invited_at timestamp with time zone not null
);

create table public.plans (
  id uuid not null,
  owner_id uuid not null,
  activity_type public.activity_type not null,
  other_label text,
  label text not null,
  recurrence public.plan_recurrence not null,
  day_of_week smallint not null,
  start_time time without time zone not null,
  timezone text not null,
  end_condition public.plan_end_condition not null,
  end_after_weeks integer,
  starts_on date not null,
  linked_template_id uuid,
  created_at timestamp with time zone not null,
  place text not null
);

create table public.profile_sports (
  id uuid not null,
  profile_id uuid not null,
  tag text not null,
  is_primary boolean not null,
  created_at timestamp with time zone not null
);

create table public.profiles (
  user_id uuid not null,
  display_name text not null,
  bio text,
  headline_accomplishment text,
  years_training integer,
  weekly_volume text,
  usually_free text,
  training_for text,
  gender text,
  experience_level public.experience_level,
  preferred_group_size public.group_size,
  neighborhood text,
  home_point extensions.geography(Point,4326),
  avatar_url text,
  qr_code text not null,
  id_verified boolean not null,
  photo_verified boolean not null,
  live_map_visible_until timestamp with time zone,
  typical_session_length public.session_length,
  measurement_system text not null
);

create table public.push_outbox (
  id bigint generated always as identity not null,
  recipient_id uuid not null,
  event text not null,
  title text not null,
  body text not null,
  data jsonb not null,
  dedupe_key text not null,
  created_at timestamp with time zone not null,
  claimed_at timestamp with time zone,
  sent_at timestamp with time zone,
  failed_at timestamp with time zone,
  last_error text
);

create table public.push_tickets (
  ticket_id text not null,
  outbox_id bigint not null,
  token_id uuid,
  created_at timestamp with time zone not null,
  checked_at timestamp with time zone
);

create table public.push_tokens (
  id uuid not null,
  user_id uuid not null,
  platform text not null,
  token text not null,
  device_id text,
  created_at timestamp with time zone not null,
  last_seen_at timestamp with time zone not null,
  revoked_at timestamp with time zone
);

create table public.reports (
  id uuid not null,
  reporter_id uuid,
  reported_id uuid,
  reason public.report_reason not null,
  free_text text not null,
  status public.report_status not null,
  reviewer_id uuid,
  action_taken text,
  created_at timestamp with time zone not null,
  resolved_at timestamp with time zone
);

create table public.session_participants (
  session_id uuid not null,
  user_id uuid not null,
  rsvp_status public.session_rsvp not null,
  checkin_opt_in boolean not null,
  checkin_until timestamp with time zone
);

create table public.session_proposals (
  id uuid not null,
  plan_id uuid,
  proposer_id uuid not null,
  recipient_id uuid not null,
  activity_type public.activity_type not null,
  proposed_start timestamp with time zone not null,
  timezone text not null,
  status public.proposal_status not null,
  created_at timestamp with time zone not null,
  resolved_at timestamp with time zone,
  session_id uuid,
  place text not null
);

create table public.sessions (
  id uuid not null,
  plan_id uuid,
  club_event_id uuid,
  activity_type public.activity_type not null,
  starts_at timestamp with time zone not null,
  timezone text not null,
  status public.session_status not null,
  created_by uuid not null,
  occurrence_on date,
  created_at timestamp with time zone not null
);

create table public.tag_match_settings (
  user_id uuid not null,
  match_threshold numeric(3,2) not null,
  suggest_threshold numeric(3,2) not null,
  accepts integer not null,
  rejects integer not null,
  updated_at timestamp with time zone not null
);

create table public.template_sets (
  id uuid not null,
  template_id uuid not null,
  "position" integer not null,
  exercise text not null,
  target_detail text not null,
  weight numeric(7,2),
  reps integer,
  weight_unit text not null,
  duration_seconds integer,
  pace_seconds integer,
  pace_unit text,
  distance numeric(10,3),
  distance_unit text
);

create table public.template_share_responses (
  message_id uuid not null,
  user_id uuid not null,
  response public.template_response not null,
  copied_template_id uuid,
  created_at timestamp with time zone not null
);

create table public.thread_participants (
  thread_id uuid not null,
  user_id uuid not null,
  role public.thread_role not null,
  joined_at timestamp with time zone not null
);

create table public.thread_settings (
  thread_id uuid not null,
  user_id uuid not null,
  messages_muted boolean not null,
  checkin_nudges_muted boolean not null
);

create table public.users (
  id uuid not null,
  auth_id uuid not null,
  email text,
  phone text,
  created_at timestamp with time zone not null,
  age_status public.age_status not null,
  age_status_set_at timestamp with time zone not null,
  birthdate_attested_at timestamp with time zone,
  consent_status public.consent_status not null,
  consent_status_set_at timestamp with time zone not null,
  platform_age_bracket text,
  platform_age_declared_by public.age_declared_by,
  is_banned boolean not null,
  banned_at timestamp with time zone,
  banned_reason text,
  can_organize_clubs boolean not null,
  deletion_requested_at timestamp with time zone
);

create table public.verification_records (
  id uuid not null,
  user_id uuid not null,
  tier text not null,
  provider text not null,
  status text not null,
  provider_reference_id text not null,
  verified_at timestamp with time zone,
  age_check_result text,
  created_at timestamp with time zone not null,
  updated_at timestamp with time zone not null
);

create table public.wearable_connections (
  user_id uuid not null,
  provider_slug text not null,
  connected_at timestamp with time zone not null
);

create table public.wearable_events (
  id bigint generated always as identity not null,
  received_at timestamp with time zone not null,
  payload jsonb not null,
  outcome text
);

create table public.workout_templates (
  id uuid not null,
  owner_id uuid not null,
  name text not null,
  summary text not null,
  activity_type public.activity_type not null,
  source public.template_source not null,
  received_from_user_id uuid,
  created_at timestamp with time zone not null
);

-- ======================================================================
-- Functions
-- ======================================================================
CREATE OR REPLACE FUNCTION private.advance_qr_match(p_match_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  m public.matches%rowtype;
  v_gate jsonb;
  v_approval public.guardian_connection_approvals%rowtype;
begin
  select * into m from public.matches where id = p_match_id and deleted_at is null for update;
  if m.id is null or m.source <> 'qr_scan' or m.status <> 'pending' then return 'none'; end if;
  if m.recipient_confirmed_at is null then return 'awaiting_other'; end if;

  v_gate := private.qr_gate(m.requester_id, m.recipient_id);
  if not (v_gate ->> 'ok')::boolean then
    perform set_config('groundwork.minor_match_gate', 'on', true);
    update public.matches set status = 'declined' where id = m.id;
    perform set_config('groundwork.minor_match_gate', 'off', true);
    return 'declined';
  end if;

  select * into v_approval from public.guardian_connection_approvals where match_id = m.id;
  if v_approval.id is not null then
    if v_approval.status = 'denied' then
      perform set_config('groundwork.minor_match_gate', 'on', true);
      update public.matches set status = 'declined' where id = m.id;
      perform set_config('groundwork.minor_match_gate', 'off', true);
      return 'declined';
    end if;
    if v_approval.status = 'pending' then return 'awaiting_guardian'; end if;
  end if;

  perform set_config('groundwork.minor_match_gate', 'on', true);
  update public.matches set status = 'matched', matched_at = now() where id = m.id;
  perform set_config('groundwork.minor_match_gate', 'off', true);
  perform private.ensure_thread(m.id);
  return 'matched';
end;
$function$
;

CREATE OR REPLACE FUNCTION private.are_live_partners(p_a uuid, p_b uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select exists (
    select 1 from public.matches m
      join public.users ua on ua.id = p_a and not ua.is_banned
      join public.users ub on ub.id = p_b and not ub.is_banned
     where m.status = 'matched' and m.deleted_at is null
       and ((m.requester_id = p_a and m.recipient_id = p_b) or (m.requester_id = p_b and m.recipient_id = p_a))
  );
$function$
;

CREATE OR REPLACE FUNCTION private.ban_on_actioned_report()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if new.status = 'actioned' and old.status is distinct from 'actioned' then
    update public.users
       set is_banned = true,
           banned_at = coalesce(banned_at, now()),
           banned_reason = coalesce(banned_reason, 'report ' || new.id::text)
     where id = new.reported_id;
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.can_read_thread(p_thread_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select exists (
           select 1 from public.thread_participants me
             join public.users u on u.id = me.user_id
            where me.thread_id = p_thread_id
              and me.user_id = private.current_user_id()
              and not u.is_banned)
     and not exists (
           select 1 from public.thread_participants m
             join public.users mu on mu.id = m.user_id
            where m.thread_id = p_thread_id and m.role = 'member' and mu.is_banned);
$function$
;

CREATE OR REPLACE FUNCTION private.checkin_eligible(p_session uuid, p_user uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  s       public.sessions%rowtype;
  v_n     integer;
  v_other uuid;
begin
  select * into s from public.sessions where id = p_session;
  if s.id is null then return 'no_session'; end if;
  if s.status <> 'agreed' then return 'not_agreed'; end if;
  if s.club_event_id is not null then return 'club'; end if;
  if now() > s.starts_at + interval '90 minutes' then return 'ended'; end if;

  select count(*), (array_agg(user_id) filter (where user_id <> p_user))[1] into v_n, v_other
    from public.session_participants where session_id = p_session and rsvp_status = 'confirmed';
  if v_n <> 2 or v_other is null
     or not exists (select 1 from public.session_participants where session_id = p_session and user_id = p_user and rsvp_status = 'confirmed') then
    return 'not_two';
  end if;
  if not private.are_live_partners(p_user, v_other) then return 'not_partners'; end if;
  if exists (select 1 from public.users where id in (p_user, v_other) and (age_status is distinct from 'adult' and age_status is distinct from 'self_attested_adult')) then
    return 'age';
  end if;
  return null;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.clear_plan_partners_between(p_a uuid, p_b uuid)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  delete from public.plan_partners pp
   using public.plans p
   where pp.plan_id = p.id
     and ((p.owner_id = p_a and pp.user_id = p_b) or (p.owner_id = p_b and pp.user_id = p_a));
$function$
;

CREATE OR REPLACE FUNCTION private.club_facts(p_club uuid)
 RETURNS TABLE(user_id uuid, sessions_all integer, reached_all timestamp with time zone, sessions_30 integer, reached_30 timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  with attended as (
    select r.user_id, e.starts_at
      from public.club_events e
      join public.club_event_rsvps r on r.club_event_id = e.id and r.status = 'going'
      join public.club_memberships m on m.club_id = e.club_id and m.user_id = r.user_id
     where e.club_id = p_club and e.cancelled_at is null and e.starts_at <= now()
       and exists (select 1 from public.activity_logs l
                    where l.user_id = r.user_id and l.confirmed
                      and l.started_at between e.starts_at - interval '30 minutes' and e.starts_at + interval '4 hours')
  )
  select user_id,
         count(*)::int,
         max(starts_at),
         (count(*) filter (where starts_at > now() - interval '30 days'))::int,
         max(starts_at) filter (where starts_at > now() - interval '30 days')
    from attended group by user_id;
$function$
;

CREATE OR REPLACE FUNCTION private.completed_together()
 RETURNS TABLE(user_id uuid, other_id uuid, session_id uuid, starts_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select pa.user_id, pb.user_id, s.id, s.starts_at
    from public.sessions s
    join public.session_participants pa on pa.session_id = s.id and pa.rsvp_status = 'confirmed'
    join public.session_participants pb on pb.session_id = s.id and pb.rsvp_status = 'confirmed' and pb.user_id <> pa.user_id
    join public.users ua on ua.id = pa.user_id and not ua.is_banned
    join public.users ub on ub.id = pb.user_id and not ub.is_banned
   where s.status = 'completed';
$function$
;

CREATE OR REPLACE FUNCTION private.current_user_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select id from public.users where auth_id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION private.enforce_match_rules()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_req  record;
  v_rec  record;
  v_gate boolean := coalesce(current_setting('groundwork.minor_match_gate', true), '') = 'on';
begin
  -- Declining, and a soft delete, never create or strengthen a connection.
  if tg_op = 'UPDATE' and new.status = 'declined' then return new; end if;
  if tg_op = 'UPDATE'
     and new.status = old.status
     and new.requester_id = old.requester_id
     and new.recipient_id = old.recipient_id then
    return new;
  end if;

  select age_status, is_banned into v_req from public.users where id = new.requester_id;
  select age_status, is_banned into v_rec from public.users where id = new.recipient_id;

  if v_req is null or v_rec is null then
    raise exception 'Both accounts must exist.' using errcode = 'foreign_key_violation';
  end if;

  -- §5.4: a banned account cannot be a party to a new or advancing match.
  if v_req.is_banned or v_rec.is_banned then
    raise exception 'A suspended account cannot be matched.' using errcode = 'insufficient_privilege';
  end if;

  if not v_gate and (
       v_req.age_status not in ('self_attested_adult', 'adult')
       or v_rec.age_status not in ('self_attested_adult', 'adult')
     ) then
    raise exception
      'A match involving a minor or an unverified account can only be created through the safety gate (build brief 15.9).'
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.enqueue_plan_reminders()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  r      record;
  v_n    integer := 0;
  v_with text;
begin
  for r in
    select pl.id as plan_id, pl.label, pl.timezone, pl.place, nx.start as starts_at, m.uid as user_id,
           coalesce(ns.plan_reminder_offset_minutes, 60) as offset_min
      from public.plans pl
      cross join lateral (select private.plan_next_start(pl) as start) nx
      cross join lateral (
        select pl.owner_id as uid
        union all
        select pp.user_id from public.plan_partners pp where pp.plan_id = pl.id and pp.status = 'confirmed' and not pp.dismissed
      ) m
      left join public.notification_settings ns on ns.user_id = m.uid
     where nx.start is not null and nx.start > now()
       and nx.start - make_interval(mins => coalesce(ns.plan_reminder_offset_minutes, 60)) <= now()
  loop
    select string_agg(private.push_name(o.uid), ', ' order by private.push_name(o.uid)) into v_with
      from (
        select pl.owner_id as uid from public.plans pl where pl.id = r.plan_id
        union
        select pp.user_id from public.plan_partners pp where pp.plan_id = r.plan_id and pp.status = 'confirmed' and not pp.dismissed
      ) o
     where o.uid <> r.user_id and exists (select 1 from public.users u where u.id = o.uid and not u.is_banned);

    perform private.enqueue_push(
      r.user_id, 'plan_reminder', 'Coming up',
      r.label || ' at ' || to_char(r.starts_at at time zone r.timezone, 'FMHH12:MI AM') || coalesce(' with ' || v_with, '') || coalesce(' · ' || nullif(r.place, ''), ''),
      jsonb_build_object('route', 'activity', 'plan_id', r.plan_id),
      'plan_reminder:' || r.plan_id || ':' || r.starts_at::text || ':' || r.user_id);
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.enqueue_push(p_recipient uuid, p_event text, p_title text, p_body text, p_data jsonb, p_dedupe text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if p_recipient is null then return; end if;
  if not exists (select 1 from public.users where id = p_recipient and not is_banned) then return; end if;
  if exists (select 1 from public.notification_settings where user_id = p_recipient and not push_enabled) then return; end if;
  if not exists (select 1 from public.push_tokens where user_id = p_recipient and revoked_at is null) then return; end if;
  insert into public.push_outbox (recipient_id, event, title, body, data, dedupe_key)
  values (p_recipient, p_event, left(p_title, 200), left(p_body, 400), coalesce(p_data, '{}'::jsonb), p_dedupe)
  on conflict (dedupe_key) do nothing;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.ensure_thread(p_match_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_req    uuid;
  v_rec    uuid;
  v_thread uuid;
  v_guard  uuid;
begin
  select requester_id, recipient_id into v_req, v_rec
    from public.matches where id = p_match_id and status = 'matched' and deleted_at is null;
  if v_req is null then
    raise exception 'A thread needs a confirmed, live match.' using errcode = 'no_data_found';
  end if;

  select t.id into v_thread
    from public.chat_threads t
   where exists (select 1 from public.thread_participants a where a.thread_id = t.id and a.role = 'member' and a.user_id = v_req)
     and exists (select 1 from public.thread_participants b where b.thread_id = t.id and b.role = 'member' and b.user_id = v_rec)
   order by t.created_at
   limit 1;

  if v_thread is not null then
    update public.chat_threads set match_id = p_match_id, archived = false where id = v_thread;
  else
    insert into public.chat_threads (match_id) values (p_match_id) returning id into v_thread;
    insert into public.thread_participants (thread_id, user_id, role)
      values (v_thread, v_req, 'member'), (v_thread, v_rec, 'member');
  end if;

  -- Minor <-> adult only. Minor <-> minor threads are NOT guardian-readable.
  if (select (a.age_status = 'minor') <> (b.age_status = 'minor')
        from public.users a, public.users b where a.id = v_req and b.id = v_rec) then
    for v_guard in
      select g.user_id
        from public.guardian_links l
        join public.guardians g on g.id = l.guardian_id
       where l.status = 'active' and l.minor_user_id in (v_req, v_rec)
    loop
      insert into public.thread_participants (thread_id, user_id, role)
        values (v_thread, v_guard, 'guardian_observer')
        on conflict do nothing;
    end loop;
  end if;
  return v_thread;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.is_plan_occurrence(p_plan public.plans, p_on date)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'pg_catalog'
AS $function$
  select p_on is not null
     and p_on >= p_plan.starts_on
     and (case when p_plan.recurrence = 'one_time' then p_on = p_plan.starts_on
               else mod(p_on - p_plan.starts_on, 7) = 0
                    and (p_plan.end_after_weeks is null or p_on <= p_plan.starts_on + 7 * (p_plan.end_after_weeks - 1))
          end);
$function$
;

CREATE OR REPLACE FUNCTION private.is_reviewer()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select exists (
    select 1 from private.reviewers r join public.users u on u.id = r.user_id
     where u.id = private.current_user_id() and not u.is_banned
  );
$function$
;

CREATE OR REPLACE FUNCTION private.kick_account_erasure()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'extensions'
AS $function$
declare
  v_url    text;
  v_secret text;
begin
  select decrypted_secret into v_url    from vault.decrypted_secrets where name = 'account_erase_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'account_erase_secret';
  if v_url is null or v_secret is null then return; end if;
  perform net.http_post(
    url := v_url,
    body := '{}'::jsonb,
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_secret),
    timeout_milliseconds := 50000);
exception when others then
  return; -- tomorrow's run picks it up
end;
$function$
;

CREATE OR REPLACE FUNCTION private.kick_push()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'extensions'
AS $function$
declare
  v_url    text;
  v_secret text;
begin
  select decrypted_secret into v_url    from vault.decrypted_secrets where name = 'push_drain_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'push_drain_secret';
  if v_url is null or v_secret is null then return; end if;
  perform net.http_post(
    url := v_url,
    body := '{}'::jsonb,
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_secret),
    timeout_milliseconds := 20000);
exception when others then
  -- A failure to wake the sender must never fail the insert that queued the notification; the minute job will wake it.
  return;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.leaderboard_no_public_minor()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if new.visibility = 'public'
     and not exists (select 1 from public.users u where u.id = new.user_id and u.age_status in ('self_attested_adult', 'adult')) then
    raise exception 'Public isn''t available for this account.' using errcode = 'check_violation';
  end if;
  new.updated_at := now();
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.leaderboard_public_off_on_downgrade()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if new.age_status not in ('self_attested_adult', 'adult') and old.age_status in ('self_attested_adult', 'adult') then
    update public.leaderboard_settings set visibility = 'matches_and_clubs' where user_id = new.id and visibility = 'public';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.limit_activity_photos()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if (select count(*) from public.activity_photos where activity_log_id = new.activity_log_id) >= 6 then
    raise exception 'An activity can have up to 6 photos.' using errcode = 'check_violation';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.limit_clubs_per_organizer()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if (select count(*) from public.clubs where organizer_id = new.organizer_id) >= 5 then
    raise exception 'An organizer can run up to 5 clubs.' using errcode = 'check_violation';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.limit_filter_presets()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if (select count(*) from public.filter_presets where user_id = new.user_id) >= 25 then
    raise exception 'You can save up to 25 filter presets.' using errcode = 'check_violation';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.limit_plan_partners()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if (select count(*) from public.plan_partners where plan_id = new.plan_id) >= 10 then
    raise exception 'A plan can have up to 10 partners.' using errcode = 'check_violation';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.limit_plans()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if (select count(*) from public.plans where owner_id = new.owner_id) >= 30 then
    raise exception 'You can keep up to 30 plans. Delete one to add another.' using errcode = 'check_violation';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.limit_templates()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if (select count(*) from public.workout_templates where owner_id = new.owner_id) >= 50 then
    raise exception 'You can keep up to 50 templates. Delete one to add another.'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.limit_thread_members()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if new.role = 'member'
     and (select count(*) from public.thread_participants
           where thread_id = new.thread_id and role = 'member' and user_id <> new.user_id) >= 2 then
    raise exception 'A conversation has exactly two members.' using errcode = 'check_violation';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.may_report(p_reporter uuid, p_reported uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select exists (select 1 from public.matches m
                  where (m.requester_id = p_reporter and m.recipient_id = p_reported)
                     or (m.requester_id = p_reported and m.recipient_id = p_reporter))
      or exists (select 1 from public.thread_participants a join public.thread_participants b on b.thread_id = a.thread_id
                  where a.user_id = p_reporter and b.user_id = p_reported)
      or exists (select 1 from public.club_memberships a join public.club_memberships b on b.club_id = a.club_id
                  where a.user_id = p_reporter and b.user_id = p_reported)
      or (private.viewer_may_browse_discover() and private.profile_is_discoverable(p_reported));
$function$
;

CREATE OR REPLACE FUNCTION private.may_see_standing(p_target uuid, p_viewer uuid, p_club uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_vis    public.leaderboard_visibility := private.visibility_of(p_target);
  v_minor  boolean;
  v_shared boolean;
  v_match  boolean;
begin
  if p_target = p_viewer then return true; end if;
  if exists (select 1 from public.club_leaderboard_opt_outs where club_id = p_club and user_id = p_target) then return false; end if;
  if v_vis = 'off' then return false; end if;
  if exists (select 1 from public.users where id = p_target and is_banned) then return false; end if;
  select age_status = 'minor' into v_minor from public.users where id = p_target;
  v_shared := exists (select 1 from public.club_memberships where club_id = p_club and user_id = p_viewer);
  -- A minor's standing is visible only to fellow members of that same club (5.9). Never to a partner who is not one.
  if v_minor then return v_shared; end if;
  v_match := exists (select 1 from public.matches m
                      where m.status = 'matched' and m.deleted_at is null
                        and ((m.requester_id = p_viewer and m.recipient_id = p_target) or (m.requester_id = p_target and m.recipient_id = p_viewer)));
  if v_vis = 'matches_and_clubs' then return v_shared or v_match; end if;
  return v_shared or v_match or (private.viewer_may_browse_discover() and private.profile_is_discoverable(p_target));
end;
$function$
;

CREATE OR REPLACE FUNCTION private.minor_without_consent(p_user uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select exists (select 1 from public.users u
                  where u.id = p_user and u.age_status = 'minor' and u.consent_status <> 'granted');
$function$
;

CREATE OR REPLACE FUNCTION private.mutual_partner_count(p_a uuid, p_b uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select count(*)::integer
    from public.matches ma
    join public.matches mb
      on  (case when mb.requester_id = p_b then mb.recipient_id else mb.requester_id end)
        = (case when ma.requester_id = p_a then ma.recipient_id else ma.requester_id end)
   where ma.status = 'matched' and ma.deleted_at is null and p_a in (ma.requester_id, ma.recipient_id)
     and mb.status = 'matched' and mb.deleted_at is null and p_b in (mb.requester_id, mb.recipient_id)
     and private.user_is_not_banned(
           case when ma.requester_id = p_a then ma.recipient_id else ma.requester_id end);
$function$
;

CREATE OR REPLACE FUNCTION private.next_plan_date(p_dow integer, p_time time without time zone, p_tz text)
 RETURNS date
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  with now_local as (select (now() at time zone p_tz) as ts),
       base as (select ts::date as d, ts::time as t from now_local)
  select d + ((p_dow - extract(dow from d)::int + 7) % 7)
           + case when ((p_dow - extract(dow from d)::int + 7) % 7) = 0 and p_time <= t then 7 else 0 end
    from base;
$function$
;

CREATE OR REPLACE FUNCTION private.no_minor_checkin()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if new.checkin_opt_in
     and exists (select 1 from public.users u where u.id = new.user_id and u.age_status = 'minor') then
    raise exception 'Check-in sharing is not available to accounts under 18.' using errcode = 'check_violation';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.no_minor_checkin_location()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if exists (
    select 1 from public.session_participants sp join public.users u on u.id = sp.user_id
     where sp.session_id = new.session_id and (u.age_status is distinct from 'adult' and u.age_status is distinct from 'self_attested_adult')
  ) then
    raise exception 'Check-in sharing is not available for a session that includes an account under 18, or one whose age is not confirmed.' using errcode = 'check_violation';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.parse_set_json(p_el jsonb)
 RETURNS private.parsed_set
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  r        private.parsed_set;
  v_cap    numeric;
  v_n      numeric;
  v_metres numeric;
  v_dunit  text;
  v_punit  text;
begin
  if jsonb_typeof(p_el) <> 'object' or jsonb_typeof(p_el -> 'exercise') is distinct from 'string' then
    raise exception 'Each row needs an exercise.' using errcode = 'check_violation';
  end if;
  r.exercise := btrim(p_el ->> 'exercise');
  r.target_detail := coalesce(btrim(p_el ->> 'target_detail'), '');

  -- weight (+ its unit)
  r.weight_unit := coalesce(nullif(p_el ->> 'weight_unit', ''), 'lb');
  if r.weight_unit not in ('lb', 'kg') then
    raise exception 'The weight unit must be lb or kg.' using errcode = 'check_violation';
  end if;
  if p_el ? 'weight' and jsonb_typeof(p_el -> 'weight') <> 'null' then
    if jsonb_typeof(p_el -> 'weight') <> 'number' then
      raise exception 'A weight must be a number.' using errcode = 'check_violation';
    end if;
    v_n := (p_el ->> 'weight')::numeric;
    v_cap := 2000;
    if r.weight_unit = 'kg' then v_cap := 1000; end if;
    if v_n < 0 or v_n > v_cap then
      raise exception 'A weight must be between 0 and % %.', v_cap, r.weight_unit using errcode = 'check_violation';
    end if;
    r.weight := v_n;
  end if;

  -- reps
  if p_el ? 'reps' and jsonb_typeof(p_el -> 'reps') <> 'null' then
    if jsonb_typeof(p_el -> 'reps') <> 'number' then
      raise exception 'Reps must be a number.' using errcode = 'check_violation';
    end if;
    v_n := (p_el ->> 'reps')::numeric;
    if v_n <> trunc(v_n) or v_n < 1 or v_n > 999 then
      raise exception 'Reps must be a whole number from 1 to 999.' using errcode = 'check_violation';
    end if;
    r.reps := v_n::integer;
  end if;

  -- duration (seconds)
  if p_el ? 'duration_seconds' and jsonb_typeof(p_el -> 'duration_seconds') <> 'null' then
    if jsonb_typeof(p_el -> 'duration_seconds') <> 'number' then
      raise exception 'A time must be a number of seconds.' using errcode = 'check_violation';
    end if;
    v_n := (p_el ->> 'duration_seconds')::numeric;
    if v_n <> trunc(v_n) or v_n < 1 or v_n > 86400 then
      raise exception 'A time must be between 1 second and 24 hours.' using errcode = 'check_violation';
    end if;
    r.duration_seconds := v_n::integer;
  end if;

  -- distance (+ its unit): positive, at most 1000 km, whole metres
  v_dunit := nullif(p_el ->> 'distance_unit', '');
  if p_el ? 'distance' and jsonb_typeof(p_el -> 'distance') <> 'null' then
    if jsonb_typeof(p_el -> 'distance') <> 'number' then
      raise exception 'A distance must be a number.' using errcode = 'check_violation';
    end if;
    if v_dunit is null or v_dunit not in ('mi', 'km', 'm') then
      raise exception 'A distance needs a unit: miles, kilometres or metres.' using errcode = 'check_violation';
    end if;
    v_n := (p_el ->> 'distance')::numeric;
    if v_n <= 0 then
      raise exception 'A distance must be more than zero.' using errcode = 'check_violation';
    end if;
    if v_dunit = 'm' and v_n <> trunc(v_n) then
      raise exception 'A distance in metres must be a whole number.' using errcode = 'check_violation';
    end if;
    v_metres := v_n * case v_dunit when 'mi' then 1609.344 when 'km' then 1000 else 1 end;
    if v_metres > 1000000 then
      raise exception 'A distance can be at most 1000 km.' using errcode = 'check_violation';
    end if;
    r.distance := v_n;
    r.distance_unit := v_dunit;
  elsif v_dunit is not null and v_dunit not in ('mi', 'km', 'm') then
    raise exception 'A distance unit must be mi, km or m.' using errcode = 'check_violation';
  end if;

  -- pace (seconds per mile or per kilometre) and its unit
  v_punit := nullif(p_el ->> 'pace_unit', '');
  if p_el ? 'pace_seconds' and jsonb_typeof(p_el -> 'pace_seconds') <> 'null' then
    if jsonb_typeof(p_el -> 'pace_seconds') <> 'number' then
      raise exception 'A pace must be a number of seconds.' using errcode = 'check_violation';
    end if;
    v_n := (p_el ->> 'pace_seconds')::numeric;
    if v_n <> trunc(v_n) or v_n < 60 or v_n > 3600 then
      raise exception 'A pace must be between 1:00 and 60:00 per mile or kilometre.' using errcode = 'check_violation';
    end if;
    if v_punit is null or v_punit not in ('mi', 'km') then
      raise exception 'A pace needs a unit: per mile or per kilometre.' using errcode = 'check_violation';
    end if;
    r.pace_seconds := v_n::integer;
    r.pace_unit := v_punit;
  elsif v_punit is not null and v_punit not in ('mi', 'km') then
    raise exception 'A pace unit must be mi or km.' using errcode = 'check_violation';
  end if;

  return r;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.plan_for_log(p_user uuid, p_log public.activity_logs)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select p.id
    from public.plans p
   where p.owner_id = p_user
     and p.activity_type = p_log.activity_type
     and private.is_plan_occurrence(p, (p_log.started_at at time zone p.timezone)::date)
     and not exists (
       select 1 from public.sessions s
        where s.plan_id = p.id and s.occurrence_on = (p_log.started_at at time zone p.timezone)::date and s.status = 'completed')
   order by p.created_at
   limit 1;
$function$
;

CREATE OR REPLACE FUNCTION private.plan_last_on(p_recurrence public.plan_recurrence, p_starts_on date, p_weeks integer)
 RETURNS date
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'pg_catalog'
AS $function$
  select case when p_recurrence = 'one_time' then p_starts_on
              when p_weeks is not null then p_starts_on + 7 * (p_weeks - 1)
              else null end;
$function$
;

CREATE OR REPLACE FUNCTION private.plan_next_start(p_plan public.plans)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
declare
  v_local  timestamp := now() at time zone p_plan.timezone;
  v_today  date := v_local::date;
  v_cand   date;
  v_last   date := private.plan_last_on(p_plan.recurrence, p_plan.starts_on, p_plan.end_after_weeks);
  v_n      integer;
begin
  if p_plan.recurrence = 'one_time' then
    v_cand := p_plan.starts_on;
  else
    v_n := greatest(0, ceil((v_today - p_plan.starts_on) / 7.0)::int);
    v_cand := p_plan.starts_on + 7 * v_n;
    if v_cand = v_today and p_plan.start_time <= v_local::time then v_cand := v_cand + 7; end if;
  end if;
  if v_cand < v_today or (v_cand = v_today and p_plan.start_time <= v_local::time) then return null; end if;
  if v_last is not null and v_cand > v_last then return null; end if;
  return (v_cand + p_plan.start_time) at time zone p_plan.timezone;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.profile_is_discoverable(p_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select exists (
    select 1
    from public.users u
    where u.id = p_user_id
      and not u.is_banned
      and u.age_status in ('self_attested_adult', 'adult')
  );
$function$
;

CREATE OR REPLACE FUNCTION private.promote_waitlist(p_event_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_cap   integer;
  v_going integer;
  v_next  uuid;
begin
  select capacity into v_cap from public.club_events where id = p_event_id;

  loop
    select count(*) into v_going from public.club_event_rsvps where club_event_id = p_event_id and status = 'going';
    exit when v_cap is not null and v_going >= v_cap;

    select user_id into v_next from public.club_event_rsvps
     where club_event_id = p_event_id and status = 'waitlisted'
     order by waitlist_position
     limit 1;
    exit when v_next is null;

    update public.club_event_rsvps set status = 'going', waitlist_position = null
     where club_event_id = p_event_id and user_id = v_next;
  end loop;

  -- Close the gaps so the remaining positions are 1, 2, 3 ...
  with ranked as (
    select user_id, row_number() over (order by waitlist_position) as rn
      from public.club_event_rsvps
     where club_event_id = p_event_id and status = 'waitlisted'
  )
  update public.club_event_rsvps r set waitlist_position = ranked.rn
    from ranked
   where r.club_event_id = p_event_id and r.user_id = ranked.user_id and r.waitlist_position is distinct from ranked.rn;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.purge_checkin_locations()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_n integer;
begin
  delete from public.checkin_locations where purge_after < now();
  get diagnostics v_n = row_count;
  return v_n;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.purge_old_reports()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_n integer;
begin
  delete from public.reports
   where (reporter_id is null or reported_id is null)
     and status <> 'under_review'
     and resolved_at < now() - interval '1 year';
  get diagnostics v_n = row_count;
  return v_n;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.push_minute()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  perform private.enqueue_plan_reminders();
  perform private.kick_push();
end;
$function$
;

CREATE OR REPLACE FUNCTION private.push_name(p_user uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select coalesce((select nullif(btrim(display_name), '') from public.profiles where user_id = p_user), 'Someone');
$function$
;

CREATE OR REPLACE FUNCTION private.push_on_match()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if new.status = 'pending' and (tg_op = 'INSERT' or old.status is distinct from 'pending') then
    perform private.enqueue_push(
      new.recipient_id, 'match_request_received',
      'New request',
      case when new.source = 'qr_scan' then private.push_name(new.requester_id) || ' scanned your code. Open Matches to confirm.'
           else private.push_name(new.requester_id) || ' wants to train with you.' end,
      case when new.source = 'qr_scan' then jsonb_build_object('route', 'matches')
           else jsonb_build_object('route', 'person', 'id', new.requester_id) end,
      'match_request:' || new.id || ':' || new.requested_at::text);
  elsif tg_op = 'UPDATE' and new.status = 'matched' and old.status = 'pending' then
    perform private.enqueue_push(
      new.requester_id, 'match_approved',
      'You matched',
      'You and ' || private.push_name(new.recipient_id) || ' are now training partners.',
      jsonb_build_object('route', 'match', 'match_id', new.id),
      'match_approved:' || new.id || ':' || coalesce(new.matched_at, now())::text);
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.push_on_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  r record;
  v_body text;
begin
  v_body := case new.type::text
    when 'text' then left(coalesce(new.payload ->> 'text', ''), 140)
    when 'template_share' then 'Shared a workout template.'
    when 'session_proposal' then 'Proposed a session.'
    else 'Sent you a message.'
  end;
  if btrim(v_body) = '' then v_body := 'Sent you a message.'; end if;

  for r in
    select tp.user_id
      from public.thread_participants tp
      left join public.thread_settings ts on ts.thread_id = tp.thread_id and ts.user_id = tp.user_id
     where tp.thread_id = new.thread_id and tp.role = 'member' and tp.user_id <> new.sender_id
       and coalesce(ts.messages_muted, false) = false
  loop
    perform private.enqueue_push(r.user_id, 'chat_message_new', private.push_name(new.sender_id), v_body,
                                 jsonb_build_object('route', 'chat', 'thread_id', new.thread_id), 'message:' || new.id || ':' || r.user_id);
  end loop;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.push_on_proposal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if tg_op = 'INSERT' and new.status = 'proposed' then
    perform private.enqueue_push(
      new.recipient_id, 'schedule_proposal', 'Session proposed',
      private.push_name(new.proposer_id) || ' proposed ' || private.push_when(new.proposed_start, new.timezone) || '.',
      jsonb_build_object('route', 'activity', 'plan_id', new.plan_id), 'proposal:' || new.id || ':proposed');
  elsif tg_op = 'UPDATE' and old.status = 'proposed' and new.status in ('accepted', 'declined') then
    perform private.enqueue_push(
      new.proposer_id, 'schedule_proposal',
      case new.status when 'accepted' then 'Session confirmed' else 'Session declined' end,
      private.push_name(new.recipient_id) || case new.status when 'accepted' then ' confirmed ' else ' declined ' end
        || private.push_when(new.proposed_start, new.timezone) || '.',
      jsonb_build_object('route', 'activity', 'plan_id', new.plan_id), 'proposal:' || new.id || ':' || new.status);
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.push_outbox_kick()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  perform private.kick_push();
  return null;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.push_tidy()
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  delete from public.push_outbox where created_at < now() - interval '30 days' and (sent_at is not null or failed_at is not null);
$function$
;

CREATE OR REPLACE FUNCTION private.push_when(p_at timestamp with time zone, p_tz text)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
  select to_char(p_at at time zone p_tz, 'FMDay, FMHH12:MI AM');
$function$
;

CREATE OR REPLACE FUNCTION private.qr_gate(p_scanner uuid, p_target uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  s record;
  t record;
  v_minor uuid;
  v_adult record;
  v_club record;
  v_link public.guardian_links%rowtype;
  v_week integer;
  v_generic constant text := 'That code can''t be used. Try again, or ask the other person to scan yours.';
begin
  select id, age_status, consent_status, is_banned into s from public.users where id = p_scanner;
  select id, age_status, consent_status, is_banned into t from public.users where id = p_target;

  -- 1. Both exist, neither is banned (5.4).
  if s.id is null or s.is_banned then
    return jsonb_build_object('ok', false, 'reason', 'Sign in first.');
  end if;
  if t.id is null or t.is_banned or p_scanner = p_target then
    return jsonb_build_object('ok', false, 'reason', v_generic);
  end if;

  -- 2. A minor's consent must be granted (15.2). Pending and revoked are refused in both directions.
  if s.age_status = 'minor' and s.consent_status <> 'granted' then
    return jsonb_build_object('ok', false, 'reason', 'Your guardian needs to finish approving your account before you can connect with people.');
  end if;
  if t.age_status = 'minor' and t.consent_status <> 'granted' then
    return jsonb_build_object('ok', false, 'reason', v_generic);
  end if;

  -- 4. Unverified can never match with anyone by this path (5.5).
  if s.age_status = 'unverified' then
    return jsonb_build_object('ok', false, 'reason', 'Connecting with people isn''t available until your age is verified. You can still join a club with its code.');
  end if;
  if t.age_status = 'unverified' then
    return jsonb_build_object('ok', false, 'reason', v_generic);
  end if;

  -- 3. Two minors: allowed, with the mutual confirm tap. Stop here.
  if s.age_status = 'minor' and t.age_status = 'minor' then
    return jsonb_build_object('ok', true, 'mode', 'minor_minor');
  end if;
  -- Two adults: the ordinary mutual confirm.
  if s.age_status <> 'minor' and t.age_status <> 'minor' then
    return jsonb_build_object('ok', true, 'mode', 'adult_adult');
  end if;

  -- Exactly one minor. 8. The MINOR is the scanner (15.6). An adult who scanned a minor's code is told nothing
  -- about why; the answer is the same as for an expired code.
  if s.age_status <> 'minor' then
    return jsonb_build_object('ok', false, 'reason', v_generic);
  end if;
  v_minor := s.id;
  select * into v_adult from public.users where id = t.id;

  -- 5. Only a fully ID-verified adult may connect with a minor (15.5).
  if v_adult.age_status <> 'adult' then
    return jsonb_build_object('ok', false, 'reason', 'Only an adult who has completed ID verification can connect with a member under 18.');
  end if;

  -- 6. A shared club (15.5): the load-bearing rule.
  select c.id, c.name into v_club
    from public.club_memberships a
    join public.club_memberships b on b.club_id = a.club_id and b.user_id = v_adult.id
    join public.clubs c on c.id = a.club_id
   where a.user_id = v_minor
   order by c.name
   limit 1;
  if v_club.id is null then
    return jsonb_build_object('ok', false, 'reason', 'To connect with an adult you need to already be in a club together. Join their club first with its code.');
  end if;

  -- The guardian's own controls (15.4).
  select * into v_link from public.guardian_links where minor_user_id = v_minor and status = 'active' order by invited_at desc limit 1;
  if v_link.id is null then
    return jsonb_build_object('ok', false, 'reason', 'Your guardian link isn''t active, so connections with adults are paused.');
  end if;
  if not v_link.adult_connections_allowed then
    return jsonb_build_object('ok', false, 'reason', 'Your guardian has turned off connections with adults.');
  end if;

  -- 7. Three per rolling week per minor; beyond that is held for review (15.7).
  select count(*) into v_week from public.minor_adult_matches
   where minor_user_id = v_minor and state = 'active' and created_at > now() - interval '7 days';

  return jsonb_build_object('ok', true, 'mode', 'minor_adult', 'club_id', v_club.id, 'club_name', v_club.name,
                            'link_id', v_link.id, 'approval_required', v_link.per_connection_approval_required,
                            'hold', v_week >= 3);
end;
$function$
;

CREATE OR REPLACE FUNCTION private.qr_normalize(p_code text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'pg_catalog'
AS $function$
  select upper(btrim(coalesce(p_code, '')));
$function$
;

CREATE OR REPLACE FUNCTION private.ranked_members(p_club uuid, p_basis text, p_include uuid DEFAULT NULL::uuid)
 RETURNS TABLE(user_id uuid, display_name text, sessions integer, rank integer, total integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  with facts as (
    select f.user_id,
           case when p_basis = 'all' then f.sessions_all else f.sessions_30 end as sessions,
           case when p_basis = 'all' then f.reached_all else f.reached_30 end as reached
      from private.club_facts(p_club) f
  ), shown as (
    select f.user_id, f.sessions, f.reached
      from facts f
      join public.users u on u.id = f.user_id and not u.is_banned
     where f.sessions > 0
       and (f.user_id = p_include
            or (private.visibility_of(f.user_id) <> 'off'
                and not exists (select 1 from public.club_leaderboard_opt_outs o where o.club_id = p_club and o.user_id = f.user_id)))
  ), ranked as (
    select s.user_id, s.sessions,
           (row_number() over (order by s.sessions desc, s.reached asc, s.user_id))::int as rank,
           (count(*) over ())::int as total
      from shown s
  )
  select r.user_id, coalesce(p.display_name, 'Member'), r.sessions, r.rank, r.total
    from ranked r left join public.profiles p on p.user_id = r.user_id;
$function$
;

CREATE OR REPLACE FUNCTION private.reports_are_final()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if old.status <> 'under_review' and new.status is distinct from old.status then
    raise exception 'A resolved report cannot be changed.' using errcode = 'check_violation';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.resolve_code(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_code text := private.qr_normalize(p_code);
  v_user uuid;
  v_club uuid;
begin
  if v_code = '' or char_length(v_code) > 64 then return null; end if;

  select user_id into v_user from public.minor_qr_codes where code = v_code and expires_at + interval '10 seconds' > now();
  if v_user is not null then return jsonb_build_object('kind', 'person', 'person_id', v_user, 'rotating', true); end if;

  select p.user_id into v_user
    from public.profiles p join public.users u on u.id = p.user_id
   where p.qr_code = v_code and u.age_status <> 'minor';
  if v_user is not null then return jsonb_build_object('kind', 'person', 'person_id', v_user, 'rotating', false); end if;

  select id into v_club from public.clubs where qr_code = v_code;
  if v_club is not null then return jsonb_build_object('kind', 'club', 'club_id', v_club); end if;
  return null;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.share_for_recipient(p_message_id uuid)
 RETURNS TABLE(sender_id uuid, template_id uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select m.sender_id, (m.payload ->> 'template_id')::uuid
    from public.messages m
   where m.id = p_message_id
     and m.type = 'template_share'
     and m.sender_id is distinct from (select private.current_user_id())
     and (select private.can_read_thread(m.thread_id))
     and exists (select 1 from public.thread_participants p
                  where p.thread_id = m.thread_id
                    and p.user_id = (select private.current_user_id())
                    and p.role = 'member');
$function$
;

CREATE OR REPLACE FUNCTION private.user_is_not_banned(p_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select exists (select 1 from public.users u where u.id = p_user_id and not u.is_banned);
$function$
;

CREATE OR REPLACE FUNCTION private.viewer_can_see_club(p_club_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select private.viewer_is_club_member(p_club_id)
      or exists (
        select 1 from public.users u
         where u.id = (select private.current_user_id())
           and not u.is_banned
           and u.age_status in ('self_attested_adult', 'adult')
      );
$function$
;

CREATE OR REPLACE FUNCTION private.viewer_club_standing_ok()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select exists (
    select 1 from public.users u
     where u.id = (select private.current_user_id())
       and not u.is_banned
       and (u.age_status <> 'minor' or u.consent_status = 'granted')
  );
$function$
;

CREATE OR REPLACE FUNCTION private.viewer_in_session(p_session_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select exists (select 1 from public.session_participants sp
                  where sp.session_id = p_session_id and sp.user_id = (select private.current_user_id()));
$function$
;

CREATE OR REPLACE FUNCTION private.viewer_is_banned()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select coalesce(
    (select is_banned from public.users where auth_id = auth.uid()),
    true  -- no row for this session => treat as banned. Fail closed.
  );
$function$
;

CREATE OR REPLACE FUNCTION private.viewer_is_club_member(p_club_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select (select private.viewer_club_standing_ok())
     and exists (
       select 1 from public.club_memberships m
        where m.club_id = p_club_id and m.user_id = (select private.current_user_id())
     );
$function$
;

CREATE OR REPLACE FUNCTION private.viewer_is_plan_partner(p_plan_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select exists (
    select 1 from public.plan_partners pp
      join public.plans p on p.id = pp.plan_id
      join public.users o on o.id = p.owner_id
     where pp.plan_id = p_plan_id
       and pp.user_id = (select private.current_user_id())
       and pp.status in ('invited', 'confirmed')
       and not o.is_banned
  );
$function$
;

CREATE OR REPLACE FUNCTION private.viewer_may_browse_discover()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select exists (
    select 1
    from public.users u
    where u.auth_id = auth.uid()
      and not u.is_banned
      and u.age_status in ('self_attested_adult', 'adult')
  );
$function$
;

CREATE OR REPLACE FUNCTION private.viewer_may_create_club()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select exists (
    select 1 from public.users u
     where u.id = (select private.current_user_id())
       and not u.is_banned
       and u.age_status in ('self_attested_adult', 'adult')
       and (u.can_organize_clubs or u.age_status = 'adult')
  );
$function$
;

CREATE OR REPLACE FUNCTION private.viewer_owns_log(p_log_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select exists (select 1 from public.activity_logs l where l.id = p_log_id and l.user_id = (select private.current_user_id()));
$function$
;

CREATE OR REPLACE FUNCTION private.viewer_owns_plan(p_plan_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select exists (select 1 from public.plans p
                  where p.id = p_plan_id and p.owner_id = (select private.current_user_id()));
$function$
;

CREATE OR REPLACE FUNCTION private.visibility_of(p_user uuid)
 RETURNS public.leaderboard_visibility
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select coalesce((select visibility from public.leaderboard_settings where user_id = p_user), 'matches_and_clubs');
$function$
;

CREATE OR REPLACE FUNCTION private.wearable_events_tidy()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_n integer;
begin
  delete from public.wearable_events where received_at < now() - interval '30 days';
  get diagnostics v_n = row_count;
  return v_n;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.write_template_sets(p_template_id uuid, p_sets jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_el  jsonb;
  v_pos integer := 0;
  v     private.parsed_set;
begin
  if p_sets is null or jsonb_typeof(p_sets) <> 'array' or jsonb_array_length(p_sets) > 120 then
    raise exception 'A template can have up to 120 sets.' using errcode = 'check_violation';
  end if;

  for v_el in select * from jsonb_array_elements(p_sets) loop
    v_pos := v_pos + 1;
    v := private.parse_set_json(v_el);
    insert into public.template_sets (template_id, position, exercise, target_detail, weight, weight_unit, reps,
                                      duration_seconds, pace_seconds, pace_unit, distance, distance_unit)
    values (p_template_id, v_pos, v.exercise, v.target_detail, v.weight, v.weight_unit, v.reps,
            v.duration_seconds, v.pace_seconds, v.pace_unit, v.distance, v.distance_unit);
  end loop;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.accept_shared_template(p_message_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me    uuid := private.current_user_id();
  v_share record;
  v_t     public.workout_templates%rowtype;
  v_new   uuid;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;

  select * into v_share from private.share_for_recipient(p_message_id);
  if v_share.sender_id is null then
    raise exception 'That template is not available.' using errcode = 'no_data_found';
  end if;

  if exists (select 1 from public.template_share_responses where message_id = p_message_id and user_id = v_me) then
    raise exception 'You have already answered this.' using errcode = 'check_violation';
  end if;

  select * into v_t from public.workout_templates where id = v_share.template_id and owner_id = v_share.sender_id;
  if v_t.id is null then
    raise exception 'This template is no longer available.' using errcode = 'no_data_found';
  end if;

  -- COPY, never a reference (§4.3) — every set, with every number and the unit it was typed in.
  insert into public.workout_templates (owner_id, name, summary, activity_type, source, received_from_user_id)
  values (v_me, v_t.name, v_t.summary, v_t.activity_type, 'received', v_share.sender_id)
  returning id into v_new;

  insert into public.template_sets (template_id, position, exercise, target_detail, weight, weight_unit, reps,
                                    duration_seconds, pace_seconds, pace_unit, distance, distance_unit)
  select v_new, s.position, s.exercise, s.target_detail, s.weight, s.weight_unit, s.reps,
         s.duration_seconds, s.pace_seconds, s.pace_unit, s.distance, s.distance_unit
    from public.template_sets s where s.template_id = v_t.id;

  insert into public.template_share_responses (message_id, user_id, response, copied_template_id)
  values (p_message_id, v_me, 'accepted', v_new);

  return v_new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.account_deletion_blockers()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  return coalesce((
    select jsonb_agg(b.item order by b.ord)
      from (
        select 1 as ord, jsonb_build_object('kind', 'guardian',
                 'message', 'You are the parent or guardian of ' || coalesce(mp.display_name, 'a young person') ||
                            '. Pause their account first (Guardian settings, then Revoke consent), then delete yours.') as item
          from public.guardian_links gl
          join public.guardians g on g.id = gl.guardian_id and g.user_id = v_me
          left join public.profiles mp on mp.user_id = gl.minor_user_id
         where gl.status in ('pending', 'active')
        union all
        select 2, jsonb_build_object('kind', 'club',
                 'message', 'You organize ' || c.name || '. Email groundwork.app.help@gmail.com to hand it over before you delete your account.')
          from public.clubs c where c.organizer_id = v_me
      ) b), '[]'::jsonb);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.add_activity_photo(p_log_id uuid, p_path text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
  v_id uuid;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if not exists (select 1 from public.activity_logs where id = p_log_id and user_id = v_me) then
    raise exception 'That activity is not yours.' using errcode = 'no_data_found';
  end if;
  -- The path must be inside the caller's own folder for THIS activity, so a path cannot point at someone else's file.
  if p_path is null or p_path !~ ('^' || (select auth.uid())::text || '/' || p_log_id::text || '/[A-Za-z0-9._-]{1,80}$') then
    raise exception 'That photo is not stored in your folder for this activity.' using errcode = 'check_violation';
  end if;
  insert into public.activity_photos (activity_log_id, storage_path) values (p_log_id, p_path) returning id into v_id;
  return v_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.add_place(p_name text, p_kind text DEFAULT 'neighborhood'::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me    uuid := private.current_user_id();
  v_clean text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  v_slug  text;
  v_hidden timestamptz;
begin
  if v_me is null or not exists (
       select 1 from public.users u
        where u.id = v_me and not u.is_banned and u.age_status in ('self_attested_adult', 'adult')
     ) then
    raise exception 'Adding a place is available to adult accounts. You can pick one from the list.'
      using errcode = 'insufficient_privilege';
  end if;

  if p_kind not in ('neighborhood', 'city') then
    raise exception 'A place is a neighborhood or a city.' using errcode = 'invalid_parameter_value';
  end if;

  if char_length(v_clean) not between 2 and 40
     or v_clean !~ '[[:alpha:]]{2}'
     or array_length(string_to_array(v_clean, ' '), 1) > 5
     or v_clean ~ '[]0-9@#$%&*()_+={}<>|/:;"!?~`,^[]' then
    raise exception 'Use just the name of a neighborhood or city — letters only, no numbers or addresses.'
      using errcode = 'check_violation';
  end if;

  v_slug := btrim(lower(regexp_replace(v_clean, '[^a-zA-Z]+', '-', 'g')), '-');
  if v_slug = '' then
    raise exception 'Use just the name of a neighborhood or city — letters only, no numbers or addresses.'
      using errcode = 'check_violation';
  end if;

  -- Someone already added (or we seeded) this place: use it rather than make a near-twin.
  select n.hidden_at into v_hidden from public.neighborhoods n where n.slug = v_slug;
  if found then
    if v_hidden is not null then
      raise exception 'That place isn''t available.' using errcode = 'no_data_found';
    end if;
    return v_slug;
  end if;

  if (select count(*) from public.neighborhoods where created_by = v_me) >= 5 then
    raise exception 'You can add up to 5 places. Pick one from the list instead.'
      using errcode = 'check_violation';
  end if;

  insert into public.neighborhoods (slug, name, kind, user_added, created_by)
  values (v_slug, v_clean, p_kind, true, v_me)
  on conflict (slug) do nothing;

  return v_slug;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.apply_identity_result(p_session_id text, p_status text, p_age_result text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  r public.verification_records%rowtype;
  u public.users%rowtype;
  v_result text := p_age_result;
  v_ended  uuid[];
begin
  if p_status not in ('verified', 'requires_input', 'canceled') then
    raise exception 'Unknown verification status.' using errcode = 'check_violation';
  end if;
  if p_status = 'verified' and p_age_result not in ('adult', 'minor', 'inconclusive') then
    raise exception 'A verified result needs an age outcome.' using errcode = 'check_violation';
  end if;

  select * into r from public.verification_records where provider_reference_id = p_session_id for update;
  if r.id is null then
    raise exception 'No verification record for that session.' using errcode = 'no_data_found';
  end if;
  -- A finished check is final; a replayed or late event changes nothing.
  if r.status = 'verified' then
    return 'ignored';
  end if;

  select * into u from public.users where id = r.user_id for update;

  if p_status <> 'verified' then
    update public.verification_records set status = p_status, updated_at = now() where id = r.id;
    return 'recorded';
  end if;

  -- A minor (by self-attestation or an earlier ID) is never moved to adult by a later check: that needs a person (2.8).
  if v_result = 'adult' and u.age_status = 'minor' then
    v_result := 'inconclusive';
  end if;

  update public.verification_records
     set status = 'verified', verified_at = now(), age_check_result = v_result, updated_at = now()
   where id = r.id;

  if v_result = 'adult' and u.age_status in ('self_attested_adult', 'unverified') then
    update public.users set age_status = 'adult', age_status_set_at = now() where id = u.id;
  elsif v_result = 'minor' and u.age_status <> 'minor' then
    -- Sticky and fail-closed: a minor needs a guardian before anything else (15.2).
    update public.users
       set age_status = 'minor', age_status_set_at = now(), consent_status = 'pending', consent_status_set_at = now()
     where id = u.id;

    -- ...and connections formed as an adult do not survive it (same steps as revoke_guardian_consent).
    with ended as (
      update public.matches m
         set deleted_at = now()
       where m.deleted_at is null
         and u.id in (m.requester_id, m.recipient_id)
         and exists (
           select 1 from public.users other
            where other.id = case when m.requester_id = u.id then m.recipient_id else m.requester_id end
              and other.age_status in ('self_attested_adult', 'adult'))
      returning m.id
    )
    select coalesce(array_agg(id), '{}') into v_ended from ended;

    update public.chat_threads set archived = true where match_id = any (v_ended);
    perform private.clear_plan_partners_between(m.requester_id, m.recipient_id)
       from public.matches m where m.id = any (v_ended);
  end if;

  -- A guardian's own ID check is what unlocks the consent step (15.2).
  if v_result = 'adult' then
    update public.guardians
       set verified_at = now(), verification_method = 'stripe_identity', provider_reference_id = p_session_id
     where user_id = u.id;
  end if;
  return 'applied';
end;
$function$
;

CREATE OR REPLACE FUNCTION public.approve_match(p_match_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me     uuid := private.current_user_id();
  v_src    public.match_source;
  v_status text;
begin
  if v_me is null or private.viewer_is_banned() then
    raise exception 'Not available.' using errcode = 'insufficient_privilege';
  end if;

  select source into v_src from public.matches
   where id = p_match_id and recipient_id = v_me and status = 'pending' and deleted_at is null
     and private.user_is_not_banned(requester_id);
  if v_src is null then
    raise exception 'There is no request here for you to approve.' using errcode = 'no_data_found';
  end if;

  if v_src = 'qr_scan' then
    update public.matches set recipient_confirmed_at = coalesce(recipient_confirmed_at, now()) where id = p_match_id;
    v_status := private.advance_qr_match(p_match_id);
    if v_status = 'declined' then
      raise exception 'This connection can''t be completed.' using errcode = 'insufficient_privilege';
    end if;
    return;
  end if;

  update public.matches
     set status = 'matched', matched_at = now()
   where id = p_match_id;
  perform private.ensure_thread(p_match_id);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.attach_plan_partner(p_plan_id uuid, p_partner_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me   uuid := private.current_user_id();
  v_plan public.plans%rowtype;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;

  select * into v_plan from public.plans where id = p_plan_id and owner_id = v_me;
  if v_plan.id is null then
    raise exception 'That plan is not yours to change.' using errcode = 'insufficient_privilege';
  end if;

  -- §5.10 / S25: a pending or revoked minor cannot be attached, or attach anyone, in either seat.
  if private.minor_without_consent(v_me) or private.minor_without_consent(p_partner_id) then
    raise exception 'That person is not available for plans right now.' using errcode = 'insufficient_privilege';
  end if;

  -- Only people you are matched with. One message for "not matched", "banned" and "no such person".
  if p_partner_id is null or p_partner_id = v_me or not private.are_live_partners(v_me, p_partner_id) then
    raise exception 'You can add people you are matched with.' using errcode = 'insufficient_privilege';
  end if;

  -- Re-inviting a declined or dismissed partner puts them back to Invited and back on the plan.
  insert into public.plan_partners (plan_id, user_id, status)
  values (p_plan_id, p_partner_id, 'invited')
  on conflict (plan_id, user_id) do update
     set status = case when public.plan_partners.status = 'declined' then 'invited' else public.plan_partners.status end,
         dismissed = false;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.attest_age(p_birthdate date)
 RETURNS public.age_status
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_user_id     uuid;
  v_current     public.age_status;
  v_years       integer;
  v_new_status  public.age_status;
begin
  select id, age_status into v_user_id, v_current
    from public.users where auth_id = auth.uid();

  if v_user_id is null then
    raise exception 'No account for this session.' using errcode = 'insufficient_privilege';
  end if;

  if p_birthdate is null or p_birthdate > current_date then
    raise exception 'A valid date of birth is required.' using errcode = 'check_violation';
  end if;

  v_years := extract(year from age(current_date, p_birthdate));

  -- §2.8: "Under 13: refuse the account outright and say why. This is a COPPA line,
  -- not a product preference."
  if v_years < 13 then
    raise exception
      'Groundwork requires an account holder to be at least 13 years old.'
      using errcode = 'check_violation';
  end if;

  -- §2.8: a downgrade to minor is sticky. Self-attestation can never move an account
  -- OUT of minor — that needs human review. Attesting is idempotent-ish in the
  -- restrictive direction only.
  if v_current = 'minor' then
    return 'minor';
  end if;

  -- §2.8: "Minor status is granted on self-attestation alone because it is the
  -- restrictive direction — claiming to be a minor cannot be used to gain access.
  -- Adult status is not." 18+ self-attestation reaches self_attested_adult, never
  -- adult; only the Stripe Identity webhook can set adult (§2.9).
  v_new_status := case when v_years < 18 then 'minor' else 'self_attested_adult' end;

  update public.users
     set age_status            = v_new_status,
         age_status_set_at     = now(),
         birthdate_attested_at = now(),
         -- §15.2: a 13-17 account enters consent_status = pending and stays
         -- fail-closed until a guardian completes consent (phase 3).
         consent_status        = case when v_new_status = 'minor'
                                      then 'pending'::public.consent_status
                                      else 'not_required'::public.consent_status end,
         consent_status_set_at = now()
   where id = v_user_id;

  return v_new_status;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.can_create_club()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select private.viewer_may_create_club();
$function$
;

CREATE OR REPLACE FUNCTION public.cancel_account_deletion()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  update public.users
     set deletion_requested_at = null, is_banned = false, banned_at = null, banned_reason = null
   where id = v_me
     and deletion_requested_at is not null
     and banned_reason = 'account_deletion'
     and deletion_requested_at > now() - interval '30 days';
  if not found then
    raise exception 'There is no deletion to cancel.' using errcode = 'no_data_found';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.cancel_club_event(p_event_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;

  update public.club_events e set cancelled_at = now()
   where e.id = p_event_id and e.cancelled_at is null
     and exists (select 1 from public.clubs c where c.id = e.club_id and c.organizer_id = v_me);
  if not found then
    raise exception 'Only the club organizer can cancel a session.' using errcode = 'insufficient_privilege';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.cancel_rsvp(p_event_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;

  perform 1 from public.club_events where id = p_event_id for update;
  if not found then return; end if;

  update public.club_event_rsvps set status = 'cancelled', waitlist_position = null
   where club_event_id = p_event_id and user_id = v_me and status in ('going', 'waitlisted');

  perform private.promote_waitlist(p_event_id);     -- fills a freed seat, and renumbers the queue
end;
$function$
;

CREATE OR REPLACE FUNCTION public.cancel_session(p_session_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if (select private.current_user_id()) is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  update public.sessions s set status = 'cancelled'
   where s.id = p_session_id and s.status = 'agreed' and private.viewer_in_session(s.id);
  if not found then
    raise exception 'There is no upcoming session here to cancel.' using errcode = 'no_data_found';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.checkin_card(p_thread uuid)
 RETURNS TABLE(session_id uuid, partner_name text, near_label text, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select n.session_id,
         coalesce((select nullif(btrim(pr.display_name), '') from public.thread_participants tp
                     join public.profiles pr on pr.user_id = tp.user_id
                    where tp.thread_id = p_thread and tp.role = 'member' and tp.user_id <> (select private.current_user_id()) limit 1), 'Your partner'),
         n.near_label, n.created_at
    from public.checkin_nudges n
   where n.thread_id = p_thread
     and n.created_at > now() - interval '3 hours'
     and (select not private.viewer_is_banned())
     and exists (select 1 from public.thread_participants me where me.thread_id = p_thread and me.user_id = (select private.current_user_id()) and me.role = 'member')
   order by n.created_at desc
   limit 1;
$function$
;

CREATE OR REPLACE FUNCTION public.claim_guardian_invitation(p_token text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_invitation public.guardian_invitations%rowtype;
  v_guardian_user_id uuid;
  v_guardian_age public.age_status;
  v_guardian_id uuid;
  v_link_id uuid;
begin
  select id, age_status into v_guardian_user_id, v_guardian_age from public.users where auth_id = auth.uid();
  if v_guardian_user_id is null then
    raise exception 'Sign in before accepting a guardian invitation.'
      using errcode = 'insufficient_privilege';
  end if;
  if v_guardian_age not in ('self_attested_adult', 'adult') then
    raise exception 'A parent or guardian needs an adult account.'
      using errcode = 'insufficient_privilege';
  end if;

  select * into v_invitation from public.guardian_invitations
   where token_hash = encode(sha256(p_token::bytea), 'hex')
     and accepted_at is null
     and superseded_at is null
     and expires_at > now();

  if v_invitation.id is null then
    raise exception 'That invitation link is not valid any more.'
      using errcode = 'check_violation';
  end if;

  -- A minor must never be their own guardian.
  if v_invitation.minor_user_id = v_guardian_user_id then
    raise exception 'A guardian cannot be the same account as the young person.'
      using errcode = 'check_violation';
  end if;

  insert into public.guardians (user_id, first_name, last_name, email, phone)
  values (v_guardian_user_id, v_invitation.guardian_first_name,
          v_invitation.guardian_last_name, v_invitation.guardian_email,
          v_invitation.guardian_phone)
  on conflict (user_id) do update set email = excluded.email
  returning id into v_guardian_id;

  insert into public.guardian_links (guardian_id, minor_user_id, status)
  values (v_guardian_id, v_invitation.minor_user_id, 'pending')
  returning id into v_link_id;

  update public.guardian_invitations set accepted_at = now() where id = v_invitation.id;

  return v_link_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.clear_checkin_sharing(p_session uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  update public.session_participants set checkin_opt_in = false, checkin_until = null
   where session_id = p_session and user_id = v_me and checkin_opt_in;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.clear_live_map()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  update public.profiles set live_map_visible_until = null where user_id = v_me and live_map_visible_until is not null;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.clear_live_map_on_minor_downgrade()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if new.age_status = 'minor' and coalesce(old.age_status, 'unverified') <> 'minor' then
    update public.profiles
       set live_map_visible_until = null
     where user_id = new.id
       and live_map_visible_until is not null;
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.club_board(p_club uuid, p_basis text DEFAULT 'month'::text)
 RETURNS TABLE(rank integer, display_name text, sessions integer, is_me boolean, total integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if p_basis not in ('month', 'all') then
    raise exception 'Choose This month or All time.' using errcode = 'check_violation';
  end if;
  -- 1. The organizer's flag.
  if not exists (select 1 from public.clubs where id = p_club and show_leaderboard) then return; end if;
  -- Only people in the club read its board.
  if not (private.viewer_is_club_member(p_club)
          or exists (select 1 from public.clubs where id = p_club and organizer_id = v_me)) then return; end if;
  -- 2-4. Opt-out, visibility and bans are applied inside ranked_members.
  return query
    select m.rank, m.display_name, m.sessions, (m.user_id = v_me), m.total
      from private.ranked_members(p_club, p_basis) m
     where m.rank <= 10
     order by m.rank;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.confirm_activity_log(p_log_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me      uuid := private.current_user_id();
  v_log     public.activity_logs%rowtype;
  v_plan    uuid;
  v_session uuid;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  select * into v_log from public.activity_logs where id = p_log_id and user_id = v_me for update;
  if v_log.id is null then
    raise exception 'That activity is not yours to confirm.' using errcode = 'no_data_found';
  end if;
  if v_log.source <> 'auto_sync' then
    raise exception 'Only a synced activity needs confirming.' using errcode = 'check_violation';
  end if;
  if v_log.confirmed then return v_log.plan_id; end if;

  if v_log.plan_id is null then
    v_plan := private.plan_for_log(v_me, v_log);
    if v_plan is not null then
      v_session := public.mark_plan_complete(v_plan, (v_log.started_at at time zone (select timezone from public.plans where id = v_plan))::date);
    end if;
  end if;

  update public.activity_logs
     set confirmed = true, plan_id = coalesce(plan_id, v_plan), session_id = coalesce(session_id, v_session)
   where id = p_log_id;
  return coalesce(v_log.plan_id, v_plan);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.confirm_qr(p_code text, p_acknowledged boolean DEFAULT false, p_via text DEFAULT 'qr_scan'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me     uuid := private.current_user_id();
  u        record;
  v_r      jsonb;
  v_g      jsonb;
  v_target uuid;
  v_club   uuid;
  v_name   text;
  v_via    public.club_join_source;
  m        public.matches%rowtype;
  v_match  uuid;
  v_status text;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  select age_status, consent_status into u from public.users where id = v_me;
  v_r := private.resolve_code(p_code);
  if v_r is null then
    raise exception 'That code isn''t valid.' using errcode = 'no_data_found';
  end if;

  -- ---- a club: one tap, no second confirm (a club is not a person who has to consent to being met) ----
  if v_r ->> 'kind' = 'club' then
    if u.age_status = 'minor' and u.consent_status <> 'granted' then
      raise exception 'Your guardian needs to finish approving your account before you can join a club.' using errcode = 'insufficient_privilege';
    end if;
    v_club := (v_r ->> 'club_id')::uuid;
    -- S3: an unverified or 13-17 account joins through the minor-safe route; an adult records how they joined.
    v_via := case when u.age_status in ('unverified', 'minor') then 'minor_safe_route'
                  when p_via = 'invite_code' then 'invite_code' else 'qr_scan' end;
    insert into public.club_memberships (club_id, user_id, joined_via) values (v_club, v_me, v_via) on conflict do nothing;
    select name into v_name from public.clubs where id = v_club;
    return jsonb_build_object('kind', 'club', 'status', 'joined', 'club_id', v_club, 'name', v_name);
  end if;

  -- ---- a person ----
  v_target := (v_r ->> 'person_id')::uuid;
  v_g := private.qr_gate(v_me, v_target);
  if not (v_g ->> 'ok')::boolean then
    raise exception '%', v_g ->> 'reason' using errcode = 'insufficient_privilege';
  end if;
  select display_name into v_name from public.profiles where user_id = v_target;

  if v_g ->> 'mode' = 'minor_adult' and not coalesce(p_acknowledged, false) then
    raise exception 'Please read and acknowledge how connecting with an adult works first.' using errcode = 'check_violation';
  end if;

  select * into m from public.matches mm
   where mm.deleted_at is null
     and least(mm.requester_id, mm.recipient_id) = least(v_me, v_target)
     and greatest(mm.requester_id, mm.recipient_id) = greatest(v_me, v_target)
   for update;

  if m.id is not null and m.status = 'matched' then
    return jsonb_build_object('kind', 'person', 'status', 'matched', 'match_id', m.id, 'name', coalesce(v_name, 'this person'));
  end if;

  if m.id is not null and m.status = 'pending' and m.requester_id = v_target then
    -- They scanned me first: my scan is the second confirm, so both have now tapped.
    update public.matches set recipient_confirmed_at = now() where id = m.id;
    v_status := private.advance_qr_match(m.id);
    return jsonb_build_object('kind', 'person', 'status', v_status, 'match_id', m.id, 'name', coalesce(v_name, 'this person'));
  end if;

  if m.id is not null and m.status = 'pending' then
    return jsonb_build_object('kind', 'person', 'status', 'pending', 'match_id', m.id, 'name', coalesce(v_name, 'this person'));
  end if;

  -- Over the weekly cap: queued for review, not created and not refused (15.7).
  if coalesce((v_g ->> 'hold')::boolean, false) then
    if not exists (select 1 from public.minor_adult_matches
                    where minor_user_id = v_me and adult_user_id = v_target and state = 'held') then
      insert into public.minor_adult_matches (minor_user_id, adult_user_id, formed_via, shared_club_id, state)
      values (v_me, v_target, 'qr_scan', (v_g ->> 'club_id')::uuid, 'held');
    end if;
    return jsonb_build_object('kind', 'person', 'status', 'held', 'name', coalesce(v_name, 'this person'));
  end if;

  perform set_config('groundwork.minor_match_gate', 'on', true);
  if m.id is not null then
    -- A declined pair: the same rule as Discover - the person who scanned now stands as the requester, awaiting the other.
    update public.matches
       set status = 'pending', requester_id = v_me, recipient_id = v_target, requested_at = now(), source = 'qr_scan', recipient_confirmed_at = null
     where id = m.id
    returning id into v_match;
    delete from public.guardian_connection_approvals where match_id = v_match;
  else
    insert into public.matches (requester_id, recipient_id, status, source)
    values (v_me, v_target, 'pending', 'qr_scan')
    returning id into v_match;
  end if;
  perform set_config('groundwork.minor_match_gate', 'off', true);

  if v_g ->> 'mode' = 'minor_adult' then
    insert into public.minor_adult_matches (minor_user_id, adult_user_id, match_id, formed_via, shared_club_id, state)
    values (v_me, v_target, v_match, 'qr_scan', (v_g ->> 'club_id')::uuid, 'active');
    if coalesce((v_g ->> 'approval_required')::boolean, false) then
      insert into public.guardian_connection_approvals (match_id, guardian_link_id, minor_user_id)
      values (v_match, (v_g ->> 'link_id')::uuid, v_me);
    end if;
  end if;

  return jsonb_build_object('kind', 'person', 'status', 'pending', 'match_id', v_match, 'name', coalesce(v_name, 'this person'));
end;
$function$
;

CREATE OR REPLACE FUNCTION public.connection_names(p_ids uuid[])
 RETURNS TABLE(user_id uuid, display_name text, neighborhood text, neighborhood_name text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select p.user_id,
         p.display_name,
         case when u.age_status = 'minor' then null else p.neighborhood end,
         case when u.age_status = 'minor' then null else n.name end
    from public.profiles p
    join public.users u on u.id = p.user_id
    left join public.neighborhoods n on n.slug = p.neighborhood
   where p.user_id = any (p_ids)
     and not u.is_banned
     and not (select private.viewer_is_banned())
     and exists (
       select 1 from public.matches m
        where m.deleted_at is null
          and ((m.requester_id = private.current_user_id() and m.recipient_id = p.user_id)
            or (m.recipient_id = private.current_user_id() and m.requester_id = p.user_id)));
$function$
;

CREATE OR REPLACE FUNCTION public.create_club(p_name text, p_description text, p_organizer_label text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me    uuid := private.current_user_id();
  v_label text;
  v_id    uuid;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  -- One message for every reason, so this cannot be used to learn who is approved.
  if not private.viewer_may_create_club() then
    raise exception 'Creating a club is not available on this account.' using errcode = 'insufficient_privilege';
  end if;
  if coalesce(btrim(p_name), '') = '' or char_length(btrim(p_name)) > 80 then
    raise exception 'Give the club a name of up to 80 characters.' using errcode = 'check_violation';
  end if;
  if char_length(coalesce(p_description, '')) > 1000 then
    raise exception 'The description can be up to 1000 characters.' using errcode = 'check_violation';
  end if;
  if char_length(coalesce(p_organizer_label, '')) > 80 then
    raise exception 'The organizer line can be up to 80 characters.' using errcode = 'check_violation';
  end if;

  v_label := nullif(btrim(p_organizer_label), '');
  if v_label is null then
    select 'Organized by ' || coalesce(pr.display_name, 'a member') into v_label
      from public.profiles pr where pr.user_id = v_me;
  end if;

  insert into public.clubs (name, description, organizer_label, organizer_id)
  values (btrim(p_name), coalesce(btrim(p_description), ''), coalesce(v_label, ''), v_me)
  returning id into v_id;
  return v_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_plan(p_activity_type public.activity_type, p_other_label text, p_label text, p_recurrence public.plan_recurrence, p_day_of_week integer, p_start_time time without time zone, p_timezone text, p_end_condition public.plan_end_condition, p_end_after_weeks integer, p_linked_template_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
  v_id uuid;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if coalesce(btrim(p_label), '') = '' or char_length(btrim(p_label)) > 80 then
    raise exception 'Give the plan a name of up to 80 characters.' using errcode = 'check_violation';
  end if;
  if p_day_of_week is null or p_day_of_week not between 0 and 6 or p_start_time is null then
    raise exception 'Choose a day and a time.' using errcode = 'check_violation';
  end if;
  if p_timezone is null or not exists (select 1 from pg_catalog.pg_timezone_names where name = p_timezone) then
    raise exception 'That time zone is not recognised.' using errcode = 'check_violation';
  end if;
  if p_linked_template_id is not null
     and not exists (select 1 from public.workout_templates where id = p_linked_template_id and owner_id = v_me) then
    raise exception 'That template is not yours.' using errcode = 'check_violation';
  end if;

  insert into public.plans (owner_id, activity_type, other_label, label, recurrence, day_of_week, start_time,
                            timezone, end_condition, end_after_weeks, starts_on, linked_template_id)
  values (v_me, p_activity_type,
          case when p_activity_type = 'other' then nullif(btrim(p_other_label), '') end,
          btrim(p_label), p_recurrence, p_day_of_week, p_start_time, p_timezone, p_end_condition,
          case when p_end_condition = 'after_n_weeks' then p_end_after_weeks end,
          private.next_plan_date(p_day_of_week, p_start_time, p_timezone), p_linked_template_id)
  returning id into v_id;
  return v_id;
exception when check_violation then
  -- The table CHECKs say what is wrong in database terms; say it plainly.
  if sqlerrm like '%plan_other_label_matches%' then
    raise exception 'Name the activity for "other".' using errcode = 'check_violation';
  elsif sqlerrm like '%plan_end_matches%' or sqlerrm like '%end_after_weeks%' then
    raise exception 'A plan that ends after some weeks needs between 1 and 52.' using errcode = 'check_violation';
  end if;
  raise;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_template(p_name text, p_summary text, p_activity_type public.activity_type, p_sets jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
  v_id uuid;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if coalesce(btrim(p_name), '') = '' or char_length(btrim(p_name)) > 80 then
    raise exception 'Give the template a name of up to 80 characters.' using errcode = 'check_violation';
  end if;
  if p_activity_type is null then
    raise exception 'Choose an activity type.' using errcode = 'check_violation';
  end if;

  insert into public.workout_templates (owner_id, name, summary, activity_type)
  values (v_me, btrim(p_name), coalesce(btrim(p_summary), ''), p_activity_type)
  returning id into v_id;

  perform private.write_template_sets(v_id, p_sets);
  return v_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.decline_match(p_match_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or private.viewer_is_banned() then
    raise exception 'Not available.' using errcode = 'insufficient_privilege';
  end if;

  update public.matches set status = 'declined'
   where id = p_match_id and recipient_id = v_me and status = 'pending' and deleted_at is null;

  if not found then
    raise exception 'There is no request here for you to decline.' using errcode = 'no_data_found';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.decline_shared_template(p_message_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me    uuid := private.current_user_id();
  v_share record;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;

  select * into v_share from private.share_for_recipient(p_message_id);
  if v_share.sender_id is null then
    raise exception 'That template is not available.' using errcode = 'no_data_found';
  end if;

  insert into public.template_share_responses (message_id, user_id, response)
  values (p_message_id, v_me, 'declined')
  on conflict (message_id, user_id) do nothing;
  if not found then
    raise exception 'You have already answered this.' using errcode = 'check_violation';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_activity_log(p_log_id uuid)
 RETURNS text[]
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me    uuid := private.current_user_id();
  v_paths text[];
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if not exists (select 1 from public.activity_logs where id = p_log_id and user_id = v_me) then
    raise exception 'That activity is not yours to delete.' using errcode = 'no_data_found';
  end if;
  select coalesce(array_agg(storage_path), '{}') into v_paths from public.activity_photos where activity_log_id = p_log_id;
  delete from public.activity_logs where id = p_log_id and user_id = v_me;
  return v_paths;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_match(p_match_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me  uuid := private.current_user_id();
  v_req uuid;
  v_rec uuid;
begin
  if v_me is null or private.viewer_is_banned() then
    raise exception 'Not available.' using errcode = 'insufficient_privilege';
  end if;

  update public.matches set deleted_at = now()
   where id = p_match_id
     and status = 'matched'
     and deleted_at is null
     and v_me in (requester_id, recipient_id)
  returning requester_id, recipient_id into v_req, v_rec;

  if v_req is null then
    raise exception 'There is no match here to delete.' using errcode = 'no_data_found';
  end if;

  -- S9 / §2.5: the conversation is KEPT. It is only flagged.
  update public.chat_threads set archived = true where match_id = p_match_id;

  -- §2.1: "Deleting a match clears request/plan-partner state across every plan the person appears on."
  perform private.clear_plan_partners_between(v_req, v_rec);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_plan(p_plan_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  delete from public.plans where id = p_plan_id and owner_id = v_me;
  if not found then
    raise exception 'That plan is not yours to delete.' using errcode = 'no_data_found';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_template(p_template_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  delete from public.workout_templates where id = p_template_id and owner_id = v_me;
  if not found then
    raise exception 'That template is not yours to delete.' using errcode = 'no_data_found';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.discover_filter_pools()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select jsonb_build_object(
    'sports', coalesce((
       select jsonb_agg(label order by lower(label)) from (
         select distinct on (lower(label)) label from (
           select tag as label from public.profile_sports where is_primary
           union all
           select label from public.custom_tags
         ) both_sources
         order by lower(label), label
       ) s), '[]'::jsonb),
    'genders', coalesce((
       select jsonb_agg(g order by lower(g)) from (
         select distinct gender as g from public.profiles where gender is not null and btrim(gender) <> ''
       ) x), '[]'::jsonb)
  )
$function$
;

CREATE OR REPLACE FUNCTION public.discover_map_pins()
 RETURNS TABLE(user_id uuid, display_name text, neighborhood text, lat double precision, lon double precision, is_self boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
  select p.user_id,
         p.display_name,
         p.neighborhood,
         extensions.st_y(p.home_point::extensions.geometry),
         extensions.st_x(p.home_point::extensions.geometry),
         (p.user_id = (select private.current_user_id()))
    from public.profiles p
   where p.home_point is not null
     and p.live_map_visible_until is not null
     and p.live_map_visible_until > now()
$function$
;

CREATE OR REPLACE FUNCTION public.discover_people(p_filters jsonb DEFAULT '{}'::jsonb, p_limit integer DEFAULT 30, p_offset integer DEFAULT 0)
 RETURNS TABLE(user_id uuid, display_name text, neighborhood text, neighborhood_name text, distance_mi numeric, gender text, experience_level public.experience_level, preferred_group_size public.group_size, typical_session_length public.session_length, id_verified boolean, photo_verified boolean, bio text, headline_accomplishment text, years_training integer, training_for text, tags text[], mutual_count integer, match_state text)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
  with me as (
    select p.user_id,
           p.home_point,
           p.experience_level,
           coalesce((select array_agg(lower(ps.tag)) from public.profile_sports ps
                      where ps.profile_id = p.user_id), '{}'::text[]) as tags,
           (select count(*) from public.availability a where a.profile_id = p.user_id) as cells
      from public.profiles p
     where p.user_id = (select private.current_user_id())
  ),
  f as (
    select nullif(btrim(p_filters ->> 'sportTag'), '')                       as sport,
           nullif(p_filters ->> 'duration', '')::public.session_length        as duration,
           nullif(p_filters ->> 'radius', '')::numeric                        as radius,
           nullif(btrim(p_filters ->> 'gender'), '')                          as gender,
           nullif(p_filters ->> 'experience', '')::public.experience_level    as experience,
           nullif(p_filters ->> 'availability', '')                           as availability,
           nullif(p_filters ->> 'groupSize', '')::public.group_size           as group_size,
           coalesce((p_filters ->> 'verifiedOnly')::boolean, false)           as verified_only,
           coalesce((p_filters ->> 'mutualOnly')::boolean, false)             as mutual_only,
           coalesce((p_filters ->> 'verifiedPhoto')::boolean, false)          as verified_photo,
           nullif(p_filters ->> 'userId', '')::uuid                           as only_user
  ),
  cand as (
    select p.*,
           case when me.home_point is null or p.home_point is null then null
                else round((extensions.st_distance(p.home_point, me.home_point) / 1609.344)::numeric, 1)
           end as dist,
           private.mutual_partner_count(me.user_id, p.user_id) as mutual,
           m.status        as m_status,
           m.requester_id  as m_requester
      from public.profiles p
      cross join me
      left join public.matches m
        on m.deleted_at is null
       and least(m.requester_id, m.recipient_id) = least(me.user_id, p.user_id)
       and greatest(m.requester_id, m.recipient_id) = greatest(me.user_id, p.user_id)
     where p.user_id <> me.user_id
  )
  select c.user_id,
         c.display_name,
         c.neighborhood,
         (select n.name from public.neighborhoods n where n.slug = c.neighborhood),
         c.dist,
         c.gender,
         c.experience_level,
         c.preferred_group_size,
         c.typical_session_length,
         c.id_verified,
         c.photo_verified,
         c.bio,
         c.headline_accomplishment,
         c.years_training,
         c.training_for,
         (select array_agg(ps.tag order by ps.is_primary desc, ps.tag)
            from public.profile_sports ps where ps.profile_id = c.user_id) as tags,
         c.mutual,
         case
           when c.m_status is null                                        then 'none'
           when c.m_status = 'matched'                                    then 'matched'
           when c.m_status = 'pending'  and c.m_requester = me.user_id    then 'requested'
           when c.m_status = 'pending'                                    then 'incoming'
           when c.m_status = 'declined' and c.m_requester = me.user_id    then 'requested'
           else 'none'
         end as match_state
    from cand c
    cross join me
    cross join f
   where (f.only_user is null or c.user_id = f.only_user)
     and (f.sport is null or exists (select 1 from public.profile_sports ps
            where ps.profile_id = c.user_id and lower(ps.tag) = lower(f.sport)))
     and (f.duration     is null or c.typical_session_length = f.duration)
     and (f.radius       is null or (c.dist is not null and c.dist <= f.radius))
     and (f.gender       is null or lower(c.gender) = lower(f.gender))
     and (f.experience   is null or c.experience_level = f.experience)
     and (f.availability is null or exists (select 1 from public.availability a
            where a.profile_id = c.user_id
              and case when f.availability = 'weekend' then a.day_of_week in (0, 6)
                       else a.time_block::text = f.availability end))
     and (f.group_size   is null or c.preferred_group_size = f.group_size)
     and (not f.verified_only  or c.id_verified)
     and (not f.verified_photo or c.photo_verified)
     and (not f.mutual_only    or c.mutual > 0)
   -- Rule-based scoring (§2.1: "hand-tuned filter-and-score on schedule overlap, pace/experience
   -- compatibility, distance radius, and activity type" — no ML). Out of 100:
   --   40 activity     shares at least one activity with the viewer
   --   30 schedule     share of the viewer's availability cells the candidate also has
   --   20 experience   same level 20, adjacent level 10
   --   10 distance     linear over the first 10 miles
   -- The score is used to ORDER only and is not returned: it would let a client reverse-engineer
   -- who the viewer is most compatible with across the whole pool.
   order by
     (case when exists (select 1 from public.profile_sports ps
                         where ps.profile_id = c.user_id and lower(ps.tag) = any (me.tags))
           then 40 else 0 end)
     + (case when me.cells = 0 then 0 else 30 * least(1.0,
          (select count(*) from public.availability a
             join public.availability b on b.day_of_week = a.day_of_week and b.time_block = a.time_block
            where a.profile_id = c.user_id and b.profile_id = me.user_id)::numeric / me.cells) end)
     + (case when c.experience_level is null or me.experience_level is null then 0
             when c.experience_level = me.experience_level then 20
             when abs(array_position(enum_range(null::public.experience_level), c.experience_level)
                    - array_position(enum_range(null::public.experience_level), me.experience_level)) = 1 then 10
             else 0 end)
     + (case when c.dist is null then 0 else 10 * (1 - least(c.dist, 10) / 10) end)
     desc,
     c.display_name, c.user_id
   limit least(greatest(coalesce(p_limit, 30), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0)
$function$
;

CREATE OR REPLACE FUNCTION public.dismiss_plan_partner(p_plan_id uuid, p_partner_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if not exists (select 1 from public.plans where id = p_plan_id and owner_id = v_me) then
    raise exception 'That plan is not yours to change.' using errcode = 'insufficient_privilege';
  end if;
  update public.plan_partners set dismissed = true
   where plan_id = p_plan_id and user_id = p_partner_id and status = 'declined';
  if not found then
    raise exception 'Only a partner who declined can be dismissed.' using errcode = 'check_violation';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.due_account_deletions()
 RETURNS TABLE(user_id uuid, auth_id uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select u.id, u.auth_id from public.users u
   where u.deletion_requested_at <= now() - interval '30 days'
   order by u.deletion_requested_at
   limit 20;
$function$
;

CREATE OR REPLACE FUNCTION public.enforce_minor_live_map_exclusion()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if new.live_map_visible_until is not null then
    if (select age_status from public.users where id = new.user_id) = 'minor' then
      raise exception
        'A minor account can never appear on the live map (build brief §5.8, §15.8).'
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.erase_account(p_user uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_auth uuid;
begin
  select auth_id into v_auth from public.users where id = p_user and deletion_requested_at <= now() - interval '30 days';
  if v_auth is null then
    raise exception 'That account is not due for deletion.' using errcode = 'no_data_found';
  end if;

  -- The other person keeps the conversation, now under "Archived chats".
  update public.chat_threads set archived = true
   where id in (select thread_id from public.thread_participants where user_id = p_user and role = 'member');

  -- Everything that cascades from the auth user goes with it: profile, matches, plans, logs, tokens, records, memberships...
  -- Messages and reports are kept with their link to the person cut (0042).
  delete from auth.users where id = v_auth;

  -- A conversation nobody is left in can never be opened again.
  delete from public.chat_threads t
   where not exists (select 1 from public.thread_participants p where p.thread_id = t.id and p.role = 'member');

  perform private.purge_old_reports();
end;
$function$
;

CREATE OR REPLACE FUNCTION public.expire_unconsented_minors()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare v_deleted integer;
begin
  with doomed as (
    select u.id, u.auth_id
      from public.users u
     where u.age_status = 'minor'
       and u.consent_status in ('pending', 'revoked')
       and u.created_at < now() - interval '30 days'
  )
  delete from auth.users a using doomed d where a.id = d.auth_id;

  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.generate_personal_qr_code(p_display_name text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_slug text;
begin
  v_slug := upper(regexp_replace(coalesce(p_display_name, ''), '[^a-zA-Z0-9]', '', 'g'));
  v_slug := nullif(left(v_slug, 12), '');
  return 'GW-P-' || coalesce(v_slug, 'MEMBER') || '-' ||
         lpad((floor(random() * 10000))::int::text, 4, '0');
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_session_proposal(p_proposal_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
  v_p  public.session_proposals%rowtype;
  v_other uuid;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  select * into v_p from public.session_proposals where id = p_proposal_id and v_me in (proposer_id, recipient_id);
  if v_p.id is null then
    raise exception 'That proposal is not available.' using errcode = 'no_data_found';
  end if;
  v_other := case when v_p.proposer_id = v_me then v_p.recipient_id else v_p.proposer_id end;
  if not private.user_is_not_banned(v_other) then
    raise exception 'That proposal is not available.' using errcode = 'no_data_found';
  end if;
  return jsonb_build_object(
    'status', v_p.status,
    'proposed_start', v_p.proposed_start,
    'timezone', v_p.timezone,
    'activity_type', v_p.activity_type,
    'is_mine', v_p.proposer_id = v_me,
    'other_name', (select display_name from public.profiles where user_id = v_other),
    'session_id', v_p.session_id
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_shared_template(p_message_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me     uuid := private.current_user_id();
  v_share  record;
  v_t      public.workout_templates%rowtype;
  v_resp   public.template_response;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;

  select * into v_share from private.share_for_recipient(p_message_id);
  if v_share.sender_id is null then
    raise exception 'That template is not available.' using errcode = 'no_data_found';
  end if;

  select response into v_resp from public.template_share_responses where message_id = p_message_id and user_id = v_me;
  select * into v_t from public.workout_templates where id = v_share.template_id and owner_id = v_share.sender_id;

  if v_t.id is null then
    return jsonb_build_object('available', false, 'response', v_resp);
  end if;

  return jsonb_build_object(
    'available', true,
    'response', v_resp,
    'name', v_t.name,
    'summary', v_t.summary,
    'activity_type', v_t.activity_type,
    'sets', coalesce((select jsonb_agg(jsonb_build_object(
                        'exercise', s.exercise, 'target_detail', s.target_detail,
                        'weight', s.weight, 'weight_unit', s.weight_unit, 'reps', s.reps,
                        'duration_seconds', s.duration_seconds, 'pace_seconds', s.pace_seconds, 'pace_unit', s.pace_unit,
                        'distance', s.distance, 'distance_unit', s.distance_unit)
                      order by s.position)
                        from public.template_sets s where s.template_id = v_t.id), '[]'::jsonb)
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.grant_guardian_consent(p_link_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_link public.guardian_links%rowtype;
  v_verified_at timestamptz;
  v_guardian_age public.age_status;
begin
  select l.* into v_link
    from public.guardian_links l
    join public.guardians g on g.id = l.guardian_id
    join public.users u on u.id = g.user_id
   where l.id = p_link_id and u.auth_id = auth.uid();

  if v_link.id is null then
    raise exception 'No such guardian link for this account.'
      using errcode = 'insufficient_privilege';
  end if;

  select g.verified_at, u.age_status into v_verified_at, v_guardian_age
    from public.guardians g join public.users u on u.id = g.user_id where g.id = v_link.guardian_id;
  -- 15.2: the ID check is not optional, and the person who passed it must be an adult.
  if v_verified_at is null or v_guardian_age is distinct from 'adult' then
    raise exception 'Complete the identity check before giving consent.'
      using errcode = 'check_violation';
  end if;

  update public.guardian_links
     set status = 'active', consented_at = now(), revoked_at = null
   where id = p_link_id;

  update public.users
     set consent_status = 'granted', consent_status_set_at = now()
   where id = v_link.minor_user_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.guardian_decide_connection(p_approval_id uuid, p_approve boolean)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  a public.guardian_connection_approvals%rowtype;
  v_status text;
begin
  select ap.* into a
    from public.guardian_connection_approvals ap
    join public.guardian_links l on l.id = ap.guardian_link_id and l.status = 'active'
    join public.guardians g on g.id = l.guardian_id
    join public.users gu on gu.id = g.user_id
   where ap.id = p_approval_id and gu.auth_id = auth.uid() and not gu.is_banned
   for update of ap;
  if a.id is null then
    raise exception 'There is no connection here for you to decide.' using errcode = 'insufficient_privilege';
  end if;
  if a.status <> 'pending' then
    raise exception 'This connection has already been decided.' using errcode = 'check_violation';
  end if;

  update public.guardian_connection_approvals
     set status = case when p_approve then 'approved' else 'denied' end, decided_at = now()
   where id = a.id;

  v_status := private.advance_qr_match(a.match_id);
  if not p_approve then
    perform set_config('groundwork.minor_match_gate', 'on', true);
    update public.matches set status = 'declined' where id = a.match_id and status = 'pending';
    perform set_config('groundwork.minor_match_gate', 'off', true);
    v_status := 'declined';
  end if;
  return v_status;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.guardian_minor_overview()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_out jsonb := '[]'::jsonb;
  l     record;
begin
  if not exists (select 1 from public.users where auth_id = auth.uid() and not is_banned) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;

  for l in
    select gl.id as link_id, gl.minor_user_id, coalesce(p.display_name, 'Your child') as minor_name
      from public.guardian_links gl
      join public.guardians g on g.id = gl.guardian_id
      join public.users gu on gu.id = g.user_id and gu.auth_id = auth.uid() and not gu.is_banned
      left join public.profiles p on p.user_id = gl.minor_user_id
     where gl.status = 'active'
     order by p.display_name
  loop
    v_out := v_out || jsonb_build_object(
      'link_id', l.link_id,
      'minor_name', l.minor_name,
      'clubs', coalesce((
        select jsonb_agg(jsonb_build_object('name', c.name) order by c.name)
          from public.club_memberships m join public.clubs c on c.id = m.club_id
         where m.user_id = l.minor_user_id), '[]'::jsonb),
      'sessions', coalesce((
        select jsonb_agg(s order by s ->> 'starts_at') from (
          select jsonb_build_object('kind', 'club', 'title', e.title, 'starts_at', e.starts_at, 'timezone', e.timezone,
                                    'where', nullif(e.location_label, ''), 'with_name', null, 'with_is_adult', null) as s
            from public.club_event_rsvps r join public.club_events e on e.id = r.club_event_id
           where r.user_id = l.minor_user_id and r.status = 'going' and e.cancelled_at is null and e.starts_at > now()
          union all
          select jsonb_build_object('kind', 'partner', 'title', initcap(ss.activity_type::text), 'starts_at', ss.starts_at, 'timezone', ss.timezone,
                                    'where', nullif(btrim(coalesce(nullif(prop.place, ''), pl.place, '')), ''),
                                    'with_name', coalesce(op.display_name, 'Someone'),
                                    'with_is_adult', (ou.age_status in ('self_attested_adult', 'adult')))
            from public.session_participants me
            join public.sessions ss on ss.id = me.session_id and ss.status = 'agreed' and ss.starts_at > now()
            join public.session_participants other on other.session_id = ss.id and other.user_id <> me.user_id
            join public.users ou on ou.id = other.user_id and not ou.is_banned
            left join public.profiles op on op.user_id = ou.id
            left join lateral (select p2.place from public.session_proposals p2 where p2.session_id = ss.id order by p2.created_at desc limit 1) prop on true
            left join public.plans pl on pl.id = ss.plan_id
           where me.user_id = l.minor_user_id and me.rsvp_status = 'confirmed' and other.rsvp_status in ('confirmed', 'invited')
          union all
          -- The next occurrence of a plan the minor owns or has confirmed on, when someone else is on it too. (A plan's occurrences are
          -- not session rows until they happen, so they are read from the plan.) A plan with nobody else on it is the minor's own
          -- training and is not a meetup.
          select jsonb_build_object('kind', 'plan', 'title', pl.label, 'starts_at', nx.start, 'timezone', pl.timezone,
                                    'where', nullif(btrim(pl.place), ''), 'with_name', w.names, 'with_is_adult', w.any_adult)
            from public.plans pl
            cross join lateral (select private.plan_next_start(pl) as start) nx
            cross join lateral (
              select string_agg(coalesce(pr.display_name, 'Someone'), ', ' order by pr.display_name) as names,
                     bool_or(u.age_status in ('self_attested_adult', 'adult')) as any_adult
                from (select pl.owner_id as uid
                      union all
                      select pp.user_id from public.plan_partners pp where pp.plan_id = pl.id and pp.status = 'confirmed' and not pp.dismissed) m
                join public.users u on u.id = m.uid and not u.is_banned and m.uid <> l.minor_user_id
                left join public.profiles pr on pr.user_id = u.id
            ) w
           where nx.start is not null and w.names is not null
             and (pl.owner_id = l.minor_user_id
                  or exists (select 1 from public.plan_partners pp
                              where pp.plan_id = pl.id and pp.user_id = l.minor_user_id and pp.status = 'confirmed' and not pp.dismissed))
        ) x), '[]'::jsonb));
  end loop;
  return v_out;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  insert into public.users (auth_id, email, phone)
  values (new.id, new.email, new.phone)
  on conflict (auth_id) do nothing;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.identity_check_begin(p_user uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  u        public.users%rowtype;
  g        public.guardians%rowtype;
  v_ref    text;
  v_n      integer;
  v_open   text;
begin
  select * into u from public.users where id = p_user;
  if u.id is null or u.is_banned then
    return jsonb_build_object('allowed', false, 'reason', 'unavailable', 'message', 'Verification isn''t available for this account.');
  end if;
  if u.age_status = 'minor' then
    return jsonb_build_object('allowed', false, 'reason', 'minor', 'message', 'ID verification is for adults.');
  end if;
  if u.age_status = 'unverified' then
    return jsonb_build_object('allowed', false, 'reason', 'age_not_attested', 'message', 'Confirm your date of birth first.');
  end if;

  select * into g from public.guardians where user_id = u.id;

  if u.age_status = 'adult' then
    -- Already ID-verified. If they are a guardian who has not been marked verified yet, that same check counts: no second $1.50.
    if g.id is not null and g.verified_at is null then
      select provider_reference_id into v_ref from public.verification_records
       where user_id = u.id and status = 'verified' and age_check_result = 'adult' order by verified_at desc limit 1;
      update public.guardians
         set verified_at = now(), verification_method = 'stripe_identity', provider_reference_id = coalesce(v_ref, 'existing-adult-check')
       where id = g.id;
    end if;
    return jsonb_build_object('allowed', false, 'reason', 'already_verified', 'message', 'You''re already verified.');
  end if;

  -- self_attested_adult from here on.
  select count(*) into v_n from public.verification_records where user_id = u.id and created_at > now() - interval '24 hours';
  if v_n >= 5 then
    return jsonb_build_object('allowed', false, 'reason', 'too_many', 'message', 'Too many attempts today. Please try again tomorrow.');
  end if;

  -- An unfinished check is reused rather than starting (and paying for) another.
  select provider_reference_id into v_open from public.verification_records
   where user_id = u.id and status in ('pending', 'requires_input') and created_at > now() - interval '20 hours'
   order by created_at desc limit 1;
  return jsonb_build_object('allowed', true, 'reuse_session_id', v_open);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.identity_check_register(p_user uuid, p_session_id text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if coalesce(p_session_id, '') !~ '^vs_[A-Za-z0-9_]{1,200}$' then
    raise exception 'That is not a verification session id.' using errcode = 'check_violation';
  end if;
  insert into public.verification_records (user_id, provider_reference_id) values (p_user, p_session_id)
  on conflict (provider_reference_id) do nothing;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.ingest_wearable_workout(p_user_id uuid, p_provider_slug text, p_external_id text, p_activity_type public.activity_type, p_title text, p_started_at timestamp with time zone, p_duration_seconds integer, p_distance_m numeric, p_calories integer, p_avg_hr integer, p_max_hr integer, p_cadence integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_dur   integer := case when p_duration_seconds between 1 and 86400 then p_duration_seconds end;
  v_km    numeric := case when p_activity_type <> 'other' and p_distance_m > 0 and p_distance_m <= 1000000
                          then round(p_distance_m / 1000.0, 3) end;
  v_cal   integer := case when p_calories between 0 and 30000 then p_calories end;
  v_avg   integer := case when p_avg_hr between 20 and 260 then p_avg_hr end;
  v_max   integer := case when p_max_hr between 20 and 260 then p_max_hr end;
  v_cad   integer := case when p_activity_type <> 'other' and p_cadence between 1 and 400 then p_cadence end;
  v_title text := left(coalesce(nullif(btrim(p_title), ''), initcap(p_activity_type::text)), 80);
  v_slug  text := left(lower(btrim(coalesce(p_provider_slug, ''))), 40);
  v_id    uuid;
begin
  if p_user_id is null or p_external_id is null or btrim(p_external_id) = '' or p_started_at is null or p_activity_type is null then
    return 'skipped';
  end if;
  if not exists (select 1 from public.users where id = p_user_id and not is_banned) then
    return 'skipped';
  end if;
  if p_started_at > now() + interval '5 minutes' or p_started_at < now() - interval '366 days' then
    return 'skipped';
  end if;
  if v_max is not null and v_avg is not null and v_max < v_avg then v_max := null; end if;

  -- Same provider id again: refresh the measurements. The person's confirmation and any plan link stay.
  update public.activity_logs
     set activity_type = p_activity_type, started_at = p_started_at,
         ended_at = case when v_dur is null then null else p_started_at + make_interval(secs => v_dur) end,
         duration_seconds = v_dur, distance = v_km, distance_unit = case when v_km is null then null else 'km' end,
         calories = v_cal, avg_hr = v_avg, max_hr = v_max, cadence = v_cad, device_provider = nullif(v_slug, '')
   where user_id = p_user_id and provider = 'aggregator' and external_activity_id = p_external_id
  returning id into v_id;
  if v_id is not null then return 'updated'; end if;

  -- The same workout from another source (or typed in by hand) is one row, not two.
  if exists (
    select 1 from public.activity_logs
     where user_id = p_user_id and activity_type = p_activity_type
       and started_at between p_started_at - interval '5 minutes' and p_started_at + interval '5 minutes'
  ) then
    return 'duplicate';
  end if;

  insert into public.activity_logs (user_id, source, provider, external_activity_id, device_provider, activity_type, title,
                                    started_at, ended_at, duration_seconds, distance, distance_unit, calories, avg_hr, max_hr,
                                    cadence, notes, confirmed)
  values (p_user_id, 'auto_sync', 'aggregator', p_external_id, nullif(v_slug, ''), p_activity_type, v_title,
          p_started_at, case when v_dur is null then null else p_started_at + make_interval(secs => v_dur) end,
          v_dur, v_km, case when v_km is null then null else 'km' end, v_cal, v_avg, v_max, v_cad, '', false);
  return 'inserted';
end;
$function$
;

CREATE OR REPLACE FUNCTION public.leaderboard_settings_overview()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  return jsonb_build_object(
    'visibility', private.visibility_of(v_me),
    'can_be_public', exists (select 1 from public.users where id = v_me and age_status in ('self_attested_adult', 'adult')),
    'clubs', coalesce((
      select jsonb_agg(jsonb_build_object(
               'club_id', c.id, 'name', c.name, 'is_organizer', c.organizer_id = v_me, 'show_leaderboard', c.show_leaderboard,
               'opted_out', exists (select 1 from public.club_leaderboard_opt_outs o where o.club_id = c.id and o.user_id = v_me)) order by c.name)
        from public.clubs c join public.club_memberships m on m.club_id = c.id and m.user_id = v_me), '[]'::jsonb));
end;
$function$
;

CREATE OR REPLACE FUNCTION public.leave_club(p_club_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me    uuid := private.current_user_id();
  v_event uuid;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;

  for v_event in
    select e.id from public.club_events e
     where e.club_id = p_club_id
       and exists (select 1 from public.club_event_rsvps r where r.club_event_id = e.id and r.user_id = v_me and r.status in ('going', 'waitlisted'))
     order by e.id
  loop
    perform 1 from public.club_events where id = v_event for update;
    update public.club_event_rsvps set status = 'cancelled', waitlist_position = null
     where club_event_id = v_event and user_id = v_me and status in ('going', 'waitlisted');
    perform private.promote_waitlist(v_event);
  end loop;

  delete from public.club_memberships where club_id = p_club_id and user_id = v_me;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.list_club_events(p_club_id uuid)
 RETURNS TABLE(id uuid, title text, starts_at timestamp with time zone, timezone text, location_label text, capacity integer, going_count integer, my_status public.rsvp_status, my_waitlist_position integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select e.id, e.title, e.starts_at, e.timezone, e.location_label, e.capacity,
         (select count(*)::integer from public.club_event_rsvps r
           join public.users u on u.id = r.user_id
          where r.club_event_id = e.id and r.status = 'going' and not u.is_banned),
         mine.status, mine.waitlist_position
    from public.club_events e
    left join public.club_event_rsvps mine
           on mine.club_event_id = e.id and mine.user_id = (select private.current_user_id())
   where e.club_id = p_club_id
     and e.cancelled_at is null
     and e.starts_at > now()
     and private.viewer_can_see_club(e.club_id)
   order by e.starts_at;
$function$
;

CREATE OR REPLACE FUNCTION public.list_clubs()
 RETURNS TABLE(id uuid, name text, description text, organizer_label text, member_count integer, is_member boolean, is_organizer boolean, next_event_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select c.id, c.name, c.description, c.organizer_label,
         -- A total only; banned and departed members are not counted, minors are counted but never listed.
         (select count(*)::integer from public.club_memberships m join public.users u on u.id = m.user_id
           where m.club_id = c.id and not u.is_banned),
         exists (select 1 from public.club_memberships m where m.club_id = c.id and m.user_id = (select private.current_user_id())),
         c.organizer_id = (select private.current_user_id()),
         (select min(e.starts_at) from public.club_events e
           where e.club_id = c.id and e.cancelled_at is null and e.starts_at > now())
    from public.clubs c
   where private.viewer_can_see_club(c.id)
   order by c.name;
$function$
;

CREATE OR REPLACE FUNCTION public.list_connection_approvals()
 RETURNS TABLE(approval_id uuid, minor_name text, adult_name text, club_name text, requested_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select ap.id,
         coalesce(mp.display_name, 'Your child'),
         coalesce(adp.display_name, 'An adult'),
         coalesce(c.name, 'a shared club'),
         ap.created_at
    from public.guardian_connection_approvals ap
    join public.guardian_links l on l.id = ap.guardian_link_id and l.status = 'active'
    join public.guardians g on g.id = l.guardian_id
    join public.users gu on gu.id = g.user_id
    join public.matches m on m.id = ap.match_id and m.deleted_at is null
    left join public.profiles mp on mp.user_id = ap.minor_user_id
    left join public.profiles adp on adp.user_id = case when m.requester_id = ap.minor_user_id then m.recipient_id else m.requester_id end
    left join public.minor_adult_matches mam on mam.match_id = m.id
    left join public.clubs c on c.id = mam.shared_club_id
   where gu.auth_id = auth.uid() and not gu.is_banned and ap.status = 'pending'
   order by ap.created_at;
$function$
;

CREATE OR REPLACE FUNCTION public.list_guardian_connections()
 RETURNS TABLE(minor_name text, other_name text, other_is_adult boolean, connected_at timestamp with time zone, thread_id uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select coalesce(mp.display_name, 'Your child'),
         coalesce(op.display_name, 'Someone'),
         (ou.age_status in ('self_attested_adult', 'adult')),
         m.matched_at,
         (select t.id
            from public.chat_threads t
            join public.thread_participants tp on tp.thread_id = t.id and tp.role = 'guardian_observer' and tp.user_id = gu.id
           where t.match_id = m.id)
    from public.guardian_links l
    join public.guardians g on g.id = l.guardian_id
    join public.users gu on gu.id = g.user_id
    join public.matches m on m.status = 'matched' and m.deleted_at is null and l.minor_user_id in (m.requester_id, m.recipient_id)
    join public.users ou on ou.id = case when m.requester_id = l.minor_user_id then m.recipient_id else m.requester_id end
    left join public.profiles mp on mp.user_id = l.minor_user_id
    left join public.profiles op on op.user_id = ou.id
   where gu.auth_id = auth.uid() and not gu.is_banned and l.status = 'active' and not ou.is_banned
   order by m.matched_at desc;
$function$
;

CREATE OR REPLACE FUNCTION public.list_my_checkin_state()
 RETURNS TABLE(session_id uuid, eligible boolean, sharing_until timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select s.id,
         private.checkin_eligible(s.id, p.user_id) is null,
         case when p.checkin_opt_in and p.checkin_until > now() then p.checkin_until end
    from public.sessions s
    join public.session_participants p on p.session_id = s.id and p.user_id = (select private.current_user_id())
   where (select not private.viewer_is_banned())
     and s.status = 'agreed' and s.club_event_id is null
     and s.starts_at > now() - interval '3 hours' and s.starts_at < now() + interval '14 days';
$function$
;

CREATE OR REPLACE FUNCTION public.list_my_plans()
 RETURNS TABLE(id uuid, owner_id uuid, owner_name text, is_owner boolean, activity_type public.activity_type, other_label text, label text, recurrence public.plan_recurrence, day_of_week smallint, start_time time without time zone, timezone text, end_condition public.plan_end_condition, end_after_weeks integer, weeks_left integer, starts_on date, next_starts_at timestamp with time zone, linked_template_id uuid, linked_template_name text, my_status public.plan_partner_status)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select p.id, p.owner_id,
         (select pr.display_name from public.profiles pr where pr.user_id = p.owner_id),
         p.owner_id = (select private.current_user_id()),
         p.activity_type, p.other_label, p.label, p.recurrence, p.day_of_week, p.start_time, p.timezone,
         p.end_condition, p.end_after_weeks,
         case when p.recurrence = 'recurring' and p.end_after_weeks is not null
              then least(p.end_after_weeks,
                         greatest(0, ceil((private.plan_last_on(p.recurrence, p.starts_on, p.end_after_weeks)
                                           - (now() at time zone p.timezone)::date + 1) / 7.0)::int)) end,
         p.starts_on,
         -- A moved occurrence shows its new time; otherwise the series' own next time.
         coalesce(
           (select s.starts_at from public.sessions s
             where s.plan_id = p.id and s.status = 'agreed' and s.occurrence_on is not null
               and s.occurrence_on = (private.plan_next_start(p) at time zone p.timezone)::date),
           private.plan_next_start(p)),
         case when p.owner_id = (select private.current_user_id()) then p.linked_template_id end,
         case when p.owner_id = (select private.current_user_id())
              then (select t.name from public.workout_templates t where t.id = p.linked_template_id) end,
         (select pp.status from public.plan_partners pp where pp.plan_id = p.id and pp.user_id = (select private.current_user_id()))
    from public.plans p
   where (select not private.viewer_is_banned())
     and (p.owner_id = (select private.current_user_id()) or private.viewer_is_plan_partner(p.id))
     and (private.plan_last_on(p.recurrence, p.starts_on, p.end_after_weeks) is null
          or private.plan_last_on(p.recurrence, p.starts_on, p.end_after_weeks) >= (now() at time zone p.timezone)::date)
   order by private.plan_next_start(p) nulls last, p.created_at;
$function$
;

CREATE OR REPLACE FUNCTION public.list_my_proposals()
 RETURNS TABLE(id uuid, other_user_id uuid, other_name text, is_mine boolean, activity_type public.activity_type, proposed_start timestamp with time zone, timezone text, status public.proposal_status)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select p.id,
         case when p.proposer_id = (select private.current_user_id()) then p.recipient_id else p.proposer_id end,
         (select pr.display_name from public.profiles pr
           where pr.user_id = case when p.proposer_id = (select private.current_user_id()) then p.recipient_id else p.proposer_id end),
         p.proposer_id = (select private.current_user_id()),
         p.activity_type, p.proposed_start, p.timezone, p.status
    from public.session_proposals p
   where (select not private.viewer_is_banned())
     and (select private.current_user_id()) in (p.proposer_id, p.recipient_id)
     and p.status = 'proposed'
     and p.proposed_start > now()
     and private.user_is_not_banned(case when p.proposer_id = (select private.current_user_id()) then p.recipient_id else p.proposer_id end)
   order by p.created_at desc;
$function$
;

CREATE OR REPLACE FUNCTION public.list_my_sessions()
 RETURNS TABLE(id uuid, plan_id uuid, activity_type public.activity_type, starts_at timestamp with time zone, timezone text, other_user_id uuid, other_name text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select s.id, s.plan_id, s.activity_type, s.starts_at, s.timezone,
         o.user_id,
         (select pr.display_name from public.profiles pr where pr.user_id = o.user_id)
    from public.sessions s
    left join lateral (select sp.user_id from public.session_participants sp
                        where sp.session_id = s.id and sp.user_id <> (select private.current_user_id()) limit 1) o on true
   where (select not private.viewer_is_banned())
     and s.status = 'agreed'
     and s.starts_at > now() - interval '1 hour'
     and private.viewer_in_session(s.id)
     and (o.user_id is null or private.user_is_not_banned(o.user_id))
   order by s.starts_at;
$function$
;

CREATE OR REPLACE FUNCTION public.list_my_sessions_to_complete()
 RETURNS TABLE(id uuid, plan_id uuid, activity_type public.activity_type, starts_at timestamp with time zone, timezone text, other_user_id uuid, other_name text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select s.id, s.plan_id, s.activity_type, s.starts_at, s.timezone,
         o.user_id,
         (select pr.display_name from public.profiles pr where pr.user_id = o.user_id)
    from public.sessions s
    left join lateral (select sp.user_id from public.session_participants sp
                        where sp.session_id = s.id and sp.user_id <> (select private.current_user_id()) limit 1) o on true
   where (select not private.viewer_is_banned())
     and s.status = 'agreed'
     and s.plan_id is null and s.club_event_id is null and s.occurrence_on is null
     and s.starts_at <= now() and s.starts_at > now() - interval '30 days'
     and private.viewer_in_session(s.id)
     and (o.user_id is null or private.user_is_not_banned(o.user_id))
   order by s.starts_at desc;
$function$
;

CREATE OR REPLACE FUNCTION public.list_plan_partners(p_plan_id uuid)
 RETURNS TABLE(user_id uuid, display_name text, status public.plan_partner_status, dismissed boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select pp.user_id, pr.display_name, pp.status, pp.dismissed
    from public.plan_partners pp
    join public.users u on u.id = pp.user_id and not u.is_banned
    left join public.profiles pr on pr.user_id = pp.user_id
   where pp.plan_id = p_plan_id
     and (select not private.viewer_is_banned())
     and ( private.viewer_owns_plan(p_plan_id)
           or (pp.user_id = (select private.current_user_id()) and private.viewer_is_plan_partner(p_plan_id)) )
   order by pp.invited_at;
$function$
;

CREATE OR REPLACE FUNCTION public.log_activity(p_activity_type public.activity_type, p_other_label text, p_title text, p_started_at timestamp with time zone, p_duration_seconds integer, p_distance numeric, p_distance_unit text, p_notes text, p_source public.activity_source, p_plan_id uuid, p_template_id uuid, p_sets jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me      uuid := private.current_user_id();
  v_plan    public.plans%rowtype;
  v_today   date;
  v_session uuid;
  v_id      uuid;
  v_title   text;
  v_label   text := nullif(btrim(p_other_label), '');
  v_dist    private.parsed_set;
  v_el      jsonb;
  v_pos     integer := 0;
  v_set     private.parsed_set;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;

  -- Only the sync (phase 10) creates auto-synced logs.
  if p_source is null or p_source not in ('manual', 'live_gps') then
    raise exception 'Only your own activities can be added from the app.' using errcode = 'insufficient_privilege';
  end if;
  if p_activity_type is null then
    raise exception 'Choose an activity type.' using errcode = 'check_violation';
  end if;

  if p_started_at is null or p_started_at > now() + interval '5 minutes' then
    raise exception 'An activity cannot start in the future.' using errcode = 'check_violation';
  end if;
  if p_started_at < now() - interval '366 days' then
    raise exception 'That is more than a year ago.' using errcode = 'check_violation';
  end if;
  if p_duration_seconds is not null and p_duration_seconds not between 1 and 86400 then
    raise exception 'A duration must be between 1 second and 24 hours.' using errcode = 'check_violation';
  end if;
  if p_source = 'live_gps' and p_duration_seconds is null then
    raise exception 'A recorded activity has a duration.' using errcode = 'check_violation';
  end if;
  if char_length(coalesce(p_notes, '')) > 2000 then
    raise exception 'A note can be up to 2000 characters.' using errcode = 'check_violation';
  end if;
  if v_label is not null and char_length(v_label) > 40 then
    raise exception 'An activity name can be up to 40 characters.' using errcode = 'check_violation';
  end if;

  -- F5: "Other" has no distance, and so no pace. (The table CHECK says it too; this says it plainly.)
  if p_activity_type = 'other' and p_distance is not null then
    raise exception 'Other activities track time only — no distance or pace.' using errcode = 'check_violation';
  end if;
  -- A label means something only for "other".
  if p_activity_type <> 'other' then v_label := null; end if;

  -- The overall distance goes through the same validator as a set's, so the rules cannot differ.
  if p_distance is not null then
    v_dist := private.parse_set_json(jsonb_build_object('exercise', 'x', 'distance', p_distance, 'distance_unit', p_distance_unit));
  end if;

  if p_template_id is not null
     and not exists (select 1 from public.workout_templates where id = p_template_id and owner_id = v_me) then
    raise exception 'That template is not yours.' using errcode = 'check_violation';
  end if;

  if p_sets is not null and (jsonb_typeof(p_sets) <> 'array' or jsonb_array_length(p_sets) > 120) then
    raise exception 'An activity can have up to 120 sets.' using errcode = 'check_violation';
  end if;

  -- From a plan: it must be yours and of this type; completing it happens below, in this transaction.
  if p_plan_id is not null then
    select * into v_plan from public.plans where id = p_plan_id and owner_id = v_me;
    if v_plan.id is null then
      raise exception 'That plan is not yours.' using errcode = 'check_violation';
    end if;
    if v_plan.activity_type <> p_activity_type then
      raise exception 'That plan is a different kind of activity.' using errcode = 'check_violation';
    end if;
  end if;

  v_title := nullif(btrim(p_title), '');
  if v_title is null then
    v_title := case p_activity_type when 'run' then 'Run' when 'lift' then 'Lift' when 'ride' then 'Ride' else coalesce(v_label, 'Activity') end;
  end if;
  if char_length(v_title) > 80 then
    raise exception 'A title can be up to 80 characters.' using errcode = 'check_violation';
  end if;

  if p_plan_id is not null then
    v_today := (now() at time zone v_plan.timezone)::date;
    -- Complete today's session if today IS one; a plan with no session today is left alone.
    if private.is_plan_occurrence(v_plan, v_today) then
      v_session := public.mark_plan_complete(p_plan_id, v_today);
    end if;
  end if;

  insert into public.activity_logs (user_id, plan_id, session_id, template_id, source, activity_type, other_label, title,
                                    started_at, ended_at, duration_seconds, distance, distance_unit, notes)
  values (v_me, p_plan_id, v_session, p_template_id, p_source, p_activity_type, v_label, v_title,
          p_started_at,
          case when p_duration_seconds is null then null else p_started_at + make_interval(secs => p_duration_seconds) end,
          p_duration_seconds, v_dist.distance, v_dist.distance_unit, coalesce(btrim(p_notes), ''))
  returning id into v_id;

  if p_sets is not null then
    for v_el in select * from jsonb_array_elements(p_sets) loop
      v_pos := v_pos + 1;
      v_set := private.parse_set_json(v_el);
      insert into public.activity_sets (activity_log_id, position, exercise, detail, weight, weight_unit, reps,
                                        duration_seconds, pace_seconds, pace_unit, distance, distance_unit)
      values (v_id, v_pos, v_set.exercise, v_set.target_detail, v_set.weight, v_set.weight_unit, v_set.reps,
              v_set.duration_seconds, v_set.pace_seconds, v_set.pace_unit, v_set.distance, v_set.distance_unit);
    end loop;
  end if;

  return v_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.mark_plan_complete(p_plan_id uuid, p_occurrence_on date)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me    uuid := private.current_user_id();
  v_plan  public.plans%rowtype;
  v_today date;
  v_id    uuid;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  select * into v_plan from public.plans where id = p_plan_id and owner_id = v_me for update;
  if v_plan.id is null then
    raise exception 'That plan is not yours to change.' using errcode = 'insufficient_privilege';
  end if;
  v_today := (now() at time zone v_plan.timezone)::date;
  if not private.is_plan_occurrence(v_plan, p_occurrence_on) or p_occurrence_on > v_today then
    raise exception 'That session has not happened yet.' using errcode = 'check_violation';
  end if;

  select id into v_id from public.sessions where plan_id = p_plan_id and occurrence_on = p_occurrence_on;
  if v_id is null then
    insert into public.sessions (plan_id, activity_type, starts_at, timezone, status, created_by, occurrence_on)
    values (p_plan_id, v_plan.activity_type, ((p_occurrence_on + v_plan.start_time) at time zone v_plan.timezone),
            v_plan.timezone, 'completed', v_me, p_occurrence_on)
    returning id into v_id;
    insert into public.session_participants (session_id, user_id, rsvp_status) values (v_id, v_me, 'confirmed');
  else
    update public.sessions set status = 'completed' where id = v_id;
  end if;

  -- The plan's CONFIRMED partners were part of this session. (Invited and declined ones were not.)
  insert into public.session_participants (session_id, user_id, rsvp_status)
  select v_id, pp.user_id, 'confirmed'
    from public.plan_partners pp
    join public.users u on u.id = pp.user_id and not u.is_banned
   where pp.plan_id = p_plan_id and pp.status = 'confirmed' and not pp.dismissed
  on conflict (session_id, user_id) do update set rsvp_status = 'confirmed';
  return v_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.mark_session_complete(p_session_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if (select private.current_user_id()) is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  update public.sessions s set status = 'completed'
   where s.id = p_session_id and s.status = 'agreed'
     and s.plan_id is null and s.club_event_id is null and s.occurrence_on is null
     and s.starts_at <= now()
     and private.viewer_in_session(s.id);
  if not found then
    raise exception 'There is no session here to mark complete.' using errcode = 'no_data_found';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.my_progress(p_tz text DEFAULT 'UTC'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me     uuid := private.current_user_id();
  v_tz     text := case when exists (select 1 from pg_timezone_names where name = p_tz) then p_tz else 'UTC' end;
  v_today  date;
  v_cur    integer;
  v_best   integer;
  v_week0  date;
  v_weeks  jsonb;
  v_prs    jsonb;
  v_total  integer;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  v_today := (now() at time zone v_tz)::date;
  v_week0 := v_today - ((extract(isodow from v_today)::int) - 1);   -- Monday of this week

  -- ---- streaks (gaps and islands over the distinct days) ----
  with days as (
    select distinct (started_at at time zone v_tz)::date as d
      from public.activity_logs where user_id = v_me and confirmed
  ), grp as (
    select d, d - (row_number() over (order by d))::int as g from days
  ), islands as (
    select max(d) as e, count(*)::int as n from grp group by g
  )
  select coalesce((select n from islands where e >= v_today - 1 order by e desc limit 1), 0),
         coalesce((select max(n) from islands), 0)
    into v_cur, v_best;

  select count(*)::int into v_total from public.activity_logs where user_id = v_me and confirmed;

  -- ---- the last 8 weeks ----
  select coalesce(jsonb_agg(w order by (w ->> 'start')), '[]'::jsonb) into v_weeks
    from (
      select jsonb_build_object(
               'start', wk.start::text,
               'sessions', count(l.id)::int,
               'minutes', coalesce(round(sum(l.duration_seconds) / 60.0), 0)::int,
               'distance_km', coalesce(round(sum(
                   case l.distance_unit when 'mi' then l.distance * 1.609344 when 'km' then l.distance when 'm' then l.distance / 1000.0 end), 1), 0),
               'lift_kg', coalesce(round((
                   select sum(s.weight * s.reps * case s.weight_unit when 'lb' then 0.45359237 else 1 end)
                     from public.activity_sets s join public.activity_logs ll on ll.id = s.activity_log_id
                    where ll.user_id = v_me and ll.confirmed
                      and (ll.started_at at time zone v_tz)::date >= wk.start and (ll.started_at at time zone v_tz)::date < wk.start + 7
                      and s.weight is not null and s.reps is not null)), 0)::int
             ) as w
        from (select (v_week0 - 7 * g)::date as start from generate_series(0, 7) g) wk
        left join public.activity_logs l
               on l.user_id = v_me and l.confirmed
              and (l.started_at at time zone v_tz)::date >= wk.start and (l.started_at at time zone v_tz)::date < wk.start + 7
       group by wk.start
    ) x;

  -- ---- personal records ----
  with logs as (
    select id, activity_type, started_at, duration_seconds,
           case distance_unit when 'mi' then distance * 1.609344 when 'km' then distance when 'm' then distance / 1000.0 end as km
      from public.activity_logs where user_id = v_me and confirmed
  ), weekly as (
    select date_trunc('week', (started_at at time zone v_tz))::date as wk,
           count(*)::int as sessions,
           round(coalesce(sum(duration_seconds), 0) / 60.0)::int as minutes,
           round(coalesce(sum(km), 0)::numeric, 1) as distance_km
      from logs group by 1
  ), lift_weekly as (
    select date_trunc('week', (l.started_at at time zone v_tz))::date as wk,
           round(sum(s.weight * s.reps * case s.weight_unit when 'lb' then 0.45359237 else 1 end))::int as lift_kg
      from public.activity_sets s join public.activity_logs l on l.id = s.activity_log_id
     where l.user_id = v_me and l.confirmed and s.weight is not null and s.reps is not null
     group by 1
  ), lifts as (
    select distinct on (lower(s.exercise))
           s.exercise, s.weight, s.weight_unit, s.reps, l.started_at,
           s.weight * case s.weight_unit when 'lb' then 0.45359237 else 1 end as kg
      from public.activity_sets s join public.activity_logs l on l.id = s.activity_log_id
     where l.user_id = v_me and l.confirmed and s.weight is not null and s.weight > 0 and s.reps is not null
     order by lower(s.exercise), s.weight * case s.weight_unit when 'lb' then 0.45359237 else 1 end desc, s.reps desc, l.started_at
  )
  select jsonb_build_object(
    'longest_run', (select jsonb_build_object('km', round(km::numeric, 2), 'on', (started_at at time zone v_tz)::date::text)
                      from logs where activity_type = 'run' and km is not null order by km desc, started_at limit 1),
    'longest_ride', (select jsonb_build_object('km', round(km::numeric, 2), 'on', (started_at at time zone v_tz)::date::text)
                      from logs where activity_type = 'ride' and km is not null order by km desc, started_at limit 1),
    'fastest_run', (select jsonb_build_object('seconds_per_km', round((duration_seconds / km)::numeric), 'on', (started_at at time zone v_tz)::date::text)
                      from logs where activity_type = 'run' and km >= 1 and duration_seconds is not null order by duration_seconds / km, started_at limit 1),
    'longest_workout', (select jsonb_build_object('seconds', duration_seconds, 'on', (started_at at time zone v_tz)::date::text)
                      from logs where duration_seconds is not null order by duration_seconds desc, started_at limit 1),
    'best_week', jsonb_build_object(
      'sessions', (select jsonb_build_object('value', sessions, 'start', wk::text) from weekly order by sessions desc, wk desc limit 1),
      'minutes', (select jsonb_build_object('value', minutes, 'start', wk::text) from weekly where minutes > 0 order by minutes desc, wk desc limit 1),
      'distance_km', (select jsonb_build_object('value', distance_km, 'start', wk::text) from weekly where distance_km > 0 order by distance_km desc, wk desc limit 1),
      'lift_kg', (select jsonb_build_object('value', lift_kg, 'start', wk::text) from lift_weekly where lift_kg > 0 order by lift_kg desc, wk desc limit 1)
    ),
    'lifts', coalesce((select jsonb_agg(jsonb_build_object('exercise', exercise, 'weight', weight, 'unit', weight_unit, 'reps', reps,
                                                           'on', (started_at at time zone v_tz)::date::text) order by kg desc)
                         from (select * from lifts order by kg desc, exercise limit 5) top), '[]'::jsonb)
  ) into v_prs;

  return jsonb_build_object('streak', jsonb_build_object('current', v_cur, 'best', v_best), 'total_sessions', v_total,
                            'weeks', v_weeks, 'prs', v_prs);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.my_qr_code()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me   uuid := private.current_user_id();
  u      record;
  v_row  public.minor_qr_codes%rowtype;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  select age_status, consent_status into u from public.users where id = v_me;

  if u.age_status <> 'minor' then
    return jsonb_build_object('code', (select qr_code from public.profiles where user_id = v_me), 'rotating', false);
  end if;
  if u.consent_status <> 'granted' then
    raise exception 'Your code is available once your guardian has approved your account.' using errcode = 'insufficient_privilege';
  end if;

  select * into v_row from public.minor_qr_codes where user_id = v_me for update;
  if v_row.user_id is null or v_row.expires_at < now() + interval '5 seconds' then
    insert into public.minor_qr_codes (user_id, code, issued_at, expires_at)
    values (v_me, 'GW-M-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)), now(), now() + interval '60 seconds')
    on conflict (user_id) do update set code = excluded.code, issued_at = excluded.issued_at, expires_at = excluded.expires_at
    returning * into v_row;
  end if;
  return jsonb_build_object('code', v_row.code, 'rotating', true, 'expires_at', v_row.expires_at);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.partner_count_for(p_user uuid)
 RETURNS SETOF integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me     uuid := private.current_user_id();
  v_vis    public.leaderboard_visibility;
  v_minor  boolean;
  v_shared boolean;
  v_match  boolean;
  v_guard  boolean;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if p_user is null or not exists (select 1 from public.users where id = p_user and not is_banned) then return; end if;

  if p_user <> v_me then
    select age_status = 'minor' into v_minor from public.users where id = p_user;
    -- A minor's linked guardian can always see it.
    v_guard := coalesce(v_minor, false) and exists (
      select 1 from public.guardian_links l join public.guardians g on g.id = l.guardian_id
       where l.minor_user_id = p_user and l.status = 'active' and g.user_id = v_me);
    if not v_guard then
      v_vis := private.visibility_of(p_user);
      if v_vis = 'off' then return; end if;
      v_shared := exists (select 1 from public.club_memberships a join public.club_memberships b on b.club_id = a.club_id
                           where a.user_id = v_me and b.user_id = p_user);
      v_match := exists (select 1 from public.matches m
                          where m.status = 'matched' and m.deleted_at is null
                            and ((m.requester_id = v_me and m.recipient_id = p_user) or (m.requester_id = p_user and m.recipient_id = v_me)));
      if v_minor then
        if not v_shared then return; end if;                       -- never outside their own clubs
      elsif v_vis = 'matches_and_clubs' then
        if not (v_shared or v_match) then return; end if;
      elsif not (v_shared or v_match or (private.viewer_may_browse_discover() and private.profile_is_discoverable(p_user))) then
        return;
      end if;
    end if;
  end if;

  -- Only live matches, and never one whose other side is banned (so a ban lowers a former partner's total at once, S36).
  return query
    select count(*)::int
      from public.matches m
      join public.users o on o.id = case when m.requester_id = p_user then m.recipient_id else m.requester_id end and not o.is_banned
     where m.status = 'matched' and m.deleted_at is null and p_user in (m.requester_id, m.recipient_id);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.person_standing(p_user uuid DEFAULT NULL::uuid, p_basis text DEFAULT 'month'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me     uuid := private.current_user_id();
  v_target uuid;
  v_self   boolean;
  v_clubs  jsonb := '[]'::jsonb;
  v_part   jsonb := '[]'::jsonb;
  c        record;
  r        record;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if p_basis not in ('month', 'all') then
    raise exception 'Choose This month or All time.' using errcode = 'check_violation';
  end if;
  v_target := coalesce(p_user, v_me);
  v_self := v_target = v_me;
  if not v_self and exists (select 1 from public.users where id = v_target and is_banned) then return null; end if;

  -- Club standings: one chip per club where all three conditions hold (5.9 order).
  for c in
    select cl.id, cl.name
      from public.clubs cl
      join public.club_memberships m on m.club_id = cl.id and m.user_id = v_target
     where cl.show_leaderboard
       and not exists (select 1 from public.club_leaderboard_opt_outs o where o.club_id = cl.id and o.user_id = v_target)
       and (v_self or private.may_see_standing(v_target, v_me, cl.id))
     order by cl.name
  loop
    select m.rank, m.total, m.sessions into r from private.ranked_members(c.id, p_basis, v_target) m where m.user_id = v_target;
    if r.rank is not null then
      v_clubs := v_clubs || jsonb_build_object('club_id', c.id, 'club', c.name, 'rank', r.rank, 'of', r.total, 'sessions', r.sessions);
    end if;
  end loop;

  -- Top training partners: ONLY your own relationships, never a third party's (5.9).
  if v_self then
    select coalesce(jsonb_agg(jsonb_build_object('user_id', top.other_id, 'name', coalesce(p.display_name, 'Training partner'), 'sessions', top.n) order by top.n desc, top.last_at, top.other_id), '[]'::jsonb)
      into v_part
      from (
        select ct.other_id,
               (count(*) filter (where p_basis = 'all' or ct.starts_at > now() - interval '30 days'))::int as n,
               max(ct.starts_at) filter (where p_basis = 'all' or ct.starts_at > now() - interval '30 days') as last_at
          from private.completed_together() ct
         where ct.user_id = v_me
         group by ct.other_id
        having count(*) filter (where p_basis = 'all' or ct.starts_at > now() - interval '30 days') > 0
         order by 2 desc, 3, ct.other_id
         limit 5
      ) top
      left join public.profiles p on p.user_id = top.other_id;
  end if;

  if jsonb_array_length(v_clubs) = 0 and jsonb_array_length(v_part) = 0 then return null; end if;
  return jsonb_build_object('basis', p_basis, 'clubs', v_clubs, 'partners', v_part);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.plan_history(p_plan_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me     uuid := private.current_user_id();
  v_plan   public.plans%rowtype;
  v_today  date;
  v_last   date;
  v_dates  date[];
  v_done   boolean;
  v_on     date;
  v_due_on date[] := '{}';
  v_flags  boolean[] := '{}';
  v_due    integer := 0;
  v_n_done integer := 0;
  v_streak integer := 0;
  v_i      integer;
  v_six    jsonb := '[]'::jsonb;
  v_first  integer;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  select * into v_plan from public.plans where id = p_plan_id and owner_id = v_me;
  if v_plan.id is null then
    raise exception 'That plan is not yours.' using errcode = 'insufficient_privilege';
  end if;

  v_today := (now() at time zone v_plan.timezone)::date;
  v_last  := least(coalesce(private.plan_last_on(v_plan.recurrence, v_plan.starts_on, v_plan.end_after_weeks), v_today), v_today);

  if v_plan.recurrence = 'one_time' then
    v_dates := case when v_plan.starts_on <= v_today then array[v_plan.starts_on] else '{}' end;
  else
    select coalesce(array_agg(d::date order by d), '{}') into v_dates
      from generate_series(v_plan.starts_on::timestamp, v_last::timestamp, interval '7 days') d;
  end if;

  foreach v_on in array v_dates loop
    select exists (select 1 from public.sessions s
                    where s.plan_id = p_plan_id and s.occurrence_on = v_on and s.status = 'completed') into v_done;
    if v_on < v_today or v_done then
      v_due_on := v_due_on || v_on;
      v_flags := v_flags || v_done;
      v_due := v_due + 1;
      if v_done then v_n_done := v_n_done + 1; end if;
    end if;
  end loop;

  -- Streak: from the most recent due occurrence backwards.
  for v_i in reverse v_due .. 1 loop
    exit when not v_flags[v_i];
    v_streak := v_streak + 1;
  end loop;

  -- The last six due occurrences, oldest first.
  v_first := greatest(1, v_due - 5);
  for v_i in v_first .. v_due loop
    v_six := v_six || jsonb_build_object('on', v_due_on[v_i], 'done', v_flags[v_i]);
  end loop;

  return jsonb_build_object(
    'sessions_done', (select count(*) from public.sessions s where s.plan_id = p_plan_id and s.status = 'completed'),
    'due', v_due,
    'consistency_pct', case when v_due = 0 then null else floor(100.0 * v_n_done / v_due + 0.5)::int end,
    'streak', v_streak,
    'last_six', v_six
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.post_club_event(p_club_id uuid, p_title text, p_starts_at timestamp with time zone, p_timezone text, p_location_label text, p_capacity integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
  v_id uuid;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;

  -- Only the club's organizer posts sessions (§2.2). One message whether the club does not exist or is
  -- someone else's, so this cannot be used to probe for clubs.
  if not exists (select 1 from public.clubs where id = p_club_id and organizer_id = v_me) then
    raise exception 'Only the club organizer can post a session.' using errcode = 'insufficient_privilege';
  end if;

  if coalesce(btrim(p_title), '') = '' or char_length(btrim(p_title)) > 120 then
    raise exception 'Give the session a title of up to 120 characters.' using errcode = 'check_violation';
  end if;
  if p_starts_at is null or p_starts_at <= now() then
    raise exception 'A session must start in the future.' using errcode = 'check_violation';
  end if;
  if p_timezone is null or not exists (select 1 from pg_catalog.pg_timezone_names where name = p_timezone) then
    raise exception 'That time zone is not recognised.' using errcode = 'check_violation';
  end if;
  if p_capacity is not null and (p_capacity < 1 or p_capacity > 10000) then
    raise exception 'Capacity must be between 1 and 10000, or left open.' using errcode = 'check_violation';
  end if;

  insert into public.club_events (club_id, title, starts_at, timezone, location_label, capacity, created_by)
  values (p_club_id, btrim(p_title), p_starts_at, p_timezone, coalesce(btrim(p_location_label), ''), p_capacity, v_me)
  returning id into v_id;
  return v_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.propose_session(p_recipient_id uuid, p_activity_type public.activity_type, p_proposed_start timestamp with time zone, p_timezone text, p_plan_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
  v_id uuid;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if private.minor_without_consent(v_me) or private.minor_without_consent(p_recipient_id) then
    raise exception 'That person is not available for sessions right now.' using errcode = 'insufficient_privilege';
  end if;
  if p_recipient_id is null or p_recipient_id = v_me or not private.are_live_partners(v_me, p_recipient_id) then
    raise exception 'You can propose a session to people you are matched with.' using errcode = 'insufficient_privilege';
  end if;
  if p_proposed_start is null or p_proposed_start <= now() or p_proposed_start > now() + interval '120 days' then
    raise exception 'Choose a time in the next 120 days.' using errcode = 'check_violation';
  end if;
  if p_timezone is null or not exists (select 1 from pg_catalog.pg_timezone_names where name = p_timezone) then
    raise exception 'That time zone is not recognised.' using errcode = 'check_violation';
  end if;
  if p_activity_type is null then
    raise exception 'Choose an activity type.' using errcode = 'check_violation';
  end if;
  if p_plan_id is not null and not exists (select 1 from public.plans where id = p_plan_id and owner_id = v_me) then
    raise exception 'That plan is not yours.' using errcode = 'check_violation';
  end if;

  -- A new proposal to the same person replaces my earlier open one (no pile of competing times).
  update public.session_proposals set status = 'superseded', resolved_at = now()
   where proposer_id = v_me and recipient_id = p_recipient_id and status = 'proposed';

  insert into public.session_proposals (plan_id, proposer_id, recipient_id, activity_type, proposed_start, timezone)
  values (p_plan_id, v_me, p_recipient_id, p_activity_type, p_proposed_start, p_timezone)
  returning id into v_id;
  return v_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.record_checkin(p_session uuid, p_lat double precision, p_lng double precision)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
declare
  v_me     uuid := private.current_user_id();
  v_reason text;
  v_part   public.session_participants%rowtype;
  s        public.sessions%rowtype;
  v_last   timestamptz;
  v_n      integer;
  v_lat    double precision;
  v_lng    double precision;
  v_other  uuid;
  v_there  record;
  v_here   extensions.geography;
  v_thread uuid;
  v_label  text;
  v_new    uuid;
  v_u      uuid;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'That isn''t a valid location.' using errcode = 'check_violation';
  end if;

  v_reason := private.checkin_eligible(p_session, v_me);
  if v_reason is not null then return jsonb_build_object('recorded', false, 'reason', v_reason); end if;

  select * into v_part from public.session_participants where session_id = p_session and user_id = v_me;
  if v_part.user_id is null or not v_part.checkin_opt_in or v_part.checkin_until <= now() then
    return jsonb_build_object('recorded', false, 'reason', 'not_sharing');
  end if;
  select * into s from public.sessions where id = p_session;
  if now() < s.starts_at - interval '30 minutes' then return jsonb_build_object('recorded', false, 'reason', 'too_early'); end if;

  select max(recorded_at), count(*) into v_last, v_n from public.checkin_locations where session_id = p_session and user_id = v_me;
  if v_last is not null and v_last > now() - interval '20 seconds' then return jsonb_build_object('recorded', false, 'reason', 'too_soon'); end if;
  if v_n >= 120 then return jsonb_build_object('recorded', false, 'reason', 'enough'); end if;

  -- 4 decimals is about 11 m: precise enough to test "within 150 m", no more than that.
  v_lat := round(p_lat::numeric, 4)::double precision;
  v_lng := round(p_lng::numeric, 4)::double precision;
  insert into public.checkin_locations (session_id, user_id, lat, lng) values (p_session, v_me, v_lat, v_lng);

  -- Is the other person here too? They must be sharing now and have checked in within the last five minutes.
  select user_id into v_other from public.session_participants where session_id = p_session and rsvp_status = 'confirmed' and user_id <> v_me;
  select l.lat, l.lng into v_there
    from public.checkin_locations l
    join public.session_participants op on op.session_id = l.session_id and op.user_id = l.user_id and op.checkin_opt_in and op.checkin_until > now()
   where l.session_id = p_session and l.user_id = v_other and l.recorded_at > now() - interval '5 minutes'
   order by l.recorded_at desc limit 1;
  if not found then return jsonb_build_object('recorded', true, 'nudged', false); end if;

  v_here := extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography;
  if extensions.st_distance(v_here, extensions.st_setsrid(extensions.st_makepoint(v_there.lng, v_there.lat), 4326)::extensions.geography) > 150 then
    return jsonb_build_object('recorded', true, 'nudged', false);
  end if;

  select t.id into v_thread
    from public.chat_threads t
   where not t.archived
     and exists (select 1 from public.thread_participants a where a.thread_id = t.id and a.user_id = v_me and a.role = 'member')
     and exists (select 1 from public.thread_participants b where b.thread_id = t.id and b.user_id = v_other and b.role = 'member')
   order by t.created_at desc limit 1;

  select n.name into v_label from public.neighborhoods n
   where extensions.st_distance(n.centroid, v_here) < 3000
   order by extensions.st_distance(n.centroid, v_here) limit 1;

  insert into public.checkin_nudges (session_id, thread_id, near_label) values (p_session, v_thread, v_label)
  on conflict (session_id) do nothing returning session_id into v_new;
  if v_new is null then return jsonb_build_object('recorded', true, 'nudged', false); end if; -- already nudged for this session

  foreach v_u in array array[v_me, v_other] loop
    if v_thread is not null and exists (select 1 from public.thread_settings ts where ts.thread_id = v_thread and ts.user_id = v_u and ts.checkin_nudges_muted) then
      continue; -- muted for this thread: no push (the card still shows, the person can unmute)
    end if;
    perform private.enqueue_push(
      v_u, 'checkin_nudge', 'Check-in',
      private.push_name(case when v_u = v_me then v_other else v_me end) || ' checked in near your meetup spot.',
      case when v_thread is not null then jsonb_build_object('route', 'chat', 'thread_id', v_thread) else jsonb_build_object('route', 'activity') end,
      'checkin:' || p_session || ':' || v_u);
  end loop;
  return jsonb_build_object('recorded', true, 'nudged', true);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.record_guardian_details(p_first_name text, p_last_name text, p_email text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_minor_id uuid;
  v_consent  public.consent_status;
  v_id       uuid;
begin
  select id, consent_status into v_minor_id, v_consent from public.users
   where auth_id = (select auth.uid()) and age_status = 'minor';

  if v_minor_id is null then
    raise exception 'Only a 13-17 account collects guardian details.'
      using errcode = 'insufficient_privilege';
  end if;

  -- Only while no guardian has acted. Once a guardian has approved (granted) or paused (revoked) the account, the minor may not
  -- name someone else in their place.
  if v_consent is distinct from 'pending' then
    raise exception 'Your guardian details can''t be changed now.'
      using errcode = 'insufficient_privilege';
  end if;

  if coalesce(trim(p_first_name), '') = '' or coalesce(trim(p_last_name), '') = ''
     or coalesce(trim(p_email), '') = '' then
    raise exception 'A guardian name and email address are required.'
      using errcode = 'check_violation';
  end if;

  -- A re-send supersedes the previous invitation rather than accumulating live tokens.
  update public.guardian_invitations
     set superseded_at = now()
   where minor_user_id = v_minor_id and accepted_at is null and superseded_at is null;

  insert into public.guardian_invitations (
    minor_user_id, token_hash, guardian_first_name, guardian_last_name, guardian_email, expires_at, created_at
  ) values (
    v_minor_id,
    -- Placeholder, replaced by the Edge Function when it mints and sends the real token.
    encode(sha256(gen_random_uuid()::text::bytea), 'hex'),
    trim(p_first_name), trim(p_last_name), lower(trim(p_email)),
    now() + interval '14 days',
    coalesce((select min(i.created_at) from public.guardian_invitations i where i.minor_user_id = v_minor_id and i.accepted_at is null), now())
  )
  returning id into v_id;

  return v_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.register_custom_tag(p_label text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me    uuid := private.current_user_id();
  v_clean text := btrim(regexp_replace(coalesce(p_label, ''), '[[:cntrl:]]+', ' ', 'g'));
  v_out   text;
begin
  if v_me is null or private.viewer_is_banned() then
    raise exception 'Not available.' using errcode = 'insufficient_privilege';
  end if;
  if char_length(v_clean) not between 2 and 40 then
    raise exception 'An activity name needs 2 to 40 characters.' using errcode = 'check_violation';
  end if;

  insert into public.custom_tags (label, created_by)
  values (v_clean, v_me)
  on conflict (lower(label)) do update set usage_count = public.custom_tags.usage_count + 1
  returning label into v_out;

  return v_out;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.register_push_token(p_token text, p_platform text, p_device_id text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if p_token is null or char_length(p_token) not between 10 and 300 or p_platform not in ('ios', 'android') then
    raise exception 'That is not a valid push token.' using errcode = 'check_violation';
  end if;
  -- This phone now belongs to the account that just signed in on it: nobody else may keep receiving its notifications.
  update public.push_tokens set revoked_at = now() where token = p_token and user_id <> v_me and revoked_at is null;
  insert into public.push_tokens (user_id, platform, token, device_id) values (v_me, p_platform, p_token, left(p_device_id, 200))
  on conflict (user_id, token) do update set revoked_at = null, last_seen_at = now(), device_id = coalesce(excluded.device_id, public.push_tokens.device_id);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.release_held_connection(p_row_id uuid, p_release boolean, p_reviewer uuid DEFAULT NULL::uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  r public.minor_adult_matches%rowtype;
  v_g jsonb;
  v_match uuid;
begin
  select * into r from public.minor_adult_matches where id = p_row_id and state = 'held' for update;
  if r.id is null then
    raise exception 'There is no held connection with that id.' using errcode = 'no_data_found';
  end if;
  if not p_release then
    update public.minor_adult_matches set state = 'dismissed', reviewed = true, reviewed_by = p_reviewer where id = r.id;
    return 'dismissed';
  end if;

  v_g := private.qr_gate(r.minor_user_id, r.adult_user_id);
  if not (v_g ->> 'ok')::boolean then
    update public.minor_adult_matches set state = 'dismissed', reviewed = true, reviewed_by = p_reviewer where id = r.id;
    return 'dismissed';
  end if;

  perform set_config('groundwork.minor_match_gate', 'on', true);
  insert into public.matches (requester_id, recipient_id, status, source)
    values (r.minor_user_id, r.adult_user_id, 'pending', 'qr_scan')
    on conflict do nothing
    returning id into v_match;
  perform set_config('groundwork.minor_match_gate', 'off', true);
  if v_match is null then
    update public.minor_adult_matches set state = 'dismissed', reviewed = true, reviewed_by = p_reviewer where id = r.id;
    return 'dismissed';
  end if;
  if coalesce((v_g ->> 'approval_required')::boolean, false) then
    insert into public.guardian_connection_approvals (match_id, guardian_link_id, minor_user_id)
    values (v_match, (v_g ->> 'link_id')::uuid, r.minor_user_id);
  end if;
  update public.minor_adult_matches set state = 'released', match_id = v_match, reviewed = true, reviewed_by = p_reviewer where id = r.id;
  return 'released';
end;
$function$
;

CREATE OR REPLACE FUNCTION public.remove_activity_photo(p_photo_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me   uuid := private.current_user_id();
  v_path text;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  delete from public.activity_photos ph
   using public.activity_logs l
   where ph.id = p_photo_id and l.id = ph.activity_log_id and l.user_id = v_me
  returning ph.storage_path into v_path;
  if v_path is null then
    raise exception 'That photo is not yours to remove.' using errcode = 'no_data_found';
  end if;
  return v_path;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.request_account_deletion(p_confirm text)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
  v_blockers jsonb;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if p_confirm is distinct from 'DELETE' then
    raise exception 'Type DELETE to confirm.' using errcode = 'check_violation';
  end if;
  v_blockers := public.account_deletion_blockers();
  if jsonb_array_length(v_blockers) > 0 then
    raise exception 'You can''t delete your account yet. %', v_blockers -> 0 ->> 'message' using errcode = 'check_violation';
  end if;

  update public.users
     set deletion_requested_at = now(), is_banned = true, banned_at = now(), banned_reason = 'account_deletion'
   where id = v_me;
  update public.push_tokens set revoked_at = now() where user_id = v_me and revoked_at is null;
  return now() + interval '30 days';
end;
$function$
;

CREATE OR REPLACE FUNCTION public.request_match(p_target uuid)
 RETURNS public.match_status
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me     uuid := private.current_user_id();
  v_me_age public.age_status;
  v_row    public.matches%rowtype;
  v_tries  integer := 0;
begin
  if v_me is null then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;

  select age_status into v_me_age from public.users where id = v_me and not is_banned;
  if v_me_age is null then
    raise exception 'This account is suspended.' using errcode = 'insufficient_privilege';
  end if;

  -- S2: refused with an explicit error, and no matches row is created.
  if v_me_age not in ('self_attested_adult', 'adult') then
    raise exception 'Matching is available to adult accounts. You can still join a club with its code.'
      using errcode = 'insufficient_privilege';
  end if;

  -- One message for "no such account", "banned" and "not an adult" — see the header.
  if p_target is null or p_target = v_me or not exists (
       select 1 from public.users u
        where u.id = p_target and not u.is_banned
          and u.age_status in ('self_attested_adult', 'adult')
     ) then
    raise exception 'That person is not available.' using errcode = 'no_data_found';
  end if;

  loop
    v_tries := v_tries + 1;

    select * into v_row
      from public.matches m
     where m.deleted_at is null
       and least(m.requester_id, m.recipient_id) = least(v_me, p_target)
       and greatest(m.requester_id, m.recipient_id) = greatest(v_me, p_target)
       for update;

    if not found then
      begin
        insert into public.matches (requester_id, recipient_id, status, source)
        values (v_me, p_target, 'pending', 'discover');
        return 'pending';
      exception when unique_violation then
        -- Lost a race with the other side's simultaneous request; read it and decide again.
        if v_tries >= 3 then raise; end if;
        continue;
      end;
    end if;

    if v_row.status = 'matched' then
      return 'matched';
    end if;

    if v_row.status = 'pending' then
      if v_row.requester_id = v_me then
        return 'pending';                                -- idempotent
      end if;
      -- They asked first and this is the corresponding approval: request + approval = matched.
      update public.matches set status = 'matched', matched_at = now() where id = v_row.id;
      -- A confirmed match gets its 1:1 thread in the SAME transaction (§2.5).
      perform private.ensure_thread(v_row.id);
      return 'matched';
    end if;

    -- declined
    if v_row.requester_id = v_me then
      -- The person who was declined is not told so: they see "requested" and nothing more, which
      -- spares the decliner a retaliation target and spares everyone a rejection notification.
      return 'pending';
    end if;
    -- The decliner has changed their mind: their request now stands, awaiting the other side.
    update public.matches
       set status = 'pending', requester_id = v_me, recipient_id = p_target, requested_at = now()
     where id = v_row.id;
    return 'pending';
  end loop;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.reschedule_plan_occurrence(p_plan_id uuid, p_occurrence_on date, p_new_starts_at timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me    uuid := private.current_user_id();
  v_plan  public.plans%rowtype;
  v_today date;
  v_sess  public.sessions%rowtype;
  v_id    uuid;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  select * into v_plan from public.plans where id = p_plan_id and owner_id = v_me for update;
  if v_plan.id is null then
    raise exception 'That plan is not yours to change.' using errcode = 'insufficient_privilege';
  end if;
  v_today := (now() at time zone v_plan.timezone)::date;
  if not private.is_plan_occurrence(v_plan, p_occurrence_on) or p_occurrence_on < v_today then
    raise exception 'That date is not an upcoming session of this plan.' using errcode = 'check_violation';
  end if;
  if p_new_starts_at is null or p_new_starts_at <= now() or p_new_starts_at > now() + interval '120 days' then
    raise exception 'Choose a time in the next 120 days.' using errcode = 'check_violation';
  end if;

  select * into v_sess from public.sessions where plan_id = p_plan_id and occurrence_on = p_occurrence_on;
  if v_sess.id is not null and v_sess.status = 'completed' then
    raise exception 'That session is already done.' using errcode = 'check_violation';
  end if;

  if v_sess.id is null then
    insert into public.sessions (plan_id, activity_type, starts_at, timezone, created_by, occurrence_on)
    values (p_plan_id, v_plan.activity_type, p_new_starts_at, v_plan.timezone, v_me, p_occurrence_on)
    returning id into v_id;
    insert into public.session_participants (session_id, user_id, rsvp_status) values (v_id, v_me, 'confirmed');
  else
    update public.sessions set starts_at = p_new_starts_at, status = 'agreed' where id = v_sess.id;
    v_id := v_sess.id;
  end if;
  return v_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.resolve_qr(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me  uuid := private.current_user_id();
  u     record;
  v_r   jsonb;
  v_g   jsonb;
  v_name text;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  select age_status, consent_status into u from public.users where id = v_me;
  v_r := private.resolve_code(p_code);
  if v_r is null then
    return jsonb_build_object('ok', false, 'reason', 'That code isn''t valid.');
  end if;

  if v_r ->> 'kind' = 'club' then
    if u.age_status = 'minor' and u.consent_status <> 'granted' then
      return jsonb_build_object('ok', false, 'reason', 'Your guardian needs to finish approving your account before you can join a club.');
    end if;
    select name into v_name from public.clubs where id = (v_r ->> 'club_id')::uuid;
    return jsonb_build_object('ok', true, 'kind', 'club', 'name', v_name);
  end if;

  v_g := private.qr_gate(v_me, (v_r ->> 'person_id')::uuid);
  if not (v_g ->> 'ok')::boolean then
    return jsonb_build_object('ok', false, 'kind', 'person', 'reason', v_g ->> 'reason');
  end if;
  select display_name into v_name from public.profiles where user_id = (v_r ->> 'person_id')::uuid;
  return jsonb_build_object('ok', true, 'kind', 'person', 'name', coalesce(v_name, 'this person'), 'mode', v_g ->> 'mode',
                            'club_name', v_g ->> 'club_name', 'approval_required', coalesce((v_g ->> 'approval_required')::boolean, false),
                            'hold', coalesce((v_g ->> 'hold')::boolean, false));
end;
$function$
;

CREATE OR REPLACE FUNCTION public.respond_plan_invite(p_plan_id uuid, p_accept boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if private.minor_without_consent(v_me) then
    raise exception 'This opens once your parent or guardian has confirmed.' using errcode = 'insufficient_privilege';
  end if;
  if p_accept is null then
    raise exception 'Say whether you are in.' using errcode = 'check_violation';
  end if;

  update public.plan_partners pp
     set status = case when p_accept then 'confirmed'::public.plan_partner_status else 'declined'::public.plan_partner_status end,
         dismissed = false
   where pp.plan_id = p_plan_id and pp.user_id = v_me
     and exists (select 1 from public.plans p join public.users o on o.id = p.owner_id
                  where p.id = pp.plan_id and not o.is_banned);
  if not found then
    raise exception 'There is no invitation here.' using errcode = 'no_data_found';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.respond_session_proposal(p_proposal_id uuid, p_accept boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me   uuid := private.current_user_id();
  v_p    public.session_proposals%rowtype;
  v_sess uuid;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if p_accept is null then
    raise exception 'Say yes or no.' using errcode = 'check_violation';
  end if;

  -- Lock the proposal so two taps cannot both accept.
  select * into v_p from public.session_proposals where id = p_proposal_id and recipient_id = v_me for update;
  if v_p.id is null then
    raise exception 'There is no proposal here for you to answer.' using errcode = 'no_data_found';
  end if;
  if v_p.status <> 'proposed' then
    raise exception 'That proposal has already been answered or replaced.' using errcode = 'check_violation';
  end if;
  if private.minor_without_consent(v_me) or private.minor_without_consent(v_p.proposer_id)
     or not private.are_live_partners(v_me, v_p.proposer_id) then
    raise exception 'That proposal is no longer available.' using errcode = 'insufficient_privilege';
  end if;

  if not p_accept then
    update public.session_proposals set status = 'declined', resolved_at = now() where id = v_p.id;
    return null;
  end if;

  if v_p.proposed_start <= now() then
    raise exception 'That time has already passed.' using errcode = 'check_violation';
  end if;

  insert into public.sessions (plan_id, activity_type, starts_at, timezone, created_by)
  values (v_p.plan_id, v_p.activity_type, v_p.proposed_start, v_p.timezone, v_p.proposer_id)
  returning id into v_sess;
  insert into public.session_participants (session_id, user_id, rsvp_status)
  values (v_sess, v_p.proposer_id, 'confirmed'), (v_sess, v_me, 'confirmed');

  update public.session_proposals set status = 'accepted', resolved_at = now(), session_id = v_sess where id = v_p.id;
  return v_sess;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.review_access()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select private.is_reviewer();
$function$
;

CREATE OR REPLACE FUNCTION public.review_inbox()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if not private.is_reviewer() then
    raise exception 'Not available.' using errcode = 'insufficient_privilege';
  end if;
  return jsonb_build_object(
    'reports', coalesce((
      select jsonb_agg(to_jsonb(q) order by q.severe desc, q.created_at)
        from (
          select r.id, r.created_at, r.reason::text as reason, r.free_text, r.reported_id,
                 (r.reason in ('harassment', 'violence_safety')) as severe,
                 coalesce(rp.display_name, 'Someone') as reporter_name, coalesce(ep.display_name, 'Someone') as reported_name
            from public.reports r
            left join public.profiles rp on rp.user_id = r.reporter_id
            left join public.profiles ep on ep.user_id = r.reported_id
           where r.status = 'under_review'
        ) q), '[]'::jsonb),
    'connections', coalesce((
      select jsonb_agg(to_jsonb(q) order by (q.state = 'held') desc, q.created_at desc)
        from (
          select m.id, m.created_at, m.state, m.formed_via, c.name as club_name,
                 coalesce(mp.display_name, 'Someone') as minor_name, coalesce(ap.display_name, 'Someone') as adult_name
            from public.minor_adult_matches m
            left join public.profiles mp on mp.user_id = m.minor_user_id
            left join public.profiles ap on ap.user_id = m.adult_user_id
            left join public.clubs c on c.id = m.shared_club_id
           order by (m.state = 'held') desc, m.created_at desc
           limit 50
        ) q), '[]'::jsonb)
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.review_release_held(p_row_id uuid, p_release boolean)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  if not private.is_reviewer() then
    raise exception 'Not available.' using errcode = 'insufficient_privilege';
  end if;
  return public.release_held_connection(p_row_id, coalesce(p_release, false), private.current_user_id());
end;
$function$
;

CREATE OR REPLACE FUNCTION public.review_resolve_report(p_report_id uuid, p_action text, p_note text DEFAULT ''::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
  v_reported uuid;
begin
  if not private.is_reviewer() then
    raise exception 'Not available.' using errcode = 'insufficient_privilege';
  end if;
  select reported_id into v_reported from public.reports where id = p_report_id and status = 'under_review';
  if v_reported is null then
    raise exception 'There is no open report with that id.' using errcode = 'no_data_found';
  end if;
  if v_reported = v_me then
    raise exception 'A reviewer cannot action a report about themselves.' using errcode = 'insufficient_privilege';
  end if;
  return public.ts_resolve_report(p_report_id, p_action, p_note, v_me)::text;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.revoke_guardian_consent(p_link_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_link  public.guardian_links%rowtype;
  v_guard uuid;
  v_ended uuid[];
begin
  select l.* into v_link
    from public.guardian_links l
    join public.guardians g on g.id = l.guardian_id
    join public.users u on u.id = g.user_id
   where l.id = p_link_id and u.auth_id = auth.uid();

  if v_link.id is null then
    raise exception 'No such guardian link for this account.'
      using errcode = 'insufficient_privilege';
  end if;

  select user_id into v_guard from public.guardians where id = v_link.guardian_id;

  update public.guardian_links set status = 'revoked', revoked_at = now() where id = p_link_id;

  update public.users
     set consent_status = 'revoked', consent_status_set_at = now()
   where id = v_link.minor_user_id;

  with ended as (
    update public.matches m
       set deleted_at = now()
     where m.deleted_at is null
       and v_link.minor_user_id in (m.requester_id, m.recipient_id)
       and exists (
         select 1 from public.users other
          where other.id = case when m.requester_id = v_link.minor_user_id then m.recipient_id else m.requester_id end
            and other.age_status in ('self_attested_adult', 'adult'))
    returning m.id
  )
  select coalesce(array_agg(id), '{}') into v_ended from ended;

  update public.chat_threads set archived = true where match_id = any (v_ended);

  delete from public.thread_participants tp
   where tp.role = 'guardian_observer'
     and tp.user_id = v_guard
     and tp.thread_id in (select thread_id from public.thread_participants
                           where user_id = v_link.minor_user_id and role = 'member');

  -- The minor leaves every plan they shared with those adults, and the adults leave theirs.
  perform private.clear_plan_partners_between(m.requester_id, m.recipient_id)
     from public.matches m where m.id = any (v_ended);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rsvp_to_event(p_event_id uuid)
 RETURNS public.rsvp_status
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me     uuid := private.current_user_id();
  v_user   public.users%rowtype;
  v_event  public.club_events%rowtype;
  v_cur    public.rsvp_status;
  v_going  integer;
  v_status public.rsvp_status;
  v_pos    integer;
begin
  if v_me is null then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;

  select * into v_user from public.users where id = v_me;
  if v_user.id is null or v_user.is_banned then
    raise exception 'This account is suspended.' using errcode = 'insufficient_privilege';
  end if;
  -- §5.10: a pending or revoked minor is refused by every data-bearing surface.
  if v_user.age_status = 'minor' and v_user.consent_status <> 'granted' then
    raise exception 'This opens once your parent or guardian has confirmed.' using errcode = 'insufficient_privilege';
  end if;

  -- Lock the event first: every RSVP and cancellation for it now runs one at a time.
  select * into v_event from public.club_events where id = p_event_id for update;
  if v_event.id is null or v_event.cancelled_at is not null or v_event.starts_at <= now() then
    raise exception 'That session is not open for RSVPs.' using errcode = 'no_data_found';
  end if;

  if not exists (select 1 from public.club_memberships where club_id = v_event.club_id and user_id = v_me) then
    -- RSVP joins an ADULT to the club; a minor or unverified account must join by the club's code.
    if v_user.age_status in ('self_attested_adult', 'adult') then
      insert into public.club_memberships (club_id, user_id, joined_via) values (v_event.club_id, v_me, 'discover');
    else
      raise exception 'Join this club with its code first.' using errcode = 'insufficient_privilege';
    end if;
  end if;

  select status into v_cur from public.club_event_rsvps where club_event_id = p_event_id and user_id = v_me;
  if v_cur in ('going', 'waitlisted') then
    return v_cur;                                   -- already in; asking again changes nothing
  end if;

  select count(*) into v_going from public.club_event_rsvps where club_event_id = p_event_id and status = 'going';
  if v_event.capacity is null or v_going < v_event.capacity then
    v_status := 'going';
    v_pos := null;
  else
    v_status := 'waitlisted';
    select coalesce(max(waitlist_position), 0) + 1 into v_pos
      from public.club_event_rsvps where club_event_id = p_event_id and status = 'waitlisted';
  end if;

  insert into public.club_event_rsvps (club_event_id, user_id, status, waitlist_position)
  values (p_event_id, v_me, v_status, v_pos)
  on conflict (club_event_id, user_id)
  do update set status = excluded.status, waitlist_position = excluded.waitlist_position, created_at = now();

  return v_status;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.sessions_together(p_other uuid)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  return (select count(*)::int from private.completed_together() ct where ct.user_id = v_me and ct.other_id = p_other);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_checkin_sharing(p_session uuid, p_minutes integer)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me     uuid := private.current_user_id();
  v_reason text;
  v_start  timestamptz;
  v_until  timestamptz;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if p_minutes is null or p_minutes not in (30, 60, 120, 240) then
    raise exception 'Pick 30 minutes, 1 hour, 2 hours or 4 hours.' using errcode = 'check_violation';
  end if;
  v_reason := private.checkin_eligible(p_session, v_me);
  if v_reason is not null then
    raise exception 'Check-in sharing isn''t available for this session.' using errcode = 'insufficient_privilege';
  end if;
  select starts_at into v_start from public.sessions where id = p_session;
  v_until := least(now() + make_interval(mins => p_minutes), v_start + interval '90 minutes');
  update public.session_participants set checkin_opt_in = true, checkin_until = v_until where session_id = p_session and user_id = v_me;
  return v_until;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_club_leaderboard_optout(p_club uuid, p_opted_out boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if not exists (select 1 from public.club_memberships where club_id = p_club and user_id = v_me) then
    raise exception 'You''re not a member of that club.' using errcode = 'insufficient_privilege';
  end if;
  if p_opted_out then
    insert into public.club_leaderboard_opt_outs (club_id, user_id) values (p_club, v_me) on conflict do nothing;
  else
    delete from public.club_leaderboard_opt_outs where club_id = p_club and user_id = v_me;
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_club_show_leaderboard(p_club uuid, p_show boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  update public.clubs set show_leaderboard = coalesce(p_show, false) where id = p_club and organizer_id = v_me;
  if not found then
    raise exception 'Only the club''s organizer can change this.' using errcode = 'insufficient_privilege';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_guardian_controls(p_link_id uuid, p_adult_connections_allowed boolean, p_per_connection_approval_required boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
begin
  update public.guardian_links l
     set adult_connections_allowed = p_adult_connections_allowed,
         per_connection_approval_required = p_per_connection_approval_required
    from public.guardians g
    join public.users u on u.id = g.user_id
   where l.id = p_link_id and l.guardian_id = g.id and u.auth_id = auth.uid();

  if not found then
    raise exception 'No such guardian link for this account.'
      using errcode = 'insufficient_privilege';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_leaderboard_visibility(p_value public.leaderboard_visibility)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  insert into public.leaderboard_settings (user_id, visibility) values (v_me, p_value)
  on conflict (user_id) do update set visibility = excluded.visibility;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_live_map(p_minutes integer)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me    uuid := private.current_user_id();
  v_age   public.age_status;
  v_until timestamptz;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if p_minutes is null or p_minutes not in (30, 60, 120, 240) then
    raise exception 'Pick 30 minutes, 1 hour, 2 hours or 4 hours.' using errcode = 'check_violation';
  end if;

  select age_status into v_age from public.users where id = v_me;
  if v_age not in ('self_attested_adult', 'adult') then
    raise exception 'The live map isn''t available for this account.' using errcode = 'insufficient_privilege';
  end if;

  if not exists (select 1 from public.profiles where user_id = v_me and home_point is not null) then
    raise exception 'Choose your neighborhood first, so there''s somewhere to show you.' using errcode = 'check_violation';
  end if;

  v_until := now() + make_interval(mins => p_minutes);
  update public.profiles set live_map_visible_until = v_until where user_id = v_me;
  return v_until;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_neighborhood(p_slug text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
declare
  v_me       uuid := private.current_user_id();
  v_centroid extensions.geography(point, 4326);
  v_found    boolean;
begin
  if v_me is null or private.viewer_is_banned() then
    raise exception 'Not available.' using errcode = 'insufficient_privilege';
  end if;

  select n.centroid, true into v_centroid, v_found
    from public.neighborhoods n where n.slug = p_slug and n.hidden_at is null;
  if v_found is not true then
    raise exception 'Unknown neighborhood.' using errcode = 'invalid_parameter_value';
  end if;

  update public.profiles
     set neighborhood = p_slug, home_point = v_centroid
   where user_id = v_me;

  if not found then
    raise exception 'Set up your profile first.' using errcode = 'no_data_found';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_plan_place(p_plan_id uuid, p_place text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me    uuid := private.current_user_id();
  v_place text := btrim(coalesce(p_place, ''));
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if char_length(v_place) > 120 then
    raise exception 'A place can be up to 120 characters.' using errcode = 'check_violation';
  end if;
  update public.plans set place = v_place where id = p_plan_id and owner_id = v_me;
  if not found then
    raise exception 'That plan is not yours to change.' using errcode = 'insufficient_privilege';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_plan_reminder_offset(p_minutes integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if p_minutes not in (15, 30, 60, 120, 1440) then
    raise exception 'Choose 15 minutes, 30 minutes, 1 hour, 2 hours or 1 day.' using errcode = 'check_violation';
  end if;
  insert into public.notification_settings (user_id, plan_reminder_offset_minutes) values (v_me, p_minutes)
  on conflict (user_id) do update set plan_reminder_offset_minutes = excluded.plan_reminder_offset_minutes, updated_at = now();
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_plan_template(p_plan_id uuid, p_template_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if p_template_id is not null
     and not exists (select 1 from public.workout_templates where id = p_template_id and owner_id = v_me) then
    raise exception 'That template is not yours.' using errcode = 'check_violation';
  end if;
  update public.plans set linked_template_id = p_template_id where id = p_plan_id and owner_id = v_me;
  if not found then
    raise exception 'That plan is not yours to change.' using errcode = 'insufficient_privilege';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_proposal_place(p_proposal_id uuid, p_place text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me    uuid := private.current_user_id();
  v_place text := btrim(coalesce(p_place, ''));
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if char_length(v_place) > 120 then
    raise exception 'A place can be up to 120 characters.' using errcode = 'check_violation';
  end if;
  -- Only the person who proposed it, and only while it is still a proposal: an accepted time is not rewritten under the other person.
  update public.session_proposals set place = v_place where id = p_proposal_id and proposer_id = v_me and status = 'proposed';
  if not found then
    raise exception 'You can only add a place to a session you proposed, before it is answered.' using errcode = 'insufficient_privilege';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_push_enabled(p_enabled boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  insert into public.notification_settings (user_id, push_enabled) values (v_me, coalesce(p_enabled, true))
  on conflict (user_id) do update set push_enabled = excluded.push_enabled, updated_at = now();
end;
$function$
;

CREATE OR REPLACE FUNCTION public.shared_availability(p_partner_id uuid)
 RETURNS TABLE(day_of_week smallint, time_block public.time_block)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if p_partner_id is null or not private.are_live_partners(v_me, p_partner_id) then
    raise exception 'You can compare times with people you are matched with.' using errcode = 'insufficient_privilege';
  end if;
  return query
    select a.day_of_week, a.time_block
      from public.availability a
      join public.availability b on b.day_of_week = a.day_of_week and b.time_block = a.time_block
     where a.profile_id = v_me and b.profile_id = p_partner_id
     order by a.day_of_week, a.time_block;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.submit_report(p_reported uuid, p_reason public.report_reason, p_text text DEFAULT ''::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me   uuid := private.current_user_id();
  v_text text := btrim(coalesce(p_text, ''));
  v_id   uuid;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if p_reported is null or p_reported = v_me or p_reason is null then
    raise exception 'Choose who and why.' using errcode = 'check_violation';
  end if;
  if char_length(v_text) > 1000 then
    raise exception 'A report can be up to 1000 characters.' using errcode = 'check_violation';
  end if;
  -- One message for "no such person" and "not someone you can report", so this cannot be used to probe for accounts.
  if not exists (select 1 from public.users where id = p_reported) or not private.may_report(v_me, p_reported) then
    raise exception 'That person is not available to report.' using errcode = 'no_data_found';
  end if;

  -- Already reported and still open: that is the answer, not an error.
  select id into v_id from public.reports where reporter_id = v_me and reported_id = p_reported and status = 'under_review';
  if v_id is not null then return v_id; end if;

  if (select count(*) from public.reports where reporter_id = v_me and created_at > now() - interval '24 hours') >= 10 then
    raise exception 'You''ve sent a lot of reports today. Our team is reviewing them.' using errcode = 'check_violation';
  end if;

  insert into public.reports (reporter_id, reported_id, reason, free_text) values (v_me, p_reported, p_reason, v_text)
  returning id into v_id;
  return v_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.suggest_plan_for_log(p_log_id uuid)
 RETURNS TABLE(plan_id uuid, label text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me  uuid := private.current_user_id();
  v_log public.activity_logs%rowtype;
  v_plan uuid;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  select * into v_log from public.activity_logs where id = p_log_id and user_id = v_me;
  if v_log.id is null or v_log.plan_id is not null then return; end if;
  v_plan := private.plan_for_log(v_me, v_log);
  if v_plan is null then return; end if;
  return query select pl.id, pl.label from public.plans pl where pl.id = v_plan;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.ts_resolve_report(p_report_id uuid, p_action text, p_note text DEFAULT ''::text, p_reviewer uuid DEFAULT NULL::uuid)
 RETURNS public.report_status
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_status public.report_status;
begin
  if p_action not in ('ban', 'dismiss') then
    raise exception 'Action must be ban or dismiss.' using errcode = 'check_violation';
  end if;
  v_status := case p_action when 'ban' then 'actioned'::public.report_status else 'dismissed'::public.report_status end;

  update public.reports
     set status = v_status, reviewer_id = p_reviewer, action_taken = left(nullif(btrim(coalesce(p_note, '')), ''), 500), resolved_at = now()
   where id = p_report_id and status = 'under_review';
  if not found then
    raise exception 'There is no open report with that id.' using errcode = 'no_data_found';
  end if;
  return v_status;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.unregister_push_token(p_token text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null then raise exception 'Sign in first.' using errcode = 'insufficient_privilege'; end if;
  update public.push_tokens set revoked_at = now() where user_id = v_me and token = p_token and revoked_at is null;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.update_activity_log(p_log_id uuid, p_other_label text, p_title text, p_started_at timestamp with time zone, p_duration_seconds integer, p_distance numeric, p_distance_unit text, p_notes text, p_sets jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me    uuid := private.current_user_id();
  v_log   public.activity_logs%rowtype;
  v_label text := nullif(btrim(p_other_label), '');
  v_title text;
  v_dist  private.parsed_set;
  v_el    jsonb;
  v_pos   integer := 0;
  v_set   private.parsed_set;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;

  select * into v_log from public.activity_logs where id = p_log_id and user_id = v_me for update;
  if v_log.id is null then
    raise exception 'That activity is not yours to change.' using errcode = 'no_data_found';
  end if;
  if v_log.source = 'auto_sync' then
    raise exception 'A synced activity comes from your watch and can''t be edited — you can still change its note.' using errcode = 'check_violation';
  end if;

  if p_started_at is null or p_started_at > now() + interval '5 minutes' then
    raise exception 'An activity cannot start in the future.' using errcode = 'check_violation';
  end if;
  if p_started_at <> v_log.started_at and p_started_at < now() - interval '366 days' then
    raise exception 'That is more than a year ago.' using errcode = 'check_violation';
  end if;
  if p_duration_seconds is not null and p_duration_seconds not between 1 and 86400 then
    raise exception 'A duration must be between 1 second and 24 hours.' using errcode = 'check_violation';
  end if;
  if v_log.source = 'live_gps' and p_duration_seconds is null then
    raise exception 'A recorded activity has a duration.' using errcode = 'check_violation';
  end if;
  if char_length(coalesce(p_notes, '')) > 2000 then
    raise exception 'A note can be up to 2000 characters.' using errcode = 'check_violation';
  end if;
  if v_label is not null and char_length(v_label) > 40 then
    raise exception 'An activity name can be up to 40 characters.' using errcode = 'check_violation';
  end if;
  if v_log.activity_type = 'other' and p_distance is not null then
    raise exception 'Other activities track time only — no distance or pace.' using errcode = 'check_violation';
  end if;
  if v_log.activity_type <> 'other' then v_label := null; end if;

  if p_distance is not null then
    v_dist := private.parse_set_json(jsonb_build_object('exercise', 'x', 'distance', p_distance, 'distance_unit', p_distance_unit));
  end if;

  if p_sets is not null and (jsonb_typeof(p_sets) <> 'array' or jsonb_array_length(p_sets) > 120) then
    raise exception 'An activity can have up to 120 sets.' using errcode = 'check_violation';
  end if;

  v_title := nullif(btrim(p_title), '');
  if v_title is null then
    v_title := case v_log.activity_type when 'run' then 'Run' when 'lift' then 'Lift' when 'ride' then 'Ride' else coalesce(v_label, 'Activity') end;
  end if;
  if char_length(v_title) > 80 then
    raise exception 'A title can be up to 80 characters.' using errcode = 'check_violation';
  end if;

  update public.activity_logs
     set other_label = v_label,
         title = v_title,
         started_at = p_started_at,
         ended_at = case when p_duration_seconds is null then null else p_started_at + make_interval(secs => p_duration_seconds) end,
         duration_seconds = p_duration_seconds,
         distance = v_dist.distance,
         distance_unit = v_dist.distance_unit,
         notes = coalesce(btrim(p_notes), '')
   where id = p_log_id;

  delete from public.activity_sets where activity_log_id = p_log_id;
  if p_sets is not null then
    for v_el in select * from jsonb_array_elements(p_sets) loop
      v_pos := v_pos + 1;
      v_set := private.parse_set_json(v_el);
      insert into public.activity_sets (activity_log_id, position, exercise, detail, weight, weight_unit, reps,
                                        duration_seconds, pace_seconds, pace_unit, distance, distance_unit)
      values (p_log_id, v_pos, v_set.exercise, v_set.target_detail, v_set.weight, v_set.weight_unit, v_set.reps,
              v_set.duration_seconds, v_set.pace_seconds, v_set.pace_unit, v_set.distance, v_set.distance_unit);
    end loop;
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.update_activity_notes(p_log_id uuid, p_notes text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if char_length(coalesce(p_notes, '')) > 2000 then
    raise exception 'A note can be up to 2000 characters.' using errcode = 'check_violation';
  end if;
  update public.activity_logs set notes = coalesce(btrim(p_notes), '') where id = p_log_id and user_id = v_me;
  if not found then
    raise exception 'That activity is not yours to change.' using errcode = 'no_data_found';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.update_plan_schedule(p_plan_id uuid, p_scope text, p_occurrence_on date, p_day_of_week integer, p_start_time time without time zone, p_recurrence public.plan_recurrence, p_end_condition public.plan_end_condition, p_end_after_weeks integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me     uuid := private.current_user_id();
  v_plan   public.plans%rowtype;
  v_weeks  integer;
  v_new    uuid;
  v_start  date;
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;

  select * into v_plan from public.plans where id = p_plan_id and owner_id = v_me for update;
  if v_plan.id is null then
    raise exception 'That plan is not yours to change.' using errcode = 'insufficient_privilege';
  end if;
  if p_scope not in ('whole_series', 'this_and_following') then
    raise exception 'Choose whether to change this session, this and following, or the whole series.' using errcode = 'check_violation';
  end if;
  if p_day_of_week is null or p_day_of_week not between 0 and 6 or p_start_time is null then
    raise exception 'Choose a day and a time.' using errcode = 'check_violation';
  end if;

  -- A one-time plan is its own whole series; "this and following" is meaningless for it.
  if p_scope = 'whole_series' or v_plan.recurrence = 'one_time'
     or p_occurrence_on is null or p_occurrence_on <= v_plan.starts_on then
    update public.plans
       set day_of_week = p_day_of_week, start_time = p_start_time, recurrence = p_recurrence,
           end_condition = p_end_condition,
           end_after_weeks = case when p_end_condition = 'after_n_weeks' then p_end_after_weeks end,
           starts_on = private.next_plan_date(p_day_of_week, p_start_time, v_plan.timezone)
     where id = p_plan_id;
    return p_plan_id;
  end if;

  -- this_and_following: the date must be one of this series' occurrences.
  if mod(p_occurrence_on - v_plan.starts_on, 7) <> 0 then
    raise exception 'That date is not one of this plan''s sessions.' using errcode = 'check_violation';
  end if;
  v_weeks := (p_occurrence_on - v_plan.starts_on) / 7;      -- occurrences that stay in the old series
  if v_plan.end_after_weeks is not null and v_weeks >= v_plan.end_after_weeks then
    raise exception 'That date is after this plan ends.' using errcode = 'check_violation';
  end if;

  update public.plans set end_condition = 'after_n_weeks', end_after_weeks = v_weeks where id = p_plan_id;

  v_start := p_occurrence_on + ((p_day_of_week - extract(dow from p_occurrence_on)::int + 7) % 7);
  insert into public.plans (owner_id, activity_type, other_label, label, recurrence, day_of_week, start_time,
                            timezone, end_condition, end_after_weeks, starts_on, linked_template_id)
  values (v_me, v_plan.activity_type, v_plan.other_label, v_plan.label, p_recurrence, p_day_of_week, p_start_time,
          v_plan.timezone, p_end_condition,
          case when p_end_condition = 'after_n_weeks' then p_end_after_weeks end,
          v_start, v_plan.linked_template_id)
  returning id into v_new;

  -- The same people carry over, with the answer they had given.
  insert into public.plan_partners (plan_id, user_id, status, dismissed)
  select v_new, pp.user_id, pp.status, pp.dismissed from public.plan_partners pp where pp.plan_id = p_plan_id;

  return v_new;
exception when check_violation then
  if sqlerrm like '%plan_end_matches%' or sqlerrm like '%end_after_weeks%' then
    raise exception 'A plan that ends after some weeks needs between 1 and 52.' using errcode = 'check_violation';
  end if;
  raise;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.update_template(p_template_id uuid, p_name text, p_summary text, p_activity_type public.activity_type, p_sets jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_me uuid := private.current_user_id();
begin
  if v_me is null or (select private.viewer_is_banned()) then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;
  if coalesce(btrim(p_name), '') = '' or char_length(btrim(p_name)) > 80 then
    raise exception 'Give the template a name of up to 80 characters.' using errcode = 'check_violation';
  end if;
  if p_activity_type is null then
    raise exception 'Choose an activity type.' using errcode = 'check_violation';
  end if;

  perform 1 from public.workout_templates where id = p_template_id and owner_id = v_me for update;
  if not found then
    raise exception 'That template is not yours to change.' using errcode = 'no_data_found';
  end if;

  update public.workout_templates
     set name = btrim(p_name), summary = coalesce(btrim(p_summary), ''), activity_type = p_activity_type
   where id = p_template_id;

  delete from public.template_sets where template_id = p_template_id;
  perform private.write_template_sets(p_template_id, p_sets);
end;
$function$
;

-- ======================================================================
-- Column defaults
-- ======================================================================
alter table private.reviewers alter column added_at set default now();

alter table public.activity_logs alter column confirmed set default true;

alter table public.activity_logs alter column id set default gen_random_uuid();

alter table public.activity_logs alter column logged_at set default now();

alter table public.activity_logs alter column notes set default ''::text;

alter table public.activity_logs alter column source set default 'manual'::public.activity_source;

alter table public.activity_photos alter column created_at set default now();

alter table public.activity_photos alter column id set default gen_random_uuid();

alter table public.activity_sets alter column detail set default ''::text;

alter table public.activity_sets alter column id set default gen_random_uuid();

alter table public.activity_sets alter column weight_unit set default 'lb'::text;

alter table public.chat_threads alter column archived set default false;

alter table public.chat_threads alter column created_at set default now();

alter table public.chat_threads alter column id set default gen_random_uuid();

alter table public.checkin_locations alter column id set default gen_random_uuid();

alter table public.checkin_locations alter column purge_after set default (now() + '30 days'::interval);

alter table public.checkin_locations alter column recorded_at set default now();

alter table public.checkin_nudges alter column created_at set default now();

alter table public.club_event_rsvps alter column created_at set default now();

alter table public.club_events alter column created_at set default now();

alter table public.club_events alter column id set default gen_random_uuid();

alter table public.club_events alter column location_label set default ''::text;

alter table public.club_leaderboard_opt_outs alter column created_at set default now();

alter table public.club_memberships alter column joined_at set default now();

alter table public.clubs alter column created_at set default now();

alter table public.clubs alter column description set default ''::text;

alter table public.clubs alter column id set default gen_random_uuid();

alter table public.clubs alter column organizer_label set default ''::text;

alter table public.clubs alter column qr_code set default ('GW-C-'::text || upper(substr(replace((gen_random_uuid())::text, '-'::text, ''::text), 1, 10)));

alter table public.clubs alter column show_leaderboard set default false;

alter table public.custom_tags alter column first_seen_at set default now();

alter table public.custom_tags alter column id set default gen_random_uuid();

alter table public.custom_tags alter column usage_count set default 1;

alter table public.discover_filter_state alter column updated_at set default now();

alter table public.filter_presets alter column created_at set default now();

alter table public.filter_presets alter column id set default gen_random_uuid();

alter table public.guardian_connection_approvals alter column created_at set default now();

alter table public.guardian_connection_approvals alter column id set default gen_random_uuid();

alter table public.guardian_connection_approvals alter column status set default 'pending'::text;

alter table public.guardian_invitations alter column created_at set default now();

alter table public.guardian_invitations alter column id set default gen_random_uuid();

alter table public.guardian_links alter column adult_connections_allowed set default true;

alter table public.guardian_links alter column id set default gen_random_uuid();

alter table public.guardian_links alter column invited_at set default now();

alter table public.guardian_links alter column per_connection_approval_required set default true;

alter table public.guardian_links alter column status set default 'pending'::public.guardian_link_status;

alter table public.guardians alter column created_at set default now();

alter table public.guardians alter column id set default gen_random_uuid();

alter table public.leaderboard_settings alter column updated_at set default now();

alter table public.leaderboard_settings alter column visibility set default 'matches_and_clubs'::public.leaderboard_visibility;

alter table public.matches alter column id set default gen_random_uuid();

alter table public.matches alter column requested_at set default now();

alter table public.matches alter column source set default 'discover'::public.match_source;

alter table public.matches alter column status set default 'pending'::public.match_status;

alter table public.messages alter column id set default gen_random_uuid();

alter table public.messages alter column sent_at set default now();

alter table public.messages alter column type set default 'text'::public.message_type;

alter table public.minor_adult_matches alter column created_at set default now();

alter table public.minor_adult_matches alter column formed_via set default 'qr_scan'::text;

alter table public.minor_adult_matches alter column id set default gen_random_uuid();

alter table public.minor_adult_matches alter column reviewed set default false;

alter table public.minor_adult_matches alter column state set default 'active'::text;

alter table public.minor_qr_codes alter column issued_at set default now();

alter table public.neighborhoods alter column kind set default 'neighborhood'::text;

alter table public.neighborhoods alter column user_added set default false;

alter table public.notification_settings alter column plan_reminder_offset_minutes set default 60;

alter table public.notification_settings alter column push_enabled set default true;

alter table public.notification_settings alter column updated_at set default now();

alter table public.plan_partners alter column dismissed set default false;

alter table public.plan_partners alter column invited_at set default now();

alter table public.plan_partners alter column status set default 'invited'::public.plan_partner_status;

alter table public.plans alter column created_at set default now();

alter table public.plans alter column end_condition set default 'open_ended'::public.plan_end_condition;

alter table public.plans alter column id set default gen_random_uuid();

alter table public.plans alter column place set default ''::text;

alter table public.plans alter column recurrence set default 'recurring'::public.plan_recurrence;

alter table public.profile_sports alter column created_at set default now();

alter table public.profile_sports alter column id set default gen_random_uuid();

alter table public.profile_sports alter column is_primary set default false;

alter table public.profiles alter column id_verified set default false;

alter table public.profiles alter column measurement_system set default 'imperial'::text;

alter table public.profiles alter column photo_verified set default false;

alter table public.push_outbox alter column created_at set default now();

alter table public.push_outbox alter column data set default '{}'::jsonb;

alter table public.push_tickets alter column created_at set default now();

alter table public.push_tokens alter column created_at set default now();

alter table public.push_tokens alter column id set default gen_random_uuid();

alter table public.push_tokens alter column last_seen_at set default now();

alter table public.reports alter column created_at set default now();

alter table public.reports alter column free_text set default ''::text;

alter table public.reports alter column id set default gen_random_uuid();

alter table public.reports alter column status set default 'under_review'::public.report_status;

alter table public.session_participants alter column checkin_opt_in set default false;

alter table public.session_participants alter column rsvp_status set default 'invited'::public.session_rsvp;

alter table public.session_proposals alter column created_at set default now();

alter table public.session_proposals alter column id set default gen_random_uuid();

alter table public.session_proposals alter column place set default ''::text;

alter table public.session_proposals alter column status set default 'proposed'::public.proposal_status;

alter table public.sessions alter column created_at set default now();

alter table public.sessions alter column id set default gen_random_uuid();

alter table public.sessions alter column status set default 'agreed'::public.session_status;

alter table public.tag_match_settings alter column accepts set default 0;

alter table public.tag_match_settings alter column match_threshold set default 0.60;

alter table public.tag_match_settings alter column rejects set default 0;

alter table public.tag_match_settings alter column suggest_threshold set default 0.45;

alter table public.tag_match_settings alter column updated_at set default now();

alter table public.template_sets alter column id set default gen_random_uuid();

alter table public.template_sets alter column target_detail set default ''::text;

alter table public.template_sets alter column weight_unit set default 'lb'::text;

alter table public.template_share_responses alter column created_at set default now();

alter table public.thread_participants alter column joined_at set default now();

alter table public.thread_participants alter column role set default 'member'::public.thread_role;

alter table public.thread_settings alter column checkin_nudges_muted set default false;

alter table public.thread_settings alter column messages_muted set default false;

alter table public.users alter column age_status set default 'unverified'::public.age_status;

alter table public.users alter column age_status_set_at set default now();

alter table public.users alter column can_organize_clubs set default false;

alter table public.users alter column consent_status set default 'not_required'::public.consent_status;

alter table public.users alter column consent_status_set_at set default now();

alter table public.users alter column created_at set default now();

alter table public.users alter column id set default gen_random_uuid();

alter table public.users alter column is_banned set default false;

alter table public.verification_records alter column created_at set default now();

alter table public.verification_records alter column id set default gen_random_uuid();

alter table public.verification_records alter column provider set default 'stripe_identity'::text;

alter table public.verification_records alter column status set default 'pending'::text;

alter table public.verification_records alter column tier set default 'id_selfie'::text;

alter table public.verification_records alter column updated_at set default now();

alter table public.wearable_connections alter column connected_at set default now();

alter table public.wearable_events alter column received_at set default now();

alter table public.workout_templates alter column created_at set default now();

alter table public.workout_templates alter column id set default gen_random_uuid();

alter table public.workout_templates alter column source set default 'own'::public.template_source;

alter table public.workout_templates alter column summary set default ''::text;

-- ======================================================================
-- Constraints (primary and unique keys first, then checks, then foreign keys)
-- ======================================================================
alter table private.reviewers add constraint reviewers_pkey PRIMARY KEY (user_id);

alter table public.activity_logs add constraint activity_logs_pkey PRIMARY KEY (id);

alter table public.activity_photos add constraint activity_photos_pkey PRIMARY KEY (id);

alter table public.activity_sets add constraint activity_sets_pkey PRIMARY KEY (id);

alter table public.availability add constraint availability_pkey PRIMARY KEY (profile_id, day_of_week, time_block);

alter table public.chat_threads add constraint chat_threads_pkey PRIMARY KEY (id);

alter table public.checkin_locations add constraint checkin_locations_pkey PRIMARY KEY (id);

alter table public.checkin_nudges add constraint checkin_nudges_pkey PRIMARY KEY (session_id);

alter table public.club_event_rsvps add constraint club_event_rsvps_pkey PRIMARY KEY (club_event_id, user_id);

alter table public.club_events add constraint club_events_pkey PRIMARY KEY (id);

alter table public.club_leaderboard_opt_outs add constraint club_leaderboard_opt_outs_pkey PRIMARY KEY (club_id, user_id);

alter table public.club_memberships add constraint club_memberships_pkey PRIMARY KEY (club_id, user_id);

alter table public.clubs add constraint clubs_pkey PRIMARY KEY (id);

alter table public.custom_tags add constraint custom_tags_pkey PRIMARY KEY (id);

alter table public.discover_filter_state add constraint discover_filter_state_pkey PRIMARY KEY (user_id);

alter table public.filter_presets add constraint filter_presets_pkey PRIMARY KEY (id);

alter table public.guardian_connection_approvals add constraint guardian_connection_approvals_pkey PRIMARY KEY (id);

alter table public.guardian_invitations add constraint guardian_invitations_pkey PRIMARY KEY (id);

alter table public.guardian_links add constraint guardian_links_pkey PRIMARY KEY (id);

alter table public.guardians add constraint guardians_pkey PRIMARY KEY (id);

alter table public.leaderboard_settings add constraint leaderboard_settings_pkey PRIMARY KEY (user_id);

alter table public.matches add constraint matches_pkey PRIMARY KEY (id);

alter table public.messages add constraint messages_pkey PRIMARY KEY (id);

alter table public.minor_adult_matches add constraint minor_adult_matches_pkey PRIMARY KEY (id);

alter table public.minor_qr_codes add constraint minor_qr_codes_pkey PRIMARY KEY (user_id);

alter table public.neighborhoods add constraint neighborhoods_pkey PRIMARY KEY (slug);

alter table public.notification_settings add constraint notification_settings_pkey PRIMARY KEY (user_id);

alter table public.plan_partners add constraint plan_partners_pkey PRIMARY KEY (plan_id, user_id);

alter table public.plans add constraint plans_pkey PRIMARY KEY (id);

alter table public.profile_sports add constraint profile_sports_pkey PRIMARY KEY (id);

alter table public.profiles add constraint profiles_pkey PRIMARY KEY (user_id);

alter table public.push_outbox add constraint push_outbox_pkey PRIMARY KEY (id);

alter table public.push_tickets add constraint push_tickets_pkey PRIMARY KEY (ticket_id);

alter table public.push_tokens add constraint push_tokens_pkey PRIMARY KEY (id);

alter table public.reports add constraint reports_pkey PRIMARY KEY (id);

alter table public.session_participants add constraint session_participants_pkey PRIMARY KEY (session_id, user_id);

alter table public.session_proposals add constraint session_proposals_pkey PRIMARY KEY (id);

alter table public.sessions add constraint sessions_pkey PRIMARY KEY (id);

alter table public.tag_match_settings add constraint tag_match_settings_pkey PRIMARY KEY (user_id);

alter table public.template_sets add constraint template_sets_pkey PRIMARY KEY (id);

alter table public.template_share_responses add constraint template_share_responses_pkey PRIMARY KEY (message_id, user_id);

alter table public.thread_participants add constraint thread_participants_pkey PRIMARY KEY (thread_id, user_id);

alter table public.thread_settings add constraint thread_settings_pkey PRIMARY KEY (thread_id, user_id);

alter table public.users add constraint users_pkey PRIMARY KEY (id);

alter table public.verification_records add constraint verification_records_pkey PRIMARY KEY (id);

alter table public.wearable_connections add constraint wearable_connections_pkey PRIMARY KEY (user_id, provider_slug);

alter table public.wearable_events add constraint wearable_events_pkey PRIMARY KEY (id);

alter table public.workout_templates add constraint workout_templates_pkey PRIMARY KEY (id);

alter table public.activity_photos add constraint activity_photos_storage_path_key UNIQUE (storage_path);

alter table public.activity_sets add constraint activity_sets_activity_log_id_position_key UNIQUE (activity_log_id, "position");

alter table public.clubs add constraint clubs_qr_code_key UNIQUE (qr_code);

alter table public.guardian_connection_approvals add constraint guardian_connection_approvals_match_id_key UNIQUE (match_id);

alter table public.guardian_invitations add constraint guardian_invitations_token_hash_key UNIQUE (token_hash);

alter table public.guardians add constraint guardians_user_id_key UNIQUE (user_id);

alter table public.minor_qr_codes add constraint minor_qr_codes_code_key UNIQUE (code);

alter table public.profile_sports add constraint profile_sports_profile_id_tag_key UNIQUE (profile_id, tag);

alter table public.profiles add constraint profiles_qr_code_key UNIQUE (qr_code);

alter table public.push_outbox add constraint push_outbox_dedupe_key_key UNIQUE (dedupe_key);

alter table public.push_tokens add constraint push_tokens_user_id_token_key UNIQUE (user_id, token);

alter table public.template_sets add constraint template_sets_template_id_position_key UNIQUE (template_id, "position");

alter table public.users add constraint users_auth_id_key UNIQUE (auth_id);

alter table public.verification_records add constraint verification_records_provider_reference_id_key UNIQUE (provider_reference_id);

alter table public.activity_logs add constraint activity_distance_has_unit CHECK (((distance IS NULL) OR (distance_unit IS NOT NULL)));

alter table public.activity_logs add constraint activity_distance_range CHECK (((distance IS NULL) OR ((distance *
CASE distance_unit
    WHEN 'mi'::text THEN 1609.344
    WHEN 'km'::text THEN (1000)::numeric
    ELSE (1)::numeric
END) <= (1000000)::numeric)));

alter table public.activity_logs add constraint activity_ends_after_start CHECK (((ended_at IS NULL) OR (ended_at >= started_at)));

alter table public.activity_logs add constraint activity_external_id_with_provider CHECK (((provider IS NULL) = (external_activity_id IS NULL)));

alter table public.activity_logs add constraint activity_logs_avg_hr_check CHECK (((avg_hr IS NULL) OR ((avg_hr >= 20) AND (avg_hr <= 260))));

alter table public.activity_logs add constraint activity_logs_cadence_check CHECK (((cadence IS NULL) OR ((cadence >= 1) AND (cadence <= 400))));

alter table public.activity_logs add constraint activity_logs_calories_check CHECK (((calories IS NULL) OR ((calories >= 0) AND (calories <= 30000))));

alter table public.activity_logs add constraint activity_logs_device_provider_check CHECK (((device_provider IS NULL) OR ((char_length(device_provider) >= 1) AND (char_length(device_provider) <= 40))));

alter table public.activity_logs add constraint activity_logs_distance_check CHECK (((distance IS NULL) OR (distance > (0)::numeric)));

alter table public.activity_logs add constraint activity_logs_distance_unit_check CHECK (((distance_unit IS NULL) OR (distance_unit = ANY (ARRAY['mi'::text, 'km'::text, 'm'::text]))));

alter table public.activity_logs add constraint activity_logs_duration_seconds_check CHECK (((duration_seconds IS NULL) OR ((duration_seconds >= 1) AND (duration_seconds <= 86400))));

alter table public.activity_logs add constraint activity_logs_max_hr_check CHECK (((max_hr IS NULL) OR ((max_hr >= 20) AND (max_hr <= 260))));

alter table public.activity_logs add constraint activity_logs_notes_check CHECK ((char_length(notes) <= 2000));

alter table public.activity_logs add constraint activity_logs_other_label_check CHECK (((other_label IS NULL) OR ((char_length(btrim(other_label)) >= 1) AND (char_length(btrim(other_label)) <= 40))));

alter table public.activity_logs add constraint activity_logs_title_check CHECK (((char_length(btrim(title)) >= 1) AND (char_length(btrim(title)) <= 80)));

alter table public.activity_logs add constraint activity_other_is_duration_only CHECK (((activity_type <> 'other'::public.activity_type) OR ((distance IS NULL) AND (cadence IS NULL))));

alter table public.activity_logs add constraint activity_provider_matches_source CHECK (((source = 'auto_sync'::public.activity_source) = (provider IS NOT NULL)));

alter table public.activity_sets add constraint activity_sets_detail_check CHECK ((char_length(detail) <= 120));

alter table public.activity_sets add constraint activity_sets_distance_check CHECK (((distance IS NULL) OR (distance > (0)::numeric)));

alter table public.activity_sets add constraint activity_sets_distance_has_unit CHECK (((distance IS NULL) OR (distance_unit IS NOT NULL)));

alter table public.activity_sets add constraint activity_sets_distance_range CHECK (((distance IS NULL) OR ((distance *
CASE distance_unit
    WHEN 'mi'::text THEN 1609.344
    WHEN 'km'::text THEN (1000)::numeric
    ELSE (1)::numeric
END) <= (1000000)::numeric)));

alter table public.activity_sets add constraint activity_sets_distance_unit_check CHECK (((distance_unit IS NULL) OR (distance_unit = ANY (ARRAY['mi'::text, 'km'::text, 'm'::text]))));

alter table public.activity_sets add constraint activity_sets_duration_seconds_check CHECK (((duration_seconds IS NULL) OR ((duration_seconds >= 1) AND (duration_seconds <= 86400))));

alter table public.activity_sets add constraint activity_sets_exercise_check CHECK (((char_length(btrim(exercise)) >= 1) AND (char_length(btrim(exercise)) <= 80)));

alter table public.activity_sets add constraint activity_sets_pace_has_unit CHECK (((pace_seconds IS NULL) OR (pace_unit IS NOT NULL)));

alter table public.activity_sets add constraint activity_sets_pace_seconds_check CHECK (((pace_seconds IS NULL) OR ((pace_seconds >= 60) AND (pace_seconds <= 3600))));

alter table public.activity_sets add constraint activity_sets_pace_unit_check CHECK (((pace_unit IS NULL) OR (pace_unit = ANY (ARRAY['mi'::text, 'km'::text]))));

alter table public.activity_sets add constraint activity_sets_position_check CHECK ((("position" >= 1) AND ("position" <= 120)));

alter table public.activity_sets add constraint activity_sets_reps_check CHECK (((reps IS NULL) OR ((reps >= 1) AND (reps <= 999))));

alter table public.activity_sets add constraint activity_sets_weight_range CHECK (((weight IS NULL) OR ((weight >= (0)::numeric) AND (weight <= (
CASE weight_unit
    WHEN 'kg'::text THEN 1000
    ELSE 2000
END)::numeric))));

alter table public.activity_sets add constraint activity_sets_weight_unit_check CHECK ((weight_unit = ANY (ARRAY['lb'::text, 'kg'::text])));

alter table public.availability add constraint availability_day_of_week_check CHECK (((day_of_week >= 0) AND (day_of_week <= 6)));

alter table public.checkin_locations add constraint checkin_locations_lat_check CHECK (((lat >= ('-90'::integer)::double precision) AND (lat <= (90)::double precision)));

alter table public.checkin_locations add constraint checkin_locations_lng_check CHECK (((lng >= ('-180'::integer)::double precision) AND (lng <= (180)::double precision)));

alter table public.club_event_rsvps add constraint rsvp_position_matches_status CHECK (((status = 'waitlisted'::public.rsvp_status) = (waitlist_position IS NOT NULL)));

alter table public.club_event_rsvps add constraint rsvp_position_positive CHECK (((waitlist_position IS NULL) OR (waitlist_position >= 1)));

alter table public.club_events add constraint club_events_capacity_check CHECK (((capacity IS NULL) OR ((capacity >= 1) AND (capacity <= 10000))));

alter table public.club_events add constraint club_events_location_label_check CHECK ((char_length(location_label) <= 120));

alter table public.club_events add constraint club_events_title_check CHECK (((char_length(btrim(title)) >= 1) AND (char_length(btrim(title)) <= 120)));

alter table public.clubs add constraint clubs_description_check CHECK ((char_length(description) <= 1000));

alter table public.clubs add constraint clubs_name_check CHECK (((char_length(btrim(name)) >= 1) AND (char_length(btrim(name)) <= 80)));

alter table public.clubs add constraint clubs_organizer_label_check CHECK ((char_length(organizer_label) <= 80));

alter table public.custom_tags add constraint custom_tags_label_check CHECK (((char_length(label) >= 2) AND (char_length(label) <= 40)));

alter table public.discover_filter_state add constraint discover_filter_state_filter_state_check CHECK ((octet_length((filter_state)::text) <= 4096));

alter table public.filter_presets add constraint filter_presets_filter_state_check CHECK ((octet_length((filter_state)::text) <= 4096));

alter table public.filter_presets add constraint filter_presets_name_check CHECK (((char_length(btrim(name)) >= 1) AND (char_length(btrim(name)) <= 40)));

alter table public.guardian_connection_approvals add constraint approval_decided_has_time CHECK (((status = 'pending'::text) = (decided_at IS NULL)));

alter table public.guardian_connection_approvals add constraint guardian_connection_approvals_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'denied'::text])));

alter table public.guardian_invitations add constraint guardian_phone_needs_consent CHECK (((guardian_phone IS NULL) OR (guardian_sms_consent_at IS NOT NULL)));

alter table public.guardians add constraint verification_fields_agree CHECK ((((verified_at IS NULL) AND (verification_method IS NULL)) OR ((verified_at IS NOT NULL) AND (verification_method IS NOT NULL))));

alter table public.matches add constraint matches_matched_has_timestamp CHECK (((status = 'matched'::public.match_status) = (matched_at IS NOT NULL)));

alter table public.matches add constraint matches_not_self CHECK ((requester_id <> recipient_id));

alter table public.messages add constraint messages_payload_shape CHECK (((jsonb_typeof(payload) = 'object'::text) AND (octet_length((payload)::text) <= 8192) AND COALESCE(
CASE type
    WHEN 'text'::public.message_type THEN ((payload ? 'text'::text) AND ((payload - 'text'::text) = '{}'::jsonb) AND (jsonb_typeof((payload -> 'text'::text)) = 'string'::text) AND ((char_length((payload ->> 'text'::text)) >= 1) AND (char_length((payload ->> 'text'::text)) <= 4000)))
    WHEN 'template_share'::public.message_type THEN (((payload - 'template_id'::text) = '{}'::jsonb) AND ((payload ->> 'template_id'::text) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text))
    WHEN 'session_proposal'::public.message_type THEN (((payload - 'session_proposal_id'::text) = '{}'::jsonb) AND ((payload ->> 'session_proposal_id'::text) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text))
    WHEN 'checkin_nudge'::public.message_type THEN (((payload - 'session_id'::text) = '{}'::jsonb) AND ((payload ->> 'session_id'::text) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text))
    ELSE NULL::boolean
END, false)));

alter table public.minor_adult_matches add constraint minor_adult_distinct CHECK ((minor_user_id <> adult_user_id));

alter table public.minor_adult_matches add constraint minor_adult_matches_formed_via_check CHECK ((formed_via = ANY (ARRAY['qr_scan'::text, 'club_invite'::text])));

alter table public.minor_adult_matches add constraint minor_adult_matches_state_check CHECK ((state = ANY (ARRAY['active'::text, 'held'::text, 'released'::text, 'dismissed'::text])));

alter table public.neighborhoods add constraint neighborhoods_centroid_rule CHECK (((centroid IS NOT NULL) OR user_added OR (kind = 'other'::text)));

alter table public.neighborhoods add constraint neighborhoods_kind_check CHECK ((kind = ANY (ARRAY['neighborhood'::text, 'city'::text, 'other'::text])));

alter table public.notification_settings add constraint notification_settings_plan_reminder_offset_minutes_check CHECK ((plan_reminder_offset_minutes = ANY (ARRAY[15, 30, 60, 120, 1440])));

alter table public.plans add constraint plan_end_matches CHECK ((((recurrence = 'one_time'::public.plan_recurrence) AND (end_condition = 'open_ended'::public.plan_end_condition) AND (end_after_weeks IS NULL)) OR ((recurrence = 'recurring'::public.plan_recurrence) AND (end_condition = 'open_ended'::public.plan_end_condition) AND (end_after_weeks IS NULL)) OR ((recurrence = 'recurring'::public.plan_recurrence) AND (end_condition = 'after_n_weeks'::public.plan_end_condition) AND (end_after_weeks IS NOT NULL))));

alter table public.plans add constraint plan_other_label_matches CHECK (((activity_type = 'other'::public.activity_type) = (other_label IS NOT NULL)));

alter table public.plans add constraint plans_day_of_week_check CHECK (((day_of_week >= 0) AND (day_of_week <= 6)));

alter table public.plans add constraint plans_end_after_weeks_check CHECK (((end_after_weeks IS NULL) OR ((end_after_weeks >= 1) AND (end_after_weeks <= 52))));

alter table public.plans add constraint plans_label_check CHECK (((char_length(btrim(label)) >= 1) AND (char_length(btrim(label)) <= 80)));

alter table public.plans add constraint plans_other_label_check CHECK (((other_label IS NULL) OR ((char_length(btrim(other_label)) >= 1) AND (char_length(btrim(other_label)) <= 40))));

alter table public.plans add constraint plans_place_check CHECK ((char_length(place) <= 120));

alter table public.profiles add constraint profiles_measurement_system_check CHECK ((measurement_system = ANY (ARRAY['imperial'::text, 'metric'::text])));

alter table public.profiles add constraint profiles_years_training_check CHECK (((years_training IS NULL) OR (years_training >= 0)));

alter table public.push_outbox add constraint push_outbox_body_check CHECK (((char_length(body) >= 1) AND (char_length(body) <= 400)));

alter table public.push_outbox add constraint push_outbox_event_check CHECK ((event = ANY (ARRAY['match_request_received'::text, 'match_approved'::text, 'chat_message_new'::text, 'schedule_proposal'::text, 'plan_reminder'::text, 'checkin_nudge'::text])));

alter table public.push_outbox add constraint push_outbox_title_check CHECK (((char_length(title) >= 1) AND (char_length(title) <= 200)));

alter table public.push_tokens add constraint push_tokens_device_id_check CHECK (((device_id IS NULL) OR (char_length(device_id) <= 200)));

alter table public.push_tokens add constraint push_tokens_platform_check CHECK ((platform = ANY (ARRAY['ios'::text, 'android'::text])));

alter table public.push_tokens add constraint push_tokens_token_check CHECK (((char_length(token) >= 10) AND (char_length(token) <= 300)));

alter table public.reports add constraint reports_action_taken_check CHECK (((action_taken IS NULL) OR (char_length(action_taken) <= 500)));

alter table public.reports add constraint reports_free_text_check CHECK ((char_length(free_text) <= 1000));

alter table public.reports add constraint reports_not_self CHECK ((reporter_id <> reported_id));

alter table public.reports add constraint reports_resolved_has_time CHECK (((status = 'under_review'::public.report_status) = (resolved_at IS NULL)));

alter table public.session_participants add constraint session_participants_checkin_consistent CHECK ((checkin_opt_in = (checkin_until IS NOT NULL)));

alter table public.session_proposals add constraint proposal_resolved_matches CHECK (((status = 'proposed'::public.proposal_status) = (resolved_at IS NULL)));

alter table public.session_proposals add constraint proposal_two_people CHECK ((proposer_id <> recipient_id));

alter table public.session_proposals add constraint session_proposals_place_check CHECK ((char_length(place) <= 120));

alter table public.tag_match_settings add constraint tag_match_settings_accepts_check CHECK ((accepts >= 0));

alter table public.tag_match_settings add constraint tag_match_settings_match_threshold_check CHECK (((match_threshold >= 0.45) AND (match_threshold <= 0.75)));

alter table public.tag_match_settings add constraint tag_match_settings_rejects_check CHECK ((rejects >= 0));

alter table public.tag_match_settings add constraint tag_match_settings_suggest_threshold_check CHECK (((suggest_threshold >= 0.30) AND (suggest_threshold <= 0.55)));

alter table public.template_sets add constraint template_sets_distance_check CHECK (((distance IS NULL) OR (distance > (0)::numeric)));

alter table public.template_sets add constraint template_sets_distance_has_unit CHECK (((distance IS NULL) OR (distance_unit IS NOT NULL)));

alter table public.template_sets add constraint template_sets_distance_range CHECK (((distance IS NULL) OR ((distance *
CASE distance_unit
    WHEN 'mi'::text THEN 1609.344
    WHEN 'km'::text THEN (1000)::numeric
    ELSE (1)::numeric
END) <= (1000000)::numeric)));

alter table public.template_sets add constraint template_sets_distance_unit_check CHECK (((distance_unit IS NULL) OR (distance_unit = ANY (ARRAY['mi'::text, 'km'::text, 'm'::text]))));

alter table public.template_sets add constraint template_sets_duration_seconds_check CHECK (((duration_seconds IS NULL) OR ((duration_seconds >= 1) AND (duration_seconds <= 86400))));

alter table public.template_sets add constraint template_sets_exercise_check CHECK (((char_length(btrim(exercise)) >= 1) AND (char_length(btrim(exercise)) <= 80)));

alter table public.template_sets add constraint template_sets_pace_has_unit CHECK (((pace_seconds IS NULL) OR (pace_unit IS NOT NULL)));

alter table public.template_sets add constraint template_sets_pace_seconds_check CHECK (((pace_seconds IS NULL) OR ((pace_seconds >= 60) AND (pace_seconds <= 3600))));

alter table public.template_sets add constraint template_sets_pace_unit_check CHECK (((pace_unit IS NULL) OR (pace_unit = ANY (ARRAY['mi'::text, 'km'::text]))));

alter table public.template_sets add constraint template_sets_position_check CHECK ((("position" >= 1) AND ("position" <= 120)));

alter table public.template_sets add constraint template_sets_reps_check CHECK (((reps IS NULL) OR ((reps >= 1) AND (reps <= 999))));

alter table public.template_sets add constraint template_sets_target_detail_check CHECK ((char_length(target_detail) <= 120));

alter table public.template_sets add constraint template_sets_weight_range CHECK (((weight IS NULL) OR ((weight >= (0)::numeric) AND (weight <= (
CASE weight_unit
    WHEN 'kg'::text THEN 1000
    ELSE 2000
END)::numeric))));

alter table public.template_sets add constraint template_sets_weight_unit_check CHECK ((weight_unit = ANY (ARRAY['lb'::text, 'kg'::text])));

alter table public.users add constraint banned_at_present_when_banned CHECK (((is_banned AND (banned_at IS NOT NULL)) OR (NOT is_banned)));

alter table public.users add constraint consent_status_matches_age CHECK ((((age_status = 'minor'::public.age_status) AND (consent_status <> 'not_required'::public.consent_status)) OR ((age_status <> 'minor'::public.age_status) AND (consent_status = 'not_required'::public.consent_status))));

alter table public.verification_records add constraint result_only_when_verified CHECK (((age_check_result IS NULL) OR (status = 'verified'::text)));

alter table public.verification_records add constraint verification_records_age_check_result_check CHECK ((age_check_result = ANY (ARRAY['adult'::text, 'minor'::text, 'inconclusive'::text])));

alter table public.verification_records add constraint verification_records_provider_check CHECK ((provider = 'stripe_identity'::text));

alter table public.verification_records add constraint verification_records_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'verified'::text, 'requires_input'::text, 'canceled'::text])));

alter table public.verification_records add constraint verification_records_tier_check CHECK ((tier = ANY (ARRAY['liveness'::text, 'id_selfie'::text])));

alter table public.verification_records add constraint verified_has_time_and_result CHECK (((status = 'verified'::text) = ((verified_at IS NOT NULL) AND (age_check_result IS NOT NULL))));

alter table public.wearable_connections add constraint wearable_connections_provider_slug_check CHECK (((char_length(provider_slug) >= 1) AND (char_length(provider_slug) <= 40)));

alter table public.workout_templates add constraint template_own_has_no_sender CHECK (((source = 'received'::public.template_source) OR (received_from_user_id IS NULL)));

alter table public.workout_templates add constraint workout_templates_name_check CHECK (((char_length(btrim(name)) >= 1) AND (char_length(btrim(name)) <= 80)));

alter table public.workout_templates add constraint workout_templates_summary_check CHECK ((char_length(summary) <= 200));

alter table private.reviewers add constraint reviewers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.activity_logs add constraint activity_logs_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE SET NULL;

alter table public.activity_logs add constraint activity_logs_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE SET NULL;

alter table public.activity_logs add constraint activity_logs_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.workout_templates(id) ON DELETE SET NULL;

alter table public.activity_logs add constraint activity_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.activity_photos add constraint activity_photos_activity_log_id_fkey FOREIGN KEY (activity_log_id) REFERENCES public.activity_logs(id) ON DELETE CASCADE;

alter table public.activity_sets add constraint activity_sets_activity_log_id_fkey FOREIGN KEY (activity_log_id) REFERENCES public.activity_logs(id) ON DELETE CASCADE;

alter table public.availability add constraint availability_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(user_id) ON DELETE CASCADE;

alter table public.chat_threads add constraint chat_threads_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE SET NULL;

alter table public.checkin_locations add constraint checkin_locations_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE CASCADE;

alter table public.checkin_locations add constraint checkin_locations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.checkin_nudges add constraint checkin_nudges_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE CASCADE;

alter table public.checkin_nudges add constraint checkin_nudges_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES public.chat_threads(id) ON DELETE SET NULL;

alter table public.club_event_rsvps add constraint club_event_rsvps_club_event_id_fkey FOREIGN KEY (club_event_id) REFERENCES public.club_events(id) ON DELETE CASCADE;

alter table public.club_event_rsvps add constraint club_event_rsvps_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.club_events add constraint club_events_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id) ON DELETE CASCADE;

alter table public.club_events add constraint club_events_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE RESTRICT;

alter table public.club_leaderboard_opt_outs add constraint club_leaderboard_opt_outs_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id) ON DELETE CASCADE;

alter table public.club_leaderboard_opt_outs add constraint club_leaderboard_opt_outs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.club_memberships add constraint club_memberships_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id) ON DELETE CASCADE;

alter table public.club_memberships add constraint club_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.clubs add constraint clubs_organizer_id_fkey FOREIGN KEY (organizer_id) REFERENCES public.users(id) ON DELETE RESTRICT;

alter table public.custom_tags add constraint custom_tags_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;

alter table public.discover_filter_state add constraint discover_filter_state_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.filter_presets add constraint filter_presets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.guardian_connection_approvals add constraint guardian_connection_approvals_guardian_link_id_fkey FOREIGN KEY (guardian_link_id) REFERENCES public.guardian_links(id) ON DELETE CASCADE;

alter table public.guardian_connection_approvals add constraint guardian_connection_approvals_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;

alter table public.guardian_connection_approvals add constraint guardian_connection_approvals_minor_user_id_fkey FOREIGN KEY (minor_user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.guardian_invitations add constraint guardian_invitations_minor_user_id_fkey FOREIGN KEY (minor_user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.guardian_links add constraint guardian_links_guardian_id_fkey FOREIGN KEY (guardian_id) REFERENCES public.guardians(id) ON DELETE CASCADE;

alter table public.guardian_links add constraint guardian_links_minor_user_id_fkey FOREIGN KEY (minor_user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.guardians add constraint guardians_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.leaderboard_settings add constraint leaderboard_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.matches add constraint matches_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.matches add constraint matches_requester_id_fkey FOREIGN KEY (requester_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.messages add constraint messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE SET NULL;

alter table public.messages add constraint messages_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES public.chat_threads(id) ON DELETE CASCADE;

alter table public.minor_adult_matches add constraint minor_adult_matches_adult_user_id_fkey FOREIGN KEY (adult_user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.minor_adult_matches add constraint minor_adult_matches_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE SET NULL;

alter table public.minor_adult_matches add constraint minor_adult_matches_minor_user_id_fkey FOREIGN KEY (minor_user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.minor_adult_matches add constraint minor_adult_matches_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.users(id) ON DELETE SET NULL;

alter table public.minor_adult_matches add constraint minor_adult_matches_shared_club_id_fkey FOREIGN KEY (shared_club_id) REFERENCES public.clubs(id) ON DELETE CASCADE;

alter table public.minor_qr_codes add constraint minor_qr_codes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.neighborhoods add constraint neighborhoods_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;

alter table public.notification_settings add constraint notification_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.plan_partners add constraint plan_partners_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE CASCADE;

alter table public.plan_partners add constraint plan_partners_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.plans add constraint plans_linked_template_id_fkey FOREIGN KEY (linked_template_id) REFERENCES public.workout_templates(id) ON DELETE SET NULL;

alter table public.plans add constraint plans_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.profile_sports add constraint profile_sports_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(user_id) ON DELETE CASCADE;

alter table public.profiles add constraint profiles_neighborhood_fk FOREIGN KEY (neighborhood) REFERENCES public.neighborhoods(slug) ON UPDATE CASCADE;

alter table public.profiles add constraint profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.push_outbox add constraint push_outbox_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.push_tickets add constraint push_tickets_outbox_id_fkey FOREIGN KEY (outbox_id) REFERENCES public.push_outbox(id) ON DELETE CASCADE;

alter table public.push_tickets add constraint push_tickets_token_id_fkey FOREIGN KEY (token_id) REFERENCES public.push_tokens(id) ON DELETE SET NULL;

alter table public.push_tokens add constraint push_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.reports add constraint reports_reported_id_fkey FOREIGN KEY (reported_id) REFERENCES public.users(id) ON DELETE SET NULL;

alter table public.reports add constraint reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.users(id) ON DELETE SET NULL;

alter table public.reports add constraint reports_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.users(id) ON DELETE SET NULL;

alter table public.session_participants add constraint session_participants_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE CASCADE;

alter table public.session_participants add constraint session_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.session_proposals add constraint session_proposals_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE SET NULL;

alter table public.session_proposals add constraint session_proposals_proposer_id_fkey FOREIGN KEY (proposer_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.session_proposals add constraint session_proposals_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.session_proposals add constraint session_proposals_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE SET NULL;

alter table public.sessions add constraint sessions_club_event_id_fkey FOREIGN KEY (club_event_id) REFERENCES public.club_events(id) ON DELETE SET NULL;

alter table public.sessions add constraint sessions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.sessions add constraint sessions_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE SET NULL;

alter table public.tag_match_settings add constraint tag_match_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.template_sets add constraint template_sets_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.workout_templates(id) ON DELETE CASCADE;

alter table public.template_share_responses add constraint template_share_responses_copied_template_id_fkey FOREIGN KEY (copied_template_id) REFERENCES public.workout_templates(id) ON DELETE SET NULL;

alter table public.template_share_responses add constraint template_share_responses_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(id) ON DELETE CASCADE;

alter table public.template_share_responses add constraint template_share_responses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.thread_participants add constraint thread_participants_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES public.chat_threads(id) ON DELETE CASCADE;

alter table public.thread_participants add constraint thread_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.thread_settings add constraint thread_settings_thread_id_user_id_fkey FOREIGN KEY (thread_id, user_id) REFERENCES public.thread_participants(thread_id, user_id) ON DELETE CASCADE;

alter table public.users add constraint users_auth_id_fkey FOREIGN KEY (auth_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public.verification_records add constraint verification_records_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.wearable_connections add constraint wearable_connections_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.workout_templates add constraint workout_templates_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE CASCADE;

alter table public.workout_templates add constraint workout_templates_received_from_user_id_fkey FOREIGN KEY (received_from_user_id) REFERENCES public.users(id) ON DELETE SET NULL;

-- ======================================================================
-- Indexes
-- ======================================================================
CREATE UNIQUE INDEX activity_logs_external_unique ON public.activity_logs USING btree (user_id, provider, external_activity_id) WHERE (provider IS NOT NULL);

CREATE INDEX activity_logs_user_idx ON public.activity_logs USING btree (user_id, started_at DESC);

CREATE INDEX activity_photos_log_idx ON public.activity_photos USING btree (activity_log_id);

CREATE INDEX chat_threads_match_idx ON public.chat_threads USING btree (match_id);

CREATE UNIQUE INDEX chat_threads_stream_channel_idx ON public.chat_threads USING btree (stream_channel_id);

CREATE INDEX checkin_locations_purge_idx ON public.checkin_locations USING btree (purge_after);

CREATE INDEX checkin_locations_session_idx ON public.checkin_locations USING btree (session_id, user_id, recorded_at DESC);

CREATE INDEX checkin_nudges_thread_idx ON public.checkin_nudges USING btree (thread_id, created_at DESC);

CREATE INDEX club_event_rsvps_event_idx ON public.club_event_rsvps USING btree (club_event_id, status, waitlist_position);

CREATE INDEX club_events_club_idx ON public.club_events USING btree (club_id, starts_at);

CREATE INDEX club_leaderboard_opt_outs_user_idx ON public.club_leaderboard_opt_outs USING btree (user_id);

CREATE INDEX club_memberships_user_idx ON public.club_memberships USING btree (user_id);

CREATE INDEX clubs_organizer_idx ON public.clubs USING btree (organizer_id);

CREATE INDEX custom_tags_created_by_idx ON public.custom_tags USING btree (created_by);

CREATE UNIQUE INDEX custom_tags_label_unique ON public.custom_tags USING btree (lower(label));

CREATE INDEX filter_presets_user_idx ON public.filter_presets USING btree (user_id);

CREATE UNIQUE INDEX filter_presets_user_name_unique ON public.filter_presets USING btree (user_id, lower(btrim(name)));

CREATE INDEX guardian_connection_approvals_link_idx ON public.guardian_connection_approvals USING btree (guardian_link_id, status);

CREATE INDEX guardian_invitations_minor_idx ON public.guardian_invitations USING btree (minor_user_id);

CREATE INDEX guardian_links_guardian_idx ON public.guardian_links USING btree (guardian_id);

CREATE INDEX guardian_links_minor_idx ON public.guardian_links USING btree (minor_user_id);

CREATE UNIQUE INDEX guardian_links_one_active_per_minor ON public.guardian_links USING btree (minor_user_id) WHERE (status = 'active'::public.guardian_link_status);

CREATE UNIQUE INDEX matches_one_live_row_per_pair ON public.matches USING btree (LEAST(requester_id, recipient_id), GREATEST(requester_id, recipient_id)) WHERE (deleted_at IS NULL);

CREATE INDEX matches_recipient_idx ON public.matches USING btree (recipient_id);

CREATE INDEX matches_requester_idx ON public.matches USING btree (requester_id);

CREATE INDEX messages_sender_idx ON public.messages USING btree (sender_id);

CREATE INDEX messages_thread_sent_idx ON public.messages USING btree (thread_id, sent_at);

CREATE INDEX minor_adult_matches_minor_idx ON public.minor_adult_matches USING btree (minor_user_id, created_at DESC);

CREATE INDEX neighborhoods_created_by_idx ON public.neighborhoods USING btree (created_by);

CREATE INDEX plan_partners_user_idx ON public.plan_partners USING btree (user_id);

CREATE INDEX plans_owner_idx ON public.plans USING btree (owner_id, created_at DESC);

CREATE UNIQUE INDEX profile_sports_one_primary_idx ON public.profile_sports USING btree (profile_id) WHERE is_primary;

CREATE INDEX profile_sports_tag_idx ON public.profile_sports USING btree (tag);

CREATE INDEX profiles_live_map_idx ON public.profiles USING btree (live_map_visible_until) WHERE (live_map_visible_until IS NOT NULL);

CREATE INDEX profiles_neighborhood_idx ON public.profiles USING btree (neighborhood);

CREATE INDEX push_outbox_pending_idx ON public.push_outbox USING btree (id) WHERE ((sent_at IS NULL) AND (failed_at IS NULL));

CREATE INDEX push_tickets_unchecked_idx ON public.push_tickets USING btree (created_at) WHERE (checked_at IS NULL);

CREATE INDEX push_tokens_live_idx ON public.push_tokens USING btree (user_id) WHERE (revoked_at IS NULL);

CREATE INDEX push_tokens_token_idx ON public.push_tokens USING btree (token);

CREATE UNIQUE INDEX reports_one_open_per_pair ON public.reports USING btree (reporter_id, reported_id) WHERE (status = 'under_review'::public.report_status);

CREATE INDEX reports_queue_idx ON public.reports USING btree (status, created_at);

CREATE INDEX reports_reported_idx ON public.reports USING btree (reported_id);

CREATE INDEX session_participants_user_idx ON public.session_participants USING btree (user_id);

CREATE INDEX session_proposals_proposer_idx ON public.session_proposals USING btree (proposer_id, status);

CREATE INDEX session_proposals_recipient_idx ON public.session_proposals USING btree (recipient_id, status);

CREATE INDEX sessions_plan_idx ON public.sessions USING btree (plan_id, occurrence_on);

CREATE UNIQUE INDEX sessions_plan_occurrence_idx ON public.sessions USING btree (plan_id, occurrence_on) WHERE ((plan_id IS NOT NULL) AND (occurrence_on IS NOT NULL));

CREATE INDEX sessions_starts_idx ON public.sessions USING btree (starts_at);

CREATE INDEX thread_participants_user_idx ON public.thread_participants USING btree (user_id);

CREATE INDEX users_age_status_idx ON public.users USING btree (age_status);

CREATE INDEX users_is_banned_idx ON public.users USING btree (is_banned) WHERE is_banned;

CREATE INDEX verification_records_user_idx ON public.verification_records USING btree (user_id, created_at DESC);

CREATE INDEX workout_templates_owner_idx ON public.workout_templates USING btree (owner_id, created_at DESC);

-- ======================================================================
-- Views
-- ======================================================================
create view public.my_guardian_invitation with (security_invoker=true) as
 SELECT minor_user_id,
    guardian_first_name,
    guardian_last_name,
    guardian_email,
    guardian_phone_hint,
    created_at,
    email_sent_at,
    sms_sent_at,
    expires_at,
    (created_at + '14 days'::interval) AS soft_lock_at,
    (created_at + '30 days'::interval) AS deletion_at
   FROM public.guardian_invitations i
  WHERE ((superseded_at IS NULL) AND (accepted_at IS NULL));

-- ======================================================================
-- Triggers
-- ======================================================================
CREATE TRIGGER activity_photos_limit BEFORE INSERT ON public.activity_photos FOR EACH ROW EXECUTE FUNCTION private.limit_activity_photos();

CREATE TRIGGER checkin_locations_no_minor BEFORE INSERT ON public.checkin_locations FOR EACH ROW EXECUTE FUNCTION private.no_minor_checkin_location();

CREATE TRIGGER clubs_limit_per_organizer BEFORE INSERT ON public.clubs FOR EACH ROW EXECUTE FUNCTION private.limit_clubs_per_organizer();

CREATE TRIGGER filter_presets_limit BEFORE INSERT ON public.filter_presets FOR EACH ROW EXECUTE FUNCTION private.limit_filter_presets();

CREATE TRIGGER leaderboard_settings_no_public_minor BEFORE INSERT OR UPDATE ON public.leaderboard_settings FOR EACH ROW EXECUTE FUNCTION private.leaderboard_no_public_minor();

CREATE TRIGGER matches_enforce_rules BEFORE INSERT OR UPDATE OF status, requester_id, recipient_id ON public.matches FOR EACH ROW EXECUTE FUNCTION private.enforce_match_rules();

CREATE TRIGGER matches_push AFTER INSERT OR UPDATE OF status ON public.matches FOR EACH ROW EXECUTE FUNCTION private.push_on_match();

CREATE TRIGGER messages_push AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION private.push_on_message();

CREATE TRIGGER plan_partners_limit BEFORE INSERT ON public.plan_partners FOR EACH ROW EXECUTE FUNCTION private.limit_plan_partners();

CREATE TRIGGER plans_limit BEFORE INSERT ON public.plans FOR EACH ROW EXECUTE FUNCTION private.limit_plans();

CREATE TRIGGER profiles_minor_live_map_exclusion BEFORE INSERT OR UPDATE OF live_map_visible_until ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.enforce_minor_live_map_exclusion();

CREATE TRIGGER push_outbox_kick AFTER INSERT ON public.push_outbox FOR EACH STATEMENT EXECUTE FUNCTION private.push_outbox_kick();

CREATE TRIGGER reports_ban_on_actioned AFTER UPDATE OF status ON public.reports FOR EACH ROW EXECUTE FUNCTION private.ban_on_actioned_report();

CREATE TRIGGER reports_final BEFORE UPDATE OF status ON public.reports FOR EACH ROW EXECUTE FUNCTION private.reports_are_final();

CREATE TRIGGER session_participants_no_minor_checkin BEFORE INSERT OR UPDATE OF checkin_opt_in, user_id ON public.session_participants FOR EACH ROW EXECUTE FUNCTION private.no_minor_checkin();

CREATE TRIGGER session_proposals_push AFTER INSERT OR UPDATE OF status ON public.session_proposals FOR EACH ROW EXECUTE FUNCTION private.push_on_proposal();

CREATE TRIGGER thread_participants_limit_members BEFORE INSERT OR UPDATE OF role ON public.thread_participants FOR EACH ROW EXECUTE FUNCTION private.limit_thread_members();

CREATE TRIGGER users_clear_live_map_on_minor_downgrade AFTER UPDATE OF age_status ON public.users FOR EACH ROW EXECUTE FUNCTION public.clear_live_map_on_minor_downgrade();

CREATE TRIGGER users_leaderboard_public_off AFTER UPDATE OF age_status ON public.users FOR EACH ROW EXECUTE FUNCTION private.leaderboard_public_off_on_downgrade();

CREATE TRIGGER workout_templates_limit BEFORE INSERT ON public.workout_templates FOR EACH ROW EXECUTE FUNCTION private.limit_templates();

-- ======================================================================
-- Trigger on auth.users
-- ======================================================================
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- ======================================================================
-- Row level security
-- ======================================================================
alter table private.reviewers enable row level security;
alter table private.reviewers force row level security;

alter table public.activity_logs enable row level security;
alter table public.activity_logs force row level security;

alter table public.activity_photos enable row level security;
alter table public.activity_photos force row level security;

alter table public.activity_sets enable row level security;
alter table public.activity_sets force row level security;

alter table public.availability enable row level security;
alter table public.availability force row level security;

alter table public.chat_threads enable row level security;
alter table public.chat_threads force row level security;

alter table public.checkin_locations enable row level security;
alter table public.checkin_locations force row level security;

alter table public.checkin_nudges enable row level security;
alter table public.checkin_nudges force row level security;

alter table public.club_event_rsvps enable row level security;
alter table public.club_event_rsvps force row level security;

alter table public.club_events enable row level security;
alter table public.club_events force row level security;

alter table public.club_leaderboard_opt_outs enable row level security;
alter table public.club_leaderboard_opt_outs force row level security;

alter table public.club_memberships enable row level security;
alter table public.club_memberships force row level security;

alter table public.clubs enable row level security;
alter table public.clubs force row level security;

alter table public.custom_tags enable row level security;
alter table public.custom_tags force row level security;

alter table public.discover_filter_state enable row level security;
alter table public.discover_filter_state force row level security;

alter table public.filter_presets enable row level security;
alter table public.filter_presets force row level security;

alter table public.guardian_connection_approvals enable row level security;
alter table public.guardian_connection_approvals force row level security;

alter table public.guardian_invitations enable row level security;
alter table public.guardian_invitations force row level security;

alter table public.guardian_links enable row level security;
alter table public.guardian_links force row level security;

alter table public.guardians enable row level security;
alter table public.guardians force row level security;

alter table public.leaderboard_settings enable row level security;
alter table public.leaderboard_settings force row level security;

alter table public.matches enable row level security;
alter table public.matches force row level security;

alter table public.messages enable row level security;
alter table public.messages force row level security;

alter table public.minor_adult_matches enable row level security;
alter table public.minor_adult_matches force row level security;

alter table public.minor_qr_codes enable row level security;
alter table public.minor_qr_codes force row level security;

alter table public.neighborhoods enable row level security;
alter table public.neighborhoods force row level security;

alter table public.notification_settings enable row level security;
alter table public.notification_settings force row level security;

alter table public.plan_partners enable row level security;
alter table public.plan_partners force row level security;

alter table public.plans enable row level security;
alter table public.plans force row level security;

alter table public.profile_sports enable row level security;
alter table public.profile_sports force row level security;

alter table public.profiles enable row level security;
alter table public.profiles force row level security;

alter table public.push_outbox enable row level security;
alter table public.push_outbox force row level security;

alter table public.push_tickets enable row level security;
alter table public.push_tickets force row level security;

alter table public.push_tokens enable row level security;
alter table public.push_tokens force row level security;

alter table public.reports enable row level security;
alter table public.reports force row level security;

alter table public.session_participants enable row level security;
alter table public.session_participants force row level security;

alter table public.session_proposals enable row level security;
alter table public.session_proposals force row level security;

alter table public.sessions enable row level security;
alter table public.sessions force row level security;

alter table public.tag_match_settings enable row level security;
alter table public.tag_match_settings force row level security;

alter table public.template_sets enable row level security;
alter table public.template_sets force row level security;

alter table public.template_share_responses enable row level security;
alter table public.template_share_responses force row level security;

alter table public.thread_participants enable row level security;
alter table public.thread_participants force row level security;

alter table public.thread_settings enable row level security;
alter table public.thread_settings force row level security;

alter table public.users enable row level security;
alter table public.users force row level security;

alter table public.verification_records enable row level security;
alter table public.verification_records force row level security;

alter table public.wearable_connections enable row level security;
alter table public.wearable_connections force row level security;

alter table public.wearable_events enable row level security;
alter table public.wearable_events force row level security;

alter table public.workout_templates enable row level security;
alter table public.workout_templates force row level security;

-- ======================================================================
-- Policies
-- ======================================================================
create policy activity_logs_select_own on public.activity_logs as permissive for select to authenticated
  using (((user_id = ( SELECT private.current_user_id() AS current_user_id)) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))));

create policy activity_photos_select_own on public.activity_photos as permissive for select to authenticated
  using (((NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned)) AND private.viewer_owns_log(activity_log_id)));

create policy activity_sets_select_own on public.activity_sets as permissive for select to authenticated
  using (((NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned)) AND private.viewer_owns_log(activity_log_id)));

create policy availability_delete_own on public.availability as permissive for delete to authenticated
  using (((profile_id = ( SELECT private.current_user_id() AS current_user_id)) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))));

create policy availability_insert_own on public.availability as permissive for insert to authenticated
  with check (((profile_id = ( SELECT private.current_user_id() AS current_user_id)) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))));

create policy availability_select on public.availability as permissive for select to authenticated
  using (((profile_id = ( SELECT private.current_user_id() AS current_user_id)) OR (( SELECT private.viewer_may_browse_discover() AS viewer_may_browse_discover) AND private.profile_is_discoverable(profile_id))));

create policy chat_threads_select on public.chat_threads as permissive for select to authenticated
  using (private.can_read_thread(id));

create policy checkin_locations_participants on public.checkin_locations as permissive for select to authenticated
  using ((( SELECT private.viewer_in_session(checkin_locations.session_id) AS viewer_in_session) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))));

create policy checkin_locations_ts on public.checkin_locations as permissive for select to trust_and_safety
  using (true);

create policy checkin_nudges_participants on public.checkin_nudges as permissive for select to authenticated
  using ((( SELECT private.viewer_in_session(checkin_nudges.session_id) AS viewer_in_session) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))));

create policy checkin_nudges_ts on public.checkin_nudges as permissive for select to trust_and_safety
  using (true);

create policy club_event_rsvps_select_own on public.club_event_rsvps as permissive for select to authenticated
  using (((user_id = ( SELECT private.current_user_id() AS current_user_id)) AND ( SELECT private.viewer_club_standing_ok() AS viewer_club_standing_ok)));

create policy club_events_select on public.club_events as permissive for select to authenticated
  using (private.viewer_can_see_club(club_id));

create policy club_leaderboard_opt_outs_select_own on public.club_leaderboard_opt_outs as permissive for select to authenticated
  using (((user_id = ( SELECT private.current_user_id() AS current_user_id)) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))));

create policy club_memberships_select_own on public.club_memberships as permissive for select to authenticated
  using (((user_id = ( SELECT private.current_user_id() AS current_user_id)) AND ( SELECT private.viewer_club_standing_ok() AS viewer_club_standing_ok)));

create policy clubs_select on public.clubs as permissive for select to authenticated
  using (private.viewer_can_see_club(id));

create policy custom_tags_select on public.custom_tags as permissive for select to authenticated
  using (true);

create policy discover_filter_state_insert on public.discover_filter_state as permissive for insert to authenticated
  with check ((user_id = ( SELECT private.current_user_id() AS current_user_id)));

create policy discover_filter_state_select on public.discover_filter_state as permissive for select to authenticated
  using ((user_id = ( SELECT private.current_user_id() AS current_user_id)));

create policy discover_filter_state_update on public.discover_filter_state as permissive for update to authenticated
  using ((user_id = ( SELECT private.current_user_id() AS current_user_id)))
  with check ((user_id = ( SELECT private.current_user_id() AS current_user_id)));

create policy filter_presets_delete on public.filter_presets as permissive for delete to authenticated
  using ((user_id = ( SELECT private.current_user_id() AS current_user_id)));

create policy filter_presets_insert on public.filter_presets as permissive for insert to authenticated
  with check ((user_id = ( SELECT private.current_user_id() AS current_user_id)));

create policy filter_presets_select on public.filter_presets as permissive for select to authenticated
  using ((user_id = ( SELECT private.current_user_id() AS current_user_id)));

create policy filter_presets_update on public.filter_presets as permissive for update to authenticated
  using ((user_id = ( SELECT private.current_user_id() AS current_user_id)))
  with check ((user_id = ( SELECT private.current_user_id() AS current_user_id)));

create policy guardian_invitations_select_own_minor on public.guardian_invitations as permissive for select to authenticated
  using ((minor_user_id = ( SELECT private.current_user_id() AS current_user_id)));

create policy guardian_invitations_select_ts on public.guardian_invitations as permissive for select to trust_and_safety
  using (true);

create policy guardian_links_select_parties on public.guardian_links as permissive for select to authenticated
  using (((minor_user_id = private.current_user_id()) OR (guardian_id IN ( SELECT guardians.id
   FROM public.guardians
  WHERE (guardians.user_id = private.current_user_id())))));

create policy guardian_links_select_ts on public.guardian_links as permissive for select to trust_and_safety
  using (true);

create policy guardians_select_own on public.guardians as permissive for select to authenticated
  using ((user_id = private.current_user_id()));

create policy guardians_select_ts on public.guardians as permissive for select to trust_and_safety
  using (true);

create policy leaderboard_settings_select_own on public.leaderboard_settings as permissive for select to authenticated
  using (((user_id = ( SELECT private.current_user_id() AS current_user_id)) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))));

create policy matches_select_parties on public.matches as permissive for select to authenticated
  using (((deleted_at IS NULL) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned)) AND (((requester_id = ( SELECT private.current_user_id() AS current_user_id)) AND private.user_is_not_banned(recipient_id)) OR ((recipient_id = ( SELECT private.current_user_id() AS current_user_id)) AND private.user_is_not_banned(requester_id)))));

create policy messages_select on public.messages as permissive for select to authenticated
  using (private.can_read_thread(thread_id));

create policy minor_adult_matches_ts_select on public.minor_adult_matches as permissive for select to trust_and_safety
  using (true);

create policy neighborhoods_select on public.neighborhoods as permissive for select to authenticated
  using ((hidden_at IS NULL));

create policy notification_settings_select_own on public.notification_settings as permissive for select to authenticated
  using (((user_id = ( SELECT private.current_user_id() AS current_user_id)) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))));

create policy plan_partners_select on public.plan_partners as permissive for select to authenticated
  using (((NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned)) AND ((user_id = ( SELECT private.current_user_id() AS current_user_id)) OR private.viewer_owns_plan(plan_id))));

create policy plans_select on public.plans as permissive for select to authenticated
  using (((NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned)) AND ((owner_id = ( SELECT private.current_user_id() AS current_user_id)) OR private.viewer_is_plan_partner(id))));

create policy profile_sports_delete_own on public.profile_sports as permissive for delete to authenticated
  using (((profile_id = ( SELECT private.current_user_id() AS current_user_id)) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))));

create policy profile_sports_insert_own on public.profile_sports as permissive for insert to authenticated
  with check (((profile_id = ( SELECT private.current_user_id() AS current_user_id)) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))));

create policy profile_sports_select on public.profile_sports as permissive for select to authenticated
  using (((profile_id = ( SELECT private.current_user_id() AS current_user_id)) OR (( SELECT private.viewer_may_browse_discover() AS viewer_may_browse_discover) AND private.profile_is_discoverable(profile_id))));

create policy profile_sports_update_own on public.profile_sports as permissive for update to authenticated
  using (((profile_id = ( SELECT private.current_user_id() AS current_user_id)) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))))
  with check ((profile_id = ( SELECT private.current_user_id() AS current_user_id)));

create policy profiles_insert_own on public.profiles as permissive for insert to authenticated
  with check (((user_id = ( SELECT private.current_user_id() AS current_user_id)) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))));

create policy profiles_select on public.profiles as permissive for select to authenticated
  using (((user_id = ( SELECT private.current_user_id() AS current_user_id)) OR (( SELECT private.viewer_may_browse_discover() AS viewer_may_browse_discover) AND private.profile_is_discoverable(user_id))));

create policy profiles_update_own on public.profiles as permissive for update to authenticated
  using (((user_id = private.current_user_id()) AND (NOT private.viewer_is_banned())))
  with check ((user_id = private.current_user_id()));

create policy push_tokens_select_own on public.push_tokens as permissive for select to authenticated
  using (((user_id = ( SELECT private.current_user_id() AS current_user_id)) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))));

create policy reports_select_own on public.reports as permissive for select to authenticated
  using (((reporter_id = ( SELECT private.current_user_id() AS current_user_id)) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))));

create policy reports_ts_select on public.reports as permissive for select to trust_and_safety
  using (true);

create policy reports_ts_update on public.reports as permissive for update to trust_and_safety
  using (true)
  with check (true);

create policy session_participants_select on public.session_participants as permissive for select to authenticated
  using (((NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned)) AND private.viewer_in_session(session_id)));

create policy session_proposals_select on public.session_proposals as permissive for select to authenticated
  using (((NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned)) AND ((( SELECT private.current_user_id() AS current_user_id) = proposer_id) OR (( SELECT private.current_user_id() AS current_user_id) = recipient_id))));

create policy sessions_select on public.sessions as permissive for select to authenticated
  using (((NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned)) AND private.viewer_in_session(id)));

create policy tag_match_settings_insert on public.tag_match_settings as permissive for insert to authenticated
  with check ((user_id = ( SELECT private.current_user_id() AS current_user_id)));

create policy tag_match_settings_select on public.tag_match_settings as permissive for select to authenticated
  using ((user_id = ( SELECT private.current_user_id() AS current_user_id)));

create policy tag_match_settings_update on public.tag_match_settings as permissive for update to authenticated
  using ((user_id = ( SELECT private.current_user_id() AS current_user_id)))
  with check ((user_id = ( SELECT private.current_user_id() AS current_user_id)));

create policy template_sets_select_own on public.template_sets as permissive for select to authenticated
  using (((NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned)) AND (EXISTS ( SELECT 1
   FROM public.workout_templates t
  WHERE ((t.id = template_sets.template_id) AND (t.owner_id = ( SELECT private.current_user_id() AS current_user_id)))))));

create policy template_share_responses_select_own on public.template_share_responses as permissive for select to authenticated
  using (((user_id = ( SELECT private.current_user_id() AS current_user_id)) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))));

create policy thread_participants_select on public.thread_participants as permissive for select to authenticated
  using (private.can_read_thread(thread_id));

create policy thread_settings_insert on public.thread_settings as permissive for insert to authenticated
  with check (((user_id = ( SELECT private.current_user_id() AS current_user_id)) AND private.can_read_thread(thread_id)));

create policy thread_settings_select on public.thread_settings as permissive for select to authenticated
  using ((user_id = ( SELECT private.current_user_id() AS current_user_id)));

create policy thread_settings_update on public.thread_settings as permissive for update to authenticated
  using ((user_id = ( SELECT private.current_user_id() AS current_user_id)))
  with check ((user_id = ( SELECT private.current_user_id() AS current_user_id)));

create policy users_select_own on public.users as permissive for select to authenticated
  using ((auth_id = ( SELECT auth.uid() AS uid)));

create policy users_update_own on public.users as permissive for update to authenticated
  using (((auth_id = ( SELECT auth.uid() AS uid)) AND (NOT is_banned)))
  with check ((auth_id = ( SELECT auth.uid() AS uid)));

create policy verification_records_select_own on public.verification_records as permissive for select to authenticated
  using (((user_id = ( SELECT private.current_user_id() AS current_user_id)) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))));

create policy verification_records_ts_select on public.verification_records as permissive for select to trust_and_safety
  using (true);

create policy wearable_connections_select_own on public.wearable_connections as permissive for select to authenticated
  using (((user_id = ( SELECT private.current_user_id() AS current_user_id)) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))));

create policy workout_templates_select_own on public.workout_templates as permissive for select to authenticated
  using (((owner_id = ( SELECT private.current_user_id() AS current_user_id)) AND (NOT ( SELECT private.viewer_is_banned() AS viewer_is_banned))));

-- ======================================================================
-- Storage policies
-- ======================================================================
create policy activity_photos_objects_delete on storage.objects as permissive for delete to authenticated
  using (((bucket_id = 'activity-photos'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text)));

create policy activity_photos_objects_insert on storage.objects as permissive for insert to authenticated
  with check (((bucket_id = 'activity-photos'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text)));

create policy activity_photos_objects_select on storage.objects as permissive for select to authenticated
  using (((bucket_id = 'activity-photos'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text)));

-- ======================================================================
-- Table grants
-- ======================================================================
revoke all on table private.reviewers from public, anon, authenticated, service_role;

revoke all on table public.activity_logs from public, anon, authenticated, service_role;
grant select on table public.activity_logs to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.activity_logs to service_role;

revoke all on table public.activity_photos from public, anon, authenticated, service_role;
grant select on table public.activity_photos to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.activity_photos to service_role;

revoke all on table public.activity_sets from public, anon, authenticated, service_role;
grant select on table public.activity_sets to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.activity_sets to service_role;

revoke all on table public.availability from public, anon, authenticated, service_role;
grant delete, insert, select on table public.availability to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.availability to service_role;

revoke all on table public.chat_threads from public, anon, authenticated, service_role;
grant select on table public.chat_threads to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.chat_threads to service_role;

revoke all on table public.checkin_locations from public, anon, authenticated, service_role;
grant select on table public.checkin_locations to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.checkin_locations to service_role;
grant select on table public.checkin_locations to trust_and_safety;

revoke all on table public.checkin_nudges from public, anon, authenticated, service_role;
grant select on table public.checkin_nudges to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.checkin_nudges to service_role;
grant select on table public.checkin_nudges to trust_and_safety;

revoke all on table public.club_event_rsvps from public, anon, authenticated, service_role;
grant select on table public.club_event_rsvps to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.club_event_rsvps to service_role;

revoke all on table public.club_events from public, anon, authenticated, service_role;
grant select on table public.club_events to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.club_events to service_role;

revoke all on table public.club_leaderboard_opt_outs from public, anon, authenticated, service_role;
grant select on table public.club_leaderboard_opt_outs to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.club_leaderboard_opt_outs to service_role;

revoke all on table public.club_memberships from public, anon, authenticated, service_role;
grant select on table public.club_memberships to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.club_memberships to service_role;

revoke all on table public.clubs from public, anon, authenticated, service_role;
grant select on table public.clubs to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.clubs to service_role;

revoke all on table public.custom_tags from public, anon, authenticated, service_role;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.custom_tags to service_role;

revoke all on table public.discover_filter_state from public, anon, authenticated, service_role;
grant insert, select, update on table public.discover_filter_state to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.discover_filter_state to service_role;

revoke all on table public.filter_presets from public, anon, authenticated, service_role;
grant delete, insert, select on table public.filter_presets to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.filter_presets to service_role;

revoke all on table public.guardian_connection_approvals from public, anon, authenticated, service_role;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.guardian_connection_approvals to service_role;

revoke all on table public.guardian_invitations from public, anon, authenticated, service_role;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.guardian_invitations to service_role;
grant select on table public.guardian_invitations to trust_and_safety;

revoke all on table public.guardian_links from public, anon, authenticated, service_role;
grant select on table public.guardian_links to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.guardian_links to service_role;
grant select on table public.guardian_links to trust_and_safety;

revoke all on table public.guardians from public, anon, authenticated, service_role;
grant select on table public.guardians to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.guardians to service_role;
grant select on table public.guardians to trust_and_safety;

revoke all on table public.leaderboard_settings from public, anon, authenticated, service_role;
grant select on table public.leaderboard_settings to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.leaderboard_settings to service_role;

revoke all on table public.matches from public, anon, authenticated, service_role;
grant select on table public.matches to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.matches to service_role;

revoke all on table public.messages from public, anon, authenticated, service_role;
grant select on table public.messages to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.messages to service_role;

revoke all on table public.minor_adult_matches from public, anon, authenticated, service_role;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.minor_adult_matches to service_role;
grant select on table public.minor_adult_matches to trust_and_safety;

revoke all on table public.minor_qr_codes from public, anon, authenticated, service_role;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.minor_qr_codes to service_role;

revoke all on table public.neighborhoods from public, anon, authenticated, service_role;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.neighborhoods to service_role;

revoke all on table public.notification_settings from public, anon, authenticated, service_role;
grant select on table public.notification_settings to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.notification_settings to service_role;

revoke all on table public.plan_partners from public, anon, authenticated, service_role;
grant select on table public.plan_partners to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.plan_partners to service_role;

revoke all on table public.plans from public, anon, authenticated, service_role;
grant select on table public.plans to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.plans to service_role;

revoke all on table public.profile_sports from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public.profile_sports to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.profile_sports to service_role;

revoke all on table public.profiles from public, anon, authenticated, service_role;
grant insert, select on table public.profiles to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.profiles to service_role;

revoke all on table public.push_outbox from public, anon, authenticated, service_role;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.push_outbox to service_role;

revoke all on table public.push_tickets from public, anon, authenticated, service_role;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.push_tickets to service_role;

revoke all on table public.push_tokens from public, anon, authenticated, service_role;
grant select on table public.push_tokens to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.push_tokens to service_role;

revoke all on table public.reports from public, anon, authenticated, service_role;
grant select on table public.reports to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.reports to service_role;
grant select on table public.reports to trust_and_safety;

revoke all on table public.session_participants from public, anon, authenticated, service_role;
grant select on table public.session_participants to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.session_participants to service_role;

revoke all on table public.session_proposals from public, anon, authenticated, service_role;
grant select on table public.session_proposals to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.session_proposals to service_role;

revoke all on table public.sessions from public, anon, authenticated, service_role;
grant select on table public.sessions to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.sessions to service_role;

revoke all on table public.tag_match_settings from public, anon, authenticated, service_role;
grant insert, select, update on table public.tag_match_settings to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.tag_match_settings to service_role;

revoke all on table public.template_sets from public, anon, authenticated, service_role;
grant select on table public.template_sets to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.template_sets to service_role;

revoke all on table public.template_share_responses from public, anon, authenticated, service_role;
grant select on table public.template_share_responses to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.template_share_responses to service_role;

revoke all on table public.thread_participants from public, anon, authenticated, service_role;
grant select on table public.thread_participants to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.thread_participants to service_role;

revoke all on table public.thread_settings from public, anon, authenticated, service_role;
grant insert, select on table public.thread_settings to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.thread_settings to service_role;

revoke all on table public.users from public, anon, authenticated, service_role;
grant select on table public.users to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.users to service_role;

revoke all on table public.verification_records from public, anon, authenticated, service_role;
grant select on table public.verification_records to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.verification_records to service_role;
grant select on table public.verification_records to trust_and_safety;

revoke all on table public.wearable_connections from public, anon, authenticated, service_role;
grant select on table public.wearable_connections to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.wearable_connections to service_role;

revoke all on table public.wearable_events from public, anon, authenticated, service_role;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.wearable_events to service_role;

revoke all on table public.workout_templates from public, anon, authenticated, service_role;
grant select on table public.workout_templates to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.workout_templates to service_role;

-- ======================================================================
-- View and sequence grants
-- ======================================================================
revoke all on table public.my_guardian_invitation from public, anon, authenticated, service_role;
grant select on table public.my_guardian_invitation to authenticated;
grant delete, insert, maintain, references, select, trigger, truncate, update on table public.my_guardian_invitation to service_role;

revoke all on sequence public.push_outbox_id_seq from public, anon, authenticated, service_role;
grant select, update, usage on sequence public.push_outbox_id_seq to anon;
grant select, update, usage on sequence public.push_outbox_id_seq to authenticated;
grant select, update, usage on sequence public.push_outbox_id_seq to service_role;

revoke all on sequence public.wearable_events_id_seq from public, anon, authenticated, service_role;
grant select, update, usage on sequence public.wearable_events_id_seq to anon;
grant select, update, usage on sequence public.wearable_events_id_seq to authenticated;
grant select, update, usage on sequence public.wearable_events_id_seq to service_role;

-- ======================================================================
-- Column grants
-- ======================================================================
grant select (id) on table public.custom_tags to authenticated;

grant select (label) on table public.custom_tags to authenticated;

grant select (usage_count) on table public.custom_tags to authenticated;

grant update (filter_state) on table public.filter_presets to authenticated;

grant update (name) on table public.filter_presets to authenticated;

grant select (accepted_at) on table public.guardian_invitations to authenticated;

grant select (created_at) on table public.guardian_invitations to authenticated;

grant select (email_sent_at) on table public.guardian_invitations to authenticated;

grant select (expires_at) on table public.guardian_invitations to authenticated;

grant select (guardian_email) on table public.guardian_invitations to authenticated;

grant select (guardian_first_name) on table public.guardian_invitations to authenticated;

grant select (guardian_last_name) on table public.guardian_invitations to authenticated;

grant select (guardian_phone_hint) on table public.guardian_invitations to authenticated;

grant select (minor_user_id) on table public.guardian_invitations to authenticated;

grant select (sms_sent_at) on table public.guardian_invitations to authenticated;

grant select (superseded_at) on table public.guardian_invitations to authenticated;

grant select (kind) on table public.neighborhoods to authenticated;

grant select (name) on table public.neighborhoods to authenticated;

grant select (slug) on table public.neighborhoods to authenticated;

grant select (user_added) on table public.neighborhoods to authenticated;

grant update (avatar_url) on table public.profiles to authenticated;

grant update (bio) on table public.profiles to authenticated;

grant update (display_name) on table public.profiles to authenticated;

grant update (experience_level) on table public.profiles to authenticated;

grant update (gender) on table public.profiles to authenticated;

grant update (headline_accomplishment) on table public.profiles to authenticated;

grant update (measurement_system) on table public.profiles to authenticated;

grant update (preferred_group_size) on table public.profiles to authenticated;

grant update (training_for) on table public.profiles to authenticated;

grant update (typical_session_length) on table public.profiles to authenticated;

grant update (usually_free) on table public.profiles to authenticated;

grant update (weekly_volume) on table public.profiles to authenticated;

grant update (years_training) on table public.profiles to authenticated;

grant update (action_taken) on table public.reports to trust_and_safety;

grant update (resolved_at) on table public.reports to trust_and_safety;

grant update (reviewer_id) on table public.reports to trust_and_safety;

grant update (status) on table public.reports to trust_and_safety;

grant update (checkin_nudges_muted) on table public.thread_settings to authenticated;

grant update (messages_muted) on table public.thread_settings to authenticated;

grant update (email) on table public.users to authenticated;

grant update (phone) on table public.users to authenticated;

-- ======================================================================
-- Function grants
-- ======================================================================
revoke all on function private.advance_qr_match(p_match_id uuid) from public, anon, authenticated, service_role;

revoke all on function private.are_live_partners(p_a uuid, p_b uuid) from public, anon, authenticated, service_role;

revoke all on function private.ban_on_actioned_report() from public, anon, authenticated, service_role;

revoke all on function private.can_read_thread(p_thread_id uuid) from public, anon, authenticated, service_role;
grant execute on function private.can_read_thread(p_thread_id uuid) to authenticated;

revoke all on function private.checkin_eligible(p_session uuid, p_user uuid) from public, anon, authenticated, service_role;

revoke all on function private.clear_plan_partners_between(p_a uuid, p_b uuid) from public, anon, authenticated, service_role;

revoke all on function private.club_facts(p_club uuid) from public, anon, authenticated, service_role;

revoke all on function private.completed_together() from public, anon, authenticated, service_role;

revoke all on function private.current_user_id() from public, anon, authenticated, service_role;
grant execute on function private.current_user_id() to authenticated;
grant execute on function private.current_user_id() to service_role;

revoke all on function private.enforce_match_rules() from public, anon, authenticated, service_role;

revoke all on function private.enqueue_plan_reminders() from public, anon, authenticated, service_role;

revoke all on function private.enqueue_push(p_recipient uuid, p_event text, p_title text, p_body text, p_data jsonb, p_dedupe text) from public, anon, authenticated, service_role;

revoke all on function private.ensure_thread(p_match_id uuid) from public, anon, authenticated, service_role;

revoke all on function private.is_plan_occurrence(p_plan public.plans, p_on date) from public, anon, authenticated, service_role;

revoke all on function private.is_reviewer() from public, anon, authenticated, service_role;

revoke all on function private.kick_account_erasure() from public, anon, authenticated, service_role;

revoke all on function private.kick_push() from public, anon, authenticated, service_role;

revoke all on function private.leaderboard_no_public_minor() from public, anon, authenticated, service_role;

revoke all on function private.leaderboard_public_off_on_downgrade() from public, anon, authenticated, service_role;

revoke all on function private.limit_activity_photos() from public, anon, authenticated, service_role;

revoke all on function private.limit_clubs_per_organizer() from public, anon, authenticated, service_role;

revoke all on function private.limit_filter_presets() from public, anon, authenticated, service_role;

revoke all on function private.limit_plan_partners() from public, anon, authenticated, service_role;

revoke all on function private.limit_plans() from public, anon, authenticated, service_role;

revoke all on function private.limit_templates() from public, anon, authenticated, service_role;

revoke all on function private.limit_thread_members() from public, anon, authenticated, service_role;

revoke all on function private.may_report(p_reporter uuid, p_reported uuid) from public, anon, authenticated, service_role;

revoke all on function private.may_see_standing(p_target uuid, p_viewer uuid, p_club uuid) from public, anon, authenticated, service_role;

revoke all on function private.minor_without_consent(p_user uuid) from public, anon, authenticated, service_role;

revoke all on function private.mutual_partner_count(p_a uuid, p_b uuid) from public, anon, authenticated, service_role;
grant execute on function private.mutual_partner_count(p_a uuid, p_b uuid) to authenticated;

revoke all on function private.next_plan_date(p_dow integer, p_time time without time zone, p_tz text) from public, anon, authenticated, service_role;

revoke all on function private.no_minor_checkin() from public, anon, authenticated, service_role;

revoke all on function private.no_minor_checkin_location() from public, anon, authenticated, service_role;

revoke all on function private.parse_set_json(p_el jsonb) from public, anon, authenticated, service_role;

revoke all on function private.plan_for_log(p_user uuid, p_log public.activity_logs) from public, anon, authenticated, service_role;

revoke all on function private.plan_last_on(p_recurrence public.plan_recurrence, p_starts_on date, p_weeks integer) from public, anon, authenticated, service_role;

revoke all on function private.plan_next_start(p_plan public.plans) from public, anon, authenticated, service_role;

revoke all on function private.profile_is_discoverable(p_user_id uuid) from public, anon, authenticated, service_role;
grant execute on function private.profile_is_discoverable(p_user_id uuid) to authenticated;
grant execute on function private.profile_is_discoverable(p_user_id uuid) to service_role;

revoke all on function private.promote_waitlist(p_event_id uuid) from public, anon, authenticated, service_role;

revoke all on function private.purge_checkin_locations() from public, anon, authenticated, service_role;

revoke all on function private.purge_old_reports() from public, anon, authenticated, service_role;

revoke all on function private.push_minute() from public, anon, authenticated, service_role;

revoke all on function private.push_name(p_user uuid) from public, anon, authenticated, service_role;

revoke all on function private.push_on_match() from public, anon, authenticated, service_role;

revoke all on function private.push_on_message() from public, anon, authenticated, service_role;

revoke all on function private.push_on_proposal() from public, anon, authenticated, service_role;

revoke all on function private.push_outbox_kick() from public, anon, authenticated, service_role;

revoke all on function private.push_tidy() from public, anon, authenticated, service_role;

revoke all on function private.push_when(p_at timestamp with time zone, p_tz text) from public, anon, authenticated, service_role;

revoke all on function private.qr_gate(p_scanner uuid, p_target uuid) from public, anon, authenticated, service_role;

revoke all on function private.qr_normalize(p_code text) from public, anon, authenticated, service_role;

revoke all on function private.ranked_members(p_club uuid, p_basis text, p_include uuid) from public, anon, authenticated, service_role;

revoke all on function private.reports_are_final() from public, anon, authenticated, service_role;

revoke all on function private.resolve_code(p_code text) from public, anon, authenticated, service_role;

revoke all on function private.share_for_recipient(p_message_id uuid) from public, anon, authenticated, service_role;

revoke all on function private.user_is_not_banned(p_user_id uuid) from public, anon, authenticated, service_role;
grant execute on function private.user_is_not_banned(p_user_id uuid) to authenticated;

revoke all on function private.viewer_can_see_club(p_club_id uuid) from public, anon, authenticated, service_role;
grant execute on function private.viewer_can_see_club(p_club_id uuid) to authenticated;

revoke all on function private.viewer_club_standing_ok() from public, anon, authenticated, service_role;
grant execute on function private.viewer_club_standing_ok() to authenticated;

revoke all on function private.viewer_in_session(p_session_id uuid) from public, anon, authenticated, service_role;
grant execute on function private.viewer_in_session(p_session_id uuid) to authenticated;

revoke all on function private.viewer_is_banned() from public, anon, authenticated, service_role;
grant execute on function private.viewer_is_banned() to authenticated;
grant execute on function private.viewer_is_banned() to service_role;

revoke all on function private.viewer_is_club_member(p_club_id uuid) from public, anon, authenticated, service_role;
grant execute on function private.viewer_is_club_member(p_club_id uuid) to authenticated;

revoke all on function private.viewer_is_plan_partner(p_plan_id uuid) from public, anon, authenticated, service_role;
grant execute on function private.viewer_is_plan_partner(p_plan_id uuid) to authenticated;

revoke all on function private.viewer_may_browse_discover() from public, anon, authenticated, service_role;
grant execute on function private.viewer_may_browse_discover() to authenticated;
grant execute on function private.viewer_may_browse_discover() to service_role;

revoke all on function private.viewer_may_create_club() from public, anon, authenticated, service_role;

revoke all on function private.viewer_owns_log(p_log_id uuid) from public, anon, authenticated, service_role;
grant execute on function private.viewer_owns_log(p_log_id uuid) to authenticated;

revoke all on function private.viewer_owns_plan(p_plan_id uuid) from public, anon, authenticated, service_role;
grant execute on function private.viewer_owns_plan(p_plan_id uuid) to authenticated;

revoke all on function private.visibility_of(p_user uuid) from public, anon, authenticated, service_role;

revoke all on function private.wearable_events_tidy() from public, anon, authenticated, service_role;

revoke all on function private.write_template_sets(p_template_id uuid, p_sets jsonb) from public, anon, authenticated, service_role;

revoke all on function public.accept_shared_template(p_message_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.accept_shared_template(p_message_id uuid) to authenticated;
grant execute on function public.accept_shared_template(p_message_id uuid) to service_role;

revoke all on function public.account_deletion_blockers() from public, anon, authenticated, service_role;
grant execute on function public.account_deletion_blockers() to authenticated;
grant execute on function public.account_deletion_blockers() to service_role;

revoke all on function public.add_activity_photo(p_log_id uuid, p_path text) from public, anon, authenticated, service_role;
grant execute on function public.add_activity_photo(p_log_id uuid, p_path text) to authenticated;
grant execute on function public.add_activity_photo(p_log_id uuid, p_path text) to service_role;

revoke all on function public.add_place(p_name text, p_kind text) from public, anon, authenticated, service_role;
grant execute on function public.add_place(p_name text, p_kind text) to authenticated;
grant execute on function public.add_place(p_name text, p_kind text) to service_role;

revoke all on function public.apply_identity_result(p_session_id text, p_status text, p_age_result text) from public, anon, authenticated, service_role;
grant execute on function public.apply_identity_result(p_session_id text, p_status text, p_age_result text) to service_role;

revoke all on function public.approve_match(p_match_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.approve_match(p_match_id uuid) to authenticated;
grant execute on function public.approve_match(p_match_id uuid) to service_role;

revoke all on function public.attach_plan_partner(p_plan_id uuid, p_partner_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.attach_plan_partner(p_plan_id uuid, p_partner_id uuid) to authenticated;
grant execute on function public.attach_plan_partner(p_plan_id uuid, p_partner_id uuid) to service_role;

revoke all on function public.attest_age(p_birthdate date) from public, anon, authenticated, service_role;
grant execute on function public.attest_age(p_birthdate date) to authenticated;
grant execute on function public.attest_age(p_birthdate date) to service_role;

revoke all on function public.can_create_club() from public, anon, authenticated, service_role;
grant execute on function public.can_create_club() to authenticated;
grant execute on function public.can_create_club() to service_role;

revoke all on function public.cancel_account_deletion() from public, anon, authenticated, service_role;
grant execute on function public.cancel_account_deletion() to authenticated;
grant execute on function public.cancel_account_deletion() to service_role;

revoke all on function public.cancel_club_event(p_event_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.cancel_club_event(p_event_id uuid) to authenticated;
grant execute on function public.cancel_club_event(p_event_id uuid) to service_role;

revoke all on function public.cancel_rsvp(p_event_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.cancel_rsvp(p_event_id uuid) to authenticated;
grant execute on function public.cancel_rsvp(p_event_id uuid) to service_role;

revoke all on function public.cancel_session(p_session_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.cancel_session(p_session_id uuid) to authenticated;
grant execute on function public.cancel_session(p_session_id uuid) to service_role;

revoke all on function public.checkin_card(p_thread uuid) from public, anon, authenticated, service_role;
grant execute on function public.checkin_card(p_thread uuid) to authenticated;
grant execute on function public.checkin_card(p_thread uuid) to service_role;

revoke all on function public.claim_guardian_invitation(p_token text) from public, anon, authenticated, service_role;
grant execute on function public.claim_guardian_invitation(p_token text) to authenticated;
grant execute on function public.claim_guardian_invitation(p_token text) to service_role;

revoke all on function public.clear_checkin_sharing(p_session uuid) from public, anon, authenticated, service_role;
grant execute on function public.clear_checkin_sharing(p_session uuid) to authenticated;
grant execute on function public.clear_checkin_sharing(p_session uuid) to service_role;

revoke all on function public.clear_live_map() from public, anon, authenticated, service_role;
grant execute on function public.clear_live_map() to authenticated;
grant execute on function public.clear_live_map() to service_role;

revoke all on function public.clear_live_map_on_minor_downgrade() from public, anon, authenticated, service_role;
grant execute on function public.clear_live_map_on_minor_downgrade() to service_role;

revoke all on function public.club_board(p_club uuid, p_basis text) from public, anon, authenticated, service_role;
grant execute on function public.club_board(p_club uuid, p_basis text) to authenticated;
grant execute on function public.club_board(p_club uuid, p_basis text) to service_role;

revoke all on function public.confirm_activity_log(p_log_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.confirm_activity_log(p_log_id uuid) to authenticated;
grant execute on function public.confirm_activity_log(p_log_id uuid) to service_role;

revoke all on function public.confirm_qr(p_code text, p_acknowledged boolean, p_via text) from public, anon, authenticated, service_role;
grant execute on function public.confirm_qr(p_code text, p_acknowledged boolean, p_via text) to authenticated;
grant execute on function public.confirm_qr(p_code text, p_acknowledged boolean, p_via text) to service_role;

revoke all on function public.connection_names(p_ids uuid[]) from public, anon, authenticated, service_role;
grant execute on function public.connection_names(p_ids uuid[]) to authenticated;
grant execute on function public.connection_names(p_ids uuid[]) to service_role;

revoke all on function public.create_club(p_name text, p_description text, p_organizer_label text) from public, anon, authenticated, service_role;
grant execute on function public.create_club(p_name text, p_description text, p_organizer_label text) to authenticated;
grant execute on function public.create_club(p_name text, p_description text, p_organizer_label text) to service_role;

revoke all on function public.create_plan(p_activity_type public.activity_type, p_other_label text, p_label text, p_recurrence public.plan_recurrence, p_day_of_week integer, p_start_time time without time zone, p_timezone text, p_end_condition public.plan_end_condition, p_end_after_weeks integer, p_linked_template_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.create_plan(p_activity_type public.activity_type, p_other_label text, p_label text, p_recurrence public.plan_recurrence, p_day_of_week integer, p_start_time time without time zone, p_timezone text, p_end_condition public.plan_end_condition, p_end_after_weeks integer, p_linked_template_id uuid) to authenticated;
grant execute on function public.create_plan(p_activity_type public.activity_type, p_other_label text, p_label text, p_recurrence public.plan_recurrence, p_day_of_week integer, p_start_time time without time zone, p_timezone text, p_end_condition public.plan_end_condition, p_end_after_weeks integer, p_linked_template_id uuid) to service_role;

revoke all on function public.create_template(p_name text, p_summary text, p_activity_type public.activity_type, p_sets jsonb) from public, anon, authenticated, service_role;
grant execute on function public.create_template(p_name text, p_summary text, p_activity_type public.activity_type, p_sets jsonb) to authenticated;
grant execute on function public.create_template(p_name text, p_summary text, p_activity_type public.activity_type, p_sets jsonb) to service_role;

revoke all on function public.decline_match(p_match_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.decline_match(p_match_id uuid) to authenticated;
grant execute on function public.decline_match(p_match_id uuid) to service_role;

revoke all on function public.decline_shared_template(p_message_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.decline_shared_template(p_message_id uuid) to authenticated;
grant execute on function public.decline_shared_template(p_message_id uuid) to service_role;

revoke all on function public.delete_activity_log(p_log_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.delete_activity_log(p_log_id uuid) to authenticated;
grant execute on function public.delete_activity_log(p_log_id uuid) to service_role;

revoke all on function public.delete_match(p_match_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.delete_match(p_match_id uuid) to authenticated;
grant execute on function public.delete_match(p_match_id uuid) to service_role;

revoke all on function public.delete_plan(p_plan_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.delete_plan(p_plan_id uuid) to authenticated;
grant execute on function public.delete_plan(p_plan_id uuid) to service_role;

revoke all on function public.delete_template(p_template_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.delete_template(p_template_id uuid) to authenticated;
grant execute on function public.delete_template(p_template_id uuid) to service_role;

revoke all on function public.discover_filter_pools() from public, anon, authenticated, service_role;
grant execute on function public.discover_filter_pools() to authenticated;
grant execute on function public.discover_filter_pools() to service_role;

revoke all on function public.discover_map_pins() from public, anon, authenticated, service_role;
grant execute on function public.discover_map_pins() to authenticated;
grant execute on function public.discover_map_pins() to service_role;

revoke all on function public.discover_people(p_filters jsonb, p_limit integer, p_offset integer) from public, anon, authenticated, service_role;
grant execute on function public.discover_people(p_filters jsonb, p_limit integer, p_offset integer) to authenticated;
grant execute on function public.discover_people(p_filters jsonb, p_limit integer, p_offset integer) to service_role;

revoke all on function public.dismiss_plan_partner(p_plan_id uuid, p_partner_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.dismiss_plan_partner(p_plan_id uuid, p_partner_id uuid) to authenticated;
grant execute on function public.dismiss_plan_partner(p_plan_id uuid, p_partner_id uuid) to service_role;

revoke all on function public.due_account_deletions() from public, anon, authenticated, service_role;
grant execute on function public.due_account_deletions() to service_role;

revoke all on function public.enforce_minor_live_map_exclusion() from public, anon, authenticated, service_role;
grant execute on function public.enforce_minor_live_map_exclusion() to service_role;

revoke all on function public.erase_account(p_user uuid) from public, anon, authenticated, service_role;
grant execute on function public.erase_account(p_user uuid) to service_role;

revoke all on function public.expire_unconsented_minors() from public, anon, authenticated, service_role;
grant execute on function public.expire_unconsented_minors() to service_role;

revoke all on function public.generate_personal_qr_code(p_display_name text) from public, anon, authenticated, service_role;
grant execute on function public.generate_personal_qr_code(p_display_name text) to authenticated;
grant execute on function public.generate_personal_qr_code(p_display_name text) to service_role;

revoke all on function public.get_session_proposal(p_proposal_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.get_session_proposal(p_proposal_id uuid) to authenticated;
grant execute on function public.get_session_proposal(p_proposal_id uuid) to service_role;

revoke all on function public.get_shared_template(p_message_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.get_shared_template(p_message_id uuid) to authenticated;
grant execute on function public.get_shared_template(p_message_id uuid) to service_role;

revoke all on function public.grant_guardian_consent(p_link_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.grant_guardian_consent(p_link_id uuid) to authenticated;
grant execute on function public.grant_guardian_consent(p_link_id uuid) to service_role;

revoke all on function public.guardian_decide_connection(p_approval_id uuid, p_approve boolean) from public, anon, authenticated, service_role;
grant execute on function public.guardian_decide_connection(p_approval_id uuid, p_approve boolean) to authenticated;
grant execute on function public.guardian_decide_connection(p_approval_id uuid, p_approve boolean) to service_role;

revoke all on function public.guardian_minor_overview() from public, anon, authenticated, service_role;
grant execute on function public.guardian_minor_overview() to authenticated;
grant execute on function public.guardian_minor_overview() to service_role;

revoke all on function public.handle_new_auth_user() from public, anon, authenticated, service_role;
grant execute on function public.handle_new_auth_user() to service_role;

revoke all on function public.identity_check_begin(p_user uuid) from public, anon, authenticated, service_role;
grant execute on function public.identity_check_begin(p_user uuid) to service_role;

revoke all on function public.identity_check_register(p_user uuid, p_session_id text) from public, anon, authenticated, service_role;
grant execute on function public.identity_check_register(p_user uuid, p_session_id text) to service_role;

revoke all on function public.ingest_wearable_workout(p_user_id uuid, p_provider_slug text, p_external_id text, p_activity_type public.activity_type, p_title text, p_started_at timestamp with time zone, p_duration_seconds integer, p_distance_m numeric, p_calories integer, p_avg_hr integer, p_max_hr integer, p_cadence integer) from public, anon, authenticated, service_role;
grant execute on function public.ingest_wearable_workout(p_user_id uuid, p_provider_slug text, p_external_id text, p_activity_type public.activity_type, p_title text, p_started_at timestamp with time zone, p_duration_seconds integer, p_distance_m numeric, p_calories integer, p_avg_hr integer, p_max_hr integer, p_cadence integer) to service_role;

revoke all on function public.leaderboard_settings_overview() from public, anon, authenticated, service_role;
grant execute on function public.leaderboard_settings_overview() to authenticated;
grant execute on function public.leaderboard_settings_overview() to service_role;

revoke all on function public.leave_club(p_club_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.leave_club(p_club_id uuid) to authenticated;
grant execute on function public.leave_club(p_club_id uuid) to service_role;

revoke all on function public.list_club_events(p_club_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.list_club_events(p_club_id uuid) to authenticated;
grant execute on function public.list_club_events(p_club_id uuid) to service_role;

revoke all on function public.list_clubs() from public, anon, authenticated, service_role;
grant execute on function public.list_clubs() to authenticated;
grant execute on function public.list_clubs() to service_role;

revoke all on function public.list_connection_approvals() from public, anon, authenticated, service_role;
grant execute on function public.list_connection_approvals() to authenticated;
grant execute on function public.list_connection_approvals() to service_role;

revoke all on function public.list_guardian_connections() from public, anon, authenticated, service_role;
grant execute on function public.list_guardian_connections() to authenticated;
grant execute on function public.list_guardian_connections() to service_role;

revoke all on function public.list_my_checkin_state() from public, anon, authenticated, service_role;
grant execute on function public.list_my_checkin_state() to authenticated;
grant execute on function public.list_my_checkin_state() to service_role;

revoke all on function public.list_my_plans() from public, anon, authenticated, service_role;
grant execute on function public.list_my_plans() to authenticated;
grant execute on function public.list_my_plans() to service_role;

revoke all on function public.list_my_proposals() from public, anon, authenticated, service_role;
grant execute on function public.list_my_proposals() to authenticated;
grant execute on function public.list_my_proposals() to service_role;

revoke all on function public.list_my_sessions() from public, anon, authenticated, service_role;
grant execute on function public.list_my_sessions() to authenticated;
grant execute on function public.list_my_sessions() to service_role;

revoke all on function public.list_my_sessions_to_complete() from public, anon, authenticated, service_role;
grant execute on function public.list_my_sessions_to_complete() to authenticated;
grant execute on function public.list_my_sessions_to_complete() to service_role;

revoke all on function public.list_plan_partners(p_plan_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.list_plan_partners(p_plan_id uuid) to authenticated;
grant execute on function public.list_plan_partners(p_plan_id uuid) to service_role;

revoke all on function public.log_activity(p_activity_type public.activity_type, p_other_label text, p_title text, p_started_at timestamp with time zone, p_duration_seconds integer, p_distance numeric, p_distance_unit text, p_notes text, p_source public.activity_source, p_plan_id uuid, p_template_id uuid, p_sets jsonb) from public, anon, authenticated, service_role;
grant execute on function public.log_activity(p_activity_type public.activity_type, p_other_label text, p_title text, p_started_at timestamp with time zone, p_duration_seconds integer, p_distance numeric, p_distance_unit text, p_notes text, p_source public.activity_source, p_plan_id uuid, p_template_id uuid, p_sets jsonb) to authenticated;
grant execute on function public.log_activity(p_activity_type public.activity_type, p_other_label text, p_title text, p_started_at timestamp with time zone, p_duration_seconds integer, p_distance numeric, p_distance_unit text, p_notes text, p_source public.activity_source, p_plan_id uuid, p_template_id uuid, p_sets jsonb) to service_role;

revoke all on function public.mark_plan_complete(p_plan_id uuid, p_occurrence_on date) from public, anon, authenticated, service_role;
grant execute on function public.mark_plan_complete(p_plan_id uuid, p_occurrence_on date) to authenticated;
grant execute on function public.mark_plan_complete(p_plan_id uuid, p_occurrence_on date) to service_role;

revoke all on function public.mark_session_complete(p_session_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.mark_session_complete(p_session_id uuid) to authenticated;
grant execute on function public.mark_session_complete(p_session_id uuid) to service_role;

revoke all on function public.my_progress(p_tz text) from public, anon, authenticated, service_role;
grant execute on function public.my_progress(p_tz text) to authenticated;
grant execute on function public.my_progress(p_tz text) to service_role;

revoke all on function public.my_qr_code() from public, anon, authenticated, service_role;
grant execute on function public.my_qr_code() to authenticated;
grant execute on function public.my_qr_code() to service_role;

revoke all on function public.partner_count_for(p_user uuid) from public, anon, authenticated, service_role;
grant execute on function public.partner_count_for(p_user uuid) to authenticated;
grant execute on function public.partner_count_for(p_user uuid) to service_role;

revoke all on function public.person_standing(p_user uuid, p_basis text) from public, anon, authenticated, service_role;
grant execute on function public.person_standing(p_user uuid, p_basis text) to authenticated;
grant execute on function public.person_standing(p_user uuid, p_basis text) to service_role;

revoke all on function public.plan_history(p_plan_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.plan_history(p_plan_id uuid) to authenticated;
grant execute on function public.plan_history(p_plan_id uuid) to service_role;

revoke all on function public.post_club_event(p_club_id uuid, p_title text, p_starts_at timestamp with time zone, p_timezone text, p_location_label text, p_capacity integer) from public, anon, authenticated, service_role;
grant execute on function public.post_club_event(p_club_id uuid, p_title text, p_starts_at timestamp with time zone, p_timezone text, p_location_label text, p_capacity integer) to authenticated;
grant execute on function public.post_club_event(p_club_id uuid, p_title text, p_starts_at timestamp with time zone, p_timezone text, p_location_label text, p_capacity integer) to service_role;

revoke all on function public.propose_session(p_recipient_id uuid, p_activity_type public.activity_type, p_proposed_start timestamp with time zone, p_timezone text, p_plan_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.propose_session(p_recipient_id uuid, p_activity_type public.activity_type, p_proposed_start timestamp with time zone, p_timezone text, p_plan_id uuid) to authenticated;
grant execute on function public.propose_session(p_recipient_id uuid, p_activity_type public.activity_type, p_proposed_start timestamp with time zone, p_timezone text, p_plan_id uuid) to service_role;

revoke all on function public.record_checkin(p_session uuid, p_lat double precision, p_lng double precision) from public, anon, authenticated, service_role;
grant execute on function public.record_checkin(p_session uuid, p_lat double precision, p_lng double precision) to authenticated;
grant execute on function public.record_checkin(p_session uuid, p_lat double precision, p_lng double precision) to service_role;

revoke all on function public.record_guardian_details(p_first_name text, p_last_name text, p_email text) from public, anon, authenticated, service_role;
grant execute on function public.record_guardian_details(p_first_name text, p_last_name text, p_email text) to authenticated;
grant execute on function public.record_guardian_details(p_first_name text, p_last_name text, p_email text) to service_role;

revoke all on function public.register_custom_tag(p_label text) from public, anon, authenticated, service_role;
grant execute on function public.register_custom_tag(p_label text) to authenticated;
grant execute on function public.register_custom_tag(p_label text) to service_role;

revoke all on function public.register_push_token(p_token text, p_platform text, p_device_id text) from public, anon, authenticated, service_role;
grant execute on function public.register_push_token(p_token text, p_platform text, p_device_id text) to authenticated;
grant execute on function public.register_push_token(p_token text, p_platform text, p_device_id text) to service_role;

revoke all on function public.release_held_connection(p_row_id uuid, p_release boolean, p_reviewer uuid) from public, anon, authenticated, service_role;
grant execute on function public.release_held_connection(p_row_id uuid, p_release boolean, p_reviewer uuid) to service_role;
grant execute on function public.release_held_connection(p_row_id uuid, p_release boolean, p_reviewer uuid) to trust_and_safety;

revoke all on function public.remove_activity_photo(p_photo_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.remove_activity_photo(p_photo_id uuid) to authenticated;
grant execute on function public.remove_activity_photo(p_photo_id uuid) to service_role;

revoke all on function public.request_account_deletion(p_confirm text) from public, anon, authenticated, service_role;
grant execute on function public.request_account_deletion(p_confirm text) to authenticated;
grant execute on function public.request_account_deletion(p_confirm text) to service_role;

revoke all on function public.request_match(p_target uuid) from public, anon, authenticated, service_role;
grant execute on function public.request_match(p_target uuid) to authenticated;
grant execute on function public.request_match(p_target uuid) to service_role;

revoke all on function public.reschedule_plan_occurrence(p_plan_id uuid, p_occurrence_on date, p_new_starts_at timestamp with time zone) from public, anon, authenticated, service_role;
grant execute on function public.reschedule_plan_occurrence(p_plan_id uuid, p_occurrence_on date, p_new_starts_at timestamp with time zone) to authenticated;
grant execute on function public.reschedule_plan_occurrence(p_plan_id uuid, p_occurrence_on date, p_new_starts_at timestamp with time zone) to service_role;

revoke all on function public.resolve_qr(p_code text) from public, anon, authenticated, service_role;
grant execute on function public.resolve_qr(p_code text) to authenticated;
grant execute on function public.resolve_qr(p_code text) to service_role;

revoke all on function public.respond_plan_invite(p_plan_id uuid, p_accept boolean) from public, anon, authenticated, service_role;
grant execute on function public.respond_plan_invite(p_plan_id uuid, p_accept boolean) to authenticated;
grant execute on function public.respond_plan_invite(p_plan_id uuid, p_accept boolean) to service_role;

revoke all on function public.respond_session_proposal(p_proposal_id uuid, p_accept boolean) from public, anon, authenticated, service_role;
grant execute on function public.respond_session_proposal(p_proposal_id uuid, p_accept boolean) to authenticated;
grant execute on function public.respond_session_proposal(p_proposal_id uuid, p_accept boolean) to service_role;

revoke all on function public.review_access() from public, anon, authenticated, service_role;
grant execute on function public.review_access() to authenticated;
grant execute on function public.review_access() to service_role;

revoke all on function public.review_inbox() from public, anon, authenticated, service_role;
grant execute on function public.review_inbox() to authenticated;
grant execute on function public.review_inbox() to service_role;

revoke all on function public.review_release_held(p_row_id uuid, p_release boolean) from public, anon, authenticated, service_role;
grant execute on function public.review_release_held(p_row_id uuid, p_release boolean) to authenticated;
grant execute on function public.review_release_held(p_row_id uuid, p_release boolean) to service_role;

revoke all on function public.review_resolve_report(p_report_id uuid, p_action text, p_note text) from public, anon, authenticated, service_role;
grant execute on function public.review_resolve_report(p_report_id uuid, p_action text, p_note text) to authenticated;
grant execute on function public.review_resolve_report(p_report_id uuid, p_action text, p_note text) to service_role;

revoke all on function public.revoke_guardian_consent(p_link_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.revoke_guardian_consent(p_link_id uuid) to authenticated;
grant execute on function public.revoke_guardian_consent(p_link_id uuid) to service_role;

revoke all on function public.rsvp_to_event(p_event_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.rsvp_to_event(p_event_id uuid) to authenticated;
grant execute on function public.rsvp_to_event(p_event_id uuid) to service_role;

revoke all on function public.sessions_together(p_other uuid) from public, anon, authenticated, service_role;
grant execute on function public.sessions_together(p_other uuid) to authenticated;
grant execute on function public.sessions_together(p_other uuid) to service_role;

revoke all on function public.set_checkin_sharing(p_session uuid, p_minutes integer) from public, anon, authenticated, service_role;
grant execute on function public.set_checkin_sharing(p_session uuid, p_minutes integer) to authenticated;
grant execute on function public.set_checkin_sharing(p_session uuid, p_minutes integer) to service_role;

revoke all on function public.set_club_leaderboard_optout(p_club uuid, p_opted_out boolean) from public, anon, authenticated, service_role;
grant execute on function public.set_club_leaderboard_optout(p_club uuid, p_opted_out boolean) to authenticated;
grant execute on function public.set_club_leaderboard_optout(p_club uuid, p_opted_out boolean) to service_role;

revoke all on function public.set_club_show_leaderboard(p_club uuid, p_show boolean) from public, anon, authenticated, service_role;
grant execute on function public.set_club_show_leaderboard(p_club uuid, p_show boolean) to authenticated;
grant execute on function public.set_club_show_leaderboard(p_club uuid, p_show boolean) to service_role;

revoke all on function public.set_guardian_controls(p_link_id uuid, p_adult_connections_allowed boolean, p_per_connection_approval_required boolean) from public, anon, authenticated, service_role;
grant execute on function public.set_guardian_controls(p_link_id uuid, p_adult_connections_allowed boolean, p_per_connection_approval_required boolean) to authenticated;
grant execute on function public.set_guardian_controls(p_link_id uuid, p_adult_connections_allowed boolean, p_per_connection_approval_required boolean) to service_role;

revoke all on function public.set_leaderboard_visibility(p_value public.leaderboard_visibility) from public, anon, authenticated, service_role;
grant execute on function public.set_leaderboard_visibility(p_value public.leaderboard_visibility) to authenticated;
grant execute on function public.set_leaderboard_visibility(p_value public.leaderboard_visibility) to service_role;

revoke all on function public.set_live_map(p_minutes integer) from public, anon, authenticated, service_role;
grant execute on function public.set_live_map(p_minutes integer) to authenticated;
grant execute on function public.set_live_map(p_minutes integer) to service_role;

revoke all on function public.set_neighborhood(p_slug text) from public, anon, authenticated, service_role;
grant execute on function public.set_neighborhood(p_slug text) to authenticated;
grant execute on function public.set_neighborhood(p_slug text) to service_role;

revoke all on function public.set_plan_place(p_plan_id uuid, p_place text) from public, anon, authenticated, service_role;
grant execute on function public.set_plan_place(p_plan_id uuid, p_place text) to authenticated;
grant execute on function public.set_plan_place(p_plan_id uuid, p_place text) to service_role;

revoke all on function public.set_plan_reminder_offset(p_minutes integer) from public, anon, authenticated, service_role;
grant execute on function public.set_plan_reminder_offset(p_minutes integer) to authenticated;
grant execute on function public.set_plan_reminder_offset(p_minutes integer) to service_role;

revoke all on function public.set_plan_template(p_plan_id uuid, p_template_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.set_plan_template(p_plan_id uuid, p_template_id uuid) to authenticated;
grant execute on function public.set_plan_template(p_plan_id uuid, p_template_id uuid) to service_role;

revoke all on function public.set_proposal_place(p_proposal_id uuid, p_place text) from public, anon, authenticated, service_role;
grant execute on function public.set_proposal_place(p_proposal_id uuid, p_place text) to authenticated;
grant execute on function public.set_proposal_place(p_proposal_id uuid, p_place text) to service_role;

revoke all on function public.set_push_enabled(p_enabled boolean) from public, anon, authenticated, service_role;
grant execute on function public.set_push_enabled(p_enabled boolean) to authenticated;
grant execute on function public.set_push_enabled(p_enabled boolean) to service_role;

revoke all on function public.shared_availability(p_partner_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.shared_availability(p_partner_id uuid) to authenticated;
grant execute on function public.shared_availability(p_partner_id uuid) to service_role;

revoke all on function public.submit_report(p_reported uuid, p_reason public.report_reason, p_text text) from public, anon, authenticated, service_role;
grant execute on function public.submit_report(p_reported uuid, p_reason public.report_reason, p_text text) to authenticated;
grant execute on function public.submit_report(p_reported uuid, p_reason public.report_reason, p_text text) to service_role;

revoke all on function public.suggest_plan_for_log(p_log_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.suggest_plan_for_log(p_log_id uuid) to authenticated;
grant execute on function public.suggest_plan_for_log(p_log_id uuid) to service_role;

revoke all on function public.ts_resolve_report(p_report_id uuid, p_action text, p_note text, p_reviewer uuid) from public, anon, authenticated, service_role;
grant execute on function public.ts_resolve_report(p_report_id uuid, p_action text, p_note text, p_reviewer uuid) to service_role;
grant execute on function public.ts_resolve_report(p_report_id uuid, p_action text, p_note text, p_reviewer uuid) to trust_and_safety;

revoke all on function public.unregister_push_token(p_token text) from public, anon, authenticated, service_role;
grant execute on function public.unregister_push_token(p_token text) to authenticated;
grant execute on function public.unregister_push_token(p_token text) to service_role;

revoke all on function public.update_activity_log(p_log_id uuid, p_other_label text, p_title text, p_started_at timestamp with time zone, p_duration_seconds integer, p_distance numeric, p_distance_unit text, p_notes text, p_sets jsonb) from public, anon, authenticated, service_role;
grant execute on function public.update_activity_log(p_log_id uuid, p_other_label text, p_title text, p_started_at timestamp with time zone, p_duration_seconds integer, p_distance numeric, p_distance_unit text, p_notes text, p_sets jsonb) to authenticated;
grant execute on function public.update_activity_log(p_log_id uuid, p_other_label text, p_title text, p_started_at timestamp with time zone, p_duration_seconds integer, p_distance numeric, p_distance_unit text, p_notes text, p_sets jsonb) to service_role;

revoke all on function public.update_activity_notes(p_log_id uuid, p_notes text) from public, anon, authenticated, service_role;
grant execute on function public.update_activity_notes(p_log_id uuid, p_notes text) to authenticated;
grant execute on function public.update_activity_notes(p_log_id uuid, p_notes text) to service_role;

revoke all on function public.update_plan_schedule(p_plan_id uuid, p_scope text, p_occurrence_on date, p_day_of_week integer, p_start_time time without time zone, p_recurrence public.plan_recurrence, p_end_condition public.plan_end_condition, p_end_after_weeks integer) from public, anon, authenticated, service_role;
grant execute on function public.update_plan_schedule(p_plan_id uuid, p_scope text, p_occurrence_on date, p_day_of_week integer, p_start_time time without time zone, p_recurrence public.plan_recurrence, p_end_condition public.plan_end_condition, p_end_after_weeks integer) to authenticated;
grant execute on function public.update_plan_schedule(p_plan_id uuid, p_scope text, p_occurrence_on date, p_day_of_week integer, p_start_time time without time zone, p_recurrence public.plan_recurrence, p_end_condition public.plan_end_condition, p_end_after_weeks integer) to service_role;

revoke all on function public.update_template(p_template_id uuid, p_name text, p_summary text, p_activity_type public.activity_type, p_sets jsonb) from public, anon, authenticated, service_role;
grant execute on function public.update_template(p_template_id uuid, p_name text, p_summary text, p_activity_type public.activity_type, p_sets jsonb) to authenticated;
grant execute on function public.update_template(p_template_id uuid, p_name text, p_summary text, p_activity_type public.activity_type, p_sets jsonb) to service_role;

-- ======================================================================
-- Comments
-- ======================================================================
comment on table public.guardians is 'A guardian is a real Groundwork account (§15.2), not an email address on a minor''s record. Readable only by that guardian and the compliance role (§5.10).';

comment on column public.guardian_invitations.guardian_phone_hint is 'Masked guardian phone number for screen 0e. The ONLY phone-derived column a client role may read; guardian_phone itself is never granted to authenticated.';

comment on column public.guardian_invitations.token_hash is 'SHA-256 of the single-use token. The raw token exists only in the email and SMS sent to the guardian — never in the database, so a read cannot be replayed into consent.';

comment on column public.profiles.home_point is 'COARSE location only — neighborhood centroid, never an exact address (§4.1). Precise geolocation is VCDPA sensitive data (§5.1).';

comment on column public.profiles.live_map_visible_until is 'Server-side expiry for "Show on live map" (§2.7). A pin must disappear from every query the moment this passes (§5.1) — enforced in the query layer, not by the client hiding it. Must stay NULL for any minor account (§5.8, test S20).';

comment on column public.users.age_status is 'Four-state age model (§2.8). Server-writable only — see the column grants below and public.attest_age(). No client path may set this (§5.5, test S13).';

comment on column public.users.birthdate_attested_at is 'WHEN the birthdate was attested, never the date itself. Storing a DOB would breach §5.3 and put the account in scope for a VCDPA sensitive-data argument (§2.8).';

comment on column public.users.can_organize_clubs is 'Founder-approved club organizer (pilot). Written only by the founder in the database — never granted to a client role.';

comment on function public.attest_age(p_birthdate date) is 'Signup age gate (§2.8). Takes a date of birth, derives the status, and DISCARDS the date — it is never persisted (§5.3, test S11). Reaches self_attested_adult at most; only the Stripe Identity webhook may set adult (§2.9). Refuses under-13 (COPPA).';

comment on function public.expire_unconsented_minors() is '§15.2: deletes a minor account still without consent after 30 days. Deleting the auth.users row cascades to public.users and everything below it. Notice at each step, and the minor''s ability to export their logged activity beforehand, are application responsibilities — this function is the deletion only.';

-- ======================================================================
-- Storage bucket
-- ======================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values ('activity-photos', 'activity-photos', false, 5242880, '{image/jpeg,image/png,image/heic,image/webp}') on conflict (id) do nothing;
