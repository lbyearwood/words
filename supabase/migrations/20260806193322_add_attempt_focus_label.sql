alter table public.activity_attempts
  add column focus_label text;

alter table public.activity_attempts
  add constraint activity_attempts_focus_label_valid
  check (
    focus_label is null
    or char_length(btrim(focus_label)) between 1 and 120
  );

comment on column public.activity_attempts.focus_label is
  'Immutable learner-facing snapshot of the practice scope, such as My Collection | Liked Terms.';

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
  if v_caller is null then
    raise exception 'Authentication required';
  end if;

  if v_focus_label is not null and char_length(v_focus_label) > 120 then
    raise exception 'Practice focus label must be 120 characters or fewer';
  end if;

  v_result := public.create_scoped_practice_attempt(
    p_source,
    p_requested_length,
    p_category_ids,
    p_source_attempt_id,
    p_item_ids
  );
  v_attempt_id := (v_result ->> 'attempt_id')::uuid;

  update public.activity_attempts
  set focus_label = v_focus_label
  where id = v_attempt_id
    and user_id = v_caller;

  if not found then
    raise exception 'Practice attempt not found';
  end if;

  return v_result;
end;
$$;

comment on function public.create_scoped_practice_attempt_with_focus(
  public.practice_source,
  integer,
  text[],
  uuid,
  uuid[],
  text
) is 'Atomically creates an explicitly scoped practice attempt and stores its learner-facing focus snapshot.';

revoke all on function public.create_scoped_practice_attempt_with_focus(
  public.practice_source,
  integer,
  text[],
  uuid,
  uuid[],
  text
) from public, anon;

grant execute on function public.create_scoped_practice_attempt_with_focus(
  public.practice_source,
  integer,
  text[],
  uuid,
  uuid[],
  text
) to authenticated, service_role;

-- Historical attempts did not snapshot their collection tab. Recover only the
-- unambiguous case requested here: every tested item is still liked by the owner.
update public.activity_attempts as attempt
set focus_label = 'My Collection | Liked Terms'
where attempt.source = 'word_bank'
  and attempt.status = 'completed'
  and attempt.focus_label is null
  and exists (
    select 1
    from public.attempt_answers as answer
    where answer.attempt_id = attempt.id
  )
  and not exists (
    select 1
    from public.attempt_answers as answer
    left join public.user_collections as collection
      on collection.user_id = attempt.user_id
     and collection.knowledge_item_id = answer.knowledge_item_id
     and collection.is_liked
    where answer.attempt_id = attempt.id
      and collection.knowledge_item_id is null
  );
