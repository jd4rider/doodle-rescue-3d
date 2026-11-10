/*
 * Browser smoke test for the exported Web build.
 *
 *   python3 -m http.server 4291 --directory web/play
 *   node Tools/smoke.mjs http://127.0.0.1:4291/
 *
 * Boots in a portrait phone, checks the canvas and the arcade account layer,
 * starts level one, draws the actual solution with the mouse, presses Play and
 * waits for the real physics to award a win. Then checks the journey map and a
 * desktop window. Screenshots land in /tmp/doodle-shots.
 */
import { createRequire } from 'node:module'
import { mkdirSync } from 'node:fs'

const require = createRequire(import.meta.url)
const { chromium } = require('../../starfall-squadron/node_modules/playwright')

const url = process.argv[2] || 'http://127.0.0.1:4291/'
const failures = []
const errors = []
mkdirSync('/tmp/doodle-shots', { recursive: true })

async function stateOf(page) {
  try {
    return await page.evaluate(() => window.__doodleState || null)
  } catch (error) {
    return null
  }
}

async function waitForState(page, predicate, timeout = 30000) {
  const start = Date.now()
  let last = null
  while (Date.now() - start < timeout) {
    last = await stateOf(page)
    if (last && predicate(last)) return last
    await page.waitForTimeout(200)
  }
  return last
}

async function command(page, value) {
  await page.evaluate((text) => {
    window.__doodleCommand = text
  }, value)
}

const browser = await chromium.launch()
const context = await browser.newContext({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2,
  hasTouch: true,
  isMobile: true,
})
const page = await context.newPage()
page.on('pageerror', (error) => errors.push(`phone: ${error.message}`))
page.on('console', (message) => {
  if (message.type() === 'error') errors.push(`console: ${message.text()}`)
})

await page.goto(url, { waitUntil: 'domcontentloaded' })
await page.waitForSelector('#canvas', { timeout: 60000 })
await page.waitForTimeout(5000)

const layout = await page.evaluate(() => {
  const canvas = document.querySelector('#canvas')
  const rect = canvas ? canvas.getBoundingClientRect() : null
  return {
    canvas: rect ? { w: Math.round(rect.width), h: Math.round(rect.height), top: Math.round(rect.top), left: Math.round(rect.left) } : null,
    window: { w: innerWidth, h: innerHeight },
    bridge: window.DoodleRescue ? window.DoodleRescue.version : null,
    client: typeof window.LittleJoyArcade === 'object',
  }
})
console.log('layout', JSON.stringify(layout))
if (!layout.canvas) failures.push('phone: no canvas')
if (!layout.bridge) failures.push('phone: the DoodleRescue bridge is missing')
if (!layout.client) failures.push('phone: the Little Joy client is missing')
if (layout.canvas && (layout.canvas.h < layout.window.h * 0.99 || layout.canvas.w < layout.window.w * 0.99)) {
  failures.push(`phone: canvas ${layout.canvas.w}x${layout.canvas.h} does not fill ${layout.window.w}x${layout.window.h}`)
}

let state = await waitForState(page, (s) => s.screen === 'title', 30000)
console.log('title', JSON.stringify(state))
if (!state || state.screen !== 'title') failures.push('phone: the title screen did not boot')
if (state && state.levels !== 20) failures.push(`phone: expected 20 levels, got ${state && state.levels}`)
await page.screenshot({ path: '/tmp/doodle-shots/title.png' })

await command(page, 'start:campaign:1')
state = await waitForState(page, (s) => s.screen === 'game' && s.phase === 'draw', 30000)
console.log('game', JSON.stringify(state))
if (!state || state.screen !== 'game') failures.push('phone: could not start level one')
if (state && state.mode !== 'bee') failures.push(`phone: level one mode is ${state && state.mode}`)
await page.waitForTimeout(700)
await page.screenshot({ path: '/tmp/doodle-shots/draw.png' })

if (state && Array.isArray(state.solution_screen) && state.solution_screen.length >= 2) {
  const rect = await page.evaluate(() => {
    const r = document.querySelector('#canvas').getBoundingClientRect()
    return { left: r.left, top: r.top, width: r.width, height: r.height }
  })
  const points = state.solution_screen.map(([x, y]) => ({
    x: rect.left + (x / state.canvas.w) * rect.width,
    y: rect.top + (y / state.canvas.h) * rect.height,
  }))
  await page.mouse.move(points[0].x, points[0].y)
  await page.mouse.down()
  for (let i = 1; i < points.length; i += 1) {
    const from = points[i - 1]
    const to = points[i]
    for (let step = 1; step <= 8; step += 1) {
      await page.mouse.move(from.x + ((to.x - from.x) * step) / 8, from.y + ((to.y - from.y) * step) / 8)
      await page.waitForTimeout(16)
    }
  }
  await page.mouse.up()
  state = await waitForState(page, (s) => s.used > 2, 6000)
  console.log('after real drag', JSON.stringify({ used: state && state.used, phase: state && state.phase }))
  if (!state || !(state.used > 2)) failures.push('phone: a real pointer drag did not build a beam')
  await page.screenshot({ path: '/tmp/doodle-shots/stroke.png' })
}

await command(page, 'play')
state = await waitForState(page, (s) => s.phase === 'sim' || s.phase === 'won' || s.phase === 'lost', 8000)
if (!state || state.phase === 'draw') failures.push('phone: Play did not start the simulation')
state = await waitForState(page, (s) => s.phase === 'won' || s.phase === 'lost', 45000)
console.log('result', JSON.stringify({ phase: state && state.phase, used: state && state.used, stars: state && state.stars, fps: state && state.fps }))
if (!state || state.phase !== 'won') failures.push(`phone: drawing the stored solution did not win (${state && state.phase})`)
if (state && state.phase === 'won' && !state.result) failures.push('phone: the win card did not open')
await page.waitForTimeout(900)
await page.screenshot({ path: '/tmp/doodle-shots/win.png' })

await command(page, 'screen:worlds')
state = await waitForState(page, (s) => s.screen === 'worlds', 8000)
if (!state || state.screen !== 'worlds') failures.push('phone: the journey map did not open')
await page.waitForTimeout(400)
await page.screenshot({ path: '/tmp/doodle-shots/worlds.png' })

const wide = await browser.newContext({ viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 })
const widePage = await wide.newPage()
widePage.on('pageerror', (error) => errors.push(`desktop: ${error.message}`))
await widePage.goto(url, { waitUntil: 'domcontentloaded' })
await widePage.waitForSelector('#canvas', { timeout: 60000 })
await widePage.waitForTimeout(4500)
const wideLayout = await widePage.evaluate(() => {
  const rect = document.querySelector('#canvas').getBoundingClientRect()
  return { w: Math.round(rect.width), h: Math.round(rect.height), window: { w: innerWidth, h: innerHeight } }
})
console.log('desktop layout', JSON.stringify(wideLayout))
if (wideLayout.w < wideLayout.window.w * 0.99 || wideLayout.h < wideLayout.window.h * 0.99) {
  failures.push(`desktop: canvas ${wideLayout.w}x${wideLayout.h} must fill the window`)
}
await widePage.screenshot({ path: '/tmp/doodle-shots/desktop.png' })

await browser.close()
console.log('errors', JSON.stringify(errors.slice(0, 12)))
if (errors.length) failures.push(`${errors.length} console/page error(s)`)
if (failures.length) {
  console.error('SMOKE FAILED')
  for (const failure of failures) console.error(' - ' + failure)
  process.exit(1)
}
console.log('SMOKE OK')
