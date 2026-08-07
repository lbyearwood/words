-- Keep target attribution tied to the goals captured when the attempt was created.
-- This prevents a later goal change from rewriting the meaning of historical points.
create or replace function private.snapshot_point_event_categories(
  p_event_id bigint,
  p_user_id uuid,
  p_knowledge_item_id uuid
)
returns void
language sql
security invoker
set search_path = pg_catalog, public
as $$
  insert into public.user_point_event_categories (
    event_id, user_id, category_id, goal_role, goal_weight, importance
  )
  select
    p_event_id,
    p_user_id,
    goal.category_id,
    goal.role,
    goal.weight,
    mapping.importance
  from public.user_point_events event
  join public.activity_attempts attempt on attempt.id = event.attempt_id
  cross join lateral jsonb_to_recordset(attempt.goal_snapshot) as goal(
    category_id text,
    role public.category_goal_role,
    weight numeric
  )
  join public.knowledge_item_categories mapping
    on mapping.category_id = goal.category_id
   and mapping.knowledge_item_id = p_knowledge_item_id
  where event.id = p_event_id
    and event.user_id = p_user_id
  on conflict (event_id, category_id) do nothing;
$$;

revoke all on function private.snapshot_point_event_categories(bigint, uuid, uuid)
from public, anon, authenticated;

comment on function private.snapshot_point_event_categories(bigint, uuid, uuid) is
  'Snapshots target attribution from the immutable attempt goal snapshot.';
