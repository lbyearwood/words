import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, ArrowRight, Bookmark, BookmarkCheck, CheckCircle2, Heart, ThumbsDown, XCircle } from 'lucide-react'
import { Navigate, useNavigate, useParams } from 'react-router-dom'
import { ErrorState, LoadingState } from '../components/PageState'
import { fetchCollectionItem, fetchPracticeAttempt, saveToCollection, setDislikedState, setLikedState, submitPracticeAnswer } from '../lib/api'
import type { AnswerFeedback } from '../lib/types'
import { useAuth } from '../state/AuthContext'
import { useSound } from '../state/SoundContext'

export function PracticePage() {
  const { user } = useAuth()
  const { playSound } = useSound()
  const { attemptId = '' } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [selected, setSelected] = useState('')
  const [feedback, setFeedback] = useState<AnswerFeedback | null>(null)
  const [localIndex, setLocalIndex] = useState<number | null>(null)
  const [error, setError] = useState('')
  const [preferenceMessage, setPreferenceMessage] = useState('')
  const query = useQuery({
    queryKey: ['practice-attempt', attemptId],
    queryFn: () => fetchPracticeAttempt(attemptId),
    enabled: Boolean(attemptId),
  })

  const firstUnanswered = useMemo(
    () => query.data?.answers.findIndex((answer) => answer.answered_at === null) ?? 0,
    [query.data],
  )
  const activeIndex = localIndex ?? Math.max(0, firstUnanswered)
  const current = query.data?.answers[activeIndex]

  const preferenceQuery = useQuery({
    queryKey: ['collection-item', user?.id, current?.knowledge_item_id],
    queryFn: () => fetchCollectionItem(user!.id, current!.knowledge_item_id),
    enabled: Boolean(user && current),
  })

  const preferenceMutation = useMutation({
    mutationFn: async (action: 'save' | 'like' | 'unlike' | 'dislike' | 'remove_dislike') => {
      if (!user || !current) throw new Error('This term is unavailable.')
      if (action === 'like' || action === 'unlike') {
        await setLikedState(user.id, current.knowledge_item_id, action === 'like')
      } else if (action === 'dislike' || action === 'remove_dislike') {
        await setDislikedState(user.id, current.knowledge_item_id, action === 'dislike')
      } else {
        await saveToCollection(user.id, current.knowledge_item_id)
      }
      return action
    },
    onSuccess: async (action) => {
      setError('')
      setPreferenceMessage(action === 'like' ? 'Added to favourites and your Collection.'
        : action === 'unlike' ? 'Removed from favourites.'
          : action === 'dislike' ? 'Marked as disliked. This term will remain available.'
            : action === 'remove_dislike' ? 'Dislike removed.'
              : 'Saved in My Collection.')
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ['collection-item', user?.id, current?.knowledge_item_id] }),
        queryClient.invalidateQueries({ queryKey: ['app-data', user?.id] }),
      ])
    },
    onError: (caught) => setError(caught instanceof Error ? caught.message : 'Unable to update this term.'),
  })

  const answerMutation = useMutation({
    mutationFn: () => submitPracticeAnswer(current!.id, selected),
    onSuccess: (result) => {
      setFeedback(result)
      setError('')
      playSound(result.is_correct ? 'correct' : 'incorrect')
    },
    onError: (caught) => setError(caught instanceof Error ? caught.message : 'Unable to save your answer.'),
  })

  async function moveNext() {
    if (!query.data || !feedback) return
    if (feedback.attempt_completed || activeIndex === query.data.answers.length - 1) {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ['practice-attempt', attemptId] }),
        queryClient.invalidateQueries({ queryKey: ['app-data'] }),
        queryClient.invalidateQueries({ queryKey: ['learning-dashboard'] }),
        queryClient.invalidateQueries({ queryKey: ['points-summary'] }),
        queryClient.invalidateQueries({ queryKey: ['progress-data'] }),
        queryClient.invalidateQueries({ queryKey: ['practice-setup-counts'] }),
      ])
      navigate(`/results/${attemptId}`, { replace: true })
      return
    }
    setLocalIndex(activeIndex + 1)
    setSelected('')
    setFeedback(null)
    setPreferenceMessage('')
  }

  if (query.isLoading) return <LoadingState label="Opening your question…" />
  if (query.error || !query.data || !current) return <ErrorState message={query.error?.message ?? 'Attempt not found.'} />
  if (query.data.attempt.status === 'completed') return <Navigate to={`/results/${attemptId}`} replace />

  const progress = ((activeIndex + 1) / query.data.answers.length) * 100
  const preference = preferenceQuery.data
  const isSaved = preference?.state === 'saved'
  const isLiked = isSaved && preference?.is_liked
  const isDisliked = preference?.is_disliked ?? false

  return (
    <div className="page question-page">
      <header className="question-header">
        <button className="icon-button" data-tooltip="Leave practice" onClick={() => navigate('/practice')} aria-label="Leave practice"><ArrowLeft /></button>
        <strong>Question {activeIndex + 1} of {query.data.answers.length}</strong>
      </header>
      <div className="question-progress" aria-label={`${Math.round(progress)}% complete`}><span style={{ width: `${progress}%` }} /></div>
      <section className="question-panel">
        <div className="question-context-row">
          <p className="question-type">{current.question_type.replaceAll('_', ' ')}</p>
          <div className="question-item-actions" aria-label="Term actions">
            <button className={`icon-button ${isSaved ? 'is-selected' : ''}`} disabled={preferenceMutation.isPending} aria-label={isSaved ? 'Saved in My Collection' : 'Add to My Collection'} data-tooltip={isSaved ? 'Saved in My Collection' : 'Add to My Collection'} onClick={() => preferenceMutation.mutate('save')}>
              {isSaved ? <BookmarkCheck aria-hidden="true" /> : <Bookmark aria-hidden="true" />}
            </button>
            <button className={`icon-button ${isLiked ? 'is-liked' : ''}`} disabled={preferenceMutation.isPending} aria-label={isLiked ? 'Remove from favourites' : 'Add to favourites'} data-tooltip={isLiked ? 'Remove from favourites' : 'Add to favourites'} onClick={() => preferenceMutation.mutate(isLiked ? 'unlike' : 'like')}>
              <Heart aria-hidden="true" fill={isLiked ? 'currentColor' : 'none'} />
            </button>
            <button className={`icon-button ${isDisliked ? 'is-disliked' : ''}`} disabled={preferenceMutation.isPending} aria-label={isDisliked ? 'Remove dislike' : 'Dislike'} data-tooltip={isDisliked ? 'Remove dislike' : 'Dislike'} onClick={() => preferenceMutation.mutate(isDisliked ? 'remove_dislike' : 'dislike')}>
              <ThumbsDown aria-hidden="true" fill={isDisliked ? 'currentColor' : 'none'} />
            </button>
          </div>
        </div>
        {preferenceMessage ? <p className="question-preference-message" role="status">{preferenceMessage}</p> : null}
        <h1>{current.prompt}</h1>
        <p>{feedback ? 'Review the answer, then keep going.' : 'Tap one answer'}</p>
        <div className="answer-options">
          {current.options.map((option, optionIndex) => {
            const isCorrect = feedback && option === feedback.correct_answer
            const isWrongSelection = feedback && option === selected && !feedback.is_correct
            return (
              <button
                key={option}
                className={`${selected === option ? 'is-selected' : ''}${isCorrect ? ' is-correct' : ''}${isWrongSelection ? ' is-incorrect' : ''}`}
                onClick={() => setSelected(option)}
                disabled={Boolean(feedback)}
              >
                <span className="option-marker">{String.fromCharCode(65 + optionIndex)}</span>
                <span>{option}</span>
              </button>
            )
          })}
        </div>
        {feedback ? (
          <section className={`answer-feedback ${feedback.is_correct ? 'is-correct' : 'is-incorrect'}`} role="status">
            {feedback.is_correct ? <CheckCircle2 aria-hidden="true" /> : <XCircle aria-hidden="true" />}
            <div>
              <div className="answer-feedback-heading">
                <strong>{feedback.is_correct ? 'Correct' : 'Not quite'}</strong>
                {feedback.is_correct
                  ? <b className="answer-points-earned">+{feedback.points_earned} points</b>
                  : <b className="answer-points-empty">No points yet</b>}
              </div>
              <p><b>{feedback.term}</b> — {feedback.meaning}</p>
              <small>{feedback.example_sentence}</small>
              {feedback.recovery_points > 0 ? <small className="recovery-points">Includes +{feedback.recovery_points} recovery points.</small> : null}
              {!feedback.is_correct ? <small className="points-encouragement">This term will be prioritised so you can earn points when you retrieve it later.</small> : null}
              {feedback.attempt_completed && feedback.completion_points + feedback.grade_points > 0
                ? <small className="test-bonus-points">Test bonuses: +{feedback.completion_points + feedback.grade_points} points.</small>
                : null}
            </div>
          </section>
        ) : null}
        {error ? <p className="form-error" role="alert">{error}</p> : null}
        <footer className="question-panel-footer">
          {feedback ? (
            <button className="primary-button question-next" onClick={moveNext}>
              {feedback.attempt_completed || activeIndex === query.data.answers.length - 1 ? 'See results' : 'Next'} <ArrowRight aria-hidden="true" />
            </button>
          ) : (
            <button className="primary-button question-next" disabled={!selected || answerMutation.isPending} onClick={() => answerMutation.mutate()}>
              {answerMutation.isPending ? 'Checking…' : 'Check answer'} <ArrowRight aria-hidden="true" />
            </button>
          )}
        </footer>
      </section>
    </div>
  )
}
