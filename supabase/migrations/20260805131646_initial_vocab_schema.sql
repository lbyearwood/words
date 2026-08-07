create type public.knowledge_category as enum (
  'everyday_communication',
  'school_subjects',
  'work',
  'idioms_phrases',
  'quotes'
);

create type public.knowledge_difficulty as enum ('beginner', 'intermediate', 'advanced');
create type public.knowledge_source as enum ('seeded', 'user_added');
create type public.collection_state as enum ('saved', 'hidden');
create type public.practice_source as enum (
  'word_bank',
  'missed',
  'category',
  'mixed_library',
  'attempt_misses'
);
create type public.question_type as enum (
  'multiple_choice',
  'true_false'
);
create type public.attempt_status as enum ('in_progress', 'completed', 'abandoned');

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 60),
  goals text[] not null default '{}',
  interested_categories public.knowledge_category[] not null default '{}',
  current_level public.knowledge_difficulty,
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.knowledge_items (
  id uuid primary key default gen_random_uuid(),
  term text not null check (char_length(trim(term)) between 1 and 160),
  meaning text not null check (char_length(trim(meaning)) between 1 and 600),
  example_sentence text not null check (char_length(trim(example_sentence)) between 1 and 800),
  category public.knowledge_category not null,
  difficulty public.knowledge_difficulty not null,
  source public.knowledge_source not null,
  owner_id uuid references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint knowledge_item_source_owner_check check (
    (source = 'seeded' and owner_id is null)
    or (source = 'user_added' and owner_id is not null)
  )
);

create table public.user_collections (
  user_id uuid not null references auth.users (id) on delete cascade,
  knowledge_item_id uuid not null references public.knowledge_items (id) on delete cascade,
  state public.collection_state not null default 'saved',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, knowledge_item_id)
);

create table public.activity_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  source public.practice_source not null,
  category public.knowledge_category,
  source_attempt_id uuid,
  requested_length integer not null check (requested_length between 10 and 200),
  actual_length integer not null default 0 check (actual_length between 0 and 200),
  status public.attempt_status not null default 'in_progress',
  score integer not null default 0 check (score >= 0 and score <= actual_length),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  duration_seconds integer check (duration_seconds is null or duration_seconds >= 0),
  created_at timestamptz not null default now(),
  unique (id, user_id),
  constraint attempt_category_source_check check (
    (source = 'category' and category is not null)
    or (source <> 'category' and category is null)
  ),
  constraint attempt_retest_source_check check (
    (source = 'attempt_misses' and source_attempt_id is not null)
    or (source <> 'attempt_misses' and source_attempt_id is null)
  ),
  constraint attempt_completion_check check (
    (status = 'completed' and completed_at is not null and duration_seconds is not null)
    or (status <> 'completed' and completed_at is null)
  ),
  foreign key (source_attempt_id, user_id)
    references public.activity_attempts (id, user_id)
);

create table public.attempt_answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  knowledge_item_id uuid not null references public.knowledge_items (id),
  position integer not null check (position between 1 and 200),
  question_type public.question_type not null,
  prompt text not null check (char_length(trim(prompt)) > 0),
  options jsonb not null check (
    jsonb_typeof(options) = 'array'
    and jsonb_array_length(options) between 2 and 4
  ),
  correct_answer text not null,
  selected_answer text,
  is_correct boolean,
  answered_at timestamptz,
  created_at timestamptz not null default now(),
  unique (attempt_id, position),
  unique (attempt_id, knowledge_item_id),
  foreign key (attempt_id, user_id)
    references public.activity_attempts (id, user_id) on delete cascade,
  constraint answer_completion_check check (
    (selected_answer is null and is_correct is null and answered_at is null)
    or (selected_answer is not null and is_correct is not null and answered_at is not null)
  )
);

create index knowledge_items_browse_idx
  on public.knowledge_items (source, category, difficulty, lower(term));
create index knowledge_items_owner_idx on public.knowledge_items (owner_id);
create index user_collections_state_idx on public.user_collections (user_id, state);
create index activity_attempts_recent_idx
  on public.activity_attempts (user_id, completed_at desc)
  where status = 'completed';
create index attempt_answers_item_recent_idx
  on public.attempt_answers (user_id, knowledge_item_id, answered_at desc)
  where is_correct is not null;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();

create trigger knowledge_items_set_updated_at
before update on public.knowledge_items
for each row execute function private.set_updated_at();

create trigger user_collections_set_updated_at
before update on public.user_collections
for each row execute function private.set_updated_at();

alter table public.profiles enable row level security;
alter table public.knowledge_items enable row level security;
alter table public.user_collections enable row level security;
alter table public.activity_attempts enable row level security;
alter table public.attempt_answers enable row level security;

create policy "profiles_select_own"
on public.profiles for select to authenticated
using ((select auth.uid()) = id);

create policy "profiles_update_own"
on public.profiles for update to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "knowledge_items_select_visible"
on public.knowledge_items for select to authenticated
using (source = 'seeded' or (select auth.uid()) = owner_id);

create policy "knowledge_items_insert_owned"
on public.knowledge_items for insert to authenticated
with check (source = 'user_added' and (select auth.uid()) = owner_id);

create policy "knowledge_items_update_owned"
on public.knowledge_items for update to authenticated
using (source = 'user_added' and (select auth.uid()) = owner_id)
with check (source = 'user_added' and (select auth.uid()) = owner_id);

create policy "knowledge_items_delete_owned"
on public.knowledge_items for delete to authenticated
using (source = 'user_added' and (select auth.uid()) = owner_id);

create policy "collections_select_own"
on public.user_collections for select to authenticated
using ((select auth.uid()) = user_id);

create policy "collections_insert_own_visible_item"
on public.user_collections for insert to authenticated
with check (
  (select auth.uid()) = user_id
  and exists (
    select 1 from public.knowledge_items item
    where item.id = knowledge_item_id
      and (item.source = 'seeded' or item.owner_id = (select auth.uid()))
  )
);

create policy "collections_update_own"
on public.user_collections for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "collections_delete_own"
on public.user_collections for delete to authenticated
using ((select auth.uid()) = user_id);

create policy "attempts_select_own"
on public.activity_attempts for select to authenticated
using ((select auth.uid()) = user_id);

create policy "attempts_insert_own"
on public.activity_attempts for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "attempts_update_own"
on public.activity_attempts for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "attempts_delete_own"
on public.activity_attempts for delete to authenticated
using ((select auth.uid()) = user_id);

create policy "answers_select_own_attempt"
on public.attempt_answers for select to authenticated
using (
  (select auth.uid()) = user_id
  and exists (
    select 1 from public.activity_attempts attempt
    where attempt.id = attempt_id and attempt.user_id = (select auth.uid())
  )
);

create policy "answers_insert_own_attempt"
on public.attempt_answers for insert to authenticated
with check (
  (select auth.uid()) = user_id
  and exists (
    select 1 from public.activity_attempts attempt
    where attempt.id = attempt_id and attempt.user_id = (select auth.uid())
  )
);

create policy "answers_update_own_attempt"
on public.attempt_answers for update to authenticated
using (
  (select auth.uid()) = user_id
  and exists (
    select 1 from public.activity_attempts attempt
    where attempt.id = attempt_id and attempt.user_id = (select auth.uid())
  )
)
with check (
  (select auth.uid()) = user_id
  and exists (
    select 1 from public.activity_attempts attempt
    where attempt.id = attempt_id and attempt.user_id = (select auth.uid())
  )
);

create policy "answers_delete_own_attempt"
on public.attempt_answers for delete to authenticated
using (
  (select auth.uid()) = user_id
  and exists (
    select 1 from public.activity_attempts attempt
    where attempt.id = attempt_id and attempt.user_id = (select auth.uid())
  )
);

create view public.user_item_confidence
with (security_invoker = true)
as
select
  collection.user_id,
  collection.knowledge_item_id,
  coalesce(recent.answer_count, 0)::integer as recent_answer_count,
  coalesce(recent.recent_accuracy, 0)::numeric(5, 2) as recent_accuracy,
  case
    when coalesce(recent.answer_count, 0) = 0 then 'New'
    when recent.latest_correct = false or recent.recent_accuracy < 60 then 'Needs practice'
    when recent.answer_count >= 3 and recent.latest_correct = true and recent.recent_accuracy >= 80 then 'Confident'
    else 'Learning'
  end::text as confidence_status
from public.user_collections collection
left join lateral (
  select
    count(*)::integer as answer_count,
    avg(case when answers.is_correct then 100.0 else 0.0 end) as recent_accuracy,
    (array_agg(answers.is_correct order by answers.answered_at desc))[1] as latest_correct
  from (
    select answer.is_correct, answer.answered_at
    from public.attempt_answers answer
    join public.activity_attempts attempt
      on attempt.id = answer.attempt_id and attempt.user_id = answer.user_id
    where answer.user_id = collection.user_id
      and answer.knowledge_item_id = collection.knowledge_item_id
      and answer.is_correct is not null
      and attempt.status = 'completed'
    order by answer.answered_at desc
    limit 5
  ) answers
) recent on true
where collection.state = 'saved';

create function public.create_personal_item(
  p_term text,
  p_meaning text,
  p_example_sentence text,
  p_category public.knowledge_category,
  p_difficulty public.knowledge_difficulty
)
returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  created_item_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  insert into public.knowledge_items (
    term, meaning, example_sentence, category, difficulty, source, owner_id
  ) values (
    trim(p_term), trim(p_meaning), trim(p_example_sentence),
    p_category, p_difficulty, 'user_added', auth.uid()
  ) returning id into created_item_id;

  insert into public.user_collections (user_id, knowledge_item_id, state)
  values (auth.uid(), created_item_id, 'saved');

  return created_item_id;
end;
$$;

create function public.complete_attempt(
  p_attempt_id uuid,
  p_duration_seconds integer
)
returns public.activity_attempts
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  completed_attempt public.activity_attempts;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  update public.activity_attempts attempt
  set
    actual_length = answer_totals.answer_count,
    score = answer_totals.correct_count,
    status = 'completed',
    completed_at = now(),
    duration_seconds = greatest(p_duration_seconds, 0)
  from (
    select
      count(*)::integer as answer_count,
      count(*) filter (where is_correct)::integer as correct_count
    from public.attempt_answers
    where attempt_id = p_attempt_id
      and user_id = auth.uid()
      and is_correct is not null
  ) answer_totals
  where attempt.id = p_attempt_id
    and attempt.user_id = auth.uid()
    and attempt.status = 'in_progress'
    and answer_totals.answer_count > 0
  returning attempt.* into completed_attempt;

  if completed_attempt.id is null then
    raise exception 'Attempt not found, already completed, or has no answered questions';
  end if;

  return completed_attempt;
end;
$$;

revoke all on all tables in schema public from anon;
revoke all on all functions in schema public from public, anon;

grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;

grant usage on schema public to authenticated;
grant usage on type public.knowledge_category to authenticated;
grant usage on type public.knowledge_difficulty to authenticated;
grant usage on type public.knowledge_source to authenticated;
grant usage on type public.collection_state to authenticated;
grant usage on type public.practice_source to authenticated;
grant usage on type public.question_type to authenticated;
grant usage on type public.attempt_status to authenticated;

grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.knowledge_items to authenticated;
grant select, insert, update, delete on public.user_collections to authenticated;
grant select, insert, update, delete on public.activity_attempts to authenticated;
grant select, insert, update, delete on public.attempt_answers to authenticated;
grant select on public.user_item_confidence to authenticated;
grant execute on function public.create_personal_item(
  text, text, text, public.knowledge_category, public.knowledge_difficulty
) to authenticated;
grant execute on function public.complete_attempt(uuid, integer) to authenticated;
