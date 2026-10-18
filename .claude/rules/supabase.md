---
paths:
  - "supabase/**"
---

# Supabase rules

groundwork-pilot is linked to this repo through Supabase's GitHub integration. Each PR that changes `supabase/` gets a preview branch built from the repo's migrations; merging to `main` applies them to groundwork-pilot, which is production.

- The Supabase MCP in `.mcp.json` is read-only. Use it to inspect tables, logs and advisors. Never remove `read_only=true` or point it at another project.
- Every schema change is a new file in `supabase/migrations/`, made with `supabase migration new <name>`. Never use `apply_migration`, the dashboard or `supabase db push`; the change reaches the database only when its PR merges.
- Never edit a migration that is already on `main`. Fix it with a new migration.
- New tables enable RLS in the same migration that creates them. A table with no policy is a failure, not a default.
- Rules about minors (brief §5 and §15) are enforced in RLS policies or Edge Functions, never only in app code.
- When the PR's preview branch is built, ask me for its advisor results (Supabase dashboard > Advisors on the branch), and fix every RLS, exposed-table and security-definer warning before calling the work done. After merge, run `get_advisors` for `security` and `performance` on production and paste the output.
- Webhook functions (`stripe-webhook`, `spike-webhook`, `push-send`, `account-erase`, `guardian-sms-optin`) keep `verify_jwt = false` in `supabase/config.toml`. Every other function keeps the default.
- The service-role key may be read only inside `supabase/functions/` via `Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")`. Never return it, log it, or pass it to the client.
- After changing the schema, regenerate types with `supabase gen types typescript --linked` and commit them.
