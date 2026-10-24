# Story 023: Nội dung chương 2–3 — boss và trait mới, địch phá luật, lá sử thi có điều kiện, pool 24 lá

> **Epic**: Kaiten Duel (v4)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-24

## Context

**GDD**: `design/game-brief.md` (v4, mục "Thế giới", "Roguelike"), `design/reference/osfe-reference.md` (§2.4, §5, §7, §8)
**Requirement**: Người dùng không muốn chơi thử khi nội dung còn mỏng: hiện có 1 chương đủ (9 trận) và một chương mẫu 1 tầng. Story này làm **chương 2 Hầm Ngục và chương 3 Tháp Sương** đầy đủ trên bản đồ 7 cột của Story 022, thêm **địch phá luật** (lý do để pool lá có "lá dở trong trận này"), đưa lá sử thi về đường cong OSFE (độ hiếm mua điều kiện, không mua sát thương), và mở rộng pool lên 24 lá với hai từ khóa mới.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM (chủ yếu dữ liệu + 3 trait/behaviour mới)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Địch phá luật (3 mẫu, cắm như trait/brain profile)**

- [ ] **Bóng Ma** (mẫu OSFE `Ghost`): máu rất thấp (`boss_max_hp` 24), **giáp phẳng** cao (`boss_defense` 12, trừ sau khi tính Ghim/nội tại, tối thiểu 1 — công thức OSFE §9.4); Đốt và lá có cờ `pierce_defense` bỏ qua giáp. Buộc người chơi dùng lá đốt hoặc lá xuyên giáp. `boss_defense` là khóa mới trong match, mặc định 0, có trong `schema.md`.
- [ ] **Kẻ Phản Ứng** (mẫu `Reacter`): trait `step_reactor` — mỗi lần người chơi bước, boss nhận một "phát" (`charges`); đủ `charges_to_fire` (3) thì vung ngay một đòn 3 ô tới ô người chơi với cảnh báo `warning_sec` 0,5 s. Người chơi đứng yên nối ấn thì an toàn: thưởng Tập trung.
- [ ] **Pháo Ngòi** (mẫu `Chargecannon`): trait `fuse_cannon` — ngòi đếm `fuse_sec` (12 s) hiện thanh trên HUD; hết ngòi → đòn toàn hàng của người chơi `fuse_damage` (40 = 13 % máu 300); trúng boss đủ `interrupt_damage` (30) trong một đòn thì ngòi đặt lại. Kiểm tra DPS, thưởng trận pháp lớn.
- [ ] Ba địch đều là match bình thường trong pool `danger`/`battle` tier ≥ 1 của chương 2–3; tên và mô tả một dòng (hiện ở intro trận) có khóa vi/en.

**Phần B — Chương 2 và 3**

- [ ] `chapters.json`: **ch2 Hầm Ngục** (7 cột theo khung 022; pool 10 trận: 6 lính thường ở 3 tier, Bóng Ma, Kẻ Phản Ứng, miniboss *Cai Ngục* (trait `rotten_thrower` + `row_burner` nhẹ), boss *Quỷ Khổng Lồ* (trait mới `slam`: cứ `slam_interval_sec` 7 s đập nứt 2 ô ngẫu nhiên bên người chơi trong `crack_sec` 4 s, ô nứt không đứng được — mẫu OSFE TileType Cracked)). **ch3 Tháp Sương** (pool 10 trận: 6 lính, Pháo Ngòi, Bóng Ma bản mạnh, miniboss *Pháp Sư Sương* (`frost_aura`: ấn rơi chậm 0,8× khi boss còn > 50 % máu), boss *Chúa Tể Sương* (2 pha: pha 2 ở 50 % máu đổi `brain_set` sang `aggressive` và bật `row_burner`)). Số máu địch leo thang **4 trục** (OSFE §5): +15 % máu/chương, `boss_step_cooldown_mult` −0,1/chương, `boss_defense` 0 → 2 → 4 cho lính thường, boss cần `boss_min_runes` (mới: boss ưu tiên trận pháp ≥ N ô) 2 → 3.
- [ ] Mở khóa: chương 3 mở khi chương 2 thắng (chuỗi hiện có). Sân (`arenas.json`) thêm 2 hình cho chương 3 (`cross_wide`, `pillars`).
- [ ] Mỗi chương một dòng intro và một dòng kết (CSV vi/en); tên boss/trait/địch mới đủ khóa.

**Phần C — Lá: đường cong độ hiếm và pool 24**

- [ ] **Lá sử thi về 7–8 sát thương/ô và có điều kiện** (OSFE §2.2, §8.2): `tu_kiem` 8/ô, **Hành quyết**: ×2 khi boss dưới `execute_ratio` 0,25; `song_kiem` 8/ô, ×1,5 khi boss đang Rạn; `han_bang` giữ ghim 1,8 s nhưng thêm Rạn 2 tầng. Lá hiếm 7–8/ô. Lá thường 6–7/ô. `damage_per_cell` không còn tăng theo độ hiếm.
- [ ] **Hai từ khóa mới** (OSFE §7, đề xuất §8.9): **Rạn** (`fragile`): địch nhận ×`fragile_mult` 1,5 từ đòn kế tiếp, mỗi đòn trừ 1 tầng, tối đa 3 tầng; **Hàn** (`frost`): 3 tầng → nổ `frost_burst` 24 sát thương xuyên giáp rồi xóa tầng. **Ghim** chỉ còn khống chế (bỏ ×1,5 của 020; `pinned_damage_mult` về 1,0 và chuyển vai trò sang Rạn). HUD hiện tầng Rạn/Hàn cạnh Cháy ×N.
- [ ] Pool 20 → **24 lá**: 2 lá Rạn (thường 3 ô, hiếm 2 ô), 2 lá Hàn (thường 2 ô, hiếm 4 ô diện rộng). Bộ khởi đầu không đổi. Mô tả lá nhắc từ khóa. Thẻ thưởng hiện từ khóa bằng màu riêng.
- [ ] `combat.json`: `pinned_damage_mult` 1,0, `fragile_mult`, `fragile_max_stacks`, `frost_stacks_to_burst`, `frost_burst_damage`, `execute_ratio` mặc định; tất cả có trong `schema.md`.

**Phần D — Kiểm chứng**

- [ ] Test: giáp phẳng trừ đúng và tối thiểu 1, Đốt/`pierce_defense` bỏ qua giáp; `step_reactor` vung sau đúng 3 bước và không vung khi đứng yên; `fuse_cannon` nổ sau 12 s và đặt lại khi trúng ≥ 30; `slam` nứt 2 ô và ô nứt chặn bước trong 4 s; `frost_aura` 0,8× rồi tắt ở 50 %; boss 2 pha đổi brain đúng mốc; Rạn ×1,5 trừ tầng, Hàn nổ ở 3 tầng xuyên giáp; Hành quyết ×2 dưới 25 %; ch2/ch3 nạp, pool đủ, 2 sân mới hợp lệ; i18n đủ khóa.
- [ ] Mô phỏng `deck_sim` chạy ch1→ch3 với bản đồ 022 (70 seed × 3 nhân vật, chính sách build): báo tỉ lệ thắng từng chương; mục tiêu **ch1 40–60 %, ch2 25–45 %, ch3 15–35 %** với bot hiện tại; số đòn trúng/run thắng 15–30. Không đạt thì chỉnh JSON (máu, defense, cooldown), không chỉnh mã. Ghi bảng vào Completion Notes.
- [ ] Ảnh trong `production/qa/evidence/chapters-2-3/`: intro Bóng Ma với dòng mô tả; HUD Kẻ Phản Ứng đang đếm phát; HUD Pháo Ngòi với thanh ngòi; Quỷ Khổng Lồ với 2 ô nứt; Chúa Tể Sương pha 2; HUD với Rạn ×2 và Hàn ×3; màn thưởng có lá Hành quyết; màn chọn chương với 3 chương (ch3 khóa).
- [ ] Không hằng số gameplay trong mã; mọi chuỗi mới là khóa `TEXT_*` với vi và en; JSON chỉ `name_key`/`desc_key`.

---

## Implementation Notes

- Trait mới (`step_reactor`, `fuse_cannon`, `slam`, `frost_aura`, `phase_shift`) dùng `BossTrait` hooks hiện có; nếu thiếu hook (ví dụ "người chơi vừa bước", "boss nhận sát thương ≥ X một đòn", "máu dưới ngưỡng") thì thêm vào `TraitHost` ở **một** điểm và ghi vào Completion Notes.
- Giáp phẳng và `pierce_defense` đi qua `CutEffects.apply` đúng điểm hiện có (sau Ghim/nội tại/tuyệt kỹ, trước `state.damage`); `StatusEffects` thêm `fragile`/`frost` cạnh `pin`/`burn`, cùng API `stacks_at`.
- Đường cong độ hiếm là một lượt sửa `cards.json` + cập nhật `deck_power_test` (các assertion 10/9 dpc).
- Thứ tự làm: C (từ khóa + lá, vì A/B cần Rạn/pierce) → A → B → D.

---

## Out of Scope

- Cửa hàng, tiền, pact, hell pass (story sau). Nhân vật 4–5. Hình/âm thật. Minigame trại nghỉ. Lên Android (story riêng sau cổng chơi thử).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/chapters-2-3/`; bảng mô phỏng 3 chương.

**Status**: Screenshots retained (chapters-2-3/01-10) + simulation summary (chapters-2-3/simulation-70seeds.md).

---

## Dependencies

- Depends on: Story 022 (bản đồ 7 cột, pool theo loại nút, máu ×3), Story 020 (từ khóa, cấp lá), Story 014 (TraitHost)
- Unlocks: **cổng chơi thử 6** (run đầu tiên đủ nội dung), cửa hàng/pact, Android

---

## Completion Notes
**Completed**: 2026-10-24
**Criteria**: 12/14 pass, 2 not met (closed by user decision with tech debt TD-006, TD-008, TD-009): the three-chapter win-rate targets (40–60 / 25–45 / 15–35 %) and 15–30 boss hits per won run. DEFERRED (needs real play): feel of the rule-breakers (Reacter and Fuse Golem win 90–100 %, Reacter under-measured because the bot rarely steps), readability of the new HUD readouts on a phone, character balance (TD-008).
**Deviations**: BLOCKING (accepted): simulation targets. With the data as first delivered chapters 2 and 3 were never won (0 % for all three characters): the boss step cooldown shrinks with board size (0.23–0.29 s on large boards against 0.37–0.80 s in chapter 1) and the chapter escalation lowered it further. A per-match step tuning measured with `--step-mult` was applied (14 values in `chapters.json`: ogre_king step 1.01→1.5 and HP 260→290, rat_king_guard 1.12→1.6, bat_swarm 1.34→1.7, ghost 1.0→1.3, ghost_elite 0.9→1.3, stone_sentry 1.24→1.9 and move_commitment 0.9→0.7, snow_wolf 1.1→1.6, ice_golem 1.02→1.5, rime_archer 1.1→1.4, frost_mage 1.1→1.6 and HP 190→210, mist_lord 1.0→1.5, jailer 1.12→1.3). Result (build, 70 seeds): chapter 1 91.4 / 45.7 / 84.3 %, chapter 2 58.6 / 7.1 / 58.6 %, chapter 3 20.0 / 0.0 / 18.6 % (Swordsman / Mage / Assassin); chapter 3 is in band for the two melee characters, chapter 2 is easy for them. ADVISORY: pool is 26 cards, not 24 (Hàn needed 4 cards for a viable keyword build); `song_kiem` moved rare→epic to match its condition. ADVISORY: Ghim is control-only (`pinned_damage_mult` 1.0, the code path stays); Rạn and Hàn are per-side stacks; Hàn burst is applied by the caller so it bypasses defense and Rạn. ADVISORY: `boss_defense` travels as `options.target_defense` through `CutEffects.apply`. ADVISORY: trait names/descriptions, `desc_key` (match intro line) and `intro_key`/`end_key` (chapter lines on the map header and the RUN WON panel) were added after the logic parts; `--chapter=<id>` dev arg added. ADVISORY: Mage balance: HP 180/200 and a deck swap were measured and reverted (TD-008, balance by playtest). ADVISORY: not captured separately: frost_aura tag, slam warning outline, reactor 3/3 red state.
**Test Evidence**: Integration; tests waived at `qa.level: minimal`. Retained screenshots `production/qa/evidence/chapters-2-3/01-10*.png` (opened and checked) and `simulation-70seeds.md` plus `simulation-70seeds-raw.txt`. Scratch suites 0 fails on the final data: keyword2 (70), defense (22), traits2 (71), chapters23 (125), map_gen (35), reward_luck (23), run_session_v4, run_flow2, pause_flow, reward_run, deck_power, signature, keyword, i18n, character, chapters (69), deck, cut, status, arbiter, run/trait/arena flow (headless, 24 suites); cut_flow and focus_flow (windowed, `--no-autopause`). Parse-check 83/83; strings.csv 296 rows, 3 columns each.
**Code Review**: Skipped (solo mode).
**Not verified**: feel with a human player, bot dodge calibration (TD-006), touch on a device.
**Carries forward**: gate 6 playtest (first run with all three chapters); character balance (TD-008); chapter 2 retune (TD-009); TD-001..009.
