import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, ArrowRight, Bookmark, BookmarkCheck, CheckCircle2, Heart, ThumbsDown, XCircle } from 'lucide-react'
import { Navigate, useNavigate, useParams } from 'react-router-dom'
import { ErrorState, LoadingState } from '../components/PageState'
import { ReadAloudButton } from '../components/ReadAloudButton'
import { fetchCollectionItem, fetchPracticeAttempt, saveToCollection, setDislikedState, setLikedState, submitPracticeAnswer } from '../lib/api'
import type { AnswerFeedback, PracticeAttemptData } from '../lib/types'
import { useAuth } from '../state/AuthContext'
import { useSound } from '../state/SoundContext'

type PreferenceAction = 'save' | 'like' | 'unlike' | 'dislike' | 'remove_dislike'

interface PreferenceMutationInput {
  action: PreferenceAction
  itemId: string
}

interface SubmittedFeedback {
  answerId: string
  answerIndex: number
  selectedAnswer: string
  result: AnswerFeedback
}

export function PracticePage() {
  const { user } = useAuth()
  const { playSound } = useSound()
  const { attemptId = '' } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [selected, setSelected] = useState('')
  const [submittedFeedback, setSubmittedFeedback] = useState<SubmittedFeedback | null>(null)
  const [localIndex, setLocalIndex] = useState<number | null>(null)
  const [error, setError] = useState('')
  const [preferenceMessage, setPreferenceMessage] = useState<{ itemId: string; text: string } | null>(null)
  const queryKey = ['practice-attempt', attemptId] as const
  const query = useQuery({
    queryKey,
    queryFn: () => fetchPracticeAttempt(attemptId),
    enabled: Boolean(attemptId),
  })

  const firstUnansweredIndex = useMemo(
    () => query.data?.answers.findIndex((answer) => answer.answered_at === null) ?? 0,
    [query.data],
  )
  const hasUnanswered = firstUnansweredIndex >= 0
  const frontierIndex = hasUnanswered
    ? firstUnansweredIndex
    : Math.max(0, (query.data?.answers.length ?? 1) - 1)
  const requestedIndex = localIndex ?? frontierIndex
  const activeIndex = Math.min(Math.max(0, requestedIndex), frontierIndex)
  const current = query.data?.answers[activeIndex]
  const currentSubmission = submittedFeedback?.answerId === current?.id ? submittedFeedback : null
  const isAnswered = Boolean(current?.answered_at || currentSubmission)
  const isHistoricalReview = isAnswered && activeIndex < frontierIndex && !currentSubmission

  const preferenceQuery = useQuery({
    queryKey: ['collection-item', user?.id, current?.knowledge_item_id],
    queryFn: () => fetchCollectionItem(user!.id, current!.knowledge_item_id),
    enabled: Boolean(user && current),
  })

  const preferenceMutation = useMutation({
    mutationFn: async ({ action, itemId }: PreferenceMutationInput) => {
      if (!user) throw new Error('This term is unavailable.')
      if (action === 'like' || action === 'unlike') {
        await setLikedState(user.id, itemId, action === 'like')
      } else if (action === 'dislike' || action === 'remove_dislike') {
        await setDislikedState(user.id, itemId, action === 'dislike')
      } else {
        await saveToCollection(user.id, itemId)
      }
      return action
    },
    onSuccess: async (action, variables) => {
      setError('')
      const text = action === 'like' ? 'Added to favourites and your Collection.'
        : action === 'unlike' ? 'Removed from favourites.'
          : action === 'dislike' ? 'Marked as disliked. This term will remain available.'
            : action === 'remove_dislike' ? 'Dislike removed.'
              : 'Saved in My Collection.'
      setPreferenceMessage({ itemId: variables.itemId, text })
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ['collection-item', user?.id, variables.itemId] }),
        queryClient.invalidateQueries({ queryKey: ['app-data', user?.id] }),
      ])
    },
    onError: (caught) => setError(caught instanceof Error ? caught.message : 'Unable to update this term.'),
  })

  const answerMutation = useMutation({
    mutationFn: ({ answerId, selectedAnswer }: { answerId: string; selectedAnswer: string; answerIndex: number }) => (
      submitPracticeAnswer(answerId, selectedAnswer)
    ),
    onSuccess: (result, variables) => {
      const submission = {
        answerId: variables.answerId,
        answerIndex: variables.answerIndex,
        selectedAnswer: variables.selectedAnswer,
        result,
      }
      setLocalIndex(variables.answerIndex)
      setSubmittedFeedback(submission)
      setError('')
      queryClient.setQueryData<PracticeAttemptData>(queryKey, (existing) => {
        if (!existing) return existing
        return {
          ...existing,
          answers: existing.answers.map((answer) => answer.id === variables.answerId
            ? {
              ...answer,
              selected_answer: variables.selectedAnswer,
              correct_answer: result.correct_answer,
              is_correct: result.is_correct,
              answered_at: answer.answered_at ?? new Date().toISOString(),
              points_earned: result.points_earned,
              term: result.term,
              meaning: result.meaning,
              example_sentence: result.example_sentence,
            }
            : answer),
        }
      })
      playSound(result.is_correct ? 'correct' : 'incorrect')
    },
    onError: (caught) => setError(caught instanceof Error ? caught.message : 'Unable to save your answer.'),
  })

  function showQuestion(index: number) {
    if (!query.data || index < 0 || index > frontierIndex) return
    if (currentSubmission) setSelected('')
    setLocalIndex(index === frontierIndex ? null : index)
    setSubmittedFeedback(null)
    setPreferenceMessage(null)
    setError('')
  }

  function returnToCurrentQuestion() {
    showQuestion(frontierIndex)
  }

  async function finishAttempt() {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey }),
      queryClient.invalidateQueries({ queryKey: ['app-data'] }),
      queryClient.invalidateQueries({ queryKey: ['learning-dashboard'] }),
      queryClient.invalidateQueries({ queryKey: ['points-summary'] }),
      queryClient.invalidateQueries({ queryKey: ['progress-data'] }),
      queryClient.invalidateQueries({ queryKey: ['practice-setup-counts'] }),
    ])
    navigate(`/results/${attemptId}`, { replace: true })
  }

  async function continueAfterFeedback() {
    if (!query.data || !currentSubmission) return
    if (currentSubmission.result.attempt_completed || !hasUnanswered) {
      await finishAttempt()
      return
    }
    returnToCurrentQuestion()
  }

  if (query.isLoading) return <LoadingState label="Opening your question…" />
  if (query.error || !query.data || !current) return <ErrorState message={query.error?.message ?? 'Attempt not found.'} />
  if (query.data.attempt.status === 'completed') return <Navigate to={`/results/${attemptId}`} replace />

  const reachedQuestionCount = hasUnanswered ? frontierIndex + 1 : query.data.answers.length
  const progress = (reachedQuestionCount / query.data.answers.length) * 100
  const preference = preferenceQuery.data
  const isSaved = preference?.state === 'saved'
  const isLiked = isSaved && preference?.is_liked
  const isDisliked = preference?.is_disliked ?? false
  const selectedAnswer = isAnswered
    ? current.selected_answer ?? currentSubmission?.selectedAnswer ?? ''
    : selected
  const correctAnswer = current.correct_answer ?? currentSubmission?.result.correct_answer ?? null
  const answerWasCorrect = current.is_correct ?? currentSubmission?.result.is_correct ?? false
  const term = currentSubmission?.result.term ?? current.term ?? ''
  const meaning = currentSubmission?.result.meaning ?? current.meaning ?? correctAnswer ?? ''
  const exampleSentence = currentSubmission?.result.example_sentence ?? current.example_sentence ?? ''
  const pointsEarned = currentSubmission?.result.points_earned ?? current.points_earned
  const visiblePreferenceMessage = preferenceMessage?.itemId === current.knowledge_item_id
    ? preferenceMessage.text
    : ''

  return (
    <div className="page question-page">
      <header className="question-header">
        <div className="question-history-controls" aria-label="Question review navigation">
          <button
            className="icon-button"
            data-tooltip="Previous question"
            onClick={() => showQuestion(activeIndex - 1)}
            disabled={activeIndex === 0}
            aria-label="Previous question"
          >
            <ArrowLeft aria-hidden="true" />
          </button>
          <strong>{isHistoricalReview ? 'Reviewing' : 'Question'} {activeIndex + 1} of {query.data.answers.length}</strong>
          <button
            className="icon-button"
            data-tooltip="Next reviewed question"
            onClick={() => showQuestion(activeIndex + 1)}
            disabled={activeIndex >= frontierIndex}
            aria-label="Next reviewed question"
          >
            <ArrowRight aria-hidden="true" />
          </button>
        </div>
        <button className="text-link question-leave" onClick={() => navigate('/practice')}>Leave practice</button>
      </header>
      <div className="question-progress" aria-label={`${Math.round(progress)}% complete`}><span style={{ width: `${progress}%` }} /></div>
      <section className="question-panel">
        {isHistoricalReview ? (
          <div className="question-review-notice" role="status">
            <div>
              <strong>Reviewing question {activeIndex + 1}</strong>
              <span>Answer locked. Your response and score cannot be changed.</span>
            </div>
            <button className="text-link" onClick={returnToCurrentQuestion}>Return to question {frontierIndex + 1}</button>
          </div>
        ) : null}
        <div className="question-context-row">
          <p className="question-type">{current.question_type.replaceAll('_', ' ')}</p>
          <div className="question-item-actions" aria-label="Term actions">
            <button className={`icon-button ${isSaved ? 'is-selected' : ''}`} disabled={preferenceMutation.isPending} aria-label={isSaved ? 'Saved in My Collection' : 'Add to My Collection'} data-tooltip={isSaved ? 'Saved in My Collection' : 'Add to My Collection'} onClick={() => preferenceMutation.mutate({ action: 'save', itemId: current.knowledge_item_id })}>
              {isSaved ? <BookmarkCheck aria-hidden="true" /> : <Bookmark aria-hidden="true" />}
            </button>
            <button className={`icon-button ${isLiked ? 'is-liked' : ''}`} disabled={preferenceMutation.isPending} aria-label={isLiked ? 'Remove from favourites' : 'Add to favourites'} data-tooltip={isLiked ? 'Remove from favourites' : 'Add to favourites'} onClick={() => preferenceMutation.mutate({ action: isLiked ? 'unlike' : 'like', itemId: current.knowledge_item_id })}>
              <Heart aria-hidden="true" fill={isLiked ? 'currentColor' : 'none'} />
            </button>
            <button className={`icon-button ${isDisliked ? 'is-disliked' : ''}`} disabled={preferenceMutation.isPending} aria-label={isDisliked ? 'Remove dislike' : 'Dislike'} data-tooltip={isDisliked ? 'Remove dislike' : 'Dislike'} onClick={() => preferenceMutation.mutate({ action: isDisliked ? 'remove_dislike' : 'dislike', itemId: current.knowledge_item_id })}>
              <ThumbsDown aria-hidden="true" fill={isDisliked ? 'currentColor' : 'none'} />
            </button>
          </div>
        </div>
        {visiblePreferenceMessage ? <p className="question-preference-message" role="status">{visiblePreferenceMessage}</p> : null}
        <div className="question-prompt-row">
          <h1>{current.prompt}</h1>
          {current.term ? <ReadAloudButton term={current.term} pronunciation={current.pronunciation} /> : null}
        </div>
        <p>{isAnswered ? 'Review the locked answer and feedback.' : 'Tap one answer'}</p>
        <div className="answer-options">
          {current.options.map((option, optionIndex) => {
            const isCorrect = isAnswered && option === correctAnswer
            const isWrongSelection = isAnswered && option === selectedAnswer && !answerWasCorrect
            return (
              <button
                key={option}
                className={`${selectedAnswer === option ? 'is-selected' : ''}${isCorrect ? ' is-correct' : ''}${isWrongSelection ? ' is-incorrect' : ''}`}
                onClick={() => setSelected(option)}
                disabled={isAnswered}
              >
                <span className="option-marker">{String.fromCharCode(65 + optionIndex)}</span>
                <span>{option}</span>
              </button>
            )
          })}
        </div>
        {isAnswered ? (
          <section className={`answer-feedback ${answerWasCorrect ? 'is-correct' : 'is-incorrect'}`} role="status">
            {answerWasCorrect ? <CheckCircle2 aria-hidden="true" /> : <XCircle aria-hidden="true" />}
            <div>
              <div className="answer-feedback-heading">
                <strong>{answerWasCorrect ? 'Correct' : 'Not quite'}</strong>
                {answerWasCorrect
                  ? <b className="answer-points-earned">+{pointsEarned} points</b>
                  : <b className="answer-points-empty">No points yet</b>}
              </div>
              <p><b>{term}</b> — {meaning}</p>
              {exampleSentence ? <small>{exampleSentence}</small> : null}
              {currentSubmission && currentSubmission.result.recovery_points > 0 ? <small className="recovery-points">Includes +{currentSubmission.result.recovery_points} recovery points.</small> : null}
              {!answerWasCorrect ? <small className="points-encouragement">This term will be prioritised so you can earn points when you retrieve it later.</small> : null}
              {currentSubmission && currentSubmission.result.attempt_completed && currentSubmission.result.completion_points + currentSubmission.result.grade_points > 0
                ? <small className="test-bonus-points">Test bonuses: +{currentSubmission.result.completion_points + currentSubmission.result.grade_points} points.</small>
                : null}
            </div>
          </section>
        ) : null}
        {error ? <p className="form-error" role="alert">{error}</p> : null}
        <footer className="question-panel-footer">
          {currentSubmission ? (
            <button className="primary-button question-next" onClick={continueAfterFeedback}>
              {currentSubmission.result.attempt_completed || !hasUnanswered ? 'See results' : 'Next'} <ArrowRight aria-hidden="true" />
            </button>
          ) : isHistoricalReview ? (
            <button className="primary-button question-next" onClick={returnToCurrentQuestion}>
              Return to question {frontierIndex + 1} <ArrowRight aria-hidden="true" />
            </button>
          ) : isAnswered && !hasUnanswered ? (
            <button className="primary-button question-next" onClick={finishAttempt}>
              See results <ArrowRight aria-hidden="true" />
            </button>
          ) : (
            <button
              className="primary-button question-next"
              disabled={!selected || answerMutation.isPending}
              onClick={() => answerMutation.mutate({ answerId: current.id, selectedAnswer: selected, answerIndex: activeIndex })}
            >
              {answerMutation.isPending ? 'Checking…' : 'Check answer'} <ArrowRight aria-hidden="true" />
            </button>
          )}
        </footer>
      </section>
    </div>
  )
}
