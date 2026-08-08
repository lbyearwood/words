import type { KnowledgeItem } from '../lib/types'

export function SenseMeta({
  item,
  senseCount,
  showPronunciation = true,
}: {
  item: KnowledgeItem
  senseCount: number
  showPronunciation?: boolean
}) {
  const position = Math.min(Math.max(item.sense_order, 1), senseCount)

  return (
    <div className="sense-meta" aria-label={`Meaning ${position} of ${senseCount}`}>
      <div className="sense-badges">
        {item.part_of_speech ? <span>{item.part_of_speech}</span> : null}
      </div>
      {showPronunciation && item.pronunciation ? (
        <p className="pronunciation-guide">
          <b>Sound it out</b>
          <strong>{item.pronunciation}</strong>
        </p>
      ) : null}
    </div>
  )
}
