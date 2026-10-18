# Story 010: Bảng cân bằng cắt + Đốt, Ghim + boss học bằng bộ đếm

> **Epic**: Kaiten Duel (v3)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-18

## Context

**GDD**: `design/game-brief.md` (v3)
**Requirement**: Brief MVP feature 5 — bảng cân bằng cắt; hai kỹ năng còn lại (Đốt, Ghim); boss "học" bằng bộ đếm trong trận

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` v3 (Menu kỹ năng; MVP feature 5), scoped to this story:*

- [ ] **Đốt** (≥ 5 ô, cooldown 8 s): tập ô cháy trong thời gian cấu hình (3 s), đứng trong ăn sát thương dần theo tick cấu hình; ô cháy hiện rõ và chặn đường nhặt. **Ghim** (≥ 7 ô, cooldown 10 s): trúng thì đối thủ không bước được trong thời gian cấu hình (1,2 s), hiện rõ trạng thái. Cả hai dùng chung khung `skills.json` của Story 008, không mã riêng từng kỹ năng ngoài tập hành động dựng sẵn (sát thương, đẩy, đặt trạng thái ô, đặt trạng thái đơn vị).
- [ ] Boss dùng được cả bốn kỹ năng với cùng dữ liệu; brain có trọng số cho từng kỹ năng.
- [ ] **Bảng cân bằng cắt** sau cổng chơi thử 3, ghi trong `cuts.json`/`skills.json` với chú thích: sát thương cơ bản, vung cơ bản/mỗi ô, hệ số theo số điểm nếu cần (ví dụ đa giác 4 điểm nhân thêm), ngưỡng ô của kỹ năng. Mỗi thay đổi so với khởi điểm trong brief có một dòng lý do trong `schema.md`.
- [ ] Boss **học bằng bộ đếm** cấu hình được: người chơi bước né sớm N lần liên tiếp → tỉ lệ **feint** (vung rồi hủy, mất điểm rẻ) tăng; người chơi để tay đầy chờ đòn to → boss ưu tiên đòn nhanh để ngắt; người chơi ngắt đòn thành công nhiều → boss chuyển sang 1 điểm. Tất cả là số trong `boss_brain.json`.
- [ ] Feint hiển thị khác với đòn thật sau khi hủy (người chơi hiểu mình vừa bị lừa).
- [ ] Ảnh chụp màn hình: Đốt đang cháy, Ghim trúng, một lần feint — giữ lại trong `production/qa/evidence/card-set-adaptive-boss/`.

---

## Implementation Notes

- Hiệu ứng là dữ liệu + tập hành động dựng sẵn; trạng thái ô (cháy) và trạng thái đơn vị (ghim) là hai bảng nhỏ trong `CombatState`, tiêm delta.
- Giá trị cân bằng là khởi điểm; chỉnh bằng chơi thử, ghi lý do.
- Giữ `boss_brain.json` đọc được bằng mắt: mỗi quy tắc có tên và chú thích trong `schema.md`.

---

## Out of Scope

- Ghép thẻ (sau MVP). Meta progression. Nhiều boss khác nhau (Story 011 dùng bộ trọng số khác nhau cho từng trận, kỹ năng là chung). Thủ đoạn rơi của boss (backlog).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Retained screenshot trong `production/qa/evidence/card-set-adaptive-boss/`.
- Logic: `tests/unit/combat/skill_effects_test.gd` — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 009
- Unlocks: Story 011
