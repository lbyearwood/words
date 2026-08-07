# Vocab Express — Personal Vocabulary Prototype

## Purpose

Build a private, mobile-first vocabulary learning app for two initial users: Max and Tia. The app should help a user build a personal word bank, practise it in short or long tests, and see clear evidence that their vocabulary knowledge is improving.

The product should feel personal, encouraging and modern — not like a school worksheet or a formal testing platform.

## Delivery constraint: local Supabase first

The next Codex **must develop and test against a local Supabase project running through Docker before connecting any hosted Supabase project or deploying to GitHub Pages**.

Required local workflow:

1. Install/pin the Supabase CLI as a project development dependency.
2. Run `npx supabase init` in this repository.
3. Start the local stack with `npx supabase start` (Docker Desktop or a Docker-compatible runtime is required).
4. Create and apply schema migrations locally.
5. Test authentication and all Row Level Security (RLS) policies locally using two distinct test accounts.
6. Test the full core user journey locally before any production configuration.
7. Commit the `supabase/` directory, migrations, seed data and a `.env.example`; do not commit real keys or user passwords.

The local environment provides Supabase Studio and Mailpit for inspection/testing. The local API URL and publishable key emitted by `supabase start` belong only in a local `.env` file.

## Platform and technical shape

- Frontend: React + Vite + TypeScript, deployed as a static site to GitHub Pages after local testing passes.
- Backend: Supabase Auth and Postgres only. No custom always-on server is needed for the prototype.
- Design: mobile-first. Desktop is a wider version of the same product, not a separate admin experience.
- Initial audience: two private accounts only; accounts may be created manually in Supabase for the prototype.
- Security: never put a Supabase `service_role`/secret key in the frontend. Enable RLS on every public table.

## Navigation and mobile experience

Bottom navigation on mobile:

1. Home
2. Library
3. My Collection
4. Practise
5. Profile

Mobile requirements:

- One-column layout; no horizontal overflow.
- Large, thumb-friendly tap targets.
- Clear type and generous spacing.
- A test presents one question at a time with tap-to-select answers.
- The main journey should be quick: open app → browse/save a word → practise → see what to revisit.

Visual direction:

- True-white primary surfaces with a fresh green primary colour and bright yellow highlights.
- Use green for key actions, selected states and progress; reserve yellow for warmth, emphasis and small celebratory touches. Keep text and contrast accessible on both colours.
- Friendly, mature, confidence-building tone; not childish and not a school-style dashboard.
- Main language should use **Word Bank**, **Practise**, **Words to revisit**, and **Keep going**.

## Core features (in scope)

### 1. Authentication and privacy

- Sign in and sign out for Max and Tia.
- Each user can only view/change their own collection, attempts, answers and progress.
- The shared starter library is readable by both users.

### 2. Shared Library

Each Knowledge Item should support:

- Word or phrase
- Plain-English meaning
- Example sentence
- Category
- Difficulty: `beginner`, `intermediate`, or `advanced`
- Source: `seeded` or `user_added`

Initial categories:

- Everyday communication
- School / subjects
- Work
- Idioms / phrases
- Quotes

### 3. My Collection / Word Bank

- Like/save a library item into the user's personal Word Bank.
- Dislike/hide an item and later undo this.
- Add a personal word, phrase, quote or subject term directly to the user's collection.
- Display an understandable confidence status per saved item: **New**, **Learning**, **Confident**, or **Needs practice**.

Confidence must be calculated from recent answers, not manually self-rated. Keep the first formula simple and documented in code; it can evolve later.

### 4. Practice tests

Test sources:

- My Word Bank (liked/saved words only)
- Words I missed
- A selected category
- Mixed Library

Test lengths:

- Quick choices: 15, 30, 45, or 60 questions
- Custom: any whole number from 10 to 200
- The app must cap the selected size at the number of eligible items available and explain this clearly.

Question types (all tap-to-select; no typed answers in this prototype):

- Multiple choice
- True / False

The test builder may mix question types automatically. It must avoid presenting the same Knowledge Item twice in one attempt.

### 5. Results and retesting

After each test show:

- Score and percentage
- Time taken
- Correct and incorrect answers
- The words missed, with their meanings
- A clear **Practise missed items** action

### 6. Competency and progress statistics

Home should provide an encouraging snapshot, for example:

- Words saved
- Words practised
- Overall accuracy
- Accuracy this week / recent accuracy
- Strongest category
- Weakest category
- Number of words ready to revisit

The app should communicate progress as knowledge growth, not as a harsh grade. Do not claim a user is objectively fluent or competent overall; use precise phrases such as “Your accuracy”, “Most confident area”, and “Words to revisit”.

## Suggested screens

| Screen | Required content and actions |
|---|---|
| Sign in | Secure sign-in, clear simple error state |
| Home | Progress snapshot; Continue practising; Add a word; Browse Library; latest practice |
| Library | Browse/filter starter items; view meaning/example; like/dislike |
| My Collection | Saved and personal items; confidence status; remove/unhide where appropriate |
| Practise setup | Choose source, question count and mixed question types |
| Question | One question, answer options, progress indicator, accessible next action |
| Results | Score, time, review of misses, practise-missed action |
| Profile | Display name; optional three-question onboarding preferences; sign out |

## Optional lightweight onboarding

Ask once after first sign-in, but do not block use:

- What do you want to improve? (speaking confidently, school, work, vocabulary)
- Categories that interest you
- Current level: beginner, intermediate, advanced

## Data model (minimum viable)

| Table | Purpose |
|---|---|
| `profiles` | User display name and optional onboarding preferences |
| `knowledge_items` | Shared seeded library and user-created knowledge items |
| `user_collections` | Each user's saved/hidden relationship to an item and confidence status/data |
| `activity_attempts` | Practice session source, requested/actual length, score, time and completion data |
| `attempt_answers` | Item-level question type, selected answer, correctness and timestamps |

### RLS rules

- `profiles`: user can select/update only their own row.
- `knowledge_items`: all authenticated users can read shared seeded items; a user can create, update and delete only items they own.
- `user_collections`, `activity_attempts`, `attempt_answers`: owner-only select/insert/update/delete, with ownership enforced in both `USING` and `WITH CHECK` clauses for updates.
- Any child answer record must be linked to an attempt owned by the current user.
- The next Codex must prove both accounts cannot read each other's private rows in local testing.

## Explicitly out of scope

- AI recommendations or generated content
- Memory games
- Typed/free-text answers
- Matching, drag-and-drop, or other activity types
- Leaderboards, rankings, social features, certificates, streaks and badges
- Payments
- Notifications
- Complex teacher/admin tools
- Public sign-up or a multi-user classroom workflow

## Acceptance criteria before deployment

1. Local Supabase starts successfully via Docker.
2. Migrations create the schema from an empty local database.
3. Two test accounts can sign in locally.
4. RLS testing shows account A cannot access account B’s private collection or results.
5. Each account can save a word, create a personal word, run a 15-question Word Bank test, review results and retest missed words.
6. Custom practice accepts 10–200 and caps to eligible item count.
7. Multiple Choice and True / False questions function on a phone-sized viewport.
8. Home statistics update after a completed practice attempt.
9. The Vite production build passes.
10. Only after all previous criteria pass may the app be configured for a hosted Supabase project and GitHub Pages.
