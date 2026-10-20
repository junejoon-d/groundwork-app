# Build environment: Windows, iPhone, no Mac

Settled Sept 2026. Never assume macOS tooling.

## The setup
- Windows laptop: AMD Ryzen 7 5800H, 16 GB RAM, x64. No Mac, none planned.
- iPhone 15 Pro Max: Developer Mode on, TestFlight installed, registered with `eas device:create`. Clears the iOS 26 floor for Declared Age Range.
- Expo with EAS Build. Claude Code runs natively on Windows (no WSL). Docker/WSL can't run on this PC, which is why the Supabase baseline was generated from the catalog instead of `supabase db pull`.

## Rules that follow
- **Never eject or `expo prebuild` into a bare project.** With no Mac the iOS project could never be compiled. If a native dependency won't work through a config plugin: solve it inside Expo, change the dependency, or buy a Mac.
- **Expo Go is not the test path.** HealthKit, the Spike SDK and Stripe Identity can't run in it, and it misbehaves for notifications, OAuth, deep links and maps. **The development build is the only thing that runs the real app.** Never suggest going back to Expo Go.
- **Phase 1 discipline:** install every native dependency and prove they compile together in one real EAS build before feature work. Each iOS compile is a 10–25 minute cloud build plus queue.
- No iOS Simulator. Every iOS check is on the physical iPhone (GPS, camera QR, HealthKit and push need a device anyway).
- Android: test on a physical phone over USB. The emulator needs AMD-V/SVM plus Windows Hypervisor Platform and will be slow on 16 GB; use it only for layout checks.

## Windows pitfalls
- 260-character path limit: enable `LongPathsEnabled`, keep the project at a short path like `C:\dev\groundwork`.
- Exclude the project folder from Windows Defender scanning.
- `core.autocrlf true`.
- Keep the project out of OneDrive.
- Case-insensitive filesystem: an import that works locally can fail in EAS's Linux container.

## EAS cost
Free: 15 iOS + 15 Android builds a month, low-priority queue. Starter $19/month: priority queue plus $45 credit. Only native config changes need a new build; JS and UI hot-reload. Plan: stay on Free, subscribe to Starter in native-heavy phases (1, 3, 9, 10, 11), cancel between.

## Animation
Adding Reanimated and Gesture Handler (for the `animate-expo` skill) needs one new development build.

## Open
- Testing Garmin without a Garmin watch: Spike has no sandbox. See `05-vendors.md` for the plan (a Garmin-wearing beta tester from DC Triathlon Club at the start of phase 9, backfill, replaying signed sample payloads).
