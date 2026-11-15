# `run_all_tests.sh` — known gaps

What the shared test runner **cannot** tell you. Written so nobody spends half an hour re-deriving it from a
confusing report. Each entry says what is missed, how it was measured, and why it has not been fixed yet.

Related: `docs/qa/tree-guard-scope.md` (what the tree manifest covers).

---

## 1. A suite that prints its result and then CRASHES is counted green

**Measured 2026-11-15.** `tests/unit/run/formations_config_test.gd`:

    FAILS=0 PASSES=59   exit=139

`139 = 128 + 11` = **SIGSEGV**. The suite runs every assertion, prints its `FAILS` line, and segfaults during
teardown. Reproduced on a throwaway worktree at `HEAD` with the file unmodified, so it is **pre-existing** and not
caused by any current change.

**Why it slips through.** `record()` only marks `*** NO RESULT ***` when the output has **no `FAILS` line** and the
exit code is not 124 (timeout):

    if [ -z "$f" ] && [ "$code" -ne 124 ]; then f="*** NO RESULT ***"; ...

A crash *after* printing leaves the `FAILS` line present, so `$f` is non-empty, the branch is skipped, and the exit
code is never examined again. The suite counts as a pass.

**How to read a report until this is fixed:** a `FAILS=0` line does **not** rule out that the suite died after
printing it. If a suite looks suspicious, re-run it alone and check `$?` by hand.

**Why it is not fixed yet (2026-11-15).** Gating on the exit code changes how **every** suite is classified, and
the fix landed in the middle of a 35-minute full run — changing the measuring instrument during the measurement.
It deserves a run of its own. When it is done, it needs the same two-direction proof as the other guards: a suite
that crashes after printing must go red, and a suite that exits cleanly must stay green.

**Suspected cause of the crash itself** (unverified): these suites call `ChaptersConfig.set_formation_lookup()`
with a lambda, leaving a static Callable alive at teardown. `tests/unit/combat/phase_banner_host_test.gd`, which
does not call it, exits 0. That is a correlation on two data points, not a diagnosis.

---

## 2. A run cut off part-way leaves a file that looks finished

**Observed 2026-11-15.** A full run stopped at `interrupt_tell_test`, about 80 of ~320 suites. The output file had
81 lines, no `SUMMARY`, no `RESULT`. Nothing in it says it is incomplete.

Guard 3 above (`[ ! -s "$OUT" ]`) does **not** cover this and is not wrong to miss it: it asks "did we produce
nothing", and 81 lines is not nothing. The new shape is **producing half**.

**Cheapest check:** the last line of a finished run is always `RESULT: ok` or `RESULT: FAILED`. Anything else means
the run did not reach its own ending. A reader can apply it today with `tail -1`; the runner cannot apply it to
itself, because a process that dies does not get to write a verdict about having died — the check belongs to
whoever reads the file.

**Why it matters more than it looks:** a truncated file is the most convincing kind of false green. Everything in
it is true. Every suite it lists really did report what it says. The only false thing is the impression that the
list is complete, and that impression comes from the file's shape rather than from anything written in it.

---

## The family these belong to

Six shapes of the same failure have been found in two days, all of them **silent**:

| | Shape | Caught by |
|---|---|---|
| 1 | `RESULT: ok` printed with failing suites — failures counted but never gated | reading a real log |
| 2 | A missing suite path: Godot prints no `FAILS`, no error, exits 0 | the `NO RESULT` branch |
| 3 | A filter that matches nothing (`(?!…)` in ERE, `[^)]*` stopping early) returns an empty result that reads as "all clear" | running the filter on a case known to hit |
| 4 | The runner called with no argument: output goes to an empty filename, 320 suites run for 35 minutes, exit 0 | being bitten |
| 5 | A suite prints the right result, then dies, and the death is not counted | running it alone and reading `$?` |
| 6 | A run stops part-way; the file it leaves is true in every line and complete in none | `tail -1` is not a `RESULT:` line |

The through-line: **green inferred from the absence of a failure signal, rather than asserted.** Every fix in this
file's history is the same move — require the positive statement instead of accepting silence. Shapes 3, 5 and 6 are
the ones a guard cannot predict, which is why the standing rule is to prove an instrument can see a failure before
trusting what it says about success.
