import { StrictMode } from 'react'
import { createRoot, type Root } from 'react-dom/client'
import { BookmarkCheck, Heart, ThumbsDown } from 'lucide-react'
import { ReadAloudButton } from '../../src/components/ReadAloudButton'
import { SenseMeta } from '../../src/components/SenseMeta'
import { TermFamilyHeader } from '../../src/components/TermFamilyHeader'
import type { KnowledgeItem } from '../../src/lib/types'
import '../../src/styles.css'

const items = [
  {
    id: 'coincide-one',
    term: 'Coincide',
    meaning: 'To happen at the same time.',
    pronunciation: 'co-in-SIDE',
    part_of_speech: 'verb',
    sense_order: 1,
  },
  {
    id: 'coincide-two',
    term: 'Coincide',
    meaning: 'To agree or match exactly.',
    pronunciation: 'co-in-SIDE',
    part_of_speech: 'verb',
    sense_order: 2,
  },
] as KnowledgeItem[]

export function TermActions({ question = false }: { question?: boolean }) {
  return (
    <div className={question ? 'question-item-actions' : 'collection-card-actions'} aria-label="Term actions">
      {question ? <button className="icon-button is-selected" aria-label="Saved in My Collection"><BookmarkCheck /></button> : null}
      <button className="icon-button is-liked" aria-label="Remove from favourites"><Heart fill="currentColor" /></button>
      {!question ? <button className="icon-button is-selected" aria-label="Saved in My Collection"><BookmarkCheck /></button> : null}
      <button className="icon-button" aria-label="Dislike"><ThumbsDown /></button>
    </div>
  )
}

export function Preview() {
  return (
    <main className="page speech-visual-preview">
      <section className="collection-row term-family-card" aria-label="Coincide term card">
        <TermFamilyHeader term="Coincide" items={items} />
        <div className="term-family-senses">
          {items.map((item) => (
            <article className="term-sense-row" key={item.id}>
              <TermActions />
              <SenseMeta item={item} senseCount={2} showPronunciation={false} />
              <p className="sense-meaning">{item.meaning}</p>
              <div className="category-tags"><span>General Vocabulary</span></div>
              <footer className="collection-card-meta">
                <small>Intermediate</small>
                <span className="confidence-status"><i />Untested</span>
              </footer>
            </article>
          ))}
        </div>
      </section>

      <section className="question-panel" aria-label="Practice question preview">
        <div className="question-context-row">
          <p className="question-type">Multiple choice</p>
          <TermActions question />
        </div>
        <div className="question-prompt-row">
          <h1>Which meaning best matches 'Commemorate'?</h1>
          <ReadAloudButton term="Commemorate" pronunciation="com-MEM-o-rate" />
        </div>
        <p>Tap one answer</p>
        <div className="answer-options">
          {[
            'With intense feeling, enthusiasm or conviction.',
            'A belief or set of beliefs treated as unquestionably true.',
            'To honour and remember a person or event, often through a ceremony or lasting symbol.',
            'Treating a serious subject with inappropriate humour.',
          ].map((option, index) => (
            <button className={index === 2 ? 'is-selected' : ''} key={option}>
              <span className="option-marker">{String.fromCharCode(65 + index)}</span>
              <span>{option}</span>
            </button>
          ))}
        </div>
        <footer className="question-panel-footer">
          <button className="primary-button question-next">Check answer</button>
        </footer>
      </section>
    </main>
  )
}

const previewWindow = window as Window & { __brainExpressSpeechPreviewRoot?: Root }
const previewRoot = previewWindow.__brainExpressSpeechPreviewRoot ?? createRoot(document.getElementById('root')!)
previewWindow.__brainExpressSpeechPreviewRoot = previewRoot
previewRoot.render(<StrictMode><Preview /></StrictMode>)
