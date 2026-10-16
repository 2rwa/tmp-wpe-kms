import assert from 'node:assert/strict';
import { chromium } from 'playwright';
const browser = await chromium.launch({headless: true});
try {
  const page = await browser.newPage();
  await page.goto('http://127.0.0.1:8765/', {waitUntil:'networkidle'});
  const title = await page.title();
  assert.match(title, /WPE WebKit/);
  assert.match(await page.locator('#command').textContent(), /WPE_PLATFORM=drm/);
  assert.equal(await page.locator('#mode-button').getAttribute('aria-pressed'),'false');
  await page.locator('#mode-button').click();
  assert.match(await page.locator('#mode-label').textContent(), /2GB/);
  assert.equal(await page.locator('#mode-button').getAttribute('aria-pressed'),'true');
  assert.equal(await page.locator('html').getAttribute('data-memory-mode'), 'low');
  await page.locator('#platform-selector').selectOption('headless');
  assert.match(await page.locator('#command').textContent(), /WPE_PLATFORM=headless/);
  await page.locator('#mode-button').click();
  assert.equal(await page.locator('html').getAttribute('data-memory-mode'),'normal');
  console.log('PASS: real browser controls → state → redraw; command selection');
} finally {
  await browser.close();
}
