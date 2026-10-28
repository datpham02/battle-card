# HUD Design

> **Status**: In Review
> **Author**: user + ux-designer
> **Last Updated**: 2026-10-28
> **Platform Targets**: Mobile (Android, iOS), landscape 1280x720 reference, touch only (no gamepad, no hover)
> **Template**: HUD Design

---

## HUD Philosophy

**Tối giản, chỉ thông tin quyết định.** Lưới ô và các ô đỏ báo đòn là "sân khấu" của game; HUD đứng sau, không tranh chỗ với chúng. (Quyết định của người dùng, 2026-10-28.)

1. **Không che lưới.** Yếu tố luôn hiện chỉ nằm ngoài hai lưới: dải trên cùng và vùng điều khiển phía dưới.
2. **Chỉ hiện cái đổi quyết định ngay lúc này.** Còn lại là theo ngữ cảnh (hiện khi liên quan) hoặc theo yêu cầu (chạm để xem).
3. **Một thông tin, một chỗ, một dạng.** Máu là thanh. Thời gian là đồng hồ đếm ngược gắn ngay trên thứ nó thuộc về.
4. **Ngón cái trước.**
   - Mọi thứ chạm vào phải đủ lớn cho ngón cái (hiện ≥ 96 px ở 720p).
   - Khi kéo khối, ngón tay che nửa dưới màn hình, nên lưới ở nửa trên, nơi ô đỏ báo đòn trên đất người chơi vẫn đọc được.
5. **Cảnh báo không chỉ bằng màu.** Luôn kèm hình, chữ hoặc dấu.
6. **Luật cân bằng.** Thêm một yếu tố luôn hiện thì phải bỏ hoặc hạ cấp một yếu tố khác.

**Nguồn:** quyết định của người dùng 2026-10-28; nguyên tắc cảm ứng trước (`technical-preferences.md`); các tỉ lệ bố cục trong `src/layout/screen_layout.gd` (lưới chiếm 0,03–0,55 chiều cao).

---

## Information Architecture

### Full Information Inventory

Không có GDD với mục UI Requirements (ở tầng `minimal`, `game-brief.md` thay GDD). Danh sách lập từ `design/game-mechanics.md` và các view đang vẽ HUD. Thuật ngữ theo `design/glossary.md` (chữ trong game vẫn là tên cũ cho tới khi story đổi thuật ngữ chạy).

**M** = Luôn hiện · **C** = Theo ngữ cảnh · **D** = Theo yêu cầu (chạm để xem) · **H** = Ẩn (truyền đạt bằng hình trên ô, không có chữ riêng)

| ID | Thông tin | Nguồn | Loại |
|---|---|---|---|
| I-01 | Máu người chơi (thanh + số) | trận | **M** |
| I-02 | Máu boss (thanh + số + tên) | trận | **M** |
| I-03 | Nút tạm dừng | điều khiển | **M** (nhỏ, ngoài vùng ngón cái) |
| I-04 | Dòng bối cảnh trận (tầng, vùng, chặng, địch, sân) | chuyến leo | **C**: hiện ở màn giới thiệu trận, rồi thu gọn còn tên địch |
| I-05 | Số lá trong bộ | bộ bài | **D** |
| I-06 | Pad 4 hướng | di chuyển | **M** |
| I-07 | Túi khối (3 ô, số ô mỗi khối) | khối | **M** |
| I-08 | Nút Thức Tỉnh + Bản Khắc ("0/21") + trạng thái hồi/sẵn sàng/đang chạy | Thức Tỉnh | **M** |
| I-09 | Thanh Tập trung (đếm ngược, hồi) | Tập trung | **C**: khi đang đặt khối; chưa dùng được thì chỉ có dấu nhỏ |
| I-10 | Bóng khối + báo trúng/trượt (xanh/đỏ) | đặt khối | **C** |
| I-11 | Số ô và sát thương dự kiến | đặt khối | **C** |
| I-12 | Nút Xoay, Tung phép, Hủy | đặt khối | **C** |
| I-13 | Menu 4 lá phép (đếm 3 giây, lá khóa "cần N ô", hồi chiêu) | lá phép | **C** |
| I-14 | Gợi ý ghép khối thứ hai | ghép | **C** |
| I-15 | Biểu tượng Hình Cộng Hưởng của sân | ghép | **C**: khi đang cầm khối |
| I-16 | Ô đỏ báo đòn trên đất người chơi | boss | **M** (khi có đòn) |
| I-17 | Đếm ngược + tên đòn + số ô ("BOSS 7 ô · 1,6 s") | boss | **M** (khi có đòn) |
| I-18 | Hàng khối boss đang giữ | boss | **M** |
| I-19 | NGẮT! (đòn bị phá) | phá phép | **C** |
| I-20 | ĐÒN GIẢ! (boss tự hủy) | boss | **C** |
| I-21 | Số sát thương, TRÚNG/TRƯỢT | trận | **C** |
| I-22 | Số hồi máu | trận | **C** |
| I-23 | Từ khóa trên đơn vị: Cháy ×n, Rạn ×n, Giá Lạnh ×n, Đóng Băng (đếm giây) | từ khóa | **C**: gắn trên đơn vị |
| I-24 | Ô Tường, Bãi Gai, ô đang cháy | vùng, từ khóa | **H** |
| I-25 | Địa hình vùng: lầy, cát lấp, mạch dung nham, ô nứt/rơi, mũi tên gió, mây che | vùng | **H**, kèm nhãn ngắn khi sắp xảy ra (SẮP PHUN, SẮP RƠI…) |
| I-26 | Đặc tính boss có đếm: Ngòi cháy, Phản xạ, Tái sinh/hồi sinh | boss | **C**: gắn trên boss |
| I-27 | Biểu ngữ pha ("PHA 2") | boss cuối | **C** |
| I-28 | "Báo trúng bị mây che" | Không Đảo | **C** |
| I-29 | Vàng | chuyến leo | **M** ở màn bản đồ; **H** trong trận |
| I-30 | Tầng X/5, chặng | chuyến leo | **M** ở màn bản đồ; **C** trong trận |
| I-31 | Bảo vật đang có | bảo vật | **D** (dải bảo vật); **C** khi một bảo vật kích hoạt (nháy) |
| I-32 | Giao Kèo hiện tại | Giao Kèo | **D** |
| I-33 | May mắn, lượt bỏ lá, lượt quên hình | chuyến leo | **D** |
| I-34 | Dòng nhắc Khối Lạ lần đầu | Khối Lạ | **C** (một lần) |
| I-35 | Thông báo Bộ khối bị thay | bộ khối | **C** (một lần) |
| I-36 | Biểu ngữ Thức Tỉnh đang chạy | Thức Tỉnh | **C** |
| I-37 | Bộ đếm "học" của boss (né / ngắt / giả) | gỡ lỗi | **H** (chỉ dùng khi dev) |

### Categorization

Người dùng duyệt cả 8 nhóm theo đề xuất (2026-10-28).

| Loại | Số mục | Mục |
|---|---|---|
| **M: Luôn hiện** (trong trận) | **9** | I-01, I-02, I-03, I-06, I-07, I-08, I-16*, I-17*, I-18 (*chỉ khi boss có đòn) |
| **M** (màn bản đồ) | 2 | I-29, I-30 |
| **C: Theo ngữ cảnh** | 20 | I-04, I-09–I-15, I-19–I-23, I-26–I-28, I-30 (trong trận), I-34–I-36 |
| **D: Theo yêu cầu** | 4 | I-05, I-31–I-33 |
| **H: Ẩn** | 4 | I-24, I-25, I-29 (trong trận), I-37 |

**Kiểm tra xung đột với triết lý (mục A):** chỉ 9 yếu tố luôn hiện trong trận, hợp với "tối giản". Hiện trạng HUD trong build có khoảng 60 yếu tố đang vẽ; mục D sẽ đối chiếu từng yếu tố với bảng này để biết cái nào phải hạ xuống C, D hay H.

---

## Layout Zones

Màn ngang 1280×720 (tham chiếu), tỉ lệ lấy từ `src/layout/screen_layout.gd`. Người dùng chọn (2026-10-28): sắp xếp **trái đi – phải đặt – giữa tung phép**; lưới giữ **55 % chiều cao** (phương án A).

```
+------------------------------------------------------------------------+
| Z1  [Máu bạn ▓▓▓▓]     ( ⏸ )  [Hình CH]          [▓▓▓▓ Máu boss]       |
|                                                    Z1b [khối boss]      |
|   +-------- lưới bạn ----------+-------- lưới địch --------+  Z2       |
|   |                            |                           |  (lưới +   |
|   |                            |                           |  ô đỏ +    |
|   +----------------------------+---------------------------+  trạng thái)|
|  Z3                    Z4                          Z5                  |
|  [  ↑  ]       [ THỨC TỈNH · Bản Khắc 0/21 ]    [khối][khối][khối]      |
|  [← ↓ →]       (khi đặt: số ô · Xoay · Tung phép · Hủy)                |
+------------------------------------------------------------------------+
```

| Vùng | Vị trí | Chứa | Ghi chú |
|---|---|---|---|
| **Z1** Dải trên | 0–11 % cao | Hai thanh máu (I-01, I-02), tạm dừng (I-03), biểu tượng Hình Cộng Hưởng (I-15, khi cầm khối) | Ngoài vùng ngón cái, không che lưới |
| **Z1b** | dưới thanh máu boss | Hàng khối boss đang giữ (I-18) | Giữ nguyên chỗ hiện tại |
| **Z2** Lưới | 3–55 % cao | Hai lưới; ô đỏ báo đòn và đếm ngược (I-16, I-17); từ khóa gắn trên đơn vị (I-23); địa hình (I-24, I-25); số sát thương và hồi máu (I-21, I-22); biểu ngữ và thông báo (I-19, I-20, I-26–I-28) | Mọi thông báo chuyển động nằm trên lớp này |
| **Z3** Trái dưới | góc trái | Pad 4 hướng (I-06); khi đặt khối chuyển thành nút Xoay lớn (I-12) | Ngón cái trái: **đi** |
| **Z4** Dải giữa | giữa dưới | Thức Tỉnh + Bản Khắc (I-08); khi đặt khối: số ô, sát thương (I-11), Tung phép, Hủy (I-12), Tập trung (I-09); khi chọn lá: menu 4 lá (I-13) | Ngón nào rảnh thì bấm |
| **Z5** Phải dưới | góc phải | Túi khối, 3 ô (I-07) | Ngón cái phải: **kéo khối** lên lưới địch |

**Lý do:** ngón trái đi, ngón phải đặt khối, ở giữa là trạng thái và nút xác nhận. Vùng điều khiển **đổi nội dung theo ngữ cảnh** (pad thành Xoay, Thức Tỉnh thành Tung phép) nên không thêm yếu tố mới, đúng triết lý mục A.

**Phương án đã bỏ:** túi khối ở giữa, Thức Tỉnh bên phải. Ngón kéo khối sẽ che đường giữa hai lưới, là nơi cần nhìn nhất.

### Kích thước ô và hệ quả cho art

Ước tính từ hằng số bố cục (chưa đo trên máy thật):

| Sân | Ô (rộng × cao, px) |
|---|---|
| 3×3 (6 cột hai bên) | 129 × 92 |
| 5×5 (10 cột) | **77 × 55** |
| 7×2 (14 cột, Không Đảo) | 86 × 61 (giới hạn bởi bề ngang) |

- **Quyết định: art được vẽ để đọc được ở ô 55 px cao** (sân 5×5). Sân nhỏ chỉ thấy nhân vật to hơn.
- **Phương án dự phòng B** (làm sau buổi chơi thử nếu nhân vật khó đọc): lưới 3–66 % cao, vùng điều khiển còn 34 %, nút pad còn khoảng 77 px (≈ 8 mm trên điện thoại 6″, dưới mức khuyến nghị 9 mm của Android). Ô 5×5 thành khoảng 93 × 67 (+22 %). Chỉ cần đổi hằng số `ARENA_BOTTOM_RATIO` và các tỉ lệ `DPAD_BUTTON_RATIO`, `SLOT_HEIGHT_RATIO`, nhưng phải thử trên máy thật.

---

## HUD Element Specifications

Mỗi yếu tố ghi hình dạng, cách cập nhật, khi nào hiện, hiệu ứng. ID tham chiếu bảng ở mục Information Architecture (I-xx); E-xx là ID yếu tố. Mọi trạng thái đều truyền đạt bằng hình hoặc chữ, không chỉ bằng màu. Người dùng duyệt 2026-10-28.

### Dải trên (Z1, Z1b)

| ID | Yếu tố (loại) | Hình dạng | Cập nhật | Hiện khi | Hiệu ứng |
|---|---|---|---|---|---|
| E-01 | Máu người chơi (M) | Thanh ngang + "200/200" + tên nhân vật | Liên tục, mượt 0,2 s | Luôn | Mất máu: đoạn "vết" nhạt co dần 0,4 s. Dưới 25 %: viền nhấp nháy 1 Hz + biểu tượng "!" |
| E-02 | Máu boss (M) | Như E-01, kèm vạch nửa máu nếu boss có đổi pha | Liên tục | Luôn | Như E-01; đổi pha thì vạch nháy 0,5 s |
| E-03 | Tạm dừng (M) | Nút tròn 65 px, góc giữa trên | Sự kiện | Luôn | Nhấn: dừng ngay, không cần xác nhận |
| E-04 | Bối cảnh trận (C) | Dải một dòng: "Tầng 1/5 · Rừng Sương · Chặng 1/3" + tên địch | Một lần | 2 giây đầu trận | Trượt vào, mờ dần. Xem lại trong màn Tạm dừng |
| E-05 | Số lá trong bộ (D) | Chữ trong màn Tạm dừng | Sự kiện | Chỉ khi mở Tạm dừng | — |
| E-15 | Hình Cộng Hưởng (C) | Hình thu nhỏ 5–7 ô cạnh nút tạm dừng | Sự kiện | Khi trong túi có ≥ 1 khối | Sáng viền khi hai khối đang ghép khớp hình |
| E-18 | Khối boss đang giữ (M) | 3 ô nhỏ dưới thanh máu boss, mỗi ô là hình thu nhỏ (Khối Lạ có dấu sao). **Trống:** khung ô mờ, không chữ | Sự kiện | Luôn | Ô bị dùng xóa mờ 0,2 s |

### Điều khiển (Z3, Z4, Z5)

| ID | Yếu tố | Hình dạng | Cập nhật | Hiện khi | Hiệu ứng |
|---|---|---|---|---|---|
| E-06 | Pad 4 hướng (M) | Chữ thập 4 nút 97 px | Liên tục | Luôn; khóa khi đang đặt | Nút lún khi bấm. Viền sáng dần theo hồi bước (0,18–0,6 s) |
| E-07 | Túi khối (M) | 3 ô, mỗi ô hình thu nhỏ + "5 ô" | Sự kiện | Luôn | Nhặt: khối bay vào ô 0,2 s. Đầy: nhãn "ĐẦY". Khối chọn: viền vàng. Khối Lạ: dấu sao. Khối hỏng: xám + dấu X |
| E-08 | Thức Tỉnh (M) | Nút lớn: tên + thanh Bản Khắc "0/21" | Liên tục | Luôn | **Đang nạp:** mờ, thanh chạy. **Đang hồi:** mờ + "Hồi 12 s". **Sẵn sàng:** sáng + chữ "SẴN SÀNG", nhịp đập 1 Hz. **Đang chạy:** thanh thời gian + "ĐANG DÙNG" |

### Đặt khối và tung phép (chỉ khi đang đặt)

| ID | Yếu tố | Hình dạng | Cập nhật | Hiệu ứng |
|---|---|---|---|---|
| E-09 | Tập trung (C) | Thanh + "TẬP TRUNG 3,2 s" trên nút Tung phép. Chưa dùng được: tag "Tập trung còn 5 s" | Liên tục | Hết thì trận chậm lại 0,2× |
| E-10 | Bóng khối + báo trúng (C) | Ô xanh/đỏ trên đất địch kèm nhãn "Sẽ trúng ✓" / "Sẽ trượt ✗" | Theo ngón tay | Hít vào ô trong 0,05 s. Khối nâng lên 56 px trên ngón tay |
| E-11 | Số ô và sát thương (C) | Chữ lớn "7 ô" + "Sát thương 42" ở dải giữa | Theo xoay hoặc ghép | — |
| E-12 | Xoay, Tung phép, Hủy (C) | Xoay: nút lớn thay pad. Tung phép: nút xanh lá ở giữa. Hủy: nút nhỏ | Sự kiện | Xoay: khối quay 90° trong 0,1 s |
| E-13 | Menu 4 lá (C) | 4 thẻ ngang: tên, số ô tối thiểu, hồi chiêu, sát thương/ô; thanh đếm 3 s phía trên | Liên tục | Lá chưa đủ ô: mờ + "cần N ô". Hết giờ: tự chọn nhát chém cơ bản |
| E-14 | Gợi ý ghép (C) | Một dòng nhỏ: "Kéo thêm khối để ghép · +1,5 s" | Mỗi lần mở menu | Ẩn sau khi người chơi đã ghép ít nhất một lần (cờ trong tiến trình). **Đề xuất mới.** |

### Đọc đòn boss (trên lưới)

| ID | Yếu tố | Hình dạng | Cập nhật | Hiệu ứng |
|---|---|---|---|---|
| E-16 | Ô đỏ báo đòn (M khi có đòn) | Ô đỏ có **sọc chéo** + viền đậm | Theo đòn | Cường độ tăng khi gần hết giờ |
| E-17 | Đếm ngược + tên đòn (M khi có đòn) | Nhãn gần ô đỏ: "BOSS 7 ô · Kiếm khí · 1,6 s" + thanh co dần. Nhãn không che ô người chơi đang đứng | Liên tục | — |
| E-19 | NGẮT! (C) | Biểu ngữ giữa lưới 0,6 s + dòng nhỏ ("boss bị hủy đòn" hoặc "đòn của bạn bị hủy") | Sự kiện | Lắc nhẹ 0,15 s |
| E-20 | ĐÒN GIẢ! (C) | Biểu ngữ nhỏ phía trên boss 0,8 s | Sự kiện | — |

### Con số và trạng thái (gắn vào đơn vị)

| ID | Yếu tố | Hình dạng | Cập nhật | Hiệu ứng |
|---|---|---|---|---|
| E-21 | Sát thương, TRÚNG/TRƯỢT (C) | Số nổi lên từ đơn vị, viền trắng, cỡ chữ theo lượng sát thương | Sự kiện | Bay lên, mờ dần trong 0,8 s |
| E-22 | Số hồi máu (C) | "+8" có dấu cộng (không chỉ màu xanh) | Sự kiện | Như E-21 |
| E-23 | Từ khóa trên đơn vị (C) | Tối đa 3 chip dưới ô đơn vị: biểu tượng **khác hình nhau** (ngọn lửa, vết nứt, bông tuyết, khối băng) + số tầng/giây | Liên tục | Chip mới bật ra 0,2 s |

### Địa hình vùng và đặc tính boss

| ID | Yếu tố | Hình dạng | Cập nhật | Hiệu ứng |
|---|---|---|---|---|
| E-25 | Cảnh báo địa hình (H + nhãn C) | Ô có **sọc/viền nét đứt** kèm nhãn ngắn: SẮP PHUN, SẮP RƠI, GIÓ ĐẨY, BÃO CÁT, SẮP CHÁY | Theo sự kiện | Nhãn hiện 0,8–1 s trước khi xảy ra |
| E-26 | Đặc tính boss có đếm (C) | Chip gắn ô boss: "Ngòi 3,2 s", "Phản ứng 2/3", "HỒI SINH 1,2 s" | Liên tục | — |
| E-27 | Biểu ngữ pha (C) | Dải ngang trên lưới 1,5 s: "PHA 2 · Tâm Lưới bừng sáng" | Sự kiện | Giáng vào, rung nhẹ |
| E-28 | Báo trúng bị mây che (C) | Nhãn E-10 thay bằng biểu tượng mây + "Báo trúng bị mây che" | Theo đặc tính | — |
| E-36 | Thức Tỉnh đang chạy (C) | Dải trên lưới: "TRẢM · 2,3 s" | Liên tục | — |

### Chuyến leo và thông báo một lần

| ID | Yếu tố | Hình dạng | Cập nhật | Hiện khi |
|---|---|---|---|---|
| E-29/30 | Vàng, tầng, chặng, máu (M ở bản đồ) | Dải trên màn bản đồ: ❤ 170/200 · 🪙 44 · Tầng 2/5 | Sự kiện | Chỉ màn bản đồ, không có trong trận |
| E-31 | Bảo vật (D) | Dải biểu tượng bảo vật nhỏ; chạm mở chi tiết. **Trống:** chữ "Chưa có bảo vật" | Sự kiện | Chạm; biểu tượng nháy 0,5 s khi kích hoạt |
| E-32/33 | Giao Kèo, may mắn, lượt bỏ lá, lượt quên hình (D) | Chữ trong màn Tạm dừng và màn bản đồ | Sự kiện | Theo yêu cầu |
| E-34/35 | Nhắc một lần: Khối Lạ, đổi Bộ khối (C) | Dòng nhắc 4 s dưới thanh máu | Sự kiện | Một lần, lưu cờ "đã thấy" trong tiến trình |

**Số lượng:** trong trận chỉ 9 yếu tố luôn hiện (E-01, E-02, E-03, E-06, E-07, E-08, E-16, E-17, E-18). Mọi hiệu ứng nhấp nháy hoặc rung có phương án giảm chuyển động (mục Accessibility).

**Ghi chú:** các biểu tượng trạng thái, vạch nửa máu, viền hồi bước của pad, sọc chéo ô đỏ, nhãn ✓/✗ và chip từ khóa là **mục tiêu thiết kế**; hiện trạng build có thể chưa có hết. Danh sách khác biệt sẽ lập khi nghiệm thu.

---

## HUD States by Gameplay Context

Game không có thế giới thăm dò hay đối thoại. Ánh xạ: **thăm dò** = màn bản đồ chuyến leo; **đối thoại / cắt cảnh** = màn Tha/Giết và màn kết thúc; **chiến đấu** = các trạng thái trong trận; **tạm dừng** = màn Tạm dừng. Người dùng duyệt 2026-10-28.

| Ngữ cảnh | HUD hiện | Ẩn |
|---|---|---|
| **Bản đồ chuyến leo** (thăm dò) | Dải chuyến leo (E-29/30), dải bảo vật (E-31), các nút bản đồ | Toàn bộ HUD trận |
| **Giới thiệu trận** (2 s) | Hai thanh máu, dải bối cảnh (E-04), điều khiển hiện nhưng mờ | Mọi thông báo |
| **Chiến đấu: nhàn rỗi / di chuyển** | 9 yếu tố luôn hiện (E-01, 02, 03, 06, 07, 08, 16*, 17*, 18) + thông báo theo ngữ cảnh khi xảy ra | Nút Xoay, Tung phép, Hủy, Tập trung, menu lá |
| **Chiến đấu: đang đặt khối** | Pad thành nút Xoay (E-12); dải giữa có số ô + sát thương (E-11), Tung phép, Hủy, Tập trung (E-09); bóng khối + báo trúng (E-10); hình Cộng Hưởng (E-15) | Pad bị khóa; Thức Tỉnh vẫn hiện nhưng mờ |
| **Chiến đấu: chọn lá** | Menu 4 lá (E-13) chiếm dải giữa, thanh đếm 3 s, gợi ý ghép (E-14) | Số ô và Tung phép |
| **Chiến đấu: đòn đang niệm** | Ô đỏ của boss (E-16, E-17) và đòn bạn đang niệm trên đất địch | Tung phép |
| **Chiến đấu: Thức Tỉnh đang chạy** | E-08 "ĐANG DÙNG", dải thời gian (E-36) | — |
| **Chiến đấu: pha 2 của boss** | Biểu ngữ pha (E-27) 1,5 s, rồi trở lại như bình thường | — |
| **Tha/Giết** (cắt cảnh) | Chỉ màn Tha/Giết toàn màn hình | Toàn bộ HUD trận |
| **Kết thúc** (cắt cảnh) | Các trang kết thúc toàn màn hình | Toàn bộ HUD |
| **Tạm dừng** | Phủ mờ: bối cảnh (E-04), số lá trong bộ (E-05), Giao Kèo, may mắn, bảo vật (E-31–E-33); nút Tiếp tục, Thoát (đã lưu) | Điều khiển trận |

(*) chỉ khi boss có đòn.

### Biến thể của HUD

| Biến thể | Điều kiện | Thay đổi |
|---|---|---|
| Mặc định | Chơi thường | — |
| Máu thấp | Máu người chơi < 25 % | E-01 viền nhấp nháy 1 Hz + "!" (giảm chuyển động: biểu tượng tĩnh, không nhấp nháy) |
| Túi trống | Túi khối rỗng | Ô hiện dấu "+"; không có nhãn |
| Túi đầy | 3/3 khối | Nhãn "ĐẦY" cạnh túi; khối không nhặt được |
| Tập trung chưa dùng được | Đang hồi | Tag nhỏ "Tập trung còn 5 s" |
| Thức Tỉnh chưa sẵn sàng | Bản Khắc chưa đầy hoặc đang hồi | E-08 mờ + tiến trình hoặc "Hồi N s" |
| Boss đang niệm | Boss tung đòn | Ô đỏ có sọc + nhãn đếm ngược |
| Cảnh báo địa hình | Vùng có địa hình | Nhãn ngắn 0,8–1 s trước khi xảy ra |

---

## Information Hierarchy

Dùng khi HUD quá đông: bỏ từ dưới lên. Cột cuối nói cái gì mang thông tin đó khi yếu tố bị ẩn. Người dùng duyệt 2026-10-28.

| Hạng | Yếu tố | Lý do | Khi bị ẩn thì |
|---|---|---|---|
| **MUST KEEP** | E-01, E-02 (máu) | Sống hay chết | Không có thay thế |
| | E-16, E-17 (ô đỏ + đếm ngược) | Né đòn là cách phòng thủ duy nhất | Không có thay thế |
| | E-06, E-07 (pad, túi khối) | Điều khiển | — |
| | E-10, E-11, E-12 (khi đang đặt) | Quyết định đặt khối | — |
| **SHOULD KEEP** | E-08 (Thức Tỉnh) | Chiều sâu chiến thuật | Hiệu ứng hình trên lưới |
| | E-18 (khối boss đang giữ) | Đoán đòn kế tiếp của boss | Cảnh báo ô đỏ khi tung |
| | E-23 (từ khóa trên đơn vị) | Biết có đòn đang tích | Hiệu ứng trên ô |
| | E-25 (cảnh báo địa hình) | Tránh sát thương môi trường | Hình vẽ trên ô |
| **CAN HIDE** | E-21, E-22 (số nổi) | Phản hồi, không quyết định | Thanh máu cho thấy thay đổi |
| | E-04, E-15, E-34, E-35 | Chỉ giúp lần đầu | Màn Tạm dừng, thông báo một lần |
| **ALWAYS HIDE** (trong trận) | E-05, E-31–E-33 | Xem được ở Tạm dừng | Màn Tạm dừng |
| | E-37 (bộ đếm học của boss) | Chỉ dùng khi dev | — |

---

## Visual Budget

Đo theo **số yếu tố** và **diện tích**. Diện tích tính từ kích thước nút hiện có (pad 97 px, túi khối 113×158 px, nút Xoay 288×288 px). Người dùng duyệt 2026-10-28.

| Tiêu chí | Giới hạn | Hiện trạng ước tính |
|---|---|---|
| Số yếu tố đồng thời: nhàn rỗi | **9** (đúng bộ "luôn hiện") | 9 |
| Số yếu tố đồng thời: đang đặt khối hoặc chọn lá | **≤ 16** | khoảng 15 |
| Số yếu tố đồng thời, kể cả thông báo | **≤ 18** | — |
| Diện tích điều khiển và thanh máu: nhàn rỗi | **≤ 20 %** diện tích màn hình | khoảng 14 % |
| Diện tích điều khiển và thanh máu: đang đặt khối | **≤ 30 %** | khoảng 25 % |
| Diện tích phủ lên lưới bởi biểu ngữ và nhãn (không tính ô đỏ báo đòn và chip trên đơn vị) | **≤ 15 %** diện tích lưới | — |
| Số nổi cùng lúc | **≤ 6** | — |

**Thứ tự bỏ khi vượt ngân sách** (bỏ yếu tố đầu bảng trước): E-34/35 → E-04 → E-14 → E-15 → E-21/22 (thu nhỏ rồi ẩn) → E-36 → E-28.

---

## Feedback & Notification Systems

Mức ưu tiên: **P1** an toàn tính mạng, **P2** sự kiện chiến đấu quan trọng, **P3** trạng thái kéo dài, **P4** phản hồi, **P5** nhắc một lần. Người dùng duyệt 2026-10-28.

| Loại | Kích hoạt | Vị trí | Thời lượng | Tối đa cùng lúc | Ưu tiên | Hàng đợi |
|---|---|---|---|---|---|---|
| Cảnh báo đòn boss (E-16, E-17) | Boss bắt đầu niệm | Đất người chơi | Bằng thời gian niệm | 2 (đòn hiện tại + đòn ghép kế) | **P1** | **Không bao giờ xếp hàng hay bị che.** Cả hai hiện cùng lúc |
| NGẮT! (E-19) | Đòn bị phá | Giữa lưới | 0,6 s | 1 | P2 | Thay thế, không xếp hàng. Phá liên tiếp thì chạy lại từ đầu |
| ĐÒN GIẢ! (E-20) | Boss tự hủy đòn | Trên ô boss | 0,8 s | 1 | P2 | Thay thế |
| Biểu ngữ pha (E-27) | Boss đổi pha | Dải trên lưới | 1,5 s | 1 | P2 | Hiện song song với NGẮT! (hai vị trí khác nhau) |
| Cảnh báo địa hình (E-25) | 0,8–1 s trước sự kiện | Trên ô bị ảnh hưởng | 0,8–1 s | 4 | P2 | Hơn 4 thì giữ 4 nhãn gần người chơi nhất; ô vẫn có sọc |
| Thức Tỉnh sẵn sàng (E-08) | Bản Khắc đầy và hết hồi | Nút Thức Tỉnh | Trạng thái kéo dài | 1 | P3 | Là trạng thái, không phải thông báo; kèm nháy 0,5 s và âm thanh lúc chuyển |
| Thức Tỉnh đang chạy (E-36) | Kích hoạt | Dải trên lưới | Hết thời gian kỹ năng | 1 | P3 | — |
| Số sát thương và hồi máu (E-21, E-22) | Trúng đòn, hồi máu | Trên đơn vị | 0,8 s | 6 | P4 | Số cũ nhất gộp vào số mới khi vượt 6 |
| Bảo vật kích hoạt (E-31) | Bảo vật phát tác | Biểu tượng bảo vật | 0,5 s | 3 | P4 | Cùng một bảo vật trong 1 s chỉ nháy một lần |
| Nhắc một lần (E-14, E-34, E-35) | Sự kiện lần đầu | Dưới thanh máu | 4 s | 1 | P5 | **Xếp hàng tối đa 2.** Chỉ hiện khi 1,5 s qua không có P1 hay P2 và người chơi không đang kéo. Sau 10 s chưa hiện được thì bỏ; cờ "đã thấy" chỉ ghi khi đã thật sự hiện, nên lần sau vẫn nhắc |

**Quy tắc chung:**
- **Không bao giờ che ô đỏ báo đòn (P1).** Mọi thông báo khác phải tránh vùng đất người chơi đang đứng và vùng ô đỏ.
- **Giữ trong khi chiến đấu:** chỉ P5 bị giữ lại chờ khoảnh khắc yên. P1–P4 hiện ngay.
- **Âm thanh:** mỗi thông báo P1 và P2 có âm thanh riêng; âm thanh không thay thế hình (hình luôn có).

---

## Platform Adaptation

Màn ngang cố định, **chỉ cảm ứng** (không hover, không gamepad). Chuột và phím chỉ là công cụ test trên desktop. Người dùng chấp nhận tạm thời 2026-10-28 (có thể sửa nhỏ sau).

| Chủ đề | Quy tắc |
|---|---|
| **Màn tham chiếu** | 1280×720 (16:9). Lưới và vùng điều khiển tính theo chiều cao màn hình |
| **Màn rộng hơn 16:9** (ví dụ 20:9, 1600×720) | Lưới giữ nguyên cỡ. Phần rộng thêm thành lề. Pad bám mép trái **vùng an toàn**, túi khối bám mép phải, dải giữa ở giữa; thanh máu kéo dài theo vùng an toàn. Ngón cái luôn chạm tới các mép |
| **Màn hẹp hơn** (ví dụ 4:3, 960×720) | Lưới 10 cột bị giới hạn bề ngang, ô nhỏ hơn. Pad (97 px) + dải giữa + túi khối (3 × 113 px) vừa khít khoảng 940 px, **cần thử trên máy tính bảng thật** |
| **Vùng an toàn** | Dùng vùng an toàn của hệ điều hành làm lề tối thiểu (tai thỏ, góc bo tròn). Lề dưới = lớn hơn của 2 % (hiện tại) và vạch vuốt hệ thống (iOS: thanh Home). Không đặt nút chạm trong vùng vuốt cử chỉ của Android ở mép |
| **Kích thước chạm** | Điều khiển chính ≥ **96 px** (khoảng 10 mm). Điều khiển phụ (tạm dừng) ≥ 65 px. Khoảng cách giữa hai nút chạm kề nhau ≥ 6 px (pad được phép dùng đúng 6 px vì là một cụm) |
| **Đa chạm** | Ngón trái giữ pad, ngón phải kéo khối **cùng lúc** phải hoạt động. Không dùng thao tác chỉ có bấm giữ hoặc vuốt chính xác |
| **Ngón tay che màn hình** | Khối nâng lên 56 px trên ngón tay khi kéo. Lưới nằm ở nửa trên; ô đỏ báo đòn trên đất người chơi không bị ngón phải che |
| **Rung (haptic)** | Tùy chọn, mặc định bật: rung ngắn khi boss bắt đầu đòn và khi bạn bị trúng. Không rung liên tục |
| **Android và iOS** | Cùng bố cục. Khác biệt chỉ ở vùng an toàn và API rung |

---

## Accessibility

**Chưa có cấp trợ năng nào được cam kết cho dự án** (chưa có `design/accessibility-requirements.md`). Tạm dùng **WCAG-AA làm nền**; xem Open Questions. Người dùng chấp nhận tạm thời 2026-10-28 (có thể sửa nhỏ sau).

| Hạng mục | Yêu cầu |
|---|---|
| **Không chỉ bằng màu** | Mọi trạng thái đều có hình hoặc chữ: báo trúng "✓ Sẽ trúng" / "✗ Sẽ trượt"; ô đỏ báo đòn có sọc chéo; chip từ khóa có biểu tượng khác hình nhau; máu thấp có "!"; Tập trung có chữ đếm |
| **Tương phản** | Chữ ≥ 4,5 : 1 so với nền (chữ lớn ≥ 3 : 1). Nhãn đếm ngược và sát thương có viền để đọc được trên mọi địa hình |
| **Cỡ chữ** | Chữ người chơi phải đọc **trong lúc chiến đấu** (đếm ngược, số sát thương, nhãn cảnh báo): ≥ **18 px** ở 720p; số liệu chính (đếm ngược, số ô, sát thương): ≥ **24 px**. Nhắc một lần: ≥ 18 px |
| **Giảm chuyển động** | Một tùy chọn. Tắt: nhấp nháy máu thấp, nhịp đập Thức Tỉnh sẵn sàng, rung biểu ngữ, lắc NGẮT!. Thay bằng dấu tĩnh (viền, nhãn). Không bao giờ có chớp sáng toàn màn hình; mọi nhấp nháy ≤ 1 Hz |
| **Thuận tay trái** | Một tùy chọn đảo vị trí pad và túi khối (Z3 ↔ Z5) |
| **Thao tác thay thế cho kéo** | Đặt khối bằng **chạm khối rồi chạm ô đích** cũng được, không bắt buộc kéo |
| **Áp lực thời gian** | Game thời gian thực. Có sẵn chậm 0,2× khi đặt khối và Tập trung dừng hẳn 4 giây. Chưa có tùy chọn "hỗ trợ" nào kéo dài thêm (Open Questions) |
| **Âm thanh** | Mọi âm cảnh báo đều có hình tương ứng. Rung là kênh thứ ba tùy chọn |
| **Đọc màn hình** | Không áp dụng trong trận thời gian thực. Các màn menu (bản đồ, cửa hàng, tạm dừng) nên dùng AccessKit của Godot 4.5+ (Open Questions) |

---

## Tuning Knobs

Game **chưa có màn Cài đặt** (màn chính chỉ có nút VI/EN), nên các tùy chọn này cần một story riêng (Open Questions). Người dùng duyệt 2026-10-28.

| Tùy chọn | Giá trị | Mặc định | Ảnh hưởng |
|---|---|---|---|
| Giảm chuyển động | Tắt / Bật | Theo hệ điều hành nếu đọc được, không thì Tắt | Tắt nhấp nháy, nhịp đập, rung màn hình, lắc biểu ngữ; thay bằng dấu tĩnh |
| Thuận tay trái | Tắt / Bật | Tắt | Đổi chỗ pad ↔ túi khối |
| Rung | Tắt / Bật | Bật | Rung khi boss bắt đầu đòn và khi bị trúng |
| Rung màn hình | 0 / 50 / 100 % | 100 % | Độ rung khi NGẮT! và đổi pha |
| Cỡ chữ HUD | 100 / 115 / 130 % | 100 % | Chữ ở dải trên, dải giữa và các dòng nhắc. Nhãn trên lưới tự thu nhỏ cho vừa ô |
| Cỡ điều khiển | 90 / 100 / 110 % | 100 % | Pad và túi khối (110 % vẫn vừa vùng dưới 45 %) |
| Số nổi | Tất cả / Chỉ đòn lớn / Tắt | Tất cả | Số sát thương và hồi máu |
| Bảng màu báo trúng | Xanh lá – đỏ / Xanh dương – cam | Xanh lá – đỏ | Bóng khối và ô báo đòn (vẫn có ✓/✗ và sọc) |
| Nhắc hướng dẫn | Đầy đủ / Ẩn, kèm nút "Hiện lại nhắc" | Đầy đủ | Gợi ý ghép và các dòng nhắc một lần |

---

## Acceptance Criteria

QA kiểm được mà không cần đọc tài liệu khác. Người dùng duyệt 2026-10-28.

- [ ] **Vùng an toàn:** ở 1280×720, 1600×720 (20:9) và 960×720 (4:3), không nút chạm nào nằm trong vùng an toàn của hệ điều hành. Pad bám mép trái, túi khối bám mép phải, không yếu tố nào bị cắt.
- [ ] **Chiến đấu nhàn rỗi** chỉ hiện đúng 9 yếu tố: hai thanh máu, tạm dừng, pad, túi khối, nút Thức Tỉnh, hàng khối boss, ô đỏ và đếm ngược khi có đòn. Không có nút Xoay, Tung phép, Hủy, thanh Tập trung hay menu lá.
- [ ] **Đang đặt khối:**
  - Pad đổi thành nút Xoay; dải giữa hiện số ô, sát thương, Tung phép, Hủy.
  - Trong lúc ngón phải kéo khối từ túi, ô đỏ báo đòn trên đất người chơi vẫn nhìn thấy.
- [ ] **Không chỉ bằng màu:** trên ảnh chụp đen trắng vẫn phân biệt được báo trúng/trượt, ô đỏ báo đòn (sọc), chip từ khóa và máu thấp.
- [ ] **Ngân sách:** đo trên ảnh chụp. Điều khiển và thanh máu ≤ 20 % diện tích màn hình khi nhàn rỗi, ≤ 30 % khi đặt khối. Biểu ngữ và nhãn phủ ≤ 15 % diện tích lưới.
- [ ] **Hàng đợi thông báo:** khi NGẮT!, đổi pha và một dòng nhắc một lần xảy ra cùng lúc:
  - NGẮT! và biểu ngữ pha hiện ngay, ở hai chỗ khác nhau.
  - Dòng nhắc chờ 1,5 s yên rồi mới hiện.
  - Không thông báo nào che ô đỏ báo đòn.
- [ ] **Kích thước chạm:** điều khiển chính ≥ 96 px, nút tạm dừng ≥ 65 px ở 720p.
- [ ] **Chữ:** chữ đọc trong chiến đấu ≥ 18 px, số liệu chính ≥ 24 px ở 720p. Tương phản ≥ 4,5 : 1 (lấy mẫu).
- [ ] **Giảm chuyển động bật:** không có nhấp nháy, nhịp đập hay rung; thay bằng dấu tĩnh.
- [ ] **Thuận tay trái bật:** pad bên phải, túi khối bên trái; kéo đặt khối vẫn hoạt động.
- [ ] **Đa chạm:** giữ pad bằng ngón trái trong khi kéo khối bằng ngón phải hoạt động bình thường.
- [ ] **Art ở ô nhỏ:** trên ảnh chụp sân 5×5 (ô khoảng 55 px cao), nhận ra được 5 nhân vật và boss qua dáng hình.

---

## Open Questions

1. **Cấp trợ năng chưa cam kết.** Cần tạo `design/accessibility-requirements.md` (`/ux-design accessibility`). Đề xuất nền WCAG-AA.
2. **Chưa có bản đồ hành trình người chơi.** `design/player-journey.md` viết tay theo mẫu `.claude/docs/templates/player-journey.md`.
3. **Chưa có art bible.** Màu, phông chữ, biểu tượng từ khóa và chất liệu khối của HUD chờ `/art-bible`.
4. **Chưa có thư viện mẫu tương tác.** Spec này dùng 3 mẫu mới, nên thêm vào `design/ux/interaction-patterns.md`:
   - vùng đổi nội dung theo ngữ cảnh,
   - chạm khối rồi chạm ô,
   - hàng đợi nhắc một lần.
5. **Thử trên máy thật:**
   - ô 55 px có đọc được không (quyết định có chuyển sang phương án lưới 66 % hay không),
   - nút 97 px,
   - vùng an toàn,
   - máy tính bảng 4:3.
6. **Chưa có màn Cài đặt** để chứa các tùy chọn ở mục Tuning Knobs. Cần story mới.
7. **Tùy chọn hỗ trợ áp lực thời gian** (Tập trung dài hơn, trận chậm hơn) ảnh hưởng cân bằng, cần quyết định thiết kế.
8. **AccessKit cho các màn menu** (Godot 4.5+): có làm không, khi nào.
9. **Danh sách khác biệt giữa build hiện tại và spec** (vạch nửa máu, sọc ô đỏ, ✓/✗, chip từ khóa, viền hồi bước…): lập khi làm story HUD.
10. **Chữ trong HUD vẫn dùng tên cũ** (mảnh, trận đồ, tuyệt kỹ…). Đổi theo `design/glossary.md` trong story đổi thuật ngữ.
11. **TD-038** (dòng nhắc bị lưới đè): sửa trong story HUD theo quy tắc mục Feedback & Notification Systems.
