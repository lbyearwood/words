import { describe, expect, it } from 'vitest'
import { buildPracticeQuestions, calculateConfidence, getEligibleItems } from './practice'
import type { AppData, ItemCategory, KnowledgeItem } from './types'

const professionalCategory: ItemCategory = {
  id: 'professional_communication',
  name: 'Professional Communication',
  description: null,
  sort_order: 4,
  is_primary: true,
  importance: 0.8,
}

const items: KnowledgeItem[] = Array.from({ length: 20 }, (_, index) => ({
  id: String(index),
  term: `Word ${index}`,
  meaning: `Meaning ${index}`,
  example_sentence: `Word ${index} appears in this example.`,
  categories: [professionalCategory],
  difficulty: 'beginner',
  source: 'seeded',
  owner_id: null,
  default_importance: 0.7,
}))

describe('buildPracticeQuestions', () => {
  it('caps to eligible items and never repeats a target', () => {
    const questions = buildPracticeQuestions([...items.slice(0, 12), items[0]], items, 30, 'attempt-one')
    expect(questions).toHaveLength(12)
    expect(new Set(questions.map((question) => question.knowledge_item_id)).size).toBe(12)
  })

  it('is reproducible and mixes multiple-choice and true-or-false questions', () => {
    const first = buildPracticeQuestions(items, items, 16, 'stable-seed')
    const second = buildPracticeQuestions(items, items, 16, 'stable-seed')
    expect(first).toEqual(second)
    expect(new Set(first.map((question) => question.question_type))).toEqual(
      new Set(['multiple_choice', 'true_false']),
    )
    expect(first.every((question) => new Set(question.options).size === question.options.length)).toBe(true)
  })
})

describe('getEligibleItems', () => {
  it('includes secondary category matches and de-duplicates combined categories', () => {
    const articulate: KnowledgeItem = {
      ...items[0],
      categories: [
        { ...professionalCategory, is_primary: false },
        {
          id: 'sophisticated_speaker',
          name: 'Sophisticated Speaker',
          description: null,
          sort_order: 23,
          is_primary: true,
          importance: 0.9,
        },
      ],
    }
    const data = {
      items: [articulate, items[1]],
      collections: [],
      answers: [],
    } as unknown as AppData

    const eligible = getEligibleItems(
      data,
      'category',
      ['professional_communication', 'sophisticated_speaker'],
    )

    expect(eligible.map((item) => item.id)).toEqual([articulate.id, items[1].id])
    expect(new Set(eligible.map((item) => item.id)).size).toBe(eligible.length)
  })
})

describe('calculateConfidence', () => {
  it.each([
    [[], 'New'],
    [[false], 'Needs practice'],
    [[true], 'Learning'],
    [[true, true, true], 'Confident'],
    [[false, true, true, true, true], 'Needs practice'],
    [[true, false, false], 'Needs practice'],
  ] as const)('maps %j to %s', (answers, expected) => {
    expect(calculateConfidence([...answers])).toBe(expected)
  })
})
