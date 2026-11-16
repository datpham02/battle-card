# Multi-enemy Phase 5 — per-unit trait evidence, re-captured 2026-11-16

Eight frames, four traits, one windowed Godot run (`--audio-driver Dummy`), captured by
`tools/qa/multi_enemy_trait_footage.gd` after commit `748e933e` (step 3 / H5: a trait answers its own unit's
wound). `TREE: STABLE` over 26,799 files for the whole run, scope printed with the report.

    burrow        carrier unit 1 at (6, 2), BARE unit 0 at (5, 1)
    rebirth       carrier unit 0 at (5, 2), BARE unit 1 at (6, 0)
    boss_phases   carrier unit 1 at (6, 2), BARE unit 0 at (5, 0)
    shroud        carrier unit 0 at (5, 0), BARE unit 1 at (4, 1)

## Why re-captured, and what these frames do NOT prove

The 2026-11-14 set in `../multi-enemy-phase5/` was taken on code where `combat_view` handed every resolved swing
to unit 0's host alone. `748e933e` changed **who receives `on_boss_damaged`**: `boss_phases` on unit 1 previously
never received it and now does. So the older frames document a build that no longer exists. They are kept, not
overwritten — evidence carries the limits of the day it was made, and deleting it would erase the fact that it
once described something else.

**All eight frames differ from the 2026-11-14 set by hash. That measurement proves nothing about the fix.**
Between the two captures other sessions replaced all five hero sprites (Vale, Ilva, Quill, Bram, Oriel), changed
the master palette and added dash motion. A pixel difference is exactly what BOTH hypotheses predict — "the
routing change altered trait behaviour" and "the art changed under the camera" — so the comparison cannot
separate them and is not offered as if it could.

What would separate them: capture the same four traits from a worktree at `748e933e^` with today's art, and diff
that against this set. Not done. It was not needed, because the routing is proven precisely where it is visible:

    tests/unit/combat/multi_enemy_traits_test.gd    FAILS=2 PASSES=37  ->  FAILS=0 PASSES=39

**So read these frames as a record of the CURRENT build, not as proof of a change.** They show four PER-UNIT
traits each acting on its own carrier while the bare unit beside it is untouched, in a live two-unit match. That
is the §3.6 deliverable. The proof that step 3 fixed anything is in the four H5/H5b legs, which were watched
failing first.

Known noise, exit 0: the run ends with "ObjectDB instances leaked" and "29 resources still in use at exit".
Present in the 2026-11-14 run too, unrelated to the frames, and worth remembering next to
`docs/qa/runner-known-gaps.md` §1 — a process that prints its result and then complains at teardown is the
shape that hid two SIGSEGVs for weeks.
