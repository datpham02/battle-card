# Story 030: Làm lại Thiên Hỏa và Ảnh Bộ — gắn với trận đồ, bỏ điều kiện khó đạt, cân bằng giá trị mỗi phút

> **Epic**: Kaiten Duel (v5)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md` (v4 "Nhân vật", v5 "Trận đồ")
**Requirement**: Story 029 Phần D đo bằng bot (`production/qa/evidence/formation-map/signature-cooldown.md`, 168 dòng): giá trị mỗi phút (sát thương thêm + máu hồi) của ba tuyệt kỹ là khoảng **6–8 : 1,5 : 1** (Trảm : Thiên Hỏa : Ảnh Bộ) ở mọi thời gian hồi. Thời gian hồi chỉ bớt số lần dùng nên không nâng được tuyệt kỹ yếu. Nguyên nhân: Thiên Hỏa cần đất địch đang cháy (85–90 % lần dùng gần như không có lửa); Ảnh Bộ cần boss đang bị Ghim trong 2 s (thẻ Ghim khởi đầu cần 4 ô, hồi 10 s). TD-005 đã nêu từ Story 021. Người dùng chốt 2026-10-25: viết story riêng, cân bằng theo **tỉ lệ tương đối**, không cần bằng nhau (quyết định TD-008).

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Thiên Hỏa: đốt cả trận đồ**

- [ ] Khi kích hoạt, Thiên Hỏa **đốt mọi ô thật của đất địch đang sáng trong trận đồ** (lúc kích hoạt trận đồ vừa đủ nên thường là cả sân) với `burn_stacks` tầng Đốt (params trong `characters.json`, khởi điểm 1), **rồi** kích nổ toàn bộ cháy trên sân như hiện nay (`detonate_mult`), và đặt lại cooldown lá đốt như cũ. Thứ tự đốt → nổ ghi rõ trong mã; số trong dữ liệu.
- [ ] Đọc trận đồ **trước** khi `activate_signature` xóa nó (một điểm duy nhất, không đổi luật Story 029).

**Phần B — Ảnh Bộ: nhân đôi mọi đòn nhỏ**

- [ ] Trong `duration_sec`, **mọi đòn ≤ `small_cells` ô** của người chơi được ×`small_mult` (đổi tên từ `pinned_small_mult`, khởi điểm 2), không còn cần boss bị Ghim. Bước không cooldown giữ nguyên. Cộng dồn với `quick_blade` như cũ.
- [ ] `characters.json` và `schema.md` cập nhật tên khóa; khóa cũ `pinned_small_mult` vẫn đọc được (cảnh báo, dùng như `small_mult`) để không vỡ dữ liệu.

**Phần C — Cân bằng và kiểm chứng**

- [ ] Bot (sao từ `sigcd_probe.gd` của Story 029) đo lại giá trị mỗi lần dùng, số lần dùng mỗi trận và giá trị mỗi phút của ba tuyệt kỹ (P = 0,5 và 0,25; sân vuông, chữ nhật, chữ thập, vòng). Mục tiêu: thứ tự Trảm ≥ Thiên Hỏa ≥ Ảnh Bộ vẫn giữ, nhưng chênh lệch giá trị mỗi phút **không quá khoảng 2 : 1** giữa mạnh nhất và yếu nhất; tối đa ~3 lần dùng mỗi trận trên sân vuông. Lệch thì chỉnh **dữ liệu** (`burn_stacks`, `detonate_mult`, `small_mult`, `duration_sec`, `cooldown_sec`), không chỉnh mã. Bảng vào `production/qa/evidence/signature-rework/signature-balance.md`.
- [ ] Mô tả tuyệt kỹ (`signature.thien_hoa.desc`, `signature.anh_bo.desc`, vi/en) và dòng tuyệt kỹ ở màn chọn nhân vật viết lại theo luật mới, vừa hai dòng như Story 021.
- [ ] Test: Thiên Hỏa đốt đúng các ô trận đồ đang sáng rồi nổ; không có trận đồ (debug) thì chỉ nổ phần cháy có sẵn; Ảnh Bộ ×2 cho đòn ≤ `small_cells` khi boss không bị Ghim, không áp cho đòn lớn hơn, hết hiệu lực thì thôi; khóa cũ `pinned_small_mult` vẫn đọc được.
- [ ] Ảnh trong `production/qa/evidence/signature-rework/`: Thiên Hỏa vừa kích hoạt (cả sân cháy, số nổ); Ảnh Bộ đang hiệu lực với một đòn nhỏ trúng ×2; màn chọn nhân vật với mô tả mới (vi và en).
- [ ] Không hằng số gameplay trong mã; chuỗi mới là khóa `TEXT_*` với vi và en.

---

## Implementation Notes

- Thiên Hỏa cần đọc trận đồ: truyền danh sách ô đang sáng vào `BaseSignature` qua ctx lúc kích hoạt (một điểm trong `CombatView.activate_signature`, trước khi trận đồ xóa).
- Dùng lại API cháy hiện có của `StatusEffects` (cộng tầng Đốt cho từng ô).

---

## Out of Scope

- Làm lại Trảm, tuyệt kỹ thứ hai, nâng cấp tuyệt kỹ, nhân vật 4–5, tuyệt kỹ cho boss.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/signature-rework/`; bảng cân bằng.

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 029 (trận đồ, thời gian hồi), Story 021 (tuyệt kỹ)
- Unlocks: cân bằng nhân vật (TD-008), Story 026 (đo lại ba chương)
