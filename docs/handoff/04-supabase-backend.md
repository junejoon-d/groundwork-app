# Supabase backend

## Read first: two repos touch this database
The app's own repo, `C:\dev\groundwork` (local, no GitHub remote), has migrations `0001`–`0049` applied by its own runner and its own copies of the Edge Functions. This GitHub repo has a baseline generated from production plus PR #6. Production's migration history (checked 2026-10-20) lists only this repo's three versions; local `0049_reference_tables_grants` isn't recorded. A merge here redeploys functions over whatever the local repo deployed, and the reverse. Settle which repo is the source of truth before more backend changes (`10-open-items.md`).

## The project
- **groundwork-pilot** (ref `klpszhgfvibojttmtbik`) is the only Supabase project, so **it is production**.
- **GitHub integration is on.** Merging to `main` of `junejoon-d/groundwork-app` applies new migrations and redeploys the functions listed in `supabase/config.toml`.
- **Branching is on** (since 2026-10-20): each PR that changes `supabase/` gets a preview branch built from the repo's migrations. There's a limit on preview branches running at once. A PR opened while branching was off, or while over that limit, is skipped until Danny creates its branch by hand (dashboard > Branches > Create branch, same name as the git branch).
- Claude's Supabase MCP (`.mcp.json`) is **read-only**. Never `apply_migration`, `execute_sql` writes, dashboard edits or `supabase db push`. Rules in `.claude/rules/supabase.md`.

## What's in the repo
- `supabase/migrations/20261018014441_remote_schema.sql`: the baseline of production as of 2026-10-19, generated from the live catalog (no Docker). It never runs on production (its version was pre-recorded). Excludes on purpose: pg_cron jobs, Vault secret values, default privileges. Creates the nologin role `trust_and_safety`.
- `20261018014442_research_reference_tables.sql`: `public.venues` (323 rows, `apify_seed`), `public.local_events` (97), `private.partner_orgs` (23), `private.outreach_orgs` (37, CRM status columns). Approved by Danny 2026-10-18. No user tables touched.
- `20261020015000_guardian_email_sends_and_photo_paths.sql` (PR #6).
- `supabase/functions/`: `account-erase`, `guardian-sms-optin`, `identity-start`, `invite-guardian`, `push-send`, `spike-connect`, `spike-webhook`, `stream-chat`, `stripe-webhook`, plus `_shared/` (push, spike, spike-map, stripe). The five webhook functions (`stripe-webhook`, `spike-webhook`, `push-send`, `account-erase`, `guardian-sms-optin`) keep `verify_jwt = false`.
- Tables (public unless noted): users, profiles, profile_sports, availability, neighborhoods, clubs, club_memberships, club_events, club_event_rsvps, club_leaderboard_opt_outs, leaderboard_settings, matches, minor_adult_matches, minor_qr_codes, guardians, guardian_links, guardian_invitations, guardian_connection_approvals, verification_records, chat_threads, thread_participants, thread_settings, messages, plans, plan_partners, sessions, session_participants, session_proposals, checkin_locations, checkin_nudges, activity_logs, activity_sets, activity_photos, workout_templates, template_sets, template_share_responses, custom_tags, tag_match_settings, discover_filter_state, filter_presets, notification_settings, push_tokens, push_outbox, push_tickets, reports, wearable_connections, wearable_events, `private.reviewers`, plus the four research tables. Note `checkin_locations` holds users' GPS check-ins, not venues.
- pg_cron jobs on production: push-minute (every minute), push-tidy, checkin-purge, account-erasure (also purges old reports), wearable-events-tidy.

## PR history
| PR | What | State |
|---|---|---|
| #1 | Claude Code setup kit (`.claude/`, hooks, rules, tokens, skills) | merged 2026-10-18 |
| #2–#4 | Hardening the `.env` guard hook (dotfile globs, braces, extglobs) | merged |
| #5 | Baseline: full live schema + 9 Edge Functions. Preview matched production exactly; production verified unchanged after deploy (52 tables, 180 functions, 788 rows, 5 cron jobs) | merged 2026-10-20 |
| #6 | Security fixes: `public.guardian_email_sends` (service-role-only send log; `invite-guardian` allows 1 email per 10 minutes and 5 a day per minor, never for an expired invite) and `public.account_photo_paths(uuid)` (service-role-only, returns text[] so the API row cap can't truncate; `account-erase` uses it). Erasure waits for the next run if it can't confirm the Stripe ID-check deletion or photo cleanup | merged and verified on production 2026-10-20 |
| #7 | Mobbin reference links per design flow (docs only) | merged 2026-10-20 |

## Advisor warnings that predate this work (production)
- 95 SECURITY DEFINER functions callable by signed-in users.
- 8 tables with RLS on but no policy.
- Leaked-password protection is off in Auth (a one-click setting).
These are known and not yet fixed.

## Working rules (also in `.claude/rules/supabase.md`)
- Every schema change is a new migration file via `supabase migration new <name>`, reviewed on its preview branch. Never edit a migration already on `main`.
- New tables enable RLS and get policies in the same migration.
- Minor rules are enforced in RLS or Edge Functions, never only in app code.
- After a preview build, check advisors on the branch; after merge, run production `get_advisors` (security and performance).
- Service-role key only inside `supabase/functions/` via `Deno.env.get`.
- Regenerate types after schema changes.
- The guard hook is good enough: acknowledge further glob-trick findings rather than opening PRs, unless Danny asks.

## Research data notes
- `venues` rows with `source = 'apify_seed'` are reference data scraped from Google Maps. Replace them from a licensed Places API before launch, keeping `source_place_id` aligned. Ratings and review counts were left out on purpose.
- A monthly scheduled task (1st of the month) re-runs the events and compliance research and upserts `local_events`.

## Open
- Fix the pre-existing advisor warnings (definer functions, policy-less tables, leaked-password protection).
- Swap seed venues for a licensed Places API before launch.
