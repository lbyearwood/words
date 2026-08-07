import { AlertCircle, LoaderCircle } from 'lucide-react'

export function LoadingState({ label = 'Loading your terms…' }: { label?: string }) {
  return (
    <div className="page-state" role="status">
      <LoaderCircle className="spin" aria-hidden="true" />
      <p>{label}</p>
    </div>
  )
}

export function ErrorState({ message }: { message: string }) {
  return (
    <div className="page-state error-state" role="alert">
      <AlertCircle aria-hidden="true" />
      <h2>Something went wrong</h2>
      <p>{message}</p>
    </div>
  )
}
