# UI spec — <feature or app name>

> Written before implementation, then built immediately (no approval gate). Deciding once, up front, is
> what makes screen five match screen one. Fill every section; "N/A" with a reason is valid, silence is not.

## 0. Context and assumptions

- **Stack detected:** <framework, styling approach, component library — read from the repo>
- **Existing design system:** <token file / theme config / component lib, or "none — greenfield">
- **Primary device (inferred):** <mobile | tablet | desktop> — <why: product type / how it's opened>
- **Also designed for:** <the others — always fluid across all>
- **Brand input:** <logo, brand colors, existing site — or "none, chosen here">
- **Language / script:** <e.g. Thai + English — fonts and line-height checked>
- **Other assumptions made instead of asking:** <list — cheap for the user to correct>

## 1. Direction

- **Name:** <from directions.md, e.g. Aurora Glass> (borrowed element, max one: <or none>)
- **Mood in one sentence:** <>
- **Signature move:** <the one memorable thing — and where it appears>
- **Motion personality:** <durations / easing family: snappy | smooth | springy | cinematic>
- **Why this direction for this product:** <one line>
- **AI-default patterns deliberately avoided:** <which of the blacklist were tempting>

## 2. Tokens

Real values, not adjectives.

### Color (OKLCH)
| Token | Light | Dark | Used for |
|---|---|---|---|
| `--bg` | | | page background |
| `--surface` | | | cards, panels |
| `--border` | | | dividers, outlines |
| `--text` | | | body text |
| `--text-muted` | | | secondary — must clear 4.5:1 |
| `--accent` / `--accent-2` | | | primary / secondary emphasis |
| `--gradient-brand` | | | the brand gradient, if any |
| `--accent-fg` | | | text on accent |
| `--danger` / `--success` | | | semantic |

Contrast checked (computed): body <ratio> · muted <ratio> · accent-fg on accent <ratio> · text over glass/gradient (worst case) <ratio>

### Type
Display: <family> · Text: <family> · Mono (if any): <> · Thai-capable fallback: <>
Fluid scale: <--step--1 … --step-6 clamp() values> · Weights: <>
Line-height: body <> (Thai <>) · headings <> · Measure cap: <ch>

### Spacing / radius / depth
Spacing scale: <4/8/12/16/24/32/48/64/96/128> · Section padding: <clamp()>
Radius set: <--r-sm / --r-md / --r-lg / --r-pill values> · Depth recipe: <hairline | layered shadow | glass | hard offset | bg-step> · Shadow tokens: <>

### Motion
`--dur-instant` <> · `--dur-fast` <> · `--dur-base` <> · `--dur-slow` <> · `--dur-hero` <>
`--ease-out` <> · `--ease-in-out` <> · `--ease-spring` <>

**Where these live:** <file path>

## 3. Layout and fluid behavior

Page skeleton at the primary width:
```
<ascii sketch>
```
Intrinsic / fluid parts (no media query): <grids, clamp() type, container queries>
Layout shape changes (media queries): <e.g. sidebar → drawer at <1024>>

### Responsive matrix (look at each in preflight)
| Width | Layout / what changes | Special concern |
|---|---|---|
| 320 | | smallest, zoom |
| 390 | | typical phone |
| 768 | | tablet portrait |
| 1024 | | tablet landscape / laptop |
| 1440 | | desktop |
| 1920 | | max-width cap |
| 844×390 | | landscape phone |
| 200% zoom | | reflow |

## 4. Components — every state

| Component | default | hover | active | focus-visible | disabled | loading | empty | error |
|---|---|---|---|---|---|---|---|---|
| | | | | | | | | |

## 5. Liveliness plan

| # | Piece | This product's version |
|---|---|---|
| L1 | Entrance choreography | <what staggers in, total ms> |
| L2 | Interactive feedback | <hover / press / focus personality> |
| L3 | Signature motion | <> |
| L4 | Two+ non-hover motions | <scroll reveal / list enter-leave / indicator / count-up / ambient …> |
| L5 | Loading | <skeletons, optimistic updates where safe> |
| L6 | Continuity | <view transition / shared element, or "none — why"> |
| L7 | Reduced-motion behavior | <what each piece degrades to> |

## 6. Interaction map

| User action | Immediate response | Then | On failure |
|---|---|---|---|
| | | | |

Optimistic updates: <which actions, and the revert behavior>

## 7. Content states

| Screen/region | No data | One item | Many items | Load failed |
|---|---|---|---|---|
| | | | | |

## 8. Deliberately out of scope

<what this spec is not covering, and why — so the gap is a decision, not an oversight>
