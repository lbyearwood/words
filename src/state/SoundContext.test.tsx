import { fireEvent, render, screen } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { SoundProvider, useSound } from './SoundContext'

vi.mock('./AuthContext', () => ({
  useAuth: () => ({ user: { id: 'max-test' } }),
}))

const createdAudio: MockAudio[] = []

class MockAudio {
  src: string
  preload = ''
  volume = 1
  play = vi.fn().mockResolvedValue(undefined)

  constructor(src = '') {
    this.src = src
    createdAudio.push(this)
  }
}

function SoundHarness() {
  const { soundEnabled, setSoundEnabled, playSound } = useSound()
  return (
    <>
      <span>{soundEnabled ? 'Sound on' : 'Sound off'}</span>
      <button onClick={() => setSoundEnabled(!soundEnabled)}>Toggle sound</button>
      <button onClick={() => playSound('correct')}>Play correct</button>
    </>
  )
}

describe('SoundProvider', () => {
  beforeEach(() => {
    localStorage.clear()
    createdAudio.length = 0
    vi.stubGlobal('Audio', MockAudio)
  })

  it('plays the correct-answer asset and persists a disabled preference per user', () => {
    const view = render(<SoundProvider><SoundHarness /></SoundProvider>)

    expect(screen.getByText('Sound on')).toBeVisible()
    fireEvent.click(screen.getByRole('button', { name: 'Play correct' }))
    expect(createdAudio.at(-1)?.src).toContain('freesound_community-ui_correct_button2-103167.mp3')
    expect(createdAudio.at(-1)?.play).toHaveBeenCalledOnce()

    fireEvent.click(screen.getByRole('button', { name: 'Toggle sound' }))
    expect(screen.getByText('Sound off')).toBeVisible()
    expect(localStorage.getItem('vocab-express:sound:max-test')).toBe('off')

    const countBeforeMutedPlay = createdAudio.length
    fireEvent.click(screen.getByRole('button', { name: 'Play correct' }))
    expect(createdAudio).toHaveLength(countBeforeMutedPlay)

    view.unmount()
    render(<SoundProvider><SoundHarness /></SoundProvider>)
    expect(screen.getByText('Sound off')).toBeVisible()
  })
})
