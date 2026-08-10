import { useEffect, useMemo, useRef, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import {
  ArrowRight,
  BookOpen,
  Bookmark,
  ChevronDown,
  Clock3,
  History,
  Info,
  ListChecks,
  Layers3,
  Puzzle,
  Sparkles,
  Tags,
  Target,
} from 'lucide-react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { ErrorState, LoadingState } from '../components/PageState'
import { useAppData, usePracticeSetupCounts, usePracticeSetupMultiCount } from '../hooks/useAppData'
import { createPracticeAttemptMulti } from '../lib/api'
import { practiceSelectionLabel, togglePracticeSource } from '../lib/practiceSelection'
import type { Category, PracticeSource } from '../lib/types'

const sourceOptions = [
  {
    value: 'recommended',
    label: 'Recommended for you',
    copy: 'Balances your goals, weaker terms and terms due for review.',
    icon: Sparkles,
  },
  { value: 'word_bank', label: 'My Collection', copy: 'Practise terms you’ve saved.', icon: Bookmark },
  { value: 'missed', label: 'Terms I missed', copy: 'Revisit terms you answered incorrectly.', icon: Clock3 },
  { value: 'category', label: 'Selected category', copy: 'Focus on one area.', icon: Tags },
  { value: 'mixed_library', label: 'Mixed Library', copy: 'Practise from the full library.', icon: BookOpen },
] as const

const selectableSources = new Set<PracticeSource>(sourceOptions.map((option) => option.value))

export function PracticeSetupPage() {
  const dataQuery = useAppData()
  const countsQuery = usePracticeSetupCounts()
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const [params] = useSearchParams()
  const requestedSource = params.get('source') as PracticeSource | null
  const sourceAttemptId = params.get('attempt')
  const initialSource = requestedSource === 'attempt_misses' && sourceAttemptId
    ? requestedSource
    : requestedSource && selectableSources.has(requestedSource)
      ? requestedSource
      : 'recommended'
  const [practiceTab, setPracticeTab] = useState<'start' | 'continue'>(
    requestedSource ? 'start' : params.get('tab') === 'continue' ? 'continue' : 'start',
  )
  const [sources, setSources] = useState<PracticeSource[]>([initialSource])
  const [sourceMenuOpen, setSourceMenuOpen] = useState(false)
  const [category, setCategory] = useState<Category>('')
  const [count, setCount] = useState(15)
  const [custom, setCustom] = useState(false)
  const [error, setError] = useState('')
  const sourcePickerRef = useRef<HTMLDivElement>(null)

  const activeCategory = category || dataQuery.data?.categories[0]?.id || ''
  const selectedSourceSet = useMemo(() => new Set(sources), [sources])
  const selectedCategoryIds = selectedSourceSet.has('category') && activeCategory ? [activeCategory] : []
  const multipleSources = sources.length > 1
  const multiCountQuery = usePracticeSetupMultiCount(
    sources,
    selectedCategoryIds,
    sourceAttemptId,
    multipleSources,
  )
  const counts = countsQuery.data
  const onlySource = sources[0]
  const eligibleCount = multipleSources
    ? multiCountQuery.data ?? 0
    : onlySource === 'category'
      ? counts?.categories[activeCategory] ?? 0
      : onlySource === 'attempt_misses'
        ? null
        : onlySource
          ? counts?.[onlySource] ?? 0
          : 0
  const actualCount = eligibleCount === null ? count : Math.min(count, eligibleCount)
  const sessionMinutes = actualCount ? Math.max(1, Math.ceil(actualCount / 3)) : 0

  useEffect(() => {
    if (!sourceMenuOpen) return
    const handleOutsidePointer = (event: PointerEvent) => {
      if (!sourcePickerRef.current?.contains(event.target as Node)) setSourceMenuOpen(false)
    }
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setSourceMenuOpen(false)
    }
    document.addEventListener('pointerdown', handleOutsidePointer)
    document.addEventListener('keydown', handleEscape)
    return () => {
      document.removeEventListener('pointerdown', handleOutsidePointer)
      document.removeEventListener('keydown', handleEscape)
    }
  }, [sourceMenuOpen])

  const startMutation = useMutation({
    mutationFn: async () => {
      if (!dataQuery.data || actualCount === 0) throw new Error('There are no eligible terms in this source yet.')
      if (!sources.length) throw new Error('Choose at least one practice source.')
      const result = await createPracticeAttemptMulti({
        sources,
        requestedLength: Math.max(10, Math.min(200, Math.round(count))),
        categoryIds: selectedCategoryIds,
        sourceAttemptId: selectedSourceSet.has('attempt_misses') ? sourceAttemptId : null,
      })
      return result.attempt_id
    },
    onSuccess: async (attemptId) => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ['app-data'] }),
        queryClient.invalidateQueries({ queryKey: ['practice-setup-counts'] }),
      ])
      navigate(`/practice/${attemptId}`)
    },
    onError: (caught) => setError(caught instanceof Error ? caught.message : 'Unable to start practice.'),
  })

  if (dataQuery.isLoading || countsQuery.isLoading) return <LoadingState label="Preparing your practice choices…" />
  if (dataQuery.error || !dataQuery.data || countsQuery.error || !countsQuery.data) {
    return <ErrorState message={dataQuery.error?.message ?? countsQuery.error?.message ?? 'No data found.'} />
  }

  const categories = dataQuery.data.categories
  const selectedCategoryName = categories.find((item) => item.id === activeCategory)?.name
  const inProgressAttempts = dataQuery.data.attempts.filter((attempt) => attempt.status === 'in_progress')
  const sourceLabel = practiceSelectionLabel(sources, selectedCategoryName)

  function chooseSource(nextSource: PracticeSource) {
    setSources((current) => togglePracticeSource(current, nextSource))
    setError('')
  }

  function optionEligibleCount(source: Exclude<PracticeSource, 'attempt_misses'>) {
    return source === 'category'
      ? countsQuery.data?.categories[activeCategory] ?? 0
      : countsQuery.data?.[source] ?? 0
  }

  function attemptSourceLabel(attempt: (typeof inProgressAttempts)[number]) {
    if (attempt.focus_label) return attempt.focus_label
    if (attempt.source === 'recommended') return 'Recommended for you'
    if (attempt.source === 'word_bank') return 'My Collection'
    if (attempt.source === 'missed') return 'Terms I missed'
    if (attempt.source === 'mixed_library') return 'Mixed Library'
    if (attempt.source === 'attempt_misses') return 'Missed items practice'
    return categories.find((item) => item.id === attempt.category_id)?.name ?? 'Selected category'
  }

  function formatStartedAt(value: string) {
    const startedAt = new Date(value)
    return new Intl.DateTimeFormat('en-GB', {
      day: 'numeric',
      month: 'short',
      year: startedAt.getFullYear() === new Date().getFullYear() ? undefined : 'numeric',
    }).format(startedAt)
  }

  return (
    <div className="page practice-setup-page">
      <header className="page-heading practice-heading">
        <div>
          <h1>Practice</h1>
          <p>Build a new session or pick up exactly where you left off.</p>
        </div>
      </header>

      <div className="practice-tabs" role="tablist" aria-label="Practice options">
        <button
          type="button"
          id="start-practice-tab"
          role="tab"
          aria-selected={practiceTab === 'start'}
          aria-controls="start-practice-panel"
          className={practiceTab === 'start' ? 'is-active' : ''}
          onClick={() => setPracticeTab('start')}
        >
          Start New Practice
        </button>
        <button
          type="button"
          id="continue-practice-tab"
          role="tab"
          aria-selected={practiceTab === 'continue'}
          aria-controls="continue-practice-panel"
          className={practiceTab === 'continue' ? 'is-active' : ''}
          onClick={() => setPracticeTab('continue')}
        >
          Continue Practice
          {inProgressAttempts.length ? <span className="practice-tab-count" aria-hidden="true">{inProgressAttempts.length}</span> : null}
        </button>
      </div>

      {practiceTab === 'start' ? <div
        className="practice-setup-layout"
        id="start-practice-panel"
        role="tabpanel"
        aria-labelledby="start-practice-tab"
      >
        <div className="practice-setup-form">
          <section className="setup-section" aria-labelledby="practice-source-heading">
            <h2 id="practice-source-heading">1. Choose what to practise</h2>
            <div className="practice-source-picker" ref={sourcePickerRef}>
              <button
                className="practice-source-trigger"
                type="button"
                aria-expanded={sourceMenuOpen}
                aria-controls="practice-source-menu"
                onClick={() => setSourceMenuOpen((current) => !current)}
              >
                <Layers3 aria-hidden="true" />
                <span><strong>{sourceLabel}</strong><small>{multipleSources ? `${sources.length} sources selected` : 'Select one or more practice sources'}</small></span>
                {sources.length ? <b>{sources.length}</b> : null}
                <ChevronDown aria-hidden="true" />
              </button>
              {sourceMenuOpen ? (
                <fieldset className="practice-source-menu" id="practice-source-menu">
                  <legend className="sr-only">Choose practice sources</legend>
                  <header>
                    <div><strong>Practice sources</strong><small>Select one or more</small></div>
                    {sources.length ? <button type="button" onClick={() => { setSources([]); setError('') }}>Clear</button> : null}
                  </header>
                  <div className="practice-source-options">
                    {selectedSourceSet.has('attempt_misses') ? (
                      <label className="practice-source-option">
                        <input type="checkbox" checked onChange={() => chooseSource('attempt_misses')} />
                        <span className="practice-source-option-icon"><Clock3 aria-hidden="true" /></span>
                        <span className="practice-source-option-copy"><strong>Missed from this result</strong><small>Revisit the exact terms missed in that practice.</small></span>
                      </label>
                    ) : null}
                    {sourceOptions.map(({ value, label, copy, icon: Icon }) => (
                      <label className="practice-source-option" key={value}>
                        <input type="checkbox" checked={selectedSourceSet.has(value)} onChange={() => chooseSource(value)} />
                        <span className="practice-source-option-icon"><Icon aria-hidden="true" /></span>
                        <span className="practice-source-option-copy"><strong>{label}</strong><small>{copy}</small></span>
                        <b>{optionEligibleCount(value)}</b>
                      </label>
                    ))}
                  </div>
                </fieldset>
              ) : null}
            </div>

            {selectedSourceSet.has('category') ? (
              <label className="practice-category-select">
                Choose a category
                <select value={activeCategory} onChange={(event) => setCategory(event.target.value as Category)}>
                  {dataQuery.data.categories.map((option) => (
                    <option key={option.id} value={option.id}>{option.name}</option>
                  ))}
                </select>
              </label>
            ) : null}
          </section>

          <section className="setup-section session-length-section" aria-labelledby="session-length-heading">
            <h2 id="session-length-heading">2. Choose session length</h2>
            <div className="count-options" role="group" aria-label="Session length">
              {[15, 30, 45, 60].map((value) => (
                <button
                  key={value}
                  type="button"
                  className={!custom && count === value ? 'is-selected' : ''}
                  aria-pressed={!custom && count === value}
                  onClick={() => { setCustom(false); setCount(value); setError('') }}
                >
                  {value}
                </button>
              ))}
              <button
                type="button"
                className={custom ? 'is-selected' : ''}
                aria-pressed={custom}
                onClick={() => { setCustom(true); setError('') }}
              >
                Custom
              </button>
            </div>
            {custom ? (
              <label className="custom-count">
                Custom amount
                <input
                  type="number"
                  min={10}
                  max={200}
                  step={1}
                  value={count}
                  onChange={(event) => setCount(Math.max(10, Math.min(200, Math.round(Number(event.target.value)))))}
                />
                <small>Enter a whole number from 10 to 200.</small>
              </label>
            ) : null}
            <p className="session-length-help">Custom sessions can contain 10–200 questions.</p>
          </section>
        </div>

        <aside className="session-summary" aria-labelledby="session-summary-heading">
          <h2 id="session-summary-heading">Your session</h2>
          <div className="session-summary-list">
            <div className="session-summary-row">
              <span className="summary-icon"><Target aria-hidden="true" /></span>
              <span><small>Source</small><strong>{sourceLabel}</strong></span>
            </div>
            <div className="session-summary-row">
              <span className="summary-icon"><ListChecks aria-hidden="true" /></span>
              <span><small>Questions</small><strong>{actualCount || 0}</strong></span>
            </div>
            <div className="session-summary-row">
              <span className="summary-icon"><Puzzle aria-hidden="true" /></span>
              <span><small>Activity mix</small><strong>Multiple choice · True or false</strong></span>
            </div>
          </div>

          <div className="eligibility-note" aria-live="polite">
            <Info aria-hidden="true" />
            <span>
              {multiCountQuery.isLoading
                ? 'Calculating the combined term poolâ€¦'
                : eligibleCount === null
                ? 'Each missed term from that result is available once.'
                : <><strong>{eligibleCount}</strong> eligible {eligibleCount === 1 ? 'term' : 'terms'} available{count > eligibleCount && eligibleCount ? ` · session capped at ${eligibleCount}` : ''}</>}
            </span>
          </div>
          {multiCountQuery.error ? <p className="form-error" role="alert">{multiCountQuery.error.message}</p> : null}
          {error ? <p className="form-error" role="alert">{error}</p> : null}
          <button
            type="button"
            className="primary-button start-practice"
            disabled={!actualCount || multiCountQuery.isLoading || startMutation.isPending}
            onClick={() => startMutation.mutate()}
          >
            {startMutation.isPending
              ? 'Building your practice…'
              : `Start ${actualCount || 0}-question practice`}
          </button>
          <p className="session-duration">
            {sessionMinutes ? `Usually takes about ${sessionMinutes} minute${sessionMinutes === 1 ? '' : 's'}.` : 'Choose an available source to start.'}
          </p>
        </aside>
      </div> : (
        <section
          className="continue-practice-panel"
          id="continue-practice-panel"
          role="tabpanel"
          aria-labelledby="continue-practice-tab"
        >
          <header>
            <div>
              <h2>Continue your practice</h2>
              <p>Resume an unfinished session from its next unanswered question.</p>
            </div>
            <span className="continue-heading-icon" aria-hidden="true"><History /></span>
          </header>
          {inProgressAttempts.length ? (
            <div className="continue-attempt-list">
              {inProgressAttempts.map((attempt) => (
                <article className="continue-attempt-card" key={attempt.id}>
                  <span className="continue-attempt-icon" aria-hidden="true"><Clock3 /></span>
                  <div className="continue-attempt-copy">
                    <h3>{attemptSourceLabel(attempt)}</h3>
                    <p>{attempt.actual_length} questions · Started {formatStartedAt(attempt.started_at)}</p>
                    <small>Your answers are saved. Continue from the next question.</small>
                  </div>
                  <button
                    type="button"
                    className="primary-button continue-attempt-button"
                    onClick={() => navigate(`/practice/${attempt.id}`)}
                  >
                    Continue <ArrowRight aria-hidden="true" />
                  </button>
                </article>
              ))}
            </div>
          ) : (
            <div className="empty-state continue-empty-state">
              <span className="continue-empty-icon" aria-hidden="true"><History /></span>
              <h3>No practice waiting</h3>
              <p>When you leave a session before finishing, it will be ready here.</p>
              <button type="button" className="secondary-button" onClick={() => setPracticeTab('start')}>Start New Practice</button>
            </div>
          )}
        </section>
      )}
    </div>
  )
}
