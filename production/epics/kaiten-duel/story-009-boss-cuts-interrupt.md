# Story 009: Boss đi nhặt và cắt — brain trọng số, vung đỏ trên bàn bạn, ngắt đòn hai chiều

> **Epic**: Kaiten Duel (v3)
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-18

## Context

**GDD**: `design/game-brief.md` (v3)
**Requirement**: Brief MVP feature 4 — boss đi nhặt điểm bên nó và cắt bằng cùng hệ với brain trọng số JSON; vung đỏ trên bàn người chơi; ngắt đòn hai chiều; không có đòn nào theo đồng hồ cố định

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` v3 (Core loop: Ngắt đòn, Boss; MVP feature 4), scoped to this story:*

- [ ] Boss có **túi, nhịp rơi và tay riêng** (cùng luật Story 007, tham số riêng trong `boss_brain.json`) và **tự đi nhặt**: một ô mỗi bước với cooldown riêng (khởi điểm 0,55 s), hướng do brain quyết; người chơi thấy rõ boss đang đi về ô nào. `enemy_cell` đổi qua setter có kiểm tra.
- [ ] Boss **cắt bằng cùng `CutActor`/`CutResolver`** trên bàn người chơi: 1 điểm chém ngay; 2–4 điểm vào menu (boss chọn trong cùng khoảng chậm, không lâu hơn thời gian chọn của người chơi); cùng công thức vung và sát thương; cùng bộ kỹ năng và cooldown.
- [ ] Khi boss vung: tập ô sáng **đỏ trên bàn người chơi** với đếm ngược và nhãn điểm nó dùng; hết vung thì chém; người chơi đã bước ra thì MISS, còn trong thì HIT. Boss vẫn di chuyển được khi đang vung.
- [ ] **Ngắt đòn hai chiều**: đòn nào **chạm ô đối thủ trước** thì hủy đòn đối thủ đang vung; điểm đã dùng của bên bị hủy mất; hiển thị rõ "NGẮT" ở cả hai chiều. Một bên chết thì mọi đòn đang đếm bị hủy. Test xác định hai ca: bạn chém trước 0,1 s → đòn boss hủy; boss chém trước → đòn bạn hủy.
- [ ] **Brain là bảng trọng số JSON** (`assets/data/boss_brain.json`), ít nhất các yếu tố: ô người chơi có nằm trong tập ô của tổ hợp đang xét; số ô (sát thương) so với khoảng vung; đồng hồ đang đếm của người chơi (đua được hay không); có nên đi nhặt điểm đang nằm dưới đường dao của người chơi; kỹ năng nào đang sẵn; HP boss thấp → ưu tiên đòn nhanh. Hai bộ trọng số khác nhau phải cho hành vi khác nhau nhìn thấy được.
- [ ] **Không còn đòn nào theo đồng hồ cố định**; boss không hành động khi chết hoặc khi người chơi đã chết.
- [ ] Ảnh chụp màn hình: boss đi nhặt; boss vung đỏ trên bàn bạn với nhãn; một lần trúng; một lần hụt do bước ra; một lần ngắt đòn mỗi chiều — giữ lại trong `production/qa/evidence/boss-cuts-interrupt/`.

---

## Implementation Notes

- Brain là RefCounted thuần: nhận trạng thái (ô hai bên, HP, tay hai bên, điểm trên sân, đòn đang vung của người chơi) → quyết định (bước đâu / chốt tổ hợp nào / kỹ năng nào); tiêm delta và RNG có seed. Liệt kê tổ hợp 1–4 điểm trong tay boss (tối đa 15), chấm điểm bằng trọng số, chọn theo softmax hoặc max có nhiễu (số trong JSON).
- Boss và người chơi dùng chung `CutActor`, `MoveCooldown`, `FieldDrops`, chỉ khác phe và tham số: không hai bản sao logic. Ngắt đòn nằm trong một nơi (`CombatState` hoặc bộ điều phối trận) nghe `swing_resolved` của cả hai phe.
- Feedback đòn lưu **ô bị trúng** lúc chém, không đọc ô hiện tại khi vẽ.
- Giữ `max_tick_sec` cho công bằng khi khựng frame; một tick lớn không được cho hai đòn chém "cùng lúc" theo thứ tự sai: so sánh thời điểm chém còn lại, không so sánh thứ tự xử lý.
- **Sau story này là cổng chơi thử 3**: chơi và ghi lại cooldown bước, vung, nhịp rơi có đúng cảm giác không trước khi làm 010. Cập nhật hook `--demo=`.

---

## Out of Scope

- Story 010: Đốt, Ghim, bảng cân bằng, boss học bằng bộ đếm, feint.
- Story 011: nhiều trận, boss khác nhau, chơi lại.
- Thủ đoạn rơi của boss (backlog).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshot trong `production/qa/evidence/boss-cuts-interrupt/`.
- Integration: `tests/integration/combat/interrupt_test.gd` hoặc tài liệu playtest — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007, Story 008
- Unlocks: Story 010
