# Card art — in-game evidence (2026-11-13)

`gallery-1..6.png`: every card of `assets/data/cards.json` drawn by the game's own `CardFace.draw_skill` (ancient face,
reward-screen size 176x256) at 1280x720, locale vi, after `godot --import`. Capture script (design tool, not game code):
`design/assets/candidates/ui/card-art/scripts/card_gallery_capture.gd`, run windowed with `--audio-driver Dummy`.
Logs: `import.log` (0 errors), `capture.log`.

Observations (Claude, for the user's review — not an approval):
- The 47 new pictures read clearly at x2 inside the frame; background #2C2A35 sits well in the gold picture border.
- The 13 old pictures (page 1, plus kiem_khi / suong_mong etc.) use navy #1F2835 or black backgrounds: visibly different from the new set (Q7).
- Weak at this size: gai_nguyen (dark twig almost lost), tran_gai (dim spiral), thien_quang (thin pillar), bay_kep (reads as a ring), min_tre (busy).
- Still code-drawn: cuong_phong (no passing image), vung_lay (mire colours undefined).
- Not captured: battle hand / cooldown column, shop, phone resolution.

## Recapture 2026-11-13 21:02 (after replacing the 13 old arts and 4 weak ones)

`gallery-1..6.png` now show all 60 arts under the Master Reference (import 0 errors; run alongside two other
sessions' headless Godot jobs, user: "Chạy song song"). Previous capture kept in `before-replace/`.
Observations: page 1 now matches the rest (same #2C2A35 background); gai_nguyen, thien_quang, bay_kep, min_tre read
clearly; still weak: tran_gai (dim ring/spiral), kiem_khi (slash reads a little like a feather). Still code-drawn:
cuong_phong, vung_lay.
