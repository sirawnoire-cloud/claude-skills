# Responsive — fluid by default, verified by looking

"Responsive" is not "the columns stack on mobile". It means the interface is **designed at every width,
orientation and input type**, and adapts to the person's settings. The user shouldn't have to ask
"make it more responsive" — that request means a flat, only-not-broken layout got shipped.

## Decide the primary device — by inference, never by asking

Infer it from the product (see SKILL.md Phase 2): dashboards, admin and dev tools → desktop-primary;
consumer, content, commerce, link-shared pages → mobile-primary; unsure → mobile-first. State it in the
assumptions. The primary device gets the layout with no compromise; the others get adaptations that are
*designed*, not leftovers. Always fluid across all of them.

Mobile-first CSS (base = phone, `min-width` queries add complexity) is the forgiving default.

## Fluid everything — fewer breakpoints, more intrinsic behavior

Prefer layouts that adapt continuously over ones that jump at breakpoints:

```css
.grid   { display: grid; gap: var(--gap); grid-template-columns: repeat(auto-fit, minmax(min(100%, 18rem), 1fr)); }
.stack  { display: flex; flex-direction: column; gap: var(--gap); }
.row    { display: flex; flex-wrap: wrap; gap: var(--gap); }
h1      { font-size: var(--step-5); }                         /* clamp() scale from theme.md */
section { padding-block: var(--space-section); padding-inline: clamp(1rem, 4vw, 3rem); }
.wrap   { width: min(100% - 2rem, 80rem); margin-inline: auto; }  /* caps ultra-wide */
img, video { max-width: 100%; height: auto; }
```

Use a media query when the layout must genuinely **change shape** (sidebar → drawer, table → cards), not
merely resize. Typical set: base · ~640–768 · ~1024 · ~1280+ (usually just a max-width). Add one where
the *content* breaks — resize slowly and watch for lines too long, orphaned cards, overflowing tables.

## Container queries — components that adapt to where they're placed

A component should respond to its **container**, not the viewport, so it works in a sidebar, a modal and a
main column without knowing which it's in:

```css
.tile-wrap { container-type: inline-size; }
.tile { display: grid; gap: .75rem; }
@container (min-width: 28rem) { .tile { grid-template-columns: 8rem 1fr; align-items: center; } }
@container (min-width: 44rem) { .tile { grid-template-columns: 12rem 1fr auto; } }
```
Bento tiles, cards, stat blocks, nav items: container queries by default.

## Responsive to the person, not just the screen

| Signal | What to do |
|---|---|
| Input: `(hover: hover) and (pointer: fine)` vs coarse | Hover/cursor effects only on fine pointers; coarse gets bigger targets and visible controls |
| `prefers-color-scheme` | Light and dark token sets; honor the system, allow override |
| `prefers-reduced-motion` | Motion degrades to opacity/instant (see `motion.md`) |
| `prefers-contrast: more` | Strengthen borders and text contrast |
| Text zoom / browser zoom (up to 200–400%) | Layout reflows, nothing clipped or overlapping; rem-based sizing, fixed term in `clamp()` |
| Orientation / split-screen / foldables | Test landscape phone (≈ 844×390); don't depend on tall viewports |
| Slow network / low power | Skeletons, lazy-loaded images with dimensions, no heavy always-on effects |
| Language | RTL/Thai/long-word safe: logical properties (`margin-inline`), `overflow-wrap`, test long strings |

Use **logical properties** (`margin-inline`, `padding-block`, `inset-inline-start`) so RTL and vertical
writing work for free.

## Touch targets — non-negotiable

**44×44px minimum** for anything tappable, ~8px between adjacent targets. The visual element can be
smaller than the hit area (a 20px icon inside a 44px button is correct). Thumb reach: on phones, the
bottom half is comfortable and the top corners aren't — primary actions live low on mobile.

## What changes at each width

| | Mobile | Desktop |
|---|---|---|
| Navigation | bottom bar or drawer | top bar or sidebar |
| Multi-column | stacks to one | side by side |
| Table | cards, or horizontal scroll with sticky first column | full table |
| Modal | full-screen / bottom sheet | centered dialog |
| Primary action | bottom, often sticky | inline or top-right |
| Hover affordances | must be visible | may appear on hover |
| Hero / display type | scaled, still dramatic | full scale |

**Never hide content to make mobile fit.** Reorganize, collapse behind a disclosure, or paginate — but a
mobile user who can't reach what a desktop user can is being given a broken app.

## The things that actually break

- **Horizontal overflow** — the most common bug. Usual causes: fixed widths, long unbroken strings
  (URLs, tokens, Thai without spaces), images without `max-width`, negative margins, `100vw` (includes
  the scrollbar). Wide content (tables, code, diagrams) scrolls inside its own `overflow-x: auto`
  wrapper; the page never scrolls sideways.
- **`100vh` on mobile** hides content under browser chrome — use `100dvh` (with a `100vh` fallback).
- **Sticky headers eating small screens** — shrink on scroll or don't stick.
- **Fixed bars vs the on-screen keyboard** — test with a text field focused.
- **Images without dimensions** — layout shift; always `width`/`height` or `aspect-ratio`.
- **Safe areas** — `padding: env(safe-area-inset-*)` on full-bleed fixed elements (notches, home bar).
- **Ultra-wide stretching** — cap line length and content width; don't let a 1920px layout be 1920px of
  text.
- **Hover-only meaning** — invisible on touch.

## Pre-flight: six widths + the extras (run it, don't reason about it)

| Width | Stands for | Look for |
|---|---|---|
| 320 | smallest phones, zoomed text | overflow, wrapping, targets |
| 390 | typical phone | the mobile-primary layout at its best |
| 768 | tablet portrait | in-between layouts, orphaned grids |
| 1024 | tablet landscape / small laptop | sidebar vs drawer decisions |
| 1440 | desktop | the desktop-primary layout at its best |
| 1920 | large monitor | max-width caps, not stretched or lost in space |
| + landscape phone 844×390 | | short-viewport problems, sticky bars |
| + 200% text zoom | | reflow, clipping |

```
~/.claude/skills/ui-craft/scripts/preflight.sh http://localhost:3000
~/.claude/skills/ui-craft/scripts/preflight.sh ./index.html --out ./preflight
```
It screenshots all of the above, then reports horizontal overflow (with the offending elements), tap
targets under 44px at touch widths, interactive elements with no transition, images with no dimensions,
body text under 16px, and how much is animating — also once with reduced motion emulated. Look at the
screenshots; the numbers catch breakage, your eyes catch "not designed".

Say which widths you actually looked at and which you only reasoned about. Don't blur the two.
