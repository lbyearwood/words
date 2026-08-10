-- V2 category IDs belong to learner_categories and must never be written to
-- the legacy activity_attempts.category_id column, whose foreign key targets
-- the shared categories table. Snapshot learner-owned category context in its
-- own junction and retain a human-readable focus label on the attempt.
alter table public.activity_attempts
  drop constraint attempt_category_source_check;

alter table public.activity_attempts
  add constraint attempt_category_source_check check (
    (
      selection_version = 'learner-owned-fsrs-v2'
      and category_id is null
    )
    or (
      selection_version <> 'learner-owned-fsrs-v2'
      and (
        (source = 'category' and category_id is not null)
        or (source <> 'category' and category_id is null)
      )
    )
  );

create table public.learner_activity_attempt_categories (
  attempt_id uuid not null,
  user_id uuid not null,
  learner_category_id uuid not null,
  goal_role public.category_goal_role,
  goal_weight numeric(4,3) check (goal_weight between 0 and 1),
  created_at timestamptz not null default now(),
  primary key (attempt_id, learner_category_id),
  foreign key (attempt_id, user_id)
    references public.activity_attempts (id, user_id) on delete cascade,
  foreign key (learner_category_id, user_id)
    references public.learner_categories (id, user_id) on delete cascade
);

create index learner_activity_attempt_categories_user_attempt_idx
  on public.learner_activity_attempt_categories (user_id, attempt_id);
create index learner_activity_attempt_categories_category_idx
  on public.learner_activity_attempt_categories (learner_category_id);

alter table public.learner_activity_attempt_categories enable row level security;

create policy learner_attempt_categories_select_own
  on public.learner_activity_attempt_categories
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.learner_activity_attempt_categories
  from public, anon, authenticated;
grant select on table public.learner_activity_attempt_categories to authenticated;
grant all on table public.learner_activity_attempt_categories to service_role;

do $migration$
declare
  function_definition text;
  old_attempt_insert text;
  new_attempt_insert text;
begin
  select pg_catalog.pg_get_functiondef(
    'private.create_v2_practice_attempt(public.practice_source,integer,text[],uuid,uuid[],text)'::regprocedure
  ) into function_definition;

  function_definition := pg_catalog.replace(function_definition, E'\r\n', E'\n');

  old_attempt_insert := $old$
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
$old$;

  new_attempt_insert := $new$
    null,
    case when p_source = 'attempt_misses' then p_source_attempt_id else null end,
    p_requested_length, actual_count, 'learner-owned-fsrs-v2',
    coalesce((select jsonb_agg(jsonb_build_object(
      'category_id', focus.learner_category_id,
      'role', focus.goal_role,
      'weight', focus.goal_weight
    ) order by focus.goal_weight desc, focus.learner_category_id)
    from public.learner_category_focus focus where focus.user_id = caller), '[]'::jsonb),
    coalesce(
      nullif(btrim(p_focus_label), ''),
      case when p_source = 'category' then (
        select pg_catalog.string_agg(category.name, ' | ' order by category.sort_order)
        from public.learner_categories category
        where category.user_id = caller
          and category.id = any(category_uuids)
      ) end
    )
  );

  if p_source = 'recommended' then
    insert into public.learner_activity_attempt_categories (
      attempt_id, user_id, learner_category_id, goal_role, goal_weight
    )
    select attempt_id, caller, focus.learner_category_id, focus.goal_role, focus.goal_weight
    from public.learner_category_focus focus
    where focus.user_id = caller;
  elsif p_source = 'category' then
    insert into public.learner_activity_attempt_categories (
      attempt_id, user_id, learner_category_id
    )
    select attempt_id, caller, selected_category_id
    from unnest(category_uuids) selected_category_id;
  end if;

  for selected in
$new$;

  if pg_catalog.strpos(function_definition, old_attempt_insert) = 0 then
    raise exception 'Unable to patch V2 selected-category attempt insertion';
  end if;

  function_definition := pg_catalog.replace(
    function_definition,
    old_attempt_insert,
    new_attempt_insert
  );

  execute function_definition;
end;
$migration$;

revoke all on function private.create_v2_practice_attempt(
  public.practice_source, integer, text[], uuid, uuid[], text
) from public, anon, authenticated;
grant execute on function private.create_v2_practice_attempt(
  public.practice_source, integer, text[], uuid, uuid[], text
) to service_role;
