import { useQuery, useQueryClient, type QueryClient } from '@tanstack/react-query'
import { fetchAppData, fetchCollectionData, fetchLearningDashboard, fetchLibraryData, fetchPointsSummary, fetchPracticeSetupCounts, fetchPracticeSetupMultiCount, fetchProgressData } from '../lib/api'
import type { Category, PracticeSource } from '../lib/types'
import { useAuth } from '../state/AuthContext'

export const appDataQueryOptions = (userId: string) => ({
  queryKey: ['app-data', userId] as const,
  queryFn: () => fetchAppData(userId),
})

export const collectionDataQueryOptions = (userId: string) => ({
  queryKey: ['collection-data', userId] as const,
  queryFn: () => fetchCollectionData(userId),
})

export const learningDashboardQueryOptions = (userId: string) => ({
  queryKey: ['learning-dashboard', userId] as const,
  queryFn: fetchLearningDashboard,
})

export const pointsSummaryQueryOptions = (userId: string) => ({
  queryKey: ['points-summary', userId] as const,
  queryFn: fetchPointsSummary,
})

export const practiceSetupCountsQueryOptions = (userId: string) => ({
  queryKey: ['practice-setup-counts', userId] as const,
  queryFn: fetchPracticeSetupCounts,
})

export const libraryDataQueryOptions = (userId: string, client: QueryClient) => ({
  queryKey: ['library-data', userId] as const,
  queryFn: async () => {
    const shell = await client.ensureQueryData(appDataQueryOptions(userId))
    return fetchLibraryData(userId, shell)
  },
})

export function useAppData() {
  const { user } = useAuth()
  return useQuery({
    ...appDataQueryOptions(user?.id ?? ''),
    enabled: Boolean(user),
  })
}

export function useLibraryData() {
  const { user } = useAuth()
  const queryClient = useQueryClient()
  return useQuery({
    ...libraryDataQueryOptions(user?.id ?? '', queryClient),
    enabled: Boolean(user),
  })
}

export function useLearningDashboard() {
  const { user } = useAuth()
  return useQuery({
    ...learningDashboardQueryOptions(user?.id ?? ''),
    enabled: Boolean(user),
  })
}

export function useCollectionData() {
  const { user } = useAuth()
  return useQuery({
    ...collectionDataQueryOptions(user?.id ?? ''),
    enabled: Boolean(user),
  })
}

export function usePracticeSetupCounts() {
  const { user } = useAuth()
  return useQuery({
    ...practiceSetupCountsQueryOptions(user?.id ?? ''),
    enabled: Boolean(user),
  })
}

export function usePracticeSetupMultiCount(
  sources: PracticeSource[],
  categoryIds: Category[],
  sourceAttemptId: string | null,
  enabled: boolean,
) {
  const { user } = useAuth()
  return useQuery({
    queryKey: ['practice-setup-multi-count', user?.id, [...sources].sort(), [...categoryIds].sort(), sourceAttemptId],
    queryFn: () => fetchPracticeSetupMultiCount({ sources, categoryIds, sourceAttemptId }),
    enabled: Boolean(user) && enabled,
  })
}

export function usePointsSummary() {
  const { user } = useAuth()
  return useQuery({
    ...pointsSummaryQueryOptions(user?.id ?? ''),
    enabled: Boolean(user),
  })
}

export function useProgressData() {
  const { user } = useAuth()
  return useQuery({
    queryKey: ['progress-data', user?.id],
    queryFn: fetchProgressData,
    enabled: Boolean(user),
  })
}
