# Groundwork handoff: everything decided and researched so far

Written 2026-10-20 from the Athlete Partner App project (its threads, memory, research files and the original claude.ai project's knowledge docs). This folder is for the Claude Code session that builds the app in `junejoon-d/groundwork-app`.

**State of the build (corrected 2026-10-20):** the app is already largely built, in Danny's local repo at `C:\dev\groundwork` (Expo app, `supabase/migrations/0001`–`0049`, Edge Functions, test suites). That repo has no GitHub remote. Its `docs/decisions.md` and `docs/launch-checklist.md` are the source of truth for what's built and what's left; where they disagree with these notes, they win. These notes add what that session couldn't see: the research, the naming search, and the GitHub-side Supabase work in `junejoon-d/groundwork-app`.

**How to use it:** read this index, then only the file for the area you're working on. Each file ends with what is still open. Every open or undecided item is also collected in `10-open-items.md`.

**Precedence:** the repo itself (migrations, functions, `.claude/rules/`, `CLAUDE.md`) wins over these notes. Among notes, the newest date wins. "Groundwork" is still the working title (see `09-naming.md`).

| File | What's in it |
|---|---|
| `01-product.md` | What the app is, v1 scope, the seven founder decisions, matching, safety and location rules, go-to-market |
| `02-minor-safety-and-compliance.md` | The 13–17 model, the §15 safeguards, guardian consent, SafeSport, state app-store laws, COPPA, platform age APIs |
| `03-build-environment.md` | Windows + iPhone with no Mac, EAS only, never eject, never Expo Go, Windows pitfalls |
| `04-supabase-backend.md` | groundwork-pilot (production), GitHub integration, migrations, Edge Functions, PR history, advisor warnings |
| `05-vendors.md` | Spike (Garmin + HealthKit), Stream Chat, Stripe Identity, Expo; what the docs snapshot answered |
| `06-design.md` | Harbor tokens, what's still TODO, Mobbin reference flows, design principles from the market scan |
| `07-claude-code-setup.md` | What's in `.claude/`, why, and the vetted Claude Code practices from the reels research |
| `08-market-research.md` | App store keywords, competitor reviews, Reddit, races, venues, clubs and sponsors |
| `09-naming.md` | The rename search: Danny's preferences, finalists, what's ruled out |
| `10-open-items.md` | Every open decision, gap and to-do in one list |
| `11-budget-timeline-legal.md` | Path A budget, monthly burn, timeline, App Store path, legal drafts |

## Sources (in the project's shared files, not this repo)
- Knowledge docs from the original project: `/mnt/project-files/knowledge/claude/*.md`
- Research outputs (each folder has `summary.md` plus CSVs): `/mnt/project-files/research/apify/<task>/`, `/mnt/project-files/research/claude-code-reels/`
- Setup kit as first drafted: `/mnt/project-files/groundwork-claude-setup/`

## Source documents
- **Build Brief rev 5** and **Harbor design language**: in `C:\dev\groundwork\docs\` as both .docx and .md (`build-brief.md`, `harbor-design-language.md`), and in this repo's `docs/` as .md. The brief is the plan of record.
- **Legal drafts** (the round-19 ToS, Privacy Policy and Liability Waiver .docx): not found in `C:\dev\groundwork` or the project files. The app's own privacy, terms and SMS pages exist and still need a lawyer's read (launch checklist §3).
- Published artifacts: [Playbook](https://claude.ai/code/artifact/2a618231-8a29-4d0e-81a4-5161c4f62d79), [canvas wireframe](https://claude.ai/code/artifact/21512d5f-763c-4de7-958b-eb1481a0a3bc), [mobile wireframe](https://claude.ai/code/artifact/3d669e4f-0a3b-4dcc-abf4-107e70bcaea6), [market scan](https://claude.ai/code/artifact/9137b578-117e-4c35-a7c3-23d353fdd967), [rename shortlist](https://claude.ai/code/artifact/32b23f22-3bb6-4cff-ae13-2aeb44bd43e3).
