# Story 041: Khối Lạ — khối hình ngẫu nhiên rơi xen kẽ khối hình học, cỡ theo số ô của sân

> **Epic**: Kaiten Duel (v6)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-28

## Context

**GDD**: `design/game-mechanics.md` (mục 2.2 "Khối rơi", 2.4 "Ghép khối và Hình Cộng Hưởng"), `design/game-brief.md` (Core loop v5 › "Mảnh ấn rơi", Story 034 bộ mảnh), `design/glossary.md`, `design/world-context.md`
**Requirement**:
- **Hiện trạng:** mọi khối rơi đều lấy từ một thư viện **cố định 19 hình** (`assets/data/pieces.json`), theo trọng số của bộ khối.
- **Yêu cầu của người dùng (2026-10-27):** khối còn phải có **hình dạng ngẫu nhiên**. Đã chốt như sau:
  - **Giữ** khối hình học và bộ khối hiện có, **thêm** khối hình ngẫu nhiên rơi xen kẽ.
  - **Cỡ** khối ngẫu nhiên phụ thuộc **số ô của sân**.
  - Tên: **Khối Lạ** / Odd Block.
- **Giới hạn toán học:** mọi hình liền nhau 1–4 ô (xoay, không lật) **đã có sẵn** trong thư viện, gồm 1 + 1 + 2 + 7 hình. Hình 5 ô có 18, thư viện có 8. Vì vậy một Khối Lạ "thật sự lạ" phải có **từ 5 ô trở lên** và **không trùng** hình nào trong thư viện:
  - Ở sân nhỏ (tối đa 5 ô), Khối Lạ là 10 hình 5 ô còn thiếu.
  - Ở sân lớn, có thêm hình 6–7 ô (60 và 196 hình).
- **Lore:** sau Biến Cố, sức mạnh đôi khi kết tinh thành những hình chưa ai biết.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM (khối to làm đổi cân bằng sát thương và thời gian niệm; não boss phải đặt được hình lạ; đọc hình lạ trên màn hình nhỏ)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Bộ sinh hình**

- [x] Một lớp sinh hình **Khối Lạ** nhận vào **danh sách ô thật của đất đích**, một **RNG có seed** và cấu hình. Nó trả về một hình:
  - **Liền nhau** theo cạnh.
  - Có số ô trong **[cỡ tối thiểu, cỡ tối đa của sân]**.
  - **Không trùng** (sau mọi phép xoay 90°) bất kỳ hình nào trong `pieces.json`, kể cả hình chỉ có trong chuyến leo.
  - **Đặt vừa đất đích** ở ít nhất một vị trí và hướng. Ở sân có đảo thì phải vừa trọn một đảo.
- [x] **Cỡ tối đa theo sân** = `clamp(floor(số ô đất đích / chia) + cộng, min, max)`, khởi điểm chia 4, cộng 3, min 4, max 7. Kết quả trên các sân hiện có:
  - Sân 9 ô: 5.
  - Sân 12 ô: 6.
  - Sân 17 ô trở lên: 7.

  **Cỡ tối thiểu** khởi điểm là 5. Nếu cỡ tối đa của sân nhỏ hơn cỡ tối thiểu thì sân đó **không có Khối Lạ**, kể cả sau Giao Kèo hay vùng đặc biệt.
- [x] **Phân bố cỡ:** trọng số theo số ô, khởi điểm 5: 6, 6: 3, 7: 1. Chỉ các cỡ ≤ cỡ tối đa của sân được tính.
- [x] **Không treo.** Số lần thử có giới hạn (khởi điểm 40). Nếu thử hết mà không ra hình hợp lệ thì rơi một khối hình học như cũ, và đếm số lần như vậy để mô phỏng báo cáo.
- [x] Cùng seed thì cùng hình. Bộ sinh hình không đụng RNG của các hệ khác.

**Phần B — Khối Lạ trong trận**

- [x] Mỗi lần một khối rơi, nó là **Khối Lạ** với xác suất `odd_block_chance` (khởi điểm 0,25, chỉnh bằng mô phỏng ở Phần E). Còn lại là khối hình học rút từ bộ khối như hiện nay.
  - Khối có sẵn đầu trận (`start_pieces`) luôn là khối hình học.
  - Các luật hiện có vẫn giữ: nhịp rơi, số khối tối đa trên sân, thời gian tươi.
- [x] Khối Lạ dùng **mọi luật của khối thường**:
  - Nhặt, túi 3, xoay 90° (không lật), đặt vừa đất địch, báo trúng.
  - Sát thương = sát thương mỗi ô × tổng ô; niệm 0,2 s + 0,25 s × ô.
  - Ghép tối đa 2 khối (3 với Tam Hợp), phá phép.
  - Bản Khắc. Hình Cộng Hưởng tính trên **hợp ô của đòn** như cũ, nên Khối Lạ ghép trúng hình của sân vẫn được ×1,5.
- [x] **Phía boss** dùng cùng luật: khối rơi bên boss có cùng xác suất là Khối Lạ, cỡ theo số ô **đất người chơi**.
  - Não boss (`boss_brain.gd`) chấm điểm và đặt Khối Lạ như mọi khối; không có trọng số riêng nếu không cần.
  - Một trận có trait `frost_aura` hoặc các đặc tính đổi nhịp rơi vẫn áp lên Khối Lạ.
- [x] **Không thuộc bộ khối:**
  - Khối Lạ không vào Học hình hay Quên hình, không làm đổi trọng số bộ khối.
  - Màn Bộ khối hiện thêm một dòng tỉ lệ Khối Lạ ở sân hiện tại (hoặc "Không có Khối Lạ ở sân này").
- [x] **Bảo vật và luật khác:**
  - Mảnh Tươi áp lên Khối Lạ.
  - Ấn Đơn không bao giờ kích hoạt với Khối Lạ (Khối Lạ ≥ 5 ô).
  - Phản Đòn vẫn cho khối ô đơn hình học.
  - Điều khoản Giao Kèo bậc 8 (khối rơi chậm) áp lên mọi khối.
  - Lá nguyền và các thứ khác không đổi.
- [x] Khối Lạ không lưu qua trận; khối trên sân và trong túi vẫn mất khi hết trận như hiện nay. Save chuyến leo không đổi phiên bản.

**Phần C — Hiển thị và chạm**

- [x] Khối Lạ **nhận ra ngay**, cả trên sân, trong túi, khi kéo, khi đã in lên đất và ở phía boss:
  - **Viền và màu riêng**, không trùng màu từ khóa (Cháy, Đóng Băng, Rạn, Giá Lạnh) hay màu báo trúng xanh/đỏ.
  - Thêm **dấu nhỏ** trong túi.
  - Khối hình 6–7 ô vẫn vừa ô túi (thu nhỏ theo khung hình bao).
- [x] Lần đầu nhặt Khối Lạ trong một chuyến leo thì hiện một dòng nhắc ngắn: "Khối Lạ: hình mới, to và mạnh, niệm lâu hơn". Dòng nhắc lưu đã thấy trong progress, như cờ "Mới mở" của Story 037.
- [x] Chuỗi mới (vi + en) là khóa trong `assets/i18n/strings.csv`, ghi bằng module csv. Tên hiển thị **Khối Lạ** / **Odd Block**. Các chuỗi khác của khối vẫn giữ chữ hiện tại ("mảnh"); việc đổi sang "khối" thuộc story đổi thuật ngữ.

**Phần D — Dữ liệu**

- [x] Mọi số nằm trong dữ liệu:
  - Khối `odd_blocks` trong `assets/data/field_drops.json`, gồm: `chance`, `min_cells`, `size_divisor`, `size_add`, `size_min`, `size_max`, `size_weights`, `max_tries`.
  - Trận ghi đè được (`odd_blocks` trong match của `chapters.json`), ví dụ để tắt Khối Lạ ở một trận.
  - Ghi trong `assets/data/schema.md`.
- [x] Không hằng số gameplay mới trong mã game.

**Phần E — Mô phỏng và cân bằng**

- [x] `tools/balance/sim_core.gd` / `deck_sim.gd` sinh Khối Lạ cho cả hai bên bằng cùng lớp sinh hình. Bot nhặt và đặt Khối Lạ như khối thường.
  - Cờ `--odd=on|off` và `--odd-chance=X`.
  - Thêm bảng: tỉ lệ Khối Lạ trên tổng khối rơi, cỡ trung bình, số lần rơi về khối hình học.
- [ ] Chạy `--run=v6` 70 seed mỗi nhân vật trên **bộ seed chưa dùng**, so `--odd=on` với `--odd=off`:
  - Tỉ lệ thắng chuyến leo mỗi nhân vật vẫn trong **30–45 %**, hoặc lệch không quá ±5 điểm so với kết quả Story 040 (44,3 / 35,7 / 42,9 / 27,1 / 47,1).
  - Không nhân vật nào lệch > 10 điểm giữa on và off.
  - Nếu lệch thì **chỉ chỉnh dữ liệu**: `chance`, `size_weights`, `min_cells`. Mỗi thay đổi một dòng trong Completion Notes.
- [x] Báo cáo trong `production/qa/evidence/random-blocks/simulation-random-blocks.md`, kèm file log thô.

**Phần F — Kiểm chứng**

- [x] Test unit cho bộ sinh hình:
  - Liền nhau, đúng khoảng cỡ, không trùng thư viện (kể cả các phép xoay), vừa sân.
  - Sân có đảo, sân có ô thiếu.
  - Seed cố định ra cùng hình, có giới hạn thử, rơi về khối hình học.
  - Công thức cỡ tối đa trên cả 19 sân, và sân không có Khối Lạ.
- [x] Test tích hợp:
  - Tỉ lệ Khối Lạ trong một trận seed cố định.
  - Đặt, ghép và cộng hưởng bằng Khối Lạ.
  - Boss đặt Khối Lạ.
  - Học hình và Quên hình không đụng Khối Lạ.
- [x] Toàn bộ suite headless và windowed FAILS=0; `main.tscn` chạy cửa sổ 0 lỗi.
- [x] Ảnh trong `production/qa/evidence/random-blocks/`:
  - Khối Lạ nằm trên sân.
  - Khối Lạ trong túi cạnh khối thường.
  - Đang kéo Khối Lạ lên đất địch với báo trúng.
  - Boss niệm bằng Khối Lạ (cảnh báo đỏ trên đất người chơi).
  - Dòng nhắc lần đầu.
  - Màn Bộ khối với dòng tỉ lệ Khối Lạ.

---

## Implementation Notes

- `PieceLibrary` hiện tra hình theo `id`. Khối Lạ cần một hình **tạo lúc chạy**, ví dụ id dạng `odd:<số>` kèm danh sách ô. Mọi chỗ gọi `shape_cells(id)` / `make_piece(id)` phải chấp nhận hình đó mà không cần nó nằm trong `pieces.json`. Kiểm `field_drops.gd`, `piece_deck.gd`, `boss_brain.gd`, `arena_validator.gd`, và các view vẽ khối (`field_drops_view.gd`, túi khối, bóng khối).
- **Sinh hình khuyên dùng:**
  1. Chọn cỡ theo trọng số.
  2. Bắt đầu từ một ô, mỗi bước thêm một ô kề ngẫu nhiên (thuật toán mọc).
  3. Chuẩn hóa hình về gốc (0,0) và so với cả 4 hướng xoay của mọi hình thư viện.
  4. Kiểm vừa đất bằng hàm đặt vừa hiện có.
- Hình 1–4 ô luôn trùng thư viện, nên `min_cells` < 5 chỉ làm tăng số lần thử. Validator dữ liệu nên cảnh báo khi `min_cells` < 5.
- Cỡ tính trên **đất đích hiện tại** (sau biến thể sân). Cát lấp ô và ô rơi tạm thời không tính.
- Khối Lạ được vẽ ghép từ ô như khối thường, nên không cần asset riêng ngoài viền và màu (xem `design/world-context.md` mục 8).
- Demo: `--demo=odd_field|odd_bag|odd_place|odd_boss`, hoặc cờ dev `--odd-chance=1` để chụp ảnh.

---

## Out of Scope

- Đổi chữ "mảnh" thành "khối" và các thuật ngữ khác của `design/glossary.md`: story đổi thuật ngữ riêng.
- Ghi lại một Khối Lạ để nó vào bộ khối ("Ghi hình"): ý tưởng để sau, xem `design/ideas-backlog.md`.
- Thêm 10 hình 5 ô còn thiếu vào thư viện: không làm, vì chúng là phần lớn Khối Lạ ở sân nhỏ.
- Bảo vật hay lá mới xoay quanh Khối Lạ.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Test unit và tích hợp ở Phần F; báo cáo mô phỏng và ảnh trong `production/qa/evidence/random-blocks/`.

**Status**: Created — `tests/unit/pieces/odd_block_test.gd`, `tests/integration/run/odd_block_flow_test.gd`, `production/qa/evidence/random-blocks/` (6 screenshots, simulation report + raw)

---

## Dependencies

- Depends on: Story 024–028 (khối, túi, đặt, ghép, Hình Cộng Hưởng), Story 034 (bộ khối), Story 040 (mốc cân bằng và công cụ `--run=v6`)
- Unlocks: story đổi thuật ngữ có thêm "Khối Lạ" đúng tên; Phần "Ghi hình" sau buổi chơi thử

---

## Completion Notes
**Completed**: 2026-10-28 (`/story-done`, verdict BLOCKED, closed by the user's explicit choice "Đóng, ghi nợ kỹ thuật")
**Criteria**: 22/23 passing. Not met: Part E win band (Giáo sĩ 54.3 % with odd blocks, outside 30–45 %). On the same seeds 3001–3070 Giáo sĩ wins 58.6 % with odd blocks off, so the miss is seed-set noise (sd about 6 per 70-seed cell; Story 040 measured 47.1 % on other seeds), not a Khối Lạ effect. Carried to TD-037. The max on/off gap is 10.0 points (Pháp sư), exactly the limit.
**Deviations**: first-ever hint instead of first-per-run; the piece-deck line states the rule from data, not per arena; no odd mark on Bản Khắc lit cells; in a multi-block cast the mark does not say which cells are odd. Relic and Giao Kèo interactions (an_don, manh_tuoi, phan_don, Kiep 8) were confirmed by reading the code, with no dedicated test.
**Test Evidence**: Integration: `tests/unit/pieces/odd_block_test.gd` (53), `tests/integration/run/odd_block_flow_test.gd` (24); sweep 255/255 parse, 107 headless + 5 windowed FAILS=0, launch 0 errors; 6 screenshots + simulation report and raw in `production/qa/evidence/random-blocks/`.
**Code Review**: Skipped (solo mode)
**Tech debt**: TD-037 (Giáo sĩ band, with the other open balance items), TD-038 (hint row overlaps the arena top).


**Implemented 2026-10-27** (`/dev-story`).

**Core (Part A, B, D):**
- New `src/pieces/odd_block.gd` (`OddBlock.generate` / `grow`) and `src/pieces/odd_block_config.gd` (`OddBlockConfig`).
- `Piece.ODD_PREFIX` / `is_odd()` / `canonical_key()`, and `PieceLibrary.has_equivalent_shape()`.
- `FieldDropsConfig.odd`. `FieldDrops` rolls odd blocks on tick spawns only, from its own seeded RNG; with chance 0 it makes no RNG call. It counts spawns, odd spawns and fallbacks.
- CombatView merges the match key `odd_blocks` and the dev arg `--odd-chance=` before the boss copy is made, so both sides get the same settings.
- `RunConfig.MATCH_KEYS` has `odd_blocks`.
- Data: `field_drops.json` `odd_blocks`, documented in `schema.md`.
- An odd piece is 5–7 cells and never matches a library shape under rotation. It always fits the target half; island arenas included.
- Max size by arena: 9 cells → 5, 12–15 → 6, 17 and up → 7. Every arena has odd blocks.

**Presentation (Part C):**
- Violet-magenta body, a bright magenta outer edge and a sparkle mark. This style is used on the field (both halves), in the bag (a 7-cell shape fits), on the placement ghost (green/red forecast still on top), on committed and running casts, and on the boss's red telegraph.
- First-ever pickup hint, stored as progress `seen_unlocks` `hint:odd_block`.
- Piece-deck line: "Khối Lạ: khoảng 12% khối rơi, 5–7 ô tùy sân (không học, không quên)".
- New strings `piece.odd.name`, `ui.hud.odd_hint`, `ui.piece_deck.odd_rule`, `ui.piece_deck.odd_none` (vi + en).
- Demos `--demo=odd_field|odd_bag|odd_place|odd_boss|odd_hint`.

**Deviations from the story text:**
1. The piece-deck line states the rule from the data, not a per-arena value, because the screen opens outside a match.
2. The hint is first-ever, not first per run, because it is stored in progress.
3. The Bản Khắc layer keeps no shape, so odd marks appear on placed and running casts, not on lit cells.
4. In a multi-block cast, the mark shows the cast has an odd block, not which cells came from it.

**Simulation (Part E):** `production/qa/evidence/random-blocks/simulation-random-blocks.md`, seeds 3001–3070, 70 runs per character, odd on vs off on the same seeds.
- At the first value of 0.25, Pháp sư gained +22.8 and Thợ săn +12.8, because big blocks hit hard and Pháp sư casts 4+-cell spells 25 % faster.
- Data change: `field_drops.json` `odd_blocks.chance` 0.25 → **0.12**.
- At 0.12: mean +0.3; per character +2.9 / +10.0 / −4.3 / −2.9 / −4.3, so the max is 10.0 = the limit (PASS).
- The odd share of drops is about 11 %, mean odd size 5.5, about 0.1 fallbacks per run.
- **Not met:** Giáo sĩ run win 54.3 % with odd blocks (band 30–45, Story 040 value 47.1). With odd blocks off on the same seeds it is 58.6 %, so the miss comes from the seed set, not this story. The character band is tracked by TD-037.

**Tooling:**
- `deck_sim` has `--odd=on|off`, `--odd-chance=X` and an `ODD` table.
- The bot plays odd blocks; its `--aware-min` limit was raised to 7.
- Fixed a placement-cache bug: odd pieces are keyed by their cells, because one canonical id can come in different base orientations. The game's boss brain already keyed its cache by cells.

**Tests:**
- New `odd_block_test` (53 checks) and `odd_block_flow_test` (24 checks; a real match where the boss casts a 5-cell odd piece: 1.45 s windup, 4 × 5 = 20 damage).
- `odd_block_test` was updated for the tuned chance 0.12. No old test needed changing.
- Sweep 2026-10-27: parse 255/255, 107 headless suites FAILS=0, 5 windowed suites FAILS=0, `main.tscn` 0 errors.

**Screenshots** (`production/qa/evidence/random-blocks/`, vi, arena `pillars`): 01 odd blocks on both halves, 02 bag with two odd blocks and the hint, 03 placing a 7-cell odd block (forecast 7 ô / −42), 04 the boss's 7-cell odd cast telegraph, 05 first-pickup hint, 06 piece-deck rule line at 12 %.

**Tech debt:** TD-038. The hint and the piece-deck notice share the status row that overlaps the arena top, so grid lines cross the text. It is readable; UI polish is deferred until art.

