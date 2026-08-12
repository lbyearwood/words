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

## Completed production review

The initial Two-Learner V2 review was completed on 10 August 2026. Later
learner-requested additions continue the same audited batch sequence. The
hosted database retains the full per-item before/after evidence and content
hashes.

| Learner | Batches | Reviewed | Approved | Archived |
| --- | ---: | ---: | ---: | ---: |
| Max | 21 | 821 | 792 | 29 |
| Tia | 7 | 305 | 305 | 0 |

Max's decisions comprise 80 `keep`, 591 `rewrite`, 121 `change_sense` and 29
`exclude` records. Tia's decisions comprise 255 `keep`, 29 `rewrite` and 21
`change_sense` records. Archived items remain reversible and are excluded from
practice and mastery.

Production acceptance checks confirmed zero pending items, placeholder
examples, missing parts of speech, missing single-word pronunciations,
duplicate normalised term families, primary-category errors and cross-learner
category mappings. Rolled-back practice smoke tests generated 15 valid,
non-duplicated questions for each learner without retaining attempts.
