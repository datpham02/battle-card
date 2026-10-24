# Story 022: Bản đồ chương và kinh tế thưởng — khung nút cố định, nhánh 2–3, token bỏ lá, thưởng theo loại nút, độ hiếm trôi theo may mắn

> **Epic**: Kaiten Duel (v4)
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-24

## Context

**GDD**: `design/game-brief.md` (v4, mục "Run"), `design/reference/osfe-reference.md` (§6, §9.2, §9.3)
**Requirement**: Chương hiện là danh sách trận thẳng (3 tầng × 3 trận). Tài liệu tham chiếu OSFE cho thấy một run hay là **khung cố định + ngẫu nhiên trên nền**: mỗi world chắc chắn có shop, miniboss, trại nghỉ, kho báu, boss, và mỗi cột 2–3 nút để người chơi chọn; thưởng quyết định theo loại nút; bỏ lá là token hiếm; độ hiếm thưởng trôi theo may mắn tích lũy. Story này đưa bốn điều đó vào Ấn Kiếm mà **không** thêm nội dung mới (boss/lá của chương 2–3 là Story 023).

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH (đụng GameFlow, RunSession, save v4, màn chọn chương)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Bản đồ chương (`chapters.json` v2)**

- [ ] Mỗi chương định nghĩa **cột** thay cho tầng: `columns: [{kinds: [...], pick: N}]`. Loại nút (`NodeKind`): `battle`, `danger` (trận + ô cháy sẵn / trait thêm), `treasure` (1 lá thưởng miễn phí, không đánh), `rest` (trại nghỉ, xem Phần C), `miniboss`, `boss`. Khung mặc định cho chương 7 cột, lấy theo OSFE §9.3: cột 0 = 1 battle; cột 1–2 = 2–3 nút từ {battle, danger, treasure}; cột 3 có đúng 1 `miniboss`; cột 4 có đúng 1 `rest` và 1 treasure-hoặc-battle; cột 5 = 2–3 nút {battle, danger}; cột 6 = `boss`. Số nút mỗi cột và loại nút ngẫu nhiên **seeded theo run** (`run_seed`), cùng seed cùng bản đồ. Hai nút anh em không cùng loại khi có thể.
- [ ] Pool trận theo loại nút và theo **bậc cột** (`tier` 0–2 ánh xạ từ cột như OSFE `CalculateStageNum`: cột 0 → 0, cột 1–2 → 1, cột ≥3 → 2; **kẹp ≤ 1 khi người chơi chưa thắng boss nào trong save** — onboarding ẩn). Mỗi pool là danh sách match hiện có (`goblin_scout`…). Chương 1 giữ đúng 9 trận hiện nay phân vào pool; không thêm boss mới ở story này.
- [ ] `RunSession` lưu `map` (danh sách cột đã sinh), `column`, `node_index`, `cleared_nodes`; save v4; v3 (tầng/trận) nạp được bằng cách **bắt đầu lại chương** với thông báo một dòng (không crash, không mất chương đã thắng).
- [ ] **Màn chọn nút** (`ChapterMapView`, thay `FloorSelect` đã bỏ ở 019): vẽ 7 cột, nút của cột hiện tại bấm được, nút đã qua tô, nút khóa mờ; biểu tượng theo loại (chữ/ký hiệu vẽ bằng code, không ảnh); boss cột cuối luôn thấy. Nút back = Về title (giữ save).

**Phần B — Kinh tế thưởng**

- [ ] **Thưởng theo loại nút**, không ngẫu nhiên: `battle`/`danger` → chọn 1 trong 3 lá (như nay); `treasure` → 1 lá chọn 1 trong 3 **không cần đánh**; `miniboss` → 1 trong 3 lá **độ hiếm tối thiểu rare**; `boss` → 1 trong 3 lá + **1 token bỏ lá**; `rest` → không lá.
- [ ] **Token bỏ lá** (`RunSession.removal_tokens`): khởi đầu `rewards.json → starting_removals` (1); mỗi boss chương +1; ô "Bỏ 1 lá" trong màn thưởng chỉ hiện khi token > 0 và tiêu 1 token khi dùng. Bỏ hẳn "bỏ lá miễn phí mỗi trận".
- [ ] **Độ hiếm trôi theo may mắn**: `luck` của run = `luck_per_node` (1) × số nút đã qua (+ `luck_start` 0); trọng số R0..R2 = công thức tuyến tính trong `rewards.json` (`rarity_weights_at_luck: {"0": [70,25,5], "70": [31,35,34]}`, nội suy, kẹp). Treasure/miniboss áp sàn độ hiếm sau khi roll. Test xác định.
- [ ] Máu: **bỏ `heal_between_matches` và `heal_between_floors`** (về 0 trong `chapters.json`, khóa giữ để Story 023 dùng cho `rest`); HP chỉ hồi ở nút `rest` (Phần C) và từ lá/nội tại. Số máu tối đa nhân vật **×2 (100 → 200, 80 → 160, 90 → 180)** — story viết ×3, người dùng chốt ×2 ngày 2026-10-24 sau mô phỏng ("làm khó hơn": ở ×3 bot thắng 100 % kể cả không nhặt lá) — sát thương địch giữ nguyên, một đòn ≈ 8–11 % máu, trong dải OSFE 3–12 % (§8.4). `second_wind` hồi 20 thay vì 10. Các test đang assert 25/40 cập nhật.

**Phần C — Nút nghỉ (`rest`) tối thiểu**

- [ ] Màn `RestView`: hai lựa chọn, **Nghỉ** (hồi `rest_heal_ratio` 0,3 × máu tối đa) hoặc **Rèn** (nâng cấp 1 lá tự chọn +1, tối đa cấp 3). Chọn xong sang cột kế. Không minigame (để sau).

**Phần D — Kiểm chứng**

- [ ] Test: cùng `run_seed` sinh cùng bản đồ; mọi bản đồ có đúng 1 miniboss ở cột 3, 1 rest ở cột 4, 1 boss ở cột 6, cột 1–2 và 5 có 2–3 nút; tier kẹp ≤ 1 khi `cleared_bosses == 0`; thưởng đúng theo loại nút; token bỏ lá tiêu đúng và không âm; độ hiếm trôi đúng công thức tại luck 0 / 35 / 70; save v4 round-trip giữ bản đồ, cột, token, luck; v3 nạp → chương bắt đầu lại không crash.
- [ ] Mô phỏng `deck_sim` cập nhật cho bản đồ 7 cột (bot chọn nút: ưu tiên treasure > rest khi HP < 50 % > battle): báo tỉ lệ thắng chương và số đòn trúng/run với máu ×3; mục tiêu **15–30 đòn trúng mỗi run thắng** (OSFE). Không đạt thì chỉnh `combat.json`/`characters.json`, không chỉnh mã.
- [ ] Ảnh trong `production/qa/evidence/chapter-map/`: bản đồ chương lúc bắt đầu; sau khi qua 3 cột; màn thưởng miniboss (3 lá hiếm); màn thưởng boss có token; nút rest với hai lựa chọn; màn thưởng không có ô bỏ lá khi token = 0.
- [ ] Không hằng số gameplay trong mã; chuỗi mới là khóa `TEXT_*` với vi và en.

---

## Implementation Notes

- `ChaptersConfig` v2 đọc `columns`; giữ `RunConfig.from_floor` dưới dạng `from_node` (một nút = một trận hoặc một màn). `GameFlow` thay vòng "tầng → trận" bằng "cột → nút". `--floor=chX/fY` đổi thành `--node=chX/cC/nN` cho chụp ảnh; giữ `--run=*`.
- Sinh bản đồ trong lớp thuần `ChapterMapGen.generate(chapter, run_seed, cleared_bosses) -> Array[Column]` để test không cần cây node.
- `RewardRoller.roll` nhận `luck` và `min_rarity`; `rewards.json` thêm `starting_removals`, `luck_per_node`, `luck_start`, `rarity_weights_at_luck`, `rest_heal_ratio` (hoặc để trong `chapters.json → defaults`; chọn một chỗ, ghi vào schema).
- Màn `ChapterSelectView` (019) giữ; `ChapterMapView` là màn mới sau khi chọn chương / tiếp tục run.

---

## Out of Scope

- Nội dung chương 2–3, địch phá luật, lá mới, trait mới (023). Cửa hàng, tiền, pact (story sau; OSFE §6/§9.2 là tham chiếu). Minigame ở trại nghỉ. Hell pass. Hình ảnh bản đồ.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/chapter-map/`; bảng mô phỏng số đòn trúng/run.

**Status**: Screenshots retained (chapter-map/01-13) + simulation table (chapter-map/simulation-70seeds.md).

---

## Dependencies

- Depends on: Story 019 (RunSession, GameFlow, save), Story 020 (RewardRoller, token UI), Story 021 (không đụng)
- Unlocks: Story 023 (nội dung chương 2–3 dùng pool theo loại nút), cửa hàng/pact sau này

---

## Completion Notes
**Completed**: 2026-10-24
**Criteria**: 10/11 pass, 1 not met (closed by user decision with tech debt TD-006/TD-007). DEFERRED (needs real play): readability of the map on a phone, whether 7 columns feel too long, feel of the rest node, how much a real player dodges.
**Deviations**: BLOCKING (accepted, logged TD-006): Phase D target of 15–30 boss hits per won run not reached; measured 5.5–8.2 (kiem_si 8.2, phap_su 7.8, sat_thu 5.5) with hero HP x2, 6–10 at x3. Per-hit damage is 8–11 % of max HP (OSFE band 3–12 %); the shortfall is hit COUNT (bosses land 14–21 % of swings), driven mainly by the bot's assumed 85 % telegraph dodge, which was calibrated against HP 100 in Story 020. Slowing the boss (think/reaction x0.7) was measured and rejected (bot offence collapses, wins 5 %). ADVISORY: hero HP is **x2 (200/160/180)**, not the story's x3, and `second_wind` heals 20 not 30 — user decision "làm khó hơn" after the x3 run showed the bot winning 100 % even with always-skip; at x2 kiem_si wins 96 %, sat_thu 90 %, phap_su 44 % (build policy, 70 seeds). ADVISORY: two data tunings kept: treasure only as a filler in column 1, column 4 = rest + battle; the four tier-1/2 chapter-1 battles (wolf, dire_wolf, goblin_archer, goblin_warrior) moved from cautious to balanced (treasure per run 2.2 -> 0.83, matches per run 4.3 -> 5.2, hits +15 %). ADVISORY: danger nodes add `row_burner` via `defaults.danger_traits`; pre-burned cells not implemented. ADVISORY: chapter 2 uses `ch2_placeholder_*` copies until Story 023. ADVISORY: caller-less floor-model APIs left in place (TD-007). ADVISORY: fixed two defects found while verifying: phase views kept their last frame when inactive (title showed under the map; every phase view now redraws when inactive), and a Vietnamese CSV row containing a comma was split (row now quoted; `csv.reader` check = 3 columns on all 229 rows). ADVISORY: save v3 is not migrated, the chapter restarts with a one-line notice; cleared chapters are kept.
**Test Evidence**: Integration; tests waived at `qa.level: minimal`. Retained screenshots `production/qa/evidence/chapter-map/01-13*.png` (opened and checked, re-shot after the HP x2 change) and the simulation summary `simulation-70seeds.md` with raw outputs `simulation-70seeds-raw.txt` and `simulation-70seeds-hp2-raw.txt`. Scratch suites 0 fails: map_gen (33), reward_luck (23), run_session_v4 (51), run_flow2 (133), pause_flow (73), reward_run (53), deck_power, signature, keyword, i18n, character, chapters (69), deck, cut, status, arbiter, run/trait/arena flow (headless); cut_flow and focus_flow (windowed, `--no-autopause`). Parse-check 77/77.
**Code Review**: Skipped (solo mode).
**Not verified**: real feel, balance with a human player (dodge rate), touch on a device, the old-save banner on a real v3 file from disk (staged through a memory store).
**Carries forward**: Story 023 (chapters 2–3 content, rule-breaker enemies, rare/epic curve, Rạn/Hàn, pool 24), then gate 6 playtest; re-anchor the bot dodge from that playtest (TD-006); TD-001..007.
