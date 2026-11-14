# UI style pass, 2026-11-14 — the HP plate and the shape tiles

**Why:** the user reported that the battle HP plate (top-left) and the reward / shop shape tiles
"still look like a modern border". They were right, and they were the last two places where it was
true: both still painted the pre-2026-11-01 look (flat `NIGHT_STONE` fill, 1 px `MIST` line) while
the rest of the game moved to the ancient pixel plate in three steps — 2026-11-01 (`PixelFrame`),
2026-11-02 (the button system) and 2026-11-07 (`plate_panel` on the event / rest / world-map /
character panels). This pass finishes that conversion; it is not a new direction.

## What the user approved

`option-B-and-F.png` — option **B** for the HP plate and option **F** for the shape tile, chosen off
`mockup-v3.png`, which showed every variant side by side. Both are drawn with assets that already
existed (`assets/art/ui/plates/plate_*_up.png`). **No PixelLab generation was spent on this pass.**

Rejected on that sheet, with the reason, so nobody re-proposes them:

- **C** (plate at ×2 in a 60 px box) — would push the panel into the Z1 band where the back-row
  units' heads sit.
- **D** (sunken slab, no gold rim) — kept on the sheet because a raised plate means "pressable" in
  art bible §7.4 and the HP panel is not tappable; the user chose B anyway, and the 2026-11-07 pass
  had already put raised plates on the equally untappable event / rest panels.
- **G** (the whole tile turns gold when selected) — a gold field drowns the tile's blue shape and
  its green "New" tag.

**Not the card frame.** The user's standing rule is that the stone frame with gold rivets belongs to
cards only. That frame is `assets/art/ui/cards/card_frame_ancient.png`, which has gem sockets at its
corners. This pass uses `assets/art/ui/plates/`, a different nine-slice with no gems, and skips
`UiButtons.draw_gem` (only PRIMARY buttons get those).

## Files

| File | Change |
|---|---|
| `src/ui/hud_skin.gd` | new `stone_panel`, `groove_bar`, `stone_card` painters |
| `src/combat/combat_view.gd` | `_draw_player_panel` uses them; two new consts in the HUD block |
| `src/run/reward_view.gd` | `draw_shape_tile` uses `stone_card`; the tile's border colour is gone |

Panel rects, tile rects and every touch target are unchanged, so no layout and no hit area moved.

### Deliberately NOT changed

`_draw_hud`'s two **corner panels** (the `hud_corner_panels` config path) still carry the old 1 px
frame. That mode is **off** in `combat.json`, so it cannot be screenshotted for the user to approve,
and its 52 px box holds three rows — the Engraving bar would land on the plate's lip and all three
rows would need re-laying. Converting it blind, with no evidence, would be worse than leaving it.
Worth its own pass if that mode is ever turned back on.

## Reading the screenshots

**Captured 2026-11-14, ~10:34–10:36**, from the shared checkout at that minute. In a tree a dozen sessions are
writing, a capture records whatever everyone happened to have on disk that second — so a screenshot needs its
time and a note on what else was live, or it quietly documents someone else's work. The same minute cuts both
ways: the character session's 10:30 `f3-prayer` frames contain *this* pass's HP plate, because
`combat_view.gd` was last written at 10:28:48.

The checkout is shared by about a dozen sessions, and two sets of changes that are **not part of this
pass** are live in the tree and therefore visible in the battle captures. They belong to the
character-system session's F3 work (uncommitted at capture time):

- a damage number drawn in the character's accent colour when a passive boosted the hit;
- a two-segment link from the enemy cell to the "+N" on a Priest heal.

Neither is the restyle. Do not attribute them to it.

## Evidence

| File | What it is |
|---|---|
| `mockup-v1/v2/v3.png` | the option sheet, drawn with the game's own painters, before any code changed |
| `option-B-and-F.png` | the two chosen options at 2x, before vs after |
| `before-after.png` | **the verdict shot**: the user's two original screenshots against the shipped result |
| `after-battle-hp-plate.png` | the HP plate in a real Misty Forest battle, 1280x720 |
| `after-reward-shape-tiles.png` | the reward screen's ink row, nothing selected |
| `after-reward-shape-tiles-selected.png` | the same with the left tile tapped: the gold selection ring |

Captured with `tools/qa/ui_style_shots.gd` (added by this pass), which loads the real `main.tscn` — these are
the running game, not mockups. `--mode=ink` forces the pending card and ink offers the way
`DemoArgs._force_reward_offer` does, because no dev arg reached the ink row before.

**Run them again with:**

```
godot --windowed --resolution 1280x720 --audio-driver Dummy --path . -s res://tools/qa/ui_style_shots.gd \
  -- --mode=battle --demo=controls_idle --no-autopause --out=<png>
```

`--no-autopause` is not optional: without it the window loses focus, the game pauses itself and the shot is of
the pause panel over a dimmed HUD. The first battle capture of this pass was exactly that.

## Verification

- `godot-parse-check` on all four changed / added scripts: ok.
- 29 suites under `tests/unit/ui/`, `tests/unit/layout/` and `combat_config_hud_test`: every one `FAILS=0`.
- No test asserted the old frame, so none needed changing; the painters are drawing-only and the rects they
  are given did not move.
