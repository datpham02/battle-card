# Routing table — which tool and skill for which request

The tool is chosen by what the asset needs, never by habit. State the chosen
route and the rejected ones in one line each.

## Characters and images → PixelLab (`/pixellab-animation-engineer`)

| Request | Skill call | Inputs you pass from the State card |
|---|---|---|
| new character anchor | `/pixellab-animation-engineer --mode anchor <entity_id>` | spec design row + palette table + likeness check (or `/asset-spec character:<id>` first), tier canvas (`docs/art/ASSET_SPECIFICATION.md` §2), style image lineage of the tier (heroes: Knight v3 south 84x84 upload `8efc54de`; Misty Forest enemies: Goblin v3 south rotation), facing |
| clip(s) for an existing character | `/pixellab-animation-engineer --mode animation <entity_id> <clip>` | Master Reference §2 anchor path, §3 frame/feet, §4 palette, §5 configuration, §6 contract (timing), §7 constraints, next candidate version |
| image asset with a reference (env piece, island, card art, portrait) | `/pixellab-animation-engineer --mode image <asset id>` | spec row, palette (region ramp or card ramp), size, `no_background`, style image if the family has one |
| tiles (flagstones) | same, `--mode image` with `create_tiles_pro` named in the request | region.json palette, cell size |

Paid tools are never in this skill's `allowed-tools`; the harness and the
specialised skill both ask.

## Effects → decision rule (`docs/art/PIXELFX_INTEGRATION.md` §2)

1. **Reuse:** an installed pack (`vfx.*` in the registry, `cast/index.json`
   `packs`, `floor/index.json` `packs`, `status/index.json`) or a code-drawn
   form (`src/art/impact_fx.gd` `FORMS`, `CastGlyphFx`, `FuseFx`, `SkyDropFx`,
   `DeliveryFx`) already does it → wire data (`index.json` entry), no art.
2. **Square-only, per cell size** (floor marks, square bursts, stamps, anything
   that must read as Tessera "magic is square") → `tools/fx-pipeline`: recipe
   in `tools/fx-pipeline/recipes/`, `python -X utf8 -I tools/fx-pipeline/fxc.py build <recipe>`,
   candidates under `design/assets/candidates/fx-pipeline/`, `fxc check`.
   Free, deterministic, already in the VfxPack format.
3. **A close PixelFX catalog effect exists** (`node tools/list.mjs <words>` in
   `C:/WorkSpace/research/pixelfx`, `docs/CATALOG.md`) → the installed
   `pixelfx` skill (plugin `pixelfx@pixelfx` 0.3.0) with
   `references/pixelfx-tessera-notes.md`. Output becomes a candidate pack through
   `python -X utf8 -I tools/fx-pipeline/pixelfx_adapter.py adapt <json> --out design/assets/candidates/pixelfx/<pack>-v<N>-<date> …`
   (alpha quantised, palette snapped, `fxc check` run, provenance in the
   manifest; `docs/art/PIXELFX_INTEGRATION.md` §4), then `art_check.py candidate`
   and `review_package.py`. Proof of concept: `impact_flash_steel_pixelfx-v1`.
4. **Organic generated look** (status overlays around a body, eruptions, smoke)
   → PixelLab `vfx_workbench` (free) through `/pixellab-animation-engineer --mode vfx-workbench`
   is **not** implemented; use the MCP workbench directly from the main
   session as before (free tools only), then the same candidate convention.

The effect's `provider` goes into the registry entry (`pixelfx` with its
block, `fx-pipeline`, `pixellab`). An adapted upstream effect is `adapted`,
never `original`.

## UI, cards, environment

| Request | Route |
|---|---|
| plates, map icons, 9-slices, composites, thorn tiles | deterministic scripts (`tools/asset-pipeline/make_ui_plates.py`, `make_map_icons.py`, `design/assets/candidates/misty-forest/scripts/*`); provider `script` |
| icons with a drawn look, islands, backdrops, support kit, card art | `/pixellab-animation-engineer --mode image` (the spec row holds the prompt; cards use `design/assets/candidates/ui/card-art/prompts.md`) |
| a region's slab set | script first (`draw_slabs.py` lineage), PixelLab stamps / flagstones as needed |

## Specs, audits, reviews

| Need | Route |
|---|---|
| no spec, or the spec predates the current canvas / palette | `/asset-spec <system:|level:|character:> <name>` — project overlay (`.claude/skills/asset-spec/references/project-format.md`) |
| technical audit | `/asset-audit <asset|all>` — project rules (`.claude/skills/asset-audit/references/project-rules.md`); plus `asset_registry.py check`, `export_sheets.py --check`, `fxc check` |
| visual review package | `Agent(art-director)`: contact sheet / GIF paths, in-game capture, before/after, QA summary, known issues, suggested revision prompt — ends with "waiting for the user", never a verdict |
| pipeline questions (import flags, registry drift, adapter, index entries) | `Agent(technical-artist)` |
| new asset *type* | ask the user about the AD-VISUAL gate (`.claude/docs/director-gates/ad-visual.md`) |
