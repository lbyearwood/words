import { ArrowRight, BookOpen, Bookmark, RefreshCw, Sparkles, Target, Trophy } from 'lucide-react'
import { Link } from 'react-router-dom'
import { ErrorState } from '../components/PageState'
import { useAppData, useLearningDashboard, usePointsSummary } from '../hooks/useAppData'

export function HomePage() {
  const appQuery = useAppData()
  const learningQuery = useLearningDashboard()
  const pointsQuery = usePointsSummary()
  if (appQuery.isLoading || learningQuery.isLoading || pointsQuery.isLoading) {
    return (
      <div className="page home-page home-loading" role="status" aria-label="Loading your learning overview">
        <header className="page-heading home-heading">
          <div><h1>Welcome back</h1><p>Preparing your latest learning overview…</p></div>
        </header>
        <section className="home-loading-panel" aria-hidden="true">
          <span className="loading-skeleton loading-skeleton-ring" />
          <div><span className="loading-skeleton wide" /><span className="loading-skeleton medium" /></div>
        </section>
        <section className="home-loading-metrics" aria-hidden="true">
          {Array.from({ length: 6 }, (_, index) => <span className="loading-skeleton" key={index} />)}
        </section>
      </div>
    )
  }
  if (appQuery.error || !appQuery.data || learningQuery.error || !learningQuery.data || pointsQuery.error || !pointsQuery.data) {
    return <ErrorState message={appQuery.error?.message ?? learningQuery.error?.message ?? pointsQuery.error?.message ?? 'No data found.'} />
  }

  const { profile, collections, attempts } = appQuery.data
  const learning = learningQuery.data
  const points = pointsQuery.data
  const completed = attempts.filter((attempt) => attempt.status === 'completed')
  const answered = completed.reduce((total, attempt) => total + attempt.actual_length, 0)
  const correct = completed.reduce((total, attempt) => total + attempt.score, 0)
  const accuracy = answered ? Math.round((correct / answered) * 100) : 0
  const savedCount = collections.filter((row) => row.state === 'saved').length
  const primaryGoal = learning.goals.find((goal) => goal.goal_role === 'primary')
  const overallMastery = learning.overall.durable_mastery

  const metrics = [
    { label: 'Terms saved', value: savedCount, icon: Bookmark, to: '/collection' },
    { label: 'Terms practised', value: learning.reviewed_unique, icon: BookOpen },
    { label: 'Your accuracy', value: answered ? `${accuracy}%` : '—', icon: Target },
    {
      label: 'Primary target',
      value: primaryGoal?.category_name ?? 'Choose a goal',
      icon: Sparkles,
      to: '/profile',
      emphasis: primaryGoal ? 'goal' : 'choose-goal',
    },
    { label: 'Terms due', value: learning.due_count, icon: RefreshCw, to: '/practice', emphasis: 'due' },
    { label: 'Learning points', value: points.lifetime_points.toLocaleString('en-GB'), icon: Trophy, to: '/progress', emphasis: 'points' },
  ]

  return (
    <div className="page home-page">
      <header className="page-heading home-heading">
        <div>
          <h1>Hello, {profile.display_name}</h1>
          <p>You’re building useful knowledge, one term at a time.</p>
        </div>
      </header>

      <section className="progress-hero" aria-labelledby="overall-mastery-heading">
        <div
          className="progress-ring"
          style={{ '--progress': `${overallMastery * 3.6}deg` } as React.CSSProperties}
          aria-label={`${Math.round(overallMastery)}% overall durable mastery`}
        >
          <span>{Math.round(overallMastery)}%</span>
        </div>
        <div className="progress-hero-copy">
          <h2 id="overall-mastery-heading">Overall durable mastery</h2>
          <p>Your predicted recall after 30 days across each visible term, counted once.</p>
        </div>
        <Link className="primary-button hero-action" to="/practice">
          Recommended practice <ArrowRight aria-hidden="true" />
        </Link>
      </section>

      <section className="home-progress-panel" aria-labelledby="progress-snapshot-heading">
        <h2 id="progress-snapshot-heading">Your progress</h2>
        <div className="metric-list">
          {metrics.map(({ label, value, icon: Icon, to, emphasis }) => {
            const content = (
              <>
                <span className={`metric-icon ${emphasis === 'choose-goal' ? 'needs-goal' : ''}`}>
                  <Icon aria-hidden="true" />
                </span>
                <span className="metric-copy">
                  <strong>{value}</strong>
                  <small>{label}</small>
                </span>
                {emphasis === 'due' ? <ArrowRight className="metric-arrow" aria-hidden="true" /> : null}
              </>
            )

            return to ? (
              <Link className={`metric-row ${emphasis ?? ''}`} to={to} key={label} aria-label={`${label}: ${value}`}>
                {content}
              </Link>
            ) : (
              <div className={`metric-row ${emphasis ?? ''}`} key={label}>
                {content}
              </div>
            )
          })}
        </div>
      </section>

      <section className={`vocabulary-target-panel ${learning.goals.length ? 'has-goals' : 'is-empty'}`} aria-labelledby="vocabulary-targets-heading">
        <div className="target-panel-icon"><Target aria-hidden="true" /></div>
        <div className="target-panel-content">
          <div className="target-panel-heading">
            <div>
              <h2 id="vocabulary-targets-heading">Your vocabulary targets</h2>
              <p>Coverage, recall today and durable 30-day mastery.</p>
            </div>
            {learning.goals.length ? <Link className="secondary-button" to="/profile">Manage goals</Link> : null}
          </div>

          {learning.goals.length ? (
            <div className="mastery-list">
              {learning.goals.map((goal) => (
                <article className="mastery-card" key={goal.category_id}>
                  <div className="mastery-title">
                    <span>
                      <small>{goal.goal_role === 'primary' ? 'Primary target' : 'Supporting target'}</small>
                      <strong>{goal.category_name}</strong>
                    </span>
                    <b>{Math.round(goal.durable_mastery)}%</b>
                  </div>
                  <div className="mastery-measures">
                    <div><span>Coverage</span><strong>{Math.round(goal.coverage)}%</strong><i><b style={{ width: `${goal.coverage}%` }} /></i></div>
                    <div><span>Recall today</span><strong>{Math.round(goal.current_recall)}%</strong><i><b style={{ width: `${goal.current_recall}%` }} /></i></div>
                    <div><span>30-day mastery</span><strong>{Math.round(goal.durable_mastery)}%</strong><i><b style={{ width: `${goal.durable_mastery}%` }} /></i></div>
                  </div>
                  <p>{goal.practised_items} of {goal.total_items} weighted terms encountered</p>
                </article>
              ))}
            </div>
          ) : (
            <div className="goal-empty">
              <p>Choose a primary category and up to three supporting categories to start measuring mastery.</p>
              <Link className="secondary-button" to="/profile">Choose my goals</Link>
            </div>
          )}
        </div>
      </section>
    </div>
  )
}
