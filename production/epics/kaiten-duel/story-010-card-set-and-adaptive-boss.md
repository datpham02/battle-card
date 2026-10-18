# Story 010: Bộ 10–12 thẻ có hình dạng tầm + boss học bằng bộ đếm

> **Epic**: Kaiten Duel (v2)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md` (v2)
**Requirement**: Brief MVP features 5 và 6 — bộ 10–12 thẻ có hình dạng tầm; boss "học" bằng bộ đếm trong trận

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` v2 (MVP features 5–6), scoped to this story:*

- [ ] 10–12 loại thẻ định nghĩa hoàn toàn trong dữ liệu (hiệu ứng, hình dạng tầm, sát thương/giáp, recovery, khoảng vung khi boss dùng), đủ nhóm: di chuyển (Step, Dash), đánh (Strike ô trước mặt, Cannon cả hàng, Wide Slash quét cột, đòn nặng), đỡ (Guard), đúng lúc (Parry, Counter), và ít nhất một thẻ tiện ích (ví dụ *Chef's Knife* biến một đĩa sắp ôi thành thẻ tốt).
- [ ] *Dash*: lao tới cột gần boss nhất trong lưới mình và đánh; *Knockback*: đẩy boss lùi một ô nếu có chỗ. Mọi thay đổi vị trí đều là hiệu ứng thẻ; không có thẻ di chuyển "tự do".
- [ ] Boss dùng được mọi thẻ trong bộ với cùng dữ liệu.
- [ ] Boss "học" bằng bộ đếm cấu hình được: người chơi bước né sớm N lần liên tiếp → tỉ lệ **feint** (giơ thẻ rồi hủy) tăng; người chơi spam đánh → boss ưu tiên Guard; người chơi parry thành công nhiều → boss đổi sang thẻ khoảng vung ngắn hơn. Tất cả là số trong `boss_brain.json`.
- [ ] Feint hiển thị khác với đòn thật sau khi hủy (người chơi hiểu mình vừa bị lừa).
- [ ] Ảnh chụp màn hình từng thẻ mới đang được dùng và một lần feint, được giữ lại trong `production/qa/evidence/`.

---

## Implementation Notes

- Hiệu ứng là dữ liệu + tập hành động dựng sẵn (sát thương theo hình, giáp, di chuyển bản thân, đẩy đối thủ, biến đổi đĩa trên quầy), không mã riêng từng thẻ.
- Giá trị cân bằng là khởi điểm; chỉnh bằng chơi thử.
- Giữ `boss_brain.json` đọc được bằng mắt: mỗi quy tắc có tên và chú thích trong `schema.md`.

---

## Out of Scope

- Ghép thẻ (sau MVP). Meta progression. Nhiều boss khác nhau (Story 011 dùng bộ trọng số khác nhau cho từng trận, nhưng thẻ là chung).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Retained screenshot trong `production/qa/evidence/card-set-adaptive-boss/`.
- Logic: `tests/unit/cards/card_effects_test.gd` — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 009
- Unlocks: Story 011
