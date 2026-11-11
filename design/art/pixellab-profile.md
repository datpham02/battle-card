# PixelLab Animation Profile — Tessera (Kaiten Duel)

Read by the `pixellab-animation-engineer` skill (Phase 0). Project-specific
facts live here; the skill itself stays engine- and game-agnostic.
Sources: `design/assets/specs/swordsman-assets.md`, `design/assets/specs/goblin-scout-assets.md`,
`art_src/units/*/clips.json`, art bible §4, §8 (P3 reserved colours).

## Project

| Key | Value |
|---|---|
| Engine | Godot 4.6 (frames go through `tools/asset-pipeline/export_sheets.py`, which refuses off-palette pixels) |
| Tick base | 60 Hz; `clips.json` stores per-frame milliseconds, so convert ticks × 16.67 and round to whole ms |
| Palette file | `art_src/palette/tessera_master.gpl` (every opaque unit pixel must be in it; adding a colour is the art-director's call) |
| Reserved colours | red = telegraph only (art bible P3); orange = Burn status; never baked into body frames |
| Effects | always separate VFX packs (`assets/art/vfx/`), never in body frames |
| Budget | ask before every paid call; state the cost first (user rule 2026-10-31); verify view/layout before spending (memory `verify-before-spending-gens`) |

## Paths

| Key | Path |
|---|---|
| design_sheets | `design/art/animation-sheets/` |
| candidates | `design/assets/candidates/<character>/` (raw PixelLab output, never accepted art) |
| accepted frames | `art_src/units/<id>/<clip>/<n>.png` + `art_src/units/<id>/clips.json` |
| generation log | the character's spec in `design/assets/specs/` (Generation log table) |
| registry | `design/assets/asset-registry.yaml` — status, approval, PixelLab ids and lineage per unit and per clip (P0, 2026-11-11); `python -X utf8 -I tools/asset-pipeline/asset_registry.py show unit.<id>` |
| master references | `design/assets/references/characters/<id>.md` (P1, one file per character; until then the registry entry + the spec are the reference) |
| evidence | `production/qa/evidence/` |

## Characters

> 2026-11-11: this section covers 2 of the 16 animated units. The other 14 are
> described by their registry entries (`unit.<id>` in
> `design/assets/asset-registry.yaml`: frame, facing, clips, PixelLab character
> id, lineage) and their specs; P1 moves every unit into
> `design/assets/references/characters/`. Facts below for `kiem_si` predate the
> 96×92 canvas change of 2026-11-08 (`body_h` 70, sources bottom-aligned).

### kiem_si — Swordsman (player)

| Key | Value |
|---|---|
| PixelLab character | `2d093318-1ba4-43aa-b843-a5f0fdf62939` (v3 tall anchor, approved 2026-10-31) |
| Anchor image | `art_src/units/kiem_si/idle/0.png` |
| View / direction | low top-down / **south-east** (the game mirrors it for facing left) |
| Frame | 96×70, feet on row 69, feet x 48 (PixMiniMax canvas 96×96: rows 10..79 cropped, feet row 79 there) |
| Identity recap | "a slender young knight about 4.5 heads tall with ash-blond hair falling over the forehead, steel plate armour with square pauldrons, a navy cape with brass trim, holding a long narrow straight sword in the right hand" |
| Mirror policy | mirrored at runtime for facing left (sword hand flips; accepted) |
| Engine that worked | `animate_character` mode `pixminimax`, south-east, 4–8 frames = 1 gen per clip |
| Known generator drift | cape turns skin-coloured in fast frames → recolour navy; impact stars baked into hit frames → delete; specks < 12 px |
| Clips | idle (4), step (4), cast_gesture (9, v4 wind-up 2026-11-01, hold frame 4), hit (3), victory (5), defeat (8), fall (4), awaken (6) — see `art_src/units/kiem_si/clips.json` |
| Open feedback | 2026-11-01: cast_gesture stiffness → fixed by v4 wind-up (`design/art/animation-sheets/kiem_si-cast_gesture.md`); idle: frames 0–2 near-identical and a pop at frame 3 (anim_qa), not yet addressed |

### goblin_scout — Goblin Scout (enemy)

| Key | Value |
|---|---|
| PixelLab character | `3b9516c8-2be0-43e2-b505-c58ba6e254c8` (v3, approved 2026-10-31) |
| Anchor image | `art_src/units/goblin_scout/idle/0.png` |
| View / direction | low top-down / **south-west** |
| Frame | 64×52, feet x 32 (PixMiniMax canvas 68×68: x 2..65, rows 6..57) |
| Identity recap | "a small crouched goblin scout with desaturated olive-green skin, long pointed ears sticking out sideways, a pale moss-green pointed hood, a ragged brown leather jerkin, a short knife at the belt, pale tiny eyes in a dark face" |
| Engine that worked | `animate_character` mode `pixminimax`, south-west, 4–8 frames = 1 gen per clip |
| Known generator drift | red spray baked into hit (red is the telegraph) → delete; turns to face right in later frames → keep frames that face left |
| Clips | idle, step, windup, hit, down — see `art_src/units/goblin_scout/clips.json` |

## QA overrides

None yet; the skill's defaults in `references/animation-qa.md` apply. Planted
clips here keep the feet on row 69 (hero) / the goblin's anchor row.
