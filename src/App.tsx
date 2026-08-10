import { lazy, Suspense } from 'react'
import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from './components/AppShell'
import { LoadingState } from './components/PageState'
import { useAuth } from './state/AuthContext'
import { SignInPage } from './pages/SignInPage'

const HomePage = lazy(() => import('./pages/HomePage').then((module) => ({ default: module.HomePage })))
const LibraryPage = lazy(() => import('./pages/LibraryPage').then((module) => ({ default: module.LibraryPage })))
const CollectionPage = lazy(() => import('./pages/CollectionPage').then((module) => ({ default: module.CollectionPage })))
const PracticeSetupPage = lazy(() => import('./pages/PracticeSetupPage').then((module) => ({ default: module.PracticeSetupPage })))
const PracticePage = lazy(() => import('./pages/PracticePage').then((module) => ({ default: module.PracticePage })))
const ResultsPage = lazy(() => import('./pages/ResultsPage').then((module) => ({ default: module.ResultsPage })))
const ProgressPage = lazy(() => import('./pages/ProgressPage').then((module) => ({ default: module.ProgressPage })))
const ProfilePage = lazy(() => import('./pages/ProfilePage').then((module) => ({ default: module.ProfilePage })))

export function App() {
  const { user, loading } = useAuth()
  if (loading) return <LoadingState label="Opening Brain Express…" />
  if (!user) return <SignInPage />

  return (
    <Suspense fallback={<LoadingState />}>
      <Routes>
        <Route element={<AppShell />}>
          <Route index element={<HomePage />} />
          <Route path="library" element={<LibraryPage />} />
          <Route path="collection" element={<CollectionPage />} />
          <Route path="practice" element={<PracticeSetupPage />} />
          <Route path="practice/:attemptId" element={<PracticePage />} />
          <Route path="results/:attemptId" element={<ResultsPage />} />
          <Route path="progress" element={<ProgressPage />} />
          <Route path="profile" element={<ProfilePage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </Suspense>
  )
}
