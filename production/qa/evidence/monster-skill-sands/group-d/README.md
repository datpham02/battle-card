# Monster Skill Phase 2 — Sa Mạc nhóm S-D (boss sand_sphinx), ảnh chụp 2026-11-14

Lệnh (mỗi ảnh một tiến trình, tuần tự, tắt tiếng, **vùng art là `sands`**):
`godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -- --pattern=sand_sphinx --arena=oasis --art-region=sands --seed=1 --no-autopause --shot=<png> --shot-frame=<n>`

| Ảnh | Thấy gì trong CHÍNH khung đó |
|---|---|
| `sand_sphinx-oasis-f140` | Hero **175/200** — đã mất đúng 25, khớp `sphinx_gaze` trong data (thiết kế 10 × 2,5) |
| `sand_sphinx-oasis-f200` | **Hai ô cát** nằm cạnh hero, ô hero đứng không bị lấp — `sphinx_bury` |
| `sand_sphinx-oasis-f260` | **Hai ô cảnh báo vàng xếp dọc** cạnh hero |
| `sand_sphinx-oasis-f330` | Hero **165/200** — đã mất đúng 35, khớp `sphinx_claw` trong data (thiết kế 14 × 2,5) |

Nhân Sư đứng giữa ô của nó, nền `sands` đúng vùng (lần nhóm C `--art-region=desert` lặng lẽ rơi về vùng mặc định
và hỏng 6 khung; lần này đã kiểm bằng mắt từng ảnh, không tin `exit=0`).

## Ghi chú

**1. Ảnh chụp theo `--shot-frame=N` KHÔNG phải một dòng thời gian.** Máu hero qua bốn khung theo số tăng dần:
**175 → 200 → 200 → 165**. Hero không thể hồi 25 máu. Bốn tiến trình riêng, cùng seed, nên nếu `N` là giây mô
phỏng thì điều này không thể xảy ra: **`N` đếm khung đã dựng, không đếm giây mô phỏng**, và ánh xạ khung→giây
trượt theo tải máy giữa các tiến trình.

Vì vậy bảng trên chỉ ghi **dữ kiện bên trong từng khung**. Không được đọc bộ ảnh như một chuỗi diễn biến: "bị
nhìn, rồi bị chôn, rồi bị vuốt" là câu chuyện do thứ tự tên file gợi ra, không phải thứ bộ ảnh chứng minh. Đây là
**dữ liệu không có thứ tự được bày ra theo một thứ tự** — nguy ở chỗ người đọc không cần hiểu sai, chính cách sắp
xếp đã hiểu sai hộ họ. README nhóm A/B/C đã được sửa câu chữ vì lý do này (một ghi chú cuối trang không thắng nổi
danh sách file sắp theo số).

**2. Dấu vân tay cây mã — và một đính chính cho nhóm A–C.** Lượt chạy suite và lượt chụp của nhóm D dùng
**manifest `git hash-object`** trên mọi file đã sửa trong `src`, `assets/data`, `assets/i18n`, `tests` (bỏ
`.import`/`.uid`), lấy hai đầu và so: suite `c48877c3…` hai đầu, chụp `afe1c704…` hai đầu.

Nhóm A–C ghi "cây mã đứng yên" dựa trên `git status --porcelain -- src | md5sum`. Phép đó **băm tên file và chữ
cái trạng thái, không băm nội dung**: một file đã ở trạng thái ` M` rồi bị sửa tiếp vẫn cho cùng mã. Nó **không**
phát hiện các sửa chú thích trong `combat_view.gd` hôm nay, cũng không phát hiện đổi một dòng trong
`characters.json`. Phép kiểm không sai về thứ nó đo; tôi sai về thứ nó chứng minh.

**3. Một lượt chạy xanh đã bị loại bỏ.** Lượt 5 suite lúc 14:34:15 trả về toàn xanh. Session character sửa
`assets/data/characters.json` lúc 14:36:35 — **giữa lượt chạy**. Một dòng, `accent_color` của Thợ Săn, không dính
gì tới thứ các suite này kiểm (`max_hp`). Lượt đó vẫn bị loại và chạy lại: một lượt chạy bị cắt làm hai trạng thái
cây **không phải kết quả yếu hơn, mà là không phải kết quả** — và nhìn vào đầu ra thì không phân biệt được.

**4. Bốn lỗi của nhóm D đều nằm trong TEST, không lỗi nào trong game.** Dữ liệu `sa_group_d.py` ghi ra không bị
sửa sau khi áp.

| Dòng báo lỗi | Nguyên nhân thật |
|---|---|
| sandfall: it warns / 2x2 / damage / second fall | `get_phase()` không tồn tại (`get_phase_index()`); SCRIPT ERROR cắt cụt hàm nên p2 không bao giờ mở |
| *(y hệt bốn dòng trên)* | `weight: 0.0` là cố ý — planner đúng khi không chọn nó trong thế giới cô lập |
| second fall 30, nhận 40 | helper khớp theo id kỹ năng, bắt phải **đòn đầu của lần tung kế tiếp** |
| second fall 30, nhận 40 | phép đo lấy **hiệu máu qua một cửa sổ**, không phải đòn đánh |

Hai điều đáng giữ: (a) dòng 3 và 4 **cùng thông báo, khác nguyên nhân** — sửa cái đầu không đổi gì trên màn hình,
đúng lúc dễ kết luận "engine hỏng" nhất; (b) lỗi 2–4 đều do chính bản sửa lỗi 1 sinh ra — nâng `weight` để kỹ năng
chịu tung ra là thứ khiến lần tung kế tiếp rơi vào mọi cửa sổ đo. Cả hai đã ghi vào chú thích `_only()` trong
suite.

**5. Đường code lần đầu được dùng lại là phần chắc nhất.** `transition.on_enter` — dữ liệu đầu tiên trong game đi
qua đường này — xanh ngay lần chạy đầu và giữ xanh qua cả bốn lần. Những phần "quen thuộc" mới là nơi hỏng.

**6. `phases[].traits` chỉ được kiểm ở mức HÌNH DẠNG DỮ LIỆU.** Suite khẳng định p2 mang `sandstorm` với
`interval_sec` 9; nó **không** chứng minh phần ghi đè tới được engine, vì `pattern_fixtures.gd` không dựng
TraitHost nên `CombatView._apply_pattern_phase` chưa từng được chạy qua. Đây là dữ liệu đầu tiên đi qua đường đó
nên **không có lần xanh nào trước để so**. Header của suite nêu đúng vật cản này và sẽ sai một cách nhìn thấy được
khi ai đó cắm TraitHost vào fixture.

**7. Banner "Floor 1/7 · Misty Forest · Goblin Scout" và máu quái 90 là của dev launcher,** không phải của Nhân Sư
— `--pattern=` chỉ thay quái của match đầu.
