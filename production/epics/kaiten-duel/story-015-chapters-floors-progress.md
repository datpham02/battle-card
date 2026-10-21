# Story 015: Chương và tầng — một run là một tầng, lưu tầng đã mở

> **Epic**: Kaiten Duel (v3)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-21

## Context

**GDD**: `design/game-brief.md` (v3, mục "Chương và tầng")
**Requirement**: Sau cổng chơi thử 4 (sau Story 014, 2026-10-20: "ổn và cân bằng hơn rồi"), người dùng muốn chuyển sang cấu trúc **vượt chương / vượt tầng**: mỗi tầng gồm N trận rồi boss; thắng boss tầng N mở tầng N+1. Hiện một run (`run.json`, Story 011) đúng bằng một tầng, nên story này **bọc** run hiện có vào tầng/chương, thêm màn chọn tầng và màn qua tầng, và lưu tầng đã mở. Quyết định đã chốt với người dùng: tầng thấp **một hình sân cố định** cho cả tầng; tầng cao rút **ngẫu nhiên từ nhóm hình** (`arena_pool`) kèm biến thể có kiểm (Story 014); **máu không mang qua tầng**; thua giữa tầng thì **chơi lại đúng trận đã thua** (người dùng chốt lại 2026-10-20, thay phương án "từ trận 1").

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: lưu bằng `FileAccess` vào `user://` (xem `docs/engine-reference/godot/` cho kiểu trả về của FileAccess ở 4.4+); không dùng `ConfigFile` để giữ một định dạng JSON duy nhất với phần còn lại của dữ liệu.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Dữ liệu chương/tầng**

- [ ] `assets/data/chapters.json` thay `run.json`: `{ "defaults": {heal_between_matches, intro_sec, end_delay_sec, between_sec}, "chapters": [ {id, display_name, floors: [ {id, display_name, arena?: {...}, arena_pool?: [shape_id…], arena_variant?: bool, matches: [ <khối trận như MATCH_KEYS của RunConfig> ]} ]} ] }`. Trận cuối của mỗi tầng là boss (như run hiện nay). `run.json` bị xóa; 4 trận hiện tại thành **tầng 1 của chương 1**.
- [ ] Luật sân của tầng: trận có `arena` riêng thì giữ; không thì nếu tầng có `arena` (hình cố định) mọi trận dùng hình đó; nếu tầng có `arena_pool` thì **mỗi trận rút một hình** từ nhóm theo **túi xáo seeded** (xáo nhóm theo `floor_seed` rồi đi vòng: hai trận liền kề không trùng hình khi nhóm ≥ 2) và áp `arena_variant` của tầng. Tầng không có gì → `combat.json`. Một tầng có cả `arena` lẫn `arena_pool` là lỗi dữ liệu (cảnh báo, dùng `arena`).
- [ ] **Seed sân theo lần vào tầng**: `RunController` sinh một `floor_seed` khi bắt đầu tầng (mới mỗi lần vào tầng; **giữ nguyên khi chơi lại trận thua** để thử lại đúng sân đã thua) và truyền `arena_seed = hash(floor_seed, chỉ số trận)` vào `match_params` (đóng lệch "arena_seed chưa truyền" của Story 014). Dev arg `--seed=N` ép seed để chụp ảnh tái lập được.
- [ ] Dữ liệu mẫu đủ để chứng minh luật: chương 1 "Quán vỉa hè" có 3 tầng — tầng 1: vuông cố định, 2 trận + boss (trận hiện tại, bớt một); tầng 2: chữ nhật cố định, 3 trận + boss; tầng 3: `arena_pool` [chữ thập, chữ U, bậc thang] + biến thể, 3 trận + boss. Chương 2 "Bếp khách sạn" có 1 tầng (vòng, biến thể) làm chỗ cắm nội dung sau và để kiểm luật mở chương. Số máu/bộ não/trait của các trận mới sao từ trận gần nhất, cân bằng là việc của đợt nội dung (Story 017).
- [ ] `RunConfig` nhận **một tầng** (`RunConfig.from_floor(resolved_floor, defaults)`; `from_dictionary` định dạng phẳng cũ vẫn dùng được và là cách test nạp một tầng ad-hoc qua `RunController.run_config_path`, mặc định rỗng, khi khác rỗng thì bỏ qua màn chọn tầng và không ghi tiến độ), `RunState` giữ các pha cũ và thêm `retry_match` / `resume_at` cho luật chơi lại; không có số 4 hay "trận cuối là boss" ngầm ngoài dữ liệu. `schema.md` có mục `chapters.json` và xóa mục `run.json`.

**Phần B — Tiến độ và luật mở**

- [ ] `ProgressState` (RefCounted, thuần) giữ **hai thứ**: (1) tập các tầng đã xong (`cleared: ["ch1/f1", …]`); `is_unlocked(chapter_i, floor_i)` = tầng đầu của chương 1, hoặc tầng ngay trước nó (trong chương, hoặc tầng cuối chương trước) đã xong; `mark_cleared`. (2) **Tầng đang dở** (`in_progress: {floor: "ch1/f2", match_index, hp_at_match_start, floor_seed}` hoặc null): ghi khi **bắt đầu mỗi trận** (kể cả trận 1; `hp_at_match_start` âm = máu đầy), xóa khi thắng boss tầng, khi người chơi chọn *Chơi lại từ đầu*, hoặc khi vào tầng khác (sau xác nhận). **Thoát ra chọn tầng từ màn thua không xóa**: tầng vẫn "đang dở" ở trận vừa thua. Mọi lần **tiếp tục** từ save (kể cả sau khi tắt app giữa trận) áp luật chơi lại: máu = max(`hp_at_match_start`, `retry_min_hp_ratio` × máu tối đa), `hp_at_match_start` âm thì đầy. `to_json`, `from_json` (dữ liệu hỏng/thiếu → tiến độ trống kèm cảnh báo, không crash; `in_progress` trỏ tới tầng không tồn tại → bỏ qua phần đó).
- [ ] `ProgressStore` ghi/đọc `user://progress.json` qua hai hàm nhỏ (`save_text`, `load_text`) để test tiêm bộ nhớ giả. Ghi **ngay** tại mỗi mốc (bắt đầu trận, thắng boss tầng, rời tầng), không chờ thoát app. Phiên bản `"version": 1` trong file. **Không lưu giữa một trận đang đánh** (quyết định: trận 1–2 phút thời gian thực; lưu giữa chừng vừa phức tạp vừa thành cách thoát khi sắp thua): tắt app giữa trận → mở lại vào đúng trận đó theo luật chơi lại (cùng sân, máu ≥ 50%).
- [ ] Dev arg `--progress=none|all` bỏ qua file lưu (trống / mở hết) để chụp ảnh và test; không ghi đè file thật khi dùng arg này.

**Phần C — Luồng và màn hình**

- [ ] **Màn chọn tầng** (`FloorSelectView`): danh sách chương, mỗi chương các ô tầng: *khóa* (xám, có ổ khóa vẽ bằng code), *mở* (sáng), *đã xong* (dấu tích), *đang dở* (viền nổi + "Trận 3/4"); hiện tên tầng và hình sân ("Chữ nhật", hay "Ngẫu nhiên" cho pool). Chạm ô mở → vào tầng từ trận 1; chạm ô đang dở → **tiếp tục từ trận đang dở** (vào tầng dở từ đầu là một nút phụ "Chơi lại từ đầu" trong ô đó, có xác nhận). Chỉ một tầng dở tại một thời điểm: vào tầng khác thì tầng dở cũ bị bỏ (hỏi xác nhận). Bố cục landscape 1280×720, chạm được bằng ngón cái (ô ≥ 96 px). Màn này là màn đầu tiên khi mở game cho tới khi Story 016 thêm title.
- [ ] **Màn qua tầng** thay màn thắng của Story 011: "TẦNG XONG — <tên tầng>", hai nút: *Tầng tiếp* (nếu có và đã mở) và *Chọn tầng*. Thắng tầng cuối của chương: "CHƯƠNG XONG", chỉ còn *Chọn tầng* (chương 2 đã mở).
- [ ] **Màn thua** có hai nút: *Chơi lại trận* và *Chọn tầng*. Chơi lại = **đúng trận vừa thua**, cùng sân (cùng seed), boss máu đầy, người chơi có máu như lúc bước vào trận đó nhưng không dưới `retry_min_hp_ratio` × máu tối đa (`chapters.json → defaults`, khởi điểm 0,5) để không kẹt ở boss với vài máu. Vị trí trong tầng **được lưu** (`in_progress`): thoát app rồi mở lại thì tiếp tục đúng trận đó. Nút chơi lại ngay trong màn thua giữ nguyên hành vi "không cần thoát" của Story 011.
- [ ] Máu: đầy khi vào tầng; trong tầng hồi `heal_between_matches` như hiện nay; không mang qua tầng. `RunState` ghi nhớ máu lúc vào mỗi trận (`hp_at_match_start`) cho luật chơi lại.
- [ ] Nhãn trận trong HUD: "Tầng 2 · Trận 1/4 · <boss> · <sân>" (bỏ chữ "Chương"; tên chương chỉ ở màn chọn tầng). Boss: "Tầng 2 · BOSS · …".
- [ ] Dev args: `--floor=ch1/f3` vào thẳng tầng; `--match=N`, `--run=intro|between|won|lost`, `--arena=`, `--demo=` vẫn chạy (demo dùng tầng 1 chương 1); `--run=won` nay hiện màn qua tầng.

**Chung**

- [ ] Test (scratch hoặc lưu `tests/`): luật mở tầng (chuỗi 3 tầng + sang chương); từ_json hỏng → trống; pool rút theo seed xác định, hai trận liền kề không trùng hình; `from_floor` áp sân cố định cho mọi trận; thua ở trận 3 → chơi lại trận 3, cùng `arena_seed`, máu = max(máu lúc vào trận 3, 50%); lưu rồi nạp lại giữa trận 3 → `in_progress` cho đúng trận 3, cùng seed, cùng máu; thắng boss → `in_progress` null và `cleared` có tầng; thắng boss tầng → `cleared` có tầng đó và `is_unlocked` tầng kế = true.
- [ ] Ảnh trong `production/qa/evidence/chapters-floors/`: màn chọn tầng với bốn trạng thái khóa/mở/xong/đang dở; màn qua tầng; màn chương xong; màn thua hai nút; hai trận của tầng pool với hai sân khác nhau; HUD nhãn "Tầng 2 · Trận 1/4".
- [ ] Không hằng số gameplay trong mã; mọi chuỗi hiển thị là `const TEXT_*`.

---

## Implementation Notes

- Giữ `RunController`/`RunState`/`RunHudView` là **một tầng**; thêm một lớp mỏng trên: `GameFlow` (Node, trong `src/main.tscn` thay chỗ `RunController` là con trực tiếp) sở hữu `ProgressState`, `ChaptersConfig`, màn chọn tầng, và tạo/hủy `RunController` khi vào/ra tầng. Màn qua tầng/thua có thể là `RunHudView` đọc thêm ngữ cảnh tầng (nút thứ hai) để không viết lại màn.
- `ChaptersConfig.load_from_file()` + `floor_for(chapter_i, floor_i) -> Dictionary` đã **giải sân** (điền `arena`/`arena_seed` vào từng trận) để `RunConfig.from_floor` không biết gì về pool. Dùng `ArenaLibrary.shape_ids` để kiểm id trong pool lúc nạp (id lạ → cảnh báo, bỏ khỏi pool; pool rỗng → `combat.json`).
- Seed: `floor_seed = randi()` trừ khi `--seed`; `arena_seed` của trận i = `hash([floor_seed, i])`.
- `ScreenLayout` thêm rect cho ô tầng (lưới 4 cột) và hai nút của màn kết; giữ grid-first.
- Thứ tự làm: A (dữ liệu + config, test thuần) → B (progress, test thuần) → C (GameFlow, màn chọn, nút thứ hai, HUD) → ảnh.

---

## Out of Scope

- Màn title, tạm dừng, nút back Android, ẩn dòng debug → Story 016.
- Nội dung thật cho tầng 2–3 và chương 2 (boss mới, trait mới, số cân bằng) → Story 017.
- Meta progression ngoài "tầng đã mở" (mở kỹ năng, chọn bộ kỹ năng, tiền tệ), điểm số, Daily Counter.
- Mang máu/điểm qua tầng; chọn lại trận giữa tầng; lưu **giữa** một trận đang đánh; nhiều slot lưu; sao lưu cloud.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/chapters-floors/`.
- Integration: `tests/integration/run/progress_test.gd` — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: Screenshots retained; integration test not saved (advisory at minimal).

---

## Dependencies

- Depends on: Story 011 (run), Story 014 (thư viện sân, biến thể, `arena_seed`)
- Unlocks: Story 016 (title/tạm dừng), Story 017 (nội dung chương)

---

## Completion Notes
**Completed**: 2026-10-21
**Criteria**: 16/16 pass. DEFERRED (needs real play): feel across three floors, difficulty of the new matches (numbers copied from the nearest existing match), floor select on touch.
**Deviations**: ADVISORY: any dev run arg (`--run`, `--match`, `--demo`, `--arena`) forces a memory store even with `--floor`, so captures never write the real save. ADVISORY: `enter_floor` writes the in-progress record immediately, in addition to every PLAYING start. ADVISORY: the chapter-clear screen offers only "Chọn tầng" although chapter 2 exists (as written in the story; a "Chương tiếp" button is an option). ADVISORY: floor select uses one fixed block per chapter, more than 4 floors in a chapter would overflow. ADVISORY: `GameFlow.enter_test_floor()` and `set_store_for_test()` are test hooks; scratch flow tests were repointed to them. Retry/resume rule: any resume from the save (including after quitting mid-match) applies max(hp at match start, 50% of max HP); leaving from the lose screen keeps the floor in progress.
**Test Evidence**: Integration; tests waived at `qa.level: minimal`. Retained screenshots `production/qa/evidence/chapters-floors/01-10*.png` (all opened and checked). Scratch tests: chapters 66 pass, floor flow 41 pass, trait/arena/run flow 0 fails (headless), cut/focus flow 0 fails (windowed). Real `user://progress.json` round trip verified once, file removed.
**Code Review**: Skipped (solo mode).
**Not verified**: real feel, touch on a device, a chapter with more than 4 floors.
**Carries forward**: Story 016 (title with Continue, pause, back, `--debug`); Story 017 (chapter content and balance); Story 018 (device build).
