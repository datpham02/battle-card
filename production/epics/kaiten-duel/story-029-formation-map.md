# Story 029: Trận đồ — ô sáng khi được phủ, phai dần, sáng đủ cùng lúc thì tuyệt kỹ sẵn sàng

> **Epic**: Kaiten Duel (v5)
> **Status**: Complete
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

**Phần D — Thời gian hồi tuyệt kỹ (bổ sung 2026-10-25, người dùng chốt)**

- [ ] Mỗi lần dùng tuyệt kỹ đều cần **một trận đồ mới sáng đủ**: kích hoạt tuyệt kỹ **xóa trận đồ** về 0 (không xóa lúc hoàn thành nữa) và bắt đầu **thời gian hồi**.
- [ ] Thời gian hồi **riêng từng nhân vật**: khóa `cooldown_sec` trong khối `signature` của `characters.json` (có trong `schema.md`, kẹp ≥ 0). Tuyệt kỹ có hiệu lực theo thời gian (Trảm, Ảnh Bộ) bắt đầu hồi **khi hiệu lực kết thúc**; tuyệt kỹ tức thì (Thiên Hỏa) hồi ngay.
- [ ] **Hồi và tích chạy song song**: trong lúc hồi ô vẫn sáng và vẫn tính. Tuyệt kỹ **sẵn sàng khi đã hết hồi VÀ trận đồ đang sáng đủ** — kiểm cả lúc đòn phủ ô lẫn đúng lúc hết hồi; hết hồi mà chưa đủ thì sẵn sàng ngay khi đủ. Đã sẵn sàng thì giữ tới khi dùng (ô phai không làm mất trạng thái sẵn sàng).
- [ ] Nút tuyệt kỹ: trong lúc hồi hiện "Hồi N s" (khóa `TEXT_*` vi/en, làm tròn lên giây); hết hồi mà trận đồ chưa đủ hiện "Trận đồ N/M"; sẵn sàng như cũ.
- [ ] Số khởi điểm do bot đo: **giá trị trung bình mỗi lần dùng** (sát thương thêm + máu hồi do tuyệt kỹ) của từng nhân vật, rồi đặt `cooldown_sec` sao cho giá trị mỗi phút của ba nhân vật gần nhau theo tỉ lệ (không cần bằng nhau; Trảm mạnh nhất hồi lâu nhất, Ảnh Bộ ngắn nhất) và tuyệt kỹ dùng tối đa khoảng 3 lần mỗi trận kể cả khi rải đòn giỏi. Bảng vào `production/qa/evidence/formation-map/signature-cooldown.md`.
- [ ] Test: dùng tuyệt kỹ xóa trận đồ và bắt đầu hồi; hồi của tuyệt kỹ có thời gian bắt đầu sau khi hiệu lực hết; trận đồ đủ trong lúc hồi thì sẵn sàng đúng lúc hết hồi; hết hồi mà chưa đủ thì sẵn sàng khi đủ; ô phai sau khi đã sẵn sàng không làm mất sẵn sàng; không mang qua trận. Ảnh: nút "Hồi N s" (vi và en).

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

**Status**: Screenshots retained (formation-map/01-08, 9 PNG) + bot tables (formation-timing.md, signature-cooldown.md) + suites (formation_map_test, signature_test).

---

## Dependencies

- Depends on: Story 024 (mảnh), Story 028 (đòn 2 mảnh phủ hợp ô), Story 021 (tuyệt kỹ, nút, banner)
- Unlocks: Story 025 (não boss viết theo luật cuối), Story 026 (đo lại cân bằng)

---

## Completion Notes
**Completed**: 2026-10-25
**Criteria**: 18/19 pass or deferred, 1 not met (closed by user decision, carried to Story 030 and TD-019). NOT MET: Phần D — the value per minute of the three signatures is not comparable: measured 6-8 : 1.5 : 1 (Tram : Thien Hoa : Anh Bo) at every cooldown, because a cooldown only removes uses; Thien Hoa needs fire that is mostly absent (85-90 % of its uses fire with little burn) and Anh Bo needs a pinned boss in a 2 s window. DEFERRED (needs real play): the 3.5 Hz blink of cells about to fade (a still shows only the dashed border), readability of the lit cells on a phone, whether a 12 s fade on 3x3 and cooldowns 25 / 15 / 12 s feel right.
**Deviations**: ADVISORY (superseded by user decisions 2026-10-25): fade is 5.0 s + 0.8 s per cell (3x3 12.2 s, 4x3 14.6 s, 21-cell ring 21.8 s, 6x6 33.8 s) instead of the 4.0 / 0.6 listed in Phần A, chosen from the bot measurement; the map is cleared when the signature is ACTIVATED (Phần D), not when it completes (Phần A item 4); completing while the signature is ready or running only lights cells. ADVISORY (accepted): the 1-3 readies per match target of Phần C holds only for a player who spreads casts (about half the casts over dark cells: 2.0-2.9 per match on all four boards with 5.0/0.8); strike-only play reaches the full map 0-0.02 times per match (TD-018). ADVISORY: bot caveats — one piece per cast, no joins, P (share of casts spent on the map) is a stand-in for player behaviour not a measurement, and the live Story 025 root-while-swinging lock (TD-017) is in every measurement. ADVISORY: `CharacterConfig._read_signature` (not in the story's file list) no longer reads `charge_cells`, a leftover key is ignored; `SignatureCharge`, `charge_cells` and `signature_charge_cells` are gone; `ui.hud.signature_charge` replaced by `ui.hud.formation_count`, `formation_complete`, `signature_cooldown`. ADVISORY: HUD blink/alpha constants (`FORMATION_*`) are visual constants local to `cut_hud_view.gd`; the warn ratio, fade and flash length come from `combat.json`. Tram cooldown 25 s (placeholder was 20), Thien Hoa 15 s, Anh Bo 12 s from `signature-cooldown.md`; with those on a 3x3 board Tram fires about 1.3 times per match, Thien Hoa 1.6, Anh Bo about 1.3.
**Test Evidence**: Integration; tests waived at `qa.level: minimal` but present and run on the final code: `tests/unit/combat/formation_map_test.gd` (58 checks plus 19 cooldown checks), `signature_test.gd` rewritten for the new rules, `character_test`, `i18n_test`; headless sweep of 41 suites: 39 green, `pace_test` FAILS=2 and `run_state_test` FAILS=16 are the known TD-011; windowed `join_flow_test`, `cut_flow_test`, `focus_flow_test`, `input_test` all FAILS=0. Parse-check 9/9. strings.csv 323 rows, 3 columns each. Retained screenshots `production/qa/evidence/formation-map/01-08*.png` (all opened and checked). Bot results, chapter 1, kiem_si, readies per match (old 18-cell charge / new map 4.0-0.6 with strike-only play / new map 5.0-0.8 with half the casts on the map): square 0.82 / 0.02 / 2.93, rect 0.97 / 0.00 / 2.42, cross 1.50 / 0.00 / 2.00, ring 2.09 / 0.00 / 2.11; first ready about 14 s (square), 25 s (rect), 24 s (cross), 33 s (ring). Value per use / per minute at cooldown 25 s: Tram about 11.6 / 23 on square, Thien Hoa 1.7 / 3.2 on square (7.0 / 9.3 on cross), Anh Bo 1.1 / 2.3.
**Code Review**: Skipped (solo mode).
**Not verified**: the blink and the formation read on a phone, real-play readies per match, how often a human completes the map, Thien Hoa and Anh Bo with patient human activation (the bot fires them on simple rules).
**Carries forward**: Story 030 (rework Thien Hoa and Anh Bo, rebalance value per minute), Story 025 (boss uses and joins pieces; verify TD-017 live edits), Story 026, Story 027; TD-001..002, 004..019.
