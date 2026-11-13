# Monster Skill Phase 1 — Hỏa Ngục nhóm C (Elite), ảnh chụp 2026-11-13

Lệnh (mỗi ảnh một tiến trình, tuần tự, tắt tiếng):
`godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -- --pattern=<id> --arena=<forge|caldera> --art-region=hellfire --seed=<1|2> --no-autopause --shot=<png> --shot-frame=<N>`
(ảnh Pyre thêm `--pattern-hp=0.45`).

| Ảnh | Thấy gì |
|---|---|
| fire_eater-forge-f260 | `eater_ember_belch` vừa trúng: lửa trên ô hero và ô ngay dưới (đường thẳng đứng qua hero), hero 186/200 (12 + một tick 2), chip Cháy góc trái |
| fire_eater-forge-f380 | lửa của Belch còn cháy; khung ngà nhấp nháy quanh Eater = `eater_devour` đang niệm, có thể ngắt |
| ash_phoenix-caldera-f260 | `phoenix_ash_dive` trúng: hero 188/200, chip Rạn (tím) góc trái |
| ash_phoenix-caldera-hp45-f200 | `phoenix_pyre` (máu 45 %): chữ L 3 ô đỏ cạnh hero, không gồm ô hero; khung ngà liền = không ngắt được |
| còn lại | cùng trận ở khung khác |

Ghi chú: trait `burn_eater` / `rebirth` của match KHÔNG có trong ảnh dev (`--pattern=` dùng match đầu của run, không mang trait của
match Hỏa Ngục); hai trait đó được kiểm bằng test (`pattern_hellfire_group_c_test.gd`). Banner tên vùng/quái là của dev launcher.
