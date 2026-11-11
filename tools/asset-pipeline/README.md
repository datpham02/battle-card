# Asset pipeline — unit sprite sheets

`export_sheets.py` turns loose PNG frames into the per-unit sprite sheet and
Aseprite-style JSON that the battle art layer reads (art bible §8.1, §8.6).
It is the **stand-in for the `.aseprite` route**: §8.1 names Aseprite as the
drawing source, with one tag per clip and the frame durations in the tags.
Until an artist works in Aseprite, the source is a folder of PNGs plus a
`clips.json` (the user's 2026-10-31 decision, Story 045). The JSON the
exporter writes is the Aseprite "array" layout, so when an `.aseprite` file
replaces the folder, Aseprite's own `--sheet --data` export can produce the
same files and nothing in the engine changes.

Pure Python 3, standard library only (this machine has no Pillow). Always run
it as `python -X utf8 -I` (the project convention: UTF-8 console, isolated
imports).

## Run

```
python -X utf8 -I tools/asset-pipeline/export_sheets.py
```

writes, for every folder under `art_src/units/`:

| Output | What |
|---|---|
| `assets/art/units/unit_<id>_sheet.png` | RGBA 8-bit, one row per clip, fixed cells of the unit's frame size, 1 px transparent gutter between cells |
| `assets/art/units/unit_<id>_sheet.json` | Aseprite array format: `frames[]` + `meta.frameTags[]` + `meta.tessera` |

The exporter is deterministic (same input, same bytes). CI runs

```
python -X utf8 -I tools/asset-pipeline/export_sheets.py --check
```

which rebuilds in memory, compares with the committed files and exits 1 on
any drift (2 on a rule violation, 0 when everything matches). `--units a,b`
limits a run to some units; `--root` points at another checkout.

Current sheets (16 units, 2026-11-11 — the register of record is now
`design/assets/asset-registry.yaml`, see `asset_registry.py` below; this table
is a convenience copy):

| Unit | Frame | Sheet | Clips |
|---|---|---|---|
| `giao_si` (ASSET-033, hero) | 96x72 | `unit_giao_si_sheet.png` 872x875 | idle (8), draw (8), step (4), step_forward (7), step_back (7), step_down (7), cast_gesture (9), hit (3), victory (8), defeat (8), fall (4), awaken (5) |
| `kiem_si` (ASSET-001, hero) | 96x92 (`body_h` 70) | `unit_kiem_si_sheet.png` 872x1394 | idle (8), draw (8), step (4), step_forward (7), step_back (7), step_up (7), step_down (7), cast_gesture (9), cast_forward (9), cast_summon (9), hit (3), victory (5), defeat (8), fall (4), awaken (6) |
| `phap_su` (ASSET-030, hero) | 96x70 | `unit_phap_su_sheet.png` 872x851 | idle (8), draw (8), step (4), step_forward (7), step_back (7), step_down (7), cast_gesture (9), hit (3), victory (8), defeat (8), fall (4), awaken (8) |
| `sat_thu` (ASSET-031, hero) | 96x70 | `unit_sat_thu_sheet.png` 872x780 | idle (8), draw (8), step (4), step_forward (7), step_down (7), cast_gesture (9), hit (3), victory (8), defeat (8), fall (4), awaken (5) |
| `tho_san` (ASSET-032, hero) | 96x72 | `unit_tho_san_sheet.png` 872x875 | idle (8), draw (8), step (4), step_forward (7), step_back (5), step_down (7), cast_gesture (9), hit (3), victory (8), defeat (8), fall (4), awaken (5) |
| `dire_wolf` (ASSET-027, monster) | 68x52 | `unit_dire_wolf_sheet.png` 413x264 | idle (4), step (4), windup (4), hit (3), down (6) |
| `goblin_archer` (ASSET-026, monster) | 64x52 | `unit_goblin_archer_sheet.png` 389x264 | idle (4), step (4), windup (4), hit (3), down (6) |
| `goblin_scout` (ASSET-003, monster) | 64x52 | `unit_goblin_scout_sheet.png` 519x264 | idle (4), step (4), windup (2, last held), hit (3), down (8) |
| `greycap_sporeling` (ASSET-022, monster) | 64x52 | `unit_greycap_sporeling_sheet.png` 389x264 | idle (4), step (4), windup (4), hit (3), down (6) |
| `mossbound_sentry` (ASSET-023, monster) | 64x52 | `unit_mossbound_sentry_sheet.png` 389x317 | idle (4), step (4), windup (4), brace (4), hit (3), down (6) |
| `rootling` (ASSET-021, monster) | 64x52 | `unit_rootling_sheet.png` 389x264 | idle (4), step (4), windup (4), hit (3), down (6) |
| `ancient_root_sentinel` (ASSET-024, elite) | 80x80 | `unit_ancient_root_sentinel_sheet.png` 485x485 | idle (4), step (4), windup (4), stunned (4), hit (3), down (6) |
| `mistbriar_matron` (ASSET-025, elite) | 80x80 | `unit_mistbriar_matron_sheet.png` 323x485 | idle (4), step (4), windup (4), guard (4), hit (3), down (4) |
| `wolf_alpha` (ASSET-028, elite) | 80x80 | `unit_wolf_alpha_sheet.png` 485x485 | idle (4), step (4), windup (4), howl (4), hit (3), down (6) |
| `forest_witch` (ASSET-020, boss) | 160x130 | `unit_forest_witch_sheet.png` 1287x1309 | idle (4), step_forward (7), step_back (7), step_up (5), step_down (7), windup (3), windup_heavy (3), phase_shift (8), hit (3), down (6) |
| `goblin_warlock` (ASSET-029, boss) | 160x130 | `unit_goblin_warlock_sheet.png` 804x916 | idle (4), step (4), windup (4), windup_heavy (4), phase_shift (4), hit (3), down (5) |

## Asset registry — `asset_registry.py`

`design/assets/asset-registry.yaml` is the single source of truth for every art
asset's lifecycle (`candidate → accepted → installed → approved`, `legacy`),
files, PixelLab ids, lineage and the user's recorded acceptance / approval.
`design/assets/asset-manifest.md` is generated from it. Full schema and rules:
`docs/art/ASSET_REGISTRY.md`.

```
python -X utf8 -I tools/asset-pipeline/asset_registry.py validate     # YAML + schema + lifecycle
python -X utf8 -I tools/asset-pipeline/asset_registry.py check        # + files, duplicates, orphans, drift
python -X utf8 -I tools/asset-pipeline/asset_registry.py manifest     # regenerate asset-manifest.md
python -X utf8 -I tools/asset-pipeline/asset_registry.py bootstrap    # list production art missing from the registry (--add-missing appends)
python -X utf8 -I tools/asset-pipeline/asset_registry.py set-acceptance unit.kiem_si accepted --clip idle --by user --evidence "<file>: <the user's words>"
python -X utf8 -I tools/asset-pipeline/asset_registry.py set-status unit.kiem_si approved --clip idle --by user --evidence "<file>: <the user's words>"
python -X utf8 -I tools/asset-pipeline/asset_registry.py set-production <id> <path> [path...]
```

No PyYAML on this machine: the tool reads and writes its own strict YAML subset
(2-space indent, no anchors, no multi-line scalars). Keep hand edits in that form
and run `check` afterwards.

`set-production` records the installed file paths on an entry. It does not
change acceptance or approval.

## Installing an accepted candidate — `integrate.py`

`integrate.py` is the production install path (P4). It stops with
`BLOCKED — not accepted` unless that entry or clip is `acceptance: accepted`
with `accepted_evidence`. It never overwrites a destination that already
exists, and it never sets `approved`.

```
python -X utf8 -I tools/asset-pipeline/integrate.py pack <registry id> [--candidate DIR] [--kind floor|cast|status] [--dry-run] [--no-godot]
python -X utf8 -I tools/asset-pipeline/integrate.py clip <entity id> <clip> --candidate DIR [--frames clean|raw] [--dry-run] [--no-godot]
```

`pack` copies the candidate to `assets/art/vfx/<kind>/<pack>/`, writes the
index entry, runs `fxc check` and `art_check.py asset`, then
`set-status installed`. `clip` copies frames under `art_src/units/<id>/<clip>/`,
appends `clips.json`, runs `export_sheets.py --units`, then the sheet tests.
Evidence lands in `production/qa/evidence/integration/`. `--dry-run` writes
nothing. Set `INTEGRATE_ROOT` to rehearse against a scratch tree. Details:
`.claude/skills/game-art-workflow/references/integration.md`.

## Source layout

```
art_src/                      <- .gdignore: Godot never imports the sources
  palette/tessera_master.gpl  <- every colour a unit frame may use (GIMP palette)
  units/<id>/clips.json       <- clip order, frames, ms per frame, loop kind, facing
  units/<id>/<clip>/<n>.png   <- one RGBA frame per file, n from 0
```

`<id>` is the data id (`kiem_si`, `goblin_scout`, ...), never the display
name. Frames are plain 8-bit PNGs (RGBA, RGB, palette or grey are all read);
every frame of a unit has the unit's frame size, alpha is only 0 or 255, the
left, right and top edge rows are transparent (§8.3; the feet touch the bottom
row), and every opaque colour is in the palette, at most 8 per unit (§8.9 #4).

`clips.json`:

```json
{
  "id": "goblin_scout",
  "asset": "ASSET-003",
  "frame": {"w": 32, "h": 48},
  "facing": "left",
  "clips": [
    {"name": "idle",   "frames": ["idle/0.png", "idle/1.png"], "ms": [400, 400], "loop": "loop"},
    {"name": "windup", "frames": ["windup/0.png"],             "ms": [0],        "loop": "hold"}
  ]
}
```

- `clips` is the row order of the sheet (top to bottom) and the `frameTags`
  order of the JSON.
- `ms` has one entry per frame; `0` means "no own duration" (held by code).
- `loop` is one of `loop`, `once`, `hold_last`, `hold` (§8.6).
- `facing` is the direction the drawn unit faces, `right` or `left`. The
  battle layer mirrors a unit when its side needs the other direction.

## Output JSON

Aseprite's array layout, plus one extension block:

```
frames[]            filename "<id>_<clip>_<n>", frame {x,y,w,h}, rotated false,
                    trimmed false, spriteSourceSize, sourceSize, duration (ms)
meta.image          "unit_<id>_sheet.png"
meta.size           {w, h}
meta.scale          "1"
meta.frameTags[]    {name, from, to, direction "forward"}  — one per clip
meta.tessera        {unit, asset, facing, frame {w,h}, gutter, columns,
                     loop {<tag>: loop|once|hold_last|hold}, palette [hex...]}
```

The engine draws with `draw_texture_rect_region` using `frames[i].frame`,
walks a clip with `frameTags` and reads the hold rule from
`meta.tessera.loop[tag]` (§8.6).

## Adding a unit

1. Create `art_src/units/<id>/` with one folder per clip and `0.png`,
   `1.png`, ... inside; write `clips.json` as above. Every colour must already
   be in `art_src/palette/tessera_master.gpl` (adding one is the art
   director's call, §8.4).
2. Run the exporter, then `godot --headless --path . --import` once so the
   `.import` file for the new sheet exists.
3. Open `assets/art/units/unit_<id>_sheet.png.import` and make sure of
   `compress/mode=0` (Lossless), `mipmaps/generate=false`,
   `process/fix_alpha_border=true`, `process/premult_alpha=false` (§8.7);
   set `detect_3d/compress_to=0` so a stray 3D use can never switch the
   texture to VRAM compression. Commit the `.import` file with the sheet:
   under `assets/art/` it is part of the asset.
4. Add the unit to `tests/unit/art/sheet_export_test.gd` (expected clips and
   durations) and to the table above.
5. Run `--check` and the test suite; both must pass before the commit.

## Naming

`[group]_[id]_[variant]_[size]` per §8.1: `unit_kiem_si_sheet`,
`unit_goblin_scout_alt_sheet`. Monster palette variants are exported as their
own sheets by script from the base frames (§8.4), never swapped at runtime.
