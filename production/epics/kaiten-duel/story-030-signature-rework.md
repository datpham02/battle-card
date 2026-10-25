# Story 030: Làm lại Thiên Hỏa và Ảnh Bộ — gắn với trận đồ, bỏ điều kiện khó đạt, cân bằng giá trị mỗi phút

> **Epic**: Kaiten Duel (v5)
> **Status**: Complete
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

> **Đổi thứ tự 2026-10-25 (người dùng chốt sau khi bot đo):** đốt rồi nổ ngay khiến mỗi ô trận đồ gây ~12 sát thương (sân 3×3: 108, 4×3: 144 — hạ gọn boss một lần dùng, giá trị mỗi phút gấp ~10 lần Trảm). Bộ số chỉ-dữ-liệu của bot đưa lửa trận đồ về gần 0, làm phần "đốt cả trận đồ" vô nghĩa. Luật mới: **kích nổ lửa đang có TRƯỚC, rồi đốt mọi ô trận đồ đang sáng thành biển lửa kéo dài** (`burn_duration_sec`): gây sát thương theo thời gian khi boss đứng trong lửa và chặn đường boss (não boss né ô cháy qua `burn_avoid`). Hai mục dưới được hiểu theo thứ tự này.

- [ ] Khi kích hoạt, Thiên Hỏa **kích nổ toàn bộ cháy đang có** trên đất địch như hiện nay (`detonate_mult`), đặt lại cooldown lá đốt, **rồi đốt mọi ô thật của đất địch đang sáng trong trận đồ** (lúc kích hoạt trận đồ vừa đủ nên thường là cả sân) với `burn_stacks` tầng Đốt, kéo dài `burn_duration_sec` (params trong `characters.json`). Lửa mới **không** bị kích nổ trong cùng lần dùng. Thứ tự nổ → đốt ghi rõ trong mã; số trong dữ liệu.
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

**Status**: Screenshots retained (signature-rework/01-04, 5 PNG) + balance table (signature-rework/signature-balance.md) + suites (signature_test rewritten, character_test, i18n_test).

---

## Dependencies

- Depends on: Story 029 (trận đồ, thời gian hồi), Story 021 (tuyệt kỹ)
- Unlocks: cân bằng nhân vật (TD-008), Story 026 (đo lại ba chương)

---

## Completion Notes
**Completed**: 2026-10-25
**Criteria**: 9/9 pass, 1 only partly (Phần C screenshots: no detonation number is shown because the HUD never drew one). DEFERRED (needs real play): whether the 3 s sea of fire really blocks the boss (the bot saw only 0-2 boss hits per 30 matches inside fire windows, not significant), and Thien Hoa played by a patient human instead of the bot rules.
**Deviations**: ADVISORY (user decision 2026-10-25): Thien Hoa order is detonate existing burn (x2) -> reset burn cards -> ignite every lit formation cell, not ignite-then-detonate; ignite-then-detonate measured 129.7 value/min against Tram 13.2 (a full 3x3 board detonated for 108, 4x3 for 144, one use killed the boss) and the data-only fix that kept ignite-then-detonate made the formation fire worth ~0. The new fire is not detonated in the same use. ADVISORY: data changes — `phap_su` signature `burn_duration_sec` 2.0 -> 3.0, `burn_damage_per_tick` 1.5 -> 0.5 (cooldown 15, `burn_stacks` 1, `burn_tick_sec` 0.5, `detonate_mult` 2.0 unchanged); `sat_thu` `small_mult` 2.0 -> 1.75 (the story placeholder was 2.0); `kiem_si` unchanged. ADVISORY: the 2 : 1 target holds on the four-board average only (1.99 : 1 at P=0.5, 1.2 : 1 at P=0.25) with order Tram > Thien Hoa > Anh Bo; per board Thien Hoa is weak on 3x3 (6.9/min against Tram 23.4) and strong on 4x3 and cross (16.8, 16.6), margins 12.7 vs 13.2 and 6.5 vs 6.4 are inside the noise of 30 matches per cell, and Tram : Anh Bo is already exactly 2.0 because Anh Bo went to x1.75 (TD-020). ADVISORY: bot caveats — fires on the Story 021 rules (Thien Hoa held up to 6 s), one piece per cast, no joins, TD-017 boss lock live; Anh Bo free steps (dodging value) not counted. ADVISORY (TD-021): no HUD number for the detonation damage; Mage card description is clipped on the Vietnamese card ("...tap trung duoc" for "...tap trung duoc lau", older than this story). ADVISORY: demo `thien_hoa_ignited` retired (it called a private method and showed a state the game cannot reach); added `thien_hoa_fire`, `thien_hoa_burning` (fire 1 s later) and `anh_bo_hit`, which lift `freeze_time` for the single activation call (dev only); `schema.md` rewritten for the new rules (not in the story's file list). The Anh Bo screenshot was recaptured after the x1.75 change (-26 = 15 x 1.75; the first capture showed x2).
**Test Evidence**: Integration; tests waived at `qa.level: minimal` but present and run on the final code: `tests/unit/combat/signature_test.gd` (Thien Hoa through CombatView and with a real FormationMap + StatusEffects: detonation counts only pre-existing burn, lit cells burn afterwards with the configured duration/tick/damage, no formation or no lit cells gives the old behaviour, burn cards reset; Anh Bo small casts x small_mult unpinned, no multiplier for larger casts or after expiry, free steps, legacy `pinned_small_mult` read with a warning, `small_mult` wins when both exist), `character_test`, `i18n_test`; headless sweep of 41 suites: 39 green, `pace_test` FAILS=2 and `run_state_test` FAILS=16 are the known TD-011; windowed `join_flow_test`, `cut_flow_test`, `focus_flow_test`, `input_test` FAILS=0. Parse-check 5/5. strings.csv 323 rows, 3 columns each. Retained screenshots `production/qa/evidence/signature-rework/01-04*.png` (all opened and checked) and `signature-balance.md` plus `-raw.txt`. Bot results, value per minute, four-board mean, P=0.5 / P=0.25: Tram 13.2 / 7.7, Thien Hoa 12.7 / 6.5, Anh Bo 6.6 / 6.4; uses per match on the 3x3 board at P=0.5: Tram 1.30, Thien Hoa 1.43, Anh Bo 1.57.
**Code Review**: Skipped (solo mode).
**Not verified**: the sea of fire against a boss that is avoiding burning cells, human-timed activation, balance on bigger boards in real play.
**Carries forward**: Story 025 (boss uses and joins pieces, aims at the featured shape, counter window; verify the live TD-017 edits first), Story 026, Story 027; TD-001..002, 004..021.
