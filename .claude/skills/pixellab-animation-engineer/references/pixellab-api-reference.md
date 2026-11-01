# PixelLab API Reference (animation subset)

**Verified:** 2026-11-01 against (a) the live PixelLab MCP tool schemas and
(b) the official docs: `https://api.pixellab.ai/v2/openapi.json` (the
`/v2/docs` page is a JS shell) and `https://api.pixellab.ai/mcp/docs`.
**Rule:** the live tool schema wins over this file. When they disagree, use the
schema, tell the user, and add a line to the changelog at the bottom.
Items marked **[UNVERIFIED]** were not confirmed in either source: do not rely on
them without checking.

## 0. Access and security

- MCP server `https://api.pixellab.ai/mcp`, HTTP API `https://api.pixellab.ai/v2`.
  Both take the same token as `Authorization: Bearer <token>`.
- MCP: the client already holds the token. Never ask the user to paste it into chat.
- HTTP-only calls (Section 6): read the token from the `PIXELLAB_API_TOKEN`
  environment variable inside the command; never write it to a file, print it,
  or put it in a URL.
- Character/object ZIP and spritesheet download URLs need no auth (the UUID is
  the key): do not publish them.
- All generation is async: a call queues a job; `wait_for_jobs` (free) waits;
  `get_image` / `get_character` / `get_object` fetch results. `cancel_job` on a
  queued job is not charged; a running one may be.

## 1. Which tool for which job

| Situation | Tool / mode | Why |
|---|---|---|
| Stored PixelLab character, a standard humanoid motion that has a template | `animate_character` mode `template` | cheapest (1 gen/dir up to ~92 px), skeleton-driven, fixed frame count |
| Stored character, custom motion, sprite ≤ ~64 px | `animate_character` mode `v3` | cheap re-rolls at small sizes, 4–16 frames |
| Stored character, custom motion, sprite ≥ ~96 px or > 16 frames | `animate_character` mode `pixminimax` | priced by canvas steps, 4–40 frames, cheap at large sizes |
| Stored humanoid, identity/colour drift is the problem | `animate_character` mode `skeleton-v3` | moves the drawn character instead of redrawing it; template clip or your own poses |
| Loose sprite (not a PixelLab character, or the local frame was edited after generation) | `animate_image_pixminimax` (or `animate_image` for ≤ 16 frames) | works from any PNG; pin the end with a last frame |
| Exact poses needed (a rig, a pose you can describe joint by joint) | `animate_with_skeleton_v3` | 3–15 frames, 18 COCO joints per frame |
| A prop / object | `animate_object` mode `v3` | objects have no skeleton |
| Same character, different outfit or state first | `create_character_state` (10–25 gen) | keeps identity; expensive |

**Quality escalation** (official): template → v3 → pixminimax. Delete the bad
animation (`delete_animation`) before retrying on a stored character.
Use skeleton-v3 when the motion is right but identity/colours drift.

## 2. `animate_character` (MCP) / `POST /characters/animations` (HTTP)

Required: `character_id`. Modes (auto: `template` if `template_animation_id`, else `v3`):

| Field | Modes | Notes |
|---|---|---|
| `mode` | all | `template` \| `v3` \| `pixminimax` \| `skeleton-v3` (HTTP also has legacy `pro`, 10–25/dir) |
| `template_animation_id` | template, skeleton-v3 | ids below; unknown ids are refused before queueing |
| `action_description` | v3, pixminimax | **motion or pose only**, no locations or objects |
| `frame_count` | v3: 4–16 even; pixminimax: multiple of 4, 4–40; custom skeleton-v3: 3–15 | ignored by template |
| `directions` | all | template defaults to all directions; custom modes default to `["south"]` — always pass it |
| `custom_start_frame_url` / `_base64` | v3, pixminimax | single direction only; prefer URL (MCP truncates long base64) |
| `end_frame_url` / `_base64` | v3, pixminimax | enables interpolation toward that pose; same size as start; single direction |
| `keep_first_frame` | v3, pixminimax | default true: the source frame is stored as frame 0 (so 8 requested = 9 stored) |
| `subject_description` | pixminimax | noun phrase, 1–300 chars; fill it when a job fails saying the AI declined |
| `initial_pose` | pixminimax | 1–300 chars: the pose the first frame is in |
| `ai_freedom` | template | 0–900 (MCP), default 0 = rigid template. HTTP range 0–1000 **[UNVERIFIED]** |
| `animation_group_id` + `animation_name` | all | append directions to an existing group; re-pass the name (not inherited); an existing direction → 409 |
| `poses`, `move`, `scale` | skeleton-v3 custom | call once with `action_description` and no `poses` → free instructions; then call with `poses` |

**Costs (generations per direction):**
- template: 1 up to ~92 px canvas; larger canvases bill in batches (e.g.
  `jumping-1` 9 frames: 3 at 128 px, 5 at 180 px, 9 at 256 px). The submit
  receipt states the ceiling.
- v3: `ceil(w × h × frames / 65536)` on the **generated** canvas, which grows
  past the sprite (a 96 px character often animates at ~132 px → bills 3 at 8 frames).
  Limit: w × h × frames ≤ 8 × 256 × 256.
- pixminimax: by upscaled canvas (×4 up to 64 px, ×2 up to 128 px, ×1 above).
  At 64/128/256: 4–8 frames = 1, 12–16 = 2, 20–24 = 3, 28 = 4, 32–36 = 5, 40 = 6.
  Four pixels over a step is much cheaper on long clips (40 frames: 6 at
  128×128, 2 at 132×132). Several 8-frame calls cost less than one long one.
- skeleton-v3: 3 frames = 2, 4–14 = 3, 15 = 4.
- `enhance_prompt` (where offered): +0.05.

**Template ids (frames):** `backflip` (10), `breathing-idle` (4),
`cross-punch` (6), `crouched-walking` (6), `crouching` (5), `drinking` (6),
`falling-back-death` (7), `fight-stance-idle-8-frames` (8), `fireball` (6),
`flying-kick` (6), `front-flip` (6), `getting-up` (5), `high-kick` (7),
`hurricane-kick` (4), `jumping-1` (9), `jumping-2` (8), `lead-jab` (3),
`leg-sweep` (7), `picking-up` (5), `pull-heavy-object` (6), `pushing` (6),
`roundhouse-kick` (7), `running-4-frames` (4), `running-6-frames` (6),
`running-8-frames` (8), `running-jump` (8), `running-slide` (6), `sad-walk` (8),
`scary-walk` (8), `surprise-uppercut` (7), `taking-punch` (6), `throw-object` (7),
`two-footed-jump` (7), `walk`/`walk-1`/`walk-2`/`walking` (6), `walking-2` (4),
`walking-3`…`walking-10` (6; `walking-5` is 4), `walking-4-frames` (4),
`walking-6-frames` (6), `walking-8-frames` (8). Quadrupeds: see `get_character`.
Official name mapping: hurt → `taking-punch`; death → `falling-back-death`
(+ `getting-up`); dash/dodge → `running-slide` / `running-jump`; cast → `fireball`.
`hurt`, `dashing`, `casting`, `shooting`, `staff-spin-attack` **do not exist**.
There is **no weapon-swing template**: sword attacks are custom (v3 / pixminimax / skeleton-v3).

## 3. Loose-image animation

**`animate_image_pixminimax`** (MCP) / `POST /animate-pixminimax` (HTTP), beta:
- `description` (motion, 1–1000), `first_frame_url`/`_base64` (≤ 256 px),
  optional `last_frame_url`/`_base64` (same size, pins the end),
  `frame_count` (multiple of 4, 4–40), `seed`, `no_background` (default true),
  `enhance_prompt` (+0.05; returns the rewritten text),
  caption fields `direction`, `view` (`low top-down`|`high top-down`|`side`),
  `subject_description`, `initial_pose` (≤ 300). Caption fields left out are read
  from the image by a model that can decline: then send them yourself.
- Cost: same table as pixminimax above. ~1–7 min.
- `get_image` returns frame_count + 1 images; index 0 is the input frame.

**`animate_image`** (MCP) / `POST /animate-with-text-v3` (HTTP):
- `action` (motion, 1–1000), `first_frame_url`/`_base64`, optional last frame,
  `frame_count` 4–16 even, `seed`, `no_background`. HTTP also has `enhance_prompt`.
- Limit w × h × frames ≤ 524,288. Cost `ceil(w×h×frames/65536)`, min 1
  (64×64×8 = 1; 128×128×16 = 4). ~30–180 s. Returns frame_count + 1 images.

**`animate_with_skeleton_v3`** (MCP) / `POST /animate-with-skeleton-v3`:
- `description` = **appearance** noun phrase (the motion lives in the skeletons),
  `action` = short label (≤ 100), `direction`, `view`, `first_frame_url`,
  `first_frame_keypoints` (the pose the image is already in), `keypoints`
  (3–15 frames × all 18 COCO-18 joints: NOSE, NECK, RIGHT/LEFT SHOULDER, ELBOW,
  ARM (= wrist), HIP, KNEE, LEG (= ankle), EYE, EAR; x/y as 0–1 fractions;
  `z_index`; optional `depth` 0–255), `template_id`
  (`mannequin`|`bear`|`cat`|`dog`|`horse`|`lion`), `seed`, `no_background`.
- LEFT/RIGHT are the character's own sides. Returns exactly len(keypoints) frames.
- Keypoints for your sprite: `POST /v2/estimate-skeleton` (HTTP only, 0.1 gen,
  body `{"image": {"type": "base64", "base64": "<png>"}}`).
- Cost: 3 frames = 2, 4–14 = 3, 15 = 4.

**`animate_object`** (MCP) / `POST /objects/{id}/animations`: `object_id`,
`animation_description` (1–1000), `frame_count` (v3: 4–16 even),
`mode` `v3` (default) or `pro` (10–25/dir; MCP asks for `confirm_cost`).
Do not pass `directions` for 1-direction objects. `replace_existing` to redo a direction.

## 4. Prompt-related facts

- Motion fields (`action`, `action_description`, `description` on pixminimax /
  animate_image): describe **movement, not appearance**; leave out locations and
  objects. Skeleton-v3 is the inverse (description = appearance).
- Length limits: v3 / pixminimax / object action 1000; v2 action 500; caption
  fields 300; skeleton action 100; character description 2000.
- **No negative-prompt field** on the current animation tools (only legacy
  `/animate-with-text` has `negative_description`). Phrase constraints positively.
- Enhancement: inline `enhance_prompt` (+0.05; on failure the original text is
  used and nothing is charged). HTTP-only standalone `POST /enhance-animation-v3-prompt`
  (`first_frame`, `last_frame`, `action` ≤ 500, `engine` v3|pixminimax|skeleton-v3,
  `direction`, `frame_count`) — cost **[UNVERIFIED]**.
- Palette (image creation tools): MCP `palette` (hex list), `palette_name`,
  `max_colors` (2–64); HTTP `target_palette`. Not offered on `animate_character`
  v3/pixminimax: snap colours in cleanup.
- Seeds: `seed` reproduces a job when the other inputs are identical.
- Direction names: `south` (toward camera), `south-east`, `east`, `north-east`,
  `north`, `north-west`, `west`, `south-west`. Views: `low top-down` (~20°),
  `high top-down` (~35°), `side`. Ask the user for the direction; do not pick one.
- Official tip: run upscaled pixel art through `unzoom` (HTTP `POST /unzoom`,
  MCP `unzoom_image`) before animating; upscaled input is the most common cause
  of poor output.

## 5. Errors to handle

401 bad token · 402 not enough credits · 403 not your asset · 404 not found ·
409 direction already exists (use `replace_existing` / a new group) · 422
validation (fix the field, do not retry blindly) · 429 too many concurrent jobs
or "all directions rate-limited" (wait, then resubmit only the missing
directions with `animation_group_id`). No numeric rate limits are published.

## 6. HTTP-only endpoints (no MCP tool)

Use only when MCP cannot do the job, with the env-var token (Section 0), after
the same approval gate. The MCP docs call raw v2 use outside MCP "at your own risk".
- `POST /estimate-skeleton` (0.1 gen): keypoints for skeleton-v3.
- `POST /interpolation-v2` (Pro): `start_image`, `end_image`, `action` ≤ 500,
  `image_size` 16–128. Cost **[UNVERIFIED]**.
- `POST /edit-animation-v2` (Pro): edit 2–16 existing frames by `description`;
  16 frames ≤ 64 px, 9 at 65–80 px, 4 above. Cost **[UNVERIFIED]**.
- `POST /animate-with-text-v2` (Pro): 16 frames at 32–64 px, 4 at 128–256 px.
  Cost **[UNVERIFIED]**.
- `POST /enhance-animation-v3-prompt` (see Section 4).

## Changelog

- 2026-11-01: created from the live MCP schemas + openapi.json + MCP docs.
