# MQL5 mechanics — timing, timeframes, sessions, sizing

The traps here compile clean, backtest without complaint, and produce wrong results. That's what makes
them worth a reference file: none of them announce themselves.

## Close-based vs tick-based — two independent axes

These get conflated constantly. They are separate decisions and both have to be right.

### Axis 1 — when the EA decides

| Signal type | Timing | Why |
|---|---|---|
| Closed-candle patterns — pin bar, engulfing, inside bar, BOS/CHoCH confirmed by close | **close-based**: act once per new bar | The pattern does not exist until the bar closes. Evaluating mid-bar means acting on a candle that can still change shape — a look-ahead-flavoured bug that produces signals the live EA will never reproduce. |
| Price-level entries — limit at an FVG or order-block edge | **tick-based**, or a pending order | The level is known in advance; the fill is a price event, not a bar event. A pending order is usually better: the broker executes it, so latency and missed ticks stop mattering. |
| SL/TP management, trailing stops, break-even moves | **tick-based** | Managing an open position once a bar is management that arrives up to a full bar late. |

**SMC/ICT is a hybrid, and it should be built as one:** structure and bias evaluated on bar close;
entry and position management on ticks or pending orders. Say which parts are which in the explain-back
so the user sees the split.

New-bar detection idiom — do this once, at the top of `OnTick`:

```mql5
static datetime last_bar = 0;
datetime cur = iTime(_Symbol, InpSignalTF, 0);
bool new_bar = (cur != last_bar);
if (new_bar) last_bar = cur;
// structure/signal work guarded by new_bar; management runs every tick
```

Never use `OnTimer` for signal timing. It drifts relative to bars and is unreproducible in the tester.

### Axis 2 — how the backtest models ticks

**Always "Every tick based on real ticks."** This holds even when the EA's logic is entirely
close-based, and that combination is exactly where people cut the corner.

Reason: the *signal* fires on close, but whether **SL or TP was hit first inside a bar** depends on the
path price took through that bar. Lower-quality models (Open prices only, 1 minute OHLC) guess the
path. With a tight stop — every SMC entry at an FVG or OB edge — that guess is wrong often, and it
guesses in the optimistic direction. A strategy can look profitable purely because the tester assumed
TP was reached before SL in bars where the opposite happened.

So: `close-based logic + real ticks` is the normal correct combination. `close-based logic + OHLC
model` is the classic overstated backtest.

## Multi-timeframe without repainting

ICT is HTF-bias → LTF-entry by nature, so the EA needs at least two timeframes declared. Declare both
explicitly as inputs (`InpBiasTF`, `InpSignalTF`), and state them in the report.

**The repaint trap:** reading `iHigh(_Symbol, PERIOD_H4, 0)` gives the H4 bar *currently forming*. Its
values change until it closes. Any structure computed from bar 0 of a higher timeframe will produce
one answer live and a different answer on the next tick, and the tester will happily replay whatever
the code asked for. Backtests built this way look excellent and cannot be reproduced live.

**The rule: on any timeframe other than the one you're trading, only ever read closed bars — index 1
and higher.** A confirmed swing on the bias timeframe is confirmed only after `N` closed bars, and
that lag is real information, not something to engineer away.

Also: check `Bars(_Symbol, InpBiasTF)` is sufficient before computing anything, and handle the startup
period where it isn't. And confirm data for the bias timeframe actually exists in the tester —
`SERIES_SYNCHRONIZED` / a `CopyRates` return check — rather than assuming.

## Broker GMT offset — the silent killzone bug

Killzone hours are defined in exchange local time. Broker server time is typically GMT+2 or GMT+3 and
shifts with European DST. Hardcoding `if (hour >= 7 && hour < 10)` gives a window that is wrong by
hours, differently in summer and winter, and differently again on another broker.

**Never hardcode session hours against `TimeCurrent()`.** Resolve the offset at runtime:

- `TimeGMTOffset()` gives the local-terminal-to-GMT offset; `TimeCurrent()` is server time and
  `TimeGMT()` is GMT — derive the server↔GMT offset from these rather than assuming a constant.
- In the **tester**, GMT-related functions are limited. Verify what `TimeGMT()` and `TimeGMTOffset()
  ` actually return in a test run on the PC before trusting session logic. If they're unusable, fall
  back to an explicit `InpServerGmtOffset` input, default it from a live probe, and print the resolved
  session windows to the log on init so a wrong offset is visible immediately instead of silently
  shifting every trade.
- Handle US and EU daylight saving separately — they change on different dates, so the New-York-to-
  London gap is not constant.

**Verification step, not optional:** on the first backtest, log the server time of the first bar of
each killzone and eyeball that they land where expected. A killzone strategy running on the wrong
hours produces a plausible-looking equity curve for reasons that have nothing to do with the strategy.

## Position sizing — the lot-rounding bug that causes zero trades

Percent-risk sizing on gold with a tight stop can compute a lot size **below the broker's minimum**.
Rounded naively, that's `0.0` — and an order for 0 lots fails or is never sent. The EA then trades
nothing, reports nothing wrong, and looks like a strategy problem when it's an arithmetic one.

This is a leading cause of "the EA doesn't trade" that has nothing to do with the strategy or with
overfitting. Rule it out before diagnosing anything else.

Required handling on every size calculation:

```mql5
double vmin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
double vmax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

lots = MathFloor(lots / vstep) * vstep;       // never round up — that exceeds the risk budget
if (lots < vmin) { /* log WHY, then skip the trade */ }
if (lots > vmax) lots = vmax;                 // and log that risk was capped
```

- **Floor, never round.** Rounding up silently exceeds the risk the user specified.
- **When the size floors below minimum, log it explicitly** — "skipped: required 0.004 lots, broker
  minimum 0.01, would be 2.5x intended risk." Skipping silently is how this stays invisible for weeks.
- **Report how many trades were skipped for this reason** in the backtest summary. A strategy that
  "took 12 trades" but skipped 200 for undersizing is not the strategy that was tested.

Also verify SL distance against `SYMBOL_TRADE_STOPS_LEVEL` — a stop closer than the broker's minimum is
rejected at order-send time, again with no strategy-level symptom.

## Magic number — deterministic, not random

"Generated automatically" must mean **derived deterministically** — e.g. a hash of the EA name and
strategy variant — not randomized at compile or init time. A magic number that changes between runs
orphans open positions: the restarted EA cannot recognize its own trades, so it won't manage or close
them, and it may open duplicates alongside them.

Print the magic number on init. Two EAs on the same account with the same magic number will manage
each other's positions.

## News filter in the tester — verify before relying on it

The skill's news filter uses `CalendarValueHistory`. **Economic calendar data availability in the
Strategy Tester is limited**, and depending on terminal build and broker it may return nothing at all.
If so, the backtest runs as though the filter didn't exist — and then live behaviour differs from
everything that was tested.

Before accepting a news-filtered EA as tested:

1. On the PC, run a short backtest that logs how many calendar events the filter actually saw.
2. Zero events over a period that definitely contained NFP or CPI means the filter is inert in the
   tester.
3. If it's inert, either import a static high-impact event table for testing, or state clearly in the
   report that the news filter is **untested** — it exists in the code but no backtest exercised it.

Never report a news-filtered EA as validated when the filter never ran.

## Costs the tester will not add for you

Real ticks carry real spread. They do **not** carry commission or swap — those are tester/broker
settings, and the defaults are frequently zero.

- **Commission** must be set to the broker's actual per-lot charge. On a high-frequency tight-stop
  strategy this can be the difference between profitable and not.
- **Swap** matters for anything holding overnight. Gold swap is often materially negative.
- State both values used in the report. A backtest that didn't specify them was run at zero cost, and
  should be labelled that way rather than presented as a result.

## Dashboard cost in the tester

Chart-object updates on every tick slow a real-tick backtest substantially — enough to make a long test
impractical. Guard dashboard drawing with `if (!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger
(MQL_VISUAL_MODE))`, or throttle it to once per bar. The dashboard is for live use; it should not be
paying for itself during every optimization pass.
