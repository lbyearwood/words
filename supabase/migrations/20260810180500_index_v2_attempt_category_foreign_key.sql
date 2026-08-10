-- Match the composite attempt ownership foreign key column order so Postgres
-- can enforce cascades without scanning learner attempt-category snapshots.
drop index if exists public.learner_activity_attempt_categories_user_attempt_idx;

create index learner_activity_attempt_categories_attempt_user_idx
  on public.learner_activity_attempt_categories (attempt_id, user_id);
