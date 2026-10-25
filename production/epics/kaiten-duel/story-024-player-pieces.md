# Story 024: Mảnh ấn phía người chơi — mảnh rơi, túi 3, đặt và xoay lên đất địch, báo trúng, hạ min_cells

> **Epic**: Kaiten Duel (v5)
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md` (v5, mục "Core loop — mảnh ấn")
**Requirement**: Chơi thử 2026-10-24: người dùng thấy đánh trúng boss rất khó, nối ấn đòi nhớ quy ước chu vi (A/B/C/D) và phải nhặt 3–4 ấn mới có một vùng. Đo bằng logic game thật (`hit_probe.gd`, 40 đòn mỗi ô): boss thường né phần lớn đòn từ 3 ô trở lên; ô giữa sân chỉ trúng được bằng trận pháp ≥ 3 ô. Người dùng quyết định **bỏ nối ấn, thay bằng mảnh ấn**: mỗi ấn rơi là một mảnh hình sẵn, chọn mảnh, đặt lên chỗ bất kỳ vừa khít trên đất địch, chọn lá. Story này đổi **phía người chơi**; boss giữ nguyên hệ nối ấn đến Story 025.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH (đổi cơ chế lõi và luồng nhập của người chơi)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Dữ liệu và logic mảnh**

- [ ] `assets/data/pieces.json` (mới, có trong `schema.md`): danh sách hình, mỗi hình `{id, cells: [[x,y],...], name_key}` với ô tương đối, liền cạnh, 1–5 ô. Khởi điểm 12 hình: `mono`; `bar2`; `bar3`, `l3`; `square`, `t4`, `l4`, `s4`, `bar4`; `plus5`, `u5`, `bar5`. Trọng số rơi theo chương (`weights` theo chapter id, mặc định dùng `default`): chương 1 ưu tiên 1–3 ô, hình 5 ô hiếm.
- [ ] `Piece` (RefCounted, thuần): hình + hướng xoay 0–3; `cells_at(anchor, rotation)` trả ô tuyệt đối; xoay 90° chuẩn hóa về gốc (ô trên-trái = (0,0)). Không lật.
- [ ] `PiecePlacement` (thuần): với một `BoardGrid` và mảnh, liệt kê **vị trí hợp lệ** (mọi ô là ô thật của đất địch, kể cả sân có lỗ); `snap(target_cell, rotation)` trả vị trí hợp lệ gần nhất hoặc rỗng; `covers(cell)`.
- [ ] Rơi mảnh: nhịp, số tối đa trên sân, độ tươi đọc từ `field_drops.json` (khóa mới cho mảnh: khởi điểm `piece_spawn_interval_sec` 3,0, `piece_max_on_field` 3, `piece_freshness_sec` 8,0); rút hình theo trọng số chương, **bỏ qua hình không có vị trí hợp lệ** trên đất địch của trận; hướng xoay ngẫu nhiên; seeded. Vào trận có `start_pieces` mảnh (khởi điểm 1, `field_drops.json`). Bù khi đói như v3.
- [ ] **Túi mảnh 3** (`hold_slots.json` → `piece_slot_count` 3). Bước lên ô có mảnh là nhặt; túi đầy thì mảnh nằm lại và hiện "ĐẦY" như v3.
- [ ] Trait `rotten_thrower` (Story 014) ném **mảnh nguyền** lên đất người chơi: mảnh 1 ô màu xám có dấu X, nhặt vào chiếm một chỗ trong túi, tự tan sau `rot_in_hand_sec`, **không đặt được**.

**Phần B — Luồng đặt mảnh**

- [ ] **Cảm ứng là cách nhập chính** (game mobile chơi ngang hai tay, quyết định 2026-10-24); chuột và phím chỉ là phụ để test trên máy tính. Không chức năng nào chỉ làm được bằng chuột di (hover), phím hoặc chuột phải.
- [ ] Chọn mảnh (chạm hoặc bắt đầu kéo ô trong túi; phím 1–3 phụ) → **chế độ đặt**: Tập trung sẵn sàng thì trận dừng hẳn (4 s, cooldown 8 s, như Story 012); không thì chậm `menu_time_scale` 0,2×. D-pad khóa, dùng chung `input_locked`.
- [ ] **Kéo thả (cách chính, một thao tác)**: giữ mảnh trong túi kéo lên đất địch; **bóng mảnh nổi phía trên ngón tay** một khoảng `drag_lift_px` (`hold_slots.json`) để ngón không che; bóng hít vào lưới đất địch qua `PiecePlacement.snap`. **Thả trên đất địch = chốt vị trí và mở menu phép ngay**; thả ngoài đất địch = mảnh về túi (hủy). Chuột trái kéo thả y như ngón tay.
- [ ] **Chạm từng bước (cách phụ)**: chạm mảnh để chọn, chạm một ô đất địch để đặt bóng ở đó, chạm lại vào bóng hoặc nút Thi triển để chốt. Ngoài đất địch thì bóng mờ và không chốt được.
- [ ] **Xoay 90° theo chiều kim đồng hồ**: trong chế độ đặt, vùng d-pad hiện **nút Xoay lớn** (≥ 64 px, gần hết vùng d-pad) cho ngón cái trái, **bấm được trong lúc ngón kia đang kéo** (đa chạm, theo `index` của sự kiện chạm). Chạm lại vào mảnh đang chọn trong túi cũng xoay; hình trong ô túi xoay theo. Mảnh xoay quanh ô đang ở dưới ngón tay / bóng (ô đó giữ chỗ); xoay xong không vừa thì hít về vị trí hợp lệ gần nhất. Phụ trên máy tính: phím R, chuột phải.
- [ ] **Báo trúng**: bóng mảnh xanh khi ô boss đang đứng nằm trong mảnh, đỏ khi không; số ô và sát thương dự kiến của lá mặc định hiện ở chỗ không bị ngón tay che và không đè nút khác.
- [ ] Chốt → **menu phép v4** không đổi (rút 4 lá, 0,2×, 3 s, hết giờ tự *Kiếm khí*; lá chưa đủ ô khóa "cần N ô"). Nút Hủy trong chế độ đặt hoặc menu trả mảnh về túi (Esc phụ trên máy tính).
- [ ] Đòn dùng đúng các ô của mảnh: `CutActor.begin_swing(cells, …)` như hiện tại, thời gian niệm và sát thương theo số ô như v4. Mảnh dùng xong mất; đòn bị phá phép thì mảnh mất.
- [ ] Thanh nạp tuyệt kỹ, nội tại (`wide_caster` cần 5 ô, `quick_blade` ≤ 3 ô), Ảnh Bộ, Trảm vẫn tính theo số ô như trước.
- [ ] **Không còn nối ấn cho người chơi**: túi ấn, nhãn chu vi trên đất địch, đường nối, đòn 1 ấn xuyên thẳng biến mất khỏi HUD người chơi. Code nối ấn **giữ lại** vì boss còn dùng (gỡ ở Story 026).

**Phần C — Lá và cân bằng tạm**

- [ ] `cards.json`: mọi `min_cells` ≤ 5. `bang_phong` 7 → 4 (TD-003); `song_kiem`, `han_bang`, `thien_hoa`, `tu_kiem` 6 → 5. Mô tả lá nào nhắc số ô thì sửa chuỗi vi/en.
- [ ] Không chỉnh máu, nhịp boss hay độ khó chương trong story này; cân bằng làm ở Story 026.

**Phần D — Kiểm chứng**

- [ ] Test thuần (`tests/unit/combat/`): xoay 4 lần về hình gốc, chuẩn hóa gốc; vị trí hợp lệ trên sân vuông, chữ nhật, sân có lỗ (không vị trí nào chạm ô thiếu); `snap` về vị trí gần nhất; rơi mảnh seeded bỏ qua hình không vừa; túi 3 đầy chặn nhặt; mảnh nguyền không đặt được và tan đúng giờ; báo trúng đúng với ô boss.
- [ ] Suite bấm chuột người chơi (`tests/integration/ui/cut_flow_test.gd`, `focus_flow_test.gd`, `input_test.gd`) cập nhật sang luồng mảnh và chạy xanh (windowed, `-- --no-autopause`); các suite còn lại trong `tests/` không đỏ thêm (baseline 33 pass, 2 hỏng sẵn TD-011).
- [ ] `hit_probe.gd` (scratch, sao chép từ `deck_sim.gd`) thêm chế độ **đặt mảnh thật**: chỉ dùng các hình trong `pieces.json`, vị trí hợp lệ, chọn vị trí phủ ô boss và nhiều ô kề nhất. Báo tỉ lệ trúng 1–5 ô cho 11 địch chương 1 vào Completion Notes, so với bảng đo nối ấn ngày 2026-10-24.
- [ ] Ảnh trong `production/qa/evidence/player-pieces/`: sân có mảnh rơi (hình thu nhỏ); túi 3 mảnh; **đang kéo: bóng nổi trên điểm chạm, nút Xoay ở vùng d-pad**; chế độ đặt bóng xanh (trúng); bóng đỏ (trượt); sau khi xoay; mảnh 1 ô đặt ở ô giữa sân; menu phép sau khi đặt; mảnh nguyền trong túi; HUD vi và en.
- [ ] Không hằng số gameplay trong mã; chuỗi mới là khóa `TEXT_*` với vi và en.

---

## Implementation Notes

- Tách logic thuần (`Piece`, `PieceLibrary`, `PiecePlacement`, rơi mảnh) khỏi view để test không cần cảnh. Rơi mảnh có thể là `FieldDrops` mang thêm payload hình, hoặc lớp riêng `PieceDrops` cùng API (`tick`, `pick_up_at`, `set_blocked_cells`, `place_rotten`); chọn cách ít đụng boss nhất vì boss vẫn dùng `FieldDrops` có nhãn.
- Chế độ đặt dùng lại `FocusController` (dừng hẳn) và `CutFlow` (menu); thêm trạng thái PLACING trước MENU. Một điểm vào duy nhất cho phím R / chuột phải / chạm lại.
- `--demo=pieces_hand|placing_hit|placing_miss|rotten_piece` và `--piece=<id>` cho chụp ảnh.
- Boss AI chấm điểm đòn theo đường thoát của **người chơi**, không phụ thuộc cách người chơi ra đòn; `_visible_incoming` chỉ đọc `player_actor.get_cells()` nên đòn từ mảnh tự tương thích.

---

## Out of Scope

- Boss dùng mảnh, boss đứng yên khi niệm, vòng cooldown bước boss (Story 025). Gỡ code nối ấn, chuyển `deck_sim`, đo lại cân bằng chương (Story 026). Kết giới / Trận gai (Story 027). Gộp hai mảnh thành một đòn, lật mảnh, trợ giúp theo chương (hiện ý định bước của boss), trận tập.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/player-pieces/`.
- Bảng tỉ lệ trúng mảnh thật so với nối ấn trong Completion Notes.

**Status**: Screenshots retained (player-pieces/01-09) + hit-rate table (player-pieces/hit-rates-pieces.md) + suites (tests/unit/pieces, cut_flow/focus_flow/input_test rewritten).

---

## Dependencies

- Depends on: Story 012 (Tập trung), Story 017 (menu rút 4 lá), Story 020 (sát thương theo lá), Story 014 (`rotten_thrower`)
- Unlocks: **cổng chơi thử 7** (người dùng chơi lại với mảnh), Story 025, Story 026, Story 027

---

## Completion Notes
**Completed**: 2026-10-25
**Criteria**: 23/23 pass or deferred, 0 failing. DEFERRED (needs real play on a device): feel of the touch drag (lift distance, thumb reach of the Xoay button, real multi-touch — every touch check so far uses synthetic events), the piece drop pace (3.0 s, max 3 on field, 8 s fresh, 1 start piece) and the 4 s Focus placing window, readability of the hit/miss tag on a small screen. UNTESTED (ADVISORY, TD-015): signature charge, passives and Anh Bo through the piece path (the code path is the same `_begin_cut`; only the unit-level `signature_test` covers the charge).
**Deviations**: ADVISORY: new suites live in `tests/unit/pieces/` (story said `tests/unit/combat/`). ADVISORY: `run_controller.gd` and `game_flow.gd` touched to pass `chapter_id` for chapter weights (outside the listed files, needed). ADVISORY (balance, TD-012): with real pieces 5-cell casts are the weakest (19 % mean hit rate against 35 % for rune-era clusters; 28 % vs 50 % right after a boss step) and eight cards now need 5 cells (dai_dao, hoa_tran, thien_lang, han_tran, song_kiem, han_bang, thien_hoa, tu_kiem); suggested fix in Story 026: a compact 5-cell shape (P-pentomino) or lowering some cards to 4. ADVISORY: bosses are not easier to hit with pieces (warlock 16 % aimed / 32 % right after a step, witch 15 % / 22 %, about the rune-era best case); the counter window of Story 025 is the lever. ADVISORY (TD-013): cancelling the card menu does not return the four drawn cards (`Deck` has no return API). ADVISORY (TD-014): small HUD defects — hit/miss readout appears twice during a drag, the tag covers part of the boss square, rotten-piece countdown contrast, English "Cancel" nearly fills its button, unused DOT_* constants in cut_hud_view.gd, label-era `--demo=` modes no longer match the player flow. FIXED in this story: untranslated "FULL" label (now `ui.hud.full`, ĐẦY / FULL); `PiecePlacement.snap` tie-break that could miss the cell under the finger; `bang_phong` 7 → 4 cells closes TD-003. API quirk: the player's bag must be built with `HoldSlots.create_piece_hand(n)` because `HoldSlots.new()` clamps to 3..4 for the boss.
**Test Evidence**: Integration; tests waived at `qa.level: minimal` but present and run: `tests/unit/pieces/` piece_test 43, piece_placement_test 51, piece_drops_test 77; windowed `tests/integration/ui/` cut_flow_test 41, focus_flow_test 31, input_test 35; `pause_flow_test` 78 and `trait_flow_test` 25 rewritten; status_test updated. Headless sweep of 35 suites: 33 green, `pace_test` FAILS=2 and `run_state_test` FAILS=16 are the known TD-011. Parse-check 31/31. strings.csv 315 rows, 3 columns each. Retained screenshots `production/qa/evidence/player-pieces/01-09*.png` (all opened and checked) and `hit-rates-pieces.md` plus `-raw.txt`.
**Code Review**: Skipped (solo mode).
**Not verified**: the touch feel on a phone, drop pace and balance with a human player, multi-touch on real hardware.
**Carries forward**: gate 7 playtest (play with pieces); Story 025 (boss uses pieces, counter window, step ring); Story 026 (retire runes, rebalance, 5-cell fix, TD-011); Story 027; TD-001..002, 004..015.
