# PixelFX in the Tessera art workflow

Status 2026-11-11: **P0 + P1 of the PixelFX track done** (tool recorded, version
verified, registry provenance fields defined). P2–P4 (skill integration,
adapter + proof of concept, Godot integration) follow the main roadmap in
`docs/art/AI_GAME_ART_WORKFLOW_IMPLEMENTATION.md`. Earlier study:
`docs/research/pixelfx-study.md` (2026-11-02, Vietnamese).

PixelFX is a **reference and a candidate VFX authoring tool**. It does not
replace PixelLab (characters, images) or `tools/fx-pipeline` (the square-only
Tessera effects already in the game), and its JavaScript never runs inside
Godot: only its exported PNG + JSON do, after the adapter described in §4.

## 1. What PixelFX is (verified on the installed copy)

| Item | Verified value |
|---|---|
| Upstream | https://github.com/patch-gg/pixelfx — MIT, Copyright (c) 2026 Patch and Hugo Duprez |
| Installed plugin | `pixelfx@pixelfx` **0.3.0**, user scope, commit `a84159688af3ca37a4be05a0d422b94451b2e24e` (2026-10-31), installed 2026-11-02, cache `C:/Users/ADMIN/.claude/plugins/cache/pixelfx/pixelfx/0.3.0`, skill `skills/pixelfx/SKILL.md` (the only skill it ships) |
| Marketplace clone | `C:/Users/ADMIN/.claude/plugins/marketplaces/pixelfx` — same commit |
| Authoring checkout | `C:/WorkSpace/research/pixelfx` — same commit; the skill says "work in a pixelfx checkout"; renders land in its `records/<category>/<name>/`. **Use this clone, never the plugin cache**, so renders do not pollute the plugin. |
| Upstream HEAD on 2026-11-11 | `044e12a45dc9cc312cec50ee606dfc98afe5adc2` (`git ls-remote`) — **newer than 0.3.0**. Not updated: the plugin stays as installed until the user decides (P0 rule). |
| Runtime | Node ≥ 18 (`node` 22 present), no npm install needed for the tools; `esbuild` only as a dev dependency; ffmpeg optional for GIF / MP4 previews (present) |
| Library | 244 effects in 21 categories (`src/fx/<category>/<name>.js`, catalog `docs/CATALOG.md`), 12 "moves" (chained attacks), core in `src/core/` (`painter`, `sim`, `particles`, `color` with `PAL` ramps, `math` with seeded `Rng`, `act`, `rig`, `poses`, `chain`) |
| Tools | `tools/list.mjs` (search ids / names / tags), `render.mjs` (contact sheet; `--sheet`, `--gif`, `--mp4`, `--all`, `--seed`, `--fps`, `--opts JSON`, `--out DIR`), `act.mjs` (acted-out playback, 12 fps steps), `check.mjs` (spill, one-shots ending empty, loop seams, unseeded randomness, slow frames, act key order), `new.mjs` (draft file), `sheets.mjs` (whole library to `sheets/`), `compare.mjs`, `montage.mjs`, `serve.mjs` (gallery) |
| Authoring contract | `docs/AUTHORING.md`: `meta {name, desc, tags, size, origin, duration, loop, fps, bg, options{palette, seed, …}}`; pure effects export `draw(p, t, o)` (frame from `t` alone, seamless loops); simulated ones `create(o)` stepping `sim.js` particles; local coordinates with (0, 0) at the anchor (feet / impact point); one-shots draw nothing at `t = duration`; every random number from the seeded `Rng`; optional `export const act` (poses on 12 fps steps, `hits[{t, stop, shake, push}]`) |
| Two buffers | `color` (opaque, Bayer-dithered or translucent pixels) + `light` (additive glow). The sheet export composites both into one RGBA with **real alpha**. |

### Licensing facts to keep

- MIT applies to the code and the effects, with two conditions: keep the
  copyright and permission notice in copies or substantial portions.
- `NOTICE.md`: `src/core/sim.js` **and 202 effect files** carry a header like
  *"adapted from Sprite Fusion's open-source … MIT License, Copyright (c) 2026
  Hugo Duprez"*. Copying or adapting such an effect into Tessera keeps that
  header (and the Patch line) in the adapted file and in the registry's
  `pixelfx.attribution`.
- `src/core/act.js` adapts Hollow Crown (MIT, rehan-remade): same rule.
- `gallery/fonts` is Patch's own font and **not** MIT: never copied.
- `tools/fx-pipeline/NOTICE.md` already records that fxkit follows PixelFX's
  structure without copying code; it stays accurate.

## 2. Division of responsibilities

| Need | Tool | Why |
|---|---|---|
| Characters, character animation, image assets with a reference, illustrated assets, tiles | **PixelLab** (`.claude/skills/pixellab-animation-engineer`, profile `design/art/pixellab-profile.md`) | organic shapes need generation with a style image and palette lock |
| Combat VFX, magic, fire / explosions, projectiles, melee impacts, status effects, environmental effects, UI feedback, procedural loops | **PixelFX** as the first candidate, **fx-pipeline** when the effect must be square-only in the Tessera grammar (art bible P1: "mọi sức mạnh đều mang hình ô vuông"), **PixelLab vfx_workbench** when a generated organic look is wanted | PixelFX has 244 motion references and a draft → render → look → refine loop; fxkit already renders per cell size in the VfxPack format; the workbench is free and organic |
| Code-drawn runtime effects tied to gameplay events (`ImpactFx`, `FuseFx`, `SkyDropFx`, `CastGlyphFx`) | **Godot code** | they follow authoritative events, not clips |

Decision rule for a VFX request (P2 orchestrator): (1) does an installed pack or
a code-drawn form already do it → reuse; (2) must it be strictly square /
per-cell-size → fx-pipeline; (3) does `node tools/list.mjs <words>` find a
close PixelFX effect → PixelFX (reuse options, adapt, or write an original
with its method); (4) otherwise PixelLab workbench. PixelFX is never
mandatory; the request's look decides.

## 3. Export format vs the Tessera VfxPack format

PixelFX `node tools/render.mjs <id> --sheet [--seed N] [--fps N] [--opts JSON] [--out DIR]`
writes `records/<id>/<name>.png` (transparent frames in a grid, left → right,
top → bottom, `cols = ceil(sqrt(n·h/w))`) and `<name>.json`
(`tools/lib/fxlib.mjs` `spriteSheet`):

```
frames[i]: { filename "<name> i", frame {x,y,w,h}, rotated false, trimmed false,
             spriteSourceSize, sourceSize {w,h}, duration = round(1000 / fps) }
meta: { app "https://github.com/patch-gg/pixelfx", version "1", image, format "RGBA8888",
        size, scale "1", frameTags [{name, from 0, to n-1, direction forward}],
        pixelfx: { id, name, fps, loop, frames n, frameSize [w,h], pivot = meta.origin, columns,
                   act?: { windup, recovery, hits[{t, freeze}] } } }
```

`n = round(duration · fps) + (loop ? 0 : 1)`; frame size = `meta.size` plus
`2 × margin` (`--margin`, default 0); a one-shot's last frame is empty by
contract.

Tessera reads `assets/art/vfx/<kind>/<pack>/manifest.json` through
`src/art/vfx_pack.gd`: `frame_ms, loop, canvas{w,h}, anchor{x,y},
clips[]{name, depth behind|front|both, frames, frame{w,h}, offset{x,y},
sheets[{file, first_frame, frames, columns}]}`; the pack is played through an
`index.json` entry (`dir, layer floor|overlay, play loop|once|once_hold, clip,
frames, frame_ms, anchor center|ground_center|(feet), cell`), drawn at
`feet + offset`, never scaled, tinted by `modulate`.

| Field | PixelFX | Tessera | Mapping / finding |
|---|---|---|---|
| Frame size | `meta.pixelfx.frameSize` (= size + 2·margin) | `canvas`, `clips[].frame` | direct |
| Frame rects | `frames[].frame` on a grid | `sheets[].columns` + `frames` | direct: `columns = meta.pixelfx.columns`, `first_frame 0` |
| Duration / FPS | `duration = round(1000/fps)`, default **30 fps → 33 ms** | one `frame_ms` per pack (fxkit packs use **50 ms**, PixelLab packs 45–125 ms) | render with `--fps 20` (50 ms) to match the existing packs, or accept 33 ms; `frame_ms` is per pack so either works |
| Loop | `meta.pixelfx.loop` | `loop` + index `play` | loop → `loop: true`, `play: loop`; one-shot → `loop: false`, `play: once`; `once_hold` needs a `hold_frame` chosen by hand |
| Pivot / origin | `meta.pixelfx.pivot` = effect anchor in frame px (feet / impact point) | `anchor{x,y}` on the canvas; `clips[].offset` = frame top-left relative to the feet = `(-pivot.x, -pivot.y)` | direct; index `anchor` kind chosen per effect (ground effects: `ground_center`; cell marks: `center`) |
| Layers | `draw(frame, "back" | "front")` at runtime; the sheet export composites both | `depth` behind / front with separate sheets | the CLI export gives one composited clip (`whole`); a back/front split needs a small render script (P3 decision; fxkit packs already ship `whole` only for most) |
| Transparency | **real alpha** (glow baked as colour with alpha, translucent smoke, Bayer dither) | **alpha 0 or 255 only** (`fxc check` FAIL `alpha`; art bible §8.1) | adapter must quantise alpha (threshold or 4×4 Bayer, per effect) — the biggest incompatibility |
| Palette | any ramp via `options.palette` (`PAL.*` or hex list), glow adds off-ramp colours | every pixel in `art_src/palette/tessera_master.gpl` (`fxc check` FAIL `palette`), no colour near `#E5293B` | render with a Tessera ramp in `--opts`, then snap to the master palette in the adapter; red-family effects need a recolour |
| Shape language | discs, rings, soft volumes allowed | square / 45° only for magic (art bible P1; `fxc check` warns `round_shape`) | choose or adapt effects accordingly; `round_shape` stays a warning, the user judges |
| Cell size | one canvas per render | packs authored per cell size (`cell [64,46]` / `[43,31]`, `FloorVfx.variant_for`) | render twice with `--opts {"size": …}` where the effect exposes a size knob, or accept one size for overlays |
| Overlay length | any | overlay one-shots ≤ 0.35 s (`fxc check` FAIL `overlay_too_long`) | pick / trim `duration` |
| Import | — | Lossless, mipmaps off, fix_alpha_border on, nearest (`.import` convention) | same as every pack |
| Runtime | JS (`createFx`, `createAct`) | GDScript `VfxPack` | **no JS in Godot**: sheets only |
| Act timing | `meta.pixelfx.act {windup, recovery, hits[{t, freeze}]}` | `cast/index.json` `gesture_hold_frame`, `hit_feel {hit_stop, shake, recoil}`, `combat.json timing.delivery`, authoritative events | reference only: adapt the numbers to Tessera's own clips and events, never drive gameplay from the sheet |

## 4. Adapter (built in P3, 2026-11-11: `tools/fx-pipeline/pixelfx_adapter.py` 0.1)

```
python -X utf8 -I tools/fx-pipeline/pixelfx_adapter.py selftest
python -X utf8 -I tools/fx-pipeline/pixelfx_adapter.py adapt <effect>.json [--png <effect>.png] \
    --out design/assets/candidates/pixelfx/<pack>-v<N>-<date> --pack-id <pack> \
    [--frames A:B] [--crop WxH] [--frame-ms 50] [--alpha threshold|bayer] [--alpha-cut 128] \
    [--layer overlay|floor] [--anchor ground_center|center] [--cell 64x46] [--ramp steel|burn|...|#hex,...] \
    --origin upstream|adapted|original --effect-id <id> --upstream-commit <sha> [--seed N] [--title "..."]
```

Output: `whole.png`, `manifest.json` (VfxPack format + `source` provenance + `index_entry`),
`contact.png`, `anim.gif`, `adapter-report.json` (fxc findings, stats); exit 1 when `fxc check` FAILs
(files stay for inspection). Proof of concept: `impacts/hit-flash` rendered at 20 fps with the steel ramp →
`design/assets/candidates/pixelfx/impact_flash_steel_pixelfx-v1-2026-11-11/` (7 × 50 ms, 80×64, 4 colours,
fxc PASS; registry `vfx.floor.impact_flash_steel_pixelfx`, status candidate, acceptance pending). Godot
reads it like any pack: `tests/unit/art/pixelfx_adapter_test.gd` (fixture `tests/fixtures/art/pixelfx_adapted_fixture/`).

The steps, as designed:

1. read the PixelFX JSON, verify `meta.app` and `meta.pixelfx`;
2. re-pack frames into a `whole.png` grid with the Tessera 1 px rule, quantise
   alpha, snap colours to the master palette (recording the mapping),
   reject or flag telegraph red;
3. write `manifest.json` in the VfxPack format with `app: "pixelfx <id> via
   pixelfx_adapter <version>"`, `source {provider: pixelfx, effect_id,
   upstream_commit, seed, options, fps, adapter_version}` and the
   `index_entry` to add;
4. run `fxc.py check` on the result (the same gate as every fxkit pack) and
   write `contact.png` / `anim.gif` evidence next to it;
5. the candidate then follows the normal path: user acceptance → install
   (copy + `index.json` entry) → approval. **Existing production packs are not
   touched.**

One metadata system: the registry entry is `type: vfx_pack, provider: pixelfx`
with the `pixelfx` block (§5); the pack on disk is a normal VfxPack manifest.

## 5. Registry provenance (defined in P1, validated by `asset_registry.py`)

Top-level `providers:` describes every tool (pixellab, pixelfx, fx-pipeline,
script, hand, data) with version / commit / source / licence. Every asset has
`provider`. A PixelFX asset adds:

```yaml
pixelfx:
  origin: upstream | adapted | original   # unmodified upstream effect | upstream effect changed for Tessera | Tessera effect written with the pixelfx method
  effect_id: fire/torch                   # upstream id, or tessera/<name> for originals
  category: fire
  source_path: C:/WorkSpace/research/pixelfx/src/fx/fire/torch.js   # or the project copy once one exists
  upstream_repo: https://github.com/patch-gg/pixelfx
  upstream_commit: a84159688af3ca37a4be05a0d422b94451b2e24e
  attribution: "<the header notice of the upstream file>"   # required for upstream / adapted
  seed: 1
  options: {palette: [...], ...}
  fps: 20
  render_cmd: "node tools/render.mjs fire/torch --sheet --fps 20 --seed 1 --opts '...'"
  exported_png: design/assets/candidates/pixelfx/…/torch.png
  exported_json: design/assets/candidates/pixelfx/…/torch.json
  adapter_version: "0.1"                  # required once installed
  modifications: "what changed vs upstream"   # adapted only
qa: {pixelfx_check: pass|fail, fxc_check: pass|fail, report: path}
```

`validate` fails an entry whose `provider: pixelfx` lacks the block, whose
`origin` is upstream / adapted without `attribution`, or which is installed
without `adapter_version`. `frame`, `manifest`, `status`, `acceptance`,
`approved_*`, `history` are the same fields every VFX pack has.

## 6. Authoring workflow (P2 wires it into `game-art-workflow`)

`Draft → Render → Inspect → Refine → Render → QA → User Review`; never one
shot.

1. Identify the requested VFX (card id, delivery / impact type, layer, cell).
2. Inspect existing Tessera assets: registry `vfx.*`, `cast/index.json`,
   `floor/index.json`, code-drawn forms (`ImpactFx.FORMS`).
3. Search the PixelFX catalog: `node tools/list.mjs <words>` in the authoring
   checkout, `docs/CATALOG.md`; render the two or three closest
   (`node tools/render.mjs <id> --zoom 3`) and look at `records/<id>/contact.png`.
4. Decide: reuse (options only), adapt (copy the file, keep its notice, edit),
   or original (`node tools/new.mjs tessera/<name>`); or hand the request to
   fx-pipeline / PixelLab (§2 rule). Record the decision in the registry
   (`log-event … note`).
5. Load the art bible (P1 square magic, §4 palette, §8.5 overlays ≤ 0.35 s,
   §8.10 no glow / no smooth gradients) and the material ramp from
   `tools/fx-pipeline/palettes.json`.
6. Write the effect spec row in `design/assets/specs/fx-pipeline-assets.md`
   (or the card's spec): size, anchor kind, layer, duration, palette, seed.
7. Draft / modify the effect code (3–5 variants when the direction is open).
8. Render (`--seed`, `--fps 20`, `--opts` with the Tessera ramp).
9. Inspect the contact sheet and `--gif` / `--all`; judge at 1× and 2×.
10. Refine the worst thing; three rounds minimum.
11. `node tools/check.mjs <id>` clean.
12. `node tools/render.mjs <id> --sheet …` → PNG + JSON.
13. Adapter → VfxPack candidate (§4).
14. `fxc.py check <pack> --layer …`, then the Godot QA (`floor_vfx_test`,
    `vfx_pack_test`, contact sheet via `tools/qa/*contact_sheet.gd`,
    in-game footage with `--write-movie`).
15. Visual review package: contact sheet, GIF, in-game capture, before/after
    against the current pack, QA summary, known issues, suggested next prompt.
16. Wait for the user's words; record with `set-acceptance`.
17. Integrate only after explicit authorisation (copy to `assets/art/vfx/…`,
    index entry, `set-status installed`, evidence), then `approved` on the
    user's final word.

## 7. Acting concepts as references for Tessera timing

PixelFX acts: wind-up (negative keys before `t = 0`), anticipation /
release pose on the key frame ("snap"), attack, impact with `stop` (hit
freeze 0.03–0.2 s), `shake`, `push` and a springy `straw` target reaction,
follow-through, recovery. Tessera already has the equivalents and keeps them
as the source of truth: hero `cast_gesture` 9 slots with the coil held on
frame 4 and the release on frame 5, `cast/index.json` `hit_feel` (flash,
shake, hit_stop, recoil), `combat.json timing.delivery`, enemy `windup`
held on a 0 ms frame until the telegraph ends, `hit` 3 × 40 ms, and
timing driven by authoritative events (`cast_scheduled`, `impact_resolved`).
When designing a new combat effect, read the closest PixelFX act's numbers
(`meta.pixelfx.act` in the sheet JSON or `export const act` in the file) as a
reference for proportions, then express them in Tessera's own clips and
`hit_feel` values. The 24×38 stock character, its rig and poses are study
material only: never a production character, never a replacement for the
PixelLab-generated clips.

## 8. Known limitations (why it complements rather than replaces)

- Real alpha and additive light contradict the alpha 0/255 rule; the adapter
  quantises and the result must be judged by eye.
- Disc / ring / soft-smoke motifs contradict the square magic grammar; many
  catalog effects need adaptation or are references only.
- Default fire / blood ramps use reds the telegraph rule forbids on units;
  always render with a Tessera ramp.
- One composited layer per export; `behind` / `front` splits need a custom
  render (P3).
- JavaScript runtime only; Godot plays sheets.
- Upstream moves (HEAD `044e12a` vs installed `a841596`); pin the commit in
  every registry entry so renders stay reproducible.

## 9. Roadmap slices and acceptance

| Phase | PixelFX slice | State |
|---|---|---|
| P0 | tool recorded (this file, registry `providers.pixelfx`), installed version and source verified, plugin untouched | done 2026-11-11 |
| P1 | registry `provider` + `pixelfx` block + validation; provenance rules (upstream / adapted / original, attribution) | done 2026-11-11 |
| P2 | `game-art-workflow` routes VFX requests per §2; reuses the installed `pixelfx` skill (same version as upstream 0.3.0 — reuse, add Tessera notes: authoring checkout path, `--fps 20`, Tessera ramps, alpha rule, square grammar, no red) | pending |
| P3 | `tools/fx-pipeline/pixelfx_adapter.py` + selftest + Godot test; review package (`tools/qa/review_package.py`); proof of concept `impact_flash_steel_pixelfx-v1` (candidate only, pending the user) | done 2026-11-11 |
| P4 | install an approved PixelFX pack through the normal path; `art_check.sh` covers adapter output; existing packs unchanged | pending |

Done when: Claude can discover and evaluate catalog effects; create and refine
a new procedural VFX; render and inspect it; export PNG + JSON; adapt the
output to the VfxPack format; the registry keeps provenance; existing VFX keep
working; the user's approval is still mandatory.
