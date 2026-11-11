# Roster tầng — map và quái để thiết kế asset

**Ngày:** 2026-11-11. Số liệu lấy từ data đang chạy, không lấy từ bản brief cũ.

Nguồn:

- Thứ tự leo, pool, máu, trait: `assets/data/chapters.json`
- Tên tiếng Việt: `assets/i18n/strings.csv`
- Vùng art: `assets/art/regions.json`
- Cỡ sân: `assets/data/arenas.json` (`side_cols` × `side_rows` là **một nửa** sân)
- Công thức máu: `RunConfig._apply_scaling` — nhân `region_normalize` trước, rồi `floor_scaling`
- Không khí từng vùng: `design/art/region-visual-brief-2026-11-05.md`
- Palette, cỡ pixel, viền, luật render (dùng file này khi viết prompt gen): `docs/art/RENDER-STANDARDS.md`
- Pipeline asset: `docs/art/AI_GAME_ART_WORKFLOW_IMPLEMENTATION.md`, registry `design/assets/asset-registry.yaml`

Máu trong bảng quái là **máu gốc** trong `chapters.json`. Máu trong trận = gốc × `region_normalize.hp_mult` × `floor_scaling.hp_mult`.

`var` trên sân = shape được phép khoét thêm 1–3 ô (`arenas.json` `variant_change_min/max`).

Sheet = có `assets/art/units/unit_<id>_sheet.png`. Ngoài Rừng Sương, không vùng nào có sheet.

---

## Cách một run xếp tầng

Leo **7 tầng**, đúng thứ tự, từ dưới bản đồ leo lên. Hết tầng 7 là trận cuối, không phải một đảo leo.

| Tầng | Chapter id | Art region | Tên | Đảo leo | Env trận |
|---|---|---|---|---|---|
| 1 | `ch1` | `forest` | Rừng Sương | `island_ch1.png` | **đủ** `assets/art/env/forest/` |
| 2 | `hellfire` | `hellfire` | Thành Hỏa Ngục | `island_hellfire.png` | chưa — fallback dải màu, phiến rừng |
| 3 | `desert` | `sands` | Sa Mạc Cát Vùi | `island_desert.png` | chưa |
| 4 | `swamp` | `swamp` | Đầm Lầy Độc | `island_swamp.png` | chưa |
| 5 | `ch2` | `dungeon` | Hầm Ngục | `island_ch2.png` | chưa |
| 6 | `ch3` | `ice_tower` | Tháp Sương | `island_ch3.png` | chưa |
| 7 | `sky_isles` | `sky_isles` | Không Đảo | `island_sky_isles.png` | chưa |
| cuối | `an_dai` | `lattice_heart` | Tâm Lưới | không có đảo | chưa |

`world.region_order` = `ch1, hellfire, desert, swamp, ch2, ch3, sky_isles`. `final_match` = `an_dai` / `an_dai_keeper`, trước đó một shop (`final_prelude`).

Hồi máu khi rời tầng: `floor_heal_ratio` **0.6**.

### Cột node (giống nhau mọi tầng)

7 cột, `world.region_columns`. Tier pool lấy từ `floor_tiers`: `[cột đầu, cột giữa, cột boss]`.

| Cột | Số node | Loại | Bắt buộc |
|---|---|---|---|
| 1 | 1 | battle | |
| 2 | 3 | battle, danger từ tầng 2 | |
| 3 | 2–3 | battle, danger từ tầng 2 | 1 treasure |
| 4 | 2–3 | battle, danger | tầng 1: event. Từ tầng 2: 1 miniboss |
| 5 | 3 | battle, danger | 1 rest và (treasure hoặc battle) |
| 6 | 2–3 | battle, danger | cột đặc biệt: shop / event (`special_nodes.column` = 5). Tầng 1 có shop. Từ tầng 2 có 3 shop chắc trong cả run |
| 7 | 1 | boss | |

| Tầng | Tier cột đầu / giữa / boss | Pool quái thường | Elite | Boss |
|---|---|---|---|---|
| 1–3 | 0 / 1 / 1 | `battle` tier 0 ở cột 1, tier 1 ở cột giữa | chưa (miniboss `min_floor` 2). Cột 4 là event | `boss` tier 1 |
| 4–7 | 1 / 2 / 2 | `battle` tier 1 ở cột 1, tier 2 ở cột giữa | `miniboss` tier 2 | `boss` tier 2 |

Node `danger` được gắn thêm trait `row_burner` nếu quái chưa có trait đó (`defaults.danger_traits`).

### Hệ số tầng

`defense_add` và `size_add` cộng vào giáp và kích thước mảnh nhỏ nhất của quái. `step_mult` càng thấp thì quái bước càng nhanh.

| Tầng | hp | step | giáp + | size + |
|---|---|---|---|---|
| 1 | 0.70 | 1.00 | 0 | 0 |
| 2 | 0.75 | 0.97 | 0 | 0 |
| 3 | 0.80 | 0.95 | 0 | 0 |
| 4 | 0.85 | 0.90 | 1 | 0 |
| 5 | 0.95 | 0.87 | 1 | 0 |
| 6 | 1.05 | 0.84 | 1 | 0 |
| 7 | 1.15 | 0.80 | 2 | 1 |
| cuối | 1.25 | 0.80 | 2 | 1 |

Mỗi vùng còn nhân thêm `region_normalize` **trước** hệ số tầng. Cột “máu thực” = hai hệ số nhân với nhau, áp lên máu gốc trong bảng quái.

---

## Tầng 1 — Rừng Sương

- Art: `forest`. Env trận đã có (nền `bg_forest_far_v4`, phiến, stamp, gai, tường/cột/vòm/rễ/dương xỉ). Đảo leo có.
- Không khí: phế tích, sương thấp, rêu xám. Không lá tươi, không nắng. Brief §1.
- Normalize: máu ×0.75, bước ×1.05, giáp +0. **Máu thực trên tầng này ×0.525.**
- Sân gặp trong pool: square 3×3, rect 4×3, u_shape 4×3, cross 4×4, boss_hall 6×4.

| Id | Tên | Vai | Máu gốc | Sân | Trait riêng | Sheet |
|---|---|---|---|---|---|---|
| `goblin_scout` | Goblin trinh sát | battle t0 | 170 | square | | có |
| `rootling` | Rễ Con | battle t0–1 | 190 | square | | có |
| `mossbound_sentry` | Lính Gác Rêu | battle t0–2, danger t2 | 250 | rect | | có |
| `greycap_sporeling` | Nấm Mũ Xám | battle t1–2, danger t1 | 220 | u_shape var | | có |
| `goblin_archer` | Goblin cung thủ | battle t1–2, danger t1–2 | 200 | rect | | có |
| `dire_wolf` | Sói dữ | battle t1–2, danger t1–2 | 240 | rect | | có |
| `wolf_alpha` | Sói đầu đàn | miniboss t1–2 | 440 | rect | | có |
| `ancient_root_sentinel` | Vệ Binh Rễ Cổ | miniboss t1–2 | 420 | rect | | có |
| `mistbriar_matron` | Mẹ Gai Sương | miniboss t2 | 400 | cross var | | có |
| `goblin_warlock` | Goblin vu sư | boss t1 | 760 | boss_hall | | có |
| `forest_witch` | Phù thủy rừng | boss t2 | 1090 | boss_hall | | có |

Tầng 1 chỉ rút battle t0 và boss t1: trinh sát, Rễ Con, Lính Gác Rêu, rồi Goblin vu sư. Elite và Phù thủy rừng xuất hiện khi vùng này được gắn vào tầng 4+ — với thứ tự leo hiện tại, Rừng Sương **chỉ đứng ở tầng 1**, nên `mistbriar_matron`, `wolf_alpha`, `ancient_root_sentinel`, `forest_witch` có sheet nhưng **không ra trong run thường**.

Có data, **không nằm pool nào** (đừng gen trừ khi đưa lại vào pool): `wolf` Sói xám 108 square, `goblin_chief` Thủ lĩnh Goblin 130 square `row_burner`, `goblin_warrior` Goblin chiến binh 97 rect, `goblin_shaman` Goblin pháp sư 140 rect, `goblin_brute` Goblin lực sĩ 130 u_shape var. Không có sheet.

Kẻ Gác để vẽ nếu sau này boss t2 được dùng: Phù thủy rừng — mặt nạ mỏ chim, sừng hươu, áo lá rách (`08-warden-forest-01.png`, chỉ lấy bố cục).

---

## Tầng 2 — Thành Hỏa Ngục

- Art: `hellfire`. Env trận chưa có. Fallback trời `#3A3236` / đất `#1F1B1D`. Đảo leo có.
- Không khí: than, tháp nhọn, xích. Dung nham chỉ trong khe. Không cam sáng trên nền (cam là trạng thái Cháy). Brief §6.
- Normalize: máu ×0.75, bước ×1.05. **Máu thực ×0.5625.**
- Sân: forge 5×3 (mạch lửa theo hàng), caldera 5×5 (mạch theo cột, khuyết 3 ô).

| Id | Tên | Vai | Máu gốc | Sân | Trait riêng | Sheet |
|---|---|---|---|---|---|---|
| `imp` | Tiểu Quỷ | battle t0–1 | 92 | forge | | không |
| `ember_hound` | Chó Than Hồng | battle t0–1 | 110 | caldera | | không |
| `ash_golem` | Khôi Tro | battle t1–2, danger t1 | 132 | forge | | không |
| `flame_cultist` | Tín Đồ Lửa | battle t1–2, danger t1–2 | 128 | caldera | `row_burner` | không |
| `magma_slug` | Sên Dung Nham | battle t2, danger t1–2 | 140 | forge | | không |
| `hell_knight` | Hiệp Sĩ Địa Ngục | battle t2, danger t2 | 156 | caldera | | không |
| `fire_eater` | Quỷ Nuốt Lửa | miniboss t1–2 | 90 | forge | `burn_eater` | không |
| `ash_phoenix` | Phượng Tro | miniboss t1–2 | 74 | caldera | `rebirth` | không |
| `inferno_lord` | Chúa Quỷ Lửa | boss t1 và t2 | 180 | caldera | `vent_surge`, `phase_shift` | không |

Tầng 2 dùng battle t0 ở cột 1, battle/danger t1 ở giữa, boss t1. Elite (`min_floor` 2) **có** từ tầng này: Quỷ Nuốt Lửa, Phượng Tro. Boss t1 và t2 là cùng một id.

Kẻ Gác: Chúa Quỷ Lửa — giáp phiến than, sừng đồng, ngực nứt ochre, áo cháy xém. Bỏ vân dung nham cam khắp thân.

Registry backlog: `unit.hellfire.roster`.

---

## Tầng 3 — Sa Mạc Cát Vùi

- Art: `sands` (chapter id vẫn là `desert`). Env chưa có. Fallback trời `#B8A888` / đất `#6E6248`. Nền sáng, quái cần mảng tối. Đảo leo có.
- Không khí: cát bụi, tàn tích vòm, vết ngọc `#4F8A80`. Không vẽ sẵn cát phủ kín phiến (ô cát lấp là luật chơi). Brief §5.
- Normalize: máu ×0.75, bước ×1.05. **Máu thực ×0.60.**
- Sân: dunes 5×4 (gió + cát), oasis 5×5 (gió + cát, khuyết tâm).

| Id | Tên | Vai | Máu gốc | Sân | Trait riêng | Sheet |
|---|---|---|---|---|---|---|
| `dune_jackal` | Chó Rừng Cồn | battle t0–1 | 90 | dunes | | không |
| `sand_beetle` | Bọ Cát | battle t0–1 | 106 | dunes | | không |
| `dust_nomad` | Du Mục Bụi | battle t1–2, danger t1 | 116 | oasis | | không |
| `mirage_sprite` | Bóng Ảo Ảnh | battle t1–2, danger t1–2 | 124 | dunes var | | không |
| `scarab_guard` | Vệ Binh Bọ Hung | battle t2, danger t1–2 | 140 | oasis var | | không |
| `sun_archer` | Xạ Thủ Mặt Trời | battle t2, danger t2 | 152 | dunes var | `row_burner` | không |
| `sand_burrower` | Bọ Cát Ẩn | miniboss t1–2 | 84 | dunes | `burrow` | không |
| `scorpion` | Bọ Cạp Phản | miniboss t1–2 | 96 | oasis | `riposte` | không |
| `sand_sphinx` | Nhân Sư Cát | boss t1 và t2 | 175 | oasis var | `sandstorm` | không |

Tầng 3 vẫn tier 0/1/1. `scarab_guard` và `sun_archer` là battle t2 — **chưa ra** ở tầng này. Elite t1 thì có: Bọ Cát Ẩn, Bọ Cạp Phản.

Kẻ Gác: Nhân Sư Cát — ngồi thẳng, đầu người đội sừng, đai ochre, cánh đá gập.

Registry backlog: `unit.sands.roster`.

---

## Tầng 4 — Đầm Lầy Độc

- Art: `swamp`. Env chưa có. Fallback trời `#6B705A` / đất `#353A2C`. Đảo leo có.
- Không khí: bùn, lau, nấm `#6A5868`. Ô lầy là luật chơi (phiến chìm, bọt). Brief §4.
- Normalize: máu ×0.75, bước ×1.05. **Máu thực ×0.6375.** Giáp tầng +1.
- Sân: bog 5×3 (lầy 4/nửa), reed_maze 5×5 (lầy 3/nửa).

| Id | Tên | Vai | Máu gốc | Sân | Trait riêng | Sheet |
|---|---|---|---|---|---|---|
| `bog_rat` | Chuột Lầy | battle t0–1 | 88 | bog | | không |
| `mire_slug` | Sên Bùn | battle t0–1 | 104 | bog | | không |
| `swamp_lizard` | Thằn Lằn Đầm | battle t1–2, danger t1 | 112 | reed_maze | | không |
| `marsh_toad` | Cóc Đầm | battle t1–2, danger t1–2 | 126 | bog var | | không |
| `reed_witch` | Phù Thủy Lau Sậy | battle t2, danger t1–2 | 138 | reed_maze var | `rotten_thrower` | không |
| `bog_hound` | Chó Săn Đầm | battle t2, danger t2 | 150 | bog var | `row_burner` | không |
| `spore_cap` | Nấm Bào Tử | miniboss t1–2 | 70 | bog | `spore_burst` | không |
| `leap_frog` | Ếch Nhảy | miniboss t1–2 | 80 | reed_maze | `hop_skip` | không |
| `toad_matriarch` | Cóc Chúa | boss t1 và t2 | 170 | bog var | `bog_spread`, `seal_caster` | không |

Tầng 4 chuyển tier 1/2/2. Cột 1 rút battle t1 (không còn chỉ chuột/sên). Elite t2 và boss t2 cùng id với t1.

Kẻ Gác: Cóc Chúa — thấp, rộng, 3–4 nấm xám-tím trên đầu, rêu nhỏ giọt.

Registry backlog: `unit.swamp.roster`.

---

## Tầng 5 — Hầm Ngục

- Art: `dungeon` (chapter id `ch2`). Env chưa có. Fallback trời `#4A4440` / đất `#2C2826`. Nền tối, không chân trời. Đảo leo có.
- Không khí: vòm, cột, xích. Đuốc là mảng ochre tĩnh, không phát sáng. Brief §2.
- Normalize: máu ×0.85, bước ×1.05, giáp gốc một số quái đã có 2. **Máu thực ×0.8075.** Giáp tầng +1.
- Sân: square 3×3, rect 4×3, cross 4×4, u_shape 4×3, staircase 4×4, ring 6×5.

| Id | Tên | Vai | Máu gốc | Sân | Trait riêng | Sheet |
|---|---|---|---|---|---|---|
| `skeleton` | Bộ xương lính | battle t0 | 92 | square | | không |
| `zombie` | Xác sống | battle t0–1 | 104 | rect | | không |
| `bat_swarm` | Đàn dơi hầm | battle t1–2, danger t1 | 115 | cross var | | không |
| `slime` | Nhầy ngục | battle t1–2, danger t1–2 | 138 | u_shape var | | không |
| `ghost` | Bóng Ma | battle t1, danger t1 | 24 | rect | | không |
| `reacter` | Kẻ Phản Ứng | battle t1–2, danger t1–2 | 70 | cross | `step_reactor` | không |
| `cultist` | Tín đồ tà giáo | battle t2, danger t2 | 150 | staircase var | | không |
| `rat_king_guard` | Lính gác Chuột Vương | battle t2, danger t2 | 161 | ring var | `row_burner` | không |
| `jailer` | Cai Ngục | miniboss t1–2 | 77 | u_shape var | `rotten_thrower`, `row_burner`, `seal_caster` | không |
| `ogre_king` | Quỷ Khổng Lồ | boss t1 và t2 | 132 | ring var | `slam` | không |

Tầng 5 tier 1/2/2. `skeleton` chỉ ở battle t0 — **không ra** ở tầng này.

Kẻ Gác: Quỷ Khổng Lồ — đá xám, vai rộng, đầu nhỏ, vương miện và râu ngà, xích gỉ `#8A6A40`.

Registry backlog: `unit.dungeon.roster`.

---

## Tầng 6 — Tháp Sương

- Art: `ice_tower` (chapter id `ch3`). Env chưa có. Fallback trời `#8E95B8` / đất `#4C5069`. Phiến vẫn tối. Không tinh thể cyan (trùng Đóng Băng). Đảo leo có.
- Không khí: biển mây, tháp xa, lan can. Brief §3.
- Normalize: máu ×0.75, bước ×1.10, giáp vùng −1 rồi giáp tầng +1 → giáp cộng **0** nếu quái không có giáp sẵn. **Máu thực ×0.7875.**
- Sân: square 3×3, rect 4×3, cross_wide 5×5, pillars 5×5, diamond 5×5, staircase 4×4.

| Id | Tên | Vai | Máu gốc | Sân | Trait riêng | Sheet |
|---|---|---|---|---|---|---|
| `frost_sprite` | Tiên sương | battle t0 | 106 | square | | không |
| `wisp` | Ma trơi | battle t0–1 | 120 | rect | | không |
| `stone_sentry` | Lính canh đá | battle t1–2, danger t1 | 132 | cross_wide | | không |
| `snow_wolf` | Sói tuyết | battle t1–2, danger t1 | 159 | pillars | | không |
| `fuse_golem` | Pháo Ngòi | battle t1–2, danger t1–2 | 110 | rect | `fuse_cannon` | không |
| `rime_archer` | Cung thủ sương giá | battle t2, danger t2 | 172 | staircase var | | không |
| `ice_golem` | Người băng | battle t2, danger t2 | 185 | diamond var | `row_burner` | không |
| `ghost_elite` | Bóng Ma bản mạnh | battle t2, danger t2 | 36 | cross_wide | | không |
| `frost_mage` | Pháp Sư Sương | miniboss t1–2 | 92 | diamond var | `frost_aura`, `thorn_field` | không |
| `mist_lord` | Chúa Tể Băng Giá | boss t1 và t2 | 139 | pillars | `frost_aura`, `phase_shift` | không |

Tầng 6 tier 1/2/2. `frost_sprite` (chỉ t0) **không ra**.

Kẻ Gác: Chúa Tể Băng Giá — cao, hẹp, áo xanh đêm, cổ lông ngà, vương miện gai băng, mũ không mặt.

Registry backlog: `unit.ice_tower.roster`.

---

## Tầng 7 — Không Đảo

- Art: `sky_isles`. Env chưa có. Fallback trời `#B9BFC8` / đất `#6A7080`. Nền xa sáng. Đảo leo có.
- Không khí: biển mây, đảo đá nâng, vạch sét tĩnh. Ô sắp rơi là luật chơi (`crumble` trên twin/three isles). Brief §7.
- Normalize: máu ×0.45, bước ×1.05. **Máu thực ×0.5175.** Giáp tầng +2, size +1.
- Sân: twin_isles 6×3, three_isles 7×2, islands_bridge 6×3. Hai sân đầu `crumble: true`.

| Id | Tên | Vai | Máu gốc | Sân | Trait riêng | Sheet |
|---|---|---|---|---|---|---|
| `cloud_sprite` | Tinh Mây | battle t0–1 | 88 | twin_isles | | không |
| `harpy` | Điểu Nữ | battle t0–1 | 104 | three_isles | | không |
| `wind_monk` | Võ Tăng Gió | battle t1–2, danger t1 | 118 | islands_bridge | | không |
| `storm_eagle` | Đại Bàng Bão | battle t1–2, danger t1–2 | 126 | twin_isles | | không |
| `sky_sentinel` | Lính Gác Trời | battle t2, danger t1–2 | 144 | three_isles | | không |
| `thunder_shaman` | Pháp Sư Sấm | battle t2, danger t2 | 150 | islands_bridge | `row_burner` | không |
| `gale_bird` | Chim Gió | miniboss t1–2 | 86 | twin_isles | `gust` | không |
| `cloud_veil` | Thần Mây | miniboss t1–2 | 96 | three_isles | `shroud` | không |
| `storm_dragon` | Long Vương Gió | boss t1 và t2 | 185 | islands_bridge | `island_drop`, `gust` | không |

Tầng 7 tier 1/2/2, nên Tinh Mây và Điểu Nữ (có t1) vẫn ra ở cột 1.

Kẻ Gác: Long Vương Gió — rồng chữ S, hai sừng ngà, cánh gập, mây ở chân.

Registry backlog: `unit.sky_isles.roster`.

---

## Trận cuối — Tâm Lưới

Không phải tầng 8 trên bản đồ leo. Sau shop prelude.

- Art: `lattice_heart`. Env chưa có. Fallback trời `#15142A` / đất `#0E0D1C`. Không chân trời, lưới vàng mảnh. Brief §8.
- Normalize: không khai (×1). **Máu thực ×1.25.** Giáp +2, size +1.
- Một trận: `an_dai_keeper` Người Giữ Tâm Lưới, máu gốc 198, sân `an_dai_dais` 5×5 (bốn góc và tâm khuyết). Không sheet.
- Pha 1: `seal_caster` (được khóa ô người chơi), não balanced, đứng yên khi vung.
- Pha 2 ở 50% máu: thêm `row_burner`, não aggressive, dừng 1.0s khi chuyển pha.
- Khung trùm trong brief: 48×64, áo thụng ngà-xám, mũ trùm mặt trống, một tay mở.

Registry backlog: `unit.lattice_heart.roster`.

---

## Việc asset còn thiếu, theo vùng

Mỗi vùng chưa có env cần cùng một bộ, Rừng Sương là mẫu đang chạy (`assets/art/env/forest/region.json`):

1. Nền 800×360 (xa) + lớp trôi nếu vùng có sương/mây/cát.
2. Phiến 16×16 nine-slice + stamp + màu bệ `platform`.
3. Tile ô đặc biệt của vùng nếu luật có (gai, lầy, cát lấp, mạch lửa, ô rơi).
4. Đồ lề (cột, tường, vòm) nếu muốn ngang tầm rừng. Đảo leo 320×192 **đã có** cho 7 vùng; Tâm Lưới không dùng đảo.

Quái cần sheet: mọi id cột “không” ở trên, trừ các id Rừng Sương đã có. Đừng gen 5 goblin/sói xám không nằm pool nếu chưa quyết đưa chúng lại.

Ảnh `design/art/reference/07-<vùng>-01.png` và `08-warden-<vùng>-01.png` chỉ để lấy bố cục. Brief ghi rõ phần nào của ảnh đó là sai (đuốc sáng, tinh thể cyan, cát phủ sẵn, thác dung nham).
