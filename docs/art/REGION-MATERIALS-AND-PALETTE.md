# Vật liệu từng vùng và bảng màu đã khóa

**Ngày:** 2026-11-11. Nội dung lấy nguyên từ `design/art/region-visual-brief-2026-11-05.md` và `art_src/palette/tessera_master.gpl`. Không thêm hex.

Luật render (khung, viền, nearest, alpha) ở `docs/art/RENDER-STANDARDS.md`. Pool quái đang chạy ở `docs/art/FLOOR-MAP-ROSTER.md`. Danh sách quái trong brief là bản 2026-11-05, không phải pool.

`tessera_master.gpl` chỉ khóa màu của sprite đã duyệt: 5 anh hùng, Goblin trinh sát, Phù thủy rừng, nấm/vỏ đá của roster rừng, cộng màu tín hiệu VFX. **Không có dòng màu cho quái Hầm Ngục, Tháp, Đầm, Sa Mạc, Hỏa Ngục, Không Đảo, Tâm Lưới.** Những con đó chưa được phép gán hex. Muốn màu mới thì art-director thêm vào `.gpl` trước; `export_sheets.py` từ chối pixel đục ngoài list.

Đỏ báo đòn `#E5293B` không có trong file. Không dùng.

---

## Luật chung (brief §0)

Nền 800×360, ≤ 3 lớp. Dải xa 72 px. Hai lề 80 px. Đáy 36 % tối theo bậc. Đồ vật chỉ ở dải chân trời hoặc hai lề, cách mép sân ≥ 8 px. Không viền, S ≤ 25 %, không glow, không đỏ, không chữ.

Hình: vuông thẳng = lưới mới. Cong, mòn, bị phủ = thế giới cũ. Chỗ lưới chạm vật cũ thì cắt vuông 90°. Họa tiết duy nhất: ô vuông lồng ô vuông. Mỗi vùng 1–2 đá polyomino vỡ màu xám và 1 đồ ngà (kiếm gãy hoặc cờ rách).

Phiến: nine-slice 16×16, mặt 3 tông, không viền Mực, S ≤ 30 %, V ≤ 55 %. Phủ hữu cơ chỉ mép và góc, ≤ 25 % mặt, một màu phủ mỗi vùng. Nứt ≤ 2, bậc thang 1 px.

Hai nửa sân do code nhân sau, không vẽ vào texture: người chơi `#B8CCE8`, địch `#9A84A4`.

Mật độ: thưa = Tháp, Không Đảo, Sa Mạc, Tâm Lưới (≤ 3 lớn + ≤ 6 nhỏ). Dày = Rừng, Đầm, Hầm (≤ 6 lớn + ≤ 12 nhỏ).

---

## Từng vùng được dùng gì

### Rừng Sương `forest`

| | Được | Không |
|---|---|---|
| Chất | Đá xám, rêu, rễ, lá, sương, vòm đá đổ, cột gãy | Lá tươi, nắng, tia sáng |
| Nền | Trời `#7D8896`. Đồi cây + 3–4 tàn tích ≤ 25 px, V ≤ 45. Rễ và cột ở lề. Sương trôi ≤ 1 px/s | Cầu vòm cao. Ngọn cây lấn HUD |
| Sàn | Mặt `#6A6B62` / `#4C4D47` / `#3A3B37`. Mép `#262521`. Vạch `#5A5B54`. Phủ rêu ở góc. Bệ mặt `#3A3B37`, thành `#262521`, mép thành `#5A5B54` | |
| Hình lưới | Phế tích lát đá, rễ đội ô | |

Đã có art. Brief không yêu cầu làm lại cả bộ.

### Hầm Ngục `dungeon`

| | Được | Không |
|---|---|---|
| Chất | Đá xám lạnh, vòm, 4–5 cột, xích treo, bụi đá, xích gỉ ở mép phiến, hố sập (ô Lỗ, code) | Trời, chân trời, đuốc phát sáng |
| Nền | Tường vòm thay trời. Chân tường đúng chỗ chân trời. Trần tối. Đuốc = mảng ochre đục tĩnh `#8A6A40` | Lửa đuốc sáng. Hố sập vẽ sẵn trong nền |
| Sàn | Sàn lát ô, lưới trùng kiến trúc cũ. Phủ bụi đá và xích gỉ | |
| Fallback | Trời `#4A4440`, đất `#2C2826`. V nền ≤ 30 | |
| Kẻ Gác | Đá xám, vai rộng, đầu nhỏ, vương miện và râu ngà, xích `#8A6A40` | Vòng đá lơ lửng quanh người |

### Tháp Sương `ice_tower`

| | Được | Không |
|---|---|---|
| Chất | Phiến băng tối, sương giá lam-xám ở mép, biển mây, 2–3 tháp xa, lan can, cột băng thấp | Tinh thể cyan, `#A6EEFF` |
| Nền | Trời `#8E95B8`. Biển mây. Tháp thưa. Lan can và cột băng ở lề | Sân tròn vẽ trong nền (ô vẫn vuông, chỉ khuyết) |
| Sàn | Phiến tối `#4C5266`. Phủ sương giá mép, lam-xám | Cyan trên phiến |
| Fallback | Trời `#8E95B8`, đất `#4C5069` | |
| Kẻ Gác | Cao, hẹp, áo xanh đêm, cổ lông ngà, vương miện gai băng, mũ không mặt. Gai băng một vai | Băng xanh sáng, khói áo tràn khung |

### Đầm Lầy `swamp`

| | Được | Không |
|---|---|---|
| Chất | Đá chìm bùn, rong ở mép, nước phẳng, cột chìm, lau, nấm `#6A5868`, sương độc không tươi | Ô-liu tươi |
| Nền | Trời ô-liu xám. Tàn tích thấp trong sương. Nấm ở lề | |
| Sàn | Mép chìm, rong. Ô lầy là luật chơi, không vẽ sẵn: mặt `#4E4A2A`, bọt `#A8C83A` ≤ 8 px, phiến chìm 2 px | `#4E4A2A` trên nền thường |
| Fallback | Trời `#6B705A`, đất `#353A2C`. V nền ≤ 40. Chủ đạo ô-liu `#4E4C3C` | |
| Kẻ Gác | Thân tròn, thấp, rộng. 3–4 nấm `#6A5868` trên đầu. Rêu nhỏ giọt | Dây chuyền ô vuông ngà (đọc thành Khối) |

### Sa Mạc `sands`

| | Được | Không |
|---|---|---|
| Chất | Đá quảng trường, cát tràn từ một phía trên phiến, cồn, vòm, cột nửa vùi, bình ngọc đục `#4F8A80`, sương cát | Cát phủ kín phiến trong tấm nền. Ngọc tươi |
| Nền | Trời be bụi. V 60–72 nên quái cần mảng tối | |
| Sàn | Phủ cát một phía, ≤ 25 % mặt. Ô cát lấp là luật: sóng hữu cơ phủ 100 % | |
| Fallback | Trời `#B8A888`, đất `#6E6248`. Chủ đạo `#A89A80` | |
| Kẻ Gác | Ngồi thẳng. Đầu người, sừng, đai ochre, ngọc `#4F8A80`, cánh phiến đá gập | Nằm ngang, vàng, gạch lơ lửng |

### Hỏa Ngục `hellfire`

| | Được | Không |
|---|---|---|
| Chất | Than, tháp nhọn đen, tường, xích, tro và mép cháy xém trên phiến | Cam sáng trên nền, thác dung nham, đỏ |
| Nền | Trời than. V ≤ 25 | |
| Sàn | Nứt thành ô. Khe mạch 3 px = 1 px Mực + 2 px `#FFB21F`. Chỉ trong khe | Vân cam trên thân quái, mắt cam |
| Fallback | Trời `#3A3236`, đất `#1F1B1D`. Chủ đạo `#24201E` | |
| Kẻ Gác | Giáp phiến than, hai sừng cong đồng, ngực nứt ochre tối, áo cháy xém | Vân dung nham cam khắp thân |

`#FF7A1F` là Cháy, không phải màu tường.

### Không Đảo `sky_isles`

| | Được | Không |
|---|---|---|
| Chất | Đá đảo `#5A5048`, mòn gió, gần như không phủ. Biển mây. Đảo nhỏ xa. Vạch sét tĩnh. Vàng sấm S ≤ 30 % | Lưới đặt trên đất phẳng |
| Nền | Trời `#8AA2B8`, V 55–72. Mây tối hơn trời 1 bậc. Lưới chỉ trên thân đảo | |
| Sàn | Mặt đá nâng. Chân đá thon là code. Ô sắp rơi là luật (nứt + nét đứt) | |
| Fallback | Trời `#B9BFC8`, đất `#6A7080` | |
| Kẻ Gác | Rồng chữ S, rộng ≤ 40 trong dáng cũ, đầu cao, hai sừng ngà, cánh gập, mây ở chân | Sừng vàng, sét, cụm đảo, cánh xòe quá khung |

### Tâm Lưới `lattice_heart`

| | Được | Không |
|---|---|---|
| Chất | Đá chàm, bậc đài ngà-xám, 4–6 cột. Phiến không phủ, có rãnh ô vuông lồng ô vuông | Địa hình cũ, chữ, icon trái tim |
| Nền | `#15142A`, không chân trời. Lưới `#FFD45C` nét 1 px, phủ 20–40 %. V ≤ 20 | Vàng chiếm nền |
| Fallback | Trời `#15142A`, đất `#0E0D1C` | |
| Trùm | Áo thụng ngà-xám, mũ trùm mặt trống, dải vải 2 px, một tay mở. 3 mảnh Ánh Lưới do code, không vẽ vào sheet | Bệ phiến, hàng khối lơ lửng, vàng phủ thân |

Pha 2: lưới nền sáng thêm 1 bậc và hai cung ngà sau đầu, cũng là lớp code/nền riêng, không phải màu thân.

---

## `tessera_master.gpl` — 47 màu

RGB trong file. Hex là mã ghi cạnh tên. Màu ghi "không dùng ở khung hiện tại" vẫn nằm trong list (exporter cho qua) nhưng không được đưa vào prompt con mới.

### Dùng chung

| RGB | Hex | Tên | Dùng cho |
|---|---|---|---|
| 27 23 34 | `#1B1722` | Ink | Viền đơn vị và Khối |
| 239 230 210 | `#EFE6D2` | Ivory | Viền trang trí, mắt, răng |

### Kiếm sĩ `kiem_si`

| RGB | Hex | Tên | Ghi chú |
|---|---|---|---|
| 52 64 110 | `#34406E` | Tabard navy | Đang dùng |
| 184 137 58 | `#B8893A` | Trim gold | Đang dùng. Không phải Ánh Lưới `#FFD45C` |
| 216 205 176 | `#D8CDB0` | Hair ash blond | Đang dùng |
| 143 163 184 | `#8FA3B8` | Armour mid | Cũng là thân khối Thép |
| 238 244 250 | `#EEF4FA` | Armour light | Cũng là sáng khối Thép |
| 95 111 130 | `#5F6F82` | Armour dark | |
| 227 185 154 | `#E3B99A` | Skin | Da chung, Giáo sĩ cũng dùng |
| 79 88 100 | `#4F5864` | Cloak dark Mist | Trong list, khung hiện tại không dùng |
| 232 217 168 | `#E8D9A8` | Hair pale blond | Trong list, khung hiện tại không dùng |

### Pháp sư — chỉ màu khối, không có ramp áo trong file này

| RGB | Hex | Tên |
|---|---|---|
| 58 42 38 | `#3A2A26` | Than khối |
| 240 160 48 | `#F0A030` | Hổ phách khối |

### Sát thủ `sat_thu`

| RGB | Hex | Tên |
|---|---|---|
| 44 42 53 | `#2C2A35` | Vải tối |
| 58 55 68 | `#3A3744` | Vải |
| 85 80 100 | `#555064` | Vải sáng |
| 94 70 54 | `#5E4636` | Da thuộc |
| 138 106 80 | `#8A6A50` | Da thuộc sáng |
| 191 243 236 | `#BFF3EC` | Ngọc trắng, mép mũ và lưỡi. Cũng là khối Băng sắc |

### Thợ săn `tho_san`

| RGB | Hex | Tên |
|---|---|---|
| 92 58 34 | `#5C3A22` | Da thuộc tối |
| 138 90 51 | `#8A5A33` | Da thuộc. Cũng là thân khối Gỗ |
| 94 97 80 | `#5E6150` | Choàng |
| 126 128 104 | `#7E8068` | Choàng sáng |
| 70 214 164 | `#46D6A4` | Ngọc dây. Cũng là dây khối |

### Giáo sĩ `giao_si`

| RGB | Hex | Tên |
|---|---|---|
| 110 114 130 | `#6E7282` | Áo bóng |
| 184 188 200 | `#B8BCC8` | Chì. Cũng là chì khối Kính |
| 226 227 234 | `#E2E3EA` | Áo ngà-xám |
| 227 185 154 | `#E3B99A` | Da, dùng chung với Kiếm sĩ |

Tím lilac `#B9B0DC` của spec Giáo sĩ **không** có trong gpl và không có trên sprite đã duyệt. Không đưa vào prompt.

### Goblin trinh sát `goblin_scout` — con quái duy nhất có ramp riêng

| RGB | Hex | Tên | Ghi chú |
|---|---|---|---|
| 125 139 90 | `#7D8B5A` | Da giữa | |
| 89 100 63 | `#59643F` | Da tối | Trong list, khung hiện tại không dùng |
| 154 125 94 | `#9A7D5E` | Da thuộc | |
| 102 82 63 | `#66523F` | Da thuộc tối | |
| 143 160 112 | `#8FA070` | Mũ rêu nhạt | |

### Roster rừng khác — file chỉ khóa nhóm màu, không khóa từng con

Comment trong gpl gán như sau, không có bảng pixel từng loài:

| Nhóm | Hex | Gán cho |
|---|---|---|
| Rêu `#5E6B55`, rêu tối `#4A5545`, rêu sâu `#3A4538` | vùng + VFX rễ / Phù thủy | |
| Vỏ gai `#4A3A2A`, bóng gai `#8A7350` | Phù thủy rừng, gai | |
| Nấm `#4A3E4A` `#6A5868` `#8E8296` | mũ Nấm Mũ Xám | |
| Đá `#2C2925` `#4A4640` `#5A5650` `#6A6B62` | phiến, và vỏ Lính Gác Rêu / Mẹ Gai Sương | |

`dire_wolf`, `wolf_alpha`, `rootling`, `goblin_archer`, `goblin_warlock`, `ancient_root_sentinel` không có dòng riêng. Màu của chúng là màu đã dính trên sheet đã duyệt, không được suy từ tên.

### Tín hiệu, không tô thân quái

| RGB | Hex | Tên |
|---|---|---|
| 255 122 31 | `#FF7A1F` | Cháy |
| 255 178 31 | `#FFB21F` | Mạch dung nham |
| 184 154 106 | `#B89A6A` | Gai |

### Hex nằm trong brief nhưng không nằm trong gpl

Không đưa vào sprite: `#C9BB9B`, `#DCCFB0`, `#8F8167` (ấn ký khối nhặt), `#B8CCE8`, `#9A84A4` (nhân nửa sân), các fallback trời/đất của vùng chưa có nền, `#8E95B8`, `#4C5266`, `#4E4C3C`, `#A89A80`, `#4F8A80`, `#24201E`, `#8AA2B8`, `#5A5048`, `#15142A`, `#8A6A40`. Chúng là màu nền hoặc màu code, không phải màu đơn vị đã khóa.
