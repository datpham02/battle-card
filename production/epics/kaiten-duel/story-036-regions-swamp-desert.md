# Story 036: Vùng Đầm Lầy Độc và Sa Mạc Cát Ấn — ô lầy, cát lấp ô, mảnh trôi theo gió, địch và boss vùng mới

> **Epic**: Kaiten Duel (v6)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md` (v6, mục "Run v6 — mô hình OSFE" › "Bản đồ thế giới", "Vùng"; v5 "Vùng: Kết giới và Trận gai"), `design/reference/osfe-reference.md` (§5.4 leo thang theo world, §5.5, §7.1 Poison)
**Requirement**: Bản đồ thế giới của Story 031 cho mỗi tầng chọn 1 trong 2 vùng, nhưng pool mới có 3 vùng (Rừng Sương, Hầm Ngục, Tháp Sương — nội dung `ch1`–`ch3` trong `assets/data/chapters.json`), nên 5 tầng × 2 lựa chọn lặp vùng ngay trong một run. Story này thêm hai vùng đầu tiên **có luật sân riêng** (không chỉ đổi địch): **Đầm Lầy Độc** (ô lầy: bước ra khỏi lầy thì hồi bước chậm, đứng trong lầy mất máu theo nhịp) và **Sa Mạc Cát Ấn** (cát lấp ô theo nhịp, mảnh trên sân trôi theo gió). Mỗi vùng theo mẫu nội dung của Story 023: 5–6 địch thường, 1 boss vùng, 2 kẻ phá luật, trait mới khi cần, sân riêng, trọng số mảnh riêng, tên/mô tả vi+en. Độ khó **không** gắn vào vùng: hệ số theo tầng của Story 031 lo phần đó.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM (hai lớp ô mới chạm `UnitMover` và rơi mảnh; 6 trait mới; phần lớn còn lại là dữ liệu)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Hai lớp ô mới (dùng chung cho mọi vùng, cả hai bên)**

- [ ] **Ô lầy** (`mire`): bước được. Bước **ra khỏi** một ô lầy thì cooldown của bước đó × `mire_step_mult` (khởi điểm 1,6). Đứng trong lầy mất `mire_tick_damage` (khởi điểm 1) mỗi `mire_tick_sec` (khởi điểm 0,5 s), tick đầu sau `mire_grace_sec` (khởi điểm 0,5 s) để đi ngang qua một ô lầy gần như không mất máu. Áp dụng cho người chơi và boss; trận có thể đặt `mire_immune: true` cho boss (khóa match mới, mặc định false).
- [ ] **Cát lấp** (`sand`): cứ `sand_interval_sec` (khởi điểm 6 s) mỗi bên có `sand_cells` (khởi điểm 2) ô bị cát lấp trong `sand_sec` (khởi điểm 3 s), cảnh báo `sand_warn_sec` (khởi điểm 0,8 s) trước. Ô cát **không bước vào được** (như ô nứt của `slam`, gộp qua `UnitMover.add_blocker`); mảnh đang nằm trên ô đó bị chôn (mất). Ô đang có người đứng không bị chọn. **Luật chừa đường** của Story 027 (`ZoneRules.fit_cells`) áp cho cát: không bao giờ để một bên không còn ô bước được.
- [ ] **Gió** (`wind`): ở sân có `wind: true`, mỗi mảnh đang nằm trên sân (của cả hai bên) trôi 1 ô theo hướng gió mỗi `drift_sec` (khởi điểm 2,0 s); hướng gió đổi mỗi `wind_shift_sec` (khởi điểm 8 s), chọn seeded trong 4 hướng. Mảnh không trôi vào ô thiếu, ô cát, ô có mảnh khác hay ra ngoài sân (đứng yên lần đó). Mảnh mới rơi xuống ô lệch 1 ô theo gió nếu ô đó trống ("mảnh rơi lệch"), nếu không thì rơi đúng chỗ.
- [ ] Số trong `assets/data/combat.json` khối mới `hazards` (`mire_step_mult`, `mire_tick_damage`, `mire_tick_sec`, `mire_grace_sec`, `sand_interval_sec`, `sand_cells`, `sand_sec`, `sand_warn_sec`, `drift_sec`, `wind_shift_sec`), trận ghi đè được qua khóa cùng tên trong match; tất cả có trong `assets/data/schema.md`. Trạng thái ô nằm trong model (`StatusEffects` hoặc lớp `TileHazards` cạnh nó: `is_mire(side, cell)`, `is_sanded(side, cell)`, `wind_dir()`), không trong view.
- [ ] Não boss (`assets/data/boss_brain.json`): trọng số mới `mire_avoid` trong mọi `sets` (balanced 1,0, aggressive 0,5, cautious 1,5 — khởi điểm) chấm chi phí bước vào lầy như `burn_avoid`/`thorn_avoid`; ô cát là ô chặn khi tìm đường và né; boss nhặt mảnh có tính trước hướng trôi. Ghi điểm vào `last_debug()`.

**Phần B — Đầm Lầy Độc (`swamp`)**

- [ ] Vùng `swamp` trong định dạng vùng của Story 031 (file và khóa do 031 chốt; nếu 031 vẫn dùng `chapters.json` thì là một mục mới cạnh `ch1`–`ch3`), `name_key` / `intro_key` / `end_key` vi+en, pool theo loại nút (`battle`, `danger` theo tier, `boss`).
- [ ] **6 địch thường** (khởi điểm, số là bậc tầng 1 trước hệ số tầng của 031): `bog_rat` (máu 88, cautious), `mire_slug` (máu 104, balanced, `mire_immune`), `swamp_lizard` (máu 112, balanced, `movement.move_commitment` 0,9), `marsh_toad` (máu 126, balanced, `swing_speed_mult` 0,95), `reed_witch` (máu 138, balanced, trait `rotten_thrower` `interval_sec` 7), `bog_hound` (máu 150, balanced, trait `row_burner`). `boss_step_cooldown_mult` 1,3–1,8 như các trận cùng bậc ở `ch1`.
- [ ] **Kẻ phá luật 1 — Nấm Bào Tử** (`spore_cap`, máu 70): trait mới `spore_burst` — mỗi lần bị trúng, rải lầy lên ô người chơi đang đứng và tối đa `spread_cells` (khởi điểm 2) ô kề trong `spore_mire_sec` (khởi điểm 4 s), có thời gian chờ nội `icd_sec` (khởi điểm 1,5 s). Ép "đánh ít mà đau": nhiều đòn nhỏ biến đất mình thành bãi lầy.
- [ ] **Kẻ phá luật 2 — Ếch Nhảy** (`leap_frog`, máu 80): trait mới `hop_skip` — mỗi `hop_every` (khởi điểm 3) bước, bước kế tiếp là cú nhảy 2 ô thẳng, **bỏ qua** kết giới và gai nằm giữa (ô đích vẫn phải bước được). Làm lá vùng yếu đi trong trận này; thưởng đòn đón đầu ô đích (bóng đích hiện `hop_warn_sec` 0,4 s trước).
- [ ] **Boss vùng — Cóc Chúa** (`toad_matriarch`, máu 170, `aggressive`, `mire_immune`): trait mới `bog_spread` — cứ `interval_sec` (khởi điểm 8 s) biến `cells` (khởi điểm 2) ô bên người chơi thành lầy trong `mire_sec` (khởi điểm 5 s), ưu tiên ô thoát của người chơi khi boss đang niệm đòn ≥ 3 ô (như `thorn_field`); kèm `seal_caster` nhẹ (`interval_sec` 12) để boss có cả "chặn" và "làm chậm".
- [ ] **Sân**: 2 hình mới trong `assets/data/arenas.json` — `bog` (rộng, ô thiếu ít) và `reed_maze` (nhiều ô thiếu, lối hẹp) — mỗi hình có `hazards.mire` (số ô lầy mỗi bên, seeded khi `variant: true`), `featured_shape` 5–7 ô và `featured_bonus` hiệu ứng `pin` ("sa lầy"). `ArenaValidator` nhận khóa mới, kiểm luật chừa đường và luật "ghép được hình chủ đạo từ ít nhất 2 cặp mảnh".
- [ ] **Trọng số mảnh** `swamp` trong `assets/data/pieces.json` `weights`: nghiêng mảnh 2–3 ô (lầy làm đi chậm, mảnh nhỏ dễ nhặt hơn), 5 ô hiếm như `ch1`.

**Phần C — Sa Mạc Cát Ấn (`desert`)**

- [ ] Vùng `desert` cùng định dạng, `name_key` / `intro_key` / `end_key` vi+en, sân có `wind: true` và `hazards.sand`.
- [ ] **6 địch thường** (bậc tầng 1, khởi điểm): `dune_jackal` (máu 90, cautious), `sand_beetle` (máu 106, balanced, `boss_defense` 2), `dust_nomad` (máu 116, balanced), `mirage_sprite` (máu 124, cautious, `movement.move_noise` 0,15), `scarab_guard` (máu 140, balanced, `boss_defense` 3), `sun_archer` (máu 152, balanced, `row_burner`).
- [ ] **Kẻ phá luật 1 — Bọ Cát Ẩn** (`sand_burrower`, máu 84): trait mới `burrow` — cứ `interval_sec` (khởi điểm 7 s) lặn `burrow_sec` (khởi điểm 1,5 s): không bị trúng, không bị phá phép, rồi trồi ở ô seeded (vòng tròn cảnh báo `surface_warn_sec` 0,5 s). Đòn tới nơi lúc boss đang lặn là trượt nhưng vẫn để vùng (luật 027). Thưởng canh nhịp và kết giới chặn ô trồi.
- [ ] **Kẻ phá luật 2 — Bọ Cạp Phản** (`scorpion`, máu 96): trait mới `riposte` — trúng nó bằng đòn ≥ `min_cells` (khởi điểm 4) ô thì nó phản ngay một đòn 1 ô vào ô người chơi với cảnh báo `warn_sec` 0,4 s, sát thương `damage` (khởi điểm 10). Ngược với Nấm Bào Tử: thưởng đòn nhỏ.
- [ ] **Boss vùng — Nhân Sư Cát** (`sand_sphinx`, máu 175, `balanced`, `boss_min_runes` 3): trait mới `sandstorm` — cứ `interval_sec` (khởi điểm 12 s) bão cát `storm_sec` 3 s: `drift_sec` ×0,5 và lấp thêm `extra_sand` (khởi điểm 2) ô bên người chơi (vẫn chừa đường); HUD hiện thanh bão.
- [ ] **Sân**: 2 hình mới `dunes` và `oasis` (ô giữa thiếu), `featured_bonus` hiệu ứng `fragile`; validator như Phần B.
- [ ] **Trọng số mảnh** `desert`: nghiêng thanh (`bar2`/`bar3`/`bar4`) vì gió trôi theo hàng/cột.

**Phần D — Vào bản đồ thế giới (Story 031)**

- [ ] `swamp` và `desert` vào pool vùng; xuất hiện ở mọi tầng 1–5, độ khó do hệ số tầng của 031 (máu, nhịp bước, giáp, cỡ đòn). Nếu 031 có khóa `min_floor` thì để mặc định (1); story mở khóa (037) có thể khóa vùng sau.
- [ ] Không lặp vùng trong run khi pool đủ (luật 031), seeded: cùng seed cho cùng thứ tự vùng.
- [ ] Mọi trait mới đăng ký trong `src/traits/trait_registry.gd`, kế thừa `BossTrait`, đọc tham số từ dữ liệu; hook thiếu (ví dụ "boss vừa bị trúng" cho `spore_burst`/`riposte`) thêm vào `TraitHost` ở **một** điểm.

**Phần E — Hiển thị, chạm và kiểm chứng**

- [ ] Hình đọc được trên điện thoại ngang: lầy là ô sẫm có bọt (khác hẳn gai răng cưa và kết giới khối đặc của 027); ô sắp lấp có viền cát nhấp nháy trong `sand_warn_sec`, ô đã lấp là khối cát có thanh thời gian; mũi tên gió ở góc HUD **và** vệt nhỏ trên mỗi mảnh sắp trôi. Không thêm thao tác mới: chạm/kéo như cũ; mảnh đang bị kéo để đặt **không** trôi.
- [ ] Test (`tests/unit/combat/hazard_test.gd`, `tests/unit/traits/region_traits_test.gd`, `tests/unit/run/regions_swamp_desert_test.gd`): rời ô lầy nhân cooldown đúng, tick độc đúng nhịp và bỏ qua thời gian ân hạn, `mire_immune`; ô cát chặn bước rồi mở, chôn mảnh, không chọn ô có người, luật chừa đường; gió trôi đúng hướng, không trôi vào ô cấm, mảnh đang kéo không trôi; mỗi trait mới đúng nhịp và tham số; hai vùng nạp, pool đủ, 4 sân mới hợp lệ, đủ khóa i18n vi/en.
- [ ] **Mô phỏng**: bot (`tools/balance/hit_probe.gd` chế độ `bot` và `deck_sim.gd`, thêm cờ chọn vùng và tầng nếu 031 chưa có, ví dụ `--region=swamp --floor=1,3,5`) đi qua mạch lầy/cát/gió như người chơi (tránh lầy theo chi phí, đi vòng cát, đuổi mảnh trôi). Báo theo tầng 1, 3, 5: tỉ lệ thắng từng trận, boss vùng, đòn trúng/trận, số lần vào lầy và máu mất do lầy mỗi trận, số mảnh bị chôn/trôi. **Mục tiêu**: ở cùng tầng, tỉ lệ thắng trung bình của mỗi vùng mới nằm trong ±10 điểm so với trung bình 3 vùng cũ; không trận nào thắng > 95 % hay < 15 % ở tầng 1; máu mất do lầy ≤ 15 % máu mất cả trận. Không đạt thì chỉnh JSON, không chỉnh mã. Bảng vào Completion Notes và `production/qa/evidence/regions-swamp-desert/simulation-regions.md` (+ raw).
- [ ] Ảnh trong `production/qa/evidence/regions-swamp-desert/`: sân `bog` có lầy hai bên; người chơi đứng trong lầy với số mất máu; Nấm Bào Tử rải lầy; Ếch Nhảy với bóng đích; sân `dunes` có cát sắp lấp và đã lấp; mũi tên gió và mảnh đang trôi; Bọ Cát Ẩn đang lặn; Nhân Sư Cát trong bão; màn chọn vùng của 031 có Đầm Lầy Độc / Sa Mạc Cát Ấn (vi và en).
- [ ] Không hằng số gameplay trong mã; chuỗi mới là khóa trong `assets/i18n/strings.csv` với vi và en; JSON chỉ `name_key`/`desc_key`.

---

## Implementation Notes

- Ô cát dùng lại `UnitMover.add_blocker` (đã gộp nứt + kết giới ở 027); thêm nguồn thứ ba chứ không ghi đè.
- Lầy là hệ số cooldown của **một** bước, đặt ở `UnitMover` qua một hàm hệ số cắm được (như `blocked_cell_fn`), để Ảnh Bộ (bước không cooldown) vẫn thắng lầy — ghi rõ thứ tự nhân trong Completion Notes.
- Trôi mảnh và chôn mảnh đi qua model mảnh trên sân của Story 024 (`field_drops`), không di chuyển node trong view.
- Thứ tự làm: A (lớp ô) → B → C → D → E. Demo: `--demo=mire|sand|wind|spore|hop|burrow|riposte|bog_spread|sandstorm`.

---

## Out of Scope

- Thành Hỏa Ngục, Không Đảo (Story 039). Khóa vùng theo cột mốc (Story 037). Lá, bảo vật hay hình mảnh riêng của vùng. Trạng thái Độc chồng tầng kiểu OSFE (lầy chỉ là mất máu theo ô). Cân bằng cả run (Story 040). Hình/âm thật.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/regions-swamp-desert/`; bảng mô phỏng theo tầng.

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 031 (bản đồ thế giới, pool vùng, hệ số theo tầng), Story 027 (luật chừa đường, `add_blocker`), Story 024/025 (mảnh trên sân, boss dùng mảnh)
- Unlocks: Story 039 (đợt vùng 3 dùng lại lớp ô), Story 040 (cân bằng cả run)
