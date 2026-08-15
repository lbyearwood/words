import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Bookmark, BookmarkCheck, CheckCircle2, Clock3, Heart, RotateCcw, Sparkles, Trophy, XCircle } from 'lucide-react'
import { Link, useParams } from 'react-router-dom'
import { ConfettiCelebration } from '../components/ConfettiCelebration'
import { ErrorState, LoadingState } from '../components/PageState'
import { ReadAloudButton } from '../components/ReadAloudButton'
import { collectionDataQueryOptions } from '../hooks/useAppData'
import { fetchPracticeAttempt, saveToCollection, setLikedState } from '../lib/api'
import { getScoreGrade } from '../lib/results'
import type { AttemptAnswer, UserCollection } from '../lib/types'
import { useAuth } from '../state/AuthContext'
import { useSound } from '../state/SoundContext'

function formatDuration(seconds: number | null) {
  const value = seconds ?? 0
  return `${Math.floor(value / 60).toString().padStart(2, '0')}:${(value % 60).toString().padStart(2, '0')}`
}

type MissedTermAction = 'save' | 'like' | 'unlike'

function MissedTermRow({
  answer,
  userId,
  preference,
  preferenceLoading,
  preferenceUnavailable,
}: {
  answer: AttemptAnswer
  userId: string
  preference: UserCollection | undefined
  preferenceLoading: boolean
  preferenceUnavailable: boolean
}) {
  const queryClient = useQueryClient()
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')
  const term = answer.term?.trim() || 'This term'
  const isSaved = preference?.state === 'saved'
  const isLiked = preference?.is_liked ?? false

  const preferenceMutation = useMutation({
    mutationFn: async (action: MissedTermAction) => {
      if (action === 'like' || action === 'unlike') {
        await setLikedState(userId, answer.knowledge_item_id, action === 'like')
      } else {
        await saveToCollection(userId, answer.knowledge_item_id)
      }
      return action
    },
    onMutate: () => {
      setMessage('')
      setError('')
    },
    onSuccess: async (action) => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ['collection-data', userId] }),
        queryClient.invalidateQueries({ queryKey: ['collection-item', userId, answer.knowledge_item_id] }),
        queryClient.invalidateQueries({ queryKey: ['app-data', userId] }),
        queryClient.invalidateQueries({ queryKey: ['library-data', userId] }),
        queryClient.invalidateQueries({ queryKey: ['practice-setup-counts', userId] }),
      ])
      setMessage(action === 'like'
        ? 'Added to favourites and My Collection.'
        : action === 'unlike'
          ? 'Removed from favourites. It remains in My Collection.'
          : 'Saved in My Collection.')
    },
    onError: (caught) => setError(caught instanceof Error ? caught.message : 'Unable to update this term.'),
  })

  const controlsDisabled = preferenceLoading || preferenceUnavailable || preferenceMutation.isPending
  const saveTooltip = preferenceLoading
    ? 'Loading Collection status'
    : preferenceUnavailable
      ? 'Collection status unavailable'
      : isSaved
        ? 'Saved in My Collection'
        : 'Add to My Collection'
  const likeTooltip = preferenceLoading
    ? 'Loading favourite status'
    : preferenceUnavailable
      ? 'Favourite status unavailable'
      : isLiked
        ? 'Remove from favourites'
        : 'Add to favourites'

  return (
    <article className="missed-term-row" aria-busy={preferenceMutation.isPending}>
      <XCircle className="missed-term-status-icon" aria-hidden="true" />
      <div className="missed-term-details">
        <span className="missed-term-copy">
          <strong>{term}</strong>
          <small>{answer.meaning ?? 'Meaning unavailable.'}</small>
        </span>
        <div className="missed-term-actions question-item-actions" aria-label={`Actions for ${term}`}>
          <button
            type="button"
            className={`icon-button ${isSaved ? 'is-selected' : ''}`}
            aria-label={`${isSaved ? 'Saved in My Collection' : 'Add to My Collection'}: ${term}`}
            aria-pressed={isSaved}
            data-tooltip={saveTooltip}
            disabled={controlsDisabled}
            onClick={() => preferenceMutation.mutate('save')}
          >
            {isSaved ? <BookmarkCheck aria-hidden="true" /> : <Bookmark aria-hidden="true" />}
          </button>
          <button
            type="button"
            className={`icon-button ${isLiked ? 'is-liked' : ''}`}
            aria-label={`${isLiked ? 'Remove from favourites' : 'Add to favourites'}: ${term}`}
            aria-pressed={isLiked}
            data-tooltip={likeTooltip}
            disabled={controlsDisabled}
            onClick={() => preferenceMutation.mutate(isLiked ? 'unlike' : 'like')}
          >
            <Heart aria-hidden="true" fill={isLiked ? 'currentColor' : 'none'} />
          </button>
          <ReadAloudButton term={term} pronunciation={answer.pronunciation} className="missed-term-read-aloud" />
        </div>
        {message ? <p className="question-preference-message missed-term-preference-message" role="status">{message}</p> : null}
        {error ? <p className="form-error missed-term-preference-error" role="alert">{error}</p> : null}
      </div>
    </article>
  )
}

export function ResultsPage() {
  const { user } = useAuth()
  const { attemptId = '' } = useParams()
  const { soundEnabled, playSound } = useSound()
  const query = useQuery({ queryKey: ['practice-attempt', attemptId], queryFn: () => fetchPracticeAttempt(attemptId), enabled: Boolean(attemptId) })
  const hasMissedTerms = query.data?.answers.some((answer) => answer.is_correct === false) ?? false
  const collectionQuery = useQuery({
    ...collectionDataQueryOptions(user?.id ?? ''),
    enabled: Boolean(user && hasMissedTerms),
    refetchOnMount: 'always',
  })
  const preferenceByItem = useMemo(() => {
    const preferences = new Map<string, UserCollection>()
    collectionQuery.data?.collections.forEach((preference) => preferences.set(preference.knowledge_item_id, preference))
    return preferences
  }, [collectionQuery.data])

  useEffect(() => {
    if (!soundEnabled || query.data?.attempt.status !== 'completed') return
    const playedKey = `vocab-express:victory-played:${attemptId}`
    if (sessionStorage.getItem(playedKey)) return
    sessionStorage.setItem(playedKey, 'true')
    playSound('victory')
  }, [attemptId, playSound, query.data?.attempt.status, soundEnabled])
  if (query.isLoading) return <LoadingState label="Preparing your results…" />
  if (query.error || !query.data) return <ErrorState message={query.error?.message ?? 'Results not found.'} />

  const { attempt, answers, points } = query.data
  const percentage = attempt.actual_length ? Math.round((attempt.score / attempt.actual_length) * 100) : 0
  const grade = getScoreGrade(percentage)
  const missed = answers.filter((answer) => answer.is_correct === false)

  return (
    <div className="page results-page">
      {attempt.status === 'completed' ? <ConfettiCelebration /> : null}
      <header className="results-heading"><div><h1>{percentage >= 80 ? 'Well done!' : 'Keep going'}</h1><p>Your answers have updated what the app will show you next.</p></div><span className="celebration-mark">★</span></header>
      <section className="score-summary">
        <div className="score-ring" style={{ '--progress': `${percentage * 3.6}deg` } as React.CSSProperties}><strong>{attempt.score}/{attempt.actual_length}</strong></div>
        <div className="score-result"><strong>{percentage}%</strong><span>Your score</span></div>
        <div className={`score-grade grade-${grade.toLowerCase()}`} aria-label={`Grade ${grade}`}><span>Grade</span><strong>{grade}</strong></div>
      </section>
      <section className="result-metrics">
        <div><Clock3 /><strong>{formatDuration(attempt.duration_seconds)}</strong><span>Time taken</span></div>
        <div><CheckCircle2 /><strong>{attempt.score}</strong><span>Correct</span></div>
        <div className="incorrect"><XCircle /><strong>{attempt.actual_length - attempt.score}</strong><span>Incorrect</span></div>
      </section>
      <section className="points-result-card" aria-labelledby="points-earned-heading">
        <div className="points-result-total">
          <span><Trophy aria-hidden="true" /></span>
          <div><small>Learning points earned</small><h2 id="points-earned-heading">+{points.total_points}</h2></div>
        </div>
        <div className="points-result-breakdown">
          <div><strong>{points.answer_points}</strong><span>Answer points</span></div>
          <div><strong>{points.recovery_points}</strong><span>Recovery</span></div>
          <div><strong>{points.completion_points}</strong><span>Completion</span></div>
          <div><strong>{points.grade_points}</strong><span>Grade bonus</span></div>
        </div>
        <p><Sparkles aria-hidden="true" /> Points reward useful retrieval; mastery is still measured separately by long-term recall.</p>
      </section>
      <section className="missed-section">
        <h2>Terms missed</h2>
        {missed.length ? missed.map((answer) => (
          <MissedTermRow
            key={answer.id}
            answer={answer}
            userId={user!.id}
            preference={preferenceByItem.get(answer.knowledge_item_id)}
            preferenceLoading={collectionQuery.isLoading}
            preferenceUnavailable={Boolean(collectionQuery.error)}
          />
        )) : <div className="empty-state compact"><h3>No missed terms</h3><p>You answered every question correctly.</p></div>}
        {missed.length && collectionQuery.error
          ? <p className="form-error missed-term-collection-error" role="alert">Collection and favourite controls are temporarily unavailable. Listening still works.</p>
          : null}
      </section>
      {missed.length ? <Link className="primary-button" to={`/practice?source=attempt_misses&attempt=${attempt.id}`}><RotateCcw /> Practise missed items</Link> : <Link className="primary-button" to="/practice">Keep going</Link>}
      <Link className="text-link" to="/">Back to Home</Link>
    </div>
  )
}
