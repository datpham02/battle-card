# AI Game Art Workflow — implementation progress (handoff for future sessions)

Read this first when continuing the workflow build. Baseline audit:
`docs/art/AI-ART-WORKFLOW-AUDIT-2026-11-11.md`. The repository state wins over
both documents when they disagree.

## Phase status

| Phase | Scope | Status |
|---|---|---|
| **P0** | Asset registry, registry tool, generated manifest, doc sync, art-director memory | DONE 2026-11-11 (user approved: "Start P1") |
| **P1** | Per-character Master References (16), consistency rules, candidate naming convention, history management | DONE 2026-11-11 (user approved: "Start P2") |
| **P2** | `game-art-workflow` orchestrator skill; extend `/asset-spec`, `/asset-audit`, `/pixellab-animation-engineer`; extend art-director / technical-artist agents; session continuity; PixelFX routing + Tessera notes | DONE 2026-11-11 (user approved: "Start P3") |
| **P3** | Generation metadata (`candidate.py`), unified QA (`art_check.py/.sh`), review package (`review_package.py`), PixelFX adapter + selftest + Godot test, proof-of-concept candidate | **DONE 2026-11-11** |
| **P4** | Production integration pipeline, safe technical fixes (`production/.gdignore`, `detect_3d`), hooks, CI proposal. Visual findings classified, not applied | **DONE 2026-11-11 — waiting for the user. No next phase.** |

**Current phase:** fresh P0 re-baseline done 2026-11-11 afternoon
(`docs/art/P0-BASELINE-2026-11-11.md`). The P0–P4 artifacts below still exist.
The user's new prompt stops here: do not start its P1 (region/monster YAML specs)
until they confirm. The PixelFX proof of
concept is still `acceptance: pending`
(`design/assets/candidates/pixelfx/impact_flash_steel_pixelfx-v1-2026-11-11/preview/REVIEW.md`);
`integrate.py pack` on that id exits BLOCKED until the user accepts it.
The deferred visual items are in the risk table. Do not start them without a yes.

**2026-11-14 PixelFX PoC installed.** The user accepted it in chat ("Chấp nhận", after the contact sheet and gif). `candidate.py verdict` recorded acceptance; `integrate.py pack` installed it (status `installed`, evidence `production/qa/evidence/integration/2026-11-14-vfx-floor-impact_flash_steel_pixelfx.md`). Found on the real run: `integrate.py` re-dumped the hand-laid `floor/index.json` (100-line diff). Fixed: `_insert_pack_line` appends one line and verifies the parse, falling back to a full rewrite. Rehearsed in a scratch tree: byte-identical to the real tree. `floor_vfx_test.gd` PACK_IDS gained the id (the suite asserts the index count). Not `approved`: no skill plays it.

**2026-11-14 state check (continuation after the context reset):** most P0–P4 files are
already committed (`c0c81ae8` and later). Still uncommitted from this workflow:
`tools/qa/review_package.py`, `tools/fx-pipeline/pixelfx_adapter.py`,
`tests/unit/art/pixelfx_adapter_test.gd`, `tests/fixtures/art/pixelfx_adapted_fixture/`,
`design/assets/candidates/pixelfx/` (proof of concept), today's `tools/qa/art_check.py`
fix and the two docs. **The P4.2 `detect_3d/compress_to=0` edit is no longer in the
tree:** HEAD and the working copy both hold 72 (now 78 with new card arts) imports at 0
and 262 at 1, and `git diff --ignore-cr-at-eol` on `assets/art/**/*.import` is empty.
The 140 "modified" imports differ only by CRLF. It was not re-applied: that is the user's
call (the mix is a WARNING in `art_check`, not a FAIL). Separately, the three art suites
red on a clean `main` (reported by another session) are not this workflow's: 128 untracked
candidate PNGs from the Ngàn Kiếm / forest-monster sessions, plus 7 candidate JSONs that
check out CRLF because `.gitattributes` has no `eol=lf` rule under `design/assets/candidates/`.

## P3 checklist (done 2026-11-11)

- [x] P3.1 Generation process: the skill's Phases 0–7 + `tools/asset-pipeline/candidate.py new|qa|verdict` persist folder, `metadata.json`, `QA.md` and registry events (`candidate_created`, `qa_completed`, `set-acceptance`); paid calls still gated by the specialised skill and the harness.
- [x] P3.2 Automated processing reuses `export_sheets.py`, `fxc.py check`, `anim_qa.py`, `sprite_measure.gd`, the Godot art suites — nothing duplicated.
- [x] P3.3 `tools/qa/art_check.py` + `art_check.sh`: modes `all | changed | asset | character | clip | candidate`; checks registry, sheets, packs, imports, PNG integrity, frames, anim_qa, Godot suites, hygiene; verdicts PASS / WARNING / FAIL / UNKNOWN (worst wins; UNKNOWN names the reason); `--json`; pre-fxkit packs with `qa.known_fxc_fail` reported as WARNING "KNOWN", never hidden or passed.
- [x] P3.4 `tools/qa/review_package.py`: contact sheet, GIF, before/after, `REVIEW.md` with QA summary, known issues, suggested revision; ends "Waiting for the user's decision".
- [x] PixelFX P3: `tools/fx-pipeline/pixelfx_adapter.py` 0.1 (`adapt`, `selftest`): window/crop, alpha quantise (threshold/Bayer), palette snap, red avoidance, border padding, VfxPack manifest with `source` provenance, previews, `fxc check`; proof of concept `impacts/hit-flash` → `impact_flash_steel_pixelfx-v1` (candidate, acceptance pending); registry entry `vfx.floor.impact_flash_steel_pixelfx` with the `pixelfx` block; `tests/unit/art/pixelfx_adapter_test.gd` + fixture.
- [x] Registry: `qa` recorded on the 23 pre-fxkit packs (observation, decision pending); `_check_pack` reads candidate folders for `candidate` / `accepted` entries.

## P3 tests (2026-11-11)

| Check | Result |
|---|---|
| `pixelfx_adapter.py selftest` (synthetic export: glow, translucency, border touch, telegraph red, foreign JSON) | 0 FAIL |
| Proof of concept: `node tools/render.mjs impacts/hit-flash --sheet --fps 20 --seed 17 --opts <steel ramp>` (free) → `adapt --frames 0:5 … --ramp steel` | fxc PASS; 7 × 50 ms, 80×64, 4 colours; `node tools/check.mjs impacts/hit-flash` ok |
| `art_check.py candidate <poc>` → `review_package.py <poc> --qa-json` | PASS; preview/contact_x4.png, anim.gif, REVIEW.md |
| `tests/unit/art/pixelfx_adapter_test.gd` | FAILS=0; watched failure: fixture `frame_ms` 50→51 gave FAILS=2, fixture restored byte-identical |
| `art_check.py all` (with the 18 Godot art suites) | verdict WARNING: 0 FAIL, 25 WARNING (23 known pre-fxkit packs, `detect_3d` mix, evidence imported), 55 PASS |
| `asset_registry.py validate` / `check`, manifest regenerated (108 assets) | 0 FAIL, 0 WARN |
| `candidate.py new --dry-run` | next version computed (v2), nothing written |

## P2 checklist (done 2026-11-11)

- [x] P2.1 `.claude/skills/game-art-workflow/SKILL.md` (+ `references/state-resolution.md`, `routing.md`, `integration.md`, `pixelfx-tessera-notes.md`): 12 modes (create, character, anchor, animation, vfx, ui, card, environment, revise, continue, audit, integrate), `--dry-run`; orchestrates, never generates / approves / installs.
- [x] P2.2 State resolution: registry `show` → Master Reference → bible sections → spec → production / candidates / evidence → lifecycle → missing fields; State card template; next-step decision table ordered attention → QA'd candidate → accepted → unknown-acceptance → mode default; NOT ASSESSED when the registry is unreadable or `check` fails for the id.
- [x] P2.3 `/asset-spec`: project overlay + `references/project-format.md` (registry-aware, project block format, manifest generated, targets character/animation/vfx/ui/card/environment). `/asset-audit`: overlay + `references/project-rules.md` (no power-of-two for sheets; registry check, export drift, fxc check, import flags, tiers, lifecycle, evidence, orphans; allowed commands added). `/pixellab-animation-engineer`: `model: sonnet`, `--mode animation|anchor|image`, Phase 0 reads registry + Master Reference, Phase A anchor / Phase I image with `references/anchor-checklist.md`, Phase 7 records to the registry; paid tools still absent from `allowed-tools`.
- [x] P2.4 `art-director.md` and `technical-artist.md`: "Tessera AI art workflow" sections (inputs, responsibilities, verdict ranking, what they never do); no new agents.
- [x] P2.5 Continuity: procedure in `state-resolution.md` §4 with worked examples; dry run executed (below).
- [x] PixelFX P2: VFX decision rule in `routing.md` + `pixelfx-tessera-notes.md` referencing the installed `pixelfx` skill (same commit as upstream 0.3.0, reused, not copied).
- [x] Registration: `.claude/docs/skills-reference.md` rows, `CCGS Skill Testing Framework/catalog.yaml` entry + spec `skills/utility/game-art-workflow.md` (5 cases).

## P2 tests (2026-11-11)

| Check | Result |
|---|---|
| Static linter (the 7 `/skill-test static` checks re-implemented in Python) on game-art-workflow, asset-spec, asset-audit, pixellab-animation-engineer | all PASS; two pre-existing WARN-class patterns unchanged (asset-spec: artifact skill without a verdict word; asset-audit: read-only, no "May I write"); no paid PixelLab tool in any `allowed-tools`; every named `references/` file exists |
| Skill registered | `game-art-workflow` appears in the session's skill list (frontmatter parses); catalog has one entry |
| Dry run `/game-art-workflow continue Knight cast_forward --dry-run` | resolved `unit.kiem_si` / clip `cast_forward` by rule 3 (entity + clip); `check` clean for the id; State card from registry + reference §11 + spec + candidates + evidence + active.md; next step = nothing to continue (approved 2026-11-08), offers `revise` / `audit`; nothing called. Finding: `design/assets/specs/swordsman-cast-forward.md` title still says "(NOT generated)" — stale spec header, listed as a doc fix |
| Persisted-data check for the second example (Hunter cast_hand) | true on the morning of 2026-11-11; the user dropped that clip the same afternoon, so the example no longer applies |

## PixelFX track (added 2026-11-11, `docs/art/PIXELFX_INTEGRATION.md`)

| Phase | PixelFX slice | Status |
|---|---|---|
| P0 | PixelFX recorded as a reference / candidate VFX tool; installed plugin verified: `pixelfx@pixelfx` 0.3.0, commit `a841596` (same as the marketplace clone and `C:/WorkSpace/research/pixelfx`); upstream HEAD `044e12a` is newer, plugin left untouched; licence (MIT + Sprite Fusion / Hollow Crown notices, non-MIT gallery font) recorded | DONE |
| P1 | registry `providers:` block (pixellab, pixelfx, fx-pipeline, script, hand, data) + `provider` on all 107 assets + `pixelfx` provenance block with `origin upstream/adapted/original`, attribution and adapter version rules enforced by `validate` | DONE |
| P2 | route VFX requests in `game-art-workflow` (PixelLab vs PixelFX vs fx-pipeline vs workbench); reuse the installed `pixelfx` skill, add Tessera notes (authoring checkout, `--fps 20`, Tessera ramps, alpha 0/255, square grammar, no red) | DONE (`.claude/skills/game-art-workflow/references/routing.md`, `pixelfx-tessera-notes.md`) |
| P3 | `tools/fx-pipeline/pixelfx_adapter.py` (PixelFX JSON+PNG → VfxPack candidate, alpha quantise, palette snap, `fxc check`) + selftest + Godot test; review package; proof of concept `impact_flash_steel_pixelfx-v1` as a candidate | DONE (pending the user's look) |
| P4 | install an approved PixelFX pack through `integrate.py`; `art_check` covers adapter output; existing packs unchanged | script ready; real install BLOCKED — PoC `acceptance: pending` (watched 2026-11-11, exit 2, nothing written). Existing packs not modified |

Division of labour (user decision): PixelLab = characters, animation, image assets; PixelFX = candidate for combat / magic / fire / projectile / impact / status / environment / UI effects; fx-pipeline, existing packs, Godot runtime and QA stay. PixelFX never replaces the others without a demonstrated technical reason, and its JavaScript never runs in Godot.

## Key architecture decisions (confirmed by the user 2026-11-11)

| Area | Decision |
|---|---|
| Asset registry | YAML: `design/assets/asset-registry.yaml` (strict subset, no PyYAML on this machine; the tool has its own reader/writer) |
| Character Master Reference | one file per character, `design/assets/references/characters/<id>.md` (P1) |
| Approval authority | the user only; `accepted` / `approved` need `--by user --evidence`; an automated PASS is never approval |
| Automation | maximum, inside those gates; no paid generation, no commit, no deletion, no overwrite of production art without the user's explicit word |
| Registry ids | stable slugs `type.name[.sub]`; the old `ASSET-NNN` numbers survive as `legacy_asset_id` (they collide: ASSET-020 twice) |
| Status by location | a file under `assets/art/` is `installed`; its `acceptance` stays `unknown` until a record is found or the user speaks |
| Required-but-missing assets | `backlog[]` in the registry, not lifecycle entries |

## Important file locations

| What | Path |
|---|---|
| Registry (source of truth) | `design/assets/asset-registry.yaml` |
| Registry tool | `tools/asset-pipeline/asset_registry.py` (`validate`, `check`, `manifest`, `bootstrap`, `set-status`, `set-production`, `show`, `export-json`) |
| Production install (P4) | `tools/asset-pipeline/integrate.py` (`pack`, `clip`; BLOCKED without acceptance; `INTEGRATE_ROOT` for a scratch rehearsal) |
| Registry schema + rules | `docs/art/ASSET_REGISTRY.md` |
| Generated manifest | `design/assets/asset-manifest.md` (archive of the 2026-10-31 hand-written one: `design/assets/asset-manifest-2026-10-31-archive.md`) |
| Engine-facing spec (synced) | `docs/art/ASSET_SPECIFICATION.md` |
| Art bible (§8.1/8.3/8.7 synced) | `design/art/art-bible.md` |
| PixelLab defaults | `design/art/pixellab-profile.md` |
| Exporter + sheet register | `tools/asset-pipeline/export_sheets.py`, `tools/asset-pipeline/README.md` |
| art-director agent memory | `.claude/agent-memory/art-director/MEMORY.md` (gitignored) |
| Master References (P1) | `design/assets/references/characters/<id>.md` (16), index `design/assets/references/README.md` |
| Consistency rules (P1) | `design/assets/references/CHARACTER_CONSISTENCY.md` |
| Candidate / version / history convention (P1) | `docs/art/PIXEL_ART_WORKFLOW.md` §5a; registry `history` events via `asset_registry.py log-event` |
| PixelFX integration | `docs/art/PIXELFX_INTEGRATION.md`; authoring checkout `C:/WorkSpace/research/pixelfx` (never the plugin cache); study `docs/research/pixelfx-study.md` |
| Orchestrator (P2) | `.claude/skills/game-art-workflow/SKILL.md` + `references/{state-resolution,routing,integration,pixelfx-tessera-notes}.md`; spec `CCGS Skill Testing Framework/skills/utility/game-art-workflow.md` |
| Skill overlays (P2) | `.claude/skills/asset-spec/references/project-format.md`, `.claude/skills/asset-audit/references/project-rules.md`, `.claude/skills/pixellab-animation-engineer/references/anchor-checklist.md` |
| Unified QA / review / candidates (P3) | `tools/qa/art_check.py` + `.sh`, `tools/qa/review_package.py`, `tools/asset-pipeline/candidate.py` |
| PixelFX adapter + PoC (P3) | `tools/fx-pipeline/pixelfx_adapter.py`, `design/assets/candidates/pixelfx/impact_flash_steel_pixelfx-v1-2026-11-11/`, `tests/unit/art/pixelfx_adapter_test.gd`, `tests/fixtures/art/pixelfx_adapted_fixture/` |
| Evidence | `production/qa/evidence/<topic>/` |

## P4 checklist (done 2026-11-11)

- [x] P4.1 `tools/asset-pipeline/integrate.py` `pack` / `clip`. BLOCKED without `acceptance: accepted` plus `accepted_evidence`. Never overwrites. Moves candidate → installed, writes `production/qa/evidence/integration/`, updates the registry and regenerates the manifest. Does not set `approved`. Scratch rehearsal via `INTEGRATE_ROOT` was done in the previous session; this session watched the real tree refuse `vfx.floor.impact_flash_steel_pixelfx` (acceptance `pending`, exit 2, no write).
- [x] P4.2 Safe fixes only: `production/.gdignore` (empty file; Godot stops importing evidence). `detect_3d/compress_to=0` on all 170 art imports. Everything else in the audit's technical list is classified below and was not applied.
- [x] P4.3 Hooks. `validate-assets.sh` validates `assets/art/**/*.json`, `art_src/**/*.json`, and the registry YAML. `validate-commit.sh` runs `art_check.py changed --no-godot` on staged art / sources / registry. FAIL or a check that cannot run blocks. Budget is 25 s (a 12 s budget false-blocked this tree: the changed-mode pass over the detect_3d import diff measured 13 s).
- [x] P4.3 bugfix in `art_check.py changed`, found while watching the hook: `units` was a list, so `|=` crashed on any dirty art path; VFX paths used `parts[:4]` (the kind folder) and `fxc` reported `no_manifest`. Both fixed. Kind `index.json` is not treated as a pack.
- [x] P4.4 CI proposal stays at `tools/ci/art-check.yml`. Not copied to `.github/workflows/`. Python only, no Godot, nothing paid.

## P4 tests (2026-11-11)

| Check | Result |
|---|---|
| `integrate.py pack vfx.floor.impact_flash_steel_pixelfx` on the real tree | exit 2, `BLOCKED — … acceptance: pending`. No file written |
| Commit hook, staged `art_src/units/goblin_scout/clips.json` with a fake clip `_hooktest` (missing frame) | exit 2. stderr: `BLOCKED: art check FAIL` with registry (`clip _hooktest … not in registry`) and frames (`frame file missing _hooktest/0.png`). File restored with `git restore --staged --worktree`; clip names back to idle/step/windup/hit/down; `git diff` empty |
| `art_check.py changed --no-godot` on the current dirty art tree (182 paths, before the hook mutation) | exit 0, verdict WARNING, 0 FAIL. Known pre-fxkit packs stay WARNING |
| 2026-11-14 — commit hook, staged a temp `art_src/units/_hooktest/clips.json` with malformed JSON | exit 2, `BLOCKED: art check FAIL` naming `frames [_hooktest] … is not valid JSON`. First run blocked too but `art_check.py` crashed with a traceback instead of a FAIL line; fixed (`check_frames` now reports malformed `clips.json` / sheet JSON as FAIL, reads `utf-8-sig`). Temp file unstaged and deleted, index empty |
| 2026-11-14 — `art_check.py all --no-godot` after that fix | exit 0, verdict WARNING: 0 FAIL, 0 UNKNOWN, 25 WARNING (23 known pre-fxkit packs + leftover `production/**/*.import` hygiene + 1 other), 92 PASS. Godot suites not rerun today (Godot slot held by another session; last 18/18 FAILS=0 on 2026-11-11) |
| `art_check.py all` after `.gdignore`, `detect_3d=0`, and the `changed`-mode fixes | exit 0, verdict WARNING: 0 FAIL, 24 WARNING (23 known pre-fxkit packs + 1492 leftover `production/**/*.png.import`), 56 PASS. Imports: 170/170 Lossless, no mipmaps, fix alpha, no premult, no `detect_3d` mix. 18/18 `tests/unit/art/*_test.gd` FAILS=0 |

## P4.2 risk table (classified, not applied)

Audit §6. None of these change pixels, paths, or runtime drawing until the user says so.

| Finding | Risk if left | Risk if "fixed" now | Decision |
|---|---|---|---|
| Status overlays only for hero and goblin sizes; goblin burn/chill/frozen drawn on 80×80 elites and 160×130 bosses | Boss status FX reads small. Unknown whether that look was accepted | New packs are a visual change (free workbench, still a look change) | User. Audit §13.4 |
| VFX authored at 64×46 and 43×31; `FloorVfx.variant_for` picks nearest and does not scale | Non-fill bursts can overflow the smallest cells | A scale policy changes every floor effect | User |
| HUD `CHIP_ICON_SCALE = 0.5` and a float ratio in `status_row.gd`; map backdrop float-stretched | Nearest filter drops pixels; icons look uneven | Integer scale changes the HUD layout | User |
| Project texture filter is Linear; `card_face.gd` draws art without `PixelFrame.nearest` | A new raw `draw_texture` in the battle HUD is bilinear | Flipping the project default changes every texture that does not opt into nearest | User |
| PixelLab manifests name sheets that were never shipped (`whole-with-sprite.png`, `part-*.png`); registry already warns via `clips_not_shipped` | None at runtime (the game reads the indexed clip) | Writing `clips_not_shipped` asserts a fact about every manifest. Do it as a registry edit when the user wants the warning gone, not as a silent rewrite | User |
| Names diverge from `[group]_[id]_[variant]_[size]` (bare card ids, `ui/*`, `_v2/_v3/_v4` backdrops kept beside the live file) | `/asset-audit` flags them. Nothing in the engine keys off that pattern | Renaming production files breaks every path and `.import` | User. Do not rename |

Already applied this phase, both reversible: `production/.gdignore`; `detect_3d/compress_to=0` on the 170 art imports. The 1492 `.import` files already under `production/` are leftovers. `.gdignore` stops new ones. Deleting the leftovers is a delete, so it waits.

## P4 completion report (2026-11-11)

### Summary

Accepted candidates now have one install command. The two technical fixes that do not change the picture (evidence no longer imported, 3D compression flag consistent) are in. Hooks block a bad art commit. The CI file exists and is off. Visual findings stay classified.

### Files this continuation touched

Modified (2026-11-14 continuation): `tools/qa/art_check.py` (malformed JSON → FAIL line), `docs/art/PIXELFX_INTEGRATION.md` §9 (P2/P4 rows closed), this file.

Modified: `tools/qa/art_check.py` (`changed` path bugs, hygiene wording), `.claude/hooks/validate-commit.sh` (budget 12 s → 25 s), `tools/asset-pipeline/README.md`, `.claude/docs/hooks-reference.md`, `.claude/skills/game-art-workflow/references/integration.md`, this file.

Created earlier in P4, not in this continuation: `tools/asset-pipeline/integrate.py`, `tools/ci/art-check.yml`, `production/.gdignore`, plus `set-production` in `asset_registry.py` and the hook extensions in `validate-assets.sh`.

Deleted: nothing.

### Registry

No status write. `integrate.py` on the pending PixelFX id refused before any registry edit.

### Safety

`art_src/units/goblin_scout/clips.json` was mutated, staged, and restored in the hook test. No production sprite, sheet, or pack was overwritten. No credits spent. Nothing committed.

### Acceptance criteria

| Criterion | Result |
|---|---|
| Accepted assets integrate through a repeatable pipeline | PASS for the script. Real-tree install of the only PixelFX candidate is BLOCKED until acceptance |
| Integration tests pass | PASS — `art_check.py all` 0 FAIL; 18 art suites FAILS=0. The scratch end-to-end rehearsal was the previous session's |
| Git hooks work and do not break the existing checks | PASS — watched exit 2 on a broken clip, file restored. Budget raised so the current import diff does not false-block |
| CI documented, no paid generation | PASS — `tools/ci/art-check.yml` is a proposal, not enabled |
| No automatic final approval | PASS — `integrate.py` never sets `approved` |

### Outstanding

The risk table. 1492 leftover `.import` files under `production/`. PixelFX PoC still pending the user's look. Pre-fxkit pack warnings (23) still "decision pending: re-export or waive".

## P0 checklist (done)

- [x] P0.1 Inspected `design/assets/`, `design/registry/`, `design/art/`, `assets/art/`, `art_src/`, `docs/art/`, `production/qa/evidence/`, specs, manifests; reused the registry pattern of `design/registry/entities.yaml`.
- [x] P0.2 `design/assets/asset-registry.yaml`: 107 assets (16 units with 172 clips, 41 VFX packs, 18 env, 12 UI groups, 13 cards, 1 texture, 6 config files) + 65 backlog rows. Every status / acceptance / approval carries the file and quote it came from; everything else is `unknown`.
- [x] P0.3 Lifecycle `candidate → accepted → installed → approved`, `legacy`; transitions table in the file, enforced by `set-status` and validated over `history`.
- [x] P0.4 `tools/asset-pipeline/asset_registry.py` (stdlib): validate / check (files, duplicates, orphans, drift vs `clips.json`, sheet JSON and VFX manifests) / manifest / bootstrap / set-status / show / export-json.
- [x] P0.5 `design/assets/asset-manifest.md` regenerated (generated header, summary, decisions table, per-type tables, backlog); old manifest archived.
- [x] P0.6 Docs synced to disk: `ASSET_SPECIFICATION.md` §0 note, §2 frame tiers, §3 palette path, §4 folders, §5 atlases/.gdignore, §6 `detect_3d`; art bible §8.1 folders + warden + palette rows, §8.3 hero/monster/warden rows, §8.7 texture note, header date; `pixellab-profile.md` paths + coverage note; exporter README table (16 units) + registry section.
- [x] P0.7 `.claude/agent-memory/art-director/MEMORY.md` seeded (pointers + the user's standing art rules + a review method).

## P1 checklist (done 2026-11-11)

- [x] P1.1 16 Master References generated from the registry, `clips.json`, the sheet JSON and quoted spec rows (identity, concept, anchor + approval, facing/frame, palette locked vs installed, PixelLab configuration + style lineage, animation contract with per-clip status, visual constraints, generation lineage, versions approved/retired/rejected, approval history, open points). Registry `pixellab` fields completed with full character / image / job / upload ids and `retired_ids`; `candidates` lists point at the real rotation / anim / clean folders; `reference:` links all 16.
- [x] P1.2 `design/assets/references/CHARACTER_CONSISTENCY.md`: anchor preservation, palette locking, silhouette/proportions, pixel density + frame alignment, feet, animation consistency, allowed variation, mechanical-edits-only, record-keeping — all restated from the bible / profile / production log, no new contradictory rule.
- [x] P1.3 Candidate convention in `docs/art/PIXEL_ART_WORKFLOW.md` §5a: `candidates/<group>/<asset-or-clip>-v<N>-<date>/{raw,clean,preview,QA.md,metadata.json}`, traceability fields, QA.md template; old folders keep their names (listed in the registry).
- [x] P1.4 History: `asset_registry.py log-event` (generation_started/completed, candidate_created, qa_completed, note; refuses state-changing events), plus `set-acceptance` / `set-status` from P0; events carry clip, job id, candidate path, evidence, note.

## Tests run (2026-11-11)

P1: `asset_registry.py check` 0 FAIL / 0 WARN after the patch and generation; `manifest` regenerated; `log-event` on a scratch copy: `user_approved` refused (state change), `generation_started --clip idle --job-id --candidate` accepted and `validate` clean; every `reference:` and `candidates` path verified on disk by `check`.

P0:

| Command | Result |
|---|---|
| `python -X utf8 -I tools/asset-pipeline/asset_registry.py validate` | 0 FAIL, 0 WARN |
| `python -X utf8 -I tools/asset-pipeline/asset_registry.py check` | 0 FAIL, 0 WARN, 78 INFO (installed assets with acceptance unknown / no spec) |
| YAML round trip (load → dump == file) | stable |
| lifecycle gates on a scratch copy (`--root <tmp>`): `approved → installed` refused; `approved` without `--by user` refused; `set-acceptance … --by user --evidence` then `set-status … approved --clip idle` accepted; `validate` clean afterwards | as expected; the real registry untouched |
| `python -X utf8 -I tools/asset-pipeline/export_sheets.py --check` | all 32 sheet files ok, exit 0 (no art changed) |
| `godot --headless -s res://tests/unit/art/sheet_export_test.gd` | FAILS=0 |
| `godot --headless -s res://tests/unit/art/sprite_sheet_test.gd` | FAILS=0 |
| `godot --headless -s res://tests/unit/art/art_assets_test.gd` | FAILS=0 |

## Outstanding issues / decisions for the user

Listed in `design/assets/asset-manifest.md` → "Needs the user's decision"
(registry `attention:` fields): Mage / Assassin / Hunter anchor result approval
not recorded; `small_burst`
TEMP; goblin-size status overlays on elites and bosses; arch / roots / ferns
conflicting approval records; untracked climb stair art; HUD icon direction.
Plus: the 65 backlog rows (portraits, 37 card arts, 7 regions, Lattice Heart
island, elite/boss overlays) are paid or design work that waits for the user.

## Known limitations

- The registry's YAML is a subset: no multi-line scalars, no anchors; long
  quotes stay on one line.
- Approval evidence that only exists in the gitignored
  `production/session-state/active.md` (Forest Witch clips) is recorded as
  `accepted`, flagged "session note", not `approved`.
- `check` compares the registry with `clips.json`, the sheet JSON and the VFX
  manifests; it does not open PNG pixels (palette / alpha checks stay in
  `export_sheets.py --check` and `fxc check` until P3's `art_check.sh`).
- Nothing is wired into hooks or CI yet (P4).
