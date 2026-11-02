# tools/fx-pipeline — code-drawn, square-only skill VFX ("fxkit")

Plan: `docs/plans/animation-pipeline.md`. Research behind it: `docs/research/pixelfx-study.md`.
Pure Python 3 standard library (no Pillow, no ffmpeg, no Node). Run from the repository root.

```bash
python -X utf8 -I tools/fx-pipeline/fxc.py selftest
python -X utf8 -I tools/fx-pipeline/fxc.py build tools/fx-pipeline/recipes/kiem_khi.fx.json
python -X utf8 -I tools/fx-pipeline/fxc.py check <pack folder>... [--layer overlay|floor]
```

## What a build does

For every pack of a recipe and every cell size it lists:

1. renders the component (a pure function of time) at the recipe's fps;
2. checks the code: deterministic, nothing drawn outside the canvas (four seeds), one-shots end empty,
   loops have no seam, no unseeded randomness;
3. writes the pack to `design/assets/candidates/fx-pipeline/<pack>/` (`manifest.json` + `whole.png`, plus
   `behind.png` / `front.png` when both layers are used) in the format `src/art/vfx_pack.gd` already reads;
4. checks the files: alpha 0/255, every colour in `art_src/palette/tessera_master.gpl`, nothing near the
   telegraph red #E5293B, a clear 1 px border, sheet/JSON agreement, overlay one-shots <= 0.35 s,
   disc-shaped clusters, specks, square count;
5. writes `contact.png`, `anim.gif`, `strip12.png` to `production/qa/evidence/fx-pipeline/<recipe>/<pack>/`;
6. composes the skill timeline with the real sprites from `art_src/units/` at the game's own timings
   (`timeline/timeline.gif`, `timeline-keys.png`, `skill_timing.json`) and writes `build-report.md`.

Exit 1 on any FAIL. **Nothing is written into `assets/`**: installing a pack into the game
(`assets/art/vfx/...` + its `index.json` entry, then pointing `cast/index.json` `impact_packs` /
`travel_packs` at it) is a separate, approved step. Each pack's manifest carries the `index_entry` to add.

## Files

| Path | What |
|---|---|
| `fxkit/painter.py` | layers (`behind` under units, `front` over units) and a painter with only squares, bevels, 45° diamonds, rect outlines, lines, polygons, string sprites; local space, flip, colour 0 = draw nothing |
| `fxkit/motion.py` | closed-form `fly`, `shard` (fall, bounce once, rest), `burst`, `cycle`, `stream` |
| `fxkit/rng.py`, `easing.py` | seeded randomness (mulberry32, integer hash); `seg`, `smooth`, `bump`, eases |
| `fxkit/palette.py`, `palettes.json` | master palette + material ramps (0 ink, 1 dark, 2 body, 3 highlight, 4 core), validated on load |
| `fxkit/render.py`, `sheet.py` | sample a component; write the pack |
| `fxkit/check.py` | the checks above |
| `fxkit/preview.py`, `timeline.py` | previews on the real slab; the skill timeline |
| `fxkit/data.py` | `"@source:path"` references into `assets/data/*.json` and the VFX indexes |
| `components/` | reusable components; sizes come from the cell (square unit u ≈ cell h / 10) so effects read at a distance: `square_wave`, `square_slash`, `square_burst`, `square_mark` (steel and any material), `square_gather` (charge on a cell, or an enemy's wind-up at the hand), `flame_burst`, `root_crawl` (variants by entry edge), `root_spike` |
| `recipes/<skill>.fx.json` | one skill: delivery (must match the game data), material (per pack too), packs with `cells` sizes and `variants`, and the timeline scene: `player_cast` (cards) or `enemy_skill` (windup, red warning, followup, footprints) |

Prototypes: `kiem_khi` (Knight, CASTER_TO_TARGET), `hoa_tran` (Fire Mage, DIRECT_MANIFESTATION),
`branch_lattice` (Forest Witch, GROUND_PROPAGATION). Units without sprites appear as grey stand-ins in the timeline.

## Writing a component

Subclass `fxkit.component.Component`: `duration(o)`, `box(o)` -> `(w, h, ox, oy)` (even sizes),
`draw(P, t, o)` drawing into `P["behind"]` / `P["front"]` from `t` and `o` only. Use `o["ramp"]` for colours
and `fxkit.rng.rng(o["seed"], i)` for anything random. Register it in `components/__init__.py`.
Then: say it in one line, build, look at `contact.png` and `strip12.png`, fix the worst thing, build again.
