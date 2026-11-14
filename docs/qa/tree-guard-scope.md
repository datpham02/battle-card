# Chốt chặn cây mã: phạm vi là một phần của kết quả

Một lượt chạy dài (suite, sim, hay chụp ảnh) chỉ đáng tin nếu cây mã **đứng yên** suốt lượt. Chốt chặn làm việc
đó bằng cách băm một tập file ở hai đầu và so.

**Luật trung tâm: không có một phạm vi chung cho mọi lượt chạy, và mỗi hàm manifest phải IN phạm vi của nó ra
cùng kết quả.** Một manifest không nói nó che cái gì sẽ bị đọc rộng hơn mức nó chịu được.

## Vì sao không có phạm vi chung

Hai loại lượt chạy hỏi hai câu khác nhau:

| Loại | Câu hỏi | `.import` là gì |
|---|---|---|
| Suite logic headless | *code có đổi không* | **nhiễu** — bản import tự sinh ra nó |
| Lượt chụp ảnh | *thứ hiện ra màn hình có đổi không* | **nội dung** — đổi nó là đổi khung hình |

Ngày 2026-11-14 có ba dụng cụ chạy trên cùng một cây với ba nghĩa khác nhau của chữ "cây ổn định", và không dụng
cụ nào nói ra nghĩa của mình. Hậu quả không phải một lượt chạy hỏng, mà là **đổ oan**: hai file `design/` bị nghi
cắt ngang một lượt chạy, trong khi thủ phạm thật là một file `tests/` ghi trước đó ba phút.

## Danh sách loại trừ, không phải danh sách cho phép

Với một chốt chặn, **mặc định phải là băm tất cả**, rồi loại trừ những gì **chứng minh được** là không bao giờ
được nạp. Danh sách cho phép mà thiếu một mục thì chốt chặn im lặng yếu đi và không ai biết; danh sách loại trừ
mà thiếu một mục thì chốt chặn chỉ rộng hơn cần thiết.

Mỗi mục loại trừ phải kèm **bằng chứng**, không phải cảm giác. Bằng chứng cho phạm vi suite logic của nhóm
Monster Skill Phase 2 (grep chạy ngày 2026-11-14):

| Loại trừ | Bằng chứng |
|---|---|
| `docs/**` | không một dòng `res://docs/` nào trong `src`, `tests`, `tools` |
| `production/**` | **không bao giờ được ĐỌC, chỉ được GHI** — `skill_v2_batch*_evidence.gd`, `world_map_v2_evidence.gd`, `tools/audio/skill_timeline_dump.gd` xuất vào đó. Nếu băm nó, **một suite ghi bằng chứng sẽ tự làm lệch manifest của chính lượt chạy chứa nó** |
| `design/**` **trừ** `design/assets/candidates/**` | 4 suite art đọc `candidates/` (`art_assets`, `pixelfx_adapter`, `sheet_export` so từng byte, `vfx_pack`). Phần còn lại, kể cả `asset-registry.yaml`, không chỗ nào nạp — grep `asset-registry` trong `src`/`tests`/`tools` rỗng |
| `*.import`, `*.uid` | sidecar do chính bản import sinh ra |

**Phạm vi này KHÔNG dùng lại được cho một lượt chụp ảnh.** Một lần chụp phụ thuộc `assets/art/**`, `*.tscn`,
`project.godot` và cả `*.import` — mượn nguyên hàm này sẽ báo "cây ổn định" trong khi backdrop vừa bị thay.

## Nguồn danh sách: `ls-files`, không phải `status`

`git status --porcelain` so cây làm việc với **INDEX/HEAD**, nên nó liệt kê *file đang bẩn*. Hệ quả:

1. **Nó mù với toàn bộ phần sạch**, trong khi một lượt chạy nạp cả cây.
2. **Một `git commit` làm nó lệch dù không byte nào trên đĩa đổi** — các dòng ` M` biến mất.

Điểm 2 từng đẻ ra một luật xã giao ("đừng commit khi người khác chạy"). Luật đó yếu: nó sẽ bị phá bởi người mới,
hoặc bởi chính mình lúc vội. Thay nguồn danh sách thì dụng cụ tự miễn nhiễm:

```sh
{ git ls-files; git ls-files --others --exclude-standard; } \
  | grep -E '<đuôi file trong phạm vi>' | sort -u \
  | while read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done > "$list"
git hash-object --stdin-paths < "$list" | paste -d' ' - "$list"
```

Đo trên repo nháp (2026-11-14):

```
1. cây bẩn:                           8a1ca9a6…
2. sau git add:                       8a1ca9a6…   không đổi
3. sau git commit:                    8a1ca9a6…   không đổi
4. sau khi xoá b.json (chưa git rm):  edc18231…   ĐỔI, exit=0
```

**Chưa che:** `git rm`, `git mv`, đổi `.gitignore`, `git checkout` nhánh khác. Cả bốn đổi danh sách đường dẫn nên
gần như chắc chắn làm lệch — nhưng "gần như chắc chắn" là lập luận, không phải đo.

### Hai cái bẫy trong chính đường ống đó

**`[ -f ]` là bộ lọc DANH SÁCH, không phải thân vòng lặp băm.** `git ls-files` liệt kê theo index, nên file đã
xoá khỏi cây mà chưa `git rm` vẫn trong danh sách, và `git hash-object --stdin-paths` gặp đường dẫn không tồn tại
sẽ **chết giữa chừng** (exit 128) — mọi đường dẫn đứng sau không bao giờ được băm. Ai hứng stdout mà không kiểm
`$?` nhận một manifest **ngắn nhưng đúng định dạng**, và hai lượt cắt cùng chỗ **so ra bằng nhau**, tức PASS.

**Cái đắt là sinh tiến trình, không phải vòng lặp.** Gọi `git hash-object` từng file: **1 phút 21 giây** cho 1254
file. Cùng vòng lặp đó chỉ để test `[ -f ]` rồi `--stdin-paths` một lần: **0,84 giây**.

## Hai câu hỏi trước khi ghi bất cứ thứ gì vào repo

1. **`git status --porcelain` có in ra khác đi sau hành động này không?** Tạo file: CÓ (hiện dạng `??`). Sửa:
   CÓ. Xoá: CÓ. **Commit: CÓ** (với manifest kiểu `status`). Ghi vào scratchpad hay memory: KHÔNG.
2. **Nếu CÓ: người đang giữ máy đã nhắn "khe là của bạn" chưa, và tôi đã nhắn lại "tôi xong rồi" chưa?**

Chỉ hai tin nhắn đó đổi được câu trả lời. Danh sách tiến trình **không** phải tín hiệu: runner sinh **một tiến
trình Godot cho mỗi suite**, nên một lượt chạy đầy đủ là 320+ PID lần lượt hiện rồi thoát, và mẫu nào cũng trông
như máy rảnh.

**Không hỏi nội dung.** Ngày 2026-11-14 có ba lần một phiên thay phép thử cơ học bằng phán đoán nội dung — "file
này không ai dùng chung", "không suite nào nạp nó", "nó ở thư mục khác" — và **cả ba lần phán đoán đều ĐÚNG**.
Vẫn hỏng cả ba.

## Chốt chặn hỏng về phía nào

Khi viết bất kỳ chốt chặn nào, hỏi: **nếu cái này hỏng, nó có hỏng theo cách mà một người KHÔNG để ý vẫn nhận ra
không?**

Hỏng **chặt** thì tự tố cáo trong một lượt chạy. Hỏng **lỏng** thì không bao giờ có triệu chứng — không ai bị
chặn, không lượt nào đỏ — và thứ duy nhất sai là **câu bạn đi nói với người khác** về thứ chốt chặn che được.

Ví dụ thật: bộ lọc loại trừ đầu tiên viết là `grep -vE '^design/(?!assets/candidates/)'`. **ERE không có
lookahead** — `(?!...)` bị hiểu theo nghĩa đen, mẫu không bao giờ khớp, `grep -v` **không loại gì cả**. Chốt chặn
rộng y như cũ, không ai mất gì, và nó sẽ sống nhiều tuần.

**Một bộ lọc chưa chạy thử trên dữ liệu giả là một lời khẳng định, không phải một chốt chặn** — y như một
regression test chưa từng thấy đỏ. Và phép thử phải có **cả hai phía**: chỉ thử các đường dẫn *phải bị loại* thì
một mẫu không khớp gì cả vẫn xanh.
