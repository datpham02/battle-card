# Monster Skill Phase 1 — Hỏa Ngục nhóm B (lửa cắt đường), ảnh chụp 2026-11-13

Lệnh (mỗi ảnh một tiến trình, tuần tự, tắt tiếng):
`godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -- --pattern=<id> --arena=<forge|caldera> --art-region=hellfire --seed=1 --no-autopause --shot=<png> --shot-frame=<150|260>`

| Ảnh | Thấy gì |
|---|---|
| flame_cultist-caldera-f260 | `cultist_kindle`: 2 ô bên trái hero đang cháy, hero 200/200 (không ô nào dưới chân); cột mạch phun 1 và 4 cảnh báo (địa hình) |
| magma_slug-forge-f260 | `slug_lava_spit`: ô đỏ dưới chân hero; ô Sên vừa rời (nửa địch) đang cháy, chip lửa trên Sên = `slug_molten_trail` |
| hell_knight-caldera-f150 | `knight_cleave`: thanh đỏ trên hàng hero (bị cắt bởi cột khuyết của caldera, `clip` + `min_cells 2`); khung ngà = không ngắt được |
| các ảnh còn lại | cùng trận ở khung khác |

Banner "Misty Forest · Goblin Scout" là của dev launcher (`--pattern=` thay match đầu của run), không phải lỗi nhóm B.
