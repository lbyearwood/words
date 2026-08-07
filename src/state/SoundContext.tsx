import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { useAuth } from './AuthContext'

type SoundName = 'correct' | 'incorrect' | 'victory'

interface SoundContextValue {
  soundEnabled: boolean
  setSoundEnabled: (enabled: boolean) => void
  playSound: (sound: SoundName) => void
}

const soundUrls: Record<SoundName, string> = {
  correct: new URL('../../sounds/freesound_community-ui_correct_button2-103167.mp3', import.meta.url).href,
  incorrect: new URL('../../sounds/universfield-wrong-answer-126515.mp3', import.meta.url).href,
  victory: new URL('../../sounds/emand_edroff-victory-bell-success-fanfare-576275.mp3', import.meta.url).href,
}

const soundVolumes: Record<SoundName, number> = {
  correct: 0.5,
  incorrect: 0.45,
  victory: 0.5,
}

const SoundContext = createContext<SoundContextValue | null>(null)

function preferenceKey(userId: string | undefined) {
  return `vocab-express:sound:${userId ?? 'guest'}`
}

export function SoundProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth()
  const [preferenceOverrides, setPreferenceOverrides] = useState<Record<string, boolean>>({})
  const activePreferenceKey = preferenceKey(user?.id)
  const soundEnabled = preferenceOverrides[activePreferenceKey]
    ?? localStorage.getItem(activePreferenceKey) !== 'off'

  useEffect(() => {
    for (const url of Object.values(soundUrls)) {
      const audio = new Audio(url)
      audio.preload = 'auto'
    }
  }, [])

  const setSoundEnabled = useCallback((enabled: boolean) => {
    setPreferenceOverrides((current) => ({ ...current, [activePreferenceKey]: enabled }))
    localStorage.setItem(activePreferenceKey, enabled ? 'on' : 'off')
  }, [activePreferenceKey])

  const playSound = useCallback((sound: SoundName) => {
    if (!soundEnabled) return
    const audio = new Audio(soundUrls[sound])
    audio.volume = soundVolumes[sound]
    void audio.play().catch(() => {
      // Browsers can block audio when a user gesture has not yet occurred.
    })
  }, [soundEnabled])

  const value = useMemo(() => ({ soundEnabled, setSoundEnabled, playSound }), [playSound, setSoundEnabled, soundEnabled])

  return <SoundContext.Provider value={value}>{children}</SoundContext.Provider>
}

// eslint-disable-next-line react-refresh/only-export-components
export function useSound() {
  const context = useContext(SoundContext)
  if (!context) throw new Error('useSound must be used inside SoundProvider')
  return context
}
