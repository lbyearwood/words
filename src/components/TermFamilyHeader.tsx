import type { ReactNode } from 'react'
import type { KnowledgeItem } from '../lib/types'

export function TermFamilyHeader({ term, items, actions }: { term: string; items: KnowledgeItem[]; actions?: ReactNode }) {
  const pronunciations = [...new Set(items.map((item) => item.pronunciation).filter(Boolean))]
  const sharedPronunciation = pronunciations.length === 1 ? pronunciations[0] : null
  const meaningLabel = `${items.length} ${items.length === 1 ? 'meaning' : 'meanings'}`

  return (
    <header className="term-family-heading">
      <h2>
        {term}
        {sharedPronunciation ? <span className="term-pronunciation">({sharedPronunciation})</span> : null}
      </h2>
      {actions}
      <span className="meaning-count">{meaningLabel}</span>
    </header>
  )
}
