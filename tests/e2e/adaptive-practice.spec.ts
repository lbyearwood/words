import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { expect, test } from '@playwright/test'

const credentialsPath = join(process.cwd(), '.local-test-credentials.json')

test('goal setup drives a complete recommended practice with feedback', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'The core adaptive journey only needs one browser run.')
  if (!existsSync(credentialsPath)) throw new Error('Local test credentials are missing.')
  const credentials = JSON.parse(readFileSync(credentialsPath, 'utf8')) as {
    users: Array<{ displayName: string; email: string; password: string }>
  }
  const user = credentials.users.find((candidate) => candidate.displayName === 'Tia')!
  const consoleErrors: string[] = []
  page.on('console', (message) => { if (message.type() === 'error') consoleErrors.push(message.text()) })
  page.on('pageerror', (error) => consoleErrors.push(error.message))

  await page.goto('/#/')
  await page.getByLabel('Email', { exact: true }).fill(user.email)
  await page.getByLabel('Password', { exact: true }).fill(user.password)
  await page.getByRole('button', { name: 'Sign in', exact: true }).click()
  await expect(page.getByRole('heading', { name: 'Hello, Tia' })).toBeVisible()

  await page.goto('/#/profile')
  await page.getByLabel('Primary target').selectOption('education_learning')
  await page.getByLabel('Sophisticated Speaker', { exact: true }).check()
  await page.getByRole('button', { name: 'Save changes', exact: true }).click()
  await expect(page.getByText('Profile and vocabulary goals saved.')).toBeVisible()

  await page.goto('/#/practice')
  await expect(page.getByRole('heading', { name: 'Your session' })).toBeVisible()
  await expect(page.getByText('Multiple choice · True or false')).toBeVisible()
  await page.getByRole('button', { name: 'Custom', exact: true }).click()
  await page.getByLabel('Custom amount').fill('10')
  await page.getByRole('button', { name: 'Start 10-question practice' }).click()

  for (let index = 0; index < 10; index += 1) {
    await expect(page.getByText(`Question ${index + 1} of 10`)).toBeVisible()
    await page.locator('.answer-options button').first().click()
    await page.getByRole('button', { name: 'Check answer' }).click()
    await expect(page.locator('.answer-feedback')).toBeVisible()
    const continueButton = index === 9
      ? page.getByRole('button', { name: 'See results' })
      : page.getByRole('button', { name: 'Next', exact: true })
    await continueButton.click()
  }

  await expect(page).toHaveURL(/#\/results\//)
  await expect(page.getByText('Your answers have updated what the app will show you next.')).toBeVisible()
  await page.goto('/#/')
  await expect(page.getByRole('heading', { name: 'Your vocabulary targets' })).toBeVisible()
  await expect(page.getByText('Education & Learning', { exact: true }).first()).toBeVisible()
  expect(consoleErrors).toEqual([])
})
