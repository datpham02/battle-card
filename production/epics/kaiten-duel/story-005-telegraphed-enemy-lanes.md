# Story 005: Địch báo trước đòn trên 3 làn

> **Epic**: Kaiten Duel
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 6 — địch với đòn báo trước (biểu tượng, làn, đếm ngược) trên 3 làn cố định

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (Core loop, Player goal & fail state, MVP feature 6), scoped to this story:*

- [ ] Sân có 3 làn cố định; người chơi và địch luôn đứng trên đúng một làn.
- [ ] Địch chạy theo mẫu hành vi cố định (không ngẫu nhiên) đọc từ file dữ liệu; mỗi đòn có sát thương, làn mục tiêu và thời gian đếm ngược.
- [ ] Trước mỗi đòn, người chơi thấy biểu tượng đòn, vệt đỏ trên làn mục tiêu và vòng đếm ngược (khởi điểm khoảng 3 s ở màn đầu).
- [ ] Khi đếm ngược về 0, đòn trúng người chơi nếu người chơi đang ở làn mục tiêu; không trúng nếu đã đổi làn.
- [ ] Thẻ giáp hấp thụ sát thương đòn đó; thẻ đổi làn làm đòn hụt.
- [ ] HP người chơi về 0 thì trận thua (phát tín hiệu cho story 007); địch về 0 thì trận thắng.
- [ ] Ở màn đầu chỉ có một đòn báo trước tại một thời điểm.
- [ ] Ảnh chụp màn hình trạng thái đang báo đòn (biểu tượng, vệt làn, đếm ngược) và trạng thái đòn trúng/hụt được giữ lại trong `production/qa/evidence/`.

---

## Implementation Notes

- Mẫu đòn của địch là dữ liệu (danh sách đòn + thời gian), không logic ngẫu nhiên; tách khỏi hiển thị để test xác định.
- Thời gian báo đòn, sát thương, làn nằm trong file dữ liệu ngoài.
- Cần ít nhất một thẻ đổi làn tạm để kiểm tra "đòn hụt"; thẻ đầy đủ ở story 006.

---

## Out of Scope

- Nhiều địch cùng lúc, mẫu đòn ngẫu nhiên, ngắt đòn.
- Story 006: các thẻ Dash/Sidestep/Knockback đầy đủ.
- Story 007: cấu trúc run và boss.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshot báo đòn và kết quả đòn, trong `production/qa/evidence/`.
- Integration: `tests/integration/combat/telegraph_lane_test.gd` hoặc tài liệu playtest — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003
- Unlocks: Story 006, Story 007
