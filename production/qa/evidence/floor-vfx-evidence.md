# Test Evidence: Story 048 — Hiệu ứng trên mặt ô bằng PixelLab

> **Story**: `production/epics/kaiten-duel/story-048-floor-vfx-pixellab.md`
> **Story Type**: Visual/Feel
> **Date**: 2026-10-31
> **Tester**: Claude (orchestrator); ảnh chụp bằng `--write-movie`, từng ảnh được mở và đối chiếu
> **Build / Commit**: `6eead5e` (gói + FloorVfx), nối dây trong `1b91b90` (main, pushed)

---

## What Was Tested

9 gói hiệu ứng mặt ô F1–F9 làm bằng PixelLab VFX workbench (miễn phí), xuất game pack, chép vào `assets/art/vfx/floor/` cùng `index.json`, phát bằng `FloorVfx` trong `FloorDynamicLayer` (dưới đơn vị) và `OverlayLayer` (F6, F8 trên đơn vị). Sau góp ý của người dùng (2026-10-31): hiệu ứng phủ kín ô (gói `fill` làm trên ô tham chiếu 64×46, đặt giữa ô và cắt theo ô qua `VfxPack.draw_clip` clip_rect) và bỏ mọi thanh thời gian (vùng gai/ấn, chip, ô cháy).

**Acceptance criteria covered**: Phần A, B, C (xem bảng; có lệch).

---

## Acceptance Criteria Results

| # | Criterion | Result | Notes |
|---|---|---|---|
| A-1 | 9 gói F1–F9 bằng `vfx_workbench`, xuất game pack, candidates + bản game, không `.zip` trong game | PASS | Candidates `design/assets/candidates/floor-vfx/` (v1 + v2 phủ ô); zip không commit |
| A-2 | Khung vừa ô 5x5 (43×31), tràn ≤ 4 art-px; màu theo bảng; alpha 0/255; không chữ; hạt vuông | PASS với lệch | **Lệch theo người dùng:** gói `fill` làm trên ô 64×46 và cắt theo ô đang vẽ (thay vì làm ở 43×31) để phủ kín ô ở mọi cỡ sân. Vòng tròn trong sigil/burst đã bỏ (Tessera chỉ hình vuông); nứt đỏ đổi sang đá + Mực |
| A-3 | `index.json` id → thư mục, lớp, lặp | PASS | `fill`, `ref_cell` [64,46], `hold_frame` 7 cho ô nứt |
| B-1 | `FloorVfx` loop / one-shot, đồng hồ theo delta trận, reduce motion = khung tĩnh | PASS | `tests/unit/art/floor_vfx_test.gd` |
| B-2 | F1, F2, F4, F5, F7, F9 dưới đơn vị; F6, F8 trên đơn vị ≤ 0,35 s | PASS | |
| B-3 | Bỏ hình vẽ code tương ứng; thiếu gói → giữ đường cũ, không crash | PASS với lệch | **Lệch theo người dùng:** AC ghi "giữ thanh thời gian 2 px" — đã bỏ hết thanh thời gian ("cái đó ko cần để cd"). Chữ TRÚNG / TRƯỢT / NGẮT nổi phía trên ô, không nền trắng |
| B-4 | Không gì trên mặt ô che đơn vị ngoài F6 / F8 | PASS | Ảnh 01, 05 |
| C-1 | Test đơn vị chọn gói, hàng đợi một lần, reduce motion, thiếu gói | PASS | `floor_vfx_test` |
| C-2 | Toàn bộ suite FAILS=0 | PASS | 129 headless + 6 windowed, 0 SCRIPT ERROR (sau commit `1b91b90`) |
| C-3 | Mỗi hiệu ứng một ảnh trong trận + ảnh tổng hợp 4× + evidence doc ký | PASS (chờ ký) | Đủ ảnh cho cả 9 gói (xem bảng ảnh) + ảnh tổng hợp 4×. F3, F4, F7 và bảng Tạm dừng chụp bằng một probe tạm (gọi `FloorVfx.play` cho F3 / F7; F4 dùng `SlamTrait` thật qua `FloorDynamicLayer`), không qua một trận chơi thật. Khung va chạm F6 / F8 chỉ sống ≤ 0,35 s |
---

## Screenshots / Video

Tất cả trong `production/qa/evidence/floor-vfx/`, 1280×720. Chụp trước đợt chỉnh màn hình trận kiểu OSFE (`1b91b90`) nên header máu cũ và Kiếm sĩ v1 còn trong ảnh; phần hiệu ứng sàn không đổi.

| # | Filename | What It Shows | Criterion |
|---|---|---|---|
| 1 | `01-f1-burning-half.png` | F1 ô cháy phủ kín cả nửa địch, chip Cháy dưới chân, không thanh thời gian | A-2, B-2, B-3 |
| 2 | `02-f2-engraving-3x3.png` | F2 ô Bản Khắc sáng trên sân 3x3 | B-2 |
| 3 | `03-f2-engraving-5x5-cropped.png` | F2 trên ô 43×31, gói 64×46 cắt theo ô | A-2 |
| 4 | `04-f5-cast-target.png` | F5 ô phép đang niệm, tô màu khối Kiếm sĩ | B-2 |
| 5 | `05-f6-f8-hit-interrupt-labels.png` | Chữ TRÚNG −12 và NGẮT nổi trên ô, không nền trắng | B-3, B-4 |
| 6 | `06-f9-thorn-spikes.png` | F9 gai đâm | B-2 |
| 7 | `07-chips-no-bars.png` | Chip trạng thái không còn thanh thời gian | B-3 |
| 8 | `08-f7-miss-dust-over-time.png` | F7 bụi trượt trên 9 ô nửa địch, 6 nhịp cách nhau 5 khung: đốm nhỏ lớn dần thành đám mây xám xanh khoảng hai phần ba ô | B-2, A-2 |
| 9 | `09-f3-engraving-complete-over-time.png` | F3 Bản Khắc hoàn tất trên 9 ô nửa địch, 6 nhịp: tia sao vàng rồi tản thành tia nhỏ; nhỏ hơn ô, không phủ kín | B-2, A-2 |
| 10 | `10-f4-cracked-cells-held.png` | F4 ô nứt (SlamTrait thật) giữ ở khung 7: nét nứt trên 2 ô nửa người chơi, ô thứ ba bị khung đặt khối che một phần | B-2 |
| 11 | `11-f4-crack-zoom-x5.png` | Cận cảnh nét nứt 5×: viền ngoài đỏ rất tối (#1B0404), phần trong xám tím | A-2 |
| 12 | `12-all-packs-middle-frame-x4.png` | Khung giữa của 9 gói phóng 4× (F4 ở khung giữ 7), theo thứ tự F1 … F9 | C-3 |

---

## Test Conditions

- **Game state at start**: demo `--demo=...` của DemoArgs, thời gian đóng băng sau khi dựng trạng thái
- **Platform / hardware**: Windows 11, Godot 4.6.3, cửa sổ 1280×720
- **Framerate during test**: chế độ quay (`--write-movie`, fps cố định)
- **Any special setup required**: `--no-autopause`

---

## Observations

- **Màu nét nứt F4:** viền ngoài #1B0404 là đỏ rất tối, không phải Mực #1B1722 trong bảng; trên nền đá hơi ngả đỏ nâu. Màu đỏ dành cho ô báo đòn (art bible P3). Sửa nhỏ: đổi #1B0404 → #1B1722 trong `cracked_cell/whole.png` và `front.png`.
- **Kích thước:** bản yêu cầu của người dùng là hiệu ứng phủ kín ô. F1, F2, F4, F5, F9 là gói `fill`; F7 là `fill` nhưng đám bụi chỉ chiếm khoảng hai phần ba ô ở lúc to nhất; F3, F6, F8 không `fill` (tia sao / tia lửa nhỏ giữa ô).
- Ảnh 01–07 chụp trước đợt chỉnh màn hình trận kiểu OSFE (`1b91b90`), nên header máu cũ và Kiếm sĩ v1 còn trong ảnh; ảnh 08–12 chụp sau đợt đó.
- Hiệu ứng vùng (lầy, miệng phun, bão, cát) để story asset vùng.
- Ô báo đòn giữ phẳng theo art bible P3.

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Lead (art-director / designer) | DatPT (solo) | 2026-10-31 | [x] Approved |

---

*Template: `.claude/docs/templates/test-evidence.md`*
*Used for: Visual/Feel and UI story type evidence records*
*Location: `production/qa/evidence/floor-vfx-evidence.md`*
