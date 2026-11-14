# Monster Skill Phase 2 — Sa Mạc nhóm S-C (hai elite), ảnh chụp 2026-11-14

Lệnh (mỗi ảnh một tiến trình, tuần tự, tắt tiếng, **vùng art là `sands`**):
`godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -- --pattern=<id> --arena=<dunes|oasis> --art-region=sands --seed=1 --no-autopause --shot=<png> --shot-frame=<n>`

| Ảnh | Thấy gì |
|---|---|
| `sand_burrower-dunes-f160` | **Đường đỏ 2 ô DỌC theo cột hero** của `burrower_undertow` — bằng chứng bản sửa toạ độ ở §12.1 của kế hoạch: trước khi sửa, cùng kiểu neo này tạo ra thanh ngang |
| `sand_burrower-dunes-f270` | Hero đã mất đúng 30, khớp Cát Cuốn trong data (thiết kế 12 × 2,5). "Đã mất" chứ không phải "giảm": một hiệu số cần một khung trước, mà bộ ảnh này không có |
| `scorpion-oasis-f150` | Cặp ô đỏ của `scorpion_pincer_hold` kẹp quanh hero |
| `scorpion-oasis-f260` | Chích Độc / Kẹp Càng đã nổ |
| `scorpion-oasis-f330` | Khung có nọc độc đang chạy (Độc 3 s, 0,5 s mỗi nhịp, 1,5 mỗi nhịp = 9 tổng) |

## Ghi chú

**1. Dấu vân tay cây mã.** Lượt chụp lấy `git status --porcelain -- src | md5sum` trước và sau; giống nhau
(`77579843…`), nên 5 khung này gắn với một cây mã đứng yên. Hôm nay đã có **hai** lần sửa file giữa một lần chạy
dài (một được khai, một không), nên bước này không còn là hình thức.

**2. Hố Sụt không có trong bộ ảnh.** `burrower_sinkhole` bị khoá sau `hp_below: 0.5`, mà dev launcher không hạ máu
quái, nên nó không thể lên hình trong lượt chụp này. Cơ chế được kiểm bằng test
(`pattern_sands_group_c_test.gd`: hai ô cạnh hero, không bao giờ là ô hero đứng, luôn còn một ô kề an toàn).
Đây là **thiếu bằng chứng hình ảnh có chủ ý và đã ghi**, không phải ba dấu tích rồi im lặng ở dấu thứ tư.

**3. Hai trait của hai elite không kiểm ở đây.** `burrow` (tạm dừng pattern brain) và `riposte` (phản đòn khi người
chơi tung đòn lớn) có suite riêng: `pattern_phase0_pause_test` và `region_traits_test`.

**4. Banner "Floor 1/7 · Misty Forest · Goblin Scout" và máu quái 90 là của dev launcher,** không phải của quái
Sa Mạc — `--pattern=` chỉ thay quái của match đầu.

**5. Chưa ai kiểm NGƯỜI CHƠI ĐỌC ĐƯỢC GÌ từ các hiệu ứng này.** Mọi phép kiểm của nhóm A–C trả lời câu *"có đúng
không"*: damage khớp data, ô cùng cột, vùng chừa lối thoát, cây mã đứng yên. Không phép nào trả lời *"người chơi
hiểu đây là gì"*. Ví dụ cụ thể: ô cát của Bọ Cát hiện rõ và đúng chỗ, nhưng chưa ai xác nhận người chơi đọc nó là
*ô này không đứng được nữa*. Cùng loại với ô đỏ cảnh báo, vốn đã được học từ các vùng trước nên không phải dạy lại.

Ghi ra đây vì hôm nay session character đã mất hai bộ ảnh cho đúng bài học này: một hiệu ứng **vẽ đúng** vẫn có thể
**nói sai** (hai dấu ngoặc kẹp hai bên một đơn vị nghĩa là *đang chọn*, không phải *đã bị đánh dấu*), và không phép
kiểm hình học nào bắt được — chỉ có người xem rồi hỏi "cái này đang nói gì với tôi?".

**N. Ảnh chụp theo `--shot-frame=N` KHÔNG phải một dòng thời gian** (thêm 2026-11-14, sau nhóm D).
`N` đếm khung đã dựng, không đếm giây mô phỏng, và mỗi ảnh là một tiến trình riêng — nên ánh xạ khung→giây trượt
theo tải máy. Bằng chứng: bốn khung Nhân Sư cho máu hero 175 → 200 → 200 → 165 theo số khung tăng dần, điều không
thể xảy ra trên một dòng thời gian.

Mọi dữ kiện **bên trong một khung** vẫn thật. Mọi câu bắc qua **hai** khung thì không. Các dòng bảng trên đã được
sửa lại cho đúng phạm vi đó; nếu bạn thấy ở đâu còn chữ "rồi", "sau đó", "giảm", "khung muộn" thì đó là sót.
