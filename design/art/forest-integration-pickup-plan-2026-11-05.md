# Rừng Sương: nối nền với sân + Khối nhặt voxel — chẩn đoán và kế hoạch

**Ngày:** 2026-11-05 · **Đầu vào:** `C:/Users/ADMIN/Downloads/tessera_regions_background_arena_blocks_v2.md` (mục 10)
· **Trạng thái:** chỉ đọc code + mockup miễn phí. **Chưa gọi API tốn credit, chưa sửa gameplay hay renderer.**

---

## 1. Thông số đã xác minh trong repo (thay cho các mục [CẦN KIỂM TRA])

| Hạng mục | Giá trị thật | Nguồn |
|---|---|---|
| Viewport nghệ thuật | **800×360 art-px** (không phải 640×360), SubViewport nearest, hiện ra màn hình theo bội số nguyên | `src/battle/battle_canvas.gd` (ScreenLayout.ART_CANVAS_WIDTH/HEIGHT) |
| Thứ tự lớp trong canvas | BackdropLayer → FloorLayer (+ FloorDynamicLayer) → UnitLayer → OverlayLayer | `battle_canvas.gd` |
| Sân phối cảnh | Sân vẽ trong SubViewport riêng rồi nắn hình thang, hàng sau / hàng trước **0,82** | `combat.json` `floor.perspective.back_ratio`, `canvas_floor_perspective.gdshader` |
| Bệ sân | Code vẽ bằng màu phẳng: mặt bệ, mặt trước 12 art-px dưới hàng cuối, khe giữa hai nửa, bóng | `src/battle/floor_layer.gd` (SlabPainter.paint_platform), `region.json` → `platform` |
| Nền | `bg_forest_far.png` 800×360 vẽ từ (0, 0) + dải sương `bg_forest_near.png` 800×48 (đáy ở hàng 70) | `src/battle/backdrop_layer.gd`, `region.json` |
| Khối nhặt (field piece) | **Không nằm trong canvas pixel**: `FieldDropsView` (Node2D trong `battle.tscn`) vẽ bằng hình vector ở độ phân giải màn hình qua `BoardGeometry.to_screen` | `src/drops/field_drops_view.gd`, `src/battle/battle.tscn` |
| Thứ tự Khối / nhân vật | FieldDropsView, BossDropsView → **BattleUnitView** (nhân vật đè lên Khối) → HoldSlotsView → CutHudView | `battle.tscn`, `battle_unit_view.gd` |
| Số hình Khối | **19 hình** (mono … y5) + Khối Lạ (hình ngẫu nhiên tới 7 ô) | `assets/data/pieces.json`, Story 041 |
| Hero | Khung nguồn 96×96, hiện trong game ở khung 96×70 / 96×72 | `art_src/units/*/clips.json` |

---

## 2. Vì sao nền và sân trông rời nhau

Chụp so sánh: `design/assets/candidates/pickup-voxel/mockup-forest-current.png`.

1. **Hai mặt đất chồng nhau.** `bg_forest_far.png` có sẵn **một nền đất với phiến đá lát rải rác và cột gãy** ở nửa dưới (thấy rõ dưới sân, y ≈ 480–720). Sân đấu là một mặt đất thứ hai đặt lên trên. Hai mặt đất khác tỉ lệ phiến, khác góc nhìn.
2. **Hai góc nhìn khác nhau.** Sân được shader nắn hình thang (0,82), còn nền vẽ nhìn ngang và không bị nắn. Mép trên sân thu vào trong khi nền phía sau không có đường phối cảnh tương ứng.
3. **Bệ là màu phẳng.** Mặt trước bệ (12 art-px) chỉ là dải `#262521` có vạch mạch, không có chất liệu đá/rêu như vòm và cột của nền, và **không có gì đỡ bên dưới** (không tường, móng, rễ). Đọc như một tấm bảng trôi trước tranh.
4. **Màu hai nửa sân.** Nhuộm `#B8CCE8` / `#9A84A4` (nhân) kéo phiến về xanh lạnh / tím, lệch khỏi họ rêu xám của nền.
5. **Dải sương mỏng và nằm sai chỗ.** Sương 800×48 ở hàng 70 (cuối dải cảnh xa), không có sương che chân sân như art bible mô tả ("sương thấp che chân phiến").

## 3. Vì sao Khối nhặt giống icon phẳng

1. **Vẽ ngoài canvas pixel:** hình vector ở độ phân giải màn hình (`PieceDraw.draw_shape`), không phải pixel art → khác hẳn chất liệu của sân và nhân vật.
2. **Không có chiều dày:** các ô vuông phẳng, không mặt trên / mặt bên, không bóng, không chuyển động.
3. **Tô cả ô:** ô bên dưới được phủ màu 12–18 % + viền màu + thanh thời gian + nhãn.
4. **Lưu ý quan trọng về màu:** xanh lá → vàng → đỏ hiện nay **là độ tươi (thời gian còn lại trước khi Khối biến mất)**, không phải loại Khối. Nếu bỏ màu phủ ô, phải giữ cách báo thời gian khác (xem 4.3).
5. Khối Lạ (Story 041) dùng màu tím-hồng và dấu lấp lánh; Khối thối (Story 014) màu xám có dấu X. Hai trạng thái này cũng cần có phiên bản voxel.

---

## 4. Kế hoạch đề xuất (Forest trước, chưa thực hiện)

### 4.1 Nền tách lớp (PixelLab, cần duyệt)

| Asset | Mô tả | Công cụ dự kiến | Gen ước tính |
|---|---|---|---|
| Nền xa mới | Giữ rừng, vòm, cột lề của bản hiện tại; **bỏ mặt đất lát phiến dưới sân**, thay bằng đất tối mờ dần + sương thấp để sân là mặt đất duy nhất | Pixen 640×360 (như ASSET-005) rồi ghép 800×360 bằng script, hoặc sửa từng mảng ≤ 256 px bằng `edit_image_pro_flash` | 3–6 |
| Bộ đỡ sân (support kit) | Dải tường đá cũ / vòm thấp / chân cột cùng đá xám-rêu, **ghép modular** để chạy dưới mặt trước bệ ở mọi dạng sân (3×3 … 6×4) + 2 cụm rễ ôm góc | `create_image_pro_flash` (dải tileable 128×32 + 2 góc 48×48) | 10–15 |
| Lớp sương chân sân | Sương thấp vắt ngang chân bệ, trôi ≤ 1 px/s | vẽ lại bằng script (miễn phí) hoặc Pixen 1 gen | 0–1 |

Phần code (miễn phí, cần duyệt riêng): một lớp **SupportLayer** giữa Backdrop và Floor, tự đặt các mảnh tường/vòm theo đúng đáy sân của mỗi dạng arena; mặt trước bệ đổi từ màu phẳng sang texture cùng họ đá; giảm độ nhuộm hai nửa sân (giữ phân biệt phe, kéo về họ rêu xám). **Không đổi lưới, số ô, hitbox, vị trí nhân vật, HUD.**

### 4.2 Khối nhặt trên sàn: ấn ký đá cổ (Ancient Stone Sigil) — **vẽ bằng code, không gen**

> **Lịch sử quyết định.** 2026-11-05: item voxel 3D xoay kiểu Minecraft (bỏ: khi xoay, thanh dài quay đầu chỉ còn một
> chấm, Khối Lạ 7 ô thành một cục). 2026-11-06 sáng: polyomino 2D vàng nổi, nhấp nhô, có bóng (bỏ: trông như icon UI
> sáng đặt lên sân). **2026-11-06, bản hiện hành (người dùng, "Ground Block Pickup Visual Redesign"):** Khối là
> **ấn ký hình học cổ khảm vào mặt đá**.

**Thứ tự ưu tiên:** (1) nhận ra đúng hình polyomino, (2) đọc ngay giữa trận, (3) hợp art bible Tessera,
(4) đơn giản, dễ bảo trì, (5) chi tiết trang trí.

Lý do vẽ bằng code:
- Có **19 hình + Khối Lạ ngẫu nhiên tới 7 ô**: gen từng hình ≈ 19+ gen và **không gen được Khối Lạ**.
- Dựng từ **một mẫu ô vuông đá dùng lại** cho mọi hình và mọi chất liệu: hình mới / chất liệu mới không cần sprite riêng.

Cách trình bày:
- Mỗi Khối là **polyomino 2D phẳng nằm trên ô sàn**, ghép từ các **ô vuông đá nhỏ nối cạnh với nhau**, đúng hình và đúng hướng như trên tay (dữ liệu `pieces.json`, không xoay, không đổi hình cho vừa ô).
- Mỗi ô vuông: **viền tối mảnh 1 px** (dùng chung giữa hai ô kề nhau, nên khe giữa các ô là 1 đường tối), **mép trên-trái sáng hơn 1 px**, **mép dưới-phải tối hơn 1 px**, mặt giữa một tông. Trông như đá khảm, không phải khối 3D nổi.
- **Phong hóa cổ (người dùng 2026-11-06: "cổ cổ tý cho hợp phong cách game"):** ô vuông đủ lớn (mặt trong ≥ 7 px) khắc mờ họa tiết văn hóa duy nhất của Tessera, **"ô vuông lồng ô vuông"** (vòng 1 px lùi 2 px vào trong); mỗi ô một **chấm rỗ**; các **góc lồi ngoài cùng mòn mất 1 px**. Hình Khối không đổi.
- **Nằm theo mặt đá (người dùng 2026-11-06: "có ngóc nghiêng giống mặt đá"):** Khối vẽ trong mặt phẳng sàn phẳng rồi nắn bằng **cùng shader phối cảnh với sàn** (không nhuộm màu nửa sân); ô vuông ép dẹt theo tỉ lệ cao/rộng của ô sàn như phiến đá.
- Màu trầm: Khối thường **đá ngà cũ** (mặt `#C9BB9B`, mép sáng `#DCCFB0`, mép tối `#8F8167`, khắc `#A8997B`); Khối Lạ (Story 041) **tím trầm**; Khối thối (Story 014) **xám** + dấu X. Không dùng xanh thép `#8FA3B8` cho Khối thường vì gần màu nhuộm nửa sân người chơi `#B8CCE8`.
- **Không** nổi, nhấp nhô, xoay, bóng đổ, hạt, lấp lánh, glow. **Không** tô cả ô, **không** viền vàng/xanh quanh ô. Đá sàn, vết nứt, rêu lộ nguyên.
- Khối nằm **đúng tâm ô sau phép nắn phối cảnh** (`BoardGeometry`), vẽ ở **PickupLayer** trong canvas pixel 800×360 (nearest, thẳng pixel), sau FloorLayer, trước UnitLayer. Lớp riêng: không sửa texture sàn; nhặt Khối thì chỉ lớp Khối mất.
- **Kích thước theo khung bao của từng hình:** cạnh ô vuông = min(0,68 × bề ngang ô / số cột, 0,80 × chiều cao ô / số hàng), kẹp 4–14 art-px. Hình rộng ≥ 3 cột chiếm khoảng 60–75 % bề ngang ô; hình 1–2 cột bị chặn trên để không che hết đá; luôn chừa khoảng trống tới mép ô. Ô vuông tối thiểu 4 px để vẫn có mép sáng, mặt và mép tối (kiểm ở ô nhỏ nhất 38×27).
- **Độ tươi = Khối nứt dần** (người dùng chốt 2026-11-05: "từ từ nứt ra, hết thời gian thì bể hoàn toàn rồi tan biến"); hợp với chất liệu đá:

  | Thời gian còn lại (Khối nằm 8 s, `field_drops.json` `piece_freshness_sec`) | Hình |
  |---|---|
  | 100–55 % | Nguyên vẹn |
  | 55–28 % | Vết nứt mảnh 1 px trên mặt đá |
  | 28–0 % | Nứt sâu + mẻ góc (pixel mất ở cạnh) |
  | Hết hạn | **Vỡ vụn tại chỗ:** từng ô vuông đá biến mất theo thứ tự ngẫu nhiên trong ~0,4 s, không văng hạt; xong thì ô sàn trống |

  Ngưỡng 55 % / 28 % lấy từ `FieldDropsView.FRESH_RATIO` / `WARN_RATIO`. Màu Khối cố định (không xanh → đỏ).
- Ô báo đòn đỏ, viền xác nhận khi đặt khối, hiệu ứng trạng thái **giữ nguyên** (FloorDynamicLayer / CutHudView). Khối màu đá trầm nên không lẫn với các lớp báo hiệu đó.
- Không đổi logic nhặt, rải, xoay, túi Khối, kích thước sân, phối cảnh, nền, nhân vật, HUD.

### 4.3 QA

- Mockup trước/sau ở camera hiện tại (ảnh chụp thật, cùng khung 1280×720).
- Sân nhỏ `square` 3×3, sân lớn `boss_hall` 6×4, `cross` (ô khuyết), hố rớt / ô cháy / bãi gai có Khối nằm trên.
- Kiểm tra bắt buộc của tài liệu: tắt PickupLayer thì ô bên dưới không đổi pixel nào.
- Chạy toàn bộ test + test mới cho PickupLayer (tâm ô, đúng hình từng ô, kích thước, thứ tự vẽ với nhân vật).
- Nguyên mẫu ở Rừng Sương với ít nhất các hình L, T, S, I, U, Chữ thập; kiểm ở độ phân giải thật và cỡ màn điện thoại; duyệt trước khi áp cho mọi vùng.
- Ảnh bằng chứng lưu trong `production/qa/evidence/forest-integration/`.

### 4.4 Thứ tự đề xuất và chi phí

| Bước | Nội dung | Gen |
|---|---|---|
| 1 | PickupLayer ấn ký đá bằng code (mọi hình, độ tươi nứt / vỡ vụn) | 0 |
| 2 | SupportLayer + texture mặt bệ + chỉnh nhuộm hai nửa sân (code, dùng tạm màu/đá hiện có) | 0 |
| 3 | Nền xa Forest không có mặt đất thứ hai | 3–6 |
| 4 | Bộ đỡ sân Forest (tường/vòm/rễ) | 10–15 |
| **Tổng Forest** | | **~13–21** |

Mỗi lần gen: đưa prompt, công cụ, số gen để duyệt trước; gen thử 1 mảnh trước khi làm cả bộ.

---

## 5. Mockup (miễn phí, không gen)

- Hiện tại: `design/assets/candidates/pickup-voxel/mockup-forest-current.png`
- Đề xuất Khối voxel ở tâm ô (vàng hình L 3 ô, xanh thanh 2 ô), sàn giữ nguyên màu đá:
  `design/assets/candidates/pickup-voxel/mockup-forest-voxel-pickups.png`
- Vòng xoay + bob, phóng to 3 lần: `design/assets/candidates/pickup-voxel/mockup-pickup-loop-x3.gif`
  (**đã thay** bằng polyomino 2D nhìn thẳng, xem 4.2 cập nhật 2026-11-06; giữ mockup làm lịch sử quyết định)
- Script mockup (pure Python, fxkit): scratchpad `voxel_mock.py` — chỉ để duyệt hướng, bản thật viết trong Godot.
