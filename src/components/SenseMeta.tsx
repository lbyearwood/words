import type { KnowledgeItem } from '../lib/types'

export function SenseMeta({ item, senseCount }: { item: KnowledgeItem; senseCount: number }) {
  const position = Math.min(Math.max(item.sense_order, 1), senseCount)

  return (
    <div className="sense-meta" aria-label="Meaning details">
      <div className="sense-badges">
        {item.part_of_speech ? <span>{item.part_of_speech}</span> : null}
        {senseCount > 1 ? <span>Meaning {position} of {senseCount}</span> : null}
        {item.sense_label ? <span>{item.sense_label}</span> : null}
      </div>
      {item.pronunciation ? <p className="pronunciation-guide"><b>Sound it out</b><strong>{item.pronunciation}</strong></p> : null}
    </div>
  )
}
