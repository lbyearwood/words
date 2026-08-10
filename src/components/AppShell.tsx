import { useEffect, useState } from 'react'
import { useIsFetching } from '@tanstack/react-query'
import { BarChart3, BookOpen, Bookmark, Home, LogOut, PencilLine, RefreshCw, Settings, UserRound, Volume2, VolumeX, X } from 'lucide-react'
import { NavLink, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '../state/AuthContext'
import { useSound } from '../state/SoundContext'
import { Brand } from './Brand'
import { DataWarmup } from './DataWarmup'

const navigation = [
  { to: '/', label: 'Home', icon: Home },
  { to: '/library', label: 'Library', icon: BookOpen },
  { to: '/collection', label: 'My Collection', icon: Bookmark },
  { to: '/practice', label: 'Practice', icon: PencilLine },
  { to: '/progress', label: 'My Progress', icon: BarChart3 },
  { to: '/profile', label: 'Profile', icon: UserRound },
]

export function AppShell() {
  const location = useLocation()
  const { signOut } = useAuth()
  const { soundEnabled, setSoundEnabled } = useSound()
  const [showSettings, setShowSettings] = useState(false)
  const syncingLearnerData = useIsFetching({
    predicate: (query) => ['collection-data', 'library-data'].includes(String(query.queryKey[0])),
  }) > 0

  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: 'auto' })
  }, [location.pathname])

  useEffect(() => {
    if (!showSettings) return
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setShowSettings(false)
    }
    window.addEventListener('keydown', closeOnEscape)
    return () => window.removeEventListener('keydown', closeOnEscape)
  }, [showSettings])

  return (
    <div className="app-shell">
      <DataWarmup />
      <aside className="desktop-sidebar">
        <Brand />
        <nav aria-label="Primary navigation">
          {navigation.map(({ to, label, icon: Icon }) => (
            <NavLink key={to} to={to} end={to === '/'}>
              <Icon aria-hidden="true" />
              <span>{label}</span>
            </NavLink>
          ))}
          <button type="button" className="sidebar-settings" onClick={() => setShowSettings(true)}>
            <Settings aria-hidden="true" />
            <span>Settings</span>
          </button>
          <button type="button" className="sidebar-sign-out" onClick={() => void signOut()}>
            <LogOut aria-hidden="true" />
            <span>Sign out</span>
          </button>
        </nav>
        <p className="sidebar-note">Keep learning, every day.</p>
      </aside>

      <div className="app-frame">
        <header className="mobile-header">
          <Brand />
          <div className="mobile-header-actions">
            <button type="button" className="mobile-header-action" onClick={() => setShowSettings(true)} aria-label="Settings" data-tooltip="Settings"><Settings aria-hidden="true" /></button>
            <button type="button" className="mobile-header-action" onClick={() => void signOut()} aria-label="Sign out" data-tooltip="Sign out"><LogOut aria-hidden="true" /></button>
          </div>
        </header>
        <main className="main-content">
          <Outlet />
        </main>
        <nav className="bottom-nav" aria-label="Primary navigation">
          {navigation.map(({ to, label, icon: Icon }) => (
            <NavLink key={to} to={to} end={to === '/'}>
              <Icon aria-hidden="true" />
              <span>{label}</span>
            </NavLink>
          ))}
        </nav>
      </div>

      {syncingLearnerData ? (
        <div className="background-sync-status" role="status" aria-live="polite">
          <RefreshCw className="spin" aria-hidden="true" />
          <span>Synchronising your terms…</span>
        </div>
      ) : null}

      {showSettings ? (
        <div className="dialog-backdrop settings-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setShowSettings(false) }}>
          <section className="dialog-panel settings-dialog" role="dialog" aria-modal="true" aria-labelledby="settings-title">
            <header>
              <div><h2 id="settings-title">Settings</h2><p>Choose how Brain Express responds while you practise.</p></div>
              <button type="button" className="icon-button" aria-label="Close settings" data-tooltip="Close" onClick={() => setShowSettings(false)}><X aria-hidden="true" /></button>
            </header>
            <div className="sound-setting-row">
              <span className="sound-setting-icon">{soundEnabled ? <Volume2 aria-hidden="true" /> : <VolumeX aria-hidden="true" />}</span>
              <div><h3>Sound effects</h3><p>Play feedback after answers and a fanfare when a quiz is complete.</p></div>
              <button
                type="button"
                className={`sound-toggle ${soundEnabled ? 'is-on' : ''}`}
                role="switch"
                aria-checked={soundEnabled}
                aria-label="Sound effects"
                onClick={() => setSoundEnabled(!soundEnabled)}
              ><span aria-hidden="true" /></button>
            </div>
          </section>
        </div>
      ) : null}
    </div>
  )
}
