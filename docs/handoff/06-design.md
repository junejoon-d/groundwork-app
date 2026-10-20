# Design: Harbor and reference flows

## Harbor ("Middle Distance" system), adopted Sept 2026
Replaces brief §10 wholesale. The values live in `src/theme/tokens.ts`; the rules in `.claude/rules/ui-design.md`.
- **Colors (light):** coral `#F0664B` (the one tap color), steel-teal `#3B7A8C` (secondary information), chalk `#F3F1EA` (background), ink-navy `#232C30` (text).
- **Colors (dark), complete:** bg `#12171A`, card `#1B2226`, border `#333C42`, text `#ECEFF0`, muted `#8B969C`, coral `#F5806A`, teal `#5FA3B8`, coral tint `#3A2620`, teal tint `#1C2F34`.
- **Type:** Outfit (display), Figtree (body), IBM Plex Mono (data such as pace, HR, duration). Roles still need confirming against the Harbor doc.
- **Mark:** two rounded pills rotated −16° and +12°, crossing at centre, multiply blend.
- **Superseded, never reintroduce:** the wireframe's `#FF5A2E` accent and the Patrick Hand font.
- **Contrast fix adopted:** `onAccent` uses ink labels on coral buttons in light mode. Card-colored labels measure 3.08:1 and fail AA.
- Other palettes explored (Sunrise, Trailhead, Ember & Gold) were not chosen. Ember & Gold was noted as good for streak/PR/matched celebration moments.

## Still TODO in tokens.ts
- Light: `card`, `border`, `textMuted`, `tintAccent`, `tintSecondary`. Dark: `onAccent`.
- **`danger` and `warn` in both modes.** Harbor has no red or warning tone, but the product needs one (Delete match, Report, Declined, weak GPS, Invited/pending). Don't reuse coral for destructive actions, since coral means "tap here". Check new values against the same contrast table. Decide before phase 3.
- The type scale, spacing and radius scale (placeholders now).
All of these come from the Harbor .docx, which isn't in the repo yet.

## Principles from the market scan
- Semantic color (match, verification, report states) stays strictly functional, like Whoop. One warm, non-urgent brand accent, closer to Peanut or Strava than Tinder or Bumble.
- Calm, near-neutral base (Hinge-like) suits a verification-heavy, safety-first app.
- Editorial voice for bios and training philosophy; tabular mono for data (Nike Run Club, Whoop, Garmin).
- Peanut (platonic, safety-conscious mutual matching) is the closest live precedent for onboarding and reporting flows.
- Strava Clubs is the precedent for the "mutual clubs" trust signal. Garmin Connect's pinnable cards are a model for the companion website.

## Reference flows (Mobbin, PR #7)
`design/reference-flows.md` links 3–4 Mobbin flows for each of 10 Groundwork flows, with what's worth copying: sign-up and onboarding, permission explainers, profile and sports setup, browse nearby, match request and accept, session details, chat, report and block, identity verification, connect Apple Health. Copy structure, never looks. Mobbin image links expire after 30 days, so link to the flow pages.
- Gaps: Playtomic and Bumble For Friends aren't on Mobbin. No app shows a "request sent, waiting" state, so design that one from scratch.

## UI rules in force (summary of `.claude/rules/ui-design.md`)
- Tokens only; ask before inventing a value.
- One tap color. Big or small, nothing between. Layer the screen.
- One question per onboarding screen. Our own explainer before every OS permission prompt, always with "Not now", and the app must work after "Not now".
- Ask for notifications after the first match or accepted session; location when first browsing nearby; Health when first connecting it.
- After building a screen: ask Danny for a dev-build screenshot and run the `design-check` skill. Motion uses the `animate-expo` skill.

## Profile content (from the wireframe rounds)
The public profile splits "Journey so far" (races, marathons, PR count) from a "Training profile" card: years training, short bio or philosophy, typical weekly volume, home neighborhood, preferred training times, trust badges, mutual clubs.

## Open
- Fill the token TODOs and decide danger/warn before phase 3.
- Iconography and motion defaults were recommended in the Harbor doc but not decided.
