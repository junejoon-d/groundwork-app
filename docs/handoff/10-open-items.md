# Open items: everything not yet decided or done (as of 2026-10-20)

## Decisions only Danny can make
| Item | Needed by | Notes |
|---|---|---|
| Pick the new app name | before store listing, domains, branding | Ranking: Regulars, Stayer, Mooring, Standfast, Staunch (`09-naming.md`) |
| `danger` and `warn` color tokens | before phase 3 | Harbor has none; don't reuse coral |
| Harbor light-mode TODOs, type scale, spacing, radius | before phase 3 | From the Harbor .docx |
| Whether to add a fuller parental-notification flow | before minor features ship | Suggested as an eighth §14 decision |
| Outsourced moderation vendor and trigger point | when report volume grows | Deliberately deferred |
| Iconography and motion defaults | before UI phases | Recommended in the Harbor doc, not decided |
| Fix the pre-existing Supabase advisor warnings | before real users | 95 SECURITY DEFINER functions callable by signed-in users, 8 RLS tables without policies, leaked-password protection off |

## Danny's to-dos
- Add the Build Brief .docx, the Harbor .docx and the legal drafts to the repo (for example under `docs/`), so build sessions can read them. These handoff notes don't replace the brief.
- Paste the brief §11 CLAUDE.md block above the rules in `CLAUDE.md`.
- Reconnect the Stripe connector on claude.ai (its sign-in expired).
- Spike sales call: ask first whether there's a sandbox, then pricing and lead time.
- Recruit one Garmin-wearing beta tester (DC Triathlon Club) at the start of phase 9.
- Start the insurance broker conversation early (weeks of underwriting).
- Attorney: legal drafts, minor P2P matching, consent mechanism, guardian visibility, COPPA posture, state app-store laws, and a full trademark search on the chosen name.
- Form the Virginia LLC.

## Build work that is specified but not built yet
- Store age signals (Apple Declared Age Range, Google Play Age Signals) at signup and every launch. Needs a native module or config plugin; no Expo wrapper found.
- `RESCIND_CONSENT` webhook and Play approval-status checks; a significant-change checklist for releases.
- TAKE IT DOWN report-and-takedown flow (48 hours).
- The §15.9 single match gate and test S32 (direct `matches` insert refused).
- Replace seed `venues` with a licensed Places API before launch.
- Spike webhook: idempotency, async processing, periodic reconciliation (events are dropped after ~4 days of failed retries).
- The "request sent, waiting" screen (no reference app has one).

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
