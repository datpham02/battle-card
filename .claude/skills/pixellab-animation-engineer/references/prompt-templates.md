# Prompt Templates

How to turn an Animation Design Sheet into PixelLab field values. Two layers:
the **structured brief** (complete, human-readable, kept in the design sheet)
and the **compiled fields** (what the chosen tool actually accepts).

## Writing rules

- **Physical motion, not adjectives.** "Shifts weight onto the back foot, pulls
  the sword back past the hip, steps forward with the front foot and cuts
  horizontally at chest height" beats "epic, dynamic, powerful slash".
- **No filler keywords** ("masterpiece", "high quality", "8k", "trending").
  They cost characters and change nothing.
- **Name body parts and sides consistently.** The character's own right/left
  (as the skeleton tools do). In profile and 3/4 views prefer **near/far**
  ("near foot", "far arm") when right/left is ambiguous.
- **State facing three ways:** the direction label, which body part points at
  the camera / screen edge, and "faces the same way in every frame".
- **Camera lock:** "camera does not move or zoom; the character stays the same size".
- **Start and end:** "starts from the idle pose" / "ends back in the idle pose"
  (or "ends holding the final pose").
- **Positive constraints.** The animation tools have no negative field, so write
  "the sword stays the same length", "only the character, no effects, no
  background", "the cape stays navy", not "no growing sword".
- **One motion per call.** A combo is several clips, or one clip whose
  description lists the hits in order with their frame ranges.
- **Identity recap verbatim.** Copy the profile's `identity_recap` exactly; do
  not paraphrase it differently from call to call.

## Structured brief (fill every heading)

```text
CHARACTER: <identity_recap from the profile, verbatim>
REFERENCE: <character id or anchor image>; keep its proportions, outline, palette and pixel size
ACTION: <category> — <gameplay purpose in one line>
KEY POSES:
  K1 <name>: <body mechanics: weight, hips/shoulders, hands/weapon, loose parts>
  K2 ...
FRAMES (n=<N>, ticks @60Hz):
  f1 <pose / change from previous> [ticks] [event]
  ...
TIMING: anticipation <a>% / action <b>% / follow-through <c>% / recovery <d>%; total <T> ticks
DIRECTION & VIEW: <direction label>, <view>; <which side faces the camera>; same facing every frame
SIZE: <frame WxH>, feet on row <R>, x <X>; generated canvas may be larger, cropped later
STYLE: same pixel size and outline as the reference; no anti-aliasing
PALETTE: <hex list or palette file>; no new colours
LOOP: <cycle | one-shot → idle | one-shot → hold last>
CONSTRAINTS: <positive constraints, incl. the fix clauses of earlier failed takes>
EXPORT: transparent background; <frames> frames; keep_first_frame <true/false>
```

## Compiling to tool fields

### `animate_character` mode `pixminimax` (stored character, custom motion)

| Field | From the brief | Limit |
|---|---|---|
| `action_description` | ACTION verb phrase + KEY POSES in order + the most important CONSTRAINTS, motion only | keep ≤ ~600 of 1000 chars; long text dilutes |
| `subject_description` | CHARACTER as one noun phrase | ≤ 300 |
| `initial_pose` | the pose of the start frame | ≤ 300 |
| `directions` | `[<direction>]` (one) | — |
| `frame_count` | N (multiple of 4) | 4–40 |
| `custom_start_frame_url` / `end_frame_url` | optional: pin start/end poses | single direction |
| `keep_first_frame` | false when frame 0 must not be the idle source | — |

Example (`action_description`):
> "Shifts weight onto the back foot and crouches slightly, pulling the sword
> back past the hip with both hands while the cape swings forward; steps forward
> with the near foot into a lunge and cuts horizontally to the right at chest
> height in one fast stroke, the body twisting with the cut; the blade
> overshoots past the front, the cape trails behind and settles; returns to the
> idle stance. Faces right the whole time, feet stay on the ground, the sword
> keeps the same length, only the character, no effects."

### `animate_character` mode `v3`

Same as above without `subject_description` / `initial_pose`; `frame_count`
4–16 even. Watch the canvas growth in the cost.

### `animate_character` mode `template` / `skeleton-v3` with a template

Only `template_animation_id` (+ `ai_freedom` for template). Choose the template
whose key poses match the sheet; there is no text to tune, so this is the
cheapest test of timing, not of style.

### `animate_character` mode `skeleton-v3` custom

1. Call with `action_description` and no `poses` → free instructions with this
   character's numbers.
2. Translate each FRAMES row into one pose object (pelvis, hips, chest, lean,
   head, hands, elbows, feet) or a `move` from the instructions; add held items
   with `poses`. 3–15 frames.

### `animate_image_pixminimax` (loose sprite)

| Field | From the brief |
|---|---|
| `description` | as `action_description` above (motion only) |
| `subject_description` | CHARACTER noun phrase |
| `initial_pose` | start pose |
| `direction`, `view` | DIRECTION & VIEW (always pass; the auto-caption may decline) |
| `first_frame_url` | the anchor frame (URL preferred) |
| `last_frame_url` | optional end pose (same size) |
| `frame_count` | N (multiple of 4) |
| `enhance_prompt` | per Phase 3 rule |

### `animate_with_skeleton_v3`

`description` = CHARACTER (appearance only), `action` = short label, motion =
`keypoints` built from FRAMES (18 joints per frame).

## Fix-clause slot

Append clauses from `animation-qa.md` at the **end** of the motion text under
the words "Most important:" so they override earlier wording. Keep at most 3;
if more are needed, the design (key poses) is probably wrong, not the wording.

## Prompt Pack output (manual mode)

For each call: tool name, mode, every field value as a copy-ready block, the
cost and the reason for the engine, then the QA command to run on the result.
