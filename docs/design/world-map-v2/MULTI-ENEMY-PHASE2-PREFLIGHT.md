# Multi-enemy Phase 2 — Preflight: quyền sở hữu file và bản đồ thay đổi resolver

**Ngày:** 2026-11-13 · **Trạng thái:** preflight xong, **DỪNG** vì xung đột ownership · **Chưa sửa code Phase 2.**
Nền: `MULTI-ENEMY-ENCOUNTER-AUDIT.md` §4.3 + roadmap bước 2, `MULTI-ENEMY-PHASE1-DESIGN.md` §3.4.

## 1. Baseline thực tế (không ghi là PASS)

| Hạng mục | Trạng thái 13/11 |
|---|---|
| Full suite Phase 1 | 296/298 — 2 FAIL |
| `keyword2_test` | **Vẫn tái hiện (tĩnh):** `assets/i18n/strings.csv` còn 3 dòng sai số cột (1128 `ui.status.poison.desc`, 1134 `enemy_skill.hound_ember_charge.counter`, 1136 `enemy_skill.golem_ash_mantle.counter`). File do session monster-skills sửa. |
| `pattern_phase0_ai_test` | Chưa chạy lại được: lúc preflight session monster-skills đang chạy Godot (`pattern_roster_fairness_test`, PID 17656); không chạy song song. Test chưa track, kiểm `enemy_skills.json` cũng do session đó sửa. |
| Working tree mới | Session monster-skills đã sửa thêm `assets/data/chapters.json` (+12 dòng: 6 quái Hellfire `imp, ember_hound, ash_golem, flame_cultist, magma_slug, hell_knight` chuyển `brain: pattern`), `enemy_skills.json`, `strings.csv`, `src/ui/status_row.gd`, `tests/unit/combat/enemy_skills_config_test.gd`, 4 test `pattern_hellfire_*`. Không đụng file Phase 0/1. |

## 2. Quyền sở hữu các file Phase 2 cần

| File | Trạng thái | Chủ | Phase 2 cần đổi gì |
|---|---|---|---|
| `src/combat/swing_arbiter.gd` | sạch | — | `_settle/_fire_event`: hit theo `enemies_in`, mỗi unit một lần; `boss_defense` → `unit.defense`; `enemy_untargetable_fn(u)`; bounce/pull theo unit; `_cancel_all` khi `enemy_died` (giữ) |
| `src/combat/cut_effects.gd` | sạch | — | `apply`/`can_affect` nhận unit key; damage/push/pull/R1/execute/HP ratio theo unit (69 điểm chạm) |
| `src/combat/tile_hazards.gd` | sạch | — | timer đứng (mire/vent/crumble) theo unit; `_fall` qua `set_unit_cell` |
| `src/combat/parry_guard.gd` | sạch | — | phản đòn / ghim đúng unit tấn công |
| `src/combat/zone_rules.gd` | sạch | — | bảo vệ lối ra của mọi unit |
| `src/combat/crit_rules.gd` | sạch | — | điều kiện crit đọc HP / ô của unit bị trúng |
| `src/combat/unit_mover.gd` | sạch | — | không bắt buộc ở Phase 2 (occupancy đã ở `CombatState.unit_fits`) |
| **`src/combat/status_effects.gd`** | **M, +101 dòng (poison, `active_statuses`…)** | **monster-skills** | Bắt buộc: `_units_on` (`:1408-1416`), `_burn_lead_cells` (`:1424`), `_check_thorn_entries` (`:1320-1340`), `_fall_hole` / landing (`:1207-1243`), `fire_trap` / ward (`:770-864`), `_is_dead` (`:1150`), hook chỉ-ENEMY `fragile_mult_fn` (`:294`), `frost_burst_mult_fn` (`:321`), `burn_heal_ratio_fn` (`:608, :1312`) — tất cả đọc `state.enemy_cell` / `is_enemy_dead` / `Side.ENEMY` |
| **`src/combat/combat_view.gd`** | **M** | **monster-skills** | `SwingArbiter.new(... _boss.get_actor() ...)` `:486`, `boss_defense` `:492`, `_on_swing_resolved` feedback `:504`, `pattern_hit_fn` `:516`, `_on_parried` `:2380` |
| **`src/traits/trait_host.gd`** | **M** | **monster-skills** | hook toàn cục `enemy_untargetable_fn` `:35`, `burn_heal_ratio_fn` `:39`, `enemy_death_hook_fn` `:44` (theo unit = Phase 5 theo roadmap, nhưng arbiter Phase 2 đổi chữ ký `enemy_untargetable_fn`) |
| **`src/combat/pattern_controller.gd`** | **M** | **monster-skills** | guard `_status.guard(E)`; `on_enemy_hit()` không đối số (Phase 3 theo roadmap) |

**Xung đột:** `status_effects.gd` (bắt buộc cho Phase 2), `combat_view.gd` và `trait_host.gd` (cần cho phần nối). Theo
brief: dừng, không sửa.

## 3. Vì sao không làm "nửa Phase 2" im lặng

Sổ trạng thái unit của `StatusEffects` (pin, root, slow, guard, Rạn, Hàn, mark, poison) là `Dictionary` khoá `int`
nên **nhận được** `unit_key(i)` mà không sửa file. Nhưng phần tick và chiếm chỗ (`_units_on`, cháy, gai, lỗ rơi, bẫy,
ward, phản ứng R1) và các hook nhân Rạn / nổ Hàn chỉ biết `Side.ENEMY`. Nếu chỉ chuyển `CutEffects`/`SwingArbiter`:
unit 1 nhận damage đúng nhưng **không bị đốt, không dính gai, không rơi lỗ**, và Rạn của unit 1 không được nhân
signature — vi phạm nguyên tắc "thuộc tính của unit này không được xử lý như unit khác". Trong game chưa có unit 1
(CombatView dựng ở Phase 3) nên không lộ ra, nhưng đó là một nguồn lệch ngữ nghĩa phải ghi rõ.

## 4. Phương án phối hợp

| | Phương án | Ưu | Nhược |
|---|---|---|---|
| **A (đề xuất)** | Chờ session monster-skills commit (hoặc bàn giao) `status_effects.gd`, `combat_view.gd`, `trait_host.gd`; rồi làm Phase 2 trọn vẹn | Không xung đột, một lần đúng | Phụ thuộc lịch session kia |
| B | Phase 2a ngay trong 6 file sạch (arbiter, cut_effects, tile_hazards, parry_guard, zone_rules, crit_rules), truyền `unit_key` vào sổ int của StatusEffects; ghi khoảng trống tick/occupancy thành danh sách "Phase 2b" + test đánh dấu khoảng trống; 2b sau bàn giao | Tiến được ngay | Trạng thái lai có chủ đích; `SwingArbiter.enemy_untargetable_fn` đổi chữ ký sẽ cần shim vì `trait_host.gd` gán nó |
| C | Nhờ session monster-skills tự thêm vào `status_effects.gd` các hàm theo unit (spec §5 dưới) | Họ giữ file | Giao việc ngoài phạm vi của họ |

## 5. Câu hỏi thiết kế cần chốt trước khi code (audit chưa nói rõ)

1. **Một cast phủ nhiều unit:** mỗi unit nhận **toàn bộ** damage một lần (audit §4.3) — giữ nguyên, không chia?
2. **Đẩy / kéo / dời (xung_kich, chan_phong, cuong_phong, loc_cuon, push/pull):** áp cho mọi unit bị phủ theo thứ tự
   index, mỗi unit chỉ dời nếu đích trống (occupancy) — hay chỉ unit gần nhất?
3. **Chuỗi / nảy (bounce, SEQUENTIAL_CHAIN):** mắt xích tiếp theo nhắm unit bị phủ kế tiếp, hay giữ một mục tiêu?
4. **Rạn / execute / mark:** tính và tiêu theo từng unit (Rạn của unit 1 chỉ nhân đòn vào unit 1)?
5. **Interrupt:** Phase 2 chỉ unit 0 có actor (agent của unit 1+ là Phase 3) → chỉ ngắt khi unit 0 bị trúng. Đồng ý?
6. **Thống kê trận (`damage_dealt`, objective `big_cast`):** cộng damage mọi unit?

---

## 6. Quyết định của người dùng (2026-11-13)

**Chọn Option A.** Chờ session monster-skills commit hoặc bàn giao rõ ràng cả ba file `status_effects.gd`,
`combat_view.gd`, `trait_host.gd`, rồi làm Phase 2 trọn vẹn một lượt. **Không làm Phase 2a, không workaround, không
trạng thái triển khai một phần.**

### 6.1 Quyết định thiết kế đã chốt (trả lời §5)

1. Một cast phủ nhiều unit: **mỗi unit nhận full damage đúng một lần.**
2. Push / pull / shift: xử lý unit theo **index tăng dần**; chỉ dời khi đích hợp lệ **và còn trống tại thời điểm xử lý
   unit đó** (occupancy kiểm tra lại cho từng unit, sau khi unit trước đã dời). Không bao giờ hai unit cùng một ô; không
   dời xuyên qua unit khác nếu luật di chuyển hiện tại không cho. Trường hợp đích của unit sau bị unit trước chiếm:
   unit sau **đứng yên** (hoặc rút ngắn quãng dời theo đúng luật "chặn" hiện có của push) — phải có test riêng.
3. Chain / bounce: mắt xích tiếp theo chọn **unit tiếp theo** trong danh sách bị phủ (`enemies_in`, thứ tự index).
4. Fragile (Rạn), execute, mark: trạng thái và việc tiêu thụ **độc lập theo unit**.
5. Phase 2 chỉ unit 0 có actor: **chỉ hit vào unit 0 mới interrupt.**
6. Match stats / objectives: **cộng damage của mọi unit.**

### 6.2 Điều kiện bắt đầu (tất cả phải đúng)

- [ ] `status_effects.gd`, `combat_view.gd`, `trait_host.gd` đã được session monster-skills **commit** hoặc **bàn giao
      bằng văn bản** (note trong thư mục chung hoặc tin nhắn), và không còn file Phase 2 nào có thay đổi chưa commit của
      session khác.
- [ ] `strings.csv` hết dòng sai số cột → chạy lại `keyword2_test`.
- [ ] Chạy lại `pattern_phase0_ai_test`.
- [ ] Ghi baseline mới chính xác (số suite / số FAIL, phân loại) trước khi sửa code.
- [ ] Không có tiến trình Godot nào khác trên project.

### 6.3 Trạng thái kiểm tra gần nhất (2026-11-13)

| Mục | Kết quả |
|---|---|
| Commit mới trên `main` | không (HEAD vẫn `2fdfe3f`) |
| `status_effects.gd`, `combat_view.gd`, `trait_host.gd` | vẫn `M` (chưa commit) |
| `strings.csv` | vẫn `M`; 3 dòng sai cột (`ui.status.poison.desc`, `enemy_skill.hound_ember_charge.counter`, `enemy_skill.golem_ash_mantle.counter`) |
| Note bàn giao của monster-skills | có, nhưng ghi "UNCOMMITTED, waiting for review before group C" — **chưa bàn giao** |
| Yêu cầu của họ cho multi-enemy (note §"For the multi-enemy session") | F2 / F5 dùng chung giữa các enemy, push ICD theo phe, frost-burst ICD phía player, unit id trên `damaged` / `enemy_died` (đã có `unit_damaged` / `unit_died` từ Phase 1) — sẽ tính vào Phase 2/3 |

---

## 7. Bàn giao (2026-11-13) và thiết kế triển khai Phase 2

**Bàn giao:** session monster-skills xác nhận bằng tin nhắn: `status_effects.gd`, `combat_view.gd`, `trait_host.gd`
thuộc multi-enemy từ 13/11; họ chỉ sửa data (Group C). Group D có thể cần **một dòng** trong `combat_view.gd`
(`_on_pattern_phase_started` không gọi `announce_phase` khi host đã có `phase_shift` / `boss_phases`) — họ sẽ nhắn,
multi-enemy sửa hoặc phối hợp. `strings.csv` đã sửa (kiểm tĩnh: 1158 dòng, mọi dòng 3 cột). Điều kiện còn lại: chạy
lại `keyword2_test`, `pattern_phase0_ai_test` và full suite khi không còn Godot nào.

### 7.1 Một quy ước "key" xuyên suốt

`key 0` = player, `key 1 + i` = enemy unit `i` (`CombatState.unit_key`). `key 1` == `Side.ENEMY` == unit 0, nên mọi
lời gọi hiện có (chỉ truyền 0 / 1) giữ nguyên nghĩa. **Nửa sân** của một key = `CombatState.side_of(key)`
(PLAYER cho 0, ENEMY cho mọi key ≥ 1). Quy tắc tách: *sổ theo unit* (pin, root, slow, guard, Rạn, Hàn, mark, poison,
ICD phản ứng, last_cell, timer đứng của hazard) khoá theo **key**; *sổ theo ô / nửa sân* (cháy, gai, field, lỗ, mire,
cát, sụp) khoá theo **nửa sân**.

### 7.2 Thay đổi theo file

| File | Thay đổi |
|---|---|
| `combat_state.gd` | Các hàm nhận `side` hiện có (`cell_of`, `unit_cells`, `unit_at`, `unit_in`, `damage`, `cast_origin`) nhận **key**: key 0/1 như cũ, key ≥ 2 = unit tương ứng. Thêm `side_of`, `is_key_dead`, `hp_of`, `max_hp_of`, `heal_key`, `key_fits`, `set_key_cell`, `hit_cell_of`, `footprint_size_of`, `cells_at_key`, `enemy_keys`. Không đổi ngữ nghĩa Phase 1. |
| `cut_effects.gd` | `apply` nhận `options.target_key` (mặc định 1 = như cũ) và `options.cast_parts` (mặc định true). Mọi thao tác unit dùng key; zone / field / ignite / detonation / heal_caster chỉ chạy khi `cast_parts`. Thêm `target_keys(...)` (unit bị phủ, + unit kề cho thẻ kéo, trừ unit không nhắm được) và `merge_unit_results(...)`. Push / pull / dời dùng `key_fits` + `set_key_cell` (occupancy kiểm lại từng bước). |
| `swing_arbiter.gd` | `_settle` / `_fire_event`: một trận 1 unit đi đúng đường cũ; ≥ 2 unit: lặp `target_keys` theo index, lần đầu `cast_parts = true`, các lần sau false; kết quả gộp (damage cộng, hit = bất kỳ, `unit_results`). Đếm hit của cast **theo unit** (max_hits, một hit / wave / unit). Bounce chọn unit bị phủ kế tiếp chưa trúng. Interrupt và `pattern_hit_fn` chỉ khi unit 0 trúng. Defense: unit 0 = `boss_defense` (như cũ), unit khác = `EnemyUnit.defense`; `enemy_untargetable_fn` chỉ áp unit 0. Mark trigger theo từng unit trúng. Kết thúc trận: `all_required_dead()` thay `is_enemy_dead()`; unit 0 chết khi còn unit khác chỉ huỷ actor của unit 0. |
| `status_effects.gd` | `_is_dead` → `is_key_dead`; `_units_on` / lead cells / thorn entry / trap / lỗ rơi / landing lặp mọi unit sống; heal cháy qua `heal_key`; hook nhân Rạn / nổ Hàn của signature áp mọi key ≥ 1; hook `burn_heal_ratio_fn` (trait) chỉ unit 0. |
| `tile_hazards.gd` | Timer đứng (mire, vent, sụp) và miễn mire thành dict theo key; tra unit theo key; `_fall` qua `set_key_cell`; tránh ô của mọi unit khi rải cát / sụp. |
| `zone_rules.gd` | `fit_cells_for(grid, side, standing_cells, ...)`: giữ lối ra cho **mọi** unit đứng trên nửa sân (gấp `fit_cells` theo từng unit, ô unit khác tính là chặn). |
| `crit_rules.gd` | Điều kiện crit đọc ô / HP / status của **key** mục tiêu. |
| `combat_view.gd` | Chỉ `get_match_stats().damage_dealt` = tổng damage của mọi unit (quyết định 6). Không dựng unit 1+ (Phase 3). |
| `parry_guard.gd`, `trait_host.gd`, `unit_mover.gd` | **Không đổi**: chỉ unit 0 có actor (phản đòn đúng unit 0); trait thuộc unit 0 (per-unit host là Phase 5); unit 1+ chưa có mover. |

### 7.3 Baseline trước Phase 2 (2026-11-13, sau bàn giao)

`production/qa/multi-enemy-phase2-baseline-2026-11-13.txt`: **299/300** — `keyword2_test` và `pattern_phase0_ai_test`
nay xanh; **`tests/unit/ui/terminology_scan_test.gd` FAIL** (xanh ở baseline Phase 0 và Phase 1). Test chỉ đọc
`assets/i18n/strings.csv` (do monster-skills sửa) → phân loại tạm: lỗi thuộc session khác, đang lấy dòng FAIL cụ thể.

---

## 8. Phase 2 đã triển khai (2026-11-13, UNCOMMITTED)

### 8.1 File đã sửa / thêm

| File | Thay đổi Phase 2 |
|---|---|
| `src/combat/combat_state.gd` | Các hàm nhận `side` (`cell_of`, `unit_cells`, `unit_at`, `unit_in`, `damage`, `cast_origin`) nhận **key** (0 / 1 như cũ; ≥ 2 = unit tương ứng). Thêm `side_of`, `is_key_dead`, `hp_of`, `max_hp_of`, `heal_key`, `key_fits`, `set_key_cell`, `hit_cell_of`, `footprint_size_of`, `cells_at_key`, `enemy_keys`, `all_keys`, `enemy_keys_in`, `key_at`. `damage_key` / `cell_of_key` / `unit_cells_of_key` (Phase 1) thành alias. |
| `src/combat/cut_effects.gd` | `apply`: `options.target_key`, `options.cast_parts`, `options.detonated`; mọi thao tác unit theo key, zone / field / ignite / detonate / heal_caster / featured burn chỉ khi `cast_parts`; push / pull qua `key_fits` + `set_key_cell`. Thêm `target_keys`, `merge_unit_results`, `hit_unit0`. |
| `src/combat/swing_arbiter.gd` | `_settle` lặp `target_keys`; `_fire_event` viết lại theo key (sổ hit / wave / keyword theo unit, bounce chọn unit kế tiếp, pull / push / R1 theo unit, interrupt + `pattern_hit_fn` chỉ unit 0); `_finish_cast` + `_trigger_mark` theo unit (`only_key` cho echo); defense / untargetable / crit snapshot theo key; kết thúc trận = `all_required_dead()`; unit 0 chết khi còn unit khác chỉ dừng actor của nó. |
| `src/combat/status_effects.gd` | `_is_dead` → `is_key_dead`; `_units_on` / lead cells / thorn entry / trap / lỗ rơi / landing theo mọi unit sống; heal cháy qua `heal_key`; hook nhân Rạn / nổ Hàn của signature cho mọi key ≥ 1; `burn_heal_ratio_fn` vẫn chỉ unit 0. |
| `src/combat/tile_hazards.gd` | Sổ unit (miễn mire, đứng mire / vent / sụp) thành dict theo key; `mire_damage` phát key; `_fall` qua `set_key_cell`; ô hạ cánh / rải cát tránh mọi unit; leave-a-path cho mọi unit. |
| `src/combat/zone_rules.gd` | `fit_cells_for`, `standing_cells`. |
| `src/combat/crit_rules.gd` | Điều kiện crit đọc ô của key mục tiêu. |
| `src/combat/combat_view.gd` | `get_match_stats().damage_dealt` = tổng mọi unit; pattern `on_enemy_hit` chỉ khi unit 0 trúng; trait nhận `unit0_damage`. |
| `tests/unit/combat/multi_enemy_resolver_test.gd` (mới) | 49 check, 14 nhóm. |

Không sửa: `parry_guard.gd`, `unit_mover.gd`, `trait_host.gd`, `pattern_controller.gd`, `chapters.json`, data / asset.

### 8.2 Lỗi tìm được khi test

`merge_unit_results` trả kết quả đơn nguyên dạng legacy cả khi unit trúng duy nhất là unit 1 → `hit_unit0` tưởng unit 0
trúng → ngắt nhầm swing của unit 0. Sửa: chỉ giữ dạng legacy khi mục tiêu là hero / unit 0. Test C đã FAIL trước khi sửa
và PASS sau.

### 8.3 Kết quả test

| Bộ | Kết quả |
|---|---|
| `multi_enemy_resolver_test` (mới) | 49 / 49 |
| `combat_state_units_test` | 63 / 63 |
| Khoá: `boss_footprint`, `state_damaged_signal`, `boss_downed`, `arbiter`, `cut` | xanh |
| Hồi quy combat + traits + battle + relics + run | 184 / 186 |
| Full suite | 300 / 302 |

Hai suite không xanh, đều không do Phase 2:
- `pattern_hellfire_group_d_test` (test chưa track của monster-skills, Group D): 2 FAIL đúng lỗi có sẵn họ ghi trong
  note bàn giao ("on_enter does not force weight-0 skills", bản sửa 3 dòng đề xuất, chưa áp dụng; `pattern_controller.gd`
  Phase 2 không chạm).
- `pattern_roster_fairness_test`: log trống vì vượt timeout 240 s của runner (~280 s khi máy bận, theo note monster-skills);
  chạy riêng để xác nhận (§8.4).
- `terminology_scan_test` (FAIL ở baseline) nay xanh: lỗi tạm thời ở `strings.csv` của monster-skills, họ đã sửa.

### 8.4 Xác nhận riêng

`pattern_roster_fairness_test` chạy riêng (timeout 900 s): **FAILS=0, 277 s** — xanh; ô trống trong full suite chỉ là
timeout 240 s của runner.

### 8.5 Rủi ro / chưa làm (trước Phase 3)

- `CombatView` vẫn chưa dựng unit 1+ → trong game vẫn 1v1; mọi đường per-unit chỉ chạy trong test. Nối là Phase 3.
- Unit 1+ chưa có actor / brain / mover (Phase 3): chưa tấn công, chưa đi, `ParryGuard` vẫn phản đòn unit 0 (đúng vì chỉ
  unit 0 đánh).
- Trait, `burn_heal_ratio_fn`, `enemy_untargetable_fn`, `enemy_death_hook_fn` vẫn thuộc unit 0 (per-unit host = Phase 5).
- Signal `pinned` / `trap_fired` / `reaction_fired` / `mire_damage` / `burn_hurt` phát **key** (1 = unit 0 như cũ; ≥ 2 =
  unit khác). HUD / audio hiện chỉ nghe 0 / 1 → pop / chip của unit 1+ chưa hiện (Phase 4).
- Profile modifiers và Kiếp vẫn chỉ vào unit 0 (từ Phase 1; `modifier_target` là quyết định Phase 3).
- Runner `tools/qa/run_all_tests.sh` timeout 240 s < thời gian `pattern_roster_fairness_test` khi máy bận.

---

## 9. Phase 3 preflight (2026-11-13) — DỪNG vì xung đột ownership

Phase 3 (audit §9 bước 3): `CombatView` dựng N unit + agent (`BossController` / `PatternController` mỗi unit), một
`FieldDrops` nửa enemy dùng chung, `SwingArbiter` N actor, occupancy cho mover / brain, `ThreatBoard` (F2 / F5 chung,
thẻ tấn công), kết thúc trận `all_required_dead()`.

| File cần | Trạng thái | Chủ |
|---|---|---|
| `combat_view.gd`, `swing_arbiter.gd` | M | multi-enemy (bàn giao 13/11) |
| `boss_controller.gd`, `boss_brain.gd`, `unit_mover.gd`, `field_drops.gd`, `cut_actor.gd`, `boss_learning.gd` | sạch | — |
| **`pattern_controller.gd`** | **M, +403 / −11 (monster-skills Phase 0, chưa commit)** | **monster-skills** — không nằm trong 3 file đã bàn giao; note của họ: "pattern_controller.gd is NOT touched by multi-enemy"; họ còn đề xuất một bản sửa 3 dòng chưa áp dụng ở đó (bug `on_enter` / weight 0, Group D) |

**Vì sao chặn:** `PatternController` là "skill lifecycle for ONE enemy": 25 chỗ đọc / ghi trạng thái **unit 0**
(`set_enemy_footprint`, `set_enemy_cell`, `enemy_hp_floor`, `enemy_invulnerable_left`, `enemy_in`, `guard(E)` …). Một
instance thứ hai cho unit 1 sẽ ghi vào unit 0. Toàn bộ ch1 (11 / 16 match) và toàn bộ Hellfire (9 / 9) giờ chạy pattern
brain → không làm được đội hình ch1 / Hellfire nào nếu không sửa file này. F5 (khoảng cách cảnh báo chung) và thẻ tấn
công cũng nằm trong vòng đời của `PatternController`.

**Phương án:**
- **A (đề xuất):** nhờ monster-skills áp (hoặc bỏ) bản sửa 3 dòng của họ rồi bàn giao `pattern_controller.gd`; sau đó làm
  Phase 3 trọn vẹn.
- B: Phase 3a ngay với file sạch: N unit chỉ khi unit 1+ là **block brain** (ch2, ch3, swamp, desert, sky_isles);
  entry pattern brain ở unit 1+ bị từ chối có cảnh báo; F5 / thẻ tấn công cho pattern để 3b. Trạng thái lai có chủ đích.
- C: chờ.

**Câu hỏi thiết kế cần chốt cho Phase 3:** (1) `ThreatBoard` + thẻ tấn công (`attack_slots`) có thuộc Phase 3 không
(audit §6.2 nói có; brief Phase 3 không liệt kê); (2) `BossLearning` một bản chung hay mỗi unit; (3) think interval ×
√N có áp không; (4) unit 1+ block brain dùng chung `FieldDrops` nửa enemy, mỗi unit một `HoldSlots` — đồng ý?
