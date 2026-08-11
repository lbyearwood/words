begin;
select plan(50);

select has_table('public', 'learner_plans', 'learner plans exist');
select has_table('public', 'learner_categories', 'learner categories exist');
select has_table('public', 'learner_term_families', 'term families exist');
select has_table('public', 'learning_items', 'learner-owned items exist');
select has_table('public', 'vocabulary_items', 'vocabulary content exists');
select has_table('public', 'learning_item_categories', 'learner category mappings exist');
select has_table('public', 'learner_category_focus', 'temporary focus exists');
select has_table('public', 'learner_activity_attempt_categories', 'learner attempt category snapshots exist');
select has_table('private', 'content_review_records', 'private reviews exist');
select has_table('private', 'personalised_content_manifests', 'idempotent manifests exist');
select has_table('private', 'assessment_templates', 'future assessment foundation exists');
select has_column('public', 'attempt_answers', 'learning_item_id', 'answers reference learner items');
select has_column('public', 'user_collections', 'learning_item_id', 'collections reference learner items');
select has_column('public', 'user_item_learning_states', 'content_version', 'memory state is content-versioned');
select has_function('public', 'get_my_learning_plan', array[]::text[], 'learning plan RPC exists');
select has_function('public', 'get_my_categories', array[]::text[], 'learner category RPC exists');
select has_function('public', 'get_my_library', array['text','uuid[]','integer','integer'], 'focused library RPC exists');
select has_function('public', 'get_my_collection', array[]::text[], 'focused collection RPC exists');
select has_function('public', 'create_personal_vocabulary_item',
  array['text','text','text','uuid','knowledge_difficulty','uuid[]','text','text','text'],
  'personal vocabulary RPC exists');
select is(public.fsrs_retrievability(2.3065, 2), 0.90949326::numeric, 'FSRS-6 reference is retained');
select is((select stability from private.fsrs_next_state(null, null, 0, 3::smallint)), 2.3065::numeric, 'FSRS-6 Good state is retained');
select is((select count(*)::integer from pg_tables where schemaname = 'public' and tablename in (
  'learner_plans','learner_categories','learner_term_families','learning_items',
  'vocabulary_items','learning_item_categories','learner_category_focus','learner_point_event_categories'
) and rowsecurity), 8, 'RLS is enabled on every v2 public table');
select is((select count(*)::integer from pg_tables where schemaname = 'private' and tablename like 'wordnet_%'), 0, 'WordNet tables are removed');

insert into auth.users (id, email, aud, role, created_at, updated_at)
values
  ('10000000-0000-0000-0000-000000000001', 'max-v2@example.test', 'authenticated', 'authenticated', now(), now()),
  ('20000000-0000-0000-0000-000000000002', 'tia-v2@example.test', 'authenticated', 'authenticated', now(), now());

insert into public.profiles (id, display_name)
values
  ('10000000-0000-0000-0000-000000000001', 'Max'),
  ('20000000-0000-0000-0000-000000000002', 'Tia')
on conflict (id) do update set display_name = excluded.display_name;

select is((select count(*)::integer from public.learner_categories where user_id = '10000000-0000-0000-0000-000000000001'), 14, 'Max receives 14 categories');
select is((select count(*)::integer from public.learner_categories where user_id = '20000000-0000-0000-0000-000000000002'), 15, 'Tia receives 15 categories');
select is((select plan_name from public.learner_plans where user_id = '10000000-0000-0000-0000-000000000001'), 'Sophisticated Speaker at Work', 'Max receives his permanent plan');
select is((select plan_name from public.learner_plans where user_id = '20000000-0000-0000-0000-000000000002'), 'Year 9 Learning', 'Tia receives her permanent plan');
select is((select count(*)::integer from public.learner_category_focus where user_id = '10000000-0000-0000-0000-000000000001'), 4, 'Max receives one primary and three supporting focuses');
select is((select count(*)::integer from public.learner_category_focus where user_id = '20000000-0000-0000-0000-000000000002'), 4, 'Tia receives one primary and three supporting focuses');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is((select count(*)::integer from public.learner_categories), 14, 'Max cannot see Tia categories');
select is((public.get_my_learning_plan()->'plan'->>'plan_name'), 'Sophisticated Speaker at Work', 'Max reads only his plan');

create temporary table max_item as
select public.create_personal_vocabulary_item(
  'Alleviate',
  'To make a problem or difficult situation less severe.',
  'The revised handover process should alleviate pressure on the support team.',
  (select id from public.learner_categories where slug = 'sophisticated_speaker'),
  'intermediate',
  array[(select id from public.learner_categories where slug = 'leadership_management')],
  'verb', 'uh-LEE-vee-ate', 'make less severe'
) id;

select is((select count(*)::integer from public.get_my_categories()), 14, 'category RPC returns Max categories');
select is(jsonb_array_length(public.get_my_library()), 1, 'Max library contains his new item');
select is((public.get_practice_setup_counts()->>'recommended')::integer, 1, 'pending self-added term is immediately testable');
select is((select qa_status::text from public.learning_items where id = (select id from max_item)), 'pending', 'self-added term remains review pending');
select ok((select practice_enabled from public.learning_items where id = (select id from max_item)), 'self-added term is practice-enabled');

create temporary table max_liked_item as
select public.set_learning_item_preference(
  (select id from max_item), null, true, null
) result;
select is(
  (select result->>'state' from max_liked_item),
  'saved',
  'liking a term automatically saves it to the collection'
);
select ok(
  (select (result->>'is_liked')::boolean from max_liked_item),
  'the preference response confirms the term is liked'
);
select is(
  (select count(*)::integer from public.user_collections
   where user_id = '10000000-0000-0000-0000-000000000001'
     and learning_item_id = (select id from max_item)
     and state = 'saved'
     and is_liked),
  1,
  'the saved and liked state is persisted together'
);

create temporary table max_attempt as
select public.create_practice_attempt('recommended', 10, '{}', null) result;
select is((select (result->>'actual_length')::integer from max_attempt), 1, 'short pools cap cleanly');
select is(
  (public.get_practice_attempt((select (result->>'attempt_id')::uuid from max_attempt))->'answers'->0->>'pronunciation'),
  'uh-LEE-vee-ate',
  'practice questions expose the learner pronunciation'
);
select is(
  (public.get_practice_attempt((select (result->>'attempt_id')::uuid from max_attempt))->'answers'->0->>'correct_answer'),
  null::text,
  'unanswered practice questions still hide the correct answer'
);
select is(
  (select count(*)::integer
   from public.learner_activity_attempt_categories
   where attempt_id = (select (result->>'attempt_id')::uuid from max_attempt)),
  4,
  'recommended attempts snapshot all active learner targets'
);

create temporary table max_category_attempt as
select public.create_practice_attempt(
  'category',
  10,
  array[(select id::text from public.learner_categories where slug = 'sophisticated_speaker')],
  null
) result;
select is(
  (select category_id from public.activity_attempts
   where id = (select (result->>'attempt_id')::uuid from max_category_attempt)),
  null::text,
  'learner category IDs are not written to the legacy category foreign key'
);
select is(
  (select focus_label from public.activity_attempts
   where id = (select (result->>'attempt_id')::uuid from max_category_attempt)),
  'Sophisticated Speaker',
  'selected-category attempts retain their readable focus label'
);
select is(
  (select count(*)::integer
   from public.learner_activity_attempt_categories
   where attempt_id = (select (result->>'attempt_id')::uuid from max_category_attempt)
     and learner_category_id = (select id from public.learner_categories where slug = 'sophisticated_speaker')),
  1,
  'selected-category attempts snapshot the learner category'
);

select throws_ok(
  $$ select public.set_category_goals(
    (select id::text from public.learner_categories where user_id = '20000000-0000-0000-0000-000000000002' limit 1), '{}'
  ) $$,
  'P0001', 'Choose categories from your learning plan',
  'Max cannot select a Tia category'
);

select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000002', true);
select is((select count(*)::integer from public.learner_categories), 15, 'Tia cannot see Max categories');
select is(jsonb_array_length(public.get_my_library()), 0, 'Tia cannot see Max learning content');
select throws_ok(
  $$ select public.get_practice_attempt((select (result->>'attempt_id')::uuid from max_attempt)) $$,
  'P0001', 'Attempt not found', 'Tia cannot read Max questions'
);

reset role;
select * from finish();
rollback;
