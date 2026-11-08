# Swordsman `cast_forward` clip — specification (NOT generated)

**Date:** 2026-11-08 · **For:** Trảm Địa (`tram_dia`) and later Knight ground-wave cards · **Status:** spec only.
Every paid generation waits for the user's explicit yes, call by call (memory: PixelLab generation workflow).

## 1. Why

- **The problem:** `cast_gesture` (9 frames, `art_src/units/kiem_si/clips.json`) reads as a rising upward cut, while
  Trảm Địa's wave skims the floor toward the enemy half.
- **What the clip must show:** a low, heavy, forward two-handed drive, so the release clearly pushes the wave along
  the ground.
- **What already works:** the release timing (`cast/index.json` `gesture_hold_frame` 4 → slash frame 5,
  `gesture_lead_sec` 0.03, travel 0.15 s) lands the wave exactly on the burst event. The new clip only changes the
  pose, not the timing.

## 2. Hard constraints (match the existing sheet)

- **Frame and anchor:**
  - Frame 96×70, facing right, feet on the bottom row, feet x = 48, the same anchor as every Knight clip.
  - The unit stays on its cell: no frame moves the feet.
- **Frame count and timing:** 9 frames with the **same ms as `cast_gesture`**:

  | Frame | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
  |---|---|---|---|---|---|---|---|---|---|
  | ms | 83 | 83 | 83 | 83 | 200 | 50 | 83 | 100 | 133 |

  Frame 4 is held during the swing telegraph, frame 5 is the release. The cast index timing stays valid unchanged.
- **Colours and canvas:**
  - Palette: the 8 sheet colours (steel #8FA3B8 / #EEF4FA / #5F6F82, ivory trim, blond, cape, ink #1B1722).
  - No glow, no smear and no baked effect: the release VFX is drawn by the game.
  - 1 px margin to every canvas edge in all frames.
- **Hand point:** frame 5 must put the blade tip low and forward, about **(+22, −20) art px** from the feet (today's
  `hand` is (14, −34)). Update `cast/index.json` `square_wave_steel.hand` only after the clip is approved.

## 3. Key poses

| # | Pose |
|---|---|
| 0 | guard (identical to the guard anchor) |
| 1–2 | sword drops to the right hip, both hands on the grip, knees bend |
| 3 | weight shifts back, blade low behind, point down toward the floor |
| **4** | **coil (held):** crouched, blade low and drawn back, shoulders turned away |
| **5** | **release:** lunge forward, the front knee over the toes, the blade swept flat and low to the front at knee height, arms fully extended |
| 6–7 | follow-through: the blade stays low and forward, the cape trails |
| 8 | back to guard (identical to frame 0) |

## 4. Generation plan (requires approval per call)

| Step | Tool | Input | Cost |
|---|---|---|---|
| 1 | `animate_image_pixminimax` | first and last frame pinned to the guard anchor; 8 frames; south-east; positive motion text (below) | 1 gen |
| 2 | free | palette snap, speck clean and recentre (`art_src` pipeline), pick 9 frames and order them as §3 | 0 |
| 3 | optional retry | only if frame 5 does not read low and forward; one re-run, never a loop | 1 gen |

Motion prompt (positive wording only, memory "PixMiniMax: no negative words"):

> "the knight lowers the sword to the hip with both hands, crouches and draws the blade back low, then lunges forward
> and sweeps the blade flat at knee height toward the right, holds the low forward reach, then returns to the guard
> stance, feet stay planted on the same spot"

## 5. Acceptance

- Silhouette test at 1× (640×360): the frame 5 blade is below the belt line and in front of the body.
- Feet x = 48 and the bottom row are the same in all 9 frames; margins ≥ 1 px; only the 8 palette colours.
- In game (`--demo=tram_live`), the release frame lines up with the wave leaving the hand; the wave starts from the
  new hand point.
