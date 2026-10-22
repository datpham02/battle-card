# Story 017: Lá bài và bộ bài — menu rút 4 lá, cộng đổi vỏ fantasy

> **Epic**: Kaiten Duel (v4)
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-22

## Context

**GDD**: `design/game-brief.md` (v4, mục "Lá bài và bộ bài", "Thế giới")
**Requirement**: Người dùng muốn lớp roguelike: nhân vật theo lớp có bộ bài khởi đầu, nhặt lá qua tầng. Bước một là biến **kỹ năng** thành **lá bài** và cho menu **rút 4 lá từ bộ bài** mỗi lần thi triển, thay cho 4 kỹ năng cố định. Cùng lúc đổi vỏ sang fantasy ở mức dữ liệu và chuỗi hiển thị (bỏ sushi/bếp). Chưa có nhân vật (018) và thưởng (019): story này dùng một bộ mặc định.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Lá bài thay kỹ năng**

- [ ] `assets/data/cards.json` thay `skills.json`: giữ `menu_time_scale`, `menu_choose_sec`, khối `focus`, thêm `hand_size` (4), `default_card` ("kiem_khi"), `default_deck` (danh sách id, dùng khi chưa có nhân vật: 2 kiem_khi, 2 chan_phong, 1 hoa_tran, 1 bang_phong), và `cards` {id → display_name, effect, min_cells, cooldown_sec, tham số hiệu ứng, `rarity` (common/rare/epic), `class_tags` [], `implemented`}. Bốn lá cơ bản: `kiem_khi` (damage), `chan_phong` (push), `hoa_tran` (burn), `bang_phong` (pin), giữ nguyên số v3. `SkillConfig` đổi tên thành `CardConfig` (hoặc giữ lớp, đổi file và thêm getter; nói rõ trong Completion Notes); `schema.md` cập nhật.
- [ ] **`Deck`** (RefCounted, thuần, seeded): danh sách id lá; `draw(n)` rút theo **túi xáo** (xáo cả bộ, rút lần lượt, hết túi xáo lại; lá trùng được phép); `size`, `add`, `remove_at`, `to_array`/`from_array`; `reset_bag(seed)`. Test: cùng seed cùng chuỗi rút; 12 lá rút 3 tay 4 lá không lá nào xuất hiện quá số bản trong bộ.
- [ ] **Menu rút bài**: khi `CutFlow.open_menu` mở, nó nhận **tay** = `deck.draw(hand_size)` (từ `CombatView`, bộ bài là `match_params["deck"]` hoặc `default_deck`); các ô menu hiện đúng tay đó theo thứ tự rút; lá chưa đủ ô vẫn khóa "cần N ô"; chọn lá → hiệu ứng như nay (cooldown theo id). Hết giờ → `default_card` dù không có trong tay. Nếu bộ ít hơn `hand_size` lá thì tay ngắn hơn, ô thừa trống.
- [ ] Boss **không rút bài**: mỗi trận có `boss_cards` trong `chapters.json` (mặc định 4 lá cơ bản); não boss chấm điểm trên danh sách đó như nay. Không sửa `BossBrain` ngoài việc đổi nguồn danh sách.
- [ ] Mọi test mô phỏng seeded vẫn xác định; test: tay rút khác nhau giữa hai lần thi triển với bộ 8 lá; bộ 3 lá cho tay 3; hết giờ chọn ra `kiem_khi` khi tay không có nó; cooldown theo id vẫn chặn lá trùng.

**Phần B — Đa ngôn ngữ (người dùng yêu cầu 2026-10-22, làm cùng lượt đổi vỏ)**

- [ ] Dùng hệ dịch của Godot: `assets/i18n/strings.csv` (cột `keys,vi,en`, UTF-8, Godot import thành `.translation`; `project.godot` khai báo `internationalization/locale/translations` và `fallback = "vi"`). Khóa đặt theo nhóm: `ui.*` (nút, tiêu đề, nhãn), `card.<id>.name` / `card.<id>.desc`, `chapter.<id>.name`, `floor.<id>.name`, `boss.<id>.name`, `arena.<id>.name`, `trait.<id>.name`, `title.*`.
- [ ] Mọi `const TEXT_*` trong `src/` trở thành **khóa** và được vẽ qua `tr()`; chuỗi có tham số dùng `tr(key) % [...]`. Không còn chữ hiển thị tiếng Việt viết thẳng trong mã (kể cả `ArenaNames`, trait `display_name`).
- [ ] JSON: `display_name` → `name_key` (cards, chapters, floors, matches/boss, traits params); `schema.md` ghi quy ước. Mã đọc `name_key` rồi `tr()`; thiếu khóa thì hiện khóa thô (Godot mặc định) để lộ lỗi.
- [ ] Hai ngôn ngữ đủ từ đầu: **vi** và **en**. Nút **VI / EN** ở màn title (`UiButtons`, góc dưới phải), gọi `TranslationServer.set_locale`, lưu `locale` vào `progress.json` (khóa mới, v1 không có thì mặc định vi), áp lại khi mở game. Mọi view vẽ lại theo ngôn ngữ mới ngay (view vẽ mỗi khung nên không cần làm gì thêm; ghi nhận nếu có chỗ cache chuỗi).
- [ ] Test scratch: quét `src/**/*.gd` lấy mọi giá trị `TEXT_*` và `assets/data/*.json` lấy mọi `name_key`, kiểm tất cả đều có trong CSV với cả hai cột không rỗng; `tr()` với locale en trả về chuỗi en cho vài khóa mẫu.
- [ ] Ảnh: title ở en, menu phép ở en (thêm vào bộ ảnh Phần C).

**Phần C — Đổi vỏ fantasy (dữ liệu và chuỗi, không logic)**

- [ ] `chapters.json`: chương 1 *Rừng Sương* (tầng Bìa rừng / Lối mòn / Hang sói; đối thủ goblin, sói, boss *Thủ lĩnh Goblin*…), chương 2 *Hầm Ngục* (một tầng mẫu, boss *Quỷ Khổng Lồ*). Cùng số với hiện nay, chỉ đổi id/tên. Trait hiện tên: `row_burner` → "Hỏa tức", `rotten_thrower` → "Ấn nguyền" (tên hiển thị trong JSON trait params `display_name` hoặc bảng trong `ArenaNames`-style const; id code giữ).
- [ ] Chuỗi UI (trong CSV, cả vi và en): nút "Chốt" → "Thi triển" / "Cast"; gợi ý intro "Nhặt ấn · nối trận pháp · Thi triển"; title "ẤN KIẾM" / "RUNE DUEL" và tagline; "Ấn" ở chỗ nào đang ghi "điểm"; tên lá từ `card.<id>.name`. Không còn chuỗi "sushi", "bếp", "dao", "thớt" trong `src/`, `assets/data/`, CSV (grep sạch, trừ lịch sử trong docs).
- [ ] `project.godot` `config/name` = "Ấn Kiếm" (tiêu đề cửa sổ); tên repo và thư mục không đổi.
- [ ] Ảnh trong `production/qa/evidence/cards-deck/`: menu với tay 4 lá rút ở hai lần thi triển khác nhau (hai ảnh, tay khác nhau); menu với bộ 3 lá (một ô trống); title "ẤN KIẾM" (vi) và "RUNE DUEL" (en); HUD với tên chương/boss/sân mới; menu phép ở en.
- [ ] Không hằng số gameplay trong mã; chuỗi `TEXT_*`.

---

## Implementation Notes

- `CutFlow.open_menu(labels, cells)` hiện lấy `skill_order` từ config; đổi thành nhận `hand: Array[String]` do `CombatView` rút từ `Deck` ngay lúc mở menu. `CutHudView` vẽ theo `flow.get_hand()`; `ScreenLayout.skill_menu_rects(vp, n)` đã nhận số ô.
- `SkillCooldowns`, `SkillAvailability`, `CutEffects` chỉ đổi nguồn config; giữ API.
- `match_params["deck"]` là `Array[String]`; `RunController` truyền từ `RunConfig` (mặc định `default_deck`; 019 thay bằng bộ của run). `match_params["boss_cards"]` tương tự.
- Đổi vỏ: làm bằng một lượt sửa dữ liệu + grep chuỗi; không đổi id code (`row_burner`, `slash` → đổi thành `kiem_khi` chỉ trong dữ liệu và `FALLBACK`; nếu đổi id code thì đổi hết một lượt, không nửa vời).

---

## Out of Scope

- Nhân vật, nội tại, bộ khởi đầu theo lớp (018). Thưởng lá, pool, độ hiếm có tác dụng (019; `rarity`/`class_tags` ở đây chỉ là dữ liệu).
- Lá mới với hiệu ứng mới (nội dung sau 019).
- Hình, âm. Ngôn ngữ thứ ba trở đi, phông riêng, số nhiều/giống; dịch nội dung docs.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/cards-deck/`.

**Status**: Screenshots retained (cards-deck/01-09).

---

## Dependencies

- Depends on: Story 008 (menu), Story 010 (hiệu ứng), Story 015 (chapters.json)
- Unlocks: Story 018, Story 019

---

## Completion Notes
**Completed**: 2026-10-22
**Criteria**: 17/17 pass. DEFERRED (needs real play): feel of drawing from a 6-card deck (repetition), quality of the English translation, hands drawn from very small decks.
**Deviations**: ADVISORY: class names SkillConfig / SkillCooldowns / SkillAvailability / CutFlow kept; only the data file (`cards.json`, git-renamed from `skills.json`), ids and semantics changed. ADVISORY: a 3-card hand renders 3 wide slots instead of 4 slots with one empty. ADVISORY: Godot's default locale is the OS locale; GameFlow applies the saved locale (default vi) at startup, scratch tests set the locale explicitly. ADVISORY: generated `.translation` files are gitignored; the CSV is the source and `--import` regenerates them. Timeout in the menu always picks `default_card` (kiem_khi), even if it is not in the hand, as the story says. Dev args added: `--lang`, `--deck`, `--drops-seed`.
**Test Evidence**: Integration; tests waived at `qa.level: minimal`. Retained screenshots `production/qa/evidence/cards-deck/01-09*.png` (all opened and checked). Scratch tests: i18n, deck, chapters (67), floor/pause/trait/run/arena flow 0 fails (headless); cut_flow and focus_flow 0 fails (windowed, `--no-autopause`). Scan: 0 Vietnamese literals in code strings, 0 theme words.
**Code Review**: Skipped (solo mode).
**Not verified**: real feel, English translation quality, touch on a device.
**Carries forward**: Story 018 (characters, passives, starter decks, character select) and Story 019 (rewards, run, permadeath, run save). Every new string from now on is a key plus vi and en CSV rows.
