import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { expect, test, type Page } from '@playwright/test'

type LocalUser = {
  displayName: 'Max' | 'Tia'
  email: string
  password: string
}

type LocalCredentials = {
  users: LocalUser[]
}

const credentialsPath = join(process.cwd(), '.local-test-credentials.json')

function loadLocalUsers() {
  if (!existsSync(credentialsPath)) {
    throw new Error(
      'Local test credentials are missing. Run `npm run supabase:start` and `node scripts/provision-local-users.mjs` first.',
    )
  }

  const credentials = JSON.parse(readFileSync(credentialsPath, 'utf8')) as LocalCredentials
  return credentials.users
}

async function expectFullWidthPage(page: Page) {
  const widths = await page.evaluate(() => {
    const pageElement = document.querySelector<HTMLElement>('.page')
    const mainElement = document.querySelector<HTMLElement>('.main-content')
    return {
      pageWidth: pageElement?.getBoundingClientRect().width ?? 0,
      mainWidth: mainElement?.getBoundingClientRect().width ?? 0,
    }
  })
  expect(widths.pageWidth).toBeGreaterThan(0)
  expect(Math.abs(widths.mainWidth - widths.pageWidth)).toBeLessThanOrEqual(1)
}

for (const user of loadLocalUsers()) {
  test(`${user.displayName} can sign in on a responsive layout`, async ({ page }, testInfo) => {
    const consoleErrors: string[] = []
    page.on('console', (message) => {
      if (message.type() === 'error') consoleErrors.push(message.text())
    })
    page.on('pageerror', (error) => consoleErrors.push(error.message))

    await page.goto('/#/')
    await page.getByLabel('Email', { exact: true }).fill(user.email)
    await page.getByLabel('Password', { exact: true }).fill(user.password)
    await page.getByRole('button', { name: 'Sign in', exact: true }).click()

    await expect(page).toHaveURL(/#\/$/)
    await expect(page.getByRole('heading', { name: `Hello, ${user.displayName}` })).toBeVisible()

    const layout = await page.evaluate(() => ({
      clientWidth: document.documentElement.clientWidth,
      scrollWidth: document.documentElement.scrollWidth,
    }))
    expect(layout.scrollWidth).toBeLessThanOrEqual(layout.clientWidth)
    await expectFullWidthPage(page)

    const bottomNavigation = page.locator('.bottom-nav')
    const desktopSidebar = page.locator('.desktop-sidebar')
    if (testInfo.project.name === 'desktop') {
      await expect(desktopSidebar).toBeVisible()
      await expect(bottomNavigation).toBeHidden()
      await expect(desktopSidebar.getByRole('link', { name: 'Practice', exact: true })).toBeVisible()
      await expect(desktopSidebar.getByRole('link', { name: 'My Progress', exact: true })).toBeVisible()
      await expect(desktopSidebar.getByRole('button', { name: 'Settings', exact: true })).toBeVisible()
      await expect(desktopSidebar.getByRole('button', { name: 'Sign out', exact: true })).toBeVisible()
    } else {
      await expect(bottomNavigation).toBeVisible()
      await expect(desktopSidebar).toBeHidden()
      await expect(bottomNavigation.getByRole('link', { name: 'Practice', exact: true })).toBeVisible()
      await expect(bottomNavigation.getByRole('link', { name: 'My Progress', exact: true })).toBeVisible()
      await expect(page.locator('.mobile-header').getByRole('button', { name: 'Settings', exact: true })).toBeVisible()
      await expect(page.locator('.mobile-header').getByRole('button', { name: 'Sign out', exact: true })).toBeVisible()
      await expect(bottomNavigation).toHaveCSS('background-color', 'rgb(0, 75, 44)')
      await expect(page.locator('.mobile-header')).toHaveCSS('background-color', 'rgb(0, 75, 44)')
    }

    await page.goto('/#/progress')
    await expect(page.getByRole('heading', { name: 'My Progress', exact: true })).toBeVisible()
    const resultsTab = page.getByRole('tab', { name: 'My Results', exact: true })
    const progressTab = page.getByRole('tab', { name: 'My Progress', exact: true })
    await expect(resultsTab).toHaveAttribute('aria-selected', 'true')
    if (user.displayName === 'Max') {
      await expect(page.locator('.result-history-row')).toHaveCount(1)
      await expect(page.locator('.result-grade strong')).toHaveAccessibleName(/^Grade [A-E]$/)
      await expect(page.locator('.result-points')).toContainText('+84')
    } else {
      await expect(page.locator('.result-history-row')).toHaveCount(0)
      await expect(page.getByRole('heading', { name: 'No completed tests yet', exact: true })).toBeVisible()
    }
    await progressTab.click()
    await expect(progressTab).toHaveAttribute('aria-selected', 'true')
    await expect(page.getByRole('heading', { name: 'Your target journey', exact: true })).toBeVisible()
    await expect(page.getByRole('heading', { name: 'Choose your vocabulary targets', exact: true })).toBeVisible()
    await resultsTab.click()
    await expect(resultsTab).toHaveAttribute('aria-selected', 'true')
    await expectFullWidthPage(page)

    await page.goto('/#/library')
    await expect(page.getByRole('heading', { name: 'Library', exact: true })).toBeVisible()
    const categoryFilter = page.getByRole('combobox', { name: 'Category', exact: true })
    await expect(categoryFilter.locator('option')).toHaveCount(29)
    await expect(page.getByRole('searchbox', { name: 'Search terms' })).toBeVisible()
    await expect(page.getByRole('combobox', { name: 'Difficulty', exact: true })).toBeVisible()
    await expect(page.getByRole('button', { name: 'Add to My Collection: A blessing in disguise', exact: true })).toBeVisible()
    await expect(page.getByRole('button', { name: 'Dislike A blessing in disguise', exact: true })).toBeVisible()
    await expect(page.getByRole('button', { name: /^Hide / })).toHaveCount(0)
    const librarySort = page.getByRole('combobox', { name: 'Sort', exact: true })
    await expect(librarySort).toBeVisible()
    await page.getByRole('button', { name: 'Sophisticated Speaker', exact: true }).click()
    await expect(categoryFilter).toHaveValue('sophisticated_speaker')
    await expect(page.locator('.list-summary')).toHaveText(/^\d+ terms$/)
    await expect(page.getByRole('heading', { name: 'Articulate', exact: true })).toBeVisible()
    await expect(page.getByLabel('Categories for Articulate')).toContainText('Sophisticated Speaker')
    await expect(page.getByLabel('Categories for Articulate')).toContainText('Professional Communication')
    await expect(page.getByLabel('Categories for Articulate')).toContainText('Leadership & Management')
    await librarySort.selectOption('reverse-alphabetical')
    const reverseSortedTerms = await page.locator('.word-row h2').allTextContents()
    expect(reverseSortedTerms).toEqual([...reverseSortedTerms].sort((a, b) => b.localeCompare(a, 'en-GB', { sensitivity: 'base' })))
    const librarySearch = page.getByRole('searchbox', { name: 'Search terms' })
    await librarySearch.fill('Articulate')
    await expect(page.locator('.list-summary')).toHaveText('1 term')
    await expect(page.getByRole('heading', { name: 'Articulate', exact: true })).toBeVisible()
    await librarySearch.fill('')

    const libraryLayout = await page.evaluate(() => ({
      clientWidth: document.documentElement.clientWidth,
      scrollWidth: document.documentElement.scrollWidth,
    }))
    expect(libraryLayout.scrollWidth).toBeLessThanOrEqual(libraryLayout.clientWidth)
    await expectFullWidthPage(page)

    await page.goto('/#/collection')
    await expect(page.getByRole('heading', { name: 'My Collection', exact: true })).toBeVisible()
    await expect(page.getByRole('region', { name: 'Collection summary' })).toBeVisible()
    await expect(page.getByRole('region', { name: 'Collection summary' }).getByText('Disliked terms', { exact: true })).toBeVisible()
    await expect(page.getByRole('searchbox', { name: 'Search your collection' })).toBeVisible()
    await expect(page.getByRole('combobox', { name: 'Sort collection' })).toBeVisible()
    const practiseCollection = page.getByRole('button', { name: /Practise .*collection.* terms/ })
    await expect(page.getByRole('button', { name: /Liked: / })).toBeVisible()
    await expect(page.getByRole('button', { name: /Disliked: / })).toBeVisible()
    await expect(practiseCollection).toBeEnabled()
    if (user.displayName === 'Max') {
      const collectionSearch = page.getByRole('searchbox', { name: 'Search your collection' })
      const firstCollectionTerm = await page.locator('.collection-row h2').first().innerText()
      await collectionSearch.fill(firstCollectionTerm)
      await expect(page.getByRole('heading', { name: firstCollectionTerm, exact: true })).toBeVisible()
      await collectionSearch.fill('')
    }
    const collectionLayout = await page.evaluate(() => ({
      clientWidth: document.documentElement.clientWidth,
      scrollWidth: document.documentElement.scrollWidth,
    }))
    expect(collectionLayout.scrollWidth).toBeLessThanOrEqual(collectionLayout.clientWidth)
    await expectFullWidthPage(page)

    await page.goto('/#/profile')
    await expect(page.getByText('Vocabulary goals', { exact: true })).toBeVisible()
    await expect(page.getByRole('heading', { name: 'Personal details', exact: true })).toBeVisible()
    await expect(page.getByRole('searchbox', { name: 'Search goals', exact: true })).toBeVisible()
    await expect(page.locator('.profile-page').getByRole('button', { name: 'Sign out', exact: true })).toHaveCount(0)
    await expect(page.getByRole('button', { name: 'Save changes', exact: true })).toBeVisible()
    const viewAllGoals = page.getByRole('button', { name: /View all \d+ categories/ })
    await viewAllGoals.click()
    await expect(page.getByRole('button', { name: 'Show suggested goals', exact: true })).toBeVisible()
    await page.getByRole('button', { name: 'Show suggested goals', exact: true }).click()
    const profileLayout = await page.evaluate(() => ({
      clientWidth: document.documentElement.clientWidth,
      scrollWidth: document.documentElement.scrollWidth,
    }))
    expect(profileLayout.scrollWidth).toBeLessThanOrEqual(profileLayout.clientWidth)
    await expectFullWidthPage(page)

    await page.goto('/#/practice')
    await expect(page.getByRole('heading', { name: 'Practice', exact: true })).toBeVisible()
    const startPracticeTab = page.getByRole('tab', { name: 'Start New Practice', exact: true })
    const continuePracticeTab = page.getByRole('tab', { name: /Continue Practice/ })
    await expect(startPracticeTab).toHaveAttribute('aria-selected', 'true')
    await expect(continuePracticeTab).toBeVisible()
    await expect(page.getByRole('radio', {
      name: 'Recommended for you Balances your goals, weaker terms and terms due for review.',
      exact: true,
    })).toBeChecked()
    await expect(page.getByRole('heading', { name: 'Your session' })).toBeVisible()
    await expect(page.getByText('Multiple choice · True or false')).toBeVisible()
    await continuePracticeTab.click()
    await expect(page.getByRole('heading', { name: 'Continue your practice', exact: true })).toBeVisible()
    await startPracticeTab.click()
    await expect(page.getByRole('heading', { name: 'Your session' })).toBeVisible()
    const practiceLayout = await page.evaluate(() => ({
      clientWidth: document.documentElement.clientWidth,
      scrollWidth: document.documentElement.scrollWidth,
    }))
    expect(practiceLayout.scrollWidth).toBeLessThanOrEqual(practiceLayout.clientWidth)
    await expectFullWidthPage(page)

    expect(consoleErrors).toEqual([])
  })
}
