-- Curate Max's requested modern terms as one audited batch. Formidable and
-- Perpetuity already exist, so the migration only changes their collection
-- preferences instead of creating duplicate learner-owned items.
do $$
declare
  max_user constant uuid := '8b57ddf0-1152-4b2a-85cd-ead229c3f075';
  v_batch_number constant integer := 18;
  v_manifest_id constant text := 'max-v2-curated-additions-018';
  requested jsonb := $terms$
  [
    {
      "term": "Atomic",
      "normalized_term": "atomic",
      "definition": "Carried out as one indivisible operation that either completes fully or does not happen at all.",
      "example_sentence": "The migration is atomic: either every record is updated successfully or none of the changes is retained.",
      "part_of_speech": "adjective",
      "pronunciation": "uh-TOM-ik",
      "sense_label": "indivisible operation",
      "difficulty": "advanced",
      "importance": 0.520,
      "categories": [
        {"slug": "critical_thinking_logic", "is_primary": true, "importance": 0.680},
        {"slug": "general_vocabulary", "is_primary": false, "importance": 0.350}
      ],
      "evidence": [
        {"type": "source", "url": "https://csrc.nist.gov/glossary/term/atomic_operation", "note": "Modern computing sense verified against the NIST glossary."},
        {"type": "learner_fit", "note": "Useful for discussing reliable technical and data operations at work."}
      ]
    },
    {
      "term": "Crude",
      "normalized_term": "crude",
      "definition": "Rough, basic or insufficiently detailed, and therefore not fully accurate or refined.",
      "example_sentence": "The initial forecast was crude, but it revealed that the programme would exceed its budget.",
      "part_of_speech": "adjective",
      "pronunciation": "krood",
      "sense_label": "rough or unrefined",
      "difficulty": "intermediate",
      "importance": 0.700,
      "categories": [
        {"slug": "critical_thinking_logic", "is_primary": true, "importance": 0.760},
        {"slug": "general_vocabulary", "is_primary": false, "importance": 0.650},
        {"slug": "professional_communication", "is_primary": false, "importance": 0.580}
      ],
      "evidence": [
        {"type": "source", "url": "https://dictionary.cambridge.org/dictionary/english/crude", "note": "Spelling and current sense verified."},
        {"type": "learner_fit", "note": "Supports precise evaluation of early estimates and incomplete analysis."}
      ]
    },
    {
      "term": "Disconcerting",
      "normalized_term": "disconcerting",
      "definition": "Causing uncertainty, unease or worry.",
      "example_sentence": "It was disconcerting to discover that the board had received two conflicting versions of the forecast.",
      "part_of_speech": "adjective",
      "pronunciation": "dis-kun-SUR-ting",
      "sense_label": "causing unease",
      "difficulty": "advanced",
      "importance": 0.720,
      "categories": [
        {"slug": "sophisticated_speaker", "is_primary": true, "importance": 0.820},
        {"slug": "professional_communication", "is_primary": false, "importance": 0.700},
        {"slug": "social_communication", "is_primary": false, "importance": 0.580}
      ],
      "evidence": [
        {"type": "source", "url": "https://dictionary.cambridge.org/dictionary/english/disconcerting", "note": "Spelling and current sense verified."},
        {"type": "learner_fit", "note": "Useful for describing concerning situations without exaggeration."}
      ]
    },
    {
      "term": "Disparaging",
      "normalized_term": "disparaging",
      "definition": "Expressing criticism in a way that shows a lack of respect or value.",
      "example_sentence": "The chair challenged the disparaging remarks before they undermined trust within the team.",
      "part_of_speech": "adjective",
      "pronunciation": "dis-PARR-i-jing",
      "sense_label": "showing disrespect",
      "difficulty": "advanced",
      "importance": 0.790,
      "categories": [
        {"slug": "professional_communication", "is_primary": true, "importance": 0.860},
        {"slug": "leadership_management", "is_primary": false, "importance": 0.820},
        {"slug": "social_communication", "is_primary": false, "importance": 0.760},
        {"slug": "sophisticated_speaker", "is_primary": false, "importance": 0.660}
      ],
      "evidence": [
        {"type": "source", "url": "https://dictionary.cambridge.org/dictionary/english/disparaging", "note": "Spelling and current sense verified."},
        {"type": "learner_fit", "note": "Relevant to respectful leadership and workplace communication."}
      ]
    },
    {
      "term": "Revert",
      "normalized_term": "revert",
      "definition": "To return to a previous state, method or behaviour.",
      "example_sentence": "If the pilot does not improve turnaround times, we will revert to the existing approval process.",
      "part_of_speech": "verb",
      "pronunciation": "ri-VURT",
      "sense_label": "return to an earlier state",
      "difficulty": "intermediate",
      "importance": 0.780,
      "categories": [
        {"slug": "professional_communication", "is_primary": true, "importance": 0.840},
        {"slug": "general_vocabulary", "is_primary": false, "importance": 0.720},
        {"slug": "leadership_management", "is_primary": false, "importance": 0.640}
      ],
      "evidence": [
        {"type": "source", "url": "https://dictionary.cambridge.org/dictionary/english/revert-to", "note": "Spelling and the standard British-English sense verified."},
        {"type": "learner_fit", "note": "Natural in discussions about pilots, processes and contingency decisions."}
      ]
    },
    {
      "term": "Melodramatic",
      "normalized_term": "melodramatic",
      "definition": "Showing or describing much stronger emotion than a situation justifies.",
      "example_sentence": "Describing one missed milestone as a disaster would be melodramatic; the recovery plan is already working.",
      "part_of_speech": "adjective",
      "pronunciation": "mel-uh-druh-MAT-ik",
      "sense_label": "excessively emotional",
      "difficulty": "intermediate",
      "importance": 0.610,
      "categories": [
        {"slug": "sophisticated_speaker", "is_primary": true, "importance": 0.700},
        {"slug": "social_communication", "is_primary": false, "importance": 0.680},
        {"slug": "professional_communication", "is_primary": false, "importance": 0.620}
      ],
      "evidence": [
        {"type": "source", "url": "https://dictionary.cambridge.org/dictionary/english/melodramatic", "note": "Spelling and current sense verified."},
        {"type": "learner_fit", "note": "Supports measured judgement when discussing setbacks at work."}
      ]
    },
    {
      "term": "Impregnable",
      "normalized_term": "impregnable",
      "definition": "So strong or well protected that it seems impossible to defeat, overcome or penetrate.",
      "example_sentence": "Our market position appeared impregnable until a smaller competitor introduced a cheaper service.",
      "part_of_speech": "adjective",
      "pronunciation": "im-PREG-nuh-bul",
      "sense_label": "impossible to overcome",
      "difficulty": "advanced",
      "importance": 0.660,
      "categories": [
        {"slug": "sophisticated_speaker", "is_primary": true, "importance": 0.760},
        {"slug": "business_economics", "is_primary": false, "importance": 0.640},
        {"slug": "critical_thinking_logic", "is_primary": false, "importance": 0.600}
      ],
      "evidence": [
        {"type": "source", "url": "https://dictionary.cambridge.org/dictionary/english/impregnable", "note": "Spelling and current sense verified."},
        {"type": "learner_fit", "note": "Useful figuratively when evaluating competitive strength and defensibility."}
      ]
    },
    {
      "term": "Obfuscate",
      "normalized_term": "obfuscate",
      "definition": "To make something less clear or harder to understand, especially deliberately.",
      "example_sentence": "The revised dashboard should clarify performance, not obfuscate it with vanity metrics.",
      "part_of_speech": "verb",
      "pronunciation": "OB-fus-kayt",
      "sense_label": "make unclear",
      "difficulty": "advanced",
      "importance": 0.860,
      "categories": [
        {"slug": "critical_thinking_logic", "is_primary": true, "importance": 0.900},
        {"slug": "sophisticated_speaker", "is_primary": false, "importance": 0.840},
        {"slug": "professional_communication", "is_primary": false, "importance": 0.800},
        {"slug": "academic_language_writing", "is_primary": false, "importance": 0.740},
        {"slug": "research_methods_evidence", "is_primary": false, "importance": 0.700}
      ],
      "evidence": [
        {"type": "source", "url": "https://dictionary.cambridge.org/dictionary/english/obfuscate", "note": "Spelling and current sense verified."},
        {"type": "learner_fit", "note": "Highly relevant to clear reporting, reasoning and professional communication."}
      ]
    }
  ]
  $terms$::jsonb;
  entry jsonb;
  categories_json jsonb;
  full_manifest jsonb;
  source_id uuid;
  learner_family_id uuid;
  learning_id uuid;
  category_count integer;
  approved_count integer;
  liked_count integer;
begin
  -- Production contains Max. Schema-only local resets intentionally do not.
  if not exists (
    select 1 from public.profiles profile
    where profile.id = max_user and lower(profile.display_name) = 'max'
  ) then
    raise notice 'Max profile is absent; skipping Max-specific curated content.';
    return;
  end if;

  if not exists (
    select 1 from private.personalised_content_manifests manifest
    where manifest.manifest_id = v_manifest_id
  ) then
    full_manifest := jsonb_build_object(
      'manifest_id', v_manifest_id,
      'user_id', max_user,
      'batch_number', v_batch_number,
      'items', '[]'::jsonb
    );

    for entry in select value from jsonb_array_elements(requested)
    loop
      if exists (
        select 1
        from public.learner_term_families family
        where family.user_id = max_user
          and family.normalized_term = entry->>'normalized_term'
      ) then
        raise exception 'Requested term already exists for Max: %', entry->>'term';
      end if;

      select jsonb_agg(
        jsonb_build_object(
          'category_id', category.id,
          'is_primary', (mapping->>'is_primary')::boolean,
          'importance', (mapping->>'importance')::numeric
        )
        order by (mapping->>'is_primary')::boolean desc, category.sort_order
      ), count(*)
      into categories_json, category_count
      from jsonb_array_elements(entry->'categories') mapping
      join public.learner_categories category
        on category.user_id = max_user
       and category.slug = mapping->>'slug';

      if category_count <> jsonb_array_length(entry->'categories') then
        raise exception 'A requested category is not available to Max for %', entry->>'term';
      end if;

      source_id := gen_random_uuid();
      learner_family_id := gen_random_uuid();
      learning_id := gen_random_uuid();

      insert into public.knowledge_items (
        id, term, meaning, example_sentence, difficulty, source, owner_id,
        default_importance, part_of_speech, pronunciation, sense_label
      ) values (
        source_id,
        entry->>'term',
        entry->>'definition',
        entry->>'example_sentence',
        (entry->>'difficulty')::public.knowledge_difficulty,
        'user_added',
        max_user,
        (entry->>'importance')::numeric,
        entry->>'part_of_speech',
        entry->>'pronunciation',
        entry->>'sense_label'
      );

      insert into public.knowledge_item_categories (
        knowledge_item_id, category_id, is_primary, importance
      )
      select
        source_id,
        category.id,
        (mapping->>'is_primary')::boolean,
        (mapping->>'importance')::numeric
      from jsonb_array_elements(entry->'categories') mapping
      join public.categories category on category.id = mapping->>'slug';

      insert into public.learner_term_families (
        id, user_id, normalized_term, display_term
      ) values (
        learner_family_id, max_user, entry->>'normalized_term', entry->>'term'
      );

      insert into public.learning_items (
        id, user_id, item_type, source_knowledge_item_id, difficulty,
        importance, origin, qa_status, practice_enabled
      ) values (
        learning_id,
        max_user,
        'vocabulary',
        source_id,
        (entry->>'difficulty')::public.knowledge_difficulty,
        (entry->>'importance')::numeric,
        'curated',
        'pending',
        false
      );

      insert into public.vocabulary_items (
        learning_item_id, user_id, term_family_id, definition,
        example_sentence, part_of_speech, pronunciation, sense_label,
        sense_order, evidence
      ) values (
        learning_id,
        max_user,
        learner_family_id,
        entry->>'definition',
        entry->>'example_sentence',
        entry->>'part_of_speech',
        entry->>'pronunciation',
        entry->>'sense_label',
        1,
        entry->'evidence'
      );

      insert into private.content_review_records (
        learning_item_id, user_id, batch_number, before_content, drafted_at
      ) values (
        learning_id, max_user, v_batch_number, '{}'::jsonb, now()
      );

      full_manifest := jsonb_set(
        full_manifest,
        '{items}',
        (full_manifest->'items') || jsonb_build_array(jsonb_build_object(
          'learning_item_id', learning_id,
          'decision', 'keep',
          'reason', 'Spelling, meaning, example, metadata and learner fit were reviewed before approval.',
          'term', entry->>'term',
          'definition', entry->>'definition',
          'example_sentence', entry->>'example_sentence',
          'part_of_speech', entry->>'part_of_speech',
          'pronunciation', entry->>'pronunciation',
          'sense_label', entry->>'sense_label',
          'difficulty', entry->>'difficulty',
          'importance', (entry->>'importance')::numeric,
          'categories', categories_json,
          'evidence', entry->'evidence'
        ))
      );
    end loop;

    perform private.apply_personalised_content_manifest(full_manifest);
  end if;

  -- Save and like the eight new items plus the two exact existing items.
  insert into public.user_collections (
    user_id, knowledge_item_id, learning_item_id, state, is_liked, is_disliked
  )
  select
    max_user,
    learning.source_knowledge_item_id,
    learning.id,
    'saved'::public.collection_state,
    true,
    false
  from public.learner_term_families family
  join public.vocabulary_items vocabulary
    on vocabulary.user_id = max_user
   and vocabulary.term_family_id = family.id
  join public.learning_items learning
    on learning.id = vocabulary.learning_item_id
   and learning.user_id = max_user
  where family.user_id = max_user
    and family.normalized_term = any (array[
      'atomic', 'crude', 'disconcerting', 'perpetuity', 'disparaging',
      'revert', 'melodramatic', 'impregnable', 'formidable', 'obfuscate'
    ])
  on conflict (user_id, knowledge_item_id) do update
  set learning_item_id = excluded.learning_item_id,
      state = 'saved'::public.collection_state,
      is_liked = true,
      is_disliked = false,
      updated_at = now();

  select count(distinct family.normalized_term)
  into approved_count
  from public.learner_term_families family
  join public.vocabulary_items vocabulary
    on vocabulary.user_id = max_user
   and vocabulary.term_family_id = family.id
  join public.learning_items learning
    on learning.id = vocabulary.learning_item_id
   and learning.user_id = max_user
  where family.user_id = max_user
    and family.normalized_term = any (array[
      'atomic', 'crude', 'disconcerting', 'perpetuity', 'disparaging',
      'revert', 'melodramatic', 'impregnable', 'formidable', 'obfuscate'
    ])
    and learning.qa_status = 'approved'
    and learning.practice_enabled
    and learning.archived_at is null;

  select count(distinct family.normalized_term)
  into liked_count
  from public.learner_term_families family
  join public.vocabulary_items vocabulary
    on vocabulary.user_id = max_user
   and vocabulary.term_family_id = family.id
  join public.learning_items learning
    on learning.id = vocabulary.learning_item_id
   and learning.user_id = max_user
  join public.user_collections collection
    on collection.user_id = max_user
   and collection.learning_item_id = learning.id
  where family.user_id = max_user
    and family.normalized_term = any (array[
      'atomic', 'crude', 'disconcerting', 'perpetuity', 'disparaging',
      'revert', 'melodramatic', 'impregnable', 'formidable', 'obfuscate'
    ])
    and collection.state = 'saved'
    and collection.is_liked
    and not collection.is_disliked;

  if approved_count <> 10 then
    raise exception 'Expected 10 approved modern requested terms, found %', approved_count;
  end if;
  if liked_count <> 10 then
    raise exception 'Expected 10 saved and liked requested terms, found %', liked_count;
  end if;
  if exists (
    select 1 from public.learner_term_families family
    where family.user_id = max_user and family.normalized_term = 'informidable'
  ) then
    raise exception 'Obsolete term Informidable must not enter Max''s active curriculum';
  end if;
end;
$$;
