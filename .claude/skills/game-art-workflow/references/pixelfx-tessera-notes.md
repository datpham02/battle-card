# Using the installed `pixelfx` skill for Tessera (project notes, not a copy of the skill)

The skill itself is the plugin's `skills/pixelfx/SKILL.md` (`pixelfx@pixelfx`
0.3.0, commit `a841596`); invoke it as `pixelfx:pixelfx` and follow it. These
notes add only what Tessera needs. Full background: `docs/art/PIXELFX_INTEGRATION.md`.

1. **Checkout:** work in `C:/WorkSpace/research/pixelfx` (same commit as the
   plugin). Never render inside the plugin cache
   (`~/.claude/plugins/cache/pixelfx/...`). Renders land in that checkout's
   `records/<category>/<name>/`; copy what the project keeps into
   `design/assets/candidates/pixelfx/<effect>-v<N>-<date>/` with `metadata.json`
   and `QA.md` (`docs/art/PIXEL_ART_WORKFLOW.md` §5a).
2. **Search first:** `node tools/list.mjs <words>` and `docs/CATALOG.md`; render
   the closest two or three (`node tools/render.mjs <id> --zoom 3`) and look at
   `contact.png` before deciding reuse / adapt / original.
3. **Render settings for Tessera:** `--fps 20` (50 ms frames like the fxkit
   packs) unless the effect is a loop whose feel needs 30; `--seed N` fixed and
   recorded; `--opts '{"palette": [...]}'` with a Tessera ramp from
   `tools/fx-pipeline/palettes.json` (material ramps) — never the stock fire /
   blood reds (telegraph rule). `--bg none` for sheets.
4. **Grammar:** art bible P1 "magic is square": prefer square and 45° shapes;
   discs, rings and soft smoke are references or need adaptation; no glow as a
   separate layer (the sheet bakes it; the adapter quantises it); overlay
   one-shots over units ≤ 0.35 s; floor effects sit on the cell centre;
   readable from afar at 2× (user rule).
5. **Alpha and palette:** the export has real alpha; Tessera needs 0/255 and
   every colour in `art_src/palette/tessera_master.gpl`. The adapter
   (`tools/fx-pipeline/pixelfx_adapter.py adapt … --ramp <material> --alpha threshold|bayer`)
   does the quantising and snapping and runs `fxc check`; a render is a
   candidate only after it. Overlay one-shots: pick a `--frames A:B` window so
   `frames × frame_ms ≤ 350 ms` (one empty frame is appended when the clip does
   not end empty).
6. **Provenance:** record in the registry entry `pixelfx {origin upstream|adapted|original,
   effect_id, category, source_path, upstream_repo, upstream_commit, attribution,
   seed, options, fps, render_cmd, exported_png, exported_json}`. An adapted
   file keeps the upstream header notice (Patch; Sprite Fusion / Hugo Duprez
   where the file says so). Never copy `gallery/fonts`.
7. **Acting:** read `meta.pixelfx.act` / `export const act` as timing
   references only; Tessera's clips, `hit_feel` and authoritative events stay
   in charge (`docs/art/PIXELFX_INTEGRATION.md` §7). The stock character is
   never a production character.
8. **Checks:** `node tools/check.mjs <id>` clean before export; then the
   Tessera side (`fxc check`, Godot tests) after the adapter.
9. **Cost:** PixelFX is free; the user's approval is still required before a
   candidate becomes `accepted`, and the orchestrator's gates apply unchanged.
