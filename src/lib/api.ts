import { supabase } from './supabase'
import type {
  AppData,
  CollectionData,
  Category,
  CategoryRecord,
  Difficulty,
  KnowledgeItem,
  KnowledgeItemCategoryRow,
  PartOfSpeech,
  AnswerFeedback,
  CategoryGoal,
  LearningDashboard,
  PracticeAttemptData,
  PracticeSetupCounts,
  PracticeSource,
  ProgressData,
  PointsSummary,
  UserCollection,
} from './types'

const API_PAGE_SIZE = 1000

function unwrap<T>(result: { data: T | null; error: { message: string } | null }): T {
  if (result.error) throw new Error(result.error.message)
  if (result.data === null) throw new Error('The database returned no data.')
  return result.data
}

export async function fetchAppData(userId: string): Promise<AppData> {
  const [profile, itemResult, categoryResult, mappingResult, goalResult, collections, confidence, attempts] = await Promise.all([
    supabase.from('profiles').select('*').eq('id', userId).single(),
    supabase.from('knowledge_items').select('*').order('term'),
    supabase.from('categories').select('*').order('sort_order'),
    supabase.from('knowledge_item_categories').select('knowledge_item_id,category_id,is_primary,importance'),
    supabase.from('user_category_goals').select('*').order('goal_weight', { ascending: false }),
    supabase.from('user_collections').select('*'),
    supabase.from('user_item_confidence').select('*'),
    supabase.from('activity_attempts').select('*').order('created_at', { ascending: false }),
  ])

  const categories = unwrap(categoryResult) as CategoryRecord[]
  const categoryById = new Map(categories.map((category) => [category.id, category]))
  const mappingsByItem = new Map<string, KnowledgeItem['categories']>()
  for (const mapping of unwrap(mappingResult) as KnowledgeItemCategoryRow[]) {
    const category = categoryById.get(mapping.category_id)
    if (!category) continue
    const assigned = mappingsByItem.get(mapping.knowledge_item_id) ?? []
    assigned.push({ ...category, is_primary: mapping.is_primary, importance: Number(mapping.importance) })
    mappingsByItem.set(mapping.knowledge_item_id, assigned)
  }

  const rawItems = unwrap(itemResult) as Omit<KnowledgeItem, 'categories'>[]
  const items = rawItems.map((item) => ({
    ...item,
    categories: (mappingsByItem.get(item.id) ?? []).sort(
      (first, second) => Number(second.is_primary) - Number(first.is_primary) || first.sort_order - second.sort_order,
    ),
  }))

  return {
    profile: unwrap(profile) as AppData['profile'],
    categories,
    categoryGoals: unwrap(goalResult) as CategoryGoal[],
    items,
    collections: unwrap(collections) as AppData['collections'],
    confidence: unwrap(confidence) as AppData['confidence'],
    attempts: unwrap(attempts) as AppData['attempts'],
    answers: [],
  }
}

export async function fetchCollectionData(userId: string): Promise<CollectionData> {
  const collectionRows: UserCollection[] = []
  let collectionOffset = 0

  const categoryPromise = supabase.from('categories').select('*').order('sort_order')
  while (true) {
    const result = await supabase
      .from('user_collections')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .order('knowledge_item_id')
      .range(collectionOffset, collectionOffset + API_PAGE_SIZE - 1)
    const page = unwrap(result) as UserCollection[]
    collectionRows.push(...page)
    if (page.length < API_PAGE_SIZE) break
    collectionOffset += API_PAGE_SIZE
  }
  const categoryResult = await categoryPromise

  const categories = unwrap(categoryResult) as CategoryRecord[]
  const itemIds = collectionRows.map((row) => row.knowledge_item_id)
  const rawItems: Omit<KnowledgeItem, 'categories'>[] = []
  const mappings: KnowledgeItemCategoryRow[] = []

  for (let start = 0; start < itemIds.length; start += 100) {
    const ids = itemIds.slice(start, start + 100)
    const itemResult = await supabase.from('knowledge_items').select('*').in('id', ids).order('term')
    rawItems.push(...(unwrap(itemResult) as Omit<KnowledgeItem, 'categories'>[]))

    let mappingOffset = 0
    while (true) {
      const mappingResult = await supabase
        .from('knowledge_item_categories')
        .select('knowledge_item_id,category_id,is_primary,importance')
        .in('knowledge_item_id', ids)
        .order('knowledge_item_id')
        .order('category_id')
        .range(mappingOffset, mappingOffset + API_PAGE_SIZE - 1)
      const page = unwrap(mappingResult) as KnowledgeItemCategoryRow[]
      mappings.push(...page)
      if (page.length < API_PAGE_SIZE) break
      mappingOffset += API_PAGE_SIZE
    }
  }

  const confidenceRows: CollectionData['confidence'] = []
  let confidenceOffset = 0
  while (true) {
    const confidenceResult = await supabase
      .from('user_item_confidence')
      .select('*')
      .eq('user_id', userId)
      .order('knowledge_item_id')
      .range(confidenceOffset, confidenceOffset + API_PAGE_SIZE - 1)
    const page = unwrap(confidenceResult) as CollectionData['confidence']
    confidenceRows.push(...page)
    if (page.length < API_PAGE_SIZE) break
    confidenceOffset += API_PAGE_SIZE
  }

  const categoryById = new Map(categories.map((category) => [category.id, category]))
  const mappingsByItem = new Map<string, KnowledgeItem['categories']>()
  for (const mapping of mappings) {
    const category = categoryById.get(mapping.category_id)
    if (!category) continue
    const assigned = mappingsByItem.get(mapping.knowledge_item_id) ?? []
    assigned.push({ ...category, is_primary: mapping.is_primary, importance: Number(mapping.importance) })
    mappingsByItem.set(mapping.knowledge_item_id, assigned)
  }

  return {
    categories,
    collections: collectionRows,
    confidence: confidenceRows,
    items: rawItems.map((item) => ({
      ...item,
      categories: (mappingsByItem.get(item.id) ?? []).sort(
        (first, second) => Number(second.is_primary) - Number(first.is_primary) || first.sort_order - second.sort_order,
      ),
    })),
  }
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
      .from('activity_attempt_categories')
      .select('attempt_id,user_id,category_id,goal_role,goal_weight,created_at'),
    supabase.from('categories').select('id,name,description,sort_order').order('sort_order'),
    supabase.rpc('get_learning_dashboard'),
  ])

  return {
    attempts: unwrap(attemptResult) as ProgressData['attempts'],
    attemptCategories: unwrap(attemptCategoryResult) as ProgressData['attemptCategories'],
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
  const { error } = await supabase.from('user_collections').upsert(
    { user_id: userId, knowledge_item_id: itemId, state: 'saved' },
    { onConflict: 'user_id,knowledge_item_id' },
  )
  if (error) throw new Error(error.message)
}

export async function setLikedState(userId: string, itemId: string, isLiked: boolean) {
  const { error } = await supabase.from('user_collections').upsert(
    {
      user_id: userId,
      knowledge_item_id: itemId,
      state: 'saved',
      is_liked: isLiked,
      ...(isLiked ? { is_disliked: false } : {}),
    },
    { onConflict: 'user_id,knowledge_item_id' },
  )
  if (error) throw new Error(error.message)
}

export async function setDislikedState(userId: string, itemId: string, isDisliked: boolean) {
  const existing = await fetchCollectionItem(userId, itemId)

  if (isDisliked) {
    const { error } = await supabase.from('user_collections').upsert(
      {
        user_id: userId,
        knowledge_item_id: itemId,
        state: existing?.state === 'saved' ? 'saved' : 'preference',
        is_liked: false,
        is_disliked: true,
      },
      { onConflict: 'user_id,knowledge_item_id' },
    )
    if (error) throw new Error(error.message)
    return
  }

  if (existing?.state === 'saved') {
    const { error } = await supabase
      .from('user_collections')
      .update({ is_disliked: false })
      .eq('user_id', userId)
      .eq('knowledge_item_id', itemId)
    if (error) throw new Error(error.message)
    return
  }

  const { error } = await supabase
    .from('user_collections')
    .delete()
    .eq('user_id', userId)
    .eq('knowledge_item_id', itemId)
  if (error) throw new Error(error.message)
}

export async function fetchCollectionItem(userId: string, itemId: string) {
  const { data, error } = await supabase
    .from('user_collections')
    .select('*')
    .eq('user_id', userId)
    .eq('knowledge_item_id', itemId)
    .maybeSingle()
  if (error) throw new Error(error.message)
  return data as UserCollection | null
}

export async function removeFromCollection(userId: string, itemId: string) {
  const existing = await fetchCollectionItem(userId, itemId)
  const operation = existing?.is_disliked
    ? supabase
      .from('user_collections')
      .update({ state: 'preference', is_liked: false })
      .eq('user_id', userId)
      .eq('knowledge_item_id', itemId)
    : supabase
      .from('user_collections')
      .delete()
      .eq('user_id', userId)
      .eq('knowledge_item_id', itemId)
  const { error } = await operation
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
  const { data, error } = await supabase.rpc('create_personal_item', {
    p_term: input.term,
    p_meaning: input.meaning,
    p_example_sentence: input.example,
    p_primary_category: input.primary_category,
    p_secondary_categories: input.secondary_categories,
    p_difficulty: input.difficulty,
    p_part_of_speech: input.part_of_speech,
    p_pronunciation: input.pronunciation,
    p_sense_label: input.sense_label,
  })
  if (error) throw new Error(error.message)
  return data as string
}
