# Animation Design Sheet — Combat

Covers: attack, heavy attack, combo attack, cast spell, skill animation, hit
reaction, hurt, death. Copy this file, fill every `<…>`, delete the guidance
lines in `>` quotes when done.

## Header

| Field | Value |
|---|---|
| Character | `<name>` (`<profile character key>`) |
| Clip | `<attack \| heavy_attack \| combo \| cast \| skill_<name> \| hit \| hurt \| death>` |
| Replaces | `<old clip path or "new">` — user's words: "<quote>" |
| Direction / view | `<direction>`, `<view>` |
| Frame | `<W×H>`, feet row `<R>`, feet x `<X>` |
| Loop | `<one-shot → idle \| one-shot → hold last>` |
| Engine (planned) | `<tool + mode>` — `<why>` |

## Gameplay purpose and events

> What must the player read, and when? Attacks: when the damage lands. Casts:
> when the spell leaves the hand (`release`) — the VFX/projectile code keys off
> it. Enemy attacks: the `tell` is the fairness window (≥ ~28 ticks before `hit`).

| Event | Frame | Tick from start | Who uses it |
|---|---|---|---|
| tell | `<f>` | `<t>` | `<telegraph / player>` |
| release / hit | `<f>` | `<t>` | `<projectile spawn / damage>` |
| recover | `<f>` | `<t>` | `<input returns>` |

## Key poses

> Combat key poses must change the silhouette. The usual cure for "stiff":
> weight onto the back foot + shoulders/hips twisted away in the anticipation,
> a step or lunge into the action, body rotation continuing past the target,
> cape/hair lagging 1–2 frames.

| Key | Name | Body mechanics |
|---|---|---|
| K1 | Ready (idle) | `<weight, hands, weapon>` |
| K2 | Anticipation peak | `<weight back, crouch depth, weapon position, twist>` |
| K3 | Action / contact | `<lunge, arm extension, weapon at target, smear?>` |
| K4 | Follow-through | `<overshoot, rotation, loose parts still moving>` |
| K5 | Recovery | `<back to stance; which frame blends into idle>` |

## Frames

| f | Pose / change from previous | Ticks | Event |
|---|---|---|---|
| 0 | source frame (idle) | — | — |
| 1 | `<…>` | `<…>` | |
| … | | | |

Phase split: anticipation `<a>`% · action `<b>`% · follow-through `<c>`% ·
recovery `<d>`% · total `<T>` ticks (`<ms>` ms).

## Category guidance

| Clip | Frames | Notes |
|---|---|---|
| attack (light) | 4–6 | short anticipation (1 frame), contact on frame 2–3, quick recovery |
| heavy attack | 6–8 | long held anticipation (8–12 ticks), lunge, 1-frame smear, 2-frame overshoot, slow recovery = punish window |
| combo | 3×4 | each hit a smaller anticipation; recovery only after the last hit; alternate sides/heights so hits read separately |
| cast spell | 6–8 | gather (hands/weapon pull in), held charge pose, `release` frame with the arm/weapon extended toward the target, follow-through; the spell itself is VFX, not in the body frames |
| skill (signature) | 8–12 | a silhouette no other clip has (spin, leap, two-handed overhead); keep the frame size budget |
| hit reaction | 2–3 | snap away from the hit (head and torso first), settle; feet stay |
| hurt (heavy) | 4 | recoil, stagger step, catch balance, stand |
| death | 6–8 | hit, knees buckle, fall, ground impact (1 px squash), settle; last frame held |

## Constraints (positive wording)

- Faces `<direction>` in every frame; camera does not move or zoom.
- `<weapon>` stays in the `<right/left>` hand and keeps its length.
- Feet: `<planted on row R | the near foot steps forward one cell-width | …>`.
- Only the character: no slash trail, sparks, glow or blood (VFX is separate).
- Palette: `<hex list>`; `<part>` stays `<colour>`.
- `<fix clauses from earlier takes>`

## Prompt Pack

> Compile with `references/prompt-templates.md`; paste the field values here.

## QA log

| Take | Job | Verdict | Crossed / not run | Fix applied |
|---|---|---|---|---|
| 1 | | | | |
