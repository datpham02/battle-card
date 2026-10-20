# Story 010: Bảng cân bằng cắt + Đốt, Ghim + boss học bằng bộ đếm

> **Epic**: Kaiten Duel (v3)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-20

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
- [ ] ~~Bảng cân bằng cắt~~ **Dời** sang đợt cân bằng sau Story 011 (quyết định cổng 3: hoàn thiện trước, cân bằng sau). Story này giữ nguyên mọi số hiện có; chỉ thêm số mới cho Đốt, Ghim và bộ đếm học.
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

---

## Completion Notes
**Completed**: 2026-10-20
**Criteria**: 5/5 passing; the balance-table criterion was deferred by the user's gate-3 decision ("complete the game first, balance later") and every existing number was kept.
**Deviations**: ADVISORY: a Burn that covers the target's cell counts as touching it, so it cancels the target's running swing although it deals no direct damage. ADVISORY: the boss-learning debug line ("né / ngắt / giả") is drawn in all builds and must be hidden before release. ADVISORY: demos use the boss's private `_do_cut` / `_tick_feint` and the DEV-ONLY flag `force_next_feint`. Burn/pin pickup-blocking and the learning behaviour are verified by scratch tests only (no screenshot).
**Test Evidence**: Logic story, tests waived at `qa.level: minimal`. Retained screenshots `production/qa/evidence/card-set-adaptive-boss/01-06*.png` (all opened and checked). Scratch scripts (not retained): status effects 32/32, learning thresholds and feint rates (16 feints vs 0), boss set comparison, swing arbiter, two real-mouse flow tests. No unit tests saved for `StatusEffects`, `BossLearning` or the arbiter.
**Code Review**: Skipped (solo mode).
**Not verified**: feel of Burn/Pin/feint in a real match; touch on a device.
**Carries to Story 011**: nothing blocking. Run reset must also clear `StatusEffects`, `BossLearning`, skill cooldowns and burning cells; each match needs a new boss brain with the weight set from `run.json`.
