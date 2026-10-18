# Story 006: Hai lưới 3×3, thẻ Step, đánh theo hình dạng tầm (refit)

> **Epic**: Kaiten Duel (v2)
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md` (v2)
**Requirement**: Brief MVP feature 1 — hai lưới 3×3 đối mặt, Step di chuyển, thẻ đánh/đỡ dùng bằng chạm với hình dạng tầm từ dữ liệu, recovery theo thẻ

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` v2 (Core loop + MVP feature 1), scoped to this story:*

- [ ] Sân là hai lưới 3×3 đối mặt (người chơi trái, boss phải), màn hình ngang 1280×720; người chơi và boss mỗi bên luôn đứng trên đúng một ô của lưới mình. Hình học lưới là hàm thuần trong `ScreenLayout`; 3 làn cũ bị thay thế.
- [ ] Thẻ *Step*: kéo từ ô tay thả lên **ô kề** (4 hướng) trong lưới của mình thì người chơi bước sang ô đó; thả lên ô không kề, ô đang đứng, lưới boss hay ngoài lưới thì thẻ quay về ô tay.
- [ ] Thẻ đánh/đỡ dùng bằng **chạm** (không cần kéo): hiệu ứng tính theo **hình dạng tầm** khai báo trong dữ liệu, tương đối với ô người chơi đứng (ít nhất 4 hình: ô trước mặt / cả hàng / cột liền kề quét 3 hàng / tự thân cho Guard). Trúng boss nếu ô boss nằm trong vùng.
- [ ] Khi chạm giữ một thẻ đánh, vùng tầm sáng lên trên lưới boss trước khi thả tay; thả tay ra là dùng.
- [ ] Recovery theo thẻ như Story 003 giữ nguyên; dữ liệu thẻ mở rộng với trường hình dạng và tầm, ghi trong `schema.md`.
- [ ] Boss tạm thời đứng yên (không đánh) ở ô giữa lưới của nó để kiểm tra; logic đánh theo giờ cũ (`EnemyLogic` theo mẫu) bị gỡ hoặc tắt, không còn chạy.
- [ ] Ảnh chụp màn hình: lưới hai bên với người chơi/boss, một lần Step, một lần vùng tầm sáng lên, được giữ lại trong `production/qa/evidence/`.

---

## Implementation Notes

- Làm lại trên nền có sẵn: `CombatState` (HP/giáp), `RecoveryLock`, `CardPlayer`, `CardDragController`, `HoldSlotsView`. Thay `player_lane`/`ENEMY_LANE` bằng tọa độ ô (`Vector2i`) cho cả hai bên; `enemy_cell` phải thay đổi được (Story 008 cần).
- Hình dạng tầm là dữ liệu (danh sách offset ô tương đối hoặc tên mẫu + tham số), không viết mã riêng từng thẻ.
- Chạm-để-dùng và kéo-để-bước dùng chung cơ chế input của Story 002; phân biệt theo loại thẻ từ dữ liệu.
- Giữ hook `--demo=` hoạt động; thêm demo cho lưới/Step/vùng tầm.
- Kiểm tra API Godot 4.6 trong `docs/engine-reference/godot/` (HIGH risk).

---

## Out of Scope

- Story 007: quầy sushi chung (băng chuyền cũ vẫn cấp thẻ tạm thời trong story này).
- Story 008: boss chơi thẻ, khoảng vung, vùng tầm của boss.
- Story 009: Parry/Counter/Posture.
- Story 010: bộ thẻ đầy đủ (ở đây chỉ cần Step, Guard, Strike, một thẻ cả hàng, một thẻ quét cột).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Retained screenshot trong `production/qa/evidence/grid-step-shaped-attacks/`.
- Logic: `tests/unit/combat/attack_shape_test.gd` — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003, Story 005 (code nền; cả hai Complete)
- Unlocks: Story 007, Story 008
