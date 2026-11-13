# Monster Skill Phase 1 — Hỏa Ngục nhóm D (Inferno Lord), ảnh chụp 2026-11-13

Lệnh (mỗi ảnh một tiến trình, tuần tự, tắt tiếng):
`godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -- --pattern=inferno_lord --arena=caldera --art-region=hellfire --seed=1 --no-autopause --shot=<png> --shot-frame=<N>`
(ảnh pha 2 thêm `--pattern-hp=0.45`).

| Ảnh | Thấy gì |
|---|---|
| inferno_lord-p1-f300 | pha 1: `lord_brand` đã trúng, hero 190/200, chip Rạn (tím) góc trái |
| inferno_lord-p2-f220, f300 | pha 2 (máu 41): chỉ ô đỏ đơn của Brand. **Không** thấy khối 2×2 `lord_eruption_call` mở đầu pha 2 — đúng với lỗi on_enter (xem plan §11), chờ duyệt bản vá |
| inferno_lord-p1-f150, p2-f140 | các khung khác |

Ảnh dev không mang trait `vent_surge` / `phase_shift` của match (launcher dùng match đầu của run); quan hệ trait ↔ pattern được kiểm
bằng `pattern_hellfire_group_d_test.gd` (cùng tick, một banner, vent timer ×0,7).
