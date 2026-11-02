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

**Phạm vi:** spec này chỉ gồm HUD trong trận và dải chuyến leo. Các màn title, chọn nhân vật, thưởng, cửa hàng, sự kiện, trại nghỉ, Tha/Giết, kết thúc, thành tựu, mở khóa và cài đặt cần spec UX riêng.

Không có GDD với mục UI Requirements (ở tầng `minimal`, `game-brief.md` thay GDD). Danh sách lập từ `design/game-mechanics.md` và các view đang vẽ HUD. Thuật ngữ theo `design/glossary.md` (chữ trong game vẫn là tên cũ cho tới khi story đổi thuật ngữ chạy).

**M** = Luôn hiện · **C** = Theo ngữ cảnh · **D** = Theo yêu cầu (chạm để xem) · **H** = Ẩn (truyền đạt bằng hình trên ô, không có chữ riêng)

| ID | Thông tin | Nguồn | Loại |
|---|---|---|---|
| I-01 | Máu người chơi (thanh + số) | trận | **M** |
| I-02 | Máu boss (thanh + số + tên) | trận | **M** |
| I-03 | Nút tạm dừng | điều khiển | **M** (nhỏ, ngoài vùng ngón cái) |
| I-04 | Dòng bối cảnh trận (tầng, vùng, chặng, địch, sân) | chuyến leo | **C**: hiện ở màn giới thiệu trận, rồi thu gọn còn tên địch |
| I-05 | Số lá trong bộ | bộ bài | **D** |
| I-06 | Joystick nổi 4 hướng (chế độ pad đã bỏ 2026-11-01) | di chuyển | **M** |
| I-07 | Túi khối (3 ô, số ô mỗi khối) | khối | **M** |
| I-08 | Nút Thức Tỉnh + Bản Khắc ("0/21") + trạng thái hồi/sẵn sàng/đang chạy | Thức Tỉnh | **M** |
| I-09 | Thanh Tập trung (đếm ngược, hồi) | Tập trung | **C**: khi đang đặt khối; chưa dùng được thì chỉ có dấu nhỏ |
| I-10 | Bóng khối + báo trúng/trượt (xanh/đỏ) | đặt khối | **C** |
| I-11 | Số ô và sát thương dự kiến | đặt khối | **C** |
| I-12 | Nút Xoay, Tung phép, Hủy | đặt khối | **C** |
| I-13 | Menu 4 lá phép (đếm 3 giây, lá khóa "cần N ô", hồi chiêu), mở khi bấm Tung phép (2026-11-01) | lá phép | **C** |
| I-14 | Gợi ý ghép khối thứ hai | ghép | **C** |
| I-15 | Biểu tượng Hình Cộng Hưởng của sân | ghép | **C**: khi đang cầm khối |
| I-16 | Ô đỏ báo đòn trên đất người chơi | boss | **M** (khi có đòn) |
| I-17 | Ô báo đòn đậm dần (người dùng chốt 2026-10-31: **không nhãn đếm ngược**; độ đậm của ô đỏ là đồng hồ, đầy = đòn rơi) | boss | **M** (khi có đòn) |
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
| I-38 | Độ tươi của khối trên sân (hết 8 s thì tan) | khối rơi | **M**, gắn trên khối (chỉ khi có khối) |
| I-39 | Kết quả trận: thắng (+máu hồi, đối thủ kế, đếm tự tiếp tục) / thua (thống kê) | chuyến leo | **C** (ngữ cảnh riêng) |
| I-40 | Hẹn giờ khối hỏng trong túi | đặc tính boss | **C**, gắn trên ô túi |
| I-41 | "Bản Khắc hoàn thành" | Bản Khắc | **C** |
| I-42 | Dòng mô tả trận (một câu) | trận | **C**, trong dải giới thiệu (cùng I-04) |

### Categorization

Người dùng duyệt cả 8 nhóm theo đề xuất (2026-10-28).

| Loại | Số mục | Mục |
|---|---|---|
| **M: Luôn hiện** (trong trận) | **9** + 1 | I-01, I-02, I-03, I-06, I-07, I-08, I-16*, I-17*, I-18 (*chỉ khi boss có đòn); I-38 gắn trên khối (không tính vào 9, xem cách đếm ở Visual Budget) |
| **M** (màn bản đồ) | 2 | I-29, I-30 |
| **C: Theo ngữ cảnh** | 24 | I-04, I-09–I-15, I-19–I-23, I-26–I-28, I-30 (trong trận), I-34–I-36, I-39–I-42 |
| **D: Theo yêu cầu** | 4 | I-05, I-31–I-33 |
| **H: Ẩn** | 4 | I-24, I-25, I-29 (trong trận), I-37 |

**Kiểm tra xung đột với triết lý (mục A):** chỉ 9 yếu tố luôn hiện trong trận, hợp với "tối giản". Bổ sung sau `/ux-review` (2026-10-28, người dùng duyệt): I-38 (M, gắn trên khối), I-39 (C, ngữ cảnh riêng), I-40–I-42 (C). Hiện trạng HUD trong build có khoảng 60 yếu tố đang vẽ; mục D sẽ đối chiếu từng yếu tố với bảng này để biết cái nào phải hạ xuống C, D hay H.

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

### Bố cục điều khiển v3 (2026-11-02, thay các dòng Z1, Z3, Z4, Z5 bên dưới)

Nguồn: `design/quick-specs/bo-cuc-dieu-khien-v3-2026-11-02.md` (người dùng chốt 2026-11-02). Số đo ở 720p, nhân theo cao màn hình / 720 (`ScreenLayout.controls_scale`). Mọi nút có hình nhìn thấy đúng cỡ spec và một **vùng chạm vô hình** riêng (`ScreenLayout.row_hit_rects`): cao 96 px tới mép dưới màn hình, rộng tới 96 px quanh tâm nút; hai nút cạnh nhau chia đôi khe giữa (Xoay chỉ còn 74 px rộng, vẫn ≥ 64 px của spec); nút ngoài cùng kéo tới mép màn hình. Không vùng chạm nào chồng nhau hay chồng lên sân.

```
+------------------------------------------------------------------------+
| [bảo vật ...]          (dòng tầng: chỉ bản phát triển)  [khối boss] ⬡28 [⏸]|
| [Trói][Chậm][Rạn][Giáp]  <- buff/debuff, quạt thời gian                |
| [hồi]                                                                  |
| [hồi]  +-------- lưới bạn ---------+-------- lưới địch --------+       |
|        +---------------------------+---------------------------+       |
|  (joystick)               ◇ Thức Tỉnh                                  |
| [Tung phép][Xoay][Hủy]    0/12              [ổ][ổ][ổ]                  |
+------------------------------------------------------------------------+
```

| Vùng | Nội dung v3 |
|---|---|
| Trên trái | Hàng bảo vật (12 px từ mép, cao 28 px); dưới nó hàng buff/debuff của nhân vật (E-43); dưới nữa cột hồi chiêu (E-42). Không còn chip "Hình Cộng Hưởng" và "Bộ: N lá" |
| Trên phải | Nút tạm dừng 48 px sát góc (vùng chạm là ô 96 px ở góc); bên trái là vàng (icon lục giác + số), bên trái nữa là khối boss đang giữ |
| Dòng tầng | "Tầng 1/5 · …" chỉ vẽ ở bản phát triển (`OS.is_debug_build()`; ảnh chụp có thể tắt bằng `--no-dev-title`) |
| Dưới trái | Lúc di chuyển: joystick. Lúc đặt khối: hàng `[Tung phép 100][Xoay 64][Hủy 72]` cao 64 px, cách nhau 10 px, sát góc, cùng đáy với túi khối. Tung phép chỉ hiện khi đang đặt hoặc trong cửa sổ đặt; Xoay chỉ khi đang cầm khối. Lúc chọn lá: Hủy nằm chỗ Tung phép |
| Dưới giữa | Thức Tỉnh (hình thoi) + số Bản Khắc; ẩn khi đặt khối và khi chọn lá |
| Dưới phải | Túi khối gọn: 3 ổ đá vát góc 64×64 thẳng hàng (túi 4 ô: 4 ổ cùng hàng), cách nhau 10 px, sát góc phải, cùng đáy |
| Thời gian | Ngòi vàng cháy theo chiều kim đồng hồ từ 12 giờ quanh viền nút Tung phép (cửa sổ đặt 3 s và Tập trung; nếu cả hai chạy thì hiện cái hết trước, vì đó là hạn tác động kế tiếp) và quanh khung bao 4 lá (3 s chọn lá). Đầu ngòi là hình thoi sáng; phần đã cháy là rãnh tối. Bỏ mọi thanh rời |
| Chữ hiệu ứng | Không khung: màu tự nổi (vàng cho có lợi, xanh lá "sẽ trúng", đỏ nhạt "sẽ trượt"), viền mực dày 6 px, bóng 2 px, to ×1,2, nảy 0,18 s khi hiện (tắt khi bật Giảm chuyển động) |
| Cộng hưởng | Tự tính như cũ. Khi các khối đặt khớp hình: bóng khối chuyển vàng + chữ "Cộng hưởng ×1,5 · N ô · −X". Hình cần ghép hiện một lần ở băng giới thiệu đầu trận, cạnh tên sân |
| Hình dạng | Không hình tròn trong HUD trừ joystick: vàng là lục giác, dấu gỡ khối và điểm dưới ngón tay là hình thoi, mũi tên Xoay gãy góc |
| Sân | Cỡ ô né cả vùng chạm túi khối và cột hồi chiêu (`ScreenLayout.hud_obstacle_rects`): sân 7 cột mỗi nửa thu nhỏ một chút thay vì nằm dưới cột hồi chiêu |

Ảnh: `production/qa/evidence/controls-v3/`.

Các dòng dưới đây là bố cục v2, giữ để tra lịch sử; chỗ nào khác bảng v3 ở trên thì v3 thắng.

| Vùng | Vị trí | Chứa | Ghi chú |
|---|---|---|---|
| **Z1** Dải trên | ≈ 3–20 % cao (sửa 2026-10-31: 8–20 % là dải cảnh xa của nền, art bible 6.4; trước đó 3–14 %). **Trong trận không có panel máu** (sửa lần 3, 2026-10-31, người dùng: "khi chiến đấu thì hiện số máu dưới chân còn ẩn cái thanh máu ở trên", "chỉ cần con số không, ko cần border"): số máu hiện tại của mỗi đơn vị là chữ trơn có viền mực ngay dưới chân (người chơi chữ sáng, boss Ngà), chip trạng thái dưới số; hàng trên cùng (dưới dòng tầng, trên dải cảnh xa) theo OSFE (người dùng 2026-10-31: "debuff hay buff thì hiện ở góc trái, tiền góc phải"): bảo vật (buff; bảo vật âm viền đỏ = debuff, nháy khi kích hoạt) bắt đầu từ góc trên trái, vàng của lượt chơi ở góc trên phải, hàng khối boss đang giữ ngay bên trái số vàng; tiến độ Bản Khắc ở dưới ô kim cương Thức Tỉnh. `combat.json hud.corner_panels: true` bật lại hai panel góc. Phương án panel góc (sửa lần 2): **Hai panel máu áp sát hai góc trên, 0–7,2 %** (sửa lần 2, 2026-10-31, người dùng: "đưa thanh máu về góc như này giống osfe": panel 260×52 px ở 720p (thanh máu ngắn kiểu OSFE, người dùng: "ko cần dài quá"), tối đa 28 % bề ngang, vát góc trong phía dưới; người chơi trên trái: tên + "máu/tối đa", thanh máu, thanh Bản Khắc; boss trên phải: ô khối đang giữ + tên, thanh máu, "máu/tối đa". Cao 52 px để đầu Kiếm sĩ v3 ở hàng sau sân 5x5 không bị che. Dòng tầng/trận nằm giữa hai panel; "Bộ: N lá" bên phải nút tạm dừng. Trước đó: 3–11 %, panel 430×60 của Story 046); 8–20 % để trống cho cảnh xa và đầu đơn vị hàng sau cùng (đơn vị đứng cao kiểu OSFE, `design/art/art-bible.md` mục 1 và 3; người dùng chốt 2026-10-28) | Hai thanh máu (I-01, I-02), tạm dừng (I-03), biểu tượng Hình Cộng Hưởng (I-15, khi cầm khối) | Ngoài vùng ngón cái, không che lưới |
| **Z1b** | trong panel boss, hàng trên, bên trái tên (sửa 2026-10-31) | Hàng khối boss đang giữ (I-18), ô 22×17 px | Thu gọn cho vừa hàng |
| **Z2** Lưới | ≈ 20–64 % cao cho hàng rộng (sửa 2026-10-31: sân bắt đầu ở 20 % để nền có dải cảnh xa; trước đó 15 %); hàng hẹp nằm gọn trong khe ngón cái (x 25–76 %) được xuống tới 76 % (bố cục v2, `design/quick-specs/control-layout-v2.md`, người dùng chốt 2026-10-31; trước đó 14–55 %) | Hai lưới; ô đỏ báo đòn và đếm ngược (I-16, I-17); từ khóa gắn trên đơn vị (I-23); địa hình (I-24, I-25); số sát thương và hồi máu (I-21, I-22); biểu ngữ và thông báo (I-19, I-20, I-26–I-28) | Mọi thông báo chuyển động nằm trên lớp này |
| **Z3** Trái dưới | vùng x 0–25 %, y 64–100 % | Joystick nổi 4 hướng (I-06, đế 160 px, núm 88 px, xuất hiện tại chỗ chạm); là điều khiển di chuyển **duy nhất**: chế độ pad 3x3 (`controls.movement = pad`) đã bỏ theo quyết định người dùng 2026-11-01, giá trị `pad` cũ trong `settings.json` bị bỏ qua. Khi đặt khối chuyển thành nút Xoay lớn (I-12) | Ngón cái trái: **đi**. Bố cục v2 2026-10-31, trước đó pad 4 hướng cố định; 2026-11-01 bỏ pad |
| **Z4** Dải giữa | giữa dưới | Thức Tỉnh + Bản Khắc (I-08); khi đặt khối: số ô, sát thương (I-11), Tung phép, Hủy (I-12), Tập trung (I-09); khi chọn lá: lớp xám nhìn xuyên được + menu 4 lá **ở giữa màn hình** (I-13, 2026-11-01) | Ngón nào rảnh thì bấm |
| **Z5** Phải dưới | góc phải, 3 ô 130x93 px xếp vòng cung quanh điểm xoay ngón cái (góc 100/128/156°, bán kính 2× cao ô) | Túi khối, 3 ô (I-07) | Ngón cái phải: **kéo khối** lên lưới địch. Bố cục v2 2026-10-31, trước đó 3 ô 158x113 thẳng hàng |

**Lý do:** ngón trái đi, ngón phải đặt khối, ở giữa là trạng thái và nút xác nhận. Vùng điều khiển **đổi nội dung theo ngữ cảnh** (pad thành Xoay, Thức Tỉnh thành Tung phép) nên không thêm yếu tố mới, đúng triết lý mục A.

### Lề vùng an toàn (Android, iOS)

| Lề | Giá trị |
|---|---|
| Trái, phải | lớn hơn của 3 % chiều rộng (38 px ở 1280) và vùng an toàn hệ điều hành (tai thỏ, góc bo, vùng vuốt cử chỉ ở mép của Android) |
| Trên | lớn hơn của 3 % chiều cao (22 px ở 720) và vùng an toàn |
| Dưới | lớn hơn của 2 % chiều cao (14 px ở 720) và vạch vuốt hệ thống (thanh Home của iOS) |

Không nút chạm nào nằm trong phần lề này.

### Vị trí của các thông tin còn lại

| Thông tin | Vùng / nơi hiện |
|---|---|
| I-04, I-42 (bối cảnh, mô tả trận) | Dải giới thiệu đè lên Z2 trong 2 giây đầu trận |
| I-05, I-32, I-33 (bộ bài, Giao Kèo, may mắn, lượt) | Màn Tạm dừng; I-32/I-33 cũng ở màn bản đồ |
| I-10 (bóng khối, báo trúng) | Z2, trên đất địch |
| I-14 (gợi ý ghép) | Z4, dưới menu lá |
| I-29, I-30 (vàng, tầng, chặng, máu) | Dải trên của màn bản đồ |
| I-31 (bảo vật) | Màn bản đồ (dải dưới trái); trong trận chỉ nháy biểu tượng ở Z1 cạnh thanh máu người chơi khi kích hoạt |
| I-34, I-35, I-36, I-41 (nhắc một lần, Thức Tỉnh đang chạy, Bản Khắc hoàn thành) | Dải hẹp ở mép trên Z2; **không phủ đất người chơi và ô đỏ** (sửa TD-038) |
| I-37 | Không hiện (chỉ dev) |
| I-38 (độ tươi khối) | Z2, gắn dưới từng khối trên sân |
| I-39 (kết quả trận) | Khung giữa màn hình (ngữ cảnh "Kết quả trận") |
| I-40 (hẹn giờ khối hỏng) | Z5, trên ô túi chứa khối hỏng |

**Phương án đã bỏ:** túi khối ở giữa, Thức Tỉnh bên phải. Ngón kéo khối sẽ che đường giữa hai lưới, là nơi cần nhìn nhất.

### Sân phối cảnh (2026-11-02, ADR-0002)

Sân trận vẽ thành hình thang phối cảnh, tỉ lệ hàng sau / hàng trước **0,82** (`combat.json` `floor.perspective.back_ratio`; `--floor-perspective=0` ép phẳng). Mọi yếu tố HUD **nằm trên ô** đi theo đa giác ô đã nắn qua `BoardGeometry`: bóng ma khối (xanh / đỏ / vàng cộng hưởng) và viền khối lạ, nhãn dự báo / tổng / cộng hưởng (đặt cạnh khung bao của ô đã nắn, trong nửa địch đã nắn), chữ TRÚNG / TRƯỢT, NGẮT, nhãn góc cảnh báo, thẻ địa hình (lầy, cát, lỗ thông hơi, nứt, rơi, đảo, gió), vòng hồi sinh, mây che, ô rơi trên sân và thanh độ tươi. Chạm và kéo khối đổi điểm chạm ngược về sân phẳng (`BoardGeometry.cell_at`). Chữ giữ cỡ phẳng cho dễ đọc; khung, vạch, vòng co theo tỉ lệ cục bộ. Các yếu tố **không** nằm trên sân (túi khối, nút, cột hồi chiêu, dải trên, băng tên phép) giữ bố cục màn hình.

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
| E-03 | Tạm dừng (M) | **v3:** ô đá 48 px sát góc trên phải, vùng chạm ô 96 px ở góc; vàng nằm bên trái. (Cũ: nút vuông 32 px giữa trên, vùng chạm 88×88 px) | Sự kiện | Luôn | Nhấn: dừng ngay, không cần xác nhận |
| E-04 | Bối cảnh trận (C) | Dải một dòng: "Tầng 1/5 · Rừng Sương · Chặng 1/3" + tên địch, dòng thứ hai là mô tả trận (I-42) | Một lần | 2 giây đầu trận | Trượt vào, mờ dần. Xem lại trong màn Tạm dừng |
| E-05 | Số lá trong bộ (D) | Chữ trong màn Tạm dừng | Sự kiện | Chỉ khi mở Tạm dừng | — |
| E-15 | Hình Cộng Hưởng (C) | **v3:** bỏ chip trên dải. Hình hiện một lần ở băng giới thiệu đầu trận cạnh tên sân ("Cộng hưởng ×1,5"); khi ghép khớp: bóng khối vàng + chữ "Cộng hưởng ×1,5 · N ô · −X" không khung | Sự kiện | Băng giới thiệu; lúc ghép khớp | Chữ nảy nhẹ khi hiện |
| E-18 | Khối boss đang giữ (M) | 3 ô nhỏ dưới thanh máu boss, mỗi ô là hình thu nhỏ (Khối Lạ có dấu sao). **Trống:** khung ô mờ, không chữ | Sự kiện | Luôn | Ô bị dùng xóa mờ 0,2 s |

### Điều khiển (Z3, Z4, Z5)

| ID | Yếu tố | Hình dạng | Cập nhật | Hiện khi | Hiệu ứng |
|---|---|---|---|---|---|
| E-06 | Pad 4 hướng (M) | Chữ thập 4 nút 97 px | Liên tục | Luôn; khóa khi đang đặt | Nút lún khi bấm. Viền sáng dần theo hồi bước (0,18–0,6 s). Giữ nút: lặp bước theo nhịp hồi bước, không bước thừa |
| E-07 | Túi khối (M) | **v3:** 3 ổ đá vát góc 64×64 thẳng hàng dưới phải; trong ổ chỉ có hình khối, số ô nhỏ ở góc dưới phải | Sự kiện | Luôn | Nhặt: khối bay vào ô 0,2 s. Đầy: viền hổ phách quanh mọi ổ (v3 bỏ nhãn "ĐẦY"). Khối chọn (v3): viền vàng. Khối chọn: viền Ngà (vàng là màu Bản Khắc). Khối Lạ: dấu sao. Khối hỏng: xám + chữ "HỎNG" + giây (không dấu X: ✗ là "trượt")|
| E-08 | Thức Tỉnh (M) | Nút lớn: tên + thanh Bản Khắc "0/21" | Liên tục | Luôn | **Đang nạp:** mờ, thanh chạy. **Đang hồi:** mờ + "Hồi 12 s". **Sẵn sàng:** sáng + chữ "SẴN SÀNG", nhịp đập 1 Hz. **Đang chạy:** thanh thời gian + "ĐANG DÙNG" |

### Đặt khối và tung phép (chỉ khi đang đặt)

| ID | Yếu tố | Hình dạng | Cập nhật | Hiệu ứng |
|---|---|---|---|---|
| E-09 | Tập trung (C) | **v3:** ngòi vàng quanh viền Tung phép (cùng ngòi với cửa sổ đặt; hiện cái hết trước) + khung xanh thép quanh màn hình. Bỏ thanh, tag "DỪNG" và tag hồi Tập trung | Liên tục | Hết thì trận chậm lại 0,2× |
| E-10 | Bóng khối + báo trúng (C) | Ô sàn đất địch trùng hình khối đổi màu, không vẽ khối lên sân: **trọn ô, màu khối của nhân vật**: trúng tô đậm, viền liền / trượt tô mờ, viền nét đứt, kèm nhãn "Sẽ trúng ✓" / "Sẽ trượt ✗" | Theo ngón tay | Hít vào ô trong 0,05 s, chỉ đổi màu, không animation. Khối nhỏ nâng lên 56 px trên ngón tay |
| E-11 | Số ô và sát thương (C) | **v3:** chỉ trên sân cạnh bóng khối, chữ không khung ("Sẽ trúng · 7 ô · -42", "Tổng 7 ô · 42 sát thương"); bỏ cột dưới | Theo xoay hoặc ghép | — |
| E-12 | Xoay, Tung phép, Hủy (C) | **v3:** hàng dưới trái `[Tung phép 100][Xoay 64][Hủy 72]` cao 64 px, chữ Tung phép vàng, Xoay vuông với mũi tên xoay vàng; gợi ý "Kéo khối lên đất địch" là chữ trơn ngay trên hàng khi khối chưa ở đất địch | Sự kiện | Xoay: khối quay 90° trong 0,1 s |
| E-13 | Menu 4 lá (C) | **Từ 2026-11-01** (`design/quick-specs/menu-la-giua-man-hinh-2026-11-01.md`): mở khi bấm Tung phép, không mở khi thả khối. Lớp xám nhẹ nhìn xuyên được phủ cả màn hình; 4 mặt lá `CardFace` (176×256) ở giữa màn hình; **v3:** 3 s là ngòi vàng chạy quanh khung góc cạnh bao 4 lá (thay thanh đếm), Hủy ở góc dưới trái. Lá đang hồi: tối, quạt đen quay theo kim đồng hồ + số giây, không chọn được | Liên tục | Lá chưa đủ ô: mờ + "cần N ô". Hết giờ: tự chọn nhát chém cơ bản |
| E-14 | Gợi ý ghép (C) | **Bỏ 2026-11-01**: ghép làm trước khi bấm Tung phép, không còn ghép trong menu (+1,5 s). Dòng cũ: "Kéo thêm khối để ghép · +1,5 s" | Mỗi lần mở menu | Hiện suốt thời gian menu 4 lá mở, theo **thời gian chọn lá** (3 s / 6 s / không giới hạn); không xếp hàng với các dòng nhắc một lần. Ẩn hẳn sau khi người chơi đã ghép ít nhất một lần (cờ trong tiến trình). **Đề xuất mới.** |
| E-43 | Buff/debuff nhân vật (C, v3 2026-11-02) | Hàng dưới hàng bảo vật, góc trên trái: mỗi trạng thái đang có (Đóng Băng, Trói, Chậm, Cháy, Rạn, Giá Lạnh, Giáp tạm) một khung bát giác 40 px viền màu trạng thái; phần thời gian còn lại sáng màu trạng thái, phần đã qua phủ tối quay theo kim đồng hồ từ 12 giờ, có kim; trạng thái theo tầng (Rạn, Giá Lạnh) hiện số tầng. Chạm: chú thích nhỏ tên + tác dụng (3 s). Thay chip dưới chân nhân vật (boss giữ chip) | Liên tục | Khi có trạng thái | Trói và Chậm chưa có icon trong bộ icon: tạm vẽ glyph góc cạnh bằng code |
| E-42 | Cột hồi chiêu (C, 2026-11-01) | **v3:** dưới hàng buff/debuff. Mép trái màn hình, giữa hàng bảo vật và cần điều khiển: icon mỗi lá đang hồi, quạt đen mờ quay theo chiều kim đồng hồ từ 12 giờ, số giây còn lại ở giữa (kiểu Liên Minh Huyền Thoại) | Khi có lá đang hồi | Hồi xong thì icon rời cột; xếp từ trên xuống theo thứ tự dùng |

### Đọc đòn boss (trên lưới)

| ID | Yếu tố | Hình dạng | Cập nhật | Hiệu ứng |
|---|---|---|---|---|
| E-16 | Ô đỏ báo đòn (M khi có đòn) | Ô đỏ có **sọc chéo** + viền đậm | Theo đòn | Cường độ tăng khi gần hết giờ |
| E-17 | Ô báo đòn đậm dần (M khi có đòn) | Không còn nhãn chữ (sửa 2026-10-31). Các ô đỏ hiện mờ ngay khi địch bắt đầu niệm rồi đậm dần đều tới đầy đúng lúc đòn rơi: sọc chéo ≥ 50 % từ đầu, phần tô 0 → 45 %, viền 30 → 100 %; tất cả ở lớp sàn, dưới chân đơn vị. Giảm chuyển động: 3 bậc rời (mờ, vừa, đậm). Tên đòn và số ô chỉ hiện ở màn tạm dừng / thông tin | Liên tục | — |
| E-19 | NGẮT! (C) | Biểu ngữ giữa lưới 0,6 s + dòng nhỏ ("boss bị hủy đòn" hoặc "đòn của bạn bị hủy") | Sự kiện | Lắc nhẹ 0,15 s |
| E-20 | ĐÒN GIẢ! (C) | Biểu ngữ nhỏ phía trên boss 0,8 s | Sự kiện | — |

### Con số và trạng thái (gắn vào đơn vị)

| ID | Yếu tố | Hình dạng | Cập nhật | Hiệu ứng |
|---|---|---|---|---|
| E-21 | Sát thương, TRÚNG/TRƯỢT (C) | Số nổi lên từ đơn vị, viền trắng, cỡ chữ theo lượng sát thương | Sự kiện | Bay lên, mờ dần trong 0,8 s |
| E-22 | Số hồi máu (C) | "+8" có dấu cộng (không chỉ màu xanh) | Sự kiện | Như E-21 |
| E-23 | Từ khóa trên đơn vị (C) | Tối đa 3 chip dưới ô đơn vị (sân 5×5: tối đa 2, phần dư "+N"): biểu tượng **khác hình nhau** (ngọn lửa, vết nứt, bông tuyết, khối băng) + số tầng/giây | Liên tục | Chip mới bật ra 0,2 s |

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
| E-34/35 | Nhắc một lần: Khối Lạ, đổi Bộ khối (C) | Dòng nhắc **6 s** (≥ 5 s theo `design/accessibility-requirements.md`) ở mép trên Z2; đọc lại ở "Xem lại hướng dẫn" | Sự kiện | Một lần, lưu cờ "đã thấy" trong tiến trình |

### Bổ sung sau `/ux-review`

| ID | Yếu tố | Hình dạng | Cập nhật | Hiện khi | Hiệu ứng |
|---|---|---|---|---|---|
| E-24 | Ô Tường, Bãi Gai, ô cháy (H) | Tường: khối dựng nổi, viền đặc, gạch chéo. Bãi Gai: gai nhọn trên nền thưa, đi qua được. Ô cháy: ngọn lửa + **sọc ngang** (sọc chéo chỉ dành cho báo đòn). **Ba loại khác hình hẳn nhau** (không chỉ khác màu) | Sự kiện | Khi ô có hiệu ứng | Bật lên 0,15 s khi xuất hiện, mờ dần khi hết |
| E-38 | Độ tươi khối trên sân (M, gắn trên khối) | Thanh ngắn dưới mỗi khối, **chiều dài = thời gian còn lại**, không mã màu (đỏ chỉ dành cho báo đòn) | Liên tục | Khi có khối trên sân | Dưới 2 s: khối nháy chậm 1 Hz (giảm chuyển động: viền nét đứt) |
| E-39 | Kết quả trận (C) | Khung giữa màn hình. Thắng: "THẮNG TRẬN!", "+N máu", "Đối thủ kế: X", nút Tiếp tục ≥ 96 px, "tự động sau N s". Thua: "THUA!", trận và tầng gục, thống kê, nút | Một lần | Khi trận kết thúc | Phóng nhẹ vào 0,2 s |
| E-40 | Hẹn giờ khối hỏng (C) | Số giây trên ô túi chứa khối hỏng + vạch co dần | Liên tục | Khi trong túi có khối hỏng | — |
| E-41 | Bản Khắc hoàn thành (C) | Dải ngắn ở mép trên Z2: "Bản Khắc hoàn thành"; nút Thức Tỉnh nháy | Sự kiện | Khi mọi ô cùng sáng | 1 s |

### Ánh xạ yếu tố → thông tin, vùng, nguồn dữ liệu

| Yếu tố | Thông tin | Vùng | Nguồn (hệ thống sở hữu dữ liệu) |
|---|---|---|---|
| E-01, E-02 | I-01, I-02 | Z1 | trạng thái trận (CombatState) |
| E-03, E-05 | I-03, I-05 | Z1; màn Tạm dừng | luồng trận (GameFlow) |
| E-04 | I-04, I-42 | Dải giới thiệu trên Z2 | dữ liệu trận và chuyến leo |
| E-06 | I-06 | Z3 | di chuyển (UnitMover) |
| E-07, E-40 | I-07, I-40 | Z5 | túi khối (HoldSlots) |
| E-08, E-36, E-41 | I-08, I-36, I-41 | Z4; mép trên Z2 | Thức Tỉnh và Bản Khắc |
| E-09 | I-09 | Z4 | Tập trung (FocusController) |
| E-10, E-11, E-12 | I-10, I-11, I-12 | Z2 (đất địch); Z3, Z4 | đặt khối (PlacementController, CastPlan) |
| E-13, E-14 | I-13, I-14 | Z4 | lá phép (CutFlow, Deck) |
| E-15 | I-15 | Z1 | Hình Cộng Hưởng của sân |
| E-16, E-17, E-20 | I-16, I-17, I-20 | Z2 | đòn của boss (BossController) |
| E-18 | I-18 | Z1b | túi khối của boss |
| E-19, E-21, E-22 | I-19, I-21, I-22 | Z2 | kết quả đòn |
| E-23 | I-23 | Z2 (trên đơn vị) | từ khóa (StatusEffects) |
| E-24, E-25 | I-24, I-25 | Z2 | vùng và địa hình (ZoneRules, TileHazards) |
| E-26, E-27, E-28 | I-26, I-27, I-28 | Z2 | đặc tính boss (TraitHost) |
| E-29/30, E-31, E-32/33 | I-29–I-33 | Màn bản đồ, màn Tạm dừng | chuyến leo (RunSession) |
| E-34, E-35 | I-34, I-35 | Mép trên Z2 | tiến trình (cờ "đã thấy") |
| E-38 | I-38 | Z2 (trên khối) | khối rơi (FieldDrops) |
| E-39 | I-39 | Khung giữa màn hình | luồng chuyến leo (GameFlow, RunSession) |

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
| **Chiến đấu: chọn lá** | Lớp xám nhìn xuyên được + menu 4 lá (E-13) ở giữa màn hình, thanh đếm 3 s (gợi ý ghép E-14 đã bỏ) | Số ô và Tung phép |
| **Chiến đấu: đòn đang niệm** | Ô đỏ của boss (E-16, E-17) và ô đích đòn của bạn trên đất địch: màu chất liệu khối, sáng dần tới lúc phép rơi; hình trên ô, không nhãn (`design/art/art-bible.md` Mục 3) | Tung phép |
| **Chiến đấu: Thức Tỉnh đang chạy** | E-08 "ĐANG DÙNG", dải thời gian (E-36) | — |
| **Chiến đấu: pha 2 của boss** | Biểu ngữ pha (E-27) 1,5 s, rồi trở lại như bình thường | — |
| **Kết quả trận** | Khung kết quả (E-39) + thanh máu người chơi (E-01, để thấy máu hồi) | Mọi HUD trận khác; mọi thông báo đang chờ bị xóa, nhắc một lần (P5) dời sang trận sau |
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
| | E-13 (menu lá, khi mở) | Chọn đòn | Hết giờ tự chọn nhát chém cơ bản |
| | E-38 (độ tươi khối) | Quyết định nhặt khối nào trước | Khối tan mà không báo |
| | E-29/30 (trên màn bản đồ) | Chọn đường đi | — |
| | E-39 (kết quả trận) | Biết máu đã hồi, đối thủ kế | — |
| **SHOULD KEEP** | E-08 (Thức Tỉnh) | Chiều sâu chiến thuật | Hiệu ứng hình trên lưới |
| | E-18 (khối boss đang giữ) | Đoán đòn kế tiếp của boss | Cảnh báo ô đỏ khi tung |
| | E-23 (từ khóa trên đơn vị) | Biết có đòn đang tích | Hiệu ứng trên ô |
| | E-25 (cảnh báo địa hình) | Tránh sát thương môi trường | Hình vẽ trên ô |
| | E-24 (Tường, Bãi Gai, ô cháy) | Biết ô nào đi được | Không có thay thế (H: chính là hình trên ô) |
| | E-03 (tạm dừng) | Cần nhưng ít bấm | Nút Back của hệ điều hành mở Tạm dừng |
| | E-09 (Tập trung) | Biết còn bao lâu được dừng | Trận chuyển sang chậm 0,2× |
| | E-19 (NGẮT!) | Biết đòn bị phá | Ô đỏ biến mất, âm thanh |
| | E-26 (đặc tính boss có đếm) | Canh thời điểm | Hình trên ô boss |
| | E-27 (biểu ngữ pha) | Boss đổi lối đánh | Vạch nửa máu nháy (E-02) |
| | E-28 (mây che báo trúng) | Biết báo trúng không dùng được | Không có bóng xanh/đỏ |
| | E-40 (khối hỏng) | Biết khi nào ô túi trống lại | Khối xám có chữ "HỎNG" + giây |
| **CAN HIDE** | E-21, E-22 (số nổi) | Phản hồi, không quyết định | Thanh máu cho thấy thay đổi |
| | E-04, E-15, E-34, E-35 | Chỉ giúp lần đầu | Màn Tạm dừng, thông báo một lần |
| | E-14 (gợi ý ghép) | Chỉ cần với người mới | Thanh đếm menu lá vẫn có +1,5 s |
| | E-20 (ĐÒN GIẢ!) | Phản hồi | Ô đỏ biến mất |
| | E-36, E-41 (Thức Tỉnh đang chạy, Bản Khắc hoàn thành) | Phản hồi | Trạng thái của nút E-08 |
| **ALWAYS HIDE** (trong trận) | E-05, E-31–E-33 | Xem được ở Tạm dừng | Màn Tạm dừng |
| | E-37 (bộ đếm học của boss) | Chỉ dùng khi dev | — |

---

## Visual Budget

**Cách đếm:** một yếu tố là một khối thông tin có **vị trí riêng** trên màn hình. Một nhóm nút đứng cùng chỗ (Xoay + Tung phép + Hủy) tính **1**. Thông tin gắn trên khối hoặc đơn vị (thanh tươi E-38, chip từ khóa E-23) **không tính** vào số yếu tố mà tính vào diện tích phủ lưới.

Đo theo **số yếu tố** và **diện tích**. Diện tích tính từ kích thước nút hiện có (pad 97 px, túi khối 113×158 px, nút Xoay 288×288 px). Người dùng duyệt 2026-10-28.

| Tiêu chí | Giới hạn | Hiện trạng ước tính |
|---|---|---|
| Số yếu tố đồng thời: nhàn rỗi | **9** (đúng bộ "luôn hiện") | 9 |
| Số yếu tố đồng thời: đang đặt khối hoặc chọn lá | **≤ 16** | Đặt khối: E-01, 02, 03, 07, 08 (mờ), 18 + nhóm nút E-12 + E-09, 10, 11, 15 = **11**. Chọn lá khi boss đang niệm: E-01, 02, 03, 07, 08, 18, 13, 14, 15, 16, 17 = **11** |
| Số yếu tố đồng thời, kể cả thông báo | **≤ 18** | Trường hợp xấu nhất: 11 + 4 thông báo P2 (NGẮT!, pha, 2 nhãn địa hình) = **15** |
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
| Bản Khắc hoàn thành (E-41) | Mọi ô cùng sáng | Mép trên Z2 | 1 s | 1 | P3 | Thay thế |
| Nhắc một lần (E-34, E-35) | Sự kiện lần đầu | Mép trên Z2 | 6 s | 1 | P5 | **Xếp hàng tối đa 2.** Chỉ hiện khi 1,5 s qua không có P1 hay P2 và người chơi không đang kéo. Sau 10 s chưa hiện được thì bỏ; cờ "đã thấy" chỉ ghi khi đã thật sự hiện, nên lần sau vẫn nhắc |

**Quy tắc chung:**
- **Không bao giờ che ô đỏ báo đòn (P1).** Mọi thông báo khác phải tránh vùng đất người chơi đang đứng và vùng ô đỏ.
- **Kết quả trận (E-39)** không phải thông báo: khi trận kết thúc, mọi thông báo đang hiện hoặc đang chờ bị xóa; P5 chưa hiện dời sang trận sau.
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
| **Kích thước chạm** | Điều khiển chính ≥ **96 px** (mục tiêu 104 px; trên máy 6″ 20:9 96 px chỉ ≈ 8,3 mm, cần đo trên máy thật). Điều khiển phụ ≥ **88 px** vùng chạm (hình có thể nhỏ hơn, ví dụ tạm dừng 32 px). Khoảng cách giữa hai nút chạm kề nhau ≥ **12 px** (cụm pad ≥ 8 px); Tung phép và Hủy cách ≥ 24 px. Theo kiểm UX 2026-10-29 (`design/art/art-bible.md` 7.4) |
| **Đa chạm** | Ngón trái giữ pad, ngón phải kéo khối **cùng lúc** phải hoạt động. Không dùng thao tác chỉ có bấm giữ hoặc vuốt chính xác |
| **Ngón tay che màn hình** | Khối nâng lên 56 px trên ngón tay khi kéo. Lưới nằm ở nửa trên; ô đỏ báo đòn trên đất người chơi không bị ngón phải che |
| **Rung (haptic)** | Tùy chọn, mặc định bật: rung ngắn khi boss bắt đầu đòn và khi bạn bị trúng. Không rung liên tục |
| **Android và iOS** | Cùng bố cục. Khác biệt chỉ ở vùng an toàn và API rung |

---

## Accessibility

**Cấp đã cam kết: Standard, điều chỉnh cho cảm ứng** (`design/accessibility-requirements.md`, 2026-10-28). Các hạng mục dưới đây là phần của HUD; cam kết đầy đủ, bảng kiểm màu và kế hoạch kiểm thử nằm ở file đó. Người dùng chấp nhận tạm thời 2026-10-28 (có thể sửa nhỏ sau).

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
| Chế độ mù màu | Tắt / Bật | Tắt | **Chờ quyết định** (2026-10-29): bóng khối không còn dùng xanh lá – đỏ (nay là màu khối của nhân vật, trúng/trượt đọc bằng hình), nên chưa rõ chế độ này còn đổi gì. Xem Open Questions 14 |
| Nhắc hướng dẫn | Đầy đủ / Ẩn, kèm mục "Xem lại hướng dẫn" | Đầy đủ | Gợi ý ghép và các dòng nhắc một lần |
| Thời gian chọn lá | 3 s / 6 s / không giới hạn | 3 s | Menu 4 lá (E-13): hết giờ tự chọn nhát chém cơ bản; không giới hạn thì chờ người chơi chọn (trận vẫn chậm 0,2×) |
| Tự tiếp tục sau trận | 3 s / 8 s / Tắt | 3 s | Màn kết quả trận (E-39); nút Tiếp tục luôn có |
| Xác nhận Giết | Giữ 0,6 s / Chạm hai lần | Giữ 0,6 s | Màn Tha/Giết |

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
- [ ] **Kích thước chạm:** điều khiển chính ≥ 96 px, vùng chạm nút tạm dừng ≥ 88 px, khoảng cách hai nút kề ≥ 12 px ở 720p.
- [ ] **Chữ:** chữ đọc trong chiến đấu ≥ 18 px, số liệu chính ≥ 24 px ở 720p. Tương phản ≥ 4,5 : 1 (lấy mẫu).
- [ ] **Giảm chuyển động bật:** không có nhấp nháy, nhịp đập hay rung; thay bằng dấu tĩnh.
- [ ] **Thuận tay trái bật:** pad bên phải, túi khối bên trái; kéo đặt khối vẫn hoạt động.
- [ ] **Đa chạm:** giữ pad bằng ngón trái trong khi kéo khối bằng ngón phải hoạt động bình thường.
- [ ] **Độ tươi khối:** trên ảnh chụp đen trắng, phân biệt được khối sắp tan (thanh ngắn) với khối mới rơi (thanh đầy).
- [ ] **Kết quả trận:** khi thắng trận, khung kết quả hiện máu hồi và đối thủ kế, nút Tiếp tục ≥ 96 px, tự tiếp tục sau đúng số giây ghi trên màn; không còn thông báo trận nào hiện trên khung.
- [ ] **Dòng nhắc không đè lưới:** dòng nhắc một lần không phủ ô nào của đất người chơi và không phủ ô đỏ báo đòn (TD-038).
- [ ] **Art ở ô nhỏ:** trên ảnh chụp sân 5×5 (ô khoảng 55 px cao), nhận ra được 5 nhân vật và boss qua dáng hình.
- [ ] **Cỡ chữ 130 %:** bật Cỡ chữ HUD 130 % trên màn 1280×720; không chữ nào bị cắt và không chữ nào che ô đỏ báo trúng.
- [ ] **Đường một ngón:** chơi trọn một chuyến leo chỉ bằng một ngón, thao tác tuần tự (chạm khối trong túi rồi chạm ô đích, bấm pad, chạm lá); không bước nào bắt buộc hai ngón.
- [ ] **Thời gian chọn lá:** đặt 6 s thì menu 4 lá mở đủ 6 s rồi mới tự chọn nhát chém cơ bản; đặt không giới hạn thì menu chờ đến khi người chơi chọn.
- [ ] **Giữ pad:** giữ một nút pad 2 s thì nhân vật bước lặp đúng nhịp hồi bước; thả tay là dừng ngay, không có bước thừa sau khi thả.
- [ ] **Tự tiếp tục sau trận:** đặt 8 s thì màn kết quả chờ 8 s; đặt Tắt thì chờ vô hạn; ở mọi mức, nút Tiếp tục luôn hiện và bấm được.

---

## Open Questions

1. ~~Cấp trợ năng chưa cam kết~~ **Đã giải quyết 2026-10-28:** Standard, điều chỉnh cho cảm ứng (`design/accessibility-requirements.md`).
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
11. **TD-038** (dòng nhắc bị lưới đè): sửa trong story HUD theo quy tắc mục Feedback & Notification Systems và vị trí "mép trên Z2" ở mục Layout Zones.
12. **Độ dài chữ vi/en.** Bản tiếng Anh dài hơn; cần độ dài tối đa cho các nhãn trên lưới (E-17, E-25) và dải giữa (E-11, E-13) trước khi làm story HUD. Nhãn trên lưới tự thu nhỏ cho vừa ô (mục Tuning Knobs).
13. ~~Nút tạm dừng E-03 so với dải Z1 mới~~ **Đã giải 2026-10-29:** nút vuông 32 px, vùng chạm 88×88 px (`design/art/art-bible.md` 7.7).
14. **Chế độ mù màu còn đổi gì?** Trước đây nó đổi bóng khối xanh lá – đỏ sang lam – cam. Từ 2026-10-29 bóng khối dùng màu khối của nhân vật và đọc trúng/trượt bằng hình, nên không còn cặp màu nào bắt buộc phải đổi. Tầng Standard trong `design/accessibility-requirements.md` vẫn cam kết "ít nhất một chế độ mù màu". Cần chốt: giữ chế độ (ví dụ đổi đỏ báo đòn và các màu trạng thái sang bảng tương phản cao) hay ghi lý do bỏ.
15. **Dải giữa Z4 ngoài tầm ngón cái trên máy 20:9** (kiểm UX 2026-10-29: tâm cách mép ~69 mm, ngón với tới ~50 mm). Tung phép, Xoay, Thức Tỉnh là nút hay bấm nhất. Cần chốt: neo Z4 về phía tay rảnh hay chia nút sang Z3/Z5. Kiểm trên máy thật.
16. **Vùng vuốt Back của Android** (~55 px từ mép) có thể trùng pad sát mép trái. Đẩy pad vào ≥ 56 px hoặc xin loại trừ cử chỉ (chưa kiểm trong Godot 4.6).

## Thay đổi sau buổi chơi thử 2026-10-31 (người dùng)

- **Không còn vòng hồi bước** quanh người chơi và boss sau mỗi bước (`combat.json` `hud.step_rings: false`); vòng thép liền "boss bị khóa chân khi đang niệm" vẫn giữ.
- **Số sát thương từ sàn**: ô cháy, ô gai và lầy hiện "-N" bay lên trên đầu đơn vị (cam Cháy, nâu Gai, xám xanh Lầy), 0,7 s; số "TRÚNG -N" của đòn đánh giữ nguyên. Đi kèm luật mới `burn_on_entry`: bước vào ô đang cháy mất ngay một nhịp sát thương (trước đây đi ngang qua không mất gì).
- **Chiêu bay ra từ nhân vật**: khi người chơi niệm, nhân vật giữ tư thế giơ kiếm; khi còn `travel_sec + gesture_lead_sec` (0,27 s) clip chém chạy và lưỡi kiếm khí (gói PixelLab `assets/art/vfx/cast/sword_wave`) phóng từ tay tới các ô đích, chạm đúng lúc đòn rơi (`assets/art/vfx/cast/index.json`).
- **Skin cho toàn bộ màn**: nền tối `HudSkin.SCREEN_BG`, nút vát góc `HudSkin.button` (chính: viền vàng Ánh Lưới), thẻ `HudSkin.card`; vị trí và vùng chạm không đổi.
