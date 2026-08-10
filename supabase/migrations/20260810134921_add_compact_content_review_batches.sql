-- Build a complete, auditable personalised-content manifest from a compact
-- curator batch. Every item still receives an explicit decision and part of
-- speech; omitted content fields retain the current learner-owned wording.
create or replace function private.apply_compact_content_review_batch(p_batch jsonb)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  learner_id uuid;
  compact_item_count integer;
  full_manifest jsonb;
begin
  if nullif(btrim(p_batch->>'manifest_id'), '') is null then
    raise exception 'manifest_id is required';
  end if;

  begin
    learner_id := (p_batch->>'user_id')::uuid;
  exception when invalid_text_representation then
    raise exception 'The batch learner is invalid';
  end;

  if jsonb_typeof(p_batch->'items') <> 'array' then
    raise exception 'items must be an array';
  end if;
  compact_item_count := jsonb_array_length(p_batch->'items');
  if compact_item_count not between 1 and 50 then
    raise exception 'A batch must contain 1 to 50 items';
  end if;
  if (select count(distinct (entry->>'learning_item_id'))
      from jsonb_array_elements(p_batch->'items') entry) <> compact_item_count then
    raise exception 'A batch cannot contain the same item twice';
  end if;

  select jsonb_build_object(
    'manifest_id', p_batch->>'manifest_id',
    'user_id', learner_id,
    'batch_number', (p_batch->>'batch_number')::integer,
    'items', jsonb_agg(
      jsonb_build_object(
        'learning_item_id', learning.id,
        'decision', coalesce(nullif(entry->>'decision', ''), 'keep'),
        'reason', coalesce(nullif(entry->>'reason', ''), 'Reviewed against the learner plan and approved.'),
        'term', coalesce(nullif(btrim(entry->>'term'), ''), family.display_term),
        'definition', coalesce(nullif(btrim(entry->>'definition'), ''), vocabulary.definition),
        'example_sentence', coalesce(nullif(btrim(entry->>'example_sentence'), ''), vocabulary.example_sentence),
        'part_of_speech', coalesce(nullif(lower(btrim(entry->>'part_of_speech')), ''), vocabulary.part_of_speech),
        'pronunciation', case
          when entry ? 'pronunciation' then nullif(btrim(entry->>'pronunciation'), '')
          else vocabulary.pronunciation
        end,
        'sense_label', case
          when entry ? 'sense_label' then nullif(btrim(entry->>'sense_label'), '')
          else vocabulary.sense_label
        end,
        'difficulty', coalesce(nullif(entry->>'difficulty', ''), learning.difficulty::text),
        'importance', coalesce((entry->>'importance')::numeric, learning.importance),
        'categories', coalesce(entry->'categories', (
          select jsonb_agg(jsonb_build_object(
            'category_id', mapping.learner_category_id,
            'is_primary', mapping.is_primary,
            'importance', mapping.importance
          ) order by mapping.is_primary desc, category.sort_order)
          from public.learning_item_categories mapping
          join public.learner_categories category on category.id = mapping.learner_category_id
          where mapping.learning_item_id = learning.id
        )),
        'evidence', coalesce(entry->'evidence', jsonb_build_array(jsonb_build_object(
          'type', 'learner_fit',
          'note', 'Definition, example, metadata and categories were reviewed for this learner.'
        ))),
        'title_parentheses_approved', coalesce((entry->>'title_parentheses_approved')::boolean, false)
      ) order by ordinality
    )
  ) into full_manifest
  from jsonb_array_elements(p_batch->'items') with ordinality compact(entry, ordinality)
  join public.learning_items learning
    on learning.id = (entry->>'learning_item_id')::uuid
   and learning.user_id = learner_id
  join public.vocabulary_items vocabulary on vocabulary.learning_item_id = learning.id
  join public.learner_term_families family on family.id = vocabulary.term_family_id;

  if jsonb_array_length(full_manifest->'items') <> compact_item_count then
    raise exception 'A learning item does not belong to this learner';
  end if;

  return private.apply_personalised_content_manifest(full_manifest);
end;
$$;

revoke all on function private.apply_compact_content_review_batch(jsonb)
  from public, anon, authenticated;
