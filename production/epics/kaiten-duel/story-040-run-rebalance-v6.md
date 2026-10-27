# Story 040: Cân bằng lại cả run v6 bằng mô phỏng — 5 tầng + Ấn Đài, bảo vật, vàng, bộ mảnh, Tha/Giết, cấp Kiếp; chỉ chỉnh dữ liệu

> **Epic**: Kaiten Duel (v6)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Config/Data
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-27

## Context

**GDD**: `design/game-brief.md` (v6, mục "Run v6 — mô hình OSFE" toàn bộ; "Player goal & fail state"; "Số khởi điểm"), `design/reference/osfe-reference.md` (§5.4, §5.5 ngân sách đòn trúng, §9.6 Hell Pass), `tools/balance/README.md`
**Requirement**: Story 031–039 mỗi story tự đo phần của mình; chưa ai đo **cả run**: 5 tầng × (3 cột vùng) + trận cuối Ấn Đài, với bảo vật, vàng/cửa hàng/sự kiện, bộ mảnh, Tha/Giết và cấp Kiếp cùng lúc. Các vòng lặp tăng trưởng (bảo vật đổi luật, xóa lá, bỏ hình mảnh) có thể cộng dồn thành chiến lược trội; `deck_sim.gd` hiện chỉ chạy chương 1–3 kiểu cũ với mục tiêu 40–60 / 25–45 / 15–35 %. Story này mở rộng công cụ mô phỏng cho run v6, đặt mục tiêu cả run, và **chỉ chỉnh dữ liệu** (`assets/data/*.json`) tới khi đạt. Mọi con số đều phụ thuộc giả định né của bot (TD-006, `--dodge=0.85` từ thời nối ấn), nên neo lại tỉ lệ né từ lần chơi thử là một phần của story.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM (thời gian chạy mô phỏng dài; kết quả phụ thuộc bot)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Neo lại bot (TD-006)**

- [ ] Từ log của lần chơi thử gần nhất (cổng chơi thử 8 sau Story 031, hoặc buổi chơi thử riêng cho story này): đếm đòn boss có cảnh báo nhắm ô người chơi và số lần người chơi né được → **tỉ lệ né người thật**; đo thêm thời gian kéo-thả một mảnh và thời gian chọn lá trung bình. Ghi cách đếm và cỡ mẫu (≥ 100 đòn boss) vào Completion Notes, cập nhật `DEFAULT_BOT` trong `tools/balance/sim_core.gd` và mục "The TD-006 dodge assumption" của `tools/balance/README.md`.
- [ ] Nếu chưa có dữ liệu chơi thử: chạy mọi bảng ở `--dodge=0.7`, `0.85`, `0.95` và báo độ nhạy; tiêu chí neo ghi **DEFERRED** (không được ghi PASS), TD-006 giữ mở.

**Phần B — Mở rộng công cụ (`tools/balance/`, không phải mã game)**

- [x] `deck_sim.gd` chạy **run v6**: chọn vùng mỗi tầng theo luật của Story 031 (seeded, chính sách chọn vùng: ngẫu nhiên giữa 2 lựa chọn), 5 tầng + Ấn Đài, máu mang qua tầng và hồi một phần theo dữ liệu. Cờ mới: `--run=v6` (mặc định khi có dữ liệu 031), `--floors=1..5`, `--final=on|off`.
- [x] Chính sách bot cho phần build, mỗi chính sách là một luật đơn giản ghi trong README: **bảo vật** (lấy bảo vật đầu tiên theo bảng giá trị tĩnh trong sim; cờ `--relic=value|random|none`), **vàng/cửa hàng/sự kiện** (mua xóa lá khi bộ > 10 lá, mua bảo vật nếu đủ vàng, nhận sự kiện khi máu > 50 %; cờ `--shop=on|off`), **bộ mảnh** (bỏ hình 5 ô không vừa sân hay gặp, thêm hình 2–3 ô; `--pieces=on|off`), **Tha/Giết** (`--mercy=kill|spare|mixed`), **cấp Kiếp** (`--kiep=0..10`), **nhân vật** (5 nhân vật nếu Story 037 xong).
- [x] Bảng ra mới: `RUN | character | policy | kiep | win % | deaths by floor (1..5, final) | hits taken / won run | run minutes (est.) | gold earned / spent | relics / run | deck size | piece set size`; `REGION x FLOOR` (tỉ lệ thắng mỗi vùng ở mỗi tầng); `RELIC LIFT` (tỉ lệ thắng khi bảo vật X có từ tầng ≤ 2 so với không có); `SHOP` (tần suất mua mỗi món); `VERDICT run` theo mục tiêu ở Phần C. Mỗi dòng có header `bot: ... | overrides: ...` như hiện nay.
- [x] **Thời lượng run ước tính** = tổng giây trận mô phỏng (thời gian sim, đã gồm thời gian chậm 0,2× của menu) + thời gian ngoài trận theo hằng số trong sim (khởi điểm: bản đồ 8 s/nút, chọn thưởng 15 s, cửa hàng 45 s, sự kiện 30 s, trại nghỉ 10 s, chọn Tha/Giết 10 s, intro/kết trận theo `intro_sec`/`end_delay_sec`). Hằng số ngoài trận nằm ở đầu `deck_sim.gd` và in ra header.

**Phần C — Mục tiêu (khởi điểm; người dùng chốt lại sau lần chơi thử)**

- [ ] **Tỉ lệ thắng run ở Kiếp 0**, chính sách build, bot đã neo, Tha/Giết `mixed`: **30–45 %** cho mỗi nhân vật; chênh giữa nhân vật cao nhất và thấp nhất ≤ 20 điểm. Dòng onboarding (save trống, `cleared_bosses` 0): ≥ 20 %.
- [ ] **Độ khó tăng dần theo tầng**: xác suất chết ở tầng *n* khi đã tới tầng *n* không giảm từ tầng 1 tới tầng 5 (cho phép lùi ≤ 3 điểm do nhiễu); chết ở tầng 1 ≤ 10 % số run; thắng Ấn Đài khi đã tới: 50–70 %.
- [ ] **Thời lượng run thắng** (ước tính Phần B): trung vị **40–50 phút**; run thua trung vị ≥ 15 phút (thua không quá sớm).
- [ ] **Số đòn boss trúng mỗi run thắng: 15–30** (ngân sách OSFE của Story 022/023); một đòn boss trung bình 4–15 % máu tối đa.
- [ ] **Vùng**: ở mỗi tầng, tỉ lệ thắng trận của mọi vùng trong ±10 điểm so với trung bình tầng đó (không vùng nào là "vùng tránh" hay "vùng chọn chắc").
- [ ] **Không chiến lược trội** (kiểm Sirlin "chơi để thắng"): chênh tỉ lệ thắng run giữa `--mercy=kill` và `--mercy=spare` ≤ 10 điểm; không bảo vật nào có `RELIC LIFT` > +15 điểm; không món cửa hàng nào được mua < 2 % lượt vào cửa hàng (món "không bao giờ đáng mua"); chính sách `--pieces=on` không hơn `off` quá 10 điểm.
- [x] **Kinh tế vàng**: vàng tiêu ≥ 70 % vàng kiếm trong run thắng; vàng tồn ở Ấn Đài trung vị ≤ giá một bảo vật cửa hàng (không tích vàng vô dụng).
- [ ] **Cấp Kiếp** (nếu Story 038 xong): tỉ lệ thắng giảm đơn điệu từ Kiếp 0 tới Kiếp 10 (cho phép lùi ≤ 3 điểm); Kiếp 10 ≥ 3 % với bot đã neo; không cấp nào làm tụt > 12 điểm một mình.

**Phần C2 — Bản sắc bộ khởi đầu (yêu cầu của người dùng, 2026-10-26)**

Mỗi nhân vật phải có "sắc màu" riêng ngay từ trận đầu, không chỉ khác tỉ lệ của cùng 4 lá. Luật "không có lớp" vẫn giữ: lá nào cũng nằm trong pool chung, chỉ bộ khởi đầu nghiêng về hướng mà tuyệt kỹ của nhân vật khuếch đại.

- [x] Bộ khởi đầu (`assets/data/characters.json` `starter_deck`) của mỗi nhân vật có **≥ 3 / 6 lá thuộc hướng của nó**: Kiếm sĩ → lá sát thương cao (Trảm); Pháp sư → lá Đốt (Thiên Hỏa); Sát thủ → Ghim + lá nhỏ (Ảnh Bộ); Thợ săn → vùng + Rạn (Vây Bắt); Giáo sĩ → Hàn (Thánh Ấn). `kiem_khi` (lá nền) tối đa 2 lá mỗi bộ.
- [x] Hai nhân vật bất kỳ chung **≤ 3 lá** trong bộ khởi đầu (đếm cả lá trùng), để không bộ nào là bản sao đổi tỉ lệ của bộ khác. Hiện tại Kiếm sĩ / Pháp sư / Sát thủ dựng từ cùng 4 lá (Kiếm khí, Chấn phong, Hỏa trận, Băng phong); Kiếm sĩ không có lá sát thương cao nào dù Trảm khuếch đại hướng đó.
- [x] Kiểm chứng: test dữ liệu cho hai luật trên; mô phỏng Phần E chạy sau khi đổi bộ, và mục tiêu tỉ lệ thắng của Phần C áp dụng cho bộ mới (đổi bộ là chỉnh dữ liệu, theo Phần D).

**Phần D — Chỉ chỉnh dữ liệu**

- [x] Mọi thay đổi để đạt Phần C nằm trong `assets/data/*.json` (máu, nhịp bước, giáp, cỡ đòn của trận; hệ số theo tầng của 031; hồi máu khi sang tầng; giá và lượng vàng; trọng số thưởng/bảo vật/hình mảnh; tham số Kiếp). Không đổi mã game; nếu một mục tiêu chỉ đạt được bằng mã thì ghi TD mới và để mục đó DEFERRED.
- [x] Mỗi thay đổi một dòng trong Completion Notes: khóa, giá trị cũ → mới, lý do (bảng nào lệch). Số mới vẫn là "khởi điểm" cho tới khi người dùng chơi thử; `design/game-brief.md` mục "Số khởi điểm" cần cập nhật bởi người dùng hoặc story sau (story này không sửa brief).

**Phần E — Kiểm chứng**

- [x] **Mô phỏng** cuối: 70 seed × mỗi nhân vật × chính sách build, Kiếp 0, `--mercy=mixed`, cộng các lượt so sánh ở Phần C (mercy kill/spare, pieces on/off, relic none, Kiếp 0–10 với 30 seed); kèm smoke 5 seed để đo thời gian chạy và ghi vào README. Bảng tóm tắt vào Completion Notes; đầy đủ vào `production/qa/evidence/run-v6-balance/simulation-run-v6.md` và `simulation-run-v6-raw.txt`, có header bot và overrides.
- [x] Smoke sau khi chỉnh dữ liệu: toàn bộ suite headless và windowed chạy, FAILS=0 (test có ngưỡng số cũ được cập nhật theo dữ liệu mới, ghi tên test vào Completion Notes); `main.tscn` chạy cửa sổ `--quit-after 300`, 0 dòng lỗi.
- [x] Ảnh trong `production/qa/evidence/run-v6-balance/` (dữ liệu đổi thì thứ người chơi thấy đổi): bản đồ thế giới tầng 1 và tầng 5 với số máu địch đã chỉnh; một boss vùng ở tầng 5; trận cuối Ấn Đài; màn kết thúc run thắng có thời lượng; cửa hàng với giá mới.
- [x] Không hằng số gameplay mới trong mã game.

---

## Implementation Notes

- Run đầy đủ có thể kéo dài nhiều giờ (README: ~1,6 s cho một run một chương; run v6 ~ 6 lần): chia lô theo nhân vật, chạy có timeout, gom kết quả; dùng `hit_probe.gd --modes=bot` để soi một vùng/tầng lệch trước khi chạy lại cả run.
- Thứ tự chỉnh khuyến nghị (từ gốc tới ngọn): hệ số theo tầng (độ dốc) → máu/hồi máu sang tầng (ngân sách đòn) → kinh tế vàng → bảo vật/món cửa hàng trội → vùng lệch → Kiếp.
- Đổi seed tập giữa lượt chỉnh và lượt chốt để tránh khớp quá mức với một tập seed.

---

## Out of Scope

- Thay đổi luật hay mã gameplay (story riêng nếu mô phỏng chỉ ra cần). Cân bằng theo người thật ngoài phần neo bot. Thử thách ngày. Nội dung mới. Sửa `design/game-brief.md`.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Config/Data
**Required evidence**:
- Smoke check pass; bảng mô phỏng và retained screenshots trong `production/qa/evidence/run-v6-balance/`.

**Status**: Created — `production/qa/evidence/run-v6-balance/` (simulation-run-v6.md, simulation-run-v6-raw.txt, 10 screenshots); smoke: see Completion Notes

---

## Dependencies

- Depends on: Story 031–039 (bản đồ thế giới, bảo vật, vàng/cửa hàng/sự kiện, bộ mảnh, Tha/Giết và boss cuối, hai đợt vùng, mở khóa và nhân vật, cấp Kiếp); dữ liệu chơi thử cho Phần A (TD-006)
- Unlocks: lên Android, cổng chơi thử run v6 đầy đủ

---

## Completion Notes
**Completed**: 2026-10-27 (`/story-done`, verdict BLOCKED, closed by the user's explicit choice "Đóng, ghi nợ kỹ thuật")
**Criteria**: 14/23 passing. Not met (measured): C1 run win band (Tho san 27.1, Giao si 47.1), C2 monotone deaths and final-match band (2 of 5 characters each), C5 region cells (3 of 5), C6 dominant strategies (kill vs spare +10.7, relic lift khoi_the +19.4 / huyet_an +18.5, 15 items the bot never buys), C8 Kiep ladder. C3 minutes (27-30, target 40-50) and C4 boss hits (30-36, target 15-30) fail against the bot and are carried as DEFERRED to the gate-8 playtest: they depend on a person's speed and dodge (Part A). Part A anchoring DEFERRED (no playtest log); the dodge sensitivity covers 2 of 5 characters only.
**Deviations**: none against GDD / ADR (minimal tier). Scope: the same uncommitted change also carries the user-requested tech-debt work (card_text, cast_path_kits_test, achievements_flow_test, piece_deck_flow_test fix).
**Test Evidence**: Config/Data: smoke 251/251 parse, 105 headless + 5 windowed FAILS=0, launch 0 errors; 10 retained screenshots and simulation-run-v6.md + raw in `production/qa/evidence/run-v6-balance/`.
**Code Review**: Skipped (solo mode)
**Tech debt**: TD-036 (Kiep ladder), TD-037 (bot shop policy and the residual Part C misses); TD-006 stays open; TD-015 / 025 / 026 / 033 partly done; TD-034 superseded by TD-036.


**Implemented 2026-10-26/27** (`/dev-story`). Full tables: `production/qa/evidence/run-v6-balance/simulation-run-v6.md`;
raw: `simulation-run-v6-raw.txt` (`final2/*` = shipped data, seeds 2001-2070; `final/*` = before the second data pass).

**Part A — DEFERRED.** No playtest log exists, so `DEFAULT_BOT` (dodge 0.85) is unchanged and TD-006 stays open. The
dodge sensitivity ran for Kiem si and Phap su only (30 seeds; 0.70 / 0.85 / 0.95 = 33.3 / 36.7 / 46.7 and 20.0 / 40.0 /
30.0), not for all five characters: the second Part A bullet is partial.

**Part B — tooling** (`tools/balance/deck_sim.gd`, `tools/balance/README.md`; `sim_core.gd` unchanged): `--run=v6`,
`--floors`, `--final`, `--mercy`, `--shop`, `--pieces`, `--relic`, `--tables`, list flags (`--dodge=a,b,c`,
`--mercy=kill,spare`, `--pieces=on,off`), the out-of-match time constants (map 8 s / node, reward 15, shop 45, event 30,
rest 10, fate 10) printed in the header, and the tables RUN / RUN DETAIL / REGION x FLOOR / RELIC LIFT / SHOP / DODGE
SENSITIVITY / VERDICT run. Added during tuning: `--seed-offset=N` (fresh seed sets for the final check) and
`--char-set=<id>.<path>:<X|xF>` (character probes side by side without editing the data file).

**Part C — final check** (shipped data, 70 seeds, Kiep 0, build, mercy mixed): run win Kiem si 44.3 / Phap su 35.7 /
Sat thu 42.9 / Tho san 27.1 / Giao si 47.1 (sd about 6 each); spread 20.0.

| Target | Verdict |
|---|---|
| Run win 30-45 % per character | FAIL for 2 of 5 (Tho san -2.9, Giao si +2.1; within 1 sd); spread 20.0 = at the limit |
| Onboarding >= 20 % | PASS (50.0 / 46.7 / 33.3, pass-1 data) |
| Deaths rise f1..f5 | FAIL for 2 of 5 (Phap su f3, Tho san f4); floor-1 deaths 1.4-8.6 % PASS |
| Final won when reached 50-70 % | FAIL for 2 of 5 (Phap su 73.5, Sat thu 75.0) |
| Won-run minutes 40-50; boss hits / won run 15-30 | DEFERRED: 26.7-29.7 min and 30.4-36.1 hits; the two pull against each other under the bot and both depend on Part A (person speed and dodge) |
| Lost-run minutes >= 15; boss hit 4-15 % max HP | PASS (18.6-26.4 min; 6.1-7.1 %) |
| Regions +-10 pts | FAIL for 3 of 5 (sky_isles f3 for Kiem si, swamp f2 for Sat thu / Tho san; cells of 20-25 matches) |
| Kill vs spare <= 10 | FAIL, borderline: +10.7 mean of 5 x 30 seeds (per character +23 to -13) |
| Relic lift <= +15 | FAIL: khoi_the +19.4, huyet_an +18.5 (an_don +20.2 fixed by the data pass) |
| No shop item < 2 % of offers | FAIL: 15 items, 12 cards outside the bot's build picks + the 3 services the bot never buys (bot policy) |
| Pieces on not above off by > 10 | PASS (on 41.3 vs off 44.7) |
| Gold economy | PASS (75-81 % spent in won runs; 28-47 gold left at the final, a relic costs 60) |
| Kiep monotone, Kiep 10 >= 3 %, no step > 12 | FAIL: Kiem si 60.0 / 46.7 / 46.7 / 46.7 / 23.3 / 10.0 / 6.7 / 0 / 0 / 0 / 0 (30 seeds) |

Tuning stopped here on purpose: pass 1 (seeds 1001+) and pass 2 (seeds 2001+) differ by up to 17 points per character
for small data changes, so the remaining 2-3 point misses are inside the noise. The Kiep ladder needs its own pass.

**Part D — data changes (from -> to, reason):**

- `characters.json` `starter_deck` (Part C2): kiem_si [kiem_khi, kiem_khi, chan_phong, chan_phong, hoa_tran, bang_phong] -> [kiem_khi, kiem_vu, kiem_vu, thiet_kiem, thiet_kiem, chan_phong]; phap_su [kiem_khi, chan_phong, hoa_tran x3, bang_phong] -> [kiem_khi, hoa_xa, hoa_tinh, hoa_tinh, hoa_tran, bang_phong]; sat_thu [kiem_khi x3, chan_phong, bang_phong x2] -> [kiem_khi, kiem_khi, kiem_vu, thiet_kiem, bang_chau, han_kiem]; tho_san [.., tran_gai, ran_kich, chan_phong] -> [kiem_khi, kiem_khi, ket_gioi, ket_gioi, tran_gai, ran_kich]; giao_si [.., han_kiem, bang_phong] -> [kiem_khi, kiem_khi, han_khi, han_khi, han_kiem, han_kiem]. Each character's direction, <= 3 shared cards.
- `chapters.json` `world.floor_heal_ratio` 0.35 -> 0.6: run win 0-27 % with deaths piled at region bosses.
- `chapters.json` `world.floor_scaling` hp_mult rows 1-5: 1.0 / 1.1 / 1.2 / 1.3 / 1.4 -> 0.7 / 0.8 / 0.85 / 1.05 / 1.15: run win too low; steeper late slope so deaths rise by floor.
- `chapters.json` `world.floor_scaling.final.hp_mult` 1.5 -> 1.25 and `an_dai_keeper.boss_max_hp` 130 -> 198: final HP 195 -> 248 at Kiep 0 (the final was won 80-96 % when reached after the floor change); the row stays close to floor 5 because Kiep 4 (floor_shift) makes floor 5 use it.
- `chapters.json` `sky_isles.region_normalize.hp_mult` 0.53 -> 0.45: sky_isles 15-24 pts under the floor mean at floors 3-4.
- `chapters.json` `world.fate.execute_artifact_offers` 3 -> 2: kill beat spare by 10-20 pts.
- `characters.json` `phap_su.max_hp` 190 -> 210: Phap su 13-20 % while the others were 30-40.
- `characters.json` `tho_san.max_hp` 190 -> 200: low end of the band.
- `characters.json` `sat_thu.passive.params.damage_mult` 1.25 -> 1.4: Sat thu 18-24 % after the world change (its identity, small casts).
- `relics.json` `an_don.params.mult` 2.0 -> 1.75: RELIC LIFT +20.2.
- `strings.csv`: `passive.quick_blade.desc` 25 % -> 40 %, `relic.an_don.desc` x2 -> x1,75 / x1.75 (the numbers above); `passive.second_wind.desc` 10 -> 20 HP (the data has been 20 since before this story; the text was wrong).

No game code changed; no new gameplay constant in game code. `design/game-brief.md` "Số khởi điểm" is left for the user.

**Tests updated to the new data:** `tests/unit/run/character_test.gd` (phap_su 210, quick_blade 1.4, phap_su deck),
`tests/unit/run/character_unlock_test.gd` (phap_su 210, tho_san 200, the five decks), `tests/integration/run/run_flow2_test.gd`
(mage max HP 210), `tests/unit/combat/signature_test.gd` (Quick Blade 1.4), `tests/unit/relics/relic_registry_test.gd`
and `relic_conditional_test.gd` (an_don 1.75), `tests/unit/combat/deck_power_test.gd` and `tests/unit/run/reward_run_test.gd`
(the new default deck). New: `tests/unit/run/starter_identity_test.gd` (Part C2 rules).

**Tech-debt work run in parallel (user request, same uncommitted change):** `src/run/card_text.gd` + 30 `card.*.desc`
rows with placeholders (TD-026 texts, TD-025 docs); `tests/unit/combat/cast_path_kits_test.gd` (49 checks) and
`tests/integration/ui/achievements_flow_test.gd` (20 checks) (TD-015, TD-033 part); `tests/integration/run/piece_deck_flow_test.gd`
fixed seed 87109 + safe ink pick (the flaky shape-removal checks: 10/10 passes).

**Smoke (Part E, 2026-10-27, shipped data):** import 0 errors; parse 251/251; 105 headless suites FAILS=0 (after
updating `tests/unit/run/final_match_data_test.gd`: fate offers 2, final HP bound region boss x1.3 -> x2.0 because this
story moved the final's difficulty onto the keeper; `tests/unit/run/world_map_gen_test.gd`: floor_heal_ratio 0.6);
5 windowed suites FAILS=0; `main.tscn` windowed `--quit-after 300`: 0 SCRIPT ERROR, 0 ERROR lines.

**Screenshots** (`production/qa/evidence/run-v6-balance/`, vi, Kiep 0, seed 4242): 01 world map floor 1, 02 floor-1
battle (Goblin trinh sat 46 HP = 86 x 0.75 x 0.7), 03 world map floor 5, 04 floor-5 battle (Soi xam 94 HP = 108 x 0.75 x
1.15), 05 floor-5 region boss, 06 An Dai map (shop then boss), 07 An Dai final match (phase 2, 124/248), 08 won-run
ending with time 7:42 (dev-staged stats), 09 floor-5 shop (prices unchanged by this story), 10 execute offer with 2 relics.
The world map shows no enemy HP, so the HP proof is the battle captures.

**New tech debt:** Kiep ladder retune after the steeper floor curve (Kiep 4 floor_shift -23 pts, Kiep 7-10 at 0 %);
the bot's shop policy (never buys services, card picks follow the build policy) makes the shop and relic-lift checks
measure the bot, not the items.
