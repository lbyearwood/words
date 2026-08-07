alter type public.practice_source add value if not exists 'recommended' before 'word_bank';

alter table public.knowledge_items
  add column default_importance numeric(4, 3) not null default 0.500,
  add constraint knowledge_items_default_importance_check
    check (default_importance between 0.000 and 1.000);

alter table public.knowledge_item_categories
  add column importance numeric(4, 3) not null default 0.600,
  add constraint knowledge_item_categories_importance_check
    check (importance between 0.000 and 1.000);

alter table private.wordnet_curation_records
  add column default_importance numeric(4, 3),
  add constraint wordnet_curation_default_importance_check
    check (default_importance is null or default_importance between 0.000 and 1.000),
  add constraint wordnet_curation_approved_importance_check
    check (status <> 'approved' or default_importance is not null);

alter table private.wordnet_curation_categories
  add column importance numeric(4, 3),
  add constraint wordnet_curation_category_importance_check
    check (importance is null or importance between 0.000 and 1.000);

-- Starter importance is deliberately reviewed term-by-term. Category mappings use
-- 0.800 for a primary relationship and 0.600 for a supporting relationship, with
-- essential category vocabulary promoted below.
with weights(term, importance) as (
  values
    ('Articulate', 0.850), ('Candid', 0.720), ('Concise', 0.900),
    ('Empathetic', 0.830), ('Clarify', 0.920), ('Assertive', 0.780),
    ('Attentive', 0.700), ('Considerate', 0.670), ('Deliberate', 0.740),
    ('Perceptive', 0.760), ('Nuanced', 0.880), ('Pragmatic', 0.820),
    ('Resilient', 0.780), ('Tactful', 0.760), ('Validate', 0.830),
    ('Hypothesis', 0.930), ('Analyse', 0.960), ('Evidence', 0.980),
    ('Context', 0.950), ('Infer', 0.920), ('Coherent', 0.880),
    ('Contrast', 0.890), ('Evaluate', 0.960), ('Methodology', 0.850),
    ('Synthesis', 0.860), ('Corroborate', 0.720), ('Empirical', 0.830),
    ('Extrapolate', 0.650), ('Paradigm', 0.690), ('Ubiquitous', 0.610),
    ('Agenda', 0.830), ('Collaborate', 0.900), ('Deadline', 0.860),
    ('Feedback', 0.950), ('Prioritise', 0.930), ('Accountable', 0.920),
    ('Delegate', 0.900), ('Efficient', 0.820), ('Initiative', 0.850),
    ('Stakeholder', 0.790), ('Consensus', 0.850), ('Contingency', 0.730),
    ('Facilitate', 0.820), ('Mitigate', 0.780), ('Strategic', 0.900),
    ('Break the ice', 0.620), ('On the same page', 0.720),
    ('Hit the nail on the head', 0.600), ('Once in a blue moon', 0.520),
    ('Under the weather', 0.580), ('A blessing in disguise', 0.520),
    ('Cut to the chase', 0.700), ('Get the ball rolling', 0.690),
    ('In the long run', 0.680), ('Think outside the box', 0.650),
    ('Bite the bullet', 0.600), ('Read between the lines', 0.760),
    ('The tip of the iceberg', 0.630), ('Throw in the towel', 0.570),
    ('Weather the storm', 0.590), ('Knowledge is power', 0.650),
    ('Practice makes progress', 0.730), ('Actions speak louder than words', 0.680),
    ('The only way out is through', 0.580), ('Small steps add up', 0.640),
    ('Fortune favours the bold', 0.520), ('Less is more', 0.620),
    ('Time is the wisest counsellor', 0.480), ('Well begun is half done', 0.550),
    ('What we think, we become', 0.520),
    ('The unexamined life is not worth living', 0.500),
    ('In the middle of difficulty lies opportunity', 0.470),
    ('No wind favours the sailor who has no port', 0.460),
    ('We are what we repeatedly do', 0.590),
    ('The journey of a thousand miles begins with one step', 0.580)
)
update public.knowledge_items item
set default_importance = weights.importance
from weights
where item.term = weights.term and item.source = 'seeded';

update public.knowledge_items set default_importance = 0.700 where source = 'user_added';
update public.knowledge_item_categories set importance = case when is_primary then 0.800 else 0.600 end;

-- Promote category-defining relationships. These are independent of the KI's
-- general usefulness and are intentionally attached to the junction row.
with essential(term, category_id, importance) as (
  values
    ('Hypothesis', 'research_methods_evidence', 0.970),
    ('Analyse', 'critical_thinking_logic', 0.970),
    ('Analyse', 'education_learning', 0.930),
    ('Evidence', 'research_methods_evidence', 1.000),
    ('Evidence', 'critical_thinking_logic', 0.970),
    ('Context', 'academic_language_writing', 0.980),
    ('Infer', 'critical_thinking_logic', 0.950),
    ('Evaluate', 'education_learning', 0.970),
    ('Evaluate', 'critical_thinking_logic', 0.960),
    ('Methodology', 'research_methods_evidence', 0.950),
    ('Feedback', 'professional_communication', 0.980),
    ('Feedback', 'leadership_management', 0.930),
    ('Prioritise', 'leadership_management', 0.980),
    ('Accountable', 'leadership_management', 0.980),
    ('Delegate', 'leadership_management', 0.970),
    ('Strategic', 'leadership_management', 0.970),
    ('Articulate', 'sophisticated_speaker', 0.960),
    ('Concise', 'sophisticated_speaker', 0.940),
    ('Clarify', 'sophisticated_speaker', 0.950),
    ('Nuanced', 'sophisticated_speaker', 0.950)
)
update public.knowledge_item_categories mapping
set importance = essential.importance
from essential
join public.knowledge_items item on item.term = essential.term
where mapping.knowledge_item_id = item.id
  and mapping.category_id = essential.category_id;

create type public.category_goal_role as enum ('primary', 'supporting');

create table public.user_category_goals (
  user_id uuid not null references auth.users (id) on delete cascade,
  category_id text not null references public.categories (id) on delete cascade,
  goal_role public.category_goal_role not null,
  goal_weight numeric(4, 3) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, category_id),
  constraint user_category_goals_weight_check check (
    (goal_role = 'primary' and goal_weight = 1.000)
    or (goal_role = 'supporting' and goal_weight = 0.600)
  )
);

create unique index user_category_goals_one_primary_idx
  on public.user_category_goals (user_id) where goal_role = 'primary';
create index user_category_goals_user_weight_idx
  on public.user_category_goals (user_id, goal_weight desc, category_id);

create table public.user_item_learning_states (
  user_id uuid not null references auth.users (id) on delete cascade,
  knowledge_item_id uuid not null references public.knowledge_items (id) on delete cascade,
  stability numeric(14, 8) not null check (stability between 0.001 and 36500),
  difficulty numeric(11, 8) not null check (difficulty between 1 and 10),
  repetitions integer not null default 0 check (repetitions >= 0),
  lapses integer not null default 0 check (lapses >= 0),
  last_rating smallint not null check (last_rating between 1 and 3),
  last_question_type public.question_type not null,
  last_answer_correct boolean not null,
  last_review_at timestamptz not null,
  next_review_at timestamptz not null,
  algorithm_version text not null default 'ts-fsrs-5.4.1/fsrs-6.0',
  state_version integer not null default 1 check (state_version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, knowledge_item_id)
);

create index user_item_learning_due_idx
  on public.user_item_learning_states (user_id, next_review_at, knowledge_item_id);
create index user_item_learning_recent_idx
  on public.user_item_learning_states (user_id, last_review_at desc);

create table public.user_item_review_events (
  id bigint generated always as identity primary key,
  answer_id uuid not null unique references public.attempt_answers (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  knowledge_item_id uuid not null references public.knowledge_items (id) on delete cascade,
  question_type public.question_type not null,
  rating smallint not null check (rating between 1 and 3),
  is_correct boolean not null,
  reviewed_at timestamptz not null,
  elapsed_days numeric(12, 6) not null check (elapsed_days >= 0),
  retrievability_before numeric(10, 8) not null check (retrievability_before between 0 and 1),
  stability_before numeric(14, 8),
  stability_after numeric(14, 8) not null,
  difficulty_before numeric(11, 8),
  difficulty_after numeric(11, 8) not null,
  curriculum_value numeric(10, 8) not null check (curriculum_value between 0 and 1),
  desired_retention numeric(10, 8) not null check (desired_retention between 0.86 and 0.94),
  scheduled_days numeric(12, 6) not null check (scheduled_days >= 0),
  algorithm_version text not null,
  created_at timestamptz not null default now()
);

create index user_item_reviews_history_idx
  on public.user_item_review_events (user_id, knowledge_item_id, reviewed_at desc);

create table public.activity_attempt_categories (
  attempt_id uuid not null,
  user_id uuid not null,
  category_id text not null references public.categories (id) on delete restrict,
  goal_role public.category_goal_role,
  goal_weight numeric(4, 3) check (goal_weight between 0 and 1),
  created_at timestamptz not null default now(),
  primary key (attempt_id, category_id),
  foreign key (attempt_id, user_id)
    references public.activity_attempts (id, user_id) on delete cascade
);

insert into public.activity_attempt_categories (attempt_id, user_id, category_id)
select id, user_id, category_id from public.activity_attempts where category_id is not null;

alter table public.activity_attempts
  add column selection_version text not null default 'uniform-v1',
  add column goal_snapshot jsonb not null default '[]'::jsonb;

alter table public.attempt_answers
  add column selection_pool text,
  add column selection_score numeric(16, 10),
  add column curriculum_value_at_selection numeric(10, 8),
  add column retrievability_at_selection numeric(10, 8),
  add column desired_retention_at_selection numeric(10, 8);

create table private.fsrs_scheduler_configs (
  algorithm_version text primary key,
  parameters numeric[] not null check (cardinality(parameters) = 21),
  active boolean not null default false,
  created_at timestamptz not null default now()
);

insert into private.fsrs_scheduler_configs (algorithm_version, parameters, active)
values (
  'ts-fsrs-5.4.1/fsrs-6.0',
  array[0.212,1.2931,2.3065,8.2956,6.4133,0.8334,3.0194,0.001,
        1.8722,0.1666,0.796,1.4835,0.0614,0.2629,1.6483,0.6014,
        1.8729,0.5425,0.0912,0.0658,0.1542]::numeric[],
  true
);

create or replace function public.fsrs_retrievability(
  p_stability numeric,
  p_elapsed_days numeric
)
returns numeric
language sql
immutable
strict
set search_path = pg_catalog
as $$
  select round(
    power(
      1 + (exp(ln(0.9) / -0.1542) - 1) * greatest(p_elapsed_days, 0) / p_stability,
      -0.1542
    )::numeric,
    8
  );
$$;

create or replace function private.fsrs_interval_days(
  p_stability numeric,
  p_retention numeric
)
returns integer
language sql
immutable
strict
set search_path = pg_catalog
as $$
  select least(
    36500,
    greatest(
      1,
      round(
        p_stability *
        ((power(p_retention, 1 / -0.1542) - 1) /
         (exp(ln(0.9) / -0.1542) - 1))
      )::integer
    )
  );
$$;

create or replace function private.fsrs_next_state(
  p_stability numeric,
  p_difficulty numeric,
  p_elapsed_days numeric,
  p_rating smallint
)
returns table(stability numeric, difficulty numeric)
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  w numeric[] := array[0.212,1.2931,2.3065,8.2956,6.4133,0.8334,3.0194,0.001,
                       1.8722,0.1666,0.796,1.4835,0.0614,0.2629,1.6483,0.6014,
                       1.8729,0.5425,0.0912,0.0658,0.1542];
  old_s numeric := coalesce(p_stability, 0);
  old_d numeric := coalesce(p_difficulty, 0);
  r numeric;
  initial_d numeric;
  delta_d numeric;
  next_d numeric;
  next_s numeric;
  sinc numeric;
  s_after_fail numeric;
  next_s_min numeric;
begin
  if p_rating not between 1 and 3 or p_elapsed_days < 0 then
    raise exception 'Invalid FSRS input';
  end if;

  if old_s = 0 and old_d = 0 then
    stability := greatest(w[p_rating], 0.1);
    difficulty := least(10, greatest(1, w[5] - exp((p_rating - 1) * w[6]) + 1));
    return next;
    return;
  end if;

  r := public.fsrs_retrievability(old_s, p_elapsed_days);
  -- FSRS clamps initial card difficulty, but deliberately uses the raw Easy
  -- difficulty during mean reversion.
  initial_d := w[5] - exp(3 * w[6]) + 1;
  delta_d := -w[7] * (p_rating - 3);
  next_d := old_d + delta_d * (10 - old_d) / 9;
  next_d := w[8] * initial_d + (1 - w[8]) * next_d;
  difficulty := least(10, greatest(1, round(next_d, 8)));

  if p_elapsed_days = 0 then
    sinc := power(old_s, -w[20]) * exp(w[18] * (p_rating - 3 + w[19]));
    if p_rating >= 2 then sinc := greatest(sinc, 1); end if;
    next_s := old_s * sinc;
  elsif p_rating = 1 then
    s_after_fail := w[12] * power(old_d, -w[13]) *
      (power(old_s + 1, w[14]) - 1) * exp((1 - r) * w[15]);
    next_s_min := old_s / exp(w[18] * w[19]);
    next_s := greatest(0.001, least(next_s_min, s_after_fail));
  else
    next_s := old_s * (
      1 + exp(w[9]) * (11 - old_d) * power(old_s, -w[10]) *
      (exp((1 - r) * w[11]) - 1) *
      case when p_rating = 2 then w[16] else 1 end
    );
  end if;

  stability := round(least(36500, greatest(0.001, next_s)), 8);
  return next;
end;
$$;

create or replace function private.item_curriculum_value(
  p_user_id uuid,
  p_knowledge_item_id uuid
)
returns numeric
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  with item as (
    select default_importance, owner_id
    from public.knowledge_items where id = p_knowledge_item_id
  ), goal_totals as (
    select
      count(*)::integer as goal_count,
      coalesce(sum(goal.goal_weight * mapping.importance), 0) as affinity
    from public.user_category_goals goal
    left join public.knowledge_item_categories mapping
      on mapping.knowledge_item_id = p_knowledge_item_id
     and mapping.category_id = goal.category_id
    where goal.user_id = p_user_id
  ), base as (
    select
      item.default_importance,
      item.owner_id,
      case when goal_totals.goal_count > 0
        then 0.15 * item.default_importance + 0.85 * (1 - exp(-goal_totals.affinity))
        else item.default_importance
      end as value
    from item cross join goal_totals
  )
  select round(
    least(1, greatest(0,
      1 - (1 - base.value) *
        (1 - case when base.owner_id = p_user_id or exists (
          select 1 from public.user_collections collection
          where collection.user_id = p_user_id
            and collection.knowledge_item_id = p_knowledge_item_id
            and collection.state = 'saved'
        ) then 0.15 else 0 end)
    ))::numeric,
    8
  )
  from base;
$$;

create or replace function private.item_confidence_label(
  p_user_id uuid,
  p_knowledge_item_id uuid,
  p_at timestamptz default now()
)
returns text
language plpgsql
stable
security invoker
set search_path = pg_catalog, public
as $$
declare
  state_row public.user_item_learning_states;
  curriculum numeric;
  retention_target numeric;
  recall_now numeric;
  spaced_mc_success boolean;
begin
  select * into state_row
  from public.user_item_learning_states
  where user_id = p_user_id and knowledge_item_id = p_knowledge_item_id;

  if state_row.user_id is null then return 'New'; end if;
  curriculum := private.item_curriculum_value(p_user_id, p_knowledge_item_id);
  retention_target := 0.86 + 0.08 * curriculum;
  recall_now := public.fsrs_retrievability(
    state_row.stability,
    greatest(0, extract(epoch from (p_at - state_row.last_review_at)) / 86400)
  );
  if not state_row.last_answer_correct or recall_now < retention_target then
    return 'Needs practice';
  end if;

  select exists (
    select 1
    from public.user_item_review_events earlier
    join public.user_item_review_events later
      on later.user_id = earlier.user_id
     and later.knowledge_item_id = earlier.knowledge_item_id
     and later.reviewed_at >= earlier.reviewed_at + interval '18 hours'
    where earlier.user_id = p_user_id
      and earlier.knowledge_item_id = p_knowledge_item_id
      and earlier.question_type = 'multiple_choice'
      and later.question_type = 'multiple_choice'
      and earlier.is_correct and later.is_correct
  ) into spaced_mc_success;

  if state_row.stability >= 30 and spaced_mc_success then return 'Confident'; end if;
  return 'Learning';
end;
$$;

create or replace function public.current_item_curriculum_value(p_knowledge_item_id uuid)
returns numeric
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  return private.item_curriculum_value(auth.uid(), p_knowledge_item_id);
end;
$$;

create or replace function public.current_item_confidence_label(p_knowledge_item_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  return private.item_confidence_label(auth.uid(), p_knowledge_item_id);
end;
$$;

create or replace function public.create_personal_item(
  p_term text,
  p_meaning text,
  p_example_sentence text,
  p_primary_category text,
  p_difficulty public.knowledge_difficulty,
  p_secondary_categories text[] default '{}'
)
returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  created_item_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not exists (select 1 from public.categories where id = p_primary_category) then
    raise exception 'Unknown primary category: %', p_primary_category;
  end if;
  if exists (
    select 1 from unnest(coalesce(p_secondary_categories, '{}')) secondary(category_id)
    left join public.categories category on category.id = secondary.category_id
    where category.id is null
  ) then raise exception 'One or more secondary categories are unknown'; end if;

  insert into public.knowledge_items (
    term, meaning, example_sentence, difficulty, default_importance, source, owner_id
  ) values (
    trim(p_term), trim(p_meaning), trim(p_example_sentence), p_difficulty,
    0.700, 'user_added', auth.uid()
  ) returning id into created_item_id;

  insert into public.knowledge_item_categories (
    knowledge_item_id, category_id, is_primary, importance
  ) values (created_item_id, p_primary_category, true, 0.800);
  insert into public.knowledge_item_categories (
    knowledge_item_id, category_id, is_primary, importance
  )
  select created_item_id, secondary.category_id, false, 0.600
  from (select distinct unnest(coalesce(p_secondary_categories, '{}')) category_id) secondary
  where secondary.category_id <> p_primary_category;

  insert into public.user_collections (user_id, knowledge_item_id, state)
  values (auth.uid(), created_item_id, 'saved');
  return created_item_id;
end;
$$;

create or replace function public.set_category_goals(
  primary_category_id text,
  supporting_category_ids text[] default '{}'
)
returns setof public.user_category_goals
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller uuid := auth.uid();
  supporting text[];
begin
  if caller is null then raise exception 'Authentication required'; end if;
  supporting := array(
    select distinct value from unnest(coalesce(supporting_category_ids, '{}')) value
    where value <> primary_category_id order by value
  );
  if primary_category_id is null or not exists (
    select 1 from public.categories where id = primary_category_id
  ) then raise exception 'Choose a valid primary category'; end if;
  if cardinality(supporting) > 3 then raise exception 'Choose no more than three supporting categories'; end if;
  if exists (
    select 1 from unnest(supporting) value
    left join public.categories category on category.id = value
    where category.id is null
  ) then raise exception 'One or more supporting categories are invalid'; end if;

  delete from public.user_category_goals where user_id = caller;
  insert into public.user_category_goals (user_id, category_id, goal_role, goal_weight)
  values (caller, primary_category_id, 'primary', 1.000);
  insert into public.user_category_goals (user_id, category_id, goal_role, goal_weight)
  select caller, value, 'supporting', 0.600 from unnest(supporting) value;

  return query select * from public.user_category_goals where user_id = caller
    order by goal_weight desc, category_id;
end;
$$;

create or replace function public.clear_category_goals()
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  delete from public.user_category_goals where user_id = auth.uid();
end;
$$;

create or replace function public.create_practice_attempt(
  p_source public.practice_source,
  p_requested_length integer,
  p_category_ids text[] default '{}',
  p_source_attempt_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
  caller uuid := auth.uid();
  attempt_id uuid := gen_random_uuid();
  eligible_count integer;
  actual_count integer;
  position_index integer := 0;
  selected record;
  option_values jsonb;
  shown_meaning text;
  make_true boolean;
  selection_key numeric;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  if p_requested_length not between 10 and 200 then raise exception 'Question count must be between 10 and 200'; end if;
  if p_source = 'category' and cardinality(coalesce(p_category_ids, '{}')) <> 1 then
    raise exception 'Choose one category';
  end if;
  if p_source = 'attempt_misses' and not exists (
    select 1 from public.activity_attempts attempt
    where attempt.id = p_source_attempt_id and attempt.user_id = caller
  ) then raise exception 'The source attempt was not found'; end if;

  create temporary table if not exists pg_temp.practice_candidates (
    item_id uuid primary key,
    pool text not null,
    weight double precision not null,
    curriculum double precision not null,
    retrievability double precision not null,
    desired_retention double precision not null,
    sample_key double precision not null
  ) on commit drop;
  truncate pg_temp.practice_candidates;

  insert into pg_temp.practice_candidates
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
  ), weighted as (
    select *,
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
      end weight
    from scored
  )
  select id, pool, weight, curriculum, retrievability, desired_retention,
    -ln(((hashtextextended(attempt_id::text || id::text, 0) & 9223372036854775807)::double precision + 1::double precision)
      / 9223372036854775808::double precision) / greatest(weight, 0.000001::double precision)
  from weighted;

  select count(*) into eligible_count from pg_temp.practice_candidates;
  if eligible_count = 0 then raise exception 'There are no eligible words in this source yet'; end if;
  actual_count := least(p_requested_length, eligible_count);

  create temporary table if not exists pg_temp.practice_selected (
    item_id uuid primary key,
    pool text not null,
    weight double precision not null,
    curriculum double precision not null,
    retrievability double precision not null,
    desired_retention double precision not null,
    sample_key double precision not null
  ) on commit drop;
  truncate pg_temp.practice_selected;

  if p_source = 'recommended' then
    insert into pg_temp.practice_selected
    with ranked as (
      select candidate.*, row_number() over (partition by pool order by sample_key) pool_rank
      from pg_temp.practice_candidates candidate
    )
    select item_id, pool, weight, curriculum, retrievability, desired_retention, sample_key
    from ranked
    where pool_rank <= case pool
      when 'target_due' then ceil(actual_count * 0.45)
      when 'target_weak' then ceil(actual_count * 0.20)
      when 'target_new' then ceil(actual_count * 0.15)
      when 'outside_due' then ceil(actual_count * 0.10)
      else ceil(actual_count * 0.10)
    end
    order by sample_key limit actual_count;

    insert into pg_temp.practice_selected
    select candidate.item_id, candidate.pool, candidate.weight, candidate.curriculum,
      candidate.retrievability, candidate.desired_retention, candidate.sample_key
    from pg_temp.practice_candidates candidate
    where not exists (select 1 from pg_temp.practice_selected chosen where chosen.item_id = candidate.item_id)
    order by candidate.sample_key
    limit greatest(0, actual_count - (select count(*) from pg_temp.practice_selected));
  else
    insert into pg_temp.practice_selected
    select * from pg_temp.practice_candidates order by sample_key limit actual_count;
  end if;

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
    select chosen.*, item.term, item.meaning
    from pg_temp.practice_selected chosen
    join public.knowledge_items item on item.id = chosen.item_id
    order by chosen.sample_key
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
    return jsonb_build_object(
      'is_correct', answer_row.is_correct,
      'correct_answer', answer_row.correct_answer,
      'term', item_row.term,
      'meaning', item_row.meaning,
      'example_sentence', item_row.example_sentence,
      'attempt_completed', attempt_row.status = 'completed',
      'confidence_status', private.item_confidence_label(caller, answer_row.knowledge_item_id)
    );
  end if;

  correct := p_selected_answer = answer_row.correct_answer;
  rating := case when not correct then 1 when answer_row.question_type = 'true_false' then 2 else 3 end;
  curriculum := private.item_curriculum_value(caller, answer_row.knowledge_item_id);
  retention_target := 0.86 + 0.08 * curriculum;

  select * into state_row from public.user_item_learning_states
  where user_id = caller and knowledge_item_id = answer_row.knowledge_item_id
  for update;

  elapsed := case when state_row.user_id is null then 0
    else greatest(0, floor(extract(epoch from (now() - state_row.last_review_at)) / 86400)) end;
  recall_before := case when state_row.user_id is null then 0
    else public.fsrs_retrievability(state_row.stability, elapsed) end;
  select * into new_state from private.fsrs_next_state(
    state_row.stability, state_row.difficulty, elapsed, rating
  );
  scheduled_days := case when rating = 1 then 10.0 / 1440
    else private.fsrs_interval_days(new_state.stability, retention_target) end;
  due_at := now() + scheduled_days * interval '1 day';

  update public.attempt_answers
  set selected_answer = p_selected_answer,
      is_correct = correct,
      answered_at = now()
  where id = answer_row.id;

  insert into public.user_item_review_events (
    answer_id, user_id, knowledge_item_id, question_type, rating, is_correct,
    reviewed_at, elapsed_days, retrievability_before, stability_before, stability_after,
    difficulty_before, difficulty_after, curriculum_value, desired_retention,
    scheduled_days, algorithm_version
  ) values (
    answer_row.id, caller, answer_row.knowledge_item_id, answer_row.question_type,
    rating, correct, now(), elapsed, recall_before, state_row.stability, new_state.stability,
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
    rating, answer_row.question_type, correct, now(), due_at,
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
    updated_at = now();

  if not exists (
    select 1 from public.attempt_answers pending
    where pending.attempt_id = answer_row.attempt_id and pending.answered_at is null
  ) then
    update public.activity_attempts attempt
    set status = 'completed',
        completed_at = now(),
        duration_seconds = greatest(0, extract(epoch from (now() - attempt.started_at))::integer),
        actual_length = (select count(*) from public.attempt_answers where attempt_id = attempt.id),
        score = (select count(*) from public.attempt_answers where attempt_id = attempt.id and is_correct)
    where attempt.id = answer_row.attempt_id;
    attempt_is_completed := true;
  end if;

  confidence := private.item_confidence_label(caller, answer_row.knowledge_item_id);
  return jsonb_build_object(
    'is_correct', correct,
    'correct_answer', answer_row.correct_answer,
    'term', item_row.term,
    'meaning', item_row.meaning,
    'example_sentence', item_row.example_sentence,
    'attempt_completed', attempt_is_completed,
    'confidence_status', confidence,
    'next_review_at', due_at,
    'rating', rating
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
          'example_sentence', item.example_sentence
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

drop view public.user_item_confidence;
create view public.user_item_confidence
with (security_invoker = true)
as
select
  collection.user_id,
  collection.knowledge_item_id,
  coalesce(state.repetitions, 0)::integer as recent_answer_count,
  coalesce((
    select avg(case when event.is_correct then 100.0 else 0 end)
    from public.user_item_review_events event
    where event.user_id = collection.user_id
      and event.knowledge_item_id = collection.knowledge_item_id
  ), 0)::numeric(5, 2) as recent_accuracy,
  public.current_item_confidence_label(collection.knowledge_item_id) as confidence_status,
  state.stability,
  state.next_review_at
from public.user_collections collection
left join public.user_item_learning_states state
  on state.user_id = collection.user_id
 and state.knowledge_item_id = collection.knowledge_item_id
where collection.state = 'saved';

create view public.user_item_learning_summary
with (security_invoker = true)
as
select
  state.user_id,
  state.knowledge_item_id,
  state.stability,
  state.difficulty,
  state.repetitions,
  state.lapses,
  state.last_answer_correct,
  state.last_review_at,
  state.next_review_at,
  public.fsrs_retrievability(
    state.stability,
    greatest(0, extract(epoch from (now() - state.last_review_at)) / 86400)
  ) as current_retrievability,
  public.current_item_curriculum_value(state.knowledge_item_id) as curriculum_value,
  public.current_item_confidence_label(state.knowledge_item_id) as confidence_status
from public.user_item_learning_states state;

create view public.user_category_mastery
with (security_invoker = true)
as
with visible as (
  select goal.user_id, goal.category_id, goal.goal_role, goal.goal_weight,
    mapping.knowledge_item_id, mapping.importance,
    state.stability, state.last_review_at, state.repetitions
  from public.user_category_goals goal
  join public.knowledge_item_categories mapping on mapping.category_id = goal.category_id
  join public.knowledge_items item on item.id = mapping.knowledge_item_id
  left join public.user_item_learning_states state
    on state.user_id = goal.user_id and state.knowledge_item_id = mapping.knowledge_item_id
  where (item.source = 'seeded' or item.owner_id = goal.user_id)
    and not exists (
      select 1 from public.user_collections hidden
      where hidden.user_id = goal.user_id
        and hidden.knowledge_item_id = item.id
        and hidden.state = 'hidden'
    )
), scored as (
  select *,
    case when stability is null then 0 else public.fsrs_retrievability(
      stability, greatest(0, extract(epoch from (now() - last_review_at)) / 86400)
    ) end current_recall,
    case when stability is null then 0 else public.fsrs_retrievability(
      stability, greatest(0, extract(epoch from (now() - last_review_at)) / 86400) + 30
    ) end durable_recall
  from visible
)
select user_id, category_id, goal_role, goal_weight,
  round((100 * coalesce(sum(importance) filter (where repetitions > 0), 0) / nullif(sum(importance), 0))::numeric, 1) coverage,
  round((100 * sum(importance * current_recall) / nullif(sum(importance), 0))::numeric, 1) current_recall,
  round((100 * sum(importance * durable_recall) / nullif(sum(importance), 0))::numeric, 1) durable_mastery,
  count(*)::integer total_items,
  count(*) filter (where repetitions > 0)::integer practised_items
from scored
group by user_id, category_id, goal_role, goal_weight;

create or replace function public.get_learning_dashboard()
returns jsonb
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
    'overall', (
      with visible as (
        select item.id, item.default_importance, state.stability,
          state.last_review_at, state.repetitions
        from public.knowledge_items item
        left join public.user_item_learning_states state
          on state.user_id = auth.uid() and state.knowledge_item_id = item.id
        where (item.source = 'seeded' or item.owner_id = auth.uid())
          and not exists (
            select 1 from public.user_collections hidden
            where hidden.user_id = auth.uid()
              and hidden.knowledge_item_id = item.id
              and hidden.state = 'hidden'
          )
      ), scored as (
        select *,
          case when stability is null then 0 else public.fsrs_retrievability(
            stability, greatest(0, extract(epoch from (now() - last_review_at)) / 86400)
          ) end current_recall,
          case when stability is null then 0 else public.fsrs_retrievability(
            stability, greatest(0, extract(epoch from (now() - last_review_at)) / 86400) + 30
          ) end durable_recall
        from visible
      )
      select jsonb_build_object(
        'coverage', round((100 * coalesce(sum(default_importance) filter (where repetitions > 0), 0) / nullif(sum(default_importance), 0))::numeric, 1),
        'current_recall', round((100 * sum(default_importance * current_recall) / nullif(sum(default_importance), 0))::numeric, 1),
        'durable_mastery', round((100 * sum(default_importance * durable_recall) / nullif(sum(default_importance), 0))::numeric, 1),
        'total_items', count(*)::integer,
        'practised_items', count(*) filter (where repetitions > 0)::integer
      )
      from scored
    ),
    'goals', coalesce((
      select jsonb_agg(jsonb_build_object(
        'category_id', mastery.category_id,
        'category_name', category.name,
        'goal_role', mastery.goal_role,
        'goal_weight', mastery.goal_weight,
        'coverage', mastery.coverage,
        'current_recall', mastery.current_recall,
        'durable_mastery', mastery.durable_mastery,
        'total_items', mastery.total_items,
        'practised_items', mastery.practised_items
      ) order by mastery.goal_weight desc, category.sort_order)
      from public.user_category_mastery mastery
      join public.categories category on category.id = mastery.category_id
      where mastery.user_id = auth.uid()
    ), '[]'::jsonb),
    'due_count', (
      select count(*) from public.user_item_learning_states state
      where state.user_id = auth.uid() and state.next_review_at <= now()
    ),
    'reviewed_unique', (
      select count(*) from public.user_item_learning_states state where state.user_id = auth.uid()
    )
  );
$$;

create or replace function public.get_practice_setup_counts()
returns jsonb
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  with visible as (
    select item.id, item.source, state.last_answer_correct
    from public.knowledge_items item
    left join public.user_item_learning_states state
      on state.user_id = auth.uid() and state.knowledge_item_id = item.id
    where (item.source = 'seeded' or item.owner_id = auth.uid())
      and not exists (
        select 1 from public.user_collections hidden
        where hidden.user_id = auth.uid() and hidden.knowledge_item_id = item.id and hidden.state = 'hidden'
      )
  )
  select jsonb_build_object(
    'recommended', count(*),
    'word_bank', count(*) filter (where exists (
      select 1 from public.user_collections saved
      where saved.user_id = auth.uid() and saved.knowledge_item_id = visible.id and saved.state = 'saved'
    )),
    'missed', count(*) filter (where last_answer_correct = false),
    'mixed_library', count(*) filter (where source = 'seeded'),
    'categories', coalesce((
      select jsonb_object_agg(category_id, item_count)
      from (
        select mapping.category_id, count(distinct mapping.knowledge_item_id) item_count
        from public.knowledge_item_categories mapping
        join visible on visible.id = mapping.knowledge_item_id
        group by mapping.category_id
      ) counts
    ), '{}'::jsonb)
  ) from visible;
$$;

-- Migrate any legacy interest list without changing users who have not selected one.
insert into public.user_category_goals (user_id, category_id, goal_role, goal_weight)
select profile.id, category_id,
  case when ordinal = 1 then 'primary'::public.category_goal_role else 'supporting'::public.category_goal_role end,
  case when ordinal = 1 then 1.000 else 0.600 end
from public.profiles profile
cross join lateral unnest(profile.interested_categories) with ordinality selected(category_id, ordinal)
where ordinal <= 4
on conflict do nothing;

-- Replay existing answer history into the new model without modifying attempts,
-- collections, answers or timestamps.
do $$
declare
  answer_row record;
  state_row public.user_item_learning_states;
  rating smallint;
  curriculum numeric;
  retention_target numeric;
  elapsed numeric;
  recall_before numeric;
  new_state record;
  scheduled_days numeric;
begin
  for answer_row in
    select answer.*
    from public.attempt_answers answer
    where answer.is_correct is not null and answer.answered_at is not null
    order by answer.user_id, answer.knowledge_item_id, answer.answered_at, answer.id
  loop
    select * into state_row from public.user_item_learning_states
    where user_id = answer_row.user_id and knowledge_item_id = answer_row.knowledge_item_id;
    rating := case when not answer_row.is_correct then 1
      when answer_row.question_type = 'true_false' then 2 else 3 end;
    curriculum := private.item_curriculum_value(answer_row.user_id, answer_row.knowledge_item_id);
    retention_target := 0.86 + 0.08 * curriculum;
    elapsed := case when state_row.user_id is null then 0 else greatest(0,
      floor(extract(epoch from (answer_row.answered_at - state_row.last_review_at)) / 86400)) end;
    recall_before := case when state_row.user_id is null then 0
      else public.fsrs_retrievability(state_row.stability, elapsed) end;
    select * into new_state from private.fsrs_next_state(
      state_row.stability, state_row.difficulty, elapsed, rating
    );
    scheduled_days := case when rating = 1 then 10.0 / 1440
      else private.fsrs_interval_days(new_state.stability, retention_target) end;

    insert into public.user_item_review_events (
      answer_id, user_id, knowledge_item_id, question_type, rating, is_correct,
      reviewed_at, elapsed_days, retrievability_before, stability_before, stability_after,
      difficulty_before, difficulty_after, curriculum_value, desired_retention,
      scheduled_days, algorithm_version
    ) values (
      answer_row.id, answer_row.user_id, answer_row.knowledge_item_id,
      answer_row.question_type, rating, answer_row.is_correct, answer_row.answered_at,
      elapsed, recall_before, state_row.stability, new_state.stability,
      state_row.difficulty, new_state.difficulty, curriculum, retention_target,
      scheduled_days, 'ts-fsrs-5.4.1/fsrs-6.0'
    ) on conflict (answer_id) do nothing;

    insert into public.user_item_learning_states (
      user_id, knowledge_item_id, stability, difficulty, repetitions, lapses,
      last_rating, last_question_type, last_answer_correct, last_review_at,
      next_review_at, algorithm_version, state_version
    ) values (
      answer_row.user_id, answer_row.knowledge_item_id, new_state.stability, new_state.difficulty,
      coalesce(state_row.repetitions, 0) + 1,
      coalesce(state_row.lapses, 0) + case when rating = 1 then 1 else 0 end,
      rating, answer_row.question_type, answer_row.is_correct, answer_row.answered_at,
      answer_row.answered_at + scheduled_days * interval '1 day',
      'ts-fsrs-5.4.1/fsrs-6.0', coalesce(state_row.state_version, 0) + 1
    ) on conflict (user_id, knowledge_item_id) do update set
      stability = excluded.stability, difficulty = excluded.difficulty,
      repetitions = excluded.repetitions, lapses = excluded.lapses,
      last_rating = excluded.last_rating, last_question_type = excluded.last_question_type,
      last_answer_correct = excluded.last_answer_correct,
      last_review_at = excluded.last_review_at, next_review_at = excluded.next_review_at,
      state_version = excluded.state_version, updated_at = now();
  end loop;
end;
$$;

create trigger user_category_goals_set_updated_at
before update on public.user_category_goals
for each row execute function private.set_updated_at();
create trigger user_item_learning_states_set_updated_at
before update on public.user_item_learning_states
for each row execute function private.set_updated_at();

alter table public.user_category_goals enable row level security;
alter table public.user_item_learning_states enable row level security;
alter table public.user_item_review_events enable row level security;
alter table public.activity_attempt_categories enable row level security;
alter table private.fsrs_scheduler_configs enable row level security;

create policy "category_goals_select_own" on public.user_category_goals
for select to authenticated using ((select auth.uid()) = user_id);
create policy "learning_states_select_own" on public.user_item_learning_states
for select to authenticated using ((select auth.uid()) = user_id);
create policy "review_events_select_own" on public.user_item_review_events
for select to authenticated using ((select auth.uid()) = user_id);
create policy "attempt_categories_select_own" on public.activity_attempt_categories
for select to authenticated using ((select auth.uid()) = user_id);

revoke all on table public.user_category_goals from anon, authenticated;
revoke all on table public.user_item_learning_states from anon, authenticated;
revoke all on table public.user_item_review_events from anon, authenticated;
revoke all on table public.activity_attempt_categories from anon, authenticated;
grant select on public.user_category_goals to authenticated;
grant select on public.user_item_learning_states to authenticated;
grant select on public.user_item_review_events to authenticated;
grant select on public.activity_attempt_categories to authenticated;
grant select on public.user_item_confidence to authenticated;
grant select on public.user_item_learning_summary to authenticated;
grant select on public.user_category_mastery to authenticated;
grant usage on type public.category_goal_role to authenticated;

grant all privileges on public.user_category_goals to service_role;
grant all privileges on public.user_item_learning_states to service_role;
grant all privileges on public.user_item_review_events to service_role;
grant all privileges on public.activity_attempt_categories to service_role;
grant usage, select on all sequences in schema public to service_role;

revoke insert, update, delete on public.activity_attempts from authenticated;
revoke insert, update, delete on public.attempt_answers from authenticated;
revoke select on public.attempt_answers from authenticated;
revoke all on function public.set_category_goals(text, text[]) from public, anon;
revoke all on function public.clear_category_goals() from public, anon;
revoke all on function public.create_practice_attempt(public.practice_source, integer, text[], uuid) from public, anon;
revoke all on function public.submit_practice_answer(uuid, text) from public, anon;
revoke all on function public.get_practice_attempt(uuid) from public, anon;
revoke all on function public.get_learning_dashboard() from public, anon;
revoke all on function public.get_practice_setup_counts() from public, anon;
revoke all on function public.fsrs_retrievability(numeric, numeric) from public, anon;
revoke all on function public.current_item_curriculum_value(uuid) from public, anon;
revoke all on function public.current_item_confidence_label(uuid) from public, anon;
grant execute on function public.set_category_goals(text, text[]) to authenticated;
grant execute on function public.clear_category_goals() to authenticated;
grant execute on function public.create_practice_attempt(public.practice_source, integer, text[], uuid) to authenticated;
grant execute on function public.submit_practice_answer(uuid, text) to authenticated;
grant execute on function public.get_practice_attempt(uuid) to authenticated;
grant execute on function public.get_learning_dashboard() to authenticated;
grant execute on function public.get_practice_setup_counts() to authenticated;
grant execute on function public.fsrs_retrievability(numeric, numeric) to authenticated;
grant execute on function public.current_item_curriculum_value(uuid) to authenticated;
grant execute on function public.current_item_confidence_label(uuid) to authenticated;

revoke all on table private.fsrs_scheduler_configs from public, anon, authenticated;
revoke all on function private.fsrs_interval_days(numeric, numeric) from public, anon, authenticated;
revoke all on function private.fsrs_next_state(numeric, numeric, numeric, smallint) from public, anon, authenticated;
revoke all on function private.item_curriculum_value(uuid, uuid) from public, anon, authenticated;
revoke all on function private.item_confidence_label(uuid, uuid, timestamptz) from public, anon, authenticated;
