# Story 048: Hiệu ứng trên mặt ô bằng PixelLab — thay hình vẽ code của ô cháy, Bản Khắc, ô nứt, ô phép, trúng/trượt, NGẮT, gai đâm

> **Epic**: Kaiten Duel (v6)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-31

## Context

**GDD**: `design/art/art-bible.md` §3 (hình theo nhóm hiệu ứng), §4 (màu tín hiệu: Cháy #FF7A1F, Ánh Lưới #FFD45C, Mực #1B1722, màu khối anh hùng), §6.3 (ô đặc biệt), §8.3 (VFX đặt giữa ô, không phóng), §8.5 (hạt ≤ 128 ô vuông, lớp phủ sàn), §8.6 (thứ tự Floor → Unit → Overlay), §8.10; `design/assets/specs/slice1-combat-ui-assets.md`; Story 047 (`FloorLayer`, `FloorDynamicLayer`, `UnitLayer`, `VfxPack`, `StatusPacks`), Story 046 (`TelegraphPainter`, `BurnPainter`).
**Requirement**:
- **Người dùng chốt 2026-10-31:** "Xài pixellab làm các hiệu ứng tạo ra trên mặt ô luôn" — mọi hiệu ứng trên mặt ô làm bằng PixelLab VFX workbench (miễn phí, không tốn gen), thay cho hình vẽ bằng code.
- **Giữ nguyên dạng phẳng, không đổi:** ô báo đòn đỏ (art bible P3: tín hiệu phải đọc ngay, Story 046 Phần C) và các cảnh báo cùng loại (hàng sắp cháy, ô sắp nứt, ô phản đòn, bóng nhảy) — chúng là tín hiệu, không phải hiệu ứng.
- **Hiện trạng:** `BurnPainter` (cam + sọc + glyph lửa), `CutHudView._draw_formation` (ô Bản Khắc sáng), `_draw_trait_cells` (ô nứt: nền tối + đường nứt), `_draw_swing` (ô phép người chơi đang niệm + nhãn "Nick 0.5"), `_draw_feedback` / `_draw_boss_feedback` (TRÚNG / TRƯỢT), `_draw_interrupt` (NGẮT: tô cam + chữ X), `_draw_zones` (chớp khi bước vào gai) đều vẽ bằng `draw_rect` / `draw_line` ở độ phân giải gốc.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**Engine**: Godot 4.6 | **Risk**: MEDIUM (nhiều hiệu ứng đổi một lúc; hiệu ứng trên mặt ô không được che đơn vị)
**Engine Notes**: gói xuất bằng `vfx_workbench export --game-pack` (manifest + `whole.png` / `behind.png` / `front.png`), đọc bằng `VfxPack` của Story 047; vẽ ở art-px trong canvas, neo giữa ô (`FloorLayer.cell_art_rect(cell).get_center()`), không phóng.

---

## Bảng hiệu ứng (slice 1)

| # | Hiệu ứng | Khi nào | Phần PixelLab gợi ý | Màu khóa | Lặp | Lớp |
|---|---|---|---|---|---|---|
| F1 | Ô cháy | ô đang cháy (`StatusEffects.burning_cells`) | `scorch_mark` + `ember_rise` | Cháy #FF7A1F, than, Mực | loop | Floor (dưới đơn vị) |
| F2 | Ô Bản Khắc sáng | ô địch đã sáng trong `FormationMap` | `square_sigil` nhỏ, tĩnh nhẹ | Ánh Lưới #FFD45C | loop | Floor |
| F3 | Bản Khắc hoàn tất | lúc bản đồ đủ | `square_sigil` + `flash_burst` | Ánh Lưới | once | Floor |
| F4 | Ô nứt | ô bị nứt (slam) | `ground_cracks`, giữ khung cuối | đá tối + vệt sáng | once → hold | Floor |
| F5 | Ô phép đang niệm (người chơi) | `CutActor` người chơi đang niệm | `square_sigil` | màu khối nhân vật (Kiếm sĩ #8FA3B8 / #EEF4FA) | loop | Floor |
| F6 | Trúng | đòn trúng ô có đơn vị | `hit_star` + `debris_burst` (đá vụn) | Ngà #EFE6D2, đá | once | Overlay (trên, ≤ 0,35 s) |
| F7 | Trượt | đòn trượt | `dust_puff` | Sương #7D8896 | once | Floor |
| F8 | NGẮT | đòn bị ngắt | `shield_break` đổi màu | cam #FF7A1F + Ngà | once | Overlay (≤ 0,35 s) |
| F9 | Gai đâm | đơn vị bước vào ô gai | `ice_spikes` đổi màu gai | Gai #B89A6A, Mực | once | Floor |

Ngoài slice 1 (làm cùng asset của vùng, story sau): ô lầy (`bubbles_rise`), miệng phun (`steam_vent` / dung nham), bão (`wind_gusts`), cát lấp; ô Ấn / hố là story Ô rớt (đã có gói `pixel_shatter`).

## Acceptance Criteria

**Phần A — Gói hiệu ứng**
- [x] 9 gói F1–F9 làm bằng `vfx_workbench` (không gọi công cụ trả phí), xuất `--game-pack`, lưu `design/assets/candidates/floor-vfx/pack-<id>/` (+ GIF xem trước), rồi sao chép vào `assets/art/vfx/floor/<id>/` (manifest + PNG, import Lossless, không mipmap, không `.zip`).
- [x] Mỗi gói: khung vừa ô 5x5 (43×31) — phần trên mặt đất không tràn quá mép phiến hơn 4 art-px; màu trong bảng ở trên; alpha 0/255; không chữ; hạt là ô vuông (art bible P1). *(Đóng 2026-10-31: gói `fill` làm trên ô 64×46 và cắt theo ô theo ý người dùng; nét nứt F4 dùng #1B0404, không phải Mực; F3/F6/F8 không phủ kín ô, F7 chiếm ~2/3 ô.)*
- [x] `assets/art/vfx/floor/index.json` liệt kê id → thư mục, lớp (floor / overlay), lặp hay một lần.

**Phần B — Nối vào game**
- [x] `FloorVfx` (pure + vẽ) phát gói trên ô theo bảng: loop cho trạng thái, một lần cho sự kiện (hàng đợi sự kiện có thời điểm bắt đầu, xóa khi xong); đồng hồ theo delta trận (dừng khi Focus / Pause), giảm chuyển động = khung đại diện tĩnh.
- [x] F1, F2, F4, F5, F7, F9 vẽ trong `FloorDynamicLayer` (dưới đơn vị); F6, F8 vẽ trong `OverlayLayer` (trên đơn vị, ≤ 0,35 s).
- [x] Bỏ phần vẽ code tương ứng (`BurnPainter` phần tô/sọc/glyph — giữ thanh thời gian 2 px; `_draw_formation` ô sáng; `_draw_trait_cells` ô nứt (giữ cảnh báo); `_draw_swing` tô ô + nhãn "Nick 0.5"; tô ô của `_draw_feedback` / `_draw_boss_feedback` (giữ số sát thương "-N"); `_draw_interrupt` tô + X (giữ chữ NGẮT ngắn); chớp gai). Thiếu gói → giữ đường vẽ cũ, không crash. *(Đóng 2026-10-31: người dùng bảo bỏ mọi thanh thời gian, kể cả thanh 2 px của BurnPainter.)*
- [x] Không gì trên mặt ô che đơn vị ngoài F6 / F8 (chớp ≤ 0,35 s).

**Phần C — Test và bằng chứng**
- [x] Test đơn vị: chọn gói theo trạng thái ô; hàng đợi một lần hết hạn đúng; reduce motion; thiếu gói → null.
- [x] Toàn bộ suite `FAILS=0`.
- [x] Ảnh `production/qa/evidence/floor-vfx/`: mỗi hiệu ứng một ảnh trong trận + một ảnh tổng hợp các gói phóng 4×; evidence doc có chữ ký (Visual/Feel).

## Notes
- VFX workbench miễn phí; không dùng công cụ tạo ảnh trả phí trong story này. Nếu một gói cần ảnh nguồn trả phí, hỏi người dùng trước.
- Ô báo đòn giữ phẳng theo P3; nếu playtest muốn "sống" hơn, chỉ thêm chuyển động nhẹ cho sọc, không đổi màu hay hình.

## Completion Notes
**Completed**: 2026-10-31
**Criteria**: 10/10 verified (A 3, B 4, C 3); 2 khác câu chữ gốc (xem Deviations). Hoãn: cảm giác thời lượng và độ đậm của hiệu ứng khi chơi (playtest).
**Deviations** (ADVISORY, người dùng chấp nhận khi đóng):
- Nét nứt F4 (`cracked_cell`) có viền đỏ rất tối #1B0404, không phải Mực #1B1722 trong bảng màu; đỏ dành cho ô báo đòn (art bible P3). Sửa nhỏ: đổi màu trong `whole.png` và `front.png`.
- Chưa phủ kín ô: F3, F6, F8 là tia nhỏ giữa ô; F7 chiếm khoảng hai phần ba ô ở lúc to nhất. F1, F2, F4, F5, F9 là gói `fill` (cắt theo ô).
- Thanh thời gian 2 px bị bỏ theo người dùng; AC gốc ghi "giữ thanh 2 px".
- Ảnh F3, F4, F7 (08–11) chụp bằng probe tạm gọi `FloorVfx.play` / `SlamTrait` thật, không qua một trận chơi; ảnh 01–07 chụp trước đợt chỉnh màn hình trận `1b91b90`.
- Candidates nằm ở `design/assets/candidates/floor-vfx/f<n>-<id>/` (không phải `pack-<id>/`); file zip để ngoài git.
- Hiệu ứng vùng (lầy, miệng phun, bão, cát) để story asset vùng; ô Ấn / hố là story Ô rớt.
**Test Evidence**: Visual/Feel: evidence doc `production/qa/evidence/floor-vfx-evidence.md` ký `[x] Approved` (DatPT, solo, 2026-10-31); ảnh `production/qa/evidence/floor-vfx/01–12`; test `tests/unit/art/floor_vfx_test.gd`; 129 headless + 6 windowed FAILS=0.
**Code Review**: Skipped (solo mode)
