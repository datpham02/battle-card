# VFX Scale & Impact Guide

**Status:** draft for approval (2026-11-08). **Applies to:** every skill VFX, cast clip and floor stamp in battle.
**Measured in:** the real battle scene at native 640×360 (`--demo=tram_live`, Kiếm sĩ vs Goblin Scout, `rect` arena).

## 1. Reference units (measure everything against these)

| Unit | Native px (640×360) | Notes |
|---|---|---|
| **Tile width (W)** | **60** (flat cell 64, drawn top row ~59) | the floor perspective narrows back rows a little |
| **Tile height (H)** | **43** (flat cell 46, drawn top row ~40) | |
| **Knight height (K)** | **64** | ≈ 1.5 H; the Goblin Scout is 46 |
| **Space above the arena** | ~1.3 H above the top row before the HUD | anything taller collides with the HP bar |

Write sizes as tile ratios ("1.35 H"), never as raw pixels: the ratio survives a new arena, the pixels do not.
Desktop shows the same art at 2× (1280×720); judge sizes at native 640×360, then check 2×.

## 2. Intensity tiers

| Tier | Used for | Primary effect size | Duration of the peak | Extra weight allowed |
|---|---|---|---|---|
| **MINOR** | basic cards, status ticks, small hits | ≤ 1 W | ≤ 0.15 s | target flash + 2 px target shake (existing `hit_feel`) |
| **MAJOR** | rare/epic damage skills (e.g. **Trảm Địa** eruption) | 1.2–1.6 W, 1.5–2 H | 0.15–0.3 s | + secondary impacts, floor mark that lingers |
| **SIGNATURE** | a hero's identity skill (e.g. **Ngàn Kiếm**), Awakening | MAJOR sizes, finale +30–50 % | finale 0.3–0.4 s | + a distinct finale beat; optional board shake (§6) |

One cast has **one** primary. Everything else in that cast is secondary and visibly smaller.

## 3. Size targets

| Element | Target | Why |
|---|---|---|
| Projectile / travelling wave | 0.5–0.8 W | must not hide the cells it crosses |
| Primary explosion | 1.2–1.6 W, 1.5–2 H | reads as "this tile got hit hard" without covering neighbours |
| Secondary impacts | 0.7–1 W | one per extra hit cell, never as big as the primary |
| Spectral / summoned weapons | 1.3–1.8 H tall | taller than the Knight's own sword so they read as magic, not props |
| Blade-ground impact | 0.8–1.2 W | the contact flash sits inside its tile |
| Signature finale | +30–50 % over its own normal beat | emphasis comes from contrast with the beats before it |
| Floor mark / scorch | ≤ 1.1 W | marks stay tile-exact so the board stays readable |

## 4. Hierarchy: primary vs secondary

- **Primary** = the authoritative damage moment on the main cell: biggest, brightest (core white), first in draw
  priority, the only one that may break the tile outline.
- **Secondary** = extra cells, shards, dust, rings: ≤ 0.75 × the primary's size, the body/edge tones of the ramp
  only (no core white), shorter.
- **Tertiary** = lingering marks and particles: floor-flat, low alpha, never above units.
- A cast that hits several cells in a row (Ngàn Kiếm) keeps every beat at secondary weight except the **finale**.

## 5. Timing principles

- **The visual contact frame equals the authoritative event time** (`at` from the resolver). Never move damage to
  match art; move art to match damage.
- Anticipation ≥ 0.1 s before contact (hover, wind-up, shadow darkening). The telegraph lasts as long as gameplay
  says, not as long as the art wants.
- Peak (flash) 1–3 frames at 60 fps, then decay over 0.15–0.35 s.
- Staggered beats (multi-hit): ≥ 0.1 s apart so each contact reads; Ngàn Kiếm uses 0.12 s.
- Judge timing at 1× and 2× game speed (memory: VFX readable from afar).

## 6. Weight without changing gameplay

- **Target shake:** the existing `hit_feel` (2 px, 0.12 s, off under reduce motion). Keep for all tiers.
- **Board shake (SIGNATURE finale only):** the board, units and VFX offset 2 px for ≤ 0.15 s, draw-only; the far
  backdrop and the HUD stay still; off under reduce motion. Built for Ngàn Kiếm: `SkyDropFx.board_shake` +
  `BattleCanvas.set_board_offset`.
- **Hit-stop: not used.** The combat clock is real time; freezing it would shift enemy timings (gameplay). A
  "visual hit-stop" (holding the VFX frame 2 frames while the clock runs) is allowed for the finale only.
- **No full-screen flashes.** Brightness stays local to the hit tile(s).
- Reduce motion: no shake, no tremble, no trails, fewer particles; contact frames and telegraphs unchanged.

## 7. Pixel-art sizing rules

- Author at the size it is shown. **No non-integer runtime scaling** of pixel art (it smears pixels). Only 1× or 2×.
- Code-drawn VFX (SkyDropFx, surge fronts) scale by rebuilding geometry in whole pixels, never by a transform.
- Nearest-neighbour filtering everywhere; pivots on whole pixels (anchor `ground_center` for floor packs).
- Minimum readable detail: 2 px lines, 3 px squares at native. Anything thinner disappears on a phone.
- Square / block fragments only (Tessera: magic is geometric blocks), angular shapes, no circles.

## 8. Layering and readability

Back to front:

1. floor (tile shadows, telegraph fills, marks)
2. back-row VFX
3. units
4. front-row VFX
5. HUD

- Sort sky/air VFX back rows first, so nearer ones overlap farther ones.
- Tall VFX stacked in one column: move the BACK one aside by a few px while it waits (visual-only), and bring it home
  before the contact frame. Never shrink everything to fit.
- VFX waiting over a unit: lift it above the unit's head where the HUD allows, and make it see-through until it acts.
- Cap every hover, trail and upward fragment below the HUD band (Ngàn Kiếm: y 18 at 640×360).
- **Hitboxes stay tile-exact:** shadows, telegraphs and marks are clipped to their cells. Big art may overflow its
  tile, but the floor read never lies about which cells are hit.
- Enemy telegraph red is reserved: player VFX never use `#E5293B`.
- An Ink (dark) edge around bright VFX keeps them readable over the light floor.

## 9. Mobile performance

- Code-drawn rect VFX: budget ≤ 400 rects per frame for the whole overlay (five Ngàn Kiếm swords peak at 114 sword/impact rects, shadows excluded).
- Frame packs: ≤ 128×128 per frame, ≤ 16 frames, one atlas per pack.
- No per-frame node creation; draw from data (`SkyDropFx`, `OverlayLayer`).
- Particles: ≤ 14 per beat, ≤ 40 alive.

## 10. Current skills against this guide

| Effect | Tier | Measured (native) | Tile ratio | Verdict |
|---|---|---|---|---|
| Ngàn Kiếm sword (before) | SIGNATURE | ~9×24 | 0.55 H | too small (fixed) |
| **Ngàn Kiếm sword (now)** | SIGNATURE | ~19×58 | **1.35 H** | in target |
| Ngàn Kiếm finale sword | SIGNATURE | ~25×75 | 1.75 H (+30 %) | in target |
| Ngàn Kiếm impact (before) | | ~15 | 0.25 W | too small (fixed) |
| **Ngàn Kiếm impact (now)** | | ~51 | **0.85 W** (finale +35 %) | in target |
| Trảm Địa eruption | MAJOR | 48×86 | 0.8 W × 2.0 H | narrower than target, tall column |
| Trảm Địa mark | MAJOR | 64×46 | 1.07 W | in target |
| Trảm Địa secondary burst (small) | | 50×27 | 0.83 W | in target |
| Trảm Địa square-wave travel | | 53×45 | 0.88 W | slightly over the projectile range |

Regression check: `tests/unit/art/sky_drop_fx_test.gd` `test_scale_targets` pins the Ngàn Kiếm ratios.

## 11. Trảm Địa evaluation (approved assets NOT modified)

The eruption is a tall, narrow column (0.8 W × 2.0 H). Height is at the top of the MAJOR range; width is under it.
On the burst tile it never plays alone: the mark (1.07 W), the secondary bursts on the surge cells (0.83 W) and the
cracks widen the read on the ground to about 1.1–1.4 W. In the captures it reads as the primary hit of the cast.

| Option | What | Cost | Recommendation |
|---|---|---|---|
| **A. Keep as is** | no change | 0 | **recommended**: within MAJOR on height and ground read; a column suits "the earth splits upward" |
| B. Runtime scale ×1.25 | draw the pack bigger | 0 | **rejected**: non-integer scaling smears the pixels (§7) |
| C. Re-export wider | free vfx_workbench re-export at 128 px frames, base 1.3 W | 0 credits, new asset | only with your approval and a before/after first; it replaces an approved asset |
