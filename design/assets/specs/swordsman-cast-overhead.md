# Swordsman `cast_overhead` clip — specification + PixelLab plan (NOT generated)

**Date:** 2026-11-08 · **For:** Ngàn Kiếm (`ngan_kiem`) · **Status:** GENERATED + INTEGRATED 2026-11-08 (job ac2cb023, 1 gen; see the 07 report §11), awaiting approval. Before that, Ngàn Kiếm cast with the
shared `cast_gesture` as a fallback. Every paid generation waits for the user's explicit yes, call by call.

## 1. Intent

A summoning and commanding gesture, distinct from Trảm Địa's low forward `cast_forward`. The Knight does not strike
with his own weapon:

1. guard;
2. the sword rises overhead in both hands;
3. the body straightens and the upright sword is the summoning focus (held);
4. a decisive downward or forward commanding sweep releases the blades;
5. back to guard.

## 2. Constraints (same conventions as `cast_forward`)

- **Frame and anchor:**
  - Frame 96×70, facing right (south-east 3/4), feet on row 69 at x32–38 (the guard anchor), anchor x = 48.
  - No frame moves the feet.
- **Timing:** 9 slots with the cast timing of `cast_gesture` / `cast_forward`:

  | Slot | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
  |---|---|---|---|---|---|---|---|---|---|
  | ms | 83 | 83 | 83 | 83 | 200 | 50 | 83 | 100 | 133 |

  Slot 4 is held during the swing telegraph: the sword held upright. Slot 5 is the commanding release, at the moment
  the blades start to materialize (the swing end).
- **Colours and canvas:**
  - Palette: the 7 sheet colours (`1b1722 8fa3b8 d8cdb0 5f6f82 e3b99a b8893a 34406e`); navy cape with gold trim.
  - 1 px margins; no baked effects.
- **Hand points:** after cleanup, measure `charge_hand` (the hands on the upright hold, where the summoning squares
  gather) and `hand` (the release point). They go into `cast/index.json` `card_casts.ngan_kiem` with
  `clip: cast_overhead`.

## 3. PixelLab call A (needs approval)

Checked 2026-11-08 against the real source and the tool schema:
- `cast_gesture/0.png` is 96×70, guard stance facing right: sword LOW in the right hand pointing down-forward, left
  fist raised (the earlier draft said "held at chest height"; corrected below).
- `animate_image_pixminimax`: frame counts are multiples of 4; a 96 px longer side is billed in the 128 tier, where
  4–8 frames = 1 generation. Returns frame_count + 1 images (index 0 = the input).
- Same call shape as the approved `cast_forward` job 5e5e14ed (first and last frame pinned to this guard).
- Prompt has positive motion words only (no "no / without" phrasing: PixMiniMax painted the negated thing on the Mage).
- Lesson from `cast_forward`: a fast "sweep" baked a smear into one frame, so the release is worded as a firm
  lowering to a held pointing pose.

| Field | Value |
|---|---|
| Tool | `mcp__pixellab__animate_image_pixminimax` |
| `first_frame_url` | data URL of `art_src/units/kiem_si/cast_gesture/0.png` (the guard anchor, 96×70; the same source as `cast_forward`) |
| `last_frame_url` | the same file (returns to guard) |
| `frame_count` | `8` (returns 9 images: input + 8, the last pinned to guard) |
| `direction` / `view` | `"south-east"` / `"low top-down"` |
| `subject_description` | `"a small pixel-art knight with short silver-blond hair, steel plate armour, a navy tabard with a gold cross and a navy cape with gold trim, holding a straight steel sword"` |
| `initial_pose` | `"standing in a ready guard stance, the sword held low in the right hand and angled down to the front, the left fist raised in front of the chest"` |
| `seed` / `no_background` / `enhance_prompt` | `1` / `true` / `false` |
| `description` | "the knight brings the sword up with both hands and raises it straight above his head, blade pointing at the sky, straightens his body and holds it high like a beacon, then lowers it in one firm commanding motion to point forward and down toward the right, holds that pointing pose for a beat, then settles back into the guard stance; both feet stay planted on the same spot" |
| Cost | **≤ 1 generation** (96 px longer side: under the 128 tier; 8 frames = 1) |

**Afterwards (free, mechanical only):**
- `tools/qa/sprite_clean.gd`: palette snap, specks, feet re-plant.
- `tools/qa/sprite_recolour_region.gd`: only if the cape turns gold again.
- Map the generated frames to the 9 slots: guard, rise, rise, overhead, overhead (held), release, follow, follow,
  guard. Drop a smeared frame if one appears.

**Outputs:**
- `design/assets/candidates/swordsman/cast-overhead/{raw,clean-96x70}/`
- `art_src/units/kiem_si/cast_overhead/0–8.png`
- `clips.json`, `unit_kiem_si_sheet`
- `sheet_export_test` + `sprite_sheet_test` rows

## 4. Acceptance

- **Anchor:** feet x32–38 on row 69 in all 9 slots; no slide in continuous playback.
- **Pose:** the slot 4 sword is above the head and upright; the slot 5 sword points down or forward (a command, not a
  hit).
- **Look:** the Knight's proportions, armour, navy cape and sword are kept; 0 off-palette colours.
- **In game:** the summoning squares gather at the raised sword; the blades start to appear at the release frame.
