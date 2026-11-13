# Multi-enemy Phase 1 — `CombatState` → units: audit điểm truy cập và thiết kế

**Ngày:** 2026-11-13 · **Trạng thái:** Bước 1 (audit + đề xuất) — **CHƯA code**, chờ duyệt · **Nền:** Phase 0 đã duyệt
(`MULTI-ENEMY-ENCOUNTER-AUDIT.md`, `03-encounter-system.md` §1 ghi chú 13/11) · **Nhánh:** `main` @ `2fdfe3f` + working tree.

---

## 0. Kết luận trước

| Câu hỏi | Trả lời |
|---|---|
| Phạm vi file Phase 1 | **Chỉ** `src/combat/combat_state.gd`, file mới `src/combat/enemy_unit.gd`, test mới, và (tuỳ chọn, cùng chủ) `src/run/run_config.gd` + `src/run/chapters_config.gd` để `enemies[]` mang số đã resolve. **Không** chạm `combat_view.gd`, `pattern_controller.gd`, `status_effects.gd`, `enemy_skills_config.gd`, `pattern_brain.gd`, `src/traits/*` — session "design-monster-skills" đang giữ bản sửa chưa commit của các file đó (xem §1). |
| Nguyên tắc tương thích | **Mọi API hiện có của `CombatState` giữ nguyên chữ ký và ngữ nghĩa, và trỏ vào unit 0.** API nhiều unit là hàm/signal **mới**. Không có caller nào phải sửa trong Phase 1; 81 file test dựng `CombatState.new(` và 2 test khoá ngữ nghĩa (`boss_footprint_test`, `state_damaged_signal_test`) chạy nguyên. |
| Một nguồn chân lý | HP / ô / footprint / sàn HP / bất tử / hook chết của **mỗi** unit nằm trong **một** `EnemyUnit`; các trường `enemy_*` của `CombatState` là **property proxy** (getter/setter) tới `units[0]`, không có bản sao. |
| Danh tính unit | `index` 0..3 trong `CombatState.units`; **khoá unit** `unit_key(index) = 1 + index`, nên `Side.ENEMY (=1) == unit_key(0)`: mọi dict khoá theo phe ở các lớp khác vẫn đúng cho unit 0 (chuẩn bị cho Phase 2). |
| Target / active unit | Phase 1 **không** đổi cách chọn mục tiêu: `enemy_in / is_enemy_at / unit_in(ENEMY)` vẫn chỉ hỏi unit 0 (ngữ nghĩa cũ). Thêm `enemies_in(cells) -> Array[int]`, `enemy_at(cell) -> int` để Phase 2 (`SwingArbiter`/`CutEffects`) chọn đúng unit. Không có "active unit": mọi unit sống đều là mục tiêu không gian. |
| Rủi ro ghi nhầm unit | Chặn ở nguồn: `damage_unit(i)`, `heal_unit(i)`, `set_unit_cell(i)`, `set_unit_footprint(i)` chỉ chạm `units[i]`; `damage(side)` / `damage_enemy()` cũ chỉ chạm unit 0. Test "unit 1 trúng, unit 0 nguyên" là test bắt buộc. |
| Victory | `is_enemy_dead()` **giữ** = unit 0 chết (không đổi ngữ nghĩa; `combat_view._tick_end` thuộc file session khác). Thêm `all_required_dead()` = điều kiện thắng nhiều unit; `_tick_end` chuyển sang nó ở Phase 3 khi `combat_view.gd` được sửa. |

---

## 1. Ràng buộc từ working tree (kiểm tra `git status` 13/11)

Session **design-monster-skills** đang sửa (uncommitted): `src/combat/combat_view.gd`, `enemy_skills_config.gd`,
`pattern_brain.gd`, `pattern_controller.gd`, `status_effects.gd`, `src/traits/boss_trait.gd`, `burrow.gd`, `rebirth.gd`,
`shroud.gd`, `trait_host.gd`; test mới `tests/unit/combat/pattern_phase0_*`, `status_poison_test.gd`; 2 FAIL về
`poison` trong full suite là của họ (đã ghi ở Phase 0).

Hệ quả cho Phase 1:
- `combat_state.gd` **không** bị session nào giữ → sửa được.
- Việc **nối** `CombatView._ready` để dựng N unit từ `match_params.enemies` (dòng `CombatState.new(` duy nhất trong
  `src`, `combat_view.gd:388`) **hoãn** sang Phase 3 hoặc tới khi session kia commit. Phase 1 chuẩn bị sẵn
  `CombatState.add_unit(...)` / `CombatState.from_match_params(...)` để lúc nối chỉ cần một dòng.
- Các caller đang bị giữ (`pattern_controller`, `status_effects`, trait) **ghi trực tiếp** `enemy_invulnerable_left`,
  `enemy_hp_floor`, `enemy_death_hook_fn` (bảng §2.3) → proxy **phải có setter**, không chỉ getter.

---

## 2. Audit: mọi nơi đọc / ghi `CombatState`

Nguồn: grep toàn `src/` (tests đếm riêng). `combat_state.gd` hiện 384 dòng, không có unit; 8 trường enemy vô hướng
(`:33-55`), 2 trường player, `grid`, 6 signal.

### 2.1 Tần suất theo thành viên (toàn `src/`, trừ `combat_state.gd`)

| Thành viên | Số chỗ | Thành viên | Số chỗ |
|---|---|---|---|
| `player_cell` | 90 | `is_enemy_dead()` | 51 |
| `enemy_cell` | 46 | `is_player_dead()` | 40 |
| `player_hp` | 28 | `cell_of(side)` | 26 |
| `enemy_hp` | 25 | `damage(side, amt)` | 25 |
| `enemy_max_hp` | 19 | `enemy_footprint_cells()` | 21 |
| `enemy_invulnerable_left` | 15 | `set_player_cell` | 12 |
| `player_max_hp` | 10 | `set_enemy_cell` | 9 |
| `damage_player` | 9 | `unit_at(side, cell)` | 8 |
| `enemy_footprint_size()` | 8 | `cell_changed` (signal) | 8 |
| `unit_in(side, cells)` | 7 | `set_player_hp` | 7 |
| `unit_cells(side)` | 6 | `heal_enemy` | 6 |
| `enemy_fits` | 6 | `footprint_cells_at` | 4 |
| `damage_enemy` | 4 | `is_enemy_at` | 3 |
| `enemy_in` | 3 | `enemy_hp_floor` | 3 |
| `enemy_hit_cell` | 3 | `enemy_death_hook_fn` | 3 |
| `cast_origin(side)` | 3 | `enemy_died` (signal) | 2 |
| `damaged` (signal) | 2 | `set_enemy_footprint` | 1 |
| `enemy_damage_taken` / `player_damage_taken` | 1 / 1 | `enemy_cast_origin` / `enemy_anchors` | 1 / 1 |
| `enemy_healed` (signal) | 2 | `changed` (signal) | 1 |

### 2.2 File dùng từng thành viên enemy (ai sẽ phải "chọn unit" ở Phase 2–5)

| Thành viên | File (`src/`) |
|---|---|
| `enemy_cell` | battle/unit_layer, combat/boss_brain, boss_controller, combat_view*, cut_hud_view, pattern_controller*, pattern_planner, status_effects*, unit_mover, dev/demo_args, traits/burrow*, hop_skip |
| `enemy_hp` | boss_brain, combat_view*, crit_rules, cut_effects, cut_hud_view, parry_guard, pattern_controller*, status_effects*, demo_args, traits/boss_phases, boss_trait*, frost_aura, phase_shift, rebirth* |
| `enemy_max_hp` | boss_brain, combat_view*, crit_rules, cut_effects, pattern_controller*, demo_args, boss_phases, frost_aura, phase_shift, rebirth* |
| `enemy_hp_floor` | pattern_controller*, boss_phases |
| `enemy_invulnerable_left` | unit_layer, pattern_controller*, boss_phases |
| `enemy_damage_taken` | combat_view* |
| `enemy_death_hook_fn` | trait_host* |
| `set_enemy_cell` | cut_effects, pattern_controller*, status_effects*, tile_hazards, unit_mover, demo_args, burrow*, hop_skip |
| `set_enemy_footprint` | pattern_controller* |
| `enemy_footprint_cells` | floor_dynamic_layer, floor_layer, unit_layer, combat_view*, crit_rules, cut_effects, cut_hud_view, pattern_controller*, status_effects*, swing_arbiter, demo_args, passives/hunter_mark |
| `enemy_footprint_size` | unit_layer, boss_brain, status_effects* |
| `enemy_in` | cut_hud_view, pattern_controller* |
| `enemy_fits` | boss_brain, cut_effects, pattern_controller*, status_effects* |
| `enemy_anchors`, `enemy_cast_origin` | pattern_controller* |
| `enemy_hit_cell` | combat_view*, cut_effects |
| `is_enemy_at` | floor_dynamic_layer, overlay_layer, cut_hud_view |
| `is_enemy_dead` | floor_dynamic_layer, floor_layer, unit_layer, boss_brain, boss_controller, combat_view*, cut_hud_view, parry_guard, pattern_controller*, status_effects*, swing_arbiter, tile_hazards, demo_args, boss_phases, burrow*, hop_skip |
| `damage_enemy` | demo_args, signatures/thien_hoa, boss_trait* |
| `heal_enemy` | pattern_controller*, status_effects*, traits/burn_eater, rebirth* |
| `footprint_cells_at` | floor_layer, boss_brain, status_effects*, unit_mover |
| `footprint_extent` | unit_layer |

`*` = file session monster-skills đang giữ → không sửa trong Phase 1 (và các caller này **không cần** sửa nhờ proxy).

### 2.3 Ghi trực tiếp vào trường enemy (proxy cần setter)

| File:dòng | Ghi |
|---|---|
| `pattern_controller.gd:464, :467, :1153, :1157` | `enemy_invulnerable_left = …` |
| `pattern_controller.gd:1168, :1170` | `enemy_hp_floor = …` |
| `traits/boss_phases.gd:93, :167` | `enemy_invulnerable_left = …` |
| `traits/boss_phases.gd:236` | `enemy_hp_floor = …` |
| `traits/trait_host.gd:44, :250` | `enemy_death_hook_fn = …` |
| `dev/demo_args.gd:1651, :2209` | `enemy_hp = …` (dev) |
| tests (12 file) | `enemy_hp / enemy_max_hp / enemy_cell / enemy_invulnerable_left / enemy_hp_floor / enemy_footprint = …` |

### 2.4 Signal và người nghe

| Signal | Người nối (`src/`) |
|---|---|
| `damaged(side, amount)` | unit_layer:682 (`_on_damaged` → `_hit_left[side]`), audio bridge (theo phe) |
| `cell_changed(side, old, new)` | unit_layer:683, boss_controller:91 (lọc `side != ENEMY`), combat_view:430, demo_args:970, traits/hop_skip:63 |
| `enemy_died` | combat_view:394 (`_on_enemy_died`, downed), swing_arbiter:143 (`_cancel_all`) |
| `player_died` | swing_arbiter:142 |
| `enemy_healed(amount)` | cut_hud_view (số hồi xanh), demo_args |
| `changed` | 1 chỗ |

Thứ tự signal được test khoá: `damaged → changed → enemy_died` (`state_damaged_signal_test.gd:117`), và
`damaged` không phát cho damage bị bỏ qua / bị sàn chặn.

### 2.5 Khởi tạo

- `src`: duy nhất `combat_view.gd:388` `CombatState.new(_grid, player_max_hp, boss_max_hp, _config.player_start_cell, _config.enemy_start_cell)`.
- Tests: 110 lệnh `CombatState.new(` / 81 file, đối số vị trí (grid, player hp, enemy hp, player cell, enemy cell) → **chữ ký `_init` giữ nguyên.**
- Test khoá footprint: `boss_footprint_test.gd` (`normalize_footprint`, anchor mặc định 6×4, `enemy_fits` biên/divider/lỗ, `set_enemy_footprint` từ chối rộng 4 trên nửa 3 cột, `enemy_cast_origin`, `enemy_hit_cell`, `UnitMover` bước với footprint).

---

## 3. Thiết kế đề xuất

### 3.1 `EnemyUnit` (mới, `src/combat/enemy_unit.gd`, RefCounted, dữ liệu thuần)

```gdscript
class_name EnemyUnit
var index: int                 # 0..3, vị trí trong CombatState.units
var id: String                 # template / match id ("" cho match thường cũ: giữ nguyên hành vi)
var cell: Vector2i             # anchor (top-left của footprint)
var footprint: Array[Vector2i] # [(0,0)] mặc định
var max_hp: float
var hp: float
var hp_floor: float = 0.0
var invulnerable_left: float = 0.0
var damage_taken: float = 0.0
var death_hook_fn: Callable    # rebirth
var required: bool = true      # tính vào điều kiện thắng
var defense: float = 0.0       # Phase 2 (SwingArbiter.boss_defense → unit)
var role: String = ""          # nhãn
func is_dead() -> bool
func footprint_cells() -> Array[Vector2i]      # = CombatState.footprint_cells_at(cell)
func covers(cell) / covers_any(cells) -> bool   # = is_enemy_at / enemy_in cho unit này
func extent() -> Vector2i, cast_origin() -> Vector2i, hit_cell(cells) -> Vector2i
```
Các hàm hình học (`extent / cast_origin / hit_cell / normalize`) là **chuyển** nguyên logic hiện có của
`CombatState` (`:170-316`) sang unit (một nguồn), `CombatState` gọi lại cho unit 0 — không có bản sao thuật toán.

### 3.2 `CombatState` sau Phase 1

```gdscript
var units: Array[EnemyUnit]                         # >= 1, units[0] = "the enemy" cũ
# ---- PROXY (getter/setter, không lưu trữ) → units[0]; chữ ký & kiểu y nguyên ----
var enemy_cell: Vector2i:              get: return units[0].cell;              set(v): units[0].cell = v
var enemy_footprint: Array[Vector2i]:  get: return units[0].footprint;         set(v): units[0].footprint = v
var enemy_max_hp: float / enemy_hp / enemy_hp_floor / enemy_invulnerable_left / enemy_damage_taken / enemy_death_hook_fn  (tương tự)
# ---- API cũ: chữ ký + ngữ nghĩa y nguyên, thao tác trên unit 0 ----
is_enemy_dead() damage_enemy(a) heal_enemy(a) set_enemy_cell(c) set_enemy_footprint(o) enemy_footprint_size()
footprint_cells_at(a) enemy_footprint_cells() is_enemy_at(c) enemy_in(cells) enemy_fits(a, blocked_fn)
enemy_anchors() default_enemy_anchor() enemy_cast_origin() enemy_hit_cell(cells) unit_cells(side) unit_at(side, c)
unit_in(side, cells) cast_origin(side) footprint_extent() damage(side, a) cell_of(side)
# ---- API mới theo unit ----
const MAX_UNITS := 4                                 # = FormationRules.MAX_UNITS
static func unit_key(index: int) -> int: return 1 + index          # Side.ENEMY == unit_key(0)
static func unit_index_of(key: int) -> int: return key - 1         # -1 cho PLAYER
func unit_count() -> int;  func get_unit(i) -> EnemyUnit;  func living_units() -> Array[int]
func add_unit(id: String, max_hp: float, footprint: Array[Vector2i] = [ZERO], anchor := NO_CELL, required := true) -> int
      # -1 khi: đã MAX_UNITS, hoặc không anchor nào fit (loại ô unit sống khác + grid). Không bao giờ dời unit khác.
func is_unit_dead(i) all_required_dead() any_enemy_alive()
func damage_unit(i, a) heal_unit(i, a) -> float   set_unit_cell(i, c) -> bool   set_unit_footprint(i, o) -> bool
func unit_fits(i, anchor, blocked_fn = Callable()) -> bool   # grid + blocked_fn + KHÔNG đè ô của unit sống khác
func unit_anchors(i) default_unit_anchor(i)
func enemies_in(cells) -> Array[int]      # index các unit SỐNG bị phủ, tăng dần
func enemy_at(cell) -> int                # index unit SỐNG phủ ô, -1
func all_enemy_cells(alive_only := true) -> Array[Vector2i]
func damage_key(key, a) / cell_of_key(key) / unit_cells_of_key(key)   # key = 0 player, 1+i unit (Phase 2 dùng)
# ---- Signal ----
signal unit_damaged(index: int, amount: float)      # MỌI unit
signal unit_healed(index: int, amount: float)
signal unit_cell_changed(index: int, old: Vector2i, new: Vector2i)
signal unit_died(index: int)
signal all_required_died                             # điều kiện thắng (Phase 3 _tick_end)
# signal cũ: damaged(ENEMY, a) / cell_changed(ENEMY, …) / enemy_died / enemy_healed CHỈ phát cho unit 0,
# đúng thứ tự cũ: unit_damaged → damaged → changed → unit_died → enemy_died (→ all_required_died)
```

**Quy tắc "unit 0 = cũ":** trong một trận có một unit, mọi lệnh gọi và mọi signal **giống hệt** hiện tại (kể cả thứ
tự và payload). `unit_fits` loại ô của unit khác — với một unit không có "unit khác" nên bằng `enemy_fits` cũ.

**Vì sao không gộp `enemy_in` thành "bất kỳ unit"** ở Phase 1: `SwingArbiter`/`CutEffects` sau khi thấy `unit_in(ENEMY)`
true sẽ gọi `damage(ENEMY)` → **unit 0 lĩnh đòn thay unit bị phủ** (vi phạm nguyên tắc 4). Chuyển `enemy_in` cùng lúc
với resolver ở Phase 2, qua `enemies_in()`.

### 3.3 Khởi tạo và dữ liệu Phase 0

- `_init(grid, player_max_hp, enemy_max_hp, player_cell, enemy_cell)` **không đổi**: tạo `units = [EnemyUnit(0, "", …)]`.
- Mới: `static func from_match_params(grid, player_max_hp, params: Dictionary, player_start, enemy_start) -> CombatState`:
  unit 0 từ `boss_max_hp` như cũ; nếu `params.enemies` có ≥ 2 entry thì `add_unit` cho entry 1.. với
  `max_hp`, `footprint_cells`, `required`, `role`, `id` của entry. Chưa ai gọi trong `src` ở Phase 1 (CombatView bị giữ);
  test gọi.
- Để entry mang đủ số: **mở rộng Phase 0 (file của tôi)** `RunConfig.from_node` / `ChaptersConfig.get_formation_match_raw`
  resolve cho **mỗi** entry: `template_id`, `max_hp` (= template `boss_max_hp` × `region_normalize.hp_mult` ×
  `floor_scaling.hp_mult` × `hp_mult`), `defense` (= template `boss_defense` + normalize/floor `defense_add` +
  `defense_add`), `brain`, `enemy`, `footprint` (từ `enemy_skills.json`), `traits` (template + entry). `_clean_match`
  carry các khoá này trong `enemies[]` (bổ sung `FormationRules.ENTRY_KEYS`). Số của unit 0 vẫn tính như match thường
  (không có nguồn kép: entry[0].max_hp **được tính từ cùng công thức** `_apply_scaling` và test khẳng định bằng
  `boss_max_hp × hp_mult`).

### 3.4 Những gì Phase 1 **không** làm (để lại Phase 2–5, đã có bảng caller §2.2)

- Không đổi `SwingArbiter` (vẫn 1 actor/phe, `boss_defense` một số), `CutEffects`, `StatusEffects`, `TileHazards`,
  `UnitMover`, AI, trait, HUD, `UnitLayer`. Không có đòn của unit 1+, không có target UI.
- `CombatView` không dựng unit 1+ → **game thật vẫn 1v1**, formation node chơi như match của quái đầu (như Phase 0).
- `is_enemy_dead()` vẫn = unit 0 (16 file caller đổi theo từng phase: HUD/UnitLayer → `is_unit_dead(i)`; `_tick_end`
  → `all_required_dead()`; arbiter `_cancel_all` → giữ theo unit 0 hay `all_required_died` — quyết ở Phase 2).

---

## 4. File sẽ sửa và lý do

| File | Đổi | Lý do |
|---|---|---|
| `src/combat/enemy_unit.gd` (mới) | lớp dữ liệu unit + hình học footprint | một nguồn chân lý cho mọi thuộc tính riêng của unit |
| `src/combat/combat_state.gd` | `units`, proxy, API/signal theo unit, occupancy | lớp khoá duy nhất; caller không đổi |
| `src/run/run_config.gd`, `src/run/chapters_config.gd` (tuỳ chọn, đề nghị làm) | resolve số per-entry trong `enemies[]` | để `from_match_params` dựng unit không cần `ChaptersConfig` |
| `assets/data/schema.md` | khoá entry resolved | tài liệu |
| `tests/unit/combat/combat_state_units_test.gd` (mới) | §5 | |
| `tests/unit/run/formations_config_test.gd` | thêm check số resolved | |

**Không sửa:** `combat_view.gd` và mọi file session monster-skills đang giữ; `chapters.json`; AI; reward.

---

## 5. Kế hoạch test

1. **Hồi quy 1 unit (bắt buộc giữ nguyên):** `boss_footprint_test`, `state_damaged_signal_test`, `boss_downed_test`,
   toàn bộ `tests/unit/combat`, `tests/unit/traits`, `tests/unit/battle`, `tests/unit/relics`, rồi full suite (nền);
   đối chiếu 2 FAIL `poison` có sẵn.
2. **`combat_state_units_test.gd` (mới):**
   - 1 unit: `unit_count()==1`, `unit_key(0)==Side.ENEMY`, proxy đọc/ghi (`enemy_hp = x` → `get_unit(0).hp == x`),
     `from_match_params` không có `enemies` → giống `_init`.
   - 2–3 unit: `damage_unit(1)` không đổi `enemy_hp`; `damage(ENEMY)` không đổi unit 1; `heal_unit`; `set_unit_cell(1)`
     vào ô unit 0 bị từ chối; `set_enemy_cell` vào ô unit 1 bị từ chối; unit 1 chết → ô được giải phóng,
     `enemies_in` bỏ qua; `enemy_at`; `all_enemy_cells`.
   - Signal: unit 1 trúng → `unit_damaged(1)` phát, `damaged(ENEMY)` **không** phát; unit 1 chết → `unit_died(1)`,
     `enemy_died` không; cả hai chết → `all_required_died` đúng một lần; thứ tự cho unit 0 vẫn
     `damaged → changed → enemy_died`.
   - `required=false` không chặn `all_required_dead()`; `add_unit` thứ 5 → -1; `add_unit` footprint không fit → -1 và
     không dời unit khác; 2×2 + 1 trên `boss_hall` dựng được, mỗi unit anchor riêng.
   - Floor hook / sàn HP / bất tử theo unit: `hp_floor` của unit 1 không ảnh hưởng unit 0.
3. **Phase 0 mở rộng:** `from_node(formation)` entry[i].max_hp = template × normalize × floor × hp_mult;
   entry[0].max_hp == `boss_max_hp` của match.

---

## 6. Rủi ro

| Rủi ro | Mức | Giảm thiểu |
|---|---|---|
| Proxy property làm chậm vòng lặp nóng (`boss_brain._bfs` đọc `enemy_cell`) | thấp | getter một phép đọc; đo bằng `sim_core.gd` 30 seed trước/sau nếu cần |
| Test nào đó so sánh `CombatState` bằng `==` hay duyệt property list | thấp | grep trước khi code; không thấy chỗ nào |
| `enemy_footprint` setter: caller ghi mảng không chuẩn hoá (chỉ test) | thấp | setter chuẩn hoá như `set_enemy_footprint` |
| Session monster-skills commit đè `combat_state.gd`? | không | họ không chạm file này (git status) |
| Caller dùng `is_enemy_dead()` làm "hết địch" | trung | giữ nghĩa cũ; danh sách 16 file để Phase 2–4 chuyển |
| `unit_fits` loại ô unit khác làm `set_enemy_footprint` thay đổi anchor mặc định khi có unit 1 | thấp | chỉ xảy ra khi ≥ 2 unit; test riêng |

---

## 7. Điểm dừng

Đã hoàn thành Bước 1 (audit + thiết kế). **Chưa sửa code.** Chờ duyệt để làm Bước 2 (triển khai trong phạm vi §4) và
Bước 3 (test). Không mở rộng sang Phase 2.
