alter table public.user_collections
  add column if not exists is_liked boolean not null default false;

alter table public.user_collections
  add constraint user_collections_liked_requires_saved
  check (not is_liked or state = 'saved');

create index user_collections_liked_idx
  on public.user_collections (user_id, knowledge_item_id)
  where is_liked and state = 'saved';

comment on column public.user_collections.is_liked is
  'Marks a saved Knowledge Item as a user favourite without duplicating its collection row.';

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
declare
  caller uuid := auth.uid();
  attempt_id uuid := gen_random_uuid();
  eligible_count integer;
  actual_count integer;
  selected_items jsonb := '[]'::jsonb;
  position_index integer := 0;
  selected record;
  option_values jsonb;
  shown_meaning text;
  make_true boolean;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  if cardinality(coalesce(p_item_ids, '{}')) = 0 then raise exception 'Choose at least one collection word'; end if;
  if p_requested_length not between 10 and 200 then raise exception 'Question count must be between 10 and 200'; end if;
  if p_source = 'category' and cardinality(coalesce(p_category_ids, '{}')) <> 1 then
    raise exception 'Choose one category';
  end if;
  if p_source = 'attempt_misses' and not exists (
    select 1 from public.activity_attempts attempt
    where attempt.id = p_source_attempt_id and attempt.user_id = caller
  ) then raise exception 'The source attempt was not found'; end if;

  with visible as (
    select item.id, item.owner_id,
      coalesce(state.repetitions, 0) repetitions,
      coalesce(state.lapses, 0) lapses,
      state.stability,
      state.last_rating,
      state.last_review_at,
      state.last_answer_correct,
      private.item_curriculum_value(caller, item.id)::double precision curriculum,
      exists (
        select 1 from public.user_category_goals goal
        join public.knowledge_item_categories mapping
          on mapping.category_id = goal.category_id and mapping.knowledge_item_id = item.id
        where goal.user_id = caller
      ) is_target,
      case when state.user_id is null then 0::double precision else public.fsrs_retrievability(
        state.stability,
        greatest(0, extract(epoch from (now() - state.last_review_at)) / 86400)
      )::double precision end retrievability
    from public.knowledge_items item
    left join public.user_item_learning_states state
      on state.user_id = caller and state.knowledge_item_id = item.id
    where (item.source = 'seeded' or item.owner_id = caller)
      and not exists (
        select 1 from public.user_collections hidden
        where hidden.user_id = caller and hidden.knowledge_item_id = item.id and hidden.state = 'hidden'
      )
      and item.id = any(p_item_ids)
      and (
        p_source = 'recommended'
        or (p_source = 'word_bank' and exists (
          select 1 from public.user_collections saved
          where saved.user_id = caller and saved.knowledge_item_id = item.id and saved.state = 'saved'
        ))
        or (p_source = 'mixed_library' and item.source = 'seeded')
        or (p_source = 'category' and exists (
          select 1 from public.knowledge_item_categories mapping
          where mapping.knowledge_item_id = item.id and mapping.category_id = any(p_category_ids)
        ))
        or (p_source = 'missed' and state.last_answer_correct = false)
        or (p_source = 'attempt_misses' and exists (
          select 1 from public.attempt_answers answer
          where answer.attempt_id = p_source_attempt_id
            and answer.user_id = caller
            and answer.knowledge_item_id = item.id
            and answer.is_correct = false
        ))
      )
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
    from visible
  ), weighted as materialized (
    select id,
      case
        when p_source <> 'recommended' then 'manual'
        when is_target and repetitions = 0 then 'target_new'
        when is_target and retrievability <= desired_retention then 'target_due'
        when is_target and (stability < 30 or last_rating = 1) then 'target_weak'
        when not is_target and repetitions > 0 and retrievability <= desired_retention then 'outside_due'
        else 'maintenance'
      end pool,
      case when p_source <> 'recommended' then 1::double precision else
        (0.02::double precision + power(curriculum, 1.5::double precision) *
          (0.55::double precision * urgency + 0.25::double precision * learning_gap + 0.10::double precision * lapse_factor + 0.10::double precision * uncertainty)) *
        recency_multiplier
      end weight,
      curriculum,
      retrievability,
      desired_retention,
      -ln(((hashtextextended(attempt_id::text || id::text, 0) & 9223372036854775807)::double precision + 1::double precision)
        / 9223372036854775808::double precision) / greatest(
          case when p_source <> 'recommended' then 1::double precision else
            (0.02::double precision + power(curriculum, 1.5::double precision) *
              (0.55::double precision * urgency + 0.25::double precision * learning_gap + 0.10::double precision * lapse_factor + 0.10::double precision * uncertainty)) *
            recency_multiplier
          end,
          0.000001::double precision
        ) sample_key
    from scored
  ), session as (
    select count(*)::integer eligible_count,
      least(p_requested_length, count(*)::integer) actual_count
    from weighted
  ), ranked as (
    select candidate.*, session.eligible_count, session.actual_count,
      row_number() over (partition by candidate.pool order by candidate.sample_key) pool_rank
    from weighted candidate
    cross join session
  ), chosen as (
    select *
    from ranked
    order by
      case
        when p_source = 'recommended' and ranked.pool_rank <= case ranked.pool
          when 'target_due' then ceil(ranked.actual_count * 0.45)
          when 'target_weak' then ceil(ranked.actual_count * 0.20)
          when 'target_new' then ceil(ranked.actual_count * 0.15)
          when 'outside_due' then ceil(ranked.actual_count * 0.10)
          else ceil(ranked.actual_count * 0.10)
        end then 0
        else 1
      end,
      ranked.sample_key
    limit p_requested_length
  )
  select
    coalesce(max(chosen.eligible_count), 0)::integer,
    coalesce(max(chosen.actual_count), 0)::integer,
    coalesce(jsonb_agg(jsonb_build_object(
      'item_id', chosen.id,
      'pool', chosen.pool,
      'weight', chosen.weight,
      'curriculum', chosen.curriculum,
      'retrievability', chosen.retrievability,
      'desired_retention', chosen.desired_retention
    ) order by chosen.sample_key), '[]'::jsonb)
  into eligible_count, actual_count, selected_items
  from chosen;

  if eligible_count = 0 then raise exception 'There are no eligible words in this source yet'; end if;

  insert into public.activity_attempts (
    id, user_id, source, category_id, source_attempt_id, requested_length,
    actual_length, selection_version, goal_snapshot
  ) values (
    attempt_id, caller, p_source,
    case when p_source = 'category' and cardinality(p_category_ids) = 1 then p_category_ids[1] else null end,
    case when p_source = 'attempt_misses' then p_source_attempt_id else null end,
    p_requested_length, actual_count,
    case when p_source = 'recommended' then 'goal-weighted-fsrs-v1' else 'uniform-v2' end,
    coalesce((select jsonb_agg(jsonb_build_object(
      'category_id', goal.category_id, 'role', goal.goal_role, 'weight', goal.goal_weight
    ) order by goal.goal_weight desc, goal.category_id)
    from public.user_category_goals goal where goal.user_id = caller), '[]'::jsonb)
  );

  if p_source = 'recommended' then
    insert into public.activity_attempt_categories (attempt_id, user_id, category_id, goal_role, goal_weight)
    select attempt_id, caller, category_id, goal_role, goal_weight
    from public.user_category_goals where user_id = caller;
  elsif p_source = 'category' then
    insert into public.activity_attempt_categories (attempt_id, user_id, category_id)
    select attempt_id, caller, distinct_category
    from (select distinct unnest(p_category_ids) distinct_category) chosen;
  end if;

  for selected in
    select
      (candidate.value->>'item_id')::uuid item_id,
      candidate.value->>'pool' pool,
      (candidate.value->>'weight')::double precision weight,
      (candidate.value->>'curriculum')::double precision curriculum,
      (candidate.value->>'retrievability')::double precision retrievability,
      (candidate.value->>'desired_retention')::double precision desired_retention,
      item.term,
      item.meaning
    from jsonb_array_elements(selected_items) with ordinality candidate(value, item_order)
    join public.knowledge_items item on item.id = (candidate.value->>'item_id')::uuid
    order by candidate.item_order
  loop
    position_index := position_index + 1;
    if mod(position_index, 2) = 1 then
      select jsonb_agg(value order by option_order) into option_values
      from (
        select value,
          hashtextextended(attempt_id::text || selected.item_id::text || value, 1) option_order
        from (
          select selected.meaning value
          union
          select chosen.meaning
          from (
            select distractor.meaning
            from public.knowledge_items distractor
            where distractor.id <> selected.item_id
              and distractor.meaning <> selected.meaning
              and (distractor.source = 'seeded' or distractor.owner_id = caller)
              and not exists (
                select 1 from public.user_collections hidden
                where hidden.user_id = caller and hidden.knowledge_item_id = distractor.id and hidden.state = 'hidden'
              )
            order by exists (
              select 1
              from public.knowledge_item_categories target_category
              join public.knowledge_item_categories distractor_category
                on distractor_category.category_id = target_category.category_id
               and distractor_category.knowledge_item_id = distractor.id
              where target_category.knowledge_item_id = selected.item_id
            ) desc,
            hashtextextended(attempt_id::text || selected.item_id::text || distractor.id::text, 2)
            limit 3
          ) chosen
        ) valueset
      ) ordered_options;

      insert into public.attempt_answers (
        attempt_id, user_id, knowledge_item_id, position, question_type,
        prompt, options, correct_answer, selection_pool, selection_score,
        curriculum_value_at_selection, retrievability_at_selection, desired_retention_at_selection
      ) values (
        attempt_id, caller, selected.item_id, position_index, 'multiple_choice',
        format('Which meaning best matches “%s”?', selected.term), option_values,
        selected.meaning, selected.pool, selected.weight, selected.curriculum,
        selected.retrievability, selected.desired_retention
      );
    else
      make_true := mod((hashtextextended(attempt_id::text || selected.item_id::text, 3) & 9223372036854775807), 2) = 0;
      shown_meaning := selected.meaning;
      if not make_true then
        select distractor.meaning into shown_meaning
        from public.knowledge_items distractor
        where distractor.id <> selected.item_id and distractor.meaning <> selected.meaning
          and (distractor.source = 'seeded' or distractor.owner_id = caller)
        order by exists (
          select 1 from public.knowledge_item_categories first_mapping
          join public.knowledge_item_categories second_mapping
            on second_mapping.category_id = first_mapping.category_id
           and second_mapping.knowledge_item_id = distractor.id
          where first_mapping.knowledge_item_id = selected.item_id
        ) desc,
        hashtextextended(attempt_id::text || selected.item_id::text || distractor.id::text, 4)
        limit 1;
        if shown_meaning is null then shown_meaning := selected.meaning; make_true := true; end if;
      end if;

      insert into public.attempt_answers (
        attempt_id, user_id, knowledge_item_id, position, question_type,
        prompt, options, correct_answer, selection_pool, selection_score,
        curriculum_value_at_selection, retrievability_at_selection, desired_retention_at_selection
      ) values (
        attempt_id, caller, selected.item_id, position_index, 'true_false',
        format('“%s” means “%s”', selected.term, shown_meaning), '["True","False"]'::jsonb,
        case when make_true then 'True' else 'False' end,
        selected.pool, selected.weight, selected.curriculum,
        selected.retrievability, selected.desired_retention
      );
    end if;
  end loop;

  return jsonb_build_object(
    'attempt_id', attempt_id,
    'eligible_count', eligible_count,
    'actual_length', actual_count,
    'requested_length', p_requested_length
  );
end;
$$;

revoke all on function public.create_scoped_practice_attempt(
  public.practice_source, integer, text[], uuid, uuid[]
) from public, anon;

grant execute on function public.create_scoped_practice_attempt(
  public.practice_source, integer, text[], uuid, uuid[]
) to authenticated, service_role;

comment on function public.create_scoped_practice_attempt(
  public.practice_source, integer, text[], uuid, uuid[]
) is 'Creates a practice attempt narrowed to an authenticated user-owned eligible Knowledge Item set.';
