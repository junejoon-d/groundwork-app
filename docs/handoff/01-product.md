# Product: what Groundwork is and what v1 includes

Groundwork matches people for athletic activities (running first, also gym, cycling, climbing, triathlon and more). It started as "PRPair". The pilot is the Rosslyn–Ballston corridor in Arlington, VA, with DC, Alexandria and Falls Church around it. Danny is the solo founder and builds it with Claude Code (budget "Path A", see `11-budget-timeline-legal.md`).

## v1 scope (founder-confirmed)
- Include as much of the wireframe as possible: matching, scheduling and plans, live GPS recording plus manual logging, auto-reconcile with HealthKit and Garmin, ID and photo verification, location check-ins, user reporting, chat.
- **"Matched" means one request plus one approval.** Never auto-match on request.
- **Mobile first.** The only web surface is a lightweight Strava-like profile and activity viewer.
- **An account is required for the whole app.** No signed-out mode anywhere. Email and phone sign-in.
- Push notifications at launch.
- HealthKit and Garmin at launch, not deferred.
- **Free at launch** to build matching density. Later money comes from brand partnerships, not subscriptions or ads. Research backs this: paying to connect is the top complaint about Peanut and Meetup (`08-market-research.md`).

## The seven decisions Danny settled (Sept 2026, brief §14)
1. **Age model:** four states, `unverified` → `minor` / `self_attested_adult` → `adult`. Adult comes from the Stripe Identity webhook. DOB at signup. A minor downgrade is sticky. Store only the derived over-18 outcome. **Minors can do person-to-person QR matching** (a teen connecting with teammates or a coach), under the §15 safeguards in `02-minor-safety-and-compliance.md`.
2. **Harbor design system** replaces brief §10 wholesale (`06-design.md`).
3. **Discover map view is in v1.** It is a named banned-user exclusion surface.
4. **Leaderboards at launch** for clubs and personal profiles. Payments and competitions stay out.
5. **Chat mute:** per thread, with separate Messages and Check-in-nudge toggles. Muting is often the step before reporting, so it matters for safety too.
6. **Aggregator: Spike** (`05-vendors.md`).
7. **Account required everywhere** (above).

## Leaderboard design ("Standing")
- Per-club standing on a profile, never an app-wide rank.
- Ranked on **sessions logged in a rolling 30 days**, never pace or distance. A pace board recreates the intimidation the app exists to remove.
- The organizer decides whether a club's board exists; each member decides whether they appear. Default visibility `matches_and_clubs`, not public.
- Minors are never ranked outside their own clubs and can't be `public`.
- Ranks are computed server-side. Never send other members' raw counts to the client.

## Safety and trust (top priority)
- Minimum age 13. **Discover is 18+ only.** 13–17 join clubs and partners through QR or invite codes and never see Discover.
- Reports cover more than chat: violence, harassment, other. They go to a review queue and can end in a ban. A banned user is excluded from Discover, Matches and the map.
- At pilot scale Danny reviews reports personally. Outsourced moderation comes later, with no vendor or trigger picked yet.
- **Location data:** foreground and session-scoped only. Precise check-in pings are purged after 30 days (coarse aggregates may stay). RLS limits access to the two session participants plus a named trust-and-safety role. Encrypted at rest. When a report is filed, the relevant window becomes case-scoped, with logged reviewer access.
- Ship foreground-only location at launch (avoids the App Store background-location rejection risk).

## Matching priorities (from the research)
- Pace or ability band, goal and time slots are the main fields, ahead of distance.
- Filters are hard constraints, with an honest "no one matches, widen?" state.
- Offer small groups and "bring a friend" runs between 1:1 and a big club.
- User-set safety settings: same-gender filter, chat only after both accept, suggested public meeting spots, check-ins, location hidden by default.
- Low-pressure first-meet tags for beginners ("slow / walk-run", "silent gym partner").
- Age out inactive profiles and expire unanswered requests, so the app never feels like a ghost town.

## Go-to-market
- Partnerships with local run groups, stores and gyms in Rosslyn–Ballston, plus a founder-led seeding push. Word of mouth, not paid acquisition.
- First contacts: Pacers Running Clarendon and PR Run & Walk (Ballston Run Club). Full list in `08-market-research.md`.
- Launch window: late January or early February 2027, 8–12 weeks before the spring races (Cherry Blossom, PNC Alexandria Half).

## Open
- Several §14 follow-ups are in `10-open-items.md` (danger/warn tokens, moderation vendor, parental-consent depth).
