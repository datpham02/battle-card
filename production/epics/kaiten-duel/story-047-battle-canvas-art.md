# Story 047: Tầng art trong trận — SubViewport 800×360, nền và sàn Rừng Sương, sprite đơn vị, lớp phủ trạng thái

> **Epic**: Kaiten Duel (v6)
> **Status**: In Progress
> **Layer**: Presentation (render)
> **Type**: Visual/Feel
> **Estimate**: — (nhiều ngày; 5 phần, mỗi phần một subagent)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-31

## Context

**GDD**: `design/art/art-bible.md` §1 (hệ quả kỹ thuật), §6.3 (phiến 9-slice + stamp, **bệ nổi B**), §6.4 (nền một bức, **dải cảnh xa 20 %**), §8.2 (SubViewport 800×360, hệ số phóng nguyên, phần dư tô Mực), §8.3 (khung 40×48 / 32×48, neo giữa đáy), §8.5 (lớp phủ, không shader bắt buộc), §8.6 (clip, thứ tự ba lớp Floor → Unit → Overlay), §8.7 (import Lossless), §8.10 (cấm); `docs/art/ASSET_SPECIFICATION.md` §1–§6 (hợp đồng render, tên file, cờ import); `design/assets/specs/misty-forest-assets.md` (ASSET-004 v4, ASSET-005 v2, ASSET-007 v2); `design/assets/specs/slice1-combat-ui-assets.md` (ASSET-017..020 lớp phủ trạng thái); `design/quick-specs/control-layout-v2.md` (Story 044, hình học cụm điều khiển không đổi).

**Requirement**:
- **Hiện trạng (2026-10-31):** game không nạp một file ảnh nào. `CombatView._draw` vẽ ô sân bằng `draw_rect` màu phẳng, người chơi là hình tròn ghi tên, địch là ô vuông đỏ, nền là màu be của `main_screen.gd`; tất cả ở độ phân giải gốc 1280×720 với tỉ lệ `viewport.y / 360` (số lẻ ở màn khác). Mọi asset đã vẽ (sprite Kiếm sĩ 17 khung, Goblin 9 khung, phiến v4, nền v2, gai, 6 gói lớp phủ trạng thái) chỉ mới ghép thử trong `prototypes/art-check`.
- **Đích:** trận vẽ trên **một SubViewport 800×360 art-px** với ba Node2D con theo §8.6, hiển thị bằng một Node2D phóng **hệ số nguyên** n, căn giữa, phần dư tô Mực; trong đó: nền Rừng Sương (xa + sương gần), bệ nổi B + phiến 9-slice v4 với stamp theo seed ô, gai phủ nguyên ô, sprite Kiếm sĩ và Goblin Scout chạy đúng clip theo trạng thái trận, lớp phủ Cháy / Đóng Băng / Giá Lạnh từ gói PixelLab gắn theo chân đơn vị. **Dải cảnh xa 20 %** (chuyển từ Story 046 Phần A sang đây vì nền đã vẽ cho dải này).
- **Không đổi:** luật chơi, hình học cụm điều khiển (Story 044), toạ độ chạm, HUD Z1 (Story 046 lo skin), `CutHudView` (ô báo đòn chuyển xuống FloorLayer là Story 046 Phần C; story này chỉ **chừa móc** cho nó).
- **Đơn vị chưa có sheet** (Pháp sư, Sát thủ, Thợ săn, Giáo sĩ; mọi quái ngoài Goblin Scout): vẽ dấu tạm **bên trong canvas** (vòng tròn tên / ô vuông như hiện tại, làm tròn art-px) để cùng lớp và cùng thứ tự với sprite; không crash, không chữ cảnh báo trên sân.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH (đổi đường vẽ của cả trận; mọi suite click windowed bấm toạ độ theo dải sân 13 % cũ; tên cài đặt snap pixel trên Viewport ở 4.6 cần kiểm; SubViewport trên điện thoại yếu cần đo draw call)
**Engine Notes**:
- Giữ Node2D + `_draw` (`draw_texture_rect_region`), **không** AnimatedSprite2D / AnimationPlayer / Sprite2D riêng từng đơn vị (§8.6, §8.10).
- SubViewport: `size = (800, 360)`, `canvas_item_default_texture_filter = NEAREST`, `msaa_2d = DISABLED`, `use_hdr_2d = false`, `snap_2d_transforms_to_pixel = true`, `snap_2d_vertices_to_pixel = true` (hai cờ snap là thuộc tính `Viewport`, **kiểm lại tên trong `docs/engine-reference/godot/`** trước khi dùng), `render_target_update_mode = UPDATE_ALWAYS` (hoặc `UPDATE_WHEN_VISIBLE`, chọn sau khi đo), `transparent_bg = false`.
- Node hiển thị: một Node2D vẽ `get_texture()` của SubViewport bằng `draw_texture_rect` vào `ScreenLayout.art_rect(vp)` với `texture_filter = TEXTURE_FILTER_NEAREST`; **không** `SubViewportContainer` (dự án không dùng Control).
- Hệ số phóng: `n = max(1, floor(min(W / 640, H / 360)))`; rect đích `800n × 360n` căn giữa; ở 1280×720 và 1600×720 n = 2 nên **mọi số đo hiện tại của sân giữ nguyên** (trừ đỉnh dải sân lên 20 %).
- Import mọi PNG trong `assets/art/`: `compress/mode=0`, `mipmaps/generate=false`, `process/fix_alpha_border=true`, `process/premult_alpha=false`; **commit cả `.import`** (khác `production/qa/evidence/`).
- `design/assets/candidates/` và `art_src/` có `.gdignore`; story này **sao chép** file đã duyệt vào `assets/art/`, không trỏ thẳng vào candidates.
- Lật ngang sprite (địch quay về vạch giữa) bằng `draw_texture_rect_region` với `rect.size.x` âm; lật là hợp lệ, xoay góc lẻ và phóng không nguyên thì không (§8.10).

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Canvas và hình học (`src/battle/battle_canvas.gd` mới, `src/layout/screen_layout.gd`)**

- [ ] `BattleCanvas` (Node2D, con đầu tiên của `battle.tscn`, vẽ **trước** `CombatView`) sở hữu một `SubViewport` 800×360 với ba Node2D con theo thứ tự: `BackdropLayer`, `FloorLayer`, `UnitLayer`, `OverlayLayer` (Overlay để trống, chừa cho Story 046 Phần C và VFX đòn). Cờ viewport theo Engine Notes; snap pixel **chỉ** trên SubViewport, không đặt toàn project.
- [ ] `ScreenLayout.art_scale(vp) -> int` (công thức n ở trên), `art_rect(vp) -> Rect2` (800n×360n căn giữa), `play_rect(vp)` (640n×360n ở giữa art_rect), `to_art(vp, px) -> Vector2i` và `from_art(vp, art) -> Vector2`. `cell_size()` dùng `art_scale` thay cho `viewport.y / ART_CANVAS_HEIGHT`; ở 1280×720 và 1600×720 bảng cỡ ô **khớp Story 044** trừ thay đổi ở dòng dưới. Phần dư ngoài art_rect tô Mực #1B1722 bởi `BattleCanvas` (không phải `main_screen`).
- [ ] **Dải cảnh xa 20 % (chuyển từ Story 046 Phần A):** hằng số `BOARD_BAND_TOP_RATIO = 0.20` thay công thức `ARENA_TOP_RATIO + HUD_HEIGHT_RATIO × arena`; `board_area_rect()` bắt đầu ở 20 %; Z1 giữ 3–8 %; 8–20 % không chứa yếu tố nào. Bảng cỡ ô mới kiểm ±1 px: 3x3 → 64×46; 5x5 → 43×31; ring → không lớn hơn 43×31 và không ô nào chạm ô túi (luật Story 044); pha lê 6x6 (spec tạm) → 46×33. Số cũ 49×35 không còn được tham chiếu.
- [ ] Toạ độ ô trong canvas: `FloorLayer.cell_art_rect(cell) = to_art(ScreenLayout.cell_rect(...))`, tức **hình học sân vẫn do `ScreenLayout` quyết**, canvas chỉ đổi đơn vị. Mọi hàm chạm (`cell_at`, túi, Thức Tỉnh, joystick/pad, menu) **không đổi hành vi**; `tests/unit/layout/screen_layout_v2_test.gd` cập nhật bảng và vẫn `FAILS=0`.
- [ ] `CombatView` **không còn vẽ** ô sân, vạch giữa, người chơi, địch (xóa `_draw_board`, `_draw_cell`, `_draw_enemy`, `_draw_player_marker`); HUD Z1, vòng hồi bước, vòng boss tạm thời vẫn vẽ ở đó (Story 046 và story VFX dời sau). `main_screen.gd` không vẽ khung sân be nữa khi đang trong trận.

**Phần B — Nền và sàn Rừng Sương (`src/battle/backdrop_layer.gd`, `src/battle/floor_layer.gd`, `src/art/slab_painter.gd`, `src/art/art_assets.gd`)**

- [ ] `assets/art/env/forest/`: `bg_forest_far.png` (800×360), `bg_forest_near.png` (800×48), `env_slab_forest_9slice.png` (16×16), `env_slab_forest_stamps.png` (96×48) + `env_slab_forest_stamps.json`, `env_thorn_forest_tile16.png` (16×16), sao chép **không đổi pixel** từ `design/assets/candidates/misty-forest/` (test so hash); kèm `region.json`: `{"backdrop": {"far": ..., "near": ..., "near_bottom_row": 70}, "slab": {...}, "thorn_tile": ...}`. Số hàng đáy sương (70) nằm trong JSON, không hardcode.
- [ ] `ArtAssets` (file tĩnh, nạp một lần, cache): `region(id) -> Dictionary` đọc `assets/art/env/<region>/region.json`; `unit_sheet(unit_id) -> SpriteSheet` (null khi thiếu); `status_pack(kind, frame_kind) -> VfxPack` (null khi thiếu). Thiếu file ⇒ trả null và `push_warning` một lần, **không crash**; mọi lớp có đường vẽ dự phòng.
- [ ] `BackdropLayer`: vẽ lớp xa ở (0,0) và dải sương gần với đáy ở `near_bottom_row`; chỉ `queue_redraw` khi vùng đổi (không vẽ lại mỗi khung); vùng chưa có nền (ngoài `forest`) tô hai bậc phẳng theo bảng vùng của art bible §6.4 (trời / đất) bằng code, không crash.
- [ ] `SlabPainter` (file tĩnh, hàm thuần): `paint_cell(canvas, art_rect, seed, nine, stamps_tex, stamps_meta)` vẽ 9-slice theo lề của JSON (3/3/3/4) giãn tới cỡ ô; stamp đặt theo `RandomNumberGenerator` seed = hash(side, col, row) nên **ổn định giữa các lần vẽ**; luật: chỉ stamp vừa mặt, ≤ 2 vết nứt, vật phủ ≤ 25 % mặt, speckle ≤ 4 % (theo `rules` trong JSON); chip mép bám mép ngoài phiến (anchor `top_right`, `bottom_left_face`, `top_edge`, `left_edge`, `lip_bottom` như prototype). **Viết lại theo chuẩn production, không copy** `prototypes/art-check` (`.claude/rules/prototype-code.md`).
- [ ] `SlabPainter.paint_platform(canvas, cells_art_rects)` dựng **bệ nổi B** (§6.3): mặt bệ 6 art-px quanh mọi ô thật (khe giữa hai nửa cũng là đá bệ với một vạch mảnh), mặt trước 12 art-px dưới ô không có ô thật bên dưới (cạnh trên sáng 1 px, 2 px Mực ở đáy, mạch đá dọc), bóng 4 px Mực 50 % xuống đất; màu từ bảng phiến v2 Rừng Sương trong `region.json`. Vẽ theo từng ô nên sân khuyết ô (ring, cross, islands) vẫn đúng hình.
- [ ] `FloorLayer` vẽ theo thứ tự: bệ → phiến mọi ô thật (`grid.player_cells()`, `enemy_cells()`) → ô đặc biệt: **gai** = tile 16×16 lặp phủ nguyên ô (ASSET-007 v2, đọc `StatusEffects` như `CutHudView._draw_zones` đang làm; `CutHudView` bỏ phần vẽ gai của nó), ô Ấn (seal) tạm giữ màu như hiện tại nhưng vẽ ở đây; redraw khi lưới, vùng hay trạng thái ô đổi (nối tín hiệu `zone_applied` / tick có đổi), không mỗi khung.
- [ ] `FloorLayer.add_painter(fn: Callable)` / `remove_painter(fn)`: danh sách hàm `fn(canvas: Node2D, floor: FloorLayer)` chạy **sau phiến, trước đơn vị** — móc cho Story 046 Phần C (ô báo đòn đậm dần) và ô kéo; story này chỉ có test gọi thử.

**Phần C — Sprite đơn vị (`src/art/sprite_sheet.gd`, `src/art/unit_animator.gd`, `src/battle/unit_layer.gd`)**

- [ ] `SpriteSheet` đọc `assets/art/units/unit_<id>_sheet.png` + `.json` **định dạng Aseprite array của Story 045**: `frames[]` (rect, duration), `meta.frameTags[]` (name, from, to), `meta.tessera.loop` (`loop | once | hold_last | hold`); API: `clip(name) -> Dictionary{frames: Array[Rect2i], durations_ms: Array[int], loop: String}`, `has_clip(name)`. Test đọc một JSON cố định (fixture dưới `tests/fixtures/art/`), không đọc sheet thật.
- [ ] `UnitAnimator` (RefCounted, **không node**, tick bằng delta tiêm vào): `play(clip, restart := false)`, `tick(delta)`, `frame_index()`, `is_finished()`; luật lặp theo `loop`; `set_reduce_motion(true)` ⇒ clip `idle` dừng ở khung 0 (§8.6), các clip khác vẫn chạy; clip không có trong sheet ⇒ về `idle` và trả false (không lỗi).
- [ ] Ánh xạ trạng thái → clip (trong `UnitLayer`, đọc các đối tượng hiện có, **không thêm luật chơi**):

  | Trạng thái | Clip | Nguồn tín hiệu |
  |---|---|---|
  | mặc định | `idle` (lặp) | — |
  | vừa bước | `step` một vòng, kéo dài đúng `UnitMover.get_cooldown_remaining()` lúc bước (khung chia đều) | `CombatState` đổi ô (so ô giữa hai tick) |
  | người chơi bắt đầu niệm | `cast_gesture` một lần | `CutActor.swing_started` của người chơi |
  | địch đang niệm | `windup` giữ tới hết | `CutActor.is_swinging()` của boss |
  | trúng đòn | `hit` một lần, ưu tiên trên `step`/`windup` trong 0,12 s | sự kiện mất máu (nếu `CombatState` chưa có tín hiệu `damaged(side, amount)`, thêm **một** tín hiệu ở đó, test đơn vị kèm) |
  | địch chết / gục | `down` rồi giữ khung cuối | `is_enemy_dead()` / `is_boss_downed()` |
  | người chơi chết | `defeat` rồi giữ khung cuối | `is_player_dead()` |
  | thắng | `victory` lặp | `is_enemy_dead()` và người chơi sống |
  | Thức Tỉnh đang chạy | `awaken` lặp | `CombatView.get_signature()` hiệu ứng đang chạy |
  | `fall` | **chưa dùng** (chờ story Ô rớt) | — |

- [ ] `UnitLayer._draw`: mọi đơn vị **hàng sau trước, cùng hàng theo x** (§8.6); neo = **giữa đáy khung**, chân đặt ở `cell_art_rect.end.y − 3` (trên mép trước 3 px), x = giữa ô, **làm tròn art-px nguyên**; người chơi quay phải, địch quay trái (lật ngang nếu sheet vẽ quay phải; ghi hướng gốc trong `region.json`/sheet JSON `meta.tessera.facing`); đơn vị không có sheet vẽ dấu tạm (vòng tròn tên / ô vuông) cùng neo. Boss gục (Story 035) và boss bất tử (viền) giữ cách tô hiện tại trên sprite bằng `modulate`-tương-đương qua màu vẽ, không shader.
- [ ] Chuyển `CombatView` sang **không vẽ đơn vị** đồng thời giữ mọi API đọc trạng thái mà `CutHudView`, test và DemoArgs đang dùng; vòng hồi bước của người chơi và vòng boss vẽ tại `from_art(neo)` để vẫn bám chân.

**Phần D — Lớp phủ trạng thái (`src/art/vfx_pack.gd`, trong `UnitLayer`)**

- [ ] `assets/art/vfx/status/<kind>_<frame>/` với `<kind>` ∈ `burn, frozen, chill`, `<frame>` ∈ `hero, goblin`: `manifest.json`, `behind.png`, `front.png` (và `whole.png` để kiểm) sao chép từ `design/assets/candidates/slice1-fx/status-vfx/pack-tessera-status-*/` (không đổi pixel; **không** commit `.zip`). Import theo cờ chuẩn.
- [ ] `VfxPack` đọc manifest PixelLab (`clips[]` với `frame {w,h}`, `sheets[] {file, columns}`, `offset {x,y}` so với neo chân, `frame_ms`, `loop`): `clip(name)` trả rect từng khung + offset; test đọc một manifest fixture.
- [ ] `UnitLayer` vẽ với mỗi đơn vị đang chịu trạng thái (đọc `StatusEffects`: cháy / đóng băng / giá lạnh; `fragile` giữ lớp phủ script hiện có): clip `behind` **trước** sprite, clip `front` **sau** sprite, cùng neo chân, chạy theo `frame_ms` của gói, đồng hồ dùng delta trận (dừng khi Focus/Pause). Đơn vị dùng dấu tạm cũng nhận lớp phủ (gói `hero` cho người chơi, `goblin` cho địch 32×48). Reduce motion: khung 0 giữ.
- [ ] Chip trạng thái dưới thanh máu **không** thuộc story này (Story 046 Phần B).

**Phần E — Test, demo và bằng chứng**

- [ ] Test đơn vị `tests/unit/art/`: `sprite_sheet_test` (fixture JSON: số clip, rect, duration, loop); `unit_animator_test` (lặp / once / hold_last / hold, step kéo theo cooldown, hit ưu tiên, reduce motion, clip thiếu); `vfx_pack_test` (fixture manifest: offset, số khung, cột); `slab_painter_test` (cùng seed ⇒ cùng danh sách stamp; stamp không vượt mặt; luật ≤ 2 nứt / 25 % phủ / 4 % speckle; bệ: ô không có ô dưới sinh mặt trước, ô có thì không); `art_assets_test` (thiếu file ⇒ null, không lỗi; hash 5 file env khớp candidates).
- [ ] `tests/unit/layout/`: `art_scale`/`art_rect` ở 1280×720 (n=2, rect đầy), 1600×720 (n=2, lề Mực 0 vì 800·2 = 1600), 2400×1080 (n=3), 1024×768 (n=1, rect 800×360 căn giữa); bảng cỡ ô mới; `to_art`/`from_art` khứ hồi.
- [ ] Cập nhật toạ độ các suite click windowed theo dải 20 % (input, focus_flow, cut_flow, join_flow, achievements_flow, stick_flow); **toàn bộ 112 suite headless + 6 windowed `FAILS=0`**.
- [ ] `DemoArgs` thêm `--demo=anim_cast | anim_hit | anim_down | anim_defeat | status_burn | status_frozen` (dừng đồng hồ ở khung đặc trưng) và `--region=<id>` để chụp; ghi vào đầu `src/dev/demo_args.gd` như các demo khác.
- [ ] Ảnh 1280×720 lưu `production/qa/evidence/battle-canvas-art/`: (1) 3x3 Rừng Sương, hai sprite `idle`, bệ + phiến + nền; (2) 5x5; (3) ring (sân khuyết ô vẫn đúng bệ); (4) Kiếm sĩ giữa `step`; (5) `cast_gesture`; (6) Goblin `windup` + ô báo đòn hiện tại; (7) Goblin `hit`; (8) Goblin `down`; (9) Kiếm sĩ `defeat`; (10) Cháy trên Goblin, Đóng Băng trên Kiếm sĩ (behind/front đúng thứ tự: thấy lớp sau bị thân che); (11) gai phủ nguyên ô; (12) 1600×720; (13) 1024×768 với lề Mực; (14) trận Pháp sư vs Sói: dấu tạm trong canvas, không crash; (15) một ảnh phóng 4× vùng 100×60 art-px quanh Kiếm sĩ chứng minh không nhòe, không nửa pixel. **Đối chiếu bằng mắt** với `asset-slice1-art-check/56–61, 80–88` và ghi khác biệt.
- [ ] Đo và ghi vào Completion Notes: draw call tầng art (`Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` trước/sau), mục tiêu ≤ 30 cho tầng art (§8.7); thời gian khung headless không tăng > 10 % so với HEAD trước story.
- [ ] `design/assets/asset-manifest.md`: ASSET-004, 005, 007, 017–020 → **Done** (đang dùng trong game, chờ chữ ký); `design/art/art-bible.md` §8.2 ghi tên cờ snap đã kiểm; `docs/art/ASSET_SPECIFICATION.md` §1 bỏ *to verify* tương ứng.
- [ ] Bảng kiểm nhận asset §8.9 #9 ("ghép trong game") đánh dấu đạt cho 7 asset trên, có đường dẫn ảnh.

---

## Phụ thuộc và thứ tự

- **Story 045** (sheet + JSON của Kiếm sĩ và Goblin) phải xong trước **Phần C**; Phần A, B, D, E(1–2) không cần 045. Nếu 045 chưa có khi bắt đầu, làm A → B → D trước, C sau.
- **Story 046** mất Phần A (chuyển sang đây) và phụ thuộc 047 cho `FloorLayer.add_painter` (Phần C của 046) và `art_rect` (chip trạng thái dưới chân vẽ ở toạ độ art). Làm 047 trước 046.
- Thứ tự subagent đề xuất (mỗi phần một brief, tách theo file): A (canvas + layout + test layout) → B (nền, sàn, bệ, gai) → C (sheet, animator, UnitLayer) → D (gói trạng thái) → E (demo, suite click, ảnh).

## Ngoài phạm vi

- Ô báo đòn đậm dần dưới chân, skin HUD, chip trạng thái, font: Story 046.
- Khối nằm trên đất bằng ô 5×5 (ASSET-008), VFX đòn (ASSET-009/016), nháy trúng shader (ASSET-010), ô đích (ASSET-011): story VFX đòn, dùng `OverlayLayer` chừa sẵn.
- Ô rớt (quick spec `o-rot-thay-tuong-2026-10-31`) và clip `fall`: story luật riêng.
- Nền các vùng ngoài Rừng Sương, sheet 4 anh hùng còn lại, sheet quái khác: asset chưa có; dự phòng bằng code.
- Atlas gộp (§8.1): mới 2 đơn vị, chưa cần.
- `FieldDropsView` / `BossDropsView` (khối nằm trên sân) và vòng hồi bước vẫn vẽ ở độ phân giải gốc trên canvas; chuyển vào `OverlayLayer` ở story VFX.

## Notes

- Lý do tách canvas khỏi input: đổi toạ độ chạm sang art-px kéo theo mọi suite click và `HandInputController`; không mua được gì ở 1280×720 (n = 2 nên hai hệ trùng nhau). Khi nào cần hỗ trợ màn n = 1 hoặc 3 thật sự, chỉ `ScreenLayout` đổi.
- Ở màn 1024×768 (n = 1) sân chỉ còn 800×360 giữa màn; đây là luật §8.2 đã chốt, không phải lỗi; điện thoại mục tiêu đều n ≥ 2.
- `prototypes/art-check/art_check.gd` có bản tham khảo của mọi hình (`_draw_slab_art`, `_draw_stamp`, `--platform`, `--bg`, `--status-pack`, `--props`); đọc để lấy số, **không copy code**.
- Hướng quay gốc của sheet: xem khung trong `design/assets/candidates/swordsman/` và `goblin-scout/` khi làm Phần C; ghi `meta.tessera.facing` vào exporter của 045 nếu chưa có (sửa nhỏ, cùng chủ file).
- Playtest sau story: sprite 40×48 trên ô 43×31 (5x5) có đọc được ở 1× không; nếu đầu đơn vị hàng sau che quá nhiều hàng trước thì xét lại khoảng neo 3 px.

## Implementation Notes (2026-10-31, /dev-story)

Làm bằng 7 subagent theo file: A (canvas + layout), B thuần + B nối (sàn/nền), D thuần + D nối (gói trạng thái), C thuần + C nối (sprite), E (demo + ảnh). Story 045 chạy ở phiên riêng và merge vào `main` (`4ddd779`).

**Lệch so với tiêu chí, đã chấp nhận:**
- Pha lê 6x6 (spec tạm) ra ô **43×31**, không phải 46×33: với 46×33 hàng 4 của nó bắt đầu ở x 272 < 320 nên là hàng rộng và phải kết thúc ≤ 64 %, mà kết thúc ở 474. Hình học quyết, bảng ở Phần A sửa theo.
- `CombatView.get_battle_canvas()` thay cho `get_canvas()` (CanvasItem đã có `get_canvas() -> RID`).
- `main_screen.gd` không sửa: canvas phủ kín màn trong trận nên khung be bị che hoàn toàn; ngoài trận vẫn cần nó.
- `BackdropLayer` bỏ móc `size_changed` (canvas phóng cả khối); `FloorLayer` giữ, có guard khi trận đã bị giải phóng trước bind trễ (3 suite flow từng báo SCRIPT ERROR, đã sửa).
- Cờ demo vùng là `--art-region=<id>` vì GameFlow đã dùng `--region=`.
- Demo `anim_step` chụp ở 50 % độ dài bước (0,1 s vẫn là khung 0).
- Seal: tô phẳng `SEAL_FILL` trên mặt phiến ở FloorLayer (dưới đơn vị); hình hố là story Ô rớt.
- `CombatState` thêm tín hiệu `damaged(side, amount)`; `SettingsStore` thêm `reduce_motion`.
- 5 vùng chưa có nền dùng hai bậc màu phẳng trong `assets/art/regions.json` (`fallback_bands`), 3 bậc lấy từ art bible §6.4, còn lại là tạm, chờ art-director.

**Nhìn thấy trong ảnh, ngoài phạm vi (Story 046):** sọc Cháy cam và ô báo đòn đỏ của `CutHudView` vẫn vẽ ở độ phân giải gốc đè lên sprite (ảnh 05, 06, 10, 16); vòng hồi bước, khối trên đất (`FieldDropsView`) cũng ở lớp gốc (story VFX); chữ HUD trên tán cây khó đọc.

**Số đo:** draw call cả khung 87 (`board`), 104 (`status_burn`), 90 (dấu tạm); chưa có mốc trước story để tách phần tầng art. Ở 1024×768 (n = 1) canvas 800×360 nằm giữa nền Mực theo luật §8.2.

**Chạy:** 123 suite headless + 6 suite click `FAILS=0`, 0 SCRIPT ERROR (2026-10-31, tuần tự). Ảnh: `production/qa/evidence/battle-canvas-art/01–16` đã xem từng ảnh.

