# Claude Code setup in this repo

Merged in PR #1 (2026-10-18), hardened in #2–#4. Full description in `docs/claude-code-setup.md`.

| File | What it does |
|---|---|
| `.claude/settings.json` | Enables Anthropic's `claude-security` and `security-guidance` plugins, denies reading or editing `.env` files, runs the secret-guard hook, starts every session in plan mode |
| `.claude/hooks/guard-secrets.js` | Blocks reading `.env*` (including through shell and PowerShell and glob tricks), writing secret values or the service-role key into files, secret `EXPO_PUBLIC_` variables, and the service-role key outside `supabase/functions/`. Tested on 84 inputs. `onFailure: "block"` |
| `.mcp.json` | Supabase MCP on groundwork-pilot, read-only |
| `.claude/rules/supabase.md` | Migration-only schema changes, RLS in the same migration, advisors, webhook `verify_jwt` |
| `.claude/rules/app-secrets.md` | What may go in `EXPO_PUBLIC_`; never trust cached safety state |
| `.claude/rules/ui-design.md` | Harbor rules (see `06-design.md`) |
| `.claude/skills/design-check/` | Compare a dev-build screenshot to its reference and the rules, then fix |
| `.claude/skills/animate-expo/` | Emil Kowalski's Expo animation skill (MIT), chosen over the same author's web-only `apple-design` |
| `src/theme/tokens.ts` | Harbor tokens (some TODOs) |
| `design/reference-flows.md` | Mobbin flows per screen |

## Rules from CLAUDE.md, and why
- Secrets: never read `.env`; production secrets belong in Supabase function secrets and EAS secrets, not a local `.env`. Anything in `EXPO_PUBLIC_` ships inside the app bundle.
- Before marking a phase done: commit, run `/claude-security scan my branch`, fix every confirmed finding, and paste the result next to the §12 security tests. (Claude Security needs a paid plan; on Pro turn on "Dynamic workflows" in `/config`.)
- Each session starts in plan mode. For a new phase, interview Danny with AskUserQuestion before writing the plan, then wait for approval.
- Show evidence (command plus output) before calling a task done. `/clear` between unrelated tasks. Ask before installing any skill, plugin or MCP server.
- Keep CLAUDE.md under 200 lines; phase detail goes in `.claude/rules/` with `paths:` frontmatter.

## Vetted practices from the Claude Code reels research (44 reels, 2026-10-18)
Adopted:
1. Official `claude-security` and `security-guidance` plugins; scan before signing off each phase.
2. Block secrets at the tool level (deny rules plus hook), not only by instruction.
3. Supabase MCP read-only against production; run advisors after every migration.
4. Lean CLAUDE.md, scoped rules, plan mode with an interview. ("Plan mode is being removed" is false.)
App advice worth keeping:
- Fast cold start: trust the stored session, render a cached home snapshot, fire startup requests in parallel. **But never let cached age, verification or match state gate a safety feature**; RLS is the source of truth.
- Ask for push permission after the first win (first match request or accepted session), behind our own explainer.
Rejected:
- OmniRoute and similar provider routers (send code and prompts to unknown providers; minors' data risk).
- Session replay tools like PostHog replay (would record minors' chats) and review-gating prompts (against store policy).
- Claude-Mem (built-in memory covers it), long "install these plugins" lists, Composio-style all-in-one connectors.
- Context7 was the one third-party pick aimed at a real pain point (current Expo/Supabase docs); not installed.

## Two copies of this setup
The local app repo `C:\dev\groundwork` merged the same kit on 2026-10-19 (see its decisions log): plan mode, the secrets deny rules, `claude-security`, its own `guard-secrets.js` with a self-test, and the same three rules. It left out `security-guidance` (not installed). Its CLAUDE.md already carries the brief's rules, so nothing needs pasting there.
