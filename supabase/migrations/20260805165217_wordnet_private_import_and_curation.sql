alter table public.categories
  drop constraint categories_sort_order_check;

alter table public.categories
  add constraint categories_sort_order_check
  check (sort_order between 1 and 25);

insert into public.categories (id, name, description, sort_order)
values (
  'miscellaneous',
  'Miscellaneous',
  'Learner-suitable words that do not naturally fit another approved category. Reviewed after curation for possible taxonomy improvements.',
  25
);

create type private.wordnet_import_status as enum (
  'importing',
  'ready',
  'failed'
);

create type private.wordnet_curation_status as enum (
  'unreviewed',
  'drafted',
  'approved',
  'excluded',
  'needs_review'
);

create type private.wordnet_batch_status as enum (
  'pending',
  'in_progress',
  'quality_check',
  'completed',
  'failed'
);

create table private.wordnet_releases (
  id bigint generated always as identity primary key,
  edition text not null unique check (char_length(trim(edition)) between 1 and 80),
  source_url text not null,
  archive_sha256 text not null check (archive_sha256 ~ '^[0-9a-f]{64}$'),
  license_name text not null,
  license_url text not null,
  status private.wordnet_import_status not null default 'importing',
  expected_counts jsonb not null default '{}'::jsonb,
  imported_counts jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint wordnet_release_completion_check check (
    (status = 'ready' and completed_at is not null)
    or status <> 'ready'
  )
);

create table private.wordnet_synsets (
  release_id bigint not null references private.wordnet_releases (id) on delete cascade,
  synset_id text not null check (synset_id ~ '^[0-9]{8}-[nvars]$'),
  part_of_speech text not null check (part_of_speech in ('n', 'v', 'a', 'r', 's')),
  lexicographer_file text not null,
  definitions text[] not null check (cardinality(definitions) > 0),
  members text[] not null check (cardinality(members) > 0),
  ili text,
  wikidata text,
  raw_metadata jsonb not null,
  created_at timestamptz not null default now(),
  primary key (release_id, synset_id)
);

create table private.wordnet_examples (
  release_id bigint not null,
  synset_id text not null,
  position smallint not null check (position > 0),
  example_text text not null check (char_length(trim(example_text)) > 0),
  primary key (release_id, synset_id, position),
  foreign key (release_id, synset_id)
    references private.wordnet_synsets (release_id, synset_id) on delete cascade
);

create table private.wordnet_entries (
  release_id bigint not null references private.wordnet_releases (id) on delete cascade,
  lemma text not null check (char_length(trim(lemma)) > 0),
  part_of_speech text not null check (part_of_speech in ('n', 'v', 'a', 'r', 's')),
  raw_metadata jsonb not null,
  created_at timestamptz not null default now(),
  primary key (release_id, lemma, part_of_speech)
);

create table private.wordnet_pronunciations (
  release_id bigint not null,
  lemma text not null,
  part_of_speech text not null,
  position smallint not null check (position > 0),
  pronunciation text not null check (char_length(trim(pronunciation)) > 0),
  variety text,
  raw_metadata jsonb not null,
  primary key (release_id, lemma, part_of_speech, position),
  foreign key (release_id, lemma, part_of_speech)
    references private.wordnet_entries (release_id, lemma, part_of_speech) on delete cascade
);

create table private.wordnet_senses (
  release_id bigint not null,
  sense_key text not null check (char_length(trim(sense_key)) > 0),
  lemma text not null,
  part_of_speech text not null,
  synset_id text not null,
  raw_metadata jsonb not null,
  created_at timestamptz not null default now(),
  primary key (release_id, sense_key),
  unique (release_id, sense_key, synset_id),
  foreign key (release_id, lemma, part_of_speech)
    references private.wordnet_entries (release_id, lemma, part_of_speech) on delete cascade,
  foreign key (release_id, synset_id)
    references private.wordnet_synsets (release_id, synset_id) on delete cascade
);

create table private.wordnet_synset_relations (
  release_id bigint not null,
  source_synset_id text not null,
  relation_type text not null check (relation_type ~ '^[a-z][a-z0-9_]*$'),
  target_synset_id text not null,
  primary key (release_id, source_synset_id, relation_type, target_synset_id),
  foreign key (release_id, source_synset_id)
    references private.wordnet_synsets (release_id, synset_id) on delete cascade,
  foreign key (release_id, target_synset_id)
    references private.wordnet_synsets (release_id, synset_id) on delete cascade
);

create table private.wordnet_sense_relations (
  release_id bigint not null,
  source_sense_key text not null,
  relation_type text not null check (relation_type ~ '^[a-z][a-z0-9_]*$'),
  target_sense_key text not null,
  primary key (release_id, source_sense_key, relation_type, target_sense_key),
  foreign key (release_id, source_sense_key)
    references private.wordnet_senses (release_id, sense_key) on delete cascade,
  foreign key (release_id, target_sense_key)
    references private.wordnet_senses (release_id, sense_key) on delete cascade
);

create table private.wordnet_frames (
  release_id bigint not null references private.wordnet_releases (id) on delete cascade,
  frame_id text not null,
  template text not null check (char_length(trim(template)) > 0),
  primary key (release_id, frame_id)
);

create table private.wordnet_curation_batches (
  release_id bigint not null references private.wordnet_releases (id) on delete cascade,
  batch_number integer not null check (batch_number > 0),
  first_synset_id text not null,
  last_synset_id text not null,
  item_count smallint not null check (item_count between 1 and 100),
  status private.wordnet_batch_status not null default 'pending',
  started_at timestamptz,
  completed_at timestamptz,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (release_id, batch_number),
  foreign key (release_id, first_synset_id)
    references private.wordnet_synsets (release_id, synset_id),
  foreign key (release_id, last_synset_id)
    references private.wordnet_synsets (release_id, synset_id),
  constraint wordnet_batch_completion_check check (
    (status = 'completed' and completed_at is not null)
    or status <> 'completed'
  )
);

create table private.wordnet_curation_records (
  release_id bigint not null,
  synset_id text not null,
  batch_number integer not null,
  status private.wordnet_curation_status not null default 'unreviewed',
  source_sense_key text,
  learner_title text,
  plain_english_definition text,
  natural_example text,
  preferred_term text,
  difficulty public.knowledge_difficulty,
  decision_reason text,
  qa_evidence jsonb not null default '{}'::jsonb,
  approved_knowledge_item_id uuid unique references public.knowledge_items (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (release_id, synset_id),
  foreign key (release_id, synset_id)
    references private.wordnet_synsets (release_id, synset_id) on delete cascade,
  foreign key (release_id, batch_number)
    references private.wordnet_curation_batches (release_id, batch_number) on delete restrict,
  foreign key (release_id, source_sense_key, synset_id)
    references private.wordnet_senses (release_id, sense_key, synset_id),
  constraint wordnet_curation_approved_check check (
    status <> 'approved'
    or (
      approved_knowledge_item_id is not null
      and learner_title is not null
      and plain_english_definition is not null
      and natural_example is not null
      and preferred_term is not null
      and difficulty is not null
    )
  ),
  constraint wordnet_curation_excluded_check check (
    status <> 'excluded' or char_length(trim(decision_reason)) > 0
  )
);

create table private.wordnet_curation_categories (
  release_id bigint not null,
  synset_id text not null,
  category_id text not null references public.categories (id) on delete restrict,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (release_id, synset_id, category_id),
  foreign key (release_id, synset_id)
    references private.wordnet_curation_records (release_id, synset_id) on delete cascade
);

create table private.knowledge_item_regional_variants (
  knowledge_item_id uuid not null references public.knowledge_items (id) on delete cascade,
  variant text not null check (char_length(trim(variant)) between 1 and 160),
  region_code text not null check (region_code ~ '^[a-z]{2}(-[A-Z]{2})?$'),
  is_preferred boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (knowledge_item_id, variant, region_code)
);

create unique index wordnet_curation_one_primary_category_idx
  on private.wordnet_curation_categories (release_id, synset_id)
  where is_primary;

create unique index knowledge_item_one_preferred_variant_idx
  on private.knowledge_item_regional_variants (knowledge_item_id)
  where is_preferred;

create index wordnet_entries_lemma_ci_prefix_idx
  on private.wordnet_entries (release_id, lower(lemma) text_pattern_ops);

create index wordnet_senses_synset_idx
  on private.wordnet_senses (release_id, synset_id, sense_key);

create index wordnet_synset_relations_target_idx
  on private.wordnet_synset_relations (release_id, target_synset_id, relation_type);

create index wordnet_sense_relations_target_idx
  on private.wordnet_sense_relations (release_id, target_sense_key, relation_type);

create index wordnet_curation_queue_idx
  on private.wordnet_curation_records (release_id, status, batch_number, synset_id);

create index wordnet_curation_approved_category_idx
  on private.wordnet_curation_categories (category_id, release_id, synset_id);

create trigger wordnet_releases_set_updated_at
before update on private.wordnet_releases
for each row execute function private.set_updated_at();

create trigger wordnet_curation_batches_set_updated_at
before update on private.wordnet_curation_batches
for each row execute function private.set_updated_at();

create trigger wordnet_curation_records_set_updated_at
before update on private.wordnet_curation_records
for each row execute function private.set_updated_at();

alter table private.wordnet_releases enable row level security;
alter table private.wordnet_synsets enable row level security;
alter table private.wordnet_examples enable row level security;
alter table private.wordnet_entries enable row level security;
alter table private.wordnet_pronunciations enable row level security;
alter table private.wordnet_senses enable row level security;
alter table private.wordnet_synset_relations enable row level security;
alter table private.wordnet_sense_relations enable row level security;
alter table private.wordnet_frames enable row level security;
alter table private.wordnet_curation_batches enable row level security;
alter table private.wordnet_curation_records enable row level security;
alter table private.wordnet_curation_categories enable row level security;
alter table private.knowledge_item_regional_variants enable row level security;

revoke all on all tables in schema private from public, anon, authenticated;
revoke all on all sequences in schema private from public, anon, authenticated;
revoke all on all functions in schema private from public, anon, authenticated;

grant usage on schema private to service_role;
grant all privileges on all tables in schema private to service_role;
grant all privileges on all sequences in schema private to service_role;

alter default privileges for role postgres in schema private
  revoke all on tables from public, anon, authenticated;
alter default privileges for role postgres in schema private
  revoke all on sequences from public, anon, authenticated;
alter default privileges for role postgres in schema private
  revoke execute on functions from public, anon, authenticated;
