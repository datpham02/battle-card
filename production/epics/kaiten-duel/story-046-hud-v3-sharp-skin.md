# Story 046: HUD v3 — dải cảnh xa 20 %, giao diện vẽ sắc, ô báo đòn đậm dần

> **Epic**: Kaiten Duel (v6)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-31

## Context

**GDD**: `design/art/art-bible.md` §1 (bảng OSFE, hệ quả kỹ thuật: báo đòn trọn ở lớp sàn, không gì trên ô che đơn vị), §4 (dòng Báo đòn đậm dần), §6.3 (bệ nổi B), §6.4 (dải cảnh xa 20 %), §7.3 (chữ), §7.4 (HUD vẽ sắc ở 720p, hình khung, icon 55 px), §7.5 (thanh máu 12 px, vết mất máu, nấc nửa máu); `design/ux/hud.md` (Z1 3–20 %, Z2 20–64 %, I-17/E-17 ô báo đòn đậm dần); `design/quick-specs/control-layout-v2.md` (Story 044, cụm điều khiển); `design/assets/specs/slice1-combat-ui-assets.md` (ASSET-012 `intensity`, ASSET-013/015 ứng viên); `docs/art/ASSET_SPECIFICATION.md` §1 (hợp đồng render).
**Requirement**:
- **Hiện trạng:** `ScreenLayout` đặt sân từ 3 % + 20 % của arena (≈ 13 %) tới 55 %; `CombatView._draw_hud` vẽ hai thanh máu bằng `draw_rect` + `ThemeDB.fallback_font`; `CutHudView._draw_boss_swing` tô ô đỏ phẳng và vẽ **nhãn đếm ngược** "x,x s" + tên đòn + số ô lên trên; mọi nút là chữ nhật tối viền mảnh; không font riêng.
- **Đích (người dùng chốt 2026-10-31, mock `prototypes/art-check --skin=osfe --floor… --platform --band-top=0.20 --tele-k`, ảnh 56–61):**
  1. **Dải cảnh xa 20 %**: sân bắt đầu ở 20 % chiều cao (hàng rộng kết thúc ≤ 64 %, hàng hẹp ≤ 76 % theo Story 044); 0–20 % chỉ có HUD Z1 (3–8 %) và nền.
  2. **HUD vẽ sắc ở độ phân giải gốc**: panel header hai bên vát góc 45°, thanh máu 12 px có rãnh, vết mất máu, số và tên; thanh Bản Khắc chia đốt; pause và info là ô icon; ô túi là thẻ có huy hiệu giá; Thức Tỉnh là kim cương; chip từ khóa dưới chân đơn vị; **không tấm số máu dưới chân**; màu Đá Đêm #1E1B24 / viền Sương #7D8896 / chữ #F4F6FA viền #0F1219; font sans thật thay `fallback_font`.
  3. **Ô báo đòn đậm dần**: bỏ nhãn đếm ngược; các ô đỏ hiện mờ khi địch bắt đầu niệm và đậm dần đều tới đầy đúng lúc đòn rơi; tô, sọc chéo và viền đều **dưới chân đơn vị**.
- **Không thuộc story này:** sprite, SubViewport 640×360 và phiến/bệ vẽ bằng texture (story kỹ thuật riêng), joystick và vòng cung túi (Story 044), xuất sheet (Story 045), nền v2 thật (hiện là ứng viên).

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM (đổi hình học sân lần nữa sau Story 044 → mọi suite click windowed bấm toạ độ cũ; bỏ nhãn đếm ngược là đổi cách người chơi đọc nhịp đòn, cần playtest; font mới phải phủ tiếng Việt)
**Engine Notes**: giữ Node2D + `_draw` như toàn bộ UI hiện có, không dùng `Control`; `draw_colored_polygon` + `draw_polyline` cho vát góc và kim cương (đã chạy trong prototype); font nạp một lần bằng `FontFile.load_dynamic_font` và cache (art bible §8.8: TTF động, antialiasing xám, không MSDF); `draw_texture_rect_region` với `texture_filter = NEAREST` cho icon 55 px.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Hình học (`src/layout/screen_layout.gd`)**

- [ ] Hằng số `BOARD_BAND_TOP_RATIO = 0.20` thay cho công thức `ARENA_TOP_RATIO + HUD_HEIGHT_RATIO × arena`; `board_area_rect()` bắt đầu ở 20 %. Z1 giữ 3–8 %; 8–20 % không chứa yếu tố nào.
- [ ] Bảng cỡ ô cập nhật và kiểm ±1 px: 5x5 → 43×31 art-px (86×62 px) với đáy 64 %; 3x3 → 64×46 (trần); pha lê 6x6 với đáy 76 % → 46×33. Số cũ (49×35 cho 5x5) không còn được tham chiếu.
- [ ] Mọi hàm chạm (`cell_at`, túi, Thức Tỉnh, joystick/pad) đúng với dải mới; không ô nào nằm dưới nút.

**Phần B — Chữ và khung (`src/ui/hud_skin.gd` mới, dùng bởi `CombatView` và `CutHudView`)**

- [ ] `HudSkin` là một file tĩnh cung cấp: `panel(canvas, rect, cuts, fill, line)` (vát góc 45°, cạnh `cuts` theo px), `diamond(canvas, center, r, fill, line, width)`, `segments(canvas, rect, total, filled, lit)`, `text(canvas, pos, str, size, color, align, width)` (viền 3 px #0F1219 + chữ), `hp_bar(canvas, rect, ratio, trail, fill, notch)`, `slot_card(...)`, `icon(canvas, name, pos, scale)`; màu là hằng số đặt tên theo art bible §4 / §7.4 (Đá Đêm, Sương, Ngà, Ánh Lưới, xanh máu #58D468, vết #B8B0A0).
- [ ] **Font**: `HudSkin.font_semibold()` / `font_bold()` nạp từ `assets/fonts/` (Noto Sans SemiBold + Bold, OFL, tập con Latin + Vietnamese; **việc tải file cần người dùng duyệt**, tới lúc đó dùng `ThemeDB.fallback_font` qua cùng hàm, không gọi `fallback_font` rải rác). Cỡ theo §7.3: tên 24 SemiBold, số máu 20–24 Bold, nhãn phụ 13–18. Chuỗi kiểm "Tiếng Việt ẳ ẵ ặ ế ộ ử ữ ự Đ đ Ơ ơ Ư ư" hiện đủ dấu.
- [ ] **Z1**: header trái 430×60 px vát góc dưới-phải: tên + cấp, thanh máu 300×12 (rãnh #15131A, tô #58D468, vết #B8B0A0 co 0,4 s, số "170/200" bên phải), thanh Bản Khắc 300×6 chia 7 đốt vàng + "n/21"; header phải đối xứng cho địch: thanh Ngà, nấc nửa máu Ngà 2 px nhô 3 px, 3 ô khối boss; pause và info là icon 55 px giữa trên. Thanh và số vẽ sắc ở pixel màn hình (không nhân 2).
- [ ] **Z4/Z5**: ô túi = thẻ Đá Đêm vát góc trên-phải, viền Sương 1,5 px (Ngà 3 px khi chọn), huy hiệu trắng 30×30 góc dưới-trái ghi số ô, khối xem trước vẽ bằng ô thép 18 px có bevel; nút Thức Tỉnh = kim cương bán kính 57 px viền Ánh Lưới 3 px với icon 55 px và "n/21"; bộ đếm túi "5 / 9" trên tấm nhỏ. Kích thước chạm theo Story 044 không đổi.
- [ ] **Chip từ khóa** (I-23): icon 55 px vẽ ở tỉ lệ 0,5 **tạm**, đặt **dưới chân** đơn vị, căn giữa, tối đa 2 trên sân 5x5; không tấm số máu dưới chân (số máu chỉ ở Z1).
- [ ] Icon đọc từ `assets/art/ui/ui_icons_55.png` + `.json` (sao chép từ ứng viên `design/assets/candidates/slice1-ui/osfe-icons/`, import Lossless, không mipmap); khi thiếu file, vẽ hình dự phòng bằng code như hiện tại, không crash.

**Phần C — Ô báo đòn đậm dần (`src/combat/cut_hud_view.gd`, `src/combat/cut_actor.gd`)**

- [ ] `CutActor.get_progress() -> float` = `1 − time_left / duration` của đòn đang niệm (duration lưu lúc `begin_swing`, kể cả override và các hệ số Story 018/032); 0 khi không niệm.
- [ ] `_draw_boss_swing` **không vẽ nhãn đếm ngược, tên đòn hay số ô** nữa; thay bằng: với `k = get_progress()`, mỗi ô vẽ tô đỏ #E5293B alpha `lerp(0, 0,45, k)`, sọc chéo 45° (texture 8×8 `fx_telegraph_stripe_8.png` lặp, hoặc vẽ bằng code) alpha `lerp(0,5, 1, k)`, viền 2 px đỏ + mép Mực 1 px ngoài alpha `lerp(0,3, 1, k)`. Hằng số ba cặp này đặt tên và nằm trong `CombatConfig` (data-driven).
- [ ] Toàn bộ ô báo đòn (tô, sọc, viền) vẽ **dưới đơn vị**: chuyển sang lớp của `CombatView` trước khi vẽ đơn vị, hoặc tách `FloorLayer` vẽ trước `CombatView`. `CutHudView` chỉ còn vẽ trên đơn vị những thứ art bible cho phép (VFX trúng ≤ 0,35 s, biểu ngữ, menu).
- [ ] Đòn trong hàng chờ (Story 013) vẽ ở `k = 0` với sọc thưa hơn (giữ phân biệt "sắp" và "đang"); đòn giữ Khối Lạ vẫn mang dấu sao góc (Story 041).
- [ ] **Giảm chuyển động** (`accessibility.reduce_motion`): `k` lượng tử hoá thành 3 bậc 0 / 0,5 / 1 thay vì liên tục. Không nhấp nháy ở bất kỳ bậc nào.
- [ ] Màn tạm dừng / thông tin đòn vẫn hiện tên đòn và số ô (chữ bỏ khỏi sân không mất khỏi game).

**Phần D — Test và bằng chứng**

- [ ] Test đơn vị `tests/unit/layout/`: `board_area_rect` bắt đầu ở 20 %; bảng cỡ ô mới (3x3, 5x5, pha lê 6x6); không chồng lấn nút.
- [ ] Test đơn vị `tests/unit/combat/`: `get_progress()` ở 0 %, 50 %, 100 % và sau khi đòn kết thúc; ba công thức alpha ở `k` = 0 / 0,5 / 1 (hàm thuần trong `CombatConfig` hoặc `HudSkin`, không cần node); lượng tử hoá 3 bậc khi reduce motion.
- [ ] Test đơn vị `HudSkin`: đa giác vát góc đúng số đỉnh; `segments` chia đúng số đốt; `text` không vỡ với chuỗi tiếng Việt (độ rộng > 0).
- [ ] Các suite click windowed cập nhật toạ độ theo dải 20 %; toàn bộ test `FAILS=0`.
- [ ] Ảnh 1280×720 lưu `production/qa/evidence/hud-v3/`: 5x5 đầu trận; đòn địch ở `k ≈ 0`, `0,5`, `1` với Kiếm sĩ đứng trên ô đỏ (chứng minh không che người); thẻ túi có khối, một thẻ chọn, một thẻ trống; Thức Tỉnh sẵn sàng; chip từ khóa trên goblin; chuỗi tiếng Việt; một ảnh 1600×720 kiểm lề; một ảnh với reduce motion. Đối chiếu bằng mắt với `asset-slice1-art-check/58`, `60`, `61`.
- [ ] `design/ux/hud.md` ghi lại số liệu đã đo (cỡ ô, vị trí) nếu lệch so với spec.

---

## Notes

- Thứ tự làm đề xuất: A (hình học) → C (báo đòn, vì đổi luật chơi và lớp vẽ) → B (skin) → D. A và C có thể chạy song song với B nếu `HudSkin` được dựng trước với font dự phòng.
- Prototype `prototypes/art-check/art_check.gd` chứa bản vẽ tham khảo của mọi hình (`_draw_hud_osfe`, `_chamfer`, `_diamond`, `_segments`, `_hp_bar`, `_slot_card`, `--tele-k`); **viết lại theo chuẩn production, không copy** (`.claude/rules/prototype-code.md`).
- Bộ 9-slice pixel 16×16 (ASSET-013) và icon 12×12 (ASSET-015) giữ làm dự phòng cho đường pixel; story này không dùng chúng.
- Tải Noto Sans (OFL) là hành động cần người dùng duyệt; story có thể hoàn thành với font dự phòng và ghi rõ trong bằng chứng.
- Playtest sau story: người chơi có còn đọc được "đòn còn bao lâu" chỉ qua độ đậm không; nếu không, bước lùi là thêm thanh co dần mảnh ở mép trên cụm ô (không chữ), không quay lại nhãn.
