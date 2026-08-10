import { describe, expect, it } from 'vitest'
import { practiceSelectionLabel, togglePracticeSource } from './practiceSelection'

describe('practice source selection', () => {
  it('uses the specific label for one source', () => {
    expect(practiceSelectionLabel(['word_bank'])).toBe('My Collection')
    expect(practiceSelectionLabel(['category'], 'Science')).toBe('Science')
  })

  it('uses Mixed Library for several sources', () => {
    expect(practiceSelectionLabel(['word_bank', 'missed'])).toBe('Mixed Library')
  })

  it('adds and removes sources without duplicates', () => {
    expect(togglePracticeSource(['recommended'], 'word_bank')).toEqual(['recommended', 'word_bank'])
    expect(togglePracticeSource(['recommended', 'word_bank'], 'recommended')).toEqual(['word_bank'])
  })
})
