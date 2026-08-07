import { describe, expect, it } from 'vitest'
import { getScoreGrade } from './results'

describe('getScoreGrade', () => {
  it.each([
    [100, 'A'],
    [80, 'A'],
    [79, 'B'],
    [70, 'B'],
    [69, 'C'],
    [60, 'C'],
    [59, 'D'],
    [50, 'D'],
    [49, 'E'],
    [0, 'E'],
  ] as const)('grades %i%% as %s', (percentage, grade) => {
    expect(getScoreGrade(percentage)).toBe(grade)
  })
})
