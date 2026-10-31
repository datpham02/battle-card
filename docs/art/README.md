# docs/art — pixel art production documents

**The visual identity lives in one place: [`design/art/art-bible.md`](../../design/art/art-bible.md)**
(Vietnamese, 9 sections, user-approved 2026-10-29, amended since). Nothing in
this folder restates it; when a document here and the art bible disagree, the
art bible wins and the document here is the one to fix.

| Document | Scope | Engine-specific? |
|---|---|---|
| [`PIXEL_ART_WORKFLOW.md`](PIXEL_ART_WORKFLOW.md) | How an asset goes from brief to game: reference, constraints, draw or generate, check, log. Reusable for another pixel-art project | No |
| [`ASSET_SPECIFICATION.md`](ASSET_SPECIFICATION.md) | The numbers for this project: frames, palette, naming, folders, export, Godot import | Yes (Godot 4.6, mobile) |
| [`ART_QA_CHECKLIST.md`](ART_QA_CHECKLIST.md) | What every asset is checked against before it is called a candidate or done, and which checks are automated | Mixed; each line says |

Where the rest of the art pipeline is:

- Per-asset specs and production logs: `design/assets/specs/*-assets.md`
- Status of every asset: `design/assets/asset-manifest.md`
- Candidates (not yet exported): `design/assets/candidates/<group>/`, with the
  drawing scripts next to them in `scripts/`
- In-engine look check: `prototypes/art-check/` (see its README for every option)
- Retained evidence: `production/qa/evidence/asset-slice1-art-check/`
- Reference concepts (composition and mood only, never traced):
  `design/art/reference/`

Source of the external reading list evaluated for these documents:
[awesome-pixel-art](https://github.com/Siilwyn/awesome-pixel-art) (read
2026-10-31). What was taken from it and what was not is in
`PIXEL_ART_WORKFLOW.md` §7.
