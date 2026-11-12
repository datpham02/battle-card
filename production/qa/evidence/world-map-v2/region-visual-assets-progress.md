# World Map v2 — Region visual assets, all 7 regions (progress report)

Started 2026-11-12 (side session, autonomous). Scope: visual assets + their integration only — no gameplay,
roster, balance, save, graph or rule changes. Nothing committed, pushed or deployed. Resume rule: read this
file, then `git status`; never discard existing work.

## 1. Initial audit (2026-11-12)

### 1.1 How region art reaches the screen today

| Piece | Where | Finding |
|---|---|---|
| Chapter → art region | `assets/art/regions.json` `chapters` | ch1→forest, hellfire→hellfire, desert→sands, swamp→swamp, ch2→dungeon, ch3→ice_tower, sky_isles→sky_isles, an_dai→lattice_heart. Already correct, no change needed. |
| Region art bundle | `assets/art/env/<region>/region.json` (`ArtAssets.region`) | **Only `forest/` exists.** Every other region returns `{}` (one warning) → flat fallback. |
| Backdrop | `BackdropLayer` (`backdrop.far` 800×360, optional `backdrop.near`, `ground_shade`, `modulate`) | Without art: two flat bands from `regions.json` `fallback_bands` (confirmed: 6 of 7 climb regions + Lattice Heart draw flat bands today). |
| Board slabs | `FloorLayer` (`slab.nine_slice` 16×16 + `slab.stamps` sheet + JSON meta, or `slab.flagstones`) | Without art: `SlabPainter.FALLBACK_STONE` flat grey rect per cell, default platform palette (forest grey). |
| Platform (deck / face / divider / pit colours) | `region.json` `platform` | Without it: forest greys hardcoded as defaults. |
| Foundation wall, pillars, arches, ferns, roots | `SupportLayer` (`support` block; textures optional, coded stone courses fallback) | Without a `support` block the layer draws nothing (board floats on the flat band). |
| Thorn hazard tile | `thorn_tile` 16×16 | Without it: flat thorn colour. |
| Half tints | `region.json` `half_tints` else `regions.json` | Shared blue / plum defaults for every non-forest region. |
| Floor progression inside a region | `region.json` `areas.rules` + `areas.art.<area>` (`ArtAssets.area_for`, `GameFlow.current_art_area`) | Forest: edge (columns ≤ 34 %) → ruins → sanctum (boss). Mechanism is generic; only forest uses it. |
| Map screen backdrop | `ChapterMapView._draw_backdrop` | Draws `backdrop.far` of the current area under a veil → every new far backdrop is also the map screen's background. |
| Climb map islands | `assets/art/ui/climb/island_<chapter>.png` + `islands.json` | **All 7 regions have islands** (320×192). World map tint uses `fallback_bands`. Reused as is. |
| Hazard visuals (vents, mire, sand, crumble, pit) | `FloorDynamicLayer`, `CastFloorFx`, `BurnPainter` | Code-drawn with signal colours; pit uses the region `platform` palette. No per-region art needed; the region palette feeds them. |
| Dev launch for QA | `--node=fF/<region>/cC/nN --seed=N --shot=<png>` (`GameFlow`, `DemoArgs`) | c0 = first battle, c6 = warden (boss) → sanctum area. |

### 1.2 Existing assets

- `assets/art/env/forest/`: far backdrops v1–v4 + edge + sanctum (800×360, ≤ 40 colours), near mist 800×48,
  9-slice 16×16, stamps 96×48 + JSON (18 stamps), flagstones 256×256, platform face 231×12, support wall 231×44,
  pillar 28×56, arch 72×40, roots 64×64, ferns 96×32, thorn tile v1/v2. This is the quality + format reference.
- `assets/art/ui/climb/`: islands for all 7 regions, clouds, stairs, summit, sky.
- `design/art/reference/07-<region>-01.png`: ChatGPT concepts per region — composition / mood reference only
  (art bible §6.4: never redrawn from).
- Design sources for each identity: `design/art/region-visual-brief-2026-11-05.md`,
  `docs/art/REGION-MATERIALS-AND-PALETTE.md`, `docs/art/RENDER-STANDARDS.md` §4, art bible §6.1–6.6,
  `design/assets/regions/<region>.yaml` (all six say `environment: missing`).

### 1.3 What is missing per region (before this task)

| Region (chapter) | Backdrop | Slabs | Platform palette | Support | Thorn tile | Areas | Island |
|---|---|---|---|---|---|---|---|
| forest (ch1) | ✅ v4 + edge + sanctum | ✅ | ✅ | ✅ kit | ✅ | ✅ 3 | ✅ |
| hellfire | ❌ bands | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| sands (desert) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| swamp | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| dungeon (ch2) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| ice_tower (ch3) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| sky_isles | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| lattice_heart (final, not a climb region) | ❌ | ❌ | ❌ | ❌ | ❌ | — | — (final cube) |

### 1.4 Tooling available in this session

- PixelLab (paid gens): subscription active, 2153 generations left — but the project's standing rule requires the
  user's explicit "yes" **per generation call in this session**, and this session is autonomous with the user away.
  → No paid generation is spent here. Paid upgrade prompts are written in §8 for the user to approve later.
- Free: `pixelart_workbench`, Python 3.12 standard library (no Pillow / numpy on this machine; the project's own
  PNG codec in `tools/fx-pipeline/fxkit/pngio.py` / `export_sheets.py` is reused), Godot 4.6.3 windowed captures.
- Precedent: the forest slab 9-slice, stamps, thorn tile, mist strip, wall courses and the sky / ground / mist
  layers of the first backdrops were drawn by script in this project (active.md 2026-10-31 → 11-06); PixelLab was
  then used for the painterly far backdrops and the support kit.

### 1.5 Integration plan (decided)

1. One generator script, `tools/asset-pipeline/make_region_env.py` (deterministic, seeded), writes for each of the
   six regions: far backdrops (base `edge` / inner `ruins`-equivalent / `sanctum` variants), an optional near strip
   (drifting mist / cloud / sand haze / ash), 9-slice, stamps sheet + JSON, thorn tile, support wall / pillar /
   arch recoloured colour-for-colour from the forest kit (mechanical recolour only), and `region.json`.
2. `region.json` per region follows the forest schema exactly (backdrop, slab, platform, support, half_tints,
   thorn_tile, areas) so no engine code changes are needed for the art to load.
3. `.import` files are produced by Godot on first launch (`godot --headless --import`) — same settings as forest
   (lossless, no mipmaps, nearest on the node).
4. Lattice Heart gets a backdrop + slab set too (final match; cheap once the generator exists) — documented as a
   bonus, not part of the 7-region claim.

## 2. Visual direction per region (from the approved design sources, nothing invented)

| Region | Mood (brief) | Sky / far / near | Slab (3 tones + cover) | Platform / support | Area variation over the floor |
|---|---|---|---|---|---|
| Forest | lost in gentle ruins, low mist | existing v4 / edge / sanctum | grey-moss stone, moss at corners | existing kit | edge → ruins → sanctum (existing) |
| Hellfire | pulse, pressure, hottest; V ≤ 25 | charcoal sky, black spires + chains, lava only in cracks (`#FFB21F`, 2 px max), no bright orange | charcoal basalt `#3A3436/#2A2628/#1F1B1D`, ash + scorched edges; vein stamps | obsidian deck, charred wall | outer wall (spires far) → citadel (chains, pillars) → caldera sanctum (dark, vein-lit cracks in the ground) |
| Sands | vast, buried; light V 60–72 | dusty beige sky, dunes, half-buried arches / columns, jade-dulled jar `#4F8A80`, sand haze strip | pale sandstone `#A89A80/#8E8268/#6E6248`, sand spill from one side | sandstone deck, buried wall | open dunes → buried plaza (columns) → sphinx court (big arch, darker) |
| Swamp | heavy, sticky; V ≤ 40 | olive-grey sky, low ruins in fog, flat water, sunken columns, reeds, mushrooms `#6A5868`, drifting toxic fog | mud-stone `#5A5848/#4A4838/#3A382A`, weed / sunken edges | mud deck, roots + reeds (forest roots / ferns recoloured) | reed shore → sunken ruins → toad hollow (mushrooms, darker) |
| Dungeon | closed, oppressive; V ≤ 30, no sky | vault wall instead of sky, 4–5 pillars, hanging chains, torches as dull ochre `#8A6A40` (no glow) | cold grey-blue `#4A4E5A/#3E4450/#2E323B`, dust + rust chain stamps | grey deck, cell wall + pillars | cell block → vault (arches) → throne hall (banners, darker) |
| Ice Tower | lonely, colder; far V 60–72, slabs dark | lavender-blue sky `#8E95B8`, cloud sea, 2–3 far towers, railings + low ice pillars at the margins, cloud strip; **no cyan** | dark blue-grey `#5A6078/#4C5266/#3E4256`, frost at edges (blue-grey) | blue-grey deck, frosted wall | terrace → spire gallery → summit (towers near, cloud lower) |
| Sky Isles | wind, precarious; V 55–72 | bright horizon band, thunder-yellow S ≤ 30 %, 1–2 static lightning lines, cloud sea one step darker, far small islands, nothing under the board but cloud | wind-worn tan-grey `#6E645A/#5A5048/#46403A`, almost no cover | island rock deck, tapered rock foot | outer isles → bridge isles → storm peak (lightning, dragon perch) |
| Lattice Heart (final) | solemn, bare; V ≤ 20 | indigo `#15142A`, no horizon, ivory-grey dais + columns, 1 px gold lattice 20–40 % | bare slab with square-in-square groove | indigo deck | — (one match) |

Signal colours kept out of every backdrop and slab: `#E5293B`, `#FFD45C` (except the Lattice Heart lattice lines,
per the bible), `#FF7A1F`, `#A6EEFF`, `#3A5CF0`, `#E04CD0`, `#A8C83A`, the five heroes' block colours.

(Sections 3–8 are filled in as the work lands below.)

## 3. Visual audit v1 — "one template, seven colours" (2026-11-12, after the user's correction)

Evidence: `region-visuals/20-audit-farbands-v1.png` (the far bands of all seven, stacked),
`region-visuals/21-audit-ingame-v1.png` (first battle of every region + the Sky Isles warden, 1280×720 halved),
and the per-region shots `01`–`13`.

| Dimension | Finding across the six generated regions | Verdict |
|---|---|---|
| Composition | Every scripted backdrop was built by one function chain: stepped sky → silhouette row on the 72 px horizon → a rubble edge → calm ground → two framing pillars → a broken polyomino stone bottom-left and an ivory broken sword bottom-right. The same skeleton in six colour keys. | **Fail** |
| Silhouette | Hellfire, swamp, dungeon, sands, ice all draw a row of **arches** on the horizon (the same `arch()` primitive); hellfire / ice / swamp / sands share `tower()` + `spire()` rows. Only Sky Isles (floating islands) and dungeon (vault, no sky) have a silhouette of their own. | **Fail** (4 of 6 alike) |
| Architecture | The board's foundation is the **forest support kit recoloured** in all six (same wall strip, same pillar, same recessed arch) — the forest's ruined-cloister stonework appears under a desert plaza, a swamp shore, a floating island. | **Fail** (explicitly the "same structure with different colours" case) |
| Terrain / ground | Same calm stepped earth + rubble in all six; the one terrain idea per region from the brief (sand spill, sunken mud, cracked basalt, cloud below the rim, frost) is missing or 1-px small. | **Fail** |
| Palette | Each region keeps its brief palette (charcoal / dusty beige / olive / grey-blue / lavender / storm blue) and V caps. | Pass |
| Atmosphere | Only hellfire (ash bands + veins), swamp (fog), sky (thunder band, clouds) and ice (cloud sea) carry an atmosphere device; dungeon and sands have none beyond the colour. | Weak |
| In-game read | Side by side (`21-audit-ingame-v1.png`), the regions are distinguishable by hue and by the slab tint, not by the environment: the foundation wall with its two arches is the most visible non-board element in every shot and it is identical in all seven. | **Fail** |

What is genuinely shared and allowed to stay shared (art bible §6.1: "Phiến giống nhau ở mọi vùng (ramp Đá chung). Vùng chỉ
đổi thứ phủ lên mép/khe và đồ vật bao quanh"): the slab 9-slice geometry and the 8–16 px stamp decals (recoloured to the
region's ramp + cover colour), the thorn hazard tile, the platform palette keys, the `region.json` schema and the
area rules. Everything else listed under "Fail" is replaced per region in §4–§6 below.

## 4. Seven independent art directions (from the approved brief §1–§7, bible §2 / §6.4 / §6.5; nothing invented)

| | Identity | Palette (primary / secondary) | Silhouette (far band) | Terrain | Architecture | Foreground (margins) | Midground (board foot) | Atmosphere | Signature |
|---|---|---|---|---|---|---|---|---|---|
| **Forest** (keep) | gentle ruins lost in mist | moss grey-green / cool grey, mist #7D8896 | tree crowns and one ruined arch | dark earth, roots | round-arched cloister stone, moss | great trunks and roots | mossy retaining wall, ferns | low drifting mist | roots gripping square-cut stone |
| **Hellfire** | the citadel is a furnace; pressure | charcoal #24201E / soot, dark bronze; amber only in cracks | one **massive black fortress** with jagged spires and an iron gate, chains spanning the sky | cracked basalt plaza, veins glowing in the cracks | brutal slab-sided obsidian walls, iron, chains (no arches) | basalt columns wrapped in chains | a basalt ledge split by glowing cracks, iron spikes | ash clouds, heat shimmer absent (matte) | the gate + chains + veins |
| **Sands** | vast, buried; time wins | dusty beige #A89A80 / ochre, dull jade #4F8A80 | **rolling dunes** with a drowned city: domes and a half-buried colonnade | sand drifting across sandstone paving | smooth sandstone, domes, square-cut columns worn round | fallen column drums, a jade jar | a sandstone step with sand pouring over its lip | sand haze, bright sky (V 60–72) | the half-buried dome + jade jar |
| **Swamp** | heavy, sticky, drowned | olive #4E4C3C / mud brown, violet-grey mushrooms #6A5868 | **flat black water** with drowned columns and dead trees, no skyline | mud and sunken slabs, pools | drowned stone sinking at an angle, wood piers | gnarled dead trees, reeds | a mud bank with sunken logs and roots, reeds, mushrooms | low toxic fog patches | mushrooms + drowned columns |
| **Dungeon** | sealed in; weight above | cold grey-blue #3E4450 / rust, soot; ochre torch #8A6A40 | **no sky**: one stone wall of cell gates and chains fills the band | worn flagstones, rubble, a collapsed pit | massive square pillars, iron bars, barrel vaults | iron-barred cells, chains | dressed stone footing with iron rings and bars | darkness, dull unlit torches | the cell gates + chains |
| **Ice Tower** | alone above the clouds | lavender-blue #8E95B8 / slate #4C5266, frost white (no cyan) | **cloud sea** with distant spired towers and a broken bridge | frost-rimed dark stone terrace | thin tall towers, balustrades, icicles | balustrade, frosted pillars, low ice crystals | a frosted parapet with icicles hanging below | pale sky, cloud below | the cloud sea + spires |
| **Sky Isles** | the ground leaves; wind | storm grey-blue #8AA2B8 / storm yellow S ≤ 30 %, wind-worn tan | **floating islands** hanging in a storm sky, two static lightning bolts | wind-worn rock island top, cloud under the rim | rope bridges, tapered rock undersides, wind-eroded stone | broken rope bridges off the island edge | **no wall**: a tapered rock foot (bible §6.3) and cloud beneath | storm light band, cloud sea | the islands + lightning + rope bridge |
| *(final) Lattice Heart* | solemn, bare | indigo #15142A / ivory-grey, gold lattice 1 px | no horizon: dais + columns under a gold lattice | bare lattice | ivory-grey dais, 4–6 columns | columns | indigo dais edge | lattice lines | the lattice |

Reuse policy applied: shared = slab geometry + stamp decals (recoloured), thorn tile, platform palette schema, area
rules, HUD. Region-specific = the far backdrop (one generation per region, independent prompt), the board's
foundation strip (one scripted or generated strip per region, different silhouette), the margin props, the near
atmosphere strip. The forest support kit (wall / pillar / arch / roots / ferns) stays **forest-only** (swamp keeps
the roots and ferns because they are the swamp's own motif in the brief: "rễ", "lau sậy").

## 5. Asset reuse analysis (after the correction)

| Element | Forest | 6 generated regions | Shared? | Why |
|---|---|---|---|---|
| Far backdrop 800×360 | PixelLab v4 (+ edge / sanctum) | **one PixelLab `create_image_pro` 792×336 per region, its own prompt, seed and composition** (§6) | No | the identity carrier |
| Board foundation strip 231×44 | PixelLab cloister wall | **own scripted silhouette per region**: basalt columns + veins / buried ashlar + sand drift / mud bank + sunken logs / dressed stone + barred cells + iron rings / frosted blocks + icicles / tapered rock underside over nothing (Sky Isles, no foot shadow) | No | the most visible non-board element |
| Pillar 28×56 | PixelLab | own per region where the architecture has pillars (hellfire chained column, sands worn drum, dungeon iron-banded pier, ice frosted pier); none for swamp / sky | No | — |
| Recessed arch 72×40 | PixelLab | **removed** from every other region | No | it was the forest's cloister |
| Roots 64×64 / ferns 96×32 | PixelLab | swamp only, recoloured (its brief names roots and reeds) | Swamp only | genuinely belongs to both |
| Slab 9-slice 16×16 | scripted | same geometry, region 3-tone ramp | Yes | bible §6.1: slabs are the shared Root-Form grid; only the cover changes |
| Stamp decals 96×48 | scripted | recoloured colour-for-colour (cover = ash / sand / weed / dust / frost / wind-wear), density rules per region | Yes (technical, 8–16 px) | same rule |
| Thorn tile 16×16 | scripted | recoloured | Yes (hazard tile, code-placed) | gameplay readability |
| Platform palette, half tints | region.json | region.json, own values | schema only | — |
| Near strip (mist) | PixelLab, off | **none** (the generated far carries its own fog / haze / cloud; the scripted strip read as a checker stripe) | — | — |
| Area variants (floor progression) | 3 generated backdrops | 1 generated backdrop + `modulate` per area (edge lighter, sanctum darker) + support density | — | see §10: sanctum backdrops are the next paid pass |

## 6. Assets created / regenerated (2026-11-12)

PixelLab, user-approved in this session ("Duyệt cả 6 lần gọi"), `create_image_pro` 792×336, `max_colors` 40,
`no_background` false, style anchor = `bg_forest_far_v4.png` with `style_copy` outline + detail + shading only (never
its colours), 25 generations per call = **150 generations** (balance before 2153.9):

| Region | Job | Seed | Raw candidate (kept) | Installed as |
|---|---|---|---|---|
| hellfire | `896c484d-73fe-4ef0-ad75-ff9e2d066d29` | 1102 | `design/assets/candidates/regions-v2/hellfire-pro-01-792x336.png` | `assets/art/env/hellfire/bg_hellfire_far_inner.png` |
| sands | `ea5f35cb-c4fa-4e6a-acd1-f999ef4daa81` | 1103 | `…/sands-pro-01-792x336.png` | `assets/art/env/sands/bg_sands_far_inner.png` |
| swamp | `cdc49bd5-0485-4a27-87c4-96ec1cacc37a` | 1104 | `…/swamp-pro-01-792x336.png` | `assets/art/env/swamp/bg_swamp_far_inner.png` |
| dungeon | `ec50dd62-8578-4701-b313-0fd11933b708` | 1105 | `…/dungeon-pro-01-792x336.png` | `assets/art/env/dungeon/bg_dungeon_far_inner.png` |
| ice_tower | `796647ea-e730-4606-9336-36863dd23b6e` | 1106 | `…/ice_tower-pro-01-792x336.png` | `assets/art/env/ice_tower/bg_ice_tower_far_inner.png` |
| sky_isles | `65a037a9-1b1b-4378-83cc-a075e5d9f4b8` | 1107 | `…/sky_isles-pro-01-792x336.png` | `assets/art/env/sky_isles/bg_sky_isles_far_inner.png` |

Install step (`make_region_env.py --install <region>=<png>`): the 792×336 is padded to 800×360 exactly like the
forest edge / sanctum backdrops (edge columns repeated ×4, 24 px Ink at the bottom), a near-black letterbox frame
(hellfire, swamp) is trimmed by extending the first real row / column, then quantized to ≤ 40 colours (bible §8.4).
The prompts are in the job records above and in the session log; each was written from the brief's own formula
(bible §6.4 table) and names nothing from another region.

Scripted (0 generations), all from `tools/asset-pipeline/make_region_env.py`, deterministic:
`env_support_<region>_wall.png` (6 own silhouettes + lattice_heart), `env_support_<region>_pillar.png` (hellfire,
sands, dungeon, ice_tower, lattice_heart), `env_slab_<region>_9slice.png`, `env_slab_<region>_stamps.png` + `.json`,
`env_thorn_<region>_tile16.png`, `env_support_swamp_{roots,ferns}.png`, `region.json` ×7. Lattice Heart (final match)
keeps a scripted backdrop (`bg_lattice_heart_far_inner.png`) as a bonus, not counted among the seven.

Removed (my own earlier scripted files, nothing pre-existing): the v1 scripted `bg_<region>_far_{edge,sanctum}.png`,
the scripted near strips, and the recoloured forest `arch` / `pillar` copies of v1, with their `.import` files.

## 7. Integration

- `assets/art/regions.json` unchanged: its `chapters` map already pointed every chapter at these folder names.
- Each `assets/art/env/<region>/region.json` follows the forest schema; `ArtAssets` resolves it without code changes.
  Keys used: `backdrop.far` (+ `ground_shade` 3 Ink bands from row 300 for the control zone, `near_enabled` false),
  `slab.*`, `thorn_tile`, `platform` (deck / face / face_top / mortar / shadow / divider — also the pit colours),
  `support` (own `wall_tile`, optional `pillar`, coded fallbacks, sky: `foot_shadow` [] and `wall_bottom_shade` []),
  `half_tints`, `areas.rules` (sanctum = boss, edge ≤ 34 % of the columns, inner) and `areas.art` (edge
  `modulate` #F4F2F6, sanctum `modulate` #CCC6D2 + darker half tints + pillar density).
- The same `backdrop.far` is what `ChapterMapView` stretches under the region map (veiled), so the map screens now
  show the region too (`region-visuals/44-map-hellfire.png`, `45-map-sky.png`, `46-map-sands.png`).
- `.import` files generated by `godot --headless --import` with the project defaults (lossless, no mipmaps; the
  canvas samples nearest). Texture memory: 7 far backdrops × 800×360 RGBA = ~1.1 MB each uncompressed, only the
  current region's is loaded by a battle (`ArtAssets` caches per path; one region per run floor).
- No engine code, data, test, save or balance file was changed. `git status` shows only `assets/art/env/<new>/`,
  `tools/asset-pipeline/make_region_env.py`, `design/assets/regions/*.yaml` (environment status),
  `design/assets/candidates/regions-v2/`, and this evidence folder as this task's changes.

## 8. Before / after and side-by-side validation (v2, 2026-11-12)

Sheets: `region-visuals/54-before-after-v1-v2.png` (left = scripted template v1, right = v2, six regions),
`50-audit-farbands-v2.png` (far bands of all seven stacked), `52-audit-backdrops-v2-full.png` (the seven full
backdrops), `51-audit-ingame-v2.png` (first battle of every region, 1280×720), `53-audit-wardens-v2.png` (the six
warden battles = sanctum area). Per-region shots: `31`–`42` (odd = column 0 battle, even = warden), `13` = forest
control.

| Region | 1. Silhouette | 2. Composition | 3. Architecture | 4. Palette | 5. Atmosphere | Recognisable without the label? |
|---|---|---|---|---|---|---|
| Forest | tree crowns + one ruined arch | trunks frame, cloister wall under the board | round-arched moss cloister | moss grey-green | low mist | yes (unchanged reference) |
| Hellfire | one jagged black fortress with a shut gate, chains across the sky | gate dead centre, chained basalt columns at the margins, cracked plaza | brutal obsidian walls, iron gate, chains; basalt-column foundation with veins | charcoal / soot / maroon, amber only in cracks | ash clouds, heat held matte | yes: gate + chains + veins |
| Sands | rolling dunes swallowing domes and a colonnade | low horizon, fallen column drums left, jade jar + arch right, sand across paving | smooth sandstone, domes, drum columns; buried ashlar foundation with a sand drift | dusty beige / ochre / jade | bright haze (V 60–72) | yes: dunes + dome + jar |
| Swamp | flat black water, drowned columns, dead trees | water band mid-far, gnarled trunks frame, mud shore | drowned stone, dead wood; mud bank with sunken logs, roots and reeds under the board | olive / mud / violet mushrooms | fog patches | yes: black water + mushrooms |
| Dungeon | no sky: a wall of cell gates and vaults | symmetrical vault, barred cells both sides, chains from the ceiling | square piers, iron bars, barrel vaults; dressed-stone foundation with barred windows and rings | cold grey-blue / soot / rust / dull ochre | darkness, unlit torches | yes: cell gates + chains |
| Ice Tower | cloud sea, thin spires, a broken bridge | balustrade with icicles across, frosted arches at the margins | thin towers, balustrade; frosted-block foundation with icicles | lavender / slate / frost white | pale sky, cloud below | yes: cloud sea + spires |
| Sky Isles | floating islands over cloud, two lightning bolts | the arena island mid-frame, rope bridges off both edges, cloud under | rope bridges, wind-worn rock; tapered rock underside with no wall and no foot shadow | storm grey-blue / storm yellow / tan | storm light band, cloud sea | yes: islands + lightning + bridges |

Pairs checked for residual similarity: hellfire ↔ dungeon (both dark): different silhouette (fortress + sky vs no
sky), different palette (maroon-charcoal vs grey-blue), different foundation (columns + veins vs ashlar + bars).
Ice ↔ sky (both have a cloud sea): ice's clouds sit *behind* a balustrade in a pale lavender frame, sky's clouds sit
*under* the island in a storm frame with lightning and a yellow horizon; foundations differ completely (frosted
wall vs rock underside). Sands ↔ forest (both have arches): warm bright dunes vs cool dark mist. No pair fails.

## 9. Visual QA (1280×720, Godot 4.6.3 windowed, `--audio-driver Dummy`, seed 27, Kiếm sĩ)

- Launched and captured: every region's column-0 battle and its warden battle (sanctum area) = 12 shots + the
  forest control; all `region.json` bundles load with **no `ArtAssets` warning and no script error** in the launch
  logs (grep of every run).
- Readability: the board, half tints, telegraph red, pickups, hero and HUD stay readable in all 13 shots; the far
  band sits under the floor title without competing with it; no backdrop object crosses the board.
- Hazard overlays confirmed on the new floors: forge / caldera vents (hellfire), wind + sand (sands), mire cells
  (swamp), crumble islands (sky), frost (ice) all draw over the region slabs as before.
- Fixes made from the in-game look (not visible on the raw images): the scripted near strips were removed (they read
  as a checker stripe across the top of the board); the v1 paving read as a wall and was dropped; the lava veins in
  the control zone were cut to a few.
- Not verified: Android / a real phone (no device in this session); the chapter map screen with the new backdrops
  could not be captured (`--shot` lives in the battle scene's DemoArgs only; the map draws the same `backdrop.far`
  texture through `ChapterMapView._draw_backdrop`, unchanged code).
- Enemy sprites for the six regions do not exist yet (known, outside this task: `docs/art/FLOOR-MAP-ROSTER.md`), so
  the enemy half of each shot shows the board only.

## 10. Remaining gaps and limitations

1. **Floor progression inside a region** uses one generated backdrop per region with `modulate` per area (edge
   lighter, sanctum darker) plus support density; the forest has three generated backdrops. A second paid pass
   (6 × `create_image_pro` 792×336 = 150 generations, one sanctum prompt per region: the warden's hall) would give
   each region a real sanctum like the forest. Not run: needs the user's approval.
2. The board foundation strips and pillars are scripted (0 generations): distinct silhouettes, but flatter than the
   forest's PixelLab wall. A paid `create_tiles_pro` / Pro Flash pass per region could replace them one for one
   (same file names, `region.json` untouched).
3. Slab 9-slice and stamp decals are the forest set recoloured, by design (bible §6.1). If a region wants its own
   cover shapes (sand ripples, frost feathers), those are 8–16 px decals to draw by script.
4. Lattice Heart (final match) has only a scripted backdrop; it was outside the "seven regions" scope.
5. `region_areas_test.gd` line 37: the "region without areas" fixture moved from `dungeon` (which now has areas) to
   `lattice_heart`; no other test or source file changed.
6. Android device QA not possible here.

## 11. Completion checklist

| Region | Backdrop (own generation) | Foundation (own silhouette) | Slabs + platform | Areas | Loads in-game, no warnings | Column-0 shot | Warden shot | Distinct in the side-by-side |
|---|---|---|---|---|---|---|---|---|
| forest | ✅ (existing) | ✅ (existing) | ✅ | ✅ 3 | ✅ | ✅ 13 | — (control only) | ✅ |
| hellfire | ✅ | ✅ | ✅ | ✅ modulate | ✅ | ✅ 31 | ✅ 32 | ✅ |
| sands | ✅ | ✅ | ✅ | ✅ modulate | ✅ | ✅ 33 | ✅ 34 | ✅ |
| swamp | ✅ | ✅ | ✅ | ✅ modulate | ✅ | ✅ 35 | ✅ 36 | ✅ |
| dungeon | ✅ | ✅ | ✅ | ✅ modulate | ✅ | ✅ 37 | ✅ 38 | ✅ |
| ice_tower | ✅ | ✅ | ✅ | ✅ modulate | ✅ | ✅ 39 | ✅ 40 | ✅ |
| sky_isles | ✅ | ✅ | ✅ | ✅ modulate | ✅ | ✅ 41 | ✅ 42 | ✅ |

Regression: targeted art suites green (`art_assets`, `region_areas`, `backdrop_v2`, `floor_layer`, `support_layer`
all FAILS=0). Full suite: `full-suite-region-visuals-2026-11-12.txt` (result line appended below when it finishes).
Nothing committed, pushed or deployed.

**Full suite result (2026-11-12, `tools/qa/run_all_tests.sh`):** 287 suites, every line `FAILS=0 0 se`
(`full-suite-region-visuals-2026-11-12.txt`). No Godot process left running.

---

## 12. Arena integration — the arena as part of each region (2026-11-12, second task)

**Problem (user):** the backdrops differed, but the arena was one generic rectangular platform reused across the
regions, laid *over* the background. Evidence: `region-visuals/51-audit-ingame-v2.png` and the "before" column of
`arena-integration/23-before-after.png`.

### 12.1 Pipeline inspection — what is shared, what is per region

| Layer (draw order, art px 800×360) | Script | Shared geometry (unchanged) | Region-specific art BEFORE | Region-specific art AFTER |
|---|---|---|---|---|
| BackdropLayer | `src/battle/backdrop_layer.gd` | — | `backdrop.far`, `ground_shade`, `modulate` | same |
| SupportLayer (foundation under the front faces) | `src/battle/support_layer.gd` | `wall_spans` = under every front face, never over a cell | `support.wall_tile` (+pillar, swamp roots/ferns), colours | + **`support.foot_tile`** (ground contact strip, `foot_rise` / `foot_extend` / `foot_modulate`) |
| FloorLayer → SlabPainter (deck, front face, slabs, zones) | `src/battle/floor_layer.gd`, `src/art/slab_painter.gd` | `platform_deck_rects`, `platform_front_rects`, `cell_art_rect`, the 0.82 homography | 9-slice + stamps recoloured from the forest sheet, `platform` palette; **front face = SlabPainter's coded blocks** (forest only had `face_tile`) | + **`platform.face_tile`** per region (a course of its own foundation), + **`platform.rim_tile`** (`rim_rise`, `rim_modulate`), + **`platform.joints`** (`color`, `dark`, `chance`) |
| PickupLayer / UnitLayer / OverlayLayer | — | — | — | untouched |

**Gameplay geometry is untouched:** no change to `BoardGeometry`, `FloorPerspective`, `ScreenLayout`, `BoardGrid`,
`CombatView`, the cell rects, hitboxes, unit anchors or the camera. Every new element is drawn from the existing
`platform_front_rects` / `wall_spans` (outside the cells) or in the 1 px gap between neighbouring cells; the rim's
rise is clamped to `DECK_MARGIN - 1` so it can never reach a cell (`tests/unit/art/arena_dress_test.gd`).

### 12.2 New visual architecture (data-driven, `region.json`)

Four hooks, all outside the cells, all optional (a region without them draws exactly as before):

1. **Front face = the region's own foundation.** `platform.face_tile` = 12 rows cut from the region's wall strip
   (`make_region_env.py face_from_wall`, 0 gen), the way the forest's lip is cut from its PixelLab wall. Lip and
   wall are one material, so the platform reads as a solid block of the region's stone, not a board with a coded lip.
2. **Edge rim** (`SlabPainter.paint_rim_strip`, drawn in FloorLayer → warped with the floor): an alpha strip over
   the front faces rising ≤ 5 px into the deck margin — what the region leaves on the edge (bible §6.1 "phủ lên mép").
3. **Joints** (`SlabPainter.joint_segments` / `paint_joint_segments`): seeded 1 px dashed lines in the gaps between
   neighbouring real cells, never on an outer edge — what the region leaves in the cracks (bible §6.1 "phủ lên khe").
   1 px + dashed so they never compete with the red telegraph or the ivory outlines.
4. **Ground contact** (`SupportLayer._draw_foot_strip`): an alpha strip at every wall's foot, over the Ink foot
   shadow, extended `foot_extend` px past the span — how the region's ground meets the wall.

Lighting stays the bible's (upper-left light: light top row on the face, `wall_top_shade` contact shadow under the
coping, stepped Ink foot shadow, `backdrop.ground_shade` darkening the painted ground behind the foundation).

### 12.3 Per-region arena design (all scripted, 0 gen; strips 231 px wide, repeated on an absolute x grid)

| Region | Front face (from own wall) | Rim on the edge | Joints | Ground contact at the foot |
|---|---|---|---|---|
| Hỏa Ngục | basalt columns with veins | scorched patches, ash clumps, ember dots along the lip | **lava veins** `#FFB21F` dashed Ink, chance 0.3 (bible §6.3 exception) | ash heap, three ember cracks in the ground |
| Sa Mạc | buried sandstone course | **sand lapping over the edge from one side**, thinning lumps (bible "cát tràn từ một phía") | sand-filled `#C8B890`, chance 0.5 | sand piled against the wall, two half-buried blocks of the swallowed square, extends 12 px |
| Đầm Lầy | mud bank with a sunken log | weed clumps + strands draping over the lip, a wet line | weed `#4E5A3C`, chance 0.4 | **stagnant water** with ripples, pale reflections, two lily pads; extends 16 px |
| Hầm Ngục | dressed-stone course | stone dust + **two rusted chain lengths** lying on the lip (bible "xích gỉ ở lề") | dust, chance 0.12 (almost bare) | flagstone floor edge with Ink mortar + fallen rubble |
| Tháp Sương | frosted block course | **frost rime + icicles hanging over the face** | rime `#A6ACC4`, chance 0.45 | snow drift with a shadow line; extends 8 px |
| Không Đảo | wind-worn rock (the tapered underside's top) | chipped notches + pale dust, almost bare (bible "mòn gió") | none | **loose stones floating under the island** (`foot_rise` −6 leaves a gap) |
| Rừng Sương | *(unchanged, approved 2026-11-06: PixelLab wall course, roots, ferns, flagstones)* | — | — | — |

Shared on purpose: the deck / face / wall *geometry* (one platform rule for every arena shape, cross and u-shaped
included), the slab 9-slice + stamp sheet recoloured per region (bible §6.1 "phiến giống nhau ở mọi vùng"), the
thorn tile, the Ink shadow bands.

### 12.4 Workflow followed

1. Pipeline inspected (12.1). 2. Current seven captured = `region-visuals/31…41` + `13` (the "before" column of
`23-before-after.png`). 3. Architecture proposed (12.2). 4. Hỏa Ngục implemented first → `11-hellfire-c0-v1.png`
(found and fixed a mis-placed mist block in SupportLayer on the first run: parse error, then clean). 5. Verified
in-game. 6. The other five regions dressed with the same hooks and their own strips (12.3). 7. All seven captured.

### 12.5 QA (1280×720, windowed, `--audio-driver Dummy`, seed 27, Kiếm sĩ, column 0 of each region)

`production/qa/evidence/world-map-v2/arena-integration/`:

| File | What |
|---|---|
| `11…17-<region>-c0-v1.png` | full arena + background, one per region (forest = control, unchanged) |
| `20-all-seven-arenas.png` | the seven side by side (half size) |
| `21-edges-undersides-2x.png` | front edge, underside and foot of every region at 2× |
| `22-surfaces-2x.png` | surface + joints of every region at 2× |
| `23-before-after.png` | before (region-visuals v2) / after, per region |

Checks: no `SCRIPT ERROR`, no `ArtAssets` warning in any launch; red telegraph, ivory outlines, pickups, hazard
chips and the unit all drawn over the dressing (the rim never reaches a cell, joints are 1 px dashed); the Hellfire
lane board (holes, B1 lanes) still draws its walls under every lower edge. Side-by-side (edges sheet): seven
different lips, seven different edges, six different ground contacts; the arena foot now meets sand / water / ash /
snow / rubble / nothing (floating stones) instead of the same Ink bands on every ground.

Tests: new `tests/unit/art/arena_dress_test.gd` (joints only between neighbours, deterministic; rim top under every
cell bottom for any rise; six dressed regions resolve face / rim / foot from disk and SupportLayer loads the foot;
forest untouched). Related suites re-run green: slab_painter, art_assets, support_layer, floor_layer, region_areas.
Full suite: `full-suite-arena-integration-2026-11-12.txt` (result appended below).

### 12.6 What remains (needs the user)

- **Surface material is still the shared 9-slice recoloured** for the six regions (`22-surfaces-2x.png`): the
  forest alone has a generated flagstone sheet (`create_tiles_pro`, 15 gen). The same hook (`slab.flagstones` +
  `flagstone_meta`) is ready for the others: 6 × `create_tiles_pro` 64 px 4×4 sheets = **90 gen**, one prompt per
  region (obsidian cracked basalt / weathered sandstone with sand in the joints / sunken mud-stained stone / dressed
  dungeon flags / frosted cracked stone / wind-worn island rock). Not generated: paid, waits for the user's yes.
- Scripted strips are flat compared with PixelLab art; an optional paid pass could replace the six wall + face
  strips (`create_image_pro_flash` 231×44, ~9 gen each) one for one without touching code or `region.json`.
- Sanctum variants of the dressing are inherited from the base region (the `areas.art` merge); none needed per area.
- Map screen not capturable (`--shot` is battle-only); no Android device here.

Restrictions kept: no gameplay / balance / grid / collision / roster / encounter / save change, Hellfire B1
untouched, all prior uncommitted work preserved, nothing committed, pushed, deployed, reset, stashed or switched.

---

## 13. Arena surfaces — region-specific materials, hybrid implementation (2026-11-12, third task)

**Problem (user, after §12):** edges and undersides were now regional, but the six surfaces were still the forest
9-slice recoloured: a generic board on a regional platform, details only around the rim.

### 13.1 Audit — how a surface was composed

| Element | Before §13 | Shared / per region |
|---|---|---|
| Base surface | forest 16×16 9-slice + 18 stamps, recoloured per region (`make_region_env.py recolour`) — forest alone had a PixelLab flagstone sheet | one construction, seven palettes |
| Joints | 1 px seeded lines (§12) | per region |
| Environment on the surface | none (only the rim on the front faces) | — |
| Edge / underside | §12 strips | per region |

The engine already had the right hook: `slab.flagstones` + `flagstone_meta` (SlabPainter.paint_flagstone: one 64 px tile
per cell, picked by the cell's seed and weights, nine-cropped so the pixel density never changes). Only the forest fed it.

### 13.2 Surface material system (technology chosen per component)

| Component | Technology | Why |
|---|---|---|
| Gameplay grid rendering | unchanged (`cell_art_rect`, deck / face geometry, homography) | gameplay-critical, untouched |
| **Base surface material** | **procedural flagstone sheet per region**, Python, deterministic, cached as a 256×256 PNG (`tools/asset-pipeline/make_region_flagstones.py`), consumed by the existing flagstone hook | each region gets its own *construction* (masonry splits, ice layer, strata, plates…), not a palette swap; 0 gen; the tile anatomy was measured on the forest's PixelLab sheet (1 px Ink frame, 3 px light top/left, 2 px dark bottom/right) so the forest and the six sit in one family; ≤ 12 colours each, no dither, no outlines inside the face (bible §6.2) |
| **Region overlay — perimeter cover** | **GDScript, runtime, static** (`SlabPainter.perimeter_cover_rects` pure → `paint_perimeter_cover`), driven by `slab.perimeter` in `region.json` | depends on the board's shape (which sides of a cell face the ground), so it cannot be baked into a tile; drawn once per static redraw, one rect per column, ≤ depth px (≤ 8) on open sides only |
| Region overlay — joints | §12 (`platform.joints`) | — |
| Environmental effects | none animated (bible: static scenery; combat readability) | — |
| Edge / underside | §12 strips, face cut from the same wall | — |
| Shaders | none added (the existing perspective shader warps the whole flat floor, so every overlay follows the 0.82 homography for free) | no new per-pixel work on mobile |

PixelLab / generated assets used in this task: **none** (the forest's approved PixelLab flagstones and wall are kept
as they were). Everything new is deterministic script output or runtime GDScript; nothing regenerates per frame.

### 13.3 Per-region surface language (sheet construction + perimeter cover)

| Region | Flagstone construction (16 tiles, weights favour plain) | From the perimeter onto the cells |
|---|---|---|
| Hỏa Ngục | obsidian / basalt plates split by 2 px angular cracks (Ink + fold), scorched patches with an ash core, two tiles with a short molten crack (Ink + ember px), chipped corners | ash **drift** `#4A4446` ≤ 4 px, chance 0.45 |
| Sa Mạc | sandstone with faint strata, rounded eroded corners, sand drifted into the lower-right corner (one side), two worn square-in-square tiles, cracks, grains | sand **drift** ≤ 6 px from left / top / bottom only ("cát tràn từ một phía"), chance 0.8 |
| Đầm Lầy | damp stone with wide mud stains (not green), two puddle tiles (dark water + one light rim), moss only in a corner on three tiles, a root crossing two tiles, cracks | weed **clumps** on the edge, chance 0.6 |
| Hầm Ngục | heavy masonry: tiles split into 1×2 / 2×1 / 2×2 / off-centre dressed blocks with Ink joints and their own light / dark edges, cracks, chipped corners, rust dust | stone-dust **drift** ≤ 3 px, chance 0.3 |
| Tháp Sương | an ice sheet over the stone (inset 5 px) cracked with pale lines, frost band with teeth on four tiles, flat snow with a shadow in a corner on three, reflection streaks, one Ink crack through the ice | frost **rime** line with teeth on open edges, chance 0.7 |
| Không Đảo | wind-worn rock: broken horizontal erosion streaks, pits with a light lower rim, chipped edges, a faint exposed-Lattice line on two tiles (1 px, one step, no glow, bible §6.5), cracks | dust **drift** ≤ 2 px, chance 0.25 (almost bare) |
| Rừng Sương | *(approved PixelLab sheet, unchanged)* | **roots** 3 px bark strokes reaching ≤ 8 px onto edge cells, chance 0.35 |

### 13.4 Workflow followed

Audit (13.1) → system (13.2) → Hỏa Ngục first (`31-hellfire-c0-v2.png`, 3× crop checked: plates, veins, ash drift,
molten crack, boundaries intact) → six sheets generated, previewed at 3× (`scratchpad`), refined once (hellfire ash
patches were reading as holes; ice snow was a bright disc and frost a speckle row; sand corner was a wedge; swamp moss
too small) → five regions + forest roots → all seven captured → side by side (13.5).

### 13.5 QA (1280×720, windowed, `--audio-driver Dummy`, seed 27, Kiếm sĩ)

`production/qa/evidence/world-map-v2/arena-integration/`:

| File | What |
|---|---|
| `31…37-<region>-c0-v2.png` | full arena + background, all seven (column 0) |
| `38-hellfire-warden-v2.png` | Hỏa Ngục warden hall (B1 lane board, sanctum modulate) |
| `420-all-seven-arenas.png` | the seven side by side |
| `421-edges-undersides-2x.png` | surface-to-edge transitions at 2× |
| `422-surfaces-2x.png` | surface close-ups at 2× |
| `423-before-after.png` | §12 state (left) vs §13 (right), per region |
| `*20…23*.png` (no prefix) | the §12 sheets, kept |

Checked in the running game (not only the exports): no `SCRIPT ERROR` / `ArtAssets` warning in any of the 9 launches;
cell boundaries (Ink frame + light fold) visible on every tile of every region; red telegraph, ivory outlines, hazard
chips (`48` / `55` / `56` / `95`), pickups and the unit all above the surface; nothing animated; no bright effect on
cells (hellfire embers are ≤ 2 px per tile, two tiles of sixteen); the hellfire lane board with holes draws ash
drift on the hole-facing sides as intended (open sides). Texture artifacts: none seen at 2× / 3× (nine-crop keeps the
6 px border, the ice inset reads as the ice layer's edge). Contrast: faces stay within the region ramps (V ≤ 55);
snow / frost / sand crests are the only pixels above, all ≤ 1–2 px.

**Performance:** no per-frame work added. The floor is static (redraw on setup / resize / zone change only). Per
redraw: flagstones = 9 texture-region draws per cell (as the forest already did); perimeter cover = one rect per
column of an open side (~40–60 per open side, ≤ 2 open sides on most perimeter cells) + a few 1 px crest / speck rects;
joints = 1 px rects. All inside one CanvasItem → batched by the 2D renderer. Six 256×256 RGBA sheets added (1.5 MB
raw, PNG 2–4 KB each). No new shader, no new viewport. Measured on desktop only (no device here).

Tests: `tests/unit/art/arena_dress_test.gd` extended — six different 256×256 sheets with 16 weights each, perimeter
kinds known and depth ≤ 8, forest keeps its PixelLab sheet and gains roots, `perimeter_cover_rects` pure: nothing on
a closed cell, every rect inside the cell for all four kinds, deterministic. Related suites green. Full suite before
the surface work: `full-suite-arena-integration-2026-11-12.txt` (288 suites, all FAILS=0); after:
`full-suite-arena-surfaces-2026-11-12.txt` (result line below).

### 13.6 Modified / added files (this task)

- `tools/asset-pipeline/make_region_flagstones.py` (new) — the six sheets; `make_region_env.py` — `DRESS` gains
  `weights` + `perimeter`, `region_json` emits `slab.flagstones` / `flagstone_meta` / `perimeter`.
- `assets/art/env/<6 regions>/env_slab_<r>_flagstones.png` (new) + `region.json` regenerated;
  `assets/art/env/forest/region.json` — `slab.perimeter` (roots) only.
- `src/art/slab_painter.gd` — `paint_perimeter_cover`, `perimeter_cover_rects`, `_blob_rects`;
  `src/battle/floor_layer.gd` — reads `slab.perimeter`, computes open sides from the grid, draws after the slab.
- `tests/unit/art/arena_dress_test.gd` — extended. Asset registry +6, manifest regenerated.

### 13.7 Remaining limitations

- Procedural sheets are deliberately flat pixel-art (bible §6.2); a PixelLab `create_tiles_pro` pass per region
  (15 gen each) could replace any sheet one for one through the same hook if the user wants painterly detail.
- Perimeter cover is per cell edge; it does not yet continue across two neighbouring edge cells as one long mound
  (each cell seeds its own). Acceptable at 1280×720; could be made board-continuous later.
- No animated environment (by design); no Android device; map screen not capturable.

Restrictions kept: gameplay, balance, grid geometry, collision, rosters, encounters, saves, Hellfire B1 untouched;
all earlier uncommitted work preserved; nothing committed, pushed, deployed, reset, stashed or switched.

**Full suite result (2026-11-12 → 13, after the surface work, `tools/qa/run_all_tests.sh`):** 288 suites, every line `FAILS=0 0 se` (`full-suite-arena-surfaces-2026-11-12.txt`). No Godot process left running.
