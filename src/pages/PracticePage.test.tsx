import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { PracticeAttemptData } from '../lib/types'
import { PracticePage } from './PracticePage'

const mocks = vi.hoisted(() => ({
  fetchCollectionItem: vi.fn(),
  fetchPracticeAttempt: vi.fn(),
  playSound: vi.fn(),
  saveToCollection: vi.fn(),
  setDislikedState: vi.fn(),
  setLikedState: vi.fn(),
  submitPracticeAnswer: vi.fn(),
}))

vi.mock('../lib/api', () => ({
  fetchCollectionItem: mocks.fetchCollectionItem,
  fetchPracticeAttempt: mocks.fetchPracticeAttempt,
  saveToCollection: mocks.saveToCollection,
  setDislikedState: mocks.setDislikedState,
  setLikedState: mocks.setLikedState,
  submitPracticeAnswer: mocks.submitPracticeAnswer,
}))

vi.mock('../state/AuthContext', () => ({
  useAuth: () => ({ user: { id: 'max-test' } }),
}))

vi.mock('../state/SoundContext', () => ({
  useSound: () => ({ playSound: mocks.playSound }),
}))

const attempt: PracticeAttemptData = {
  attempt: {
    id: 'attempt-1',
    user_id: 'max-test',
    source: 'recommended',
    category_id: null,
    source_attempt_id: null,
    requested_length: 3,
    actual_length: 3,
    status: 'in_progress',
    score: 0,
    started_at: '2026-08-15T09:00:00.000Z',
    completed_at: null,
    duration_seconds: null,
    focus_label: 'Recommended for you',
    points_earned: 0,
    point_system_version: 'v1',
  },
  answers: [
    {
      id: 'answer-1',
      attempt_id: 'attempt-1',
      user_id: 'max-test',
      knowledge_item_id: 'item-1',
      position: 1,
      question_type: 'multiple_choice',
      prompt: 'Which meaning best matches "Commemorate"?',
      options: ['A forceful objection.', 'To honour and remember a person or event.', 'An uncertain prediction.'],
      correct_answer: 'To honour and remember a person or event.',
      selected_answer: 'A forceful objection.',
      is_correct: false,
      answered_at: '2026-08-15T09:00:20.000Z',
      term: 'Commemorate',
      pronunciation: 'com-MEM-o-rate',
      meaning: 'To honour and remember a person or event.',
      example_sentence: 'The team held an event to commemorate the organisation\'s anniversary.',
      points_earned: 0,
    },
    {
      id: 'answer-2',
      attempt_id: 'attempt-1',
      user_id: 'max-test',
      knowledge_item_id: 'item-2',
      position: 2,
      question_type: 'multiple_choice',
      prompt: 'Which meaning best matches "Cogent"?',
      options: ['Clear, logical and convincing.', 'Needlessly complicated.', 'Brief and uncertain.'],
      correct_answer: null,
      selected_answer: null,
      is_correct: null,
      answered_at: null,
      term: 'Cogent',
      pronunciation: 'CO-jent',
      points_earned: 0,
    },
    {
      id: 'answer-3',
      attempt_id: 'attempt-1',
      user_id: 'max-test',
      knowledge_item_id: 'item-3',
      position: 3,
      question_type: 'true_false',
      prompt: '"Salient" means the most noticeable or important.',
      options: ['True', 'False'],
      correct_answer: null,
      selected_answer: null,
      is_correct: null,
      answered_at: null,
      term: 'Salient',
      pronunciation: 'SAY-lee-ent',
      points_earned: 0,
    },
  ],
  points: {
    answer_points: 0,
    recovery_points: 0,
    completion_points: 0,
    grade_points: 0,
    total_points: 0,
    system_version: 'v1',
  },
}

class MockSpeechSynthesisUtterance {
  lang = ''
  rate = 1
  pitch = 1
  voice: SpeechSynthesisVoice | null = null
  onend: (() => void) | null = null
  onerror: (() => void) | null = null

  constructor(public text: string) {}
}

function renderPractice() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  })

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={['/practice/attempt-1']}>
        <Routes>
          <Route path="/practice/:attemptId" element={<PracticePage />} />
          <Route path="/practice" element={<div>Practice setup</div>} />
          <Route path="/results/:attemptId" element={<div>Results</div>} />
        </Routes>
      </MemoryRouter>
    </QueryClientProvider>,
  )
}

async function openHistoricalReview() {
  await screen.findByRole('heading', { name: 'Which meaning best matches "Cogent"?' })
  fireEvent.click(screen.getByRole('button', { name: /Clear, logical and convincing\./ }))
  expect(screen.getByRole('button', { name: /Clear, logical and convincing\./ })).toHaveClass('is-selected')

  fireEvent.click(screen.getByRole('button', { name: 'Previous question' }))
  await screen.findByText('Answer locked. Your response and score cannot be changed.')
}

describe('PracticePage locked answer review', () => {
  beforeEach(() => {
    mocks.fetchPracticeAttempt.mockResolvedValue(attempt)
    mocks.fetchCollectionItem.mockResolvedValue(null)
    mocks.saveToCollection.mockResolvedValue(undefined)
    mocks.setDislikedState.mockResolvedValue(undefined)
    mocks.setLikedState.mockResolvedValue(undefined)
    mocks.submitPracticeAnswer.mockReset()
    mocks.playSound.mockReset()

    vi.stubGlobal('SpeechSynthesisUtterance', MockSpeechSynthesisUtterance)
    Object.defineProperty(window, 'speechSynthesis', {
      configurable: true,
      value: {
        cancel: vi.fn(),
        getVoices: vi.fn(() => []),
        speak: vi.fn(),
      },
    })
  })

  afterEach(() => {
    cleanup()
    vi.clearAllMocks()
    vi.unstubAllGlobals()
  })

  it('locks persisted answers, keeps the frontier progress and preserves the current draft', async () => {
    renderPractice()
    await openHistoricalReview()

    expect(screen.getByText('Reviewing question 1')).toBeVisible()
    expect(screen.getByLabelText('67% complete')).toBeVisible()

    const savedWrongAnswer = screen.getByRole('button', { name: /A forceful objection\./ })
    const savedCorrectAnswer = screen.getByRole('button', { name: /To honour and remember a person or event\./ })
    expect(savedWrongAnswer).toBeDisabled()
    expect(savedWrongAnswer).toHaveClass('is-selected', 'is-incorrect')
    expect(savedCorrectAnswer).toBeDisabled()
    expect(savedCorrectAnswer).toHaveClass('is-correct')
    expect(screen.queryByRole('button', { name: /check answer/i })).not.toBeInTheDocument()
    expect(mocks.submitPracticeAnswer).not.toHaveBeenCalled()

    fireEvent.click(screen.getAllByRole('button', { name: 'Return to question 2' })[0])
    await screen.findByRole('heading', { name: 'Which meaning best matches "Cogent"?' })

    expect(screen.getByRole('button', { name: /Clear, logical and convincing\./ })).toHaveClass('is-selected')
    expect(screen.getByRole('button', { name: /check answer/i })).toBeEnabled()
    expect(screen.getByLabelText('67% complete')).toBeVisible()
  })

  it('keeps collection, favourite, dislike and read-aloud controls available in review', async () => {
    renderPractice()
    await openHistoricalReview()

    await waitFor(() => expect(mocks.fetchCollectionItem).toHaveBeenCalledWith('max-test', 'item-1'))
    expect(screen.getByRole('button', { name: 'Add to My Collection' })).toBeEnabled()
    expect(screen.getByRole('button', { name: 'Add to favourites' })).toBeEnabled()
    expect(screen.getByRole('button', { name: 'Dislike' })).toBeEnabled()
    expect(screen.getByRole('button', { name: 'Read Commemorate aloud' })).toBeEnabled()
  })
})
