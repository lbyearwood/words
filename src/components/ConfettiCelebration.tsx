import { useEffect, useState, type CSSProperties } from 'react'

const CONFETTI_COLOURS = ['#ffc21c', '#00994f', '#ff654f', '#dc3975', '#3182ce', '#7c4dff']
const CONFETTI_DURATION_MS = 5_000

type ConfettiStyle = CSSProperties & {
  '--confetti-drift': string
  '--confetti-spin': string
}

const CONFETTI_PIECES = Array.from({ length: 84 }, (_, index) => ({
  id: index,
  className: index % 5 === 0 ? 'is-circle' : index % 3 === 0 ? 'is-streamer' : '',
  style: {
    left: `${(index * 47) % 101}%`,
    width: `${7 + ((index * 3) % 6)}px`,
    height: `${8 + ((index * 7) % 12)}px`,
    backgroundColor: CONFETTI_COLOURS[index % CONFETTI_COLOURS.length],
    animationDelay: `${((index * 11) % 90) / 100}s`,
    animationDuration: `${3.6 + ((index * 7) % 40) / 100}s`,
    '--confetti-drift': `${((index * 29) % 180) - 90}px`,
    '--confetti-spin': `${480 + ((index * 31) % 720)}deg`,
  } as ConfettiStyle,
}))

function prefersReducedMotion() {
  return typeof window !== 'undefined'
    && typeof window.matchMedia === 'function'
    && window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

export function ConfettiCelebration() {
  const [isVisible, setIsVisible] = useState(() => !prefersReducedMotion())

  useEffect(() => {
    if (!isVisible) return
    const timer = window.setTimeout(() => setIsVisible(false), CONFETTI_DURATION_MS)
    return () => window.clearTimeout(timer)
  }, [isVisible])

  if (!isVisible) return null

  return (
    <div className="confetti-celebration" aria-hidden="true" data-testid="confetti-celebration">
      {CONFETTI_PIECES.map((piece) => (
        <i className={piece.className} key={piece.id} style={piece.style} />
      ))}
    </div>
  )
}
