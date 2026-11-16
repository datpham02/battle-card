# Dáng đứng trên sàn — đo, chẩn đoán, và hai giả thuyết bị bác bỏ

**Ngày:** 2026-11-16 ~23:0x · phiên `monster-cast-anim` · Godot 4.6.3 stable.
**Lệnh:** `godot --audio-driver Dummy --path . -s res://tools/qa/stance_probe.gd -- <out> ch1 goblin_scout`

Người dùng nói dáng đứng của nhân vật và quái trên sàn "nhìn chưa ổn". Tài liệu này ghi phép đo đã làm,
hai giả thuyết bị chính phép đo bác bỏ, và nguyên nhân thật.

## 1. Vị trí đứng KHÔNG sai

`stance_probe.gd` hỏi thẳng engine, cho **cả 35 ô**: rect phẳng của ô, mốc chân nó tính, bốn đỉnh hình thang
đã vẽ, trọng tâm hình thang đó.

| Phép đo | Kết quả |
|---|---|
| Mệnh đề kẹp `min(tâm_ô, đáy_ô − 3)` có kích hoạt không | **không, 0/35 ô** |
| Chân so với trọng tâm ô đã vẽ | **−1,0 px** (hàng 0–2), **−1,5 px** (hàng 3–4) |
| Rect phẳng mỗi ô | 64×46, **đồng đều mọi hàng** |

**Giả thuyết 1 (mệnh đề kẹp đẩy chân ra mép trước ô): BÁC BỎ.** Mệnh đề kẹp chạy trên rect *phẳng*, mà rect
phẳng đồng đều mọi hàng (phối cảnh áp sau), nên nó không bao giờ thắng.

**Giả thuyết 2 (warp của tâm hình thang lệch khỏi trọng tâm): CÓ THẬT NHƯNG BẰNG 1,5 PX.** Đúng về cơ chế,
vô nghĩa về độ lớn. Không ai nhìn thấy 1,5 px.

Luật "đơn vị đứng giữa ô" đang được tuân thủ. **Sửa offset ở đây là sửa một thứ không hỏng.**

## 2. Nguyên nhân thật: kích thước, và một luật cũ nói ngược

> **ĐÃ SỬA cùng ngày — đọc Mục 5 trước khi trích dẫn mục này.** Phần dưới đo BỀ NGANG, và kết luận
> "45/68 con quá nhỏ" cùng "thứ tự theo bậc bị đảo" là **SAI**: chúng sinh ra từ việc đo sai trục.
> Giữ nguyên ở đây làm hồ sơ, không xoá — nhưng đừng dùng số của mục này.

Ô rộng 64 px. Bề ngang thân, đo trên khung `idle` của từng sheet:

| Bậc | n | Thấp nhất | Cao nhất |
|---|---|---|---|
| Quái thường | 47 | **`wisp` 19 px = 30 %** | `swamp_lizard` 49 px = 77 % |
| Tinh Anh | 13 | `leap_frog` 31 px = 48 % | `fire_eater` 60 px = 94 % |
| Kẻ Gác / boss | 8 | `mist_lord` 36 px = 56 % | `forest_witch` 151 px = 236 % (khối 2×2) |

Ba điều hỏng:

1. **Khoảng 45 / 68 con dưới 60 % bề ngang ô.**
2. **Trong cùng một bậc chênh 2,5 lần** — `wisp` 30 % và `swamp_lizard` 77 % đứng trên hai ô y hệt nhau.
   Đây là thứ mắt bắt được; con số tuyệt đối thì không.
3. **Thứ tự theo bậc bị đảo** — Tinh Anh `leap_frog` 48 % nhỏ hơn quái thường `swamp_lizard` 77 %;
   Kẻ Gác `mist_lord` 56 % nhỏ hơn hàng chục quái thường.

### Luật cũ nói NGƯỢC, và không ai cưỡng chế

`design/art/art-bible.md` §5.2 **đã có** luật từ 2026-10-29: *"Quái thường ≤ 34 px"*, *"Tinh Anh ≤ 40 px"*.
Đó là **trần trên**, và trên ô 64 px thì 34 px = **53 %** — tức luật cũ *yêu cầu* quái chỉ chiếm nửa ô, ngược
hẳn với điều người dùng nói ("quái phải to gần hết bề ngang ô").

Và nó đang bị phá rộng rãi vì **không phép kiểm nào đọc §5.2**:

| Nhóm | Vượt trần cũ |
|---|---|
| Quái thường, vùng mới | 21 / 40 |
| Quái thường, Rừng Sương | 2 / 6 |
| Tinh Anh (trần 40 px) | **10 / 13** |

Nên bức tranh không phải "thiếu luật" mà là "có luật, nói ngược, và trôi mất vì không ai đo".

## 3. Đã làm gì

- **Thay hẳn luật** (người dùng chốt 2026-11-16): art bible §5.2 nay đo **theo tỉ lệ với ô**, không theo px
  tuyệt đối — quái thường 70–85 %, Tinh Anh 90–105 %, Kẻ Gác/boss một ô 110–130 %, Kẻ Gác khối 2×2 giữ nguyên.
  Các khoảng **không chồng nhau**, nên bậc trên chắc chắn to hơn bậc dưới chứ không chỉ "nên to hơn".
- **Thêm phép kiểm `scale` vào `tools/qa/art_check.py`**, mức **WARNING, không phải FAIL**. Lý do: lúc chốt
  luật có **56 / 65** con ngoài khoảng, nên FAIL sẽ khoá commit art của cả 15 phiên cho tới khi gen lại xong
  roster. Một cổng không ai qua nổi sẽ bị tắt, và khi đó nó không bảo vệ gì nữa.

### Phép kiểm đã được thử cả hai chiều

Một phép kiểm luôn cho cùng một câu trả lời thì không mang tin tức nào, nên nó được chạy trên hai tập:

| Tập | Kết quả |
|---|---|
| 5 con tôi đã đo là **trong** khoảng (`swamp_lizard`, `mire_slug`, `dire_wolf`, `sand_beetle`, `hell_knight`) | **PASS** |
| 4 con tôi đã đo là **ngoài** khoảng (`wisp`, `frost_sprite`, `leap_frog`, `mist_lord`) | **WARNING**, nêu đúng 4 |

Bộ giải mã PNG mới trong `art_check.py` cũng được đối chiếu với bộ giải mã khác (`export_sheets.read_png`)
trên ba sprite: `wisp` 19, `swamp_lizard` 49, `inferno_lord` 69 — **khớp cả ba**.

## 4. Chưa làm

- **Chưa gen lại con nào.** Pixel art không phóng được phi nguyên lần, nên đưa một con về khoảng đúng nghĩa
  là gen lại từ đầu. 56 con ngoài khoảng, phải chia đợt và mỗi đợt người dùng duyệt riêng.
- Phép đo chỉ chạy trên arena `square` của `ch1`. Arena khác có hình ô khác; kết luận ở Mục 1 chưa kiểm trên
  những arena đó.
- Ảnh `stance_ch1_goblin_scout.png` chụp lúc 23:0x trên cây dùng chung với 15 phiên khác, nên nó bắt được cả
  việc dở dang của họ.


---

## 5. SỬA LẠI (cùng ngày, 2026-11-16 ~23:4x): Mục 2 đo sai trục

Trước khi tiêu tiền gen lại theo luật ở Mục 3, tôi tra giá: **11 generation mỗi con** (1 nhân vật Pro Flash
64×64 = 6, cộng 5 clip). Tám con đầu = 88 generation. Số đó buộc phải kiểm lại luật, và luật sai.

### Mười hai con "quá hẹp" đều đã cao gần hết ô

| Con | Rộng | Cao | % ngang ô | **% cao ô** |
|---|---|---|---|---|
| `wisp` | 19 | 51 | 30 % | **111 %** |
| `frost_sprite` | 22 | 45 | 34 % | **98 %** |
| `goblin_scout` | 26 | 46 | 41 % | **100 %** |
| `zombie` | 26 | 46 | 41 % | **100 %** |
| `cultist` | 28 | 47 | 44 % | **102 %** |

Chúng là **nhân hình: cao và mảnh**. Những con "rộng" (`mire_slug` 47×26, `sand_beetle` 46×36) là **thú bốn
chân: thấp và bè**. Cái Mục 2 gọi là "chênh 2,5 lần trong cùng một bậc" thực ra là **người so với thú**.

Luật ở Mục 3, nếu thi hành, sẽ kéo mọi goblin / ma / giáo sĩ rộng gần gấp đôi — **biến nhân hình thành khối
lùn bè** — với giá 88 lần gen.

### Đo theo trục lấp đầy ô thì roster KHÔNG hỏng

Độ hiện diện = `max(rộng/64, cao/46)`:

| Bậc | Khoảng | Trung bình |
|---|---|---|
| Quái thường | 73–**113 %** | 97 % |
| Tinh Anh | **120**–172 % | 153 % |
| Kẻ Gác | 172–207 % | 190 % |
| Boss | 163–185 % | 175 % |

Các bậc **tách sạch**, **không một trường hợp đảo bậc nào**. Khẳng định "thứ tự theo bậc bị đảo" ở Mục 2 là
sai. Chỉ **8/46** quái thường dưới 85 %, và cả tám là sinh vật thấp lè tè đúng thiết kế.

### Thủ phạm còn lại: hero to ngang Tinh Anh

| | Độ hiện diện |
|---|---|
| Quái thường | 97 % |
| **Năm anh hùng** | **137–150 %** |
| Tinh Anh | 120–172 % |

Hero nằm **trong dải Tinh Anh**. Và đó là **chủ ý đã ghi**: art bible §8.3 nói Goblin Scout *"khoảng 70 %
Kiếm sĩ"*; đo thật 46/65 = **71 %**. Game chạy đúng tài liệu; thứ người dùng không ưng là chính chủ ý đó.
Đổi nó là quyết định thẩm mỹ riêng, **chưa chốt**.

### Luật và phép kiểm đã sửa

art bible §5.2 và `art_check.py` nay dùng độ hiện diện: quái thường 85–115 %, Tinh Anh 120–175 %,
Kẻ Gác/boss một ô 160–210 %. Các dải lấy **từ chính số đo roster**.

Thử lại cả hai chiều sau khi sửa:

| Tập | Trước (đo bề ngang) | Sau (đo độ hiện diện) |
|---|---|---|
| 5 nhân hình cao-mảnh | WARNING (kết tội oan) | **PASS** |
| 3 sinh vật thấp bè | — | **WARNING**, nêu đúng 3 |
| Toàn roster | 56/65 ngoài dải | **6/65** ngoài dải |

Bộ giải mã PNG được mở rộng sang hai trục và đối chiếu lại với `export_sheets.read_png` trên ba sprite:
`wisp` (19,51), `mire_slug` (47,26), `inferno_lord` (69,79) — khớp cả ba, cả hai chiều.

### Điều đáng mang đi

Phép đo đầu tiên **đúng về con số và sai về đại lượng**. 19 px là số thật; nó chỉ không phải thứ cần đo.
Cái bắt được sai lầm không phải sự cẩn thận — mà là câu hỏi "cái giá là bao nhiêu" hỏi trước khi trả tiền.
