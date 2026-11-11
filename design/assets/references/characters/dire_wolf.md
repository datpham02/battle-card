# Master Reference — Dire Wolf (`dire_wolf`)

> One file per character (P1, 2026-11-11). Facts come from the registry entry `unit.dire_wolf`, `art_src/units/dire_wolf/clips.json`, the sheet JSON and the spec; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.dire_wolf`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id / legacy id | `unit.dire_wolf` / ASSET-027 |
| Type / tier | unit / monster |
| Role | Enemy — normal tier, Misty Forest roster v2 (four-legged) |
| Spec | `design/assets/specs/misty-forest-roster-assets.md` |
| Design (approved text) | Lean ragged dire wolf on all four legs, long low body, dark stone-grey fur, shaggy mane matted with dark moss over the shoulders, torn left ear, long muzzle with two pale fangs, small pale eyes, tail low (ASSET-027 Design). |
| Silhouette / proportions | Horizontal body; south-west bbox 46x43, 8 colours; 68 px wide frame so the swaying tail is not cut (feet x = 34). |
| Likeness check | Closest: a Warg (LotR) or Sif (Dark Souls). Differentiated: no saddle, collar, armour or sword, not giant, moss-matted mane, torn ear. |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | none (doi-hinh-rung-suong quick spec §3.3) |
| Anchor image (canonical frame) | `art_src/units/dire_wolf/idle/0.png` — idle frame 0 of the installed source; every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/dire-wolf/rot`, `design/assets/candidates/dire-wolf/anim`, `design/assets/candidates/dire-wolf/clean-68x52` |
| Anchor approval | **approved** — art_src/units/dire_wolf/clips.json source: "approved 2026-11-03" |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | left (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-west |
| Frame | 68x52 art px |
| Anchor rule | feet on the last pixel row, feet x = 34; ≥ 1 transparent px left / right / top (`export_sheets.py` refuses otherwise) |
| Sheet | `assets/art/units/unit_dire_wolf_sheet.png` 413x264, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation: Ink #1B1722; fur #2C2925 / #4A4640 / #5A5650 / #6A6B62; moss #3A4538 / #4A5545; eyes / fangs #EFE6D2. No red, no glow.
- In the installed sheet (`meta.tessera.palette`, 8 colours): `#1B1722`, `#2C2925`, `#3A4538`, `#4A4640`, `#4A5545`, `#5A5650`, `#6A6B62`, `#EFE6D2`
- Master: `art_src/palette/tessera_master.gpl`; ≤ 8 colours per unit; alpha 0 / 255 only; no red `#E5293B` (telegraph), no orange baked in (Burn); adding a colour is the art-director's call (bible §8.4).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | de3a83f9-cd77-4d23-9f95-3cc946143ea4 |
| Image / job ids on record | 3dc9716c, 531650e0, e7c22119, f1dd4464, 130b6a3a (clip groups) |
| Configuration that produced the anchor and clips | create_character_pro_flash 64x64, low top-down, 8 directions, seed 1, template `dog`, palette locked (max 8), style_image = Goblin v3 south rotation (colour off). Clips: animate_character pixminimax south-west, 8 frames (5 gen, 'Gen 5 clip'). |
| Style reference (style_image lineage) | Goblin Scout v3 south rotation; PixelLab `dog` template for the quadruped rig. |
| Post-generation (free, mechanical only) | palette snap to the locked colours, specks < 12 px removed, feet re-planted on the last row, body recentred; region recolour when the model drifted (Knight cape); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a monster (art bible §5.4 / §8.6): `idle`, `step`, `windup`, `hit`, `down`.
Optional clips the code plays when present (fallback otherwise): `brace`, `guard`, `stunned`, `howl`.

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 4 | 250 | loop | installed | unknown | — | src frames 0/2/4/6 |
| `step` | 4 | 100 | loop | installed | unknown | — | nominal; the game paces step by the step cooldown; src 1/3/5/7 |
| `windup` | 4 | 100, 100, 100, 0 | hold_last | installed | unknown | — | crouches to pounce, held until the telegraph ends; src 2/4/6/8 |
| `hit` | 3 | 40 | once | installed | unknown | — | src frames 4-6 (1-3 had a baked red spray; the red mouth was snapped to the fur greys) |
| `down` | 6 | 100, 120, 150, 150, 150, 150 | hold_last | installed | unknown | — | slumps onto its side; src 1/2/3/4/6/8 |

Timing rules: `idle` 125 ms (heroes) / 250–300 ms (enemies) per frame today (bible §8.6 says 0.4 s — the installed timing is the user's accepted feel); `step` is nominal, the game paces it by the step cooldown; `windup` ends on a 0 ms frame held until the telegraph ends; hero casts share the Knight's 9-slot timing 83, 83, 83, 83, 200 (hold frame 4), 50, 83, 100, 133 with the release on frame 5.

## 7. Visual constraints (what a new generation must keep)

- Same anchor: generate from `art_src/units/dire_wolf/idle/0.png` (or the character id) with the first frame pinned; for one-shot clips pin the last frame too.
- Same canvas 68x52, same feet row and feet x; the exporter bottom-aligns shorter sources, never taller ones.
- Identity in the upper half: Horizontal body; south-west bbox 46x43, 8 colours; 68 px wide frame so the swaying tail is not cut (feet x = 34).
- 1 px closed Ink outline; banded shading, light from the upper left; no glow, no smooth gradients, no anti-aliasing fringe (ART_QA_CHECKLIST §B–§D).
- Facing stays left in every frame (the model sometimes turns the back from frame 4: drop those frames, as for the Witch's step_up).
- Effects (bursts, stars, slash smears, red sprays) are never part of the body: delete or drop the frame; VFX are separate packs.
- Allowed variation: pose, cloth / hair / tendril sway, breathing 1–2 px, held weapon angle; not allowed: palette drift, proportions, props disappearing, new accessories.

## 8. Generation lineage

- 2026-11-03 anchor-01 → character de3a83f9 (6 gen) — APPROVED
- 2026-11-03 anim-5clips (5 gen) → clean-68x52 → sheet

## 9. Versions

- **Current:** installed sheet, see §3

## 10. Approval history (from the registry)

| Date | Event | Target | By | Evidence / note |
|---|---|---|---|---|
| 2026-11-11 | registered | asset | — | bootstrapped from disk by asset_registry.py; status by location only |
| 2026-11-03 | user_approved installed→approved | asset | user | art_src/units/dire_wolf/clips.json source: "approved 2026-11-03" |
| 2026-11-11 | note | asset | — | Master Reference created: design/assets/references/characters/dire_wolf.md |

## 11. Open points

- hit frames 1–3 had a baked red spray; red mouth snapped to fur greys (clips.json notes)

Evidence folders: `production/qa/evidence/misty-forest-roster`, `production/qa/evidence/misty-forest-roster-v2`
