# Open items: everything not yet decided or done (as of 2026-10-20)

## Decisions only Danny can make
| Item | Needed by | Notes |
|---|---|---|
| Pick the new app name | before store listing, domains, branding | Ranking: Regulars, Stayer, Mooring, Standfast, Staunch (`09-naming.md`) |
| Whether to add a fuller parental-notification flow | before minor features ship | Suggested as an eighth §14 decision |
| Outsourced moderation vendor and trigger point | when report volume grows | Deliberately deferred |
| Iconography and motion defaults | before UI phases | Recommended in the Harbor doc, not decided |
| Fix the pre-existing Supabase advisor warnings | before real users | 95 SECURITY DEFINER functions callable by signed-in users, 8 RLS tables without policies, leaked-password protection off |

## Two repos, one production database (most urgent)
- `C:\dev\groundwork` (local, no GitHub remote) holds the app and numbered migrations `0001`–`0049`, applied by its own runner.
- `junejoon-d/groundwork-app` (GitHub) holds a baseline generated from production plus PR #6, and its Supabase GitHub integration redeploys Edge Functions on every merge to `main`.
- Production's migration history lists only the GitHub track (checked 2026-10-20: `remote_schema`, `research_reference_tables`, `guardian_email_sends_and_photo_paths`). Local `0049_reference_tables_grants` (closes the research tables to clients) isn't recorded there.
- A merge on either side can overwrite the other's functions or schema. Pick one repo as the source of truth before more backend changes.

## Danny's to-dos
- Decide the source-of-truth repo (above).
- The legal drafts weren't found; the app's privacy, terms and SMS pages need a lawyer's read anyway.
- Reconnect the Stripe connector on claude.ai (its sign-in expired).
- Everything in `C:\dev\groundwork\docs\launch-checklist.md` marked "you" (Spike credentials and a Garmin tester, Stripe live mode after the LLC, Apple, a domain for SendGrid, Supabase Pro, phone sign-in decision).
- Attorney: legal pages, minor P2P matching, consent mechanism, guardian visibility, COPPA posture, state app-store laws, and a full trademark search on the chosen name.
- Start the insurance broker conversation early.

## Build state
What's built and what's left is tracked in `C:\dev\groundwork\docs\launch-checklist.md` and `decisions.md`, not here. Items from the research that may not be in it yet: store age signals (Apple Declared Age Range, Google Play Age Signals), a `RESCIND_CONSENT` webhook, a significant-change checklist for the stores, and a TAKE IT DOWN takedown flow.

## Research gaps
- Utah's App Store Act date conflicts (6 May 2027 vs 2026); read HB 498.
- No Louisiana enforcement news after 1 Jul 2026; no FTC COPPA cases found after April 2026 (ftc.gov blocked the scraper); California AB 1043 final text not retrieved; no 2026 MAAPP update confirmed.
- Race calendar is missing Pacers events, Cherry Blossom, Army Ten-Miler, 5Ks and cycling.
- Club meeting times are from third-party lists; club sizes unverified.
- Stream Chat docs crawl is partial.
- Sweatmates looks like couples accountability, not a matcher; worth a direct look.

## Superseded, don't revive
- Ejecting from Expo (`expo prebuild` to bare). Testing in Expo Go.
- Cutting the wearable aggregator from the pilot.
- The wireframe's `#FF5A2E` accent and Patrick Hand font.
- Minors barred from P2P QR (round 16); reversed, minors can match by QR under §15.
- The Korean/Spanish/Japanese name shortlist from the original project (Duri, Sali, Jjak and others).
- Pointing Claude's Supabase MCP at a separate dev project; there is only production, so it's read-only there.
