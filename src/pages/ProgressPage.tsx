import { ArrowRight, BarChart3, BookOpen, Bookmark, CircleHelp, ClipboardCheck, Clock3, RefreshCw, Target, Trophy } from 'lucide-react'
import { Link, useSearchParams } from 'react-router-dom'
import { ErrorState, LoadingState } from '../components/PageState'
import { usePointsSummary, useProgressData } from '../hooks/useAppData'
import { formatCompactDuration, formatClockDuration, getMasteryStage, MASTERY_STAGES, pointsToMastered, resultFocusLabel, summariseCompletedAttempts } from '../lib/progress'
import { getScoreGrade } from '../lib/results'
import type { ActivityAttempt, PracticeSource } from '../lib/types'

type ProgressTab = 'results' | 'progress'

function FocusIcon({ source }: { source: PracticeSource }) {
  if (source === 'word_bank') return <Bookmark aria-hidden="true" />
  if (source === 'missed' || source === 'attempt_misses') return <RefreshCw aria-hidden="true" />
  if (source === 'mixed_library') return <BookOpen aria-hidden="true" />
  return <Target aria-hidden="true" />
}

function formatResultDate(value: string | null) {
  if (!value) return 'Not recorded'
  return new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }).format(new Date(value))
}

export function ProgressPage() {
  const [params, setParams] = useSearchParams()
  const query = useProgressData()
  const pointsQuery = usePointsSummary()
  const selectedTab: ProgressTab = params.get('tab') === 'progress' ? 'progress' : 'results'

  if (query.isLoading || pointsQuery.isLoading) return <LoadingState label="Building your progress view…" />
  if (query.error || !query.data || pointsQuery.error || !pointsQuery.data) return <ErrorState message={query.error?.message ?? pointsQuery.error?.message ?? 'Progress could not be loaded.'} />

  const { attempts, attemptCategories, categories, dashboard } = query.data
  const summary = summariseCompletedAttempts(attempts)
  const pointSummary = pointsQuery.data
  const targetPoints = new Map(pointSummary.goals.map((goal) => [goal.category_id, goal.points]))
  const categoryById = new Map(categories.map((category) => [category.id, category]))
  const focusByAttempt = new Map<string, string[]>()
  for (const mapping of attemptCategories) {
    const category = categoryById.get(mapping.category_id)
    if (!category) continue
    const focus = focusByAttempt.get(mapping.attempt_id) ?? []
    focus.push(category.name)
    focusByAttempt.set(mapping.attempt_id, focus)
  }

  function selectTab(tab: ProgressTab) {
    setParams(tab === 'progress' ? { tab: 'progress' } : {}, { replace: true })
  }

  return (
    <div className="page progress-page">
      <header className="page-heading">
        <div>
          <h1>My Progress</h1>
          <p>See your completed tests and how close you are to mastering your targets.</p>
        </div>
      </header>

      <div className="progress-tabs" role="tablist" aria-label="Progress views">
        <button type="button" role="tab" aria-selected={selectedTab === 'results'} aria-controls="my-results-panel" className={selectedTab === 'results' ? 'is-active' : ''} onClick={() => selectTab('results')}>My Results</button>
        <button type="button" role="tab" aria-selected={selectedTab === 'progress'} aria-controls="my-progress-panel" className={selectedTab === 'progress' ? 'is-active' : ''} onClick={() => selectTab('progress')}>My Progress</button>
      </div>

      {selectedTab === 'results' ? (
        <section id="my-results-panel" role="tabpanel" className="results-history-panel" aria-label="My Results">
          <section className="results-overview" aria-label="Results summary">
            <article><span><ClipboardCheck aria-hidden="true" /></span><div><strong>{summary.tests}</strong><small>Tests completed</small></div></article>
            <article><span><Target aria-hidden="true" /></span><div><strong>{summary.tests ? `${summary.accuracy}%` : '—'}</strong><small>Overall accuracy</small></div></article>
            <article><span><CircleHelp aria-hidden="true" /></span><div><strong>{summary.questions}</strong><small>Questions answered</small></div></article>
            <article><span><Clock3 aria-hidden="true" /></span><div><strong>{formatCompactDuration(summary.durationSeconds)}</strong><small>Practice time</small></div></article>
            <article><span><Trophy aria-hidden="true" /></span><div><strong>{pointSummary.lifetime_points.toLocaleString('en-GB')}</strong><small>Learning points</small></div></article>
          </section>

          {attempts.length ? (
            <>
              <div className="result-history-header" aria-hidden="true"><span>Focus</span><span>Score</span><span>Grade</span><span>Points</span><span>Time</span><span>Date</span><span>Action</span></div>
              <div className="result-history-list">
                {attempts.map((attempt) => <ResultHistoryRow attempt={attempt} focus={focusByAttempt.get(attempt.id) ?? []} key={attempt.id} />)}
              </div>
              <p className="results-list-note">Showing {attempts.length} of {attempts.length} results. Newest first.</p>
            </>
          ) : (
            <div className="progress-empty-state">
              <BarChart3 aria-hidden="true" />
              <h2>No completed tests yet</h2>
              <p>Finish a practice session and its score, grade and focus will appear here.</p>
              <Link className="primary-button" to="/practice">Start practice <ArrowRight aria-hidden="true" /></Link>
            </div>
          )}
        </section>
      ) : (
        <section id="my-progress-panel" role="tabpanel" className="target-progress-panel" aria-label="My Progress">
          <header className="target-journey-heading"><h2>Your target journey</h2><p>Mastery reflects your predicted recall after 30 days.</p></header>
          <ol className="mastery-stage-scale" aria-label="Mastery stages">
            {MASTERY_STAGES.map((stage, index) => <li key={stage.name}><span aria-hidden="true">{index + 1}</span><div><strong>{stage.name}</strong><small>{stage.range}</small></div></li>)}
          </ol>

          {dashboard.goals.length ? (
            <>
              <div className="target-progress-list">
                {dashboard.goals.map((goal) => {
                  const mastery = Math.round(goal.durable_mastery)
                  const stage = getMasteryStage(mastery)
                  const remaining = pointsToMastered(mastery)
                  return (
                    <article className="target-progress-card" key={goal.category_id}>
                      <header><span className="target-progress-icon"><Target aria-hidden="true" /></span><div><h3>{goal.category_name}</h3><small>{goal.goal_role === 'primary' ? 'Primary target' : 'Supporting target'}</small></div></header>
                      <div className="target-mastery-measure">
                        <span><small>Durable mastery</small><strong>{mastery}%</strong><b className={`stage-${stage.toLowerCase()}`}>{stage}</b></span>
                        <div className="target-mastery-track" role="progressbar" aria-label={`${goal.category_name} durable mastery`} aria-valuemin={0} aria-valuemax={100} aria-valuenow={mastery}>
                          <i style={{ width: `${mastery}%` }} /><b style={{ left: `${Math.min(100, Math.max(0, mastery))}%` }} />
                          <span className="threshold-25" /><span className="threshold-50" /><span className="threshold-80" />
                        </div>
                      </div>
                      <dl className="target-progress-metrics">
                        <div><dt>Coverage</dt><dd>{Math.round(goal.coverage)}%</dd></div>
                        <div><dt>Recall today</dt><dd>{Math.round(goal.current_recall)}%</dd></div>
                        <div><dt>Weighted terms encountered</dt><dd>{goal.practised_items} of {goal.total_items}</dd></div>
                        <div><dt>Target learning points</dt><dd>{(targetPoints.get(goal.category_id) ?? 0).toLocaleString('en-GB')}</dd></div>
                        <div><dt>To Mastered</dt><dd>{remaining ? `${remaining} percentage points` : 'Achieved'}</dd></div>
                      </dl>
                    </article>
                  )
                })}
              </div>
              <div className="target-progress-actions"><Link className="primary-button" to="/practice"><Target aria-hidden="true" /> Start recommended practice</Link><Link className="secondary-button" to="/profile">Manage goals</Link></div>
            </>
          ) : (
            <div className="progress-empty-state goals-empty">
              <Target aria-hidden="true" />
              <h2>Choose your vocabulary targets</h2>
              <p>Select one primary target and up to three supporting targets. Your mastery journey will then appear here.</p>
              <Link className="primary-button" to="/profile">Choose my goals <ArrowRight aria-hidden="true" /></Link>
            </div>
          )}
        </section>
      )}
    </div>
  )
}

function ResultHistoryRow({ attempt, focus }: { attempt: ActivityAttempt; focus: string[] }) {
  const accuracy = attempt.actual_length ? Math.round((attempt.score / attempt.actual_length) * 100) : 0
  const grade = getScoreGrade(accuracy)
  const focusLabel = resultFocusLabel(attempt, focus)

  return (
    <article className="result-history-row">
      <div className="result-focus"><span><FocusIcon source={attempt.source} /></span><div><strong>{focusLabel}</strong></div></div>
      <div className="result-score" data-label="Score"><strong>{attempt.score} / {attempt.actual_length}</strong><span>{accuracy}%</span></div>
      <div className="result-grade" data-label="Grade"><strong className={`grade-${grade.toLowerCase()}`} role="img" aria-label={`Grade ${grade}`}>{grade}</strong></div>
      <div className="result-points" data-label="Points"><Trophy aria-hidden="true" /><strong>+{attempt.points_earned}</strong></div>
      <div className="result-time" data-label="Time"><Clock3 aria-hidden="true" /><span>{formatClockDuration(attempt.duration_seconds)}</span></div>
      <div className="result-date" data-label="Date"><time dateTime={attempt.completed_at ?? undefined}>{formatResultDate(attempt.completed_at)}</time></div>
      <Link className="result-view-link" to={`/results/${attempt.id}`}>View result <ArrowRight aria-hidden="true" /></Link>
    </article>
  )
}
