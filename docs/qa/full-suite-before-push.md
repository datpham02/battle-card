# Run the full suite BEFORE pushing to `main`, not after

**The rule.** Before a push to `main`, run `tools/qa/run_all_tests.sh` to completion and read the result. Not
after, not instead of the narrow gates a session already has.

**Provenance:** set by the user on 2026-11-15, recorded here from the coordinating session's relay of that
decision, not from a conversation this file's author was in. If the relay is wrong, this file is wrong with it.

Related: `docs/qa/runner-known-gaps.md` (what the runner cannot tell you), `docs/qa/tree-guard-scope.md` (what the
tree manifest covers).

---

## Why — three bugs that were already on the remote

The 2026-11-15 run was the **first readable full run in two days**. It immediately found three defects that had
been pushed to `main`:

- a jailer enemy still carrying a trait that was supposed to have been removed
- old vocabulary in a new enemy chain, pushed with the Swamp commits, unnoticed by anyone
- the Keeper sheet missing its motion profile

All three passed the narrow gate of the session that wrote them, and all three were pushed. (These three are
relayed from the session that ran the suite, not measured here.)

That is the argument in one line: **a per-session gate checks what that session thought to check.** The full suite
is the only thing that checks what nobody thought of — including the interactions between sessions that each
tested their own change in isolation and never saw it beside anyone else's.

---

## Four conditions, so the rule survives contact with a working day

**1. Only when the push touches code or data.** That means the extensions the manifest tracks:
`.gd .json .csv .tres .tscn .cfg .sh`. A push of only `.md`, `.yaml` or evidence images does not need a run.

**2. One run covers every commit pushed with it.** Batch the commits, push once, run once. Thirty-five minutes per
commit would kill the rule inside a day; thirty-five minutes per push is payable. This condition is what makes the
rule survivable, so do not quietly drop it to "be safe" — a rule nobody can afford is a rule nobody follows.

**3. The run only counts if it is WHOLE, checked by three independent signs:**

    the last line is RESULT:            (a run cut off part-way leaves a file that looks finished)
    the suite count matches a number written down BEFORE the run
    tree_moved=0                        (nobody edited shared files mid-run)

Missing any one of the three and the run covers nothing. They are independent on purpose: a truncated run can
still show `tree_moved=0`, and a complete run on a moving tree describes no single version of the code.

**4. A red suite does not automatically block the push — an unexplained one does.** Every red leg must be traced
to an owner and stated, in the commit message or in the report to the user. "Red because of another session's
work in progress" is an acceptable answer **when it has been established**; "red, cause unknown" is not, and
blocks.

---

## The cost, written down so whoever skips the rule knows what they are trading

- **~35 minutes** of wall clock per run, during which the shared checkout must hold still: no writes to the
  tracked extensions by any session.
- **The machine sleeping mid-run is not yet prevented.** The 02:31 run died this way — Windows logged
  `The system is entering sleep. Sleep Reason: Application API`, which is the whole machine, not the process.
  Two sessions were refused permission to request a keep-awake, so until the user changes a power setting or
  allows that request, **every long run can still be cut in half**, and a cut run produces a file that reads as
  complete (see `runner-known-gaps.md` §2).
- **A run cut by sleep costs the 35 minutes and buys nothing**, so the sleep risk is not a footnote on the cost:
  it is a chance of paying the cost twice.

A rule with its price written next to it can be set aside deliberately in a hurry. A rule without one gets set
aside without anyone noticing they chose to.
