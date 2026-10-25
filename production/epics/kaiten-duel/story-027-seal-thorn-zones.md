# Story 027: Kết giới và Trận gai — vùng chặn và vùng thu phí đặt bằng mảnh, cho cả người chơi và boss

> **Epic**: Kaiten Duel (v5)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

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

**Status**: Created — production/qa/evidence/seal-thorn-zones/ (01-08 screenshots, simulation-zones.md + raw)

---

## Dependencies

- Depends on: Story 024 (mảnh), Story 025 (boss dùng mảnh), Story 026 (bot mảnh và cân bằng nền)
- Unlocks: cửa hàng/pact, Android

---

## Completion Notes
**Completed**: 2026-10-25
**Criteria**: 13/13 pass, 0 failing. DEFERRED (needs real play): how seals and thorns feel and read on a phone, whether the 2 s seal window of the player's cards is right for a human, the thorn entry flash (not visible in a still), the real dodge rate that every simulated number depends on (TD-006). Not observed on screen: the card Lồng ấn in a reward offer (its strings and data exist). Tests not mutation-checked: the new suites passed on their first run.
**What changed**: `StatusEffects` holds the zones (`apply_seal`, `apply_thorns`, `is_sealed(side, cell)`, `thorns_at(side, cell)`, `sealed_cells`, `thorn_cells`, remaining-time getters, signals `zone_applied` / `zone_expired` / `thorn_entered`); `ZoneRules.fit_cells` / `cast_seal` / `cast_thorns` (the leave-a-path rule: a seal that would close every open neighbour drops exactly one cell); `CutEffects` dispatches `seal` / `thorns` at swing arrival, hit or miss (one code point); `UnitMover.add_blocker` ORs seals with cracks, wired for both movers in `CombatView._wire_zones`; numbers in `combat.json` `zones` (seal 1.2 s, thorn 3.0 s, 6 damage, 1 Ran) read by `CombatConfig`; 4 cards (`ket_gioi`, `long_an`, `tran_gai`, `gai_nguyen`); boss brain treats seals as blocked, thorn cost `thorn_avoid` x thorn damage (new weight: balanced 1.0, aggressive 0.5, cautious 1.5), dodge trade-off recorded in `last_debug().dodge_plan`; traits `seal_caster` (jailer, ch2 miniboss) and `thorn_field` (frost_mage, ch3 miniboss); HUD draws seal (violet block, glowing border) and thorns (inward sawtooth) with a time bar; reward cards show "Kết giới" / "Trận gai" + "Rạn +N"; 4 new demos plus `trait_seal`, `trait_thorns`, `reward_zone_cards`; `tools/balance` flags `--no-zone-cards`, `--card-set`.
**Simulation** (70 seeds, build policy, bot rule: seal when the boss has at most 3 open exits, thorns on 2+ open exits, follow-up cast at once). Win % before (no zone cards) -> after with seal 1.2 s -> 2.0 s (shipped) for Kiếm sĩ / Pháp sư / Sát thủ: ch2 44.3 / 15.7 / 41.4 -> 50.0 / 14.3 / 21.4 -> 50.0 / 18.6 / 34.3; ch3 24.3 / 15.7 / 12.9 -> 21.4 / 8.6 / 12.9 -> 15.7 / 11.4 / 12.9. Largest rise +8.6 (ch2 Kiếm sĩ at 2.5 s), so the "weaken if +15 points" rule did not fire. Hit rate of non-zone casts within 2 s after a seal against other casts: with a 1.2 s seal 30.7-41.9 % against 37-46 % (worse than ordinary); with 2.0 s 35.5-46.5 % against 37-46 % (level or better) — the reason the two player seal cards carry `seal_sec: 2.0`. Zone cards picked about 0.6-1.2 per run, 1.05-1.48 zone casts per match; the boss steps into thorns only 0.07-0.13 times per match. Full tables: `production/qa/evidence/seal-thorn-zones/simulation-zones.md` and `-raw.txt`.
**Deviations**: ADVISORY (TD-026): zones are drawn ABOVE units and field pieces, not below, because `CutHudView` sits above `CombatView` and the drops views; a sealed cell holding a unit or piece is drawn see-through (alpha 0.45) so it stays visible. ADVISORY: the two player seal cards use `seal_sec: 2.0` (per card) while the `combat.json` default stays 1.2 s (boss seals on the player keep the short window); the story named 1.2 s as a starting value. ADVISORY (TD-026): card descriptions write 2 s / 3 s / 6 HP into the text, like the older cards, so they go stale if `combat.json` is tuned. ADVISORY (TD-026): `seal_caster` and `thorn_field` keep `DEFAULT_*` fallback constants in code (real values come from `chapters.json`; same pattern as older traits). ADVISORY (TD-026): the brain's thorn cost counts damage only, not the Ran a thorn applies; the traits' "escape cells" are a fixed `escape_steps` reach of 2, not the player's real step cooldown; the traits load `combat.json` themselves because the trait context carries no `CombatConfig`. ADVISORY: the ch2 Sát thủ cell at seal 1.2 s dropped 20 points (about 2.4 times the noise); a re-run on a fresh seed set was planned but not run; at 2.0 s the drop is about 7 points, inside the noise. ADVISORY: behaviour outside the story: a zone card whose target stands inside the zone ("hit") interrupts the opponent's running swing, like the Đốt cards. ADVISORY: the card Lồng ấn does not appear in the reward-offer screenshots (07, 08 show Kết giới, Trận gai, Gai nguyền). Scope: touched beyond the story text: `skill_config.gd` (per-card zone numbers, boss card list without zone cards via `boss_card_order()`), `reward_view.gd`, `unit_mover.gd`, `tests/unit/combat/deck_power_test.gd`, `tests/unit/traits/trait_test.gd`, `tests/unit/run/chapters23_test.gd` (one line each: card count, known trait ids), `tools/balance/*`.
**Test Evidence**: Integration; tests waived at `qa.level: minimal` but present and run on the final code: new suites `tests/unit/combat/zone_test.gd`, `tests/unit/combat/boss_zones_test.gd`, `tests/unit/traits/zone_traits_test.gd`; parse-check 145/145; 47 headless and 4 windowed suites all FAILS=0; `main.tscn` launched windowed with `--quit-after 300`, 0 error lines. Retained screenshots `production/qa/evidence/seal-thorn-zones/01-08*.png` (all opened and checked) plus `simulation-zones.md` and `simulation-zones-raw.txt`.
**Code Review**: Skipped (solo mode).
**Not verified**: feel on a phone, balance against a human, the `aggressive` brain set (forest_witch) with zones, Lồng ấn on screen.
**Carries forward**: gate 7 playtest (touch feel, join, featured bonus, formation map, cooldowns, signatures, counter window, zones, anchor the bot dodge); TD-001..006, 008..016, 018, 020, 021, 023..026.
