# Monster cast animation — Đợt 1, sáu boss

**Chụp:** 2026-11-16 21:45:44 và 21:45:46 (giờ máy), phiên `monster-cast-anim`.
**Build:** Godot 4.6.3 stable official (khớp bản đã ghim). Cây mã `main`, HEAD `8f7ed329`.
**Lệnh:** `godot --audio-driver Dummy --path . -s res://tools/qa/inferno_lord_heavy_footage.gd -- production/qa/evidence/monster-cast-anim`,
chạy sau `--import` (cache `.godot/imported/unit_inferno_lord_sheet.png-*.ctex` 21:45:19, mới hơn PNG 21:41:12).

## Hai ảnh

| File | Kỹ năng | `interruptible` | Clip trên màn hình (harness tự khai) |
|---|---|---|---|
| `windup_lord_brand_0020ms.png` | `lord_brand` | mặc định (ngắt được) | `windup` |
| `heavy_lord_cinder_lane_2240ms.png` | `lord_cinder_lane` | `false` | **`windup_heavy`** |

Cả hai ra từ **một tiến trình, một trận**, chọn theo **trạng thái** `PatternController` chứ không theo số khung
(`--shot-frame=N` đếm khung đã dựng, không đếm giây mô phỏng).

## Cái này chứng minh được gì

**Clip mới thật sự chạy.** Dòng log `clip_on_screen=windup_heavy` đến từ `UnitLayer.get_current_clip()`, không
phải từ việc nhìn ảnh. Đây là bằng chứng quyết định, vì khi sheet thiếu clip thì `_update_clip` (`unit_layer.gd:999`)
**lặng lẽ** rơi về `windup` và hai bức ảnh chụp ở hai thời điểm khác nhau của cùng một clip vẫn trông khác nhau
đủ để qua mắt người đang mong nó chạy.

## Ba điều nó KHÔNG chứng minh được — đọc trước khi trích dẫn

1. **Không so được chiều cao giữa hai ảnh.** Con boss đã **đổi ô** trong 2,2 giây giữa hai lần chụp, và sàn có
   phối cảnh nên mỗi hàng một tỉ lệ khác nhau. Số đo thô: windup `48x148 px`, heavy `70x144 px` — tỉ lệ rộng/cao
   0,32 → 0,49, hợp với dáng quỳ, **nhưng hai con số này thuộc hai tỉ lệ vẽ khác nhau** nên không phải một phép so
   sánh hợp lệ. Muốn so đúng phải ghim con boss ở cùng một ô cho cả hai lần chụp.
2. **Nền KHÔNG phải nền Hoả Ngục.** Ảnh hiện nền Rừng Sương dù HUD ghi "Caldera". Nguyên nhân là lối chạy
   `enter_test_floor` không đặt `chapter_id` vào `match_params`, nên `ArtAssets.region_for_match` trả về
   `DEFAULT_REGION = "forest"` (`art_assets.gd:47,134`). Đây là **giới hạn của harness**, không phải lỗi game —
   nhưng nó có nghĩa là hai ảnh này **không nói gì** về diện mạo của vùng Hoả Ngục.
3. **Chỉ một quái, một clip.** Không nói gì về `phase_shift`, về 5 boss còn lại, hay về 15 quái khác đang
   thiếu clip.

## Cây mã lúc chụp

Checkout dùng chung với 15 phiên khác. Lúc 21:47:09 có **568 mục** trong `git status --porcelain`, nên ảnh chụp
bắt được cả việc dở dang của phiên khác, không riêng việc của phiên này. Đáng kể nhất:

- `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` — dirty, của phiên region-enem.
- `assets/art/ui/climb/stair_*.png`, `audio_src/pixellab/ambience/*.wav`, `assets/art/icons/` — untracked, của các phiên khác.
- Của chính phiên này: `art_src/units/inferno_lord/{clips.json, windup_heavy/}`,
  `assets/art/units/unit_inferno_lord_sheet.{png,json}`,
  `design/assets/candidates/hellfire/inferno_lord/**/windup_heavy/`, `tools/qa/inferno_lord_heavy_footage.gd`.

Không mục nào trong số đó thay đổi sprite của Inferno Lord, nên chúng không ảnh hưởng tới điều hai ảnh này khẳng định.

## Nguồn clip

PixMiniMax `animate_image_pixminimax`, job `39d167f6-3228-4c52-a9be-0755cd62144c`, **1 generation**, người dùng
duyệt trong phiên. Anchor là `frame_000.png` dùng chung của cả 5 clip cũ (md5 giống hệt nhau ở idle/step/windup/hit/down).
Khung thô giữ ở `design/assets/candidates/hellfire/inferno_lord/download/Idle/animations/windup_heavy/south-west/`.
Dọn cơ học: cắt alpha <128, snap về 7 màu đã khoá, xoá cụm <12 px, dịch ngang +1 (suy từ cặp raw→clean của idle,
kiểm chứng trên hai khung windup khác), chân xuống hàng đáy. Chọn khung 3/4/6/8; bỏ khung 5 vì có một vệt sáng
`#EFE6D2` chỉ xuất hiện đúng một khung.


---

# Đợt 1 đầy đủ — 12 clip, 6 boss (2026-11-16 ~22:1x)

**Lệnh:** `godot --audio-driver Dummy --path . -s res://tools/qa/boss_cast_footage.gd -- <out> <chapter> <match_id>`,
một tiến trình cho mỗi boss, chạy sau `--import`.

| Boss | `phase_shift` | `windup_heavy` | Kỹ năng |
|---|---|---|---|
| inferno_lord | ✅ clip=phase_shift | ✅ clip=windup_heavy | `lord_eruption_call` |
| sand_sphinx | ✅ | ✅ | `sphinx_sandfall` |
| toad_matriarch | ✅ | ✅ | `matriarch_toxic_croak` |
| ogre_king | ✅ | ✅ | `ogre_club` |
| mist_lord | ✅ | ✅ | `mist_lord_whiteout` |
| storm_dragon | ✅ | ✅ | `dragon_tempest` |

Mỗi dòng `SHOT` in ra tên clip `UnitLayer` đang thực sự vẽ. **Đó mới là bằng chứng; bức ảnh chỉ cho thấy nó trông
ra sao.** Một sheet thiếu clip sẽ rơi về `windup` trong im lặng (`unit_layer.gd:999`).

## Lần chạy đầu HỎNG — giữ lại ở đây vì nó dạy hai điều

Lần chạy 22:0x bắt được 2 trên 12 ảnh. Hai lỗi, cả hai nằm trong harness, không nằm trong clip:

1. **Bốn boss treo cho tới hết giờ.** Kỹ năng không-ngắt-được của `sand_sphinx`, `toad_matriarch`, `mist_lord`,
   `storm_dragon` **chỉ có ở pha 2**, mà harness lại đợi chụp `heavy` xong mới hạ máu sang pha 2 — một vòng khoá
   chết. Đã sửa: hạ máu NGAY khi trận bắt đầu.
2. **Hai ảnh `phase_shift` thật ra là clip `hit`.** `hit` xếp trên `phase_shift` trong `UnitLayer.clip_for`, nên
   cú `damage_enemy` ép sang pha 2 che mất đúng khoảnh khắc cần chụp. Trạng thái nói "đang đổi pha", màn hình vẽ
   "đang trúng đòn". Đã sửa: chỉ chụp khi **tên clip trên màn hình** khớp với clip cần tìm, không chụp theo trạng
   thái. Hai ảnh sai đã xoá, không giữ làm bằng chứng.

Điều đáng mang đi: **cái engine quyết định không phải cái đang ở trên màn hình.** Và lần chạy hỏng đã *báo* hỏng
thay vì lặng lẽ cho qua — đó là lý do duy nhất khiến hai lỗi này nhìn thấy được.

## Nới khung — và phép kiểm đi kèm

Bốn boss phải nới khung cho tư thế mới: inferno_lord 108x86→116x86, sand_sphinx 106x86→106x87,
ogre_king 96x84→100x85, storm_dragon 100x96→**128x98**. `body_h` giữ chiều cao khung cũ nên HUD không xê dịch.

Nới khung là cách kinh điển để dời toàn bộ sprite mà không ai hay. Phép kiểm: so độ lệch tâm thân so với mốc chân
và khoảng đệm đáy, giữa bản gốc trong `candidates/clean-*` (không đụng tới) và bản đã nới trong `art_src`, trên
mọi khung của clip cũ (idle/windup/hit/down, cả 6 nhân vật). **0 khung lệch.**

## Vẫn chưa chứng minh được

- Nền trong mọi ảnh là Rừng Sương, không phải nền vùng thật (lý do ở mục trên: `enter_test_floor` không đặt
  `chapter_id`). Các ảnh này **không nói gì** về diện mạo từng vùng.
- Không so được kích thước giữa hai ảnh của cùng một boss: sàn có phối cảnh, mỗi hàng một tỉ lệ.
- 15 quái khác vẫn thiếu clip (`guard`/`brace` 7 con, `howl` 3 con, `windup_heavy` 2 con) — đợt 2 và 3.
