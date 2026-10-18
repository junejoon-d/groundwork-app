---
paths:
  - "app/**"
  - "src/**"
  - "components/**"
---

# UI design rules

## Tokens
- Every color, font, font size, spacing and radius comes from `src/theme/tokens.ts`. No hex values or raw numbers in components.
- Never reintroduce the superseded `#FF5A2E` accent or the Patrick Hand font.
- If a screen needs a value the tokens don't have, stop and ask me. Don't invent one.

## Three visual rules
1. **One tap color.** Coral (`accent`) means "you can tap this": primary buttons, the active tab, the selected chip. Don't use coral for headings, decorative icons, borders or body text. Teal is for secondary information, not actions.
2. **Big or small, nothing in between.** Each screen has one `hero` or `title` element; everything else is `body` or `caption`. Don't add new sizes between steps.
3. **Layer the screen.** Large type or imagery sits in the back, the main content (match card, session details) in the middle, and actions on top (floating or pinned bottom buttons). Let layers overlap a little rather than stacking everything in one flat column.

## Onboarding and permissions
- Ask for one thing per screen.
- Every permission screen (location, notifications, Health) shows our own explainer first, then the iOS prompt only if the user taps continue, and always has a "Not now" option. The app must work after "Not now".
- Ask for notifications after the first match or accepted session, not at launch. Ask for location when the user first browses nearby activities, and for Health when they first connect Apple Health.
- The primary button looks and sits the same on every onboarding slide (coral, bottom, full width). "Not now" is always the secondary style.
- Ask for the username as "Claim your handle".
- Alternate giving and asking: after a screen that asks for something, the next one shows something useful or encouraging.

## References
- Before building a new flow, check `design/reference-flows.md` for the apps to study and copy the structure, not the look.

## Checking the result
- After building or changing a screen, run the `design-check` skill with my screenshot from the development build, and fix every difference it finds.
- For motion, gestures, sheets and press feedback, use the `animate-expo` skill.
