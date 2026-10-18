# Story 005: Địch báo trước đòn trên 3 làn

> **Epic**: Kaiten Duel
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-18

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
- **Lộ API "thời gian còn lại tới đòn" (ví dụ `get_time_to_impact()` và `has_incoming_attack()`) trên logic địch.** Story 006 cần nó cho các thẻ "đúng lúc" (Counter/Parry, backlog #2). Không làm thẻ đó ở đây, chỉ để sẵn số liệu.
- Story 003 để lại: thêm `CombatState.damage_player` (giáp hấp thụ trước), tín hiệu `player_died`, và `CardPlayer.can_play` phải chặn khi người chơi đã chết.
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

---

## Completion Notes
**Completed**: 2026-10-18
**Criteria**: 8/8 passing. Not assessed: how the 3 s telegraph *feels* (reaction room, difficulty) — reserved for play-test gate 2 in EPIC.md.
**Deviations**: ADVISORY — (1) fallback defaults duplicated in `enemy_pattern_config.gd` (telegraph 3.0, initial pause 1.0, feedback 1.0); a missing key warns but runs with the old number; (2) `CombatView` calls `queue_redraw()` every frame; (3) left for Story 006 (from specialist review): `EnemyLogic` needs `cancel_attack()`/`delay_attack()` for Parry/Knockback, a result enum (HIT/MISS/PARRIED/COUNTERED) instead of a bool, a mutable enemy lane for Dash Strike, and `CardPlayer` needs a reference to the enemy for timing windows. Story 007 must build a fresh `EnemyLogic` on restart.
**Scope additions requested by the user during the story**: layout changed to horizontal rows facing each other (player left, enemy right, HUD band on top) and the project orientation changed portrait -> LANDSCAPE 1280x720 (`project.godot` orientation=0, `project.yaml` commands.run). Story 002's portrait evidence screenshots are stale history. `max_tick_sec` (0.1) added so a frame hitch cannot telegraph and resolve an attack in one tick (time slows instead of skipping).
**Test Evidence**: waived at `qa.level: minimal`. Run result: OBSERVED — `production/qa/evidence/telegraphed-enemy-lanes/01–07*.png`. Own-row drop rejected, adjacent-row Sidestep moves + armor + lock, lane-1 attack MISS while in row 0, lane-0 attack HIT with armor 10 -> 0 and HP 100 -> 95: verified by a scratch windowed pointer-event test (not retained in repo).
**Code Review**: Skipped (Solo mode); specialist GDScript review found no bugs.
