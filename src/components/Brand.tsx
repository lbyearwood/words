import { Brain } from 'lucide-react'

export function Brand() {
  return (
    <div className="brand" aria-label="Vocab Express">
      <Brain className="brand-mark" aria-hidden="true" strokeWidth={2.6} />
      <span>Vocab Express</span>
    </div>
  )
}
