---
paths:
  - "supabase/**"
---

# Supabase rules

- The Supabase MCP server in `.mcp.json` points at the **dev** project. Never change it to the production project, and never run writes against production.
- Every schema change is a migration file in `supabase/migrations/`. No edits in the dashboard.
- After every migration, run `get_advisors` for both `security` and `performance`. Fix every RLS, exposed-table and security-definer warning before moving on, and paste the advisor output into your summary.
- New tables enable RLS in the same migration that creates them. A table with no policy is a failure, not a default.
- Rules about minors (brief §5 and §15) are enforced in RLS policies or Edge Functions, never only in app code.
- The service-role key may be read only inside `supabase/functions/` via `Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")`. Never return it, log it, or pass it to the client.
- After changing the schema, regenerate types with `generate_typescript_types` and commit them.
