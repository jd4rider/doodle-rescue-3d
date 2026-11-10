/*
 * Frame-rate probe for the exported Web build.
 *
 *   python3 -m http.server 4291 --directory web/play
 *   node Tools/perf.mjs http://127.0.0.1:4291/          # Chrome headless
 *   node Tools/perf.mjs http://127.0.0.1:4291/ --headed # real window, real GPU
 *
 * Samples the game's own Engine.get_frames_per_second() at the title, a Bee
 * Defence level and a Bridge level, in a phone viewport and a desktop window.
 * Reports the median of five one-second samples so a single stalled frame does
 * not decide the number.
 */
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const { chromium } = require('../../starfall-squadron/node_modules/playwright')

const url = process.argv[2] || 'http://127.0.0.1:4291/'
const headed = process.argv.includes('--headed')
const browser = await chromium.launch({ channel: 'chrome', headless: !headed })

async function state(page) {
  return page.evaluate(() => window.__doodleState || null)
}

async function waitFor(page, predicate, timeout = 60000) {
  const start = Date.now()
  while (Date.now() - start < timeout) {
    const value = await state(page)
    if (value && predicate(value)) return value
    await page.waitForTimeout(200)
  }
  return null
}

async function command(page, value) {
  await page.evaluate((text) => {
    window.__doodleCommand = text
  }, value)
}

async function sample(page, label) {
  const values = []
  for (let i = 0; i < 5; i += 1) {
    await page.waitForTimeout(700)
    const value = await state(page)
    if (value) values.push(value.fps || 0)
  }
  values.sort((a, b) => a - b)
  const median = values[Math.floor(values.length / 2)] || 0
  console.log(`${label}: ${median} fps (samples ${values.join(', ')})`)
  return median
}

const results = {}

const phone = await browser.newContext({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2,
  hasTouch: true,
  isMobile: true,
})
const phonePage = await phone.newPage()
await phonePage.goto(url, { waitUntil: 'domcontentloaded' })
await phonePage.waitForSelector('#canvas', { timeout: 60000 })
await waitFor(phonePage, (s) => s.screen === 'title')
await phonePage.waitForTimeout(2500)
results['phone title'] = await sample(phonePage, 'phone title')

await command(phonePage, 'start:campaign:1')
await waitFor(phonePage, (s) => s.screen === 'game')
await phonePage.waitForTimeout(1200)
results['phone bee draw'] = await sample(phonePage, 'phone bee draw')

await command(phonePage, 'start:campaign:6')
await waitFor(phonePage, (s) => s.screen === 'game' && s.level === 6)
await phonePage.waitForTimeout(1200)
results['phone bridge draw'] = await sample(phonePage, 'phone bridge draw')

const desktop = await browser.newContext({ viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 })
const desktopPage = await desktop.newPage()
await desktopPage.goto(url, { waitUntil: 'domcontentloaded' })
await desktopPage.waitForSelector('#canvas', { timeout: 60000 })
await waitFor(desktopPage, (s) => s.screen === 'title')
await desktopPage.waitForTimeout(2500)
results['desktop title'] = await sample(desktopPage, 'desktop title')

await command(desktopPage, 'start:campaign:1')
await waitFor(desktopPage, (s) => s.screen === 'game')
await desktopPage.waitForTimeout(1200)
results['desktop bee draw'] = await sample(desktopPage, 'desktop bee draw')

await browser.close()
console.log('PERF ' + (headed ? 'HEADED' : 'HEADLESS') + ' ' + JSON.stringify(results))
