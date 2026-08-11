-- Give every learner-owned vocabulary question its display pronunciation without
-- exposing the unanswered correct response.

create or replace function public.get_practice_attempt(p_attempt_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  caller uuid := auth.uid();
  result jsonb;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  if not exists (
    select 1 from public.activity_attempts where id = p_attempt_id and user_id = caller
  ) then raise exception 'Attempt not found'; end if;

  select jsonb_build_object(
    'attempt', to_jsonb(attempt),
    'points', jsonb_build_object(
      'answer_points', coalesce((select sum(points) from public.user_point_events where attempt_id = attempt.id and event_type = 'answer'), 0),
      'recovery_points', coalesce((select sum(points) from public.user_point_events where attempt_id = attempt.id and event_type = 'recovery'), 0),
      'completion_points', coalesce((select sum(points) from public.user_point_events where attempt_id = attempt.id and event_type = 'completion'), 0),
      'grade_points', coalesce((select sum(points) from public.user_point_events where attempt_id = attempt.id and event_type = 'grade'), 0),
      'total_points', attempt.points_earned,
      'system_version', attempt.point_system_version
    ),
    'answers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', answer.id, 'attempt_id', answer.attempt_id, 'user_id', answer.user_id,
        'knowledge_item_id', answer.learning_item_id,
        'learning_item_id', answer.learning_item_id,
        'position', answer.position, 'question_type', answer.question_type,
        'prompt', answer.prompt, 'options', answer.options,
        'correct_answer', case when answer.answered_at is not null or attempt.status = 'completed' then answer.correct_answer else null end,
        'selected_answer', answer.selected_answer, 'is_correct', answer.is_correct,
        'answered_at', answer.answered_at, 'term', family.display_term,
        'pronunciation', vocabulary.pronunciation,
        'meaning', vocabulary.definition, 'example_sentence', vocabulary.example_sentence,
        'points_earned', coalesce((select sum(points) from public.user_point_events event
          where event.answer_id = answer.id and event.event_type in ('answer', 'recovery')), 0)
      ) order by answer.position)
      from public.attempt_answers answer
      join public.learning_items learning on learning.id = answer.learning_item_id
      join public.vocabulary_items vocabulary on vocabulary.learning_item_id = learning.id
      join public.learner_term_families family on family.id = vocabulary.term_family_id
      where answer.attempt_id = attempt.id
        and answer.user_id = caller
        and learning.user_id = caller
    ), '[]'::jsonb)
  ) into result
  from public.activity_attempts attempt
  where attempt.id = p_attempt_id and attempt.user_id = caller;
  return result;
end;
$$;

revoke all on function public.get_practice_attempt(uuid) from public, anon;
grant execute on function public.get_practice_attempt(uuid) to authenticated;
