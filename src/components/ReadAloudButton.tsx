import { useEffect, useRef, useState } from 'react'
import { Volume2 } from 'lucide-react'

interface ActiveSpeech {
  utterance: SpeechSynthesisUtterance
  deactivate: () => void
}

let activeSpeech: ActiveSpeech | null = null

function getSpeechSynthesis() {
  if (typeof window === 'undefined' || typeof window.speechSynthesis === 'undefined') return null
  if (typeof SpeechSynthesisUtterance === 'undefined') return null
  return window.speechSynthesis
}

function stopActiveSpeech() {
  const synthesis = getSpeechSynthesis()
  const speech = activeSpeech
  activeSpeech = null
  synthesis?.cancel()
  speech?.deactivate()
}

function chooseBritishVoice(synthesis: SpeechSynthesis) {
  const voices = synthesis.getVoices?.() ?? []
  return voices.find((voice) => voice.lang.toLowerCase() === 'en-gb')
    ?? voices.find((voice) => /british|united kingdom|\buk\b/i.test(`${voice.name} ${voice.lang}`))
    ?? voices.find((voice) => voice.lang.toLowerCase().startsWith('en'))
    ?? null
}

export function ReadAloudButton({
  term,
  pronunciation,
  className = '',
}: {
  term: string
  pronunciation?: string | null
  className?: string
}) {
  const [isSpeaking, setIsSpeaking] = useState(false)
  const mounted = useRef(true)
  const utteranceRef = useRef<SpeechSynthesisUtterance | null>(null)
  const synthesis = getSpeechSynthesis()
  const spokenTerm = term.trim()
  const visibleLabel = pronunciation?.trim() || 'Read aloud'
  const unavailable = !synthesis || !spokenTerm

  useEffect(() => {
    mounted.current = true
    return () => {
      mounted.current = false
      if (activeSpeech?.utterance === utteranceRef.current) {
        activeSpeech = null
        getSpeechSynthesis()?.cancel()
      }
    }
  }, [])

  function handleClick() {
    if (!synthesis || !spokenTerm) return

    if (activeSpeech?.utterance === utteranceRef.current) {
      stopActiveSpeech()
      return
    }

    stopActiveSpeech()
    const utterance = new SpeechSynthesisUtterance(spokenTerm)
    utterance.lang = 'en-GB'
    utterance.rate = 0.88
    utterance.pitch = 1
    utterance.voice = chooseBritishVoice(synthesis)
    utteranceRef.current = utterance
    setIsSpeaking(true)

    const finish = () => {
      if (activeSpeech?.utterance !== utterance) return
      activeSpeech = null
      if (mounted.current) setIsSpeaking(false)
    }

    utterance.onend = finish
    utterance.onerror = finish
    activeSpeech = {
      utterance,
      deactivate: () => {
        if (mounted.current) setIsSpeaking(false)
      },
    }
    try {
      synthesis.speak(utterance)
    } catch {
      if (activeSpeech?.utterance === utterance) activeSpeech = null
      if (mounted.current) setIsSpeaking(false)
    }
  }

  return (
    <button
      type="button"
      className={`read-aloud-button ${isSpeaking ? 'is-speaking' : ''} ${className}`.trim()}
      aria-label={`Read ${spokenTerm || 'this term'} aloud`}
      aria-pressed={isSpeaking}
      data-tooltip={unavailable ? 'Read aloud unavailable' : isSpeaking ? 'Stop reading aloud' : 'Read term aloud'}
      disabled={unavailable}
      onClick={handleClick}
    >
      <Volume2 aria-hidden="true" />
      <span>{visibleLabel}</span>
    </button>
  )
}
