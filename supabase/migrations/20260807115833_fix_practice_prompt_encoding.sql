do $migration$
declare
  function_record record;
  function_definition text;
  broken_open_quote text := convert_from(decode('c3a2e282acc593', 'hex'), 'UTF8');
  broken_close_quote text := convert_from(decode('c3a2e282acc29d', 'hex'), 'UTF8');
begin
  for function_record in
    select procedure.oid
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in ('create_practice_attempt', 'create_scoped_practice_attempt')
  loop
    function_definition := pg_get_functiondef(function_record.oid);
    function_definition := replace(function_definition, broken_open_quote, chr(8220));
    function_definition := replace(function_definition, broken_close_quote, chr(8221));
    execute function_definition;
  end loop;

  update public.attempt_answers
  set prompt = replace(
    replace(prompt, broken_open_quote, chr(8220)),
    broken_close_quote,
    chr(8221)
  )
  where prompt like '%' || chr(226) || '%';
end;
$migration$;

comment on function public.create_practice_attempt(
  public.practice_source, integer, text[], uuid
) is 'Creates a practice attempt with correctly encoded learner-facing question prompts.';

comment on function public.create_scoped_practice_attempt(
  public.practice_source, integer, text[], uuid, uuid[]
) is 'Creates a scoped practice attempt with correctly encoded learner-facing question prompts.';
