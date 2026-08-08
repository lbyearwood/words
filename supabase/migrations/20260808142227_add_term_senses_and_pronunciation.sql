create table public.term_families (
  id uuid primary key default gen_random_uuid(),
  normalized_term text not null,
  display_term text not null,
  is_single_word boolean generated always as (normalized_term !~ '[[:space:]]') stored,
  created_at timestamptz not null default now(),
  constraint term_families_normalized_term_not_blank check (length(normalized_term) > 0),
  constraint term_families_normalized_term_unique unique (normalized_term)
);

comment on table public.term_families is
  'Canonical written terms. Knowledge Items remain individual meanings linked to one term family.';

alter table public.term_families enable row level security;
revoke all on table public.term_families from public, anon, authenticated;

alter table public.knowledge_items
  add column term_family_id uuid references public.term_families (id) on delete restrict,
  add column part_of_speech text,
  add column pronunciation text,
  add column sense_label text,
  add column sense_order smallint;

alter table public.knowledge_items
  add constraint knowledge_items_part_of_speech_check check (
    part_of_speech is null or part_of_speech in (
      'noun', 'verb', 'adjective', 'adverb', 'pronoun', 'preposition',
      'conjunction', 'determiner', 'interjection', 'phrase', 'idiom',
      'quotation', 'other'
    )
  ),
  add constraint knowledge_items_pronunciation_not_blank check (
    pronunciation is null or length(btrim(pronunciation)) > 0
  ),
  add constraint knowledge_items_sense_label_not_blank check (
    sense_label is null or length(btrim(sense_label)) > 0
  ),
  add constraint knowledge_items_sense_order_positive check (
    sense_order is null or sense_order > 0
  );

insert into public.term_families (normalized_term, display_term)
select normalized_term, min(term) as display_term
from (
  select lower(regexp_replace(btrim(term), '[[:space:]]+', ' ', 'g')) as normalized_term,
         btrim(term) as term
  from public.knowledge_items
) terms
group by normalized_term;

with ranked_senses as (
  select item.id,
         family.id as term_family_id,
         row_number() over (
           partition by family.id
           order by lower(item.meaning), item.id
         )::smallint as sense_order
  from public.knowledge_items item
  join public.term_families family
    on family.normalized_term = lower(regexp_replace(btrim(item.term), '[[:space:]]+', ' ', 'g'))
)
update public.knowledge_items item
set term_family_id = ranked.term_family_id,
    sense_order = ranked.sense_order
from ranked_senses ranked
where ranked.id = item.id;

alter table public.knowledge_items
  alter column term_family_id set not null,
  alter column sense_order set not null;

create unique index knowledge_items_term_family_sense_order_key
  on public.knowledge_items (term_family_id, sense_order);
create unique index knowledge_items_term_family_meaning_key
  on public.knowledge_items (term_family_id, lower(btrim(meaning)));
create index knowledge_items_term_family_idx
  on public.knowledge_items (term_family_id, sense_order, id);

create or replace function private.assign_term_family()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  normalized text := lower(regexp_replace(btrim(new.term), '[[:space:]]+', ' ', 'g'));
  family_id uuid;
begin
  if normalized = '' then raise exception 'Term cannot be blank'; end if;

  insert into public.term_families (normalized_term, display_term)
  values (normalized, btrim(new.term))
  on conflict (normalized_term) do update
    set display_term = public.term_families.display_term
  returning id into family_id;

  new.term := btrim(new.term);
  if new.term_family_id is distinct from family_id then
    new.term_family_id := family_id;
    new.sense_order := null;
  end if;

  if new.sense_order is null then
    select coalesce(max(item.sense_order), 0) + 1
    into new.sense_order
    from public.knowledge_items item
    where item.term_family_id = family_id
      and item.id is distinct from new.id;
  end if;

  new.part_of_speech := nullif(lower(btrim(new.part_of_speech)), '');
  new.pronunciation := nullif(btrim(new.pronunciation), '');
  new.sense_label := nullif(btrim(new.sense_label), '');
  return new;
end;
$$;

revoke all on function private.assign_term_family() from public, anon, authenticated;

create trigger knowledge_items_assign_term_family
before insert or update of term, term_family_id, sense_order, part_of_speech, pronunciation, sense_label
on public.knowledge_items
for each row execute function private.assign_term_family();

-- Curate only facts that are unambiguous in the current starter collection.
update public.knowledge_items
set part_of_speech = 'adjective', pronunciation = 'ar-TIK-you-lut', sense_label = 'clear expression'
where lower(term) = 'articulate'
  and lower(meaning) like 'able to express ideas clearly%';

update public.knowledge_items
set part_of_speech = 'verb', pronunciation = 'co-in-SIDE', sense_label = 'happen together'
where lower(term) = 'coincide'
  and lower(meaning) like 'to happen at the same time%';

update public.knowledge_items
set part_of_speech = 'adjective', pronunciation = 'dis-CREET', sense_label = 'separate and distinct'
where lower(term) = 'discrete'
  and lower(meaning) like 'separate and distinct%';

update public.knowledge_items item
set part_of_speech = case mapping.category_id
  when 'idioms' then 'idiom'
  when 'quotes' then 'quotation'
  else 'phrase'
end
from public.knowledge_item_categories mapping
where mapping.knowledge_item_id = item.id
  and mapping.is_primary
  and mapping.category_id in ('phrases', 'quotes', 'idioms')
  and item.part_of_speech is null;

create or replace function private.practice_question_prompt(
  p_knowledge_item_id uuid,
  p_question_type public.question_type,
  p_shown_meaning text default null
)
returns text
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  item public.knowledge_items;
  family_senses integer;
  use_context boolean;
begin
  select * into item from public.knowledge_items where id = p_knowledge_item_id;
  if item.id is null then raise exception 'Knowledge Item not found'; end if;

  select count(*) into family_senses
  from public.knowledge_items sibling
  where sibling.term_family_id = item.term_family_id;
  use_context := family_senses > 1 and length(btrim(item.example_sentence)) > 0;

  if p_question_type = 'multiple_choice' then
    if use_context then
      return format('In the sentence “%s”, what does “%s” mean?', item.example_sentence, item.term);
    end if;
    if family_senses > 1 and item.part_of_speech is not null then
      return format('Which meaning matches “%s” used as a %s?', item.term, item.part_of_speech);
    end if;
    return format('Which meaning best matches “%s”?', item.term);
  end if;

  if use_context then
    return format('In the sentence “%s”, “%s” means “%s”.', item.example_sentence, item.term, p_shown_meaning);
  end if;
  if family_senses > 1 and item.part_of_speech is not null then
    return format('Used as a %s, “%s” means “%s”.', item.part_of_speech, item.term, p_shown_meaning);
  end if;
  return format('“%s” means “%s”', item.term, p_shown_meaning);
end;
$$;

revoke all on function private.practice_question_prompt(uuid, public.question_type, text)
  from public, anon, authenticated;

-- Keep one sense from a written term in each test, and make prompts context-safe
-- whenever that term has several meanings.
do $$
declare
  procedure record;
  definition text;
  updated text;
  old_selection text := $old$
  ), session as (
    select count(*)::integer eligible_count,
      least(p_requested_length, count(*)::integer) actual_count
    from weighted
  ), ranked as (
    select candidate.*, session.eligible_count, session.actual_count,
      row_number() over (partition by candidate.pool order by candidate.sample_key) pool_rank
    from weighted candidate
    cross join session
  ), chosen as (
$old$;
  new_selection text := $new$
  ), family_ranked as (
    select candidate.*,
      row_number() over (partition by candidate.term_family_id order by candidate.sample_key) family_rank
    from weighted candidate
  ), session as (
    select count(*)::integer eligible_count,
      least(p_requested_length, count(*)::integer) actual_count
    from family_ranked
    where family_rank = 1
  ), ranked as (
    select candidate.*, session.eligible_count, session.actual_count,
      row_number() over (partition by candidate.pool order by candidate.sample_key) pool_rank
    from family_ranked candidate
    cross join session
    where candidate.family_rank = 1
  ), chosen as (
$new$;
begin
  for procedure in
    select p.oid, p.proname
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('create_practice_attempt', 'create_scoped_practice_attempt')
  loop
    definition := pg_get_functiondef(procedure.oid);
    updated := replace(definition,
      'select item.id, item.owner_id,',
      'select item.id, item.term_family_id, item.owner_id,');
    updated := replace(updated,
      E'weighted as materialized (\n    select id,',
      E'weighted as materialized (\n    select id, term_family_id,');
    updated := replace(updated, old_selection, new_selection);
    updated := replace(updated,
      'format(''Which meaning best matches “%s”?'', selected.term)',
      'private.practice_question_prompt(selected.item_id, ''multiple_choice'', null)');
    updated := replace(updated,
      'format(''“%s” means “%s”'', selected.term, shown_meaning)',
      'private.practice_question_prompt(selected.item_id, ''true_false'', shown_meaning)');

    if updated = definition
      or position('term_family_id' in updated) = 0
      or position('private.practice_question_prompt' in updated) = 0 then
      raise exception 'Could not safely update % for term-family practice', procedure.proname;
    end if;
    execute updated;
  end loop;
end;
$$;

create or replace function public.create_personal_item(
  p_term text,
  p_meaning text,
  p_example_sentence text,
  p_primary_category text,
  p_difficulty public.knowledge_difficulty,
  p_secondary_categories text[] default '{}',
  p_part_of_speech text default null,
  p_pronunciation text default null,
  p_sense_label text default null
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
    term, meaning, example_sentence, difficulty, default_importance, source, owner_id,
    part_of_speech, pronunciation, sense_label
  ) values (
    trim(p_term), trim(p_meaning), trim(p_example_sentence), p_difficulty,
    0.700, 'user_added', auth.uid(), p_part_of_speech, p_pronunciation, p_sense_label
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

revoke all on function public.create_personal_item(
  text, text, text, text, public.knowledge_difficulty, text[], text, text, text
) from public, anon;
grant execute on function public.create_personal_item(
  text, text, text, text, public.knowledge_difficulty, text[], text, text, text
) to authenticated, service_role;

comment on column public.knowledge_items.term_family_id is
  'Groups separate sense-level Knowledge Items under one written term.';
comment on column public.knowledge_items.part_of_speech is
  'Curated grammatical role for this exact sense.';
comment on column public.knowledge_items.pronunciation is
  'Learner-friendly non-IPA sound-out guide; capital letters mark stress.';
comment on column public.knowledge_items.sense_label is
  'Short learner-facing label distinguishing this meaning from sibling senses.';
