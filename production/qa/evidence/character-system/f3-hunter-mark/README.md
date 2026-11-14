# F3 — `hunter_mark` cue — readability gate

## Result history

Kept in order, with dates. A verdict that disappears and reappears with different numbers and no
note between them is unreadable later; the history is worth more than any single verdict in it.

| Version | Date | Verdict | Why it ended |
|---|---|---|---|
| **v1 — axis-aligned jaws** (`v1-axis-aligned/`) | 2026-11-14 12:50 | **PARTIAL, 3 of 4** | **SUPERSEDED by the realignment.** The user judged the cue misaligned and ugly. Cause: `_draw_passive_mark` built its box with `_bg().fit_rect(...)`, documented at `board_geometry.gd:149` as an **axis-aligned screen** rect for "text, a panel, an icon, a circle". The board is drawn in perspective, so the vertical jaws sat askew against every line around them, bled into the neighbouring thorn cells and cut across the enemy's feet. A shape that lies on the floor has to be built in model space and mapped point by point through `to_screen()`. The v1 frames are kept because the measurements below were taken from them. |
| **v2 — model-space jaws** (`v2-model-space/`) | 2026-11-14 13:4x | not scored | **SUPERSEDED by the crack.** The projection fix worked — the jaws leaned with the board, sat inside the cell and stopped cutting the enemy's feet — and the shape was still wrong. The user asked what the effect was supposed to mean ("is it showing it's been branded?"), which is the verdict: two brackets flanking a unit read as **selected / targeted** in every game UI, not as **marked**. A cue that has to be explained has failed. v2 was a correctly drawn version of the wrong idea. |
| **v3 — crack on the body** | pending | pending | — |

> **Criterion 4 has moved three times today**: undetermined → answerable → undetermined. That is the
> record of a harness limit being found, not of a flaky criterion, and it is why the readings below
> stay here rather than being overwritten.

---

## 2026-11-14 — the frame numbers in this folder are not a timeline

A second session hit this with its own capture set and reported it: **`--shot-frame=N` indexes
rendered frames, not simulation time.** Their four sphinx shots, same seed, increasing frame numbers,
came back with hero HP 175 → 200 → 200 → 165 — impossible on one timeline. Four separate processes,
and the frame→sim-time mapping shifts with machine load.

`shoot.sh` in this folder's scratchpad spawns **one Godot per frame** (`for frame in 5 12 20 30 45 70`,
a fresh `$G ... --shot-frame=$frame` each pass). So this capture has exactly the same property, and
two things above have to be withdrawn:

1. **"Simulation time does not meaningfully advance in this demo" is not supported by this evidence.**
   It was inferred from the cue still being drawn at f70 when `FEEDBACK_SEC` = 0.8 s should have
   expired it. But f70's process may simply not have reached 0.8 s of sim time. A frozen clock and a
   shifting frame→time mapping produce the same picture, and this capture cannot tell them apart.
2. **The 110 px → 104 px jaw measurement is not a measurement of motion.** f5 and f70 came from two
   different processes, so the pair has no before/after relation. The numbers are real; the
   *difference* between them means nothing.

**Criterion 4 stays UNDETERMINED** — that label was right and is now better founded. What changes is
the reason: not "the demo freezes time" but **"this capture method cannot produce an ordered
sequence at all."** That is a harness limit, not a property of the demo, and it is the fourth
movement of criterion 4 today.

### Consequence for the v3 brand capture, before it is shot

The brand is a 300 ms / 7-frame animation. Proving it reads as *branding* needs frames in order,
which is precisely what one-process-per-frame cannot give. Shooting it the old way would produce a
set that looks like evidence and answers nothing — the failure this file exists to record. Options,
cheapest first:

- **Motion from the sheet, integration from the game.** `anim.gif` / `contact.png` in the pixelfx
  candidate already show the animation in order, rendered deterministically. The in-game shot then
  only has to answer "is it on the right body, at the right size, in the right colour" — one frame,
  no ordering needed. This splits the question so neither half needs the harness to do what it can't.
- **One process, many shots.** A capture hook that writes several PNGs from a single run, so the
  frames share one clock. Needs a change to the shot path; not yet investigated.

The first option needs no engine work and is the one to try.

---

# v1 — axis-aligned jaws: **PARTIAL (3 of 4 criteria)**

**Captured:** 2026-11-14 ~12:50. **Demo:** `--character=tho_san --demo=vay_bat --seed=1`, windowed
1280x720, `--audio-driver Dummy`. Story 037's own demo: a real `tran_gai` cast beside the boss, so
the mark is earned through the passive's own path, not a scene arranged to flatter the cue.

**Do not read this folder as a pass.** Criterion 4 is unanswered, and the reason is below rather
than omitted — a criterion that disappears between the plan and the write-up reads as one that
passed.

## What the cue is

Two jaws in the hunter's accent `#7FA64B` closing on the marked enemy, the same closing-bracket
shape as the passive's select-screen icon. It exists because the passive's entire output is a Ran
stack, and **a Ran stack applied by a CARD draws the identical chip** — without a cue of its own the
player cannot tell that the character did anything.

## The four criteria, written before the capture

| # | Criterion | Verdict |
|---|---|---|
| 1 | Visible at 1280x720 without being told where to look | **PASS** |
| 2 | Reads as attached to the ENEMY, not as board furniture | **PASS** |
| 3 | Accent distinguishable from the green "+N" and the gold zone marks | **PASS** |
| 4 | Late frame differs from early — can a player *time* the mark | **UNDETERMINED** |

The pre-registered rule was "yes on 1-3 and no on 4 is still a FAIL". Criterion 4 did not get a
*no*; it got no reading at all, for a harness reason measured below. That is a different outcome and
the gate stays open until a harness that can answer it has.

## Why criterion 4 is unanswered, measured rather than eyeballed

> **Read the frame-ordering section above first.** The two readings below came from two
> separate Godot processes, so their *difference* is not a measurement of motion. The numbers
> stand; the inference drawn from them has been withdrawn.

Accent-coloured pixel columns in the board region, clustered per frame:

| Frame | Left jaw | Right jaw | Inner gap |
|---|---|---|---|
| f5 | 700–734 | 844–883 | 110 px |
| f70 | 700–740 | 844–893 | 104 px |

The jaws move **6 px across 65 frames**. The design closes them by `cell_width * 0.35 * fade`, which
is tens of pixels over the cue's life, so they are not ageing.

The decisive point: `FEEDBACK_SEC` is 0.8 s, so at 60 fps the cue should have **expired entirely**
by frame 70. It has not — the jaws are still drawn at nearly full opening. **Simulation time does
not meaningfully advance in this demo**, and `_age_flash` is step-gated, so the flash is raised and
then effectively frozen.

> **A correction, recorded rather than quietly dropped.** Mid-session I reported the opposite — that
> the harness *did* advance sim time — on the evidence that 3 of 6 frames were distinct. That was
> wrong: the frames differ because the **"Deadfall" banner** fades on real time, not because the cue
> moves. The banner is not part of this cue. The measurement above is what settles it, and it
> contradicts the eyeball reading that preceded it.

## What would answer criterion 4

A harness where match time runs: a live match, or a demo that ticks `CombatView` rather than setting
the board up and stopping. Until then the cue is known to be **visible and attributable**, and
**unknown to be timeable**.

## Known limits of these frames (all v1, in `v1-axis-aligned/`)

- **The banner covers the enemy in f5–f30.** Those four frames are byte-identical and the "Deadfall"
  signature banner sits over the board, so only the jaw tips show. Only f45 and f70 show the cue
  unobstructed.
- **1v1 only.** `_vay_bat_demo` reads `state.enemy_cell`, singular. The multi-enemy session's
  deliberate gap at `combat_view.gd:611` — the mark still only fires for unit 0 in a real match —
  cannot appear in these frames and is **not** evidenced either way here.
- **Shared checkout.** A capture here shows whatever every session had on disk that second. The tree
  manifest taken before and after this capture was identical, so these six frames are one tree; the
  run log in the session scratchpad carries the per-file hashes.

## Correctness is a separate gate, and it passed

`tests/unit/combat/passive_cue_test.gd` — 36 PASS, FAILS=0, 0 script errors, re-run immediately
before this capture. The gate was watched failing first: removing `fire_event_cue()` gives FAILS=2
on the two positive legs. Worth knowing for anyone extending it — **the four negative legs stayed
green against the broken code**, because "no cue was raised" is trivially true when the cue can never
fire. Only the positive legs guard anything.
