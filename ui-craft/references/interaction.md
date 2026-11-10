# Making it not stiff

"Stiff" has a specific cause: the interface does not visibly react to the person using it. Every click
that produces no immediate change, every wait with no indication, every hover with no acknowledgement
adds up to something that feels dead — even when it's fast and correct.

The fix starts with **feedback**: the interface answering every action. Make the feedback *on-brand*
(carry the direction's motion personality from `motion.md`) rather than a generic color swap — that's the
difference between "responds" and "alive". This is always built in; the user should never have to ask
for it.

## The state ladder — build all of it, or it feels unfinished

For every interactive element:

| State | What it's for | Cost of skipping |
|---|---|---|
| **default** | resting | — |
| **hover** | "this is clickable" | on desktop, nothing looks interactive |
| **active / pressed** | "your click landed" | the biggest single contributor to feeling dead |
| **focus-visible** | keyboard position | the app is unusable by keyboard |
| **disabled** | "not now" — and ideally *why* | users click and nothing happens, with no explanation |
| **loading** | "working on it" | double submits, and the app feels broken on slow networks |

**Active state matters more than hover** and gets skipped more often. The press is the moment the
person is asking "did that work?" Answer it: a 1px translate, a slight scale-down, a shade darker.
Instant, no transition on the way in.

**`:focus-visible`, not `:focus`.** `:focus` puts rings on mouse clicks too, which is why people delete
focus styles entirely and break keyboard access. `:focus-visible` shows the ring only when it's needed.
Never `outline: none` without a replacement.

## Loading: match the wait

| Wait | Do |
|---|---|
| < 300ms | nothing — a flashing spinner is worse than no spinner |
| 300ms – 1s | inline spinner, or disable the control |
| 1s – 3s | skeleton matching the real layout |
| > 3s | progress, and say what's happening |

**Skeletons beat spinners** for content areas: they hold the layout so nothing jumps when data lands.
Match the real shape — a skeleton whose proportions differ from the content causes a visible snap.

**Buttons that trigger work must show it themselves.** Spinner inside the button, label swapped or
kept, button disabled. A global overlay for a single button action is heavy-handed and hides what's
happening.

**Reserve the space.** Layout shift when content loads is the most jarring thing an interface does.
Fixed-height containers, aspect ratios on images, skeletons the size of the real thing.

## Optimistic updates — where "instant" actually comes from

For actions that almost always succeed (toggle a like, check a checkbox, rename something), update the
UI immediately and reconcile with the server after. If it fails, revert and say so.

This is the single biggest perceived-speed win available, and it costs one error path. Don't use it for
anything destructive or expensive — deleting, paying, submitting — where a silent revert would be
worse than a wait.

## Transitions: what to animate

The full system (tokens, entrance choreography, scroll reveals, view transitions, performance budget)
lives in `motion.md`. The rules that belong here, at the interaction level:

**Animate:** color/background/transform on hover and press, opacity for appear/disappear, transform for
movement, expand/collapse (via `grid-template-rows`, not `height`), elements entering or leaving a list,
and a bounded entrance choreography on first view.

**Don't let motion cost the person time.** Entrances finish within ~650ms and never gate a control —
everything is usable at t = 0. Whole-page transitions must not add latency to navigation (use view
transitions that run *while* content loads, not before). Nothing the person has to wait through more
than once.

The test: does the motion do a job — **answer** an action, **orient** to what changed, **connect** two
states, or **delight** inside a budget? An item sliding out shows it was removed; a card lifting on
hover shows it's grabbable; a staggered first-view entrance gives the page a pulse and a reading order.
Motion that does none of those is decoration; remove it.

**Stagger with a cap.** 40–60ms between items for the first ~8; group the rest. On twenty rows a full
stagger is a wait.

**Always:**
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: .01ms !important;
    transition-duration: .01ms !important;
  }
}
```

## Telling the user what happened

Every action needs a visible outcome. If nothing on screen changes, the person assumes it failed and
does it again.

- **Inline beats toast** when the result has a location — a saved field turning green, a row updating.
  Toasts are for things with no home on screen.
- **Errors go next to the cause**, not in a banner at the top. A form error at the top of a long form
  makes the user hunt.
- **Say what to do, not what went wrong.** "Enter an email address" beats "Invalid input."
- **Validate at the right time**: on blur for the first pass, then live once a field has errored. Live
  validation from the first keystroke means telling someone their email is invalid while they type it.
- **Destructive actions confirm**, and the confirm button says the verb ("Delete project"), not "OK".

## Empty states — the most-skipped screen

An empty list showing nothing reads as broken. An empty state should say what goes here, why it's
empty, and offer the action that fills it. It's often a user's first screen — treat it as an
opportunity, not an error.

Distinguish three cases, they need different words: **never had data**, **filtered to nothing** (offer
to clear the filter), and **failed to load** (offer retry).

## Touch has no hover

If mobile is primary, hover may only enhance — never reveal. Any control that appears on hover must be
permanently visible on touch. Also: no hover-triggered tooltips carrying required information.

Touch also has no precision. See `responsive.md` for target sizes.
