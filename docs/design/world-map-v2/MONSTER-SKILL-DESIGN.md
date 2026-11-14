# Monster Skill Design — toàn bộ roster, 8 vùng

**Ngày:** 2026-11-13 · **Trạng thái:** Proposed (thiết kế, chưa implement) · **Phạm vi:** audit code + thiết kế skill cho
73 match id trong `assets/data/chapters.json`. Không đổi stats, trait, pool, id. Không tạo asset.
**Đọc cùng:** `docs/skill-v2/02-mechanics-catalog.md` (vốn effect của người chơi), `docs/art/FLOOR-MAP-ROSTER.md` (roster theo tầng),
`docs/design/world-map-v2/03-encounter-system.md` (encounter profile), `assets/data/schema.md` §"Phase 2 (P2.2)" (schema `enemy_skills.json`),
`docs/design/world-map-v2/MULTI-ENEMY-ENCOUNTER-AUDIT.md` (session anh em, đang viết — kiến trúc nhiều enemy).

**Quy ước trạng thái trong tài liệu**

| Nhãn | Nghĩa |
|---|---|
| **EXISTS** | có trong code và đang chạy trong game (có file:line) |
| **PARTIAL** | có một phần: API có nhưng không ai gọi, hoặc có bug, hoặc chỉ có cho một phía |
| **MISSING** | không tìm thấy implementation — mọi skill dùng nó là **đề xuất**, không phải chức năng sẵn có |
| **DESIGNED** | skill mới trong tài liệu này, chưa có trong `enemy_skills.json` |
| **EXISTS (forest)** | skill đã có trong `enemy_skills.json` (11 quái Rừng Sương) |

---

## 0. Tóm tắt điều hành

1. **Có hai hệ "não" địch, không phải một.** 11 quái Rừng Sương chạy **pattern brain**: skill khai báo trong
   `assets/data/enemy_skills.json` (34 skill), chọn theo trọng số, có telegraph ô đỏ, fairness F1–F10, phase, marker.
   57 quái còn lại (6 vùng + trận cuối) chạy **block brain**: nhặt khối trên nửa sân mình rồi "cast" khối lên nửa sân
   người chơi bằng chính lá bài của người chơi (`boss_cards`), cộng thêm 0–3 **trait** (22 trait class trong `src/traits/`).
   Block brain **không có khái niệm skill riêng của quái**: hai Imp và Zombie chỉ khác nhau ở số và trait.
2. **Khuyến nghị kiến trúc:** đưa toàn bộ roster về **pattern brain** (schema `enemy_skills.json` là hệ skill duy nhất có
   sẵn), vùng này sang vùng khác, đúng cách Rừng Sương đã đi (P2.2–P2.4). Trait tick-theo-thời-gian giữ nguyên
   (row_burner, vent_surge, gust, island_drop, sandstorm, bog_spread, fuse_cannon, riposte, spore_burst, burn_eater,
   rebirth, frost_aura, shroud, hop_skip, slam, rotten_thrower); 4 trait móc vào "boss swing" (seal_caster,
   thorn_field, step_reactor, phase_shift) được **chuyển thành skill / phase** trong pattern brain (§5.4).
3. **Vốn effect tái dùng được từ code:** 14 effect dùng ngay (damage, root, slow, pin, fragile, frost, guard, haste, marker,
   move, thorns, drop, burn-cell qua `ignite`, mire/sand/fall qua `TileHazards`) — 7 trong số đó chưa được mở cho skill
   quái và chỉ cần thêm key vào `EnemySkillsConfig` (§5.2). **Cần phát triển mới:** poison (DoT bám người chơi), heal cho
   skill, evade/shroud dạng skill, push/pull người chơi từ pattern skill, điều kiện theo đồng đội, VFX cho skill quái
   (hiện delivery của skill quái **không được đọc** để vẽ), summon (không có đơn vị thứ hai — ngoài phạm vi).
4. **Multi-enemy: engine hiện giữ đúng một enemy** (`CombatState.enemy_hp`, `Side` chỉ có PLAYER/ENEMY, HUD một thanh máu,
   `_tick_end` kết thúc khi `is_enemy_dead()`). Thiết kế phối hợp ở đây chia hai bậc: **Bậc A** chạy được ngay khi có
   nhiều đơn vị vì chỉ dùng trạng thái chung (trạng thái trên người chơi, ô trên sân, guard theo phe); **Bậc B** cần
   id đơn vị (đồng đội chết, máu đồng đội) — phụ thuộc audit của session anh em.
5. **Kiểm kê:** 73 id · 68 nằm trong pool · 5 mồ côi (Rừng Sương, không pool) · 11 đã có skill (EXISTS) · 57 thiết kế mới
   trong tài liệu này (113 skill DESIGNED + 3 skill dùng chung) · 5 đưa vào danh sách review.

---

## 1. Kiến trúc skill / effect hiện tại (audit)

### 1.1 Hai hệ não

| | Pattern brain | Block brain |
|---|---|---|
| Ai dùng | 11 quái `ch1` có `"brain": "pattern"` trong `chapters.json` (goblin_scout, rootling, mossbound_sentry, greycap_sporeling, goblin_archer, dire_wolf, wolf_alpha, ancient_root_sentinel, mistbriar_matron, goblin_warlock, forest_witch) | 57 match còn lại (không có key `brain`) + 5 match ch1 mồ côi |
| Dữ liệu | `assets/data/enemy_skills.json` (skills + enemies + phases), load bởi `src/combat/enemy_skills_config.gd` (từ chối dữ liệu sai, không vá) | `chapters.json` match block (`brain_set`, `boss_cards`, `boss_min_runes`, `traits`, timing) + `boss_brain.json` (3 bộ trọng số) |
| Vòng hành động | `PatternController` (`src/combat/pattern_controller.gd`): IDLE → chọn skill → WINDUP → WARNING (ô đỏ) → resolve → FOLLOWUP → RECOVERY; mover của BossController giữ quái đứng yên khi `is_busy()` | `BossController.tick` → `BossBrain.decide` (`boss_brain.gd:245-397`): chấm điểm **wait / move / cut**; cut = cast khối đang cầm lên nửa sân người chơi qua `CutActor.begin_swing` → `SwingArbiter` → `CutEffects.apply` (cùng pipeline lá bài người chơi, `side = ENEMY`) |
| Telegraph | `warning_sec` riêng, không scale theo tempo; vẽ bằng `FloorLayer.pattern_telegraph_state` + `fx_telegraph_stripe_8.png` | Windup của swing chính là telegraph; thời lượng `0.2 + 0.25 × ô` × `swing_speed_mult` (`cuts.json`, `cut_actor.gd:81`) |
| Sát thương lên người chơi | `effects.damage` phẳng (8–22) → parry → `ward_absorb` → `damage_player` (`pattern_controller.gd:574-597`). **Không** nhân Rạn của người chơi (xem gap G1) | `6 × ô × hệ số lá` (`cut_config.gd:55-56`, `cut_effects.gd:255-384`); Rạn/pin/R2/R3 áp dụng đối xứng |
| Interrupt | Đòn người chơi trúng khi WINDUP/WARNING và `interruptible` → hủy, cooldown × 0.5, có thể stun (`:258-269`) | Swing trúng hủy swing đối phương (`swing_arbiter.gd:372-380`) |
| Phase | `phases[]` với `enter_hp_ratio`, `transition.sec` (bất tử), `on_enter`, `every_nth`, `overrides` | Trait `phase_shift` (1 ngưỡng) hoặc key `phases` → trait `boss_phases` (chỉ `an_dai_keeper`) |
| Trait | Không dùng trait (forest_witch "no traits"); `TraitHost` vẫn được tạo | 0–3 trait / match, `TraitHost` (`src/traits/trait_host.gd`) |

### 1.2 Schema skill hiện có (`enemy_skills.json`, `EnemySkillsConfig`)

- `kind`: `attack` | `self` | `marker` (`enemy_skills_config.gd:11`).
- `pattern.anchor`: `on_player`, `near_player`, `row_of_player`, `column_of_player`, `row_of_anchor`, `fixed`, `self_cell`,
  `enemy_half_empty` (`:12-15`); `offsets`, `variants` (nhiều hình), `rotations`, `clip`/`min_cells`, `must_cover_player`,
  `exclude_player`, `count`, `row: any|player`, `anchor_rows`.
- `effects` (`:248-299`): `damage`, `damage_no_markers`, `status {root, slow, pin, fragile, frost}`, `zone {thorns, drop}`,
  `guard {amount, sec, while_markers}`, `marker {kind, life_sec, break_min_cells, break_stun_sec}`, `haste {cooldown_mult, sec}`,
  `move {to: adjacent_row}`.
- `followup`: `relative_to` ∈ first_cells / first_end / first_center / player / same_cells / first_shift, `delay_sec`,
  `show_with_first`, `requires_anchor`, `exclude_first`, `prefer: anchor_row`.
- `conditions` mà code **thực sự đọc** (`pattern_controller.gd:398-415`): `phases`, `hp_below`, `hp_above`, `once`,
  `requires_anchor`, `player_still_sec`, `player_aimed_within_sec`. Key lạ bị bỏ qua im lặng.
- `delivery {type, origin, travel, impact}`: **bắt buộc khai, nhưng không có code nào đọc để vẽ** cho skill quái
  (`CombatView.delivery_for` chỉ đọc cards.json, `combat_view.gd:3527-3531`; `PatternController.skill_resolved` không có listener).
  Impact hợp lệ: slash, burst, shatter, burn, freeze, poison, knockback, guard, seal, thorns, curse, none (`skill_delivery.gd:41`).
- Enemy: `tier` (normalize nhưng **không ai đọc**), `footprint` (2×2 cho warden rừng), `phases[].traits` (parse nhưng
  **không được tiêu thụ**), `ai` override.
- Key đã parse nhưng vô dụng: `target_side`, `owner`, `name_key`/`counter_key` (chỉ dùng cho strings), `move.to` (luôn ±1 hàng).

### 1.3 Kiểm kê effect (phân loại nghiêm: đã có / một phần / chưa có)

Nguồn: `src/combat/status_effects.gd`, `tile_hazards.gd`, `cut_effects.gd`, `pattern_controller.gd`, `src/traits/*.gd`.

| Effect | Ai đang gây | Lên ai | Cơ chế (file:line) | Trạng thái | Mở cho skill quái? |
|---|---|---|---|---|---|
| Damage trực tiếp | lá người chơi; block boss (cùng lá); pattern `effects.damage` | cả hai | `cut_effects.gd:255-384`; `pattern_controller.gd:574-606` | EXISTS | có |
| Execute ×2 ≤ 25 % | lá `tu_kiem`, Dấu Tử | enemy | `cut_effects.gd:346-356` | EXISTS (người chơi → địch) | không cần |
| **Burn** (lửa trên **ô**, không phải trạng thái đơn vị) | lá lửa; block boss lá lửa; trait `row_burner`; mạch dung nham; signature | đơn vị đứng trên ô, cả hai phía | `StatusEffects.ignite` `:183`; chồng tối đa 3, +2 s/+1 dmg mỗi tầng; `burn_on_entry` | EXISTS | **chưa** — `ZONE_IDS` chỉ có thorns/drop. Thêm `zone.id: burn` = 1 key (§5.2) |
| Poison (DoT bám đơn vị) | — | — | chỉ là tên impact VFX (`skill_delivery.gd:41`) | **MISSING** | cần phát triển (§5.3) |
| Mire (lầy: bước ×1,6, 0,5 dmg/0,5 s) | sân bog/reed_maze; trait `bog_spread`, `spore_burst`; lá `vung_lay` | cả hai | `tile_hazards.gd:296, 344-378`; `TileHazards.add_mire` | EXISTS | chưa — thêm `zone.id: mire` |
| Sand (ô bị lấp, chặn) | sân dunes/oasis; trait `sandstorm` | ô | `tile_hazards.gd:189-200, 386-466`; `add_sand` | EXISTS | chưa — thêm `zone.id: sand` |
| Vent (mạch phun) | sân forge/caldera; trait `vent_surge` | ô | `trigger_vents` | EXISTS | giữ ở trait |
| Crumble / island fall (rơi, đẩy + 8 dmg) | sân sky_isles; trait `island_drop` | nửa người chơi | `tile_hazards.gd:760, 926-946`; `drop_cells` | EXISTS | chưa — thêm `zone.id: fall` |
| Thorns (Bãi Gai 3 s / 6 / +1 Rạn) | lá gai → nửa địch; pattern `seedbed` → nửa người chơi; trait `thorn_field` | cả hai | `apply_thorns` `:787`; `ZoneRules.cast_thorns` | EXISTS | có |
| Drop / Ô rớt (nứt 0,8 → hố, rơi chết) | pattern `bark_shift`; trait `seal_caster` | nửa người chơi | `apply_drop` `:949` qua `ZoneRules.cast_drop` | EXISTS | có |
| Guard (giáp tạm, Xuyên giáp bỏ qua) | pattern `brace`, `wreath_guard`, `moss_guard` | **enemy** (theo **phe**, không theo đơn vị) | `guard(side)` `:1412`; cộng vào `boss_defense` (`swing_arbiter.gd:148,344,563`) | EXISTS (địch) | có |
| Guard cho người chơi | chỉ dev demo | — | `guard_amount(PLAYER)` không được đọc trong công thức | PARTIAL | không cần |
| Ward / Parry | lá người chơi | người chơi | `ward_absorb` `:722`; `parry_guard.gd:84-102` | EXISTS (người chơi) | không |
| Haste (cooldown × k trong N s) | pattern `alpha_howl` | enemy | `pattern_controller.gd:686-689, 721-722` | EXISTS | có |
| Damage up / enrage của địch | — | — | phase chỉ đổi bộ skill, tempo, step | **MISSING** | thay bằng phase + haste |
| Pin / Đóng Băng (đứng im) | lá băng; block boss; pattern `status: pin` (hỗ trợ, **chưa skill nào dùng**) | cả hai | `pin` `:354`; F4 `cc_grace` | EXISTS | có (cổng F4) |
| Root (khóa bước) | pattern `root_prick`, `branch_net`, `root_nail` | người chơi | `root` `:1343` | EXISTS | có |
| Slow (bước ×1,3 / 1,5 s) | pattern `entangled_row`, `rending_rush`, `curse_lane` | người chơi | `slow` `:1391` | EXISTS | có |
| Fragile / Rạn (×1,5 đòn kế, tối đa 3) | lá; pattern `spore_squares`, `hex_bolt`; thorns | cả hai | `apply_fragile` `:242-284` | EXISTS | có, **nhưng** damage pattern không nhân Rạn của người chơi (G1) |
| Frost / Giá Lạnh (3 tầng nổ 24) | lá băng; pattern `status: frost` (hỗ trợ, chưa dùng) | enemy (dùng); người chơi (có đường code) | `apply_frost` `:290-304` trả về damage nổ, **`pattern_controller.gd:627` vứt giá trị trả về** | PARTIAL trên người chơi (G2) | có sau khi sửa G2 |
| Stun (đứng im, hủy skill) | marker break, `interrupt_stun_sec` | **enemy** | `pattern_controller.gd:292-302` | EXISTS | — (stun người chơi = pin/root) |
| Weakness (gây ít sát thương hơn) | — | — | — | **MISSING** | không đề xuất (CC là đủ) |
| Dấu Tử (mark) | lá `dau_tu` | enemy | `apply_mark`/`has_mark`/`consume_mark` `:541-566` | EXISTS (người chơi → địch) | "mark" của quái lên người chơi = **Rạn** (đã có), không cần mark mới |
| Marker (mốc/vòng hoa trên nửa địch) | pattern skill `marker` | ô nửa địch | `pattern_controller.gd:661-680, 783-794` | EXISTS | có |
| Heal / hồi máu địch | trait `burn_eater`, `rebirth` | enemy | `CombatState.heal_enemy` `combat_state.gd:114` | EXISTS (chỉ trait) | chưa — thêm `effects.heal` |
| Summon / đơn vị thứ hai | — | — | `CombatState` giữ một `enemy_cell`/`enemy_hp` | **MISSING** | ngoài phạm vi; chờ multi-enemy |
| Push / pull người chơi | lá đẩy (lên địch); block boss lá đẩy (lên người chơi); trait `gust` (1 ô) | cả hai qua lá; pattern **không** | `CutEffects.push_away/pull_toward` `cut_effects.gd:887-903`; `gust.gd:147` | EXISTS qua lá; MISSING cho pattern | thêm `effects.push/pull` (§5.2) |
| Evade / untargetable | trait `burrow`, `rebirth` | enemy | `SwingArbiter.enemy_untargetable_fn` (`swing_arbiter.gd:96-98, 356`) | EXISTS (trait) | thêm `effects.evade {sec}` |
| Shroud (ẩn báo trúng) | trait `shroud` | UI người chơi | `shroud.gd:20-35` (`hit_forecast_blocked`) | EXISTS (trait); kiểm tra "đang niệm" đọc CutActor, **không** đọc PatternController | thêm `effects.shroud {sec}` |
| Bất tử khi chuyển pha; HP floor | pattern transition; `boss_phases` | enemy | `enemy_invulnerable_left`, `enemy_hp_floor` | EXISTS | có |
| Phản ứng R1/R2/R3 + ICD 1 s | tự động | cả hai | `reaction_allowed` `:507`; `reaction_immune_fn` **chưa gán** | EXISTS (R1–R3), PARTIAL (miễn nhiễm) | tự động |
| Trigger điều kiện | phase `enter_hp_ratio`; conditions `hp_below/once/requires_anchor/...`; trait on_hit | — | §1.2 | EXISTS cho máu/own-state; **MISSING** cho đồng đội | thêm key điều kiện (§5.2) |

**Gap/bug tìm thấy khi audit (không sửa trong session này):**

- **G1** `pattern_controller.gd:591-597`: damage pattern không gọi `fragile_mult_against(PLAYER)` → Rạn trên người chơi vô
  dụng với pattern enemy (block boss thì có). Mọi synergy "mark rồi đánh mạnh" của tài liệu này **cần sửa G1**.
- **G2** `pattern_controller.gd:627`: `apply_frost(PLAYER, …)` bỏ giá trị trả về → Giá Lạnh của quái lên người chơi
  không bao giờ nổ. Tháp Băng cần sửa.
- **G3** `status_effects.gd:128` `reaction_immune_fn` không được gán → không có "immune_status" dữ liệu.
- **G4** Skill quái không có VFX travel/impact (delivery không được đọc); người chơi chỉ thấy ô đỏ + clip `hit`.
- **G5** `phases[].traits` của pattern enemy không được tiêu thụ; HUD banner pha nghe `TraitHost.phase_changed`, không
  nghe `PatternController.phase_started`.
- **G6** Trait móc vào swing của block brain (`seal_caster`, `thorn_field`, `step_reactor`) không có tác dụng trên pattern
  enemy; `burrow`/`rebirth` tắt `BossController` nhưng không tắt `PatternController` (cần hook pause).

### 1.4 22 trait (block brain) — tất cả có code, không có id "chỉ trong data"

| Trait | Loại hook | Cơ chế (default) | Tương thích pattern brain |
|---|---|---|---|
| row_burner | tick | 8 s/lần, cảnh báo 1,2 s, đốt hàng người chơi 2,5 s (2 dmg/0,5 s) | **giữ** |
| rotten_thrower | tick | 6 s/lần, 1 khối thối lên nửa người chơi, chiếm slot 6 s | giữ |
| slam | tick | 7 s/lần nứt 2 ô 4 s, 20 dmg nếu đứng trên ô nứt | giữ |
| fuse_cannon | tick + on_boss_damaged | ngòi 12 s → nổ hàng 40 dmg; đòn ≥ 30 reset | giữ |
| frost_aura | tick | khối người chơi rơi chậm ×1,25 khi boss > 50 % | giữ |
| vent_surge | tick | 10 s/lần, 2 mạch nửa người chơi phun, ưu tiên mạch dưới chân | giữ |
| gust | tick | 6 s/lần đẩy người chơi 1 ô theo mũi tên, cảnh báo 0,6 | giữ |
| island_drop | tick | 11 s/lần rơi 1 đảo 4 s, không bao giờ đảo cuối | giữ |
| sandstorm | tick | 12 s/lần bão 3 s: drift ×0,5, +2 ô cát | giữ |
| bog_spread | tick (+ swing để ưu tiên ô thoát) | 8 s/lần 2 ô lầy 5 s | giữ (mất ưu tiên ô thoát) |
| spore_burst | on_boss_damaged | mỗi đòn trúng → lầy ô người chơi + 2 ô kề 4 s, ICD 1,5 | giữ |
| riposte | on_player_swing_resolved | đòn ≥ 4 ô trúng → cảnh báo 0,4 s ô người chơi, 10 dmg | giữ |
| burn_eater | burn_heal_ratio | lửa hồi máu thay vì đau | giữ |
| rebirth | on_boss_would_die | hồi sinh 40 % sau 1,5 s, trừ khi có Giá Lạnh | giữ **sau khi** thêm pause cho PatternController (G6) |
| burrow | tick | 7 s/lần lặn 1,5 s untargetable | như rebirth (G6) |
| hop_skip | mover | sau 3 bước nhảy 2 ô | giữ (mover dùng chung) |
| shroud | hit_forecast_blocked | ẩn báo trúng trừ khi pin/đang swing | giữ, sửa kiểm tra "đang niệm" đọc stage pattern |
| phase_shift | on_tick/on_boss_damaged | đổi brain_set, step, thêm trait | **thay** bằng `phases[]` của pattern enemy + G5 |
| boss_phases | — | dạng N pha (an_dai_keeper) | thay bằng `phases[]` |
| seal_caster | on_boss_swing_started | nứt 2–3 ô thoát khi boss swing ≥ 3 ô | **chuyển** thành skill `zone: drop` (đã có `bark_shift` làm mẫu) |
| thorn_field | on_boss_swing_started | gai lên ô thoát khi swing ≥ 4 ô | chuyển thành skill `zone: thorns` |
| step_reactor | on_player_stepped → `actor.begin_swing` | 3 bước người chơi = 1 swing 3 ô | chuyển thành skill có điều kiện `player_steps_since ≥ 3` (key mới) |

---

## 2. Năng lực AI hiện tại (audit)

### 2.1 Pattern brain chọn skill thế nào (`pattern_controller.gd:361-395`, `pattern_brain.gd:27-79`)

1. Cổng F5: cách lần cảnh báo trước ≥ `max(gap_needed, 0,4 s)`; recovery "nặng" (≥ 1,2 s) kéo gap lên `step_cd + 0,25`.
2. Ứng viên = skill của pha hiện tại, chưa cooldown, `conditions` đúng, có ≥ 1 plan **công bằng** (F1 người chơi kịp
   thoát với `t_need = lock_left + (k−1)·step_cd + 0,25 ≤ warning_sec`; F2 ô đỏ ≤ 50 % ô dùng được, **tính cả cảnh báo của
   trait** qua `external_red_fn`).
3. Trọng số = `weight` × 1,2 nếu người chơi đứng yên ≥ 1,5 s và plan phủ ô đó × 0,45 nếu là skill vừa dùng × 1,25 nếu là
   `mechanic` của pha × (1 + 0,1·U(−1,1)). `every_nth` ép skill nếu nó nằm trong ứng viên. `weight: 0` = chỉ khi bị ép.
4. Plan ưu tiên phủ ô người chơi (`pick_plan`). Anchor được **re-plan lại lúc hết windup** theo ô người chơi khi đó.
5. Không có: chọn theo máu/trạng thái **người chơi** (ngoài "đứng yên"), theo đồng đội, theo ô người chơi đang đứng
   (lầy/gai/cháy). Đây là 3 nhóm key điều kiện cần thêm (§5.2).

### 2.2 Block brain (`boss_brain.gd`)

Chấm điểm wait/move/cut mỗi 0,3 s; cut = `cut_per_cell·ô + cut_hit_now + escape_penalty/(1+ô thoát) − …`; 3 bộ trọng số
balanced / aggressive / cautious (aggressive: cast ngay khi có 1 khối, combo 60 %; cautious: gom 4 khối, né mạnh).
Lá bài chọn theo `skill_bonus_<id>`. Không có recovery sau cast; `RecoveryLock` không được tham chiếu. Learning: feint
khi người chơi né ≥ 3 lần liên tiếp. Block brain **vẫn là tầng di chuyển** của pattern enemy (BossController luôn được tạo).

### 2.3 Animation & VFX

- Clip địch: idle/step/hit/windup/down là bộ cơ bản; `windup_heavy`, `phase_shift`, `guard` (→ brace), `stunned`, `howl` **chỉ được
  yêu cầu qua pattern brain** (`unit_layer.gd:448-468`, ưu tiên `:577-615`). Block brain chỉ chơi idle/step/windup/hit/down;
  chuyển pha, burrow, rebirth **không có clip**.
- Telegraph: ô đỏ sọc `fx_telegraph_stripe_8.png`; khung ngà = tell không thể ngắt / ô di chuyển; marker vẽ tối dưới đỏ.
- VFX cast của người chơi: `assets/art/vfx/cast/index.json` (travel/impact packs, 19 impact form × 6 họ, cast glyph),
  `assets/art/vfx/floor/` (burning_cell, cracked_cell, thorn_spikes, root_seal, impact_flame_burn…), `assets/art/vfx/status/`
  (burn/chill/frozen cho hero và goblin). **Skill quái chưa đi qua đường này (G4).**

---

## 3. Kiểm kê roster (73 id, theo `chapters.json` + `strings.csv`)

Cột **Ra trận** = xuất hiện trong run tiêu chuẩn 7 tầng với `floor_tiers` hiện tại (tầng 1–3 tier 0/1/1, tầng 4–7 tier 1/2/2)
và `region_order` cố định. Cột **Não** = pattern (P) / block (B). Elite = pool `miniboss`; Boss = pool `boss`.

### 3.1 Rừng Sương `ch1` (tầng 1) — 16 id, 11 trong pool, 5 mồ côi

| Id | Tên | Loại | Não | Trait | Skill hiện có | Ra trận |
|---|---|---|---|---|---|---|
| goblin_scout | Goblin Scout | Normal B0 | P | — | scout_stab, scout_hop | có |
| rootling | Rootling | Normal B0–1 | P | — | root_prick, creep | có |
| mossbound_sentry | Mossbound Sentry | Normal B0–2 D2 | P | — | slab_tap, brace | có |
| greycap_sporeling | Greycap Sporeling | Normal B1–2 D1 | P | — | spore_squares, seedbed | có |
| goblin_archer | Goblin Archer | Normal B1–2 D1–2 | P | — | aimed_shot, volley | có |
| dire_wolf | Dire Wolf | Normal B1–2 D1–2 | P | — | chase_bite, prowl | có |
| wolf_alpha | Alpha Wolf | Elite M1–2 | P | — | alpha_howl, rending_rush, alpha_bite | **không** (tầng 1 chưa có elite) |
| ancient_root_sentinel | Ancient Root Sentinel | Elite M1–2 | P | — | sentinel_anchor, branch_net, bark_shift | không |
| mistbriar_matron | Mistbriar Matron | Elite M2 | P | — | thorn_fork, wreath_guard | không |
| goblin_warlock | Goblin Warlock | Boss t1 | P (2×2) | — | hex_bolt, stolen_shape, curse_lane, warlock_blink, twin_shapes (p2) | có |
| forest_witch | Forest Witch | Boss t2 | P (2×2) | — | 9 skill / 3 pha | không |
| wolf | Grey Wolf | — (không pool) | B | — | — | không |
| goblin_chief | Goblin Chief | — | B | row_burner | — | không |
| goblin_warrior | Goblin Warrior | — | B | — | — | không |
| goblin_shaman | Goblin Shaman | — | B | — | — | không |
| goblin_brute | Goblin Brute | — | B | — | — | không |

### 3.2 Thành Hỏa Ngục `hellfire` (tầng 2) — 9 id

| Id | Tên | Loại | Não | Trait | Máu gốc / giáp / min_runes | Ra trận |
|---|---|---|---|---|---|---|
| imp | Imp | Normal B0–1 | B | — | 92 | có |
| ember_hound | Ember Hound | Normal B0–1 | B | — | 110 | có |
| ash_golem | Ash Golem | Normal B1–2 D1 | B | — | 132 / def 3 | có |
| flame_cultist | Flame Cultist | Normal B1–2 D1–2 | B | row_burner | 128 | có |
| magma_slug | Magma Slug | Normal B2 D1–2 | B | — | 140 | có (qua danger t1) |
| hell_knight | Hell Knight | Normal B2 D2 | B | — | 156 / def 2 / mr 3 | **không** (tầng 2 tier tối đa 1) |
| fire_eater | Fire Eater | Elite | B | burn_eater | 90 / mr 2 | có |
| ash_phoenix | Ash Phoenix | Elite | B | rebirth | 74 / mr 2 | có |
| inferno_lord | Inferno Lord | Boss | B | vent_surge, phase_shift | 180 / mr 3, aggressive | có |

### 3.3 Sa Mạc Cát Vùi `desert` (tầng 3) — 9 id

| Id | Tên | Loại | Não | Trait | Máu / giáp / mr | Ra trận |
|---|---|---|---|---|---|---|
| dune_jackal | Dune Jackal | Normal B0–1 | B | — | 90 | có |
| sand_beetle | Sand Beetle | Normal B0–1 | B | — | 106 / def 2 | có |
| dust_nomad | Dust Nomad | Normal B1–2 D1 | B | — | 116 | có |
| mirage_sprite | Mirage Sprite | Normal B1–2 D1–2 | B | — | 124 (cautious, noise 0,15) | có |
| scarab_guard | Scarab Guard | Normal B2 D1–2 | B | — | 140 / def 2 | có (qua danger t1) |
| sun_archer | Sun Archer | Normal B2 D2 | B | row_burner | 152 | **không** |
| sand_burrower | Sand Burrower | Elite | B | burrow | 84 / mr 2 | có |
| scorpion | Riposte Scorpion | Elite | B | riposte | 96 | có |
| sand_sphinx | Sand Sphinx | Boss | B | sandstorm | 175 / mr 3 | có |

### 3.4 Đầm Lầy Độc `swamp` (tầng 4) — 9 id

| Id | Tên | Loại | Não | Trait | Máu / giáp / mr | Ra trận |
|---|---|---|---|---|---|---|
| bog_rat | Bog Rat | Normal B0–1 | B | — | 88 | có |
| mire_slug | Mire Slug | Normal B0–1 | B | — (`mire_immune`) | 104 | có |
| swamp_lizard | Swamp Lizard | Normal B1–2 D1 | B | — | 112 | có |
| marsh_toad | Marsh Toad | Normal B1–2 D1–2 | B | — | 126 | có |
| reed_witch | Reed Witch | Normal B2 D1–2 | B | rotten_thrower (9 s) | 138 | có |
| bog_hound | Bog Hound | Normal B2 D2 | B | row_burner | 150 | có |
| spore_cap | Spore Cap | Elite | B | spore_burst | 70 / mr 2 | có |
| leap_frog | Leap Frog | Elite | B | hop_skip | 80 / mr 2 | có |
| toad_matriarch | Toad Matriarch | Boss | B | bog_spread, seal_caster (`mire_immune`) | 170 / mr 3, aggressive | có |

### 3.5 Hầm Ngục `ch2` (tầng 5) — 10 id

| Id | Tên | Loại | Não | Trait | Máu / giáp / mr | Ra trận |
|---|---|---|---|---|---|---|
| skeleton | Skeleton Guard | Normal B0 | B | — | 92 / def 2 | **không** (tầng 5 tier ≥ 1) |
| zombie | Zombie | Normal B0–1 | B | — | 104 / def 2 | có |
| bat_swarm | Crypt Bat Swarm | Normal B1–2 D1 | B | — | 115 / def 2 | có |
| slime | Dungeon Slime | Normal B1–2 D1–2 | B | — | 138 / def 2 | có |
| ghost | Ghost | Normal B1 D1 | B | — | 24 / def 12 | có |
| reacter | The Reacter | Normal B1–2 D1–2 | B | step_reactor | 70 / def 2 / mr 2 | có |
| cultist | Cultist | Normal B2 D2 | B | — | 150 / def 2 | có |
| rat_king_guard | Rat King's Guard | Normal B2 D2 | B | row_burner | 161 / def 2 | có |
| jailer | The Jailer | Elite | B | rotten_thrower, row_burner, seal_caster | 77 / mr 2 | có |
| ogre_king | Giant Ogre | Boss | B | slam | 132 / mr 3, aggressive | có |

### 3.6 Tháp Sương `ch3` (tầng 6) — 10 id

| Id | Tên | Loại | Não | Trait | Máu / giáp / mr | Ra trận |
|---|---|---|---|---|---|---|
| frost_sprite | Frost Sprite | Normal B0 | B | — | 106 / def 4 | **không** |
| wisp | Wisp | Normal B0–1 | B | — | 120 / def 4 | có |
| stone_sentry | Stone Sentry | Normal B1–2 D1 | B | — | 132 / def 4 | có |
| snow_wolf | Snow Wolf | Normal B1–2 D1 | B | — | 159 / def 4 | có |
| fuse_golem | Fuse Cannon | Normal B1–2 D1–2 | B | fuse_cannon | 110 / mr 2 | có |
| rime_archer | Rime Archer | Normal B2 D2 | B | — | 172 / def 4 | có |
| ice_golem | Ice Golem | Normal B2 D2 | B | row_burner | 185 / def 4 | có |
| ghost_elite | Greater Ghost | Normal B2 D2 | B | — | 36 / def 16 | có |
| frost_mage | Frost Mage | Elite | B | frost_aura, thorn_field | 92 / mr 2 | có |
| mist_lord | Frost Lord | Boss | B | frost_aura, phase_shift | 139 / mr 3 | có |

### 3.7 Không Đảo `sky_isles` (tầng 7) — 9 id

| Id | Tên | Loại | Não | Trait | Máu / giáp / mr | Ra trận |
|---|---|---|---|---|---|---|
| cloud_sprite | Cloud Sprite | Normal B0–1 | B | — | 88 | có |
| harpy | Harpy | Normal B0–1 | B | — | 104 | có |
| wind_monk | Wind Monk | Normal B1–2 D1 | B | — | 118 | có |
| storm_eagle | Storm Eagle | Normal B1–2 D1–2 | B | — | 126 (step nhanh nhất vùng) | có |
| sky_sentinel | Sky Sentinel | Normal B2 D1–2 | B | — | 144 / def 3 | có |
| thunder_shaman | Thunder Shaman | Normal B2 D2 | B | row_burner | 150 | có |
| gale_bird | Gale Bird | Elite | B | gust | 86 / mr 2 | có |
| cloud_veil | Cloud Veil | Elite | B | shroud | 96 / mr 2 | có |
| storm_dragon | Storm Dragon | Boss | B | island_drop, gust | 185 / mr 3 | có |

### 3.8 Tâm Lưới `an_dai` (trận cuối) — 1 id

| Id | Tên | Loại | Não | Trait | Máu / mr | Ra trận |
|---|---|---|---|---|---|---|
| an_dai_keeper | Heart Keeper | Final boss | B (`phases`) | p1 seal_caster; p2 (50 %) + row_burner, aggressive | 198 / mr 3 | có |

**Tổng:** 73 id = 11 pattern (đã có skill) + 57 block trong pool + 5 block mồ côi. 13 id có trong pool nhưng **không ra
trận** với tier/thứ tự tầng hiện tại (4 rừng, hell_knight, sun_archer, skeleton, frost_sprite + 5 mồ côi) — vẫn được thiết
kế (trừ mồ côi) vì `region_pool` cho phép vùng đứng ở tầng khác và `--pattern=`/dev launcher dùng được.


---

## 4. Thiết kế skill từng quái

### 4.0 Cách đọc một dòng skill

Mỗi skill ghi 12 trường theo thứ tự: **`skill_id` — Tên EN** (loại) · *Mô tả* · *Kích hoạt* (trigger + điều kiện) · *Mục tiêu*
(anchor / pattern theo schema `enemy_skills.json`) · *Hiệu ứng* · *Thời lượng* · *Hồi / điều kiện dùng* · *Anim/VFX*
(clip địch + delivery `{type, travel, impact}`) · *Phản đòn*. Chủ sở hữu = tiêu đề quái. Số là **giá trị khởi điểm**
cho mô phỏng (`tools/qa/...` deck_sim + `pattern_roster_fairness_test`), không phải số đã cân bằng.

Quy ước số theo tiền lệ rừng: Normal damage 6–14, warning 0,9–1,2 s, cooldown 2,4–3,5 s; Elite 10–16, cooldown 3–6;
Boss 12–22, skill nặng `interruptible: false` + recovery ≥ 1,2 s. Ô đỏ mỗi plan ≤ 50 % ô dùng được (F2).

**Ký hiệu effect mới** (chưa có trong `EnemySkillsConfig`, xem §5.2 / §5.3): `zone:burn`, `zone:mire`, `zone:sand`,
`zone:fall`, `status:poison`, `push`/`pull`, `heal`, `consume_burn`, `evade`, `shroud`, `move.to:far_cell`, điều kiện
`player_status`, `player_on_zone`, `ally_*`, `player_steps_since`. Mọi skill dùng ký hiệu này = DESIGNED + cần code.

> **Quy ước offset của `column_of_player` (phát hiện ở nhóm C, 2026-11-13).** `PatternPlanner` đặt ô theo
> `(player.x − off.y, start + off.x)`: trục **x** của offset chạy **dọc cột** (giống `row_of_player`, nơi x chạy dọc hàng).
> Một cột 3 ô viết là `[[0,0],[1,0],[2,0]]`, **không phải** `[[0,0],[0,1],[0,2]]` (dạng đó nằm ngang). Các skill thiết kế ở §4
> có ghi offset cột kiểu `[[0,0],[0,1]]` (Scarab Spear, Tongue Pull, Chain Hook, Gale Palm, Sky Spear, Ghost Wail, Rime Lance,
> Storm Breath, Tongue Lash, Undertow, Frozen Wail…) phải đổi sang dạng trục x khi implement. `pattern_fairness_test.gd`
> (`column_of_player: vertical windows`) là chuẩn tham chiếu.

### 4.1 Skill dùng chung (`owner: shared`, 3 skill)

Nhiều Normal chỉ cần 1 skill đặc trưng + 1 đòn cơ bản; tái dùng đúng tinh thần `dev_prick`/`dev_bar` (một skill id, nhiều
enemy tham chiếu — `EnemySkillsConfig` đã cho phép).

- **`shared_jab` — Jab** (attack) · Đòn 1 ô thẳng vào người chơi, "nhịp nền" của mọi vùng · Kích hoạt: cooldown, weight 1,0 ·
  Mục tiêu: `on_player` 1 ô · Hiệu ứng: 8 dmg · Thời lượng: windup 0,4 / warning 0,9 · Hồi 2,6 s ·
  Anim/VFX: `windup`; `CASTER_TO_TARGET / square_streak / slash` · Phản đòn: bước sang ô kề.
- **`shared_bar` — Bar Sweep** (attack) · Thanh 2 ô xoay 4 hướng phủ người chơi · weight 0,8 · `on_player` `[[0,0],[1,0]]`
  rotations 4 · 10 dmg · 0,5 / 1,0 · Hồi 3,0 · `windup`; `CASTER_TO_TARGET / square_streak / slash` · Phản đòn: bước vuông góc thanh.
- **`shared_sidestep` — Sidestep** (self, `counts_as_cast: false`) · Dời một hàng · weight 0,4, `cooldown_sec` 5 ·
  `self_cell`, `move {to: adjacent_row}` · windup 0,8 / recovery 0,3 · Anim: `step` + khung ngà ô đích · Phản đòn: đánh ô khung ngà.

Khác biệt với bản riêng của rừng (`scout_stab`, `slab_tap`, `scout_hop`, `prowl`): cùng cơ chế, nhưng skill rừng có
`name_key`/`counter_key` riêng và số riêng theo quái; `shared_*` là nền cho quái chưa có skill, không thay thế skill rừng.

### 4.2 Thành Hỏa Ngục — bản sắc: **Dấu Tro (Rạn) → áp lực sát thương; giáp phiến than; ô cháy**

Mạch: Normal "đánh dấu" (Rạn) → Normal khác "ăn dấu" (đòn nhân ×1,5 qua Rạn, cần G1) → Golem che đồng đội (guard theo phe) →
ô cháy cắt đường thoát (fairness F1 không cho thoát xuyên ô cháy, nên ô cháy là "tường mềm"). Trait `row_burner`,
`vent_surge`, `burn_eater`, `rebirth` giữ nguyên.

**`imp` Imp — Normal (B0–1), forge** · vai: **marker** · **IMPLEMENTED 2026-11-13 (Phase 1 nhóm A)**
- **`imp_ash_dart` — Ash Dart** (attack) · Phi tiêu tro 1 ô, trúng thì dính Dấu Tro · Kích hoạt: cooldown; weight ×1,5 khi
  `allies_alive >= 1` (Bậc B) · `on_player` 1 ô · 6 dmg + `status {fragile, stacks 1}` · 0,4 / 1,0 · Hồi 2,6 ·
  `windup`; `CASTER_TO_TARGET / square_streak / burn` · Phản đòn: ô đỏ đơn, bước đi là xong; Dấu Tro ở lại 1 tầng → đừng ăn đòn tiếp.
- `shared_sidestep` (weight 0,6: Imp lanh).
- Status: DESIGNED. Synergy: Rạn trên người chơi là trạng thái **theo phe**, mọi quái khác ăn được → Bậc A.

**`ember_hound` Ember Hound — Normal (B0–1), caldera** · vai: **ăn dấu** · **IMPLEMENTED 2026-11-13**
- **`hound_ember_charge` — Ember Charge** (attack) · Lao dọc hàng người chơi từ vạch chia · Kích hoạt: cooldown; weight ×2,0
  khi `player_status: fragile` (key mới) · `row_of_player` `[[0,0],[1,0]]` start front clip min 2 · 10 dmg (×1,5 nếu Rạn, sau G1) ·
  0,5 / 1,0 · Hồi 3,0 · `windup`; `GROUND_PROPAGATION / floor_run / burn` · Phản đòn: đổi hàng; xóa Rạn bằng cách… không xóa được —
  né đòn đánh dấu từ đầu.
- Status: DESIGNED. Khác `chase_bite` (sói rừng: 2 nhịp SKY trên ô người chơi): chó than đánh **hàng**, một nhịp, thưởng theo trạng thái.

**`ash_golem` Ash Golem — Normal (B1–2, D1), forge, def 3** · vai: **lá chắn đội** · **IMPLEMENTED 2026-11-13**
- **`golem_ash_mantle` — Ash Mantle** (self) · Phủ tro lên **cả phe địch**: guard +3 · Kích hoạt: cooldown; weight 1,2 khi
  `allies_alive >= 1`, 0,3 khi một mình · `self_cell` · `guard {amount 3, sec 4}` (guard theo phe = mọi quái trong trận cùng nhận,
  **hành vi sẵn có** của `StatusEffects.guard(ENEMY)`) · 4 s · Hồi 8 · `guard`→`brace`; `DIRECT_MANIFESTATION / none / guard` ·
  Phản đòn: Xuyên giáp; đánh Golem lúc windup (interruptible, `interrupt_stun_sec` 0,8).
- **`golem_cinder_slam` — Cinder Slam** (attack) · Đấm 2×2 cạnh người chơi · `near_player` `[[0,0],[1,0],[0,1],[1,1]]` rot 4,
  must_cover · 12 dmg · 0,7 / 1,3 · Hồi 5, `interruptible: false`, recovery 1,2 · `windup_heavy`; `DIRECT_MANIFESTATION / none / shatter` ·
  Phản đòn: ra khỏi khối 2×2 (luôn có ≥ 1 cạnh mở theo F1).
- Status: DESIGNED. Normal 2 skill vì Golem là "cơ chế đội"; một mình chỉ còn slam (ít nhớ).

**`flame_cultist` Flame Cultist — Normal (B1–2, D1–2), caldera, trait row_burner** · vai: **cắt đường bằng lửa** · **IMPLEMENTED 2026-11-13 (Phase 1 nhóm B)**
- **`cultist_kindle` — Kindle** (attack, zone) · Thắp 2 ô cạnh người chơi · Kích hoạt: cooldown; không dùng nếu nửa người chơi
  đã có ≥ 3 ô cháy (ngân sách zone §9.3) · `near_player` `[[0,0]]` count 2 (hai ô kề khác nhau), `exclude_player` ·
  0 dmg + `zone {id: burn, sec 3, tick 0,5, dmg 2}` (**mới**: gọi `StatusEffects.ignite`) · 3 s · Hồi 6 ·
  `windup`; `DIRECT_MANIFESTATION / none / burn` · Phản đòn: ô cháy báo đỏ trước 1,0 s; đứng yên hoặc đi vòng; F1 đảm bảo không bị
  nhốt (zone bị cắt theo F3 `zone_leaves_exit`).
- `shared_jab`.
- Status: DESIGNED. Trait `row_burner` giữ: hàng lửa định kỳ là "nhịp lớn", Kindle là "nhịp nhỏ".

**`magma_slug` Magma Slug — Normal (B2, D1–2), forge** · vai: **chậm, để lại vết** · **IMPLEMENTED 2026-11-13**
- **`slug_lava_spit` — Lava Spit** (attack) · Nhổ dung nham 1 ô, ô đó cháy tiếp · `on_player` 1 ô · 8 dmg + `zone {burn, 2 s}` trên
  đúng ô đó · 0,7 / 1,2 · Hồi 3,4 · `windup`; `SKY_TO_TARGET / falling_squares / burn` · Phản đòn: bước đi, **đừng quay lại ô cũ** 2 s.
- **`slug_molten_trail` — Molten Trail** (self) · Khi Sên dời hàng, ô nó rời bỏ cháy 2 s (nửa địch → người chơi đặt khối lên ô cháy
  thì khối cháy mất, `FieldDrops.bury_cells` đã có cho vent) · `self_cell`, `move {adjacent_row}` + `zone {burn, 2 s, side: self}`
  (**mới**: zone phía mình) · Hồi 7, weight 0,5 · Phản đòn: không đặt khối lên vệt.
- Status: DESIGNED.

**`hell_knight` Hell Knight — Normal (B2, D2), caldera, def 2, mr 3** · vai: **đòn nặng, phòng thủ khi yếu** · **IMPLEMENTED 2026-11-13** (không ra tầng 2 — giữ cho tầng khác / Kiếp)
- **`knight_cleave` — Cleave** (attack) · Chém ngang 3 ô hàng người chơi · `row_of_player` `[[0,0],[1,0],[2,0]]` clip min 2 ·
  14 dmg · 0,6 / 1,2 · Hồi 4,5, `interruptible: false`, recovery 1,2 · `windup_heavy`; `CASTER_TO_TARGET / square_streak / slash` · Phản đòn: đổi hàng.
- **`knight_bulwark` — Bulwark** (self) · Giơ khiên phiến than · Kích hoạt: `hp_below 0,5`, `once` · `guard {5, 4 s}` · Hồi 0 ·
  `guard`; impact `guard` · Phản đòn: Xuyên giáp / chờ.
- Status: DESIGNED.

**`fire_eater` Fire Eater — Elite, forge, trait burn_eater** · cơ chế: **tạo lửa rồi nuốt lửa để hồi máu** · **IMPLEMENTED 2026-11-13 (Phase 1 nhóm C)**
- **`eater_ember_belch` — Ember Belch** (attack) · Phun than dọc cột người chơi, cột cháy sau · `column_of_player` `[[0,0],[0,1],[0,2]]`
  clip min 2 · 12 dmg + `zone {burn, 2,5 s}` trên các ô · 0,6 / 1,2 · Hồi 5 · `windup`; `GROUND_PROPAGATION / floor_run / burn` · Phản đòn: ra khỏi cột.
- **`eater_devour` — Devour Flame** (self) · Hút mọi ô đang cháy **hai nửa sân**, mỗi ô hồi 6 máu và tắt lửa · Kích hoạt:
  `burning_cells >= 2` (key mới), weight 1,5, `mechanic` · `self_cell` · `consume_burn {heal_per_cell 6}` (**mới**) · windup 1,4 ·
  Hồi 9, `interruptible: true`, `interrupt_stun_sec` 1,0 · `howl`→`windup`; impact `burn` · Phản đòn: đánh nó lúc hút (1,4 s cửa sổ) →
  choáng 1 s; không dùng lá lửa với nó (trait `burn_eater` đã nói vậy).
- Status: DESIGNED. Boss-ish loop nhưng là Elite: 2 skill, 1 cơ chế nhớ.

**`ash_phoenix` Ash Phoenix — Elite, caldera, trait rebirth** · cơ chế: **sống lại trừ khi Giá Lạnh** (trait) + bãi lửa trước khi gục · **IMPLEMENTED 2026-11-13**
- **`phoenix_ash_dive` — Ash Dive** (attack) · Bổ nhào hình L · `on_player` `[[0,0],[1,0],[0,1]]` rot 4 · 12 dmg + fragile 1 ·
  0,5 / 1,1 · Hồi 3,5 · `windup`; `SKY_TO_TARGET / falling_squares / burn` · Phản đòn: ra phía mở của chữ L (giống `spore_squares`
  về hình, khác về impact và theo sau là Pyre).
- **`phoenix_pyre` — Pyre** (attack, zone) · Giàn thiêu 3 ô quanh người chơi · Kích hoạt: `hp_below 0,5`, `once` ·
  `near_player` count 3 exclude_player · `zone {burn, 4 s}` · windup 0,8 / warning 1,2 · recovery 1,5 ·
  `windup_heavy`; `DIRECT_MANIFESTATION / none / burn` · Phản đòn: đứng yên trong 4 s hoặc đi theo lối F3 chừa lại; mang băng để chặn hồi sinh.
- Status: DESIGNED. Yêu cầu G6 (rebirth tắt PatternController khi hồi sinh).

**`inferno_lord` Inferno Lord — Boss (Kẻ Gác), caldera, mr 3, trait vent_surge (+ warden_hook Heat)** · cơ chế học được: **mạch phun đôi + làn than** · **IMPLEMENTED 2026-11-13 (Phase 1 nhóm D)**
- Pha 1 (1,0): `lord_brand`, `lord_cinder_lane`, `lord_stride`; mechanic `lord_cinder_lane`.
- Pha 2 (0,5): + `lord_eruption_call`; `every_nth {lord_eruption_call, 3}`; transition 1,5 s (bất tử); `on_enter: [lord_eruption_call]`.
  Thay trait `phase_shift` (`vent_interval_mult 0,7`) bằng override `vent_surge.interval_sec` qua `phases[].traits` (G5).
- **`lord_brand` — Brand** (attack) · Đóng dấu tro · `on_player` 1 ô · 10 dmg + fragile 1 · 0,4 / 0,9 · Hồi 2,8 · `windup`; `CASTER_TO_TARGET / square_streak / burn`.
- **`lord_cinder_lane` — Cinder Lane** (attack) · Làn than 3 ô dọc hàng, cháy sau · `row_of_player` 3 ô clip min 2 · 14 dmg + `zone {burn, 2 s}` ·
  0,8 / 1,4 · Hồi 5,5, `interruptible: false`, recovery 1,2 · `windup_heavy`; `GROUND_PROPAGATION / floor_run / burn` · Phản đòn: đổi hàng sớm; làn cháy 2 s chặn đường về.
- **`lord_stride` — Stride** (self) · = `shared_sidestep` số riêng (hồi 8, weight 2) · Phản đòn: đánh khung ngà.
- **`lord_eruption_call` — Eruption Call** (attack) · Gọi 2×2 tro rồi **gọi lại cùng ô** · `near_player` 2×2 must_cover · 14 dmg ·
  `followup {relative_to same_cells, delay_sec 1,0, warning 1,0, effects {damage 10, zone {burn, 2 s}}}` · 0,9 / 1,5 · Hồi 0, weight 0 (chỉ khi ép),
  `interruptible: false`, recovery 1,5 · `windup_heavy`; `SKY_TO_TARGET / falling_squares / burst` · Phản đòn: ra khỏi 2×2, **không quay lại** sau 1 s.
- Status: DESIGNED. Heat warden_hook (`vent_surge interval 7`) giữ nguyên vì trait vẫn chạy.

### 4.3 Sa Mạc Cát Vùi — bản sắc: **cát lấp (kiểm soát ô), ảo ảnh/né, phục kích người đứng yên, độc (mới)**

Trait giữ: `burrow`, `riposte`, `sandstorm`, `row_burner` (sun_archer). Độc = trạng thái mới `poison` (§5.3), dùng chung với Đầm Lầy
nhưng ở Sa Mạc gắn với **bọ cạp** (ít, mạnh), ở Đầm Lầy gắn với **nhiều nguồn nhỏ**.

**`dune_jackal` Dune Jackal — Normal (B0–1), dunes** · vai: **bầy, cắn đuổi**
- **`jackal_pack_nip` — Pack Nip** (attack) · Cắn rồi cắn đuổi · `on_player` 1 ô · 7 dmg · `followup {relative_to player, warning 0,75, damage 6}` ·
  0,4 / 0,9 · Hồi 2,8 · weight ×1,5 khi `allies_alive >= 1` · `windup`; `CASTER_TO_TARGET / square_streak / slash` · Phản đòn: bước hai lần (như sói rừng, nhưng yếu hơn và nhanh hơn).
- `shared_sidestep` weight 0,6.
- Status: DESIGNED.

**`sand_beetle` Sand Beetle — Normal (B0–1), dunes, def 2** · vai: **lấp ô**
- **`beetle_sand_spray` — Sand Spray** (attack, zone) · Húc 2 ô, một ô bị cát lấp · `on_player` `[[0,0],[1,0]]` rot 4 · 8 dmg +
  `zone {id: sand, cells 1 (ô xa người chơi nhất của thanh), sec 3}` (**mới**: `TileHazards.add_sand`, giữ luật chừa đường của hazards) ·
  0,5 / 1,0 · Hồi 4 · `windup`; `GROUND_PROPAGATION / floor_run / shatter` · Phản đòn: bước vuông góc; nhớ ô cát 3 s không đứng được.
- Status: DESIGNED.

**`dust_nomad` Dust Nomad — Normal (B1–2, D1), oasis** · vai: **phục kích**
- **`nomad_ambush` — Ambush** (attack) · Lao tới chém chữ T khi người chơi đứng yên · Kích hoạt: `player_still_sec >= 1,2` (đã có),
  weight 2,0; ngoài điều kiện: không dùng · `near_player` `[[0,0],[1,0],[-1,0],[0,1]]` rot 4 must_cover · 12 dmg · 0,5 / 1,1 · Hồi 4 ·
  `windup`; `CASTER_TO_TARGET / square_streak / slash` · Phản đòn: **đừng đứng yên** quá 1 s khi Du Mục còn sống; chữ T luôn hở 3 phía.
- **`nomad_veil_step` — Veil Step** (self) · Tan vào bụi, hiện ra ô khác · `self_cell`, `move {to: far_cell}` (**mới**: ô trống xa nhất
  nửa địch) + `evade {sec 0,6}` (**mới**: untargetable) · windup 0,6 / recovery 0,2 · Hồi 7, weight 0,8, `counts_as_cast: false` ·
  `step`; impact `none` · Phản đòn: đòn đang bay trượt → ghim khối trước khi nó windup (0,6 s), hoặc chờ.
- Status: DESIGNED.

**`mirage_sprite` Mirage Sprite — Normal (B1–2, D1–2), dunes var** · vai: **ảo ảnh (marker)**
- **`sprite_mirage` — Mirage** (marker) · Đặt bóng cát trên nửa địch · `enemy_half_empty` count 1, `row: player` ·
  `marker {kind mirage, life 8, break_min_cells 1}` · windup 0,6 · Hồi 6 · `windup`; impact `none` · Phản đòn: đánh 1 ô lên bóng để xóa.
- **`sprite_shimmer_lash` — Shimmer Lash** (attack) · Quất từ **hàng của bóng** · Kích hoạt: `requires_anchor 1` · `row_of_anchor`
  `[[0,0],[1,0]]` start front clip min 2 · 10 dmg + fragile 1 · 0,5 / 1,0 · Hồi 3,2 · `windup`; `CASTER_TO_TARGET / square_streak / slash` ·
  Phản đòn: rời hàng của bóng, phá bóng.
- Status: DESIGNED. Khác Sentinel rừng (anchor + net 3 ô + lặp + stun khi phá): bóng không stun, không lặp, đổi chỗ nhanh.

**`scarab_guard` Scarab Guard — Normal (B2, D1–2), oasis var, def 2** · vai: **tường đội**
- **`scarab_shield_wall` — Shield Wall** (self) · Giơ khiên ngọc: guard phe +4 · Kích hoạt: cooldown; weight 1,2 khi
  `allies_alive >= 1` hoặc `hp_below 0,6`; 0,3 nếu không · `guard {4, 4 s}` · Hồi 9, `interrupt_stun_sec` 0,8 · `guard`; impact `guard` ·
  Phản đòn: Xuyên giáp; ngắt lúc windup.
- **`scarab_spear` — Spear Thrust** (attack) · Đâm giáo dọc cột 2 ô · `column_of_player` `[[0,0],[0,1]]` clip min 1 · 12 dmg · 0,5 / 1,1 · Hồi 3,4 ·
  `windup`; `CASTER_TO_TARGET / square_streak / slash` · Phản đòn: bước ngang.
- Status: DESIGNED. Khác Ash Golem (guard 3/4 s + slam 2×2): Scarab guard cao hơn, đòn thường là cột (sân oasis 5×5 rộng).

**`sun_archer` Sun Archer — Normal (B2, D2), dunes var, trait row_burner** (không ra tầng 3)
- **`archer_blinding_arc` — Blinding Arc** (attack) · Tên chói hình chữ thập, làm chậm · `near_player` `[[0,0],[1,0],[-1,0],[0,1],[0,-1]]`
  must_cover (5 ô ≤ 50 % của dunes 5×4 = 10) · 10 dmg + `slow {1,5 s, ×1,3}` · 0,6 / 1,3 · Hồi 4 · `windup`; `SKY_TO_TARGET / falling_squares / slash` ·
  Phản đòn: bước chéo = 1 bước thoát; F4 không cho chồng slow trong 1 s sau khóa bước.
- Status: DESIGNED. Khác `aimed_shot` (hàng 4 ô) và `volley` (chéo 3 ô) của goblin: chữ thập + slow.

**`sand_burrower` Sand Burrower — Elite, dunes, trait burrow** · cơ chế: **lặn (trait) + trồi lên kéo người chơi xuống cát**
- **`burrower_undertow` — Undertow** (attack) · Cát trôi dọc cột, ô đầu trói · `column_of_player` 3 ô clip min 2 · 12 dmg +
  `root {0,7 s, first_cell_only}` · 0,6 / 1,2 · Hồi 4,5 · `windup`; `GROUND_PROPAGATION / floor_run / shatter` · Phản đòn: bước ngang; ô đầu là ô nguy hiểm nhất.
- **`burrower_sinkhole` — Sinkhole** (attack, zone) · Hai ô cạnh người chơi sụp · Kích hoạt: `hp_below 0,5` · `near_player` count 2 exclude_player ·
  `zone {drop, warn 0,8, hole 1,5}` · 0,5 / 1,2 · Hồi 8 · `windup`; `DIRECT_MANIFESTATION / none / shatter` · Phản đòn: luật Ô rớt (luôn chừa ô kề an toàn).
- Status: DESIGNED. Khác Sentinel `bark_shift` (1 ô, bất kỳ lúc nào): 2 ô, chỉ khi yếu. Cần G6 (burrow tắt PatternController).

**`scorpion` Riposte Scorpion — Elite, oasis, trait riposte** · cơ chế: **phản đòn lớn (trait) + nọc độc**
- **`scorpion_venom_sting` — Venom Sting** (attack) · Chích 1 ô, dính Độc · `on_player` 1 ô · 8 dmg + `status {poison, sec 3, tick 0,5, dmg 1,5}`
  (**mới** §5.3; tổng 9) · 0,4 / 0,9 · Hồi 3 · `windup`; `CASTER_TO_TARGET / square_streak / poison` · Phản đòn: ô đơn, bước đi; Độc không
  chồng, chỉ làm mới.
- **`scorpion_pincer_hold` — Pincer Hold** (attack) · Kẹp 2 ô, trúng thì Đóng Băng ngắn · `on_player` `[[0,0],[1,0]]` rot 4 · 10 dmg +
  `pin {0,6 s}` (F4 `cc_grace`) · 0,6 / 1,2 · Hồi 5,5 · `windup`; `DIRECT_MANIFESTATION / none / knockback` · Phản đòn: bước vuông góc;
  **đừng dùng đòn ≥ 4 ô ngay sau** (riposte).
- Status: DESIGNED.

**`sand_sphinx` Sand Sphinx — Boss, oasis var, mr 3, trait sandstorm** · cơ chế học được: **bão cát (trait) + chôn ô + cát đổ hai nhịp**
- Pha 1 (1,0): `sphinx_gaze`, `sphinx_claw`, `sphinx_bury`, `sphinx_shift`; mechanic `sphinx_bury`.
- Pha 2 (0,5): + `sphinx_sandfall`; every_nth 3; transition 1,5; `phases[].traits` override `sandstorm {interval_sec 9}` (G5).
- **`sphinx_gaze` — Riddle Gaze** (attack) · 1 ô, Rạn · `on_player` · 10 dmg + fragile 1 · 0,4 / 0,9 · Hồi 2,8 · `windup`; `CASTER_TO_TARGET / square_streak / curse`.
- **`sphinx_claw` — Stone Claw** (attack) · Chữ T 4 ô · `near_player` T rot 4 must_cover · 14 dmg · 0,6 / 1,3 · Hồi 4,5 · `windup`; `DIRECT_MANIFESTATION / none / shatter` · Phản đòn: ra phía hở.
- **`sphinx_bury` — Bury** (attack, zone) · Lấp 2 ô cạnh người chơi 4 s · `near_player` count 2 exclude_player · `zone {sand, 4 s}` · 0,6 / 1,1 · Hồi 6 ·
  `windup`; `DIRECT_MANIFESTATION / none / seal` · Phản đòn: đừng để bị dồn vào góc; cát luôn chừa đường (luật hazards).
- **`sphinx_shift` — Shift** (self) · = `shared_sidestep` (hồi 8, weight 2).
- **`sphinx_sandfall` — Sandfall** (attack) · 2×2 cát đổ, lặp lệch một hàng · `near_player` 2×2 must_cover · 16 dmg ·
  `followup {relative_to first_shift, offsets [[0,1]], rotations [0,180], show_with_first, warning 0,75, damage 12}` · 0,9 / 1,5 · weight 0 ·
  `interruptible: false`, recovery 1,5 · `windup_heavy`; `SKY_TO_TARGET / falling_squares / shatter` · Phản đòn: ra phía **không** có làn sọc chờ (như Withered Crown, hình khác).
- Status: DESIGNED.

### 4.4 Đầm Lầy Độc — bản sắc: **độc nhiều nguồn nhỏ, lầy/slow, hồi máu, kiểm soát vùng**

Trait giữ: `rotten_thrower`, `spore_burst`, `hop_skip`, `bog_spread`, `row_burner` (bog_hound). `seal_caster` của Cóc Chúa chuyển thành skill.

**`bog_rat` Bog Rat — Normal (B0–1), bog** · vai: **nguồn độc nhỏ, bầy**
- **`rat_gnaw` — Gnaw** (attack) · Cắn, dính Độc nhẹ · `on_player` 1 ô · 6 dmg + `poison {2 s, tick 0,5, dmg 1}` · 0,4 / 0,9 · Hồi 2,4 ·
  weight ×1,5 khi `allies_alive >= 1` · `windup`; `CASTER_TO_TARGET / square_streak / poison` · Phản đòn: bước đi; Độc làm mới chứ không chồng → 2 chuột ≠ 2× độc.
- Status: DESIGNED. Khác Scorpion sting: 1/0,5 s × 2 s (= 4) so với 1,5 × 3 s (= 9).

**`mire_slug` Mire Slug — Normal (B0–1), bog, mire_immune** · vai: **tạo lầy**
> **[ĐÃ THAY KHI TRIỂN KHAI — xem MONSTER-SKILL-PHASE2-PLAN.md §13.1]** `count 2` ở dưới KHÔNG dùng được cho một
> đòn đánh: `PatternController` chỉ đọc `pattern.count` trong nhánh `marker` (:1057), nên một attack mang
> `count: 2` lặng lẽ đặt MỘT ô. Data đã ship viết thành `offsets: [[0,0],[1,0]]` + `exclude_player`.

- **`slug_slime_trail` — Slime Trail** (attack, zone) · Nhớt lầy 2 ô cạnh người chơi · `near_player` count 2 exclude_player · `zone {mire, 4 s}`
  (**mới**: `TileHazards.add_mire`) · 0,6 / 1,0 · Hồi 5 · `windup`; `DIRECT_MANIFESTATION / none / poison` · Phản đòn: báo đỏ 1 s; không bước vào ô lầy (×1,6 bước, 0,5/0,5 s).
- `shared_sidestep` weight 0,3 (sên chậm, `cooldown_sec` 7).
- Status: DESIGNED. Khác trait `bog_spread` (định kỳ, ưu tiên ô thoát): Trail là skill có báo đỏ, né được.

**`swamp_lizard` Swamp Lizard — Normal (B1–2, D1), reed_maze** · vai: **ăn người bị chậm**
- **`lizard_tail_sweep` — Tail Sweep** (attack) · Quật đuôi 3 ô, làm chậm · `near_player` `[[0,0],[1,0],[2,0]]` rot 4 must_cover · 9 dmg + slow 1,5 ·
  0,5 / 1,1 · Hồi 3,5 · `windup`; `CASTER_TO_TARGET / square_streak / slash` · Phản đòn: bước vuông góc.
- **`lizard_drag_bite` — Drag Bite** (attack) · Chỉ cắn người đang **chậm hoặc trong lầy** · Kích hoạt: `player_status: slow` **hoặc**
  `player_on_zone: mire` (key mới), weight 2 · `on_player` 1 ô · 14 dmg + root 0,7 · 0,4 / 1,0 · Hồi 4 · `windup`; `SKY_TO_TARGET / falling_squares / slash` ·
  Phản đòn: ra khỏi lầy trước; F1 tính `lock_left` với slow nên warning 1,0 vẫn đủ 1 bước.
- Status: DESIGNED. 2 skill nhưng skill 2 có điều kiện → chỉ "nhớ" một luật: đừng để bị chậm gần Thằn Lằn.

**`marsh_toad` Marsh Toad — Normal (B1–2, D1–2), bog var** · vai: **kéo mồi vào lầy**
> **[ĐÃ THAY KHI TRIỂN KHAI — xem MONSTER-SKILL-PHASE2-PLAN.md §16.1]** `[[0,0],[0,1]]` ở dưới tạo ra một cặp ô
> NẰM NGANG, không phải lưỡi dọc. Trên `column_of_player`, planner map `Vector2i(player.x - off.y, start + off.x)`
> (`pattern_planner.gd:87`): **`off.x` đi XUỐNG cột, `off.y` đi NGANG**. Data đã ship viết `[[0,0],[1,0]]`.
> Đây là lần thứ BA cùng một cặp chữ số sai (`eater_ember_belch`, `scarab_spear` đã ship rồi phải sửa, và dòng này).

- **`toad_tongue` — Tongue Pull** (attack) · Lưỡi dọc cột 2 ô, trúng thì **kéo** 1 ô về vạch chia · `column_of_player` `[[0,0],[0,1]]` ·
  10 dmg + `pull {cells 1}` (**mới**: `CutEffects.pull_toward` phía người chơi; bị chặn → R3 Va Đập 8 + pin 0,6 theo luật phản ứng sẵn có) ·
  0,6 / 1,1 · Hồi 4,5 · `windup`; `CASTER_TO_TARGET / square_streak / knockback` · Phản đòn: bước ngang; đừng đứng ngay trước ô lầy/gai (kéo vào = R3).
- Status: DESIGNED. Ngân sách đẩy/kéo: ICD 2 s theo phe (§9.2).

**`reed_witch` Reed Witch — Normal (B2, D1–2), reed_maze var, trait rotten_thrower (9 s)** · vai: **độc diện rộng**
- **`witch_rot_cloud` — Rot Cloud** (attack) · Mây mục hình L, dính Độc · `on_player` L 3 ô rot 4 · 8 dmg + `poison {3 s, 0,5, 1,5}` · 0,5 / 1,1 · Hồi 4 ·
  `windup`; `SKY_TO_TARGET / falling_squares / poison` · Phản đòn: ra phía mở của L; khối thối (trait) chiếm tay → đừng nhặt bừa.
- Status: DESIGNED. Khác `spore_squares` (L + Rạn): Độc thay Rạn.

**`bog_hound` Bog Hound — Normal (B2, D2), bog var, trait row_burner** · vai: **đuổi**
- **`hound_mire_chase` — Mire Chase** (attack) · Lao dọc hàng, nhanh hơn khi mồi chậm · `row_of_player` 3 ô start front clip min 2 · 12 dmg ·
  0,5 / 1,0; weight ×2 khi `player_status: slow` · Hồi 3,5 · `windup`; `GROUND_PROPAGATION / floor_run / slash` · Phản đòn: đổi hàng.
- Status: DESIGNED. Khác Ember Hound (thưởng Rạn, 2 ô): thưởng slow, 3 ô.

**`spore_cap` Spore Cap — Elite, bog, trait spore_burst** · cơ chế: **mỗi đòn trúng → lầy (trait); tự hồi khi yếu**
> **[ĐÃ BỔ SUNG KHI TRIỂN KHAI — xem MONSTER-SKILL-PHASE2-PLAN.md §16.2]** Data đã ship thêm `clip: true,
> min_cells: 3`. Không có `clip`, `_add_plan` bỏ CẢ kế hoạch khi chỉ một ô rơi ngoài nửa sân, và trên arena lưới
> khuyết (`bog`, `reed_maze`) kỹ năng **không bao giờ tung ra** — `_cfg.problems` vẫn rỗng, nên nó trông y hệt một
> kỹ năng chưa tới lượt. `witch_rot_cloud` đã hỏng đúng kiểu này trước khi phát hiện.

- **`spore_puff` — Spore Puff** (attack) · Bào tử chữ thập 5 ô, Độc · `near_player` chữ thập must_cover (bog 5×3 = 15 ô → cap 7) ·
  8 dmg + `poison {3 s, 0,5, 1}` · 0,6 / 1,2 · Hồi 5 · `windup`; `SKY_TO_TARGET / falling_squares / poison` · Phản đòn: bước chéo.
- **`spore_regrow` — Regrow** (self) · Mọc lại: hồi 12 % máu tối đa trong 3 s · Kích hoạt: `hp_below 0,6`, weight 1,5 ·
  `heal {ratio 0,12, sec 3}` (**mới**, kênh `CombatState.heal_enemy`) · windup 1,2 (bị ngắt = mất hồi) · Hồi 10, `interruptible: true`, `interrupt_stun_sec` 1,0 ·
  `howl`→`windup`; `DIRECT_MANIFESTATION / none / guard` · Phản đòn: đánh khi nó mọc — **nhưng** mỗi đòn trúng rải lầy (trait) →
  dùng đòn **ít ô, mạnh** (desc trong strings đã dạy).
- Status: DESIGNED.

**`leap_frog` Leap Frog — Elite, reed_maze, trait hop_skip** · cơ chế: **nhảy 2 ô (trait) + đè hai nhịp**
> **[ĐÃ BỔ SUNG KHI TRIỂN KHAI — xem MONSTER-SKILL-PHASE2-PLAN.md §16.2]** Data đã ship thêm `clip: true,
> min_cells: 3`, cùng lý do với `spore_puff`: 2×2 trên `reed_maze` rụng ở cả bốn hướng xoay nếu không clip.

- **`frog_leap_slam` — Leap Slam** (attack) · Đè 2×2, nảy lên đè lại · `near_player` 2×2 must_cover · 12 dmg · `followup {same_cells, delay 1,0, warning 1,0, damage 10}` ·
  0,6 / 1,2 · Hồi 5 · `windup_heavy`; `SKY_TO_TARGET / falling_squares / shatter` · Phản đòn: ra khỏi 2×2, không quay lại 1 s.
- **`frog_croak` — Croak** (self) · Kêu: cooldown ×0,75 trong 6 s · `haste {0,75, 6}` · windup 1,2 · Hồi 12, `interruptible: true`, `interrupt_stun_sec` 0,8 ·
  `howl`; impact `none` · Phản đòn: ngắt lúc kêu (như Alpha Howl, yếu hơn).
- Status: DESIGNED.

**`toad_matriarch` Toad Matriarch — Boss, bog var, mr 3, mire_immune, trait bog_spread (+ seal_caster → skill)** · cơ chế học được: **lầy lan + ô sụp + tiếng kêu độc**
- Pha 1 (1,0): `matriarch_tongue_lash`, `matriarch_sink`, `matriarch_shift`, `matriarch_spit`; mechanic `matriarch_sink`.
- Pha 2 (0,5): + `matriarch_toxic_croak`; every_nth 3; transition 1,5; `on_enter: [matriarch_regrow]`; `phases[].traits` override `bog_spread {interval_sec 6}`.
- **`matriarch_spit` — Mire Spit** (attack) · 1 ô + lầy ô đó · `on_player` · 10 dmg + `zone {mire, 3 s}` · 0,4 / 0,9 · Hồi 2,8 · `windup`; `SKY_TO_TARGET / falling_squares / poison`.
- **`matriarch_tongue_lash` — Tongue Lash** (attack) · Cột 3 ô, chậm · `column_of_player` 3 clip min 2 · 12 dmg + slow · 0,6 / 1,2 · Hồi 4,5 · `windup`; `CASTER_TO_TARGET / square_streak / slash`.
> **[SẼ THAY KHI TRIỂN KHAI — xem MONSTER-SKILL-PHASE2-PLAN.md §13.1]** `count 2` không dùng được cho một đòn
> đánh (chỉ nhánh `marker` đọc nó). Viết thành `offsets: [[0,0],[1,0]]` + `exclude_player` như `slug_slime_trail`
> và `sphinx_bury`.

- **`matriarch_sink` — Sink** (attack, zone) · Sụp 2 ô thoát · `near_player` count 2 exclude_player · `zone {drop, warn 0,8, hole 1,2}` · 0,6 / 1,2 · Hồi 9 ·
  `windup`; `DIRECT_MANIFESTATION / none / seal` · Phản đòn: luật Ô rớt. (Thay `seal_caster` vì trait ấy móc swing block.)
- **`matriarch_shift`** = `shared_sidestep` (hồi 8, weight 2).
- **`matriarch_toxic_croak` — Toxic Croak** (attack) · 2×2 độc, lặp lệch hàng · `near_player` 2×2 must_cover · 14 dmg + `poison {4 s, 0,5, 1,5}` ·
  `followup {first_shift [[0,1]] rot [0,180], show_with_first, warning 0,75, damage 10}` · 0,9 / 1,5 · weight 0, `interruptible: false`, recovery 1,5 ·
  `windup_heavy`; `SKY_TO_TARGET / falling_squares / poison`.
- **`matriarch_regrow` — Regrow** (self) · hồi 8 % một lần khi vào pha 2 · `heal {0,08, 1,5 s}`, `once`, weight 0 · `howl`.
- Status: DESIGNED.


### 4.5 Hầm Ngục `ch2` — bản sắc: **nguyền (Rạn + slow), trói/ghim, hố, xác không chết, nghi lễ khi đồng đội ngã**

Trait giữ: `rotten_thrower`, `row_burner`, `slam`, `step_reactor` (→ chuyển thành điều kiện skill). `seal_caster` của Cai Ngục → skill.
"Summon" (undead gọi thêm) **không thiết kế**: không có đơn vị thứ hai trong engine; nếu multi-enemy có spawn sau này, Cultist là ứng viên đầu.

**`skeleton` Skeleton Guard — Normal (B0), square, def 2** (không ra tầng 5)
- **`skeleton_shield_bash` — Shield Bash** (attack) · Húc khiên 1 ô, choáng ngắn · `on_player` 1 ô · 8 dmg + `pin {0,5 s}` (F4) · 0,5 / 1,0 · Hồi 3,2 ·
  `windup`; `CASTER_TO_TARGET / square_streak / shatter` · Phản đòn: bước đi; pin ngắn, không chồng (F4 1 s).
- `shared_sidestep` weight 0,3.
- Status: DESIGNED.

**`zombie` Zombie — Normal (B0–1), rect, def 2** · vai: **trói**
- **`zombie_grab` — Grab** (attack) · Níu chân 1 ô · `on_player` · 8 dmg + `root {0,8 s}` · 0,5 / 1,0 · Hồi 3 · `windup`; `DIRECT_MANIFESTATION / none / curse` ·
  Phản đòn: ô đơn; bị níu = ăn đòn tiếp của đồng đội → ưu tiên né Zombie.
- Status: DESIGNED. Khác `root_prick` (rễ 0,7 s, từ dưới đất): chậm hơn, trói lâu hơn, không có creep.

**`bat_swarm` Crypt Bat Swarm — Normal (B1–2, D1), cross var, def 2** · vai: **rải, cơ động**
- **`swarm_scatter` — Scatter Bite** (attack) · Ba vết cắn rời nhau · `on_player` variants `[[0,0],[2,0],[1,1]]`, `[[0,0],[0,2],[1,1]]`, `[[0,0],[1,1],[2,2]]`
  rot 4 clip min 2 · 6 dmg + fragile 1 · 0,4 / 1,0 · Hồi 2,8 · `windup`; `SKY_TO_TARGET / falling_squares / slash` · Phản đòn: ô lẻ, một bước là thoát.
- **`swarm_flutter`** = `shared_sidestep` số riêng (hồi 3, weight 1,0, windup 0,5): đàn dơi đổi hàng liên tục · Phản đòn: dự đoán ô khung ngà.
- Status: DESIGNED. Khác `volley` (chéo 3 ô liền): rời rạc + Rạn.

**`slime` Dungeon Slime — Normal (B1–2, D1–2), u_shape var, def 2** · vai: **bọc, chậm**
- **`slime_engulf` — Engulf** (attack) · Trùm 2×2, dính nhớt · `near_player` 2×2 must_cover · 10 dmg + slow 1,5 · 0,7 / 1,3 · Hồi 4,5 · `windup`; `DIRECT_MANIFESTATION / none / poison` ·
  Phản đòn: ra khỏi 2×2.
- **`slime_ooze` — Ooze** (attack, zone) · Để lại 1 ô nhớt (lầy) · `near_player` count 1 exclude_player · `zone {mire, 3 s}` · 0,5 / 1,0 · Hồi 6 · `windup`; impact `poison` ·
  Phản đòn: không bước vào.
- Status: DESIGNED. Dùng lại mire của đầm lầy với số nhỏ hơn (3 s/1 ô) — khác về vai: Slime dùng nhớt để **giữ** người chơi trong tầm Engulf.

**`ghost` Ghost — Normal (B1, D1), rect, 24 HP / def 12** · vai: **chỉ lửa hoặc xuyên giáp mới đau** (đã có qua defense)
- **`ghost_wail` — Wail** (attack) · Tiếng rú dọc cột 2 ô, Rạn · `column_of_player` `[[0,0],[0,1]]` · 8 dmg + fragile 1 · 0,5 / 1,0 · Hồi 3,2 ·
  `windup`; `CASTER_TO_TARGET / chain_spark / curse` · Phản đòn: bước ngang.
- **`ghost_phase` — Phase** (self) · Tan rồi hiện ở hàng khác, lúc tan không đánh được · `move {adjacent_row}` + `evade {0,8 s}` · windup 0,5 · Hồi 6, weight 0,8,
  `counts_as_cast: false` · `step`; impact `none` · Phản đòn: ghim khối trước khi nó tan; đợi nó hiện.
- Status: DESIGNED. `ghost_phase` **dùng chung** với `ghost_elite` (cùng id, cùng số): cùng loài, chỉ khác máu/giáp/skill tấn công.

**`reacter` The Reacter — Normal (B1–2, D1–2), cross, def 2, mr 2, trait step_reactor** · vai: **phạt bước**
- **`reacter_lash` — Trip Lash** (attack) · Quất khi người chơi **vừa bước 3 lần** · Kích hoạt: `player_steps_since >= 3` (key mới, đếm từ lần
  dùng trước; thay trait `step_reactor`, giữ tên "Dây Vướng" trong strings), weight 3; ngoài điều kiện không dùng · `near_player` 3 ô liền
  variants L/bar must_cover · 9 dmg · 0,3 / 0,9 (nhanh — nhưng vẫn ≥ 1 bước với step_cd 0,55) · Hồi 2 ·
  `windup`; `DIRECT_MANIFESTATION / none / slash` · Phản đòn: đứng yên đặt khối (desc hiện có); mỗi 3 bước thì né thêm 1 lần.
- Status: DESIGNED (chuyển từ trait → điều kiện skill để Reacter cũng chơi được trên pattern brain; số giữ của trait: 3 bước, 3 ô, 0,5 → 0,9 s cảnh báo cho F1).

**`cultist` Cultist — Normal (B2, D2), staircase var, def 2** · vai: **vòng nguyền + nghi lễ khi đồng đội chết**
- **`cultist_curse_ring` — Curse Ring** (attack) · 4 ô quanh người chơi, không trúng ô đang đứng; bước ra đâu cũng trúng trừ khi đứng yên hoặc bước 2 lần ·
  `near_player` `[[0,0],[1,0],[-1,0],[0,1],[0,-1]]` với **`exclude_player`** (4 ô kề) · 8 dmg + slow 1,5 · 0,6 / 1,3 · Hồi 4,5 · `windup`;
  `DIRECT_MANIFESTATION / none / curse` · Phản đòn: **đứng yên** là an toàn (ngược mọi đòn khác) — hoặc 2 bước liền (F1: 2 bước ≈ 0,55+0,25 < 1,3).
- **`cultist_dark_rite` — Dark Rite** (self) · Khi một đồng đội vừa ngã: cả phe +guard 4 và cooldown ×0,7 trong 5 s · Kích hoạt: `ally_died_within_sec 4`
  (Bậc B, key mới), `once`, weight 3 · `guard {4, 5 s}` + `haste {0,7, 5}` · windup 1,0 · `interruptible: true`, `interrupt_stun_sec` 1,0 ·
  `howl`; impact `curse` · Phản đòn: ngắt nghi lễ ngay sau khi hạ con đầu; hoặc giết Cultist **trước**.
- Status: DESIGNED. Một mình: chỉ Curse Ring.

**`rat_king_guard` Rat King's Guard — Normal (B2, D2), ring var, def 2, trait row_burner** · vai: **đẩy lùi**
- **`guard_shove` — Shield Shove** (attack) · Húc thanh 2 ô, trúng thì **đẩy lùi** 1 ô · `on_player` `[[0,0],[1,0]]` rot 4 · 10 dmg + `push {1, away}`
  (**mới**: `CutEffects.push_away` phía người chơi; bị chặn → R3) · 0,5 / 1,1 · Hồi 4 · `windup`; `CASTER_TO_TARGET / square_streak / knockback` ·
  Phản đòn: bước vuông góc; đừng đứng sát hàng cuối (đẩy bị chặn = Va Đập).
- Status: DESIGNED.

**`jailer` The Jailer — Elite, u_shape var, mr 2, trait rotten_thrower + row_burner (+ seal_caster → skill)** · cơ chế: **móc xích kéo + khóa ô**
- **`jailer_chain_hook` — Chain Hook** (attack) · Móc dọc cột 2 ô, trúng thì trói và kéo 1 ô · `column_of_player` `[[0,0],[0,1]]` · 12 dmg + root 0,8 +
  `pull {1}` · 0,6 / 1,2 · Hồi 5 · `windup`; `CASTER_TO_TARGET / chain_spark / knockback` · Phản đòn: bước ngang.
- **`jailer_lockdown` — Lockdown** (attack, zone) · Khóa 2 ô thoát thành hố · `near_player` count 2 exclude_player · `zone {drop, 0,8, 1,2}` · 0,6 / 1,2 · Hồi 9 ·
  `windup`; `DIRECT_MANIFESTATION / none / seal` · Phản đòn: luật Ô rớt. (Thay `seal_caster {cells 2–3, interval 9}`.)
- Status: DESIGNED. 2 trait tick (khối thối, hàng lửa) giữ nguyên → Elite này **nhiều cơ chế nhất roster** (4); nếu playtest quá tải thì bỏ `row_burner` trước (ghi để người dùng quyết, không đổi ở đây).

**`ogre_king` Giant Ogre — Boss, ring var, mr 3, trait slam** · cơ chế học được: **nứt đất (trait) + chùy hai nhịp**
- Pha 1 (1,0): `ogre_club`, `ogre_grab`, `ogre_shift`; mechanic `ogre_club`.
- Pha 2 (0,5): + `ogre_quake`; every_nth 3; transition 1,5; `on_enter: [ogre_roar]`; `phases[].traits` override `slam {slam_interval_sec 5}`.
- **`ogre_club` — Club** (attack) · Chùy 2×2 · `near_player` 2×2 must_cover · 14 dmg · 0,7 / 1,3 · Hồi 4,5, `interruptible: false`, recovery 1,2 · `windup_heavy`; `DIRECT_MANIFESTATION / none / shatter`.
- **`ogre_grab` — Grab** (attack) · Tóm 1 ô, ghim · `on_player` · 10 dmg + pin 0,6 · 0,5 / 1,0 · Hồi 3,5 · `windup`; `CASTER_TO_TARGET / square_streak / knockback`.
- **`ogre_shift`** = `shared_sidestep` (hồi 8, weight 2).
- **`ogre_roar` — Roar** (self) · `haste {0,7, 6}`, weight 0 (chỉ on_enter), `interrupt_stun_sec` 1,0 · `howl`.
- **`ogre_quake` — Quake** (attack) · Cả hàng 4 ô rồi hàng kề · `row_of_player` 4 ô clip min 2 · 16 dmg · `followup {first_shift [[0,1]] rot [0,180], show_with_first, 0,75, damage 12}` ·
  0,9 / 1,6 · weight 0, `interruptible: false`, recovery 1,5 · `windup_heavy`; `GROUND_PROPAGATION / floor_run / shatter` · Phản đòn: sang hàng không có làn sọc chờ.
- Status: DESIGNED.

### 4.6 Tháp Sương `ch3` — bản sắc: **Giá Lạnh tích tầng (nổ 24), Đóng Băng ngắn, chậm, giáp băng**

Trait giữ: `fuse_cannon`, `frost_aura`, `row_burner` (ice_golem — lệch chủ đề, giữ vì là trait mặc định của node danger). `thorn_field`
của Frost Mage → skill. `phase_shift` của Mist Lord → `phases[]`. **Toàn vùng phụ thuộc sửa G2** (Giá Lạnh của quái lên người chơi không nổ).
Ngân sách Giá Lạnh (§9.2): nổ 24 bỏ giáp là 12 % máu hero chuẩn 200; trong bầy chỉ **một** quái mang Giá Lạnh ≥ 2 tầng/đòn.

**`frost_sprite` Frost Sprite — Normal (B0), square, def 4** (không ra tầng 6)
- **`sprite_frost_kiss` — Frost Kiss** (attack) · Chạm 1 ô, +1 Giá Lạnh · `on_player` · 6 dmg + `frost {stacks 1}` · 0,4 / 0,9 · Hồi 2,4 · `windup`; `CASTER_TO_TARGET / square_streak / freeze` ·
  Phản đòn: ô đơn; 3 lần trúng = nổ 24 → không được trúng 3 lần trong một trận ngắn.
- Status: DESIGNED.

**`wisp` Wisp — Normal (B0–1), rect, def 4** · vai: **đèn (marker) + lóe từ hàng đèn**
- **`wisp_lantern` — Lantern** (marker) · Treo đèn băng trên nửa địch · `enemy_half_empty` count 1 row player · `marker {kind lantern, life 8, break_min_cells 1}` · windup 0,6 · Hồi 6 ·
  Phản đòn: đánh 1 ô lên đèn.
- **`wisp_lantern_flare` — Lantern Flare** (attack) · Lóe sáng dọc hàng đèn · `requires_anchor 1` · `row_of_anchor` `[[0,0],[1,0]]` start front · 9 dmg + frost 1 · 0,5 / 1,0 · Hồi 3,2 ·
  `windup`; `CASTER_TO_TARGET / chain_spark / freeze` · Phản đòn: rời hàng đèn.
- Status: DESIGNED. Cùng khung marker với Mirage Sprite (sa mạc) nhưng hiệu ứng Giá Lạnh và đèn nằm **hàng người chơi** lúc đặt.

**`stone_sentry` Stone Sentry — Normal (B1–2, D1), cross_wide, def 4** · vai: **tường băng đội**
- **`sentry_rime_bulwark` — Rime Bulwark** (self) · Guard phe +5 · weight 1,2 khi `allies_alive >= 1` hoặc `hp_below 0,6`, 0,3 nếu không · `guard {5, 4 s}` · Hồi 9, `interrupt_stun_sec` 0,8 · `guard`; impact `guard`.
- **`sentry_hammer` — Rime Hammer** (attack) · Thanh 2 ô · `on_player` bar rot 4 · 12 dmg · 0,5 / 1,1 · Hồi 3,4 · `windup`; `CASTER_TO_TARGET / square_streak / shatter`.
- Status: DESIGNED. = Scarab Guard về vai; khác sân (cross_wide 5×5) và impact; hai vùng không gặp nhau trong một trận.

**`snow_wolf` Snow Wolf — Normal (B1–2, D1), pillars, def 4** · vai: **săn người đã lạnh**
- **`snow_wolf_hunt` — Winter Hunt** (attack) · Lao dọc hàng, làm chậm; hăng hơn khi mồi có Giá Lạnh · `row_of_player` `[[0,0],[1,0]]` start front · 10 dmg + slow 1,5 ·
  weight ×1,8 khi `player_status: frost` · 0,5 / 1,0 · Hồi 3,2 · `windup`; `GROUND_PROPAGATION / floor_run / freeze` · Phản đòn: đổi hàng.
- `shared_sidestep` weight 0,5.
- Status: DESIGNED. Khác `chase_bite` (rừng) và Ember/Bog Hound: thưởng theo Giá Lạnh, thêm slow.

**`fuse_golem` Fuse Cannon — Normal (B1–2, D1–2), rect, mr 2, trait fuse_cannon** · vai: **ngòi (trait) + mảnh băng**
- **`fuse_shard_burst` — Shard Burst** (attack) · Ba mảnh băng rời · `on_player` variants rời rạc (như `swarm_scatter`) clip min 2 · 8 dmg + frost 1 · 0,5 / 1,1 · Hồi 3,6 ·
  `windup`; `SKY_TO_TARGET / falling_squares / freeze` · Phản đòn: một bước thoát; dập ngòi bằng đòn ≥ 30.
- Status: DESIGNED. Trait ngòi giữ nguyên (tick + on_boss_damaged, tương thích).

**`rime_archer` Rime Archer — Normal (B2, D2), staircase var, def 4** · vai: **bắn hàng + chông băng**
- **`rime_frost_arrow` — Frost Arrow** (attack) · Tên băng dọc hàng 4 ô · `row_of_player` 4 ô start any clip min 2 · 12 dmg + frost 1 · 0,8 / 1,0 · Hồi 3,4 ·
  `windup`; `CASTER_TO_TARGET / square_streak / freeze` · Phản đòn: đổi hàng.
- **`rime_caltrops` — Ice Caltrops** (attack, zone) · Chông băng 1 ô cạnh người chơi · `near_player` count 1 exclude_player · `zone {thorns, sec 3, damage 4, fragile_stacks 1}` · 0,5 / 1,0 · Hồi 6 ·
  `windup`; `DIRECT_MANIFESTATION / none / thorns` · Phản đòn: không bước vào.
- Status: DESIGNED. Khác `aimed_shot`: Giá Lạnh; khác `seedbed`: 4 dmg thay 6, kèm tên.

**`ice_golem` Ice Golem — Normal (B2, D2), diamond var, def 4, trait row_burner** · vai: **đấm băng ghim**
- **`ice_golem_glacier_fist` — Glacier Fist** (attack) · Đấm 2×2, trúng thì Đóng Băng · `near_player` 2×2 must_cover · 14 dmg + pin 0,6 · 0,8 / 1,4 · Hồi 5, `interruptible: false`, recovery 1,2 ·
  `windup_heavy`; `DIRECT_MANIFESTATION / none / freeze` · Phản đòn: ra khỏi 2×2; không ngắt được.
- Status: DESIGNED.

**`ghost_elite` Greater Ghost — Normal (B2, D2), cross_wide, 36 HP / def 16** · vai: **ma lạnh**
- **`greater_ghost_wail` — Frozen Wail** (attack) · Cột 3 ô, Giá Lạnh · `column_of_player` 3 ô clip min 2 · 10 dmg + frost 1 · 0,5 / 1,1 · Hồi 3,4 · `windup`; `CASTER_TO_TARGET / chain_spark / freeze`.
- `ghost_phase` (dùng chung với `ghost`).
- Status: DESIGNED.

**`frost_mage` Frost Mage — Elite, diamond var, mr 2, trait frost_aura (+ thorn_field → skill)** · cơ chế: **chồng Giá Lạnh tới nổ; băng hộ thân theo mốc**
- **`frost_mage_cold_snap` — Cold Snap** (attack) · 1 ô, +2 Giá Lạnh · `on_player` · 8 dmg + frost 2 · 0,5 / 1,0 · Hồi 3,2 · `windup`; `CASTER_TO_TARGET / square_streak / freeze` ·
  Phản đòn: ô đơn, nhưng trúng 2 lần = nổ 24 → đây là đòn phải né nhất vùng.
- **`frost_mage_rime_field` — Rime Field** (attack, zone) · Gai băng 2 ô thoát · `near_player` count 2 exclude_player · `zone {thorns, 3 s, 6, +1 Rạn}` · 0,5 / 1,1 · Hồi 6 ·
  `windup`; `DIRECT_MANIFESTATION / none / thorns` · (Thay `thorn_field {min_swing 4, max 3}`.)
- **`frost_mage_ice_ward` — Ice Ward** (marker + guard) · Đặt tinh thể, giáp +6 khi tinh thể còn · `hp_below 0,5`, `once` · `enemy_half_empty` count 1 ·
  `marker {kind crystal, life 8, break 1}` + `guard {6, 8 s, while_markers}` · windup 0,8 · `guard`; impact `freeze` · Phản đòn: phá tinh thể / Xuyên giáp (= `wreath_guard` của Matron, bản băng).
- Status: DESIGNED.

**`mist_lord` Frost Lord — Boss (Kẻ Gác), pillars, mr 3, trait frost_aura (+ phase_shift → phases)** · cơ chế học được: **mốc tinh thể + trắng xóa hai nhịp**
- Pha 1 (1,0): `mist_lord_rime_lance`, `mist_lord_frost_nail`, `mist_lord_crystal_anchor`, `mist_lord_shift`; mechanic `mist_lord_crystal_anchor`.
- Pha 2 (0,5 — trùng `frost_aura.until_hp_ratio`, sương tắt đúng lúc pha 2 bắt đầu, có chủ ý): + `mist_lord_whiteout`, `mist_lord_ice_mantle`; every_nth 3;
  transition 1,5; `on_enter: [mist_lord_crystal_anchor]`; override `crystal_anchor {count 2}`. Thay `phase_shift {brain aggressive, step ×0,85, +row_burner}`
  bằng: `phases[].traits: [row_burner]` (G5) + `pattern_tempo_mult` override pha 0,85 (**mới**: tempo theo pha).
- **`mist_lord_frost_nail` — Frost Nail** (attack) · 1 ô, ghim 0,5 · `on_player` · 8 dmg + pin 0,5 · 0,4 / 0,9 · Hồi 3 · `windup`; `CASTER_TO_TARGET / square_streak / freeze`.
- **`mist_lord_rime_lance` — Rime Lance** (attack) · Cột 3 ô, Giá Lạnh · `column_of_player` 3 clip min 2 · 12 dmg + frost 1 · 0,6 / 1,2 · Hồi 4,5 · `windup`; `CASTER_TO_TARGET / square_streak / freeze`.
- **`mist_lord_crystal_anchor` — Crystal Anchor** (marker) · `enemy_half_empty` count 1 · `marker {crystal, 12 s, break 1}` · Hồi 8 · (như `root_anchor`, bản băng; các đòn `row_of_anchor` không có ở đây — mốc nuôi giáp).
- **`mist_lord_ice_mantle` — Ice Mantle** (self) · `requires_anchor 1` · `guard {6, 10 s, while_markers}` · Hồi 12 · `guard`.
- **`mist_lord_shift`** = `shared_sidestep` (hồi 8, weight 3, footprint 1 ô).
- **`mist_lord_whiteout` — Whiteout** (attack) · 2×2 rồi lệch hàng, mỗi nhịp +1 Giá Lạnh · `near_player` 2×2 must_cover · 14 dmg + frost 1 ·
  `followup {first_shift [[0,1]] rot [0,180], show_with_first, 0,75, damage 10 + frost 1}` · 0,9 / 1,5 · weight 0, `interruptible: false`, recovery 1,5 ·
  `windup_heavy`; `SKY_TO_TARGET / falling_squares / freeze` · Phản đòn: ra phía không có làn sọc; **đừng** ăn cả hai nhịp (2 tầng + Lance = nổ).
- Status: DESIGNED.

### 4.7 Không Đảo `sky_isles` — bản sắc: **gió đẩy, ô rơi, cơ động, mây che**

Trait giữ: `gust`, `island_drop`, `shroud`, `row_burner` (thunder_shaman). Luật đẩy (§9.2): không đẩy vào ô đang cảnh báo rơi/hố/cát
(gust đã làm), ICD đẩy 2 s theo phe; R3 Va Đập khi bị chặn (8 + pin 0,6) **tính vào** ngân sách CC.

**`cloud_sprite` Cloud Sprite — Normal (B0–1), twin_isles** · vai: **che báo trúng ngắn**
- **`cloud_sprite_mist_veil` — Mist Veil** (self) · Phủ mây: ẩn báo trúng 3 s · `shroud {sec 3}` (**mới**: OR vào `hit_forecast_blocked`) · windup 0,6 · Hồi 9, weight 0,8 ·
  `windup`; impact `none` · Phản đòn: đặt khối theo trí nhớ vị trí; mây tan khi nó bị ghim.
- `shared_jab`.
- Status: DESIGNED. Khác trait `shroud` của Cloud Veil (vĩnh viễn, trừ khi pin/niệm): Tinh Mây che **có kỳ hạn**.

**`harpy` Harpy — Normal (B0–1), three_isles** · vai: **bổ nhào, hất lùi**
- **`harpy_dive` — Talon Dive** (attack) · Bổ nhào 1 ô, hất lùi 1 ô · `on_player` · 10 dmg + `push {1, away}` · 0,5 / 1,0 · Hồi 3,2 · `windup`; `SKY_TO_TARGET / falling_squares / knockback` ·
  Phản đòn: bước đi; trên three_isles (7×2) đứng hàng sau = đẩy bị chặn = Va Đập → đứng hàng trước.
- Status: DESIGNED.

**`wind_monk` Wind Monk — Normal (B1–2, D1), islands_bridge (crumble)** · vai: **đẩy theo cột, dịch chuyển**
- **`monk_gale_palm` — Gale Palm** (attack) · Chưởng gió dọc cột 2 ô, đẩy lùi · `column_of_player` `[[0,0],[0,1]]` · 9 dmg + `push {1, away}` · 0,5 / 1,1 · Hồi 4 ·
  `windup`; `GROUND_PROPAGATION / floor_run / knockback` · Phản đòn: bước ngang; trên sân crumble, bị đẩy = đổi ô = reset đồng hồ nứt (có lợi!) trừ khi đẩy bị chặn.
- **`monk_wind_step` — Wind Step** (self) · `move {to: far_cell}` · windup 0,5 · Hồi 6, weight 1,0, `counts_as_cast: false` · Phản đòn: đánh khung ngà.
- Status: DESIGNED. Khác Harpy: cột + không kèm nhào; khác Nomad: không evade.

**`storm_eagle` Storm Eagle — Normal (B1–2, D1–2), twin_isles** · vai: **nhanh, lượn**
- **`eagle_talon_rake` — Talon Rake** (attack) · Cào dọc hàng 3 ô · `row_of_player` 3 ô start front clip min 2 · 12 dmg · 0,5 / 1,1 · Hồi 3,0 · `windup`; `GROUND_PROPAGATION / floor_run / slash`.
- **`eagle_circle`** = `shared_sidestep` số riêng (hồi 3, weight 2, windup 0,5) — Đại Bàng đổi hàng liên tục · Phản đòn: dự đoán khung ngà.
- Status: DESIGNED. Nhịp nhanh nhất vùng (step mult 1,2 trong data) + skill ngắn: "đọc nhanh".

**`sky_sentinel` Sky Sentinel — Normal (B2, D1–2), three_isles, def 3** · vai: **làm rơi ô**
- **`sentinel_stone_gale` — Stone Gale** (attack, zone) · Làm 1 ô cạnh người chơi rơi 3 s · `near_player` count 1 exclude_player · `zone {id: fall, warn 1,0, fall 3}`
  (**mới**: `TileHazards.drop_cells`; không bao giờ ô cầu, không đảo cuối — luật có sẵn) · 0,6 / 1,2 · Hồi 7 · `windup`; `DIRECT_MANIFESTATION / none / shatter` ·
  Phản đòn: rời ô cảnh báo; bị rơi = đẩy + 8.
- **`sentinel_spear` — Sky Spear** (attack) · Cột 2 ô · `column_of_player` 2 · 12 dmg · 0,5 / 1,1 · Hồi 3,4 · `windup`; `CASTER_TO_TARGET / square_streak / slash`.
- Status: DESIGNED. Khác `island_drop` (trait, cả đảo): một ô, có chọn.

**`thunder_shaman` Thunder Shaman — Normal (B2, D2), islands_bridge, trait row_burner** · vai: **sét rải, choáng**
- **`shaman_thunder_call` — Thunder Call** (attack) · Ba tia sét rời, trúng thì Đóng Băng 0,5 · `on_player` variants rời rạc clip min 2 · 10 dmg + pin 0,5 · 0,6 / 1,2 · Hồi 4,5 ·
  `windup`; `SKY_TO_TARGET / falling_squares / burst` · Phản đòn: một bước; trait hàng lửa đọc là "hàng sét".
- Status: DESIGNED. (R4 Dẫn Điện trong catalog chưa có → không dùng "charged".)

**`gale_bird` Gale Bird — Elite, twin_isles, trait gust** · cơ chế: **gió tạt định kỳ (trait) + luồng xuống/lên**
- **`gale_bird_downdraft` — Downdraft** (attack) · Đè 2×2 gió, hất lùi · `near_player` 2×2 must_cover · 12 dmg + `push {1, away}` · 0,6 / 1,2 · Hồi 4,5 · `windup`; `SKY_TO_TARGET / falling_squares / knockback`.
- **`gale_bird_updraft` — Updraft** (self) · Bay vụt lên (không đánh được 1 s) rồi đáp ô xa · `evade {1,0}` + `move {far_cell}` · windup 0,6 · Hồi 9, weight 1, `counts_as_cast: false` ·
  `step`; impact `none` · Phản đòn: ghim khối trước khi nó bay.
- Status: DESIGNED.

**`cloud_veil` Cloud Veil — Elite, three_isles, trait shroud** · cơ chế: **ẩn báo trúng (trait) + tia hai bên + hóa mây**
- **`cloud_veil_fork_bolt` — Fork Bolt** (attack) · 1 ô rồi hai ô hai bên · `on_player` 1 ô · 10 dmg · `followup {first_shift [[0,1]] rot [0,180], show_with_first, 0,75, damage 8}` ·
  0,5 / 1,2 · Hồi 4 · `windup`; `SEQUENTIAL_CHAIN / chain_spark / burst` · Phản đòn: bước dọc trục còn lại.
- **`cloud_veil_vapor_form` — Vapor Form** (marker + guard) · `hp_below 0,5`, `once` · `marker {kind cloud, 8 s, break 1}` + `guard {5, 8 s, while_markers}` · `guard`; impact `none`.
- Status: DESIGNED. Sửa `shroud` để "đang niệm" đọc stage pattern (G6).

**`storm_dragon` Storm Dragon — Boss (Kẻ Gác), islands_bridge, mr 3, trait island_drop + gust** · cơ chế học được: **đảo rơi (trait) + bão hai nhịp đẩy**
- Pha 1 (1,0): `dragon_tail_sweep`, `dragon_storm_breath`, `dragon_wing_shift`; mechanic `dragon_storm_breath`.
- Pha 2 (0,5): + `dragon_tempest`; every_nth 3; transition 1,5; `phases[].traits` override `island_drop {interval_sec 8}`, `gust {interval_sec 9}` (G5).
- **`dragon_tail_sweep` — Tail Sweep** (attack) · Hàng 3 ô, hất lùi · `row_of_player` 3 ô clip min 2 · 14 dmg + `push {1, away}` · 0,7 / 1,3 · Hồi 5 · `windup`; `CASTER_TO_TARGET / square_streak / knockback`.
- **`dragon_storm_breath` — Storm Breath** (attack) · Cột 3 ô, chậm · `column_of_player` 3 clip min 2 · 12 dmg + slow · 0,6 / 1,2 · Hồi 4,5 · `windup`; `GROUND_PROPAGATION / floor_run / burst`.
- **`dragon_wing_shift`** = `shared_sidestep` (hồi 8, weight 2).
- **`dragon_tempest` — Tempest** (attack) · 2×2 rồi lệch, nhịp hai đẩy · `near_player` 2×2 must_cover · 16 dmg · `followup {first_shift, show_with_first, 0,75, damage 12 + push 1}` ·
  0,9 / 1,6 · weight 0, `interruptible: false`, recovery 1,5 · `windup_heavy`; `SKY_TO_TARGET / falling_squares / burst` · Phản đòn: ra phía không có làn sọc, về phía **không** có mép đảo sau lưng.
- Status: DESIGNED.

### 4.8 Tâm Lưới `an_dai` — trận cuối

**`an_dai_keeper` Heart Keeper — Final boss, an_dai_dais 5×5 (4 góc + tâm khuyết), mr 3** · cơ chế học được: **ô khóa (p1) → thêm hàng lửa, hung hãn (p2)**. Giữ đúng hai pha của data hiện tại.
- Pha 1 (1,0): `keeper_lattice_bolt`, `keeper_sigil_lane`, `keeper_lattice_seal`, `keeper_shift`; mechanic `keeper_lattice_seal`; brain movement `balanced`.
- Pha 2 (0,5): + `keeper_heart_flare`; every_nth 3; transition 1,0 (bất tử, banner `phase.an_dai_keeper.2` hiện có); `phases[].traits: [row_burner]`;
  brain_set `aggressive` (movement) — cần `phases[].brain_set` (**mới**, 1 dòng, `BossBrain.use_set` có sẵn).
- **`keeper_lattice_bolt` — Lattice Bolt** (attack) · 1 ô, Rạn · `on_player` · 10 dmg + fragile 1 · 0,4 / 0,9 · Hồi 2,8 · `windup`; `CASTER_TO_TARGET / square_streak / burst`.
- **`keeper_sigil_lane` — Sigil Lane** (attack) · Hàng 3 ô · `row_of_player` 3 clip min 2 · 14 dmg · 0,7 / 1,3 · Hồi 5, `interruptible: false`, recovery 1,2 · `windup_heavy`; `GROUND_PROPAGATION / floor_run / burst`.
- **`keeper_lattice_seal` — Lattice Seal** (attack, zone) · Khóa 2 ô (có thể gồm ô đang đứng theo luật Ô rớt) · `near_player` count 2 (không `exclude_player`; `ZoneRules.cast_drop` + `unit_cell_droppable` quyết) ·
  `zone {drop, 0,8, 1,2}` · 0,6 / 1,2 · Hồi 9 · `windup`; `DIRECT_MANIFESTATION / none / seal` · (Thay `seal_caster {may_target_player_cell}`.)
- **`keeper_shift`** = `shared_sidestep` (hồi 8, weight 2).
- **`keeper_heart_flare` — Heart Flare** (attack) · 2×2 rồi lệch · `near_player` 2×2 must_cover · 16 dmg + fragile 1 · `followup {first_shift, show_with_first, 0,75, damage 12}` · 0,9 / 1,5 ·
  weight 0, `interruptible: false`, recovery 1,5 · `windup_heavy`; `SKY_TO_TARGET / falling_squares / burst`.
- Status: DESIGNED. Lưu ý: pha 1 hiện cast 6 lá (`boss_cards`) — bản pattern thay bằng 4 skill; sim Story 035 từng đo win-rate rất nhạy với trận này → **bắt buộc chạy lại sim** trước khi đổi.

### 4.9 Rừng Sương `ch1` — đã có skill (EXISTS), chỉ ghi bổ sung cho bầy

11 quái giữ nguyên skill trong `enemy_skills.json` (bảng §3.1). Bổ sung **không tạo skill mới**, chỉ thêm trọng số điều kiện khi multi-enemy có:

| Quái | Bổ sung Bậc A (chỉ data) | Lý do |
|---|---|---|
| goblin_archer | `aimed_shot` weight ×1,8 khi `player_status: root` | Rootling trói → cung thủ bắn hàng: combo "trói rồi bắn" đã có đủ nguyên liệu |
| dire_wolf | `chase_bite` weight ×1,5 khi `player_status: slow` | sói đuổi mồi chậm |
| greycap_sporeling | `seedbed` không dùng nếu nửa người chơi đã ≥ 2 ô gai | ngân sách zone |
| mossbound_sentry | `brace` weight ×1,5 khi `allies_alive >= 1` | guard theo phe che cả bầy |
| goblin_scout | `scout_hop` weight ×1,5 khi `allies_alive >= 1` | trinh sát né để đồng đội đánh |

5 match mồ côi (`wolf`, `goblin_chief`, `goblin_warrior`, `goblin_shaman`, `goblin_brute`): **không thiết kế** (không pool, không sheet, không ra trận) — danh sách review §13.


---

## 5. Nhóm skill và effect tái sử dụng

### 5.1 Phân loại (tham khảo) và skill thuộc nhóm

| Nhóm | Effect nền (code) | Skill dùng (ví dụ) | Khác nhau ở đâu |
|---|---|---|---|
| Attack đơn | `damage`, anchor `on_player` 1 ô | shared_jab, imp_ash_dart, scorpion_venom_sting, lord_brand… | status kèm theo (Rạn / Độc / Giá Lạnh / pin), tốc độ (0,9–1,0 s), impact |
| Attack vùng | anchor `near_player`/`row_of_player`/`column_of_player` + offsets | golem_cinder_slam (2×2), knight_cleave (hàng), scarab_spear (cột), nomad_ambush (T), cultist_curse_ring (vòng rỗng) | hình, điều kiện kích hoạt (đứng yên, trạng thái), có followup hay không |
| Hai nhịp | `followup` (same_cells / first_shift / player) | lord_eruption_call, frog_leap_slam (cùng ô, delay 1,0), sphinx_sandfall / ogre_quake / mist_lord_whiteout / dragon_tempest / keeper_heart_flare (lệch hàng), jackal_pack_nip (đuổi) | "quay lại là chết" vs "làn sọc chờ" vs "đuổi" |
| DoT ô | `zone:burn` (`ignite`) | cultist_kindle, slug_lava_spit/molten_trail, eater_ember_belch, lord_cinder_lane, phoenix_pyre | ô kề / dọc cột / theo làn / chỉ khi yếu |
| DoT bám người | `status:poison` (**mới**) | rat_gnaw (4 tổng), scorpion_venom_sting (9), witch_rot_cloud (9), spore_puff (6), matriarch_toxic_croak (12) | liều, hình; **không chồng**, chỉ làm mới |
| Kiểm soát ô | `zone:mire`, `zone:sand`, `zone:fall`, `zone:thorns`, `zone:drop` | slug_slime_trail, beetle_sand_spray, sentinel_stone_gale, rime_caltrops, burrower_sinkhole | loại địa hình = vùng; drop chỉ cho Elite/Boss |
| Defense | `guard` (theo phe) | golem_ash_mantle (3/4 s), scarab_shield_wall (4/4), sentry_rime_bulwark (5/4), knight_bulwark (5/4 once), *_ice_ward/vapor_form (while_markers) | số, điều kiện (đồng đội / máu), có mốc để phá hay không |
| Buff | `haste` | frog_croak (0,75/6), ogre_roar, cultist_dark_rite (+guard) | kích hoạt: tự do / on_enter / đồng đội chết |
| Debuff | `fragile`, `slow`, `frost` | marker: imp, sphinx_gaze, bat_swarm; slow: lizard_tail_sweep, archer_blinding_arc; frost: frost_kiss, cold_snap (2) | nguồn → bên "ăn" debuff là quái khác (§7) |
| Control | `root`, `pin` (cổng F4), `push`/`pull` (**mới**) | zombie_grab, burrower_undertow (root); skeleton_shield_bash, ogre_grab, glacier_fist (pin); harpy_dive, monk_gale_palm, guard_shove, dragon_tail_sweep (push); toad_tongue, jailer_chain_hook (pull) | thời lượng ngắn (0,5–0,8); push/pull ICD |
| Support | `heal` (**mới**), `consume_burn` (**mới**) | spore_regrow, matriarch_regrow, eater_devour | có cửa sổ ngắt (windup 1,2–1,4, `interrupt_stun_sec`) |
| Summon | — | **không có** | ngoài phạm vi (không đơn vị thứ hai) |
| Conditional | `hp_below`/`once`/`requires_anchor`/`player_still_sec` (có); `player_status`, `player_on_zone`, `ally_*`, `player_steps_since`, `burning_cells` (**mới**) | knight_bulwark, phoenix_pyre (máu); lizard_drag_bite, hound_mire_chase (trạng thái); cultist_dark_rite (đồng đội); reacter_lash (bước) | — |
| Mobility | `move` (adjacent_row; `far_cell` **mới**), `evade` (**mới**) | shared_sidestep và các bản riêng; nomad_veil_step, ghost_phase, gale_bird_updraft | có evade hay không; `counts_as_cast: false` |
| Marker | `marker` + `row_of_anchor` | sprite_mirage/shimmer_lash, wisp_lantern/flare, crystal_anchor + ice_mantle, vapor_form | mốc nuôi đòn (hàng) hay nuôi giáp |

**Luật chống trùng:** hai skill cùng effect nền phải khác ≥ 2 trong 4 trục {hình/anchor, điều kiện kích hoạt, status kèm, nhịp
(followup/delay)}. Ví dụ bốn "chó lao hàng": `chase_bite` (rừng: SKY 1 ô ×2 nhịp), `hound_ember_charge` (2 ô, thưởng Rạn),
`hound_mire_chase` (3 ô, thưởng slow), `snow_wolf_hunt` (2 ô, slow + thưởng Giá Lạnh), `eagle_talon_rake` (3 ô, nhịp nhanh, không thưởng).

### 5.2 Mở key mới trong `EnemySkillsConfig` nhưng **tái dùng code sẵn có** (việc nhỏ, 1 PR)

| Key mới | Gọi tới (đã có) | Ghi chú |
|---|---|---|
| `effects.zone.id: burn {sec, tick_sec, dmg, side?}` | `StatusEffects.ignite(cells, sec, tick, dmg)` | cùng luật chồng 3 tầng của row_burner; `side: self` cho vệt sên |
| `effects.zone.id: mire {sec}` | `TileHazards.add_mire(side, cells, sec)` | luật chừa đường của hazards |
| `effects.zone.id: sand {sec}` | `TileHazards.add_sand` | như sandstorm |
| `effects.zone.id: fall {warn, fall}` | `TileHazards.drop_cells(side, cells, fall_sec, warn_sec)` | không ô cầu/đảo cuối (sẵn) |
| `effects.status.id: pin` / `frost` | đã hỗ trợ; chỉ cần sửa G2 và dùng | — |
| `effects.heal {ratio|amount, sec}` | `CombatState.heal_enemy` | tick trong `PatternController`; hủy khi bị ngắt |
| `effects.consume_burn {heal_per_cell}` | `StatusEffects.burning_cells` + `clear_burn` + `heal_enemy` | — |
| `effects.push {cells, dir: away}` / `effects.pull {cells}` | `CutEffects.push_away` / `pull_toward` với target PLAYER | phải xác nhận hàm nhận `Side.PLAYER` (block boss đã đẩy người chơi qua lá → có đường) |
| `effects.evade {sec}` | cờ trong `PatternController`, OR vào `SwingArbiter.enemy_untargetable_fn` (hiện TraitHost sở hữu) | — |
| `effects.shroud {sec}` | OR vào `TraitHost.hit_forecast_blocked` | — |
| `move.to: far_cell` | `_move_targets` mở rộng (ô trống xa nhất nửa địch, không marker/hố) | — |
| `conditions.player_status: [ids]`, `player_on_zone: [mire|thorns|burn|sand]`, `player_steps_since`, `burning_cells` | `StatusEffects` getters, `TileHazards`, `on_player_stepped` | thêm vào `_conditions_ok` **và** `weight_mults_by_condition` trong `PatternBrain` (trọng số thay vì cấm) |
| `phases[].traits` | `TraitHost.add_trait / teardown` (có) | G5 |
| `phases[].brain_set`, `phases[].pattern_tempo_mult` | `BossBrain.use_set`, tempo của controller | thay `phase_shift` |
| `conditions.ally_died_within_sec`, `allies_alive`, `ally_hp_below` | **chờ multi-enemy** (cần id đơn vị) | Bậc B |

### 5.3 Effect cần phát triển mới (không có code nền)

1. **Poison (Độc)** — trạng thái bám **người chơi** (phe), `{sec, tick_sec, dmg}`; không chồng, làm mới; tick qua `StatusEffects.tick` →
   `damage_player`; HUD chip mới `keyword.poison`; VFX status pack `poison_hero`. Miễn nhiễm: không. Khác burn (ô) và mire (ô): theo người.
2. **VFX cho skill quái (G4)** — `CombatView` nghe `PatternController.warning_started/skill_resolved` → `CastVfx` với delivery của skill
   (travel từ ô cast origin `enemy_cast_origin` tới ô đích; impact theo `impact_packs`). Dùng được ngay 19 impact form + packs hiện có; chỉ
   cần pack riêng cho `poison`, `curse`, `seal` (đang rỗng trong `impact_packs`).
3. **Pause hook cho PatternController (G6)** — `set_active(false)` tương đương BossController, gọi từ burrow/rebirth.
4. **Ngân sách bầy** (§9) — `external_red_fn` gộp cảnh báo của mọi quái; `_since_warning` cấp trận; ICD push theo phe.
5. **Summon** — không làm trong chương trình này.

### 5.4 Trait chuyển đổi khi quái sang pattern brain

| Trait | Thay bằng | Ở quái |
|---|---|---|
| seal_caster | skill `zone: drop` (`*_sink`, `jailer_lockdown`, `keeper_lattice_seal`) | toad_matriarch, jailer, an_dai_keeper |
| thorn_field | skill `zone: thorns` (`frost_mage_rime_field`) | frost_mage |
| step_reactor | điều kiện `player_steps_since` (`reacter_lash`) | reacter |
| phase_shift | `phases[]` + `phases[].traits/brain_set/tempo` | inferno_lord, mist_lord |
| boss_phases (`phases` match key) | `phases[]` của pattern enemy | an_dai_keeper |
| 17 trait còn lại | giữ nguyên | — |

---

## 6. Bản sắc vùng

| Vùng | Cơ chế chủ đạo (code) | Cơ chế phụ | Trait vùng | Quái **không** phải bản sao nhau vì |
|---|---|---|---|---|
| Rừng Sương | rễ/trói, mốc, gai (EXISTS) | guard, haste | — | đã kiểm trong P2.3 (5 nguyên mẫu + 6 kẻ cũ) |
| Hỏa Ngục | Rạn ("Dấu Tro") → đòn thưởng; `zone:burn` | guard phe; mạch phun | row_burner, vent_surge, burn_eater, rebirth | marker (Imp) / ăn dấu (Hound) / che (Golem) / cắt đường (Cultist) / vết (Slug) / nặng (Knight) / hút lửa (Eater) / giàn thiêu (Phoenix) / làn + gọi lại (Lord) |
| Sa Mạc | `zone:sand`, mốc ảo ảnh, phục kích đứng yên, evade | poison (1 nguồn), root | burrow, riposte, sandstorm, row_burner | bầy (Jackal) / lấp (Beetle) / phục kích + tan (Nomad) / bóng (Sprite) / tường (Scarab) / chữ thập slow (Archer) / cột trói + sụp (Burrower) / độc + ghim (Scorpion) / chôn + cát đổ (Sphinx) |
| Đầm Lầy | poison nhiều nguồn, `zone:mire`, slow, heal | pull, drop | rotten_thrower, spore_burst, hop_skip, bog_spread, row_burner | độc nhẹ (Rat) / lầy (Slug) / ăn chậm (Lizard) / kéo (Toad) / độc L (Witch) / đuổi chậm (Hound) / độc thập + mọc lại (Cap) / đè + kêu (Frog) / lầy + sụp + kêu độc (Matriarch) |
| Hầm Ngục | Rạn + slow ("nguyền"), root/pin, drop | push/pull, nghi lễ | rotten_thrower, row_burner, slam, step_reactor | ghim (Skeleton) / trói (Zombie) / rải (Bat) / bọc + nhớt (Slime) / cột + tan (Ghost) / phạt bước (Reacter) / vòng + nghi lễ (Cultist) / đẩy (Rat Guard) / móc + khóa (Jailer) / chùy + rung (Ogre) |
| Tháp Sương | frost tích tầng, pin ngắn, slow | guard băng (mốc), thorns băng | fuse_cannon, frost_aura, row_burner | chạm (Sprite) / đèn (Wisp) / tường (Sentry) / săn lạnh (Wolf) / mảnh + ngòi (Fuse) / tên + chông (Archer) / đấm ghim (Golem) / cột lạnh (Ghost) / 2 tầng + tinh thể (Mage) / mốc + trắng xóa (Lord) |
| Không Đảo | push, `zone:fall`, mobility (far_cell, evade), shroud | pin (sét) | gust, island_drop, shroud, row_burner | che (Sprite) / nhào + hất (Harpy) / cột + bước gió (Monk) / cào + lượn (Eagle) / rơi ô (Sentinel) / sét ghim (Shaman) / đè + bay (Gale) / tia + mây (Veil) / quét + bão (Dragon) |
| Tâm Lưới | drop (có thể ô đang đứng), Rạn, row_burner pha 2 | — | row_burner (p2) | trận một boss |

Lệch chủ đề cần người dùng biết (không đổi): `row_burner` trên ice_golem / bog_hound / thunder_shaman / sun_archer là trait mặc định
của node `danger` (`defaults.danger_traits`), nên "lửa" xuất hiện ở mọi vùng. Thiết kế này đọc nó là "hàng sét / hàng băng" trong
strings nếu muốn (chỉ đổi text), hoặc đổi `danger_traits` theo vùng sau (ngoài phạm vi).

---

## 7. Phối hợp nhiều quái (multi-enemy)

### 7.0 Điều kiện tiên quyết và hai bậc

Engine hiện **không** có nhiều quái (audit §1, `CombatState` một `enemy_hp`; `03-encounter-system.md` §1 đã quyết "composition,
not multi-enemy" cho World Map v2). Session anh em đang audit cách mở. Thiết kế dưới đây tự giới hạn:

- **Bậc A (chạy được ngay khi có nhiều đơn vị, không cần giao tiếp quái–quái):** combo qua **trạng thái chung** — status trên
  người chơi (Rạn, slow, root, poison, frost là theo **phe người chơi**), ô trên sân (lầy, cháy, gai, cát), **guard theo phe địch**
  (`StatusEffects.guard(ENEMY)` áp lên mọi quái — đây là "che đồng đội" miễn phí), và điều kiện `player_status` / `player_on_zone`.
- **Bậc B (cần id đơn vị trong signal/state):** `ally_died_within_sec`, `allies_alive`, `ally_hp_below`; heal/guard nhắm một đồng đội;
  HUD nhiều thanh máu; F2/F5 gộp cảnh báo của mọi quái; `_tick_end` khi **tất cả** chết; cut của người chơi chọn mục tiêu theo ô.

Luật chung cho mọi đội hình: **tối đa 1 skill `interruptible: false` đang chạy** trong trận; **F2 chung** (tổng ô đỏ của mọi quái + trait
≤ 50 %); **F5 chung** (khoảng cách cảnh báo tính toàn trận); **F4 chung** (đã theo phe: hai quái không chồng root/pin trong 1 s);
đội hình 2–3 Normal, hoặc 1 Elite + 1 Normal; Boss không có add trong chương trình này.

### 7.1 Hỏa Ngục — "Dấu Tro": `imp` + `ember_hound` (+ `ash_golem`)

- **Vai chính:** Ember Hound (sát thương). Imp là nguồn Rạn, Golem là lá chắn.
- **Combo:** Imp `ash_dart` trúng → Rạn 1 → Hound `ember_charge` weight ×2, đòn 10 → 15 (cần G1). Golem `ash_mantle` → cả ba +3 giáp 4 s →
  đòn 1–2 ô của người chơi trượt giáp; ép dùng Xuyên giáp hoặc đòn to (đòn to → ô đỏ ít, dễ trúng Imp).
- **Tần suất:** dart hồi 2,6 s; tỉ lệ trúng người chơi khá ~30–40 % (ô đơn) → ~1 Rạn / 7 s; charge hồi 3 → combo ~mỗi 7–9 s. Mantle 8 s/lần.
- **Phản đòn:** né dart là cắt combo tận gốc (đòn dễ né nhất trận); giết Imp trước (92 HP, thấp nhất); Xuyên giáp qua Mantle.
- **Mất một con:** Imp chết → Hound thành chó lao 10 dmg thường; Golem chết → không giáp; Hound chết → Imp + Golem là trận chậm, an toàn. Đội hình **xuống cấp mềm**.

### 7.2 Hỏa Ngục Peril — "Lò": `flame_cultist` + `magma_slug`

- **Vai chính:** Cultist (row_burner + kindle) chia sân bằng lửa; Slug đóng ô.
- **Combo:** hàng lửa (trait) + 2 ô cháy (kindle) + ô nhổ (spit) → đường thoát F1 không được xuyên ô cháy → **AI tự thu hẹp plan của chính nó**
  (plan không công bằng bị bỏ). Rủi ro không phải "quá mạnh" mà "**chết đói**": quá nhiều ô cháy → mọi skill bị abort → trận trống rỗng.
- **Ngân sách zone (§9.3):** tổng ô cháy do skill ≤ 3 trên nửa người chơi; kindle/spit kiểm tra trước khi chọn.
- **Phản đòn:** đứng ở ô đã cháy xong (an toàn 2–3 s), giết Cultist trước (kindle là nguồn chính).
- **Mất một con:** còn Slug = trận chậm; còn Cultist = như trận danger hiện tại.

### 7.3 Sa Mạc — "Cồn cát": `dust_nomad` + `mirage_sprite` + `sand_beetle`

- **Vai chính:** Nomad. Sprite buộc người chơi rời hàng bóng (di chuyển), Beetle lấp ô (ít chỗ) → người chơi **phải** đứng yên ở đâu đó → Nomad `ambush` (điều kiện đứng yên 1,2 s).
- **Tần suất:** ambush chỉ khi đứng yên; người chơi giỏi gần như không cho cơ hội → combo hiếm (< 1/trận), nhưng **đe dọa** liên tục. Đúng ý "không combo không thể phản ứng".
- **Phản đòn:** phá bóng (1 ô) để Sprite câm; cát 3 s thì chờ; bước nhỏ đều đặn.
- **Mất một con:** Nomad chết → trận "điều hướng"; Sprite chết → Nomad vẫn phục kích nhưng không bị ép rời hàng.

### 7.4 Đầm Lầy — "Bùn": `reed_witch` + `mire_slug` + `marsh_toad`

- **Vai chính:** Toad (kéo). Slug tạo lầy, Toad kéo người chơi 1 ô về vạch chia **vào** ô lầy (pull bị chặn bởi lầy? không — lầy bước được, chỉ chậm; chặn = R3 chỉ khi hố/gai/biên).
  Witch rải Độc lên người đã chậm (Rot Cloud L, trúng dễ hơn khi bước ×1,6).
- **Tần suất:** trail 5 s, tongue 4,5 s → ~1 lần kéo-vào-lầy / 10 s; Độc 9 tổng.
- **Phản đòn:** không đứng ngay trước ô lầy (cột Toad là 2 ô dọc, dễ bước ngang); ra khỏi lầy trước khi Witch windup (0,5 s + 1,1 warning: đủ 1 bước chậm 0,88 s).
- **Mất một con:** Slug chết → không lầy mới (lầy sân vẫn có); Toad chết → không kéo; Witch chết → không Độc. Đội hình **tuyến tính**, mỗi con một mắt xích, mất mắt nào cũng còn chơi được.

### 7.5 Hầm Ngục — "Nghi lễ": `cultist` + `zombie` + `skeleton`

- **Vai chính:** Cultist. Zombie trói 0,8 s → Curse Ring (4 ô kề, 1,3 s) vô nghĩa với người **đang trói**… nên combo thật là ngược: Curse Ring ép **đứng yên** → Zombie `grab` ô đơn trên ô đang đứng (ngược luật thường).
  Khi một con ngã → `dark_rite` (guard 4 + haste 0,7 trong 5 s) cho hai con còn lại (Bậc B).
- **Tần suất:** ring 4,5 s, grab 3 s; "đứng yên vs bước" là lưỡng nan mỗi ~5 s; dark_rite 1 lần/trận.
- **Phản đòn:** giết Cultist **trước** (không có rite) — nhưng Cultist HP 150 cao nhất; hoặc giết Skeleton cuối cùng để rite chỉ buff 1 con; ngắt rite (windup 1,0, stun 1,0).
- **Mất một con:** chính là cơ chế; còn một con = trận thường.

### 7.6 Tháp Sương — "Băng tan": `wisp` + `snow_wolf` (+ `frost_sprite` nếu tier cho)

- **Vai chính:** Wolf. Wisp lóe +1 Giá Lạnh từ hàng đèn → Wolf `hunt` ×1,8 + slow → người chậm dễ ăn lóe tiếp → 3 tầng = nổ 24 (bỏ giáp).
- **Ngân sách frost (§9.2):** trong bầy chỉ **một** nguồn Giá Lạnh (Wisp); Sprite thêm vào chỉ khi Wisp vắng. Nổ tối đa 1 lần / 10 s (ICD phe người chơi — cần thêm vào `apply_frost` cho PLAYER).
- **Phản đòn:** phá đèn (1 ô); đổi hàng khi Wolf windup; tầng Giá Lạnh hiện trên chip HUD (cần chip phía người chơi — HUD hiện chỉ vẽ chip cho ENEMY, §10).
- **Mất một con:** Wisp chết → Wolf 10 dmg + slow thường; Wolf chết → Wisp cần 3 lóe trúng, ~hiếm.

### 7.7 Không Đảo — "Gió và mép": `harpy` + `wind_monk` + `sky_sentinel`

- **Vai chính:** Sentinel (rơi ô). Monk/Harpy đẩy 1 ô; Sentinel làm rơi ô cạnh người chơi → đẩy bị chặn bởi ô đang rơi = **R3 Va Đập** (8 + pin 0,6). Nguy hiểm nhất tài liệu.
- **Luật cứng:** push **không bao giờ** đẩy vào ô đang cảnh báo rơi/hố/cát (luật gust sẵn có, áp cho `effects.push`); ICD push 2 s theo phe; R3 vẫn có thể xảy ra khi đẩy vào biên/đảo khác → chấp nhận nhưng tính vào CC budget (pin 0,6 qua F4).
- **Tần suất:** dive 3,2 s, palm 4 s, gale 7 s → "đẩy + mép" ~1 / 8 s; Va Đập thực tế thấp nếu người chơi đứng hàng trước.
- **Phản đòn:** đứng hàng trước (gần vạch chia) — ngược trực giác "lùi là an toàn", đúng chủ đề vùng; giết Sentinel (144 HP, giáp 3) hoặc Harpy (104) trước.
- **Mất một con:** Sentinel chết → đẩy chỉ còn đổi ô (trên crumble còn **có lợi** cho người chơi: reset đồng hồ nứt); Harpy/Monk chết → Sentinel chỉ rơi ô, chậm.

### 7.8 Elite + 1 Normal (mẫu cho lane Elite)

`fire_eater` + `flame_cultist`: Cultist thắp → Eater nuốt (hồi 6/ô). Giết Cultist trước là lời giải; Eater một mình phải tự thắp (belch) rồi nuốt — chậm hơn nhiều.
`spore_cap` + `mire_slug`: lầy từ cả trait (mỗi đòn trúng Cap) và skill → ngân sách mire ≤ 4 ô. `frost_mage` + `stone_sentry`: guard 5 + cold snap: giết Sentry trước hoặc Xuyên giáp.

---

## 8. Phản đòn (counterplay)

Nguyên tắc từ code: **mọi đòn pattern đều qua F1** (người chơi đứng yên không bị khóa luôn kịp 1 bước), nên "không thể phản ứng" chỉ
xảy ra khi **chồng CC** hoặc **chồng ô đỏ** — hai thứ F4/F2 đã chặn ở mức một quái, và §9 chặn ở mức bầy.

| Loại skill | Cách thoát đúng | Lỗi người chơi thường gặp | Dấu hiệu đọc được (tell) |
|---|---|---|---|
| 1 ô `on_player` | 1 bước bất kỳ | đứng yên đặt khối | ô đỏ đơn 0,9–1,0 s |
| thanh / hàng / cột | bước **vuông góc** | bước dọc theo thanh | thanh đỏ, hướng |
| 2×2 / L / T | ra phía hở | ra góc | khối đỏ, F1 chừa cạnh |
| hai nhịp cùng ô | **không quay lại** 1 s | quay lại ô cũ | ô đỏ thứ hai mờ hơn |
| hai nhịp lệch hàng | ra phía **không** có làn sọc | ra phía làn sọc | làn sọc (show_with_first) |
| zone (cháy/lầy/cát/gai/rơi) | nhớ ô 2–4 s, F3 luôn chừa lối | bước vào ô vừa đỏ | ô đổi màu sau đỏ |
| marker (bóng/đèn/tinh thể) | đánh 1–2 ô lên mốc | bỏ mặc mốc | ô tối dưới đỏ trên nửa địch |
| guard theo phe | Xuyên giáp / đợi hết / ngắt windup | đòn 1 ô liên tục | clip `guard`/`brace`, chip giáp |
| haste / heal / rite | **ngắt** (windup 1,0–1,4 s, stun 0,8–1,0) | để nó kêu xong | clip `howl`, khung nhấp nháy (interrupt_tell) |
| evade / far_cell | ghim khối trước windup, hoặc đợi | ném đòn vào chỗ trống | clip `step` + khung ngà đích |
| push / pull | đứng hàng trước / không đứng trước ô xấu | lùi sát mép | impact `knockback` |
| poison | né nguồn; không chồng nên 2 nguồn ≠ 2× | hoảng vì tick | chip Độc trên người |
| frost (Giá Lạnh) | không để trúng lần 3 | ăn hai nhịp Whiteout | chip tầng |
| không ngắt được | chỉ né | cố ngắt | khung ngà liền |

Mỗi skill DESIGNED cần hai dòng strings `enemy_skill.<id>.name` / `.counter` (tiền lệ rừng: 34 skill × 2 dòng, `strings.csv` 869–934) —
viết khi implement, không viết ở đây để tránh trôi khỏi số cuối.

---

## 9. Nguyên tắc cân bằng

### 9.1 Ngân sách theo tier (giá trị khởi điểm, không đổi stats bây giờ)

| | Normal | Elite | Boss | Final |
|---|---|---|---|---|
| Skill riêng | 1 (+1 shared), tối đa 2 | 2 (+1 trait) | 3–4 / pha, 2 pha | 4–5, 2 pha |
| Cơ chế phải nhớ | 1 | 2 (skill + trait) | 1 cơ chế lớn + 1 nhịp hai | 2 |
| Damage/đòn | 6–14 | 10–16 | 12–22 | 10–16 (+ Rạn) |
| Warning | 0,9–1,3 | 1,0–1,2 | 0,9–1,6 | 0,9–1,5 |
| Cooldown | 2,4–6 | 3–12 | 2,8–9 | 2,8–9 |
| Skill không ngắt được | 0–1 (chỉ 2×2/hàng nặng) | 0–1 | 1–2 | 1–2 |
| Trait | 0–1 | 1 (Jailer 2 — xem §4.5) | 1–2 | 1 (p2) |

**Sát thương kỳ vọng vs người chơi né hoàn hảo = 0** (bất biến P2.3, test `pattern_roster_dodge_test`). Vs người chơi trung bình:
Normal ≤ 20 % máu hero (200) mỗi trận, Elite ≤ 35 %, Boss ≤ 60 % — số từ bot playtest mục tiêu "Đòn boss trúng mỗi chuyến 15–30"
(`design/game-mechanics.md` §7). Pha chuyển bất tử 1,0–1,5 s.

### 9.2 Ngân sách khống chế, đẩy, Giá Lạnh (mức trận, không mức quái)

- **CC:** F4 `cc_grace 1,0 s` theo phe người chơi (sẵn): sau khi hết root/pin, 1 s không ai được root/pin. Root ≤ 0,8, pin ≤ 0,6 (Normal 0,5).
  Không có skill vừa root vừa pin. Tổng thời gian bị khóa bước mục tiêu ≤ 10 % thời lượng trận.
- **Push/pull:** ICD 2 s theo phe; không đẩy vào ô cảnh báo/hố/cát/rơi; R3 Va Đập (8 + pin 0,6) chỉ khi chặn bởi biên/đơn vị → tính như pin (F4).
- **Giá Lạnh lên người chơi:** nổ 24 bỏ giáp = 12 % máu → ICD nổ 10 s theo phe (thêm vào `apply_frost(PLAYER)` khi sửa G2); 1 nguồn ≥ 2 tầng/đòn mỗi trận (Cold Snap).
- **Poison:** không chồng, làm mới; liều tối đa 12 (Matriarch); tổng tick/s ≤ 3.
- **Guard phe:** tối đa 6, không cộng dồn (giữ giá trị lớn hơn — hành vi sẵn có `guard()`); hai nguồn guard cùng bầy → chỉ cao nhất.

### 9.3 Ngân sách ô (zone) trên nửa người chơi

Ô đỏ ≤ 50 % (F2, gộp mọi quái). Ô cháy do skill ≤ 3; lầy do skill ≤ 4; cát ≤ 2 (+ sân); gai ≤ 3; hố ≤ 2 (+ luật Ô rớt); rơi ≤ 1 (+ island_drop).
Skill zone kiểm tra ngân sách trong `conditions` (key `zone_budget_ok` — gộp vào §5.2) để AI **không bị đói** (xem 7.2) thay vì bị abort.

### 9.4 Bầy nhiều quái

- HP bầy = ngân sách HP một quái cùng tier chia đều (nguyên tắc "pack budget" D8 trong schema P2.3), **không** cộng dồn — bản chất của
  bầy là nhiều nhịp đe dọa hơn, không nhiều máu hơn.
- Tempo: mỗi quái trong bầy n con nhận `pattern_tempo_mult × (1 + 0,3·(n−1))` (windup/cooldown/recovery chậm hơn, warning không đổi) để tổng
  nhịp cảnh báo của bầy ≈ 1,3–1,5× một con, không phải n×.
- Tối đa 1 skill không ngắt được đang chạy; F5 gap chung; chỉ 1 nguồn Giá Lạnh; chỉ 1 nguồn drop.
- Quái chết **không** buff quái khác trừ Cultist (Bậc B, có ngắt).

### 9.5 Không làm ở giai đoạn này

Không đổi `boss_max_hp`, giáp, `boss_min_runes`, trait, pool. Ghi nhận: khi chuyển block → pattern, HP cần tune lại (tiền lệ rừng:
190–250 cho Normal pattern so với 88–160 Normal block, vì pattern enemy không "nhặt khối" và trận ngắn hơn) — việc của bước sim.

---

## 10. Yêu cầu animation / VFX

**Clip (unit sheet, đã có pipeline 5 clip cơ bản cho 6 vùng — session anh em "region enemy visual assets"):** idle, step, windup, hit,
down là đủ cho **mọi Normal** trong tài liệu (fallback: `windup_heavy`→windup, `guard`→brace→windup, `howl`→windup, `stunned`→idle,
`phase_shift`→idle). Clip thêm **đáng gen** (ưu tiên): Elite/Boss `windup_heavy` (mọi skill không ngắt được), `howl` (Eater devour,
Frog croak, Ogre roar, Cultist rite, Regrow ×2), `guard` (Golem, Scarab, Sentry, Knight, Mage, Veil), `stunned` (mọi quái có
`interrupt_stun_sec`: 9 con), `phase_shift` (7 boss). Block brain hiện **không** phát 6 clip đặc biệt → chuyển sang pattern brain là điều
kiện để các clip này có ý nghĩa.

**VFX (G4 phải xong trước):** mỗi skill đã khai `delivery {type, travel, impact}` theo `SkillDelivery`; packs cần có: `travel` square_streak /
falling_squares / floor_run / chain_spark (floor_run đã có `miss_dust`), `impact` slash / burst / shatter / burn (có `impact_flame_burn`) /
freeze / poison (**mới**) / knockback / guard / seal / thorns (có `thorn_spikes`) / curse (**mới**). Status pack phía hero: `burn_hero`, `chill_hero`,
`frozen_hero` có; cần `poison_hero`, `fragile_hero` (Rạn trên người chơi chưa có chip/VFX), `slow_hero`, `root_hero` (root_seal ở floor có thể dùng).
Floor: `burning_cell`, `cracked_cell`, `thorn_spikes`, `root_seal` dùng lại; cần `mire_cell` (nếu chưa), `sand_cell`, `fall_warn`, marker
`mirage` / `lantern` / `crystal` / `cloud` (4 hình mốc mới, vẽ tối dưới đỏ như anchor/wreath).

**HUD:** chip trạng thái **phía người chơi** (hiện `_draw_pins` chỉ ENEMY): Rạn, Giá Lạnh, Độc, slow, root; thanh máu nhiều quái (Bậc B);
banner pha nghe `PatternController.phase_started` (G5).

**Mọi thứ trên là hướng dẫn kích cỡ theo ô, màu sáng, đọc được từ xa** (quy ước VFX của dự án); không gen trong tài liệu này.

---

## 11. Lộ trình implement (đề xuất, theo vùng, mỗi bước có thể dừng)

| Bước | Nội dung | Code | Kiểm chứng |
|---|---|---|---|
| **0. Nền** — **ĐÃ IMPLEMENT 2026-11-13 (Phụ lục B)** | sửa G1 (Rạn người chơi trong pattern damage), G2 (frost nổ), G6 (pause hook; shroud đọc stage), G5 (`phases[].traits/brain_set/tempo`); mở key §5.2 (zone burn/mire/sand/fall, heal, consume_burn, push/pull, evade, shroud, far_cell, điều kiện người chơi/ô/bước, zone_budget); G4 VFX hook; status `poison` + chip hero | `enemy_skills_config.gd`, `pattern_controller.gd`, `pattern_brain.gd`, `status_effects.gd`, `combat_view.gd`, `cut_hud_view.gd`, `trait_host.gd` | unit test từng key (fixture `dev_pattern_dummy`), `pattern_roster_fairness_test` mở rộng, 1 clip windowed `--pattern=dev_pattern_dummy` |
| **1. Hỏa Ngục** (9) — nhóm A (imp, ember_hound, ash_golem) **ĐÃ IMPLEMENT 2026-11-13**, test pass, ảnh `production/qa/evidence/monster-skill-hellfire/group-a/` | `enemy_skills.json` + `chapters.json` `brain: pattern` 9 match, strings 17×2, Inferno Lord phases thay phase_shift; Heat warden_hook giữ | data + strings | sim deck_sim 7 tầng so baseline B1 (`production/qa/evidence/world-map-v2/b1-balance`), dodge test = 0 dmg, capture mỗi quái |
| **2. Đầm Lầy + Sa Mạc** (18) | poison dùng ở 2 vùng; Matriarch/Burrower drop; Sphinx phases | data + strings | như trên; kiểm riposte/burrow/spore_burst trên pattern |
| **3. Hầm Ngục + Tháp Sương** (20) | reacter → điều kiện bước; frost chain; Jailer 4 cơ chế (quyết giữ/bỏ row_burner) | data + strings | ICD nổ Giá Lạnh; sim |
| **4. Không Đảo + Tâm Lưới** (10) | push/pull + crumble tương tác; Keeper phases (sim Story 035 chạy lại) | data + strings | sim fate endings |
| **5. Bầy (Bậc A)** | khi multi-enemy có đơn vị: trọng số điều kiện người chơi, F2/F5 chung, ICD push, tempo bầy | theo audit session anh em | formation test 7.1–7.7 |
| **6. Bầy (Bậc B)** | `ally_*`, HUD nhiều plate, rite/heal nhắm đồng đội | — | — |

Mỗi bước: **chỉ data + strings** sau bước 0 (trừ bước 5–6). Có thể dừng sau bất kỳ bước nào mà game vẫn nhất quán (vùng chưa chuyển vẫn
chạy block brain như hôm nay). Thứ tự chọn theo: Hỏa Ngục là slice đã có baseline cân bằng và rule Heat; Đầm Lầy/Sa Mạc chia poison;
Hầm/Tháp cần sửa frost; Không Đảo cần push (rủi ro R3 cao nhất); Tâm Lưới cuối vì sim nhạy nhất.

---

## 12. Bảng tổng hợp

Status: **EXISTS** = có trong `enemy_skills.json`; **DESIGNED** = mới trong tài liệu; **ORPHAN** = không pool, đưa vào review. Số skill
= skill riêng (không đếm `shared_*`; `ghost_phase` đếm cho ghost).

| Vùng | Monster ID | Loại | Số skill | Tên skill | Status |
|---|---|---|---|---|---|
| ch1 | goblin_scout | Normal | 2 | Probing Stab, Hop Aside | EXISTS |
| ch1 | rootling | Normal | 2 | Root Prick, Creep | EXISTS |
| ch1 | mossbound_sentry | Normal | 2 | Slab Tap, Brace | EXISTS |
| ch1 | greycap_sporeling | Normal | 2 | Spore Squares, Seedbed | EXISTS |
| ch1 | goblin_archer | Normal | 2 | Aimed Shot, Diagonal Volley | EXISTS |
| ch1 | dire_wolf | Normal | 2 | Chase Bite, Prowl | EXISTS |
| ch1 | wolf_alpha | Elite | 3 | Alpha Howl, Rending Rush, Hunting Bite | EXISTS |
| ch1 | ancient_root_sentinel | Elite | 3 | Root Anchor, Branch Net, Bark Shift | EXISTS |
| ch1 | mistbriar_matron | Elite | 2 | Thorn Fork, Wreath Guard | EXISTS |
| ch1 | goblin_warlock | Boss | 5 | Hex Bolt, Stolen Shape, Curse Lane, Blink, Twin Shapes | EXISTS |
| ch1 | forest_witch | Boss | 9 | Root Nail, Branch Lattice, Entangled Row, Moss Guard, Root Shift, Root Anchor, Withered Crown, Forest's Last Knot (+Root Anchor) | EXISTS |
| ch1 | wolf | — | 0 | — | ORPHAN |
| ch1 | goblin_chief | — | 0 | — (trait row_burner) | ORPHAN |
| ch1 | goblin_warrior | — | 0 | — | ORPHAN |
| ch1 | goblin_shaman | — | 0 | — | ORPHAN |
| ch1 | goblin_brute | — | 0 | — | ORPHAN |
| hellfire | imp | Normal | 1 | Ash Dart (+Sidestep) | IMPLEMENTED |
| hellfire | ember_hound | Normal | 1 | Ember Charge | IMPLEMENTED |
| hellfire | ash_golem | Normal | 2 | Ash Mantle, Cinder Slam | IMPLEMENTED |
| hellfire | flame_cultist | Normal | 1 | Kindle (+Jab; trait Flame Row) | IMPLEMENTED |
| hellfire | magma_slug | Normal | 2 | Lava Spit, Molten Trail | IMPLEMENTED |
| hellfire | hell_knight | Normal | 2 | Cleave, Bulwark | IMPLEMENTED |
| hellfire | fire_eater | Elite | 2 | Ember Belch, Devour Flame (+trait Ember Feast) | IMPLEMENTED |
| hellfire | ash_phoenix | Elite | 2 | Ash Dive, Pyre (+trait Rise Again) | IMPLEMENTED |
| hellfire | inferno_lord | Boss | 4 | Brand, Cinder Lane, Stride, Eruption Call (+trait Twin Eruption) | IMPLEMENTED |
| desert | dune_jackal | Normal | 1 | Pack Nip (+Sidestep) | DESIGNED |
| desert | sand_beetle | Normal | 1 | Sand Spray | DESIGNED |
| desert | dust_nomad | Normal | 2 | Ambush, Veil Step | DESIGNED |
| desert | mirage_sprite | Normal | 2 | Mirage, Shimmer Lash | DESIGNED |
| desert | scarab_guard | Normal | 2 | Shield Wall, Spear Thrust | DESIGNED |
| desert | sun_archer | Normal | 1 | Blinding Arc (+trait Flame Row) | DESIGNED |
| desert | sand_burrower | Elite | 2 | Undertow, Sinkhole (+trait burrow) | DESIGNED |
| desert | scorpion | Elite | 2 | Venom Sting, Pincer Hold (+trait riposte) | DESIGNED |
| desert | sand_sphinx | Boss | 5 | Riddle Gaze, Stone Claw, Bury, Shift, Sandfall (+trait sandstorm) | DESIGNED |
| swamp | bog_rat | Normal | 1 | Gnaw | DESIGNED |
| swamp | mire_slug | Normal | 1 | Slime Trail (+Sidestep) | DESIGNED |
| swamp | swamp_lizard | Normal | 2 | Tail Sweep, Drag Bite | DESIGNED |
| swamp | marsh_toad | Normal | 1 | Tongue Pull | DESIGNED |
| swamp | reed_witch | Normal | 1 | Rot Cloud (+trait Rotten Toss) | DESIGNED |
| swamp | bog_hound | Normal | 1 | Mire Chase (+trait Flame Row) | DESIGNED |
| swamp | spore_cap | Elite | 2 | Spore Puff, Regrow (+trait spore_burst) | DESIGNED |
| swamp | leap_frog | Elite | 2 | Leap Slam, Croak (+trait hop_skip) | DESIGNED |
| swamp | toad_matriarch | Boss | 6 | Mire Spit, Tongue Lash, Sink, Shift, Toxic Croak, Regrow (+trait bog_spread) | DESIGNED |
| ch2 | skeleton | Normal | 1 | Shield Bash (+Sidestep) | DESIGNED |
| ch2 | zombie | Normal | 1 | Grab | DESIGNED |
| ch2 | bat_swarm | Normal | 2 | Scatter Bite, Flutter | DESIGNED |
| ch2 | slime | Normal | 2 | Engulf, Ooze | DESIGNED |
| ch2 | ghost | Normal | 2 | Wail, Phase | DESIGNED |
| ch2 | reacter | Normal | 1 | Trip Lash (thay trait Tripwire) | DESIGNED |
| ch2 | cultist | Normal | 2 | Curse Ring, Dark Rite | DESIGNED |
| ch2 | rat_king_guard | Normal | 1 | Shield Shove (+trait Flame Row) | DESIGNED |
| ch2 | jailer | Elite | 2 | Chain Hook, Lockdown (+trait Rotten Toss, Flame Row) | DESIGNED |
| ch2 | ogre_king | Boss | 5 | Club, Grab, Shift, Roar, Quake (+trait Fissure) | DESIGNED |
| ch3 | frost_sprite | Normal | 1 | Frost Kiss | DESIGNED |
| ch3 | wisp | Normal | 2 | Lantern, Lantern Flare | DESIGNED |
| ch3 | stone_sentry | Normal | 2 | Rime Bulwark, Rime Hammer | DESIGNED |
| ch3 | snow_wolf | Normal | 1 | Winter Hunt (+Sidestep) | DESIGNED |
| ch3 | fuse_golem | Normal | 1 | Shard Burst (+trait Lit Fuse) | DESIGNED |
| ch3 | rime_archer | Normal | 2 | Frost Arrow, Ice Caltrops | DESIGNED |
| ch3 | ice_golem | Normal | 1 | Glacier Fist (+trait Flame Row) | DESIGNED |
| ch3 | ghost_elite | Normal | 1 | Frozen Wail (+Phase dùng chung) | DESIGNED |
| ch3 | frost_mage | Elite | 3 | Cold Snap, Rime Field, Ice Ward (+trait Heavy Mist) | DESIGNED |
| ch3 | mist_lord | Boss | 6 | Frost Nail, Rime Lance, Crystal Anchor, Ice Mantle, Shift, Whiteout (+trait Heavy Mist) | DESIGNED |
| sky_isles | cloud_sprite | Normal | 1 | Mist Veil (+Jab) | DESIGNED |
| sky_isles | harpy | Normal | 1 | Talon Dive | DESIGNED |
| sky_isles | wind_monk | Normal | 2 | Gale Palm, Wind Step | DESIGNED |
| sky_isles | storm_eagle | Normal | 2 | Talon Rake, Circle | DESIGNED |
| sky_isles | sky_sentinel | Normal | 2 | Stone Gale, Sky Spear | DESIGNED |
| sky_isles | thunder_shaman | Normal | 1 | Thunder Call (+trait Flame Row) | DESIGNED |
| sky_isles | gale_bird | Elite | 2 | Downdraft, Updraft (+trait Crosswind) | DESIGNED |
| sky_isles | cloud_veil | Elite | 2 | Fork Bolt, Vapor Form (+trait Clouded Aim) | DESIGNED |
| sky_isles | storm_dragon | Boss | 4 | Tail Sweep, Storm Breath, Wing Shift, Tempest (+trait Island Drop, Crosswind) | DESIGNED |
| an_dai | an_dai_keeper | Final | 5 | Lattice Bolt, Sigil Lane, Lattice Seal, Shift, Heart Flare (+Flame Row p2) | DESIGNED |

**Tổng:** 73 id · 11 EXISTS (34 skill) · 57 DESIGNED (113 skill + 3 `shared_*`) · 5 ORPHAN.

---

## 13. Danh sách cần review (chưa đủ thông tin / cần người dùng quyết)

| Mục | Vì sao | Cần gì |
|---|---|---|
| `wolf`, `goblin_chief`, `goblin_warrior`, `goblin_shaman`, `goblin_brute` | không pool, không sheet, không ra trận; không rõ còn giữ hay xóa | quyết: đưa lại pool (thì thiết kế như Normal rừng) hay xóa khỏi `chapters.json` |
| `jailer` (4 cơ chế: 2 trait tick + 2 skill) | nhiều nhất roster, trên Elite | quyết giữ cả hay bỏ `row_burner` |
| `row_burner` trên ice_golem / bog_hound / thunder_shaman / sun_archer | trait mặc định node danger, lệch chủ đề vùng | đổi text theo vùng, hay `danger_traits` theo vùng (ngoài phạm vi) |
| `an_dai_keeper` chuyển pattern | sim Story 035 đo win-rate 0–7 % rất nhạy với trận này | chạy lại sim trước khi bật |
| Poison (Độc) | effect mới, hai vùng dùng | duyệt khái niệm "không chồng, làm mới" |
| Push/pull người chơi từ skill | rủi ro R3 Va Đập | duyệt luật ICD 2 s + không đẩy vào ô xấu |
| 13 id không ra trận với tier hiện tại | vẫn thiết kế; ưu tiên implement thấp | xác nhận có giữ `region_pool` xoay vùng không |
| HP khi chuyển block → pattern | tiền lệ rừng tăng ~2× | bước sim của từng vùng |

---

## Phụ lục A — Nguồn audit (để kiểm lại)

- Pattern brain: `src/combat/pattern_controller.gd` (chọn skill 361–395; điều kiện 398–415; timeline 489–562; damage 574–606; status 609–628;
  zone 631–655; self/marker/move/haste/guard 661–695; interrupt 258–302; phase 321–334, 754–780), `pattern_brain.gd` 27–79, `pattern_planner.gd`
  18–110, `fairness_check.gd` 17–155, `enemy_skills_config.gd` 11–31, 112–124, 248–299, 302–379.
- Block brain: `boss_brain.gd` 245–397, 611–707; `boss_controller.gd` 123–150, 239–287; `cut_effects.gd` 255–384; `swing_arbiter.gd` 311–381.
- Trait: `src/traits/trait_registry.gd` 8–31; từng file trait (§1.4); `trait_host.gd` 119–198, 266–278; `boss_phases.gd` 43–236; `run_config.gd` 11–25, 154–179, 221–336.
- Effect: `status_effects.gd` (ignite 183, fragile 242–284, frost 290–313, pin 354, reaction 507, mark 541–566, ward 722, thorns 787, drop 949,
  hole fall 1106–1133, root 1343, slow 1391, guard 1412), `tile_hazards.gd` 189–200, 296–378, 760, 926–946, `zone_rules.gd` 24–118, `combat_state.gd` 36–55, 90–114.
- Một enemy: `combat_state.gd` 10, 36–55; `combat_view.gd` 187, 252, 448, 515, 1302–1314, 2544–2592; `cut_hud_view.gd` 2229–2318.
- VFX/anim: `unit_layer.gd` 98–127, 437–469, 575–605, 777–802; `combat_view.gd` 3527–3531; `assets/art/vfx/cast/index.json`; `floor/`, `status/`.
- Data: `chapters.json` (73 match, pools, floor_tiers, region_order), `region_rules.json`, `boss_brain.json`, `enemy_skills.json` (34 skill, 13 enemy),
  `strings.csv` 102–114, 232–250, 623–640, 801–818, 864–934.

---

## Phụ lục B — Phase 0 Foundation: trạng thái implement (2026-11-13, chưa commit, test CHƯA CHẠY)

Code của bước 0 (§11) đã viết; **chưa chạy test nào** vì phiên bị cấm bật tiến trình Godot (runner `tools/qa/run_all_tests.sh`
cần `godot --headless`). Quy tắc "regression test phải được xem fail trước khi tin" (`.claude/rules/test-standards.md`) vì thế
**chưa được thoả** — người dùng cần chạy 5 suite mới + các suite pattern cũ trước khi dùng.

### B.1 Đã làm

| Hạng mục | Chỗ sửa | Ghi chú |
|---|---|---|
| G1 Rạn của người chơi nhân vào đòn pattern | `pattern_controller.gd` `_resolve_cells` | `consume_fragile(PLAYER)` trước `ward_absorb`; cùng thứ tự với CutEffects |
| G2 Giá Lạnh của quái nổ lên người chơi | `_apply_status` nhánh `frost` | áp `apply_frost` trả về; cộng vào `result.damage`; `StatusEffects.frost_burst_icd[side]` (mặc định tắt) giữ tầng ở ngưỡng−1 trong ICD |
| G3 `reaction_immune_fn` | `trait_host.gd` bind trong `_init`, gỡ ở `teardown_all`; `BossTrait.reaction_immune(side, id)` ảo; `extra_reaction_immune_fn` | enemy data `immune_reactions: ["r1"…]` → `PatternController.reaction_immune` |
| Zone mở cho skill quái | `EnemySkillsConfig.ZONE_IDS` += burn / mire / sand / fall; `zone.side: player|self` | burn → `StatusEffects.ignite`; mire/sand/fall → `TileHazards` (`PatternController.hazards`, null = bỏ qua + warning) |
| `effects.heal {ratio, amount, sec}` | `_resolve_self_or_marker` + tick | tức thì hoặc theo giây; `stun()` và `set_active(false)` huỷ |
| `effects.consume_burn {heal_per_cell}` | như trên | xoá mọi ô cháy hai nửa sân, hồi theo số ô |
| `effects.push {cells}` / `pull {cells}` | `_apply_forced_move` | `CutEffects.push_away` / `pull_toward` (về `enemy_cast_origin`); `player_blocked_fn`; ward `push_immune`; R3 qua `reaction_allowed` với `reactions` của match; `push_icd_sec` theo phe (mặc định 0) |
| `effects.evade {sec}` / `shroud {sec}` | `is_evading()` / `is_shrouded()` → `TraitHost.extra_untargetable_fn` / `extra_forecast_blocked_fn` | một điểm quyết định vẫn là TraitHost |
| `move.to: far_cell` | `_move_targets(to)` | ô xa nhất (Manhattan) mà footprint vừa |
| Poison (Độc) | `StatusEffects.poison/is_poisoned/get_poison_left/poison_tick_damage/clear_poison`, `_tick_poison`, `STATUS_POISON` trong `STATUS_ORDER`/`active_statuses`; `STATUS_IDS` += poison; `statuses.poison` mặc định 3 / 0,5 / 1 | không chồng: thời gian = max, damage = max, nhịp = min; chết → gỡ |
| VFX hook (G4) | `PatternController.skill_resolved` → `CombatView._on_pattern_skill_resolved` → `_play_cut_vfx(ENEMY, feedback, delivery)`; `PatternController.vfx_feedback()` (static, thuần) | result mang `kind` + `delivery`; thiếu delivery → `SkillDelivery.FALLBACK` + warning 1 lần/skill; self/marker không vẽ |
| Điều kiện AI mới | `_conditions_ok`: `player_status`, `player_on_zone`, `self_status`, `player_steps_since`, `burning_cells`, `max_zone_cells {kind: n}`, `allies_alive_min/max`, `ally_died_within_sec`, `ally_hp_below` | ally_* đọc `allies_fn` (chưa có engine nhiều quái → mặc định không đồng đội) |
| Trọng số theo trạng thái | skill `weights {player_status, player_on_zone, self_status, allies_alive}` → `PatternBrain.weight_for` | skill không có `weights` chấm điểm y như cũ (rừng không đổi) |
| `phases[].traits` / `brain_set` / `tempo_mult` (G5) | parse trong config; `CombatView._apply_pattern_phase` (add/remove qua TraitHost, `BossBrain.use_set`, tempo = gốc × pha); `announce_phase(index+1)` cho banner HUD | thay `phase_shift` cho quái pattern |
| Pause/resume (G6) | `PatternController.set_active/is_active`; `burrow.gd`, `rebirth.gd` dùng ctx `pattern_getter` (CombatView.make_trait_ctx); burrow chờ `is_busy()`; `shroud.gd` đọc `is_threatening()` | pause huỷ skill đang WINDUP/WARNING/FOLLOWUP_WAIT (cooldown × cancel ratio), đóng băng mọi đồng hồ; RECOVERY/STUNNED giữ timer |
| Bước người chơi | `CombatView.try_step_player` → `PatternController.on_player_stepped()` | đếm cho `player_steps_since` (step_reactor dạng data) |

### B.2 Chưa làm / chờ người dùng

- **Test chưa chạy** (xem đầu phụ lục). 5 suite mới: `tests/unit/combat/pattern_phase0_bugfix_test.gd`, `status_poison_test.gd`,
  `pattern_phase0_effects_test.gd`, `pattern_phase0_ai_test.gd`, `pattern_phase0_pause_test.gd`. Suite cũ phải chạy lại:
  `pattern_*`, `status_*`, `tests/unit/traits/*`, `tests/integration/run/pattern_*_dodge_test.gd`.
- **Câu hỏi Poison:** khi hai Độc khác số chồng nhau, bản implement lấy **max thời gian, max damage/tick, min nhịp** (theo quy ước
  `slow`/`guard` sẵn có). Thiết kế chỉ nói "không chồng, làm mới" — cần xác nhận hay đổi thành "cái mới thay cái cũ".
- `schema.md` không sửa (session khác đang sửa file đó) — key mới ghi ở B.1; cần chép sang schema khi file rảnh.
- HUD chip Độc/Rạn/Giá Lạnh **phía người chơi** chưa vẽ (`cut_hud_view._draw_pins` vẫn chỉ ENEMY); `active_statuses(PLAYER)` đã có dữ liệu.
- Pack VFX `poison` / `curse` / `seal` trong `impact_packs` vẫn rỗng → fallback vẽ shards mặc định.
- Không chuyển quái nào sang pattern brain; không thêm skill vào `enemy_skills.json`; không đổi stats/pool/trait.

### B.3 Phase 0 — kết quả test (2026-11-13, chạy nền)

- Suite mục tiêu 19/19 pass (`production/qa/monster-skill-phase0-targeted-2026-11-13.txt`; `status_poison_test` pass sau khi sửa
  lỗi lambda của chính test).
- Full suite 294 suite (`monster-skill-phase0-full-suite-2026-11-13.txt`): 2 lỗi mới do Phase 0 đã sửa — `enemy_skills_config_test`
  (fixture dùng `poison` làm status lạ → đổi sang `plague`), `controls_v3_hud_test` (`StatusRow.INFO` thiếu dòng poison → thêm
  row + 2 string `ui.status.poison.*`); `stick_flow_test` 17293 script error trong full run nhưng chạy lại FAILS=0 → không ổn định,
  không thuộc Phase 0. Sau sửa: cả hai suite FAILS=0.

### B.4 Phase 1 Hỏa Ngục — cân bằng nhóm E (2026-11-13)

Sim cùng seed với B1: Hỏa Ngục trên pattern brain **dễ hơn nhiều** so với block brain (qua 100 %, HP mất trong trận −76 %,
thời gian run +5,5 %). Giá trị damage §4 (6–14) ngang rừng tầng 1, nên cần một đợt tinh chỉnh trước khi coi Hỏa Ngục là
tầng 2 thật. Chi tiết và các lựa chọn: `MONSTER-SKILL-PHASE1-HELLFIRE-PLAN.md` §12.1. Bài học cho Phase 2+ (Sands, Swamp…):
đặt damage theo tầng của vùng, không lấy rừng làm mốc, và chạy sim so với baseline block trước khi chốt.

### B.5 Hỏa Ngục — damage chốt sau tinh chỉnh (2026-11-14)

Damage đòn trực tiếp của 11 skill Hỏa Ngục = **giá trị thiết kế §4 × 3,5** (Imp 21, Hound 35, Golem/Eater/Phoenix 42,
Cultist/Slug 28, Knight 49, Lord: Dấu Nung 35 / Cinder Lane 49 / Eruption 49 rồi 35). Lửa cháy theo nhịp giữ 2/tick.
Cơ sở: `MONSTER-SKILL-PHASE1-HELLFIRE-PLAN.md` §12.2 — tỉ lệ thắng gộp bằng B1 (13,2 vs 13,3), phút/run bằng nhau.
Trần an toàn: đòn nặng nhất ×1,5 (Rạn) phải dưới nửa máu hero thấp nhất; test `pattern_hellfire_group_d_test` giữ gate này.
**Bài học cho Phase 2+ (Sands, Swamp…):** đặt damage theo tầng của vùng chứ không lấy rừng tầng 1 làm mốc, và chạy sim
so với baseline block TRƯỚC khi chốt; giá trị thiết kế ban đầu lệch 3,5 lần.
