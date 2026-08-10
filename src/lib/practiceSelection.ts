import type { PracticeSource } from './types'

export function practiceSelectionLabel(
  sources: PracticeSource[],
  categoryName?: string,
) {
  if (sources.length > 1) return 'Mixed Library'
  const source = sources[0]
  if (!source) return 'Choose sources'
  if (source === 'recommended') return 'Recommended for you'
  if (source === 'word_bank') return 'My Collection'
  if (source === 'missed') return 'Terms I missed'
  if (source === 'category') return categoryName ?? 'Selected category'
  if (source === 'attempt_misses') return 'Missed from this result'
  return 'Mixed Library'
}

export function togglePracticeSource(
  sources: PracticeSource[],
  source: PracticeSource,
) {
  return sources.includes(source)
    ? sources.filter((selected) => selected !== source)
    : [...sources, source]
}
