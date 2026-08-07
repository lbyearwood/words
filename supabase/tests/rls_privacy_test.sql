BEGIN;
SELECT plan(82);

SELECT has_table('public', 'profiles', 'profiles table exists');
SELECT has_table('public', 'knowledge_items', 'knowledge_items table exists');
SELECT has_table('public', 'categories', 'categories table exists');
SELECT has_table('public', 'knowledge_item_categories', 'item category junction exists');
SELECT has_view('public', 'user_item_confidence', 'confidence view exists');
SELECT has_table('public', 'user_category_goals', 'category goals table exists');
SELECT has_table('public', 'user_item_learning_states', 'learning states table exists');
SELECT has_table('public', 'user_item_review_events', 'immutable review events table exists');
SELECT has_table('public', 'user_point_events', 'immutable Learning Points ledger exists');
SELECT has_table('public', 'user_point_event_categories', 'point target attribution snapshot exists');
SELECT has_table('public', 'user_point_totals', 'transactional Learning Points total exists');
SELECT has_column('public', 'activity_attempts', 'points_earned', 'attempts store their awarded point total');
SELECT has_function('public', 'get_points_summary', ARRAY[]::text[], 'owner points summary RPC exists');
SELECT has_column('public', 'user_collections', 'is_liked', 'collection rows can be marked as favourites');
SELECT has_column('public', 'user_collections', 'is_disliked', 'item preferences can be marked as disliked');
SELECT has_column('public', 'activity_attempts', 'focus_label', 'practice attempts snapshot their learner-facing focus');
SELECT has_function(
  'public',
  'create_scoped_practice_attempt',
  ARRAY['practice_source', 'integer', 'text[]', 'uuid', 'uuid[]'],
  'filtered collection practice RPC exists'
);
SELECT has_function(
  'public',
  'create_scoped_practice_attempt_with_focus',
  ARRAY['practice_source', 'integer', 'text[]', 'uuid', 'uuid[]', 'text'],
  'filtered collection practice stores its focus snapshot atomically'
);
SELECT has_view('public', 'user_category_mastery', 'category mastery view exists');
SELECT is(public.fsrs_retrievability(2.3065, 2), 0.90949326::numeric, 'FSRS-6 forgetting curve matches ts-fsrs 5.4.1');
SELECT is((SELECT stability FROM private.fsrs_next_state(null, null, 0, 3::smallint)), 2.3065::numeric, 'FSRS-6 initial Good stability matches reference');
SELECT is((SELECT difficulty FROM private.fsrs_next_state(2.3065, 2.11810397, 2, 3::smallint)), 2.11121424::numeric, 'FSRS-6 reviewed Good difficulty matches reference');
SELECT cmp_ok(
  (SELECT answer_points FROM private.calculate_learning_points('learning-points-v1', 'multiple_choice', 'intermediate', 'Learning', .70, 5, .50, 'neutral', 1, false, true, false)),
  '>',
  (SELECT answer_points FROM private.calculate_learning_points('learning-points-v1', 'true_false', 'intermediate', 'Learning', .70, 5, .50, 'neutral', 1, false, true, false)),
  'multiple choice retrieval earns more than true-or-false recognition'
);
SELECT cmp_ok(
  (SELECT answer_points FROM private.calculate_learning_points('learning-points-v1', 'multiple_choice', 'advanced', 'Learning', .70, 5, .50, 'neutral', 1, false, true, false)),
  '>',
  (SELECT answer_points FROM private.calculate_learning_points('learning-points-v1', 'multiple_choice', 'beginner', 'Learning', .70, 5, .50, 'neutral', 1, false, true, false)),
  'advanced content earns more than beginner content when other factors match'
);
SELECT cmp_ok(
  (SELECT answer_points FROM private.calculate_learning_points('learning-points-v1', 'multiple_choice', 'intermediate', 'Learning', .70, 5, 1, 'neutral', 1, false, true, false)),
  '>',
  (SELECT answer_points FROM private.calculate_learning_points('learning-points-v1', 'multiple_choice', 'intermediate', 'Learning', .70, 5, 0, 'neutral', 1, false, true, false)),
  'target relevance increases the reward for the same retrieval'
);
SELECT is(
  (SELECT answer_points FROM private.calculate_learning_points('learning-points-v1', 'multiple_choice', 'advanced', 'Needs practice', .30, 8, 1, 'liked', 1, true, false, false)),
  0,
  'incorrect answers never earn answer points'
);
SELECT is((SELECT count(*)::integer FROM public.categories), 28, 'all 28 approved top-level categories exist');
SELECT is(
  position(
    'pg_temp.practice_' in pg_get_functiondef(
      'public.create_practice_attempt(public.practice_source,integer,text[],uuid)'::regprocedure
    )
  ),
  0,
  'practice selection has no temporary staging relation dependency'
);
SELECT is(
  (SELECT sort_order FROM public.categories WHERE id = 'miscellaneous'),
  28::smallint,
  'Miscellaneous is the final fallback category'
);
SELECT cmp_ok(
  (SELECT count(*)::integer FROM public.knowledge_items WHERE source = 'seeded'),
  '>=',
  75,
  'shared library retains the 75 starter items and may include curated items'
);
SELECT is(
  (SELECT count(*)::integer FROM pg_tables WHERE schemaname = 'public' AND rowsecurity),
  14,
  'RLS is enabled on every public table'
);
SELECT is(
  (SELECT count(*)::integer FROM public.knowledge_items WHERE default_importance NOT BETWEEN 0 AND 1),
  0,
  'every Knowledge Item has a bounded default importance'
);
SELECT is(
  (SELECT count(*)::integer FROM public.knowledge_item_categories WHERE importance NOT BETWEEN 0 AND 1),
  0,
  'every category mapping has a bounded importance'
);
SELECT is(
  (
    SELECT count(*)::integer
    FROM public.knowledge_items item
    WHERE item.source = 'seeded'
      AND (SELECT count(*) FROM public.knowledge_item_categories mapping WHERE mapping.knowledge_item_id = item.id AND mapping.is_primary) = 1
  ),
  (SELECT count(*)::integer FROM public.knowledge_items WHERE source = 'seeded'),
  'every shared item has exactly one primary category'
);
SELECT is(
  (SELECT count(*)::integer FROM (
    SELECT knowledge_item_id, category_id FROM public.knowledge_item_categories GROUP BY 1, 2 HAVING count(*) > 1
  ) duplicate_mapping),
  0,
  'an item/category pair is stored once'
);
SELECT is(
  (SELECT count(*)::integer FROM (
    SELECT knowledge_item_id FROM public.knowledge_item_categories WHERE is_primary GROUP BY 1 HAVING count(*) > 1
  ) duplicate_primary),
  0,
  'an item has no more than one primary category'
);
SELECT is(
  (SELECT count(*)::integer FROM public.categories WHERE id IN ('sophisticated_speaker', 'leadership_management')),
  2,
  'the two curated categories exist without seeded counts'
);

INSERT INTO auth.users (id, email, aud, role, created_at, updated_at)
VALUES
  ('10000000-0000-0000-0000-000000000001', 'max-rls@example.test', 'authenticated', 'authenticated', now(), now()),
  ('20000000-0000-0000-0000-000000000002', 'tia-rls@example.test', 'authenticated', 'authenticated', now(), now());

INSERT INTO public.profiles (id, display_name)
VALUES
  ('10000000-0000-0000-0000-000000000001', 'Max'),
  ('20000000-0000-0000-0000-000000000002', 'Tia');

CREATE TEMPORARY TABLE expected_shared_counts AS
SELECT
  (SELECT count(*)::integer FROM public.knowledge_items WHERE source = 'seeded') AS item_count,
  (
    SELECT count(*)::integer
    FROM public.knowledge_item_categories mapping
    JOIN public.knowledge_items item ON item.id = mapping.knowledge_item_id
    WHERE item.source = 'seeded'
  ) AS mapping_count;
GRANT SELECT ON expected_shared_counts TO authenticated;

INSERT INTO public.user_collections (user_id, knowledge_item_id, state)
SELECT '10000000-0000-0000-0000-000000000001', id, 'saved'
FROM public.knowledge_items ORDER BY term LIMIT 1;

INSERT INTO public.activity_attempts (
  id, user_id, source, requested_length, actual_length
) VALUES (
  '30000000-0000-0000-0000-000000000003',
  '10000000-0000-0000-0000-000000000001',
  'word_bank', 10, 1
);

INSERT INTO public.attempt_answers (
  attempt_id, user_id, knowledge_item_id, position, question_type,
  prompt, options, correct_answer, selected_answer, is_correct, answered_at
)
SELECT
  '30000000-0000-0000-0000-000000000003',
  '10000000-0000-0000-0000-000000000001',
  id, 1, 'true_false', 'Test prompt', '["True", "False"]'::jsonb,
  'True', 'True', true, now()
FROM public.knowledge_items ORDER BY term LIMIT 1;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
SELECT is(
  (public.get_learning_dashboard()->'overall'->>'total_items')::integer,
  (SELECT count(*)::integer FROM public.knowledge_items),
  'overall mastery counts each visible Knowledge Item once despite category overlap'
);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);

SELECT is((SELECT display_name FROM public.profiles), 'Max', 'Max sees only his profile');
SELECT is((SELECT count(*)::integer FROM public.categories), 28, 'Max can read all categories');
SELECT is(
  (SELECT count(*)::integer FROM public.knowledge_item_categories),
  (SELECT mapping_count FROM expected_shared_counts),
  'Max can read all shared category mappings'
);
SELECT is(
  (SELECT count(*)::integer FROM public.knowledge_items WHERE source = 'seeded'),
  (SELECT item_count FROM expected_shared_counts),
  'Max can read the complete shared library'
);
SELECT is((SELECT count(*)::integer FROM public.user_collections), 1, 'Max can read his saved item');
UPDATE public.user_collections SET is_liked = true;
SELECT is((SELECT count(*)::integer FROM public.user_collections WHERE is_liked), 1, 'Max can favourite one shared collection row');
UPDATE public.user_collections SET state = 'preference', is_liked = false, is_disliked = true;
SELECT is((SELECT count(*)::integer FROM public.user_collections WHERE is_disliked), 1, 'Max can dislike a word without hiding it');
UPDATE public.user_collections SET state = 'saved', is_disliked = false;
SELECT is((SELECT count(*)::integer FROM public.activity_attempts), 1, 'Max can read his attempt');
SELECT is(has_table_privilege('authenticated', 'public.attempt_answers', 'select'), false, 'learners cannot read raw answers directly');

SELECT lives_ok(
  $$
    CREATE TEMPORARY TABLE scoped_collection_attempt AS
    SELECT public.create_scoped_practice_attempt_with_focus(
      'word_bank',
      10,
      '{}',
      null,
      ARRAY[(SELECT knowledge_item_id FROM public.user_collections LIMIT 1)],
      'My Collection | Liked Terms'
    ) AS result
  $$,
  'collection practice and its focus snapshot are created transactionally'
);
SELECT is(
  (
    SELECT focus_label
    FROM public.activity_attempts
    WHERE id = (SELECT (result->>'attempt_id')::uuid FROM scoped_collection_attempt)
  ),
  'My Collection | Liked Terms',
  'the collection focus snapshot is stored on the generated attempt'
);

SELECT lives_ok(
  $$ SELECT public.set_category_goals('education_learning', ARRAY['sophisticated_speaker']) $$,
  'Max can set one primary and supporting goal'
);
SELECT is((SELECT count(*)::integer FROM public.user_category_goals WHERE goal_role = 'primary'), 1, 'Max has one primary goal');
SELECT is((SELECT count(*)::integer FROM public.user_category_goals WHERE goal_role = 'supporting'), 1, 'Max has one supporting goal');

SELECT lives_ok(
  $$
    CREATE TEMPORARY TABLE generated_attempt AS
    SELECT public.create_practice_attempt('recommended', 10, '{}', null) AS result
  $$,
  'Recommended practice is generated transactionally'
);
SELECT is(
  (SELECT jsonb_array_length(public.get_practice_attempt((result->>'attempt_id')::uuid)->'answers') FROM generated_attempt),
  10,
  'Recommended practice contains ten unique questions'
);
SELECT lives_ok(
  $$
    SELECT public.submit_practice_answer(
      (
        SELECT (answer->>'id')::uuid
        FROM generated_attempt,
        LATERAL jsonb_array_elements(
          public.get_practice_attempt((result->>'attempt_id')::uuid)->'answers'
        ) answer
        ORDER BY (answer->>'position')::integer
        LIMIT 1
      ),
      'deliberately incorrect'
    )
  $$,
  'answer submission atomically creates learning state'
);
SELECT is((SELECT count(*)::integer FROM public.user_item_learning_states), 1, 'Max can read his new learning state');
SELECT is((SELECT count(*)::integer FROM public.user_item_review_events), 1, 'Max can read his review event');
SELECT lives_ok(
  $$
    SELECT public.submit_practice_answer(
      (
        SELECT (answer->>'id')::uuid
        FROM generated_attempt,
        LATERAL jsonb_array_elements(
          public.get_practice_attempt((result->>'attempt_id')::uuid)->'answers'
        ) answer
        ORDER BY (answer->>'position')::integer
        LIMIT 1
      ),
      'deliberately incorrect'
    )
  $$,
  'duplicate answer submission is idempotent'
);
SELECT is((SELECT count(*)::integer FROM public.user_point_events), 1, 'one immutable zero-point answer event is recorded once');
SELECT is((public.get_points_summary()->>'lifetime_points')::integer, 0, 'an incorrect answer does not inflate the learner total');

SELECT lives_ok(
  $$
    CREATE TEMPORARY TABLE created_personal_item AS
    SELECT public.create_personal_item(
      'Artful test item',
      'A temporary item used to verify category assignment.',
      'This temporary item is rolled back with the database test.',
      'sophisticated_speaker',
      'intermediate',
      ARRAY['professional_communication', 'leadership_management']
    ) AS id
  $$,
  'a personal item can be created with primary and secondary categories'
);
SELECT is(
  (SELECT count(*)::integer FROM public.knowledge_item_categories WHERE knowledge_item_id = (SELECT id FROM created_personal_item)),
  3,
  'the personal item stores all category assignments once'
);
SELECT is(
  (SELECT count(*)::integer FROM public.knowledge_item_categories WHERE knowledge_item_id = (SELECT id FROM created_personal_item) AND is_primary),
  1,
  'the personal item has exactly one primary category'
);
SELECT is(
  (SELECT default_importance FROM public.knowledge_items WHERE id = (SELECT id FROM created_personal_item)),
  0.700::numeric,
  'personal items receive the planned default importance'
);
SELECT is(
  (SELECT count(*)::integer FROM public.user_collections WHERE knowledge_item_id = (SELECT id FROM created_personal_item)),
  1,
  'the personal item has one shared Word Bank row'
);

SELECT set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000002', true);
SELECT is((SELECT display_name FROM public.profiles), 'Tia', 'Tia sees only her profile');
SELECT is((SELECT count(*)::integer FROM public.categories), 28, 'Tia can read all categories');
SELECT is(
  (SELECT count(*)::integer FROM public.knowledge_item_categories),
  (SELECT mapping_count FROM expected_shared_counts),
  'Tia can read all shared category mappings'
);
SELECT is((SELECT count(*)::integer FROM public.user_collections), 0, 'Tia cannot read Max''s collection');
SELECT is((SELECT count(*)::integer FROM public.activity_attempts), 0, 'Tia cannot read Max''s attempts');
SELECT is((SELECT count(*)::integer FROM public.user_category_goals), 0, 'Tia cannot read Max''s goals');
SELECT is((SELECT count(*)::integer FROM public.user_item_learning_states), 0, 'Tia cannot read Max''s learning states');
SELECT is((SELECT count(*)::integer FROM public.user_item_review_events), 0, 'Tia cannot read Max''s review events');
SELECT is((SELECT count(*)::integer FROM public.user_point_events), 0, 'Tia cannot read Max''s point ledger');
SELECT throws_ok(
  $$ SELECT public.get_practice_attempt((SELECT (result->>'attempt_id')::uuid FROM generated_attempt)) $$,
  'P0001',
  'Attempt not found',
  'Tia cannot retrieve Max''s protected questions'
);

SELECT throws_ok(
  $$
    INSERT INTO public.user_collections (user_id, knowledge_item_id, state)
    SELECT '10000000-0000-0000-0000-000000000001', id, 'saved'
    FROM public.knowledge_items ORDER BY term OFFSET 1 LIMIT 1
  $$,
  '42501',
  'new row violates row-level security policy for table "user_collections"',
  'Tia cannot insert a collection row owned by Max'
);

RESET ROLE;

SELECT has_table('private', 'wordnet_releases', 'private WordNet releases table exists');
SELECT has_table('private', 'wordnet_synsets', 'private WordNet synsets table exists');
SELECT has_table('private', 'wordnet_senses', 'private WordNet senses table exists');
SELECT has_table('private', 'wordnet_curation_records', 'private curation records table exists');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
SELECT throws_ok(
  $$ SELECT count(*) FROM private.wordnet_synsets $$,
  '42501',
  'permission denied for schema private',
  'authenticated learners cannot query private WordNet data'
);
SELECT throws_ok(
  $$ SELECT * FROM private.fsrs_next_state(null, null, 0, 3::smallint) $$,
  '42501',
  'permission denied for schema private',
  'authenticated learners cannot invoke private scheduler helpers'
);

SELECT * FROM finish();
ROLLBACK;
