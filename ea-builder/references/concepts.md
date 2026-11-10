# Concept definitions — PA, SMC, ICT, volume

Load this only when the chosen style involves price action, Smart Money Concepts, or ICT material.
A moving-average EA does not need any of it.

## Why this file exists

Indicator strategies have no definitional ambiguity: a 20-period EMA is a formula, and everyone's
20 EMA is the same number. SMC/ICT concepts are the opposite — they are defined by *pattern
recognition on a chart*, the source material is video-based and inconsistent, and two experienced
traders mark different order blocks on the same candles.

That creates a failure mode indicator strategies don't have: **the code can implement a plausible
definition that isn't the one the user meant, compile clean, backtest, and produce numbers nobody can
interpret.** Worse, when the backtest fails you can't tell whether the concept is wrong, the
parameters are wrong, or the *translation* is wrong.

So this file fixes exactly one mechanical definition per concept. Not because it's the only valid one,
but because a written, auditable choice is the only thing that makes iteration meaningful. Every
definition below carries the ambiguity it's resolving, so the user can disagree with the specific
choice rather than with a black box.

**Always show the user the "on the chart" line and the mechanical rule together, and get confirmation
before writing MQL5.** If the user has never marked these by hand, they cannot validate a rule stated
in code terms — they can only validate a picture plus a sentence.

---

# Part 1 — Price Action

Lowest definitional risk. These have reasonably standard mechanical forms, so translation error is
small. Build these first as a baseline (see `robustness.md`).

## Pin bar / rejection candle

**On the chart:** a candle with a long tail on one side and a small body at the other end. Price pushed
one way and got shoved back.

**Mechanical rule:** with `range = high - low`, `body = |close - open|`:
- bullish: `lower_wick >= 2 * body` AND `lower_wick >= 0.6 * range` AND `close` in the upper 35% of range
- bearish: mirrored

**Ambiguity resolved:** wick-to-body ratios in the wild run 2:1 to 3:1. Taking 2:1 plus a
close-position filter, because ratio alone admits candles that closed mid-range and aren't rejections.

**MQL5:** evaluate on the **closed** bar only (`shift = 1`). A pin bar is not a pin bar until the
candle closes.

## Engulfing

**On the chart:** one candle's body completely swallows the previous candle's body, in the opposite
direction.

**Mechanical rule:** bullish — `close[1] > open[2]` AND `open[1] < close[2]` AND candle 2 was bearish
AND candle 1 is bullish. Require `body[1] >= 1.2 * body[2]` so a marginal overlap doesn't count.

**Ambiguity resolved:** body-engulfing, not full range-engulfing. Range-engulfing is much rarer and
would collapse trade frequency on its own.

## Inside bar

**Mechanical rule:** `high[1] < high[2]` AND `low[1] > low[2]`. A compression signal, not a direction
signal — pair it with the breakout direction of the mother bar.

## Break of structure (swing-based)

**On the chart:** price closes past the most recent significant high or low.

**Mechanical rule:** fractal swing points with lookback `N` (default 3): a swing high is a bar whose
high exceeds the `N` highs on both sides. A bullish BOS is a **close** above the last confirmed swing
high.

**Ambiguity resolved:** confirmation by **close**, not by wick. Wick-based breaks fire on every
liquidity spike and are the single largest source of false signals here. Also: swings are only
confirmed `N` bars after they form — accept that lag, don't try to detect them live (see the repaint
warning in `mechanics.md`).

## Support/resistance zone

**Mechanical rule:** cluster confirmed swing points within `tolerance = k * ATR(14)` (default k=0.5)
of each other; a zone needs at least 2 touches to exist. Zone bounds are the min/max of its members.

**Ambiguity resolved:** ATR-relative tolerance rather than fixed pips, so the same rule works when
gold's volatility regime changes. A fixed-pip tolerance tuned in a quiet month breaks in a violent one.

---

# Part 2 — SMC core

Moderate definitional risk. These four have workable mechanical forms; the rest of the SMC vocabulary
mostly reduces to combinations of them.

## Market structure — BOS and CHoCH

**On the chart:** an uptrend makes higher highs and higher lows. A BOS continues it; a CHoCH is the
first break that says the trend flipped.

**Mechanical rule:** track confirmed swing highs/lows (fractal, as in BOS above) and hold a state
machine with `trend ∈ {up, down, none}`.
- In `up`: a close above the last swing high = **BOS** (continuation). A close below the last *higher
  low* = **CHoCH** (flip to `down`).
- In `down`: mirrored.
- `none` at start; the first confirmed BOS sets the trend.

**Ambiguity resolved:** CHoCH triggers on breaking the last **protected** swing (the higher low that
produced the most recent BOS), not any minor low. Using any low makes CHoCH fire constantly and the
state machine flaps.

**MQL5:** this state machine is the backbone — build and log it first. If the structure state is wrong,
every downstream concept is wrong, and it's the single most valuable thing to print to the dashboard.

## Order block

**On the chart:** the last opposite-direction candle before the move that broke structure. The idea is
that unfilled orders sit there.

**Mechanical rule:** on a bullish BOS, walk back from the breaking candle to the **last bearish candle**
before the impulse; the order block is that candle's `open`→`low` range (body-to-low). Mirrored for
bearish. Mark it valid until price closes fully through it, then discard.

**Ambiguity resolved — this is the big one.** Competing definitions: whole candle range vs body only vs
body-to-wick; last opposite candle vs the highest-volume candle in the leg; requiring the impulse to
leave an imbalance or not. Taking **body-to-extreme of the last opposite candle before a
structure-breaking impulse**, because it's the most commonly taught form and it's unambiguous to code.

State this choice to the user explicitly — it is the most likely place their mental model differs.

## Fair value gap / imbalance

**On the chart:** a three-candle pattern where the middle candle moves so fast it leaves a price band
that wasn't traded through properly.

**Mechanical rule:** bullish FVG when `low[i] > high[i+2]` — the gap is the band `high[i+2] → low[i]`.
Bearish mirrored. Fill state: track how far price has retraced into it; treat >50% penetration as
mitigated, full penetration as consumed and discarded.

**Ambiguity resolved:** the strict three-candle no-overlap form, not the looser "big candle" version.
The 50% mitigation threshold is a choice — say so, since some material treats any touch as mitigation.

## Liquidity sweep / stop run

**On the chart:** price pokes just past an obvious high or low, triggers stops, and immediately
reverses.

**Mechanical rule:** a bar whose **wick** exceeds a confirmed swing point by up to `0.5 * ATR(14)` but
whose **close** returns back inside, followed within `M` bars (default 3) by a CHoCH in the opposite
direction.

**Ambiguity resolved:** requires close-back-inside *and* a following structure shift. Wick-beyond alone
happens constantly and is not a sweep — it's just a wick. This is deliberately strict; loosen it only
if trade frequency collapses (see `robustness.md`).

---

# Part 3 — ICT extras

Highest definitional risk, and the most parameter-heavy. Every item here needs the broker GMT-offset
handling in `mechanics.md` — killzones defined in wall-clock hours are silently wrong otherwise.

## Killzones / sessions

**Mechanical rule:** windows in **exchange local time**, converted to broker server time at runtime,
never hardcoded:
- London: 02:00–05:00 New York time
- New York AM: 07:00–10:00 New York time
- London close: 10:00–12:00 New York time
- Asia range: 20:00–00:00 New York time (used as a range, not an entry window)

**Ambiguity resolved:** anchoring to New York time and handling US/EU daylight-saving separately,
because broker server time is typically GMT+2/+3 and shifts with EU DST — a hardcoded hour drifts by
an hour twice a year and by several hours permanently if the broker changes.

## Premium / discount

**Mechanical rule:** take the current structural leg (last confirmed swing low → swing high in an
uptrend). Above the 50% level is premium, below is discount. Longs only in discount, shorts only in
premium. The "optimal trade entry" band is the 62–79% retracement of the leg.

**Ambiguity resolved:** measured on the **current structural leg**, not a fixed lookback window. A
fixed window puts the 50% line in an arbitrary place whenever a new leg forms.

## Breaker block

**Mechanical rule:** an order block that price traded fully through, then returned to from the other
side. Implement as a state transition on the existing order-block objects (`valid → failed → breaker`),
not as a separate detector — a separate detector duplicates the OB logic and the two drift apart.

## Mitigation block

**Mechanical rule:** the last opposite candle before a move that broke a *swing point but not
structure* (no BOS). Mechanically identical to an order block with a weaker trigger condition. Flag it
distinctly so the backtest can show whether it contributes anything — it usually adds trades and
lowers quality, and you want that visible rather than blended in.

## Judas swing

**Mechanical rule:** within the first hour of a killzone, a move beyond the Asia-session range that
closes back inside, followed by a CHoCH in the opposite direction. It is a liquidity sweep with a
session-time and range constraint — implement it on top of the sweep detector, not as new logic.

**Note on frequency:** this is a session-constrained pattern requiring three conditions in sequence. It
will be rare. Estimate its frequency before building it (see `robustness.md`) — this concept in
particular has a habit of producing a beautiful backtest containing six trades.

---

# Part 4 — Volume profile: read this before agreeing to build it

**MT5 on a retail gold CFD does not have real volume.**

- `tick_volume` = the number of price changes within the bar. Not contracts, not lots, not money.
- `real_volume` requires an exchange feed. For XAUUSD spot CFD from a retail broker it is normally 0
  or absent. Verify on the actual PC before building anything that depends on it — if it's 0, any
  `real_volume` logic silently evaluates to nothing.

So a volume profile / POC / VAH / VAL built here rests on a **proxy for activity**, not on traded
volume. That matters because the usual reason to want volume in an SMC context — "see what
institutions did" — is exactly the claim the proxy cannot support.

**What tick_volume is legitimately good for:**
- comparing activity between sessions or killzones
- filtering out abnormally quiet bars
- confirming that a sweep or impulse happened on elevated activity rather than in a dead hour

**What it cannot support:** any claim about institutional participation, absorption, or delta.

**If the user wants it anyway** (a reasonable choice — the activity proxy has real uses): build it on
`tick_volume`, name the inputs so the proxy is visible (`InpUseTickVolumeProxy`, not
`InpUseVolume`), and carry an explicit line in the final report saying the profile is built on tick
count, not traded volume. Do not let it appear in the dashboard as plain "Volume."

Real gold volume lives in GC futures — a different instrument, a different data source, and not
available inside an MT5 XAUUSD backtest. Say that plainly rather than approximating it and hoping.
