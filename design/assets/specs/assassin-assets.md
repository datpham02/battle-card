# Asset Specs — Assassin (`sat_thu`)

Art bible §5.1 hero table: flat rhombus, crouched, the **shortest hero**; pointed hood, two daggers across the chest;
charcoal cloth #3A3744 with jade-white #BFF3EC only on the blades and the hood edge; face mask, only the eyes show.
Reference concept `design/art/reference/04-rogue-01.png` (user approved the design 2026-11-05: "Duyệt cả ba").
Pipeline as the Mage (ASSET-030): `create_character_pro_flash`, low top-down, 8 directions, style from the Knight v3
south rotation (`design/assets/candidates/swordsman/v3-tall/v3t-knight-south-84.png`, outline / detail / shading only),
palette locked; the south-east rotation (3/4 facing right) is the anchor; clips with `animate_image_pixminimax` from
the anchor, **positive motion words only** (negative words painted red on the Mage). Every paid call is approved by the
user first, one at a time.

## ASSET-031 — Assassin sprite sheet

| Field | Value |
|---|---|
| Design (from `04-rogue-01`) | Chibi, crouched wide stance, knees bent. Pointed square-cut hood (tip falls back) with a small jade-white diamond emblem on the forehead and a jade-white hood edge; dark cloth mask over the nose and mouth; charcoal fringe of hair under the hood; eyes 2x2 Ink. Short charcoal capelet, brown leather bracers, belt with a square buckle, wrapped legs, brown boots. Two short daggers held **reverse grip**, crossed in front of the chest at rest. |
| Kept from the reference | hood shape and diamond emblem, mask, reverse-grip daggers, crouch, capelet |
| Dropped from the reference | white-blond hair (art bible §5.1: no five white-haired heroes; charcoal hair instead); the flying teal scarf (clashes with the Hunter's jade cord); skin-tone cheeks wider than the eyes |
| Height | visible ~58 px in the 96x96 canvas (Knight v3 66, Mage 65): the shortest hero |
| Palette (locked, 8) | Ink #1B1722; cloth #2C2A35 / #3A3744 / #555064; leather #5E4636 / #8A6A50; jade-white #BFF3EC; skin #E3B99A (eye band only). No red, no orange, no ice blue. |
| Likeness check | Closest known looks: the hooded assassins of *Assassin's Creed* (Altaïr / Ezio). Differentiated: chibi crouched build, square pointed hood with a diamond emblem (no eagle-beak hood), charcoal cloth (no white robe, no red sash), reverse-grip short daggers (no hidden blade). |
| Cast gesture (§5.1) | A: daggers crossed in front of the chest. B: both arms flung out, blades pointing right. |
| Awaken (§5.1) | Shadow Dash: low lunge forward; the two darker after-images are code, not frames. |
| Clips | idle, step, cast_gesture, hit, victory, defeat, fall, awaken, draw (optional), step_forward / step_back / step_down (dash), as the Knight and the Mage |

### Anchor prompt (draft, shown to the user before the call)

> chibi rogue assassin, about 4 heads tall, crouched wide stance with knees bent, pointed square-cut hood whose tip
> falls back, small pale jade diamond emblem on the hood front, pale jade trim along the hood edge, dark cloth mask
> over nose and mouth, short charcoal fringe under the hood, small dark eyes, short charcoal capelet, brown leather
> bracers, belt with a square buckle, wrapped legs, brown boots, holding two short daggers in reverse grip crossed in
> front of the chest, pale jade blades

| Step | Date | Tool | Settings | Cost | Output | Result |
|---|---|---|---|---|---|---|
| anchor-01 | 2026-11-05 | `create_character_pro_flash` | 96x96, low top-down, 8 directions, seed 5, palette above (max 8), style_image = Knight v3 south 84x84 (upload `8efc54de`, colour off), prompt above | 7 gen (approved: "Duyệt, gen 7 gen") | character `47d6480b-8685-429a-9971-8f28145d6bdb`, job `ba18ae67`; `design/assets/candidates/assassin/rot/` (8 rotations), preview `assassin-vs-knight-mage-x4.png` | 7 colours, no red. Reads at a glance: pointed hood with jade trim, mask, jade reverse-grip daggers, crouch. south-east bbox 42x67 (Knight 31x66, Mage 32x65): **as tall as the Knight, not ~58** (the crouch went into width), and the south-east view is turned only slightly from the front. Hood emblem came out as a small cross, not a diamond. Likeness: closest the hooded assassins of *Assassin's Creed* / a generic ninja; differs by the chibi crouch, square pointed hood, charcoal cloth, no white robe or red sash. **Approved by the user as the anchor** ("Duyệt làm gốc", 2026-11-05): height equal to the Knight is fine; the cross emblem is kept (no hand painting). Clips are made from `rot/south-east.png`. |
| anim-idle | 2026-11-05 | `animate_image_pixminimax`, first frame = `rot/south-east.png` (rotation URL), 8 frames, seed 1, low top-down, south-east; prompt "calm ready idle in a low crouch, shoulders rise and fall gently with breathing, the hood tip sways slightly, both daggers stay crossed in front of the chest with the blade tips shifting a little, feet planted" | 1 gen (approved: "Gen thử idle") | job `352a7f82-1c49-4242-a197-d148798928ff`; raw `anim/idle/f0-f8.png` (f0 = input), strip `anim-idle-raw-x4.png` | **Clean**: every frame 7 colours, 0 red, feet row 80 fixed, bbox 41-42 x 65-67 (head breathes 2 px), f8 returns to f0 so it loops. |
| anim-11clips | 2026-11-05 | `animate_image_pixminimax` x11, same first frame and settings as anim-idle, positive motion prompts only (step, cast_gesture, hit, victory, defeat, fall, awaken, draw, step_forward, step_back, step_down; prompts as proposed to the user) | step `aa9bd847`, cast `0172ee9f`, hit `e1fb8dcc`, victory `70c8d999`, defeat `505383fc`, fall `66a4bb2d`, awaken `5caa3f37`, draw `77835371`, forward `eddb6e2d`, back `fbdc6ca3`, down `c01eed60` | 11 gen (approved: "Duyệt, gen 11 clip"; one call refused by the 10-job limit and re-sent, not billed twice) | raw `anim/<clip>/f0-f8.png`, strips `anim-<clip>-raw-x4.png` | 0 red in every frame. Off-palette only on smear frames (cast f1-f4 light anti-aliasing, hit f2 blade smear, awaken f3, back f3). Good: idle, step, cast (cross then fling right), hit f3-f5, victory (dagger raised), defeat (kneel), awaken (held lunge, capelet streaming), step_forward, step_down. Weak: draw ends with the daggers crossed high (a small pose jump into idle); fall does not drop, it turns toward the camera with arms up (f5-f8 used; the game moves the unit). **step_back rejected**: teleport with speed lines, cut at the canvas edge. |
| sheet-01 | 2026-11-05 | local Godot cleanup (free, `build_frames` with this palette, feet row 80, crop rows 11..80) + `export_sheets.py --units sat_thu` | snap to the 8 colours, specks < 12 px removed, pieces lifted onto row 80; draw / step_forward / step_down recentred on the head (x 46); 6 colours added to `art_src/palette/tessera_master.gpl` | 0 | `art_src/units/sat_thu/` (idle 8 @125 loop, draw 8 once, step 4 @100 loop, step_forward / step_down 7 @50 once, cast_gesture 9 on the Knight timings, hit 3 @40, victory / defeat 8 @100 hold_last, fall 4 @100 hold_last, awaken 5 @120 loop); `assets/art/units/unit_sat_thu_sheet.png` 872x780; evidence `production/qa/evidence/assassin-sprite/` | In battle (bot, Goblin Archer, won 22 s, 0 violations): guard pose, cast fling. sheet_export, sprite_sheet, unit_animator, roster_sprite, unit_step_glide tests pass. Assassin total: anchor 7 + clips 12 = **19 gen**. Back-dash and up-step play `step`. |
| fix-cast-hold | 2026-11-05 | local (free) | user, with an in-battle crop: "cái này có phải bị lỗi ko" — the held cast frame (raw cast f1-f4, daggers crossed in an X over the face) read as a glitch / a crossed-out unit at battle size. cast_gesture frames 1-4 replaced by idle 1-4 (the low guard of the anchor); frame 0 and the fling (raw f5-f8) kept, timings unchanged | 0 | `art_src/units/sat_thu/cast_gesture/1-4.png`, sheet re-exported; evidence `production/qa/evidence/assassin-sprite/04-cast-hold-guard.png` (card menu open, guard held, face clear) | User chose "Đổi sang thế thủ". sheet_export, sprite_sheet, roster_sprite, cast_hold_short_clip tests pass. |
| anim-cast-xslash | 2026-11-05 | `animate_image_pixminimax`, first and last frame = `rot/south-east.png`, 8 frames, seed 1, south-east; prompt "from the low guard: pulls both daggers back and up above the shoulders into a coiled wind-up and holds, then two fast diagonal slashes crossing in an X in front of the body to the right at chest height, arms ending crossed low, a short follow-through, then returns to the same low guard" | 1 gen (approved: "Duyệt, gen 1 gen"; user: "động tác cast skill của sát thủ xấu quá, làm cho nó chém chéo nhau") | job `66c2c370-7430-4261-8b0f-97b410c4c0ef`; raw `anim/cast_xslash/f0-f8.png`, strip `anim-cast_xslash-raw-x4.png`, cleaned `cast-xslash-clean-x4.png` | 0 red; only the slash frame f4 off-palette (anti-aliased smear, snapped to two flat jade arcs). **Installed as `cast_gesture`** (same 9 frames and timings): f0, f1, f2, f2, f3 (daggers raised above the shoulders = hold frame 4, face clear), f4 (jade X slash = frame 5, 50 ms), f5, f6 (arms crossed low), f8 (guard). Replaces fix-cast-hold and the arms-flung-out take. In battle: follow-through after the hit (`production/qa/evidence/assassin-sprite/05-...`); the 50 ms X frame is in `06-xslash-cast-frames.png`. Assassin total: 20 gen. |
| evidence-note | 2026-11-05 | — | — | 0 | — | `02-cast-fling-right.png` and `04-cast-hold-guard.png` removed: they showed cast takes replaced by anim-cast-xslash. Kept: 01 (guard in battle), 03 (anchor vs Knight / Mage), 05, 06 (X slash). |
| v2-dash-4clips | 2026-11-15 | `animate_character` pixminimax x4, south-east, 8 frames, keep_first_frame, `custom_start_frame_url` = one upload of `rot/south-east.png` | the Swordsman v7 dash wording (hold ONE leaning shape for four frames, end back in the low guard), plus two clauses this character needs: **no speed words anywhere** (the 2026-11-05 `step_back` came back as a teleport with speed lines) and "every part of the body stays inside the frame with a clear margin on all four sides" (that clip was also cut at the canvas edge, and this anchor is 42 px wide against the Knight's 31) | 4 gen (approved: "Gen 4 clip") | groups: forward `6d43b009`, back `6cb500e7`, up `0d9467fe`, down `34d110e4` | **0 off-palette pixels in all 36 frames** — no speed lines, and nothing reaches an edge: the widest frame is `dash_back` f6 at x 15-77 of 96. forward, back and down all WIDEN through the hold (42 px idle -> 53 / 63 / 50), which is the body opening into the lean. **`dash_up` fails the same way it has for every character: it NARROWS to 34-37 px through the hold**, the signature of the figure turning to a profile or back view. The Knight's v3 step_up (2026-11-02) and the Mage's (2026-11-04) were rejected for exactly this. Three characters, three failures, one direction: this is a property of the model, not luck. "the shoulders stay square to the lower right" is not enough; the next attempt states the SILHOUETTE WIDTH, which is the thing that can be measured. |
| v2-dash-4clips VERDICT | 2026-11-15 | — | — | 0 (4 already spent) | — | **Not installed, and they will not be: they animate the wrong body.** These four clips were generated against the 2026-11-05 dagger anchor, but `docs/design/character-system/CHARACTER-VISUAL-REDESIGN.md` (approved by the user 2026-11-14) replaces it: `sat_thu` becomes **Quill**, and the 2026-11-14 decision "bỏ hẳn" removes weapon shapes from all five heroes — no daggers, and no empty sheaths either. Every frame here holds two daggers. **The cause was mine: this file predates the redesign, and I read it and stopped.** The redesign doc is the one that governs, and nothing in this file pointed at it until now. Cost: 4 generations. What survives is free — the dash wording (hold one shape, end in the guard, no speed words, stay inside the frame) and the measurement that catches a bad "up" clip. |

> **Read `docs/design/character-system/CHARACTER-VISUAL-REDESIGN.md` before generating anything for
> this character.** Quill's approved design: shortest of the five and the only crouched one, a flattened
> spindle; a cloth face wrap with a narrow eye slit; charcoal `#3A3744` strapped close at every joint; a
> high narrow hood with a sharp angular peak; **both hands low and empty, fingers spread**; no cloak, no
> loose fabric, no weapon and no sheath. Open conflict **C3** in that doc is unresolved and blocks the
> anchor: her accent `#BFF3EC` is a near-Chill value that §5.1 forbids, and it passed only because the
> daggers carried it over a few pixels. With the daggers gone the accent has to grow, so it needs a new
> value or a recorded exception before any paid call.

## Quill anchor — checklist for approval (nothing generated yet)

Settled 2026-11-15: accent is **bone white `#EFE6D2`** (C3 resolved in the redesign doc).

**Palette is already locked — no new value needed, so C4 does not apply.** All six are in
`tessera_master.gpl`: ink `#1B1722`, assassin cloth dark `#2C2A35`, assassin cloth `#3A3744`,
assassin cloth light `#555064`, skin `#E3B99A`, accent `#EFE6D2`. `#BFF3EC` is retired from this
character. The two assassin leathers (`#5E4636`, `#8A6A50`) are dropped: the design says cloth
strapped at the joints, not leather.

**Likeness check, per the standing rule — the closest known character is `Sheik` (Zelda):** a face
wrap with a narrow eye slit, wrapped limbs, a light agile build. Also near: a generic shinobi, and the
hooded assassin of *Assassin's Creed* (named in the 2026-11-05 check). What separates Quill, in the
order a player would notice at 40 px: a **sharp angular peaked hood** against Sheik's soft cowl;
**empty hands held low with the fingers spread**, against a character defined by what they throw;
**permanently crouched, the shortest of the five**, against Sheik standing tall; **charcoal and bone
white only**, against Sheik's white-and-blue with the Sheikah eye.

| # | Must be true of the anchor | How it will be checked |
|---|---|---|
| 1 | Shortest of the five: visibly under Vale's and Ilva's 63 px | measure the south-east bbox |
| 2 | Crouched in every rotation — a flattened spindle, never upright | south-east bbox wider than tall in the upper body |
| 3 | Both hands low, close to the body, fingers spread, **empty** | look: no weapon, no sheath, no scabbard |
| 4 | Face wrap with one narrow horizontal eye slit, nothing else of the face | look |
| 5 | High narrow hood with a sharp angular peak — the most angular of the five | look |
| 6 | Cloth strapped close at wrists, waist, knees, ankles; nothing loose, no cloak | look |
| 7 | Accent only at the hood edge and the cuffs, a thin line, not a mass | count accent pixels: under 8 % of the body |
| 8 | Exactly the six locked colours, alpha 0/255 | `frame_stats.gd` with the palette |
| 9 | Inside the canvas with a margin on all four sides | bbox against the canvas |

Canvas 84x84, 8 directions, low top-down, south-east is the anchor the game mirrors — the same
settings as Vale v5 and Ilva, so the install pipeline is unchanged.

| quill-anchor-01 | 2026-11-15 | `create_character_pro_flash` | 84x84, 8 directions, low top-down, seed 5, palette = the six locked colours, max_colors 6, style_image = Vale v5 south rotation; description from the approved design prompt plus a negative clause (daggers, sheaths, cloaks, bulk, armour) | 6 gen (approved: "Duyệt, gen anchor") | character `70e50d90-48a6-487a-94cd-664d318960c4`; rotations in the session scratchpad | **5 of 9 checklist items pass, 1 fails, 1 was not measured, 2 are judgement.** PASS: south-east bbox 34x58 — **58 px is the shortest of the five** (Vale and Ilva are 63); **0 off-palette pixels**, 5 of the 6 locked colours (`#2C2A35` unused); margins on all four sides (25 / 26 / 16 / 11); hands low, open and **empty — no weapon, no sheath**; face wrap with one narrow eye slit; a high hood with a sharp angular peak; cloth strapped at wrists, knees and ankles with nothing loose. **FAIL item 2: it is not crouched.** It stands close to upright in a wide stance, where the design calls for "permanently slightly low, a flattened spindle" — and being the only crouched hero is Quill's single most distinctive silhouette trait. The build also reads stocky and broad rather than spindly, which weakens the separation from Bram's T shape. Item 7 (accent under 8 %) was **not measured**: the anchor fails item 2 regardless, so measuring a frame that will be discarded would be wasted work. Likeness: with the daggers gone it reads as a generic shinobi, which the 2026-11-05 check already named as the near miss. **Next attempt must state the crouch as geometry, not as a word** — the hips at mid-thigh height, the head no higher than a standing figure's shoulders — because "crouched" alone did not survive. |

### Why anchor-01's costume reads badly (user 2026-11-15: "sao bộ đồ trông xấu vậy")

Looked at 6x, not guessed. Five specific faults, each with its cause in the prompt:

1. **The hood is a plain cone.** It is the largest shape on the character and has no structure at
   all — no brim, no fold, no seam — so it reads as a dunce cap or a garden gnome rather than
   tailored cloth. The prompt asked for "a high narrow hood with a sharp angular peak" and got
   exactly that and nothing more.
2. **The body is one flat dark mass.** `#3A3744` covers torso, arms and legs with almost no
   `#555064`, so there is no shoulder line, no chest, no belt — a sack with limbs. The prompt never
   said where the mid tone goes, so none of it went anywhere.
3. **The accent is scattered blotches, not trim.** Three or four pale lumps at each wrist, knee and
   ankle read as bandages or dirt. "Accent at the hood edge and the cuffs" was taken as "put the
   accent on every joint".
4. **Accent and skin blur together.** `#EFE6D2` bone and `#E3B99A` skin are close in value, so the
   wrist straps and the bare hands merge into one pale smudge.
5. **Gnome proportions.** A huge hood over a short wide body with stubby legs — a consequence of
   asking for "shortest of the five" without saying where the height is lost.

**Fixes for the next anchor, all stated as placement rather than adjectives:** a hood whose peak is
swept back with a folded brim across the forehead and one centre seam; `#555064` reserved for the
shoulders, the chest and the outer legs so the body has form, with `#2C2A35` for the shadow side (it
went unused last time); the accent as **one continuous thin line** along the hood rim and the front
edge of the tunic, and **off the joints entirely**; the joint straps in dark charcoal so bare hands
stay the only skin-coloured thing; the height lost from the **torso**, not the legs.

> **Amendment to the approved design, flagged rather than done quietly:** the redesign doc says the
> accent sits "at the hood edge and cuffs only". Moving it off the cuffs is a change to that line, and
> the reason is fault 4 — at this size the cuffs put bone white next to skin and both turn to mush.

| quill-anchor-02 | 2026-11-15 | `create_character_pro_flash` | same settings, seed 6, description rewritten so every instruction is a PLACEMENT rather than an adjective: the crouch as geometry (hips at mid-thigh, head no higher than a standing figure's shoulders, height taken from the torso), the hood with a folded brim and one seam with the peak swept back, `#555064` named for shoulders / chest / outer legs and `#2C2A35` for the shadow side, the accent as one continuous line on the hood rim and the tunic front edge and nowhere else, joint straps in dark charcoal so the bare hands are the only skin | 6 gen (approved: "Gen lại anchor") | character `1db79b8d-0726-4ae1-99f5-5e67153b1389` | **All five costume faults fixed, and the crouch with them.** The hood has a brim and an edge line instead of a cone; shoulders, chest, a tunic front edge and a waist line all read; the accent is one line, no blotches at the joints; the hands are the only skin-coloured area; the figure is genuinely folded down over its knees. Measured: south-east bbox **40x63**, **0 off-palette pixels**, and **all six locked colours are now in use** — `#2C2A35` went unused in v1, which was fault 2's cause, and naming where it goes fixed it. Margins 24 / 21 / 14 / 8. **Checklist item 1 now FAILS: 63 px is level with Vale and Ilva, not shorter** (v1 was 58). The crouch bought the silhouette at the cost of the height: folded down to 63 px he would stand near 75. Items 5 and 7 are weaker but pass: the peak is less sharply angular than v1's cone, and the accent is a thin line by eye, not counted. |

> **ACCEPTED 2026-11-15 (user: "Nhận").** `quill-anchor-02`, character
> `1db79b8d-0726-4ae1-99f5-5e67153b1389`, is the Quill anchor. The 8 rotations are saved in
> `design/assets/candidates/assassin/quill-2026-11-15/rot/` (md5-verified out of the session
> scratchpad on the spot, rather than left in a temp folder the way the Ilva rotations were).
>
> **Checklist item 1 is formally waived, not quietly dropped:** Quill is 63 px, level with Vale and
> Ilva, not the shortest of the five. Of the two silhouette traits the redesign gives her, "the only
> crouched one" is kept and "the shortest" is given up, because the crouch is the one that reads at
> 40 px in battle and the height difference never did. `docs/design/character-system/CHARACTER-VISUAL-REDESIGN.md`
> still says "shortest" and now disagrees with the sprite; that is an art-director edit to that file,
> flagged here rather than made.
>
> Anchor cost for Quill: 12 generations (6 rejected, 6 accepted).

| quill-idle-01 | 2026-11-16 | `animate_character` pixminimax, south-east, 8 frames, keep_first_frame, **straight from the character** (no upload: unlike Ilva's, this anchor is the unmodified rotation, so nothing is lost by animating it directly) | positive-only: chest rises and falls 1 px, shoulders settle, hood rim and tunic edge shift 1 px, hands stay low and open, **the hips stay at the same height through every frame so the crouch is held**, feet planted, last frame returns to the opening pose | 1 gen (approved: "Gen thử idle") | job `38154bfc-09c4-4008-8555-dfed941b3e5d`, group `64725c21-6153-4e70-8f0d-ec720c7f6e34` | **Control passed.** All 9 frames: bottom row 84, **feet x 32-41 identical on every frame** (no drift at all), 6 colours and **0 off-palette pixels**, and the crouch is held throughout — he never straightens, which was the risk worth 1 generation to test. Frame 1 and frame 9 share a bbox, so the loop closes. The body rises 4 px at the peak of the breath (bbox top 22 -> 18 -> 22), larger than Vale's 1-2 px; acceptable for a crouched figure, worth a look in battle. Stored canvas is **100x100**, not the anchor's 84x84, so the clips need the same crop-and-replant step as the other two heroes. |

| quill-12clips | 2026-11-16 | `animate_character` pixminimax x12, south-east, straight from the character, keep_first_frame; 8 frames for the long clips, 4 for step / hit / fall / awaken | the five movement clips in the Swordsman v7 dash wording with the crouch pinned ("the hips stay low", "the body rises back into the low crouch"); the seven action clips as the shipping set, hands stated empty throughout | 12 gen (approved: "Gen 12 clip") | groups: forward `1e1e29d7`, back `c3eb8df6`, up `2974bd95`, down `e58b883e`, step `35c8d9ff`, cast `7cfa9310`, hit `e7be26c0`, victory `ced6cff2`, defeat `23db44b3`, fall `1bcaf0f2`, awaken `159e9cef`, draw `5d8a80ef`; raw frames rescued to `quill-2026-11-15/raw-clips/` | **12 of 12 usable. 11 of 12 have 0 off-palette pixels**; only `fall` has 89 (anti-aliasing on the flung arms), the same recoverable kind proved on the Mage. Starting width is 40 px on every clip; `cast_gesture` dips to 34 only during the coil, which the prompt asked for. |

### The "up" direction, solved — and why it took four characters

`dash_up` holds **39 px against a 40 px start**, and the face wrap is visible in every frame. It does
not turn away. That is the **first** time the up direction has survived: the Knight's v3 step_up
(2026-11-02), the Mage's (2026-11-04) and the old Assassin's (2026-11-15) were all rejected for
turning into a profile or a back view.

Every failed attempt gave the model a **direction**: "keeping the guard and facing right", "the
shoulders stay square to the lower right". Every one of those describes where the character points,
and the model satisfied it while rotating the body. The attempt that worked gave it a **measurable
quantity instead**: *"the silhouette stays at least as wide from left to right in every frame as it
is in the first frame, with both shoulders, both arms and both legs visible throughout."*

That is the same instruction as the test that catches the failure — a clip that turns away narrows.
**Writing the prompt in the units of the check is what fixed it**, and the same move fixed "crouched"
on the anchor two steps earlier. Worth trying on Vale's and Ilva's step_up clips, which still carry
the old wording.

| quill-install | 2026-11-16 | mechanical cleanup + install + export | snap to the six colours, drop clusters < 12 px, replant each frame's bottom row, crop 100x100 -> **96x92** at x 2..97 | 0 | `art_src/units/sat_thu/` (13 clips, 85 frames), candidates in `quill-2026-11-15/{raw-clips,clean-96x92}/`, sheet `unit_sat_thu_sheet.png` **872x1208** | **The frame had to grow from 96x70 to 96x92.** Quill is 63 px crouched, so every clip that lifts the body put pixels on row 0 of a 70-row frame. `clips.json` carries the frame size, `body_h` stays 70 so the HUD and portraits keep framing the old body height, and the registry is updated to match. The Swordsman made the same move for the same reason. **The exporter caught this, not my own check: I had verified "touches_edge=0" while only testing x < 1 and x > 94 — I never looked at y = 0.** A one-sided edge test returns a clean zero and reads like proof. The rescan over all four edges found **16 frames across 7 clips**, not the one the exporter happened to name. After the rebuild all 85 frames are 96x92, feet on row 91, no contact on any edge, at most 6 colours, 0 off-palette. Five suites green: sheet_export, sprite_sheet, art_assets, unit_step_glide, unit_animator. Recording: 38 dash events, capture hash `42577dce...` differs from the earlier runs, so the new art is on screen. |

| dash-motion-gap | 2026-11-16 | `unit_motion.json` (data only) | user: "với phần di chuyển bạn quên làm theo kiểu dash rồi ạ?" | 0 | `sat_thu` and `phap_su` given `dash_ease` / `ghost_count` / `ghost_gap` / `lean_px` | **The user was right and the cause was a scope I set myself.** The Swordsman dash work put `dash_ease` and the ghost trail on `kiem_si` alone, and the commit message even boasted that "every other unit is byte-identical" — correct when written, wrong the moment Ilva and Quill shipped with dash CLIPS and the default braking curve and **zero** afterimages. Now tuned per character: `sat_thu` 1.3 ease / 3 ghosts / 0.03 gap (it is the fastest hero, step x0.9), `phap_su` 1.5 / 2 / 0.04. Capture hash moved from `42577dce...` to `b558cdd1...`, so the change is on screen. A narrow scope is right when it is written and has to be revisited every time something new enters it. |

| quill-anchor-03 | 2026-11-16 | `create_character_pro_flash` | 84x84, seed 7, palette widened to 8 (the two assassin leathers brought back for straps and wraps); description written from the user's reference sheet **in words, not uploaded as a style image** — the practice this project already follows for `04-knight-01` and `04-mage-01` | 6 gen (approved: "Thiết kế lại") | character `5e05e92a-3aee-4543-a60a-703e684b8e90` | **The costume is fixed and the crouch is lost.** Present and good: the half-cape over the far shoulder with a pointed tail, the diagonal chest strap with a buckle, layered leather forearm wraps, wrapped boots with cuffs, a draped hood with the peak falling back, eyes visible in a band. The torso is no longer a flat mass. Two faults: **it stands close to upright again**, the trait v2 had won, and a **large skin-coloured patch sits on the near shoulder** reading as a bare arm, which the design does not call for. Measured: bbox 45x63, 0 off-palette, 7 of 8 colours (`#5E4636` unused). |

### Three anchors, three trades — naming the pattern instead of rolling again

| | silhouette | costume | colours used |
|---|---|---|---|
| v1 (34x58) | upright | flat, cone hood, blotchy accent | 5 of 6 |
| v2 (40x63) | **crouched** | plain but clean | 6 of 6 |
| v3 (45x63) | upright | **the one the user asked for** | 7 of 8 |

Each anchor won one axis and gave back another. The user's own rule forbids re-roll loops, so a fourth
attempt is only worth making if it carries a **reason**, not a new seed. The reason available: v2's crouch
survived when the crouch was the FIRST thing in a short description; v3 front-loaded six costume elements
and the crouch clause, though present and identically worded, was buried. The next attempt therefore
states the crouch first AND last, cuts the costume to the four elements that actually landed, and pins the
skin ("the only skin is the narrow eye band and the two bare hands") to kill the bare shoulder. If that
does not hold both, the honest move is to pick the best of the four and stop, not to keep paying.

> **ACCEPTED 2026-11-16 (user: "Chọn bản v3").** `quill-anchor-03`, character
> `5e05e92a-3aee-4543-a60a-703e684b8e90`, is the Quill anchor. The 8 rotations are saved in
> `design/assets/candidates/assassin/quill-v3-2026-11-16/rot/`, md5-verified on the spot. v2 is retired;
> its rotations stay in `quill-2026-11-15/rot/` as history, and the 13 clips generated from it (12
> generations) are superseded and will not be installed.
>
> **Two things are waived, and the second is worth more than it looks:**
> 1. The **bare shoulder patch** stays — a skin-coloured area on the near arm the design never asked for.
> 2. **Quill is no longer crouched, and no longer the shortest.** The redesign doc gave her exactly two
>    silhouette traits and she now has neither. What separates her from the other four heroes at battle
>    size is now the **half-cape's asymmetry** and nothing else. That is thinner than the design intended,
>    and `CHARACTER-VISUAL-REDESIGN.md` still describes her as "the shortest of five heroes and the only
>    crouched one" — it disagrees with the sprite on both counts now, not one. An art-director edit to that
>    file is owed; flagged here rather than made.
>
> Anchor cost for Quill across three attempts: **18 generations** (12 rejected, 6 accepted).

| quill-v3-idle | 2026-11-16 | `animate_character` pixminimax, south-east, 8 frames, keep_first_frame, straight from the character | positive-only: chest 1 px, shoulders settle, **cape tail sways and returns**, hood rim 1 px, **the chest strap and buckle stay exactly where they are on the body**, hands low, feet planted, last frame returns | 1 gen (approved: "Gen thử idle") | job `d6d99dd4-d088-467d-b5f5-900acbb84399`, group `e91af822-ac02-4508-9801-ea0b121bd366` | **Control passed, and it tested the right thing.** The two new elements are the ones animation breaks: all 9 frames keep the **chest strap and buckle on the body** (no sliding) and the **cape attached at the far shoulder**. Feet x 34-60 identical on every frame, bottom row 80 on every frame, 7 colours and **0 off-palette**. The cape tail swings 5 px on the left edge (24 -> 29 -> 24) against the 1-2 px asked for; that is cloth reading as cloth, not a fault. Loop closes. Stored canvas 96x96 this time, not 100x100 — read it per clip rather than assuming. |

| quill-v3-12clips | 2026-11-16 | `animate_character` pixminimax x12, south-east, straight from the character | movement in the v7 dash wording with the cape pinned ("the cape stays attached at the far shoulder") and the strap pinned ("the chest strap stays on the body"); action clips as the shipping set | 12 gen (approved: "oke làm đi") | groups: forward `b6e586ec`, back `e34e4304`, up `152bb12e`, down `00f67556`, step `99d7cc83`, cast `422cd8fb`, hit `4a2610fb`, victory `3d1be783`, defeat `09f23c10`, fall `30c97a00`, awaken `801688e3`, draw `7aeb9fed` | **11 of 12 clean, 1 needs the snap.** Off-palette is 0 everywhere except `fall` at 345 px (flung arms plus a flaring cape) — the recoverable kind, as proved on the Mage. The cape stays on the shoulder and the chest strap stays on the body in every clip. Widths start at 45: `dash_down` and `defeat` widen as they should, `cast_gesture` reaches 63 on the extended arm. |

### Correction: the "up" direction is NOT solved

An earlier section in this file says the width instruction **solved** the up direction, on the strength of
Quill v2's `dash_up` holding 39 px against a 40 px start. **That was one data point and I wrote it as a
conclusion.** On the v3 anchor the identical instruction produced `dash_up` at **33 px against a 45 px
start** — a 27 % narrowing, and the strip shows the body turning to a near profile with the cape wrapping
across the front. Milder than the full back view that killed three earlier attempts, but the same drift.

So the honest score for "state the silhouette width instead of a facing direction" is **one success, one
failure**, not a fix. What changed between them is worth noting for whoever tries next: v2 was crouched
and capeless, v3 stands and has a cape — either the cape gives the model something to rotate, or the
crouch was what held the shoulders square and the width instruction merely rode along with it.

The earlier section is left in place rather than rewritten, with this correction below it, so the
sequence of what was believed and when stays readable.

| quill-v3-install | 2026-11-16 | mechanical cleanup + install + export | snap to the eight colours, drop clusters < 12 px, replant each frame's bottom row, crop 96x96 -> 96x92 at full width | 0 | `art_src/units/sat_thu/` (13 clips, 85 frames), candidates in `quill-v3-2026-11-16/{raw-clips,clean-96x92}/`, sheet `unit_sat_thu_sheet.png` 872x1208 | **All 85 frames: 96x92, feet on row 91, no contact on ANY of the four edges, at most 8 colours, 0 off-palette — `fall`'s 345 off-palette pixels snapped clean**, as the Mage's worst clip did. The crop offset is 0 here, not the 2 used for the v2 clips: that anchor stored at 100x100 and this one at 96x96. Read the canvas per clip; a number carried over from the previous batch would have shifted every frame 2 px. Five suites green (sheet_export, sprite_sheet, art_assets, unit_step_glide, dash_ghost) and `art_check` reports no FAIL. Recording: 30 dash events, capture hash `dfa28069...` against the v2 build's `b558cdd1...`, so the new art is on screen. **Quill total: 44 generations** — 18 anchor across three attempts, 1 control idle on v2, 12 clips on v2 (superseded), 1 control idle on v3, 12 clips on v3. |
