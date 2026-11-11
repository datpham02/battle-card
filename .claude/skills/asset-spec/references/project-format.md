# Project overlay — Tessera asset specs (read before Phase 1)

This project keeps its own spec format and a machine-readable registry. When
this file and the generic phases disagree, this file wins for this project.

## Inputs the generic phases do not know about

| Read | For |
|---|---|
| `design/assets/asset-registry.yaml` via `python -X utf8 -I tools/asset-pipeline/asset_registry.py show <id>` | what already exists, its status / acceptance, frame, palette, PixelLab ids, candidates; the `backlog[]` list = what is required and missing (use it instead of "Needed" rows in the entity inventory) |
| `design/assets/references/characters/<id>.md` | the Master Reference of an existing character (identity, anchor, palette, contract) — a new clip spec inherits it |
| `design/assets/references/CHARACTER_CONSISTENCY.md` | the rules every spec must restate for its asset |
| `docs/art/ASSET_SPECIFICATION.md` | the real frame tiers, palette path, folders, import settings (the art bible §8 numbers are targets) |
| `design/art/pixellab-profile.md` | PixelLab defaults (view, direction, seeds, style images) |
| `docs/art/PIXELFX_INTEGRATION.md` §2 | which tool an effect spec should name |

## Spec block format used in this project

The project's specs (`design/assets/specs/*-assets.md`) evolved past the
generic `ASSET-NNN` block. New blocks use this shape (quote an existing file of
the same tier, e.g. `hunter-assets.md`, `misty-forest-roster-assets.md`):

```
## <registry id> — <Name> (legacy id ASSET-NNN only if one already exists)

| Field | Value |
|---|---|
| Design (approved text) | one paragraph; for characters the concept file it comes from, "described in words, never used as an image input" |
| Tier / frame | from `docs/art/RENDER-STANDARDS.md`, then the sheet on disk. Bible §1 and §3 do not override those numbers. Hero 96x70 (Thợ săn / Giáo sĩ 96x72, Kiếm sĩ 96x92 body_h 70) · monster 64x52 (dire wolf 68x52) · elite 80x80 · keeper 160x130 |
| Facing / view | right = south-east (heroes), left = south-west (enemies); low top-down. Anchor: bottom centre, feet on the last pixel row |
| Palette | hex only when `palette_status` is `locked` or `group_assigned_not_per_creature` and every hex is in `art_src/palette/tessera_master.gpl`. Otherwise write `undefined`. Never invent a hex. ≤ 8 colours per unit |
| Likeness check | closest famous look + how this differs (required before any anchor) |
| Pre-generation checklist | prop held and visible in 3/4, accent on 2–3 large parts, face visible, value contrast (user rule 2026-11-05) |
| Tool / route | PixelLab (`create_character_pro_flash` … / `animate_image_pixminimax` …) · PixelFX (effect id) · fx-pipeline (recipe) · script — with the parameters |
| Prompt | positive wording only; subject recap verbatim from the Master Reference for clips |
| Clips (characters) | required per tier (Master Reference §6) with frames / ms / loop |
| Acceptance | what the user must see (in-game capture at 1× and 2×, contact sheet) |

### Generation log

| Step | Date | Tool | Settings | Cost | Output | Result |
```

`Status:` lines are no longer kept in specs: status lives in the registry.
When the spec is written, register the asset:
`python -X utf8 -I tools/asset-pipeline/asset_registry.py bootstrap` lists
production art without an entry; a planned asset is a `backlog[]` row (ask "May
I write" to add it); a produced candidate becomes an asset entry with
`status: candidate` and `provider`.

## Manifest

`design/assets/asset-manifest.md` is **generated** (`asset_registry.py manifest`).
Do not append rows to it by hand; update the registry and regenerate.

## Read order and the two jobs

Frame, anchor, outline and pixel rules come from `docs/art/RENDER-STANDARDS.md`
before `design/art/art-bible.md`. The bible still wins on identity where it
does not contradict that file, the roster, the 2026-11-05 brief, or the GPL.

Two jobs, do not mix them:

1. **Fill a spec or a Master Reference.** Missing facts stay `unknown`. A
   palette that is not `locked` or `group_assigned_not_per_creature` stays
   `undefined`. No sheet stays `sheet: absent`. Acceptance with no quoted
   user line stays `unknown`. Status is not written here; it stays in the
   registry. This job may proceed while data is missing.
2. **Prepare a generation prompt.** Stop if the Master Reference file is
   missing, or if `palette_status` is `needs_art_director_review` / `undefined`.
   Do not write colour into the prompt and do not call PixelLab. Do not call
   `set-status` with `approved`.

A missing prompt is not a reason to skip job 1.

## Which file, by asset type

Do not force one table onto every type. Do not write a new environment spec
for the seven regions that have none, and do not start a prompt bank.

| Type | Read |
|---|---|
| Character / unit | `design/assets/specs/*-assets.md` for that id, then `design/assets/references/characters/<id>.md`. Coverage only, not identity: `design/assets/characters/<region>/<id>.yaml` |
| Character animation | the same Master Reference §6, plus the clip spec if one exists (`swordsman-cast-forward.md` and its siblings) |
| Environment | `design/assets/specs/misty-forest-assets.md` for the region that has art. Others: roster + `docs/art/REGION-MATERIALS-AND-PALETTE.md`, and stop |
| Floor | the same environment spec and `docs/art/RENDER-STANDARDS.md` (16×16 nine-slice, no outline) |
| VFX | `design/assets/specs/fx-pipeline-assets.md`, then `docs/art/PIXELFX_INTEGRATION.md` |
| Card / UI | `design/assets/specs/slice1-combat-ui-assets.md` and `design/assets/candidates/ui/card-art/prompts.md` |

## Region and monster specs

`design/assets/regions/<id>.yaml` and `design/assets/characters/<region>/<id>.yaml`
are generated from the live roster. A region without a locked GPL ramp has
`sprite_palette_status: needs_art_director_review` and an empty colour list.
Do not add a hex there. Check with
`python -X utf8 -I tools/asset-pipeline/spec_check.py`.

## Prompts

PixelLab prompts: positive words only (negative words painted red —
`design/assets/specs/mage-assets.md` rows anim02); the subject recap verbatim
from the Master Reference §1; the style image of the tier; palette locked;
`no_background`. VFX effect specs name the route decided by
`docs/art/PIXELFX_INTEGRATION.md` §2 and the Tessera ramp.
