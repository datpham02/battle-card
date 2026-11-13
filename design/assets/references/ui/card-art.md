# Master Reference — Card art (ảnh minh họa lá bài)

**Khóa ngày:** 2026-11-13, theo quyết định Q1–Q8 của người dùng trong
`design/assets/candidates/ui/card-art/card-art-audit-2026-11-13.md` §8.
**Phạm vi:** mọi file `assets/art/cards/<card id>.png` (registry `card.<id>`).
**Không phải:** khung lá bài (`ui.cards.frames`), icon HUD, VFX.

File này giữ đánh số mục như Master Reference nhân vật: §2 anchor, §4 palette, §5 cấu hình PixelLab,
§7 ràng buộc. Registry là nguồn cho status / acceptance; file này không ghi approval.
Chỗ nào chưa có quyết định thì ghi **undefined**. Không tự đặt thêm luật.

---

## 1. Danh tính

Một lá bài = **một chủ thể đậm, ở giữa, trên nền phẳng tối**, đọc được ở x2 trên card ancient và ở cột hồi chiêu.
Thế giới Tessera: fantasy Tây phương, phép thuật hiện ra thành **khối hình học**.

## 2. Style anchor (Q1)

| Mục | Giá trị |
|---|---|
| File | `assets/art/cards/hoa_xa.png` (Tia lửa / Spark), cùng byte với `design/assets/candidates/ui/card-art/hoa_xa_v2.png` |
| Registry | `card.hoa_xa` — `installed`, `acceptance: accepted` ("approved style", prompts.md:13). Chưa `approved` |
| Lấy từ anchor | **Bố cục và độ chi tiết**: 1 chủ thể, đặt giữa, phần lớn khung là nền phẳng, chi tiết thấp, bóng cơ bản, viền tối 1 màu quanh chủ thể |
| **Không** lấy từ anchor | Màu và nền. Đo 2026-11-13: anchor có 8 màu, **0/8 nằm trong `tessera_master.gpl`**; nền `#1F2835` (81 % pixel), không phải `#2C2A35` |
| Cách dùng | So cạnh nhau bằng mắt khi QA (§9). `create_image_pixflux` không có ô ảnh style; dùng anchor làm `init_image` sẽ kéo theo hình tia lửa, nên **không** dùng |

Hệ quả: chính anchor không qua §4 / §7 hiện tại. Xem lại nó thuộc đợt Q7 (sau Pilot), không sửa bây giờ.

## 3. Canvas

| Mục | Khóa |
|---|---|
| Kích thước | **32×32 px**, PNG RGBA 8 bit |
| Vùng an toàn | **28×28 giữa** (x, y từ 2 đến 29). Card ancient chỉ hiện phần này (`CardFace.ANCIENT_PICTURE_PX = 28`), x2 |
| Lề | 2 px mỗi cạnh chỉ có nền. Không pixel chủ thể nào ở lề |
| Alpha | **chỉ 0 hoặc 255**. File cuối đục toàn bộ (nền phủ kín) |
| Pixel | 1 art-px = 1 pixel, không phóng lẻ, không xoay góc lẻ, không pixel lẻ loi |

## 4. Palette (Q3, Q4, Q5)

| Mục | Khóa |
|---|---|
| Palette | `art_src/palette/tessera_master.gpl`. Đếm 2026-11-13: **63 dòng màu** (chú thích trong file ghi "47 -> 64") |
| Mọi pixel đục | phải nằm trong palette trên. Ngoài palette = không đạt |
| Nền | phẳng **`#2C2A35`**, một màu, phủ toàn bộ pixel không thuộc chủ thể |
| Viền chủ thể | **1 px `#1B1722`** (Mực), kín quanh chủ thể |
| Vết nứt Rạn (Q5) | Mực `#1B1722` + Ngà `#EFE6D2`. Không tím |
| Card nguyền (Q6) | dùng chung nền `#2C2A35` |
| Màu cấm | `#E5293B` (đỏ báo đòn), `#E04CD0` (Khối Lạ), mọi tím/hồng. Cả hai không có trong palette, nên ép palette tự loại chúng |
| Chủ thể sát nền | chủ thể không dùng `#2C2A35` ở mép; viền Mực luôn ngăn chủ thể với nền |

### 4.1 Màu nhấn theo anh hùng (card riêng) — từ RENDER-STANDARDS §4, chỉ phần có trong palette

| Anh hùng | Màu nhấn trong palette | Ngoài palette |
|---|---|---|
| kiem_si | `#8FA3B8`, `#EEF4FA` (bóng `#5F6F82`) | — |
| phap_su | `#3A2A26`, `#F0A030` | — |
| sat_thu | `#BFF3EC` | — |
| tho_san | `#8A5A33`, `#46D6A4` | — |
| giao_si | `#B8BCC8` (+ `#E2E3EA` của thân Giáo sĩ) | `#E4DAFF` lila: **undefined** |

### 4.2 Màu theo họ hiệu ứng

| Họ | Trong palette | Ngoài palette → **undefined** cho tới khi người dùng thêm hoặc chọn thay |
|---|---|---|
| Lửa / Cháy | `#FF7A1F`, `#FFB21F`, `#F0A030`, Ngà | — |
| Thép / kiếm | `#8FA3B8`, `#EEF4FA`, `#5F6F82` | — |
| Đá / Đẩy / Rạn | `#4A4640`, `#5A5650`, `#6A6B62`, `#2C2925`, Mực, Ngà | — |
| Gai / Rêu | `#5E6B55`, `#4A5545`, `#B89A6A`, `#8A7350` | — |
| Băng / Đóng băng | `#A6EEFF` (thêm vào gpl 2026-11-13, người dùng: "Thêm vào gpl, vượt trần"), `#EEF4FA`, `#8FA3B8`, `#5F6F82` | — |
| Giá Lạnh | `#3A5CF0` (thêm cùng lúc), `#EEF4FA`, `#A8B0C8`, `#8FA3B8` | — |
| Lầy | `#4E4C3C`, `#5A4A3A` (màu Đầm Lầy) | `#A8C83A`, `#4E4A2A` |
| Sương | — | `#7D8896` |

### 4.3 Palette con theo từng card (khóa 2026-11-13, người dùng: "Khóa palette con trước")

Lý do (pilot 2026-11-13): ép đủ 63 màu thì pixflux lấy màu tối của vùng hoặc chính màu nền làm viền và thân.
Viền Mực ở mép chủ thể: do_kiem 98 %, hoa_loi 7 %, khien_thep 0 % (19 % mép là `#2C2A35`).

Luật:

1. `color_image_base64` của mỗi lần gen = **palette con** của card đó, không phải cả gpl.
2. Palette con luôn có Mực `#1B1722` và **không có màu tối nào khác ngang Mực** (`#24201E`, `#2C2925`, `#2E3450`, `#3A3744`…), để viền chỉ có thể là Mực.
3. Palette con **không có màu nền `#2C2A35`**. Nền được phủ sau gen (§8), nên chủ thể không thể dùng màu nền.
4. Ngoài Mực: màu chất liệu và màu nhấn của card, lấy từ §4.1 / §4.2, ≤ 3 bậc mỗi chất liệu, **tổng ≤ 8 màu**.
5. Mọi màu phải là một dòng của gpl (`gpl_swatch.py --only` từ chối màu ngoài gpl).
6. Card mà họ của nó chưa có màu trong gpl (băng, giá lạnh, lầy, sương, lila Giáo sĩ) vẫn **undefined**, không gen.

Palette con theo họ (gốc để chọn; mỗi card chọn từ đây, ghi danh sách cụ thể vào prompt):

| Họ | Màu (ngoài Mực) |
|---|---|
| Thép / kiếm / khiên | `#4F5864`, `#5F6F82`, `#8FA3B8`, `#EEF4FA` (+ Ngà `#EFE6D2` cho tia) |
| Lửa / Cháy | `#FF7A1F`, `#FFB21F`, `#EFE6D2` (+ `#F0A030`) |
| Pháp sư (card riêng) | `#3A2A26`, `#F0A030` + họ Lửa |
| Đá / Đẩy / Rạn | `#4A4640`, `#5A5650`, `#6A6B62`, `#EFE6D2` |
| Gai / Rêu | `#4A5545`, `#5E6B55`, `#8A7350`, `#B89A6A` |
| Sát thủ (card riêng) | `#BFF3EC` + họ Thép |
| Thợ săn (card riêng) | `#5C3A22`, `#8A5A33`, `#46D6A4` |
| Giáo sĩ (card riêng) | `#6E7282`, `#B8BCC8`, `#E2E3EA` (lila `#E4DAFF` undefined) |

Palette con của 3 card pilot:

| Card | `--only` |
|---|---|
| do_kiem | `#1B1722,#4F5864,#5F6F82,#8FA3B8,#EEF4FA,#EFE6D2` |
| hoa_loi | `#1B1722,#3A2A26,#4A4640,#F0A030,#FF7A1F,#FFB21F,#EFE6D2` |
| khien_thep | `#1B1722,#4F5864,#5F6F82,#8FA3B8,#EEF4FA` |

`#3A2A26` (than) là màu tối thứ hai duy nhất được phép, chỉ cho tấm ấn của Pháp sư. Nếu viền hoa_loi vẫn không ra Mực thì bỏ nó.

Palette đã chạm trần 64 (chú thích gpl). Thêm màu là việc của art-director với lời đồng ý của người dùng.
Các card băng / giá lạnh / lầy (batch sau) **chưa gen được** theo palette này cho tới khi hàng trên có quyết định.
Bảng prompt §6 của audit có vài hex ngoài palette (`#A6EEFF`, `#A8C83A`, `#4E4A2A`, `#7D8896`, `#E4DAFF`): phải sửa trước khi dùng.

## 5. Cấu hình PixelLab (Q2)

| Tham số `create_image_pixflux` | Giá trị khóa | Lý do |
|---|---|---|
| `width`, `height` | 32, 32 | §3 |
| `no_background` | `true` | tool trả nền trong suốt; nền `#2C2A35` phủ sau bằng thao tác cơ học (§8) để màu nền đúng tuyệt đối |
| `outline` | `"single color black outline"` | như batch1; ép palette đưa màu viền về Mực |
| `shading` | `"basic shading"` | như anchor |
| `detail` | `"low detail"` | như anchor |
| `view`, `direction`, `isometric` | không đặt | icon chính diện |
| `text_guidance_scale` | 8.0 (mặc định) | chưa có quyết định khác |
| `color_image_base64` | output của `design/assets/candidates/ui/card-art/scripts/gpl_swatch.py --only "<palette con §4.3>"` | Q3 + §4.3 |
| `seed` | không đặt; ghi seed / job id trả về vào registry | tái lập |
| Negative description | **tool không có ô này** | mô tả chỉ dùng câu tích cực (bài học PixMiniMax: chữ phủ định vẽ ra đúng thứ bị cấm) |
| Giá | 1 generation / lần gọi | mỗi lần gọi cần "yes" riêng của người dùng |

**Mẫu mô tả** (chỉ câu tích cực):

```
game icon: <SUBJECT>, one bold subject centered with an empty 2 pixel margin, Western fantasy,
angular geometric shapes, <COLOUR WORDS + HEX>, flat pixel colours, up to 3 shades lit from the top-left,
hard pixel edges, 1 pixel dark ink outline, clean readable silhouette
```

## 6. Quy tắc hình (silhouette, vũ khí, hình học)

1. **Một chủ thể** chiếm phần lớn vùng 28×28; không cảnh, không nhân vật cầm đồ.
2. **Phân biệt trong họ:** hai card cùng họ (cùng hiệu ứng hoặc cùng anh hùng) phải khác **dáng**, không chỉ khác màu.
   Phép thử: tô đen chủ thể, đặt cạnh nhau, vẫn gọi đúng tên từng card (RENDER-STANDARDS §6.1).
3. **Vũ khí Tây phương:** kiếm thẳng hai lưỡi, khiên kite / heater / tower, rìu, búa, giáo, dao găm.
   Không kiếm cong một lưỡi kiểu phương Đông, không tua kiếm, không họa tiết wuxia.
4. **Hình học Tessera:** card phép (lửa, băng, sét, ánh sáng, ấn) có ít nhất một phần **vuông hoặc bậc thang**
   trong chủ thể (ngọn lửa bậc, mảnh băng vuông, tia vuông).
5. **Không giống đồ nổi tiếng:** trước khi duyệt, gọi tên vật nổi tiếng gần nhất và ghi điểm khác (luật "no lookalike").
6. Không chữ, số, rune, ký hiệu viết.

## 7. Ràng buộc kỹ thuật

- Không gradient mượt, không glow / bloom, không dither (RENDER-STANDARDS §3).
- Sáng từ trên-trái, ≤ 3 bậc bóng mỗi chất liệu (RENDER-STANDARDS §2).
- Không vẽ tay chi tiết lên ảnh gen. Chỉ thao tác cơ học ở §8.

## 8. Hậu kỳ cho phép (cơ học, công cụ miễn phí)

1. Pixel alpha 0 → `#2C2A35` (đổ nền). Pixel alpha giữa 1–254 → **dừng, báo người dùng** (undefined: chưa có luật làm tròn).
2. Kiểm palette: mọi pixel đục nằm trong gpl. Pixel ngoài palette → **dừng, báo người dùng** (undefined: chưa có quyết định ép nearest sau gen).
3. Kiểm lề 2 px chỉ có `#2C2A35`.
4. **Tô viền Mực** (người dùng cho phép 2026-11-13: "Cho phép tô viền"): trên ảnh gen thô (trước bước 1), mọi pixel
   đục có ít nhất một hàng xóm 4 hướng trong suốt (hoặc nằm ở mép canvas) → `#1B1722`. Chỉ đổi màu, không thêm
   hay bớt pixel, nên khung bao không đổi. Giữ file thô; file đã tô lưu riêng (`<id>_ink.png`).
   Thứ tự: tô viền → bước 1 (đổ nền) → bước 2–3.
Công cụ: `pixelart_workbench` (miễn phí) hoặc script stdlib. Không dùng Pillow.

## 9. QA mỗi ảnh (trước khi đưa người dùng)

1. §3: 32×32, alpha 0/255, đục toàn bộ, lề 2 px sạch.
2. §4: toàn bộ màu trong gpl, nền đúng `#2C2A35`, viền Mực kín, không màu cấm.
3. Sheet x4 cạnh `hoa_xa.png` và các card cùng họ: cùng độ đậm / độ chi tiết; tô đen vẫn phân biệt.
4. §6: tên vật nổi tiếng gần nhất + điểm khác.
5. Ảnh chụp trong game (shop, phần thưởng, tay bài, cột hồi chiêu) ở `production/qa/evidence/card-art/`.
6. Registry: ảnh gen về đăng ký `candidate`. Chỉ người dùng chuyển `accepted` / `approved`, kèm câu trích.

## 10. Undefined

| Mục | Ghi chú |
|---|---|
| Màu băng / giá lạnh / lầy / sương / lila Giáo sĩ | §4.2, ngoài palette |
| Làm tròn alpha nửa trong, ép nearest sau gen | §8 |
| `text_guidance_scale` khác mặc định | chưa thử |
| Có thêm câu chống giống cho từng card | ghi theo từng prompt |

## 11. Lịch sử

| Ngày | Sự kiện |
|---|---|
| 2026-11-13 | Người dùng chốt Q1–Q8; file này được viết. Chưa có lần gen nào theo file này |
| 2026-11-13 | Pilot 3 gen với cả gpl (do_kiem, hoa_loi, khien_thep); hoa_loi và khien_thep trượt kiểm viền §4 |
| 2026-11-13 | Người dùng: "Khóa palette con trước" → §4.3. Không gen lại |
| 2026-11-13 | hoa_loi gen lại 2 lần (v2 palette con, v3 mô tả mới). Người dùng: "Cho phép tô viền" → §8 bước 4 |
| 2026-11-13 | Batch3 (người dùng cho tự gen theo batch): 86 gen, 38 ảnh cài; sau đó thêm `#A6EEFF` `#3A5CF0` vào gpl, 16 gen, 9 ảnh băng/lạnh. Prompt thêm câu "fills only the middle two thirds" từ vòng 3. Báo cáo `design/assets/candidates/ui/card-art/batch3/REPORT-2026-11-13.md` |
