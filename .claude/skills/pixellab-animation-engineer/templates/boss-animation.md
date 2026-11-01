# Animation Design Sheet — Boss

Covers: boss tells, telegraphed attacks, phase changes, enrage, summons, big
deaths, and any custom boss move. Copy, fill every `<…>`, delete the `>`
guidance lines when done.

## Header

| Field | Value |
|---|---|
| Boss | `<name>` (`<profile character key>`) |
| Move | `<name>` — `<what it does in gameplay>` |
| Direction / view | `<direction>`, `<view>` |
| Frame | `<W×H>` (bosses may use a larger frame; record it), feet row `<R>` |
| Loop | `<one-shot → idle \| hold → loop (charging) \| one-shot → hold (phase change)>` |
| Engine (planned) | `<tool + mode>` — `<why>` |

## Fairness and readability

> A boss move is a contract with the player: the tell promises what comes and
> when. The tell must be a silhouette change unique to this move (players learn
> moves by shape), held long enough to react (≥ ~28 ticks before `hit`; longer
> for big damage), and the recovery after the attack is the punish window.

| Event | Frame | Tick | Use |
|---|---|---|---|
| tell start | `<f>` | `<t>` | telegraph on the board starts |
| hit / release | `<f>` | `<t>` | damage / projectile spawn |
| recovery end | `<f>` | `<t>` | boss can act again |

Tell → hit: `<n>` ticks (≥ 28). Punish window: `<n>` ticks.

## Key poses

| Key | Name | Body mechanics |
|---|---|---|
| K1 | Idle (menacing) | `<…>` |
| K2 | Tell (unique silhouette) | `<what changes: raised arm, coil, glowing weapon — glow as VFX>` |
| K3 | Attack | `<…>` |
| K4 | Overshoot / impact | `<…>` |
| K5 | Exposed recovery | `<visibly vulnerable: hunched, weapon down>` |

## Frames

| f | Pose | Ticks | Event |
|---|---|---|---|
| 1 | | | |
| … | | | |

## Category guidance

| Move | Frames | Notes |
|---|---|---|
| telegraphed attack | 8–16 | long held tell, short attack, long recovery |
| phase change / enrage | 8–12 | one-shot; ends in a new idle stance (may be a new state: `create_character_state`, 10–25 gen — ask) |
| summon | 6–10 | gather, raise, release; the summoned thing is a separate asset |
| boss death | 10–16 | longer than a normal death; big impact frame; last frame held |

## Constraints (positive wording)

- Faces `<direction>`; camera locked; same size every frame.
- The tell pose is held for `<n>` ticks (frames repeat via ticks, not duplicates).
- Only the boss; telegraph markers and glows are separate VFX.
- Reserved colours (`<telegraph colour, status colours>`) never appear in the body frames.
- `<fix clauses>`

## Prompt Pack

## QA log

| Take | Job | Verdict | Crossed / not run | Fix applied |
|---|---|---|---|---|
| 1 | | | | |
