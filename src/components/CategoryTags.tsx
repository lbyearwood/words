import type { KnowledgeItem } from '../lib/types'

export function CategoryTags({ item }: { item: KnowledgeItem }) {
  return (
    <div className="category-tags" aria-label={`Categories for ${item.term}`}>
      {item.categories.map((category) => (
        <span className={category.is_primary ? 'is-primary' : ''} key={category.id}>
          {category.name}
          {category.is_primary ? <span className="sr-only"> (primary)</span> : null}
        </span>
      ))}
    </div>
  )
}
