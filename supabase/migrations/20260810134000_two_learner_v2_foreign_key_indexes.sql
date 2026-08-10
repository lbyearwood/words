-- Cover every foreign-key lookup reported by the Supabase performance advisor.
-- The legacy columns remain indexed while compatibility data is still present.

create index if not exists content_review_records_user_idx
  on private.content_review_records (user_id);

create index if not exists activity_attempt_categories_attempt_user_idx
  on public.activity_attempt_categories (attempt_id, user_id);
create index if not exists activity_attempt_categories_category_idx
  on public.activity_attempt_categories (category_id);

create index if not exists activity_attempts_category_idx
  on public.activity_attempts (category_id);
create index if not exists activity_attempts_point_system_idx
  on public.activity_attempts (point_system_version);
create index if not exists activity_attempts_source_user_idx
  on public.activity_attempts (source_attempt_id, user_id);

create index if not exists attempt_answers_attempt_user_idx
  on public.attempt_answers (attempt_id, user_id);
create index if not exists attempt_answers_knowledge_item_idx
  on public.attempt_answers (knowledge_item_id);

create index if not exists learner_category_focus_category_user_idx
  on public.learner_category_focus (learner_category_id, user_id);
create index if not exists learner_point_event_categories_category_user_idx
  on public.learner_point_event_categories (learner_category_id, user_id);

create index if not exists learning_item_categories_category_user_idx
  on public.learning_item_categories (learner_category_id, user_id);
create index if not exists learning_item_categories_item_user_idx
  on public.learning_item_categories (learning_item_id, user_id);

create index if not exists user_category_goals_category_idx
  on public.user_category_goals (category_id);

create index if not exists user_collections_knowledge_item_idx
  on public.user_collections (knowledge_item_id);
create index if not exists user_collections_learning_item_user_idx
  on public.user_collections (learning_item_id, user_id);

create index if not exists user_item_learning_states_knowledge_item_idx
  on public.user_item_learning_states (knowledge_item_id);
create index if not exists user_item_learning_states_learning_item_idx
  on public.user_item_learning_states (learning_item_id);

create index if not exists user_item_review_events_knowledge_item_idx
  on public.user_item_review_events (knowledge_item_id);
create index if not exists user_item_review_events_learning_item_cover_idx
  on public.user_item_review_events (learning_item_id);

create index if not exists user_point_event_categories_category_idx
  on public.user_point_event_categories (category_id);
create index if not exists user_point_event_categories_event_user_idx
  on public.user_point_event_categories (event_id, user_id);

create index if not exists user_point_events_attempt_user_idx
  on public.user_point_events (attempt_id, user_id);
create index if not exists user_point_events_knowledge_item_idx
  on public.user_point_events (knowledge_item_id);
create index if not exists user_point_events_learning_item_idx
  on public.user_point_events (learning_item_id);
create index if not exists user_point_events_system_version_idx
  on public.user_point_events (system_version);

create index if not exists vocabulary_items_item_user_idx
  on public.vocabulary_items (learning_item_id, user_id);
create index if not exists vocabulary_items_family_user_idx
  on public.vocabulary_items (term_family_id, user_id);
