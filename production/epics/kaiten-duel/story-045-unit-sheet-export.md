# Story 045: Xuất sprite sheet đơn vị slice 1 — nguồn PNG, exporter Python, JSON kiểu Aseprite

> **Epic**: Kaiten Duel (v6)
> **Status**: In Progress
> **Layer**: Presentation (asset pipeline)
> **Type**: Config/Data + Visual
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-31

## Context

**GDD**: `design/art/art-bible.md` §8.1 (định dạng, thư mục, tên; sửa 2026-10-31: nguồn PNG được chấp nhận), §8.3 (khung: anh hùng 40x48, quái 32x48), §8.6 (clip và thời lượng khung), §8.7 (import Lossless, mipmap tắt, fix_alpha_border), §8.9 (bảng kiểm); `design/assets/specs/swordsman-assets.md` và `goblin-scout-assets.md` (bảng clip, đường dẫn xuất, generation log); `design/assets/asset-manifest.md`.
**Requirement**:
- **Hiện trạng:** 22 khung candidate đã kiểm (§8.9 #1, #3, #7, #9) nằm ở `design/assets/candidates/swordsman/ASSET-001-*-40x48.png` (14 khung) và `design/assets/candidates/goblin-scout/ASSET-003-*-32x48.png` (8 khung). Chưa có `art_src/`, `assets/art/`, không có Aseprite trên máy, code game chưa nạp texture nào.
- **Đích:** mỗi đơn vị một sheet `.png` + `.json` ở `assets/art/units/`, định dạng đúng §8.1 để story SubViewport sau này vẽ bằng `draw_texture_rect_region` + bảng khung từ JSON (§8.6), không cần biết nguồn là Aseprite hay PNG.
- **Quyết định nguồn (người dùng chốt 2026-10-31, phương án A):** nguồn vẽ là thư mục PNG rời + `clips.json`, exporter Python thuần (máy không có Pillow). `.aseprite` sẽ thay thế khi có họa sĩ làm trong Aseprite; JSON giữ đúng định dạng Aseprite "array" nên engine không đổi.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: LOW (chỉ thêm file và script; rủi ro là `.import` sai cờ làm vỡ pixel, và hold `step` phụ thuộc cooldown nên JSON chỉ là giá trị danh nghĩa)
**Engine Notes**: `.import` của ảnh trong `assets/art/` **phải commit** (khác với `production/qa/evidence/`), vì nó mang cờ Lossless / mipmap / fix_alpha_border. Đặt `art_src/.gdignore` để Godot không import nguồn.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Nguồn vẽ (`art_src/`)**

- [ ] `art_src/.gdignore` tồn tại. Cấu trúc `art_src/units/<id>/<clip>/<n>.png` với `<id>` là id dữ liệu (`kiem_si`, `goblin_scout`), `<n>` từ `0`. Khung chép từ candidates, **không đổi pixel** (kiểm bằng hash trong test).
- [ ] `art_src/units/<id>/clips.json` ghi thứ tự clip, danh sách khung, thời lượng ms mỗi khung và kiểu lặp theo §8.6:

  | Đơn vị | Clip theo thứ tự hàng | Khung | ms | Lặp |
  |---|---|---|---|---|
  | kiem_si | `idle` | idle-A, idle-B | 400, 400 | loop |
  | | `step` | step-A, step-B | 300, 300 (danh nghĩa, code theo cooldown) | loop |
  | | `cast_gesture` | cast-A, cast-B | 80, 120 | once |
  | | `hit` | hit | 120 | once |
  | | `victory` | victory-A, victory-B | 400, 400 | loop |
  | | `defeat` | defeat-A, defeat-B | 150, 150 | hold last |
  | | `fall` | fall | 0 | hold |
  | | `awaken` | awaken-A, awaken-B | 120, 120 | loop |
  | goblin_scout | `idle` | idle-A, idle-B | 400, 400 | loop |
  | | `step` | step-A, step-B | 300, 300 | loop |
  | | `windup` | windup | 0 | hold đến hết báo đòn |
  | | `hit` | hit | 120 | once |
  | | `down` | down-A, down-B | 150, 150 | hold last |

- [ ] Bảng màu nguồn: `art_src/palette/tessera_master.gpl` chứa đúng các hex đang dùng (8 của Kiếm sĩ, 7 của Goblin với nâu đã sửa #856B50 / #66523F); exporter đối chiếu, pixel ngoài bảng là lỗi.

**Phần B — Exporter (`tools/asset-pipeline/export_sheets.py`)**

- [ ] Python 3 thuần (`-I`, không Pillow): đọc `clips.json`, dựng sheet **mỗi hàng một clip, ô cố định theo khung đơn vị, đệm 1 px trong suốt giữa ô và quanh mép**; ghi `assets/art/units/unit_<id>_sheet.png` RGBA 8-bit, alpha chỉ 0/255.
- [ ] Kích thước: `unit_kiem_si_sheet.png` 81x391 (2 cột 40 px + 1 đệm; 8 hàng 48 px + 7 đệm); `unit_goblin_scout_sheet.png` 65x244 (2 cột 32 px; 5 hàng).
- [ ] `unit_<id>_sheet.json` theo định dạng Aseprite **array**: `frames[]` với `filename` = `<id>_<clip>_<n>`, `frame {x,y,w,h}`, `rotated false`, `trimmed false`, `spriteSourceSize`, `sourceSize`, `duration`; `meta.frameTags[]` với `name`, `from`, `to`, `direction` (`forward`), và một trường mở rộng `meta.tessera.loop` cho mỗi tag (`loop | once | hold_last | hold`), `meta.image`, `meta.size`, `meta.scale "1"`.
- [ ] Chạy lại cho ra byte giống hệt (deterministic); thêm `--check` để CI so sánh file đã commit với kết quả mới và báo lỗi khi lệch.
- [ ] `tools/asset-pipeline/README.md`: cách chạy, cách thêm đơn vị, quy ước tên; ghi rõ đây là đường thay thế `.aseprite` theo §8.1.

**Phần C — Import Godot**

- [ ] Mở project một lần (hoặc `godot --headless --import`) để sinh `.import` cho hai sheet; sửa và commit với `compress/mode=0` (Lossless), `mipmaps/generate=false`, `process/fix_alpha_border=true`, `process/premult_alpha=false`. Một test đọc hai file `.import` và khẳng định bốn cờ này.
- [ ] Không có `.import` nào sinh ra trong `art_src/` hay `design/assets/candidates/` (cả hai có `.gdignore`).

**Phần D — Test và nghiệm thu**

- [ ] `tests/unit/art/sheet_export_test.gd` (hoặc Python test chạy trong CI nếu đọc PNG dễ hơn): kích thước sheet; mỗi ô trong JSON cắt ra **giống pixel** với khung nguồn tương ứng; alpha chỉ 0/255; số màu ≤ 8 mỗi đơn vị và thuộc bảng; tag và duration đúng bảng ở Phần A; đệm 1 px trong suốt.
- [ ] Ảnh bằng chứng `production/qa/evidence/unit-sheet-export/`: hai sheet phóng 4x, và một lần nạp thử trong `prototypes/art-check` bằng `--sheet` (đọc sheet + JSON thay vì PNG rời) chạy clip `cast` và `down`, để chứng minh JSON đủ cho engine.
- [ ] `design/assets/asset-manifest.md`: ASSET-001 và ASSET-003 → **Done** (sheet + JSON có trong `assets/art/units/`), chờ chữ ký art-director (solo: người dùng) để lên Approved.
- [ ] Thêm hai sheet vào danh sách kiểm của `/asset-audit` (tên, cỡ, định dạng) nếu skill đó có cấu hình; nếu không thì ghi chú trong README của pipeline.

---

## Notes

- `art_src/` và `assets/art/` chưa tồn tại; story này tạo cả hai cùng `.gdignore` cho `art_src/`.
- Atlas chung và atlas vùng (§8.1, script của technical-artist) ngoài phạm vi: mới có 2 đơn vị, chưa cần gộp.
- Nối sprite vào `combat_view.gd` (thay vòng tròn YOU và ô đỏ) thuộc story SubViewport 640x360, sau story này.

## Implementation Notes (2026-10-31)

Implemented on branch `claude/vigilant-chebyshev-4d039b` (side session of the Story 047 session), uncommitted.

- **Files:** `art_src/.gdignore`, `art_src/palette/tessera_master.gpl`, `art_src/units/{kiem_si,goblin_scout}/clips.json` + 22 frames (byte-identical copies of the candidates), `tools/asset-pipeline/export_sheets.py` + `README.md`, `assets/art/units/unit_{kiem_si,goblin_scout}_sheet.{png,json,png.import}`, `tests/unit/art/sheet_export_test.gd` (158 checks, FAILS=0), `prototypes/art-check/art_check.gd` (`--sheet=<dir>`), evidence `production/qa/evidence/unit-sheet-export/01–04`.
- **Facing recorded** in `meta.tessera.facing`: `kiem_si` = `right`, `goblin_scout` = `left` (the 3/4 south-east / south-west rotations of the specs; checked on the frames). Story 047 flips the unit whose side needs the other direction.
- **Gutter and edge:** the 81x391 / 65x244 sizes fix a 1 px gutter *between* cells only; the "around the edge" margin is the frame's own transparent margin (§8.3), which the exporter enforces on the left, right and top edges. The bottom row is exempt: feet touch the last pixel row by §8.3, so the sheet's bottom edge is not transparent.
- **Palette:** `tessera_master.gpl` lists the 8 Swordsman + 7 Goblin Scout spec colours (13 unique; Ink and Ivory shared). Goblin leather is the lifted `#9A7D5E` / `#66523F` of fix-02 (the story's `#856B50` was superseded the same day); `#59643F` (skin dark) is in the spec but unused by the current frames.
- **Import:** the four §8.7 flags were already Godot's defaults for these PNGs; `detect_3d/compress_to` was set to 0 on top so a 3D use can never switch the sheet to VRAM compression. The test asserts all five.
- **`/asset-audit`** has no configurable asset list, so the exported-sheet register is the table in `tools/asset-pipeline/README.md`.
- **Hold-frame durations:** `fall` and `windup` carry `duration: 0` (held by code); art-check shows them for 0.4 s.
