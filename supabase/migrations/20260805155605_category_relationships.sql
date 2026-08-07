create table public.categories (
  id text primary key check (id ~ '^[a-z0-9_]+$'),
  name text not null unique check (char_length(trim(name)) between 1 and 80),
  description text,
  sort_order smallint not null unique check (sort_order between 1 and 24),
  created_at timestamptz not null default now()
);

insert into public.categories (id, name, description, sort_order)
values
  ('general_vocabulary', 'General Vocabulary', null, 1),
  ('critical_thinking_logic', 'Critical Thinking & Logic', null, 2),
  ('academic_language_writing', 'Academic Language & Writing', null, 3),
  ('professional_communication', 'Professional Communication', null, 4),
  ('education_learning', 'Education & Learning', null, 5),
  ('research_methods_evidence', 'Research Methods & Evidence', null, 6),
  ('social_communication', 'Social Communication', null, 7),
  ('beliefs_spirituality', 'Beliefs & Spirituality', null, 8),
  ('biology_life_sciences', 'Biology & Life Sciences', null, 9),
  ('emotions_relationships', 'Emotions & Relationships', null, 10),
  ('philosophy_ethics', 'Philosophy & Ethics', null, 11),
  ('mathematics_statistics', 'Mathematics & Statistics', null, 12),
  ('health_medicine', 'Health & Medicine', null, 13),
  ('psychology_behaviour', 'Psychology & Behaviour', null, 14),
  ('law_civic_life', 'Law & Civic Life', null, 15),
  ('culture_social_norms', 'Culture & Social Norms', null, 16),
  ('literature_rhetoric', 'Literature & Rhetoric', null, 17),
  ('society_politics', 'Society & Politics', null, 18),
  ('language_linguistics', 'Language & Linguistics', null, 19),
  ('physics_engineering', 'Physics & Engineering', null, 20),
  ('personal_development_wellbeing', 'Personal Development & Wellbeing', null, 21),
  ('business_economics', 'Business & Economics', null, 22),
  (
    'sophisticated_speaker',
    'Sophisticated Speaker',
    'Precise, confident and persuasive language for polished general conversation without specialist terminology.',
    23
  ),
  (
    'leadership_management',
    'Leadership & Management',
    'Broadly useful language for leading people, decisions, performance and organisational direction.',
    24
  );

create table public.knowledge_item_categories (
  knowledge_item_id uuid not null references public.knowledge_items (id) on delete cascade,
  category_id text not null references public.categories (id) on delete restrict,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (knowledge_item_id, category_id)
);

create unique index knowledge_item_categories_one_primary_idx
  on public.knowledge_item_categories (knowledge_item_id)
  where is_primary;

create index knowledge_item_categories_category_idx
  on public.knowledge_item_categories (category_id, knowledge_item_id);

-- Every existing item receives a safe primary mapping before the legacy field is removed.
insert into public.knowledge_item_categories (knowledge_item_id, category_id, is_primary)
select
  item.id,
  case item.category
    when 'everyday_communication' then 'social_communication'
    when 'school_subjects' then 'education_learning'
    when 'work' then 'professional_communication'
    when 'idioms_phrases' then 'general_vocabulary'
    when 'quotes' then 'literature_rhetoric'
  end,
  true
from public.knowledge_items item;

create function private.remap_starter_categories()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  delete from public.knowledge_item_categories mapping
  using public.knowledge_items item
  where item.id = mapping.knowledge_item_id
    and item.source = 'seeded';

  with primary_categories(term, category_id) as (
    values
      ('Articulate', 'sophisticated_speaker'),
      ('Candid', 'social_communication'),
      ('Concise', 'sophisticated_speaker'),
      ('Empathetic', 'emotions_relationships'),
      ('Clarify', 'sophisticated_speaker'),
      ('Assertive', 'social_communication'),
      ('Attentive', 'social_communication'),
      ('Considerate', 'social_communication'),
      ('Deliberate', 'critical_thinking_logic'),
      ('Perceptive', 'critical_thinking_logic'),
      ('Nuanced', 'sophisticated_speaker'),
      ('Pragmatic', 'critical_thinking_logic'),
      ('Resilient', 'personal_development_wellbeing'),
      ('Tactful', 'social_communication'),
      ('Validate', 'emotions_relationships'),
      ('Hypothesis', 'research_methods_evidence'),
      ('Analyse', 'critical_thinking_logic'),
      ('Evidence', 'research_methods_evidence'),
      ('Context', 'academic_language_writing'),
      ('Infer', 'critical_thinking_logic'),
      ('Coherent', 'academic_language_writing'),
      ('Contrast', 'academic_language_writing'),
      ('Evaluate', 'critical_thinking_logic'),
      ('Methodology', 'research_methods_evidence'),
      ('Synthesis', 'academic_language_writing'),
      ('Corroborate', 'research_methods_evidence'),
      ('Empirical', 'research_methods_evidence'),
      ('Extrapolate', 'mathematics_statistics'),
      ('Paradigm', 'academic_language_writing'),
      ('Ubiquitous', 'general_vocabulary'),
      ('Agenda', 'professional_communication'),
      ('Collaborate', 'professional_communication'),
      ('Deadline', 'professional_communication'),
      ('Feedback', 'professional_communication'),
      ('Prioritise', 'leadership_management'),
      ('Accountable', 'leadership_management'),
      ('Delegate', 'leadership_management'),
      ('Efficient', 'professional_communication'),
      ('Initiative', 'leadership_management'),
      ('Stakeholder', 'professional_communication'),
      ('Consensus', 'leadership_management'),
      ('Contingency', 'leadership_management'),
      ('Facilitate', 'leadership_management'),
      ('Mitigate', 'professional_communication'),
      ('Strategic', 'leadership_management'),
      ('Break the ice', 'general_vocabulary'),
      ('On the same page', 'general_vocabulary'),
      ('Hit the nail on the head', 'general_vocabulary'),
      ('Once in a blue moon', 'general_vocabulary'),
      ('Under the weather', 'general_vocabulary'),
      ('A blessing in disguise', 'general_vocabulary'),
      ('Cut to the chase', 'general_vocabulary'),
      ('Get the ball rolling', 'general_vocabulary'),
      ('In the long run', 'general_vocabulary'),
      ('Think outside the box', 'general_vocabulary'),
      ('Bite the bullet', 'general_vocabulary'),
      ('Read between the lines', 'general_vocabulary'),
      ('The tip of the iceberg', 'general_vocabulary'),
      ('Throw in the towel', 'general_vocabulary'),
      ('Weather the storm', 'general_vocabulary'),
      ('Knowledge is power', 'education_learning'),
      ('Practice makes progress', 'personal_development_wellbeing'),
      ('Actions speak louder than words', 'philosophy_ethics'),
      ('The only way out is through', 'personal_development_wellbeing'),
      ('Small steps add up', 'personal_development_wellbeing'),
      ('Fortune favours the bold', 'personal_development_wellbeing'),
      ('Less is more', 'philosophy_ethics'),
      ('Time is the wisest counsellor', 'philosophy_ethics'),
      ('Well begun is half done', 'personal_development_wellbeing'),
      ('What we think, we become', 'psychology_behaviour'),
      ('The unexamined life is not worth living', 'philosophy_ethics'),
      ('In the middle of difficulty lies opportunity', 'personal_development_wellbeing'),
      ('No wind favours the sailor who has no port', 'leadership_management'),
      ('We are what we repeatedly do', 'psychology_behaviour'),
      ('The journey of a thousand miles begins with one step', 'personal_development_wellbeing')
  )
  insert into public.knowledge_item_categories (knowledge_item_id, category_id, is_primary)
  select item.id, mapping.category_id, true
  from public.knowledge_items item
  join primary_categories mapping on mapping.term = item.term
  where item.source = 'seeded';

  with secondary_categories(term, category_id) as (
    values
      ('Articulate', 'professional_communication'), ('Articulate', 'leadership_management'),
      ('Candid', 'sophisticated_speaker'), ('Candid', 'professional_communication'),
      ('Concise', 'professional_communication'), ('Concise', 'academic_language_writing'),
      ('Empathetic', 'social_communication'), ('Empathetic', 'leadership_management'),
      ('Clarify', 'professional_communication'), ('Clarify', 'social_communication'),
      ('Assertive', 'sophisticated_speaker'), ('Assertive', 'leadership_management'),
      ('Attentive', 'emotions_relationships'), ('Attentive', 'leadership_management'),
      ('Considerate', 'emotions_relationships'),
      ('Deliberate', 'sophisticated_speaker'),
      ('Perceptive', 'social_communication'), ('Perceptive', 'sophisticated_speaker'),
      ('Nuanced', 'critical_thinking_logic'), ('Nuanced', 'academic_language_writing'),
      ('Pragmatic', 'professional_communication'), ('Pragmatic', 'leadership_management'),
      ('Resilient', 'psychology_behaviour'),
      ('Tactful', 'sophisticated_speaker'), ('Tactful', 'professional_communication'), ('Tactful', 'leadership_management'),
      ('Validate', 'social_communication'), ('Validate', 'psychology_behaviour'),
      ('Hypothesis', 'education_learning'),
      ('Analyse', 'academic_language_writing'), ('Analyse', 'education_learning'),
      ('Evidence', 'critical_thinking_logic'), ('Evidence', 'academic_language_writing'),
      ('Context', 'critical_thinking_logic'),
      ('Infer', 'research_methods_evidence'), ('Infer', 'academic_language_writing'),
      ('Coherent', 'sophisticated_speaker'),
      ('Contrast', 'critical_thinking_logic'),
      ('Evaluate', 'academic_language_writing'), ('Evaluate', 'research_methods_evidence'),
      ('Methodology', 'academic_language_writing'),
      ('Synthesis', 'critical_thinking_logic'),
      ('Corroborate', 'law_civic_life'), ('Corroborate', 'academic_language_writing'),
      ('Empirical', 'critical_thinking_logic'),
      ('Extrapolate', 'research_methods_evidence'), ('Extrapolate', 'critical_thinking_logic'),
      ('Paradigm', 'philosophy_ethics'), ('Paradigm', 'research_methods_evidence'),
      ('Ubiquitous', 'sophisticated_speaker'),
      ('Collaborate', 'leadership_management'),
      ('Feedback', 'leadership_management'),
      ('Prioritise', 'professional_communication'),
      ('Accountable', 'professional_communication'),
      ('Delegate', 'professional_communication'),
      ('Efficient', 'leadership_management'),
      ('Initiative', 'personal_development_wellbeing'),
      ('Stakeholder', 'business_economics'), ('Stakeholder', 'leadership_management'),
      ('Consensus', 'professional_communication'), ('Consensus', 'sophisticated_speaker'),
      ('Contingency', 'professional_communication'), ('Contingency', 'critical_thinking_logic'),
      ('Facilitate', 'professional_communication'), ('Facilitate', 'sophisticated_speaker'),
      ('Mitigate', 'critical_thinking_logic'), ('Mitigate', 'sophisticated_speaker'),
      ('Strategic', 'professional_communication'), ('Strategic', 'business_economics'),
      ('Break the ice', 'social_communication'),
      ('On the same page', 'social_communication'), ('On the same page', 'professional_communication'),
      ('Hit the nail on the head', 'social_communication'), ('Hit the nail on the head', 'sophisticated_speaker'),
      ('Once in a blue moon', 'social_communication'),
      ('Under the weather', 'social_communication'), ('Under the weather', 'health_medicine'),
      ('A blessing in disguise', 'social_communication'),
      ('Cut to the chase', 'social_communication'), ('Cut to the chase', 'sophisticated_speaker'), ('Cut to the chase', 'professional_communication'),
      ('Get the ball rolling', 'social_communication'), ('Get the ball rolling', 'professional_communication'),
      ('In the long run', 'social_communication'),
      ('Think outside the box', 'critical_thinking_logic'), ('Think outside the box', 'professional_communication'),
      ('Bite the bullet', 'personal_development_wellbeing'), ('Bite the bullet', 'social_communication'),
      ('Read between the lines', 'critical_thinking_logic'), ('Read between the lines', 'sophisticated_speaker'),
      ('The tip of the iceberg', 'social_communication'), ('The tip of the iceberg', 'critical_thinking_logic'),
      ('Throw in the towel', 'personal_development_wellbeing'), ('Throw in the towel', 'social_communication'),
      ('Weather the storm', 'personal_development_wellbeing'), ('Weather the storm', 'business_economics'),
      ('Knowledge is power', 'philosophy_ethics'), ('Knowledge is power', 'literature_rhetoric'),
      ('Practice makes progress', 'education_learning'), ('Practice makes progress', 'literature_rhetoric'),
      ('Actions speak louder than words', 'social_communication'), ('Actions speak louder than words', 'literature_rhetoric'),
      ('The only way out is through', 'psychology_behaviour'), ('The only way out is through', 'literature_rhetoric'),
      ('Small steps add up', 'literature_rhetoric'),
      ('Fortune favours the bold', 'leadership_management'), ('Fortune favours the bold', 'literature_rhetoric'),
      ('Less is more', 'culture_social_norms'), ('Less is more', 'literature_rhetoric'),
      ('Time is the wisest counsellor', 'literature_rhetoric'),
      ('Well begun is half done', 'literature_rhetoric'),
      ('What we think, we become', 'personal_development_wellbeing'), ('What we think, we become', 'literature_rhetoric'),
      ('The unexamined life is not worth living', 'literature_rhetoric'),
      ('In the middle of difficulty lies opportunity', 'literature_rhetoric'),
      ('No wind favours the sailor who has no port', 'personal_development_wellbeing'), ('No wind favours the sailor who has no port', 'literature_rhetoric'),
      ('We are what we repeatedly do', 'personal_development_wellbeing'), ('We are what we repeatedly do', 'literature_rhetoric'),
      ('The journey of a thousand miles begins with one step', 'literature_rhetoric')
  )
  insert into public.knowledge_item_categories (knowledge_item_id, category_id, is_primary)
  select item.id, mapping.category_id, false
  from public.knowledge_items item
  join secondary_categories mapping on mapping.term = item.term
  where item.source = 'seeded'
  on conflict (knowledge_item_id, category_id) do nothing;
end;
$$;

revoke all on function private.remap_starter_categories() from public, anon, authenticated;
select private.remap_starter_categories();

alter table public.profiles
  add column interested_category_ids text[] not null default '{}';

update public.profiles profile
set interested_category_ids = coalesce(
  (
    select array_agg(distinct mapped.category_id order by mapped.category_id)
    from unnest(profile.interested_categories) old_category
    cross join lateral (
      values (
        case old_category
          when 'everyday_communication' then 'social_communication'
          when 'school_subjects' then 'education_learning'
          when 'work' then 'professional_communication'
          when 'idioms_phrases' then 'general_vocabulary'
          when 'quotes' then 'literature_rhetoric'
        end
      )
    ) mapped(category_id)
  ),
  '{}'
);

alter table public.profiles drop column interested_categories;
alter table public.profiles rename column interested_category_ids to interested_categories;

alter table public.activity_attempts drop constraint attempt_category_source_check;
alter table public.activity_attempts add column category_id text references public.categories (id);

update public.activity_attempts
set category_id = case category
  when 'everyday_communication' then 'social_communication'
  when 'school_subjects' then 'education_learning'
  when 'work' then 'professional_communication'
  when 'idioms_phrases' then 'general_vocabulary'
  when 'quotes' then 'literature_rhetoric'
end
where category is not null;

alter table public.activity_attempts drop column category;
alter table public.activity_attempts add constraint attempt_category_source_check check (
  (source = 'category' and category_id is not null)
  or (source <> 'category' and category_id is null)
);

drop index public.knowledge_items_browse_idx;
alter table public.knowledge_items drop column category;
create index knowledge_items_browse_idx
  on public.knowledge_items (source, difficulty, lower(term));

drop function public.create_personal_item(
  text, text, text, public.knowledge_category, public.knowledge_difficulty
);
drop type public.knowledge_category;

create function public.create_personal_item(
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
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not exists (select 1 from public.categories where id = p_primary_category) then
    raise exception 'Unknown primary category: %', p_primary_category;
  end if;

  if exists (
    select 1
    from unnest(coalesce(p_secondary_categories, '{}')) secondary(category_id)
    left join public.categories category on category.id = secondary.category_id
    where category.id is null
  ) then
    raise exception 'One or more secondary categories are unknown';
  end if;

  insert into public.knowledge_items (
    term, meaning, example_sentence, difficulty, source, owner_id
  ) values (
    trim(p_term), trim(p_meaning), trim(p_example_sentence),
    p_difficulty, 'user_added', auth.uid()
  ) returning id into created_item_id;

  insert into public.knowledge_item_categories (
    knowledge_item_id, category_id, is_primary
  ) values (
    created_item_id, p_primary_category, true
  );

  insert into public.knowledge_item_categories (
    knowledge_item_id, category_id, is_primary
  )
  select created_item_id, secondary.category_id, false
  from (
    select distinct unnest(coalesce(p_secondary_categories, '{}')) as category_id
  ) secondary
  where secondary.category_id <> p_primary_category;

  insert into public.user_collections (user_id, knowledge_item_id, state)
  values (auth.uid(), created_item_id, 'saved');

  return created_item_id;
end;
$$;

alter table public.categories enable row level security;
alter table public.knowledge_item_categories enable row level security;

create policy "categories_select_authenticated"
on public.categories for select to authenticated
using (true);

create policy "item_categories_select_visible"
on public.knowledge_item_categories for select to authenticated
using (
  exists (
    select 1
    from public.knowledge_items item
    where item.id = knowledge_item_id
      and (item.source = 'seeded' or item.owner_id = (select auth.uid()))
  )
);

create policy "item_categories_insert_owned"
on public.knowledge_item_categories for insert to authenticated
with check (
  exists (
    select 1
    from public.knowledge_items item
    where item.id = knowledge_item_id
      and item.source = 'user_added'
      and item.owner_id = (select auth.uid())
  )
);

create policy "item_categories_update_owned"
on public.knowledge_item_categories for update to authenticated
using (
  exists (
    select 1
    from public.knowledge_items item
    where item.id = knowledge_item_id
      and item.source = 'user_added'
      and item.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.knowledge_items item
    where item.id = knowledge_item_id
      and item.source = 'user_added'
      and item.owner_id = (select auth.uid())
  )
);

create policy "item_categories_delete_owned"
on public.knowledge_item_categories for delete to authenticated
using (
  exists (
    select 1
    from public.knowledge_items item
    where item.id = knowledge_item_id
      and item.source = 'user_added'
      and item.owner_id = (select auth.uid())
  )
);

revoke all on public.categories from anon, authenticated;
revoke all on public.knowledge_item_categories from anon, authenticated;
grant select on public.categories to authenticated;
grant select, insert, update, delete on public.knowledge_item_categories to authenticated;
grant all privileges on public.categories to service_role;
grant all privileges on public.knowledge_item_categories to service_role;
revoke all on function public.create_personal_item(
  text, text, text, text, public.knowledge_difficulty, text[]
) from public, anon;
grant execute on function public.create_personal_item(
  text, text, text, text, public.knowledge_difficulty, text[]
) to authenticated;
