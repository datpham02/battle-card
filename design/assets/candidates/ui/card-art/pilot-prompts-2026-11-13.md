# Card art — Pilot 3 prompt (2026-11-13)

> **Cập nhật 2026-11-13:** 3 gen pilot đã chạy với cả gpl (bảng cuối file). Người dùng khóa **palette con** —
> Master Reference §4.3. Lần gen tiếp theo (gen lại hay card mới) dùng `--only` của card đó, không dùng cả gpl.
> Gen lại hoa_loi / khien_thep chưa được cho phép.

**Trạng thái ban đầu: chuẩn bị xong, CHƯA GEN.** Mỗi lần gọi = 1 generation và cần người dùng nói "yes" cho **đúng lần gọi đó**.
Không re-roll. Ảnh không đạt → báo người dùng, không tự gen lại.

Theo: Master Reference `design/assets/references/ui/card-art.md` (§3 canvas, §4 palette, §5 cấu hình, §6 hình, §8 hậu kỳ).
Chủ thể: audit `card-art-audit-2026-11-13.md` §6.1 (do_kiem, hoa_loi) và §6.2 (khien_thep), đã ép về màu trong palette.

## Tham số chung (cả 3 lần gọi)

```
tool:                 mcp__pixellab__create_image_pixflux
width / height:       32 / 32
no_background:        true
outline:              "single color black outline"
shading:              "basic shading"
detail:               "low detail"
text_guidance_scale:  8.0
color_image_base64:   <stdout of: python -X utf8 -I design/assets/candidates/ui/card-art/scripts/gpl_swatch.py>
                      (63 colours of art_src/palette/tessera_master.gpl; `--count` prints them)
                      SUPERSEDED 2026-11-13: add --only "<card subset>" (Master Reference §4.3)
seed:                 unset — record the returned seed / job id
view / direction / isometric: unset
negative description: not supported by this tool → the descriptions below are positive-only
```

Style reference `assets/art/cards/hoa_xa.png`: chỉ dùng để so khi QA (tool không có ô style image; Master Reference §2).

## 1. do_kiem — Đỡ Kiếm / Parry (kiem_si, common)

```
game icon: a plain unmarked steel kite shield standing upright with a straight double-edged sword blade
crossing diagonally in front of it, a small square spark where the blade meets the shield rim,
one bold subject centered with an empty 2 pixel margin, Western fantasy, angular geometric shapes,
steel blue-grey #8FA3B8 and pale steel white #EEF4FA metal with dark steel #5F6F82 shading,
ivory #EFE6D2 spark, flat pixel colours, up to 3 shades lit from the top-left, hard pixel edges,
1 pixel dark ink outline, clean readable silhouette
```

| Kiểm | Ghi chú |
|---|---|
| Màu nhấn | Kiếm sĩ `#8FA3B8` / `#EEF4FA` (+ `#5F6F82`), Ngà cho tia — đều trong gpl |
| Hình học Tessera | tia lửa va chạm hình vuông |
| Gần đồ nổi tiếng | Khiên Hylian + Master Sword (Zelda). Khác: khiên thép trơn, không huy hiệu chim, không xanh/đỏ, chuôi kiếm thường |
| Phân biệt trong họ | ngan_kiem = nhiều lưỡi rơi; tram_dia = kiếm cắm đá; thiet_kiem (đã cài) = kiếm chéo **không** khiên → khiên phải là khối chính |

## 2. hoa_loi — Hỏa Lôi / Fire Mine (phap_su, common)

```
game icon: a square charcoal stone sigil plate lying flat, seen slightly from above, with an amber
carved square border and three small stepped square flames rising from its corners,
one bold subject centered with an empty 2 pixel margin, Western fantasy, angular geometric shapes,
charcoal #3A2A26 plate, amber #F0A030 border lines, orange #FF7A1F and gold-orange #FFB21F flames
with ivory #EFE6D2 tips, flat pixel colours, up to 3 shades lit from the top-left, hard pixel edges,
1 pixel dark ink outline, clean readable silhouette
```

| Kiểm | Ghi chú |
|---|---|
| Màu nhấn | Pháp sư `#3A2A26` / `#F0A030`; Cháy `#FF7A1F` / `#FFB21F` — đều trong gpl |
| Hình học Tessera | tấm ấn vuông + ngọn lửa bậc vuông |
| Gần đồ nổi tiếng | không có vật biểu tượng rõ; ghi lại nếu kết quả giống ấn / bẫy của game khác |
| Phân biệt trong họ | hoa_xa = 1 tia; hoa_tran = bát lửa có chân; hoa_tinh = đống than; hoa_tuyen = tường lửa; thien_thach = đá rơi → tấm phẳng vuông là dáng riêng |
| Rủi ro | "border lines" có thể thành ký tự / rune → nếu có chữ hoặc rune: không đạt (§6.6) |

## 2b. hoa_loi — mô tả viết lại (2026-11-13, CHƯA GEN, chờ duyệt)

Vì sao viết lại: v1 (cả gpl) và v2 (palette con) đều ra **tấm/khung vuông, lửa nhỏ hoặc không có lửa**. Chữ
"plate lying flat" + "carved square border" kéo ảnh về dáng khung. Card là mìn lửa: ấn nạp rồi **nổ**, nên chủ thể
mới = **khối ấn đang nổ tung**, lửa chiếm phần lớn khung.

```
game icon: a small square charcoal stone block in three-quarter view at the bottom, its top split open by a
bright orange cross-shaped crack, a big stepped square-cornered flame with three tongues bursting upward out of
the crack and filling most of the picture, charcoal #3A2A26 block with amber #F0A030 edges, orange #FF7A1F flame
with a gold-orange #FFB21F inner flame and an ivory #EFE6D2 core, one bold subject centered with an empty
2 pixel margin, Western fantasy, angular geometric shapes, flat pixel colours, up to 3 shades lit from the
top-left, hard pixel edges, 1 pixel dark ink outline around the whole subject, clean readable silhouette
```

Palette con (Master Reference §4.3, bỏ `#4A4640` của v2 vì phần đá đó là chỗ viền trượt):
`--only "#1B1722,#3A2A26,#F0A030,#FF7A1F,#FFB21F,#EFE6D2"` (6 màu). Tham số còn lại như phần chung.

**Checklist khóa trước khi gen** (đạt hết mới coi là xong; trượt → báo, không tự gen lại):

| # | Kiểm | Đạt khi |
|---|---|---|
| 1 | Lửa là chủ thể | ngọn lửa ≥ 1/2 chiều cao chủ thể; khối đá chỉ ở 1/3 dưới |
| 2 | Dáng Tessera | lửa bậc góc vuông + khối đá vuông |
| 3 | Viền | ≥ 90 % pixel mép chủ thể là Mực `#1B1722` (do_kiem đạt 98 %) |
| 4 | Phân biệt trong họ | tô đen vẫn khác: hoa_xa = giọt lửa tròn không đế; hoa_tran = bát có chân; hoa_tinh = đống than thấp |
| 5 | Màu | chỉ 6 màu palette con; không đỏ, không tím |
| 6 | Chữ / rune | không có ký tự trên khối (vết nứt chữ thập là một nét, không phải chữ) |
| 7 | Vùng an toàn | chủ thể trong 28×28 giữa |

Gần đồ nổi tiếng nhất: **khối Magma của Minecraft** (khối tối có vết nứt cam). Khác ở chỗ: một khối nhỏ đứng ở
góc 3/4 với ngọn lửa bậc lớn nổ phía trên, không phải mặt khối lát phẳng; màu than, không đen-đỏ.

Rủi ro còn lại: ngọn lửa bậc lớn có thể giống hoa_xa → kiểm #4 bằng sheet tô đen.

## 3. khien_thep — Khiên Thép / Steel Ward (chung, common)

```
game icon: a tall square-cornered steel tower shield seen straight from the front, a raised square boss
in the centre and four small square steel rivets in the corners, one bold subject centered with an
empty 2 pixel margin, Western fantasy, angular geometric shapes, steel blue-grey #8FA3B8 face,
dark steel #5F6F82 rim and shading, pale steel white #EEF4FA highlight on the top-left edge,
flat pixel colours, up to 3 shades lit from the top-left, hard pixel edges, 1 pixel dark ink outline,
clean readable silhouette
```

| Kiểm | Ghi chú |
|---|---|
| Màu | thép `#8FA3B8` / `#5F6F82` / `#EEF4FA` — trong gpl. Không phải card anh hùng nên không có màu nhấn riêng |
| Hình học Tessera | khiên chữ nhật góc vuông, núm vuông, đinh vuông |
| Gần đồ nổi tiếng | khiên scutum La Mã (chung chung, không phải nhân vật). Không huy hiệu, không đinh vàng (đinh vàng là của khung card) |
| Phân biệt trong họ | thanh_thuan (sau) = khiên heater màu Giáo sĩ + khung vuông; do_kiem = khiên kite + kiếm |
| Rủi ro | cùng màu thép với do_kiem → so dáng khi QA (§9.3) |

## Sau mỗi lần gen (miễn phí, không cần yes)

1. Tải ảnh về `design/assets/candidates/ui/card-art/pilot/<id>.png`.
2. Hậu kỳ §8: alpha 0 → `#2C2A35`; alpha 1–254 hoặc pixel ngoài gpl → dừng, báo người dùng.
3. QA §9.1–9.4, sheet x4 cạnh `hoa_xa.png`.
4. Registry: `log-event card.<id> generation_completed --job-id ... --candidate ...` (backlog → entry `candidate`; người giữ registry làm).
5. Đưa người dùng xem. Chụp trong game (§9.5) chỉ sau khi người dùng cho cài thử.

| Card | Gen | Trạng thái |
|---|---|---|
| do_kiem | 1 | **đã gen 2026-11-13** (job `c71a2b6c`), candidate `pilot/do_kiem.png`, chờ người dùng xem |
| hoa_loi | 1 | **đã gen 2026-11-13** (job `65e85c75`), candidate `pilot/hoa_loi.png`, chờ người dùng xem; QA §4 viền KHÔNG đạt (sửa lại 2026-11-13) |
| khien_thep | 1 | **đã gen 2026-11-13** (job `145dc5d3`), candidate `pilot/khien_thep.png`; QA §4 viền KHÔNG đạt |
