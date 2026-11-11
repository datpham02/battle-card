# Anchor and image modes — pre-generation checklist (Tessera)

A character's anchor is the still every clip descends from; an image asset
(env piece, island, card art, portrait, tile set) is a one-off render. Both
are paid Pro Flash / Pro calls, so everything below is settled **before** the
cost quote, and the user sees the filled checklist with the quote.

## A. Facts from the project (fill from files, never from memory)

| Item | Source |
|---|---|
| Registry entry or backlog row | `asset_registry.py show <id>` / `backlog[]` |
| Spec design row, locked palette (≤ 8 hex), likeness check | `design/assets/specs/<target>-assets.md` (run `/asset-spec` first if absent) |
| Tier canvas and feet rule | `docs/art/ASSET_SPECIFICATION.md` §2 (hero 96x70–72, monster 64x52, elite 80x80, boss 160x130); feet on the last row, feet x = canvas centre |
| Facing / view | heroes south-east (right), enemies south-west (left); `low top-down` |
| Style image of the family | heroes: Knight v3 south 84x84 (upload `8efc54de`); Misty Forest enemies: Goblin v3 south rotation; a new region's first enemy: the user decides (the Knight for scale, or none) |
| Concept reference | `design/art/reference/*.png` described in words — never an image input (user rule) |
| Consistency rules | `design/assets/references/CHARACTER_CONSISTENCY.md` §1–§3, §8 |

## B. The user's checklist (every line answered in the quote; user rule 2026-11-05 after wasted gens)

- [ ] **Likeness:** closest famous character or object named, and the two or
      three differences that keep this design its own.
- [ ] **Held prop** is in the hand and visible in the 3/4 view (crossbow, book,
      staff, daggers); the prompt says where it is held.
- [ ] **Accent colour** (the hero's block colour) on 2–3 large parts, ≤ 15 % of
      pixels; enemies have no accent.
- [ ] **Face** visible (eyes 2x2 Ink; a veil or hood still shows the face).
- [ ] **Value contrast** against the slab: identity in the upper half reads in
      blackout at 1×.
- [ ] **Height** matches the tier (hero ≈ 66 px, normal ≈ 46, elite ≥ 12 px
      taller than normals, boss fills the 2x2 block); the prompt states "about
      N px tall".
- [ ] **Palette locked** and `max_colors 8`; "No red, no glow" written as
      positive constraints (dark fantasy, muted, 1 px dark outline).
- [ ] **One pilot** generation first (one call), then the user decides the batch.

## C. Call shape (quote verbatim in the gate)

- Character anchor: `create_character_pro_flash` — canvas per tier, `low
  top-down`, 8 directions, seed (heroes 5, enemies 1 by precedent),
  `palette` + `max_colors 8`, `style_image` + `style_options` outline /
  detail / shading on, colour off, `no_background true`, prompt from the
  spec. Quadrupeds: `template: dog`. Bosses too wide for the character
  canvas: `create_image_pro_flash` single image (Warlock, Witch precedent).
- Image asset: `create_image_pro_flash` (≤ 128 px) or `create_image_pro`
  (bigger, e.g. 320x192 islands, 792x336 backdrops), palette locked,
  `no_background` per the spec.
- Tiles: `create_tiles_pro` with the region palette.

## D. After the result (free)

Rotations / image saved under
`design/assets/candidates/<group>/anchor-v<N>-<date>/raw/`; measure with
`tools/qa/sprite_measure.gd` (bbox, feet, colours off-palette, red pixels);
paste mock in game or art-check; present at 1× and 3×; the likeness line
again. The user's words decide; record them with
`asset_registry.py set-acceptance` (candidate) and, when the user calls it the
anchor, `set-status … accepted` then `installed` when the idle frame lands in
`art_src/units/<id>/idle/0.png`. A rejected still stays in its folder with
`QA.md` "Verdict: rejected — <the user's words>".
