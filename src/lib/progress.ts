import type { ActivityAttempt, PracticeSource } from './types'

export type MasteryStage = 'Emerging' | 'Securing' | 'Advancing' | 'Mastered'

export const MASTERY_STAGES: ReadonlyArray<{ name: MasteryStage; range: string }> = [
  { name: 'Emerging', range: '0–24%' },
  { name: 'Securing', range: '25–49%' },
  { name: 'Advancing', range: '50–79%' },
  { name: 'Mastered', range: '80–100%' },
]

export function getMasteryStage(value: number): MasteryStage {
  if (value >= 80) return 'Mastered'
  if (value >= 50) return 'Advancing'
  if (value >= 25) return 'Securing'
  return 'Emerging'
}

export function pointsToMastered(value: number) {
  return Math.max(0, 80 - Math.round(value))
}

export function formatClockDuration(seconds: number | null) {
  const value = Math.max(0, seconds ?? 0)
  return `${Math.floor(value / 60).toString().padStart(2, '0')}:${(value % 60).toString().padStart(2, '0')}`
}

export function formatCompactDuration(seconds: number) {
  const minutes = Math.floor(seconds / 60)
  const remainingSeconds = seconds % 60
  if (!minutes) return `${remainingSeconds}s`
  return `${minutes}m ${remainingSeconds.toString().padStart(2, '0')}s`
}

export function practiceSourceLabel(source: PracticeSource) {
  const labels: Record<PracticeSource, string> = {
    recommended: 'Recommended for you',
    word_bank: 'My Collection',
    missed: 'Terms I missed',
    category: 'Selected category',
    mixed_library: 'Mixed Library',
    attempt_misses: 'Missed items retest',
  }
  return labels[source]
}

export function resultFocusLabel(attempt: ActivityAttempt, categoryFocus: string[]) {
  if (attempt.focus_label) return attempt.focus_label
  if (categoryFocus.length) return categoryFocus.join(' | ')
  return practiceSourceLabel(attempt.source)
}

export function summariseCompletedAttempts(attempts: ActivityAttempt[]) {
  const questions = attempts.reduce((total, attempt) => total + attempt.actual_length, 0)
  const correct = attempts.reduce((total, attempt) => total + attempt.score, 0)
  const durationSeconds = attempts.reduce((total, attempt) => total + (attempt.duration_seconds ?? 0), 0)
  return {
    tests: attempts.length,
    questions,
    correct,
    accuracy: questions ? Math.round((correct / questions) * 100) : 0,
    durationSeconds,
  }
}
