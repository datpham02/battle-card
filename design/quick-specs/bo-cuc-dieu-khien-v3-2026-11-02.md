# Quick Design Spec: Bố cục điều khiển v3 (hai ngón cái, khung góc cạnh)

**Type**: Tweak
**System**: HUD trong trận, đặt khối, chọn lá
**GDD Reference**: `design/ux/hud.md`; `design/quick-specs/control-layout-v2.md` (thay phần bố cục); `design/quick-specs/menu-la-giua-man-hinh-2026-11-01.md` (giữ luồng)
**Date**: 2026-11-02
**Người dùng chốt**: 2026-11-02, qua các hình phác trong hội thoại — "oke làm control như vầy đi"
**Trạng thái**: Đã duyệt

## Quy tắc chung
- **Hình góc cạnh** (vát góc, thoi, lục giác…), không hình tròn; **ngoại lệ duy nhất: cần điều khiển**.
- **Chữ hiệu ứng không có khung** (cộng hưởng, dự báo trúng, NGẮT!…): chữ tự nổi bằng màu (vàng cho hiệu ứng có lợi), viền mực dày, bóng nhẹ, to hơn chữ thường, nảy nhẹ khi hiện.
- Nút và bảng dùng khung đá pixel đã có (`PixelFrame`, `UiButtons`, họ khung lá bài cổ).

## Lúc di chuyển
- **Góc trên trái — chỉ bảo vật và buff/debuff:** hàng trên icon bảo vật; hàng dưới icon trạng thái đang có trên nhân vật (Trói, Chậm, Guard, Cháy, Rạn, Đóng Băng, Giá Lạnh…), mỗi icon có quạt thời gian còn lại quay theo kim đồng hồ trong khung góc cạnh; chạm để xem tác dụng.
- **Góc trên phải:** vàng (icon góc cạnh, ví dụ lục giác) rồi **nút tạm dừng sát góc**.
- Bỏ chip "Resonant shape / Cộng hưởng" và "Deck: N". Dòng tiêu đề "Floor 1/5 · …" chỉ hiện ở bản phát triển.
- **Dưới trái:** cần điều khiển (như hiện tại).
- **Dưới giữa:** nút Thức Tỉnh (hình thoi) + số Bản Khắc.
- **Dưới phải:** **túi khối gọn** — 3 ổ đá vát góc 64×64 px (720p) thẳng hàng, cùng đáy; trong ổ chỉ có hình khối, số ô nhỏ ở góc; ổ đang chọn viền vàng; túi đầy viền hổ phách.

## Lúc đặt khối
- **Dưới trái (ngón cái trái, thay chỗ cần điều khiển):** hàng `[Tung phép] [Xoay] [Hủy]`, cùng cao 64 px, cùng đáy; Tung phép 100 px rộng sát góc, chữ vàng; Xoay vuông 64 px với mũi tên xoay vàng; Hủy 72 px. Xoay đứng giữa làm vùng đệm giữa hai nút trái nghĩa.
- **Thời gian (3 s đặt khối, Tập trung):** **ngòi vàng cháy quanh viền nút Tung phép** theo chiều kim đồng hồ; đầu ngòi là một hình thoi sáng nhỏ. Bỏ các thanh rời.
- Tung phép chỉ hiện khi đang đặt khối.
- **Dưới phải (ngón cái phải):** chỉ túi khối (đang kéo khối lên sân).
- Thức Tỉnh ẩn khi đặt khối.
- Bỏ cụm "FULL / N ô / sát thương" ở dưới; số ô và sát thương chỉ hiện trên sân cạnh bóng khối, **không khung**.
- **Cộng hưởng tự tính** khi các khối đặt xuống trùng hình: bóng khối chuyển vàng + chữ "Cộng hưởng ×1,5 · N ô · −X" (không khung). Hình cần ghép hiện một lần ở băng giới thiệu đầu trận cạnh tên sân.

## Lúc chọn lá
- Giữ luồng hiện tại (lớp xám nhìn xuyên, 4 lá giữa màn hình).
- **3 giây chọn lá = ngòi vàng chạy quanh khung bao 4 lá** (thay thanh ngang).
- **Hủy** ở góc dưới trái (chỗ Tung phép).
- **Cột hồi chiêu** dời xuống dưới hàng buff/debuff ở mép trái.

## Acceptance Criteria
- [ ] Không còn hình tròn nào trong HUD trừ cần điều khiển.
- [ ] Không còn chữ hiệu ứng nào nằm trong khung.
- [ ] Góc trên trái chỉ có bảo vật và buff/debuff; buff/debuff hiện đúng trạng thái đang có và thời gian còn lại.
- [ ] Góc trên phải: vàng bên trái, tạm dừng sát góc.
- [ ] Lúc đặt khối: Tung phép / Xoay / Hủy ở dưới trái cùng hàng 64 px; túi khối dưới phải; ngòi vàng chạy đúng thời gian đặt khối và Tập trung.
- [ ] Lúc chọn lá: ngòi quanh khung 4 lá; Hủy dưới trái; cột hồi chiêu dưới hàng buff.
- [ ] Mọi vùng chạm ≥ 64 px ở 720p (ngón cái); không chồng lên sân.
- [ ] Ảnh 1280×720 giữ lại cho cả 3 trạng thái, tiếng Việt và tiếng Anh (`production/qa/evidence/controls-v3/`).
- [ ] Không hồi quy: luồng đặt khối / ghép / chọn lá / Tập trung / Thức Tỉnh.

## GDD Update Required?
Có — `design/ux/hud.md` (Z1, Z3, Z4, Z5, E-13, E-42), ghi chú thay thế trong `design/quick-specs/control-layout-v2.md`.
