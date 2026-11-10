---
name: ea-builder
description: Build a MetaTrader 5 Expert Advisor (EA) for gold (XAUUSD) from a plain-language trading idea — no trading jargon or MQL5 knowledge required from the user. Compiles and backtests against a real MT5 install on a separate PC. Manual invoke only — use /ea-builder.
disable-model-invocation: true
---

Personal-use skill. Invoke as:

```
/ea-builder <plain-language trading idea, or blank to use the current conversation's idea>
```

## Gather requirements (ask, don't assume)

Ask these before writing any code — one at a time, plain language, no jargon in the question itself:

1. **Trade style** — offer Scalping, Day Trading, Swing/Trend Following, Range/Mean Reversion, each described in plain language, and combinable (e.g. Scalping + Trend Following = a trend filter gates fast entries). If the user says "High Frequency Trading," clarify first: true HFT needs co-located servers retail MT5 can't provide — what they likely mean is very-frequent scalping.
   - Name the environment each style needs: Scalping wants low spread and a stable, low-latency connection (ideally a VPS near the broker's server); Day Trading is fine on a normal retail setup; Swing/Trend is the least demanding. If the user's setup doesn't match and they want to proceed anyway, build it — but the final report must carry an explicit "results may be worse live than backtested because your environment doesn't match this style" disclaimer.
   - **Concept-based styles** — Price Action, Smart Money Concepts, ICT — are also on offer, but they
     are not the same kind of thing as the four above and shouldn't be presented as if they were. PA
     has fairly standard mechanical definitions and codes cleanly. SMC and ICT are defined by visual
     pattern recognition, the source material disagrees with itself, and turning them into code means
     *choosing* a definition. Say this before the user picks, and read `references/concepts.md` the
     moment any of the three is chosen.
   - **Volume** — if the user asks for volume profile or volume confirmation, read the volume section
     of `references/concepts.md` before agreeing. Retail XAUUSD has no real volume in MT5; anything
     built here rests on a tick-count proxy, and the user needs to know that before it's built, not in
     the final report.
2. **News filter** — recommend yes for most styles (pauses new entries around high-impact USD news using MQL5's real `CalendarValueHistory` API), but ask rather than force — a style built to trade the news itself would want it off.
3. **Account balance and leverage** — needed to size positions as percent-risk-per-trade, not a guessed fixed lot.
4. **On-chart dashboard** — optional. If yes, it shows: EA on/off + running strategy, any open position (direction, size, live P/L), Daily/Weekly/Monthly P/L, trade count so far, and the reason for the EA's last action. Style it clearly — green/red for profit/loss, grouped sections, readable labels — but it's still MQL5 chart-object code, so it goes through the same compile loop as everything else; it doesn't get a pass on correctness just for being "only UI."

## Explain the logic back before writing code

Once the idea and the answers above are in hand, summarize in plain language before touching MQL5: which indicator(s) and their actual parameter values ("two moving averages, set to 20 and 50" — not just "moving averages"), how entries trigger, how exits trigger, and — if styles were combined — how the layers interact (which one filters, which one triggers). Let the user confirm this matches what they pictured before spending a compile/backtest cycle on it.

## Lock the definitions before writing code (concept-based styles only)

Skip this entirely for indicator strategies — a 20-period EMA needs no agreement about what it is.

For PA, SMC, or ICT, the explain-back above is not enough. "Enter at the order block" sounds like a
shared understanding and isn't: there are several incompatible definitions of an order block in common
use, and the code has to pick one. Picking silently is how a build produces numbers nobody can
interpret.

So, for every concept in the strategy, pull the definition from `references/concepts.md` and show the
user two things together:

1. **What it looks like on the chart**, in plain language — the picture, not the formula.
2. **The exact mechanical rule** that will be coded, including the specific thresholds.

Then say which competing definition was rejected and why, because that is the part the user can
actually disagree with.

If the user has never marked these by hand, they cannot validate a rule stated in code terms — only a
picture plus a sentence. Write it for someone who has read about SMC but never drawn an order block.

Get explicit confirmation before writing MQL5. A wrong definition caught here costs a paragraph; caught
after a compile and a real-tick backtest it costs an iteration, and there are only three.

## Estimate the trade frequency before writing code

Stacking conditions multiplies against frequency. Five hard gates that each hold 40% of the time align
on about 1% of bars — a handful of trades a year on H1, from which no statistic means anything.

Before building, state: each hard condition's rough hit rate, the product, and the expected setup count
over the intended test period. Show the user that number.

If it's under ~30 setups per test period, recommend cutting conditions now. Read
`references/robustness.md` for the confluence budget and the soft-scoring alternative to hard AND. This
is the cheapest possible moment to find out the strategy will barely trade — after a compile and a
backtest, the same discovery costs an iteration.

If the user wants it built as specified anyway, build it — same as with an environment mismatch, the
call is theirs. But record the predicted setup count first, and when the backtest then fails the
minimum-trade-count gate, report it as **the predicted outcome, not a strategy failure**: the
conditions were too restrictive, exactly as estimated, and no amount of retuning addresses that. Do not
spend iterations retuning a strategy that failed for a reason known before the first build.

## Always-on defaults (never ask, never skip)

- Stop-loss and take-profit on every position.
- Position sizing as percent-risk-of-balance, using the balance/leverage gathered above — never an arbitrary fixed lot.
- A unique magic number per EA, generated automatically, so multiple EAs or charts never collide.
- Never hardcode the symbol string ("XAUUSD") — read it from the chart via `_Symbol`/`Symbol()`, since brokers name gold differently.
- Never hardcode digit/point assumptions in SL/TP math — use `_Digits`/`_Point`, since brokers quote gold at different decimal precision.
- Declare the timeframe(s) the EA is designed for explicitly in code, and state them plainly in the report — don't rely on whatever chart the user happens to drop it on. Multi-timeframe strategies (all of ICT, most SMC) declare both a bias timeframe and a signal timeframe as separate inputs, and read **only closed bars** on the bias timeframe — bar 0 of a higher timeframe repaints, and a backtest built on it cannot be reproduced live. See `references/mechanics.md`.
- Never hardcode session or killzone hours against server time. Resolve the broker's GMT offset at runtime, handle US and EU daylight saving separately, and log the resolved session windows on init so a wrong offset is visible immediately rather than silently shifting every trade.
- Every lot-size calculation floors to the broker's volume step, checks `SYMBOL_VOLUME_MIN`/`MAX`, and **logs explicitly when a trade is skipped because the size floored below minimum**. Silent undersizing is a leading cause of "the EA doesn't trade" that has nothing to do with the strategy — rule it out before diagnosing anything else. Also check the stop distance against `SYMBOL_TRADE_STOPS_LEVEL`.
- The magic number is derived deterministically (a hash of EA name and variant), never randomized at compile or init — a magic number that changes between runs orphans open positions, so the restarted EA can neither manage nor close its own trades.
- Plain-language input names and MQL5 `input group` sections on every input parameter, with a one-line comment on what changing it does. This is what the user sees in MT5's native Inputs tab, so it has to be self-explanatory without needing the dashboard.

## Diagnose before retrying — don't just retune the same approach

A known failure mode building EAs with an LLM: after a failed backtest, the pull is to tweak the same indicator's parameters (a moving-average period from 20 to 15, an RSI threshold from 70 to 65) rather than asking whether that whole *family* of indicator fits the idea at all. Retuning a mismatched approach can burn every remaining iteration without ever getting closer — the fix needed was at the start, not in the numbers.

Before writing the next attempt, classify why the previous one failed:

- **Parameter-level** — the approach is a reasonable fit for the stated idea and style; the specific thresholds/periods just aren't tuned right yet. Retune within the same approach.
- **Approach-level** — no amount of retuning this indicator/technique will satisfy the idea and style as described; the mismatch is structural (e.g. a lagging trend indicator can't produce the fast reaction a scalping idea needs). Switch to a structurally different indicator/technique family for the next attempt — not a variation of the same one.

- **Definition-level** (concept-based strategies only) — the concept fits and the parameters are
  plausible, but the mechanical rule implemented isn't what the user meant. The FVG threshold, the
  order-block boundary, how strict a liquidity sweep has to be.

  A failing backtest looks *identical* in all three cases, so this one cannot be resolved by
  inspection. **Stop the loop and ask.** Show the specific definition in question, the alternative
  reading, and what each would change. Guessing burns an iteration and, worse, retuning a definitional
  mismatch fits the strategy to the wrong concept. A question costs none of the three attempts.

State which of the three it is, and why, in the iteration report — an auditable call, not a silent guess. Given `/loop-engineer`'s 3-iteration cap, don't spend more than one iteration retuning an approach that turns out to be approach-level; switch immediately rather than burning the remaining attempts on the same dead end.

## PC dependency — needed from here on, no fallback

Everything above (requirements, the plain-language explain-back) needs no PC at all — talk through those anytime. The PC is only required once actual compiling, backtesting, or a demo live run starts, since that needs a real MT5 install (a separate Windows PC, not this Mac — the Mac's own Wine-wrapped MT5 was tested and found unreliable for headless compiling). Don't fall back to it, and don't build a custom backtester as a substitute either; a from-scratch re-implementation of the trading logic in another language can silently diverge from what the compiled EA actually does, which defeats the point of testing at all.

- Connection details live in `.ea-builder-pc.json` at the project root: `{tailscale_ip, ssh_user, mql5_path}`. First time this is needed without the file: ask the user for these once, save them, reuse forever after.
- Some answers gathered above can only be *verified* on the PC, so treat them as provisional until it's reachable. Specifically: whether `real_volume` is non-zero for this broker's XAUUSD (if it's 0, any real-volume logic is inert and the design has to fall back to the tick-count proxy or drop volume entirely), and whether the tester returns calendar data for the news filter. Check both on the first PC connection, before the first build — not after a backtest has already been run on logic that was silently doing nothing.
- Right before the first compile attempt — not any earlier — check the PC is reachable (SSH to `tailscale_ip`). Unreachable → tell the user to turn the PC on; everything gathered and explained so far stays valid, resume straight into compiling once it's back.

## Criteria — what "pass" actually means

**Compiling is not one of the gates.** Getting code to compile is work *inside* an attempt, not an
attempt of its own: push the `.mq5` over SSH, run `metaeditor64.exe /compile:...`, read the real log,
fix, recompile — and only hand a compiling EA to the evaluator. Treating a syntax error as a failed
iteration burns a third of the strategy attempts on a typo.

Cap the inner compile cycle at ~5 tries. Blowing that cap *is* an iteration failure, with a real
reason worth feeding forward: "this approach couldn't be expressed in compiling MQL5."

The gate is the backtest — run on the PC, in MT5's actual Strategy Tester, at the highest tick-quality
mode available ("Every tick based on real ticks"). This holds even when the EA's logic is entirely
close-based: the signal fires on close, but which of SL/TP was hit first *inside* a bar depends on the
tick path, and lower-quality models guess it optimistically. With the tight stops these strategies use,
that guess is the difference between a profitable curve and a real one. See `references/mechanics.md`.

A backtest passes only if **all** of the following hold. Read `references/robustness.md` for the
reasoning behind each:

1. **Both periods hold up.** Split the range into a tuning period and a held-out one, and report their
   statistics side by side, not merged — a merged number hides a flat holdout. A strategy that only
   works on the period it was shaped to is overfit, not working.
2. **At least 30 trades in each period, separately.** This is a hard gate, not a note in the report.
   Below 30, drawdown and win rate describe those particular trades and nothing else. Missing it is a
   **fail** whose finding is "too few trades to evaluate" — and the fix is loosening conditions, not
   retuning parameters.
3. **Parameter sensitivity at ±20%.** Re-run every meaningful numeric parameter 20% up and down.
   Robust strategies degrade smoothly; one that collapses found a coincidence. Report it as a small
   table — it is cheap and often the most informative thing in the report.
4. **Commission and swap set to real values, and stated.** Real ticks carry spread but not these; the
   tester defaults are frequently zero. A run at zero cost gets labelled as such, never presented as a
   plain result.
5. **Data range and modelling quality stated.** Real-tick XAUUSD history is only a few years deep and
   varies by broker. Under about a year is not evaluation for a session- or structure-based strategy —
   say so before building, not after.
6. **Skipped trades counted and reported separately** — trades declined because the lot floored below
   the broker minimum or the stop sat inside the broker's stop level. "12 taken, 200 skipped for
   undersizing" is a different situation from "12 taken," and the standard report shows neither.
7. **If a news filter was chosen, it must have actually run.** Calendar data in the Strategy Tester is
   limited and may return nothing, in which case the backtest ran as though the filter didn't exist.
   Verify it saw events; if it didn't, either import a static event table or report the filter as
   **untested**. Never report a news-filtered EA as validated when the filter never ran.

## Build in layers when several concept families are wanted

PA baseline alone, fully tested. Then + SMC core, tested. Then + ICT extras, tested. Keep each layer's
backtest for comparison.

Because this spans several build/test cycles, the layer is state that has to survive a cutoff. Record
the current layer and each completed layer's result in `.loop-engineer-state.json` alongside the usual
fields (`{..., layer: "2-smc", layers_done: [{layer, result, trades, note}]}`). Without it, a resumed
session cannot tell which layer it was on, and will either redo a tested layer or skip an untested one.

Building everything at once has only two outcomes and both are uninformative: it performs badly and you
can't tell which layer is dragging, or it performs well and you can't tell whether SMC and ICT
contributed anything or the PA baseline is carrying it alone. Layered, every addition has a measured
before and after — and "this layer didn't improve on the one below it, drop it" is a successful result
of the process, not a failure of it.

Drive the build itself with the `/loop-engineer` pattern: task = build the EA to the gathered spec, criteria = the two gates above. Its executor/evaluator/state-file/resume/log mechanics all apply unchanged — no need to reimplement any of that here.

## The report always ends with these disclaimers

- Passing compile + backtest is not a green light for real money — test on a demo account first, and know that demo still isn't a perfect stand-in for live execution (requotes, fill differences).
- If a news filter wasn't chosen, or the style trades through news anyway: gold moves hard on USD news (Fed, NFP, CPI) — flag the exposure.
- If the style holds positions overnight or over a weekend: flag gap risk at the next market open.
- If the user proceeded despite an environment mismatch (from "Gather requirements" above): repeat that specific mismatch and what it likely costs in practice.
- If any volume logic was built: state plainly that it rests on `tick_volume` — a count of price changes, not traded contracts — and that retail XAUUSD has no real volume in MT5. It supports claims about session activity, not about institutional participation.
- If the strategy is concept-based (PA/SMC/ICT): restate the specific mechanical definitions that were locked in, and note that a different but equally common definition of the same concept could produce materially different results. The backtest validated *this* translation, not the concept in general.
- If a news filter was included but the calendar returned nothing in the tester: say the filter is untested, not merely present.
