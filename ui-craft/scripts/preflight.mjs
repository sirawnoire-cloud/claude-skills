#!/usr/bin/env node
// ui-craft preflight — see preflight.sh. Reports objective responsive/liveliness problems; your eyes judge the rest.
import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import os from 'node:os';

const require = createRequire(import.meta.url);
const cache = process.env.UI_CRAFT_CACHE || join(os.homedir(), '.cache', 'ui-craft');
let pw;
try { pw = require(require.resolve('playwright-core', { paths: [cache, process.cwd()] })); }
catch { console.error('playwright-core not found. Run scripts/preflight.sh (it installs it into ' + cache + ').'); process.exit(2); }

const args = process.argv.slice(2);
if (!args[0] || args[0].startsWith('--')) { console.error('usage: preflight.sh <url-or-html-file> [--out DIR] [--widths 320,390,...]'); process.exit(2); }
const opt = (n, d) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : d; };
const target = /^(https?|file):\/\//.test(args[0]) ? args[0] : pathToFileURL(resolve(args[0])).href;
const outDir = resolve(opt('--out', '.ui-craft-preflight'));
const widths = opt('--widths', '320,390,768,1024,1440,1920').split(',').map(Number);
const HEIGHT = { 320: 640, 390: 844, 768: 1024, 1024: 768, 1440: 900, 1920: 1080 };
mkdirSync(outDir, { recursive: true });

const views = widths.map(w => ({ name: 'w' + w, w, h: HEIGHT[w] || 900, touch: w <= 768 }));
views.push({ name: 'landscape-phone', w: 844, h: 390, touch: true });
views.push({ name: 'zoom200', w: 640, h: 800, touch: false, dsf: 2 });

const measure = () => {
  const root = document.documentElement, vw = root.clientWidth;
  const sel = (el) => { let s = el.tagName.toLowerCase(); if (el.id) s += '#' + el.id; else if (typeof el.className === 'string' && el.className.trim()) s += '.' + el.className.trim().split(/\s+/).slice(0, 2).join('.'); return s; };
  const visible = (el) => { const r = el.getBoundingClientRect(), cs = getComputedStyle(el); return r.width > 1 && r.height > 1 && cs.visibility !== 'hidden' && cs.display !== 'none' && cs.opacity !== '0'; };
  const clipped = (el) => { for (let p = el.parentElement; p && p !== document.body; p = p.parentElement) { if (getComputedStyle(p).overflowX !== 'visible') return true; } return false; };
  const r = { scrollW: root.scrollWidth, clientW: vw };
  r.overflowX = root.scrollWidth > vw + 1;
  r.offenders = [];
  if (r.overflowX) for (const el of document.body.querySelectorAll('*')) {
    const b = el.getBoundingClientRect();
    if (b.right > vw + 1 && visible(el) && !clipped(el)) { r.offenders.push(sel(el) + ' right=' + Math.round(b.right)); if (r.offenders.length >= 6) break; }
  }
  const interactive = [...document.querySelectorAll('a[href],button,input:not([type=hidden]),select,textarea,summary,[role=button],[role=link],[role=tab],[tabindex]:not([tabindex="-1"])')].filter(visible);
  r.interactive = interactive.length;
  r.smallTargets = interactive.filter(el => { const b = el.getBoundingClientRect(); if (el.tagName === 'A' && getComputedStyle(el).display === 'inline') return false; return Math.min(b.width, b.height) < 44; })
    .map(el => { const b = el.getBoundingClientRect(); return sel(el) + ' ' + Math.round(b.width) + 'x' + Math.round(b.height); });
  r.noTransition = interactive.filter(el => getComputedStyle(el).transitionDuration.split(',').every(d => parseFloat(d) === 0)).map(sel);
  r.imgNoDims = [...document.images].filter(i => visible(i) && !i.hasAttribute('width') && !i.hasAttribute('height') && getComputedStyle(i).aspectRatio === 'auto').length;
  r.bodyFont = parseFloat(getComputedStyle(document.body).fontSize);
  r.smallText = [...document.querySelectorAll('p,li,td,label,span')].filter(el => visible(el) && el.childNodes.length && [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim()) && parseFloat(getComputedStyle(el).fontSize) < 14).length;
  r.squeezed = [...document.querySelectorAll('body *')].filter(el => {
    if (!visible(el)) return false;
    const t = [...el.childNodes].filter(n => n.nodeType === 3).map(n => n.textContent.trim()).join(' ').trim();
    if (t.length < 12) return false;
    const cs = getComputedStyle(el), lh = parseFloat(cs.lineHeight) || parseFloat(cs.fontSize) * 1.3, h = el.getBoundingClientRect().height;
    const lines = Math.round(h / lh);
    return lines >= 5 && t.length / lines < 4;
  }).slice(0, 4).map(sel);
  r.viewportMeta = !!document.querySelector('meta[name=viewport]');
  const anims = document.getAnimations();
  r.animRunning = anims.filter(a => a.playState === 'running').length;
  r.animInfinite = anims.filter(a => { try { return a.effect.getComputedTiming().iterations === Infinity; } catch { return false; } }).length;
  const closed = (el) => { for (let p = el; p && p !== document.documentElement; p = p.parentElement) { const cs = getComputedStyle(p); if (cs.visibility === 'hidden' || cs.pointerEvents === 'none' || p.getAttribute('aria-hidden') === 'true' || p.hasAttribute('inert') || p.hasAttribute('hidden')) return true; } return false; };
  r.hiddenList = [...document.querySelectorAll('body *')].filter(el => { const b = el.getBoundingClientRect(); return b.top < innerHeight && b.bottom > 0 && b.width > 1 && parseFloat(getComputedStyle(el).opacity) < 0.05 && (el.textContent || '').trim().length > 0 && getComputedStyle(el).display !== 'none' && !closed(el); }).slice(0, 5).map(sel);
  r.hiddenInView = r.hiddenList.length;
  return r;
};

const browser = await pw.chromium.launch({ channel: 'chrome' }).catch(async () => { console.error('(system Chrome not found; trying bundled chromium)'); return pw.chromium.launch(); });
const report = { target, views: {}, console: [], focus: null };
const run = async (v, extra = {}) => {
  const ctx = await browser.newContext({ viewport: { width: v.w, height: v.h }, hasTouch: v.touch, isMobile: v.touch, deviceScaleFactor: v.dsf || (v.touch ? 2 : 1), ...extra });
  const page = await ctx.newPage();
  page.on('pageerror', e => report.console.push(v.name + ': ' + e.message));
  page.on('console', m => { if (m.type() === 'error') report.console.push(v.name + ': ' + m.text()); });
  await page.goto(target, { waitUntil: 'load', timeout: 20000 }).catch(e => report.console.push(v.name + ': goto ' + e.message));
  await page.waitForTimeout(250);
  const early = await page.evaluate(() => document.getAnimations().filter(a => a.playState === 'running').length);
  await page.waitForTimeout(1000);
  // scroll through the whole page (triggers scroll reveals / lazy content), then back to top
  await page.evaluate(async () => {
    const step = Math.max(200, Math.round(innerHeight * 0.7)); let y = 0;
    for (let i = 0; i < 60 && y < document.documentElement.scrollHeight; i++) { y += step; scrollTo(0, y); await new Promise(r => setTimeout(r, 140)); }
    scrollTo(0, 0); await new Promise(r => setTimeout(r, 400));
  });
  const m = await page.evaluate(measure); m.animEarly = early;
  return { ctx, page, m };
};

for (const v of views) {
  const { ctx, page, m } = await run(v);
  await page.screenshot({ path: join(outDir, v.name + '.png'), fullPage: true }).catch(() => {});
  report.views[v.name] = m;
  if (v.name === 'w1440') {
    await page.keyboard.press('Tab');
    report.focus = await page.evaluate(() => { const el = document.activeElement; if (!el || el === document.body) return { ok: null, note: 'nothing focusable' }; const cs = getComputedStyle(el); const none = cs.outlineStyle === 'none' && cs.boxShadow === 'none'; return { ok: !none, el: el.tagName.toLowerCase() + (el.className && typeof el.className === 'string' ? '.' + el.className.split(' ')[0] : '') }; });
  }
  await ctx.close();
}
const rm = await run({ name: 'reduced-motion', w: 390, h: 844, touch: true }, { reducedMotion: 'reduce' });
report.reducedMotion = rm.m; await rm.ctx.close(); await browser.close();

// ---- verdicts
const fails = [], warns = [];
for (const [name, m] of Object.entries(report.views)) {
  if (m.overflowX) fails.push(`${name}: horizontal overflow (${m.scrollW}px > ${m.clientW}px) ← ${m.offenders.join(', ') || 'unknown'}`);
  const touch = views.find(x => x.name === name)?.touch;
  if (touch && m.smallTargets.length) fails.push(`${name}: ${m.smallTargets.length} tap target(s) < 44px ← ${m.smallTargets.slice(0, 5).join(', ')}`);
  if (!m.viewportMeta && name === 'w390') fails.push('missing <meta name="viewport">');
  if (m.noTransition.length && name === 'w1440') warns.push(`w1440: ${m.noTransition.length}/${m.interactive} interactive element(s) have no transition ← ${m.noTransition.slice(0, 5).join(', ')}`);
  if (m.squeezed && m.squeezed.length) warns.push(`${name}: squeezed text (≈1-3 chars per line — a column too narrow) ← ${m.squeezed.join(', ')}`);
  if (m.imgNoDims && name === 'w390') warns.push(`${m.imgNoDims} image(s) without width/height/aspect-ratio (layout shift)`);
  if (m.bodyFont < 16 && name === 'w390') warns.push(`body font-size is ${m.bodyFont}px (< 16px)`);
  if (m.smallText && name === 'w390') warns.push(`${m.smallText} text element(s) under 14px`);
}
const m1440 = report.views.w1440 || Object.values(report.views)[0];
if (m1440 && m1440.animEarly === 0 && m1440.animRunning === 0) warns.push('nothing is animating on load or after 1s — liveliness baseline (entrance / ambient) looks absent');
const rmm = report.reducedMotion;
if (rmm.animInfinite > 0) warns.push(`reduced-motion: ${rmm.animInfinite} infinite animation(s) still running`);
if (rmm.hiddenInView > 0) fails.push(`reduced-motion: ${rmm.hiddenInView} in-view element(s) stuck at opacity 0 (reveal never fires without motion) ← ${rmm.hiddenList.join(', ')}`);
if (report.focus && report.focus.ok === false) fails.push(`first tabbable (${report.focus.el}) has no visible focus style`);
for (const c of report.console.slice(0, 5)) warns.push('console: ' + c);

writeFileSync(join(outDir, 'report.json'), JSON.stringify({ ...report, fails, warns }, null, 2));
console.log(`\nui-craft preflight — ${target}\nscreenshots + report.json → ${outDir}\n`);
console.log('view'.padEnd(18) + 'overflow  interactive  <44px  noTrans  animEarly/running/∞');
for (const [n, m] of Object.entries(report.views)) console.log(n.padEnd(18) + String(m.overflowX ? 'YES' : 'no').padEnd(10) + String(m.interactive).padEnd(13) + String(m.smallTargets.length).padEnd(7) + String(m.noTransition.length).padEnd(9) + `${m.animEarly}/${m.animRunning}/${m.animInfinite}`);
console.log('\n' + (fails.length ? 'FAIL' : 'PASS') + ` — ${fails.length} fail, ${warns.length} warn`);
fails.forEach(f => console.log('  FAIL ' + f)); warns.forEach(w => console.log('  warn ' + w));
console.log('\nNumbers catch breakage; open the screenshots to judge whether it feels designed at each width.');
process.exit(fails.length ? 1 : 0);
