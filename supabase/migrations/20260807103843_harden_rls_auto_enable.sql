-- This Supabase-managed event-trigger helper is invoked by PostgreSQL itself.
-- It is not part of the learner-facing RPC surface.
revoke all on function public.rls_auto_enable() from public, anon, authenticated;
