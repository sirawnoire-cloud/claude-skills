# Robustness — frequency, overfitting, and what "passed" has to mean

An EA that passes a backtest has not been shown to work. It has been shown to have produced good
numbers on one dataset, possibly by accident, possibly because the search that produced it was allowed
to keep going until something fit. This file is the set of gates that make the difference visible.

## The confluence collapse — do this arithmetic before writing code

Every hard condition multiplies against the others. If five conditions each pass on 40% of bars and are
roughly independent:

```
0.40^5 ≈ 0.010  →  1% of bars
```

On H1 gold, one year is roughly 6,000 bars. 1% is ~60 setups, and after direction and session filters,
far fewer actual trades. A win rate computed over eight trades is noise wearing a percentage sign.

This is why "add SMC and ICT and price action confluence" — which sounds like it should improve
quality — routinely produces an EA that takes almost no trades, or none at all. Nothing is broken; the
conditions just never align.

**So: estimate the frequency before spending a build cycle.** For each hard condition, state roughly
how often it holds, multiply them, multiply by bars in the test period, and show the user the expected
setup count. If the number is small, that is the moment to cut conditions — not after a compile, a
backtest, and three iterations.

## The confluence budget

- **Three or four hard gates, maximum.** A fifth needs a reason that can be said out loud, and the
  frequency estimate has to be redone with it included.
- **Prefer soft scoring to hard AND.** Score the conditions and trade above a threshold rather than
  requiring all of them. Frequency degrades gracefully instead of falling off a cliff, the threshold
  becomes a single tunable knob, and a near-miss setup is visible in the log rather than invisible.
- **Every condition must earn inclusion by measurement.** Add it, re-run, and see whether it improved
  expectancy — not just win rate. A condition that lifts win rate while cutting trade count in half has
  usually made things worse.

## Build in layers, never in one lump

When several concept families are wanted, build and test them in sequence:

1. **PA baseline alone.** Fully tested. This is the control.
2. **+ SMC core.** Test. Compare to the baseline.
3. **+ ICT extras.** Test. Compare again.

Each layer gets its own backtest, kept for comparison.

The reason is diagnostic, not procedural. Build everything at once and there are only two outcomes,
both uninformative: it performs badly and you don't know which layer is dragging, or it performs well
and you don't know whether the SMC and ICT layers contributed anything or the PA baseline is carrying
it alone. Layered, every addition has a measured before and after.

If a layer doesn't improve on the one below it, say so plainly and recommend dropping it. That is a
successful outcome of this process, not a failure of it.

## Pass criteria — beyond "the numbers look good"

All of these are gates. A run that misses one has not passed.

### Minimum trade count — a hard gate, not a note

**At least 30 trades in each test period**, tuning and holdout separately.

Below that, every statistic is dominated by noise: drawdown, win rate, and profit factor from a
20-trade sample tell you about those twenty trades and nothing about the strategy. Reporting them as
though they characterize the system is the most common way a backtest misleads.

Under 30 in either period → **fail**, and the finding is "too few trades to evaluate," not "poor
performance." The fix is loosening conditions (see the confluence budget), not retuning parameters.

If the holdout period has far fewer trades than the tuning period, that itself is a warning: the
conditions may have been shaped around the tuning period's specific conditions.

### Both periods, not just the tuned one

Already in the main skill: split the range, check both. Adding here — report the two periods'
statistics **side by side**, not merged. A merged number hides a holdout that was flat or negative.

### Parameter sensitivity — ±20%

Take every meaningful numeric parameter and re-run at +20% and −20%.

A strategy that only works at exactly the tuned values found a coincidence in the data. A robust one
degrades smoothly — worse at the edges, still recognizably the same strategy. If a 20% change collapses
results, the parameter is fitted to noise.

Report this as a small table: parameter, base result, −20%, +20%. It is often the single most
informative thing in the whole report, and it is cheap — a handful of extra runs.

### Costs must be explicit

Commission and swap values used, stated in the report. See `mechanics.md`. A test run at zero cost is
labelled as such, never presented as a plain result.

### Data length and quality must be stated

Real-tick history for XAUUSD typically goes back only a few years, and varies by broker.

- Report the **actual date range** and the tester's **modelling quality**.
- Testing a session- or structure-based strategy on less than about a year is not evaluation — regimes
  do not repeat inside a few months.
- If the available history is too short for the strategy type, say so before building, not after.

### Skipped trades must be reported

Trades the EA declined to take because the lot size floored below the broker minimum, or the stop was
inside the broker's stop level, are invisible in the standard report. Count them and report them
separately. "12 trades taken, 200 skipped for undersizing" describes a completely different situation
from "12 trades taken."

## Overfitting by search — why the iteration cap stays

`/loop-engineer` caps at 3 iterations, and this skill does not raise it.

An unbounded retune loop is a machine for producing overfitted strategies: keep adjusting until
something passes the holdout, and eventually something passes the holdout by chance. The holdout stops
being a test the moment it is used as a target often enough. A hard cap is what turns "keep grinding"
into "stop and involve a human," and for this task that friction is the safeguard, not an obstacle.

Note the cap applies to **strategy attempts**. Getting code to compile is inner-loop work inside a
single attempt, not an attempt of its own — see the main skill's criteria section.

## The three-way ambiguity — stop, don't guess

Indicator strategies fail in two ways: parameter-level and approach-level. Concept-based strategies add
a third, and it is not distinguishable from the other two by looking at the backtest:

- **Parameter-level** — right concept, right translation, wrong numbers.
- **Approach-level** — the concept doesn't fit the idea and no tuning will fix it.
- **Definition-level** — the concept fits, but the mechanical rule implemented isn't what the user
  meant. The FVG threshold, the order-block boundary, the sweep strictness.

A failing backtest looks identical in all three cases. Guessing wrong burns an iteration and, worse,
teaches the wrong lesson — retuning a definitional mismatch produces a strategy fitted to the wrong
concept.

**When it is genuinely ambiguous, stop the loop and ask.** Show the user the specific definition in
question, the alternative reading, and what each would change. Do not spend an iteration on a coin
flip: the user has three attempts, and one question costs none of them.
