# Animation Principles for Game Sprites

The motion-design half of the skill. Engine- and tool-agnostic.

Sources: classic animation principles; game-feel practice. The timing-in-ticks,
per-action recipe and event ideas were adapted, in our own words, from
agent-sprite-forge (MIT) and perfectpixel-studio (MIT).

## 1. The four phases of every action

| Phase | What it does | Share of a one-shot |
|---|---|---|
| **Anticipation** | Moves *against* the action first: crouch before a jump, pull the blade back before the cut, lean back before a lunge. Tells the player what is coming. | 20–35 % (longer for enemies: it is their tell) |
| **Action** | The fastest part: few frames, big spacing, often a smear. | 10–20 % |
| **Follow-through** | Momentum carries past the target: blade overshoots, body keeps rotating, cape/hair keep going after the body stops. | 20–30 % |
| **Recovery** | Settles back to a neutral pose that can blend into idle. Can be cancelled. | 20–35 % |

**A stiff animation usually has no anticipation and no follow-through.** When a
user says "it just stands and swings", add: a weight shift onto the back foot,
shoulders/hips twisting away, a step or lunge into the action, the body
continuing after the blade, and the cape lagging 1–2 frames behind the torso.

## 2. Timing in ticks, not milliseconds

Author timing at 60 Hz ticks so every frame lands on a whole display frame:

| Ticks | ms | Reads as |
|---|---|---|
| 2 | 33 | smear / impact flash only |
| 3 | 50 | fast action frame |
| 4 | 67 | 15 fps: snappy action |
| 5 | 83 | 12 fps: default game animation |
| 6 | 100 | 10 fps: walk, idle beats |
| 8 | 133 | 7.5 fps: slow idle, heavy holds |
| 12+ | 200+ | held key pose (anticipation peak, victory) |

- Odd millisecond values (80 ms) round to uneven tick patterns (5,5,4,5) and
  stutter. Prefer the tick values above.
- **Hold key poses 2–3× longer than passing frames** instead of duplicating a frame.
- Keep a clip's ticks in a list next to its frames (`[5,5,3,2,3,6,8]`). The
  engine plays from that list; generated frames have no timing of their own.

## 3. Spacing, arcs, weight

- **Slow in / slow out:** frames bunch up near key poses and spread out in the action.
- **Arcs:** hands, weapon tips and heads move on curves, not straight lines.
  Check the weapon tip across frames: it should draw a smooth arc.
- **Weight:** the centre of mass moves before the limbs. A heavy hit drops the
  hips; a light jab barely moves them.
- **Overlap:** loose parts (cape, hair, scarf, ears, tail) start later and stop
  later than the body. 1–2 frames of lag is enough at sprite sizes.
- **Squash and stretch:** small in pixel art (1–2 px). Use it on landings and
  impacts, not on armour.
- **Smears:** one frame of the action may show the blade or limb stretched into
  a crescent. It must use the sprite's own palette.

## 4. Gameplay events and readability

- Mark events on frames: `tell` (the readable warning pose), `active`/`hit`
  (the damage frame), `release` (a projectile leaves), `recover`
  (control returns), `step_l`/`step_r`, `cancel_window`.
- **Enemy tells:** the tell must be a silhouette change and come at least
  ~28 ticks (~0.45 s) before the hit for a fair reaction window. Bosses longer.
- **Hit-stop** (engine side, not frames): ~4–6 ticks for a normal hit, ~8 for a
  guard break, up to ~18 for a boss finisher.
- The key pose must read at 1× game size: if the silhouette of the key pose
  looks like idle, the animation is not readable.
- Visual effects (slash trails, impacts, dust, magic) go on a **separate layer
  or sheet**, not baked into the body frames. Baked effects break palette
  rules, get flipped with the body, and cannot be re-timed.

## 5. Loop policy

| Policy | For | Rules |
|---|---|---|
| **Cycle** | idle, walk, run, hover | Last frame flows into the first; no duplicate end frame; never ping-pong (feet slide backwards). Walk/run: the second half mirrors the legs of the first half, it does not repeat them. |
| **One-shot → idle** | attacks, casts, dodges, hurt | Starts from the idle pose and ends in a pose that blends back into idle. Never played backwards as recovery. |
| **One-shot → hold last** | death, defeat, victory | Last frame is a stable pose that can be held. |
| **Hold → loop** | charging, channelling | One-shot wind-up, then a short cycle until released. |

## 6. Recipe table (defaults; the templates refine them)

Frames counted without the source frame. Ticks are per frame, default.

| Category | Frames | Key poses | Loop | Default ticks |
|---|---|---|---|---|
| Idle | 4 (6 for breathing + blink) | neutral, inhale peak | cycle | 8–10 each |
| Walk | 6 or 8 | contact, down, passing, up (×2, legs swapped) | cycle | 5–6 |
| Run | 6 or 8 | contact, push-off, flight, passing | cycle | 4 |
| Jump (take-off) | 3–4 | crouch, push, rise | one-shot → hold | 4, 3, 5 |
| Fall | 2–4 | apex, falling loop | hold → loop | 6 |
| Landing | 3 | impact squash, absorb, stand | one-shot → idle | 3, 5, 6 |
| Dash | 4 | lean/crouch, burst, glide, brake | one-shot → idle | 3, 2, 4, 6 |
| Dodge / roll | 4–6 | crouch, tuck, roll, rise | one-shot → idle | 3–4 |
| Attack (light) | 4–6 | wind-up, strike, follow-through, recover | one-shot → idle | 4, 2, 4, 6 |
| Heavy attack | 6–8 | big wind-up (held), lunge, impact, overshoot, recover | one-shot → idle | 6, 12 hold, 2, 2, 5, 8 |
| Combo (3-hit) | 3 × 4 | each hit has its own small wind-up; recovery only after the last | one-shot | 3–4 |
| Cast spell | 6–8 | gather, raise/charge (held), release, follow-through, recover | one-shot → idle | 5, 10 hold, 2, 4, 6 |
| Skill (signature) | 8–12 | as cast/attack but with a distinct, bigger silhouette | one-shot → idle | per design |
| Hit reaction | 2–3 | snap back, settle | one-shot → idle | 2, 4, 6 |
| Hurt (heavy) | 4 | recoil, stagger, catch balance, stand | one-shot → idle | 3, 5, 5, 6 |
| Death | 6–8 | hit, knees buckle, fall, impact, settle | one-shot → hold | 4–6, last held |
| Victory | 4–8 | pose build-up, held pose (optional loop) | one-shot → hold / loop | 6, held |
| Defeat | 6–8 | slump, kneel, head down | one-shot → hold | 6–8 |
| Boss move | 8–16 | long tell (held), telegraph pose, attack, long recovery (punish window) | one-shot → idle | tell ≥ 28 ticks total |
