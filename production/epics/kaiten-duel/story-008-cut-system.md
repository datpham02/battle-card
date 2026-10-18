# Story 008: Boss chơi thẻ — tay bài, rút từ quầy, khoảng vung, brain theo trọng số

> **Epic**: Kaiten Duel (v2)
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md` (v2)
**Requirement**: Brief MVP feature 3 — boss có tay bài riêng rút từ cùng quầy; thẻ giơ lên + khoảng vung + vùng tầm trên lưới người chơi là báo đòn; luật chọn thẻ theo trọng số JSON; không còn đòn tự động theo giờ

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` v2 (Core loop + MVP feature 3), scoped to this story:*

- [ ] Boss có tay bài riêng (số ô cấu hình được, khởi điểm 3) và **lấy đĩa từ cùng quầy** với người chơi: khi boss chọn một đĩa, nó "với tay" trong một khoảng cấu hình được (khởi điểm 0,8 s) và đĩa đó được đánh dấu rõ; người chơi chạm lấy trước thì boss hụt.
- [ ] Boss dùng thẻ bằng cùng hệ hiệu ứng và hình dạng tầm như người chơi (Step di chuyển boss trên lưới nó; đánh tính từ ô boss; Guard cộng giáp boss). `enemy_cell` thay đổi được.
- [ ] Mỗi thẻ boss chơi có **khoảng vung** (cấu hình theo thẻ): trong khoảng đó lá bài boss giơ lên hiện rõ ở phía boss và **vùng tầm sáng đỏ trên lưới người chơi**; hết khoảng vung thì phát động; người chơi đã bước ra khỏi vùng thì hụt (MISS), còn trong vùng thì trúng (giáp hấp thụ trước).
- [ ] Boss có recovery theo thẻ như người chơi; **không còn bất kỳ đòn nào theo đồng hồ cố định**; `EnemyLogic` theo mẫu bị gỡ.
- [ ] Luật chọn thẻ là **bảng trọng số trong JSON** (`assets/data/boss_brain.json`): ít nhất các yếu tố "người chơi đang trong tầm thẻ này", "người chơi có giáp", "HP boss thấp → ưu tiên Guard", "ưu tiên lấy đĩa mà người chơi đang thiếu". Hai bộ trọng số khác nhau phải cho hành vi khác nhau nhìn thấy được.
- [ ] Chỉ một thẻ boss đang vung tại một thời điểm; boss không hành động khi chết hoặc khi người chơi đã chết.
- [ ] Lộ API cho Story 009: `has_incoming_card()`, `get_time_to_impact()`, thẻ đang vung và vùng tầm của nó.
- [ ] Ảnh chụp màn hình: boss với tay lấy đĩa, boss giơ thẻ với vùng tầm đỏ trên lưới người chơi, một lần trúng, một lần hụt do bước ra, được giữ lại trong `production/qa/evidence/`.

---

## Implementation Notes

- Brain là RefCounted thuần: nhận trạng thái (ô hai bên, HP/giáp, tay bài, quầy) → quyết định (lấy đĩa nào / chơi thẻ nào / bước đâu) theo trọng số; tiêm delta và RNG có seed để test xác định.
- Boss và người chơi dùng chung `CardPlayer`/hiệu ứng, chỉ khác "phe"; tránh hai bản sao logic.
- Tất cả tham số trong dữ liệu. Giữ `max_tick_sec` cho công bằng khi khựng frame.
- **Sau story này là cổng chơi thử 3.** Cập nhật hook `--demo=`.

---

## Out of Scope

- Story 009: Parry/Counter/Posture và hậu quả.
- Story 010: boss học bằng bộ đếm, feint; bộ thẻ đầy đủ.
- Story 011: nhiều trận, boss khác nhau, chơi lại.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshot trong `production/qa/evidence/boss-plays-cards/`.
- Integration: `tests/integration/combat/boss_brain_test.gd` hoặc tài liệu playtest — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006, Story 007
- Unlocks: Story 009, Story 010
