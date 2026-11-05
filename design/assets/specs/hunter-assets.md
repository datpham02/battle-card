# Asset Specs — Hunter (`tho_san`)

Art bible §5.1 hero table: T shape; crossbow slung over the shoulder, wide-brim hat with one ivory feather; brown
leather #8A5A33, olive-grey cloak (S <= 35 %), jade cord #46D6A4 (<= 6 px); brown hair, eyes 2x1 in the brim's shadow.
Reference concept `design/art/reference/04-ranger-01.png` (user approved the design 2026-11-05: "Duyệt cả ba").
Pipeline as the Assassin (`assassin-assets.md`): `create_character_pro_flash` 96x96, low top-down, 8 directions, seed 5,
style_image = Knight v3 south (colour off), palette locked, south-east anchor, clips with `animate_image_pixminimax`,
positive motion words only. Every paid call is approved by the user first, one at a time.

## ASSET-032 — Hunter sprite sheet

| Field | Value |
|---|---|
| Design (from `04-ranger-01`) | Chibi, upright, square shoulders. Wide round-brim brown hat with one ivory feather tucked in the band; **brown** hair under the brim, eyes 2x1 in the brim's shadow. Olive-grey hooded cloak with a ragged hem down to the knees, fastened by a jade clasp; a short jade cord across the chest. Brown leather jerkin, belt with a pouch and a square buckle, brown trousers, boots. A wooden crossbow slung across the back, its bow arm showing over the left shoulder and its stock behind the hip. |
| Kept from the reference | hat with feather, crossbow on the back, ragged cloak, pouch and belt, jade clasp / cord |
| Dropped from the reference | white-blond hair (brown instead); the green hat band and saturated green cloak (olive-grey, S <= 35 %, so it is not a green "elf ranger"); jade loops wider than 6 px |
| Height | visible ~66 px in the 96x96 canvas, as the Knight v3 (hat brim included) |
| Palette (locked, 8) | Ink #1B1722; leather #5C3A22 / #8A5A33; olive-grey #5E6150 / #7E8068; jade #46D6A4; skin #E3B99A; ivory #EFE6D2 (feather, buckle). No red, no orange. |
| Likeness check | Closest known looks: Van Helsing (wide hat + crossbow) and Robin Hood (feathered cap, green). Differentiated: chibi build, round wide brim (no pointed feathered cap), olive-grey not Lincoln green, brown hair, crossbow on the back (no longbow, no long coat). |
| Cast gesture (§5.1) | A: crossbow lowered to the hip. B: crossbow raised level with the shoulder, pointing right. |
| Awaken (§5.1) | Snare: drops to one knee, crossbow planted in front. |
| Clips | idle, step, cast_gesture, hit, victory, defeat, fall, awaken, draw (unslings the crossbow), step_forward / step_back / step_down |

### Anchor prompt (draft, shown to the user before the call)

> chibi hunter, about 4 heads tall, standing upright, wide round-brim brown leather hat with one ivory feather in the
> band, short brown hair, small dark eyes in the brim shadow, olive-grey hooded cloak with a ragged hem to the knees and
> a small jade clasp, thin jade cord across the chest, brown leather jerkin, belt with a pouch and a square buckle,
> brown boots, wooden crossbow slung across the back with the bow arm over the left shoulder, hands empty at the sides

| Step | Date | Tool | Settings | Cost | Output | Result |
|---|---|---|---|---|---|---|
| anchor-01 | — | `create_character_pro_flash` | 96x96 (native preset; the Mage asked 80x96 and got 96x96), low top-down, 8 directions, seed 5, palette above (max 8), style_image = Knight v3 south (colour off), prompt above | ~7 gen (to approve) | `design/assets/candidates/hunter/rot/` | — |
