-- Resolve the learner-owned item on every legacy-compatible review row. The
-- legacy knowledge_item_id remains temporarily so the proven FSRS-6 and point
-- calculations can continue to run during the additive rollout.
create or replace function private.populate_v2_learning_item_id()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.learning_item_id is null then
    if tg_table_name = 'user_item_review_events' then
      select answer.learning_item_id into new.learning_item_id
      from public.attempt_answers answer
      where answer.id = new.answer_id and answer.user_id = new.user_id;
    else
      select learning.id into new.learning_item_id
      from public.learning_items learning
      where learning.user_id = new.user_id
        and learning.source_knowledge_item_id = new.knowledge_item_id;
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.populate_v2_learning_item_id() from public, anon, authenticated;

create trigger attempt_answers_populate_learning_item
before insert or update of knowledge_item_id, learning_item_id on public.attempt_answers
for each row execute function private.populate_v2_learning_item_id();

create trigger learning_states_populate_learning_item
before insert or update of knowledge_item_id, learning_item_id on public.user_item_learning_states
for each row execute function private.populate_v2_learning_item_id();

create trigger review_events_populate_learning_item
before insert or update of answer_id, learning_item_id on public.user_item_review_events
for each row execute function private.populate_v2_learning_item_id();

create trigger point_events_populate_learning_item
before insert or update of knowledge_item_id, learning_item_id on public.user_point_events
for each row execute function private.populate_v2_learning_item_id();

create or replace function private.snapshot_v2_point_event_categories()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.learning_item_id is null then return new; end if;
  insert into public.learner_point_event_categories (
    event_id, user_id, learner_category_id, goal_role, goal_weight, importance
  )
  select new.id, new.user_id, mapping.learner_category_id,
    focus.goal_role, focus.goal_weight, mapping.importance
  from public.learning_item_categories mapping
  join public.learner_category_focus focus
    on focus.user_id = new.user_id
   and focus.learner_category_id = mapping.learner_category_id
  where mapping.learning_item_id = new.learning_item_id
  on conflict do nothing;
  return new;
end;
$$;

revoke all on function private.snapshot_v2_point_event_categories() from public, anon, authenticated;

create trigger point_events_snapshot_v2_categories
after insert on public.user_point_events
for each row execute function private.snapshot_v2_point_event_categories();

create or replace function private.create_v2_practice_attempt(
  p_source public.practice_source,
  p_requested_length integer,
  p_category_ids text[] default '{}',
  p_source_attempt_id uuid default null,
  p_item_ids uuid[] default '{}',
  p_focus_label text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller uuid := auth.uid();
  attempt_id uuid := gen_random_uuid();
  category_uuids uuid[] := '{}';
  eligible_count integer;
  actual_count integer;
  selected_items jsonb := '[]'::jsonb;
  position_index integer := 0;
  selected record;
  option_values jsonb;
  shown_meaning text;
  make_true boolean;
  preference text;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  if p_requested_length not between 10 and 200 then
    raise exception 'Question count must be between 10 and 200';
  end if;
  if p_focus_label is not null and char_length(btrim(p_focus_label)) > 120 then
    raise exception 'Practice focus label must be 120 characters or fewer';
  end if;
  begin
    select coalesce(array_agg(distinct value::uuid), '{}') into category_uuids
    from unnest(coalesce(p_category_ids, '{}')) value;
  exception when invalid_text_representation then
    raise exception 'Choose categories from your learning plan';
  end;
  if exists (
    select 1 from unnest(category_uuids) category_id
    where not exists (
      select 1 from public.learner_categories
      where id = category_id and user_id = caller
    )
  ) then raise exception 'Choose categories from your learning plan'; end if;
  if p_source = 'category' and cardinality(category_uuids) = 0 then
    raise exception 'Choose at least one category';
  end if;
  if p_source = 'attempt_misses' and not exists (
    select 1 from public.activity_attempts
    where id = p_source_attempt_id and user_id = caller
  ) then raise exception 'The source attempt was not found'; end if;

  with eligible as (
    select learning.id, learning.source_knowledge_item_id, learning.importance,
      vocabulary.term_family_id,
      coalesce(state.repetitions, 0) repetitions,
      coalesce(state.lapses, 0) lapses,
      state.stability, state.last_rating, state.last_review_at,
      state.last_answer_correct,
      private.v2_item_curriculum_value(caller, learning.id)::double precision curriculum,
      exists (
        select 1
        from public.learner_category_focus focus
        join public.learning_item_categories mapping
          on mapping.learner_category_id = focus.learner_category_id
         and mapping.learning_item_id = learning.id
        where focus.user_id = caller
      ) is_target,
      case when state.user_id is null then 0::double precision else public.fsrs_retrievability(
        state.stability,
        greatest(0, extract(epoch from (now() - state.last_review_at)) / 86400)
      )::double precision end retrievability
    from public.learning_items learning
    join public.vocabulary_items vocabulary on vocabulary.learning_item_id = learning.id
    left join public.user_item_learning_states state
      on state.user_id = caller and state.learning_item_id = learning.id
    where learning.user_id = caller
      and learning.item_type = 'vocabulary'
      and learning.practice_enabled
      and (learning.qa_status = 'approved' or learning.origin = 'user_created')
      and learning.archived_at is null
      and (cardinality(coalesce(p_item_ids, '{}')) = 0 or learning.id = any(p_item_ids))
      and (
        p_source = 'recommended'
        or (p_source = 'word_bank' and exists (
          select 1 from public.user_collections collection
          where collection.user_id = caller
            and collection.learning_item_id = learning.id
            and collection.state = 'saved'
        ))
        or p_source = 'mixed_library'
        or (p_source = 'category' and exists (
          select 1 from public.learning_item_categories mapping
          where mapping.learning_item_id = learning.id
            and mapping.learner_category_id = any(category_uuids)
        ))
        or (p_source = 'missed' and state.last_answer_correct = false)
        or (p_source = 'attempt_misses' and exists (
          select 1 from public.attempt_answers answer
          where answer.attempt_id = p_source_attempt_id
            and answer.user_id = caller
            and answer.learning_item_id = learning.id
            and answer.is_correct = false
        ))
      )
  ), one_sense_per_term as (
    select distinct on (term_family_id) *
    from eligible
    order by term_family_id, importance desc, id
  ), scored as (
    select *, 0.86::double precision + 0.08::double precision * curriculum desired_retention,
      1::double precision / (1::double precision + exp(-(((0.86::double precision + 0.08::double precision * curriculum) - retrievability) / 0.04::double precision))) urgency,
      case when stability is null then 1::double precision else exp(-stability::double precision / 14::double precision) end learning_gap,
      least(lapses::double precision / 4::double precision, 1::double precision) lapse_factor,
      1::double precision / sqrt(repetitions::double precision + 1::double precision) uncertainty,
      case
        when last_review_at is null then 1::double precision
        when last_answer_correct and last_review_at > now() - interval '12 hours' then 0.05::double precision
        when not last_answer_correct and last_review_at > now() - interval '10 minutes' then 0.10::double precision
        else 1::double precision
      end recency_multiplier
    from one_sense_per_term
  ), weighted as materialized (
    select *,
      case
        when p_source <> 'recommended' then 'manual'
        when is_target and repetitions = 0 then 'target_new'
        when is_target and retrievability <= desired_retention then 'target_due'
        when is_target and (coalesce(stability, 0) < 30 or last_rating = 1) then 'target_weak'
        when not is_target and repetitions > 0 and retrievability <= desired_retention then 'outside_due'
        else 'maintenance'
      end pool,
      case when p_source <> 'recommended' then 1::double precision else
        (0.02::double precision + power(curriculum, 1.5::double precision) *
          (0.55::double precision * urgency + 0.25::double precision * learning_gap +
           0.10::double precision * lapse_factor + 0.10::double precision * uncertainty)) *
        recency_multiplier
      end weight
    from scored
  ), keyed as (
    select *, -ln(
      ((hashtextextended(attempt_id::text || id::text, 0) & 9223372036854775807)::double precision + 1)
      / 9223372036854775808::double precision
    ) / greatest(weight, 0.000001) sample_key
    from weighted
  ), session as (
    select count(*)::integer eligible_count,
      least(p_requested_length, count(*)::integer) actual_count
    from keyed
  ), ranked as (
    select keyed.*, session.eligible_count, session.actual_count,
      row_number() over (partition by pool order by sample_key) pool_rank
    from keyed cross join session
  ), chosen as (
    select * from ranked
    order by case
      when p_source = 'recommended' and pool_rank <= case pool
        when 'target_due' then ceil(actual_count * 0.45)
        when 'target_weak' then ceil(actual_count * 0.20)
        when 'target_new' then ceil(actual_count * 0.15)
        when 'outside_due' then ceil(actual_count * 0.10)
        else ceil(actual_count * 0.10)
      end then 0 else 1 end,
      sample_key
    limit p_requested_length
  )
  select coalesce(max(eligible_count), 0)::integer,
    coalesce(max(actual_count), 0)::integer,
    coalesce(jsonb_agg(jsonb_build_object(
      'learning_item_id', id,
      'source_knowledge_item_id', source_knowledge_item_id,
      'pool', pool, 'weight', weight, 'curriculum', curriculum,
      'retrievability', retrievability,
      'desired_retention', desired_retention
    ) order by sample_key), '[]'::jsonb)
  into eligible_count, actual_count, selected_items
  from chosen;

  if eligible_count = 0 then
    raise exception 'There are no practice-ready terms in this source yet';
  end if;

  insert into public.activity_attempts (
    id, user_id, source, category_id, source_attempt_id, requested_length,
    actual_length, selection_version, goal_snapshot, focus_label
  ) values (
    attempt_id, caller, p_source,
    case when p_source = 'category' and cardinality(category_uuids) = 1 then category_uuids[1]::text else null end,
    case when p_source = 'attempt_misses' then p_source_attempt_id else null end,
    p_requested_length, actual_count, 'learner-owned-fsrs-v2',
    coalesce((select jsonb_agg(jsonb_build_object(
      'category_id', focus.learner_category_id,
      'role', focus.goal_role,
      'weight', focus.goal_weight
    ) order by focus.goal_weight desc, focus.learner_category_id)
    from public.learner_category_focus focus where focus.user_id = caller), '[]'::jsonb),
    nullif(btrim(p_focus_label), '')
  );

  for selected in
    select
      (candidate.value->>'learning_item_id')::uuid learning_item_id,
      (candidate.value->>'source_knowledge_item_id')::uuid source_knowledge_item_id,
      candidate.value->>'pool' pool,
      (candidate.value->>'weight')::double precision weight,
      (candidate.value->>'curriculum')::double precision curriculum,
      (candidate.value->>'retrievability')::double precision retrievability,
      (candidate.value->>'desired_retention')::double precision desired_retention,
      family.display_term term, vocabulary.definition meaning,
      vocabulary.example_sentence, vocabulary.sense_label,
      learning.content_version
    from jsonb_array_elements(selected_items) with ordinality candidate(value, item_order)
    join public.learning_items learning on learning.id = (candidate.value->>'learning_item_id')::uuid
    join public.vocabulary_items vocabulary on vocabulary.learning_item_id = learning.id
    join public.learner_term_families family on family.id = vocabulary.term_family_id
    order by candidate.item_order
  loop
    position_index := position_index + 1;
    select case
      when collection.is_disliked then 'disliked_explicit'
      when collection.is_liked then 'liked'
      else 'neutral'
    end into preference
    from public.user_collections collection
    where collection.user_id = caller and collection.learning_item_id = selected.learning_item_id;
    preference := coalesce(preference, 'neutral');

    if mod(position_index, 2) = 1 then
      select jsonb_agg(value order by option_order) into option_values
      from (
        select value, hashtextextended(attempt_id::text || selected.learning_item_id::text || value, 1) option_order
        from (
          select selected.meaning value
          union
          select distractor.definition
          from public.learning_items other
          join public.vocabulary_items distractor on distractor.learning_item_id = other.id
          where other.user_id = caller
            and other.id <> selected.learning_item_id
            and other.practice_enabled
            and (other.qa_status = 'approved' or other.origin = 'user_created')
            and distractor.definition <> selected.meaning
          order by hashtextextended(attempt_id::text || selected.learning_item_id::text || other.id::text, 2)
          limit 3
        ) option_set
      ) options_ordered;

      insert into public.attempt_answers (
        attempt_id, user_id, knowledge_item_id, learning_item_id, position,
        question_type, assessment_kind, prompt, options, correct_answer,
        selection_pool, selection_score, curriculum_value_at_selection,
        retrievability_at_selection, desired_retention_at_selection,
        preference_snapshot, question_payload
      ) values (
        attempt_id, caller, selected.source_knowledge_item_id, selected.learning_item_id,
        position_index, 'multiple_choice', 'multiple_choice',
        format('Which meaning best matches “%s”?', selected.term), option_values,
        selected.meaning, selected.pool, selected.weight, selected.curriculum,
        selected.retrievability, selected.desired_retention, preference,
        jsonb_build_object('term', selected.term, 'definition', selected.meaning,
          'example_sentence', selected.example_sentence, 'sense_label', selected.sense_label,
          'content_version', selected.content_version)
      );
    else
      make_true := mod((hashtextextended(attempt_id::text || selected.learning_item_id::text, 3) & 9223372036854775807), 2) = 0;
      shown_meaning := selected.meaning;
      if not make_true then
        select distractor.definition into shown_meaning
        from public.learning_items other
        join public.vocabulary_items distractor on distractor.learning_item_id = other.id
        where other.user_id = caller
          and other.id <> selected.learning_item_id
          and other.practice_enabled
          and (other.qa_status = 'approved' or other.origin = 'user_created')
          and distractor.definition <> selected.meaning
        order by hashtextextended(attempt_id::text || selected.learning_item_id::text || other.id::text, 4)
        limit 1;
        if shown_meaning is null then shown_meaning := selected.meaning; make_true := true; end if;
      end if;

      insert into public.attempt_answers (
        attempt_id, user_id, knowledge_item_id, learning_item_id, position,
        question_type, assessment_kind, prompt, options, correct_answer,
        selection_pool, selection_score, curriculum_value_at_selection,
        retrievability_at_selection, desired_retention_at_selection,
        preference_snapshot, question_payload
      ) values (
        attempt_id, caller, selected.source_knowledge_item_id, selected.learning_item_id,
        position_index, 'true_false', 'true_false',
        format('“%s” means “%s”.', selected.term, shown_meaning),
        '["True", "False"]'::jsonb,
        case when make_true then 'True' else 'False' end,
        selected.pool, selected.weight, selected.curriculum,
        selected.retrievability, selected.desired_retention, preference,
        jsonb_build_object('term', selected.term, 'definition', selected.meaning,
          'example_sentence', selected.example_sentence, 'sense_label', selected.sense_label,
          'content_version', selected.content_version)
      );
    end if;
  end loop;

  return jsonb_build_object(
    'attempt_id', attempt_id, 'eligible_count', eligible_count,
    'actual_length', actual_count, 'requested_length', p_requested_length
  );
end;
$$;

revoke all on function private.create_v2_practice_attempt(
  public.practice_source, integer, text[], uuid, uuid[], text
) from public, anon, authenticated;

create or replace function public.create_practice_attempt(
  p_source public.practice_source,
  p_requested_length integer,
  p_category_ids text[] default '{}',
  p_source_attempt_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  return private.create_v2_practice_attempt(
    p_source, p_requested_length, p_category_ids, p_source_attempt_id, '{}', null
  );
end;
$$;

create or replace function public.create_scoped_practice_attempt(
  p_source public.practice_source,
  p_requested_length integer,
  p_category_ids text[] default '{}',
  p_source_attempt_id uuid default null,
  p_item_ids uuid[] default '{}'
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if cardinality(coalesce(p_item_ids, '{}')) = 0 then
    raise exception 'Choose at least one collection term';
  end if;
  return private.create_v2_practice_attempt(
    p_source, p_requested_length, p_category_ids, p_source_attempt_id, p_item_ids, null
  );
end;
$$;

create or replace function public.create_scoped_practice_attempt_with_focus(
  p_source public.practice_source,
  p_requested_length integer,
  p_category_ids text[] default '{}',
  p_source_attempt_id uuid default null,
  p_item_ids uuid[] default '{}',
  p_focus_label text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if cardinality(coalesce(p_item_ids, '{}')) = 0 then
    raise exception 'Choose at least one collection term';
  end if;
  return private.create_v2_practice_attempt(
    p_source, p_requested_length, p_category_ids, p_source_attempt_id, p_item_ids, p_focus_label
  );
end;
$$;

alter function public.submit_practice_answer(uuid, text)
  rename to submit_practice_answer_legacy_v1;
revoke all on function public.submit_practice_answer_legacy_v1(uuid, text)
  from public, anon, authenticated;

create function public.submit_practice_answer(
  p_answer_id uuid,
  p_selected_answer text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller uuid := auth.uid();
  result jsonb;
  content jsonb;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  result := public.submit_practice_answer_legacy_v1(p_answer_id, p_selected_answer);
  select jsonb_build_object(
    'term', family.display_term,
    'meaning', vocabulary.definition,
    'example_sentence', vocabulary.example_sentence
  ) into content
  from public.attempt_answers answer
  join public.learning_items learning on learning.id = answer.learning_item_id
  join public.vocabulary_items vocabulary on vocabulary.learning_item_id = learning.id
  join public.learner_term_families family on family.id = vocabulary.term_family_id
  where answer.id = p_answer_id and answer.user_id = caller;
  return result || coalesce(content, '{}'::jsonb);
end;
$$;

create or replace function public.get_practice_attempt(p_attempt_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  caller uuid := auth.uid();
  result jsonb;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  if not exists (
    select 1 from public.activity_attempts where id = p_attempt_id and user_id = caller
  ) then raise exception 'Attempt not found'; end if;

  select jsonb_build_object(
    'attempt', to_jsonb(attempt),
    'points', jsonb_build_object(
      'answer_points', coalesce((select sum(points) from public.user_point_events where attempt_id = attempt.id and event_type = 'answer'), 0),
      'recovery_points', coalesce((select sum(points) from public.user_point_events where attempt_id = attempt.id and event_type = 'recovery'), 0),
      'completion_points', coalesce((select sum(points) from public.user_point_events where attempt_id = attempt.id and event_type = 'completion'), 0),
      'grade_points', coalesce((select sum(points) from public.user_point_events where attempt_id = attempt.id and event_type = 'grade'), 0),
      'total_points', attempt.points_earned,
      'system_version', attempt.point_system_version
    ),
    'answers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', answer.id, 'attempt_id', answer.attempt_id, 'user_id', answer.user_id,
        'knowledge_item_id', answer.learning_item_id,
        'learning_item_id', answer.learning_item_id,
        'position', answer.position, 'question_type', answer.question_type,
        'prompt', answer.prompt, 'options', answer.options,
        'correct_answer', case when answer.answered_at is not null or attempt.status = 'completed' then answer.correct_answer else null end,
        'selected_answer', answer.selected_answer, 'is_correct', answer.is_correct,
        'answered_at', answer.answered_at, 'term', family.display_term,
        'meaning', vocabulary.definition, 'example_sentence', vocabulary.example_sentence,
        'points_earned', coalesce((select sum(points) from public.user_point_events event
          where event.answer_id = answer.id and event.event_type in ('answer', 'recovery')), 0)
      ) order by answer.position)
      from public.attempt_answers answer
      join public.learning_items learning on learning.id = answer.learning_item_id
      join public.vocabulary_items vocabulary on vocabulary.learning_item_id = learning.id
      join public.learner_term_families family on family.id = vocabulary.term_family_id
      where answer.attempt_id = attempt.id
    ), '[]'::jsonb)
  ) into result
  from public.activity_attempts attempt
  where attempt.id = p_attempt_id and attempt.user_id = caller;
  return result;
end;
$$;

create or replace function public.get_practice_setup_counts()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare caller uuid := auth.uid(); result jsonb;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  with eligible as (
    select learning.id, vocabulary.term_family_id, state.last_answer_correct
    from public.learning_items learning
    join public.vocabulary_items vocabulary on vocabulary.learning_item_id = learning.id
    left join public.user_item_learning_states state
      on state.user_id = caller and state.learning_item_id = learning.id
    where learning.user_id = caller and learning.item_type = 'vocabulary'
      and learning.practice_enabled
      and (learning.qa_status = 'approved' or learning.origin = 'user_created')
      and learning.archived_at is null
  ), unique_eligible as (
    select distinct on (term_family_id) * from eligible order by term_family_id, id
  )
  select jsonb_build_object(
    'recommended', (select count(*) from unique_eligible),
    'word_bank', (select count(*) from unique_eligible eligible where exists (
      select 1 from public.user_collections collection
      where collection.user_id = caller and collection.learning_item_id = eligible.id and collection.state = 'saved'
    )),
    'missed', (select count(*) from unique_eligible where last_answer_correct = false),
    'mixed_library', (select count(*) from unique_eligible),
    'categories', coalesce((
      select jsonb_object_agg(category.id::text, coalesce(tally.total, 0))
      from public.learner_categories category
      left join lateral (
        select count(distinct vocabulary.term_family_id) total
        from public.learning_item_categories mapping
        join public.learning_items learning on learning.id = mapping.learning_item_id
        join public.vocabulary_items vocabulary on vocabulary.learning_item_id = learning.id
        where mapping.learner_category_id = category.id
          and learning.user_id = caller and learning.practice_enabled
          and (learning.qa_status = 'approved' or learning.origin = 'user_created')
      ) tally on true
      where category.user_id = caller
    ), '{}'::jsonb)
  ) into result;
  return result;
end;
$$;

create or replace function public.get_learning_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare caller uuid := auth.uid(); result jsonb;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  with active as (
    select distinct on (vocabulary.term_family_id)
      learning.id, learning.importance, vocabulary.term_family_id,
      state.stability, state.last_review_at, state.next_review_at,
      case when state.user_id is null then 0 else public.fsrs_retrievability(
        state.stability, greatest(0, extract(epoch from (now() - state.last_review_at)) / 86400)
      ) end current_recall,
      case when state.user_id is null then 0 else public.fsrs_retrievability(
        state.stability, greatest(0, extract(epoch from (now() - state.last_review_at)) / 86400) + 30
      ) end durable_recall
    from public.learning_items learning
    join public.vocabulary_items vocabulary on vocabulary.learning_item_id = learning.id
    left join public.user_item_learning_states state
      on state.user_id = caller and state.learning_item_id = learning.id
    where learning.user_id = caller and learning.practice_enabled
      and (learning.qa_status = 'approved' or learning.origin = 'user_created')
      and learning.archived_at is null
    order by vocabulary.term_family_id, learning.importance desc, learning.id
  )
  select jsonb_build_object(
    'overall', jsonb_build_object(
      'coverage', coalesce(100.0 * count(*) filter (where stability is not null) / nullif(count(*), 0), 0),
      'current_recall', coalesce(100.0 * avg(current_recall), 0),
      'durable_mastery', coalesce(100.0 * avg(durable_recall), 0),
      'total_items', count(*),
      'practised_items', count(*) filter (where stability is not null)
    ),
    'goals', coalesce((
      select jsonb_agg(jsonb_build_object(
        'category_id', category.id, 'category_name', category.name,
        'goal_role', focus.goal_role, 'goal_weight', focus.goal_weight,
        'coverage', coalesce(metrics.coverage, 0),
        'current_recall', coalesce(metrics.current_recall, 0),
        'durable_mastery', coalesce(metrics.durable_mastery, 0),
        'total_items', coalesce(metrics.total_items, 0),
        'practised_items', coalesce(metrics.practised_items, 0)
      ) order by focus.goal_weight desc, category.sort_order)
      from public.learner_category_focus focus
      join public.learner_categories category on category.id = focus.learner_category_id
      left join lateral (
        select
          100.0 * count(*) filter (where active.stability is not null) / nullif(count(*), 0) coverage,
          100.0 * sum(mapping.importance * active.current_recall) / nullif(sum(mapping.importance), 0) current_recall,
          100.0 * sum(mapping.importance * active.durable_recall) / nullif(sum(mapping.importance), 0) durable_mastery,
          count(*) total_items,
          count(*) filter (where active.stability is not null) practised_items
        from public.learning_item_categories mapping
        join active on active.id = mapping.learning_item_id
        where mapping.learner_category_id = category.id
      ) metrics on true
      where focus.user_id = caller
    ), '[]'::jsonb),
    'due_count', count(*) filter (where next_review_at <= now()),
    'reviewed_unique', count(*) filter (where stability is not null)
  ) into result from active;
  return result;
end;
$$;

create or replace function public.get_points_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare caller uuid := auth.uid(); result jsonb;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  select jsonb_build_object(
    'lifetime_points', coalesce((select lifetime_points from public.user_point_totals where user_id = caller), 0),
    'week_points', coalesce((select sum(points) from public.user_point_events where user_id = caller and created_at >= date_trunc('week', now())), 0),
    'completed_tests', (select count(*) from public.activity_attempts where user_id = caller and status = 'completed'),
    'average_test_points', coalesce((select round(avg(points_earned)) from public.activity_attempts where user_id = caller and status = 'completed'), 0),
    'goals', coalesce((
      select jsonb_agg(jsonb_build_object(
        'category_id', category.id, 'category_name', category.name,
        'goal_role', focus.goal_role, 'points', coalesce(goal_points.points, 0)
      ) order by focus.goal_weight desc, category.sort_order)
      from public.learner_category_focus focus
      join public.learner_categories category on category.id = focus.learner_category_id
      left join (
        select learner_category_id, sum(event.points)::bigint points
        from public.learner_point_event_categories mapping
        join public.user_point_events event on event.id = mapping.event_id
        where mapping.user_id = caller group by learner_category_id
      ) goal_points on goal_points.learner_category_id = category.id
      where focus.user_id = caller
    ), '[]'::jsonb)
  ) into result;
  return result;
end;
$$;

revoke all on function public.create_practice_attempt(public.practice_source, integer, text[], uuid) from public, anon;
revoke all on function public.create_scoped_practice_attempt(public.practice_source, integer, text[], uuid, uuid[]) from public, anon;
revoke all on function public.create_scoped_practice_attempt_with_focus(public.practice_source, integer, text[], uuid, uuid[], text) from public, anon;
revoke all on function public.submit_practice_answer(uuid, text) from public, anon;
revoke all on function public.get_practice_attempt(uuid) from public, anon;
revoke all on function public.get_practice_setup_counts() from public, anon;
revoke all on function public.get_learning_dashboard() from public, anon;
revoke all on function public.get_points_summary() from public, anon;

grant execute on function public.create_practice_attempt(public.practice_source, integer, text[], uuid) to authenticated;
grant execute on function public.create_scoped_practice_attempt(public.practice_source, integer, text[], uuid, uuid[]) to authenticated;
grant execute on function public.create_scoped_practice_attempt_with_focus(public.practice_source, integer, text[], uuid, uuid[], text) to authenticated;
grant execute on function public.submit_practice_answer(uuid, text) to authenticated;
grant execute on function public.get_practice_attempt(uuid) to authenticated;
grant execute on function public.get_practice_setup_counts() to authenticated;
grant execute on function public.get_learning_dashboard() to authenticated;
grant execute on function public.get_points_summary() to authenticated;
