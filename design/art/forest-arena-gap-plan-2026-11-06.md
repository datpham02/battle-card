# Rừng Sương: thu hẹp khoảng cách giữa game và concept — phân tích và đề xuất asset

**Ngày:** 2026-11-06 · **Trạng thái:** phân tích + nguyên mẫu bằng code (0 gen). **Chưa gọi PixelLab** cho phần dưới đây.
**So sánh:** ảnh 1 (sân Chữ nhật trong game), ảnh 2 (sân Chữ thập trong game), ảnh 3 (concept: Mage vs Dire Wolf, Rectangle).
Nguyên mẫu: `production/qa/evidence/forest-integration/15-proto-rect.png`, `15-proto-cross.png`.

---

## 1. Khác biệt và nguyên nhân

| Khía cạnh | Concept (ảnh 3) | Game hiện tại | Nguyên nhân | Sửa bằng |
|---|---|---|---|---|
| Chiều sâu, lớp cảnh | Cây lớn hai lề, tàn tích sau mép trên sân, đường lát đá phía trước | Nền v2 có cây và vòm hai lề, nửa dưới tối | Gần đạt; thiếu **lớp tiền cảnh** (dương xỉ, cỏ, đá) che chân sân | Asset (tiền cảnh) |
| Màu mặt sân | Đá xám ấm, rêu trong mạch, nhuộm hai nửa rất nhẹ | Nhuộm xanh/tím còn rõ | **Render:** nhuộm nhân hai lần (FloorLayer + shader) | Code ✔ (đã giảm) |
| Đường lưới | Mạch đá mảnh có rêu | Mạch tối dày | **Render:** màu deck `#3A3B37` gần đen | Code ✔ (deck `#454B3F`) |
| Vết nứt lặp | Ít, ngẫu nhiên | Một số phiến nứt to lặp lại | **Render:** trọng số chọn phiến đều nhau | Code ✔ (ưu tiên phiến trơn) |
| Viền mép (coping) | Hàng đá mũ **dày** (~2× hiện tại), nhô ra, rêu rủ xuống | Viền 12 px cắt từ tường | **Thiếu asset** | Asset (coping) |
| Kiến trúc tường | Trụ chịu lực, vòm lõm giữa các trụ, chân móng | Một dải gạch lặp | **Thiếu asset** + **thiếu luật đặt module** | Code ✔ (luật đặt trụ) + asset (trụ, vòm) |
| Rễ, rêu | Rễ lớn ôm hai góc sân, rêu rủ | Rễ nhỏ nằm sẵn trong dải tường lặp | **Thiếu asset** (rễ góc phải tách khỏi dải lặp) | Asset (rễ góc) |
| Bóng tiếp xúc | Bóng dưới coping, chân tường tối | Có bóng chân tường, thiếu bóng dưới mép | **Render** | Code ✔ (bóng dưới coping) |
| Ánh sáng, thứ bậc sáng | Mặt sân sáng nhất, tường tối hơn, nền tối nhất | Đúng thứ bậc nhưng mặt sân hơi tối | Render | Code ✔ (nhuộm nhẹ làm sáng mặt sân) |
| Mật độ pixel | Concept vẽ minh họa chi tiết cao | Pixel art 800×360 | Cố ý: **giữ pixel art**, không chép độ chi tiết minh họa | — |
| Chữ nhật vs Chữ thập | (chỉ có Chữ nhật) | Tường đặt theo từng mép trước thật | Code đã xử lý từng đoạn mép; trụ đặt theo từng đoạn | Code ✔ |
| Huy hiệu khắc ở giữa tường | Có | Không | **Không làm**: luật art chỉ cho phép họa tiết "ô vuông lồng ô vuông", không biểu tượng | — |

**Tóm lại:** màu, mạch, bóng và luật đặt module là việc của render/code (đã làm trong nguyên mẫu). Coping dày, trụ, vòm, rễ góc và tiền cảnh là **asset còn thiếu**, thứ duy nhất cần PixelLab.

## 2. Đã làm trong nguyên mẫu (0 gen)

- Nhuộm hai nửa nhẹ hơn: Rừng Sương `#E2E8EE` / `#D4CAD8`; shader `(0.93, 1, 0.96)` / `(0.99, 0.93, 1)`. Vẫn phân biệt phe.
- Mạch giữa phiến: deck `#454B3F` (xám rêu) thay màu gần đen; đường chia hai phe `#2C2D29`.
- Trọng số phiến: phiến trơn (0, 13) ×5, phiến nứt to ×2, phiến rêu nhiều ×1.
- Bóng tiếp xúc dưới coping: 2 dải mực 55 % / 30 % ở đầu tường.
- **Luật đặt trụ** (`SupportLayer.pillar_xs`): mỗi đoạn tường có trụ ở hai đầu và cách đều ~120 px; trụ đặt theo **từng đoạn mép trước thật** (Chữ thập có trụ dưới cả mép trên lẫn mép dưới). Trụ trong nguyên mẫu là ô thay thế (lát cắt tường sáng hơn + viền mực) cho tới khi có sprite.

## 3. Luật module cho mọi dạng sân

- **Tường:** dưới mỗi mép trước của ô có thật (`SlabPainter.platform_front_rects` → `SupportLayer.wall_spans`), không kéo qua ô khuyết.
- **Coping:** chạy theo đúng các mép trước đó, dày hơn mép hiện tại, nối tường bên dưới.
- **Trụ:** hai đầu mỗi đoạn + cách đều; đoạn ngắn hơn 2 trụ thì chỉ trụ đầu.
- **Vòm lõm:** chỉ đặt giữa hai trụ khi khoảng trống ≥ chiều rộng vòm; không thì để tường trơn.
- **Rễ góc:** ở hai đầu ngoài cùng của mép trước dài nhất (và mép trên Chữ thập), lật ngang cho đầu phải.
- **Tiền cảnh:** cụm dương xỉ/cỏ rải thưa dọc chân tường, cách đều có lệch ngẫu nhiên theo seed, không đè lên nút điều khiển.
- Tất cả nằm ngoài vùng ô; lớp sàn vẽ đè lên trên.

## 4. Asset cần PixelLab (chờ duyệt)

Ảnh tham chiếu phong cách chung: `env_support_forest_wall.png` (tường đã duyệt). Bảng màu khóa:
`#1B1722 #262521 #3A3B37 #4C4D47 #5A5B54 #6A6B62 #7A7B70 #36412F #4C5A40 #5E6B55`.

| # | Asset | Cỡ | Công cụ / tham số | Giá |
|---|---|---|---|---|
| 1 | Coping dày (dải lặp ngang) | 256×24 | `create_image_pro_flash`, có nền, max 24 màu, style = cắt 96×24 từ tường | 9 |
| 2 | Trụ chịu lực | 28×56 | `create_image_pro_flash`, nền trong suốt, max 24 màu, style = cắt 28×44 từ tường | 5 |
| 3 | Vòm lõm (chèn giữa trụ) | 72×40 | `create_image_pro_flash`, có nền, max 24 màu, style = cắt 72×40 từ tường | 5 |
| 4 | Rễ ôm góc | 64×64 | `create_image_pro_flash`, nền trong suốt, max 24 màu (lật ngang cho góc phải) | 5 |
| 5 | Cụm dương xỉ/cỏ tiền cảnh | 96×32 | `create_image_pro_flash`, nền trong suốt, max 16 màu | 5 |
| | **Tổng** | | | **29** |

**Prompt** (chỉ dùng câu khẳng định):

1. *Coping:* "Front view of a row of thick weathered coping stones capping an ancient stone platform, seen straight on, filling the whole image. Long rectangular capstones edge to edge with thin dark joints, a rounded worn top edge catching soft light from the upper left, a darker overhanging underside along the bottom, small moss clumps along the top and a few thin moss strands draping over the front. Muted grey-green ruin stone, crisp pixel art, clean pixel clusters. Left and right edges continue naturally into the same row, even repeating texture across the whole width."
2. *Trụ:* "Front view of a single square stone support pillar of an ancient ruined platform, seen straight on, standing upright and filling the image height. A plain capital block on top, stacked weathered stone blocks, a wider base block at the bottom, worn edges, a little moss at the joints. Soft light from the upper left, muted grey-green ruin stone, crisp pixel art, clean pixel clusters, transparent background."
3. *Vòm lõm:* "Front view of a low recessed stone arch built into an ancient retaining wall, seen straight on, filling the image. A round arch of wedge-shaped stones over a deep dark shadowed opening, surrounding weathered wall blocks, a little moss on the keystone. Soft light from the upper left, muted grey-green ruin stone, crisp pixel art, clean pixel clusters."
4. *Rễ góc:* "Thick old tree roots wrapping over the corner of a stone platform and climbing down its wall, seen from the front, two or three gnarled roots with thin root tendrils and moss, dark brown-grey bark, soft light from the upper left, muted dark-fantasy palette, crisp pixel art, clean pixel clusters, transparent background."
5. *Tiền cảnh:* "A low clump of dark forest ferns and short grass growing at the foot of an old stone wall, seen from the front, a few broken stone fragments among the leaves, muted dark green and grey-green, soft light from the upper left, crisp pixel art, clean pixel clusters, transparent background."

**Danh sách kiểm tra khi nhận:** nhìn thẳng mặt, không phối cảnh; cùng họ đá với tường; độ sáng: coping < mặt phiến, trụ ≈ tường, tiền cảnh tối hơn tường; không biểu tượng/chữ/rune/glow/đỏ; rễ và cỏ không che mặt ô.

**Đề xuất thứ tự:** gen 1 + 2 trước (14 gen), ghép xem; ổn mới gen 3–5 (15 gen).

**Kết quả 2026-11-06 (người dùng duyệt "Gen 1+2, 14 gen"):**
- #2 Trụ (5 gen): **đạt**, dùng làm `assets/art/env/forest/env_support_forest_pillar.png`; `SupportLayer` đặt trụ theo `pillar_xs` (hai đầu mỗi đoạn tường + cách đều 120 px), đầu trụ ngay dưới viền.
- #1 Coping (9 gen): **không đạt** (các viên nhòe thành một dải, vệt rễ chữ Y lặp). Không dùng; giữ `design/assets/candidates/forest-arena-kit/coping-01-raw-256x24.png` làm hồ sơ. Người dùng chọn **giữ viền hiện tại** (hàng đá cắt từ tường đã duyệt, 0 gen).
- Còn chờ duyệt: #3 vòm lõm, #4 rễ góc, #5 dương xỉ tiền cảnh (15 gen).

## 5. Vùng hiển thị ("The Buried Sands" dưới art rừng)

Đây là **cờ dev** `--art-region=forest` của cảnh demo chụp ảnh: canvas bị ép vẽ Rừng Sương còn trận đấu bên trong lấy ngẫu nhiên. Trong game thật, `regions.json` ánh xạ chương `desert` → vùng `sands`; vùng này chưa có `region.json` nên vẽ **hai dải màu dự phòng** (`#B8A888` / `#6E6248`) và phiến đá phẳng, **không dùng art Rừng Sương**. Không có ánh xạ sai.


## 6. Nền v3 — thay nền thật (2026-11-06)

- **Vì sao v1/v2 chưa đạt:** mặt cỏ của nền nằm ở giữa chiều cao sân (art y ≈ 120–165), nửa dưới là khoảng tối hoặc sân lát phiến; chân tường (art y ≈ 280–290) chạm vào khoảng tối nên sân như treo lơ lửng.
- **Gen:** `create_image_pro` 792×336, 25 gen, prompt của người dùng (bãi trống rêu, tàn tích chỉ ở hai bên, giữa để trống cho sân), tham chiếu = concept người dùng + tường đã duyệt. Kết quả: `design/assets/candidates/forest-background/bg-02-raw-792x336.png`.
- **Thay trong game:** `assets/art/env/forest/bg_forest_far_v3.png` (đặt x 4, lặp cột mép, 24 hàng đáy màu mực), `region.json` → `backdrop.far = bg_forest_far_v3.png`; dải sương gần vẫn tắt. Nền cũ (`bg_forest_far.png`, `_v2`) giữ trong repo, không còn nạp.
- **Sửa kèm:** đường chia hai phe chỉ vẽ trên các deck cắt qua nó (`SlabPainter.divider_segments`), không còn vạch thẳng xuyên khoảng trống giữa hai cánh trên của sân Chữ thập.
- **Trước/sau:** `production/qa/evidence/forest-integration/23-before-after-rect.png`, `23-before-after-cross.png` (trên: nền gốc · giữa: v2 · dưới: v3).
- **Còn khác concept:** đường chân trời của v3 thấp hơn mép sau của sân, nên ngay sau mép trên của sân là sương và cây xa thay vì tàn tích; concept có vòm/trụ đứng sát mép sau. Hàng đá mũ dày và huy hiệu khắc giữa tường không làm (đã ghi ở trên).
