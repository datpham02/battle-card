# Story 009: Parry/Counter, Posture và hậu quả hai chiều

> **Epic**: Kaiten Duel (v2)
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md` (v2)
**Requirement**: Brief MVP feature 4 — Parry/Counter trong cửa sổ cuối khoảng vung; boss rơi thẻ + choáng; thanh Posture → loạng choạng; người chơi xóa recovery

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` v2 (Core loop + MVP feature 4), scoped to this story:*

- [ ] Thẻ *Parry*: dùng khi boss đang vung và còn ≤ cửa sổ cấu hình được (khởi điểm 0,5 s) tới lúc phát động → đòn boss **bị hủy** (thẻ boss rơi, không phát động). Dùng ngoài cửa sổ → chỉ là thẻ đỡ yếu (giáp nhỏ).
- [ ] Thẻ *Counter*: như Parry nhưng thay choáng bằng **phản đòn** lên boss (sát thương cấu hình được) nếu boss trong tầm.
- [ ] Parry thành công → boss bị **Choáng** (cấu hình, khởi điểm 2 s): không chơi thẻ, không lấy đĩa, không bước.
- [ ] Thanh **Posture** của boss hiện trên HUD; mỗi parry/counter cộng một lượng cấu hình; đầy thì boss **Loạng choạng** (khởi điểm 3,5 s): đòn người chơi nhân hệ số cấu hình (khởi điểm ×2), boss không bước; hết thì Posture về 0.
- [ ] Người chơi parry thành công → **recovery xóa ngay** (có thể chơi thẻ tiếp tức thì). (Buff thay thế "Focus" ghi trong backlog, chưa làm.)
- [ ] Hậu quả theo loại thẻ bị parry, từ dữ liệu: parry đòn nặng → boss *Mất thăng bằng* (nhận thêm sát thương lần tới); parry thẻ Step → boss bị đẩy lùi một ô nếu có chỗ.
- [ ] Kết quả đòn là enum (HIT / MISS / PARRIED / COUNTERED), hiển thị rõ bằng chữ và màu; người chơi thấy rõ khi "dùng đúng lúc".
- [ ] Ảnh chụp màn hình: khoảnh khắc Parry thành công, boss choáng, Posture đầy và loạng choạng, được giữ lại trong `production/qa/evidence/`.

---

## Implementation Notes

- Cần trên boss logic: `cancel_incoming_card()`, trạng thái Choáng/Loạng choạng có thời hạn, Posture là số trong `CombatState` của phe boss.
- Mọi cửa sổ, thời hạn, hệ số trong `assets/data/parry.json` (hoặc gộp vào `combat_cards.json`/`boss_brain.json`), ghi `schema.md`.
- Phản hồi hình/âm cho parry đúng lúc là thứ quyết định cảm giác; placeholder vẫn phải làm rõ (chớp, chữ to, dừng hình 0,1 s cấu hình được).

---

## Out of Scope

- Story 010: Parry/Counter là một phần của bộ thẻ đầy đủ; ở đây chỉ hai thẻ này.
- Buff thay thế cho người chơi (Focus) — backlog.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Retained screenshot trong `production/qa/evidence/parry-counter-posture/`.
- Logic: `tests/unit/combat/parry_window_test.gd` — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 008
- Unlocks: Story 010
