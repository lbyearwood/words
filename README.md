# Brain Express

A private, mobile-first vocabulary learning app for Max and Tia.

Max and Tia each have a learner-owned curriculum, category set, content wording
and learning history. There is no shared WordNet catalogue. Reviewed content is
maintained in deterministic personalised manifests of at most 50 items; see
[`content/personalised/README.md`](content/personalised/README.md).

## Local development

1. Start Docker Desktop.
2. Copy `.env.example` to `.env.local` and add the values printed by `npx supabase status`. This project uses the isolated local API port `55321`.
3. Run `npm install`.
4. Run `npx supabase start`.
5. Run `npm run dev`.

Never put a Supabase secret or `service_role` key in a `VITE_` environment variable.
