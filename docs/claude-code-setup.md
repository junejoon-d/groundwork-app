# Groundwork Claude Code setup (reel takeaways: top 4 + six design ideas)

How this repo is set up for Claude Code. All files below are already in place; the steps further down are the parts only you can do.

## What's here
| File | Takeaway | What it does |
|---|---|---|
| `.claude/settings.json` | 1, 2, 4 | Turns on Anthropic's `claude-security` and `security-guidance` plugins for the repo, denies Claude reading or editing any `.env` file, runs the secret-guard hook, and starts every session in plan mode. |
| `.claude/hooks/guard-secrets.js` | 2 | Blocks Claude, before the tool runs, from reading `.env*` files (including via shell or PowerShell), writing Stripe/Supabase/webhook secret values or the service-role key into files, creating secret `EXPO_PUBLIC_` variables, and using the service-role key outside `supabase/functions/`. Plain Node, works on Windows. `.env.example` stays readable. |
| `.mcp.json` | 3 | Connects the Supabase MCP server to groundwork-pilot, **read-only**. Claude can inspect tables, logs and advisors but can't change anything. |
| `.claude/rules/supabase.md` | 3, 4 | Loads only when Claude touches `supabase/**`: schema changes only as migration files that reach production through a merged PR, advisors on the preview branch, RLS in the same migration, webhook `verify_jwt` settings, service-role key only in Edge Functions. |
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
2. Bring the live database into the repo before the first PR that touches `supabase/` (see the next section).
3. `.gitignore` already ignores `.env` and `.env.*` (but keeps `.env.example`). Leave that in place.
4. Start Claude Code in the repo. When it asks to trust the project's plugins and MCP server, approve them. If the plugins don't install by themselves, run:
   ```
   /plugin install claude-security@claude-plugins-official
   /plugin install security-guidance@claude-plugins-official
   ```
   Then run `/mcp` and sign in to Supabase when prompted.
5. Fill in the TODO values in `src/theme/tokens.ts` from the Harbor doc before phase 3.
6. Check that the hook works: ask Claude "show me what's in .env". It should refuse with a `Blocked by guard-secrets` message. Run `/hooks` to see the hook listed.

## Bring the live database into the repo (once)
Supabase's GitHub integration is on. A PR that changes `supabase/` gets a preview branch built from the repo's migrations, and merging to `main` applies them to groundwork-pilot. Right now the repo has none of the database: groundwork-pilot has 52 tables, but only the research tables came from a recorded migration, and its 9 Edge Functions aren't in the repo. Until this is fixed, preview branches start empty and the first new migration will fail on them.

On your Windows machine, with Docker Desktop running and the Supabase CLI installed, from the repo root on a new branch:
```
supabase init
supabase login
supabase link --project-ref klpszhgfvibojttmtbik
supabase migration repair --status reverted 20261018014442
supabase db pull
supabase functions download stream-chat
```
Repeat the last line for `invite-guardian`, `guardian-sms-optin`, `spike-webhook`, `spike-connect`, `push-send`, `identity-start`, `stripe-webhook` and `account-erase`.

- `migration repair` only removes the one history row for the research tables; it doesn't change any table. `db pull` then writes the whole schema, research tables included, into one `<timestamp>_remote_schema.sql` and records it as applied, so production won't run it again.
- Add this to `supabase/config.toml` so deploys from the repo keep the webhooks reachable. Production has JWT checks off for exactly these five:
  ```toml
  [functions.stripe-webhook]
  verify_jwt = false
  [functions.spike-webhook]
  verify_jwt = false
  [functions.push-send]
  verify_jwt = false
  [functions.account-erase]
  verify_jwt = false
  [functions.guardian-sms-optin]
  verify_jwt = false
  ```
- Open a PR. Its preview branch should build green, which shows the baseline replays cleanly.

## Notes
- Claude Security needs a paid plan. On Pro, turn on "Dynamic workflows" in `/config`. It scans committed code, so commit before running `/claude-security scan my branch`.
- Plan mode is the default. Press Shift+Tab to leave it once you approve a plan.
- I used `.mcp.json` scoped to one project with `read_only=true` instead of the Supabase plugin from the marketplace. groundwork-pilot is the only project and it is production, so Claude gets read access there and makes changes only through migration files in PRs. Both URL parameters are from Supabase's MCP docs.
- `onFailure: "block"` in settings means that if Node is missing or the hook crashes, Claude's file and shell tools stop rather than run unchecked. Node is already required for Expo.
- The hook was tested against 68 sample inputs (Windows paths, trailing dots and `::$DATA` streams, symlinks, `find -name`, PowerShell and extglob wildcards, PowerShell, quoted or escaped names like `.e"nv"`, dotfile globs like `.e*`, `process.env`, anon vs service-role JWTs). Shell parsing by pattern can't catch every trick, so the hook reduces risk rather than guaranteeing it; the deny rules and `.gitignore` are the other layers. The strongest protection is keeping production secrets out of the repo folder entirely: they belong in Supabase Edge Function secrets and EAS secrets, not in a local `.env`.
- **Why animate-expo instead of apple-design:** I read the author's `apple-design` skill. It's good on principles, but it's written for the web: CSS, pointer events and Framer Motion. The same author's `animate-expo` covers the same Apple motion ideas for React Native, using Reanimated, Gesture Handler and expo-haptics. Both are plain instruction files with no scripts or network calls. Adding Reanimated and Gesture Handler means one new EAS development build.
- **Mobbin:** the Mobbin connector here needs a paid Mobbin plan, so reference screenshots have to be saved by hand for now.
