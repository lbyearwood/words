import { Brain } from 'lucide-react'

export function Brand() {
  return (
    <div className="brand" aria-label="Brain Express">
      <Brain className="brand-mark" aria-hidden="true" strokeWidth={2.6} />
      <span>Brain Express</span>
    </div>
  )
}
