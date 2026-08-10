-- Keep the distractor ORDER BY/LIMIT scoped to its SELECT within the UNION,
-- and use ASCII quotation marks so practice prompts cannot regress to
-- mojibake when migrations are replayed in different encodings.
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
    E'union\n          select distractor.definition',
    E'union\n          (select distractor.definition'
  );
  function_definition := pg_catalog.replace(
    function_definition,
    E'          limit 3\n        ) option_set',
    E'          limit 3)\n        ) option_set'
  );
  function_definition := pg_catalog.replace(
    function_definition,
    'Which meaning best matches â€œ%sâ€?',
    'Which meaning best matches "%s"?'
  );
  function_definition := pg_catalog.replace(
    function_definition,
    'â€œ%sâ€ means â€œ%sâ€.',
    '"%s" means "%s".'
  );

  execute function_definition;
end;
$migration$;
