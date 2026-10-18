# Story 006: Bộ 10–12 thẻ (Dash/Sidestep/Knockback)

> **Epic**: Kaiten Duel
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 5 — 10–12 loại thẻ (đánh, đỡ, Dash Strike, Sidestep, Knockback…)

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (Core loop + MVP feature 5), scoped to this story:*

- [ ] Có 10–12 loại thẻ khác nhau, định nghĩa hoàn toàn trong file dữ liệu ngoài (tên, hiệu ứng, recovery, thẻ nâng cấp).
- [ ] Có đủ nhóm: đòn đánh (nhẹ/thường/nặng), đỡ/giáp, và thẻ đổi làn.
- [ ] Dash Strike: lao tới và đánh, đưa người chơi sang làn của địch.
- [ ] Sidestep: đổi sang làn bên cạnh và nhận một lớp giáp nhỏ.
- [ ] Knockback: đẩy địch sang làn khác (đòn sắp tới của địch đổi làn theo, hoặc bị hụt theo quy tắc đã khai báo).
- [ ] Mỗi thẻ có định nghĩa thẻ nâng cấp cho story 004.
- [ ] Không có thẻ "Di chuyển" độc lập: mọi thay đổi làn là hiệu ứng của thẻ khác.
- [ ] Ảnh chụp màn hình từng thẻ đổi làn đang được dùng được giữ lại trong `production/qa/evidence/`.

---

## Implementation Notes

- Hiệu ứng thẻ là dữ liệu + một tập nhỏ hành động dựng sẵn (sát thương, giáp, đổi làn người chơi, đổi làn địch), không viết mã riêng cho từng thẻ.
- Giá trị cân bằng chỉ là khởi điểm; chỉnh bằng chơi thử.
- Xác nhận Knockback tương tác với đòn đang báo trước như thế nào trước khi làm (quy tắc cần chốt trong story này).

---

## Out of Scope

- Thẻ có windup/ngắt, thẻ mới ngoài bộ 10–12, tiến trình mở khóa thẻ.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Retained screenshot các thẻ đổi làn, trong `production/qa/evidence/`.
- Logic: `tests/unit/cards/card_effects_test.gd` — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004, Story 005
- Unlocks: Story 007
