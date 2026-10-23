# Story 020: Bộ bài có sức nặng — sát thương theo lá, nâng cấp khi nhặt trùng, bỏ lá, từ khóa Ghim/Đốt, bỏ khái niệm lớp

> **Epic**: Kaiten Duel (v4)
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-24

## Context

**GDD**: `design/game-brief.md` (v4, mục "Lá bài và bộ bài", "Nhân vật", "Run")
**Requirement**: Người dùng muốn **việc chọn lá sau mỗi trận ảnh hưởng thật đến sức mạnh và kết quả**. Hiện sát thương là 6 × số ô cho mọi lá, bộ chỉ phình ra, không nâng cấp, không bỏ lá, không lá nào tương tác với lá nào, nên chọn gì cũng gần như nhau. Người dùng cũng chốt **bỏ khái niệm "lớp"**: nhân vật là một cá nhân với bộ khởi đầu, nội tại và (Story 021) tuyệt kỹ riêng; không lá nào gắn lớp, không nghiêng trọng số thưởng theo lớp. Đa dạng đến từ pool lá và từ khóa hiệp đồng dùng chung.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Lá là đường cong sức mạnh**

- [ ] `cards.json`: mỗi lá có `damage_per_cell` riêng thay cho `base_damage_per_cell` chung của `combat.json` (giữ khóa cũ làm fallback khi lá thiếu). Khởi điểm: lá khởi đầu 5–6, thưởng thường 7, hiếm 8–9, sử thi 10; lá đốt/ghim giữ 0 nhưng tham số hiệu ứng mạnh hơn theo độ hiếm. `damage_multiplier` bỏ hoặc gộp vào `damage_per_cell` (ghi rõ trong Completion Notes). Boss dùng `boss_cards` với cùng bảng.
- [ ] **Cấp lá**: bộ bài lưu `{id, level}` (level 1–3). `cards.json` có `upgrade` cho mỗi lá: mỗi cấp cộng `damage_per_cell` (+1), hoặc giảm `min_cells` (−1, không dưới 1), hoặc giảm `cooldown_sec` (−1 s), theo bảng của lá. Tên hiện "Kiếm khí +1" / "+2". `Deck.add(id)` khi đã có lá đó cấp < 3 → nâng cấp bản đầu tiên thay vì thêm bản; cấp 3 rồi thì thêm bản mới.
- [ ] **Bỏ khái niệm lớp**: xóa `class_tags` khỏi `cards.json`, `class_tag_bonus` khỏi `rewards.json`, `RewardRoller` không nhận thẻ nữa; chuỗi "lớp" trong CSV, màn chọn nhân vật và brief đổi thành "nhân vật". `schema.md` cập nhật.

**Phần B — Màn thưởng có quyết định thật**

- [ ] Màn thưởng đưa **3 lá + ô thứ tư "Bỏ 1 lá"** (`rewards.json → allow_remove: true`). Chọn ô này → danh sách bộ hiện tại (tên + cấp), chạm một lá để bỏ (bộ không được dưới `min_deck_size`, mặc định 4). Thẻ lá đã có trong bộ hiện nhãn "Nâng cấp → +N" thay vì tên trần; lá cấp 3 không được đề nghị nữa (trừ khi pool cạn).
- [ ] Nhãn HUD "Bộ: N lá" giữ nguyên; màn RUN KẾT THÚC / RUN THẮNG liệt kê bộ cuối (tên + cấp, một dòng, cắt bớt nếu quá dài).

**Phần C — Hai từ khóa hiệp đồng (dùng chung mọi nhân vật)**

- [ ] **Ghim**: địch đang bị ghim ăn `pinned_damage_mult` (×1.5, `combat.json`) từ lá sát thương (`effect: damage`, `push`). Hiển thị số sát thương màu khác khi được nhân.
- [ ] **Đốt**: lá đốt trúng địch **đang cháy** → kéo dài thời gian cháy thêm `burn_stack_extend_sec` (2 s) và tăng `burn_damage_per_tick` thêm `burn_stack_tick_bonus` (+1), tối đa `burn_max_stacks` (3). HUD boss hiện số tầng cháy (vd. "🔥×2" bằng chữ, không icon mới).
- [ ] Mô tả lá (CSV) nhắc từ khóa: "Ghim 1,2 s. Địch bị ghim ăn thêm 50 % từ đòn kiếm."

**Phần E — Pool đủ rộng để build (người dùng 2026-10-22: "còn quá ít, hoàn thiện rồi mới trải nghiệm")**

- [ ] `cards.json` có **≥ 20 lá** (hiện 8), chỉ dùng bốn hiệu ứng có sẵn (damage, push, burn, pin) với tham số khác nhau: nhiều lá sát thương theo số ô khác nhau (1–6 ô), lá đẩy 1–2 ô, lá đốt diện rộng/cháy lâu/cháy mạnh, lá ghim ngắn–dài, vài lá đánh đổi (ví dụ cần nhiều ô, cooldown dài, sát thương rất cao). Phân bố độ hiếm khoảng 10 thường / 7 hiếm / 3 sử thi. Mỗi lá có `name_key`/`desc_key`, bảng `upgrade`, dòng vi và en trong CSV. Mỗi từ khóa (Ghim, Đốt) có ít nhất 4 lá liên quan để build theo từ khóa khả thi.
- [ ] Bộ khởi đầu của ba nhân vật giữ nguyên số lá nhưng không dùng lá nào chỉ có ở pool thưởng. `card_order` và scratch test đếm lá cập nhật.

**Phần D — Kiểm chứng bằng số, không chỉ cảm giác**

- [ ] Script mô phỏng seeded (scratch hoặc `tests/`) chạy ≥ 200 run chương 1 cho mỗi chính sách chọn thưởng: **luôn bỏ qua**, **ngẫu nhiên**, **theo build** (ưu tiên nâng cấp lá có `damage_per_cell` cao nhất, rồi từ khóa đang có). Yêu cầu: tỉ lệ thắng tầng 3 của "theo build" cao hơn "luôn bỏ qua" **ít nhất 25 điểm phần trăm**, và máu còn lại trung bình cao hơn rõ. Không đạt → chỉnh JSON, không chỉnh mã; ghi bảng số vào Completion Notes.
- [ ] Ba nhân vật cùng chính sách "theo build" cùng seed → bộ cuối khác nhau **quá nửa số lá** (vì bộ khởi đầu khác, không vì trọng số).
- [ ] Test: nâng cấp đúng bảng và kẹp cấp 3; bỏ lá không xuống dưới `min_deck_size`; Ghim nhân đúng, không nhân khi hết ghim; Đốt chồng đúng tối đa 3 tầng; save/nạp giữ cấp lá; file save v2 cũ (deck là mảng id) nạp thành cấp 1.
- [ ] Ảnh trong `production/qa/evidence/deck-power/`: màn thưởng với thẻ "Nâng cấp" và ô "Bỏ 1 lá"; danh sách bỏ lá; HUD với địch bị ghim ăn đòn nhân; HUD với cháy ×2; RUN THẮNG liệt kê bộ cuối.
- [ ] Không hằng số gameplay trong mã; mọi chuỗi mới là khóa `TEXT_*` qua `tr()` với vi và en trong `assets/i18n/strings.csv`.

---

## Implementation Notes

- `Deck` đổi phần tử từ `String` thành `{id, level}` nhưng giữ API `to_array` trả về dạng cũ cho HUD; `from_array` chấp nhận cả mảng id (cấp 1) lẫn mảng dict. `RunSession.to_dict` v3 (chỉ đổi khóa `deck`), `ProgressState` giữ nạp v2.
- `CutEffects`/`SwingArbiter` đọc `damage_per_cell` của lá (đã áp cấp) qua một điểm: `CardConfig.resolved(id, level)` trả về dict đã cộng nâng cấp. Không rải phép cộng ở nhiều chỗ.
- Ghim và Đốt đã có trong `StatusController` (Story 010); phần mới là hệ số và chồng tầng, cùng chỗ.
- Bỏ lớp: xóa field là đủ, `RewardRoller.roll` bỏ tham số `character_tags` (giữ chữ ký ít thay đổi nhất, ghi rõ).

---

## Out of Scope

- Tuyệt kỹ nhân vật (021), chương 2–3 (story riêng sau 021). Kháng/yếu theo kẻ địch, lá mới có hiệu ứng mới, cửa hàng, xem bộ giữa trận (ngoài danh sách bỏ lá).
- Nhân vật 4–5, lá có hiệu ứng mới (chỉ lá dùng bốn hiệu ứng sẵn có).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Bảng mô phỏng ba chính sách trong Completion Notes.
- Retained screenshots trong `production/qa/evidence/deck-power/`.

**Status**: Screenshots retained (deck-power/01-08) + simulation table (deck-power/simulation-70seeds.md).

---

## Dependencies

- Depends on: Story 017 (Deck, cards.json), Story 019 (RewardRoller, RewardView, RunSession)
- Unlocks: Story 021 (tuyệt kỹ khuếch đại từ khóa), nội dung chương 2–3

---

## Completion Notes
**Completed**: 2026-10-24
**Criteria**: 14/15 pass, 1 not met (closed by user decision with tech debt TD-001). DEFERRED (needs real play): feel of upgrades, clarity of the keywords, readability of the 4-slot reward screen.
**Deviations**: BLOCKING (accepted, logged TD-001): Phase D simulation target of 25 pp not reached, build vs always-skip is kiem_si +20.0, sat_thu +21.4, phap_su +4.3 (70 seeds x 3 characters x 3 policies, dt 0.05, 477.6 s); HP-at-end condition and deck-difference condition (0.562) pass. The bot casts 1-2 cells against dodging bosses so about two thirds of the pool is never used; JSON deliberately not tuned to fit it. ADVISORY: burn stacking is flat +1 damage per stack (base tracked separately), not compounding. ADVISORY: the fourth reward slot is a narrower card (0.16w); remove list is 6x2 tiles; card descriptions allow 4 lines; reward_view and cut_hud_view shrink long names with a fit-font helper. ADVISORY: `damage_per_cell` fallback comes from cuts.json (CutConfig), `damage_multiplier` and `class_tags` removed from the data. ADVISORY: scratch assertions updated for the new numbers (push of 5 cells = 20 in cut_test, status_test, cut_flow_test). ADVISORY: `--demo=pin` prints a pre-existing DemoArgs warning. ADVISORY (balance, TD-002/003): mage starter deck, 7-cell bang_phong in every starter deck.
**Test Evidence**: Logic; tests waived at `qa.level: minimal`. Retained screenshots `production/qa/evidence/deck-power/01-08*.png` (all opened and checked) and the simulation table `simulation-70seeds.md` plus raw output. Scratch suites 0 fails: deck_power (49), keyword (35), deck, cut, status, i18n, reward_run (45), character, chapters (67), run_flow2, pause_flow, arbiter, run/trait/arena flow (headless); cut_flow and focus_flow (windowed, `--no-autopause`). Parse-check 67/67.
**Code Review**: Skipped (solo mode).
**Not verified**: real feel, balance with a human player, touch on a device.
**Carries forward**: Story 021 (signature skills amplify the deck), a content story for chapters 2-3, then the playtest gate; TD-001..003.
