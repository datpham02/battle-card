# Story 044: Bố cục điều khiển v2 — joystick nổi, túi vòng cung, dải sân cao hơn

> **Epic**: Kaiten Duel (v6)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-31

## Context

**GDD**: `design/quick-specs/control-layout-v2.md` (mọi con số), `design/ux/hud.md` (Z2, Z3, Z5, I-06 đã cập nhật), `design/art/art-bible.md` §7.2 (nền tối chỉ ở nút), §8.2–8.3 (canvas 640x360, ô 38x27…64x46), `design/accessibility-requirements.md` (vùng chạm ≥ 88 px; câu hỏi mở "một ngón")
**Requirement**:
- **Hiện trạng:** `ScreenLayout` cho cụm điều khiển 45 % chiều cao (đáy sân 55 %, ô túi 22 %, pad 13,5 %), `dpad_view.gd` vẽ pad 3x3 cố định, `hold_slots_view.gd` xếp 3 ô thẳng hàng, dải dưới tô nền tối. Sân 5x5 chỉ còn ô 38x27 art-px.
- **Đích:** bố cục v2 theo quick spec: đáy sân 64 % cho hàng rộng, 76 % cho hàng nằm trong khe ngón cái; joystick nổi 4 hướng trong vùng x 0–25 % × y 64–100 %; 3 ô túi 130x93 px trên vòng cung; nút Thức Tỉnh 115 px sát đáy; nền tối chỉ dưới nút. Tùy chọn Settings `controls.movement = joystick | pad`.
- **Bằng chứng mock:** `production/qa/evidence/asset-slice1-art-check/11-21` (prototype `prototypes/art-check`, không tái dùng code).

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM (đổi hình học mọi màn trong trận; các suite click windowed đang bấm vào toạ độ pad và ô túi cũ; input joystick là đường mới cho `UnitMover`)
**Engine Notes**: input cảm ứng đọc qua `InputEventScreenTouch` / `InputEventScreenDrag` như `hand_input_controller.gd` đang làm; không dùng `Control`, giữ Node2D + `_draw` như toàn bộ UI hiện có.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Hình học (`src/layout/screen_layout.gd`)**

- [x] Hằng số mới theo bảng tuning knobs của quick spec §4 (`ARENA_BOTTOM_WIDE_RATIO` 0,64, `ARENA_BOTTOM_NARROW_RATIO` 0,76, `THUMB_GAP` [0,25, 0,764], `STICK_ZONE_WIDTH_RATIO` 0,25, `SLOT_HEIGHT_RATIO` 0,18, góc và bán kính cung). Giá trị cũ không còn được tham chiếu.
- [x] `cell_size()` chọn ô lớn nhất tỉ lệ 1,4 trong [38x27, 64x46] art-px (nhân 2 ở 720p) thỏa: hàng rộng hơn khe ngón cái kết thúc ≤ 64 %, hàng trong khe ≤ 76 %, mỗi nửa ≤ 298 art-px. Bảng kiểm trong quick spec §2.1 đúng tới ±1 px cho 3x3, 5x5, ring, crystal (crystal đọc từ `--arena` hay spec tạm, chưa cần có trong `arenas.json`).
- [x] Sân canh giữa ngang; canh giữa dọc trong 15,2–64 % rồi tràn xuống khi luật cho phép. Không ô nào nằm dưới nút, ô túi hay vùng joystick.
- [x] Hàm `stick_zone_rect()`, `slot_rect(i)` (vòng cung), `signature_rect()` (115 px, cách đáy 0,5·lề) thay các hàm cũ; `cell_at()` và mọi hàm chạm khác vẫn đúng.

**Phần B — Joystick (`src/combat/dpad_view.gd` hoặc file mới `src/combat/stick_view.gd`)**

- [x] Chạm xuống trong vùng Z3 → đế xuất hiện tại điểm chạm; nhấc → biến mất. Gợi ý mờ 3 s đầu trận và khi `show_control_hints`.
- [x] Vùng chết 16 px; snap 4 hướng theo góc 90°; vào hướng = bước ngay nếu hết cooldown; giữ = bước lại mỗi khi cooldown hết (dùng cooldown của `UnitMover`, không thêm số); đổi hướng = bước ngay; thả = dừng.
- [x] Khi đặt khối, vùng Z3 là nút Xoay lớn như hiện tại; joystick không nhận chạm.
- [x] `controls.movement = pad` vẽ pad 3x3 nút 88 px trong cùng vùng với hành vi cũ. Settings có mục đổi (khóa i18n `TEXT_*` mới, vi + en).
- [x] Phím mũi tên trên desktop không đổi.

**Phần C — Túi và Thức Tỉnh (`src/hold/hold_slots_view.gd`, nút Thức Tỉnh)**

- [x] 3 ô 130x93 px trên cung theo quick spec §2.3; kéo thả, đếm ô, thanh độ tươi, hẹn giờ khối hỏng, khối đang kéo nâng 56 px giữ nguyên.
- [x] Nút Thức Tỉnh 115 px sát đáy; menu 4 lá và Tung phép/Hủy/Tập trung không đè T3 khi mở.
- [x] Không còn nền tối cả dải; nền tối Mực 85 % + viền 2 px chỉ dưới từng nút và ô túi.

**Phần D — Test và bằng chứng**

- [x] Test đơn vị `tests/unit/layout/`: bảng cỡ ô ở quick spec §2.1; luật hàng rộng/hẹp; `slot_rect` không chồng nhau và ≥ 88 px; `stick_zone_rect`.
- [x] Test đơn vị cho phép đọc joystick (vùng chết, snap, giữ/đổi/thả) tách khỏi node (tiêm cooldown giả).
- [x] Các suite click windowed cập nhật toạ độ (chạy với `controls.movement = pad` khi suite cần bấm pad). Toàn bộ test `FAILS=0`.
- [x] Ảnh 1280x720 lưu `production/qa/evidence/control-layout-v2/`: 3x3, 5x5, ring (và crystal nếu đã vào `arenas.json`), joystick đang đẩy, pad tùy chọn, đặt khối với nút Xoay, menu lá mở cạnh T3, một ảnh 1600x720 kiểm lề rộng.
- [x] `design/accessibility-requirements.md`: ghi `controls.movement = pad` là đường một ngón có nút nhìn thấy; phần còn lại của câu hỏi mở giữ nguyên.

---

## Notes

- Việc thêm hình `crystal` vào `arenas.json` là story thiết kế riêng (game-designer duyệt đường bước và số ô); story này chỉ bảo đảm bố cục chứa được nó.
- Sprite và SubViewport 640x360 không thuộc story này.

## Completion Notes
**Completed**: 2026-10-31
**Criteria**: 20/20 passing, none deferred. Not tested on real touch hardware: joystick feel (device playtest, `/team-qa`).
**Deviations** (all advisory, none contradicts the quick spec's intent):
- Ring board cell is 45x32 art px at 1280x720 (forge 57x41), not 49x35: `cell_size()` also keeps every real cell off the four slot rects. User approved 2026-10-31.
- 4th bag slot (Túi Rộng) sits on an inner ring (122°, 1.05 × slot height, x 1142 y 585) because four slots on one arc always cover Cancel or reach into the arena. User approved 2026-10-31.
- Arc numbers corrected from the quick spec draft (radius 2.25 × slot height, angles 96/126/156): the draft overlapped T2/T3 by about 15x31 px. Quick spec updated.
- No Settings screen exists, so `controls.movement` is toggled from the pause panel and saved in `user://settings.json`.
- `pad` mode draws 86.4 px buttons (the 259 px zone cannot hold three 88 px buttons); each hit area grows outward to 88 px.
- Placement hint moved from the 30 px tag zone to a band across the top of the Rotate button, with a new short string.
- Confirm (green) and Rotate (blue) keep their state fills; Cancel, the menu and the slots use Ink 85 % with a 2 px frame.
- Out-of-list files touched: `src/settings/settings_store.gd` (new), `src/run/run_hud_view.gd` (pause toggle), `src/combat/cut_hud_view.gd`, `assets/i18n/strings.csv`, `design/accessibility-requirements.md`.
**Test Evidence**: UI — retained screenshots in `production/qa/evidence/control-layout-v2/` (14); unit `tests/unit/layout/screen_layout_v2_test.gd`, `tests/unit/ui/{stick_reader,settings_store,dpad_hit_area}_test.gd`; integration `tests/integration/ui/stick_flow_test.gd`. All 112 headless suites and the 6 windowed click suites FAILS=0 on 2026-10-31.
**Code Review**: Skipped (solo mode)

