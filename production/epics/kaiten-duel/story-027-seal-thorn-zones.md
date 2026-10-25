# Story 027: Kết giới và Trận gai — vùng chặn và vùng thu phí đặt bằng mảnh, cho cả người chơi và boss

> **Epic**: Kaiten Duel (v5)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-24

## Context

**GDD**: `design/game-brief.md` (v5, mục "Vùng: Kết giới và Trận gai")
**Requirement**: Người dùng muốn trận đấu "đấu trí một tý": có phép làm một vùng ô **không vào được**, hoặc **vào thì mất máu** để đánh đổi né một đòn khác; nhiều mảnh nối nhau để ép boss vào thế phải nhận sát thương. Phía boss đã có mầm của ý này (boss tránh ô cháy qua `burn_avoid`, trait `slam` làm nứt ô bên người chơi qua `UnitMover.blocked_cell_fn`, `row_burner` là vùng đi qua mất máu); người chơi chưa có công cụ tương ứng.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Hai loại vùng**

- [ ] **Kết giới** (`seal`): các ô của mảnh trên đất bên bị nhắm **không bước vào được** trong `seal_sec` (khởi điểm 1,2 s). Bên đang đứng trong ô đó khi vùng hình thành thì không bị đẩy, nhưng ra rồi không vào lại được.
- [ ] **Trận gai** (`thorns`): bước vào ô gai được, nhưng mỗi lần bước vào mất `thorn_damage` (khởi điểm 6) và nhận 1 tầng Rạn; vùng kéo dài `thorn_sec` (khởi điểm 3 s).
- [ ] **Luật chừa đường**: một vùng mới không được để bên bị nhắm **không còn ô nào bước được** từ ô đang đứng; ô vi phạm bị bỏ khỏi vùng (giữ nhiều ô nhất có thể), như cách `ArenaValidator` giữ sân hợp lệ. Áp dụng cho cả hai bên.
- [ ] Số trong `combat.json` (`seal_sec`, `thorn_sec`, `thorn_damage`), có trong `schema.md`. Trạng thái vùng nằm trong `StatusEffects` cạnh `burn`/`pin` (API `is_sealed(side, cell)`, `thorns_at(side, cell)`), không trong view.

**Phần B — Lá của người chơi và boss hiểu vùng**

- [ ] 4 lá mới trong pool (`cards.json`, có `name_key`/`desc_key` vi/en, màu từ khóa riêng trên thẻ thưởng): *Kết giới* (thường, 2 ô, chỉ tạo vùng), *Lồng ấn* (hiếm, 3 ô, kết giới + sát thương nhẹ), *Trận gai* (thường, 3 ô), *Gai nguyền* (hiếm, 4 ô, gai + Rạn 2 tầng khi vào). Vùng hình thành khi đòn **tới nơi**, trúng hay trượt boss đều có vùng.
- [ ] Não boss: ô kết giới là ô chặn khi tìm đường và né; ô gai có chi phí `thorn_avoid` (trọng số mới trong `boss_brain.json`, như `burn_avoid`) — boss có thể chọn đi qua gai khi né một đòn lớn hơn phí. Ghi điểm chấm vào debug như các trọng số khác.

**Phần C — Boss dùng vùng lên người chơi**

- [ ] Trait `seal_caster`: cứ `interval_sec` boss đặt một kết giới mảnh 2–3 ô trên đất người chơi, ngay trước một đòn lớn (dồn người chơi). Trait `thorn_field`: boss phủ trận gai lên đường thoát của người chơi khi niệm đòn ≥ 4 ô. Cả hai tuân luật chừa đường.
- [ ] Gán vào chương 2–3 (`chapters.json`): ít nhất 1 miniboss chương 2 và 1 boss hoặc miniboss chương 3; tên và mô tả trait có khóa vi/en.

**Phần D — Hiển thị và kiểm chứng**

- [ ] Hình khác hẳn nhau: kết giới là khối đặc có viền sáng; gai là viền răng cưa; cả hai có thanh thời gian còn lại. Đọc được trên cả hai đất.
- [ ] Test: ô kết giới chặn bước trong `seal_sec` rồi mở; vào ô gai mất máu và Rạn mỗi lần vào; luật chừa đường bỏ đúng ô; boss né qua gai khi phí nhỏ hơn đòn và đi vòng khi phí lớn hơn; vùng hình thành khi đòn trượt; trait đặt vùng đúng nhịp và tuân luật chừa đường.
- [ ] Mô phỏng: bot người chơi dùng lá vùng theo quy tắc đơn giản (kết giới chặn đường thoát rồi đánh vào ô còn lại); báo tỉ lệ trúng và tỉ lệ thắng chương 2–3 trước và sau khi thêm lá vùng vào Completion Notes. Chỉnh dữ liệu nếu lá vùng mạnh vượt (tỉ lệ thắng chương tăng quá 15 điểm).
- [ ] Ảnh trong `production/qa/evidence/seal-thorn-zones/`: kết giới trên đất boss dồn boss vào góc; trận gai trên đất boss; boss đi qua gai; trait boss đặt kết giới lên đất người chơi; thẻ thưởng lá vùng (vi và en).
- [ ] Không hằng số gameplay trong mã; chuỗi mới là khóa `TEXT_*` với vi và en.

---

## Implementation Notes

- Ô kết giới dùng lại `UnitMover.blocked_cell_fn` (đã có từ trait `slam`); gộp nhiều nguồn chặn (nứt, kết giới) qua một hàm hợp thay vì ghi đè.
- Áp vùng ở **một** điểm khi đòn tới nơi (`CutEffects` / `SwingArbiter`), dù trúng hay trượt.
- `--demo=seal_on_boss|thorns_on_boss|boss_seal` cho chụp ảnh.

---

## Out of Scope

- Vùng có hiệu ứng khác (hồi máu, tăng tốc), vùng tồn tại cả trận, tương tác vùng với Đốt/Hàn ngoài Rạn, nội dung chương mới.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/seal-thorn-zones/`; bảng mô phỏng trước/sau.

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 024 (mảnh), Story 025 (boss dùng mảnh), Story 026 (bot mảnh và cân bằng nền)
- Unlocks: cửa hàng/pact, Android
