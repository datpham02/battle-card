# Story 001: Băng chuyền sinh thẻ, trôi và biến mất

> **Epic**: Kaiten Duel
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-18

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 1 — băng chuyền sinh thẻ, thẻ trôi qua và biến mất nếu không lấy

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (Core loop + MVP feature 1), scoped to this story:*

- [ ] Thẻ xuất hiện đều đặn ở một đầu băng chuyền theo khoảng thời gian cấu hình được.
- [ ] Mỗi thẻ trôi với tốc độ không đổi (cấu hình được) tới đầu còn lại.
- [ ] Thẻ trôi hết băng chuyền mà không được lấy thì bị xóa khỏi cảnh, không rò rỉ node.
- [ ] Loại thẻ sinh ra được chọn ngẫu nhiên từ bảng thẻ đọc từ file dữ liệu bên ngoài; hạt giống ngẫu nhiên tiêm được để test xác định.
- [ ] Băng chuyền chạy liên tục và độc lập với việc người chơi làm gì.
- [ ] Tốc độ và khoảng thời gian sinh thẻ nằm trong file cấu hình, không hard-code.
- [ ] Ảnh chụp màn hình băng chuyền đang chạy (nhiều thẻ trên băng chuyền) được giữ lại trong `production/qa/evidence/`.

---

## Implementation Notes

- Mã nguồn ở `src/` (gốc code của Godot); dữ liệu cấu hình ở `assets/data/`.
- GDScript có kiểu tĩnh, signal snake_case thì quá khứ (`card_spawned`, `card_expired`).
- Logic sinh/trôi tách khỏi node hiển thị để test được không cần cảnh.
- Kiểm tra API Godot 4.6 trong `docs/engine-reference/godot/` trước khi dùng (HIGH risk).

---

## Out of Scope

- Story 002: ô giữ và kéo thẻ.
- Story 006: bộ thẻ đầy đủ (ở đây dùng vài thẻ giả).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Retained screenshot trong `production/qa/evidence/` (thứ người chơi nhìn thấy).
- Logic: `tests/unit/conveyor/conveyor_belt_test.gd` — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 002

---

## Completion Notes
**Completed**: 2026-10-18
**Criteria**: 7/7 passing (no deferred items)
**Deviations**: ADVISORY — (1) `conveyor_config.gd` hard-codes fallback defaults that duplicate the JSON; (2) `conveyor_belt.json` has no schema/units doc; (3) `ConveyorBelt.get_cards()` exposes the internal array and there is no `take_card()` yet — Story 002 must add it.
**Test Evidence**: waived at `qa.level: minimal`. Run result: OBSERVED — `production/qa/evidence/conveyor-belt/01-belt-early-frame10.png`, `02-belt-running-frame119.png`. Node-leak and seeded-determinism checks were run via a scratch script (not retained in repo).
**Code Review**: Skipped (Solo mode); informal GDScript specialist review during `/dev-story` found no bugs.
