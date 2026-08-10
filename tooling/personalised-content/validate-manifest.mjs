import { readFile, stat } from 'node:fs/promises'
import { resolve } from 'node:path'

const allowedDecisions = new Set(['keep', 'rewrite', 'change_sense', 'exclude'])
const allowedDifficulty = new Set(['beginner', 'intermediate', 'advanced'])
const allowedParts = new Set([
  'noun', 'verb', 'adjective', 'adverb', 'pronoun', 'preposition',
  'conjunction', 'determiner', 'interjection', 'phrase', 'idiom',
  'quotation', 'other',
])
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
const placeholder = /most precise term for the idea|describe a different word/i
const trailingParentheses = /\s+\([^)]*\)$/

function fail(message) {
  throw new Error(message)
}

function validateManifest(manifest, source) {
  if (!manifest || typeof manifest !== 'object') fail(`${source}: expected a JSON object`)
  if (typeof manifest.manifest_id !== 'string' || !manifest.manifest_id.trim()) fail(`${source}: manifest_id is required`)
  if (!uuid.test(manifest.user_id ?? '')) fail(`${source}: user_id must be a UUID`)
  if (!Number.isInteger(manifest.batch_number) || manifest.batch_number < 1) fail(`${source}: batch_number must be positive`)
  if (!Array.isArray(manifest.items) || manifest.items.length < 1 || manifest.items.length > 50) {
    fail(`${source}: items must contain 1 to 50 entries`)
  }

  const itemIds = new Set()
  for (const [index, item] of manifest.items.entries()) {
    const at = `${source}: item ${index + 1}`
    if (!uuid.test(item.learning_item_id ?? '')) fail(`${at}: learning_item_id must be a UUID`)
    if (itemIds.has(item.learning_item_id)) fail(`${at}: duplicate learning_item_id`)
    itemIds.add(item.learning_item_id)
    if (!allowedDecisions.has(item.decision)) fail(`${at}: invalid decision`)
    if (item.decision === 'exclude') {
      if (typeof item.reason !== 'string' || !item.reason.trim()) fail(`${at}: exclusions need a reason`)
      continue
    }
    for (const field of ['term', 'definition', 'example_sentence', 'part_of_speech', 'difficulty']) {
      if (typeof item[field] !== 'string' || !item[field].trim()) fail(`${at}: ${field} is required`)
    }
    if (!allowedParts.has(item.part_of_speech)) fail(`${at}: invalid part_of_speech`)
    if (!allowedDifficulty.has(item.difficulty)) fail(`${at}: invalid difficulty`)
    if (typeof item.importance !== 'number' || item.importance < 0 || item.importance > 1) fail(`${at}: importance must be 0–1`)
    if (placeholder.test(item.example_sentence)) fail(`${at}: placeholder example rejected`)
    if (!item.term.includes(' ') && (typeof item.pronunciation !== 'string' || !item.pronunciation.trim())) {
      fail(`${at}: a single word needs a recognisable pronunciation`)
    }
    if (trailingParentheses.test(item.term) && item.title_parentheses_approved !== true) {
      fail(`${at}: parenthetical title needs title_parentheses_approved: true`)
    }
    if (!Array.isArray(item.categories) || item.categories.length < 1) fail(`${at}: categories are required`)
    if (item.categories.filter((category) => category.is_primary === true).length !== 1) {
      fail(`${at}: exactly one category must be primary`)
    }
    const categoryIds = new Set()
    for (const category of item.categories) {
      if (!uuid.test(category.category_id ?? '')) fail(`${at}: category_id must be a UUID`)
      if (categoryIds.has(category.category_id)) fail(`${at}: duplicate category mapping`)
      categoryIds.add(category.category_id)
      if (typeof category.importance !== 'number' || category.importance < 0 || category.importance > 1) {
        fail(`${at}: category importance must be 0–1`)
      }
    }
  }
  return { manifest_id: manifest.manifest_id, item_count: manifest.items.length }
}

const input = resolve(process.argv[2] ?? '')
if (!process.argv[2]) fail('Usage: npm run content:validate -- <manifest.json>')
if (!(await stat(input)).isFile()) fail('Pass one manifest JSON file')
const manifest = JSON.parse(await readFile(input, 'utf8'))
const result = validateManifest(manifest, input)
process.stdout.write(`Valid manifest ${result.manifest_id}: ${result.item_count} items\n`)
