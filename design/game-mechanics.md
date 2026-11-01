# Cơ chế game Tessera

> **2026-10-27, cập nhật tên 2026-11-01.** Mô tả cơ chế **đang chạy trong game** sau 40 story, viết bằng thuật ngữ của `design/glossary.md`. Bối cảnh thế giới: `design/world-context.md`.
> Đây là bản tóm tắt dễ đọc. Luật chi tiết và lịch sử quyết định nằm ở `design/game-brief.md`; mọi con số nằm trong `assets/data/*.json` và là **số khởi điểm**, chỉnh lại được sau buổi chơi thử.
> Tên riêng của lá, Thức Tỉnh, bảo vật, nội tại và đặc tính boss dưới đây là **tên trong game** (`assets/i18n/strings.csv`, cột `vi`; bảng đối chiếu vi/en ở `design/glossary.md` nhóm 5).
> **Kế hoạch, chưa có trong game:** bản đồ v2, địch có đòn đặc trưng, Kẻ Gác 3 pha và hệ lá v2 lấy nguồn từ `docs/architecture/adr-0001-tessera-design-pack-alignment.md` và bộ thiết kế `TESSERA_CLAUDE_DESIGN_PACK/tessera_claude_pack`. Tài liệu này chỉ tả bản đang chạy; mục nào đổi thì cập nhật khi pha tương ứng xong.

---

## 1. Game trong một đoạn

Đấu thời gian thực trên hai nửa lưới đối diện, bạn bên trái, địch bên phải. **Khối** hình 1–5 ô rơi xuống nửa của bạn. Bạn chạy tới nhặt, rồi **đặt khối lên đúng chỗ bạn đoán địch sẽ đứng**, chọn một **lá phép** để quyết định khối thành đòn gì, rồi **tung phép**. Khối càng to thì đòn càng mạnh nhưng niệm càng lâu, và ai chạm trước thì phá đòn của người kia. Mỗi **chuyến leo**, bạn chọn một nhân vật, đi qua **5 tầng vùng đất** (mỗi tầng chọn 1 trong 2 vùng) tới **Tâm Lưới**. Trên đường bạn nhặt lá, bảo vật, khối mới, và **tha hay giết** từng Kẻ Gác. **Chết là hết chuyến leo.**

**Vòng chơi:**
1. **Chọn nhân vật** và mức Giao Kèo.
2. Mỗi tầng: **chọn vùng**, đi 3 chặng (trận, nhánh rẽ, Kẻ Gác), nhận thưởng sau mỗi nút.
3. Hạ Kẻ Gác, chọn **Tha hoặc Giết**.
4. Sau tầng 5: **Tâm Lưới**, gồm cửa hàng rồi trận cuối.
5. **Kết thúc** theo số Kẻ Gác đã tha hoặc giết.
6. Mở khóa nội dung mới và bậc Giao Kèo kế tiếp, rồi bắt đầu chuyến leo sau.

---

## 2. Trận đấu

### 2.1 Sân và di chuyển
- Hai nửa lưới đối diện, mỗi bên chỉ đi trong nửa của mình. **Kích thước và hình sân là dữ liệu**: 3×3 trở lên, có thể có ô thiếu, đảo, vòng, kim cương. Có 19 hình sân trong `arenas.json`, kèm biến thể ngẫu nhiên có kiểm tra.
- Di chuyển bằng **nút 4 hướng**, mỗi lần một ô, không xếp hàng lệnh.
- **Hồi bước theo kích thước sân:** `0,45 × (2 / (max(cột, hàng) − 1)) ^ 0,75` giây, kẹp trong [0,18; 0,60]. Sân to thì bước nhanh hơn.
- Bước lên ô có khối là nhặt khối đó.

### 2.2 Khối rơi
- **Bộ khối** của bạn gồm 19 hình chuẩn 1–5 ô: ô đơn; thanh 2; thanh 3, L nhỏ; vuông, T, L, J, S, Z, thanh 4; chữ thập, U, P, Y, N, V, bậc thang, thanh 5. Một số hình mở khóa dần.
- Mỗi hình có trọng số rơi. Đầu trận có sẵn **1 khối**; sau đó **3 giây rơi một khối** vào ô trống ngẫu nhiên bên bạn, hướng xoay ngẫu nhiên.
- Trên sân có **tối đa 3 khối**. Khối không nhặt sẽ **tan sau 8 giây**.
- Hình nào không đặt vừa đất địch ở trận này thì không rơi.
- **Túi khối giữ tối đa 3 khối.**
- **Khối Lạ (Story 041).**
  - Khoảng 12 % khối rơi sẽ là hình ngẫu nhiên ≥ 5 ô, không trùng 19 hình của bộ khối.
  - Cỡ tối đa theo số ô đất đích: `số ô ÷ 4 + 3`, giới hạn 4–7. Sân 9 ô tối đa 5, sân 12 ô tối đa 6, sân 17 ô trở lên tối đa 7.
  - Cả hai bên đều nhận, dùng mọi luật của khối thường.
  - Không thuộc bộ khối.

### 2.3 Đặt khối và tung phép
1. **Chọn khối** trong túi (chạm hoặc kéo) để vào chế độ đặt.
   - Nếu **Tập trung** sẵn sàng thì trận **dừng hẳn** tối đa 4 giây (Pháp sư 5 giây, Giáo sĩ 4,5 giây), hồi 8 giây.
   - Nếu chưa, trận **chậm còn 0,2×**.
2. **Bóng khối** đi theo ngón tay và hít vào lưới đất địch. Chỉ đặt được khi **mọi ô** của khối nằm trên ô thật. **Xoay 90°** bằng cách chạm lại vào khối; không lật được.
3. **Báo trúng:** bóng khối **xanh** nếu ô địch đang đứng nằm trong khối, **đỏ** nếu không. Số ô và sát thương dự kiến hiện cạnh bóng.
4. Thả khối thì **chưa hiện lá nào**; nút **Tung phép** hiện ra. Từ lúc thả khối đầu có **3 giây** (`cuts.json` `place_window_sec`) để ghép thêm khối (mục 2.4) và bấm Tung phép; hết giờ thì tự Tung phép.
   - Bấm Tung phép: **lớp xám nhẹ nhìn xuyên được** phủ cả màn hình, **4 lá** rút từ bộ bài theo túi xáo hiện **ở giữa màn hình**; có **3 giây** để chọn, trận chậm 0,2×.
   - Hết giờ thì tự dùng đòn chém cơ bản.
   - Lá chưa đủ số ô hiện "cần N ô". Lá đang hồi chiêu tối đi, có quạt đen quay theo kim đồng hồ và số giây, không chọn được.
   - Lá vừa dùng có hồi chiêu: icon vào **cột mép trái màn hình** với quạt đen quay theo kim đồng hồ (kiểu Liên Minh Huyền Thoại); hồi xong thì rời cột. Spec: `design/quick-specs/menu-la-giua-man-hinh-2026-11-01.md`.
5. **Tung phép.** Đòn bắt đầu **niệm**:
   - **Thời gian niệm** = 0,2 s + 0,25 s × tổng số ô.
   - **Đang niệm vẫn đi được.** Mỗi bên chỉ có một đòn đang niệm.
   - **Sát thương** = sát thương mỗi ô của lá × tổng số ô, rồi nhân bảo vật, nội tại, từ khóa.
6. **Phá phép:** đòn nào chạm ô đối thủ trước thì **hủy đòn đang niệm của đối thủ**, và khối của bên bị hủy mất luôn.

### 2.4 Ghép khối và Hình Cộng Hưởng
- **Trước khi bấm Tung phép**, kéo thêm **một khối** nữa lên đất địch để **ghép** vào cùng đòn. Khi 4 lá đã hiện thì không ghép thêm được nữa. Hai khối không được chồng ô; chạm cạnh hay rời nhau đều được. Tối đa 2 khối mỗi đòn, 3 khối nếu có bảo vật Xích Ba Mắt.
- Mỗi sân có một **Hình Cộng Hưởng** 5–7 ô gợi dáng sân, hiện nhỏ trên HUD. Đòn **2 khối** có tổng ô trùng hình này (xoay được, không lật) được **×1,5 sát thương** cộng **một hiệu ứng theo chủ đề sân**: Rạn, Đóng Băng, Cháy hoặc Giá Lạnh.

### 2.5 Bản Khắc và Thức Tỉnh
- Mỗi đòn của bạn chạm đất địch, dù trúng hay trượt, làm **sáng** các ô nó phủ.
- Ô sáng **phai** sau `5 s + 0,8 s × số ô đất địch` (sân 3×3 khoảng 12 giây).
- **Mọi ô cùng sáng** là Bản Khắc hoàn thành. Khi Bản Khắc hoàn thành **và** đã hết thời gian hồi, kỹ năng riêng của nhân vật **Thức Tỉnh** sẵn sàng (xem mục 4).

### 2.6 Từ khóa trạng thái

| Từ khóa | Hiệu ứng | Số |
|---|---|---|
| **Cháy** | Ô cháy, đứng trong mất máu dần; chặn đường | Chồng tối đa 3 tầng, mỗi tầng kéo dài thêm 2 s |
| **Đóng Băng** | Đứng im | 1,2 s |
| **Rạn** | Đòn kế tiếp ăn ×1,5 | Tối đa 3 tầng |
| **Giá Lạnh** | Tích tầng, đủ thì nổ | 3 tầng nổ, gây 24 sát thương |
| **Đẩy** | Đẩy lùi 1 ô kèm sát thương nhẹ | — |
| **Ô rớt** (chỉ boss, thay Tường từ 2026-10-31) | Ô nứt 0,8 s rồi thành hố không bước vào được; ai còn đứng trên lúc rơi thì rơi chết | nứt 0,8 s, hố 1,2 s |
| **Bãi Gai** | Bước vào được nhưng mất máu và dính Rạn | 3 s, 6 sát thương, +1 Rạn |
| **Hành quyết** | Sát thương nhân thêm khi địch dưới 25 % máu | — |
| **Xuyên giáp** | Bỏ qua giáp của địch | — |

Luật công bằng cho Ô rớt (`design/quick-specs/o-rot-thay-tuong-2026-10-31.md`): lúc bắt đầu nứt luôn còn ít nhất 1 ô kề an toàn; ô của người chơi chỉ được chọn khi người chơi bước kịp (hồi bước còn ≤ 0,6 s, không Đóng Băng, không bị trói); Đóng Băng giữa chừng thì ô dưới chân không rơi; Tập trung dừng đồng hồ nứt. Bãi Gai vẫn bước được nên không cần luật này.

Mỗi ô một hiệu ứng (`design/quick-specs/mot-o-mot-hieu-ung-2026-11-01.md`):
- Một ô chỉ giữ 1 hiệu ứng vùng (Cháy, Bãi Gai, Ô rớt); phép mới thay cái cũ với thời lượng đầy đủ, cùng loại thì làm mới. Địa hình của vùng và trạng thái trên người không tính.
- Ô đang nứt hoặc đã là hố là ô khóa: không phép nào tác dụng lên ô đó (không sát thương, trạng thái hay hiệu ứng vùng) cho tới khi ô hiện lại; ô vừa nứt thì mất màu cảnh báo đỏ ngay.

### 2.7 Địa hình vùng

| Vùng | Địa hình |
|---|---|
| Đầm Lầy Độc | **Ô lầy**: bước chậm ×1,6, mất 0,5 máu mỗi 0,5 s |
| Sa Mạc Cát Vùi | **Cát lấp**: mỗi 6 s có 2 ô bị lấp trong 3 s, có cảnh báo 0,8 s. **Gió** đổi hướng mỗi 8 s, đẩy khối trôi lệch |
| Thành Hỏa Ngục | **Mạch dung nham**: mỗi 7 s, cảnh báo 1 s rồi phun cả hàng hoặc cột trong 2 s, đốt 2 máu mỗi 0,5 s và cháy khối trên đó |
| Không Đảo | **Ô nứt** (chỉ nửa sân người chơi, người dùng chốt 2026-11-01; nửa sân boss không sụp): đứng lâu 2 s thì nứt, cảnh báo 0,6 s, rồi rơi trong 4 s. Ai đứng trên ô rơi bị đẩy sang ô kề và mất 8 máu. Luôn chừa đường ra khỏi đảo |

### 2.8 Địch và boss
- Địch dùng **cùng hệ khối**: nhặt và đặt khối lên đất bạn. Bộ não của địch chấm điểm khối, vị trí và hướng xoay theo đường thoát của bạn.
- **Cảnh báo:** ô sắp bị đánh hiện **đỏ** trên đất bạn kèm thời gian niệm. Né ra khỏi vùng đỏ là thoát.
- **Địch đứng yên khi đang niệm.** Đây là **cửa sổ phản công**: đánh trúng lúc này để phá đòn của nó.
- **Đặc tính** làm mỗi trận khác nhau, hiện có khoảng 20:
  - **Thời gian:** Ngòi Nổ (ngòi cháy hết thì nổ cả hàng), Dây Vướng (mỗi bước của bạn nạp một phát), Cùng Đường (nửa máu thì hung hãn hơn).
  - **Sân:** Nứt Đất (đập nứt ô bên bạn), Hàng Lửa (thở lửa quét một hàng), Ném Đồ Hỏng (ném khối độc vào túi bạn), Chặn Lối (làm nứt rồi rơi 2–3 ô bên bạn thành hố, có thể gồm ô bạn đứng), Gai Níu Chân (rải Bãi Gai).
  - **Hồi sinh và hồi máu:** Sương Nặng (khối rơi chậm hơn), Ăn Lửa (Cháy hồi máu cho nó), Sống Lại (hồi sinh một lần trừ khi đang dính Giá Lạnh).
  - **Theo vùng:** Mạch Phun Đôi, Gió Tạt, Che Tầm Ngắm (giấu báo trúng), Đảo Rơi, và các chiêu lặn, nhảy, phản đòn của Sa Mạc và Đầm Lầy.
- **Thắng:** địch về 0 máu. **Thua:** bạn về 0 máu, chuyến leo kết thúc.

---

## 3. Lá phép và bộ bài

- **Bộ bài** là danh sách lá, khởi đầu 6 lá, tối thiểu 4. Lá trùng được phép và làm lá đó ra thường hơn.
- **Không có "lớp":** lá nào cũng nằm trong pool chung.
- Mỗi lá có: **số ô tối thiểu**, **thời gian hồi**, **sát thương mỗi ô**, **độ hiếm** (Thường / Hiếm / Sử thi) và **3 cấp nâng**.
- **36 lá trong dữ liệu:** 34 lá thường và 2 lá nguyền; 3 lá Tường không còn tới tay người chơi (xem dòng Ô rớt). Gom theo hiệu ứng:

| Hiệu ứng | Lá |
|---|---|
| **Chém** (sát thương thuần) | Rạch nhẹ (cơ bản, bất kỳ ô, không hồi), Xé toạc, Lia ngang, Bổ nặng, Lưỡi sắc, Nêm sắt, Nhát cuối (Hành quyết), Rét cắt, Tuyết rơi, Buốt xương |
| **Đẩy** | Hích nhẹ, Xô lùi, Cú húc, Sạt lở |
| **Cháy** | Tia lửa, Tro hồng, Lò than, Lửa rừng, Giàn thiêu |
| **Đóng Băng** | Men băng, Mưa đá, Lặng yên, Tảng băng |
| **Rạn** | Nứt chân chim, Đứt gãy |
| **Giá Lạnh** | Rùng mình, Bão trắng, Sương bạc |
| **Ô rớt** | chỉ boss (đặc tính Chặn Lối); ba lá Tường Rào chắn, Lồng đá, Hàng cọc rời bộ lá người chơi từ 2026-10-31 |
| **Bãi Gai** | Bụi rậm, Dây úa, Bẫy chông |
| **Lá nguyền** | Gánh Nặng, Mối Hận: chiếm chỗ trong 4 lá rút, nhưng luôn còn ít nhất 1 lá thường |

Vài lá mở khóa qua thành tựu: Bẫy chông, Dây úa (thay Hàng cọc từ 2026-10-31), Sương bạc, Buốt xương.

---

## 4. Nhân vật

Mỗi nhân vật có máu, tốc độ bước, thời gian Tập trung, **nội tại**, **Thức Tỉnh** và **bộ khởi đầu** nghiêng về một hướng riêng.

| Nhân vật | Máu | Nội tại | Thức Tỉnh | Bộ khởi đầu | Mở khóa |
|---|---|---|---|---|---|
| **Kiếm sĩ** | 200 | Lấy Lại Sức: +20 máu sau mỗi trận thắng | **Vung Hết Sức**: 3 s, mọi đòn tính gấp đôi số ô, hút 20 % sát thương | Rạch nhẹ, Xé toạc ×2, Lia ngang ×2, Hích nhẹ | Có sẵn |
| **Pháp sư** | 210 | Tay Vững: đòn ≥ 4 ô niệm nhanh hơn 25 %; Tập trung 5 s | **Bùng Nổ**: kích nổ lửa đang cháy ×2, làm mới Cháy, đốt cả Bản Khắc đang sáng | Rạch nhẹ, Tia lửa, Tro hồng ×2, Lò than, Lặng yên | Có sẵn |
| **Sát thủ** | 180 | Nhát Gọn: đòn ≤ 4 ô +40 %; bước nhanh hơn 10 % | **Bóng Lướt**: 2 s, bước không chờ, đòn ≤ 3 ô ×1,75 | Rạch nhẹ ×2, Xé toạc, Lia ngang, Mưa đá, Rét cắt | Có sẵn |
| **Thợ săn** | 200 | Dấu Con Mồi: địch bước vào gai của bạn hoặc đứng kề gai vừa rải thì nhận 1 Rạn (chờ 3 s) | **Bẫy Sập**: 4 s, Bãi Gai kéo dài ×1,5 và rải thêm 1 ô, tiêu Rạn ×2 | Rạch nhẹ ×2, Bụi rậm ×2, Bẫy chông, Nứt chân chim | **Giết** tổng cộng 3 Kẻ Gác |
| **Giáo sĩ** | 210 | Lời Cầu Được Đáp: mỗi lần Giá Lạnh nổ trên địch thì hồi 8 máu; Tập trung 4,5 s | **Ban Phước**: 4 s, mỗi đòn trúng thêm 1 Giá Lạnh, nổ ×1,5 | Rạch nhẹ ×2, Rùng mình ×2, Rét cắt ×2 | **Tha** tổng cộng 3 Kẻ Gác |

---

## 5. Chuyến leo

### 5.1 Cấu trúc
- **5 tầng.** Mỗi tầng chọn **1 trong 2 vùng**, lấy ngẫu nhiên có seed từ pool, không lặp vùng đã đi trong chuyến leo.
- **Pool có 7 vùng:** Rừng Sương, Hầm Ngục, Tháp Sương, Đầm Lầy Độc, Sa Mạc Cát Vùi, Thành Hỏa Ngục, Không Đảo. Hai vùng cuối mở khóa khi lần đầu tới tầng 4 và tầng 5.
- **Mỗi vùng có 3 chặng:**
  - **Trận mở đầu.**
  - **Nhánh rẽ** 2–3 nút: trận, hiểm địa, tinh anh (từ tầng 2), kho báu, trại nghỉ, sự kiện, cửa hàng. Có ít nhất 3 cửa hàng mỗi chuyến leo, từ tầng 2.
  - **Kẻ Gác.**
- **Sau tầng 5:** **Tâm Lưới**, gồm một cửa hàng rồi trận với **Người Giữ Tâm Lưới** (2 pha).
- **Độ khó theo tầng, không gắn với vùng.** Cùng một vùng gặp ở tầng cao thì địch nhiều máu hơn, nhịp nhanh hơn, giáp dày hơn, đòn to hơn:

  | Tầng | Máu địch | Nhịp | Giáp | Đòn |
  |---|---|---|---|---|
  | 1 | ×0,7 | ×1,0 | +0 | +0 ô |
  | 2 | ×0,8 | ×0,95 | +0 | +0 ô |
  | 3 | ×0,85 | ×0,9 | +1 | +0 ô |
  | 4 | ×1,05 | ×0,85 | +1 | +0 ô |
  | 5 | ×1,15 | ×0,8 | +2 | +1 ô |
  | Tâm Lưới | ×1,25 (trên máu gốc 198) | ×0,8 | +2 | +1 ô |

- **Mang theo cả chuyến leo:** máu, bộ bài, bảo vật, vàng, bộ khối. Lưu ở mỗi nút, nên thoát giữa chừng rồi chơi tiếp được.

### 5.2 Hồi máu
- **Sang tầng mới:** hồi **60 %** máu tối đa.
- **Trại nghỉ:** chọn **Nghỉ** (hồi 30 % máu) hoặc **Rèn** (một lá +1 cấp).
- **Cửa hàng:** dịch vụ hồi 25 % máu. Một số nội tại và bảo vật cũng hồi máu.

### 5.3 Phần thưởng sau nút
- **Trận, hiểm địa:** chọn **1 trong 3 lá** (hoặc bỏ qua, hoặc nâng cấp một lá có sẵn) cộng vàng.
- **Tinh anh:** 3 lá từ Hiếm trở lên cộng vàng.
- **Kho báu:** miễn phí, chọn **1 lá hoặc 1 bảo vật**.
- **Kẻ Gác:** 3 lá cộng **1 lượt bỏ lá** cộng **1 lượt quên hình**, rồi tới màn Tha/Giết.
- **Độ hiếm trôi theo May mắn:** May mắn +1 mỗi nút. Tỉ lệ Thường/Hiếm/Sử thi đi từ 70/25/5 ở May mắn 0 tới 31/35/34 ở May mắn 70.
- **Học hình:** sau trận có 35 % cơ hội được chọn 1 trong 2 hình để **thêm vào bộ khối** hoặc làm hình đó rơi nhiều hơn (tối đa ×4).
- **Quên hình:** dùng lượt quên hình để bỏ một hình khỏi bộ khối. Bộ khối giữ tối thiểu 5 hình.

### 5.4 Tha hay Giết
- Hạ Kẻ Gác xong thì chọn:
  - **Tha:** không nhận gì thêm ngay lúc đó.
  - **Giết:** chọn **1 trong 2 bảo vật** từ Hiếm trở lên. Xác nhận bằng cách **giữ nút 0,6 s**.
- Cả hai lựa chọn vẫn nhận thưởng Kẻ Gác thường.
- **Kết thúc ở Tâm Lưới:**
  - **Lòng Tha Thứ:** tha tất cả.
  - **Lưỡi Kiếm Lạnh:** giết tất cả.
  - **Cán Cân:** còn lại.
- **Tổng số lần tha hoặc giết qua mọi chuyến leo** mở khóa Giáo sĩ (tha 3) và Thợ săn (giết 3).

### 5.5 Vàng, cửa hàng, sự kiện
- **Vàng:**
  - Bắt đầu với **20 vàng**.
  - Mỗi nút cho: trận 12, kho báu 15, hiểm địa 22, tinh anh 25, Kẻ Gác 35 (±20 %).
  - Nhân thêm theo tầng, từ ×1,0 tới ×1,4.
- **Cửa hàng:**
  - Bày 3 lá (30 / 40 / 60 vàng theo độ hiếm) và 2 bảo vật (50 / 70 / 90 vàng).
  - Ba dịch vụ, mỗi loại dùng một lần: **bỏ 1 lá** (60), **hồi máu 25 %** (40), **quên 1 hình** (45).
  - Giá tăng theo tầng, tối đa ×1,2.
- **Sự kiện:** 8 sự kiện là lựa chọn có rủi ro.
  - **Bàn thờ máu:** đổi máu lấy bảo vật.
  - **Kẻ buôn lá nguyền:** nhận lá nguyền để lấy lợi.
  - **Sòng bạc ven đường:** cược vàng.
  - **Lời thách đấu:** một trận khó hơn để lấy thưởng.
  - **Suối tĩnh:** hồi máu, hoặc mất máu để nâng một lá.
  - **Kẻ lang thang:** đổi bảo vật.
  - **Mộ hoang:** đào lấy vàng, có thể dính lá nguyền.
  - **Lời thề:** bước chậm 2 trận để nhận thưởng.

### 5.6 Bảo vật
Bảo vật là đồ bị động **đổi luật**, không chỉ cộng số. Mỗi bảo vật chỉ có một chiếc. Có **16 bảo vật**:

| Hạng | Bảo vật |
|---|---|
| **Thường** | Sỏi Lẻ (đòn chỉ gồm 1 khối ô đơn ×1,75), Chỉ Khâu (mỗi đòn ghép hồi 3 máu, tối đa 15 mỗi trận), Gai Dai (Bãi Gai +1 s, mở khóa qua thành tựu kết thúc Lòng Tha Thứ; thay bảo vật Tường cũ từ 2026-10-31), Đinh Cong (địch bước vào gai của bạn thêm 1 Rạn), Muối Ướp (khối tươi thêm 4 s), Đá Tĩnh Tâm (Tập trung +1 s) |
| **Hiếm** | Phấn Đánh Dấu (Bản Khắc phai chậm hơn 30 %), Nhang Trầm (Thức Tỉnh hồi nhanh hơn 20 %), Túi Rộng (túi khối +1 ô), Bình Nhựa Thông (Cháy chồng thêm 1 tầng), Cò Nhạy (đòn đầu mỗi trận không niệm), Dao Gạt Đòn (phá đòn địch thì nhận 1 khối ô đơn) |
| **Sử thi** | Băng Giòn (Giá Lạnh nổ ở 2 tầng nhưng yếu hơn 33 %), Xu Đánh Cược (đòn ≥ 5 ô +30 %; trượt thì mất 2 máu) |
| **Mảnh Gốc** (từ Kẻ Gác) | Âm Thoa (Hình Cộng Hưởng ×2 thay vì ×1,5), Xích Ba Mắt (ghép được khối thứ 3) |

---

## 6. Chơi lại và tiến trình

- **Chỉ mở thêm lựa chọn, không cộng sức mạnh vĩnh viễn.**
- **Mở khóa theo cột mốc:** lần đầu hạ Kẻ Gác, lần đầu tới tầng 4 hoặc tầng 5, lần đầu tới Tâm Lưới, lần đầu thắng, tổng số tha hoặc giết. Mỗi cột mốc mở nhân vật, lá, bảo vật, hình khối hoặc vùng mới. Nội dung vừa mở được báo ở màn "Mới mở".
- **24 thành tựu** theo vùng, nhân vật, lối build và kết thúc. Nhiều thành tựu thêm nội dung vào pool. Có thành tựu ẩn.
- **Giao Kèo (0–10):**
  - Thắng một chuyến leo ở bậc N thì mở bậc N+1 **cho nhân vật đó**.
  - Chọn bậc ở màn chọn nhân vật bằng thanh [−] [+]. Mặc định là bậc cao nhất đã mở, hạ xuống 0 được.
  - Các **điều khoản cộng dồn**: bậc 3 là chịu điều khoản 1, 2 và 3.

| Bậc | Điều khoản |
|---|---|
| 1 | Túi lép: vàng nhận −25 % |
| 2 | Trại nghèo: Nghỉ hồi ít hơn 33 % |
| 3 | Đường nguy: nút hiểm địa xuất hiện gấp đôi |
| 4 | Địch trưởng thành: địch mạnh như tầng kế; trận cuối +10 % máu |
| 5 | Giá cắt cổ: giá cửa hàng +20 %; boss cuối thêm 1 đặc tính |
| 6 | Vết thương dai: hồi máu khi sang tầng giảm một nửa |
| 7 | Thân mỏng: máu tối đa −15 % |
| 8 | Khối chậm: khối của bạn rơi chậm hơn 15 % |
| 9 | Boss nhanh tay: boss niệm nhanh hơn 10 % |
| 10 | Kẻ Gác hung hãn: Kẻ Gác thêm 1 đặc tính |

---

## 7. Trạng thái cân bằng (mô phỏng, Story 040)

Số dưới đây đo bằng bot mô phỏng (`tools/balance/deck_sim.gd`), **chưa neo bằng người thật**. Bot giả định né được 85 % đòn có cảnh báo.

| Chỉ số | Hiện tại | Mục tiêu |
|---|---|---|
| Tỉ lệ thắng chuyến leo (Giao Kèo 0) | Kiếm sĩ 44 %, Pháp sư 36 %, Sát thủ 43 %, Thợ săn 27 %, Giáo sĩ 47 % | 30–45 % mỗi nhân vật |
| Thắng trận cuối khi tới được | 54–75 % | 50–70 % |
| Thời lượng một chuyến leo thắng | khoảng 27–30 phút (bot) | 40–50 phút, chờ chơi thử |
| Đòn boss trúng mỗi chuyến leo thắng | 30–36 (bot) | 15–30, chờ chơi thử |
| Giao Kèo | bậc 4 tụt mạnh, bậc 7–10 gần như không thắng được | giảm đều, bậc 10 ≥ 3 % |

Việc còn mở: thang Giao Kèo cần chỉnh lại (TD-036), chính sách mua đồ của bot (TD-037), neo bot bằng buổi chơi thử (TD-006). Xem `docs/tech-debt-register.md`.

---

## 8. Chỉnh ở đâu

| Muốn chỉnh | File |
|---|---|
| Thời gian niệm, sát thương cơ bản | `assets/data/cuts.json` |
| Hồi bước, từ khóa, Bản Khắc, Ô rớt, Bãi Gai, địa hình | `assets/data/combat.json` |
| Khối rơi, túi khối | `assets/data/field_drops.json`, `hold_slots.json`, `pieces.json` |
| Lá phép | `assets/data/cards.json` |
| Nhân vật | `assets/data/characters.json` |
| Vùng, sân, địch, tầng, hồi máu, trận cuối, Tha/Giết | `assets/data/chapters.json`, `arenas.json` |
| Não địch | `assets/data/boss_brain.json` |
| Thưởng, May mắn, Học hình | `assets/data/rewards.json` |
| Vàng, cửa hàng | `assets/data/economy.json` |
| Sự kiện | `assets/data/events.json` |
| Bảo vật | `assets/data/relics.json` |
| Thành tựu, mở khóa | `assets/data/achievements.json` |
| Giao Kèo | `assets/data/kiep_levels.json` |
| Mọi chữ hiển thị (vi + en) | `assets/i18n/strings.csv` |
