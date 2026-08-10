import { useEffect } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import {
  appDataQueryOptions,
  collectionDataQueryOptions,
  learningDashboardQueryOptions,
  libraryDataQueryOptions,
  pointsSummaryQueryOptions,
  practiceSetupCountsQueryOptions,
} from '../hooks/useAppData'
import { useAuth } from '../state/AuthContext'

type IdleWindow = Window & typeof globalThis & {
  requestIdleCallback?: (callback: () => void, options?: { timeout: number }) => number
  cancelIdleCallback?: (handle: number) => void
}

export function DataWarmup() {
  const { user } = useAuth()
  const queryClient = useQueryClient()

  useEffect(() => {
    if (!user) return
    const browserWindow = window as IdleWindow
    let cancelled = false

    const warmData = async () => {
      await Promise.all([
        queryClient.prefetchQuery(appDataQueryOptions(user.id)),
        queryClient.prefetchQuery(learningDashboardQueryOptions(user.id)),
        queryClient.prefetchQuery(pointsSummaryQueryOptions(user.id)),
        queryClient.prefetchQuery(practiceSetupCountsQueryOptions(user.id)),
      ])
      if (cancelled) return
      await queryClient.prefetchQuery(collectionDataQueryOptions(user.id))
      if (cancelled) return
      await queryClient.prefetchQuery(libraryDataQueryOptions(user.id, queryClient))
    }

    const start = () => void warmData().catch(() => {
      // Individual pages retain their normal retry and error states.
    })
    const idleHandle = browserWindow.requestIdleCallback?.(start, { timeout: 1_200 })
    const timeoutHandle = idleHandle === undefined ? window.setTimeout(start, 350) : null

    return () => {
      cancelled = true
      if (idleHandle !== undefined) browserWindow.cancelIdleCallback?.(idleHandle)
      if (timeoutHandle !== null) window.clearTimeout(timeoutHandle)
    }
  }, [queryClient, user])

  return null
}
