#!/usr/bin/env node
// golden-path-probe.mjs — Manhattan Orchestrator · Phase 4.1 Golden-Path Slice Probe (Tier B)
//
// The Environment Integrity Gate (Phase 4.0 / env-integrity-gate.sh) proves the substrate is
// ALIVE. It cannot prove the user-facing VERTICAL SLICE (data store -> API -> rendered pixel)
// is CORRECT. This probe closes that gap: it drives a REAL browser through the golden path and
// asserts a user actually sees correct, live content — the check that would have caught the
// "crash-looping backend rendered as a valid-looking empty state, QA green" incident.
//
// It asserts, in a live-mode headless browser:
//   1. The target view renders >= MIN_ROWS real rows (ROW_SELECTOR), AND
//   2. The empty/null-state component is ABSENT (EMPTY_SELECTOR)   <-- the incident-killer pair
//   3. A KNOWN live value is visible on screen (EXPECT_TEXT)        <-- proves DB->API->UI truth
//   4. ZERO uncaught console errors / pageerrors                    <-- catches runtime/hydration bugs
//   5. NO failed network responses (status >= 400) on the view's real API calls (API_URL_RE)
//   6. The app is in LIVE mode, not mock/demo/fallback (provenance) <-- catches silent fallback
//
// Any failure exits non-zero to BLOCK the dependent empirical claim (hard gate, like Phase 4.0).
//
// Determinism: assert on a SPECIFIC known/seeded value (EXPECT_TEXT), never on length>0 alone —
// empty-vs-populated is the whole bug. Use bounded retries/timeouts to absorb cold-start windows;
// a timeout is a BLOCK, not a pass. Prefer a stable seeded "sentinel" record over live-volume data.
//
// Requires: `npm i -D playwright` (or @playwright/test). Configure via env below.
//
// Env:
//   URL          full URL of the view in LIVE mode (required)
//   ROW_SELECTOR CSS/testid for a real data row         (default [data-testid="event-log-row"])
//   EMPTY_SELECTOR CSS/testid for the empty/null state  (default [data-testid="event-logs-empty-state"])
//   EXPECT_TEXT  a known live/seeded value that must be visible (optional but strongly recommended)
//   API_URL_RE   regex matching the view's real API calls to watch for >=400 (default /api/)
//   MIN_ROWS     minimum real rows required             (default 1)
//   LIVE_ASSERT  JS expression eval'd in page that must be truthy for live mode (optional)
//   TIMEOUT_MS   per-assertion timeout                  (default 15000)
//
// Exit codes: 0 = PASS (user sees correct live content) · 1 = FAIL (slice broken) · 2 = setup error.

import process from 'node:process';

let chromium;
try {
  ({ chromium } = await import('playwright'));
} catch {
  console.error('[Phase 4.1] setup error: playwright not installed. Run: npm i -D playwright');
  process.exit(2);
}

const URL = process.env.URL;
if (!URL) { console.error('[Phase 4.1] setup error: URL env var is required'); process.exit(2); }
const ROW_SELECTOR = process.env.ROW_SELECTOR || '[data-testid="event-log-row"]';
const EMPTY_SELECTOR = process.env.EMPTY_SELECTOR || '[data-testid="event-logs-empty-state"]';
const EXPECT_TEXT = process.env.EXPECT_TEXT || '';
const API_URL_RE = new RegExp(process.env.API_URL_RE || '/api/');
const _minRowsRaw = parseInt(process.env.MIN_ROWS || '1', 10);
if (Number.isNaN(_minRowsRaw)) { console.error('[Phase 4.1] setup error: MIN_ROWS must be a number'); process.exit(2); }
const MIN_ROWS = _minRowsRaw;
const LIVE_ASSERT = process.env.LIVE_ASSERT || '';
const _timeoutRaw = parseInt(process.env.TIMEOUT_MS || '15000', 10);
if (Number.isNaN(_timeoutRaw)) { console.error('[Phase 4.1] setup error: TIMEOUT_MS must be a number'); process.exit(2); }
const TIMEOUT_MS = _timeoutRaw;

const failures = [];
const consoleErrors = [];
const badResponses = [];

const browser = await chromium.launch();
const page = await browser.newPage();
page.on('console', (m) => { if (m.type() === 'error') consoleErrors.push(m.text()); });
page.on('pageerror', (e) => consoleErrors.push(String(e)));
page.on('response', (r) => { if (API_URL_RE.test(r.url()) && r.status() >= 400) badResponses.push(`${r.status()} ${r.url()}`); });

try {
  await page.goto(URL, { waitUntil: 'domcontentloaded', timeout: TIMEOUT_MS });

  // 1 + 2: real rows present AND empty-state absent (the incident-killer pair)
  await page.waitForSelector(ROW_SELECTOR, { timeout: TIMEOUT_MS }).catch(() => {});
  const rowCount = await page.locator(ROW_SELECTOR).count();
  const emptyCount = await page.locator(EMPTY_SELECTOR).count();
  if (rowCount < MIN_ROWS) failures.push(`expected >= ${MIN_ROWS} rows (${ROW_SELECTOR}), saw ${rowCount}`);
  if (emptyCount > 0) failures.push(`empty/null-state present (${EMPTY_SELECTOR}) — dead data masked as valid empty state`);

  // 3: a known live value is visible (proves DB -> API -> UI truth)
  if (EXPECT_TEXT) {
    const visible = await page.getByText(EXPECT_TEXT, { exact: false }).first().isVisible().catch(() => false);
    if (!visible) failures.push(`known live value not visible on screen: "${EXPECT_TEXT}"`);
  }

  // 6: live-mode provenance (no silent mock/demo/fallback)
  if (LIVE_ASSERT) {
    const live = await page.evaluate((expr) => { try { return !!eval(expr); } catch { return false; } }, LIVE_ASSERT);
    if (!live) failures.push(`live-mode assertion failed: ${LIVE_ASSERT} (app may be serving mock/fallback data)`);
  }
} catch (e) {
  failures.push(`navigation/interaction error: ${String(e)}`);
} finally {
  await browser.close();
}

// 4 + 5: hygiene
if (consoleErrors.length) failures.push(`uncaught console/page errors: ${consoleErrors.length} (${consoleErrors[0]})`);
if (badResponses.length) failures.push(`failed API responses: ${badResponses.join(', ')}`);

if (failures.length) {
  console.error('[Phase 4.1: Golden-Path Slice Probe] FAILED — the user-facing vertical slice is broken:');
  for (const f of failures) console.error(`  - ${f}`);
  console.error('  Dependent empirical claim is UNVERIFIABLE. Block delivery or downgrade to Hypothesis.');
  process.exit(1);
}
console.log('[Phase 4.1: Golden-Path Slice Probe] PASSED — a real browser rendered correct live content end-to-end.');
process.exit(0);
