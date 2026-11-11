# Quy chuẩn render — palette, pixel, viền

**Ngày:** 2026-11-11. Dùng file này khi biến `docs/art/FLOOR-MAP-ROSTER.md` và `design/art/region-visual-brief-2026-11-05.md` thành prompt gen. Roster chỉ có không khí và vài hex. Số dưới đây lấy từ Art Bible; chỗ Bible tự mâu thuẫn thì lấy lần chốt muộn hơn.

Nguồn, theo thứ tự thắng:

| Việc | Lấy từ | Bỏ |
|---|---|---|
| Khung sprite đang chạy | Art Bible §8.3, đo trên đĩa 2026-11-11 | §1 pipeline và §3 còn ghi 32×48 / Kẻ Gác 48×64. Đó là khung cũ, trước 2026-10-31 |
| Viewport, nearest, alpha | §8.2, §8.7, §8.10 | |
| Viền, thứ bậc, cấm dither | §3, §6.2, §8.9 | |
| Hex dùng chung và tín hiệu | §4 | |
| Màu đã khóa trên sprite | `art_src/palette/tessera_master.gpl` (47 màu). Exporter từ chối pixel đục ngoài list | LUT và `tessera_region_*.gpl` **chưa có** |
| Nền, phiến, phối cảnh sân | §6.3–6.4 (2026-10-31 và 2026-11-02) | §3 còn nói chân trời 9–13 %. §6.4 đổi thành dải xa **20 %** |
| Công thức từng vùng | Brief 2026-11-05, chép từ §6. Brief không thêm luật render | |

---

## 1. Pixel và khung

Một art-px = một texel. Không khử răng cưa, không phóng lẻ, không xoay góc lẻ, không đặt sprite ở nửa pixel.

| Bề mặt | Khung | Cách hiện |
|---|---|---|
| Trận | SubViewport **800×360**. Vùng chơi 640 ở giữa, **80 px mỗi lề** chỉ là nền | Phóng bội nguyên, `NEAREST`. Phần dư màn tô Mực `#1B1722` |
| HUD, chữ | **1280×720**, không snap pixel | Không nhét chữ vào sprite |
| Ô sàn | 38×27 (sân lớn) đến 64×46 (sân nhỏ), bội 2 | Phiến vẽ phẳng rồi shader nắn |
| Nền | **800×360**, ≤ 3 lớp | Không nắn phối cảnh |
| Đảo leo | 320×192 | Ngoài file này. `design/art/climb-map-asset-spec-2026-11-07.md` |

Khung đơn vị **đang dùng**, neo giữa đáy, chân ở hàng pixel cuối:

| Loại | Khung art-px | Cao thân |
|---|---|---|
| Anh hùng | 96×70. `tho_san` / `giao_si` 96×72. `kiem_si` 96×92 (`body_h` 70) | ~66, rộng thân ~31 |
| Quái thường | 64×52. `dire_wolf` 68×52 vì đuôi | ~46 |
| Tinh anh | 80×80 | cao hơn quái thường |
| Kẻ Gác / Người Giữ | **160×130** trên đĩa (`forest_witch`, `goblin_warlock`) | Mục 5 vẫn mô tả dáng trong thân ≤ 52×40 của khung 48×64 cũ. Khi gen boss mới, khung xuất là 160×130; dáng vẫn đọc ở nửa trên |

Prompt gen đơn vị: ra một tư thế, nền phẳng, rồi thu **nearest** vào khung trên, ép palette, sửa viền tay. Đừng giao model một tấm đã phối cảnh.

Alpha chỉ **0 hoặc 255**. Import: Lossless, không mipmap, không nén VRAM, lọc nearest trên node.

---

## 2. Viền

| Cái gì | Viền |
|---|---|
| Đơn vị, Khối | **1 px `#1B1722` kín**. Không đen thuần. Không viền màu phe |
| Viền trong đơn vị | Chỉ tách bộ phận, ≤ 3. Sáng từ trên-trái, ≤ 3 bậc bóng mỗi chất liệu |
| Phiến, nền, đồ lề | **Không viền**. Mép sáng 1 px trên-trái + khe tối. Ảnh concept `07-*` có viền 4 cạnh: bỏ |
| Ô báo đòn | Viền 2 px đỏ `#E5293B` + mép Mực ngoài. Code vẽ, không vẽ vào texture nền |
| HUD chữ trên thế giới | Viền Mực 2 px ở lớp 1280×720 |

Mắt anh hùng 2×2 Mực, không lòng trắng. Họa tiết dưới 2×2 không sống ở ô 38×27. Dấu nhận dạng (tai, sừng, mũ, vũ khí) nằm **nửa trên**, dày ≥ 3 px.

---

## 3. Render trong trận

Thứ tự vẽ, art-px: nền (không nắn) → `FloorLayer` vẽ phẳng → shader nắn sàn → `UnitLayer` → `OverlayLayer`.

Phối cảnh **chỉ trên sàn**, không trên nền và không trên sprite:

- Hàng sau / hàng trước = **0,82** (`floor.perspective.back_ratio`). `--floor-perspective=0` ép phẳng.
- Phiến, stamp, báo đòn, VFX sàn vẽ phẳng, shader lấy mẫu nearest. Sprite không co. Chỉ điểm chân đi theo mặt đã nắn.

Dither cấm trên phiến, đơn vị, Khối, VFX. Chỉ mây/sương và một dải chuyển bậc nền: checker 2×2, rộng ≤ 4 px.

Cấm trên asset: gradient mượt, glow, bloom, Light2D, normal map, MSAA, chữ, rune, đỏ `#E5293B` (đỏ chỉ là báo đòn, code tô).

Thứ bậc sáng, từ nổi đến chìm: Khối → ô đỏ → đơn vị → phiến → nền. Pixel S ≥ 60 và V ≥ 75 chỉ cho Khối, Mảnh Gốc, màu nhấn khối.

---

## 4. Palette

### Thang

| Lớp | S | V |
|---|---|---|
| Khối | ≥ 60 % | ≥ 75 % |
| Đơn vị | 30–60 %. Địch **30–45 %**, màu vùng + Đá/Sương/Ngà, không màu nhấn khối | nửa trên phải lệch nền ≥ 25 điểm V trên ≥ 40 % pixel |
| Phiến | ≤ 30 % | ≤ 55 % |
| Nền | ≤ 25 % | trời ≤ 72 %; đất dưới lưới ≤ 30 % |
| Đồ lề | ≤ 25 % | lệch nền ≤ 20 |

Ngân sách Bible: tối đa 64 cho mọi thứ đứng trên sân. Mỗi vùng **≤ 3 màu riêng**, còn lại ramp Đá/Sương. Nền **tính riêng, ≤ 40 màu/vùng**, và không được dùng màu tín hiệu.

Màu tín hiệu, không đưa vào nền hay thân quái:

| Hex | Chỉ dùng cho |
|---|---|
| `#E5293B` | Ô báo đòn |
| `#FFD45C` | Ánh Lưới: Bản Khắc, Mảnh Gốc, lưới Tâm Lưới |
| `#FF7A1F` | Cháy (lửa bậc thang + sọc ngang) |
| `#FFB21F` | Mạch dung nham, chỉ trong khe |
| `#A6EEFF` | Vỏ Đóng Băng |
| `#3A5CF0` | Giá Lạnh |
| `#E04CD0` | Khối Lạ |
| `#A8C83A` / `#4E4A2A` | Bọt lầy / mặt ô lầy |
| `#8FA3B8` `#EEF4FA` | Khối Kiếm sĩ |
| `#3A2A26` `#F0A030` | Khối Pháp sư |
| `#BFF3EC` | Khối Sát thủ |
| `#8A5A33` `#46D6A4` | Khối Thợ săn |
| `#E4DAFF` `#B8BCC8` | Khối Giáo sĩ |

Mực `#1B1722`, Ngà `#EFE6D2`, Sương `#7D8896`, Đá `#4A4640` / mép `#2C2925` là màu chung.

`tessera_master.gpl` hiện **47** màu. Bảng đủ RGB/hex và màu nào thuộc con nào nằm ở `docs/art/REGION-MATERIALS-AND-PALETTE.md`. Vùng chưa có sprite thì file đó không có hex riêng: không tự bịa.

### Từng vùng — màu đã chốt

Chưa có ramp 3 tông đo được ngoài Rừng Sương. Cột "riêng" là màu vùng trong §4, tối đa 3.

| Vùng | Chủ đạo | Riêng đã ghi | Cấm trên phiến / nền | Nền V |
|---|---|---|---|---|
| Rừng Sương | Rêu `#5E6B55` | Ramp phiến đo được: mặt `#6A6B62` / `#4C4D47` / `#3A3B37`, mép `#262521`, vạch `#5A5B54`. Rêu tối `#4A5545`, `#3A4538`. Nấm `#6A5868` `#4A3E4A` `#8E8296` | Lục tươi | ≤ 45. Trời sương `#7D8896` |
| Hầm Ngục | Đá xám lam `#3E4450` | Đuốc ochre **đục** `#8A6A40` | Cam đuốc tươi, lửa phát sáng | ≤ 30. Không chân trời |
| Tháp Sương | Xa `#8E95B8`, phiến `#4C5266` | Sương giá lam-xám, không cyan | `#A6EEFF` và tinh thể cyan | Trời 60–72, phiến vẫn tối |
| Đầm Lầy | Ô-liu `#4E4C3C` | Nấm `#6A5868`. Ô lầy là luật, không phải nền | Ô-liu tươi. `#4E4A2A` chỉ cho ô lầy | ≤ 40 |
| Sa Mạc | Be `#A89A80` | Ngọc đục `#4F8A80` | Cát phủ kín phiến trong tấm nền | 60–72, quái cần mảng tối |
| Hỏa Ngục | Than `#24201E` | `#FFB21F` chỉ khe 3 px (1 Mực + 2 px cam) | Đỏ. Cam sáng trên tường, thác dung nham | ≤ 25 |
| Không Đảo | Trời `#8AA2B8`, phiến `#5A5048` | Vàng sấm S ≤ 30 % | Lưới vàng đặt trên đất phẳng | 55–72 |
| Tâm Lưới | `#15142A` | Lưới `#FFD45C` phủ 20–40 %, nét 1 px | Vàng chiếm nền, icon trái tim | ≤ 20 |

Hai nửa sân nhân màu **sau**, không vẽ sẵn trong texture: người chơi `#B8CCE8`, địch `#9A84A4`.

Fallback khi chưa có nền (`assets/art/regions.json`, ghi là placeholder trừ rừng / tháp / tâm lưới):

| Region | Trời | Đất |
|---|---|---|
| forest | `#7D8896` | `#4A5257` |
| dungeon | `#4A4440` | `#2C2826` |
| ice_tower | `#8E95B8` | `#4C5069` |
| swamp | `#6B705A` | `#353A2C` |
| sands | `#B8A888` | `#6E6248` |
| hellfire | `#3A3236` | `#1F1B1D` |
| sky_isles | `#B9BFC8` | `#6A7080` |
| lattice_heart | `#15142A` | `#0E0D1C` |

### Phiến, mọi vùng

- 1 nine-slice **16×16** + **6 stamp** (8×6 đến 16×8). Giữa phẳng để giãn. Mép trước 2–3 px và khe 1–2 px không giãn.
- ≤ 3 tông. Không viền Mực. Nứt ≤ 2, 1 px bậc thang. Nhiễu ≤ 4 %, cụm 2 px.
- Vật phủ chỉ mép và góc, ≤ 25 % mặt. Một màu phủ mỗi vùng (bảng §6.1 trong Bible, brief §0.2).
- Bệ do code vẽ: vành 6 px, mặt trước 12 px, bóng 4 px Mực 50 %. Không vẽ bệ vào tấm nền.

---

## 5. Cái prompt không được vẽ

Code hoặc lớp phủ đã vẽ những thứ này. Texture gen mà có chúng sẽ đè hệ thống:

- Ô đỏ báo đòn, ô cháy, ô lầy, cát lấp, mạch phun, ô nứt/hố, gai (tile 16×16 riêng).
- Hai nửa sân xanh/tím.
- Hình thang phối cảnh. Phiến và nền gen **phẳng**.
- Viền Mực trên nền. Chữ, rune, số.
- Mảnh Gốc trên đầu Kẻ Gác (code, 2 px/ô, `#FFD45C`).
- VFX phép (ô vuông, tô bằng màu khối).

Nền: dải xa **72 px** (20 %), hai lề 80 px, đáy 36 % tối theo bậc (không gradient mượt). Vật chỉ ở dải chân trời hoặc hai lề, cách mép sân ≥ 8 px. Dày (rừng, đầm, hầm): ≤ 6 vật lớn + ≤ 12 nhỏ. Thưa (tháp, đảo, sa mạc, tâm lưới): ≤ 3 lớn + ≤ 6 nhỏ. Mỗi vùng 1–2 đá polyomino vỡ màu xám, không vàng, và 1 đồ ngà (kiếm gãy hoặc cờ rách).

Công thức trời/xa/gần và ảnh `07-*` đúng/sai: brief §1–§8. Ảnh đó chỉ lấy bố cục.

---

## 6. Nhận asset

Từ §8.9, phần liên quan gen:

1. Tô đen vẫn phân biệt loài trong cùng vùng.
2. Che nửa dưới vẫn nhận ra.
3. Viền 1 px `#1B1722` chỉ trên đơn vị và Khối. Phiến và nền không viền.
4. Màu đơn vị nằm trong `tessera_master.gpl` hoặc được thêm vào đó trước khi xuất.
5. Alpha 0/255, một cỡ pixel, không pixel lẻ.
6. Không `#E5293B`, không gradient mượt.
7. Chụp trong trận trước khi coi là xong. Nền tối cần mảng sáng (V ≥ 60 trên ≥ 25 % nửa trên). Nền sáng (tháp, sa mạc, đảo) cần mảng tối (V ≤ 40 trên ≥ 40 % nửa trên).
