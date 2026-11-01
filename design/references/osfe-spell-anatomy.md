# OSFE spell anatomy — reference for Tessera casts

**Source:** One Step From Eden (GOG build owned by the user), read from its official mod data
(`OSFE_Data/StreamingAssets/Data/Spells.xml`, the format the game ships for modders). No code was
decompiled. Nothing from the game is copied here: only how spells are structured, in our own words,
and aggregate timings. Read 2026-11-01.

**Why:** user playtest 2026-10-31 asked for casts that read like OSFE: the spell visibly leaves the
hero and lands on the cells, instead of only appearing on the cells.

## The four beats of a player spell

842 spells in the file, 270 of them player deck spells. Every player spell is the same four beats:

1. **Cast at the hand.** A short charge or glint plays at the hero's gun point. Median length
   0.15 s; most spells have no cast delay at all, so the spell feels instant.
2. **Delivery**, one of three shapes:
   - **Straight shot** (63% of player spells): a projectile leaves the hand and flies along the
     hero's row at 600–800 px/s (it crosses the field in about 0.2 s) and lands on the first
     target in that row.
   - **Lob** (24%): an object flies in an arc for 0.1–0.7 s (usually 0.1–0.2 s). While it flies,
     the cells it will land on carry a danger marker.
   - **Strike from above** (7%): bolts or blades drop onto several cells, 0.05 s apart.
   - Plus a small set of **slashes**: a cut shaped over the cells in front, about 0.2 s.
3. **A blast on every cell hit**, centred on that cell, about 0.2–0.6 s. Spells that hit several
   cells set them off **one after another, 0.05–0.2 s apart**, so the eye follows the spell.
4. **A mark left on the cell** (fire, crack, broken tile) that outlives the blast.

Spell animations run at about 70 ms a frame, 3–4 frame loops.

Not in the data (it lives in engine code): the hit feel — white flash on the target, a small
shake, a short freeze. Tessera's values for those are our own.

## How Tessera maps it

| Card effect | OSFE shape | Tessera beats |
|---|---|---|
| damage (sword) | straight shot | windup = charge at the hand; sword wave flies along the hero's row; a slash on each target cell, 0.05 s apart from the nearest |
| burn | lob | fireball arcs ~0.2 s, landing cells marked; blast; burning cell stays (exists) |
| pin / frost | straight shot | ice bolt; frost blast per cell |
| push | straight shot along the floor | ground gust; shockwave per cell |
| seal / thorns | strike from above / below | seal drops or spikes rise per cell, 0.05 s apart |
| fragile | lob | falling rock; crack stays (exists) |

Tessera keeps its windup (the swing's telegraph) as beat 1; beats 2–4 follow the timings above.
Every per-cell effect sits in the middle of its cell (user rule 2026-11-01).

## Tessera sword cast — as approved by the user (2026-11-01)

After several rounds of playtest feedback and two reference boards drawn by the
user, the damage (sword) cast is:

| Beat | Time | What shows | Data (`assets/art/vfx/cast/index.json`, `sword_wave`) |
|---|---|---|---|
| 1. Wind-up | swing telegraph | hero crouches into the coil pose and holds it (`cast_gesture` v4, frame 4) | `gesture_hold_frame: 4` |
| 2. Slash + sword qi | at launch | lunge-slash frame; the sword-qi wave flies straight from the hand to the **first cell** (the area cell nearest the hero) | `travel_sec: 0.15`, `path: first_cell`, `gesture_lead_sec: 0.03` |
| 3–4. Touch + big explosion | 0–130 ms after impact | one big ground burst on the first cell (`big_burst`, PixelLab-generated) | `impact: big_burst`, `first_hold_sec: 0.13` |
| 5–7. Spread | 80 ms per step | smaller bursts go off cell by cell through the rest of the area, breadth-first from the first cell (`small_burst`), square shards rising | `cell_burst: small_burst`, `flow_step_sec: 0.08` |
| 8. Fade | ~180 ms | shards dissolve | `flood.fade_sec: 0.18` |

Rules the user set on the way:
- Not separate projectiles running through the cells, and not slash marks appearing on the cells.
- Not a spread back toward the caster: it explodes on the first cell and spreads to the other cells.
- No gold tint / outline on the cells (`flood.tiles: false`): only the explosions spreading.
- Each cell is hit when its burst goes off: hit flash, shake and the HIT label wait for it.
