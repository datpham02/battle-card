# F3 §2.1 — `second_wind` victory cue — readability gate

**Result: the cue does NOT appear in any captured frame. This is a RESULT, not a failed capture.**

Captured 2026-11-14 ~20:39–20:40, windowed 1280×720, `--audio-driver Dummy`, `--character=kiem_si
--run=second_wind`, 8 frames (f080–f135).

## The measurement

| Frame | Cue pixels in band | min y | Whole-screen `#58D468` |
|---|---|---|---|
| sw-f080 | **0** | — | 1488 |
| sw-f085 | **0** | — | 1488 |
| sw-f090 | **0** | — | 1488 |
| sw-f095 | **0** | — | 1488 |
| sw-f100 | **0** | — | 1488 |
| sw-f110 | **0** | — | 1488 |
| sw-f120 | **0** | — | 1488 |
| sw-f135 | **0** | — | 1488 |

**Frames with cue pixels: 0 of 8. Zero-pixel frames are counted and listed, not dropped** — a run
that quietly filters its empty frames reports on whatever survived, which is how a half-working
effect looks finished.

### The band, and why it is not the whole screen

Measured inside **x 410–530, y 100–152**, which sits strictly **above** the hero sprite
(x 440–500, y 153–290, located by cropping f080 and reading the sprite's edges).

The exclusion is load-bearing: **the HP bar is the same `#58D468` as the cue**, because the cue
deliberately uses `HudSkin.HP_FILL` so that green reads as "health". A whole-screen filter returns
**1488 matching pixels in every frame, at identical coordinates** — the bar — and an eye scanning
that column would read "green pixels present in all 8 frames" as the cue being there. The glow is
drawn additively over the sprite and so is bounded by the sprite's own silhouette; it cannot reach
this band. Anything green in the band can only be the rising text.

### What this measurement CANNOT see

- **The first part of the text's rise, while it still overlaps the hero's body.** The band starts
  above the sprite. This gate proves the text reached open space or did not; it says nothing about
  where it started.
- **The glow itself.** The glow lives inside the silhouette, which is the region the band excludes
  on purpose. A separate instrument is needed for it, and this capture is not it.

### Configuration delta, stated rather than buried

These frames were shot with **`end_delay_sec = 0.2`**, not the shipped **1.5 s**
(`CombatView.DEFAULT_END_DELAY_SEC`). The dev flag shortens it so the cue lands in frame numbers a
windowed capture can actually reach; shots at frames 150–200 timed out, including one at a full
600 s.

**Why the delta does not invalidate a negative result:** `end_delay_sec` changes *when*
`match_ended` is emitted, not *whether* it is, nor what runs afterwards. The cue's own window is
`between_sec` = 3.0 s of frozen board, which is independent of it. So a cue absent across 55 frames
of that window is absent for reasons the delay cannot explain. **This argument would NOT hold for a
positive result** — "it appeared with a shortened delay" is weaker than "it appears in the shipped
configuration" — so if a later run does show the cue, re-shoot at 1.5 s before calling it proven.

## What is known to work, and how that squares with a blank capture

`tests/unit/battle/victory_cue_test.gd` passes **FAILS=0**, including the control leg: the same node
with `PROCESS_MODE_INHERIT` must FAIL to advance under a frozen parent, and it does.

And an earlier run of this same capture produced, repeatedly, `String formatting error ... at
_draw_passive_cue_text (unit_layer.gd)`. That error is evidence in its own right: **the draw function
was being called, many times, while the battle was frozen** — which is exactly the mechanism the
`PROCESS_MODE_ALWAYS` node exists to provide. The text threw before drawing anything (the
`ui.hud.passive_heal_number` row had not been re-imported into `strings.vi/en.translation` yet), so
nothing reached the screen.

**The narrowest hypothesis left:** the text path runs and the glow path has never drawn. They are
separate callbacks on separate canvases (`_draw_passive_cue_text` on the cue node,
`_draw_passive_cue_glow` on its additive child), so one can work while the other never fires. **That
is where to look next — not at another capture.** Shooting more frames of the same harness answers
the same question again.

## Capture provenance

- Manifest scope: tree-wide by **extension** (`.gd .json .csv .tres .tscn .cfg .sh .png .import .uid
  .translation`), excluding this folder, which the capture writes into. Excluding its own output is
  what stops the gate firing on every single run.
- The capture before this one reported `TREE MOVED` and it was **wrong** — a single corrupt line in
  the manifest (two hashes concatenated) shifted every `paste` row after it, which `diff` then
  reported as a mass deletion of another session's files. Nothing had been deleted. The hash
  pipeline now validates that every line is 40 hex characters, and the manifest is taken after a
  settle, because the corrupt line came from hashing files while Godot's `--import` was still
  writing them.
