# Nghiên cứu PixelFX: kỹ thuật nên học cho pipeline animation của Tessera

> **Ngày:** 2026-11-02. **Nguồn:** clone `https://github.com/patch-gg/pixelfx` (v0.3.0, 244 hiệu ứng, 313 file)
> tại `C:\WorkSpace\research\pixelfx` (ngoài source game, không import vào Godot).
> **Đã đọc:** README, `docs/AUTHORING.md`, `docs/CATALOG.md`, `skills/pixelfx/SKILL.md`, toàn bộ `src/core/*`
> (fx, painter, color, math, particles, sim, chain, act, actor, rig, scene), toàn bộ `tools/*.mjs`, và các ví dụ
> `melee/sword-slash`, `ice/frost-nova`, `explosions/small-explosion`, `moves/sword-combo`, `moves/fireball-throw`,
> `moves/earth-stomp`, `nature/earth-spike`, `nature/root-snare`, `nature/thorns`, `fire/fireball`,
> `impacts/hit-spark`, `impacts/impact-frame`, `projectiles/magic-missile`, `status/burning` cùng các `_lib.js`.
> **Chưa chạy:** `node tools/render.mjs` (chế độ auto từ chối chạy code tải về; không cần cho báo cáo này).
> **Kế hoạch áp dụng:** `docs/plans/animation-pipeline.md`.

---

## 0. Kết luận trong năm dòng

1. PixelFX không phải thư viện sprite: **mỗi hiệu ứng là một hàm vẽ theo thời gian**, xuất ra sprite sheet khi cần.
   Đây là ý tưởng đáng học nhất: Tessera có thể **mô tả skill bằng dữ liệu, render ra PNG + JSON bằng code**, và
   render lại ở mọi cỡ ô (38×27 … 64×46 art-px) mà không vẽ lại.
2. Ba lớp tách bạch của nó khớp với ADR-0001 A1 của Tessera: **hiệu ứng** (impact), **move = chuỗi cue có thời gian**
   (delivery), **act = thân người làm gì và khi nào** (character animation + hit-stop + phản ứng mục tiêu).
3. Phần **không lấy**: light buffer/glow, khói trong mờ, dither Bayer, vòng tròn/vành, bảng đỏ-lửa, nhân vật mẫu
   24×38 và skeleton. Tất cả vi phạm art bible P1/§8.10 hoặc luật "đỏ chỉ cho báo đòn".
4. Bộ công cụ **render → nhìn → sửa → check** (contact sheet, strip 12 fps, check spill/seam/determinism) là quy
   trình nên sao chép nguyên tắc, viết lại cho ràng buộc pixel của Tessera (palette .gpl, alpha 0/255, chỉ hình vuông).
5. Giấy phép MIT; nếu chuyển thể code (không chỉ ý tưởng) phải giữ dòng copyright Patch + Hugo Duprez; font
   `gallery/fonts` không được dùng.

---

## 1. Kiến trúc PixelFX (cách tạo pixel-art effect bằng code)

### 1.1 Một hiệu ứng = một file, hai dạng

| Dạng | Export | Khi nào | Cách scrub/xuất sheet |
|---|---|---|---|
| **Pure** | `draw(p, t, o)` (+ `drawBack`) | loop, aura, beam, critter | khung tại `t` tính trực tiếp từ `t`, nên loop không mối nối, nhảy tới khung bất kỳ |
| **Simulated** | `create(o) → { update(dt), draw(p), drawBack(p) }` | one-shot có mảnh vỡ, tia lửa, khói | runtime bước `update` ở **≥ 120 Hz** (`fx.js` chia `dt` thành `ceil(dt·120)` bước) nên cùng seed cho cùng kết quả ở mọi fps |

`meta` bắt buộc: `name, desc, tags, size [w,h], origin [x,y], duration, loop, fps, bg, options { palette, seed, … }`.
`origin` là **điểm neo trong canvas** (chân nhân vật, điểm va chạm, tâm ô). Mọi hiệu ứng vẽ quanh (0,0) cục bộ,
x sang phải, y xuống; hiệu ứng có hướng luôn quay phải, painter lo `flip`/`angle`.

### 1.2 Hai buffer: `color` và `light`

`createFrame(w,h)` tạo `color: Uint32Array` (pixel đục, hoặc fade bằng **dither Bayer 4×4** trong `Painter.put`, hoặc
blend thật bằng `blendPx`) và `light: Uint32Array` (**cộng màu additive**, `Painter.add`). `composite()` trộn: màu lên nền,
rồi cộng light; trên nền trong suốt light biến thành màu có alpha. Toàn bộ "độ nóng" của hiệu ứng PixelFX nằm ở light.

**Đối với Tessera:** art bible P1 ("chỉ Khối phát sáng"), §8.10 ("không glow, bloom"), yêu cầu "không hiệu ứng quá nhiều
ánh sáng" → **bỏ light buffer**. Thay bằng **"bậc nóng" của ramp**: 1–2 khung đầu dùng màu phần sáng/Ngà, rồi tụt bậc.
Ý "hai buffer" vẫn giữ nhưng đổi nghĩa: **`floor` (dưới đơn vị) và `front` (trên đơn vị)**, trùng với
`FloorDynamicLayer`/`OverlayLayer` của game và trường `depth: behind|front` trong manifest pack hiện có.

### 1.3 Painter: biến đổi cục bộ → màn hình, vẽ theo ô pixel

`painter.js` (353 dòng) là phần đáng chuyển thể nhất:
- `place(x, y, flip, angle)` rồi `cellX/cellY` làm tròn **tâm ô pixel**, nên lật/xoay vẫn rơi đúng ô, không nửa pixel.
- `each(x0,y0,x1,y1, fn)` duyệt mọi pixel màn hình có tâm nằm trong hộp cục bộ → nền của mọi hình tô (`shade`, `rect`,
  `poly`, `circle`, `ring`, `arc`, `beam`). Với Tessera chỉ cần `rect`, `poly` (bậc thang 45°), `line` Bresenham, `sprite`
  (từ chuỗi ký tự), `mask`/`outline` (viền 1 px quanh silhouette).
- Màu `0` = "không vẽ gì" nên không bao giờ xóa pixel đã có; `fade` nhân alpha toàn hiệu ứng (dùng cho `stop()` loop).
- `p.sprite(rows, pal, x, y, {scale, flip, tint})`: sprite tí hon viết bằng chuỗi `"..##.."`. Rất hợp cho **hạt vuông
  2×2, mảnh 3×3, dấu chất liệu** của Tessera.

### 1.4 Màu: ramp tối→sáng, `fit()` và `at()`

`color.js`: palette là **ramp hex tối→sáng**; `fit(ramp, n)` resample về đúng n bậc để code đánh chỉ số `C[5]` với mọi
palette; `at(ramp, t)` chọn **một bậc, không trộn** ("pixel art picks a color, it doesn't fade between two");
`blend()` chỉ dành cho light. `resolveOptions()` resample mọi option là ramp. 27 ramp sẵn (`PAL.fire, ice, poison…`).

**Cho Tessera:** cùng cơ chế nhưng ramp là **tập con của `tessera_master.gpl`** theo vai trò: `block` (thân/phần sáng
của khối anh hùng), `burn`, `freeze`, `thorns`, `wood`, `ivory`, `ink`. Không có `blend()`. Không có ramp nào chứa
`#E5293B`.

### 1.5 Ngẫu nhiên có seed, ba cách

| Cách | Hàm | Dùng cho |
|---|---|---|
| Hash thuần | `rand(seed, i, k)` → cùng số mọi khung | hạt trong effect **pure**: vị trí hạt i tại t là hàm đóng |
| Rng mulberry32 | `new Rng(seed)`, `.range/.int/.chance/.pick/.gauss` | effect **simulated**, tạo một lần trong `create` |
| Rng theo hạt | `rng(seed, i)` | `burst(n, seed, fn)`, `cycle(...)`, `stream(...)` |

`tools/check.mjs` fail nếu file chứa `Math.random`. Chuỗi cue (`chain`) cho mỗi cue seed = `seed + i` để hai cue cùng loại
không trùng hạt.

### 1.6 Hạt không mô phỏng (`particles.js`) và hạt mô phỏng (`sim.js`)

- **Closed-form**: `fly(x,y,vx,vy,t,g,drag)` cho vị trí tại t có trọng lực + drag tuyến tính (nghiệm giải tích);
  `burst` (n hạt một lần), `cycle` (hạt lặp chu kỳ, **loop không mối nối**), `stream` (emitter từ t0 đến t1). Hạt là hàm
  của t → scrub, xuất sheet từng khung, không cần state.
- **Simulated** (`sim.js`, chuyển thể từ Sprite Fusion): `Particles` với 12 loại (`SPARK` kéo dài theo tốc độ và nảy sàn,
  `GRIT` rơi nảy một lần rồi nằm, `STREAK` tụ năng lượng, `STAR` nhấp nháy, `SMOKE/VAPOUR/DUST` đĩa trong mờ, `FIRE`
  nguội dần theo `FIRE_RAMP`, `BRAND` rơi xuống châm `Blazes`…), `Bits` (mảnh cứng xoay, nảy, nằm yên), `Lights`
  (lóe rồi tắt theo life²), `Blazes` (lửa nhỏ nơi mảnh rơi). `GRAVITY = 950 px/s²`.

**Cho Tessera:** lấy `fly/burst/cycle/stream` và hai loại hạt: **GRIT** (mảnh vuông rơi, nảy một lần, nằm) và một loại
mới **SQUARE** (ô vuông 1–3 px, kéo dài thành bậc thang theo tốc độ thay vì vạch chéo). Bỏ SMOKE/VAPOUR/DUST/FIRE/Lights.

### 1.7 Easing, timing, pha

`math.js` có `seg(t,t0,t1)` (tiến độ 0..1 trong cửa sổ), `smooth` (smoothstep), `bump` (0→1→0), bộ `ease.*`
(`outQuart`, `outExpo`, `outBack`, `outElastic`…). Hiệu ứng viết thành **hằng số pha** ở đầu file
(`const UP = 0.34, RISE = 0.09, CRACK = 1.18, SPLIT = 1.5…` trong `earth-spike`) và mọi `hits` của act trỏ vào đúng
hằng số đó, không gõ tay thời gian ("the hit lands out of sync → move the hit key to the effect's own constant").

Nhịp chuẩn mà AUTHORING.md và SKILL.md đúc kết ("The bar", 10 điểm): **vào nhanh, ra chậm**; 1–2 khung trắng "hero
frame" lúc bung; hit 0,3–0,8 s; one-shot phải **trống hẳn tại t = duration**; nhiều sự kiện nhỏ lệch pha nhau.

### 1.8 Wind-up, attack, impact, hit-stop, recovery: `act`

`act.js` (chuyển thể cách Hollow Crown chơi skill):

```js
export const act = {
  target: { x: 58 },
  poses: [[-0.55, GUARD], [-0.3, WIND], [0, CUT, "snap"], [0.06, DOWN, "snap"], [0.86, GUARD]],
  hits:  [{ t: 0.06, stop: 0.14, shake: 0.18, amp: 2, push: 2.8, straw: 18, skin: "char" }],
  dust:  [{ t: 0.06, x: 16, n: 7, dir: 1 }],
};
```

- **t = 0 là khung đầu của hiệu ứng**; key âm là wind-up; key sau `duration` là recovery.
- `poses` nội suy; `"snap"` giữ pose cũ rồi nhảy (khung release), `"out"` nhanh rồi dịu, `"in"` chậm rồi nhanh. Chi vẫn
  **bước 12 fps** (`poseAt` làm tròn `(t−t0)·12`) để đọc như vẽ tay, riêng vị trí chân mượt.
- `hits[].stop` = **hit-stop**: `createAct.update()` dừng **mọi thứ** (effect, thân, mục tiêu) trong `stop` giây;
  `shake/amp` ném cả bức ảnh (`act.shake` trả `[sx, sy]` để host dịch canvas); `push` đẩy mục tiêu trên lò xo
  (`Target.step`: `omega += (-60θ − 3,4ω)dt`), `skin` nhuộm mục tiêu (char/ice/shock…), `flash` trắng, `shiver`.
- `actTiming(mod)` xuất act thành **dữ liệu thuần** cho game có nhân vật riêng: `{ windup, recovery, hits:[{t, freeze,
  shake, amp, push, skin}], poses }`. Sheet JSON mang nó ở `meta.pixelfx.act`. Đây chính là điểm nối với Tessera:
  **không dùng skeleton của PixelFX, chỉ dùng cấu trúc timing**.
- `tools/check.mjs` kiểm act: key đúng thứ tự, field pose hợp lệ, hit nằm trong act, `stop > 0,3 s` → cảnh báo
  "reads as a stall", tay nhảy > 30 px trong một bước 12 fps → cần thêm key hoặc `"snap"`.

### 1.9 Move = chuỗi hiệu ứng (`chain.js`)

```js
export const create = chain([
  { fx: charge,   t: 0.08, until: THROW, palette: PAL.fire },
  { fx: fireball, t: THROW, until: HIT, x: (t) => 28 + (t - THROW) * SPEED, y: -22 },
  { fx: blast,    t: HIT,   x: TX },
]);
```

Mỗi **cue** = effect con + `t` bắt đầu + `until` cắt + `x,y` (số hoặc **hàm của thời gian** → projectile là effect có
`x(t)`) + option riêng. Từ ngoài nhìn vào, move vẫn là một effect bình thường (play, recolor, export).
`shiftKeys/shiftHits` dịch pose/hit của effect con theo thời gian và x để ghép act của move (`sword-combo` ghép 3 act).

**Đây là mô hình đúng cho `delivery` của Tessera:** `CASTER_TO_TARGET` = cue travel với `x(t)` từ tay tới ô đầu, cue
impact ở `t = HIT`, các cue impact nhỏ ở `HIT + k·spread_step_sec`; `SEQUENTIAL_CHAIN` = n cue impact cách nhau
`step_sec`; `GROUND_PROPAGATION` = cue floor_run với `x(t)` chạy trên sàn.

### 1.10 Hiệu ứng trên thân (`actor`, `onBody`)

Effect có `meta.actor` nhận `o.actor = { mask, pixels, x, y, w, h, head, chest }` = silhouette + màu của nhân vật đứng
yên; `status/burning` đọc viền (`shape(a)`) để đặt điểm cháy, nhuộm `pixels` thành trắng 1 khung mỗi tick, vẽ vết than
trên áo; `actorAlpha(t)` ẩn nhân vật gốc khi effect tự vẽ thân. Với act `onBody: true`, mỗi pixel của pose biết nó từ pixel
nào của thân đứng, nên frost/poison **bám theo pose**.

**Cho Tessera:** nhân vật là frame PixelLab, không phải rig, nên phần "bám theo pose" không áp dụng. Nhưng ý **"effect
đọc mask của sprite"** rất hợp để sinh overlay trạng thái theo silhouette (vỏ băng vuông = `outline(mask)` 1 px; gai Trói
quanh chân = hàng dưới của mask), thay cho pack PixelLab cố định theo một frame (hiện `frame_kind_of` trong
`unit_layer.gd` ép mọi địch, kể cả Phù thủy 2×2, dùng pack cỡ goblin).

### 1.11 Tái sử dụng một hiệu ứng cho nhiều skill

Ba đòn bẩy, theo thứ tự rẻ → đắt:
1. **Option**: `palette`, `seed`, `flip`, `angle`, `light` + knob riêng (`radius`, `height`, `count`, `reach`). Lửa xanh =
   `{"palette": PAL.ice}` không sửa code. `resolveOptions` resample ramp nên palette 4 bậc hay 8 bậc đều chạy.
2. **Chain**: ghép effect sẵn thành move khác (fireball-throw = spell-charge + fireball + small-explosion).
3. **`_lib.js` theo nhóm**: `melee/_lib` (swing, smear, trace, shavings), `nature/_lib` (stoneShape, drawRock,
   drawSpike, floorCrack, drawLeaf), `impacts/_lib` (spikes, star, brokenRing, makeCracks, dustRing),
   `status/_lib` (shape, tongue, ember, icon), `fire/_lib` (flameTongue, firePuff, looped). Hiệu ứng mới = tổ hợp
   primitive + hằng số pha.

Tessera đã làm 1 ở mức dữ liệu (`impact_style.colours = "block"` tô theo khối anh hùng); thiếu 2 và 3.

---

## 2. Quản lý khung, sprite sheet và metadata

### 2.1 Render khung (`tools/lib/fxlib.mjs: renderFrames`)

`n = round(duration · fps) + (loop ? 0 : 1)` khung; mỗi khung `inst.update(1/fps)` rồi vẽ **hai lần**: `shown` (có nền +
nhân vật mẫu, để nhìn) và `bare` (chỉ hiệu ứng, cho sheet). `edgeFade` làm mờ light ở 8 px mép canvas để glow bị cắt
không thành hộp (không cần khi bỏ light).

### 2.2 Sprite sheet + JSON kiểu Aseprite (`spriteSheet`)

- Lưới `cols = ceil(sqrt(n·h/w))` gần vuông, PNG trong suốt, **không gutter**.
- JSON `frames[]` = `{ filename, frame{x,y,w,h}, rotated:false, trimmed:false, spriteSourceSize, sourceSize,
  duration (ms) }`; `meta` = `{ app, image, format: "RGBA8888", size, scale, frameTags:[{name, from, to, direction}],
  pixelfx: { id, name, fps, loop, frames, frameSize, pivot: origin, columns, act?: actTiming } }`.
- Godot/Unity Aseprite importer và Phaser đọc được; `pivot` là `meta.origin`.

Tessera đã dùng **cùng họ JSON** cho đơn vị (`tools/asset-pipeline/export_sheets.py` xuất `frames[] + meta.frameTags +
meta.tessera`, gutter 1 px, đọc bởi `src/art/sprite_sheet.gd`) và một họ khác cho VFX (manifest PixelLab đọc bởi
`src/art/vfx_pack.gd`: `canvas, anchor, clips[{frame, sheets[{file, columns, rows}], offset}]`, **một `frame_ms` cho cả
pack, chỉ sheet đầu, không gutter, không scale**). Pipeline mới nên xuất **đúng hai họ này** để không sửa loader (kế hoạch §4).

### 2.3 Preview: contact sheet, GIF/MP4, strip 12 fps

- `render.mjs`: `records/<id>/contact.png` (16 khung đều, phóng `--zoom`, nhãn `id size duration frames fps LOOP/ONE-SHOT`
  bằng font 3×5 nội bộ), `--all` mọi khung, `--gif/--mp4` qua **ffmpeg** (palettegen, `dither=none`), `--sheet`.
- `act.mjs`: strip **các bước 12 fps liên tiếp** (không lấy mẫu đều) vì "motion bugs don't show in samples"; `--sheet`
  nướng cả act (thân + mục tiêu) thành sheet.
- `compare.mjs`: nhiều bản nháp cùng hàng, cùng mốc thời gian, để chọn bản tốt nhất.
- `montage.mjs`, `build-gallery.mjs`, `serve.mjs`: gallery web.

Máy này **không có ffmpeg**, không Pillow, không ImageMagick; có Node 24.22 và Python 3.12. Dự án đã có
`prototypes/art-check/tools/make_gif.py` (GIF thuần Python) → GIF preview làm bằng nó, không phụ thuộc ffmpeg.

### 2.4 Kiểm tra lỗi (`tools/check.mjs`, 216 dòng)

| Kiểm | Cách | Kết quả |
|---|---|---|
| meta | name/desc/tags/size 8..480/origin/duration ≤ 12 s/bg hợp lệ; option không được tên `x y flip angle light` | FAIL |
| `Math.random` trong source | regex | FAIL |
| **Spill** | vẽ vào frame có lề 24 px, đếm pixel ngoài `size`; thử thêm seed 2, 3, 7 | warn + bbox gợi ý grow size |
| One-shot **ends empty** | đếm pixel tại `t = duration` | warn |
| **Loop seam** | diff khung cuối→đầu so với bậc 90 % của diff khung-khung | warn |
| **Determinism** | vẽ cùng t hai lần / chạy sim hai lần cùng seed | FAIL |
| Palette ngắn | chạy với palette 4 bậc, bắt màu `undefined` qua monkey-patch `Painter.put` | FAIL ("use fit") |
| Tốc độ | median > 4 ms/khung | warn |
| Act | key thứ tự, field lạ, hit ngoài act, `stop > 0,3`, loop pose kết thúc tại duration, tay nhảy > 30 px/bước, act không kết thúc | FAIL/warn |

Thiếu cho Tessera (phải tự thêm): màu nằm trong `.gpl`, alpha chỉ 0/255, cấm `#E5293B`, hạt lẻ (orphan pixel), chỉ hình
vuông/bậc 45°, ≤ 128 ô vuông/khung, thời lượng overlay trên đơn vị ≤ 0,35 s, JSON khớp PNG.

### 2.5 Quy trình làm việc (SKILL.md)

Tìm hiệu ứng có sẵn → thử option trước khi sửa code → `new.mjs` template → **nói hiệu ứng trong một dòng kèm art direction**
→ nháp 3–5 bản khác hẳn nhau (`<name>-a..e.js`) → render, nhìn contact sheet → "fix the worst thing, render again",
tối thiểu 3 vòng → act it out → check sạch → xóa nháp không giữ. Bảng "you see → fix" (mush at 1x → ít màu hơn, bóng
dáng rõ; floaty → ease out nhanh + hero frame trắng + ngắn hơn; stiff → biến thiên mọi hạt…) đáng chép vào checklist QA.

---

## 3. Đọc ví dụ theo nhóm: cái gì chuyển được sang "vuông"

| Nhóm / ví dụ | Kỹ thuật cốt lõi | Chuyển sang Tessera |
|---|---|---|
| **melee/sword-slash** | hình lưỡi liềm = `shade` trên elip nghiêng, đầu `ease.outExpo` 0,06 s, đuôi tan 0,24 s; echo mỏng trễ 0,017 s; glint ở mũi; 10 SPARK + 16 MOTE khi chạm; act GUARD→WIND→CUT(snap)→DOWN, hit-stop 0,14 s | **Không lấy hình liềm** (user đã bỏ sóng cong 2026-11-01). Lấy: hai lớp (vệt chính + echo trễ), đầu nhanh đuôi chậm, hạt văng lúc chạm, nhịp act. Vệt = **bậc thang ô vuông** (đã có `square_streak`) |
| **explosions/small-explosion** | 4 pha: flash trắng 0,06 s → vành sốc (`ring` co giãn `1−k³`) → lửa nguội thành khói → mảnh đá `Bits` nảy, `Blazes` cháy nơi rơi, vết cháy sàn `scorch` nguội dần 5,4 s | Lấy **cấu trúc pha** (flash → sóng → mảnh → dấu để lại) và `Bits` kiểu CHUNK đổi thành ô vuông; bỏ vành tròn, khói, light. "Dấu để lại" = Bản Khắc/ô cháy đã có trong game |
| **ice/frost-nova** | tinh thể `crystal()` mọc có ridge sáng; vành băng trên sàn `band` nửa xa/nửa gần; sàn đóng sương rồi tan | Mặt phẳng sàn tách **nửa sau đơn vị / nửa trước** = hai lớp floor/front. Tinh thể → **cột ô vuông** |
| **impacts/hit-spark** | 3 nhịp khung cố định (0–0,025 s cross đầy, 0,025–0,058 mỏng, 0,058–0,092 chỉ tia dài), core **diamond** `|dx|+|dy| ≤ r`, 9 SPARK + 6 GRIT bay theo hướng đòn `aim` | Diamond = hình 45° hợp luật; **nhịp 3 khung lúc chạm** là khuôn cho impact ≤ 0,35 s; `aim` = hướng từ ô trước |
| **impacts/impact-frame** | 2 khung trắng + 2 khung đảo + 4 khung tia rút, mask tính sẵn mỗi khung | Mẫu cho **hit flash** toàn màn khi boss trúng Phá phép (chỉ nếu muốn; art bible cấm rung màn bằng khung) |
| **projectiles/magic-missile** | `CHARGE 0,2 s` mote hút vào tay → `FLY 0,62 s` theo `pos(u)` lượn sin, dải ruy băng xoắn từ trail → burst `flare` + `ring` | Khuôn ba pha **charge → fly → burst** cho CASTER_TO_TARGET. Đường bay Tessera thẳng theo hàng (OSFE), ruy băng → đuôi ô vuông nhỏ dần |
| **nature/earth-spike** | sàn nứt sáng `floorCrack` → cọc `drawSpike` bật lên **overshoot `outBack`** + 1 khung trắng → mảnh GRIT/dust → đứng → tách đôi, mục → chìm | Khuôn cho **Bãi Gai / rễ trồi**: nứt → trồi (outBack) → trắng 1 khung → đứng → chìm. Cọc nhiều mặt → cột vuông 2 tông |
| **nature/root-snare** | 5 rễ `path()` xoắn ốc quanh chân, grow `outCubic`, cinch (siết) 0,62 s có snap + sparkle, hold có mote xanh, break 1,75 s vỡ vỏ cây; act GRAB với hit-stop 0,05/0,04 | Khuôn cho **Trói (root)** trên đơn vị: mọc → siết (snap) → giữ → vỡ. Vẽ rễ bằng đoạn vuông 2 px bậc thang, đọc mask sprite để biết chân ở đâu |
| **nature/thorns** | gai bật lần lượt `at: 0.12 + i·0.075`, mỗi cái to hơn, có "seam" chạy trước trên sàn `run = outCubic · reach`, leaf collar, sink | Đúng khuôn **GROUND_PROPAGATION ô này sang ô kia** cho Phù thủy: vạch chạy trước (floor layer) rồi gai trồi theo thứ tự ô |
| **fire/fireball + status/burning** | lưỡi lửa `tongue` nhiều lớp theo `LAYERS` (ngưỡng → bậc ramp), gió `WIND`, tick 0,6 s flash trắng rồi cam, vết than lan trên áo | Lửa Tessera = **bậc thang ô vuông + sọc ngang** (art bible). Lấy nhịp tick (flash → cam → than) cho Cháy |
| **moves/sword-combo, fireball-throw, earth-stomp** | `chain` + `shiftKeys/shiftHits`, hằng số `A, B, C, STEP`, `THROW, FLY, HIT`, `STOMP, RAM` | Mẫu cho file **skill timeline** của Tessera: hằng số pha ↔ `combat.json timing.delivery` |
| **status/_lib `shape(a)`** | từ mask tính `rows[l,r]`, `up` (đỉnh), `body`, dùng để đặt hiệu ứng theo silhouette | Sinh overlay Trói/Đóng Băng/Rạn **theo mask từng frame** của sprite thật |

---

## 4. Đồng bộ animation nhân vật với VFX kỹ năng (PixelFX và Tessera hiện tại)

| Vấn đề | PixelFX | Tessera hiện tại (`cast/index.json`, `UnitLayer`, `CombatView`) |
|---|---|---|
| Mốc 0 | khung đầu của hiệu ứng | lúc **launch** (`gesture_lead_sec` trước đó clip nhảy sang khung chém) |
| Wind-up | key âm, nội suy | clip `cast_gesture` dừng ở `gesture_hold_frame` (4) suốt telegraph (dài thay đổi), `UnitAnimator.set_paused/seek` |
| Release | `"snap"` tới pose CUT đúng t = 0 | khung 5 của clip (`events.release` trong animation sheet) |
| Hit-stop | `hits[].stop`, dừng mọi thứ | chưa có (chỉ `hit_feel` flash add-blend 0,1 s + shake 2 px 0,12 s trên mục tiêu) |
| Mục tiêu phản ứng | `Target` lò xo + skin + straw | clip `hit` 3×40 ms + `HitFlash` con add-blend; địch: WINDUP → WARNING → RESOLVE → FOLLOWUP → RECOVERY (`pattern_controller.gd`) |
| Nhiều mục tiêu | `targets[]`, `hits[].at` | `SkillDelivery.arrival_times` tính giờ đến từng ô; mỗi ô chạm khi burst của nó nổ |
| Dữ liệu cho host | `actTiming()` → `{windup, recovery, hits[]}` | rải ở `cast/index.json`, `combat.json timing.delivery`, `clips.json`, `enemy_skills.json` |

Bài học: gom thành **một bản ghi timing per skill** (kế hoạch §3.4) và thêm **hit-stop** như trường dữ liệu
(`freeze_sec`, mặc định 0 để không đổi cảm giác hiện tại cho tới khi người dùng duyệt).

---

## 5. Những gì KHÔNG lấy, và vì sao

| Của PixelFX | Vi phạm | Thay bằng |
|---|---|---|
| `light` buffer, `glow/glowLine/glowRing`, `Lights` | P1, §8.10 (glow, bloom), brief "không quá nhiều ánh sáng" | bậc sáng của ramp, 1–2 khung hero-frame Ngà/trắng |
| `disc/blend` khói, hơi, bụi trong mờ | §8.3 alpha 0/255 trên sprite; §6.2 dither chỉ mist | mảnh vuông đục rơi/nhỏ dần; "khói" = ô vuông xám bậc 1 bay lên rồi mất |
| Dither Bayer để fade | §6.2 | fade = **thu nhỏ bậc** (3→2→1 px) hoặc rụng từng hạt theo seed |
| `circle/ring/arc/band/crystal`, lưỡi liềm | "không nổ tròn", P1 "sức mạnh luôn vuông" | `rect/poly` bậc 45°, diamond `|dx|+|dy|`, cột/vành vuông |
| `PAL.fire/blood/lava` (có đỏ), `FIRE_RAMP` | đỏ chỉ cho báo đòn | ramp Cháy `#FF7A1F/#FFB21F` + Ngà, khối Pháp sư `#3A2A26/#F0A030` |
| Nhân vật mẫu 24×38, `rig.js` skeleton, `Target` bù nhìn rơm | user: không dùng sprite PixelFX | frame PixelLab thật (`art_src/units/*`), placeholder vuông cho Pháp sư/Phù thủy chưa có |
| Shake bằng dịch cả bức ảnh | §8.10 "không rung màn bằng khung vẽ" | shake chỉ trên **sprite đơn vị** (đã có `hit_feel.shake_px`), không rung sàn/HUD |
| Canvas 136–480 px | hiệu ứng Tessera gói trong ô 38×27…64×46 (+ lề) | canvas = cỡ ô + lề theo data, render per cỡ ô |
| ffmpeg cho GIF/MP4 | không cài | GIF thuần Python (`make_gif.py`) |

---

## 6. Giấy phép và NOTICE

- `LICENSE`: **MIT**, Copyright (c) 2026 Patch và (c) 2026 Hugo Duprez. Dùng, sửa, bán đều được; **phải giữ thông báo
  bản quyền** khi sao chép "substantial portions".
- `NOTICE.md`: `src/core/sim.js` và các effect ghi ở đầu file chuyển thể từ Sprite Fusion VFX (Hugo Duprez, MIT);
  `src/core/act.js` chuyển thể cách Hollow Crown chơi skill (rehan-remade, MIT); **font Patch Pixel trong `gallery/fonts`
  không thuộc MIT**, không được dùng.
- Khuyến nghị cho Tessera: viết lại bằng ngôn ngữ của pipeline (ý tưởng không có bản quyền); nếu chuyển thể nguyên đoạn
  (ví dụ `fly()` giải tích, Bresenham `line`, `fit/at`), thêm `tools/fx-pipeline/NOTICE.md` ghi ba dòng MIT trên.
  Không chép effect nào nguyên vẹn (AUTHORING "The bar" #9 cũng cấm chép Hugo's effects wholesale).

---

## 7. Mâu thuẫn trong tài liệu Tessera phát hiện khi đối chiếu (cần người dùng quyết)

1. **Cỡ khung nhân vật.** Brief và art bible §1 P2/§3: anh hùng ~40 px trong **32×48**, Kẻ Gác **48×64**.
   `docs/art/ASSET_SPECIFICATION.md` §2 và art-check README: anh hùng **40×48**. Art bible §8.3 (đã sửa sau) và sprite
   đã cài: `kiem_si` **96×70** (chân hàng 69), `goblin_scout` **64×52**; `phase2-misty-forest` §8 đề xuất tinh anh 64×64,
   Phù thủy **96×80** (A7: boss 2–3× anh hùng, footprint 2×2). Pipeline sẽ **không gắn cứng cỡ khung** (đọc từ
   `clips.json`/data) và mặc định theo sprite đã cài, nhưng tài liệu cần một con số canon.
2. **Projectile và thời lượng VFX.** Art bible §3 "Anh hùng niệm… **không phóng vật gì ra**", "VFX ≤ 0,35 s, chỉ trong
   các ô đích" ↔ ADR-0001 D7/A1 (2026-11-01, LOCKED): hiệu ứng **được bay** từ caster dạng vuông; sóng kiếm đã duyệt
   bay 0,15 s + nổ 0,13 s + lan 0,08 s/ô. ADR mới hơn và do người dùng duyệt; §3 art bible cần sửa (không thuộc task này).
3. **Cử chỉ niệm 2 khung 0,2 s** (art bible §3, §8.6 `cast_gesture 0,08 + 0,12 s`; idle 0,4 s/khung; windup 1 khung;
   victory lặp) ↔ dữ liệu thật: cast 9 khung ~0,9 s có khung giữ coil (v4, 2026-11-01), idle 250 ms, windup 2 khung,
   victory `hold_last`. Art bible §8.6 lạc hậu.
4. **VFX 38×27, 3 xám tô bằng code** (ASSET_SPECIFICATION §2, art bible §3/§8.3) ↔ pack hiện tại 64×64 màu thật từ
   PixelLab trên ô tham chiếu 64×46 + `impact_style` vẽ code. Hai mô hình song song; kế hoạch chọn một.
5. **Nháy trúng**: art bible §5.4 "đổi palette sang Ngà 0,06 s" qua shader `unit_fx` ↔ shader **không tồn tại**
   (chỉ có `canvas_floor_perspective.gdshader`); game dùng `HitFlash` add-blend trắng 0,1 s alpha 0,75.
6. **Độ phân giải**: brief "640×360" ↔ `BattleCanvas` SubViewport **800×360** (640 vùng chơi + 80 lề mỗi bên); comment ở
   `screen_layout.gd:50` vẫn ghi 640. Không mâu thuẫn thật, ghi để khỏi hiểu nhầm cỡ canvas backdrop.
7. **Palette master**: tài liệu nói `assets/art/palette/tessera_master.gpl` ≤ 64 màu + LUT ↔ file thật
   `art_src/palette/tessera_master.gpl` **16 màu**, không LUT. Pipeline VFX cần thêm màu tín hiệu (Cháy, Đóng Băng,
   gỗ, hổ phách) vào `.gpl` → quyết định của art-director (người dùng ở chế độ solo).
8. **Neo chân**: art bible "3 art-px trên mép trước phiến" ↔ `UnitLayer` đặt chân tại 0,72 chiều cao ô
   (`FEET_DEPTH_RATIO`); pack sàn neo **đáy-giữa ô**. Pipeline phải xuất `anchor` rõ ràng theo quy ước code.
9. **Mô tả Phù thủy trong brief** ("rễ lan qua sàn theo từng ô; ô cảnh báo trồi gai") khớp `branch_lattice` và
   `entangled_row` (GROUND_PROPAGATION, impact `thorns`); `root_nail` là DIRECT_MANIFESTATION, `forest_last_knot`
   là SEQUENTIAL_CHAIN `chain_spark`. Prototype 3 nên làm cho **`branch_lattice`** (L 3 ô + followup 1 ô).
10. **Pack trạng thái theo cỡ**: mọi địch dùng pack cỡ goblin (`frame_kind_of` ép theo phe). Phù thủy 2×2 sẽ nhận
    overlay nhỏ sai cỡ nếu không sinh overlay theo mask (§1.10).

---

## 8. Bảng tóm tắt: học gì, bỏ gì

| Học (chuyển thể) | Bỏ |
|---|---|
| Effect = code theo thời gian, `meta` + `origin` + `options` | Light buffer, glow |
| Painter: biến đổi cục bộ, làm tròn tâm ô, màu 0 = không vẽ | Dither alpha, blend trong mờ |
| Ramp `fit/at`, option `palette`, resample | 27 ramp có đỏ |
| Seed: `rand/Rng/rng(seed,i)`, cấm `Math.random` | — |
| `fly/burst/cycle/stream`, GRIT, Bits | SMOKE/VAPOUR/FIRE, Blazes, Lights |
| Hằng số pha, ease, "fast in slow out", hero frame, ends empty | Vành tròn, lưỡi liềm, crystal |
| `act` = poses/hits/dust → `actTiming` dữ liệu; hit-stop | Rig, nhân vật mẫu, bù nhìn rơm, shake cả màn |
| `chain` cue với `x(t)`, `shiftKeys` | Canvas lớn 136–480 |
| render/contact/strip 12 fps/compare/check/new | ffmpeg, gallery web |
| Sheet + JSON kiểu Aseprite, `pivot` | — |
| `_lib` theo nhóm, option trước khi sửa code, 3–5 nháp | Chép effect nguyên vẹn |
