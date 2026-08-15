-- Add Max's requested, learner-owned Concession item as audited batch 22.
do $$
declare
  max_user constant uuid := '8b57ddf0-1152-4b2a-85cd-ead229c3f075';
  v_batch_number constant integer := 22;
  v_manifest_id constant text := 'max-v2-curated-additions-022';
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
      where family.user_id = max_user and family.normalized_term = 'concession'
    ) then
      raise exception 'Concession already exists for Max';
    end if;

    select jsonb_agg(jsonb_build_object(
      'category_id', category.id,
      'is_primary', category.slug = 'professional_communication',
      'importance', case category.slug
        when 'professional_communication' then 0.920
        when 'leadership_management' then 0.880
        when 'sophisticated_speaker' then 0.840
        when 'social_communication' then 0.760
        when 'critical_thinking_logic' then 0.700
        when 'business_economics' then 0.620
        when 'general_vocabulary' then 0.580
      end
    ) order by category.sort_order)
    into categories_json
    from public.learner_categories category
    where category.user_id = max_user
      and category.slug in (
        'professional_communication', 'leadership_management',
        'sophisticated_speaker', 'social_communication',
        'critical_thinking_logic', 'business_economics',
        'general_vocabulary'
      );

    if coalesce(jsonb_array_length(categories_json), 0) <> 7 then
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
      'Concession',
      'Something you agree to give, allow or change in order to reach an agreement or make a dispute easier to resolve.',
      'To secure stakeholder support, we made a limited concession on the implementation timetable without changing the overall strategy.',
      'advanced',
      'user_added',
      max_user,
      0.780,
      'noun',
      'kun-SESH-un',
      'compromise made to reach agreement'
    );

    insert into public.knowledge_item_categories (
      knowledge_item_id, category_id, is_primary, importance
    ) values
      (source_id, 'professional_communication', true, 0.920),
      (source_id, 'leadership_management', false, 0.880),
      (source_id, 'sophisticated_speaker', false, 0.840),
      (source_id, 'social_communication', false, 0.760),
      (source_id, 'critical_thinking_logic', false, 0.700),
      (source_id, 'business_economics', false, 0.620),
      (source_id, 'general_vocabulary', false, 0.580);

    insert into public.learner_term_families (
      id, user_id, normalized_term, display_term
    ) values (
      learner_family_id, max_user, 'concession', 'Concession'
    );

    insert into public.learning_items (
      id, user_id, item_type, source_knowledge_item_id, difficulty,
      importance, origin, qa_status, practice_enabled
    ) values (
      learning_id, max_user, 'vocabulary', source_id, 'advanced', 0.780,
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
      'Something you agree to give, allow or change in order to reach an agreement or make a dispute easier to resolve.',
      'To secure stakeholder support, we made a limited concession on the implementation timetable without changing the overall strategy.',
      'noun',
      'kun-SESH-un',
      'compromise made to reach agreement',
      1,
      jsonb_build_array(
        jsonb_build_object(
          'type', 'source',
          'url', 'https://www.oxfordlearnersdictionaries.com/definition/english/concession',
          'note', 'Spelling, pronunciation and the negotiation sense were verified.'
        ),
        jsonb_build_object(
          'type', 'source',
          'url', 'https://dictionary.cambridge.org/dictionary/english/concession',
          'note', 'The current British English meaning and usage were cross-checked.'
        ),
        jsonb_build_object(
          'type', 'learner_fit',
          'note', 'Useful for discussing compromise, negotiation and stakeholder agreement at work.'
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
        'reason', 'Spelling, meaning, example, metadata and workplace relevance were reviewed before approval.',
        'term', 'Concession',
        'definition', 'Something you agree to give, allow or change in order to reach an agreement or make a dispute easier to resolve.',
        'example_sentence', 'To secure stakeholder support, we made a limited concession on the implementation timetable without changing the overall strategy.',
        'part_of_speech', 'noun',
        'pronunciation', 'kun-SESH-un',
        'sense_label', 'compromise made to reach agreement',
        'difficulty', 'advanced',
        'importance', 0.780,
        'categories', categories_json,
        'evidence', jsonb_build_array(
          jsonb_build_object(
            'type', 'source',
            'url', 'https://www.oxfordlearnersdictionaries.com/definition/english/concession',
            'note', 'Spelling, pronunciation and the negotiation sense were verified.'
          ),
          jsonb_build_object(
            'type', 'source',
            'url', 'https://dictionary.cambridge.org/dictionary/english/concession',
            'note', 'The current British English meaning and usage were cross-checked.'
          ),
          jsonb_build_object(
            'type', 'learner_fit',
            'note', 'Useful for discussing compromise, negotiation and stakeholder agreement at work.'
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
    and family.normalized_term = 'concession'
    and vocabulary.sense_label = 'compromise made to reach agreement'
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
    and family.normalized_term = 'concession'
    and vocabulary.sense_label = 'compromise made to reach agreement'
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
    and family.normalized_term = 'concession'
    and vocabulary.sense_label = 'compromise made to reach agreement'
    and collection.state = 'saved'
    and collection.is_liked
    and not collection.is_disliked;

  if approved_count <> 1 then
    raise exception 'Expected one approved Concession item, found %', approved_count;
  end if;
  if liked_count <> 1 then
    raise exception 'Expected Concession to be saved and liked';
  end if;
end;
$$;
