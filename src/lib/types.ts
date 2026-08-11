export type Category = string
export type Difficulty = 'beginner' | 'intermediate' | 'advanced'
export type CollectionState = 'saved' | 'preference'
export type ConfidenceStatus = 'New' | 'Learning' | 'Confident' | 'Needs practice'
export type PracticeSource =
  | 'recommended'
  | 'word_bank'
  | 'missed'
  | 'category'
  | 'mixed_library'
  | 'attempt_misses'
export type QuestionType = 'multiple_choice' | 'true_false'
export const partOfSpeechValues = [
  'noun', 'verb', 'adjective', 'adverb', 'pronoun', 'preposition',
  'conjunction', 'determiner', 'interjection', 'phrase', 'idiom',
  'quotation', 'other',
] as const
export type PartOfSpeech = (typeof partOfSpeechValues)[number]

export interface CategoryRecord {
  id: Category
  slug: string
  user_id: string
  name: string
  description: string | null
  sort_order: number
}

export interface ItemCategory extends CategoryRecord {
  is_primary: boolean
  importance: number
}

export interface Profile {
  id: string
  display_name: string
  goals: string[]
  interested_categories: Category[]
  current_level: Difficulty | null
  onboarding_completed: boolean
}

export interface KnowledgeItem {
  id: string
  learning_item_id: string
  source_knowledge_item_id: string
  term_family_id: string
  term: string
  meaning: string
  example_sentence: string
  part_of_speech: PartOfSpeech | null
  pronunciation: string | null
  sense_label: string | null
  sense_order: number
  difficulty: Difficulty
  source: 'seeded' | 'user_added'
  owner_id: string | null
  default_importance: number
  item_type: 'vocabulary'
  origin: 'migrated' | 'curated' | 'user_created'
  qa_status: 'pending' | 'approved' | 'excluded'
  practice_enabled: boolean
  content_version: number
  categories: ItemCategory[]
}

export interface KnowledgeItemCategoryRow {
  knowledge_item_id: string
  category_id: Category
  is_primary: boolean
  importance: number
}

export interface CategoryGoal {
  user_id: string
  category_id: Category
  goal_role: 'primary' | 'supporting'
  goal_weight: number
}

export interface LearnerPlan {
  user_id: string
  plan_name: string
  objective: string
  audience_context: string
  curriculum_baseline: string | null
  locale: string
}

export interface LearnerPlanResponse {
  plan: LearnerPlan
  focus: CategoryGoal[]
}

export interface UserCollection {
  user_id: string
  knowledge_item_id: string
  state: CollectionState
  is_liked: boolean
  is_disliked: boolean
  created_at: string
  updated_at: string
}

export interface ConfidenceRow {
  user_id: string
  knowledge_item_id: string
  recent_answer_count: number
  recent_accuracy: number
  confidence_status: ConfidenceStatus
  stability: number | null
  next_review_at: string | null
}

export interface ActivityAttempt {
  id: string
  user_id: string
  source: PracticeSource
  category_id: Category | null
  source_attempt_id: string | null
  requested_length: number
  actual_length: number
  status: 'in_progress' | 'completed' | 'abandoned'
  score: number
  started_at: string
  completed_at: string | null
  duration_seconds: number | null
  focus_label: string | null
  points_earned: number
  point_system_version: string
}

export interface AttemptCategory {
  attempt_id: string
  user_id: string
  category_id: Category
  goal_role: 'primary' | 'supporting' | null
  goal_weight: number | null
  created_at: string
}

export interface AttemptAnswer {
  id: string
  attempt_id: string
  user_id: string
  knowledge_item_id: string
  position: number
  question_type: QuestionType
  prompt: string
  options: string[]
  correct_answer: string | null
  selected_answer: string | null
  is_correct: boolean | null
  answered_at: string | null
  term?: string
  pronunciation?: string | null
  meaning?: string
  example_sentence?: string
  points_earned: number
}

export interface AttemptPointsBreakdown {
  answer_points: number
  recovery_points: number
  completion_points: number
  grade_points: number
  total_points: number
  system_version: string
}

export interface PracticeAttemptData {
  attempt: ActivityAttempt
  answers: AttemptAnswer[]
  points: AttemptPointsBreakdown
}

export interface AnswerFeedback {
  is_correct: boolean
  correct_answer: string
  term: string
  meaning: string
  example_sentence: string
  attempt_completed: boolean
  confidence_status: ConfidenceStatus
  next_review_at: string
  rating: 1 | 2 | 3
  points_earned: number
  answer_points: number
  recovery_points: number
  completion_points: number
  grade_points: number
  attempt_points: number
  lifetime_points: number
  points_breakdown: Record<string, number | string>
}

export interface GoalPoints {
  category_id: Category
  category_name: string
  goal_role: 'primary' | 'supporting'
  points: number
}

export interface PointsSummary {
  lifetime_points: number
  week_points: number
  completed_tests: number
  average_test_points: number
  goals: GoalPoints[]
}

export interface CategoryMastery {
  category_id: Category
  category_name: string
  goal_role: 'primary' | 'supporting'
  goal_weight: number
  coverage: number
  current_recall: number
  durable_mastery: number
  total_items: number
  practised_items: number
}

export interface LearningDashboard {
  overall: {
    coverage: number
    current_recall: number
    durable_mastery: number
    total_items: number
    practised_items: number
  }
  goals: CategoryMastery[]
  due_count: number
  reviewed_unique: number
}

export interface PracticeSetupCounts {
  recommended: number
  word_bank: number
  missed: number
  mixed_library: number
  categories: Partial<Record<Category, number>>
}

export interface ProgressData {
  attempts: ActivityAttempt[]
  attemptCategories: AttemptCategory[]
  categories: CategoryRecord[]
  dashboard: LearningDashboard
}

export interface AppData {
  profile: Profile
  learnerPlan: LearnerPlan
  categories: CategoryRecord[]
  categoryGoals: CategoryGoal[]
  items: KnowledgeItem[]
  collections: UserCollection[]
  confidence: ConfidenceRow[]
  attempts: ActivityAttempt[]
  answers: AttemptAnswer[]
}

export interface CollectionData {
  categories: CategoryRecord[]
  items: KnowledgeItem[]
  collections: UserCollection[]
  confidence: ConfidenceRow[]
}

export function itemHasCategory(item: KnowledgeItem, category: Category) {
  return item.categories.some((assigned) => assigned.id === category)
}

export function primaryCategory(item: KnowledgeItem) {
  return item.categories.find((assigned) => assigned.is_primary) ?? item.categories[0]
}
