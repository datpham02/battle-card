# Swordsman `cast_overhead` v2 — acting review and production proposal (NOT generated)

**Date:** 2026-11-08 · **For:** Ngàn Kiếm · **Status:** v1 (job ac2cb023) is in game as a placeholder and is NOT
approved as final. Option A chosen 2026-11-08 (conditional): the free frame migration and HUD checks are done (§7); K4 awaits approval (§8). Nothing in this document has been generated; every paid call waits for an explicit yes.

## 1. Review of the v1 clip (measured on the 9 cleaned frames, 96×70)

| Measure | v1 `cast_overhead` | approved `cast_forward` (reference) |
|---|---|---|
| Head top across the clip | y6–y10 (4 px of travel) | y8–y25 (17 px: a real crouch) |
| Anticipation (f1 head vs guard) | 1 px UP (no dip) | 1 px down, then a 17 px coil |
| Changed pixels f2→f3 | 33 % of the silhouette (near repeat) | — |
| Changed pixels f5→f6 | 19 % (near duplicate) | — |
| Slots 3 and 4 | the same image (f3 used twice) | f3 used twice too, but its coil is a strong pose |

Findings:
1. **Redundant poses:** f2 ≈ f3 (upright sword), f5 ≈ f6 (command point). With f3 reused for the hold, about 4 of the
   9 slots carry new information.
2. **Weak anticipation:** f1 rotates the sword to horizontal while the body stands still. There is no dip, no grip
   change and no shoulder wind-up.
3. **Missing body mechanics:** the torso, shoulders and head barely move (4 px); only the sword and forearms move.
   The cape moves only on the command frames.
4. **Insufficient summoning hold:** the "overhead" pose is the sword held upright in front of the face, hands at
   chest height. The blade, not the body, goes up. Its silhouette is closed (arms in, sword over the face).
5. **Weak command:** f5 swings the sword down-forward, but the torso does not follow (head y10, no lean). It reads
   as lowering the sword, not commanding.
6. **Abrupt recovery:** f7 → f8 changes 80 % of the silhouette in one 133 ms step; there is no settling frame.

## 2. Can the existing frames be fixed for free? No.

- **Frame selection / timing:** reordering, re-timing or bringing back raw f4 (a tilt in-between) smooths the motion,
  but adds no anticipation, no open overhead silhouette and no torso lean. Those poses do not exist in the raw set.
- **Mechanical edits** (the only edits allowed on generated sprites):
  - shifting the upper body 1–2 px could fake a dip;
  - they cannot rotate shoulders, raise the arms, open the silhouette or make the torso lean;
  - painting new limbs by hand is out (the user rejected hand-painted sprite details).
- **Conclusion:** the acting has to come from new generated key poses.

## 3. The real constraint: frame height

The Knight sheet frame is **96×70**, feet on row 69, head top at y8. The v1 blade already touched y0 (row 0 had to
be cleared). A true summoning pose (arms raised, both hands on the hilt above the head, blade pointing up) needs about
20–25 more rows above the head. **It cannot fit in 96×70**, whatever the generator does.

| Option | What | Cost / risk |
|---|---|---|
| **A. Taller Knight frame, 96×92 (recommended)** | Pad every Knight frame on top to 92 px (feet stay on the bottom row, so drawing is unchanged: units draw bottom-centre on the feet). Only `cast_overhead` uses the new rows. | Free, mechanical. Done in the exporter (`frame.h` 92; 70 px sources bottom-aligned at export), so source and candidate files stay byte-identical. Touches: `clips.json` `frame`, sheet size tests, and `cut_hud_view` (it places a pop above the head from the frame height; re-anchor it to the old 70). Top-row hero: the blade tip reaches about y10 (the HUD title band ends at y12): accepted for 0.3 s, or capped. |
| B. Stay 96×70 | "Overhead" becomes a roof guard: both hands above the forehead, blade horizontal or angled back. | No structural change, but the blade cannot point up, which misses the brief. |

## 4. Generation plan (for option A; each step needs its own yes, shown with its result)

PixMiniMax pins only the first and last frame. With both pinned to the same guard (v1), it produced a low-amplitude
in-and-out. **The fix is to pin the KEY POSES**: generate the summoning keyframe and the command keyframe first,
review them, then let PixMiniMax animate between them in three short segments.

| Step | Tool and call | Output | Cost |
|---|---|---|---|
| 1. Keyframe K4: summoning hold | `edit_image_pro_flash`, `method: "text"`, `image_url`: guard `cast_gesture/0` padded to 96×92 (data URL), `use_color_palette_correction: true`, `no_background: true`, `seed: 1`, description below | 1 image 96×92 | **5 gen** |
| 2. Keyframe K5: command | `edit_image_pro_flash`, same settings, source = guard padded, description below | 1 image 96×92 | **5 gen** |
| 3. Guard → K4 | `animate_image_pixminimax`, first = guard (96×92), last = K4, `frame_count: 4`, `direction: "south-east"`, `view: "low top-down"`, `seed: 1`, `enhance_prompt: false` | 4 in-betweens (dip, grip, lift, raise) | **1 gen** |
| 4. K4 → K5 | same, first = K4, last = K5, `frame_count: 4` | the command motion | **1 gen** |
| 5. K5 → guard | same, first = K5, last = guard, `frame_count: 4` | follow-through, recovery, settle | **1 gen** |
| **Total** | | about 15 candidate frames for the 9 slots | **13 gen** (2,174.9 left this cycle) |

After each step: mechanical clean only (palette snap, specks, feet re-plant), and a review sheet before the next
step. A failed keyframe stops the plan; a keyframe is not regenerated without a new yes.

**Prompts (motion and pose words only; positive phrasing, as PixMiniMax needs):**
- **K4 description:** "the same knight, feet planted in the same stance, standing tall with his back straight and chest
  open, both arms raised high, both hands gripping the sword hilt above his head, the blade pointing straight up at the
  sky, shoulders squared, chin raised, the cape hanging behind him"
- **K5 description:** "the same knight, feet planted in the same stance, leaning forward with his weight on the front
  leg, both hands on the hilt at waist height thrusting the sword forward and down toward the right, the blade pointing
  at the ground ahead, the right shoulder driven forward, the cape swinging out behind him"
- **Step 3 description:** "the knight bends his knees slightly and grips the sword with both hands, draws his shoulders
  back, then lifts the sword up past his face and raises it high overhead with both arms, ending tall with the blade
  pointing at the sky"
- **Step 4 description:** "the knight brings the raised sword down in one powerful commanding stroke, his torso and
  shoulders turning forward with the motion, ending leaning forward with the sword pointing at the ground ahead to the
  right"
- **Step 5 description:** "the knight holds the pointing pose for a moment, then draws the sword back toward his body
  and straightens up, settling smoothly back into the guard stance"

**Slot plan (same 9 slots and ms, so the cast timing data is unchanged):**

| Slot | 0 | 1 | 2 | 3 | 4 (held 200 ms + swing) | 5 (release, 50 ms) | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|---|
| Pose | guard | dip + grip (step 3) | lift (step 3) | raise (step 3) | **K4** | **K5** | follow-through (step 5) | recover (step 5) | guard |

If the cast reads better with a longer release, the ms can move within the same total (for example 50 → 83 on slot 5,
133 → 100 on slot 8). Slot 5 still starts at the swing end, so the authoritative schedule is untouched.

## 5. VFX link between the pose and the swords (proposal, free code, not built)

Everything stays on the existing clock: the hold runs during the swing (slot 4), the release is the swing end (t0),
and the swords already start materializing at t0.

1. **Summoning hold (slot 4, during the swing):** at `charge_hand` (the raised blade tip):
   - a small square ring of 4 steel squares turns in 90° steps around the tip;
   - fragments rise from the floor around the Knight and converge on it;
   - the ring tightens and brightens as the swing progresses (k 0 → 1), then a 3×3 core lights at k > 0.8.
   - Reduce motion: the ring holds still and fewer fragments show.
2. **Command (t0, 0.12 s):**
   - a directional flash: 3 stepped chevrons of light along the sword line from `hand` toward the centroid of the cast
     cells, replacing the current dotted streak for this card;
   - at the same instant, a thin vertical rise of squares from each target tile's top, as if the swords answer the
     call.
   - The materialize phase already starts at t0, so the swords visibly respond on the release frame.
3. **Unchanged:** shadows, sword timing, impacts, finale, shake and the gameplay schedule.

## 6. What happens next

1. You choose A (taller frame) or B (stay 96×70).
2. With A: I implement the free frame-height change, verify every Knight clip draws pixel-identical in battle, then ask
   for step 1 (K4, 5 gen) with its exact data URL.
3. Each later step is asked separately, after you have reviewed the previous result.

## 7. Option A: free preparation done (2026-11-08, user decision: A, conditional)

### 7.1 Frame height migration (96×70 → 96×92)

- **Exporter** (`tools/asset-pipeline/export_sheets.py`): a source frame of the unit's width but shorter is
  bottom-aligned into the cell, with transparent rows added on top. The top 1 px margin is checked on the source
  frame. An optional `body_h` is written to `meta.tessera.body_h` only for a unit that declares it, so every other
  unit's sheet stays byte-identical (verified: `git status` shows only `unit_kiem_si_sheet.*` changed).
- **`art_src/units/kiem_si/clips.json`:** `frame` 96×92, `body_h` 70. No source PNG changed.
- **`SpriteSheet.body_height()` / `body_rect()`:**
  - the floor-damage pop above the head (`CutHudView._pop_lift`) uses the 70 px body;
  - the character-select card and the save-slot portrait draw the bottom 70 rows, so they are not shrunk;
  - the world map draws by the feet (unchanged);
  - the battle draws bottom-centre on the feet (unchanged).
- **Sheet:** 872×1394 (was 872×1064).

### 7.2 Compatibility evidence (`production/qa/evidence/skill-v2-ngan-kiem/frame-92/`)

- `tools/qa/sheet_pad_compare.gd`, old vs new sheet: **101 frames checked, 0 differ; padding fully transparent.**
  Each new cell's bottom 70 rows equal the old cell pixel for pixel. That covers every Knight clip, Trảm Địa's
  `cast_forward` included.
- Real battle, same seed and command, every frame of a 1280×720 capture compared before vs after:

  | Scene | Frames | Differing frames |
  |---|---|---|
  | Ngàn Kiếm plus5 (`cast_overhead` v1, idle, hit) | 210 | **0** |
  | Trảm Địa bar4 (`cast_forward`) | 210 | **0** |
  | Thiết Kiếm bar4 (`cast_gesture`) | 210 | **0** |
  | plain match (draw, idle, steps) | 360 | every frame differs, ONLY in the floor pickup at (310,268)–(381,429): that match spawns its pickup piece unseeded (a different random piece shape each run). The Knight pixels are identical. |

- **Anchors:** feet stay on the bottom row (padded source: feet row 91, x32–38). `body_rect` keeps the bottom row
  (`sprite_sheet_test`).

### 7.3 Top-row HUD clearance (`frame-92/hud-clearance-top-row-2x.png`)

- **Setup:** Knight on each top-row cell, columns 0–3 (`--demo=board --player-cell=c,0`), at 1280×720. Feet at art
  y 101 = screen y 202 (art → screen: x·2 − 160, y·2).
- **HUD as drawn:**
  - player panel 0,0–260,42;
  - title text 420,0–860,22;
  - relic strip 12,48–260,76;
  - status row 12,82–260,122;
  - gold and pause at the far right;
  - boss status from x 674.
- **Envelopes** (`tools/qa/hud_clearance.gd`, min gap 12 screen px = 6 art px):

  | Envelope (art px from the feet) | Col 0 | Col 1 | Col 2 | Col 3 |
  |---|---|---|---|---|
  | Full overhead: blade straight up, tip at the 92 frame top (x −10..6, y −91..−62) | **overlaps the player panel by 20** | clear, 38 | **touches the title (−2)** | **touches the title (−2)** |
  | **K4 target: blade tilted forward, tip ≤ 20 px above the head (x +6..+20, y −82..−62)** | clear, 12 | clear, 16 | clear, 16 | clear, 16 |

- **Decision for K4:** the summoning pose keeps both arms raised and both hands on the hilt above the head. The
  blade points UP and tilts slightly FORWARD (toward the battlefield). Its tip stays within 20 px above the head
  top, in front of the face. This is a limited-scope fit; the HUD is unchanged. The straight-up pose cannot clear the
  title or the HP panel on the top row.
- **Pre-existing, not caused by this change:** on column 0 the current 70 px Knight body already overlaps the left
  HUD column (relic strip, status row) horizontally when those strips show.
- **Fallback, if a generated K4 still breaks the envelope:** a separate code-drawn layer for the raised blade. It is
  not needed with the target above.

## 8. K4 summoning keyframe: exact call (awaiting approval; nothing generated)

| Field | Value |
|---|---|
| Tool | `mcp__pixellab__edit_image_pro_flash` (schema checked: `image_url` data URL, `method` text, `description`, `no_background`, `use_color_palette_correction`, `seed`) |
| Source | `design/assets/candidates/swordsman/cast-overhead-v2/source/guard_96x92.png`: `cast_gesture/0` bottom-aligned, **96×92** (multiple of 4, as Pro Flash edit requires; checked 96×92 is a valid custom size), feet row 91 x32–38, 7 colours, 0 off-palette |
| `method` | `"text"` |
| `use_color_palette_correction` | `true` (snaps to the source colours) |
| `no_background` | `true` |
| `seed` | `1` |
| Cost | **5 generations** (quoted by `get_pro_flash_capabilities`, edit 96×92: image 5, total 5); 2,174.9 left |
| Output | `design/assets/candidates/swordsman/cast-overhead-v2/k4/raw.png`, then a mechanical clean to `k4/clean.png` |

**`description`** (pose words, positive phrasing):

> "the same knight with the same face, hair, steel armour, navy tabard with a gold cross, navy cape with gold trim and
> the same sword, both feet planted in exactly the same place; he stands tall with his back straight and chest open,
> both arms raised above his head, both hands gripping the sword hilt together just above his head, the blade pointing
> up and tilted slightly forward toward the right, its tip a little above his head, shoulders lifted and squared, chin
> raised, the cape hanging behind his legs"

**Acceptance checklist (K4 is reviewed against this before anything else is asked):**
1. 96×92. The feet on the bottom row at x32–38, or fixable by a whole-frame translate of at most 3 px.
2. Both arms raised, both hands on the hilt above the head. The torso is straight and the silhouette is open (arms
   clear of the face).
3. The blade points up, tilted slightly forward. Its tip is inside the K4 envelope: frame y ≥ 10, frame x 54–68.
4. Identity kept: face, hair, steel-blue plates, navy tabard and cape with gold trim, the same sword, chibi
   proportions, 1 px outline.
5. 7 sheet colours after the palette snap, no stray clusters, no baked glow or effects.
6. **If it fails:** stop and report. No retry without a new yes. K5 and the in-betweens are not asked until K4 is
   accepted.

## 9. K4 result (2026-11-08): generated once, NOT accepted yet (review below; no retry made)

- **Pre-check:** complete suite rerun **209/209 green**, 0 script errors, golden unchanged.
- **Call:** exactly as in §8. The first attempt with an inline data URL was rejected before generating (the base64
  was corrupted in transit; the balance was unchanged at 2,174.9). The same image was then sent by upload
  (`upload:55f446d5…`).
- **Job:** `d6efd0e3-47b1-4bec-8255-83b6d9515c48`, image `aab303cd-25b7-51af-b2c3-667b0b9be457`.
- **Cost: 5 generations** (2,174.9 → 2,169.9).
- **Files (`design/assets/candidates/swordsman/cast-overhead-v2/k4/`):**
  - `raw.png`;
  - `clean.png` (palette snap: 1 off-palette colour #dbc8aa snapped; 0 speck px dropped; whole-frame shift +3 px x so
    the feet land on x32–38);
  - `compare_guard_raw_clean_x6.png`;
  - `hud_clearance_top_row_k4_2x.png`.

| Criterion | Result |
|---|---|
| 1. Feet anchoring | **PASS.** Raw feet on row 91 at x29–35; one whole-frame shift of +3 px puts them on x32–38. No other edit. |
| 2. Pose quality | **PARTIAL.** Both arms raised and both hands on the hilt above the head: yes. But the blade comes out at about 30° above horizontal, pointing far forward-right, so it reads as a high two-handed guard, not "blade up, tilted slightly forward". The silhouette is open at the chest, but the arms frame the face closely. |
| 3. Body acting | **PASS with a drift.** Chest open, shoulders lifted, stance tall and planted, clearly different from the guard. But the body turned from the 3/4 south-east view toward a near-frontal view. |
| 4. HUD safety | **PARTIAL.** Columns 1–3: clear of the title by 12 px, exactly the minimum. Column 0: the raised elbow and arms reach x −12 from the feet, overlapping the HP panel / relic strip area. The tip is at 84 px above the feet, 2 px higher than the target zone, and 25 px forward of the feet, 5 px beyond it. |
| 5. Identity | **FAIL.** The hair lost its spiky silhouette (it reads as a pale cap behind the arms), and the face is larger and flatter. The armour, tabard with its cross, cape and gold trim, and sword are kept. |
| 6. Pixel quality | **PASS.** 6 colours, all in the sheet palette; no stray pixels; no baked VFX; hard pixel edges, no anti-aliasing. |

**Verdict:** K4 does not meet the bar (identity fails; pose and HUD are partial). It is kept as a candidate only; K5
and the in-betweens are not started. Options are listed in the report to the user; each needs a new yes.

## 10. K4 v3: pose redesign (2026-11-08, free study; no PixelLab call)

K4 v2 is rejected and kept for reference only (`k4/raw.png`, `k4/clean.png`, untouched). Its raised-arm idea is the
only thing reused; its frontal torso, arm placement and head are not.

### 10.1 Measured guard geometry (identity source, 96×92 frame, feet on row 91, frame x 48 = the feet)

- Head and hair: x 42–59, y 28–43.
- Shoulders: left (far) about (40, 46), right (near) about (57, 47).
- Sword: about 36 px hilt to tip (crossguard + blade ≈ 31 px beyond the hands; grip + pommel ≈ 5 px behind).

### 10.2 Layout study (free; flat shapes on the real guard body: NOT art)

- **Tool:** `scratchpad pose_layout.gd`.
- **Method:**
  - keeps the guard's real head and body below the shoulders;
  - erases the guard's lowered blade where it stands clear of the body (a short stub over the hip remains: a
    mockup artefact);
  - draws the raised arms, hands and a full-length sword as flat shapes;
  - tests EVERY part (head and hair, far forearm, near forearm, hands, whole sword, torso and cape) against the
    drawn HUD with the Knight on each top-row cell (min gap 12 screen px).
- **Files** (`design/assets/candidates/swordsman/cast-overhead-v2/k4v3-layout/`):
  - `k4v3_pose_comparison_x4.png` (guard / K4 v2 rejected / C1 / C2 / C3);
  - `k4v3_hud_top_row_2x.png` (each candidate pasted on the four top-row shots, HUD in red; the shots' own Knight
    shows behind the paste).

| Candidate | Hands (frame px) | Blade angle | Sword top in frame | Columns 1–3 (worst part) | Column 0 |
|---|---|---|---|---|---|
| C1: hilt above the head (as requested) | (63, 25) | 60° | **tip at y −2: leaves the 92 frame** | **sword overlaps the title by 12 px** | new parts clear (sword 20, hands 24) |
| **C2: hilt at the temple, right of the face (recommended)** | (63, 37) | 56° | tip at y 11 | **all parts clear; nearest is the sword, 14 px from the title** | new parts clear (sword 20, hands 24, near forearm 14) |
| C3: hilt above the head at the HUD's maximum angle | (63, 25) | 29° | tip at y 10 | sword 10 px from the title / 7 from the boss panel (too close) | new parts clear |

- **Column 0, every candidate and the current guard alike:** the head, the far shoulder and the torso overlap the
  status row / relic strip column (x ≤ 260). This is the existing 70 px body standing on that cell, not the new pose.
  The new parts (hands, near forearm, sword) clear the HUD there.

### 10.3 The conflict, stated plainly

- With the hilt ABOVE the head (y ≈ 25), a 55–65° blade of the true length rises about 26 px higher. Its tip
  leaves the 96×92 frame and covers the title on the top row's columns 1–3.
- Keeping the hilt above the head and 12 px from the title caps the blade at about 29°. That is the high guard you
  rejected (C3).
- Hiding the blade under the HUD or clipping it is out, as you said. A separate sword layer would only let the
  blade leave the frame; it would still cover the title.
- The only free-of-HUD way to keep the steep 55–60° diagonal and the full sword length is to lower the grip to
  temple height, just right of the face (C2). The forearms rise on both sides of the head: the near arm up the right
  cheek, the far arm behind the head, with the elbows lifted and out. The face and the hair stay clear.
- **Rejected alternative:** a row-specific pose (C1 off the top row, C2 on it) would need two keyframes, a taller
  frame and two code paths.

### 10.4 K4 v3 pose specification (C2)

- **Orientation:** the original south-east 3/4 view (the torso turned like the guard, the tabard cross on the
  near side, the cape behind).
- **Legs:** both feet on the guard's spots (x32–38 front, the back foot as in the guard); knees slightly bent, weight
  low and even.
- **Torso:** tall and stable, chest open toward the camera's right, shoulders lifted and squared, chin up.
- **Head:** the guard's head, unchanged in shape and size: face, eyes and spiky silver hair silhouette fully visible.
- **Arms and hands:**
  - both hands together on the hilt, held just right of the head at temple height (frame ≈ (63, 37));
  - the near (right) forearm rises beside the cheek;
  - the far (left) forearm reaches up behind the head;
  - the elbows are raised and out.
- **Sword:** the original sword at full length (≈ 36 px), angled 55–58° above horizontal, pointing up and forward to
  the upper right (toward the enemy half). The tip ends near frame (80, 11).
- **Cape:** navy with gold trim, hanging behind the legs, as in the guard.
- **Read:** a commander raising his sword as a beacon toward the battlefield; an active, open, upward diagonal. Not
  a high guard (blade too flat) and not an upright salute in front of the face (v1).

### 10.5 Generation methods compared (tool capabilities checked)

| Method | Tool and cost | Identity / 3/4 view | Body mechanics | HUD control | Verdict |
|---|---|---|---|---|---|
| A. Inpaint K4 v2 | `inpaint_image_pro_flash` (mask + optional 1 reference, 96×92), 5 gen per call | Could restore the head, but the frontal torso and the arm frame around the head stay. Fixing them means masking most of the body: a full regeneration in all but name. | Inherits v2's frontal stance | Arms and blade are v2's, which are out of the C2 zone | **Not recommended.** It keeps the composition that failed. |
| B1. New Pro Flash edit from the padded guard | `edit_image_pro_flash` text (or `reference` with 1 image), 96×92, 5 gen | Text-only edit is what produced v2's frontal turn and lost hair. A reference only steers appearance, not pose. | Pose follows the text loosely | Weak (single image, no control over the angle) | Possible, but the same risk as v2 |
| **B2. New PixMiniMax animation from the padded guard (recommended)** | `animate_image_pixminimax`, first frame = padded guard, open-ended (no last frame), 8 frames, 96×92 is in the ≤128 tier: **1 gen** | Best: the video model kept the face, the hair, the 3/4 view and the cape in all 9 v1 frames. | The motion itself gives the anticipation and the raise; v1's flatness came from pinning BOTH ends to the guard, which this call does not do. | Medium: the end pose is picked from 8 frames and measured against the C2 zone. The earlier frames are K1 / K2 candidates at no extra cost. | **Recommended:** cheapest (1 gen vs 5), best identity, and it also yields the anticipation frames. |

### 10.6 Exact proposed call (B2; NOT run)

| Field | Value |
|---|---|
| Tool | `mcp__pixellab__animate_image_pixminimax` (schema checked: frame counts in multiples of 4; frames up to 256 px; 96 px longer side billed at the 128 tier: 4–8 frames = 1 gen; returns frame_count + 1 images, index 0 = the input) |
| `first_frame_url` | `upload:<id>` of `design/assets/candidates/swordsman/cast-overhead-v2/source/guard_96x92.png` (uploaded fresh before the call; an inline data URL was corrupted last time) |
| `last_frame_url` | none (open end, so the pose can complete) |
| `frame_count` | `8` |
| `direction` / `view` | `"south-east"` / `"low top-down"` |
| `subject_description` | "a small pixel-art knight with short spiky silver-blond hair, steel plate armour, a navy tabard with a gold cross and a navy cape with gold trim, holding a straight steel sword" |
| `initial_pose` | "standing in a ready guard stance, the sword held low in the right hand and angled down to the front, the left fist raised in front of the chest" |
| `description` | "the knight bends his knees slightly and takes the sword hilt in both hands, then lifts the sword up along his right side and raises it beside his head, both hands on the hilt at the height of his temple just to the right of his face, elbows raised and out, the blade angled up and forward toward the upper right, his chest opening and his shoulders lifting as he straightens tall, then he holds that raised summoning pose steady; both feet stay planted on the same spot" |
| `seed` / `no_background` / `enhance_prompt` | `1` / `true` / `false` |
| Cost | **1 generation** (2,169.9 left) |
| Output | `design/assets/candidates/swordsman/cast-overhead-v2/k4v3/raw/f0–f8.png`; mechanical clean only (palette snap, specks, whole-frame feet shift) |

### 10.7 K4 v3 acceptance criteria (the chosen frame among f1–f8)

1. **Feet:** on the bottom row at x32–38 (the back foot as in the guard). Only a whole-frame shift is allowed to fix
   them; no vertical bob between the chosen frames.
2. **View:** the 3/4 south-east view is kept: the torso is not turned frontal, the tabard cross is on the near side,
   the cape is behind.
3. **Identity:** the face shape and size, the eyes and the spiky silver hair silhouette match the guard. Nothing
   covers the face or hair.
4. **Grip and arms:** both hands on the hilt, at temple height and right of the face; the forearms rise on both sides
   of the head; the elbows are lifted.
5. **Sword:** the original design and length (35 ± 3 px), angled 50–62° up and forward.
6. **HUD:** every part of the frame passes `pose_layout`'s check on all four top-row columns: ≥ 12 px on columns
   1–3, and nothing new beyond the existing body on column 0. The top of the sword is at frame y ≥ 9.
7. **Acting:** chest open, shoulders up, tall stable stance; clearly a summoning command, not a salute or a high
   guard.
8. **Pixels:** the 7 sheet colours after the snap, no stray clusters, no smear or baked VFX, no blur.
9. **If no frame passes:** stop and report. No retry without a new yes. K5 and the in-betweens are not started.

## 11. K4 v3 result (2026-11-08): ONE PixMiniMax call, REJECTED

- **Call:** exactly §10.6. The source was sent as `upload:f5e78816…`, not an inline data URL; this is a transport
  detail, not a parameter change.
- **Job:** `a99c7f3b-4077-435a-959b-64851456ebb7`.
- **Cost: 1 generation** (2,169.9 → 2,168.9).
- No retry, no inpaint, no other paid call.
- **Files (`design/assets/candidates/swordsman/cast-overhead-v2/k4v3/`):**
  - `raw/f0–f8.png`;
  - `raw_sheet_x4.png`;
  - `chosen_f6_raw_uncleaned.png`;
  - `hud_clearance_top_row_f6_2x.png`.
- **What the motion did:**
  - f1 is still the guard;
  - f2 turns the Knight front-facing;
  - f3 swings the sword up to the LEFT;
  - f4–f8 settle into a two-handed raised sword with the body turned to face south-WEST (the cape now hangs on the
    screen-right side) and the arms crossing in front of the face.
  - No frame keeps the 3/4 south-east view while raising the sword.
- **Best candidate:** f6, the strongest summoning read of f4–f8. It was not cleaned: it already uses the 7 sheet
  colours, and no whole-frame shift can restore the anchor, because the stance itself changed.

| Criterion (f6) | Result |
|---|---|
| Feet anchor | **FAIL.** The stance changed: the bottom-row foot moved to x55–60 (was x32–38) and the other foot lifted. A whole-frame shift cannot restore it. |
| 3/4 south-east orientation | **FAIL.** Turned to face south-west (cape on the right, tabard turned left). |
| Face and hair preserved | **FAIL.** The hair silhouette is kept, but the forearms cross in front of the face. |
| Both hands on the hilt at temple height | **PARTIAL.** Both hands are on the hilt, but on the LEFT of the head, above the brow, not right of the face. |
| Sword angle (target 50–62° up-forward) | **FAIL.** About 45°, from a hilt above the head. |
| Full sword length | **PASS.** The original sword at full length. |
| HUD, all 4 top-row cells | **FAIL.** The sword reaches frame y 1 (screen y 20). Column 0 overlaps the left HUD column by 26 px; column 1 is 10 px from the title (min 12); columns 2–3 touch the title (−2). |
| Pixel quality | **PASS.** 7 sheet colours, no stray pixels, no smear or baked VFX (f2, f3 and f8 carry off-palette colours; f6 does not). |
| Summoning read | **PARTIAL.** A raised two-handed sword reads as powerful, but it faces away from the battlefield (south-west). |

**Verdict: REJECTED.** No frame passes all criteria; identity (view, face) and HUD safety fail. K5 is not
started. No further paid call is proposed automatically.

