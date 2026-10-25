# Story 034: Bộ mảnh của run — trọng số hình mảnh riêng của người chơi, "Ấn hình" và "Xóa hình", luôn còn hình vừa sân

> **Epic**: Kaiten Duel (v6)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md` (v6, mục "Run v6 — mô hình OSFE" → "Xây build trong run": **Bộ mảnh**; nền: mục "Core loop (v5)" → "Mảnh ấn rơi", "Ghép mảnh và hình chủ đạo")
**Requirement**: Hiện túi rơi của người chơi lấy trọng số cố định theo chương (`pieces.json` → `weights.ch1..ch3`, đọc qua `PieceLibrary.weight(id, chapter_id)` trong `FieldDrops._draw_piece`). Brief v6 coi bộ mảnh là **bộ bài thứ hai của run**: người chơi thêm hình hoặc bỏ bớt hình để lái build (mảnh nhỏ niệm nhanh, mảnh lớn sát thương cao, cặp hình để ghép hình chủ đạo). Boss vẫn dùng trọng số gốc.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM (đổi nguồn trọng số của `FieldDrops`, luật dự phòng "luôn có hình vừa sân", save run)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Mô hình bộ mảnh**

- [ ] `RunSession.piece_deck` = `{mult: {shape_id: float}, added: [shape_id]}`. Khởi đầu: mọi hình có trong `pieces.json` → `shapes` với `pool` mặc định có `mult` 1,0; `added` rỗng. Lưu khóa `piece_deck` trong save run; thiếu khóa = khởi đầu; id lạ bị bỏ có cảnh báo.
- [ ] **Trọng số hiệu dụng** của người chơi trong một trận: `w(s) = base(s, khóa vùng/tầng) × mult(s)`; với hình chỉ có qua run (`pool: "run_only"`) thì `base = run_only_weight` (khởi điểm 6). `base` vẫn lấy từ `pieces.json` theo khóa vùng/tầng mà Story 031 chốt (hiện là `ch1..ch3`/`default`). Hình có `w = 0` không rơi.
- [ ] `pieces.json` thêm 3 hình **chỉ có qua run** (khởi điểm; vì không lật nên ảnh gương là hình khác): `z4` (gương của `s4`), `j4` (gương của `l4`), `y5`. Có `name_key` vi/en, `pool: "run_only"`. Bảng hình trong `schema.md` cập nhật.
- [ ] `FieldDrops.enable_pieces` nhận thêm một nguồn trọng số tiêm vào (Callable hoặc Dictionary, mặc định = trọng số gốc) — không đọc `RunSession` trực tiếp; `CombatView` truyền trọng số hiệu dụng cho **phía người chơi**. **Boss không bị ảnh hưởng**: mọi đường rơi mảnh của boss vẫn đọc `PieceLibrary.weight` gốc (test xác nhận).

**Phần B — Ấn hình và Xóa hình**

- [ ] **Ấn hình** (phần thưởng): đưa ra 2 hình (seeded); chọn một → nếu là hình `run_only` chưa có thì thêm vào `added` (`mult` 1,0); nếu đã có thì `mult += 1,0` (trần `mult_max` khởi điểm 4,0). Hình đã ở trần không được đưa ra.
- [ ] **Xóa hình**: đặt `mult(s) = 0`. Từ chối (không đổi gì, có thông báo) khi sau đó bộ còn **ít hơn `min_shapes`** hình có `mult > 0` (khởi điểm 5). Hình đã xóa có thể được Ấn hình lại (về `mult` 1,0).
- [ ] **Luôn còn hình vừa sân**: lúc vào trận, nếu không hình nào trong bộ (có `w > 0`) đặt vừa đất địch của sân đó (bộ lọc `PiecePlacement.has_any_placement` sẵn có), thì trận đó dùng trọng số gốc cho các hình vừa sân, ghi cảnh báo, và HUD hiện một dòng "Bộ mảnh không vừa sân này — dùng mảnh gốc". Test với một bộ chỉ còn hình 5 ô trên sân hẹp.
- [ ] Nguồn (số trong `rewards.json` → khối mới `piece_rewards`, mô tả trong `schema.md`): sau trận `battle`/`danger` thắng, với xác suất `ink_offer_chance` (khởi điểm 0,35) màn thưởng có thêm hàng **Ấn hình** (chọn hoặc bỏ qua, không mất lượt chọn lá); kho báu luôn có hàng Ấn hình; **token Xóa hình** `shape_removals` khởi đầu 1, +1 mỗi boss vùng, dùng ở màn bộ mảnh. Nếu Story 033 đã xong: cửa hàng thêm dịch vụ "Xóa hình" (giá khởi điểm 45, 1 lần/cửa hàng) và một sự kiện có thể trao Ấn hình — không bắt buộc cho story này.

**Phần C — Hiển thị (mobile ngang, ngón cái)**

- [ ] Màn **Bộ mảnh**, mở bằng một nút trên HUD bản đồ (và từ màn thưởng khi chọn Ấn hình/Xóa hình): lưới các hình (vẽ bằng code như hình thu nhỏ trên sân), mỗi hình kèm **% rơi** tính theo vùng kế tiếp (hoặc vùng hiện tại), số `mult` dạng chấm (1–4), hình đã xóa mờ có gạch. Ô chạm mỗi hình ≥ 64 dp.
- [ ] Xóa hình: chạm hình → hình nổi lên, nút **Xóa hình (còn N token)** góc dưới phải; khi bị chặn bởi `min_shapes` nút mờ kèm lý do. Ấn hình: hai thẻ hình lớn giữa màn, chạm chọn rồi xác nhận góc dưới phải, "Bỏ qua" góc dưới trái.
- [ ] Màn thưởng hiện hàng Ấn hình dưới hàng lá, không đẩy nút xác nhận ra khỏi vùng ngón cái.

**Phần D — Kiểm chứng**

- [ ] Test (`tests/unit/pieces/` hoặc `tests/unit/run/`): trọng số hiệu dụng đúng công thức; Ấn hình thêm `run_only` và tăng `mult`, dừng ở `mult_max`; Xóa hình bị chặn ở `min_shapes`; luật dự phòng khi không hình nào vừa sân; boss rơi theo trọng số gốc khi bộ người chơi đã đổi; `FieldDrops` với nguồn trọng số tiêm vào cho phân bố đúng trên 10 000 lần rút seeded (sai số ≤ 2 điểm %); save/load giữ `piece_deck` và `shape_removals`.
- [ ] **Mô phỏng**: `deck_sim` / `hit_probe` thêm `--piece-deck=remove:mono,bar2|add:y5,square` (bộ mảnh cố định cho bot từ đầu run). Ba cấu hình × 3 nhân vật × 70 seed: gốc; bỏ hình nhỏ (`mono`, `bar2`, `bar3`); bỏ hình lớn (`plus5`, `u5`, `bar5`). Báo tỉ lệ trúng theo cỡ đòn, số đòn mỗi trận, tỉ lệ ghép, tỉ lệ đòn hình chủ đạo, phá phép được/bị phá, và tỉ lệ thắng vùng/run. Nếu một cấu hình nâng tỉ lệ thắng **quá 10 điểm** (khởi điểm) so với gốc thì đó là chiến lược trội: chỉnh `min_shapes`, `mult_max` hoặc `run_only_weight` và đo lại. Bảng trong Completion Notes và `production/qa/evidence/piece-deck/simulation-piece-deck.md`.
- [ ] Ảnh trong `production/qa/evidence/piece-deck/`: màn Bộ mảnh với một hình đã xóa và một hình `mult` 3 (vi và en); màn Ấn hình hai thẻ (vi và en); nút Xóa hình bị chặn ở `min_shapes`; trên sân rơi một hình `run_only` (`z4` hoặc `j4`); dòng HUD của luật dự phòng.
- [ ] Không hằng số gameplay trong mã; chuỗi mới (`piece.z4.name`, `piece.j4.name`, `piece.y5.name`, `TEXT_PIECE_DECK_*`) có vi và en.

---

## Implementation Notes

- Điểm đổi duy nhất của việc rút: `FieldDrops._draw_piece()` (đang cộng `_piece_library.weight(id, _chapter_id)`); thay bằng một hàm trọng số tiêm vào khi `enable_pieces` được gọi, mặc định gọi lại `PieceLibrary.weight`.
- `PieceLibrary` (`src/pieces/piece_library.gd`) bỏ qua hình `run_only` trong `weight()` gốc (trả 0) để chúng không rơi cho boss hay trận không có run.
- Hình chủ đạo của sân (`arenas.json`) có thể không còn ghép được sau khi người chơi xóa hình: đây là đánh đổi của người chơi, không chặn; chỉ ghi số liệu trong mô phỏng.
- `--demo=piece_deck|ink_offer|shape_remove_blocked|run_only_drop|deck_fallback` cho chụp ảnh.

---

## Out of Scope

- Bộ mảnh cho boss; hình mảnh có hiệu ứng riêng (mảnh cháy, mảnh nguyền); lật hình; hình 6 ô trở lên; mở khóa hình theo cột mốc (story chơi lại); bảo vật đổi bộ mảnh (có thể thêm sau ở `relics.json`); dịch vụ cửa hàng khi Story 033 chưa xong.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/piece-deck/` (màn mới có bản vi và en); `simulation-piece-deck.md` + raw.

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 031 (bản đồ thế giới v6: khóa vùng/tầng cho trọng số gốc, màn thưởng v6, save run v6)
- Unlocks: dịch vụ "Xóa hình" ở cửa hàng (Story 033 nếu làm sau), bảo vật về bộ mảnh, mở khóa hình mảnh theo cột mốc
