import { useQuery } from '@tanstack/react-query'
import { fetchAppData, fetchCollectionData, fetchLearningDashboard, fetchPointsSummary, fetchPracticeSetupCounts, fetchProgressData } from '../lib/api'
import { useAuth } from '../state/AuthContext'

export function useAppData() {
  const { user } = useAuth()
  return useQuery({
    queryKey: ['app-data', user?.id],
    queryFn: () => fetchAppData(user!.id),
    enabled: Boolean(user),
  })
}

export function useLearningDashboard() {
  const { user } = useAuth()
  return useQuery({
    queryKey: ['learning-dashboard', user?.id],
    queryFn: fetchLearningDashboard,
    enabled: Boolean(user),
  })
}

export function useCollectionData() {
  const { user } = useAuth()
  return useQuery({
    queryKey: ['collection-data', user?.id],
    queryFn: () => fetchCollectionData(user!.id),
    enabled: Boolean(user),
  })
}

export function usePracticeSetupCounts() {
  const { user } = useAuth()
  return useQuery({
    queryKey: ['practice-setup-counts', user?.id],
    queryFn: fetchPracticeSetupCounts,
    enabled: Boolean(user),
  })
}

export function usePointsSummary() {
  const { user } = useAuth()
  return useQuery({
    queryKey: ['points-summary', user?.id],
    queryFn: fetchPointsSummary,
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
