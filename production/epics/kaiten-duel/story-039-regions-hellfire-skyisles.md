# Story 039: Vùng Thành Hỏa Ngục và Không Đảo — mạch dung nham, sân tách đảo, ô rơi; pool vùng lên 7

> **Epic**: Kaiten Duel (v6)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-26

## Context

**GDD**: `design/game-brief.md` (v6, mục "Run v6 — mô hình OSFE" › "Bản đồ thế giới", "Vùng"), `design/reference/osfe-reference.md` (§5.4: world Fire ghép biome, leo thang bằng buff gắn thêm)
**Requirement**: Brief cần 6–8 vùng để mỗi tầng có lựa chọn thật. Sau Story 036 pool có 5 vùng (Rừng Sương, Hầm Ngục, Tháp Sương, Đầm Lầy Độc, Sa Mạc Cát Ấn). Story này thêm đợt 3: **Thành Hỏa Ngục** (mạch dung nham phun theo nhịp; địch phá luật bắt bỏ lối Đốt) và **Không Đảo** (sân tách thành đảo nối bằng cầu, ô đứng lâu thì rơi), đưa pool lên **7 vùng**. Cùng mẫu nội dung với 036: 5–6 địch thường, 1 boss vùng, 2 kẻ phá luật, trait mới khi cần, sân và trọng số mảnh riêng, tên/mô tả vi+en, độ khó theo tầng của Story 031.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM (ô rơi cần luật chừa đường trên sân tách đảo; 6 trait mới)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Hai lớp ô mới (thêm vào khối `hazards` của Story 036, cả hai bên)**

- [ ] **Mạch dung nham** (`lava_vent`): sân có danh sách mạch (một hàng hoặc một cột mỗi mạch, mỗi bên). Cứ `vent_interval_sec` (khởi điểm 7 s) một mạch seeded **phun**: cảnh báo `vent_warn_sec` (khởi điểm 1,0 s), rồi các ô của mạch thành ô cháy `vent_sec` (khởi điểm 2 s) — dùng lại ô cháy của Hỏa trận / `row_burner` (đứng trong mất máu theo tick, boss né qua `burn_avoid`). Mảnh trên ô phun bị đốt (mất). Không chặn bước, nên không cần luật chừa đường.
- [ ] **Ô rơi** (`crumble`): ở sân có `crumble: true`, một ô bị đứng liên tục `crumble_after_sec` (khởi điểm 2,0 s) thì nứt (viền cảnh báo `crumble_warn_sec` 0,6 s) rồi **rơi** trong `fall_sec` (khởi điểm 4 s): không bước vào được (qua `UnitMover.add_blocker`), mảnh trên đó mất; bên đang đứng trên ô khi nó rơi bị **đẩy** sang ô kề bước được gần nhất và nhận `fall_damage` (khởi điểm 8). Luật chừa đường (`ZoneRules.fit_cells`) áp cho ô rơi: ô cuối cùng nối một đảo với lối thoát không rơi.
- [ ] Số trong `assets/data/combat.json` `hazards` (`vent_interval_sec`, `vent_warn_sec`, `vent_sec`, `crumble_after_sec`, `crumble_warn_sec`, `fall_sec`, `fall_damage`), trận ghi đè được, có trong `assets/data/schema.md`. API model: `is_venting(side, cell)`, `is_fallen(side, cell)`, `crumble_progress(side, cell)`.
- [ ] Não boss: ô rơi là ô chặn; trọng số mới `crumble_avoid` (chi phí đứng lâu trên một ô ở sân `crumble`) trong mọi `sets` của `boss_brain.json`; mạch sắp phun được tính như ô cháy sắp có. Ghi vào `last_debug()`.

**Phần B — Thành Hỏa Ngục (`hellfire`)**

- [ ] Vùng `hellfire` trong định dạng vùng của Story 031, `name_key` / `intro_key` / `end_key` vi+en, pool `battle`/`danger` theo tier và `boss`.
- [ ] **6 địch thường** (bậc tầng 1, khởi điểm): `imp` (máu 92, cautious), `ember_hound` (máu 110, balanced, `movement.move_commitment` 0,9), `ash_golem` (máu 132, balanced, `boss_defense` 3), `flame_cultist` (máu 128, balanced, trait `row_burner`), `magma_slug` (máu 140, balanced, `swing_speed_mult` 0,95), `hell_knight` (máu 156, balanced, `boss_defense` 2, `boss_min_runes` 3).
- [ ] **Kẻ phá luật 1 — Quỷ Nuốt Lửa** (`fire_eater`, máu 90): trait mới `burn_eater` — Đốt và ô cháy (của người chơi **và** của mạch dung nham) **hồi máu** cho nó thay vì gây sát thương (hệ số `heal_ratio` khởi điểm 1,0). Lá đốt thành "lá dở trong trận này"; mô tả trận nói rõ.
- [ ] **Kẻ phá luật 2 — Phượng Tro** (`ash_phoenix`, máu 74): trait mới `rebirth` — lần đầu về 0 máu thì hồi sinh với `revive_ratio` (khởi điểm 0,4) máu tối đa sau `revive_sec` 1,5 s (không bị trúng lúc đó), **trừ khi** lúc chết đang có ≥ 1 tầng Hàn. Thưởng lối Hàn; HUD hiện biểu tượng "còn 1 mạng".
- [ ] **Boss vùng — Chúa Quỷ Lửa** (`inferno_lord`, máu 180, `aggressive`, `boss_min_runes` 3): trait mới `vent_surge` — cứ `interval_sec` (khởi điểm 10 s) cho 2 mạch bên người chơi phun cùng lúc, ưu tiên mạch chứa ô người chơi; kèm `phase_shift` (pha 2 ở 50 % máu: `vent_interval_sec` ×0,7).
- [ ] **Sân**: 2 hình mới trong `assets/data/arenas.json` — `forge` (2 mạch hàng mỗi bên) và `caldera` (ô giữa thiếu, 2 mạch cột) — `featured_bonus` hiệu ứng `burn`; `ArenaValidator` kiểm mạch nằm trên ô thật và luật hình chủ đạo ghép được từ ≥ 2 cặp mảnh.
- [ ] **Trọng số mảnh** `hellfire` trong `assets/data/pieces.json` `weights`: nghiêng mảnh 4–5 ô (vùng muộn, đòn lớn) nhưng `mono`/`bar2` ≥ 8 để vẫn có đòn nhanh.

**Phần C — Không Đảo (`sky_isles`)**

- [ ] Vùng `sky_isles` cùng định dạng, `name_key` / `intro_key` / `end_key` vi+en; mọi sân của vùng có `crumble: true`.
- [ ] **6 địch thường** (bậc tầng 1, khởi điểm): `cloud_sprite` (máu 88, cautious), `harpy` (máu 104, balanced, `movement.move_noise` 0,1), `wind_monk` (máu 118, balanced), `storm_eagle` (máu 126, balanced, `boss_step_cooldown_mult` thấp nhất vùng), `sky_sentinel` (máu 144, balanced, `boss_defense` 3), `thunder_shaman` (máu 150, balanced, trait `row_burner`).
- [ ] **Kẻ phá luật 1 — Chim Gió** (`gale_bird`, máu 86): trait mới `gust` — cứ `interval_sec` (khởi điểm 6 s) đẩy người chơi 1 ô theo hướng seeded (cảnh báo mũi tên `warn_sec` 0,6 s); không đẩy vào ô thiếu, ô rơi hay ô kết giới (đứng yên lần đó). Ép giữ vị trí, phạt đứng sát mép đảo.
- [ ] **Kẻ phá luật 2 — Thần Mây** (`cloud_veil`, máu 96): trait mới `shroud` — ô boss đang đứng bị mây che: **báo trúng** (bóng mảnh xanh/đỏ, Story 024) bị tắt khi đặt mảnh vào trận này, trừ lúc boss đang Ghim hoặc đang niệm (đứng yên). Thưởng Ghim và phản công; mô tả trận nói rõ.
- [ ] **Boss vùng — Long Vương Gió** (`storm_dragon`, máu 185, `balanced`, `boss_min_runes` 3): trait mới `island_drop` — cứ `interval_sec` (khởi điểm 11 s) một **đảo** bên người chơi (không phải đảo duy nhất còn đứng được) rơi trong `fall_sec`, cảnh báo `warn_sec` 1,2 s; kèm `gust` nhẹ.
- [ ] **Sân**: dùng `islands_bridge` có sẵn và thêm 2 hình `twin_isles` (2 đảo, 1 cầu 1 ô) và `three_isles` (3 đảo nhỏ); mỗi đảo ≥ 2 ô; `featured_bonus` hiệu ứng `pin`. Validator: mọi đảo nối được khi chưa ô nào rơi; hình chủ đạo ghép được từ ≥ 2 cặp mảnh.
- [ ] **Trọng số mảnh** `sky_isles`: nghiêng mảnh 1–3 ô (đảo nhỏ, mảnh lớn khó đặt vừa — hình không đặt vừa thì không rơi, luật 024).

**Phần D — Pool vùng lên 7**

- [ ] `hellfire` và `sky_isles` vào pool vùng của Story 031: pool **7 vùng**; một run 5 tầng × 2 lựa chọn không lặp vùng trong run (seeded). Hệ số tầng của 031 áp như mọi vùng; nếu Story 037 đã có, mỗi vùng mới có một mục mở khóa (ví dụ "lần đầu tới tầng 4") trong dữ liệu mở khóa của 037.
- [ ] Trait mới đăng ký trong `src/traits/trait_registry.gd`, kế thừa `BossTrait`; hook mới ("boss sắp chết" cho `rebirth`, "nhận hồi từ Đốt" cho `burn_eater`, "khóa báo trúng" cho `shroud`) thêm vào `TraitHost` ở một điểm.

**Phần E — Hiển thị, chạm và kiểm chứng**

- [ ] Đọc được trên điện thoại ngang: mạch dung nham là vệt đỏ sẫm cố định, sáng dần trong `vent_warn_sec`; ô sắp rơi có vết nứt lớn dần theo `crumble_progress`, ô đã rơi là khoảng trống có thanh thời gian; khe giữa đảo vẽ khác ô thiếu thường. Thần Mây: khi báo trúng bị khóa, bóng mảnh có viền xám và biểu tượng mây (người chơi biết vì sao không có màu). Không thêm thao tác mới.
- [ ] Test (`tests/unit/combat/hazard_test.gd` mở rộng, `tests/unit/traits/region_traits_test.gd` mở rộng, `tests/unit/run/regions_hellfire_sky_test.gd`): mạch phun đúng nhịp, cháy và đốt mảnh; ô rơi sau đứng đủ lâu, đẩy và trừ máu, chừa đường trên sân tách đảo; `burn_eater` hồi thay vì mất máu; `rebirth` hồi sinh một lần và không hồi khi có Hàn; `gust` không đẩy vào ô cấm; `shroud` tắt báo trúng trừ khi Ghim/niệm; `island_drop` không làm rơi đảo cuối; pool 7, không lặp vùng, 4 sân mới hợp lệ, đủ khóa i18n vi/en.
- [ ] **Mô phỏng**: như Story 036 (cờ vùng/tầng), bot hiểu mạch (né như ô cháy) và ô rơi (đổi ô trước `crumble_after_sec`). Báo theo tầng 1, 3, 5: tỉ lệ thắng từng trận và boss vùng, máu mất do mạch/ô rơi, số lần bị đẩy, tỉ lệ trúng ở trận Thần Mây so với trung bình. **Mục tiêu**: ở cùng tầng, trung bình mỗi vùng mới trong ±10 điểm so với trung bình 5 vùng có sẵn; không trận nào > 95 % hay < 15 % ở tầng 1; ở trận Quỷ Nuốt Lửa bộ khởi đầu Pháp sư (nặng lửa) vẫn thắng ≥ 25 % ở tầng 1 (lá dở chứ không phải trận chết chắc). Thêm một dòng tần suất vùng: qua 200 run seeded mỗi vùng xuất hiện như một lựa chọn 20–40 % số lượt chọn tầng. Chỉnh JSON, không chỉnh mã. Bảng vào Completion Notes và `production/qa/evidence/regions-hellfire-skyisles/simulation-regions.md` (+ raw).
- [ ] Ảnh trong `production/qa/evidence/regions-hellfire-skyisles/`: sân `forge` có mạch sắp phun và đang phun; Quỷ Nuốt Lửa hồi máu từ Đốt (số xanh); Phượng Tro hồi sinh; sân `twin_isles` có ô nứt và ô đã rơi; Chim Gió với mũi tên đẩy; bóng mảnh bị mây che; Long Vương Gió làm rơi một đảo; màn chọn vùng có Thành Hỏa Ngục / Không Đảo (vi và en).
- [ ] Không hằng số gameplay trong mã; chuỗi mới là khóa trong `assets/i18n/strings.csv` với vi và en.

---

## Implementation Notes

- Mạch phun dùng lại ô cháy của `row_burner` / Hỏa trận (cùng sát thương tick, cùng `burn_avoid`), chỉ thêm nhịp và cảnh báo.
- Ô rơi là nguồn chặn thứ tư trong `UnitMover.add_blocker` (nứt, kết giới, cát, rơi). Phép đẩy khi ô rơi dùng lại tìm ô kề của `chan_phong`.
- Đảo được tính từ ô thật của sân (thành phần liên thông) để `island_drop` và luật chừa đường không cần dữ liệu đảo viết tay.
- Demo: `--demo=vent|crumble|burn_eater|rebirth|gust|shroud|island_drop`.

---

## Out of Scope

- Vùng thứ 8 (chỉ làm nếu mô phỏng tần suất cho thấy lặp vùng khó chịu). Lá, bảo vật riêng của vùng. Đẩy rơi khỏi sân gây chết ngay. Cân bằng cả run (Story 040). Hình/âm thật.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/regions-hellfire-skyisles/`; bảng mô phỏng theo tầng và tần suất vùng.

**Status**: Created — 3 new suites (`tests/unit/run/regions_hellfire_sky_test`, `tests/unit/combat/vent_crumble_view_test`, `tests/unit/ui/hazard_strings_039_test`) and 4 extended (`hazard_test`, `region_traits_test`, `boss_brain_hazard_test`, the Story 037 unlock suites), 9 screenshots and `simulation-regions.md` + raw in `production/qa/evidence/regions-hellfire-skyisles/`

---

## Dependencies

- Depends on: Story 036 (khối `hazards`, mẫu vùng, cờ mô phỏng vùng/tầng), Story 031 (pool vùng, hệ số tầng); dùng dữ liệu mở khóa của Story 037 nếu đã xong
- Unlocks: Story 040 (cân bằng cả run với đủ 7 vùng)

---

## Completion Notes
**Completed**: 2026-10-26
**Criteria**: 22/23 passing or passing with notes; E3 (simulation) partly met. Met: each new region within +-10 points of the five-region mean at floors 1 / 3 / 5 (hellfire +1.6 / +3.9 / +6.5, sky_isles after tuning +0.6 / -6.8 / -6.1 against 95.8 / 89.9 / 80.8), region frequency 27.5-31.1 % of floor choices over 200 runs (target 20-40 %), fire_eater with the Phap su starter deck 100 % at floor 1 (target >= 25 %). NOT met: "no match above 95 % at floor 1" (measurement limit: the old regions are 97-100 % there too, as in Story 036). DEFERRED: how vents / crumble / the traits read and feel on a real phone (gate 8 playtest; UI polish waits for the art assets).
**Deviations**: JSON tuning `sky_isles.region_normalize.hp_mult` 0.75 -> 0.53 (without it -21 / -23 points at floors 3 / 5, mostly 180 s timeouts on the small split arenas; crumble timing was probed and is not the cause); two extra hazards keys `vent_tick_sec` 0.5 and `vent_tick_damage` 2.0 (the story gives no burn numbers for vents; `RunConfig.HAZARD_OVERRIDE_KEYS` now has 19 entries); a crumbling cell pushes its occupant to the nearest free 4-neighbour that keeps an exit (the chan_phong push only pushes away from the divider); `island_drop` removes the arena's bridge cells from the islands and never drops a bridge or the last island; there was no enemy heal path, so `CombatState.heal_enemy` / `enemy_healed` were added for `burn_eater`; `rebirth`: a Han stack applied by the same lethal cut does not stop that death, a Han burst that kills clears its own stacks first (so it revives); two new achievements `reach_floor_4` (-> hellfire) and `reach_floor_5` (-> sky_isles) with a new `best_floor` condition, so the Story 037 counts became 24 achievements and the locked list gained 2 regions; `n5` (4 long) fits no sky_isles arena (2-3 rows), accepted by the story.
**Test Evidence**: Integration: 3 new suites + 4 extended + 12 updated, sweep 246 parse, 102 headless + 4 windowed FAILS=0 (`piece_deck_flow_test` failed once under machine load, 3 of 3 alone, already flaky in the register), launch 0 errors; screenshots `production/qa/evidence/regions-hellfire-skyisles/01,03-09*.png`; simulation `simulation-regions.md` + `simulation-regions-raw.txt`.
**Code Review**: Skipped (solo mode)
**Tech debt**: TD-035.
