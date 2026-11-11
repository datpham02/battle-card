# Project overlay — Tessera audit rules (replace the generic Phase 3 checks)

Pixel-art sprite sheets are not power-of-two textures and never will be; the
generic texture rule does not apply here. These are the checks that do, each
with the command that runs it and the verdict when it cannot run.

| Check | How | Verdict rules |
|---|---|---|
| Registry consistency | `python -X utf8 -I tools/asset-pipeline/asset_registry.py check` | FAIL lines = registry and disk disagree (missing production file, clip set / frame / loop drift vs `clips.json` and the sheet JSON, duplicate id or path, manifest numbers); WARN = orphan production file, missing candidate / evidence path, manifest clips without files; INFO = installed with acceptance unknown. Tool absent or crashes → `NOT ASSESSED — registry check did not run` |
| Sheet export drift + palette + alpha + margins (units) | `python -X utf8 -I tools/asset-pipeline/export_sheets.py --check` | exit 0 = every sheet matches its sources; exit 1 = drift (name the files); exit 2 = rule violation (off-palette pixel, alpha not 0/255, edge touch, > 8 colours). No `art_src/` → `NOT ASSESSED — no sources` |
| VFX pack files | `python -X utf8 -I tools/fx-pipeline/fxc.py check <pack dir> --layer overlay|floor` per pack under `assets/art/vfx/` | FAIL alpha / palette / telegraph_red / edge / overlay_too_long / sheet_size / no_whole; warn round_shape / odd_canvas. Known: the pre-fxkit PixelLab packs fail palette and length (`design/assets/specs/fx-pipeline-assets.md` "Observation on existing packs") — report, do not hide |
| Frame tiers | registry `frame` vs `docs/art/ASSET_SPECIFICATION.md` §2 (hero 96x70/72/92, monster 64x52 + wolf 68x52, elite 80x80, boss 160x130) | a unit outside its tier size = WARN with the entry |
| Import settings | every `assets/art/**/*.png.import`: `compress/mode=0`, `mipmaps/generate=false`, `process/fix_alpha_border=true`, `process/premult_alpha=false` (read with Grep) | any deviation = FAIL naming the file. Unit sheets are `detect_3d/compress_to=0` (eight of them were set on 2026-11-11). Report a unit sheet that is not 0 as WARN. Do not edit those `.import` files from this audit |
| Spec index | `python -X utf8 -I tools/asset-pipeline/spec_check.py` | exit 1 = FAIL (region set, invented sprite hex, approval inferred). Script missing → `NOT ASSESSED` |
| Reference coverage | a `unit_*_sheet.png` whose id has no `design/assets/references/characters/<id>.md` | WARN, name the id. Do not create the file in the audit |
| Reference hex | hexes in `design/assets/references/characters/*.md` against `art_src/palette/tessera_master.gpl` | a body colour absent from the GPL = FAIL. `#E5293B` cited only as forbidden telegraph is not a body colour. Do not add a hex to fix it |
| Render standard | reference §3 frame and §4 outline against `docs/art/RENDER-STANDARDS.md` | a frame that disagrees with the standard or the sheet JSON = WARN. Bible 32×48 or keeper 48×64 does not win |
| Naming | units `unit_<id>_sheet.*`; env `env_<kind>_<region>_<variant>.png` / `bg_<region>_<layer>[_vN].png`; VFX `<kind>/<pack>/{manifest.json,whole.png,behind.png,front.png}`; cards `<card_id>.png`; UI has no group prefix today (documented in ASSET_SPECIFICATION §4) | report deviations from the documented reality as INFO, from the bible target as WARN; never FAIL a file the spec documents as the convention |
| Lifecycle | registry `status`, `acceptance`, `attention` | `installed` with `acceptance: unknown` → INFO list (what waits for the user); `attention` set → list under "Needs the user's decision"; an `approved` entry without `approved_evidence` cannot exist (validate FAILs) |
| Evidence | each `installed` / `approved` entry's `evidence[]` paths exist | missing = WARN |
| Orphans | `asset_registry.py check` WARN "orphan production file" + Grep of `src/**/*.gd`, `assets/data/*.json`, `assets/art/**/index.json`, `region.json` for the stem | unreferenced = INFO (the registry may mark it `legacy` on purpose) |
| Godot import of non-art | `.import` files under `production/` | present = WARN "evidence imported by Godot" (P4 adds `production/.gdignore`) |

Verdict for the whole audit: worst of FAIL > WARN > NOT ASSESSED > PASS, with
every NOT ASSESSED named and its reason. Technical PASS says nothing about the
look: the user's acceptance is recorded in the registry, not inferred here.

Report sections for this project: Summary · Registry drift · Sheet export ·
VFX packs · Import settings · Naming · Lifecycle (needs the user) · Evidence ·
Orphans · Recommendations (which skill fixes what:
`/game-art-workflow integrate|revise`, technical-artist for pipeline drift).
