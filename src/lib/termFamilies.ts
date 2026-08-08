import type { KnowledgeItem } from './types'

export interface TermFamilyGroup {
  id: string
  term: string
  items: KnowledgeItem[]
}

function fallbackFamilyId(term: string) {
  return term.trim().replace(/\s+/g, ' ').toLocaleLowerCase('en-GB')
}

export function groupKnowledgeItems(items: KnowledgeItem[]): TermFamilyGroup[] {
  const groups = new Map<string, TermFamilyGroup>()

  for (const item of items) {
    const id = item.term_family_id || fallbackFamilyId(item.term)
    const group = groups.get(id) ?? { id, term: item.term, items: [] }
    group.items.push(item)
    groups.set(id, group)
  }

  return [...groups.values()].map((group) => ({
    ...group,
    items: group.items.slice().sort((first, second) =>
      first.sense_order - second.sense_order || first.meaning.localeCompare(second.meaning, 'en-GB'),
    ),
  }))
}
