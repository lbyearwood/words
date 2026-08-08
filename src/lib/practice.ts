import type {
  AppData,
  Category,
  ConfidenceStatus,
  KnowledgeItem,
  PracticeSource,
  QuestionType,
} from './types'
import { itemHasCategory } from './types'

export interface PracticeQuestion {
  knowledge_item_id: string
  position: number
  question_type: QuestionType
  prompt: string
  options: string[]
  correct_answer: string
}

function hashString(value: string) {
  let hash = 2166136261
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index)
    hash = Math.imul(hash, 16777619)
  }
  return hash >>> 0
}

function randomFromSeed(seed: string) {
  let value = hashString(seed)
  return () => {
    value += 0x6d2b79f5
    let next = value
    next = Math.imul(next ^ (next >>> 15), next | 1)
    next ^= next + Math.imul(next ^ (next >>> 7), next | 61)
    return ((next ^ (next >>> 14)) >>> 0) / 4_294_967_296
  }
}

function shuffled<T>(items: readonly T[], random: () => number) {
  const result = [...items]
  for (let index = result.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(random() * (index + 1))
    ;[result[index], result[swapIndex]] = [result[swapIndex], result[index]]
  }
  return result
}

function fillOptions(
  correct: string,
  library: KnowledgeItem[],
  target: KnowledgeItem,
  value: (item: KnowledgeItem) => string,
  random: () => number,
) {
  const targetCategories = new Set(target.categories.map((category) => category.id))
  const preferred = library.filter(
    (item) =>
      item.id !== target.id
      && item.categories.some((category) => targetCategories.has(category.id))
      && value(item) !== correct,
  )
  const fallback = library.filter((item) => item.id !== target.id && value(item) !== correct)
  const unique = new Map<string, string>()
  for (const option of [...shuffled(preferred, random), ...shuffled(fallback, random)]) {
    unique.set(value(option).toLocaleLowerCase(), value(option))
    if (unique.size === 3) break
  }
  return shuffled([correct, ...unique.values()], random)
}

function promptFor(target: KnowledgeItem, library: KnowledgeItem[], type: QuestionType, shownMeaning?: string) {
  const senseCount = library.filter((item) => item.term_family_id === target.term_family_id).length
  const hasSeveralMeanings = senseCount > 1
  const hasContext = hasSeveralMeanings && target.example_sentence.trim().length > 0

  if (type === 'multiple_choice') {
    if (hasContext) return `In the sentence “${target.example_sentence}”, what does “${target.term}” mean?`
    if (hasSeveralMeanings && target.part_of_speech) {
      return `Which meaning matches “${target.term}” used as a ${target.part_of_speech}?`
    }
    return `Which meaning best matches “${target.term}”?`
  }

  if (hasContext) return `In the sentence “${target.example_sentence}”, “${target.term}” means “${shownMeaning}”.`
  if (hasSeveralMeanings && target.part_of_speech) {
    return `Used as a ${target.part_of_speech}, “${target.term}” means “${shownMeaning}”.`
  }
  return `“${target.term}” means “${shownMeaning}”`
}

export function buildPracticeQuestions(
  targets: KnowledgeItem[],
  library: KnowledgeItem[],
  requestedCount: number,
  seed: string,
): PracticeQuestion[] {
  const random = randomFromSeed(seed)
  const uniqueTargets = [...new Map(targets.map((item) => [item.term_family_id || item.id, item])).values()]
  const selected = shuffled(uniqueTargets, random).slice(0, Math.min(requestedCount, uniqueTargets.length))
  const types: QuestionType[] = ['multiple_choice', 'true_false']

  return selected.map((target, index) => {
    const type = types[index % types.length]

    if (type === 'true_false') {
      const makeTrue = random() >= 0.5
      const alternative = shuffled(
        library.filter((item) => item.id !== target.id && item.meaning !== target.meaning),
        random,
      )[0]
      const shownMeaning = makeTrue || !alternative ? target.meaning : alternative.meaning
      return {
        knowledge_item_id: target.id,
        position: index + 1,
        question_type: type,
        prompt: promptFor(target, library, type, shownMeaning),
        options: ['True', 'False'],
        correct_answer: makeTrue || !alternative ? 'True' : 'False',
      }
    }

    return {
      knowledge_item_id: target.id,
      position: index + 1,
      question_type: 'multiple_choice',
      prompt: promptFor(target, library, 'multiple_choice'),
      options: fillOptions(target.meaning, library, target, (item) => item.meaning, random),
      correct_answer: target.meaning,
    }
  })
}

export function getEligibleItems(
  data: AppData,
  source: PracticeSource,
  category?: Category | Category[],
  sourceAttemptId?: string,
) {
  const saved = new Set(
    data.collections.filter((row) => row.state === 'saved').map((row) => row.knowledge_item_id),
  )
  const visible = data.items

  if (source === 'word_bank') return visible.filter((item) => saved.has(item.id))
  if (source === 'mixed_library') return visible.filter((item) => item.source === 'seeded')
  if (source === 'category') {
    const selectedCategories = Array.isArray(category) ? category : category ? [category] : []
    const eligibleById = new Map<string, KnowledgeItem>()
    for (const item of visible) {
      if (selectedCategories.some((selected) => itemHasCategory(item, selected))) {
        eligibleById.set(item.id, item)
      }
    }
    return [...eligibleById.values()]
  }
  if (source === 'attempt_misses') {
    const missed = new Set(
      data.answers
        .filter((answer) => answer.attempt_id === sourceAttemptId && answer.is_correct === false)
        .map((answer) => answer.knowledge_item_id),
    )
    return visible.filter((item) => missed.has(item.id))
  }

  const latestByItem = new Map<string, AppData['answers'][number]>()
  for (const answer of [...data.answers].sort(
    (a, b) => new Date(b.answered_at ?? 0).getTime() - new Date(a.answered_at ?? 0).getTime(),
  )) {
    if (!latestByItem.has(answer.knowledge_item_id) && answer.is_correct !== null) {
      latestByItem.set(answer.knowledge_item_id, answer)
    }
  }
  return visible.filter((item) => latestByItem.get(item.id)?.is_correct === false)
}

export function calculateConfidence(recentAnswers: boolean[]): ConfidenceStatus {
  const answers = recentAnswers.slice(0, 5)
  if (answers.length === 0) return 'New'
  const accuracy = (answers.filter(Boolean).length / answers.length) * 100
  if (!answers[0] || accuracy < 60) return 'Needs practice'
  if (answers.length >= 3 && accuracy >= 80) return 'Confident'
  return 'Learning'
}
