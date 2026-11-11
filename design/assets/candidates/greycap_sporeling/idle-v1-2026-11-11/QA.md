# QA — idle v1 (2026-11-11)

## Request
- Asset: `unit.greycap_sporeling` · clip `idle`
- Why: P2 pilot: 4-frame breathing idle per docs/art/P2-GREYCAP-IDLE-HANDOFF-2026-11-11.md

## Call
- Provider / tool: pixellab / animate_character
- Ids: job f90a856a-140a-446e-99bd-4cfcfe0c0925 · character 5705da35-be85-49c2-9704-555fbe8c755e · effect —
- Seed: — · Cost: 1 generation
- Params: `{"mode": "v3", "directions": ["south-west"], "frame_count": 4, "keep_first_frame": true, "canvas": "64x76", "animation_group_id": "ac4c6b8f-0ce7-458b-a921-75c214250250", "server_animation_name": "idle_v2_2026-11-11"}`
- Prompt: Idle breathing loop, four frames numbered 0, 1, 2 and 3, facing south-west. Frame 0 stays the pinned start pose. On frame 1 the big cap rises one pixel. On frame 2 the big cap stays one pixel higher and the two side caps rise one pixel. On frame 3 all three caps return to the frame 0 pose. The root base and both feet stay on the same pixels. Cap shapes, body width, and the one-pixel dark outline stay unchanged. Flat colour bands only.
- Source anchor: `art_src/units/greycap_sporeling/idle/0.png`

## Measured
frame 0 = anchor, feet fixed, no red; FAIL amplitude (cap +3..6 px, body +1..3 px/side, 400-620 px redrawn) and palette (54-94 off-palette px per frame)

Report: `QA.md`

## Verdict
- Technical: FAIL
- User: **accepted** (2026-11-11) — user 2026-11-11: 'Cài thay idle cũ' after viewing preview/old-vs-snap-x3.png

## Snap pass (user: "Snap màu thử", 2026-11-11)
clean/0..3.png: nearest-colour snap to the 8 locked hex, crop rows 12..63 of the 64x76 canvas to 64x52 so the feet sit on the bottom row (x 30-34, c 32). Mechanical only, nothing repainted.

| Frame | px snapped | px clipped above the crop | bbox after | colours |
|---|---|---|---|---|
| clean/0 | 0 | 0 | 15,5,43,51 | 7 |
| clean/1 | 94 | 0 | 15,2,43,51 | 7 |
| clean/2 | 69 | 4 | 14,0,45,51 | 7 |
| clean/3 | 85 | 4 | 13,0,46,51 | 7 |

Palette now PASS. Amplitude unchanged (cap top reaches row 0, 4 px of the cap tip lost on frames 2-3). Sheet: preview/old-vs-snap-x3.png (row 1 current idle, row 2 snapped candidate). Not installed; user decides.

## Install (2026-11-11)
- integrate.py clip BLOCKED (registry entry is `installed`, tool takes accepted/candidate only) -> manual install on the same path:
  clean/0..3 -> art_src/units/greycap_sporeling/idle/0..3.png and the sheet_export_test copies design/assets/candidates/greycap/clean-64x52/idle/.
  Previous idle frames kept in design/assets/candidates/greycap/clean-64x52/idle-pre-2026-11-11/.
- export_sheets.py refused frames 2-3 (opaque pixel on row 0, bible 8.3 wants a 1 px top margin): row 0 cleared on 7 columns and
  the Ink outline moved to row 1 (mechanical). Sheet re-exported 389x264, clips.json idle note added, ms/loop unchanged.
- Godot --import; sheet_export_test, sprite_sheet_test, roster_sprite_test: FAILS=0.
- In-game: production/qa/evidence/greycap-idle-v2/ (tools/qa/greycap_idle_footage.gd, muted), strip_x2.png = 6 frames, the last three show the installed clip.
- Not committed.
