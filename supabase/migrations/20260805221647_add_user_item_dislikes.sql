alter table public.user_collections
  add column if not exists is_disliked boolean not null default false;

alter table public.user_collections
  add constraint user_collections_liked_disliked_exclusive
  check (not (is_liked and is_disliked));

update public.user_collections
set state = 'preference',
    is_liked = false,
    is_disliked = true
where state = 'hidden';

create index user_collections_disliked_idx
  on public.user_collections (user_id, knowledge_item_id)
  where is_disliked;

comment on column public.user_collections.is_disliked is
  'Marks a Knowledge Item as disliked without hiding it or requiring it to be saved in My Collection.';
