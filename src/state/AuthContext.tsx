import type { Session, User } from '@supabase/supabase-js'
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { activateUserQueryCache, clearUserQueryCache, restoreUserQueryCache } from '../lib/queryCache'
import { supabase } from '../lib/supabase'

interface AuthContextValue {
  session: Session | null
  user: User | null
  loading: boolean
  signIn: (email: string, password: string) => Promise<void>
  signOut: () => Promise<void>
}

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)

  const applySession = useCallback(async (nextSession: Session | null) => {
    if (nextSession) {
      await restoreUserQueryCache(nextSession.user.id)
      activateUserQueryCache(nextSession.user.id)
    }
    setSession(nextSession)
    setLoading(false)
  }, [])

  useEffect(() => {
    let active = true
    let authEventHandled = false

    const { data } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      if (!active) return
      authEventHandled = true
      void applySession(nextSession)
    })

    void supabase.auth.getSession().then(({ data: sessionData }) => {
      if (active && !authEventHandled) {
        void applySession(sessionData.session)
      }
    })

    return () => {
      active = false
      data.subscription.unsubscribe()
    }
  }, [applySession])

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      user: session?.user ?? null,
      loading,
      async signIn(email, password) {
        const { data, error } = await supabase.auth.signInWithPassword({ email, password })
        if (error) throw new Error(error.message)
        await applySession(data.session)
      },
      async signOut() {
        const userId = session?.user.id
        const { error } = await supabase.auth.signOut()
        if (error) throw new Error(error.message)
        if (userId) await clearUserQueryCache(userId)
        setSession(null)
      },
    }),
    [applySession, loading, session],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth() {
  const context = useContext(AuthContext)
  if (!context) throw new Error('useAuth must be used inside AuthProvider')
  return context
}
