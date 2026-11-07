# Accessibility Requirements

> **Status**: In Review
> **Author**: user + ux-designer
> **Last Updated**: 2026-10-28
> **Template**: Accessibility Requirements

## Accessibility Tier Definition

### Tier Definitions

| Tier | Core Commitment | Typical Effort |
|------|----------------|----------------|
| **Basic** | Critical player-facing text is readable at standard resolution. No feature requires color discrimination alone. Volume controls exist for music, SFX, and voice independently. The game is completable without photosensitivity risk. | Low — primarily design constraints |
| **Standard** | All of Basic, plus: full input remapping on all platforms, subtitle support with speaker identification, adjustable text size, at least one colorblind mode, and no timed input that cannot be extended or toggled. | Medium — requires dedicated implementation work |
| **Comprehensive** | All of Standard, plus: screen reader support for menus, mono audio option, difficulty assist modes, HUD element repositioning, reduced motion mode, and visual indicators for all gameplay-critical audio. | High — requires platform API integration and significant UI architecture |
| **Exemplary** | All of Comprehensive, plus: full subtitle customization (font, size, color, background, position), high contrast mode, cognitive load assist tools, tactile/haptic alternatives for all audio-only cues, and external third-party accessibility audit. | Very High — requires dedicated accessibility budget and specialist consultation |

### This Project's Commitment

**Target Tier**: **Standard**, adjusted for a touch-only game (user decision, 2026-10-28).

**Rationale**: Đây là roguelike thời gian thực trên điện thoại, chơi bằng cảm ứng. Rào cản lớn nhất nằm ở vận động và thời gian (kéo khối, hai ngón cùng lúc, đòn boss chạy theo đồng hồ) và ở thị giác (chữ nhỏ trên màn hẹp, cảnh báo dựa vào màu đỏ/xanh). Standard giải quyết cả hai: chỉnh cỡ chữ, chế độ mù màu, kèm các điều chỉnh cho cảm ứng (thuận tay trái, chạm thay cho kéo, cỡ điều khiển). Basic bỏ mất chế độ mù màu; với game có ô đỏ báo đòn là cơ chế sống còn, như vậy sẽ loại người chơi mù màu đỏ–xanh (khoảng 8 % nam giới). Comprehensive cần dựng lại toàn bộ giao diện (hiện là `Node2D` tự vẽ, không có `Control`) để dùng AccessKit; công sức lớn trong khi giao diện đang chờ art. Cam kết Standard làm kịp bằng phần lớn những gì `design/ux/hud.md` đã quyết.

**Cách áp dụng Standard cho game cảm ứng:**

| Cam kết của Standard | Áp dụng |
|---|---|
| Chữ đọc được, không chỉ bằng màu, không chớp sáng nguy hiểm | Đã có trong `design/ux/hud.md` |
| Cỡ chữ chỉnh được | 100 / 115 / 130 % |
| Ít nhất một chế độ mù màu | **Nội dung cần định lại** (2026-10-29): bóng khối đã đổi sang màu khối của nhân vật, trúng/trượt đọc bằng ✓/✗ và viền; sọc và hình biểu tượng giữ nguyên. Xem Open Questions |
| Âm lượng nhạc và hiệu ứng riêng | Khi game có âm thanh (hiện chưa có) |
| Không thao tác tính giờ nào không nới hoặc tắt được | **Chưa đạt (chấp nhận 2026-11-07):** thời gian chọn lá cố định 3 s, người dùng bỏ tùy chọn nới. Né đòn boss theo thời gian thực là bản chất game (Known Intentional Limitations) |
| Remap điều khiển | Không áp dụng (chỉ cảm ứng). Thay bằng thuận tay trái, cỡ điều khiển 90–110 %, chạm thay cho kéo |
| Phụ đề | Không áp dụng (không có thoại) |

**Features explicitly in scope (beyond tier baseline)**:
- **Giảm chuyển động**: vốn thuộc Comprehensive, nâng lên vì game có nhiều nhấp nháy và rung báo hiệu.
- **Thuận tay trái**: đảo pad và túi khối, vì điều khiển chia ngón trái/phải.
- **Rung thay cho âm cảnh báo**: vốn thuộc Exemplary; game chưa có âm thanh, cảnh báo hình là kênh chính, rung là kênh thứ ba.
- ~~**Nới thời gian chọn lá**~~: bỏ 2026-11-07 theo quyết định người dùng; menu luôn 3 s (xem Known Intentional Limitations).

**Features explicitly out of scope** (đều nằm trong Known Intentional Limitations):
- Trình đọc màn hình: giao diện chưa dùng `Control` nên AccessKit không áp dụng được.
- Chế độ tương phản cao.
- Tùy biến phụ đề: game không có thoại.
- Âm đơn: game chưa có âm thanh.
- Chế độ hỗ trợ độ khó: ảnh hưởng cân bằng, cần quyết định thiết kế riêng.
- Remap điều khiển: chỉ cảm ứng.
- Kiểm định bên ngoài.

---

## Visual Accessibility

Điều chỉnh bảng mẫu cho game điện thoại, độ phân giải tham chiếu 1280×720. **Specified** = đã quyết ở mức thiết kế (`design/ux/hud.md`), chưa dựng. Người dùng duyệt 2026-10-28.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---|---|---|---|---|
| Cỡ chữ tối thiểu, menu | Standard | Mọi màn menu | Specified | ≥ 24 px ở 720p |
| Cỡ chữ tối thiểu, HUD | Standard | HUD trận | Specified | Chữ cần hành động (đếm ngược, số ô, sát thương, nhãn lá, SẴN SÀNG, SẮP PHUN) ≥ 24 px; chữ phụ ≥ 18 px (`design/art/art-bible.md` 7.3) |
| Tương phản chữ | Standard | Mọi chữ | Specified | ≥ 4,5 : 1 chữ thường, ≥ 3 : 1 chữ lớn (≥ 18 px đậm). Nhãn đếm ngược, sát thương có viền để đọc được trên mọi địa hình. Đo bằng công cụ trên màu cuối cùng |
| Chế độ mù màu | Standard | Mọi thứ mã hóa bằng màu | Specified | **Chờ quyết định** (2026-10-29): bảng màu báo trúng xanh dương – cam không còn cần, vì bóng khối đã bỏ xanh lá – đỏ. Mọi tín hiệu còn lại đã có dấu không phụ thuộc màu (bảng kiểm bên dưới), nên Tritanopia được che bằng hình và chữ |
| Kiểm màu-là-tín-hiệu-duy-nhất | Basic | Toàn bộ | Specified | Bảng bên dưới |
| Cỡ chữ chỉnh được | Standard | Menu + HUD | Specified | 100 / 115 / 130 %. Không giảm dưới 100 % để giữ mức tối thiểu. Nhãn trên lưới tự thu nhỏ cho vừa ô |
| Cỡ điều khiển | Standard (điều chỉnh) | Pad, túi khối | Specified | 90 / 100 / 110 %, thay cho "UI scaling" của mẫu |
| Giảm chuyển động | Standard | Hiệu ứng HUD, rung biểu ngữ | Specified | Tắt nhấp nháy máu thấp, nhịp đập Thức Tỉnh, rung màn hình, lắc biểu ngữ; thay bằng dấu tĩnh. Ô đích đang niệm giữ 70 % cố định; VFX phép chỉ hiện khung cuối. Có tùy chọn rung màn hình 0 / 50 / 100 % |
| Cảnh báo chớp sáng | Basic | Toàn game | Not Started | (1) Thông báo nhạy cảm ánh sáng **một lần ở lần mở game đầu tiên**. (2) Không chớp > 3 lần/giây; nhấp nháy HUD ≤ 1 Hz; không có chớp toàn màn hình. (3) Kiểm lại mọi hiệu ứng khi có art |
| Chế độ tương phản cao | Comprehensive | — | **Ngoài phạm vi** | Xem Known Intentional Limitations |
| Điều chỉnh độ sáng / gamma | Basic | Toàn game | **Ngoài phạm vi** | Dùng độ sáng của hệ điều hành điện thoại (xem Known Intentional Limitations) |
| Phụ đề, nhận dạng người nói, tùy biến phụ đề, chú thích âm thanh | Basic–Comprehensive | — | **Không áp dụng** | Game không có thoại hay âm thanh |

### Color-as-Only-Indicator Audit

Mỗi mục phải có kênh không-màu hoạt động được trong cả ba dạng mù màu trước khi phát hành.

| Location | Color Signal | What It Communicates | Non-Color Backup | Status |
|---|---|---|---|---|
| Bóng khối khi kéo (ô sàn đất địch đổi màu) | Màu khối của nhân vật: đậm = trúng, mờ = trượt (không dùng đỏ) | Khối có trúng ô boss không | Nhãn "Sẽ trúng ✓" / "Sẽ trượt ✗" + viền liền / nét đứt | Specified |
| Ô đích đang niệm | Màu chất liệu khối anh hùng, sáng dần | Đòn của bạn rơi vào đâu, sắp rơi chưa | Dấu chất liệu + mép nổi trên ô; độ sáng tăng (không phải đổi màu) | Specified |
| Ô đỏ báo đòn boss | Đỏ | Ô nào sắp bị đánh | Sọc chéo + viền đậm + nhãn đếm ngược kèm tên đòn | Specified |
| Thanh máu | Xanh lá; khi thấp **không đổi sang đỏ** (đỏ chỉ dành cho báo đòn, `design/art/art-bible.md` Mục 4) | Sắp chết | Số "170/200", biểu tượng "!", viền Ngà nhấp nháy (hoặc viền đặc 3 art-px, tĩnh, khi giảm chuyển động) | Specified |
| Độ tươi khối trên sân | Không mã màu (chỉ chiều dài) | Khối sắp tan | Chiều dài thanh co lại; dưới 2 s khối nháy (hoặc viền nét đứt) | Specified |
| Từ khóa trên đơn vị | Cam, băng nhạt, Ngà + vết nứt, lam đậm | Cháy, Đóng Băng, Rạn, Giá Lạnh | Biểu tượng **khác hình** (ngọn lửa, khối băng, vết nứt, bông tuyết) + số tầng/giây | Specified |
| Tường và Bãi Gai | Lam-xám / xương-gỉ (không dùng tím: trùng Khối Lạ) | Đi qua được hay không | Hình khác hẳn: khối dựng nổi và gạch chéo với gai nhọn trên nền thưa | Specified |
| Hạng hiếm của lá và bảo vật | Viền màu | Thường / Hiếm / Sử thi / Boss | Tên hạng bằng chữ trên thẻ | Specified |
| Khối Lạ | Tím hồng | Khối ngẫu nhiên, khác bộ khối | Dấu sao + viền ngoài của cả hình | Specified |
| Thức Tỉnh sẵn sàng | Sáng lên | Dùng được | Chữ "SẴN SÀNG" + nhịp đập (hoặc viền tĩnh khi giảm chuyển động) | Specified |
| Cảnh báo địa hình | Cam-vàng, không đỏ | Sắp có mạch phun, ô rơi | Sọc hoặc viền nét đứt + nhãn chữ ("SẮP PHUN"...) | Specified |
| Nút Tung phép (xanh lá), Hủy (nâu) | Màu | Xác nhận hay hủy | Nhãn chữ trên nút; Tung phép to hơn Hủy | Specified |
| Hai nửa lưới | **Không tô màu hai nửa** (`design/art/art-bible.md` Mục 1) | Đất của ai | Vị trí trái/phải + đường phân chia giữa | Specified |
| Lá chưa đủ ô | Mờ | Không dùng được | Chữ "cần N ô" | Specified |

**Quan sát (cũ, trước 2026-10-29):** bảng màu báo trúng xanh dương – cam không phù hợp với Tritanopia (rất hiếm, khoảng 0,001 %), nhưng tín hiệu không bao giờ chỉ dựa vào màu nên vẫn dùng được.

---

## Motor Accessibility

Người dùng duyệt 2026-10-28. **Specified** = đã quyết ở mức thiết kế, chưa dựng.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---|---|---|---|---|
| Remap điều khiển | Standard | — | **Không áp dụng** | Chỉ cảm ứng, không có phím hay nút vật lý. Thay bằng thuận tay trái và cỡ điều khiển (bên dưới) |
| Chuyển đổi phương thức nhập | Standard | — | **Không áp dụng** | Chỉ cảm ứng. Bản dev trên desktop dùng chuột/phím chỉ để test |
| **Đường một ngón** | Standard (điều chỉnh) | Mọi thao tác trong trận | Specified | **Không thao tác nào bắt buộc hai ngón cùng lúc.** Mọi thứ làm được bằng một ngón tuần tự: đi (joystick nổi; **chế độ pad 3x3 nhìn thấy sẵn đã bỏ theo quyết định người dùng 2026-11-01**, nên người cần nút cố định hiện không có lựa chọn: xem Open Questions), chạm khối trong túi, chạm ô đích, chạm lá. Hai ngón chỉ là cách nhanh hơn. Cần xác nhận "chạm khối rồi chạm ô" hoạt động trọn vẹn trong build (Story 044, 2026-10-31) |
| **Thuận tay trái** | Standard (điều chỉnh) | Pad ↔ túi khối | Specified | Đảo vùng Z3 và Z5 |
| Cỡ điều khiển | Standard (điều chỉnh) | Pad, túi khối | Specified | 90 / 100 / 110 % |
| Thay thế cho thao tác giữ | Standard | Mọi thao tác giữ | Not Started | Các thao tác giữ trong game: (1) **giữ 0,6 s để xác nhận Giết** → tùy chọn "chạm hai lần để xác nhận"; (2) **giữ để xem chi tiết** lá/bảo vật → thêm biểu tượng ⓘ chạm một lần |
| Thay thế cho thao tác dồn dập | Standard | Pad | Not Started | **Giữ nút pad để lặp bước** theo nhịp hồi bước. Joystick nổi (điều khiển duy nhất từ 2026-11-01) đã lặp khi giữ; chế độ `pad` đã bỏ |
| Điều chỉnh thời gian thao tác | Standard | Mọi thao tác tính giờ | Specified | Không thao tác nào chỉnh được: **thời gian chọn lá** cố định 3 s (tùy chọn 3 s / 6 s / không giới hạn bỏ 2026-11-07). Các thao tác tính giờ khác: Tập trung (4–5 s), cửa sổ ghép (+1,5 s), giữ Giết (0,6 s) đã nêu ở trên. Né đòn boss là bản chất game (Known Intentional Limitations) |
| Hỗ trợ ngắm | Standard | — | **Không áp dụng** | Không có ngắm; báo trúng hiện sẵn |
| Chạy tự động, hỗ trợ nền tảng | Standard | — | **Không áp dụng** | Không có |
| Dời vị trí HUD | Comprehensive | — | **Ngoài phạm vi** | Thay bằng thuận tay trái |

---

## Cognitive Accessibility

Người dùng duyệt 2026-10-28.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---|---|---|---|---|
| Tùy chọn độ khó | Standard | — | **Một phần** | Có **Giao Kèo 0–10** (khó hơn, mở bằng thắng). **Chưa có chế độ dễ hơn Giao Kèo 0**; ghi vào Known Intentional Limitations |
| **Tạm dừng ở mọi trạng thái** | Basic | Mọi trạng thái trận | Specified | Nút tạm dừng luôn có trong trận. **Ngoại lệ có lý do:** 0,5 s khóa ngay sau khi tiếp tục (`pause_lockout_sec`), để tránh chạm nhầm |
| **Xem lại hướng dẫn** | Standard | Mọi nhắc một lần | Specified | Mọi dòng nhắc (Khối Lạ, ghép khối...) đọc lại được từ mục "Xem lại hướng dẫn" trong Cài đặt |
| Rõ ràng mục tiêu | Standard | — | **Không áp dụng** | Mục tiêu duy nhất là lên Tâm Lưới; màn bản đồ luôn hiện tầng và đường đi |
| Chỉ báo hình cho thông tin chỉ có ở âm thanh | Standard | — | **Chưa áp dụng** | Game chưa có âm thanh; mọi cảnh báo đã có hình (xem Auditory) |
| **Thời gian đọc giao diện** | Standard | Mọi thứ tự tắt | Not Started | Quy tắc: không thông tin cần hành động nào tự tắt dưới 5 s. Bảng bên dưới liệt kê mọi thành phần tự tắt |
| Tài liệu tải nhận thức | Comprehensive | — | **Ngoài phạm vi** | Tham chiếu ngân sách yếu tố ở `design/ux/hud.md` (9 yếu tố khi nhàn rỗi) |
| Hỗ trợ điều hướng | Standard | — | **Không áp dụng** | Không có thế giới mở; bản đồ hiện đường đi |

### Các thành phần tự tắt

| Thành phần | Thời lượng | Cần hành động? | Cách xử lý |
|---|---|---|---|
| NGẮT!, ĐÒN GIẢ!, biểu ngữ pha, nhãn địa hình, dải Bản Khắc | 0,6–1,5 s | Không (phản hồi; thông tin vẫn còn trên lưới) | Giữ nguyên |
| **Dòng nhắc một lần** (Khối Lạ, Bộ khối) | 4 s → **6 s** | Không, nhưng mang nội dung hướng dẫn | Đổi lên 6 s; đọc lại được ở "Xem lại hướng dẫn" |
| **Màn kết quả trận tự tiếp tục** | 3 s (`between_sec`) | Không | Giữ mặc định 3 s; thêm tùy chọn **tự tiếp tục: 3 s / 8 s / Tắt**; nút Tiếp tục luôn có |
| Menu 4 lá | 3 s | **Có** | Nới được: 3 s / 6 s / không giới hạn |
| Gợi ý ghép (E-14) | Bằng thời gian chọn lá | Có (gợi ý cách ghép) | Đi theo menu 4 lá (3 s cố định); không phải dòng nhắc một lần |

---

## Auditory Accessibility

**Game chưa có âm thanh nào** (không có tài nguyên âm thanh, mã chưa phát). Phần này là cam kết cho lúc âm thanh được thêm vào, cộng bảng kiểm các âm cảnh báo dự kiến. Người dùng duyệt 2026-10-28.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---|---|---|---|---|
| Phụ đề thoại | Basic | — | **Không áp dụng** | Không có thoại |
| Chú thích âm thanh cho SFX quan trọng | Comprehensive | — | **Ngoài phạm vi** | Thay bằng quy tắc: mọi âm cảnh báo đều có hình thay thế (bảng bên dưới). Không cần chú thích chữ |
| Âm đơn | Comprehensive | — | **Ngoài phạm vi** | Chưa có âm thanh; xem lại khi có âm thanh |
| **Âm lượng độc lập** | Basic | Mọi âm thanh | Not Started, **bắt buộc trước khi phát hành âm thanh** | Tối thiểu hai thanh: **Nhạc** và **Hiệu ứng** (âm giao diện nằm trong Hiệu ứng). 0–100 %, mặc định 80 %. Có trong Cài đặt và màn Tạm dừng, lưu vào hồ sơ |
| Hiển thị hướng âm thanh | Comprehensive | — | **Không áp dụng** | Mọi đe dọa nằm trên lưới, không có âm thanh theo hướng |
| Tương thích máy trợ thính | Standard | Âm cao tần | **Chưa áp dụng** | Khi có âm thanh: cảnh báo quan trọng không chỉ nằm trên 4 kHz |
| **Rung thay cho âm cảnh báo** | Exemplary (nâng lên) | Cảnh báo P1 | Specified | Rung ngắn khi boss bắt đầu đòn và khi bạn bị trúng. Tùy chọn Bật/Tắt, mặc định Bật. Cần API rung của Android và iOS |

### Gameplay-Critical SFX Audit

Âm thanh chưa tồn tại; đây là **các âm dự kiến** làm cảnh báo, mỗi âm đã có hình thay thế trong `design/ux/hud.md`.

| Sound Effect | What It Communicates | Visual Backup | Caption Required | Status |
|---|---|---|---|---|
| Boss bắt đầu đòn | Né đi | Ô đỏ có sọc + nhãn đếm ngược (E-16, E-17) | Không | Specified |
| Bạn bị trúng | Mất máu | Số sát thương, thanh máu, rung | Không | Specified |
| NGẮT! | Đòn bị phá | Biểu ngữ NGẮT! + ô đỏ biến mất | Không | Specified |
| Thức Tỉnh sẵn sàng | Dùng được | Nút "SẴN SÀNG" (E-08) | Không | Specified |
| Máu thấp | Sắp chết | "!" + viền (E-01) | Không | Specified |
| Boss đổi pha | Đổi lối đánh | Biểu ngữ pha (E-27) + vạch nửa máu | Không | Specified |
| Cảnh báo địa hình | Sắp phun / rơi | Sọc, nét đứt, nhãn chữ (E-25) | Không | Specified |
| Bảo vật kích hoạt | Hiệu ứng bảo vật | Nháy biểu tượng (E-31) | Không | Specified |

---

## Platform Accessibility API Integration

Người dùng duyệt 2026-10-28. Game chỉ phát hành trên điện thoại, nên các hàng Xbox, PlayStation, Steam và trình đọc màn hình trên PC của mẫu không áp dụng.

| Platform | API / Standard | Features Planned | Status | Notes |
|---|---|---|---|---|
| Android | AccessibilityService / TalkBack | **Không** trong phạm vi hiện tại | Ngoài phạm vi | Giao diện tự vẽ bằng `Node2D`, TalkBack không đọc được |
| iOS | UIAccessibility / VoiceOver | **Không** trong phạm vi hiện tại | Ngoài phạm vi | Như trên |
| Godot AccessKit (4.5+) | Node `Control` kết nối với công cụ đọc màn hình | **Không áp dụng được** cho giao diện hiện tại | Ngoài phạm vi | `docs/engine-reference/godot/current-best-practices.md` ghi AccessKit hoạt động qua node `Control`. Toàn bộ game dùng `Node2D` tự vẽ, không có `Control`. Dùng được sẽ cần một story dựng lại các màn menu thành `Control`. **NOT SOURCEABLE — việc AccessKit chạy trên Android/iOS ở Godot 4.6 không được nêu trong `docs/engine-reference/godot/`**; phải xác minh trước khi hứa |
| Cỡ chữ hệ điều hành | Android font scale, iOS Dynamic Type | **Không đọc** | Ngoài phạm vi | Dùng tùy chọn cỡ chữ trong game (100–130 %) |
| Cài đặt "giảm chuyển động" của hệ điều hành | Android "Remove animations", iOS "Reduce Motion" | Mặc định bật Giảm chuyển động nếu đọc được | Not Started | **Chưa kiểm chứng** Godot 4.6 có API đọc cài đặt này không; nếu không thì mặc định Tắt |
| Rung | Android Vibrator, iOS Haptic Engine | Rung ngắn cho cảnh báo P1 | Not Started | Cần API rung của Godot cho di động; kiểm khi làm |

---

## Per-Feature Accessibility Matrix

Ở tầng `minimal` chưa có `systems-index.md`, nên dùng các hệ thống trong `design/game-mechanics.md`. Khi thêm hệ thống mới phải thêm một hàng ở đây. Người dùng duyệt 2026-10-28.

| System | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed | Notes |
|---|---|---|---|---|---|---|
| Di chuyển (pad) | Nút ≥ 96 px, viền hồi bước | Giữ để lặp, thuận tay trái, cỡ 90–110 % | — | — | Một phần | Giữ để lặp chưa có mã |
| Đặt khối và tung phép | Báo trúng có ✓/✗, bảng màu thay thế | Chạm khối rồi chạm ô, một ngón | Nhãn số ô và sát thương | — | Một phần | Cần xác nhận đường một ngón trong build |
| Menu chọn lá | Chữ ≥ 24 px, "cần N ô" | Thẻ ≥ 96 px | Thời gian 3 s cố định (bỏ tùy chọn 2026-11-07) | — | Có (thiết kế) | Chưa dựng |
| Đòn và cảnh báo của boss | Sọc + nhãn đếm ngược | — | Cảnh báo không bị che | Rung, âm dự kiến | Có (thiết kế) | Né theo thời gian thực: Known Intentional Limitations |
| Thức Tỉnh | Chữ "SẴN SÀNG", giảm chuyển động | Nút ≥ 96 px | — | — | Có (thiết kế) | — |
| Địa hình vùng | Sọc, nét đứt, nhãn | — | Cảnh báo 0,8–1 s | — | Có (thiết kế) | — |
| Bản đồ chuyến leo | Biểu tượng khác hình | Chạm ≥ 96 px | Tầng và đường đi luôn hiện | — | Có | — |
| Thưởng, cửa hàng, sự kiện | Hạng bằng chữ | Giữ → chạm ⓘ | Không tự tắt | — | Một phần | Thay thế giữ để xem chi tiết chưa có |
| Tha/Giết | — | Xác nhận: giữ 0,6 s hoặc chạm hai lần | — | — | Một phần | Chạm hai lần chưa có |
| Kết quả trận | Nút ≥ 96 px | — | Tự tiếp tục 3 s / 8 s / Tắt | — | Một phần | Tùy chọn chưa có |
| Bảo vật, thành tựu | Biểu tượng + chữ | — | Đọc lại ở Tạm dừng | — | Có | — |
| Nhắc hướng dẫn | Chữ ≥ 18 px | — | 6 s, xem lại được | — | Một phần | Đổi 4 s lên 6 s (đã sửa trong `design/ux/hud.md`) |
| Cài đặt (sẽ có) | Cỡ chữ, bảng màu | Thuận tay, cỡ điều khiển, rung | Nhắc, thời gian | Âm lượng | **Chưa** | Story riêng |

---

## Accessibility Test Plan

Người dùng duyệt 2026-10-28.

| Feature | Test Method | Test Cases | Pass Criteria | Responsible | Status |
|---|---|---|---|---|---|
| Tương phản chữ | Công cụ đo trên ảnh chụp mọi màn | Mọi cặp chữ/nền, cả bốn loại địa hình | Chữ thường ≥ 4,5 : 1, chữ lớn ≥ 3 : 1 | ux-designer | Not Started |
| Chế độ mù màu | Mô phỏng Coblis trên ảnh chụp, bật cả hai bảng màu | Trận, bản đồ, thưởng | Không mất thông tin nào; phân biệt được báo trúng/trượt và ô đỏ | ux-designer | Not Started |
| Đường một ngón | Chơi trọn một chuyến leo chỉ bằng một ngón tuần tự | Đi, nhặt, đặt, chọn lá, Thức Tỉnh | Hoàn thành mọi thao tác, không cần hai ngón cùng lúc | qa-tester | Not Started |
| Thay thế thao tác giữ | Bật chạm hai lần và ⓘ | Xác nhận Giết, xem chi tiết lá và bảo vật | Không thao tác nào cần giữ | qa-tester | Not Started |
| Giữ để lặp | Giữ nút pad | Đi liên tục qua 5 ô | Lặp đúng nhịp hồi bước; không bước thừa | qa-tester | Not Started |
| ~~Thời gian chọn lá~~ | Bỏ 2026-11-07 (không còn tùy chọn) | — | — | — | N/A |
| Giảm chuyển động | Bật rồi chơi một chuyến leo | Máu thấp, Thức Tỉnh sẵn sàng, NGẮT!, đổi pha | Không nhấp nháy, nhịp đập, rung; thay bằng dấu tĩnh | ux-designer | Not Started |
| Cỡ chữ 130 % | Đặt 130 % | Mọi màn, các sân nhỏ nhất | Không chữ nào bị cắt hay đè lên ô đỏ | ux-designer | Not Started |
| Cỡ điều khiển và thuận tay trái | Đặt 90 % / 110 % và bật đảo | Pad, túi khối, kéo khối | Vẫn đủ ≥ 96 px (ở 100 %); kéo khối hoạt động | qa-tester | Not Started |
| Chớp sáng | Phân tích hiệu ứng | Mọi hiệu ứng và biểu ngữ | Không chớp > 3 lần/giây; không chớp toàn màn hình | ux-designer | Not Started |
| Rung | Thử trên máy thật | Boss bắt đầu đòn, bị trúng | Rung ngắn; tắt được | qa-tester | Not Started |
| Thử với người dùng: mù màu | Người mù màu đỏ–xanh chơi một buổi | Cả hai bảng màu | Hoàn thành không cần hỏi về màu | producer | Not Started |
| Thử với người dùng: vận động | Người chơi một tay hoặc có hạn chế vận động | Đường một ngón, menu 3 s, giữ để lặp | Hoàn thành nội dung trong mức chấp nhận được | producer | Not Started |

---

## Known Intentional Limitations

Mỗi mục là một rủi ro. Người dùng duyệt 2026-10-28.

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---|---|---|---|---|
| Trình đọc màn hình (TalkBack, VoiceOver, AccessKit) | Comprehensive | Giao diện là `Node2D` tự vẽ; cần dựng lại menu thành `Control` và chưa xác nhận AccessKit chạy trên di động | **Cao với người mù**; game thời gian thực trên lưới vốn khó dùng cho người mù | Ghi rõ; xem lại nếu dựng lại menu thành `Control` |
| Né đòn thời gian thực không làm chậm hơn được | Standard | Là bản chất game | Người có phản xạ chậm khó né | Chậm 0,2× khi đặt khối, Tập trung dừng hẳn, cảnh báo có đếm ngược |
| Nới thời gian chọn lá (3 s / 6 s / không giới hạn) | Standard | Người dùng bỏ 2026-11-07: giữ nhịp trận thống nhất, Cài đặt gọn hơn | Người chơi một tay hoặc phản xạ chậm có 3 s cố định để chọn lá | Trận chậm 0,2× khi menu mở, hết giờ tự chọn lá; giá trị cũ trong save bị bỏ qua |
| Chế độ dễ hơn Giao Kèo 0 | Comprehensive | Ảnh hưởng cân bằng; chưa có dữ liệu chơi thử (TD-006) | Người thấy độ khó nền quá cao không có lối thoát | Mở khóa nội dung dần; xem lại sau buổi chơi thử |
| Chế độ tương phản cao | Comprehensive | Ngoài công sức hiện tại | Người thị lực kém | Tương phản ≥ 4,5 : 1, viền chữ, tín hiệu không chỉ bằng màu, cỡ chữ 130 % |
| Điều chỉnh độ sáng trong game | Basic | Điện thoại đã có độ sáng hệ điều hành | Thấp | Dùng độ sáng của hệ điều hành |
| Công tắc ngoài, tay cầm, điều khiển thích ứng | Standard (điều khiển) | Chỉ cảm ứng; Switch Access cần cây trợ năng | Người dùng thiết bị thích ứng không chơi được | Đường một ngón |
| Cỡ chữ của hệ điều hành | Standard | Dùng tùy chọn cỡ chữ riêng trong game | Thấp | Cỡ chữ 100–130 % trong game |
| Phụ đề, chú thích, âm đơn | Basic–Comprehensive | Game chưa có thoại hay âm thanh | Khi có âm thanh phải làm đủ | Âm lượng độc lập bắt buộc trước khi phát hành âm thanh |
| Tài liệu tải nhận thức; kiểm định bên ngoài | Comprehensive, Exemplary | Ngoài công sức hiện tại | Trung bình | Ngân sách yếu tố trong `design/ux/hud.md` |

---

## Audit History

| Date | Auditor | Type | Scope | Findings Summary | Status |
|---|---|---|---|---|---|
| — | — | — | — | Chưa có kiểm định nào. Kiểm định đầu tiên khi story HUD hoàn thành (theo Test Plan) | Not Started |

---

## External Resources

| Resource | URL | Relevance |
|---|---|---|
| WCAG 2.1 | https://www.w3.org/TR/WCAG21/ | Tương phản, cỡ chữ, yêu cầu nhập liệu |
| Game Accessibility Guidelines | https://gameaccessibilityguidelines.com | Danh mục kiểm theo nhóm và chi phí |
| AbleGamers Player Panel | https://ablegamers.org/player-panel/ | Thử với người chơi khuyết tật |
| Coblis | https://www.color-blindness.com/coblis-color-blindness-simulator/ | Mô phỏng mù màu trên ảnh chụp |
| Accessible Games Database | https://accessible.games | Ví dụ thiết kế trợ năng |
| Android Accessibility | https://developer.android.com/guide/topics/ui/accessibility | Chuẩn trợ năng di động Android |
| Apple Human Interface Guidelines: Accessibility | https://developer.apple.com/design/human-interface-guidelines/accessibility | Chuẩn trợ năng di động iOS |

*Chưa kiểm tra lại các URL; xác minh trước khi trích dẫn.*

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| "Chạm khối rồi chạm ô" hoạt động trọn vẹn trong build (đường một ngón)? | ui-programmer | Trước story HUD | Mở |
| **Mở lại 2026-11-01:** người chơi cần nút di chuyển nhìn thấy, cố định (một ngón, không kéo) đi bằng gì? Chế độ `controls.movement = pad` từng trả lời câu này nhưng đã bỏ theo quyết định người dùng 2026-11-01 (joystick là điều khiển duy nhất). Phương án: chạm ô kề để bước, hoặc đưa lại pad dưới dạng tùy chọn trợ năng | ux-designer + người dùng | Trước story Cài đặt | Mở |
| Godot 4.6 có API đọc cài đặt "giảm chuyển động" của hệ điều hành? | ui-programmer | Khi làm màn Cài đặt | Mở |
| AccessKit chạy trên Android/iOS ở Godot 4.6? Có đáng dựng lại menu bằng `Control`? | technical-director | Trước khi cân nhắc nâng lên Comprehensive | Mở |
| Thời gian chọn lá "không giới hạn": trận tạm dừng hẳn hay vẫn chậm 0,2×? Ảnh hưởng cân bằng | game-designer | Trước story Cài đặt | Đóng 2026-11-07: tùy chọn bị bỏ, menu 3 s cố định |
| Có thêm chế độ dễ hơn Giao Kèo 0? | game-designer | Sau buổi chơi thử (TD-006) | Mở |
| Màn Cài đặt chứa mọi tùy chọn: story riêng | producer | Sau story HUD | Mở |
| Khi game có âm thanh: bus Nhạc/Hiệu ứng, thanh trượt trong Cài đặt và Tạm dừng | audio-director | Trước khi phát hành âm thanh | Mở |
| Thông báo nhạy cảm ánh sáng lần mở đầu: hiện ở màn nào? | ux-designer | Trước phát hành | Mở |
| API rung của Godot cho di động | ui-programmer | Khi làm rung | Mở |
| Chế độ mù màu còn đổi gì, sau khi bóng khối bỏ xanh lá – đỏ (2026-10-29)? Giữ (bảng tương phản cao cho đỏ báo đòn và màu trạng thái) hay ghi lý do bỏ | accessibility-specialist | Trước story Cài đặt | Mở |
