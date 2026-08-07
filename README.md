# Vocab Express

A private, mobile-first vocabulary learning app for Max and Tia.

## Open English WordNet

The local backend can import Open English WordNet 2025 Plus as private candidate data. The archive is not committed to the repository and raw WordNet content is never shown in the learner Library automatically.

- Source: <https://en-word.net/static/english-wordnet-2025-plus-json.zip>
- Expected SHA-256: `8832b8fa26a14c0ba8c99bb1ef8db6f9e122a6d9193b65ca9e0ef572580fee7e`
- Licence: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)

Use `npm run wordnet:inspect`, `npm run wordnet:import`, and `npm run wordnet:verify` for the raw dataset. The Codex-only review workflow is documented in [curation/wordnet/README.md](curation/wordnet/README.md).

## Local development

1. Start Docker Desktop.
2. Copy `.env.example` to `.env.local` and add the values printed by `npx supabase status`. This project uses the isolated local API port `55321`.
3. Run `npm install`.
4. Run `npx supabase start`.
5. Run `npm run dev`.

Never put a Supabase secret or `service_role` key in a `VITE_` environment variable.
