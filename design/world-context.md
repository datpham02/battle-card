# Thế giới Tessera: bối cảnh cho asset

> **Phiên bản 2, 2026-10-27.** Người dùng đã duyệt các điểm sau:
> - **Fantasy phương Tây**, không theo kiếm hiệp hay tiên hiệp.
> - Thế giới gặp một **Biến Cố** làm quy tắc biến đổi: mọi sức mạnh chỉ dùng được qua **hình ghép từ ô vuông**.
> - Lore Hình Gốc, tên **Tessera**, trận cuối **Tâm Lưới**.
> - Toàn bộ thuật ngữ theo `design/glossary.md`.
>
> Tài liệu này là đầu vào cho asset nhân vật, animation, world và map, và cho `/art-bible`. Nó **không đổi cơ chế**: luật chơi vẫn theo `design/game-brief.md` và `assets/data/*.json`.
> Mục ghi **[Khởi điểm]** là gợi ý hình ảnh, chốt lại ở art bible.
> Chữ trong game đã dùng thuật ngữ mới của `design/glossary.md` (kiểm `assets/i18n/strings.csv` 2026-11-01: không còn Ấn Đài, Kiếp, mảnh, trận đồ…).

---

## 1. Thế giới trong một đoạn

**Tessera** từng là một thế giới fantasy bình thường. Pháp sư vung tay là ra lửa, kiếm sĩ chỉ cần rút kiếm, mỗi người dùng sức mạnh theo cách của mình. Rồi **Biến Cố** xảy ra: **Hình Gốc**, khối hình đầu tiên đã nặn ra mọi vùng đất, vỡ tan ở **Tâm Lưới**. Từ đó một **mạng lưới ô vuông** lan khắp thế giới, và quy tắc đổi khác. **Mọi sức mạnh, từ phép thuật, kiếm thuật đến chiêu thức, chỉ còn dùng được khi đi qua những khối hình ghép từ ô vuông.** Ai muốn đánh đều phải nhặt khối rơi trên đất mình, xoay, đặt lên đất đối thủ rồi tung phép. Không ai thoát được luật này, kể cả quái vật, rồng và những kẻ gác vùng.

Người chơi là một trong năm nhà thám hiểm, leo qua năm tầng đất của Tessera để lên **Tâm Lưới**, nơi Biến Cố bắt đầu. Trên đường, họ hạ từng **Kẻ Gác** và phải chọn: **tha** cho họ giữ mảnh Hình Gốc, hay **giết** để lấy nó. Lựa chọn đó quyết định thế giới được ghép lại theo cách nào. Chết là hết một **chuyến leo**, và Tessera xếp lại vùng đất cho chuyến sau.

---

## 2. Luật sức mạnh sau Biến Cố (lore giải thích cơ chế)

| Cơ chế trong game | Cách thế giới giải thích |
|---|---|
| **Khối** (1–5 ô) rơi trên sân mình | Sức mạnh còn sót của Hình Gốc **kết tinh thành khối** và rơi xuống lưới. Khối để lâu không dùng sẽ tan. |
| Nhặt khối, xoay, đặt lên đất địch | Sức mạnh chỉ "in" được lên đất theo đúng hình của khối. Khối quyết định **chỗ** đòn đánh xuống. |
| **Lá phép** (Chém, Đẩy, Cháy, Đóng Băng, Giá Lạnh, Rạn…) | Lá là **công thức**: nó cho khối biết phải trở thành gì. Bộ bài là sổ công thức người chơi mang theo. |
| Khối càng to thì đòn càng mạnh nhưng niệm càng lâu | Hình lớn khó giữ ổn định, phải niệm lâu mới in trọn được. |
| **Phá phép**: ai chạm trước thì hủy đòn người kia | Hai khối đang hình thành va nhau thì khối đến sau vỡ tan. |
| Hai lưới đối diện | Sau Biến Cố mọi vùng đất nằm trên **mạng lưới** ô vuông. Sức mạnh chỉ bám được vào lưới, nên mọi trận đấu diễn ra trên hai nửa lưới đối diện. |
| **Hình Cộng Hưởng**: ghép hai khối trùng hình của sân thì ×1,5 | Mỗi vùng mang dư âm một mảnh Hình Gốc. Ghép đúng hình đó thì đất cộng hưởng. |
| **Bản Khắc**: ô bị đánh sáng lên rồi phai | Đất ghi nhớ những khối đã in lên nó. Khi cả nửa lưới cùng sáng, sức mạnh riêng của nhân vật **Thức Tỉnh**. |
| **Bãi Gai** và **Ô rớt** | Khối cũng rải được thành bãi gai. Riêng boss còn làm nứt ô lưới bên người chơi cho rơi thành hố (Ô rớt, thay Tường từ 2026-10-31). |
| Boss cũng nhặt và đặt khối | Biến Cố trói tất cả, kể cả Kẻ Gác. |
| **Bảo vật** | Vật cổ dùng để uốn luật khối. Thứ quý nhất là **Mảnh Gốc** của Kẻ Gác. |
| **Bộ khối**: Học hình, Quên hình | Mỗi người tự chọn những hình mình thạo. Bộ khối là tay nghề của họ. |

---

## 3. Cốt truyện khung

- **Biến Cố.** Hình Gốc vỡ ở Tâm Lưới, mạng lưới ô vuông phủ khắp Tessera, và quy tắc sức mạnh đổi khác. **Nguyên nhân Biến Cố cố ý để ngỏ**, dành cho mở rộng sau: ai hay điều gì làm vỡ Hình Gốc.
- **Kẻ Gác.** Mảnh Hình Gốc rơi vào tay các Kẻ Gác, mỗi người một vùng. Mảnh đó định hình vùng đất của họ: sân, địa hình, quái vật. Hạ được họ thì chọn:
  - **Tha:** Kẻ Gác giữ mảnh, vùng đất vẫn sống theo cách của nó. Tha đủ nhiều thì con đường của **Giáo sĩ** mở ra.
  - **Giết:** người chơi lấy **Mảnh Gốc**, vùng đất mất linh hồn. Giết đủ nhiều thì con đường của **Thợ săn** mở ra.
- **Tâm Lưới.** Đỉnh của Tessera, nơi Biến Cố bắt đầu. **Người Giữ Tâm Lưới** canh nơi đó và ghi lại mọi lựa chọn: *"Mọi lựa chọn của ngươi đều được ghi ở đây."* Ai lên tới Tâm Lưới sẽ quyết định Tessera được ghép lại theo cách nào. Có ba kết thúc:
  - **Lòng Tha Thứ** (tha tất cả): các Kẻ Gác còn sống, các vùng đất thở dễ hơn.
  - **Cán Cân** (lưng chừng): Tâm Lưới vỡ làm đôi, một nửa sáng, một nửa tối.
  - **Lưỡi Kiếm Lạnh** (giết tất cả): Tâm Lưới cúi đầu trước sức mạnh. Người chơi mạnh nhất và cô độc nhất.
- **Chuyến leo và Giao Kèo.**
  - Mỗi lần chơi là một **chuyến leo**. Chết thì chuyến leo kết thúc, và Tessera xếp lại vùng đất theo thứ tự khác cho chuyến sau.
  - Người đã thắng có thể ký **Giao Kèo** với Người Giữ Tâm Lưới trước chuyến leo kế tiếp. Mỗi bậc thêm một **điều khoản** khắc nghiệt (10 bậc, cộng dồn, riêng cho từng nhân vật).

---

## 4. Bản đồ thế giới

- **Hình dạng [Khởi điểm]:** một ngọn núi lớn giữa Tessera. Các vùng đất xếp thành tầng quanh sườn núi, **Tâm Lưới trên đỉnh**. Mạng lưới ô vuông nên lộ rõ dần khi lên cao, như thể gần tâm Biến Cố hơn. Mỗi tầng chọn 1 trong 2 vùng.
- **Cấu trúc chuyến leo (cơ chế, không đổi):** 5 tầng, mỗi tầng 1 vùng, mỗi vùng có 3 **chặng**:
  - **Trận mở đầu.**
  - **Nhánh rẽ** gồm các nút trận, hiểm địa, tinh anh, kho báu, sự kiện, cửa hàng, trại nghỉ.
  - **Kẻ Gác.**

  Sau tầng 5 là Tâm Lưới: một cửa hàng rồi trận cuối.
- **Cùng một vùng có thể gặp ở bất kỳ tầng nào.** Lên càng cao, quái của vùng đó càng mạnh. Hình ảnh nên gợi được độ cao, ví dụ mây, ánh sáng hoặc độ lộ của lưới đổi theo tầng, mà không cần vẽ lại vùng.
- **Biểu tượng nút** (đã có trong game): trận (kiếm chéo), hiểm địa (tam giác), tinh anh (đầu lâu), kho báu (rương), trại nghỉ (giọt lửa), cửa hàng (túi tiền), Kẻ Gác (vương miện).

---

## 5. Các vùng đất

Mỗi vùng là một kiểu **mạng lưới** khác nhau sau Biến Cố: lưới đè lên địa hình cũ của vùng. Tên quái và Kẻ Gác lấy từ dữ liệu game. Phần không khí trích từ chữ trong game.

### Rừng Sương (Misty Forest)
- **Không khí:** rừng thưa nhiều lối né, sương phủ thấp.
- **Mạng lưới [Khởi điểm]:** phế tích lát đá giữa rừng, rễ cây đội ô lên, rêu lấp kẽ ô.
- **Sân:** vuông, chữ nhật.
- **Quái:**
  - Rễ, rêu, nấm: Rễ Con, Lính Gác Rêu, Nấm Mũ Xám; tinh anh Vệ Binh Rễ Cổ, Mẹ Gai Sương.
  - Goblin: trinh sát, cung thủ; **Goblin Vu Sư** (Kẻ Gác tầng 1–2: ném khối 4 ô trộm của lưới).
  - Sói: sói dữ; tinh anh sói đầu đàn.
  - (2026-11-03, `design/quick-specs/doi-hinh-rung-suong-2026-11-03.md`.)
- **Kẻ Gác:** **Phù thủy rừng**.
- **Màu [Khởi điểm]:** xanh rêu, xám sương, nâu gỗ.

### Hầm Ngục (The Dungeon)
- **Không khí:** *"Cánh cổng ngục khép lại sau lưng. Tiếng xích kéo lê trong bóng tối."*
- **Mạng lưới:** sàn ngục xếp ô đá, có hố sập (lỗ trên sân) và khu bị tách đôi (hai đảo).
- **Địa hình:** ô rớt (boss làm nứt ô rồi rơi thành hố).
- **Quái:** bộ xương lính, xác sống, đàn dơi, nhầy ngục, tín đồ tà giáo, lính gác Chuột Vương, bóng ma, Kẻ Phản Ứng, Cai Ngục.
- **Kẻ Gác:** **Quỷ Khổng Lồ**.
- **Màu [Khởi điểm]:** xám đá, xanh rêu ẩm, đuốc là mảng ochre đục không phát sáng (chỉ Khối phát sáng).

### Tháp Sương (The Mist Tower)
- **Không khí:** *"Tháp Sương mọc lên từ biển mây, mỗi bậc thang lạnh hơn bậc trước."*
- **Mạng lưới:** sàn tháp lát phiến băng, sân hình vòng, hình kim cương.
- **Địa hình:** bãi gai.
- **Quái:** tiên sương, ma trơi, lính canh đá, sói tuyết, cung thủ sương giá, người băng, Pháo Ngòi, Pháp Sư Sương.
- **Kẻ Gác:** **Chúa Tể Băng Giá** (Frost Lord; trước 2026-11-01 là Chúa Tể Sương).
- **Màu [Khởi điểm]:** trắng băng, lam nhạt, tím lạnh.

### Đầm Lầy Độc (The Poison Swamp)
- **Không khí:** *"Hơi độc bốc lên từ bùn đen. Mỗi bước chân chìm sâu hơn bước trước."*
- **Mạng lưới:** lối đá chìm nửa trong bùn.
- **Địa hình:** **ô lầy** làm chậm bước và rút máu.
- **Quái:** chuột lầy, sên bùn, thằn lằn đầm, cóc đầm, phù thủy lau sậy, chó săn đầm, nấm bào tử, ếch nhảy.
- **Kẻ Gác:** **Cóc Chúa**.
- **Màu [Khởi điểm]:** xanh độc, nâu bùn, tím nấm.

### Sa Mạc Cát Vùi (The Buried Sands)
- **Không khí:** *"Gió nóng cuốn cát qua những cồn đá cổ. Cát nuốt từng ô đất dưới chân."*
- **Mạng lưới:** quảng trường cổ bị cát vùi, chỉ lộ một phần.
- **Địa hình:** **cát lấp ô** (ô tạm mất), **gió đẩy khối** trôi lệch.
- **Quái:** chó rừng cồn, bọ cát, du mục bụi, bóng ảo ảnh, vệ binh bọ hung, xạ thủ mặt trời, bọ cát ẩn, bọ cạp phản.
- **Kẻ Gác:** **Nhân Sư Cát**.
- **Màu [Khởi điểm]:** vàng cát, cam nắng, xanh ngọc cổ.

### Thành Hỏa Ngục (The Hellfire Citadel)
- **Không khí:** *"Dung nham sôi dưới những bức tường cháy đen. Mạch lửa phun lên theo từng nhịp đập của thành."*
- **Mạng lưới:** sàn thành, giữa các ô là mạch dung nham.
- **Địa hình:** **mạch dung nham** (cảnh báo rồi phun cả hàng hoặc cột), ô cháy.
- **Quái:** tiểu quỷ, chó than hồng, khôi tro, tín đồ lửa, sên dung nham, hiệp sĩ địa ngục, quỷ nuốt lửa, phượng tro.
- **Kẻ Gác:** **Chúa Quỷ Lửa**.
- **Màu [Khởi điểm]:** đen than, cam-vàng dung nham, cam lửa (không dùng đỏ: đỏ dành cho báo đòn, xem `design/art/art-bible.md`).

### Không Đảo (The Sky Isles)
- **Không khí:** *"Những hòn đảo trôi giữa gió lộng, nối nhau bằng những nhịp cầu mong manh. Đứng lâu một chỗ, đất sẽ rơi."*
- **Mạng lưới:** đảo đá nổi, mỗi đảo là một cụm ô, nối bằng cầu.
- **Địa hình:** **ô nứt rồi rơi** khi đứng lâu, rồi mọc lại sau một lúc.
- **Quái:** tinh mây, điểu nữ, võ tăng gió, đại bàng bão, lính gác trời, pháp sư sấm, chim gió, thần mây.
- **Kẻ Gác:** **Long Vương Gió**.
- **Màu [Khởi điểm]:** trời xanh, trắng mây, vàng sấm.

### Tâm Lưới (The Lattice Heart), trận cuối
- **Không khí:** đỉnh của Tessera, nơi Biến Cố bắt đầu. Mạng lưới ở đây lộ trần, gọn và sáng nhất. Yên tĩnh, trang nghiêm.
- **Sân:** hình bậc đài, mỗi ô là một phiến đá khắc.
- **Kẻ giữ:** **Người Giữ Tâm Lưới**. Trận có 2 pha, biểu ngữ pha 2 là "Tâm Lưới bừng sáng".
- **Hình ảnh theo kết thúc [Khởi điểm]:**
  - **Lòng Tha Thứ:** ánh sáng ấm.
  - **Cán Cân:** Tâm Lưới vỡ đôi, một nửa sáng, một nửa tối.
  - **Lưỡi Kiếm Lạnh:** ánh sáng lạnh, lưới cúi rạp.

---

## 6. Năm nhân vật

Mỗi nhân vật phải có **bản sắc riêng ngay từ trận đầu**: dáng hình, màu và cả **chất liệu khối** của họ. Lý do là thao tác chính của game là nhặt và đặt khối, nên khối của mỗi người phải trông khác nhau. Họ đều từng dùng sức mạnh theo cách cũ trước Biến Cố, nên có thể kể ngắn cách mỗi người thích nghi. Không có "lớp": lá nào cũng dùng chung, nhân vật chỉ nghiêng về một hướng qua bộ khởi đầu và Thức Tỉnh.

| Nhân vật | Lối chơi (theo dữ liệu) | Thức Tỉnh | Hình ảnh [Khởi điểm] | Chất liệu khối [Khởi điểm] |
|---|---|---|---|---|
| **Kiếm sĩ** | Bền, 200 máu, đòn sát thương cao, hồi 20 máu sau trận thắng | Vung Hết Sức: trong 3 s mọi phép tính gấp đôi số ô, hút 20 % sát thương | Hiệp sĩ giáp thép, kiếm lớn, dáng vững | **Thép**: khối như phiến kim loại, in xuống thành vết chém sáng |
| **Pháp sư** | 210 máu, phép diện rộng, Cháy | Bùng Nổ: kích nổ lửa đang cháy, đốt cả nửa lưới đã khắc | Pháp sư áo nâu than nhấn hổ phách, sách hoặc gậy, dáng gầy | **Than lửa**: khối thân tối nứt hổ phách, để lại tàn lửa |
| **Sát thủ** | Nhanh, 180 máu, đòn nhỏ (≤ 4 ô) mạnh hơn 40 %, Đóng Băng | Bóng Lướt: trong 2 s bước không chờ, đòn ≤ 3 ô ×1,75 | Kẻ cắp hoặc sát thủ đôi dao, áo đen | **Băng sắc**: khối nhỏ, trong, cạnh nhọn |
| **Thợ săn** | 200 máu, rải Bãi Gai và bẫy chông, làm boss **Rạn**. Mở khóa khi đã **giết** 3 Kẻ Gác | Bẫy Sập: Bãi Gai kéo dài ×1,5 và rải thêm 1 ô, tiêu Rạn ×2 | Ranger áo da, nỏ, móc bẫy | **Gỗ và dây**: khối như khung bẫy |
| **Giáo sĩ** | Bền, 210 máu, xây bộ **Giá Lạnh**; mỗi lần Giá Lạnh nổ trên boss thì hồi 8 máu. Mở khóa khi đã **tha** 3 Kẻ Gác | Ban Phước: mỗi đòn trúng thêm 1 tầng Giá Lạnh, nổ ×1,5 | Cleric áo trắng bạc, biểu tượng thánh trước ngực | **Kính thánh**: khối như kính màu phát sáng |

**Gợi ý lý do lên đường** (để viết chữ sau, không bắt buộc cho asset):
- **Kiếm sĩ:** mất khả năng vung kiếm tự do sau Biến Cố, muốn tìm lại nó.
- **Pháp sư:** muốn hiểu quy tắc mới.
- **Sát thủ:** được thuê lấy một Mảnh Gốc.
- **Thợ săn:** săn những Kẻ Gác.
- **Giáo sĩ:** muốn hàn gắn thế giới.

---

## 7. Từ khóa trạng thái (cần đọc ra ngay)

| Từ khóa | Nghĩa trong game | Màu [Khởi điểm] |
|---|---|---|
| **Cháy** | Ô cháy, đứng trong mất máu dần | Cam lửa |
| **Đóng Băng** | Đứng im 1,2 s | Xanh băng nhạt |
| **Rạn** | Vết nứt, đòn kế tiếp ăn ×1,5 | Ngà, có đường nứt màu Mực |
| **Giá Lạnh** | Tích tầng lạnh rồi nổ | Lam đậm |
| **Ô rớt** (chỉ boss) | Ô nứt 0,8 s rồi rơi thành hố không bước vào được; ai còn đứng trên lúc rơi thì rơi chết; hết hạn ô hiện lại | Vết nứt lan + đỏ đậm dần như ô báo đòn; hố tối; ô hiện lại từ trắng |
| **Bãi Gai** | Bước vào được nhưng mất máu hoặc dính Rạn | Phải **khác hình hẳn** với ô rớt |

Màu nhân vật và màu vùng nên tránh trùng các màu này, để trạng thái luôn nổi bật.

---

## 8. Ràng buộc cho artist (từ cơ chế)

**Màn hình và trận đấu**
- Ngang **1280×720**, chơi bằng cảm ứng trên điện thoại.
- Hai lưới đối diện: người chơi bên trái, địch bên phải. Sân rộng 3×3 trở lên, có thể có lỗ, có đảo, có hình vòng hoặc kim cương.
- Mỗi nhân vật và mỗi quái **đứng gọn trong một ô**. Ô nhỏ nhất (sân 5×5) khoảng **77 × 55 px**, ô sân 3×3 khoảng 129 × 92 px (ước tính, xem `design/ux/hud.md`). **Art phải đọc được ở ô 55 px cao**, nhận ra được **bằng dáng hình**.
- Màn chọn nhân vật cần thêm **chân dung riêng**.

**Animation nhân vật**
- Đứng chờ (idle).
- **Bước một ô:** rất nhanh, 0,18–0,6 s mỗi bước.
- **Niệm:** **nhân vật vẫn đi được khi đang niệm**, nên niệm không khóa tư thế: một cử chỉ ngắn ~0,2 s rồi đi lại tự do; trạng thái niệm hiện ở ô đích trên đất địch (`design/art/art-bible.md` Mục 3). Thời gian niệm 0,2 s + 0,25 s mỗi ô.
- Bị trúng đòn. **Bị phá phép**: khối vỡ.
- Bị đẩy lùi, bị Đóng Băng, bị Cháy.
- **Rơi khỏi đảo** (Không Đảo), và rơi xuống hố của Ô rớt.
- **Thức Tỉnh:** mỗi nhân vật một kiểu riêng.
- Thắng và thua cuối trận.

**Animation boss và quái**
- Đứng chờ, bước.
- **Tư thế niệm đứng yên**: đây là cửa sổ phản công, phải rất dễ thấy.
- Trúng đòn, bị phá phép.
- **Gục**: Kẻ Gác gục trước màn Tha/Giết.
- Riêng Người Giữ Tâm Lưới: chuyển pha.
- Một số đặc tính cần hình riêng: hồi sinh (phượng tro), nuốt lửa, che dự báo (thần mây), làm rơi đảo (Long Vương Gió).

**Khối: trung tâm của art direction**
- 19 hình, 1–5 ô (một số mở khóa dần), xoay được, không lật.
- Cần hình cho từng trạng thái:
  - **Rơi** xuống lưới.
  - **Nằm** trên đất (thu nhỏ, không có chữ).
  - **Trong túi khối** (tối đa 3).
  - **Ô sáng khi kéo:** màu khối của nhân vật; trúng = viền liền + ✓, trượt = viền nét đứt + ✗ (`design/art/art-bible.md` Mục 3).
  - **In lên đất địch.**
  - **Vỡ** khi bị phá phép.
  - **Tan** khi hết hạn.

**Hiệu ứng trên sân**
- Cảnh báo đòn địch: ô đỏ trên đất mình.
- **Bản Khắc:** ô sáng rồi phai.
- **Hình Cộng Hưởng** của sân (5–7 ô): hiện nhỏ trên HUD, cộng hưởng khi ghép đúng.
- Ô cháy, ô lầy, ô cát lấp, mạch dung nham (cảnh báo rồi phun), ô nứt rồi rơi.
- Ô rớt (nứt, thành hố, hiện lại), Bãi Gai.

**Hiện trạng:** toàn bộ hình trong game vẫn là **ô màu và hình tròn tạm**. Phong cách đã chốt trong `design/art/art-bible.md` (mục 1–4, 2026-10-28): pixel art theo tinh thần One Step From Eden.

---

## 9. Tóm tắt tiếng Anh (cho công cụ tạo hình)

> **Tessera** was an ordinary high-fantasy world until **the Cataclysm**: the **Primal Form** that shaped every land shattered at the **Lattice Heart**, and a lattice of squares spread across the world. Since then, all power — magic, swordplay, any technique — only works when channeled through **shapes made of square tiles** (1–5 tiles, like tetrominoes). Everyone, heroes and monsters alike, picks up glowing **blocks** that fall on their side of the lattice, rotates them and stamps them onto the enemy's half to strike. Every land sits on its own lattice laid over its old terrain: overgrown ruins in a misty forest, a dungeon floor with collapsed pits, an ice tower, half-sunk stones in a poison swamp, a sand-buried plaza, a citadel floor split by lava veins, and floating sky islands joined by bridges. Each land is guarded by a **Warden** who holds a shard of the Primal Form. Heroes climb a great mountain through five lands to the Lattice Heart at the summit, choosing to spare or slay each Warden. Tone: Western fantasy, quiet, melancholic, readable; not wuxia. Five heroes: a steel knight (steel blocks), a fire mage (ember blocks), a fast dagger rogue (sharp ice blocks), a trap-setting ranger (wood-and-rope blocks), a silver cleric (stained-glass blocks). Landscape mobile game; characters must read at about 55 px tall inside one grid tile (the smallest arena), up to about 90 px in the largest tiles.

---

## 10. Còn mở

1. **Phong cách hình:** **Đã chốt** (2026-10-28): pixel art kiểu One Step From Eden, chỉ lấy góc nhìn của OSFE: lưới phẳng, đơn vị đứng thẳng cao ~40 px (khung 32×48), nền nhìn ngang có chân trời; chiến trường 640×360. Xem `design/art/art-bible.md`.
2. **Áp thuật ngữ vào game:** **Đã xong** (kiểm 2026-11-01): chữ trong `strings.csv` theo `design/glossary.md` (nhóm 1–4).
3. **Tên riêng, nhóm 5 của glossary:** **Đã chốt** (2026-10-29, Story 043): lá, Thức Tỉnh, bảo vật, đặc tính boss, nội tại. Xem `design/glossary.md` nhóm 5.
4. **Chữ cần viết lại theo lore:**
   - Lời vào và lời kết của Tâm Lưới (đang "(Tạm)").
   - Lời vào và lời kết của Rừng Sương (chưa có).
   - Câu "Phía trên, màn sương đang chờ" của Hầm Ngục.
   - Ba đoạn kết có nhắc Ấn Đài.
5. **Nguyên nhân Biến Cố:** để ngỏ có chủ đích.
6. **Hình của từng Mảnh Gốc** và biểu tượng bảo vật: hiện chỉ là chữ cái trong ô vuông.
