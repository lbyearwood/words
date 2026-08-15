import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { PracticeAttemptData, UserCollection } from '../lib/types'
import { ResultsPage } from './ResultsPage'

const mocks = vi.hoisted(() => ({
  fetchPracticeAttempt: vi.fn(),
  fetchCollectionData: vi.fn(),
  saveToCollection: vi.fn(),
  setLikedState: vi.fn(),
  readAloud: vi.fn(),
  collections: [] as UserCollection[],
}))

vi.mock('../lib/api', () => ({
  fetchAppData: vi.fn(),
  fetchCollectionData: mocks.fetchCollectionData,
  fetchLearningDashboard: vi.fn(),
  fetchLibraryData: vi.fn(),
  fetchPointsSummary: vi.fn(),
  fetchPracticeAttempt: mocks.fetchPracticeAttempt,
  fetchPracticeSetupCounts: vi.fn(),
  fetchPracticeSetupMultiCount: vi.fn(),
  fetchProgressData: vi.fn(),
  saveToCollection: mocks.saveToCollection,
  setLikedState: mocks.setLikedState,
}))

vi.mock('../state/AuthContext', () => ({
  useAuth: () => ({ user: { id: 'max-id', email: 'max@example.test' } }),
}))

vi.mock('../state/SoundContext', () => ({
  useSound: () => ({ soundEnabled: false, playSound: vi.fn() }),
}))

vi.mock('../components/ConfettiCelebration', () => ({
  ConfettiCelebration: () => null,
}))

vi.mock('../components/ReadAloudButton', () => ({
  ReadAloudButton: ({ term, pronunciation }: { term: string; pronunciation?: string | null }) => (
    <button type="button" aria-label={`Read ${term} aloud`} onClick={() => mocks.readAloud(term, pronunciation)}>
      {pronunciation || 'Read aloud'}
    </button>
  ),
}))

function resultData(isCorrect = false): PracticeAttemptData {
  return {
    attempt: {
      id: 'attempt-1',
      user_id: 'max-id',
      source: 'mixed_library',
      category_id: null,
      source_attempt_id: null,
      requested_length: 1,
      actual_length: 1,
      status: 'completed',
      score: isCorrect ? 1 : 0,
      started_at: '2026-08-15T09:00:00.000Z',
      completed_at: '2026-08-15T09:00:30.000Z',
      duration_seconds: 30,
      focus_label: 'Mixed Library',
      points_earned: 10,
      point_system_version: 'v1',
    },
    answers: [{
      id: 'answer-1',
      attempt_id: 'attempt-1',
      user_id: 'max-id',
      knowledge_item_id: 'item-commemorate',
      position: 1,
      question_type: 'multiple_choice',
      prompt: 'Which meaning best matches Commemorate?',
      options: ['To honour and remember.', 'To obscure.'],
      correct_answer: 'To honour and remember.',
      selected_answer: isCorrect ? 'To honour and remember.' : 'To obscure.',
      is_correct: isCorrect,
      answered_at: '2026-08-15T09:00:20.000Z',
      term: 'Commemorate',
      pronunciation: 'com-MEM-o-rate',
      meaning: 'To honour and remember a person or event.',
      example_sentence: 'The team gathered to commemorate the milestone.',
      points_earned: isCorrect ? 10 : 0,
    }],
    points: {
      answer_points: isCorrect ? 10 : 0,
      recovery_points: 0,
      completion_points: 0,
      grade_points: 0,
      total_points: isCorrect ? 10 : 0,
      system_version: 'v1',
    },
  }
}

function collectionRow(overrides: Partial<UserCollection> = {}): UserCollection {
  return {
    user_id: 'max-id',
    knowledge_item_id: 'item-commemorate',
    state: 'saved',
    is_liked: false,
    is_disliked: false,
    created_at: '2026-08-15T09:00:00.000Z',
    updated_at: '2026-08-15T09:00:00.000Z',
    ...overrides,
  }
}

function renderResults() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  })

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={['/results/attempt-1']}>
        <Routes>
          <Route path="/results/:attemptId" element={<ResultsPage />} />
        </Routes>
      </MemoryRouter>
    </QueryClientProvider>,
  )
}

describe('ResultsPage missed-term actions', () => {
  afterEach(cleanup)

  beforeEach(() => {
    vi.clearAllMocks()
    mocks.collections.length = 0
    mocks.fetchPracticeAttempt.mockResolvedValue(resultData(false))
    mocks.fetchCollectionData.mockImplementation(async () => ({
      categories: [],
      items: [],
      collections: [...mocks.collections],
      confidence: [],
    }))
    mocks.saveToCollection.mockImplementation(async (userId: string, itemId: string) => {
      mocks.collections.splice(0, mocks.collections.length, collectionRow({ user_id: userId, knowledge_item_id: itemId }))
    })
    mocks.setLikedState.mockImplementation(async (userId: string, itemId: string, isLiked: boolean) => {
      mocks.collections.splice(0, mocks.collections.length, collectionRow({
        user_id: userId,
        knowledge_item_id: itemId,
        is_liked: isLiked,
      }))
    })
  })

  it('renders accessible Collection, favourite and read-aloud controls for a missed term', async () => {
    renderResults()

    const save = await screen.findByRole('button', { name: 'Add to My Collection: Commemorate' })
    await waitFor(() => expect(save).toBeEnabled())
    expect(screen.getByRole('button', { name: 'Add to favourites: Commemorate' })).toBeEnabled()
    const readAloud = screen.getByRole('button', { name: 'Read Commemorate aloud' })
    expect(readAloud).toBeEnabled()

    fireEvent.click(readAloud)
    expect(mocks.readAloud).toHaveBeenCalledWith('Commemorate', 'com-MEM-o-rate')
  })

  it('saves the missed term using its learning-item identifier', async () => {
    renderResults()

    const save = await screen.findByRole('button', { name: 'Add to My Collection: Commemorate' })
    await waitFor(() => expect(save).toBeEnabled())
    fireEvent.click(save)

    await waitFor(() => expect(mocks.saveToCollection).toHaveBeenCalledWith('max-id', 'item-commemorate'))
    expect(await screen.findByRole('button', { name: 'Saved in My Collection: Commemorate' })).toHaveAttribute('aria-pressed', 'true')
  })

  it('liking a missed term targets the correct item and refreshes both liked and saved state', async () => {
    renderResults()

    const like = await screen.findByRole('button', { name: 'Add to favourites: Commemorate' })
    await waitFor(() => expect(like).toBeEnabled())
    fireEvent.click(like)

    await waitFor(() => expect(mocks.setLikedState).toHaveBeenCalledWith('max-id', 'item-commemorate', true))
    expect(await screen.findByRole('button', { name: 'Remove from favourites: Commemorate' })).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByRole('button', { name: 'Saved in My Collection: Commemorate' })).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByRole('status')).toHaveTextContent('Added to favourites and My Collection.')
  })

  it('does not render term action controls when every answer was correct', async () => {
    mocks.fetchPracticeAttempt.mockResolvedValue(resultData(true))
    renderResults()

    expect(await screen.findByRole('heading', { name: 'No missed terms' })).toBeVisible()
    expect(screen.queryByRole('button', { name: /My Collection:|favourites:|Read .* aloud/i })).not.toBeInTheDocument()
    expect(mocks.fetchCollectionData).not.toHaveBeenCalled()
  })
})
