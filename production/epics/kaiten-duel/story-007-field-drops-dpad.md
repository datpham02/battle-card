# Story 007: Quầy sushi chung thay băng chuyền

> **Epic**: Kaiten Duel (v2)
> **Status**: Ready
> **Layer**: Core
> **Type**: UI
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md` (v2)
**Requirement**: Brief MVP feature 2 — quầy chung 6 đĩa đứng yên, đồng hồ độ tươi, dọn đĩa mới, chạm để lấy vào 4 ô tay

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` v2 (Core loop + MVP feature 2), scoped to this story:*

- [ ] Một quầy **6 chỗ đĩa** cố định nằm giữa hai lưới (hoặc ở dải dưới, chọn theo bố cục 1280×720), số chỗ cấu hình được.
- [ ] Mỗi đĩa xuất hiện với **đồng hồ độ tươi** (cấu hình được, khởi điểm 7 s) hiển thị rõ bằng hình (vòng/viền giảm dần) và đổi màu khi sắp ôi; hết giờ thì đĩa biến mất.
- [ ] Chỗ trống được dọn đĩa mới sau một khoảng trễ cấu hình được; loại thẻ rút từ bảng có trọng số với seed tiêm được (tái dùng logic Story 001).
- [ ] **Chạm** một đĩa để lấy vào ô tay trống; tay đầy thì chạm không có tác dụng và người chơi thấy rõ lý do; đĩa đã lấy rời quầy ngay.
- [ ] Không còn băng chuyền: `ConveyorView`/`ConveyorBelt` bị gỡ khỏi cảnh chính (giữ file nếu còn tái dùng logic, nhưng không chạy).
- [ ] Quầy có một API để một "người lấy" khác (boss, Story 008) lấy đĩa với thời gian với tay, chưa dùng ở story này.
- [ ] Ảnh chụp màn hình: quầy đầy đĩa với các mức độ tươi khác nhau, một đĩa sắp ôi, tay đầy, được giữ lại trong `production/qa/evidence/`.

---

## Implementation Notes

- Logic quầy là RefCounted (chỗ, độ tươi, dọn mới, lấy), tiêm delta; view mỏng. Tái dùng bảng thẻ và RNG có seed từ `ConveyorBelt`.
- Mọi thời gian (độ tươi, trễ dọn, cảnh báo sắp ôi) trong `assets/data/counter_plates.json`, ghi vào `schema.md`.
- Vùng chạm cỡ ngón tay; không hover.
- Cập nhật hook `--demo=`; các demo cũ dựa trên băng chuyền sửa hoặc bỏ.

---

## Out of Scope

- Story 008: boss lấy đĩa từ quầy và chơi thẻ.
- Ghép thẻ (sau MVP).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: UI
**Required evidence**:
- Retained screenshot của từng trạng thái đã chạm tới, trong `production/qa/evidence/shared-counter/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006
- Unlocks: Story 008
