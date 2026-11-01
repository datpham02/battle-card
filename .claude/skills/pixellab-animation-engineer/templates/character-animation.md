# Animation Design Sheet — Character (non-combat)

Covers: idle, victory, defeat, emotes, talk, interact. Copy, fill every `<…>`,
delete the `>` guidance lines when done.

## Header

| Field | Value |
|---|---|
| Character | `<name>` (`<profile character key>`) |
| Clip | `<idle \| victory \| defeat \| emote_<name>>` |
| Direction / view | `<direction>`, `<view>` |
| Frame | `<W×H>`, feet row `<R>`, feet x `<X>` |
| Loop | `<cycle \| one-shot → hold last \| one-shot → loop>` |
| Engine (planned) | `<tool + mode>` — `<why; template breathing-idle / fight-stance-idle exist>` |

## Personality

> Idle and victory carry the character's personality more than any attack.
> Write 2–3 words for the attitude (e.g. "calm, guarded, proud") and one
> physical habit that shows it (sword resting on the shoulder, shifting weight,
> ears twitching). This is what makes two characters feel different.

Attitude: `<…>` · Habit: `<…>`

## Key poses

| Key | Name | Body mechanics |
|---|---|---|
| K1 | `<neutral / exhale>` | `<…>` |
| K2 | `<inhale peak / pose peak>` | `<chest up 1 px, shoulders, cape>` |
| K3 | `<optional: blink / habit>` | `<…>` |

## Frames

| f | Pose | Ticks | Event |
|---|---|---|---|
| 1 | | | |
| … | | | |

## Category guidance

| Clip | Frames | Notes |
|---|---|---|
| idle | 4 (6 with a blink) | 1 px breathing on the chest/shoulders, loose parts lag; 8–10 ticks; anything moving on a still body by 1 px back and forth reads as jitter unless it is the breath |
| victory | 4–8 | build-up into a held pose; the held frame must read at 1× |
| defeat | 6–8 | slump, kneel, head down; ends on a stable held frame |
| emote | 4–8 | one clear gesture; return to idle |

## Constraints (positive wording)

- Faces `<direction>`; camera locked; same size every frame.
- Feet planted on row `<R>` (idle/victory) unless the pose kneels.
- `<held item>` stays in the `<hand>`.
- Only the character; no effects.
- `<fix clauses>`

## Prompt Pack

## QA log

| Take | Job | Verdict | Crossed / not run | Fix applied |
|---|---|---|---|---|
| 1 | | | | |
