# Minor safety, consent and compliance

The most consequential product area. Brief §15 (plus §5.10 and §2.8) holds the full spec; this is what was captured outside the brief. Compliance findings are research, not legal advice; an attorney must confirm them before real users.

## The rule that shaped everything: SafeSport
The US Center for SafeSport bans private 1:1 electronic messages between an adult and a minor athlete, including in sport apps. Another adult (parent or guardian, adult family member, or another adult participant) must be copied. There's a close-in-age exception for a gap of 4 years or less. Danny's own use case is a coach and a 16-year-old cross-country runner, so a private 1:1 thread would put a compliant coach in breach.

**Implemented:** every minor↔adult thread includes the linked guardian as a silent, read-only `guardian_observer` row in `thread_participants`. Both sides see the same disclosure at match time and a persistent banner. Minor↔minor threads are **not** guardian-readable.
- Judgment call: this gives the guardian visibility rather than full participation. If a club safeguarding officer objects, the change is small because the guardian is already a participant row.

## Signup and guardian consent for 13–17
- At signup: DOB, guardian first and last name, guardian email **and** mobile (all required), plus the platform age signal where available (bracket and whether self- or guardian-declared).
- Guardian gets an email and SMS single-use link that names the minor and says plainly that the app arranges in-person meetups. The guardian creates a real guardian account and passes a Stripe Identity document check ($1.50). Fallback: a $0.50 authorization charge, reversed at once. A one-click email confirmation is not an acceptable consent record. Nobody in the market accepts a guardian email typed in by the minor.
- **Pending state fails closed.** A pending minor can edit their profile and log their own activity, nothing else: no Discover, no QR either way, no invite codes, no messages, no plan partners, no appearance in any roster, search or board. 14 days → soft lock; 30 days → deletion with an export offered.
- **Guardians see:** connections with adults flagged, per-connection approval (on by default), a master toggle for adult connections, club memberships, revoke, and the upcoming session schedule including time and place. Guardians cannot read minor↔minor threads, activity detail, notes or photos.

## The §15 safeguards (all requirements)
1. Minor↔minor P2P QR is allowed freely.
2. Minor↔adult requires the adult to be fully `adult` (ID-verified), never `self_attested_adult`.
3. Minor↔adult also requires an existing shared club (EXISTS on `club_memberships`). The strongest single safeguard.
4. A minor's own code is short-lived and rotating, and display-only: no share sheet, no save image, no copyable text.
5. In a minor↔adult pair the minor always scans; the adult's code is scanned, never the reverse.
6. Every minor↔adult match is flagged into a trust-and-safety queue; about 3 a week, excess queued, not refused.
- **§15.7 hard rule:** no live-map visibility and no check-in location sharing for minor accounts, ever.
- **§15.9:** all eleven checks run in order inside one server-side function every entry path calls. Test S32: a direct insert into `matches` that bypasses the gate must be refused by a constraint or trigger.

## Build-order consequence
Consent is **phase 3, straight after auth**, because `consent_status` gates almost every surface. Do not defer it to "before launch".

## State App Store Accountability Acts (status Oct 2026)
- **Texas SB 2420: enforceable now.** The Supreme Court declined to reinstate the injunction on 6 Jul 2026; the merits appeal is pending in the Fifth Circuit. Apple turned it on for new Texas accounts on 4 Jun 2026, Google on 28 May 2026.
- **Utah SB 142 / HB 498:** private right of action only; key provisions 6 May 2027 (one tracker says 2026; verify the bill text).
- **Louisiana HB 570:** in effect since 1 Jul 2026. Developers must require a linked parent account and verifiable parental consent.
- **Alabama HB 161:** 1 Jan 2027, retroactive (existing accounts by 1 Oct 2027). Apply the **lowest applicable age category's** defaults.
- **California AB 1043:** 1 Jan 2027, OS-level signal, treat it as the primary age indicator; receiving it is actual knowledge.
- **Colorado SB26-051:** 1 Jul 2028. Pending: HI, IA, KS, KY, VA.
- **Common duties:** read age category (<13, 13–15, 16–17, 18+) and consent status from the store; tell the store about any **significant change** (new data use, rating, monetization, material feature change), which triggers fresh parental consent; use age data only for age and safety; don't enforce ToS against a minor without parental consent.

## COPPA and federal
- The amended COPPA Rule's compliance date was 22 Apr 2026: written security program, posted retention schedule, vendor assurances, separate consent for non-integral third-party sharing, biometrics count as personal information. Up to $53,088 per violation.
- A store signal of "<13" is actual knowledge: block and delete promptly. The app refuses under-13 accounts.
- FTC policy (Feb 2026): data collected only to verify age is OK without parental consent if used only for that, deleted, secured and disclosed.
- **TAKE IT DOWN Act** (enforced since 19 May 2026): platforms hosting user messages must remove non-consensual intimate imagery within 48 hours. Needs a report-and-takedown flow.

## Platform APIs
- **Apple Declared Age Range** (iOS 26+, build with the iOS 26.2 SDK): age range, eligibility and method. **PermissionKit `SignificantAppUpdateTopic`** requests guardian consent for a significant update and the feature must stay blocked until it arrives. **`RESCIND_CONSENT`** server notification reports revoked consent. No Expo wrapper was found, so this needs a native module or config plugin.
- **Google Play Age Signals** (beta, client-side): check on every launch. Google does **not** disable the app when a parent denies a change; the app must enforce it. Never use the data for ads, profiling or analytics.

## What to build because of this
1. Read store age signals at signup and on each launch. Block and delete <13; route 13–17 to the invite-only flow.
2. A `RESCIND_CONSENT` webhook (Edge Function) that freezes the account and tells the guardian; check Play's approval status.
3. A significant-change checklist to file with both stores before releases that touch minors.
4. Strictest defaults for 13–15.
5. Guardian-visible adult↔minor threads with an audit log; team broadcasts include a club adult.
6. No age data in analytics, crash reporting or ads. Store only an age bucket and a timestamp.
7. TAKE IT DOWN reporting with a 48-hour takedown.

## Already in the database
`guardians`, `guardian_links`, `guardian_invitations`, `guardian_connection_approvals`, `minor_qr_codes`, `minor_adult_matches`, `verification_records`, `thread_participants`, plus the `invite-guardian`, `guardian-sms-optin`, `identity-start`, `stripe-webhook` and `account-erase` functions. PR #6 added a guardian email send log (1 per 10 minutes, 5 a day per minor). See `04-supabase-backend.md`.

## Open
- A fuller parental-notification flow beyond what's built was suggested as a possible eighth decision.
- Attorney review scope: minor P2P matching, the consent mechanism, guardian thread visibility, COPPA posture, the state laws. It binds before real users, not before code.
- Gaps in the research: Utah date conflict, no post-July Louisiana enforcement news, final CA AB 1043 text not retrieved, no 2026 MAAPP update confirmed.
- Track: CA and AL 1 Jan 2027, Utah 6 May 2027 (verify), Colorado 1 Jul 2028, the Texas appeal.
