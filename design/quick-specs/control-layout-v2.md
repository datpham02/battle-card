# Quick Spec — Bố cục điều khiển v2 (joystick nổi, túi vòng cung, sân cao hơn)

> **Loại**: thay đổi bố cục và điều khiển trong trận (UX), không đổi luật chơi
> **Nguồn**: phác thảo của người dùng 2026-10-31; mock trong `prototypes/art-check` (ảnh `production/qa/evidence/asset-slice1-art-check/11-21`)
> **Người dùng chốt**: 2026-10-31 — joystick nổi 4 hướng; sân lớn nhất là tinh thể 6x6, dải sân tới 76 %
> **Tài liệu bị ảnh hưởng**: `design/ux/hud.md` (Z2, Z3, Z5, I-06), `src/layout/screen_layout.gd`, `src/combat/dpad_view.gd`, `src/hold/hold_slots_view.gd`, `design/accessibility-requirements.md` (câu hỏi mở "một ngón")
> **Không đổi**: sprite, bảng màu, art bible §8 (trừ ghi chú về dải sân), luật đi từng ô và cooldown

## 1. Vấn đề

Bố cục hiện tại (`ScreenLayout`) cho cụm điều khiển 45 % chiều cao màn hình: đáy dải sân ở 55 %, ô túi cao 22 %, nút pad 13,5 %, nền tối cả dải. Dải sân chỉ còn 295 px ở 720p nên sân 5x5 phải dùng ô nhỏ nhất (38x27 art-px) và trông bé dù sprite đúng cỡ (hero 86 px, 12 % màn hình). Kiểm tỉ lệ ngày 2026-10-31 kết luận vấn đề ở bố cục, không ở sprite.

## 2. Quyết định

Mọi số dưới đây tính ở 1280x720; canvas chiến trường 640x360 art-px phóng 2x theo art bible §8.2. Tỉ lệ ghi kèm để `ScreenLayout` dùng cho màn khác.

### 2.1 Dải sân (Z2)

| Tham số | Hiện tại | v2 |
|---|---|---|
| Đỉnh dải sân | 3 % + 20 % × (55 − 3) % = 13,4 % | 3 % + 20 % × (64 − 3) % = **15,2 %** (giữ công thức, Z1 vẫn 3–8 % cho HUD, 8–15 % trống cho đầu đơn vị) |
| Đáy dải cho hàng rộng | 55 % | **64 %** |
| Đáy dải cho hàng hẹp | — | **76 %**, chỉ với hàng nằm gọn trong **khe ngón cái** x ∈ [25 %, 76,4 %] của chiều rộng (320–978 px) |
| Lề hai bên | 3 % | 3 % (không đổi) |

**Luật đặt sân:** một hàng của sân (cả hai nửa cộng vạch giữa) mà vượt ra ngoài khe ngón cái thì đáy hàng đó phải ≤ 64 %; hàng nằm gọn trong khe được xuống tới 76 %. Sân canh giữa theo chiều ngang; theo chiều dọc canh giữa dải 15,2–64 % rồi được phép tràn xuống nếu luật trên cho phép.

**Cỡ ô:** tỉ lệ rộng/cao 1,4; nhỏ nhất 38x27, lớn nhất 64x46 art-px; chọn ô lớn nhất thỏa luật đặt sân và chiều rộng mỗi nửa ≤ 298 art-px (602 art-px trừ vạch giữa 6, chia đôi). Hệ quả đã đo:

| Sân (mỗi nửa) | Ô ở bố cục cũ | Ô ở v2 |
|---|---|---|
| 3x3 | 64x46 | 64x46 (trần) |
| 4x4 cross | 60x43 | 60x43 |
| 5x5 | 38x27 | **49x35** (đo lại khi làm Story 044; bản nháp ghi 48x34) |
| 6x5 ring | 38x27 | **45x32** (Story 044: ô thu nhỏ để không ô sân nào chạm T1; xem 2.3) |
| 6x6 tinh thể | không vừa | **49x35** (nhờ dải 76 %) |
| 7x6 tinh thể | không vừa | 42x30 (chiều rộng khóa) |

Quy tắc nhớ: từ 6 cột trở lên chiều rộng quyết định cỡ ô, từ 5 cột trở xuống chiều cao quyết định. Trần khung bao của một hình sân là **7 cột × 6 hàng mỗi nửa**; mọi hình trong `arenas.json` hiện tại đều vừa.

### 2.2 Z3 — di chuyển: joystick nổi 4 hướng (I-06)

- **Vùng nhà:** x 0–25 %, y 64–100 % (320x259 px). Chạm xuống bất kỳ đâu trong vùng thì joystick xuất hiện tại điểm chạm; nhấc tay thì biến mất. Không có hình cố định khi không chạm, chỉ một gợi ý mờ (vòng 1 px, alpha 0,25) ở tâm (150 px từ lề trái, 80 % chiều cao) trong 3 giây đầu trận và khi `settings.show_control_hints` bật.
- **Kích thước:** đế bán kính 80 px (160 px), núm bán kính 44 px (88 px, bằng ngưỡng chạm tối thiểu của `design/accessibility-requirements.md`).
- **Đọc hướng:** vùng chết 16 px (20 % bán kính đế). Ngoài vùng chết, snap vào 4 hướng theo góc 90° (chéo chia theo trục gần hơn). Không có hướng chéo vì lưới đi 4 hướng.
- **Nhịp bước:** vào vùng một hướng = một bước ngay (nếu hết cooldown). Giữ hướng = bước lại mỗi khi cooldown hết (cùng cooldown đang có trong `UnitMover`, không thêm số mới). Đổi hướng = bước ngay theo hướng mới nếu hết cooldown. Thả = dừng.
- **Khi đặt khối:** vùng Z3 đổi thành nút Xoay lớn như hiện tại (I-12), joystick tắt.
- **Tùy chọn `controls.movement`:** `joystick` (mặc định) | `pad`. Chưa có màn Settings nên nút đổi nằm trên bảng Tạm dừng; giá trị lưu ở `user://settings.json`. `pad` vẽ lại pad 3x3 cũ trong cùng vùng (nút vẽ 86 px vì vùng cao 259 px không chứa 3 nút 88 px; vùng chạm mỗi nút nới ra ngoài thành 88 px), cho người cần nút nhìn thấy; đây là trả lời cho câu hỏi mở "một ngón" trong `design/accessibility-requirements.md` (vẫn mở phần còn lại).
- **Bàn phím/chuột trên desktop:** không đổi (phím mũi tên, test click dùng pad qua tùy chọn `pad`).

### 2.3 Z5 — túi khối vòng cung (I-07)

- 3 ô, mỗi ô dọc **93x130 px** (cao 18 % chiều cao, rộng = cao / 1,4; cũ 113x158).
- Tâm cung: điểm xoay ngón cái phải `(W − 0,5·lề, H + 0,35·cao ô)` = (1261, 765). Bán kính **2,25 × cao ô = 292 px**. Góc **96° (T1), 126° (T2), 156° (T3)** tính từ trục +x ngược chiều kim đồng hồ; T1 cao bên phải, T3 thấp bên trái.
- Ở 1280x720: T1 tại (1184, 411), T2 tại (1043, 465), T3 tại (948, 582), mỗi ô 93x130; khe hẹp nhất 2,4 px (T2–T3 theo x); đáy T3 ở 712. `slot_rect` kẹp mọi ô vào trong màn hình. Ở 1600x720 cả cụm dời phải 315 px.
- **Sửa khi làm Story 044 (2026-10-31):** số trong bản nháp (bán kính 2 × cao ô, góc 100/128/156) sai: T2 và T3 đè nhau khoảng 15x31 px và T3 lòi ra ngoài 4,8 px. Bán kính và góc ở trên là bản đã sửa, có test.
- **Ô sân không chạm ô túi:** `cell_size()` còn đòi không ô sân thật nào đè lên ô túi nào. Ở 1280 sân ring thu từ 49x35 xuống 45x32 (**người dùng duyệt 2026-10-31**, ảnh `03-ring-arena.png`) và forge từ 59x42 xuống 57x41; các sân khác và mọi sân ở 1600 không đổi. T1 vẫn ló vào góc phải dưới của khung sân (y 411–460), chỗ không có ô sân.
- **Túi 4 ô (Túi Rộng):** 4 ô trên một cung là không thể (mọi cung thử từ 2,0–4,0 × cao ô, góc 80–178° đều đè nút Hủy hoặc trèo vào sân). Ô thứ 4 nằm trên vòng trong dưới chỗ nghỉ ngón cái: góc 122°, bán kính 1,05 × cao ô, tại (1142, 585), cách T2 6,7 px, không chạm nút nào. **Người dùng duyệt 2026-10-31** (ảnh `production/qa/evidence/control-layout-v2/08-bag4-inner-ring.png`).
- Thứ tự T1→T3 là thứ tự túi hiện tại (ô 0→2). Kéo thả, đếm số ô, thanh độ tươi, hẹn giờ khối hỏng giữ nguyên hành vi.
- Mép trái ô T3 (x ≈ 948) là mốc phải của các nút giữa; nút Hủy tính từ mép này nên dời theo (x 788–929). Cột số ô / sát thương giữa Thức Tỉnh và Hủy chỉ còn ~75 px nên chữ trong đó tự thu nhỏ cho vừa.

### 2.4 Z4 — Thức Tỉnh và menu lá

- Nút Thức Tỉnh 115 px (16 %), canh giữa, cách đáy 19 px (0,5·lề). Menu 4 lá và nhóm Tung phép/Hủy/Tập trung giữ vị trí giữa dưới như hiện tại; kiểm lại không đè T3 khi menu mở (menu rộng tối đa tới x 960).

### 2.5 Nền

- Không còn dải nền tối. Nền tối (Mực 85 %) chỉ dưới từng nút và ô túi, viền 2 px (`art-bible.md` §7.2). Phần còn lại lộ nền sân.

## 3. Hình sân đề xuất: `crystal`

Khung bao 6x6 mỗi nửa, cắt góc xa theo bậc 3/2/1/1/2/3. Tọa độ nửa (cột 0 xa vạch giữa):

```
"id": "crystal", "side_cols": 6, "side_rows": 6, "difficulty": 4,
"missing_cells": [[0,0],[1,0],[2,0],[0,1],[1,1],[0,2],[0,3],[0,4],[1,4],[0,5],[1,5],[2,5]]
```

24 ô mỗi nửa (luật `min_cells_per_side` 6 thỏa). Ô 49x35 ở v2. **Chưa thêm vào `arenas.json`**: game-designer cần duyệt đường bước, số ô đặt khối (24 so với 25 của 5x5) và biến thể của `arena_variants.gd` trước.

## 4. Tuning knobs

| Khóa | Mặc định | Ghi chú |
|---|---|---|
| `layout.arena_bottom_wide` | 0,64 | đáy cho hàng rộng |
| `layout.arena_bottom_narrow` | 0,76 | đáy cho hàng trong khe |
| `layout.thumb_gap` | [0,25, 0,764] | theo chiều rộng |
| `layout.stick_zone_width` | 0,25 | |
| `layout.stick_base_px` / `stick_knob_px` | 160 / 88 | |
| `layout.stick_deadzone_ratio` | 0,20 | của bán kính đế |
| `layout.slot_height_ratio` | 0,18 | cũ 0,22 |
| `layout.slot_arc_angles_deg` | [96, 126, 156] | bản nháp [100, 128, 156] đè nhau |
| `layout.slot_arc_radius_ratio` | 2,25 | nhân cao ô; bản nháp 2,0 |
| `controls.movement` | joystick | joystick \| pad |

## 5. Tiêu chí nghiệm thu

- [ ] Ảnh 1280x720 cho 3x3, 5x5, ring, crystal: không ô sân nào nằm dưới nút hay ô túi; ô 5x5 ≥ 48x34, crystal 49x35.
- [ ] Mọi vùng chạm ≥ 88 px; ba ô túi không chạm nhau; T3 không đè menu lá khi mở.
- [ ] Joystick: chạm trong vùng là xuất hiện tại chỗ chạm; vùng chết 16 px; 4 hướng; giữ thì bước theo cooldown; thả thì dừng; chuyển sang Xoay khi đặt khối.
- [ ] Settings đổi được `controls.movement`; `pad` vẽ pad 88 px và test click cũ chạy được với tùy chọn này.
- [ ] Z1 không đổi; đầu đơn vị hàng sau cùng vẫn ló vào 8–15 %.
- [ ] Test đơn vị cho hàm chọn ô và luật đặt sân (bảng ở 2.1), và cho phép đọc hướng joystick (vùng chết, snap, giữ/thả).

## 6. Ngoài phạm vi

Sprite và bảng màu; SubViewport 640x360 (story kỹ thuật riêng, bố cục này tính theo tỉ lệ nên không phụ thuộc); thêm `crystal` vào `arenas.json` (chờ game-designer); màn ngoài trận.
