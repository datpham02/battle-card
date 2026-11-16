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

**FIXED 2026-11-15.** `record()` now counts two cases as a crash, and `crashes=` joins the SUMMARY and the exit
gate:

    exit code >= 128                      killed by a signal, whatever it printed
    exit != 0 while the FAILS line says 0 a suite claiming no failures has no reason to exit non-zero

**The rule deliberately NOT used:** "exit code must equal the failure count", even though suites end with
`quit(fails)`. That convention is unverified across all 333 suites, and any suite ending `quit(0)` regardless
would be flagged on every red run. A gate that fires on healthy suites gets switched off, which costs more than
the hole it closes.

Proved in seven directions before being trusted — the ones that must stay **silent** matter more than the ones
that fire:

    FAILS=0 + exit 139   flagged      (the real case; reproduced end to end, formations_config_test)
    FAILS=0 + exit 1     flagged
    FAILS=0 + exit 0     silent       (phase_banner_host_test, reproduced end to end)
    FAILS=3 + exit 3     silent       quit(fails) convention
    FAILS=3 + exit 0     silent       quit(0) convention - the false-positive direction
    exit 124             silent       timeout keeps its own meaning
    no FAILS line        silent       still NO RESULT, unchanged

**Known limit, stated rather than discovered later:** exit codes are 8-bit, so a suite with >= 128 genuine
failures would alias into the signal range and be reported as killed. The worst seen is 102. The alternative —
trusting the failure-count convention — has the worse failure mode.

**MEASURED 2026-11-15, first full run with the guard (333 suites, `full-suite-2026-11-15d-gate.txt`): the hole was
2 suites wide.**

    tests/unit/run/formations_config_test.gd         FAILS=0  *** KILLED BY SIGNAL (exit=139) ***
    tests/unit/run/formation_shared_traits_test.gd   FAILS=0  *** KILLED BY SIGNAL (exit=139) ***

`formations_config_test` is the one that was found by hand and prompted the guard. **`formation_shared_traits_test`
was unknown to everybody** — it was written and committed (`2a68960a`, 2026-11-15) as a gate for the shared-trait
rule, ran green in every check made of it, and has been segfaulting since. The guard caught its own author's bug on
its first real run. That is the argument for the guard in one line: the case you build an instrument for is never
the only case it finds, and you cannot count what you have never recorded.

**CAUSE ESTABLISHED 2026-11-15 17:2x, and it was NOT what this entry claimed.** The hypothesis named the
lambda. The same call also parks an `ArenaLibrary` in a static — two things that always moved together, so no
measurement so far could tell them apart, and naming one of them was a guess wearing the clothes of a diagnosis.
Seven probes, each changing one factor:

    lib in static + lambda in static   exit 139    the crash, reproduced in 6 lines
    ArenaLibrary loaded, not stored    exit 0      loading it is innocent
    LAMBDA in static, library null     exit 139    sufficient on its own
    LIBRARY in static, empty Callable  exit 0      the library is innocent
    neither                            exit 0      control
    lambda created but NOT stored      exit 0      creating one is innocent
    STATIC-FUNC Callable in static     exit 0      and this is the fix

Run alongside the real suite as a known hit (`exit 139`), so a row of silent probes could not be mistaken for a
working experiment.

**It is a lambda STORED IN A STATIC.** Not lambdas (they are fine unstored), not statics (one holding an object
is fine). A lambda written inside `_initialize()` captures the `SceneTree`; a class static outlives it; the
process dies with SIGSEGV at teardown — *after* printing its result, which is why the runner scored both suites
green until the exit code was finally looked at.

**FIXED in both suites:** the inline lambda is now a `static func` reached through `Callable(get_script(), ...)`.
Verified on the property that matters and on the one that could have hidden a dead fix:

    formation_shared_traits_test   exit 139 -> 0   PASSES=9  unchanged
    formations_config_test         exit 139 -> 0   PASSES=59 unchanged

The pass counts are the real check. An invalid `Callable` would also stop the crash — by making the suite assert
nothing. Unchanged counts say the lookup still runs.

**The lesson that outlives the bug:** this entry asserted a cause for hours while the evidence only supported
"one of these two". It happened to be right, which is worse than being wrong, because nothing would have
corrected it. The discriminating probe took five minutes and should have come before the sentence.

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

## 3. Noise from somebody else's run, showing up as this run's failure

**Inferred from the structure, never observed.** Recorded so nobody chases it as a suite bug, and labelled so
nobody cites it as an incident.

Every suite is its own Godot process under a ceiling: **600 s** headless, **240 s** for the windowed suites in
`tests/integration/ui/`. Two or three full runs overlapping on one machine compete for CPU and slow everything;
a heavy suite could be pushed past its ceiling and recorded as `TIMEOUT`. The mark would land on the **run that
was harmed**, not the run that caused it, and nothing in the file records that the machine was busy. `tree_moved`
cannot catch it either: no byte on disk changes.

**Counted, not assumed: 0 `TIMEOUT` across all three runs on 2026-11-15**, including the stretch where three ran
at once, and including a 39-minute run with 15 minutes of overlap. The margin is wider than either session
guessed — consistent with the header's "~270 s on a **busy** machine" against a 600 s ceiling.

Sign to look for: a lone `TIMEOUT` on a suite that is normally green, with the rest of the run healthy.
Prevention: one full run at a time, by slot. (monster-skills session, with their own three corrections to how
they first told it.)

> **CORRECTED 2026-11-15 — read the line before blaming the machine.** This entry used to say "before looking for
> a bug in that suite, ask who else was running." That order is wrong, and wrong in the expensive direction: it
> sends a reader hunting for a second session that may not exist while the cause sits in their own suite. A
> runtime error during startup makes Godot **print the error and hang**, so it is killed at the ceiling and
> recorded as `TIMEOUT` too — measured in section 6. **Check `SCRIPT ERRORS` on the same line first:**
>
>     ... *** SCRIPT ERRORS=1 *** TIMEOUT    hung on its own error; the machine is innocent
>     ... FAILS=0 0 se TIMEOUT               no error printed; NOW ask who else was running
>
> Contention remains a real cause. It is the second question, not the first.

---

## 4. Counting suites by `grep` gives a different answer depending on the pattern

**Measured 2026-11-15, two sessions, one file, same ten minutes.** The file is
`production/qa/full-suite-2026-11-15d-gate.txt`, whose own `SUMMARY` line says `suites=333`.

    grep -c 'FAILS='   ->  334   one TOO MANY
    grep -c 'FAILS='   ->  330   three TOO FEW

Same command, same file, two readers, two answers — and **neither error is in the same direction**:

- **334**: the explanatory legend the runner itself prints under a `FAILED` verdict contains the literal text
  `FAILS=0`. The report counts as one of the suites it is describing.
- **330**: a handful of suites print `FAILS:` with a colon instead of `FAILS=`. They are real suites, really
  reported, and invisible to that pattern.

**Read `SUMMARY: suites=` instead.** It is the only count in the file produced by the thing that did the counting;
everything else is a reader re-deriving it from prose.

**Why both numbers are written here rather than just one.** A single one-directional example teaches the wrong
lesson: shown only the 334, a reader fixes the pattern (`grep -c '^tests.*FAILS='`) and keeps counting by grep.
Shown both, the lesson is the right one — **the method is wrong, not the pattern.** Any pattern narrow enough to
exclude the legend is narrow enough to miss a suite that formats its line differently, and nothing in the output
tells you which just happened.

This is the same shape as every other entry in this file, pointed at a number instead of a verdict: a count
inferred from a text search reads as authoritative precisely because it came out of a command.

**A second instance, 2026-11-16, on a different question and worse.** Checking whether files had been converted
to LF, `grep -c $''` was used to count lines containing a carriage return. Reproduced on two files built on the
spot:

    file with 0 CR bytes    tr -dc '' | wc -c -> 0    grep -c $'' -> 3
    file with 3 CR bytes    tr -dc '' | wc -c -> 3    grep -c $'' -> 3

**The same answer for both.** `$''` does not survive to grep, which receives an EMPTY pattern and matches every
line. So the check reported "all 352 lines have CR" for a file with none — not the false *negative* one might
expect from a tool reading in text mode, but a false *alarm*, and one that cannot distinguish the two cases it
was asked to separate at all.

Three instruments were tried before a trustworthy one: `grep -c $''` (matches everything), `od -c` piped
through `grep -o` with an alternation (leftmost match wins, so it reports whichever appears first), and `od -c`
piped through `grep -c` (counts 16-byte output rows, not line endings). **The decisive one reads bytes and does
no text interpretation:**

    cr=$(tr -dc '' < "$f" | wc -c); ln=$(wc -l < "$f")
    # cr == 0 -> pure LF;  cr == ln -> pure CRLF;  otherwise MIXED

The general rule is the one this file keeps arriving at from new directions: **before a check convinces you, run
it on a case where you KNOW the answer, in both directions.** Two three-line files settled in one command what
three plausible-looking greps had made steadily more confusing.

---

## 5. A verdict of FAILED whose every printed number is zero

**Observed 2026-11-15, on the first run of the crash guard.** The gate condition counted `crash_total`; the line
that prints the verdict did not. The result:

    SUMMARY: suites=333 failures=0 script_errors=0 timeouts=0 no_result=0 crashes=2 tree_moved=0
    RESULT: FAILED - failures=0 script_errors=0 timeouts=0 no_result=0 tree_moved=0
      crashes = a suite printed a result and then died ...

**FAILED, with every number it shows equal to zero, followed by a legend for a count it never printed.** A reader
has two ways out, and both are bad: conclude the runner is broken, or go hunting in another line for the reason.
`SUMMARY` had it all along, one line above — which is exactly why it survived review: the information was present
in the file, just not in the sentence that passes judgement.

**Fixed 2026-11-15**: `crashes=$crash_total` added to the verdict, checked in five counter states (crashes alone,
clean, failures without crashes, tree_moved alone, all at once).

**The class, which is the part worth keeping.** Every other entry in this file is a *green* that was not earned.
This one is the mirror: a **red that cannot be acted on**. They are the same defect — the reader is handed a
conclusion and denied the evidence for it — and the mirror is the easier one to ship, because a false red feels
safe. It is not: an unexplainable FAILED trains people to re-run until it goes away.

**Invariant, now written at the condition itself:** a counter must be added in *three* places — the gate
condition, `SUMMARY`, and the verdict line. Two of three is this bug.

---

## 6. The `NO RESULT` detector, finally fired on purpose — and what the probe found instead

**Measured 2026-11-15, 14:38.** Three probes outside `tests/` (so no full run could pick them up), each run
through real Godot and then through the runner's **own** `record()` function, lifted out of the file with `sed`
rather than retyped — a copy I typed would test my copy, not the runner.

    A  prints nothing, exits 0      -> *** NO RESULT *** 0 se        nores 0 -> 1   FIRES
    B  runtime error in _initialize -> *** SCRIPT ERRORS=1 *** TIMEOUT  nores 1 -> 1   (see below)
    C  healthy suite, FAILS=0       -> FAILS=0 0 se                  nores 1 -> 1   SILENT

**`NO RESULT` is healthy.** It fires on the shape it was written for — the one seen in the wild, a suite that
produces no `FAILS` line and no error — and stays silent on a healthy suite. Both directions, which is the whole
test: a detector that fires on everything guards nothing.

**Probe B did not test what it was designed to test, and that is the finding worth keeping.** The recipe handed
to me was "a suite that dies in `_initialize()` produces the NO RESULT shape". It does not — not here. A runtime
error inside `_initialize()` on a `SceneTree` script makes Godot **print the error and then hang**. It never
exits. `timeout` killed it at the ceiling and the exit code was **124**, so the `NO RESULT` branch skipped it by
design (124 is excluded on purpose: a killed process has not "returned no result", it was stopped).

So B exercised the timeout path, not the one it was aimed at. Had A not been in the same batch, the run would
have produced a plausible-looking line, no `NO RESULT`, and no way to tell whether the detector was dead or the
probe was wrong. **Three probes, not one** is what separated those.

**This corrects section 3.** That entry tells a reader who sees a lone `TIMEOUT` to ask who else was running,
because a busy machine can push a slow suite past its ceiling. True, but no longer the only cause: **a suite that
errors during startup hangs and is also recorded as `TIMEOUT`** — after burning the full 600 s ceiling. The two
**BOUNDARY, measured 2026-11-16 and narrower than this entry first implied.** The hang above was measured for an
error inside `_initialize()` on a `SceneTree` script — probe B, exit 124 at the ceiling. It does **not**
generalise to "a startup error hangs". A real defect on the startup PATH, two bad lines in
`CombatView._setup_pattern_brain()`, was measured in a clean checkout and did not hang at all:

    boss_footprint_dodge   FAILS=0 se=1 exit=0   4 s    a false green on a real suite
    forest_witch_flow      FAILS=1 se=1 exit=1   5 s    caught it on its own

So WHERE the error happens decides the behaviour, and "startup error" is too coarse a category to predict from.
Read the line, never the category. (Measured by the coordinating session, commit `e1bca36e`.)


are told apart on the same line:

    ... *** SCRIPT ERRORS=1 *** TIMEOUT    hung on an error; the machine is innocent
    ... FAILS=0 0 se TIMEOUT               no error printed; now ask who else was running

Check the line before the machine.

---

## 7. A gap that does not go silent — it wears somebody else's label

Every other entry here is about **silence**: a detector that never fires, an empty column, a number nobody
recorded. This class emits a signal — but the signal belongs to something else. A runtime error in a setup
function can make Godot print the error and hang; the runner waits out the 600 s ceiling and writes `TIMEOUT`,
which already has a familiar reading: *"the machine was busy."* A code defect puts on the costume of an
infrastructure problem, and the reader goes looking where there is nothing to find.

> **A gap that covers up is silent, and everyone knows silence carries no news. A gap that emits the wrong label
> consumes the attention it attracts, and spends it going the wrong way.**

**How to read a `TIMEOUT`:** conclude nothing from the label. `*** SCRIPT ERRORS=n ***` on the same line means
broken code, not a busy machine. A lone `TIMEOUT` on a suite that normally takes seconds is far more suspicious
than one on a suite that normally takes 270 s.

**AND THIS ENTRY ALMOST SHIPPED A FABRICATED CASE, which is worth more than the entry.** The draft listed, as
observed case 2, a `BossBrainConfig.push_icd_sec` defect that "printed the error and HUNG, cut by the timeout".
It was relayed from another session and copied in without being measured. It is false: measured afterwards in a
clean checkout, those two bad lines ran in **4 s and 5 s** and did not hang — one suite caught the defect
outright, the other was a false green. The line survived to be corrected only because a write lock delayed the
paste. **Luck, not discipline.** A relayed observation is a claim, and it needs the same measurement as your own
before it goes under your file's name.

(Class identified by the design-monster-skills session; case 2 corrected by the coordinating session,
commit `e1bca36e`.)

---

## 8. A suite can enter the very function and turn around at the door

How the gap above survives. `CombatView._setup_pattern_brain()` opens with a guard:

```gdscript
if not is_pattern_brain():
    return
```

`tests/unit/combat/pattern_wiring_test.gd` builds a `CombatView` and has "pattern" in its name — but never sets a
pattern brain, so it enters and leaves on the first line, touching nothing inside. An audit by filename, or by
"which suites build a `CombatView`", counts it as covered. Counted by what opens the guard instead:

    suites that build a CombatView          38
    suites that set BRAIN_PATTERN            2    boss_footprint_dodge_test, forest_witch_flow_test
    pattern_wiring_test                      3 CombatView references, 0 BRAIN_PATTERN

The guard is a conjunction — `brain == RunConfig.BRAIN_PATTERN` **and** a non-empty `enemy` — so even counting by
`BRAIN_PATTERN` alone would over-count.

**Count coverage by what OPENS the guard, not by what calls the function.** Written down because the first count
made exactly this mistake: asked to verify the claim, this file's own author grepped for files mentioning
"pattern", got **33**, and had to count again by the guard to get **2**. The wrong method answers instantly, looks
thorough, and was 16x too large.

---

## 9. Several clean results that are clean for ONE reason are ONE observation

Both directions, both seen on 2026-11-15.

**Too little evidence read as enough:** "no suite goes through this path" rested on four clean suites — but three
never build a `CombatView` at all and the fourth stops at the guard, and one says in its own header that it avoids
`CombatView` deliberately. Four suites clean for the same reason are **one** observation wearing four coats.

**Too much evidence read into a single fact:** two red legs on `harpy_dive` were **one** correct behaviour seen
twice — a push blocked into a hole, so R3 adds 8 — and read as double the evidence that the data was wrong.

Same arithmetic error, sign flipped: **correlated results are not independent ones, and the count feels like
strength in both directions.** Before a count persuades you, ask what would make every member of it move together.

---

## The family these belong to

Eleven shapes of the same failure have been found in two days, all of them **silent**:

| | Shape | Caught by |
|---|---|---|
| 1 | `RESULT: ok` printed with failing suites — failures counted but never gated | reading a real log |
| 2 | A missing suite path: Godot prints no `FAILS`, no error, exits 0 | the `NO RESULT` branch — **fired on purpose 2026-11-15, healthy** |
| 3 | A filter that matches nothing (`(?!…)` in ERE, `[^)]*` stopping early) returns an empty result that reads as "all clear" | running the filter on a case known to hit |
| 4 | The runner called with no argument: output goes to an empty filename, 320 suites run for 35 minutes, exit 0 | being bitten |
| 5 | A suite prints the right result, then dies, and the death is not counted | running it alone and reading `$?` |
| 6 | A run stops part-way; the file it leaves is true in every line and complete in none | `tail -1` is not a `RESULT:` line |
| 7 | A count derived by `grep` from a report, wrong in both directions at once depending on the pattern | reading `SUMMARY: suites=` instead |
| 8 | A verdict of FAILED with every number it prints equal to zero — the mirror of a false green | a counter reaching the gate but not the verdict |
| 9 | A code defect wearing an infrastructure label: a hang recorded as `TIMEOUT`, which reads as "busy machine" | `SCRIPT ERRORS` on the same line |
| 10 | A function entered and left at its guard, counted as covered | counting what OPENS the guard, not what calls it |
| 11 | Several results that are clean for ONE shared reason, counted as several | asking what would make them all move together |

The through-line: **green inferred from the absence of a failure signal, rather than asserted.** Every fix in this
file's history is the same move — require the positive statement instead of accepting silence. Shapes 3, 5 and 6 are
the ones a guard cannot predict, which is why the standing rule is to prove an instrument can see a failure before
trusting what it says about success.
