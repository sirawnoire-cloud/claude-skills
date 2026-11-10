# Theme and craft fundamentals

The direction (`directions.md`) decides the *look*. This file is the machinery under every look: tokens,
color, type, spacing, depth. Bold designs need *more* rigor here, not less — a loud palette or a glass
effect with sloppy spacing and weak contrast looks worse than a plain page.

## Tokens: one source of truth

Every color, size, space, radius, shadow, duration and easing is a CSS custom property defined once. No
raw values in components. Where they live:

- **Tailwind** — custom properties on `:root` / `[data-theme]`, referenced from `tailwind.config`.
- **shadcn/ui** — edit its existing variables; don't add a parallel set.
- **Plain CSS / CSS Modules** — one `tokens.css`, imported once.
- **CSS-in-JS** — the library's theme object, one file.

Self-check: can you name every color, size, space and duration on screen and point at where it's
defined? Anything unaccounted for is a hole the next component will widen.

## Color

**Build ramps in OKLCH.** It's perceptually uniform, so equal lightness steps *look* equal and hue stays
stable across a ramp — which makes accessible, harmonious palettes a calculation rather than guesswork.

```css
:root {
  --h: 285;                                         /* brand hue */
  --accent:     oklch(0.68 0.20 var(--h));
  --accent-2:   oklch(0.82 0.13 205);              /* secondary / gradient partner */
  --accent-fg:  oklch(0.99 0 0);                    /* text on accent — verify contrast */
  --bg:         oklch(0.985 0.005 var(--h));
  --surface:    oklch(1 0 0);
  --border:     color-mix(in oklab, var(--text) 10%, transparent);
  --text:       oklch(0.2 0.02 var(--h));
  --text-muted: oklch(0.45 0.03 var(--h));          /* must clear 4.5:1 on --bg: compute it */
  --gradient-brand: linear-gradient(135deg, var(--accent), var(--accent-2));
}
```
Use `color-mix(in oklab, …)` for hover/pressed/translucent variants instead of hand-picking hexes. Use
`light-dark()` with `color-scheme: light dark` where support is acceptable, or `[data-theme]` token sets.

**An accent *system*, not an accent.** Primary, an optional secondary, a brand gradient — all tokens.
Emphasis must still read: the single most important action on a screen is the most prominent thing.
Squint test: blur your eyes (or view in grayscale) — hierarchy should survive.

**Neutrals carry the design.** Give the grey ramp a hue cast (a few degrees toward the brand hue or a
warm tone); pure `#808080` reads dead. Nine to eleven steps so there's always a right one. Avoid pure
`#000` / `#fff` for large areas — start inset so there's room to go darker/lighter.

**Dark mode is a separate palette, not an inversion.** Lower saturation, less extreme contrast (pure
white on pure black vibrates), surfaces separated by lightness steps rather than shadows. Every token has
a value in both themes; never define a color only inside a media query.

**Contrast is computed, never eyeballed:** body 4.5:1, large text and UI components 3:1 — and it applies
over glass, gradients and photos (check the worst-case pixel, or add a scrim).

Traps: muted text that drifts lighter each pass; accent on everything (so nothing is emphasized);
gradients across low-contrast hue pairs that muddy in the middle (use `in oklch` interpolation).

## Type

**Pair with intent.** A display face with character + a workhorse text face (max two families, ~4
weights) — unless the direction is Quiet Precision, where one family with real weights is right. Variable
fonts give the range with one file. Load with `font-display: swap`, preload the display face.

**A scale with drama.** Fluid, with a real jump to the hero:
```css
:root {
  --step--1: clamp(.83rem, .80rem + .15vw, .94rem);
  --step-0:  clamp(1rem,   .96rem + .20vw, 1.125rem);   /* body ≥ 16px */
  --step-1:  clamp(1.25rem,1.15rem + .5vw, 1.5rem);
  --step-3:  clamp(1.75rem,1.4rem + 1.6vw, 2.5rem);
  --step-5:  clamp(2.5rem, 1.6rem + 4.5vw, 5rem);       /* section/hero headings */
  --step-6:  clamp(3rem,   1.5rem + 7vw,   7.5rem);     /* hero display */
}
```
Always keep a fixed `rem` term inside `clamp()` so browser zoom still works. Body 16px minimum — 14px
body is the commonest reason a UI feels cramped.

**Details that read as quality:**
- `text-wrap: balance` on headings, `text-wrap: pretty` on paragraphs
- Tight tracking on large display (`-0.02em` to `-0.04em`), never on body
- `font-variant-numeric: tabular-nums` for numbers that change or align
- Heading line-height ~1.05–1.25, body ~1.5–1.6, measure capped at ~65–75ch
- Weight and size build hierarchy first; color supports it

## Thai (and other non-Latin) text

The user may be Thai-speaking and the content often is too:
- Use fonts with real Thai glyphs: *Noto Sans Thai*, *IBM Plex Sans Thai*, *Anuphan*, *Prompt*, *Kanit*,
  *Sarabun*, *Bai Jamjuree*. A Latin-only display font silently falls back for Thai — pair it with a Thai
  font in the same `font-family` stack and **look at Thai text rendered**.
- Thai needs more line-height: **body ≥ 1.6–1.7**, headings ≥ 1.3 (stacked vowels/tone marks clip at
  tight leading).
- No negative letter-spacing on Thai. Don't use `text-transform` (no case in Thai).
- Thai has no spaces between words: use `overflow-wrap: anywhere` / `word-break: normal` and let the
  browser's Thai segmentation break lines; test long strings for overflow.
- Test mixed Thai/English lines — baseline and size can differ between the two fonts; adjust with
  `size-adjust`/`ascent-override` if needed.

## Spacing

One scale, powers of a base: `4 / 8 / 12 / 16 / 24 / 32 / 48 / 64 / 96 / 128`. Section padding is fluid:
```css
--space-section: clamp(3rem, 2rem + 5vw, 8rem);
```
**Proximity encodes relationship** — related things close, unrelated things far. Everything evenly spaced
reads as an undifferentiated list. Align to a grid and mean it: 2px drift is the most-felt, least-named
flaw. Density follows direction (Terminal/Dashboard dense by design; Editorial/Quiet generous) — but
cramped-by-accident always reads as unfinished.

## Depth, borders, radius

Decide a **depth recipe per direction** and apply it consistently, as tokens:

- **Border-only** (hairline) — Terminal, Quiet Precision
- **Layered shadow** — 2–3 stacked, low-alpha, small-offset shadows (never one big blurry drop):
  ```css
  --shadow-lift: 0 1px 1px oklch(0 0 0 / .06), 0 4px 8px oklch(0 0 0 / .06), 0 16px 32px oklch(0 0 0 / .08);
  ```
- **Glass** — translucent surface + `backdrop-filter` + 1px light border + inner highlight (Aurora)
- **Hard offset** — `4px 4px 0` solid shadow + thick border (Neo-brutalist)
- **Background step** — a surface one lightness step off the page, no border/shadow (Bento, Soft)

Radius is a small named set (e.g. `--r-sm`, `--r-md`, `--r-lg`, `--r-pill`) used consistently per
component type — mixing arbitrary values looks accidental. Texture (2–4% grain/noise over large flat
areas) removes the sterile "digital flat" look cheaply.

## Self-check before calling a theme done

- Every value traces to a token; both themes defined
- Contrast computed for body, muted, accent-on-bg, text-on-accent, and text over any glass/gradient
- The hero is clearly the biggest thing; the primary action is clearly the most prominent action
- Looks intentional in grayscale and at 320px
- Thai (or the content's script) actually rendered and checked
