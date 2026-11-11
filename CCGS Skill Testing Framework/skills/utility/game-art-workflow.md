# Skill Test Spec: /game-art-workflow

## Skill Summary

`/game-art-workflow` is the single entry point for AI game art in Tessera. It
takes `<mode> <target> [--dry-run]` (modes: create, character, anchor,
animation, vfx, ui, card, environment, revise, continue, audit, integrate),
resolves the asset's state from `design/assets/asset-registry.yaml` (through
`tools/asset-pipeline/asset_registry.py`), the Master Reference, the art bible,
the spec, the production files, the newest candidate folder and the history,
presents a State card, derives the next valid step from the table in
`references/state-resolution.md`, routes to the specialised skill or tool
(`/pixellab-animation-engineer`, `/asset-spec`, `/asset-audit`, the installed
`pixelfx` skill, `tools/fx-pipeline`, scripts, the art-director /
technical-artist agents) per `references/routing.md`, records the result in
the registry (`log-event`, `set-acceptance`, `set-status`) and reports
PASS / WARN / FAIL / NOT ASSESSED per check. It never generates, approves or
installs on its own; the user is the only approver.

---

## Static Assertions (Structural)

- [ ] Has required frontmatter fields: `name`, `description`, `argument-hint`, `user-invocable`, `allowed-tools`
- [ ] Has ≥2 phase headings (Phase 0–6)
- [ ] Contains the verdict keywords `PASS`, `WARN`, `FAIL`, `NOT ASSESSED`, `BLOCKED`, with the ranking stated
- [ ] Contains "May I write" language (candidate folders, spec rows, references, registry edits)
- [ ] Has a next-step handoff section (`## Recommended Next Steps`)
- [ ] `allowed-tools` lists no paid PixelLab tool (`mcp__pixellab__animate_*`, `create_*`, `edit_*`, `inpaint_*`)
- [ ] Every file named under `references/` exists: `state-resolution.md`, `routing.md`, `integration.md`, `pixelfx-tessera-notes.md`

---

## Behavioral Test Cases

### Case 1 — Continue an approved clip
**Input:** `/game-art-workflow continue Knight cast_forward`
**Expected:** resolves to `unit.kiem_si` clip `cast_forward` (registry `show`), reports status `approved` 2026-11-08 with its evidence, finds no `attention`, states "nothing to continue" and offers `revise` or `audit`. No generation, no registry change.

### Case 2 — Continue a clip the user dropped
**Input:** `/game-art-workflow continue Hunter cast_hand`
**Expected:** resolves to `unit.tho_san`, finds no `cast_hand` clip, and stops. It does not regenerate and does not ask keep-or-regenerate. The same is true for Kiếm sĩ: that clip was dropped the same day.

### Case 3 — VFX request routing
**Input:** `/game-art-workflow vfx "ice shards burst on the hit cell" --dry-run`
**Expected:** applies the VFX decision rule in order (installed pack / code form → fx-pipeline square-only → PixelFX catalog match via `node tools/list.mjs` → workbench), names the chosen route and the rejected ones, states PixelFX output is reference-only until the adapter exists, and calls nothing because of `--dry-run`.

### Case 4 — Registry unreadable
**Input:** any mode while `design/assets/asset-registry.yaml` is missing or `check` FAILs for the target
**Expected:** verdict `NOT ASSESSED` naming the cause; suggests `bootstrap` / the technical-artist; does not proceed to generation.

### Case 5 — Acceptance gate
**Input:** `/game-art-workflow integrate unit.phap_su` with `acceptance: unknown`
**Expected:** `BLOCKED — not accepted`; no file copied, no `set-status`.

---

## Protocol Assertions

- [ ] Paid generation is quoted and asked for by the specialised skill; the orchestrator never pre-approves
- [ ] `accepted` / `approved` only through `set-acceptance` / `set-status --by user --evidence`
- [ ] Production art is never overwritten; candidates never deleted
- [ ] Skipped phases (dry run, missing skill, unreadable registry) are named in the output
