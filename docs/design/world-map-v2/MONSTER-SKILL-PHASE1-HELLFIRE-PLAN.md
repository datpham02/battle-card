# Monster Skill Phase 1 — Hỏa Ngục: kế hoạch triển khai (research + planning, chưa code)

**Ngày:** 2026-11-13 · **Trạng thái:** Proposed, chờ người dùng xác nhận · **Điều kiện tiên quyết:** Phase 0 Foundation **phải
pass test** (đang chạy nền, `production/qa/monster-skill-phase0-targeted-2026-11-13.txt`); tài liệu này **không** coi Phase 0
là đã pass. **Phạm vi:** 9 quái `hellfire` trong `assets/data/chapters.json` (§4.2 của `MONSTER-SKILL-DESIGN.md`, 17 skill +
2 skill dùng chung). Không vùng khác. Không đổi stats/trait/pool.

---

## 1. Hiện trạng 9 quái Hỏa Ngục (data đang chạy)

| Id | Loại | Não | Trait | HP gốc / giáp / min_runes | Sân | Sprite (session anh em, uncommitted) |
|---|---|---|---|---|---|---|
| imp | Normal B0–1 | block, cautious | — | 92 | forge | `unit_imp_sheet` 5 clip |
| ember_hound | Normal B0–1 | block | — | 110 | caldera | có |
| ash_golem | Normal B1–2 D1 | block | — | 132 / def 3 | forge | có |
| flame_cultist | Normal B1–2 D1–2 | block | row_burner | 128 | caldera | có |
| magma_slug | Normal B2 D1–2 | block | — | 140 | forge | có |
| hell_knight | Normal B2 D2 (không ra tầng 2) | block | — | 156 / def 2 / mr 3 | caldera | có |
| fire_eater | Elite | block | burn_eater {heal_ratio 1} | 90 / mr 2 | forge | có |
| ash_phoenix | Elite | block | rebirth {0.4, 1.5 s} | 74 / mr 2 | caldera | có |
| inferno_lord | Boss | block, aggressive | vent_surge {10 s, 2}; phase_shift {0.5, aggressive, step 1.0, extra [], vent_interval_mult 0.7} | 180 / mr 3 | caldera | có |

Không quái nào có skill riêng: block brain cast lá bài người chơi (`boss_card_order`) + trait. Sân: forge 5×3 (mạch phun hàng 0–1
mỗi nửa), caldera 5×5 (khuyết 3 ô cột 3, mạch phun cột 1 và 4). Vùng có rule Heat (gauge 0–4 chỉnh `vent_interval_sec`,
`vent_tick_damage`, `vent_sec`, thêm `vent_surge` ở heat 4; warden_hook `vent_surge {7 s, first 10 s}`) và modifier pool
`big_hands, quick_blocks, thorn_field, seal_caster, vent_surge`.

Sprites: 5 clip cơ bản (idle/step/windup/hit/down) — session "region enemy visual assets" đã gen 9 sheet, chưa commit. Clip
đặc biệt (guard/brace/howl/windup_heavy/stunned/phase_shift) **chưa có** → fallback của `unit_layer.gd` (guard→brace→windup,
howl→windup, windup_heavy→windup, stunned→idle, phase_shift→idle).

---

## 2. Đối chiếu 17 skill với Phase 0

Ký hiệu cột **Hỗ trợ**: **P0** = Phase 0 hỗ trợ trực tiếp (chỉ data); **CODE** = cần mở rộng code (nhỏ, ghi rõ); **ASSET** = cần
asset/VFX mới (không bắt buộc để chạy, fallback có sẵn).

### 2.1 Normal

| Quái | Skill | Delivery (`type / travel / impact`) → VFX hiện có | Effect / điều kiện / trọng số dùng | Hỗ trợ |
|---|---|---|---|---|
| imp | `imp_ash_dart` 1 ô, 6 dmg + fragile 1 | `CASTER_TO_TARGET / square_streak / burn` → streak mặc định màu burn + `impact_flame_burn` | `status fragile` (có); `weights.allies_alive 1.5` (P0, trơ khi chưa có bầy) | **P0** |
| imp | `shared_sidestep` weight 0,6 | `DIRECT / none / none` | `move adjacent_row` | P0 |
| ember_hound | `hound_ember_charge` hàng 2 ô từ vạch chia, 10 dmg | `GROUND / floor_run / burn` → `miss_dust` chạy sàn + flame | `weights.player_status {fragile: 2.0}` (P0); ×1,5 Rạn qua G1 (P0) | **P0** |
| ash_golem | `golem_ash_mantle` guard phe +3 / 4 s | `DIRECT / none / guard` → không pack (rỗng) | `guard` (có); `weight 0.3` + `weights.allies_alive 4.0` (P0); `interrupt_stun_sec 0.8` (có) | P0; clip `guard`/`brace` = ASSET tuỳ chọn |
| ash_golem | `golem_cinder_slam` 2×2 near_player, 12 | `DIRECT / none / shatter` → shards mặc định | `interruptible false`, recovery 1,2 (có) | P0; clip `windup_heavy` = ASSET tuỳ chọn |
| flame_cultist | `cultist_kindle` 2 ô kề, cháy 3 s | `DIRECT / none / burn` | `zone {id burn, sec 3, tick 0.5, damage 2}` (P0); `conditions.max_zone_cells {burn: 3}` (P0). **Lưu ý data:** `pattern.count` chỉ dùng cho marker → viết 2 ô bằng `near_player` + `offsets [[0,0],[0,1]]` rot 4 + `exclude_player` | **P0** (đổi cách viết pattern) |
| flame_cultist | `shared_jab` | `CASTER / square_streak / slash` | — | P0 |
| magma_slug | `slug_lava_spit` 1 ô 8 + cháy ô đó 2 s | `SKY / falling_squares / burn` | `damage` + `zone burn` cùng ô (P0) | **P0** |
| magma_slug | `slug_molten_trail` dời hàng, ô vừa rời cháy 2 s | `DIRECT / none / burn` | `move` + `zone {burn, side: self}` (P0, chỉ burn) | **P0** |
| hell_knight | `knight_cleave` hàng 3 ô, 14, không ngắt | `CASTER / square_streak / slash` | có | P0 |
| hell_knight | `knight_bulwark` guard 5 / 4 s khi < 50 %, 1 lần | `DIRECT / none / guard` | `conditions {hp_below 0.5, once}` (có) | P0 |

### 2.2 Elite

| Quái | Skill | Delivery → VFX | Effect / điều kiện | Hỗ trợ |
|---|---|---|---|---|
| fire_eater | `eater_ember_belch` cột 3 ô, 12 + cháy 2,5 s | `GROUND / floor_run / burn` | `column_of_player` clip min 2 (có) + `zone burn` (P0) | **P0** |
| fire_eater | `eater_devour` hút mọi ô cháy, +6/ô | `DIRECT / none / burn` | `consume_burn {heal_per_cell 6}` (P0); `conditions.burning_cells 2` (P0); `interrupt_stun_sec 1.0` (có); `mechanic` | **P0**; clip `howl` = ASSET tuỳ chọn |
| fire_eater | trait `burn_eater` giữ | — | hook burn_heal_ratio (có) | P0 |
| ash_phoenix | `phoenix_ash_dive` L 3 ô, 12 + fragile 1 | `SKY / falling_squares / burn` | có | P0 |
| ash_phoenix | `phoenix_pyre` 3 ô kề cháy 4 s khi < 50 % | `DIRECT / none / burn` | `near_player` L `[[0,0],[1,0],[0,1]]` rot 4 `exclude_player` (viết lại thay `count 3`) + `zone burn` (P0) + `hp_below/once` (có); F3 tự cắt ô để chừa lối | **P0** |
| ash_phoenix | trait `rebirth` giữ | — | pause PatternController qua `pattern_getter` (P0, **phụ thuộc test pause pass**) | P0 |

### 2.3 Boss

| Skill | Delivery → VFX | Effect / điều kiện | Hỗ trợ |
|---|---|---|---|
| `lord_brand` 1 ô 10 + fragile | `CASTER / square_streak / burn` | có | P0 |
| `lord_cinder_lane` hàng 3 ô 14 + cháy 2 s, không ngắt | `GROUND / floor_run / burn` | `zone burn` (P0) | P0 |
| `lord_stride` = sidestep (hồi 8, weight 2) | — | có | P0 |
| `lord_eruption_call` 2×2, 14; lặp cùng ô sau 1 s, 10 + cháy 2 s | `SKY / falling_squares / burst` | `followup {same_cells, delay 1.0, effects {damage 10, zone burn}}` — followup effects đi qua `_normalize_effects` nên `zone` trong followup **được** áp (P0); `weight 0` + `every_nth` (có) | **P0** |
| Pha 2 ở 50 %: mạch phun dày hơn | — | **Khuyến nghị: GIỮ trait `phase_shift`** (`vent_interval_mult 0.7`, `extra_traits []`, `step_mult 1.0`, `brain_set aggressive`) — trait này không phụ thuộc block brain, chạy song song với `phases[]` của pattern. Không dùng `phases[].traits` cho vent_surge (xem §4.1) | P0 + 1 việc CODE nhỏ (§4.2 banner đôi) |
| trait `vent_surge` + Heat warden_hook | — | tick-based, giữ nguyên; hook override params vẫn áp vì trait nằm ở `chapters.json` | P0 |

**Kết luận đối chiếu:** 17/17 skill viết được bằng data với Phase 0; không skill nào cần effect mới. Hai chỗ phải viết khác bản
thiết kế (`count` → `offsets`). Hai việc code nhỏ ở §4.

---

> **Quy ước offset của `column_of_player` (phát hiện ở nhóm C, 2026-11-13).** `PatternPlanner` đặt ô theo
> `(player.x − off.y, start + off.x)`: trục **x** của offset chạy **dọc cột** (giống `row_of_player`, nơi x chạy dọc hàng).
> Một cột 3 ô viết là `[[0,0],[1,0],[2,0]]`, **không phải** `[[0,0],[0,1],[0,2]]` (dạng đó nằm ngang). Các skill thiết kế ở §4
> có ghi offset cột kiểu `[[0,0],[0,1]]` (Scarab Spear, Tongue Pull, Chain Hook, Gale Palm, Sky Spear, Ghost Wail, Rime Lance,
> Storm Breath, Tongue Lash, Undertow, Frozen Wail…) phải đổi sang dạng trục x khi implement. `pattern_fairness_test.gd`
> (`column_of_player: vertical windows`) là chuẩn tham chiếu.

## 3. Thay đổi data dự kiến (khi được duyệt)

| File | Thay đổi |
|---|---|
| `assets/data/enemy_skills.json` | +17 skill (`owner` tương ứng) + 2 shared (`shared_jab`, `shared_sidestep`; `shared_bar` để dành) + 9 `enemies` (imp, ember_hound, ash_golem, flame_cultist, magma_slug, hell_knight: `skills`; fire_eater, ash_phoenix: `skills`; inferno_lord: `phases` p1/p2, `tier warden`, footprint 1 ô theo bible Kẻ Gác 1 ô) |
| `assets/data/chapters.json` | 9 match `hellfire`: thêm `"brain": "pattern", "enemy": "<id>"`; **giữ** `traits`, `brain_set` (movement), timing; `boss_min_runes` để nguyên (trơ với pattern). Không đổi `boss_max_hp` (§6 rủi ro) |
| `assets/i18n/strings.csv` | 19 × 2 dòng `enemy_skill.<id>.name` / `.counter` (vi, en), CRLF, UTF-8 không BOM, 3 cột — viết bằng script append, không mở bằng Excel (ghi chú encoding trong memory) |
| `assets/data/schema.md` | mục P2.2 bổ sung key Phase 0 (đang bị session khác sửa → làm sau cùng, hoặc giao session đó) |

Không đụng: `region_rules.json`, `arenas.json`, `boss_brain.json`, trait class, sprite.

---

## 4. Việc code cần mở rộng (ngoài data), đều nhỏ

### 4.1 Phase traits trùng id (chỉ nếu không giữ `phase_shift`)
`CombatView._apply_pattern_phase` hiện **thêm** trait của pha bằng `add_trait`; một `vent_surge` thứ hai sẽ chạy song song với
`vent_surge` của match → mạch phun gấp đôi. Nếu muốn pha 2 đổi params của trait sẵn có phải thêm luật "cùng id → remove rồi
add" và **sẽ mất** params do warden_hook Heat ghi đè. → **Khuyến nghị giữ `phase_shift`** (0 code), chỉ dùng `phases[]` cho skill.

### 4.2 Banner pha đôi
`phase_shift` gọi `announce_phase(2)`; `_on_pattern_phase_started` cũng gọi `announce_phase(index+1)` ở cùng ngưỡng 0,5 → HUD
hiện "PHA 2" hai lần. Sửa 1 dòng: không announce từ pattern khi host đã có trait `phase_shift`/`boss_phases`, hoặc bỏ announce
trong `phase_shift` khi match là pattern. Test: 1 banner.

### 4.3 Dodge test với mạch phun
`pattern_roster_dodge_test` chạy không hazards; với Hỏa Ngục bot né hoàn hảo vẫn có thể đứng trên mạch phun (địa hình). Giữ bất
biến "0 damage từ **skill**" bằng cách chạy roster dodge **không wire `hazards`** (như rừng), và một test riêng có hazards chỉ
đo `fairness`/không-đói (§5). Không đổi code game.

### 4.4 Modifier trơ (quyết định thiết kế, không code trong Phase 1)
`big_hands` (`boss_min_runes_add`) và `quick_blocks` (`boss_drop_interval_mult`) **không có tác dụng** lên pattern enemy →
2/5 modifier của lane Hỏa Ngục thành vô hiệu sau khi chuyển. Đề xuất cho World Map v2 (ngoài Phase 1): map `big_hands` →
`pattern_tempo_mult × 0.9` hoặc `weights` nặng hơn; `quick_blocks` → `pattern_tempo_mult × 0.85`. Cần người dùng quyết.

---

## 5. Kế hoạch theo nhóm quái, test và file

Mỗi nhóm = 1 PR data + strings + test; chạy tests **ở nền**; capture windowed `--audio-driver Dummy` cho từng quái.

| Nhóm | Quái | Vì sao gom | Test case mới / mở rộng |
|---|---|---|---|
| **A. Dấu Tro** — **XONG 2026-11-13, chờ review** | imp, ember_hound, ash_golem | combo nền của vùng (Rạn → thưởng; guard phe) | (1) imp dart dính Rạn, hound ×1,5 + weight ×2 khi Rạn (`weight_for`); (2) golem mantle guard(E) cộng vào giáp swing (SwingArbiter), Xuyên giáp bỏ; (3) mantle weight 0,3 khi không có đồng đội; (4) fairness F1/F2 trên forge + caldera + 200 biến thể; (5) dodge 0 dmg |
| **B. Lửa cắt đường** — **XONG 2026-11-13, chờ review** | flame_cultist, magma_slug, hell_knight | zone burn, ngân sách, self zone | (1) kindle không chọn khi ≥ 3 ô cháy nửa người chơi (kể cả hàng row_burner); (2) spit: ô trúng cháy 2 s; (3) molten trail: ô cũ cháy, ô mới không; khối người chơi đặt lên vệt bị đốt (`FieldDrops.bury_cells` — xác minh có gọi khi `cell_ignited`); (4) kindle F3 chừa lối; (5) AI không đói: trên forge có 2 hàng mạch phun đang cháy vẫn có ≥ 1 plan công bằng trong 10 s mô phỏng; (6) knight bulwark 1 lần dưới 50 % |
| **C. Elite** — **XONG 2026-11-13, chờ review** | fire_eater, ash_phoenix | heal/consume + rebirth pause | (1) devour chỉ khi ≥ 2 ô cháy, hút cả hai nửa, +6/ô, bị ngắt → stun 1 s không hồi; (2) belch → devour loop ≤ 1 lần / 9 s; (3) pyre 1 lần, 3 ô, chừa lối; (4) rebirth giữ 1 HP, pattern pause, revive 40 %, có Giá Lạnh thì chết thật (test trait cũ + pattern); (5) burn_eater: lửa của chính nó không làm nó đau (đứng trên ô belch? belch chỉ nửa người chơi → không) |
| **D. Kẻ Gác** — **XONG 2026-11-13 (bản vá on_enter đã duyệt + áp), chờ review** | inferno_lord | phases + trait song song + Heat | (1) p1 4 skill, p2 +eruption_call every_nth 3, on_enter; (2) transition 1,5 s bất tử, HP floor 0,5; (3) `phase_shift` vẫn đổi vent mult 0,7 và brain_set; (4) 1 banner; (5) warden_hook heat ≥ 3 vẫn áp interval 7; (6) eruption_call followup cùng ô + zone trong followup; (7) `vent_surge_arena_invariant_test` vẫn pass |
| **E. Cân bằng** | cả 9 | — | `tools/balance/deck_sim.gd` 7 tầng, so với baseline B1 (`production/qa/evidence/world-map-v2/b1-balance`): thời lượng trận, hits_taken, win-rate theo hero; `run_bot_matrix.sh` cho 6 match Hỏa Ngục |

File dự kiến: `assets/data/enemy_skills.json`, `assets/data/chapters.json`, `assets/i18n/strings.csv`, test mới
`tests/unit/combat/pattern_hellfire_roster_test.gd` (fairness forge/caldera, theo mẫu `pattern_roster_fairness_test` với
`ArenaLibrary.grid_for_spec`), `tests/integration/run/pattern_hellfire_dodge_test.gd`, mở rộng `tests/unit/traits/region_traits_test.gd`
(rebirth + pattern), 1 dòng `combat_view.gd` (§4.2) + test banner, `docs/design/world-map-v2/MONSTER-SKILL-DESIGN.md` (đánh dấu
Hỏa Ngục implemented), `production/qa/evidence/monster-skill-hellfire/` (capture).

Thứ tự: A → B → C → D → E. Dừng được sau mỗi nhóm (quái chưa chuyển vẫn chạy block brain).

---

## 6. Mâu thuẫn / rủi ro với gameplay hiện tại

| # | Rủi ro | Mức | Xử lý |
|---|---|---|---|
| R1 | **HP:** pattern enemy không nhặt khối, trận ngắn hơn; rừng đã nâng Normal lên 190–250 (pack budget D8) trong khi Hỏa Ngục 92–156 → trận có thể quá ngắn/ít đe doạ, hoặc ngược lại nếu skill mạnh hơn block cast | cao | KHÔNG đổi HP trong Phase 1; chạy sim nhóm E trước, đề xuất số sau |
| R2 | **AI đói vì lửa:** F1 không cho thoát xuyên ô cháy; forge có 2 hàng mạch phun cháy 2 s mỗi 7 s (4 s ở heat 4) + kindle/spit/belch → nhiều plan bị loại, quái đứng im | cao | ngân sách `max_zone_cells {burn: 3}` trên mọi skill burn; test B(5); nếu vẫn đói: giảm `sec` zone xuống 2, hoặc ưu tiên plan không chạm ô cháy (code, sau) |
| R3 | **Modifier trơ** `big_hands`, `quick_blocks` (§4.4) | trung | quyết định thiết kế trước khi bật lane Peril Hỏa Ngục với pattern |
| R4 | **Banner pha đôi** (§4.2) | thấp | 1 dòng + test |
| R5 | **Rebirth/burrow pause** phụ thuộc test Phase 0 pass | trung | chờ kết quả nền |
| R6 | **Heat gauge**: hàng heat chỉnh vent + `boss_drop_interval_mult 0.9` (heat 3–4) — drop mult trơ với pattern → Heat yếu đi một bậc | thấp | ghi nhận; có thể map sang tempo sau |
| R7 | **flame_cultist** có cả `row_burner` (trait) + kindle: cùng ngân sách burn 3 ô → kindle gần như câm trong 2,5 s hàng cháy | thấp | chấp nhận (thiết kế: hàng lửa = nhịp lớn) |
| R8 | **Sprite chưa commit** của session anh em; capture Phase 1 cần sheet đó | thấp | phối hợp commit trước nhóm A |
| R9 | **Clip đặc biệt** thiếu → guard/howl nhìn như windup | thấp | ASSET tuỳ chọn; không chặn |
| R10 | `strings.csv` CRLF/UTF-8 | thấp | append bằng script, kiểm `git diff` chỉ thêm dòng |

Không có mâu thuẫn với luật sân (vent, Heat warden_hook), với Skill v2 của người chơi, hay với save format.

---

## 7. Danh sách cần người dùng xác nhận trước khi triển khai

1. Kết quả test Phase 0 (nền) — **điều kiện tiên quyết**, kể cả 5 suite mới và suite pattern/trait cũ.
2. Inferno Lord: giữ trait `phase_shift` song song `phases[]` (0 code) hay chuyển hẳn sang `phases[].traits` (cần luật cùng-id, mất warden_hook)? **Đề xuất: giữ.**
3. Luật chồng Poison (không dùng ở Hỏa Ngục, nhưng Phase 0 đã implement max/max/min) — xác nhận để khỏi sửa lại sau.
4. Số khởi điểm của 17 skill (§4.2 thiết kế) dùng nguyên cho sim, HP không đổi — đồng ý?
5. Modifier `big_hands` / `quick_blocks` với pattern enemy (§4.4): tạm chấp nhận trơ trong Phase 1, hay map sang tempo ngay?
6. Thứ tự nhóm A→B→C→D→E và việc commit sheet Hỏa Ngục của session anh em trước nhóm A.
7. Có gen clip đặc biệt (guard/howl/windup_heavy) cho Golem, Eater, Knight, Lord không (paid, PixelLab) — mặc định **không** trong Phase 1.

---

## 8. Nhóm A — đã triển khai (2026-11-13, chưa commit)

- Data: `assets/data/enemy_skills.json` +5 skill (`shared_sidestep`, `imp_ash_dart`, `hound_ember_charge`, `golem_ash_mantle`,
  `golem_cinder_slam`) + 3 enemies (imp: dart + sidestep weight 0,6 qua `overrides`; ember_hound; ash_golem); `assets/data/chapters.json`
  3 match `brain: pattern` + `enemy`; `assets/i18n/strings.csv` +10 dòng `enemy_skill.*.name/.counter`.
- Khác thiết kế §4.2: `hound_ember_charge` dùng cửa sổ trượt `row_of_player` 2 ô (clip, min 2, không `start: front`) để luôn phủ
  được hero ở mọi cột — bản thiết kế viết "từ vạch chia" sẽ câm khi hero đứng lùi.
- Test: `tests/unit/combat/pattern_hellfire_group_a_test.gd` (dart → Rạn; hound 10 / 15 vs Rạn + stack tiêu; weight ×2; mantle
  guard(E) 3/4 s, giáp swing 3+3 → lá 7 còn 1, pierce bỏ cả; weight 0,3 / 1,2; ngắt → stun 0,8; slam 2×2 không ngắt, 12),
  `pattern_hellfire_fairness_test.gd` (forge + caldera + 200 biến thể, F1/F2/F3, dodger 0 dmg, mọi skill dùng được),
  `tests/integration/run/pattern_hellfire_dodge_test.gd` (sân thật của match, 3 seed, dodger 0 dmg từ skill, đứng yên bị đau).
  Kết quả: tất cả FAILS=0 (`production/qa/monster-skill-hellfire-group-a-rerun-2026-11-13.txt`), kèm `enemy_skills_config`,
  `pattern_dodge`, `pattern_roster_fairness/dodge`, `vent_surge_arena_invariant`, `chapters`, `chapters23`, `world_map_gen`,
  `hazard_strings_039`, `pattern_roster_mechanics` đều pass.
- Ảnh: `production/qa/evidence/monster-skill-hellfire/group-a/` (6 ảnh + README).
- Chưa: sim cân bằng (nhóm E), HP không đổi, modifier `big_hands`/`quick_blocks` trơ (đã chấp nhận), capture đúng banner vùng
  cần run thật.

## 9. Nhóm B — đã triển khai (2026-11-13, chưa commit)

- Data: `enemy_skills.json` +6 skill (`shared_jab`, `cultist_kindle`, `slug_lava_spit`, `slug_molten_trail`, `knight_cleave`,
  `knight_bulwark`) + 3 enemies; `chapters.json` 3 match `brain: pattern` + `enemy` (HP, giáp, `row_burner` của Cultist, sân giữ
  nguyên); `strings.csv` +12 dòng. Không thêm code: mọi skill viết bằng key Phase 0.
- Viết khác thiết kế §4.2 (đã ghi ở §2.1): `cultist_kindle` = `near_player` + `offsets [[0,0],[0,1]]` xoay 4 hướng + `exclude_player`
  (thanh 2 ô chạm hero, không gồm ô hero) thay cho `count 2`; `knight_bulwark` thêm `weight 2.0` để khi đủ điều kiện (< 50 %, 1 lần)
  nó không thua Cleave quá lâu; `knight_cleave` dùng cửa sổ trượt dọc hàng như Hound (không `start: front`).
- Test: `tests/unit/combat/pattern_hellfire_group_b_test.gd` (kindle 2 ô cạnh hero, không ô hero, 3 s, còn lối; ngân sách burn 3 chặn
  kindle khi 10 ô cháy, jab vẫn ra đòn; spit 8 + ô cháy 2 s, tick 2 lên hero đứng yên; trail dời 1 hàng, ô rời cháy, ô mới không,
  Sên không tự đốt; cleave 2–3 ô trên hàng hero, khung ngà, không ngắt, 14; bulwark không dùng > 50 %, dùng 1 lần < 50 %, guard 5 / 4 s);
  `pattern_hellfire_fairness_test.gd` và `pattern_hellfire_dodge_test.gd` mở rộng lên 6 quái (máu quái đẩy xuống 45 % ở giây 30 để
  bulwark chạy). Kết quả: `production/qa/monster-skill-hellfire-group-b-2026-11-13.txt` + chạy lại 2 suite sau sửa test, tất cả FAILS=0.
- Lỗi gặp trong lượt, đều do test: (1) bộ đếm `int` trong lambda (GDScript capture theo giá trị) làm check "jab không đói" fail
  và check "kindle không được chọn" luôn pass vô nghĩa → đổi sang mảng; (2) `pattern_phase0_ai_test` đòi cả file không có `weights`
  (đã sai từ nhóm A) → thu hẹp về 11 quái rừng, đúng ý gốc.
- Ảnh: `production/qa/evidence/monster-skill-hellfire/group-b/` (6 ảnh + README).

## 10. Nhóm C — đã triển khai (2026-11-13, chưa commit)

- Data: `enemy_skills.json` +4 skill (`eater_ember_belch`, `eater_devour`, `phoenix_ash_dive`, `phoenix_pyre`) + 2 enemies tier
  `elite` (fire_eater: mechanic `eater_devour`); `chapters.json` 2 match `brain: pattern` + `enemy` (HP, trait `burn_eater` /
  `rebirth`, sân giữ nguyên) → 8/9 match Hỏa Ngục chạy pattern; `strings.csv` +8 dòng. Không thêm code.
- Viết khác / bổ sung so với §2.2: Belch dùng `column_of_player` với offsets `[[0,0],[1,0],[2,0]]` (quy ước trục x, ghi chú ở §3);
  Pyre `interruptible: false` (thiết kế ghi clip `windup_heavy`, tức là tell không-ngắt) và `weight 2.0` (như Bulwark) để không bị
  Dive lấn sau khi đủ điều kiện; Devour `weight 1.5` + `mechanic` đúng thiết kế.
- Test: `tests/unit/combat/pattern_hellfire_group_c_test.gd` (belch đường thẳng đứng 2–3 ô, 12, ô cháy 2,5 s kể cả khi trượt, chỉ
  nửa người chơi; devour cần ≥ 2 ô cháy, nuốt cả hai nửa, +6/ô, chặn ở max HP, bị ngắt → stun 1 s không hồi + lửa còn + cooldown ×0,5;
  devour nuốt cả lửa mạch phun (ghi nhận hành vi, rủi ro R11); burn_eater hồi máu khi đứng trên lửa, miễn R1, R2/R3 vẫn được;
  dive chữ L 3 ô, 12 ×1,5 với Rạn có sẵn rồi để lại 1 Rạn, Rạn không quá 3; pyre không dùng > 50 %, dùng 1 lần, 1–3 ô cạnh hero
  không gồm ô hero, 4 s, khung ngà không ngắt, còn lối, không tự đốt; rebirth giữ 1 HP + pause pattern + hồi 40 % → mở Pyre; có 1 Hàn
  → chết hẳn; mọi dòng strings của skill Hỏa Ngục đọc đúng 3 cột). Fairness/dodge mở rộng lên 8 quái.
- Lỗi gặp trong lượt: (1) config: Belch viết offset cột sai quy ước → thanh nằm ngang; test mới bắt được, sửa data. (2) strings
  (từ Phase 0 / nhóm A): 3 dòng có dấu phẩy không bọc ngoặc → 5 cột, cột en lệch; sửa + thêm check 3 cột. (3) strings: thuật ngữ cũ
  "windup" (Golem, nhóm A) và "Cột/Column" (Belch) bị `terminology_scan_test` bắt → viết lại theo glossary #18 / #26.
- Full suite: 300 suite; lần chạy có 1 FAIL (`terminology_scan_test`, lỗi (3) ở trên, do chương trình này) → đã sửa, chạy lại riêng
  `terminology_scan_test`, `pattern_hellfire_group_c_test`, `keyword2_test`: FAILS=0. Không chạy lại toàn bộ 300 suite sau sửa.
- Rủi ro mới: **R11** Devour nuốt cả lửa của mạch phun (terrain ignite) và hồi máu theo số ô: một hàng forge phun (5 ô) = +30 HP,
  đồng thời tắt lửa mạch phun sớm. Không đổi trong nhóm C (đúng chữ thiết kế "hút mọi ô cháy"); cần quyết ở nhóm E (giới hạn ô,
  bỏ terrain, hoặc giữ như phần thưởng cho người chơi vì mạch phun tắt sớm).
- Ảnh: `production/qa/evidence/monster-skill-hellfire/group-c/` (7 ảnh + README).

## 11. Nhóm D — Inferno Lord (2026-11-13, chưa commit)

- Data: `enemy_skills.json` +4 skill (`lord_brand`, `lord_cinder_lane`, `lord_stride`, `lord_eruption_call`) + enemy `inferno_lord`
  (tier warden, 1 ô, sân caldera, p1 {brand, lane, stride} mechanic lane; p2 ở 0,5 + eruption, mechanic eruption, `every_nth` 3,
  transition 1,5 s, `on_enter` eruption); `chapters.json` match `brain: pattern` + `enemy` — **traits `vent_surge` + `phase_shift`
  giữ nguyên** (không chuyển vào `phases[].traits`), HP / giáp / sân không đổi → 9/9 match Hỏa Ngục chạy pattern; `strings.csv` +8
  dòng (tên vi của Brand là "Dấu Nung", tránh họ từ "Ấn" cũ; counter Cinder Lane dùng "sweeps", tránh "runs" của glossary).
- `phase_shift` + pattern: cùng tick ở đúng 50 % (pattern kẹp máu ở ngưỡng, `phase_shift` kích hoạt khi ≤ 0,5) → đổi brain_set
  aggressive, nhân vent timer 0,7, announce pha 2 **một lần**; CombatView cũng announce 2 từ pattern trong cùng khoảnh khắc nhưng
  HUD chỉ đặt lại chữ "PHA 2" → **một banner**. Kết luận: **không cần sửa `combat_view.gd`** (file đã bàn giao cho multi-enemy).
- **Lỗi controller tìm thấy (chưa sửa, chờ duyệt):** `PatternController._try_choose` chỉ chuyển `every_nth` vào `forced_skill`;
  skill của `transition.on_enter` đi vào vòng quay trọng số. Eruption có `weight 0` (thiết kế: chỉ khi bị ép) → tổng trọng số 0 →
  không chọn → bị `pop` khỏi hàng đợi và mất. `assets/data/schema.md` dòng 1109 ghi rõ hợp đồng: weight 0 "chỉ khi bị ép
  (`every_nth` / `on_enter`)" → code trái tài liệu, lỗi có từ P2.4 (rừng không lộ vì `root_anchor` của Witch có weight > 0).
  **Bản vá đề xuất (3 dòng, `src/combat/pattern_controller.gd` `_try_choose`, file của chương trình này, multi-enemy không sửa):**
  ```gdscript
  var forced: String = ""
  if not forced_queue_skill.is_empty():
      forced = forced_queue_skill  # on_enter forces its skill (schema: weight 0 = only when forced by every_nth / on_enter)
  elif not every.is_empty() and (_phase_casts + 1) % int(every["n"]) == 0:
      forced = str(every["skill"])
  ```
  Ảnh hưởng: chỉ skill on_enter; với Witch (on_enter root_anchor, weight > 0, ứng viên duy nhất) kết quả không đổi. Test hồi quy đã
  có và **đã thấy fail** trên code hiện tại: `pattern_hellfire_group_d_test` "first warning of p2 is the eruption" và
  "first counted cast is the eruption" (thấy `lord_cinder_lane`). Thay thế không cần code (đã cân nhắc, **không** khuyến nghị):
  cho eruption weight nhỏ > 0 → có xác suất bắn ngoài nhịp every_nth, sai thiết kế.
- Test: `tests/unit/combat/pattern_hellfire_group_d_test.gd` — data; p1 không bao giờ eruption, đủ brand/lane/stride; brand 10 + Rạn;
  lane 2–3 ô hàng hero, 14, không ngắt, cháy 2 s, Lord không tự đốt; một đòn dừng ở 50 %, transition 1,5 s bất tử, xoá đỏ, hồi lại
  có thể bị đánh; p2 eruption chỉ ở cast 1 hoặc bội 3 (stride không tính), ≥ 4 lần/60 s; eruption 2×2 phủ hero 14, ô CŨ lần hai sau
  ≥ 1 s với cảnh báo 1 s, 10, rồi cháy 2 s; hero rời đi thì lần hai trượt; `phase_shift` từ chapters.json cùng tick, 1 announce, vent ×0,7;
  8 dòng strings đúng 3 cột. **Kết quả: FAILS=2 (đúng 2 check on_enter ở trên), còn lại pass.**
- Fairness/dodge mở rộng lên 9 quái (máu đẩy xuống 45 % ở giây 30 cho Lord).
- Full suite 302 (`production/qa/monster-skill-hellfire-group-d-full-suite-2026-11-13.txt`, 10:54–11:28): **298 sạch, 4 không sạch** —
  `pattern_hellfire_group_d` FAILS=2 (lỗi on_enter, chờ duyệt); `terminology_scan` FAILS=1 ("runs", đã sửa, chạy lại FAILS=0);
  `pattern_roster_fairness` không in kết quả (chạy riêng FAILS=0 nhưng mất 278 s > timeout 240 s của runner khi máy bận → môi trường);
  `multi_enemy_resolver_test` FAILS=5 (suite mới của session multi-enemy, Phase 2 đang làm). Lượt targeted 10:08–10:54 có parse error
  vì session multi-enemy đang sửa `cut_effects.gd` / `zone_rules.gd` giữa chừng → kết quả lượt đó không dùng.
- Ảnh: `production/qa/evidence/monster-skill-hellfire/group-d/` (5 ảnh + README; pha 2 không thấy eruption, khớp lỗi on_enter).

### 11.1 Bản vá on_enter — đã áp (2026-11-13, người dùng duyệt)

- `src/combat/pattern_controller.gd` `_try_choose`: thêm nhánh `if not forced_queue_skill.is_empty(): forced = forced_queue_skill`,
  nhánh `every_nth` thành `elif`. Diff file trước bản vá +400/−10, sau +403/−11: chỉ đúng 3 dòng thêm, 1 dòng bỏ. Không đổi gì khác;
  `lord_eruption_call` giữ `weight: 0`.
- Kết quả (`production/qa/monster-skill-onenter-fix-2026-11-13.txt`): `pattern_hellfire_group_d_test` FAILS=0 (hai check on_enter
  PASS: warning đầu và cast đầu của p2 là eruption; eruption chỉ ở cast 1 / bội 3; không có ở p1); `forest_witch_phases_test`,
  `forest_witch_mechanics_test`, `forest_witch_fairness_test` FAILS=0 (root_anchor on_enter, forest_last_knot mỗi cast thứ 3);
  `pattern_controller_test` FAILS=0 (on_enter marker); nhóm A/B/C, 5 suite Phase 0, roster mechanics/dodge, variants/haste,
  pattern_dodge, hellfire fairness/dodge FAILS=0 — 19/19.
- Full suite (`monster-skill-onenter-fix-full-suite-2026-11-13.txt`, 13:18–13:51): **302 suite, 301 sạch, 1 không có kết quả**
  (`pattern_roster_fairness_test`, vượt timeout 240 s của runner); chạy lại riêng (timeout 900 s): **FAILS=0, 0 script error, 267 s**.
- `pattern_controller.gd` bàn giao cho session multi-enemy (ghi chú chung, 2026-11-13).

## 12. Các vấn đề còn mở — đã xử lý (2026-11-13, chưa commit)

- **Timeout runner:** `tools/qa/run_all_tests.sh` cho suite headless 600 s (trước 240 s; `pattern_roster_fairness_test` cần ~270 s
  khi máy bận). Suite bị cắt in thêm ` TIMEOUT` trên dòng của nó thay vì cột FAILS trống. Suite windowed giữ 240 s.
- **`big_hands` / `quick_blocks` trên quái pattern (§4.4):** thêm khoá `pattern_tempo_mult` vào `RegionRules.PATCH_MULT_KEYS` và
  vào phần `match` của hai modifier trong `assets/data/region_rules.json` (big_hands ×0,9, quick_blocks ×0,85). Phần block brain giữ
  nguyên (boss_min_runes +1 / boss_drop_interval ×0,85); `RunConfig` chỉ giữ `pattern_tempo_mult` cho trận `brain: pattern`. Chữ
  hiển thị đổi cho đúng cả hai brain ("Khối lớn hơn, niệm nhanh hơn" / "Khối rơi nhanh, hồi chiêu nhanh hơn"). Test mới
  `tests/unit/run/map_v2/pattern_modifiers_test.gd` FAILS=0; 6 suite map_v2 + terminology FAILS=0. Hàng Heat
  `boss_drop_interval_mult` vẫn trơ trên quái pattern (R6, không đổi trong Phase 1).
- **R11 — Devour nuốt cả lửa mạch phun:** session multi-enemy (chủ `pattern_controller.gd`) áp `_zone_fires()` — chỉ ô cháy có
  `zone_kind_at == KIND_BURN` (lửa do skill / lá bài) mới tính cho điều kiện `burning_cells` và cho `consume_burn`. Test nhóm C đổi
  thành `test_devour_skips_terrain_fire` (hàng mạch phun một mình không kích hoạt Devour, vẫn cháy sau khi nuốt; chỉ +6 HP mỗi ô lửa
  zone). Kết quả chạy riêng FAILS=0 (`production/qa/multi-enemy-phase3-r11-2026-11-13.txt`); full suite sau Phase 3 + R11:
  305/305 sạch, không timeout (`production/qa/multi-enemy-phase3-suite-2026-11-13.txt`).
- **Sim cân bằng nối Phase 0:** `tools/balance/sim_core.gd` truyền cho `PatternController` đúng các hook như `combat_view`
  (hazards, `player_blocked_fn`, reactions, `external_red_fn` từ cảnh báo trait, hook TraitHost, ctx `pattern_getter`).
- **Nhóm E (sim cân bằng):** `production/qa/evidence/monster-skill-hellfire/group-e/run-group-e.sh` — cùng cờ và seed với B1
  (5 nhân vật × set 2001/3001 × 70 seed, route value), một tiến trình Godot mỗi lúc; so sánh bằng `aggregate-e.py` (B1 → E).
  Kết quả: xem §12.1.

### 12.1 Kết quả nhóm E — B1 (block brain) → E (pattern brain), cùng seed (2026-11-13)

Bảng đầy đủ: `production/qa/evidence/monster-skill-hellfire/group-e/aggregate-e.md`. 10 job, exit 0; 2 script error ở job
kiem_si/2001 (lỗi `_skill` bị xoá giữa lúc resolve khi phản đòn đỡ, đã vá bởi multi-enemy sau job 7 — chỉ mất một emit
`skill_resolved`, sát thương vẫn tính; job 8–10 chạy trên code đã vá, số liệu tương đương).

| chỉ số (gộp 10 combo) | B1 | E | ngưỡng | kết luận |
|---|---|---|---|---|
| tỉ lệ thắng run | 13,3 % | 17,7 % | ±10 điểm | đạt (+4,4) |
| thắng — sat_thu | 7,8 % | 18,5 % | ±10 điểm | **vượt** (+10,7) |
| qua Hỏa Ngục (% run vào tầng 2) | 84,6 % | 100 % | — | **mất áp lực** (0 chết / 700 run) |
| HP mất trong trận / tuyến Hỏa Ngục | 63,4 | 15,2 | — | **−76 %** |
| HP sau warden (trước hồi) | 49,7 % | 85,1 % | — | **+35 điểm** |
| phút / run (mọi run) | 32,77 | 34,57 | ±2 % | **vượt** (+5,5 %, do sống lâu hơn) |
| vàng / run, relic / run | 616 / 10,5 | 702 / 11,9 | — | +14 % / +12 % (hệ quả) |
| heat ở warden (trung bình) | 1,48 | 1,55 | — | không đổi |

**Kết luận: nhóm E KHÔNG đạt.** Hỏa Ngục pattern dễ hơn hẳn Hỏa Ngục block: sát thương skill (6–14 mỗi đòn, ngang rừng tầng 1)
thấp hơn nhiều so với lá bài boss block ném ra, nên bot né 85 % gần như không mất máu. Không có núm sát thương cho quái
pattern (chỉ có `pattern_tempo_mult`). Lưu ý: rừng (pattern, tầng 1) cũng 100 % qua trong B1 → bot sim có thể lạc quan với
đòn có cảnh báo; nhưng chênh lệch so với chính B1 là rõ.

Cần người dùng chọn (chưa sửa gì): (a) tăng `effects.damage` của 17 skill Hỏa Ngục (data, ~×2–2,5, mục tiêu HP mất ~55–65 / tuyến)
rồi chạy lại nhóm E; (b) thêm núm `pattern_damage_mult` theo vùng (code nền, cần đề xuất riêng); (c) chấp nhận và để playtest
người thật quyết định.
