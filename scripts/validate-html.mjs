#!/usr/bin/env node
// Optional maintainer check: exercise actual generated reports in installed Chrome.
// Runtime kdash does not depend on Node or Playwright.
import fs from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import crypto from 'node:crypto';

const option = (name) => process.argv[process.argv.indexOf(name) + 1];
for (const name of ['--run', '--module', '--browser']) {
  if (!process.argv.includes(name)) throw new Error(`Required: ${name}`);
}
const run = path.resolve(option('--run'));
const root = path.dirname(path.dirname(run));
const evidence = JSON.parse(await fs.readFile(path.join(run, 'results.json'), 'utf8'));
const releaseVersion = evidence.version.replace(/^kdash /, '');
const [major, minor, patch] = releaseVersion.split('.').map(Number);
const hasFmea = major > 4 || (major === 4 && (minor > 28 || (minor === 28 && patch >= 1)));
const captures = (await fs.readFile(path.join(run, 'captures.tsv'), 'utf8')).trim().split(/\r?\n/);
const pngColumn = captures[0].split('\t').indexOf('png');
if (pngColumn < 0 || captures.length < 2) throw new Error('Capture manifest has no PNG paths');
const terminalGalleries = new Set(captures.slice(1).map(row => path.dirname(row.split('\t')[pngColumn])));
if (terminalGalleries.size !== 1) throw new Error('Capture manifest has multiple terminal galleries');
const terminalGallery = path.basename([...terminalGalleries][0]);
const galleryName = terminalGallery.startsWith('cli_')
  ? `html${terminalGallery.slice(4)}` : `html${evidence.version.replace(/^kdash /, '').replaceAll('.', '')}`;
const gallery = process.argv.includes('--gallery')
  ? path.resolve(root, option('--gallery')) : path.join(root, 'samples', galleryName);
if (path.dirname(gallery) !== path.join(root, 'samples')) throw new Error('--gallery must name a direct child of samples/');
const output = path.join(gallery, 'screenshots');
await fs.mkdir(output, { recursive: true });
const { chromium } = await import(pathToFileURL(path.resolve(option('--module'))).href);
const reports = (await fs.readdir(path.join(run, 'reports')))
  .filter(name => /^kdash_namespace_report.*\.html$/.test(name)).sort();
if (!reports.length) throw new Error('No generated namespace report');
// Prefer the report retaining the longest live history over a later short run.
const candidates = await Promise.all(reports.map(async name => ({ name,
  size: (await fs.stat(path.join(run, 'reports', name))).size })));
const source = path.join(run, 'reports', candidates.sort((a, b) => b.size - a.size)[0].name);
const checks = [];
const screenshots = [];
const errors = [];
const additionalReports = [];
const check = (name, passed, detail = '') => {
  checks.push({ name, status: passed ? 'PASS' : 'FAIL', detail });
  console.log(`${passed ? 'PASS' : 'FAIL'} ${name} ${detail}`);
  if (!passed) throw new Error(name);
};
const browser = await chromium.launch({ executablePath: option('--browser'), headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 1500, height: 1100 }, acceptDownloads: true });
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(pathToFileURL(source).href, { waitUntil: 'load' });
  check('html-real-workloads', (await page.locator('body').textContent()).includes('app-server'), 'actual fixture workload present');
  for (const tab of ['overview', 'pods', 'nodes', 'workloads', 'ip', 'mem', 'io', 'history']) {
    await page.locator(`.tab[data-tab="${tab}"]`).click();
    check(`html-tab-${tab}`, await page.locator(`.view[data-view="${tab}"]`).isVisible());
    const png = path.join(output, `${tab}.png`);
    await page.screenshot({ path: png, animations: 'disabled' });
    screenshots.push({ file: path.relative(root, png).replaceAll('\\', '/'),
      sha256: crypto.createHash('sha256').update(await fs.readFile(png)).digest('hex'), tab });
  }
  await page.locator('.tab[data-tab="pods"]').click();
  await page.locator('#gq').fill('z-crash');
  const filtered = page.locator('#podtable tbody[data-s]:not(.r-hidden)');
  check('html-search', await filtered.count() > 0 && (await filtered.allTextContents()).every(text => text.includes('z-crash')));
  await page.locator('#gq').fill('');
  const before = await page.locator('html').getAttribute('data-theme');
  await page.getByRole('button', { name: 'theme', exact: true }).click();
  check('html-theme', (await page.locator('html').getAttribute('data-theme')) !== before);
  await page.getByRole('button', { name: 'theme', exact: true }).click();
  await page.locator('#kdtz').selectOption('utc');
  check('html-timezone', await page.locator('#kdtz').inputValue() === 'utc' &&
    (await page.locator('.tzn').allTextContents()).some(text => text.includes('UTC')));
  await page.locator('.tab[data-tab="overview"]').click();
  await page.locator('#actiontable thead th').nth(2).click();
  const sorted = await page.locator('#actiontable tbody tr').evaluateAll(rows => rows.map(row => row.cells[2].textContent.trim()));
  const ascending = [...sorted].sort((a, b) => a.localeCompare(b));
  check('html-sort', sorted.length > 1 && (JSON.stringify(sorted) === JSON.stringify(ascending) ||
    JSON.stringify(sorted) === JSON.stringify(ascending.reverse())));
  const csvEvent = page.waitForEvent('download');
  await page.locator('#action button').filter({ hasText: 'CSV' }).click();
  const csv = await csvEvent;
  await csv.saveAs(path.join(run, 'logs', 'browser-action.csv'));
  const csvText = await fs.readFile(path.join(run, 'logs', 'browser-action.csv'), 'utf8');
  check('html-csv-download', csvText.includes('z-crash') && csvText.includes('Severity'));
  const jsonEvent = page.waitForEvent('download');
  await page.getByRole('button', { name: 'JSON', exact: true }).click();
  const json = await jsonEvent;
  await json.saveAs(path.join(run, 'logs', 'browser-report.json'));
  const jsonText = await fs.readFile(path.join(run, 'logs', 'browser-report.json'), 'utf8');
  const downloaded = JSON.parse(jsonText);
  check('html-json-download', downloaded.generator === 'kdash' && jsonText.includes('app-server'));
  await page.locator('.tab[data-tab="history"]').click();
  check('html-history-charts', await page.locator('.view[data-view="history"] svg').count() > 0);
  check('html-no-script-errors', errors.length === 0, errors.join('; '));
  if (hasFmea) {
    const fmeaDir = path.join(run, 'reports', 'fmea');
    const worksheets = (await fs.readdir(fmeaDir)).filter(name => name.endsWith('.html')).sort();
    if (!worksheets.length) throw new Error('No generated FMEA HTML worksheet');
    const worksheet = path.join(fmeaDir, worksheets.at(-1));
    const fmeaPage = await browser.newPage({ viewport: { width: 1500, height: 1100 } });
    fmeaPage.on('pageerror', error => errors.push(error.message));
    await fmeaPage.goto(pathToFileURL(worksheet).href, { waitUntil: 'load' });
    const text = await fmeaPage.locator('body').textContent();
    check('html-fmea-real-rows', (await fmeaPage.locator('table tr').count()) >= 40 && text.includes('z-pending') && text.includes(releaseVersion));
    check('html-fmea-no-script-errors', errors.length === 0, errors.join('; '));
    const png = path.join(output, 'fmea.png');
    await fmeaPage.screenshot({ path: png, animations: 'disabled' });
    screenshots.push({ file: path.relative(root, png).replaceAll('\\', '/'),
      sha256: crypto.createHash('sha256').update(await fs.readFile(png)).digest('hex'), tab: 'fmea' });
    additionalReports.push({ report: path.relative(run, worksheet).replaceAll('\\', '/'),
      sha256: crypto.createHash('sha256').update(await fs.readFile(worksheet)).digest('hex') });
    await fmeaPage.close();
  }
} catch (error) {
  if (!checks.some(c => c.status === 'FAIL')) checks.push({ name: 'browser-exception', status: 'FAIL', detail: error.message });
  process.exitCode = 1;
} finally {
  await browser.close();
  await fs.writeFile(path.join(run, 'browser-results.json'), JSON.stringify({
    version: evidence.version, source_sha256: evidence.sha256,
    report: path.relative(run, source).replaceAll('\\', '/'),
    report_sha256: crypto.createHash('sha256').update(await fs.readFile(source)).digest('hex'),
    status: checks.some(c => c.status === 'FAIL') ? 'FAIL' : 'PASS', checks, screenshots, errors,
    additional_reports: additionalReports,
  }, null, 2) + '\n');
}
