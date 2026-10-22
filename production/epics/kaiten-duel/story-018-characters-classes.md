# Story 018: Nhân vật theo lớp — chỉ số, nội tại, bộ khởi đầu, màn chọn nhân vật

> **Epic**: Kaiten Duel (v4)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-22

## Context

**GDD**: `design/game-brief.md` (v4, mục "Nhân vật theo lớp")
**Requirement**: Người dùng muốn 3–5 nhân vật theo lớp, mỗi lớp có bộ bài khởi đầu riêng. Story này thêm dữ liệu nhân vật, nội tại cắm được, màn chọn nhân vật, và đưa chỉ số + bộ khởi đầu vào trận. Ba lớp đầu; lớp 4–5 chỉ là thêm JSON.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

- [ ] `assets/data/characters.json`: `{ "characters": [ {id, display_name, description, max_hp, step_cooldown_mult, focus_max_sec, passive: {id, params}, starter_deck: [card ids], unlocked: bool} ] }`. Ba nhân vật: `kiem_si` (100 máu, ×1,0, 4 s, nội tại `second_wind`: hồi thêm 10 máu sau mỗi trận thắng; bộ 2 kiem_khi 2 chan_phong 1 hoa_tran 1 bang_phong), `phap_su` (80, ×1,0, 5 s, `wide_caster`: trận pháp ≥ 5 ô niệm nhanh hơn 15 %; bộ 1 kiem_khi 1 chan_phong 3 hoa_tran 1 bang_phong), `sat_thu` (90, ×0,9, 4 s, `quick_blade`: phép ≤ 3 ô sát thương +25 %; bộ 3 kiem_khi 1 chan_phong 2 bang_phong). Cả ba `unlocked: true` lúc này. `schema.md` có mục.
- [ ] `CharacterConfig` (RefCounted): nạp, kiểm (id trùng, lá lạ trong bộ → cảnh báo và bỏ lá đó, bộ rỗng → `default_deck`), `get(id)`, `ids()`, `unlocked_ids()`.
- [ ] **Nội tại cắm được**: `BasePassive` (hooks: `setup(ctx, params)`, `on_match_start()`, `on_match_won()`, `modify_swing_duration(cells, duration) -> float`, `modify_damage(cells, damage) -> float`, `teardown()`), `PassiveRegistry` id → script, host trong `CombatView` như `TraitHost`. Ba nội tại mẫu ở trên. `CutActor`/`CutEffects` gọi `modify_*` qua một điểm duy nhất (không rải). Id lạ → cảnh báo, không nội tại.
- [ ] Chỉ số vào trận: `match_params["character"]` = {max_hp, step_cooldown_mult, focus_max_sec, passive, deck}; `CombatState.player_max_hp`, cooldown bước người chơi (nhân vào giá trị theo sân), `FocusController` max, `Deck` từ bộ khởi đầu (019 thay bằng bộ của run). `RunController`/`GameFlow` truyền qua; không có nhân vật → mặc định hiện nay (để test và demo cũ chạy).
- [ ] **Màn chọn nhân vật** (`CharacterSelectView`): sau title, trước chọn chương. Thẻ cho mỗi nhân vật: tên, máu, mô tả ngắn, nội tại, **bộ khởi đầu** liệt kê theo số bản ("Kiếm khí ×2 …"); nhân vật khóa hiện xám. Chọn → sang chọn chương với nhân vật đã chọn (hiện tên nhân vật ở góc). Nút Về → title. Nút back theo pha. Dev arg `--character=<id>`.
- [ ] HUD trận hiện tên nhân vật thay "YOU" (chuỗi từ dữ liệu).
- [ ] Test: config nạp 3 nhân vật, lá lạ bị bỏ; `wide_caster` giảm thời gian niệm đúng 15 % với 5 ô và không đổi với 4 ô; `quick_blade` +25 % với 3 ô, không với 4; `second_wind` cộng máu sau thắng, kẹp max; chọn `phap_su` → trận có 80 máu, Tập trung 5 s, bộ 6 lá đúng danh sách; không nhân vật → giá trị cũ.
- [ ] Ảnh trong `production/qa/evidence/characters/`: màn chọn nhân vật; HUD với tên nhân vật và máu 80 của Pháp sư; menu phép rút từ bộ Pháp sư (nhiều Hỏa trận).
- [ ] Không hằng số gameplay trong mã; mọi chuỗi hiển thị là khóa `TEXT_*` qua `tr()` với dòng vi và en trong `assets/i18n/strings.csv`; JSON chỉ có `name_key`/`desc_key`.

---

## Implementation Notes

- `GameFlow` thêm pha CHARACTER_SELECT giữa TITLE và FLOOR_SELECT (019 đổi FLOOR_SELECT thành chọn chương); `go_back` cập nhật.
- Nội tại và trait dùng cùng kiểu (RefCounted, hooks, registry) để sau này một lá/một boss có thể cắm cả hai.
- Giữ `--demo=*`, `--run=*`, `--floor=*` chạy với nhân vật mặc định (`kiem_si`) khi không có `--character`.

---

## Out of Scope

- Mở khóa nhân vật (điều kiện, màn mở khóa): `unlocked` chỉ là cờ dữ liệu.
- Nhân vật 4–5, nội tại phức tạp (theo trạng thái, theo lá).
- Thưởng lá, run (019).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/characters/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 017 (cards.json, Deck), Story 016 (GameFlow pha, UiButtons)
- Unlocks: Story 019
