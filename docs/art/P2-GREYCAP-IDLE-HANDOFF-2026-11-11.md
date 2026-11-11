# P2 Greycap idle — handoff cho session sau

Ngày: 2026-11-11. Pilot `greycap_sporeling` dừng sau khi user duyệt prompt. Chưa có generation.

Đọc kèm `docs/art/P1-HANDOFF-2026-11-11.md`. File này không sửa file đó.

## Việc session sau được làm

Chỉ khi user viết một câu riêng, rõ, cho phép gọi đúng một job PixelLab với các tham số ở mục "Job chưa được gọi" bên dưới.

Trước câu đó:

- Không gọi PixelLab. Kể cả `get_balance` và `get_pro_flash_capabilities`.
- Không tải frame, không tạo thư mục candidate, không chạy `candidate.py`.
- Không export sheet, không sửa `clips.json`, không đổi Registry, không đổi GPL, không commit, không push.

Handoff này không phải câu cho phép đó.

## Đã xong

- P2.0: user chọn `greycap_sporeling` (`unit.greycap_sporeling`), forest, quái thường.
- P2.1: đối chiếu Master Reference, spec ASSET-022, registry, GPL, `RENDER-STANDARDS.md`, `clips.json`, `art_src/units/greycap_sporeling/idle/0.png` (IHDR 64×52).
- Palette gate mở vì `palette_status` là `group_assigned_not_per_creature`, Master Reference có trên đĩa, và 8 hex sheet đều nằm trong `art_src/palette/tessera_master.gpl`.
- User duyệt prompt có điều kiện: sửa cách đếm frame. Bản dưới đây là bản đã sửa. Bản cũ nói mũ về vị trí ban đầu ở "frame 4". Clip chỉ có frame 0, 1, 2, 3. Câu đó đã bỏ.

## Không được làm

- Không regen sheet rừng.
- Không ghi đè `art_src/units/greycap_sporeling/`.
- Không ghi đè `assets/art/units/unit_greycap_sporeling_sheet.png`.
- Không ghi đè `assets/art/units/unit_greycap_sporeling_sheet.json`.
- Không dùng clip `windup` làm pose. Model từng tô đỏ cả thân. Snap sau đó thành khói xám-tím.
- Không thêm hex. Không lấy màu nhân vật khác. Không sửa GPL. Không set `palette_status: locked`.
- Không đổi `status` hoặc `acceptance`. Entry hiện tại: `status: approved` (2026-11-02, user), `acceptance: unknown`. Generation mới không làm acceptance thành accepted.
- Không biến concept thành anchor. Không có concept image. Anchor là `art_src/units/greycap_sporeling/idle/0.png`.
- Working tree đang bẩn từ P0, post-P0 và P1. Không reset, clean, stash, checkout đè.

## Identity đã khóa

Nguồn: `design/assets/specs/misty-forest-roster-assets.md` ASSET-022 và `design/assets/references/characters/greycap_sporeling.md` §1. Không thêm chi tiết.

- Ba nấm xám-tím xỉn trên một thân ngắn.
- Một mũ lớn có đốm, hai mũ nhỏ hai bên.
- Thân ngà, gốc rêu, khe mắt dưới mũ lớn, chấm bào tử nhạt.
- Không glow, không mũ thứ tư, không tay, không mặt người.
- Frame 64×52. Hướng sheet trái, view PixelLab south-west. Chân hàng cuối, feet x = 32. Viền 1 px `#1B1722`. Alpha 0 hoặc 255.
- Được nhích 1–2 px như thở. Không đổi tỉ lệ, không đổi chân, không thêm phụ kiện.

Spec còn chữ "7 colours" và "29×47". Sheet meta có 8 màu, Ink tính vào. Chưa đo lại 29×47 trên PNG. Không bỏ màu và không thêm màu để "sửa" chỗ này.

Character id ghi trong reference: `5705da35-be85-49c2-9704-555fbe8c755e`. Chưa hỏi server. Có thể chết lúc gọi.

## Palette được dùng

Đúng 8 hex. `animate_character` không nhận palette target. Snap local sau khi có frame. Pixel ngoài list là FAIL.

| Hex | Việc |
|---|---|
| `#1B1722` | Ink, viền |
| `#4A3E4A` `#6A5868` `#8E8296` | Mũ. Comment GPL gán cho Greycap |
| `#D8CDB0` | Thân ngà. Swatch dùng chung, không phải ramp riêng |
| `#4A5545` `#5E6B55` | Rêu gốc |
| `#EFE6D2` | Chấm bào tử và khe mắt |

## Motion đã duyệt

4 frame × 250 ms, loop, tổng 1 s. Đây là metadata dự kiến cho candidate, chưa ghi vào `clips.json`.

| Frame | Chuyển động | Giữ nguyên |
|---|---|---|
| 0 | Pose anchor, ghim | Toàn bộ |
| 1 | Mũ lớn lên 1 px | Gốc, chân, rộng thân, hình mũ |
| 2 | Mũ lớn giữ +1 px. Hai mũ bên lên 1 px | Gốc và chân |
| 3 | Cả ba mũ về đúng pose frame 0 | Gốc và chân |

Loop nối frame 3 về frame 0. Clip thiết kế không có frame thứ năm.

## Job chưa được gọi

Chỉ gửi đúng các giá trị này, một lần, sau câu cho phép riêng.

- Tool: `animate_character`
- `mode`: `v3`
- Character: `5705da35-be85-49c2-9704-555fbe8c755e`
- Direction: `south-west` only
- `frame_count`: `4`
- `keep_first_frame`: `true`
- `enhance_prompt`: `false`
- Seed: không set
- Start frame lúc gọi: `art_src/units/greycap_sporeling/idle/0.png`
- Không dán base64 vào tài liệu

`subject_description`:

```
a squat greycap sporeling, one large dull grey-violet cap, two small side caps, an ivory stem, a mossy root base, eye slits under the big cap, pale spore dots
```

`initial_pose`:

```
low top-down south-west, big cap over the ivory stem, small caps at the sides, mossy roots on the bottom row, feet centred
```

`action_description`:

```
Idle breathing loop, four frames numbered 0, 1, 2 and 3, facing south-west. Frame 0 stays the pinned start pose. On frame 1 the big cap rises one pixel. On frame 2 the big cap stays one pixel higher and the two side caps rise one pixel. On frame 3 all three caps return to the frame 0 pose. The root base and both feet stay on the same pixels. Cap shapes, body width, and the one-pixel dark outline stay unchanged. Flat colour bands only.
```

API không có ô negative. Đoạn sau chỉ dùng cho QA và snap:

Không đỏ `#E5293B`, không cam, không glow, không gradient, không antialias, không mũ thứ tư, không tay, không mặt người, không vòng vàng, không bước chân, không phình thân kiểu windup, không hex ngoài 8 màu trên.

## Nếu receipt không phải 4 file

Tài liệu skill nói `keep_first_frame` true có thể lưu thêm frame nguồn (ví dụ xin 8 thì lưu 9). Xin 4 có thể nhận 5. Clip là bốn frame đầu, đúng motion 0–3 ở trên. File thừa không cài, không mô tả thêm vào prompt, không tự gọi job thứ hai.

## Chi phí

Chưa có receipt. Không gọi balance.

Nếu canvas generate giữ 64×52 và 4 frame: `ceil(64×52×4 / 65536) = 1` generation, một chiều, không cộng 0.05. Nếu canvas bị phóng, số generation tăng. Doc không có ví dụ cho 64×52. Đây không phải giá đã chốt.

Mode `v3` vì bảng skill đặt custom motion ở sprite khoảng ≤ 64 px vào v3. Các clip cũ của con này dùng pixminimax. Không đổi engine nếu không hỏi user. Không dùng template `breathing-idle`. Đó là skeleton người.

## Nơi ghi output, khi nào được ghi

Chỉ sau job thành công và trong đúng scope đã duyệt:

`design/assets/candidates/greycap_sporeling/idle-2026-11-11/raw/`

Dùng `python -X utf8 -I tools/asset-pipeline/candidate.py new` để có `metadata.json` và `QA.md`. Ghi job id, tool, prompt motion, seed nếu server trả. Không copy vào `art_src/` và không export production.

## QA sau khi có frame

Chưa chạy. Khi có frame:

- 64×52. Frame 0 trùng anchor nếu `keep_first_frame` đúng.
- Chân không đổi hàng, feet x không đổi.
- Chỉ 8 hex. Viền 1 px `#1B1722`. Alpha 0/255.
- Ba mũ còn đủ. Nhịp là thở, không phải bước và không phải windup.
- Số liệu PASS không phải visual acceptance. User xem contact sheet rồi mới nói acceptance.

## Git lúc viết file này

`main` ngang `origin/main`. Cây làm việc vẫn bẩn. File này là untracked mới. Không stage gì khác.
