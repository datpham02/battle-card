# Art Bible: Tessera

> **Status**: Draft (đủ 9 mục, người dùng duyệt từng mục 2026-10-28/29)
> **Owned By**: art-director
> **Last Updated**: 2026-10-29
> **Art Director Sign-Off (AD-ART-BIBLE)**: SKIPPED 2026-10-28 — solo mode

`/art-bible` writes these nine sections in this order and replaces each
section's `[To be designed]` line as that section is approved. A section still
holding its placeholder is incomplete; a later run fills only those.

## 1. Visual Identity Statement

**Quy tắc một câu:**
> **"Đá lặng, sương mờ, pixel gọn: chỉ Khối phát sáng, và mọi sức mạnh đều mang hình ô vuông."**

Khi phân vân: nếu nền tranh mắt với Khối, giảm độ tươi và độ sáng của nền, không làm Khối sáng thêm.

**Hướng phong cách (người dùng chốt 2026-10-28):** pixel art. **Chỉ góc nhìn lấy theo One Step From Eden**; mọi thứ còn lại là của Tessera.
- Chiến trường vẽ ở **640×360**, phóng to bội số nguyên: ×2 / ×3 / ×4 trên màn cao 720 / 1080 / 1440.
- **Góc nhìn (đối chiếu ảnh chụp OSFE thật, 2026-10-28):**
  - lưới phẳng nhìn thẳng, ô chữ nhật rộng hơn cao, không phối cảnh; chiều sâu của phiến lấy từ mép trước 2–3 px;
  - đơn vị đứng thẳng, chân trong ô, đầu và thân lấn lên hàng sau; vẽ hàng sau trước, hàng trước sau. Cỡ sprite cố định (P2), nên cao ~1,5 ô ở sân 5×5 và gần 1 ô ở sân 3×3;
  - nền là phong cảnh nhìn ngang có chân trời; lưới nằm trên mặt đất tối hơn bên dưới.

**Đối chiếu với dòng "Art & audio direction" cũ trong `design/game-brief.md`** (dòng này viết trước khi có Tessera):
- "Hơi cartoon": giữ, ở dạng chibi pixel.
- "Sáng": chuyển từ nền sang Khối.
- "Nền đá khắc": giữ.
- "Ấn là ký tự phát sáng": bỏ. Khối không có chữ, không có rune.
- "Trận pháp vẽ sáng rồi bùng": thành ô đích sáng dần, phép rơi xuống, rồi phai (Bản Khắc).

### Nguyên tắc

**P1. Khối là nguồn sáng duy nhất, và sức mạnh luôn vuông** (Khối là nhân vật chính; luật thế giới sau Biến Cố)
- Chỉ Khối và hiệu ứng trạng thái được tươi cao và có glow. Nền và sân giảm độ tươi, tối hơn.
- Mọi VFX dựng từ ô vuông:
  - ô đích sáng dần, phép rơi xuống thành ô sáng;
  - phá phép: ô đích vỡ thành mảnh vuông;
  - tan thành hạt vuông.
- VFX phép làm theo **loại hiệu ứng**, không theo lá: 6 loại, tô màu chất liệu khối anh hùng (bảng ở Mục 3). Không bao giờ vẽ Khối cỡ lớn lên đất địch.
- Không tia, không nổ tròn kiểu anime.
- **Test:** làm mờ ảnh chụp màn hình; mắt phải rơi vào Khối hoặc ô đỏ trước. Hiệu ứng nào không vuông phải có lý do lore.

**P2. Dáng trước, chi tiết sau** (đọc được ở ô nhỏ; pipeline một người cộng AI)
- Sprite khung gốc 32×48, neo ở chân. Anh hùng cao khoảng 40 px gốc (quái và Kẻ Gác: Mục 3), viền tối 1 px.
- Mỗi nhân vật có một dáng đặc trưng (vật cầm hoặc mũ) và một màu nhấn.
- Bảng màu chung tối đa 64 màu (nâng từ 48, người dùng chốt 2026-10-29); mỗi vùng dùng một tập con.
- Sprite giữ **một cỡ cố định ở mọi sân**; ô lớn chỉ thêm khoảng thở.
- **Test** (ở 1×, trên sân 5×5, ô 38×27):
  - tô đen từng sprite: năm anh hùng và các quái cùng vùng vẫn phân biệt được;
  - ảnh màu, 3 quái đứng cùng cột ở 3 hàng liền nhau: vẫn đếm được 3 và nhận ra loài, dù nửa dưới thân bị che;
  - nếu cần thêm pixel mới nhận ra thì sửa dáng, không thêm chi tiết.

**P3. Đỏ là của mối nguy; hình nói trước màu** (báo đòn; accessibility)
- Dải đỏ, kèm sọc chéo và viền đậm, **chỉ dành cho báo đòn** trên đất người chơi.
- Hai nửa sân không tô đỏ/xanh như OSFE; phân biệt bằng vị trí và khe giữa.
- Đã chốt:
  - Dung nham Thành Hỏa Ngục: cam-vàng trên nền đen than.
  - Pháp sư: áo nâu than, nhấn hổ phách (người dùng chốt 2026-10-29). Khác trạng thái Cháy bằng hình ngọn lửa trên ô.
- **Không còn ngoại lệ** (người dùng chốt 2026-10-29): ô sáng khi kéo dùng **màu khối của nhân vật**; trúng/trượt đọc bằng hình (viền liền + ✓ / viền nét đứt + ✗). Đỏ chỉ có một nghĩa.
- Chất liệu Khối phân biệt bằng hình:

  | Chất liệu | Dấu hình |
  |---|---|
  | Thép | Vát cạnh |
  | Than lửa | Vết nứt |
  | Băng sắc | Nhỏ, cạnh nhọn |
  | Gỗ và dây | Khung buộc dây |
  | Kính thánh | Chia ô bằng chì |

- **Test:** chuyển ảnh sang đen trắng hoặc giả lập mù màu. Đạt khi phân biệt được ô đỏ, 5 chất liệu Khối, và Tường / Bãi Gai / ô cháy.

### Từ One Step From Eden: lấy và không lấy

Góc nhìn đã đối chiếu với ảnh chụp thật (2026-10-28). Các dòng khác vẫn là quan sát chung; cần thêm 2–4 ảnh trước khi dùng làm chuẩn.

| Lấy | Không lấy |
|---|---|
| **Góc nhìn:** lưới phẳng nhìn thẳng, ô rộng hơn cao | Ô chỉ là khung viền trơn (Tessera dùng phiến đá có mép) |
| Đơn vị đứng thẳng, lấn lên hàng sau | Viền ô xanh/đỏ theo phe |
| Nền nhìn ngang có chân trời, chi tiết nhưng trầm | Bảng màu neon, cyber-anime, súng và máy móc |
| Sprite pixel nhỏ, dáng rõ, viền tối | Bão hạt, rung màn hình, chớp sáng (lời chê "hỗn loạn" của OSFE) |
| Phép sáng, tươi, ít màu, nổi trên nền tối | Phép dạng đạn bay |
| **Ngôn ngữ UI** (người dùng chốt 2026-10-31): HUD vẽ sắc ở độ phân giải gốc, panel phẳng vát góc 45°, kim cương cho số quan trọng, thanh chia đốt, chữ sans trắng viền tối, số máu trên tấm tối dưới chân đơn vị | Màu UI của OSFE (navy, viền ô lam/đỏ theo phe); Tessera dùng Đá Đêm #1E1B24 và viền Sương |
| Bố cục khung hình: sân là một bệ đá nổi giữa cảnh, nền là **một bức** theo góc nhìn của sân | Nền kiểu nhìn ngang (platformer) có thân cây đứng trước sân |
| Icon HUD bão hòa, có glow nhẹ trong ô tối | Glow ở bất kỳ đâu trên sân (P1: chỉ Khối sáng) |

### Không làm
- Kiếm hiệp, tiên hiệp: mây cuộn, sơn mài đỏ-vàng, hoa văn Hán.
- Bản sao OSFE: neon, máy móc, ô viền trơn tô xanh/đỏ theo phe, bão hạt, rung màn hình.
- Chữ hoặc rune trên Khối và địa hình. Nhãn thuộc về HUD.
- "Pixel giả":
  - lẫn cỡ pixel;
  - khử răng cưa mờ;
  - phóng to tỉ lệ lẻ;
  - xoay sprite góc lẻ. Khối xoay 90° thì được.
- Đỏ ngoài báo đòn. Không có ngoại lệ.

### Hệ quả kỹ thuật (cần story riêng)
- **Chiến trường render qua SubViewport 640×360**, phóng to bội số nguyên. Lưới, nhân vật, Khối và VFX vẽ trong đó.
- **Ô snap theo pixel gốc:** nhỏ nhất khoảng 38×27, lớn nhất khoảng 64×46. Khối thu nhỏ trên đất: 5 px mỗi ô khối.
- **Góc nhìn OSFE không đổi phép chiếu.** Lưới vẫn là hình chữ nhật phẳng như code hiện tại; chỉ đổi neo sprite, thứ tự vẽ và lớp phủ.
- **HUD và chữ vẽ ở 1280×720**, bằng font có đủ dấu tiếng Việt. Font pixel ở 360p không hiện rõ "ế", "ộ".
- **Phần code phải sửa:**
  - dựng SubViewport;
  - đổi tọa độ chạm sang tọa độ gốc;
  - sửa `src/layout/screen_layout.gd` cho ô snap bội số 2;
  - neo sprite ở giữa đáy khung, đặt 3 art-px trên mép trước của phiến; vẽ theo hàng (hàng sau trước). Tường xếp chung với đơn vị;
  - báo đòn nằm **trọn ở lớp sàn, dưới đơn vị** (sửa 2026-10-31; trước đó viền 2 px ở lớp phủ): tô, sọc và viền 2 px + mép Mực đều dưới chân. Không nhãn đếm ngược: ô đậm dần từ lúc địch niệm tới lúc đòn rơi (sọc ≥ 50 % từ đầu, tô 0 → 45 %, viền 30 → 100 %); độ đậm là đồng hồ;
  - lớp phủ trên đơn vị cũng chứa: viền bóng khối và ✓/✗, VFX phép, Khối đang rơi, Khối trên đất và thanh độ tươi (thứ bậc #1–2 không bị đầu đơn vị che). Ô đích đang niệm nằm ở lớp sàn, dưới đơn vị, như phần tô của báo đòn;
  - chạm và thả khối tính theo ô sàn, không theo sprite;
  - mỗi vùng một nền nhìn ngang 800×360, nằm sau lưới.
- **Không gì trên ô được che đơn vị đứng trên ô** (người dùng chốt 2026-10-31, thay cho luật 2026-10-28 "viền và nhãn đếm ở trên đơn vị"): tô, sọc, viền ô đỏ và ô đích đều ở lớp sàn; không tấm số máu dưới chân; chip từ khóa đặt dưới chân, không đè thân. Chỉ VFX trúng đòn (≤ 0,35 s) được vẽ trên đơn vị. Sọc vẫn lộ ở phần trên ô và hai bên thân (kiểm ảnh 58/60).
- Các vùng Z1–Z5 của `design/ux/hud.md` không đổi vị trí. Ở sân 5×5, đầu đơn vị hàng sau cùng ló vào dải Z1 (anh hùng 19 art-px, quái 13, Kẻ Gác 31). **Người dùng chốt 2026-10-28: dồn Z1 lên 3–8 % chiều cao**, nửa dưới Z1 để trống cho đầu đơn vị (đã ghi vào `design/ux/hud.md`). Kẻ Gác đứng hàng sau, dưới thanh máu boss: Mảnh Gốc dời sang ngang vai.
- Màn điện thoại 20:9 không chia hết theo chiều ngang. Dự án đang để `window/stretch/aspect="expand"`, nên chỉ dư khoảng trống hai bên.

### Pipeline asset
1. Gen ảnh lớn bằng AI, một tư thế, nền phẳng.
2. Thu nhỏ nearest-neighbor về khung 32×48 (Kẻ Gác 48×64).
3. Ép về bảng màu chung (Aseprite).
4. Sửa tay viền và dáng.
5. Animation vẽ tay từ bản đã sạch.

Ở cỡ ~40 px, dọn ảnh AI có thể nhanh ngang vẽ tay; đo ở vertical slice rồi mới chọn. AI dùng tốt nhất cho concept, dáng và chọn màu. Công cụ pixel AI chuyên dụng (PixelLab, Retro Diffusion) có phí, cần thử trước.

### Rủi ro lớn nhất: khối lượng animation
Khoảng 70 sinh vật, phần lớn vẽ tay, một người làm. Ước lượng **chưa đo** của art-director:

| Loại | Ước lượng |
|---|---|
| Nhân vật chính (32×48) | Khoảng 8 h/con + ~1 h cử chỉ niệm 2 khung |
| Quái (32×48) | 3–4 h/con |
| Kẻ Gác (48×64) | Khoảng 10 h/con |
| Mỗi vùng (ô và nền nhìn ngang 2–3 lớp) | 10–14 h |
| VFX phép (6 loại dùng chung, tô màu bằng code) | 3–4 h/loại, 18–24 h |
| **Tổng** | **375–480 h** |

Giảm thiểu:
- Đóng Băng, Cháy và ô đích đang niệm làm bằng shader hoặc lớp phủ dùng chung. VFX phép dùng chung cho cả 5 anh hùng, chỉ đổi màu; không vẽ riêng từng lá.
- Quái thường dùng bộ animation tối thiểu: đứng 2 khung, bước 2, trúng 1, gục 2.
- Quái cùng loài dùng đổi màu cộng phụ kiện. Riêng 5 nhân vật chính phải khác hẳn nhau.
- Làm **vertical slice** trước (1 nhân vật, 1 vùng, 3 quái, Khối), đo giờ thật rồi mới ngoại suy.

## 2. Mood & Atmosphere

**Luật chung**
- Mood đổi bằng **bậc bảng màu**: nền và phiến tụt hoặc tăng 1 bậc sáng / độ tươi. Không dùng bloom, chớp hay rung.
- Glow là halo pixel vẽ tay quanh Khối (P1). Không dùng glow hậu kỳ của Godot, vì nó làm nhòe pixel. Phần cài đặt giao technical-artist.
- **Khối, ô đỏ, bóng khối và ô đích đang niệm không bao giờ bị làm tối hay khử màu** theo trạng thái.
- Không chớp toàn màn hình; mọi nhấp nháy ≤ 1 Hz. Khi bật Giảm chuyển động, nhịp đập thay bằng dấu tĩnh.
- Tông nền của Tessera: **lặng, u buồn, rõ ràng**. Chói sáng chỉ là khoảnh khắc ngắn.

| Trạng thái | Cảm xúc đích | Ánh sáng (nhiệt · tương phản) | Từ khóa | Năng lượng | Yếu tố mang mood |
|---|---|---|---|---|---|
| Trận, nhàn | Tỉnh táo, sẵn sàng | Màu vùng, tương phản vừa; Khối sáng nhất | lặng, gọn, rình | 3/5 | Khối rơi trên phiến tối |
| Trận, nguy (địch niệm) | Gấp, phải né | **Không đổi ánh sáng sân**; mối nguy nằm ở ô đỏ và dáng địch | sắc, đếm, ép | 5/5 | Ô đỏ sọc + Khối địch giơ trên đầu |
| Đặt khối / chọn lá (chậm 0,2×, Tập trung) | Thời gian đọng lại, cân nhắc | Nền và phiến tụt 1 bậc sáng, giảm 30 % độ tươi | treo, đọng, nét | 2/5 | Hạt bụi vuông lơ lửng gần như đứng im |
| Thức Tỉnh | Bùng lên có nghi lễ | Nền tối thêm 1 bậc; Ánh Lưới dâng từ mọi ô Bản Khắc | dâng, rực, ngắn | 5/5 | Nửa lưới địch sáng vàng cùng lúc |
| Bản đồ chuyến leo | Hành trình, cô độc | Lạnh, sương sớm, tương phản thấp; đỉnh núi sáng nhất | xa, cao, gió | 1/5 | Núi với lưới vàng lộ dần về đỉnh |
| Trại nghỉ | Ấm, an toàn tạm | Ấm; một vùng sáng nhỏ giữa nền tối | nhỏ, ấm, thở | 1/5 | Lửa trại trên một Khối than đang tan (lửa vuông, đúng P1) |
| Sự kiện | Tò mò, bất định | Trung tính, một nguồn sáng lệch tâm | lạ, lưỡng lự | 2/5 | Minh họa tĩnh trong khung phiến |
| Cửa hàng | Thực dụng | Ấm vừa, tương phản vừa | gọn, xếp, sạch | 2/5 | Vật phẩm xếp ô vuông trên quầy đá |
| Tha/Giết | Nặng, phán xét | Lạnh, tối; Mảnh Gốc là nguồn sáng duy nhất (nghiêng Tha: Mảnh ấm vàng; nghiêng Giết: Mảnh ngà lạnh) | tĩnh, câm, nặng | 1/5 | Kẻ Gác gục dưới Mảnh Gốc lơ lửng. **Không đỏ, không máu** |
| Tâm Lưới | Trang nghiêm, đỉnh điểm | Nền đen chàm, lưới Ánh Lưới lộ trần; pha 2 lưới nền sáng thêm 1 bậc | trần, thiêng, sáng | 4/5 | Lưới vàng mảnh phủ toàn nền |
| Thắng | Nhẹ nhõm, xứng đáng | Nền ấm lên 1 bậc, tương phản giảm | thở, lắng | 3/5 | Ô Bản Khắc sáng lần cuối rồi tắt dần |
| Thua | Mất mát, chấp nhận | Khử màu dần về Sương, tương phản thấp | phai, rã, lặng | 1/5 | Khối trong túi tan thành hạt; lưới xếp lại |
| Màn tiêu đề | U buồn, mời gọi | Đêm sang bình minh lạnh; ánh vàng ở đỉnh | xa, lặng, gọn | 1/5 | Núi Tessera, Khối rơi chậm từ đỉnh |

**Ba kết thúc ở Tâm Lưới**
- Lòng Tha Thứ: Ánh Lưới ấm.
- Cán Cân: nửa Ánh Lưới, nửa Sương.
- Lưỡi Kiếm Lạnh: ngà-lam lạnh, lưới cúi rạp.

**Theo vùng** (mỗi vùng một màu nền chủ đạo, độ tươi thấp)

| Vùng | Màu nền | Không khí | Ghi chú |
|---|---|---|---|
| Rừng Sương | Xanh rêu xám, mát | Lạc giữa phế tích hiền | Sương thấp che chân phiến |
| Hầm Ngục | Xám đá lạnh, tối nhất | Khép kín, ngột ngạt | Trong nhà, không chân trời: tường vòm thế chỗ. Đuốc là mảng ochre đục, **không phát sáng** |
| Tháp Sương | Lam-tím nhạt ở nền xa; phiến vẫn tối | Cô độc, lạnh dần | Chân trời thấp là biển mây; lưới trên sân thượng tháp |
| Đầm Lầy Độc | Ô-liu bùn | Nặng, dính, ngộp | Hơi độc là lớp mờ không tươi |
| Sa Mạc Cát Vùi | Be cát bụi, ấm | Mênh mông, bị vùi | Ngọc cổ chỉ là vết trên đá |
| Thành Hỏa Ngục | Đen than, nóng nhất | Nhịp đập, áp lực | Dung nham chỉ nằm trong khe |
| Không Đảo | Lam trời xám, nền xa sáng | Gió, chênh vênh | Lưới trên đảo đá nổi, dưới là trời; sấm vàng mờ ở chân trời |
| Tâm Lưới | Đen chàm | Trang nghiêm, trần trụi | Không chân trời; lưới vàng phủ toàn nền |

**Độ cao:** mỗi tầng lên, lưới nền lộ thêm 1 bậc và mây thấp dần. Không vẽ lại vùng theo tầng.

## 3. Shape Language

**Ngữ pháp gốc**
- **Vuông = sức mạnh:** Khối, Mảnh Gốc, VFX, UI.
- **Hữu cơ = thế giới cũ:** sinh vật, rễ, bùn, mây. Được phép vì chúng không phải sức mạnh (lý do lore theo P1).
- **Nhọn = thứ làm đau khi chạm:** gai, Băng sắc, sọc báo đòn.

**Bóng dáng ở khung 32×48** (test tô đen của P2)

| Nhóm | Khung | Dấu nhóm |
|---|---|---|
| Anh hùng | 32×48; cao 38–42 px, thân rộng ≤ 30; đứng thẳng, quay phải, đầu chibi ~14 px | Một vật vượt khỏi khối thân ≥ 4 px, ở nửa trên |
| Quái thường | 32×48; cao ≤ 34 px, loài thấp (nhầy, sói) ≥ 20 px; quay trái | Dáng loài ở nửa trên; biến thể = đổi màu + 1 phụ kiện |
| Tinh Anh | 32×48; cao ≤ 40 px, cùng loài với quái thường | 1 bộ phận phóng to + 2–3 "vảy lưới" vuông 2×2 px trên thân |
| Kẻ Gác | 48×64; thân cao ≤ 52, rộng ≤ 40 px; đứng một ô | **Mảnh Gốc** nổi trên đầu, cách 2 px, cao ≤ 8 px: polyomino màu Ánh Lưới, 2 px mỗi ô |

**Đứng trong ô.** Cỡ sprite cố định, nên độ lấn lên hàng sau đổi theo sân:

| Đơn vị | Sân 5×5 (ô 38×27) | Sân 3×3 (ô 64×46) |
|---|---|---|
| Anh hùng, Tinh Anh (40) | 19 px, ~70 % hàng sau | 0 |
| Quái (34) | 13 px, ~48 % | 0 |
| Kẻ Gác (52, Mảnh Gốc +10) | 31 px: cả hàng sau + 4 px; Mảnh Gốc tới 41 | 12 px, ~26 %; Mảnh Gốc tới 22 |

- Nửa dưới thân thường bị đơn vị hàng trước che, nên **mọi dấu nhận dạng (vật cầm, mũ, tai, Mảnh Gốc) nằm ở nửa trên**.

**Năm anh hùng**

| Anh hùng | Dáng tổng | Dấu duy nhất |
|---|---|---|
| Kiếm sĩ | Chữ nhật, vai vuông | Kiếm lớn chéo lưng, chuôi vượt đầu |
| Pháp sư | Tam giác cao, gầy | Mũ chóp nhọn gập đầu |
| Sát thủ | Thoi dẹt, khom; cao ~34–36 px (thấp nhất nhóm) | Mũ trùm nhọn + hai dao chĩa ngang |
| Thợ săn | Chữ T | Nỏ vắt ngang vai, mũ rộng vành |
| Giáo sĩ | Chuông đáy rộng | Gậy, đầu gậy là ô vuông lồng ô vuông |

**Quái và tư thế niệm**
- Dấu loài của quái:
  - goblin: tai nhọn ngang;
  - sói: thân ngang;
  - bộ xương: khe sườn hở;
  - dơi: sải cánh;
  - nhầy: vòm không chân.
- **Tư thế niệm của địch** (người dùng chốt 2026-10-29): đứng yên trong tư thế **lấy đà**: khom người, một tay kéo ra sau như sắp ném, tay kia chống ra trước; 3–5 hạt vuông màu ngà tụ ở bàn tay sau. **Không cầm khối, không giơ hai tay** (giơ hai tay đọc thành đầu hàng). Loài khác đổi cho hợp dáng (sói hạ thấp đầu, nhầy co lại) nhưng phải đọc là "sắp đánh". Đây là cửa sổ phản công nên phải thấy rõ; đòn rơi vào đâu do ô đỏ trên đất người chơi cho biết.
- Quái đứng yên suốt khi niệm, và đứng yên chính là dấu báo. Tư thế niệm nằm trong khung 32×48 (Kẻ Gác 48×64), không vượt khung.
- **Anh hùng niệm** (người dùng chốt 2026-10-28): cử chỉ ngắn ~0,2 s lúc đòn bắt đầu niệm (sau khi chọn lá), 2 khung (chuẩn bị 0,08 s, vung 0,12 s), rồi đi lại tự do. Trạng thái niệm nằm ở ô đích trên đất địch, không nằm trên anh hùng: **không hào quang**.
  - Cử chỉ hướng về phía địch, ngang vai. Không giơ gì quá đầu (để khác tư thế niệm của địch), không phóng vật gì ra (không đạn bay):
    - Kiếm sĩ: rút kiếm, chém ngang;
    - Pháp sư: đẩy hai tay ra trước;
    - Sát thủ: hất hai dao ra trước;
    - Thợ săn: giương nỏ ngang;
    - Giáo sĩ: chĩa đầu gậy ra trước.
  - Bấm bước trong lúc cử chỉ thì cắt cử chỉ, bước ngay.

**Khối và ô đích: các trạng thái**

| Trạng thái | Hình | Chuyển động |
|---|---|---|
| Rơi | Cỡ đầy, đủ chất liệu, vệt hạt vuông phía trên | Rơi thẳng; chạm đất bắn 2–4 hạt vuông; không nảy, không méo |
| Nằm trên đất | 5 px mỗi ô, đúng hình ghép của khối, dấu chất liệu 1 px, quầng sáng 1 px; **lơ lửng 2 px trên mặt phiến, bóng tối vuông in xuống phiến**; thanh độ tươi bên dưới | Đứng yên, không nhấp nhô (người dùng chốt 2026-10-29). Còn < 2 s: nháy 1 Hz (Giảm chuyển động: viền nét đứt) |
| Trong túi | Cùng cỡ art-pixel với sân; nhãn "5 ô" ngoài khối | Bay vào ô trong 0,2 s |
| Bóng khi kéo | Ô sàn đất địch trùng hình khối, **trọn ô**, đổi sang **màu khối của nhân vật** (người dùng chốt 2026-10-29); **không vẽ khối lên sân**. Khối nhỏ vẫn theo ngón tay, nâng 56 px; không có con trỏ bàn tay | Hít vào ô 0,05 s, chỉ đổi màu, không animation. Phần tô = màu khối; **viền và ✓/✗ = Ngà có mép Mực** (Mục 7.4). Trúng: tô đậm, viền liền, ✓ trên ô địch. Trượt: tô mờ 50 %, **viền nét đứt**, ✗ |
| Ô đích đang niệm | Đúng các ô đã chọn. Thân tô màu thân chất liệu, 60 %; dấu chất liệu phóng cỡ ô + mép nổi (sáng 1 px trên-trái, tối dưới-phải) màu phần sáng. Không sọc, không lõm, không viền trong, không ✓/✗ | Dấu và mép tăng đều 35 → 100 % trong thời gian niệm (0,2 s + 0,25 s/ô), bằng code, không khung vẽ, không nháy. Giảm chuyển động: 70 % cố định |
| Phép rơi | VFX theo loại hiệu ứng của lá (bảng dưới), rơi đúng các ô đích; rồi thành ô Bản Khắc lõm | VFX ≤ 0,35 s; Bản Khắc phai dần |
| Vỡ (Phá phép) | Mỗi ô đích tách 4 mảnh vuông màu chất liệu | Văng, rơi, xám dần về Đá rồi tắt; ≤ 0,3 s. Không để lại Bản Khắc (đòn chưa chạm đất) |
| Tan (hết hạn) | Tan từ mép vào thành hạt 1 px | Bay lên chậm ~0,5 s, giữ màu rồi trong dần |

**VFX phép theo loại hiệu ứng** (nhóm lá theo `design/game-mechanics.md` §3)
- Ô vuông 2×2 art-px màu phần sáng của chất liệu khối anh hùng, viền 1 px màu thân. Tô màu bằng code: một bộ khung dùng chung cho cả 5 anh hùng.
- Mỗi loại 3–5 khung, ≤ 0,35 s, chỉ trong các ô đích. Không tia, không nổ tròn, không rung màn.
- Phân biệt loại bằng **hình và hướng chuyển động**, không bằng màu (màu là của anh hùng).
- Giảm chuyển động: chỉ hiện khung cuối, tĩnh 0,15 s.
- Đòn trùng Hình Cộng Hưởng: chạy VFX của lá, rồi hiện chip từ khóa trên đơn vị (E-23). Không thêm VFX thứ hai.

| Loại | Lá | Hình | Chuyển động | Thời lượng |
|---|---|---|---|---|
| Chém | Nhóm Chém (Rạch nhẹ … Buốt xương) | Một vệt bậc thang ô vuông chéo qua mỗi ô đích | Quét một lượt từ trái sang phải, tắt | ≤ 0,25 s |
| Đẩy | Hích nhẹ, Xô lùi, Cú húc, Sạt lở | Cột ô vuông ở mép trái mỗi ô | Trượt sang phải nửa ô, mỏng dần | ≤ 0,3 s |
| Cháy | Tia lửa, Tro hồng, Lò than, Lửa rừng, Giàn thiêu | Cột ô vuông bậc thang mọc từ đáy ô | Mọc 2 bậc rồi hạ; ô cháy (màu Cháy, sọc ngang) hiện ngay sau | ≤ 0,35 s |
| Băng | Đóng Băng (Men băng … Tảng băng), Giá Lạnh (Rùng mình, Bão trắng, Sương bạc) | Mảnh 1–2 px rơi | Đông thành viền vuông quanh ô (Đóng Băng) hoặc dấu cộng giữa ô (Giá Lạnh), tắt | ≤ 0,35 s |
| Rạn | Nứt chân chim, Đứt gãy | Đường nứt bậc thang 1 px | Lan từ ô đầu đến ô cuối, tắt | ≤ 0,3 s |
| Dựng | Tường (Rào chắn, Lồng đá, Hàng cọc), Bãi Gai (Bụi rậm, Dây úa, Bẫy chông) | Ô vuông trồi từ mép trước phiến | Trồi lên, nhường chỗ Tường hoặc Bãi Gai (hình ở "Môi trường") | ≤ 0,3 s |

§3 không có lá hồi máu hay khiên nên không có loại đó. Có lá như vậy thì thêm loại thứ 7.

**Dấu chất liệu ở 5 px mỗi ô**

| Chất liệu | Dấu |
|---|---|
| Thép | Sáng 1 px góc trên-trái, tối dưới-phải |
| Than lửa | Thân tối, 1 vết nứt chéo |
| Băng sắc | Khuyết 1 px ở hai góc đối, trong suốt |
| Gỗ và dây | Khung 1 px + 1 dây ngang |
| Kính thánh | Chì chia ô 2×2 |

**Khối Lạ và Khối địch**
- **Khối Lạ:** không chất liệu; mặt phẳng màu Tím Lạ; **một viền bao ngoài cả hình** (không viền từng ô); sao dấu cộng 5 px ở góc.
- **Khối của địch:** phẳng màu ngà-đá, viền Mực, không chất liệu.

**Môi trường**
- **Phiến:**
  - mặt tối đa 3 tông;
  - mép trước 2–3 px, tối hơn mặt 2 bậc;
  - khe 1–2 px màu Mực (ngoại lệ: mạch dung nham Hỏa Ngục 3 px, Mục 6.3);
  - **không viền Mực**: viền chỉ dành cho đơn vị và Khối.
- **Khe giữa hai nửa sân:** ~6 px, có một đường lưới mảnh.
- **Lỗ:** mất phiến, lộ đáy vùng (tối, bùn hoặc trời); mép ô bên cạnh lộ ra.
- **Đảo:** cụm phiến có mép bao quanh. Riêng Không Đảo thêm chân đá thon nhọn bên dưới.
- **Sân vòng hoặc kim cương:** ô vẫn vuông, chỉ khuyết ô.
- **Tường và Bãi Gai đối lập ở bốn cặp** (cao/thấp, đặc/thưa, chữ nhật/tam giác, kín/hở):
  - Tường: khối dựng ~30 px (thấp hơn anh hùng), đặc, chữ nhật, viền kín, gạch chéo; vẽ theo hàng như đơn vị, che nửa dưới đơn vị phía sau.
  - Bãi Gai: thấp ≤ 6 px, gai tam giác thưa, lộ mặt phiến giữa các gai.
- **Ô cháy:** lửa bậc thang bằng ô vuông + **sọc ngang**. Sọc chéo chỉ dành cho báo đòn.
- **Dung nham:** chỉ trong khe giữa các ô.
- **Lầy, cát lấp:** hình hữu cơ, thấp.
- **Ô sắp rơi:** vết nứt + viền nét đứt.
- **Nền (nhìn ngang):**
  - mỗi vùng một tấm 800×360 (phủ màn 20:9 khi `expand`), dùng chung cho mọi cỡ sân của vùng; lưới đặt giữa;
  - tối đa 3 lớp: trời, dải đất xa, dải gần sát chân trời. Mảng khối lớn, không viền;
  - chân trời ở 9–13 % chiều cao (32–47 art-px), luôn trên mép trên Z2. Đầu đơn vị hàng sau đè lên dải xa, nên dải xa tương phản thấp nhất;
  - dưới chân trời là mặt đất, tối dần theo 2–3 bậc màu (không gradient mượt) tới đáy màn. Ngay dưới lưới tối hơn phiến ≥ 1 bậc;
  - chỉ lớp mây hoặc sương được trôi, ≤ 1 art-px/s; các lớp khác đứng yên. Bật Giảm chuyển động: đứng yên hết;
  - lưới mảnh của thế giới đè lên trời và đất xa, độ lộ tăng theo tầng.
- **Nền theo vùng (chỗ khác chuẩn):**
  - Hầm Ngục: trong nhà, không chân trời. Tường hầm có vòm và cột thế chỗ trời, chân tường nằm đúng chỗ chân trời; trần tối; đuốc là mảng ochre đục trên tường.
  - Tháp Sương: lưới trên sân thượng đá; chân trời thấp là biển mây lam-tím, tháp xa thưa; dưới mép sân là vách tháp tối.
  - Không Đảo: không có mặt đất. Lưới trên thân đảo đá thon xuống ~70 % chiều cao; quanh và dưới là biển mây, tối hơn trời 1 bậc; đảo nhỏ xa ở chân trời.
  - Tâm Lưới: không chân trời. Nền chàm phủ kín, lưới Ánh Lưới 20–40 % phủ toàn nền; dưới lưới tối nhất.

**UI**
- UI lặp lại hình phiến:
  - khung 9-slice góc vuông khuyết 1 art-px, mép dưới 2 art-px;
  - không bo tròn, không nút hình viên thuốc;
  - nút khi nhấn mất mép và tụt 2 art-px.
- Phần pixel của UI (khung, icon, khối thu nhỏ) vẽ đúng cỡ art-pixel của sân (×2 ở 720p). Chữ, số và thanh máu vẽ sắc ở 1280×720. Không trộn hai cỡ trong một icon.
- Icon trạng thái trên lưới 12×12 art-px (24 px ở 720p), mỗi icon một hình khác hẳn: ngọn lửa, khối băng, bông tuyết dấu cộng, vết nứt.
- UI nhấn mạnh bằng độ dày mép và độ sáng, không bằng glow.

**Thứ bậc, từ nổi nhất đến chìm nhất**

| # | Lớp | Cách vẽ |
|---|---|---|
| 1 | Khối và Mảnh Gốc | Halo pixel, viền Mực, tươi nhất |
| 2 | Ô đỏ báo đòn | Sọc, viền 2 px; viền và nhãn đếm vẽ trên đơn vị |
| 2b | Ô đích đang niệm | Màu chất liệu, không halo, không viền đậm, thân 60 %: ở đỉnh vẫn chìm hơn ô đỏ |
| 3 | Đơn vị | Viền Mực 1 px, tươi vừa, một màu nhấn |
| 4 | Phiến | Không viền, có mép, tươi thấp |
| 5 | Nền | Không viền, tươi và tương phản thấp nhất |

UI đứng ngoài thang này và giữ trung tính.

## 4. Color System

**Quyết định của người dùng (2026-10-28)**
- **Không đỏ trong HUD:**
  - Máu thấp: "!" + viền Ngà.
  - Thanh độ tươi khối: chỉ còn chiều dài.
  - Cảnh báo địa hình: cam-vàng nét đứt + chữ.
- **Bản Khắc dùng một màu Ánh Lưới** cho mọi nhân vật.
- **Khối Sát thủ:** ngọc-trắng trong suốt.

**Thang giá trị**

| Lớp | Độ tươi (S) | Độ sáng (V) |
|---|---|---|
| Khối | ≥ 60 % | ≥ 75 % |
| Đơn vị | 30–60 % | — |
| Phiến | ≤ 30 % | ≤ 55 % |
| Nền | ≤ 25 % | Trời ≤ 72 %; đất dưới lưới ≤ 30 % |

**Ngân sách 64 màu** (nâng từ 48, người dùng chốt 2026-10-29: 48 chưa tính da, tóc, da thuộc, vải của 5 anh hùng và ~22 thân quái)
- Dùng chung khoảng 26 màu: 7 màu chính + ~11 tín hiệu + ~8 màu khối anh hùng.
- ~16 màu cho da, tóc, da thuộc, vải (anh hùng và quái dùng chung ramp).
  - Đã đề xuất khi làm spec Kiếm sĩ (2026-10-29, `design/assets/specs/swordsman-assets.md`): giáp tối #5F6F82, áo choàng #4F5864, tóc vàng nhạt #E8D9A8, da #E3B99A.
- Còn ~22 màu cho 8 vùng: **mỗi vùng tối đa 3 màu riêng**; còn lại dùng chung ramp Đá và Sương.
- Muốn vượt 64 thì hỏi người dùng.

**Bảng màu chính**

| Màu | Hex | Nghĩa trong Tessera |
|---|---|---|
| Mực Viền | #1B1722 | Viền 1 px của đơn vị và Khối; đáy khe phiến. Không dùng đen thuần |
| Đá Lưới | #4A4640 · mép #2C2925 | Thế giới cũ: phiến sân |
| Sương | #7D8896 | Khoảng cách, nỗi buồn sau Biến Cố; nền xa; màn thua |
| Ngà | #EFE6D2 | Con người: chữ, UI; nền của Rạn |
| Ánh Lưới | #FFD45C | Sức mạnh Hình Gốc: Bản Khắc, Thức Tỉnh, Mảnh Gốc, Tâm Lưới |
| Đỏ Báo Đòn | #E5293B | Đòn sắp rơi xuống đất bạn. Không mang nghĩa nào khác |
| Tím Lạ | #E04CD0 | Khối Lạ: sức mạnh nằm ngoài bộ khối |

**Tín hiệu** (màu luôn đi kèm hình)

| Tín hiệu | Màu | Hình bắt buộc |
|---|---|---|
| Báo đòn | Đỏ #E5293B | Sọc chéo 45° + viền 2 px, **đậm dần** từ mờ tới đầy theo thời gian niệm của địch (không nhãn đếm ngược, sửa 2026-10-31) |
| Ô sáng khi kéo (trúng / trượt) | Tô: màu khối của nhân vật (đậm / mờ 50 %). Viền và ✓/✗: Ngà, mép Mực | Trúng: viền liền, ✓ trên ô địch. Trượt: viền nét đứt, ✗. Không cần bảng màu thay thế: trúng/trượt đọc bằng hình |
| Bản Khắc | Ánh Lưới, phai 100 → 0 % | Ô lõm vuông, viền trong 1 px |
| Ô đích đang niệm | Màu chất liệu khối anh hùng (không thêm màu); dấu và mép tăng 35 → 100 % | Dấu chất liệu cỡ ô + mép nổi. Khác Bản Khắc (lõm, viền trong, vàng, phai xuống) và báo đòn (đỏ, sọc chéo, đất bạn); không ✓/✗ |
| Cháy | #FF7A1F | Lửa bậc thang + sọc ngang |
| Đóng Băng | #A6EEFF | Vỏ băng vuông bọc sprite; icon khối băng |
| Giá Lạnh | #3A5CF0 | Bông tuyết dấu cộng + số tầng |
| Rạn | Ngà + vết nứt màu Mực | Vết nứt vắt qua sprite; icon vết nứt |
| Ô lầy (độc) | #A8C83A trên #4E4A2A | Bọt, ô sẫm, mép phiến chìm |
| Mạch dung nham | #FFB21F trên nền than | Chỉ trong khe. Sắp phun: khe sáng + nét đứt + chữ "SẮP PHUN" |
| Tường / Bãi Gai | #6E7A88 / #B89A6A | Khác hình hoàn toàn (Mục 3) |
| Khối Lạ | Tím Lạ | Viền bao ngoài cả hình + sao |
| Hồi máu / Giáp | #58D468 / #C8CED6 | Chữ "+8" / biểu tượng khiên |

**Khối của năm anh hùng** (màu nhấn trên áo = màu khối; không trùng tín hiệu)

| Anh hùng · chất liệu | Thân / phần sáng | Né va chạm bằng cách nào |
|---|---|---|
| Kiếm sĩ · Thép | #8FA3B8 / #EEF4FA | Vát cạnh; màu Giáp chỉ có ở HUD |
| Pháp sư · Than lửa | #3A2A26 / hổ phách #F0A030 | Thân **tối**, chỉ vết nứt sáng; tách khỏi Cháy, dung nham, Ánh Lưới |
| Sát thủ · Băng sắc | #BFF3EC trong suốt / #FFFFFF | Trong suốt, góc nhọn; Đóng Băng là vỏ đục và chỉ nằm trên đơn vị |
| Thợ săn · Gỗ và dây | #8A5A33 / dây ngọc #46D6A4 | Khi kéo, màu bóng thay hẳn màu khối |
| Giáo sĩ · Kính thánh | Kính #E4DAFF / chì #B8BCC8 | Nhạt, tươi thấp, có lưới chì; Khối Lạ thì tươi và có sao |

Khối của địch: #CFC6B4 phẳng, viền Mực.

**Nhiệt độ theo vùng**

| Vùng | Nhiệt | Màu chủ đạo | Cấm / hạn chế trên phiến |
|---|---|---|---|
| Rừng Sương | Mát | Rêu xám #5E6B55 | Lục tươi (va bóng trúng, ô lầy) |
| Hầm Ngục | Lạnh, tối | Đá xám lam #3E4450 | Cam đuốc tươi; thay bằng ochre đục #8A6A40 |
| Tháp Sương | Lạnh | Nền xa #8E95B8, phiến #4C5266 | Cyan tươi (va Đóng Băng) |
| Đầm Lầy Độc | Ấm, đục | Ô-liu xám #4E4C3C (nền S ≤ 25 %; #4E4A2A chỉ cho ô lầy) | Tím nấm phải xám hóa #6A5868 (tránh Tím Lạ) |
| Sa Mạc Cát Vùi | Ấm | Be cát bụi #A89A80 (nền S ≤ 25 %) | Ngọc cổ chỉ dạng đục #4F8A80 |
| Thành Hỏa Ngục | Nóng | Than #24201E | Cấm đỏ; cam chỉ ở dung nham |
| Không Đảo | Mát, sáng | Trời #8AA2B8, phiến đá ấm #5A5048 | Vàng sấm độ tươi ≤ 30 % |
| Tâm Lưới | Trung tính lạnh | Chàm #15142A + lưới Ánh Lưới 20–40 % | Nhiệt đổi theo kết thúc (Mục 2) |

**UI tách khỏi màu thế giới** (phẳng, không glow, không mang màu vùng)

| Thành phần | Màu |
|---|---|
| Nền khung | Đá Đêm #1E1B24 (90 %), viền #4A4652 |
| Chữ chính | Ngà, tương phản ~13:1 |
| Chữ phụ | #B8B0A0, ~7,9:1 |
| Nút Tung phép | #58D468, chữ màu Mực |
| Nút Hủy | #6B4A35, chữ Ngà |
| Viền khi chọn | Ngà, 2 art-px |
| Hạng (luôn kèm chữ) | Thường #B8B0A0 · Hiếm #5A9BFF · Sử thi #A97CFF · Boss Ánh Lưới |
| Thanh máu | Người chơi #58D468 · boss Ngà. **Không đỏ** |

**An toàn mù màu** (P = Protanopia, D = Deuteranopia, T = Tritanopia)

| Cặp màu | P | D | T | Hình cứu |
|---|---|---|---|---|
| Ô đỏ báo đòn – ô sáng khi kéo (Pháp sư, hổ phách) | lẫn | lẫn | đạt | Khác nửa sân; sọc chéo / không sọc, có ✓ hoặc ✗ |
| Bóng trúng – trượt (mặc định) | hỏng | hỏng | đạt | ✓/✗, viền liền/nét đứt, chế độ lam–cam |
| Cháy – dung nham – Than lửa | hỏng | hỏng | hỏng | Lửa trên ô / vạch trong khe / khối tối có nứt |
| Bản Khắc – Cháy | hỏng | hỏng | đạt | Ô lõm phẳng / lửa + sọc ngang |
| Đóng Băng – Giá Lạnh | đạt | đạt | gần | Khối băng / bông tuyết + số tầng |
| Ô lầy – ô sáng khi kéo (Thợ săn, dây ngọc) | lẫn | lẫn | đạt | Bọt + mép chìm / viền liền hoặc nét đứt + ✓/✗ |
| Khối Lạ – Đỏ Báo Đòn | đạt | đạt | gần | Sao + viền ngoài; khác chỗ (Khối khác ô đất) |
| Khối Lạ – Kính thánh | gần | gần | gần | Sao, độ tươi khác, lưới chì |
| Rạn – Bản Khắc | đạt | đạt | gần | Nứt trên đơn vị / ô lõm trên đất |
| Ô niệm Pháp sư (nứt hổ phách) – Bản Khắc | hỏng | hỏng | gần | Thân tối, mép nổi, 1 nứt chéo / ô vàng lõm, viền trong |
| Ô niệm Pháp sư – Cháy | hỏng | hỏng | hỏng | Thân tối có nứt / lửa bậc thang + sọc ngang. Khi ô niệm phủ lên ô cháy, thân 60 % phải đủ đè lửa (kiểm) |
| Ô niệm – ô sáng khi kéo (cùng màu khối) | — | — | — | Ô niệm: dấu chất liệu + mép nổi, không ✓/✗. Ô kéo: viền liền/nét đứt + ✓/✗. Chỉ gặp khi kéo khối mới lúc đòn cũ đang niệm |
| Ô niệm Thợ săn (gỗ) – Bãi Gai | lẫn | lẫn | lẫn | Khung + dây, mép nổi / gai tam giác thưa |
| Ô niệm Kiếm sĩ (thép) – Giá Lạnh, Đóng Băng | gần | gần | lẫn | Vát cạnh trên ô đất / bông tuyết, vỏ băng trên đơn vị |
| Ô niệm Kiếm sĩ – Tường | lẫn | lẫn | lẫn | Phẳng trên ô / khối dựng 30 px, gạch chéo |

**Lưu ý mù màu**
- **Cụm cam (Cháy, dung nham, Than lửa) không tách được bằng màu, kể cả với mắt thường.** Chỉ dựa vào hình. Phải kiểm ở vertical slice Hỏa Ngục + Pháp sư.
- Các cặp "Ô niệm" là ước lượng, chưa chạy giả lập. Kiểm ở vertical slice với cả 5 màu khối; cặp nặng nhất là Pháp sư niệm lên ô đang cháy.

## 5. Character Design Direction

Nguồn: ảnh concept tạm `design/art/reference/04-lineup-01`, `08-warden-*-01`, `08-heart-keeper-01`. Mục 1–4 thắng ảnh: chỉ lấy dáng, trang phục, đạo cụ; bỏ hex, vàng, glow, cỡ. Người dùng duyệt 2026-10-29.

### 5.1 Anh hùng
- Chibi ~2,8 đầu: khung 32×48 neo chân, cao 40 (38–42), rộng ≤ 30; đầu 14×13, thân 13, chân 10–12. Quay phải, 3/4.
- Nhận dạng ở **20 px trên** (đầu, vai, vật cầm); nửa dưới 2 tông, chỉ giữ dáng.
- Viền Mực 1 px ngoài; viền trong chỉ để tách bộ phận (≤ 3). Bóng ≤ 3 bậc mỗi chất liệu, sáng từ trên-trái.
- Mặt: mắt 2×2 Mực, không lòng trắng; miệng 1 px chỉ ở khung thắng/thua/trúng. Cảm xúc nằm ở dáng thân.
- ≤ 8 màu mỗi người. Màu nhấn = màu khối, ≤ 15 % pixel (chỉ phần nhấn được vượt S 30–60 % của Đơn vị). Tránh Cháy, Đóng Băng, Giá Lạnh, Ánh Lưới, Tím Lạ, Đỏ.
- Thức Tỉnh: màu nhấn đổi sang Ánh Lưới bằng shader chung; cái riêng là dáng (bảng 2).

| Anh hùng | Dáng · vật đặc trưng (nửa trên) | Chính · nhấn | Mặt, tóc ở 40 px |
|---|---|---|---|
| Kiếm sĩ | Chữ nhật, HAI vai vuông to đối xứng; kiếm thẳng hai lưỡi hẹp (2 px) trong vỏ tối đeo chéo lưng, chỉ chuôi + **chắn tay chữ thập** rộng ~6 px + núm tròn nhô trên đầu ≥ 4 px (dấu nhận dạng là chữ thập, không phải lưỡi bản rộng) | Giáp thép #8FA3B8 tấm đối xứng, viền Ngà ngang ngực; choàng ngắn ngang hông Sương tối #4F5864 cài hai vai (không lam #3A5CF0) · nhấn #EEF4FA | Tóc vàng nhạt cắt ngắn, mái bằng, 3 chùm nhỏ chỉ ở đỉnh, băng đầu Ngà 1 px; mắt mở 2×2, chân mày 1 px thẳng. *Sửa 2026-10-31: bản v1 (tóc dựng cao, đại kiếm bản rộng, choàng dài) đọc ra Cloud FF7 nên bỏ.* |
| Pháp sư | Tam giác cao gầy; mũ chóp gập có chùm bông. **Không sách** (cử chỉ cần hai tay trống) | **Áo nâu than #3A2A26** · nhấn hổ phách #F0A030 ở dải mũ, gấu áo, thắt lưng (người dùng chốt 2026-10-29) | Tóc bạc lòa xòa 3 px dưới vành; mắt 2×1 |
| Sát thủ | Thoi dẹt, khom; cao ~34–36 px (thấp nhất nhóm); mũ trùm nhọn, hai dao ngang ngực | Vải xám than #3A3744 · ngọc-trắng #BFF3EC ở lưỡi dao, mép mũ | Khăn che mặt; chỉ khe mắt Ngà 3×1 |
| Thợ săn | Chữ T; nỏ vắt vai, mũ rộng vành + 1 lông ngà | Da nâu #8A5A33, choàng xám-ô-liu S ≤ 35 % · dây ngọc #46D6A4 (≤ 6 px) | Tóc nâu; mắt 2×1 trong bóng vành |
| Giáo sĩ | Chuông đáy rộng; gậy đầu ô vuông lồng ô vuông; voan | Áo Ngà-xám, chì #B8BCC8 · tím nhạt #B9B0DC ở đầu gậy, mép voan | Voan phủ tóc; mắt nhắm 3×1 |

| Anh hùng | Idle (2 khung) | Cử chỉ niệm: A (0,08 s) → B (0,12 s), tầm vai, không quá đầu | Thức Tỉnh (2 khung lặp) |
|---|---|---|---|
| Kiếm sĩ | Ngực lên 1 px, đuôi choàng lệch 1 px; đứng dạng chân | A: kiếm rút ngang vai, mũi chỉ ra sau. B: chém ngang tới x = 30. Hết cử chỉ kiếm về lưng (không thêm khung) | Vung Hết Sức: hai tay cầm kiếm ngang ngực, thủ rồi chém; choàng bay |
| Pháp sư | Chóp mũ và chùm bông đung 1 px, bàn tay rảnh co duỗi | A: hai tay co sát ngực. B: hai lòng bàn tay đẩy ra trước | Bùng Nổ: hai tay dang ngang vai, mũ ngả sau |
| Sát thủ | Cả người tụt 1 px, mũi dao nhích ±1 px luân phiên | A: hai dao chéo trước ngực. B: hai tay hất ra, dao hướng phải | Bóng Lướt: lao người; 2 bản sao tối hơn phía sau cách 4 px (code) |
| Thợ săn | Vành mũ nghiêng 1 px, lông vũ rung, dồn trọng lượng | A: nỏ hạ ngang hông. B: nỏ giương ngang vai, mũi chĩa ra | Bẫy Sập: quỳ một gối, nỏ chống đất phía trước |
| Giáo sĩ | Voan và gấu áo lệch 1 px, đầu cúi 1 px | A: gậy dựng thẳng. B: gậy nghiêng, đầu gậy chĩa ra ngang đầu | Ban Phước: hai tay giữ gậy cắm xuống, cúi đầu |

- **Lấy từ `04-lineup-01`:** kiếm lưng, giáp vai (Kiếm sĩ); mũ chùm bông, viền gấu áo (Pháp sư); mũ trùm, dao cầm ngược (Sát thủ); vành rộng, lông, nỏ vai, dây (Thợ săn); voan, gậy ô vuông (Giáo sĩ).
- **Bỏ:** tóc trắng-vàng cả năm người (mất khác biệt); viền vàng (trùng Ánh Lưới); choàng lam hoàng gia (gần Giá Lạnh); sách Pháp sư; khăn lam-ngọc Sát thủ (va dây ngọc Thợ săn); tím bão hòa; mắt to có lòng trắng (vỡ ở 40 px).

### 5.2 Kẻ thù
- Phân biệt địch/ta ở 1× bằng 3 thứ:
  - quay trái, nửa sân phải;
  - **không có màu nhấn khối**: địch dùng màu vùng + Đá/Sương/Ngà, S 30–45 %;
  - anh hùng = đầu tròn + đạo cụ cạnh thẳng; địch = hữu cơ/nhọn (tai, sừng, cánh).
- Cùng viền Mực 1 px, không viền màu phe. Tư thế niệm theo Mục 3 (lấy đà, không cầm khối). Không có đồng minh hay NPC trong trận (NPC chỉ là minh họa tĩnh ở sự kiện/cửa hàng).
- **Quái thường** ≤ 34 px: dấu loài ở nửa trên.
- **Tinh Anh** ≤ 40 px: cùng loài + 1 bộ phận phóng to + 2–3 vảy 2×2 màu Ngà, phẳng, không glow.
- **Kẻ Gác** (48×64, thân ≤ 52×40): loài duy nhất, không biến thể, có **Mảnh Gốc**. Khác Tinh Anh ở 3 thứ: cao hơn ≥ 12 px, không thuộc loài quái thường, có Mảnh Gốc.
- **Mảnh Gốc:**
  - polyomino 4–6 ô, **mỗi Kẻ Gác một hình**; nếu dữ liệu có Hình Cộng Hưởng của vùng thì dùng đúng hình đó (cần kiểm);
  - 2 px/ô, ≤ 8 px cao, Ánh Lưới + halo 1 px, cách đầu 2 px, đứng yên;
  - sân 5×5, hàng sau cùng: dời ngang vai (Mục 1).
  - Ảnh `08-*` vẽ nó bằng ~1/3 thân: bỏ cỡ, giữ ý "mỗi hình một Kẻ Gác".

| Kẻ Gác | Thiết kế một dòng (nhận dạng ở nửa trên) | Lấy / Bỏ (`08-warden-*`) |
|---|---|---|
| Phù thủy rừng | Gầy; mặt nạ mỏ chim có sừng hươu (12 px trên), áo choàng lá rách, gậy cầm sát người, thấp hơn sừng | Lấy: sừng, mỏ, áo lá, tóc ngà. Bỏ: gậy cao quá đầu, hoa nhỏ, lá thò ra > 40 px |
| Quỷ Khổng Lồ | Đá xám, vai rộng 40, đầu nhỏ 12 px, vương miện + râu ngà, xích gỉ ochre #8A6A40 vắt ngực và cổ tay | Lấy: xích, vương miện, râu, giáp vai. Bỏ: vòng cột đá lơ lửng (tranh Mảnh Gốc) |
| Chúa Tể Sương | Cao hẹp, áo xanh đêm rũ, cổ lông Ngà, vương miện gai băng, mũ không mặt; gai băng chỉ ở một vai | Lấy: cổ lông, vương miện, mũ trống. Bỏ: băng xanh sáng (va Đóng Băng, khối Sát thủ), khói áo > 40 px |
| Cóc Chúa | Tròn, rộng 40, thấp; 3–4 nấm xám-tím #6A5868 trên đầu, rêu nhỏ giọt; tay sau kéo | Lấy: dáng tròn, nấm, bụng sáng. Bỏ: dây chuyền ô vuông ngà (đọc như Khối), nấm kem to |
| Nhân Sư Cát | **Ngồi thẳng**; đầu người đội sừng, đai ochre + ngọc #4F8A80, hai cánh phiến đá gập sau vai, đuôi vòng | Lấy: mũ sừng, cánh phiến. Bỏ: dáng nằm ngang (> 70 px), trang sức vàng (Ánh Lưới), gạch lơ lửng |
| Chúa Quỷ Lửa | Giáp phiến than, hai sừng cong đồng, ngực nứt bằng ochre tối, áo choàng cháy xém | Lấy: sừng, giáp phiến, áo rách. **Bỏ vân dung nham cam sáng khắp thân và mắt cam** (chỉ Khối phát sáng; cam = Cháy/mạch), gai lơ lửng |
| Long Vương Gió | Rồng uốn chữ S đứng, rộng ≤ 40: đầu cao hai sừng ngà, cánh gập sát, mây lượn ở chân | Lấy: đầu sừng, vảy xám-lam. Bỏ: sừng vàng và sét (Ánh Lưới), cụm đảo (thuộc nền), cánh xòe 60+ px |
| Người Giữ Tâm Lưới | **Khung 48×64 như Kẻ Gác** (người dùng chốt 2026-10-29); áo thụng ngà-xám, mũ trùm mặt trống, dải vải 2 px, một tay mở ra trước; **3 mảnh** Ánh Lưới trên đầu. Pha 2: palette sáng thêm 1 bậc + hai cung vòng bậc thang ngà sau đầu | Lấy: áo thụng, dải vải, cung vòng. Bỏ: bệ phiến, hàng khối lơ lửng, vàng phủ thân |

### 5.3 Dáng và biểu cảm
- Dáng phóng đại vừa, mặt tối giản: pose mạnh, không cứng như tượng. Idle luôn có chuyển động 1 px; trúng = ngả sau 2 px.
- Mỗi trạng thái đổi bóng đen ≥ 4 px so với idle. Thắng: nắm tay hoặc đạo cụ ngang vai. Thua: quỳ gục. Không máu, không đỏ.

### 5.4 Bộ animation tối thiểu (số khung vẽ, ước tính chưa đo)

| Trạng thái | Anh hùng | Quái, Tinh Anh | Kẻ Gác | Người Giữ |
|---|---|---|---|---|
| Idle / Bước | 2 / 2 | 2 / 2 | 2 / 2 | 2 / 2 |
| Niệm | 2 (cử chỉ) | 1 (lấy đà tĩnh) | 1–2 (+1 cho đặc tính) | 1 |
| Trúng | 1 | 1 | 1 | 1 |
| Gục / Thắng, Thua | Thắng 2, Thua 2 | Gục 2 | Gục 2 | Gục 2 + chuyển pha 2 |
| Rơi khỏi đảo | 1 | dùng khung Trúng | — | — |
| Thức Tỉnh | 2 (riêng) | — | — | — |
| **Tổng** | **14** | **8** | **9–10** + sprite Mảnh Gốc | **~11** |

- **Không vẽ khung** (code/lớp phủ dùng chung):
  - Đóng Băng: vỏ băng vuông, 2 cỡ khung.
  - Cháy: lửa bậc thang 2 khung + sọc ngang, 2 cỡ.
  - Rạn: nứt Mực trên Ngà.
  - Nháy trúng: đổi palette sang Ngà 0,06 s (Giảm chuyển động: 1 khung tĩnh), không đỏ.
  - Thức Tỉnh: shader palette.
  - Bóng chân: chữ nhật 20×2, tối hơn phiến 1 bậc.
  - Đẩy lùi, rơi: trượt/rơi thẳng, không xoay lẻ.
  - Hạt ngà ở tư thế niệm của địch.

### 5.5 LOD
- Ở 1× trên ô 38×27 (≈ ô 55 px cao ở 720p) **sống**: dáng, 1 vật nhận dạng dày ≥ 3 px, 1 màu nhấn, mắt 2×2.
- **Không sống**: ngón tay (bàn tay 2×2, 3×3 khi cử chỉ), họa tiết < 2×2, hoa văn áo > 3 đường 1 px.
- Cỡ sprite không đổi giữa sân 3×3 và 5×5 (P2): không có LOD thứ hai ở chiến trường. Chi tiết dồn nửa trên.
- **Chân dung (tier riêng, màn chọn nhân vật):**
  - 64×80 art-px (ngực lên), cùng cỡ pixel với sân, hiện ×2 ở 720p = 128×160.
  - Cùng bảng màu + viền Mực; thêm mắt 3×3 + điểm sáng 1 px, tóc 2 chùm bóng.
  - 1 biểu cảm. Anh hùng khóa = bóng Đá phẳng bằng shader (không vẽ).
  - Thêm ~2–3 h mỗi chân dung (~10–15 h, chưa đo).

### 5.6 Biến thể quái
- Một loài = 1 bộ thân (8 khung). Biến thể = **đổi 2–3 màu + 1 phụ kiện** ≤ 8×8 px ở nửa trên (mũ, tai, sừng, vai giáp). Phụ kiện vẽ một lần, ghép theo bảng offset từng khung (lệch ≤ 1 px). Cách đổi màu: xuất sẵn sheet riêng bằng script (Mục 8.4).
- ≤ 3 biến thể/thân + 1 Tinh Anh; thêm nữa thì là loài mới. Ví dụ goblin 6 vai = 2 thân (nhỏ: trinh sát, cung thủ, pháp sư; to: chiến binh, lực sĩ, vu sư) × 3.
- Hai biến thể cùng bóng đen phải khác ở phụ kiện nửa trên **và** ≥ 2 màu (test P2).
- Ước tính (chưa đo): ~60 sinh vật ≈ 22 thân (3–4 thân/vùng) × 3–4 h + ~40 biến thể × 0,5 h ≈ 100 h, thay vì 180–240 h nếu vẽ riêng từng con.

## 6. Environment Design Language

Nguồn: ảnh concept tạm `design/art/reference/07-*-01`, `09-world-map-01`. Mục 1–4 thắng ảnh. Người dùng duyệt 2026-10-29.

### 6.1 Ngôn ngữ kiến trúc
- **Vuông thẳng = lưới Hình Gốc (mới, chung); cong, mòn, bị phủ = thế giới cũ.** Phiến giống nhau ở mọi vùng (ramp Đá chung). Vùng chỉ đổi thứ phủ lên mép/khe và đồ vật bao quanh.
- Nơi lưới chạm rễ, tường, cát: vật cũ bị **cắt vuông 90°** (dấu Biến Cố).

| Vùng | Lưới đè lên | Phủ lên phiến (1 màu riêng) |
|---|---|---|
| Rừng Sương | Phế tích lát đá, rễ đội ô | Rêu ở góc |
| Hầm Ngục | Sàn ngục vốn lát ô, lưới trùng kiến trúc cũ; hố sập | Bụi đá, xích gỉ ở lề |
| Tháp Sương | Sân thượng lát phiến băng | Sương giá ở mép, lam-xám (không cyan) |
| Đầm Lầy | Lối đá chìm nửa trong bùn | Mép chìm, rong |
| Sa Mạc | Quảng trường cổ bị cát vùi | Cát tràn từ một phía |
| Hỏa Ngục | Sàn thành nứt thành ô, khe là mạch | Tro, mép cháy xém |
| Không Đảo | Mặt đảo đá bị nâng khỏi đất | Mòn gió, gần như không phủ |
| Tâm Lưới | Lưới lộ trần, không địa hình cũ | Không phủ; phiến có rãnh ô vuông lồng ô vuông (không chữ) |

### 6.2 Chất liệu
- Phẳng, khối màu. Phiến ≤ 3 tông (mặt, mép trước, khe Mực), **không viền Mực**. Nền không viền, không ánh sáng vẽ. Mặt phiến S ≤ 30 %, V ≤ 55 %.
- Vết nứt: ≤ 2/phiến, 1 px bậc thang, lệch mặt 1 bậc. Nhiễu: ≤ 4 % pixel, cụm 2 px, không rải từng pixel.
- **Dither: cấm** trên phiến, đơn vị, Khối, VFX. Chỉ cho lớp mây/sương và 1 dải chuyển giữa hai bậc nền kề: checker 2×2, ≤ 4 px rộng, trôi nguyên tấm.
- Vật phủ (rêu, tuyết, cát, bùn, tro): hữu cơ, thấp, chỉ ở mép và góc, ≤ 25 % mặt phiến.
- Ảnh `07-*`: **bỏ** viền Mực đậm 4 cạnh, hình thang phối cảnh, rêu rải khắp mặt. **Lấy** mép sáng 1 px trên-trái, khe tối.

### 6.3 Phiến và ô đặc biệt (hình theo Mục 3)
- **Quy tắc cỡ** (người dùng chốt 2026-10-29): mỗi vùng **1 bộ nine-slice 16×16 + 6 stamp** (vết nứt, vật phủ, 8×6 đến 16×8), dựng bằng code ở cỡ ô bất kỳ 38×27…64×46 (bội số 2).
  - Phần giữa tô phẳng tông A nên giãn được. Mép trước 2–3 px và khe 1–2 px cố định, không giãn.
  - Stamp đặt theo seed ô nên ổn định giữa các lần vẽ.
  - Chi phí ~2–3 h/vùng, nằm trong 10–14 h/vùng của Mục 1.
- **Bệ nổi (người dùng chốt 2026-10-31, phương án B):** lưới ô vẫn chữ nhật; cảm giác "bệ đá nhìn chếch" đến từ khung vẽ bằng code quanh sân, không từ ô hình thang: mặt bệ 6 art-px quanh mọi ô thật (khe giữa hai nửa cũng là đá bệ, một vạch mảnh ở giữa), **mặt trước 12 art-px** dưới mọi ô không có ô thật bên dưới (cạnh trên sáng 1 px, 2 px Mực ở đáy, mạch đá dọc), bóng 4 px Mực 50 % xuống đất. Vẽ theo từng ô nên sân khuyết ô vẫn đúng hình. Màu = bảng phiến v2 của vùng: mặt bệ tối hơn mặt phiến một bậc, mặt trước = màu mép. Mẫu: `prototypes/art-check --platform`, ảnh 56–57.
- **Phiến v2 (2026-10-31):** mặt 3 tông (cạnh sáng trên-trái, mặt, cạnh tối phải-dưới), mép trước tối với 1 px sáng ở cạnh trên; Rừng Sương: #6A6B62 / #4C4D47 / #3A3B37, mép #262521, vạch #5A5B54. Lý do: phiến v1 lẫn vào đất của nền.
- **Lỗ:** không vẽ phiến; tô đáy tối nhất của vùng (đất, bùn, mây); mép trước phiến trên kéo xuống 3 px thành vách.
- **Đảo, sân vòng/kim cương:** mép bao 2–3 px tối hơn 1 tông; ô khuyết giữ ô vuông. Không Đảo thêm chân đá thon bậc thang dưới hàng cuối (code).
- **Tường / Bãi Gai:** dựng trên phiến thường; Tường 30 px đặc, gạch chéo; Bãi Gai ≤ 6 px, gai thưa.
- **Ô cháy:** mặt tối thêm 1 bậc + lửa bậc thang + sọc ngang.
- **Ô lầy:** phiến chìm 2 px, mặt #4E4A2A + bọt #A8C83A ≤ 8 px.
- **Ô cát lấp:** sóng cát hữu cơ phủ 100 %, mép gợn.
- **Mạch dung nham (ngoại lệ Hỏa Ngục, người dùng chốt 2026-10-29):** khe 3 px = 1 Mực + 2 px #FFB21F.
- **Ô sắp rơi:** nứt + viền nét đứt; mọc lại bằng phiến trồi bậc thang từ dưới.

### 6.4 Nền nhìn ngang
- 800×360, ≤ 3 lớp (trời, xa, gần). **Dải cảnh xa chiếm 20 % chiều cao** (người dùng chốt 2026-10-31; trước đó chân trời 32–47 px ≈ 12 %): sân bắt đầu ở 20 %, nên cảnh xa có 72 art-px và hai lề 80 px mỗi bên. Dưới chân trời tối dần 2–3 bậc.
- **Nền là một bức, không phải dải + màu lấp** (sửa 2026-10-31 sau ảnh 51/52): vẽ cả tấm theo góc nhìn của sân (nhìn hơi chếch từ trên): cảnh xa trên, mép chuyển tiếp (bụi, đá, rễ) ngay dưới chân trời, khoảng đất trống nơi bệ đặt, hai lề có cột hoặc thân cây đóng khung, đáy 36 % tối dần theo bậc để vùng điều khiển có nền. Không thân cây đứng trước sân, không chân trời cắt bằng một đường thẳng.
- Ảnh `07-*` và `05-battle-*` là tham khảo bố cục và không khí, **không vẽ lại từ ảnh**. Lỗi của chúng (cảnh xa cao ~40 %, sprite to gấp đôi) không mang theo; ý tàn tích / vòm / cầu nén vào dải 20 % và hai lề.

| Vùng | Công thức (trời / xa / gần) | `07-*` đúng / sai |
|---|---|---|
| Rừng Sương | Sương #7D8896 phẳng / đồi cây + 3–4 tàn tích ≤ 25 px, V ≤ 45 / rễ và cột gãy ở lề; sương thấp trôi. Ứng viên cả tấm: `bg-explorations/fullframe-seed05` (2026-10-31) | Đúng: sương nhiều lớp, vòm cổng. Sai: cầu vòm xa cao |
| Hầm Ngục | Không trời; tường vòm + 4–5 cột, chân tường = chân trời; xích treo; đuốc = mảng ochre tĩnh | Đúng: cột, vòm, cờ ô lồng ô. Sai: lửa đuốc sáng; hố sập vẽ trong nền |
| Tháp Sương | Lam-tím #8E95B8 / biển mây + 2–3 tháp xa thưa / lan can, cột băng thấp ở lề | Đúng: biển mây, tháp xa, sân tròn. Sai: tinh thể cyan (va Đóng Băng) |
| Đầm Lầy | Ô-liu xám / tàn tích thấp trong sương, nước phẳng / cột chìm, lau sậy, nấm #6A5868 | Đúng: nước phẳng, nấm. Sai: ô-liu quá tươi |
| Sa Mạc | Be bụi / cồn + tàn tích vòm / cột nửa vùi, bình ngọc #4F8A80; sương cát trôi | Đúng: cồn, dải ngọc đục. Sai: cát phủ phiến sẵn (ô cát lấp là luật chơi) |
| Hỏa Ngục | Than / tháp nhọn đen / tường cháy, xích; **không cam sáng trong nền** | Đúng: tháp nhọn, xích. Sai: thác dung nham cam khắp nền |
| Không Đảo | Dải sáng chân trời, vàng sấm S ≤ 30 %, 1–2 vạch sét tĩnh / biển mây tối hơn trời 1 bậc, đảo nhỏ xa / lưới trên thân đảo | Đúng: biển mây, đảo xa, vạch sấm. Sai: lưới đặt trên đất phẳng |
| Tâm Lưới | Chàm #15142A, không chân trời / bậc đài ngà-xám + 4–6 cột / lưới Ánh Lưới 1 px phủ 20–40 % | Đúng: lưới mảnh có nút vuông, bậc đài. Sai: trái tim Hình Gốc (đọc như icon máu; Hình Gốc là polyomino vuông vỡ), vàng sáng chiếm nền |

### 6.5 Đồ vật và kể chuyện không chữ
- **Chỗ đặt:** (A) dải chân trời 0–47 px; (B) hai lề ngoài lưới, cách mép phiến ≥ 8 px; (C) dưới lưới là Z3/Z4, chỉ mặt đất, không vật.
- **Cấm:** vật trên hoặc chồng ô sân; vật có ΔV > 12 trong cột x của lưới, từ chân trời đến Z2 (đầu đơn vị hàng sau đè lên đó).
- **Mật độ:** thưa (Tháp Sương, Không Đảo, Sa Mạc, Tâm Lưới) ≤ 3 vật lớn (≥ 24 px) + ≤ 6 nhỏ; dày (Rừng, Đầm Lầy, Hầm Ngục) ≤ 6 lớn + ≤ 12 nhỏ, dồn ở lề.
- Vật không viền, S ≤ 25 %, ΔV với nền ≤ 20, tĩnh (chỉ mây/sương trôi), không glow, không đỏ, không chữ/rune. Họa tiết văn hóa duy nhất: ô vuông lồng ô vuông (cờ, cột).
- **Kể chuyện:**
  - Mảnh Hình Gốc vỡ: đá vuông gãy hình polyomino nằm lệch ở lề, xám, không vàng, 1–2 mỗi vùng.
  - Lưới lộ theo tầng: lớp 1 px phủ trời và dải xa, hiện bằng bậc màu đường kẻ (không alpha). Tầng 1 ẩn, tầng 2–5 sáng dần 1 bậc/tầng, Tâm Lưới 20–40 %. Mây hạ thấp theo tầng.
  - Dấu người: 1 vật Ngà mỗi vùng (kiếm gãy cắm đất, cờ rách).
  - Cắt vuông 90° ở chỗ lưới chạm vật cũ.
  - Vùng tự kể: cát vùi, bùn chìm, tro.
- `09-world-map-01`: lấy ý lưới vàng lộ dần về đỉnh; bỏ glow dày.

### 6.6 Kiểm tra dễ đọc (đơn vị trên nền)
- **Luật:** ≥ 40 % pixel nửa trên của đơn vị lệch V ≥ 25 điểm so với nền ngay sau đầu (ảnh xám). Viền Mực không đủ: ở nền V ≤ 25 nó biến mất.
- **Nền tối** (Hầm ≤ 30, Hỏa Ngục ≤ 25, Tâm Lưới ≤ 20, Đầm ≤ 40, Rừng ≤ 45): nửa trên cần ≥ 25 % pixel V ≥ 60 (xương, ngà, vải, sừng đồng).
- **Nền sáng** (Tháp, Sa Mạc 60–72; Không Đảo 55–72): nửa trên cần ≥ 40 % pixel V ≤ 40 (áo xanh đêm, mũ than). Quái băng/cát thân nhạt phải có đầu tối.
- **Trên phiến** (V ≤ 55): khối sáng V ≥ 60. Pixel S ≥ 60 và V ≥ 75 chỉ dành cho Khối, Mảnh Gốc, màu nhấn khối (giữ thứ bậc #1).
- **Kiểm:** ảnh xám + làm mờ, mỗi vùng × 5 anh hùng + 3 quái, ở vertical slice.

## 7. UI/HUD Visual Direction

Soạn: art-director (hình ảnh) + ux-designer (kiểm dùng được trên điện thoại). Người dùng duyệt 2026-10-29, chọn **số của UX** cho cỡ chạm và cỡ chữ. Mục này chỉ quyết phần nhìn; vùng Z1–Z5, danh sách E-xx, ngân sách thị giác, ưu tiên thông báo, tuning knob và tiêu chí nghiệm thu **tham chiếu `design/ux/hud.md`**, không viết lại ở đây.

### 7.1 Screen-space, không diegetic
- HUD là lớp kính đứng ngoài thế giới: phẳng, trung tính, không mang màu vùng, không glow (Mục 3–4).
- **Thuộc thế giới**, vẽ trong SubViewport 640×360:
  - lớp sàn, dưới đơn vị: ô sáng khi kéo, ô đích đang niệm, Bản Khắc, phần tô và sọc ô đỏ;
  - lớp phủ, trên đơn vị: viền ô đỏ, viền ô kéo, ✓/✗, thanh độ tươi khối, VFX, vỏ băng / vết nứt trên sprite.
- **Chữ và số không bao giờ diegetic.** Mọi chữ ở lớp HUD 1280×720, chỉ neo vào tọa độ thế giới (E-17, E-21–23, E-26), có viền Mực 2 px để đọc được trên mọi địa hình.
- Khối đang kéo vẽ ở lớp HUD: tọa độ màn hình, nâng 56 px trên ngón, đi qua cả túi lẫn lưới.

### 7.2 Từ các mockup tạm `05-battle-02…06`
- **Giữ:** thanh máu mảnh sát mép trên, không khung nặng; nút nền tối chỉ ở vùng chạm; ô túi lõm; pad chữ thập; ô đỏ sọc có viền; lề lưới rộng; thanh boss Ngà, thanh người chơi xanh; dải điều khiển dưới đặc, tách khỏi lưới.
- **Sửa:**
  - chữ mảnh kiểu pixel, không viền: thay bằng font ở 7.3;
  - thanh máu trơ, không rãnh: thêm rãnh Mực, khung 1 art-px, số "170/200";
  - nút Thức Tỉnh hình thoi (ô vuông xoay 45°, trái P1): đổi thành khung 2×2 ô, một ô sáng, kèm nhãn và "0/21";
  - nút và ô túi quá nhỏ (~50–84 px): theo cỡ ở 7.4;
  - thiếu đếm ngược E-17, số ô E-11, Xoay/Tung phép/Hủy E-12, tạm dừng E-03, Hình Cộng Hưởng E-15, khối boss E-18, thanh độ tươi E-38;
  - con trỏ bàn tay và đường nét đứt từ khối tới ô: bỏ;
  - thanh máu sát mép 14 px: đẩy xuống lề an toàn 22 px.

### 7.3 Chữ
- **Ngôn ngữ (người dùng chốt 2026-10-29): tiếng Anh là ngôn ngữ chủ đạo; trước mắt Anh + Việt**, sau có thể thêm. Font phải phủ nhiều hệ chữ và hợp phong cách game.
- **Hướng font (đề xuất, chờ thử trong Godot):** chữ thường (HUD, menu, mô tả) dùng **Noto Sans** (OFL; Latin gồm tiếng Việt, Hy Lạp, Cyrillic; thêm file Noto cho CJK/Thái… vào chuỗi dự phòng khi có ngôn ngữ đó). Chữ lớn (tiêu đề, biểu ngữ T1) dùng **một font pixel** có đủ tiếng Việt, ví dụ LanaPixel (cần kiểm giấy phép và dấu tiếng Việt). Không cần font CJK lúc này. Yêu cầu chung:
  - Latin đầy đủ (gồm tiếng Việt: Ơ ơ Ư ư Đ đ, U+1EA0–1EF9, dấu chồng "ế ộ ẫ Ắ");
  - mở rộng sang hệ chữ khác bằng **chuỗi font dự phòng** của Godot (thêm font cho CJK, Thái… khi thêm ngôn ngữ), không đổi font chính;
  - sans vuông vắn, mở, đọc được ở 18–24 px; không serif trang trí, không giả cổ, không kiếm hiệp;
  - số **tabular lining** để "170/200" không nhảy; không italic;
  - giấy phép cho phép nhúng vào game thương mại (OFL hoặc tương đương).
- Không dùng font pixel cho chữ dưới 24 px.
- Trọng lượng: Bold cho số và biểu ngữ; SemiBold cho tên và nhãn; Medium cho dòng nhắc và thân menu. Chữ hoa +4 % tracking; line-height ≥ 1,35 (không cắt dấu chồng). Viền Mực 2 px cho mọi chữ đặt trên thế giới.

| Cấp | px @720p | Dùng cho |
|---|---|---|
| T1 | 40 Bold hoa | NGẮT!, PHA 2, THẮNG/THUA (ở 130 %: ≤ 52) |
| T2 | 28 Bold | Số liệu chính: đếm ngược E-17, "7 ô", sát thương dự kiến, Tập trung |
| T3 | 24 / 32 / 40 Bold | Số nổi, theo lượng sát thương |
| T4 | 24 Bold; tên 24 SemiBold | Số máu "170/200", tên nhân vật |
| T5 | **24** SemiBold | **Nhãn cần hành động:** SẴN SÀNG, ĐẦY, SẮP PHUN, tên đòn, "5 ô", "cần N ô", tên lá |
| T6 | 18 SemiBold / Medium | **Chữ phụ:** hạng, số chip, dòng nhắc một lần, gợi ý ghép |
| Menu | 24 Medium; tiêu đề 32 SemiBold | Các màn menu |

- **Sàn đọc:** chữ cần hành động ≥ 24 px; 18 px chỉ cho chữ phụ. Mọi cỡ nhân hệ số S = cao màn / 720.
- **Cỡ chữ HUD 115 / 130 %:** nhân T2, T4–T6; T1 chặn 52 px. Nhãn trên lưới tự thu nhỏ cho vừa ô nhưng không dưới 18 px, ưu tiên rút gọn chữ. Tên lá cho phép 2 dòng. Z1 ở 130 %: số tối đa 26 px để vừa dải 36 px; tên cắt "…", tên đầy đủ có ở Tạm dừng.

### 7.4 Hệ khung, tương phản, cỡ chạm
- **HUD vẽ sắc ở 1280×720** (người dùng chốt 2026-10-31 sau style test OSFE, ảnh 40–57): panel, nút, thanh, chữ, số dùng đường 1 px và font ở độ phân giải gốc, không ép vào lưới art-pixel. Chỉ thứ nằm trên thế giới (icon trên đơn vị, ✓/✗, khối thu nhỏ) là pixel art ×2.
- **Hình khung:** nền Đá Đêm #1E1B24 ≥ 90 %, viền Sương #7D8896 1 px; **vát góc 45°** 12–18 px ở một hoặc hai góc thay cho khuyết 1 art-px; **kim cương** cho số quan trọng (Thức Tỉnh, giá ô, sát thương); thanh Bản Khắc **chia đốt**; thẻ ô túi có huy hiệu giá ở góc dưới; số máu trên tấm tối 52×18 dưới chân đơn vị. Nổi = có mép dưới 2 px Mực nhô dưới viền; nhấn = mất mép, tụt 2 px.
- **4 loại khung pixel 9-slice** (art-px; ×2 ở 720p; chỉ màu của Mục 4) — **dự phòng cho đường pixel**, không phải HUD chính nữa:
  - **Panel** 9-slice, lề 4 / 4 / 4 / 6. Nền #1E1B24 90 %, **viền Sương #7D8896** 1 art-px (≥ 3:1 trên nền; #4A4652 chỉ ~1,9:1 nên không dùng làm viền chính), góc vuông khuyết 1, mép dưới Mực.
  - **Button**: như Panel, nổi (có mép dưới). Nổi = bấm được.
  - **Slot** (túi, Hình Cộng Hưởng): lề 3, **lõm** (trên-trái Mực, dưới-phải #4A4652), viền ngoài Sương. Lõm = chứa đồ.
  - **Bar**: 3-slice ngang, đầu 2, viền 1; rãnh Mực 90 %.
  - Dải điều khiển dưới: nền đặc 100 %. Bề mặt có chữ hoặc icon không được trong hơn 85 %.
- **Trạng thái:** mặc định; nhấn = mất mép, tụt 2 art-px, tức thì, nhả 0,06 s (**vùng chạm không dịch theo**); tắt = nội dung 50 %, mất mép, kèm chữ lý do ("cần 3 ô"); chọn = viền Ngà 2 art-px; sẵn sàng (Thức Tỉnh) = viền Ánh Lưới 3 art-px; focus chỉ có ở bản dev desktop.
- **Icon HUD 55×55 px** (ứng viên 2026-10-31, gen từ mô tả, `candidates/slice1-ui/osfe-icons/`): ký hiệu một màu bão hòa trên ô Đá Đêm bo nhẹ, viền tối dày, glow nhẹ **chỉ trong ô icon**. Chip từ khóa trên đơn vị vẫn là icon pixel 12×12 (24 px), không thu icon 55 xuống.
- **Icon 12×12 art-px** (24 px, đường pixel và chip trên đơn vị): thân nét 2 art-px, tô phẳng một màu tín hiệu + 1 điểm sáng Ngà góc trên-trái; chỉ khối vuông và bậc thang 45°, không cong, không glow; viền Mực 1 art-px chỉ cho icon đứng trên thế giới. Test tô đen vẫn nhận ra.
  - Danh sách: tạm dừng, "!" máu thấp, ✓, ✗, Xoay, Giáp, 4 từ khóa (Cháy, Rạn, Giá Lạnh, Đóng Băng), mây (E-28), sao Khối Lạ, "+" ô túi trống, ⓘ, Bản Khắc/Thức Tỉnh (2×2 ô, một ô sáng), 4 mũi pad.
  - **Hủy chỉ có chữ**, vì ✗ đã mang nghĩa "trượt". **Khối hỏng ghi chữ "HỎNG"** + giây, không dùng dấu X.
- **Tương phản (sửa theo kiểm UX, cần đo lại bằng công cụ):**
  - ô đỏ báo đòn: viền đỏ có **mép Mực 1 art-px bên ngoài** (đỏ trên phiến chỉ ~2,1:1, đỏ trên Mực ~4:1);
  - nhãn đặt trên ô đỏ: chữ Ngà trên **tấm Mực**, không đặt thẳng lên đỏ;
  - chữ ≥ 4,5:1; chữ lớn, viền nút, icon, ✓/✗ ≥ 3:1;
  - chữ ở Z1 không có khung: luôn có viền Mực (nền Sa Mạc sáng).
- **Ô sáng khi kéo** (người dùng chốt 2026-10-29): **phần tô = màu khối** của nhân vật; **viền và ✓/✗ = Ngà có mép Mực** (đủ tương phản cả với khối tối của Pháp sư và khối nhạt của Giáo sĩ). ✓/✗ cỡ 24–32 px trên một tấm Mực nhỏ.
- **Cỡ chạm (theo UX; máy 6″ 20:9, 1 mm ≈ 11,5 px ở 720p — cần đo trên máy thật):**
  - điều khiển chính ≥ 96 px (mục tiêu 104 px nếu còn chỗ); điều khiển phụ ≥ 88 px;
  - **vùng chạm ≥ vùng nhìn**: hình nhỏ hơn 88 px thì vùng chạm vô hình vẫn ≥ 88 px;
  - khoảng cách hai nút kề nhau **≥ 12 px** (cụm pad ≥ 8 px); Tung phép và Hủy cách ≥ 24 px, khác cỡ và màu; tạm dừng cách mọi nút khác ≥ 24 px;
  - pad cách mép trái ≥ 56 px để tránh vùng vuốt Back của Android (cần kiểm trên máy).
- **Chip từ khóa dưới đơn vị:** sân 5×5 tối đa **2 chip**, phần dư gộp thành "+N"; sân lớn hơn tối đa 3.
- **Thanh độ tươi khối trên sàn:** dài cố định ≥ 24 px, cao ≥ 4 px, không phụ thuộc cỡ khối.

### 7.5 Thành phần chính
- **Thanh máu:** 12 px cao, đầu cắt vuông, rãnh Mực. Người chơi #58D468, boss Ngà. Vạch nửa máu boss: nấc Ngà 2 px, nhô 3 px. **Vết mất máu #B8B0A0** co dần 0,4 s (không đỏ). Máu thấp: "!" + viền Ngà 2 art-px nhấp 1 Hz; Giảm chuyển động: viền **đặc** 3 art-px, tĩnh (nét đứt đã mang nghĩa trượt/sắp rơi). Số "170/200" T4, tên trước số. Boss: căn phải, ba ô khối boss 24×18 px (Z1b) dưới thanh.
- **Pad:** 4 Button 97 px, mũi tên bậc thang 28 px Ngà, khe 8 px. Hồi bước: viền chuyển #4A4652 → Ngà theo nấc. Khi đặt khối: pad thay bằng nút Xoay 288 px, icon 48 px.
- **Thức Tỉnh:** Button ~280×96; "THỨC TỈNH" T5, thanh Bản Khắc #FFD45C 10 px + "0/21". Hồi: 50 % + "Hồi 12 s". Sẵn sàng: viền Ánh Lưới 3 art-px + "SẴN SÀNG" (độ dày 2↔3, 1 Hz; Giảm chuyển động: tĩnh 3).
- **Tung phép:** nền #58D468, chữ Mực T2 (cần đo tương phản), to hơn Hủy. **Hủy:** #6B4A35, chữ Ngà.
- **Túi khối:** Slot lõm, khối 8 art-px/ô, màu khối anh hùng, nhãn "5 ô" T5. Chọn: viền Ngà 2. Khối hỏng: xám + "HỎNG" + giây. Khối Lạ: sao 5 px.
- **Thẻ lá (E-13):** Button ~134×120. Dải trên 22 px màu hạng + nhãn hạng bằng chữ; tên tối đa 2 dòng; dưới "cần N ô" + sát thương/ô T2. Lá chưa đủ ô: trạng thái tắt.
- **Hình Cộng Hưởng:** Slot 36 px cao, ô 3 art-px, hình tối đa 4×4, màu Ngà phẳng; khớp: viền Ngà 2 art-px; không tương tác.
- **Số nổi (không đỏ):** gây sát thương = số trần T3 bay lên; **nhận sát thương = "−42" trong khung Panel nhỏ viền Ngà, tụt xuống 8 px rồi mờ**; hồi "+8" #58D468 bay lên; giáp = icon khiên + số #C8CED6; TRƯỢT = chữ #B8B0A0 đứng yên rồi mờ. Dấu, khung và hướng là kênh không-màu. Số không che ô đỏ.
- **Biểu ngữ:** Panel 90 %, chữ T1/T2, viền Ngà 2 (Ánh Lưới cho Thức Tỉnh/Bản Khắc). NGẮT!, ĐÒN GIẢ! dưới 15 % diện tích lưới; chạm ô đỏ thì dời lên mép trên lưới. Dòng nhắc một lần: Panel 1 dòng ≤ 60 ký tự, icon trái, T6, 6 s, ở mép trên Z2.

### 7.6 Chuyển động UI
- Không đàn hồi, không nảy. Xuất hiện ease-out 0,12–0,2 s (trượt 8 px + hiện dần); biến mất mờ 0,15–0,2 s; thanh và đếm ngược tuyến tính.
- Khung và icon di chuyển theo nấc art-px; chữ theo px nguyên; khung và chữ của một biểu ngữ đi cùng nhau.
- Nút nhấn tức thì. Xoay: khối quay 90° trong 0,1 s. NGẮT! lắc 0,15 s; pha 2 giáng 8 px trong 0,1 s.
- Màn kết quả trận: trượt 8 px + hiện 0,2 s (không phóng to khung pixel).
- **Tĩnh:** khung, pad, túi, nhãn, tên, thanh Bản Khắc (chỉ đổi khi giá trị đổi).
- **Giảm chuyển động:** bỏ trượt, lắc, giáng, nhịp, nhấp; chỉ hiện/tắt tức thì hoặc mờ ≤ 0,1 s; vết mất máu tức thì; viền tĩnh thay nhịp.

### 7.7 Nút tạm dừng (E-03)
- Button vuông **32×32 px** nhìn thấy (16×16 art-px, icon hai vạch), ở giữa trên, trong dải Z1.
- **Vùng chạm vô hình 88×88 px** kéo xuống dải 8–14 % đang trống; Hình Cộng Hưởng nằm ngoài vùng này.
- Chỉ kích hoạt khi chạm **bắt đầu** trong vùng (kéo khối đi ngang qua không bấm nhầm). Khóa 0,5 s sau khi tiếp tục.
- Nút Back của hệ điều hành cũng mở Tạm dừng (hud.md).

### 7.8 Hai lớp và đường nối
- **Pixel layer (SubViewport 640×360):** lưới, sprite, khối trên sàn, VFX, ô tô, sọc và viền ô đỏ, ✓/✗, thanh độ tươi. Không chữ.
- **Lớp HUD (1280×720 × S):** mọi chữ, thanh máu, thanh Bản Khắc; khung 9-slice, icon, khối trong túi và khối đang kéo vẽ theo art-px nguyên (= 2S px), nearest; chip từ khóa.
- Thứ tự vẽ: sàn → đơn vị → lớp phủ (trong viewport) → HUD. Neo HUD vào thế giới từ hình chữ nhật ô, làm tròn về 2 px; chữ làm tròn px nguyên. Không vật nào vắt qua hai lớp.
- Mọi nét UI ≥ 2 px ở 720p, để còn sắc khi máy 1080p phóng ×1,5.

### 7.9 Màn khác dùng lại hệ khung (mỗi màn cần spec UX riêng)

| Màn | Dùng lại | Thêm |
|---|---|---|
| Tiêu đề | Button, Panel | Wordmark, chữ 64 px |
| Chọn nhân vật | 5 thẻ | Khung chân dung (Mục 5.5), hàng chỉ số |
| Thưởng | 3 thẻ như E-13 | Nhãn hạng bằng chữ, ⓘ |
| Cửa hàng | Slot vật phẩm | Nhãn giá, icon vàng |
| Sự kiện | Khung minh họa | Nút lựa chọn rộng, đoạn văn 24 px |
| Trại nghỉ | Danh sách Button | Nền một nguồn sáng |
| Tha/Giết | 2 Button | Thanh giữ 0,6 s chạy trong nút (Ngà, không đỏ); lựa chọn chạm hai lần |
| Kết thúc | Trang chữ toàn màn | Khung trang, phân trang |
| Thành tựu | Lưới Slot | Trạng thái khóa (xám, không ẩn tên) |
| Cài đặt | Hàng, thanh trượt, nhóm nút 100/115/130 % | Công tắc BẬT/TẮT bằng chữ (không dùng ✓/✗), tay cầm vuông |
| Bản đồ | Dải E-29/30 | Icon nút, trái tim, xu |
| Tạm dừng | Panel phủ mờ | — |

### 7.10 Câu hỏi mở
- **Font:** thử Noto Sans (chữ thường) và một font pixel có tiếng Việt (tiêu đề) trong Godot với chuỗi mẫu Anh + Việt ("Tiếng Việt ẳ ẵ ặ ế ộ ử ữ ự") trước khi chốt; kiểm giấy phép.
- **Dải giữa Z4 nằm ngoài tầm ngón cái** trên máy 20:9 (tâm cách mép ~69 mm); có thể cần neo về phía tay rảnh. Thuộc `design/ux/hud.md`.
- **Vùng vuốt Back của Android** so với pad sát mép trái; cách xin loại trừ cử chỉ trong Godot 4.6 chưa kiểm.

## 8. Asset Standards

Soạn: art-director (hướng art) + technical-artist (giới hạn Godot 4.6 và điện thoại). Người dùng duyệt 2026-10-29 và chọn ở ba chỗ hai bên khác nhau (8.4, 8.5, 8.2). Số nào không ghi "Mục 1–7" là **đề xuất**; "chưa đo" là ước lượng; "cần kiểm" là chưa xác minh trên Godot 4.6. Repo hiện chưa có thư mục art (`assets/` chỉ có `data/`, `i18n/`), nên cấu trúc dưới đây là mới.

### 8.1 Định dạng, thư mục, tên
| Thứ | Định dạng | Ở đâu | Chủ |
|---|---|---|---|
| Nguồn vẽ | `.aseprite`, 1 file/đơn vị, tag = clip, thời lượng khung ghi trong tag. **Tạm chấp nhận (người dùng chốt 2026-10-31, Story 045):** thư mục PNG rời `art_src/units/<id>/<clip>/<n>.png` + `clips.json` (thứ tự, ms, lặp) khi chưa có họa sĩ làm trong Aseprite; exporter Python xuất cùng định dạng JSON nên engine không phân biệt | `art_src/` ở gốc repo, có `.gdignore` | art |
| Xuất đơn vị | sheet `.png` (mỗi hàng 1 clip, ô cố định, đệm 1 px trong suốt giữa ô) + `.json` Aseprite | `assets/art/...` | art xuất |
| Atlas trận | script gộp sheet thành **atlas chung** (5 anh hùng, VFX, lớp phủ trạng thái, icon, khung UI, chất liệu Khối) + **atlas vùng** (quái, Kẻ Gác, phiến, vật trang trí của vùng) | sinh tự động | technical-artist viết script; sửa một đơn vị thì chạy lại script |
| Khác | `.png` rời: nền, chân dung | `assets/art/...` | art |
| Màu | vẽ indexed theo bảng chung; xuất RGBA 8-bit; **alpha chỉ 0 hoặc 255** | | art |

- Thư mục: `assets/art/{palette,units,wardens,env/<region>,blocks,vfx,ui,portraits}/`. Region: `forest, dungeon, ice_tower, swamp, sands, hellfire, sky_isles, lattice_heart`.
- Tên: snake_case tiếng Anh cho nhóm, **id dữ liệu** cho tên (`kiem_si`, `phap_su`, `goblin_scout`…), dạng `[nhóm]_[tên]_[biến thể]_[cỡ]`.

| Asset | Ví dụ |
|---|---|
| Anh hùng | `units/unit_kiem_si_sheet.png` + `.json`; tag `idle`, `step`, `cast_gesture` |
| Quái, biến thể | `units/unit_goblin_scout_sheet.png`, `unit_goblin_scout_alt_sheet.png` |
| Kẻ Gác | `wardens/warden_forest_sheet.png` (48×64) |
| Phiến | `env/hellfire/env_slab_hellfire_9slice.png` + `env_slab_hellfire_stamps.png` |
| Tường / Bãi Gai | `env/forest/env_wall_forest.png`, `env_thorn_forest.png` |
| Nền | `env/sands/bg_sands_sky.png`, `bg_sands_far.png`, `bg_sands_near.png` |
| Ô khối | `blocks/block_tiles_16.png`, `block_tiles_5.png` |
| VFX | `vfx/vfx_slash_sheet.png` (6 loại: `slash, push, burn, ice, crack, build`) |
| Icon | `ui/ui_icons_status_12.png` |
| Chân dung | `portraits/portrait_phap_su.png` |
| Bảng màu | `palette/tessera_master.gpl` (Aseprite đọc thẳng), `tessera_master_lut.png`, `tessera_region_hellfire.gpl` |

### 8.2 Render và màn hình
- Chiến trường vẽ trong **SubViewport 800×360** (vùng chơi 640 ở giữa, 80 px mỗi bên chỉ là nền). Texture filter Nearest, MSAA 2D tắt, HDR 2D tắt.
- **Snap pixel đặt trên SubViewport**, không đặt toàn project (để HUD 1280×720 không bị snap). Tên cài đặt ở 4.6: cần kiểm.
- Hiển thị bằng một Node2D vẽ texture của viewport (dự án không dùng Control), `texture_filter = NEAREST`; HUD vẽ sau, ở độ phân giải gốc.
- **Hệ số phóng nguyên** n = max(1, floor(min(W/640, H/360))); rect đích 800n×360n căn giữa, cắt hai bên nếu thiếu. **Phần dư tô Mực** (người dùng chốt 2026-10-29). Ví dụ: 2400×1080 khớp n = 3; iPhone Pro Max dư ~16 % chiều dọc; iPad 4:3 dư ~30 %.
- `ScreenLayout` thêm `art_rect()` làm gốc cho Z1–Z5; tọa độ chạm đổi về art-px; input xử lý ở root (cần kiểm).
- Vị trí đơn vị, hạt, VFX làm tròn về art-px nguyên **trong code**; tốc độ tính theo art-px/s có bộ cộng dồn; không tween vị trí lẻ.

### 8.3 Khung, neo, đệm
| Loại | Khung (art-px) | Ghi chú |
|---|---|---|
| Anh hùng | **40×48** (sửa 2026-10-31: 32×48 không chứa nổi vũ khí rút ra ở khung niệm và Thức Tỉnh; thân vẫn ≤ 30, chỉ khung rộng thêm 4 px mỗi bên) | cao 38–42; thân rộng ≤ 30; vật cầm/vung nằm trong khung |
| Quái, Tinh Anh | 32×48 (Mục 1, 3, 5) | cao ≤ 34 / ≤ 40; thân rộng ≤ 30 |
| Kẻ Gác, Người Giữ Tâm Lưới | 48×64; thân ≤ 52×40 (Mục 5) | Mảnh Gốc **không vẽ trong sheet**: code dựng, 2 px/ô |
| Phiến | 9-slice nguồn 16×16, lề 3 trái-phải-trên, mép trước 2–3 dưới; + 6 stamp (Mục 6.3) | ô thật 38×27 … 64×46 |
| Tường / Bãi Gai | 40×40 / 40×12, neo giữa đáy | Tường vẽ ~30 px, rộng ≤ 36 |
| Nền | 800×360 mỗi lớp (≤ 3: trời, xa, gần); lớp trời có thể ≤ 800×200 | lớp mây trôi: lặp ngang liền mạch (hai quad lệch 800 px) |
| Ô khối | 16×16 (rơi, túi) và 5×5 (trên đất) | 7 cột: 5 chất liệu, Lạ, địch |
| VFX | khung 38×27, 3 giá trị xám cố định (sáng / thân / Mực), code tô màu | ô lớn: đặt giữa, không phóng |
| Icon | 12×12 | 1 icon = 1 cỡ pixel |
| Chân dung | 64×80 (Mục 5.5) | vẽ lại, không phóng sprite |
| Khung UI 9-slice | nguồn 16×16, lề 4 / 4 / 4 / 6 (Mục 7.4) | |

- **Neo = giữa đáy khung**, chân chạm hàng pixel cuối, không lệch giữa các khung. Chừa ≥ 1 px trong suốt mỗi bên; vật vượt thân (kiếm, mũ) nằm trong khung.
- Khung 32/48 chẵn để tâm trúng pixel; ô cao lẻ (27) nên ô snap bội 2.

### 8.4 Bảng màu và biến thể
- **Master** `palette/tessera_master.gpl` + `tessera_master_lut.png` (dải 1×N): **tối đa 64 màu** (Mục 4) cho mọi thứ **đứng trên sân và trong HUD pixel**: đơn vị, Kẻ Gác, phiến + stamp, bệ, Tường/Bãi Gai, Khối, VFX, icon pixel, khung 9-slice. Tập con vùng `tessera_region_<id>.gpl` = màu chung + ≤ 3 màu riêng.
- **Nền tính riêng** (người dùng chốt 2026-10-31 theo kiểm kê: thế giới slice 1 = 66 màu, riêng nền v2 Rừng Sương 38): mỗi vùng một tấm vẽ, **≤ 40 màu mỗi vùng**, không nằm trong master và không được dùng màu tín hiệu (Đỏ Báo Đòn, Ánh Lưới, màu khối của năm anh hùng, bốn màu trạng thái). Luật Mục 6.4 (S, V, bậc phẳng, dither chỉ ở sương) vẫn áp cho nền. Lý do: nền không chia pixel nào với sprite nên gộp chung một con số không mua được gì, còn ép nền xuống 30 màu làm mất các lớp sương.
- **HUD vẽ sắc** (Mục 7.4) dùng bảng UI của Mục 4 (Đá Đêm, Sương, Ngà, chữ, tín hiệu), không đếm vào 64; icon HUD 55 px ≤ 24 màu một sheet.
- **Biến thể quái: xuất sẵn sheet riêng bằng script** (Aseprite/Python) từ bản gốc (người dùng chốt 2026-10-29): đổi 2–3 màu theo bảng, ghép phụ kiện. Chi phí chạy bằng 0, màu chắc chắn trong bảng, ~74 KB mỗi biến thể. Không dùng LUT lúc chạy. Anh hùng không đổi màu.
- **Thêm màu:** chỉ art-director; nêu lý do và tín hiệu nào không thay được; đối chiếu ngân sách và bảng mù màu Mục 4; ghi vào đầu `.gpl` và changelog; quantise lại asset bị ảnh hưởng. Muốn vượt 64 thì hỏi người dùng.

### 8.5 Shader và lớp phủ
- Tối đa 3 ShaderMaterial trong trận (đề xuất): `unit_fx` (Đóng Băng, Cháy, nháy trúng, Rạn, Thức Tỉnh đổi palette) và `floor_fx` (sọc chéo báo đòn theo pixel, ô đích đang niệm 35 → 100 %, ô kéo). VFX tô màu bằng `modulate`, không cần shader.
- Shader chỉ xuất **texel gốc hoặc một màu của bảng**, không nội suy ra màu mới, **trừ lớp phủ trên sàn**: ô đích đang niệm (60 %) và ô trượt khi kéo (50 %) được **trộn trong mờ** dù sinh màu ngoài bảng (người dùng chốt 2026-10-29). Không dùng dither cho chúng (Mục 6.2).
- Tham số theo lần vẽ truyền qua `modulate`/vertex colour để giữ một material, một batch (cần kiểm nghĩa `COLOR` trong canvas shader 4.6).
- Dự phòng không shader: nháy trúng dùng khung "trúng"; Đóng Băng/Cháy dùng lớp phủ vẽ sẵn; sọc báo đòn dùng texture 8×8. Biên dịch shader trước ở màn nạp (hoặc Shader Baker 4.5, cần kiểm cho canvas/Mobile/iOS).
- Hạt: ≤ 128 ô vuông 2×2 cùng lúc (đề xuất); vượt thì giảm số hạt theo loại hiệu ứng, giữ khung cuối.

### 8.6 Animation
- **Số khung theo Mục 5.4** (anh hùng 14, quái 8, Kẻ Gác 9–10). Chạy bằng Node2D tự vẽ (`draw_texture_rect_region` + bảng khung từ JSON), không dùng AnimatedSprite2D/AnimationPlayer: khớp code hiện có, không tốn node theo số đơn vị.

| Clip | Ai | Giữ, lặp |
|---|---|---|
| `idle` | mọi đơn vị | 0,4 s/khung, lặp; Giảm chuyển động: chỉ khung 1 |
| `step` | anh hùng, quái | khớp thời gian hồi bước (0,18–0,6 s/bước, chưa đo) |
| `cast_gesture` | anh hùng | 0,08 + 0,12 s, 1 lần (Mục 3) |
| `windup` | địch | 1 khung, **giữ đến hết báo đòn** |
| `hit` | mọi đơn vị | 0,12 s, 1 lần; nháy trúng bằng shader |
| `knock` | mọi đơn vị | dùng lại `hit` + code đẩy, 0 khung mới |
| `down` | địch | 0,15 s/khung rồi giữ khung cuối |
| `victory` / `defeat` | anh hùng | 0,4 s, lặp / giữ khung cuối |
| `awaken` | anh hùng | 0,12 s/khung |

- Lớp phủ, không vẽ khung: nháy trúng, Đóng Băng, Cháy, Rạn, ô đích đang niệm, hạt ngà ở tay địch khi `windup`, Mảnh Gốc.
- **Thứ tự vẽ** (ba Node2D anh em trong SubViewport): `FloorLayer` (ô, tô báo đòn, ô đích, Bản Khắc) → `UnitLayer` (đơn vị và Tường, hàng sau trước, cùng hàng theo x) → `OverlayLayer` (viền 2 px, ✓/✗, VFX, Khối, thanh độ tươi). Không cần Y-sort, z_index hay CanvasLayer. `FloorLayer` và nền chỉ vẽ lại khi đổi trạng thái; lớp mây vẽ lại ~1 lần/giây.

### 8.7 Import và bộ nhớ
- **Import mọi ảnh art:** Compress = **Lossless** (nén VRAM làm vỡ pixel art), Mipmaps tắt, `fix_alpha_border` bật, Premult Alpha tắt. Lọc đặt NEAREST trên node. Cờ ETC2/ASTC khi export có thể vẫn phải bật (cần kiểm).
- **Trần texture:** atlas ≤ 2048×2048, dùng **1024×1024** (máy yếu, cần kiểm trên máy thật). Mỗi sinh vật một hàng: 12 khung × 32 = 384×48 (Kẻ Gác 576×64).
- Draw call tầng art ≈ 20–30 (đoán, đo ở Debugger → Monitors), còn ≥ 100 cho HUD trong ngân sách 150.

| Mục (RGBA8) | MB |
|---|---|
| Anh hùng 5 × 12 khung | 0,37 |
| Quái và Tinh Anh ~62 | 4,57 |
| Kẻ Gác ~8 | 1,18 |
| Nền 8 vùng × 3 lớp × 800×360 | 27,65 |
| Phiến, VFX, lớp phủ, icon, khung UI | ~1,8 |
| **Tổng art** (~7 % trần 512 MB) | **≈ 35,6** |

- Một trận chỉ nạp vùng hiện tại: ≈ 5 MB. Nếu thiếu bộ nhớ thì thu nhỏ lớp trời trước.

### 8.8 Font
- Font động TTF/OTF, antialiasing xám, hinting bật; **không MSDF, không bitmap**. Tối đa 2 độ đậm, cắt tập con Latin + Vietnamese (~100–200 KB/tệp, cần kiểm). Chữ tĩnh cache (TextLine) nếu đo thấy cần.
- Hướng font: Mục 7.3 (Noto Sans cho chữ thường, font pixel có tiếng Việt cho tiêu đề; đang chờ thử). Hiện code dùng `ThemeDB.fallback_font`; đổi một chỗ khi khởi động (cần kiểm).
- Chuỗi kiểm: "Tiếng Việt ẳ ẵ ặ ế ộ ử ữ ự" + Đ đ, Ơ ơ, Ư ư.

### 8.9 Bảng kiểm nhận asset
| # | Kiểm | Đạt khi |
|---|---|---|
| 1 | Tô đen ở 1× trên sân 5×5 | 5 anh hùng và quái cùng vùng vẫn phân biệt |
| 2 | Nửa trên | mọi dấu nhận dạng ở nửa trên; che nửa dưới vẫn nhận ra |
| 3 | Test 3 hàng | 3 quái cùng cột 3 hàng liền: đếm được 3, nhận ra loài |
| 4 | Màu | anh hùng ≤ 8, quái ≤ 8, Kẻ Gác ≤ 12; mọi màu thuộc bảng chung hoặc tập con vùng |
| 5 | Viền | 1 px #1B1722, kín, chỉ trên đơn vị và Khối; phiến và nền không viền |
| 6 | Pixel | alpha chỉ 0/255; không khử răng cưa; không pixel lẻ loi; một cỡ pixel |
| 7 | Animation | chân không lệch, không vượt khung, viền không rung giữa khung |
| 8 | Màu cấm | không đỏ #E5293B, không gradient mượt |
| 9 | Ghép trong game | chụp trong trận, lưu ở `production/qa/evidence/` |

- Duyệt: art-director đối chiếu bảng với ảnh chụp trong game; người dùng ký cuối. Hỏng #1–3 thì sửa dáng, không thêm chi tiết (P2).

### 8.10 Không được làm
- Không chữ trong sprite, nền, icon, chân dung (✓/✗ là hình nên được phép); nhãn ở HUD 1280×720.
- Xoay góc lẻ; phóng không nguyên (kể cả "thở" 1,05×); đặt sprite ở nửa pixel.
- Gradient mượt, alpha lẻ trên nền và đơn vị; mipmap, lọc tuyến tính; nén VRAM; texture > 2048; mỗi sinh vật một texture riêng lúc chạy.
- Glow, bloom, WorldEnvironment, Light2D, normal map, MSAA, BackBufferCopy/CanvasGroup, SubViewport riêng cho từng đơn vị.
- Rung màn hình bằng khung vẽ; nền động quá một lớp; hạt không làm tròn về art-px.

## 9. Reference Direction

Người dùng duyệt 2026-10-29 (giữ cả 5 nguồn). Mục 1–8 luôn thắng mọi tham khảo. Mega Man Battle Network, Slay the Spire và Hades trong `design/game-brief.md` chỉ là tham khảo cơ chế, không phải tham khảo hình. Mỗi nguồn dưới đây giải một vấn đề riêng: góc nhìn / báo đòn và đơn vị nhỏ / phép vuông / chiều sâu sương / ánh sáng đêm bằng pixel.

| # | Nguồn | Xem ở đâu | Lấy | Không lấy |
|---|---|---|---|---|
| 1 | **One Step From Eden** (Thomas Moon Kang, 2020) | 6 ảnh Steam (store app 960690), xem 2026-10-31 | **Góc nhìn** (Mục 1) + **ngôn ngữ UI**: UI sắc trên thế giới pixel, panel vát góc, kim cương, thanh đốt, chữ sans viền tối, icon có glow | Màu navy, viền ô lam/đỏ theo phe, neon, bão hạt, rung màn hình, đạn bay |
| 2 | **Into the Breach** (Subset Games, 2018) | Một lượt bất kỳ sau khi Vek đã báo đòn, đảo đầu | **Đòn báo vẽ lên ô đất, không vẽ lên quái.** Đơn vị nhỏ nhận ra nhờ dáng + một mảng màu. Panel UI tối, viền mảnh, góc vuông | Phép chiếu isometric, mech khoa học viễn tưởng, khung chữ dày đặc. Màu báo nguy của nó cũng không lấy (cần kiểm), vì Tessera đã quy định đỏ + sọc chéo |
| 3 | **Fez** (Polytron, 2012) | Cảnh nhặt đủ 8 cube bit, các mảnh tụ thành khối vàng | **Sức mạnh là hạt vuông tụ lại, khớp thành khối, rồi tan về hạt vuông**; không tia, không vòng tròn. Mẫu chuyển động cho Khối rơi/tan, hạt ngà ở tay địch, 6 loại VFX | Xoay phối cảnh 3D, pastel tươi phủ cả thế giới, chữ tetromino khắc trên tường (Tessera cấm chữ và rune) |
| 4 | **Caspar David Friedrich**: *The Abbey in the Oakwood* (1809–10, Alte Nationalgalerie Berlin), *Wanderer above the Sea of Fog* (1818, Hamburger Kunsthalle) | Hai bức tranh | **Chân trời thấp, sương xếp lớp theo bậc giá trị**: càng xa càng nhạt, xám, ít tương phản; tàn tích chỉ là bóng phẳng. Áp vào trời và dải xa (Mục 6.4), màn tiêu đề, bản đồ (người đứng quay lưng) | Chuyển màu sơn dầu mượt (Tessera dùng bậc phẳng), thập giá và đám tang, cành vẽ từng nét |
| 5 | **Kingdom Two Crowns** (Raw Fury, 2018) | Cảnh đêm quanh lửa trại ở căn cứ (cần kiểm là cảnh tiêu biểu) | **Một nguồn sáng ấm nhỏ trên nền đêm lạnh, phẳng** (Trại nghỉ, Mục 2); **dải đất tối dần theo bậc** dưới mặt chơi | Mặt nước phản chiếu, tia sáng, bloom hay sương bằng shader, cuộn parallax nhiều lớp (Tessera chỉ cho mây trôi ≤ 1 art-px/s) |

**Ảnh nội bộ (`design/art/reference/`, concept tạm)**
- **Chuẩn gần nhất hiện có: `02-style-test-01`**: lưới nhìn thẳng, phiến có mép trước, khe giữa hai nửa sân, nền tàn tích trong sương, đất tối dưới lưới.
  - Không làm chuẩn cho: cỡ sprite và ô (to gần gấp đôi chuẩn); chân trời (~31 % màn, chuẩn 9–13 %); ô kéo màu lam (chuẩn: màu khối anh hùng); rêu phủ khắp mặt phiến; choàng lam và tóc trắng-vàng của Kiếm sĩ (đã bỏ ở Mục 5.1).
- **`06-blocks-01`**: dấu của 5 chất liệu và chuỗi vỡ thành hạt vuông.
  - Không làm chuẩn cho: glow mềm và viền từng ô của Khối Lạ (chuẩn: một viền bao ngoài, Mục 3); mảnh vỡ xoay góc lẻ; nơ trang trí của Gỗ và dây (ở 5 px chỉ còn khung + 1 dây).
- **`03-key-art-01`**: mood cho màn tiêu đề và bản đồ (lưới vàng lộ dần về đỉnh, người đứng quay lưng). Không làm chuẩn cho trận: phối cảnh, khối vàng lớn phát sáng, glow dày.
- `04-lineup-01`, `05-battle-02…06`, `07-*`, `08-*`, `09-world-map-01`: dùng theo danh sách Lấy/Bỏ ở Mục 5, 6, 7.
- `05-battle-02…06`, `07-forest-01` (2026-10-31): **chuẩn bố cục khung hình** (dải cảnh xa, bệ đá, đáy tối), không phải chuẩn vẽ; không vẽ lại hay img2img từ ảnh.

**Cách dùng:** gom ảnh chụp từng nguồn vào `design/art/reference/external/`, mỗi ảnh kèm một dòng "lấy gì". Chỉ để đối chiếu nguyên lý: không trace, không đưa ảnh ngoài vào prompt AI.
