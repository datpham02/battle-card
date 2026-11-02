# Asset Specs — Boss: Forest Witch (Phù thủy Rừng, `forest_witch`)

Source design: `design/quick-specs/phase2-misty-forest-2026-11-01.md` section 8 (P2.5) and D13; art bible §5.2 (Kẻ Gác row
"Phù thủy rừng"); user concept `design/art/reference/08-warden-forest-01.png` (described in words, never used as an
image input).

## ASSET-020 — Forest Witch body sprite sheet

| Field | Value |
|---|---|
| Frame | 128x128 art-px, feet on row 124 (bbox bottom), feet centre x ~62; visible ~85x121. Drawn x2 at 720p. Stands on her 2x2 footprint (D13). |
| Palette (locked) | Ink #1B1722; moss #3A4538 / #4A5545 / #5E6B55; bark #4A3A2A; mask and antlers #8A7350 / #B89A6A; hair and hands #EFE6D2 (Ngà). No red, no glow. |
| Facing | Body turned slightly left, the reaching hand toward the player (no rotation pass needed). |
| Clips (spec 8) | idle 2, move 2, windup_common 2, windup_heavy 2, phase_shift 3, hit 2, defeat 4 |
| Code-drawn, not in the sprite | Primal Shard (Mảnh Gốc) polyomino in Ánh Lưới #FFD45C over her head; phase-change square particles; markers, ivory frames, red telegraphs. |
| Likeness check | Closest known look: Leshen (The Witcher 3). Differentiated: carved wooden bird-beak mask (no deer skull), thin woman with long ivory hair, short antlers (~12 px over the head), no crows. User approved 2026-11-02. |

### Generation log

| Step | Date | Tool | Settings | Cost | Output | Result |
|---|---|---|---|---|---|---|
| anchor-01 | 2026-11-02 | `create_image_pro_flash` | 128x128, seed 1, no_background, palette locked to the 8 hex above, max_colors 8; prompt = front view, ~96 px tall, thin hunched woman, ragged moss / dead-leaf cloak to the ground, ivory hair, carved wooden bird-beak mask with two short branching antlers, bony hand reaching forward, twisted root staff close to her side; negative glow, red, flowers, crows, deer skull, floating things, background, text | 6 gen | job `f34c2791-e76b-4323-b763-ef34e23e9aee`, image `9c5a2e55-1a9f-5fc3-ab7c-6fc32014d711`; `design/assets/candidates/forest-witch/witch-anchor-cand-01-seed1-128.png` (+ `-x4.png`, `-ingame.png`) | 6 of the 8 colours (the dark and light moss unused: the cloak reads olive-brown); bbox 85x121 (taller than the 96 asked; the thin body covers only part of the two back-row cells in the in-game composite). **APPROVED by the user 2026-11-02 as the anchor.** |
| anim-idle | 2026-11-02 | `animate_image_pixminimax` | first frame = anchor-01 (download URL), 8 frames, seed 1, view low top-down, motion "slow breathing while standing still: shoulders rise and fall about 1 px, cloak tatters and hair sway, the reaching hand curls its fingers once, staff and feet planted" | 1 gen | job `d6a72828-dfe1-4f30-a33b-9d4cf9040ad4`; raw `design/assets/candidates/forest-witch/idle-raw/f0-f8.png`, strip `idle-raw-strip-x2.png`; **idle A = f0, idle B = f4** (`witch-idle-A/B-128.png`) | All 9 frames: every pixel in the locked palette, no red, feet row 124 unchanged, top row 4 -> 3. f1/f2 differ by ~120 px (breath), f3-f7 by ~1500-1900 px (shoulders and cloak shift, hand curls from f6), f8 settles back. |
