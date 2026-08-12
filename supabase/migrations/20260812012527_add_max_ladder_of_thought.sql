-- Add Max's requested phrase as an explicitly curated metaphor. It is not
-- presented as an established idiom or as the separate Ladder of Inference.
do $$
declare
  max_user constant uuid := '8b57ddf0-1152-4b2a-85cd-ead229c3f075';
  v_batch_number constant integer := 20;
  v_manifest_id constant text := 'max-v2-curated-additions-020';
  source_id uuid;
  learner_family_id uuid;
  learning_id uuid;
  categories_json jsonb;
  full_manifest jsonb;
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
    if exists (
      select 1 from public.learner_term_families family
      where family.user_id = max_user
        and family.normalized_term = 'ladder of thought'
    ) then
      raise exception 'Ladder of thought already exists for Max';
    end if;

    select jsonb_agg(jsonb_build_object(
      'category_id', category.id,
      'is_primary', category.slug = 'phrases',
      'importance', case category.slug
        when 'phrases' then 0.650
        when 'critical_thinking_logic' then 0.600
        when 'academic_language_writing' then 0.450
      end
    ) order by category.sort_order)
    into categories_json
    from public.learner_categories category
    where category.user_id = max_user
      and category.slug in (
        'phrases', 'critical_thinking_logic', 'academic_language_writing'
      );

    if jsonb_array_length(categories_json) <> 3 then
      raise exception 'The required Max categories are unavailable';
    end if;

    source_id := gen_random_uuid();
    learner_family_id := gen_random_uuid();
    learning_id := gen_random_uuid();

    insert into public.knowledge_items (
      id, term, meaning, example_sentence, difficulty, source, owner_id,
      default_importance, part_of_speech, pronunciation, sense_label
    ) values (
      source_id,
      'Ladder of thought',
      'A sequence of connected reasoning steps in which each idea builds on the one before it.',
      'The strategy paper presents a clear ladder of thought, moving from evidence to assumptions and then to a recommendation.',
      'advanced',
      'user_added',
      max_user,
      0.500,
      'phrase',
      null,
      'connected sequence of reasoning'
    );

    insert into public.knowledge_item_categories (
      knowledge_item_id, category_id, is_primary, importance
    ) values
      (source_id, 'phrases', true, 0.650),
      (source_id, 'critical_thinking_logic', false, 0.600),
      (source_id, 'academic_language_writing', false, 0.450);

    insert into public.learner_term_families (
      id, user_id, normalized_term, display_term
    ) values (
      learner_family_id, max_user, 'ladder of thought', 'Ladder of thought'
    );

    insert into public.learning_items (
      id, user_id, item_type, source_knowledge_item_id, difficulty,
      importance, origin, qa_status, practice_enabled
    ) values (
      learning_id, max_user, 'vocabulary', source_id, 'advanced', 0.500,
      'curated', 'pending', false
    );

    insert into public.vocabulary_items (
      learning_item_id, user_id, term_family_id, definition,
      example_sentence, part_of_speech, pronunciation, sense_label,
      sense_order, evidence
    ) values (
      learning_id,
      max_user,
      learner_family_id,
      'A sequence of connected reasoning steps in which each idea builds on the one before it.',
      'The strategy paper presents a clear ladder of thought, moving from evidence to assumptions and then to a recommendation.',
      'phrase',
      null,
      'connected sequence of reasoning',
      1,
      jsonb_build_array(
        jsonb_build_object(
          'type', 'provenance',
          'note', 'User-requested curated metaphor; not presented as an established idiom or named framework.'
        ),
        jsonb_build_object(
          'type', 'contrast',
          'url', 'https://actiondesign.com/resources/readings/ladder-of-inference',
          'note', 'Distinguished from the established Ladder of Inference framework.'
        ),
        jsonb_build_object(
          'type', 'learner_fit',
          'note', 'A concise metaphor for explaining the structure of an argument or recommendation at work.'
        )
      )
    );

    insert into private.content_review_records (
      learning_item_id, user_id, batch_number, before_content, drafted_at
    ) values (
      learning_id, max_user, v_batch_number, '{}'::jsonb, now()
    );

    full_manifest := jsonb_build_object(
      'manifest_id', v_manifest_id,
      'user_id', max_user,
      'batch_number', v_batch_number,
      'items', jsonb_build_array(jsonb_build_object(
        'learning_item_id', learning_id,
        'decision', 'keep',
        'reason', 'The exact user-requested phrase is retained and accurately labelled as a curated metaphor.',
        'term', 'Ladder of thought',
        'definition', 'A sequence of connected reasoning steps in which each idea builds on the one before it.',
        'example_sentence', 'The strategy paper presents a clear ladder of thought, moving from evidence to assumptions and then to a recommendation.',
        'part_of_speech', 'phrase',
        'pronunciation', null,
        'sense_label', 'connected sequence of reasoning',
        'difficulty', 'advanced',
        'importance', 0.500,
        'categories', categories_json,
        'evidence', jsonb_build_array(
          jsonb_build_object(
            'type', 'provenance',
            'note', 'User-requested curated metaphor; not presented as an established idiom or named framework.'
          ),
          jsonb_build_object(
            'type', 'contrast',
            'url', 'https://actiondesign.com/resources/readings/ladder-of-inference',
            'note', 'Distinguished from the established Ladder of Inference framework.'
          ),
          jsonb_build_object(
            'type', 'learner_fit',
            'note', 'A concise metaphor for explaining the structure of an argument or recommendation at work.'
          )
        )
      ))
    );

    perform private.apply_personalised_content_manifest(full_manifest);
  end if;

  insert into public.user_collections (
    user_id, knowledge_item_id, learning_item_id, state, is_liked, is_disliked
  )
  select
    max_user, learning.source_knowledge_item_id, learning.id,
    'saved'::public.collection_state, true, false
  from public.learner_term_families family
  join public.vocabulary_items vocabulary
    on vocabulary.user_id = max_user and vocabulary.term_family_id = family.id
  join public.learning_items learning
    on learning.id = vocabulary.learning_item_id and learning.user_id = max_user
  where family.user_id = max_user
    and family.normalized_term = 'ladder of thought'
  on conflict (user_id, knowledge_item_id) do update
  set learning_item_id = excluded.learning_item_id,
      state = 'saved'::public.collection_state,
      is_liked = true,
      is_disliked = false,
      updated_at = now();

  select count(*) into approved_count
  from public.learner_term_families family
  join public.vocabulary_items vocabulary
    on vocabulary.user_id = max_user and vocabulary.term_family_id = family.id
  join public.learning_items learning
    on learning.id = vocabulary.learning_item_id and learning.user_id = max_user
  where family.user_id = max_user
    and family.normalized_term = 'ladder of thought'
    and learning.qa_status = 'approved'
    and learning.practice_enabled
    and learning.archived_at is null;

  select count(*) into liked_count
  from public.learner_term_families family
  join public.vocabulary_items vocabulary
    on vocabulary.user_id = max_user and vocabulary.term_family_id = family.id
  join public.learning_items learning
    on learning.id = vocabulary.learning_item_id and learning.user_id = max_user
  join public.user_collections collection
    on collection.user_id = max_user and collection.learning_item_id = learning.id
  where family.user_id = max_user
    and family.normalized_term = 'ladder of thought'
    and collection.state = 'saved'
    and collection.is_liked
    and not collection.is_disliked;

  if approved_count <> 1 then
    raise exception 'Expected one approved Ladder of thought item, found %', approved_count;
  end if;
  if liked_count <> 1 then
    raise exception 'Expected Ladder of thought to be saved and liked';
  end if;
end;
$$;
