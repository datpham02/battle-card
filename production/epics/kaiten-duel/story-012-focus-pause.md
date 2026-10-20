# Story 012: Tập trung — dừng hẳn trận khi nối điểm (có giới hạn và cooldown)

> **Epic**: Kaiten Duel (v3)
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-20

## Context

**GDD**: `design/game-brief.md` (v3)
**Requirement**: Phản hồi chơi thử sau Story 011 — vừa di chuyển vừa chọn điểm nối quá khó; khi bắt đầu nối điểm trận phải **dừng hẳn** để người chơi nhìn và chọn thêm, nhưng thời gian dừng có giới hạn và có cooldown, không dừng mãi. Thay ý "Tập trung chậm 0,5×" trong backlog.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

- [ ] **Kích hoạt**: khi Tập trung đang sẵn sàng (hết cooldown), mỗi lần tay có ≥ 1 điểm được chọn (và không đang mở menu kỹ năng, không ai đã chết) thì **toàn bộ mô phỏng đứng yên**: boss, đồng hồ vung của cả hai bên, điểm rơi, độ tươi, cooldown bước và cooldown kỹ năng, ô cháy/ghim. Chọn thêm, bỏ chọn, xem trước số ô và sát thương vẫn hoạt động.
- [ ] **Giới hạn**: tối đa `focus_max_sec` (4 s **thời gian thật**); có thanh đếm ngược hiện cạnh nút Chốt. Hết giờ thì trận chạy lại, **điểm đang chọn được giữ**, không tự Chốt, không mất gì.
- [ ] **Kết thúc sớm**: bấm Chốt, hoặc bỏ chọn hết điểm, kết thúc Tập trung ngay. Sau Chốt 2–4 điểm menu kỹ năng mở như cũ (làm chậm 0,2×).
- [ ] **Cooldown**: mọi cách kết thúc đều bắt đầu cooldown `focus_cooldown_sec` (8 s thời gian thật). Trong cooldown, chọn điểm **không** dừng trận (đòn nhanh 1 điểm vẫn làm như cũ); hiện rõ "Tập trung còn N s".
- [ ] **Không di chuyển được khi đang dừng** (`focus_locks_movement` = true): nút di chuyển mờ đi và phím tắt bị bỏ qua; bước đã bấm không được xếp hàng.
- [ ] Boss không có Tập trung. Một bên đã chết thì Tập trung không kích hoạt và đang chạy thì kết thúc.
- [ ] Mọi số (`focus_time_scale` 0,0, `focus_max_sec`, `focus_cooldown_sec`, `focus_locks_movement`) nằm trong `assets/data/skills.json`, ghi vào `schema.md`; `focus_time_scale` > 0 cho phép đổi từ "dừng hẳn" sang "chậm" mà không sửa mã.
- [ ] Không có vòng lặp vô hạn hay chia cho 0 khi bước thời gian bằng 0 (trọng tài, vung, cooldown).
- [ ] Ảnh chụp: đang Tập trung (lớp phủ, thanh còn lại, nút di chuyển mờ, xem trước số ô); Tập trung đang cooldown với số giây; được giữ lại trong `production/qa/evidence/focus-pause/`.

---

## Implementation Notes

- `FocusController` RefCounted: sẵn sàng / đang chạy / cooldown; đồng hồ thời gian thật tiêm vào; tín hiệu `started`, `ended(reason)` với reason là `confirmed`, `deselected`, `timeout`, `death`.
- `CombatView` lấy hệ số mô phỏng = hệ số menu kỹ năng khi menu mở, hệ số Tập trung khi Tập trung chạy; đồng hồ thật (menu, Tập trung) không bị nhân.
- Khóa di chuyển ở `try_step_player` và ở `DPadView`.
- Đây là ý "Tập trung" trong `design/ideas-backlog.md` nhưng **dừng hẳn** theo yêu cầu người chơi (không phải 0,5×).

---

## Out of Scope

- Cân bằng số khác của trận (nhịp boss, độ khó trận 1): đợt cân bằng sau.
- Boss có Tập trung; Tập trung cho kỹ năng khác.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshot trong `production/qa/evidence/focus-pause/`.
- Integration: `tests/integration/combat/focus_pause_test.gd` — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 008, Story 011
- Unlocks: đợt cân bằng

---

## Completion Notes
**Completed**: 2026-10-20
**Criteria**: 9/9 passing.
**Deviations**: ADVISORY: pressing Confirm while the confirm is blocked (own swing still running, or all covered cells missing) does not end Focus (agent's judgement call). ADVISORY: the "TẬP TRUNG" label is drawn inside the bar because only ~25 px of vertical room exists above the confirm button. ADVISORY: the "ready" indicator is a faint dot at the bar's left end. Bad `focus` values fall back to defaults with a warning (including a negative cooldown). `SwingArbiter.tick` got an explicit early return for `delta <= 0`.
**Test Evidence**: Integration; tests waived at `qa.level: minimal`. Retained screenshots `production/qa/evidence/focus-pause/01-focus.png`, `02-focus_timeout.png`, `03-focus_cooldown.png` (all opened and checked). Scratch scripts (not retained): FocusController 19/19; a real-scene flow test (match frozen 1 s real incl. boss cell, drop freshness and boss step cooldown; d-pad ignored; timeout at 4.04 s with selection kept; selecting during cooldown does not freeze and a 1-point cut works; ready again after 8 s; deselect, confirm and death each end it with the right reason). The old pick-up scratch test is still occasionally flaky (unseeded random drop lands on its target cell); a guard was added, one failure in three runs remained afterwards.
**Code Review**: Skipped (solo mode).
**Not verified**: how 4 s / 8 s feel in play; touch on a device; whether locking movement during Focus is too strict (switch `focus_locks_movement` to false in `skills.json` to test).
