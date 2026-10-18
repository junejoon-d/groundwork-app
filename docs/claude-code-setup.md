# Groundwork Claude Code setup (reel takeaways: top 4 + six design ideas)

How this repo is set up for Claude Code. All files below are already in place; the steps further down are the parts only you can do.

## What's here
| File | Takeaway | What it does |
|---|---|---|
| `.claude/settings.json` | 1, 2, 4 | Turns on Anthropic's `claude-security` and `security-guidance` plugins for the repo, denies Claude reading or editing any `.env` file, runs the secret-guard hook, and starts every session in plan mode. |
| `.claude/hooks/guard-secrets.js` | 2 | Blocks Claude, before the tool runs, from reading `.env*` files (including via shell or PowerShell), writing Stripe/Supabase/webhook secret values or the service-role key into files, creating secret `EXPO_PUBLIC_` variables, and using the service-role key outside `supabase/functions/`. Plain Node, works on Windows. `.env.example` stays readable. |
| `.mcp.json` | 3 | Connects the Supabase MCP server to your **dev** project only. |
| `.claude/rules/supabase.md` | 3, 4 | Loads only when Claude touches `supabase/**`: dev-only database, run the security advisors after every migration, RLS in the same migration, service-role key only in Edge Functions. |
| `.claude/rules/app-secrets.md` | 2, 4 | Loads only when Claude touches app code: what may and may not go in `EXPO_PUBLIC_`, and never trust cached safety state. |
| `CLAUDE.md` | 1, 4, design | About 20 lines to paste under your existing CLAUDE.md. Keep the whole file under 200 lines. |

### Design ideas
| File | Idea | What it does |
|---|---|---|
| `src/theme/tokens.ts` | 1. Spec first | Harbor colors, fonts, type scale, spacing and radius in one file. Dark mode is complete; several light-mode values, the type scale and spacing are marked TODO because the Harbor .docx isn't in the project files. Fill those from it. |
| `design/reference-flows.md` | 2. Borrow flows | Which apps to look at for each Groundwork flow, and where to save screenshots so Claude can use them. |
| `.claude/rules/ui-design.md` | 3, 4 | Loads when Claude touches app code: tokens only, coral as the only tap color, big-or-small sizes, layered screens, and the onboarding and permission rules. |
| `.claude/skills/design-check/` | 5. Screenshot compare | Run after building a screen: Claude checks your dev-build screenshot against the reference and the rules, lists differences, fixes them, and asks for a new screenshot. |
| `.claude/skills/animate-expo/` | 6. Apple Design skill | Emil Kowalski's Expo animation skill, reviewed and pinned (MIT). See the note below on why this one instead of apple-design. |

## Finish setup (about 10 minutes, once)
1. Paste the CLAUDE.md from build brief §11 at the top of `CLAUDE.md`, above the rules already there.
2. In `.mcp.json`, replace `YOUR_DEV_PROJECT_REF` with your **dev** Supabase project's ref (Project Settings > General). Never put the production ref here. I couldn't load Supabase's MCP docs from here to re-check the `project_ref` URL parameter, so confirm it on their MCP setup page.
3. `.gitignore` already ignores `.env` and `.env.*` (but keeps `.env.example`). Leave that in place.
4. Start Claude Code in the repo. When it asks to trust the project's plugins and MCP server, approve them. If the plugins don't install by themselves, run:
   ```
   /plugin install claude-security@claude-plugins-official
   /plugin install security-guidance@claude-plugins-official
   ```
   Then run `/mcp` and sign in to Supabase when prompted.
5. Fill in the TODO values in `src/theme/tokens.ts` from the Harbor doc before phase 3.
6. Check that the hook works: ask Claude "show me what's in .env". It should refuse with a `Blocked by guard-secrets` message. Run `/hooks` to see the hook listed.

## Notes
- Claude Security needs a paid plan. On Pro, turn on "Dynamic workflows" in `/config`. It scans committed code, so commit before running `/claude-security scan my branch`.
- Plan mode is the default. Press Shift+Tab to leave it once you approve a plan.
- I used `.mcp.json` scoped to one project instead of the Supabase plugin from the marketplace, because a project-scoped connection can't reach production.
- `onFailure: "block"` in settings means that if Node is missing or the hook crashes, Claude's file and shell tools stop rather than run unchecked. Node is already required for Expo.
- The hook was tested against 20 sample inputs (Windows paths, PowerShell, `process.env`, anon vs service-role JWTs). It reduces risk, but it can't stop every possible leak; the deny rules and `.gitignore` are the other layers.
- **Why animate-expo instead of apple-design:** I read the author's `apple-design` skill. It's good on principles, but it's written for the web: CSS, pointer events and Framer Motion. The same author's `animate-expo` covers the same Apple motion ideas for React Native, using Reanimated, Gesture Handler and expo-haptics. Both are plain instruction files with no scripts or network calls. Adding Reanimated and Gesture Handler means one new EAS development build.
- **Mobbin:** the Mobbin connector here needs a paid Mobbin plan, so reference screenshots have to be saved by hand for now.
