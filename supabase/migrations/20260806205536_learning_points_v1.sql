create type public.point_event_type as enum (
  'answer',
  'recovery',
  'completion',
  'grade'
);

create table private.point_system_configs (
  version text primary key,
  active boolean not null default false,
  base_points numeric(8, 3) not null check (base_points > 0),
  multiple_choice_factor numeric(6, 3) not null check (multiple_choice_factor > 0),
  true_false_factor numeric(6, 3) not null check (true_false_factor > 0),
  beginner_factor numeric(6, 3) not null check (beginner_factor > 0),
  intermediate_factor numeric(6, 3) not null check (intermediate_factor > 0),
  advanced_factor numeric(6, 3) not null check (advanced_factor > 0),
  new_factor numeric(6, 3) not null check (new_factor > 0),
  learning_factor numeric(6, 3) not null check (learning_factor > 0),
  needs_practice_factor numeric(6, 3) not null check (needs_practice_factor > 0),
  mastered_factor numeric(6, 3) not null check (mastered_factor > 0),
  goal_floor numeric(6, 3) not null check (goal_floor > 0),
  goal_scale numeric(6, 3) not null check (goal_scale >= 0),
  preference_factor numeric(6, 3) not null check (preference_factor >= 1),
  spacing_floor numeric(6, 3) not null check (spacing_floor between 0 and 1),
  recovery_spacing_floor numeric(6, 3) not null check (recovery_spacing_floor between 0 and 1),
  recovery_base numeric(6, 3) not null check (recovery_base >= 0),
  completion_scale numeric(6, 3) not null check (completion_scale >= 0),
  grade_a_factor numeric(6, 3) not null check (grade_a_factor >= 0),
  grade_b_factor numeric(6, 3) not null check (grade_b_factor >= 0),
  grade_c_factor numeric(6, 3) not null check (grade_c_factor >= 0),
  grade_d_factor numeric(6, 3) not null check (grade_d_factor >= 0),
  grade_e_factor numeric(6, 3) not null check (grade_e_factor >= 0),
  created_at timestamptz not null default now()
);

create unique index point_system_one_active_idx
  on private.point_system_configs (active)
  where active;

insert into private.point_system_configs (
  version, active, base_points,
  multiple_choice_factor, true_false_factor,
  beginner_factor, intermediate_factor, advanced_factor,
  new_factor, learning_factor, needs_practice_factor, mastered_factor,
  goal_floor, goal_scale, preference_factor,
  spacing_floor, recovery_spacing_floor, recovery_base,
  completion_scale,
  grade_a_factor, grade_b_factor, grade_c_factor, grade_d_factor, grade_e_factor
) values (
  'learning-points-v1', true, 20.000,
  1.000, 0.800,
  0.900, 1.000, 1.200,
  1.050, 1.000, 1.100, 0.750,
  0.900, 0.250, 1.040,
  0.100, 0.350, 3.000,
  4.000,
  0.150, 0.100, 0.050, 0.020, 0.000
);

alter table public.activity_attempts
  add column points_earned integer not null default 0 check (points_earned >= 0),
  add column point_system_version text references private.point_system_configs (version);

update public.activity_attempts
set point_system_version = 'learning-points-v1'
where point_system_version is null;

alter table public.activity_attempts
  alter column point_system_version set not null;

alter table public.attempt_answers
  add column preference_snapshot text not null default 'neutral'
    check (preference_snapshot in ('neutral', 'liked', 'disliked_explicit'));

create table public.user_point_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  attempt_id uuid not null,
  answer_id uuid references public.attempt_answers (id) on delete cascade,
  knowledge_item_id uuid references public.knowledge_items (id) on delete cascade,
  event_type public.point_event_type not null,
  points integer not null check (points >= 0),
  system_version text not null references private.point_system_configs (version),
  question_type public.question_type,
  content_difficulty public.knowledge_difficulty,
  status_before text check (status_before is null or status_before in ('New', 'Learning', 'Confident', 'Needs practice')),
  retrievability_before numeric(10, 8) check (retrievability_before is null or retrievability_before between 0 and 1),
  fsrs_difficulty_before numeric(11, 8) check (fsrs_difficulty_before is null or fsrs_difficulty_before between 1 and 10),
  curriculum_value numeric(10, 8) check (curriculum_value is null or curriculum_value between 0 and 1),
  preference_snapshot text check (preference_snapshot is null or preference_snapshot in ('neutral', 'liked', 'disliked_explicit')),
  spacing_credit numeric(8, 6) check (spacing_credit is null or spacing_credit between 0 and 1),
  factor_snapshot jsonb not null default '{}'::jsonb,
  calculation_mode text not null default 'live',
  created_at timestamptz not null default now(),
  unique (id, user_id),
  foreign key (attempt_id, user_id)
    references public.activity_attempts (id, user_id) on delete cascade
);

create unique index user_point_events_answer_type_idx
  on public.user_point_events (answer_id, event_type)
  where answer_id is not null;

create unique index user_point_events_attempt_bonus_idx
  on public.user_point_events (attempt_id, event_type)
  where answer_id is null;

create index user_point_events_user_recent_idx
  on public.user_point_events (user_id, created_at desc, id desc);

create index user_point_events_attempt_idx
  on public.user_point_events (user_id, attempt_id, event_type);

create table public.user_point_event_categories (
  event_id bigint not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  category_id text not null references public.categories (id) on delete restrict,
  goal_role public.category_goal_role not null,
  goal_weight numeric(4, 3) not null check (goal_weight between 0 and 1),
  importance numeric(4, 3) not null check (importance between 0 and 1),
  created_at timestamptz not null default now(),
  primary key (event_id, category_id),
  foreign key (event_id, user_id)
    references public.user_point_events (id, user_id) on delete cascade
);

create index user_point_event_categories_user_goal_idx
  on public.user_point_event_categories (user_id, category_id, event_id);

create table public.user_point_totals (
  user_id uuid primary key references auth.users (id) on delete cascade,
  lifetime_points bigint not null default 0 check (lifetime_points >= 0),
  state_version integer not null default 1 check (state_version > 0),
  updated_at timestamptz not null default now()
);

create or replace function private.snapshot_attempt_point_system()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if new.point_system_version is null then
    select config.version into new.point_system_version
    from private.point_system_configs config
    where config.active;
  end if;
  if new.point_system_version is null then
    raise exception 'No active point system is configured';
  end if;
  return new;
end;
$$;

create trigger activity_attempt_point_system_snapshot
before insert on public.activity_attempts
for each row execute function private.snapshot_attempt_point_system();

create or replace function private.snapshot_answer_preference()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  collection public.user_collections;
begin
  select * into collection
  from public.user_collections
  where user_id = new.user_id
    and knowledge_item_id = new.knowledge_item_id;

  new.preference_snapshot := case
    when coalesce(collection.is_liked, false) then 'liked'
    else 'neutral'
  end;
  return new;
end;
$$;

create trigger attempt_answer_preference_snapshot
before insert on public.attempt_answers
for each row execute function private.snapshot_answer_preference();

create or replace function private.calculate_learning_points(
  p_system_version text,
  p_question_type public.question_type,
  p_content_difficulty public.knowledge_difficulty,
  p_status_before text,
  p_retrievability numeric,
  p_fsrs_difficulty numeric,
  p_curriculum numeric,
  p_preference text,
  p_spacing_factor numeric,
  p_previous_wrong boolean,
  p_is_correct boolean,
  p_user_created boolean default false
)
returns table (
  answer_points integer,
  recovery_points integer,
  question_factor numeric,
  content_factor numeric,
  memory_factor numeric,
  status_factor numeric,
  goal_factor numeric,
  preference_factor numeric,
  spacing_factor numeric,
  breakdown jsonb
)
language plpgsql
stable
security invoker
set search_path = pg_catalog, public, private
as $$
declare
  config private.point_system_configs;
  raw_points numeric;
begin
  select * into config
  from private.point_system_configs
  where version = p_system_version;
  if config.version is null then raise exception 'Point system configuration not found'; end if;

  question_factor := case p_question_type
    when 'multiple_choice' then config.multiple_choice_factor
    else config.true_false_factor
  end;
  content_factor := case
    when p_user_created then 1.000
    when p_content_difficulty = 'beginner' then config.beginner_factor
    when p_content_difficulty = 'advanced' then config.advanced_factor
    else config.intermediate_factor
  end;
  memory_factor := case when p_status_before = 'New' then 1.000 else
    least(1.250, greatest(0.850,
      1.200 - 0.350 * coalesce(p_retrievability, 0)
      + 0.050 * ((coalesce(p_fsrs_difficulty, 5) - 5) / 5)
    ))
  end;
  status_factor := case p_status_before
    when 'New' then config.new_factor
    when 'Needs practice' then config.needs_practice_factor
    when 'Confident' then config.mastered_factor
    else config.learning_factor
  end;
  goal_factor := config.goal_floor + config.goal_scale * least(1, greatest(0, coalesce(p_curriculum, 0)));
  preference_factor := case when p_preference in ('liked', 'disliked_explicit')
    then config.preference_factor else 1.000 end;
  spacing_factor := least(1, greatest(config.spacing_floor, coalesce(p_spacing_factor, 1)));

  if not p_is_correct then
    answer_points := 0;
    recovery_points := 0;
  else
    raw_points := config.base_points * question_factor * content_factor * memory_factor
      * status_factor * goal_factor * preference_factor * spacing_factor;
    answer_points := greatest(0, round(raw_points)::integer);
    recovery_points := case when p_previous_wrong
      then greatest(0, round(config.recovery_base * content_factor * goal_factor)::integer)
      else 0 end;
  end if;

  breakdown := jsonb_build_object(
    'base_points', config.base_points,
    'question_factor', question_factor,
    'content_factor', content_factor,
    'memory_factor', memory_factor,
    'status_factor', status_factor,
    'goal_factor', goal_factor,
    'preference_factor', preference_factor,
    'spacing_factor', spacing_factor,
    'status_before', p_status_before,
    'preference', p_preference,
    'answer_points', answer_points,
    'recovery_points', recovery_points
  );
  return next;
end;
$$;

create or replace function private.snapshot_point_event_categories(
  p_event_id bigint,
  p_user_id uuid,
  p_knowledge_item_id uuid
)
returns void
language sql
security invoker
set search_path = pg_catalog, public
as $$
  insert into public.user_point_event_categories (
    event_id, user_id, category_id, goal_role, goal_weight, importance
  )
  select p_event_id, p_user_id, goal.category_id, goal.goal_role, goal.goal_weight, mapping.importance
  from public.user_category_goals goal
  join public.knowledge_item_categories mapping
    on mapping.category_id = goal.category_id
   and mapping.knowledge_item_id = p_knowledge_item_id
  where goal.user_id = p_user_id
  on conflict (event_id, category_id) do nothing;
$$;

create or replace function private.award_attempt_point_bonuses(
  p_attempt_id uuid,
  p_calculation_mode text default 'live'
)
returns table (completion_points integer, grade_points integer)
language plpgsql
security invoker
set search_path = pg_catalog, public, private
as $$
declare
  attempt_record public.activity_attempts;
  config private.point_system_configs;
  subtotal integer;
  accuracy numeric;
  grade_factor numeric;
  inserted_points integer;
begin
  completion_points := 0;
  grade_points := 0;

  select * into attempt_record from public.activity_attempts attempt_source where attempt_source.id = p_attempt_id;
  if attempt_record.id is null or attempt_record.status <> 'completed' then return next; return; end if;
  select * into config from private.point_system_configs where version = attempt_record.point_system_version;

  select coalesce(sum(event.points), 0)::integer into subtotal
  from public.user_point_events event
  where event.attempt_id = attempt_record.id
    and event.event_type in ('answer', 'recovery');

  accuracy := case when attempt_record.actual_length = 0 then 0
    else attempt_record.score::numeric / attempt_record.actual_length end;
  completion_points := round(
    config.completion_scale * sqrt(attempt_record.actual_length::numeric) * (0.25 + 0.75 * accuracy)
  )::integer;
  grade_factor := case
    when accuracy >= 0.80 then config.grade_a_factor
    when accuracy >= 0.70 then config.grade_b_factor
    when accuracy >= 0.60 then config.grade_c_factor
    when accuracy >= 0.50 then config.grade_d_factor
    else config.grade_e_factor
  end;
  grade_points := round(subtotal * grade_factor)::integer;

  insert into public.user_point_events (
    user_id, attempt_id, event_type, points, system_version,
    factor_snapshot, calculation_mode, created_at
  ) values (
    attempt_record.user_id, attempt_record.id, 'completion', completion_points, attempt_record.point_system_version,
    jsonb_build_object(
      'question_count', attempt_record.actual_length,
      'accuracy', accuracy,
      'completion_scale', config.completion_scale,
      'points', completion_points
    ),
    p_calculation_mode, coalesce(attempt_record.completed_at, now())
  )
  on conflict (attempt_id, event_type) where answer_id is null do nothing
  returning points into inserted_points;
  if inserted_points is null then completion_points := 0; end if;

  inserted_points := null;
  insert into public.user_point_events (
    user_id, attempt_id, event_type, points, system_version,
    factor_snapshot, calculation_mode, created_at
  ) values (
    attempt_record.user_id, attempt_record.id, 'grade', grade_points, attempt_record.point_system_version,
    jsonb_build_object(
      'accuracy', accuracy,
      'answer_subtotal', subtotal,
      'grade_factor', grade_factor,
      'points', grade_points
    ),
    p_calculation_mode, coalesce(attempt_record.completed_at, now())
  )
  on conflict (attempt_id, event_type) where answer_id is null do nothing
  returning points into inserted_points;
  if inserted_points is null then grade_points := 0; end if;

  return next;
end;
$$;

create or replace function public.submit_practice_answer(
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
  answer_row public.attempt_answers;
  attempt_row public.activity_attempts;
  item_row public.knowledge_items;
  state_row public.user_item_learning_states;
  correct boolean;
  rating smallint;
  curriculum numeric;
  retention_target numeric;
  elapsed numeric;
  recall_before numeric;
  new_state record;
  scheduled_days numeric;
  due_at timestamptz;
  attempt_is_completed boolean := false;
  confidence text;
  status_before text;
  spacing_credit numeric := 1;
  previous_wrong boolean := false;
  previous_interval_seconds numeric;
  elapsed_seconds numeric;
  point_result record;
  answer_event_id bigint;
  recovery_event_id bigint;
  answer_points integer := 0;
  recovery_points integer := 0;
  completion_points integer := 0;
  grade_points integer := 0;
  bonus_result record;
  new_points integer := 0;
  attempt_points integer := 0;
  lifetime_points bigint := 0;
  point_breakdown jsonb := '{}'::jsonb;
  reviewed_at timestamptz := now();
begin
  if caller is null then raise exception 'Authentication required'; end if;
  if p_selected_answer is null or char_length(trim(p_selected_answer)) = 0 then raise exception 'Choose an answer'; end if;

  select * into answer_row from public.attempt_answers
  where id = p_answer_id for update;
  if answer_row.id is null or answer_row.user_id <> caller then raise exception 'Question not found'; end if;
  select * into attempt_row from public.activity_attempts where id = answer_row.attempt_id;
  if attempt_row.status <> 'in_progress' and answer_row.answered_at is null then
    raise exception 'This practice attempt is no longer active';
  end if;
  select * into item_row from public.knowledge_items where id = answer_row.knowledge_item_id;

  if answer_row.answered_at is not null then
    select coalesce(sum(event.points) filter (where event.event_type = 'answer'), 0)::integer,
      coalesce(sum(event.points) filter (where event.event_type = 'recovery'), 0)::integer
    into answer_points, recovery_points
    from public.user_point_events event where event.answer_id = answer_row.id;
    select event.factor_snapshot into point_breakdown
    from public.user_point_events event
    where event.answer_id = answer_row.id and event.event_type = 'answer'
    limit 1;
    select coalesce(total.lifetime_points, 0) into lifetime_points
    from public.user_point_totals total where total.user_id = caller;
    select coalesce(sum(event.points) filter (where event.event_type = 'completion'), 0)::integer,
      coalesce(sum(event.points) filter (where event.event_type = 'grade'), 0)::integer
    into completion_points, grade_points
    from public.user_point_events event where event.attempt_id = answer_row.attempt_id;
    return jsonb_build_object(
      'is_correct', answer_row.is_correct,
      'correct_answer', answer_row.correct_answer,
      'term', item_row.term,
      'meaning', item_row.meaning,
      'example_sentence', item_row.example_sentence,
      'attempt_completed', attempt_row.status = 'completed',
      'confidence_status', private.item_confidence_label(caller, answer_row.knowledge_item_id),
      'points_earned', answer_points + recovery_points,
      'answer_points', answer_points,
      'recovery_points', recovery_points,
      'completion_points', completion_points,
      'grade_points', grade_points,
      'attempt_points', attempt_row.points_earned,
      'lifetime_points', lifetime_points,
      'points_breakdown', coalesce(point_breakdown, '{}'::jsonb)
    );
  end if;

  correct := p_selected_answer = answer_row.correct_answer;
  rating := case when not correct then 1 when answer_row.question_type = 'true_false' then 2 else 3 end;
  status_before := private.item_confidence_label(caller, answer_row.knowledge_item_id, reviewed_at);
  curriculum := private.item_curriculum_value(caller, answer_row.knowledge_item_id);
  retention_target := 0.86 + 0.08 * curriculum;

  select * into state_row from public.user_item_learning_states
  where user_id = caller and knowledge_item_id = answer_row.knowledge_item_id
  for update;

  elapsed := case when state_row.user_id is null then 0
    else greatest(0, floor(extract(epoch from (reviewed_at - state_row.last_review_at)) / 86400)) end;
  recall_before := case when state_row.user_id is null then 0
    else public.fsrs_retrievability(state_row.stability, elapsed) end;
  previous_wrong := state_row.user_id is not null and not state_row.last_answer_correct;

  if state_row.user_id is not null and reviewed_at < state_row.next_review_at then
    previous_interval_seconds := greatest(1, extract(epoch from (state_row.next_review_at - state_row.last_review_at)));
    elapsed_seconds := greatest(0, extract(epoch from (reviewed_at - state_row.last_review_at)));
    spacing_credit := 0.10 + 0.90 * power(least(1, elapsed_seconds / previous_interval_seconds), 2);
    if previous_wrong then spacing_credit := greatest(0.35, spacing_credit); end if;
  end if;

  select * into point_result from private.calculate_learning_points(
    attempt_row.point_system_version,
    answer_row.question_type,
    item_row.difficulty,
    status_before,
    recall_before,
    state_row.difficulty,
    curriculum,
    answer_row.preference_snapshot,
    spacing_credit,
    previous_wrong,
    correct,
    item_row.source = 'user_added'
  );
  answer_points := point_result.answer_points;
  recovery_points := point_result.recovery_points;
  point_breakdown := point_result.breakdown;

  select * into new_state from private.fsrs_next_state(
    state_row.stability, state_row.difficulty, elapsed, rating
  );
  scheduled_days := case when rating = 1 then 10.0 / 1440
    else private.fsrs_interval_days(new_state.stability, retention_target) end;
  due_at := reviewed_at + scheduled_days * interval '1 day';

  update public.attempt_answers
  set selected_answer = p_selected_answer,
      is_correct = correct,
      answered_at = reviewed_at
  where id = answer_row.id;

  insert into public.user_item_review_events (
    answer_id, user_id, knowledge_item_id, question_type, rating, is_correct,
    reviewed_at, elapsed_days, retrievability_before, stability_before, stability_after,
    difficulty_before, difficulty_after, curriculum_value, desired_retention,
    scheduled_days, algorithm_version
  ) values (
    answer_row.id, caller, answer_row.knowledge_item_id, answer_row.question_type,
    rating, correct, reviewed_at, elapsed, recall_before, state_row.stability, new_state.stability,
    state_row.difficulty, new_state.difficulty, curriculum, retention_target,
    scheduled_days, 'ts-fsrs-5.4.1/fsrs-6.0'
  );

  insert into public.user_item_learning_states (
    user_id, knowledge_item_id, stability, difficulty, repetitions, lapses,
    last_rating, last_question_type, last_answer_correct, last_review_at,
    next_review_at, algorithm_version, state_version
  ) values (
    caller, answer_row.knowledge_item_id, new_state.stability, new_state.difficulty,
    coalesce(state_row.repetitions, 0) + 1,
    coalesce(state_row.lapses, 0) + case when rating = 1 then 1 else 0 end,
    rating, answer_row.question_type, correct, reviewed_at, due_at,
    'ts-fsrs-5.4.1/fsrs-6.0', coalesce(state_row.state_version, 0) + 1
  ) on conflict (user_id, knowledge_item_id) do update set
    stability = excluded.stability,
    difficulty = excluded.difficulty,
    repetitions = excluded.repetitions,
    lapses = excluded.lapses,
    last_rating = excluded.last_rating,
    last_question_type = excluded.last_question_type,
    last_answer_correct = excluded.last_answer_correct,
    last_review_at = excluded.last_review_at,
    next_review_at = excluded.next_review_at,
    algorithm_version = excluded.algorithm_version,
    state_version = excluded.state_version,
    updated_at = reviewed_at;

  insert into public.user_point_events (
    user_id, attempt_id, answer_id, knowledge_item_id, event_type, points,
    system_version, question_type, content_difficulty, status_before,
    retrievability_before, fsrs_difficulty_before, curriculum_value,
    preference_snapshot, spacing_credit, factor_snapshot, created_at
  ) values (
    caller, answer_row.attempt_id, answer_row.id, answer_row.knowledge_item_id,
    'answer', answer_points, attempt_row.point_system_version, answer_row.question_type,
    item_row.difficulty, status_before, recall_before, state_row.difficulty, curriculum,
    answer_row.preference_snapshot, spacing_credit, point_breakdown, reviewed_at
  ) returning id into answer_event_id;
  perform private.snapshot_point_event_categories(answer_event_id, caller, answer_row.knowledge_item_id);

  if recovery_points > 0 then
    insert into public.user_point_events (
      user_id, attempt_id, answer_id, knowledge_item_id, event_type, points,
      system_version, question_type, content_difficulty, status_before,
      retrievability_before, fsrs_difficulty_before, curriculum_value,
      preference_snapshot, spacing_credit, factor_snapshot, created_at
    ) values (
      caller, answer_row.attempt_id, answer_row.id, answer_row.knowledge_item_id,
      'recovery', recovery_points, attempt_row.point_system_version, answer_row.question_type,
      item_row.difficulty, status_before, recall_before, state_row.difficulty, curriculum,
      answer_row.preference_snapshot, spacing_credit,
      jsonb_build_object('previous_review_incorrect', true, 'points', recovery_points), reviewed_at
    ) returning id into recovery_event_id;
    perform private.snapshot_point_event_categories(recovery_event_id, caller, answer_row.knowledge_item_id);
  end if;

  if not exists (
    select 1 from public.attempt_answers pending
    where pending.attempt_id = answer_row.attempt_id and pending.answered_at is null
  ) then
    update public.activity_attempts attempt
    set status = 'completed',
        completed_at = reviewed_at,
        duration_seconds = greatest(0, extract(epoch from (reviewed_at - attempt.started_at))::integer),
        actual_length = (select count(*) from public.attempt_answers where attempt_id = attempt.id),
        score = (select count(*) from public.attempt_answers where attempt_id = attempt.id and is_correct)
    where attempt.id = answer_row.attempt_id;
    attempt_is_completed := true;

    select * into bonus_result
    from private.award_attempt_point_bonuses(answer_row.attempt_id, 'live');
    completion_points := bonus_result.completion_points;
    grade_points := bonus_result.grade_points;
  end if;

  new_points := answer_points + recovery_points + completion_points + grade_points;
  update public.activity_attempts attempt
  set points_earned = (
    select coalesce(sum(event.points), 0)::integer
    from public.user_point_events event where event.attempt_id = attempt.id
  )
  where attempt.id = answer_row.attempt_id
  returning points_earned into attempt_points;

  insert into public.user_point_totals (user_id, lifetime_points)
  values (caller, new_points)
  on conflict (user_id) do update set
    lifetime_points = public.user_point_totals.lifetime_points + excluded.lifetime_points,
    state_version = public.user_point_totals.state_version + 1,
    updated_at = reviewed_at
  returning user_point_totals.lifetime_points into lifetime_points;

  confidence := private.item_confidence_label(caller, answer_row.knowledge_item_id, reviewed_at);
  return jsonb_build_object(
    'is_correct', correct,
    'correct_answer', answer_row.correct_answer,
    'term', item_row.term,
    'meaning', item_row.meaning,
    'example_sentence', item_row.example_sentence,
    'attempt_completed', attempt_is_completed,
    'confidence_status', confidence,
    'next_review_at', due_at,
    'rating', rating,
    'points_earned', answer_points + recovery_points,
    'answer_points', answer_points,
    'recovery_points', recovery_points,
    'completion_points', completion_points,
    'grade_points', grade_points,
    'attempt_points', attempt_points,
    'lifetime_points', lifetime_points,
    'points_breakdown', point_breakdown
  );
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
      'answer_points', coalesce((select sum(event.points) from public.user_point_events event where event.attempt_id = attempt.id and event.event_type = 'answer'), 0),
      'recovery_points', coalesce((select sum(event.points) from public.user_point_events event where event.attempt_id = attempt.id and event.event_type = 'recovery'), 0),
      'completion_points', coalesce((select sum(event.points) from public.user_point_events event where event.attempt_id = attempt.id and event.event_type = 'completion'), 0),
      'grade_points', coalesce((select sum(event.points) from public.user_point_events event where event.attempt_id = attempt.id and event.event_type = 'grade'), 0),
      'total_points', attempt.points_earned,
      'system_version', attempt.point_system_version
    ),
    'answers', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', answer.id,
          'attempt_id', answer.attempt_id,
          'user_id', answer.user_id,
          'knowledge_item_id', answer.knowledge_item_id,
          'position', answer.position,
          'question_type', answer.question_type,
          'prompt', answer.prompt,
          'options', answer.options,
          'correct_answer', case when answer.answered_at is not null or attempt.status = 'completed' then answer.correct_answer else null end,
          'selected_answer', answer.selected_answer,
          'is_correct', answer.is_correct,
          'answered_at', answer.answered_at,
          'term', item.term,
          'meaning', item.meaning,
          'example_sentence', item.example_sentence,
          'points_earned', coalesce((
            select sum(event.points)
            from public.user_point_events event
            where event.answer_id = answer.id and event.event_type in ('answer', 'recovery')
          ), 0)
        ) order by answer.position
      )
      from public.attempt_answers answer
      join public.knowledge_items item on item.id = answer.knowledge_item_id
      where answer.attempt_id = attempt.id
    ), '[]'::jsonb)
  ) into result
  from public.activity_attempts attempt
  where attempt.id = p_attempt_id and attempt.user_id = caller;
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
declare
  caller uuid := auth.uid();
  result jsonb;
begin
  if caller is null then raise exception 'Authentication required'; end if;

  select jsonb_build_object(
    'lifetime_points', coalesce((select lifetime_points from public.user_point_totals where user_id = caller), 0),
    'week_points', coalesce((
      select sum(event.points) from public.user_point_events event
      where event.user_id = caller and event.created_at >= date_trunc('week', now())
    ), 0),
    'completed_tests', (select count(*) from public.activity_attempts attempt where attempt.user_id = caller and attempt.status = 'completed'),
    'average_test_points', coalesce((
      select round(avg(attempt.points_earned)) from public.activity_attempts attempt
      where attempt.user_id = caller and attempt.status = 'completed'
    ), 0),
    'goals', coalesce((
      select jsonb_agg(jsonb_build_object(
        'category_id', goal.category_id,
        'category_name', category.name,
        'goal_role', goal.goal_role,
        'points', coalesce(goal_points.points, 0)
      ) order by goal.goal_weight desc, category.sort_order)
      from public.user_category_goals goal
      join public.categories category on category.id = goal.category_id
      left join (
        select mapping.category_id, sum(event.points)::bigint points
        from public.user_point_event_categories mapping
        join public.user_point_events event on event.id = mapping.event_id
        where mapping.user_id = caller
        group by mapping.category_id
      ) goal_points on goal_points.category_id = goal.category_id
      where goal.user_id = caller
    ), '[]'::jsonb)
  ) into result;
  return result;
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
declare
  v_caller uuid := auth.uid();
  v_focus_label text := nullif(btrim(p_focus_label), '');
  v_result jsonb;
  v_attempt_id uuid;
begin
  if v_caller is null then raise exception 'Authentication required'; end if;
  if v_focus_label is not null and char_length(v_focus_label) > 120 then
    raise exception 'Practice focus label must be 120 characters or fewer';
  end if;

  v_result := public.create_scoped_practice_attempt(
    p_source, p_requested_length, p_category_ids, p_source_attempt_id, p_item_ids
  );
  v_attempt_id := (v_result ->> 'attempt_id')::uuid;

  update public.activity_attempts
  set focus_label = v_focus_label
  where id = v_attempt_id and user_id = v_caller;
  if not found then raise exception 'Practice attempt not found'; end if;

  if v_focus_label like 'My Collection | Disliked Terms%' then
    update public.attempt_answers answer
    set preference_snapshot = 'disliked_explicit'
    where answer.attempt_id = v_attempt_id
      and exists (
        select 1 from public.user_collections collection
        where collection.user_id = v_caller
          and collection.knowledge_item_id = answer.knowledge_item_id
          and collection.is_disliked
      );
  end if;

  return v_result;
end;
$$;

-- Reconstruct the small existing history without changing FSRS state or answers.
do $$
declare
  review record;
  item public.knowledge_items;
  answer public.attempt_answers;
  attempt_record public.activity_attempts;
  point_result record;
  event_id bigint;
  status_before text;
  spacing_credit numeric;
  previous_wrong boolean;
  previous_scheduled_days numeric;
  bonuses record;
begin
  update public.attempt_answers answer_row
  set preference_snapshot = case
    when attempt_source.focus_label like 'My Collection | Liked Terms%' then 'liked'
    when attempt_source.focus_label like 'My Collection | Disliked Terms%' then 'disliked_explicit'
    else 'neutral'
  end
  from public.activity_attempts attempt_source
  where attempt_source.id = answer_row.attempt_id;

  for review in
    select event.*,
      lag(event.is_correct) over (
        partition by event.user_id, event.knowledge_item_id
        order by event.reviewed_at, event.id
      ) previous_correct,
      lag(event.scheduled_days) over (
        partition by event.user_id, event.knowledge_item_id
        order by event.reviewed_at, event.id
      ) previous_scheduled_days
    from public.user_item_review_events event
    order by event.reviewed_at, event.id
  loop
    select * into answer from public.attempt_answers where id = review.answer_id;
    select * into item from public.knowledge_items where id = review.knowledge_item_id;
    select * into attempt_record from public.activity_attempts attempt_row where attempt_row.id = answer.attempt_id;
    previous_wrong := review.previous_correct is false;
    previous_scheduled_days := review.previous_scheduled_days;
    status_before := case
      when review.stability_before is null then 'New'
      when previous_wrong then 'Needs practice'
      when review.stability_before >= 30 then 'Confident'
      else 'Learning'
    end;
    spacing_credit := case
      when review.stability_before is null or previous_scheduled_days is null or review.elapsed_days >= previous_scheduled_days then 1
      else 0.10 + 0.90 * power(least(1, review.elapsed_days / greatest(previous_scheduled_days, 0.000001)), 2)
    end;
    if previous_wrong then spacing_credit := greatest(0.35, spacing_credit); end if;

    select * into point_result from private.calculate_learning_points(
      attempt_record.point_system_version,
      review.question_type,
      item.difficulty,
      status_before,
      review.retrievability_before,
      review.difficulty_before,
      review.curriculum_value,
      answer.preference_snapshot,
      spacing_credit,
      previous_wrong,
      review.is_correct,
      item.source = 'user_added'
    );

    insert into public.user_point_events (
      user_id, attempt_id, answer_id, knowledge_item_id, event_type, points,
      system_version, question_type, content_difficulty, status_before,
      retrievability_before, fsrs_difficulty_before, curriculum_value,
      preference_snapshot, spacing_credit, factor_snapshot,
      calculation_mode, created_at
    ) values (
      review.user_id, answer.attempt_id, answer.id, review.knowledge_item_id,
      'answer', point_result.answer_points, attempt_record.point_system_version,
      review.question_type, item.difficulty, status_before,
      review.retrievability_before, review.difficulty_before, review.curriculum_value,
      answer.preference_snapshot, spacing_credit, point_result.breakdown,
      'historical-replay-v1', review.reviewed_at
    ) on conflict (answer_id, event_type) where answer_id is not null do nothing
    returning id into event_id;
    if event_id is not null then
      perform private.snapshot_point_event_categories(event_id, review.user_id, review.knowledge_item_id);
    end if;

    event_id := null;
    if point_result.recovery_points > 0 then
      insert into public.user_point_events (
        user_id, attempt_id, answer_id, knowledge_item_id, event_type, points,
        system_version, question_type, content_difficulty, status_before,
        retrievability_before, fsrs_difficulty_before, curriculum_value,
        preference_snapshot, spacing_credit, factor_snapshot,
        calculation_mode, created_at
      ) values (
        review.user_id, answer.attempt_id, answer.id, review.knowledge_item_id,
        'recovery', point_result.recovery_points, attempt_record.point_system_version,
        review.question_type, item.difficulty, status_before,
        review.retrievability_before, review.difficulty_before, review.curriculum_value,
        answer.preference_snapshot, spacing_credit,
        jsonb_build_object('previous_review_incorrect', true, 'points', point_result.recovery_points),
        'historical-replay-v1', review.reviewed_at
      ) on conflict (answer_id, event_type) where answer_id is not null do nothing
      returning id into event_id;
      if event_id is not null then
        perform private.snapshot_point_event_categories(event_id, review.user_id, review.knowledge_item_id);
      end if;
    end if;
  end loop;

  for attempt_record in select * from public.activity_attempts where status = 'completed'
  loop
    select * into bonuses from private.award_attempt_point_bonuses(attempt_record.id, 'historical-replay-v1');
  end loop;

  update public.activity_attempts attempt_row
  set points_earned = coalesce((
    select sum(event.points)::integer
    from public.user_point_events event where event.attempt_id = attempt_row.id
  ), 0);

  insert into public.user_point_totals (user_id, lifetime_points)
  select event.user_id, sum(event.points)::bigint
  from public.user_point_events event
  group by event.user_id
  on conflict (user_id) do update set
    lifetime_points = excluded.lifetime_points,
    state_version = public.user_point_totals.state_version + 1,
    updated_at = now();
end;
$$;

alter table public.user_point_events enable row level security;
alter table public.user_point_event_categories enable row level security;
alter table public.user_point_totals enable row level security;

create policy "point_events_select_own"
on public.user_point_events for select to authenticated
using ((select auth.uid()) = user_id);

create policy "point_event_categories_select_own"
on public.user_point_event_categories for select to authenticated
using ((select auth.uid()) = user_id);

create policy "point_totals_select_own"
on public.user_point_totals for select to authenticated
using ((select auth.uid()) = user_id);

revoke all on table private.point_system_configs from public, anon, authenticated;
revoke all on table public.user_point_events from public, anon, authenticated;
revoke all on table public.user_point_event_categories from public, anon, authenticated;
revoke all on table public.user_point_totals from public, anon, authenticated;

grant select on table public.user_point_events to authenticated;
grant select on table public.user_point_event_categories to authenticated;
grant select on table public.user_point_totals to authenticated;
grant all privileges on table public.user_point_events to service_role;
grant all privileges on table public.user_point_event_categories to service_role;
grant all privileges on table public.user_point_totals to service_role;
grant usage, select on sequence public.user_point_events_id_seq to service_role;
grant usage on type public.point_event_type to authenticated, service_role;

revoke all on function public.get_points_summary() from public, anon;
revoke all on function public.submit_practice_answer(uuid, text) from public, anon;
revoke all on function public.get_practice_attempt(uuid) from public, anon;
revoke all on function public.create_scoped_practice_attempt_with_focus(
  public.practice_source, integer, text[], uuid, uuid[], text
) from public, anon;

grant execute on function public.get_points_summary() to authenticated, service_role;
grant execute on function public.submit_practice_answer(uuid, text) to authenticated, service_role;
grant execute on function public.get_practice_attempt(uuid) to authenticated, service_role;
grant execute on function public.create_scoped_practice_attempt_with_focus(
  public.practice_source, integer, text[], uuid, uuid[], text
) to authenticated, service_role;

revoke all on function private.snapshot_attempt_point_system() from public, anon, authenticated;
revoke all on function private.snapshot_answer_preference() from public, anon, authenticated;
revoke all on function private.calculate_learning_points(
  text, public.question_type, public.knowledge_difficulty, text,
  numeric, numeric, numeric, text, numeric, boolean, boolean, boolean
) from public, anon, authenticated;
revoke all on function private.snapshot_point_event_categories(bigint, uuid, uuid) from public, anon, authenticated;
revoke all on function private.award_attempt_point_bonuses(uuid, text) from public, anon, authenticated;

comment on table public.user_point_events is
  'Immutable, owner-readable ledger of versioned Learning Points awards.';
comment on table public.user_point_totals is
  'Transactionally maintained lifetime Learning Points balance for each learner.';
comment on column public.activity_attempts.points_earned is
  'Final total of immutable point events awarded during this attempt.';
