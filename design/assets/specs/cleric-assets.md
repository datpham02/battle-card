# Asset Specs — Cleric (`giao_si`)

Art bible §5.1 hero table: bell shape with a wide base; staff whose head is a square inside a square; veil; ivory-grey
robe, lead #B8BCC8, pale lilac #B9B0DC only on the staff head and the veil edge; the veil covers the hair, eyes closed
3x1. Reference concept `design/art/reference/04-cleric-01.png` (user approved the design 2026-11-05: "Duyệt cả ba").
Pipeline as the Assassin (`assassin-assets.md`): `create_character_pro_flash` 96x96, low top-down, 8 directions, seed 5,
style_image = Knight v3 south (colour off), palette locked, south-east anchor, clips with `animate_image_pixminimax`,
positive motion words only. Every paid call is approved by the user first, one at a time.

## ASSET-033 — Cleric sprite sheet

| Field | Value |
|---|---|
| Design (from `04-cleric-01`) | Chibi, calm upright pose, robe flaring into a wide bell that reaches the ground. A soft ivory veil over the head and shoulders hides the hair, with a thin pale lilac edge and a small lilac square on the brow; eyes closed (a short Ink line). Ivory-grey layered robe with wide sleeves, a lead-grey tabard down the front with one small lilac square, a plain belt. Holds a tall pale staff in the right hand, its head a square frame set inside a larger square frame (turned 45°) with a pale lilac centre. |
| Kept from the reference | veil, layered wide-sleeved robe, front tabard, square-in-square staff head, bell silhouette |
| Dropped from the reference | long blonde hair spilling out (the veil covers the hair: art bible §5.1); open eyes (closed instead); the large lilac panels and tall pointed hood (lilac only on the staff head, the veil edge and two small squares) |
| Height | visible ~64 px in the 96x96 canvas (staff head may reach ~68) |
| Palette (locked, 8) | Ink #1B1722; robe #6E7282 / #B8BCC8 / #E2E3EA; lilac #8F86B8 / #B9B0DC; skin #E3B99A; staff ivory #D8CDB0. No red, no gold, no saturated purple. |
| Likeness check | Closest known looks: Final Fantasy's White Mage (white hooded robe) and generic fantasy nuns. Differentiated: no red triangle trim, no hood with ears, a soft veil with closed eyes, the square-in-square staff (no cross, no orb). |
| Cast gesture (§5.1) | A: staff held upright. B: staff tilted, its head pointing out level with the head. |
| Awaken (§5.1) | Blessing: both hands on the staff planted down, head bowed. |
| Clips | idle, step, cast_gesture, hit, victory, defeat, fall, awaken, draw (optional), step_forward / step_back / step_down |

### Anchor prompt (draft, shown to the user before the call)

> chibi cleric, about 4 heads tall, calm upright pose, soft ivory veil over the head and shoulders hiding the hair,
> thin pale lilac edge on the veil and a small lilac square on the brow, eyes closed, ivory-grey layered robe with
> wide sleeves flaring into a wide bell shape to the ground, lead-grey front tabard with one small lilac square, plain
> belt, holding a tall pale staff in the right hand whose head is a square frame set diagonally inside a larger square
> frame with a pale lilac centre

| Step | Date | Tool | Settings | Cost | Output | Result |
|---|---|---|---|---|---|---|
| anchor-01 | — | `create_character_pro_flash` | 96x96 (native preset; the Mage asked 80x96 and got 96x96), low top-down, 8 directions, seed 5, palette above (max 8), style_image = Knight v3 south (colour off), prompt above | ~7 gen (to approve) | `design/assets/candidates/cleric/rot/` | — |
