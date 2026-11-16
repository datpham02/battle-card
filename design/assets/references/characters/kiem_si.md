# Master Reference — Swordsman / Knight (Kiếm sĩ) (`kiem_si`)

> One file per character (P1, 2026-11-11). Facts come from the registry entry `unit.kiem_si`, `art_src/units/kiem_si/clips.json`, the sheet JSON and the spec; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.kiem_si`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id / legacy id | `unit.kiem_si` / ASSET-001 |
| Type / tier | unit / hero |
| Role | Player hero — Swordsman / Knight (Kiếm sĩ); steel blocks |
| Spec | `design/assets/specs/swordsman-assets.md` |
| Design (approved text) | Chibi knight, rectangular build with two big square symmetric pauldrons, steel-blue plate armour with an ivory trim band across the chest; a straight narrow double-edged sword (blade 2 px) in a dark scabbard across the back — the wide cross-guard (~6 px) and round pommel above the head are the identifying mark, not a wide blade; pale blond hair cut short with a flat fringe, hair falling over the forehead (anti-Cloud choice), 1 px ivory headband; eyes 2x2 Ink, no whites. (design/assets/specs/swordsman-assets.md:34-35 Visual Description v2; art bible §5.1 row Kiếm sĩ) |
| Silhouette / proportions | Rectangle; two square shoulders; v3 tall OSFE ratio ~4.5 heads: visible 31x66 px south-east (swordsman-assets.md:105). In battle the sword is held in a guard stance the whole match (user 2026-11-02 'trạng thái đứng luôn'; swordsman-assets.md:112). |
| Likeness check | v1 read as Cloud Strife (FF7) and was dropped (swordsman-assets.md:85). Differentiated: short flat blond cut with headband, narrow double-edged sword with cross-guard, square pauldrons, short cape. |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | design/art/reference/04-knight-01.png (described in words, never used as an image input — swordsman-assets.md row v3-knight-01) |
| Anchor image (canonical frame) | `art_src/units/kiem_si/idle/0.png` — idle frame 0 of the installed source; every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/swordsman/v3-tall`, `design/assets/candidates/swordsman/v3-tall/clean-96x70`, `design/assets/candidates/swordsman/anim-idle-v2`, `design/assets/candidates/swordsman/cast-forward`, `design/assets/candidates/swordsman/cast-command`, `design/assets/candidates/swordsman/cast-hand-v3` |
| Anchor approval | **approved** — art_src/units/kiem_si/clips.json source: "v3 tall anchor, approved 2026-10-31"; design/assets/specs/swordsman-assets.md:116 (Status 2026-10-31 v3) |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | right (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-east |
| Frame | 96x92 art px, body_h 70 |
| Anchor rule | feet on the last pixel row, feet x = 48; ≥ 1 transparent px left / right / top (`export_sheets.py` refuses otherwise) |
| Sheet | `assets/art/units/unit_kiem_si_sheet.png` 872x1394, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation: Ink #1B1722; steel #5F6F82 / #8FA3B8 / #EEF4FA; navy cape #34406E; brass #B8893A; ash hair #D8CDB0; skin #E3B99A (swordsman-assets.md:104 v3-knight-01 palette). Accent (light steel #EEF4FA) ≤ 15 % of pixels (art bible §5.1).
- In the installed sheet (`meta.tessera.palette`, 8 colours): `#1B1722`, `#34406E`, `#5F6F82`, `#8FA3B8`, `#B8893A`, `#D8CDB0`, `#E3B99A`, `#EEF4FA`
- Master: `art_src/palette/tessera_master.gpl`; ≤ 8 colours per unit; alpha 0 / 255 only; no red `#E5293B` (telegraph), no orange baked in (Burn); adding a colour is the art-director's call (bible §8.4).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | 2d093318-1ba4-43aa-b843-a5f0fdf62939 |
| Image / job ids on record | 5e5e14ed-952d-42ec-b517-8bff32bb795e (cast_forward), 91224bb1-17de-4a5b-a70b-b4f6a93ac14d (cast_summon), 9d1adf31 (idle v2), 5e4ba76d-2db3-44aa-8ea5-cc0d2e0a4118 (guard cast = cast_gesture), ac2cb023 (cast_overhead v1, rejected), 2a14a25c (cast_hand v3, dropped 2026-11-11, not on the sheet) |
| Configuration that produced the anchor and clips | create_character_pro_flash, canvas 64x84 (text), low top-down, 8 directions, seed 5, palette locked (max 8), style_image = v3-knight-01 south rotation (own image; outline / shading / detail only, colour off); prompt 'same design, ~4.5 heads, ~76 px tall' (swordsman-assets.md:105). Clips: animate_character pixminimax south-east 4–8 frames (2026-10-31/11-02), then animate_image_pixminimax from the local guard anchor with first (and last) frame pinned (2026-11-02 onward). |
| Style reference (style_image lineage) | v3-knight-01 (character f81b0fb3, 48x64) → v3-knight-tall (character 2d093318). The Knight's south rotation is the style_image for every other hero (upload 8efc54de, 84x84). |
| Post-generation (free, mechanical only) | palette snap to the locked colours, specks < 12 px removed, feet re-planted on the last row, body recentred; region recolour when the model drifted (Knight cape); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a hero (art bible §5.4 / §8.6): `idle`, `step`, `cast_gesture`, `hit`, `victory`, `defeat`, `awaken`, `fall`.
Optional clips the code plays when present (fallback otherwise): `draw`, `step_forward`, `step_back`, `step_up`, `step_down`, `cast_hand`, `cast_forward`, `cast_summon`.

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 8 | 125 | loop | installed | unknown | 9d1adf31 | 2026-11-02 guard stance (user: in battle the knight holds the sword ready, 'trạng thái đứng luôn'): PixMiniMax from the draw_to_guard last frame, cleaned and recentred on the body |
| `draw` | 8 | 60, 60, 80, 80, 80, 80, 80, 120 | once | installed | unknown | — | 2026-11-02 match start: draws the sword from the back into the guard stance (PixMiniMax on the v3 character, no recentring: the feet do not move); UnitLayer plays it once when the match binds |
| `step` | 4 | 100 | loop | installed | unknown | — | nominal; the game paces step by the step cooldown |
| `step_forward` | 7 | 50 | once | installed | unknown | — | 2026-11-02 guard stance (user: in battle the knight holds the sword ready, 'trạng thái đứng luôn'): PixMiniMax from the draw_to_guard last frame, cleaned and recentred on the body; OSFE dash, the game glides the unit |
| `step_back` | 7 | 50 | once | installed | unknown | — | 2026-11-02 guard stance (user: in battle the knight holds the sword ready, 'trạng thái đứng luôn'): PixMiniMax from the draw_to_guard last frame, cleaned and recentred on the body; OSFE back-dash, still facing right |
| `step_up` | 7 | 50 | once | installed | unknown | — | 2026-11-02 guard stance (user: in battle the knight holds the sword ready, 'trạng thái đứng luôn'): PixMiniMax from the draw_to_guard last frame, cleaned and recentred on the body; keeps facing right (the first roll turned its back) |
| `step_down` | 7 | 50 | once | installed | unknown | — | 2026-11-02 guard stance (user: in battle the knight holds the sword ready, 'trạng thái đứng luôn'): PixMiniMax from the draw_to_guard last frame, cleaned and recentred on the body |
| `cast_gesture` | 9 | 83, 83, 83, 83, 200, 50, 83, 100, 133 | once | installed | unknown | — | 2026-11-02 guard stance: PixMiniMax from the guard anchor (first and last frame pinned to it), src frames 0,1,2,3,4,8,6,7,0: guard, raise, lift, coil, coil (frame 4, held during the swing telegraph by the cast index gesture_hold_frame), slash with the arm fully out (5, the release cut and the wave leave; src 5 had a baked crescent smear, dropped), follow-through x2, back to the guard. Same 9 frames and ms as the v4 clip, so the cast timing data is unchanged |
| `cast_forward` | 9 | 83, 83, 83, 83, 200, 50, 83, 100, 133 | once | approved | approved 2026-11-08 | 5e5e14ed-952d-42ec-b517-8bff32bb795e | 2026-11-08 Trảm Địa (user-approved PixMiniMax job 5e5e14ed-952d-42ec-b517-8bff32bb795e, 1 gen; first and last frame pinned to cast_gesture/0 guard): raw f0-f8 in design/assets/candidates/swordsman/cast-forward/raw, cleaned mechanically (tools/qa/sprite_clean.gd: palette snap to the 7 sheet colours, specks < 6 px dropped, f1/f2 +5 px, f3 +6 px, f6/f7 -1 px so the feet stay on x32-38). Slots: f0 guard, f1-f2 draw back, f3 coil (also slot 4, held during the swing telegraph like cast_gesture's frame 4), f5 release (low forward), f6-f7 follow-through, f8 guard; raw f4 dropped (baked slash smear). Same 9 ms as cast_gesture so the cast timing data is unchanged. Known: the wind-up raises the sword high (not low to the hip as asked) (cape fixed 2026-11-08: tools/qa/sprite_recolour_region.gd b8893a -> 34406e on the INTERIOR of gold components >= 25 px, slots 5 and 6 only, 54 + 30 px; the 1 px gold trim and every armour trim kept). |
| `cast_summon` | 9 | 83, 83, 83, 83, 200, 50, 83, 100, 133 | once | installed | accepted 2026-11-08 | 91224bb1-17de-4a5b-a70b-b4f6a93ac14d | 2026-11-08 Ngàn Kiếm cast (user-chosen): one-handed raise + pull-down, user-approved PixMiniMax job 91224bb1-17de-4a5b-a70b-b4f6a93ac14d (1 gen; first frame = guard 96x92, last frame = the earlier command pose 96x92), raw in design/assets/candidates/swordsman/cast-command/raw. Mechanical clean only (palette snap; 0 speck px; no move: feet already on x32-38 row 91). Slots: raw f0 guard, f1 crouch, f3 raise, f5 raise, f4 summon hold (slot 4: held through the swing and, for the on-tile summon, until the visual command), f7 pull-down + cape (release), f8 command pose, then the return and the guard (frames of the retired cast_overhead v1 7 and 8, kept here as slots 7-8). Raw f2 (blade on the frame top row) and f6 (baked smear arc) dropped. Known and accepted by the user: the raised blade overlaps the top-row HUD on 3 of 4 cells. |
| `hit` | 3 | 40 | once | installed | unknown | — | 2026-11-02 guard stance (user: in battle the knight holds the sword ready, 'trạng thái đứng luôn'): PixMiniMax from the draw_to_guard last frame, cleaned and recentred on the body (src frames 1, 4, 5: the slash smear of 2-3 dropped) |
| `victory` | 5 | 100 | hold_last | installed | unknown | — |  |
| `defeat` | 8 | 100 | hold_last | installed | unknown | — |  |
| `fall` | 4 | 100 | hold_last | installed | unknown | — | unused until the falling-cell story (no gameplay uses it yet) |
| `awaken` | 6 | 120 | loop | installed | unknown | — |  |

Timing rules: `idle` 125 ms (heroes) / 250–300 ms (enemies) per frame today (bible §8.6 says 0.4 s — the installed timing is the user's accepted feel); `step` is nominal, the game paces it by the step cooldown; `windup` ends on a 0 ms frame held until the telegraph ends; hero casts share the Knight's 9-slot timing 83, 83, 83, 83, 200 (hold frame 4), 50, 83, 100, 133 with the release on frame 5.

## 7. Visual constraints (what a new generation must keep)

- Same anchor: generate from `art_src/units/kiem_si/idle/0.png` (or the character id) with the first frame pinned; for one-shot clips pin the last frame too.
- Same canvas 96x92, same feet row and feet x; the exporter bottom-aligns shorter sources, never taller ones.
- Identity in the upper half: Rectangle; two square shoulders; v3 tall OSFE ratio ~4.5 heads: visible 31x66 px south-east (swordsman-assets.md:105). In battle the sword is held in a guard stance the whole match (user 2026-11-02 'trạng thái đứng luôn'; swordsman-assets.md:112).
- 1 px closed Ink outline; banded shading, light from the upper left; no glow, no smooth gradients, no anti-aliasing fringe (ART_QA_CHECKLIST §B–§D).
- Facing stays right in every frame (the model sometimes turns the back from frame 4: drop those frames, as for the Witch's step_up).
- Effects (bursts, stars, slash smears, red sprays) are never part of the body: delete or drop the frame; VFX are separate packs.
- Allowed variation: pose, cloth / hair / tendril sway, breathing 1–2 px, held weapon angle; not allowed: palette drift, proportions, props disappearing, new accessories.

## 8. Generation lineage

- 2026-10-31 v1 40x48 / 32x48 frames (Cloud-like) — rejected, parked in candidates/swordsman/v1-cloudlike + ASSET-001-*-40x48.png
- 2026-10-31 v2-cand-01 create_image_pro_flash 32x48 seed 2 (job cdafe2b0) — anti-Cloud design, superseded by v3
- 2026-10-31 v3-cand-01 create_image_pro_flash 48x64 (job 391d2fc7) — not accepted (bald head, front only)
- 2026-10-31 v3-knight-01 create_character_pro_flash 48x64 → character f81b0fb3 (6 gen) — design right, too short
- 2026-11-14 **Vale anchor v5 — APPROVED by the user**
  - **The pointed shape at the right hand is the CLOTH TAIL, accepted by the user 2026-11-14.**
    Written down because it will be asked again: it has a tapering point, a pale edge highlight and
    one `#B8893A` pixel, which reads like a short blade at a glance. It is **in the approved anchor**,
    not introduced by the clip — cropping the identical region from `anchor_v5/south-east.png` and
    from clip frame 4 gives the same pixels. **Do not "fix" it in a later clip or re-roll the anchor
    over it.**
  - **What this caught about the review itself:** the anchor was approved against a checklist (armour,
    cloak, shield, helmet, weapon, height) and the shape was not noticed, because it was not on the
    list and the list felt complete. A checklist catches what it names and quietly licenses
    everything else.
  - **Clip result, measured:** 9 frames 96x96, **0 off-palette pixels**, body rises **1 px**, motion
    concentrated in frames 4-7 (frames 0-2 differ from each other by 1 px), frame 8 returns to within
    5 px of frame 0 so the loop closes. Accepted: the uneven rhythm is within what a 1 px breathing
    idle can carry, and a re-roll would cost a generation to buy a difference nobody can see at 1x.
  - **SHEET REBUILT IN PLACE 2026-11-14** — `assets/art/units/unit_kiem_si_sheet.png`,
    **101/101 frames placed**, 872x1394, **0 empty frames, 0 off-palette pixels** when re-measured
    from the sheet itself. The old sheet is recoverable from git (it was clean) and a copy sits in
    the session scratchpad.
  - **The existing JSON stayed the authority for everything except the pixels.** Each new frame was
    blitted at the exact x/y the old frame occupied, so frame names, durations, frameTags, the loop
    map, columns and gutter are untouched and cannot disagree with the game. **A layout recomputed
    is a layout that can be wrong; a layout reused cannot.** The only JSON edit is the palette value
    `#8FA3B8` -> `#8FA8BE`, the drift the user ruled on — 1 occurrence.
  - **`step` was built as a one-shot first and that was wrong.** The sheet's own `meta.tessera.loop`
    says `idle: loop, step: loop, awaken: loop`, and `victory / defeat / fall: hold_last`. I had
    taken the clip's NAME as the hint. Fixed before the sheet was built, so `step` now stores
    [0,1,2,3] and drops the return-to-frame-0 instead of showing frame 0 twice per cycle.
    **The sheet's loop map is the authority, not the clip name** — nothing in the name of `step`
    says it cycles, and nothing in `step_forward` says it does not.
  - **INSTALLED 2026-11-14 to `art_src/units/kiem_si/anchor_v5_clips/`** — 15 clips, shipped frame
    counts, canvas **96x92**. Mechanical only. Result: **0 off-palette, 0 specks, 0 pixels lost off
    canvas**.
  - **The shift is ONE shift for the whole unit** (dx **-3**, dy **+11**), computed from `idle`
    frame 0 and applied to every frame of every clip. Centring each frame on its own bounding box
    would re-centre the character every frame and **delete the motion** — a step would become a man
    walking on the spot. The shift belongs to the unit, not the frame.
  - **Two frames needed a 1 px nudge and the guard is what found them:** `fall` frame 3 and
    `step_forward` frame 6 reach one row lower than `idle` frame 0 (a fall, the plant of a long
    step), so the unit shift pushed them past the last row. First run reported **12 pixels lost**
    and refused to ship. Fixed with the smallest nudge that keeps every pixel on canvas (-1 each),
    printed rather than applied silently — same convention as the shipped `cast_forward`
    ("+5 px, +6 px, -1 px").
  - **Frame selection rule, stated so it is reproducible:** evenly spaced, first and last raw frame
    always kept; **loop clips drop the final raw frame first** because it is the return to frame 0
    and storing it would show frame 0 twice per cycle. Picks are printed per clip.
  - **The 96x96 -> 96x92 crop takes the four rows off the TOP, and that is now verified, not
    assumed**: the "pixels lost off canvas" counter is the verification, and it reads 0.
  - **`step_down` regenerated and fixed — same lesson as `awaken`, different shape.** New group
    `1e9283d3-9a9e-494d-b379-09a12013676c` (`step_down_v2`). The dead version was asked for a
    **direction of travel** ("one heavy step toward the viewer"); straight at the camera, a 2D sprite
    has nothing to translate, so the generator returned the reference frame nine times. The new one
    is asked for **visible motion inside the frame** ("the near leg lifts high, knee rising in front
    of the body, then reaches down and plants heavily as the body drops"). Measured per frame vs
    frame 0: **8, 790, 1194, 1339, 1400, 1419, 1051, 830** (the dead one: eight zeros; `step_up`
    peaks at 1528). 0 off-palette.
  - **Both failures were the same mistake in different clothes:** the prompt described the clip's
    PURPOSE (a loop, a direction) instead of what the pixels do. The generator draws pixels.
  - **Final state: 15 of 15 clips good, 29 generations for Vale.** Use `awaken_loop` and
    `step_down_v2`; the groups named `awaken` and `step_down` are dead and must not be installed.
    Every clip's frame 0 measures **41x63**, identical to the anchor sprite, so all 15 start on
    model; a contact sheet of every clip's peak frame shows no armour, cloak, shield or weapon
    anywhere.
  - **CORRECTION 2026-11-14, and it overturns a number recorded above.** Every "loop closes to N px"
    figure on this page measured **frame 8 against frame 0** — but a loop clip **drops frame 8** when
    installed (it is the return to frame 0), so the loop actually closes between the **last STORED**
    frame and frame 0. I was grading a frame the game never shows.
    Re-measured on the frames that are actually stored, as `wrap step / median step`:

    | clip | steps between stored frames | wrap / median | |
    |---|---|---|---|
    | `idle` v1 | **1, 0**, 49, 456, 86, 7, 108 | **9.78** | SNAP (and two dead steps) |
    | `idle_v2` | 766, 754, 539, 842, 1017, 598, 614 | **1.11** | smooth |
    | `awaken_loop` | **5**, 750, 792, 483, **9** | 2.14 | SNAP |
    | `awaken_v2` | 632, 820, 871, 872, 648 | **1.41** | smooth |

    **The criterion was wrong as well as the pair.** "Closes to ~0" is the wrong target for a stored
    loop: zero means frame 0 is shown twice per cycle. The wrap should be **one ordinary step**, so
    the test is `wrap / median step ≈ 1`, not `wrap ≈ 0`. Under the right test, the `idle` now in the
    shipped sheet SNAPS at 9.78 — which is what the user saw and reported as "thiếu animation trạng
    thái bình thường", before any measurement said so.
  - **`idle_v2` (`484db8cb-6974-430e-bdd2-ae82ff923edc`) and `awaken_v2`
    (`f4cb4793-7345-4ee7-a713-836915080cdd`) are the ones to install**, 0 off-palette, no dead steps,
    wrap in line with the rest. The groups `idle`, `awaken` and `awaken_loop` are all superseded.
  - **`awaken` regenerated as a loop and it worked — the diagnosis is confirmed by number, not by
    eye.** New group `445a4554-a67e-4c28-95db-f7ce83bf5e58` (name `awaken_loop`), prompt rewritten as
    a CYCLE ("...ending in exactly the starting pose so the motion repeats seamlessly").
    **last-vs-first = 3 px**, against **661** for the one-shot wording and **5** for `idle`. Motion is
    not lost in the bargain: 1034 px at peak. Use this group; the old `awaken` group is dead.
  - **`step_down` is a DEAD CLIP — all 9 frames byte-identical.** Confirmed by two independent
    downloads (the second with `curl --fail`, no errors): 9 files, **1 distinct hash**. The generator
    returned the reference frame nine times for "taking one heavy step toward the viewer" — a motion
    straight at the camera, which is the one direction a 2D sprite cannot show by translation.
    **Needs 1 regeneration with the motion described as something visible** (the near leg lifting and
    planting, the body dropping), not as a direction of travel.
  - **A download failure nearly became a second false defect.** The first fetch of `step_back` was
    missing frame 1 and the first fetch of `step_down` returned frame 0 nine times — the bulk `curl`
    loop had no `--fail`, so transient errors wrote plausible files. Re-fetching with `--fail` cleared
    `step_back` (8 distinct of 9, normal) and confirmed `step_down`. **A measurement pipeline that
    cannot tell "no motion" from "no download" reports the first and means the second.**
  - **All 15 clips completed and measured 2026-11-14. 0 off-palette pixels in every frame of every
    clip** — the palette lock held across 120+ generated frames without a single snap needed.
    `cast_gesture` delivers the signature: arms at the sides in f0-f1, rising, **crossed in front of
    the chest from f3 and held** — the Art Bible §3 mark, in the clip it belongs to.
  - **`awaken` is WRONG and it is my error, not the generator's.** The shipped clip is a **6-frame
    LOOP at 120 ms** (table above). I wrote it a one-shot motion prompt — "slowly settling into a
    steady standing stance" — which describes something that ends. Measured: last frame differs from
    the first by **661 px**, so it will snap visibly every time it wraps. For comparison `idle`, a
    loop written as a loop, closes to **5 px**. The defect is in the prompt, so re-rolling the same
    prompt would reproduce it; a looping motion has to be described as a cycle that returns.
    **Needs 1 regeneration and the user's yes.**
  - *Motion measured per clip (max pixels changed vs frame 0): defeat 1562, victory 1523,
    cast_forward 1498, cast_gesture 947, draw 929, awaken 857, cast_summon 828, idle ~550.*
  - **Remaining 14 clips queued 2026-11-14**, all `south-east`, pixminimax, palette locked 8,
    **1 generation each = 14** (running total for Vale: **27**). 8 animated frames for the long
    clips, 4 for `step` / `hit` / `fall` / `victory`; the raw frames are then selected into the
    shipped slot counts mechanically, as `cast_forward` was.
  - **`draw` had no referent any more and was repurposed, not dropped.** The shipped clip is
    "draws the sword from the back into the guard stance" and there is no sword. `UnitLayer` still
    plays it once at match start, so deleting it would need a code change. Regenerated as **lifting
    both hands into a ready stance** — same role, new action. **Flagged for the user:** nobody
    decided this; the clip list was written for an armed character and nothing re-examined it when
    the weapons went.
  - **First clip (test, 2026-11-14):** `idle`, animate_character mode pixminimax, direction
    **south-east only**, 8 frames + kept reference frame, palette locked 8, **1 generation**, group
    `c239cb82-e5e5-4f0e-9d50-b51144ad480a`, job `6f091f90-f30f-4cd7-a3b8-2419760230ff`.
    **One clip, one direction, before the other fourteen** — if the motion prompt is wrong, it is
    wrong for all of them, and finding that out costs 1 generation here instead of 15.
    Motion prompt is positive-only (cloth sway, chest rise), per the Mage-clip lesson: naming a thing
    to forbid it is how "no red" painted the Mage red.
    Animation canvas comes back **96x96** while the project frame is **96x92** — reconcile at install.
  - **INSTALLED 2026-11-14 to `art_src/units/kiem_si/anchor_v5/`** (8 rotations). Mechanical only:
    palette snap, 8-connected specks < 12 px dropped, feet planted on the last row, body centred —
    one shift per image, no resampling, no hand-painted pixel. Measured during the clean:
    **0 off-palette pixels and 0 specks in all eight** — the locked palette held exactly, so the snap
    and speck passes were identity. Body heights 61-64 px (south 61, the rest 63-64).
  - **The live sheet `assets/art/units/unit_kiem_si_sheet.png` was deliberately NOT touched.** It
    holds **15 clips / 101 frames** of the OLD armoured, sword-carrying Vale. Dropping the new anchor
    into it would give one cloth-and-bare-arms idle frame beside a hundred frames of plate and sword
    — worse than either version alone. The anchor is the SOURCE the clips are generated from; the
    sheet changes when the clips do, not before. create_character_pro_flash 64x84, same config as v4 (seed 5, 8 dir, palette 8, style_image = `f81b0fb3` south, outline+shading only) — character `3ec3cc62-d6af-43f3-a7b9-a94dcf73cdba`, job `99108cc4-7589-4e72-b4a7-57749e0473c0`, **6 gen**, user said "Loại, gen lại". **Two prompt changes, each aimed at one named v4 defect:**
  - **Proportions stated as numbers** ("~4.5 heads tall, roughly 76 pixels tall, head near the top of the frame, feet near the bottom"). v4 came out **48 px** against the roster's **70**. The approved anchor used the SAME 64x64 style image and still reached 70, because its prompt carried "~4.5 heads, ~76 px tall" (line 93 of this file). The style image was not the cause; the missing proportion line was.
  - **Forearms described as something metal cannot be**: "soft cloth strips wound round and round many times, the loose ends hanging free". v4 produced segmented plates with gold studs — vambraces. "Wide cloth bands" sits too close to a vambrace for the model to tell them apart.
  - **APPROVED 2026-11-14.** Both named v4 defects fixed, measured: forearms are wound cloth with loose
    ends (no plates, no studs); body **61 px** tall vs v4's 48.
  - **Approved OVER a raised objection, recorded because the objection did not disappear.** The wound
    forearms plus wound shins plus the cloth sash read **East Asian**, against the project's Western,
    no-wuxia direction ([[world-direction-tessera]], `design/world-context.md`). I raised it before
    approval; the user approved anyway, which is their call as creative director. **What this leaves
    open for the next hero:** either wound limbs are now house style for Tessera and the other four
    may use them, or Vale is a one-character exception. Nobody has decided that, and a later session
    generating Ilva or Bram will have to guess unless it is settled. **The cause is worth keeping
    too:** the wraps were MY fix for the v4 vambraces — describing cloth wound round and round is the
    shinobi vocabulary, so fixing a material defect introduced a world defect one level up. A reject
    list of objects (armour, cloak, shield, helmet, weapon) cannot catch that: v5 passes it cleanly.
  - **Size is still short of the roster and not reconciled.** Measured like-for-like against frame 0
    of the installed sheet: v5 **61 px** tall / **42 px** wide, installed Vale **64 / 50**. The
    reference table above states `body_h 70`, a third number — so the declared value and the sheet's
    own ink extent already disagree, before this anchor is installed. Settle which is authoritative
    at install time; do not scale the sprite to match a number nobody has checked.
  - v4 (`5e91b37f-68db-4231-9401-46a08f8d39b0`) **REJECTED**, kept on PixelLab, not used. Rejected under the user's own rule rather than hand-fixed: the plates would have been hand-painting, and the height is not fixable by hand at all.
- 2026-11-14 **Vale anchor v4 (weapon-free AND armour-free)** create_character_pro_flash 64x84, seed 5, 8 dir, low top-down, palette locked 8 (`#34406E` reused for the cloth, `#8FA8BE` as the identity value instead of the sheet's `#8FA3B8` drift), max_colors 8, style_image = v3-knight-01 south (`f81b0fb3-1433-4a18-b65b-a48bd24cef72`, 64x64) with **outline + shading only, colour and detail off** — character `5e91b37f-68db-4231-9401-46a08f8d39b0`, job `25d97348-de62-4a8f-adab-263917118ddc`, **6 gen**, user said YES to this one call. Design locked first in `docs/design/character-system/WEAPON-FREE-ANCHOR-KIEM-SI.md`.
  - **Why NOT the usual 84x84 style image** (`upload 8efc54de`, the one every other hero uses): a style reference must fit inside the target canvas, and 84 > 64, so that call would have been refused. The 64x64 ancestor is the one that fits. Caught before spending, not after.
  - **The prompt carries no negative words.** The banned list (armour, cloak, shield, helmet, weapon, mass-forming metal) is the REJECT rule for the reviewer, deliberately kept out of the description — naming a thing to forbid it is how the Mage clips ended up painted red.
- 2026-10-31 v3-knight-tall create_character_pro_flash 64x84, style_image = v3-knight-01 south → character 2d093318 (6 gen) — APPROVED anchor
- 2026-10-31 v3-anim-idle + 7 clips animate_character pixminimax (8 gen) → clean-96x70
- 2026-11-02 dashes (4 gen), draw_to_guard + 6 guard clips (7 gen), guard cast (1 gen, job 5e4ba76d) — guard stance set
- 2026-11-05 idle v2 animate_image_pixminimax job 9d1adf31 (anchor pinned first + last)
- 2026-11-08 cast_forward job 5e5e14ed (1 gen) — approved; cast_summon job 91224bb1 (1 gen) — accepted; canvas grew to 96x92 (option A)
- 2026-11-10 cast_hand v3 job 2a14a25c — approved, then dropped from the sheet by the user on 2026-11-11. The raw frames stay in candidates/swordsman/cast-hand-v3 and are not installed. A hand cast holds idle.

## 9. Versions

- **Current:** v3-tall (96x92 canvas since 2026-11-08, sources 96x70 bottom-aligned)
- **Retired:**
  - v1 40x48 (Cloud-like) — paths `design/assets/candidates/swordsman/ASSET-001-*-40x48.png`, `design/assets/candidates/swordsman/v1-cloudlike`, `design/assets/candidates/swordsman/pre-40x48` — design/assets/specs/swordsman-assets.md:85 "the v1 Swordsman reads as Cloud Strife"
  - v2 anti-Cloud rotations — paths `design/assets/candidates/swordsman/ASSET-001-v2-*.png` — swordsman-assets.md v2 rows (superseded by v3 tall)
  - cast_overhead v1 (job ac2cb023) — paths `design/assets/candidates/swordsman/cast-overhead` — design/assets/specs/swordsman-cast-overhead-v2.md:3 "placeholder and is NOT approved"; not in clips.json
- **Rejected:**
  - v1 40x48 Cloud-like body (swordsman-assets.md:85)
  - v3-cand-01 48x64 still (swordsman-assets.md:103)
  - cast_overhead v1 (job ac2cb023): 'placeholder and is NOT approved' (swordsman-cast-overhead-v2.md:3)
  - cast_summon K4 first take: 'Verdict: NOT APPROVED' (swordsman-cast-command.md:72) before the accepted raise + pull-down
  - cast_hand v1, v2, v3, k2-edit, k2-mitten. v3 was approved 2026-11-10 and removed from the sheet 2026-11-11 (candidates/swordsman/cast-hand-*/QA.md)

## 10. Approval history (from the registry)

| Date | Event | Target | By | Evidence / note |
|---|---|---|---|---|
| 2026-11-11 | registered | asset | — | bootstrapped from disk by asset_registry.py; status by location only |
| 2026-10-31 | user_approved installed→approved | asset | user | art_src/units/kiem_si/clips.json source: "v3 tall anchor, approved 2026-10-31"; design/assets/specs/swordsman-assets.md:116 (Status 2026-10-31 v3) |
| 2026-11-08 | user_approved installed→approved | cast_forward | user | docs/skill-v2/skill-checklist.md tram_dia row: Animation **APPROVED** (cast_forward); art_src/units/kiem_si/clips.json note "user-approved PixMiniMax job 5e5e14ed" |
| 2026-11-08 | user_accepted | cast_summon | user | design/assets/specs/swordsman-cast-command.md:3 "ACCEPTED by the user 2026-11-08 as cast_summon"; docs/skill-v2/skill-checklist.md ngan_kiem row "ACCEPTED 2026-11-08 (cast_summon, job 91224bb1)" |
| 2026-11-10 | user_approved installed→approved | cast_hand | user | art_src/units/kiem_si/clips.json note "PixMiniMax v3 (job 2a14a25c, user-approved 2026-11-10)"; commit 03b71a4 "Knight cast_hand clip from the approved PixMiniMax v3 hand push" |
| 2026-11-11 | note | asset | — | Master Reference created: design/assets/references/characters/kiem_si.md |
| 2026-11-11 | note | cast_hand | user | dropped from the sheet. Job 2a14a25c is not installed. A hand cast holds idle. |

## 11. Open points

- 5x5 back-row head sits under the player HP panel (swordsman-assets.md:116, deferred top-row HUD issue)
- fall clip unused until the falling-cell story
- Registry `unit.kiem_si`: `status` approved (2026-10-31, evidence in §10), `acceptance` unknown. Do not treat status as acceptance.
- `palette_status`: locked. The eight sheet colours in §4 match `unit_kiem_si_sheet.json` `meta.tessera.palette` and are in `tessera_master.gpl`. No further body colour.
- Frame 96x92, `body_h` 70, sheet 872x1394: matches `docs/art/RENDER-STANDARDS.md` and the sheet JSON. Outline is the Ink already named in §4.
- Shade steps per material: unknown. Not measured on the sheet.
- Anatomy beyond §1 (a separate eye, armour or weapon spec): unknown. Do not add it.
- `cast_hand` is not on the sheet (dropped 2026-11-11, §8 and §10). §6 lists it only as a clip the code plays when the sheet has it.

Evidence folders: `production/qa/evidence/swordsman-v3`, `production/qa/evidence/guard-stance`, `production/qa/evidence/kiem-si-cast-hand`, `production/qa/evidence/skill-v2-tram-dia-art`, `production/qa/evidence/skill-v2-ngan-kiem`, `production/qa/evidence/unit-sheet-export`, `production/qa/evidence/units-centred`
