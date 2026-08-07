import { useMemo, useState, type FormEvent } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { BarChart3, Bookmark, BookmarkMinus, BookOpenCheck, Check, ChevronDown, CirclePlus, Heart, Play, Search, Sparkles, Tags, ThumbsDown, X } from 'lucide-react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { z } from 'zod'
import { CategoryTags } from '../components/CategoryTags'
import { ErrorState, LoadingState } from '../components/PageState'
import { useCollectionData } from '../hooks/useAppData'
import { createPersonalItem, createScopedPracticeAttempt, removeFromCollection, saveToCollection, setDislikedState, setLikedState } from '../lib/api'
import { categoryIds, type Category, type ConfidenceStatus } from '../lib/types'
import { useAuth } from '../state/AuthContext'

const itemSchema = z.object({
  term: z.string().trim().min(1, 'Add a term.').max(160),
  meaning: z.string().trim().min(1, 'Add a plain-English meaning.').max(600),
  example: z.string().trim().min(1, 'Add an example sentence.').max(800),
  primary_category: z.enum(categoryIds),
  secondary_categories: z.array(z.enum(categoryIds)),
  difficulty: z.enum(['beginner', 'intermediate', 'advanced']),
})

const confidenceClass: Record<ConfidenceStatus, string> = {
  New: 'new',
  Learning: 'learning',
  Confident: 'confident',
  'Needs practice': 'needs-practice',
}

const confidenceLabel = (status: ConfidenceStatus) => status === 'Confident' ? 'Mastered' : status

type CollectionSort = 'recent' | 'alphabetical' | 'reverse-alphabetical' | 'needs-practice'
type CollectionFilter = 'All' | 'Liked' | 'Disliked' | ConfidenceStatus

const confidenceOrder: Record<ConfidenceStatus, number> = {
  'Needs practice': 0,
  New: 1,
  Learning: 2,
  Confident: 3,
}

export function CollectionPage() {
  const { user } = useAuth()
  const query = useCollectionData()
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const [params, setParams] = useSearchParams()
  const [showAdd, setShowAdd] = useState(params.get('add') === 'true')
  const [filter, setFilter] = useState<CollectionFilter>('All')
  const [selectedCategories, setSelectedCategories] = useState<Category[]>([])
  const [search, setSearch] = useState('')
  const [sort, setSort] = useState<CollectionSort>('recent')
  const [formError, setFormError] = useState('')
  const [practiceError, setPracticeError] = useState('')
  const [primaryCategory, setPrimaryCategory] = useState<Category>('general_vocabulary')

  const refreshCollection = () => Promise.all([
    queryClient.invalidateQueries({ queryKey: ['collection-data', user!.id] }),
    queryClient.invalidateQueries({ queryKey: ['app-data', user!.id] }),
    queryClient.invalidateQueries({ queryKey: ['practice-setup-counts', user!.id] }),
  ])

  const removeMutation = useMutation({
    mutationFn: (itemId: string) => removeFromCollection(user!.id, itemId),
    onSuccess: refreshCollection,
  })
  const addMutation = useMutation({
    mutationFn: createPersonalItem,
    onSuccess: async () => {
      await refreshCollection()
      setShowAdd(false)
      setParams({})
    },
  })
  const likeMutation = useMutation({
    mutationFn: ({ itemId, isLiked }: { itemId: string; isLiked: boolean }) =>
      setLikedState(user!.id, itemId, isLiked),
    onSuccess: refreshCollection,
  })
  const saveMutation = useMutation({
    mutationFn: (itemId: string) => saveToCollection(user!.id, itemId),
    onSuccess: refreshCollection,
  })
  const dislikeMutation = useMutation({
    mutationFn: ({ itemId, isDisliked }: { itemId: string; isDisliked: boolean }) =>
      setDislikedState(user!.id, itemId, isDisliked),
    onSuccess: refreshCollection,
  })

  const collectionRows = useMemo(() => {
    if (!query.data) return []
    const itemById = new Map(query.data.items.map((item) => [item.id, item]))
    const confidenceById = new Map(query.data.confidence.map((row) => [row.knowledge_item_id, row.confidence_status]))
    return query.data.collections
      .flatMap((row) => {
        const item = itemById.get(row.knowledge_item_id)
        if (!item) return []
        return [{ item, collection: row, confidence: confidenceById.get(item.id) ?? ('New' as ConfidenceStatus) }]
      })
  }, [query.data])

  const savedRows = useMemo(
    () => collectionRows.filter((row) => row.collection.state === 'saved'),
    [collectionRows],
  )
  const dislikedRows = useMemo(
    () => collectionRows.filter((row) => row.collection.is_disliked),
    [collectionRows],
  )

  const confidenceCounts = useMemo(() => {
    const counts: Record<ConfidenceStatus, number> = { New: 0, Learning: 0, Confident: 0, 'Needs practice': 0 }
    for (const row of savedRows) counts[row.confidence] += 1
    return counts
  }, [savedRows])

  const likedCount = useMemo(() => savedRows.filter((row) => row.collection.is_liked).length, [savedRows])
  const dislikedCount = dislikedRows.length

  const statusFilteredRows = useMemo(() => {
    if (filter === 'Disliked') return dislikedRows
    return savedRows.filter((row) => {
      if (filter === 'All') return true
      if (filter === 'Liked') return row.collection.is_liked
      return row.confidence === filter
    })
  }, [dislikedRows, filter, savedRows])

  const selectedCategorySet = useMemo(() => new Set(selectedCategories), [selectedCategories])
  const categoryCounts = useMemo(() => {
    const counts = new Map<Category, number>()
    for (const { item } of statusFilteredRows) {
      for (const category of item.categories) {
        counts.set(category.id, (counts.get(category.id) ?? 0) + 1)
      }
    }
    return counts
  }, [statusFilteredRows])

  const filteredRows = useMemo(() => {
    if (!selectedCategorySet.size) return statusFilteredRows
    return statusFilteredRows.filter(({ item }) =>
      item.categories.some((category) => selectedCategorySet.has(category.id)),
    )
  }, [selectedCategorySet, statusFilteredRows])

  const practiceItemIds = useMemo(() => filteredRows.map((row) => row.item.id), [filteredRows])
  const selectedCategoryNames = useMemo(() => {
    const selected = new Set(selectedCategories)
    return query.data?.categories
      .filter((category) => selected.has(category.id))
      .map((category) => category.name) ?? []
  }, [query.data?.categories, selectedCategories])
  const practiceTabLabel = filter === 'All'
    ? null
    : filter === 'Confident'
      ? 'Mastered Terms'
      : filter === 'Needs practice'
        ? 'Needs Practice Terms'
        : `${filter} Terms`
  const storedPracticeFocus = [
    'My Collection',
    practiceTabLabel,
    selectedCategoryNames.length ? `Categories: ${selectedCategoryNames.join(', ')}` : null,
  ].filter(Boolean).join(' | ')
  const practiceScopeLabel = selectedCategories.length
    ? `${selectedCategories.length} selected ${selectedCategories.length === 1 ? 'category' : 'categories'}`
    : filter === 'All' ? 'all collection' : filter.toLowerCase()

  const practiceMutation = useMutation({
    mutationFn: () => createScopedPracticeAttempt({
      source: filter === 'Disliked' ? 'recommended' : 'word_bank',
      requestedLength: 15,
      itemIds: practiceItemIds,
      focusLabel: storedPracticeFocus,
    }),
    onSuccess: (attempt) => navigate(`/practice/${attempt.attempt_id}`),
    onError: (caught) => setPracticeError(caught instanceof Error ? caught.message : 'Unable to start practice.'),
  })

  const rows = useMemo(() => {
    const normalizedSearch = search.trim().toLocaleLowerCase()
    return filteredRows
      .filter(({ item }) => !normalizedSearch || [
        item.term,
        item.meaning,
        item.example_sentence,
        ...item.categories.map((category) => category.name),
      ].some((value) => value.toLocaleLowerCase().includes(normalizedSearch)))
      .slice()
      .sort((first, second) => {
        if (sort === 'alphabetical') return first.item.term.localeCompare(second.item.term)
        if (sort === 'reverse-alphabetical') return second.item.term.localeCompare(first.item.term)
        if (sort === 'needs-practice') {
          return confidenceOrder[first.confidence] - confidenceOrder[second.confidence]
            || first.item.term.localeCompare(second.item.term)
        }
        return new Date(second.collection.created_at).getTime() - new Date(first.collection.created_at).getTime()
          || first.item.term.localeCompare(second.item.term)
      })
  }, [filteredRows, search, sort])

  const toggleCategory = (category: Category) => {
    setSelectedCategories((current) => current.includes(category)
      ? current.filter((selected) => selected !== category)
      : [...current, category])
  }

  const clearFilters = () => {
    setSearch('')
    setFilter('All')
    setSelectedCategories([])
  }

  if (query.isLoading) return <LoadingState label="Opening your collection…" />
  if (query.error || !query.data) return <ErrorState message={query.error?.message ?? 'No data found.'} />

  async function handleAdd(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setFormError('')
    const form = new FormData(event.currentTarget)
    const parsed = itemSchema.safeParse({
      term: form.get('term'),
      meaning: form.get('meaning'),
      example: form.get('example'),
      primary_category: form.get('primary_category'),
      secondary_categories: form.getAll('secondary_categories'),
      difficulty: form.get('difficulty'),
    })
    if (!parsed.success) {
      setFormError(parsed.error.issues[0]?.message ?? 'Check the details and try again.')
      return
    }
    try {
      await addMutation.mutateAsync(parsed.data)
    } catch (caught) {
      setFormError(caught instanceof Error ? caught.message : 'Unable to add this item.')
    }
  }

  return (
    <div className="page collection-page">
      <header className="page-heading heading-with-action">
        <div><h1>My Collection</h1><p>Your personal collection of terms.</p></div>
        <div className="collection-heading-actions">
          <button
            className="primary-button collection-practice"
            disabled={!practiceItemIds.length || practiceMutation.isPending}
            aria-label={`Practise ${practiceScopeLabel} terms`}
            onClick={() => { setPracticeError(''); practiceMutation.mutate() }}
          ><Play aria-hidden="true" /> {practiceMutation.isPending ? 'Starting…' : 'Practise collection'}</button>
          <button className="secondary-button" onClick={() => setShowAdd(true)}><CirclePlus aria-hidden="true" /> Add a term</button>
        </div>
      </header>

      <div className="collection-overview">
        <section className="collection-summary" aria-label="Collection summary">
          <article className="collection-summary-card total"><span><BookOpenCheck aria-hidden="true" /></span><div><strong>{savedRows.length}</strong><small>Total terms</small></div></article>
          <article className="collection-summary-card confident"><span><Check aria-hidden="true" /></span><div><strong>{confidenceCounts.Confident}</strong><small>Mastered</small></div></article>
          <article className="collection-summary-card learning"><span><Sparkles aria-hidden="true" /></span><div><strong>{confidenceCounts.Learning}</strong><small>Learning</small></div></article>
          <article className="collection-summary-card needs-practice"><span><BarChart3 aria-hidden="true" /></span><div><strong>{confidenceCounts['Needs practice']}</strong><small>Needs practice</small></div></article>
          <article className="collection-summary-card liked"><span><Heart aria-hidden="true" fill="currentColor" /></span><div><strong>{likedCount}</strong><small>Liked terms</small></div></article>
          <article className="collection-summary-card disliked"><span><ThumbsDown aria-hidden="true" fill="currentColor" /></span><div><strong>{dislikedCount}</strong><small>Disliked terms</small></div></article>
        </section>
      </div>
      {practiceError ? <p className="form-error" role="alert">{practiceError}</p> : null}

      <section className="collection-toolbar" aria-label="Collection controls">
        <label className="collection-search"><span className="sr-only">Search your collection</span><Search aria-hidden="true" /><input type="search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search your collection" /></label>
        <div className="confidence-filters" aria-label="Filter by confidence">
          {(['All', 'Liked', 'Disliked', 'New', 'Learning', 'Confident', 'Needs practice'] as const).map((status) => {
            const count = status === 'All' ? savedRows.length : status === 'Liked' ? likedCount : status === 'Disliked' ? dislikedCount : confidenceCounts[status]
            const label = status === 'Confident' ? 'Mastered' : status
            return <button key={status} aria-label={`${label}: ${count}`} className={filter === status ? 'is-active' : ''} onClick={() => setFilter(status)}>{label}</button>
          })}
        </div>
        <details className="collection-category-filter">
          <summary aria-label={`Filter by categories${selectedCategories.length ? `, ${selectedCategories.length} selected` : ''}`}>
            <Tags aria-hidden="true" />
            <span>Categories</span>
            {selectedCategories.length ? <strong>{selectedCategories.length}</strong> : null}
            <ChevronDown className="category-filter-chevron" aria-hidden="true" />
          </summary>
          <fieldset className="collection-category-menu">
            <legend className="sr-only">Filter by categories</legend>
            <header>
              <div><strong>Categories</strong><small>Select one or more</small></div>
              {selectedCategories.length ? <button type="button" onClick={() => setSelectedCategories([])}>Clear</button> : null}
            </header>
            <div className="collection-category-options">
              {query.data.categories.map((category) => (
                <label className="collection-category-option" key={category.id}>
                  <input
                    type="checkbox"
                    checked={selectedCategorySet.has(category.id)}
                    onChange={() => toggleCategory(category.id)}
                  />
                  <span>{category.name}</span>
                  <small>{categoryCounts.get(category.id) ?? 0}</small>
                </label>
              ))}
            </div>
          </fieldset>
        </details>
        <label className="collection-sort"><span className="sr-only">Sort collection</span><select value={sort} onChange={(event) => setSort(event.target.value as CollectionSort)}><option value="recent">Recently added</option><option value="alphabetical">A to Z</option><option value="reverse-alphabetical">Z to A</option><option value="needs-practice">Needs practice first</option></select></label>
      </section>

      {selectedCategories.length ? (
        <div className="selected-category-filters" aria-label="Selected category filters">
          {selectedCategories.map((categoryId) => {
            const category = query.data.categories.find((candidate) => candidate.id === categoryId)
            if (!category) return null
            return (
              <button key={category.id} type="button" onClick={() => toggleCategory(category.id)}>
                {category.name}<X aria-hidden="true" />
              </button>
            )
          })}
          <button className="clear-category-filters" type="button" onClick={() => setSelectedCategories([])}>Clear categories</button>
        </div>
      ) : null}

      {rows.length ? (
        <section className="collection-list" aria-label={filter === 'Disliked' ? 'Disliked terms' : 'Saved terms'}>
          {rows.map(({ item, collection, confidence }) => {
            const isUpdating = (removeMutation.isPending && removeMutation.variables === item.id)
              || (saveMutation.isPending && saveMutation.variables === item.id)
              || (likeMutation.isPending && likeMutation.variables?.itemId === item.id)
              || (dislikeMutation.isPending && dislikeMutation.variables?.itemId === item.id)
            return (
              <article className="collection-row" key={item.id} aria-busy={isUpdating}>
              <div className="collection-card-copy">
                <h2>{item.term}</h2>
                <p>{item.meaning}</p>
                <CategoryTags item={item} />
                <div className="collection-card-meta"><small><BarChart3 aria-hidden="true" />{item.source === 'user_added' ? 'Personal' : item.difficulty}</small><span className={`confidence-status ${confidenceClass[confidence]}`}><i />{confidenceLabel(confidence)}</span></div>
              </div>
              <div className="collection-card-actions">
                <button
                  className={`icon-button ${collection.is_liked ? 'is-liked' : ''}`}
                  aria-label={`${collection.is_liked ? 'Unlike' : 'Like'} ${item.term}`}
                  data-tooltip={collection.is_liked ? 'Remove from favourites' : 'Add to favourites'}
                  disabled={isUpdating}
                  onClick={() => likeMutation.mutate({ itemId: item.id, isLiked: !collection.is_liked })}
                ><Heart aria-hidden="true" fill={collection.is_liked ? 'currentColor' : 'none'} /></button>
                <button
                  className={`icon-button ${collection.state === 'saved' ? 'is-selected' : ''}`}
                  aria-label={collection.state === 'saved' ? `Remove ${item.term} from My Collection` : `Add ${item.term} to My Collection`}
                  data-tooltip={collection.state === 'saved' ? 'Remove from My Collection' : 'Add to My Collection'}
                  disabled={isUpdating}
                  onClick={() => collection.state === 'saved' ? removeMutation.mutate(item.id) : saveMutation.mutate(item.id)}
                >
                  {collection.state === 'saved' ? <BookmarkMinus aria-hidden="true" /> : <Bookmark aria-hidden="true" />}
                </button>
                <button
                  className={`icon-button ${collection.is_disliked ? 'is-disliked' : ''}`}
                  aria-label={`${collection.is_disliked ? 'Remove dislike for' : 'Dislike'} ${item.term}`}
                  data-tooltip={collection.is_disliked ? 'Remove dislike' : 'Dislike'}
                  disabled={isUpdating}
                  onClick={() => dislikeMutation.mutate({ itemId: item.id, isDisliked: !collection.is_disliked })}
                >
                  <ThumbsDown aria-hidden="true" fill={collection.is_disliked ? 'currentColor' : 'none'} />
                </button>
              </div>
              </article>
            )
          })}
        </section>
      ) : (
        <div className="empty-state"><h2>{filter === 'Liked' ? 'No liked terms yet' : filter === 'Disliked' ? 'No disliked terms' : savedRows.length ? 'No matching terms' : 'No terms here yet'}</h2><p>{filter === 'Liked' ? 'Use the heart on any term to add it to your favourites.' : filter === 'Disliked' ? 'Use the thumbs-down icon on any term you dislike and it will appear here.' : savedRows.length ? 'Try another search, status or category filter.' : 'Save something from the Library or add a term of your own.'}</p>{savedRows.length || filter === 'Disliked' ? <button className="secondary-button" onClick={clearFilters}>Clear filters</button> : null}</div>
      )}

      {showAdd ? (
        <div className="dialog-backdrop" role="presentation">
          <section className="dialog-panel" role="dialog" aria-modal="true" aria-labelledby="add-word-title">
            <header><div><h2 id="add-word-title">Add to My Collection</h2><p>Use language that will still make sense later.</p></div><button className="icon-button" data-tooltip="Close" onClick={() => { setShowAdd(false); setParams({}) }} aria-label="Close"><X /></button></header>
            <form onSubmit={handleAdd}>
              <label>Term<input name="term" required maxLength={160} /></label>
              <label>Plain-English meaning<textarea name="meaning" required rows={3} maxLength={600} /></label>
              <label>Example sentence<textarea name="example" required rows={3} maxLength={800} /></label>
              <div className="form-grid">
                <label>Primary category<select name="primary_category" value={primaryCategory} onChange={(event) => setPrimaryCategory(event.target.value as Category)}>{query.data.categories.map((category) => <option key={category.id} value={category.id}>{category.name}</option>)}</select></label>
                <label>Difficulty<select name="difficulty" defaultValue="intermediate"><option value="beginner">Beginner</option><option value="intermediate">Intermediate</option><option value="advanced">Advanced</option></select></label>
              </div>
              <fieldset className="secondary-category-options">
                <legend>Secondary categories <small>Optional</small></legend>
                <p>Add this term to any other relevant categories.</p>
                <div>
                  {query.data.categories.map((category) => (
                    <label className="check-option" key={category.id}>
                      <input
                        type="checkbox"
                        name="secondary_categories"
                        value={category.id}
                        disabled={category.id === primaryCategory}
                      />
                      <span>{category.name}</span>
                    </label>
                  ))}
                </div>
              </fieldset>
              {formError ? <p className="form-error" role="alert">{formError}</p> : null}
              <button className="primary-button" disabled={addMutation.isPending} type="submit">{addMutation.isPending ? 'Adding…' : 'Add to My Collection'}</button>
            </form>
          </section>
        </div>
      ) : null}
    </div>
  )
}
