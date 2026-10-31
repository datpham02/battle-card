# Test Evidence: Story 047 — Tầng art trong trận (SubViewport 800×360, nền và sàn Rừng Sương, sprite đơn vị, lớp phủ trạng thái)

> **Story**: `production/epics/kaiten-duel/story-047-battle-canvas-art.md`
> **Story Type**: Visual/Feel
> **Date**: 2026-10-31
> **Tester**: Claude (orchestrator) — ảnh chụp bởi subagent Phần E, từng ảnh được mở và đối chiếu
> **Build / Commit**: `edcc788` (main, pushed)

---

## What Was Tested

Trận được vẽ qua một SubViewport 800×360 hiển thị ở hệ số phóng nguyên (n = 2 ở 1280×720 và 1600×720, n = 1 ở 1024×768), phần dư tô Mực. Trong canvas: nền Rừng Sương (xa + dải sương), bệ nổi B, phiến 9-slice v4 với stamp theo seed ô, gai phủ nguyên ô, sprite Kiếm sĩ (40×48, quay phải) và Goblin Scout (32×48, quay trái) chạy đúng clip theo trạng thái trận, lớp phủ Cháy / Đóng Băng / Giá Lạnh từ gói PixelLab (nửa sau lưng trước sprite, nửa trước sau sprite), dấu tạm cho đơn vị chưa có sheet. HUD, nút, túi và input vẫn ở độ phân giải gốc.

**Acceptance criteria covered**: Phần A (canvas, hình học, dải 20 %), B (nền, sàn, bệ, gai), C (sprite, clip, neo, hướng quay), D (lớp phủ trạng thái, reduce motion), E (ảnh 1–16, draw call).

---

## Acceptance Criteria Results

| # | Criterion (from story) | Result | Notes |
|---|----------------------|--------|-------|
| A-1 | BattleCanvas + SubViewport 800×360, 4 lớp theo thứ tự, cờ NEAREST / no MSAA / no HDR / snap chỉ trên SubViewport | PASS | Cờ kiểm qua ClassDB trên 4.6.3; test `battle_canvas_test` khẳng định root viewport không snap |
| A-2 | `art_scale` / `art_rect` / `play_rect` / `to_art` / `from_art`; Mực ngoài art_rect; bảng Story 044 giữ ở 1280 và 1600 | PASS | Ảnh 12 (1600×720, không lề), ảnh 13 (1024×768, lề Mực) |
| A-3 | Dải cảnh xa 20 %; 3x3 → 64×46; 5x5 → 43×31; ring không chạm ô túi; pha lê 6x6 → 46×33 | PASS với lệch | Pha lê đo được **43×31**: với 46×33 hàng 4 bắt đầu ở x 272 < 320 nên là hàng rộng và phải kết thúc ≤ 64 % nhưng kết thúc ở 474. Hình học quyết; test ghi 43×31 |
| A-4 | Hình học sân vẫn do ScreenLayout quyết; hàm chạm không đổi; layout test FAILS=0 | PASS | 6 suite click FAILS=0 không cần sửa toạ độ |
| A-5 | CombatView không vẽ sân / vạch giữa / người chơi / địch; main_screen không vẽ khung be trong trận | PASS với ghi chú | `main_screen.gd` không sửa: canvas phủ kín màn trong trận nên khung be bị che hoàn toàn (không ảnh nào còn be) |
| B-1 | `assets/art/env/forest/*` sao chép không đổi pixel + `region.json` với `near_bottom_row` 70 | PASS | SHA-256 kiểm trong `art_assets_test` |
| B-2 | `ArtAssets` cache, thiếu file → null + warn một lần | PASS | test `art_assets_test` |
| B-3 | BackdropLayer: xa + sương gần, redraw khi đổi vùng; vùng chưa có nền → hai bậc phẳng | PASS | Màu dự phòng 5 vùng là tạm (xem Observations) |
| B-4 | SlabPainter: 9-slice theo lề JSON, stamp theo seed ổn định, luật ≤ 2 nứt / 25 % phủ / 4 % speckle, chip bám mép; viết mới, không copy prototype | PASS | `slab_painter_test` 32 PASS |
| B-5 | Bệ nổi B theo §6.3, đúng hình sân khuyết ô | PASS | Ảnh 03 (ring) |
| B-6 | FloorLayer: bệ → phiến → gai (tile 16×16) → ấn → painter; redraw theo sự kiện, không mỗi khung; CutHudView bỏ vẽ gai | PASS | `floor_layer_test`: 0 redraw khi rảnh, +1 mỗi sự kiện vùng; ảnh 11 |
| B-7 | `add_painter` / `remove_painter` chạy sau phiến, trước đơn vị | PASS | test gọi thử |
| C-1 | SpriteSheet đọc JSON Aseprite của Story 045, fixture test | PASS | 66 PASS |
| C-2 | UnitAnimator không node, luật lặp, reduce motion, clip thiếu → idle | PASS | 70 PASS |
| C-3 | Ánh xạ trạng thái → clip theo bảng; `fall` chưa dùng | PASS | `clip_for` 9 dòng ưu tiên có test; ảnh 04–09 |
| C-4 | Vẽ hàng sau trước, cùng hàng theo x; neo giữa đáy, chân ở `end.y − 3`; quay về vạch giữa; dấu tạm khi không sheet; Story 035 giữ | PASS | Ảnh 01, 14, 15; kiểm 2×2 pixel: 0 sai trong vùng sprite |
| C-5 | CombatView không vẽ đơn vị nhưng giữ API; vòng hồi bước và vòng boss bám chân | PASS | Ảnh 04 (vòng cam quanh Kiếm sĩ) |
| D-1 | 6 gói trạng thái sao chép, không `.zip`, import chuẩn | PASS | `vfx_pack_test` 166 PASS, SHA-256 |
| D-2 | VfxPack đọc manifest PixelLab, fixture test | PASS | |
| D-3 | UnitLayer vẽ behind trước / front sau sprite, đồng hồ theo delta trận, reduce motion khung 0 | PASS | Ảnh 10, 16 |
| D-4 | Chip trạng thái dưới thanh máu không thuộc story | N/A | Story 046 |
| E-1 | Test đơn vị `tests/unit/art/` 5 suite | PASS | |
| E-2 | Test layout `art_scale`/`art_rect` 4 cỡ màn, bảng cỡ ô, khứ hồi | PASS | |
| E-3 | Suite click cập nhật, toàn bộ FAILS=0 | PASS | 123 headless + 6 windowed, 0 SCRIPT ERROR (sau khi sửa guard bind trễ) |
| E-4 | DemoArgs `anim_* / status_* / --region` | PASS với lệch | Cờ vùng là `--art-region` vì GameFlow đã dùng `--region`; `anim_step` chụp ở 50 % độ dài bước |
| E-5 | 15 ảnh theo danh sách, đối chiếu với art-check 56–61, 80–88 | PASS | 16 ảnh (thêm reduce motion) |
| E-6 | Draw call ≤ 30 cho tầng art; thời gian khung không tăng > 10 % | NOT MEASURED | Cả khung 87 / 104; không có mốc trước story để tách tầng art; thời gian khung chưa đo |
| E-7 | Manifest Done, art bible §8.2 tên cờ, ASSET_SPECIFICATION bỏ *to verify* | PASS | |
| E-8 | §8.9 #9 đánh dấu đạt | PASS | |

---

## Screenshots / Video

Tất cả trong `production/qa/evidence/battle-canvas-art/`, 1280×720 trừ 12 và 13.

| # | Filename | What It Shows | Acceptance Criterion |
|---|----------|--------------|----------------------|
| 1 | `01-forest-3x3-idle.png` | Nền Rừng Sương, bệ, phiến có stamp, Kiếm sĩ quay phải, Goblin quay trái, chân trên phiến | A, B, C-4 |
| 2 | `02-forest-5x5.png` | 5x5 ô 43×31, hai sprite nguyên vẹn | A-3 |
| 3 | `03-ring-platform.png` | Sân ring: bệ và mặt trước theo ô thật, lỗ lộ nền | B-5 |
| 4 | `04-anim-step.png` | Clip `step` giữa chừng, vòng hồi bước quanh Kiếm sĩ | C-3, C-5 |
| 5 | `05-anim-cast.png` | Clip `cast_gesture` kiếm đưa ra trước | C-3 |
| 6 | `06-anim-windup.png` | Goblin `windup`, vòng khoá xanh, ô báo đòn trên nửa người chơi | C-3 |
| 7 | `07-anim-hit.png` | Goblin `hit`, HP 41/46 | C-3 |
| 8 | `08-anim-down.png` | Goblin nằm (`down` khung cuối), Kiếm sĩ `victory` | C-3 |
| 9 | `09-anim-defeat.png` | Kiếm sĩ `defeat`, HP 0/200 | C-3 |
| 10 | `10-status-burn-frozen.png` | Lửa trên Goblin, băng quanh chân Kiếm sĩ | D-3 |
| 11 | `11-thorns-tiles.png` | Gai 16×16 phủ nguyên 4 ô quanh Goblin | B-6 |
| 12 | `12-wide-1600x720.png` | Đủ 800 art-px, n = 2, không lề Mực | A-2 |
| 13 | `13-1024x768-ink-margins.png` | n = 1, canvas 800×360 giữa nền Mực, HUD ngoài canvas | A-2 |
| 14 | `14-placeholder-mage-vs-wolf.png` | Dấu tạm Pháp sư và Sói trong canvas, không crash | C-4 |
| 15 | `15-zoom-4x-units.png` | Vùng 100×60 art-px quanh Kiếm sĩ phóng 4×, không nhòe | C-4 |
| 16 | `16-reduce-motion.png` | Như ảnh 10 với lớp phủ và idle ở khung 0 | D-3 |

---

## Test Conditions

- **Game state at start**: demo `--demo=board` và các demo `anim_* / status_*` của DemoArgs, thời gian đóng băng sau khi dựng trạng thái; trận Kiếm sĩ vs Goblin Scout qua `--node=ch1/c0/n0 --seed=2`
- **Platform / hardware**: Windows 11, Godot 4.6.3, cửa sổ 1280×720 (1600×720 và 1024×768 qua `override.cfg` tạm, đã xóa)
- **Framerate during test**: chế độ quay (`--write-movie`, fps cố định); thời gian khung thực chưa đo
- **Any special setup required**: `--no-autopause`; Story 045 (sheet) merge vào main trước Phần C

---

## Observations

- Sọc Cháy màu cam và ô báo đòn đỏ của `CutHudView` vẫn vẽ ở độ phân giải gốc **đè lên sprite** (ảnh 05, 06, 10, 16). Thuộc Story 046 Phần C (đưa xuống `FloorLayer.add_painter`). Nên làm ngay sau.
- Vòng hồi bước, vòng boss và khối trên đất (`FieldDropsView`) còn ở lớp gốc; chuyển vào `OverlayLayer` ở story VFX.
- Chữ HUD ở dải trên khó đọc trên tán cây tối: skin Story 046 Phần B.
- Màu nền dự phòng cho 5 vùng chưa có asset (`assets/art/regions.json` → `fallback_bands`) là tạm, 3 bậc lấy từ art bible §6.4, còn lại chờ art-director.
- Đầu Kiếm sĩ (48 px) trên ô 31 px ở sân 5x5 đè lên hàng trên; đúng dự kiến trong Notes của story, cần playtest xem có rối không.
- Draw call cả khung 87–104; chưa có mốc trước story. Nên đo lại khi làm story VFX.

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Lead (art-director / designer) | DatPT (solo) | 2026-10-31 | [x] Approved |

---

*Template: `.claude/docs/templates/test-evidence.md`*
*Used for: Visual/Feel and UI story type evidence records*
*Location: `production/qa/evidence/battle-canvas-art-evidence.md`*
