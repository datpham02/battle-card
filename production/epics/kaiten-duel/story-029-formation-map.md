# Story 029: Trận đồ — ô sáng khi được phủ, phai dần, sáng đủ cùng lúc thì tuyệt kỹ sẵn sàng

> **Epic**: Kaiten Duel (v5)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md` (v5, mục "Trận đồ")
**Requirement**: Người dùng muốn các mảnh "ghép lại thành nguyên hình sân" để có hiệu ứng đặc biệt. Gom mảnh trong túi cho khít sân không chạy được (túi 3, sân tới 36 ô, người chơi sẽ ôm mảnh thay vì đánh). Quyết định 2026-10-25: **trận đồ tích qua nhiều đòn** — mỗi đòn phủ ô nào thì ô đó sáng trên đất địch, trúng hay trượt đều tính; ô sáng **phai dần** và phải phủ lại; khi **mọi ô thật của đất địch cùng sáng** thì trận đồ hoàn thành. Trận đồ **thay thanh nạp tuyệt kỹ** (hiện là 18 ô đã tung) — không thêm thanh thứ hai. Người dùng lo "không giới hạn thời gian thì quá dễ": cơ chế phai từng ô là giới hạn đó, không dùng đồng hồ đếm ngược chung.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Logic**

- [ ] `FormationMap` (RefCounted, thuần, thuộc trạng thái trận để test không cần cảnh): một đồng hồ mỗi ô thật của đất địch. `cover(cells)` đặt đồng hồ các ô đó về `fade_sec`; `tick(dt)` trừ dần; `lit_count()`, `total()`, `fraction_left(cell)`, `is_complete()` (mọi ô cùng > 0), `reset()`.
- [ ] `fade_sec = fade_base_sec + fade_per_cell_sec × số ô thật của đất địch` (khởi điểm 4,0 s và 0,6 s, `combat.json`, có trong `schema.md`): sân 3×3 ≈ 9,4 s, 4×3 ≈ 11,2 s, vòng 21 ô ≈ 16,6 s.
- [ ] Đòn của người chơi phủ trận đồ **khi tới nơi** (trúng hay trượt); đòn bị phá phép không tính. Đòn 2 mảnh (Story 028) phủ hợp ô của nó.
- [ ] **Trận đồ thay thanh nạp**: hoàn thành ⇒ tuyệt kỹ sẵn sàng (nút sáng như hiện nay) và trận đồ xóa về rỗng; trong lúc tuyệt kỹ đang sẵn sàng mà chưa dùng, đòn mới vẫn phủ nhưng không tích thêm lần sẵn sàng thứ hai. Kích hoạt tuyệt kỹ không xóa trận đồ đang tích (đã xóa lúc hoàn thành). `charge_cells` trong `characters.json` và `signature_charge_cells` trong `combat.json` bỏ (hoặc ghi `deprecated` trong `schema.md` nếu còn chỗ đọc); `SignatureCharge` bỏ hoặc thành vỏ đọc `FormationMap` — chọn cách ít đụng nhất, ghi lại.
- [ ] Không mang qua trận; boss không có trận đồ.

**Phần B — HUD**

- [ ] Ô sáng trên đất địch: viền/ánh sáng nhạt theo `fraction_left` (đậm khi mới phủ, nhạt dần), **nhấp nháy** khi còn dưới `fade_warn_ratio` (khởi điểm 0,25). Không che boss, bóng mảnh, cảnh báo đòn boss và các ô cháy/Rạn/nứt — vẽ dưới chúng, đọc được trên màn nhỏ.
- [ ] Nút tuyệt kỹ thay "x %" bằng "Trận đồ lit/total" (khóa `TEXT_*` vi/en); đầy thì nút sáng như cũ.
- [ ] Khi hoàn thành: toàn bộ đất địch lóe sáng ~0,5 s và tên trận đồ/tuyệt kỹ hiện như banner tuyệt kỹ hiện có.

**Phần C — Kiểm chứng**

- [ ] Test thuần: phủ, phai đúng `fade_sec` theo cỡ sân, hoàn thành chỉ khi mọi ô cùng sáng, sân có lỗ chỉ tính ô thật, phủ lại làm tươi, đòn bị phá phép không phủ, tuyệt kỹ sẵn sàng đúng một lần, không mang qua trận.
- [ ] Đo bằng bot (scratch, từ `hit_probe.gd` / `deck_sim.gd`): thời gian trung bình tới khi hoàn thành trận đồ ở 3–4 sân chương 1 với nhịp ra đòn của bot hiện tại; so với thời gian đầy thanh 18 ô cũ. Mục tiêu khởi điểm: tuyệt kỹ sẵn sàng **1–3 lần mỗi trận** như trước; lệch thì chỉnh `fade_base_sec` / `fade_per_cell_sec`, không chỉnh mã. Bảng vào Completion Notes.
- [ ] Ảnh trong `production/qa/evidence/formation-map/`: trận đồ phủ một nửa (ô đậm và ô nhạt); ô sắp tắt nhấp nháy; nút "Trận đồ 7/9"; lúc hoàn thành (đất địch lóe sáng, banner); sân vòng có lỗ; bản tiếng Anh.
- [ ] Không hằng số gameplay trong mã; chuỗi mới là khóa `TEXT_*` với vi và en.

---

## Implementation Notes

- `FormationMap` cạnh `SignatureCharge` trong trạng thái trận; một điểm gọi `cover` duy nhất ở chỗ đòn người chơi tới nơi (`SwingArbiter` / `CombatView._on_swing_resolved`).
- `--demo=formation_half|formation_warn|formation_complete` cho chụp ảnh.

---

## Out of Scope

- Trận đồ cho boss, hiệu ứng "Đại trận" riêng ngoài tuyệt kỹ, nâng cấp tuyệt kỹ, cân bằng lại ba chương (Story 026 đo lại sau cùng).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/formation-map/`; bảng thời gian hoàn thành trận đồ.

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 024 (mảnh), Story 028 (đòn 2 mảnh phủ hợp ô), Story 021 (tuyệt kỹ, nút, banner)
- Unlocks: Story 025 (não boss viết theo luật cuối), Story 026 (đo lại cân bằng)
