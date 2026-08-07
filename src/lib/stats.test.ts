import { describe, expect, it } from 'vitest'
import { calculateCategoryScores } from './stats'
import type { AttemptAnswer, KnowledgeItem } from './types'

describe('calculateCategoryScores', () => {
  it('counts one answer once overall while crediting every assigned category', () => {
    const item = {
      id: 'shared-word',
      categories: [
        { id: 'sophisticated_speaker', name: 'Sophisticated Speaker', description: null, sort_order: 23, is_primary: true },
        { id: 'professional_communication', name: 'Professional Communication', description: null, sort_order: 4, is_primary: false },
        { id: 'leadership_management', name: 'Leadership & Management', description: null, sort_order: 24, is_primary: false },
      ],
    } as KnowledgeItem
    const answer = {
      knowledge_item_id: item.id,
      is_correct: true,
    } as AttemptAnswer

    const categoryScores = calculateCategoryScores([answer], [item])

    expect([answer]).toHaveLength(1)
    expect(categoryScores).toHaveLength(3)
    expect(categoryScores.every((score) => score.total === 1 && score.correct === 1)).toBe(true)
  })
})
