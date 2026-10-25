# Story 031: Bản đồ thế giới — 5 tầng × chọn 1 trong 2 vùng, vùng 3 cột, trận cuối Ấn Đài, độ khó theo tầng

> **Epic**: Kaiten Duel (v6)
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md` (v6, mục "Run v6 — mô hình OSFE" → "Bản đồ thế giới"), `design/reference/osfe-reference.md` (§6, §9.3: `numZones`, `CalculateStageNum`, `GenerateRandomWorldList`)
**Requirement**: Hiện một run = một chương 7 cột (Story 022), thắng boss chương là thắng run, chương sau mở khi chương trước đã thắng — cảm giác "chọn màn" chứ không phải roguelike. Người dùng chốt (2026-10-25) đi theo OSFE: **một run = chọn nhân vật → 5 tầng → trận cuối Ấn Đài**; mỗi tầng chọn 1 trong 2 vùng; mỗi vùng ngắn 3 cột; độ khó theo **tầng** chứ không theo vùng; run 40–50 phút. Ba chương hiện có (`ch1` Rừng Sương, `ch2` Hầm Ngục, `ch3` Tháp Sương) trở thành ba **vùng**. Màn chọn chương bỏ. Story này chỉ đổi **khung run**; bảo vật (032), vàng/cửa hàng/sự kiện (033), bộ mảnh (034), Tha/Giết và boss Ấn Đài thật (035) là story sau.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH (đụng GameFlow, RunSession, save run v5, ProgressState v5, bỏ một phase, mở rộng deck_sim)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Dữ liệu thế giới (`chapters.json` → khối `world`, chương = vùng)**

- [ ] `chapters.json` thêm khối `world` (đọc qua `ChaptersConfig`, có trong `assets/data/schema.md`): `floors` (5), `choices_per_floor` (2), `region_pool` (danh sách id vùng; khởi điểm `["ch1","ch2","ch3"]`), `region_columns` (khung cột của một vùng, cùng dạng `columns` của Story 022), `floor_scaling` (một dòng mỗi tầng 1–5 và một dòng `final`), `floor_heal_ratio`, `final_match` (`{"region": "ch3", "match_id": "mist_lord"}` tạm tới Story 035). Mảng `chapters` giữ nguyên tên khóa (đổi tên khóa là churn), nhưng mọi mã mới gọi chúng là **vùng** (`region_id`). Không dùng chữ `zone` cho vùng: `zone` đã là kết giới/trận gai (Story 027: `ZoneRules`, khối `zones` trong `combat.json`).
- [ ] Khung vùng mặc định `region_columns` (khởi điểm), sinh bằng `ChapterMapGen` hiện có:
  - cột 0: 1 nút `battle`;
  - cột 1: 2–3 nút từ {`battle`, `danger`, `treasure`, `rest`, `miniboss`}, có đúng 1 `rest` hoặc `treasure` (50/50 seeded) và `miniboss` chỉ từ tầng 2 trở đi (`min_floor` trên loại nút); `event` và `shop` thêm ở Story 033;
  - cột 2: 1 nút `boss` (boss vùng, rút từ pool `boss` của vùng).
  Nếu mô phỏng (Phần F) cho run ngắn hơn 40 phút, kéo dài bằng **dữ liệu** (thêm một cột nhánh vào `region_columns`), không sửa mã.
- [ ] **Độ khó theo tầng**: `floor_scaling[f]` = `{hp_mult, step_mult, defense_add, size_add}` — bốn trục leo thang của Story 023: máu boss (`boss_max_hp` ×), nhịp bước (`boss_step_cooldown_mult` ×, < 1 = nhanh hơn), giáp phẳng (`boss_defense` +), cỡ đòn (khóa cỡ mảnh/đòn của boss hiện có ở Story 023/025, xem `schema.md`; + số ô). Áp ở **một** điểm: `RunConfig.from_node` nhận `floor` và nhân/cộng sau khi đọc trận. Khởi điểm:

  | Tầng | hp_mult | step_mult | defense_add | size_add |
  |---|---|---|---|---|
  | 1 | 1,00 | 1,00 | 0 | 0 |
  | 2 | 1,15 | 0,95 | 0 | 0 |
  | 3 | 1,30 | 0,90 | 1 | 0 |
  | 4 | 1,50 | 0,85 | 1 | 1 |
  | 5 | 1,70 | 0,80 | 2 | 1 |
  | final | 1,90 | 0,80 | 2 | 1 |

- [ ] **Chuẩn hóa vùng**: số trận của `ch2`/`ch3` đang mang sẵn độ khó chương 2–3. Mỗi vùng có `region_normalize` (`{hp_mult, step_mult, defense_add}`, khởi điểm ch1 = 1/1/0, ch2 = 0,85/1,05/0, ch3 = 0,75/1,10/−1, kẹp giáp ≥ 0) áp **trước** `floor_scaling`, để cùng một tầng thì ba vùng khó ngang nhau (đo ở Phần F). Bậc pool (`tier`) theo tầng: `floor_tiers` (khởi điểm tầng 1 `[0,1,·]`, tầng 2 `[0,1,·]`, tầng 3–5 `[1,2,·]`; cột boss luôn pool `boss`); kẹp `onboarding_tier_cap` khi save chưa thắng boss nào giữ như Story 022.

**Phần B — Sinh thế giới (lớp thuần `WorldMapGen`)**

- [ ] `WorldMapGen.offer_for_floor(region_pool, run_seed, floor, chosen_path) -> Array[String]` (2 id vùng khác nhau), thuần, không cần cây node. Luật theo thứ tự: (1) ưu tiên vùng **chưa đi** trong run; (2) khi không đủ, ưu tiên vùng **đi ít lần nhất**; (3) tránh vùng vừa đi ở tầng trước nếu còn lựa chọn khác; (4) bốc ngẫu nhiên seeded `hash([run_seed, floor, chosen_path])`. Với pool 3 vùng và 5 tầng: vùng được phép lặp ở tầng khác, nhưng hai lựa chọn của một tầng luôn khác nhau. Pool chỉ 1 vùng → tầng đưa ra 1 lựa chọn (không crash).
- [ ] Bản đồ vùng sinh khi chọn vùng: `ChapterMapGen.generate(region_spec, hash([run_seed, region_id, floor]), cleared_bosses)` — cùng vùng gặp lại ở tầng khác ra bản đồ khác. Cùng seed + cùng lựa chọn → cùng thế giới, cùng bản đồ, cùng trận.

**Phần C — Run và lưu (`RunSession` save v5, `ProgressState` v5)**

- [ ] `RunSession` thêm `floor` (0..4; 5 = trận cuối), `region_id` (thay `chapter_index`), `region_offer` (2 id vùng của tầng đang chọn; rỗng khi đã chọn), `region_path` (id vùng đã chọn theo tầng); `map` là bản đồ của vùng hiện tại. Hạ boss vùng **không** thắng run: `complete_node` với `boss` → tầng +1, hồi `floor_heal_ratio` × máu tối đa (khởi điểm **0,25**, kẹp ≤ max), sinh `region_offer` tầng kế; boss vẫn cho thưởng boss (3 lá + 1 token bỏ lá) như Story 022. Qua tầng 5 → nút trận cuối; thắng trận cuối = thắng run. Luck tích lũy qua cả run (`luck_per_node` giữ 1).
- [ ] Save v5 lưu và nạp lại đủ: `floor`, `region_id`, `region_offer`, `region_path`, bản đồ vùng, cột, nút, máu, bộ bài, token, luck, seed, thời gian, offer đang chờ. Thoát ở **bất kỳ** điểm nào (màn chọn vùng, bản đồ vùng, giữa trận, màn thưởng, trại nghỉ) rồi *Tiếp tục* → về đúng màn đó. Save run v4 (chương) nạp được: `needs_restart` + thông báo một dòng (mẫu `RESTART_OLD_SAVE` đã có), bắt đầu run v6 mới cho nhân vật đã lưu, không crash.
- [ ] `ProgressState` v5: **bỏ mở chương** (`is_chapter_unlocked` không còn người gọi; xóa cùng `unlocked_everything`, `--progress=all` đổi nghĩa thành "đã thắng boss" để tắt onboarding). `cleared_chapters` của file v4 chuyển thành `regions_boss_beaten` (id vùng từng hạ boss — Story 037 dùng làm cột mốc); `cleared_bosses` giữ. Thêm `best_floor` (tầng cao nhất từng tới, 1..6). File v4 nạp không mất `locale`, `seen_cards`, `cleared_bosses`.

**Phần D — Luồng và màn hình (chạm bằng ngón cái)**

- [ ] `GameFlow`: `Phase.CHAPTER_SELECT` thay bằng `Phase.WORLD_MAP`. Luồng: title → chọn nhân vật → **màn chọn vùng tầng 1** → bản đồ vùng → … → boss vùng → thưởng → (tầng kế) màn chọn vùng … → trận cuối → kết quả. `ChapterSelectView` gỡ khỏi `main.tscn` (file xóa hoặc để lại không người gọi — ghi vào Completion Notes); `go_back` ở WORLD_MAP = về title giữ save.
- [ ] **`WorldMapView`** (màn chọn vùng, mới, vẽ bằng code như `ChapterMapView`): dải tiến độ trên cùng 5 tầng + Ấn Đài (tầng đã qua tô, tầng hiện tại sáng, mỗi tầng ghi vùng đã chọn); giữa màn **hai thẻ vùng lớn** đặt trái/phải để mỗi ngón cái một thẻ, mỗi thẻ ≥ 40 % chiều rộng và ≥ 50 % chiều cao màn ngang, ghi tên vùng, một dòng mô tả sân/địch đặc trưng, tên boss vùng, và độ khó tầng (ví dụ "Tầng 3 — máu địch ×1,3"). Chạm một thẻ → thẻ nổi lên + nút **Vào vùng** lớn ở mép dưới cùng phía; chạm lại thẻ hoặc nút để xác nhận (một chạm nhầm không khóa lựa chọn). Không cần kéo, không cần hai tay.
- [ ] `ChapterMapView` vẽ 3 cột của vùng + tiêu đề "Tầng N/5 · <vùng>"; mọi nút bấm được có vùng chạm ≥ 96 px ở độ phân giải logic hiện tại. `RunHudView` dòng vị trí đổi thành "Tầng N/5 · <vùng> · cột C/3" (khóa mới `ui.run_hud.run_floor_position`); banner sang tầng "Tầng N+1 — hồi X máu" sau boss vùng.
- [ ] Màn kết quả thắng/thua ghi tầng tới được và đường vùng (`region_path`), thay "chương".

**Phần E — Kiểm chứng tự động**

- [ ] Test mới `tests/unit/run/world_map_gen_test.gd`: cùng seed + cùng lựa chọn → cùng offer mọi tầng; hai lựa chọn một tầng luôn khác nhau; pool 6 vùng → không vùng nào lặp trong 5 tầng; pool 3 vùng → mỗi vùng xuất hiện ≥ 1 lần trong offer của 2 tầng đầu và không vùng nào bị đi 3 lần khi còn vùng đi ít hơn; pool 1 vùng → 1 lựa chọn.
- [ ] Test mới `tests/unit/run/floor_scaling_test.gd`: `RunConfig.from_node` cùng trận ở tầng 1 và tầng 4 cho máu, nhịp bước, giáp, cỡ đòn đúng bảng; chuẩn hóa vùng áp trước hệ số tầng; giáp không âm; trận cuối dùng dòng `final`.
- [ ] Test mới `tests/unit/run/run_session_v5_test.gd`: round-trip v5 ở 6 điểm thoát (Phần C); boss vùng tăng tầng, hồi đúng 25 % kẹp max, không thắng run; thắng trận cuối thắng run; save v4 → `needs_restart`. `progress_state` v4 → v5 giữ locale/seen/bosses, chuyển `cleared_chapters` → `regions_boss_beaten`.
- [ ] Chạy lại và sửa cho xanh: `map_gen_test`, `chapters_test`, `chapters23_test`, `reward_run_test`, `reward_luck_test`, `run_session_v4_test` (thành test đường save cũ), `run_state_test`, `character_test`, `arena_test`, cùng các suite luồng headless (run_flow, pause_flow, run/trait/arena flow) và cửa sổ (cut_flow, focus_flow với `--no-autopause`). Parse-check toàn bộ.

**Phần F — Mô phỏng (`tools/balance/deck_sim.gd`)**

- [ ] deck_sim thêm chế độ `--world` (5 tầng + trận cuối, khung và hệ số đọc từ `chapters.json`), bot chọn vùng ngẫu nhiên seeded (`--region-pick=random|first`) và chọn nút như Story 022 (thêm: chọn `rest` khi HP < 50 %). Cập nhật `tools/balance/README.md`.
- [ ] Báo (70 seed × 3 nhân vật, policy `build`, dòng header bot/override dán kèm): tỉ lệ thắng run; tỉ lệ còn sống sau mỗi tầng; phân bố cái chết theo tầng; tỉ lệ thắng **theo vùng ở cùng tầng**; số đòn trúng mỗi run thắng; luck và trọng số độ hiếm cuối run; **thời gian run ước tính** = (Σ giây trận + `node_overhead_sec` × số nút) / 60, `node_overhead_sec` khởi điểm 25 s (chọn nút, thưởng, đọc màn — giả định, ghi rõ).
- [ ] Mục tiêu (khởi điểm, chỉnh **dữ liệu** chứ không chỉnh mã): run thắng 40–50 phút ước tính; thắng run (build) 20–40 % với Kiếm sĩ và Sát thủ, Pháp sư không dưới 10 %; ba vùng ở cùng tầng chênh tỉ lệ qua vùng ≤ 15 điểm; không tầng nào chiếm > 40 % số lần chết; đường sống sót giảm dần theo tầng (răng cưa: hồi máu sang tầng thấy được). Không đạt mục tiêu nào thì ghi số đo và đề xuất ở Completion Notes.

**Phần G — Ảnh và quy ước**

- [ ] Ảnh trong `production/qa/evidence/world-map/`: màn chọn vùng tầng 1 (vi); màn chọn vùng tầng 3 có dải tiến độ đã tô 2 tầng (en); một thẻ đang chọn + nút Vào vùng; bản đồ vùng 3 cột với tiêu đề tầng; banner sang tầng có số hồi máu; HUD trong trận với dòng "Tầng N/5"; thông báo một dòng khi nạp save v4; màn kết quả thua ghi tầng và đường vùng.
- [ ] Không hằng số gameplay trong mã (fallback `DEFAULT_*` chỉ khi file hỏng, như Story 022); mọi số mới trong `schema.md`; chuỗi mới là khóa `ui.*` với vi và en trong `assets/i18n/strings.csv` (kiểm `csv.reader` 3 cột).

---

## Implementation Notes

- File chạm: `src/run/chapters_config.gd` (`world_spec()`, `region_spec(region_id, floor)`, `floor_scaling(floor)`), `chapter_map_gen.gd` (giữ API, thêm `min_floor` trên loại nút và tier theo `floor_tiers`), mới `src/run/world_map_gen.gd` (`class_name WorldMapGen`), `run_session.gd` (v5), `run_config.gd` (`from_node(..., floor)`), `game_flow.gd`, `progress_state.gd` (v5), `progress_store.gd` (không đổi API), mới `src/run/world_map_view.gd`, `chapter_map_view.gd`, `run_hud_view.gd`, `main.tscn`.
- Arena seed: `ChaptersConfig.arena_seed_for(run_seed, floor * 100 + column)` thay `chapter_index * 100 + column`.
- Cờ dev (`game_flow.gd` header): `--chapter=` → `--region=<id>` + `--at-floor=N` (không dùng `--floor=` vì đó là alias cũ); `--node=fF/<region>/cC/nN`; `--run=world` (chọn vùng tầng 1), `--run=world3` (tầng 3, đường vùng seeded), `--run=floorclear` (banner sang tầng), `--run=final` (đứng trước trận cuối); `--progress=demo` thành save v5 ở tầng 2.
- Không đổi luật trận (core loop v5) và không đổi `rewards.json` ngoài việc thưởng boss vùng không còn kết thúc run.

---

## Out of Scope

- Bảo vật (032), vàng/cửa hàng/sự kiện (033), bộ mảnh (034), Tha/Giết, boss Ấn Đài thật và ba kết thúc (035), vùng mới (036, 039), mở khóa theo cột mốc và thành tựu (037), cấp Kiếp (038), cân bằng cả run lần cuối (040). Hình ảnh bản đồ thế giới (placeholder vẽ bằng code). Chế độ chương riêng (đã bỏ).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/world-map/` (danh sách Phần G); bảng mô phỏng run 5 tầng `simulation-world.md` + raw.

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 026 (gỡ nối ấn, deck_sim v5), Story 027 (vùng, trait vùng trong chương 2–3) — cả hai Complete; Story 022 (ChapterMapGen, RunSession v4, thưởng theo nút), Story 023 (bốn trục leo thang)
- Unlocks: Story 032 (bảo vật), 033, 034, 035; **cổng chơi thử 8 sau khi 031 + 032 xong** (run 5 tầng đầu tiên trên điện thoại: độ dài run thật, cảm giác chọn vùng, đường răng cưa máu, đọc thẻ vùng bằng ngón cái; neo lại né của bot TD-006)
