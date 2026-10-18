---
name: design-check
description: Compare a screenshot of a Groundwork screen from the development build against its reference and the Harbor rules, list every difference, then fix them. Use after building or changing any screen, or when Danny pastes a phone screenshot.
---

# Design check

Groundwork is a native app tested on Danny's iPhone through an EAS development build. Browser tools can't see it, so the screenshot Danny pastes is the only visual evidence.

## Inputs
1. **The screenshot** from the dev build. If Danny hasn't pasted one, ask for it and stop. Don't judge a screen from code alone.
2. **The reference**: a wireframe, a Mobbin screenshot, or an earlier approved screenshot. If there is none, check against the rules only and say so.

## Steps
1. Name the screen and which reference you're comparing against.
2. Check the screenshot against `.claude/rules/ui-design.md`:
   - Is coral used only on tappable things? Is there exactly one primary action?
   - Is there one big element, with everything else small and no in-between sizes?
   - Are back, middle and top layers clear?
   - Do the colors, fonts and spacing look like `src/theme/tokens.ts`? Grep the screen's code for hex values or raw numbers.
   - On permission or onboarding screens: is there a "Not now", and is the primary button where it is on the other slides?
3. Compare against the reference: layout order, hierarchy, missing or extra elements, alignment, spacing rhythm, text truncation, and the safe area on the notch and home indicator.
4. Write a numbered list of differences, each with the file and line you'll change. Mark anything that's a judgment call rather than a rule as **ask Danny**.
5. Fix the rule violations and clear differences. Leave the judgment calls for Danny.
6. Ask Danny for a new screenshot after the dev build reloads, and repeat until there's nothing left on the list.

## Don'ts
- Don't say a screen "looks good" without listing what you checked.
- Don't add new tokens or sizes to make a mismatch go away. Ask instead.
