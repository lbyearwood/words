export type ScoreGrade = 'A' | 'B' | 'C' | 'D' | 'E'

export function getScoreGrade(percentage: number): ScoreGrade {
  if (percentage >= 80) return 'A'
  if (percentage >= 70) return 'B'
  if (percentage >= 60) return 'C'
  if (percentage >= 50) return 'D'
  return 'E'
}
