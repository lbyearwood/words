import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import type { Session } from '@supabase/supabase-js'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { AuthProvider, useAuth } from './AuthContext'

const { getSession, signInWithPassword, unsubscribe } = vi.hoisted(() => ({
  getSession: vi.fn(),
  signInWithPassword: vi.fn(),
  unsubscribe: vi.fn(),
}))

vi.mock('../lib/supabase', () => ({
  supabase: {
    auth: {
      getSession,
      onAuthStateChange: vi.fn(() => ({ data: { subscription: { unsubscribe } } })),
      signInWithPassword,
      signOut: vi.fn(),
    },
  },
}))

const session = {
  access_token: 'access-token',
  refresh_token: 'refresh-token',
  expires_in: 3600,
  token_type: 'bearer',
  user: { id: 'max-id', email: 'max@vocab.local' },
} as Session

function AuthHarness() {
  const { user, loading, signIn } = useAuth()
  return (
    <>
      <span>{loading ? 'Loading' : user?.email ?? 'Signed out'}</span>
      <button onClick={() => void signIn('max@vocab.local', 'password')}>Sign in</button>
    </>
  )
}

describe('AuthProvider', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    getSession.mockResolvedValue({ data: { session: null } })
    signInWithPassword.mockResolvedValue({ data: { session }, error: null })
  })

  it('applies the returned password session without waiting for an auth event', async () => {
    render(<AuthProvider><AuthHarness /></AuthProvider>)

    await screen.findByText('Signed out')
    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }))

    await waitFor(() => expect(screen.getByText('max@vocab.local')).toBeVisible())
    expect(signInWithPassword).toHaveBeenCalledWith({ email: 'max@vocab.local', password: 'password' })
  })
})
