# Audit & thiết kế: Encounter nhiều quái (Multi-Enemy Encounter)

**Ngày:** 2026-11-13 · **Trạng thái:** Audit + đề xuất, CHƯA implement · **Nhánh:** `main` @ `2fdfe3f` · **Engine:** Godot 4.6.3
**Phạm vi:** chỉ đọc code và dữ liệu thật; không sửa code, data, asset, test; không commit.
**Hướng đi được yêu cầu:** Normal = 2–3 quái thường · Hard = 3–4 quái nhiều vai trò · Elite = 1 Elite + 1–2 quái hỗ trợ · Boss = 1 Boss + cơ chế riêng hoặc quái phụ. Vai trò: Attacker / Tank / Support / Disruptor. Không tạo quái mới.

---

## 0. Kết luận trong một trang

| Câu hỏi | Trả lời |
|---|---|
| Mở rộng được hay cần refactor? | **Cần refactor có kiểm soát ở tầng "danh tính unit"**, không phải viết lại combat. Toàn bộ combat khoá đối thủ bằng `CombatState.Side` (2 giá trị PLAYER / ENEMY) và các trường vô hướng `enemy_hp / enemy_cell / enemy_footprint` trên `CombatState`. Không hệ nào có khái niệm "unit thứ hai cùng phe". Khoá `Side` phải trở thành khoá `unit`, nhưng có thể làm **tăng dần phía sau một lớp tương thích** (enemy đầu tiên giữ nguyên `Side.ENEMY = 1`) nên combat 1v1 hiện tại và 81 file test `CombatState.new(` không vỡ. |
| Module bắt buộc đổi | (1) `CombatState` → danh sách unit; (2) `SwingArbiter` (`_actors` 1 actor/phe, interrupt theo phe, `boss_defense` một số); (3) `StatusEffects` (pin/root/slow/guard/Ran/Hàn/mark khoá theo phe); (4) `CutEffects` (nhánh `target_side == ENEMY` → unit cụ thể); (5) `CombatView._ready/_process` (một `_boss`, một `_pattern`); (6) `UnitLayer` + `CutHudView` (một sheet/HP plate/feedback mỗi phe); (7) `TraitHost` (hook toàn cục `enemy_death_hook_fn`, `enemy_untargetable_fn`); (8) `RunConfig._clean_match` whitelist + `EncounterComposer` + `UnitLayer.unit_ids_for` (data). |
| Triển khai từng bước mà không phá combat hiện tại? | **Được**, với điều kiện giữ bất biến "encounter 1 quái = hành vi cũ byte-by-byte" qua từng bước và chạy `tools/qa/run_all_tests.sh` sau mỗi bước (271 test hiện xanh). Dữ liệu cũ (`chapters.json` không có khoá `enemies`) được đọc thành encounter 1 quái. |
| Bắt đầu từ module nào? | **`CombatState`** (bước 1), vì mọi thứ khác đọc nó. Sau đó `StatusEffects` + `CutEffects` + `SwingArbiter` (bước 2), rồi agent/AI (bước 3), presentation (bước 4), trait (bước 5), data/World Map (bước 6). Data schema (`enemies[]`) có thể viết sớm vì bước 0 chỉ thêm khoá và đọc thành 1 quái. |
| Số quái tối đa với arena hiện tại | **4 unit cells** (ô bị chiếm) mỗi nửa, chỉ ở shape ≥ 15 ô thật; **3** ở 11–14 ô; **2** ở `square` (9 ô). Boss 2×2 tính 4 ô → Boss + 1–2 quái phụ chỉ trên `boss_hall`/`caldera`/`oasis` (22–24 ô). Chi tiết §8.4. |
| Rủi ro lớn nhất | (a) **Fairness F1/F2** hiện tính riêng từng agent (`PatternController.external_red_fn` chỉ gộp cảnh báo trait), N agent cùng đỏ sẽ vượt `max_red_ratio` → cần Bảng đe doạ chung + cơ chế "thẻ tấn công"; (b) **damage người chơi nhận ≈ ×N** nếu không hãm tempo; (c) 52 quái ngoài ch1 chưa có sprite (đang gen ở session khác) — đội hình 3 quad đỏ không đánh giá được "nhìn"; (d) quyết định thiết kế `03-encounter-system.md §1` (11/11) ghi rõ "composition, not multi-enemy" — cần **người dùng lật quyết định đó** trước khi code. |
| Mâu thuẫn với tài liệu hiện có | `docs/design/world-map-v2/03-encounter-system.md §1`, `README.md:38`, `00-current-state-audit.md:75`, `01-game-design-spec.md:233` đều nói "không multi-enemy". Ngược lại `design/quick-specs/phase2-misty-forest-2026-11-01.md:549` **D7: "Một quái mỗi trận trong Phase 2; nhiều quái cùng lúc làm ở Phase 3"** — tức multi-enemy đã được dự kiến cho Phase 3. Báo cáo này là bản thiết kế cho "Phase 3" đó. |

---

## 1. Kiến trúc hiện tại (current architecture)

### 1.1 Chuỗi từ node bản đồ → trận đấu → phần thưởng

```
RegionMapGen / ChapterMapGen  →  node {kind, match_id, modifiers, objective, reward_tier}
  └ GameFlow._spawn_match(match_id, kind)                      src/run/game_flow.gd:2415-2451
      ├ EncounterComposer.profile(node, region, gauge)         src/run/map/encounter_composer.gd:19-58
      ├ RunConfig.from_node(..., profile)                      src/run/run_config.gd:111-149
      │    raw = chapters.get_match_raw(region, match_id)      (MỘT match block)
      │    _apply_scaling → danger_traits → EncounterComposer.apply_to_raw → KiepRules
      │    data["matches"] = [raw]  → from_dictionary → _clean_match (whitelist MATCH_KEYS :11-17)
      └ RunController.new() … configure(run_config, 0, hp)    src/run/run_controller.gd:116-120
           └ _spawn_battle(): instantiate res://src/battle/battle.tscn, view.match_params = params   :317-360
                └ CombatView._ready()                           src/combat/combat_view.gd:368-522
                     CombatState.new(grid, player_hp, boss_max_hp, …)         :382-384   (1 enemy)
                     BossController.new(_state, _grid, …)                      :448-451   (1 agent)
                     SwingArbiter.new(_state, _grid, _cut_actor, _boss.get_actor(), …)  :480 (1 actor/phe)
                     TraitHost.new(make_trait_ctx(), _trait_specs(), seed)     :515      (ctx.boss = _boss)
                     _setup_pattern_brain(brain_config)                        :517      (0 hoặc 1 PatternController)
  CombatView._tick_end → match_ended(won, hp)                   :1302-1314
  └ RunController._on_match_ended → RunState.on_match_won/lost  :386-398
      └ GameFlow._on_match_won → objectives → _complete_match_node → RewardRoller   :2580-2630, 2652-2689
```

Combat là **thời gian thực** (không theo lượt): `CombatView._process` (`:1345-1419`) tick `_status`, `_hazards`, `_mover`, `_drops`, `_boss.tick`, `_pattern.tick`, `_arbiter.tick` mỗi khung với `step = real_step × _sim_scale()` (Focus / menu làm chậm). `SwingArbiter.tick` (`swing_arbiter.gd:154-176`) chia khung thành lát tại mốc actor/event gần nhất; hai resolution trong một lát là "trade".

### 1.2 Enemy spawning (câu A)

| Điểm | Thực tế trong code |
|---|---|
| Spawn ở đâu | Không có "spawn" theo nghĩa scene. Enemy là **số liệu trong `CombatState`** (`src/combat/combat_state.gd:33-55`: `enemy_cell`, `enemy_footprint`, `enemy_max_hp`, `enemy_hp`, `enemy_invulnerable_left`, `enemy_hp_floor`, `enemy_death_hook_fn`) + **một agent** `BossController` (`combat_view.gd:448`) + tuỳ chọn một `PatternController` (`:2573-2592`). Hình vẽ do `UnitLayer` lấy sheet theo `match_params["id"]` (`src/battle/unit_layer.gd:610-616`). |
| Giới hạn 1 enemy | **Có, ở cấu trúc dữ liệu**: `CombatState` chỉ có một bộ trường enemy; `enum Side {PLAYER, ENEMY}`; `unit_cells/unit_at/unit_in/cell_of/damage(side)` rẽ nhánh PLAYER-hoặc-ENEMY (`:320-362`). `BoardGrid` có nửa enemy với nhiều ô (`src/board/board_grid.gd:92 enemy_cells()`), nhưng chỉ một unit đứng trên đó. |
| Khởi tạo từ gì | Từ **match block JSON** (`assets/data/chapters.json chapters[].matches.<id>`): `boss_max_hp`, `brain_set`, `boss_defense`, `boss_min_runes`, `traits[]`, `arena`, và với pattern brain `brain: "pattern"`, `enemy: <id>` trỏ sang `assets/data/enemy_skills.json enemies.<id>` (tier, footprint, skills/phases). Không có scene/resource riêng cho enemy. |
| Có cấu trúc encounter chưa | **Chưa**. Node World Map v2 giữ `match_id` (một id) + `modifiers[]` + `objective` + `reward_tier` (`src/run/map/region_map_gen.gd:113-118`; lưu ở `RunSession.columns_from_graph` `run_session.gd:356-361`). `EncounterComposer.profile` chỉ vá match block (traits, hazard keys, `*_mult`, `*_add`, arena variant) — `apply_to_raw` `encounter_composer.gd:75-120`. |
| Spawn nhiều enemy mà không viết lại? | **Không với code hiện tại**: `RunConfig._clean_match` (`run_config.gd:221-298`) bỏ mọi khoá ngoài whitelist, `CombatView` tạo đúng một `_boss`, `SwingArbiter._init` nhận đúng một `boss_actor` (`swing_arbiter.gd:137-138`). Nhưng **không cần viết lại**: các lớp agent (`BossController`, `PatternController`, `UnitMover`, `CutActor`, `BossBrain`, `BossLearning`) đều là RefCounted tạo-được-nhiều-bản; thứ thiếu là **danh tính unit** xuyên suốt. |

### 1.3 Vòng đời trận (câu B)

| Giai đoạn | Code | Giả định 1 enemy |
|---|---|---|
| Khởi tạo | `CombatView._ready` `:368-522` (thứ tự: state → mover → drops → placement → deck → actor/flow → BossController → status → arbiter → zones/hazards/relics → TraitHost → pattern → passive/signature) | `CombatState.new(... boss_max_hp ...)` một HP; `_boss` một agent |
| Enemy xuất hiện | `UnitLayer._bind_match` `unit_layer.gd:688-698` nạp `SpriteSheet.load_unit(match id)`; vị trí `_cell_of(ENEMY)` = `state.enemy_cell` `:922-924`; z-order sort danh sách 2 unit `:997-1028` | `_sheet[side]`, `_anim[side]` khoá theo phe |
| Nhận damage | `SwingArbiter._settle/_fire_event` → `CutEffects.apply` (`cut_effects.gd:78-92`): `target_side = ENEMY`, `inside = state.unit_in(target_side, cells)` `:168`, `state.damage(target_side, dmg)` `:384`; `CombatState.damage_enemy` `:96-109` (hook rebirth `:101`, floor pha, `damaged(side)` → `enemy_died`) | Một HP; `enemy_hit_cell(cells)` một footprint |
| Chết | `enemy_died` → `SwingArbiter._cancel_all` `:143`; `CombatView._on_enemy_died` `:2479-2495` chỉ xử lý **boss "downed"** (`boss_can_down`) | — |
| **Điều kiện kết thúc** | `CombatView._tick_end` `:1302-1314`: `if not (is_player_dead() or is_enemy_dead()) return` → đếm `end_delay_sec` → `match_ended.emit(won = not is_player_dead(), player_hp)` | **Victory = `is_enemy_dead()` của MỘT enemy.** Đây là điểm phải đổi thành "mọi unit bắt buộc đã chết" |
| Sau chết, cái gì vẫn tick | `_process` không dừng: `_status`, `_hazards`, `_drops`, `_boss.tick`, `_pattern.tick`, `_arbiter.tick` vẫn chạy; chỉ `_trait_host.on_tick` bị chặn khi một bên chết `:1410-1411`. `BossBrain.decide` tự chờ khi một bên chết (`boss_brain.gd:257`) | Với N unit: unit chết phải `set_active(false)` + `actor.cancel()` riêng (hiện chỉ làm ở nhánh downed `:2483-2484`) |
| Victory/defeat → run | `RunController._on_match_ended` `:386-398` → `RunState.on_match_won` (`run_state.gd:74-80`, node 1 match → WON) → `GameFlow._on_run_phase_changed` `:2569-2576` → `_on_match_won` `:2580-2600` (stats, objective) / `_finish_run_lost` `:2827-2843` | `get_match_stats()` `:2516-2520`: `damage_dealt = enemy_damage_taken` một unit |
| Reward/drop | `GameFlow._offer_reward` `:2652-2689`: `RewardRoller.reward_for_node_tier(kind, cfg, tier)`; vàng `economy.json gold_drops` theo **kind** (battle 12, danger 22, miniboss 25, boss 35) | **Thưởng theo node, không theo enemy** — multi-enemy không cần đổi reward |
| Node tiếp theo | `_complete_match_node` `:2606-2630` → `RunSession.complete_node` (`run_session.gd:532-557`) → `_return_to_map` | — |
| Save/load | `RunSession.to_dict` `:1085-1110` lưu node (`match_id`, `modifiers`, `objective`…) + `hp`; **không lưu trạng thái giữa trận** (`GameFlow._save_run` chỉ gọi ở `_spawn_match` và `_on_match_started`; resume = spawn lại match từ đầu `:2460-2488`) | Save không có HP enemy → multi-enemy không cần save mid-combat; chỉ cần node lưu đủ để **tái tạo đội hình** |

### 1.4 AI và hành động (câu C)

| Lớp | Khoá theo | Giả định 1 enemy (file:line) | Dùng lại được? |
|---|---|---|---|
| `BossBrain` (`boss_brain.gd`) | 1 instance / boss | `state.enemy_cell` `:341, :835`; `Side.ENEMY` cứng trong `own_blocked` `:313-326`, `_apply_hazards` `:1242`, `_apply_crumble` `:1310`; footprint đơn `_anchor_space` `:802-826`. Có sẵn hook `extra_own_blocked_fn` `:99, :331-334` (hiện chỉ nhận marker của pattern) | Cần tham số unit ("ô của tôi", "footprint của tôi"); ô unit khác → `extra_own_blocked_fn` |
| `BossController` (`boss_controller.gd`) | 1 controller = 1 boss; tự tạo `HoldSlots`, `FieldDrops.new(cfg, grid.enemy_cells(), seed)` `:85`, `UnitMover(…, Side.ENEMY)` `:86`, `CutActor(…, Side.ENEMY)` `:87`, `SkillCooldowns`, `BossBrain` | `tick` dùng `_state.enemy_cell` `:126`, `is_enemy_dead` `:130`; **`_on_cell_changed` lọc chỉ theo phe `:356-359`** → N controller sẽ cùng nhặt khi bất kỳ enemy nào bước; drops phủ cả nửa sân `:85` | Cần unit id + drops dùng chung (một `FieldDrops` cho nửa sân, tiêm vào) |
| `UnitMover` (`unit_mover.gd`) | theo phe `_init(state, side, cd)` `:31` | `set_enemy_cell` `:60-63`; `is_pinned(_side)/is_rooted(_side)` `:49`; **không có kiểm tra "ô bị unit khác chiếm"** (chỉ `blocked_cell_fn` + `add_blocker` `:81-98`) | Cần unit id; occupancy đưa vào `add_blocker` hoặc `CombatState.enemy_fits(…, exclude unit)` |
| `PatternController` (`pattern_controller.gd`) | "skill lifecycle for ONE enemy" `:3`; `E = Side.ENEMY` `:35` | `_init` ghi đè footprint toàn cục `set_enemy_footprint` `:105`; đọc/ghi `enemy_hp`, `enemy_hp_floor`, `enemy_invulnerable_left` (pha) `:325-331, :754-780`; di chuyển `set_enemy_cell` `:684`; guard theo phe `_status.guard(E)` `:692`; `on_enemy_hit()` không có unit `:258-271`; **fairness `_fair` `:441-448`: `unsafe = external_red_fn()` `:455-456` chỉ = `CombatView.trait_warning_cells` (`combat_view.gd:2585`)** → không thấy cảnh báo của agent anh em; F5 gap `_since_warning` theo instance | Cần refactor: unit id + **Bảng đe doạ chung** cho F1/F2/F5 |
| `PatternBrain`, `PatternPlanner`, `FairnessCheck` | thuần, nhận ctx | `PatternPlanner` anchor `self_cell` / `enemy_half_empty` lấy ô từ ctx `:25-46`; `FairnessCheck.red_ok` đếm đúng cái được đưa `:87-93` | Dùng lại nguyên; caller phải gộp ô/marker của unit khác vào ctx |
| `SwingArbiter` (`swing_arbiter.gd`) | `_actors[side]` 1 actor/phe `:137-138`; `boss_actor.swing_resolved.bind(ENEMY)` `:141` | `boss_defense: float` một số `:86`; `enemy_untargetable_fn()` không đối số `:98`; interrupt `victim = _actors[_opposite(side)]` `:372-379, :630-636`; `enemy_footprint_cells()` `:549`; `enemy_died → _cancel_all` `:143` | Cần refactor: N actor enemy, hit rơi vào unit nào, interrupt actor nào, defense/untargetable theo unit |
| `CutEffects` (`cut_effects.gd`) | static, `target_side` | `target_side = ENEMY if side == PLAYER` `:93`; `unit_in` `:168`; `enemy_hit_cell` `:169-170`; defense chỉ khi `target_side == ENEMY` `:362`; `_hp_of` `:735-740`; push/pull `set_enemy_cell` `:562, :785, :914`; R1 `enemy_footprint_cells` `:460-466` | Cần refactor: hit test chọn unit bị phủ; damage/status/push theo unit |
| `StatusEffects` (`status_effects.gd`) | **theo phe**: `_pins` `:86-87`, `_fragile` `:245`, `_frost` `:302`, `_marks` `:94-95`, `_last_cell` `:96-97`, `_roots/_slows/_guards` `:156-158`; theo phe→ô: thorns/fields/holes; theo ô: `_burning` `:83-85` | `tick(delta, state)` `:364`; `_units_on(cell, state)` `:1309-1319` đọc `state.enemy_cell`; `_check_thorn_entries` `:1221-1251`; `_fall_hole` `set_enemy_cell` `:1106-1131`; `burn_heal_ratio_fn` chỉ ENEMY `:1213-1214` | Cần refactor sổ trạng thái unit (pin/root/slow/guard/Ran/Hàn/mark/ICD) sang khoá unit; sổ ô/zone giữ nguyên |
| `TileHazards` (`tile_hazards.gd`) | mảng `[{}, {}]` theo phe `:64-92` | `_unit_cell/_unit_on/_unit_over` qua `state.cell_of/unit_at/unit_cells(side)` `:1011-1025`; `_fall` `set_enemy_cell` `:929-935` | Cần unit id cho timer đứng (mire/vent/crumble); sổ ô giữ |
| `TraitHost` / `BossTrait` (`src/traits/`) | 1 host / trận `trait_host.gd:3`; ctx `make_trait_ctx` `combat_view.gd:1220-1226` có `boss` = `_boss` | Hook toàn cục: `arbiter.enemy_untargetable_fn` `:29`, `status.burn_heal_ratio_fn` `:33`, `state.enemy_death_hook_fn` `:36`, `placement.forecast_blocked_fn` `:39`; `on_boss_swing_*`, `on_boss_damaged` không có unit `:126-166`; trait đọc `state.enemy_*` trực tiếp: `boss_phases`, `rebirth`, `burrow`, `hop_skip`, `frost_aura`, `phase_shift`, `seal_caster`, `shroud`, `step_reactor` | `row_burner`, `vent_surge`, `thorn_field`… (chỉ chạm nửa người chơi) dùng lại nguyên; host cần **một host / unit** |
| `BossLearning`, `ParryGuard`, `ZoneRules` | — | `BossLearning` theo dõi 1 swing đang chạy `:14-21`; `ParryGuard.try_parry` phản đòn `state.damage(ENEMY)`/`pin(ENEMY)` `:93-96` không biết kẻ đánh; `ZoneRules.fit_cells` bảo vệ lối ra của MỘT ô đứng `:24` | Learning: 1 instance/unit; Parry/Zone: cần unit id |
| Thứ tự hành động | Không có lượt. Mỗi agent quyết định theo `think_interval_sec` riêng (`BossBrain.decide` `:259`), `SwingArbiter._step` tick mọi actor trong `_actors` rồi resolve `_pending` | N agent cùng hành động trong một khung là **tự nhiên** với kiến trúc này; vấn đề là **fairness và hãm tempo**, không phải thứ tự |
| Target selection | Enemy luôn nhắm `state.player_cell` (`BossBrain._best_piece_cut` `:620`, `PatternPlanner` anchor on_player/row/column). **Người chơi không chọn mục tiêu**: cast = đặt khối lên nửa enemy, trúng nếu mask phủ ô footprint (`PlacementController` `src/pieces/placement_controller.gd:148-159`; `CutHudView._draw_preview` `enemy_in` `cut_hud_view.gd:1631, :1666`) | Multi-enemy: hit test theo **không gian** → khối phủ ô của unit nào thì unit đó trúng (có thể trúng nhiều unit một lần). Không cần UI chọn mục tiêu. |

### 1.5 UI và trình bày (câu D)

| Thành phần | Code | Giả định |
|---|---|---|
| Bố trí trên arena | `UnitLayer._draw` `unit_layer.gd:997-1028`: danh sách 2 dict `{side, cell}` sort hàng → cột → phe, vẽ bóng, status sau, sprite, status trước. `_feet_of_unit` `:944-957` theo footprint | **Đã lặp danh sách unit** → mở rộng N là thay đổi cục bộ; các bảng `_sheet/_anim/_hit_left/…` khoá theo phe `:172-214` phải thành theo unit |
| Sprite sheet | `unit_ids_for(match_params)` `:610-616` → ENEMY = `match_params["id"]`; `SpriteSheet.load_unit` `res://assets/art/units/unit_<id>_sheet.json` (`src/art/sprite_sheet.gd:19-21`); thiếu sheet → quad đỏ `_draw_enemy` `:1152-1169` | Mỗi entry trong encounter cần id sheet riêng (= match id của quái đó) |
| Health bar | `CutHudView._draw_hp_plates` `cut_hud_view.gd:2275-2284` lặp `[PLAYER, ENEMY]`, HP = `state.enemy_hp`; corner panel `CombatView._draw_hud` `:2767-2807` + `_hp_ratio(1)` `:2916`; HP trail mảng 2 slot `:2922-2944` | Thành plate / unit (đã vẽ dưới chân nên mở rộng tự nhiên) |
| Keyword chips (Hàn/Rạn/Guard/Mark) | `_draw_pins` `:2229-2259` chỉ `[ENEMY]`, đọc status theo phe | Theo unit |
| Damage number / HIT-MISS | Không từ `damaged`; từ `_on_swing_resolved` → `_feedback` (player) / `_boss_feedback` (enemy) `combat_view.gd:2394-2438`; vẽ tại `fb["cell"]` = `enemy_hit_cell(cells)` `cut_effects.gd:169` | Một feedback/phe → cần danh sách feedback (mỗi unit trúng một số) |
| Hit clip / flash / shake | `UnitLayer._on_damaged(side, amount)` `:718-726` từ `state.damaged(side, amount)` | Signal cần mang unit |
| Telegraph (ô đỏ) | `FloorLayer.telegraph_state` `floor_layer.gd:140-147`: một nguồn (`pattern.telegraph_cells()` hoặc `TelegraphPainter.state_for(boss actor)`); `SwingArbiter.pending_cells(side)` theo phe | Phải **gộp** telegraph của N unit (cùng một màu đỏ; sọc queued riêng) |
| Travel VFX / parry flash / heal number | `_boss_travel` một bản `:3611-3641`; `_parry_flash.cell = enemy_cell` `:2372`; `_draw_boss_heals` tại `enemy_cell` `:2816-2826` | Theo unit |
| Audio | `CombatAudioBridge` nối `get_boss().get_actor()`, `get_pattern_controller()` `src/audio/combat_audio_bridge.gd:37-38, :72-74`, `damaged(side)` `:193-196` | Theo unit (hoặc gộp: cue "windup" của bất kỳ unit) |
| Bề mặt phụ thuộc | Caller `get_boss()/get_pattern_controller()` ngoài `combat_view.gd`: `cut_hud_view.gd` 5, `floor_layer.gd` 4, `unit_layer.gd` 3, `run_hud_view.gd` 2, `pickup_layer.gd` 2, `combat_audio_bridge.gd` 2, `field_drops_view.gd` 1, `demo_args.gd` 29 (dev). Đọc `state.enemy_*` ngoài `combat_state.gd`: 134 chỗ / 24 file (bảng §10) | Giữ `get_boss()` = unit chính để các caller cũ sống; thêm `get_enemies()` |

### 1.6 Data và World Map (câu E)

- **Encounter lưu ở node** (`RegionMapGen` ghi `match_id`; v1 `ChapterMapGen` cũng vậy). Roster: `chapters.json` 8 chapter, **73 match id**, 63 trong pool; pool theo `kind × tier` (`pools.battle/danger/miniboss/boss` × `"0"/"1"/"2"`). Dump đầy đủ: §7.
- **Enemy pool per region** chính là `chapters[<region>].pools`; `region_normalize` + `world.floor_scaling` áp **tại một chỗ** `RunConfig._apply_scaling` `run_config.gd:154-179`.
- **Định nghĩa encounter bằng danh sách id**: chưa có chỗ nào. Thêm được ở ba tầng: (a) match block mới kiểu `encounter` trong `matches` (giữ id cũ nguyên); (b) node World Map v2 mang `enemies[]` do `EncounterComposer` sinh từ `formations`; (c) `RunConfig._clean_match` phải whitelist `enemies` (hiện bỏ mọi khoá lạ `:221-298`).
- **Tương thích**: khoá `enemies` vắng = encounter 1 quái từ chính match block → mọi data cũ, mọi test `RunConfig.load_from_file` flat, và map v1 của 6 region không đổi hành vi. Save v8 (`RunSession.SAVE_VERSION`) không lưu HP enemy nên **không cần đổi định dạng save mid-combat**; chỉ node cần thêm khoá tuỳ chọn `enemies` (hoặc `encounter_id`) — xem §5.4.

---

## 2. Giới hạn của mô hình một enemy (single-enemy limitations)

1. **`CombatState` là nguồn chân lý vô hướng** (`combat_state.gd:33-55`). Không có mảng unit, không có id. `Side` chỉ có 2 giá trị và được dùng làm khoá dict ở 6+ lớp.
2. **Victory = một `is_enemy_dead()`** (`combat_view.gd:1305`). Kẻ địch thứ hai không có chỗ để "chưa chết".
3. **`SwingArbiter._actors` 1 actor/phe** (`:137-138`): hai enemy không thể cùng có swing đang chạy; interrupt luôn huỷ "actor phe kia".
4. **Trạng thái unit khoá theo phe**: pin/root/slow/guard/Ran/Hàn/mark/reaction-ICD (`status_effects.gd`). Ghim một quái = ghim cả bầy.
5. **Occupancy không tồn tại**: `UnitMover`/`set_enemy_cell` chỉ kiểm tra "ô thật của nửa sân + blocker" — hai unit sẽ đứng chồng ô.
6. **Fairness cục bộ**: mỗi `PatternController` tự kiểm F1/F2/F5 với `unsafe` = cảnh báo trait (`:452-464`); không thấy telegraph của `BossController` khối hay pattern khác. Với N agent, trần `max_red_ratio 0.5` (`enemy_skills.json fairness`) bị vượt và lối thoát F1 có thể bị agent khác chặn.
7. **Drops nửa enemy thuộc BossController** (`:85`): N controller = N bộ sinh khối trên cùng nửa sân → spam khối; `_on_cell_changed` lọc theo phe nên mọi controller cùng nhặt.
8. **TraitHost hook toàn cục** (`enemy_death_hook_fn`, `enemy_untargetable_fn`, `burn_heal_ratio_fn`): `rebirth`/`burrow`/`shroud` của một quái sẽ áp lên "enemy" nói chung.
9. **Trình bày một sheet/một plate/một feedback mỗi phe**; telegraph một nguồn.
10. **Data**: `_clean_match` whitelist; `UnitLayer.unit_ids_for` lấy id từ `match_params["id"]`; `EncounterComposer.preview` trả một `enemy_name_key`.

Những gì **KHÔNG** phải giới hạn: `BoardGrid` (nửa enemy nhiều ô, 9–24 ô thật); `PatternBrain/Planner/FairnessCheck` (thuần); `BossController/BossBrain/UnitMover/CutActor/BossLearning` (RefCounted, tạo N bản được); reward/economy (theo node); save (không lưu mid-combat); `FormationMap` (theo ô nửa sân, không theo unit).

---

## 3. Tính khả thi multi-enemy (feasibility)

**Khả thi, mức "refactor tầng khoá", không phải viết lại.** Lý do:

- Logic gameplay đã tách khỏi scene (RefCounted thuần, DI qua constructor), nên **thêm chiều unit = thêm tham số**, không phải đổi kiến trúc node.
- Hit test vốn **không gian** (mask phủ ô) → tự nhiên hỗ trợ "một cast trúng nhiều unit" mà không cần UI chọn mục tiêu (phù hợp touch-first).
- `UnitLayer._draw` đã sort danh sách unit; HP plate đã vẽ dưới chân unit; telegraph đã là tập ô → trình bày mở rộng bằng vòng lặp.
- Footprint 2×2 (P2.2b, `enemy_fits/enemy_in/enemy_hit_cell`) đã giải bài "một unit nhiều ô" — bài "nhiều unit" là mở rộng cùng bộ hàm với tham số unit.
- Real-time, không có lượt → không cần hàng đợi hành động; cần **hãm** (throttle) chứ không cần **xếp lượt**.

**Cái giá thật**: ~24 file đọc `state.enemy_*` (134 chỗ), ~8 file gọi `get_boss()`; 81 file test dựng `CombatState.new(` và 34 test dựng `CombatView`. Chiến lược **facade tương thích** (§4.2) giữ 100% API cũ cho unit chính nên các test này không phải sửa ở bước 1–2; chúng trở thành lưới an toàn hồi quy.

---

## 4. Kiến trúc đề xuất (proposed architecture)

### 4.1 Nguyên tắc

1. Một encounter = **danh sách unit** trên nửa enemy; mỗi unit có id template (= match id hiện có), vị trí spawn, vai trò (nhãn thiết kế, không phải logic), và tuỳ chọn ghi đè số.
2. **Unit chính (index 0) giữ nguyên ngữ nghĩa `Side.ENEMY`**. `enum Side {PLAYER = 0, ENEMY = 1}` → định nghĩa **khoá unit** `unit_key = 0` (player), `1 + i` (enemy i). Khoá `1` trùng `Side.ENEMY` nên mọi dict khoá-theo-phe hiện có **đúng luôn cho enemy đầu tiên** mà không đổi giá trị. `side_of(key) = PLAYER if key == 0 else ENEMY`.
3. Không nhân bản logic combat: một `SwingArbiter`, một `StatusEffects`, một `TileHazards`, một `FieldDrops` cho nửa enemy, một `CutHudView`. Chỉ **agent** (brain/controller/pattern/learning/trait host) là 1 bản/unit.
4. Encounter 1 quái **phải** sinh hành vi giống hiện tại từng byte (determinism với seed, cùng log test).
5. Fairness là **tài sản của phe**, không của agent: một `ThreatBoard` chung.

### 4.2 Sơ đồ lớp

```
CombatState
  units: Array[EnemyUnit]                 # NEW  (>= 1)
  enemy_hp / enemy_cell / enemy_footprint / enemy_max_hp / enemy_hp_floor /
  enemy_invulnerable_left / enemy_death_hook_fn   # giữ: PROXY tới units[0] (getter/setter)
  is_enemy_dead()        -> mọi unit "required" đã chết   (victory)   # đổi nghĩa — xem bước 1
  is_unit_dead(u)        # NEW
  unit_in(side, cells)   -> enemy: bất kỳ unit sống bị phủ            # giữ chữ ký
  enemies_in(cells) -> Array[int]   # NEW: các unit bị phủ, theo thứ tự index
  enemy_fits(anchor, blocked_fn, unit = 0)   # + loại ô của unit khác đang sống
  damage(key, amount) / damage_unit(u, amount)                        # NEW
  signal damaged(key: int, amount)          # key = unit_key, 1 cho enemy 0 (tương thích)
  signal unit_died(u: int)                   # NEW; enemy_died vẫn phát khi victory đạt

EnemyUnit (RefCounted, NEW)                 # src/combat/enemy_unit.gd
  id: String (match id), index, cell, footprint, max_hp, hp, hp_floor, invulnerable_left,
  defense: float, damage_taken, death_hook_fn, required: bool (tính victory), role: String

EnemyAgent (RefCounted, NEW)                # src/combat/enemy_agent.gd — "bộ đồ nghề" của 1 unit
  unit: EnemyUnit, controller: BossController, pattern: PatternController|null,
  learning: BossLearning, traits: TraitHost, feedback: Dictionary, travel: Dictionary
  tick(step, player_actor)

ThreatBoard (RefCounted, NEW)               # src/combat/threat_board.gd
  red_cells_of(side) = ∪ telegraph/queued của mọi agent + trait warnings
  last_warning_at, attack_tokens (xem §6.2)
  external_red_fn cho mỗi PatternController; pending_threat cho BossBrain

CombatView
  _agents: Array[EnemyAgent]; get_boss() -> _agents[0].controller (giữ); get_enemies()
  _ready: build units từ match_params["enemies"] (vắng -> [match block]), 1 FieldDrops nửa enemy
  _process: for a in _agents: a.tick(step, _cut_actor); _arbiter.tick
  _tick_end: dùng CombatState.is_enemy_dead() (đã = all required dead)

SwingArbiter
  _actors: Dictionary unit_key -> CutActor   (0 = player, 1.. = enemies)  # giữ cấu trúc, đổi khoá
  _settle/_fire_event: target = enemies_in(cells) khi side == PLAYER; mỗi unit trúng 1 lần
  interrupt: huỷ actor của unit bị trúng (không phải "actor phe kia")
  boss_defense -> unit.defense; enemy_untargetable_fn(u)

StatusEffects
  sổ unit (pin/root/slow/guard/fragile/frost/mark/ICD/last_cell): khoá unit_key
  _units_on(cell): lặp state.units + player
  guard_amount(key), is_pinned(key) … (chữ ký giữ, key 1 = enemy 0)
```

### 4.3 Luồng một cast của người chơi với N unit

1. `confirm_placement` → `CutActor.begin_swing(cells, skill, target_is_enemy)` (không đổi).
2. `SwingArbiter._settle`: `hit_units = state.enemies_in(cells)`; nếu rỗng → MISS như cũ. Với từng unit (theo index): `CutEffects.apply(..., target_key = 1 + u, options.target_defense = unit.defense + guard_amount(key))`. **Hit once per unit** (giữ bất biến P2.2b theo unit). Damage number: một feedback/unit tại `unit.hit_cell(cells)`.
3. Interrupt: nếu unit u bị trúng và actor của u đang swing & interruptible → `actors[1+u].cancel()`; pattern của u `on_enemy_hit()`.
4. `unit_died(u)` → agent u: `controller.set_active(false)`, `actor.cancel()`, `pattern` dừng, marker/zone của u trên nửa người chơi: giữ (zone là của phe) hoặc xoá theo trait — quyết định thiết kế (mặc định giữ, như boss downed chỉ xoá khi là region boss).
5. `is_enemy_dead()` = mọi unit `required` chết → `_tick_end` như cũ → `match_ended`.

### 4.4 Luồng hành động của enemy

- Mỗi khung: `for a in _agents: a.tick(step, _cut_actor)`; thứ tự theo index (determinism). `BossController.tick` giữ nguyên nhưng nhận `unit` và `shared_drops`.
- `BossBrain.decide(ctx)`: ctx thêm `my_cell`, `my_cells`, `other_enemy_cells` (vào `extra_own_blocked_fn`), `threat_board`. Chọn cut vẫn nhắm `player_cell`.
- `PatternController(…, unit)`: `external_red_fn = threat_board.red_cells_of(PLAYER)` (gộp mọi agent) → F2 đúng theo phe; `_since_warning` đọc `threat_board.last_warning_at` → F5 đúng theo phe.
- **Thẻ tấn công** (§6.2): trước khi bước vào WINDUP/WARNING, agent xin thẻ từ `ThreatBoard`; số thẻ = `attack_slots` của encounter (mặc định 1 ở Normal, 2 ở Hard/Elite). Hết thẻ → agent chỉ đi lại / nhặt / self-skill. Đây là nút điều tiết damage nhận chính.

---

## 5. Cấu trúc dữ liệu (data structure)

### 5.1 Encounter block (thêm vào `chapters.json`, tương thích ngược)

Match block hiện tại = **template quái** (giữ nguyên, không đổi id, không đổi số). Thêm khoá tuỳ chọn `enemies` vào một match block *mới* kiểu encounter, hoặc đặt trong `formations` riêng của chapter (đề xuất: **`formations` riêng**, để pool `battle/danger/miniboss/boss` giữ id quái và pool mới `formations` giữ id đội hình):

```jsonc
"hellfire": {
  "matches": { "imp": {…}, "ember_hound": {…}, … },      // KHÔNG ĐỔI
  "formations": {                                         // NEW
    "hf_patrol": {
      "name_key": "formation.hf_patrol.name",
      "type": "normal",                                    // normal | hard | elite | boss
      "arena": {"shape": "forge"},
      "attack_slots": 1,                                   // thẻ tấn công đồng thời (§6.2)
      "enemies": [
        {"id": "imp",         "slot": "front_top",  "role": "attacker"},
        {"id": "ember_hound", "slot": "front_bottom","role": "attacker", "hp_mult": 0.9}
      ]
    },
    "hf_siege": {
      "type": "hard", "arena": {"shape": "caldera"}, "attack_slots": 2,
      "enemies": [
        {"id": "hell_knight",   "slot": "front_mid", "role": "tank", "required": true},
        {"id": "flame_cultist", "slot": "back_top",  "role": "disruptor"},
        {"id": "imp",           "slot": "back_bottom","role": "attacker", "hp_mult": 0.7}
      ]
    }
  },
  "pools": {
    "battle": {...},                                       // KHÔNG ĐỔI
    "formation": {"0": ["hf_patrol"], "1": ["hf_patrol","hf_siege"], "2": ["hf_siege", …]}   // NEW
  }
}
```

| Khoá | Kiểu | Ý nghĩa | Mặc định |
|---|---|---|---|
| `formations.<fid>.type` | `normal\|hard\|elite\|boss` | nhãn thiết kế; map tới node kind `battle\|danger\|miniboss\|boss` | bắt buộc |
| `.arena` | như match | sân của encounter (ghi đè `arena` của từng template) | sân của enemy[0] |
| `.attack_slots` | int ≥ 1 | số unit được ở WINDUP/WARNING cùng lúc | 1 |
| `.hp_budget_mult` | float > 0 | nhân tổng HP (§8.1) | 1.0 |
| `.enemies[]` | array ≥ 1 | các unit | bắt buộc |
| `.enemies[].id` | match id của cùng chapter | template (brain, traits, defense, enemy_skills) | bắt buộc |
| `.enemies[].slot` | id trong `spawn_slots` (§5.3) | ô spawn; không fit → ô fit gần nhất (`default_enemy_anchor` theo unit) | theo index |
| `.enemies[].role` | `attacker\|tank\|support\|disruptor` | nhãn hiển thị/kiểm tra data, không đổi logic | `""` |
| `.enemies[].required` | bool | tính vào victory | `true` |
| `.enemies[].hp_mult`, `.defense_add`, `.tempo_mult` | số | ghi đè per unit, áp **sau** `region_normalize × floor_scaling` | 1 / 0 / 1 |
| `.enemies[].traits` | array | thêm trait riêng cho unit (vd `rebirth` cho quái phụ của boss) | `[]` |
| `.enemies[].spawn_at` | `{"phase": 2}` hoặc `{"hp_ratio_of": 0, "below": 0.5}` | quái phụ xuất hiện muộn (Boss + quái phụ) — **giai đoạn 2 của roadmap**, không bắt buộc | ngay từ đầu |

**Tương thích**: node có `match_id` thuộc `matches` → encounter 1 quái `{enemies: [{id: match_id}]}` (sinh trong `RunConfig.from_node`, không chạm data cũ). Node có `match_id` thuộc `formations` → đội hình. `pools.formation` vắng → generator không bao giờ rút đội hình (6 region v1 giữ y nguyên).

### 5.2 Match params đưa vào CombatView

`RunConfig._clean_match` thêm whitelist `enemies` (mảng dict đã clean: `id, slot, role, required, hp_mult, defense_add, tempo_mult, traits, brain, enemy, pattern_tempo_mult, boss_max_hp, boss_defense, boss_min_runes, brain_set, movement, swing_speed_mult…` = chính các `MATCH_KEYS` áp cho từng unit) và `attack_slots`. Các khoá boss-level cũ (`boss_max_hp`, `traits`, …) ở gốc match_params **giữ = unit 0** để mọi `match_params.get("boss_*")` (bảng 31 khoá ở `combat_view.gd`) tiếp tục đúng.

Floor scaling: `_apply_scaling` chạy cho từng entry (HP, step, defense, runes/tempo) — một chỗ duy nhất, như hiện nay.

### 5.3 Spawn slots (theo nửa enemy, toạ độ side)

Định nghĩa trong `arenas.json` mỗi shape (tuỳ chọn; thiếu → suy từ `default_enemy_anchor` của từng unit, loại ô unit trước):

```jsonc
"spawn_slots": {"front_top": [3,0], "front_mid": [3,1], "front_bottom": [3,2], "back_top": [1,0], "back_mid": [1,1], "back_bottom": [1,2]}
```
(side coords: col 0 = xa divider nhất; dùng `BoardGrid.to_side_coords`). Quy tắc: Tank/Attacker cận chiến ở `front_*`, Disruptor/"Support" ở `back_*`; footprint 2×2 chiếm `front_mid`+`back_mid` hàng kế.

### 5.4 World Map v2 và save

- `MapGraph` node: thêm khoá tuỳ chọn `enemies: [{id, slot, role}]` + `formation_id` (giữ `match_id` = `formation_id` để preview/`record_death`/`boss_fates` không đổi). `schema` 2 → thêm khoá tuỳ chọn, **không cần nâng `SAVE_VERSION`** (đọc thiếu = 1 quái). Nếu đổi `RunSession.SAVE_VERSION` 8→9 thì `MIN_LOADABLE_VERSION` giữ 8.
- `EncounterComposer.profile` thêm `enemies` vào profile; `apply_to_raw` áp `match_patch` cho **mọi** entry (trait modifier như `row_burner` → mặc định unit 0; thiết kế có thể gắn `modifier_target: "all" | "first" | "role:disruptor"` trong `region_rules.json modifiers`).
- `preview()` trả `enemy_name_keys: []` + `formation_name_key` để `WorldMapView` hiện "Tiểu Quỷ ×2" hay tên đội hình.
- Save không lưu mid-combat → không có "load giữa bầy quái".

---

## 6. Ảnh hưởng UI / AI (implications)

### 6.1 UI

| Hạng mục | Thay đổi |
|---|---|
| `UnitLayer` | bảng theo unit_key; `_draw` lặp `[player] + units` (sort giữ); `unit_ids_for` → `[character.id] + [e.id for e in enemies]`; `_on_damaged(key)`; placeholder quad đỏ **per unit** (sprite chờ session asset) |
| HP plate | `_draw_hp_plates` lặp unit sống; plate quái phụ nhỏ hơn (ví dụ 80 %), boss giữ cỡ |
| Chips Hàn/Rạn/Guard/Mark | theo unit, dưới plate của unit |
| Damage number | `_boss_feedback` → mảng; mỗi unit trúng một số tại `unit.hit_cell` (đã có offset chống đè? — chưa; thêm lệch 6 px theo index) |
| Telegraph | gộp tập ô đỏ của mọi agent; **không** tô màu theo unit (một màu đỏ, art bible); sọc queued giữ; khi vượt F2 chung thì agent không được xin thẻ |
| Forecast xanh/đỏ (`_draw_preview`) | `enemies_in(cells)` → tô viền từng unit sẽ trúng; "×2" nhỏ khi trúng ≥ 2 |
| Corner panel (`hud.corner_panels` mặc định false) | giữ cho unit 0 (boss); không mở rộng |
| Tên trong intro | `RunConfig.match_name` → tên đội hình, hoặc "A, B & C" |
| Pause panel (`run_hud_view.gd:898`) | dòng "boss đang vung" → unit đầu tiên đang swing |
| Audio | cue windup/warning từ bất kỳ agent (`ThreatBoard` phát signal gộp) |
| Dev (`demo_args.gd`, 29 caller) | giữ `get_boss()` = unit 0; thêm `--formation=<fid>` |

### 6.2 AI

- **Thẻ tấn công (`attack_slots`)**: `ThreatBoard.request_token(agent) -> bool`; trả khi swing resolve/cancel/feint. Normal 1 thẻ: đội hình 2–3 quái vẫn chỉ 1 đòn tới cùng lúc → damage nhận ≈ hiện tại + áp lực đổi hướng. Hard/Elite 2 thẻ với `min_gap_between_warnings_sec` chung (0.4 s) + trần đỏ chung 0.5.
- **Unit không có thẻ** vẫn: di chuyển (`BossBrain._plan_move`), nhặt khối (block brain), self-skill không-đe-doạ (`brace`, `creep`, `witch_shift`…), đặt marker. Thiết kế này khiến Tank/Disruptor "bận" mà không tăng DPS.
- **Think interval**: `boss_think_interval_sec` của từng unit × `sqrt(N)` để tổng số quyết định/giây không tăng tuyến tính (knob `formation.think_mult`, mặc định `sqrt(N)`).
- **Occupancy**: `extra_own_blocked_fn` nhận ô của unit khác; `UnitMover.add_blocker` thêm occupancy; `PatternPlanner enemy_half_empty` nhận `cell_ok_fn` loại ô unit khác.
- **Drops dùng chung**: một `FieldDrops(enemy_cells)`; `max_on_field` không nhân N; mỗi block-brain unit có `HoldSlots` riêng, nhặt ô mình bước lên (`_on_cell_changed(key == my key)`).
- **Learning**: 1 `BossLearning`/unit (feint/dodge streak riêng), hoặc 1 chung cho cả bầy (đơn giản hơn; đề xuất chung ở bước 3, tách sau nếu cần).
- **Trait**: `TraitHost` 1/unit, ctx.boss = controller của unit, hook `death/untargetable/burn_heal` khoá unit. `row_burner`/`vent_surge`/`thorn_field`/`seal_caster` (chỉ chạm nửa người chơi) chạy nguyên; `boss_phases`/`rebirth`/`burrow`/`hop_skip`/`shroud` cần đọc `unit` thay `state.enemy_*`.
- **Parry**: `ParryGuard.try_parry(..., attacker_key)` phản đòn đúng unit (pattern resolve biết agent; block-brain qua `SwingArbiter` event `side`→`key`).
- **Hiệu năng**: N ≤ 4 RefCounted agent tick/khung, `BossBrain.decide` chỉ chạy mỗi `think_interval`; `_anchor_space`/`_bfs` trên nửa sân ≤ 24 ô → không đáng kể. `FairnessCheck.escape_path` BFS nhỏ. Rủi ro hiệu năng thấp; đo bằng `tools/balance/sim_core.gd` headless (xem §8.6).

---

## 7. Đội hình mẫu theo region (sample encounters)

**Nguyên tắc**: chỉ dùng id đã có trong **pool** của region (orphan ch1 `wolf/goblin_chief/goblin_warrior/goblin_shaman/goblin_brute` không dùng). Vai trò suy từ skill/trait thật (bảng vai trò dưới). **Không tồn tại quái Support** (không quái nào hồi/buff đồng minh): mục "Support" trong đội hình mẫu dùng Tank-tự-guard (`mossbound_sentry brace`, `mistbriar_matron wreath_guard`) hoặc Disruptor kiểm soát; muốn Support đúng nghĩa cần **trait mới** (`pack_guard`: guard cho đồng minh trong hàng; `pack_mend`: hồi theo tick khi đứng cạnh) — ngoài scope "không tạo quái mới" nhưng không tạo quái, chỉ tạo trait; đề xuất để sau.

Tổng HP tham chiếu: hệ số Normal 2 quái ≈ 0.55 + 0.55 = 1.1 × một normal; 3 quái ≈ 0.45 × 3 = 1.35; Hard 3–4 quái ≈ 1.6–1.8 (ngang danger budget 1.6 của D8 `phase2-misty-forest §5.5`); Elite = 1.0 elite + 0.3–0.4 × 2; Boss = boss + 0.3 × quái phụ. Số `hp_mult` dưới là điểm khởi đầu cho sim.

### 7.1 Bảng vai trò (từ data thật)

| Vai trò | Pattern brain (`enemy_skills.json`) | Block brain (trait / `boss_defense`) |
|---|---|---|
| Attacker | goblin_scout, goblin_archer, dire_wolf, wolf_alpha (haste tự thân) | imp, ember_hound, magma_slug, bog_rat, swamp_lizard, marsh_toad, mire_slug (mire_immune), dune_jackal, dust_nomad, mirage_sprite, skeleton, zombie, bat_swarm, slime, cultist, frost_sprite, wisp, stone_sentry, snow_wolf, rime_archer, cloud_sprite, harpy, wind_monk, storm_eagle, fuse_golem (`fuse_cannon` 12 s) |
| Tank | mossbound_sentry (`brace` guard 3/3 s), mistbriar_matron (`wreath_guard` 5) | ash_golem (def 3), hell_knight (def 2, runes 3), sky_sentinel (def 3), sand_beetle (def 2), scarab_guard (def 2), ghost (def 12 / 24 HP), ghost_elite (def 16 / 36 HP), fire_eater (`burn_eater`), ash_phoenix (`rebirth`), scorpion (`riposte`) |
| Disruptor | rootling (root), greycap_sporeling (thorns + Rạn), ancient_root_sentinel (marker, root, hole) | row_burner: flame_cultist, bog_hound, sun_archer, thunder_shaman, rat_king_guard, ice_golem; reed_witch (`rotten_thrower`), reacter (`step_reactor`), spore_cap (`spore_burst`), gale_bird (`gust`), cloud_veil (`shroud`), frost_mage (`frost_aura`+`thorn_field`), leap_frog (`hop_skip`), sand_burrower (`burrow`) |
| Support | **không có** | **không có** |

### 7.2 Đội hình mẫu

Ký hiệu: `id ×hp_mult [role]`; sân = `arena.shape` (ô thật/nửa); thẻ = `attack_slots`.

| Region | Type | Đội hình | Sân | Thẻ | Ghi chú |
|---|---|---|---|---|---|
| **hellfire** (Thành Hỏa Ngục) | Normal | imp ×0.55 [atk] + ember_hound ×0.55 [atk] | forge (15) | 1 | = ví dụ brief; cả hai pool battle 0 |
| | Normal | ember_hound ×0.5 + imp ×0.5 + imp ×0.4 | caldera (22) | 1 | "bầy" 3 quái nhỏ, floor ≥ 2 |
| | Hard | hell_knight ×0.8 [tank, required] + flame_cultist ×0.5 [disruptor row_burner] + imp ×0.4 [atk] | caldera (22) | 2 | = ví dụ brief (Hell Knight + Imp + Ash Golem) nhưng thay Ash Golem bằng Flame Cultist để có Disruptor; biến thể: hell_knight + ash_golem ×0.5 [tank] + magma_slug ×0.5 |
| | Elite | fire_eater ×1.0 [tank burn_eater] + imp ×0.35 + ember_hound ×0.35 | forge (15) | 2 | fire_eater hồi từ lửa → quái phụ Attacker buộc người chơi chọn mục tiêu |
| | Elite | ash_phoenix ×1.0 [rebirth] + flame_cultist ×0.4 [disruptor] | caldera (22) | 2 | |
| | Boss | inferno_lord ×1.0 [vent_surge, phase_shift] + (pha 2) imp ×0.3 ×2 `spawn_at phase 2` | caldera (22) | 2 | cơ chế riêng = Heat/vent (đã có) + quái phụ pha 2 (roadmap bước 7) |
| **swamp** (Đầm Lầy Độc) | Normal | marsh_toad ×0.55 + mire_slug ×0.55 [mire_immune] | bog (13) | 1 | = ví dụ brief |
| | Normal | bog_rat ×0.4 ×3 | bog (13) | 1 | bầy chuột |
| | Hard | reed_witch ×0.6 [disruptor rotten_thrower] + bog_hound ×0.6 [disruptor row_burner] + swamp_lizard ×0.5 [atk] | reed_maze (17) | 2 | ví dụ brief "Toad Matriarch + Reed Witch + Bog Rat" không dùng được vì toad_matriarch là **boss** (pool boss) — thay bằng reed_witch + bog_hound + lizard |
| | Elite | spore_cap ×1.0 [disruptor spore_burst] + marsh_toad ×0.4 + bog_rat ×0.35 | bog (13) | 2 | |
| | Elite | leap_frog ×1.0 [hop_skip] + mire_slug ×0.4 [mire_immune] | reed_maze (17) | 2 | |
| | Boss | toad_matriarch ×1.0 [bog_spread, seal_caster] + bog_rat ×0.3 ×2 | bog (13) | 2 | sân 13 ô: boss 1 ô + 2 chuột = 3 ô, OK |
| **desert** (Sa Mạc Cát Vùi) | Normal | dune_jackal ×0.55 + sand_beetle ×0.55 [tank def2] | dunes (18) | 1 | |
| | Hard | scarab_guard ×0.7 [tank] + sun_archer ×0.6 [disruptor] + mirage_sprite ×0.45 | oasis (24) | 2 | |
| | Elite | scorpion ×1.0 [riposte] + dust_nomad ×0.4 ×2 | oasis (24) | 2 | riposte phạt cast ≥ 4 ô; quái phụ ép cast lớn → xung đột có chủ ý |
| | Elite | sand_burrower ×1.0 [burrow] + sand_beetle ×0.4 | dunes (18) | 2 | |
| | Boss | sand_sphinx ×1.0 [sandstorm] + scarab_guard ×0.4 [tank] | oasis (24) | 2 | |
| **sky_isles** (Không Đảo) | Normal | cloud_sprite ×0.55 + harpy ×0.55 | twin_isles (14) | 1 | |
| | Hard | sky_sentinel ×0.7 [tank] + thunder_shaman ×0.6 [disruptor] + storm_eagle ×0.45 | islands_bridge (14) | 2 | 14 ô, 3 unit = 3 ô |
| | Elite | cloud_veil ×1.0 [shroud] + wind_monk ×0.4 | three_isles (12) | 2 | |
| | Elite | gale_bird ×1.0 [gust] + harpy ×0.4 ×2 | twin_isles (14) | 2 | |
| | Boss | storm_dragon ×1.0 [island_drop, gust] + cloud_sprite ×0.3 (pha 2) | islands_bridge (14) | 2 | |
| **ch1** (Rừng Sương, pattern brain) | Normal | rootling ×0.55 [disruptor root] + goblin_scout ×0.55 [atk] | square (9) | 1 | sân 9 ô: tối đa 2 unit |
| | Normal | mossbound_sentry ×0.5 [tank brace] + goblin_archer ×0.5 [atk lane] | rect (12) | 1 | archer đánh hàng dài, sentry chắn trước |
| | Hard | goblin_archer ×0.6 + greycap_sporeling ×0.55 [disruptor thorns] + rootling ×0.45 | rect (12) | 2 | |
| | Elite | ancient_root_sentinel ×1.0 [disruptor marker] + rootling ×0.35 + mossbound_sentry ×0.35 | rect (12) | 2 | trùng `teach_after [rootling, mossbound_sentry]` → dạy trước, gặp cùng sau |
| | Elite | mistbriar_matron ×1.0 [tank wreath] + greycap_sporeling ×0.4 | cross (12) | 2 | |
| | Boss | forest_witch 2×2 ×1.0 (một mình) | boss_hall (24) | 2 | marker/anchor của Witch đã dày; không thêm quái phụ |
| | Boss | goblin_warlock 2×2 ×1.0 + goblin_scout ×0.3 (pha 2) | boss_hall (24) | 2 | |
| **ch2** (Hầm Ngục) | Normal | skeleton ×0.55 + zombie ×0.55 | square (9) | 1 | |
| | Hard | rat_king_guard ×0.7 [disruptor] + cultist ×0.5 + bat_swarm ×0.45 | ring (21) | 2 | |
| | Elite | reacter ×1.0 [step_reactor] + ghost ×1.0 [tank def12/24HP] | cross (12) | 2 | ghost ít HP nhiều giáp, đứng trước |
| | Elite | jailer ×1.0 [rotten_thrower, row_burner, seal_caster] + skeleton ×0.4 | u_shape (11) | 2 | jailer là miniboss duy nhất |
| | Boss | ogre_king ×1.0 [slam] + slime ×0.4 | ring (21) | 2 | |
| **ch3** (Tháp Sương) | Normal | frost_sprite ×0.55 + wisp ×0.55 | square (9) | 1 | |
| | Hard | ice_golem ×0.7 [disruptor] + stone_sentry ×0.55 + snow_wolf ×0.5 | pillars (21) | 2 | |
| | Elite | frost_mage ×1.0 [frost_aura, thorn_field] + ghost_elite ×1.0 [tank def16] | diamond (13) | 2 | |
| | Elite | fuse_golem ×1.0 [fuse_cannon] + rime_archer ×0.45 | rect (12) | 2 | |
| | Boss | mist_lord ×1.0 [frost_aura, phase_shift] + frost_sprite ×0.3 ×2 (pha 2) | pillars (21) | 2 | |
| **an_dai** | Boss | an_dai_keeper ×1.0 (một mình) | an_dai_dais (20) | 2 | 2 pha có sẵn; không đổi |

Ghi chú cân bằng: `hp_mult` là nhân **sau** `region_normalize × floor_scaling` (D8 budget giữ); `boss_defense` theo template; `boss_min_runes` của Tank (hell_knight 3) giữ để cast khối lớn.

---

## 8. Rủi ro và cân bằng (risks & balance)

### 8.1 Combat balance và thời lượng trận

- Hiện tại một trận 2–4 phút (`03-encounter-system.md §1`), Witch 136–231 s (`active.md`), sim bot dodge 0.85 (`run-v6-balance`). Mục tiêu: **giữ tổng HP encounter ≈ 1.0–1.35× một normal** (Normal) và **≤ 1.8×** (Hard) theo ngân sách D8 §5.5 để thời lượng không tăng quá 25 %. Multi-enemy phải là áp lực **không gian và chọn mục tiêu**, không phải "nhiều HP hơn".
- Lợi ích tự nhiên cho người chơi: khối lớn/zone (`hoa_*`, `tran_gai`, `dia_chan`) trúng nhiều unit → giá trị AoE tăng; cần sim để Rạn/execute không bị lệch (execute threshold theo HP từng unit nhỏ → dễ execute).
- Rủi ro: quái nhỏ `hp_mult 0.35` chết trong 1–2 cast → "đi qua"; đặt sàn HP tối thiểu (vd ≥ 0.3 × normal).

### 8.2 Độ khó và damage nhận

- Không hãm: DPS địch ≈ ×N (mỗi agent có `CutActor` riêng). **Thẻ tấn công** (§6.2) là nút chính: Normal 1 thẻ → damage nhận ≈ hiện tại; Hard/Elite 2 thẻ → ≈ ×1.5–1.8 với gap chung 0.4 s + trần đỏ 0.5 chung; sim kiểm `Mean boss hit 4–15 % max HP` (tiêu chí `simulation-run-v6.md:42`).
- F1 (lối thoát): `FairnessCheck.escape_path` phải chạy trên **hợp** các ô đỏ của mọi agent; `ThreatBoard` cung cấp.
- Block-brain combo (`combo_chance`) + pattern followup cùng lúc có thể vượt trần → thẻ đếm cả combo/followup như một đòn kéo dài.

### 8.3 Arena layout và spawn

- Ô thật/nửa (từ `arenas.json`): square 9, staircase 10, u_shape 11, rect/cross/three_isles 12, bog/diamond 13, islands_bridge/twin_isles 14, forge 15, reed_maze 17, dunes 18, an_dai_dais 20, ring/cross_wide/pillars 21, caldera 22, oasis/boss_hall 24. `rules.min_cells_per_side 6`.
- Người chơi cần chỗ **đặt khối** trên nửa enemy: khối 1–5 ô, odd block tới 7 (`field_drops.json odd_blocks` size_max 7 ở ≥ 16 ô). Unit chiếm ô làm giảm ô đặt tự do → quy tắc: **ô bị unit chiếm ≤ 1/3 ô thật** và **ô trống ≥ 6**.
- Hazards theo shape (vents `forge/caldera` theo hàng/cột, mire `bog/reed_maze` 3–4 ô, sand 2 ô, crumble) cũng chiếm ô của unit → kiểm `enemy_fits(blocked_fn)` với mọi unit tại spawn; nếu không fit → giảm số unit (log problem, không crash).

### 8.4 Số enemy tối đa đề xuất

| Ô thật/nửa | Shape | Max ô unit | Đội hình cho phép |
|---|---|---|---|
| 9 | square | 2 | Normal 2 |
| 10–12 | staircase, u_shape, rect, cross, three_isles | 3 | Normal 2–3, Hard 3, Elite 1+2 |
| 13–15 | bog, diamond, twin_isles, islands_bridge, forge | 3 (Hard 4 chỉ nếu ≥ 6 ô trống sau hazards) | Boss 1 + 2 |
| 17–21 | reed_maze, dunes, an_dai_dais, ring, cross_wide, pillars | 4 | Hard 4 |
| 22–24 | caldera, oasis, boss_hall | 4 (boss 2×2 + 0 phụ, hoặc boss 1 ô + 2–3 phụ) | Boss 2×2 + 1 phụ = 5 ô: chấp nhận chỉ ở boss_hall/oasis |

**Trần toàn cục: 4 unit, 5 ô unit.** Hard 4 quái chỉ từ 17 ô. Đây là trần kỹ thuật/đọc được; cân bằng có thể thấp hơn.

### 8.5 Target selection

Không có UI chọn mục tiêu (touch-first): mục tiêu = vị trí khối. Rủi ro: người chơi "vô tình" đánh quái phụ thay vì Tank; đó là ý đồ (Tank chắn trước). Forecast phải hiện rõ **unit nào sẽ trúng** (viền + số "×2").

### 8.6 AI và hiệu năng

- Rủi ro quyết định dẫm nhau (hai agent cùng muốn một ô): `extra_own_blocked_fn` + occupancy blocker; thua thiệt nhỏ chấp nhận (agent sau chờ).
- Pattern marker (Sentinel anchor) của một unit + ô đỏ của unit khác trên cùng hàng: `ThreatBoard` gộp; F2 chặn.
- Hiệu năng: N ≤ 4; đo bằng `tools/balance/sim_core.gd` (headless) trước/sau; tiêu chí `max_tick_sec 0.1` không bị kẹt trên Android.

### 8.7 Reward / drop

Giữ theo node (`economy.json gold_drops` theo kind; `reward_tiers` theo tier). Đội hình Hard dùng kind `danger`/tier 2; không thưởng per-kill. Objective `no_hit_3`, `joiner`, `big_cast` vẫn đúng; thêm objective mới `multi_hit` (một cast trúng ≥ 2 unit) qua `get_match_stats()` (đếm trong `_on_swing_resolved`).

### 8.8 Save / load

Không lưu mid-combat → không đổi. Node lưu `formation_id` (đặt vào `match_id` để tương thích) + `enemies[]` tuỳ chọn. `RunSession.record_death` dùng `boss_name_key` → tên đội hình. `MapValidator._check_pools` (`src/run/map/map_validator.gd:142-153`) kiểm mọi node đánh nhau có `match_id` nằm trong `spec.pools[kind][tier]` hoặc `spec.match_ids` → khi node rút từ `pools.formation`, spec truyền vào validator phải gộp formation id vào `match_ids` (hoặc thêm kind-pool `formation`), nếu không save sẽ bị drop lúc load (`RunSession` gọi validate khi nạp `map_graph`).

### 8.9 Rủi ro tổ chức

- **Quyết định thiết kế ngược với `03 §1`**: cần người dùng duyệt "lật D-03§1, thực hiện D7 Phase 3".
- **Sprite**: 52 quái ngoài ch1 chưa có sheet (session "region enemy visual assets"); đội hình nên **prototype trên ch1** (11 sheet có sẵn) để đánh giá "nhìn" đúng chuẩn `run-and-observe`.
- Hai session đang sửa `src/art/*`, `src/battle/floor_layer.gd`, `support_layer.gd`: roadmap bước 4 (UnitLayer/CutHud) không chạm các file đó.

---

## 9. Lộ trình triển khai theo giai đoạn nhỏ (roadmap)

Mỗi bước: encounter 1 quái **không đổi hành vi**; chạy `GODOT=… bash tools/qa/run_all_tests.sh out.txt` (271 test xanh làm baseline) + test mới của bước; story chạm thứ nhìn thấy → ảnh chụp `production/qa/evidence/multi-enemy/`.

| Bước | Nội dung | File chính | Test / bằng chứng | Cỡ |
|---|---|---|---|---|
| **0. Data schema (an toàn)** | Thêm `formations`, `pools.formation`, `spawn_slots` vào `schema.md`; `ChaptersConfig` parse `formations` (validate id ∈ matches, slot ∈ arena); `RunConfig._clean_match` whitelist `enemies`/`attack_slots`; `from_node` sinh `enemies = [{id: match_id}]` khi node là match thường. CombatView **chưa đọc** `enemies` | `chapters_config.gd`, `run_config.gd`, `schema.md`, `chapters.json` (chỉ thêm khối, có thể để trống) | `tests/unit/run/formations_config_test.gd` (parse, lỗi id, tương thích flat); toàn bộ suite xanh | S |
| **1. CombatState → units** | `EnemyUnit`; `units: Array`; mọi `enemy_*` thành proxy tới `units[0]`; `is_enemy_dead()` = all required dead; `enemies_in`, `damage_unit`, `unit_died`, `enemy_fits(…, unit)` loại ô unit khác; `damaged(key)` với key 1 = enemy 0 | `combat_state.gd` (+ `enemy_unit.gd`) | `combat_state_units_test.gd`: 1 unit = hành vi cũ (so sánh log với `state_damaged_signal_test`), 2 unit: victory, occupancy, `enemies_in`; 81 test `CombatState.new(` xanh không sửa | M |
| **2. Resolve & status theo unit** | `SwingArbiter._actors` khoá unit_key; `_settle/_fire_event` lặp `enemies_in`; interrupt theo unit; `unit.defense`; `CutEffects` nhận `target_key`; `StatusEffects` sổ unit khoá unit_key, `_units_on` lặp units; `TileHazards` timer theo unit; `ParryGuard`/`ZoneRules` nhận key | `swing_arbiter.gd`, `cut_effects.gd`, `status_effects.gd`, `tile_hazards.gd`, `parry_guard.gd`, `zone_rules.gd` | `multi_hit_test.gd` (một cast trúng 2 unit, mỗi unit 1 lần, defense riêng, interrupt đúng actor), `status_per_unit_test.gd` (pin unit 1 không pin unit 2); các test cut/parry/hazard cũ xanh | L |
| **3. Agents & ThreatBoard** | `EnemyAgent`; `CombatView._ready` build N agent từ `match_params.enemies` (vắng → 1); một `FieldDrops` nửa enemy tiêm vào controller; `BossController(unit, shared_drops)`; `BossBrain` ctx `my_cell/other_cells`; `PatternController(unit)`; `ThreatBoard` + thẻ tấn công + F2/F5 chung; `_process` lặp agent; unit chết → agent tắt | `combat_view.gd`, `boss_controller.gd`, `boss_brain.gd`, `pattern_controller.gd`, `unit_mover.gd` (+ `enemy_agent.gd`, `threat_board.gd`) | `pattern_pack_fairness_test.gd` (2 pattern agent: tổng đỏ ≤ 0.5, gap ≥ 0.4, perfect dodger 0 dmg như `pattern_roster_dodge_test`), `attack_tokens_test.gd`, `pack_determinism_test.gd` (cùng seed → cùng log); `sim_core.gd --formation=` chạy 30 seed | L |
| **4. Presentation** | `UnitLayer` theo unit (sheet, anim, hit, placeholder); `CutHudView` HP plate/chips/feedback theo unit; `FloorLayer.telegraph_state` gộp; forecast "×2"; `_boss_feedback` → mảng; audio bridge gộp | `unit_layer.gd`, `cut_hud_view.gd`, `floor_layer.gd`, `floor_dynamic_layer.gd`, `overlay_layer.gd`, `combat_audio_bridge.gd` | Story UI/Visual → **ảnh chụp** `production/qa/evidence/multi-enemy/` (windowed, `--audio-driver Dummy`), test `cut_hud_multi_plates_test.gd`; `boss_downed_test` xanh | M |
| **5. Traits per unit** | `TraitHost` 1/unit, ctx.boss = controller unit, hook death/untargetable/burn_heal theo unit; `boss_phases`, `rebirth`, `burrow`, `hop_skip`, `shroud`, `frost_aura`, `phase_shift`, `seal_caster`, `step_reactor` đọc `unit` | `src/traits/*` | `region_traits_test` xanh; `rebirth_in_pack_test.gd` (phoenix hồi sinh không giữ cả bầy ở 1 HP) | M |
| **6. World Map & data thật** | `EncounterComposer.profile/apply_to_raw/preview` với `enemies`; `RegionMapGen/ChapterMapGen._draw_match` rút từ `pools.formation` theo `formation_weight` của archetype slot; `MapGraph`/`MapValidator`/`RunSession` chấp nhận formation id; `WorldMapView` preview tên đội hình; viết `formations` cho **hellfire** (v2) và **ch1** (sprite có sẵn) từ §7.2 | `encounter_composer.gd`, `region_map_gen.gd`, `chapter_map_gen.gd`, `map_validator.gd`, `run_session.gd`, `world_map_view.gd`, `chapters.json`, `arenas.json` | `map_gen_formations_test.gd`, `run_session_v8_formation_roundtrip_test.gd`; `deck_sim --run=v6` 70 seed so với baseline `run-v6-balance` (win %, mean hit %) | M |
| **7. Boss + quái phụ muộn** | `spawn_at {phase}` / `{below hp_ratio}`: `CombatState.add_unit` giữa trận, agent tạo động, HUD plate mới | `combat_state.gd`, `combat_view.gd`, `boss_phases.gd` | `late_spawn_test.gd`; ảnh pha 2 inferno_lord | M |
| **8. Cân bằng & QA** | sim 30–70 seed/region; Android device QA (`production/qa/android-device-qa-*.md`); chỉnh `hp_mult`/`attack_slots` | `chapters.json` | `production/qa/evidence/multi-enemy/simulation-*.md`, `smoke-check` | M |

Có thể dừng sau bước 3 (gameplay chạy được với quad đỏ, test headless) để quyết định tiếp; bước 4–5 độc lập nhau; bước 6 cần 0–5.

**Phụ thuộc với session khác**: bước 4 chỉ sửa `unit_layer.gd`, `cut_hud_view.gd`, `floor_layer.gd:140-205` (telegraph/pattern extras) — `floor_layer.gd` đang được session arena sửa phần vẽ sàn (`paint_rim_strip`…), nên bước 4 nên chờ commit của session đó hoặc tách `telegraph_state` sang file riêng trước.

---

## 10. Files likely to be modified

| Nhóm | File | Thay đổi | Bước |
|---|---|---|---|
| Lõi state | `src/combat/combat_state.gd` | units, proxy, victory, `enemies_in`, occupancy | 1 |
| | `src/combat/enemy_unit.gd` (mới) | dữ liệu một unit | 1 |
| Resolve | `src/combat/swing_arbiter.gd` (`:86, :98, :128-151, :311-381, :496-700`) | actors theo unit, hit nhiều unit, interrupt, defense | 2 |
| | `src/combat/cut_effects.gd` (`:93-94, :168-170, :362, :384, :460-466, :547-570, :735-740, :766-790`) | `target_key` | 2 |
| | `src/combat/status_effects.gd` (`:86-97, :156-162, :364, :1106-1150, :1213-1266, :1309-1335`) | sổ unit, `_units_on` | 2 |
| | `src/combat/tile_hazards.gd` (`:64-92, :929-935, :1011-1025`) | timer theo unit | 2 |
| | `src/combat/parry_guard.gd` (`:84-108`), `src/combat/zone_rules.gd` (`:24, :82-88`), `src/combat/crit_rules.gd` (3 chỗ `enemy_*`) | key | 2 |
| Agent | `src/combat/combat_view.gd` (`:368-522, :1220-1226, :1302-1314, :1345-1419, :2394-2438, :2479-2495, :2539-2592, :2751-2758, :2961-2978, :3611-3641`) | N agent, ThreatBoard, feedback mảng | 3 |
| | `src/combat/enemy_agent.gd`, `src/combat/threat_board.gd` (mới) | | 3 |
| | `src/combat/boss_controller.gd` (`:69-91, :123-150, :356-376`) | unit, shared drops | 3 |
| | `src/combat/boss_brain.gd` (`:245-360, :313-341, :802-835, :1241-1310`) | my_cell, other cells | 3 |
| | `src/combat/pattern_controller.gd` (`:93-110, :202, :258-271, :325-331, :441-485, :574-607, :658-714, :754-780`) | unit, ThreatBoard | 3 |
| | `src/combat/unit_mover.gd` (`:31, :46-74, :102-106`) | key, occupancy | 3 |
| | `src/combat/boss_learning.gd`, `src/combat/focus_controller.gd` | không đổi (1/unit hoặc chung) | — |
| Trình bày | `src/battle/unit_layer.gd` (`:160-214, :421-469, :610-616, :682-726, :768-771, :922-976, :997-1096, :1152-1169`) | theo unit | 4 |
| | `src/combat/cut_hud_view.gd` (`:1341-1342, :1631, :1666, :1885-1908, :2105-2154, :2229-2303, :2755-2826`) | plate/chips/feedback theo unit | 4 |
| | `src/battle/floor_layer.gd` (`:140-205`), `src/battle/floor_dynamic_layer.gd` (`:118-121`), `src/battle/overlay_layer.gd` (`:350-351`), `src/battle/pickup_layer.gd` (`:205-206`), `src/drops/field_drops_view.gd` (`:79`) | gộp telegraph, drops chung | 4 |
| | `src/audio/combat_audio_bridge.gd` (`:37-38, :69-74, :193-196`), `src/run/run_hud_view.gd` (`:898-900`) | gộp cue | 4 |
| Trait | `src/traits/trait_host.gd` (`:22-46, :112-166, :180-231`), `src/traits/boss_trait.gd` (`:12-26`), `boss_phases.gd`, `rebirth.gd`, `burrow.gd`, `hop_skip.gd`, `shroud.gd`, `frost_aura.gd`, `phase_shift.gd`, `seal_caster.gd`, `step_reactor.gd`, `bog_spread.gd` | host/unit | 5 |
| Data & run | `src/run/run_config.gd` (`:11-17, :111-149, :154-179, :221-298, :303-316`) | whitelist, enemies, scaling per unit | 0 |
| | `src/run/chapters_config.gd` | `formations`, `pools.formation` | 0 |
| | `src/run/map/encounter_composer.gd` (`:19-58, :75-120, :145-175`), `src/run/map/region_rules.gd` (`:301-320` `_clean_patch`) | enemies, modifier_target | 6 |
| | `src/run/map/region_map_gen.gd` (`:103-152`), `src/run/chapter_map_gen.gd` (`:451`), `src/run/map/map_validator.gd`, `src/run/map/map_graph.gd` | rút formation, validate | 6 |
| | `src/run/run_session.gd` (`:356-361, :883-931, :1085-1110, :1255`), `src/run/game_flow.gd` (`:1078-1088, :2415-2451, :2580-2600`), `src/run/world_map_view.gd`, `src/run/run_controller.gd` (`:317-360`) | formation id, preview | 6 |
| | `assets/data/chapters.json`, `assets/data/arenas.json` (`spawn_slots`), `assets/data/schema.md`, `assets/i18n/strings.csv` (`formation.<id>.name`) | data | 0, 6 |
| Dev/test | `src/dev/demo_args.gd` (`--formation=`), `tools/balance/sim_core.gd`, `tools/balance/deck_sim.gd` | mô phỏng đội hình | 3, 8 |
| Tài liệu | `docs/design/world-map-v2/03-encounter-system.md §1` (lật quyết định), `README.md:38`, `design/game-mechanics.md`, ADR mới (`docs/architecture/adr-000X-multi-enemy-encounters.md`) | | 0 |

**Không đổi**: `BoardGrid`, `PatternBrain`, `PatternPlanner`, `FairnessCheck`, `CutActor`, `HoldSlots`, `PlacementController`, `RewardRoller`, `economy.json`, `rewards.json`, `enemy_skills.json` (chỉ thêm khoá tuỳ chọn nếu cần), định dạng save v8 (chỉ thêm khoá tuỳ chọn).

---

## Phụ lục A. Nguồn đã kiểm chứng

- Code: `src/combat/combat_state.gd` (toàn bộ), `combat_view.gd` `:368-600, :1296-1420, :2470-2540`, `swing_arbiter.gd :135-145`, `boss_controller.gd :1-91, :356-360`, `unit_mover.gd :1-63`, `pattern_controller.gd :47, :455-456`, `status_effects.gd :83-88, :1309-1319`, `unit_layer.gd :997-1012`, `board_grid.gd :1-60`; các số dòng khác do 4 lượt audit song song (lifecycle, UI, AI/status, data) đọc và được tôi kiểm chéo bằng grep đếm theo file.
- Data: `assets/data/chapters.json` (dump toàn bộ 8 chapter), `arenas.json` (ô thật/nửa tính bằng script), `enemy_skills.json`, `region_rules.json`, `route_archetypes.json`, `rewards.json`, `economy.json`, `characters.json` (HP hero 180–210), `schema.md`.
- Tài liệu: `docs/design/world-map-v2/00, 02, 03, 04, 05, README`, `design/quick-specs/phase2-misty-forest-2026-11-01.md` (D7, D8, §5.5), `production/qa/evidence/run-v6-balance/simulation-run-v6.md`, `production/session-state/active.md`, hand-over notes của session "region enemy visual assets" và "world map v2 design".
