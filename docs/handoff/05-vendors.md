# Vendors and integrations

| Need | Vendor | Why | Cost |
|---|---|---|---|
| Database, auth, RLS, functions | **Supabase** | RLS gives auditable access control for the safety-sensitive joins (reports, messages, location) | free tier covers pilot |
| Chat | **Stream Chat** (Sendbird fallback) | Custom message types (plan proposals, check-in nudges, template shares) and built-in moderation | free tier for pilot; watch the 100-concurrent-connection cap at evening run-club peaks; paid ~$399–499/month after |
| Wearables | **Spike** | First-party Expo config plugin; one integration for HealthKit, Health Connect and Garmin | ~$450/month, **required** (Danny: most pilot runners wear Garmin) |
| ID verification | **Stripe Identity** | $1.50 per check, no minimum, self-serve SDK. Persona dropped ($250/month minimum); Veriff ($49/month + $0.80) is the fallback | ~$75–150 for the pilot |
| Builds | **Expo EAS** | Builds and submits iOS from Windows | Free, Starter $19 in native-heavy months |

A docs snapshot of all four is in `/mnt/project-files/research/apify/vendor-docs/` (Spike 100 pages, Stream RN 233 pages, Stripe Identity 28, Expo 51), one Markdown file per page.

## Spike: the things that cost time if missed
- **The React Native SDK covers on-device sources only (Apple HealthKit, Android Health Connect). Garmin is not in the mobile SDK.** Garmin is cloud-to-cloud: Spike's server API and webhooks deliver it to a Supabase Edge Function (`spike-webhook`), while the phone handles Apple Health. Garmin is the path that matters most for this pilot.
- Config plugin: `spike/sdk-docs__react-native__plugin-expo.md`. Works in a development build without ejecting.
- **No sandbox or simulated Garmin data.** The admin console can create test users, but Garmin data still needs a real linked Garmin account. To test the handler without one, replay the sample payload and sign it yourself.
- **Webhook body** is a JSON array of events with no metric values. It says what changed; then you pull records from `/queries/workouts` or the statistics endpoints for that time window.
  ```json
  [{"application_user_id":"User1","timestamp":"2025-04-15T13:33:55Z","event_type":"record_change",
    "metrics":["calories_burned_active","distance","steps"],"activity_types":["sedentary","walking"],
    "provider_slug":"garmin","earliest_record_start_at":"2025-04-15T09:30:00Z","latest_record_end_at":"2025-04-15T13:33:00Z"}]
  ```
  `event_type` is `record_change`, `provider_integration_created` or `provider_integration_deleted`.
- **Signature:** `X-Body-Signature` is a hex HMAC-SHA256 of the raw body with the admin-console secret. Verify before parsing.
- **Retries:** anything but HTTP 200 within 30 s fails. Up to 10 retries (5 s, 2 min, 30 min, 2 h, then every 12 h), then the event is **discarded**. So: return 200 fast, process async, be idempotent (key on user + window + metrics), and run a periodic reconciliation query.
- **Backfill** is off by default. Set "Max Backfill (days)" in the admin console: up to 90 days for Garmin, once per user, up to 12 hours, only for integrations created after it's on. Arrives through the same webhooks, possibly out of order.
- Write the handler defensively: log the raw payload before parsing, tolerate missing fields, never let a bad payload break a user's log.
- Auto-reconcile needs only workout type, duration, average and max HR, which normalized data covers. Vendor-only metrics like Garmin Body Battery are lost, which is fine.
- **Garmin test plan:** recruit one Garmin-wearing tester (DC Triathlon Club or Arlington Triathlon Club) at the **start** of phase 9, turn backfill on first, so one connection yields real history.

## Stripe Identity
- No built-in age threshold. Expand `verified_outputs.dob` and compute age yourself; store only the over-18 outcome.
- Webhooks: `identity.verification_session.{created, processing, requires_input, verified, canceled, redacted}`.
- Test mode doesn't really process checks; use Stripe's test flows.
- Also used for guardian verification (`02-minor-safety-and-compliance.md`).

## Stream Chat
- Custom message types: `stream-chat-rn/chat__docs__sdk__react-native__guides__custom-message-types.md`.
- Moderation: `stream-chat-rn/chat__docs__react-native__moderation.md`. Block, mute and flag hooks are in the same folder.
- The crawl is partial (233 of 730 pages); re-run with a higher cap for the full component reference.

## Connectors and tools available to Claude in the project
Supabase (read-only), Expo (builds, logs, store reviews), Mobbin (paid since 2026-10-20), Sentry, Stripe (sign-in currently expired), Strava (Danny's own data, useful for realistic sample profiles), Apify (through the desktop app). No Spike, Stream or Stripe Identity connector exists.

## Open
- First question on the Spike sales call: is there a sandbox? Then pricing and lead time.
- Re-crawl Stream's component reference if needed.
