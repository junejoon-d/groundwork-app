-- Recorded in production as version 20261018014442 (research_reference_tables). Copied verbatim from
-- supabase_migrations.schema_migrations; do not edit, production already ran it.

create table public.venues (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  category          text not null check (category in
                     ('run_store','climbing_gym','crossfit','track','trailhead','pool','pickleball',
                      'tennis','bike_shop','yoga','pilates','gym','park')),
  address           text,
  city              text,
  neighborhood_slug text references public.neighborhoods(slug) on update cascade on delete set null,
  location          extensions.geography(point, 4326) not null,
  website           text,
  rating            numeric(2,1),
  review_count      integer,
  is_partner        boolean not null default false,
  source            text not null,
  source_place_id   text,
  source_url        text,
  source_fetched_at timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (source, source_place_id)
);
create index venues_location_gix on public.venues using gist (location);
create index venues_neighborhood_idx on public.venues (neighborhood_slug, category);
alter table public.venues enable row level security;
create policy "venues readable by signed-in users" on public.venues
  for select to authenticated using (true);
comment on table public.venues is 'Suggested public meet-up spots. Seeded from a Google Maps scrape (source=apify_seed) for reference only; refresh from a licensed places API before production.';

create table public.local_events (
  id                   uuid primary key default gen_random_uuid(),
  name                 text not null,
  sport                text not null,
  starts_on            date not null,
  city                 text,
  state                text,
  miles_from_clarendon integer,
  distances            text,
  price_range          text,
  registration_open    boolean,
  platform             text,
  source_url           text not null,
  source_fetched_at    timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (name, starts_on)
);
create index local_events_starts_on_idx on public.local_events (starts_on);
alter table public.local_events enable row level security;
create policy "local events readable by signed-in users" on public.local_events
  for select to authenticated using (true);
comment on table public.local_events is 'Upcoming races near the pilot zone (RunSignup/Eventbrite scrape). Refreshed monthly.';

create table private.partner_orgs (
  id                uuid primary key default gen_random_uuid(),
  rank              integer,
  business          text not null unique,
  type              text,
  scope             text,
  location          text,
  community_program boolean,
  program_link      text,
  website           text,
  reason            text,
  status            text not null default 'not_contacted'
                    check (status in ('not_contacted','contacted','in_talks','partner','declined')),
  source_url        text,
  source_fetched_at timestamptz,
  created_at        timestamptz not null default now()
);
alter table private.partner_orgs enable row level security;

create table private.outreach_orgs (
  id                uuid primary key default gen_random_uuid(),
  rank              integer,
  organization      text not null unique,
  type              text,
  sport             text,
  area              text,
  meets             text,
  website_or_handle text,
  fit_score         integer,
  first_contact     boolean not null default false,
  garmin_heavy      boolean not null default false,
  youth_org_only    boolean not null default false,
  why               text,
  status            text not null default 'not_contacted'
                    check (status in ('not_contacted','contacted','in_talks','onboarded','declined')),
  source_url        text,
  source_fetched_at timestamptz,
  created_at        timestamptz not null default now()
);
alter table private.outreach_orgs enable row level security;
