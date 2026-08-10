-- Hosted pg_get_functiondef uses CRLF while local Postgres uses LF. Apply the
-- distractor scoping fix for either representation and normalise both prompt
-- literals using encoding-independent patterns.
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
    E'union\r\n          select distractor.definition',
    E'union\r\n          (select distractor.definition'
  );
  function_definition := pg_catalog.replace(
    function_definition,
    E'          limit 3\r\n        ) option_set',
    E'          limit 3)\r\n        ) option_set'
  );
  function_definition := pg_catalog.regexp_replace(
    function_definition,
    'Which meaning best matches [^'']+',
    'Which meaning best matches "%s"?'
  );
  function_definition := pg_catalog.regexp_replace(
    function_definition,
    '[^'']*%s[^'']*means[^'']*%s[^'']*',
    '"%s" means "%s".'
  );

  execute function_definition;
end;
$migration$;
