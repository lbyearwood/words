-- This Supabase-managed event-trigger helper is invoked by PostgreSQL itself.
-- It is not part of the learner-facing RPC surface. The helper is present on
-- hosted Supabase projects but is not created by every local CLI runtime, so a
-- clean local migration replay must treat it as optional.
do $$
begin
  if pg_catalog.to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke all on function public.rls_auto_enable() from public, anon, authenticated';
  end if;
end;
$$;
