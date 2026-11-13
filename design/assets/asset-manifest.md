# Asset Manifest (GENERATED)

> **Generated** from `design/assets/asset-registry.yaml` by `python -X utf8 -I tools/asset-pipeline/asset_registry.py manifest` on 2026-11-13. Do not edit by hand — edit the registry and regenerate. The previous hand-written manifest (2026-10-31) is archived as `asset-manifest-2026-10-31-archive.md`.

Lifecycle: `candidate → accepted → installed → approved`; `legacy` = replaced. **installed is not approved**: `Accepted` / `Approved` columns show what the user recorded; `unknown` means no record exists.

## Summary

| Total | Candidate | Accepted | Installed | Approved | Legacy |
|---|---|---|---|---|---|
| 286 | 6 | 0 | 201 | 75 | 4 |

Acceptance recorded: unknown 198, pending 14, accepted 74, rejected 0.

## Needs the user's decision

| Asset | Open point |
|---|---|
| `unit.phap_su` | anchor result never recorded as approved: design/assets/specs/mage-assets.md rows anchor-02 / anim03-idle-v3 record per-call approval only. Confirm the current anchor, or name the fix. |
| `unit.sat_thu` | anchor result never recorded as approved: design/assets/specs/assassin-assets.md:5 design approved 2026-11-05 ("Duyệt cả ba"); row anchor-01 records the gen approval ("Duyệt, gen 7 gen"), not the result. Confirm the current anchor, or name the fix. |
| `unit.tho_san` | anchor result never recorded as approved: design/assets/specs/hunter-assets.md:5 design approved 2026-11-05 ("Duyệt cả ba"); rows anchor-01/02 record gen approval, not the result. Confirm the current anchor, or name the fix. |
| `vfx.floor.small_burst` | declared TEMP in its manifest and index _doc ("the big burst halved 2:1, to be replaced by a generated one"). Replace (paid) or keep? |
| `vfx.status.burn_goblin` | only hero and goblin body sizes exist (status/index.json); this pack is drawn unscaled on 80x80 elites and 160x130 bosses (unit_layer.gd frame_kind_of). Accept as is, or author elite/boss overlays (free vfx_workbench)? |
| `vfx.status.chill_goblin` | only hero and goblin body sizes exist (status/index.json); this pack is drawn unscaled on 80x80 elites and 160x130 bosses (unit_layer.gd frame_kind_of). Accept as is, or author elite/boss overlays (free vfx_workbench)? |
| `vfx.status.frozen_goblin` | only hero and goblin body sizes exist (status/index.json); this pack is drawn unscaled on 80x80 elites and 160x130 bosses (unit_layer.gd frame_kind_of). Accept as is, or author elite/boss overlays (free vfx_workbench)? |
| `card.hoa_xa` | the recorded acceptance (design/assets/candidates/ui/card-art/prompts.md:13 hoa_xa row: "(done, approved style)" — date not recorded) is for the previous image (kept at design/assets/candidates/ui/card-art/batch3/replaced-2026-11-13/hoa_xa.png); the new image of 2026-11-13 has not been accepted by the user |
| `card.liet_hoa` | file installed at assets/art/cards/liet_hoa.png on 2026-11-13 per the user's batch task, but status stays candidate: the registry lifecycle only allows candidate -> accepted -> installed, and accepted is the user's call |
| `card.thien_hoa` | file installed at assets/art/cards/thien_hoa.png on 2026-11-13 per the user's batch task, but status stays candidate: the registry lifecycle only allows candidate -> accepted -> installed, and accepted is the user's call |
| `card.do_kiem` | file installed at assets/art/cards/do_kiem.png on 2026-11-13 per the user's batch task, but status stays candidate: the registry lifecycle only allows candidate -> accepted -> installed, and accepted is the user's call |
| `card.hoa_loi` | file installed at assets/art/cards/hoa_loi.png on 2026-11-13 per the user's batch task, but status stays candidate: the registry lifecycle only allows candidate -> accepted -> installed, and accepted is the user's call |
| `card.khien_thep` | file installed at assets/art/cards/khien_thep.png on 2026-11-13 per the user's batch task, but status stays candidate: the registry lifecycle only allows candidate -> accepted -> installed, and accepted is the user's call |
| `env.forest.env_support_forest_arch` | conflicting records: design/art/forest-arena-gap-plan-2026-11-06.md:75 "Còn chờ duyệt: #3 vòm lõm" vs assets/art/env/forest/region.json support._doc_kit "2026-11-06 PixelLab kit (user-approved): pillar, arch, roots, ferns". Confirm whether this piece is approved. |
| `env.forest.env_support_forest_ferns` | conflicting records: design/art/forest-arena-gap-plan-2026-11-06.md:75 "Còn chờ duyệt: #5 dương xỉ tiền cảnh" vs assets/art/env/forest/region.json support._doc_kit "2026-11-06 PixelLab kit (user-approved): pillar, arch, roots, ferns". Confirm whether this piece is approved. |
| `env.forest.env_support_forest_roots` | conflicting records: design/art/forest-arena-gap-plan-2026-11-06.md:75 "Còn chờ duyệt: #4 rễ góc" vs assets/art/env/forest/region.json support._doc_kit "2026-11-06 PixelLab kit (user-approved): pillar, arch, roots, ferns". Confirm whether this piece is approved. |
| `ui.climb.stairs` | six wired stair PNGs stay (stair_step_0..3, stair_body, stair_root) and are still untracked. stair_segment.png was unreferenced and was deleted 2026-11-11. acceptance is still unknown. |
| `ui.icons_55` | direction decision pending: slice1-combat-ui-assets.md:220 "two candidate sets: 12x12 pixel-grid set and the 55 px OSFE-style set; direction decision pending" (the 55 px set is the one in game) |
| `unit.ghost_elite` | bible 5.6 accessory (<= 8x8, upper half) not added yet: needs the user (mechanical crop from mist_lord crown or none) |

## Units (heroes, enemies, bosses)

| Registry id | Legacy id | Tier | Frame | Facing | Status | Accepted | Approved | Clips (status) | Spec |
|---|---|---|---|---|---|---|---|---|---|
| `unit.ancient_root_sentinel` | ASSET-024 | elite | 80x80 | left | **approved** | unknown | yes 2026-11-02 | idle 4?, step 4?, windup 4?, stunned 4?, hit 3?, down 6? | `design/assets/specs/misty-forest-roster-assets.md` |
| `unit.dire_wolf` | ASSET-027 | monster | 68x52 | left | **approved** | unknown | yes 2026-11-03 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `design/assets/specs/misty-forest-roster-assets.md` |
| `unit.forest_witch` | ASSET-020 | boss | 160x130 | left | **approved** | unknown | yes 2026-11-02 | idle 4+, step_forward 7+, step_back 7+, step_up 5+, step_down 7+, windup 3+, windup_heavy 3+, phase_shift 8+, hit 3+, down 6+ | `design/assets/specs/forest-witch-assets.md` |
| `unit.giao_si` | ASSET-033 | hero | 96x72 | right | **approved** | unknown | yes 2026-11-05 | idle 8?, draw 8?, step 4?, step_forward 7?, step_back 7?, step_down 7?, cast_gesture 9?, hit 3?, victory 8?, defeat 8?, fall 4?, awaken 5? | `design/assets/specs/cleric-assets.md` |
| `unit.goblin_archer` | ASSET-026 | monster | 64x52 | left | **approved** | unknown | yes 2026-11-03 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `design/assets/specs/misty-forest-roster-assets.md` |
| `unit.goblin_scout` | ASSET-003 | monster | 64x52 | left | **approved** | unknown | yes 2026-10-31 | idle 4?, step 4?, windup 2?, hit 3?, down 8? | `design/assets/specs/goblin-scout-assets.md` |
| `unit.goblin_warlock` | ASSET-029 | boss | 160x130 | left | **approved** | unknown | yes 2026-11-04 | idle 4?, step 4?, windup 4?, windup_heavy 4?, phase_shift 4?, hit 3?, down 5? | `design/assets/specs/misty-forest-roster-assets.md` |
| `unit.greycap_sporeling` | ASSET-022 | monster | 64x52 | left | **approved** | unknown | yes 2026-11-02 | idle 4+, step 4?, windup 4?, hit 3?, down 6? | `design/assets/specs/misty-forest-roster-assets.md` |
| `unit.kiem_si` | ASSET-001 | hero | 96x92 | right | **approved** | unknown | yes 2026-10-31 | idle 8?, draw 8?, step 4?, step_forward 7?, step_back 7?, step_up 7?, step_down 7?, cast_gesture 9?, cast_forward 9*, cast_summon 9+, hit 3?, victory 5?, defeat 8?, fall 4?, awaken 6? | `design/assets/specs/swordsman-assets.md` |
| `unit.mistbriar_matron` | ASSET-025 | elite | 80x80 | left | **approved** | unknown | yes 2026-11-02 | idle 4?, step 4?, windup 4?, guard 4?, hit 3?, down 4? | `design/assets/specs/misty-forest-roster-assets.md` |
| `unit.mossbound_sentry` | ASSET-023 | monster | 64x52 | left | **approved** | unknown | yes 2026-11-02 | idle 4?, step 4?, windup 4?, brace 4?, hit 3?, down 6? | `design/assets/specs/misty-forest-roster-assets.md` |
| `unit.phap_su` | ASSET-030 | hero | 96x70 | right | **installed** | unknown | no record | idle 8?, draw 8?, step 4?, step_forward 7?, step_back 7?, step_down 7?, cast_gesture 9?, hit 3?, victory 8?, defeat 8?, fall 4?, awaken 8? | `design/assets/specs/mage-assets.md` |
| `unit.rootling` | ASSET-021 | monster | 64x52 | left | **approved** | unknown | yes 2026-11-02 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `design/assets/specs/misty-forest-roster-assets.md` |
| `unit.sat_thu` | ASSET-031 | hero | 96x70 | right | **installed** | unknown | no record | idle 8?, draw 8?, step 4?, step_forward 7?, step_down 7?, cast_gesture 9?, hit 3?, victory 8?, defeat 8?, fall 4?, awaken 5? | `design/assets/specs/assassin-assets.md` |
| `unit.tho_san` | ASSET-032 | hero | 96x72 | right | **installed** | unknown | no record | idle 8?, draw 8?, step 4?, step_forward 7?, step_back 5?, step_down 7?, cast_gesture 9?, hit 3?, victory 8?, defeat 8?, fall 4?, awaken 5? | `design/assets/specs/hunter-assets.md` |
| `unit.wolf_alpha` | ASSET-028 | elite | 80x80 | left | **approved** | unknown | yes 2026-11-04 | idle 4?, step 4?, windup 4?, howl 4?, hit 3?, down 6? | `design/assets/specs/misty-forest-roster-assets.md` |
| `unit.ash_golem` | unit.ash_golem | monster | 72x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.ash_phoenix` | unit.ash_phoenix | elite | 84x80 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.ember_hound` | unit.ember_hound | monster | 68x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.fire_eater` | unit.fire_eater | elite | 92x80 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.flame_cultist` | unit.flame_cultist | monster | 70x54 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.hell_knight` | unit.hell_knight | monster | 68x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.imp` | unit.imp | monster | 70x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.inferno_lord` | unit.inferno_lord | boss | 108x86 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.magma_slug` | unit.magma_slug | monster | 64x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.dune_jackal` | unit.dune_jackal | monster | 64x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.dust_nomad` | unit.dust_nomad | monster | 70x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.mirage_sprite` | unit.mirage_sprite | monster | 64x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.sand_beetle` | unit.sand_beetle | monster | 70x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.sand_burrower` | unit.sand_burrower | elite | 80x80 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.sand_sphinx` | unit.sand_sphinx | boss | 106x86 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.scarab_guard` | unit.scarab_guard | monster | 80x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.scorpion` | unit.scorpion | elite | 80x81 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.sun_archer` | unit.sun_archer | monster | 74x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.bog_hound` | unit.bog_hound | monster | 66x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.bog_rat` | unit.bog_rat | monster | 74x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.leap_frog` | unit.leap_frog | elite | 80x80 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.marsh_toad` | unit.marsh_toad | monster | 64x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.mire_slug` | unit.mire_slug | monster | 64x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.reed_witch` | unit.reed_witch | monster | 76x53 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.spore_cap` | unit.spore_cap | elite | 80x80 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.swamp_lizard` | unit.swamp_lizard | monster | 68x53 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.toad_matriarch` | unit.toad_matriarch | boss | 104x84 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.bat_swarm` | unit.bat_swarm | monster | 64x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.cultist` | unit.cultist | monster | 72x53 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.ghost` | unit.ghost | monster | 72x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.jailer` | unit.jailer | elite | 84x80 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.ogre_king` | unit.ogre_king | boss | 96x84 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.rat_king_guard` | unit.rat_king_guard | monster | 64x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.reacter` | unit.reacter | monster | 66x55 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.skeleton` | unit.skeleton | monster | 80x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.slime` | unit.slime | monster | 72x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.zombie` | unit.zombie | monster | 64x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.frost_mage` | unit.frost_mage | elite | 94x80 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.frost_sprite` | unit.frost_sprite | monster | 64x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.fuse_golem` | unit.fuse_golem | monster | 64x54 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.ghost_elite` | unit.ghost_elite | monster | 72x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.ice_golem` | unit.ice_golem | monster | 66x53 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.mist_lord` | unit.mist_lord | boss | 96x91 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.rime_archer` | unit.rime_archer | monster | 74x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.snow_wolf` | unit.snow_wolf | monster | 72x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.stone_sentry` | unit.stone_sentry | monster | 70x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.wisp` | unit.wisp | monster | 64x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.cloud_sprite` | unit.cloud_sprite | monster | 64x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.cloud_veil` | unit.cloud_veil | elite | 80x80 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.gale_bird` | unit.gale_bird | elite | 90x81 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.harpy` | unit.harpy | monster | 74x56 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.sky_sentinel` | unit.sky_sentinel | monster | 64x53 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.storm_dragon` | unit.storm_dragon | boss | 100x96 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.storm_eagle` | unit.storm_eagle | monster | 74x55 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.thunder_shaman` | unit.thunder_shaman | monster | 80x52 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |
| `unit.wind_monk` | unit.wind_monk | monster | 64x53 | left | **approved** | yes 2026-11-13 | yes 2026-11-13 | idle 4?, step 4?, windup 4?, hit 3?, down 6? | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` |

Clip marks: `*` approved by the user, `+` accepted, `?` acceptance unknown, `!` needs a decision.

## VFX packs

| Registry id | Index | Frames × ms | Canvas | Provider | Status | Accepted | Approved | Note |
|---|---|---|---|---|---|---|---|---|
| `vfx.cast.charge_flame_burn` | packs.charge_flame_burn | 6 × 50 | 46x46 | fx-pipeline | **installed** | unknown | no record | prototype 2 (hoa_tran) / Mage fireball cast pack; the look was accepted as a prototype (fx-pipeline-assets.md §Prototype 2) but no install-approval line was found for these packs |
| `vfx.cast.hand_charge` | packs.hand_charge | 4 × 71 | 24x24 | pixellab | **installed** | unknown | no record | open in active.md: "hand_charge/root_seal workbench" (rework considered) |
| `vfx.cast.release_square_slash_steel` | packs.release_square_slash_steel | 4 × 50 | 86x28 | fx-pipeline | **installed** | yes 2026-11-02 | no record |  |
| `vfx.cast.sword_wave` | packs.sword_wave | 4 × 83 | 50x48 | pixellab | **installed** | unknown | no record | cast/index.json default pack (sat_thu, tho_san, giao_si); the Knight moved to square_wave_steel on 2026-11-02 after "hiệu ứng còn quá nhỏ nhìn từ xa"; kept for rollback (index _doc_task5) |
| `vfx.cast.travel_fireball_burn` | packs.fire_bolt_burn | 4 × 50 | 94x42 | fx-pipeline | **installed** | unknown | no record | prototype 2 (hoa_tran) / Mage fireball cast pack; the look was accepted as a prototype (fx-pipeline-assets.md §Prototype 2) but no install-approval line was found for these packs |
| `vfx.cast.travel_square_wave_steel` | packs.square_wave_steel | 4 × 50 | 72x54 | fx-pipeline | **installed** | yes 2026-11-02 | no record |  |
| `vfx.floor.big_burst` | packs.big_burst | 9 × 50 | 64x96 | pixellab | **approved** | unknown | yes 2026-11-01 |  |
| `vfx.floor.burning_cell` | packs.burning_cell | 12 × 100 | 70x86 | pixellab | **installed** | pending | no record | Story 048 evidence C-3: "PASS (chờ ký)" (production/qa/evidence/floor-vfx-evidence.md, 2026-10-31) — technical pass, sign-off pending |
| `vfx.floor.cast_target` | packs.cast_target | 16 × 100 | 74x52 | pixellab | **installed** | pending | no record | Story 048 evidence C-3: "PASS (chờ ký)" (production/qa/evidence/floor-vfx-evidence.md, 2026-10-31) — technical pass, sign-off pending |
| `vfx.floor.cell_slash` | packs.cell_slash | 7 × 45 | 64x64 | pixellab | **installed** | unknown | no record | assets/art/vfx/floor/index.json _doc: "cell_slash … PixelLab-generated (Pro Flash key + animate_image, user 2026-11-01)" — generation approved; result approval not stated |
| `vfx.floor.cracked_cell` | packs.cracked_cell | 12 × 83 | 83x52 | pixellab | **installed** | pending | no record | Story 048 evidence C-3: "PASS (chờ ký)" (production/qa/evidence/floor-vfx-evidence.md, 2026-10-31) — technical pass, sign-off pending |
| `vfx.floor.engraving_complete` | packs.engraving_complete | 10 × 67 | 49x45 | pixellab | **installed** | pending | no record | Story 048 evidence C-3: "PASS (chờ ký)" (production/qa/evidence/floor-vfx-evidence.md, 2026-10-31) — technical pass, sign-off pending |
| `vfx.floor.engraving_lit` | packs.engraving_lit | 24 × 125 | 70x52 | pixellab | **installed** | pending | no record | Story 048 evidence C-3: "PASS (chờ ký)" (production/qa/evidence/floor-vfx-evidence.md, 2026-10-31) — technical pass, sign-off pending |
| `vfx.floor.hit_impact` | packs.hit_impact | 6 × 56 | 49x40 | pixellab | **installed** | pending | no record | Story 048 evidence C-3: "PASS (chờ ký)" (production/qa/evidence/floor-vfx-evidence.md, 2026-10-31) — technical pass, sign-off pending |
| `vfx.floor.impact_burst_big_steel` | packs.impact_burst_big_steel | 7 × 50 | 106x88 | fx-pipeline | **installed** | yes 2026-11-02 | no record |  |
| `vfx.floor.impact_burst_big_steel_c43x31` | packs.impact_burst_big_steel_c43x31 | 7 × 50 | 72x66 | fx-pipeline | **installed** | yes 2026-11-02 | no record |  |
| `vfx.floor.impact_burst_small_steel` | packs.impact_burst_small_steel | 5 × 50 | 106x74 | fx-pipeline | **installed** | yes 2026-11-02 | no record |  |
| `vfx.floor.impact_burst_small_steel_c43x31` | packs.impact_burst_small_steel_c43x31 | 5 × 50 | 72x56 | fx-pipeline | **installed** | yes 2026-11-02 | no record |  |
| `vfx.floor.impact_eruption_tram_dia` | packs.impact_eruption_tram_dia | 7 × 50 | 112x112 | fx-pipeline | **approved** | unknown | yes 2026-11-08 |  |
| `vfx.floor.impact_flame_burn` | packs.impact_flame_burn | 7 × 50 | 94x116 | fx-pipeline | **installed** | unknown | no record | prototype 2 (hoa_tran) / Mage fireball cast pack; the look was accepted as a prototype (fx-pipeline-assets.md §Prototype 2) but no install-approval line was found for these packs |
| `vfx.floor.impact_flame_burn_c43x31` | packs.impact_flame_burn_c43x31 | 7 × 50 | 62x80 | fx-pipeline | **installed** | unknown | no record | prototype 2 (hoa_tran) / Mage fireball cast pack; the look was accepted as a prototype (fx-pipeline-assets.md §Prototype 2) but no install-approval line was found for these packs |
| `vfx.floor.impact_flame_small_burn` | packs.impact_flame_small_burn | 6 × 50 | 94x102 | fx-pipeline | **installed** | unknown | no record | prototype 2 (hoa_tran) / Mage fireball cast pack; the look was accepted as a prototype (fx-pipeline-assets.md §Prototype 2) but no install-approval line was found for these packs |
| `vfx.floor.impact_flame_small_burn_c43x31` | packs.impact_flame_small_burn_c43x31 | 6 × 50 | 62x72 | fx-pipeline | **installed** | unknown | no record | prototype 2 (hoa_tran) / Mage fireball cast pack; the look was accepted as a prototype (fx-pipeline-assets.md §Prototype 2) but no install-approval line was found for these packs |
| `vfx.floor.interrupt` | packs.interrupt | 6 × 56 | 49x46 | pixellab | **installed** | pending | no record | Story 048 evidence C-3: "PASS (chờ ký)" (production/qa/evidence/floor-vfx-evidence.md, 2026-10-31) — technical pass, sign-off pending |
| `vfx.floor.mark_embers_burn` | packs.mark_embers_burn | 7 × 50 | 64x46 | fx-pipeline | **installed** | unknown | no record | prototype 2 (hoa_tran) / Mage fireball cast pack; the look was accepted as a prototype (fx-pipeline-assets.md §Prototype 2) but no install-approval line was found for these packs |
| `vfx.floor.mark_embers_burn_c43x31` | packs.mark_embers_burn_c43x31 | 7 × 50 | 44x32 | fx-pipeline | **installed** | unknown | no record | prototype 2 (hoa_tran) / Mage fireball cast pack; the look was accepted as a prototype (fx-pipeline-assets.md §Prototype 2) but no install-approval line was found for these packs |
| `vfx.floor.mark_eruption_tram_dia` | packs.mark_eruption_tram_dia | 12 × 50 | 112x112 | fx-pipeline | **approved** | unknown | yes 2026-11-08 |  |
| `vfx.floor.mark_stamp_big_steel` | packs.mark_stamp_big_steel | 9 × 50 | 64x46 | fx-pipeline | **installed** | yes 2026-11-02 | no record |  |
| `vfx.floor.mark_stamp_big_steel_c43x31` | packs.mark_stamp_big_steel_c43x31 | 9 × 50 | 44x32 | fx-pipeline | **installed** | yes 2026-11-02 | no record |  |
| `vfx.floor.mark_stamp_small_steel` | packs.mark_stamp_small_steel | 7 × 50 | 64x46 | fx-pipeline | **installed** | yes 2026-11-02 | no record |  |
| `vfx.floor.mark_stamp_small_steel_c43x31` | packs.mark_stamp_small_steel_c43x31 | 7 × 50 | 44x32 | fx-pipeline | **installed** | yes 2026-11-02 | no record |  |
| `vfx.floor.miss_dust` | packs.miss_dust | 10 × 83 | 70x52 | pixellab | **installed** | pending | no record | Story 048 evidence C-3: "PASS (chờ ký)" (production/qa/evidence/floor-vfx-evidence.md, 2026-10-31) — technical pass, sign-off pending |
| `vfx.floor.root_seal` | packs.root_seal | 12 × 100 | 74x52 | pixellab | **installed** | pending | no record | Story 048 evidence C-3: "PASS (chờ ký)" (production/qa/evidence/floor-vfx-evidence.md, 2026-10-31) — technical pass, sign-off pending |
| `vfx.floor.small_burst` | packs.small_burst | 9 × 45 | 32x48 | pixellab | **installed** | unknown | no record |  |
| `vfx.floor.thorn_spikes` | packs.thorn_spikes | 8 × 63 | 70x52 | pixellab | **installed** | pending | no record | Story 048 evidence C-3: "PASS (chờ ký)" (production/qa/evidence/floor-vfx-evidence.md, 2026-10-31) — technical pass, sign-off pending |
| `vfx.status.burn_goblin` | burn.goblin | 12 × 83 | 35x65 | pixellab | **installed** | yes 2026-10-31 | no record | 2026-10-31 manifest row (archived): Done (in game since Story 047), awaiting the art-director's sign-off; ASSET-020 was also used by the Forest Witch spec; the registry keys them apart |
| `vfx.status.burn_hero` | burn.hero | 12 × 83 | 46x87 | pixellab | **installed** | yes 2026-10-31 | no record | 2026-10-31 manifest row (archived): Done (in game since Story 047), awaiting the art-director's sign-off; ASSET-020 was also used by the Forest Witch spec; the registry keys them apart |
| `vfx.status.chill_goblin` | chill.goblin | 16 × 83 | 50x53 | pixellab | **installed** | yes 2026-10-31 | no record | 2026-10-31 manifest row (archived): Done (in game since Story 047), awaiting the art-director's sign-off; ASSET-020 was also used by the Forest Witch spec; the registry keys them apart |
| `vfx.status.chill_hero` | chill.hero | 16 × 83 | 95x103 | pixellab | **installed** | yes 2026-10-31 | no record | 2026-10-31 manifest row (archived): Done (in game since Story 047), awaiting the art-director's sign-off; ASSET-020 was also used by the Forest Witch spec; the registry keys them apart |
| `vfx.status.frozen_goblin` | frozen.goblin | 12 × 100 | 44x61 | pixellab | **installed** | yes 2026-10-31 | no record | 2026-10-31 manifest row (archived): Done (in game since Story 047), awaiting the art-director's sign-off; ASSET-020 was also used by the Forest Witch spec; the registry keys them apart |
| `vfx.status.frozen_hero` | frozen.hero | 12 × 100 | 60x83 | pixellab | **installed** | yes 2026-10-31 | no record | 2026-10-31 manifest row (archived): Done (in game since Story 047), awaiting the art-director's sign-off; ASSET-020 was also used by the Forest Witch spec; the registry keys them apart |
| `vfx.floor.impact_flash_steel_pixelfx` | — | 7 × 50 | 80x64 | pixelfx (upstream impacts/hit-flash) | **candidate** | pending | no record | P3 proof of concept: shows the PixelFX -> VfxPack path end to end; 7 of 11 source frames kept for the 350 ms overlay rule; glow under alpha 128 dropped; 673 source colours snapped to the 4-colour steel ramp. Not installed, not accepted: the user decides. |

## Environment

| Registry id | Name | File(s) | Size | Status | Accepted | Approved | Spec | Note |
|---|---|---|---|---|---|---|---|---|
| `env.forest.bg_forest_far` | bg_forest_far | `assets/art/env/forest/bg_forest_far.png` | 800x360 | **legacy** | unknown | no record | `design/assets/specs/misty-forest-assets.md` | v1 (Story 047); replaced by v4 — region.json _doc_far: "Older far backdrops kept"; referenced by tests only |
| `env.forest.bg_forest_far_edge` | bg_forest_far_edge | `assets/art/env/forest/bg_forest_far_edge.png` | 800x360 | **installed** | unknown | no record | — | area variant, 2026-11-06 ("Làm thử 3 khu"); region.json areas._doc: create_image_pro 792x336, 25 gen each, gen approved "oke gen di"; result approval not recorded |
| `env.forest.bg_forest_far_sanctum` | bg_forest_far_sanctum | `assets/art/env/forest/bg_forest_far_sanctum.png` | 800x360 | **installed** | unknown | no record | — | area variant, 2026-11-06 ("Làm thử 3 khu"); region.json areas._doc: create_image_pro 792x336, 25 gen each, gen approved "oke gen di"; result approval not recorded |
| `env.forest.bg_forest_far_v2` | bg_forest_far_v2 | `assets/art/env/forest/bg_forest_far_v2.png` | 800x360 | **legacy** | unknown | no record | `design/assets/specs/misty-forest-assets.md` | replaced by v4 — region.json _doc_far: "Older far backdrops kept"; unreferenced |
| `env.forest.bg_forest_far_v3` | bg_forest_far_v3 | `assets/art/env/forest/bg_forest_far_v3.png` | 800x360 | **legacy** | unknown | no record | `design/assets/specs/misty-forest-assets.md` | replaced by v4 — region.json _doc_far: "Older far backdrops kept"; unreferenced |
| `env.forest.bg_forest_far_v4` | Misty Forest far backdrop v4 (in use) | `assets/art/env/forest/bg_forest_far_v4.png` | 800x360 | **installed** | unknown | no record | `design/assets/specs/misty-forest-assets.md` | region.json backdrop._doc_far: v4 = v3 (create_image_pro, 25 gen) + rows 0-71 from the approved master concept; the backdrop itself has no result-approval record |
| `env.forest.bg_forest_near` | bg_forest_near | `assets/art/env/forest/bg_forest_near.png` | 800x48 | **installed** | unknown | no record | — | near mist layer; region.json near_enabled: false (not drawn) |
| `env.forest.env_platform_forest_face` | env_platform_forest_face | `assets/art/env/forest/env_platform_forest_face.png` | 231x12 | **installed** | unknown | no record | — | 0 gen: rows 15-26 cut from the support wall (region.json platform._doc_face_tile) |
| `env.forest.env_slab_forest_9slice` | Misty Forest slab 9-slice (ASSET-004) | `assets/art/env/forest/env_slab_forest_9slice.png` | 16x16 | **approved** | unknown | yes 2026-10-31 | `design/assets/specs/misty-forest-assets.md` |  |
| `env.forest.env_slab_forest_flagstones` | Misty Forest flagstones 16 x 64x64 (create_tiles_pro) | `assets/art/env/forest/env_slab_forest_flagstones.png` | 256x256 | **installed** | unknown | no record | — | assets/art/env/forest/region.json slab.flagstone_meta._doc: "2026-11-06 PixelLab create_tiles_pro (15 gen, user-approved prompt)" — prompt approval, result approval not recorded |
| `env.forest.env_slab_forest_stamps` | Misty Forest slab stamps (ASSET-004, 18 stamps + json) | `assets/art/env/forest/env_slab_forest_stamps.png`, `assets/art/env/forest/env_slab_forest_stamps.json` | 96x48 | **approved** | unknown | yes 2026-10-31 | `design/assets/specs/misty-forest-assets.md` |  |
| `env.forest.env_support_forest_arch` | env_support_forest_arch | `assets/art/env/forest/env_support_forest_arch.png` | 72x40 | **installed** | unknown | no record | `design/art/forest-arena-gap-plan-2026-11-06.md` |  |
| `env.forest.env_support_forest_ferns` | env_support_forest_ferns | `assets/art/env/forest/env_support_forest_ferns.png` | 96x32 | **installed** | unknown | no record | `design/art/forest-arena-gap-plan-2026-11-06.md` |  |
| `env.forest.env_support_forest_pillar` | env_support_forest_pillar | `assets/art/env/forest/env_support_forest_pillar.png` | 28x56 | **installed** | yes 2026-11-06 | no record | `design/art/forest-arena-gap-plan-2026-11-06.md` |  |
| `env.forest.env_support_forest_roots` | env_support_forest_roots | `assets/art/env/forest/env_support_forest_roots.png` | 64x64 | **installed** | unknown | no record | `design/art/forest-arena-gap-plan-2026-11-06.md` |  |
| `env.forest.env_support_forest_wall` | env_support_forest_wall | `assets/art/env/forest/env_support_forest_wall.png` | 231x44 | **approved** | unknown | yes 2026-11-06 | `design/art/forest-arena-gap-plan-2026-11-06.md` |  |
| `env.forest.env_thorn_forest_tile16` | env_thorn_forest_tile16 | `assets/art/env/forest/env_thorn_forest_tile16.png` | 16x16 | **legacy** | unknown | no record | `design/assets/specs/misty-forest-assets.md` | v1 thorn tile; region.json thorn_tile points at _v2 (2026-11-06 recolour); _doc_thorn_tile: "the original env_thorn_forest_tile16.png is kept" |
| `env.forest.env_thorn_forest_tile16_v2` | env_thorn_forest_tile16_v2 | `assets/art/env/forest/env_thorn_forest_tile16_v2.png` | 16x16 | **installed** | unknown | no record | `design/assets/specs/misty-forest-assets.md` | 2026-11-06 colour-for-colour recolour to pale bone / dark earth (region.json _doc_thorn_tile); acceptance not recorded |
| `env.dungeon.bg_dungeon_far_inner` | bg_dungeon_far_inner | `assets/art/env/dungeon/bg_dungeon_far_inner.png` | 800x360 | **installed** | unknown | no record | — |  |
| `env.dungeon.env_slab_dungeon_9slice` | env_slab_dungeon_9slice | `assets/art/env/dungeon/env_slab_dungeon_9slice.png` | 16x16 | **installed** | unknown | no record | — |  |
| `env.dungeon.env_slab_dungeon_stamps` | env_slab_dungeon_stamps | `assets/art/env/dungeon/env_slab_dungeon_stamps.png`, `assets/art/env/dungeon/env_slab_dungeon_stamps.json` | 96x48 | **installed** | unknown | no record | — |  |
| `env.dungeon.env_support_dungeon_pillar` | env_support_dungeon_pillar | `assets/art/env/dungeon/env_support_dungeon_pillar.png` | 28x56 | **installed** | unknown | no record | — |  |
| `env.dungeon.env_support_dungeon_wall` | env_support_dungeon_wall | `assets/art/env/dungeon/env_support_dungeon_wall.png` | 231x44 | **installed** | unknown | no record | — |  |
| `env.dungeon.env_thorn_dungeon_tile16` | env_thorn_dungeon_tile16 | `assets/art/env/dungeon/env_thorn_dungeon_tile16.png` | 16x16 | **installed** | unknown | no record | — |  |
| `env.hellfire.bg_hellfire_far_inner` | bg_hellfire_far_inner | `assets/art/env/hellfire/bg_hellfire_far_inner.png` | 800x360 | **installed** | unknown | no record | — |  |
| `env.hellfire.env_slab_hellfire_9slice` | env_slab_hellfire_9slice | `assets/art/env/hellfire/env_slab_hellfire_9slice.png` | 16x16 | **installed** | unknown | no record | — |  |
| `env.hellfire.env_slab_hellfire_stamps` | env_slab_hellfire_stamps | `assets/art/env/hellfire/env_slab_hellfire_stamps.png`, `assets/art/env/hellfire/env_slab_hellfire_stamps.json` | 96x48 | **installed** | unknown | no record | — |  |
| `env.hellfire.env_support_hellfire_pillar` | env_support_hellfire_pillar | `assets/art/env/hellfire/env_support_hellfire_pillar.png` | 28x56 | **installed** | unknown | no record | — |  |
| `env.hellfire.env_support_hellfire_wall` | env_support_hellfire_wall | `assets/art/env/hellfire/env_support_hellfire_wall.png` | 231x44 | **installed** | unknown | no record | — |  |
| `env.hellfire.env_thorn_hellfire_tile16` | env_thorn_hellfire_tile16 | `assets/art/env/hellfire/env_thorn_hellfire_tile16.png` | 16x16 | **installed** | unknown | no record | — |  |
| `env.ice_tower.bg_ice_tower_far_inner` | bg_ice_tower_far_inner | `assets/art/env/ice_tower/bg_ice_tower_far_inner.png` | 800x360 | **installed** | unknown | no record | — |  |
| `env.ice_tower.env_slab_ice_tower_9slice` | env_slab_ice_tower_9slice | `assets/art/env/ice_tower/env_slab_ice_tower_9slice.png` | 16x16 | **installed** | unknown | no record | — |  |
| `env.ice_tower.env_slab_ice_tower_stamps` | env_slab_ice_tower_stamps | `assets/art/env/ice_tower/env_slab_ice_tower_stamps.png`, `assets/art/env/ice_tower/env_slab_ice_tower_stamps.json` | 96x48 | **installed** | unknown | no record | — |  |
| `env.ice_tower.env_support_ice_tower_pillar` | env_support_ice_tower_pillar | `assets/art/env/ice_tower/env_support_ice_tower_pillar.png` | 28x56 | **installed** | unknown | no record | — |  |
| `env.ice_tower.env_support_ice_tower_wall` | env_support_ice_tower_wall | `assets/art/env/ice_tower/env_support_ice_tower_wall.png` | 231x44 | **installed** | unknown | no record | — |  |
| `env.ice_tower.env_thorn_ice_tower_tile16` | env_thorn_ice_tower_tile16 | `assets/art/env/ice_tower/env_thorn_ice_tower_tile16.png` | 16x16 | **installed** | unknown | no record | — |  |
| `env.lattice_heart.bg_lattice_heart_far_inner` | bg_lattice_heart_far_inner | `assets/art/env/lattice_heart/bg_lattice_heart_far_inner.png` | 800x360 | **installed** | unknown | no record | — |  |
| `env.lattice_heart.env_slab_lattice_heart_9slice` | env_slab_lattice_heart_9slice | `assets/art/env/lattice_heart/env_slab_lattice_heart_9slice.png` | 16x16 | **installed** | unknown | no record | — |  |
| `env.lattice_heart.env_slab_lattice_heart_stamps` | env_slab_lattice_heart_stamps | `assets/art/env/lattice_heart/env_slab_lattice_heart_stamps.png`, `assets/art/env/lattice_heart/env_slab_lattice_heart_stamps.json` | 96x48 | **installed** | unknown | no record | — |  |
| `env.lattice_heart.env_support_lattice_heart_pillar` | env_support_lattice_heart_pillar | `assets/art/env/lattice_heart/env_support_lattice_heart_pillar.png` | 28x56 | **installed** | unknown | no record | — |  |
| `env.lattice_heart.env_support_lattice_heart_wall` | env_support_lattice_heart_wall | `assets/art/env/lattice_heart/env_support_lattice_heart_wall.png` | 231x44 | **installed** | unknown | no record | — |  |
| `env.lattice_heart.env_thorn_lattice_heart_tile16` | env_thorn_lattice_heart_tile16 | `assets/art/env/lattice_heart/env_thorn_lattice_heart_tile16.png` | 16x16 | **installed** | unknown | no record | — |  |
| `env.sands.bg_sands_far_inner` | bg_sands_far_inner | `assets/art/env/sands/bg_sands_far_inner.png` | 800x360 | **installed** | unknown | no record | — |  |
| `env.sands.env_slab_sands_9slice` | env_slab_sands_9slice | `assets/art/env/sands/env_slab_sands_9slice.png` | 16x16 | **installed** | unknown | no record | — |  |
| `env.sands.env_slab_sands_stamps` | env_slab_sands_stamps | `assets/art/env/sands/env_slab_sands_stamps.png`, `assets/art/env/sands/env_slab_sands_stamps.json` | 96x48 | **installed** | unknown | no record | — |  |
| `env.sands.env_support_sands_pillar` | env_support_sands_pillar | `assets/art/env/sands/env_support_sands_pillar.png` | 28x56 | **installed** | unknown | no record | — |  |
| `env.sands.env_support_sands_wall` | env_support_sands_wall | `assets/art/env/sands/env_support_sands_wall.png` | 231x44 | **installed** | unknown | no record | — |  |
| `env.sands.env_thorn_sands_tile16` | env_thorn_sands_tile16 | `assets/art/env/sands/env_thorn_sands_tile16.png` | 16x16 | **installed** | unknown | no record | — |  |
| `env.sky_isles.bg_sky_isles_far_inner` | bg_sky_isles_far_inner | `assets/art/env/sky_isles/bg_sky_isles_far_inner.png` | 800x360 | **installed** | unknown | no record | — |  |
| `env.sky_isles.env_slab_sky_isles_9slice` | env_slab_sky_isles_9slice | `assets/art/env/sky_isles/env_slab_sky_isles_9slice.png` | 16x16 | **installed** | unknown | no record | — |  |
| `env.sky_isles.env_slab_sky_isles_stamps` | env_slab_sky_isles_stamps | `assets/art/env/sky_isles/env_slab_sky_isles_stamps.png`, `assets/art/env/sky_isles/env_slab_sky_isles_stamps.json` | 96x48 | **installed** | unknown | no record | — |  |
| `env.sky_isles.env_support_sky_isles_wall` | env_support_sky_isles_wall | `assets/art/env/sky_isles/env_support_sky_isles_wall.png` | 231x44 | **installed** | unknown | no record | — |  |
| `env.sky_isles.env_thorn_sky_isles_tile16` | env_thorn_sky_isles_tile16 | `assets/art/env/sky_isles/env_thorn_sky_isles_tile16.png` | 16x16 | **installed** | unknown | no record | — |  |
| `env.swamp.bg_swamp_far_inner` | bg_swamp_far_inner | `assets/art/env/swamp/bg_swamp_far_inner.png` | 800x360 | **installed** | unknown | no record | — |  |
| `env.swamp.env_slab_swamp_9slice` | env_slab_swamp_9slice | `assets/art/env/swamp/env_slab_swamp_9slice.png` | 16x16 | **installed** | unknown | no record | — |  |
| `env.swamp.env_slab_swamp_stamps` | env_slab_swamp_stamps | `assets/art/env/swamp/env_slab_swamp_stamps.png`, `assets/art/env/swamp/env_slab_swamp_stamps.json` | 96x48 | **installed** | unknown | no record | — |  |
| `env.swamp.env_support_swamp_ferns` | env_support_swamp_ferns | `assets/art/env/swamp/env_support_swamp_ferns.png` | 96x32 | **installed** | unknown | no record | — |  |
| `env.swamp.env_support_swamp_roots` | env_support_swamp_roots | `assets/art/env/swamp/env_support_swamp_roots.png` | 64x64 | **installed** | unknown | no record | — |  |
| `env.swamp.env_support_swamp_wall` | env_support_swamp_wall | `assets/art/env/swamp/env_support_swamp_wall.png` | 231x44 | **installed** | unknown | no record | — |  |
| `env.swamp.env_thorn_swamp_tile16` | env_thorn_swamp_tile16 | `assets/art/env/swamp/env_thorn_swamp_tile16.png` | 16x16 | **installed** | unknown | no record | — |  |
| `env.dungeon.env_platform_dungeon_face` | env_platform_dungeon_face | `assets/art/env/dungeon/env_platform_dungeon_face.png` | 231x12 | **installed** | unknown | no record | — |  |
| `env.dungeon.env_platform_dungeon_rim` | env_platform_dungeon_rim | `assets/art/env/dungeon/env_platform_dungeon_rim.png` | 231x7 | **installed** | unknown | no record | — |  |
| `env.dungeon.env_support_dungeon_foot` | env_support_dungeon_foot | `assets/art/env/dungeon/env_support_dungeon_foot.png` | 231x10 | **installed** | unknown | no record | — |  |
| `env.hellfire.env_platform_hellfire_face` | env_platform_hellfire_face | `assets/art/env/hellfire/env_platform_hellfire_face.png` | 231x12 | **installed** | unknown | no record | — |  |
| `env.hellfire.env_platform_hellfire_rim` | env_platform_hellfire_rim | `assets/art/env/hellfire/env_platform_hellfire_rim.png` | 231x8 | **installed** | unknown | no record | — |  |
| `env.hellfire.env_support_hellfire_foot` | env_support_hellfire_foot | `assets/art/env/hellfire/env_support_hellfire_foot.png` | 231x14 | **installed** | unknown | no record | — |  |
| `env.ice_tower.env_platform_ice_tower_face` | env_platform_ice_tower_face | `assets/art/env/ice_tower/env_platform_ice_tower_face.png` | 231x12 | **installed** | unknown | no record | — |  |
| `env.ice_tower.env_platform_ice_tower_rim` | env_platform_ice_tower_rim | `assets/art/env/ice_tower/env_platform_ice_tower_rim.png` | 231x12 | **installed** | unknown | no record | — |  |
| `env.ice_tower.env_support_ice_tower_foot` | env_support_ice_tower_foot | `assets/art/env/ice_tower/env_support_ice_tower_foot.png` | 231x12 | **installed** | unknown | no record | — |  |
| `env.sands.env_platform_sands_face` | env_platform_sands_face | `assets/art/env/sands/env_platform_sands_face.png` | 231x12 | **installed** | unknown | no record | — |  |
| `env.sands.env_platform_sands_rim` | env_platform_sands_rim | `assets/art/env/sands/env_platform_sands_rim.png` | 231x9 | **installed** | unknown | no record | — |  |
| `env.sands.env_support_sands_foot` | env_support_sands_foot | `assets/art/env/sands/env_support_sands_foot.png` | 231x16 | **installed** | unknown | no record | — |  |
| `env.sky_isles.env_platform_sky_isles_face` | env_platform_sky_isles_face | `assets/art/env/sky_isles/env_platform_sky_isles_face.png` | 231x12 | **installed** | unknown | no record | — |  |
| `env.sky_isles.env_platform_sky_isles_rim` | env_platform_sky_isles_rim | `assets/art/env/sky_isles/env_platform_sky_isles_rim.png` | 231x6 | **installed** | unknown | no record | — |  |
| `env.sky_isles.env_support_sky_isles_foot` | env_support_sky_isles_foot | `assets/art/env/sky_isles/env_support_sky_isles_foot.png` | 231x22 | **installed** | unknown | no record | — |  |
| `env.swamp.env_platform_swamp_face` | env_platform_swamp_face | `assets/art/env/swamp/env_platform_swamp_face.png` | 231x12 | **installed** | unknown | no record | — |  |
| `env.swamp.env_platform_swamp_rim` | env_platform_swamp_rim | `assets/art/env/swamp/env_platform_swamp_rim.png` | 231x8 | **installed** | unknown | no record | — |  |
| `env.swamp.env_support_swamp_foot` | env_support_swamp_foot | `assets/art/env/swamp/env_support_swamp_foot.png` | 231x14 | **installed** | unknown | no record | — |  |
| `env.dungeon.env_slab_dungeon_flagstones` | env_slab_dungeon_flagstones | `assets/art/env/dungeon/env_slab_dungeon_flagstones.png` | 256x256 | **installed** | unknown | no record | — |  |
| `env.hellfire.env_slab_hellfire_flagstones` | env_slab_hellfire_flagstones | `assets/art/env/hellfire/env_slab_hellfire_flagstones.png` | 256x256 | **installed** | unknown | no record | — |  |
| `env.ice_tower.env_slab_ice_tower_flagstones` | env_slab_ice_tower_flagstones | `assets/art/env/ice_tower/env_slab_ice_tower_flagstones.png` | 256x256 | **installed** | unknown | no record | — |  |
| `env.sands.env_slab_sands_flagstones` | env_slab_sands_flagstones | `assets/art/env/sands/env_slab_sands_flagstones.png` | 256x256 | **installed** | unknown | no record | — |  |
| `env.sky_isles.env_slab_sky_isles_flagstones` | env_slab_sky_isles_flagstones | `assets/art/env/sky_isles/env_slab_sky_isles_flagstones.png` | 256x256 | **installed** | unknown | no record | — |  |
| `env.swamp.env_slab_swamp_flagstones` | env_slab_swamp_flagstones | `assets/art/env/swamp/env_slab_swamp_flagstones.png` | 256x256 | **installed** | unknown | no record | — |  |

## UI

| Registry id | Name | File(s) | Size | Status | Accepted | Approved | Spec | Note |
|---|---|---|---|---|---|---|---|---|
| `ui.cards.frames` | Card frames (card_frame, card_frame_ancient) | `assets/art/ui/cards/card_frame.png`, `assets/art/ui/cards/card_frame_ancient.png` | — | **installed** | unknown | no record | — |  |
| `ui.climb.clouds` | Tower Ascent cloud banks x4 (128x48) | `assets/art/ui/climb/cloud_0.png`, `assets/art/ui/climb/cloud_1.png`, `assets/art/ui/climb/cloud_2.png`, `assets/art/ui/climb/cloud_3.png` | — | **installed** | unknown | no record | `design/art/climb-map-asset-spec-2026-11-07.md` |  |
| `ui.climb.islands` | Tower Ascent islands x7 (320x192) + islands.json anchors | `assets/art/ui/climb/island_ch1.png`, `assets/art/ui/climb/island_ch2.png`, `assets/art/ui/climb/island_ch3.png`, `assets/art/ui/climb/island_desert.png`, `assets/art/ui/climb/island_hellfire.png`, `assets/art/ui/climb/island_sky_isles.png`, `assets/art/ui/climb/island_swamp.png`, `assets/art/ui/climb/islands.json` | — | **installed** | unknown | no record | `design/art/climb-map-asset-spec-2026-11-07.md` | prototype: climb-map-asset-spec Phase 3 "needs approval", Phase 5 "after the prototype is approved"; no island has a result-approval record; the Lattice Heart island is missing (backlog) |
| `ui.climb.sky_far` | sky_far | `assets/art/ui/climb/sky_far.png` | 640x424 | **installed** | unknown | no record | `design/art/climb-map-asset-spec-2026-11-07.md` |  |
| `ui.climb.stairs` | Tower Ascent stair sprites (steps x4, body, root) | `assets/art/ui/climb/stair_body.png`, `assets/art/ui/climb/stair_root.png`, `assets/art/ui/climb/stair_step_0.png`, `assets/art/ui/climb/stair_step_1.png`, `assets/art/ui/climb/stair_step_2.png`, `assets/art/ui/climb/stair_step_3.png` | — | **installed** | unknown | no record | `design/art/climb-map-asset-spec-2026-11-07.md` |  |
| `ui.climb.summit` | summit | `assets/art/ui/climb/summit.png` | 256x224 | **installed** | unknown | no record | `design/art/climb-map-asset-spec-2026-11-07.md` |  |
| `ui.map.set` | Chapter map icons, plates, stats, pennant (code-drawn) | `assets/art/ui/map/check.png`, `assets/art/ui/map/gear.png`, `assets/art/ui/map/icon_battle.png`, `assets/art/ui/map/icon_boss.png`, `assets/art/ui/map/icon_danger.png`, `assets/art/ui/map/icon_event.png`, `assets/art/ui/map/icon_miniboss.png`, `assets/art/ui/map/icon_rest.png`, `assets/art/ui/map/icon_shop.png`, `assets/art/ui/map/icon_treasure.png`, `assets/art/ui/map/node_plate.png`, `assets/art/ui/map/node_plate_boss.png`, `assets/art/ui/map/node_plate_selected.png`, `assets/art/ui/map/pennant.png`, `assets/art/ui/map/stat_blocks.png`, `assets/art/ui/map/stat_deck.png`, `assets/art/ui/map/stat_gold.png`, `assets/art/ui/map/stat_removal.png` | — | **installed** | unknown | no record | — |  |
| `ui.plates.set` | Button plates (5 looks x up/down) + gem, code-drawn | `assets/art/ui/plates/gem.png`, `assets/art/ui/plates/plate_gold_down.png`, `assets/art/ui/plates/plate_gold_up.png`, `assets/art/ui/plates/plate_grey_down.png`, `assets/art/ui/plates/plate_grey_up.png`, `assets/art/ui/plates/plate_moss_down.png`, `assets/art/ui/plates/plate_moss_up.png`, `assets/art/ui/plates/plate_navy_down.png`, `assets/art/ui/plates/plate_navy_up.png`, `assets/art/ui/plates/plate_wine_down.png`, `assets/art/ui/plates/plate_wine_up.png` | — | **installed** | unknown | no record | — |  |
| `ui.title.button_frame` | button_frame | `assets/art/ui/title/button_frame.png` | 92x27 | **installed** | unknown | no record | — |  |
| `ui.title.hero_back_ne` | hero_back_ne | `assets/art/ui/title/hero_back_ne.png` | 84x84 | **installed** | unknown | no record | — |  |
| `ui.title.menu_bg` | menu_bg | `assets/art/ui/title/menu_bg.png` | 640x360 | **installed** | unknown | no record | — |  |
| `ui.icons_55` | HUD icon sheet 55 px (16 icons, OSFE-style) | `assets/art/ui/ui_icons_55.png`, `assets/art/ui/ui_icons_55.json` | 223x223 | **installed** | unknown | no record | `design/assets/specs/slice1-combat-ui-assets.md` |  |

## Card art

| Registry id | Name | File(s) | Size | Status | Accepted | Approved | Spec | Note |
|---|---|---|---|---|---|---|---|---|
| `card.bang_chau` | Card art 32x32: bang_chau | `assets/art/cards/bang_chau.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.chan_phong` | Card art 32x32: chan_phong | `assets/art/cards/chan_phong.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.dai_dao` | Card art 32x32: dai_dao | `assets/art/cards/dai_dao.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.han_khi` | Card art 32x32: han_khi | `assets/art/cards/han_khi.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.hoa_tinh` | Card art 32x32: hoa_tinh | `assets/art/cards/hoa_tinh.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.hoa_tran` | Card art 32x32: hoa_tran | `assets/art/cards/hoa_tran.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.hoa_xa` | Card art 32x32: hoa_xa | `assets/art/cards/hoa_xa.png` | 32x32 | **installed** | yes  | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.kiem_khi` | Card art 32x32: kiem_khi | `assets/art/cards/kiem_khi.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.kiem_vu` | Card art 32x32: kiem_vu | `assets/art/cards/kiem_vu.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.ran_kich` | Card art 32x32: ran_kich | `assets/art/cards/ran_kich.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.suong_mong` | Card art 32x32: suong_mong | `assets/art/cards/suong_mong.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.thiet_kiem` | Card art 32x32: thiet_kiem | `assets/art/cards/thiet_kiem.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.xung_kich` | Card art 32x32: xung_kich | `assets/art/cards/xung_kich.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.liet_hoa` | Card art 32x32: liet_hoa | `assets/art/cards/liet_hoa.png` | 32x32 | **candidate** | unknown | no record | `design/assets/candidates/ui/card-art/prompts.md` | measured 2026-11-13: background #000000, 0/6 colours in tessera_master.gpl — predates the card-art Master Reference (§4); not reviewed by the user |
| `card.thien_hoa` | Card art 32x32: thien_hoa | `assets/art/cards/thien_hoa.png` | 32x32 | **candidate** | unknown | no record | `design/assets/candidates/ui/card-art/prompts.md` | measured 2026-11-13: background #1F2835, 0/9 colours in tessera_master.gpl — predates the card-art Master Reference (§4); not reviewed by the user |
| `card.do_kiem` | Card art 32x32: do_kiem | `assets/art/cards/do_kiem.png` | 32x32 | **candidate** | pending | no record | `design/assets/candidates/ui/card-art/pilot-prompts-2026-11-13.md` | seed not returned by the job receipt |
| `card.hoa_loi` | Card art 32x32: hoa_loi | `assets/art/cards/hoa_loi.png` | 32x32 | **candidate** | pending | no record | `design/assets/candidates/ui/card-art/pilot-prompts-2026-11-13.md` | seed not returned by the job receipt |
| `card.khien_thep` | Card art 32x32: khien_thep | `assets/art/cards/khien_thep.png` | 32x32 | **candidate** | pending | no record | `design/assets/candidates/ui/card-art/pilot-prompts-2026-11-13.md` | seed not returned by the job receipt |
| `card.ngan_kiem` | Card art 32x32: ngan_kiem | `assets/art/cards/ngan_kiem.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.tram_dia` | Card art 32x32: tram_dia | `assets/art/cards/tram_dia.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.hoa_tuyen` | Card art 32x32: hoa_tuyen | `assets/art/cards/hoa_tuyen.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.thien_thach` | Card art 32x32: thien_thach | `assets/art/cards/thien_thach.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.song_dao` | Card art 32x32: song_dao | `assets/art/cards/song_dao.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.phi_tieu` | Card art 32x32: phi_tieu | `assets/art/cards/phi_tieu.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.dau_tu` | Card art 32x32: dau_tu | `assets/art/cards/dau_tu.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.bay_kep` | Card art 32x32: bay_kep | `assets/art/cards/bay_kep.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.moc_keo` | Card art 32x32: moc_keo | `assets/art/cards/moc_keo.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.gai_no` | Card art 32x32: gai_no | `assets/art/cards/gai_no.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.thanh_thuan` | Card art 32x32: thanh_thuan | `assets/art/cards/thanh_thuan.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.chuong_thanh` | Card art 32x32: chuong_thanh | `assets/art/cards/chuong_thanh.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.thien_quang` | Card art 32x32: thien_quang | `assets/art/cards/thien_quang.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.lien_tram` | Card art 32x32: lien_tram | `assets/art/cards/lien_tram.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.kiem_than` | Card art 32x32: kiem_than | `assets/art/cards/kiem_than.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.song_kiem` | Card art 32x32: song_kiem | `assets/art/cards/song_kiem.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.tu_kiem` | Card art 32x32: tu_kiem | `assets/art/cards/tu_kiem.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.thuong_xuyen` | Card art 32x32: thuong_xuyen | `assets/art/cards/thuong_xuyen.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.dap_vo` | Card art 32x32: dap_vo | `assets/art/cards/dap_vo.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.min_tre` | Card art 32x32: min_tre | `assets/art/cards/min_tre.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.bay_lo` | Card art 32x32: bay_lo | `assets/art/cards/bay_lo.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.chuoi_set` | Card art 32x32: chuoi_set | `assets/art/cards/chuoi_set.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.loc_cuon` | Card art 32x32: loc_cuon | `assets/art/cards/loc_cuon.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.dia_chan` | Card art 32x32: dia_chan | `assets/art/cards/dia_chan.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.tuong_da` | Card art 32x32: tuong_da | `assets/art/cards/tuong_da.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.hoi_am` | Card art 32x32: hoi_am | `assets/art/cards/hoi_am.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.thien_lang` | Card art 32x32: thien_lang | `assets/art/cards/thien_lang.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.ran_van` | Card art 32x32: ran_van | `assets/art/cards/ran_van.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.tran_gai` | Card art 32x32: tran_gai | `assets/art/cards/tran_gai.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.gai_nguyen` | Card art 32x32: gai_nguyen | `assets/art/cards/gai_nguyen.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.gai_doc` | Card art 32x32: gai_doc | `assets/art/cards/gai_doc.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.ganh_nang` | Card art 32x32: ganh_nang | `assets/art/cards/ganh_nang.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.oan_hon` | Card art 32x32: oan_hon | `assets/art/cards/oan_hon.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.bang_phong` | Card art 32x32: bang_phong | `assets/art/cards/bang_phong.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.han_bang` | Card art 32x32: han_bang | `assets/art/cards/han_bang.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.bang_vo` | Card art 32x32: bang_vo | `assets/art/cards/bang_vo.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.hoa_bang` | Card art 32x32: hoa_bang | `assets/art/cards/hoa_bang.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.han_kiem` | Card art 32x32: han_kiem | `assets/art/cards/han_kiem.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.thanh_thuy` | Card art 32x32: thanh_thuy | `assets/art/cards/thanh_thuy.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.han_phong` | Card art 32x32: han_phong | `assets/art/cards/han_phong.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.han_tran` | Card art 32x32: han_tran | `assets/art/cards/han_tran.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.bang_tam` | Card art 32x32: bang_tam | `assets/art/cards/bang_tam.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.cuong_phong` | Card art 32x32: cuong_phong | `assets/art/cards/cuong_phong.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |
| `card.vung_lay` | Card art 32x32: vung_lay | `assets/art/cards/vung_lay.png` | 32x32 | **installed** | unknown | no record | `design/assets/candidates/ui/card-art/batch3/prompts.json` |  |

## Loose textures

| Registry id | Name | File(s) | Size | Status | Accepted | Approved | Spec | Note |
|---|---|---|---|---|---|---|---|---|
| `texture.fx_telegraph_stripe_8` | fx_telegraph_stripe_8 | `assets/art/vfx/fx_telegraph_stripe_8.png` | 8x8 | **installed** | unknown | no record | `design/assets/specs/slice1-combat-ui-assets.md` | fallback stripe texture (shader stripes are code); 2026-10-31 manifest row: In Progress |

## Other

| Registry id | Name | File(s) | Size | Status | Accepted | Approved | Spec | Note |
|---|---|---|---|---|---|---|---|---|
| `other.vfx_cast_index` | Cast VFX index (packs, impact styles, card casts, glyphs) | `assets/art/vfx/cast/index.json` | — | **installed** | unknown | no record | — | read by src/art/cast_vfx.gd; data, not art — status by location only |
| `other.vfx_floor_index` | Floor VFX index | `assets/art/vfx/floor/index.json` | — | **installed** | unknown | no record | — | read by src/art/floor_vfx.gd |
| `other.vfx_status_index` | Status overlay index | `assets/art/vfx/status/index.json` | — | **installed** | unknown | no record | — | read by src/art/status_packs.gd |
| `other.pickup_voxel_config` | Ground Block pickup voxel config (code-drawn pickups) | `assets/art/vfx/pickup_voxel.json` | — | **installed** | unknown | no record | — | read by src/art/voxel_piece.gd; no PNG |
| `other.regions_config` | Region map: chapter -> region, fallback bands, half tints | `assets/art/regions.json` | — | **installed** | unknown | no record | — | read by src/art/art_assets.gd; fallback bands are flat colours for regions without art |
| `other.region_forest_config` | Misty Forest region config (backdrop, slab, platform, support, areas) | `assets/art/env/forest/region.json` | — | **installed** | unknown | no record | — | read by src/art/art_assets.gd |
| `other.region_hellfire_config` | Thành Hỏa Ngục region config (backdrop, slab, platform, support, areas) — generated 2026-11-12 by tools/asset-pipeline/make_region_env.py | `assets/art/env/hellfire/region.json` | — | **installed** | unknown | no record | — | read by src/art/art_assets.gd |
| `other.region_sands_config` | Sa Mạc Cát Vùi region config (backdrop, slab, platform, support, areas) — generated 2026-11-12 by tools/asset-pipeline/make_region_env.py | `assets/art/env/sands/region.json` | — | **installed** | unknown | no record | — | read by src/art/art_assets.gd |
| `other.region_swamp_config` | Đầm Lầy Độc region config (backdrop, slab, platform, support, areas) — generated 2026-11-12 by tools/asset-pipeline/make_region_env.py | `assets/art/env/swamp/region.json` | — | **installed** | unknown | no record | — | read by src/art/art_assets.gd |
| `other.region_dungeon_config` | Hầm Ngục region config (backdrop, slab, platform, support, areas) — generated 2026-11-12 by tools/asset-pipeline/make_region_env.py | `assets/art/env/dungeon/region.json` | — | **installed** | unknown | no record | — | read by src/art/art_assets.gd |
| `other.region_ice_tower_config` | Tháp Sương region config (backdrop, slab, platform, support, areas) — generated 2026-11-12 by tools/asset-pipeline/make_region_env.py | `assets/art/env/ice_tower/region.json` | — | **installed** | unknown | no record | — | read by src/art/art_assets.gd |
| `other.region_sky_isles_config` | Không Đảo region config (backdrop, slab, platform, support, areas) — generated 2026-11-12 by tools/asset-pipeline/make_region_env.py | `assets/art/env/sky_isles/region.json` | — | **installed** | unknown | no record | — | read by src/art/art_assets.gd |
| `other.region_lattice_heart_config` | Tâm Lưới (final) region config (backdrop, slab, platform, support, areas) — generated 2026-11-12 by tools/asset-pipeline/make_region_env.py | `assets/art/env/lattice_heart/region.json` | — | **installed** | unknown | no record | — | read by src/art/art_assets.gd |

## Backlog — required, no production file yet

| Id | What | Required by | Note |
|---|---|---|---|
| `portrait.kiem_si` | Character-select portrait 64x80 for kiem_si | design/assets/asset-manifest-2026-10-31-archive.md ASSET-002 (Needed); design/assets/entity-inventory.md rows 6-10; art bible §5.5 | character_select_view.gd draws the sheet's idle frame instead; paid generation needs the user's yes |
| `portrait.phap_su` | Character-select portrait 64x80 for phap_su | design/assets/asset-manifest-2026-10-31-archive.md ASSET-002 (Needed); design/assets/entity-inventory.md rows 6-10; art bible §5.5 | character_select_view.gd draws the sheet's idle frame instead; paid generation needs the user's yes |
| `portrait.sat_thu` | Character-select portrait 64x80 for sat_thu | design/assets/asset-manifest-2026-10-31-archive.md ASSET-002 (Needed); design/assets/entity-inventory.md rows 6-10; art bible §5.5 | character_select_view.gd draws the sheet's idle frame instead; paid generation needs the user's yes |
| `portrait.tho_san` | Character-select portrait 64x80 for tho_san | design/assets/asset-manifest-2026-10-31-archive.md ASSET-002 (Needed); design/assets/entity-inventory.md rows 6-10; art bible §5.5 | character_select_view.gd draws the sheet's idle frame instead; paid generation needs the user's yes |
| `portrait.giao_si` | Character-select portrait 64x80 for giao_si | design/assets/asset-manifest-2026-10-31-archive.md ASSET-002 (Needed); design/assets/entity-inventory.md rows 6-10; art bible §5.5 | character_select_view.gd draws the sheet's idle frame instead; paid generation needs the user's yes |
| `env.dungeon.slab_set` | Slab 9-slice + stamps: dungeon | assets/art/regions.json (region mapped, no env/dungeon/); design/assets/entity-inventory.md rows 81-94 | fallback flat bands drawn today (regions.json fallback_bands) |
| `env.dungeon.backdrop` | Far backdrop 800x360: dungeon | assets/art/regions.json; design/assets/entity-inventory.md rows 81-94 | — |
| `unit.dungeon.roster` | Enemy bodies + warden for dungeon | assets/data/chapters.json enemy ids with no sheet; design/assets/entity-inventory.md rows 22-78 | ids and count to confirm with the user: chapters.json mixes enemy ids with pattern ids, and the roster may change |
| `env.ice_tower.slab_set` | Slab 9-slice + stamps: ice_tower | assets/art/regions.json (region mapped, no env/ice_tower/); design/assets/entity-inventory.md rows 81-94 | fallback flat bands drawn today (regions.json fallback_bands) |
| `env.ice_tower.backdrop` | Far backdrop 800x360: ice_tower | assets/art/regions.json; design/assets/entity-inventory.md rows 81-94 | — |
| `unit.ice_tower.roster` | Enemy bodies + warden for ice_tower | assets/data/chapters.json enemy ids with no sheet; design/assets/entity-inventory.md rows 22-78 | ids and count to confirm with the user: chapters.json mixes enemy ids with pattern ids, and the roster may change |
| `env.swamp.slab_set` | Slab 9-slice + stamps: swamp | assets/art/regions.json (region mapped, no env/swamp/); design/assets/entity-inventory.md rows 81-94 | fallback flat bands drawn today (regions.json fallback_bands) |
| `env.swamp.backdrop` | Far backdrop 800x360: swamp | assets/art/regions.json; design/assets/entity-inventory.md rows 81-94 | — |
| `unit.swamp.roster` | Enemy bodies + warden for swamp | assets/data/chapters.json enemy ids with no sheet; design/assets/entity-inventory.md rows 22-78 | ids and count to confirm with the user: chapters.json mixes enemy ids with pattern ids, and the roster may change |
| `env.sands.slab_set` | Slab 9-slice + stamps: sands | assets/art/regions.json (region mapped, no env/sands/); design/assets/entity-inventory.md rows 81-94 | fallback flat bands drawn today (regions.json fallback_bands) |
| `env.sands.backdrop` | Far backdrop 800x360: sands | assets/art/regions.json; design/assets/entity-inventory.md rows 81-94 | — |
| `unit.sands.roster` | Enemy bodies + warden for sands | assets/data/chapters.json enemy ids with no sheet; design/assets/entity-inventory.md rows 22-78 | ids and count to confirm with the user: chapters.json mixes enemy ids with pattern ids, and the roster may change |
| `env.hellfire.slab_set` | Slab 9-slice + stamps: hellfire | assets/art/regions.json (region mapped, no env/hellfire/); design/assets/entity-inventory.md rows 81-94 | fallback flat bands drawn today (regions.json fallback_bands) |
| `env.hellfire.backdrop` | Far backdrop 800x360: hellfire | assets/art/regions.json; design/assets/entity-inventory.md rows 81-94 | — |
| `unit.hellfire.roster` | Enemy bodies + warden for hellfire | assets/data/chapters.json enemy ids with no sheet; design/assets/entity-inventory.md rows 22-78 | ids and count to confirm with the user: chapters.json mixes enemy ids with pattern ids, and the roster may change |
| `env.sky_isles.slab_set` | Slab 9-slice + stamps: sky_isles | assets/art/regions.json (region mapped, no env/sky_isles/); design/assets/entity-inventory.md rows 81-94 | fallback flat bands drawn today (regions.json fallback_bands) |
| `env.sky_isles.backdrop` | Far backdrop 800x360: sky_isles | assets/art/regions.json; design/assets/entity-inventory.md rows 81-94 | — |
| `unit.sky_isles.roster` | Enemy bodies + warden for sky_isles | assets/data/chapters.json enemy ids with no sheet; design/assets/entity-inventory.md rows 22-78 | ids and count to confirm with the user: chapters.json mixes enemy ids with pattern ids, and the roster may change |
| `env.lattice_heart.slab_set` | Slab 9-slice + stamps: lattice_heart | assets/art/regions.json (region mapped, no env/lattice_heart/); design/assets/entity-inventory.md rows 81-94 | fallback flat bands drawn today (regions.json fallback_bands) |
| `env.lattice_heart.backdrop` | Far backdrop 800x360: lattice_heart | assets/art/regions.json; design/assets/entity-inventory.md rows 81-94 | — |
| `unit.lattice_heart.roster` | Enemy bodies + warden for lattice_heart | assets/data/chapters.json enemy ids with no sheet; design/assets/entity-inventory.md rows 22-78 | ids and count to confirm with the user: chapters.json mixes enemy ids with pattern ids, and the roster may change |
| `ui.climb.island_lattice_heart` | Tower Ascent island: Lattice Heart summit | design/art/climb-map-asset-spec-2026-11-07.md Phase 5; assets/art/ui/climb/islands.json has no an_dai entry | candidate design/assets/candidates/climb-map/s-lattice-heart-01.png exists, not shipped |
| `vfx.status.elite_boss_overlays` | Burn / frozen / chill overlays sized for 80x80 elites and 160x130 bosses | audit docs/art/AI-ART-WORKFLOW-AUDIT-2026-11-11.md §6 #5; assets/art/vfx/status/index.json has hero/goblin only | user decision: accept the goblin-size overlay on big bodies, or author new packs (free vfx_workbench) |
