# World Map v2 — Asset hình ảnh quái theo vùng, cả 7 vùng (báo cáo tiến độ)

Bắt đầu 2026-11-13 (side session, chạy song song với session "arena surfaces / environment" trong cùng checkout).
Phạm vi: **chỉ asset hình ảnh của quái và tích hợp** — không đổi gameplay, roster, id, pool, chỉ số, AI, drop, save.
Không commit, không push, không deploy. Quy tắc tiếp tục: đọc file này rồi `git status`; không bao giờ bỏ việc đang có.

Nguồn sự thật: `assets/data/chapters.json` (roster + pool), `assets/i18n/strings.csv` (tên), `docs/art/FLOOR-MAP-ROSTER.md`
(bảng roster 2026-11-11), `docs/design/world-map-v2/02-region-design.md` (bản sắc vùng), `design/art/art-bible.md` §5.2–5.6 / §8.3 / §8.6,
`docs/art/RENDER-STANDARDS.md` §4, `docs/art/REGION-MATERIALS-AND-PALETTE.md`, `design/art/region-visual-brief-2026-11-05.md`,
`design/assets/specs/misty-forest-roster-assets.md` (pipeline mẫu đã duyệt), `design/assets/references/characters/*.md`.

---

## 1. Kiểm kê roster hiện có (2026-11-13) — KHÔNG thêm, KHÔNG bớt, KHÔNG đổi

Đếm từ `chapters.json`: **73 match id** trong 8 chapter (7 vùng leo + trận cuối). Trong pool đang chạy: **63** (5 id Rừng Sương là
orphan, không nằm pool nào). Có sheet: **11**, tất cả Rừng Sương. **52 id trong pool của 6 vùng còn lại + Người Giữ Tâm Lưới (1) = 53 id
chưa có bất kỳ sprite nào** — trong trận vẽ bằng ô đỏ placeholder (`UnitLayer._draw_enemy`, màu `ENEMY_COLOR` 0.7/0.3/0.3, số máu ở giữa).

Cỡ khung đang dùng (bible §8.3, trên đĩa): quái thường **64×52** (sói 68×52 vì đuôi), Tinh Anh **80×80**, Kẻ Gác 2×2 160×130.
Clip bắt buộc cho quái (bible §5.4/§8.6, `roster_sprite_test`): `idle`, `step`, `windup`, `hit`, `down`; clip đặc tính (`brace`,
`guard`, `stunned`, `howl`, `windup_heavy`, `phase_shift`) **chỉ được code gọi cho não pattern** (`CTX_GUARDING/STUNNED/HOWLING/HEAVY/PHASE`
đều lấy từ `PatternController`). Mọi quái 6 vùng còn lại chạy não khối (`BossController`), nên bộ 5 clip là đủ; không bịa trạng thái.

| Vùng (chapter → art) | Quái hiện có (id · tên VI · vai) | Trạng thái asset | Thiếu | Việc đề xuất |
|---|---|---|---|---|
| **Rừng Sương** (`ch1` → `forest`) | Pool: `goblin_scout` Goblin trinh sát B0 · `rootling` Rễ Con B0–1 · `mossbound_sentry` Lính Gác Rêu B0–2 · `greycap_sporeling` Nấm Mũ Xám B1–2 · `goblin_archer` Goblin cung thủ B1–2 · `dire_wolf` Sói Hoang B1–2 · `ancient_root_sentinel` Lính Gác Rễ Cổ E · `mistbriar_matron` Mẹ Gai Sương E · `wolf_alpha` Sói Đầu Đàn E · `goblin_warlock` Goblin vu sư Boss t1 · `forest_witch` Phù thủy rừng Boss t2. Orphan (không pool): `wolf`, `goblin_chief`, `goblin_warrior`, `goblin_shaman`, `goblin_brute` | **11/11 pool có sheet, đã duyệt** (registry `approved`), 5 clip + clip đặc tính (brace/guard/stunned/howl/windup_heavy/phase_shift). 5 orphan không sheet | Không thiếu gì cho pool. Orphan: theo FLOOR-MAP-ROSTER "đừng gen trừ khi đưa lại vào pool" | Giữ nguyên (visual đã duyệt). Chỉ đối chiếu lại trên sân v2 (§8) |
| **Thành Hỏa Ngục** (`hellfire`) | `imp` Tiểu Quỷ B0–1 · `ember_hound` Chó Than Hồng B0–1 · `ash_golem` Khôi Tro B1–2 D1 · `flame_cultist` Tín Đồ Lửa B1–2 D1–2 (`row_burner`) · `magma_slug` Sên Dung Nham B2 D1–2 · `hell_knight` Hiệp Sĩ Địa Ngục B2 D2 · `fire_eater` Quỷ Nuốt Lửa E (`burn_eater`) · `ash_phoenix` Phượng Tro E (`rebirth`) · `inferno_lord` Chúa Quỷ Lửa Boss (`vent_surge`, `phase_shift`) | **0/9** — placeholder ô đỏ | 9 thân + 45 clip | Gen 6 thường 64×52, 2 Tinh Anh 80×80, 1 Kẻ Gác 1 ô (khung đề xuất §7.3) |
| **Sa Mạc Cát Vùi** (`desert` → `sands`) | `dune_jackal` Chó Rừng Cồn B0–1 · `sand_beetle` Bọ Cát B0–1 · `dust_nomad` Du Mục Bụi B1–2 D1 · `mirage_sprite` Bóng Ảo Ảnh B1–2 D1–2 · `scarab_guard` Vệ Binh Bọ Hung B2 D1–2 · `sun_archer` Xạ Thủ Mặt Trời B2 D2 (`row_burner`) · `sand_burrower` Bọ Cát Ẩn E (`burrow`) · `scorpion` Bọ Cạp Phản E (`riposte`) · `sand_sphinx` Nhân Sư Cát Boss (`sandstorm`) | **0/9** | 9 thân + 45 clip | như trên |
| **Đầm Lầy Độc** (`swamp`) | `bog_rat` Chuột Lầy B0–1 · `mire_slug` Sên Bùn B0–1 · `swamp_lizard` Thằn Lằn Đầm B1–2 D1 · `marsh_toad` Cóc Đầm B1–2 D1–2 · `reed_witch` Phù Thủy Lau Sậy B2 D1–2 (`rotten_thrower`) · `bog_hound` Chó Săn Đầm B2 D2 (`row_burner`) · `spore_cap` Nấm Bào Tử E (`spore_burst`) · `leap_frog` Ếch Nhảy E (`hop_skip`) · `toad_matriarch` Cóc Chúa Boss (`bog_spread`, `seal_caster`) | **0/9** | 9 thân + 45 clip | như trên |
| **Hầm Ngục** (`ch2` → `dungeon`) | `skeleton` Bộ xương lính B0 · `zombie` Xác sống B0–1 · `bat_swarm` Đàn dơi hầm B1–2 D1 · `slime` Nhầy ngục B1–2 D1–2 · `ghost` Bóng Ma B1 D1 · `reacter` Kẻ Phản Ứng B1–2 D1–2 (`step_reactor`) · `cultist` Tín đồ tà giáo B2 D2 · `rat_king_guard` Lính gác Chuột Vương B2 D2 (`row_burner`) · `jailer` Cai Ngục E (`rotten_thrower`, `row_burner`, `seal_caster`) · `ogre_king` Quỷ Khổng Lồ Boss (`slam`) | **0/10** | 10 thân + 50 clip | 8 thường, 1 Tinh Anh, 1 Kẻ Gác |
| **Tháp Sương / Băng** (`ch3` → `ice_tower`) | `frost_sprite` Tiên sương B0 · `wisp` Ma trơi B0–1 · `stone_sentry` Lính canh đá B1–2 D1 · `snow_wolf` Sói tuyết B1–2 D1 · `fuse_golem` Pháo Ngòi B1–2 D1–2 (`fuse_cannon`) · `rime_archer` Cung thủ sương giá B2 D2 · `ice_golem` Người băng B2 D2 (`row_burner`) · `ghost_elite` Bóng Ma bản mạnh B2 D2 · `frost_mage` Pháp Sư Sương E (`frost_aura`, `thorn_field`) · `mist_lord` Chúa Tể Băng Giá Boss (`frost_aura`, `phase_shift`) | **0/10** | 10 thân + 50 clip (`ghost_elite` có thể là biến thể script của `ghost`, bible §5.6 — xem §3.6) | 8 thường, 1 Tinh Anh, 1 Kẻ Gác |
| **Không Đảo** (`sky_isles`) | `cloud_sprite` Tinh Mây B0–1 · `harpy` Điểu Nữ B0–1 · `wind_monk` Võ Tăng Gió B1–2 D1 · `storm_eagle` Đại Bàng Bão B1–2 D1–2 · `sky_sentinel` Lính Gác Trời B2 D1–2 · `thunder_shaman` Pháp Sư Sấm B2 D2 (`row_burner`) · `gale_bird` Chim Gió E (`gust`) · `cloud_veil` Thần Mây E (`shroud`) · `storm_dragon` Long Vương Gió Boss (`island_drop`, `gust`) | **0/9** | 9 thân + 45 clip | 6 thường, 2 Tinh Anh, 1 Kẻ Gác |
| *(trận cuối, ngoài 7 vùng)* **Tâm Lưới** (`an_dai` → `lattice_heart`) | `an_dai_keeper` Người Giữ Tâm Lưới (2 pha, `seal_caster` → +`row_burner`) | **0/1** | 1 thân + 5 clip | Ghi nhận; làm sau 7 vùng nếu người dùng muốn |

Ký hiệu vai: B = pool `battle` tier, D = `danger`, E = `miniboss` (Tinh Anh), Boss = `boss` (Kẻ Gác). Lấy đúng từ `pools` của
`chapters.json`; không có "cấp" riêng trên match, cấp suy từ pool và được bible §5.2 đặt tên (quái thường / Tinh Anh / Kẻ Gác).

**Kết luận kiểm kê:** việc thực là **sản xuất 52 thân mới + 260 clip** (6 vùng) rồi tích hợp; Rừng Sương chỉ cần kiểm tra lại
trên sân mới. Không có "con nào nửa chừng" ngoài rừng: không có candidate, không có reference, không có hex màu được phép
(REGION-MATERIALS: "Không có dòng màu cho quái Hầm Ngục, Tháp, Đầm, Sa Mạc, Hỏa Ngục, Không Đảo, Tâm Lưới … chưa được phép gán hex").

## 2. Audit asset hình ảnh hiện tại

### 2.1 Đường đi từ dữ liệu tới màn hình (đã kiểm trong code)

| Mắt xích | Ở đâu | Phát hiện |
|---|---|---|
| Id sprite của địch | `UnitLayer.unit_ids_for` → `match_params.id` = match id của `chapters.json` | Không cần map mới; tên file `assets/art/units/unit_<match id>_sheet.png/.json` là đủ để con quái hiện ra |
| Nạp sheet | `SpriteSheet.load_unit(id)` → null nếu thiếu → placeholder | Fallback an toàn, không crash; 53 con đang ở nhánh này |
| Clip được gọi | `UnitLayer.clip_for` (ưu tiên down > hit > windup > step > idle; cộng clip đặc tính chỉ với não pattern) | **Bộ 5 clip là trọn vẹn cho mọi quái não khối.** `phase_shift` của `inferno_lord`/`mist_lord` là trait combat, code không bao giờ yêu cầu clip `phase_shift` cho não khối → không gen |
| Hướng nhìn | địch quay trái; sheet `facing: left` (PixelLab south-west) | như rừng |
| Neo chân | giữa đáy khung, chân chạm hàng cuối, FEET_DEPTH_RATIO 0.5 (tâm ô) | mọi khung kể cả con bay/lơ lửng phải có pixel thấp nhất ở hàng cuối (đuôi mây / bóng khói) để đứng đúng tâm ô |
| Lớp trạng thái (Cháy / Đóng Băng / Giá Lạnh) | `StatusPacks` theo `frame_kind` = `goblin` cho mọi địch | Pack dựng quanh thân ~26×46; dùng được cho thường và Tinh Anh; Kẻ Gác 1 ô cao ~80 px sẽ hơi nhỏ — ghi nhận ở §11, không sửa trong task này |
| Cỡ sân | ô thật 38×27 … 64×46 art px; `size_add` tầng 7 / final = +1 chỉ là số ô sân, không phóng sprite | sprite không bao giờ co giãn (bible §8.6), nên kích thước thân phải đọc được từ cỡ ô nhỏ nhất của vùng |
| Xuất sheet | `tools/asset-pipeline/export_sheets.py` | **Từ chối pixel đục ngoài `tessera_master.gpl` (47 màu)** → trước khi cài con đầu tiên của vùng, `.gpl` phải có màu vùng (§7.2) |
| Test | `roster_sprite_test` (5 clip + facing + Tinh Anh cao hơn thường ≥ 12 px), `sheet_export_test`, `sprite_sheet_test`, `export_sheets.py --check` | Thêm id mới vào `roster_sprite_test.ROSTER/NORMALS/ELITES` theo vùng khi cài (test, không phải gameplay) |

### 2.2 Chất lượng 11 sheet Rừng Sương trên sân v2 của session anh em

Ảnh `region-visuals/13-forest-c0-control.png`, `arena-integration/37-forest-c0-v2.png`: Goblin trinh sát đứng tâm ô, vòng báo
đòn và số máu đọc rõ, viền Mực tách khỏi phiến xám-rêu; sân rừng không đổi trong việc arena surfaces (session anh em ghi
"Forest untouched"). **Không có gì phải sửa ở rừng.** Các clip rừng đã ghi "accepted/approved" trong registry; điểm mở ghi sẵn
trong reference (vd. Greycap `windup` đỏ → đã snap tím xám) giữ nguyên.

### 2.3 Cách placeholder đang đọc trên 6 sân mới (ảnh của session anh em, 2026-11-12)

`arena-integration/420-all-seven-arenas.png`, `region-visuals/31–42`: ô đỏ + số máu nổi trên mọi sân. Nền đã có bản sắc riêng
(pháo đài than + xích; cồn cát + vòm; nước đen + cây chết; tường ngục + song sắt; biển mây + tháp; đảo trôi + sét). Mức sáng nền
đo bằng mắt theo brief §0.3: Hỏa Ngục / Hầm Ngục / Đầm = **tối** (quái cần mảng sáng Ngà / Đá sáng ở nửa trên); Sa Mạc / Tháp /
Không Đảo = **sáng** (quái cần mảng tối Mực / Đá đêm ở nửa trên). Điều này quyết định bảng màu từng vùng ở §3.

## 3. Bảy hướng art quái, độc lập theo vùng (từ nguồn đã duyệt; là hướng hình ảnh, không phải bản sắc gameplay mới)

Luật chung mọi vùng (bible §5.2/§5.3/§5.5, RENDER §4): viền Mực 1 px kín, không viền màu phe; địch **không có màu nhấn khối**,
S 30–45 %, màu vùng + Đá/Sương/Ngà; dấu loài ở **nửa trên**; mắt 2×2; không đỏ `#E5293B`, không cam Cháy `#FF7A1F`, không vàng Ánh
Lưới `#FFD45C` trên thân; không glow, không gradient mượt, không dither trên đơn vị. Thường ≤ ~47 px cao, Tinh Anh ≥ thường + 12 px
(test), Kẻ Gác cao hơn Tinh Anh ≥ 12 px nữa (đề xuất §7.3). Hình thể trong một vùng phải **khác nhau về lớp bóng đen**: mỗi vùng
có ít nhất 4 trong 6 lớp {bốn chân thấp · hai chân nhỏ · hai chân cao / mang giáp · khối tròn/nhầy · bay/lơ lửng · cấu trúc/công trình}.

| Vùng | Ngôn ngữ sinh vật | Bóng đen & tỉ lệ | Chất liệu | Bảng màu (dùng chung + ≤ 3 màu vùng, đề xuất §7.2) | Thích nghi môi trường / dấu hiệu riêng | Quan hệ với kiến trúc sân |
|---|---|---|---|---|---|---|
| **Hỏa Ngục** | lò nung của pháo đài: sinh vật than, giáp phiến than, tín đồ của lửa | góc cạnh, gai, sừng; vai rộng; dáng rướn tới | than nứt, obsidian mờ, đồng tối, vải cháy xém, tro | Ink; Ngà (răng, sừng); Đá tối `#2C2925/#4A4640`; **than `#24201E`**, **đồng tối `#7A5A36`**, **ochre đục `#8A6A40`** (chia với Hầm Ngục). Dung nham chỉ là **khe nứt ≤ 2 px bằng ochre**, không cam | nhiệt làm mọi thứ co lại, nứt; **không** vân cam khắp thân, **không** mắt cam (RENDER §4 "Không") — nhiệt đọc qua vết nứt tối + tro | giáp phiến = tường slab obsidian; xích = xích trên nền; nửa trên sáng hơn nền ≤ 25 V |
| **Sa Mạc** | sinh vật vùi cát và di sản tàn tích: bọ, chó rừng, người du mục, tượng đá cổ | thấp, dài, bò sát; vỏ cứng; vải trùm; dáng ngồi của tượng | sa thạch mòn, kitin cát, vải bạc màu, ngọc đục | Ink; Ngà; **be cát `#A89A80`**, **be tối `#6E6248`**, **ngọc đục `#4F8A80`**; Hunter cloak `#5E6150/#7E8068` cho vải | cát phủ lưng, mép mòn tròn, **mảng tối lớn** nửa trên (nền sáng V 60–72) | vỏ/giáp cùng chất sa thạch với phiến; ngọc đục = bình ngọc trong nền |
| **Đầm Lầy** | sinh vật lưỡng cư, nhầy, mục rữa và phù thủy lau sậy | tròn, ướt, phình; thấp; chi dài mảnh (ếch, thằn lằn) | bùn, da ướt, rong, nấm `#6A5868`, giáp mục | Ink; Ngà; Rêu `#3A4538/#4A5545/#5E6B55`; Nấm `#4A3E4A/#6A5868/#8E8296`; **ô-liu `#4E4C3C`**, **bùn `#5A4A3A`** | giọt nước / rong bám (1–2 px, tĩnh trong sheet; code không thêm), bụng sáng Ngà để tách nền tối | nấm trên đầu = nấm ở lề; rễ = rễ mép sân |
| **Hầm Ngục** | người gác ngục chết, xác, nhầy, tín đồ, lính chuột: cũ, nặng, xích | nặng ở vai, đầu nhỏ; đứng thẳng cứng; khối nhầy; đàn dơi | xương Ngà xỉn, giáp sắt gỉ, xích ochre, vải mốc, nhầy mờ | Ink; Ngà; Đá `#2C2925/#4A4640/#5A5650/#6A6B62`; **xám lam `#3E4450`**, **gỉ `#6B4A3A`**, ochre `#8A6A40` (xích) | mảng Ngà (xương, răng, mặt nạ) để tách nền tối ≤ 30 V | xích gỉ trên thân = xích treo trong nền; song sắt = giáp thanh |
| **Tháp Băng** | sương giá, hồn ma lạnh, lính canh đá, cung thủ rime | cao hẹp, mảnh; vật liệu đóng băng; tinh thể **không** cyan | băng xám-lam, tuyết, lông Ngà, đá rime, hơi lạnh | Ink; Ngà; Cleric robe shadow `#6E7282` (sương giá); **xanh đêm `#2E3450`**, **lam-xám `#4C5266`**, **rime sáng `#A8B0C8`** | sương giá bám mép, hơi thở; **mảng tối** (xanh đêm) để tách nền sáng V 60–72; cấm `#A6EEFF` | lan can / cột băng; con đá = chất đá tháp |
| **Không Đảo** | sinh vật gió và trời: chim, điểu nữ, võ tăng, lính gác đảo cổ, mây | nhẹ, cánh gập, vải bay; cao mảnh hoặc tròn như mây | lông, mây, vải, đá đảo mòn gió, dây thừng | Ink; Ngà; đá đảo **`#5A5048`**, **xám bão `#6A7080`**, **vàng sấm đục `#B8A860`** (S ≤ 30 %) | gió kéo lông/vải về một phía (tĩnh), mây ở chân; mảng tối tách trời sáng | dây thừng / đá mòn gió = cầu dây, chân đá sân |
| **Rừng Sương** (đã có) | rễ, rêu, nấm, goblin, sói | hữu cơ, không đều | vỏ cây, rêu, nấm | như gpl hiện tại | ngụy trang xám-rêu nhưng bóng đen tách khỏi cây | giữ nguyên |

### 3.1 Thiết kế từng con — Hỏa Ngục (9)

Cột "Giống ai nhất" là kiểm tra bắt buộc trước khi duyệt anchor (quy tắc Cloud-lookalike). Khung: thường 64×52 (nhìn 3/4 trái, high
~44–47), Tinh Anh 80×80 (~66–69), Kẻ Gác 1 ô 96×84 đề xuất (~80).

| Id | Lớp bóng đen | Thiết kế một dòng (dấu loài ở nửa trên) | Vật cầm / nhìn thấy ở 3/4 | Màu | Giống ai nhất → khác ở |
|---|---|---|---|---|---|
| `imp` | hai chân nhỏ | quỷ lùn than, sừng ngắn Ngà, tai dơi, đuôi móc, lưng gù, chân dê | đinh ba ngắn gãy, cầm thấp tay gần | than, đồng tối, Ngà (sừng) | Imp (Diablo) → không đỏ, không lửa; thân than nứt ochre |
| `ember_hound` | bốn chân thấp | chó than gầy xương sườn lộ, cổ xích đứt, hàm dài, tai cụp | — (xích cổ) | than, Đá tối, ochre khe sườn | Hellhound (Doom) → không lửa, không mắt cam; xương sườn lộ như than vỡ |
| `ash_golem` | cấu trúc nặng | khối tro xám đứng thẳng, vai hình phiến lò, đầu lún trong ngực, nắm đấm to | — | Đá `#4A4640/#5A5650`, than | Golem (Clash) → vai phiến vuông cắt 90° (ngôn ngữ lưới), thân tro rỗ |
| `flame_cultist` | hai chân cao | người trùm áo cháy xém rách, mặt nạ sắt Ngà hở mắt, tay giơ gậy đuốc **đã tắt** (than đen) | gậy đuốc tắt, đầu than | than, ochre viền áo, Ngà mặt nạ | Cultist (Darkest Dungeon) → mặt nạ sắt, không lửa |
| `magma_slug` | khối tròn / nhầy | sên than dài thấp, vỏ obsidian phiến, khe nứt ochre dọc lưng, hai râu | — | obsidian `#2C2925`, than, ochre khe | Magcargo (Pokémon) → không cam, vỏ phiến góc cạnh |
| `hell_knight` | hai chân cao mang giáp | hiệp sĩ giáp phiến than, mũ sừng đồng, khiên phiến vỡ, cao nhất nhóm thường | đại kiếm đen vác vai gần | than, đồng tối, Đá | Black Knight (Dark Souls) → sừng đồng, khiên phiến than vuông |
| `fire_eater` (E) | hai chân rộng | quỷ bụng phệ miệng rộng Ngà, cổ xích, bụng than nứt ochre (nuốt lửa = ngực tro) | — | than, Ngà răng, ochre | Oni → không mặt đỏ, bụng than |
| `ash_phoenix` (E) | bay | phượng tro cánh xoè nửa, lông tro xám, mỏ Ngà, đuôi tro rủ **chạm hàng cuối** (neo) | — | Đá sáng `#6A6B62`, than, Ngà | Phoenix (Marvel) → tro xám, không lửa, không cam |
| `inferno_lord` (Kẻ Gác) | hai chân cao, 1 ô | **theo bible §5.2**: giáp phiến than, hai sừng cong đồng, ngực nứt ochre tối, áo choàng cháy xém; **bỏ** vân dung nham cam và mắt cam, gai lơ lửng | kiếm lửa **tắt** cầm thấp (tuỳ chọn) | than, đồng, ochre, Ngà | Diablo / Sargeras → giáp phiến vuông, không lửa, không đỏ |

### 3.2 Sa Mạc (9)

| Id | Lớp | Thiết kế | Vật cầm | Màu | Giống ai nhất → khác ở |
|---|---|---|---|---|---|
| `dune_jackal` | bốn chân | chó rừng gầy tai to dựng, lưng phủ cát, đuôi cụp | — | be, be tối, Ngà | Anubis-jackal → không đen, không vàng; cát trên lưng |
| `sand_beetle` | khối thấp | bọ cát vỏ sa thạch tròn, sừng ngắn, chân nhiều | — | be tối, Đá, Ngà sừng | Scarab (Mummy) → vỏ sa thạch mờ, không óng |
| `dust_nomad` | hai chân cao | du mục trùm vải bạc màu kín mặt, chỉ hở mắt Ngà, khăn bay một phía | kiếm cong ngắn cầm thấp | Hunter cloak `#5E6150/#7E8068`, be | Tusken Raider → khăn vải xanh-xám, không kính, không ống thở |
| `mirage_sprite` | lơ lửng | bóng người cát rỗng, nửa dưới tan thành hạt cát **chạm hàng cuối** | — | be, be tối, Ngà mắt | Sandman → nửa dưới hạt vuông 2 px, không mặt |
| `scarab_guard` | hai chân mang giáp | vệ binh người-bọ giáp kitin sa thạch, mũ bọ hung Ngà, khiên tròn ngọc đục | khiên + giáo | be tối, ngọc đục, Ngà | Scarab Knight (Hollow Knight-like) → ngọc đục `#4F8A80`, giáp sa thạch |
| `sun_archer` | hai chân cao | cung thủ mũ đĩa tròn be (mặt trời, mờ), áo quấn, bao tên | cung cong dài tay gần | be, be tối, ochre `#8A6A40` | Ra → không vàng Ánh Lưới, đĩa be mờ |
| `sand_burrower` (E) | khối thấp lớn | bọ đào cát dài, hàm kẹp to Ngà, nửa thân chìm **trong gò cát vẽ trong khung** | — | be tối, Đá, Ngà | Graboid (Tremors) → hàm kitin, gò cát |
| `scorpion` (E) | bốn+ chân thấp rộng | bọ cạp sa thạch, đuôi cong cao (dấu loài nửa trên), càng to | — | be tối, Đá tối, ngọc đục đốt đuôi | Scorpion (generic) → chất sa thạch, đốt ngọc đục |
| `sand_sphinx` (Kẻ Gác) | ngồi thẳng, 1 ô | **bible §5.2**: ngồi thẳng, đầu người đội sừng, đai ochre + ngọc `#4F8A80`, hai cánh phiến đá gập sau vai, đuôi vòng; **bỏ** dáng nằm ngang, trang sức vàng, gạch lơ lửng | — | be, be tối, ochre, ngọc | Sphinx (Gizeh) → sừng, cánh phiến gập, ngồi dọc |

### 3.3 Đầm Lầy (9)

| Id | Lớp | Thiết kế | Vật cầm | Màu | Giống ai nhất → khác ở |
|---|---|---|---|---|---|
| `bog_rat` | bốn chân nhỏ | chuột lầy lông ướt bết, đuôi dài trụi, răng Ngà, lưng dính rong | — | bùn, ô-liu, Ngà | Rat (Ratatouille) → bết bùn, rong lưng |
| `mire_slug` | khối thấp dài | sên bùn thân trơn tròn, hai râu mắt, vệt nhầy mờ | — | bùn, ô-liu sáng, Nấm `#8E8296` | Slug (generic) → không vỏ, nhầy xám tím |
| `swamp_lizard` | bốn chân dài thấp | thằn lằn đầm cổ xoè diềm, lưng gai, đuôi dài cong | — | ô-liu, Rêu, Ngà diềm | Frilled lizard → diềm Ngà, rong |
| `marsh_toad` | tròn phình | cóc đầm to tròn, cổ họng Ngà phình, mụn nấm nhỏ | — | ô-liu, Nấm, Ngà bụng | Toad (Mario) → cóc thật, không mũ |
| `reed_witch` | hai chân cao | phù thủy lau sậy gầy, mũ chóp lau sậy, áo rong rủ, mặt che tóc rêu | gậy lau sậy, giỏ **khối thối** nhỏ (rotten_thrower) sau lưng | Rêu, ô-liu, Nấm, Ngà | Witch (Hansel & Gretel) → lau sậy, rong, không mũi dài |
| `bog_hound` | bốn chân | chó săn đầm ướt, lưng trần da nhăn, hàm rộng, rong bám cổ | — | bùn, ô-liu, Ngà | Hyena → da nhăn ướt, rong |
| `spore_cap` (E) | cấu trúc | nấm bào tử to, mũ rộng phẳng Nấm `#6A5868`, thân Ngà, túi bào tử bên dưới mũ | — | Nấm, Rêu, Ngà | Greycap Sporeling (rừng, đã có) → **phải khác**: một mũ rộng dẹt duy nhất, thân cao gấp rưỡi, túi bào tử treo, không mắt |
| `leap_frog` (E) | hai chân dài (ếch) | ếch nhảy chân sau rất dài gập, thân nhỏ, mắt lồi Ngà trên đỉnh | — | ô-liu sáng, Rêu, Ngà | Frog (generic) → chân sau dài quá khổ, dáng chực nhảy |
| `toad_matriarch` (Kẻ Gác) | tròn rộng thấp, 1 ô | **bible §5.2**: tròn, rộng, thấp; 3–4 nấm xám-tím `#6A5868` trên đầu, rêu nhỏ giọt, bụng sáng; **bỏ** dây chuyền ô vuông ngà | — | ô-liu, Nấm, Rêu, Ngà | Marsh Toad → to gấp đôi, nấm trên đầu, tay sau kéo |

### 3.4 Hầm Ngục (10)

| Id | Lớp | Thiết kế | Vật cầm | Màu | Giống ai nhất → khác ở |
|---|---|---|---|---|---|
| `skeleton` | hai chân | bộ xương lính Ngà xỉn, mũ sắt gỉ sụp, khiên gỗ mục | kiếm gỉ ngắn | Ngà, gỉ, Đá | Skeleton (Minecraft) → mũ gỉ, khiên mục, không cung |
| `zombie` | hai chân rũ | xác sống lệch vai, một tay rủ, da xám lam, vải mốc | — | xám lam `#3E4450`, Đá, Ngà răng | Zombie (Minecraft) → vai lệch, vải mốc rách |
| `bat_swarm` | bay | ba-bốn con dơi chụm thành khối tròn, cánh xoè, mắt Ngà; dơi thấp nhất **chạm hàng cuối** | — | Đá tối, xám lam, Ngà | Zubat → đàn, không mặt to |
| `slime` | khối nhầy | nhầy ngục bán trong (giả lập bằng 2 tông, không alpha), lõi xương Ngà, giọt rủ | — | xám lam sáng, Đá, Ngà lõi | Slime (Dragon Quest) → không mặt cười, lõi xương |
| `ghost` | lơ lửng | bóng ma áo rách mờ, đuôi vải **chạm hàng cuối**, mắt hốc Ngà | xích ngắn tay | Đá sáng `#6A6B62`, xám lam, Ngà | Ghost (Pac-Man) → vải rách, xích |
| `reacter` | cấu trúc | tượng gác hầm bằng đá có khớp xích, mắt Ngà một bên, tư thế chực lao (step_reactor) | — | Đá, gỉ, ochre xích | Weeping Angel → khớp xích, đá hầm |
| `cultist` | hai chân cao | tín đồ áo thụng tối trùm kín, mặt nạ Ngà trơn, dây chuỗi ochre | dao lễ | xám lam, Đá tối, Ngà | Cultist (Bloodborne) → mặt nạ trơn Ngà, không mũ rộng |
| `rat_king_guard` | hai chân (chuột) | chuột người mặc giáp gỉ, mũ sắt, đuôi dài, khiên chấn song | giáo | gỉ, Đá, Ngà răng | Skaven (Warhammer) → giáp gỉ chấn song, không đỏ |
| `jailer` (E) | hai chân nặng | cai ngục to bụng, áo da, chùm chìa khoá Ngà, đai xích, mũ trùm | **gậy xích** (rotten_thrower / seal_caster) | gỉ, ochre, Đá tối, Ngà | Jailer (Hades) → chìa khoá Ngà, xích đai |
| `ogre_king` (Kẻ Gác) | hai chân rất nặng, 1 ô | **bible §5.2**: đá xám, vai rộng, đầu nhỏ, vương miện + râu Ngà, xích gỉ ochre `#8A6A40` vắt ngực và cổ tay; **bỏ** vòng cột đá lơ lửng | chuỳ đá (slam) | Đá, gỉ, ochre, Ngà | Ogre (Shrek) → vương miện, râu, xích |

### 3.5 Tháp Băng (10)

| Id | Lớp | Thiết kế | Vật cầm | Màu | Giống ai nhất → khác ở |
|---|---|---|---|---|---|
| `frost_sprite` | lơ lửng nhỏ | tiên sương thân sương nhỏ, váy tinh thể xám-lam **không cyan**, đuôi sương chạm hàng cuối | — | lam-xám, rime sáng, Ngà | Fairy (Zelda) → không cánh sáng, tinh thể xám |
| `wisp` | lơ lửng | ma trơi: đèn lồng băng tròn treo trên dải khói, mắt Ngà | — | xanh đêm, lam-xám, Ngà | Will-o'-wisp → đèn lồng băng, không lửa |
| `stone_sentry` | cấu trúc | lính canh đá tháp đứng thẳng, giáp đá phủ rime, mũ trụ, tay khiên đá | khiên đá | Đá, lam-xám, rime | Golem → mũ trụ tháp, rime mép |
| `snow_wolf` | bốn chân | sói tuyết lông dày Ngà-xám, mõm dài, bờm tuyết | — | rime sáng, lam-xám, Ngà | Dire Wolf (rừng) → **khác**: lông dày sáng, bờm, dáng cao hơn, mõm hẹp |
| `fuse_golem` | cấu trúc | pháo ngòi: thân đá vuông, nòng pháo băng trên vai, ngòi dây Ngà (fuse_cannon) | nòng pháo vai gần | Đá, xanh đêm, Ngà | Cannon golem (generic) → ngòi dây Ngà, nòng vuông |
| `rime_archer` | hai chân cao | cung thủ áo lông Ngà, mũ trùm, cung băng xám | cung dài | xanh đêm, rime sáng, Ngà lông | Legolas → mũ trùm lông, không tai nhọn |
| `ice_golem` | cấu trúc to | người băng khối vuông, mép rime, hốc mắt Ngà, cao nhất nhóm thường | — | lam-xám, rime sáng, Đá | Ice Golem (Clash Royale) → khối vuông cắt 90°, không cyan |
| `ghost_elite` | lơ lửng | **biến thể của `ghost`** (bible §5.6: đổi 2–3 màu + 1 phụ kiện ≤ 8×8 nửa trên): sắc lạnh xanh đêm/rime, thêm vương miện băng Ngà, **cao hơn ghost ≥ 8 px bằng dải khói dài** (script, 0 gen) — nếu người dùng muốn thân riêng thì gen như con thường | xích | xanh đêm, rime, Ngà | như ghost |
| `frost_mage` (E) | hai chân cao | pháp sư sương áo xanh đêm, cổ lông Ngà, mũ nhọn, gậy băng xám | gậy | xanh đêm, lam-xám, Ngà | Ice Wizard (Clash) → không cyan, không bóng sáng; sương giá bám áo |
| `mist_lord` (Kẻ Gác) | cao hẹp, 1 ô | **bible §5.2** Chúa Tể Băng Giá: cao hẹp, áo xanh đêm rũ, cổ lông Ngà, vương miện gai băng, mũ không mặt; gai băng một vai; **bỏ** băng xanh sáng, khói áo > 40 px | — | xanh đêm, rime, Ngà | Lich King → không mặt, gai một vai, không cyan |

### 3.6 Không Đảo (9)

| Id | Lớp | Thiết kế | Vật cầm | Màu | Giống ai nhất → khác ở |
|---|---|---|---|---|---|
| `cloud_sprite` | lơ lửng tròn | tinh mây: cụm mây xám tròn có mắt Ngà, chân mây chạm hàng cuối | — | xám bão, Đá sáng, Ngà | Kirby/Cloud (Mario Lakitu) → mây xám bão, không mặt cười |
| `harpy` | hai chân + cánh | điểu nữ chân chim, cánh gập sau lưng, tóc lông xám, dáng khom | móng | xám bão, đá đảo `#5A5048`, Ngà | Harpy (Castlevania) → cánh gập, lông xám, không trần |
| `wind_monk` | hai chân cao | võ tăng gió áo vải bay một phía, đầu trọc, dây lưng | trượng gỗ | Hunter cloak, đá đảo, Ngà | Aang → không mũi tên, trượng, áo xám-vàng đục |
| `storm_eagle` | bay lớn | đại bàng bão cánh xoè ngang khung, mỏ Ngà, lông đầu dựng; móng chạm hàng cuối | — | xám bão, Đá tối, Ngà | Eagle (generic) → lông bão xám, vệt vàng sấm đục |
| `sky_sentinel` | cấu trúc | lính gác trời: tượng đá đảo mòn gió có cánh đá gập, dây thừng quấn | giáo đá | đá đảo, xám bão, Ngà | Gargoyle → đá mòn gió, dây thừng |
| `thunder_shaman` | hai chân cao | pháp sư sấm mũ lông chim, áo choàng vàng sấm đục, trống nhỏ | gậy lông | vàng sấm `#B8A860`, xám bão, Ngà | Shaman (WoW troll) → không ngà voi, mũ lông chim |
| `gale_bird` (E) | bay lớn | chim gió to, cánh dài gập nửa, đuôi dài tới hàng cuối, mỏ Ngà | — | xám bão, đá đảo, Ngà | Roc → cánh gập, đuôi dài |
| `cloud_veil` (E) | lơ lửng cao | thần mây: thân mây cao có mạng che Ngà (shroud), mắt trống | — | xám bão, rime sáng, Ngà | Dementor / Mistbriar (rừng) → **khác**: mây xám bão, mạng che, không vỏ cây |
| `storm_dragon` (Kẻ Gác) | rồng chữ S, 1 ô | **bible §5.2**: rồng uốn chữ S đứng, rộng ≤ 40 px, đầu cao hai sừng Ngà, cánh gập sát, mây lượn ở chân; **bỏ** sừng vàng, sét, cụm đảo, cánh xoè | — | xám bão, đá đảo, vàng sấm đục, Ngà | Shenron / Haku → cánh gập, sừng Ngà, đứng chữ S |

### 3.7 Kiểm tra đa dạng bóng đen trong vùng (đếm theo lớp)

| Vùng | bốn chân | hai chân nhỏ | hai chân cao/giáp | khối tròn/nhầy | bay/lơ lửng | cấu trúc | Lớp dùng |
|---|---|---|---|---|---|---|---|
| Hỏa Ngục | ember_hound | imp | flame_cultist, hell_knight, fire_eater, inferno_lord | magma_slug | ash_phoenix | ash_golem | 6/6 |
| Sa Mạc | dune_jackal, scorpion | — | dust_nomad, sun_archer, scarab_guard | sand_beetle, sand_burrower | mirage_sprite | sand_sphinx | 5/6 |
| Đầm Lầy | bog_rat, swamp_lizard, bog_hound | leap_frog | reed_witch | mire_slug, marsh_toad, toad_matriarch | — | spore_cap | 5/6 |
| Hầm Ngục | — | skeleton, zombie, rat_king_guard | cultist, jailer, ogre_king | slime | bat_swarm, ghost | reacter | 5/6 |
| Tháp Băng | snow_wolf | — | rime_archer, frost_mage, mist_lord | — | frost_sprite, wisp, ghost_elite | stone_sentry, fuse_golem, ice_golem | 4/6 |
| Không Đảo | — | harpy | wind_monk, thunder_shaman | cloud_sprite | storm_eagle, gale_bird, cloud_veil, storm_dragon | sky_sentinel | 5/6 |

Cặp dễ trùng giữa vùng và cách tách: Greycap (rừng) ↔ spore_cap (đầm): một mũ dẹt + cao hơn, không mắt · Dire Wolf ↔ snow_wolf ↔
ember_hound ↔ bog_hound ↔ dune_jackal: khác lông (dày sáng / xương sườn lộ / da nhăn ướt / gầy tai to), khác dáng đầu và đuôi ·
Mistbriar ↔ ghost ↔ cloud_veil: vỏ cây / vải rách + xích / mây + mạng · 3 golem (ash / stone_sentry / ice): tro rỗ vai phiến /
giáp phủ rime mũ trụ / khối băng vuông.

## 4. Asset dùng lại

- 11 sheet Rừng Sương: **giữ nguyên**, không gen lại, không recolour (visual đã duyệt).
- Pipeline y hệt roster rừng: `create_character_pro_flash` (low top-down, 8 hướng, seed 1, palette khoá, `style_image` = Goblin v3
  south rotation với `color_palette: false` — character `3b9516c8`), anchor = hướng south-west, clip bằng `animate_character` pixminimax
  south-west 8 khung, dọn sạch cơ học (snap palette, bỏ đốm < 12 px, trồng chân hàng cuối, căn giữa) — **không vẽ tay chi tiết**.
- `StatusPacks` `goblin` cho mọi địch; `UnitLayer` không cần sửa cho não khối; `export_sheets.py`, `art_check.py`, `candidate.py`,
  `asset_registry.py`, `integrate.py clip` dùng nguyên.
- Nền và sân v2 của session anh em là bối cảnh để QA (§8), không sửa.

## 5. Asset đã tạo / sửa

**Hỏa Ngục 9/9 (2026-11-13, 118 gen: 55 anchor + 18 gen lại + 45 clip), phương pháp PixelLab, cài và kiểm trong trận:**

| Id | Khung | Sheet | Palette thực tế (từ sheet JSON) | Gen |
|---|---|---|---|---|
| imp | 70×52 | `unit_imp_sheet.png` 425×264 | Ink, than `#24201E`, `#2C2925`, `#4A4640`, đồng `#7A5A36`, ochre `#8A6A40`, Ngà | 6+6+5 |
| ember_hound | 68×52 | `unit_ember_hound_sheet.png` 413×264 | Ink, than, `#2C2925`, `#4A4640`, `#5A5650`, ochre, Ngà | 6+5 |
| ash_golem | 72×52 | `unit_ash_golem_sheet.png` 437×264 | Ink, than, 4 Đá, ochre, Ngà | 6+5 |
| flame_cultist | 70×54 | `unit_flame_cultist_sheet.png` 425×274 | Ink, than, `#2C2925`, `#4A4640`, đồng, ochre, Ngà | 6+5 |
| magma_slug | 64×52 | `unit_magma_slug_sheet.png` 389×264 | Ink, than, 3 Đá, ochre, Ngà | 6+5 |
| hell_knight | 68×52 | `unit_hell_knight_sheet.png` 413×264 | Ink, than, 3 Đá, đồng, ochre, Ngà | 6+5 |
| fire_eater (E) | 92×80 | `unit_fire_eater_sheet.png` 557×404 | Ink, than, `#2C2925`, `#4A4640`, đồng, ochre, Ngà | 6+6+5 |
| ash_phoenix (E) | 84×80 | `unit_ash_phoenix_sheet.png` 509×404 | Ink, than, 4 Đá, Ngà | 6+6+5 |
| inferno_lord (Kẻ Gác) | 108×86 | `unit_inferno_lord_sheet.png` 653×434 | Ink, than, 3 Đá, đồng, Ngà | 7+5 |

Khung rộng hơn tối thiểu bậc (64×52 / 80×80 / 96×84) vì clip step/windup dịch ngang (như `dire_wolf` 68 của rừng); chân vẫn ở hàng
cuối, tâm x = w/2 từ idle khung 0. Nguồn: `art_src/units/<id>/` + `clips.json`; candidate: `design/assets/candidates/hellfire/<id>/`
(rot, rot-v2, download/ 9 khung gốc mỗi clip, clean-WxH, contact `-clips-raw-x2.png` / `-clean-x2.png`). Registry: 9 entry `unit.<id>`
(`acceptance: accepted` theo "Yes, 45 clip", `status: installed`, chưa `approved`), manifest 190 asset. Reference:
`design/assets/references/characters/<id>.md` ×9. `.import` sinh bằng `--import`, cờ chỉnh về đúng goblin (`detect_3d/compress_to=0`).
Palette gpl +16 (§7.2). Test: `tests/unit/battle/roster_sprite_test.gd` +9 id, +2 Tinh Anh vào bảng chiều cao, +luật Kẻ Gác 1 ô cao
hơn Tinh Anh vùng ≥ 4 px. 5 vùng còn lại: chưa (§11).

## 6. Thay đổi animation

- Độ phủ hiện có: 11 con rừng đủ 5 clip + clip đặc tính; **9 con Hỏa Ngục đủ 5 clip (2026-11-13)**; 44 con còn lại 0 clip.
- Chọn khung Hỏa Ngục (nguồn 0 = tham chiếu, 1–8 sinh): idle 0/2/4/6 · step 1/3/5/7 · windup 2/4/6/8 (golem 1/2/4/8) giữ khung cuối ·
  hit 3 khung, bỏ các khung có hiệu ứng vẽ sẵn (imp 1–2 vệt trắng, hound 1 vệt vàng, golem 2–3 tro bắn, cultist 2–3 vệt trắng,
  fire_eater 1–2 lửa cam, phoenix 2–3 sao vàng) · down 2/3/4/5/6/8 (hound, slug 1/3/4/5/6/8). Không khung nào quay lưng.
- Kế hoạch cho mỗi con mới: đúng 5 clip (`idle` 4 khung 250 ms lặp; `step` 4 khung 100 ms; `windup` 4 khung 100/100/100/0 giữ
  khung cuối tới hết báo đòn; `hit` 3 khung 40 ms; `down` 6 khung 100/120/150×4 giữ khung cuối) — cùng timing roster rừng (reference
  §6), không đổi timing gameplay.
- Không gen `phase_shift`/`windup_heavy`/`guard`/`brace`/`stunned`/`howl` cho não khối (code không gọi). Trait riêng (`burrow`,
  `riposte`, `rebirth`, `hop_skip`, `gust`, `shroud`, `fuse_cannon`, `slam`, `sandstorm`…) **không có clip riêng** trong code hiện tại
  → đọc qua `windup` chung + VFX sẵn có; ghi ở §11 như gap có thể xét sau (sẽ là code mới, ngoài phạm vi).
- Con bay / lơ lửng: idle là bồng bềnh 1–2 px, pixel thấp nhất luôn ở hàng cuối (neo tâm ô, quy tắc "đứng giữa ô").

## 7. Chi tiết tích hợp

### 7.1 Các bước cho một con (đã kiểm trong pipeline, không sửa code)

1. `candidate.py new unit.<id>` → thư mục `design/assets/candidates/<id>/` (anchor rot/, anim/<clip>/, clean-<WxH>/).
2. Anchor: `create_character_pro_flash` theo §4; `pixelart_workbench inspect` rotation south-west (free); đo bbox / màu bằng
   `tools/qa/sprite_measure.gd`; ghi "giống ai nhất"; **trình người dùng duyệt**.
3. 5 clip pixminimax; chọn khung theo bảng §6; dọn cơ học (`sprite_clean.gd` / snap palette); loại khung có burst/đỏ/quay lưng.
4. `art_src/units/<id>/clips.json` + khung → `export_sheets.py --units <id>` → `assets/art/units/unit_<id>_sheet.png/json`;
   Godot `--headless --import` để có `.import`.
5. Registry: entry `unit.<id>` (candidate → accepted khi người dùng duyệt → installed); reference
   `design/assets/references/characters/<id>.md`.
6. Thêm id vào `tests/unit/battle/roster_sprite_test.gd` (ROSTER + NORMALS/ELITES theo vùng) — test, không phải gameplay.
7. Chụp in-game trên sân vùng đó (§8) → `production/qa/evidence/world-map-v2/region-enemies/`.

### 7.2 Mở rộng bảng màu (`art_src/palette/tessera_master.gpl`, 47 → **63** / trần 64 — ĐÃ ÁP DỤNG 2026-11-13 theo baseline người dùng)

| Vùng | Thêm (≤ 3) | Lý do (tín hiệu nào không thay được) |
|---|---|---|
| Hỏa Ngục | than `#24201E` · đồng tối `#7A5A36` · ochre đục `#8A6A40` (chia với Hầm Ngục) | than = chủ đạo RENDER §4; đồng = sừng Kẻ Gác (bible); ochre = khe nứt / xích thay cho cam bị cấm |
| Sa Mạc | be `#A89A80` · be tối `#6E6248` · ngọc đục `#4F8A80` | chủ đạo + fallback đất + ngọc Kẻ Gác (bible) |
| Đầm Lầy | ô-liu `#4E4C3C` · bùn `#5A4A3A` | chủ đạo; Rêu + Nấm dùng lại từ rừng |
| Hầm Ngục | xám lam `#3E4450` · gỉ `#6B4A3A` (ochre dùng chung) | chủ đạo; xích gỉ Kẻ Gác (bible) |
| Tháp Băng | xanh đêm `#2E3450` · lam-xám `#4C5266` · rime sáng `#A8B0C8` | áo Kẻ Gác (bible), phiến tháp, sương giá "lam-xám, không cyan" |
| Không Đảo | đá đảo `#5A5048` · xám bão `#6A7080` · vàng sấm đục `#B8A860` | RENDER §4 Không Đảo |
| **Tổng** | **+16 → 63** (ochre dùng chung Hỏa Ngục / Hầm Ngục nên là 16 dòng, không phải 17) | còn 1 chỗ dưới trần; Tâm Lưới dùng Ngà/Đá/Cleric có sẵn, không thêm. `export_sheets.py --check` sau khi thêm: 16/16 sheet ok |

Không màu nào trùng màu tín hiệu hay màu khối của 5 anh hùng. Nếu người dùng không muốn chạm trần, bỏ `#7A5A36` (đồng → dùng
ochre) và `#5A4A3A` (bùn → dùng `#4A3A2A` vỏ gai rừng) → +15.

### 7.3 Khung Kẻ Gác 1 ô (cần người dùng quyết)

Kẻ Gác 6 vùng đứng **1 ô** (không có `footprint` 2×2 như Phù thủy / Vu sư rừng; `footprint` chỉ có trong `enemy_skills.json`
của não pattern). Khung 160×130 của boss 2×2 không hợp; bible 48×64 đã lỗi thời sau OSFE scale. Đề xuất: canvas PixelLab
**96×96**, khung xuất **96×84**, thân cao ~78–82 px (Tinh Anh 66–69 + ≥ 12; thường 44–47), rộng ≤ 44 px để vẫn đứng gọn
trên ô 38 px (ô hẹp nhất) với vật cầm nằm trong khung. Chi phí anchor 7 gen thay vì 6.

### 7.4 Checklist khoá thiết kế trước MỖI anchor (quy tắc verify-before-spending)

`[ ] view low top-down, anchor = south-west (3/4 quay trái)` · `[ ] style_image Goblin v3 south, color off` · `[ ] palette khoá
≤ 8 màu từ gpl (sau §7.2)` · `[ ] canvas đúng tier (64 / 80 / 96)` · `[ ] layout: dấu loài nửa trên, chân hàng cuối, ≥ 1 px lề`
· `[ ] vật cầm nhìn thấy ở 3/4 (tay gần)` · `[ ] màu nhấn vùng đặt trên mảng lớn (thân/áo), không ở chi tiết < 2×2` · `[ ] mặt:
mắt 2×2 Ngà hoặc hốc tối; không mặt người chi tiết` · `[ ] tương phản với nền vùng (tối → mảng Ngà/Đá sáng; sáng → mảng Mực/Đá
đêm)` · `[ ] "giống ai nhất" đã ghi và prompt đã tách` · `[ ] prompt không chứa từ phủ định ở clip PixMiniMax` · `[ ] người
dùng đã "yes" cho đúng lệnh này`.

## 8. Ảnh chụp theo vùng

**Trước (placeholder, 2026-11-12, session anh em):** `region-visuals/31–42` (c0 + warden, 6 vùng), `13-forest-c0-control.png`,
`arena-integration/31–38` (sân v2), `420-all-seven-arenas.png` (7 sân cạnh nhau — Kiếm sĩ + ô đỏ).
**Sau (Hỏa Ngục, 2026-11-13, chụp thật 1280×720 windowed, `--audio-driver Dummy`, Kiếm sĩ, idle khung 40):**
`region-enemies/10-hellfire-<id>-idle.png` ×9 — tiêu đề trận xác nhận đúng con (Tiểu Quỷ, Chó Than Hồng, Khôi Tro, Tín Đồ Lửa, Sên
Dung Nham, Hiệp Sĩ Địa Ngục, Tinh Anh Quỷ Nuốt Lửa, Tinh Anh Phượng Tro, Boss Chúa Quỷ Lửa); sân Lò rèn và Miệng núi lửa. Mỗi con đứng
tâm ô, số máu dưới chân, viền Mực tách khỏi phiến. So sánh giữa vùng: `20-lineup-hellfire-vs-forest-x2.png` (6 rừng xám-rêu hữu cơ
bên trái, 9 Hỏa Ngục than-đồng bên phải: khác hẳn tông màu và chất liệu; trong Hỏa Ngục đủ 6/6 lớp bóng đen, bậc cao 36 → 79).
Chưa chụp windup/down trong trận (cần kịch bản điều khiển boss; contact sheet `-clean-x2.png` thay thế).

Cách chụp đã kiểm (2026-11-13, `region-enemies/00-baseline-hellfire-c0-seed27.png`: Tiểu Quỷ = ô đỏ "52" trên sân Lò rèn):
`godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -- --node=f<F>/<region>/c<C>/n<N> --seed=<s>
--character=kiem_si --lang=vi --shot=<png> --shot-frame=40`; c0 = trận đầu, c6 = Kẻ Gác (sanctum). Không có arg chọn match id
trực tiếp ngoài `--pattern=` (não pattern) → **bảng seed → từng con** đã dò bằng script headless mô phỏng đúng bước đi `--node`
của GameFlow (60 seed, không sửa src): `region-enemies/seed-table.md` — **đủ 52 con 6 vùng + Người Giữ** trong seed 1–20 (ví dụ
`imp` seed 1 `f2/hellfire/c0/n0`, `hell_knight` seed 3 `f2/hellfire/c1/n2`, `gale_bird` seed 20 `f7/sky_isles/c3/n1`). Tinh Anh và
Phù thủy rừng không ra trong run thường (rừng chỉ ở tầng 1) — QA chúng bằng `--pattern=<id>` như trước.

## 9. So sánh trước / sau

Hỏa Ngục: trước = ô đỏ (`00-baseline-hellfire-c0-seed27.png`, `region-visuals/31-32`), sau = `10-hellfire-<id>-idle.png`; mock
trước khi gen clip = `01-mock-hellfire-<id>.png`. Thân gốc → clean: `design/assets/candidates/hellfire/<id>/<id>-clips-raw-x2.png`
→ `<id>-clean-x2.png`.

## 10. Kết quả QA

### 10.1 Test hồi quy

Sau khi cài Hỏa Ngục (2026-11-13): `sheet_export_test` FAILS=0, `sprite_sheet_test` FAILS=0, `unit_sprites_test` FAILS=0,
`roster_sprite_test` (mở rộng) FAILS=0 — Tinh Anh 75/73 ≥ thường 50 + 12; Kẻ Gác 79 ≥ Tinh Anh + 4. `export_sheets.py --check` khớp.
Full suite: `full-suite-region-enemies-hellfire-2026-11-13.txt` — kết quả ở §10.3.

### 10.3 Full suite (2026-11-13, chạy nền, `full-suite-region-enemies-hellfire-2026-11-13.txt`)

289 test: **286 xanh**, 1 không in kết quả, 1 FAILS=1 — chạy lại riêng (`rerun-suspects-2026-11-13.txt`):
- `tests/integration/run/fate_flow_test.gd`: không in FAILS trong suite (timeout vì chạy trùng lúc chụp ảnh windowed); **chạy lại một mình FAILS=0**.
- `tests/unit/ui/controls_v3_hud_test.gd`: `test_status_poison_has_name_and_effect_keys ["poison", ""]` FAILS=1 cả khi chạy lại —
  **không thuộc task này**: trạng thái `poison` đến từ `src/combat/status_effects.gd` đang sửa dở (uncommitted) của session khác
  (`design-monster-skills`), chưa có khoá `status.poison.*` trong `strings.csv`; baseline 2026-11-12 xanh. Ghi nhận, không sửa file của session đó.
- Mọi test sprite / sheet / art liên quan asset quái: xanh.

### 10.2 Theo dõi hoàn thành từng con

Trạng thái: `—` chưa bắt đầu · `A` anchor duyệt · `C` 5 clip sạch · `I` cài sheet + registry · `G` kiểm trong trận · `✓` xong.

| Vùng | Con (trạng thái) |
|---|---|
| Rừng Sương | 11/11 `✓` (đã duyệt trước task; QA lại trên sân v2: `G` bằng ảnh 37-forest-c0-v2) |
| Hỏa Ngục | imp `✓` · ember_hound `✓` · ash_golem `✓` · flame_cultist `✓` · magma_slug `✓` · hell_knight `✓` · fire_eater `✓` · ash_phoenix `✓` · inferno_lord `✓` — 9/9 anchor + clip + cài + kiểm trận; `✓` khi người dùng duyệt clip (registry `approved`) |
| Sa Mạc | dune_jackal `✓` · sand_beetle `✓` · dust_nomad `✓` · mirage_sprite `✓` · scarab_guard `✓` · sun_archer `✓` · sand_burrower `✓` · scorpion `✓` · sand_sphinx `✓` — 9/9 (113 gen) |
| Đầm Lầy | bog_rat `✓` · mire_slug `✓` · swamp_lizard `✓` · marsh_toad `✓` · reed_witch `✓` · bog_hound `✓` · spore_cap `✓` · leap_frog `✓` · toad_matriarch `✓` — 9/9 (119 gen) |
| Hầm Ngục | skeleton `✓` · zombie `✓` · bat_swarm `✓` · slime `✓` · ghost `✓` · reacter `✓` · cultist `✓` · rat_king_guard `✓` · jailer `✓` · ogre_king `✓` — 10/10 (118 gen) |
| Tháp Băng | frost_sprite `✓` · wisp `✓` · stone_sentry `✓` · snow_wolf `✓` · fuse_golem `✓` · rime_archer `✓` · ice_golem `✓` · ghost_elite `✓` (script, phụ kiện chờ) · frost_mage `✓` · mist_lord `✓` — 10/10 (100 gen) |
| Không Đảo | cloud_sprite `✓` · harpy `✓` · wind_monk `✓` · storm_eagle `✓` · sky_sentinel `✓` · thunder_shaman `✓` · gale_bird `✓` · cloud_veil `✓` · storm_dragon `✓` — 9/9 (112 gen) |
| Tâm Lưới | an_dai_keeper — (ngoài 7 vùng) |

## 11. Khoảng trống còn lại và điều cần người dùng quyết

### 11.1 Kế hoạch gen và chi phí (PixelLab: còn 2003.9 gen, reset 2026-11-22)

| Vùng | Anchor (gen) | Clip (gen) | Tổng | Số lệnh cần "yes" |
|---|---|---|---|---|
| Hỏa Ngục | 55 + 18 gen lại | 45 | **118 (đã chi)** | 57 (đã duyệt) |
| Sa Mạc | 55 + 13 gen lại | 45 | **113 (đã chi)** | 56 (đã duyệt) |
| Đầm Lầy | 55 + 19 gen lại | 45 | **119 (đã chi)** | 57 (đã duyệt) |
| Hầm Ngục | 61 + 7 gen lại | 50 | **118 (đã chi)** | 61 (đã duyệt) |
| Tháp Băng | 55 | 45 | **100 (đã chi)** (ghost_elite 0 gen) | 54 (đã duyệt) |
| Không Đảo | 55 + 12 gen lại | 45 (1 gen lại sau khi bị chặn) | **112 (đã chi)** | 56 (đã duyệt) |
| **6 vùng** | 405 | 275 | **680 (đã chi)** | đã duyệt từng đợt |
| Tâm Lưới (tuỳ chọn) | 7 | 5 | 12 | 6 |

Dự phòng sửa anchor hỏng: **không re-roll loop**; mỗi anchor tối đa 1 lần gen lại sau khi người dùng xem (≈ +10 % = ~60 gen).
Đề xuất thứ tự: **Hỏa Ngục trước** (tầng 2, slice đã duyệt), rồi Sa Mạc → Đầm → Hầm → Tháp → Không Đảo (thứ tự leo).
Cách duyệt gọn mà vẫn đúng quy tắc "yes cho từng lệnh": mỗi vùng 2 đợt — đợt 1 "9 anchor" (người dùng xem 9 rotation + likeness,
duyệt / loại từng con), đợt 2 "45 clip" cho các anchor đã duyệt; tôi chỉ gọi những lệnh được nêu đích danh.

### 11.2 Quyết định đang chờ người dùng

1. **Duyệt 7 hướng art + 52 thiết kế một dòng** ở §3 (sửa tuỳ ý trước khi gen).
2. ~~Mở rộng gpl~~ — đã áp dụng +16 → 63 (§7.2).
3. **Khung Kẻ Gác 1 ô 96×84** (§7.3).
4. `ghost_elite` = biến thể script của `ghost` (0 gen) hay thân riêng.
5. ~~Yes cho đợt 1 Hỏa Ngục~~ — xong (Checkpoint A + B, 118 gen). **Tiếp: Sa Mạc** (9 anchor, 55 gen) theo thứ tự đã chốt; duyệt
   clip Hỏa Ngục (contact `-clean-x2.png` + ảnh trận) để chuyển registry sang `approved`.

### 11.3 Gap ngoài phạm vi (ghi nhận, không làm)

- Clip riêng cho trait (burrow / rebirth / hop_skip / gust / shroud / fuse_cannon / slam / sandstorm): cần code gọi clip mới → story riêng.
- `StatusPacks` cỡ `goblin` hơi nhỏ trên Kẻ Gác ~80 px → pack cỡ `warden` (free, vfx_workbench) sau khi có thân.
- Hiệu ứng vùng nhẹ trên thân (tro / bào tử / giọt nước / tuyết / gió) — Option C: chỉ xét **sau** khi thân gốc đạt; không dùng để che
  sprite chưa đạt. Cần một lớp overlay theo `region` trong `UnitLayer` (code chung) → bàn với session arena để không đụng file.
- Android/thiết bị thật: không có trong session này.
- 5 orphan rừng (`wolf`, `goblin_chief`, `goblin_warrior`, `goblin_shaman`, `goblin_brute`): không gen trừ khi đưa lại pool.
- `an_dai_keeper` (trận cuối): ngoài 7 vùng, tuỳ chọn.

---

## 12. Checkpoint A — Hỏa Ngục: 9 lệnh anchor (soạn 2026-11-13, CHỜ "yes" từng lệnh)

Baseline người dùng 2026-11-13: giữ roster 73 id; giữ 11 sprite rừng; gpl +16 → 63 (đã làm); Kẻ Gác 1 ô canvas 96×96 → xuất
96×84, thân 78–82 px; `ghost_elite` = biến thể script của `ghost`; thứ tự Hỏa Ngục → Sa Mạc → Đầm → Hầm → Tháp → Không Đảo;
Người Giữ để sau. PixelLab ưu tiên; nếu không đạt thì xét tự vẽ bằng tool nội bộ (pixel thật, không khối sơ sài).

### 12.1 Tham số chung cho cả 9 lệnh `create_character_pro_flash`

`view: low top-down` · `n_directions: 8` · `seed: 1` · `template_id: mannequin` (trừ `ember_hound`: `dog`, "standing on all four
legs") · `style_image.url` = Goblin Scout v3 south rotation (character `3b9516c8-2be0-43e2-b505-c58ba6e254c8`), `style_options
{outline, detail, shading: true; color_palette: false}`, `usage_description: "same pixel scale, 1 px dark outline, flat banded
shading; copy the look, not the colours"` · `palette` = ≤ 8 hex của gpl (cột bảng) · `max_colors: 8` · prompt kết thúc bằng
"transparent background, no ground shadow, no lava glow, no fire, no red, no orange, no gradient" (prompt anchor được dùng từ
phủ định; chỉ clip PixMiniMax là không). Chiều cao ghi trong prompt theo tier. Anchor = rotation **south-west**.

| # | Id | Canvas | Prompt (EN, gửi nguyên văn) | Palette khoá (≤ 8) | Gen |
|---|---|---|---|---|---|
| 1 | `imp` | 64×64 | "small hunched imp made of cracked charcoal, about 42 px tall, short ivory horns, bat ears, hooked tail, goat legs, holding a short broken trident low in the near hand, dark bronze fittings, dull ochre hairline cracks on the chest, 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #24201E #2C2925 #4A4640 #7A5A36 #8A6A40 #EFE6D2 | 6 |
| 2 | `ember_hound` | 64×64 (dog) | "gaunt charcoal hound standing on all four legs, about 34 px tall, ribs showing as cracked charcoal plates, long jaw with ivory teeth, drooping ears, a broken dull-ochre chain collar, dark grey-brown body, 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #24201E #2C2925 #4A4640 #5A5650 #8A6A40 #EFE6D2 | 6 |
| 3 | `ash_golem` | 64×64 | "squat ash golem, about 46 px tall and wide, square furnace-plate shoulders cut at right angles, head sunk into the chest, big fists, pitted grey ash body with dark cracks, dull ochre rivets, 2x2 ivory eye slit, 1 px dark outline, flat shading, …" | #1B1722 #24201E #2C2925 #4A4640 #5A5650 #6A6B62 #8A6A40 #EFE6D2 | 6 |
| 4 | `flame_cultist` | 64×64 | "tall hooded cultist, about 46 px tall, scorched ragged dark robe with dull ochre hem, plain ivory iron mask with eye slits, holding an extinguished torch staff (black charred head) in the near hand, dark bronze chain belt, 1 px dark outline, flat shading, …" | #1B1722 #24201E #2C2925 #4A4640 #7A5A36 #8A6A40 #EFE6D2 | 6 |
| 5 | `magma_slug` | 64×64 | "long low slug made of obsidian plates, about 28 px tall and 50 px long, faceted angular shell segments, a single dull ochre crack line along the back, two short eye stalks with 2x2 ivory eyes, dark charcoal underside, 1 px dark outline, flat shading, …" | #1B1722 #24201E #2C2925 #4A4640 #5A5650 #8A6A40 #EFE6D2 | 6 |
| 6 | `hell_knight` | 64×64 | "heavy knight in charcoal plate armour, about 47 px tall, helmet with two curved dark bronze horns, square cracked plate shield on the far arm, a black greatsword resting on the near shoulder, dull ochre cracks on the breastplate, no visible face, 1 px dark outline, flat shading, …" | #1B1722 #24201E #2C2925 #4A4640 #5A5650 #7A5A36 #8A6A40 #EFE6D2 | 6 |
| 7 | `fire_eater` (E) | 80×80 | "wide pot-bellied ogre-demon, about 68 px tall, huge open mouth with ivory teeth, chain collar of dull ochre links, charcoal skin cracked across the belly with dark bronze cracks, short thick legs, arms spread, 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #24201E #2C2925 #4A4640 #7A5A36 #8A6A40 #EFE6D2 | 6 |
| 8 | `ash_phoenix` (E) | 80×80 | "large ash-grey phoenix perched upright with wings half spread, about 68 px tall, long tail of ash feathers trailing down to the ground, ivory beak, charcoal legs, grey and dark grey feather bands, 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #24201E #2C2925 #4A4640 #5A5650 #6A6B62 #EFE6D2 | 6 |
| 9 | `inferno_lord` (Kẻ Gác) | 96×96 | "towering demon lord in charcoal plate armour, about 80 px tall, two long curved dark bronze horns, a dull ochre cracked breastplate, a scorched tattered cape, square-cut pauldrons, an extinguished black greatsword held low in the near hand, dark hollow visor with 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #24201E #2C2925 #4A4640 #5A5650 #7A5A36 #8A6A40 #EFE6D2 | 7 |

"…" = câu kết chung ở §12.1. **Tổng 55 gen.** Kiểm sau mỗi anchor (free): `pixelart_workbench inspect character:<id>:south-west`,
đo bbox / số màu / hàng chân, so bóng đen với 8 con còn lại và với Dire Wolf / Mossbound (rừng), ghép thử lên ảnh sân Hỏa Ngục
(`arena-integration/31-hellfire-c0-v2.png`), ghi "giống ai nhất", rồi mới trình duyệt; anchor hỏng → tối đa 1 lần gen lại sau
khi người dùng xem; vẫn hỏng → xét tự vẽ bằng `pixelart_workbench draw` (free).

### 12.5 Checkpoint B kết quả (2026-11-13, người dùng "Yes, 45 clip", 45 gen, 5 đợt × 9 vì tài khoản giới hạn 10 job)

Clip canvas PixelLab 64–124 (thân + chỗ chuyển động); tải ZIP `download/`, chọn khung (§6), dọn cơ học, cài, xuất sheet, import,
test, chụp trận (§8). Tổng Hỏa Ngục: **118 gen**. Mọi lệnh đều có yes của người dùng trước khi gọi.

### 12.2 Bảng chi phí / chất lượng — Checkpoint A kết quả (2026-11-13, 9 lệnh, 55 gen, người dùng "Yes, cả 9 lệnh")

Rotation tải về `design/assets/candidates/hellfire/<id>/rot/{south,south-west,west}.png`; sheet so sánh
`hellfire-anchors-sw-x1.png` / `-x3.png`. Đo: `tools/qa/sprite_measure.gd` (alpha 0/255, mọi màu trong gpl).

| Id | Character id | Gen | bbox SW (cao) | Màu | Giống ai nhất → khác ở | Verdict |
|---|---|---|---|---|---|---|
| imp | `6aed0a02-0353-4ab4-90ea-39a54b30bf31` | 6 | 52×**57** (y4-60) | 6 | Imp (Diablo) → không đỏ, than nứt | Thiết kế đạt (sừng, tai dơi, đuôi, đinh ba) nhưng **cao 57 px = cao hơn Hiệp sĩ (50)**, trái với "tiểu quỷ" và làm Tinh Anh phải ≥ 69 → **đề nghị gen lại 1 lần** "about 36 px tall, small, crouched" |
| ember_hound | `677145ec-45f4-4d29-b650-905e5330c130` | 6 | 40×41 | 6 | Hellhound → không lửa, sườn than | **ĐẠT**: dáng chó gầy, đầu thấp hàm dài, sườn lộ |
| ash_golem | `0c2bb412-b321-4eea-b267-0c8eec61c6fe` | 6 | 34×45 | 7 | Golem (Clash) → vai phiến vuông | **ĐẠT**: khối tro rỗ, vai vuông, đầu lún |
| flame_cultist | `68a7ab00-7cb7-4057-9f2a-d21ea3afcb53` | 6 | 29×50 | 6 | Plague doctor / Jawa → mặt nạ tròn Ngà, gậy đuốc tắt | **ĐẠT**: áo trùm, mặt nạ Ngà, gậy tay gần |
| magma_slug | `b7b62a15-cfc9-457f-b398-289d357b26fe` | 6 | 39×36 | 6 | Magcargo → không cam, vỏ phiến góc | **ĐẠT** (ghi chú: râu mắt nhỏ, bóng đen đọc như đống đá bò — chấp nhận được ở 1x, xem lại khi idle động) |
| hell_knight | `28dd0f18-c5e2-4766-94d3-f90789b60739` | 6 | 45×50 | 7 | Black Knight (Dark Souls) → sừng đồng, khiên phiến vuông | **ĐẠT**: mũ sừng, khiên, đại kiếm vác vai |
| fire_eater (E) | `87e8cfaa-9e26-47b5-9183-6caa4a690519` | 6 | 43×**47** (y16-62) | 6 | Oni → bụng than, không mặt đỏ | Thiết kế đạt (miệng rộng răng Ngà, cổ xích) nhưng **chỉ 47 px, thấp hơn cả Hiệp sĩ**; Tinh Anh cần ≥ 62 → **gen lại 1 lần** "about 72 px tall, fills the canvas height" |
| ash_phoenix (E) | `648ee0ac-93a7-487e-bfc5-900cd60ed2f3` | 6 | 33×**60** (y11-70) | 7 | Phoenix → tro xám, không lửa | Thiết kế đạt (mào, cánh gập, đuôi chạm đất) nhưng **60 px < 62** (thiếu 2 px so với luật Tinh Anh +12) → **gen lại 1 lần** "about 74 px tall" (hoặc giữ nếu người dùng chấp nhận hạ ngưỡng — không khuyến nghị) |
| inferno_lord (Kẻ Gác) | `416aac54-2e61-4147-944d-82126fbe31d0` | 7 | 69×**79** (y7-85) | 7 | Sauron / Diablo → giáp phiến vuông, kiếm tắt, không lửa | **ĐẠT**: sừng đồng dài, áo choàng rách, đại kiếm thấp, cao 79 đúng 78–82 |
| **Tổng** | | **55 + 18 = 73** | | | | 9/9 đạt sau 1 lần gen lại (§12.3) |

Bậc chiều cao sau khi 3 con gen lại đúng: thường 36–50 · Tinh Anh ≥ 62 (mục tiêu 68–74) · Kẻ Gác 79. Đa dạng bóng đen: 6/6 lớp
có mặt (bốn chân / hai chân nhỏ / hai chân cao-giáp ×3 / khối / bay / cấu trúc), không con nào là recolour của con khác;
màu toàn vùng: 9 hex (Ink, Ngà, than, 3 Đá, đồng, ochre, Đá sáng).

### 12.3 Gen lại 1 lần (2026-11-13, người dùng "Yes, gen lại 3 con", 18 gen)

| Id | Character v2 | Thay đổi prompt | Kết quả |
|---|---|---|---|
| imp | `9101d9ac-ab9f-4ac8-a309-380f27d0cbac` | "tiny crouched … only about 36 px tall, small and squat with lots of empty space above its head" | **ĐẠT** 43×36 (y21-56), 6 màu; vẫn sừng, tai dơi, đuôi móc, đinh ba tay gần |
| fire_eater | `6a18c180-f27c-4624-bd0d-a8b3c39c7712` | "huge … filling the whole canvas height, about 72 px tall, head touching the top of the frame" | **ĐẠT** 60×75 (y3-77), 6 màu; miệng rộng răng Ngà, xích ochre, bụng nứt đồng. Ghi chú: cao 75 vs Kẻ Gác 79 — Kẻ Gác vẫn to hơn về khối (69 px rộng, kiếm), chấp nhận |
| ash_phoenix | `252da60b-543d-41e4-83a9-3c18b3c84691` | "very tall … about 74 px tall, crest feathers reaching the top of the frame" | **ĐẠT** 38×73 (y4-76), 5 màu; mào, cánh gập, đuôi chạm đất |

Rotation v2 tải về `design/assets/candidates/hellfire/<id>/rot-v2/`; sheet `hellfire-regen-v2-x1.png` / `-x3.png` (cạnh Chúa Quỷ Lửa).
Bậc chiều cao chốt: thường 36–50 (imp 36, slug 36, hound 41, golem 45, cultist 50, knight 50) · Tinh Anh 73–75 · Kẻ Gác 79.
**Checkpoint A: 9/9 anchor đạt**, tổng 73 gen (55 + 18). Các character v1 của 3 con gen lại (6aed0a02, 87e8cfaa, 648ee0ac) giữ
trên PixelLab, không dùng.

### 12.3b Kiểm tra trên sân thật (bước 6, ghép cơ học ×2 lên ảnh chụp, free)

Ảnh: `region-enemies/01-mock-hellfire-<id>.png` (6 thường trên `00-baseline-hellfire-c0-seed27` sân Lò rèn, 2 Tinh Anh + Kẻ Gác
trên `region-visuals/32-hellfire-warden` sân Miệng núi lửa), chân ở tâm ô như `FEET_DEPTH_RATIO 0.5`.

Độ đọc bible §6.6 (tỉ lệ pixel nửa trên lệch ≥ 25 V so với nền ngay sau), đo bằng script, **hiệu chuẩn bằng sprite đã duyệt**:
Goblin trinh sát trên sân rừng 36 % (khớp số 36 % đã ghi trong active.md), Kiếm sĩ 48 %, Goblin trên sân Hỏa Ngục 33 %, Lính Gác
Rêu (đá, đã duyệt) trên sân Hỏa Ngục **5 %**.

| Id | % | Id | % | Id | % |
|---|---|---|---|---|---|
| imp v2 | 10 | ember_hound | 9 | ash_golem | 12 |
| flame_cultist | 11 | magma_slug | 19 | hell_knight | 17 |
| fire_eater v2 | 14 | ash_phoenix v2 | 30 | inferno_lord | 13 |

Nhận định: ngưỡng 40 % của bible không sprite nào đã duyệt đạt trên nền tối này; bằng mắt (ảnh mock) cả 9 con tách khỏi sân nhờ viền
Mực kín, mảng ochre/đồng và điểm Ngà (mắt, răng, sừng); hàng báo đòn đỏ phía sau làm thân than nổi hơn chứ không chìm. Đã thử
remap cơ học tông giữa (`#4A4640→#6A6B62`, `#5A5650→#D8CDB0`): số lên 32–51 % nhưng Hiệp sĩ / Chúa Quỷ Lửa thành trắng xương,
mất chất than Hỏa Ngục → **không áp dụng**; giữ bản gốc. Nếu playtest thấy chìm, phương án sau là rim-light Ngà do code (overlay
chung, không vẽ tay) — ghi ở §11.3.


### 12.4 Checkpoint B — prompt clip (soạn trước, CHỜ "yes"; `animate_character` mode pixminimax, direction south-west, 8 khung, 1 gen mỗi lệnh; chỉ động tác, không từ phủ định)

| Clip | Mẫu prompt (đổi chủ ngữ theo con) | Khung giữ (theo roster rừng) |
|---|---|---|
| idle | "<subject> breathing slowly in place, chest rising and falling, head sways one pixel" | 4 khung 250 ms lặp |
| step | "<subject> takes a quick short hop to the side and settles" | 4 khung 100 ms |
| windup | "<subject> crouches and draws back its weapon / body, tensing, then holds the pose" | 4 khung 100/100/100/0 giữ cuối |
| hit | "<subject> recoils backward from a blow to the chest, then straightens" | 3 khung 40 ms |
| down | "<subject> staggers, sinks to its knees and collapses onto the ground, lying still" | 6 khung 100/120/150×4 giữ cuối |

Chủ ngữ từng con (subject_description): imp "a small charcoal imp with a trident" · ember_hound "a gaunt charcoal hound" · ash_golem
"a squat grey ash golem" · flame_cultist "a hooded cultist with an ivory mask and a staff" · magma_slug "a low obsidian-plated slug" ·
hell_knight "a horned knight in charcoal plate with a greatsword" · fire_eater "a wide pot-bellied charcoal ogre-demon" · ash_phoenix
"an ash-grey phoenix perched upright" · inferno_lord "a towering horned demon lord in charcoal plate with a greatsword". Động vật:
hound step = "trots two steps and stops", windup = "lowers its head and bares its teeth, haunches tense, holds"; sên: step = "inches
forward and settles", windup = "rears the front of its body up, holds"; phượng: step = "hops once with a wing flick", windup = "spreads
both wings wide and arches back, holds", down = "folds its wings, slumps forward onto the ground, lying still".

---

## 13. Checkpoint A — Sa Mạc: 9 lệnh anchor (soạn 2026-11-13, CHỜ "yes" từng lệnh)

Tham số chung như §12.1 (style Goblin v3, colour off, low top-down, seed 1, `max_colors 8`, câu kết "transparent background, no
ground shadow, no glow, no red, no orange, no gradient"). Nền Sa Mạc **sáng** (V 60–72) → mỗi con có **mảng tối lớn** (Mực / be tối
`#6E6248` / Đá tối) ở nửa trên; be `#A89A80` chỉ ở mặt sáng. Chiều cao: thường 36–50, Tinh Anh ~72, Kẻ Gác ~80 (96×96, ngồi thẳng).
Bài học Hỏa Ngục: ghi rõ "small, about 36 px" cho con nhỏ và "fills the whole canvas height" cho Tinh Anh / Kẻ Gác ngay lần đầu.

| # | Id | Canvas | Prompt (EN) | Palette khoá (≤ 8) | Gen |
|---|---|---|---|---|---|
| 1 | `dune_jackal` | 64×64 (dog) | "lean desert jackal standing on all four legs, about 36 px tall, big upright ears, dark grey-brown back with sand dusted along the spine, pale beige belly, tucked tail, 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #4A4640 #6E6248 #A89A80 #EFE6D2 | 6 |
| 2 | `sand_beetle` | 64×64 | "low round sand beetle, about 30 px tall and 44 px long, domed sandstone-coloured shell with dark angular plates, short horn, six stubby dark legs, 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #4A4640 #6E6248 #A89A80 #EFE6D2 | 6 |
| 3 | `dust_nomad` | 64×64 | "tall desert nomad, about 48 px tall, wrapped head to toe in faded grey-green cloth, face fully covered except a dark eye slit with 2x2 ivory eyes, a loose scarf trailing to one side, holding a short curved sword low in the near hand, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #5E6150 #7E8068 #6E6248 #A89A80 #EFE6D2 | 6 |
| 4 | `mirage_sprite` | 64×64 | "hovering hollow figure made of sand, about 44 px tall, dark empty hood shape with 2x2 ivory eyes, the lower half breaking apart into square sand grains that reach the ground, pale beige and dark beige, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #6E6248 #A89A80 #EFE6D2 | 6 |
| 5 | `scarab_guard` | 64×64 | "upright scarab-beetle warrior, about 48 px tall, dark sandstone chitin armour, beetle-horn helmet with an ivory crest, round dull-jade shield on the far arm, short spear in the near hand, 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #4A4640 #6E6248 #A89A80 #4F8A80 #EFE6D2 | 6 |
| 6 | `sun_archer` | 64×64 | "desert archer, about 50 px tall, flat round dull-beige sun-disc headdress, dark wrapped robe with an ochre sash, quiver on the back, a long curved bow held in the near hand, face shadowed with 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #6E6248 #A89A80 #8A6A40 #EFE6D2 | 6 |
| 7 | `sand_burrower` (E) | 80×80 | "huge burrowing sand worm rearing up out of a mound of sand, filling the whole canvas height, about 72 px tall, segmented dark sandstone body, wide open circular maw ringed with ivory teeth, the sand mound at the base, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #4A4640 #6E6248 #A89A80 #EFE6D2 | 6 |
| 8 | `scorpion` (E) | 80×80 | "giant sandstone scorpion, wide and low body but the tail curled high over its back so it fills the whole canvas height, about 72 px tall, big dark pincers raised, dull-jade stinger segments, 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #4A4640 #6E6248 #A89A80 #4F8A80 #EFE6D2 | 6 |
| 9 | `sand_sphinx` (Kẻ Gác) | 96×96 | "great sphinx seated upright on its haunches filling the whole canvas height, about 80 px tall, human-like head with a horned headdress, dark stone face with 2x2 ivory eyes, an ochre belt set with dull-jade stones, two folded stone-slab wings behind the shoulders, tail curled round the paws, weathered sandstone body, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #4A4640 #6E6248 #A89A80 #8A6A40 #4F8A80 #EFE6D2 | 7 |

Tổng 55 gen (+ tối đa 18 nếu gen lại). Likeness kiểm trước: jackal ↔ Anubis (không đen tuyền, không vàng); nomad ↔ Tusken Raider
(không kính/ống thở); burrower ↔ Graboid; scorpion ↔ Scorpion (Mortal Kombat) tên trùng nhưng là bọ cạp thật; sphinx ↔ Gizeh
(ngồi dọc, sừng, cánh phiến). So với Hỏa Ngục: hound ↔ jackal tách bằng tai dựng + bụng be sáng; slug ↔ beetle tách bằng mai vòm
+ 6 chân; knight ↔ scarab_guard tách bằng mũ bọ + khiên tròn ngọc.

### 13.1 Checkpoint A Sa Mạc — kết quả (2026-11-13, người dùng "Yes, 9 anchor Sa Mạc", 55 gen)

Rotation `design/assets/candidates/sands/<id>/rot/`, sheet `sands-anchors-sw-x3.png`. Đo `sprite_measure.gd`:

| Id | Character id | bbox SW (cao) | Màu | Giống ai nhất → khác ở | Verdict |
|---|---|---|---|---|---|
| dune_jackal | `4542cd72-2e30-41b4-b546-a21744fc8f69` | 38×46 | 5 | Anubis / Jackal (Disney) → xám-nâu, bụng be, không đen | **ĐẠT** (cao hơn "36" đã xin nhưng vẫn ≤ 50; tai dựng, bụng sáng tách rõ Chó Than Hồng) |
| sand_beetle | `05734c38-ac7e-4610-880e-26684cabb585` | 46×36 | 6 | Scarab (The Mummy) → mai vòm sa thạch mờ, 6 chân | **ĐẠT** |
| dust_nomad | `12c54020-b917-4279-a978-5dc1d2583963` | 43×47 | 7 | Tusken Raider / xác ướp → vải xanh-xám quấn, khăn bay, kiếm cong | **ĐẠT** |
| mirage_sprite | `c161a7ac-6393-429e-a4d0-ae3c92abec5d` | 27×47 | 5 | Sandman → mũ trùm rỗng, nửa dưới hạt cát | **ĐẠT** |
| scarab_guard | `5ddb67f8-bb5d-473d-aad2-3ce1d26043bc` | 34×46 | 6 | Scarab knight → mũ bọ Ngà, khiên ngọc đục, giáo | **ĐẠT** |
| sun_archer | `99d86dc8-da50-4e0f-bd87-04b18e68d66d` | 25×45 | 6 | Monk / Dust Nomad | **CHƯA ĐẠT về đa dạng**: đĩa mặt trời thành mũ trùm tròn, cung nhỏ sát thân → trông như con nomad thứ hai; đề nghị gen lại 1 lần "wide flat disc crown, bow held out to the side" |
| sand_burrower (E) | `0d35654a-693e-4f66-9943-5fe81cf61e43` | 45×73 | 6 | Graboid / Sarlacc → hàm tròn răng Ngà, gò cát | **ĐẠT** |
| scorpion (E) | `6ef0ca3f-c41d-4412-8fe3-665d981975e2` | 59×73 | 7 | bọ cạp thật → sa thạch, đốt đuôi ngọc đục | **ĐẠT** |
| sand_sphinx (Kẻ Gác) | `61b00049-4af1-4a53-9af7-f72f15f795fe` | 37×**58** | 7 | Sphinx Gizeh → sừng, đai ngọc | **CHƯA ĐẠT cỡ**: 58 px < Tinh Anh 73 (+4); "cánh phiến" thành tấm tròn sau lưng → gen lại 1 lần "about 84 px tall, head at the top edge, two flat stone-slab wings folded upright behind the shoulders" |

7/9 đạt; 2 chờ gen lại (12 gen).

### 13.2 Gen lại 1 lần (2026-11-13, người dùng "Yes, gen lại 2", 13 gen)

| Id | Character v2 | Thay đổi | Kết quả |
|---|---|---|---|
| sand_sphinx | `87c9efbd-1c9f-4653-ab52-f185a5df2ca8` (seed 2) | "very tall, about 84 px … headdress touching the top edge … two flat stone-slab wings folded upright behind the shoulders rising above the head" | **ĐẠT** 46×85 (y4-88), 7 màu: ngồi thẳng, mũ sừng, mặt đá tối, đai ochre + ngọc, cánh phiến sau vai, đuôi quanh chân; v1 `61b00049` (58 px) retired |
| sun_archer | `eb26b6aa-7c54-4883-90b2-080dd209e74e` (seed 2) | "wide flat round sun-disc crown standing up behind the head like a halo of stone … bow held out to the side with the string visible" | **ĐẠT** 27×48, 6 màu: vành đĩa be sau đầu, áo tối đai ochre, cung giơ bên; tách khỏi Du Mục Bụi (vải quấn sáng, kiếm); v1 `99d86dc8` retired |

Sheet `sands-regen-v2-x3.png` (nomad · archer v2 · scorpion · sphinx v2). **Checkpoint A Sa Mạc: 9/9 đạt, 68 gen** (55 + 13).
Bậc cao: thường 36–48 (beetle 36, archer 48, jackal/scarab 46, nomad/mirage 47) · Tinh Anh 73/73 · Kẻ Gác 85. Lớp bóng đen: bốn chân
(jackal), khối thấp (beetle, burrower), hai chân cao (nomad, scarab, archer), lơ lửng (mirage), nhiều chân thấp (scorpion), tượng ngồi
(sphinx). Tiếp: Checkpoint B 45 clip (prompt mẫu §12.4; chủ ngữ: "a lean desert jackal", "a low domed sand beetle", "a cloth-wrapped
desert nomad with a curved sword", "a hollow hooded figure of sand", "an upright scarab-beetle warrior with a shield and spear", "a hooded
desert archer with a sun-disc crown and a bow", "a huge sand worm rearing out of a mound", "a giant sandstone scorpion", "a great horned
sphinx seated upright"; windup riêng: beetle "lifts its front and raises its horn, holds", mirage "swells and its grains swirl upward,
holds", burrower "rears higher and opens its maw wide, holds", scorpion "raises the stinger tail high and spreads the pincers, holds",
sphinx "rises on its forepaws, wings spreading, holds"; step: burrower "sinks and resurfaces a little to the side", sphinx "shifts its
weight and settles"; down: burrower "slumps and sinks back into the sand mound, lying still", mirage "collapses into a pile of sand grains,
lying still", sphinx "slumps forward onto its paws, head down, lying still").

### 13.3 Checkpoint B Sa Mạc — 45 clip + cài đặt (2026-11-13, người dùng "Yes, 45 clip", 45 gen; tổng Sa Mạc **113 gen**)

Khung chọn (nguồn 0 = tham chiếu): idle 0/2/4/6 · step 1/3/5/7 · windup 2/4/6/8 (jackal 3/4/6/8) giữ cuối · hit 3/4/5 (mirage 5/6/7
vì 3–4 vẽ vòng cát như vệt chém; burrower 4/5/6 vì 1–3 có đạn trắng/**đỏ** vẽ sẵn; scorpion 4/5/6 vì 1–3 vệt trắng; sphinx 5/6/7 vì
2–4 mảnh đá văng; beetle 3/4/5 vì 2 có đốm cam) · down 2/3/4/5/6/8. Dọn cơ học như Hỏa Ngục.

| Id | Khung | Sheet | Palette thực tế | Gen |
|---|---|---|---|---|
| dune_jackal | 64×52 | `unit_dune_jackal_sheet.png` 389×264 | Ink, `#2C2925`, `#4A4640`, be tối, be, Ngà | 6+5 |
| sand_beetle | 70×52 | `unit_sand_beetle_sheet.png` 425×264 | Ink, `#2C2925`, `#4A4640`, be tối, be, Ngà | 6+5 |
| dust_nomad | 70×52 | `unit_dust_nomad_sheet.png` 425×264 | Ink, `#2C2925`, Hunter cloak ×2, be tối, be, Ngà | 6+5 |
| mirage_sprite | 64×52 | `unit_mirage_sprite_sheet.png` 389×264 | Ink, `#2C2925`, be tối, be, Ngà | 6+5 |
| scarab_guard | 80×52 | `unit_scarab_guard_sheet.png` 485×264 | Ink, `#2C2925`, `#4A4640`, be tối, be, ngọc, Ngà | 6+5 |
| sun_archer | 74×52 | `unit_sun_archer_sheet.png` 449×264 | Ink, `#2C2925`, be tối, be, ochre, Ngà | 6+6+5 |
| sand_burrower (E) | 80×80 | `unit_sand_burrower_sheet.png` 485×404 | Ink, `#2C2925`, `#4A4640`, be tối, be, Ngà | 6+5 |
| scorpion (E) | 80×81 | `unit_scorpion_sheet.png` 485×409 | Ink, `#2C2925`, `#4A4640`, be tối, be, ngọc, Ngà | 6+5 |
| sand_sphinx (Kẻ Gác) | 106×86 | `unit_sand_sphinx_sheet.png` 641×434 | Ink, `#2C2925`, `#4A4640`, be tối, be, ochre, ngọc, Ngà | 7+7+5 |

Registry +9 (`accepted`/`installed`), manifest 199 asset, reference ×9, `roster_sprite_test` +9 id (+4 thường, +2 Tinh Anh, Kẻ Gác
`sand_sphinx` ≥ Tinh Anh + 4), `.import` sinh (cờ khớp goblin). Line-up vùng: `region-enemies/21-lineup-sands-x2.png`; ba vùng cạnh
nhau: `22-lineup-three-regions-x1.png` (rừng xám-rêu · Hỏa Ngục than-đồng · Sa Mạc be-ngọc). QA trận và test: §13.4 (điền khi chạy nền xong).

---

## 14. Checkpoint A — Đầm Lầy: 9 lệnh anchor (soạn 2026-11-13, CHỜ "yes" từng lệnh)

Tham số chung như §12.1. Nền Đầm Lầy **tối** (V ≤ 40, nước đen, ô-liu) → mỗi con có **mảng sáng** (Ngà bụng / Nấm sáng `#8E8296` /
rêu sáng `#5E6B55`) ở nửa trên. Màu vùng: ô-liu `#4E4C3C`, bùn `#5A4A3A`, Rêu `#3A4538/#4A5545/#5E6B55`, Nấm `#4A3E4A/#6A5868/#8E8296`,
Ink, Ngà. Chiều cao ghi rõ ngay từ đầu (thường 36–50 "small"/"about N px", Tinh Anh "fills the whole canvas height, about 72",
Kẻ Gác "about 84, head at the top edge"). Kẻ Gác Cóc Chúa thấp-rộng theo bible → rộng ≤ 60 px, cao ~70 nhưng vẫn phải ≥ Tinh Anh + 4:
Tinh Anh Đầm Lầy nhắm 64–66 (không 72) để giữ bậc. **Cảnh báo lặp hình**: spore_cap ≠ Greycap rừng (một mũ dẹt rộng, không mắt, thân cao);
bog_hound ≠ ember_hound/dune_jackal (da nhăn ướt, hàm rộng, rong cổ, tai cụp dính); marsh_toad ≠ toad_matriarch (nhỏ, không nấm trên đầu).

| # | Id | Canvas | Prompt (EN) | Palette khoá (≤ 8) | Gen |
|---|---|---|---|---|---|
| 1 | `bog_rat` | 64×64 | "small wet swamp rat on all fours, about 34 px tall, matted mud-brown fur plastered flat, long bare pink-less dark tail, ivory front teeth, a strand of pale weed stuck across its back, 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #5A4A3A #4E4C3C #4A5545 #5E6B55 #EFE6D2 | 6 |
| 2 | `mire_slug` | 64×64 | "fat low mud slug, about 28 px tall and 48 px long, smooth rounded grey-violet body with a lighter slime sheen band, two eye stalks with 2x2 ivory eyes, a thin trail of slime, 1 px dark outline, flat shading, …" | #1B1722 #4A3E4A #6A5868 #8E8296 #5A4A3A #EFE6D2 | 6 |
| 3 | `swamp_lizard` | 64×64 | "long low swamp lizard on four splayed legs, about 36 px tall, olive-green scaled body, a wide ivory-edged neck frill raised, a row of short back spines, long curved tail, 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #3A4538 #4E4C3C #5E6B55 #5A4A3A #EFE6D2 | 6 |
| 4 | `marsh_toad` | 64×64 | "fat round marsh toad, about 40 px tall, olive warty back, large pale ivory throat and belly, bulging 2x2 ivory eyes on top of the head, short squat legs, a few small grey-violet warts, 1 px dark outline, flat shading, …" | #1B1722 #3A4538 #4E4C3C #5E6B55 #6A5868 #EFE6D2 | 6 |
| 5 | `reed_witch` | 64×64 | "thin stooped swamp witch, about 50 px tall, tall pointed hat woven from reeds, long robe of hanging wet weed and moss, face hidden under mossy hair with 2x2 ivory eyes, a reed staff in the near hand, a small basket of rotten pieces slung on the back, 1 px dark outline, flat shading, …" | #1B1722 #3A4538 #4A5545 #5E6B55 #5A4A3A #6A5868 #EFE6D2 | 6 |
| 6 | `bog_hound` | 64×64 (dog) | "heavy wet swamp hound standing on all four legs, about 40 px tall, hairless wrinkled mud-brown skin, wide jaw with ivory teeth, drooping ears plastered to the head, strands of dark weed hanging from the neck, 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #5A4A3A #4E4C3C #3A4538 #4A5545 #EFE6D2 | 6 |
| 7 | `spore_cap` (E) | 80×80 | "tall spore mushroom creature, about 66 px tall, one single very wide flat grey-violet cap like a plate, a thick pale ivory stalk body with no face, dark spore sacs hanging under the cap rim, mossy root base, 1 px dark outline, flat shading, …" | #1B1722 #4A3E4A #6A5868 #8E8296 #D8CDB0 #4A5545 #EFE6D2 | 6 |
| 8 | `leap_frog` (E) | 80×80 | "big swamp frog crouched ready to jump, about 64 px tall with very long folded hind legs, slim olive body, bulging 2x2 ivory eyes on top of the head, pale ivory belly, webbed feet, 1 px dark outline, flat shading, …" | #1B1722 #3A4538 #4E4C3C #5E6B55 #8FA070 #EFE6D2 | 6 |
| 9 | `toad_matriarch` (Kẻ Gác) | 96×96 | "enormous round toad queen seated low and wide, about 72 px tall and 60 px wide, olive warty body, three or four grey-violet mushrooms growing on top of her head, moss dripping from her back, big pale ivory throat and belly, one arm trailing behind, 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #3A4538 #4E4C3C #5E6B55 #4A3E4A #6A5868 #5A4A3A #EFE6D2 | 7 |

Tổng 55 gen (+ gen lại nếu cần). Likeness: bog_rat ↔ Rattata (không tím); mire_slug ↔ Gastropod; marsh_toad ↔ Toad/Politoed (cóc thật,
không mũ); reed_witch ↔ phù thủy cổ điển (lau sậy, không mũi dài); leap_frog ↔ Greninja (không khăn, ếch thật); spore_cap ↔ Greycap rừng
(khác: 1 mũ dẹt, không mắt, cao 66); toad_matriarch ↔ Cóc Chúa concept 08-warden-swamp (lấy dáng tròn + nấm, bỏ dây chuyền ô vuông).

### 13.4 QA Sa Mạc (2026-11-13, chạy nền `region-enemies/sands-tests-and-shots-2026-11-13.txt`)

- `sheet_export_test`, `sprite_sheet_test`, `unit_sprites_test`: FAILS=0. `roster_sprite_test`: 9 id mới có đủ 5 clip + facing left;
  Tinh Anh 73/73 ≥ thường 50 + 12; Kẻ Gác 85 ≥ Tinh Anh + 4. FAILS=0.
- Ảnh trận thật `region-enemies/10-sands-<id>-idle.png` ×9 (sân Cồn cát / Ốc đảo, có mũi tên GIÓ): tiêu đề xác nhận đúng con (Bọ Cát,
  Chó Rừng Cồn, Du Mục Bụi, Bóng Ảo Ảnh, Vệ Binh Bọ Hung, Xạ Thủ Mặt Trời, Tinh Anh Bọ Cát Ẩn, Tinh Anh Bọ Cạp Phản, Boss Nhân Sư Cát).
  Trên phiến sa thạch sáng, mảng tối (Mực, be tối) ở nửa trên tách rõ; ngọc đục đuôi bọ cạp và khiên bọ hung đọc được ở 1×; sphinx
  đứng tâm ô, đuôi/cánh không lấn ô bên. Không con nào chìm vào nền.
- Tracker §10.2: Sa Mạc 9/9 `G` (anchor + clip + cài + kiểm trận); `✓` sau khi người dùng duyệt clip.

### 14.1 Checkpoint A Đầm Lầy — kết quả (2026-11-13, người dùng "Yes, 9 anchor", 55 gen)

Rotation `design/assets/candidates/swamp/<id>/rot/`, sheet `swamp-anchors-sw-x3.png`.

| Id | Character id | bbox SW (cao) | Màu | Giống ai nhất → khác ở | Verdict |
|---|---|---|---|---|---|
| bog_rat | `3108ea6d-b5d0-451c-bc7d-e47012a561e1` | 32×42 | 5 | Rattata → bùn nâu, rong lưng | **ĐẠT** |
| mire_slug | `3f115179-d32e-4263-b57d-c78fe96da784` | 47×26 | 6 | Gastropod → xám tím, vệt nhầy | **ĐẠT** |
| swamp_lizard | `41a0beb0-471f-4fd2-a4b8-02f0a2088048` | 49×41 | 5 | Frilled lizard → diềm Ngà, gai lưng | **ĐẠT** |
| marsh_toad | `4a8bf2b9-79e2-4383-b92e-eeff3ae9410f` | 41×36 | 5 | Politoed → cóc thật, bụng Ngà | **ĐẠT** |
| reed_witch | `93fbb976-4bd6-4997-b2aa-cc4b8075709b` | 36×52 | 6 | Gandalf / phù thủy cổ điển → mũ lau sậy, áo rong, giỏ sau lưng | **ĐẠT** (cao nhất nhóm thường: 52) |
| bog_hound | `2361b055-829e-4f8b-bd2e-f61d880724b5` | 41×44 | 6 | Hyena → da nhăn, hàm rộng, rong cổ; khác Chó Than Hồng / Chó Rừng Cồn | **ĐẠT** |
| spore_cap (E) | `3604dc0d-059c-47c8-846c-340780266d24` | 48×**52** | 7 | Greycap rừng → một mũ dẹt, không mắt, túi bào tử | thiết kế đạt, **thấp**: 52 = thường → gen lại "about 68 px, cap touching the top edge" |
| leap_frog (E) | `76d61629-3d97-4a6e-81be-b2f634fd6b9f` | 43×**39** | 6 | Greninja → ếch thật | thiết kế đạt, **thấp**: 39 → gen lại "sitting upright tall, about 66 px, head at the top edge" |
| toad_matriarch (Kẻ Gác) | `4e08740c-dd9a-4bd2-8c42-60c9e0de3a57` | 57×**52** | 7 | Cóc Chúa concept → tròn rộng, 3–4 nấm, bụng Ngà | thiết kế đạt, **thấp**: 52 → gen lại "about 76 px tall and 64 wide, mushrooms touching the top edge" |

6/9 đạt; 3 chờ gen lại (19 gen). Bài học: với sinh vật thấp bản chất (nấm, ếch, cóc) model vẫn thu nhỏ dù đã ghi "about N px" → phải ghi
"touching the top edge of the frame" ngay từ đầu.

### 14.2 Gen lại 1 lần (2026-11-13, người dùng "Yes, gen lại 3", 19 gen) — sheet `swamp-regen-v2-x3.png` (witch · spore_cap v2 · leap_frog v2 · matriarch v2)

| Id | Character v2 | bbox SW | Nhận xét |
|---|---|---|---|
| spore_cap | `2b0dccb3-d2a6-4e98-998e-06a777c983ca` | 53×**78** (y1-78) | **ĐẠT**: mũ dẹt rộng chạm mép trên, thân Ngà cao, túi bào tử treo, rễ rêu; v1 `3604dc0d` retired |
| leap_frog | `320c81ba-7698-46f2-b192-372de5d6745b` | 31×**62** | ếch ngồi thẳng, mắt lồi, bụng Ngà — đẹp, nhưng **62 < 64** (thường cao nhất = reed_witch 52 + 12). Hai cách: (a) chấp nhận theo tiền lệ Sói Đầu Đàn (sinh vật thấp bản chất, so với nhóm thường không tính witch: hound 44 → +18); (b) gen lại lần 3 (6 gen) |
| toad_matriarch | `c773c9a5-4885-4fae-b6bd-0859e54be123` | **79×75** (y11-85) | Cóc Chúa đúng bible "tròn, rộng, thấp": nấm trên đầu, rêu nhỏ giọt, bụng Ngà, tay sau kéo. Cao 75 < spore_cap 78 nên **luật Kẻ Gác theo chiều cao (+4) không đạt**, nhưng khối thân: matriarch 3529 px đục vs spore_cap 2028 px (×1.7) — "càng to" theo khối thì đạt rõ |

Đối chiếu các Kẻ Gác khác (px đục): inferno_lord 2362 vs fire_eater 2798; sand_sphinx 2589 vs scorpion 2031.
**Đề xuất**: giữ matriarch v2 và đổi luật Kẻ Gác 1 ô trong `roster_sprite_test` thành "cao hơn Tinh Anh ≥ 4 px **hoặc** khối đục ≥ 1,5× Tinh Anh
lớn nhất" (bible §5.2 cho phép Kẻ Gác thấp-rộng); leap_frog: chấp nhận 62 theo tiền lệ sói (đo với nhóm thường trừ witch) — cần người dùng quyết.

### 14.3 Quyết định người dùng (2026-11-13, "Yes, chấp nhận"): giữ leap_frog v2 (62 px, đo với nhóm thấp của vùng như tiền lệ sói) và
toad_matriarch v2 (Kẻ Gác thấp-rộng, đạt theo khối ≥ 1,5× Tinh Anh). `roster_sprite_test`: thêm `LOW_ELITES` (ếch vs rat/slug/lizard/
toad/hound + 12), Kẻ Gác 1 ô = cao hơn ≥ 4 px **hoặc** khối đục ≥ 1,5× (`_idle_art_area`); áp cho cả inferno_lord / sand_sphinx (vẫn
đạt theo chiều cao). **Checkpoint A Đầm Lầy: 9/9 đạt, 74 gen** (55 + 19). v1 retired: spore_cap `3604dc0d`, leap_frog `76d61629`,
toad_matriarch `4e08740c`. Bậc: thường 26–52 · Tinh Anh 62 (ếch, thấp bản chất) / 78 · Kẻ Gác 75 cao × 79 rộng.

### 14.4 Checkpoint B Đầm Lầy — 45 clip + cài đặt (2026-11-13, người dùng "Yes, 45 clip", 45 gen; tổng Đầm Lầy **119 gen**)

Khung chọn: idle 0/2/4/6 · step 1/3/5/7 · windup 2/4/6/8 · hit 3 khung bỏ khung có hiệu ứng vẽ sẵn (slug 3–4 bùn bắn → 5/6/7; toad 2–4
vệt Ngà → 5/6/7; witch 3 nét đứt → 4/5/6; spore 1–4 khối + vạch → 5/6/7; frog 3–4 vệt → 5/6/7; matriarch 2–5 khối tối → 6/7/8) ·
down 2/3/4/5/6/8. Miệng mở bị model tô **đỏ** ở windup của rat / lizard / hound: palette snap đổi sang màu bùn/ô-liu (không còn đỏ).
Ghi chú: rat `down` model tô bụng rêu (trong palette, giữ); matriarch `hit/0` còn 1 chấm tối nhỏ bên trái (≥ 12 px nên không bị lọc) — chấp nhận.

| Id | Khung | Sheet | Gen |
|---|---|---|---|
| bog_rat | 74×52 | `unit_bog_rat_sheet.png` 449×264 | 6+5 |
| mire_slug | 64×52 | `unit_mire_slug_sheet.png` 389×264 | 6+5 |
| swamp_lizard | 68×53 | `unit_swamp_lizard_sheet.png` 413×269 | 6+5 |
| marsh_toad | 64×52 | `unit_marsh_toad_sheet.png` 389×264 | 6+5 |
| reed_witch | 76×53 | `unit_reed_witch_sheet.png` 461×269 | 6+5 |
| bog_hound | 66×52 | `unit_bog_hound_sheet.png` 401×264 | 6+5 |
| spore_cap (E) | 80×80 | `unit_spore_cap_sheet.png` 485×404 | 6+6+5 |
| leap_frog (E) | 80×80 | `unit_leap_frog_sheet.png` 485×404 | 6+6+5 |
| toad_matriarch (Kẻ Gác) | 104×84 | `unit_toad_matriarch_sheet.png` 629×424 | 7+7+5 |

Registry +9 (`accepted`/`installed`), manifest 208 asset, reference ×9, test mở rộng ở §14.3. Import + test + ảnh trận chạy nền
(`region-enemies/swamp-tests-and-shots-2026-11-13.txt`) — §14.5.

---

## 15. Checkpoint A — Hầm Ngục: 10 lệnh anchor (soạn 2026-11-13, CHỜ "yes" từng lệnh)

Nền **tối** (V ≤ 30, tường ngục xám lam) → mảng sáng Ngà (xương, mặt nạ, răng) ở nửa trên. Màu vùng: xám lam `#3E4450`, gỉ `#6B4A3A`,
ochre `#8A6A40` (xích), Đá `#2C2925/#4A4640/#5A5650/#6A6B62`, Ink, Ngà. `skeleton` chỉ ở pool battle t0 (không ra ở tầng 5 hiện tại)
nhưng vẫn là roster → làm. Chiều cao ghi kiểu "touching the top edge" cho Tinh Anh / Kẻ Gác ngay lần đầu. Tách hình: `rat_king_guard` ≠
`bog_rat` (đứng 2 chân, giáp, giáo); `cultist` ≠ `flame_cultist` (mặt nạ trơn hình bầu dục, không gậy đuốc, chuỗi ochre); `ghost` là gốc
của biến thể `ghost_elite` (Tháp Băng, script) → giữ thân đơn giản, mảng lớn để recolour.

| # | Id | Canvas | Prompt (EN) | Palette khoá (≤ 8) | Gen |
|---|---|---|---|---|---|
| 1 | `skeleton` | 64×64 | "skeleton soldier, about 46 px tall, dull ivory bones, a sunken rusty iron helmet, a cracked round wooden shield on the far arm, a short rusty sword in the near hand, dark eye sockets, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #4A4640 #6B4A3A #D8CDB0 #EFE6D2 | 6 |
| 2 | `zombie` | 64×64 | "shambling dungeon zombie, about 46 px tall, lopsided shoulders, one arm hanging long, grey-blue rotting skin, torn mouldy rags, ivory teeth, 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #3E4450 #5A5650 #6B4A3A #EFE6D2 | 6 |
| 3 | `bat_swarm` | 64×64 | "a tight cluster of four dungeon bats flying together in a rough ball, wings spread, dark grey-blue fur, 2x2 ivory eyes, the lowest bat near the bottom of the frame, about 40 px tall, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #3E4450 #4A4640 #EFE6D2 | 6 |
| 4 | `slime` | 64×64 | "dungeon slime blob, about 38 px tall, rounded drooping grey-blue body with lighter top and darker bottom bands, an old ivory skull and bones visible inside it, slime drips at the base, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #3E4450 #5A5650 #6A6B62 #EFE6D2 | 6 |
| 5 | `ghost` | 64×64 | "hovering dungeon ghost in a ragged hooded shroud, about 46 px tall, pale grey cloth, the ragged hem trailing down to the bottom of the frame, dark hollow face with 2x2 ivory eyes, a short rusty chain hanging from one wrist, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #4A4640 #6A6B62 #6B4A3A #EFE6D2 | 6 |
| 6 | `reacter` | 64×64 | "crouching dungeon guardian statue of grey stone, about 44 px tall, ready to spring, joints bound with rusty chains, a single ivory eye on one side of its blocky head, square-cut shoulders, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #4A4640 #5A5650 #6B4A3A #8A6A40 #EFE6D2 | 6 |
| 7 | `cultist` | 64×64 | "dungeon cult acolyte in a long dark grey-blue hooded robe, about 48 px tall, a plain smooth oval ivory mask, a string of dull ochre beads, a curved ritual dagger held low in the near hand, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #3E4450 #4A4640 #8A6A40 #EFE6D2 | 6 |
| 8 | `rat_king_guard` | 64×64 | "upright rat-man soldier, about 48 px tall, standing on two legs in rusty iron armour with a barred visor helmet, long bare tail, ivory front teeth, a spear in the near hand, a square shield with iron bars on the far arm, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #4A4640 #5A4A3A #6B4A3A #8A6A40 #EFE6D2 | 6 |
| 9 | `jailer` (E) | 80×80 | "huge pot-bellied jailer filling the whole canvas height, about 72 px tall with the top of his leather hood touching the top edge, leather apron, a ring of ivory keys at the belt, a dull ochre chain wrapped round his waist, a heavy chain flail in the near hand, 2x2 ivory eyes in the hood, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #4A4640 #5A4A3A #6B4A3A #8A6A40 #EFE6D2 | 6 |
| 10 | `ogre_king` (Kẻ Gác) | 96×96 | "massive grey stone ogre king filling the whole canvas height, about 84 px tall, very broad shoulders and a small head with an ivory crown touching the top edge, a long ivory beard, rusty ochre chains across the chest and wrists, a heavy stone club held low in the near hand, 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #4A4640 #5A5650 #6A6B62 #8A6A40 #6B4A3A #EFE6D2 | 7 |

Tổng 61 gen. Likeness: skeleton ↔ Minecraft skeleton (mũ gỉ, khiên mục, kiếm); zombie ↔ Minecraft zombie (vai lệch, áo mốc); bat_swarm ↔
Zubat (đàn 4 con); slime ↔ Dragon Quest slime (không mặt cười, xương bên trong); ghost ↔ Pac-Man / Boo (áo rách, xích); reacter ↔ Weeping
Angel (khớp xích, một mắt); cultist ↔ Bloodborne (mặt nạ trơn); rat_king_guard ↔ Skaven (không đỏ, khiên chấn song); jailer ↔ Hades
(Thanatos/Cerberus?) → chìa khoá Ngà, mũ trùm da; ogre_king ↔ Shrek (vương miện, râu, xích, đá xám).

### 14.5 QA Đầm Lầy (2026-11-13, chạy nền `region-enemies/swamp-tests-and-shots-2026-11-13.txt`)

- 4 suite sprite FAILS=0. `roster_sprite_test` với luật mới: spore_cap 78 ≥ 52 + 12; leap_frog 62 ≥ nhóm thấp 44 + 12; toad_matriarch lớn
  hơn cả hai Tinh Anh theo khối (3529 vs 2028 / 1237 px đục); inferno_lord / sand_sphinx vẫn đạt theo chiều cao.
- Ảnh trận `region-enemies/10-swamp-<id>-idle.png` ×9 (sân Đầm lầy / Mê cung lau sậy, ô lầy có bọt): đúng con theo tiêu đề; Phù Thủy
  Lau Sậy và Nấm Bào Tử đứng tâm ô, mảng Ngà/Nấm sáng nổi trên nước đen.
- **Phát hiện cần kiểm**: ở ảnh Boss Cóc Chúa (khung 40) thân con boss trông **mờ như trong suốt**, thấy chấm ô lầy xuyên qua; xem lại ảnh
  cũ, Chúa Quỷ Lửa / Phượng Tro ở khung 40 cũng có hàng báo đòn đỏ phủ lên thân. **Đã xác định: hiệu ứng mở trận của boss, không phải lỗi
  sprite** — chụp lại `11-swamp-toad_matriarch-frame300.png`: Cóc Chúa đục hoàn toàn, đang ở `windup` (cổ họng phình Ngà, tay giơ), vòng
  báo đòn quanh chân, đứng tâm ô; ô đỏ báo đòn bên người chơi. Ảnh khung 40 của mọi Kẻ Gác/Tinh Anh chụp trong lúc mở trận nên trông mờ.
- Tracker §10.2: Đầm Lầy 9/9 `G`.

### 15.1 Checkpoint A Hầm Ngục — kết quả (2026-11-13, người dùng "Yes, 10 anchor", 61 gen)

Rotation `design/assets/candidates/dungeon/<id>/rot/`, sheet `dungeon-anchors-sw-x3.png`.

| Id | Character id | bbox SW (cao) | Giống ai nhất → khác ở | Verdict |
|---|---|---|---|---|
| skeleton | `20e4a563-3abd-4c7b-bfc9-e9ed0655a776` | 31×47 | Minecraft skeleton → mũ sắt gỉ, khiên tròn, kiếm gỉ | **ĐẠT** |
| zombie | `30752a1f-3ea8-4bc9-bd86-beb00ba66ae4` | 26×46 | Minecraft zombie → vai lệch, tay dài | **ĐẠT có lưu ý**: gần như toàn xám lam tối, ít Ngà → trên sân ngục tối có thể chìm; sẽ kiểm trong trận, nếu chìm thì xin gen lại |
| bat_swarm | `bf15c563-5a35-4bc9-8e80-c518d2746861` | 41×43 | Zubat → đàn 4 con | **ĐẠT** (4 dơi rời nhau, không thành khối tròn; đọc như đàn) |
| slime | `6858a57e-6a1a-4d0d-8fb0-c0d343198071` | 34×42 | Dragon Quest slime → khối xám lam, sọ + xương Ngà bên trong | **ĐẠT** |
| ghost | `a6b5e8c1-3d32-4d77-82a3-e1e3be7221e0` | 26×45 | Boo / Dementor → áo rách, mặt rỗng, xích gỉ | **ĐẠT** (gốc cho biến thể `ghost_elite`) |
| reacter | `c2dc350c-c50b-466c-835d-009a9337e74a` | 38×48 | Golem (Clash) → một mắt Ngà, thân gỉ, xích ở khớp | **ĐẠT** (màu gỉ chiếm chủ đạo thay vì đá xám — tách tốt khỏi Khôi Tro Hỏa Ngục) |
| cultist | `9e055524-f541-426b-8f7f-5df3cc9deeef` | 28×47 | Bloodborne cultist → mặt nạ bầu dục Ngà, chuỗi ochre, dao cong | **ĐẠT** (khác Tín Đồ Lửa: áo xanh đêm, không gậy) |
| rat_king_guard | `c57ac28f-035e-490c-8494-6d0b35c69be6` | 41×49 | Skaven → giáp gỉ, mũ chấn song, khiên chấn song, giáo | **ĐẠT** |
| jailer (E) | `2a521dd6-8bfe-4bc8-9581-882811897c4c` | 49×69 | Executioner (Darkest Dungeon) → mũ trùm, chìa khoá Ngà, chùy xích | **ĐẠT** (69 ≥ 49 + 12) |
| ogre_king (Kẻ Gác) | `d9765f61-9687-42f7-9d39-12e6ac71e22e` | 55×**68** | Shrek → vương miện + râu Ngà, xích gỉ, chùy đá | thiết kế đạt, **cỡ chưa đạt**: cao 68 < jailer 69, khối 2121 vs 1930 px (×1,1) → không đạt cả hai luật Kẻ Gác → **gen lại 1 lần** "about 86 px, crown touching the top edge, very wide" (7 gen) |

9/10 đạt; ogre_king chờ gen lại.

### 15.2 Gen lại ogre_king (2026-11-13, người dùng "Yes, gen lại ogre", 7 gen)

Character v2 `6e3d1533-8be4-440d-b5d6-9da47a53336c` (seed 2): bbox 61×**81**, khối 3146 px (×1,6 Cai Ngục) → **đạt cỡ** Kẻ Gác. Nhưng model
dùng ochre `#8A6A40` + gỉ `#6B4A3A` làm **da** → thành ogre da nâu, lệch bible "Đá xám". So sánh `ogre-v1-v2-grey-x3.png`
(v1 · v2 gốc · v2 remap · Cai Ngục): bản **v2-grey** là remap cơ học 2 màu (`#8A6A40→#5A5650`, `#6B4A3A→#4A4640`, không vẽ tay) → da
đá xám đúng bible, nhưng xích ngực/cổ tay cũng thành xám tối (mất "xích gỉ ochre" của bible). Hai lựa chọn: (a) v2-grey — ưu tiên chất
đá; (b) v2 gốc — giữ xích ochre nhưng da nâu. **Đề xuất (a)**: chất đá là dấu loài lớn nhất, xích vẫn đọc được bằng nét tối.

**Quyết định người dùng (2026-11-13):** chọn **v2 da xám (remap cơ học)**. Lý do người dùng nêu: đúng nhận diện đá xám của bible (quan
trọng hơn màu xích); cỡ đã đạt (81 px, khối ×1,6 Cai Ngục); tránh Ogre / Cai Ngục / Lính Gác Chuột Vương cùng tông nâu-gỉ; xích vẫn đọc
bằng nét tối. Xích xám tối là đánh đổi tạm thời, **không tô tay** để khôi phục ochre. Bible §5.2 hàng Quỷ Khổng Lồ đã ghi chú. Mọi khung
clip của ogre_king sẽ qua cùng remap `#8A6A40→#5A5650`, `#6B4A3A→#4A4640` trước khi dọn. v1 `d9765f61` retired. Checkpoint A Hầm Ngục:
**10/10 đạt, 68 gen** (61 + 7). Chưa commit cho đến khi người dùng review clip.

### 15.3 Checkpoint B Hầm Ngục — 50 clip + cài đặt (2026-11-13, người dùng "Yes, 50 clip", 50 gen; tổng Hầm Ngục **118 gen** = 61 + 7 + 50)

Ogre: 45 khung clip đều qua remap xám **trước** khi dọn (khung nâu gốc giữ ở `ogre_king/download/animations-raw-brown/`); palette dọn của
ogre không có ochre/gỉ → thân đá xám ở mọi clip (`ogre_king-clean-x2.png`). Khung hit bỏ hiệu ứng vẽ sẵn: zombie 2–3 vệt chấm,
reacter 1–4 mảnh văng, cultist 2–3 vệt chém + vòng, jailer 2–3 vệt chém + vòng. Slime hit = 3/5/8 (dẹp rồi hồi). Miệng đỏ windup zombie
→ snap palette. Zombie `down` dùng 3–8 (ngã muộn).

| Id | Khung | Sheet | Gen |
|---|---|---|---|
| skeleton | 80×52 | `unit_skeleton_sheet.png` 485×264 | 6+5 |
| zombie | 64×52 | `unit_zombie_sheet.png` 389×264 | 6+5 |
| bat_swarm | 64×52 | `unit_bat_swarm_sheet.png` 389×264 | 6+5 |
| slime | 72×52 | `unit_slime_sheet.png` 437×264 | 6+5 |
| ghost | 72×52 | `unit_ghost_sheet.png` 437×264 | 6+5 |
| reacter | 66×55 | `unit_reacter_sheet.png` 401×279 | 6+5 |
| cultist | 72×53 | `unit_cultist_sheet.png` 437×269 | 6+5 |
| rat_king_guard | 64×52 | `unit_rat_king_guard_sheet.png` 389×264 | 6+5 |
| jailer (E) | 84×80 | `unit_jailer_sheet.png` 509×404 | 6+5 |
| ogre_king (Kẻ Gác) | 96×84 | `unit_ogre_king_sheet.png` 581×424 | 7+7+5 |

Registry +10 (`accepted`/`installed`), manifest 218 asset, reference ×10, `roster_sprite_test` +10 id (thường đứng: skeleton / zombie /
ghost / reacter / cultist / rat_king_guard; Tinh Anh jailer; Kẻ Gác ogre_king vs jailer). QA nền: §15.4.

### 15.4 QA Hầm Ngục (2026-11-13, chạy nền `region-enemies/dungeon-tests-and-shots-2026-11-13.txt`)

- 4 suite sprite FAILS=0; Cai Ngục 69 ≥ thường 52 + 12; Quỷ Khổng Lồ lớn hơn Cai Ngục (81 px / 3146 đục vs 69 / 1930).
- Ảnh trận `region-enemies/10-dungeon-<id>-idle.png` ×10 (Tinh Anh và Boss chụp khung 240 để qua hiệu ứng mở trận). Zombie (lo ngại tối
  màu ở Checkpoint A): trên phiến tím mận của nửa địch, thân xám lam + viền Mực + mắt/răng Ngà vẫn tách rõ — **không cần gen lại**.
  Quỷ Khổng Lồ: vương miện và râu Ngà nổi trên tường ngục tối, thân đá xám đúng quyết định remap, đứng tâm ô.
- Tracker §10.2: Hầm Ngục 10/10 `G`.

---

## 16. Checkpoint A — Tháp Băng: 9 lệnh anchor + 1 biến thể script (soạn 2026-11-13, CHỜ "yes")

Nền **sáng** (trời 60–72, biển mây, tháp băng) → mảng **tối** (xanh đêm `#2E3450`, Mực) ở nửa trên; lam-xám `#4C5266` + rime sáng
`#A8B0C8` cho mặt sáng; **cấm cyan** `#A6EEFF` (vỏ Đóng Băng). `ghost_elite` = biến thể script của `ghost` Hầm Ngục (0 gen): đổi 2–3 màu
(xám → xanh đêm / rime) + phụ kiện ≤ 8×8 (vương miện băng Ngà) theo bible §5.6 — làm sau khi có duyệt hướng.
Tách hình: snow_wolf ≠ dire_wolf / jackal / hounds (lông dày sáng, bờm tuyết, mõm hẹp); stone_sentry ≠ ash_golem / reacter (mũ trụ tháp,
khiên đá, rime mép); ice_golem ≠ golems (khối băng vuông, hốc mắt Ngà, cao nhất nhóm thường); frost_mage ≠ cultists (mũ nhọn, cổ lông
Ngà, gậy băng); mist_lord ≠ inferno_lord (cao hẹp, áo rũ, mũ không mặt, gai băng một vai).

| # | Id | Canvas | Prompt (EN) | Palette khoá (≤ 8) | Gen |
|---|---|---|---|---|---|
| 1 | `frost_sprite` | 64×64 | "small hovering frost fairy, about 36 px tall, tiny body with a dress of grey-blue ice crystal shards, small folded frost wings, a trailing tail of mist reaching the bottom of the frame, dark night-blue face with 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #2E3450 #4C5266 #6E7282 #A8B0C8 #EFE6D2 | 6 |
| 2 | `wisp` | 64×64 | "floating will-o-wisp, about 40 px tall, a round lantern of dark ice hanging from a twisting tail of grey mist that reaches the bottom of the frame, two 2x2 ivory eyes inside the lantern, 1 px dark outline, flat shading, …" | #1B1722 #2E3450 #4C5266 #A8B0C8 #EFE6D2 | 6 |
| 3 | `stone_sentry` | 64×64 | "stone tower sentry, about 48 px tall, upright stone body with a tall tower helmet, frost rime along the edges, a square stone shield on the far arm, slit visor with 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #4A4640 #6A6B62 #4C5266 #A8B0C8 #EFE6D2 | 6 |
| 4 | `snow_wolf` | 64×64 (dog) | "snow wolf standing on all four legs, about 42 px tall, thick pale grey-white fur, a heavy snowy mane, narrow long snout, dark night-blue back stripe, ivory teeth, 2x2 dark eyes, 1 px dark outline, flat shading, …" | #1B1722 #2E3450 #6E7282 #A8B0C8 #EFE6D2 | 6 |
| 5 | `fuse_golem` | 64×64 | "squat square stone cannon golem, about 44 px tall, a short square ice-blue barrel mounted on its near shoulder, a coiled ivory fuse cord on its back, stubby legs, single ivory eye slit, 1 px dark outline, flat shading, …" | #1B1722 #2E3450 #4A4640 #4C5266 #6A6B62 #EFE6D2 | 6 |
| 6 | `rime_archer` | 64×64 | "hooded frost archer, about 50 px tall, night-blue hooded coat with a thick ivory fur collar, a long grey ice bow held in the near hand, quiver on the back, face in shadow with 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #2E3450 #4C5266 #6E7282 #A8B0C8 #EFE6D2 | 6 |
| 7 | `ice_golem` | 64×64 | "big blocky ice golem, about 50 px tall and wide, body of square grey-blue ice blocks cut at right angles, pale rime on the edges, deep dark eye holes with 2x2 ivory eyes, heavy square fists, 1 px dark outline, flat shading, …" | #1B1722 #2E3450 #4C5266 #6E7282 #A8B0C8 #EFE6D2 | 6 |
| 8 | `frost_mage` (E) | 80×80 | "tall frost mage filling the whole canvas height, about 72 px tall with the tip of the pointed hat touching the top edge, long night-blue robe, thick ivory fur collar, frost rime on the hem, a tall grey ice staff in the near hand, shadowed face with 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #2E3450 #4C5266 #6E7282 #A8B0C8 #EFE6D2 | 6 |
| 9 | `mist_lord` (Kẻ Gác) | 96×96 | "tall narrow frost lord filling the whole canvas height, about 86 px tall with the crown of ice spikes touching the top edge, long drooping night-blue robe, ivory fur collar, an empty dark hood with no face and two 2x2 ivory eyes, ice spikes on one shoulder only, hands hidden in long sleeves, 1 px dark outline, flat shading, …" | #1B1722 #2E3450 #4C5266 #6E7282 #A8B0C8 #EFE6D2 | 7 |

Tổng 55 gen. Câu kết "…" như §12.1 ("transparent background, no ground shadow, no glow, no cyan, no red, no orange, no gradient").
Likeness: frost_sprite ↔ Navi (không cánh sáng); wisp ↔ Chandelure-like (đèn băng, không lửa); stone_sentry ↔ Golem; snow_wolf ↔ Ghost
(GoT) / Mightyena (lông dày, bờm tuyết); fuse_golem ↔ cannon golem; rime_archer ↔ Legolas (mũ trùm lông, không tai nhọn); ice_golem ↔
Ice Golem (Clash, khối vuông); frost_mage ↔ Ice Wizard (không cyan); mist_lord ↔ Lich King (không mặt, gai một vai).

### 16.1 Checkpoint A Tháp Băng — kết quả (2026-11-13, người dùng "Yes, 9 anchor", 55 gen)

Rotation `design/assets/candidates/ice_tower/<id>/rot/`, sheet `ice-anchors-sw-x3.png` (wisp phải tải lại 1 lần — file đầu không phải PNG).

| Id | Character id | bbox SW (cao) | Giống ai nhất → khác ở | Verdict |
|---|---|---|---|---|
| frost_sprite | `c82795f8-221f-4f18-885a-4e4d458e75bd` | 22×46 | Navi → váy tinh thể xám-lam, đuôi sương | **ĐẠT** |
| wisp | `b1c290b0-7dad-4928-9eed-e1cee404bd66` | 19×51 | Will-o'-wisp → đèn lồng băng tối, đuôi khói | **ĐẠT** |
| stone_sentry | `ff8927dd-1080-45b5-9eae-b777aa9139e3` | 29×46 | Golem → mũ trụ tháp, khiên đá, rime mép | **ĐẠT** |
| snow_wolf | `eca3ebc1-2b13-4000-85f4-c78cb3c0f049` | 40×42 | Ghost (GoT) → lông xám-trắng dày, bờm, mõm hẹp; khác hẳn 4 con chó/sói khác | **ĐẠT** |
| fuse_golem | `c94076d4-a554-454a-abc0-025612ceaf16` | 38×45 | cannon golem → nòng vai, ngòi Ngà cuộn | **ĐẠT** |
| rime_archer | `42e4dc12-5896-4cd2-89f3-ea70ccd2b429` | 26×45 | Legolas → mũ trùm, cổ lông Ngà, cung băng | **ĐẠT** |
| ice_golem | `3488d67e-2a2a-415c-b1f0-ebe603bd56c1` | 39×49 | Ice Golem (Clash) → khối vuông, rime sáng, hốc mắt | **ĐẠT** |
| frost_mage (E) | `108e3360-e3ba-4d54-bc22-7b0357431071` | 45×74 | Black Mage / Ice Wizard → mũ nhọn, cổ lông Ngà, gậy băng, không cyan | **ĐẠT** (74 ≥ 51 + 12) |
| mist_lord (Kẻ Gác) | `85c86203-2bc0-4573-a6f8-9a64e2d565d6` | 36×88 | Lich King → mũ không mặt, vương miện gai băng, cổ lông, áo rũ | **ĐẠT** (88 ≥ 74 + 4) |

**9/9 đạt ngay lần đầu, 55 gen.** Không màu cyan nào.

**`ghost_elite` (0 gen, script):** `design/assets/candidates/ice_tower/ghost_elite/script-variant/` = toàn bộ 21 khung của `ghost` đổi cơ học
4 màu (`#6A6B62→#4C5266`, `#4A4640→#2E3450`, `#2C2925→#2E3450`, `#6B4A3A→#6E7282`) → áo xanh đêm, xích xám băng (so sánh
`ghost-vs-ghost_elite-x3.png`). Theo bible §5.6 biến thể còn cần **1 phụ kiện ≤ 8×8 ở nửa trên**; tôi **chưa thêm** vì vẽ phụ kiện là vẽ
tay. Phương án cơ học nếu muốn: cắt vương miện gai băng từ sprite Chúa Tể Băng Giá đã gen và ghép theo offset từng khung. Chờ người dùng.

### 16.2 Checkpoint B Tháp Băng — 45 clip + cài đặt (2026-11-13, người dùng "Yes, 45 clip", 45 gen; tổng Tháp Băng **100 gen**)

Khung chọn chuẩn; hit bỏ hiệu ứng vẽ sẵn (frost_sprite 3, snow_wolf 1–2, fuse_golem 3, rime_archer 2–3 vệt cyan, ice_golem 1–2 khối Ngà,
frost_mage 1–2 vệt). Model tô **cyan** cung của rime_archer ở windup/hit: palette snap chuyển hết sang rime xám — sheet không còn
`#A6EEFF` (kiểm grep JSON palette = 0). Kẻ Gác mist_lord khung 96×91 (vương miện gai + áo rũ khi windup dang tay).

| Id | Khung | Sheet | Gen |
|---|---|---|---|
| frost_sprite | 64×52 | `unit_frost_sprite_sheet.png` 389×264 | 6+5 |
| wisp | 64×52 | `unit_wisp_sheet.png` 389×264 | 6+5 |
| stone_sentry | 70×52 | `unit_stone_sentry_sheet.png` 425×264 | 6+5 |
| snow_wolf | 72×52 | `unit_snow_wolf_sheet.png` 437×264 | 6+5 |
| fuse_golem | 64×54 | `unit_fuse_golem_sheet.png` 389×274 | 6+5 |
| rime_archer | 74×52 | `unit_rime_archer_sheet.png` 449×264 | 6+5 |
| ice_golem | 66×53 | `unit_ice_golem_sheet.png` 401×269 | 6+5 |
| ghost_elite | 72×52 | `unit_ghost_elite_sheet.png` 437×264 | **0 (script)** |
| frost_mage (E) | 94×80 | `unit_frost_mage_sheet.png` 569×404 | 6+5 |
| mist_lord (Kẻ Gác) | 96×91 | `unit_mist_lord_sheet.png` 581×459 | 7+5 |

Registry +10 (9 pixellab + ghost_elite `provider: script`, attention ghi phụ kiện §5.6 còn chờ), manifest 228, reference ×9,
`roster_sprite_test` +10 id. QA nền §16.3.

---

## 17. Checkpoint A — Không Đảo: 9 lệnh anchor (soạn 2026-11-13, CHỜ "yes")

Nền **sáng** (trời 55–72, biển mây, đảo trôi, sét tĩnh) → mảng **tối** (Mực, đá đảo `#5A5048`, Đá tối) ở nửa trên; xám bão `#6A7080`
cho thân; vàng sấm đục `#B8A860` (S ≤ 30 %) chỉ nhấn nhỏ, **không vàng Ánh Lưới** `#FFD45C`. Sinh vật gió: cánh gập / vải bay một phía /
mây ở chân (chân mây là điểm neo hàng cuối). Tách hình: harpy ≠ mọi chim khác (thân người); storm_eagle ≠ gale_bird (đại bàng mõm móc,
cánh xòe ngang · chim gió đuôi dài, cánh gập dọc); cloud_sprite ≠ cloud_veil (cụm mây nhỏ có mắt · thần mây cao có mạng Ngà);
wind_monk ≠ dust_nomad (đầu trọc, áo vàng đục, trượng); sky_sentinel ≠ stone_sentry (cánh đá gập, dây thừng); storm_dragon = bible
§5.2 (rồng chữ S đứng, cánh gập, mây ở chân, sừng Ngà, **bỏ** sừng vàng và sét).

| # | Id | Canvas | Prompt (EN) | Palette khoá (≤ 8) | Gen |
|---|---|---|---|---|---|
| 1 | `cloud_sprite` | 64×64 | "small round storm cloud creature, about 36 px tall, a puffy cluster of dark grey cloud with a lighter top, two 2x2 ivory eyes, wisps of cloud at the bottom touching the ground, 1 px dark outline, flat shading, …" | #1B1722 #4A4640 #6A7080 #6A6B62 #EFE6D2 | 6 |
| 2 | `harpy` | 64×64 | "harpy, about 48 px tall, a lean woman-like body with bird legs and talons, grey-feathered wings folded behind the back, a wild crest of dark grey feathers, stone-brown feather tunic, 2x2 ivory eyes, crouched ready to leap, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #5A5048 #6A7080 #4A4640 #EFE6D2 | 6 |
| 3 | `wind_monk` | 64×64 | "wind monk, about 48 px tall, shaved head, a dull storm-yellow robe and a long sash blowing to one side, a long wooden staff held in the near hand, bare forearms, calm face with 2x2 dark eyes, 1 px dark outline, flat shading, …" | #1B1722 #5A5048 #6A7080 #B8A860 #8A6A40 #EFE6D2 | 6 |
| 4 | `storm_eagle` | 64×64 | "storm eagle standing on its talons with wings half spread, about 46 px tall, dark storm-grey feathers, a hooked ivory beak, a raised crest, dull storm-yellow streak on the wings, 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #4A4640 #6A7080 #B8A860 #EFE6D2 | 6 |
| 5 | `sky_sentinel` | 64×64 | "sky island sentinel statue, about 50 px tall, wind-worn brown stone body with stone wings folded behind, frayed rope wrapped round the arms, a stone spear in the near hand, blank face with 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #5A5048 #4A4640 #6A6B62 #8A6A40 #EFE6D2 | 6 |
| 6 | `thunder_shaman` | 64×64 | "thunder shaman, about 50 px tall, a tall headdress of grey bird feathers, a dull storm-yellow cloak, a small hide drum at the hip, a feathered staff in the near hand, shadowed face with 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #5A5048 #6A7080 #B8A860 #EFE6D2 | 6 |
| 7 | `gale_bird` (E) | 80×80 | "huge gale bird filling the whole canvas height, about 72 px tall with its crest touching the top edge, standing upright with long wings folded down its sides, a very long tail of storm-grey feathers trailing to the ground, ivory beak, 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #4A4640 #6A7080 #5A5048 #EFE6D2 | 6 |
| 8 | `cloud_veil` (E) | 80×80 | "tall cloud spirit filling the whole canvas height, about 72 px tall, a column of dark storm cloud shaped like a robed figure, a long ivory veil hanging over an empty face with 2x2 ivory eyes, cloud wisps at the base touching the ground, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #4A4640 #6A7080 #6A6B62 #EFE6D2 | 6 |
| 9 | `storm_dragon` (Kẻ Gác) | 96×96 | "storm dragon standing upright in an S curve filling the whole canvas height, about 86 px tall with its head and two ivory horns touching the top edge, body narrow (about 40 px wide), storm-grey blue scales, wings folded tight against the body, a dull storm-yellow belly stripe, coils of cloud around its lower body touching the ground, 2x2 ivory eyes, 1 px dark outline, flat shading, …" | #1B1722 #2C2925 #4A4640 #6A7080 #5A5048 #B8A860 #EFE6D2 | 7 |

Câu kết "…" = "transparent background, no ground shadow, no glow, no lightning, no gold, no red, no orange, no gradient". Tổng 55 gen.
Likeness: cloud_sprite ↔ Lakitu cloud (mây xám, không mặt cười); harpy ↔ Harpy (Castlevania, cánh gập, có tunic); wind_monk ↔ Aang
(không mũi tên, áo vàng đục); storm_eagle ↔ Braviary; sky_sentinel ↔ Gargoyle; thunder_shaman ↔ WoW shaman; gale_bird ↔ Roc;
cloud_veil ↔ Dementor / Mistbriar (mây, mạng Ngà); storm_dragon ↔ Shenron / Haku (cánh gập, sừng Ngà, đứng chữ S).

### 16.3 QA Tháp Băng (2026-11-13, chạy nền `region-enemies/ice-tests-and-shots-2026-11-13.txt`)

- 4 suite sprite FAILS=0; Pháp Sư Sương 74 ≥ thường 52 + 12; Chúa Tể Băng Giá 88 ≥ 74 + 4 (khối hai con bằng nhau ~1960 px — đạt theo chiều cao).
- Ảnh trận `region-enemies/10-ice-<id>-idle.png` ×10 (Tinh Anh, Boss khung 240). Chúa Tể Băng Giá đang windup dang tay, vương miện gai
  và cổ lông Ngà nổi trên phiến tím; Người băng (sáng nhất vùng) nổi rõ trên phiến tối. **Lưu ý `ghost_elite`**: bản recolour xanh đêm
  đứng trên phiến tím mận của nửa địch tương phản thấp (chỉ viền Mực + mắt Ngà); vẫn đọc được bóng đen, nhưng kém `ghost` gốc. Nếu
  người dùng thấy chìm: đổi map áo sang `#6E7282` (sáng hơn 1 bậc) — vẫn cơ học, 0 gen.
- Tracker §10.2: Tháp Băng 10/10 `G` (9 PixelLab + ghost_elite script).

### 17.1 Checkpoint A Không Đảo — kết quả (2026-11-13, người dùng "Yes, 9 anchor", 55 gen)

Rotation `design/assets/candidates/sky_isles/<id>/rot/`, sheet `sky-anchors-sw-x3.png`.

| Id | Character id | bbox SW (cao) | Nhận xét | Verdict |
|---|---|---|---|---|
| cloud_sprite | `b54f82af-e541-406c-85db-8f6477913dd7` | 31×41 | cụm mây xám tối có tay chân ngắn, mắt Ngà | **ĐẠT** |
| harpy | `0529ea99-f3bd-4708-a6b1-b56584c17ee7` | 32×52 | đọc như **một con chim đứng**, không thấy thân người; cùng vùng đã có đại bàng + chim gió → 3 con chim xám mỏ Ngà dễ lẫn | **YẾU** — đề nghị gen lại "clearly a woman's upper body and face, bare arms that turn into wings, bird legs below" |
| wind_monk | `82640521-1a6f-4b42-b55e-fbf26670175e` | 34×47 | đầu trọc, áo vàng đục, khăn bay, trượng; giống nhất Aang → không hình xăm mũi tên | **ĐẠT** |
| storm_eagle | `6964eb63-8e57-4844-8947-18e1d00a9d14` | 42×48 | đại bàng xám, mỏ móc Ngà, vệt vàng đục cánh | **ĐẠT** |
| sky_sentinel | `1d71becf-a375-4c41-9d52-ab8d1c4f71dd` | 34×51 | tượng đá nâu đội mũ trùm, cánh đá gập, giáo | **ĐẠT** |
| thunder_shaman | `1a7c533e-5c86-4d5f-b322-e6016be2f811` | 35×50 | model vẽ **mũ lông vũ kiểu war bonnet của thổ dân Bắc Mỹ** — biểu tượng văn hoá có thật, không hợp thế giới Tessera (fantasy phương Tây hư cấu) và dễ thành khuôn mẫu | **KHÔNG ĐẠT** — đề nghị gen lại "a hood shaped like a storm cloud with a bird-skull mask, small drum at the hip, feathered staff" |
| gale_bird (E) | `0d9d4f83-41dc-437e-9b60-5e759297e800` | 41×79 | chim lớn đứng thẳng, đuôi dài chạm đất (79 ≥ 52 + 12) | **ĐẠT** |
| cloud_veil (E) | `35004d4d-4743-4f1c-9b9c-419e84f0b2d6` | 34×69 | cột mây áo choàng, mạng Ngà dài che mặt (69 ≥ 64) | **ĐẠT** |
| storm_dragon (Kẻ Gác) | `11653cd0-94cc-4610-85fd-d401847822ac` | 45×95 | rồng chữ S đứng, sừng Ngà, cánh gập, bụng vàng đục, mây cuộn ở chân; bbox chạm mép trên (khung sẽ nới) | **ĐẠT** (95 ≥ 79 + 4) |

7/9 đạt; đề nghị gen lại thunder_shaman (bắt buộc) và harpy (khuyến nghị), 12 gen.

### 17.2 Không Đảo — gen lại 2 anchor (2026-11-13, người dùng "Yes, gen lại 2", 12 gen; tổng Checkpoint A Không Đảo 67 gen)

Rotation `design/assets/candidates/sky_isles/<id>/rot-v2/`, sheet `sky-anchors-sw-v2-x3.png` (9 con, thứ tự cloud_sprite · harpy v2 ·
wind_monk · storm_eagle · sky_sentinel · thunder_shaman v2 · gale_bird · cloud_veil · storm_dragon). Bản v1 giữ trong `rot/`, coi như loại.

| Id | Character id (v2) | bbox SW (cao) | Nhận xét | Verdict |
|---|---|---|---|---|
| thunder_shaman | `e2b788fe-4c31-4df0-8064-b119e1edeb2c` | 39×46, 6 màu | mũ trùm hình mây bão xám, mặt nạ sọ chim Ngà, áo choàng vàng đục, trống da nhỏ, gậy lông xám; **không còn mũ lông kiểu war bonnet**. Giống nhất: bác sĩ dịch hạch / Skull Kid → khác nhờ mũ mây + trống + áo vàng | **ĐẠT** |
| harpy | `c1d53bdb-1b9f-40ac-9828-07d8f25854db` | 36×49, 7 màu | rõ thân và mặt phụ nữ, tóc xám rối, tay hoá cánh lông xám, chân chim có móng, áo lông nâu đá; giờ tách hẳn khỏi storm_eagle và gale_bird. Giống nhất: Harpy (Castlevania / Monster Hunter) → generic, không trùng nhân vật cụ thể | **ĐẠT** |

Tầng cao: thường cao nhất 52 (harpy v1 đã loại) → nay sky_sentinel 51; gale_bird 79 ≥ 51 + 12, cloud_veil 69 ≥ 63; storm_dragon 95 ≥ 79 + 4.
**Checkpoint A Không Đảo: 9/9 ĐẠT.** Bước tiếp: 45 clip (5 clip × 9 con, mỗi clip 1 gen), CHỜ "yes".

### 17.3 Checkpoint B Không Đảo — 44/45 clip (2026-11-13, người dùng "Yes, 45 clip", 44 gen)

- **44 clip gen xong**, mỗi clip 1 gen PixMiniMax SW 8 frame. **Clip `step` của `sky_sentinel` KHÔNG gen được**: lệnh bị bộ kiểm quyền auto mode của Claude Code chặn (không phải PixelLab lỗi). Lệnh bị chặn không tốn gen. Không thử lại khi chưa có lời người dùng. Tạm thời `step` của sky_sentinel dùng lại 4 frame idle (ghi trong `art_src/units/sky_sentinel/clips.json`), nên con này trượt sang ô bên mà không bước chân. **Chờ người dùng: cho phép gen lại 1 clip (1 gen) hoặc giữ tạm.**
- Ngoài ra có 5 lệnh step bị PixelLab từ chối vì hàng đợi đầy (10/10). Các lệnh này không tốn gen và đã được gửi lại khi có chỗ trống.
- Làm sạch cơ học như mọi vùng: snap palette, xoá cụm < 12 px, chân ở hàng cuối, một lần dịch ngang mỗi con. Bỏ frame có vệt vẽ sẵn: cloud_sprite hit 3 (vệt cung), thunder_shaman hit 2–3 (vệt cyan). Miệng đỏ của storm_eagle và storm_dragon ở windup bị snap thành màu palette, không còn đỏ.
- Khung: cloud_sprite 64×52 · harpy 74×56 · wind_monk 64×53 · storm_eagle 74×55 · sky_sentinel 64×53 · thunder_shaman 80×52 · gale_bird 90×81 · cloud_veil 80×80 · storm_dragon 100×96. Khung warden rộng hơn 96 giống inferno_lord 108 và sand_sphinx 106.
- Sheet `assets/art/units/unit_<id>_sheet.png/json` ×9, nguồn `art_src/units/<id>/`, contact sạch `design/assets/candidates/sky_isles/<id>/<id>-clean-x2.png`, line-up `sky-idle0-clean-x3.png`.
- Registry +9 (accepted, installed; harpy và thunder_shaman ghi retired_ids v1), manifest 237 asset, reference ×9.

### 17.4 QA Không Đảo (2026-11-13, chạy nền `region-enemies/sky-tests-and-shots-2026-11-13.txt`)

- 4 suite sprite FAILS=0. Chim Gió 79 và Thần Mây 69 đều ≥ con thường 52 + 12. Long Vương Gió 95 px / 2575 px đặc, lớn hơn cả hai Tinh Anh.
- Ảnh trận `region-enemies/10-sky-<id>-idle.png` ×9 (Tinh Anh, Boss chụp ở khung 240). Long Vương Gió đứng trên một ô, sừng Ngà và mây cuộn nổi rõ trên phiến tối. Pháp Sư Sấm có áo vàng đục nổi bật. Điểu Nữ đọc được nhờ màu da và tóc xám.
- Tracker §10.2: Không Đảo 9/9 `G`; sky_sentinel thiếu clip step thật.

### 17.5 Bộ test đầy đủ sau 6 vùng (2026-11-13, chạy nền)

`full-suite-region-enemies-final-2026-11-13.txt`: 303 file, 299 xanh. Chạy lại riêng 4 file đỏ (`rerun-suspects-final-2026-11-13.txt`):
- `terminology_scan_test` và `pattern_roster_fairness_test`: xanh khi chạy riêng, nên lỗi là do máy tải nặng.
- `multi_enemy_resolver_test` FAILS=5 và `pattern_hellfire_group_d_test` FAILS=2 vẫn đỏ khi chạy riêng. Hai file này test logic chiến đấu, không đọc sprite. Các session khác đang có thay đổi chưa commit trong `src/combat/` (combat_state, pattern_brain, pattern_controller…). Task asset quái không sửa file nào trong `src/`, nên lỗi không đến từ task này. Để lại cho session đang sửa combat.
- Mọi test sprite, sheet và art: xanh.

### 17.6 Lính Gác Trời — clip step thật (2026-11-13, người dùng "Yes, gen 1 clip", 1 gen)

- Gen lại clip `step` của `sky_sentinel` (PixMiniMax SW 8 frame, cùng prompt). Chọn frame nguồn 1/3/5/7, làm sạch cơ học, khung vẫn 64×53.
- Clip step tạm bằng frame idle đã được thay. Frame step 0 giờ khác idle 0, và con này bước chân thật khi đổi ô.
- 4 suite sprite FAILS=0 (`region-enemies/sky-sentinel-step-tests-and-shots-2026-11-13.txt`), ảnh trận `10-sky-sky_sentinel-idle.png` chụp lại.
- **Không Đảo: 45/45 clip, 112 gen. Tổng 6 vùng: 680 gen.**

### 18. Duyệt clip và commit (2026-11-13)

Người dùng: "commit clip đi rồi làm người giữ tấm lưới". Lệnh này được ghi nhận là duyệt clip của 56 con thuộc 6 vùng. Registry chuyển 56 mục sang `approved` (approved_by user, 2026-11-13), tracker §10.2 chuyển `G` thành `✓`. Commit chỉ gồm file của task asset quái. Code combat, i18n, data và file của các session khác không nằm trong commit.
