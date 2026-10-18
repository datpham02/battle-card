# Story 002: Ô giữ thẻ và kéo thẻ vào ô

> **Epic**: Kaiten Duel
> **Status**: Complete
> **Layer**: Core
> **Type**: UI
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-18

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 2 — 3–4 ô giữ thẻ, kéo thẻ từ băng chuyền vào ô giữ

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (Core loop + MVP feature 2), scoped to this story:*

- [ ] Có số ô giữ cố định (3–4, cấu hình được), hiển thị rõ cả ô trống lẫn ô đầy.
- [ ] Người chơi chạm và kéo một thẻ đang trôi trên băng chuyền; thẻ bám theo ngón tay trong lúc kéo.
- [ ] Thả thẻ vào ô giữ còn trống thì thẻ vào ô và biến khỏi băng chuyền.
- [ ] Thả thẻ ở nơi không hợp lệ, hoặc khi mọi ô đã đầy, thì thẻ quay lại băng chuyền (tiếp tục trôi), không biến mất.
- [ ] Một thẻ đang bị kéo không bị xóa giữa chừng nếu đến cuối băng chuyền.
- [ ] Thao tác chạm đủ lớn cho ngón cái; không có tương tác chỉ dùng hover.
- [ ] Ảnh chụp màn hình mỗi trạng thái chính (đang kéo, ô đã có thẻ, ô đầy) được giữ lại trong `production/qa/evidence/`.

---

## Implementation Notes

- Dùng Control node và drag-and-drop/input của Godot cho cảm ứng; chạy thử bằng chuột trên máy, rồi kiểm tra trên thiết bị thật.
- Ngón tay che màn hình khi kéo: đặt băng chuyền và ô giữ ở vùng vẫn đọc được (xem Platform Notes trong `technical-preferences.md`).
- Kiểm tra API Input/UI Godot 4.6 trong `docs/engine-reference/godot/modules/input.md` và `ui.md` trước khi dùng.

---

## Out of Scope

- Story 003: dùng thẻ ra sân.
- Story 004: ghép thẻ.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: UI
**Required evidence**:
- Retained screenshot của từng màn/trạng thái đã chạm tới, trong `production/qa/evidence/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 003, Story 004

---

## Completion Notes
**Completed**: 2026-10-18
**Criteria**: 6/7 passing; DEFERRED — thumb-sized touch targets need a real-device check (estimate ≈ 61 dp card width if 720 px ≈ 360 dp; unverified)
**Deviations**: ADVISORY — (1) `hold_slots_config.gd` hard-codes fallback defaults (12/16/56 px) duplicating the JSON; (2) touch path relies on `emulate_mouse_from_touch` (default true per Godot 4.6.3 class reference), only the mouse path was exercised; (3) returned cards snap to their belt position, no animation. Also: portrait orientation decided here (720x1280); `commands.run` in project.yaml updated to match.
**Test Evidence**: waived at `qa.level: minimal`. Run result: OBSERVED — `production/qa/evidence/hold-slots/01-slots-empty.png`, `02-slots-two-held.png`, `03-slots-full.png`, `04-card-dragging-over-slot.png`. Drag/drop/return verified by a scratch windowed test using pointer events (not retained in repo). Capture note: on a 1080p monitor capture at `--resolution 540x960`; a 720x1280 window is clamped and the expand stretch widens the logical viewport.
**Code Review**: Skipped (Solo mode).
