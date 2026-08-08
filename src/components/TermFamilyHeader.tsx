import type { KnowledgeItem } from '../lib/types'

export function TermFamilyHeader({ term, items }: { term: string; items: KnowledgeItem[] }) {
  const pronunciations = [...new Set(items.map((item) => item.pronunciation).filter(Boolean))]
  const sharedPronunciation = pronunciations.length === 1 ? pronunciations[0] : null

  return (
    <header className="term-family-heading">
      <h2>
        {term}
        {sharedPronunciation ? <span className="term-pronunciation">({sharedPronunciation})</span> : null}
      </h2>
      {items.length > 1 ? <span className="meaning-count">{items.length} meanings</span> : null}
    </header>
  )
}
