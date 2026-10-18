# Story 007: Một run: 3 trận + boss, thắng/thua

> **Epic**: Kaiten Duel
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 7 — một run ngắn: 3 trận + boss, có màn thắng/thua

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (Player goal & fail state, MVP feature 7), scoped to this story:*

- [ ] Một run gồm đúng 3 trận thường rồi 1 trận boss, theo thứ tự, mỗi trận một địch (cấu hình được trong file dữ liệu).
- [ ] Thắng một trận thì chuyển sang trận kế; HP người chơi được giữ từ trận này sang trận sau theo quy tắc khai báo.
- [ ] Thắng boss thì hiện màn thắng; HP về 0 ở bất kỳ trận nào thì hiện màn thua.
- [ ] Màn thắng/thua có cách bắt đầu một run mới mà không cần thoát game.
- [ ] Mỗi run bắt đầu với trạng thái sạch: băng chuyền, ô giữ, lượt ghép, HP đều được đặt lại.
- [ ] Địch trận sau mạnh hơn hoặc đòn nhanh hơn trận trước theo dữ liệu; boss có mẫu đòn riêng.
- [ ] Một run hoàn chỉnh kéo dài khoảng 8–12 phút khi chơi thử (đo và ghi lại trong phiếu bằng chứng).
- [ ] Ảnh chụp màn hình màn thắng, màn thua và một khoảnh khắc chiến đấu ở trận boss được giữ lại trong `production/qa/evidence/`.

---

## Implementation Notes

- Cấu trúc run (danh sách trận, địch, quy tắc giữ HP) là dữ liệu bên ngoài, không hard-code.
- Meta progression (mở khóa, nâng cấp) nằm ngoài MVP: đừng làm ở đây.
- Chạy thử một run đầy đủ bằng `commands.run` và ghi lại thời lượng thật.

---

## Out of Scope

- Tiến trình meta, lưu tiến độ giữa các run, nhiều map/nhân vật.
- Quảng cáo, mua trong ứng dụng.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshot màn thắng, màn thua, trận boss, trong `production/qa/evidence/`.
- Integration: `tests/integration/run/run_flow_test.gd` hoặc tài liệu playtest — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005, Story 006
- Unlocks: None
