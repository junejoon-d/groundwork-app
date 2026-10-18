# Reference flows to study before building each screen

Copy the **structure** of a flow (steps, order, what's asked when), never the look. Everything visual comes from Harbor (`src/theme/tokens.ts`).

The Mobbin connector in this project needs a paid Mobbin plan, so I couldn't pull these automatically. Search them on mobbin.com (iOS), save screenshots into `design/refs/<flow>/`, and point Claude at that folder when you start the flow. I haven't confirmed that each app below is on Mobbin.

| Groundwork flow | Search on Mobbin | What to look for |
|---|---|---|
| Sign up and onboarding | Strava onboarding, Runna onboarding, Nike Run Club onboarding | Order of questions, how sport and level are picked, where sign-in appears |
| Permission explainers | Strava location permission, Hinge notifications permission | The pre-prompt screen before the iOS dialog, and the "Not now" placement |
| Profile and sports setup | Playtomic profile, Strava profile | Showing level and preferred times without long forms |
| Browse nearby partners or activities | Playtomic find a match, Meetup event list, ClassPass search | Filters, map vs list toggle, empty states |
| Match request and accept | Bumble For Friends, Hinge, Playtomic join match | How a request is sent, pending state, accept and decline |
| Session details and scheduling | Meetup event detail, Partiful event page | Time, place and who's coming above the fold, single clear action |
| Chat | Hinge chat, Strava messages | First-message prompts, safety and report entry points |
| Safety: report and block | Hinge report, Bumble report | How many taps, confirmation, what the reporter sees after |
| Identity and age verification | Bumble photo verification, Tinder ID verification | Explaining why before the camera opens, and what happens after |
| Connect Apple Health | Strava Apple Health, Runna Apple Health | What's read and why, before the HealthKit sheet |

When you save screenshots for a flow, run `design-check` with them as the reference after the screen is built.
