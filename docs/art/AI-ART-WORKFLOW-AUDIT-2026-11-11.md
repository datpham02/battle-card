# AI Game Art Workflow Audit — Ấn Kiếm / Tessera (Godot 4.6)

Read-only audit, 2026-11-11. Nothing was created, modified, generated or installed during the audit (this file is the only output, written on the user's request afterwards). All paths are relative to the repo root. **Verified** = read from disk or git. **Unknown** = not determinable without running the game or asking the user.

---

## 1. Project Overview

| Item | Verified value |
|---|---|
| Game | *Ấn Kiếm* (world: Tessera), mobile landscape real-time grid card battler, Vietnamese first |
| Engine | Godot 4.6, installed 4.6.3, GDScript, Mobile renderer, 1280×720 canvas_items/expand |
| Framework | claude-code-game-studios **v1.1.3** (tag present; `project.yaml` `framework.version: 1.1.3`), `modes.rigor: minimal`, `automation: guided`, review mode solo |
| Git | 210 commits on `main`; remote `origin` = your repo, `template` = upstream CCGS. **45 modified tracked files + ~1,579 untracked** (1,210 are `.import`, 117 PNG, 72 WAV, 42 video). A stale worktree sits at `.claude/worktrees/vigilant-chebyshev-4d039b/` |
| Art state | 16 animated units (5 heroes, 11 Misty Forest enemies) exported and running in game; 42 VFX packs; 1 region's environment; UI plates/icons/map/climb art; 13 of 50 card arts |
| Session state | `production/session-state/active.md` (168 lines, current to 2026-11-09 Cursor handoff) is the de facto memory of approvals and PixelLab spend |

---

## 2. Existing Project Structure

```
project.godot / project.yaml / CLAUDE.md
.claude/            agents(49) skills(85 dirs) hooks(14) rules(13) scripts(10) docs(105) agent-memory/
src/                game code; art layer in src/art/*.gd + src/battle/*_layer.gd
assets/art/         ENGINE ART (170 PNG, 66 JSON, 170 .import): units/ env/forest/ vfx/{cast,floor,status}/ ui/{cards,climb,map,plates,title}/ cards/
art_src/            .gdignore'd SOURCES: units/<id>/<clip>/<n>.png + clips.json (727 PNG), palette/tessera_master.gpl
design/art/         art-bible.md (vi, 9 §), pixellab-profile.md, reference/ (32 concepts), animation-sheets/ (1), 4 dated plan/spec docs
design/assets/      asset-manifest.md (STALE 2026-10-31), entity-inventory.md, specs/ (16), candidates/ (.gdignore'd, ~3,300 PNG)
docs/art/           PIXEL_ART_WORKFLOW.md, ASSET_SPECIFICATION.md, ART_QA_CHECKLIST.md, vfx-scale-impact-guide.md
docs/skill-v2/      26 reports incl. 16-animation-audit-and-plan.md, HANDOFF-2026-11-09.md
tools/asset-pipeline/  export_sheets.py (stdlib), make_map_icons.py, make_ui_plates.py
tools/fx-pipeline/     fxc.py + fxkit (procedural square VFX, .gdignore'd)
tools/qa/              sprite_measure/clean/recolour .gd, contact sheets, play_bot, run_all_tests.sh
tools/art/             build_cast_hand.py (untracked)
prototypes/art-check/  in-engine look check (modes blackout/rows/seq/ui)
production/qa/evidence/  119 folders of screenshots/GIF/AVI — NOT .gdignore'd (see §6)
tests/                 260 custom SceneTree suites, 17 in unit/art/
CCGS Skill Testing Framework/   specs for the framework's own skills
TESSERA_CLAUDE_DESIGN_PACK/     design pack (md + json), no art
```

No `.claude/commands/` (skills are the slash commands), no `.mcp.json`, no `export_presets.cfg`, no `.github/workflows/`, no `addons/` (the gdUnit4 command in `project.yaml` is dead).

---

## 3. claude-code-game-studios Audit

Framework drift vs tag `v1.1.3`: 21 files changed, almost all the added `pixellab-animation-engineer` skill. No upstream agent, skill, hook, rule or template has been customised for art.

| Component | Existing | Purpose | Relevant to Game Art | Reusable / Extend / Missing |
|---|---|---|---|---|
| `art-director` agent | Y | Visual identity, art bible, specs, AD gates. No Bash, no MCP, `memory: project` | Y | **Extend**: memory dir empty; cannot measure or generate; nominal sign-off authority that has never signed |
| `technical-artist` agent | Y | Pipeline, VFX, import, atlasing | Y | **Extend**: knows nothing of `tools/asset-pipeline`, `art_src`, fxkit |
| `creative-director`, `narrative-director`, `ux-designer`, `ui-programmer`, `qa-lead/tester`, `godot-*` | Y | Vision, story character design, UX, UI code, QA, engine | partial | Reusable as is |
| `/art-bible` | Y | Writes/retrofits `design/art/art-bible.md` | Y | Reusable (bible exists; retrofit mode) |
| `/asset-spec` | Y | Entity inventory, per-target specs with generic prompts, manifest rows | Y | **Extend**: unaware of candidates/, art_src/, exporter, PixelLab params; its manifest format is what went stale |
| `/asset-audit` | Y | Naming/size/format audit of `assets/` | Y | **Extend**: power-of-two rule is wrong for sheets; no palette/JSON/manifest checks |
| `/pixellab-animation-engineer` | Y (project-authored, 14 files) | Design sheet → prompt pack → gated paid run → `anim_qa.py` → hand-off | Y | **Extend**: animation only; profile covers 2 of 16 units; used once (2026-11-01); no `model:`; never skill-tested |
| `/dev-story`, `/story-done`, `/test-evidence-review` | Y | Visual/UI stories need retained screenshots (BLOCKING) | partial | Reusable |
| `/team-ui`, `/team-polish`, `/team-level` | Y | Orchestrations incl. art-director | partial | Reusable; no `team-art` |
| `/quick-design`, `/ux-design`, `/ux-review` | Y | Specs | partial | Reusable |
| Hook `validate-assets.sh` | Y | Lowercase names under `assets/`; JSON validity under `assets/**/data/` | partial | **Extend**: not art-aware; fires only on Write/Edit, never on PNGs from Bash/MCP |
| Hook `validate-commit.sh` | Y | JSON block, advisory GDD/TODO checks | partial | **Extend**: natural place to run `export_sheets.py --check` |
| `hooks-reference/post-merge-asset-validation.md` | doc only | Naming/size/format after merge | Y | **Missing** (never implemented) |
| Rules (13) | Y | Path-scoped standards | partial (`data-files`, `shader-code`, `ui-code`) | **Missing**: no rule for `assets/art/**`, `art_src/**`, `design/assets/**` |
| Templates (40) | Y | `art-bible.md`, `narrative-character-sheet.md`, `test-evidence.md` | partial | **Missing**: asset spec, manifest, generation log, character reference templates |
| Scripts (`.claude/scripts/`) | Y (10) | Workflow/doc checks | N | Art checks live in `tools/` instead (fine) |
| Director gates | Y (4 AD-*) | AD-ART-BIBLE, AD-CONCEPT-VISUAL, AD-PHASE-GATE, AD-VISUAL | Y | **Extend**: AD-VISUAL ("new asset types") is defined but no skill calls it |
| Agent memory | dirs only | Persistent agent notes | Y | `art-director/` **empty**; the 17 art rules live in the user's memory instead |
| `automation-modes` `external_calls` always-ask | Y | Ask before AI asset generation | Y | Reusable (matches the per-gen rule) |
| Tests | Y (260 suites) | 17 `unit/art` suites: sheet export, loader, VfxPack, FX | Y | Reusable; `sheet_export_test` covers 8 of 16 units |
| CI | N | — | — | **Missing**; `/test-setup` can scaffold it |
| Skill Testing Framework | Y | Static/spec/rubric tests of skills | partial | Reusable: pixellab spec exists, `last_*` results empty |

Existing components that already cover each responsibility: game design (`/design-system`, `/quick-design`, game-designer), art direction (art-director, `/art-bible`), character design (narrative-director + `/asset-spec character:`), asset generation (`/pixellab-animation-engineer` + PixelLab MCP), animation (same skill + `export_sheets.py`), visual review (`ART_QA_CHECKLIST.md`, `prototypes/art-check`, contact sheets), QA (`/asset-audit`, `/test-evidence-review`, `unit/art` tests), Godot integration (`src/art/*.gd`, `ArtAssets`, index JSONs).

---

## 4. Existing Agents and Skills (detail)

**Agents.** `art-director.md` is told to NOT create pixel art and NOT change pipeline tooling; it writes specs and the bible. `technical-artist.md` owns import settings, format conversion and atlasing. No agent file mentions PixelLab, sprite sheets, Aseprite or AI generation (grep over all 49). `creative-director` line 306 delegates asset approval to art-director. Only `game-designer/` has memory content.

**Skills.** `/asset-spec` phase 3 spawns art-director + technical-artist in parallel (full), writes `design/assets/specs/[target]-assets.md` with a Generation Prompt per block and updates `asset-manifest.md`. `/asset-audit` is read-only (Bash limited to `stat|file|od|wc|du`). `/pixellab-animation-engineer` phases: 0 profile → 1 brief → 2 design sheet → 3 prompt pack → 4 cost quote + AskUserQuestion gate (pilot first) → 5 run/download to `candidates/<char>/<clip>-<date>/raw/` → 6 QA (`anim_qa.py`, contact sheet, ≤3 retakes) → 7 hand-off with "May I write". Paid tools are deliberately excluded from `allowed-tools` so the harness also asks. It says "New character with no profile entry: create the anchor first, then come back" — anchor creation has no skill.

**Hooks wired (12):** SessionStart (`session-start`, `detect-gaps` — no art checks), PreToolUse (`validate-commit`, `validate-push`), PostToolUse Write|Edit (`validate-assets`, `validate-skill-change`), Notification, Pre/PostCompact, Stop, SubagentStart/Stop. `log-instructions.sh` is not wired.

**Workflow catalog:** `art-bible` is required only on the full ladder; pre-production lists `entity-inventory` and `asset-spec` as optional; there is no step for asset production or animation.

---

## 5. Game Asset Inventory

Status legend: **approved** = a document quotes the user approving that result; **in_progress** = exists/installed, no result sign-off or open points; **legacy** = superseded/parked; **missing** = required by a spec, no file; **unknown** = no evidence.

### 5.1 Characters and character animations (`assets/art/units/`, all RGBA, all `.import` present, exported from `art_src` — clip sets match 16/16)

| Unit | Frame | Facing | Clips (frames) | Anchor | Clip status |
|---|---|---|---|---|---|
| kiem_si (Knight) | 96×92, body_h 70 (sources mixed 96×70 + 96×92, bottom-aligned by exporter) | right | idle 8, draw 8, step 4, step_forward/back/up/down 7, cast_gesture 9, cast_forward 9, cast_summon 9, cast_hand 9, hit 3, victory 5, defeat 8, fall 4, awaken 6 | **approved** (v3, 2026-10-31, PixelLab char `2d093318`) | cast_forward **approved** (skill-checklist), cast_summon **approved** (2026-11-08), cast_hand **approved** (2026-11-10, commit 03b71a4); idle v2, draw, steps, hit, cast_gesture v4, victory, defeat, fall, awaken **in_progress**; cast_overhead v1 **legacy**; v1 40×48 / v1-cloudlike / pre-40x48 **legacy** |
| phap_su (Mage) | 96×70 | right | 12 clips (no step_up, no cast_hand by design) | in_progress (gens approved per call, no anchor-result quote) | all **in_progress** |
| sat_thu (Assassin) | 96×70 | right | 12 clips (no step_back/up) | **approved** ("Duyệt cả ba", 2026-11-05) | cast_gesture X-slash **in_progress**; others **in_progress**; `cast_hand` **in_progress, hand-painted, untracked** |
| tho_san (Hunter) | 96×72 | right | 13 clips (step_back 5 fr) | **approved** (2026-11-05) | all **in_progress**; `cast_hand` **hand-painted, untracked** |
| giao_si (Cleric) | 96×72 | right | 13 clips | **approved** ("Duyệt bản này", no lilac accent — open deviation) | all **in_progress**; `cast_hand` **hand-painted, untracked** |
| goblin_scout | 64×52 | left | idle 4, step 4, windup 2, hit 3, down 8 | approved v3 2026-10-31 | **in_progress** (manifest: "Done, awaiting sign-off"); v1 32×48 **legacy** |
| rootling, greycap_sporeling, mossbound_sentry (+brace) | 64×52 | left | 5–6 clips | approved 2026-11-02 ("Duyệt cả 4") | **in_progress** |
| goblin_archer, dire_wolf (68×52) | 64/68×52 | left | 5 clips | approved 2026-11-03 | **in_progress** |
| ancient_root_sentinel (+stunned), mistbriar_matron (+guard) | 80×80 | left | 6 clips | approved v2 2026-11-02 | **in_progress**; v1 64×64 **legacy** |
| wolf_alpha (+howl) | 80×80 | left | 6 clips | approved 2026-11-04 | **in_progress** |
| goblin_warlock (+windup_heavy, phase_shift) | 160×130 | left | 7 clips | approved 2026-11-04 | **in_progress** |
| forest_witch | 160×130 (largest sheet 1287×1309) | left | 10 clips (no plain `step`) | approved wide anchor 2026-11-02 | **approved** (active.md: "10 clips (approved, 10 gen)"); narrow v1 128×125 **legacy** |

Required but absent: **hero portraits ×5** (ASSET-002, `assets/art/portraits/` does not exist) → **missing**. Monster `strike` and hero `down` clips are in `entity-inventory.md` but not in art bible §8.6 → **unknown** whether still required.

### 5.2 Enemies for other regions
`assets/data/chapters.json` references roughly 80 enemy ids across 8 regions; only the 11 Misty Forest bodies exist. Entity inventory rows 22–78 (≈67 bodies + 7 wardens) → **missing**. `regions.json` maps 8 regions, `islands.json` covers 7 (no `an_dai`).

### 5.3 VFX (`assets/art/vfx/`, 42 packs, `VfxPack` manifest format)

| Group | Packs | Status |
|---|---|---|
| Status overlays | burn/frozen/chill × hero/goblin (PixelLab VFX Creator, 2026-10-31) | **approved look**, sign-off pending; only `hero`/`goblin` body sizes exist (see §6) |
| Floor F1–F10 | burning_cell … root_seal (vfx_workbench, free) | **in_progress** ("PASS, chờ ký" 2026-10-31) |
| cell_slash, big_burst | Pro Flash + animate_image | **approved** 2026-11-01 |
| small_burst | "TEMP: big burst halved" | **in_progress** placeholder |
| Steel fxc packs (travel/release/impact/mark ×2 cell sizes) | `tools/fx-pipeline`, 0 gen | **approved look**, installed 2026-11-02 |
| Burn fxc packs (charge/travel/impact/mark + `_c43x31`) | fxc | **in_progress** (prototype accepted, no install approval line) |
| impact/mark_eruption_tram_dia | vfx_workbench | **approved** 2026-11-08 |
| sword_wave, hand_charge | PixelLab Creator | **in_progress**, Knight moved off sword_wave; still default for 3 heroes |
| fx_telegraph_stripe_8 | script | **in_progress** |
| 8 `_c43x31` duplicate packs | fxc | **unknown** (which is drawn depends on cell size at runtime) |

Impact art exists only for burn; freeze/slash/shatter/knockback/thorns/poison/guard/seal/curse are code-drawn (`ImpactFx` forms, 27 cards) → per `16-animation-audit`: 33 cards PARTIAL, 24 unbuilt.

### 5.4 Environment / backgrounds (`assets/art/env/forest/`, 19 PNG)
`bg_forest_far_v4` **in_progress** (in use); `bg_forest_far` v1/v2/v3 **legacy** (kept in shipping tree, unreferenced); `_edge`/`_sanctum` **in_progress**; `bg_forest_near` unused (`near_enabled: false`); slab 9-slice + 18 stamps **approved** dark v4 (sign-off pending); flagstones 256×256 (PixelLab tiles_pro) **in_progress**; `env_support_forest_wall` **approved**; pillar/arch/roots/ferns **in_progress** (plan doc says "còn chờ duyệt"); thorn tile v2 in use, v1 **legacy**. Other 7 regions' slabs/backdrops → **missing ×14** (flat fallback bands drawn).

### 5.5 UI, icons, cards, map
`ui_icons_55` (16 icons, 223×223) **in_progress** (direction decision pending); `ui/cards` frames, `ui/title` (menu_bg 640×360, button, hero_back 84×84), `ui/map` (18 code-drawn), `ui/plates` (11 code-drawn) → **unknown** (in game since 2026-11-01/03, evidence folders exist, no approval line found). `ui/climb`: 7 islands 320×192, sky_far, 4 clouds, summit **in_progress** (prototype awaiting approval); 7 `stair_*` PNGs **untracked**; Lattice Heart island **missing**. Cards: 13 × 32×32; `hoa_xa` approved style, 12 **in_progress**, **37 cards without art**: bang_phong, bang_tam, bang_vo, chuoi_set, cuong_phong, dap_vo, dia_chan, do_kiem, gai_doc, gai_nguyen, ganh_nang, han_bang, han_kiem, han_phong, han_tran, hoa_bang, hoa_loi, hoi_am, kiem_than, lien_tram, liet_hoa, loc_cuon, min_tre, ngan_kiem, oan_hon, ran_van, song_dao, song_kiem, thanh_thuy, thien_hoa, thien_lang, thien_thach, thuong_xuyen, tram_dia, tran_gai, tu_kiem, vung_lay.

### 5.6 Other
Fonts: NotoSans Bold/SemiBold, Handjet, VT323 (OFL). Audio: 81 WAV, 70 procedural (CC0-equivalent), ElevenLabs takes marked UNCONFIRMED licence. i18n: `strings.csv` 1,050 lines. Data: 19 JSON + `schema.md`; `characters.json` has **no sprite/portrait fields** (sheet by id convention).

### 5.7 Candidates (`design/assets/candidates/`, `.gdignore`'d)
Per-unit folders hold raw rotations, `anim/`, `clean-<WxH>/`, strips and in-game mocks; versions coexist as `v1-cloudlike/`, `pre-40x48/`, `v3-tall/`, `rot02/`, `clean-64x64/` vs `clean-80x80/`, `cast-hand-v1..v3`, `k2-edit`, `k2-mitten` (5 `QA.md`, 4 `metadata.json`). `fx-pipeline/` holds uninstalled Witch packs (`gather_flame_charcoal`, `root_crawl_*`). `slice1-fx/`, `slice1-ui/` are the legacy script-drawn pixel-HUD set. `climb-map/` 161 PNG current WIP.

---

## 6. Pixel Art and Animation Technical Audit

**What is right (verified in code and asserted by tests):** SubViewport 800×360, `canvas_item_default_texture_filter = NEAREST`, MSAA/HDR off, both pixel-snap flags on the SubViewport only, integer scale `max(1, floor(min(W/640, H/360)))`, Ink fill, HUD at native res (`src/battle/battle_canvas.gd:64-75`, `tests/unit/battle/battle_canvas_test.gd:84-98`). Playback is `draw_texture_rect_region` from the Aseprite-style JSON with per-frame ms (`src/art/sprite_sheet.gd`, `unit_animator.gd`); no AnimatedSprite2D anywhere in `src/`. Anchor is bottom-centre at the feet for any frame size (`unit_layer.gd:628-635`); flip by negative width. All 170 art imports are Lossless / mipmaps off / fix_alpha_border on / premult off (100 %). All 897 PNGs in `assets/art` + `art_src` are RGBA 8-bit; every unit's source frames share one canvas (Knight's mixed canvas is documented and intentional).

**Problems and risks (evidence):**

| # | Finding | Evidence | Impact |
|---|---|---|---|
| 1 | **Spec docs contradict shipped frame sizes.** Spec: hero 40×48 (bible 32×48), monster 32×48, warden 48×64. Reality: heroes 96×70/72/92, monsters 64×52 (dire_wolf 68×52), elites 80×80, bosses 160×130 | `docs/art/ASSET_SPECIFICATION.md:23-25`, `art-bible.md:803-825`, sheet `meta.tessera.frame` | Any agent reading the spec generates the wrong canvas |
| 2 | **Palette path wrong in spec**: `assets/art/palette/` does not exist; real file `art_src/palette/tessera_master.gpl` (47 colours, grown from 16) | `ASSET_SPECIFICATION.md:43,62` vs `export_sheets.py:316` | Same |
| 3 | **Evidence screenshots are imported by Godot**: 1,467 `.ctex`, 70 MB of 94 MB `.godot/imported`, 1,210 untracked `.import`, 144 tracked ones churning | no `.gdignore` in `production/`; `.gitignore:69` keeps `*.import` tracked | Slow imports, noisy git, CRLF diffs |
| 4 | `detect_3d/compress_to` inconsistent: 8 sheets `0`, other 162 files `1`; test pins only the 8 | `tests/unit/art/sheet_export_test.gd:17-129,326` | Harmless now; 8 units unchecked by the export test |
| 5 | **Status overlays exist only for `hero` and `goblin` sizes**; the goblin burn/chill/frozen pack is drawn on 80×80 elites and 160×130 bosses | `unit_layer.gd:668-670`, `status/index.json` | Boss effects undersized (unknown whether accepted) |
| 6 | VFX authored for only two cell sizes (64×46, 43×31) while cells range 38×27…64×46; `FloorVfx.variant_for` picks nearest, never scales; non-fill bursts can overflow small cells | `floor_vfx.gd:157-215`, `screen_layout.gd:55-56` | Visual overflow on small boards |
| 7 | Non-integer icon scaling on the HUD: `CHIP_ICON_SCALE = 0.5`, `status_row.gd:150` float ratio; map backdrop float-stretched | `cut_hud_view.gd:147,2271`, `chapter_map_view.gd:567-572` | Dropped pixels (nearest), uneven icon look |
| 8 | Project default texture filter is Linear (`[textures]` unset); battle HUD views rely on per-texture `PixelFrame.nearest`; `card_face.gd:307,784` draw art without it | `pixel_frame.gd:54` | Any new raw `draw_texture` in the battle HUD is bilinear |
| 9 | PixelLab-Creator manifests reference sheets never shipped (`whole-with-sprite.png`, `part-*.png`, `behind.png`); some `frames` counts exceed the shipped clip | 18 manifests | Harmless to code (reads indexed clip only); manifests not self-consistent |
| 10 | Naming diverges from `[group]_[id]_[variant]_[size]`: cards bare `<id>.png`, `ui/*` without group prefix, backdrops with `_v2/_v3/_v4` kept beside the live one | `assets/art/**` | `/asset-audit` would flag most UI files |
| 11 | Clip-set asymmetry: only Knight has `step_up`, `cast_forward`, `cast_summon`; Assassin lacks `step_back`; Hunter `step_back` 5 frames; idle timing 125/250/300 ms vs bible's 400 ms | sheet JSONs vs `art-bible.md §8.6` | Code tolerates it (clip priority fallbacks); no canonical clip list |
| 12 | Three hand-painted `cast_hand` clips (sat_thu, tho_san, giao_si) sit uncommitted; they contradict the "no hand-painted details" rule and have no approval record | `art_src/units/*/clips.json` "Painted from idle/0"; `git status` | Decision needed (§13) |
| 13 | Stale docs in tools: `asset-pipeline/README.md` sheet table lists 2 units; `unit_layer.gd:12` says 96×70; bible §8.7 memory table assumes 384×48 rows and atlases that are never built; `project.yaml` names gdUnit4 with no addon | — | Misleads new sessions |
| 14 | No export preset, no Android build ever run; `production/qa/android-device-qa-skill-v2.md` is PENDING; ETC2/ASTC question in bible §8.7 unresolved | `export_presets.cfg` absent | Mobile VRAM/texture compression unverified |

Pivots/origins: handled in code (feet row = last pixel row, exporter enforces 1 px margins except bottom); no pivot data in JSON. Transparency: alpha 0/255 enforced by `export_sheets.py` and `fxc check`; installed pre-fxkit PixelLab packs are known to fail `fxc check` (off-palette) and are tolerated.

---

## 7. Existing AI Tools and Integrations

| Tool | Where configured | Status |
|---|---|---|
| **PixelLab MCP** (`https://api.pixellab.ai/mcp`, HTTP + auth header) | `~/.claude.json` → `projects["C:/WorkSpace/my-game"]` (project scope; not available in the worktree) | **Configured & used**: hundreds of logged jobs; balance trail 3,166 → 2,167.9 (2026-10-31 → 11-08) |
| ElevenLabs MCP | same project entry, needs OAuth | Configured, art-irrelevant, audio frozen |
| REA MCP (`npx rea-agents@6.7.0`) | user scope | Configured, not used for art |
| Plugin `pixelfx` 0.3.0 | user plugins | Installed; **used only as reference** (`docs/research/pixelfx-study.md`, picks rendered once); `tools/fx-pipeline` is a stdlib Python re-implementation, no code copied |
| Plugin `gamedev` (`create-game-assets`) | user plugins | Installed; **never referenced in the repo**; its scripts need Pillow (absent); bundles no generator |
| Plugin `context-engineering` | user plugins | Installed, not art |
| `ugw-marketplace` | known marketplace only | Not installed, never referenced |
| Aseprite / LibreSprite / ImageMagick / Pillow / numpy | — | **Not installed** (docs say so); all image scripts are stdlib PNG parsers |
| ffmpeg, node 22 | PATH | Present (audio / pixelfx CLI), not used by the art pipeline |
| Godot 4.6.3 headless | PATH | Used by `tools/qa/*.gd` for measure/clean/recolour/contact sheets |

Free PixelLab tools actually used: `pixelart_workbench` (lint/score/map_colors/patch_pixels, Oct 31 only), `vfx_workbench` (status packs, floor packs, Trảm Địa eruption). Paid tools used: `create_character_pro_flash`, `create_image_pro_flash`, `create_image_pro`, `create_image_pixen`, `edit_image_pro_flash`, `inpaint_image_pro_flash`, `animate_character` (pixminimax), `animate_image_pixminimax`, `create_tiles_pro`. `reduce_colors` is listed in docs but never logged.

---

## 8. Current Asset Workflow (as practised, reconstructed from specs and active.md)

A formal workflow document exists (`docs/art/PIXEL_ART_WORKFLOW.md`, 2026-10-31) and the practice mostly follows it, but it is driven from the main chat session, not from skills.

**(a) New character body.** Design row in `design/assets/specs/<unit>-assets.md` with locked ≤8-colour palette and a likeness check → pre-gen checklist (prop visible, accent on big parts, face, contrast; user rule 2026-11-05) → cost shown, explicit yes → `create_character_pro_flash` (view low top-down, SE for heroes / SW for enemies, `style_image` = approved Goblin v3 or Knight v3 rotation with colour transfer off, palette lock, `max_colors 8`, seed 1/5, `no_background`) → rotations to `candidates/<unit>/rot/` → in-game paste mock in `production/qa/evidence/` → the user's Vietnamese yes quoted verbatim in the spec row → mechanical cleanup only (`sprite_clean.gd` palette snap, speck removal, re-plant; `sprite_recolour_region.gd`) → `art_src/units/<id>/idle/0.png`; PixelLab character id stored in the spec row and `clips.json` `source`.

**(b) Animation clip.** Positive-only motion prompt → one pilot clip, then batches → `animate_character` pixminimax on the stored character, or `animate_image_pixminimax` from the local anchor PNG once frames were edited locally (8 frames, seed 1, 1 gen) → raw to `candidates/<unit>/anim/<clip>/` → frame selection by `sprite_measure.gd` + eye (baked red/yellow bursts dropped) → `sprite_clean.gd` → copy to `art_src/units/<id>/<clip>/`, edit `clips.json` (ms, loop, body_h, source) → `python -X utf8 -I tools/asset-pipeline/export_sheets.py --units <id>` (refuses off-palette, bad alpha, edge touches, >8 colours) → tests `sheet_export_test`, `sprite_sheet_test`, `roster_sprite_test` → in-game observe (`--demo`, Movie Maker AVI kept local) → evidence folder → approval written in the spec row or skill-v2 report. The `/pixellab-animation-engineer` skill ran this path **once** (cast_gesture v4, 2026-11-01); every later clip bypassed its design-sheet and `anim_qa.py` phases.

**(c) VFX.** Three sources into one `VfxPack` manifest format: PixelLab `vfx_workbench` (free) game-pack zips → extracted into `candidates/` → copied to `assets/art/vfx/<kind>/<pack>/` + `index.json` entry; `tools/fx-pipeline` recipe → `fxc build/check` → `candidates/fx-pipeline/<pack>/` + evidence contact/gif/strip → the user's "Đạt, làm tiếp" → manual install; code-drawn FX (`ImpactFx`, `FuseFx`, `SkyDropFx`) with no asset at all.

**(d) UI / icons / plates.** Deterministic scripts (`make_ui_plates.py`, `make_map_icons.py`), 0 gen; icons via Pixen (2 gen); card art 13 × Pro Flash 32×32; climb map via `create_image_pro` per the 2026-11-07 spec (partially executed, exact spend not logged in a spec).

**(e) Environment.** Slab 9-slice by script with stamps harvested from a 5-gen Pro Flash test; backdrop v4 from `create_image_pro` 792×336 (25 gen) + composite scripts; support kit via Pro Flash (pillar 5 gen accepted, coping 9 gen rejected); flagstones via `create_tiles_pro`. Logged only in `design/art/*-plan-*.md`, not in `design/assets/specs/` or the manifest.

**Approval.** Always the user (solo mode); the art-director agent is named as sign-off authority in the manifest but has never signed. **Spend tracking:** per-row Cost column in specs, balance lines in `active.md` (gitignored), no ledger. **Character consistency** relies on: `style_image` with colour off, palette lock + `max_colors 8`, stored character id or local anchor as first/last frame, post-gen palette snap, mechanical-only edits. There is **no master-reference document per character**: `pixellab-profile.md` covers 2 of 16 units; ids are scattered across ≥25 files, often truncated to 8 characters, and superseded characters are never marked retired.

---

## 9. Workflow Gaps

| Capability | Existing | Partial | Missing | Evidence |
|---|---|---|---|---|
| Art Bible / Visual Style Guide | ✔ | | | `design/art/art-bible.md` 9 sections, user-approved per section; §8 numbers stale |
| Character Master Reference | | ✔ | | `pixellab-profile.md` 2/16 units; `clips.json` `source` strings; no doc per character with id, anchor, palette, lineage, approval |
| Asset Inventory | | ✔ | | `entity-inventory.md` (2026-10-29, everything "Needed"); real inventory only discoverable from disk |
| Asset Specification | ✔ | | | 16 spec files with generation logs; format richer than `/asset-spec` produces; env/climb specs live in `design/art/` instead |
| Asset Status Tracking | | ✔ | | `asset-manifest.md` dead since 2026-10-31 (20 rows, 0 Approved) while ASSET-021..033 shipped; status scattered over specs, `active.md`, `skill-checklist.md`, `QA.md` |
| Asset Version History | | ✔ | | git + ad-hoc folder suffixes (v1/v2/v3, pre-*, clean-*, k2-*); dead finals kept in `assets/`; no written convention |
| AI Asset Generation | | ✔ | | PixelLab works and is well logged; no skill for anchors/env/UI; prompts scattered incl. a file outside the repo (`Downloads/tessera_idle_animation_prompts.md`) |
| Animation Generation | ✔ | | | `/pixellab-animation-engineer` + exporter + QA scripts; skill drifted out of use |
| Asset Review and Feedback | | ✔ | | `ART_QA_CHECKLIST.md`, art-check, contact sheets exist; `QA.md` only for Knight cast_hand + 4 idle clips; AD-VISUAL gate unused |
| Revision Management | | ✔ | | Retakes capped at 3 in the skill only; superseded PixelLab characters not retired; no candidate folder convention |
| Technical Asset QA | | ✔ | | `export_sheets.py --check`, `fxc check`, `anim_qa.py`, 17 unit/art tests — all manual; no hook/CI; `/asset-audit` rules wrong for sheets |
| Visual Consistency QA | | ✔ | | Human-only (by design), but §8.9 blackout/rows checks stopped being logged after Oct 31 |
| Godot Integration | ✔ | | | Render contract verified; data-driven indexes; gaps: overlays per body size, `.gdignore` for evidence, 8 units outside the export test |
| Asset Approval Process | | ✔ | | Per-call yes is enforced; per-result approval recorded inconsistently; "art-director sign-off" placeholder never resolved; no status lifecycle definition |

Character consistency across images and animations is **mechanically sound but unrecorded**: the lineage (which `style_image`, which character id, which local anchor) must be reconstructed from spec rows each time.

---

## 10. Recommended Architecture (smallest change set, reuse first)

**Recommendation:** do not build a separate AI art studio. Add one machine-readable registry, extend four existing components (the project skill, `/asset-spec`, `/asset-audit`, the commit hook), and sync three documents. Everything else already exists.

| Responsibility | Reuse / Extend / New | Why necessary | Location | Responsibilities | Depends on |
|---|---|---|---|---|---|
| **Art Direction** | Reuse `art-director` agent + `design/art/art-bible.md`; **extend** agent memory | Bible is current; agent has no memory and no pipeline knowledge, so each spawn re-derives rules | `.claude/agent-memory/art-director/MEMORY.md` (seed with the 17 art rules now in user memory + pointers to `docs/art/`), bible §8.1/8.3/8.7 sync | Keep identity, frame tiers, palette policy; approve additions to `.gpl` | P0 doc sync |
| **Asset registry (inventory + status + master reference + history)** | **New file**, reusing the project's registry pattern (`design/registry/entities.yaml`, `docs/registry/architecture.yaml`) | The manifest went stale because it is prose; status, ids and evidence need one keyed source that scripts and skills can read | `design/assets/asset-registry.yaml` — one entry per asset id: files, unit/clip, frame tier, PixelLab character/image/upload ids (full), anchor path, style_image lineage, palette subset, status per clip (`candidate / accepted / installed / approved / legacy`), approved_by/date quote, evidence paths, spec link, retired ids | Source of truth; `asset-manifest.md` becomes a rendered view | nothing |
| **Asset Design (specs)** | **Extend** `/asset-spec` with a project reference | Its generic prompt/manifest output does not match the spec format the project evolved (generation log, likeness check, PixelLab params) | `.claude/skills/asset-spec/references/project-format.md` + a template `.claude/docs/templates/asset-spec.md` mirroring `design/assets/specs/swordsman-assets.md`; env/climb specs move under `design/assets/specs/` | Produce specs with locked palette, canvas tier from the registry, prompt pack, pre-gen checklist | registry, bible |
| **Asset Generation (anchors, env, UI, cards)** | **Extend** `/pixellab-animation-engineer` with an `anchor` mode and an `image` mode (same cost gate, same QA hand-off) | Skill already has the approval gate, candidate layout, QA scripts; it explicitly lacks anchor creation | `.claude/skills/pixellab-animation-engineer/SKILL.md` (+ `references/anchor-checklist.md` from the memory rules, `model:` field), `design/art/pixellab-profile.md` reduced to generator defaults, per-unit data moved to the registry | Likeness check, pre-gen checklist, one-pilot rule, record ids into the registry | registry, profile |
| **Animation** | Reuse skill + `tools/asset-pipeline/export_sheets.py` + `tools/qa/sprite_*.gd`; **extend** acceptance path to run `anim_qa.py` | Already works; QA phase is skipped when run ad hoc | `tools/qa/art_check.sh` (new, thin wrapper: `export_sheets.py --check`, `fxc check`, registry check, `anim_qa.py` on changed clips) | One command for technical QA | registry |
| **Asset Review / revisions** | Reuse `ART_QA_CHECKLIST.md`, `prototypes/art-check`, contact sheets; **extend** `docs/art/PIXEL_ART_WORKFLOW.md` §5 with the candidate/version convention | Convention exists in practice, not in writing | `design/assets/candidates/<unit>/<clip>-v<N>-<date>/{raw,clean,QA.md}`; legacy finals moved out of `assets/art` or marked `legacy` in the registry | QA.md per candidate (skill template), verdict copied to registry | — |
| **Technical QA automation** | **Extend** `.claude/hooks/validate-commit.sh` (runs `art_check.sh` when `assets/art` or `art_src` are staged); **extend** `/asset-audit` with project rules; later `/test-setup` for CI | No automated gate exists; the hook infrastructure does | hook + `.claude/skills/asset-audit/references/project-rules.md` (drop power-of-two; add JSON/PNG match, alpha, palette, tier canvas, import flags, registry drift) | Block commits with drift; audit on demand | `art_check.sh` |
| **Visual QA / approval** | Reuse the solo approval; **extend** skill hand-off to offer the existing AD-VISUAL gate when a new asset *type* appears | Gate defined, never called | skill phase 7 + registry status transition | Record approver, date, quoted yes, evidence | registry |
| **Godot Integration** | Reuse `src/art/*`, `ArtAssets`, index JSONs; small fixes | Contract is correct; hygiene issues cost time | `production/.gdignore`; `sheet_export_test.gd` driven by the registry (all 16 units); `detect_3d` consistency; status-overlay packs per body tier (asset work, P3) | — | registry |
| **Rules** | **New** path-scoped rule file (the rules mechanism exists) | No rule covers art paths | `.claude/rules/art-assets.md` (paths `assets/art/**`, `art_src/**`, `design/assets/**`): RGBA, alpha 0/255, palette, naming, candidate vs final, registry update required | — | — |

Not recommended: `gamedev:create-game-assets` (needs Pillow, no generator, duplicates `PIXEL_ART_WORKFLOW.md`); a `team-art` orchestration (solo mode, no second approver); Aseprite adoption until an artist joins.

---

## 11. Proposed File and Directory Changes (none made)

**New**
- `design/assets/asset-registry.yaml`
- `tools/asset-pipeline/asset_registry.py` (scan disk + `clips.json` + sheet JSON → check registry drift, render `asset-manifest.md`; observations, not verdicts)
- `tools/qa/art_check.sh`
- `.claude/rules/art-assets.md`
- `.claude/docs/templates/asset-spec.md`, `.claude/skills/asset-spec/references/project-format.md`, `.claude/skills/asset-audit/references/project-rules.md`, `.claude/skills/pixellab-animation-engineer/references/anchor-checklist.md`
- `production/.gdignore` (or `production/qa/evidence/.gdignore`)
- `.claude/agent-memory/art-director/MEMORY.md`
- Later: `.github/workflows/art-check.yml`

**Extend**
- `.claude/skills/pixellab-animation-engineer/SKILL.md` (anchor + image modes, `model:`), then `/skill-test` it
- `.claude/hooks/validate-commit.sh` (art-staged → `art_check.sh`), `.claude/hooks/validate-assets.sh` (validate `assets/art/**/*.json` and `clips.json`)
- `design/art/pixellab-profile.md` (defaults only), `design/assets/asset-manifest.md` (generated), `docs/art/ASSET_SPECIFICATION.md` §2–6, `design/art/art-bible.md` §8.1/8.3/8.7, `docs/art/PIXEL_ART_WORKFLOW.md` §5, `tools/asset-pipeline/README.md`
- `tests/unit/art/sheet_export_test.gd` (all 16 units from the registry)
- Move `design/art/climb-map-asset-spec-2026-11-07.md`, `forest-arena-gap-plan-2026-11-06.md`, `region-visual-brief-2026-11-05.md` content into `design/assets/specs/`

**Decide, then possibly remove** (the user's call, not proposed unilaterally): `assets/art/env/forest/bg_forest_far{,_v2,_v3}.png`, `env_thorn_forest_tile16.png`, `vfx/cast/sword_wave` rollback, `vfx/floor/small_burst` TEMP, the stale worktree, 1,210 untracked `.import`.

---

## 12. Implementation Roadmap

| Priority | Work | Complexity |
|---|---|---|
| **P0 Foundation + audit** | `production/.gdignore`; build `asset-registry.yaml` from the current disk state using §5 statuses (unknowns kept as `unknown`); regenerate `asset-manifest.md`; sync `ASSET_SPECIFICATION.md` + bible §8 to real frame tiers and palette path; seed art-director memory; fix `detect_3d` on 8 sheets; resolve the 3 hand-painted `cast_hand` clips and untracked stair art | **Low–Medium** (no gens) |
| **P1 Specs, references, review** | Registry entries for all 16 units with full PixelLab ids and lineage; `/asset-spec` project format + template; candidate/version convention written; `art-assets.md` rule; status lifecycle (candidate → accepted → installed → approved → legacy) with approver/date/evidence; `validate-commit.sh` extension | **Medium** |
| **P2 Generation, animation, QA automation** | Extend the PixelLab skill (anchor/image modes, anchor checklist, registry writes) and skill-test it; `art_check.sh` wiring `export_sheets --check`, `fxc check`, `anim_qa.py`, registry check into `run_all_tests.sh`; `/asset-audit` project rules; `sheet_export_test` over 16 units; prompt bank consolidated into specs (retrieve the Downloads prompt file into the repo) | **Medium–High** |
| **P3 Godot integration + advanced** | CI via `/test-setup`; status overlays per body tier (elite/boss) and VFX cell-size policy; export preset + Android device QA; retire legacy finals; wire AD-VISUAL into the skill hand-off; portraits, remaining card art, other regions (paid, per approval) | **Medium** (High in gens) |

---

## 13. Unknown or needs the user's decision

1. **Three hand-painted `cast_hand` clips** (Assassin, Hunter, Cleric, uncommitted): keep as exception, or regenerate like the Knight's (≈3 gens)?
2. **Untracked climb `stair_*` art** and the three modified hero sheets: commit, or discard?
3. **Canonical clip list per tier**: is `step_up`/`step_back` required for every hero, is monster `strike` and hero `down` still required, or is the Knight's set the template?
4. **Status overlays for elites and bosses**: accept the goblin-size overlay on 80×80 / 160×130 bodies, or author new packs (free workbench)?
5. **Legacy finals in `assets/art`** (bg_forest_far v1–v3, thorn v1, sword_wave, small_burst TEMP): delete, or keep marked `legacy`?
6. **Burn fxc packs and floor packs F1–F10**: are they approved, or still "chờ ký"? The docs record look acceptance but no sign-off.
7. **UI plates / map icons / title / card frames**: approved or not? No approval line exists.
8. **Registry format**: YAML (matches `design/registry/entities.yaml`) or JSON (matches `assets/data/`)?
9. **Art-director agent**: keep it Bash-less with the user as sole approver, or give it Bash so it can run `art_check.sh` itself?
10. **CI**: GitHub Actions at all, given no `workflows/` exists today?
11. **Paid scope** (not started until approved): 5 portraits, 37 card arts, Lattice Heart island, 7 regions of enemies and environments.
12. **Stale worktree** `.claude/worktrees/vigilant-chebyshev-4d039b` and the 1,210 untracked `.import` files: clean up?
13. Unverifiable from disk: which `_c43x31` packs actually draw at runtime, draw-call counts, how the HUD's 0.5× icons look on device, the exact climb-map and env support-kit spend (only plan docs log it).
