# fx-pipeline assets — production log

Packs made by `tools/fx-pipeline` (code-drawn, square-only, 0 generations). Plan:
`docs/plans/animation-pipeline.md`. One row per build that a person looked at. Status of every pack:
**Candidate** (in `design/assets/candidates/fx-pipeline/`, not in the game) until the user approves it and it
is installed by a separate step.

## Prototype 1 — Knight, Square Sword Wave (`kiem_khi`, CASTER_TO_TARGET -> burst)

Recipe `tools/fx-pipeline/recipes/kiem_khi.fx.json`, material `steel` (#1B1722 / #5F6F82 / #8FA3B8 /
#EEF4FA / #EFE6D2), seed 7, 20 fps (50 ms). Body: the existing `kiem_si` `cast_gesture` v4 (hold frame 4,
release frame 5), no new frames.

| Pack | Component | Frames | Canvas | Layer / anchor | Role |
|---|---|---|---|---|---|
| `release_square_slash_steel` | `square_slash` | 4 × 50 ms | 86×28 | overlay / hand | the horizontal cut at the release frame |
| `travel_square_wave_steel` | `square_wave` (loop) | 4 × 50 ms | 72×54 | overlay / wave front | the sword qi flying hand -> first cell |
| `impact_burst_big_steel` (+ `_c43x31`) | `square_burst` big | 7 × 50 ms = 0.35 s | 106×88 (72×66) | overlay / ground_center | the big hit on the first cell |
| `impact_burst_small_steel` (+ `_c43x31`) | `square_burst` small | 5 × 50 ms = 0.25 s | 106×74 (72×56) | overlay / ground_center | each further cell |
| `mark_stamp_big_steel` (+ `_c43x31`) | `square_mark` big | 9 × 50 ms = 0.45 s | 64×46 (44×32) | floor / center | squares knocked out over the first cell, under the units |
| `mark_stamp_small_steel` (+ `_c43x31`) | `square_mark` small | 7 × 50 ms = 0.35 s | 64×46 (44×32) | floor / center | the same on each further cell |

| Log | Date | Method | Gens | Result |
|---|---|---|---|---|
| build-01 | 2026-11-02 | fxc build | 0 | First pass. Burst too small, shards clumped and flew off upward, the floor shock read as a dashed selection box; wave was mostly 1 px speckle; release slash nearly invisible (one square in frame 0) |
| build-02 | 2026-11-02 | fxc build | 0 | Frame-by-frame beats (slash: appears / full / breaks / specks; burst: cross + diamond / ring + broken cross / ring breaking); wave = solid stepped chevron + one echo; floor shock replaced by chips. Shards still in the air at the end; chips formed a ring of dots (round) |
| build-03 | 2026-11-02 | fxc build | 0 | Shards drop onto the slab (g 1400, wider spread); chips run to the cell's rectangle (corners + edge midpoints); chevron lean 2 (angular, not crescent-like) |
| build-04 | 2026-11-02 | fxc build | 0 | First-cell hit enlarged (core 9, arms 0.46 of the cell, ring 12 -> 18, 18 shards); small burst arms 3 px and no 1 px tips (read as a twinkle before). All checks pass, 0 warnings. Timeline reviewed in context |
| review | 2026-11-02 | user | — | **"hiệu ứng còn quá nhỏ nhìn từ xa gần như ko thấy gì"**: at 720p (×2) the wave was ~25 art px, shards 3–4 px, and the steel dark step sank into the slab |
| build-05 | 2026-11-02 | fxc build | 0 | Everything sized from the cell: square unit u ≈ cell h / 10 (5 px on 64×46, 3 on 43×31). Wave = sharp ">" of 5 px squares nearly a cell tall (54 px canvas); slash = 5 px band, 2 squares thick; big burst core diamond 0.30 × cell h, cross to 0.62 × cell w, ring 0.45 → 0.66 × cell h; most area in highlight / core colours. New floor pack `square_mark` (under units, lasts longer). First version: a thick square frame — read as a UI selection box, and with the burst's diamond as an "envelope" |
| build-06 | 2026-11-02 | fxc build | 0 | Mark = frame for 2 beats, then 4 corner L pieces: read as a camera reticle. Rejected by eye |
| build-07 | 2026-11-02 | fxc build | 0 | Mark = 8 large bevelled squares knocked out over the slab, lying a beat, shrinking. At an even radius they formed an ellipse of dots (round) |
| build-08 | 2026-11-02 | fxc build | 0 | Diagonal squares go to the corners, so the eight lie on the cell's rectangle; beat 0 left to the burst (the squares piled into one round blob there). 0 FAIL, 0 warnings. Judged on the timeline at 1× (far view) and 2× (720p): slash, wave, hit and the squares left on the slab all read |

Evidence: `production/qa/evidence/fx-pipeline/kiem_khi/` (`<pack>/contact.png`, `anim.gif`, `strip12.png`;
`timeline/timeline.gif`, `timeline-keys.png`, `skill_timing.json`; `build-report.md`).

**Not verified:** the packs have not been drawn by the engine (not installed; the game still plays the code
streak and code shards). The timeline is a flat-board preview without the perspective warp.

**Open for the user:** approve the look; then install (copy + `floor/index.json` entries) and decide whether
the cast index points `impact_packs.burst` and the hero travel at these packs, and whether the release slash
gets a code hook (no field for a release pack exists yet).

**User verdict 2026-11-02:** "Đạt, làm tiếp" (build-08 accepted as the look for prototype 1).

### Installed in the game (2026-11-02, user: "oke làm đi")

- Files: `assets/art/vfx/cast/{travel_square_wave_steel,release_square_slash_steel}/`,
  `assets/art/vfx/floor/{impact_burst_big,impact_burst_small,mark_stamp_big,mark_stamp_small}_steel[_c43x31]/`
  (manifest + PNGs, imported Lossless / no mipmaps like the PixelLab packs).
- `assets/art/vfx/cast/index.json`: new entry `square_wave_steel` (sword_wave's timing; `dir` = the travel pack,
  `travel_draw` "" so the art is drawn, `impact` / `cell_burst` / `impact_mark` / `cell_mark` / `release`, flood
  squares 0); `units.kiem_si` -> `square_wave_steel`. **`sword_wave` is unchanged** (rollback = point `kiem_si`
  back). `assets/art/vfx/floor/index.json`: 8 entries with `cell` sizes.
- Code (presentation only, no combat logic): `FloorVfx.variant_for` + `draw` picks the variant made for the nearest
  cell; `CastVfx.release_entry / release_elapsed / packs_replace_shards`; `CombatView._play_hero_wave` plays the
  floor marks; `OverlayLayer.release_state` draws the cut at the hand; `OverlayLayer._side_items` leaves out the code
  flash and code shards for a cast whose impacts are packs (in game the white flash frame read as a UI box over the
  burst; every other card keeps them).
- Tests: `tests/unit/art/cast_vfx_test.gd` (mapping, release timing, packs drawable), `floor_vfx_test.gd` (16 pack
  ids incl. the new 8, `test_variant_for_picks_the_nearest_cell`).
- In-game evidence (`--demo=cast_live --cast-card=kiem_khi --cast-cells=4 --seed=1`, Movie Maker 30 fps):
  `production/qa/evidence/fx-pipeline/kiem_khi/in-game/01`–`08` (3x3 board 64x46-class cells, 5x5 board -> the
  `_c43x31` variants). Seen: the cut at the hand on the slash frame, the sword qi crossing, the big burst on the first
  cell, small bursts and floor squares spreading, no code frame over them, the perspective floor warping the floor
  squares. The enemy in the capture is the red placeholder of `goblin_warrior` (no sprite), not part of this work.

## Prototype 2 — Fire Mage, Square Flame Impact (`hoa_tran`, DIRECT_MANIFESTATION -> burn)

Recipe `tools/fx-pipeline/recipes/hoa_tran.fx.json`, 5-cell plus mask (the card needs >= 5 cells), seed 11, 20 fps.
Ramps `charcoal` (gather: #3A2A26 / #F0A030 / #FFB21F / Ivory) and `burn` (#3A2A26 / #FF7A1F / #FFB21F / Ivory).
**The Mage has no sprite yet:** the timeline uses a grey stand-in with a stepped hat and the art bible's 0.2 s
cast gesture as a 2 px push.

| Pack | Component | Frames | Canvas (64×46) | Layer / anchor | Role |
|---|---|---|---|---|---|
| `gather_flame_charcoal` (+ `_c43x31`) | `square_gather` (loop) | 8 × 50 ms | 72×56 | floor / center | fire squares drawn into each target cell while the swing charges |
| `impact_flame_burn` (+ `_c43x31`) | `flame_burst` | 7 × 50 ms = 0.35 s | 94×116 | overlay / ground_center | three tongues of squared flame on a burning base, torn into rising chunks |
| `mark_embers_burn` (+ `_c43x31`) | `square_mark` small (reused) | 7 × 50 ms | 64×46 | floor / center | embers lying on the cell, then the game's `burning_cell` loop takes over |

| Log | Date | Method | Gens | Result |
|---|---|---|---|---|
| build-09 | 2026-11-02 | fxc build | 0 | Flame spilled out of its canvas (bottom: sparks land 0.3 cell in front) — fixed in the box |
| build-10 | 2026-11-02 | fxc build | 0 | One symmetric stepped pyramid with an ivory band at its foot read as a **traffic cone**; gather squares 2–3 px too small at 1× |
| build-11 | 2026-11-02 | fxc build | 0 | Flame = burning base + three tongues of different heights that lean and flicker, one darker row each (the horizontal stripe), ivory only in the middle; gather squares u px, 12 of them, core u + 3. 0 FAIL, 0 warnings; read at 1× and 2× |

## Prototype 3 — Forest Witch, Root Propagation (`branch_lattice`, GROUND_PROPAGATION -> thorns)

Recipe `tools/fx-pipeline/recipes/branch_lattice.fx.json`, boss arena `boss_hall` (6×4 per side, cell 45×39 at
720p), the L pattern + its followup cell, seed 23. Ramps `root` (Ink / #66523F / #9A7D5E / #B89A6A / Ivory) and
`ivory` (wind-up). **The Witch has no sprite yet:** 2×2 grey stand-in (96×80). Target = the real Swordsman sprite.

| Pack | Component | Frames | Canvas (64×46 / 45×39) | Layer / anchor | Role |
|---|---|---|---|---|---|
| `windup_gather_ivory` | `square_gather` (loop, reused) | 8 × 50 ms | 34×34 | overlay / hand | art bible §3 wind-up: ivory squares gathering at the back hand |
| `root_crawl_wood_from_{e,w,n,s}` (+ `_c45x39`) | `root_crawl` | 14 × 50 ms | 64×46 / 46×40 | floor / center | a tapering root crawling across the cell from the edge it came from, two branches, an ink seam ahead |
| `root_spike_wood` (+ `_c45x39`) | `root_spike` | 7 × 50 ms = 0.35 s | 84×84 / 60×74 | overlay / ground_center | three hooked root thorns punching up one after another, hold, sink |

| Log | Date | Method | Gens | Result |
|---|---|---|---|---|
| build-09 | 2026-11-02 | fxc build | 0 | Roots touched the frame border (path length vs inset) — fixed |
| build-10 | 2026-11-02 | fxc build | 0 | Spikes as stacked squares read as **bamboo poles**; the root as evenly bevelled squares read as a ribbed stick; 1 px rootlets = hatching noise |
| build-11 | 2026-11-02 | fxc build | 0 | Thorns drawn row by row as tapering hooked horns (PixelFX thorns, without light); root = continuous tapering band with a lit and a dark edge; rootlets dropped. Wind-up squares 3 -> 4 px (invisible at 1×) |
| build-12 | 2026-11-02 | fxc build | 0 | The root started 0.05 s before its spike, so the spike covered it and the root showed only *after* it: crawl now starts 0.2 s before each cell's arrival (inside the red warning; path is animation only, ADR-0001 A1). 0 FAIL, 0 warnings |

**Open for the user (game data, not changed):** `combat.json timing.delivery.GROUND_PROPAGATION.step_sec` is 0.06 s,
so the three L cells are reached within 0.12 s: the spikes read as one burst more than "cell by cell". 0.12–0.15 s
would make the propagation readable; it is a tuning value in game data, so it is the user's call.

## Checker change (build-11)

`round_shape` now also requires all four corners of the cluster's box to be empty (a disc leaves them empty; two
touching squares do not). It still flags the 31 disc clusters of the PixelLab `floor/big_burst` pack.

## Observation on existing packs (not changed)

`fxc check` on the PixelLab packs the sword cast used before Task 5: `floor/big_burst` 9 × 50 ms = 450 ms over
units and `floor/small_burst` 405 ms (art bible §1 allows <= 0.35 s over a unit), both with 6 colours outside
the master palette (#7A5A1E, #A9BCDD, #FFD45C, #FFE9A8, #FFF1C2, #FFFFFF), `big_burst` with 31 disc-shaped
clusters. Neither is played by a card today (`impact_packs` all ""), so this is a note, not a defect.
