# Multi-enemy Phase 3–5 — Kế hoạch (chưa code)

**Ngày:** 2026-11-13 · **Trạng thái:** kế hoạch; **không có code**. **Cập nhật 2026-11-13:** người dùng duyệt D1–D5 và ba điều chỉnh A1–A3 (§1.1b). Phase 3 chờ bàn giao `pattern_controller.gd` từ
session monster-skills (họ đã áp bản vá `on_enter` 3 dòng, đang chạy full suite). Phase 4 / 5 chỉ lập kế hoạch.
**Nền:** `MULTI-ENEMY-ENCOUNTER-AUDIT.md` §4, §6, §9; `MULTI-ENEMY-PHASE2-PREFLIGHT.md` §7–9 (Phase 2 per-unit resolver).

---

## 1. Phase 3 — Dựng N unit + agent trong CombatView

### 1.1 Quyết định đã duyệt và đối chiếu với code

| # | Quyết định | Đối chiếu code (đọc 13/11) | Kết luận |
|---|---|---|---|
| D1 | Một `ThreatBoard` + `attack_slots` chung cho mọi unit | F2 (trần ô đỏ) dùng chung được **không cần sửa** `PatternController`: `external_red_fn` là biến public (`pattern_controller.gd:47`), `CombatView` trỏ nó vào `ThreatBoard.red_cells`. **F5** (khoảng cách cảnh báo, `_since_warning` `:86`) và **cổng thẻ trước WINDUP** nằm trong `_try_choose` → phải sửa `pattern_controller.gd` (sau bàn giao). Block brain: cổng thẻ đặt ở `BossController._do_cut` (file sạch). Trả thẻ: `CutActor.swing_resolved / swing_cancelled` + feint (`BossController.feinted`) + `PatternController.stage_changed` về RECOVERY / IDLE. | Tương thích |
| D2 | Một `BossLearning` chung | `BossLearning` chỉ giữ **một** swing đang chạy (`_swing_active`, `_swing_cells`, `_swing_dodged`, `boss_learning.gd:15-17`). Với `attack_slots = 1` thì không bao giờ có 2 swing chồng nhau → đúng nguyên vẹn. Với `attack_slots ≥ 2` swing thứ hai ghi đè swing đầu → đếm né (dodge streak) sai. | **Không tương thích một phần.** Đề xuất: giữ MỘT instance chung nhưng mở rộng sổ swing theo unit key (`on_boss_swing_started(cells, player_cell, key = 1)` …, mặc định key 1 = như cũ). File sạch, thay đổi nhỏ. Cần duyệt. |
| D3 | Think interval × √N, có min / max | Block brain: `BossBrain.decide` so `_think_clock` với `_config.think_interval_sec` (`boss_brain.gd:259`); config là `BossBrainConfig` **dùng chung** và bị `_apply_brain_params` / `boss_phases` sửa tại chỗ → mỗi unit cần **bản config riêng**. Pattern: `PatternController.think_interval_sec` (public). | Tương thích nếu mỗi unit có config riêng. Đề xuất kẹp: `max(base × √N, base)` và trần `1.0 s`, sàn `0.05 s` (sàn pattern hiện có). N = 1 → nguyên giá trị. |
| D4 | Một `FieldDrops` chung nửa enemy | `BossController._init` tự tạo `FieldDrops` (`boss_controller.gd:85`) và `tick` nó với `_state.enemy_cell` + số ô đầy của **hand của nó** (cơ chế "đói", `:126`). Chung → phải **tiêm** drops và tick **một lần** / khung từ `CombatView`. | Tương thích sau khi đổi: tiêm drops; `CombatView` tick một lần; "đói" đọc hand **ít khối nhất** của các unit block brain. Unit pattern brain không nhặt khối (như hiện nay); nếu không có unit block brain nào thì không rơi khối nửa enemy (như trận pattern hiện nay). |
| D5 | `HoldSlots` mỗi unit block brain | `BossController` tự giữ `_hand` (`:84`). Nhặt khối: `_on_cell_changed(side)` lọc chỉ theo phe (`:356`) → mọi controller cùng nhặt. | Tương thích: chuyển sang `state.unit_cell_changed(index)` lọc đúng unit. |

### 1.1b Quyết định đã duyệt (người dùng, 2026-11-13) — bản chốt cho Phase 3

| # | Quyết định chốt |
|---|---|
| D1 | Một `ThreatBoard` + `attack_slots` chung cho mọi unit (F2 ô đỏ chung, F5 khoảng cách cảnh báo chung, cổng thẻ trước WINDUP / swing). |
| D2 + **A1** | Một `BossLearning` chung, **sổ swing đang chạy riêng theo unit key**: `on_boss_swing_started / cancelled / resolved(…, key)` ghi vào bản ghi của key đó; hai swing chồng nhau không ghi đè trạng thái học của nhau; dodge streak / interrupt count / feint chance vẫn là số **chung** của cả đội. Mặc định `key = 1` (unit 0): với `attack_slots = 1` (chỉ một swing tại một thời điểm) hành vi y như hiện nay. |
| D3 | Think interval = `clamp(base × √N, 0.05, 1.0)` s, N = số unit enemy của trận (N = 1 → `base`, không đổi). Áp cho `BossBrainConfig.think_interval_sec` riêng của từng unit và `PatternController.think_interval_sec`. |
| D4 | Một `FieldDrops` chung nửa enemy, **tiêm** vào mọi `BossController`, **tick đúng một lần / khung** từ `CombatView` (controller không tick nó nữa); "đói" đọc hand ít khối nhất trong các unit block brain. |
| D5 | Một `HoldSlots` mỗi unit block brain; nhặt khối theo `CombatState.unit_cell_changed(index)` của chính unit đó. |
| **A2** | Mọi entry đã resolve có **khối `ai`** (§1.2): `brain_set`, `boss_think_interval_sec`, `boss_reaction_sec`, `movement`, `boss_step_cooldown_mult`, `boss_cards`, `swing_speed_mult`, `mire_immune` (+ các khoá AI liên quan khác của template, liệt kê §1.2). Unit 0 giữ nguyên tương thích (khối `ai` của entry 0 suy ra từ match đã resolve, như `max_hp`). Unit 1+ lấy từ template của nó, scale như unit 0. **Mỗi unit một `BossBrainConfig` độc lập có thể sửa** (tải mới `BossBrainConfig.load_from_file()` cho mỗi unit rồi áp khối `ai` của nó); không sửa template, `chapters.json` hay bất kỳ config dùng chung nào. |
| **A3** | Mọi unit có actor đều có thể bị ngắt. Một hit chỉ ngắt **swing của đúng unit bị trúng**, chỉ báo `on_enemy_hit()` cho `PatternController` của unit đó; không bao giờ ngắt unit khác vì key dùng chung hay sai (thay quyết định Phase 2 #5 "chỉ unit 0", vốn đúng vì khi đó chỉ unit 0 có actor). |

### 1.2 Lỗ hổng dữ liệu phải lấp trước (file của multi-enemy)

Entry đã resolve (`FormationRules.RESOLVED_KEYS`) **chỉ** mang `template_id, max_hp, defense, brain, enemy, footprint`
(+ `traits`, `role`, `required`). Unit 1+ thiếu mọi khoá AI của template: `brain_set`, `boss_step_cooldown_mult`,
`boss_think_interval_sec`, `boss_reaction_sec`, `movement`, `swing_speed_mult`, `combo_chance`, `combo_gap_sec`,
`boss_min_runes`, `boss_cards`, `boss_drop_interval_mult`, `boss_root_while_swinging`, `pattern_tempo_mult`,
`mire_immune`. → Phase 3 bước 0: `RunConfig._resolve_enemies` gắn thêm khối `ai` (các khoá trên, đã scale như
`_apply_scaling` làm cho unit 0) vào mỗi entry; `FormationRules` thêm `RESOLVED_AI_KEYS`; test công thức. Đây là
**mở rộng schema** ngoài thiết kế Phase 1 → **đã duyệt (A2)**. Danh sách khoá của khối `ai`: `brain_set`,
`boss_think_interval_sec`, `boss_reaction_sec`, `movement`, `boss_step_cooldown_mult`, `boss_cards`, `swing_speed_mult`,
`mire_immune`, cộng `combo_chance`, `combo_gap_sec`, `boss_min_runes`, `boss_drop_interval_mult`, `boss_root_while_swinging`,
`pattern_tempo_mult` (cùng nhóm "AI của template"; số nào `_apply_scaling` scale cho unit 0 thì scale y hệt cho unit 1+).

### 1.3 Kiến trúc Phase 3

```
EnemyAgent (mới, src/combat/enemy_agent.gd) — một bản / unit
  key, unit (EnemyUnit), controller: BossController, pattern: PatternController | null,
  brain_config (bản riêng), hand (trong controller)
ThreatBoard (mới, src/combat/threat_board.gd) — một bản / trận
  attack_slots, request(key) -> bool, release(key), holders()
  red_cells(): ∪ telegraph + queued của mọi agent + trait warnings   (F2 chung)
  last_warning_at / note_warning(t)                                    (F5 chung)
CombatView
  _agents: Array[EnemyAgent]; get_boss() = _agents[0].controller (giữ API); get_pattern_controller() = unit 0
  _ready: units từ match_params.enemies (CombatState.from_match_params); một FieldDrops chung; mỗi unit 1 agent
  _process: drops.tick 1 lần; for a in _agents (index order): a.tick(step, _cut_actor); _arbiter.tick
  _tick_end: all_required_dead() (thay is_enemy_dead())
SwingArbiter
  _actors: key -> CutActor (0 = player, 1 + i = unit i); một actor enemy resolve → target PLAYER, attacker key k
  interrupt: hit unit k → huỷ actor k (Phase 2 chỉ unit 0 → mở rộng cho mọi unit có actor)
```

### 1.4 File cần sửa và chủ sở hữu

| File | Thay đổi | Chủ |
|---|---|---|
| `src/combat/enemy_agent.gd`, `threat_board.gd` (mới) | agent + bảng đe doạ | multi-enemy |
| `src/combat/combat_view.gd` | dựng N agent, drops chung, `_process`, `_tick_end`, wiring marker / blocker / allies_fn / mire_immune theo unit | multi-enemy (bàn giao 13/11) |
| `src/combat/swing_arbiter.gd` | `_actors` theo key, interrupt theo unit, attacker key cho parry | multi-enemy |
| `src/combat/boss_controller.gd` | tham số `key`, drops tiêm vào, nhặt khối theo unit, cổng thẻ ở `_do_cut`, `cell_of(key)` | sạch |
| `src/combat/boss_brain.gd` | `my_cell` / footprint theo key, `extra_own_blocked_fn` + ô unit khác, think interval từ config riêng | sạch |
| `src/combat/unit_mover.gd` | `cell_of(key)` / `cells_at_key` / `set_key_cell`; pin / root theo key (sổ status đã theo key) | sạch |
| `src/combat/boss_learning.gd` | sổ swing theo key (D2 + A1) | sạch |
| `src/combat/boss_brain_config.gd` | không đổi (mỗi unit tải bản mới bằng `load_from_file`); chỉ thêm `copy()` nếu cần tránh đọc file N lần | sạch |
| `src/combat/parry_guard.gd` | phản đòn / ghim **unit tấn công** (`attacker_key`) | sạch |
| `src/combat/pattern_controller.gd` | tham số `key`; 25 chỗ đọc / ghi unit 0 → unit của nó (footprint, ô, sàn HP, bất tử, guard, hồi máu, `unit_in`), F5 + cổng thẻ qua `ThreatBoard`, `on_enemy_hit()` cho đúng unit | **monster-skills — CHỜ BÀN GIAO** |
| `src/run/run_config.gd`, `src/run/formation_rules.gd` | khối `ai` per entry (§1.2) | multi-enemy |
| `src/combat/pattern_brain.gd`, `pattern_planner.gd`, `fairness_check.gd`, `cut_actor.gd` | không đổi (thuần / theo ctx) — `pattern_brain.gd` đang M bởi monster-skills, Phase 3 **không** cần sửa | — |

### 1.5 Thứ tự làm (một lượt, sau bàn giao)

0. Kiểm tra bàn giao: diff cuối `pattern_controller.gd` (chỉ thêm bản vá 3 dòng), báo cáo test của monster-skills, note bàn giao; chạy lại baseline (không Godot song song).
1. Dữ liệu: khối `ai` per entry (§1.2) + test.
2. `ThreatBoard` + `EnemyAgent` (thuần, test riêng).
3. `UnitMover`, `BossBrain`, `BossController`, `BossLearning`, `ParryGuard` nhận key (unit 0 / key 1 = như cũ).
4. `PatternController` nhận key + F5 / thẻ qua `ThreatBoard`.
5. `SwingArbiter` N actor.
6. `CombatView` dựng N agent, drops chung, `_tick_end`.
7. Test (§1.6), hồi quy, full suite.

### 1.6 Test bắt buộc (`tests/unit/combat/multi_enemy_agents_test.gd`, `threat_board_test.gd`, …)

1 unit (byte-for-byte: log quyết định / seed giống trước) · **A1:** hai swing chồng (attack_slots 2) không ghi đè sổ của
nhau, dodge của từng swing được tính; attack_slots 1 = chuỗi sự kiện learning y như trước · **A2:** khối `ai` có đủ khoá
cho mọi entry, unit 0 = các khoá của match, unit 1+ = template scale; hai unit cùng template có hai `BossBrainConfig` khác
object, sửa của một unit (vd. `boss_phases.use_set`) không lọt sang unit kia; template / `chapters.json` không đổi sau
khi dựng trận · **A3:** hit unit k chỉ huỷ actor k, chỉ `PatternController` k nhận `on_enemy_hit`; hit đồng thời 2 unit
ngắt đúng 2 actor; unit không actor không gây ngắt nhầm · **D3:** N = 1, 2, 4 → interval = base, base·√2, base·2 (kẹp
0.05–1.0) · **D4:** drops tick đúng một lần / khung với N controller · **D5:** chỉ unit bước lên khối mới nhặt · 2 unit · 3–4 unit · nhiều block brain · nhiều pattern brain ·
trộn block + pattern · tranh thẻ (`attack_slots` 1 và 2: không bao giờ quá số thẻ ở WINDUP / WARNING) · F2 chung (tổng
ô đỏ ≤ 0.5) · F5 chung (khoảng cách ≥ 0.4 s) · learning chung (dodge streak đúng khi 2 swing chồng) · HP / guard / bất tử /
footprint / ô độc lập (hai `PatternController` không ghi chéo) · unit 0 chết khi unit khác còn sống (trận chạy tiếp) ·
kết thúc đúng khi `all_required_dead()` · determinism (cùng seed → cùng log) · hồi quy Phase 2 (`multi_enemy_resolver_test`,
`combat_state_units_test`, `boss_footprint`, `state_damaged_signal`, `boss_downed`, `pattern_*`, `forest_witch_*`).

### 1.7 Phụ thuộc chưa giải quyết

| Phụ thuộc | Trạng thái |
|---|---|
| Bàn giao `pattern_controller.gd` | đang chờ (monster-skills chạy full suite) |
| D2 mở rộng `BossLearning` theo key | **đã duyệt (A1)** |
| §1.2 khối `ai` per entry (mở rộng schema) | **đã duyệt (A2)** |
| Interrupt cho mọi unit có actor (mở rộng quyết định Phase 2 #5) | **đã duyệt (A3)** |
| HUD / UnitLayer chưa vẽ unit 1+ → test Phase 3 chỉ headless; ảnh chụp là Phase 4 | đã biết |

---

## 2. Phase 4 — HUD và bằng chứng hình ảnh (preflight 13/11/2026 — chưa code)

### 2.1 Phạm vi

Chip trạng thái (Rạn / Hàn / Guard / mark / poison) cho unit 1+; số damage / heal / phản ứng cho unit 1+; định tuyến
phản hồi theo **unit key** (Phase 2 đã phát key trên `pinned`, `trap_fired`, `reaction_fired`, `mire_damage`,
`burn_hurt`, và `CombatState.unit_damaged / unit_healed / unit_died / unit_cell_changed`); sprite / placeholder / HP plate
cho mỗi unit; telegraph gộp của N agent; không phản hồi trùng / gán nhầm.

> **Đổi hướng audio (người dùng, 13/11/2026).** Audio **không** còn theo unit. Cả game dùng một bản sắc âm
> thanh chung, không có bộ âm riêng cho từng quái / unit / index. Chi tiết và bộ âm tối thiểu:
> `docs/design/audio/unified-audio-identity.md`. Phần audio của Phase 4 thu lại còn ba việc nhỏ trong
> `src/audio/` (nối `unit_damaged` vào `combat.hit.enemy`; một tag cảnh báo chung có đếm tham chiếu; bỏ đường
> phát `warn.boss.windup` trùng) và **không** thêm file âm thanh. Mọi mục HUD / telegraph ở trên giữ nguyên.

### 2.2 Ma trận quyền sở hữu (git 13/11/2026, HEAD `dae2794`)

| File | Phase 4 chạm gì | Chủ | Sửa được ngay? | Bàn giao |
|---|---|---|---|---|
| `src/battle/unit_layer.gd` | `SIDES` (:160) mở thành N key; `_draw` (:1104-1141) sắp sâu N+1 thân; `unit_ids_for` (:691); `_invuln_time` (:204) thành dict; `clip_context` (:524) lấy controller theo key | sạch (vừa commit `dae2794` bởi phiên character-animation-feel, đang idle) | **Có** | không |
| `src/combat/cut_hud_view.gd` | HP plate (:2275) 2 → N; vòng chip chỉ-ENEMY (:2235); `_unit_feet_screen` (:2297) — **mỏ neo màn hình duy nhất**; `_draw_boss_feedback` (:2041); heal boss neo vào `enemy_cell` (:2819); dot pop theo side (:845) | sạch | **Có** | không |
| `src/battle/floor_layer.gd` | `telegraph_state` (:140) và `pattern_extras` (:209) trả **một** dict phẳng → phải thành danh sách theo agent; Guard đọc cứng `Side.ENEMY` (:190) | sạch (phiên region-visual đã commit xong) | **Có** | không |
| `src/battle/floor_dynamic_layer.gd` | diff telegraph theo giá trị (:266) sẽ **nhấp nháy** nếu nguồn luân phiên; root seal chỉ unit 0 (:118-122); mark theo side (:232-242) | sạch | **Có** | không |
| `src/battle/overlay_layer.gd` | `_side_items` đúng 2 lượt (:350); `cast_travel_now(side)` (:721) nên chỉ một đòn địch chạy được; đạn địch neo vào chân unit 0 (:750) | sạch | **Có** | không |
| `src/battle/pickup_layer.gd` | chỉ `_sources()` (:199-207) | sạch | **Có** | không |
| `src/battle/support_layer.gd` | **không có gì** — thuần hình học sân | sạch | — | không |
| `src/drops/field_drops_view.gd` | `@export boss_side: bool` (:69) — một bool nên chỉ tồn tại 2 node | sạch | **Có** | không |
| `src/run/run_hud_view.gd` | `boss_swing_line()` (:894) một dòng cho một boss | sạch | **Có** | không |
| `src/ui/status_row.gd` | **không cần sửa** — đã dùng lại được cho N unit; chỉ *caller* trong `cut_hud_view` buộc nó vào một phe | **monster-skills** (`M`) | Không cần | **Không cần bàn giao** nếu Phase 4 chỉ gọi, không sửa |
| `src/combat/combat_view.gd` | `_boss_feedback` → bản ghi theo key; mở getter cho N unit; `_interrupt_flash` một dict | multi-enemy (`M`) | **Có** | không |
| `src/audio/combat_audio_bridge.gd` | 3 việc ở §2.5 | **stream C** | **Không** | **Bắt buộc** |
| `src/audio/audio_event_rules.gd` | tag cảnh báo chung + đếm tham chiếu | **stream C** | **Không** | **Bắt buộc** |
| `assets/data/audio_events.json` | nối 6 event, xoá 2 | **stream C** | **Không** | **Bắt buộc** |
| `src/dev/demo_args.gd` | thêm demo 2 và 3 quái (§2.4) | sạch | **Có** | không |

**Kết luận ownership:** mọi file HUD / telegraph / presentation đều **sạch và sửa được ngay**.
Chỉ ba file audio bị chặn. `status_row.gd` hoá ra **không phải blocker**: nó đã thuần static
và dùng lại được cho N unit, Phase 4 chỉ cần gọi nó từ một mỏ neo khác.

### 2.3 Thứ tự triển khai (theo phụ thuộc)

| # | Bước | Phụ thuộc | Vì sao thứ tự này |
|---|---|---|---|
| 1 | **Mỏ neo N unit**: `UnitLayer.SIDES` mở theo key, `_draw` sắp sâu N+1 thân, `CutHudView._unit_feet_screen` nhận key | — | Mọi thứ khác neo vào đây. Không làm trước thì plate, chip và số damage đều chồng lên unit 0 |
| 2 | **Sprite / placeholder + HP plate mỗi unit** | 1 | Unit 1+ hiện đang **vô hình**; đây là bước đầu tiên nhìn thấy được |
| 3 | **Chip trạng thái mỗi unit** (Rạn / Hàn / Guard / mark / poison) | 1, 2 | Chip treo dưới HP plate nên cần plate trước. Gọi `status_row.gd`, không sửa nó |
| 4 | **Số damage / heal / phản ứng mỗi unit** | 1 | `_boss_feedback` một dict → bản ghi theo key; đổi 4 handler từ `side` sang key |
| 5 | **Telegraph gộp N agent** | — (song song được với 2–4) | `telegraph_state` thành danh sách; phải xử lý nhấp nháy do diff theo giá trị |
| 6 | **Audio** (3 việc §2.5) | bàn giao stream C | Độc lập hoàn toàn với 1–5 |
| 7 | **QA hình ảnh 2 và 3 quái** (§2.4) | 2–5 xong, Godot rảnh | Bằng chứng bắt buộc để đóng story |

Bước 5 và 6 chạy song song được với 2–4 vì không chung file.

### 2.4 QA hình ảnh — cách dựng trận 2 và 3 quái

**Vấn đề:** `assets/data/chapters.json` hiện **không có formation nào** (đã kiểm: 0 khối `formations`).
Không được thêm formation vào dữ liệu sản phẩm chỉ để test.

Hai đường an toàn, cả hai đều không đụng dữ liệu sản phẩm:

**(a) Test headless dựng cả view** — cho test tự động.
`tests/unit/battle/unit_sprites_test.gd` đã có khuôn: nạp `res://src/main.tscn`, `flow.enter_test_floor(RunConfig.from_dictionary(data))`
với `data` đọc từ `tests/fixtures/fast_run.json`, rồi lấy `battle.get_node("CombatView")` và `canvas.get_unit_layer()`.
Phase 4 thêm `tests/fixtures/multi_enemy_run.json` với khối `enemies` trong match — **fixture, không phải dữ liệu sản phẩm**.

**(b) Demo dev cho ảnh chụp** — cho bằng chứng hình ảnh.
`src/dev/demo_args.gd` ghi thẳng vào `_combat().match_params` trước `_ready`. Thêm hai mode:

| Mode | Dựng gì |
|---|---|
| `--demo=multi_two` | 2 unit: một block, một pattern `dev_pattern_dummy` |
| `--demo=multi_three` | 3 unit: block + `dev_pattern_dummy` + `dev_pattern_boss` 2×2 trên `boss_hall` |

Cách dựng entry (giống hệt helper của `multi_enemy_agents_test.gd`, nên không phát minh gì mới):

```gdscript
var raw := {"id": "demo", "boss_max_hp": 80.0, "arena": {"shape": "boss_hall"},
    "enemies": [block_entry, pattern_entry], "attack_slots": 1}
match_params = RunConfig.clean_match(raw, 0)   # resolve xong: ai, footprint, defense
```

`clean_match` tự thêm khối `ai`, `footprint`, `defense` cho từng entry, nên demo không phải tự viết.
`dev_pattern_dummy` và `dev_pattern_boss` **đã có sẵn** trong `assets/data/enemy_skills.json` (mục dev),
nên không cần thêm nội dung mới.

**Lệnh chụp** (windowed, luôn tắt tiếng theo yêu cầu người dùng):

```
godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -- \
  --demo=multi_two --shot=production/qa/evidence/multi-enemy/01-two-units.png --shot-frame=120
```

`--shot=` lưu ảnh viewport sau `--shot-frame=N` khung rồi thoát. Ảnh phải **ở lại trên đĩa** trong
`production/qa/evidence/multi-enemy/` (coding-standards: ảnh chụp rồi xoá không phải bằng chứng).

Bộ ảnh tối thiểu: 2 unit đứng yên; 2 unit cùng cảnh báo (kiểm telegraph gộp); 3 unit có plate và chip;
một unit chết còn unit kia sống (kiểm plate biến mất đúng cái).

### 2.5 Danh sách audio (nguồn chân lý: `docs/design/audio/unified-audio-identity.md`)

**Ba thay đổi hành vi**, không thêm file âm thanh:

| # | Việc | File |
|---|---|---|
| A | Nối `CombatState.unit_damaged` vào **chính** `combat.hit.enemy` (cooldown 60 ms tự gộp nhiều unit thành một tiếng) | `combat_audio_bridge.gd` |
| B | Một tag cảnh báo chung + **đếm tham chiếu**, để một unit hết cảnh báo không tắt chuông của unit còn lại | `audio_event_rules.gd` |
| C | Bỏ đường phát `warn.boss.windup` trùng (hiện chỉ nhờ cooldown 150 ms che) | `combat_audio_bridge.gd` |

**Nối 6 event** đã có file, đang không ai gọi: `combat.crit`, `block.invalid`, `warn.terrain.vent`,
`combat.death`, `combat.lock`, `warn.boss.recovery`.

**Chỉ xoá 2 event**: `block.confirm`, `block.slot_full`.

**Giữ nguyên, không được đụng:**

- 6 event tắt có chủ ý và bị test khoá: `skill.hoa_loi.charge / prime / seal / tick`,
  `skill.ngan_kiem.charge / commit`. `audio_event_rules_test` khẳng định chúng *không* kêu.
- 3 event gọi được qua bảng `cues`: `card.highlight`, `card.unavailable`, `card.ready`.
- Cả ba bộ âm riêng của Trảm Địa, Ngàn Kiếm, Hoả Lôi.
- Nguyên tắc phát chung ở §3 của tài liệu bản sắc: pitch ±1.5 nửa cung, gộp theo cooldown, trần voice, duck.

**Không làm:** định tuyến theo unit key, pan theo vị trí, bộ âm riêng cho quái, tag `body:` tách theo unit.

### 2.5b Tiến độ bước 1–5 (2026-11-13, người dùng duyệt triển khai)

**Trạng thái: code xong, CHƯA CHẠY TEST** (Godot do phiên monster-skills giữ cho sim nhóm E).

| Bước | Làm gì | File |
|---|---|---|
| 1 | `UnitLayer.SIDES` → `unit_keys()` động (`state.all_keys()`); mọi bảng theo phe thành bảng theo key; `_invuln_time` thành dict một đồng hồ chớp mỗi unit; `_extent_of(key)` tự đo từ ô của unit (không đụng `CombatState`); `_cell_of` / `_unit_art_rect` / `_feet_of_unit` / `_status_cell` / `_is_alive` nhận key; `_mover_of` và `clip_context` lấy controller + pattern của **chính unit đó**; `unit_ids_for` trả một sprite id mỗi unit | `unit_layer.gd`, `combat_view.gd` (`pattern_of`) |
| 2 | Một HP plate mỗi unit **sống**, neo vào chân chính nó (`hp_of(key)`) | `cut_hud_view.gd` |
| 3 | Một hàng chip mỗi unit, dưới plate của nó; `get_burn_stacks(key)` chỉ đếm lửa trên ô của unit đó | `cut_hud_view.gd`, `combat_view.gd` |
| 4 | Một nhát chém trúng 2 unit → **2 số, 2 ô** (tách `unit_results`, bản ghi phụ `number_only`); hai unit cùng đánh người chơi → **2 marker** (`_boss_feedback_extra`); số hồi máu theo `unit_healed(index)` nổi trên ô của unit được hồi | `combat_view.gd`, `cut_hud_view.gd` |
| 5 | `telegraph_states()` / `extra_telegraph_states()` / `pattern_extras_list()`; `paint_dynamic` vẽ mọi unit; lớp động so sánh cả danh sách (hết nhấp nháy); dấu chân khoá (root seal) và Dấu Tử theo từng unit | `floor_layer.gd`, `floor_dynamic_layer.gd`, `combat_view.gd` (`is_step_locked_of`) |

**Định tuyến sự kiện:** phe người chơi giữ tín hiệu cũ (`damaged`, `cell_changed`); **mọi** unit địch đi qua tín hiệu
theo chỉ số (`unit_damaged`, `unit_cell_changed`, `unit_healed`). Handler cũ chặn nhánh địch, nên unit 0 **không bị
xử lý hai lần**. Phản hồi phản ứng (`reaction_fired`, `burn_hurt`, `thorn_entered`, `mire_damage`) từ Phase 2 đã mang
key sẵn, nên chỉ cần mỏ neo theo key là tự về đúng unit.

**Chưa làm, ngoài phạm vi bước 1–5** (không tự mở rộng): `overlay_layer.cast_travel_now(side)` vẫn chỉ cho một đòn
bay của phe địch; `run_hud_view.boss_swing_line()` vẫn một dòng cho một boss. `pickup_layer` và `field_drops_view`
**không cần sửa**: Phase 3 (D4) đã dùng **một** FieldDrops chung cho cả phe địch.

**QA đã dựng sẵn, chưa chạy:** fixture `tests/fixtures/multi_enemy_run.json` (2 và 3 unit, không đụng dữ liệu sản
phẩm); demo `--demo=multi_two` / `--demo=multi_three` trong `demo_args.gd`, dựng formation qua chính
`RunConfig.clean_match`; test `tests/unit/battle/multi_enemy_hud_test.gd`.

### 2.6 Blocker

| Blocker | Chặn bước | Trạng thái |
|---|---|---|
| Bàn giao `src/audio/*` từ stream C | bước 6 | **Đã nhắn 13/11, chưa có trả lời** |
| Godot do phiên monster-skills giữ (sim nhóm E, ~2 h) | bước 7 | Đang chạy; chờ họ nhắn "group E done" |
| Chưa có formation trong `chapters.json` | QA sản phẩm thật | **Không chặn Phase 4** — §2.4 đi đường demo / fixture. Đưa formation vào chapter là việc của World Map, không phải Phase 4 |

Bước 1–5 **không bị chặn gì cả** và bắt đầu được ngay khi người dùng duyệt.

### 2.7 Test / bằng chứng

Test headless: số plate = số unit sống; chip unit 1 không hiện ở unit 0; một hit vào 2 unit → 2 số damage, đúng ô;
`unit_damaged(1)` → clip `hit` của unit 1, không phải unit 0; hai agent cùng cảnh báo → telegraph gộp, không nhấp nháy
giữa hai khung.
Audio (hướng mới): hai unit trúng đòn trong cùng một tick → **một** tiếng `combat.hit.enemy` (cooldown gộp), không
phải hai; hai unit cùng cảnh báo rồi một unit hết cảnh báo → chuông vẫn kêu cho unit còn lại; không có cue nào
mang key của unit.
Bằng chứng bắt buộc (coding-standards, UI / Visual): ảnh chụp windowed `--audio-driver Dummy` trong
`production/qa/evidence/multi-enemy/` cho trận 2 và 3 unit (block, pattern, 2×2 + quái phụ trên `boss_hall`).

---

## 3. Phase 5 — Trait theo unit (thiết kế, 2026-11-13; chưa code)

Dựa trên một lượt kiểm kê toàn bộ `src/traits/` (25 script) và mọi nơi tiêu thụ hook của TraitHost.
**Chưa duyệt triển khai.**

### 3.0 Hiện trạng: vì sao Phase 5 khó hơn Phase 3 và 4

Phase 3 và 4 nhân bản những thứ **vốn đã theo unit** (controller, brain, mover, sprite, plate). Trait thì khác:
rất nhiều trait **không** thuộc về một con quái, mà là thuộc tính của **đấu trường**. Nhân bản mù sẽ hỏng.

| Số liệu | Giá trị |
|---|---|
| Script trong `src/traits/` | 25 (22 trait + registry + host + lớp cơ sở) |
| TraitHost trong một trận | **1** (dựng ở `combat_view.gd:546`, trước `_setup_extra_units`) |
| Unit 1+ có trait | **không có trait nào** — `_setup_extra_units` không dựng host, không truyền spec |
| Callable toàn cục TraitHost cài lên hệ khác | 5 |
| Slot `extra_*_fn` CombatView gán, đều trỏ pattern của unit 0 | 3 |
| Nơi HUD gọi `host.get_trait(id)` (chỉ trả **cái đầu tiên**) | 16 |

`ctx` (`combat_view.gd:1286-1295`) **không có khoá unit nào cả**. Ba khoá `boss`, `boss_drops`, `pattern_getter`
đều buộc cứng vào unit 0.

### 3.1 Phân loại trait — trục chính của thiết kế

**PER-UNIT (hiệu ứng thuộc về một con quái) — 11:** `burrow`, `rebirth`, `shroud`, `burn_eater`, `step_reactor`,
`fuse_cannon`, `riposte`, `spore_burst`, `hop_skip`, `phase_shift`, `boss_phases`.

**SHARED (hiệu ứng là thuộc tính của sân / trận) — 11:** `row_burner`, `slam`, `seal_caster`, `thorn_field`,
`bog_spread`, `sandstorm`, `vent_surge`, `gust`, `island_drop`, `frost_aura`, `rotten_thrower`.

Phần lớn nhóm SHARED **ghi vào nửa sân của người chơi** hoặc vào một đại lượng toàn cục. Chúng không nên được
nhân bản; chúng cần được **giới hạn một bản** cho mỗi trận.

### 3.2 Bảy mối nguy đã xác định (có bằng chứng)

| # | Nguy | Ví dụ |
|---|---|---|
| H1 | **Đại lượng toàn cục bị ghi đè** — lưu/khôi phục một giá trị duy nhất | `sandstorm` đặt `set_drift_mult` rồi trả về 1.0: bão thứ nhất **kết thúc** sẽ tắt gió của bão thứ hai đang thổi. `frost_aura` với `interval_scale` y hệt |
| H2 | **Bí danh unit 0** | `boss_phases` ghi `state.enemy_hp_floor` và `enemy_invulnerable_left` — là bí danh của `units[0]`. `boss_phases` trên unit 2 sẽ làm **unit 0** bất tử |
| H3 | **Slot đơn không nối chuỗi** | `slam` gán `player_mover.blocked_cell_fn`: slam thứ hai ghi đè, vết nứt của slam thứ nhất hết chặn |
| H4 | **Banner trùng** | `phase_shift`, `boss_phases` và `_apply_pattern_phase` đều gọi `announce_phase`; HUD lấy trait **đầu tiên** nên tên pha có thể lấy từ nhầm quái |
| H5 | **Kích hoạt sai chủ** | `riposte` phản đòn mọi cú chém trúng **bất kỳ** unit nào; `hop_skip` đếm bước của **mọi** quái; `spore_burst` đọc `unit0_damage` |
| H6 | **Hook OR không phân biệt** | `burrow` của unit 2 chui xuống làm **unit 0** không nhắm được, vì `enemy_untargetable_fn` chỉ đọc cho key unit 0 |
| H7 | **Vòng đời** | Tick trait bị chặn bởi `is_enemy_dead()` — **unit 0 chết là mọi trait của mọi unit đứng hình**; không có hook `on_unit_died`; không trait nào dọn dẹp khi chủ của nó chết |

### 3.3 Thiết kế đề xuất (chờ duyệt)

**D1 — Một TraitHost mỗi unit, cộng một sổ tra cứu.** Mỗi unit có host riêng với `ctx` của chính nó.
CombatView giữ `_hosts_by_key`. Vì HUD gọi `get_trait(id)` ở 16 chỗ và chỉ lấy cái đầu tiên, CombatView mở
`trait_of(id, key)` và `any_trait(id)`; HUD đổi sang chúng. **Không** giữ một host chung với nhãn key: 5 hook
toàn cục và `get_trait` sẽ vẫn mơ hồ.

**D2 — `ctx` mang khoá.** Thêm `key`; `boss` → controller của unit đó; `boss_drops` → drops của phe (vẫn chung,
D4 của Phase 3); `pattern_getter` → pattern của chính unit đó. Đây là thay đổi nhỏ nhất xoá được H5 và H6 tận gốc.

**D3 — 5 hook toàn cục thành theo key.** `enemy_death_hook_fn` đã có sẵn chỗ theo unit (`units[i].death_hook_fn`),
chỉ bí danh là buộc vào unit 0. `enemy_untargetable_fn` và `reaction_immune_fn` nhận key. `burn_heal_ratio_fn`
nhận key. `forecast_blocked_fn` **không thể** theo unit (chỉ có một ô xem trước) — giữ OR, và ghi rõ trong code
rằng đó là quyết định có ý thức, không phải sót.

**D4 — Trait SHARED giới hạn một bản mỗi trận.** Kiểm ở `FormationRules` lúc nạp formation: formation nào có hai
unit cùng mang một trait SHARED thì **bị loại kèm cảnh báo**, như cách Phase 0 đã loại formation sai. Rẻ hơn nhiều
so với đếm tham chiếu 11 trait.

**D5 — Vòng đời theo unit.** Thêm `BossTrait.on_unit_died(key)`; `_on_unit_died` gọi `teardown()` cho mọi trait của
unit đó và gỡ hook của nó. Bỏ điều kiện `is_enemy_dead()` ở chỗ tick, thay bằng: tick host của những unit **còn
sống**. Đây cũng là bản sửa cho một lỗi **đang tồn tại ở trận 1v1 nhiều quái sau này**: hiện unit 0 chết là trait
đứng hình.

**D6 — Quy gán đúng chủ.** `riposte` đọc `result["unit_keys_hit"]` (đã có sẵn từ Phase 2); `on_boss_damaged` nhận
key và lượng sát thương của chính unit đó; `hop_skip` lọc `unit_cell_changed` theo key của mình.

**D7 — Banner.** Chỉ unit 0 được `announce_phase`, hoặc banner mang tên quái. Đề xuất: **chỉ unit 0**, vì banner
pha là ngôn ngữ của trận đấu boss một mình. Quyết định thiết kế, cần người dùng chốt.

### 3.4 Thứ tự triển khai

| # | Bước | Vì sao trước |
|---|---|---|
| 1 | `ctx` mang key + `_hosts_by_key` + tick theo unit sống (D1, D2, D5) | Mọi bước sau neo vào đây |
| 2 | 5 hook theo key (D3) | Xoá H6, H2 ở mức hạ tầng |
| 3 | Sửa quy gán của 6 trait PER-UNIT (D6) | Phụ thuộc bước 1 |
| 4 | Chặn trait SHARED trùng ở FormationRules (D4) | Độc lập, làm song song được |
| 5 | Banner (D7) | Sau khi chốt thiết kế |
| 6 | HUD đổi sang `any_trait` / `trait_of` | Sau bước 1 |

### 3.5 Quyền sở hữu và blocker

| File | Chủ | Ghi chú |
|---|---|---|
| `trait_host.gd`, `boss_trait.gd`, `burrow.gd`, `rebirth.gd`, `shroud.gd` | **monster-skills** | Toàn bộ thay đổi đang có là Phase 0 (G3/G6) của họ. **Cần bàn giao cả 5** |
| 20 file trait còn lại | sạch | — |
| `combat_view.gd` | multi-enemy (đang cho phiên character mượn) | Cần lấy lại |
| `swing_arbiter.gd`, `status_effects.gd`, `combat_state.gd` | multi-enemy | — |
| `placement_controller.gd` | sạch | Một dòng cho D3 |
| `cut_hud_view.gd` | multi-enemy | 16 chỗ gọi `get_trait` |

**Blocker:** (1) bàn giao 5 file trait từ monster-skills; (2) `combat_view.gd` đang ở phiên character;
(3) Phase 0 + multi-enemy phải commit xong trước, nếu không Phase 5 lại chồng lên một đống chưa commit nữa.

### 3.6 Test bắt buộc

Theo đúng các mối nguy, mỗi test gắn với một H:
H1 hai `sandstorm`, một cái hết hạn → gió của cái kia còn nguyên. H2 `boss_phases` trên unit 2 → unit 0 **không**
bất tử. H3 hai `slam` → vết nứt của cả hai còn chặn. H5 `riposte` của unit 2 **không** nổ khi người chơi chỉ trúng
unit 1. H6 `burrow` của unit 2 chui xuống → unit 0 **vẫn** nhắm được. H7 unit 0 chết → trait của unit 2 **vẫn**
tick; unit 2 chết → trait của nó ngừng tick, hook được gỡ, đại lượng toàn cục được khôi phục.
Hồi quy: `region_traits_test`, `trait_test`, `traits2_test`, `zone_traits_test`, `boss_downed_test`,
`final_boss_phase_test`, `multi_enemy_agents_test`, `multi_enemy_hud_test`.
Bằng chứng hình ảnh: một trận 2 quái trong đó mỗi con mang một trait PER-UNIT khác nhau.

### 3.7 Quyết định đã chốt (người dùng, 2026-11-14: "theo khuyến nghị")

| # | Quyết định | Chốt |
|---|---|---|
| D4 | Trait SHARED trùng trong một formation | **Loại formation đó kèm cảnh báo**, như Phase 0 đã loại formation sai. Không đếm tham chiếu 11 trait |
| D7 | Banner đổi pha khi có nhiều quái | **Chỉ unit 0 được `announce_phase`.** Banner pha là ngôn ngữ của trận boss một mình; hai banner cùng số là nhiễu |
| Phạm vi | Làm tới đâu rồi dừng | **Bước 1–3 rồi dừng xem lại** (hạ tầng + hook theo key + quy gán đúng chủ). Bước 4–6 là lượt duyệt riêng |

Lý do chọn bước 1–3: đó là phần xoá được 5 trong 7 mối nguy ở §3.2 (H2, H5, H6, H7, và H1 ở mức hạ tầng), và là
phần **không đổi hành vi nào của trận 1v1**. Bước 4 (chặn formation) đổi dữ liệu nào hợp lệ, bước 5 (banner) đổi
thứ người chơi nhìn thấy, bước 6 (HUD) đổi 16 chỗ gọi — cả ba đều đáng được xem lại riêng.

### 3.8 Chưa bắt đầu — điều kiện khởi động

1. Commit chung phải lên main trước. Phase 5 đụng đúng những file đang chờ trong đó; bắt đầu sớm là tạo thêm một
   lớp chồng chưa commit nữa, đúng cái đã làm tối nay mất nhiều giờ.
2. Bàn giao 5 file trait từ monster-skills (`trait_host.gd`, `boss_trait.gd`, `burrow.gd`, `rebirth.gd`,
   `shroud.gd`). Mọi thay đổi đang có trong chúng là Phase 0 của họ.
3. `combat_view.gd` rảnh (phiên character commit F2 xong).

---

## 4. Tóm tắt phụ thuộc theo phase

| Phase | Chặn bởi |
|---|---|
| 3 | **XONG — đã duyệt 13/11/2026** (§6) |
| 4 | Bước 1–5 **không bị chặn**. Bước 6 (audio) chờ bàn giao `src/audio/*` từ stream C; bước 7 (ảnh chụp) chờ Godot rảnh. `status_row.gd` **không** còn là blocker — xem §2.2 |
| 5 | Phase 4 duyệt; bàn giao `boss_trait.gd`, `burrow.gd`, `rebirth.gd`, `shroud.gd` |


---

## 5. Kiểm tra quyền sở hữu (2026-11-13, sau khi duyệt A1–A3)

| File Phase 3 | git | Chủ |
|---|---|---|
| `combat_view.gd`, `swing_arbiter.gd`, `run_config.gd`, `chapters_config.gd`, `formation_rules.gd` (+ `enemy_agent.gd`, `threat_board.gd` mới) | M / ?? | multi-enemy |
| `boss_controller.gd`, `boss_brain.gd`, `boss_brain_config.gd`, `unit_mover.gd`, `boss_learning.gd`, `parry_guard.gd`, `field_drops.gd`, `cut_actor.gd` | sạch | — |
| `pattern_controller.gd` | M | **monster-skills — chưa bàn giao** (note của họ vẫn ghi "NOT touched by multi-enemy"; họ đang chạy full suite sau bản vá `on_enter`) |
| `pattern_brain.gd` | M | monster-skills — Phase 3 **không** cần sửa |

Phase 3 vẫn bị chặn tới khi bàn giao `pattern_controller.gd` được xác nhận. Không sửa code, không chạy Godot (một
tiến trình Godot của session khác đang chạy lúc kiểm tra).

### 5.1 Trình tự khi nhận bàn giao (chỉ thị người dùng, 2026-11-13)

1. Kiểm tra diff cuối của `pattern_controller.gd`, `pattern_brain.gd` và các file liên quan.
2. Đối chiếu kết quả test thực tế của monster-skills: tách riêng pass / fail / timeout.
3. Xác nhận không còn tiến trình Godot nào đang chạy.
4. Ghi baseline mới và bảng ownership mới.
5. Sau đó mới bắt đầu Phase 3 theo plan đã duyệt (§1.1b, §1.5).

### 5.2 Bàn giao nhận (2026-11-13 ~13:55) và baseline Phase 3

- **Bàn giao:** `pattern_controller.gd` thuộc multi-enemy (tin nhắn + note monster-skills "HAND-OVER: src/combat/pattern_controller.gd").
- **Diff đã kiểm:** `pattern_controller.gd` +403 / −11 so với HEAD = Phase 0 của monster-skills + bản vá `on_enter` (trong
  `_try_choose`: skill hàng đợi on_enter được truyền làm `forced`, nhánh `every_nth` thành `elif`). `pattern_brain.gd`
  (+14) và `enemy_skills_config.gd` (+113) vẫn của monster-skills, Phase 3 không sửa.
- **Test của họ (đã đối chiếu log):** `production/qa/monster-skill-onenter-fix-2026-11-13.txt` 19 / 19 FAILS=0;
  `production/qa/monster-skill-onenter-fix-full-suite-2026-11-13.txt` 302 suite: 301 sạch, `pattern_roster_fairness_test`
  **timeout** ở runner (240 s), chạy riêng FAILS=0, 0 script error, 267 s.
- **Godot:** không còn tiến trình nào; không file `src` / `tests` / data nào đổi sau 13:51 → lượt full suite đó là
  **baseline Phase 3: 301 / 302 + 1 timeout (xanh khi chạy riêng)**.
- **Ownership Phase 3:** multi-enemy: `combat_view`, `swing_arbiter`, `pattern_controller`, `status_effects`, `trait_host`,
  `combat_state`, `cut_effects`, `tile_hazards`, `zone_rules`, `crit_rules`, run/config; sạch: `boss_controller`,
  `boss_brain`, `boss_brain_config`, `unit_mover`, `boss_learning`, `parry_guard`, `field_drops`, `cut_actor`;
  monster-skills (không sửa): `pattern_brain`, `enemy_skills_config`, 4 trait, `status_row`, data, test của họ.

## 6. Kết quả Phase 3 (2026-11-13) — **ĐÃ DUYỆT** (người dùng, 13/11/2026)

> Duyệt trên cơ sở bản cài đặt đã hoàn tất và kết quả hồi quy dưới đây. Các điểm **lệch thiết kế** và
> kết quả test giữ nguyên như đã ghi, **không** sửa code Phase 3 chỉ để khớp lại thiết kế ban đầu.

- **File multi-enemy sửa / thêm:** mới `src/combat/threat_board.gd`, `src/combat/enemy_agent.gd`,
  `tests/unit/combat/multi_enemy_agents_test.gd`; sửa `combat_view`, `boss_controller`, `boss_brain`, `boss_learning`,
  `unit_mover`, `parry_guard`, `pattern_controller` (gồm R11 `_zone_fires`, người dùng duyệt), `swing_arbiter`,
  `cut_effects`, `combat_state`, `enemy_unit`, `run/formation_rules`, `run/run_config`.
- **Lệch so với thiết kế:** PatternController xin token trước khi chọn skill (kể cả skill tự thân) để không mất skill
  on_enter bị ép; unit 0 sở hữu và tick FieldDrops dùng chung; `_token_held` ở BossController để controller di chuyển của
  unit pattern không nhả token PatternController đang giữ.
- **Test:** targeted lần đầu 3 FAIL (T1/T2 tranh slot, test 7 trận không kết thúc) → sửa `_token_held` + test đặt
  `end_delay_sec = 0`. Regression 224 suite FAILS=0, 0 timeout (`production/qa/multi-enemy-phase3-regression-2026-11-13.txt`,
  agents 48/48). R11 chạy riêng FAILS=0 (`…-phase3-r11-…`). Full suite **305/305 FAILS=0, 0 timeout**
  (`…-phase3-suite-…`; baseline trước là 301/302 + 1 timeout).
- **Rủi ro còn lại:** HUD / audio cho unit 1+ (Phase 4); trait vẫn chỉ trên unit 0 (Phase 5); formations chưa có trong
  `chapters.json`; modifier và Kiếp vẫn chỉ áp unit 0; chưa chạy bằng mắt trận nhiều quái (không có màn nào dùng).

### 2.8 Hai bản sửa sau rà soát (2026-11-13, người dùng duyệt) — ĐÃ TEST

| Lỗi | Sửa | Tệp |
|---|---|---|
| Hiệu ứng kỹ năng của **mọi** quái pattern phát từ ô của quái 0 (Phase 3 nối thiếu key; bay ra từ xác khi quái 0 chết) | `skill_resolved` của từng unit nối kèm key của nó; `_on_pattern_skill_resolved` nhận `key` và truyền cho `_play_cut_vfx` | `combat_view.gd` |
| Sập `Invalid access to 'id'`: `_resolve_cells` đọc `_skill["id"]` ở cuối, sau khi gây sát thương / trạng thái / đẩy kéo đã có thể gọi `_end_skill` và làm rỗng `_skill` | Hai chỗ phát đọc id từ `result["skill_id"]` (điền trước mọi thứ); `_resolve_warning` thoát sớm khi `_skill` rỗng | `pattern_controller.gd` |

Lỗi thứ hai do phiên **monster-skills** phát hiện trong sim nhóm E (kiem_si, set 2001). Nhát đánh vẫn trúng và vẫn
được ghi; thứ mất là tín hiệu `skill_resolved`, tức phản hồi và hiệu ứng.

**Test hồi quy `tests/unit/combat/pattern_resolve_abort_test.gd` đã được xem FAIL trước**
(`.claude/rules/test-standards.md`: cổng chưa từng thấy fail không phải là cổng). Quy trình: hoàn nguyên bản sửa
bằng script, chạy, khôi phục từ bản sao đã kiểm checksum trong bẫy thoát.

| Lượt | Kết quả |
|---|---|
| Code chưa sửa | FAILS=1 + 2 lỗi `Invalid access`; id phát ra là **kỹ năng khác** (`dev_prick` thay vì `dev_bar`) |
| Code đã sửa | FAILS=0, 9 PASS, 0 lỗi engine |

**Lần viết test đầu sai**: nó tick 3 s nên bắt nhầm lần giải quyết của chiêu kế tiếp, và fail cả trên code đã sửa.
Đã siết: dừng ngay khi lần giải quyết bị huỷ xong, lấy mã kỹ năng tại đúng thời điểm huỷ, lọc tín hiệu theo mã đó.

**Hồi quy:** 15 suite pattern (gồm 4 nhóm Hellfire của monster-skills), `multi_enemy_agents` 48, `multi_enemy_hud` 33,
`interrupt_tell`, và 2 suite chạy chồng lúc trước (`telegraph_alpha`, `vent_crumble_view`) — tất cả FAILS=0.
Log: `production/qa/multi-enemy-phase4-fixes-2026-11-13.txt`.

### 2.9 Phase 4 bước 1–5: hoàn tất và **ĐÃ DUYỆT** (người dùng, 2026-11-13)

> Duyệt trên cơ sở full suite xanh và bằng chứng hình ảnh dưới đây. Khiếm khuyết còn lại (sprite che thanh máu) và
> hai mục ngoài phạm vi được ghi nhận, **không** chặn việc duyệt.

**Full suite: 311 suite, FAILS=0, 0 timeout, 0 lỗi script** — `production/qa/multi-enemy-phase4-suite-2026-11-13.txt`.
Lượt chạy này đã bao gồm số Hellfire ×3 mới của monster-skills và `run_flow2_test` đã sửa của phiên character, nên
cả cây test xanh tại thời điểm đó.

**Bằng chứng hình ảnh** (`production/qa/evidence/multi-enemy/`, windowed 1280×720, `--audio-driver Dummy`):

| Ảnh | Cho thấy |
|---|---|
| `01-two-units.png` | 2 quái: Rootling (sprite thật, HP 100) + goblin scout (HP 60), mỗi con một thanh máu dưới chân mình, thứ tự vẽ theo chiều sâu đúng |
| `02-three-units.png` | 3 quái: Mossbound Sentry (132) + goblin scout (60) + Ogre King 2×2 có bóng riêng (150), ba sprite khác nhau, ba thanh máu riêng |

**Lượt chụp đầu bị bỏ** vì demo đặt id tự bịa (`demo_dummy`) nên unit 1+ vẽ ô đỏ placeholder — không chứng minh được
bước 2. Demo nay dùng sheet có thật (`goblin_scout`, `ogre_king`): id quyết định **sprite**, `enemy` quyết định
**hành vi**, hai thứ độc lập.

**Ảnh KHÔNG chứng minh** (nói rõ để không ai suy sai): chip trạng thái (không unit nào mang trạng thái lúc chụp) và
telegraph (demo đóng băng thời gian). Bước 3 và 5 chỉ có bằng chứng từ test headless.

**Khiếm khuyết hình ảnh còn lại, chưa sửa:** khi một quái đứng ngay trước quái khác, sprite phía trước **che một phần
thanh máu** của quái phía sau (thấy rõ ở `01`, thanh "100" của Rootling). Đúng rủi ro mà bản rà soát độc lập đã nghi.
Nhẹ, nhưng có thật. Cần một bước tránh va cho plate nếu muốn xử lý.

**Chưa làm, ngoài phạm vi đã duyệt:** `overlay_layer.cast_travel_now(side)` vẫn chỉ hoạt hoạ một đòn bay của phe địch;
`run_hud_view.boss_swing_line()` vẫn một dòng cho một boss; Phase 5 (trait theo unit) chưa bắt đầu.

**Bàn giao:** `combat_view.gd` đã giao cho phiên character-system (4 dòng F2) lúc 23:10.
