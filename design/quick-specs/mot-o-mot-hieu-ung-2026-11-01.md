# Quick Design Spec: Mỗi ô một hiệu ứng, ô đang nứt là ô khóa

**Type**: Tweak
**System**: Hiệu ứng vùng trên ô (Cháy, Bãi Gai, Ô rớt), đòn của địch và của người chơi
**GDD Reference**: `design/game-mechanics.md` §2.6 (Từ khóa trạng thái), `design/quick-specs/o-rot-thay-tuong-2026-10-31.md`
**Date**: 2026-11-01
**Người dùng chốt**: 2026-11-01 — (1) "trên 1 ô chỉ có 1 hiệu ứng", chọn **hiệu ứng mới thay cái cũ**; (2) "khi ô đó đang trong hiệu ứng làm nứt thì không được xài thêm hiệu ứng nào vô, nó như một ô không thể xài skill vô luôn"
**Trạng thái**: Đã duyệt (người dùng, 2026-11-01)

## Change Summary

Một ô chỉ giữ **một hiệu ứng vùng** tại một lúc; phép mới đặt hiệu ứng lên ô đã có hiệu ứng thì **thay** cái cũ. Riêng ô **đang nứt** và ô **đã thành hố** (Ô rớt) là **ô khóa**: không phép nào tác dụng lên ô đó — không sát thương, không trạng thái, không hiệu ứng vùng mới.

## Motivation

- Ô chồng nhiều hiệu ứng khó đọc trên sân 3×3 và trên màn hình điện thoại; một ô một hiệu ứng thì nhìn là biết.
- Ô khóa xóa trường hợp bất công "đang đứng trên ô nứt thì bị một đòn khác Đóng Băng nên không chạy ra được": đòn đó không chạm được vào ô nứt nữa.

## Định nghĩa

- **Hiệu ứng vùng**: hiệu ứng **do một phép tạo ra** và còn nằm trên ô sau khi phép kết thúc: ô cháy (Cháy), Bãi Gai, vết nứt và hố của Ô rớt; sau này độc và các vùng mới theo design pack.
- **Không tính**: địa hình của vùng (ô lầy, cát lấp, mạch dung nham, ô nứt Không Đảo) — đó là sàn, không phải phép; trạng thái trên **người** (Đóng Băng, Rạn, Giá Lạnh, Cháy trên người) — vẫn theo luật cộng dồn hiện tại.

## New Rules

1. **Một ô, một hiệu ứng.** Mỗi ô có tối đa 1 hiệu ứng vùng.
2. **Mới thay cũ.** Phép đặt hiệu ứng vùng lên ô đang có hiệu ứng vùng khác: cái cũ mất ngay, cái mới bắt đầu với thời lượng đầy đủ của nó. Cùng loại thì làm mới thời lượng (giữ luật chồng tầng Cháy hiện có cho **người** đứng trong ô).
3. **Ô khóa.** Ô đang **nứt** hoặc đã thành **hố** không nhận bất kỳ tác dụng nào của phép:
   - đòn (của địch hay người chơi) có ô khóa trong vùng đánh: ô khóa bị **bỏ ra khỏi vùng**, đơn vị đứng trên ô khóa **không** nhận sát thương, trạng thái hay hiệu ứng vùng từ đòn đó; các ô còn lại của đòn đánh bình thường;
   - không phép nào đặt hiệu ứng vùng lên ô khóa (luật 2 không áp cho ô khóa);
   - ô khóa vẫn theo đúng luật Ô rớt 31/10: nứt 0,8 s, rơi, hố 1,2 s, hiện lại; khi ô hiện lại thì hết khóa.
4. **Cảnh báo khớp với đòn.** Theo design pack (cảnh báo = đúng các ô bị đánh): khi một ô bắt đầu nứt trong lúc một đòn đang cảnh báo đè lên nó, ô đó **bỏ màu cảnh báo đỏ ngay** (nhìn thấy được), không bao giờ còn đỏ ở ô sẽ không bị đánh.
5. **Ô rớt chọn ô.** Boss vẫn chọn ô theo luật công bằng 31/10; nếu ô được chọn đang có hiệu ứng vùng (ví dụ gai) thì luật 2 áp: vết nứt thay hiệu ứng đó.

## Hệ quả cần biết

- Đứng trên ô đang nứt thì **an toàn trước mọi đòn khác** trong 0,8 s, nhưng phải rời trước khi ô rơi. Đây là chủ ý: ô nứt là nguy hiểm duy nhất trên ô đó.
- Luật "ô dưới chân không rơi khi bị Đóng Băng giữa chừng" (spec 31/10) gần như không còn xảy ra từ đòn của địch; vẫn giữ làm lưới an toàn cho nguồn Đóng Băng không qua ô (nếu sau này có).
- Đốt ô rồi rải gai lên cùng ô: gai thay lửa. Người chơi cần chọn ô cho hiệu ứng thay vì chồng.

## Affected Systems

| Hệ | Ảnh hưởng | Việc |
|---|---|---|
| `StatusEffects` (ô cháy, gai, nứt/hố) | một hiệu ứng vùng mỗi ô, mới thay cũ, ô khóa | sửa + test |
| Đường phân giải đòn (`CutEffects`, `SwingArbiter`, `SkillDelivery.damage_cells`) | bỏ ô khóa khỏi vùng đánh trước khi tính sát thương/trạng thái | sửa + test |
| Cảnh báo đòn của địch (telegraph) | bỏ đỏ ở ô bắt đầu nứt | sửa + test |
| Trait vùng của boss (`row_burner`, `thorn_field`, `bog_spread`…) | đặt hiệu ứng theo luật 2, không lên ô khóa | kiểm tra + test |

## Acceptance Criteria

- [ ] Không ô nào có hơn 1 hiệu ứng vùng tại một lúc (test với gai → lửa → nứt trên cùng ô).
- [ ] Hiệu ứng mới thay cũ với thời lượng đầy đủ; cùng loại thì làm mới.
- [ ] Đòn có ô đang nứt / đã là hố trong vùng: đơn vị trên ô đó không mất máu, không nhận trạng thái; ô còn lại vẫn trúng.
- [ ] Ô bắt đầu nứt giữa lúc đang bị cảnh báo thì mất màu đỏ ngay.
- [ ] Địa hình vùng (lầy, cát, dung nham, ô nứt Không Đảo) và trạng thái trên người không đổi hành vi.
- [ ] Không hồi quy: luật Ô rớt 31/10, Bãi Gai, Cháy, các trận không có hiệu ứng vùng.

## GDD Update Required?

Có — `design/game-mechanics.md` §2.6: thêm luật "một ô một hiệu ứng" và "ô khóa"; ghi sau khi người dùng duyệt spec này.
