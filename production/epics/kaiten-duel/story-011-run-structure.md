# Story 011: Một run: 3 trận + boss, thắng/thua, chơi lại

> **Epic**: Kaiten Duel (v3)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-18

## Context

**GDD**: `design/game-brief.md` (v3)
**Requirement**: Brief MVP feature 6 — một run 3 trận + boss, màn thắng/thua, chơi lại không cần thoát

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` v3 (Player goal & fail state, MVP feature 6), scoped to this story:*

- [ ] Một run gồm đúng 3 trận thường rồi 1 trận boss, theo thứ tự, cấu hình trong dữ liệu; mỗi trận là một đối thủ với **bộ trọng số brain, cooldown bước, nhịp rơi và HP riêng** (kỹ năng và luật cắt là chung).
- [ ] Thắng một trận → chuyển sang trận kế; HP người chơi giữ theo quy tắc khai báo; điểm trên sân, tay và túi xáo được đặt lại theo quy tắc khai báo.
- [ ] Thắng boss → màn thắng; HP về 0 ở bất kỳ trận nào → màn thua; cả hai có nút chơi lại run mới mà không thoát game; mọi trạng thái (lưới, điểm, tay, túi, cooldown kỹ năng, ô cháy/ghim, bộ đếm học của boss) đặt lại sạch; brain được tạo mới mỗi trận.
- [ ] Trận sau khó hơn trận trước theo dữ liệu (boss bước nhanh hơn, nhịp rơi nhanh hơn, trọng số khôn hơn); trận boss có bộ trọng số và độ tươi riêng.
- [ ] Một run hoàn chỉnh kéo dài khoảng 8–12 phút khi chơi thử (đo và ghi lại trong phiếu bằng chứng).
- [ ] Ảnh chụp màn hình màn thắng, màn thua và một khoảnh khắc trận boss, được giữ lại trong `production/qa/evidence/`.

---

## Implementation Notes

- Cấu trúc run là dữ liệu (`assets/data/run.json`): danh sách trận, tham chiếu bộ trọng số brain, quy tắc giữ HP/đặt lại sân.
- Meta progression (thực đơn) nằm ngoài MVP: đừng làm ở đây.
- Chạy thử một run đầy đủ bằng `commands.run` và ghi thời lượng thật.

---

## Out of Scope

- Meta progression, lưu tiến độ giữa các run, nhiều nhân vật, Daily Counter, thủ đoạn rơi của boss (backlog).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshot trong `production/qa/evidence/run-structure/`.
- Integration: `tests/integration/run/run_flow_test.gd` hoặc tài liệu playtest — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 010
- Unlocks: None
