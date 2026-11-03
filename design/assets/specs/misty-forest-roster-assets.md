# Asset Specs — Misty Forest roster (Rừng Sương: 3 normals, 2 elites)

Source design: `design/quick-specs/phase2-misty-forest-2026-11-01.md` section 8 (P2.5); art bible §5.2. All five stand on one
cell. Pipeline as the Goblin Scout v3 (ASSET-003): `create_character_pro_flash` 64x64, low top-down, 8 directions, style
from the Goblin v3 south rotation (outline / detail / shading only), palette locked; the south-west rotation (3/4 facing
left) is the anchor; clips with `animate_character` PixMiniMax south-west; frames cleaned to the 64x52 enemy frame. Every
paid call is approved by the user first.

Plan (2026-11-02): normals idle, step, windup, hit, down (5 clips); Sentry + brace, Sentinel + stunned, Matron + guard.

## ASSET-021 — Rootling (`rootling`)

| Field | Value |
|---|---|
| Design | A small walking knot of grey-moss roots: round root-ball body, no torso or arms, stubby root legs, short tendrils on top, two pale eyes deep in a dark hollow. |
| Palette (locked) | Ink #1B1722; moss #3A4538 / #4A5545 / #5E6B55 / #8FA070; root bark #4A3A2A / #8A7350; eyes #EFE6D2. No red, no glow. |
| Likeness check | Closest known look: Baby Groot (Marvel). Differentiated: no torso, arms or human face; a root ball with two eye dots in a hollow. |

### Generation log

| Step | Date | Tool | Settings | Cost | Output | Result |
|---|---|---|---|---|---|---|
| anchor-01 | 2026-11-02 | `create_character_pro_flash` | 64x64, low top-down, 8 directions, seed 1, palette above (max 8), style_image = Goblin v3 south rotation (colour off); prompt = the design row, ~30 px tall, "no face like a person, no leaves, no flowers, no red, no glow" | 6 gen (approved: "làm trước 1 con rễ con tui coi thử đã") | character `ee8c6435-d08c-425c-86da-823d604d9e0f`; rotations `design/assets/candidates/rootling/rot/`, preview `rootling-rot-x4.png`, in-game mock `production/qa/evidence/misty-forest-roster/rootling-mock.png` | south-west: bbox 30x47 (tendrils included), 7 colours; reads as a small root creature about 0.6 of the Knight. `west` is a back view (unused). **APPROVED by the user 2026-11-02** ("Ok" to the anchor + 5 clips). |
| anim-5clips | 2026-11-02 | `animate_character` pixminimax, south-west, 8 frames each | idle (breathes, tendrils quiver, eyes blink), step (short waddling hop in place), windup (crouches, root legs dig in, tendrils stiffen, holds), hit (recoils, roots bristle), down (sags and collapses into a heap of dry roots, eyes go dark) | 5 gen (approved) | groups 50da6b37, 2c83f6a4, d23f92c6, 924e5065, 530ab61a; raw `rootling/anim/<clip>/0-8.png` (76x76), strip `rootling-clips-raw-x3.png` | Cleaned to 64x52 (`clean-64x52/`, feet on row 51 at x 32, one shift for the whole unit): idle 0/2/4/6, step 1/3/5/7, windup 2/4/6/8 (last held), hit 3/4/5 (frame 2 had a baked yellow burst), down 2/4/5/6/7/8. **The model drew the collapse red** (red is the telegraph only, art bible P3): the palette snap turned it into the root bark colours, so the heap reads as dry roots. Exported `assets/art/units/unit_rootling_sheet.png` (389x264). In game (`production/qa/evidence/misty-forest-roster/rootling/rootling-ingame.png`): idle, windup with the telegraph ring, step with the glide, the root heap when defeated. Total Rootling: 11 gen. |

## ASSET-022 to ASSET-025 — Greycap Sporeling, Mossbound Sentry, Ancient Root Sentinel, Mistbriar Matron

Anchors generated together on 2026-11-02 (user: "làm luôn các con còn lại nhé" after the Greycap prompt and the plan's
per-unit costs). Same settings as ASSET-021 (64x64 character, low top-down, 8 directions, seed 1, style = Goblin v3 south
rotation, colour off, palette locked, max 8). Each 6 gen, 24 in total.

| Asset | Unit | Character | Palette | Prompt (short) | South-west result | Likeness |
|---|---|---|---|---|---|---|
| ASSET-022 | `greycap_sporeling` | `5705da35-be85-49c2-9704-555fbe8c755e` | Ink; caps #4A3E4A / #6A5868 / #8E8296; stem #D8CDB0; moss #4A5545 / #5E6B55; spores #EFE6D2 | cluster of three dull grey-violet mushrooms on one squat stalk-body, ivory stems, mossy root base, eye slits under the big cap, pale spore dots | 29x47, 7 colours: a big spotted cap over an ivory stem body, two small caps at the sides like arms | Closest: Toad / the Super Mushroom (Mario) because of the spotted cap. Differences: dull grey-violet, three caps, no face, moss base. Flagged to the user |
| ASSET-023 | `mossbound_sentry` | `44968e76-914f-4ee8-9e6b-c552f0a1fdcd` | Ink; stone #2C2925 / #4A4640 / #5A5650 / #6A6B62; moss #4A5545 / #5E6B55; eyes #EFE6D2 | squat stack of grey slab stones, thick moss on the shoulders and back, no arms, eye glints in a slit | 30x45, 7 colours: a hunched stone golem; the model gave it stone arms despite "no arms" | Closest: a generic rock golem (Graveler-like). Flagged to the user |
| ASSET-024 | `ancient_root_sentinel` (elite) | `fe4c307a-cc16-4845-9777-3526ee50729d` | Ink; root #4A3A2A / #8A7350 / #B89A6A; moss #3A4538 / #4A5545 / #5E6B55; scales #EFE6D2 | tall twisted root trunk, blocky square moss canopy, long root arms to the ground, eye slits, 2-3 ivory 2x2 scales | 32x54, 6 colours: tree-like guardian with a cubic canopy, root arms, one ivory scale | Closest: an Ent / Groot. Differences: cubic canopy, no beard or human face |
| ASSET-025 | `mistbriar_matron` (elite) | `168954dc-cd1f-4058-9838-634395ca40a1` | Ink; bark #4A4640 / #5A5650 / #6A6B62; briar #4A3A2A / #8A7350 / #B89A6A; eyes / scales #EFE6D2 | hooded effigy of grey bark plates, dark hood void with two pale eyes, long briar-vine arms trailing, briar wreath, ivory scales | 33x50, 7 colours: hooded bark figure, void face, thin vine arms trailing | Closest: a Dementor (Harry Potter). Differences: bark not cloth, briar arms |

Preview: `design/assets/candidates/misty-forest-four-anchors-x3.png` (south / south-west / west per row). No red pixel in any
of the four. **All four approved by the user 2026-11-02** ("Duyệt cả 4", the two likeness flags accepted).

### Clips (2026-11-02, 23 gen approved with the anchors; `animate_character` PixMiniMax south-west, 8 frames, 1 gen each)

The account runs at most 10 jobs at once, so the clips went in three batches (refused calls are not billed).

| Unit | Clips (src frames kept) | Clean-up | Sheet |
|---|---|---|---|
| Greycap Sporeling | idle 0/5/6/7 (1-4 had a baked yellow ring), step 1/3/5/7, windup 1/2/4/6, hit 5/6/7 (2-4 bursts), down 2/3/4/5/6/8 | **windup came out bright red** (the whole body): the palette snap turned it into a grey-violet swollen puff that reads as "inflating before the spores" | `unit_greycap_sporeling_sheet.png` 389x264 (64x52) |
| Mossbound Sentry | idle 0/2/4/6, step 1/3/5/7, windup 2/4/6/8 (raised stone fist, held), brace 2/4/6/8 (hunkered wall, held), hit 5/6/7 (1-4 bursts), down 1/3/4/5/6/8 | red streaks in the rubble snapped to the stone colours | `unit_mossbound_sentry_sheet.png` 389x317 (64x52) |
| Ancient Root Sentinel (elite) | idle 0/2/4/6, step 1/3/5/7, windup 2/4/6/8 (root arms spread wide), stunned 6/7, hit 5/6/7, down 2/3/4/5/6/8 (topples into roots) | stunned: the model kept the idle pose and drew a yellow star; the two smallest-star frames, snapped to ivory (reads like the elite scale) | `unit_ancient_root_sentinel_sheet.png` 389x389 (64x64) |
| Mistbriar Matron (elite) | idle 0/2/4/6, step 1/3/5/7, windup 2/4/6/8 (vine arm reaching), guard 2/4/6/8 (wraps herself in briar), hit 5/6/7 (1-4 bursts), down 3/4/5/6/7/8 | red blots in the heap snapped to the bark colours | `unit_mistbriar_matron_sheet.png` 389x389 (64x64) |

v1 elites used a 64x64 frame (feet on row 63); superseded by the 80x80 v2 below, because they still read as normals. Master palette +7 (Greycap caps
#4A3E4A / #6A5868 / #8E8296; slab stone #2C2925 / #4A4640 / #5A5650 / #6A6B62). UnitLayer: a pattern skill with a Guard
effect winds up as `guard` (or `brace`), a stunned pattern brain plays `stunned`. Tests `roster_sprite_test` (new,
watched fail), `sheet_export_test`, `sprite_sheet_test`. In game: `production/qa/evidence/misty-forest-roster/live/roster-ingame.png`.

Roster total: Rootling 11 + four anchors 24 + clips 23 = 58 gen.

## Elites v2 — bigger by tier (2026-11-02)

User: "quái có cấp bậc càng cao thì càng to" (normal ~0.7 of the Knight, elite ~0.95, warden / boss fills a multi-cell
block). The v1 elites stood only ~54 / 50 px tall, too close to the normals, so both were regenerated at an 80x80 character
canvas with "about 68 px tall" in the prompt; same palette, style image and design text as v1 (approved ~25 gen).

| Unit | Character | Anchor south-west | Clips | Clean-up | Sheet |
|---|---|---|---|---|---|
| Ancient Root Sentinel | `fd080ea7-32d9-40e8-b1cc-64416bb1de38` (6 gen) | 69 px tall (v1 54) | idle 0/2/4/6, step 1/3/5/7, windup 2/4/6/8, stunned 4/5/6/7 (slumped; 1-3 had baked yellow stars), hit 5/6/7 (1-4 bursts, one red), down 2/3/4/5/6/8 — 6 gen | 80x80 frame, feet on row 79, body centred at x 40 (`clean-80x80/`); preview `root-sentinel/sentinel-v2-clean-x3.png` | `unit_ancient_root_sentinel_sheet.png` 485x485 (80x80), **installed** |
| Mistbriar Matron | `bad2c798-674b-4f73-b579-41272dabc284` (6 gen) | 66 px tall (v1 50) | idle 0/2/4/6, step 1/3/5/7, windup 1/2/4/6, guard 2/4/6/8 (vines wrapped round the body, held), hit 5/6/7 (1-4 red bursts), down 2/3/4/5 (6-8 drew the heap bright red, the telegraph colour, so the clip stops on the grey heap) — 6 gen (guard / hit / down approved separately: "Duyệt 3 lượt") | 80x80 (`clean-80x80/`); windup drops the trailing vines and shows two pale eyes in the hood | `unit_mistbriar_matron_sheet.png` 323x485 (80x80), **installed** |

Elites v2 total: 12 anchor + 12 clip = 24 gen (roster grand total 58 + 24 = 82). In game: `production/qa/evidence/misty-forest-roster/elites-v2/` (idle and windup for both; each now stands about the Knight's height; v1 for comparison in `live/`). `roster_sprite_test` now checks every elite's idle art is at least 12 px taller than the tallest normal (69 / 66 px vs 47). Matron windup frames show two pale eyes in the hood void; closest look there is a Jawa (Star Wars), flagged to the user.

## ASSET-026 — Goblin Archer (`goblin_archer`, roster v2)

Source design: `design/quick-specs/doi-hinh-rung-suong-2026-11-03.md` §3.2, §7. Normal tier, ~0.7 of the Knight, 64x52 frame.

| Field | Value |
|---|---|
| Design | The Goblin Scout's body (art bible §5.6 variant): dark moss-grey hood up between the long sideways ears, short curved wooden bow held low in the near hand, quiver strap across the chest with arrow tips over the shoulder. |
| Palette (locked) | Ink #1B1722; skin #7D8B5A / #59643F; leather #9A7D5E / #66523F; eyes #EFE6D2; hood #5E6B55; bow wood #8A7350. No red, no glow. |
| Likeness check | Closest known look: Dart Goblin (Clash Royale). Differentiated: desaturated olive skin, short bow (no blowpipe), no mask, ragged leather, quiver. |

| Step | Date | Tool | Settings | Cost | Output | Result |
|---|---|---|---|---|---|---|
| anchor-01 | 2026-11-03 | `create_character_pro_flash` | 64x64, low top-down, 8 directions, seed 1, palette above (max 8), style_image = Goblin v3 south rotation (uploaded, colour off) | 6 gen (approved: "Duyệt, gen 6 gen"; a first call with the style image as base64 was refused by the server, nothing billed) | character `b580ca70-d8e9-4912-a3e0-ff8e0f79d3b2`; `design/assets/candidates/goblin-archer/rot/`, preview `archer-vs-scout-x4.png` | south-west: bbox 38x43 (bow included), 7 colours, no red; bow, quiver and hood read at 1x. **APPROVED by the user 2026-11-03** ("Duyệt, gen 5 clip"). |
| anim-5clips | 2026-11-03 | `animate_character` pixminimax, south-west, 8 frames each | idle (breathes, ears twitch, bow low), step (low scuttle hop in place), windup (crouches, raises the bow, draws to the cheek, holds), hit (recoils, leans back), down (drops the bow, falls face down) | 5 gen (approved) | groups 134a1167, dcc371e1, 005cb8d3, 4b14210b, b3fe5b11; raw `goblin-archer/anim/<clip>/0-8.png` (72x72), strip `archer-clips-raw-x3.png` | Cleaned to 64x52 (`clean-64x52/`, one shift for the unit: feet on row 51 at x 32; windup / down frames whose lowest pixel sat lower were lifted onto row 51; palette snap; specks < 12 px removed): idle 0/2/4/6, step 1/3/5/7, windup 2/4/6/8 (last held), hit 4/5/6 (**1-3 had a baked yellow burst and a red spray**, dropped: red is the telegraph only), down 1/2/3/4/5/8. Exported `assets/art/units/unit_goblin_archer_sheet.png` (389x264). In game: `production/qa/evidence/misty-forest-roster-v2/goblin_archer-aimed_shot.png` (drawn bow held during the row warning). Total Goblin Archer: 11 gen. |
