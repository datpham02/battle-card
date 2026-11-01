# Animation Design Sheet — Movement

Covers: walk, run, jump, fall, landing, dash, dodge. Copy, fill every `<…>`,
delete the `>` guidance lines when done.

## Header

| Field | Value |
|---|---|
| Character | `<name>` (`<profile character key>`) |
| Clip | `<walk \| run \| jump \| fall \| landing \| dash \| dodge>` |
| Direction / view | `<direction>`, `<view>` |
| Frame | `<W×H>`, feet row `<R>`, feet x `<X>` |
| Motion type | `<in place (engine moves the sprite) \| root motion baked in>` — never both |
| Loop | `<cycle \| one-shot → hold \| one-shot → idle>` |
| Engine (planned) | `<tool + mode>` — `<why; a template exists for walk/run/jump/slide>` |

## Gameplay purpose and events

| Event | Frame | Tick | Use |
|---|---|---|---|
| step_l / step_r | `<f>` | `<t>` | footstep sound, dust VFX |
| take-off / land | `<f>` | `<t>` | physics, landing dust |
| i-frames start / end (dodge) | `<f>` | `<t>` | invulnerability window |

## Key poses

> Cycles: contact → down → passing → up, then the same with the legs swapped.
> The second half must mirror the legs, not repeat the first half (half-period
> guard). Never ping-pong a cycle: the feet slide backwards.

| Key | Name | Body mechanics |
|---|---|---|
| K1 | `<contact>` | `<front heel down, back toe, arms opposite>` |
| K2 | `<down / squash>` | `<weight drops 1 px, knee bends>` |
| K3 | `<passing>` | `<legs cross, body highest or mid>` |
| K4 | `<up / push-off>` | `<body rises 1 px, back foot pushes>` |

## Frames

| f | Pose | Ticks | Event |
|---|---|---|---|
| 1 | | | |
| … | | | |

## Category guidance

| Clip | Frames | Notes |
|---|---|---|
| walk | 6 or 8 | body bob 1 px; arms counter-swing; 5–6 ticks |
| run | 6 or 8 | forward lean, one airborne frame, bigger arm swing; 4 ticks |
| jump | 3–4 | crouch (anticipation) → push → rise; hold the rise into `fall` |
| fall | 2–4 | apex, then a short loop (cape/hair up) |
| landing | 3 | 1–2 px squash on impact, absorb, stand; feet on the ground row |
| dash | 4 | lean/crouch, burst (smear allowed), glide, brake |
| dodge / roll | 4–6 | crouch, tuck, roll, rise; keep the size constant during the tuck |

## Constraints (positive wording)

- Faces `<direction>`; camera locked; same size every frame.
- Cycle: last frame flows into the first; no duplicate end frame.
- Feet touch the ground row except in airborne frames.
- Only the character: dust and speed lines are separate VFX.
- `<fix clauses>`

## Prompt Pack

## QA log

| Take | Job | Verdict | Crossed / not run | Fix applied |
|---|---|---|---|---|
| 1 | | | | |
