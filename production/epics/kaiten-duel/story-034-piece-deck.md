# Story 034: Bộ mảnh của run — trọng số hình mảnh riêng của người chơi, "Ấn hình" và "Xóa hình", luôn còn hình vừa sân

> **Epic**: Kaiten Duel (v6)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-26

## Context

**GDD**: `design/game-brief.md` (v6, mục "Run v6 — mô hình OSFE" → "Xây build trong run": **Bộ mảnh**; nền: mục "Core loop (v5)" → "Mảnh ấn rơi", "Ghép mảnh và hình chủ đạo")
**Requirement**: Hiện túi rơi của người chơi lấy trọng số cố định theo chương (`pieces.json` → `weights.ch1..ch3`, đọc qua `PieceLibrary.weight(id, chapter_id)` trong `FieldDrops._draw_piece`). Brief v6 coi bộ mảnh là **bộ bài thứ hai của run**: người chơi thêm hình hoặc bỏ bớt hình để lái build (mảnh nhỏ niệm nhanh, mảnh lớn sát thương cao, cặp hình để ghép hình chủ đạo). Boss vẫn dùng trọng số gốc.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM (đổi nguồn trọng số của `FieldDrops`, luật dự phòng "luôn có hình vừa sân", save run)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Mô hình bộ mảnh**

- [ ] `RunSession.piece_deck` = `{mult: {shape_id: float}, added: [shape_id]}`. Khởi đầu: mọi hình có trong `pieces.json` → `shapes` với `pool` mặc định có `mult` 1,0; `added` rỗng. Lưu khóa `piece_deck` trong save run; thiếu khóa = khởi đầu; id lạ bị bỏ có cảnh báo.
- [ ] **Trọng số hiệu dụng** của người chơi trong một trận: `w(s) = base(s, khóa vùng/tầng) × mult(s)`; với hình chỉ có qua run (`pool: "run_only"`) thì `base = run_only_weight` (khởi điểm 6). `base` vẫn lấy từ `pieces.json` theo khóa vùng/tầng mà Story 031 chốt (hiện là `ch1..ch3`/`default`). Hình có `w = 0` không rơi.
- [ ] `pieces.json` thêm 3 hình **chỉ có qua run** (khởi điểm; vì không lật nên ảnh gương là hình khác): `z4` (gương của `s4`), `j4` (gương của `l4`), `y5`. Có `name_key` vi/en, `pool: "run_only"`. Bảng hình trong `schema.md` cập nhật.
- [ ] `FieldDrops.enable_pieces` nhận thêm một nguồn trọng số tiêm vào (Callable hoặc Dictionary, mặc định = trọng số gốc) — không đọc `RunSession` trực tiếp; `CombatView` truyền trọng số hiệu dụng cho **phía người chơi**. **Boss không bị ảnh hưởng**: mọi đường rơi mảnh của boss vẫn đọc `PieceLibrary.weight` gốc (test xác nhận).

**Phần B — Ấn hình và Xóa hình**

- [ ] **Ấn hình** (phần thưởng): đưa ra 2 hình (seeded); chọn một → nếu là hình `run_only` chưa có thì thêm vào `added` (`mult` 1,0); nếu đã có thì `mult += 1,0` (trần `mult_max` khởi điểm 4,0). Hình đã ở trần không được đưa ra.
- [ ] **Xóa hình**: đặt `mult(s) = 0`. Từ chối (không đổi gì, có thông báo) khi sau đó bộ còn **ít hơn `min_shapes`** hình có `mult > 0` (khởi điểm 5). Hình đã xóa có thể được Ấn hình lại (về `mult` 1,0).
- [ ] **Luôn còn hình vừa sân**: lúc vào trận, nếu không hình nào trong bộ (có `w > 0`) đặt vừa đất địch của sân đó (bộ lọc `PiecePlacement.has_any_placement` sẵn có), thì trận đó dùng trọng số gốc cho các hình vừa sân, ghi cảnh báo, và HUD hiện một dòng "Bộ mảnh không vừa sân này — dùng mảnh gốc". Test với một bộ chỉ còn hình 5 ô trên sân hẹp.
- [ ] Nguồn (số trong `rewards.json` → khối mới `piece_rewards`, mô tả trong `schema.md`): sau trận `battle`/`danger` thắng, với xác suất `ink_offer_chance` (khởi điểm 0,35) màn thưởng có thêm hàng **Ấn hình** (chọn hoặc bỏ qua, không mất lượt chọn lá); kho báu luôn có hàng Ấn hình; **token Xóa hình** `shape_removals` khởi đầu 1, +1 mỗi boss vùng, dùng ở màn bộ mảnh. Nếu Story 033 đã xong: cửa hàng thêm dịch vụ "Xóa hình" (giá khởi điểm 45, 1 lần/cửa hàng) và một sự kiện có thể trao Ấn hình — không bắt buộc cho story này.

**Phần C — Hiển thị (mobile ngang, ngón cái)**

- [ ] Màn **Bộ mảnh**, mở bằng một nút trên HUD bản đồ (và từ màn thưởng khi chọn Ấn hình/Xóa hình): lưới các hình (vẽ bằng code như hình thu nhỏ trên sân), mỗi hình kèm **% rơi** tính theo vùng kế tiếp (hoặc vùng hiện tại), số `mult` dạng chấm (1–4), hình đã xóa mờ có gạch. Ô chạm mỗi hình ≥ 64 dp.
- [ ] Xóa hình: chạm hình → hình nổi lên, nút **Xóa hình (còn N token)** góc dưới phải; khi bị chặn bởi `min_shapes` nút mờ kèm lý do. Ấn hình: hai thẻ hình lớn giữa màn, chạm chọn rồi xác nhận góc dưới phải, "Bỏ qua" góc dưới trái.
- [ ] Màn thưởng hiện hàng Ấn hình dưới hàng lá, không đẩy nút xác nhận ra khỏi vùng ngón cái.

**Phần D — Kiểm chứng**

- [ ] Test (`tests/unit/pieces/` hoặc `tests/unit/run/`): trọng số hiệu dụng đúng công thức; Ấn hình thêm `run_only` và tăng `mult`, dừng ở `mult_max`; Xóa hình bị chặn ở `min_shapes`; luật dự phòng khi không hình nào vừa sân; boss rơi theo trọng số gốc khi bộ người chơi đã đổi; `FieldDrops` với nguồn trọng số tiêm vào cho phân bố đúng trên 10 000 lần rút seeded (sai số ≤ 2 điểm %); save/load giữ `piece_deck` và `shape_removals`.
- [ ] **Mô phỏng**: `deck_sim` / `hit_probe` thêm `--piece-deck=remove:mono,bar2|add:y5,square` (bộ mảnh cố định cho bot từ đầu run). Ba cấu hình × 3 nhân vật × 70 seed: gốc; bỏ hình nhỏ (`mono`, `bar2`, `bar3`); bỏ hình lớn (`plus5`, `u5`, `bar5`). Báo tỉ lệ trúng theo cỡ đòn, số đòn mỗi trận, tỉ lệ ghép, tỉ lệ đòn hình chủ đạo, phá phép được/bị phá, và tỉ lệ thắng vùng/run. Nếu một cấu hình nâng tỉ lệ thắng **quá 10 điểm** (khởi điểm) so với gốc thì đó là chiến lược trội: chỉnh `min_shapes`, `mult_max` hoặc `run_only_weight` và đo lại. Bảng trong Completion Notes và `production/qa/evidence/piece-deck/simulation-piece-deck.md`.
- [ ] Ảnh trong `production/qa/evidence/piece-deck/`: màn Bộ mảnh với một hình đã xóa và một hình `mult` 3 (vi và en); màn Ấn hình hai thẻ (vi và en); nút Xóa hình bị chặn ở `min_shapes`; trên sân rơi một hình `run_only` (`z4` hoặc `j4`); dòng HUD của luật dự phòng.
- [ ] Không hằng số gameplay trong mã; chuỗi mới (`piece.z4.name`, `piece.j4.name`, `piece.y5.name`, `TEXT_PIECE_DECK_*`) có vi và en.

---

## Implementation Notes

- Điểm đổi duy nhất của việc rút: `FieldDrops._draw_piece()` (đang cộng `_piece_library.weight(id, _chapter_id)`); thay bằng một hàm trọng số tiêm vào khi `enable_pieces` được gọi, mặc định gọi lại `PieceLibrary.weight`.
- `PieceLibrary` (`src/pieces/piece_library.gd`) bỏ qua hình `run_only` trong `weight()` gốc (trả 0) để chúng không rơi cho boss hay trận không có run.
- Hình chủ đạo của sân (`arenas.json`) có thể không còn ghép được sau khi người chơi xóa hình: đây là đánh đổi của người chơi, không chặn; chỉ ghi số liệu trong mô phỏng.
- `--demo=piece_deck|ink_offer|shape_remove_blocked|run_only_drop|deck_fallback` cho chụp ảnh.

---

## Out of Scope

- Bộ mảnh cho boss; hình mảnh có hiệu ứng riêng (mảnh cháy, mảnh nguyền); lật hình; hình 6 ô trở lên; mở khóa hình theo cột mốc (story chơi lại); bảo vật đổi bộ mảnh (có thể thêm sau ở `relics.json`); dịch vụ cửa hàng khi Story 033 chưa xong.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/piece-deck/` (màn mới có bản vi và en); `simulation-piece-deck.md` + raw.

**Status**: Created — production/qa/evidence/piece-deck/ (01-10 screenshots, simulation-piece-deck.md + raw)

---

## Dependencies

- Depends on: Story 031 (bản đồ thế giới v6: khóa vùng/tầng cho trọng số gốc, màn thưởng v6, save run v6)
- Unlocks: dịch vụ "Xóa hình" ở cửa hàng (Story 033 nếu làm sau), bảo vật về bộ mảnh, mở khóa hình mảnh theo cột mốc

---

## Completion Notes
**Completed**: 2026-10-26
**Criteria**: 14/15 pass, 1 failing (D2: a dominant strategy was found and not tuned away; closed anyway by the user's explicit call, logged as TD-030, to be fixed in Story 040). The simulation bot (dodge 0.85 = TD-006 default, fixed deck from the first match) is not a player: a real player reaches a thinned deck only after the first token or a shop, so the real effect is probably smaller; the gate 8 playtest settles it.
**What changed**: `assets/data/pieces.json` (`pool` field; run_only shapes `z4`, `j4`, `y5`), `assets/data/rewards.json` (`piece_rewards`), `assets/data/economy.json` (`shop.services.remove_shape` 45 gold, 1 use), sections in `schema.md`; `src/pieces/piece_deck.gd` + `piece_deck_config.gd` (pure rules: effective weights, ink offer and apply, removal with `min_shapes`, fit-the-arena fallback), `PieceLibrary` (pool, run_only ids, `weight()` = 0 for run_only), `FieldDrops.enable_pieces(..., weight_source)` (a Dictionary or Callable; the boss path passes none); `RunSession` (`piece_deck`, `shape_removals`, `pending_ink_offer` in the save, no version bump; a region boss grants a removal token); `GameFlow` (`Phase.PIECE_DECK`, `get_piece_deck_rows`, `remove_shape`, ink offer API, ink roll in `_offer_reward`: after battle/danger with `ink_offer_chance`, always at a treasure; `piece_deck` in every player match incl. the `tran_thach` fight; dev flags `--run=piece_deck`, `--run=ink_offer`, `--run=ink_offer_capped`, `--shape-removals=N`, `--piece-deck-state=`); `ShopLogic` / `ShopView` service `remove_shape` (gold, shape picker); `CombatView` player weights and the fallback notice drawn by `CutHudView` (3 s); `PieceDeckView` screen (new) with a "Bo manh" button on both maps; the Ink row in `RewardView`; 28 new strings (vi + en); `deck_sim` / `sim_core` / `hit_probe` `--piece-deck=<spec>|base|small_out|big_out` with a `WORLD PIECES` table.
**Simulation** (`deck_sim --world`, 70 seeds x 3 characters, build policy; tables in `production/qa/evidence/piece-deck/simulation-piece-deck.md`, raw output beside it). Run win Kiem si / Phap su / Sat thu: base 18.6 / 14.3 / 5.7; `remove:mono` 40.0 / 25.7 / 11.4 (mean +12.8); `remove:mono,bar2` 34.3 / 38.6 / 14.3 (+16.2); small_out (mono, bar2, bar3) 32.9 / 27.1 / 4.3 (+8.6); big_out (plus5, u5, bar5) 18.6 / 17.1 / 11.4 (+2.8). Hit rate stays about 33 % while casts carry more cells (3.28 -> 4.00 cells per cast) and joins fall (0.62 -> 0.09 per match). No configuration hit the arena fallback.
**Deviations**: FAIL (D2, TD-030): removing small shapes is a dominant strategy (one removal, mono: +12.8 points on the mean, +21.4 for Kiem si; the story threshold is +10); `min_shapes`, `mult_max` and `run_only_weight` cannot stop it (only `min_shapes` 13 would, which disables removal), so no data was changed. ADVISORY (TD-030): the Ink row's confirm and skip buttons sit inside the row at its right end, not at the bottom corners, and its tiles are medium, not large; a battle reward screen (phase IN_NODE) cannot open the piece deck screen (Ink is on its own row, removal in the deck screen or the shop); the treasure screen with card + relic + Ink rows is tight (shot 10: card name touches the rarity line, relic text cut to one line); the fallback notice is drawn over the trait readouts for its 3 seconds; no event grants an Ink (the story marks it optional); the drop % uses the current region, not the next. ADVISORY: `run_controller.gd` was touched (it was not in the package list) to carry `piece_deck` into the match params; `piece_test` and `piece_placement_test` now count `base_shape_ids()` because the library holds 16 shapes; `PIECE_DECK_NOTICE_SEC` is a code constant (presentation timing) not a data field. Scope: touched beyond the story text: `cut_hud_view.gd`, `run_controller.gd`, `chapter_map_view.gd`, `world_map_view.gd`, `reward_view.gd`, `shop_view.gd`, `screen_layout.gd`, `src/main.tscn` (PieceDeckView node), `tools/balance/*`.
**Test Evidence**: Integration; tests waived at `qa.level: minimal` but present and run on the final code: new suites `tests/unit/pieces/{piece_deck,piece_library_pool,field_drops_weight_source}_test.gd`, `tests/unit/run/run_session_piece_deck_test.gd`, `tests/integration/run/piece_deck_flow_test.gd`, `tests/unit/combat/piece_deck_match_test.gd`, `tests/unit/ui/piece_deck_strings_test.gd`; parse-check 188/188; 70 headless and 4 windowed suites FAILS=0 with no script error; `main.tscn` launched windowed with `--quit-after 300`, 0 error lines. Retained screenshots `production/qa/evidence/piece-deck/01-10*.png` (all opened and checked; 03, 04 and 09 were retaken after a string fix) plus `simulation-piece-deck.md` and `simulation-piece-deck-raw.txt`. New suites not mutation-checked.
**Code Review**: Skipped (solo mode).
**Not verified**: feel on a phone, whether a real player thins the deck early and how strong that is, the Ink row and the deck screen on a touch screen, hold or drag behaviour on the shape tiles.
**Carries forward**: Story 040 (rebalance: lower the base weights of `mono` / `bar2`, or give small casts an edge, or ration removal tokens, then re-measure the three configurations); gate 8 playtest; TD-001..006, 008..016, 018, 020, 021, 023..030.
