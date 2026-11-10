# UI rubric

The pass/fail checklist. Two users: `ui-craft`'s own Phase 5 self-check, and `loop-engineer`'s
LLM-judge when the looped task is a web UI.

**How to use it:** go item by item and record pass / fail / not-applicable. Do not skim it and form an
overall impression — the impression is exactly what this replaces. For every fail, say *what* fails and
*where*, so the next iteration has something to act on. "Looks unpolished" is not a finding; "the
submit button has no loading state, so a slow save looks like nothing happened" is.

**Evidence:** run `scripts/preflight.sh <url>` when a page is reachable and cite its numbers for A and G
(overflow, tap targets, transitions, animation counts). Mark honestly what you verified by looking at the
running page versus what you reasoned about from the code. Blurring the two is how a fake pass happens.

## A. Blockers — any single fail is a fail overall

1. **No horizontal overflow** at 320, 390 and the primary width (and none at 200% text zoom).
2. **Body text contrast ≥ 4.5:1**, and UI/large text ≥ 3:1 — including over glass, gradients and
   images. Compute it; don't eyeball it.
3. **Tap targets ≥ 44×44px** on any touch layout, with ~8px between adjacent targets.
4. **Keyboard reaches every interactive element**, in a sensible order, with a visible `:focus-visible`
   style. No `outline: none` without a replacement.
5. **Real semantic elements** — `<button>` for actions, `<a href>` for navigation. Not a `div` with an
   onClick.
6. **Every async action shows it's working** — the control that triggered it enters a loading state and
   can't be double-fired.
7. **No content is unreachable on the smallest supported width.** Reorganized is fine; missing is not.
8. **Reduced motion is honored and nothing is left invisible** — with `prefers-reduced-motion: reduce`,
   animations stop and no content is stuck at `opacity: 0`.

## B. The design system is coherent

9. **Every color, space, radius, shadow, duration and easing comes from a token.** Zero raw hex values
   or arbitrary px in components.
10. **One spacing scale**, used everywhere. No stray off-scale values.
11. **A defined type system** — one fluid scale, at most two families (display + text) and about four
    weights, body ≥ 16px.
12. **Radius is a small named set** applied consistently per component type — not arbitrary values.
13. **Depth follows one recipe** (hairline, layered shadow, glass, hard offset, or background step) defined
    as tokens and applied consistently — not three mechanisms mixed by accident.
14. **Accent is a system with intent** (primary, optional secondary/gradient, all tokens). The most
    important action on each screen is clearly the most prominent thing.
15. **Dark mode, if present, is a separate palette** — not an inversion — and every token has a value in
    both. No color defined only inside a media query.

## C. States are complete

16. For every interactive element: **default, hover, active/pressed, focus-visible, disabled, loading**
    — each present and visually distinct. Active state especially; it's the most-skipped.
17. **Every list/collection has an empty state** that says what goes here and offers the action that
    fills it — and distinguishes never-had-data from filtered-to-nothing from failed-to-load.
18. **Every fetch has an error state** with a retry path.
19. **Layouts survive extremes** — one item and many items, short text and long text, a very long
    unbroken string.
20. **Disabled controls explain themselves** — or the control isn't disabled.

## D. It responds to the person

21. **Interactive elements transition** at ~90–200ms (press can be instant on the way in). Not instant
    on hover (reads broken), not >300ms (reads slow).
22. **Motion has a job** — feedback, orientation, continuity or bounded delight. It never delays reading
    or interaction (entrance ≤ ~650ms total, controls usable at t = 0) and entrances play once.
23. **Feedback for every action.** Nothing a user does leaves the screen unchanged.
24. **Errors appear next to their cause**, phrased as what to do rather than what went wrong.
25. **No layout shift when content loads** — space is reserved via skeletons, fixed heights, or aspect
    ratios.
26. **Destructive actions confirm**, with the verb on the confirm button.

## E. It fits the codebase

27. **Matches existing components' conventions** — naming, file layout, how variants are expressed.
28. **Extends the existing design system** rather than introducing a second one (bold *within* it).
29. **No new dependency** added for something the stack already does.

## F. Craft

30. **Alignment is exact.** No 2px drift.
31. **Spacing encodes relationship** — related things close, unrelated things far. Not everything
    evenly spaced.
32. **Density suits the direction** — generous where the direction is airy; dense on purpose where it's
    Terminal/Dashboard. Cramped-by-accident reads as unfinished.
33. **Hierarchy survives grayscale** — built from size, weight and contrast (squint test), not only from
    color.
34. **Line length capped at ~65–75 characters**; heading line-height ~1.05–1.25, body ~1.5–1.6
    (Thai body ≥ 1.6–1.7).

## G. Distinctive and alive — the "nobody had to ask" section

35. **A named direction** (in the spec/direction card) that the page visibly follows. A reviewer could
    describe it in one sentence beyond "clean".
36. **One signature move**, implemented and smooth, tokenized — the thing a person would remember — and
    it renders correctly (no squeezed, clipped or collapsed pieces) in screenshots at ≥ 3 widths.
37. **Typography has personality** — a deliberate display/text pairing (or a single family with real range
    for Quiet Precision) and a hero at roughly ≥ 3× body. Not default-system-sans everywhere.
38. **No AI-default template.** Check the blacklist in `directions.md`; list any that match. Three or
    more matches is a fail of this item.
39. **Entrance choreography exists**, finishes within ~650ms, and never blocks interaction.
40. **Interaction feedback is rich and on-brand** — hover, press and focus are distinct and carry the
    direction, not just a color change.
41. **At least two non-hover motions beyond the entrance** — scroll reveal, list enter/leave, tab
    indicator, expand/collapse, count-up, chart draw, or one ambient layer.
42. **Motion is cheap** — only `transform`/`opacity`/`filter` animated; no layout-property animation;
    ambient loops pause off-screen and vanish under reduced motion; ≤ 3 backdrop blurs in view.
43. **Fluid, not just stacked** — type and spacing use `clamp()`/a fluid scale; components use container
    queries or intrinsic grids; verified at the preflight widths (cite the output).
44. **Responds to the person's setup** — light/dark via tokens, fine vs coarse pointer (hover effects
    gated), reduced motion, and the content's script (e.g. Thai fonts and leading) checked.
45. **Rhythm varies** — sections aren't one block repeated; imagery, scale and layout change down the
    page.

## Scoring

- Any **A** fail → **fail**, regardless of everything else.
- More than two fails in **B** or **C** → **fail**. The system or the states aren't real yet.
- Three or more fails in **G** → **fail** ("generic or lifeless"), even if everything else passes.
  Items 35 and 36 failing together is already a strong sign of a template.
- **D**/**E**/**F** fails → report them individually; a handful of small ones is a pass with notes, but
  a cluster in **F** usually means the layout structure needs work rather than more polish.

## Anti-gaming

Watch for a screenshot that looks right over an implementation that isn't — and for effects added to
satisfy G over a broken structure:

- States left unbuilt because the default state photographs fine
- Contrast "checked" by looking rather than computing
- A mobile layout reasoned about but never actually viewed at a small width (preflight not run)
- Accessibility or reduced-motion deferred to "a later pass"
- Motion bolted on (a spinning logo, gratuitous parallax) to tick item 41 while hierarchy and spacing
  are weak
- Glass/gradients added for item 35 with text that no longer clears contrast
- The rubric narrowed mid-loop so a partial fix counts as a pass

Any of these is a fail even if the page looks good, and say so plainly in the report.
