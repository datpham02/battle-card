# Story 007: Nút di chuyển 4 hướng + điểm cắt rơi trên ô (gỡ băng chuyền và thẻ cũ)

> **Epic**: Kaiten Duel (v3)
> **Status**: Ready
> **Layer**: Core
> **Type**: UI
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-18

## Context

**GDD**: `design/game-brief.md` (v3)
**Requirement**: Brief MVP feature 2 — nút di chuyển 4 hướng (một ô mỗi lần, cooldown, không nhớ lệnh) và điểm cắt rơi theo túi xáo + nhịp + độ tươi; nhặt bằng cách bước lên; tay 4 điểm ở góc dưới phải

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` v3 (Core loop: Sân và di chuyển, Điểm cắt rơi; MVP feature 2), scoped to this story:*

- [ ] **Nút di chuyển** 4 hướng ở góc dưới trái (cỡ ngón cái, không hover): mỗi lần bấm đi đúng **một ô**; cooldown bước cấu hình được (khởi điểm 0,45 s); **bấm trong lúc cooldown thì mất, không xếp hàng lệnh**; không đi ra ngoài nửa sân của mình; thanh cooldown nhỏ hiện dưới chân nhân vật.
- [ ] **Điểm rơi**: điểm xuất hiện trên **ô trống ngẫu nhiên bên nửa sân người chơi** (không rơi vào ô đang đứng), tối đa N điểm trên nửa sân (khởi điểm 4). Mỗi điểm mang **nhãn chu vi** A1–A3, B1–B3, C1–C3, D1–D3 (quy ước trong brief), vẽ rõ trên ô.
- [ ] **Túi xáo**: nhãn rút từ túi 12 nhãn, hết túi thì xáo lại, RNG có seed tiêm được. Test xác định: 12 lần rơi liên tiếp cho đủ 12 nhãn, không trùng.
- [ ] **Nhịp rơi**: nhịp nền cấu hình được (khởi điểm 1,8 s); **bù khi đói**: tay trống quá ngưỡng (4 s) thì nhịp nhân hệ số (0,6) đến khi nhặt được; điểm **được phép** rơi vào ô đang nằm trong tập ô vung của đối thủ (cờ dữ liệu, bật). Boss chưa vung ở story này nhưng API phải nhận tập ô đó.
- [ ] Mỗi điểm trên sân có **độ tươi** (khởi điểm 7 s) hiện bằng hình trên ô, đổi màu khi sắp ôi; hết giờ thì biến mất và nhãn **không** quay lại túi (đã rút là đã rút).
- [ ] **Bước lên ô có điểm là nhặt** vào ô tay trống; **trong tay không ôi**; tay đầy (4) thì điểm nằm lại trên ô và người chơi thấy rõ lý do (nhãn FULL như hiện tại); điểm đã nhặt rời ô ngay.
- [ ] Hàng ô tay ở **góc dưới phải** hiển thị nhãn điểm (A1…), không còn tên thẻ; bàn cờ dùng phần chiều cao được giải phóng; không có gì chồng lên nhau ở 1280×720.
- [ ] **Gỡ**: `ConveyorView`/`ConveyorBelt` khỏi cảnh chính và dữ liệu; thẻ Step, Guard, Strike, Cannon, Wide Slash và kéo-để-bước khỏi `CardDragController`; giáp khỏi HUD. Chạm vào ô tay ở story này chỉ **chọn/bỏ chọn** điểm (sáng viền), chưa cắt (Story 008).
- [ ] Hệ điểm rơi có API cho một "người nhặt" thứ hai (boss, Story 009) với túi, nhịp và nửa sân riêng; chưa dùng ở story này (boss đứng yên).
- [ ] Ảnh chụp màn hình: bố cục mới với nút di chuyển và tay bên phải; vài điểm rơi với nhãn và độ tươi khác nhau; một điểm sắp ôi; tay đầy với điểm nằm lại; thanh cooldown bước đang chạy — giữ lại trong `production/qa/evidence/field-drops-dpad/`.

---

## Implementation Notes

- Logic điểm rơi là RefCounted (`FieldDrops`: túi xáo, nhịp, bù đói, độ tươi, nhặt), tiêm delta và RNG; một thể hiện cho mỗi phe với tham số riêng. View mỏng vẽ lên ô. Tái dùng RNG có seed từ `ConveyorBelt` rồi gỡ nó.
- Di chuyển là lệnh vào `CombatState.set_player_cell` qua bộ cooldown riêng (RefCounted `MoveCooldown`); boss dùng cùng bộ với tham số riêng (Story 009). Nhặt là hệ quả của việc đổi ô (nghe tín hiệu `cell_changed`).
- Dữ liệu: `assets/data/field_drops.json` (nhịp, tối đa trên sân, độ tươi, ngưỡng đói, hệ số bù, tay tối đa, cờ rơi dưới đường dao, danh sách nhãn); `combat_cards.json` đổi tên thành `combat.json` chỉ còn HP, cooldown bước, `max_tick_sec`, `feedback_sec`, ô xuất phát. Ghi `schema.md`. `hold_slots.json` giữ phần kích thước/padding.
- Thứ tự xử lý input (từ review Story 006): nút di chuyển là Control riêng, xử lý trước; chạm ô tay là chọn; giữ `tap_threshold_px`; không để hai node cùng xử lý một lần chạm.
- Cập nhật hook `--demo=`; các demo dựa trên băng chuyền/Step/thẻ đánh sửa hoặc bỏ.
- Story 006 còn `AttackShape`, `CardPlayer`, shapes trong dữ liệu: gỡ dữ liệu thẻ ở đây, để code `CardPlayer`/`AttackShape` lại cho Story 008 thay bằng `CutResolver`.

---

## Out of Scope

- Story 008: chạm điểm để cắt, xem trước, menu kỹ năng.
- Story 009: boss di chuyển, nhặt, cắt; ngắt đòn.
- Thủ đoạn rơi của boss, hiện trước nhãn sắp rơi (backlog).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: UI
**Required evidence**:
- Retained screenshot của từng trạng thái đã chạm tới, trong `production/qa/evidence/field-drops-dpad/`.
- Logic túi xáo: `tests/unit/drops/field_drops_test.gd` — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006
- Unlocks: Story 008
