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

## ASSET-027 — Dire Wolf (`dire_wolf`, roster v2)

Source design: `design/quick-specs/doi-hinh-rung-suong-2026-11-03.md` §3.3, §7. Normal tier, four-legged, body horizontal (art bible §5.2), 64x52 frame.

| Field | Value |
|---|---|
| Design | Lean ragged dire wolf on all four legs, long low body, dark stone-grey fur, shaggy mane matted with dark moss over the shoulders, torn left ear, long muzzle with two pale fangs, small pale eyes, tail low. |
| Palette (locked) | Ink #1B1722; fur #2C2925 / #4A4640 / #5A5650 / #6A6B62; moss #3A4538 / #4A5545; eyes / fangs #EFE6D2. No red, no glow. |
| Likeness check | Closest known look: a Warg (The Lord of the Rings) or Sif (Dark Souls). Differentiated: no saddle, collar, armour or sword, not giant, moss-matted mane, torn ear. |

| Step | Date | Tool | Settings | Cost | Output | Result |
|---|---|---|---|---|---|---|
| anchor-01 | 2026-11-03 | `create_character_pro_flash` | 64x64, low top-down, 8 directions, seed 1, template `dog`, palette above (max 8), style_image = Goblin v3 south rotation (uploaded, colour off) | 6 gen (approved: "Duyệt, gen 6 gen") | character `de3a83f9-cd77-4d23-9f95-3cc946143ea4`; `design/assets/candidates/dire-wolf/rot/`, preview `wolf-vs-archer-x4.png`, paste mock `wolf-mock-ingame.png` (rotation pasted at x1.4 on the archer battle shot) | south-west: bbox 46x43, 8 colours, no red; on all four legs, horizontal body, fangs and moss mane read; the grey fur stays readable on the dark enemy slab. The first paste mock used a wrong x1.4 scale (the game draws art px at x2): at the real scale the wolf fills ~80 % of the cell. The user first asked for a bigger wolf, then saw the real cause was the units' off-centre stance (feet moved to the cell centre, `units-centred` evidence) and kept this anchor: "thế ko cần gen lại nhé". |
| anim-5clips | 2026-11-03 | `animate_character` pixminimax, south-west, 8 frames each | idle (breathes, tail sways, ears twitch), step (prowling trot in place), windup (crouches to pounce, hind legs coil, snarls, holds), hit (flinches back), down (slumps onto its side) | 5 gen (approved: "Gen 5 clip") | groups 3dc9716c, 531650e0, e7c22119, f1dd4464, 130b6a3a; raw `dire-wolf/anim/<clip>/0-8.png` (68x68), strip `wolf-clips-raw-x3.png` | Cleaned to **68x52** (`clean-68x52/`; 68 wide so the swaying tail is not cut; body centred at x 34, feet on row 51, palette snap, specks removed): idle 0/2/4/6, step 1/3/5/7, windup 2/4/6/8 (last held), hit 4/5/6 (**1-3 had a baked red spray**; the red open mouth snapped to the fur greys), down 1/2/3/4/6/8. Exported `assets/art/units/unit_dire_wolf_sheet.png` (413x264). In game: `production/qa/evidence/misty-forest-roster-v2/dire_wolf-chase_bite.png` (pounce crouch held during the warning, centred in its cell). Total Dire Wolf: 11 gen. |

## ASSET-028 — Wolf Alpha (`wolf_alpha`, elite, roster v2)

Source design: `design/quick-specs/doi-hinh-rung-suong-2026-11-03.md` §3.4, §7. Elite tier: bigger than the Dire Wolf, fills the cell width; 80x80 frame like the other elites.

| Field | Value |
|---|---|
| Design | Heavy-set alpha dire wolf on all four legs, broad chest, dark stone-grey fur, thick pale ash-silver mane over the neck and shoulders, three pale claw scars on the muzzle, a ring of dark thorny briar round the neck, long fangs, bushy low tail. |
| Palette (locked) | Ink #1B1722; fur #2C2925 / #4A4640 / #5A5650 / #6A6B62; mane #D8CDB0; eyes / fangs / scars #EFE6D2; briar #4A3A2A. No red, no glow. |
| Likeness check | Closest known look: Moro (Princess Mononoke) or Ghost (Game of Thrones). Differentiated: dark grey body, only the mane pale, claw scars, briar ring, not god-sized. |

| Step | Date | Tool | Settings | Cost | Output | Result |
|---|---|---|---|---|---|---|
| anchor-01 | 2026-11-04 | `create_character_pro_flash` | **80x80**, low top-down, 8 directions, seed 1, template `dog`, palette above (max 8), style_image = Goblin v3 south rotation (uploaded, colour off) | 6 gen (approved: "Duyệt, gen 6 gen") | character `76e105ae-6ec5-49b5-ab3b-5bacaf99a17f`; `design/assets/candidates/wolf-alpha/rot/`, preview `alpha-vs-wolf-x4.png`, in-game shot with a temporary one-frame sheet `wolf_alpha-rending_rush.png` | south-west: bbox 58x55 (Dire Wolf 46x43), 7 colours, no red; the ash mane reads from afar; fills the cell width in game, centred. **APPROVED by the user 2026-11-04** ("Duyệt, gen 6 clip"). |
| anim-6clips | 2026-11-04 | `animate_character` pixminimax, south-west, 8 frames each | idle (heavy breathing, mane stirs), step (slow heavy prowl in place), windup (crouches to lunge, snarls, holds), **howl** (sits back, muzzle to the sky, holds), hit (flinches back), down (slumps onto its side) | 6 gen (approved) | groups 09d03dc5, 8fcc8ec0, e67295e8, 96b6d0f1, db38c1f8, bd63c977; raw `wolf-alpha/anim/<clip>/0-8.png` (84x84), strip `alpha-clips-raw-x3.png` | Cleaned to 80x80 (`clean-80x80/`, body centred at x 40, feet on row 79, palette snap, specks removed): idle 0/2/4/6, step 1/3/5/7, windup 2/4/6/8 (red mouth snapped to the greys), howl 2/3/5/8 (last held through the 1.4 s interrupt window), hit 3/4/5 (**1-2 had a baked red spray**), down 2/3/4/5/6/8. UnitLayer: a pattern skill with a haste effect winds up as `howl` (CTX_HOWLING, falls back to `windup`). Exported `assets/art/units/unit_wolf_alpha_sheet.png` (485x485). In game: `production/qa/evidence/misty-forest-roster-v2/wolf_alpha-alpha_howl.png`, `wolf_alpha-rending_rush.png`. Total Wolf Alpha: 12 gen. |

## ASSET-029 — Goblin Warlock (`goblin_warlock`, floor 1-2 boss, 2x2, roster v2)

Source design: `design/quick-specs/doi-hinh-rung-suong-2026-11-03.md` §3.5, §7. Boss tier: fills its 2x2 block like the Forest Witch (160x130 frame, feet at 0.8 of the block).

| Field | Value |
|---|---|
| Design | Huge hunched old goblin warlock: long sideways ears, olive skin, wrinkled face, pale eyes, crooked fangs, tall bent stitched-leather hat, ragged leather robe spreading at the ground, a huge pack of stacked square grey stone tiles (stolen from the lattice) on his back, a stone tile in one raised hand, a crooked staff topped by a cage of small tiles. |
| Palette (locked) | Ink #1B1722; skin #7D8B5A / #59643F; leather #9A7D5E / #66523F; stolen tiles #4A4640 / #6A6B62; eyes / fangs #EFE6D2. No red, no glow. |
| Likeness check | Closest known look: the Great Goblin (The Hobbit). Differentiated: stooped old caster, not fat; no crown; tall leather hat; the pack of stolen square tiles. |

| Step | Date | Tool | Settings | Cost | Output | Result |
|---|---|---|---|---|---|---|
| anchor-01 | 2026-11-04 | `create_image_pro_flash` | 160x136, seed 1, no_background, palette above (max 8), style_image = Goblin v3 south rotation (uploaded, colour off) | 6 gen (approved: "Duyệt, gen 6 gen") | image `64f0b5de-be9d-54e1-a382-200240164135` (job bcf74085); `design/assets/candidates/goblin-warlock/warlock-anchor-cand-01-160x136.png`, `warlock-anchor-x3.png`, in-game shot with a temporary one-frame sheet `goblin_warlock-start.png` | bbox 118x121; fills the 2x2 block in game; hat, tile pack and tile cage read. **Only 5 colours: no olive skin and no ivory** — face and hands came out in the leather browns, so he reads as a generic old wizard more than a goblin (the ears are there). The user chose the paid fix ("Xài 6 Gen") over a free hand recolour. |
| edit-01 | 2026-11-04 | `edit_image_pro_flash` text, source image 64f0b5de, seed 1 | "recolour only the skin: face, ears and hands olive goblin green, small ivory eyes and two ivory fangs; keep everything else" | 6 gen (approved: "Xài 6 Gen") | image `450b57de-0f40-5824-b6a1-95879b9699d9` (job 475694ae); `warlock-anchor-edit-01-160x136.png` (21 colours, the edit does not keep the palette), snapped to the 8 locked colours `warlock-anchor-edit-01-snap-160x136.png` (free), compare `warlock-snap-x3.png`, in-game `goblin_warlock-stolen_shape.png` (temporary one-frame sheet) | Green face, ears and hands, ivory eyes and fangs; pose, hat, tile pack and staff unchanged; 8 colours after the snap, no red. Reads as the goblin species now. **APPROVED by the user 2026-11-04** ("Duyệt, gen 7 clip"). |
| anim-7clips | 2026-11-04 | `animate_image_pixminimax` x7, first frame = edit-01 snapped (uploaded), 8 frames, seed 1, low top-down | idle (breathing, robe sways), step (short shuffle, the row blink), windup (points the staff, hand pulled back, holds), windup_heavy (heaves a stone tile overhead, robe flares, holds), phase_shift (doubles over, tiles rattle, straightens up), hit (recoils), down (sinks, collapses, tiles spill) | 7 gen (approved) | jobs 40e79e5f, 62bd96c4, 7a0527a4, 081827ad, 80d476f0, 8a32e20b, 1ce5753c; raw `goblin-warlock/anim/<clip>/0-8.png` (160x136), strip `warlock-clips-raw-x2.png` | Cleaned to 160x130 (`clean-160x130/`, body centred at x 80, feet on row 129, palette snap, specks removed): idle 0/2/4/6, step 1/3/5/7, windup 2/4/6/8, windup_heavy 2/3/4/6 (tile overhead, held), phase_shift 1/3/5/7, hit 5/6/7 (**1-4 had a baked red burst**), down 2/3/4/5/8 (**6-7 had a red blob**, 1-3 a cyan glint on the tile). Exported `assets/art/units/unit_goblin_warlock_sheet.png` (804x916). In game: `production/qa/evidence/misty-forest-roster-v2/goblin_warlock-stolen_shape.png`, `goblin_warlock-twin_shapes.png` (phase 2, tile overhead inside the ivory frame of an uninterruptible skill). Total Goblin Warlock: 6 anchor + 6 edit + 7 clips = 19 gen. |
