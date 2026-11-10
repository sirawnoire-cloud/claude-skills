# Motion — the liveliness baseline

"Lifeless" has a specific cause: the interface sits still while the person acts. Fixing it is not
sprinkling animation — it's giving the page a **motion system**: a few tokens, a few patterns, applied on
purpose. Every screen ships with the baseline below. The user should never have to ask for it.

Motion earns its place by doing one of four jobs: **answer** (feedback to an action), **orient** (show
what changed or where something went), **connect** (continuity between states/pages), or **delight**
(a deliberate, bounded moment). It never delays reading or interaction.

## Tokens (define once)

```css
:root {
  --dur-instant: 90ms;   /* press-down */
  --dur-fast:   150ms;   /* hover, color, small flips */
  --dur-base:   240ms;   /* most transitions */
  --dur-slow:   400ms;   /* panels, entrances */
  --dur-hero:   650ms;   /* hero / first-view choreography, direction-dependent */
  --ease-out:    cubic-bezier(.16, 1, .3, 1);     /* things arriving — default */
  --ease-in-out: cubic-bezier(.65, 0, .35, 1);    /* things moving across */
  --ease-spring: cubic-bezier(.34, 1.56, .64, 1); /* slight overshoot: toggles, success, playful */
}
```

Direction sets the personality: Quiet Precision / Terminal → short durations, no overshoot; Editorial /
Cinematic → long durations; Playful / Neo-brutalist → spring. Keep it consistent across the app.

## The baseline — every screen ships with these

| # | Piece | Minimum |
|---|---|---|
| L1 | **Entrance choreography** | First view staggers in, once, ≤ 650ms total, content readable and usable immediately |
| L2 | **Interactive feedback** | Every interactive element: hover (fine pointers), press, focus-visible — on-brand, not just a color swap |
| L3 | **Signature motion** | The direction's signature move, implemented and smooth |
| L4 | **Two non-hover motions** | Any two of: scroll reveal, list enter/leave, tab/underline indicator slide, expand/collapse, count-up, chart draw, ambient layer |
| L5 | **Loading** | Skeleton shimmer matching real layout; button-level spinners; optimistic updates where safe |
| L6 | **Continuity** | Route/state changes use view transitions or shared-element motion where supported (with fallback) |
| L7 | **Reduced motion** | Everything above degrades to opacity/instant under `prefers-reduced-motion` |

A tweak to one component still carries L2 and L7 for what it touches.

## L1 — Entrance choreography

```css
@media (prefers-reduced-motion: no-preference) {
  .rise {
    opacity: 0; translate: 0 14px;
    animation: rise var(--dur-hero) var(--ease-out) forwards;
    animation-delay: calc(var(--i, 0) * 60ms);
  }
}
@keyframes rise { to { opacity: 1; translate: 0 0; } }
```
Set `style="--i:N"` per element. Rules: stagger at most ~8 elements (then group the rest), ≤ 60ms apart;
animate transform/opacity only; never gate interactive controls behind the animation (they must work at
t = 0). Plays once per page load, not on every re-render.

## L2 — Feedback on everything interactive

```css
.btn {
  transition: transform var(--dur-fast) var(--ease-out),
              box-shadow var(--dur-base) var(--ease-out),
              background-color var(--dur-fast) var(--ease-out);
}
@media (hover: hover) {
  .btn:hover { transform: translateY(-1px); box-shadow: var(--shadow-lift); }
}
.btn:active { transform: translateY(0) scale(.97); transition-duration: var(--dur-instant); }
.btn:focus-visible { outline: 2px solid var(--accent); outline-offset: 3px; }
```
Press matters more than hover — it's the "did my click land?" answer. Wrap hover in `(hover: hover)` so
touch devices don't get stuck hover states.

## L3/L4 — Patterns that make a page feel alive

**Scroll reveal** — CSS scroll-driven where supported, IntersectionObserver fallback:
```css
@media (prefers-reduced-motion: no-preference) {
  @supports (animation-timeline: view()) {
    .reveal { animation: rise linear both; animation-timeline: view(); animation-range: entry 0% cover 28%; }
  }
}
```
```js
// fallback: html gets class "js"; only hide when JS can reveal
if (!CSS.supports('animation-timeline: view()')) {
  const io = new IntersectionObserver((es) => es.forEach(e => {
    if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
  }), { threshold: .15 });
  document.querySelectorAll('.reveal').forEach(el => io.observe(el));
}
```
```css
.js .reveal:not(.in) { opacity: 0; translate: 0 14px; }
.js .reveal { transition: opacity var(--dur-slow) var(--ease-out), translate var(--dur-slow) var(--ease-out); }
```
(If using the scroll-driven branch, don't also apply the `.js` hide rule inside `@supports`.)

**Animated indicator** (tabs, nav underline, segmented control): one absolutely positioned element whose
`translate`/`width` is set from the active item; transition it with `--ease-out`. Reads as one object
moving rather than two states swapping.

**Expand / collapse height** — animate `grid-template-rows`, never `height`:
```css
.collapsible { display: grid; grid-template-rows: 0fr; transition: grid-template-rows var(--dur-base) var(--ease-out); }
.collapsible[data-open] { grid-template-rows: 1fr; }
.collapsible > * { overflow: hidden; }
```

**List enter/leave** — items slide/fade in from where they came; removed items collapse. With the View
Transitions API this is a few lines (below); otherwise transition `opacity` + `grid-template-rows`.

**Count-up** for key numbers (once, when first visible):
```js
function countUp(el, to, ms = 900) {
  const from = 0, t0 = performance.now();
  const step = (t) => {
    const p = Math.min((t - t0) / ms, 1), e = 1 - Math.pow(1 - p, 3);
    el.textContent = Math.round(from + (to - from) * e).toLocaleString();
    if (p < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}
```
Use `font-variant-numeric: tabular-nums` so digits don't jitter. Under reduced motion, set the final value.

**Chart draw** — SVG `stroke-dasharray`/`stroke-dashoffset` from full to 0 once.

**Animated gradient border (Aurora Glass signature)** — registered property, no JS:
```css
@property --angle { syntax: '<angle>'; initial-value: 0deg; inherits: false; }
.glow {
  border: 1px solid transparent;
  background: linear-gradient(var(--surface), var(--surface)) padding-box,
              conic-gradient(from var(--angle), var(--accent), var(--accent-2), var(--accent)) border-box;
  animation: spin 6s linear infinite;
}
@keyframes spin { to { --angle: 360deg; } }
```

**Cursor spotlight** (fine pointers only):
```css
.spot { position: relative; }
.spot::before {
  content: ""; position: absolute; inset: 0; border-radius: inherit; pointer-events: none; opacity: 0;
  background: radial-gradient(420px circle at var(--mx, 50%) var(--my, 50%),
              color-mix(in oklab, var(--accent) 22%, transparent), transparent 60%);
  transition: opacity var(--dur-base);
}
@media (hover: hover) and (pointer: fine) { .spot:hover::before { opacity: 1; } }
```
```js
document.querySelectorAll('.spot').forEach(el => el.addEventListener('pointermove', e => {
  const r = el.getBoundingClientRect();
  el.style.setProperty('--mx', (e.clientX - r.left) + 'px');
  el.style.setProperty('--my', (e.clientY - r.top) + 'px');
}));
```

**Magnetic button / tilt** — optional, max one pointer effect per screen, fine pointers only.

**Ambient layer** — one slow layer (drifting blurred blobs, floating shapes, grain). Rules: `transform`
animation only, ≥ 12s loops, `pointer-events: none`, pause when off-screen (IntersectionObserver) or the
tab is hidden (`visibilitychange`), removed under reduced motion.

## L5 — Loading

Skeleton shimmer that matches the real layout (a skeleton with different proportions causes a visible
snap):
```css
.skeleton {
  background: linear-gradient(100deg, var(--surface) 30%, color-mix(in oklab, var(--surface) 70%, white) 50%, var(--surface) 70%);
  background-size: 200% 100%; animation: shimmer 1.4s linear infinite;
}
@keyframes shimmer { to { background-position: -200% 0; } }
```
Wait handling and optimistic updates: see `interaction.md`.

## L6 — Continuity with View Transitions

```js
const go = (update) => document.startViewTransition ? document.startViewTransition(update) : update();
```
```css
@media (prefers-reduced-motion: no-preference) {
  ::view-transition-old(root), ::view-transition-new(root) { animation-duration: var(--dur-slow); }
}
/* shared element: give both states the same name */
.card-thumb { view-transition-name: hero-img; }
```
Progressive enhancement only — the `update()` fallback must produce the same final UI. Frameworks with
router integration (Next, Astro, SvelteKit) have first-class support; use theirs.

## Performance rules (non-negotiable)

- Animate **`transform`, `opacity`, `filter`** (and `translate`/`scale`/`rotate`). Never `width`,
  `height`, `top`, `left`, `margin` — use `grid-template-rows` or transforms.
- `will-change` only on elements about to animate, removed after; never blanket `will-change`.
- ≤ 3 `backdrop-filter` layers in view at once; blurs are expensive on low-end phones.
- Loops that run forever must pause when not visible and be absent under reduced motion.
- JS animation uses `requestAnimationFrame` (or the Web Animations API); no `setInterval` animation loops.
- First interaction never waits for an animation to finish.
- Check on a throttled CPU (DevTools 4× slowdown) before calling it smooth.

## Reduced motion — do it properly

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation-duration: .01ms !important; animation-iteration-count: 1 !important;
    transition-duration: .01ms !important; scroll-behavior: auto !important; }
}
```
Plus: reveal-on-scroll content must be visible (not stuck at `opacity: 0`) and ambient layers off. The
page must still look intentional with motion removed — that's the test of a sound layout.

## Taste budget

One signature move, one ambient layer, one pointer effect, a consistent easing family. If you're
adding a fourth kind of effect, you're decorating; stop and fix hierarchy or spacing instead.
