# Quick Design Spec: Chọn lá giữa màn hình và hồi chiêu kiểu LMHT

**Type**: Tweak
**System**: Đặt khối và tung phép (menu lá phép), HUD trong trận
**GDD Reference**: `design/game-mechanics.md` §2.3 (Đặt khối và tung phép), §2.4 (Ghép khối và Hình Cộng Hưởng); `design/ux/hud.md`
**Date**: 2026-11-01
**Người dùng chốt**: 2026-11-01 — "khi người chơi kéo các khối xuống sàn để chọn skill thì các lá bài sẽ hiện show lên ở giữa màn hình … chứ không có hiện luôn từ đầu"; "khi kéo khối thì người ta chọn cast thì mới hiện lá bài lên"; "phủ lên có một background xám nhẹ rồi che sân, có thể nhìn xuyên thấy, và hiện 4 thẻ bài"; hồi chiêu "hiện icon ở mép trái … lớp phủ đen mờ trên icon đó rồi quay theo kim đồng hồ như cd của các skill trong Liên Minh Huyền Thoại"
**Trạng thái**: Đã duyệt (người dùng, 2026-11-01)

## Change Summary

Lá phép không còn hiện ngay khi thả khối. Người chơi đặt khối (ghép tối đa 2, hoặc 3 với Xích Ba Mắt), bấm **Tung phép**, lúc đó một lớp xám nhẹ nhìn xuyên được phủ cả màn hình và **4 lá bài** hiện giữa màn hình để chọn. Lá đang hồi chiêu hiện **icon ở cột mép trái màn hình** với lớp đen mờ quay theo chiều kim đồng hồ.

## Motivation

- Bảng nút chữ ở dải dưới nhỏ, sát cần điều khiển, khó đọc trên điện thoại; lá bài to ở giữa đọc được tên, hình và chữ.
- Tách "đặt khối" và "chọn lá" thành hai bước rõ ràng: đặt xong mới chọn, không còn vừa kéo khối thứ hai vừa đọc lá.
- Hồi chiêu nhìn một cái là biết (vòng quay quen thuộc), không phải đọc số trên từng lá.

## Design Delta

Hiện tại (`design/game-mechanics.md` §2.3 bước 4, §2.4):

> 4. Thả khối thì **menu lá phép** mở ra: rút **4 lá** từ bộ bài theo túi xáo, có **3 giây** để chọn, trận chậm 0,2×. Hết giờ thì tự dùng đòn chém cơ bản. Lá chưa đủ số ô hiện "cần N ô".
>
> Trong lúc menu lá mở, kéo thêm **một khối** nữa lên đất địch để **ghép** vào cùng đòn (+1,5 giây chọn lá).

Đổi thành:

1. **Chọn khối** trong túi → chế độ đặt như cũ (chậm 0,2×, hoặc dừng hẳn nếu Tập trung sẵn sàng).
2. **Thả khối thứ nhất** xuống sàn địch: **chưa hiện lá nào**. Nút **Tung phép** hiện như hiện nay.
3. **Ghép**: trước khi bấm Tung phép, kéo thêm khối thứ hai (thứ ba với Xích Ba Mắt) theo đúng luật ghép cũ (không chồng ô, chạm cạnh hay rời nhau đều được); Hình Cộng Hưởng tính như cũ.
4. **Thời gian đặt**: từ lúc thả khối đầu có `place_window_sec` (mặc định 3 s, `cuts.json`) để ghép và bấm; hết giờ thì **tự Tung phép**. Thanh thời gian đặt hiện ở chỗ thanh chọn lá cũ. Tập trung vẫn theo luật Tập trung hiện có (dừng hẳn tối đa 4 s).
5. **Bấm Tung phép** → **lớp xám nhẹ nhìn xuyên được** phủ toàn màn hình (sân, bóng khối vừa đặt vẫn thấy qua lớp phủ) và **4 lá** hiện ở **giữa màn hình**, dùng mặt lá `CardFace` kiểu ancient 176×256 (kiểu OSFE đã làm), thanh 3 giây phía trên. Rút 4 lá, 3 giây, trận chậm 0,2×, hết giờ tự dùng đòn chém cơ bản — giữ nguyên.
6. **Chạm một lá** → lá và lớp phủ biến mất, đòn bắt đầu niệm như cũ. Lá chưa đủ số ô vẫn ghi "cần N ô" và không chọn được.
7. Bỏ luật "kéo thêm khối trong lúc menu mở, +1,5 s".

## Hồi chiêu

- Dùng một lá có hồi chiêu → **icon** của lá vào **cột mép trái màn hình** (giữa hàng bảo vật góc trên trái và cần điều khiển góc dưới trái), xếp từ trên xuống theo thứ tự dùng.
- Trên icon: **lớp đen mờ hình quạt quay theo chiều kim đồng hồ** từ 12 giờ, phần đã hồi lộ ra; **số giây còn lại** (làm tròn lên) ở giữa icon. Hồi xong → icon biến mất khỏi cột.
- Lá đang hồi mà được rút vào 4 lá: vẫn hiện, **tối đi**, phần hình có **cùng lớp đen quay** và số giây, **không chạm được**.
- Trong trận bỏ số hồi chiêu ở góc dưới trái của lá; màn thưởng và cửa hàng vẫn ghi "hồi N s".

## Tuning Knobs

| Knob | Mặc định | Khoảng | Nơi |
|---|---|---|---|
| `place_window_sec` | 3.0 | 1.5–6 | `assets/data/cuts.json` |
| Thời gian chọn lá | 3.0 (giữ) | — | chỗ hiện có |
| Độ mờ lớp xám | ~0.45 | 0.3–0.6 | dữ liệu giao diện |

## Affected Systems

| Hệ | Ảnh hưởng | Việc |
|---|---|---|
| `CutFlow` / `CombatView` (đặt khối, ghép, mở menu) | menu mở khi bấm Tung phép; ghép trước khi bấm; cửa sổ đặt 3 s | sửa + test |
| `CutHudView` (`_draw_menu`) | lớp phủ + 4 `CardFace` giữa màn hình, thanh 3 s | sửa + ảnh |
| `ScreenLayout` | vùng 4 lá giữa màn hình, cột hồi chiêu mép trái | sửa + test |
| `CardFace` | kiểu trong trận không có số hồi chiêu; lớp quạt đen | sửa |
| Bộ test tích hợp đặt khối / ghép / menu | luồng mới | sửa + test |

## Acceptance Criteria

- [ ] Trong trận không lá nào hiện trước khi bấm Tung phép.
- [ ] Bấm Tung phép: lớp xám nhìn xuyên được + 4 lá ở giữa; sân và bóng khối vẫn thấy qua lớp phủ.
- [ ] Ghép 2 khối trước khi bấm vẫn tính Hình Cộng Hưởng; không ghép được khi menu đang mở.
- [ ] Hết `place_window_sec` tự Tung phép; hết 3 s chọn lá tự dùng đòn chém cơ bản.
- [ ] Cột hồi chiêu: icon có quạt đen quay theo kim đồng hồ, số giây đúng, hồi xong biến mất.
- [ ] Lá đang hồi trong 4 lá tối đi, có quạt, không chọn được.
- [ ] Ảnh 1280×720 giữ lại cho: đang đặt khối, đang chọn lá, đang hồi chiêu (`production/qa/evidence/card-pick-centre/`).
- [ ] Không hồi quy: Tập trung, Phá phép, sát thương, Bản Khắc, lá bị nguyền.

## GDD Update Required?

Có — `design/game-mechanics.md` §2.3 bước 4 và §2.4 (luật ghép), `design/ux/hud.md` (menu lá, cột hồi chiêu).
