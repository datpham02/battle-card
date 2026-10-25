# Story 025: Boss dùng mảnh ấn — chấm điểm vị trí và hướng xoay, boss đứng yên khi niệm, vòng hồi bước hiện khóa

> **Epic**: Kaiten Duel (v5)
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md` (v5, mục "Core loop — mảnh ấn", "Boss")
**Requirement**: Sau Story 024 người chơi dùng mảnh còn boss vẫn nối ấn; hai bên phải cùng một hệ để luật đọc được (người chơi né đòn boss theo đúng hình mình cũng dùng). Cùng đợt bàn 2026-10-24, hai việc được chọn để có **cửa sổ phản công** dễ đọc: boss không bước khi đang niệm (hiện boss vừa niệm vừa bước được, `boss_controller.gd` không chặn) và vòng hồi bước của boss (mẹo "đánh ngay khi boss vừa bước" lên gần 100 % trúng với quái thường). **Đính chính 2026-10-25:** vòng hồi bước của boss ĐÃ có từ trước (`CombatView._draw_boss_ring`: cung đỏ mỏng quanh thân boss, đầy lúc vừa bước rồi cạn, ẩn khi sẵn sàng); nhận định ban đầu "hiện vô hình" là sai. Phần mới duy nhất là trạng thái **khóa khi đang niệm** và làm vòng dễ thấy hơn nếu ảnh chụp cho thấy nó mờ.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH (viết lại phần chọn đòn của não boss)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

> **Làm tiếp 2026-10-25 (sau Story 028–029 và 030):** não boss viết một lần theo luật cuối: boss được ghép **tối đa 2 mảnh** một đòn như người chơi (Story 028; ứng viên đòn 2 mảnh chỉ lấy từ các vị trí đơn điểm cao nhất để mỗi lượt nghĩ vẫn nhẹ). **Bỏ ý "boss nhắm hình chủ đạo"** đã ghi trước đó: thưởng ×1,5 và hiệu ứng của hình chủ đạo chỉ áp cho **người chơi** (`SwingArbiter` ép đòn của boss không mang bonus), nên boss nhắm vào đó không có tác dụng; nếu muốn boss cũng có bonus thì là quyết định thiết kế riêng. **Hiện trạng trên `main` (commit 9612c34):** phần hạ tầng đã vào game — `BossController.enable_pieces`, `_do_cut` nhận ô từ mảnh, khóa bước khi niệm (`root_while_swinging: true`), `CombatView` bật chế độ mảnh cho boss — nhưng `boss_brain.gd` CHƯA sinh ứng viên theo mảnh: nó vẫn gọi `CutResolver` với nhãn, mà nhãn của mảnh ("bar2", "l3", …) không phải nhãn chu vi hợp lệ nên **boss hiện không ra đòn nào**. Việc đầu tiên của story là sửa đúng chỗ này và thêm test chứng minh boss ra đòn (TD-017).

**Phần A — Boss nhặt và đặt mảnh**

- [ ] Boss nhặt mảnh trên đất mình bằng cùng hệ rơi mảnh của Story 024 (trọng số hình theo chương, nhịp nhân `boss_drop_interval_mult` như cũ), túi 3.
- [ ] Não boss chấm điểm **(mảnh, vị trí, hướng xoay)** trên đất người chơi thay cho tập nhãn: dùng lại trọng số hiện có (`cut_hit_now`, `cut_per_cell`, `cut_duration_penalty`, `escape_penalty`, `cut_interrupt_bonus`, `min_runes_penalty` đổi nghĩa thành số ô tối thiểu, …) và `EscapeAnalysis` để đếm ô thoát của người chơi trong thời gian niệm. Số ứng viên giới hạn (`max_placements_scored` trong `boss_brain.json`) để mỗi lượt nghĩ rẻ.
- [ ] `boss_min_runes` (Story 023) đổi nghĩa thành **số ô tối thiểu của mảnh** boss ưu tiên; tên khóa giữ nguyên để không vỡ `chapters.json`, ghi rõ trong `schema.md`.
- [ ] Đòn nối (combo), giả đòn (feint), học theo bộ đếm (`BossLearning`) chạy với mảnh như với nhãn.
- [ ] Trait `rotten_thrower` ném mảnh nguyền (Story 024) không đổi; `row_burner`, `slam`, `fuse_cannon`, `step_reactor`, `frost_aura`, `phase_shift` không phụ thuộc nhãn và chạy như cũ.

**Phần B — Cửa sổ phản công**

- [ ] **Boss đứng yên khi đang niệm**: cờ `boss_root_while_swinging` (mặc định `true` trong `boss_brain.json`, ghi đè theo trận trong `chapters.json`). Khi bật, não không chọn bước và `UnitMover` của boss từ chối bước trong lúc `actor.is_swinging()`; đòn bị hủy (phá phép, giả đòn) thì bước lại được ngay.
- [ ] **Vòng hồi bước của boss** (đã có, `_draw_boss_ring`) thêm trạng thái **khóa**: khi boss đang niệm và bị khóa bước thì vòng đổi sang màu riêng (đủ khác màu thường, nét liền); xem ảnh chụp và làm vòng dày/sáng hơn nếu nhìn khó thấy trên màn nhỏ. Không tạo vòng thứ hai.

**Phần C — Kiểm chứng**

- [ ] Test: vị trí boss chọn luôn hợp lệ trên đất người chơi (kể cả sân có lỗ); điểm chấm thích ứng (người chơi đứng góc → boss ưu tiên mảnh phủ góc và ô kề); `boss_min_runes` loại mảnh nhỏ hơn; boss không bước khi đang niệm lúc cờ bật và bước được khi cờ tắt; hủy đòn mở khóa bước; vòng đổi trạng thái khóa đúng lúc boss niệm và trở lại thường khi hết niệm.
- [ ] Suite `tests/unit/combat/` về não boss (`profiles`, `learning`, `arbiter`, …) cập nhật sang mảnh và chạy xanh; không suite nào đỏ thêm so với baseline sau Story 024.
- [ ] `hit_probe.gd` thêm chế độ **phản công** (đặt mảnh vào boss ngay khi boss bắt đầu niệm): báo tỉ lệ trúng 1–5 ô cho 11 địch chương 1 vào Completion Notes, kèm số đòn boss trúng người chơi khi người chơi đứng yên (để thấy boss mảnh mạnh hay yếu hơn boss nối ấn).
- [ ] Ảnh trong `production/qa/evidence/boss-pieces/`: boss đang niệm một mảnh trên đất người chơi; vòng hồi bước boss bình thường và khi khóa; người chơi phản công trúng boss đang niệm; boss ném mảnh nguyền.
- [ ] Không hằng số gameplay trong mã; chuỗi mới là khóa `TEXT_*` với vi và en.

---

## Implementation Notes

- Giữ nguyên giao diện `BossBrain.decide(ctx)` → `{type: "cut", cells, skill_id, …}` để `BossController._do_cut` và `SwingArbiter` không đổi; chỉ đổi cách sinh ứng viên (từ tập nhãn sang vị trí mảnh).
- Khóa bước khi niệm đặt ở **một** điểm (`UnitMover.blocked_fn` hoặc kiểm tra trong `BossController.tick` trước `try_step`), không rải trong não.
- `--demo=boss_placing|boss_rooted` cho chụp ảnh.

---

## Out of Scope

- Gỡ code nối ấn và chuyển `deck_sim` (Story 026). Kết giới / Trận gai (Story 027). Hiện ý định bước của boss, trợ giúp theo chương.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/boss-pieces/`.
- Bảng tỉ lệ trúng chế độ phản công trong Completion Notes.

**Status**: Screenshots retained (boss-pieces/01-06) + counter table (boss-pieces/hit-rates-counter.md) + suites (boss_pieces_test, boss_pieces_flow_test).

---

## Dependencies

- Depends on: Story 024 (mảnh, rơi mảnh, `PiecePlacement`), **Story 028 (đòn 2 mảnh, hình chủ đạo), Story 029 (trận đồ)**, Story 013 (hồ sơ boss), Story 009 (não trọng số)
- Unlocks: Story 026, Story 027

---

## Completion Notes
**Completed**: 2026-10-25
**Criteria**: 12/12 pass, 0 failing. DEFERRED (needs real play): how the rooted-boss counter window feels and whether the steel-blue locked ring reads on a phone; whether the piece-boss is too harsh on minibosses and bosses. Partly untested: boss learning counters with pieces (existing learning suites only), the `boss_drop_interval_mult` scaling of piece drops, the per-match `boss_root_while_swinging` override.
**Fact worth recording**: from commit 9612c34 until this story the boss could not attack in the game: the plumbing (`BossController.enable_pieces`, piece-aware `_do_cut`, the step lock, `CombatView` switching the boss to piece mode) was on main but `BossBrain._best_cut` still resolved perimeter labels and a piece's label ("bar2", "l3", "square") is not a valid label, so every candidate was empty. Pushed commits 9612c34, a4fa245 and 4782016 carry that boss. Fixed here; `tests/integration/run/boss_pieces_flow_test.gd` boots a real `CombatView` and asserts the first swing (2.1 s), that the swing cells are real player-half cells, that the boss stays rooted during the swing and moves after it (the old brain fails 4 checks and never swings in 70 s).
**Deviations**: ADVISORY (decision recorded in the story): the boss does not aim at the featured shape (the bonus is player-only: `SwingArbiter` forces boss swings to carry none). ADVISORY (balance, TD-022): the piece-boss is harsher than the rune-boss on minibosses and bosses (+31 % damage per minute, +61 % on the two bosses, standing player, root on) and softer on normal enemies (-27 %); it swings less often (10.3 vs 15.1 per minute) but lands 97 % of its swings on a standing player (rune-boss 58 %); goblin_scout, dire_wolf and goblin_brute swing only 4-6 times per minute as piece-bosses against 8-15 as rune-bosses (cause not diagnosed). ADVISORY: counter hit rate on minibosses + bosses with the boss rooted: 84 / 81 / 44 / 18 / 9 % for 1-5 cells (22 / 20 / 12 / 4 / 0 % without the root); about 39 % weighted by the bot's cast sizes against about 9 % without the root; the story context target was about 50-70 %: 1-2 cells overshoot, 3 cells fall short, 4-5 cells stay low because of the windup race (the piece-boss's mean swing is 0.97 s, a 3-cell windup is 0.95 s); the player never steps in the probe so 3+ cell values are a lower bound. ADVISORY (TD-023): the countdown label is centred on the cast's bounding box and can cover a field piece lying under it; `max_cast_cells` is not applied to the boss; `max_pieces_per_cast` is read when piece mode is switched on only. ADVISORY: new tunable `pair_seed_placements` (12, `boss_brain.json`) instead of a hard-coded number; `BossController.enable_pieces` gained a 4th argument (`max_pieces`, `CombatView` passes `max_pieces_per_cast`). ADVISORY: the original `hit_probe.gd` and `deck_sim.gd` scratch simulators no longer parse (SignatureCharge was removed in Story 029); the counter probe is a copy with signatures off (`counter_probe.gd`); moving both simulators to the new rules belongs to Story 026. ADVISORY: view changes beyond the story text: boss hand slot box enlarged to 52x30 px, normal ring arc 5 -> 7 px, locked ring 9 px; boss swing label shows the cell count in piece mode ("BOSS 5 ô Kiếm khí"); five dev demos (`boss_placing`, `boss_ring_normal`, `boss_rooted`, `boss_counter`, `boss_rotten`). Closes TD-017 (the live partial edits now have tests).
**Test Evidence**: Integration; tests waived at `qa.level: minimal` but present and run on the final code: `tests/unit/combat/boss_pieces_test.gd` (27 checks), `tests/integration/run/boss_pieces_flow_test.gd` (6 checks); headless sweep of 43 suites: 41 green, `pace_test` FAILS=2 and `run_state_test` FAILS=16 are the known TD-011; windowed `join_flow_test`, `cut_flow_test`, `focus_flow_test`, `input_test` FAILS=0 with the boss now attacking. Parse-check 8/8. Retained screenshots `production/qa/evidence/boss-pieces/01-06*.png` (all opened and checked) and `hit-rates-counter.md` plus `-raw.txt`. Probe results (chapter 1, 40 casts per cell, single seed, about +-8 points): counter hit rate pooled over 3 minibosses + 2 bosses, root on: 1 cell 84 %, 2 cells 81 %, 3 cells 44 %, 4 cells 18 %, 5 cells 9 % (plain piece mode without the counter: 36 / 29 / 18 / 12 / 5 %; root off: 22 / 20 / 12 / 4 / 0 %); the two bosses alone drop to 5-14 % from 3 cells; two-piece counters (4-6 cells) reach 8-18 %; with the root on 95-100 % of resolved counters hit.
**Code Review**: Skipped (solo mode).
**Not verified**: feel of the counter window on a phone, ring readability, balance against a human, why three piece-bosses swing so rarely.
**Carries forward**: Story 026 (retire the rune system, move hit_probe/deck_sim to pieces, rebalance the three chapters incl. TD-022, 5-cell cards TD-012, stale suites TD-011), Story 027; TD-001..002, 004..023.
