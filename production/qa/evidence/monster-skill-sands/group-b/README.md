# Monster Skill Phase 2 — Sa Mạc nhóm S-B, ảnh chụp 2026-11-14

Lệnh (mỗi ảnh một tiến trình, tuần tự, tắt tiếng, **vùng art là `sands`**):
`godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -- --pattern=<id> --arena=<dunes|oasis> --art-region=sands --seed=1 --no-autopause --shot=<png> --shot-frame=<n>`

| Ảnh | Thấy gì |
|---|---|
| `scarab_guard-oasis-f160` | Khiên ngọc đang bật trên Bọ Hung (`scarab_shield_wall`); thanh đỏ `scarab_spear` **1 ô** — hero đứng sát mép nên ô thứ hai bị `clip` cắt, đúng `min_cells: 1` |
| `scarab_guard-oasis-f270` | Hero **170/200**: đã mất đúng 30, khớp damage đâm trong data (thiết kế 12 × 2,5). Chỉ quy về cú đâm vì trận này không có nguồn damage nào khác — khung hình cho thấy TỔNG máu đã mất |
| `mirage_sprite-dunes-f150` / `f260` | Bóng cát trên nửa sân địch, cùng hàng với hero; roi quất ra từ hàng của bóng |
| `sun_archer-dunes-f170` / `f250` | Chữ thập 5 ô của `archer_blinding_arc` phủ hero, hở bốn góc chéo |

## Ghi chú

**1. Dấu vân tay cây mã.** Lượt chụp này lấy `git status --porcelain -- src | md5sum` trước và sau; hai lần giống
nhau (`77579843…`), nên 6 khung này gắn với một cây mã thật sự đứng yên. Multi-enemy giữ yên `src/` cho cả lượt theo
thoả thuận. Lý do có bước này: hôm nay một session khác mất trọn một bộ ảnh vì file nguồn đổi giữa lượt chụp.

**2. Hai khung Cung Thủ đã chụp lại.** Lượt đầu trùng với một tiến trình Godot windowed của session khác — hai lượt
chụp cửa sổ cạnh nhau làm lệch nhịp khung hình. Nguyên nhân: lượt Godot được chuyền tay A → B → C mà không có một
người giữ duy nhất, nên hai bên cùng tin là đến lượt mình. Ảnh trong thư mục này là bộ chụp lại, không chồng lượt.

**3. Khiên Bọ Hung: vế máu thấp chưa có tác dụng.** Thiết kế §4.3 muốn nó ưu tiên giơ khiên khi có đồng đội **hoặc**
khi máu dưới 60 %. Khối `weights` của engine không có điều kiện theo máu, nên chỉ vế đồng đội chạy (0,3 → 1,2). Chi
tiết ở `MONSTER-SKILL-PHASE2-PLAN.md` §10.

**4. Banner "Floor 1/7 · Misty Forest · Goblin Scout" và máu quái 90 là của dev launcher,** không phải của quái Sa Mạc
— `--pattern=` chỉ thay quái của match đầu. Giống hệt ghi chú ở nhóm S-A và ở Hỏa Ngục.

**N. Ảnh chụp theo `--shot-frame=N` KHÔNG phải một dòng thời gian** (thêm 2026-11-14, sau nhóm D).
`N` đếm khung đã dựng, không đếm giây mô phỏng, và mỗi ảnh là một tiến trình riêng — nên ánh xạ khung→giây trượt
theo tải máy. Bằng chứng: bốn khung Nhân Sư cho máu hero 175 → 200 → 200 → 165 theo số khung tăng dần, điều không
thể xảy ra trên một dòng thời gian.

Mọi dữ kiện **bên trong một khung** vẫn thật. Mọi câu bắc qua **hai** khung thì không. Các dòng bảng trên đã được
sửa lại cho đúng phạm vi đó; nếu bạn thấy ở đâu còn chữ "rồi", "sau đó", "giảm", "khung muộn" thì đó là sót.
