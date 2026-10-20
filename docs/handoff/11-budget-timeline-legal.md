# Budget, timeline, App Store path and legal

## Build path: Path A (confirmed)
Danny builds with Claude Code, then an independent engineer audits. No fractional CTO for now, so the audit is required, not optional.

## Budget (Sept 2026 pricing)
- **Floor: about $8.0K–$11.4K** to pilot launch, including EAS Build. Made up of:
  - Post-build audit **$3,000–6,000**: a fixed-scope Supabase RLS audit (~$1,650) plus a 15–25 hour review of auth and ID verification. Doesn't cover general logic, matching correctness, dependencies or a pen test. Don't narrow it further.
  - Legal review **$800–1,400**: ToS and Privacy at basic/mid tier; the Liability Waiver at full tier (~$665) because Virginia case law (Hiett v. Lake Barcroft, 244 Va. 191) disfavors some pre-injury waivers.
  - Virginia LLC at the $100 floor (DIY, self as registered agent).
  - Insurance: start the broker conversation early, bind before real public users meet. Likely BOP + Tech E&O + a specialist rider; real meetup coverage would be a differentiator (Meetup.com carries none).
  - Spike aggregator **~$450/month for about 7 months** (~$3,150), required because most pilot runners wear Garmin.
- **Monthly burn:** ~$470–500 at day one (aggregator plus Stripe Identity), rising to ~$700–750 once Stream Chat outgrows its free tier (likely the 100-concurrent-connection cap at evening run-club peaks). EAS adds $0–19.

## Timeline
From 6 Sep 2026, now **26–28 weeks** (Windows cloud builds added 1–2): legal and entity (weeks 1–3, parallel) → core build (1–10) → integrations: QR, HealthKit, Garmin, Stripe Identity, RLS (8–15) → audit (15–17) → fixes and QA (17–19) → TestFlight with 20–50 local run-club and gym testers (19–23) → App Store review with buffer (23–25). **Pilot launch target: late Feb to March 2027.** The race calendar favors late January or early February if the build allows.

## App Store path
- Apple Developer account already held.
- Age rating likely 17+ (UGC, stranger matching, location), separate from the app's own 13+/18+ gating.
- Privacy Nutrition Labels and `PrivacyInfo.xcprivacy`: Health, Location (precise and coarse, disclosed separately), Contact Info, User Content, Identifiers.
- Budget 1–2 weeks for review. Named rejection risks: background location (avoided by shipping foreground-only), HealthKit usage-string specificity, minor safety and UGC moderation visibility (Guidelines 1.2, 5.1.4). Give reviewers a demo account and explain the 13+/18+/QR model in review notes.
- Reminder from compliance: significant changes that affect minors must be filed with both stores (`02-minor-safety-and-compliance.md`).

## Legal drafts (round 19, unreviewed)
One .docx with three drafts, each marked "DRAFT — NOT LEGAL ADVICE — FOR ATTORNEY REVIEW" with inline attorney notes:
1. **Terms of Service:** age gating, "verification is not a safety guarantee", an in-person meetups section naming QR Instant Match, health and location handling, reporting and bans.
2. **Privacy Policy:** mirrors the data model (Stripe Identity data, HealthKit/Garmin/aggregator data, two location categories with the 30-day ping purge, Stream messages, QR identifiers), with a VCDPA opt-in section for biometric and precise geolocation.
3. **Assumption of Risk & Liability Waiver:** Discover meetups, club events, and a QR Instant Match section; proposes a short in-app acknowledgment at Instant Match confirmation on top of the full waiver at signup.
Not to be shown to real users or used to gate signup until an attorney reviews them. The public legal pages will live in the separate `groundwork-site` repo.
