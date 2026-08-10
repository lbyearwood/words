create type public.learning_item_type as enum (
  'vocabulary', 'factual', 'calculation', 'procedure',
  'interpretation', 'source_analysis', 'written_response'
);

create type public.learning_item_origin as enum ('migrated', 'curated', 'user_created');
create type public.content_qa_status as enum ('pending', 'approved', 'excluded');
create type private.content_review_decision as enum ('keep', 'rewrite', 'change_sense', 'exclude');

-- Keep an auditable, immutable record of the two collections before the v2
-- ownership model is introduced. This snapshot deliberately excludes auth
-- credentials and contains only learning content and collection preferences.
create table private.v2_collection_snapshot (
  snapshot_id uuid not null,
  captured_at timestamptz not null,
  user_id uuid not null,
  display_name text not null,
  knowledge_item_id uuid not null,
  collection_state public.collection_state not null,
  is_liked boolean not null,
  is_disliked boolean not null,
  collection_created_at timestamptz not null,
  term text not null,
  meaning text not null,
  example_sentence text not null,
  difficulty public.knowledge_difficulty not null,
  part_of_speech text,
  pronunciation text,
  sense_label text,
  categories jsonb not null,
  primary key (snapshot_id, user_id, knowledge_item_id)
);

alter table private.v2_collection_snapshot enable row level security;
revoke all on table private.v2_collection_snapshot from public, anon, authenticated;

with capture as (
  select gen_random_uuid() snapshot_id, statement_timestamp() captured_at
)
insert into private.v2_collection_snapshot (
  snapshot_id, captured_at, user_id, display_name, knowledge_item_id,
  collection_state, is_liked, is_disliked, collection_created_at,
  term, meaning, example_sentence, difficulty, part_of_speech,
  pronunciation, sense_label, categories
)
select
  capture.snapshot_id,
  capture.captured_at,
  collection.user_id,
  profile.display_name,
  collection.knowledge_item_id,
  collection.state,
  collection.is_liked,
  collection.is_disliked,
  collection.created_at,
  item.term,
  item.meaning,
  item.example_sentence,
  item.difficulty,
  item.part_of_speech,
  item.pronunciation,
  item.sense_label,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', category.id,
      'name', category.name,
      'is_primary', mapping.is_primary,
      'importance', mapping.importance
    ) order by mapping.is_primary desc, category.sort_order)
    from public.knowledge_item_categories mapping
    join public.categories category on category.id = mapping.category_id
    where mapping.knowledge_item_id = item.id
  ), '[]'::jsonb)
from capture
join public.user_collections collection on true
join public.profiles profile on profile.id = collection.user_id
join public.knowledge_items item on item.id = collection.knowledge_item_id
where lower(profile.display_name) in ('max', 'tia');

create table public.learner_plans (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  plan_name text not null check (char_length(btrim(plan_name)) between 1 and 100),
  objective text not null check (char_length(btrim(objective)) between 1 and 600),
  audience_context text not null check (char_length(btrim(audience_context)) between 1 and 600),
  curriculum_baseline text,
  locale text not null default 'en-GB',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.learner_categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  slug text not null check (slug ~ '^[a-z0-9_]+$'),
  name text not null check (char_length(btrim(name)) between 1 and 80),
  description text,
  sort_order smallint not null check (sort_order between 1 and 100),
  created_at timestamptz not null default now(),
  unique (user_id, slug),
  unique (user_id, sort_order),
  unique (id, user_id)
);

create table public.learner_term_families (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  normalized_term text not null check (char_length(btrim(normalized_term)) > 0),
  display_term text not null check (char_length(btrim(display_term)) between 1 and 160),
  created_at timestamptz not null default now(),
  unique (user_id, normalized_term),
  unique (id, user_id)
);

create table public.learning_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  item_type public.learning_item_type not null default 'vocabulary',
  source_knowledge_item_id uuid references public.knowledge_items (id) on delete restrict,
  difficulty public.knowledge_difficulty not null,
  importance numeric(4,3) not null default 0.700 check (importance between 0 and 1),
  origin public.learning_item_origin not null,
  qa_status public.content_qa_status not null default 'pending',
  practice_enabled boolean not null default false,
  content_version integer not null default 1 check (content_version > 0),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, source_knowledge_item_id),
  unique (id, user_id),
  constraint learning_items_practice_status_check check (
    not practice_enabled or qa_status <> 'excluded'
  )
);

create table public.vocabulary_items (
  learning_item_id uuid primary key,
  user_id uuid not null,
  term_family_id uuid not null,
  definition text not null check (char_length(btrim(definition)) between 1 and 600),
  example_sentence text not null check (char_length(btrim(example_sentence)) between 1 and 800),
  part_of_speech text,
  pronunciation text,
  sense_label text,
  sense_order smallint not null check (sense_order > 0),
  evidence jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (learning_item_id, user_id)
    references public.learning_items (id, user_id) on delete cascade,
  foreign key (term_family_id, user_id)
    references public.learner_term_families (id, user_id) on delete cascade,
  unique (user_id, term_family_id, sense_order),
  constraint vocabulary_items_part_of_speech_check check (
    part_of_speech is null or part_of_speech in (
      'noun', 'verb', 'adjective', 'adverb', 'pronoun', 'preposition',
      'conjunction', 'determiner', 'interjection', 'phrase', 'idiom',
      'quotation', 'other'
    )
  ),
  constraint vocabulary_items_pronunciation_not_blank check (
    pronunciation is null or char_length(btrim(pronunciation)) > 0
  )
);

create table public.learning_item_categories (
  learning_item_id uuid not null,
  learner_category_id uuid not null,
  user_id uuid not null,
  is_primary boolean not null default false,
  importance numeric(4,3) not null default 0.600 check (importance between 0 and 1),
  created_at timestamptz not null default now(),
  primary key (learning_item_id, learner_category_id),
  foreign key (learning_item_id, user_id)
    references public.learning_items (id, user_id) on delete cascade,
  foreign key (learner_category_id, user_id)
    references public.learner_categories (id, user_id) on delete cascade
);

create unique index learning_item_categories_one_primary_idx
  on public.learning_item_categories (learning_item_id) where is_primary;

create table public.learner_category_focus (
  user_id uuid not null references public.profiles (id) on delete cascade,
  learner_category_id uuid not null,
  goal_role public.category_goal_role not null,
  goal_weight numeric(4,3) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, learner_category_id),
  foreign key (learner_category_id, user_id)
    references public.learner_categories (id, user_id) on delete cascade,
  constraint learner_category_focus_weight_check check (
    (goal_role = 'primary' and goal_weight = 1.000)
    or (goal_role = 'supporting' and goal_weight = 0.600)
  )
);

create unique index learner_category_focus_one_primary_idx
  on public.learner_category_focus (user_id) where goal_role = 'primary';

create table private.content_review_records (
  learning_item_id uuid primary key references public.learning_items (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  batch_number integer,
  decision private.content_review_decision,
  reason text,
  evidence jsonb not null default '[]'::jsonb,
  before_content jsonb not null default '{}'::jsonb,
  after_content jsonb,
  drafted_at timestamptz,
  approved_at timestamptz,
  updated_at timestamptz not null default now()
);

create table private.personalised_content_manifests (
  manifest_id text primary key,
  user_id uuid not null references public.profiles (id) on delete restrict,
  batch_number integer not null check (batch_number > 0),
  content_hash text not null,
  item_count integer not null check (item_count between 1 and 50),
  applied_at timestamptz not null default now(),
  unique (user_id, batch_number),
  unique (content_hash)
);

create table private.assessment_templates (
  id uuid primary key default gen_random_uuid(),
  learning_item_id uuid not null references public.learning_items (id) on delete cascade,
  assessment_kind text not null check (assessment_kind in (
    'multiple_choice', 'true_false', 'numeric_calculation', 'short_answer',
    'procedure', 'interpretation', 'source_analysis', 'written_response'
  )),
  prompt_config jsonb not null default '{}'::jsonb,
  marking_config jsonb not null default '{}'::jsonb,
  enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (learning_item_id, assessment_kind)
);

alter table private.content_review_records enable row level security;
alter table private.assessment_templates enable row level security;
alter table private.personalised_content_manifests enable row level security;
revoke all on table private.content_review_records from public, anon, authenticated;
revoke all on table private.assessment_templates from public, anon, authenticated;
revoke all on table private.personalised_content_manifests from public, anon, authenticated;

insert into public.learner_plans (
  user_id, plan_name, objective, audience_context, curriculum_baseline
)
select id,
  case when lower(display_name) = 'max' then 'Sophisticated Speaker at Work' else 'Year 9 Learning' end,
  case when lower(display_name) = 'max'
    then 'Develop precise, confident and persuasive language for leadership at work.'
    else 'Develop general vocabulary and subject language appropriate for Year 9.' end,
  case when lower(display_name) = 'max'
    then 'Leadership, team performance, decisions, organisational change and stakeholder communication; use natural general-adult contexts when work wording would be artificial.'
    else 'Age-appropriate British English in realistic school, subject and teenage contexts.' end,
  case when lower(display_name) = 'tia' then 'England Key Stage 3, Year 9' else null end
from public.profiles
where lower(display_name) in ('max', 'tia');

insert into public.learner_categories (user_id, slug, name, sort_order)
select profile.id, category.slug, category.name, category.sort_order
from public.profiles profile
cross join lateral (
  values
    ('general_vocabulary', 'General Vocabulary', 1),
    ('sophisticated_speaker', 'Sophisticated Speaker', 2),
    ('professional_communication', 'Professional Communication', 3),
    ('leadership_management', 'Leadership & Management', 4),
    ('critical_thinking_logic', 'Critical Thinking & Logic', 5),
    ('academic_language_writing', 'Academic Language & Writing', 6),
    ('research_methods_evidence', 'Research Methods & Evidence', 7),
    ('mathematics_statistics', 'Mathematics & Statistics', 8),
    ('education_learning', 'Education & Learning', 9),
    ('social_communication', 'Social Communication', 10),
    ('business_economics', 'Business & Economics', 11),
    ('phrases', 'Phrases', 12),
    ('quotes', 'Quotes', 13),
    ('idioms', 'Idioms', 14)
) category(slug, name, sort_order)
where lower(profile.display_name) = 'max';

insert into public.learner_categories (user_id, slug, name, sort_order)
select profile.id, category.slug, category.name, category.sort_order
from public.profiles profile
cross join lateral (
  values
    ('general_vocabulary', 'General Vocabulary', 1),
    ('art', 'Art', 2),
    ('computer_science', 'Computer Science', 3),
    ('dance', 'Dance', 4),
    ('drama', 'Drama', 5),
    ('design_technology', 'Design and Technology', 6),
    ('english', 'English', 7),
    ('geography', 'Geography', 8),
    ('german', 'German', 9),
    ('history', 'History', 10),
    ('maths', 'Maths', 11),
    ('music', 'Music', 12),
    ('religious_education', 'Religious Education', 13),
    ('physical_education', 'Physical Education', 14),
    ('science', 'Science', 15)
) category(slug, name, sort_order)
where lower(profile.display_name) = 'tia';

-- A trailing parenthetical imported as a sense description is removed from the
-- title. Genuine names and abbreviations remain intact.
with source_terms as (
  select distinct
    collection.user_id,
    case
      when item.term in ('Universal Design for Learning (UDL)', 'Law of Presence (or the Now)')
        then btrim(item.term)
      when item.term ~ '[[:space:]]+\([^)]*\)$'
        then btrim(regexp_replace(item.term, '[[:space:]]+\([^)]*\)$', ''))
      else btrim(item.term)
    end as display_term
  from public.user_collections collection
  join public.profiles profile on profile.id = collection.user_id
  join public.knowledge_items item on item.id = collection.knowledge_item_id
  where lower(profile.display_name) in ('max', 'tia')
)
insert into public.learner_term_families (user_id, normalized_term, display_term)
select user_id,
  lower(regexp_replace(display_term, '[[:space:]]+', ' ', 'g')),
  min(display_term)
from source_terms
group by user_id, lower(regexp_replace(display_term, '[[:space:]]+', ' ', 'g'));

insert into public.learning_items (
  user_id, source_knowledge_item_id, difficulty, importance,
  origin, qa_status, practice_enabled
)
select
  collection.user_id,
  item.id,
  item.difficulty,
  item.default_importance,
  'migrated',
  'pending',
  false
from public.user_collections collection
join public.profiles profile on profile.id = collection.user_id
join public.knowledge_items item on item.id = collection.knowledge_item_id
where lower(profile.display_name) in ('max', 'tia');

with prepared as (
  select
    learning.id learning_item_id,
    learning.user_id,
    family.id term_family_id,
    item.meaning,
    item.example_sentence,
    item.part_of_speech,
    item.pronunciation,
    coalesce(item.sense_label,
      case
        when item.term not in ('Universal Design for Learning (UDL)', 'Law of Presence (or the Now)')
          and item.term ~ '[[:space:]]+\([^)]*\)$'
        then regexp_replace(item.term, '^.*\(([^)]*)\)$', '\1')
        else null
      end
    ) sense_label,
    row_number() over (
      partition by learning.user_id, family.id
      order by coalesce(item.sense_order, 32767), lower(item.meaning), item.id
    )::smallint sense_order,
    item.id legacy_id
  from public.learning_items learning
  join public.knowledge_items item on item.id = learning.source_knowledge_item_id
  join public.learner_term_families family
    on family.user_id = learning.user_id
   and family.normalized_term = lower(regexp_replace(
     case
       when item.term in ('Universal Design for Learning (UDL)', 'Law of Presence (or the Now)') then btrim(item.term)
       when item.term ~ '[[:space:]]+\([^)]*\)$' then btrim(regexp_replace(item.term, '[[:space:]]+\([^)]*\)$', ''))
       else btrim(item.term)
     end,
     '[[:space:]]+', ' ', 'g'
   ))
)
insert into public.vocabulary_items (
  learning_item_id, user_id, term_family_id, definition, example_sentence,
  part_of_speech, pronunciation, sense_label, sense_order, evidence
)
select learning_item_id, user_id, term_family_id, meaning, example_sentence,
  part_of_speech, pronunciation, sense_label, sense_order,
  jsonb_build_array(jsonb_build_object(
    'type', 'legacy_migration', 'knowledge_item_id', legacy_id
  ))
from prepared;

with mapped as (
  select
    learning.id learning_item_id,
    learning.user_id,
    category.id learner_category_id,
    bool_or(legacy.is_primary) is_primary,
    max(legacy.importance) importance
  from public.learning_items learning
  join public.profiles profile on profile.id = learning.user_id
  join public.knowledge_item_categories legacy
    on legacy.knowledge_item_id = learning.source_knowledge_item_id
  join public.learner_categories category
    on category.user_id = learning.user_id
   and category.slug = case
     when lower(profile.display_name) = 'max' then
       case when legacy.category_id in (
         'general_vocabulary', 'sophisticated_speaker', 'professional_communication',
         'leadership_management', 'critical_thinking_logic', 'academic_language_writing',
         'research_methods_evidence', 'mathematics_statistics', 'education_learning',
         'social_communication', 'business_economics', 'phrases', 'quotes', 'idioms'
       ) then legacy.category_id else 'general_vocabulary' end
     else
       case
         when legacy.category_id = 'mathematics_statistics' then 'maths'
         when legacy.category_id in ('biology_life_sciences', 'physics_engineering', 'health_medicine') then 'science'
         when legacy.category_id in ('academic_language_writing', 'literature_rhetoric', 'language_linguistics', 'phrases', 'quotes', 'idioms') then 'english'
         when legacy.category_id in ('beliefs_spirituality', 'philosophy_ethics') then 'religious_education'
         when legacy.category_id in ('society_politics', 'law_civic_life', 'culture_social_norms') then 'history'
         else 'general_vocabulary'
       end
   end
  group by learning.id, learning.user_id, category.id
), ranked as (
  select mapped.*,
    row_number() over (
      partition by learning_item_id
      order by is_primary desc, importance desc, learner_category_id
    ) = 1 final_primary
  from mapped
)
insert into public.learning_item_categories (
  learning_item_id, learner_category_id, user_id, is_primary, importance
)
select learning_item_id, learner_category_id, user_id, final_primary, importance
from ranked;

-- Defensive fallback for any legacy item that had no usable category mapping.
insert into public.learning_item_categories (
  learning_item_id, learner_category_id, user_id, is_primary, importance
)
select learning.id, category.id, learning.user_id, true, 0.700
from public.learning_items learning
join public.learner_categories category
  on category.user_id = learning.user_id and category.slug = 'general_vocabulary'
where not exists (
  select 1 from public.learning_item_categories mapping
  where mapping.learning_item_id = learning.id
);

insert into public.learner_category_focus (
  user_id, learner_category_id, goal_role, goal_weight
)
select profile.id, category.id,
  case when category.slug = defaults.primary_slug then 'primary'::public.category_goal_role else 'supporting'::public.category_goal_role end,
  case when category.slug = defaults.primary_slug then 1.000 else 0.600 end
from public.profiles profile
cross join lateral (
  select
    case when lower(profile.display_name) = 'max' then 'sophisticated_speaker' else 'general_vocabulary' end primary_slug,
    case when lower(profile.display_name) = 'max'
      then array['sophisticated_speaker', 'leadership_management', 'professional_communication', 'critical_thinking_logic']
      else array['general_vocabulary', 'english', 'maths', 'science']
    end selected_slugs
) defaults
join public.learner_categories category
  on category.user_id = profile.id and category.slug = any(defaults.selected_slugs)
where lower(profile.display_name) in ('max', 'tia');

create or replace function private.seed_two_learner_plan()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare learner_name text := lower(new.display_name);
begin
  if learner_name not in ('max', 'tia') then return new; end if;
  insert into public.learner_plans (
    user_id, plan_name, objective, audience_context, curriculum_baseline
  ) values (
    new.id,
    case when learner_name = 'max' then 'Sophisticated Speaker at Work' else 'Year 9 Learning' end,
    case when learner_name = 'max'
      then 'Develop precise, confident and persuasive language for leadership at work.'
      else 'Develop general vocabulary and subject language appropriate for Year 9.' end,
    case when learner_name = 'max'
      then 'Leadership, team performance, decisions, organisational change and stakeholder communication; use natural general-adult contexts when work wording would be artificial.'
      else 'Age-appropriate British English in realistic school, subject and teenage contexts.' end,
    case when learner_name = 'tia' then 'England Key Stage 3, Year 9' else null end
  ) on conflict (user_id) do nothing;

  insert into public.learner_categories (user_id, slug, name, sort_order)
  select new.id, configured.slug, configured.name, configured.sort_order
  from (
    select * from (values
      ('max', 'general_vocabulary', 'General Vocabulary', 1),
      ('max', 'sophisticated_speaker', 'Sophisticated Speaker', 2),
      ('max', 'professional_communication', 'Professional Communication', 3),
      ('max', 'leadership_management', 'Leadership & Management', 4),
      ('max', 'critical_thinking_logic', 'Critical Thinking & Logic', 5),
      ('max', 'academic_language_writing', 'Academic Language & Writing', 6),
      ('max', 'research_methods_evidence', 'Research Methods & Evidence', 7),
      ('max', 'mathematics_statistics', 'Mathematics & Statistics', 8),
      ('max', 'education_learning', 'Education & Learning', 9),
      ('max', 'social_communication', 'Social Communication', 10),
      ('max', 'business_economics', 'Business & Economics', 11),
      ('max', 'phrases', 'Phrases', 12), ('max', 'quotes', 'Quotes', 13), ('max', 'idioms', 'Idioms', 14),
      ('tia', 'general_vocabulary', 'General Vocabulary', 1), ('tia', 'art', 'Art', 2),
      ('tia', 'computer_science', 'Computer Science', 3), ('tia', 'dance', 'Dance', 4),
      ('tia', 'drama', 'Drama', 5), ('tia', 'design_technology', 'Design and Technology', 6),
      ('tia', 'english', 'English', 7), ('tia', 'geography', 'Geography', 8),
      ('tia', 'german', 'German', 9), ('tia', 'history', 'History', 10),
      ('tia', 'maths', 'Maths', 11), ('tia', 'music', 'Music', 12),
      ('tia', 'religious_education', 'Religious Education', 13),
      ('tia', 'physical_education', 'Physical Education', 14), ('tia', 'science', 'Science', 15)
    ) valueset(learner, slug, name, sort_order)
    where learner = learner_name
  ) configured
  on conflict (user_id, slug) do nothing;

  insert into public.learner_category_focus (
    user_id, learner_category_id, goal_role, goal_weight
  )
  select new.id, category.id,
    case when category.slug = case when learner_name = 'max' then 'sophisticated_speaker' else 'general_vocabulary' end
      then 'primary'::public.category_goal_role else 'supporting'::public.category_goal_role end,
    case when category.slug = case when learner_name = 'max' then 'sophisticated_speaker' else 'general_vocabulary' end
      then 1.000 else 0.600 end
  from public.learner_categories category
  where category.user_id = new.id and category.slug = any(
    case when learner_name = 'max'
      then array['sophisticated_speaker', 'leadership_management', 'professional_communication', 'critical_thinking_logic']
      else array['general_vocabulary', 'english', 'maths', 'science'] end
  ) on conflict (user_id, learner_category_id) do nothing;
  return new;
end;
$$;

revoke all on function private.seed_two_learner_plan() from public, anon, authenticated;
create trigger profiles_seed_two_learner_plan
after insert or update of display_name on public.profiles
for each row execute function private.seed_two_learner_plan();

insert into private.content_review_records (
  learning_item_id, user_id, before_content
)
select learning.id, learning.user_id,
  jsonb_build_object(
    'term', family.display_term,
    'definition', vocabulary.definition,
    'example_sentence', vocabulary.example_sentence,
    'part_of_speech', vocabulary.part_of_speech,
    'pronunciation', vocabulary.pronunciation,
    'sense_label', vocabulary.sense_label
  )
from public.learning_items learning
join public.vocabulary_items vocabulary on vocabulary.learning_item_id = learning.id
join public.learner_term_families family on family.id = vocabulary.term_family_id;

alter table public.user_collections add column learning_item_id uuid;

update public.user_collections collection
set learning_item_id = learning.id
from public.learning_items learning
where learning.user_id = collection.user_id
  and learning.source_knowledge_item_id = collection.knowledge_item_id;

alter table public.user_collections
  add constraint user_collections_learning_item_fkey
  foreign key (learning_item_id, user_id)
  references public.learning_items (id, user_id) on delete cascade;

create unique index user_collections_learning_item_key
  on public.user_collections (user_id, learning_item_id)
  where learning_item_id is not null;

-- Progress is intentionally reset. Compatibility knowledge-item columns stay
-- in place until the post-deploy cleanup migration.
delete from public.user_point_event_categories;
delete from public.user_point_events;
delete from public.user_point_totals;
delete from public.user_item_review_events;
delete from public.user_item_learning_states;
delete from public.activity_attempt_categories;
delete from public.attempt_answers;
delete from public.activity_attempts;
delete from public.user_category_goals;

alter table public.attempt_answers add column learning_item_id uuid references public.learning_items (id);
alter table public.attempt_answers add column assessment_kind text not null default 'multiple_choice';
alter table public.attempt_answers add column question_payload jsonb not null default '{}'::jsonb;
alter table public.user_item_learning_states add column learning_item_id uuid references public.learning_items (id);
alter table public.user_item_learning_states add column content_version integer not null default 1;
alter table public.user_item_review_events add column learning_item_id uuid references public.learning_items (id);
alter table public.user_item_review_events add column content_version integer not null default 1;
alter table public.user_point_events add column learning_item_id uuid references public.learning_items (id);

create unique index user_item_learning_states_learning_item_key
  on public.user_item_learning_states (user_id, learning_item_id)
  where learning_item_id is not null;
create index attempt_answers_learning_item_idx on public.attempt_answers (learning_item_id, attempt_id);
create index review_events_learning_item_idx on public.user_item_review_events (user_id, learning_item_id, reviewed_at desc);
create index point_events_learning_item_idx on public.user_point_events (user_id, learning_item_id, created_at desc);

create table public.learner_point_event_categories (
  event_id bigint not null references public.user_point_events (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  learner_category_id uuid not null,
  goal_role public.category_goal_role not null,
  goal_weight numeric(4,3) not null,
  importance numeric(4,3) not null,
  created_at timestamptz not null default now(),
  primary key (event_id, learner_category_id),
  foreign key (learner_category_id, user_id)
    references public.learner_categories (id, user_id) on delete cascade
);

create index learner_plans_user_idx on public.learner_plans (user_id);
create index learner_categories_user_sort_idx on public.learner_categories (user_id, sort_order);
create index learner_term_families_user_term_idx on public.learner_term_families (user_id, normalized_term);
create index learning_items_user_status_idx on public.learning_items (user_id, practice_enabled, qa_status, difficulty);
create index learning_items_source_idx on public.learning_items (source_knowledge_item_id, user_id);
create index vocabulary_items_user_family_idx on public.vocabulary_items (user_id, term_family_id, sense_order);
create index learning_item_categories_category_idx on public.learning_item_categories (user_id, learner_category_id, learning_item_id);
create index learner_category_focus_user_weight_idx on public.learner_category_focus (user_id, goal_weight desc);
create index learner_point_event_categories_user_idx on public.learner_point_event_categories (user_id, learner_category_id, event_id);

alter table public.learner_plans enable row level security;
alter table public.learner_categories enable row level security;
alter table public.learner_term_families enable row level security;
alter table public.learning_items enable row level security;
alter table public.vocabulary_items enable row level security;
alter table public.learning_item_categories enable row level security;
alter table public.learner_category_focus enable row level security;
alter table public.learner_point_event_categories enable row level security;

create policy learner_plans_select_own on public.learner_plans
  for select to authenticated using ((select auth.uid()) = user_id);
create policy learner_categories_select_own on public.learner_categories
  for select to authenticated using ((select auth.uid()) = user_id);
create policy learner_term_families_select_own on public.learner_term_families
  for select to authenticated using ((select auth.uid()) = user_id);
create policy learning_items_select_own on public.learning_items
  for select to authenticated using ((select auth.uid()) = user_id);
create policy vocabulary_items_select_own on public.vocabulary_items
  for select to authenticated using ((select auth.uid()) = user_id);
create policy learning_item_categories_select_own on public.learning_item_categories
  for select to authenticated using ((select auth.uid()) = user_id);
create policy learner_category_focus_select_own on public.learner_category_focus
  for select to authenticated using ((select auth.uid()) = user_id);
create policy learner_point_event_categories_select_own on public.learner_point_event_categories
  for select to authenticated using ((select auth.uid()) = user_id);

-- Learners may only see legacy rows that back one of their personalised items.
drop policy if exists "knowledge_items_select_visible" on public.knowledge_items;
create policy "knowledge_items_select_personalised"
on public.knowledge_items for select to authenticated
using (exists (
  select 1 from public.learning_items learning
  where learning.user_id = (select auth.uid())
    and learning.source_knowledge_item_id = knowledge_items.id
));

drop policy if exists "item_categories_select_visible" on public.knowledge_item_categories;
create policy "item_categories_select_personalised"
on public.knowledge_item_categories for select to authenticated
using (exists (
  select 1 from public.learning_items learning
  where learning.user_id = (select auth.uid())
    and learning.source_knowledge_item_id = knowledge_item_categories.knowledge_item_id
));

revoke all on table public.learner_plans from public, anon, authenticated;
revoke all on table public.learner_categories from public, anon, authenticated;
revoke all on table public.learner_term_families from public, anon, authenticated;
revoke all on table public.learning_items from public, anon, authenticated;
revoke all on table public.vocabulary_items from public, anon, authenticated;
revoke all on table public.learning_item_categories from public, anon, authenticated;
revoke all on table public.learner_category_focus from public, anon, authenticated;
revoke all on table public.learner_point_event_categories from public, anon, authenticated;

grant select on table public.learner_plans to authenticated;
grant select on table public.learner_categories to authenticated;
grant select on table public.learner_term_families to authenticated;
grant select on table public.learning_items to authenticated;
grant select on table public.vocabulary_items to authenticated;
grant select on table public.learning_item_categories to authenticated;
grant select on table public.learner_category_focus to authenticated;
grant select on table public.learner_point_event_categories to authenticated;

create or replace function private.v2_confidence_label(
  p_user_id uuid,
  p_learning_item_id uuid,
  p_now timestamptz default now()
)
returns text
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  learning public.learning_items;
begin
  select * into learning from public.learning_items
  where id = p_learning_item_id and user_id = p_user_id;
  if learning.id is null then return 'New'; end if;
  return private.item_confidence_label(p_user_id, learning.source_knowledge_item_id, p_now);
end;
$$;

revoke all on function private.v2_confidence_label(uuid, uuid, timestamptz)
  from public, anon, authenticated;

create or replace function private.v2_item_curriculum_value(
  p_user_id uuid,
  p_learning_item_id uuid
)
returns numeric
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  base_importance numeric;
  active_goal_count integer;
  goal_sum numeric;
  goal_relevance numeric;
  initial_value numeric;
  saved_boost numeric;
begin
  select importance into base_importance
  from public.learning_items
  where id = p_learning_item_id and user_id = p_user_id;
  if base_importance is null then return 0; end if;

  select count(*), coalesce(sum(focus.goal_weight * mapping.importance), 0)
  into active_goal_count, goal_sum
  from public.learner_category_focus focus
  left join public.learning_item_categories mapping
    on mapping.learner_category_id = focus.learner_category_id
   and mapping.learning_item_id = p_learning_item_id
  where focus.user_id = p_user_id;

  if active_goal_count > 0 then
    goal_relevance := 1 - exp(-goal_sum);
    initial_value := 0.15 * base_importance + 0.85 * goal_relevance;
  else
    initial_value := base_importance;
  end if;

  select case when exists (
    select 1 from public.user_collections collection
    where collection.user_id = p_user_id
      and collection.learning_item_id = p_learning_item_id
      and collection.state = 'saved'
  ) then 1 else 0 end into saved_boost;

  return least(1, greatest(0,
    1 - (1 - initial_value) * (1 - 0.15 * saved_boost)
  ));
end;
$$;

revoke all on function private.v2_item_curriculum_value(uuid, uuid)
  from public, anon, authenticated;

create or replace function public.get_my_learning_plan()
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
    'plan', to_jsonb(plan),
    'focus', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', focus.user_id,
        'category_id', focus.learner_category_id,
        'goal_role', focus.goal_role,
        'goal_weight', focus.goal_weight
      ) order by focus.goal_weight desc, category.sort_order)
      from public.learner_category_focus focus
      join public.learner_categories category on category.id = focus.learner_category_id
      where focus.user_id = plan.user_id
    ), '[]'::jsonb)
  )
  from public.learner_plans plan
  where plan.user_id = (select auth.uid());
$$;

create or replace function public.get_my_categories()
returns setof public.learner_categories
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select * from public.learner_categories
  where user_id = (select auth.uid())
  order by sort_order;
$$;

create or replace function private.v2_item_json(p_learning_item_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
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
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', category.id,
        'slug', category.slug,
        'name', category.name,
        'description', category.description,
        'sort_order', category.sort_order,
        'is_primary', mapping.is_primary,
        'importance', mapping.importance
      ) order by mapping.is_primary desc, category.sort_order)
      from public.learning_item_categories mapping
      join public.learner_categories category on category.id = mapping.learner_category_id
      where mapping.learning_item_id = learning.id
    ), '[]'::jsonb)
  )
  from public.learning_items learning
  join public.vocabulary_items vocabulary on vocabulary.learning_item_id = learning.id
  join public.learner_term_families family on family.id = vocabulary.term_family_id
  where learning.id = p_learning_item_id;
$$;

revoke all on function private.v2_item_json(uuid) from public, anon, authenticated;

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

  select coalesce(jsonb_agg(private.v2_item_json(filtered.id) order by filtered.display_term, filtered.sense_order), '[]'::jsonb)
  into result
  from (
    select learning.id, family.display_term, vocabulary.sense_order
    from public.learning_items learning
    join public.vocabulary_items vocabulary on vocabulary.learning_item_id = learning.id
    join public.learner_term_families family on family.id = vocabulary.term_family_id
    where learning.user_id = caller
      and learning.qa_status <> 'excluded'
      and (p_search is null or btrim(p_search) = ''
        or family.display_term ilike '%' || btrim(p_search) || '%'
        or vocabulary.definition ilike '%' || btrim(p_search) || '%')
      and (cardinality(coalesce(p_category_ids, '{}')) = 0 or exists (
        select 1 from public.learning_item_categories mapping
        where mapping.learning_item_id = learning.id
          and mapping.learner_category_id = any(p_category_ids)
      ))
    order by family.display_term, vocabulary.sense_order
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
  select jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(private.v2_item_json(learning.id) order by family.display_term, vocabulary.sense_order)
      from public.user_collections collection
      join public.learning_items learning on learning.id = collection.learning_item_id
      join public.vocabulary_items vocabulary on vocabulary.learning_item_id = learning.id
      join public.learner_term_families family on family.id = vocabulary.term_family_id
      where collection.user_id = caller and learning.qa_status <> 'excluded'
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
      join public.learning_items learning on learning.id = collection.learning_item_id
      where collection.user_id = caller and learning.qa_status <> 'excluded'
    ), '[]'::jsonb),
    'confidence', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', caller,
        'knowledge_item_id', learning.id,
        'learning_item_id', learning.id,
        'recent_answer_count', coalesce(state.repetitions, 0),
        'recent_accuracy', case when state.repetitions is null then 0 when state.last_answer_correct then 1 else 0 end,
        'confidence_status', private.v2_confidence_label(caller, learning.id),
        'stability', state.stability,
        'next_review_at', state.next_review_at
      ))
      from public.user_collections collection
      join public.learning_items learning on learning.id = collection.learning_item_id
      left join public.user_item_learning_states state
        on state.user_id = caller and state.learning_item_id = learning.id
      where collection.user_id = caller and learning.qa_status <> 'excluded'
    ), '[]'::jsonb)
  ) into result;
  return result;
end;
$$;

drop function if exists public.set_category_goals(text, text[]);

create function public.set_category_goals(
  primary_category_id text,
  supporting_category_ids text[] default '{}'
)
returns setof public.learner_category_focus
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller uuid := auth.uid();
  primary_uuid uuid;
  support_uuids uuid[];
begin
  if caller is null then raise exception 'Authentication required'; end if;
  begin
    primary_uuid := primary_category_id::uuid;
    select coalesce(array_agg(distinct value::uuid), '{}') into support_uuids
    from unnest(coalesce(supporting_category_ids, '{}')) value
    where value <> primary_category_id;
  exception when invalid_text_representation then
    raise exception 'Choose valid categories';
  end;
  if cardinality(support_uuids) > 3 then raise exception 'Choose up to three supporting goals'; end if;
  if not exists (
    select 1 from public.learner_categories where id = primary_uuid and user_id = caller
  ) or exists (
    select 1 from unnest(support_uuids) value
    where not exists (select 1 from public.learner_categories where id = value and user_id = caller)
  ) then raise exception 'Choose categories from your learning plan'; end if;

  delete from public.learner_category_focus where user_id = caller;
  insert into public.learner_category_focus (user_id, learner_category_id, goal_role, goal_weight)
  values (caller, primary_uuid, 'primary', 1.000);
  insert into public.learner_category_focus (user_id, learner_category_id, goal_role, goal_weight)
  select caller, value, 'supporting', 0.600 from unnest(support_uuids) value;
  return query select * from public.learner_category_focus where user_id = caller
    order by goal_weight desc, learner_category_id;
end;
$$;

create or replace function public.clear_category_goals()
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  delete from public.learner_category_focus where user_id = auth.uid();
end;
$$;

create or replace function public.set_learning_item_preference(
  p_learning_item_id uuid,
  p_saved boolean default null,
  p_liked boolean default null,
  p_disliked boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller uuid := auth.uid();
  learning public.learning_items;
  collection public.user_collections;
  next_saved boolean;
  next_liked boolean;
  next_disliked boolean;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  select * into learning from public.learning_items
  where id = p_learning_item_id and user_id = caller and qa_status <> 'excluded';
  if learning.id is null then raise exception 'Learning item not found'; end if;

  select * into collection from public.user_collections
  where user_id = caller and learning_item_id = learning.id for update;
  next_saved := coalesce(p_saved, collection.state = 'saved', false);
  next_liked := coalesce(p_liked, collection.is_liked, false);
  next_disliked := coalesce(p_disliked, collection.is_disliked, false);
  if next_liked then next_saved := true; next_disliked := false; end if;
  if next_disliked then next_liked := false; end if;

  if not next_saved and not next_liked and not next_disliked then
    delete from public.user_collections where user_id = caller and learning_item_id = learning.id;
    return null;
  end if;

  insert into public.user_collections (
    user_id, knowledge_item_id, learning_item_id, state, is_liked, is_disliked
  ) values (
    caller, learning.source_knowledge_item_id, learning.id,
    case when next_saved then 'saved' else 'preference' end,
    next_liked, next_disliked
  ) on conflict (user_id, knowledge_item_id) do update set
    learning_item_id = excluded.learning_item_id,
    state = excluded.state,
    is_liked = excluded.is_liked,
    is_disliked = excluded.is_disliked,
    updated_at = now()
  returning * into collection;
  return jsonb_build_object(
    'user_id', collection.user_id,
    'knowledge_item_id', collection.learning_item_id,
    'learning_item_id', collection.learning_item_id,
    'state', collection.state,
    'is_liked', collection.is_liked,
    'is_disliked', collection.is_disliked,
    'created_at', collection.created_at,
    'updated_at', collection.updated_at
  );
end;
$$;

create or replace function public.create_personal_vocabulary_item(
  p_term text,
  p_definition text,
  p_example_sentence text,
  p_primary_category_id uuid,
  p_difficulty public.knowledge_difficulty,
  p_secondary_category_ids uuid[] default '{}',
  p_part_of_speech text default null,
  p_pronunciation text default null,
  p_sense_label text default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller uuid := auth.uid();
  normalized text := lower(regexp_replace(btrim(p_term), '[[:space:]]+', ' ', 'g'));
  legacy_item_id uuid;
  family_id uuid;
  learning_id uuid;
  legacy_category text := 'general_vocabulary';
  next_sense_order smallint;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  if char_length(btrim(p_term)) not between 1 and 160
    or char_length(btrim(p_definition)) not between 1 and 600
    or char_length(btrim(p_example_sentence)) not between 1 and 800
  then raise exception 'Complete the term, definition and example'; end if;
  if normalized !~ '[[:space:]]' and nullif(btrim(p_pronunciation), '') is null then
    raise exception 'Sound it out is required for a single word';
  end if;
  if p_part_of_speech is null then raise exception 'Choose a part of speech'; end if;
  if not exists (
    select 1 from public.learner_categories where id = p_primary_category_id and user_id = caller
  ) or exists (
    select 1 from unnest(coalesce(p_secondary_category_ids, '{}')) category_id
    where not exists (select 1 from public.learner_categories where id = category_id and user_id = caller)
  ) then raise exception 'Choose categories from your learning plan'; end if;

  select category.slug into legacy_category
  from public.learner_categories category
  join public.categories legacy on legacy.id = category.slug
  where category.id = p_primary_category_id and category.user_id = caller;
  legacy_category := coalesce(legacy_category, 'general_vocabulary');

  insert into public.knowledge_items (
    term, meaning, example_sentence, difficulty, default_importance, source, owner_id,
    part_of_speech, pronunciation, sense_label
  ) values (
    btrim(p_term), btrim(p_definition), btrim(p_example_sentence), p_difficulty,
    0.700, 'user_added', caller, lower(btrim(p_part_of_speech)),
    nullif(btrim(p_pronunciation), ''), nullif(btrim(p_sense_label), '')
  ) returning id into legacy_item_id;

  insert into public.knowledge_item_categories (
    knowledge_item_id, category_id, is_primary, importance
  ) values (legacy_item_id, legacy_category, true, 0.800);

  insert into public.learner_term_families (user_id, normalized_term, display_term)
  values (caller, normalized, btrim(p_term))
  on conflict (user_id, normalized_term) do update
    set display_term = public.learner_term_families.display_term
  returning id into family_id;

  select (coalesce(max(sense_order), 0) + 1)::smallint into next_sense_order
  from public.vocabulary_items where user_id = caller and term_family_id = family_id;

  insert into public.learning_items (
    user_id, source_knowledge_item_id, difficulty, importance,
    origin, qa_status, practice_enabled
  ) values (
    caller, legacy_item_id, p_difficulty, 0.700,
    'user_created', 'pending', true
  ) returning id into learning_id;

  insert into public.vocabulary_items (
    learning_item_id, user_id, term_family_id, definition, example_sentence,
    part_of_speech, pronunciation, sense_label, sense_order,
    evidence
  ) values (
    learning_id, caller, family_id, btrim(p_definition), btrim(p_example_sentence),
    lower(btrim(p_part_of_speech)), nullif(btrim(p_pronunciation), ''),
    nullif(btrim(p_sense_label), ''), next_sense_order,
    jsonb_build_array(jsonb_build_object('type', 'learner_submission'))
  );

  insert into public.learning_item_categories (
    learning_item_id, learner_category_id, user_id, is_primary, importance
  ) values (learning_id, p_primary_category_id, caller, true, 0.800);
  insert into public.learning_item_categories (
    learning_item_id, learner_category_id, user_id, is_primary, importance
  )
  select learning_id, category_id, caller, false, 0.600
  from (select distinct unnest(coalesce(p_secondary_category_ids, '{}')) category_id) selected
  where category_id <> p_primary_category_id;

  insert into public.user_collections (
    user_id, knowledge_item_id, learning_item_id, state
  ) values (caller, legacy_item_id, learning_id, 'saved');

  insert into private.content_review_records (
    learning_item_id, user_id, before_content
  ) values (
    learning_id, caller,
    jsonb_build_object(
      'term', btrim(p_term), 'definition', btrim(p_definition),
      'example_sentence', btrim(p_example_sentence),
      'part_of_speech', lower(btrim(p_part_of_speech)),
      'pronunciation', nullif(btrim(p_pronunciation), ''),
      'sense_label', nullif(btrim(p_sense_label), '')
    )
  );
  return learning_id;
end;
$$;

-- Database-owner-only batch application. Manifests are deterministic, capped
-- at 50 items and recorded by hash so rerunning the same batch is harmless.
create or replace function private.apply_personalised_content_manifest(p_manifest jsonb)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_manifest_id text := nullif(btrim(p_manifest->>'manifest_id'), '');
  learner_id uuid;
  batch_number integer;
  manifest_hash text := md5(p_manifest::text);
  item_count integer;
  entry jsonb;
  learning public.learning_items;
  vocabulary public.vocabulary_items;
  family public.learner_term_families;
  v_decision private.content_review_decision;
  material_change boolean;
  primary_count integer;
begin
  if v_manifest_id is null then raise exception 'manifest_id is required'; end if;
  begin
    learner_id := (p_manifest->>'user_id')::uuid;
    batch_number := (p_manifest->>'batch_number')::integer;
  exception when invalid_text_representation then
    raise exception 'The manifest learner and batch are invalid';
  end;
  if jsonb_typeof(p_manifest->'items') <> 'array' then raise exception 'items must be an array'; end if;
  item_count := jsonb_array_length(p_manifest->'items');
  if item_count not between 1 and 50 then raise exception 'A batch must contain 1 to 50 items'; end if;
  if exists (select 1 from private.personalised_content_manifests applied where applied.manifest_id = v_manifest_id) then
    if exists (
      select 1 from private.personalised_content_manifests applied
      where applied.manifest_id = v_manifest_id and applied.content_hash = manifest_hash
    ) then return jsonb_build_object('manifest_id', v_manifest_id, 'applied', false, 'item_count', item_count); end if;
    raise exception 'That manifest ID was already used for different content';
  end if;

  for entry in select value from jsonb_array_elements(p_manifest->'items')
  loop
    select * into learning from public.learning_items
    where id = (entry->>'learning_item_id')::uuid and user_id = learner_id for update;
    if learning.id is null then raise exception 'A learning item does not belong to this learner'; end if;
    select * into vocabulary from public.vocabulary_items where learning_item_id = learning.id;
    select * into family from public.learner_term_families where id = vocabulary.term_family_id;
    v_decision := (entry->>'decision')::private.content_review_decision;

    if v_decision = 'exclude' then
      update public.learning_items set qa_status = 'excluded', practice_enabled = false,
        archived_at = now(), updated_at = now() where id = learning.id;
      update private.content_review_records set decision = v_decision,
        reason = nullif(btrim(entry->>'reason'), ''), evidence = coalesce(entry->'evidence', '[]'::jsonb),
        approved_at = now(), updated_at = now() where learning_item_id = learning.id;
      continue;
    end if;

    if nullif(btrim(entry->>'term'), '') is null
      or nullif(btrim(entry->>'definition'), '') is null
      or nullif(btrim(entry->>'example_sentence'), '') is null
      or nullif(btrim(entry->>'part_of_speech'), '') is null
    then raise exception 'Approved vocabulary needs a term, definition, example and part of speech'; end if;
    if lower(entry->>'example_sentence') like '%most precise term for the idea%'
      or lower(entry->>'example_sentence') like '%describe a different word%'
    then raise exception 'Placeholder examples cannot be approved'; end if;
    if btrim(entry->>'term') ~ '[[:space:]]+\([^)]*\)$'
      and coalesce((entry->>'title_parentheses_approved')::boolean, false) is false
    then raise exception 'Parenthetical titles need explicit approval'; end if;
    if btrim(entry->>'term') !~ '[[:space:]]'
      and nullif(btrim(entry->>'pronunciation'), '') is null
    then raise exception 'Single words need a recognisable pronunciation'; end if;

    select count(*) filter (where is_primary) into primary_count
    from jsonb_to_recordset(coalesce(entry->'categories', '[]'::jsonb))
      as category(category_id uuid, is_primary boolean, importance numeric);
    if primary_count <> 1 then raise exception 'Each item needs exactly one primary category'; end if;
    if exists (
      select 1
      from jsonb_to_recordset(coalesce(entry->'categories', '[]'::jsonb))
        as category(category_id uuid, is_primary boolean, importance numeric)
      where category.importance not between 0 and 1
        or not exists (select 1 from public.learner_categories owned
          where owned.id = category.category_id and owned.user_id = learner_id)
    ) then raise exception 'A category is invalid for this learner'; end if;

    material_change := family.display_term is distinct from btrim(entry->>'term')
      or vocabulary.definition is distinct from btrim(entry->>'definition')
      or vocabulary.part_of_speech is distinct from lower(btrim(entry->>'part_of_speech'))
      or vocabulary.pronunciation is distinct from nullif(btrim(entry->>'pronunciation'), '')
      or vocabulary.sense_label is distinct from nullif(btrim(entry->>'sense_label'), '');

    update public.learner_term_families set
      display_term = btrim(entry->>'term'),
      normalized_term = lower(regexp_replace(btrim(entry->>'term'), '[[:space:]]+', ' ', 'g'))
    where id = family.id;
    update public.vocabulary_items set
      definition = btrim(entry->>'definition'),
      example_sentence = btrim(entry->>'example_sentence'),
      part_of_speech = lower(btrim(entry->>'part_of_speech')),
      pronunciation = nullif(btrim(entry->>'pronunciation'), ''),
      sense_label = nullif(btrim(entry->>'sense_label'), ''),
      evidence = coalesce(entry->'evidence', '[]'::jsonb), updated_at = now()
    where learning_item_id = learning.id;
    update public.learning_items set
      difficulty = (entry->>'difficulty')::public.knowledge_difficulty,
      importance = (entry->>'importance')::numeric,
      qa_status = 'approved', practice_enabled = true, archived_at = null,
      content_version = content_version + case when material_change then 1 else 0 end,
      updated_at = now()
    where id = learning.id;

    delete from public.learning_item_categories where learning_item_id = learning.id;
    insert into public.learning_item_categories (
      learning_item_id, learner_category_id, user_id, is_primary, importance
    )
    select learning.id, category.category_id, learner_id, category.is_primary, category.importance
    from jsonb_to_recordset(entry->'categories')
      as category(category_id uuid, is_primary boolean, importance numeric);

    update public.knowledge_items set term = btrim(entry->>'term'),
      meaning = btrim(entry->>'definition'), example_sentence = btrim(entry->>'example_sentence'),
      part_of_speech = lower(btrim(entry->>'part_of_speech')),
      pronunciation = nullif(btrim(entry->>'pronunciation'), ''),
      sense_label = nullif(btrim(entry->>'sense_label'), ''),
      difficulty = (entry->>'difficulty')::public.knowledge_difficulty,
      default_importance = (entry->>'importance')::numeric
    where id = learning.source_knowledge_item_id;

    if material_change then
      delete from public.user_item_learning_states
      where user_id = learner_id and learning_item_id = learning.id;
    end if;
    update private.content_review_records set decision = v_decision,
      reason = nullif(btrim(entry->>'reason'), ''), evidence = coalesce(entry->'evidence', '[]'::jsonb),
      after_content = entry, approved_at = now(), updated_at = now()
    where learning_item_id = learning.id;
  end loop;

  insert into private.personalised_content_manifests (
    manifest_id, user_id, batch_number, content_hash, item_count
  ) values (v_manifest_id, learner_id, batch_number, manifest_hash, item_count);
  return jsonb_build_object('manifest_id', v_manifest_id, 'applied', true, 'item_count', item_count);
end;
$$;

revoke all on function private.apply_personalised_content_manifest(jsonb)
  from public, anon, authenticated;

revoke all on function public.get_my_learning_plan() from public, anon;
revoke all on function public.get_my_categories() from public, anon;
revoke all on function public.get_my_library(text, uuid[], integer, integer) from public, anon;
revoke all on function public.get_my_collection() from public, anon;
revoke all on function public.set_category_goals(text, text[]) from public, anon;
revoke all on function public.clear_category_goals() from public, anon;
revoke all on function public.set_learning_item_preference(uuid, boolean, boolean, boolean) from public, anon;
revoke all on function public.create_personal_vocabulary_item(
  text, text, text, uuid, public.knowledge_difficulty, uuid[], text, text, text
) from public, anon;

grant execute on function public.get_my_learning_plan() to authenticated;
grant execute on function public.get_my_categories() to authenticated;
grant execute on function public.get_my_library(text, uuid[], integer, integer) to authenticated;
grant execute on function public.get_my_collection() to authenticated;
grant execute on function public.set_category_goals(text, text[]) to authenticated;
grant execute on function public.clear_category_goals() to authenticated;
grant execute on function public.set_learning_item_preference(uuid, boolean, boolean, boolean) to authenticated;
grant execute on function public.create_personal_vocabulary_item(
  text, text, text, uuid, public.knowledge_difficulty, uuid[], text, text, text
) to authenticated;
