# Character consistency rules (P1.2, 2026-11-11)

Reusable rules for keeping one character the same across every image and clip.
They restate what `design/art/art-bible.md` (§5, §8.3, §8.4, §8.6, §8.9) and
`design/art/pixellab-profile.md` already require, plus what the production log
taught (specs under `design/assets/specs/`). When a rule here and the bible
disagree, the bible wins and this file is the one to fix. Per-character facts
(anchor, ids, palette, clips) live in `design/assets/references/characters/<id>.md`.

## 1. Anchor preservation

- **One anchor per character:** `art_src/units/<id>/idle/0.png` (idle frame 0 of
  the installed source). The PixelLab character id in the Master Reference is
  the same anchor on the server; after any local edit the local PNG wins (the
  Goblin's server character kept the old palette — goblin-scout-assets.md fix-01).
- Every new clip starts from the anchor: `animate_image_pixminimax` with the
  anchor as the first frame; one-shot clips (cast, hit, draw) also pin the
  anchor as the **last** frame so the clip returns to the stance (Knight guard
  cast, Assassin X-slash, Mage idle v3).
- The anchor changes only through the user: a new anchor is a new
  `versions.current`, the old one goes to `versions.retired`, every clip is
  regenerated (Knight v1 → v2 → v3, elites v1 → v2, Witch narrow → wide).
- A still that the user has not approved is not an anchor. Generate the still,
  show it in context (`prototypes/art-check` or the game), get the yes, then
  animate (`.claude/skills/pixellab-animation-engineer`: "create the anchor
  first").

## 2. Palette locking

- Lock the palette at generation (`palette` + `max_colors 8` on every Pro Flash
  call; the spec row lists the hexes). After generation snap every opaque
  pixel to the unit's colours (`tools/qa/sprite_clean.gd`); `export_sheets.py`
  refuses anything outside `art_src/palette/tessera_master.gpl`.
- ≤ 8 colours per unit (heroes, monsters), ≤ 12 for wardens (bible §8.9 #4);
  Ink `#1B1722` is always one of them; alpha 0 or 255 only.
- Red `#E5293B` belongs to the enemy telegraph and orange to Burn: never baked
  into a body. The model bakes red sprays, yellow stars, orange impact bursts
  and crescent smears into hit / windup / cast frames — delete them or drop the
  frame (every roster `clips.json` note is an example).
- Heroes carry their block colour as the ≤ 15 % accent (steel, amber, jade-white,
  jade, lilac); enemies never carry a hero material colour (bible §5.1, §5.2).
  The Cleric is the recorded exception (no lilac survived; open deviation).
- Adding a colour to the master palette is the art-director's call, logged at
  the top of the `.gpl` (bible §8.4).

## 3. Silhouette and body proportions

- Identity sits in the **upper half** (head, shoulders, held prop): the
  Knight's cross-guard, the Mage's bent hat and book, the Assassin's square
  hood, the Hunter's brim and feather, the Cleric's veil and square staff
  head, goblin ears, the Witch's beak mask and antlers.
- Tiers by height (user 2026-11-02 "quái có cấp bậc càng cao thì càng to"):
  heroes ≈ 66 px, normals ≈ 46 px (≈ 70 % of the Knight), elites ≥ 12 px taller
  than the tallest normal (`roster_sprite_test`), bosses fill their 2×2 block.
- Keep the species / class silhouette through every clip: a crouched Assassin
  stays low, the Hunter's crossbow stays in the hands, the Cleric's staff stays
  held. If the model drops a prop in a frame, drop the frame.
- Likeness check before any anchor: name the closest famous look and say how
  the design differs (user rule after the Cloud-like Swordsman).

## 4. Pixel density and frame alignment

- One pixel size everywhere: art px at 1×, integer-scaled by the engine; never
  resize a generated frame, never draw at a half pixel (bible §8.10).
- One canvas per unit (`frame` in `clips.json`): heroes 96×70 / 96×72 /
  96×92 (`body_h` 70), normals 64×52 (Dire Wolf 68×52), elites 80×80,
  bosses 160×130. A shorter source is bottom-aligned by the exporter; a taller
  one is a canvas change that the user decides (Knight option A, 2026-11-08).
- ≥ 1 transparent px on the left, right and top of every frame; the bottom row
  may be touched (feet). Nothing may be clipped by the canvas: if a pose needs
  more room, ask about the canvas, do not shrink the body.

## 5. Feet positioning

- Feet on the **last pixel row**, feet x at the canvas centre (48 / 32 / 34 /
  40 / 80), identical in every frame of every clip; the engine anchors
  bottom-centre (`UnitLayer.sprite_dest_rect`).
- The model drifts (the Witch glided, the Knight's dashes baked in travel):
  recentre each frame on the body (cape excluded) and re-plant the feet before
  export. Measure with `tools/qa/sprite_measure.gd`; `anim_qa.py` reports feet
  row and x drift.
- Crouch, heap and lying frames are lifted onto the feet row, not left
  floating (wolves, archer, warlock notes).

## 6. Animation consistency

- Same engine and settings for every clip of a unit: PixMiniMax, 8 frames,
  seed 1, the unit's view (`low top-down`) and direction (south-east for heroes,
  south-west for enemies), positive motion words only.
- Facing never flips inside a clip; frames where the model turned the back are
  dropped (Goblin windup 3–4, Witch step_up 4+).
- Timing comes from the sheet, not the model: idle 125 ms (heroes) / 250–300 ms
  (enemies), `step` nominal 100 ms (the game paces it), `windup` ends on a
  0 ms held frame, hero casts use the Knight's 9-slot timing with the hold on
  frame 4 and the release on frame 5 (`gesture_hold_frame`), hit 3 × 40 ms.
- Clip sets per tier are in each Master Reference §6; a clip the code can use
  but the bible does not require (dashes, draw, cast_hand) is optional, and its
  absence must not break the game (UnitLayer falls back to step / idle /
  cast_gesture).
- Overlays, flashes and status effects are never extra frames (bible §5.4
  "Không vẽ khung"); they are VFX packs or shader palette swaps.

## 7. Allowed visual variation

Allowed between frames and clips: pose and weight shift, breathing 1–2 px,
cloth / hair / tendril / tail sway, weapon angle, eye blink, lean back on hit,
heap on down. Not allowed: palette change, proportion change, missing or new
accessories, outline weight change, anti-aliased edges, a different light
direction (always upper left), glow, text, red / orange baked in.

## 8. Mechanical edits only

After generation only these edits are allowed (user rule 2026-11-04 "no
hand-painted details"): palette snap, speck removal (< 12 px clusters),
translate / recentre, crop to canvas, region recolour of one existing colour
to another (Knight cape gold → navy), frame selection and duplication (hold
frames), frame order. Anything that draws new pixels (a new arm, a new face)
is a new generation and needs the user's yes. Every `cast_hand` clip was
dropped 2026-11-11, including the Knight's approved PixMiniMax v3. A hand
cast on a weapon body holds idle. The Mage's `cast_gesture` is the hand cast.

## 9. Record it

Every generation, selection and verdict goes to the registry
(`asset_registry.py log-event / set-acceptance / set-status`) and the spec's
generation log; the Master Reference is regenerated or edited to match. An
approval that is not written down does not exist (registry rule).
