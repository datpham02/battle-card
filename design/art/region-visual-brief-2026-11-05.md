# Tessera — Bản tóm tắt hình ảnh các vùng (nền + sàn)

**Ngày:** 2026-11-05 · **Mục đích:** để người dùng nắm phong cách, đặc điểm và các thứ cần vẽ của từng vùng (map),
rồi viết prompt cho từng phần cần làm lại. Mỗi vùng có ô **"Prompt / ghi chú của bạn"** ở cuối.

**Nguồn:** `design/art/art-bible.md` §2 (mood theo vùng), §5.2 (Kẻ Gác), §6.1–6.6 (môi trường); `assets/art/regions.json`,
`assets/art/env/forest/region.json`; `assets/data/chapters.json` (quái, dạng sân); `assets/data/arenas.json` (cỡ sân);
`design/assets/specs/misty-forest-assets.md` (ASSET-004/005/007). Ảnh concept tham khảo: `design/art/reference/07-<vùng>-01.png`
(nền) và `08-warden-<vùng>-01.png` (Kẻ Gác). Art bible nói rõ: ảnh 07/08 chỉ để lấy **bố cục và không khí**, không vẽ lại.

---

## 0. Luật chung cho mọi vùng (đọc trước khi viết prompt)

### 0.1 Khung hình và các lớp nền

| Mục | Giá trị |
|---|---|
| Khung vẽ toàn trận | 800×360 art-px, phóng to theo bội số nguyên, lọc nearest (pixel sắc nét) |
| Nền | ≤ 3 lớp: **trời**, **xa**, **gần** (sương/mây trôi). Rừng Sương hiện dùng 2 lớp: xa 800×360 + sương 800×48 |
| Dải cảnh xa | **20 % chiều cao trên cùng** (72 art-px). Sân bắt đầu ngay dưới đó |
| Bố cục | Vẽ **cả tấm** theo góc nhìn hơi chếch từ trên: cảnh xa trên cùng, mép chuyển tiếp (bụi, đá, rễ) dưới chân trời, khoảng đất trống nơi đặt sân, **hai lề 80 px** có cột / thân cây đóng khung, đáy 36 % tối dần theo bậc (vùng nút điều khiển). Không thân cây đứng trước sân, chân trời không cắt thẳng |
| Đồ vật | Chỉ ở **dải chân trời** hoặc **hai lề** (cách mép sân ≥ 8 px). Không vật nào trên/chồng ô sân. Không viền, độ tươi S ≤ 25 %, tĩnh (chỉ mây/sương trôi), không glow, **không đỏ**, không chữ/rune |
| Mật độ đồ vật | Vùng thưa (Tháp Sương, Không Đảo, Sa Mạc, Tâm Lưới): ≤ 3 vật lớn + ≤ 6 nhỏ. Vùng dày (Rừng, Đầm Lầy, Hầm Ngục): ≤ 6 lớn + ≤ 12 nhỏ, dồn ở lề |
| Họa tiết văn hóa | Duy nhất "ô vuông lồng ô vuông" (cờ, cột). 1–2 mảnh "Hình Gốc" vỡ (đá vuông gãy dạng polyomino, xám) mỗi vùng; 1 dấu người màu ngà (kiếm gãy, cờ rách) |
| Ngôn ngữ hình | **Vuông thẳng = lưới/sức mạnh (mới)**; **cong, mòn, bị phủ = thế giới cũ**. Chỗ lưới chạm vật cũ thì vật bị cắt vuông 90° |
| Dither | Cấm trên phiến, đơn vị, Khối, VFX. Chỉ cho sương/mây (checker 2×2) |

### 0.2 Sàn (phiến đá của sân đấu)

| Mục | Giá trị |
|---|---|
| Bộ phiến mỗi vùng | **1 nine-slice 16×16 + ~6 stamp** (vết nứt, vật phủ, 8×6 đến 16×8). Code dựng ở cỡ ô bất kỳ 38×27…64×46. Rừng Sương hiện có 18 stamp (sheet 96×48, lưới 16×8) |
| Phiến v2 | Mặt 3 tông (cạnh sáng trên-trái, mặt, cạnh tối phải-dưới), mép trước tối có 1 px sáng ở cạnh trên. Mặt phiến S ≤ 30 %, V ≤ 55 %. **Không viền Mực** |
| Vật phủ | Hữu cơ, thấp, **chỉ ở mép và góc, ≤ 25 % mặt phiến**. Mỗi vùng 1 màu phủ riêng (bảng §mỗi vùng) |
| Vết nứt / nhiễu | ≤ 2 vết nứt/phiến (1 px bậc thang); nhiễu ≤ 4 % pixel, cụm 2 px |
| Bệ nổi (code) | Mặt bệ 6 art-px quanh mọi ô, mặt trước 12 art-px dưới hàng cuối, bóng 4 px Mực 50 %. Màu bệ lấy từ `region.json` → `platform` |
| Phối cảnh | Shader nắn cả sân thành hình thang, hàng sau / hàng trước = **0,82**. Phiến vẽ phẳng, shader nắn sau |
| Hai nửa sân | Nhân màu: nửa người chơi xanh lạnh **#B8CCE8**, nửa địch tím mận u ám **#9A84A4** (không đỏ, không cam) |
| Ô đặc biệt (chung) | **Lỗ / ô rớt** (không vẽ phiến, tô đáy tối nhất vùng, mép trên kéo xuống 3 px thành vách; hết hạn hiện lại dưới lớp trắng mỏng dần) · **Bãi Gai** (tile 16×16 lặp, gai 3–5 px thưa) · **Ô cháy** (tối thêm 1 bậc + lửa bậc thang + sọc ngang) |

### 0.3 Độ dễ đọc
- ≥ 40 % pixel nửa trên đơn vị phải lệch độ sáng V ≥ 25 điểm so với nền ngay sau đầu.
- Nền tối (Hầm ≤ 30, Hỏa Ngục ≤ 25, Tâm Lưới ≤ 20, Đầm ≤ 40, Rừng ≤ 45): đơn vị cần mảng sáng. Nền sáng (Tháp, Sa Mạc 60–72; Không Đảo 55–72): đơn vị cần mảng tối.
- Pixel rất tươi + rất sáng (S ≥ 60, V ≥ 75) chỉ dành cho Khối, Mảnh Gốc, màu nhấn khối.

### 0.3b Khối nhặt trên sàn (chung mọi vùng, cập nhật 2026-11-06: ấn ký đá cổ)

Người chơi phải **nhận ra đúng hình và hướng Khối trước khi nhặt**. Ưu tiên: đúng hình → đọc ngay giữa trận → hợp art bible → đơn giản → trang trí.

| Mục | Giá trị |
|---|---|
| Kiểu | **Ấn ký đá cổ khảm trên ô**: polyomino 2D phẳng ghép từ ô vuông đá nối cạnh, đúng hình và hướng như trên tay. Không phải icon UI sáng, không khối 3D |
| Ô vuông đá | Viền tối mảnh 1 px (chung giữa hai ô kề), mép trên-trái sáng hơn, mép dưới-phải tối hơn, mặt một tông |
| Phong hóa | Khắc mờ "ô vuông lồng ô vuông" trong ô đủ lớn, 1 chấm rỗ mỗi ô, góc lồi mòn 1 px. Nằm nghiêng theo phối cảnh sàn, ô ép dẹt theo tỉ lệ ô sàn |
| Màu | Trầm: Khối thường đá ngà cũ `#C9BB9B` / `#DCCFB0` / `#8F8167`; Khối Lạ tím trầm; Khối thối xám + X. Giữ cùng chất liệu ở mọi vùng |
| Vị trí | Đúng tâm **một** ô sàn (tâm sau phép nắn phối cảnh), chừa khoảng tới mép ô |
| Cấm | Nổi, nhấp nhô, xoay, bóng đổ, hạt, lấp lánh, glow; tô cả ô; viền vàng/xanh quanh ô |
| Ô sàn | Đá, vết nứt, rêu lộ nguyên; lớp Khối riêng, không sửa texture sàn |
| Kích thước | Theo khung bao từng hình: hình ≥ 3 cột chiếm ~60–75 % bề ngang ô; ô vuông 4–14 art-px |
| Độ tươi | Nứt dần rồi vỡ vụn tại chỗ (chi tiết: `forest-integration-pickup-plan-2026-11-05.md` §4.2) |

### 0.4 Tình trạng tài nguyên hiện tại

| Vùng | Nền | Sàn | Ghi chú |
|---|---|---|---|
| Rừng Sương | **Có** (xa 800×360 + sương 800×48) | **Có** (nine-slice 16×16 + 18 stamp + gai 16×16) | Duy nhất vùng có art thật |
| 7 vùng còn lại | **Chưa** — game vẽ 2 dải màu phẳng (trời / đất) | **Chưa** — dùng phiến Rừng Sương | Cần làm trọn bộ |

---

## 1. Rừng Sương (`forest`, chương `ch1`) — tầng 1

- **Không khí:** lạc giữa phế tích hiền; lặng, u buồn, rõ ràng. Sương thấp che chân phiến.
- **Màu chủ đạo:** xanh rêu xám, mát (#5E6B55 và 2 bậc rêu tối), độ tươi thấp; **không xanh lá tươi, không nắng, không tia sáng**.
- **Nền (đang dùng):** `bg_forest_far.png` 800×360 — rừng cổ thụ rễ lớn, đồi xa mờ sương, 4 vòm đá đổ nát, cột đá gãy phủ rêu ở hai lề, nền đất tối có phiến đá lát; `bg_forest_near.png` 800×48 — 2 vệt sương mỏng trôi ≤ 1 px/s.
  - Công thức art bible: trời sương #7D8896 phẳng / đồi cây + 3–4 tàn tích ≤ 25 px, V ≤ 45 / rễ và cột gãy ở lề; sương thấp trôi.
  - Còn mở: ngọn cây cao tới ~4,7 % màn hình, lấn vào thanh HUD.
- **Sàn (đang dùng):** phiến xám đá với rêu ở góc. Màu phiến #6A6B62 / #4C4D47 / #3A3B37, mép #262521, vạch #5A5B54. Stamp: 3 vết nứt, rêu 4 góc, rễ, lá, 2 kiểu chấm, 7 vết mẻ cạnh. Bệ: mặt #3A3B37, thành #262521, mép trên thành #5A5B54.
- **Lưới đè lên:** phế tích lát đá, rễ đội ô. **Phủ lên phiến:** rêu ở góc.
- **Sân đấu (16 trận):** rect 4×3 (7), square 3×3 (4), u_shape 4×3 (2), boss_hall 6×4 (2), cross 4×4 (1).
- **Quái:** goblin (scout, archer, warlock…), sói (dire_wolf, wolf_alpha), rootling, greycap_sporeling, mossbound_sentry, ancient_root_sentinel, mistbriar_matron. **Kẻ Gác:** Phù thủy Rừng (mặt nạ mỏ chim, sừng hươu, áo lá rách).
- **Ảnh tham khảo:** `07-forest-01.png` (đúng: sương nhiều lớp, vòm cổng; sai: cầu vòm xa cao), `08-warden-forest-01.png`.
- **Cần làm thêm (tùy chọn):** lớp trời riêng; hạ ngọn cây khỏi vùng HUD; viên phiến chi tiết hơn; 1 mảnh Hình Gốc vỡ + 1 dấu người ngà.

> **Prompt / ghi chú của bạn:**
>
>

---

## 2. Hầm Ngục (`dungeon`, chương `ch2`)

- **Không khí:** khép kín, ngột ngạt; tối nhất các vùng (V nền ≤ 30).
- **Màu chủ đạo:** xám đá lạnh. Dải dự phòng hiện tại: trời #4A4440, đất #2C2826.
- **Nền:** **không trời, không chân trời** — tường vòm + 4–5 cột, chân tường = chân trời; xích treo; đuốc là **mảng ochre đục tĩnh, không phát sáng**.
- **Sàn:** sàn ngục vốn lát ô, lưới trùng kiến trúc cũ; hố sập. **Phủ lên phiến:** bụi đá, xích gỉ ở lề.
- **Sân đấu (10 trận):** ring 6×5 (2), cross 4×4 (2), u_shape (2), rect (2), square (1), staircase 4×4 (1).
- **Quái:** skeleton, zombie, bat_swarm, slime, cultist, ghost, jailer (ném khối hỏng), reacter, rat_king_guard. **Kẻ Gác:** Quỷ Khổng Lồ (ogre_king: đá xám, vai rộng, đầu nhỏ, vương miện + râu ngà, xích gỉ ochre #8A6A40).
- **Ảnh tham khảo:** `07-dungeon-01.png` (đúng: cột, vòm, cờ ô lồng ô; sai: lửa đuốc sáng, hố sập vẽ trong nền), `08-warden-dungeon-01.png`.
- **Cần làm:** nền 800×360 (tường vòm, cột, xích, đuốc tĩnh) · bộ phiến 16×16 + stamp (bụi đá, xích gỉ, vết nứt) · màu bệ `platform` · hố sập (Lỗ).

> **Prompt / ghi chú của bạn:**
>
>

---

## 3. Tháp Sương (`ice_tower`, chương `ch3`)

- **Không khí:** cô độc, lạnh dần.
- **Màu chủ đạo:** lam-tím nhạt ở nền xa (#8E95B8); **phiến vẫn tối**. Dải dự phòng: trời #8E95B8, đất #4C5069.
- **Nền:** trời lam-tím / **biển mây** + 2–3 tháp xa thưa / lan can, cột băng thấp ở lề. **Không tinh thể cyan** (trùng màu trạng thái Đóng Băng).
- **Sàn:** sân thượng lát phiến băng. **Phủ lên phiến:** sương giá ở mép, lam-xám (không cyan).
- **Sân đấu (10 trận):** cross_wide 5×5 (2), pillars 5×5 (2), diamond 5×5 (2), rect (2), square (1), staircase (1).
- **Quái:** frost_mage, frost_sprite, ice_golem, rime_archer, snow_wolf, wisp, stone_sentry, fuse_golem, ghost_elite. **Kẻ Gác:** Chúa Tể Băng Giá (mist_lord: cao hẹp, áo xanh đêm, cổ lông ngà, vương miện gai băng, mũ không mặt).
- **Ảnh tham khảo:** `07-ice-tower-01.png` (đúng: biển mây, tháp xa, sân tròn; sai: tinh thể cyan), `08-warden-ice-tower-01.png`.
- **Cần làm:** nền (trời + biển mây + tháp xa + lan can lề) · lớp mây trôi · bộ phiến băng + stamp sương giá · màu bệ.

> **Prompt / ghi chú của bạn:**
>
>

---

## 4. Đầm Lầy Độc (`swamp`)

- **Không khí:** nặng, dính, ngộp. Hơi độc là lớp mờ **không tươi**.
- **Màu chủ đạo:** ô-liu bùn (không ô-liu tươi). Dải dự phòng: trời #6B705A, đất #353A2C.
- **Nền:** trời ô-liu xám / tàn tích thấp trong sương, nước phẳng / cột chìm, lau sậy, nấm #6A5868 ở lề.
- **Sàn:** lối đá chìm nửa trong bùn. **Phủ lên phiến:** mép chìm, rong. **Ô lầy** (luật chơi): phiến chìm 2 px, mặt #4E4A2A + bọt #A8C83A ≤ 8 px.
- **Sân đấu (9 trận):** bog 5×3 (6), reed_maze 5×5 (3).
- **Quái:** bog_hound, bog_rat, leap_frog, marsh_toad, mire_slug, spore_cap, swamp_lizard, reed_witch, toad_matriarch. **Kẻ Gác:** Cóc Chúa (toad_matriarch: tròn, rộng, thấp; 3–4 nấm xám-tím #6A5868 trên đầu, rêu nhỏ giọt).
- **Ảnh tham khảo:** `07-swamp-01.png` (đúng: nước phẳng, nấm; sai: ô-liu quá tươi), `08-warden-swamp-01.png`.
- **Cần làm:** nền + lớp sương độc trôi · bộ phiến chìm bùn + stamp rong · ô lầy · màu bệ.

> **Prompt / ghi chú của bạn:**
>
>

---

## 5. Sa Mạc Cát Vùi (`sands`, chương `desert`)

- **Không khí:** mênh mông, bị vùi. Ngọc cổ chỉ là **vết trên đá**.
- **Màu chủ đạo:** be cát bụi, ấm. Dải dự phòng: trời #B8A888, đất #6E6248. Nền sáng (V 60–72) → đơn vị cần mảng tối.
- **Nền:** trời be bụi / cồn cát + tàn tích vòm / cột nửa vùi, bình ngọc #4F8A80; sương cát trôi. **Không vẽ cát phủ phiến sẵn trong nền** (ô cát lấp là luật chơi).
- **Sàn:** quảng trường cổ bị cát vùi. **Phủ lên phiến:** cát tràn từ một phía. **Ô cát lấp** (luật chơi): sóng cát hữu cơ phủ 100 %, mép gợn.
- **Sân đấu (9 trận):** dunes 5×4 (5), oasis 5×5 (4).
- **Quái:** dune_jackal, dust_nomad, mirage_sprite, sand_beetle, sand_burrower, scarab_guard, scorpion, sun_archer, sand_sphinx. **Kẻ Gác:** Nhân Sư Cát (sand_sphinx: ngồi thẳng, đầu người đội sừng, đai ochre + ngọc #4F8A80, cánh phiến đá gập).
- **Ảnh tham khảo:** `07-sands-01.png` (đúng: cồn, dải ngọc đục; sai: cát phủ phiến sẵn), `08-warden-sands-01.png`.
- **Cần làm:** nền + sương cát trôi · bộ phiến đá cổ + stamp cát tràn · ô cát lấp · màu bệ.

> **Prompt / ghi chú của bạn:**
>
>

---

## 6. Thành Hỏa Ngục (`hellfire`)

- **Không khí:** nhịp đập, áp lực; nóng nhất. Nền tối nhất nhì (V ≤ 25).
- **Màu chủ đạo:** đen than. Dải dự phòng: trời #3A3236, đất #1F1B1D. **Không cam sáng trong nền** (cam = trạng thái Cháy).
- **Nền:** trời than / tháp nhọn đen / tường cháy, xích. Dung nham **chỉ nằm trong khe**.
- **Sàn:** sàn thành nứt thành ô, khe là mạch. **Phủ lên phiến:** tro, mép cháy xém. **Mạch dung nham** (ngoại lệ đã chốt): khe 3 px = 1 Mực + 2 px #FFB21F.
- **Sân đấu (9 trận):** caldera 5×5 (5), forge 5×3 (4).
- **Quái:** ash_golem, ash_phoenix, ember_hound, fire_eater, flame_cultist, hell_knight, imp, magma_slug, inferno_lord. **Kẻ Gác:** Chúa Quỷ Lửa (inferno_lord: giáp phiến than, hai sừng cong đồng, ngực nứt ochre tối, áo choàng cháy xém; **bỏ vân dung nham cam khắp thân và mắt cam**).
- **Ảnh tham khảo:** `07-hellfire-01.png` (đúng: tháp nhọn, xích; sai: thác dung nham cam khắp nền), `08-warden-hellfire-01.png`.
- **Cần làm:** nền · bộ phiến than + stamp tro/cháy xém · mạch dung nham khe · màu bệ.

> **Prompt / ghi chú của bạn:**
>
>

---

## 7. Không Đảo (`sky_isles`)

- **Không khí:** gió, chênh vênh.
- **Màu chủ đạo:** lam trời xám, nền xa sáng (V 55–72). Dải dự phòng: trời #B9BFC8, đất #6A7080.
- **Nền:** dải sáng chân trời, vàng sấm S ≤ 30 %, 1–2 vạch sét tĩnh / biển mây tối hơn trời 1 bậc, đảo nhỏ xa / lưới trên thân đảo. **Không đặt lưới trên đất phẳng.**
- **Sàn:** mặt đảo đá bị nâng khỏi đất. **Phủ lên phiến:** mòn gió, gần như không phủ. Code thêm chân đá thon bậc thang dưới hàng cuối. **Ô sắp rơi** (luật chơi): nứt + viền nét đứt → rơi thành hố → hiện lại dưới lớp trắng mỏng dần.
- **Sân đấu (9 trận):** twin_isles 6×3 (3), three_isles 7×2 (3), islands_bridge 6×3 (3).
- **Quái:** cloud_sprite, cloud_veil, gale_bird, harpy, sky_sentinel, storm_eagle, thunder_shaman, wind_monk, storm_dragon. **Kẻ Gác:** Long Vương Gió (storm_dragon: rồng chữ S đứng, đầu cao hai sừng ngà, cánh gập sát, mây lượn ở chân).
- **Ảnh tham khảo:** `07-sky-isles-01.png` (đúng: biển mây, đảo xa, vạch sấm; sai: lưới đặt trên đất phẳng), `08-warden-sky-isles-01.png`.
- **Cần làm:** nền + lớp mây trôi · bộ phiến đá đảo mòn gió · chân đá thon · màu bệ.

> **Prompt / ghi chú của bạn:**
>
>

---

## 8. Tâm Lưới (`lattice_heart`, chương `an_dai`) — đích cuối

- **Không khí:** trang nghiêm, trần trụi, đỉnh điểm.
- **Màu chủ đạo:** đen chàm #15142A. Dải dự phòng: trời #15142A, đất #0E0D1C. Nền tối nhất (V ≤ 20).
- **Nền:** chàm, **không chân trời** / bậc đài ngà-xám + 4–6 cột / lưới Ánh Lưới 1 px phủ 20–40 %. Pha 2: lưới nền sáng thêm 1 bậc + hai cung vòng bậc thang ngà sau đầu Người Giữ.
- **Sàn:** lưới lộ trần, không địa hình cũ. **Không phủ;** phiến có rãnh ô vuông lồng ô vuông (không chữ).
- **Sân đấu:** an_dai_dais 5×5 (1).
- **Quái:** an_dai_keeper. **Trùm cuối:** Người Giữ Tâm Lưới (khung 48×64; áo thụng ngà-xám, mũ trùm mặt trống, dải vải 2 px, một tay mở ra trước; 3 mảnh Ánh Lưới trên đầu).
- **Ảnh tham khảo:** `07-lattice-heart-01.png` (đúng: lưới mảnh có nút vuông, bậc đài; sai: trái tim Hình Gốc đọc như icon máu, vàng sáng chiếm nền), `08-heart-keeper-01.png`.
- **Cần làm:** nền (bậc đài, cột, lưới vàng mảnh) + biến thể pha 2 · bộ phiến có rãnh ô lồng ô · màu bệ.

> **Prompt / ghi chú của bạn:**
>
>

---

## 9. Gợi ý cách viết prompt cho phần "làm lại"

Mỗi vùng cần tối thiểu 3 thứ. Ghi rõ cho từng thứ:

1. **Nền 800×360** — trời / xa / gần; vật gì ở dải chân trời, vật gì ở hai lề; màu chủ đạo; những gì **giữ** từ bản cũ.
2. **Viên phiến 16×16 + 6 stamp** — chất liệu mặt phiến (đá, băng, than…), vật phủ ở góc/mép (rêu, tuyết, cát, tro…), kiểu vết nứt.
3. **Màu bệ** (`platform`: deck / face / face_top / mortar / divider).

Viết theo dạng khẳng định ("tháp xa màu chàm", "mép phiến phủ tro") thay vì phủ định ("không cam"), vì các model
gen ảnh/hoạt ảnh thường hiểu sai câu phủ định. Trước khi gen, tôi sẽ đưa lại prompt đã chốt, công cụ và số gen để bạn duyệt
(mỗi lần gen đều cần bạn đồng ý).
