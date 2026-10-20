# Groundwork: Claude Code rules

<!-- Paste the ready-to-copy CLAUDE.md from build brief §11 above this line. Keep the whole file under 200 lines. Setup notes: docs/claude-code-setup.md -->

## Security
- Never read, print or edit `.env` files. Refer to environment variables by name. A hook blocks this anyway; don't try to work around it.
- Never put a secret in an `EXPO_PUBLIC_` variable or in app code. Details: `.claude/rules/app-secrets.md`.
- Before marking any phase done, commit the work, run `/claude-security scan my branch`, and fix every confirmed finding. Paste the result into the phase summary next to the §12 security tests.

## Database
- The Supabase MCP is read-only. Schema changes are migration files that reach production only when their PR merges. Details: `.claude/rules/supabase.md`.

## How we work
- Each session starts in plan mode. For a new phase, interview me with AskUserQuestion before writing the plan, then wait for my approval.
- Before calling a task done, show the evidence: the command you ran and its output.
- Run `/clear` between unrelated tasks.
- Ask before installing any skill, plugin or MCP server.
- Phase-specific detail goes in `.claude/rules/` with `paths:` frontmatter, not in this file.
- Project background, decisions and open items are in `docs/handoff/` (start at its README). Read the file for the area you're planning before you plan it.

## Design
- All visual values come from `src/theme/tokens.ts` (Harbor). Rules: `.claude/rules/ui-design.md`.
- After building or changing a screen, ask me for a dev-build screenshot and run the `design-check` skill.
