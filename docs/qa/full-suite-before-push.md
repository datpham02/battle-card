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

## Five conditions, so the rule survives contact with a working day

**1. Only when the push touches code or data.** That means the extensions the manifest tracks:
`.gd .json .csv .tres .tscn .cfg .sh`. A push of only `.md`, `.yaml` or evidence images does not need a run.

**2. One run covers every commit pushed with it.** Batch the commits, push once, run once. Thirty-five minutes per
commit would kill the rule inside a day; thirty-five minutes per push is payable. This condition is what makes the
rule survivable, so do not quietly drop it to "be safe" — a rule nobody can afford is a rule nobody follows.

**3. The run only counts if it is WHOLE, checked by three independent signs:**

    the file CONTAINS a line starting RESULT:   (grep -c '^RESULT:' is 1, not: tail -1)
    the suite count matches a number written down OUTSIDE YOUR HEAD before the run
    tree_moved=0                        (nobody edited shared files mid-run)

**Not `tail -1`.** The first version of this file said the last line must be `RESULT:`, and that check is
wrong: on a FAILING run the runner prints explanation lines *after* the verdict, so `tail -1` is a `no_result = `
note and the check calls a complete run truncated. Measured on `full-suite-2026-11-15b`, a genuinely complete run
of 333 suites — `tail -1` says truncated, `grep -c '^RESULT:'` says 1. A gate that fires on every red run is a
gate that gets ignored, and this one was written into this file by someone spending the same night warning about
exactly that.

"Written down" is load-bearing. A number you only remember is a number you can
adjust after seeing the result, and you will not notice yourself doing it. Put it
in the result file itself if you can, so it travels with the evidence; a message
to another session before you press go is the acceptable minimum. A remembered
expectation is not a check, it is a feeling of having checked.

Missing any one of the three and the run covers nothing. They are independent on purpose: a truncated run can
still show `tree_moved=0`, and a complete run on a moving tree describes no single version of the code.

**4. The run covers the COMMIT it recorded at its start, not "everything older than its timestamp".** The runner
writes `git rev-parse HEAD` into the result file before the first suite. A push is covered when the HEAD being
pushed is that commit, or when every commit added since has a covering run of its own.

This condition exists because the three above do not cover it, and the gap is not obvious: they all ask
*"is this run complete?"* and none asks *"which tree is it about?"*. Measured on 2026-11-15 —
`full-suite-2026-11-15b` finished at **12:05:15**, while the three commits waiting to push were made at
**12:11:47**, **12:11:50** and **12:15:59**. That run passes conditions 1-3 perfectly: 333 suites, `tree_moved=0`,
a real `RESULT:` line. It also describes a tree containing none of them.

Worse, it inverts: three of its red legs are exactly what `85bd258d` fixes. Using it as the gate would be using
the photograph taken before the operation to sign off the operation. `tree_moved` catches the tree changing
**during** a run; nothing catches it changing **after** — which is the shape of commit-then-push.
(monster-skills session.)

**Why identity and not time, which was the first attempt.** "Newer than every commit it covers" sounds equivalent
and creates a race nobody can win: a full run takes 25-35 minutes, eleven sessions commit to `main`, and any one
commit during the run disqualifies it — even green, even with `tree_moved=0`. Three commits landed in four minutes
on 2026-11-15 (12:11:47, 12:11:50, 12:15:59); at that rate a timestamp-based gate never finishes. And the failure
is invisible until the run is over, because a commit changes no byte on disk, so `tree_moved` stays 0 and the
first three conditions still pass.

Recording the commit instead removes the race without asking anyone to behave: a later commit does not invalidate
an earlier run, it is simply not covered by it. It also makes the condition machine-checkable rather than two
timestamps compared by eye — and file timestamps are fragile in exactly the ways this project has already hit
(a copied file, a sleeping machine, the 02:31 run).

What a slot cannot give you: the Godot slot reserves **the machine**, one engine at a time. This condition needs
something else — knowing which **branch state** a run describes. Those are different reservations, and only the
first one exists here.

**5. A red suite does not automatically block the push — an unexplained one does.** Every red leg must be traced
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

---

## The thing to guard is the WRITE, not the commit

Most of a night was spent arguing whether a `git commit` moves another session's manifest. It is a real question
with a real answer (it depends on how that manifest is built), and it is **the wrong thing to be watching.**

A commit is the visible trace of a write that already happened — possibly hours earlier. The write is what splits
a run across two versions of the code. By the time anyone can see the commit, the damage, if there was any, is
done and the evidence of *when* is already gone from `git` (it is in the file's mtime, not in the history).

Two consequences:

- **Declare scope when you WRITE, not when you commit.** "I'll commit later" is not reassurance; it describes the
  harmless half.
- **When reconstructing whether a run was split, use mtimes, not the commit graph.** The commit timestamp tells
  you when someone recorded the change, not when the file on disk changed under a running suite. The one case
  resolved this way on 2026-11-15 was settled entirely by mtimes: two writes at 12:08 and 12:09 sat after the
  previous run ended at 12:05 and before the next began at 12:12, so nothing was split — a fact the commit graph
  alone could not establish in either direction.

---

## What a GREEN run clears — and it is not the commits

Condition 5 says a red leg must be traced to an owner before it blocks. That half is written. The other half is
not, and it is the half that lets a push through:

**A green run does not clear the commits. It clears the tree.**

The suite executes the working checkout — `HEAD` plus every uncommitted file in it. On 2026-11-15 that was
**509 dirty files** belonging to eleven sessions. So a run records the behaviour of a tree that has never existed
in the history and never will: three commits waiting to push, plus nine other sessions' half-finished work, all
loaded together.

The asymmetry that follows is not symmetric, which is why it is easy to miss:

| run result | what it proves about the 3 commits |
|---|---|
| **red** | little — condition 5 exists precisely because the red leg may belong to anyone |
| **green** | **also little** — another session's uncommitted file may be *supplying* what a commit forgot |

The red case is the one everybody notices, because red demands an explanation. Green demands nothing, so nobody
asks what it was measuring. But a missing function, a renamed key, a data file a commit should have included —
each of those can sit uncommitted in another session's working copy and make a broken commit pass. The push then
sends the broken half to `main` and leaves the rescuer on someone's disk.

**What this does NOT mean.** It is not an argument for a clean checkout before every push — that costs more than
the rule is worth, and `active.md`, evidence files and in-flight art would all have to be rebuilt. It is an
argument for knowing which claim you are entitled to make:

- Entitled: *"the tree these commits sit in passes 333 suites."*
- Not entitled: *"these three commits pass 333 suites."*

Say the first one. When the second is what actually matters — a release, a commit that another machine will build,
anything where the commits travel without the tree — the run has to happen on a tree that holds only them, and
nothing in this file arranges that.

**How to tell the cheap case from the expensive one.** Before pushing, list the files the commits touch and check
whether any of them is *also* dirty, or has a dirty neighbour the commit depends on:

```bash
git diff --name-only origin/main..HEAD | sort > /tmp/pushed.txt
git status --porcelain | awk '{print $NF}' | sort > /tmp/dirty.txt
comm -12 /tmp/pushed.txt /tmp/dirty.txt      # a pushed file ALSO dirty: the dangerous overlap
```

An empty intersection does not prove independence — a commit can depend on a dirty file it does not itself touch —
but a non-empty one is a direct hit, and it is the case worth catching for the cost of two commands.

(Coordinating session, 2026-11-15, written while the gate run for those same three commits was in flight. The
claim about 509 files is from `git status --porcelain | wc -l` that afternoon; the table is reasoning, not a
measurement, and the green-run failure mode itself -- a commit passing because another session's dirty file
supplied what it forgot -- has not been observed in this project. It is written down because the shape of the
mistake is visible now, not because it has already cost anything.)

**A weaker cousin of it WAS observed, in this very file, two minutes later.** Running the `comm -12` check above
for the first time returned exactly one filename: `docs/qa/full-suite-before-push.md`. The file is in commit
`aad83d10`, waiting to push, and it was simultaneously dirty -- because the monster-skills session had corrected
it in the working tree without committing: `Four conditions` -> `Five`, and the broken `tail -1` check replaced
by `grep -c '^RESULT:'`.

So at that moment the tree held a document whose rule was right, and `origin/main` was about to receive one whose
rule was wrong. **This is not the failure mode above** -- no commit passed a suite it should have failed, and a
document cannot be rescued by a dirty neighbour the way code can. What it shares is the premise: *what the tree
says and what the push sends are two different things, and only one of them was read.* That premise is the whole
section; it just happened to prove itself on prose instead of on code.

It also says something about the check. Its first hit was the checking session's own file, which is self-detection
and therefore weak evidence that it works on anyone else's -- but it is a hit, so the check is not the kind that
silently returns empty forever. Those are different worries and only the second one is now closed.)

---

## Condition 4 refined: HEAD identity is a shortcut, not the question

Condition 4 asks *"is the HEAD being pushed the one the run recorded?"* That is a **one-way-safe approximation**:
it never passes a run that should fail, but it **rejects runs that were genuinely covering**. Rejection has a
price — it sends someone back for another 35 minutes to buy nothing, and a rule that expensive gets dropped.

A measured instance, 2026-11-15. The Keeper run (snapshot ~12:10:30, finished 12:49, 333 suites,
`failures=0`) recorded a HEAD older than the three commits waiting to push, so condition 4 rejects it. But it ran
on their content:

1. The three commits touch 4 files; **3 are inside the manifest's filter** (`strings.csv`,
   `enemy_skills_config.gd`, `zone_traits_test.gd`). The 4th is `.md`, outside it.
2. The Keeper run reported `tree_moved=1` naming **exactly one** file — `unit_kiem_si_sheet.json`. The three
   are not in that delta, so they **did not change** between 12:10:30 and 12:49.
3. The commits were created 12:11:47–12:15:59, **inside** that still window, and a commit takes its content
   from disk.
4. `git diff HEAD` on those three files is **empty** — disk equals HEAD. (Verified independently by the
   coordinating session, including a check that the same command reports a known-dirty file as differing, so an
   empty answer means "identical" and not "the command found nothing".)

So the content the Keeper run executed is the content waiting to push.

**The question condition 4 is really trying to ask** is not *"is this run newer"* (a race nobody can win — see
above) and not *"does HEAD match"*, but:

> **Was the content that ran equal to the content being pushed, for the whole duration of the run?**

Both halves are already measured by tools in the runner:

| half of the question | the tool that answers it |
|---|---|
| did the files hold still *during* the run? | `tree_moved`, comparing start and end manifests |
| does what ran equal what is committed? | `git diff HEAD -- <the pushed files>` |

Keep HEAD identity as the **shortcut**: when it matches, stop thinking, the run covers the push. When it does not
match, that is **not** an answer of "no" — it is an invitation to check the two rows above. Only if one of them
fails is the run genuinely uncovering.

**A hole, stated rather than left silent:** the chain above says nothing about the `.md` file, because the
manifest filter does not track `.md` and so `tree_moved` is blind to it. Harmless here — no `.md` changes a suite
result, and condition 1 already exempts documentation-only pushes from needing a run at all — but the chain is
three links about tracked files and does not extend to untracked-by-manifest ones. Do not quote it as if it did.

(monster-skills session proposed the HEAD anchor originally, and corrected it here: it removed a real race, and
was then stated as if it were the *correct* check rather than a safe-one-way one. Link 4 verified by the
coordinating session; links 1-3 are from the Keeper run's own output.)
