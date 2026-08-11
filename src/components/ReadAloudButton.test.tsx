import { act, cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ReadAloudButton } from './ReadAloudButton'

class MockUtterance {
  text: string
  lang = ''
  rate = 1
  pitch = 1
  voice: SpeechSynthesisVoice | null = null
  onend: (() => void) | null = null
  onerror: (() => void) | null = null

  constructor(text: string) {
    this.text = text
  }
}

const britishVoice = { name: 'British English', lang: 'en-GB' } as SpeechSynthesisVoice
const speechSynthesis = {
  cancel: vi.fn(),
  speak: vi.fn(),
  getVoices: vi.fn(() => [britishVoice]),
}

describe('ReadAloudButton', () => {
  beforeEach(() => {
    vi.stubGlobal('SpeechSynthesisUtterance', MockUtterance)
    Object.defineProperty(window, 'speechSynthesis', { configurable: true, value: speechSynthesis })
    speechSynthesis.cancel.mockClear()
    speechSynthesis.speak.mockClear()
    speechSynthesis.getVoices.mockClear()
  })

  afterEach(() => {
    cleanup()
    vi.unstubAllGlobals()
    Reflect.deleteProperty(window, 'speechSynthesis')
  })

  it('shows the recognisable pronunciation but speaks the clean term in British English', () => {
    render(<ReadAloudButton term="Coincide" pronunciation="co-in-SIDE" />)

    const button = screen.getByRole('button', { name: 'Read Coincide aloud' })
    expect(button).toHaveTextContent('co-in-SIDE')
    fireEvent.click(button)

    expect(speechSynthesis.cancel).toHaveBeenCalledOnce()
    expect(speechSynthesis.speak).toHaveBeenCalledOnce()
    const utterance = speechSynthesis.speak.mock.calls[0][0] as MockUtterance
    expect(utterance.text).toBe('Coincide')
    expect(utterance.lang).toBe('en-GB')
    expect(utterance.voice).toBe(britishVoice)
    expect(utterance.rate).toBe(0.88)
    expect(button).toHaveAttribute('aria-pressed', 'true')
  })

  it('stops a second click and deactivates the previous pill when another term starts', () => {
    render(
      <>
        <ReadAloudButton term="Coincide" pronunciation="co-in-SIDE" />
        <ReadAloudButton term="Commemorate" pronunciation="com-MEM-o-rate" />
      </>,
    )

    const first = screen.getByRole('button', { name: 'Read Coincide aloud' })
    const second = screen.getByRole('button', { name: 'Read Commemorate aloud' })
    fireEvent.click(first)
    fireEvent.click(second)
    expect(first).toHaveAttribute('aria-pressed', 'false')
    expect(second).toHaveAttribute('aria-pressed', 'true')

    fireEvent.click(second)
    expect(second).toHaveAttribute('aria-pressed', 'false')
    expect(speechSynthesis.cancel).toHaveBeenCalledTimes(3)
  })

  it('clears its active state when speech finishes', () => {
    render(<ReadAloudButton term="Discrete" pronunciation="dis-CREET" />)
    const button = screen.getByRole('button', { name: 'Read Discrete aloud' })
    fireEvent.click(button)

    const utterance = speechSynthesis.speak.mock.calls[0][0] as MockUtterance
    act(() => utterance.onend?.())
    expect(button).toHaveAttribute('aria-pressed', 'false')
  })

  it('keeps a visible disabled control when speech synthesis is unavailable', () => {
    Reflect.deleteProperty(window, 'speechSynthesis')
    vi.stubGlobal('SpeechSynthesisUtterance', undefined)

    render(<ReadAloudButton term="Queue" pronunciation="ca-you" />)
    const button = screen.getByRole('button', { name: 'Read Queue aloud' })
    expect(button).toBeDisabled()
    expect(button).toHaveTextContent('ca-you')
    expect(button).toHaveAttribute('data-tooltip', 'Read aloud unavailable')
  })
})
