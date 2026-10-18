# Story 003: Dùng thẻ ra sân + recovery, đánh địch giả

> **Epic**: Kaiten Duel
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-18

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 4 — kéo thẻ ra sân để kích hoạt, mỗi thẻ có recovery riêng

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (Core loop + MVP feature 4), scoped to this story:*

- [ ] Kéo một thẻ từ ô giữ ra sân (vùng chiến đấu) thì kích hoạt hiệu ứng của thẻ ngay, không có thời gian cast.
- [ ] Thẻ đã dùng bị xóa khỏi ô giữ, ô đó trở lại trống.
- [ ] Sau khi dùng thẻ, người chơi bị khóa không dùng được thẻ khác trong khoảng recovery của thẻ đó; băng chuyền vẫn chạy bình thường trong lúc này.
- [ ] Recovery khác nhau theo từng thẻ, đọc từ file dữ liệu (khởi điểm: nhẹ 0.4 s, thường 0.8 s, nặng 1.5 s; Sidestep/Giáp 0.3 s).
- [ ] Người chơi nhìn thấy trạng thái khóa (ví dụ ô giữ mờ đi hoặc thanh recovery) trong lúc recovery.
- [ ] Có một địch giả đứng yên với thanh HP; thẻ tấn công trừ HP, thẻ đỡ tạo lớp giáp cho người chơi; địch về 0 HP thì chết.
- [ ] Thả thẻ ngoài vùng sân thì thẻ quay lại ô giữ, không bị dùng.

---

## Implementation Notes

- Trạng thái recovery là một máy trạng thái nhỏ tách khỏi UI để test xác định (tiêm đồng hồ/delta).
- Giá trị recovery, sát thương, giáp nằm trong file dữ liệu (`assets/data/`), không hard-code.
- Chỉ cần vài thẻ tạm (đánh nhẹ/thường/nặng, đỡ); bộ đầy đủ ở story 006.
- **Cổng quyết định:** sau story này, chơi thử 30 giây. Nếu không vui, dừng lại trước khi làm story 005–007.

---

## Out of Scope

- Story 004: ghép thẻ.
- Story 005: địch tấn công, làn, báo đòn.
- Story 006: các thẻ Dash/Sidestep/Knockback.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Retained screenshot một lần dùng thẻ và trạng thái recovery, trong `production/qa/evidence/`.
- Logic: `tests/unit/combat/card_recovery_test.gd` — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002
- Unlocks: Story 005

---

## Completion Notes
**Completed**: 2026-10-18
**Criteria**: 7/7 passing. Not assessed: how the belt pace and recovery weights *feel* — reserved for the epic's play-test decision gate.
**Deviations**: ADVISORY — (1) a card with a missing `recovery_sec` key defaults to 0 (spammable) and a missing `combat_cards.json` silently rejects every card; (2) `CombatView` calls `queue_redraw()` every frame; (3) fallback HP defaults (100) are hard-coded in code, duplicating the JSON. Agent decisions: a dead enemy blocks all plays including shields; armor is uncapped and consumed by nothing until Story 005; a card dragged during recovery can be picked up but the drop is rejected.
**Test Evidence**: waived at `qa.level: minimal`. Run result: OBSERVED — `production/qa/evidence/play-card-recovery/01-attack-played-recovery-lock.png`, `02-shield-played-armor.png`, `03-enemy-dead.png`. Play / rejection-during-recovery / unlock / invalid-drop verified via a scratch windowed pointer-event test (not retained in repo).
**Code Review**: Skipped (Solo mode); informal GDScript specialist review found no bugs.
**Handoff to later stories**: 004 needs a "take card from slot without freeing the node" path and ids for upgraded cards in `combat_cards.json`; 005 needs `CombatState.damage_player` (armor absorbs first), `player_died`, and `CardPlayer.can_play` must also block when the player is dead.
