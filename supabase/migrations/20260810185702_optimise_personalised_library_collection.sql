-- Build personalised item payloads as one set instead of invoking a nested
-- item-building function once for every row returned to the learner.
create or replace function private.v2_item_rows(p_user_id uuid)
returns table (
  learning_item_id uuid,
  display_term text,
  definition text,
  sense_order integer,
  item_json jsonb
)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  with category_payload as materialized (
    select
      mapping.learning_item_id,
      jsonb_agg(
        jsonb_build_object(
          'id', category.id,
          'slug', category.slug,
          'name', category.name,
          'description', category.description,
          'sort_order', category.sort_order,
          'is_primary', mapping.is_primary,
          'importance', mapping.importance
        )
        order by mapping.is_primary desc, category.sort_order
      ) as categories
    from public.learning_item_categories mapping
    join public.learner_categories category
      on category.id = mapping.learner_category_id
     and category.user_id = p_user_id
    where mapping.user_id = p_user_id
    group by mapping.learning_item_id
  )
  select
    learning.id,
    family.display_term,
    vocabulary.definition,
    vocabulary.sense_order::integer,
    jsonb_build_object(
      'id', learning.id,
      'learning_item_id', learning.id,
      'source_knowledge_item_id', learning.source_knowledge_item_id,
      'term_family_id', family.id,
      'term', family.display_term,
      'meaning', vocabulary.definition,
      'example_sentence', vocabulary.example_sentence,
      'part_of_speech', vocabulary.part_of_speech,
      'pronunciation', vocabulary.pronunciation,
      'sense_label', vocabulary.sense_label,
      'sense_order', vocabulary.sense_order,
      'difficulty', learning.difficulty,
      'source', case when learning.origin = 'user_created' then 'user_added' else 'seeded' end,
      'owner_id', learning.user_id,
      'default_importance', learning.importance,
      'item_type', learning.item_type,
      'origin', learning.origin,
      'qa_status', learning.qa_status,
      'practice_enabled', learning.practice_enabled,
      'content_version', learning.content_version,
      'categories', coalesce(category_payload.categories, '[]'::jsonb)
    )
  from public.learning_items learning
  join public.vocabulary_items vocabulary
    on vocabulary.learning_item_id = learning.id
   and vocabulary.user_id = p_user_id
  join public.learner_term_families family
    on family.id = vocabulary.term_family_id
   and family.user_id = p_user_id
  left join category_payload on category_payload.learning_item_id = learning.id
  where learning.user_id = p_user_id
    and learning.qa_status <> 'excluded';
$$;

revoke all on function private.v2_item_rows(uuid) from public, anon, authenticated;

create or replace function public.get_my_library(
  p_search text default null,
  p_category_ids uuid[] default '{}',
  p_limit integer default 1000,
  p_offset integer default 0
)
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
  if p_limit not between 1 and 2000 or p_offset < 0 then raise exception 'Invalid page'; end if;

  select coalesce(
    jsonb_agg(filtered.item_json order by filtered.display_term, filtered.sense_order),
    '[]'::jsonb
  )
  into result
  from (
    select item.learning_item_id, item.display_term, item.sense_order, item.item_json
    from private.v2_item_rows(caller) item
    where (
      p_search is null
      or btrim(p_search) = ''
      or item.display_term ilike '%' || btrim(p_search) || '%'
      or item.definition ilike '%' || btrim(p_search) || '%'
    )
      and (
        cardinality(coalesce(p_category_ids, '{}')) = 0
        or exists (
          select 1
          from public.learning_item_categories mapping
          where mapping.user_id = caller
            and mapping.learning_item_id = item.learning_item_id
            and mapping.learner_category_id = any(p_category_ids)
        )
      )
    order by item.display_term, item.sense_order
    limit p_limit offset p_offset
  ) filtered;

  return result;
end;
$$;

create or replace function public.get_my_collection()
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

  with item_payload as materialized (
    select * from private.v2_item_rows(caller)
  )
  select jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(item.item_json order by item.display_term, item.sense_order)
      from public.user_collections collection
      join item_payload item on item.learning_item_id = collection.learning_item_id
      where collection.user_id = caller
    ), '[]'::jsonb),
    'collections', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', collection.user_id,
        'knowledge_item_id', collection.learning_item_id,
        'learning_item_id', collection.learning_item_id,
        'state', collection.state,
        'is_liked', collection.is_liked,
        'is_disliked', collection.is_disliked,
        'created_at', collection.created_at,
        'updated_at', collection.updated_at
      ))
      from public.user_collections collection
      join item_payload item on item.learning_item_id = collection.learning_item_id
      where collection.user_id = caller
    ), '[]'::jsonb),
    'confidence', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', caller,
        'knowledge_item_id', item.learning_item_id,
        'learning_item_id', item.learning_item_id,
        'recent_answer_count', coalesce(state.repetitions, 0),
        'recent_accuracy', case
          when state.repetitions is null then 0
          when state.last_answer_correct then 1
          else 0
        end,
        'confidence_status', case
          when state.user_id is null then 'New'
          else private.v2_confidence_label(caller, item.learning_item_id)
        end,
        'stability', state.stability,
        'next_review_at', state.next_review_at
      ))
      from public.user_collections collection
      join item_payload item on item.learning_item_id = collection.learning_item_id
      left join public.user_item_learning_states state
        on state.user_id = caller
       and state.learning_item_id = item.learning_item_id
      where collection.user_id = caller
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

revoke all on function public.get_my_library(text, uuid[], integer, integer) from public, anon;
revoke all on function public.get_my_collection() from public, anon;
grant execute on function public.get_my_library(text, uuid[], integer, integer) to authenticated;
grant execute on function public.get_my_collection() to authenticated;
