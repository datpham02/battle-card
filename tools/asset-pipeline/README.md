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

Current sheets (slice 1):

| Unit | Frame | Sheet | Clips |
|---|---|---|---|
| `kiem_si` (ASSET-001, v3 tall) | 96x70 | `unit_kiem_si_sheet.png` 872x780 | idle (4), step (4), step_forward (7), step_back (7), step_down (6), cast_gesture (9), hit (3), victory (5), defeat (8), fall (4), awaken (6) |
| `goblin_scout` (ASSET-003, v3) | 64x52 | `unit_goblin_scout_sheet.png` 519x264 | idle (4), step (4), windup (2, last held), hit (3), down (8) |

`/asset-audit` has no configurable asset list in this project, so this table
is the pipeline's own register of exported sheets: add a row per unit.

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
