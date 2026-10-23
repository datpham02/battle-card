# Story 021: Tuyệt kỹ nhân vật — thanh nạp, nút riêng, ba tuyệt kỹ khuếch đại bộ bài

> **Epic**: Kaiten Duel (v4)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-24

## Context

**GDD**: `design/game-brief.md` (v4, mục "Nhân vật")
**Requirement**: Người dùng chốt: **không có lớp**; thay vào đó mỗi nhân vật có một **tuyệt kỹ chủ động riêng**, và tuyệt kỹ **mạnh lên theo bộ bài** chứ không tự mạnh. Nhân vật nào cũng chơi được mọi bộ, nhưng tuyệt kỹ làm một hướng build sáng rõ hơn. Đây là thứ lái người chơi thay cho trọng số thưởng theo lớp đã bỏ ở Story 020.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Thanh nạp và nút**

- [ ] `characters.json`: mỗi nhân vật thêm `signature: {id, charge_cells, params}`. Thanh nạp tăng theo **số ô người chơi đã Thi triển** trong trận (`charge_cells`, khởi điểm 18); đầy → nút sáng; bấm → kích hoạt, thanh về 0. Nạp **không** mang qua trận. Boss không có tuyệt kỹ.
- [ ] Nút tuyệt kỹ (≥ 64 px) cạnh nút Tập trung, vẽ bằng `UiButtons`, mờ khi chưa đầy; phím tắt bàn phím (`combat.json → keys`). Không bấm được khi tạm dừng, trong menu phép, hoặc khi Tập trung đang khóa d-pad (dùng cùng khóa `input_locked`).
- [ ] `BaseSignature` (RefCounted) hooks như passive: `setup(ctx, params)`, `activate()`, `tick(dt)`, `modify_damage(card, cells, dmg)`, `on_cast(card, cells)`, `is_active()`, `teardown()`; `SignatureRegistry` id → script; host trong `CombatView` cạnh `PassiveHost`. Id lạ → cảnh báo, không tuyệt kỹ, nút ẩn.

**Phần B — Ba tuyệt kỹ (số trong `characters.json`)**

- [ ] **Kiếm sĩ — Trảm**: trong `duration_sec` (3 s) mọi lá tính số ô ×`cell_mult` (2) và hồi máu `lifesteal` (20 %) sát thương gây ra. Khuếch đại lá `damage_per_cell` cao.
- [ ] **Pháp sư — Thiên Hỏa**: kích nổ toàn bộ cháy trên sân địch: gây ngay `detonate_mult` (2) × tổng sát thương cháy còn lại, xóa cháy, đặt lại cooldown mọi lá đốt. Không có cháy → chỉ xóa cooldown lá đốt (yếu rõ, đúng ý đồ).
- [ ] **Sát thủ — Ảnh Bộ**: trong `duration_sec` (2 s) bước không cooldown; địch đang bị ghim ăn ×`pinned_small_mult` (2) từ lá ≤ `small_cells` (3) ô. Cộng dồn với Quick Blade.
- [ ] Hiệu ứng nhìn thấy khi kích hoạt: viền sân người chơi đổi màu trong thời gian hiệu lực, tên tuyệt kỹ hiện 0,8 s giữa sân (chữ, không VFX mới).

**Phần C — Kiểm chứng**

- [ ] Mô phỏng seeded (mở rộng script của 020): chính sách "theo tuyệt kỹ" (Kiếm sĩ ưu tiên nâng lá sát thương, Pháp sư ưu tiên lá đốt, Sát thủ ưu tiên ghim + lá nhỏ) **thắng tầng 3 hơn "luôn bỏ qua" ≥ 25 điểm phần trăm** và hơn "ngẫu nhiên" rõ; ba nhân vật cùng seed ra bộ cuối khác nhau quá nửa. Bảng số vào Completion Notes.
- [ ] Test: nạp đúng theo ô, đầy ở 18, về 0 khi kích hoạt, không mang qua trận; Trảm nhân ô và hồi máu kẹp max; Thiên Hỏa tính đúng tổng cháy còn lại và xóa cooldown lá đốt; Ảnh Bộ bỏ cooldown bước và nhân đúng điều kiện; không bấm được khi tạm dừng/menu/Tập trung.
- [ ] Ảnh trong `production/qa/evidence/signature-skills/`: HUD với thanh nạp nửa và đầy; Trảm đang hiệu lực; Thiên Hỏa nổ (số sát thương lớn); Ảnh Bộ; màn chọn nhân vật hiện tên và một dòng tuyệt kỹ.
- [ ] Không hằng số gameplay trong mã; chuỗi mới là khóa `TEXT_*` với vi và en.

---

## Implementation Notes

- Dùng lại khung của passive (Story 018): một host, một registry, hook gọi từ đúng một điểm trong `CutActor`/`SwingArbiter`/`StatusController`. Tuyệt kỹ và nội tại cùng tồn tại; thứ tự áp: nội tại trước, tuyệt kỹ sau (ghi rõ).
- Thanh nạp thuộc `CombatState` để test thuần; HUD chỉ vẽ.
- `--demo=signature_ready` và `--signature=<id>` cho chụp ảnh.

---

## Out of Scope

- Tuyệt kỹ cho boss, tuyệt kỹ thứ hai, nâng cấp tuyệt kỹ, VFX/âm thật, nhân vật 4–5.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Bảng mô phỏng trong Completion Notes.
- Retained screenshots trong `production/qa/evidence/signature-skills/`.

**Status**: Screenshots retained (signature-skills/01-07) + simulation table (signature-skills/simulation-70seeds.md).

---

## Dependencies

- Depends on: Story 020 (damage_per_cell, cấp lá, Ghim/Đốt chồng), Story 018 (PassiveHost, UiButtons)
- Unlocks: cổng chơi thử 6, nội dung chương 2–3

---

## Completion Notes
**Completed**: 2026-10-24
**Criteria**: 10/11 pass, 1 not met (closed by user decision with tech debt TD-004/TD-005). DEFERRED (needs real play): timing feel of pressing the signature, banner clarity, button position on a real device.
**Deviations**: BLOCKING (accepted, logged TD-004): Phase C simulation target of 25 pp not reached; signature policy vs always-skip is kiem_si +2.9, phap_su +2.9, sat_thu +17.1 (70 seeds x 3 characters x 4 policies, dt 0.05, run in two parts because of the 10-minute foreground cap); deck-difference condition passes (0.657). Signatures fire 3-8 times per run but give under 5 % of damage because the bot casts 1-2 cells against dodging bosses; Tram alone lifts kiem_si by 6-9 pp versus the Story 020 baseline; JSON deliberately not tuned. ADVISORY: signature hotkey is data-driven (`combat.json signature_key`, default Q) through `CombatConfig.signature_key` and the new `CombatView.get_config()`. ADVISORY: `name_key`/`desc_key` live inside the `signature` block; extra hook `BaseSignature.on_hit` for Tram's lifesteal; instant signatures emit activated then ended immediately; a signature can be re-earned and re-fired within a match. ADVISORY: Thien Hoa and Anh Bo descriptions shortened to fit two lines on the character cards. ADVISORY: `--signature=<id>` and `--demo=signature_ready|signature_half` dev args; `CombatView.debug_set_signature_charge` is dev-only. ADVISORY (balance, TD-005): upgrading owned cards beats picking new damage cards by 14 pp; Anh Bo may need its x2 without the pinned-boss condition; Thien Hoa needs a burn deck.
**Test Evidence**: Integration; tests waived at `qa.level: minimal`. Retained screenshots `production/qa/evidence/signature-skills/01-07*.png` (all opened and checked) and the simulation table `simulation-70seeds.md` plus raw output. Scratch suites 0 fails: signature_test (98), deck_power, keyword, deck, cut, status, i18n, character, chapters, reward_run, run_flow2, pause_flow, arbiter, run/trait/arena flow (headless); cut_flow and focus_flow (windowed, `--no-autopause`). Parse-check 74/74.
**Code Review**: Skipped (solo mode).
**Not verified**: real feel, balance with a human player, touch on a device.
**Carries forward**: content story for chapters 2-3 (informed by design/reference/osfe-reference.md), then the playtest gate; TD-001..005.
