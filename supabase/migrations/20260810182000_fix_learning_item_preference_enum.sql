-- CASE expressions resolve their text branches as text. Cast both outcomes to
-- collection_state so preference changes can insert or upsert enum values.
do $migration$
declare
  function_definition text;
  old_state_expression text := $old$case when next_saved then 'saved' else 'preference' end$old$;
  new_state_expression text := $new$case
      when next_saved then 'saved'::public.collection_state
      else 'preference'::public.collection_state
    end$new$;
begin
  select pg_catalog.pg_get_functiondef(
    'public.set_learning_item_preference(uuid,boolean,boolean,boolean)'::regprocedure
  ) into function_definition;

  function_definition := pg_catalog.replace(function_definition, E'\r\n', E'\n');

  if pg_catalog.strpos(function_definition, old_state_expression) = 0 then
    raise exception 'Unable to patch learning-item preference enum expression';
  end if;

  execute pg_catalog.replace(
    function_definition,
    old_state_expression,
    new_state_expression
  );
end;
$migration$;

revoke all on function public.set_learning_item_preference(
  uuid, boolean, boolean, boolean
) from public, anon;
grant execute on function public.set_learning_item_preference(
  uuid, boolean, boolean, boolean
) to authenticated, service_role;
