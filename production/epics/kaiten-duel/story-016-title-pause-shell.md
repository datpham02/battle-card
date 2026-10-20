# Story 016: Vỏ game — màn title, tạm dừng, nút back, tắt dòng debug

> **Epic**: Kaiten Duel (v3)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-20

## Context

**GDD**: `design/game-brief.md` (v3)
**Requirement**: Sau Story 015 game có vòng lặp đầy đủ (chọn tầng → đánh → qua tầng) nhưng vẫn mở thẳng vào màn chọn tầng, không tạm dừng được, và HUD còn dòng debug "né | ngắt | giả" của boss học (Story 010). Trước khi lên máy thật (Story 018) cần cái vỏ tối thiểu: title, tạm dừng, nút back của Android, và dòng debug chỉ hiện khi bật cờ dev.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: nút back Android tới dưới dạng `NOTIFICATION_WM_GO_BACK_REQUEST`; cần tắt `application/config/quit_on_go_back` trong `project.godot` để tự xử lý. Tạm dừng dùng `freeze_time` sẵn có của `CombatView` (Story 012/dev), **không** dùng `get_tree().paused` để d-pad/menu không rơi vào chế độ pause của Godot.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

- [ ] **Màn title** (`TitleView`): tên game vẽ bằng code, nút *Tiếp tục* (chỉ khi có tầng đang dở trong save; → vào thẳng trận đang dở), nút *Chơi* (→ màn chọn tầng), nút *Thoát* (ẩn trên iOS theo cờ nền tảng; Android/desktop thì thoát). Là màn đầu tiên khi mở game. Dev args (`--floor`, `--demo`, `--run`, `--match`, `--arena`) **bỏ qua** title và chọn tầng như hiện nay để test/chụp không đổi.
- [ ] **Tạm dừng trong trận**: nút nhỏ góc trên (≥ 64 px chạm) hoặc phím Esc; mở lớp phủ "TẠM DỪNG" với *Tiếp tục* và *Về chọn tầng* (thoát tầng = tính như thua: không ghi tiến độ, không hoàn tác). Khi tạm dừng: mô phỏng đứng hẳn (cả đồng hồ vung, rơi điểm, trait, Tập trung), d-pad và tay không nhận chạm, đồng hồ Tập trung không chạy. Tiếp tục không có đếm ngược (quyết định: trận ngắn, thêm đếm ngược là ma sát).
- [ ] Tạm dừng **không** mở được trong menu kỹ năng (đang 0,2×) và trong 0,5 s cuối của một đòn đang vung (số trong `combat.json`: `pause_lockout_sec`) để không dùng tạm dừng làm "xem trước đòn"; khi không mở được, nút mờ.
- [ ] **Nút back Android**: trong trận = tạm dừng; trong tạm dừng = tiếp tục; ở chọn tầng = về title; ở title = thoát. Esc trên desktop làm y hệt.
- [ ] **Dòng debug boss học** (và mọi dòng debug khác trong HUD) chỉ vẽ khi có arg `--debug`; mặc định ẩn. Không xóa mã: cờ `CombatView.debug_overlay` đặt từ `DemoArgs`/`GameFlow`.
- [ ] Màn chọn tầng có nút *Về* (→ title). Mọi nút mới dùng cùng kiểu vẽ với nút của Story 011/015 (một hàm vẽ nút chung trong một view tiện ích, không copy).
- [ ] Ảnh trong `production/qa/evidence/shell/`: title; tạm dừng giữa trận (thấy đồng hồ vung đứng yên ở hai ảnh cách nhau ≥ 1 s); nút tạm dừng mờ khi menu kỹ năng mở; HUD không còn dòng debug; HUD có dòng debug với `--debug`.
- [ ] Không hằng số gameplay/UI trong mã ngoài `ScreenLayout`; chuỗi hiển thị là `const TEXT_*`.

---

## Implementation Notes

- `GameFlow` (Story 015) thêm pha TITLE trước FLOOR_SELECT; back/Esc là một hàm `go_back()` theo pha.
- Tạm dừng: `RunController.set_paused(bool)` → `CombatView.freeze_time = true` + khóa input của `DPadView`/`HandInputController`/`CutHudView` qua một cờ chung `input_locked` (Focus của Story 012 đã khóa d-pad bằng `_is_locked()`, mở rộng hàm đó thay vì thêm nhánh mới). `FocusController.tick_real` không được gọi khi tạm dừng.
- `--debug` đọc trong `DemoArgs` cùng chỗ với các arg khác.

---

## Out of Scope

- Cài đặt (âm lượng, rung), ngôn ngữ, accessibility.
- Xuất Android và kiểm trên máy → Story 018.
- Hình/âm thật → phase 7.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: UI
**Required evidence**:
- Retained screenshot of each screen touched trong `production/qa/evidence/shell/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 015 (GameFlow, màn chọn tầng), Story 012 (khóa input khi Tập trung)
- Unlocks: Story 018 (lên máy thật)
