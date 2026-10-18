---
paths:
  - "app/**"
  - "src/**"
  - "components/**"
  - "app.config.*"
  - "app.json"
  - "eas.json"
---

# Secrets in app code

- Everything in an `EXPO_PUBLIC_` variable ships inside the app bundle and anyone can read it. Only the Supabase URL, the anon (publishable) key, and other public IDs may use that prefix.
- Stripe secret keys, Spike secrets, webhook secrets and the Supabase service-role key live only in Edge Function secrets (`supabase secrets set`) or EAS secrets used at build time, never in app code.
- The client talks to Stripe Identity and Spike through Edge Functions, never with a secret key directly.
- Never trust cached client state (age state, verification, match status) for a safety decision. The server and RLS decide.
