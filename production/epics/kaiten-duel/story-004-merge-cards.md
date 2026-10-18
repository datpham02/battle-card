# Story 004: Ghép 2 thẻ giống nhau

> **Epic**: Kaiten Duel
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 3 — ghép 2 thẻ giống nhau thành thẻ nâng cấp

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (Core loop + MVP feature 3), scoped to this story:*

- [ ] Kéo một thẻ trên băng chuyền hoặc từ ô giữ sang một thẻ giống hệt trong ô giữ thì hai thẻ ghép thành một thẻ nâng cấp, chiếm một ô.
- [ ] Thẻ nâng cấp mạnh hơn thẻ gốc theo giá trị khai báo trong file dữ liệu (mỗi loại thẻ có định nghĩa thẻ nâng cấp của nó).
- [ ] Ghép hai thẻ khác loại bị từ chối; thẻ quay về chỗ cũ, không mất thẻ nào.
- [ ] Số lần ghép tối đa cho mỗi lượt/trận là hữu hạn (cấu hình được); khi hết lượt ghép, ghép bị từ chối và người chơi thấy rõ lý do.
- [ ] Thẻ đã nâng cấp không ghép tiếp (một cấp nâng cấp trong MVP).
- [ ] Ghép giải phóng một ô giữ, có thể nhặt thẻ mới vào.
- [ ] Ảnh chụp màn hình trước và sau khi ghép được giữ lại trong `production/qa/evidence/`.

---

## Implementation Notes

- Quy tắc ghép (cùng loại, hết lượt, đã nâng cấp) nằm trong logic thuần để test xác định.
- Bảng thẻ nâng cấp và giới hạn ghép nằm trong file dữ liệu ngoài, không hard-code.
- Tái sử dụng cơ chế kéo thả của story 002.

---

## Out of Scope

- Ghép nhiều cấp, công thức ghép khác loại (ngoài MVP).
- Story 006: bộ thẻ đầy đủ.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Retained screenshot trước và sau ghép, trong `production/qa/evidence/`.
- Logic: `tests/unit/cards/card_merge_test.gd` — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002
- Unlocks: Story 006
