# Story 028: Ghép mảnh trên sân và hình chủ đạo — tối đa 2 mảnh một đòn, thưởng khi ghép đúng hình của trận

> **Epic**: Kaiten Duel (v5)
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md` (v5, mục "Đặt mảnh và phép", "Ghép mảnh và hình chủ đạo")
**Requirement**: Chơi thử với mảnh (sau Story 024), người dùng muốn **dùng nhiều mảnh một lúc** và **ghép mảnh**. Quyết định 2026-10-25: ghép **trên sân**, không ghép trong túi (kéo mảnh vào nhau trong túi quá lắt nhắt trên điện thoại); **một đòn tối đa 2 mảnh**; không có giới hạn cứng số ô (túi 3 + tối đa 2 mảnh + thời gian niệm theo tổng ô đã chặn việc phủ kín sân), chỉ có khóa dự phòng. Người dùng đề xuất và chốt: **thưởng khi ghép đúng "hình chủ đạo" của trận** (gợi dáng sân), ×1,5 sát thương kèm một hiệu ứng theo chủ đề trận. Việc này cũng gỡ TD-012 (mảnh 5 ô khó đặt, trúng 19 %): đòn 5–6 ô có thể ghép từ 2+3 hoặc 3+3 vào đúng chỗ.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH (đổi luồng đặt mảnh và menu phép)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Đòn nhiều mảnh**

- [ ] Một đòn gồm **1 hoặc 2 mảnh** (`max_pieces_per_cast` 2 trong `cards.json` hoặc `combat.json`, có trong `schema.md`). Hai mảnh **không được chồng ô**; ô của đòn là hợp của hai mảnh. Hai mảnh chạm cạnh hay rời nhau đều đánh được.
- [ ] **Luồng cảm ứng giữ nguyên một thao tác cho đòn 1 mảnh**: thả mảnh đầu trên đất địch vẫn mở menu phép ngay (Story 024). Trong lúc **menu phép đang mở** (chậm 0,2×), người chơi kéo thêm **một** mảnh từ túi lên đất địch; bóng mảnh thứ hai hít vào lưới, tránh ô của mảnh đầu, xanh/đỏ như mảnh đầu; thả là gắn vào đòn. Thêm mảnh thứ hai cộng `join_extra_sec` (khởi điểm 1,5 s, dữ liệu) vào thời gian chọn lá còn lại. Nút Xoay dùng được cho mảnh đang kéo. Chạm vào mảnh thứ hai đã gắn thì gỡ nó về túi.
- [ ] Menu cập nhật theo đòn mới: số ô, sát thương dự kiến, khóa "cần N ô" của lá tính trên **tổng ô**. Hủy ở menu trả **cả hai** mảnh về túi.
- [ ] **Thời gian niệm, sát thương, thanh nạp/trận đồ, nội tại** (`wide_caster`, `quick_blade`), Ảnh Bộ, Trảm tính theo **tổng số ô** của đòn. Phá phép làm mất cả hai mảnh.
- [ ] Khóa dự phòng `max_cast_cells` (mặc định 0 = tắt): khi > 0, mảnh thứ hai làm tổng vượt ngưỡng thì không gắn được (bóng đỏ có ghi chú).

**Phần B — Hình chủ đạo**

- [ ] `arenas.json`: mỗi hình sân có `featured_shape` (5–7 ô, ô tương đối, liền cạnh) và `featured_bonus` `{damage_mult, effect, stacks}` (khởi điểm `damage_mult` 1,5; `effect` một trong `fragile` / `pin` / `burn` / `frost` theo chủ đề trận); một trận trong `chapters.json` có thể ghi đè bằng `featured_shape` / `featured_bonus`. Hình gợi dáng sân khi được (chữ thập → dấu cộng lớn; chữ U, vòng → chữ U; bậc thang → bậc; vuông, chữ nhật, cột → khối 2×3 hoặc chữ T lớn…).
- [ ] **Chỉ đòn 2 mảnh** mà hợp ô của nó **trùng hình chủ đạo** (sau khi chuẩn hóa vị trí, xét 4 hướng xoay, không lật) mới được thưởng. Một mảnh đơn trùng hình không tính. Thưởng áp ở `CutEffects` (sát thương ×`damage_mult` cùng chỗ các hệ số khác, ghi rõ thứ tự) và thêm hiệu ứng `effect` × `stacks` lên boss khi trúng.
- [ ] HUD: hình chủ đạo của trận vẽ nhỏ ở góc (cạnh tên boss hoặc trên đất địch, không đè nút); khi hai mảnh đang ghép trùng hình chủ đạo thì bóng mảnh và hình ở góc cùng sáng, nhãn "Hình chủ đạo ×1,5" (khóa `TEXT_*` vi/en).
- [ ] Test bắt buộc cho **mọi hình sân** trong `arenas.json`: hình chủ đạo ghép được từ **ít nhất 2 cặp mảnh khác nhau** trong `pieces.json` (mảnh + mảnh, có xoay), và có ít nhất một vị trí hợp lệ trên đất địch của sân đó. Sân nào không đạt thì đổi hình chủ đạo, không đổi luật.

**Phần C — Kiểm chứng**

- [ ] Test thuần: hợp ô hai mảnh, cấm chồng ô, nhận diện hình chủ đạo theo 4 hướng xoay và mọi vị trí, mảnh đơn không tính, `max_cast_cells`, thưởng ×1,5 và hiệu ứng áp đúng một lần khi trúng, không áp khi trượt.
- [ ] Suite bấm chuột (`cut_flow_test` hoặc suite mới) kéo mảnh 1 thả → menu mở → kéo mảnh 2 thả → menu ghi tổng ô và cộng `join_extra_sec` → chọn lá → vung đúng hợp ô; gỡ mảnh 2; hủy trả cả hai; xoay mảnh 2 bằng ngón thứ hai.
- [ ] `hit_probe.gd` (scratch) thêm chế độ đòn 2 mảnh: tỉ lệ trúng 4–6 ô ghép so với mảnh 5 ô đơn (TD-012); bảng vào Completion Notes.
- [ ] Ảnh trong `production/qa/evidence/join-pieces/`: menu mở với một mảnh đã đặt và mảnh thứ hai đang kéo; hai mảnh ghép trùng hình chủ đạo (sáng, nhãn ×1,5); hai mảnh rời nhau; hình chủ đạo ở góc HUD của 3 sân khác nhau; bản tiếng Anh.
- [ ] Không hằng số gameplay trong mã; chuỗi mới là khóa `TEXT_*` với vi và en.

---

## Implementation Notes

- **Quyết định 2026-10-25 (người dùng chấp nhận):** ở 5 sân (vuông, chữ thập, chữ U, hai đảo, bậc thang) không hình 5–7 ô nào vừa mọi biến thể sân mà vẫn ghép được từ ≥ 2 cặp mảnh; hình chọn là hình phủ nhiều biến thể nhất, và khi sân thực tế không chứa được hình chủ đạo thì tính năng **tắt ở trận đó** (`ArenaLibrary.featured_for_match` trả `{}`). Người dùng: giữ như vậy vì "cần những độ khó như vậy để làm khó game hơn". Test yêu cầu 100 % ở 5 sân còn lại, ≥ 60 % biến thể ở 5 sân này và tắt đúng khi không vừa.

- Đòn nhiều mảnh nên là một kiểu dữ liệu nhỏ (danh sách mảnh + ô) đi qua `PlacementController` → `CutFlow.open_menu` → `_begin_cut`; `CutActor.begin_swing` vẫn nhận một mảng ô.
- Nhận diện hình: chuẩn hóa tập ô (dịch về gốc, sắp xếp) và so với 4 hướng xoay của hình chủ đạo; dùng lại `Piece.relative_cells()` / `rotated()`.
- `--demo=join_menu|join_featured|join_split` cho chụp ảnh.

---

## Out of Scope

- Boss ghép mảnh và nhắm hình chủ đạo (Story 025 làm, sau story này). Trận đồ (Story 029). Ghép trong túi, lật mảnh, đòn 3 mảnh.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/join-pieces/`; bảng tỉ lệ trúng đòn ghép.

**Status**: Screenshots retained (join-pieces/01-05, 7 PNG) + hit-rate table (join-pieces/hit-rates-join.md) + suites (join_flow_test, arena_featured_test, featured_shape_test, cast_plan_test, featured_bonus_test, placement_avoid_test; input_test made deterministic).

---

## Dependencies

- Depends on: Story 024 (mảnh, luồng đặt, menu sau khi đặt)
- Unlocks: Story 029 (trận đồ tính theo ô của đòn), Story 025 (boss ghép mảnh)

---

## Completion Notes
**Completed**: 2026-10-25
**Criteria**: 14/14 pass or deferred, 0 failing. DEFERRED (needs real play on a device): feel of dragging the second piece while the match runs at 0.2x and whether the +1.5 s (`join_extra_sec`) is enough; whether the 38 px featured-shape icon is noticed and readable on a phone; balance of the x1.5 bonus and its effects; real-play hit rate of joined 5-cell casts. UNTESTED (ADVISORY, TD-015): signature charge, passives (`wide_caster`, `quick_blade`), Anh Bo and Tram through the join path (same `_begin_cut` code path reading `cells.size()`, only unit-level coverage).
**Deviations**: ADVISORY (accepted by the user 2026-10-25): on five boards (square, cross, u_shape, islands_bridge, staircase) no 5-7 cell shape that two pieces tile in at least two ways fits every generated variant; the chosen shape covers 74.6 / 99.0 / 98.6 / 96.9 / 92.0 % of variants and `ArenaLibrary.featured_for_match` returns `{}` (feature off for that match) when the real board cannot hold it; rect, ring, diamond, cross_wide and pillars are 100 %; the plus cannot be a featured shape (only one tiling). ADVISORY: `join_flow_test` assigns the private `_featured` by hand (real arena shapes are covered by `arena_featured_test`). ADVISORY (TD-016): no on-screen hint that a second piece can be joined while the card menu is open. ADVISORY (TD-017): the paused Story 025 edit `root_while_swinging: true` (`boss_brain.json`) is live in the game and in the probes: the boss cannot step while it swings; absolute hit rates in `hit-rates-join.md` include it, comparisons inside one run stay valid, and the table is a best case that leaves out the second drag and the extra menu time. ADVISORY (TD-014): Tram button strip shows under the menu, player token name clipped on small cells. Beyond the story: `input_test.gd` made deterministic (random drops landed on cells the player stepped on; 4 of 40 runs failed before, 15 of 15 pass after), `--arena=<shape>` dev arg and demos `join_menu|join_featured|join_split`, a runtime error in `CombatView.select_piece` (untyped array from a ternary) found by capturing and fixed. The header total now counts committed cells and shows the preview as "(+N)" so it agrees with the card locks.
**Test Evidence**: Integration; tests waived at `qa.level: minimal` but present and run: `tests/unit/pieces/` featured_shape_test, cast_plan_test, arena_featured_test, placement_avoid_test; `tests/unit/combat/featured_bonus_test.gd`; windowed `tests/integration/ui/join_flow_test.gd` (46 checks, real touch events, 6 of 6 runs), `cut_flow_test`, `focus_flow_test`, `input_test` all FAILS=0 on the final code. Headless sweep of 40 suites: 38 green, `pace_test` FAILS=2 and `run_state_test` FAILS=16 are the known TD-011. Parse-check 47/47. strings.csv 321 rows, 3 columns each. Retained screenshots `production/qa/evidence/join-pieces/01-05*.png` (all opened and checked) and `hit-rates-join.md` plus `-raw.txt`. Hit rates, chapter 1, 40 casts per cell, mean over 11 enemies (aimed / right after a boss step): 5 cells single piece 42 / 41 %, joined pair 51 / 67 %, ideal cluster 59 / 65 %; 4 cells single 60 / 71, pair 60 / 66; 6 cells pair 45 / 55; 7 cells pair 38 / 41. Joining mostly fixes TD-012 (5-cell casts); minibosses and bosses stay at about 50 % or below.
**Code Review**: Skipped (solo mode).
**Not verified**: touch feel on a phone, balance of the featured bonus, real-play hit rates, the boss joining pieces or aiming at the featured shape (Story 025).
**Carries forward**: Story 029 (formation map replaces the 18-cell charge, so the Tram button still shows a percentage), Story 025 (boss uses and joins pieces, aims at the featured shape, counter window; verify the live partial edits first), Story 026, Story 027; TD-001..002, 004..017.
