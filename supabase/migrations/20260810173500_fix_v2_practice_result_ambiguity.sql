-- The table-returning function also exposes `eligible_count` and
-- `actual_count` as PL/pgSQL variables. Qualify the aggregate inputs from the
-- chosen CTE to prevent ambiguity when an attempt is generated.
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
    'max(eligible_count)',
    'max(chosen.eligible_count)'
  );
  function_definition := pg_catalog.replace(
    function_definition,
    'max(actual_count)',
    'max(chosen.actual_count)'
  );

  execute function_definition;
end;
$migration$;
