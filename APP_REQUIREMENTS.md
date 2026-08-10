# Brain Express — Two-Learner Personalised Learning V2

## Product purpose

Brain Express is a private learning app for Max and Tia. It is not a shared
dictionary or a public 120,000-word library. Each learner has a separate
curriculum, separate content wording, separate categories and private progress.

The app remains React, Vite, TypeScript and Supabase Auth/Postgres, deployed as
a static GitHub Pages site. It must work at mobile, tablet and desktop widths.

## Permanent learner plans

### Max — Sophisticated Speaker at Work

Objective: develop precise, confident and persuasive language for leadership at
work. Examples should naturally use leadership, team performance, decisions,
organisational change and stakeholder communication. Use a general adult
example when workplace wording would be artificial.

Categories: General Vocabulary; Sophisticated Speaker; Professional
Communication; Leadership & Management; Critical Thinking & Logic; Academic
Language & Writing; Research Methods & Evidence; Mathematics & Statistics;
Education & Learning; Social Communication; Business & Economics; Phrases;
Quotes; Idioms.

Default focus: Sophisticated Speaker, supported by Leadership & Management,
Professional Communication and Critical Thinking & Logic.

### Tia — Year 9 Learning

Objective: develop general vocabulary and subject language appropriate for Year
9, using age-appropriate British English and realistic school, subject and
teenage contexts. England Key Stage 3 is the initial curriculum baseline.

Categories: General Vocabulary; Art; Computer Science; Dance; Drama; Design and
Technology; English; Geography; German; History; Maths; Music; Religious
Education; Physical Education; Science.

Default focus: General Vocabulary, supported by English, Maths and Science.

## Content ownership and QA

- Every learning item belongs to exactly one learner.
- The same written term may have different definitions, examples, difficulty,
  categories and importance for Max and Tia.
- Multiple useful meanings are separate learning items grouped by one learner
  term family. One test may use only one meaning from a term family.
- Migrated content remains visible with **Review pending** but is excluded from
  practice, mastery and eligible counts until approved.
- A learner-created term is immediately practice-enabled while still displaying
  **Review pending**.
- Curation uses deterministic manifests of at most 50 items, with separate
  drafting and QA evidence. Applying an identical manifest twice is harmless.
- Decisions are `keep`, `rewrite`, `change_sense` or reversible `exclude`.
- Active vocabulary requires a clean title, recognisable non-IPA pronunciation
  for single words, part of speech, accurate definition, natural example,
  difficulty, importance and one primary learner category.
- Placeholder examples and unintended parenthetical sense descriptions are not
  allowed in approved content.
- A definition, sense, title, part-of-speech or pronunciation correction
  increments the content version and resets only that item's memory state.
  Example-only edits retain memory history.

## Core experience

- Library shows only the signed-in learner's curriculum.
- My Collection shows that learner's saved, liked and disliked subset.
- Profile shows the permanent plan and temporary primary/supporting focus.
- Recommended practice uses learner-specific importance, active focus and
  FSRS-6 memory state.
- Multiple-choice and true/false are the only enabled question types.
- Unanswered correct answers are never exposed to the browser.
- Results, progress, points and mastery include only the signed-in learner.

## Future assessment foundation

The schema may store disabled templates for factual, calculation, procedure,
interpretation, source-analysis and written-response assessments. No such
question type is learner-visible in this release. This foundation will later
support subject assessments such as Year 9 maths without treating every school
skill as vocabulary recall.

## Security requirements

- Every exposed table has explicit Data API grants and RLS; grants and RLS are
  treated as separate controls.
- Owner checks use `auth.uid()` and indexed `user_id` columns.
- Security-invoker views are required for exposed views.
- Privileged RPCs use a fixed search path, validate `auth.uid()`, revoke
  `PUBLIC` and `anon`, and explicitly grant only `authenticated` execution.
- Max and Tia must not be able to read or mutate each other's plans, categories,
  content, collections, attempts, answers, goals, points or dashboards.

## Cutover guarantees

- Preserve Max's 790 item mappings / 789 term families and Tia's 305 item
  mappings / 303 term families, including collection membership, likes and
  dislikes.
- Reset attempts, answers, points, mastery, FSRS state and temporary goals.
- Export an immutable private snapshot before the backfill.
- Remove the unused WordNet raw schema and local import assets only after the
  personalised snapshot and backfill counts are verified.

## Acceptance

Database tests must prove ownership isolation, pending-item practice rules,
cross-learner category rejection, one term family per attempt, item-scoped memory
resets, explicit grants/RLS and required indexes. Content validation must report
zero placeholders and complete metadata on approved items. Unit tests, lint,
production build and mobile/tablet/desktop browser journeys must pass for both
accounts before production is accepted.
