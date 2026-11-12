// ============================================================
//  dashboard_e2e.mjs — open the dashboard in a browser against a running bridge
//
//  The end-to-end check for test_windows_install.sh --browser: the published
//  dashboard (or --dashboard URL) in Edge or Chrome, with ?live=<bridge>, and
//    1. the page connects (its run bar shows RUNNING or PAUSED, not OFFLINE)
//    2. "until 300" sent to the bridge: the page shows PAUSED, stopped: until
//    3. the page's ▶ RUN button: the page POSTs /cmd and shows RUNNING
//    4. the page's ⏸ PAUSE button: the page shows PAUSED again
//  saving a screenshot after each step.
//
//  Usage:  PW_DIR=<folder with node_modules/playwright-core> \
//          node install/dashboard_e2e.mjs --bridge http://127.0.0.1:18952 \
//               [--dashboard URL] [--out DIR] [--channel msedge|chrome]
//               [--executable PATH]
// ============================================================
import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import { join, resolve } from 'node:path';

const arg = (name, dflt) => {
  const i = process.argv.indexOf('--' + name);
  return i > 0 && process.argv[i + 1] ? process.argv[i + 1] : dflt;
};
const BRIDGE = arg('bridge', 'http://127.0.0.1:18952');
const DASH = arg('dashboard', 'https://whalenlg.github.io/dme-dashboard/');
const OUT = resolve(arg('out', '.'));
const CHANNEL = arg('channel', process.platform === 'win32' ? 'msedge' : 'chrome');
const EXECUTABLE = arg('executable', '');   // a browser binary instead of --channel
mkdirSync(OUT, { recursive: true });

const require = createRequire(join(resolve(process.env.PW_DIR || '.'), 'x.js'));
const { chromium } = require('playwright-core');

let failed = false;
const t0 = Date.now();
const log = msg => console.log(`[${((Date.now() - t0) / 1000).toFixed(1).padStart(5)}s] ${msg}`);

const browser = await chromium.launch({
  ...(EXECUTABLE ? { executablePath: EXECUTABLE } : { channel: CHANNEL }),
  // An https page reaching http://127.0.0.1: Chromium's local-network
  // permission prompt has nobody to answer it in CI
  args: ['--disable-features=LocalNetworkAccessChecks,BlockInsecurePrivateNetworkRequests,PrivateNetworkAccessSendPreflights'],
});
const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });
page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') log(`page ${m.type()}: ${m.text()}`); });
page.on('pageerror', e => log(`page exception: ${e.message}`));
page.on('requestfailed', r => { if (r.url().startsWith(BRIDGE)) log(`request failed: ${r.method()} ${r.url()} ${r.failure()?.errorText}`); });
const bridgeReqs = [];
page.on('request', r => { if (r.url().startsWith(BRIDGE)) bridgeReqs.push(`${r.method()} ${new URL(r.url()).pathname}`); });

const runBar = async () => (await page.locator('body').innerText()).match(/●\s*(RUNNING|PAUSED|OFFLINE)[^\n]*/)?.[0] ?? '(no run bar)';
async function waitText(desc, re, ms) {
  try {
    await page.waitForFunction(src => new RegExp(src).test(document.body.innerText), re.source, { timeout: ms });
    log(`ok: ${desc}: ${await runBar()}`);
    return true;
  } catch {
    log(`FAIL: ${desc} (not seen in ${ms / 1000} s); run bar: ${await runBar()}`);
    failed = true;
    return false;
  }
}
const shot = async name => { await page.screenshot({ path: join(OUT, name), fullPage: false }); log(`screenshot ${join(OUT, name)}`); };
const bridgeCmd = async cmd => {
  const r = await fetch(`${BRIDGE}/cmd`, { method: 'POST', body: cmd });
  log(`bridge POST /cmd "${cmd}": ${r.status}`);
};

try {
  const url = `${DASH}${DASH.includes('?') ? '&' : '?'}live=${encodeURIComponent(BRIDGE)}`;
  log(`${EXECUTABLE || CHANNEL} ${browser.version()}: ${url}`);
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60_000 });

  // 1. Connected
  if (await waitText('page connected to the bridge', /●\s*(RUNNING|PAUSED)/, 90_000)) {
    await shot('dashboard-1-connected.png');

    // 2. A command from outside shows up on the page
    await bridgeCmd('until 300');
    if (await waitText('page shows the pause at 300 ms', /●\s*PAUSED[\s\S]*stopped:\s*until/, 240_000)) {
      await shot('dashboard-2-paused-until.png');

      // 3. The page's own controls drive the sim
      const run = page.getByRole('button', { name: /^\s*▶\s*RUN\s*$/ });
      const post = page.waitForRequest(r => r.url().startsWith(`${BRIDGE}/cmd`) && r.method() === 'POST', { timeout: 10_000 });
      await run.click({ timeout: 10_000 });
      log(`page sent: POST /cmd "${(await post).postData()}"`);
      if (await waitText('▶ RUN: page shows RUNNING', /●\s*RUNNING/, 60_000)) {
        await page.waitForTimeout(3000);
        await shot('dashboard-3-running.png');

        // 4. ...and stops it
        await page.getByRole('button', { name: /^\s*⏸\s*PAUSE\s*$/ }).click({ timeout: 10_000 });
        if (await waitText('⏸ PAUSE: page shows PAUSED', /●\s*PAUSED[\s\S]*stopped:\s*pause/, 60_000)) {
          await shot('dashboard-4-paused.png');
        }
      }
    }
  }
} catch (e) {
  log(`FAIL: ${e.message.split('\n')[0]}`);
  failed = true;
} finally {
  if (failed) await shot('dashboard-failed.png').catch(() => {});
  const counts = {};
  for (const r of bridgeReqs) counts[r] = (counts[r] || 0) + 1;
  log(`page's requests to the bridge: ${Object.entries(counts).map(([k, v]) => `${k} ×${v}`).join(', ') || 'none'}`);
  await browser.close();
}
log(failed ? 'dashboard end-to-end: FAILED' : 'dashboard end-to-end: passed');
process.exit(failed ? 1 : 0);
