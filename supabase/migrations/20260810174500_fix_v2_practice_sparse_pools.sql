-- Multiple-choice questions require at least one distinct learner-owned
-- distractor. Fall back to true/false for very small curricula instead of
-- creating an invalid one-option answer.
do $migration$
declare
  function_definition text;
begin
  select pg_catalog.pg_get_functiondef(
    'private.create_v2_practice_attempt(public.practice_source,integer,text[],uuid,uuid[],text)'::regprocedure
  )
  into function_definition;

  function_definition := pg_catalog.replace(
    function_definition,
    'if mod(position_index, 2) = 1 then',
    $condition$if mod(position_index, 2) = 1 and exists (
      select 1
      from public.learning_items possible_distractor
      join public.vocabulary_items possible_vocabulary
        on possible_vocabulary.learning_item_id = possible_distractor.id
      where possible_distractor.user_id = caller
        and possible_distractor.id <> selected.learning_item_id
        and possible_distractor.practice_enabled
        and (possible_distractor.qa_status = 'approved' or possible_distractor.origin = 'user_created')
        and possible_vocabulary.definition <> selected.meaning
    ) then$condition$
  );

  execute function_definition;
end;
$migration$;
