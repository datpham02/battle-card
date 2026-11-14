# Monster Skill Phase 2 — Sa Mạc nhóm S-A, ảnh chụp 2026-11-14

Lệnh (mỗi ảnh một tiến trình, tuần tự, tắt tiếng):
`godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -- --pattern=<id> --arena=<dunes|oasis> --art-region=sands --seed=1 --no-autopause --shot=<png> --shot-frame=<n>`

| Ảnh | Thấy gì |
|---|---|
| `sand_beetle-dunes-f150` | Thanh đỏ **2 ô** của `beetle_sand_spray` phủ ô hero và ô kề — đúng `offsets [[0,0],[1,0]]` neo `on_player` |
| `sand_beetle-dunes-f260` | Hero **180/200**: đã mất đúng 20, khớp damage húc trong data (thiết kế 8 × 2,5). Trận này chỉ có một kỹ năng gây damage nên 20 quy được về nó — khung hình cho thấy TỔNG máu đã mất, không cho thấy đòn nào lấy |
| `sand_beetle-dunes-f330` | **Ô cát vàng** bên trái hero; ô hero đứng KHÔNG bị lấp (xem ghi chú dưới) |
| `dust_nomad-oasis-f170` | Du Mục đang niệm; hero còn đủ máu |
| `dust_nomad-oasis-f280` | **Hình chữ T đỏ** của `nomad_ambush` phủ ô hero, hở ba phía — đúng `must_cover_player` |
| `dune_jackal-dunes-f150` / `f230` | Chó Rừng trên cồn cát. f150: một cú cắn. f230: cú cắn đuổi (`followup relative_to: player`). Hai khung rời, không khẳng định cái nào trước |

## Hai ghi chú cho người đọc sau

**1. `--art-region` nhận `sands`, không phải `desert`.** `desert` là id vùng trong `chapters.json` và
`region_rules.json`; thư mục art là `assets/art/env/sands`. Truyền sai **không báo lỗi**: nó lặng lẽ quay về vùng mặc
định và tiến trình vẫn thoát 0. Lượt chụp đầu của nhóm này ra 6 ảnh nền rừng, đúng mọi dữ kiện trong khung nhưng sai
bối cảnh, và chỉ lộ ra vì nền trông xanh. Kiểm sản phẩm, đừng kiểm mã thoát.

**2. Vì sao ô hero đứng không bị lấp cát.** Thiết kế §4.3 nói lấp "một ô, ô xa người chơi nhất". Không cần cơ chế chọn
tập con: `TileHazards._schedule` vốn đã **từ chối mọi ô đang có người đứng**, nên vùng neo `on_player` chỉ lấp được
phần còn lại của thanh — chính là ô xa hero nhất. `ZoneRules.fit_cells_for` cắt tiếp nếu lấp sẽ dồn hero vào góc.

**3. Banner "Floor 1/7 · Misty Forest · Goblin Scout" là của dev launcher** (`--pattern=` thay quái của match đầu),
không phải lỗi nhóm S-A. Tên vùng và tên quái đúng chỉ hiện trong run thật. Máu quái hiện 90 cũng là của match gốc,
không phải HP thiết kế của quái Sa Mạc.

**N. Ảnh chụp theo `--shot-frame=N` KHÔNG phải một dòng thời gian** (thêm 2026-11-14, sau nhóm D).
`N` đếm khung đã dựng, không đếm giây mô phỏng, và mỗi ảnh là một tiến trình riêng — nên ánh xạ khung→giây trượt
theo tải máy. Bằng chứng: bốn khung Nhân Sư cho máu hero 175 → 200 → 200 → 165 theo số khung tăng dần, điều không
thể xảy ra trên một dòng thời gian.

Mọi dữ kiện **bên trong một khung** vẫn thật. Mọi câu bắc qua **hai** khung thì không. Các dòng bảng trên đã được
sửa lại cho đúng phạm vi đó; nếu bạn thấy ở đâu còn chữ "rồi", "sau đó", "giảm", "khung muộn" thì đó là sót.
