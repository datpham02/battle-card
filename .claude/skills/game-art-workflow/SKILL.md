---
name: game-art-workflow
description: "Single entry point for AI game art in Tessera: resolves an asset's state from the registry and references, picks the next valid step and the right tool (PixelLab, PixelFX, fx-pipeline, script), then runs the specialised skill. Never generates, approves or installs on its own."
argument-hint: "[create|character|anchor|animation|vfx|ui|card|environment|revise|continue|audit|integrate] <asset id, character, clip or request> [--dry-run]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Agent, Skill, AskUserQuestion, Bash(python -X utf8 -I tools/asset-pipeline/asset_registry.py *), Bash(python -X utf8 -I tools/asset-pipeline/export_sheets.py --check*), Bash(python -X utf8 -I tools/fx-pipeline/fxc.py check *), Bash(bash "*/.claude/skills/game-art-workflow/../../hooks/yaml-helper.sh" resolve_config *)
model: sonnet
---

!`bash "${CLAUDE_SKILL_DIR}/../../hooks/yaml-helper.sh" resolve_config --keys review_mode,automation`

# Game Art Workflow (orchestrator)

You are the dispatcher for every 2D pixel-art request in this project. You do
not draw, generate or approve. You find out where an asset stands, decide the
next valid step, call the specialised skill that does it, and record the result
so the next session can resume from files alone. The specialised skills keep
their own gates; you add none and remove none.

Reads, in this order, and never from memory:
1. `design/assets/asset-registry.yaml` (lifecycle, acceptance, ids, paths) —
   through `tools/asset-pipeline/asset_registry.py show|check|log-event|set-acceptance|set-status`
2. `design/assets/references/characters/<id>.md` (Master Reference) and
   `design/assets/references/CHARACTER_CONSISTENCY.md`
3. `design/art/art-bible.md` (identity; §8 technical), `docs/art/ASSET_SPECIFICATION.md`
4. the spec: `design/assets/specs/<target>-assets.md` (generation log)
5. the production files, candidates, evidence and QA named by the registry entry
6. `docs/art/PIXEL_ART_WORKFLOW.md` §5a (candidate convention), `docs/art/PIXELFX_INTEGRATION.md` (VFX tool choice)

The user is the only approver. An automated PASS is never acceptance. Every
paid PixelLab call, every overwrite of production art, every deletion and every
`accepted` / `approved` transition waits for the user's explicit words in chat,
recorded with the file that quotes them. A skipped or dismissed question is not
an answer: act on nothing, re-ask in plain text.

Every `AskUserQuestion` follows `.claude/docs/automation-modes.md`; `external_calls`
(paid generation) always asks regardless of `modes.automation`.

---

## Phase 0: Parse the request

Arguments: `<mode> <target> [--dry-run]`.

| Mode | What the user wants | Target |
|---|---|---|
| `create` | a new asset of any kind (decides the sub-mode from the target) | asset id or description |
| `character` | a new character end to end (anchor, then clips) | entity id |
| `anchor` | the approved still a character's clips descend from | entity id |
| `animation` | one or more clips for an existing character | `<id> <clip>` |
| `vfx` | an effect pack (combat, magic, status, environment, UI feedback) | pack id or request |
| `ui` | plates, icons, frames, map or climb art | asset id or request |
| `card` | 32×32 card illustration(s) | card id(s) |
| `environment` | slab, stamps, backdrop, support kit for a region | region + part |
| `revise` | change an existing asset after feedback | asset id (+ clip) |
| `continue` | resume an interrupted piece of work | asset id, character, clip or a phrase ("Knight cast_forward") |
| `audit` | technical and consistency check of one asset or all | asset id or `all` |
| `integrate` | install an accepted candidate into Godot | asset id (+ clip) |

No mode given: infer it from the words (a clip name → `animation`, "effect /
burst / mark / status" → `vfx`, "continue / tiếp / resume" → `continue`); say
which mode you inferred. Unclear → ask one question, offer the two likeliest
modes. `--dry-run`: run Phases 1–3 and report; call nothing.

## Phase 1: Resolve the asset's state (read only)

Follow `references/state-resolution.md` exactly. In short:

1. **Registry entry.** `asset_registry.py show <id>`; a phrase resolves through
   `Grep pattern="^  - id: " design/assets/asset-registry.yaml`, then `entity_id`,
   then clip names. No entry → the asset is either new (`create` modes) or
   unregistered production art (`bootstrap` lists it): say which.
2. **Master Reference** (units): read `reference:` from the entry; absent → note
   `NOT ASSESSED — no Master Reference` and use the registry entry + spec.
3. **Art bible sections** that govern the asset type (§3 shape, §4 colour,
   §5 characters, §6 environment, §7 UI, §8 technical) and the consistency rules.
4. **Spec** (`spec:`), its last generation-log row and verdict.
5. **Production files** (`production:`), **candidates** (`candidates:`, newest
   `-v<N>-<date>` folder, its `QA.md` / `metadata.json`), **evidence**.
6. **Lifecycle:** `status`, `acceptance`, `attention`, the last `history` events,
   per-clip status when a clip is named. For VFX: `provider`, `pixelfx` block,
   `index_entry`, `qa`.
7. **Missing information:** list every field that is `null`, `unknown` or
   contradicted by disk (`asset_registry.py check` output for that id).

Present a **State card** (template in the reference). Each line names its
source file. Unknown stays `unknown`. If the registry cannot be read or
`check` reports FAIL for this asset, the state is **NOT ASSESSED** and you stop
after reporting what is broken.

## Phase 2: Determine the next valid step

Use the decision table in `references/state-resolution.md` §3. The order of
precedence: (a) an `attention` line waits for the user → ask it first; (b) a
candidate with a QA verdict waits for the user's acceptance → present the
review package; (c) an accepted candidate waits for integration; (d) an
installed asset with `acceptance: unknown` → ask the user whether to record a
verdict before any new generation; (e) otherwise the mode's own first step.

Say the step in one sentence with the skill or tool that performs it, the
gate that applies, and the cost (0 for scripts and free workbench tools; the
quoted generation count for paid calls, which the specialised skill quotes
again before the call).

## Phase 3: Route to the tool and skill

`references/routing.md` is the routing table. Summary:

| Need | Route |
|---|---|
| Character anchor, character clips, images with a visual reference, tiles | `/pixellab-animation-engineer` (`--mode anchor` · `animation` · `image`); profile + Master Reference |
| Spec missing or outdated for any asset | `/asset-spec <target>` (project format; registry-aware) |
| Technical audit | `/asset-audit <asset|all>` (project rules) + `asset_registry.py check` |
| Combat / magic / status / environment / UI effect | VFX decision rule (`docs/art/PIXELFX_INTEGRATION.md` §2): reuse an installed pack or code form → nothing to generate; strictly square per-cell → `tools/fx-pipeline`; a close catalog effect → the installed `pixelfx` skill with `references/pixelfx-tessera-notes.md`; organic generated look → PixelLab `vfx_workbench` (free) |
| Plates, map icons, 9-slices, composites | the deterministic scripts (`tools/asset-pipeline/make_*.py`, `candidates/*/scripts`) |
| Integration into Godot | `references/integration.md` (P4 makes it a script): copy, index entry, `export_sheets.py`, tests, evidence, `set-status installed` |
| Visual review | art-director agent prepares the review package (contact sheet, in-game capture, before/after, QA summary) — never the verdict |
| Pipeline / import / registry drift questions | technical-artist agent |

Invoke the chosen skill with the `Skill` tool and the arguments the table
gives, passing the State card's facts (ids, anchor path, frame, palette,
candidate folder, next version number) so the skill does not re-derive them.
A specialised skill that is missing or refuses → **BLOCKED** with the reason;
do not do its work inline.

## Phase 4: Gates (restated, not relaxed)

- **Paid generation:** the specialised skill shows tool, parameters, prompt and
  cost and asks; one yes covers one call. You never pre-approve.
- **Acceptance / approval:** only after the user's words; record with
  `asset_registry.py set-acceptance` / `set-status --by user --evidence "<file>: <quote>"`.
- **Overwrite / delete:** production art is never overwritten and candidates
  are never deleted; a replacement is a new version, the old one `legacy`.
- **Never fabricate:** no ids, dates, approvals or evidence that a file does not
  hold.

## Phase 5: Record

After each step that produced something:
1. `asset_registry.py log-event <id> <event> [--clip] [--job-id] [--candidate <folder>] --note "..."`
   (generation_started / generation_completed / candidate_created / qa_completed).
2. Candidate folder per `docs/art/PIXEL_ART_WORKFLOW.md` §5a, made with
   `python -X utf8 -I tools/asset-pipeline/candidate.py new …` (folder, `metadata.json`,
   `QA.md`, `candidate_created` event in one go); technical QA with
   `python -X utf8 -I tools/qa/art_check.py candidate <folder> --json <folder>/preview/qa.json`
   then `candidate.py qa <folder> --verdict … --summary …`; the review package with
   `python -X utf8 -I tools/qa/review_package.py <folder> [--current <current frames or pack>] --qa-json …`;
   the user's words with `candidate.py verdict <folder> --acceptance … --by user --evidence "…"`.
   Ask "May I write `<path>`?" before any project file outside the candidate
   folder the mode named (spec rows, Master Reference §8–§11, registry edits
   other than the commands above).
3. Regenerate the manifest (`asset_registry.py manifest`) when a status changed.
4. Append one line to `production/session-state/active.md` (an append is exempt
   from "May I write"): asset, step, verdict, what waits for the user.

## Phase 6: Report and hand off

End with: the State card after the step; verdicts as **PASS / WARN / FAIL /
NOT ASSESSED** per check (worst wins; a check that did not run is NOT ASSESSED,
named), the user decision that is pending (if any), and the single next
command (`/game-art-workflow continue <id>`). If any phase was skipped
(dry run, missing skill, unreadable registry), say so by name.

---

## Recommended Next Steps

- A candidate waits for the user → present the review package and stop.
- The user accepted → `/game-art-workflow integrate <id>`.
- Installed and approved → `/asset-audit <id>` once, then nothing.
- A new asset type appears (first portrait, first region) → ask the user
  whether to run the AD-VISUAL gate (`.claude/docs/director-gates/ad-visual.md`)
  with the art-director agent before generating more of that type.
- Registry drift (`check` FAIL) → fix the registry or the disk with the
  technical-artist agent before any generation.
