# OSFE card layout — measured proportions for Tessera's card faces

**Source:** One Step From Eden (GOG build owned by the user). The blank spell-card sprite was read from the
game's own UI bundle (`OSFE_Data/StreamingAssets/AssetBundles/sprites_ui`) with UnityPy into the session's
temporary folder outside the project, and measured there. **Nothing from the game is in this repository**: no pixels, no
colours, no traced shapes — only the proportions below, in our own words. Read 2026-11-01.

**Why:** user 2026-11-01: our cards looked "thô và cồng kềnh" (heavy, clunky) next to OSFE's "thon gọn và hài
hòa" (slim, balanced). The user asked to learn the layout and keep Tessera's own art style.

## What makes the OSFE card read as slim

1. **No frame.** The card is a flat panel with slightly cut corners; there is no border art at all. Every
   other element floats on the panel.
2. **Two big corner diamonds** carry the numbers, so the numbers are the first thing read. They sit in the
   corners, touching the card edges.
3. **One picture square** in the upper half, outlined by a line only slightly lighter than the panel.
4. **Text below the picture**, centred, small, one size.
5. Two or three colours in total.

## Proportions (W = card width, H = card height)

| Element | Measure |
|---|---|
| Card | W:H = 0.69 |
| Corner cut | ~4% of W |
| Cost diamond (top-left) | bounding box ~0.34 W, centre at (0.18 W, 0.12 H) |
| Damage diamond (bottom-right) | bounding box ~0.36 W, centre at (0.81 W, 0.87 H) |
| Picture square | ~0.42 W wide, from 0.175 H to 0.47 H, thin low-contrast outline |
| Text block | from ~0.5 H down to the damage diamond |
| Name | on the top line, right of the cost diamond |

## How Tessera uses it (`src/ui/card_face.gd`)

User 2026-11-01: "vẫn giữ phong cách cổ, chỉ lấy layout thôi" and "đừng làm border to quá". So the layout above
is drawn with Tessera's own ancient art:

- Style "ancient" (default): a PixelLab card frame (`assets/art/ui/cards/card_frame_ancient.png`, Pro Flash
  88x128, 6 gen) — a 1 px bronze border, a dark weathered slate panel, a blue gem top-left, a red gem
  bottom-right, a carved picture slot at the top. Drawn at the menu's density (x2 at 720p) = the 176x256 card
  face, the same size on every screen (`ScreenLayout.CARD_FACE_SIZE`).
- Code places only the content on the frame's measured geometry (`ANCIENT_*` constants): the name on the top
  line, the 32 px picture's centre 28 px in the slot, the effect text (one size, cooldown appended), the price at
  the foot in the shop, the numbers on the gems (the red gem dimmed on a card without damage).
- Relic tiles, the "Bỏ 1 lá" slot and the detail panel keep the menu's stone frame.
- DEV arg `--card-style=ancient|slim|stone` keeps the code-drawn slim version and the first thick stone frame
  for comparison.
