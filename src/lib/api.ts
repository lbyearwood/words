import { supabase } from './supabase'
import type {
  AppData,
  CollectionData,
  Category,
  CategoryRecord,
  Difficulty,
  KnowledgeItem,
  PartOfSpeech,
  AnswerFeedback,
  CategoryGoal,
  LearningDashboard,
  PracticeAttemptData,
  PracticeSetupCounts,
  PracticeSource,
  ProgressData,
  PointsSummary,
} from './types'

function unwrap<T>(result: { data: T | null; error: { message: string } | null }): T {
  if (result.error) throw new Error(result.error.message)
  if (result.data === null) throw new Error('The database returned no data.')
  return result.data
}

export async function fetchAppData(userId: string): Promise<AppData> {
  const [profile, categoryResult, planResult, collectionResult, attempts] = await Promise.all([
    supabase.from('profiles').select('*').eq('id', userId).single(),
    supabase.rpc('get_my_categories'),
    supabase.rpc('get_my_learning_plan'),
    supabase.from('user_collections').select('user_id,learning_item_id,state,is_liked,is_disliked,created_at,updated_at'),
    supabase.from('activity_attempts').select('*').order('created_at', { ascending: false }).limit(20),
  ])

  const plan = unwrap(planResult) as { plan: AppData['learnerPlan']; focus: CategoryGoal[] }
  const collections = (unwrap(collectionResult) as Array<Omit<AppData['collections'][number], 'knowledge_item_id'> & { learning_item_id: string }>).map(
    (row) => ({ ...row, knowledge_item_id: row.learning_item_id }),
  )

  return {
    profile: unwrap(profile) as AppData['profile'],
    learnerPlan: plan.plan,
    categories: unwrap(categoryResult) as CategoryRecord[],
    categoryGoals: plan.focus,
    items: [],
    collections,
    confidence: [],
    attempts: unwrap(attempts) as AppData['attempts'],
    answers: [],
  }
}

export async function fetchLibraryData(userId: string): Promise<AppData> {
  const [shell, itemResult] = await Promise.all([
    fetchAppData(userId),
    supabase.rpc('get_my_library', { p_limit: 2000, p_offset: 0 }),
  ])
  return { ...shell, items: unwrap(itemResult) as KnowledgeItem[] }
}

export async function fetchCollectionData(userId: string): Promise<CollectionData> {
  void userId
  const [categoryResult, collectionResult] = await Promise.all([
    supabase.rpc('get_my_categories'),
    supabase.rpc('get_my_collection'),
  ])
  const collection = unwrap(collectionResult) as Omit<CollectionData, 'categories'>
  return { ...collection, categories: unwrap(categoryResult) as CategoryRecord[] }
}

export async function fetchLearningDashboard(): Promise<LearningDashboard> {
  const { data, error } = await supabase.rpc('get_learning_dashboard')
  if (error) throw new Error(error.message)
  return data as LearningDashboard
}

export async function fetchPracticeSetupCounts(): Promise<PracticeSetupCounts> {
  const { data, error } = await supabase.rpc('get_practice_setup_counts')
  if (error) throw new Error(error.message)
  return data as PracticeSetupCounts
}

export async function fetchPointsSummary(): Promise<PointsSummary> {
  const { data, error } = await supabase.rpc('get_points_summary')
  if (error) throw new Error(error.message)
  return data as PointsSummary
}

export async function fetchProgressData(): Promise<ProgressData> {
  const [attemptResult, attemptCategoryResult, categoryResult, dashboardResult] = await Promise.all([
    supabase
      .from('activity_attempts')
      .select('id,user_id,source,category_id,source_attempt_id,requested_length,actual_length,status,score,started_at,completed_at,duration_seconds,focus_label,points_earned,point_system_version')
      .eq('status', 'completed')
      .order('completed_at', { ascending: false }),
    supabase
      .from('learner_activity_attempt_categories')
      .select('attempt_id,user_id,learner_category_id,goal_role,goal_weight,created_at'),
    supabase.rpc('get_my_categories'),
    supabase.rpc('get_learning_dashboard'),
  ])

  return {
    attempts: unwrap(attemptResult) as ProgressData['attempts'],
    attemptCategories: (unwrap(attemptCategoryResult) as Array<{
      attempt_id: string
      user_id: string
      learner_category_id: string
      goal_role: 'primary' | 'supporting' | null
      goal_weight: number | null
      created_at: string
    }>).map(({ learner_category_id, ...mapping }) => ({
      ...mapping,
      category_id: learner_category_id,
    })) as ProgressData['attemptCategories'],
    categories: unwrap(categoryResult) as ProgressData['categories'],
    dashboard: unwrap(dashboardResult) as ProgressData['dashboard'],
  }
}

export async function createPracticeAttempt(input: {
  source: PracticeSource
  requestedLength: number
  categoryIds?: Category[]
  sourceAttemptId?: string | null
}) {
  const { data, error } = await supabase.rpc('create_practice_attempt', {
    p_source: input.source,
    p_requested_length: input.requestedLength,
    p_category_ids: input.categoryIds ?? [],
    p_source_attempt_id: input.sourceAttemptId ?? null,
  })
  if (error) throw new Error(error.message)
  return data as { attempt_id: string; eligible_count: number; actual_length: number; requested_length: number }
}

export async function createScopedPracticeAttempt(input: {
  source: PracticeSource
  requestedLength: number
  itemIds: string[]
  focusLabel?: string | null
}) {
  const { data, error } = await supabase.rpc('create_scoped_practice_attempt_with_focus', {
    p_source: input.source,
    p_requested_length: input.requestedLength,
    p_category_ids: [],
    p_source_attempt_id: null,
    p_item_ids: input.itemIds,
    p_focus_label: input.focusLabel ?? null,
  })
  if (error) throw new Error(error.message)
  return data as { attempt_id: string; eligible_count: number; actual_length: number; requested_length: number }
}

export async function fetchPracticeAttempt(attemptId: string): Promise<PracticeAttemptData> {
  const { data, error } = await supabase.rpc('get_practice_attempt', { p_attempt_id: attemptId })
  if (error) throw new Error(error.message)
  return data as PracticeAttemptData
}

export async function submitPracticeAnswer(answerId: string, selectedAnswer: string): Promise<AnswerFeedback> {
  const { data, error } = await supabase.rpc('submit_practice_answer', {
    p_answer_id: answerId,
    p_selected_answer: selectedAnswer,
  })
  if (error) throw new Error(error.message)
  return data as AnswerFeedback
}

export async function saveCategoryGoals(primary: Category | null, supporting: Category[]) {
  if (!primary) {
    const { error } = await supabase.rpc('clear_category_goals')
    if (error) throw new Error(error.message)
    return
  }
  const { error } = await supabase.rpc('set_category_goals', {
    primary_category_id: primary,
    supporting_category_ids: supporting,
  })
  if (error) throw new Error(error.message)
}

export async function saveToCollection(userId: string, itemId: string) {
  void userId
  const { error } = await supabase.rpc('set_learning_item_preference', {
    p_learning_item_id: itemId, p_saved: true,
  })
  if (error) throw new Error(error.message)
}

export async function setLikedState(userId: string, itemId: string, isLiked: boolean) {
  void userId
  const { error } = await supabase.rpc('set_learning_item_preference', {
    p_learning_item_id: itemId, p_liked: isLiked,
  })
  if (error) throw new Error(error.message)
}

export async function setDislikedState(userId: string, itemId: string, isDisliked: boolean) {
  void userId
  const { error } = await supabase.rpc('set_learning_item_preference', {
    p_learning_item_id: itemId, p_disliked: isDisliked,
  })
  if (error) throw new Error(error.message)
}

export async function fetchCollectionItem(userId: string, itemId: string) {
  const collection = await fetchCollectionData(userId)
  return collection.collections.find((row) => row.knowledge_item_id === itemId) ?? null
}

export async function removeFromCollection(userId: string, itemId: string) {
  void userId
  const { error } = await supabase.rpc('set_learning_item_preference', {
    p_learning_item_id: itemId, p_saved: false,
  })
  if (error) throw new Error(error.message)
}

export async function createPersonalItem(input: {
  term: string
  meaning: string
  example: string
  primary_category: Category
  secondary_categories: Category[]
  difficulty: Difficulty
  part_of_speech: PartOfSpeech | null
  pronunciation: string | null
  sense_label: string | null
}) {
  const { data, error } = await supabase.rpc('create_personal_vocabulary_item', {
    p_term: input.term,
    p_definition: input.meaning,
    p_example_sentence: input.example,
    p_primary_category_id: input.primary_category,
    p_secondary_category_ids: input.secondary_categories,
    p_difficulty: input.difficulty,
    p_part_of_speech: input.part_of_speech,
    p_pronunciation: input.pronunciation,
    p_sense_label: input.sense_label,
  })
  if (error) throw new Error(error.message)
  return data as string
}
