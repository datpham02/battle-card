# Integration of an accepted candidate

The path is `tools/asset-pipeline/integrate.py`. It refuses to run unless the
registry entry (or clip) has `acceptance: accepted` and `accepted_evidence`.
Without that it exits **BLOCKED — not accepted** and writes nothing. It never
overwrites a pack directory, a clip folder, or an index key. It never sets
`approved`.

```
python -X utf8 -I tools/asset-pipeline/integrate.py pack <registry id> [--candidate <folder>] [--kind floor|cast|status] [--index-key <name>] [--dry-run] [--no-godot]
python -X utf8 -I tools/asset-pipeline/integrate.py clip <entity id> <clip> --candidate <folder> [--frames clean|raw] [--ms 83,83,...] [--loop loop|once|hold_last|hold] [--dry-run] [--no-godot]
```

`pack` copies the candidate into `assets/art/vfx/<kind>/<pack>/`, adds the
manifest's `index_entry`, runs `fxc check` and `art_check.py asset`, writes
evidence under `production/qa/evidence/integration/`, then
`set-status … installed`. `clip` copies frames into `art_src/units/<id>/<clip>/`,
appends the `clips.json` row, runs `export_sheets.py --units`, then the sheet
tests. `--dry-run` prints the plan. `INTEGRATE_ROOT` points both commands at a
scratch tree; the scripts stay this repository's.

Rehearse there. Do not point it at the real tree until the user has accepted
that candidate. The steps below are what the script does; use them by hand
only when the script cannot (a new clip with no registry row yet, UI / env /
cards, which the script does not install).

Precondition, hand path included: `acceptance: accepted` with the user's words
in `accepted_evidence`. Without it, stop: **BLOCKED — not accepted**.

## Units (clips)

1. Copy the cleaned frames from the candidate folder into
   `art_src/units/<id>/<clip>/<n>.png`; never over an existing clip of the same
   name (a replacement renames the old folder `<clip>-legacy-<date>` only with
   the user's yes, and the registry records `version_retired`).
2. Edit `art_src/units/<id>/clips.json`: clip entry (`name, frames, ms, loop`,
   `note` with the job id and approval date). Ask "May I write" first.
3. `python -X utf8 -I tools/asset-pipeline/export_sheets.py --units <id>` →
   regenerates `assets/art/units/unit_<id>_sheet.png/.json`.
4. `python -X utf8 -I tools/asset-pipeline/export_sheets.py --check` → 0 drift.
5. Godot: `godot --headless --path . -s res://tests/unit/art/sheet_export_test.gd`
   and `sprite_sheet_test.gd` (FAILS=0); for roster enemies also
   `roster_sprite_test.gd`.
6. In-game observation: the demo / capture command the clip's spec names
   (`--write-movie`), screenshot into `production/qa/evidence/<topic>/`.
7. `asset_registry.py set-status unit.<id> installed --clip <clip> --by <who> --evidence "<evidence path>"`
   — `installed` is a state change the tool allows from `accepted`; the user's
   final `approved` comes later, on their word, after they saw it in game.
8. Update the Master Reference §6 row and §8 lineage ("May I write").

## VFX packs

1. Copy `manifest.json` + sheets from the candidate folder to
   `assets/art/vfx/<kind>/<pack>/`; a pack dir that already exists is never
   overwritten (new dir name or the user's explicit yes).
2. Add the `index_entry` the manifest carries to the kind's `index.json`
   (ask "May I write"); for cast packs also the `cast/index.json` mapping
   (`packs`, `impact_packs`, `travel_packs`, `card_casts`).
3. `python -X utf8 -I tools/fx-pipeline/fxc.py check assets/art/vfx/<kind>/<pack> --layer <overlay|floor>`.
4. Godot: `floor_vfx_test.gd`, `vfx_pack_test.gd`, `cast_vfx_test.gd` (FAILS=0).
5. Footage or contact sheet (`tools/qa/impact_contact_sheet.gd`,
   `impact_footage.gd`) into evidence.
6. Registry: `set-status … installed`, `pixelfx.adapter_version` for PixelFX
   packs, `qa` summary, `manifest` regenerated.

## UI / env / cards

Copy to the `production` path the spec names, confirm the `.import` is created
by Godot with the project convention (Lossless, no mipmaps, fix alpha border),
run the view's test where one exists (`hud_skin_test`, `art_assets_test`,
`backdrop_v2_test`), capture, record.

Everything installed this way is still `installed`, not `approved`.
