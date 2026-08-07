create or replace function public.get_learning_dashboard()
returns jsonb
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
    'overall', (
      with visible as (
        select item.id, item.default_importance, state.stability,
          state.last_review_at, state.repetitions
        from public.knowledge_items item
        left join public.user_item_learning_states state
          on state.user_id = auth.uid() and state.knowledge_item_id = item.id
        where (item.source = 'seeded' or item.owner_id = auth.uid())
          and not exists (
            select 1 from public.user_collections hidden
            where hidden.user_id = auth.uid()
              and hidden.knowledge_item_id = item.id
              and hidden.state = 'hidden'
          )
      ), scored as (
        select *,
          case when stability is null then 0 else public.fsrs_retrievability(
            stability, greatest(0, extract(epoch from (now() - last_review_at)) / 86400)
          ) end current_recall,
          case when stability is null then 0 else public.fsrs_retrievability(
            stability, greatest(0, extract(epoch from (now() - last_review_at)) / 86400) + 30
          ) end durable_recall
        from visible
      )
      select jsonb_build_object(
        'coverage', round((100 * coalesce(sum(default_importance) filter (where repetitions > 0), 0) / nullif(sum(default_importance), 0))::numeric, 1),
        'current_recall', round((100 * sum(default_importance * current_recall) / nullif(sum(default_importance), 0))::numeric, 1),
        'durable_mastery', round((100 * sum(default_importance * durable_recall) / nullif(sum(default_importance), 0))::numeric, 1),
        'total_items', count(*)::integer,
        'practised_items', count(*) filter (where repetitions > 0)::integer
      )
      from scored
    ),
    'goals', coalesce((
      select jsonb_agg(jsonb_build_object(
        'category_id', mastery.category_id,
        'category_name', category.name,
        'goal_role', mastery.goal_role,
        'goal_weight', mastery.goal_weight,
        'coverage', mastery.coverage,
        'current_recall', mastery.current_recall,
        'durable_mastery', mastery.durable_mastery,
        'total_items', mastery.total_items,
        'practised_items', mastery.practised_items
      ) order by mastery.goal_weight desc, category.sort_order)
      from public.user_category_mastery mastery
      join public.categories category on category.id = mastery.category_id
      where mastery.user_id = auth.uid()
    ), '[]'::jsonb),
    'due_count', (
      select count(*) from public.user_item_learning_states state
      where state.user_id = auth.uid() and state.next_review_at <= now()
    ),
    'reviewed_unique', (
      select count(*) from public.user_item_learning_states state where state.user_id = auth.uid()
    )
  );
$$;

revoke all on function public.get_learning_dashboard() from public, anon;
grant execute on function public.get_learning_dashboard() to authenticated;
