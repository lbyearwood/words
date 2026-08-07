import type { AttemptAnswer, Category, KnowledgeItem } from './types'

export interface CategoryScore {
  category: Category
  correct: number
  total: number
  accuracy: number
}

export function calculateCategoryScores(
  answers: AttemptAnswer[],
  items: KnowledgeItem[],
): CategoryScore[] {
  const itemById = new Map(items.map((item) => [item.id, item]))
  const scores = new Map<Category, { correct: number; total: number }>()

  for (const answer of answers) {
    for (const category of itemById.get(answer.knowledge_item_id)?.categories ?? []) {
      const score = scores.get(category.id) ?? { correct: 0, total: 0 }
      score.total += 1
      if (answer.is_correct) score.correct += 1
      scores.set(category.id, score)
    }
  }

  return [...scores.entries()].map(([category, score]) => ({
    category,
    ...score,
    accuracy: Math.round((score.correct / score.total) * 100),
  }))
}
