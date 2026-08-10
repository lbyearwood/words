# Personalised content batches

Max and Tia are curated independently in deterministic batches of at most 50
learner-owned items. A manifest is validated locally and then applied through
the database-owner-only `private.apply_personalised_content_manifest(jsonb)`
function. The database records the manifest ID and content hash, making a
repeat application harmless and rejecting changed content under the same ID.

Required root fields are `manifest_id`, `user_id`, `batch_number` and `items`.
Every non-excluded item requires a clean term, definition, natural example,
part of speech, recognisable pronunciation for single words, difficulty,
importance and one primary category. Excluded items require a reason.

Run:

```text
npm run content:validate -- content/personalised/max-batch-001.json
```

Manifests contain learning content but no credentials. Evidence should explain
why a definition, example and category fit that learner's permanent plan.
