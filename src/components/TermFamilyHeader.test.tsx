import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import type { KnowledgeItem } from '../lib/types'
import { TermFamilyHeader } from './TermFamilyHeader'

const item = (pronunciation: string) => ({ pronunciation } as KnowledgeItem)

describe('TermFamilyHeader', () => {
  it('shows pronunciation and a singular meaning count', () => {
    render(<TermFamilyHeader term="Confer" items={[item('con-FER')]} />)

    expect(screen.getByRole('heading', { name: /Confer/ })).toHaveTextContent('(con-FER)')
    expect(screen.getByText('1 meaning')).toBeVisible()
  })

  it('shows a plural count for multiple meanings', () => {
    render(<TermFamilyHeader term="Coincide" items={[item('co-in-SIDE'), item('co-in-SIDE')]} />)

    expect(screen.getByText('2 meanings')).toBeVisible()
  })
})
