-- Cover the learner-category ownership foreign key in its declared order.
drop index if exists public.learner_activity_attempt_categories_category_idx;

create index learner_activity_attempt_categories_category_user_idx
  on public.learner_activity_attempt_categories (learner_category_id, user_id);
