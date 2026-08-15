-- Max already owns an approved Evidentiary item. Keep the content unchanged
-- and make the existing collection preference saved, liked and not disliked.
do $$
declare
  max_user constant uuid := '8b57ddf0-1152-4b2a-85cd-ead229c3f075';
  learning_id uuid;
  source_id uuid;
  matched_count integer;
  liked_count integer;
begin
  -- Production contains Max. Schema-only local resets intentionally do not.
  if not exists (
    select 1 from public.profiles profile
    where profile.id = max_user and lower(profile.display_name) = 'max'
  ) then
    raise notice 'Max profile is absent; skipping Max-specific preference.';
    return;
  end if;

  select count(*) into matched_count
  from public.learner_term_families family
  join public.vocabulary_items vocabulary
    on vocabulary.user_id = max_user and vocabulary.term_family_id = family.id
  join public.learning_items learning
    on learning.id = vocabulary.learning_item_id and learning.user_id = max_user
  where family.user_id = max_user
    and family.normalized_term = 'evidentiary'
    and learning.qa_status = 'approved'
    and learning.practice_enabled
    and learning.archived_at is null;

  if matched_count <> 1 then
    raise exception 'Expected one active approved Evidentiary item for Max, found %', matched_count;
  end if;

  select learning.id, learning.source_knowledge_item_id
  into learning_id, source_id
  from public.learner_term_families family
  join public.vocabulary_items vocabulary
    on vocabulary.user_id = max_user and vocabulary.term_family_id = family.id
  join public.learning_items learning
    on learning.id = vocabulary.learning_item_id and learning.user_id = max_user
  where family.user_id = max_user
    and family.normalized_term = 'evidentiary'
    and learning.qa_status = 'approved'
    and learning.practice_enabled
    and learning.archived_at is null;

  insert into public.user_collections (
    user_id, knowledge_item_id, learning_item_id, state, is_liked, is_disliked
  ) values (
    max_user, source_id, learning_id,
    'saved'::public.collection_state, true, false
  )
  on conflict (user_id, knowledge_item_id) do update
  set learning_item_id = excluded.learning_item_id,
      state = 'saved'::public.collection_state,
      is_liked = true,
      is_disliked = false,
      updated_at = now();

  select count(*) into liked_count
  from public.user_collections collection
  where collection.user_id = max_user
    and collection.learning_item_id = learning_id
    and collection.state = 'saved'
    and collection.is_liked
    and not collection.is_disliked;

  if liked_count <> 1 then
    raise exception 'Expected Evidentiary to be saved and liked for Max';
  end if;
end;
$$;
