-- PL/pgSQL exposes the function output parameter `actual_count` as a variable.
-- Qualify the identically named ranked CTE column so recommended-practice
-- quota selection works consistently on clean and hosted databases.
do $migration$
declare
  function_definition text;
begin
  select pg_catalog.pg_get_functiondef(
    'private.create_v2_practice_attempt(public.practice_source,integer,text[],uuid,uuid[],text)'::regprocedure
  )
  into function_definition;

  if pg_catalog.strpos(function_definition, 'ceil(actual_count *') > 0 then
    function_definition := pg_catalog.replace(
      function_definition,
      'ceil(actual_count *',
      'ceil(ranked.actual_count *'
    );
    execute function_definition;
  end if;
end;
$migration$;
