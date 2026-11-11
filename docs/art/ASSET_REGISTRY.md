# Asset Registry — schema, lifecycle and rules

`design/assets/asset-registry.yaml` is the single source of truth for every art
asset: where it is in its life, which files it is, where it came from (PixelLab
ids, lineage), and what the user said about it. It was introduced on 2026-11-11
(P0 of the AI Game Art Workflow, `docs/art/AI_GAME_ART_WORKFLOW_IMPLEMENTATION.md`)
and bootstrapped from what was on disk plus the records in the specs, the
`clips.json` sources, the VFX manifests, `region.json` and the skill-v2 reports.

Tool: `tools/asset-pipeline/asset_registry.py` (stdlib only; no PyYAML on this
machine, so the file is a strict YAML subset the tool reads and writes).
`design/assets/asset-manifest.md` is **generated** from the registry; the last
hand-written manifest is archived as `design/assets/asset-manifest-2026-10-31-archive.md`.

## Lifecycle

| State | Meaning |
|---|---|
| `candidate` | exists under `design/assets/candidates/` (or as raw generator output); not in the game |
| `accepted` | the user accepted this candidate (their words are recorded in `accepted_evidence`) |
| `installed` | the file sits under `assets/art/` and the game draws it. **Not approval.** |
| `approved` | the user approved the installed result; `approved_by`, `approved_on`, `approved_evidence` are filled |
| `legacy` | replaced or parked; kept for history, never deleted by the tool |

Transitions (`lifecycle.transitions` in the file, enforced by `set-status` and
checked over `history` by `validate`):

```
candidate → accepted | legacy
accepted  → installed | candidate (revised) | legacy
installed → approved | candidate (pulled back for rework) | legacy
approved  → legacy
```

`accepted` and `approved` are **user-only**: `set-status` refuses them without
`--by user --evidence "<file>: <the user's words>"`. The tool records; it never
decides. An automated QA PASS is not acceptance.

Art that is already `installed` (everything bootstrapped on 2026-11-11) cannot
go back to `accepted`; record the user's verdict on it with `set-acceptance`
(same `--by user --evidence` gate), which fills `acceptance` without moving the
state, then `set-status … approved` when they approve the installed result.

`acceptance` is a separate field (`unknown | pending | accepted | rejected`) so
that an asset that is physically `installed` can still say honestly that nobody
recorded the user's verdict. **`unknown` is the default and must never be
upgraded without a record.**

Units carry the lifecycle twice: the entry's own `status` is the anchor / body
(the character identity the user approved), and every clip in `clips[]` has its
own `status` + `acceptance` + evidence.

## Entry schema (assets[])

| Key | Content |
|---|---|
| `id` | stable key `type.name[.sub]`: `unit.kiem_si`, `vfx.floor.big_burst`, `env.forest.env_slab_forest_9slice`, `ui.climb.islands`, `card.hoa_xa`, `other.vfx_cast_index` |
| `type` | `unit` · `vfx_pack` · `env` · `ui` · `card` · `portrait` · `texture` · `other` |
| `name`, `entity_id`, `tier` | display name; game data id (unit id, card id, region); `hero / monster / elite / boss / n/a` |
| `legacy_asset_id` | the `ASSET-NNN` number from the 2026-10-31 manifest and the spec headers (not unique there: ASSET-020 = Chill overlay and Forest Witch) |
| `provider` | who made it: `pixellab` · `pixelfx` · `fx-pipeline` · `script` · `hand` · `data` · `mixed` · `unknown`; the top-level `providers:` block records each tool's version, source and licence |
| `pixelfx` | only for `provider: pixelfx`: `origin` (`upstream` unmodified · `adapted` changed for Tessera · `original` written with the pixelfx method), `effect_id`, `category`, `source_path`, `upstream_repo`, `upstream_commit`, `attribution` (required for upstream / adapted: the upstream file's notice), `seed`, `options`, `fps`, `render_cmd`, `exported_png`, `exported_json`, `adapter_version` (required once installed), `modifications` — see `docs/art/PIXELFX_INTEGRATION.md` §5 |
| `qa` | latest technical QA summary (`fxc_check`, `pixelfx_check`, `art_check`, `codes`, `report` path, `observed_on`); `known_fxc_fail: true` marks a pre-fxkit pack whose failure is recorded and waits for the user's re-export / waiver decision — `tools/qa/art_check.py` then reports it as WARNING "KNOWN", never as PASS; the human verdict stays in `acceptance` |
| `status`, `acceptance`, `accepted_*`, `approved_*` | lifecycle, see above |
| `attention` | one sentence when the user has to decide something; rendered in the manifest's "Needs the user's decision" table |
| `spec`, `reference` | the spec file; the per-character Master Reference (P1: `design/assets/references/characters/<id>.md`) |
| `production`, `source`, `candidates`, `evidence` | path lists: `assets/art/...`; `art_src/...`; `design/assets/candidates/...`; `production/qa/evidence/...` |
| `frame` | units: `w, h, body_h, facing` from `clips.json`; single PNGs: `w, h, colour_type` |
| `palette` | `file`, `max`, `colours` (from the sheet's `meta.tessera.palette`) |
| `pixellab` | `character_id`, `image_ids`, `job_ids`, `style_lineage` (which style_image / anchor the asset descends from) |
| `generation` | tool, recipe, gens, job id, raw folder — whatever the records give |
| `manifest` | VFX packs: `app, frames, frame_ms, loop, canvas, anchor, clips_shipped, clips_not_shipped` |
| `index_entry` | VFX packs: which `index.json` key points at the pack |
| `clips[]` | units: `name, frames, loop, ms, source_dir, status, acceptance, *_evidence, attention, generation, note` |
| `versions` | `current` + `retired[]` (`name, paths, evidence`) |
| `history[]` | `{on, event, from?, to?, clip?, by?, evidence?, note?}`; events: `generation_started, generation_completed, candidate_created, qa_completed, user_accepted, integration_completed, user_approved, candidate_rejected, version_retired, registered, note` |
| `notes[]` | free text that is not a decision |

`backlog[]` lists required assets with no production file (`id, name,
required_by, note`). They are not lifecycle entries; when one is produced it
becomes a `candidate` asset with the same id.

## Commands

```
python -X utf8 -I tools/asset-pipeline/asset_registry.py validate
python -X utf8 -I tools/asset-pipeline/asset_registry.py check
python -X utf8 -I tools/asset-pipeline/asset_registry.py manifest
python -X utf8 -I tools/asset-pipeline/asset_registry.py bootstrap [--add-missing]
python -X utf8 -I tools/asset-pipeline/asset_registry.py set-status <id> <state> [--clip <name>] --on YYYY-MM-DD --by user --evidence "..."
python -X utf8 -I tools/asset-pipeline/asset_registry.py set-acceptance <id> accepted|rejected|pending [--clip <name>] --by user --evidence "..."
python -X utf8 -I tools/asset-pipeline/asset_registry.py log-event <id> generation_started|generation_completed|candidate_created|qa_completed|note [--clip <name>] [--job-id <id>] [--candidate <path>] [--note "..."]
python -X utf8 -I tools/asset-pipeline/asset_registry.py show <id>
python -X utf8 -I tools/asset-pipeline/asset_registry.py export-json [path]
```

`check` reports `FAIL` (registry and disk disagree: missing production file,
clip set or frame differs from `clips.json` / the sheet JSON, duplicate id or
path, manifest numbers drift), `WARN` (missing candidate / evidence path,
orphan production file not in the registry, manifest clips without files) and
`INFO` (installed assets whose acceptance is unknown, entries without a spec).
It never judges the art.

## Rules for editors (people and skills)

1. Edit the registry, then regenerate the manifest; never the other way round.
2. Record what a file says, with the file. `evidence` is `path: "quote"`.
3. A new generation = a `candidate_created` (or `generation_*`) event and a
   candidate path; a user verdict = `set-status … --by user --evidence`.
4. Never delete entries or candidate folders; retire with `legacy` and a
   `version_retired` event.
5. Keep ids stable. A replacement body is a new `versions.current` with the old
   one in `versions.retired`, not a new id.
6. Run `check` before every commit that touches `assets/art/`, `art_src/` or the
   registry (P4 wires this into `validate-commit.sh`).
