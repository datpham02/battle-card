# Kế hoạch: pipeline tạo animation asset bằng code cho Tessera ("fxkit")

> **Ngày:** 2026-11-02. **Trạng thái:** ĐỀ XUẤT, chờ người dùng duyệt. Chưa tạo asset, chưa sửa code game.
> **Nguồn:** `docs/research/pixelfx-study.md` (kỹ thuật học từ PixelFX), art bible, ADR-0001 (A1 delivery), ADR-0002
> (sàn phối cảnh), `assets/art/vfx/*/index.json`, `src/art/{vfx_pack,floor_vfx,cast_vfx,sprite_sheet,unit_animator}.gd`,
> `assets/data/{cards,enemy_skills,combat}.json`, `design/quick-specs/phase2-misty-forest-2026-11-01.md`.
> **Ràng buộc của task:** không đổi combat logic, không sửa ADR, không thay asset hiện có. Mọi thứ dưới đây sinh asset
> **mới** đặt cạnh asset cũ; việc trỏ `impact_packs`/`travel_packs` sang pack mới là thay đổi dữ liệu trình bày, làm
> sau khi người dùng duyệt từng pack.

---

## 1. Mục tiêu và nguyên tắc

**Mục tiêu cuối:** mô tả một skill (delivery + impact + ô đích + nhân vật) → sinh ra mọi animation asset của skill đó
(sheet PNG trong suốt + JSON + GIF xem trước), qua kiểm pixel tự động, nhập thẳng vào Godot mà không sửa loader.

**Nguyên tắc (lấy từ PixelFX, ép theo Tessera):**

| # | Nguyên tắc | Nguồn |
|---|---|---|
| N1 | **Hiệu ứng là code theo thời gian, không phải ảnh.** Một component = một hàm `draw(p, t, o)`; sheet chỉ là bản kết xuất. Đổi cỡ ô, palette, seed → render lại, không vẽ lại | PixelFX §1.1 |
| N2 | **Ba lớp tách bạch, ba file dữ liệu:** cell mask (khối) / delivery (travel + timing) / impact (per ô). Pipeline không biết luật sát thương | ADR-0001 A1 |
| N3 | **Chỉ hình vuông và bậc 45°.** Không `circle/ring/arc`, không lưỡi liềm. Primitive duy nhất: `rect`, `poly` bậc thang, `line` Bresenham, `diamond`, `sprite` chuỗi | art bible P1, §3 |
| N4 | **Không light, không glow, không alpha lẻ, không dither** trên sprite/overlay. "Nóng" = bậc Ngà/phần sáng 1–2 khung rồi tụt bậc. Alpha chỉ 0/255 (lớp sàn được phép trộn mờ theo §8.5, nhưng pipeline mặc định 0/255) | P1, §8.3, §8.10 |
| N5 | **Palette khoá:** mọi pixel đục ∈ `art_src/palette/tessera_master.gpl` (+ các màu tín hiệu §4 được duyệt thêm). `#E5293B` bị cấm tuyệt đối trong asset | §4, P3 |
| N6 | **Seed cho mọi ngẫu nhiên**, render hai lần cho cùng khung | PixelFX §1.5 |
| N7 | **Hai lớp depth:** `behind` (= `FloorDynamicLayer`, dưới đơn vị, bị shader phối cảnh nắn) và `front` (= `OverlayLayer`, trên đơn vị, không nắn, không scale) | ADR-0002, `vfx_pack.gd` |
| N8 | **Timing của skill lấy từ data game**, không gõ tay: `combat.json timing.delivery`, `cuts.json swing_*`, `enemy_skills.json windup/warning/recovery`, `clips.json` events | PixelFX §1.7, §1.8 |
| N9 | **Nhìn trước khi tin:** mọi pack có contact sheet + GIF + strip 12 fps, và một GIF **timeline** ghép với sprite thật của Tessera trước khi vào game | PixelFX §2.3, memory "verify before spending" |
| N10 | **Không chữ, không ký hiệu** trong asset (✓/✗ là của code) | §8.10 |

---

## 2. Phân loại animation (sáu nhóm) và nguồn sản xuất

| Nhóm | Định nghĩa | Nguồn | Pipeline này làm gì |
|---|---|---|---|
| **A. Character Animation** | clip thân anh hùng/quái: `idle step cast_gesture hit windup victory defeat down awaken fall` | PixelLab (`/pixellab-animation-engineer`) → `art_src/units/<id>/` → `export_sheets.py` | **Không sinh frame thân.** Đọc `clips.json` + animation sheet (`events: hold/release/recover`) để **đồng bộ** và để ghép GIF timeline. Thêm hai clip dữ liệu cho boss: `windup_heavy`, `phase_shift` khi có sprite |
| **B. Skill VFX (travel)** | phần bay/chạy/rơi từ origin tới ô đích theo delivery | **fxkit** component | `travel_*` packs: `square_streak`, `falling_squares`, `floor_run_squares`, `chain_spark`, `root_crawl`, `flame_gather` |
| **C. Block Animation** | ô đích sáng dần khi niệm, khối vỡ khi Phá phép, khối tan khi hết hạn, khối rơi | hiện vẽ code (`CastFloorFx.charge`, `travel_style.charge`) | fxkit cung cấp component `cell_charge_steps`, `block_shatter_4`, `block_dissolve` **chỉ khi** người dùng muốn thay code bằng sheet; mặc định giữ code (rẻ, đúng cỡ ô) |
| **D. Impact Animation** | hiệu ứng trên từng ô đích lúc RESOLVE | fxkit component | `impact_*` packs cho 11 impact id: `slash burst shatter burn freeze poison knockback guard seal thorns curse` |
| **E. Enemy Hit Reaction** | clip `hit` + nháy trắng + shake + đẩy; (đề xuất) hit-stop | A + data `hit_feel` | Ghi **`react`** trong recipe: `{flash_sec, shake_px, freeze_sec (mặc định 0), push}`; không sửa `CombatView` trong task này |
| **F. Boss Animation** | như A nhưng `footprint` 2×2, neo chân = tâm hàng trước footprint (`_feet_of_unit`), thêm `windup_common/heavy`, `phase_shift`, viền Ngà bất khả xâm phạm | PixelLab khi có sprite; nay là placeholder | fxkit chỉ lo VFX quanh boss (hạt vuông chuyển pha `phase_shift_squares`, mốc rễ) và neo theo footprint |

---

## 3. Kiến trúc pipeline

### 3.1 Ngôn ngữ và vị trí

**Khuyến nghị: Python 3.12, chỉ stdlib**, tại `tools/fx-pipeline/`. Lý do: toàn bộ tooling art hiện có là Python
stdlib (`export_sheets.py` đọc/ghi PNG + ép `.gpl`, `make_gif.py`, `anim_qa.py`, `pngio.py`, `draw_*.py`); không
Pillow, không ffmpeg, không Node trong quy trình hiện tại; một ngôn ngữ cho người bảo trì một mình. Khung hình nhỏ
(≤ 128×128, ≤ 24 khung) nên tốc độ không thành vấn đề.
*Phương án B:* Node ESM chuyển thể trực tiếp `painter.js/particles.js/chain.js` (Node 24 có sẵn) — nhanh hơn để bắt
đầu, nhưng tách khỏi tooling Python và phải viết lại encoder PNG/GIF. Người dùng chọn (Quyết định D2).

```
tools/fx-pipeline/
  fxkit/
    pngio.py        đọc/ghi PNG RGBA (dùng lại logic export_sheets.py / pngio.py)
    gif.py          GIF89a (dùng lại make_gif.py)
    palette.py      đọc .gpl → ramp theo vai trò: block(hero), burn, freeze, thorns, wood, amber, ivory, ink, moss
    rng.py          Rng mulberry32 + rand(seed, i, k) hash
    math_.py        seg, smooth, bump, ease.*
    motion.py       fly/burst/cycle/stream (hạt hàm đóng), Grit (rơi, nảy một lần, nằm)
    painter.py      Frame{behind, front}, place/flip, px/rect/poly45/line/diamond/sprite/mask/outline, màu 0 = không vẽ
    timeline.py     chain(cues) với t/until/x(t); đọc timing từ combat.json/cuts.json/enemy_skills.json
    render.py       frames(component|skill, cell, fps) → list khung; contact sheet; strip 12 fps
    sheet.py        xuất manifest kiểu VfxPack (3.3) hoặc Aseprite (đơn vị)
    check.py        bộ kiểm 3.5
    preview.py      GIF timeline: slab + sprite thật + VFX + flash (3.6)
  components/
    squares.py      square_streak, square_shards, falling_squares, floor_run, chain_spark, square_flash
    flame.py        flame_gather (tích lực), flame_square_burst, flame_column_stepped
    root.py         root_crawl (sàn), root_spike (trồi), root_wrap (Trói, theo mask)
    ice.py          freeze_shell (theo mask), frost_plus (Giá Lạnh)
    misc.py         crack_steps (Rạn), guard_frame, seal_drop, curse_squares, phase_shift_squares
  recipes/          <skill_or_pack>.fx.json  (3.2)
  fxc.py            CLI
  NOTICE.md         MIT: Patch, Hugo Duprez (nếu chuyển thể đoạn code)
  README.md
```

Nguồn **có thể chỉnh sửa** của một animation = `components/*.py` (hình và nhịp) + `recipes/*.fx.json` (tham số, palette,
timing, cỡ ô). Không có file ảnh nguồn; ảnh là sản phẩm.

### 3.2 Recipe: mô tả một skill → asset

```json
{
  "id": "kiem_khi",
  "kind": "player_card",
  "delivery": {"type": "CASTER_TO_TARGET", "origin": "caster", "travel": "square_streak", "impact": "burst"},
  "palette": {"block": "kiem_si", "accent": "ivory"},
  "cells": {"ref": [64, 46], "variants": [[43, 31], [45, 32]]},
  "fps": 20,
  "travel": {"component": "square_streak", "count": 4, "size": 5, "spacing": 6, "sec": "combat.timing.delivery.CASTER_TO_TARGET"},
  "impact_first": {"component": "square_shards", "size": "big", "hold_sec": "combat.timing.delivery.CASTER_TO_TARGET.first_hold_sec"},
  "impact_spread": {"component": "square_shards", "size": "small", "step_sec": "combat.timing.delivery.CASTER_TO_TARGET.spread_step_sec"},
  "body": {"unit": "kiem_si", "clip": "cast_gesture", "hold_frame": "cast.gesture_hold_frame", "release_frame": 5},
  "react": {"flash_sec": "cast.hit_feel.flash_sec", "shake_px": "cast.hit_feel.shake_px", "freeze_sec": 0},
  "layers": {"travel": "front", "impact": "front", "mark": "behind"},
  "seed": 7
}
```

- Giá trị chuỗi dạng `"combat.timing..."` là **tham chiếu** vào `assets/data/*.json` và `assets/art/vfx/cast/index.json`;
  pipeline đọc số thật lúc render (N8). Đổi beat trong data → render lại ra đúng nhịp.
- `delivery` **phải trùng** với `cards.json`/`enemy_skills.json`; `fxc check` so sánh và báo lệch.
- Một recipe → nhiều pack: `travel_<travel>_<block>`, `impact_<impact>_big`, `impact_<impact>_small`, mỗi pack × mỗi
  cỡ ô trong `cells`.

**Ánh xạ delivery → component (bảng chuẩn, tái sử dụng cho mọi skill):**

| Delivery | Origin | Travel component (B) | Thời gian từ data | Impact (D) |
|---|---|---|---|---|
| `CASTER_TO_TARGET` | tay caster (`cast.hand`) → ô đầu | `square_streak` (4 ô vuông bậc thang, đuôi nhỏ dần) | `travel_sec`, `first_hold_sec`, `spread_step_sec` | ô đầu `*_big`, ô sau `*_small` lan BFS |
| `SKY_TO_TARGET` | trên ô `height` px | `falling_squares` (3 ô rơi, bóng vuông trên ô lớn dần) | `fall_sec`, `stagger_sec` | mỗi ô khi chạm |
| `GROUND_PROPAGATION` | `origin_cell`/`first_cell` | `floor_run_squares` hoặc `root_crawl` (vạch chạy trước trên `behind`) | `step_sec` | mỗi ô khi vạch tới |
| `DIRECT_MANIFESTATION` | tại ô | `cell_appear` (ô sáng bậc 2 khung) | `appear_sec` | ngay |
| `SEQUENTIAL_CHAIN` | `first_cell`/`caster` | `chain_spark` (ô vuông nhảy ô→ô, `lift`) | `step_sec`, `chain_order` | theo thứ tự chuỗi |

Khối Pháp sư, Sát thủ… chỉ đổi `palette.block`; cùng component (tái sử dụng như `impact_style.colours = "block"` hiện nay).

### 3.3 Định dạng xuất (khớp loader hiện có, không sửa code)

**VFX pack** = thư mục `assets/art/vfx/<layer>/<pack_id>/` chứa `manifest.json` + `whole.png` (+ `behind.png`, `front.png`
khi có hai lớp), đúng schema `VfxPack` đang đọc:

```json
{
  "app": "tools/fx-pipeline fxc 0.1",
  "name": "Tessera fx - impact burst big (kiem_si block, cell 64x46)",
  "fps": 20, "frame_ms": 50, "frames": 7, "loop": false,
  "canvas": {"w": 80, "h": 72},
  "anchor": {"kind": "ground_center", "x": 40, "y": 60},
  "clips": [
    {"name": "whole", "depth": "both", "loop": false, "start_frame": 0, "frames": 7,
     "frame": {"w": 80, "h": 72}, "sheets": [{"file": "whole.png", "first_frame": 0, "frames": 7, "columns": 7, "rows": 1}],
     "offset": {"x": -40, "y": -60}}
  ],
  "tessera": {"recipe": "kiem_khi", "component": "square_shards", "cell": [64, 46], "palette": ["#8FA3B8", "#EEF4FA", "#EFE6D2", "#1B1722"],
              "seed": 7, "layer": "overlay", "git": "<hash>", "timing_refs": {"first_hold_sec": 0.13}}
}
```

Giới hạn của loader mà pipeline tôn trọng: **một `frame_ms` cho cả pack** (giữ khung = lặp khung), **chỉ sheet đầu**,
**không gutter**, **không scale**. Khối `tessera` là siêu dữ liệu phụ (loader bỏ qua) để truy nguồn.

Đăng ký: thêm mục vào `assets/art/vfx/floor/index.json` (`layer`, `play`, `frames`, `frame_ms`, `anchor`) hoặc
`cast/index.json`; sau đó trỏ `impact_packs.<id>`/`travel_packs.<id>` (hiện `""`) sang pack mới. **Bước trỏ này đổi hình
người chơi thấy nên làm theo từng pack, có duyệt.**

**Đơn vị (nhóm A)** giữ `export_sheets.py` + JSON Aseprite; pipeline chỉ đọc.

### 3.4 Bản ghi timing per skill (`skill_timing.json`, sinh ra, không sửa tay)

Học `actTiming()` của PixelFX: `fxc timeline <recipe> --json` ghi một bản ghi phẳng để người (và test) đọc nhịp của skill
ở một chỗ, thay vì rải 4 file:

```json
{"skill": "kiem_khi", "t0": "launch",
 "body": {"clip": "cast_gesture", "hold_frame": 4, "release_frame": 5, "lead_sec": 0.03},
 "travel": {"from": "hand", "to": "first_cell", "sec": 0.15},
 "hits": [{"cell": 0, "t": 0.15, "pack": "impact_burst_big", "flash_sec": 0.1, "shake_px": 2, "freeze_sec": 0},
          {"cell": 1, "t": 0.28, "pack": "impact_burst_small"}, {"cell": 2, "t": 0.36, "pack": "impact_burst_small"}],
 "ends": 0.72}
```

Nó **không** điều khiển game (game vẫn tính `SkillDelivery.arrival_times`); nó là tài liệu kiểm chứng: `fxc check` so
`hits[].t` với `arrival_times` tính lại từ data, báo lệch > 1 khung.

### 3.5 Kiểm pixel consistency (`fxc check`)

| Kiểm | Mức | Lấy từ |
|---|---|---|
| Mọi pixel đục ∈ palette `.gpl` (+ danh sách màu tín hiệu được phép của recipe) | FAIL | `export_sheets.py` |
| Alpha chỉ 0/255 (trừ pack `behind` được khai `alpha_ok`) | FAIL | §8.3 |
| Có `#E5293B` hoặc màu cách nó < ngưỡng ΔE | FAIL | P3 |
| Vẽ ra ngoài canvas (render với lề 16 px, thử seed 2,3,7) | FAIL + bbox gợi ý | PixelFX check |
| One-shot trống hẳn ở khung cuối + 1 | FAIL | PixelFX |
| Loop: diff khung cuối→đầu ≤ 2× bậc 90 % diff khung-khung | warn | PixelFX |
| Determinism: render 2 lần giống hệt | FAIL | PixelFX |
| Không `random.random()`/`time` trong component | FAIL | PixelFX |
| **Chỉ hình vuông:** mỗi cụm liên thông có tỉ lệ pixel/bbox ≥ 0,9 hoặc là bậc thang 45° (kiểm bằng độ dốc cạnh) | warn → FAIL khi `strict` | N3 |
| Hạt lẻ: pixel đơn không thuộc cụm ≥ 2 px, trừ hạt được khai `grit` | warn | ART_QA B |
| ≤ 128 ô vuông/khung | warn | §8.5 |
| Overlay `front` trên đơn vị ≤ 0,35 s; pack sàn không giới hạn | FAIL | §1 Hệ quả kỹ thuật |
| Cỡ khung chẵn, ≥ 1 px trong suốt quanh (trừ hàng chân pack sàn) | FAIL | §8.3 |
| JSON khớp PNG (cols×rows ≥ frames, kích thước) | FAIL | ART_QA E |
| `delivery` trong recipe trùng `cards.json`/`enemy_skills.json` | FAIL | N2 |
| `hits[].t` khớp `SkillDelivery.arrival_times` (tính lại trong Python theo cùng công thức) | warn | 3.4 |
| Chạy thêm `pixelart_workbench lint/score` (PixelLab, miễn phí) khi có MCP | ghi log | ART_QA B |

### 3.6 Xem trước

- `fxc render <pack>`: `records/<pack>/contact.png` (16 khung, zoom 4) + `all.png`.
- `fxc gif <pack>`: `anim.gif` (zoom 4) + `strip12.png` (bước 12 fps liên tiếp).
- `fxc compare <pack-a> <pack-b>…`: các nháp cùng hàng.
- `fxc timeline <recipe>`: GIF **ghép**: phiến từ `candidates/misty-forest/slab v4` (hoặc hình chữ nhật 3 tông), lưới
  ô đích theo recipe, sprite thật từ `art_src/units/<id>/` chạy clip theo `events` (hold → release), VFX đúng giờ
  `arrival_times`, nháy trắng + shake trên mục tiêu, telegraph đỏ sọc vẽ bằng code (chỉ ở preview, không vào asset).
  Đơn vị **chưa có sprite** (Pháp sư, Phù thủy) → hình bóng xám phẳng đúng cỡ khung, không chữ.
- Lưu bằng chứng: `production/qa/evidence/fx-pipeline/<pack>/{contact,anim.gif,strip12,timeline.gif}`; cuối cùng vẫn
  phải chụp **trong game** (`--demo`, `--write-movie`) theo luật "a parse check is not a run".

### 3.7 Đặt tên và lưu trữ

| Thứ | Vị trí | Tên |
|---|---|---|
| Code pipeline | `tools/fx-pipeline/` | như 3.1 |
| Recipe | `tools/fx-pipeline/recipes/<skill_id>.fx.json`, hoặc `<pack_id>.fx.json` cho pack không gắn skill | id trùng `cards.json`/`enemy_skills.json` |
| Pack ứng viên (chưa duyệt) | `design/assets/candidates/fx-pipeline/<pack_id>/` (có `.gdignore`) | |
| Pack đã duyệt | `assets/art/vfx/floor/<pack_id>/` (lớp sàn và overlay một lần) · `assets/art/vfx/cast/<pack_id>/` (gắn tay caster) · `assets/art/vfx/status/<pack_id>/` | `<group>_<family>_<variant>`: `travel_square_streak_steel`, `impact_burst_big_steel`, `impact_burn_square_small`, `root_crawl_wood`, `root_spike_wood_c64x46` |
| Biến thể cỡ ô | hậu tố `_c<w>x<h>` khi có nhiều cỡ; không hậu tố = cỡ tham chiếu 64×46 (quy ước `fill/ref_cell` hiện nay) | |
| Bằng chứng | `production/qa/evidence/fx-pipeline/<pack_id>/` | `NN-mota.png`, `anim.gif`, `timeline.gif` |
| Spec/log | `design/assets/specs/fx-pipeline-assets.md` (mỗi pack một hàng: ngày, recipe, seed, cỡ, check, verdict) | |

Màu theo chất liệu dùng tên chất liệu tiếng Anh ngắn: `steel` (Kiếm sĩ), `charcoal` (Pháp sư), `ice` (Sát thủ), `wood`
(Thợ săn), `glass` (Giáo sĩ), `ivory` (địch).

### 3.8 Nhập vào Godot

1. `fxc install <pack> --to floor|cast|status` chép thư mục vào `assets/art/vfx/<layer>/<pack_id>/`, thêm mục
   `index.json` (chưa trỏ `impact_packs`).
2. Mở project một lần (hoặc `godot --headless --import`) để sinh `.png.import`; kiểm `.import` có `compress/mode=0`
   (Lossless), `mipmaps=false`; commit `.import` cùng PNG (quy ước hiện tại).
3. Test: thêm case vào `tests/unit/art/vfx_pack_test.gd` (manifest nạp được, số khung, offset) và
   `floor_vfx_test.gd` (index có pack). Suite phải xanh.
4. Trỏ `cast/index.json` `impact_packs.<impact>` / `travel_packs.<travel>` sang pack mới **theo quyết định riêng của
   người dùng**; chụp bằng chứng trong game `production/qa/evidence/fx-pipeline/`.
5. Cỡ ô: giai đoạn 1 dùng cỡ tham chiếu 64×46 + `fill/ref_cell` như pack hiện có (không sửa code). Giai đoạn 2 (story
   riêng, cần duyệt): `FloorVfx` chọn biến thể `_c<w>x<h>` gần cỡ ô thật nhất → hiệu ứng đúng pixel trên mọi sân.

---

## 4. Ba prototype đề xuất (chưa làm, chờ duyệt)

Chung: fps 20 (50 ms/khung, giữ khung = lặp), cỡ ô tham chiếu 64×46 + biến thể 43×31 (sân 5×5), seed cố định, palette
từ `.gpl` + màu tín hiệu §4. Mỗi prototype ra: pack PNG+manifest, contact, GIF, strip 12 fps, **timeline GIF ghép sprite
thật**, log `fxc check`. Không gọi PixelLab (0 gen).

### 4.1 Knight — Square Sword Wave (`kiem_khi`, CASTER_TO_TARGET → `burst`)

| Khâu | Nội dung |
|---|---|
| Thân (A) | `kiem_si` `cast_gesture` v4 có sẵn: giữ khung 4 (coil) suốt telegraph, khung 5 = chém (release), 6–8 recovery. Không sinh frame mới |
| Travel (B) | `square_streak_steel`: 4 ô vuông 5 px bậc thang từ tay (`cast.hand` [14,−34]) bay thẳng theo hàng tới ô đầu trong `travel_sec` 0,15 s; đầu Ngà `#EFE6D2`, thân thép `#8FA3B8`, đuôi nhỏ 3→2 px rồi rụng; echo thứ hai trễ 1 khung mỏng hơn (học sword-slash) |
| Impact ô đầu (D) | `impact_burst_big_steel`, canvas 80×72, neo `ground_center`: khung 0 hero-frame **diamond Ngà** `\|dx\|+\|dy\| ≤ 6` + 4 cạnh vuông; khung 1–2 vỡ thành 10–14 mảnh vuông 2–3 px (`Grit`, nảy một lần), khung 3–6 rụng + tụt bậc về thép → Mực; `first_hold_sec` 0,13 s |
| Impact lan (D) | `impact_burst_small_steel` 48×40: 5–7 mảnh, 5 khung, phát từng ô theo BFS cách `spread_step_sec` 0,08 s |
| React (E) | flash 0,1 s + shake 2 px từ `hit_feel`; `freeze_sec` 0 (ghi 0,06 trong recipe làm **đề xuất**, không bật) |
| Timeline | GIF: coil hold 0,4 s → release → bay 0,15 s → big burst → lan 2 ô → fade. Mục tiêu: goblin_scout `hit` 3×40 ms |
| Check riêng | mảnh không vượt ô kề quá 4 px (N3 spill), ≤ 0,35 s trên `front` |

### 4.2 Fire Mage — Square Flame Impact (`hoa_tran`, DIRECT_MANIFESTATION → `burn`)

| Khâu | Nội dung |
|---|---|
| Thân (A) | **Pháp sư chưa có sprite** → timeline dùng bóng xám 96×70 làm chỗ đứng, cử chỉ = dịch bóng 2 px về trước 2 khung (chỉ để canh giờ). Ghi rõ trong GIF là placeholder (bằng màu, không chữ) |
| Tích lực (B) | `flame_gather_charcoal` trên `behind`, loop 0,4 s: 6–8 ô vuông 2 px hổ phách `#F0A030` **hút vào tâm ô** từ mép phiến (học STREAK/`charge-up`), thân ô sáng dần 3 bậc `#3A2A26 → #FF7A1F`; không glow; chạy trong `appear_sec`/thời gian niệm |
| Impact (D) | `impact_burn_square_big_charcoal` 72×80 `front`: khung 0 hero-frame cột vuông Ngà 6 px; khung 1–3 **cột lửa bậc thang** 3 tầng (`#FF7A1F` thân, `#FFB21F` đỉnh, `#3A2A26` chân, sọc ngang 1 px theo art bible "lửa bậc thang + sọc ngang") mọc 2 bậc `outBack` rồi hạ; khung 4–6 vỡ 8 mảnh vuông cam rụng + 3 ô xám bậc 1 bay lên (thay khói); tổng ≤ 0,35 s |
| Dấu để lại | bàn giao cho pack `burning_cell` loop có sẵn (không thay) |
| React (E) | flash + shake; không freeze |
| Timeline | 3 ô L: cả 3 ô tích lực đồng thời (DIRECT) → nổ đồng loạt (`appear_sec` 0) → `burning_cell` |
| Check riêng | không có pixel nào gần `#E5293B` (cam phải giữ ΔE); palette thêm `#F0A030, #FF7A1F, #FFB21F, #3A2A26` cần duyệt vào `.gpl` (D4) |

### 4.3 Forest Witch — Root Propagation (`branch_lattice`, GROUND_PROPAGATION → `thorns`)

| Khâu | Nội dung |
|---|---|
| Thân (F) | **Phù thủy chưa có sprite**, footprint 2×2 → timeline dùng đa giác bóng 96×80 trên 2×2 ô, wind-up 0,5 s = bóng hạ 2 px; viền Ngà quanh 4 ô cho 3 chiêu nặng (code có sẵn, chỉ mô phỏng) |
| Telegraph | đỏ sọc 45° đậm dần suốt `warning_sec` 1,2 s, **vẽ code trong preview**, không nằm trong asset |
| Travel (B) | `root_crawl_wood` trên `behind`: vạch nứt 1 px Mực chạy trước (`outCubic`), theo sau là **thân rễ 2–3 px bậc thang** `#B89A6A`/gỗ tối, rẽ nhánh 1 lần mỗi ô, bước ô→ô theo `GROUND_PROPAGATION.step_sec` 0,06 s (học thorns "seam races ahead") từ `first_cell` của L qua 2 ô còn lại rồi ô followup |
| Impact (D) | `root_spike_wood` 64×60 `front`, neo `ground_center`: khung 0 trắng Ngà 1 khung; khung 1–2 gai vuông 2 tông trồi `outBack` 8→14 px (2–3 gai lệch pha) + 6 mảnh đất vuông bay; khung 3–5 giữ có 1 px nhấp; khung 6–7 chìm; ≤ 0,35 s. Sau đó bàn giao cho `thorn_spikes`/Bãi Gai nếu skill để lại dấu (branch_lattice không) |
| React (E) | người chơi `hit`, flash, shake; Trói (`root_nail`) dùng `root_wrap` theo mask — **không** trong 3 prototype, ghi là bước sau |
| Timeline | windup 0,5 s → warning 1,2 s (ô đỏ đậm dần, chưa có rễ) → RESOLVE: rễ bò từ ô đầu của L theo `arrival_times` (0,06 s/ô) → gai trồi ở mỗi ô khi rễ tới → followup 1 ô cảnh báo 0,75 s rồi trồi gai. Rễ là travel nên chỉ chạy sau cảnh báo, không gây sát thương ngoài ô đích |
| Check riêng | `behind` pack chịu nắn phối cảnh: vẽ vạch theo trục ô, không chéo tự do, để sau khi nắn vẫn thẳng cạnh ô |

### 4.4 Thứ tự làm và điểm dừng duyệt

1. **fxkit lõi + check + render/gif** (không asset) — 1 phiên. Điểm dừng: `fxc check` chạy sạch trên một component mẫu.
2. **Prototype 1** (Kiếm sĩ, có sprite thật) → candidates + timeline GIF → **người dùng xem**. Sửa 2–3 vòng theo bảng
   "you see → fix".
3. **Prototype 2, 3** → candidates → xem.
4. Khi duyệt: `fxc install` + test + chụp trong game; trỏ `impact_packs/travel_packs` **từng cái** theo lời người dùng.
5. Mở rộng: 11 impact × chất liệu, 5 travel, overlay trạng thái theo mask (Trói/Đóng Băng/Rạn cho mọi cỡ sprite kể cả
   boss 2×2), biến thể cỡ ô (story loader), `skill_timing.json` làm tài liệu cho mọi skill.

Ước lượng (chưa đo): bước 1 ≈ 1 phiên; mỗi prototype ≈ nửa phiên + vòng sửa; bước 5 theo từng batch.

---

## 5. Quyết định cần người dùng

| # | Câu hỏi | Khuyến nghị |
|---|---|---|
| D1 | **Cỡ khung canon** cho tài liệu: 32×48/48×64 (art bible §3) hay 96×70/64×52 (đã cài, §8.3)? | Giữ cỡ đã cài; pipeline không gắn cứng; sửa art bible §3/P2 ở task khác |
| D2 | **Ngôn ngữ pipeline**: Python stdlib (khớp tooling) hay Node (chuyển thể PixelFX trực tiếp)? | Python |
| D3 | **Khung màu theo ramp** (như pack PixelLab hiện nay) hay **khung 3 xám tô bằng `modulate`** (art bible §3, một bộ cho 5 anh hùng)? | Màu theo ramp render sẵn mỗi chất liệu: cùng code, 5 lần render, không cần shader/modulate, kiểm palette được bằng máy. Xám-tô chỉ khi ngân sách VRAM ép |
| D4 | Thêm màu tín hiệu vào `tessera_master.gpl` (16 → ~24: Cháy, hổ phách, Đóng Băng, Giá Lạnh, gỗ, rêu)? | Có, theo §4 art bible, ghi ở đầu `.gpl` |
| D5 | **Hit-stop** (`freeze_sec` ~0,06 s) có được đưa vào `hit_feel` không? Đụng `CombatView` nên ngoài task này | Để 0 trong recipe; quyết sau prototype 1 |
| D6 | Biến thể theo cỡ ô (sửa `FloorVfx` nhỏ) hay chỉ cỡ tham chiếu 64×46 + crop như nay? | Giai đoạn 1 tham chiếu; giai đoạn 2 biến thể |
| D7 | Prototype 2 và 3 dùng **bóng xám placeholder** cho Pháp sư/Phù thủy, hay chờ sprite PixelLab? | Placeholder để duyệt nhịp VFX; sprite làm sau với `/pixellab-animation-engineer` |
| D8 | Có cho chạy `node tools/render.mjs` trong clone PixelFX để so sánh trực quan (bị chế độ auto chặn)? | Không cần cho kế hoạch này; chỉ khi muốn benchmark hình |

Chỉ sau khi người dùng trả lời D1–D7 (hoặc "làm theo khuyến nghị") thì bắt đầu bước 1 của §4.4.
