# Story 008: Hệ cắt của người chơi — 1 điểm chém ngay, 2–4 điểm vẽ hình, menu kỹ năng

> **Epic**: Kaiten Duel (v3)
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-18

## Context

**GDD**: `design/game-brief.md` (v3)
**Requirement**: Brief MVP feature 3 — 1 điểm chém ngay sang điểm đối diện; 2–4 điểm vẽ đoạn/đa giác trên bàn boss với xem trước và số ô; sát thương và khoảng vung theo số ô phủ; menu kỹ năng chậm 0,2× với Chém và Đẩy

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` v3 (Core loop: Cắt, Menu kỹ năng; MVP feature 3), scoped to this story:*

- [ ] **Nhãn → điểm chu vi → tập ô** là hàm thuần (`CutResolver`): với 1 nhãn trả về 3 ô của cột (A/C) hoặc hàng (B/D) tương ứng; với 2 nhãn trả về các ô mà đoạn thẳng đi qua; với 3–4 nhãn trả về ô mà cạnh đi qua **cộng** ô trong lòng đa giác. Test xác định: A1 → cột 1 (3 ô); D2 → hàng 2; A1+C3 → 3 ô chéo; A1+A3+C3+C1 → 9 ô; A1+A3 → 3 ô hàng 1 (cạnh trên).
- [ ] **1 điểm**: chạm ô tay là **chém ngay** (không menu, cờ `single_point_opens_menu` = false); điểm rời tay.
- [ ] **2–4 điểm**: chạm lần lượt để chọn (chạm lại để bỏ chọn); bản xem trước trên bàn boss sáng **tập ô đang phủ** và hiện **số ô**; nút **Chốt** xuất hiện khi ≥ 2 điểm được chọn. Chốt là tốn điểm, không hủy.
- [ ] **Khoảng vung** = cơ bản + mỗi ô × số ô (khởi điểm 0,2 + 0,25 s); trong khoảng vung tập ô hiện **đỏ trên bàn boss** với đếm ngược; hết vung thì chém. Người chơi **vẫn di chuyển được** khi đang vung. Chỉ một đòn của người chơi vung tại một thời điểm; đang vung thì không chốt đòn khác (tay vẫn chọn được).
- [ ] **Sát thương = cơ bản × số ô** (khởi điểm 6 × ô, HP 100), trúng nếu ô boss nằm trong tập **lúc chém** (không đọc vị trí lúc chốt). HIT/MISS hiện tại ô liên quan; số sát thương hiện rõ.
- [ ] **Menu kỹ năng**: sau khi chốt 2–4 điểm, menu hiện ở phía tay phải và game chậm theo `skill_menu_time_scale` (0,2; 0 = dừng hẳn); đồng hồ chọn **3 s thật**, hết giờ tự chọn Chém. Kỹ năng khóa vẫn hiện với "cần N ô".
- [ ] Hai kỹ năng ở story này, đọc từ `skills.json`: **Chém** (bất kỳ ô, không cooldown) và **Đẩy** (≥ 3 ô, cooldown 6 s: trúng thì boss lùi 1 ô theo hướng cắt nếu có chỗ + sát thương nhẹ). Cooldown hiện mờ trên nút và đếm theo thời gian thật. Đốt và Ghim là dữ liệu có sẵn nhưng khóa (Story 010).
- [ ] Mọi số (vung, sát thương, time scale, thời gian chọn, ngưỡng ô, cooldown) trong `assets/data/cuts.json` và `assets/data/skills.json`, ghi `schema.md`.
- [ ] Ảnh chụp màn hình: xem trước 2 điểm với số ô; xem trước đa giác 4 điểm phủ 9 ô; menu kỹ năng đang chậm với Đẩy mở và Đốt/Ghim khóa; vung đỏ trên bàn boss; HIT với số sát thương; MISS — giữ lại trong `production/qa/evidence/cut-system/`.

---

## Implementation Notes

- `CutResolver` thay `AttackShape`: đầu vào danh sách nhãn, đầu ra `Array[Vector2i]` ô bàn đối thủ theo hệ tọa độ của bàn đó (0–2), không biết gì về phe; lớp gọi dịch sang ô bàn 6×3. Đoạn thẳng: duyệt ô mà đoạn cắt qua (supercover); đa giác: điểm tâm ô nằm trong đa giác hoặc cạnh đi qua ô. Điểm chu vi là tọa độ thật trên biên (A1 = (0,5; 0), D2 = (0; 1,5)…); hai đầu trùng cạnh cho đoạn chạy dọc cạnh.
- Thay `CardPlayer` bằng `CutActor` (RefCounted, một thể hiện mỗi phe ngay từ đầu, theo ghi chú review Story 006): giữ đòn đang vung (tập ô, kỹ năng, đồng hồ), tiêm delta, phát tín hiệu `swing_started/swing_resolved(cells, hit, damage)`. Story này chỉ tạo thể hiện cho người chơi; boss (009) dùng cùng lớp.
- Làm chậm: nhân delta của mọi hệ trong trận với time scale khi menu mở (không dùng `Engine.time_scale` để đồng hồ chọn chạy thật và UI không chậm). `max_tick_sec` giữ nguyên.
- `CombatState` cần API đối xứng `damage(side, amount)` và `cell_changed(side, old, new)`; bỏ giáp.
- Cập nhật hook `--demo=` (preview_2pt, preview_4pt, skill_menu, swing, hit, miss).

---

## Out of Scope

- Story 009: boss cắt, ngắt đòn hai chiều.
- Story 010: Đốt, Ghim, bảng cân bằng.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Retained screenshot trong `production/qa/evidence/cut-system/`.
- Logic: `tests/unit/combat/cut_resolver_test.gd` — khuyến nghị mạnh (hàm thuần, các ca trong tiêu chí 1), không bắt buộc ở `minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007
- Unlocks: Story 009
