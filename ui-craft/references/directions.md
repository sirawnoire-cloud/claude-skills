# Directions — pick a point of view, then commit

A "direction" is a complete, named look-and-feel with real token values and one signature move. Picking
one is what separates a designed product from a template. Choose by product context, commit to it for
the whole app, and borrow at most one element from a second direction.

Every direction below still obeys the non-negotiables: tokens, contrast ≥ 4.5:1 for body text (on glass,
gradients and photos too), every state, keyboard access, responsive at all widths, reduced-motion safe.

## Choosing

| Product | First choice | Second choice |
|---|---|---|
| AI tool, SaaS landing, startup, "futuristic" | Aurora Glass | Cinematic Dark |
| Dev tool, infra, CLI companion, API docs | Terminal / Technical | Quiet Precision |
| Dashboard, analytics, admin, CRM | Bento Dashboard | Quiet Precision |
| Portfolio, agency, brand, premium product | Editorial Luxe | Cinematic Dark |
| Creative / youth / community / indie | Neo-brutalist Pop | Soft Playful |
| Consumer app, health, education, kids, wellness | Soft Playful | Editorial Luxe |
| Media, gaming, events, entertainment | Cinematic Dark | Aurora Glass |
| Finance, enterprise, legal, internal tools, docs | Quiet Precision | Bento Dashboard |

If the user said "cool / futuristic / เท่ / ล้ำ" and the table doesn't say otherwise, go **Aurora Glass**
or **Cinematic Dark**. If they said "clean / professional", go **Quiet Precision** — but still bring the
liveliness baseline; clean is not the same as dead.

## The signature move

Each direction has one memorable idea. Name it in the spec, build it first, and make it flawless — it
carries the identity, so everything else can stay quiet. If you can't describe the page's signature
in one sentence, there isn't one yet.

## 1. Aurora Glass — futuristic, AI, SaaS

- **Mood:** luminous, deep, high-tech, calm confidence.
- **Palette:** dark base `oklch(0.16 0.02 270)`, surface `oklch(0.21 0.03 270 / 0.6)` (translucent),
  text `oklch(0.97 0.01 270)`, muted `oklch(0.75 0.03 270)`. Accent pair electric violet
  `oklch(0.68 0.2 285)` → cyan `oklch(0.82 0.13 205)`. Light theme: pale lavender-white base, same hues
  at lower chroma, glass becomes white-translucent with a soft shadow.
- **Type:** display *Space Grotesk* / *Sora* / *Outfit* (tight tracking, large); text *Inter* / *Geist*;
  mono details *Geist Mono*.
- **Shape/depth:** radius 16–20; glass = `backdrop-filter: blur(16–24px) saturate(1.4)`, 1px
  translucent border, inner top highlight `inset 0 1px 0 oklch(1 0 0 / .08)`. Max ~3 blurred layers per viewport.
- **Background:** 2–3 large blurred gradient blobs (aurora) drifting slowly, plus faint grain. One ambient layer.
- **Motion personality:** smooth, floaty — `--ease-out`, 500–700ms entrances, springy press.
- **Signature move (pick one):** animated conic-gradient border on the primary card/CTA, or a
  cursor-following spotlight that lights card borders.

## 2. Terminal / Technical — dev tools

- **Mood:** precise, fast, a bit hacker-cool.
- **Palette:** near-black `oklch(0.14 0.01 250)`, surface one step up, hairline borders
  `oklch(1 0 0 / .08)`, text off-white, one phosphor accent (green `oklch(0.85 0.2 150)`, amber, or
  cyan). Light theme: warm paper + ink + same accent darkened for contrast.
- **Type:** *Geist Mono* / *JetBrains Mono* / *IBM Plex Mono* for headings and labels, *Inter* for
  body. Tight, dense, tabular numbers.
- **Shape/depth:** radius 4–6; borders over shadows; dot-grid or fine line-grid background.
- **Motion personality:** snappy — 100–160ms, `--ease-out`, no bounce; typed-text and caret effects.
- **Signature move:** a command palette (`⌘K`) that drives the whole UI, with `kbd` hints everywhere
  and live status chips; or a streaming/typing reveal on the hero.

## 3. Bento Dashboard — SaaS, analytics

- **Mood:** organized, modern, information-rich but breathable.
- **Palette:** neutral ramp with a slight hue cast, one strong accent, plus a defined data-viz
  palette (5–6 distinguishable hues, validated for color-blind safety).
- **Type:** *Inter* / *Geist* + tabular numerals; big numbers 2.5–4× body.
- **Shape/depth:** radius 20–24 on tiles, 10–12 inside; tiles = background-step + hairline border;
  gap 12–16.
- **Layout:** bento grid — tiles of varied spans on a 12-col grid; each tile is a `container-type:
  inline-size` and adapts its own content.
- **Motion personality:** crisp — count-up numbers, charts draw once, tiles lift on hover, tiles
  stagger in.
- **Signature move:** live tiles — numbers that tick, sparklines that draw, a tile that expands in
  place (view transition) into its detail view.

## 4. Editorial Luxe — brand, portfolio, premium

- **Mood:** confident, expensive, magazine-like.
- **Palette:** warm paper `oklch(0.97 0.01 85)` + ink `oklch(0.2 0.02 60)` + one vivid accent
  (vermilion, electric blue). Dark variant: ink base, paper text.
- **Type:** serif display *Fraunces* / *Instrument Serif* / *Playfair Display* at huge sizes
  (`clamp(3rem, 8vw+1rem, 9rem)`), tight tracking; *Inter*/*Hanken Grotesk* for text.
- **Shape/depth:** radius 0–4 or full-bleed; thin rules; almost no shadow. Asymmetric grids, text
  overlapping imagery, generous negative space.
- **Motion personality:** slow, elegant — 600–900ms `--ease-out`, scroll-linked reveals, image
  mask/clip reveals.
- **Signature move:** oversized type that reacts to scroll (scales, shifts, or reveals line by line),
  or a full-bleed image that clip-reveals.

## 5. Neo-brutalist Pop — creative, youth, indie

- **Mood:** loud, honest, playful, a bit rebellious.
- **Palette:** off-white `oklch(0.97 0.02 95)` page, black `oklch(0.15 0 0)` ink, saturated flats
  (yellow `oklch(0.9 0.18 100)`, hot pink, cobalt, mint).
- **Type:** chunky display *Archivo Black* / *Bricolage Grotesque* / *Space Grotesk Bold*; text
  grotesk.
- **Shape/depth:** 2–3px black borders, **hard offset shadows** (`4px 4px 0 var(--ink)`), radius 0–8,
  sticker-like slight rotations (±1–2°).
- **Motion personality:** bouncy `--ease-spring`, 150–250ms; things snap.
- **Signature move:** the press mechanic — on `:active` the element translates by its shadow offset and
  the shadow collapses to 0 (physical button).

## 6. Soft Playful — consumer, wellness, education

- **Mood:** friendly, warm, approachable.
- **Palette:** high-lightness pastels in OKLCH (`oklch(0.92 0.06 var(--h))`), one saturated action
  color, text a deep tinted ink (never pure black).
- **Type:** rounded display *Nunito* / *Quicksand* / *Fredoka* / *Baloo*; body *Nunito Sans* or similar.
- **Shape/depth:** radius 24–32, pill buttons, soft layered shadows with a colored tint,
  inner-highlight "pillow" surfaces.
- **Motion personality:** springy, generous — `--ease-spring`, scale-in on appear, wobble on success.
- **Signature move:** a mascot / illustrated empty states and a celebratory success moment
  (confetti-lite, checkmark draw, progress ring completing).

## 7. Cinematic Dark — media, gaming, events

- **Mood:** dramatic, immersive, story-driven.
- **Palette:** true-ish black `oklch(0.12 0.005 270)`, high-contrast white text, one glowing accent;
  imagery/video does the color work.
- **Type:** condensed or wide display (*Bebas Neue*, *Anton*, *Unbounded*, *Syne*), huge, uppercase
  allowed; clean sans for text.
- **Shape/depth:** full-bleed sections, minimal chrome, film grain overlay at ~4% opacity, vignette.
- **Motion personality:** cinematic — long eases, parallax, scroll-pinned scenes, image zooms.
- **Signature move:** scroll storytelling — pinned sections whose content transforms as you scroll.

## 8. Quiet Precision — finance, enterprise, docs

- **Mood:** trustworthy, calm, exact.
- **Palette:** one neutral ramp with a slight hue cast (near-white `#FAFAF9`-ish background, near-black
  text, never pure `#000`/`#fff`), one accent used sparingly. Muted text must clear 4.5:1 — compute it.
- **Type:** one family with real weights (*Inter*, *Geist*, or system), body 16px+, large headings
  tight (`-0.02em`).
- **Shape/depth:** radius 6–8, one depth mechanism per surface (border-only is the safe default),
  generous whitespace, exact alignment.
- **Motion personality:** fast and subtle — 120–200ms, but present: hover, press, focus, list
  enter/leave, skeletons, optimistic updates.
- **Signature move:** craft in the details — beautifully handled focus rings, number formatting,
  inline validation, and keyboard shortcuts. Restraint is the point, so every flaw is visible.

## AI-default blacklist

If your output matches three or more of these, you've shipped a template. Change the direction.

- Purple/indigo → pink gradient hero on a white page
- One default sans (Inter/Roboto/system) for everything, no display face, no scale drama
- A row of three identical cards, each with an icon in a tinted circle, a title and two lines
- Centered hero, gradient headline, one filled + one ghost button
- Emoji used as icons; the same rounded-square icon tile repeated everywhere
- Glassmorphism or neon glow applied to every surface
- Uniform 8px radius and `shadow-md` on everything
- Copy that could belong to any product: "Unlock the power of…", "Seamless", "Revolutionize"
- Hero → three features → testimonial → CTA with identical vertical rhythm every time
- Gray text on gray surfaces

## Making any direction feel more alive and premium (cheap wins)

- A real display face with a visible scale jump (hero ≥ 3× body)
- A deliberate accent *system* (primary, secondary, a gradient) defined as tokens, not scattered hexes
- Layered shadows (2–3 low-alpha layers) instead of one blurry drop
- Subtle grain/noise (2–4% opacity) over large flat areas to kill the "digital flat" look
- Borders with a highlight edge (`inset 0 1px 0` light line) on dark surfaces
- Intentional asymmetry and one oversized or off-grid element per screen
- Varied section rhythm (full-bleed, split, bento, quote) instead of repeating one block
- Specific, human copy and real-feeling sample data
