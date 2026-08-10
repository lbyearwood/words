import { dehydrate, hydrate, QueryClient } from '@tanstack/react-query'

const CACHE_DATABASE = 'brain-express-cache'
const CACHE_STORE = 'learner-queries'
const CACHE_VERSION = 'personalised-v2-2026-08-10'
const CACHE_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000

const persistedQueryRoots = new Set([
  'app-data',
  'collection-data',
  'learning-dashboard',
  'library-data',
  'points-summary',
  'practice-setup-counts',
  'progress-data',
])

interface PersistedLearnerCache {
  version: string
  savedAt: number
  state: ReturnType<typeof dehydrate>
}

let activeUserId: string | null = null
let persistTimer: ReturnType<typeof setTimeout> | null = null
let unsubscribe: (() => void) | null = null

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 20_000,
      gcTime: 24 * 60 * 60 * 1000,
      retry: 1,
      refetchOnWindowFocus: false,
      refetchOnReconnect: true,
    },
  },
})

function supportsIndexedDb() {
  return typeof indexedDB !== 'undefined'
}

function openCacheDatabase(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(CACHE_DATABASE, 1)
    request.onupgradeneeded = () => {
      const database = request.result
      if (!database.objectStoreNames.contains(CACHE_STORE)) database.createObjectStore(CACHE_STORE)
    }
    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error ?? new Error('Unable to open the learner cache.'))
  })
}

async function readCache(userId: string): Promise<PersistedLearnerCache | null> {
  if (!supportsIndexedDb()) return null
  const database = await openCacheDatabase()
  try {
    return await new Promise((resolve, reject) => {
      const transaction = database.transaction(CACHE_STORE, 'readonly')
      const request = transaction.objectStore(CACHE_STORE).get(userId)
      request.onsuccess = () => resolve((request.result as PersistedLearnerCache | undefined) ?? null)
      request.onerror = () => reject(request.error ?? new Error('Unable to read the learner cache.'))
    })
  } finally {
    database.close()
  }
}

async function writeCache(userId: string, cache: PersistedLearnerCache): Promise<void> {
  if (!supportsIndexedDb()) return
  const database = await openCacheDatabase()
  try {
    await new Promise<void>((resolve, reject) => {
      const transaction = database.transaction(CACHE_STORE, 'readwrite')
      transaction.objectStore(CACHE_STORE).put(cache, userId)
      transaction.oncomplete = () => resolve()
      transaction.onerror = () => reject(transaction.error ?? new Error('Unable to save the learner cache.'))
      transaction.onabort = () => reject(transaction.error ?? new Error('Saving the learner cache was interrupted.'))
    })
  } finally {
    database.close()
  }
}

async function deleteCache(userId: string): Promise<void> {
  if (!supportsIndexedDb()) return
  const database = await openCacheDatabase()
  try {
    await new Promise<void>((resolve, reject) => {
      const transaction = database.transaction(CACHE_STORE, 'readwrite')
      transaction.objectStore(CACHE_STORE).delete(userId)
      transaction.oncomplete = () => resolve()
      transaction.onerror = () => reject(transaction.error ?? new Error('Unable to clear the learner cache.'))
      transaction.onabort = () => reject(transaction.error ?? new Error('Clearing the learner cache was interrupted.'))
    })
  } finally {
    database.close()
  }
}

function queryBelongsToUser(queryKey: readonly unknown[], userId: string) {
  return persistedQueryRoots.has(String(queryKey[0])) && queryKey[1] === userId
}

async function persistActiveUser() {
  const userId = activeUserId
  if (!userId) return
  const state = dehydrate(queryClient, {
    shouldDehydrateQuery: (query) => query.state.status === 'success' && queryBelongsToUser(query.queryKey, userId),
  })
  await writeCache(userId, { version: CACHE_VERSION, savedAt: Date.now(), state })
}

function schedulePersistence() {
  if (!activeUserId) return
  if (persistTimer) clearTimeout(persistTimer)
  persistTimer = setTimeout(() => {
    persistTimer = null
    void persistActiveUser().catch(() => {
      // Browser storage can be unavailable in private modes. Network data remains authoritative.
    })
  }, 500)
}

export function startPersistentQueryCache() {
  if (unsubscribe) return
  unsubscribe = queryClient.getQueryCache().subscribe(schedulePersistence)
}

export async function restoreUserQueryCache(userId: string) {
  try {
    const cache = await readCache(userId)
    if (!cache || cache.version !== CACHE_VERSION || Date.now() - cache.savedAt > CACHE_MAX_AGE_MS) {
      if (cache) await deleteCache(userId)
      return
    }
    hydrate(queryClient, cache.state)
  } catch {
    // A cache failure must never prevent sign-in or fresh data loading.
  }
}

export function activateUserQueryCache(userId: string) {
  activeUserId = userId
  schedulePersistence()
}

export async function clearUserQueryCache(userId: string) {
  if (activeUserId === userId) activeUserId = null
  if (persistTimer) {
    clearTimeout(persistTimer)
    persistTimer = null
  }
  queryClient.removeQueries({ predicate: (query) => query.queryKey[1] === userId })
  try {
    await deleteCache(userId)
  } catch {
    // Sign-out should still complete if browser storage is unavailable.
  }
}
