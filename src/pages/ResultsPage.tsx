import { useEffect } from 'react'
import { useQuery } from '@tanstack/react-query'
import { CheckCircle2, Clock3, RotateCcw, Sparkles, Trophy, XCircle } from 'lucide-react'
import { Link, useParams } from 'react-router-dom'
import { ConfettiCelebration } from '../components/ConfettiCelebration'
import { ErrorState, LoadingState } from '../components/PageState'
import { fetchPracticeAttempt } from '../lib/api'
import { getScoreGrade } from '../lib/results'
import { useSound } from '../state/SoundContext'

function formatDuration(seconds: number | null) {
  const value = seconds ?? 0
  return `${Math.floor(value / 60).toString().padStart(2, '0')}:${(value % 60).toString().padStart(2, '0')}`
}

export function ResultsPage() {
  const { attemptId = '' } = useParams()
  const { soundEnabled, playSound } = useSound()
  const query = useQuery({ queryKey: ['practice-attempt', attemptId], queryFn: () => fetchPracticeAttempt(attemptId), enabled: Boolean(attemptId) })

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
          <article key={answer.id}><XCircle /><span><strong>{answer.term}</strong><small>{answer.meaning}</small></span></article>
        )) : <div className="empty-state compact"><h3>No missed terms</h3><p>You answered every question correctly.</p></div>}
      </section>
      {missed.length ? <Link className="primary-button" to={`/practice?source=attempt_misses&attempt=${attempt.id}`}><RotateCcw /> Practise missed items</Link> : <Link className="primary-button" to="/practice">Keep going</Link>}
      <Link className="text-link" to="/">Back to Home</Link>
    </div>
  )
}
