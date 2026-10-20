# Groundwork — Visual Design Language ("Middle Distance" system, Harbor palette)

> Plain-text extraction of `harbor-design-language.docx` (in this folder), which is the original.
> Word tables are flattened here: each cell appears on its own line, in row order.
> NOTE: This document is reproduced as §10 of the build brief, with later resolutions
> (type scale, Lucide icons, motion, app icon, --pal-on-accent, danger/warn tokens).
> **Where the two differ, build-brief.md §10 wins** — it is the later document.

---

Groundwork
Visual Design Language — “Middle Distance” System, Harbor Palette
Drop-in replacement for Build Handoff Package §10 (“Visual design direction”) · “Groundwork” is the current working title only — naming is still being explored separately and is not finalized by this document.

0. How to use this section
This document specifies the visual design system a build session should implement for Groundwork's UI. It supersedes whatever token set currently sits in Build Handoff Package §10 — paste this section in as a direct replacement (including the open item it resolves: item #2 in §14, the Patrick Hand typography question, is superseded by the typography system in §3 below).
Precedence, matching the rule already established for other build inputs: this document is authoritative on color, type, and component tokens. The existing wireframes (mobile-preview.html, canvas, mobile) remain authoritative on screen layout, navigation, and interaction flow — re-skin their structure with these tokens rather than redesigning layouts from scratch.
Source of truth: every value below was pulled directly from the working mockups built and approved during the Harbor color-story review (light + dark, 4 palettes × 3 sample cards each). Values marked “recommended” in §3.2 and §9–10 were not present in those mockups and should be confirmed, not assumed final.
1. Direction summary
The system is called “Middle Distance” internally: warm and human enough to feel inviting for a first meetup, structured and legible enough to carry real training data (pace, heart rate, splits) without feeling clinical. It replaced two earlier explorations — one read as too sharp/angular, the other as too soft — by building the mark directly out of the product's own data vocabulary (see §4) rather than an abstract geometric or organic shape.
“Harbor” is the color story chosen from four options explored (Sunrise, Trailhead, Harbor, Ember & Gold). It pairs a warm coral with a steel-teal, on a warm off-white (light) or near-black (dark) base — legible as a fitness/data product, warm enough for a social-matching product.
2. Color tokens
Nine tokens, each with a light and dark value. Implement as CSS custom properties (or your platform's theme-token equivalent) scoped to a top-level theme provider, not hardcoded hex values in components — this is what let one set of component code render identically across all four color stories during review, and is what makes the light/dark switch in §7 a token swap rather than a rebuild.
2.1 Light mode
Token
Swatch
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
Timestamps, meta labels, helper text (large sizes only — see §8)
--pal-a-tint

#FCE4DC
Coral tint
Pill / badge backgrounds paired with ink-colored label text
--pal-b-tint

#DCEBEE
Teal tint
Pill / badge backgrounds paired with ink-colored label text

2.2 Dark mode
Token
Swatch
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
Timestamps, meta labels, helper text (large sizes only — see §8)
--pal-a-tint

#3A2620
Coral tint
Pill / badge backgrounds paired with ink-colored label text
--pal-b-tint

#1C2F34
Teal tint
Pill / badge backgrounds paired with ink-colored label text
Dark-mode accents are brightened ~4–5% in lightness versus their light-mode values (not simply reused) — this is what keeps coral and teal legible against near-black surfaces without them turning neon.
3. Typography
3.1 Typeface roles
Role
Typeface
Weights used
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
All three are Google Fonts — load via standard platform font-loading (React Native: expo-font / static font files bundled with the app, not a CDN link tag).
3.2 Type scale — recommended starting point
Not established in the reviewed mockups, which only fixed relative weight/role, not a full numeric scale. Treat the sizes below as a reasonable default a build session can start from; confirm against the actual wireframe screens (mobile-preview.html) before locking in, since the wireframes may already imply specific sizes at certain breakpoints.
Level
Size
Weight
Face / use
Display XL
32px
700
Outfit — big stat callouts (PR card hero number)
H1 / screen title
24px
700
Outfit — screen headers
H2 / section
17px
600
Outfit — card section labels ("This week, together")
Body
15px
400–500
Figtree — primary reading copy
UI label / button
14px
700
Figtree — buttons, tab labels
Pill / badge
11–11.5px
700
Figtree — tags, status chips
Data / mono
13–15px
500–600
IBM Plex Mono, tabular figures — pace, HR, splits
Meta / caption
12px
400–500
Figtree, --pal-faint — timestamps, helper text
4. Mark construction
The mark is two rounded “pill” shapes — literally the same shape as a progress bar or bar-chart bar used elsewhere in the UI — rotated and overlapped, so the logo reads as an extension of the product's own data visualization rather than a separate illustration.
Shape: two rectangles, radius 16px, dimensions roughly 96–135px wide × 22–34px tall (scale proportionally for smaller lockups / app icon).
Rotation: back shape −16°, front shape +12°.
Color: back shape --pal-b (teal), front shape --pal-a (coral).
Overlap: front shape uses mix-blend-mode: multiply where it overlaps the back shape, so the intersection reads as a third, darker tone rather than a hard edge — evoking two separate tracks/goals converging.
App icon: not yet designed at icon resolution (no safe-area / rounded-corner treatment tested). Treat as an open item — the two-pill mark will need a simplified, higher-contrast version for the ~1024px App Store icon and small-size favicon/notification-icon use, where the multiply-blend subtlety will likely be lost.
5. Spacing & radius scale
Consolidated from the component values that recurred across every mockup card:
Card radius: 16px (the one radius value used everywhere for cards/sheets — keep it singular rather than introducing a second card radius)
Button / control radius: 12–16px
Pill / badge radius: 999px (fully rounded)
Card padding: 18–22px
Card border: 1px solid --pal-line
Chart bar gap: 6–8px
Avatar diameter: 44–52px depending on context (list row vs. profile header)
6. Core component specs
Component
Shape / spacing
Color
Notes
Card
radius 16px · border 1px · padding 18–22px
border: --pal-line · bg: --pal-card
Base unit for match cards, weekly summary, PR cards
Avatar
circle, 44–52px diameter
bg: linear-gradient 135°, --pal-a → --pal-b
Gradient stands in for a photo in placeholder / no-photo states
Pill / badge
fully rounded (radius 999px) · padding 4–5px × 12–14px
bg: accent tint (a-tint / b-tint) · text: --pal-ink
Weight 700, size 11–11.5px. Used for tags, sport type, status
Primary button
radius 12–16px · padding 10–12px
bg: --pal-a · text: see §8 (on-accent token)
Weight 700–800. Do not reuse --pal-card as label color unconditionally — see accessibility note
Bar chart bar
radius 5–8px top / 3–4px bottom · gap 6–8px
active: accent color · inactive/rest: --pal-line
Weekly "together" chart and similar comparative bars
Sparkline
1.5–2px stroke, no fill
stroke: --pal-a (or --pal-b for a second series)
PR / trend cards; pair with a single terminal dot marker
7. Dark-mode implementation
Implement as three token layers, matching standard platform conventions:
A base (light) token set — §2.1.
A dark token set applied when the OS-level color scheme is dark — §2.2 — and no explicit in-app override is set.
An explicit in-app light/dark toggle that overrides the OS setting when the user sets one — store the preference, don't just follow the system permanently.
Every component should reference tokens (--pal-a, --pal-ink, etc.), never literal hex values, so the same component renders correctly in both modes without conditional logic in the component itself — this was the approach used to render the four color stories × 2 modes (8 total variants) from one shared set of mockup markup during design review, and it should carry through to production code the same way.
8. Accessibility & contrast
Computed WCAG 2.1 contrast ratios for the pairings a build session will hit most often:
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
Restrict to large/decorative labels, or pair with an icon; do not use for small body copy
Light — coral (--pal-a) on card
3.08:1
Pass (UI/large only)
Fine for icons, large numerals, bold ≥18px; not for small body text
Light — teal (--pal-b) on card
4.75:1
Pass (normal text)
Safe for body-size labels
Light — button label (--pal-card on coral)
3.08:1
Pass (UI only)
Meets the 3:1 UI-component minimum, not the 4.5:1 text minimum — see recommendation below
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
Safe for normal text (dark mode's brightened faint tone clears AA where light mode's does not)
Dark — coral (--pal-a) on card
6.27:1
Pass
Safe for normal text
Dark — teal (--pal-b) on card
5.69:1
Pass
Safe for normal text
Dark — button label (--pal-card on coral)
6.27:1
Pass
Comfortable
Recommendation: add a dedicated “on-accent” text token
The mockups use --pal-card as the button-label color on top of --pal-a in both themes, as a convenient shortcut (it works because both accent colors sit at medium brightness). Measured, that shortcut gives a comfortable 6.27:1 in dark mode but only 3.08:1 in light mode — it clears WCAG's 3:1 minimum for UI components but not the 4.5:1 minimum for text. Swapping to --pal-ink as the light-mode button-label color instead measures 4.55:1 (passes normal-text AA) while dark mode should keep --pal-card (ink-on-coral in dark mode measures only 2.22:1, worse). Recommend defining a fourth semantic token, e.g. --pal-on-accent, set to --pal-ink in light mode and --pal-card in dark mode, rather than hardcoding one color choice across both themes.
Separately: --pal-faint fails normal-text AA contrast in light mode (2.78–3.09:1). Reserve it for large text (≥18px), icon-paired labels, or genuinely non-essential meta text — not for anything a user needs to read reliably (e.g. don't use it alone for form field errors or safety-relevant copy).
9. Iconography — recommended, not yet specified
No icon set was chosen or tested against this palette in the reviewed mockups. This section is a starting recommendation for the build session, not an established decision.
Style: rounded-stroke line icons (matches the rounded-pill mark and Outfit/Figtree's soft geometry) rather than sharp/angular or filled-glyph icons.
Stroke weight: 1.5–2px at 24px icon size, scaling proportionally.
Color: --pal-ink for default/inactive state, --pal-a or --pal-b for active/selected state (e.g. active tab bar icon).
A concrete candidate to evaluate first: Phosphor Icons or Lucide (both rounded-line, open-license, React Native-friendly) — confirm licensing and bundle-size impact before committing.
10. Motion & interaction — recommended, not yet specified
Not covered in the reviewed mockups (they were static). Included here because a build session will need some default rather than inventing one ad hoc per screen.
Keep motion purposeful and brief — 150–250ms ease-out for most UI transitions (card entrance, tab switch, sheet presentation); reserve anything longer for celebratory moments (new PR, match confirmed).
A new-PR or match-confirmed moment is the one place a slightly more expressive animation (e.g. the two mark pills animating into their overlapped position) is worth the investment — everywhere else, restraint.
Respect the OS “reduce motion” accessibility setting: fall back to a simple cross-fade for all of the above when it's enabled.
11. Open items for the founder to confirm
App icon treatment at small sizes (§4) — needs its own simplified pass.
Full numeric type scale (§3.2) — currently a recommendation, not verified against the wireframe screens.
Icon set (§9) and motion defaults (§10) — no direction tested yet; recommendations above are a reasonable default, not a decision.
The --pal-on-accent fix in §8 — low-cost, worth adopting before build rather than retrofitting after launch.
This resolves §14 item #2 (Patrick Hand font) from the existing brief — confirm that Outfit/Figtree/IBM Plex Mono fully replaces that direction rather than supplementing it.
12. References
Harbor + three alternate color stories, full mockups (light & dark, all four palettes): design research artifact (see project docs for current link).
Existing build brief this section replaces: Build Handoff Package §10, and the related open item in §14 (#2).
Product/safety context that should inform certain UI states (verification badges, reporting flows, banned-state treatment): Round 15 Pre-Build Decisions.
