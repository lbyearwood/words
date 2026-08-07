import { describe, expect, it } from 'vitest'
import { formatClockDuration, formatCompactDuration, getMasteryStage, pointsToMastered, practiceSourceLabel, resultFocusLabel, summariseCompletedAttempts } from './progress'
import type { ActivityAttempt } from './types'

describe('progress helpers', () => {
  it.each([
    [0, 'Emerging'], [24, 'Emerging'], [25, 'Securing'], [49, 'Securing'],
    [50, 'Advancing'], [79, 'Advancing'], [80, 'Mastered'], [100, 'Mastered'],
  ] as const)('maps %i%% to %s', (value, stage) => {
    expect(getMasteryStage(value)).toBe(stage)
  })

  it('calculates the distance to mastery', () => {
    expect(pointsToMastered(51)).toBe(29)
    expect(pointsToMastered(92)).toBe(0)
  })

  it('formats result durations', () => {
    expect(formatClockDuration(280)).toBe('04:40')
    expect(formatCompactDuration(797)).toBe('13m 17s')
  })

  it('uses learner-facing source labels', () => {
    expect(practiceSourceLabel('word_bank')).toBe('My Collection')
    expect(practiceSourceLabel('attempt_misses')).toBe('Missed items retest')
  })

  it('uses the stored practice scope instead of reconstructing historical focus', () => {
    const attempt = {
      source: 'word_bank',
      focus_label: 'My Collection | Liked Terms',
    } as ActivityAttempt

    expect(resultFocusLabel(attempt, [])).toBe('My Collection | Liked Terms')
    expect(resultFocusLabel({ ...attempt, focus_label: null }, ['Education & Learning']))
      .toBe('Education & Learning')
  })

  it('summarises completed attempts without averaging percentages', () => {
    const attempts = [
      { actual_length: 14, score: 10, duration_seconds: 280 },
      { actual_length: 8, score: 7, duration_seconds: 426 },
    ] as ActivityAttempt[]
    expect(summariseCompletedAttempts(attempts)).toEqual({
      tests: 2,
      questions: 22,
      correct: 17,
      accuracy: 77,
      durationSeconds: 706,
    })
  })
})
