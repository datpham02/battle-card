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

---

# Update 2026-11-15 — the glow bug was found and fixed; the capture is BLOCKED, and why

## The bug the blank capture was pointing at

The hypothesis at the bottom of the original write-up was right: **the glow path had never
drawn.** `_ready()` runs on TREE ENTRY, not on `add_child`. `UnitLayer` built the cue node,
added it to a parent that was not yet in the tree, and immediately asked for the glow canvas to
connect its `draw` signal — which returned null, and the owner's `if glow == null: return`
skipped the connection **without a symptom**. The cue clocked correctly, the suite stayed green,
and the body simply never drew.

Fixed by building the canvas on demand (`passive_cue_layer.gd`), so the null case cannot happen.
`victory_cue_test.gd` gained a leg that asserts the canvas exists **before the node enters the
tree** — the one assertion that would have caught this, and it is deliberately run on a node
that is NOT added to the tree, because adding it would make the assertion pass through `_ready`
and the test could no longer fail in the presence of the fault.

## The capture is blocked, and the blocker is not the harness

A re-shoot at the shipped `end_delay_sec` (1.5 s), **without** `--fixed-fps`:

| frame | result |
|---|---|
| f120, f140 | landed, `exit=0` |
| f155 … f205 | **timed out**, `exit=124`, six in a row, 240 s each |

The two frames that landed measure **0 body / 0 band**, and that is the CORRECT result, not a
failure: both fall **before** the victory, where the design says there must be nothing. The HP-bar
column reads 1488 in both, which is what proves the filter can see `#58D468` at all. A reader
skimming for "0" will mistake this for the old negative; it is the discriminating leg working.

### What the boundary is NOT

**Retracted: "frames past ~140 hang" is wrong.** It was stated to the whole team as a limit of
the capture tool, built from a single scenario. The monster-skills session had the counter-data:
f140/f200/f260/f330 all landed in a *running* match. A sample from one scenario says nothing
about the tool, only about that scenario.

**Also retracted: the `_freeze_battle` hypothesis.** `PROCESS_MODE_DISABLED` on the battle
subtree looked like the obvious cause, but the original 8 frames were shot *after* the match had
ended and they landed. Do not re-derive it.

### What the boundary IS — measured, same frame, same tree, back to back

```
A  --pattern=sand_sphinx (running match)  f200  exit=0    LANDED
B  --run=second_wind     (reaches victory) f200  exit=124  HUNG
```

Same frame number, same flags, same machine, consecutive runs. **The hang follows the
end-of-match path, not the frame number.** This is not a QA-infrastructure limit: a code path in
the game hangs when it is being screenshotted, and it is the path every player crosses on every
win. No mechanism is proposed here, because none has been measured.

### Why the obvious workaround is also unavailable

Shooting at `end_delay_sec = 0.2` — how the original 8 frames were taken — **cannot be
reproduced on the current tree.** That shortening was removed (`game_flow.gd`,
`_dev_kill_enemy_live`): *"every shot then timed out, including frame 60, which had worked
before."* The only remaining constant, `ART_DEMO_END_DELAY_SEC`, is 600 s — it lengthens.

So the Configuration-delta section above describes a flag that **no longer exists**. The 8
committed frames are evidence from a harness the tree can no longer build. They are kept, with
this boundary date, rather than deleted or quietly re-labelled.

## Status, stated plainly

- The glow bug: **found, fixed, and covered by a test that fails without the fix.**
- That the cue **draws on screen**: **NOT demonstrated.** No frame of the victory moment exists.
- That the cue is **readable from across the board**: not demonstrated, and downstream of the above.

The remaining gate is blocked on the end-of-match hang, which is its own defect and belongs to
its own investigation, not to F3.
