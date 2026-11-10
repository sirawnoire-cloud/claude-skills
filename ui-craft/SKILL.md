---
name: ui-craft
description: >
  Design and build web UI that looks distinctive and feels alive — art-directed, fluidly responsive,
  animated with purpose — so the user never has to come back with "too stiff / not responsive enough /
  lifeless". Decides direction, palette, type, motion and responsive behavior itself, builds with those
  baselines in, then verifies in a real browser. Use when building or reworking any web page, screen,
  component or app UI: "make a page for X", "build the frontend", "looks plain/stiff/boring", "make it
  cool/modern/futuristic/beautiful", "make it responsive", "make it feel alive", "add animation/loading/
  empty states"; Thai: "สวย เท่ ล้ำ", "ทื่อ", "ไม่ responsive", "ไม่มีชีวิตชีวา". Also the rubric
  loop-engineer's LLM-judge uses for web UI tasks. NOT for Claude Artifact pages (artifact-design), NOT
  design mockups (design skill), NOT the charts themselves (dataviz), NOT backend/API/CLI work.
---

Build UI people remember using. Two ways in:

- **Directly** — the user is making or fixing a web UI. Run the flow below.
- **As loop-engineer's rubric** — the looped task is a web UI and its evaluator needs something real to
  judge against. Skip to "Serving as loop-engineer's judge" at the bottom.

## The brief the user never gives (read first)

People rarely say what they want from a UI until they've seen a flat version of it — then it arrives as
three rounds of corrections: *"it looks stiff"*, *"make it more responsive"*, *"it needs more life"*.
Those rounds are the failure this skill exists to prevent. Treat all of this as already requested, every
time, without being asked and without asking whether they want it:

1. **Distinctive** — it has a point of view you could describe in one sentence beyond "clean". Not a template.
2. **Responsive for real** — fluid at every width, orientation and input type (touch, mouse, keyboard),
   not just "the columns stack on mobile".
3. **Alive** — it reacts to the person, moves with purpose, and never reads as a static document.
4. **Still correct** — accessible, fast, every state designed (loading, empty, error, extreme content).

Boldness is a default, not a favor. A safe, flat, correct page is the thing that gets sent back.

## Phase 0 — Size the ask

Judge the scope first, so effort matches it:

- **A tweak** — one component, one property, an existing pattern. Make the change, honoring the
  baselines below for whatever it touches (a new button still gets hover/press/focus). No spec document.
- **A screen or a feature** — run the whole flow.
- **An app, or a rework with no system in place** — run the whole flow; the direction (Phase 3) is the
  bulk of the work and everything inherits from it.

When it's between a tweak and a screen, say which you picked in one line.

## Phase 1 — Detect the stack. Never ask.

Read it out of the repo:

```
package.json         → framework + UI libs + CSS approach
tailwind.config.*    → Tailwind, and whether a token layer already exists
components.json      → shadcn/ui
app/ vs pages/       → Next.js router flavor
*.module.css, styled-components, panda, vanilla-extract, plain CSS
```

Look at two or three existing components before writing anything and match their conventions (naming,
file layout, variants, `cn()`/`clsx`). State the stack you detected in one line.

**Greenfield:** don't quiz — pick. Default to plain CSS custom properties (+ Tailwind if the repo already
leans that way); name your pick and why in one line. Never make the user choose between names they
don't recognize.

**An existing design system wins on identity** — extend it, never fork a second one. But "be bold" still
applies *inside* it: add the missing states, motion, depth and responsive behavior through its tokens,
and if its look is flat, propose the upgrade as token changes in the same pass rather than leaving the
page lifeless.

## Phase 2 — Decide. Don't interview.

Every question is a round trip the user has to pay for. Infer, state the assumption, move on:

| Open point | How you decide it |
|---|---|
| Devices / primary device | From the product: dashboards, admin, dev tools → desktop-primary; consumer, content, commerce, anything people open from a link → mobile-primary; unsure → mobile-first. Always fluid across all of them. |
| Look & feel | Pick a direction from `references/directions.md` by product context. |
| Brand | Pull from the repo (logo, colors, existing site). None → you choose. |
| Light / dark | Ship both as token sets; lead with whichever suits the direction. |
| Language | Read it from the content. Thai → see the Thai notes in `references/theme.md`. |
| Density, copy, icons, imagery | Decide. Write specific, human copy — never lorem ipsum. |

Print the assumptions as a short list in the same message as the direction card (Phase 3). That makes a
wrong guess cheap to correct *after* the user sees something, which beats asking up front.

**Ask only when** (a) the request refers to brand assets or content that aren't in the repo, (b) the
choice is costly to reverse (auth flow, payments, data deletion), or (c) two readings of the request
would produce different products. One question, plain language, with your recommended answer in it.

## Phase 3 — Choose the direction, then write the spec

1. Read `references/directions.md`. Pick **one** direction for the product (at most one borrowed
   element from another). Name it, name its **signature move** (the one thing a person would remember
   and describe), and define motion personality.
2. Fill `templates/ui-spec.template.md` into `docs/ui-spec.md` (or beside the feature): direction,
   tokens with real values (`references/theme.md`), layout + fluid behavior (`references/responsive.md`),
   component inventory with every state, interaction map, liveliness plan (`references/motion.md`),
   content states.
   **If a spec already exists there, read it and extend it — never overwrite.** If new work clashes
   with it, name the clashing decisions and choose the extend path.
3. Post a **direction card** in chat — five lines: name · mood · palette + type · signature move ·
   assumptions. Then **build immediately.** Do not wait for approval; the user redirects after seeing a
   real thing. (Exception: the user asked to review the spec first.)

## Phase 4 — Build with the baselines on

These are not polish to add later — later doesn't come, and retrofitting means restructuring.

- **Token first, value never.** Every color, space, radius, shadow, duration and easing is a token. A
  hardcoded `#3b82f6` or `margin: 13px` is how a design system starts dying.
- **Responsive baseline** (`references/responsive.md`): fluid type and spacing via `clamp()`, intrinsic
  grids and container queries instead of breakpoint pileups, 44px touch targets, `dvh`, safe areas,
  input-modality aware (hover only where hover exists).
- **Liveliness baseline** (`references/motion.md`): entrance choreography, rich hover/press/focus on
  everything interactive, the direction's signature motion, at least two non-hover motions (scroll
  reveal, list enter/leave, tab indicator, count-up, ambient), skeleton loading, optimistic updates
  where safe. Transform/opacity only, `prefers-reduced-motion` honored.
- **States as you build the component:** default, hover, active, focus-visible, disabled, loading,
  empty, error (`references/interaction.md`).
- **Keyboard and semantics are part of the component:** real `<button>`/`<a>`, `:focus-visible`, sane
  tab order.
- **Structure before effects.** Hierarchy, spacing and type scale first; effects dress a sound layout,
  they don't rescue a broken one.

## Phase 5 — Pre-mortem, then prove it in a browser

**The three-complaints test** — before showing anything, answer these as the user would. Any "no" means
fix it now, not after they complain:

1. *Stiff?* Click, hover, tab through everything. Does each action answer visibly within ~100ms?
2. *Not responsive?* Look at 320, 390, 768, 1024, 1440, 1920 plus a landscape phone, and 200% text
   zoom. Does it feel designed at each, not merely not-broken?
3. *Lifeless?* Load it cold and move around. Does something move or react in the first second, on
   hover, and on scroll — and does it still look intentional with motion turned off?

**Look at it for real.** Start the dev server and run
`~/.claude/skills/ui-craft/scripts/preflight.sh <url-or-file>` — it opens the page in headless Chrome at
the six widths, writes screenshots, and reports horizontal overflow, small tap targets, interactive
elements with no transition, images without dimensions, tiny body text, squeezed text columns and how
much is animating. It scrolls the whole page first so scroll-reveals fire. Then **read the screenshots**
— open at least 390, 768 and 1440, and look specifically at the hero and the signature element: a card
squeezed into a too-narrow column, clipped text or a collapsed visual can pass most numeric checks and
still look broken. Every `warn` line is either fixed or explicitly justified. First run installs
`playwright-core` into `~/.cache/ui-craft` (no browser download; uses the installed Chrome). If it can't
run, say so plainly and mark responsive items "reasoned, not verified".

Then run `references/rubric.md` item by item and report honestly. Don't claim a pass on items you
didn't check.

## Failure modes — the wrong turns this task invites

**The generic AI look.** Purple-to-pink gradient on white, one default sans for everything, three
identical icon-in-a-circle cards, centered hero with two buttons, glass on everything. The blacklist is
in `references/directions.md` — if your output matches several, you shipped a template.

**Decorating instead of designing.** Gradients, glows and animation on a layout whose spacing and
hierarchy are wrong. If it looks cheap, the fix is spacing, alignment and type scale before another
effect.

**Too much of a good thing.** A signature move works because everything else is quiet. One memorable
idea executed perfectly beats six effects competing. Respect the budgets in `motion.md` (one ambient
layer, few blurs, one pointer effect).

**Motion that blocks or janks.** Entrances that make people wait, animating `width`/`top`, a looping
background burning battery off-screen. Motion earns its place by orienting, answering or delighting —
and never delays reading or interaction.

**Only the happy path.** Three perfect rows of data, then production has zero, four hundred, or a
failed request. Design all four.

**Hover-dependent meaning on a touch primary.** Hover may only *enhance*, never reveal.

**Contrast sacrificed for the aesthetic.** 4.5:1 for body text is a floor, and it applies on glass,
gradients and photos too.

**A second design system**, or ignoring an existing brand.

**Asking instead of deciding.** If the answer was inferable from the repo or the product type, a
question was a mistake.

**Claiming responsive without looking.** "It uses flexbox" is not evidence. Run the preflight.

## Serving as loop-engineer's judge

When `loop-engineer` runs a task whose criteria are a web UI, its LLM-judge needs something concrete or
it judges on vibes. Load `references/rubric.md`, judge item by item, and return pass/fail plus *which
items failed and where*. If a dev server is reachable, run `scripts/preflight.sh` and cite its numbers
as evidence for sections A and G. "Doesn't look good enough" is unusable feedback; "tap targets are 32px
on a mobile-primary layout, there is no entrance or scroll motion, and the hero is the default
indigo-gradient template" is.

Watch for the UI form of criteria-gaming: a screenshot that looks right while states, keyboard access,
small-width layout and reduced-motion behavior stay broken — and the inverse, effects bolted on to
satisfy section G while the structure is wrong. Judge the rubric, not the screenshot.
