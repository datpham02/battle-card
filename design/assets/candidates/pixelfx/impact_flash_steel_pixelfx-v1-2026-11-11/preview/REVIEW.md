# Review — impact_flash_steel_pixelfx-v1-2026-11-11 (2026-11-11)

Source: pack impact_flash_steel_pixelfx-v1-2026-11-11 · 7 frames · 80×64 art px · 50 ms/frame · one-shot

## Look at
- `preview/contact_x4.png` — every frame at 4× on the ground colour; judge silhouette, palette, feet row, outline.
- `preview/anim.gif` — the timing; judge the read at 1× distance too (shrink the window).

## Technical QA
Technical verdict: **PASS** (`tools/qa/art_check.py candidate`)
- PASS packs [design/assets/candidates/pixelfx/impact_flash_steel_pixelfx-v1-2026-11-11]: fxc check clean (layer overlay)
- PASS png: 1 PNG decode, all RGBA 8-bit
Adapter / fxc check: **PASS**; info stats: 7 frames x 50 ms = 350 ms, 80x64, up to 40 clusters a frame, 16 single-px specks in all

## Known issues
upstream hit-flash is a red/white flash with radial lines; rendered with the steel ramp, 7 of 11 frames kept (350 ms overlay rule); glow dropped at alpha < 128

## Suggested revision (if rejected)
render with --fps 20 and a 6-frame window, or adapt the effect file to end by frame 6; try --alpha bayer for the glow

## Decision
Accept this candidate, ask for a retake with the suggested revision, or reject it.
Record the answer: `python -X utf8 -I tools/asset-pipeline/candidate.py verdict design/assets/candidates/pixelfx/impact_flash_steel_pixelfx-v1-2026-11-11 --acceptance accepted|rejected --by user --evidence "<the user's words>"`

**Waiting for the user's decision.**
