import type { KnowledgeItem } from '../lib/types'
import { ReadAloudButton } from './ReadAloudButton'

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
        <ReadAloudButton term={item.term} pronunciation={item.pronunciation} className="sense-pronunciation-button" />
      ) : null}
    </div>
  )
}
