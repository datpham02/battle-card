# Pixel-Art Motion Guidelines

What changes when the animation is small, palette-locked pixel art. Read with
`animation-principles.md`.

## Keep the character the same character

- **Pixel density is constant.** Every frame uses the same pixel size as the
  anchor. No frame may look higher-resolution (anti-aliased curves, gradients)
  or lower (blocky) than the anchor.
- **Proportions are constant.** Head height, torso length, weapon length and
  limb thickness stay the same through the clip, within ±1 px for limbs and
  0 px for the head. A sword that grows during the swing is a defect unless it
  is an intended smear frame.
- **Held items stay in the same hand.** Never mirror a character whose gear is
  asymmetric (sword in the right hand, shield on the left) to make the other
  facing; animate that direction instead, or flag it.
- **Palette lock.** Every opaque pixel is one of the anchor's colours (or the
  project palette). Generators drift: new mid-tones on armour, a skin tone on
  the cape, a coloured glow. Snap to the palette after generation, then look
  again: a snap can turn a drifted region into the wrong colour family.
- **Outline consistency.** If the anchor has a 1 px dark outline, every frame
  has it, including the smear.

## Feet, anchor and ground

- One **feet anchor** per clip (bottom-centre on a fixed row). Planted clips
  (idle, attacks without a step, hurt, cast) keep the planted foot on the same
  pixel row and column. Moving the planted foot sideways = foot sliding.
- Steps and lunges move the body relative to the anchor on purpose; the engine
  moves the unit. Decide which: in-place clip (engine moves the sprite) or
  root motion baked into the frames. Never both.
- A jump leaves the ground row; everything else touches it.

## Motion at small sizes

- **Move whole pixels.** Sub-pixel motion (shading shifts that fake a ½ px
  move) is a tool for idles at ≥ 32 px; generators rarely do it well, so treat
  a 1 px back-and-forth on an otherwise still body as **jitter**, not breathing,
  unless the brief asked for it.
- **Frame economy:** at 32–96 px, 4–8 frames carry most actions. More frames
  of the same pose spacing look floaty; spend extra frames on holds (ticks), not
  on in-betweens.
- **Silhouette first:** at 1× the player reads only the silhouette and the
  brightest pixels. The key pose must change the silhouette (arm out, weapon
  extended, body lowered).
- **Smears:** one action frame with the weapon or limb stretched along its arc.
  Keep it in the sprite's palette, no new glow colour.
- **Loose parts lag:** cape/hair trail the body by 1–2 frames and settle 1–2
  frames after the body stops. This is the cheapest cure for stiffness.

## Effects are not body frames

- Slash trails, impact stars, dust, sparks, magic: separate VFX layer or sheet.
- If a generator bakes an effect into the body (a glow star on the hit frame,
  blood spray), remove it in cleanup or ask for a retake with the clause
  "no visual effects, only the character".
- A baked effect that uses a reserved colour (e.g. the game's telegraph red or
  status orange) is a FAIL, not a WARN.

## Canvas and padding

- Generators work on a canvas larger than the sprite (the silhouette grows it).
  Crop back to the project frame with the feet on the agreed row; never scale.
- Keep ≥ 1 px transparent margin around the widest pose (weapon tip, cape)
  in the final frame; pick the frame size from the widest pose of all clips.
- No non-integer scaling anywhere in the pipeline. Upscale previews only by
  whole factors with nearest-neighbour.

## Free cleanup after generation (in order)

1. Crop/seat: same canvas for every frame, feet on the agreed row and column.
2. Palette snap to the anchor/project palette (nearest colour).
3. Remove specks (isolated clusters under ~12 px that are not part of the body).
4. Remove baked effects and stray background pixels; alpha is 0 or 255 only.
5. Re-run the QA script; look at the contact sheet again.
