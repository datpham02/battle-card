# Skill v2 — Hỏa Lôi Milestone H2 (visual prototype) report

**Date:** 2026-11-09 · **Status:** H2 implemented, awaiting review. Not final: visual readability and counterplay
still need your review. Audio A1 not started. **Nothing committed.** No PixelLab, no paid tool, no new sprite, no
damage-model or balance change (Model A kept), no starter-deck change, top-row HUD issue untouched.
Evidence: `production/qa/evidence/skill-v2-hoa-loi/h2/`.

## 1. `focus_flow_test` diagnosis

**Classification: test-environment problem (window focus), not a gameplay or input regression.** Full notes:
`focus_flow_diagnosis.txt`.

- **Symptom:** "tap piece -> PLACING + focus active" failed 3/4 and 3/3 runs on 2026-11-09, including on a clean
  worktree of `0472896` (no H1 code). Later 4/4 PASS with unchanged code; instrumented runs also passed. The state
  before the tap was identical in passing and failing runs.
- **Cause, reproduced:** `GameFlow._notification` auto-pauses the run on `APPLICATION_FOCUS_OUT` /
  `WM_WINDOW_FOCUS_OUT` (`src/run/game_flow.gd:641-647`, intended behaviour). The windowed test opens a real window.
  When another window holds OS focus (the user at the PC, the Claude app), the run pauses and the injected tap lands on
  a paused battle. Sending `NOTIFICATION_APPLICATION_FOCUS_OUT` before the tap reproduces the exact failure 2/2
  (run paused = true, placing = false).
- **Not applied (needs your OK):** let windowed UI tests opt out of the focus auto-pause, as the demos do
  (`_no_autopause`). No assertion would change.

## 2. Implemented VFX components (free, code-drawn; one generic module)

| Component | File | What it shows |
|---|---|---|
| `FuseFx` (new, pure) | `src/art/fuse_fx.gd` | records from the authoritative `cast_scheduled` fuse event (cells + `at`); sigil, countdown, warning, collapse, floor blast, flame column, fizzle, hand glyph |
| Seal records | `combat_view.gd` `_fuse_fx`, `_mark_fuse`, `get_fuse_fx` | built at the swing end from the schedule; marked fired / fizzled by the matching `impact_resolved`; pruned when drawn out or when the cast was cleared (caster death) |
| Floor drawing | `floor_dynamic_layer.gd` `fuse_state` | sigils over the slab (and over a burning slab); blast flash / shock ring / scorch / fizzle under the burn flames |
| Overlay drawing | `overlay_layer.gd` `fuse_items` | the command glyph at the hand during the cast; one flame column per armed tile, back rows first, Ink edge |
| Cast binding | `assets/art/vfx/cast/index.json` `card_casts.hoa_loi` | `cast_gesture`, slash frame on the swing end, glyph on; the Mage's fireball, charge, impact packs and flood off for this card |

**Stages (arbiter clock):**
1. **Seal (0–0.25 s after the commit):** an amber square sigil draws itself corner-first on every armed slab.
2. **Charge:** three nested rings count down 3-2-1 (the outermost goes out each third of the fuse), and the core and
   fill brighten each step.
3. **Final warning (last 0.35 s):** the frame thickens and flickers cream / orange (steady with reduce motion) and the
   core swells. In the last 0.08 s every ring collapses into the core (anticipation).
4. **Blast (at `at`, every armed tile at once):** a cream ground flash, a square shock ring, then a stepped
   flame column about 1.15 cells tall (×1.15 for the square) with a cream core low, a gold body, an orange edge and an
   Ink outline. It holds, then sinks back into its tile (tapering, darkening) with charcoal smoke and gold embers.
5. **Aftermath:** the existing `burning_cell` flames and burn time bar, plus a fading charcoal scorch frame.
6. **Fizzle:** a cell locked before the blast breaks into 4 ash squares, with no flame.

Skipped, locked and fizzled cells never show an active sigil: records come only from the armed cells of the fuse
event, a cell locked at the cast is not in it, and a cell locked later is flagged by the arbiter's `fizzled_cells`.

## 3–5. Captures

| File | Content |
|---|---|
| `01-A-stationary-native640.png` | A: T field on an idle boss: glyph, draw-in, 3-2-1, warning, simultaneous blast, burn (hit 48) |
| `02-B-real-dodge-native640.png` | B: lone bar2 under a live boss: the BossBrain dodges, the blast misses |
| `03-C-cover-hit-native640.png` | C: plus field: the brain finds no safe cell, the blast hits (60); afterwards it leaves the fire |
| `04-D-escape-native640.png` | D: square field with an open exit: the boss escapes, the blast misses |
| `05-F-locked-cell-native640.png` | locked cell (cracked) gets no sigil, 3 seals, 36 dmg |
| `06-sequence-2x.png` | 2× crop of the full sequence (A) |
| `B_live_wolf_dodge.avi`, `C_live_wolf_plus_cover.avi` | continuous 60 fps recordings (local, ~30 MB each, not for commit) |
| `scene_*.events.txt`, `brainlog_*.txt` | authoritative event logs and BossBrain decision logs |

## 6. Real boss counterplay (no scripted movement)

Demo tooling only: `--boss-live` keeps the real BossController / BossBrain running (every demo turned it off),
`--cast-when-free` casts when the boss is not in a skill or swing, and the brain's existing debug now records its seal
reading (`last_debug().fuse`). No decision rule changed.

| Scene | Boss | Log (BossBrain) | Result |
|---|---|---|---|
| A | idle (stationary) | — | hit 48 |
| **B** real dodge | wolf pattern, live brain | t 0.53 / 1.05: `wait`, seals are a **soft** cost; t 1.55: `move (1,0) purpose=dodge`, `urgent: true, armed_left 0.40` | **miss** |
| C cover | same, plus field | t 1.55: `dodge` into (6,1), still a seal (no safe cell) | **hit 60**; t 2.58: `move purpose=retreat` off the burning cell to a non-burning one |
| D escape | same, square (exit open) | t 1.55: `dodge`, `armed_left 0.70` | **miss** |
| E burning ground | C after the blast | the boss leaves its burning cell for (7,1); it never enters a burning cell (mover blocks it; H1 unit test) | as designed |

- Goblin Scout (default pattern): its own pattern skill moved it off the field at 0.85 s; the brain then read the
  seals as urgent (0.73 s left) and correctly waited. Logged in `brainlog_B_scout_lone.txt`.
- **Caveat:** `--pattern=wolf` runs the wolf's behaviour on the match's Goblin Scout art (demo limitation; the
  sprite is not the wolf).

## 7. Authoritative synchronization

- Seal records are built in `_on_cast_scheduled` from the event's cells and `at`. The blast phase starts at exactly
  `at` (`FuseFx.phase`). They are marked by the same `impact_resolved` that applies the damage.
- Tests:
  - `tests/unit/art/fuse_fx_test.gd`: 22 checks.
  - `hoa_loi_flow_test.gd` `test_visual_sync`: 8 new checks in a real CombatView. No record during the cast; one per
    armed cell with `at` == the arbiter's event time; the Mage free during the fuse; all records armed (no flame)
    before the blast; all blast on the detonation tick; caster death leaves nothing.
- Mutations:
  - `at` +0.1 → 2 fails;
  - cleared-cast pruning removed → 1;
  - kind filter removed → 1.
- Logs: every scene's FUSE line shows the blast at the scheduled clock (B/C 2.450, D 2.750 square, A/F 1.950).
- Headless and windowed runs are identical.

**Mage animation:** `cast_gesture` over the fixed 0.45 s cast:
- frames 0–3 lift, frame 4 holds as the coil;
- the palm-out frame 5 lands at about 0.39 s, so the palm is out at the commit;
- frames 6–8 recover after the swing end while the hero is already free;
- the glyph lights cell by cell and flares at 85 %.

**Honest limitation:** the gesture pushes the palm **forward**, not down at the floor, and the book is not raised. The
link "hand → floor seals" relies on the glyph and the seals appearing on the commit. A `cast_ground` clip would fix
it (separate approval).

## 8. Regression

Full suite **217/217 green** (2026-11-09; 216 + the new `fuse_fx_test`):
- `skill_v2_golden_test` unchanged;
- `tram_dia_test`, `ngan_kiem_test`, `ngan_kiem_commitment_test`, `ngan_kiem_full_flow_test` green;
- `hoa_loi_test` (H1 timing, Model A damage, cells, one hit per wave, burn and cleanup unchanged) green;
- `boss_fuse_awareness_test`, `hoa_loi_flow_test` (+ visual sync), `sim_hoa_loi_test` (simulator parity) green;
- `focus_flow_test` passed in this run (the window kept focus, see §1).

## 9. Visual quality review (native 640×360 and 2×)

- **Good:**
  - the sigils read as geometric ground seals in the Mage's amber, distinct from the red enemy telegraph and from
    the burning flames;
  - the 3-2-1 rings read without text;
  - the final cream core and flicker read as "about to blow";
  - the simultaneous columns are big, bright and clearly tile-born;
  - the decay sinks into the tile (no beam to the sky);
  - the burning aftermath is the existing, recognisable burn.
- **Tuned on review:**
  - the columns were 1.75 cells tall (the back row reached the HUD title) and too wide → 1.15 and 0.64 cell;
  - the decay lifted off as a floating block → it now sinks and tapers;
  - the smooth cone read like a traffic cone → ragged flame edge, cream core only low and early.
- **Remaining concerns:**
  - for about 0.25 s the column covers the boss sprite on its cell (the impact moment), and the HIT number stays
    readable over it;
  - the final-warning cream core reads a bit like a blank tile at 2×;
  - smoke squares float slightly above the sinking flame;
  - the 640 px sheets are small for judging; check on a phone.

## 10. Remaining limitations

1. `cast_gesture` palm-forward motion (see §7); no new clip without approval.
2. The demo's `--pattern=wolf` uses the Goblin Scout art.
3. With every exit covered, the brain dodges into another seal (wasted step, unchanged rule).
4. No HUD feedback for a whole cast that fizzles (all cells locked during the 0.45 s); the event data has it.
5. The burn time bar is measured against `hoa_tran`'s 3.0 s (BurnPainter's fixed reference), so a Hỏa Lôi burn
   (2.0 s) starts at 2/3 of the bar — the expiry still reads (the bar empties as it ends); unchanged existing code.
6. Not checked on an Android phone; no audio (A1 not started).
7. Model A balance comparison (A, A + `max_damage_cells` 4, C) is still to do after H2, as you decided.
