import { useMemo, useState, type FormEvent } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import {
  Atom,
  BookOpen,
  Brain,
  Building2,
  ChartNoAxesCombined,
  Dna,
  GraduationCap,
  Grid2X2,
  Gavel,
  Heart,
  Languages,
  Landmark,
  MessageCircle,
  Mic2,
  PencilLine,
  Scale,
  Search,
  Sigma,
  Sparkles,
  Stethoscope,
  Tag,
  Target,
  Telescope,
  UserRound,
  UsersRound,
  type LucideIcon,
} from 'lucide-react'
import { ErrorState, LoadingState } from '../components/PageState'
import { useAppData } from '../hooks/useAppData'
import { saveCategoryGoals } from '../lib/api'
import { supabase } from '../lib/supabase'
import type { Category, CategoryGoal, CategoryRecord, Difficulty } from '../lib/types'
import { useAuth } from '../state/AuthContext'

const suggestedCategoryIds: Category[] = [
  'general_vocabulary',
  'sophisticated_speaker',
  'critical_thinking_logic',
  'leadership_management',
  'academic_language_writing',
  'professional_communication',
  'education_learning',
  'personal_development_wellbeing',
]

const categoryIcons: Partial<Record<Category, LucideIcon>> = {
  general_vocabulary: BookOpen,
  critical_thinking_logic: Brain,
  academic_language_writing: PencilLine,
  professional_communication: MessageCircle,
  education_learning: GraduationCap,
  research_methods_evidence: Telescope,
  social_communication: UsersRound,
  beliefs_spirituality: Sparkles,
  biology_life_sciences: Dna,
  emotions_relationships: Heart,
  philosophy_ethics: Scale,
  mathematics_statistics: Sigma,
  health_medicine: Stethoscope,
  psychology_behaviour: Brain,
  law_civic_life: Gavel,
  culture_social_norms: UsersRound,
  literature_rhetoric: BookOpen,
  society_politics: Landmark,
  language_linguistics: Languages,
  physics_engineering: Atom,
  personal_development_wellbeing: Heart,
  business_economics: ChartNoAxesCombined,
  sophisticated_speaker: Mic2,
  leadership_management: Building2,
  phrases: MessageCircle,
  quotes: BookOpen,
  idioms: Languages,
  miscellaneous: Tag,
}

function GoalFields({ categories, goals }: { categories: CategoryRecord[]; goals: CategoryGoal[] }) {
  const initialPrimary = goals.find((goal) => goal.goal_role === 'primary')?.category_id ?? ''
  const [primary, setPrimary] = useState<Category | ''>(initialPrimary)
  const [supporting, setSupporting] = useState<Category[]>(
    goals.filter((goal) => goal.goal_role === 'supporting').map((goal) => goal.category_id),
  )
  const [search, setSearch] = useState('')
  const [showAll, setShowAll] = useState(false)

  const availableCategories = useMemo(
    () => categories.filter((category) => category.id !== primary),
    [categories, primary],
  )

  const visibleCategories = useMemo(() => {
    const needle = search.trim().toLocaleLowerCase()
    if (needle) {
      return availableCategories.filter((category) => category.name.toLocaleLowerCase().includes(needle))
    }
    if (showAll) return availableCategories

    const availableById = new Map(availableCategories.map((category) => [category.id, category]))
    return [...new Set<Category>([...suggestedCategoryIds, ...supporting])]
      .map((id) => availableById.get(id))
      .filter((category) => category !== undefined)
  }, [availableCategories, search, showAll, supporting])

  function changePrimary(value: Category | '') {
    setPrimary(value)
    if (value) setSupporting((current) => current.filter((category) => category !== value))
  }

  function toggleSupporting(category: Category, checked: boolean) {
    setSupporting((current) => {
      if (!checked) return current.filter((item) => item !== category)
      if (current.includes(category) || current.length >= 3) return current
      return [...current, category]
    })
  }

  return (
    <section className="profile-goals-section" aria-labelledby="vocabulary-goals-heading">
      <header className="profile-section-heading">
        <span><Target aria-hidden="true" /></span>
        <div>
          <h2 id="vocabulary-goals-heading">Vocabulary goals</h2>
          <p>Choose one primary goal and up to three supporting goals.</p>
        </div>
      </header>

      <div className="profile-goal-layout">
        {supporting.map((category) => (
          <input key={category} type="hidden" name="supporting_categories" value={category} />
        ))}
        <div className="primary-goal-panel">
          <label htmlFor="primary-category">Primary target</label>
          <select
            id="primary-category"
            name="primary_category"
            value={primary}
            onChange={(event) => changePrimary(event.target.value as Category | '')}
          >
            <option value="">No primary target yet</option>
            {categories.map((category) => (
              <option key={category.id} value={category.id}>{category.name}</option>
            ))}
          </select>
          <p>Recommended practice gives your primary target the strongest focus, with room for three supporting areas.</p>
        </div>

        <fieldset className="supporting-goal-panel">
          <legend>
            <span>Supporting targets</span>
            <small aria-live="polite">{supporting.length} of 3 selected</small>
          </legend>
          <label className="goal-search-field">
            <Search aria-hidden="true" />
            <span className="sr-only">Search goals</span>
            <input
              type="search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search goals"
            />
          </label>

          <div className="goal-option-grid">
            {visibleCategories.map((category) => {
              const checked = supporting.includes(category.id)
              const CategoryIcon = categoryIcons[category.id] ?? Tag
              return (
                <label className="check-option goal-option" key={category.id}>
                  <input
                    type="checkbox"
                    checked={checked}
                    disabled={!checked && supporting.length >= 3}
                    onChange={(event) => toggleSupporting(category.id, event.target.checked)}
                  />
                  <span className="goal-option-icon"><CategoryIcon aria-hidden="true" /></span>
                  <span>{category.name}</span>
                </label>
              )
            })}
          </div>

          {visibleCategories.length === 0 ? (
            <p className="goal-search-empty">No goals match “{search}”.</p>
          ) : null}

          {!search ? (
            <button type="button" className="view-all-goals" onClick={() => setShowAll((current) => !current)}>
              <Grid2X2 aria-hidden="true" />
              {showAll ? 'Show suggested goals' : `View all ${availableCategories.length} categories`}
            </button>
          ) : null}
        </fieldset>
      </div>
    </section>
  )
}

export function ProfilePage() {
  const { user } = useAuth()
  const query = useAppData()
  const queryClient = useQueryClient()
  const [message, setMessage] = useState('')
  const mutation = useMutation({
    mutationFn: async (form: FormData) => {
      const primary = String(form.get('primary_category') ?? '') as Category | ''
      const supporting = form.getAll('supporting_categories') as Category[]
      const profileUpdate = await supabase.from('profiles').update({
        display_name: String(form.get('display_name') ?? '').trim(),
        current_level: form.get('current_level') as Difficulty,
        onboarding_completed: true,
      }).eq('id', user!.id)
      if (profileUpdate.error) throw new Error(profileUpdate.error.message)
      await saveCategoryGoals(primary || null, supporting)
    },
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ['app-data'] }),
        queryClient.invalidateQueries({ queryKey: ['learning-dashboard'] }),
        queryClient.invalidateQueries({ queryKey: ['practice-setup-counts'] }),
      ])
      setMessage('Profile and vocabulary goals saved.')
    },
  })

  if (query.isLoading) return <LoadingState label="Opening your profile…" />
  if (query.error || !query.data) return <ErrorState message={query.error?.message ?? 'No data found.'} />
  const { profile, categories, categoryGoals } = query.data

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setMessage('')
    mutation.mutate(new FormData(event.currentTarget))
  }

  return (
    <div className="page profile-page">
      <header className="page-heading profile-heading">
        <div><h1>Profile</h1><p>Shape what Vocab Express puts within easy reach.</p></div>
      </header>

      <form className="profile-form" onSubmit={handleSubmit}>
        <section className="profile-details-panel" aria-labelledby="personal-details-heading">
          <h2 id="personal-details-heading">Personal details</h2>
          <div className="profile-details-grid">
            <div className="profile-identity">
              <span><UserRound aria-hidden="true" /></span>
              <div><strong>{profile.display_name}</strong><small>{user?.email}</small></div>
            </div>
            <label>
              <span>Display name</span>
              <input name="display_name" defaultValue={profile.display_name} required maxLength={60} />
            </label>
            <label>
              <span>Current level</span>
              <select name="current_level" defaultValue={profile.current_level ?? 'intermediate'}>
                <option value="beginner">Beginner</option>
                <option value="intermediate">Intermediate</option>
                <option value="advanced">Advanced</option>
              </select>
            </label>
          </div>
        </section>

        <GoalFields categories={categories} goals={categoryGoals} />

        <footer className="profile-form-footer">
          <div className="profile-form-message" aria-live="polite">
            {mutation.error ? <p className="form-error">{mutation.error.message}</p> : null}
            {message ? <p className="form-success" role="status">{message}</p> : null}
          </div>
          <button className="primary-button" disabled={mutation.isPending} type="submit">
            {mutation.isPending ? 'Saving…' : 'Save changes'}
          </button>
        </footer>
      </form>
    </div>
  )
}
