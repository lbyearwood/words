import { useMemo, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { ArrowUpDown, Bookmark, BookmarkCheck, BookOpen, Heart, Search, ThumbsDown } from 'lucide-react'
import { CategoryTags } from '../components/CategoryTags'
import { ErrorState, LoadingState } from '../components/PageState'
import { useAppData } from '../hooks/useAppData'
import { saveToCollection, setDislikedState, setLikedState } from '../lib/api'
import { itemHasCategory, type Category, type Difficulty } from '../lib/types'
import { useAuth } from '../state/AuthContext'

type LibrarySort = 'alphabetical' | 'reverse-alphabetical' | 'difficulty-ascending' | 'difficulty-descending'

const quickCategoryIds: Category[] = [
  'general_vocabulary',
  'sophisticated_speaker',
  'professional_communication',
]

const difficultyRank: Record<Difficulty, number> = {
  beginner: 0,
  intermediate: 1,
  advanced: 2,
}

export function LibraryPage() {
  const { user } = useAuth()
  const query = useAppData()
  const queryClient = useQueryClient()
  const [search, setSearch] = useState('')
  const [category, setCategory] = useState<'all' | Category>('all')
  const [difficulty, setDifficulty] = useState<'all' | Difficulty>('all')
  const [sort, setSort] = useState<LibrarySort>('alphabetical')

  const collectionMutation = useMutation({
    mutationFn: (itemId: string) => saveToCollection(user!.id, itemId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['app-data', user!.id] }),
  })
  const likeMutation = useMutation({
    mutationFn: ({ itemId, isLiked }: { itemId: string; isLiked: boolean }) =>
      setLikedState(user!.id, itemId, isLiked),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['app-data', user!.id] }),
  })
  const dislikeMutation = useMutation({
    mutationFn: ({ itemId, isDisliked }: { itemId: string; isDisliked: boolean }) =>
      setDislikedState(user!.id, itemId, isDisliked),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['app-data', user!.id] }),
  })

  const filtered = useMemo(() => {
    if (!query.data) return []
    const needle = search.trim().toLocaleLowerCase()
    const items = query.data.items
      .filter((item) => item.source === 'seeded')
      .filter((item) => category === 'all' || itemHasCategory(item, category))
      .filter((item) => difficulty === 'all' || item.difficulty === difficulty)
      .filter((item) => !needle || `${item.term} ${item.meaning}`.toLocaleLowerCase().includes(needle))

    return [...items].sort((a, b) => {
      if (sort === 'difficulty-ascending' || sort === 'difficulty-descending') {
        const direction = sort === 'difficulty-ascending' ? 1 : -1
        const difference = (difficultyRank[a.difficulty] - difficultyRank[b.difficulty]) * direction
        if (difference !== 0) return difference
      }

      const alphabetical = a.term.localeCompare(b.term, 'en-GB', { sensitivity: 'base' })
      return sort === 'reverse-alphabetical' ? -alphabetical : alphabetical
    })
  }, [category, difficulty, query.data, search, sort])

  if (query.isLoading) return <LoadingState label="Opening the Library…" />
  if (query.error || !query.data) return <ErrorState message={query.error?.message ?? 'No data found.'} />

  const relationByItem = new Map(query.data.collections.map((row) => [row.knowledge_item_id, row]))
  const quickCategories = quickCategoryIds
    .map((id) => query.data.categories.find((option) => option.id === id))
    .filter((option) => option !== undefined)

  return (
    <div className="page library-page">
      <header className="page-heading library-heading">
        <div>
          <h1>Library</h1>
          <p>Browse useful terms, then save the ones that matter.</p>
          <div className="list-summary" aria-live="polite">
            <BookOpen aria-hidden="true" />
            <strong>{filtered.length}</strong> {filtered.length === 1 ? 'term' : 'terms'}
          </div>
        </div>
      </header>

      <section className="library-filter-panel" aria-label="Library filters">
        <label className="library-search-field">
          <Search aria-hidden="true" />
          <span className="sr-only">Search terms</span>
          <input
            type="search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search terms"
          />
        </label>
        <label className="library-select-field">
          <span className="sr-only">Category</span>
          <select value={category} onChange={(event) => setCategory(event.target.value as 'all' | Category)}>
            <option value="all">All categories</option>
            {query.data.categories.map((option) => <option key={option.id} value={option.id}>{option.name}</option>)}
          </select>
        </label>
        <label className="library-select-field">
          <span className="sr-only">Difficulty</span>
          <select value={difficulty} onChange={(event) => setDifficulty(event.target.value as 'all' | Difficulty)}>
            <option value="all">All levels</option>
            <option value="beginner">Beginner</option>
            <option value="intermediate">Intermediate</option>
            <option value="advanced">Advanced</option>
          </select>
        </label>
        <label className="library-select-field library-sort-field">
          <ArrowUpDown aria-hidden="true" />
          <span className="sr-only">Sort</span>
          <select value={sort} onChange={(event) => setSort(event.target.value as LibrarySort)}>
            <option value="alphabetical">A to Z</option>
            <option value="reverse-alphabetical">Z to A</option>
            <option value="difficulty-ascending">Level: low to high</option>
            <option value="difficulty-descending">Level: high to low</option>
          </select>
        </label>
      </section>

      <div className="library-quick-filters" role="group" aria-label="Popular categories">
        <button
          type="button"
          className={category === 'all' ? 'is-selected' : ''}
          aria-pressed={category === 'all'}
          onClick={() => setCategory('all')}
        >All</button>
        {quickCategories.map((option) => (
          <button
            type="button"
            key={option.id}
            className={category === option.id ? 'is-selected' : ''}
            aria-pressed={category === option.id}
            onClick={() => setCategory(option.id)}
          >{option.name}</button>
        ))}
      </div>

      <section className="word-list" aria-label="Library terms">
        {filtered.map((item) => {
          const relation = relationByItem.get(item.id)
          const state = relation?.state
          const isLiked = relation?.is_liked ?? false
          const isDisliked = relation?.is_disliked ?? false
          const isUpdating = (collectionMutation.isPending && collectionMutation.variables === item.id)
            || (likeMutation.isPending && likeMutation.variables?.itemId === item.id)
            || (dislikeMutation.isPending && dislikeMutation.variables?.itemId === item.id)
          return (
            <article className="word-row" key={item.id} aria-busy={isUpdating}>
              <div className="word-copy">
                <div className="word-title-line"><h2>{item.term}</h2><span className="difficulty-badge">{item.difficulty}</span></div>
                <p>{item.meaning}</p>
                <blockquote>{item.example_sentence}</blockquote>
                <CategoryTags item={item} />
              </div>
              <div className="word-actions">
                <button
                  className={`icon-button ${isLiked ? 'is-liked' : ''}`}
                  aria-label={`${isLiked ? 'Unlike' : 'Like'} ${item.term}`}
                  data-tooltip={isLiked ? 'Remove from favourites' : 'Add to favourites'}
                  disabled={isUpdating}
                  onClick={() => likeMutation.mutate({ itemId: item.id, isLiked: !isLiked })}
                ><Heart aria-hidden="true" fill={isLiked ? 'currentColor' : 'none'} /></button>
                <button
                  className={`icon-button ${state === 'saved' ? 'is-selected' : ''}`}
                  aria-label={`${state === 'saved' ? 'Saved in My Collection' : 'Add to My Collection'}: ${item.term}`}
                  data-tooltip={state === 'saved' ? 'Saved in My Collection' : 'Add to My Collection'}
                  disabled={isUpdating}
                  onClick={() => collectionMutation.mutate(item.id)}
                >{state === 'saved' ? <BookmarkCheck aria-hidden="true" /> : <Bookmark aria-hidden="true" />}</button>
                <button
                  className={`icon-button ${isDisliked ? 'is-disliked' : ''}`}
                  aria-label={`${isDisliked ? 'Remove dislike for' : 'Dislike'} ${item.term}`}
                  data-tooltip={isDisliked ? 'Remove dislike' : 'Dislike'}
                  disabled={isUpdating}
                  onClick={() => dislikeMutation.mutate({ itemId: item.id, isDisliked: !isDisliked })}
                ><ThumbsDown aria-hidden="true" fill={isDisliked ? 'currentColor' : 'none'} /></button>
              </div>
            </article>
          )
        })}
        {filtered.length === 0 && (
          <div className="library-empty-state">
            <BookOpen aria-hidden="true" />
            <h2>No matching terms</h2>
            <p>Try a different search, category or level.</p>
            <button
              type="button"
              className="secondary-button"
              onClick={() => { setSearch(''); setCategory('all'); setDifficulty('all') }}
            >Clear filters</button>
          </div>
        )}
      </section>
    </div>
  )
}
