# Multi-enemy Phase 5 — visual gate (traits on a 2-unit formation)

> **Two runs, in order.** Everything down to the `---` describes the **first** run, 2026-11-14 18:49, taken BEFORE
> the HUD was keyed — that is the run that photographed the defect. The section after the `---` is the **re-shoot**
> at 19:45, after the fix. Both are kept because the first is the evidence and the second is the proof.
> In particular `boss_phases` is called UNTESTED below: true of the first run only. The re-shoot has real frames
> for it, and the later section says so.

Captured 2026-11-14, `tools/qa/multi_enemy_trait_footage.gd`, windowed 1280x720, `--audio-driver Dummy`.
Formation: unit 0 `dire_wolf` (153 HP), unit 1 `goblin_scout` (60 HP), built through `RunConfig.clean_match`.

**What these frames are for.** The unit suites already prove the dispatch reaches the right unit. They cannot prove
the other claim — that a PLAYER can see WHICH enemy a trait fired for. The failure hunted here is not the wrong unit,
it is the ambiguous one.

**Reading test.** Cover the filename. Can someone who does not know which trait is on which unit point at the right
enemy? If they have to guess, the frame fails.

**The carrier alternates between unit 0 and unit 1 on purpose** (monster-skills session). Four traits all on unit 1
would light the same formation slot four times and could not tell "marks the unit it fired for" from "appears on the
right-hand unit". That alternation is what produced the finding below: it is the difference between the unit-0 rows
and the unit-1 row that is diagnostic, and a single-carrier set would have shown none of it.

**Pairs, not single frames.** A lone frame answers *which unit* but not *what happened*; `before` is asserted to be
an ABSENCE (`_is_showing()` false) before it is captured, so the difference cannot be read generously. Both frames of
a pair come from ONE process — a frame index is not a point in sim time, so a pair split across processes can land
"after" earlier than "before".

## Verdict

| Trait | Carrier | Frames | Attribution reads | Verdict |
|---|---|---|---|---|
| `burrow` | **unit 1** | `burrow_unit1_*` | **nothing is drawn at all** | **FAIL** |
| `rebirth` | unit 0 | `rebirth_unit0_*` | pale sprite on the carrier; banner beside the BARE unit | **PASS, with a misleading banner** |
| `shroud` | unit 0 | `shroud_unit0_*` | cloud on the carrier; label floats unattached | **PASS, with an unattached label** |
| `boss_phases` | unit 1 | none | — | **NO FRAME — harness, not product** (see below) |

Measured, not eyeballed (share of pixels changed between the pair, per screen region):

    burrow_unit1:  hero 5.63%  | unit0 0.71%  | unit1 3.36%   <- unit1 change is the goblin's IDLE BOB, not the trait
    rebirth_unit0: hero 11.75% | unit0 11.45% | unit1 0.00%
    shroud_unit0:  hero 13.84% | unit0 5.99%  | unit1 0.00%

The `0.00%` on the bare unit in both unit-0 rows is the half usually skipped: the effect fires on the carrier AND
stays silent on the other unit. Measured, both directions.

## FINDING — trait visuals are drawn for unit 0 only

`CutHudView` reads `_combat.get_trait_host()` at **ten** draw sites, and `CombatView.get_trait_host()` returns
`_trait_host` — unit 0's host, hardcoded (`combat_view.gd:1416`). Every trait carried by unit 1 or later therefore
draws **nothing**: no surface warning, no "burrowed" status, no trait row of any kind.

`burrow_unit1_after.png` is that bug photographed. `get_surface_cell()` is set — the state is correct and the suites
that assert it pass — and the goblin stands on screen unchanged, with no warning circle and no label. **The logic is
right and the player cannot see it.** The 3.36% pixel change in its region is the sprite's idle animation; the crop
shows the unit untouched.

This is the same family as the `_apply_pattern_phase` residue (`combat_view.gd:3207/3244`): a path that is correct
for a solo boss and silently does nothing for a formation. It is larger — ten sites, all player-facing.

### Worse than silent in one place

`_draw_hazard_traits_039` draws the shroud cloud over `get_state().enemy_footprint_cells()` — **unit 0's footprint**,
whatever unit is actually shrouding. So a shroud on unit 1 does not fail quietly: it paints the cloud **on the wrong
enemy**. The `shroud_unit0` pair above passes only because the carrier happened to be unit 0; had the alternation put
shroud on unit 1, that frame would have shown a confident, legible, wrong answer.

That is the ambiguous-unit failure in its most dangerous form — not "the player cannot tell", but "the player is told
something false". It is also why a capture set with a fixed carrier is worthless here: whichever slot it picked,
half of these defects would look like the other half's correct behaviour.

A twelfth site sits outside the HUD: `floor_dynamic_layer.gd:108` read unit 0's host for the slam cracks, so a slam
carried by any other unit cracked cells the floor never drew. Fixed 2026-11-14 (keyed loop, same shape as the
`root_seal` loop beneath it, which has been keyed since Phase 4).

The ten CutHudView sites need their owner's hand-off before they can be touched.

## Two legibility defects found alongside it

1. **`REVIVING 4.0 s` renders top-right, adjacent to the BARE unit** while the reviving unit is the wolf in the
   middle. A reader following the banner points at the wrong enemy. The pale sprite tint is the only honest signal.
2. **`CLOUDED` floats top-centre, attached to nothing.** With one enemy that was unambiguous; with two it names no
   one. The cloud sprite carries the attribution; the label does not.

Both pass the reading test only because the SPRITE changes. Per-unit markers are needed, not bigger effects.

## `boss_phases` — no frame in THIS run, and why that was my fault not the product's

*(Superseded by the re-shoot below, which has real frames for it. Kept because the cause is worth reading.)*

Params were `at_hp_ratio: 0.99` on unit 1, which requires unit 1's HP to fall below 99%. Nothing in a passive capture
damages unit 1, so the phase never armed and the run reported
`NO FRAME - the trait never became visible within 20.0s of sim time`. The bound is named in the report precisely so
this is distinguishable from a stalled tree. **This trait is UNTESTED by this gate** — it is not evidence of a
working `boss_phases`, and the row above must not be read as one. Re-run needs the carrier damaged first.


---

# AFTER THE FIX — re-shot 2026-11-14 19:45

Ten `CutHudView` sites keyed; `floor_dynamic_layer.gd:108` keyed earlier. Eight suites green
(`multi_enemy_traits` 31, `hunter_mark_attribution` 7, `multi_enemy_resolver` 49, `region_traits`,
`pattern_phase0_effects`, `final_boss_phase`, `forest_witch_phases`, `combat_config_hud`), no SCRIPT ERROR.

**The capture now carries its own tree guard**, with a wider scope than the headless runner's, printed with the
result: `(^|/)project\.godot$|^assets/art/|\.(gd|json|csv|tres|tscn|cfg|sh|png|import|uid)$`, **24712 files,
TREE STABLE**. The first version of that guard fired on every run because it hashed the tool's own output PNGs —
an always-red gate, the same defect as the runner's misplaced baseline this morning. The output directory is now
excluded (the frames are the run's product, not its input) and the verdict names each path that moved.

| Trait | Carrier | Before the fix | After the fix |
|---|---|---|---|
| `burrow` | unit 1 | nothing drawn at all | **gold surfacing marker + `SURFACING` + `BURROWED`** |
| `boss_phases` | unit 1 | NO FRAME (harness) + banner could never fire for unit 1 | **`PHASE 2` banner fires, carrier flashes** |
| `rebirth` | unit 0 | drew (carrier was unit 0) | unchanged |
| `shroud` | unit 1 | would have drawn on **unit 0** | **cloud on unit 1, unit 0 clean** |

## The wrong-owner fix is photographed, and it needed a separate run to be

`shroud`'s default carrier is unit 0, so the standard four-trait set **fixes that bug without ever showing it** —
the one defect that could state something false is the one the alternation happens to hide. Re-shot with
`shroud@1`: `shroud_unit1_state.png` shows the cloud on the goblin (unit 1, 60 HP) with the wolf clean. Before the
fix the cloud would have sat on the wolf.

That frame is a **single frame, filed as one**, not half a pair. `shroud` has no off state — it is on from the
moment it exists and lifts only while the unit is pinned or casting — so the absence assertion correctly refused to
fake a `before`. A lone frame cannot show *what happened*; it can show *which unit*, and for this defect which-unit
is the entire claim. The report line says so rather than leaving a reader to assume a pair.

## What is still weak: screen-wide cues name no unit

Fixed does not mean legible. Four cues are drawn once for the whole screen and cannot point at a carrier:

| Cue | Reads as |
|---|---|
| `PHASE 2` banner | full-width, names no unit |
| `BURROWED` | top-left strip, names no unit |
| `CLOUDED` | top-centre, names no unit |
| `REVIVING 4.0 s` | top-right — **nearest the BARE unit** in the rebirth frames |

Attribution is carried entirely by the per-unit cue: the cloud on the body, the pale tint, the carrier's flash. The
`burrow` marker is a middle case — it marks the **cell** the unit will surface in, not the unit, so with two enemies
a reader still guesses which one went under. These are design questions, not code defects, and they are the
remaining Phase 5 visual debt.

## Measurement caveat, stated rather than buried

`pair_diff.gd` measures FIXED screen rectangles while the units stand wherever the formation puts them. So
`unit1_right 0.00%` means "nothing changed inside that rectangle" — which is only evidence of the bare unit staying
silent **if the bare unit is inside it**. In the `rebirth` and `shroud` runs the bare unit sat outside the measured
rect, so those `0.00%` readings are weaker than they look. The attribution claims above rest on the frames, not on
those numbers.
