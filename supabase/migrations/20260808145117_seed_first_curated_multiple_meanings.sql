-- Split previously combined definitions while retaining the established sense's
-- Knowledge Item id, reviews, progress, likes, and collection history.
update public.knowledge_items
set meaning = 'To happen at the same time.'
where lower(term) = 'coincide'
  and meaning = 'To happen at the same time or agree exactly.';

with source_item as (
  select * from public.knowledge_items
  where lower(term) = 'coincide'
    and meaning = 'To happen at the same time.'
  order by id
  limit 1
), inserted as (
  insert into public.knowledge_items (
    term, meaning, example_sentence, difficulty, source, owner_id,
    default_importance, part_of_speech, pronunciation, sense_label
  )
  select source_item.term,
         'To agree or match exactly.',
         'Their accounts coincide on every important detail.',
         source_item.difficulty,
         source_item.source,
         source_item.owner_id,
         source_item.default_importance,
         'verb',
         'co-in-SIDE',
         'agree or match'
  from source_item
  where not exists (
    select 1 from public.knowledge_items existing
    where existing.term_family_id = source_item.term_family_id
      and lower(existing.meaning) = 'to agree or match exactly.'
  )
  returning id
), new_item as (
  select id from inserted
  union all
  select existing.id
  from public.knowledge_items existing
  join source_item on source_item.term_family_id = existing.term_family_id
  where lower(existing.meaning) = 'to agree or match exactly.'
  limit 1
)
insert into public.knowledge_item_categories (
  knowledge_item_id, category_id, is_primary, importance
)
select new_item.id, mapping.category_id, mapping.is_primary, mapping.importance
from new_item
cross join source_item
join public.knowledge_item_categories mapping
  on mapping.knowledge_item_id = source_item.id
on conflict (knowledge_item_id, category_id) do nothing;

with source_item as (
  select * from public.knowledge_items
  where lower(term) = 'coincide'
    and meaning = 'To happen at the same time.'
  order by id
  limit 1
), new_item as (
  select existing.id
  from public.knowledge_items existing
  join source_item on source_item.term_family_id = existing.term_family_id
  where lower(existing.meaning) = 'to agree or match exactly.'
  limit 1
)
insert into public.user_collections (
  user_id, knowledge_item_id, state, is_liked, is_disliked, created_at, updated_at
)
select collection.user_id, new_item.id, collection.state,
       collection.is_liked, collection.is_disliked,
       collection.created_at, now()
from source_item
cross join new_item
join public.user_collections collection
  on collection.knowledge_item_id = source_item.id
on conflict (user_id, knowledge_item_id) do nothing;

with source_item as (
  select * from public.knowledge_items
  where lower(term) = 'articulate'
    and lower(meaning) = 'able to express ideas clearly and effectively.'
  order by id
  limit 1
), inserted as (
  insert into public.knowledge_items (
    term, meaning, example_sentence, difficulty, source, owner_id,
    default_importance, part_of_speech, pronunciation, sense_label
  )
  select source_item.term,
         'To pronounce words or express thoughts clearly.',
         'She articulated each point carefully so everyone could follow.',
         'intermediate',
         source_item.source,
         source_item.owner_id,
         source_item.default_importance,
         'verb',
         'ar-TIK-you-late',
         'express or pronounce clearly'
  from source_item
  where not exists (
    select 1 from public.knowledge_items existing
    where existing.term_family_id = source_item.term_family_id
      and lower(existing.meaning) = 'to pronounce words or express thoughts clearly.'
  )
  returning id
), new_item as (
  select id from inserted
  union all
  select existing.id
  from public.knowledge_items existing
  join source_item on source_item.term_family_id = existing.term_family_id
  where lower(existing.meaning) = 'to pronounce words or express thoughts clearly.'
  limit 1
)
insert into public.knowledge_item_categories (
  knowledge_item_id, category_id, is_primary, importance
)
select new_item.id, mapping.category_id, mapping.is_primary, mapping.importance
from new_item
cross join source_item
join public.knowledge_item_categories mapping
  on mapping.knowledge_item_id = source_item.id
on conflict (knowledge_item_id, category_id) do nothing;

with source_item as (
  select * from public.knowledge_items
  where lower(term) = 'articulate'
    and lower(meaning) = 'able to express ideas clearly and effectively.'
  order by id
  limit 1
), new_item as (
  select existing.id
  from public.knowledge_items existing
  join source_item on source_item.term_family_id = existing.term_family_id
  where lower(existing.meaning) = 'to pronounce words or express thoughts clearly.'
  limit 1
)
insert into public.user_collections (
  user_id, knowledge_item_id, state, is_liked, is_disliked, created_at, updated_at
)
select collection.user_id, new_item.id, collection.state,
       collection.is_liked, collection.is_disliked,
       collection.created_at, now()
from source_item
cross join new_item
join public.user_collections collection
  on collection.knowledge_item_id = source_item.id
on conflict (user_id, knowledge_item_id) do nothing;
