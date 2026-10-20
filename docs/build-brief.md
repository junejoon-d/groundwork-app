# Groundwork — Structured Build Brief & Vendor Setup Guide (Revision 5)

> Plain-text extraction of `build-brief-rev5.docx` (in this folder), which is the original.
> Word tables are flattened here: each cell appears on its own line, in row order.
> When a table's structure matters, open the .docx.

---

GROUNDWORK · BUILD KICKOFF PACKAGE
Structured Build Brief
A systematic specification for a Claude Code build session — derived from 21 rounds of product, market, and technical research
Companion to: mobile-preview.html (the interactive wireframe), the Harbor Visual Design Language, and training-partner-brief.html (the Playbook)
Prepared: September 2026 · Revision 5 · Working name: Groundwork
Scope: v1 pilot — Rosslyn–Ballston corridor, Arlington, VA

Build Inputs — read this first
NEW IN THIS REVISION — This section is new. Earlier revisions never told a build session which files to open, or that an interactive reference implementation exists.
Groundwork was designed across 21 rounds before any code was written, plus a separate visual-design workstream. Four files carry that design. All four should be committed into the project repository (suggested location: docs/) so they travel with the code and can be re-read in any future session. Hand all four to the build session at kickoff.
File
What it is
How the build session should use it
mobile-preview.html
The interactive reference implementation of the mobile app. A standalone, self-contained HTML/JS wireframe — no build step, no dependencies.
THE authoritative spec for screens, states, interaction, copy, and visual language. Open it in a browser and click through every screen before writing UI code. When this document and the wireframe disagree about a detail, the wireframe wins on interaction and appearance; this document wins on data model, security, and vendor decisions. Section 9 (screen inventory) below is extracted from it, but it is a map, not a replacement — open the file. Note that the wireframe’s own colors and fonts are SUPERSEDED by the Harbor design language (§10): re-skin the wireframe’s layouts with Harbor tokens rather than copying its CSS values.
This document (Structured Build Brief + Vendor Setup Guide)
The written specification: confirmed features, out-of-scope list, data model, safety rules, vendor stack, build order, acceptance tests.
The plan of record. Work through Section 7’s build sequence one phase at a time. Verify each phase against Section 12’s acceptance criteria before starting the next.
Groundwork Visual Design Language — “Middle Distance” system, Harbor palette
The approved visual design system: color tokens (light and dark), typography, mark construction, spacing, component specs, and contrast data.
Authoritative on color, type, and component tokens. Its content is reproduced as Section 10 of this document, so the build session does not strictly need the original file — but keep it in docs/ for the swatches and the mark artwork. It supersedes every color and font value in the wireframe.
training-partner-brief.html
The Playbook — market research, competitive analysis, budget, timeline, legal, App Store submission risks.
Background and rationale. Read it when you need to know WHY a decision was made, or for the calendar-mapped timeline and App Store submission notes. Not needed to write day-to-day code.

A note on the wireframe’s honest-simulation pattern. mobile-preview.html has no backend. Several interactions stand in for a second person: tapping a pending match a second time is labelled as "simulating the other side approving"; tapping a partner chip cycles their RSVP status; the age-status control on Profile cycles adult → minor → unverified. These are demo affordances, not features. Do not build them. Every one of them is explicitly labelled in the wireframe’s own on-screen copy and source comments.
Also wireframe-only: the header eyebrow "Groundwork · mobile preview"; the "Log out (demo the sign-in gate)" and "Simulate a 13–17 minor account" buttons on Profile; the "Sample club codes" / "Sample personal codes" lists on the scan screen (a real build opens the camera); the illustrative pace constants and the time-based GPS-signal simulation on the live-recording screen; and the window.prompt() used to name a filter preset (use a real modal).
Two environment assumptions a build session must not make. First, there is no Mac — the development machine is a Windows laptop, iOS builds happen in the cloud through EAS, and any instruction involving Xcode, pod install, Transporter or the iOS Simulator does not apply (§16). Second, Expo Go is installed on the founder’s phone but is NOT the testing path: it cannot load this project’s native dependencies and the project outgrows it during phase 1. Do not issue Expo Go instructions past the first scaffolding session, and never suggest returning to Expo Go to diagnose a native-module error (§16.4a).

1. Product Overview & Scope
Groundwork is a platonic, activity-first training-partner matching app — it helps runners, lifters, and athletes of every sport find compatible people nearby to train with, log activity together, and build ongoing accountability, without the romantic framing that dating-adjacent “workout buddy” apps carry. v1 launches as a single-neighborhood pilot in the Rosslyn–Ballston corridor of Arlington, VA — a dense, transit-connected, run-club-heavy renter population identified as the strongest seeding ground in the market research (Playbook Section 04). The product is native mobile (React Native on Expo with a development build — see §13, and §16 for the Windows-only, Mac-free build pipeline; iOS-first), built around three pillars: matching (Discover’s filtered browse plus the QR instant-match path), logging (manual entry, live GPS recording, and device auto-sync/reconcile), and safety (tiered ID verification, reporting/banning, and careful handling of location and biometric data). Groups, competitions, and monetization are roadmapped but not required to prove the core matching-plus-logging loop. This brief translates 21 rounds of wireframing and research into a single ordered specification a Claude Code build session can work from directly.
2. Confirmed v1 Feature List
Organized by product area. Each item reflects a decision already made and verified in the wireframes across rounds 1–21 — this is a build spec, not a menu of options.
2.1 · Matching & Discover
Discover is the open, stranger-to-stranger browse/match surface. Requires a signed-in account (email or phone auth) and is gated 18+ (see §2.8, age-gating, which now specifies the four-state model and how an account reaches adult status).
Rule-based matching for v1 — no ML ranking. Hand-tuned filter-and-score on schedule overlap, pace/experience compatibility, distance radius, and activity type.
Discover has two view modes, toggled from the toolbar: a list view and a map view. The map shows accent-colored pins for people and teal pins for clubs, each tappable straight through to that person’s or club’s detail screen, plus a status badge reading “Live · within 1 mi · you’re visible now” or “…you’re not visible (Profile to turn on)”. A pin for the current user appears only while the “Show on live map” toggle (§2.7) is active. Banned users must be excluded from map pins exactly as they are from the list (§5.4).
People vs. Clubs is a separate segmented control from list-vs-map — all four combinations are reachable.
Full 10-filter Discover panel: sport/activity type, planned duration, distance radius (≤1/3/5/10 mi), gender, verification-status toggle, fitness/experience level (Beginner/Intermediate/Advanced), time-of-day availability (morning/midday/evening/weekend), preferred group size (1:1/small group/team), “has mutual connections” toggle, and “verified photo” (distinct flag from general ID verification).
The sport-type and gender filter option pools are generated from live data, not hardcoded enums: sport type is the distinct set of members’ primary tags plus every custom “Other”-derived tag (§2.1, fuzzy matching); gender is the distinct set of values profiles actually carry. Building either as a fixed list breaks the custom-tag feature.
Filters are chip-based, composable (multiple active at once), and persist across the session. “Clear all filters” resets them together. In the wireframe, persistence means filters survive tab switches; for the real build, persist the active filter state per user (server-side or local storage) so it also survives an app restart.
Saveable, named filter presets: a “+ Save as preset” action snapshots the whole panel; a “Manage” toggle on the preset row enables per-preset rename (pencil icon) and delete (✕, no confirmation step).
Opening Discover from a plan’s “Find a partner” flow pre-populates the sport-type filter to the plan’s activity; every other filter still layers on top. A dismissible banner (“Showing partners for <plan> · Clear filter”) marks that this context is active, and each person card grows a “+ Connect for <plan>” action.
Custom “Other” activity-type tags are matched via fuzzy string similarity (normalized Levenshtein edit-distance + a token-level pass), not a hand-curated alias list. A typed label scoring ≥0.6 against an existing tag collapses onto that tag; a suggestion at ≥0.45 is offered but not forced.
Fuzzy-match thresholds self-tune within a session: an accepted suggestion nudges both thresholds down (0.03 match / 0.02 suggest, floored at 0.45/0.30); a label saved without accepting a suggestion nudges them up by the same amounts (capped at 0.75/0.55). Surface the live threshold and accept/reject counts to the user. Persist these per user (see custom_tags / tag_match_settings in §4) — the wireframe holds them in memory only.
“Matched” requires a real two-sided event: one request + one corresponding approval. A bare Discover request lands the target in a “pending” state; only an explicit approval (or a QR mutual-confirm, §2.6) advances to “matched.” Connecting a partner directly from a plan’s “Find a partner” flow is the one exception — that action is already two-sided and sets status straight to “matched.”
The match control has three states with fixed copy and styling: “Request to train” (accent fill, white text) → “Requested — tap to approve” (accent outline on a tinted background; in production this is a passive “Requested · waiting” state, with approval happening on the other person’s device) → “Matched ✓” (teal on a teal tint). A matched person cannot be un-matched by tapping this control; that is the separate, destructive “Delete match” action.
Deleting a match clears request/plan-partner state across every plan the person appears on — not just the plan in view — but must never delete the associated chat thread; see §2.5.
Empty state, Discover list: “No matches for these filters yet — Clear a filter to see more people nearby.”
2.2 · Scheduling & Plans
1:1 scheduling is peer-overlap, not a booking link: each side proposes windows (day + time-slider); the app surfaces the overlap. The slider runs 5 AM to 9 PM in two-hour steps in the wireframe; the real build should allow finer granularity but keep the same one-screen day-chip-plus-slider interaction.
Club scheduling is organizer-posts / members-RSVP, with a waitlist once an event is full. Timezones always shown explicitly. A club has many upcoming sessions, not one standing time — the club detail screen lists them.
Recurring vs. one-time per plan, defaulting to recurring. A recurring plan additionally picks Open-ended or “End after N weeks” (stepper input, clamped 1–52) — reflect the end condition on the plan’s own summary chip (e.g. “Every Thu · 6:30 AM” vs. “Every Sat · 9:00 AM · ends in 7 wks”). A one-time plan’s chip reads “Sat · 9:00 AM · once”.
Recurring-plan edits need an explicit scope choice: “this session,” “this and following,” or “whole series.”
A plan can carry a linked template (e.g. a lift day pointing at a specific pre-filled Push Day template).
Plan cards work across every sport, not just running: run / lift / ride / generic “Other,” each with an activity-appropriate primary action (“Start live activity” for run/ride/Other; “Start from plan”, opening manual entry pre-loaded with the linked template, for lift). Every plan card also carries a secondary “Mark complete”.
Session history & consistency tracking per plan: a session count, a consistency-rate percentage (color-coded — teal ≥70%, accent/amber below), a streak count, and a six-dot recent-history strip (last six scheduled occurrences, filled if completed, otherwise a neutral grey dot).
2.3 · Logging: manual entry, live GPS recording, auto-reconcile
Tab split (load-bearing, easy to get wrong): every logging ACTION lives in the Activity tab — Today’s plan, upcoming plans, scheduling, “Start live activity”, “+ Log manually”, and the template picker. The Log tab is history-only: the auto-synced card plus the expandable recent-activity list. Do not put manual entry in Log.
Three logging paths: quick manual entry, device auto-sync (HealthKit/Garmin via aggregator, §2.12), and live in-app GPS recording.
Live activity recording: start a run/ride from the app, see elapsed time/distance/pace update live, with pause/resume and a finish step that drops the session into history. Requires GPS to keep updating with the screen locked/app backgrounded — foreground-only at launch is an acceptable v1 fallback if background-location App Review risk (§3, and the Playbook’s App Store submission section) becomes a blocker; background as a fast-follow.
Live activity types are Run, Bike Ride, and Other. “Other” tracks duration only — no distance, no pace, no assumed speed — and offers the same free-text activity label with fuzzy autocomplete that manual entry does.
GPS-signal indicator (“Acquiring… / Weak / Strong”), styled with --pal-warn while acquiring, --pal-danger once weak, and --pal-b once strong (§10.11). A weak-signal state surfaces a warning with a “Log manually” escape hatch that cancels the live recording and drops the user into manual entry for the same activity, carrying forward any linked plan/template. In the wireframe the three states are simulated on a timer; in the real build derive them from CLLocation horizontalAccuracy (or the Android equivalent) — e.g. no fix = Acquiring, >30 m = Weak, ≤30 m = Strong.
A live activity started from a plan shows a “Following today’s plan” card naming the plan’s target, and marks that plan complete when it finishes.
Auto-reconcile: a synced activity matching Today’s Plan’s type marks the plan complete in the same tap. The synced card shows a “Matches today’s plan ✓” badge, and the reconcile happens when the user confirms the card (“Looks right” → “Confirmed ✓”) — it is user-confirmed, not silent. The Auto-synced card shows a small metrics grid (duration, avg/max heart rate, calories) alongside the reconcile action, plus set-by-set detail for a strength session and +Photo / +Note actions.
One card per activity as the atomic history unit everywhere; activity-appropriate depth inside the card (cardio: pace/duration/distance/HR/cadence; lift: expands to individual sets, does not become its own top-level item). Cards are tap-to-expand, collapsed by default. Photos and a note attach to any activity, and show as small glyphs on the collapsed card.
Personal dashboard: streaks, volume trends, PRs.
2.4 · Multi-partner plans & status tracking
A plan’s partner slot is not capped at one — each plan tracks a list of connected partners as chips (“Find a partner for this” when empty, “+ Add another partner” once one is connected).
Each connected partner carries a status: Invited → Confirmed → Declined → back to Invited (in production, driven by the partner’s own RSVP; the wireframe cycles it by tap as a stand-in). Show a small colored status dot plus label on the chip. Tokens: Confirmed = --pal-b (teal), Invited = --pal-warn, Declined = --pal-danger, each as a full-strength filled dot, with the chip itself following Harbor’s pill pattern — the matching tint as background and --pal-ink as the label text (§10.11). Do not color the label text with the status token; on a tint background that fails normal-text contrast.
A Declined partner gets a “Dismiss for now” action, separate from the status cycle — this only removes them from that one plan’s active display (soft, per-plan, no exclude-list) and they remain a full match in Matches. A distinct, harder “Delete match” action is the only way to actually remove the connection, and is reachable from both Matches and the partner’s own profile. It uses the destructive treatment in §10.11 — a --pal-danger fill or outline, never the coral primary-action color.
2.5 · Chat with structured message cards
Every confirmed match gets a persistent 1:1 chat thread, backed by Stream Chat (§6). Beyond plain text, the thread must render structured message types: a plan/template share (message bubble with inline accept/decline), a proposed session time (live-synced card), and a check-in-nearby nudge.
Schedule and Log stay the source of truth for their own data — the chat thread only ever mirrors what's already true there; it is never a second place to set a schedule or a log entry.
How that mirroring works, concretely: a structured card is a Stream Chat message whose payload carries only an identifier and a rendering hint (e.g. {type: "session_proposal", session_proposal_id: "…"}). The client fetches the current state from Postgres and renders it, so the card is always live rather than a frozen snapshot of what was true when it was sent. Never write schedule or log state into the chat message body.
Structured cards in the thread: a template share (“<name> sent you a template”, with Decline / Accept & save, resolving to a small “You accepted … — saved to your templates” note); a session-proposal card (“Session proposed · Thursday · 6:00 AM · waiting on <partner>”, tapping through to Activity); and a check-in nudge (“<partner> checked in near Rosslyn · 10 min ago” with a “Start your log” action and a mute link).
Per-thread notification control with two independent toggles — Messages and Check-in nudges — both defaulting to on. Decided September 2026, extending the wireframe, which offered a mute for check-in nudges only. Scoped to that one thread and that one user; never global and never visible to the other participant. Muting suppresses push only — the thread and its messages remain fully readable in the app, and an unread indicator still appears. The muted check-in state keeps its inline pill with an Unmute action, as in the wireframe.
The reason to ship message muting in v1 is not only convenience. A user who has become uncomfortable with a partner but is not ready to report them or delete the match needs a low-friction way to reduce contact; muting is very often the step before reporting. Making that step available inside the thread is a safety affordance, not just a preference.
Deleting a match must never delete the chat thread. Matches surfaces an “Archived chats” section for any thread whose match has been deleted (label: “Match deleted · thread kept”), fully reachable with intact history.
Shareable workout templates: a matched partner can send a template as a chat message; accepting adds it to the recipient's own templates without auto-applying it to today's log.
“Report <partner>” is present in the thread itself, and expands the same report panel used on a person’s profile (§2.10).
2.6 · QR instant-match system
Every profile has its own personal QR code (“My QR code” on Profile). Every club has its own QR code on its detail page. Both are used to connect/join instantly in person.
Static, not rotating, codes for v1 (a deliberate decision, not a default): club codes must be static because they get printed on flyers/bibs/table cards; personal codes are also static for v1 on a simplicity basis, since the confirm-tap step (below) is the accepted anti-abuse defense for now. Do not build a rotating/TOTP-style token system for v1.
Personal-code scan requires a second mutual confirm tap on both sides before a match is created — a scan alone proves proximity, not consent. This preserves the same “request + approval” principle as an ordinary Discover match, just compressed into one scan and one confirm tap.
Club-code scan/join is a true one-tap instant join — no second confirm step, since a club isn't a person who needs to individually consent to being met.
A typed invite code is an equal-status alternative to scanning, not a fallback: Profile carries an “I have an invite code / scanned a QR” entry that accepts the same identifier and produces the same join. The Discover age gate routes minors and unverified accounts to it explicitly. Build the code-redemption path as the primitive and make the camera scan one way to supply the code.
Minor-safe routing is folded into the QR flow, not a separate mechanism: if the scanning account is flagged 13–17, a club-code scan automatically routes through the minor-safe direct-join path (no Discover exposure).
A 13–17 account CAN form person-to-person QR matches. This is a founder decision (September 2026) that restores the original round-11 intent — a minor who cannot use Discover still needs a way to connect with the teammates and coach from their actual team. Round 16 narrowed the QR system to club codes only for minors; that narrowing is reversed. The personal-codes surface renders for a minor account, and the underlying match action succeeds for a minor, subject to the safeguards in §15.
The reopened risk is real and §15 exists to address it. A QR code is a shareable image and v1 codes are static, so without additional constraints an adult anywhere can text a minor their code and obtain a private 1:1 chat thread and meetup scheduling with that minor, with no physical presence involved. That was the stated reason for the round-16 block. §15 recommends a set of safeguards — the most important being a club co-membership requirement for any minor-to-adult match — that preserve the teammate/coach case while closing the remote-stranger case. Those safeguards are recommendations awaiting founder confirmation; the minor person-to-person allowance itself is decided.
Fail closed on ambiguous/unverified age status: Discover browsing and person-to-person QR scanning are both blocked for an unverified account. Club-QR scanning/joining is the one deliberate exception and stays available even for an unverified account (joining a known, named club is lower risk than connecting to an unvetted stranger, and blocking it would also block legitimate new-account onboarding). Note the asymmetry introduced by the decision above: unverified now blocks person-to-person QR where minor does not, because unverified means the account’s age is genuinely unknown — it could be an adult evading verification — whereas minor is a known, handled state with its own rules.
One shared scan entry point (“Scan to connect”), reachable from Profile, Discover's toolbar, and the Discover 18+ gate screen — not a separate “event mode” feature. It opens as a full-screen flow layered over whatever tab the user was on, with a back button in the header and the tab bar still visible.
Every profile/club needs a persisted QR identifier field from day one (e.g. GW-P-<name>-#### for a person, GW-C-<club>-### for a club).
2.7 · Profile
“Journey so far” headline accomplishment is authored per person, fitted to their established sport — never a hardcoded default (e.g. a runner gets a marathon count/latest time; a lifter gets a PR lift; a cyclist gets a longest-ride milestone). Fields render only where real data exists — a newer member shows a shorter, honest card rather than padded/fabricated stats.
PRs across every sport a person actually logs (not only their primary tag), years training/experience level, a short training-philosophy blurb, typical weekly volume, mutual-clubs chips.
“Together & clubs” card: mutual training partners (people both users already train with), sessions-together count (a per-relationship count of logged/synced sessions between the viewer and this specific person), and club memberships (every club a person belongs to, cross-referenced against — but shown distinctly from — the mutual-clubs list).
A profile displays the person’s total training-partner count — e.g. “14 training partners.” Confirmed by the founder in September 2026. This REVERSES a round-17 instruction that no total-match count be shown anywhere; see the reversal note in §14.1. A build session encountering the older rule in any other artifact should follow this one.
Only active matches count toward the total. Deleted matches are excluded, matches with a banned account are excluded, and pending (requested-but-not-yet-approved) connections are excluded — it is a count of actual training partners, not of outbound requests.
The count is computed server-side and only the total reaches the client — never the underlying match rows. Same principle as §5.9’s leaderboard rule: a partner total must not become a way to enumerate somebody’s social graph one request at a time.
The partner count is governed by the same visibility control as Standing (§2.14) — off / matches_and_clubs / public — not a second, separate setting. One control covers both. Two overlapping privacy toggles for closely-related social-proof numbers is a usability and support problem, and a user who has decided how visible their activity should be has already answered this question.
A minor’s profile does not display a partner count to anyone outside their own clubs, consistent with the rule that minors are never ranked outside their clubs and never public (§2.14, §5.9). The minor themselves and their linked guardian can always see it.
Own-profile-only cards, absent from the public view: an editable sport-tag row with a “+ Add activity” chip, a “Training for” goal card (e.g. “Marine Corps Marathon · Oct 2026”), and a “Usually free” free-text availability blurb (distinct from the structured weekly availability grid that feeds matching — both exist).
Two independent verification badges: “ID verified” (neutral checkmark) and “Photo verified” (teal, camera icon) — a profile can carry either, both, or neither; both must be conditional on their own underlying flag, never rendered unconditionally.
“Show on live map” toggle is off by default and requires a two-flip activation sequence (arm → pick a duration from a fixed set of 30 min / 1 hr / 2 hr / 4 hr, nothing pre-selected → second flip activates); turning off (manually or by timeout) clears both steps, so re-activation is always a fresh deliberate sequence. The card shows an explicit status line at each stage (“Flip 1 of 2 done — pick a window below…” / “1 hr selected — flip the toggle again to go live.” / “Visible on the live map now — auto-off in 1 hr.”). The expiry must be enforced server-side, not only by a client timer.
2.8 · Age-gating (13+ overall, 18+ Discover)
Minimum account age 13+. Discover (the open matching/browse surface) requires 18+.
A 13–17 account can still belong to clubs and specific partner relationships without ever touching Discover, via the QR/invite path (§2.6) — minor-safe routing is a case within the QR system, not a separate mechanism.
A 13–17 account hitting Discover must see an explicit “Discover is 18+” gate screen, not a silent block or a description-only limitation. An unverified account sees a distinct “Age not verified yet” variant of the same screen with its own copy. Both gates offer two forward actions: “Scan a club’s QR code” and “Go to Profile → Join via invite code”.
The four-state age model (decided)
Confirmed by the founder in September 2026. This replaces the three-state model in the wireframe. age_status is written server-side only — by the signup handler or the Stripe Identity webhook — and there is no client-writable path to it.
State
How it is reached
What it permits
unverified
Default for any new or ambiguous account, and for any account with no usable birthdate (incomplete signup, import, failed validation).
Fails closed. No Discover. No person-to-person QR. Club-QR join and invite-code redemption only. This is the one state where person-to-person QR is blocked, because the account’s age is genuinely unknown.
minor
Self-attested birthdate at signup places the account at 13–17. Also set — permanently — if an ID check returns an under-18 result, or if the attested and ID dates of birth disagree materially.
No Discover, ever. A minor account additionally carries a consent_status and stays fail-closed until a guardian completes consent (§15.2). Once consent is granted: club joins, invite codes, and person-to-person QR matching subject to every rule in §15. Never eligible for the live map or check-in location sharing (§5.8).
self_attested_adult
Self-attested birthdate at signup places the account at 18 or over. This is NOT the same as adult.
Discover browsing and person-to-person QR with other adults, which still requires the mutual confirm tap. Does NOT satisfy the pre-meetup ID gate in §2.9, and under §15 does not permit forming a match with a minor.
adult
Set only by a server-side webhook handler on a completed Stripe Identity document check whose returned date of birth implies 18 or over at the time of verification.
Everything self_attested_adult permits, plus it satisfies §2.9’s government-ID gate before a first 1:1 meetup, and it earns the “ID verified” badge. Under §15 it is the only adult state eligible to match with a minor.

Collect a date of birth with a date picker at signup — not an “I am over 18” checkbox, which is worth nothing and reads badly in an App Review minor-safety assessment.
Under 13: refuse the account outright and say why. This is a COPPA line, not a product preference.
Minor status is granted on self-attestation alone because it is the restrictive direction — claiming to be a minor cannot be used to gain access. Adult status is not.
A 13–17 signup additionally collects guardian contact details and cannot complete without them, and the account remains fail-closed until guardian consent is verified — see §15.2 for the full mechanism, which was derived from current practice across comparable products and the 2026 regulatory floor.
Where the platform provides an age signal — Apple’s Declared Age Range API on iOS 26 and later, Google’s Play Age Signals API on Android — read it at signup and record both the bracket and whether the declaration was self- or guardian-declared. Three states have app-store accountability laws taking effect through 2026 that place obligations directly on developers to receive and act on these signals; Texas is the earliest. Query and decide rather than caching long-term, per both platforms’ own guidance.
A downgrade to minor is sticky. Once an ID check returns under-18, the account cannot be re-verified into adult by a later attempt without human review.
Store only the derived outcome, never the date of birth. Stripe returns it at verified_outputs.dob, but only to a restricted API key and by default only for verifications submitted in the last 48 hours — a deliberate design signal about its sensitivity. Read it inside the webhook handler, compute over-18 or not, write age_status, and discard the value. This keeps §5.3’s no-raw-biometrics rule intact and keeps the date of birth out of scope for a VCDPA sensitive-data argument.
Rationale for not requiring the full ID check before Discover: it would mean every user pays $1.50 and completes a document scan before seeing a single profile, which would collapse pilot signups. The tiered model in §2.9 already places the strong check where the real risk is — immediately before a first 1:1 meetup.
2.9 · ID + photo verification
Tiered model: baseline liveness-checked selfie for clubs/group meetups; a stronger government-ID + selfie match gate before a first 1:1 meetup.
Vendor: Stripe Identity (§6) — self-serve SDK integration, ID+selfie match, $1.50/verification after 50 free.
Verification-is-not-a-safety-guarantee framing must appear in the ToS/onboarding copy — verification confirms a stated process completed, not that the person is safe to meet.
2.10 · User reporting & banning
“Report” is reachable from both a matched partner’s profile/detail view and the chat thread — the report surface is a person's behavior, not a single message. Report and ban surfaces use --pal-danger throughout: the report link, the report panel’s border and submit button, and any banned-state treatment (§10.11).
Reason picker: Harassment, Violence or safety concern, Inappropriate behavior, Other (optional free text). Submitting lands in a visible “under review” state, shown on that person’s profile as a small “Reported by you · under review” pill.
A Harassment or Violence/safety-concern report should fast-track toward a ban (a real build should keep a human review step before the ban actually takes effect — the wireframe's instant-ban simulates a fast-tracked queue, not a recommendation to auto-ban without any review).
A banned account must be fully excluded from Discover and Matches everywhere, not merely flagged — verify this end-to-end, it is one of the audit-critical rules in §5.
At pilot launch, “under review” realistically means founder-personal review, not a staffed team — build the flow to support a single-reviewer operating model, with outsourced/vendor moderation as a later, volume-triggered upgrade (see §8, open items).
2.11 · Check-in nudges
Opt-in, per-session, foreground-only, coarse location sharing between two matched partners for an active session window — never a standing background permission. Uses the same two-flip activation pattern as “show on live map.”
When both partners are near the agreed meetup, the chat thread surfaces a “start your log” nudge card.
Retain the precise check-in location ping for 30 days, then purge from the live table (aggregate stats like “N check-ins this month” may persist without coordinates). Read access scoped via RLS to the two session participants plus a named trust-and-safety role — see §5.
2.12 · HealthKit / Garmin integration via aggregator
Confirmed required for v1, per the founder's round 21 correction: a third-party aggregator is a required launch dependency, not deferred — most runners in the Rosslyn-Ballston pilot community wear Garmin or other non-Apple watches, per the founder's direct, first-hand knowledge of the local running community (this overrides an earlier assumption based only on general demographic profiling).
Vendor confirmed: Spike (September 2026), with Terra as the documented fallback. Selected on the Expo criterion — Spike publishes a first-party Expo config plugin with its own documentation page, which automatically configures HealthKit entitlements, the iOS usage strings, and Android Health Connect permissions. Terra ships an Expo demo project but no config plugin and no Expo documentation page. See §13.2.
Spike is two integration paths, not one, and the build must implement both. The React Native SDK covers on-device sources only — Apple HealthKit and Android Health Connect. Garmin is a cloud-to-cloud provider integration handled through Spike’s server-side API and webhooks, with the user authorizing Garmin once via a Spike-hosted connection flow. Practically: the phone handles Apple Health, and a Supabase Edge Function receives Garmin activity webhooks and writes activity_logs rows. Do not look for a Garmin path inside the mobile SDK; it is not there, and assuming otherwise will cost real time at build phase 9.
Apple HealthKit is integrated directly and separately (no partnership approval needed, just standard App Store review) — keep both HealthKit-direct and the aggregator in the stack; HealthKit serves the iPhone-only minority, the aggregator serves the Garmin-wearing majority.
Google Health Connect should be built alongside HealthKit for Android platform parity if/when Android ships.
Auto-reconcile only needs a completed workout's type, duration, and avg/max heart rate — a batch/historical API read (HealthKit + the aggregator's normalized feed) is sufficient. Do not build a live-telemetry/Watch-app integration for v1 — that is a separate, materially larger v2+ feature nobody has requested yet.
Testability differs sharply between the two halves, and this matters for scheduling. Apple Health runs through the mobile SDK on the founder’s own iPhone and can be exercised end to end with real workouts from day one. Garmin cannot be tested that way, since it arrives through a server-side webhook that needs a real connected Garmin account to fire. A Garmin-wearing beta tester is already secured, so this path is verifiable rather than speculative — but they must be brought in at the START of phase 9, when the integration is being wired, not at the TestFlight phase. See §16.5a.
Strava is import-only (a one-time “connect Strava to import your last run”), never the core data backbone — Strava's API Policy bars competitive-use and bulk aggregation.
Ingested activities must be de-duplicated: the same workout can arrive from HealthKit and from the aggregator. Store the provider’s own activity identifier on activity_logs (§4) and make (user_id, source, external_activity_id) unique.
2.13 · Push notifications
NEW IN THIS REVISION — The six push events below were mapped in earlier rounds but appeared nowhere in the previous revision except as a line in the vendor table.
Push is a confirmed launch requirement. Exactly six events ship in v1. Every one deep-links into the app; none of them ever carries another user’s precise location in the payload.
Event
Trigger
Recipient / copy
Opens
match_request_received
A matches row is inserted with status = pending.
Recipient. “Jordan M. wants to train with you.”
That person’s detail screen, with the approve action.
match_approved
matches.status moves pending → matched, including via a QR mutual-confirm.
The original requester. “You and Jordan M. are now training partners.”
The chat thread.
chat_message_new
A new Stream Chat message in a thread. Suppress if that thread is already open in the foreground.
The other participant. Sender name + message preview.
That chat thread.
checkin_nudge
Both session participants have checked in within the meetup radius during the session window. MUST respect the per-thread mute (§2.5).
The partner. “Jordan M. checked in near your meetup spot.” Never include coordinates.
That chat thread.
schedule_proposal
A session proposal is created, and again when it is accepted or declined.
The other party. “Jordan M. proposed Thursday, 6:30 AM.” / “Jordan M. confirmed Thursday, 6:30 AM.”
Activity → that plan.
plan_reminder
Scheduled job, default one reminder at T-1 hour before a scheduled session (make the offset a per-user setting).
Plan owner plus every Confirmed partner. “Easy run · 4 mi at 6:30 AM with Jordan M.”
Activity → that plan.

Delivery rules: send only to push_tokens rows that are not revoked; on an APNs/FCM “unregistered” response, mark the token revoked rather than retrying. Never send to, or on behalf of, a banned account. A user with no registered token is a normal state, not an error.
Mute handling: chat_message_new respects thread_settings.messages_muted, and checkin_nudge respects thread_settings.checkin_nudges_muted, both per (thread, user) — see §2.5. The other four events are not mutable in v1; they are all consequential, low-frequency, and directly about the recipient’s own commitments. Muting suppresses the push only, never the underlying record.
A minor account receives push for the same six events, with one exception: checkin_nudge never fires for a minor in either direction, because check-in location sharing is disabled for minor accounts entirely (§5.8).
2.14 · Leaderboards
NEW IN THIS REVISION — Confirmed in scope for launch by the founder (September 2026), for clubs and for personal profiles. The previous revision listed leaderboards as out of scope with one narrow club exception.
Two distinct surfaces — club boards and personal standing — each offered on two ranking bases, all-time and rolling monthly. The club leaderboard already exists in the wireframe. The personal standing surface does not and is specified here for the first time; it deliberately reuses the per-relationship “sessions together” figure §2.7 already puts on the profile rather than introducing a parallel counter.
Two ranking bases (both ship)
NEW IN THIS REVISION — Changed in this revision: the founder confirmed that both an all-time and a rolling-monthly board ship, for clubs and for personal profiles. An earlier revision ranked on all-time only, with the 30-day figure display-only.
All-time — ranked on total sessions since joining. The long record. Rewards sustained membership and gives the club’s most committed members a permanent, visible place.
This month — ranked on sessions in a rolling 30-day window. An equal ranking basis, not a decorative secondary figure. This is the board a member who joined last week can actually move.
A segmented toggle on the board header — “This month / All time” — switches between them, matching the People/Clubs and list/map segmented controls already established in Discover (§2.1) rather than introducing a new control shape.
The default is This month. It is the board a newcomer can climb, so it is the more motivating thing to land on, and it keeps a board from reading as a fixed hierarchy of whoever joined earliest. All-time stays one tap away and is the right default for nobody in particular — it is the record, not the invitation.
Neither basis is pace or performance. Both count sessions. That decision is unchanged.
Both bases obey identical access rules — organizer flag, per-member opt-out, visibility setting, minor restrictions, server-side computation. There is no board on which a member appears under one basis and not the other.
Club member count
A club page displays its member count — e.g. “24 members.” Confirmed by the founder in September 2026, alongside the profile partner count in §2.7. This is distinct from the existing “N going this week” RSVP figure, which counts attendance at the next session; both appear.
Only active memberships count. A banned account is excluded, and a departed member decrements it. The total is computed server-side and only the total reaches the client — never the roster, which remains subject to its own access rules.
A club’s member count is public to anyone who can see the club, since a club is an organization rather than a person and its size is ordinary public information. Minor members are counted in the total but are never individually enumerable from it.
Club leaderboard (exists in the wireframe)
A club detail page may show a “Top athletes” list — rank, member display name, and a single stat (“14 sessions logged”) — with a small “Shown by organizer” chip beside the section label, and the This month / All time toggle on the section header.
Organizer-controlled visibility stays. clubs.show_leaderboard remains a per-club flag set by the organizer and defaults to off. A club that does not want a competitive dynamic simply never turns it on, which is the right default for a beginner-friendly club like the sample “We’re Not Really Runners.”
Members also get an individual opt-out, independent of the organizer’s flag. The organizer decides whether the board exists; each member decides whether they appear on it. Opting out removes the member from the board immediately and retroactively. This pairing is what keeps the feature from becoming a surveillance surface inside a club someone joined for social reasons.
Personal standing — “Trained together”
NEW IN THIS REVISION — Metric changed in this revision at the founder’s direction: all-time totals, for both clubs and people. An earlier draft proposed a rolling 30-day window.
The metric is sessions, on both bases. Explicitly not pace, distance, or any performance measure. A club board ranks members on sessions logged with that club; the personal surface ranks the people you have trained with by sessions logged together. Each is offered all-time and for the trailing 30 days.
The personal surface is a ranked list of the people you have trained with most, and it reuses the count already on the profile. §2.7’s “Together & clubs” card already carries a per-relationship “N sessions logged together” figure. That figure IS the personal standing metric — there is one counter, not two. The Standing card simply ranks those same per-relationship counts and shows the top few: “Jordan M. · 42 · Priya K. · 18 · Nia F. · 6.” Tapping through opens that person’s profile, where the same number appears in its existing place. Do not introduce a second, separately-computed sessions-together counter; if the two ever disagree the feature is broken.
A person’s own Standing card shows both halves: their club standings (one chip per qualifying club, “#3 of 24 · 47 sessions”) and their top training partners by sessions together. The card carries the same This month / All time toggle and both halves switch together.
What counts as a session together is unchanged from §2.7: a logged or synced activity attached to a plan or session both people were confirmed on. It is not a count of messages, matches, or plan invitations.
A club chip appears only when all three are true: the club’s organizer has enabled the leaderboard, the member has not opted out of that club’s board, and the viewer is permitted by the member’s visibility setting.
Visibility is a three-state per-user setting: off; matches_and_clubs (visible to matched partners and fellow members of that club); public (visible to anyone who can see the profile in Discover). Default is matches_and_clubs. A profile seen by a stranger in Discover therefore shows no standing by default — activity volume is not something a stranger should be able to read off a profile before any connection exists.
A minor account is never ranked on any board visible outside its own clubs, and public is never an available setting for a minor. A 13–17 account’s standing is visible only to fellow members of that specific club, and never to a partner who is not also a club member.
Ties break on who reached the count first. Both ranks are computed server-side on a schedule and materialized; neither is computed in the client.
Never ship other members’ raw counts to the client. The client receives only the rows the board actually displays — display name, rank, and the one stat — and only for members whose visibility permits it. Sending the full per-member session counts so the client can sort them would leak every member’s activity volume to every other member, which is the most likely way to build this feature wrong.
“Personal bests” stays a separate, non-competitive block. The existing multi-sport PR list (§2.7) is what most people mean by a personal leaderboard, and it should be presented as a person’s own record rather than folded into a ranking against others.
Standing itself is always scoped to a named club or a named person — it is never an app-wide ranking. The separate total-partner and member counts in §2.7 and §2.14 are plain totals rather than rankings, and are governed by the same visibility control.
Why both bases exist. An all-time count structurally favours whoever joined earliest — a member joining in month nine cannot realistically climb a board topped by someone with two years of sessions, which is the same discouragement a pace-ranked board would produce, relocated onto a tenure axis. Shipping the monthly board alongside it answers that structurally rather than cosmetically: every member has one board they can move this week and one that records what they have built. This is why the monthly board is the default view.
Optional, take or leave: show the inactive basis as a secondary figure on each row — “#3 · 142 all-time · 9 this month” — so the other board is legible without switching. Display only; it does not affect either ranking.
3. Explicitly Out of Scope for v1
Named directly per round 17's feasibility pass, so scope doesn't get re-litigated mid-build. None of these are declined forever — each has a stated revisit trigger.
Squad / group-vs-group matching — automated matching of one small group against another. Ship the already-built manual multi-partner plan model (add partners one at a time, track status per §2.4) for v1; treat intelligent group-vs-group matching as a genuine v2 feature.
No staffed, 24/7, or SLA-backed moderation queue — not realistic for a small team at launch. “Under review” at pilot scale means founder-personal review (§2.10). Revisit once real volume data exists.
No rotating/short-lived QR tokens — static codes only for v1 (§2.6). Revisit if real screenshot-sharing/code-farming abuse is observed post-launch.
No scan-rate limiting on personal QR codes — explicitly deferred, not declined. Real usage data (how often a code gets scanned, any outlier pattern) is the input this decision needs and doesn't have yet.
No proximity/GPS/Bluetooth co-location check on the QR mutual-confirm step — a plain confirm tap is the whole mechanism for v1.
No ML-based or adaptive matching/coaching — v1 matching is rule-based (§2.1); v1 training plans are templated, not adaptive.
No background-location entitlement requested at launch (if App Review scrutiny requires it) — foreground-only live recording is an acceptable v1 fallback; background is a fast-follow.
No live watch/Connect IQ app — driving a live session from an Apple Watch or Garmin device face is a v2/v3 feature, not required for auto-reconcile.
No payments or competitions at launch — roadmapped for v2/v3, not required to validate the core matching+logging loop. “Competitions” here means organized, time-boxed challenges with entry and prizes; the leaderboards in §2.14 are a standing display, not a competition, and are in scope.
Leaderboards are no longer out of scope. A previous revision excluded them with one narrow club exception; the founder confirmed in September 2026 that both club and personal-profile leaderboards ship at launch. They are specified in §2.14. What remains out of scope is any app-wide ranking of all users against each other — every board is scoped to a named club.
No signed-out mode. An account is required for the entire app, confirmed by the founder in September 2026. There is no anonymous browsing of any surface, no read-only preview, and no data-bearing query reachable without authentication. The wireframe’s sign-in gate copy implies Matches, Activity, and Log function while signed out; that is a wireframe artifact and must not be built.
No RAINN-style formal safety-org partnership pre-launch — a named individual safety advisor or a Trust & Safety Professional Association consultant for a safety-feature audit is the realistic pre-traction substitute.

4. Data Model Sketch
NEW IN THIS REVISION — This section has been corrected and extended. The previous revision contained two dangling foreign keys (plans.linked_template_id and checkin_locations.session_id both pointed at tables that did not exist) and was missing tables for club events/RSVPs, workout templates, agreed sessions, activity sets, push tokens, and per-thread chat settings.
A reasonable first-pass entity list for a Postgres/Supabase schema — enough to start scaffolding, not a full DBA-level spec. Types are indicative (Postgres-flavored); exact types/constraints are a build-time decision. Tables marked ADDED were missing from the previous revision and are required by features that were already confirmed.
4.1 · Core identity & profile
Entity
Key fields
Relationships / notes
users
id, auth_id (Supabase Auth), email, phone, created_at, age_status (unverified / minor / self_attested_adult / adult), age_status_set_at, birthdate_attested_at, consent_status (not_required / pending / granted / revoked), consent_status_set_at, platform_age_bracket, platform_age_declared_by (self / guardian), is_banned, banned_at, banned_reason
1:1 with profiles. age_status drives every fail-closed rule in §5. The four-state enum is confirmed and specified in §2.8; it is wider than the wireframe’s three states. Writable server-side only. consent_status is not_required for any adult account and drives the fail-closed restrictions in §15.2 for minors. platform_age_bracket / platform_age_declared_by hold the most recent Apple Declared Age Range or Google Play Age Signals response — query and decide rather than caching long-term, per both platforms’ guidance. Do NOT store the raw birthdate; store only the derived status (see verification_records).
profiles
user_id (FK), display_name, bio/philosophy, headline_accomplishment (sport-specific), years_training, weekly_volume, usually_free (free text), training_for (goal), gender, experience_level, preferred_group_size, neighborhood, home_point (geography, coarse), avatar_url, qr_code (unique), id_verified (bool), photo_verified (bool), live_map_visible_until (timestamptz, null)
1:1 with users. qr_code is the personal-QR identifier (§2.6). live_map_visible_until is the server-side expiry for the two-flip “Show on live map” toggle (§2.7) — a client-side timer alone is not sufficient, and it must remain null for any minor account (§5.8). home_point should be stored coarse (neighborhood centroid), not the user’s exact address.
profile_sports
profile_id (FK), tag, is_primary
ADDED. The editable sport-tag row on Profile and the tag chips on a card. The Discover sport-type filter pool is built from the distinct set of these plus custom_tags (§2.1).
guardians
id, user_id (FK users — the guardian’s own Groundwork account), first_name, last_name, email, phone, verified_at, verification_method (stripe_identity / card_authorization), provider_reference_id
ADDED. A guardian is a real account, not an email address on a minor’s record (§15.2). verified_at is set only when the identity or card-authorization step completes.
guardian_links
id, guardian_id (FK guardians), minor_user_id (FK users), status (pending / active / revoked), invited_at, consented_at, revoked_at, adult_connections_allowed (bool, default true), per_connection_approval_required (bool, default true)
ADDED. One active link per minor at a time. The two boolean columns are the guardian controls in §15.4; per_connection_approval_required defaults to on.
guardian_connection_approvals
id, guardian_link_id (FK), match_id (FK matches), status (pending / approved / denied), decided_at
ADDED. One row per minor-to-adult connection awaiting or having received guardian approval (§15.4, §15.9 step 10).
sport_prs
id, profile_id (FK), sport, metric_label, metric_value, achieved_at
Many per profile — powers the multi-sport PR list.
availability
profile_id (FK), day_of_week, time_block
Weekly grid; feeds matching. Distinct from profiles.usually_free, which is prose.
4.2 · Matching, chat & clubs
Entity
Key fields
Relationships / notes
matches
id, requester_id (FK users), recipient_id (FK users), status (pending/matched/declined), source (discover/qr_scan/plan_partner), requested_at, matched_at, deleted_at
The core pairing entity. status transitions per §2.1’s request+approval rule. Add a unique constraint on the unordered pair (least(requester_id, recipient_id), greatest(...)) so two people cannot end up with two rows. Deleting a match is a soft delete or a row delete — either way it must not cascade to chat_threads.
chat_threads
id, match_id (FK, nullable, ON DELETE SET NULL — never CASCADE), stream_channel_id, archived (bool), created_at
1:1 with a match at creation, but must outlive a deleted match (§2.5). stream_channel_id links the Postgres row to the Stream Chat channel.
thread_participants
thread_id (FK), user_id (FK), role (member / guardian_observer), joined_at
Replaces the previous “participant_ids (2x FK)” field, which is not expressible as a real foreign key. This junction table is what the RLS policy in §5.6 reads. role = guardian_observer is the read-only guardian seat on a minor-to-adult thread (§15.3) — it grants SELECT on messages and never INSERT.
thread_settings
thread_id (FK), user_id (FK), messages_muted (bool, default false), checkin_nudges_muted (bool, default false)
Home for the per-thread notification controls (§2.5). Two independent flags, per (thread, user), never global and never visible to the other participant. messages_muted was added in this revision alongside the founder’s decision to allow chat-message muting.
messages
id, thread_id (FK), sender_id (FK), type (text/template_share/session_proposal/checkin_nudge), payload (jsonb), sent_at
type drives which structured card renders client-side. For non-text types the payload holds an identifier only (e.g. session_proposal_id), never a copy of the schedule or log state — see §2.5.
clubs
id, name, description, organizer_label, qr_code (unique), organizer_id (FK), show_leaderboard (bool, default false)
qr_code is the club-QR identifier. show_leaderboard is the organizer-controlled per-club flag behind the “Top athletes” list (§2.14), default false.
club_memberships
club_id (FK), user_id (FK), joined_via (discover/qr_scan/invite_code/minor_safe_route), joined_at
Junction table. joined_via records whether minor-safe routing applied.
club_events
id, club_id (FK), title, starts_at (timestamptz), timezone (text), location_label, capacity (int, nullable), created_by (FK users), cancelled_at
ADDED. §2.2’s organizer-posts / members-RSVP model needs a real event entity — a club has many upcoming sessions, and a capacity is what makes a waitlist meaningful. Store timezone explicitly; the UI always shows it.
club_event_rsvps
club_event_id (FK), user_id (FK), status (going/waitlisted/cancelled), waitlist_position (int, nullable), created_at
ADDED. The waitlist promised in §2.2. When capacity is reached, new RSVPs become waitlisted with an ordered position; a cancellation promotes the lowest-numbered waitlisted row inside one transaction.
4.3 · Plans, sessions, templates & logging
Entity
Key fields
Relationships / notes
plans
id, owner_id (FK), activity_type (run/lift/ride/other), other_label, label, recurrence (one_time/recurring), day_of_week, start_time, timezone, end_condition (open_ended/after_n_weeks), weeks_remaining, linked_template_id (FK workout_templates, nullable)
One user’s training plan; may have 0..N partners. linked_template_id now resolves to a real table (it previously did not).
plan_partners
plan_id (FK), user_id (FK), status (invited/confirmed/declined), dismissed (bool)
Junction table — many partners per plan (§2.4). dismissed is per-plan-attachment only, never a global exclude.
sessions
id, plan_id (FK, nullable), club_event_id (FK, nullable), activity_type, starts_at (timestamptz), timezone, status (agreed/completed/cancelled), created_by (FK users)
ADDED. A single agreed occurrence — what a 1:1 proposal resolves into, what a plan reminder points at, and what a check-in ping belongs to. checkin_locations.session_id now resolves here (it previously did not).
session_participants
session_id (FK), user_id (FK), rsvp_status (invited/confirmed/declined), checkin_opt_in (bool, default false)
ADDED. checkin_opt_in is the per-session opt-in §2.11 requires — it is not a profile-level setting.
session_proposals
id, plan_id (FK, nullable), proposer_id (FK), recipient_id (FK), proposed_start (timestamptz), timezone, status (proposed/accepted/declined/superseded), created_at, resolved_at, session_id (FK sessions, nullable)
ADDED. §2.2’s peer-overlap 1:1 scheduling: each side proposes windows; an accepted proposal creates the sessions row and back-fills session_id. This is what the chat session-proposal card reads.
workout_templates
id, owner_id (FK users), name, summary, activity_type, source (own/received), received_from_user_id (FK, nullable), created_at
ADDED. Templates are a confirmed feature in two places — linked plan templates (§2.2) and templates shared via chat (§2.5) — and previously had no table at all. Accepting a shared template COPIES it into the recipient’s own rows; it is never a shared reference.
template_sets
id, template_id (FK), position, exercise, target_detail
ADDED. The pre-filled target rows a template carries (“Bench Press · 120 lb × 8 × 3”).
activity_logs
id, user_id (FK), plan_id (FK, nullable), session_id (FK, nullable), template_id (FK, nullable), source (manual/live_gps/auto_sync), provider (healthkit/aggregator/strava, nullable), external_activity_id (nullable), activity_type, other_label, title, started_at, ended_at, duration, distance, avg_pace, cadence, avg_hr, max_hr, calories, notes, confirmed (bool), logged_at
The atomic per-activity record (§2.3). auto_sync rows originate from the HealthKit/aggregator pipeline; make (user_id, provider, external_activity_id) unique so the same workout arriving from two sources is not double-counted (§2.12). confirmed backs the “Looks right / Confirmed ✓” step that also triggers auto-reconcile.
activity_sets
id, activity_log_id (FK), position, exercise, detail
ADDED. §2.3 requires a lift card to expand into individual sets that are NOT their own top-level items — that needs a child table, which the previous revision omitted.
activity_photos
id, activity_log_id (FK), storage_path, created_at
ADDED. Photos attach to any activity (§2.3). Store in a Supabase Storage bucket with its own access policy, not as blobs in Postgres.
4.4 · Safety, verification & platform
Entity
Key fields
Relationships / notes
relationship_sessions
user_a_id (FK), user_b_id (FK, stored with a < b so the pair is canonical), sessions_all_time, sessions_last_30d, last_session_at, computed_at
The single source of truth for “N sessions logged together” — it backs BOTH §2.7’s Together & clubs card and §2.14’s personal standing list, on both ranking bases. There must not be a second counter; if the profile figure and the standing figure can ever disagree, the feature is broken.
leaderboard_settings
user_id (FK), visibility (off / matches_and_clubs / public, default matches_and_clubs)
Backs the personal “Standing” card AND the total training-partner count on the profile (§2.7) — one control governs both, deliberately, rather than two overlapping privacy toggles for closely-related social-proof numbers. public must be rejected for any account whose age_status is minor — enforce as a CHECK or trigger, not only in the UI.
partner_counts
user_id (FK), active_partner_count, computed_at
ADDED. Materialized total training-partner count for §2.7, recomputed server-side on match creation, deletion, and ban. Counts only status = matched rows that are not soft-deleted and whose counterparty is not banned; pending rows never count. Exists so the client can be handed a number without ever being handed the match rows behind it.
club_member_counts
club_id (FK), active_member_count, computed_at
ADDED. Materialized member count for a club page (§2.14). Excludes banned accounts and departed members. Distinct from the per-session RSVP “going” figure, which is computed from club_event_rsvps.
club_leaderboard_opt_outs
club_id (FK), user_id (FK), created_at
ADDED. A member’s individual opt-out from one club’s board, independent of the organizer’s show_leaderboard flag. Presence of a row means excluded, applied retroactively.
club_standings
club_id (FK), user_id (FK), sessions_all_time, rank_all_time, sessions_last_30d, rank_30d, window_end, computed_at
Materialized ranking for §2.14, recomputed on a schedule. BOTH ranks are real ranking bases and both are materialized — rank_30d is no longer a display-only figure. window_end records the end of the rolling 30-day window the monthly figures were computed against, so a stale recompute is detectable. Ranks are computed here, server-side; the client never receives other members’ raw counts on either basis (§5.9).
minor_adult_matches
id, minor_user_id (FK), adult_user_id (FK), match_id (FK), formed_via (qr_scan / club_invite), shared_club_id (FK — required, since a shared club is a precondition), reviewed (bool, default false), reviewed_by (FK, nullable), created_at
ADDED. Every match between a minor account and an adult account writes a row here for trust-and-safety visibility (§15). This is a reviewable queue entry, not a block — the match is live immediately. Readable only by the trust-and-safety role.
filter_presets
id, user_id (FK), name, filter_state (jsonb)
Saved Discover filter snapshots (§2.1). Also persist the user’s CURRENT filter state (a single row per user, or a column on profiles) so filters survive an app restart.
custom_tags
id, label (unique, canonical), created_by (FK users, nullable), first_seen_at, usage_count
Backs the fuzzy-tag-matching pool (§2.1). Note the correction: the previous revision’s similarity_score column was wrong — similarity is a per-comparison result, not a property of a canonical tag. Uniqueness on label is what actually prevents near-duplicate tags splitting the matching pool.
tag_match_settings
user_id (FK), match_threshold (default 0.60), suggest_threshold (default 0.45), accepts, rejects, updated_at
ADDED. The self-tuning thresholds in §2.1 are per-user learned state. The wireframe holds them in memory only; a real build must persist them or the feature resets on every launch.
verification_records
id, user_id (FK), tier (liveness/id_selfie), provider (stripe_identity), status, verified_at, provider_reference_id, age_check_result (adult/minor/inconclusive)
Never store raw ID images/biometrics directly — reference the provider’s own record. age_check_result is the derived 18+/under-18 outcome (§2.8); the date of birth itself is not stored.
reports
id, reporter_id (FK), reported_id (FK), reason, free_text, status (under_review/actioned/dismissed), reviewer_id (FK, nullable), action_taken, created_at, resolved_at
Drives §2.10; the highest-sensitivity table alongside checkin_locations.
checkin_locations
id, session_id (FK sessions), user_id (FK), lat, lng, recorded_at, purge_after (recorded_at + 30 days)
The single most access-sensitive table — see §5’s location rule. session_id now resolves to a real table. Purge job removes rows past purge_after.
push_tokens
id, user_id (FK), platform (ios/android), token, device_id, created_at, last_seen_at, revoked_at (nullable)
ADDED. Push is a confirmed launch requirement (§2.13) and previously had nowhere to live. Unique on (user_id, token). Revoke rather than delete on an APNs/FCM “unregistered” response. A user’s tokens must be readable only by that user and the server role.
notification_settings
user_id (FK), plan_reminder_offset_minutes (default 60), quiet_hours_start, quiet_hours_end
ADDED. Small, but §2.13 makes the plan-reminder offset a per-user setting.

5. Key Safety / Access-Control Rules (audit-critical)
These rules must be enforced at the database layer via Postgres Row-Level Security (RLS) policies, not only in application code. Per round 20's explicit guidance, the fixed-scope post-build audit exists specifically to verify these rules — they are the do-not-cut surface of this entire project. Design and implement them carefully the first time; do not treat this list as something the audit will “catch later.” §12 turns every rule below into a concrete, runnable test.
5.1 · Location data (checkin_locations)
Readable only by the two participants in that specific session, in real time, plus a small, explicitly named trust-and-safety role — never default/general engineering access.
When a report is filed (§5.4), the retained location window for that time period becomes accessible to the trust-and-safety reviewer as part of that specific investigation — logged, case-scoped access, not standing visibility into anyone's location history.
Enforce the 30-day purge of precise coordinates at the database level (a scheduled job or RLS-adjacent policy), not only as an application-layer convention.
Column-level encryption should be evaluated for precise lat/long specifically, given the VCDPA's “sensitive data” classification for precise geolocation.
The live-map visibility window (profiles.live_map_visible_until) is part of this surface: a person’s pin must disappear from every query the moment that timestamp passes, enforced in the query/RLS layer rather than by the client hiding it.
5.2 · Reports
A report row must be readable only by: the reporter (their own submission), the reported user's account should NEVER see who reported them or the report content, and the trust-and-safety reviewer role.
A report's status transition to “actioned” (ban) must be the trigger that flips the reported user's is_banned flag — make this atomic (a single transaction or a database trigger), not two separate application calls that could race or partially fail.
5.3 · Verification & biometric data
Never store raw ID images, selfies, or biometric templates in your own database — store only Stripe Identity's verification result/reference ID and a boolean/tier outcome. This is both an RLS and an architecture rule.
The same rule applies to the date of birth returned by an ID check: derive and store the adult/minor outcome, discard the DOB itself. Stripe already gates DOB access behind a restricted API key with a 48-hour window, which is a strong hint about how it should be handled (§2.8).
verification_records rows readable only by their own user and a verification/compliance role.
5.4 · Banned-user exclusion
A banned user (is_banned = true) must be excluded from every Discover query, every Matches list, and every new-match/QR-scan creation path — enforce this as a WHERE-clause-level or RLS-level filter on the query surface itself, not as a UI-layer hide, so a banned account cannot appear via any code path, including ones written later.
“Every query surface” explicitly includes the Discover map-pin query and the personal-QR lookup — both are separate code paths from the Discover list and both must exclude banned accounts.
Verify end-to-end: report → ban → excluded from every list, for every account-facing query in the schema, as part of the post-build audit's test suite (§12).
5.5 · Age status, fail-closed defaults & minor routing
age_status must default to unverified, never to adult, for any newly created or ambiguous account. An RLS policy (or equivalent query guard) must block Discover access for unverified and for minor, and must block person-to-person QR scanning for unverified.
Club-QR join and invite-code redemption are the only surfaces permitted for an unverified account — encode this exception explicitly and narrowly.
Person-to-person QR is permitted for a minor account (§2.6, founder decision). It remains blocked for unverified. Whatever safeguards from §15 the founder adopts must be enforced at the query/action layer, not in the UI — the test for each is to call the underlying action directly with a minor account’s token and confirm it is refused.
Age status must only ever be written server-side, by the signup handler or the identity-verification webhook (§2.8). No client-writable path to age_status may exist — the wireframe’s cycle-account-state control is a demo affordance and must not be built. Setting leaderboard_settings.visibility to public must be rejected for a minor account at the same layer.
A downgrade to minor is sticky: once an ID check returns an under-18 result, the account cannot be re-verified into adult by a subsequent attempt without human review.
5.6 · Chat data
Message rows readable only by the thread's two participants (via thread_participants, §4.2).
A deleted match must not cascade-delete the chat_threads or messages rows — confirm the deletion logic only touches matches/plan_partners state, per §2.5's archived-chats requirement. Explicitly: chat_threads.match_id must be ON DELETE SET NULL, not ON DELETE CASCADE.
Stream Chat has its own access model. Channel membership tokens must be minted server-side (a Supabase Edge Function) from the same thread_participants source of truth, so a user can never be granted a Stream channel they have no Postgres row for.
5.7 · Push tokens
push_tokens rows readable and writable only by their own user and the server role. A push token is a device identifier — treat it with the same care as a session token.
5.8 · Minor accounts: location and visibility (hard rules)
NEW IN THIS REVISION — New. The wireframe happens to omit the live-map card from the minor Profile variant, but no revision of this brief ever stated it as a rule — so a build session reimplementing Profile from the spec would have added it back. Check-in location sharing was never excluded for minors anywhere.
A minor account can never appear on the live map. profiles.live_map_visible_until must remain null for any account whose age_status is minor, enforced server-side; the “Show on live map” card does not render on a minor Profile; and the map-pin query must exclude minors unconditionally, independent of that column.
A minor account can never share check-in location. session_participants.checkin_opt_in must be false for a minor, and no checkin_locations row may be written for or about a minor account. The checkin_nudge push event never fires in either direction for a session that includes a minor.
These two rules hold regardless of what the founder decides about §15. Precise or near-precise location sharing between a 13-year-old and anyone else should not exist in v1, and the decision to allow minor person-to-person matching does not change that.
A minor’s profile is never returned by any Discover query — list or map — to any account, in either direction. A minor neither browses Discover nor appears in it.
5.9 · Leaderboards
Ranks are computed server-side on both bases — all-time and rolling 30-day — and both are materialized. A client request for a board returns only the rows that board displays, for the requested basis: display name, rank, and the stat, and only for members whose leaderboard_settings.visibility permits that viewer. Never return the underlying per-member session counts for the client to sort, on either basis. Switching the This month / All time toggle is a new server request, not a client-side re-sort of data it already holds.
A board query must apply, in order: the club’s show_leaderboard flag; the member’s club_leaderboard_opt_outs row; the member’s visibility setting relative to the viewer; and the banned-user exclusion in §5.4. A member who opts out disappears from every other member’s view of the board immediately.
A minor’s standing is visible only to fellow members of that same club. It is never returned to a viewer who does not share the club, and public visibility is not a permitted value for a minor account.
The personal standing list reads from relationship_sessions, the same row that supplies §2.7’s profile figure. A viewer only ever sees rows for relationships they are themselves part of — a person’s standing list is never readable by a third party, even one permitted to see their club standings.
The total training-partner count (§2.7) and the club member count (§2.14) are returned as totals only. The endpoint that serves a count must never accept a parameter that would expand it into the underlying rows, and must not be implemented as a client-side length of a fetched match list. A count is social proof; a list is a social graph, and the two must not be the same request.
A person’s partner count obeys leaderboard_settings.visibility — the same control as Standing. When visibility does not permit the viewer, the count is absent from the response entirely rather than returned as zero or null, so its absence cannot be distinguished from a genuinely private profile.
A minor’s partner count is returned only to the minor themselves, their linked guardian, and viewers who share a club with them. It is never returned to any other account, regardless of match status.
Counts exclude soft-deleted matches, pending matches, and any match whose counterparty is banned. Banning an account must therefore trigger a recompute of partner_counts for every account it was matched with, in the same transaction as the ban (§5.2) — a banned user disappearing from a list but still inflating a former partner’s total is a visible leak of the ban.
A club member count excludes banned and departed members and is public to anyone who can see the club. Minor members are included in the total but must not be individually enumerable from it or from any adjacent endpoint.
5.10 · Guardian access & minor consent state
NEW IN THIS REVISION — New, alongside the parental-consent mechanism in §15.2.
consent_status is writable only server-side, by the signup handler and the guardian-consent handler. No client path may set it, exactly as for age_status.
A pending or revoked minor account must be refused by every data-bearing query surface listed in §15.2 — Discover, QR in both directions, invite-code redemption, messages, plan-partner attachment, club rosters, and every board. Enforce as RLS predicates on those relations, not as an application-layer check, so a code path written later inherits the restriction.
A guardian may read a minor-to-adult thread’s messages only through a thread_participants row with role = guardian_observer, and that role must never grant INSERT. A guardian has no read access to any minor-to-minor thread, to activity_logs detail, activity_sets, activity_photos, or to checkin_locations (which never exist for a minor anyway, §5.8).
guardian_links and guardian_connection_approvals are readable by the linked guardian, the linked minor, and the trust-and-safety role. No other account may read them, including the adult party to a pending connection — an adult must not be able to enumerate which minors have guardian approval pending.
guardians rows are readable only by that guardian and the compliance role. A guardian’s identity-verification record follows §5.3 exactly: store the provider reference and the outcome, never the document or the date of birth.
Revoking a guardian link must, in one transaction, set consent_status to revoked, deactivate every minor-to-adult match for that minor, and remove the guardian’s thread_participants rows. Partial application of that set is a defect.
The consolidated gate in §15.9 is the only path that may create a match involving a minor. Enforce with a database-level constraint or trigger if practical, so a future code path cannot bypass it by inserting into matches directly.

6. Confirmed Architecture / Vendor Stack
The client-framework row below is refined in §13, which resolves the Expo-versus-bare-React-Native question the previous revision left open.
Layer
Choice
Why (see Playbook for full research)
Client
React Native, native mobile (iOS-first) — specifically Expo with a development build; see §13
Single codebase for iOS/Android; mature libraries for camera/QR, HealthKit/Health Connect, background location, push, and the Stripe Identity SDK; best-represented framework in AI coding assistants’ training data.
Backend / DB
Supabase (managed Postgres + Row-Level Security)
RLS puts safety-critical access control in the same auditable, relational place a moderation console needs — the deciding factor over Firebase/Firestore. Free tier (50K auth MAU, 500MB DB) covers pilot scale; Pro ($25/mo) as the realistic near-term tier.
Server-side logic
Supabase Edge Functions
Where anything that must not run on a phone lives: Stripe Identity webhook handling and the age_status write (§2.8), Stream Chat user-token minting, push fan-out, and the 30-day location purge job.
Real-time chat
Stream Chat
Purpose-built structured-message/attachment system for plan-share, session-proposal, and check-in-nudge cards; built-in AI-assisted moderation. Free “Build” tier (1,000 MAU / 100 concurrent connections) covers pilot scale; Start tier (~$399–499/mo) once concurrent usage or moderation needs grow past that.
Identity verification
Stripe Identity
Self-serve, open-source React Native SDK, $1.50/verification with no minimum — best fit for pay-as-you-go pilot volume. Veriff is the documented fallback if verification volume grows faster than expected.
Wearable data aggregator
Spike (confirmed September 2026; Terra is the documented fallback)
Normalizes HealthKit + Garmin (and future Whoop, etc.) behind one API. ~$450/mo fixed cost, no free tier — budgeted as a required pilot cost given the Rosslyn-Ballston running community’s actual (Garmin-majority) device mix. Spike was selected over Terra on the Expo criterion in §13.2: it ships a first-party Expo config plugin with its own documentation page. See §2.12 for the two-path integration architecture this implies.
Health data (direct)
Apple HealthKit (+ Google Health Connect for Android parity)
No partnership approval needed; standard App Store review only. Serves the iPhone-only minority directly, alongside the aggregator.
App distribution
Apple Developer Program (already active) + Expo EAS Build/Submit
$99/yr, already sunk. EAS handles signing, build, and TestFlight upload without hand-managing certificates — and, critically, without a Mac (§16.2). EAS Build: free tier gives 15 iOS + 15 Android builds/month on a low-priority queue; Starter is $19/mo for high priority and $45 of credit. Budget $19/mo during native-heavy phases (§16.3). Google Play Developer ($25 one-time) only if/when an Android launch is added.
Push notifications
Expo Notifications on top of APNs/FCM
Free at any realistic pilot volume. Six events, specified in §2.13.
Hosting / misc
Domain registrar, Sentry (error monitoring), a transactional email provider, CI (GitHub Actions)
Free tiers realistically cover pilot volume; ~$20–40/mo all-in once any paid tier is needed.
7. Build Sequencing
Code build order, not calendar weeks — see the Playbook (Section 11) for the calendar-mapped version of this same sequence, targeting a pilot launch in late Feb–mid-March 2027. Fifteen phases. Treat each numbered item as one working phase: build it, verify it against §12, commit it, and only then start the next.
Project setup and native-dependency proof — create the Expo project with a development build, wire the repo, and get a blank app running on a real iPhone (Vendor Setup Guide §0, written for Windows). Then, before ANY feature work: install every native dependency the project will ever need — expo-camera, expo-location, expo-task-manager, expo-notifications, the HealthKit library, the Spike SDK and its Expo config plugin, and Stripe Identity with its custom plugin — and prove they all compile together in a real EAS build. This is the single highest-value hour in the schedule. On the founder’s Windows machine there is no local iOS compile: every native config error is a 10–25 minute cloud build round trip, and one discovered at phase 9 can cost days that the same error at phase 1 costs minutes. Do not proceed until a build containing all of them succeeds (§13.4, §16.5).
Auth + profiles + RLS foundation — stand up Supabase, wire Supabase Auth (email + phone), build the sign-in/sign-up screen as the app’s first screen (an account is required for the entire app, §3), create the users/profiles schema, capture date of birth at signup and implement the four-state age model (§2.8), and write the core RLS policies for age_status fail-closed behavior, minor location exclusion, and banned-user exclusion (§5.4, §5.5, §5.8) before building any feature that depends on them. Getting this right first is cheaper than retrofitting RLS onto features already built without it.
Parental consent & guardian linkage — the 13–17 signup fields, the platform age-signal read (Apple Declared Age Range / Google Play Age Signals), the guardian invitation, the guardian account and verification step, the consent state machine, and the fail-closed restrictions for a pending minor (§15.2). This lands early, immediately after auth, because consent_status gates almost every other surface and retrofitting it later means revisiting every query written in between.
Design system — implement the tokens in §10 once (the Harbor tokens including --pal-on-accent and the danger/caution extension, the confirmed type scale, Lucide icons, the motion defaults, spacing, radii, and the card / chip / pill-button / status-dot primitives) before building screens, so every later screen composes from the same parts instead of restyling from scratch.
Matching & Discover — the filter panel (all 10 filters), rule-based scoring, the request/approval match-state machine, saved presets, the list AND map views (the map is confirmed in scope for v1, §2.1), and the fuzzy-tag matching pool for custom activity labels.
Chat (Stream Chat integration) — wire the SDK, mint user tokens server-side, build the three structured message card types (template share, session proposal, check-in nudge), and the archived-chats behavior for deleted matches.
Scheduling & plans — 1:1 propose/overlap scheduling, club events and RSVP/waitlist, recurring/end-condition logic, multi-partner plans with status tracking, and linked templates.
Logging — manual entry, live GPS recording (foreground-only first), the activity_logs/activity_sets data model with activity-appropriate card depth, and the Activity-versus-Log tab split (§2.3).
QR instant-match system — personal + club QR generation (including rotating, display-only codes for minors), the scan flow with enforced scan direction, the typed invite-code path, the mutual-confirm step, the one-tap club-join path, the consolidated minor-safety gate in §15.9, guardian per-connection approval, guardian thread observation, the review queue and the rate limit. All of §15 is in scope for this phase; none of it is pending a decision. Retest §5.5, §5.8 and §5.10 specifically against this entry path.
HealthKit / Garmin integration (aggregator) — direct HealthKit integration plus the Spike aggregator for auto-reconcile (both paths — the Expo config plugin for on-device Apple Health, and the server-side Garmin webhook, §2.12), including de-duplication; this is flagged in the Playbook as needing real lead time for vendor onboarding, so start the aggregator’s own account/API setup (see the companion vendor setup guide) as early as practical, even if the code integration itself lands here in sequence.
ID + photo verification — Stripe Identity SDK integration, the tiered liveness-vs-full-ID gate logic, the age_status transition webhook (§2.8), and the verification_records schema (never storing raw biometric data, per §5.3).
Push notifications — device token registration, the six events in §2.13, deep links, and mute handling.
Leaderboards — the club “Top athletes” board behind the organizer flag, the per-member opt-out, the personal standing list built on relationship_sessions (the same counter §2.7 already shows), the This month / All time toggle, the scheduled computation of BOTH rank bases, the profile partner count and club member count with their server-side-total-only rule, and the visibility rules in §5.9 (§2.14).
Reporting & safety — the report flow, the reports schema and its RLS policies (§5.2), the ban-trigger logic, the minor-adult match review queue (§15), and end-to-end verification that a banned account is excluded from every query surface (§5.4).
Polish, independent code/security audit, TestFlight beta, App Store submission — the fixed-scope RLS/auth audit (round 20’s floor-budget item) happens here, before or alongside the TestFlight beta; address findings before submission. See the Playbook’s App Store submission section for the specific rejection risks (location justification, health-data usage strings, minor-safety/UGC moderation) to address in the submission notes.
8. Open Items for the Founder or Post-Build Audit
Carried forward from the Playbook — real, deliberate open decisions, not oversights. Revisit each once its stated trigger is met. §14 adds the decisions this revision surfaced, which need answers before the build starts rather than after.
Scan-rate limiting on personal QR codes — explicitly deferred pending real usage data (any outlier scan pattern suggesting a code was posted publicly).
Rotating/short-lived QR tokens — reconsider only if real screenshot-sharing or code-farming abuse is observed post-launch; static codes are the deliberate v1 choice otherwise.
Moderation vendor/staffing selection — founder reviews reports personally at pilot scale; outsourcing/vendor selection is a real next step once volume exceeds what one person can review, with no vendor or user-count trigger pinned down yet.
Un-defer trigger check for the wearable aggregator is now moot — round 21 confirmed it as a required v1 dependency, not deferred. (Kept here only to note the reversal explicitly, so a build session doesn't inadvertently treat it as optional based on older round-20 language it may encounter elsewhere.)
Insurance policy activation — broker conversation should start early, but the BOP/Tech E&O policy itself should bind right before public pilot launch, not before (a timing decision, not a scope one — see the Playbook's budget section).
Final attorney sign-off on the drafted ToS, Privacy Policy, and Assumption of Risk & Liability Waiver (produced round 19) — required before any real user ever sees these documents or is gated by them.
SQL/Postgres team-skill conversation — if the actual build team's comfort level with Postgres/RLS turns out to be lower than assumed, that's worth flagging to the post-build audit engineers explicitly rather than discovering it during the audit itself.

9. Screen Inventory & Navigation Map
NEW IN THIS REVISION — Entirely new. Extracted from mobile-preview.html. The previous revision described features but never listed the screens, so a build session had no way to know how many surfaces exist or how they nest.
9.1 · Navigation structure
An unauthenticated entry flow, then a persistent five-tab bottom bar. An account is required for the entire app (§3), so the sign-in / sign-up screen is the app’s first screen and no tab is reachable before authentication. Once signed in the tab bar is always visible — including over detail screens and the scan overlay. Sub-screens push over the active tab and get a back arrow in the header; there is no separate navigation stack per feature, no drawer, no side menu, and no modal sheets in v1.
Tab
Header title
Contents
Discover
“Discover”
The browse/match surface. Gated: sign-in gate → age gate → content. Sub-screens: person detail, club detail, filter panel (inline), scan overlay.
Matches
“Matches”
Training partners, clubs you’ve joined, archived chats. Sub-screens: chat thread, person detail, club detail.
Activity
“Activity”
Everything forward-looking (today’s plan, upcoming plans, scheduling) plus the two present-tense logging actions (start live, log manually). Sub-screens: live-activity pick, live-activity record.
Log
“Log”
History only — the auto-synced card and the expandable recent-activity list. No logging actions here.
Profile
“Profile”
Own profile, three variants by age status. Sub-screen: scan overlay.

Navigation rules
The header carries a two-line block (small eyebrow + large title) and shows a back arrow only when a detail screen, a chat thread, a live activity, or the scan overlay is open.
Person detail is reachable from the Discover list, a Discover map pin, and the Matches list; it always renders with the header title “Profile”. Club detail renders with the header title “Club”.
Back from a chat thread goes to Matches, regardless of where the thread was opened from.
Switching tabs clears: the open detail screen, the scan overlay, an in-progress live activity, the plan-partner search context, and any in-progress schedule draft. It deliberately does NOT clear the Discover filters (§2.1).
The scan overlay is a full-screen flow layered over whichever tab was active, with its own back button; completing a club scan lands the user on Matches → that club’s detail.
The live-activity flow is two screens deep inside Activity: a type picker (header “Start Activity”) and the recording screen (header “Recording · Run”).
Signing out returns to the authentication screen, not to a signed-out version of a tab. There is no signed-out state of any tab to return to.
Discover’s two gates are now the only gates inside a tab: the age gate (minor or unverified) and nothing else. The wireframe’s sign-in gate inside Discover is removed — that check has moved to the app’s entry flow.
9.2 · Full screen list
Thirty distinct surfaces. Gate screens and inline panels are listed separately because each has its own copy, its own states, and its own access rule.
Screen
Reached from
Key elements and states
0a. Sign in / Sign up
App launch, when no session exists. The app’s first screen.
Groundwork mark; “Continue with email” and “Continue with phone”; a link to switch between sign-in and sign-up. No content of any kind is visible behind or before it. An account is required for the entire app.
0b. Date of birth
Sign-up, immediately after credentials
A date picker, not a checkbox. Under 13 is refused with an explanation. 13–17 sets age_status = minor; 18+ sets self_attested_adult (§2.8). This screen cannot be skipped or dismissed.
0c. Guardian details
Sign-up, when the date of birth is 13–17
Guardian first and last name, email, and mobile number — all required. Explains in plain language what will be sent to them and why. Cannot be skipped (§15.2).
0d. Profile setup
Sign-up, after date of birth (and guardian details for a minor)
Display name, primary sport tags, and optional avatar. Minimal — everything else is editable later on Profile.
0e. Consent pending
Any app launch by a minor whose consent_status is pending or revoked
The only screen a pending minor can reach beyond their own profile and log. Shows status, who was contacted, a re-send action, and the 14-day and 30-day deadlines. Fail-closed (§15.2).
1. Age gate
Discover, when age_status is minor or unverified
Two copy variants: “Discover is 18+” (minor) and “Age not verified yet” (unverified). Both offer “Scan a club’s QR code” and “Go to Profile → Join via invite code”.
2. Discover · People · List
Discover tab
People/Clubs segmented control; Scan button; list/map icon toggle; optional plan-context banner; result count line; Filters button with active-filter count; person cards; empty state.
3. Discover · Clubs · List
Discover tab
“Upcoming · organizer posts, you RSVP” label; club cards with name, when/where, going count, RSVP / “Going ✓” toggle.
4. Discover · Map
Discover list/map toggle
CONFIRMED IN SCOPE for v1. Map canvas; live-visibility badge (“Live · within 1 mi · you’re visible now” / “…you’re not visible (Profile to turn on)”); --pal-a pins for people, --pal-b pins for clubs, a neutral pin for self only while the live-map window is active; every pin taps straight through to that person’s or club’s detail screen. Banned users and minor accounts are excluded from the pin query (§5.4, §5.8).
5. Filter panel
Inline, inside Discover · People
Saved-presets row with a Manage mode (rename ✎ / delete ✕); seven chip rows each with an “Any” option; three dashed toggle pills; “Clear all filters”.
6. Person detail
Discover list/map, Matches, chat
Name, location, verification badges, tags, blurb; total training-partner count (“14 training partners”), subject to the viewer’s permission; “The journey so far”; “Training profile”; “Together & clubs”; “Usually free”; mutual line; optional “Reported by you · under review” pill; three-state match button; optional “+ Connect for <plan>”; “Delete match” when matched; “Report <name>”.
7. Report panel
Inline, on person detail and in chat
Four reasons as radio rows, optional free-text field, Cancel / Submit report. Submit is disabled until a reason is picked.
8. Club detail
Discover, Matches, scan
Name, organizer line, description, member count (“24 members”), “Upcoming sessions” card, per-session going count, optional “Top athletes” leaderboard with a “Shown by organizer” chip and a This month / All time toggle defaulting to This month, club QR block, RSVP button.
9. Matches
Matches tab
“Training partners” (Message + Delete match), “Clubs you’ve joined”, “Archived chats” (“Match deleted · thread kept” + Open), and an empty state.
10. Chat thread
Matches, archived chats
Privacy note; text bubbles; template-share card; session-proposal card; check-in nudge card with mute; muted-state pill; report link/panel; composer bar.
11. Activity
Activity tab
Today’s plan card (type chips, label, linked template, history strip, primary + secondary actions, partner chips, find-a-partner); Upcoming plans list; quick-action row; “Direct scheduling” card; explanatory note card.
12. Plan schedule editor
Inline, on an upcoming plan card
Day chips, time slider, Recurring weekly / One time only, Ends: Open-ended / End after N weeks with a stepper, Cancel / Confirm.
13. Manual entry panel
Inline, in Activity
Type chips; “Other” free-text with an anchored autocomplete dropdown and the match-sensitivity note; pending-shared-template banner; template list; prefilled target rows with Clear; +Photo / +Note; Save.
14. Live activity · pick
Activity → Start live activity
Three cards: Run, Bike Ride, Other (with “Duration only — no distance or pace tracked”).
15. Live activity · record
Pick screen, or a plan’s Start live activity
Recording/Paused indicator; GPS pill (Acquiring / Weak / Strong); weak-signal warning with “Log manually” escape; “Following today’s plan” card; large elapsed timer; Distance + Avg pace tiles, or a duration tile plus the Other label field; Pause/Resume + Finish.
16. Log
Log tab
Auto-synced card (source + age, “Matches today’s plan ✓” badge, title, partner line, 4-tile metric grid, set rows, +Photo/+Note, “Looks right” → “Confirmed ✓”); “Recent activity · tap to expand” list with per-type expanded detail.
17. Profile · adult
Profile tab
Avatar + name + ID-verified line; sport chips with “+ Add activity”; “Training for”; “The journey so far” with a progress bar; “Training profile”; “Usually free”; My QR code block; “Show on live map” card with the two-flip toggle and auto-off duration chips.
18. Profile · minor
Profile tab, when age_status = minor
Reduced header (“13–17 account · Discover not available”), explanation card, My QR block, joined-via-invite card, “I have an invite code / scanned a QR” → code entry with Cancel / Join.
19. Profile · unverified
Profile tab, when age_status = unverified
Header (“Unverified · treated as under 18 until confirmed”), “Why you’re seeing this” card, My QR block.
20. Scan to connect
Profile, Discover toolbar, age gate
Five steps: pick (camera view; minor/unverified notice banner; personal-code section entirely absent for minor/unverified), club-joined, person-pending (“Code scanned — confirm to match”), person-matched, blocked (with distinct minor and unverified copy).
21. My QR code block
Inline, on all three Profile variants and club detail
QR image, monospace identifier (GW-P-… / GW-C-…), explanatory line, and a “Scan to connect” button. On a minor Profile this block also carries whatever §15 treatment the founder adopts (for example a countdown if codes rotate).
22. Standing card
Inline, on Profile (own and others’)
No wireframe precedent — see §2.14. A This month / All time segmented toggle (defaulting to This month) over two halves: club standings, one chip per qualifying club (“<club> — #3 of 24 · 47 sessions”), and top training partners by sessions together (“Jordan M. · 42”). Both halves switch basis together. The partner figures are the same relationship_sessions counter §2.7 already displays. Renders nothing at all when the viewer is not permitted, rather than an empty state.
23. Leaderboard settings
Profile → settings
Visibility control (off / matches and clubs / public) plus a per-club opt-out list. This one control governs BOTH the Standing card and the total training-partner count on the profile — there is deliberately no second privacy toggle. public is not offered on a minor account.
24. Thread notification settings
Inline, in a chat thread
Two independent toggles — Messages and Check-in nudges — both default on, scoped to that thread (§2.5).
25. Guardian consent (guardian side)
The emailed / texted invitation link
Guardian-facing, outside the minor’s session. Names the minor, explains plainly that the app arranges in-person training meetups, then account creation, the Stripe Identity verification step, the consent statement, and the initial controls (§15.2).
26. Guardian dashboard
Guardian’s own account
The minor’s connections with adults flagged, pending connection approvals, club memberships, upcoming session schedule with time and place, the two control toggles, and revoke consent (§15.4).
27. Minor-to-adult confirm
A minor-to-adult QR scan, after every gate in §15.9 passes
Deliberately higher-friction than the adult-to-adult confirm. Names the adult, states that they will be able to message and schedule meetups, states that the guardian can read the conversation, and requires explicit acknowledgment (§15.7).

10. Visual Design Language — “Middle Distance” system, Harbor palette
NEW IN THIS REVISION — Replaced wholesale in this revision. The previous §10 was reverse-engineered from the wireframe’s CSS. It is superseded by the approved visual design system reproduced below, which resolves the Patrick Hand question that was previously an open item.
10.0 · Precedence, and what this supersedes
This section is authoritative on color, type, and component tokens. The wireframes (mobile-preview.html and the canvas source) remain authoritative on screen layout, navigation, and interaction flow. Re-skin their structure with these tokens; do not redesign layouts from scratch.
Explicitly superseded, so a build session reading the wireframe CSS does not reintroduce them: the wireframe’s accent #FF5A2E, its teal #0E6E5C, its ink #1A1A1A, its paper background #F6F5F2, and the entire “Patrick Hand” handwriting display face. None of those values ship. The wireframe’s 1.5px hand-drawn ink outlines are also superseded by the 1px --pal-line card border below. Where the wireframe uses a color semantically — accent for the primary action, teal for confirmed/success, red for destructive — map that role onto the Harbor token that carries the same role, rather than matching the old hex.
Every value below was pulled from the working mockups approved during the Harbor color-story review (light and dark, four palettes × three sample cards each). Values that the mockups did not establish — the numeric type scale, the icon set, motion, the app icon and the on-accent token — have all since been resolved and are marked as confirmed below.
10.1 · Direction summary
The system is called “Middle Distance”: warm and human enough to feel inviting before a first meetup, structured and legible enough to carry real training data — pace, heart rate, splits — without feeling clinical. It replaced two earlier explorations, one too sharp and angular, the other too soft, by building the mark directly out of the product’s own data vocabulary (§10.4) rather than an abstract geometric or organic shape.
“Harbor” is the color story chosen from four explored (Sunrise, Trailhead, Harbor, Ember & Gold). It pairs a warm coral with a steel-teal on a warm off-white base in light mode, or a near-black base in dark mode — legible as a fitness and data product, warm enough for a social-matching one.
10.2 · Color tokens
Nine palette tokens plus the adopted --pal-on-accent semantic token, each with a light and a dark value. Implement them as theme tokens scoped to a top-level provider, never as hardcoded hex values inside components. That is what let one set of component code render identically across all four color stories during review, and it is what makes the light/dark switch in §10.7 a token swap rather than a rebuild.
Light mode
Token
Hex
Role
Used for
--pal-a
#F0664B
Primary — Coral
Primary buttons, active states, key numerals, mark (front pill)
--pal-b
#3B7A8C
Secondary — Steel-teal
Secondary data series, complementary accents, mark (rear pill)
--pal-base
#F3F1EA
Base — Chalk
Screen background
--pal-card
#FFFDF9
Card
Card / sheet / modal backgrounds
--pal-line
#E6E0D3
Line
Card borders, dividers, inactive chart bars
--pal-ink
#232C30
Ink
Headlines, body copy, primary UI text
--pal-faint
#8D9296
Faint
Timestamps, meta labels, helper text — large sizes only, see §10.8
--pal-a-tint
#FCE4DC
Coral tint
Pill / badge backgrounds paired with ink-colored label text
--pal-b-tint
#DCEBEE
Teal tint
Pill / badge backgrounds paired with ink-colored label text
--pal-on-accent
= --pal-ink
On-accent (ADOPTED)
Label text on any --pal-a or --pal-danger fill. In light mode this resolves to --pal-ink (#232C30), measuring 4.55:1 on coral

Dark mode
Token
Hex
Role
Used for
--pal-a
#F5806A
Primary — Coral (brightened)
Same roles as light mode; brightened ~4–5% lightness to hold contrast on dark surfaces
--pal-b
#5FA3B8
Secondary — Teal (brightened)
Same roles as light mode
--pal-base
#12171A
Base
Screen background
--pal-card
#1B2226
Card
Card / sheet / modal backgrounds
--pal-line
#333C42
Line
Card borders, dividers, inactive chart bars
--pal-ink
#ECEFF0
Ink
Headlines, body copy, primary UI text
--pal-faint
#8B969C
Faint
Timestamps, meta labels, helper text
--pal-a-tint
#3A2620
Coral tint
Pill / badge backgrounds paired with ink-colored label text
--pal-b-tint
#1C2F34
Teal tint
Pill / badge backgrounds paired with ink-colored label text
--pal-on-accent
= --pal-card
On-accent (ADOPTED)
Label text on any --pal-a or --pal-danger fill. In dark mode this resolves to --pal-card (#1B2226), measuring 6.27:1 on coral

Dark-mode accents are brightened roughly 4–5% in lightness rather than reused directly — that is what keeps coral and teal legible against near-black surfaces without them turning neon.
Mapping the wireframe’s semantic colors onto these tokens: the wireframe’s accent (primary action) becomes --pal-a; its teal (confirmed, verified, success) becomes --pal-b; its ink becomes --pal-ink; its paper background becomes --pal-base; its card white becomes --pal-card; its tinted success and accent backgrounds become --pal-b-tint and --pal-a-tint. The wireframe’s destructive red and amber “Invited” tone had no Harbor equivalent; they are now supplied by the extension tokens in §10.11.
10.3 · Typography
Role
Typeface
Weights
Notes
Display / headline
Outfit
500, 600, 700, 800
Rounded-geometric grotesk. Screen titles, section headers, onboarding headlines, empty-state copy.
Body / UI
Figtree
400, 500, 600, 700 (+ italic 400)
Warm humanist sans. Buttons, labels, nav, chat, profile copy, form fields.
Data / stats
IBM Plex Mono
400, 500, 600
Tabular figures. Pace, splits, heart rate, distances, timestamps, PR values — anywhere two numbers must align in a column.

All three are Google Fonts. Load them via standard platform font loading — in React Native, expo-font with the static font files bundled into the app, not a CDN stylesheet link.
This replaces the wireframe’s Inter + Patrick Hand pairing entirely. Patrick Hand does not ship.
Type scale — confirmed
NEW IN THIS REVISION — Resolved in this revision. The Harbor document offered this scale as a recommendation to be checked against the wireframes. That verification has now been done against mobile-preview.html’s actual rendered sizes; the result and the reasoning are below.
Verification result: the wireframe and Harbor agree on hierarchy and disagree on absolute size. The wireframe uses eight distinct levels in real use, which map one-to-one onto Harbor’s eight, so the structure was already right. But below the section-header level the wireframe runs consistently 2–3px smaller than Harbor proposes — body copy at 12.5–13.5px against Harbor’s 15px, buttons at 12–12.5px against 14px, captions at 10–10.5px against 12px. Those are web-mockup values measured in a 560px-wide column, not native iOS values, and below body level they fall under what iOS treats as comfortably legible. Adopting them literally would ship an app with 10px captions.
Resolution: take the wireframe’s hierarchy and Harbor’s absolute sizes, with three specific exceptions where the wireframe establishes something Harbor does not. This follows the instruction to match the wireframes where they genuinely establish a value, while not carrying across sizes that are artifacts of the mockup medium rather than design decisions.
Level
Wireframe
Harbor rec.
CONFIRMED
Resolution
Live timer
52px
—
44px / 700
Wireframe establishes a full-screen hero numeral that Harbor has no level for. Kept as its own level, trimmed from 52 because Outfit at 700 sets wider than the wireframe’s face. IBM Plex Mono, tabular figures. Full-screen recording only.
Display XL
—
32px / 700
32px / 700
Harbor’s value, unopposed. In-card hero numerals (a PR figure, a headline stat) — distinct from the live timer above.
H1 / screen title
26px
24px / 700
24px / 700
Two pixels apart. Harbor’s value taken: Outfit at 24/700 reads at least as large as the wireframe’s face at 26.
H2 / detail name
19px / 700
17px / 600
19px / 700
WIREFRAME WINS. The person- and club-detail name is a deliberate level the wireframe establishes, it is already above the legibility floor, and flattening it into the section-header size would lose a real step in the hierarchy.
H3 / section header
14–15px / 700
17px / 600
17px / 600
Harbor’s value. The wireframe’s 14–15px card title is below iOS comfort for a heading.
Body
12.5–13.5px
15px / 400–500
15px / 400–500
Harbor’s value. The wireframe’s body size is a mockup artifact and too small on a phone.
UI label / button
12–12.5px / 700
14px / 700
14px / 700
Harbor’s value, same reasoning.
Pill / badge
11px / 600
11–11.5px / 700
11.5px / 700
Sizes already agree. Harbor’s weight taken — Figtree at 600 sets lighter than the wireframe’s face at 600, so 700 preserves the intended density.
Data / mono
12.5px
13–15px / 500–600
14px / 600
The wireframe had no monospace data face at all, only 9.5px QR identifiers. Harbor establishes this level; 14px is the midpoint and aligns with the UI-label baseline.
Meta / caption
10–10.5px
12px / 400–500
12px / 400–500
Harbor’s value. 10px is below the floor for anything a user needs to read.
Tiny section label
11px / uppercase / 0.04em
—
11px / 700 / uppercase / 0.04em
WIREFRAME WINS — Harbor has no equivalent. This is the recurring card-section header (TODAY’S PLAN, THE JOURNEY SO FAR, TOGETHER & CLUBS) and it is a genuine part of the design. Carried forward as a ninth level, in Figtree.
Mono identifier
9.5px
—
12px / 500
Wireframe value raised to the caption floor. QR identifiers (GW-P-…), IBM Plex Mono.

Where the wireframe and this scale differ, this scale is authoritative — a build session re-skinning a wireframe screen should apply the level, not the wireframe’s pixel value.
All sizes support Dynamic Type scaling. These are the values at the default type size, not fixed pixel constants; anything that would break the layout when scaled up should reflow, not clamp.
10.4 · Mark construction
The mark is two rounded pill shapes — literally the same shape as a progress bar or bar-chart bar used elsewhere in the UI — rotated and overlapped, so the logo reads as an extension of the product’s own data visualization rather than a separate illustration.
Shape: two rectangles, radius 16px, roughly 96–135px wide × 22–34px tall; scale proportionally for smaller lockups.
Rotation: back shape −16°, front shape +12°.
Color: back shape --pal-b (teal), front shape --pal-a (coral).
Overlap: the front shape uses multiply blending where it crosses the back shape, so the intersection reads as a third, darker tone rather than a hard edge — two separate tracks converging.
App icon: the mark does not survive at icon sizes as drawn, because the multiply-blend overlap disappears. A resolved, executable icon treatment is specified in §10.12.
10.5 · Spacing & radius scale
Card radius: 16px — the single radius used for all cards and sheets. Keep it singular; do not introduce a second card radius.
Button / control radius: 12–16px.
Pill / badge radius: 999px, fully rounded.
Card padding: 18–22px.
Card border: 1px solid --pal-line. (This replaces the wireframe’s 1.5px ink outline and its dashed-border convention for provisional cards; where the wireframe used a dashed border to mark something secondary or optional, use the standard card border and differentiate with type weight and color instead.)
Chart bar gap: 6–8px.
Avatar diameter: 44–52px depending on context — list row versus profile header.
10.6 · Core component specs
Component
Shape / spacing
Color
Notes
Card
radius 16px · border 1px · padding 18–22px
border --pal-line · bg --pal-card
Base unit for match cards, weekly summary, PR cards, plan cards
Avatar
circle, 44–52px diameter
linear-gradient 135°, --pal-a → --pal-b
The gradient stands in for a photo in placeholder / no-photo states
Pill / badge
radius 999px · padding 4–5px × 12–14px
bg accent tint (a-tint / b-tint) · text --pal-ink
Weight 700, size 11–11.5px. Tags, sport type, status chips
Primary button
radius 12–16px · padding 10–12px
bg --pal-a · text --pal-on-accent
Weight 700–800. --pal-on-accent is an adopted token resolving to --pal-ink in light and --pal-card in dark; never hardcode one color across both themes (§10.8)
Bar chart bar
radius 5–8px top / 3–4px bottom · gap 6–8px
active accent · inactive --pal-line
Weekly “together” chart, the six-session consistency strip, and similar comparative bars
Sparkline
1.5–2px stroke, no fill
stroke --pal-a, or --pal-b for a second series
PR and trend cards; pair with a single terminal dot marker
10.7 · Dark-mode implementation
Three token layers, matching standard platform conventions:
A base (light) token set — §10.2 light values.
A dark token set applied when the OS-level color scheme is dark and no explicit in-app override is set — §10.2 dark values.
An explicit in-app light/dark toggle that overrides the OS setting when the user sets one. Store the preference; do not simply follow the system permanently.
Every component references tokens, never literal hex, so the same component renders correctly in both modes without conditional logic inside the component. That is how eight variants (four color stories × two modes) were rendered from one set of markup during design review, and it should carry through to production the same way.
10.8 · Accessibility & contrast
Pairing
Ratio
WCAG AA
Verdict / use
Light — ink text on base
12.60:1
Pass
Safe for all text sizes
Light — ink text on card
14.02:1
Pass
Safe for all text sizes
Light — faint text on base/card
2.78–3.09:1
Fail (normal text)
Restrict to large or decorative labels, or pair with an icon; never for small body copy
Light — coral (--pal-a) on card
3.08:1
Pass (UI / large only)
Icons, large numerals, bold ≥18px; not small body text
Light — teal (--pal-b) on card
4.75:1
Pass (normal text)
Safe for body-size labels
Light — button label (--pal-on-accent = ink, on coral)
4.55:1
Pass (normal text)
ADOPTED. Replaces the earlier --pal-card-on-coral shortcut, which measured only 3.08:1 and cleared the UI-component minimum but not the text minimum
Dark — ink text on base
15.62:1
Pass
Safe for all text sizes
Dark — ink text on card
13.94:1
Pass
Safe for all text sizes
Dark — faint text on base/card
5.32–5.97:1
Pass
Safe for normal text; dark mode’s brightened faint tone clears AA where light mode’s does not
Dark — coral (--pal-a) on card
6.27:1
Pass
Safe for normal text
Dark — teal (--pal-b) on card
5.69:1
Pass
Safe for normal text
Dark — button label (--pal-on-accent = card, on coral)
6.27:1
Pass
Comfortable. In dark mode ink-on-coral would measure only 2.22:1, which is why the token flips
Light — danger (--pal-danger) on card
5.52:1
Pass
Safe for all text sizes
Light — danger on base
4.96:1
Pass
Safe for all text sizes
Dark — danger on card
4.59:1
Pass
Safe for all text sizes
Dark — danger on base
5.14:1
Pass
Safe for all text sizes
Light — ink on danger-tint
10.70:1
Pass
The pill pattern — Declined status chip
Dark — ink on danger-tint
12.02:1
Pass
The pill pattern — Declined status chip
Light — card-color label on danger fill
5.52:1
Pass
Destructive button
Dark — base-color label on danger fill
5.14:1
Pass
Destructive button
Light — warn (--pal-warn) on card
5.58:1
Pass
Safe for all text sizes
Dark — warn on card
7.93:1
Pass
Safe for all text sizes

Adopted: the dedicated “on-accent” text token
The mockups use --pal-card as the button-label color on top of --pal-a in both themes, a convenient shortcut that works because both accent colors sit at medium brightness. Measured, it gives a comfortable 6.27:1 in dark mode but only 3.08:1 in light — clearing WCAG’s 3:1 minimum for UI components but not the 4.5:1 minimum for text. Swapping to --pal-ink as the light-mode button-label color measures 4.55:1 and passes normal-text AA, while dark mode should keep --pal-card (ink on coral in dark mode measures only 2.22:1, which is worse). --pal-on-accent is therefore adopted as a semantic token — --pal-ink in light mode, --pal-card in dark mode — and is used for the label on every --pal-a and --pal-danger fill. Confirmed by the founder in September 2026; it is no longer an open item.
Separately: --pal-faint fails normal-text AA in light mode at 2.78–3.09:1. Reserve it for large text (≥18px), icon-paired labels, or genuinely non-essential meta text. Never use it alone for form-field errors, verification-status copy, or any safety-relevant text — several of the most important strings in this product are exactly that.
10.9 · Iconography — Lucide (confirmed)
>>> AMENDED 2026-10-04 BY FOUNDER DECISION: THE ICON SET IS NOW TABLER ICONS, NOT LUCIDE. <<<
>>> Package @tabler/icons-react-native (MIT). Everything below that says "Lucide" applies to Tabler instead: its outline style is the same spec this section asks for (24px grid, 2px rounded stroke), so the treatment rules — sizes, stroke scaling, the color roles, never fill, never mix families — are UNCHANGED. Do not "correct" this back to Lucide. Import each icon by subpath through src/theme/icons.ts only; importing from the package root bundles all ~6,200 icons (measured +43% bundle). See docs/decisions.md, 2026-10-04.
NEW IN THIS REVISION — Resolved in this revision. The Harbor document offered two candidates without testing either.
Lucide is the icon set. ISC licence — permissive, commercial use permitted, no attribution requirement in the shipped app. React Native package: lucide-react-native, which depends on react-native-svg (already required for other chart and mark rendering). Around 1,600 icons; import only the ones used so the bundler tree-shakes the rest.
Lucide is rounded-stroke line work on a 24px grid, which is what §10.9 called for and what the two-pill mark and Outfit/Figtree’s geometry imply. It is a maintained fork of Feather with far broader coverage — including the running, bike, dumbbell, heart-pulse, map-pin, qr-code, calendar and shield glyphs this product needs, which Feather itself lacks.
Treatment: 24px default size, 2px stroke (Lucide’s own default, and the midpoint of Harbor’s 1.5–2px guidance). Scale the stroke proportionally at other sizes — 1.5px at 20px, 2.5px at 32px — so optical weight stays constant.
Color: --pal-ink for default and inactive; --pal-a for active and selected, including the active tab-bar icon; --pal-b for confirmed and verified states; --pal-danger for destructive and warning glyphs; --pal-faint only for decorative icons that are paired with a text label, never alone.
Never fill a Lucide glyph or mix in a second icon family. If a needed glyph does not exist, draw it on the same 24px grid at 2px rounded stroke rather than importing from elsewhere.
10.10 · Motion & interaction (confirmed)
NEW IN THIS REVISION — Resolved in this revision. The mockups were static and specified nothing; these are decided defaults, not recommendations.
The governing principle: motion in this product exists to explain what just happened, not to decorate. Two moments earn expression and everything else stays quick and plain. A training app is used mid-workout, one-handed, often in the cold — every millisecond of animation is a millisecond the user is waiting.
Case
Duration / curve
Notes
Micro-feedback — button press, toggle flip, chip select, checkbox
120ms ease-out
Fast enough to read as instant response rather than animation.
Standard transition — card entrance, tab switch, panel expand/collapse, list item insert
200ms ease-out, cubic-bezier(0.2, 0, 0, 1)
The default. If in doubt, this is the answer.
Sheet / modal presentation
250ms ease-out in, 200ms ease-in out
Slightly slower in than out — arriving should feel deliberate, leaving should feel immediate.
Screen push / pop
Platform default
Do NOT override the native navigation transition. Users have a deep expectation here and a custom push is the single most common way an app feels subtly wrong.
Expressive — match confirmed, new PR
450ms spring, damping ~0.7, slight overshoot
The two mark pills animate into their overlapped position, paired with one iOS notification-success haptic. These are the ONLY two springs in the app.
Live activity timer numerals
No animation
Tabular figures updating in place. Animating a running timer is noise, and it fights the tabular alignment that makes the numbers readable at a glance.
Loading
1200ms shimmer on skeleton placeholders
Skeletons in --pal-line at 60% opacity, shaped like the content that will arrive. No spinners except for a genuinely indeterminate network wait.

Never animate a safety-critical surface. The report flow, the ban state, the age gate, and the guardian-consent screens (§15) present with no transition at all. These should feel immediate and plain; an animated report dialog reads as unserious, and any delay between tapping Report and seeing the form is the wrong kind of friction.
Reduce Motion: when the OS setting is on, every entry in the table above becomes a 100ms cross-fade. The two expressive moments become a plain opacity fade — but keep the haptic, which is the part that actually carries the meaning. The skeleton shimmer becomes a static block. Screen push/pop follows whatever the platform does under Reduce Motion, which is already correct.
10.11 · Extension: danger & caution tokens
NEW IN THIS REVISION — Added after the Harbor design language was written. That palette shipped with nine tokens and no destructive or caution tone, which left the product’s most consequential controls — Delete match, Report, the Declined status, field errors, the banned state — with nothing to render in. These four tokens close that gap and were derived in OKLCH against the existing Harbor values rather than picked by eye.
Token
Light
Dark
Used for
--pal-danger
#C92038
#F64856
Destructive and safety-critical surfaces: Delete match, Report, the Declined partner-status dot, the weak-GPS warning, form and field errors, banned-state treatment
--pal-danger-tint
#FFD5D9
#4B1E25
Pill / badge background for the Declined status chip, paired with --pal-ink label text
--pal-warn
#955900
#E6AC3D
Non-destructive caution: the Invited / pending partner status, the GPS “Acquiring” state, soft warnings
--pal-warn-tint
#F7E8C8
#382A10
Pill / badge background for the Invited status chip, paired with --pal-ink label text

How these were derived
Danger sits at OKLCH L 0.54 / C 0.20 / H 21 in light mode. That is deliberately deeper and more crimson than Harbor’s coral at L 0.68 / C 0.176 / H 33: the roughly 12° hue drop pulls it off coral’s orange lean toward true red, and the lightness drop is what makes it read as “stop” rather than “primary action.”
Dark mode follows Harbor’s own stated convention of brightening an accent for dark surfaces — the same hue (21°), lifted to L 0.655 — so danger is recognizably the same color across both modes rather than two unrelated reds.
The tints deliberately break the geometry used for --pal-a-tint and --pal-b-tint, taking a higher chroma and a lower hue. A tint built on the standard geometry came out visually identical to the coral tint, which would have defeated the point.
The light warn value is deliberately dark (L 0.52) because a mid-lightness amber cannot clear text AA on a near-white card. It reads as a deep ochre rather than a bright amber, which is the cost of legibility here.
Usage rules
Danger is for destructive and safety-critical surfaces only. Never for a primary action — coral owns that, and reusing coral for destructive actions is exactly the confusion this token exists to prevent. Conversely, never use danger to draw attention to something that is not destructive or unsafe.
The Declined status pill follows Harbor’s existing pill pattern: --pal-danger-tint background with --pal-ink label text (10.70:1 light, 12.02:1 dark), and the status dot itself filled with --pal-danger at full strength. Do NOT set danger-colored text on the danger tint — that measures 4.21:1 light and 3.96:1 dark, clearing only the large-text and UI-component bar. The Invited pill works the same way with the warn pair.
Destructive buttons use a --pal-danger fill with the --pal-on-accent treatment (ink in light, card in dark). Both pass at 5.52:1 and 5.14:1, so unlike the coral primary button this one needs no special-casing.
Two honest caveats
In dark mode, danger must never be carried by color alone. Separation from coral is strong in light mode (ΔE-OK 0.145 — unmistakably a different color) but more modest in dark mode (0.101), because Harbor’s dark coral is itself a bright salmon. Always pair dark-mode danger with an icon, a border, or explicit wording. That is good practice for color-blind users regardless; here it is load-bearing for everyone.
The danger and coral tints remain close (ΔE 0.037 light, 0.043 dark) even after the deliberate adjustment — pale tints are inherently hard to separate. Do not rely on the tint background alone to signal Declined. The dot and the label text carry the meaning.
Warn is well separated from both danger (ΔE 0.146 and above) and coral (ΔE 0.187 and above), so the three-way distinction between pending, destructive, and primary holds.
10.12 · App icon (confirmed)
NEW IN THIS REVISION — Resolved in this revision. The Harbor document flagged that the two-pill mark had never been tested at icon resolution and that the multiply-blend overlap would be lost at small sizes. This is the resolution; someone still has to render the asset files (see the deliverables list).
The problem is specific: at 40px the multiply-blended intersection is roughly three pixels across, and blend modes rasterize inconsistently across icon pipelines anyway. The fix is to stop relying on the overlap to carry meaning at small sizes, without abandoning the two-track idea that makes the mark what it is.
Full icon — 1024px down to 40px
Ground: solid --pal-ink (#232C30), full bleed, one icon for both light and dark modes. Coral and steel-teal both hold strong contrast on near-black, the icon reads as one confident object against arbitrary wallpaper, and a single ground removes the light/dark icon question entirely. The chalk base (#F3F1EA) was the obvious alternative and was rejected: a near-white icon disappears against light wallpapers and looks like a missing asset.
Two pills, separated rather than overlapped. Keep both shapes and both rotations (back −16° in --pal-b, front +12° in --pal-a), but instead of intersecting, leave a ground-colored gap of 4% of the icon width between them. The two-tracks-converging reading survives, the blend mode disappears, and the gap stays visible down to 40px. This is the standard way an overlapping mark simplifies for small sizes.
Do not substitute a solid color for the intersection. The multiply of coral over teal computes to roughly #373129, a dark brown that nearly vanishes against the ink ground — it would read as a smudge, not a third tone.
Safe area: the mark occupies 62% of the icon width, optically centered, leaving ~19% clear on each side. Full-bleed square artwork with no built-in corner rounding and no baked-in shadow — iOS and Android apply their own masks.
Which variant at which size
Size
Variant
Where it appears
1024px
Full — two separated pills
App Store listing. PNG, no alpha channel, no pre-applied corner rounding.
180 / 167 / 152 / 120px
Full — two separated pills
iPhone and iPad home screen. The 4% gap is 7px at 180 and 5px at 120 — comfortably visible.
87 / 80 / 76 / 60 / 58px
Full — two separated pills
Spotlight and Settings. The gap is 3px at 76 and 2px at 58 — still resolving, which is why 40px is the floor for this variant.
40px
Full — two separated pills (floor)
Smallest size at which two distinct shapes still read. Below this they merge into a smudge.
29 / 20px
Single coral pill, +12°, ink ground
Notification icon and small Settings badge. One shape, no gap to lose, still unmistakably the mark’s front element.
Any size, tinted
Monochrome — both pills white, transparent ground
iOS tinted home screen and monochrome notification contexts. The system applies its own tint ramp.

The 29px and 20px assets are a genuinely different drawing, not a downscale of the full mark. Generating them by resampling the 1024 will produce mush; they must be authored at size.
Corner radius: author every asset as a full-bleed square with square corners. iOS applies its own superellipse mask and Android applies its adaptive-icon mask; baking in a radius produces a visible double-rounded edge. Do not add a drop shadow or a gloss layer for the same reason.
Monochrome / tinted variant
For the iOS tinted home screen and for monochrome notification icons: both pills in solid white at 100% opacity with the same 4% separating gap, on a transparent ground. No tint ramp, no gradient — the system applies its own.
Deliverables someone still has to render
1024×1024 App Store icon, PNG, no alpha channel.
The iOS asset-catalog set generated from it, plus the dedicated ≤40px single-pill variant.
The monochrome/tinted variant as a separate asset.
An Android adaptive icon when Android ships — foreground layer the pills, background layer solid --pal-ink, respecting Android’s 66% safe zone (tighter than the 62% above, so the foreground needs its own artboard).
A favicon set for any marketing site, from the same single-pill small variant.

11. How to Use This Document with Claude Code
NEW IN THIS REVISION — Entirely new. Written for a founder with no coding background who will be driving the build through Claude Code.
Claude Code is a coding assistant that runs in a terminal inside your project folder. It can read every file in that folder, write code, run commands, and check its own work. The single biggest determinant of whether the build goes well is not how you phrase any one request — it is whether the specification lives in the repository where the assistant can read it, and whether you work in small verifiable pieces instead of asking for the whole app at once.
11.1 · Put the specification in the repository
Create the project folder and its Git repository (Vendor Setup Guide, section 0).
Inside it, make a folder called docs/ and put three things in it: this document exported as docs/build-brief.md, plus copies of docs/mobile-preview.html and docs/playbook.html.
Create a short file called CLAUDE.md in the top level of the project. Claude Code reads this file automatically at the start of every session, so it is the one place you never have to re-explain anything. Keep it to about a page — it should point at the long documents rather than repeat them. Suggested content is below.
Commit all of it before writing any application code, so the specification is version-controlled alongside what gets built from it.

Suggested CLAUDE.md:
Groundwork — a platonic training-partner matching app. iOS-first, Expo + React Native, Supabase, Stream Chat.
The full specification is docs/build-brief.md. Read it before making architectural decisions.
docs/mobile-preview.html is the interactive reference implementation of every screen. Open it in a browser and match it. When it and the brief disagree on interaction or appearance, the wireframe wins.
Section 5 of the brief lists audit-critical safety rules enforced at the database layer with Postgres RLS. Never weaken or bypass one to make a feature work; raise it with me instead.
Section 7 is the build order. We work one phase at a time and do not start the next until the current one passes its checks in Section 12.
Secrets live in .env, which is git-ignored. Never commit a key or print one in full.
11.2 · Work one phase at a time
Start each session by naming the phase: “Read CLAUDE.md and docs/build-brief.md. We are on phase 4, Matching & Discover, only. Do not start any other phase.” Scoping the session is the most useful thing you can do.
Ask for a plan before code. “Before writing anything, list the files you will create or change and what each one does.” Read the list. If something is missing or looks like an invention, say so then, not after it is built.
Ask it to open the wireframe. “Open docs/mobile-preview.html in a browser, click through the Discover tab including the filter panel and the map view, and describe what you see. Then build it to match.” Assistants are far more accurate when they have looked at the reference than when they are working from a description of it.
Keep requests to one screen or one rule at a time. “Build the Discover filter panel with all ten filters and the saved-preset row” is a good request. “Build Discover” is not.
When a session gets long, confused, or starts contradicting itself, stop and start a fresh one. Nothing is lost — the specification and the code are both in the repository. Long sessions degrade; new sessions do not.
Ask it to keep a running decision log at docs/decisions.md, one line per non-obvious choice with the date. Six weeks later this is the file that explains why something is the way it is.
11.3 · Verify before you move on
Every phase ends with three checks: it builds and runs on your phone; it looks like the wireframe; and it passes the relevant tests in §12. Ask explicitly: “Run the §12 checks that apply to this phase and show me the output.”
For the safety rules specifically, ask for the tests as real SQL you can run yourself in the Supabase SQL editor, not as a prose assurance. “Write the §12 S1 through S5 checks as SQL I can paste into Supabase, and show me the expected result of each.” If a check returns rows where it should return none, that is a real defect, not a false alarm.
Take a screenshot of each finished screen next to the wireframe’s version of it. Divergence is much easier to catch visually than in code.
11.4 · Commit after every working phase
“Commit this with a clear message” at the end of each phase. A commit is a save point you can return to; without them, a bad change can be hard to undo.
Ask for a branch per phase (“create a branch called phase-04-discover”) and merge it once the phase passes its checks. If a phase goes badly, you throw the branch away instead of untangling it.
Push to GitHub at least once a day. The repository is the only real backup of the work.
11.5 · Things to insist on
No invented features. If the assistant proposes something not in this brief or the wireframe, ask where it came from. Twenty-one rounds of decisions are in here specifically so they do not get re-made accidentally at 11pm.
No secrets in code. Keys belong in .env; the file belongs in .gitignore. Ask it to confirm .gitignore covers .env before the first commit.
No weakening an RLS policy to unblock a feature. If a policy is in the way, the fix is a correct policy, not a disabled one. This is the single most likely way for the security model to quietly break.
No placeholder or fabricated user data shipped into a real database. Seed data is fine in development and must be clearly separated from production.

12. Acceptance Criteria & Test Checklist
NEW IN THIS REVISION — Entirely new. §5 states the safety rules; this section makes each of them checkable. The post-build audit should be able to run this list as-is.
The S-series below are the audit-critical security checks. Every one must be run against the API/database directly — with a real user’s credentials, using the Supabase client or the SQL editor with the appropriate role and JWT claims set — and not by observing the app’s user interface. A rule that is only enforced in the UI is not enforced. The F-series are functional checks that catch the interaction details most likely to be built wrong.
12.1 · S-series — security and access control
#
Test
Must be true
S1
Create an account with age_status = unverified. Using that account’s own token, query the Discover people source directly (not through the app).
Zero rows returned. Not “the UI hides it” — the query itself must return nothing. Repeat with age_status = minor: also zero rows.
S2
As the same unverified account, call the create-match / scan-confirm endpoint directly with another user’s valid personal QR identifier.
The call is refused with an explicit error. No matches row is created. Repeat as a minor account: same result.
S3
As an unverified account, redeem a valid CLUB QR identifier.
Succeeds. A club_memberships row is created with joined_via recording the minor-safe route. This is the one deliberate exception and must work.
S4
As an ordinary adult account, read profiles.qr_code for an account whose age_status is minor.
Denied or null. A minor’s personal code must not be retrievable by anyone else.
S5
Set is_banned = true on an account. Then, as a different account, run each of: the Discover list query, the Discover map-pin query, the Matches list query, the personal-QR lookup, and a fresh match-creation call naming the banned id.
The banned account is absent from all four reads and the creation call is refused. Five separate code paths — check all five.
S6
Move a report’s status to actioned.
users.is_banned flips in the same transaction. Force a failure part-way through and confirm both changes roll back together — never one without the other.
S7
As the reported user, select from reports where reported_id = your own id. Then as an unrelated third user, select the same rows.
Zero rows in both cases. Only the reporter (own submissions) and the trust-and-safety role can read a report.
S8
As a user who is not a participant in a session, select checkin_locations rows for that session. Then insert a row with recorded_at set 31 days in the past and run the purge job.
Zero rows for the non-participant. The 31-day-old row is gone after the purge, and the purge runs on a schedule rather than on demand.
S9
Delete a match that has an existing chat thread with messages.
chat_threads and messages rows still exist, the thread appears in “Archived chats”, and its history is intact. Confirm in the schema that chat_threads.match_id is ON DELETE SET NULL, not CASCADE.
S10
Send a match request from A to B and stop there.
matches.status is pending. B does not appear in A’s Matches list, and no chat thread is usable yet. Only an explicit approval moves it to matched.
S11
Search the entire schema and every storage bucket for anywhere an ID image, a selfie, a biometric template, or a raw date of birth could be stored.
Nothing found. verification_records holds only the provider reference, the tier, the status, and the derived adult/minor outcome.
S12
As an unrelated user, read another user’s verification_records and push_tokens rows.
Zero rows for both.
S13
Confirm age_status can only be written by the server. Attempt to update your own users.age_status to adult with a normal user token.
Refused. The only writers are the signup handler and the identity-verification webhook, both server-side.
S14
As user A, read user B’s filter_presets, plans, activity_logs, activity_sets, and thread_settings.
Zero rows for each.
S15
Mint a Stream Chat user token for a channel the user has no thread_participants row for.
Refused by the server-side token function. Channel access must derive from Postgres, never from the client asking for it.
S16
With no session at all (no JWT), call every data-bearing endpoint the app uses: Discover list, Discover map pins, Matches, Activity, Log, Profile, clubs, leaderboards.
Every one is refused. An account is required for the entire app (§3); there is no anonymous read of anything.
S17
As a minor account, attempt a person-to-person QR match with an account whose age_status is self_attested_adult.
Refused at the API layer with an explanatory error — not silently ignored, not merely hidden in the UI. Only a fully ID-verified adult may match with a minor (§15.5).
S18
As a minor account, attempt a person-to-person QR match with a fully adult account with whom the minor shares no club.
Refused (§15.5). Repeat with a shared club: proceeds to guardian approval. This single test is the difference between the teammate case and the arbitrary-stranger case.
S19
Form any minor-to-adult match by any path.
A minor_adult_matches row is written with the shared club recorded, readable by the trust-and-safety role and no one else. The guardian is added to the thread as guardian_observer and the disclosure banner is present for both parties (§15.3).
S20
As a minor account, attempt to set live_map_visible_until, opt into check-in location sharing, or write a checkin_locations row.
All refused server-side. Then confirm the Discover map-pin query returns no minor accounts to any viewer, and that checkin_nudge push never fires for a session containing a minor (§5.8).
S21
As a minor account, attempt to set leaderboard_settings.visibility to public.
Refused. Then, as a viewer who shares no club with that minor, request the minor’s standing: nothing is returned.
S22
Request a club leaderboard as a permitted viewer and inspect the raw API response.
It contains only the rows shown — display name, rank, one stat — for permitted members. It must NOT contain per-member session counts for anyone the board does not display, or for opted-out members (§5.9).
S23
Opt out of a club leaderboard, then request that board as another member.
The opted-out member is absent immediately and retroactively, regardless of their rank.
S24
As user A, read user B’s thread_settings, leaderboard_settings, relationship_sessions rows they are not part of, or any minor_adult_matches row.
Zero rows for each. minor_adult_matches is readable only by the trust-and-safety role.
S25
Create a 13–17 account and stop before the guardian completes consent. With that account’s token, attempt each of: a Discover query, a personal QR scan, a club QR scan, an invite-code redemption, sending a message, being added to a plan as a partner, and appearing in a club roster read by another user.
Every one refused or absent. This is the fail-closed table in §15.2, and it is stricter than the unverified adult state. Then confirm the account CAN still edit its own profile and log its own activities.
S26
Attempt to set users.consent_status to granted with a normal user token, from both the minor’s account and the guardian’s.
Refused. Only the server-side consent handler may write it.
S27
Complete guardian verification, then revoke consent from the guardian account.
In one transaction: consent_status becomes revoked, every minor-to-adult match is deactivated, and the guardian’s guardian_observer rows are removed. Force a mid-transaction failure and confirm all three roll back together.
S28
As the adult party to a minor-to-adult connection awaiting guardian approval, read guardian_links or guardian_connection_approvals.
Zero rows. An adult must not be able to enumerate which minors have approval pending.
S29
As a linked guardian, attempt to read a minor-to-minor thread, the minor’s activity_logs detail, activity_photos, or checkin_locations. Then attempt to POST into the minor-to-adult thread you can read.
All refused. guardian_observer grants SELECT on that one thread’s messages and nothing else — never INSERT.
S30
As a minor with three minor-to-adult matches formed in the last seven days, attempt a fourth.
Queued for review, not silently created and not flatly refused (§15.7).
S31
As an adult, scan a minor’s personal QR code (rather than the minor scanning yours).
Refused on scan direction (§15.6). Then confirm a minor’s displayed code identifier changes on roughly a 60-second cycle and that no share, save-image, or copy affordance is exposed anywhere in the UI or the API response.
S32
Insert directly into matches, bypassing the §15.9 gate function, for a pair where one party is a minor.
Refused by constraint or trigger. The consolidated gate must be the only path that can create such a match.
S33
Request another user’s profile and inspect the raw response for the partner count. Then attempt every parameter variation on that endpoint that might expand the total into rows.
Only an integer is ever returned. No parameter yields the underlying match rows, and the count is not implemented as the length of a fetched list. A count is social proof; a list is a social graph (§5.9).
S34
As an adult who shares no club with a minor, request that minor’s profile.
The partner count is absent from the response entirely — not zero, not null — so a private profile and a permission-denied profile are indistinguishable. Repeat as a club-sharing adult, as the minor, and as the linked guardian: present in all three.
S35
Set a user’s leaderboard_settings.visibility to off, then request their profile as a matched partner.
Both the Standing card and the partner count disappear together. Confirm there is no second, separate privacy setting that governs one but not the other.
S36
Ban an account that was matched with three other users, then read those three users’ partner counts.
All three decremented, in the same transaction as the ban. A banned user that disappears from lists but still inflates a former partner’s total is a visible leak of the ban (§5.2, §5.9).
S37
Create a pending (requested-but-unapproved) match and a soft-deleted match, then read the partner count.
Neither is counted. Only active matched rows count.
S38
Request a club board on the This month basis, then on All time, and inspect both raw responses.
Each returns only the displayed rows for that basis. Neither response contains the other basis’s raw per-member counts, and switching the toggle issues a new server request rather than re-sorting data the client already holds.
12.2 · F-series — functional
#
Test
Must be true
F1
RSVP to a club event past its capacity, then have an earlier attendee cancel.
The over-capacity RSVP is waitlisted with an ordered position; the cancellation promotes the first waitlisted person, in one transaction.
F2
Edit a recurring plan.
The user is asked to choose this session / this and following / whole series before anything changes.
F3
Accept a template shared in chat.
A copy appears in the recipient’s own templates. Today’s log is untouched.
F4
Start a live run from a plan, wait for the weak-GPS state, and tap “Log manually”.
The recording is cancelled and manual entry opens, pre-set to the same activity type and carrying the plan’s linked template.
F5
Record a live “Other” activity.
Duration is tracked; no distance and no pace are shown or stored. The free-text label field is offered with fuzzy autocomplete.
F6
Save a manual “Other” entry with a label close to an existing tag (e.g. “trails” against “Trail Running”).
The label collapses onto the existing canonical tag, and that tag then appears as a selectable sport-type filter chip in Discover.
F7
Set a plan’s consistency rate to exactly 70%, then 69%.
Teal at 70, accent at 69. The six-dot strip uses the same color.
F8
Confirm an auto-synced activity whose type matches today’s plan.
The plan is marked complete by that same action, with no separate step, and the card carries the “Matches today’s plan ✓” badge beforehand.
F9
Sync the same workout from both HealthKit and the aggregator.
One activity_logs row, not two.
F10
Turn on “Show on live map”: flip once, do not pick a duration, flip again.
Nothing goes live. A duration must be chosen between the two flips. Turning it off clears both the arm state and the duration.
F11
Let a live-map window expire.
The pin disappears from other users’ map queries at the server, not just on the owner’s device.
F12
Mute check-in nudges for one partner.
That partner’s nudges stop, in the app and in push. Every other thread is unaffected.
F13
Set filters in Discover, switch tabs, come back — then force-quit the app and reopen it.
The filters are still applied in both cases.
F14
Mark a plan partner Declined and tap “Dismiss for now”.
They disappear from that one plan only, and remain a full match in Matches and on every other plan.
F15
Delete a match for someone attached to three different plans.
They are removed from all three, and from Matches, in one action.
F16
Register a device, then have the push provider report the token as unregistered.
The token is marked revoked and no further sends are attempted against it.
F17
Fire each of the six push events in §2.13.
Each arrives with the right copy, opens the right screen, and none contains coordinates or another user’s precise location.
F18
Mute Messages in one thread, leave Check-in nudges on, and have that partner send a message and trigger a nudge.
No message push arrives; the nudge push does. The message itself still appears in the thread with an unread indicator, and the other participant sees no indication that they were muted.
F19
Sign up with a date of birth under 13, then 13–17, then 18+.
Refused with an explanation; age_status = minor; age_status = self_attested_adult. Confirm none of the three can be changed from the client afterwards.
F20
Complete a Stripe Identity check as a self_attested_adult account whose ID shows 18+.
age_status becomes adult, the “ID verified” badge appears, and no date of birth is persisted anywhere in the database or logs. Repeat with an ID showing under 18: age_status becomes minor permanently and a retry does not restore adult.
F21
Open Discover as a minor and as an unverified account.
Both see the age gate, with the correct one of the two copy variants. Neither can reach a person card by any route.
F22
Turn on a club’s leaderboard as its organizer, then off.
The “Top athletes” section appears and disappears for every member. Default for a new club is off.
F23
Log sessions across two clubs and with two partners, then check the Standing card on both bases.
The card opens on This month. Toggling to All time re-ranks both halves together. Both bases count sessions — not distance, not pace. The partner figure on the Standing card and the “N sessions logged together” figure on that person’s profile (§2.7) are identical on the matching basis; if they differ, the two are reading different counters and the feature is broken.
F24
View a stranger’s profile from Discover with default settings.
No Standing card is shown — default visibility is matches_and_clubs. It appears once matched or once a club is shared.
F25
Render every screen in light mode and dark mode, and with the OS set to dark but the in-app toggle set to light.
The in-app toggle wins and the preference persists across a restart. No component contains a literal hex value (§10.7).
F26
Check every primary and destructive button label’s contrast in light mode.
Both use --pal-on-accent (--pal-ink in light, --pal-card in dark), measuring 4.55:1 on coral and 5.52:1 on danger — not the old --pal-card-on-coral shortcut at 3.08:1 (§10.8).
F27
Sign up as a 13–17 account and walk the guardian through the invitation.
Guardian receives both email and SMS; creates a real account; completes the Stripe Identity step; sets the initial controls. Consent then unlocks the minor account and both parties are notified (§15.2).
F28
Leave a minor account at pending for 14 days, then 30.
Soft-locked to the consent screen at 14 with a reminder to both parties; account and data deleted at 30 with notice at each step, and the minor able to export their logged activity beforehand.
F29
Form a minor-to-adult match with guardian per-connection approval left on (the default).
The match sits pending, no thread opens, and the guardian is notified. It activates only on approval. Then turn the toggle off and confirm a subsequent connection activates without approval.
F30
Open a minor-to-adult thread as each of the three parties.
The non-dismissible disclosure banner is visible to the minor and to the adult, stating the guardian can read the conversation. The guardian sees the thread read-only with no composer.
F31
Open a minor-to-minor thread as the linked guardian.
Not accessible. Guardian visibility is scoped to the minor-to-adult case only (§15.3).
F32
Read the platform age signal on iOS 26+ and on Android.
The bracket and the self-declared / guardian-declared method are recorded, used for the current decision, and not cached long-term.
F33
Turn on Reduce Motion and exercise every transition in §10.10.
All become 100ms cross-fades; the two expressive moments fade but keep their haptic; skeleton shimmer becomes static. Confirm the report flow, ban state, age gate and consent screens have no transition at all in either setting.
F34
Join a club whose board has an established long-tenured leader, log more sessions than anyone else in the trailing month.
You top the This month board while the all-time board is unchanged. This is the whole point of shipping both bases (§2.14).
F35
Open a profile and a club page as a permitted viewer.
The profile shows a total training-partner count; the club shows a member count distinct from the per-session “going” figure. Both are plain totals, not rankings.

13. Mobile Framework Decision: Expo vs. Bare React Native
NEW IN THIS REVISION — Entirely new. The previous revision said “React Native” without resolving this, which is one of the two or three highest-consequence decisions in the build for a non-technical founder.
13.1 · Recommendation
Build with Expo, using a development build (EAS Build, config plugins, and prebuild) from day one. Do not use bare React Native, and do not rely on the Expo Go app past the first week.
This decision became load-bearing after it was made. The founder’s development machine is a Windows laptop with no Mac (§16). Expo with EAS is what makes a Mac-free iOS build possible at all: EAS compiles iOS on Expo’s own cloud macOS infrastructure, manages Apple signing credentials, and submits to TestFlight and the App Store from Windows with no Xcode and no Transporter. The reasoning below was written on other grounds — tooling, libraries, and how well represented Expo is in AI training data — and all of it still holds. But the framework choice is now also the thing that makes the project buildable on the hardware that exists.
The framing that used to matter — “managed Expo cannot use native modules, so a project like this needs bare React Native” — is out of date. In 2026 the real distinction is between the Expo Go sandbox app, which can only load the native modules Expo ships, and a development build, which is your own app binary and can load any native module at all. Expo’s Continuous Native Generation (prebuild) writes real ios/ and android/ projects from your configuration, so nothing is actually locked away; you can inspect or edit the native projects at any time, and you can eject permanently if you ever need to. Choosing Expo therefore does not give up capability. It gives up some direct control over native project files in exchange for a great deal of tooling.
13.2 · Dependency-by-dependency check
Requirement
Verdict
Detail
Camera + QR scanning
First-party
expo-camera includes barcode and QR scanning. No third-party library needed.
Push notifications
First-party
expo-notifications on top of APNs/FCM, with Expo’s push service free at any pilot volume.
Foreground + background location
First-party
expo-location plus expo-task-manager support background location updates and geofencing. Expo’s own documentation is explicit that background location requires a development build and the “location” UIBackgroundMode — which is exactly the App Review exposure §3 already flags. The foreground-only v1 fallback is equally supported, so the fallback decision stays a product decision rather than a technical one.
Apple HealthKit
Works, via a community library
Not an Expo first-party module, but @kingstinct/react-native-healthkit ships an Expo config plugin and documents Expo/development-build use directly. react-native-health-connect covers the Android side when Android ships.
Wearable aggregator
Resolved — Spike
Spike ships a first-party Expo config plugin, documented on its own page in the Spike React Native SDK docs. Adding ["react-native-spike-sdk", { … }] to app.json’s plugins array configures the iOS HealthKit entitlement and usage strings and the Android Health Connect manifest permissions automatically, and can enable background delivery. It requires a development build and a prebuild after any config change — exactly the workflow recommended here. Terra ships an Expo demo project (TerraExpo) and a README note about expo-web-browser, but no config plugin and no Expo documentation page. Spike is therefore the confirmed vendor (§6, §2.12); Terra remains the documented fallback.
Stripe Identity
Works, but needs a small custom config plugin
This is the one integration with real friction. @stripe/stripe-identity-react-native (v0.9.0, June 2026) does not ship an Expo config plugin, and its setup instructions assume a bare project: pod install on iOS, and an Android Material theme requirement plus a camera permission string. Under Expo this needs a small config plugin — roughly, an Android styles modification and an Info.plist camera usage string — or the equivalent via expo-build-properties. That is a bounded task, and it is the same native configuration bare React Native would require you to do by hand anyway. Prototype it in the first week rather than at phase 10.
13.3 · Why this matters for a non-technical founder
EAS Build compiles the app on Expo’s servers and manages Apple signing certificates and provisioning profiles for you. Certificate management is the single most common place a first-time iOS builder loses a day, and this removes it almost entirely.
EAS Submit uploads the build to TestFlight and App Store Connect with one command, instead of an Xcode archive-and-upload dance.
expo-updates lets you ship a JavaScript-only fix to pilot users without an App Store review round trip. During a 150–500-person pilot that is worth a great deal.
A development build installs on your own iPhone from a link, so you can see real progress on a real phone from day one rather than only in a simulator.
Expo is extremely well represented in AI coding assistants’ training data, which matters when an assistant is doing most of the typing.
And decisively: it removes the Mac requirement entirely. Every other benefit in this list would be worth having anyway. This one is the difference between a project that can be built on the available hardware and one that cannot. See §16.
13.4 · The honest costs, and how to manage them
Config plugins are the failure mode, and on Windows the cost of finding out late is much higher. Any native library without a plugin needs one written, and an Expo SDK upgrade can occasionally break a community plugin. The mitigation is to install every native dependency in phase 1 — camera, location, HealthKit, the Spike aggregator, Stripe Identity, notifications — and prove they all compile together in a real EAS build before any feature work. On a Mac a late discovery costs a local rebuild; here it costs a cloud build cycle per attempt, and debugging a native config error through a 10–25 minute remote build loop is genuinely painful. If something is going to be hard, find out in week one.
Pin the Expo SDK version and do not upgrade mid-build. Upgrade deliberately, on its own branch, between phases.
Do not use Expo Go beyond the very first scaffolding session — this matters more than it sounds. Expo Go’s native runtime is compiled once by Expo before you download it, so it can only load native modules Expo chose to bundle. This project’s HealthKit library, the Spike aggregator SDK and its config plugin, and Stripe Identity are none of them, and no amount of JavaScript will change that. Expo’s own guidance goes further: use a development build for any real-world app even with no native libraries, because Expo Go also fails to reproduce production behaviour for push notifications, OAuth, deep and universal linking, maps, and anything passing an API key to native code — four of which this app uses. It also runs under a generic bundle identifier rather than the app’s own, so push tokens and deep links behave differently. Use an EAS development build on the founder’s iPhone from phase 1 onward, and treat Expo Go as unavailable after that. See §16.4a.
CORRECTION — bare React Native is no longer a viable fallback for this project. An earlier revision of this section said the exit was cheap: run npx expo prebuild, get ordinary ios/ and android/ projects, and carry on. That advice was written before the Windows constraint was known and it is now misleading. Prebuilding into a bare project on a machine with no Mac leaves you with an iOS project you cannot compile — no Xcode, no local iOS toolchain, no way to produce a signed build. The escape hatch that made this a low-risk choice does not exist on this hardware.
The practical consequence: treat Expo + EAS as a commitment rather than a default. If a native dependency genuinely cannot be made to work under a config plugin, the options are to solve it inside Expo (write the plugin, or use expo-build-properties), to change the dependency, or to buy a Mac — not to eject. This raises the stakes on the phase-1 discipline below considerably, and it is a further reason to prove every native dependency compiles before any feature work begins.
Ejecting remains theoretically available and would still be the right move for a team with Macs. It is simply not an option this founder can exercise, and a build session should not propose it as one.
Sources: Expo — Continuous Native Generation, Config plugins introduction, Location (SDK), and Adopt Prebuild; kingstinct/react-native-healthkit; stripe/stripe-identity-react-native (v0.9.0, June 2026); Spike API React Native SDK documentation, including its Expo config-plugin page; Terra tryterra/Terra-React-Native.

14. Decision Log & Remaining Open Items
NEW IN THIS REVISION — Rewritten. Every product and design question previously listed here has now been answered. What remains under “deferred” is founder-owned business and legal work that runs alongside the build rather than blocking it.
Nothing in this section blocks the start of the build, and that is the point of reading it. Every design and product question raised across 21 rounds of research and four revisions of this document is now resolved and specified. §14.1 is the log of those decisions. §14.2 is one product observation the founder may want to revisit after seeing real data — it is not a blocker and the decision it concerns is already made. §14.3 is founder-owned business and legal work that runs in parallel. There is no open design question left in this document.
14.1 · Resolved — the full decision log
Question
Resolved as
How an account becomes “adult”
Four-state model — unverified / minor / self_attested_adult / adult. Date of birth at signup; adult only via a server-side Stripe Identity webhook; sticky minor downgrade; store only the derived outcome. §2.8, §4.1, §5.5.
Visual design language
Harbor “Middle Distance” system. §10. Supersedes the wireframe’s colors and fonts entirely.
Handwriting display font
Superseded — Outfit, Figtree, IBM Plex Mono. Patrick Hand does not ship. §10.3.
Discover map view
In scope for v1. §2.1, §9 screen 4, §7 phase 4, tested by S5 and S20.
Leaderboards
In scope at launch, club and personal, on TWO ranking bases — all-time and rolling 30-day — with a segmented toggle defaulting to This month. §2.14, §5.9, §7, §12.
Chat notification mute scope
Both message and check-in-nudge muting, as one per-thread control with two toggles. §2.5, §2.13, §4.2.
Aggregator vendor
Spike, on the Expo criterion. Terra is the documented fallback. §6, §2.12, §13.2.
Account required for the whole app
Confirmed. No signed-out mode. §3, §9 screens 0a–0c, test S16.
Minor person-to-person QR safeguards
All accepted and now specified as requirements, not recommendations. §15.
Parental consent for 13–17 accounts
Researched against current practice and implemented as the consensus mechanism — guardian linkage with verified consent, guardian visibility of minor-to-adult threads, and fail-closed pending state. §15.2, §15.3.
--pal-on-accent token
Adopted. Light = --pal-ink, dark = --pal-card. §10.2, §10.8.
Danger and caution tokens
Added as a Harbor extension, derived in OKLCH. §10.11.
Numeric type scale
Verified against the wireframe and confirmed. §10.3 — hierarchy from the wireframe, absolute sizes from Harbor, with three levels resolved in the wireframe’s favour.
Icon set
Lucide (ISC licence, lucide-react-native). §10.9. >>> AMENDED 2026-10-04: now Tabler Icons (MIT, @tabler/icons-react-native) by founder decision — see §10.9 and docs/decisions.md. <<<
Motion defaults
Specified. §10.10.
App icon at small sizes
Resolved — separated-pill treatment on an ink ground, with a single-pill variant below 40px and a monochrome variant. §10.12. Asset files still need rendering.
14.2 · Reversals and resolutions worth recording explicitly
Two entries where a later decision overrode an earlier one. Both are recorded with dates because the superseded rule still appears in older artifacts, and a future session that encounters it should know it was changed deliberately rather than “correct” it back.
The tenure concern in all-time leaderboards — RESOLVED
Raised (September 2026): ranking a board on all-time totals permanently advantages the longest-tenured members. A member joining in month nine could not realistically climb a board topped by someone with two years of sessions — the same discouragement dynamic the sessions-not-pace decision was made to avoid, relocated from a fitness axis onto a tenure axis.
Resolved (September 2026) by the founder’s decision to ship both an all-time and a rolling-monthly board. This answers the concern structurally rather than cosmetically: every member has one board they can move this week and one that records what they have built. Making the monthly board the default view is what converts it from a resolution on paper into one a user actually experiences. No mitigation is outstanding; this item is closed.
Public total-match counts — REVERSED
Round 17 (earlier, 2026): “do not need to show the exact number of matches that users have.” This was written into the brief as a hard rule — “No general ‘X total matches’ stat anywhere — every count is scoped to one specific relationship, never a running total” — and it shaped §2.7’s Together & clubs card, which shows only per-relationship figures.
September 2026, founder decision: reversed. A person’s profile displays their total training-partner count, and a club page displays its member count. The founder was asked to disambiguate and chose the public-total reading explicitly. The old rule has been removed from §2.7 and from §2.14; the new behaviour, with its guardrails, is specified in both.
For any future session: the September 2026 decision governs. The round-17 rule survives in the Playbook and in earlier round notes. Do not restore it. The per-relationship figures it protected are unchanged and still appear — what changed is that a plain total now appears alongside them.
The guardrails attached to the reversal are not optional and follow from rules already in the document: counts are computed server-side and only the total is sent; only active matches count; a minor’s count is not shown outside their own clubs; and the count obeys the same visibility control as Standing rather than a second toggle (§2.7, §5.9).
14.3 · Test device — RESOLVED
The founder has an iPhone 15 Pro Max, with Developer Mode already enabled and TestFlight already installed. Device testing is settled: that phone is the primary iOS test device from phase 1, registered via eas device:create. No purchase is needed, the used-iPhone budget line raised in an earlier revision is withdrawn, and the Android-first alternative considered as a workaround is moot. iOS-first sequencing stands. See §16.4.
One thing to be clear about, since Expo Go is already installed: it is not the testing path. Expo Go cannot load this project’s native dependencies and the project outgrows it during phase 1. The development build installed through EAS is what runs the real app — §16.4a explains why and what to do instead.
Garmin beta tester — secured. The founder has a Garmin-wearing beta tester lined up, which closes the one part of the build that could not otherwise be verified before launch. The remaining action is timing: bring them in at the start of phase 9, when the Spike integration is being wired, not at the TestFlight phase (§16.5a, §2.12).
14.4 · Deferred — founder-owned, not blocking the build
These sit outside the build. They should progress in parallel, and none of them prevents a build session from starting or completing any phase in §7. They are listed so they are not forgotten, not because they gate anything.
Attorney sign-off on the ToS, Privacy Policy, and Assumption of Risk & Liability Waiver, required before any real user is gated by them. The review should now explicitly cover the minor person-to-person matching decision (§15), the parental-consent mechanism (§15.2), guardian thread visibility (§15.3), and the COPPA and state app-store-law posture described there.
Insurance — broker conversation early, BOP/Tech E&O policy binding right before public pilot launch rather than before.
LLC filing — needed before Stripe can move out of test mode into live, and before any real verification is charged. Not needed to build.
The Spike sales call — startup pricing, Garmin onboarding lead time, and confirmation that the Expo config plugin is current on the pinned Expo SDK version. Start it early; the Garmin side can involve Garmin’s own approval. §6 and the Vendor Setup Guide.
Trademark clock — “Groundwork” remains a working title and naming is being explored separately. Nothing in the build depends on the final name, but the longer it runs the more surface there is to rename.
Moderation staffing — founder-personal review at pilot scale, with vendor selection triggered by volume. §2.10, §8.
Scan-rate limiting and rotating codes for adult accounts — still deferred pending real usage data. Note that both are now implemented for minor accounts as a deliberate carve-out (§15.6, §15.7).
Rendering the app-icon asset files from the §10.12 spec. A designer or a competent build session can execute it; it is specified, not open.

15. Minor Safety: Consent, Guardianship & Person-to-Person Matching
NEW IN THIS REVISION — Everything in this section is now a requirement. An earlier revision presented the safeguards as recommendations awaiting a decision; the founder accepted all of them, and the parental-consent mechanism below was added after researching current practice across comparable products and the 2026 regulatory floor.
15.1 · Status: adopted in full
Every safeguard in this section was adopted in full by founder decision (September 2026) and is a build requirement. None of it is optional, none of it is pending a decision, and none of it may be descoped by a later session on the grounds that it looks like a recommendation. Where a rule below reads as cautious, that caution is the decision. If a build session believes one of these rules blocks a legitimate flow, the correct response is to raise it with the founder, not to route around it.
15.1a · Why this section exists
A 13–17 account can form person-to-person QR matches. That restores the original round-11 intent — a minor who cannot use Discover still needs a way to connect with the teammates and coach from their actual team — after a later round narrowed the QR system to club codes only. The narrowing was over-broad and the correction is right.
The risk it reopens is specific. A QR code is a shareable image, and v1 codes are static. Without constraints, an adult anywhere could text a minor their code and obtain a private 1:1 chat thread plus meetup scheduling with that minor, with no physical presence at any point. Everything below exists to keep the teammate-and-coach case working while removing that path.
The legitimate case and the abuse case separate cleanly. Every legitimate instance involves people who are physically co-located and already affiliated — a team, a club, a practice. The abuse case involves an adult who has never been near the minor. §15.5’s shared-club requirement draws exactly that line, and it is the load-bearing safeguard in this section.
15.2 · Parental consent and guardian linkage
Researched, not invented. The mechanism below is the consensus pattern across youth-sports platforms, teen-permitting social products, and the 2026 regulatory floor. Three findings shaped it: guardian linkage is near-universally a handshake initiated from the minor’s account and completed by the guardian, not an email address typed in by the minor; guardians are given metadata and controls but not message content; and in organized US youth sports specifically, the governing standard already prohibits private one-to-one adult–minor electronic communication (§15.3).
What the comparison set actually does
Product
How the link is made
Consent proof
What the guardian gets
Roblox (2026)
Parent links their own account to the child’s; mandatory facial age check for all users via a third-party vendor, ID as an alternative for 13+.
Government ID or credit card
Chat and voice permissions, content maturity, spending caps, friend-request limits. Adults are blocked from contacting under-16s by default.
Snapchat Family Center
Parent invites, teen must actively accept. Teen can leave at any time (parent is notified).
None beyond account ownership
Friend list, who was messaged in the last 7 days, time spent, Snap Map controls, report action. Never message content.
Discord Family Center
Teen generates a code, parent scans it. Both must opt in; a parent cannot force it.
None beyond account ownership
7-day activity summaries, who was messaged, servers, spending, screen time. Explicitly not message content.
Instagram Teen Accounts
Supervision through Meta Family Center; protective defaults applied automatically regardless of linkage.
None beyond account ownership
Alerts on concerning searches, time-spent data, settings control.
SportsEngine / TeamSnap
Guardian-linked household account; the guardian is added to the athlete and is typically the account holder.
Account ownership; club-level background checks for adults
Full roster, schedule, and team communication visibility as the account holder.
Strava (under-18)
No parental linkage at all.
n/a
Nothing. Instead: hard, unchangeable defaults — followers-only profile, excluded from leaderboards, first and last 400m of every activity hidden, excluded from heatmap, and messaging disabled outright.

The consensus, and where Groundwork sits. Three patterns recur and Groundwork adopts all three: linkage is a two-sided handshake rather than an email address typed in by the minor; the guardian receives metadata and structural controls rather than message content; and protective defaults apply to the minor account regardless of whether a guardian ever engages. Groundwork departs from the consensus in exactly two places, both deliberate. First, it requires real consent verification (ID check, card-authorization fallback) where most social products require only account ownership — Roblox is the precedent, and the justification is that this product arranges physical meetings between a minor and other people, which none of the social comparison set does. Second, it grants guardian read access to minor-to-adult threads, which no product in the set does — because none of them is subject to the youth-sport safeguarding standard in §15.3, and Groundwork’s core use case is.
Strava is the instructive counter-example. The closest functional analogue in the set solves the same problem by simply switching messaging off for under-18s and excluding them from leaderboards entirely. That is a legitimate design and it is stricter than Groundwork’s. It is worth knowing that if the guardian-consent machinery ever proves too heavy for the pilot, disabling minor-to-adult connection entirely is a smaller, well-precedented product, not a failure.
The regulatory floor, including Virginia
Virginia is the launch state, and its headline minor-social-media law is currently unenforceable. SB 854 would have required platforms to identify under-16 users and cap their daily use at one hour absent parental consent. On 27 February 2026 the Eastern District of Virginia preliminarily enjoined it on First Amendment grounds in the NetChoice challenge. Groundwork therefore has no time-limit obligation in Virginia today. Do not build to it — but do not assume it is gone either; the injunction is preliminary.
The court’s reasoning is strategically useful. It signalled that blunt access restrictions are constitutionally fragile while design-based and parental-empowerment approaches are far more likely to survive. Groundwork’s model — protective defaults plus guardian empowerment, rather than blanket lockouts — is on the favourable side of that line, which is worth stating in the App Store submission notes and to the attorney.
Virginia’s VCDPA remains fully in force, including its classification of precise geolocation as sensitive data. That is already reflected in §5.1, and it is a further reason minors are excluded from location sharing entirely (§15.8).
The FTC’s amended COPPA Rule has been in full effect since 2025 with an enumerated list of approved verifiable-parental-consent methods. Groundwork’s under-13 refusal keeps it outside COPPA’s core consent regime, but the ID-check and card-authorization methods used here are drawn from that list deliberately, so the mechanism is defensible if a regulator ever asks why a 13-year-old’s guardian was verified this way.
The state App Store Accountability Acts — Texas from 1 January 2026, with Utah, Louisiana and California following — place obligations directly on developers to receive and act on app-store age and parental-consent signals. That is what the platform age-signal read below is for; it is compliance infrastructure, not a nice-to-have.
What is collected at signup for a 13–17 account
Date of birth, by date picker, as already specified in §2.8. A birthdate of 13–17 sets age_status = minor and puts the account into consent_status = pending.
Guardian first and last name, guardian email address, and guardian mobile number. All three are required; the account cannot proceed without them.
The platform age signal, where available — Apple’s Declared Age Range API on iOS 26 and later, and Google’s Play Age Signals API on Android. Both return an age bracket plus whether the declaration was self-declared or guardian-declared. Record the bracket and the declaration method. Do not cache these values long-term; query and decide, per both platforms’ own guidance.
If the platform signal reports a guardian-declared bracket, record that as corroboration — but still run Groundwork’s own linkage below, because the platform signal establishes consent to install the app, not consent to the specific things this app lets a minor do.
The two design questions this resolves
Consent is collected at signup, not at first adult connection. The whole comparison set front-loads it, and the alternative is worse in practice: a minor who has built a profile and logged three weeks of training, then hits a consent wall the first time a teammate scans their code, is a minor with a strong incentive to lie about their age. Front-loading also means the fail-closed pending state (below) is the account’s starting condition rather than a mid-flow interruption.
Both blanket consent AND per-connection approval, not one or the other. Onboarding consent establishes the guardian relationship and unlocks the account; per-connection approval then governs each individual minor-to-adult match and defaults to ON. The reasoning is that these two things are not the same decision — agreeing that your 15-year-old may use a training app is not the same as agreeing they may connect with one specific 40-year-old. A guardian who finds the per-connection prompts tiresome can switch them off (§15.4); a guardian who never touches settings gets the protective default. Minor-to-minor connections never require approval.
How the guardian is contacted and verified
Groundwork emails and texts the guardian a single-use link. The message names the minor, states plainly what the app does — including that it arranges in-person training meetups — and does not require the guardian to install anything to read it.
The guardian opens the link and creates or signs into a Groundwork guardian account. A real account, not a click-through: this is the anchor for everything the guardian later controls, and a one-click email confirmation is not a defensible consent record for an app that arranges in-person meetings between a minor and other people.
The guardian completes one verification step. Default: a Stripe Identity document check, which reuses machinery already in the build, costs $1.50, and produces a far stronger record than an email click. Fallback where an ID check is refused or fails: a $0.50 authorizing charge to a payment card, immediately reversed. Both are recognized approaches; the ID check is the one to implement first.
The guardian reviews and accepts a short consent screen naming what they are agreeing to, and sets the initial controls in §15.4.
On completion the link is created, consent_status becomes granted, and the minor account unlocks. Both parties are notified.
A guardian may be linked to more than one minor, and a minor has exactly one active guardian link at a time. Changing guardian requires the new guardian to complete the same flow.
A guardian can revoke consent at any time from their own account. Revocation immediately returns the minor to consent_status = revoked, which has the same restrictions as pending, and ends every active minor-to-adult connection.
What happens if consent is never completed — fail closed
A pending or revoked minor account is severely restricted. These limits are enforced at the query layer, not in the UI.
A pending-consent minor CAN
A pending-consent minor CANNOT
Complete their own profile and set sport tags
Open Discover, in list or map form
Log activities manually, by live recording, or by device sync
Scan or be scanned by any QR code — personal or club
Create plans and templates for themselves
Redeem a typed invite code
View their own history, PRs, and dashboards
Send or receive any chat message
See the guardian-consent status screen and re-send the invitation
Be added to any plan as a partner, or appear in any club roster
Receive push notifications about consent only
Appear in any search, board, or profile visible to another user

This is deliberately stricter than the unverified adult state. Unverified means the age is unknown; pending means we know it is a minor and have not yet reached their guardian.
Time limits: at 14 days without completed consent the account is soft-locked to the consent screen only, with a reminder to both the minor and the guardian. At 30 days the account and its data are deleted, with notice at each step. Locally logged activity can be exported by the minor before deletion.
15.3 · Guardian visibility of minor-to-adult threads
This is the single most important thing the research surfaced, and it changes a product decision. In organized US youth sports, the governing safeguarding standard requires that all electronic communication between an adult participant and a minor athlete be open and transparent — meaning another adult, typically the minor’s parent or guardian, is included on the communication. Private one-to-one adult–minor messaging is not permitted, with no exception for sport apps. A coach using Groundwork’s 1:1 chat as currently specified would be in breach of their own governing body’s policy.
Requirement: any chat thread between a minor and an adult includes the minor’s linked guardian as a silent read-only participant. The guardian is a real row in thread_participants with role = guardian_observer. They can read the thread and cannot post to it.
This is disclosed prominently and identically to both parties at the moment the match is formed, and a persistent, non-dismissible banner sits at the top of the thread reading that the minor’s guardian can see this conversation. Nobody is ever unaware they are being observed.
Minor-to-minor threads are NOT guardian-readable. No safeguarding standard asks for it, and reading two teenagers’ conversation to each other is disproportionate. Guardian visibility is scoped precisely to the asymmetric case it exists for.
This turns Groundwork from a tool that would put a compliant coach in violation into one that satisfies the standard by default, which is worth saying explicitly in club-facing marketing and in the App Store submission notes.
15.4 · What the guardian sees and controls
Modelled on the consensus across teen-supervision products: guardians get metadata, structural controls, and the ability to withdraw — not surveillance of content, beyond the §15.3 case that a safeguarding standard specifically requires.
The guardian CAN
The guardian CANNOT
See the list of people the minor is connected to, and which of them are adults
Read minor-to-minor chat threads
Read minor-to-adult chat threads (§15.3)
Post in any thread
Approve or deny each individual minor-to-adult connection before it becomes active — on by default
See the minor’s activity log detail, notes, or photos
Turn off the minor’s ability to form adult connections entirely
See the minor’s precise location — it is never collected (§15.8)
See club memberships and the schedule of upcoming sessions, including where and when
Change the minor’s training data or delete their activities
Revoke consent, which suspends the account and ends adult connections
Impersonate the minor or post as them

Session schedule visibility is deliberate and is the one place this goes further than a general-purpose social product would. This app produces real-world meetings between people; a guardian knowing that their 15-year-old is meeting someone at Long Bridge Park at 8am Saturday is the minimum reasonable disclosure.
Per-connection approval defaults to on. A guardian can turn it off — accepting connections silently — but they have to choose that.
15.5 · Person-to-person QR: the matching rules
Minor to minor: allowed freely. Two 13–17 accounts, subject only to the ordinary mutual confirm tap and to both accounts having completed consent. This is the teammate case and it carries no additional constraint.
Minor to adult: the adult must be fully adult, never self_attested_adult. Any adult who connects with a minor has completed a Stripe Identity government-ID check and has a real identity on file. The population of adults who can reach a minor at all is therefore a verified, accountable one. A coach completing an ID check before connecting with their team is a reasonable thing to ask, and arguably what a parent would expect. Cost: $1.50 per adult.
Minor to adult: an existing shared club membership is required. Both accounts must already appear in club_memberships for the same club before the match can be created. This is the load-bearing rule. It costs the stated use case essentially nothing — the coach and the teammates are in the team’s club, and if that club is not on Groundwork yet, creating it is a step the coach would take anyway. It closes the remote-stranger path almost entirely, because a stranger would first have to get into the minor’s actual club, which is an organizer-mediated, socially visible act. And it is an EXISTS check in the match-creation path, so it is cheap and trivially auditable.
Minor to adult: the guardian approves the specific connection before it becomes active, unless the guardian has turned that requirement off (§15.4). Until approved, the match sits pending and no thread opens.
An unverified account can never match with a minor by any path, since person-to-person QR is blocked for unverified entirely (§5.5).
15.6 · The minor’s own QR code
A minor’s personal code is short-lived and rotating: a fresh identifier roughly every 60 seconds, displayed with a visible countdown, valid only while displayed. A code that expires in a minute cannot be texted across town.
This is a deliberate, narrow exception to the static-codes decision in §3, and the exception is warranted. Static codes were justified because club codes get printed on flyers and bibs, and because the confirm tap was considered sufficient defense for personal codes. Neither argument holds here: nothing about the printed-flyer case applies to a personal code, and the confirm tap does not help when the minor taps confirm believing the scanner obtained their code legitimately. Club codes stay static. Adult personal codes stay static. Only a minor’s personal code rotates.
A minor’s code is display-only. No share sheet, no save-image, no copyable identifier text, no screenshot-friendly presentation. Rotation alone still permits a real-time relay — an adult on a video call asking the minor to hold up their code — so removing the export affordance matters alongside it.
For a minor-to-adult pair, the minor is always the scanner. The adult presents their code and the minor’s device reads it, never the reverse. The minor’s own code therefore never needs to be shown to an adult at all, which removes the shareable-artifact problem for the asymmetric case almost entirely, independent of rotation. It also matches how the interaction actually happens in person: the adult holds up their phone and the young person scans it.
15.7 · Review queue and rate limit
A distinct, higher-friction confirm screen for minor-to-adult matches. Not the same one-tap confirm as adult-to-adult. It names the adult, states plainly that they will be able to message and schedule meetups, states that the guardian will be able to read the conversation, and requires an explicit acknowledgment. This is the one moment where a beat of deliberation is worth the friction.
Every minor-to-adult match writes a trust-and-safety review queue entry (minor_adult_matches, §4.4), recording both accounts, the shared club, and how the match was formed. This is visibility, not a block — the match is live as soon as it is approved. At pilot scale this is a handful of rows a week and the founder can read all of them, which is exactly the signal that tells you early whether the feature is being used as intended.
Minor-to-adult match formation is rate-limited to three per rolling week per minor account. Attempts above the cap are queued for review rather than refused outright, so a legitimate burst — a whole coaching staff at one practice — still resolves, just not silently. This is a deliberate carve-out from §3’s blanket deferral of scan-rate limiting: that deferral was justified by the absence of usage data, and that justification does not extend to a child-safety vector where the cost of being wrong is asymmetric and a conservative default costs almost nothing.
15.8 · Minors and location — hard rule
A minor account can never appear on the live map. profiles.live_map_visible_until stays null for any minor, enforced server-side; the “Show on live map” card does not render on a minor Profile; and the map-pin query excludes minors unconditionally, independent of that column.
A minor account can never share check-in location. session_participants.checkin_opt_in stays false for a minor, no checkin_locations row may be written for or about a minor, and the checkin_nudge push event never fires for a session that includes one.
Precise or near-precise location sharing between a 13-year-old and anyone else does not exist in v1. Allowing minor person-to-person matching raises the stakes here rather than lowering them, since the population of adults who can see a minor’s context is now larger than zero.
Full rules in §5.8; tested by S20.
15.9 · The consolidated gate
Every check, in order, for creating a person-to-person match where either party is a minor. Implement this as one server-side function that every entry path calls — QR scan, invite code, and any future path — rather than as scattered conditionals.
Both accounts exist, neither is banned (§5.4).
The minor’s consent_status is granted. If pending or revoked, refuse (§15.2).
If the counterparty is also a minor: allow, subject only to the mutual confirm tap. Stop here.
If the counterparty is unverified: refuse (§5.5).
If the counterparty is self_attested_adult: refuse. Only a fully ID-verified adult may match with a minor (§15.5).
A shared club_memberships row exists for both accounts. If not, refuse with an explanation naming the club requirement (§15.5).
The minor has not exceeded three minor-to-adult matches in the trailing seven days. If they have, queue for review rather than refusing (§15.7).
The scan direction is minor-scans-adult. If the request came from the adult scanning the minor’s code, refuse (§15.6).
Present the higher-friction confirm screen and require explicit acknowledgment (§15.7).
If guardian per-connection approval is enabled, hold the match pending and notify the guardian. It becomes active on approval (§15.4).
On activation: create the match, write the minor_adult_matches review row, and add the guardian to the thread as guardian_observer with the disclosure banner (§15.3).

16. Building Without a Mac: Pipeline, Cost, Devices & Timeline
NEW IN THIS REVISION — New section. The founder’s development machine is a Windows laptop (AMD Ryzen 7 5800H, 16 GB RAM, x64) — there is no Mac. Everything below was verified against current 2026 documentation rather than assumed.
16.1 · The short version
A Windows-only developer can build, test, and ship this iOS app end to end. Nothing in the pipeline requires local macOS. That is true specifically because the project is on Expo with EAS — it would not be true of a bare React Native project. The framework choice in §13 was made for other reasons and has now become load-bearing for a different one.
Three things change as a consequence, and none of them changes the plan: a small new recurring cost (§16.3), a probable one-time device purchase (§16.4), and a modest schedule allowance for cloud-build latency (§16.5).
16.2 · The Mac-free iOS pipeline, verified
Step
Needs a Mac?
How it works from Windows
Compiling the iOS app
No
EAS Build compiles on Expo’s cloud macOS infrastructure. The founder’s machine never runs Xcode; it runs a CLI command and waits.
Apple signing credentials
No
EAS generates and manages the distribution certificate and provisioning profiles from the Apple Developer account. This is the step that historically forced people onto a Mac, and it is fully handled.
Registering a test iPhone
No
eas device:create produces a registration URL opened on the phone itself. Ad hoc provisioning is then handled automatically during the build.
Installing on a physical iPhone
No
The EAS dashboard produces an install link and QR code; scan it with the phone’s camera and the development build installs. iOS 16+ requires Developer Mode enabled on the device, which is a toggle in Settings.
Uploading to TestFlight / App Store
No
EAS Submit explicitly supports macOS, Linux and Windows, with no Xcode and no Transporter. It authenticates with either an Apple ID plus app-specific password, or an App Store Connect API key.
Day-to-day JavaScript iteration
No
Identical to a Mac. Metro runs locally, the development build on the phone connects over the network, and Fast Refresh applies changes in seconds. This is where most development time goes and it is completely unaffected.
iOS Simulator
YES — unavailable
There is no iOS Simulator on Windows and no legitimate way to run one. This is the single real capability gap, and it is why a physical iPhone matters (§16.4).

The practical consequence of the missing simulator: a Mac owner can check an iOS layout change in about ten seconds without touching a phone. On Windows every iOS check happens on the physical device. That is a workflow difference, not a blocker — and for this app specifically, much of what needs checking (GPS recording, QR camera scanning, HealthKit, push) only works properly on a real device anyway, so a simulator would have been of limited use here.
16.3 · EAS Build — a new recurring cost
This is the one genuinely new line item. A Mac owner compiles iOS locally for free; on Windows every iOS binary is a cloud build. Current EAS pricing:
Plan
Cost
Included
Notes
Free
$0
15 iOS + 15 Android builds/month
Low-priority queue, 1 concurrent build, 45-minute build timeout. Genuinely usable.
Starter
$19/mo
$45 of build credit
High-priority queue, 2-hour timeout, large workers available. Then usage-based.
Production
$199/mo
$225 of credit
2 concurrent builds. Far beyond what a solo pilot needs.
Per-build (overage)
—
iOS medium ~$2, iOS large ~$4; Android medium ~$1, large ~$2
What a build costs once credit is exhausted.

How many builds this project actually burns
A new build is needed only when native configuration changes — adding a native library, changing a config plugin, changing permissions strings or entitlements, or bumping the Expo SDK. JavaScript and UI changes need no build at all; they hot-reload into the existing development build.
That makes consumption extremely uneven across the fifteen phases in §7. Phases 1, 3, 9, 10 and 11 (project setup, design system, the aggregator, Stripe Identity, push) touch native config repeatedly and could plausibly use 10–25 iOS builds in a month. Phases 4 through 8 and 12 through 13 are almost entirely JavaScript and may use two or three.
Recommendation: run on Free, and subscribe to Starter ($19/mo) only during native-heavy months, cancelling in between. The $45 credit covers roughly 22 medium iOS builds, and the high-priority queue is worth more than the credit on a day when a build is blocking progress. Budget it as a standing $19/mo for planning purposes and treat any month it is not needed as a saving.
Budget reconciliation
Figure
Before
After
Monthly burn, day one
~$470–500/mo
~$489–519/mo (+$19)
Monthly burn, later
~$700–750/mo
~$719–769/mo (+$19)
Floor budget (~26 weeks)
~$7,900–11,200
~$8,000–11,400 (+$114 at $19/mo for six months; call it +$250 with occasional overages in heavy months)

Plainly: this does not materially change either figure. EAS Build adds roughly 3–4% to the monthly burn and around 1–3% to the floor budget. It is the smallest line item in the stack — an order of magnitude below the $450/month aggregator. The absence of a Mac is a workflow constraint, not a budget problem. Note also what is NOT being spent: a Mac capable of iOS development is $600 second-hand at the very bottom end and $1,000-plus new, so the cloud-build path is cheaper than buying one for at least the first three to four years.
16.4 · Device testing — settled
NEW IN THIS REVISION — Resolved. The founder owns an iPhone 15 Pro Max with Developer Mode already enabled and TestFlight already installed. This section previously laid out options for a founder who might not have an iPhone; those are now moot.
The iPhone 15 Pro Max is the primary iOS test device from phase 1. Register it once with eas device:create, install the development build from the QR code the EAS dashboard produces, and from then on the workflow is identical to a Mac-based one: Metro on the laptop, Fast Refresh on the phone, changes visible in seconds.
Developer Mode is already on and TestFlight is already installed, so the two setup steps that usually trip people up are done. The device comfortably exceeds the iOS 26 floor needed for the Declared Age Range API in §15.2, and it has the full sensor set — GPS, camera, and Apple Health — that this app’s core features actually need.
Android is the secondary platform, tested on the laptop’s emulator or a borrowed handset. Nothing about Android is on the v1 critical path (§2.12).
No device purchase is required, and the used-iPhone budget line raised in an earlier revision is withdrawn. Switching to Android-first sequencing was considered as a workaround for not having an iPhone; it is moot and iOS-first stands.
16.4a · Expo Go is not the testing path
NEW IN THIS REVISION — Added because the founder has Expo Go installed and could reasonably assume it is how the app gets tested. It is not, beyond the first day or two, and losing time to that would be an avoidable frustration.
Expo Go is a fixed sandbox app, and this project outgrows it during phase 1. Its native runtime is compiled once, by Expo, before you download it — so it can only load native modules that Expo chose to bundle. Any library whose native code is not already inside it simply cannot run there. This project depends on several: the HealthKit library, the Spike aggregator SDK and its config plugin, and Stripe Identity. None of them will ever work in Expo Go, no matter what is written in JavaScript.
Expo’s own guidance is stronger than “it depends”: they recommend a development build for any real-world app even when it uses no native libraries at all, because Expo Go also fails to reproduce production behaviour for push notifications, OAuth, deep and universal linking, maps, and anything that passes an API key to native code. Groundwork uses four of those five.
Expo Go also runs under its own generic bundle identifier rather than the app’s, so anything keyed to the real identifier — push tokens, the Apple sign-in flow, deep links — behaves differently or not at all.
What to actually do: Expo Go is fine for the very first scaffolding session, to confirm the toolchain works and see something on the phone within minutes. From the moment the first native dependency is added — which is phase 1, deliberately and immediately (§7) — the development build installed through EAS is the only thing that runs the real app. After that, Expo Go should be ignored entirely; it is not a fallback and switching back to it will produce confusing failures rather than useful ones.
A build session must not issue Expo Go instructions past the first session, and must not diagnose a native-module error by suggesting a return to Expo Go.
16.5 · Timeline impact
Honest read: allow one to two weeks, taking the pilot schedule from roughly 25–26 weeks to 26–28. It would be dishonest to leave the estimate untouched, and equally dishonest to inflate it.
Where the time goes: a Mac owner compiles iOS locally in a few minutes and iterates on native configuration quickly. On Windows each of those iterations is a cloud build — commonly 10–25 minutes of build time, plus queue time that is unbounded on the free tier’s low-priority queue. A native config error therefore costs a coffee break rather than a moment.
Where the time does NOT go: everything else. JavaScript, UI, business logic, RLS policies, and the entire §12 test suite are unaffected. That is the large majority of the fifteen phases.
Concentration matters more than the total: the delay lands almost entirely in phases 1, 3, 9, 10 and 11. Phases 4 through 8 and 12 through 13 run at full speed.
Two things reduce it materially. First, subscribing to Starter during native-heavy phases buys the high-priority queue, which is the larger half of the latency. Second — and more important — the phase-1 discipline of installing and compiling every native dependency before any feature work (§7) is now worth several times what it was on a Mac. A native incompatibility discovered in phase 9 costs a day of cloud builds; the same problem found in phase 1 costs an hour.
16.5a · Testing the Garmin path — plan in place
NEW IN THIS REVISION — Updated. The founder has a Garmin-wearing beta tester already lined up, which closes most of what was previously an open risk. What remains is a timing instruction, and it matters.
The two halves of the Spike integration have very different testability. Apple Health runs through the mobile SDK on the founder’s own iPhone, so it can be exercised end to end with real workouts from day one. Garmin cannot be tested that way: it is a cloud-to-cloud provider integration where the user authorizes Garmin once and Spike then pushes activity to a server-side webhook (§2.12). Without a Garmin account producing activity, that webhook has nothing real to fire on.
A Garmin-wearing beta tester is already secured. That is the mitigation that matters and it is in hand, so the Garmin path is verifiable rather than speculative. The rest of this section is about using that tester well.
Bring them in at the START of phase 9, when the integration is first being wired — not at the TestFlight phase. This is the part that is still actionable and the easiest thing to get wrong. The entire value of having a tester secured is surfacing real-payload surprises while there is still time and context to handle them. A build session that defers Garmin testing to the beta phase throws that advantage away and converts a solved problem back into a late one.
The ask to make of them is small: connect their existing Garmin account once. Spike backfills historical data on first connection, so a single authorization yields a body of real past Garmin activity rather than only what they record that week. For testing payload parsing, de-duplication against Apple Health (§2.12), and auto-reconcile against a plan, that history is worth far more than a few fresh workouts — and it costs the tester about two minutes.
Write the webhook handler defensively regardless. Log the raw payload before parsing, tolerate unexpected or missing fields rather than throwing, and never let a malformed provider payload break a user’s log. This is good practice independent of testing, and it is what turns a first-contact surprise into a fixable log entry instead of an incident.
Residual risk, downgraded: the Garmin path is verifiable from phase 9 onward, provided the tester is brought in on time. The remaining exposure is scheduling, not capability — if the tester slips to the beta phase, the risk returns in full.
The Spike sales-call question about a sandbox or simulated-activity mode stays on the list but is no longer the first thing to ask. A real tester beats a sandbox for first-contact verification. A sandbox would still be useful later for regression testing without needing to bother a real person each time, so it is worth knowing whether one exists.
16.6 · Windows-specific issues that genuinely bite
Issue
What to do
The 260-character path limit
The most common real failure. Deeply nested node_modules paths break local Android builds (CMake/Ninja errors reading “Filename longer than 260 characters”). Enable Win32 long paths in Windows before starting, and keep the project near the drive root — C:\dev\groundwork, not a deep folder under Documents. This does not affect iOS, which builds in the cloud on Linux/macOS paths.
Antivirus scanning node_modules
Windows Defender scanning a folder with hundreds of thousands of small files makes installs and Metro startup dramatically slower. Add the project folder and the npm cache to Defender’s exclusion list. This is the single biggest day-to-day speed win on Windows.
Line endings
Set git config --global core.autocrlf true once, at setup. Otherwise scripts written on Windows can break in the Linux containers EAS builds inside.
File watching
Metro’s watcher is less efficient on Windows. Keeping the project out of OneDrive-synced folders matters — OneDrive and Metro fight over the same files and produce phantom rebuilds. Do not put the project in Documents if that folder is synced.
Case-insensitive filesystem
Windows treats Button.tsx and button.tsx as the same file; the EAS build container does not. An import that works locally can fail in the cloud. Be consistent about filename casing from the start.

GROUNDWORK · BUILD KICKOFF PACKAGE
Vendor Stack & Setup Guide
A step-by-step guide for setting up your development machine and real vendor accounts — written for someone with no coding background
Companion to: Structured Build Brief (Part 1 of this document)
Prepared: September 2026 · Revision 5

Before anything else: this is a Windows project
The development machine is a Windows laptop. There is no Mac, and none is needed. Any instruction anywhere that assumes macOS tooling — open Xcode, run pod install, archive and upload through Transporter, use the iOS Simulator — does not apply to this project and should not be followed. iOS builds happen in the cloud through Expo EAS; the founder’s machine never runs Xcode. Build Brief §16 verifies every step of that pipeline, §16.3 covers what it costs, and §16.6 lists the Windows-specific problems that genuinely bite. A build session should read §16 before issuing any setup instruction.
The one real gap is the iOS Simulator, which does not exist on Windows. iOS work is checked on a physical iPhone instead. If the founder does not own one, Build Brief §16.4 sets out the options and costs before that becomes a blocker.
How to use this guide
This guide has two halves. Section 0 sets up your Windows machine so a Claude Code session has somewhere to build. Sections 1 through 6 then walk through creating a real account or project with each vendor Groundwork depends on, in the order it makes sense to do them. For each vendor you'll find: what to sign up for, which plan/tier to pick (matching the budget decisions already made), what credentials get generated, and a one-line reminder of what that vendor is actually for. None of the vendor signups require writing code — it's all account creation and clicking through setup screens in a web browser.
A note on security: every “key” or “secret” mentioned below should be treated like a password. Don't post it in Slack, email, or a public document. Store them somewhere private (a password manager, or a local, non-shared notes file) and give your Claude Code session access to them the way it instructs — typically as environment variables or a local, git-ignored configuration file, never committed into code that gets shared or published.
Setup order
Your development environment (Windows) — Node.js, Git, GitHub, Claude Code, Android Studio, EAS
Supabase — the foundation everything else plugs into
Apple Developer Program — confirm existing access (already held)
Expo / EAS — builds, device installs, and TestFlight uploads
Stripe Identity — identity verification
Stream Chat — in-app messaging
Spike — the wearable data aggregator (Garmin/HealthKit)

0. Your development environment (Windows)
NEW IN THIS REVISION — Rewritten in this revision. An earlier version of this guide opened by requiring a Mac. The founder’s machine is a Windows laptop, and the whole section was wrong.
You do not need a Mac. You can build, test on a real iPhone, and publish to the App Store entirely from your Windows laptop, because Expo compiles iOS in the cloud on its own Apple hardware. Section 16 of the Build Brief verifies each step of that pipeline. The one thing Windows cannot do is run the iPhone Simulator, which is why a physical iPhone matters — see Build Brief §16.4.
Everything here is a one-time setup. Budget an afternoon. If a step fails, that is normal — ask your Claude Code session to read the error and fix it; that is exactly what it is good at. You do not need to understand these tools deeply, only to have them installed and working.
0.1 · Your machine
AMD Ryzen 7 5800H, 16 GB RAM, 64-bit Windows. That is comfortably enough for this project. Keep 40–60 GB of free disk space — Android Studio and the Android SDK are large.
Work natively in Windows, not in WSL2. Claude Code now runs natively on Windows with no WSL required, and the entire Expo toolchain is plain Node.js that runs natively too. WSL2’s advantage is Linux build tools, which this project does not use — and it would add real friction, because Android Studio and its emulator run on the Windows side, so a project living inside WSL2 has to bridge across the boundary to reach them. Native is simpler and there is nothing to gain by complicating it.
You will also want a phone to see the app on. See Build Brief §16.4 — if you do not already own an iPhone, that section lays out the options and costs.
0.2 · Prepare Windows itself
Three settings that prevent the most common problems. Do these before installing anything.
Enable long file paths. Open the Start menu, type “regedit”, and open Registry Editor. Navigate to HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem, find LongPathsEnabled, and set its value to 1. Without this, Android builds fail with a confusing “filename longer than 260 characters” error. If you are uneasy editing the registry, ask your Claude Code session to do it — this is a well-known one-line fix.
Choose a short project location. Use C:\dev\groundwork. Do NOT put the project in Documents, Desktop, or anywhere synced by OneDrive — OneDrive and the development server fight over the same files and cause phantom rebuilds.
Add an antivirus exclusion. Open Windows Security → Virus & threat protection → Manage settings → Exclusions, and add the C:\dev folder. The project contains hundreds of thousands of small files and Defender scanning all of them makes everything noticeably slower. This is the single biggest day-to-day speed improvement on Windows.
0.3 · Node.js, Git and an editor
Node.js runs the development tooling. Git tracks every change to your code. The editor is where the code lives, though Claude Code will do most of the typing.
Install Node.js: download the LTS installer from nodejs.org and run it. Then open PowerShell and check it worked — node -v and npm -v should each print a version number.
Install Git: download from git-scm.com and run the installer, accepting the defaults.
Set your Git identity once, in PowerShell: git config --global user.name "Your Name" then git config --global user.email "you@example.com".
Set line endings once: git config --global core.autocrlf true. This prevents scripts written on Windows from breaking inside Expo’s Linux build machines.
Install Visual Studio Code from code.visualstudio.com. You will mostly read code rather than write it, but you need somewhere to look at files.
0.4 · GitHub
GitHub is where your code lives online — your backup, your history, and the place a future collaborator or auditor would look.
Create a free account at github.com if you do not have one.
Create a new repository named groundwork and set it to Private. Do not add a README or a .gitignore; the project setup creates those.
Install the GitHub CLI so your Claude Code session can push code without you copying anything by hand: in PowerShell, run winget install --id GitHub.cli. Then run gh auth login and follow the browser prompts.
0.5 · Claude Code
Open PowerShell as Administrator and run: irm https://claude.ai/install.ps1 | iex
Make the project folder and move into it: mkdir C:\dev\groundwork then cd C:\dev\groundwork
Run claude — the first run asks you to sign in through your browser.
Everything from here happens by talking to that session in plain English, inside that folder. It can read every file there, so this is where the docs/ folder from Build Brief §11 goes.
0.6 · Android Studio (for the Android emulator)
This gives you an on-screen Android phone for testing the secondary platform. It is optional at the start — nothing about Android is on the v1 critical path — but it is easier to install now than mid-build.
Enable virtualization in your laptop’s BIOS. Restart, press the BIOS key during startup (usually F2 or Delete on most laptops), find the setting called SVM Mode or AMD-V, and enable it. On AMD processors the emulator cannot run without this.
In Windows, open “Turn Windows features on or off” and tick Windows Hypervisor Platform. This is what the Android emulator uses on AMD hardware. You do NOT need Hyper-V.
Install Android Studio from developer.android.com/studio and let its setup wizard install the SDK and a default emulator image.
An honest note about 16 GB of RAM. Windows, the emulator, the development server, a browser and an editor together will use most of it. It will work, but the machine will feel slow with everything open at once. For day-to-day work you will have a much better time testing on a physical phone over USB — and for this app specifically that is the right choice regardless, because GPS recording, camera QR scanning and health-data sync either do not work or do not work realistically in an emulator. Treat the emulator as a way to check layouts on a different screen size, not as your main testing surface.
0.7 · Expo and EAS
EAS is what makes all of this possible without a Mac — it compiles the iOS app on Expo’s own Apple machines and hands you back a finished build.
Create a free account at expo.dev.
In PowerShell: npm install -g eas-cli, then eas login.
Plan: start on Free — 15 iOS and 15 Android builds a month, which genuinely covers quiet stretches. Expect to subscribe to Starter ($19/month) during the phases that touch native code, mainly for the faster build queue, and cancel it in between. See Build Brief §16.3.
0.8 · Creating and running the app
Your Claude Code session will do these; they are listed so you know what you are looking at.
Create the project: npx create-expo-app@latest groundwork, then npx expo install expo-dev-client.
Get it onto your iPhone 15 Pro Max: register the phone with eas device:create (it gives you a link to open on the phone), then run eas build --profile development --platform ios. The build runs in the cloud and takes 10–25 minutes. When it finishes, Expo shows a QR code — scan it with the phone’s camera and the app installs. Developer Mode is already enabled on your phone, so that step is done.
Important — Expo Go is not how you test this app. You already have Expo Go installed, and it is genuinely useful for the very first session: it will show you something on your phone within minutes of starting. But Expo Go is a fixed app that Expo built in advance, so it can only run features Expo put inside it. This project needs Apple Health, the Spike wearable SDK and Stripe Identity, and none of those can ever run in Expo Go. Push notifications and sign-in links also behave differently there than in the real app. As soon as your Claude Code session adds the first of those — which happens in phase 1, on purpose — you switch to your own development build, installed by the QR code above, and from then on Expo Go is not used again. If something stops working and someone suggests going back to Expo Go, that is the wrong direction.
Then work day to day: npx expo start --dev-client on the laptop connects the phone to whatever code you are currently editing. Changes appear on the phone in seconds. You only need another cloud build when native configuration changes — adding a library, changing permissions — not when changing screens or logic.
For Android: npx expo run:android with the emulator open, or with a phone plugged in over USB.
Later, for testers: eas build --profile production --platform ios then eas submit sends the build to TestFlight, where up to 100 pilot users can install it. No Mac, no Xcode, no Transporter at any point.
0.9 · Keeping keys safe
Every key from sections 1–6 goes in a file called .env in the project folder, one per line, and that file must be listed in .gitignore so it is never uploaded to GitHub. Ask your Claude Code session to confirm this before your first commit.
For keys that EAS needs at build time, use eas secret:create rather than putting them in a file that gets uploaded.
If you ever think a key has leaked, every vendor below lets you roll it — generate a new one and the old one stops working. Do that immediately rather than hoping.

1. Supabase — database, accounts, and login
What it's for, in one line: Supabase is where all of Groundwork's data lives — user accounts, profiles, matches, chat metadata, and everything else — plus it handles email/phone sign-in.
What to do
Go to supabase.com and click “Start your project.” Sign up with an email address (or GitHub account) — use whichever email you want tied to Groundwork's business accounts going forward.
Once signed in, click “New project.” Give it a name (e.g. “groundwork-pilot”), set a strong database password when prompted (store this immediately — it's shown only once), and pick a region physically close to your users (US East is the right choice for a DC-Metro/Virginia pilot).
Plan to select: start on the Free tier. It covers up to 50,000 monthly authenticated users and 500MB of database storage — comfortably more than a 150–500-user pilot needs. Upgrade to Pro ($25/mo) later only if you outgrow the free tier's limits or want daily backups.
Wait a few minutes for the project to finish provisioning (Supabase shows a progress screen).
Credentials you'll need to save
In your new project, go to Project Settings → API. You'll see a Project URL and two keys: an anon/public key and a service_role/secret key.
Project URL and anon key are safe to use in the mobile app itself — hand both to your Claude Code session.
The service_role/secret key is highly sensitive — it bypasses all your Row-Level Security rules. Never put it in the mobile app or share it outside a secure server-side context. Store it privately and only use it where the build explicitly calls for server-side/admin access.
Also note your database password from setup — you'll need it if you ever connect a database tool directly (e.g. via the “Connect” button in Project Settings).
2. Apple Developer Program — confirm existing access
What it's for, in one line: Apple's paid developer program is required to actually publish Groundwork to the App Store and to test it on real devices via TestFlight.
What to do
You already have an active Apple Developer Program membership ($99/yr) — no new signup needed. It is required even though you have no Mac: EAS builds and submits on your behalf, but it does so using your membership.
Confirm you can log into developer.apple.com and see your membership as active. If you're not sure of the login, this is worth checking now rather than discovering an issue mid-build.
Credentials you'll need to save
Your Apple ID (the email used for the developer account) and password. You will sign in with it when Expo's EAS tool asks, and EAS then generates and manages the distribution certificate and provisioning profiles for you. This is the step that used to force people onto a Mac, and it is fully handled from Windows — see Build Brief §16.2.
No app-specific setup is needed yet — registering the app's bundle identifier and App Store Connect record happens later in the build sequence (see the Build Brief, Section 7, step 13 and the Playbook's App Store submission section).
3. Expo / EAS — builds, device installs, and submission
NEW IN THIS REVISION — New vendor entry, following the framework decision in Build Brief §13.
What it's for, in one line: Expo builds the app on its own servers, installs it on your phone from a link, manages Apple signing certificates for you, and uploads finished builds to TestFlight.
What to do
Go to expo.dev and create a free account with your email.
Create an organization/account name you're happy to keep — it becomes part of your project's identifier.
Plan to select: the Free tier. It includes a monthly allowance of cloud builds, which is enough for a pilot if you build deliberately rather than constantly. The paid Production tier (currently around $99/mo) is worth revisiting only if build queue times become a real bottleneck near launch. Building locally on your Mac is always free and unlimited.
In Terminal: npm install -g eas-cli, then eas login.
Credentials you'll need to save
Your Expo account login. There is no key to copy — EAS authenticates through the CLI. If you want automated builds from GitHub later, generate an access token in your Expo account settings and store it the same way as the other secrets.

4. Stripe Identity — ID verification
What it's for, in one line: Stripe Identity checks a government ID against a live selfie before a user's first in-person 1:1 meetup, so Groundwork can confirm a real, matching person is behind each account — and, per Build Brief §2.8, it is also what turns an account's age status from self-attested to verified adult.
What to do
Go to stripe.com and click “Start now” / “Sign up.” You'll need basic business info — if your Virginia LLC isn't formed yet, you can start in Stripe's test/sandbox mode with just your own name and email, and add the real business entity details once the LLC exists.
Once inside the Stripe Dashboard, find “Identity” in the left-hand product menu (search “Identity” if it's not visible) and click to enable it.
Plan to select: Stripe Identity has no separate “tier” to choose — it's pay-as-you-go at $1.50 per verification, with the first 50 free. There's nothing to configure here beyond enabling the product; the pricing applies automatically as verifications happen.
Stay in Stripe's Test mode (a toggle in the dashboard) while the app is being built — test mode lets your Claude Code session build and test the whole verification flow without charging real money or requiring a real ID. Switch to Live mode only once you're ready to verify real pilot users.
Credentials you'll need to save
Go to Developers → API keys. You'll see a Publishable key and a Secret key, each with separate Test mode and Live mode versions.
The Publishable key is safe to use in the mobile app.
The Secret key must never appear in the mobile app — it belongs only in server-side code your Claude Code session builds (e.g. a Supabase Edge Function), never shipped to a user's phone.
You will also need a restricted key. On the same page, click “Create restricted key,” give it the Identity permission “Access recent sensitive verification results” set to Read, and nothing else. This is the only key that can read the date of birth from a completed ID check, which is what the age-verification step in Build Brief §2.8 depends on. Keep it server-side only, and note that by default it can read a verification's sensitive fields for 48 hours after that verification — which is ample, because the app reads the date of birth once, computes over-18 or not, and never stores it.
Keep the Test-mode and Live-mode keys clearly labeled and separate — mixing them up is a common and confusing mistake.
5. Stream Chat — in-app messaging
What it's for, in one line: Stream Chat powers every 1:1 chat thread in the app, including the structured cards (a shared workout template, a proposed session time, a check-in nudge) — not just plain text messages.
What to do
Go to getstream.io and click “Get started” / “Sign up.” Create an account with your email.
Once signed in, create a new “App” in the Stream dashboard (this is Stream's term for a project, similar to Supabase's “project”) — name it “Groundwork” or similar, and choose the Chat product when prompted.
Plan to select: the free “Build” tier, which covers up to 1,000 monthly active users and 100 concurrent connections — this covers a 150–500-user pilot's entire realistic year-one range. You will not need to enter payment details for this tier. Upgrade to the Start tier (~$399–499/mo) only once usage genuinely outgrows those limits.
Credentials you'll need to save
In your new Stream app's dashboard, go to the “App Settings” or overview page and find the API Key and API Secret.
The API Key is used in the mobile app to connect to Stream's service.
The API Secret must stay server-side only — it's used to generate secure chat “user tokens” server-side (typically from a Supabase Edge Function) and should never be embedded in the mobile app itself. Build Brief §5.6 requires those tokens to be minted from the database's own record of who is in a thread, never from what the app asks for.
6. Spike — wearable data aggregator (Garmin/HealthKit)
What it's for, in one line: This vendor normalizes fitness-tracker data — especially Garmin, the majority device among this pilot's runners per the founder's own knowledge of the community — into one consistent feed, so Groundwork can auto-reconcile a finished workout against a training plan without building and maintaining a separate integration for every watch brand.
Which one — decided
NEW IN THIS REVISION — Vendor selected in this revision. Previously this was left open between Spike and Terra.
Spike is the confirmed vendor. Terra remains a documented fallback if the commercial conversation with Spike goes badly. The deciding factor was Expo support: Spike ships a first-party Expo config plugin with its own documentation page, which configures the iOS HealthKit entitlement, the iOS permission strings, and the Android Health Connect permissions automatically. Terra ships an Expo demo project but no config plugin and no Expo documentation. Given that the whole build is Expo-based (Build Brief §13), that difference is worth more than a modest price difference.
One thing to understand before the sales call: Spike is two integration paths, not one. Its mobile SDK covers on-device sources — Apple Health on iPhone, Health Connect on Android. Garmin is a cloud-to-cloud integration handled server-side through Spike’s API and webhooks, where the user authorizes Garmin once through a connection flow. Since Garmin is the majority device in this pilot community, the server-side half is the half that matters most for you. Ask them to walk you through the Garmin authorization flow specifically.
What to do
Go to spikeapi.com and use the “Get started” / “Book a demo” option — this vendor's pricing and onboarding for a new, low-volume customer typically starts with a sales conversation rather than instant self-serve signup.
If Spike does not work out commercially, go to tryterra.co and use its contact-sales flow. Tell your Claude Code session if you switch — it changes the mobile integration work.
Plan to select: the entry-level paid tier (researched at roughly $450/month as of this round's pricing check) — this is now budgeted as a required pilot cost, not an optional upgrade, per the founder's round 21 correction on this community's actual device mix. There is no free tier, so budget for this payment to start once you begin the integration (Build Brief, Section 7, step 9) — you do not need to pay for it before that point.
Worth asking, though no longer urgent: do they offer a sandbox or test-provider mode that generates simulated Garmin activity? You can test Apple Health with your own iPhone, and you already have a Garmin-wearing beta tester lined up for the Garmin half — a real tester beats a sandbox for first-contact verification, so this is no longer the critical question it once was. A sandbox would still be useful later for repeat testing without having to bother that person each time. See Build Brief §16.5a; the important thing there is timing — bring the Garmin tester in at the start of the integration work, not at the beta phase.
Ask directly, when you talk to sales, about (a) whether a startup/early-stage discount applies, (b) how much lead time their own onboarding and Garmin API-access approval takes — this vendor relationship has more real lead time than a typical self-serve signup, and the Garmin side in particular can involve Garmin’s own approval, so starting the conversation early (even before the build reaches this integration step) is worth doing — and (c) confirmation that the Expo config plugin is current and supported on the Expo SDK version your build is pinned to.
Credentials you'll need to save
Once your account/contract is set up, the vendor's dashboard will issue an API key (and possibly a separate client ID/secret pair) — treat these the same as the other secret keys above: private, not shared, handed to your Claude Code session through a secure configuration method rather than pasted into a chat.
After setup: handing this off to your Claude Code build session
Once you've completed the steps above, you'll have a working Mac, a private GitHub repository, and a small set of URLs and keys — from Supabase, Expo, Stripe Identity, Stream Chat, and Spike. Do not paste the keys directly into a chat conversation with Claude. Instead, when you start the actual build session, tell it you have these credentials ready and ask it to set up the standard secure storage method for an Expo + Supabase project (a local .env file that never gets committed to version control, plus EAS secrets for anything needed at build time) — it will walk you through exactly where each key goes.
Then follow Build Brief §11: put the specification and the wireframe into docs/, write the short CLAUDE.md, and start with phase 1. Build one phase, verify it against §12, commit, and only then start the next.
