import { act, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { ConfettiCelebration } from './ConfettiCelebration'

const originalMatchMedia = window.matchMedia

afterEach(() => {
  vi.useRealTimers()
  Object.defineProperty(window, 'matchMedia', { configurable: true, value: originalMatchMedia })
})

describe('ConfettiCelebration', () => {
  it('fills the screen with confetti and removes it after five seconds', () => {
    vi.useFakeTimers()
    const { container } = render(<ConfettiCelebration />)

    expect(screen.getByTestId('confetti-celebration')).toBeInTheDocument()
    expect(container.querySelectorAll('.confetti-celebration i')).toHaveLength(84)

    act(() => vi.advanceTimersByTime(5_000))

    expect(screen.queryByTestId('confetti-celebration')).not.toBeInTheDocument()
  })

  it('does not render when reduced motion is requested', () => {
    Object.defineProperty(window, 'matchMedia', {
      configurable: true,
      value: vi.fn().mockReturnValue({ matches: true }),
    })

    render(<ConfettiCelebration />)

    expect(screen.queryByTestId('confetti-celebration')).not.toBeInTheDocument()
  })
})
