-- Support one practice attempt drawn from several learner-selected sources.
-- The helper is private and release-aware through learner-owned V2 records.

create or replace function private.v2_multi_source_item_ids(
  p_user_id uuid,
  p_sources public.practice_source[],
  p_category_ids uuid[],
  p_source_attempt_id uuid
)
returns table (learning_item_id uuid)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select distinct on (vocabulary.term_family_id) learning.id
  from public.learning_items learning
  join public.vocabulary_items vocabulary
    on vocabulary.learning_item_id = learning.id
  left join public.user_item_learning_states state
    on state.user_id = p_user_id
   and state.learning_item_id = learning.id
  where learning.user_id = p_user_id
    and learning.item_type = 'vocabulary'
    and learning.practice_enabled
    and (learning.qa_status = 'approved' or learning.origin = 'user_created')
    and learning.archived_at is null
    and (
      'recommended'::public.practice_source = any(p_sources)
      or 'mixed_library'::public.practice_source = any(p_sources)
      or (
        'word_bank'::public.practice_source = any(p_sources)
        and exists (
          select 1
          from public.user_collections collection
          where collection.user_id = p_user_id
            and collection.learning_item_id = learning.id
            and collection.state = 'saved'
        )
      )
      or (
        'missed'::public.practice_source = any(p_sources)
        and state.last_answer_correct = false
      )
      or (
        'category'::public.practice_source = any(p_sources)
        and exists (
          select 1
          from public.learning_item_categories mapping
          where mapping.learning_item_id = learning.id
            and mapping.learner_category_id = any(p_category_ids)
        )
      )
      or (
        'attempt_misses'::public.practice_source = any(p_sources)
        and exists (
          select 1
          from public.attempt_answers answer
          where answer.attempt_id = p_source_attempt_id
            and answer.user_id = p_user_id
            and answer.learning_item_id = learning.id
            and answer.is_correct = false
        )
      )
    )
  order by vocabulary.term_family_id, learning.importance desc, learning.id;
$$;

revoke all on function private.v2_multi_source_item_ids(
  uuid, public.practice_source[], uuid[], uuid
) from public, anon, authenticated;

create or replace function public.get_practice_setup_count_multi(
  p_sources public.practice_source[],
  p_category_ids text[] default '{}',
  p_source_attempt_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller uuid := auth.uid();
  normalized_sources public.practice_source[] := '{}';
  category_uuids uuid[] := '{}';
  eligible_count integer;
begin
  if caller is null then raise exception 'Authentication required'; end if;

  select coalesce(array_agg(distinct source order by source), '{}')
  into normalized_sources
  from unnest(coalesce(p_sources, '{}')) source;

  if cardinality(normalized_sources) = 0 then
    return 0;
  end if;

  begin
    select coalesce(array_agg(distinct value::uuid), '{}')
    into category_uuids
    from unnest(coalesce(p_category_ids, '{}')) value;
  exception when invalid_text_representation then
    raise exception 'Choose categories from your learning plan';
  end;

  if 'category'::public.practice_source = any(normalized_sources)
     and cardinality(category_uuids) = 0 then
    return 0;
  end if;

  if exists (
    select 1
    from unnest(category_uuids) category_id
    where not exists (
      select 1
      from public.learner_categories category
      where category.id = category_id and category.user_id = caller
    )
  ) then raise exception 'Choose categories from your learning plan'; end if;

  if 'attempt_misses'::public.practice_source = any(normalized_sources)
     and not exists (
       select 1 from public.activity_attempts attempt
       where attempt.id = p_source_attempt_id and attempt.user_id = caller
     ) then raise exception 'The source attempt was not found'; end if;

  select count(*)::integer
  into eligible_count
  from private.v2_multi_source_item_ids(
    caller, normalized_sources, category_uuids, p_source_attempt_id
  );

  return eligible_count;
end;
$$;

create or replace function public.create_practice_attempt_multi(
  p_sources public.practice_source[],
  p_requested_length integer,
  p_category_ids text[] default '{}',
  p_source_attempt_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller uuid := auth.uid();
  normalized_sources public.practice_source[] := '{}';
  category_uuids uuid[] := '{}';
  selected_item_ids uuid[] := '{}';
  stored_source public.practice_source;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  if p_requested_length not between 10 and 200 then
    raise exception 'Question count must be between 10 and 200';
  end if;

  select coalesce(array_agg(distinct source order by source), '{}')
  into normalized_sources
  from unnest(coalesce(p_sources, '{}')) source;

  if cardinality(normalized_sources) = 0 then
    raise exception 'Choose at least one practice source';
  end if;

  begin
    select coalesce(array_agg(distinct value::uuid), '{}')
    into category_uuids
    from unnest(coalesce(p_category_ids, '{}')) value;
  exception when invalid_text_representation then
    raise exception 'Choose categories from your learning plan';
  end;

  if 'category'::public.practice_source = any(normalized_sources)
     and cardinality(category_uuids) = 0 then
    raise exception 'Choose at least one category';
  end if;

  if exists (
    select 1
    from unnest(category_uuids) category_id
    where not exists (
      select 1
      from public.learner_categories category
      where category.id = category_id and category.user_id = caller
    )
  ) then raise exception 'Choose categories from your learning plan'; end if;

  if 'attempt_misses'::public.practice_source = any(normalized_sources)
     and not exists (
       select 1 from public.activity_attempts attempt
       where attempt.id = p_source_attempt_id and attempt.user_id = caller
     ) then raise exception 'The source attempt was not found'; end if;

  if cardinality(normalized_sources) = 1 then
    return private.create_v2_practice_attempt(
      normalized_sources[1], p_requested_length, p_category_ids,
      p_source_attempt_id, '{}', null
    );
  end if;

  select coalesce(array_agg(source_item.learning_item_id), '{}')
  into selected_item_ids
  from private.v2_multi_source_item_ids(
    caller, normalized_sources, category_uuids, p_source_attempt_id
  ) source_item;

  if cardinality(selected_item_ids) = 0 then
    raise exception 'There are no practice-ready terms in these sources yet';
  end if;

  stored_source := 'mixed_library';
  return private.create_v2_practice_attempt(
    stored_source, p_requested_length, '{}', null,
    selected_item_ids, 'Mixed Library'
  );
end;
$$;

revoke all on function public.get_practice_setup_count_multi(
  public.practice_source[], text[], uuid
) from public, anon;
revoke all on function public.create_practice_attempt_multi(
  public.practice_source[], integer, text[], uuid
) from public, anon;

grant execute on function public.get_practice_setup_count_multi(
  public.practice_source[], text[], uuid
) to authenticated;
grant execute on function public.create_practice_attempt_multi(
  public.practice_source[], integer, text[], uuid
) to authenticated;

comment on function public.get_practice_setup_count_multi(
  public.practice_source[], text[], uuid
) is 'Returns the deduplicated learner-owned term count for one or more practice sources.';
comment on function public.create_practice_attempt_multi(
  public.practice_source[], integer, text[], uuid
) is 'Creates one learner-owned practice attempt from a deduplicated union of selected sources.';
