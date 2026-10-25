# Story 038: Cấp Kiếp — 10 cấp khó cộng dồn theo nhân vật, mở bằng thắng run (như Hell Pass)

> **Epic**: Kaiten Duel (v6)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md` (v6, mục "Chơi lại" → "Cấp Kiếp"), `design/reference/osfe-reference.md` (§9.6: 15 Hell Pass, mỗi bậc một dòng dữ liệu; §5.4 leo thang bằng buff gắn thêm)
**Requirement**: Sau khi thắng run đầu tiên người chơi cần lý do quay lại ngoài mở khóa (037). OSFE dùng Hell Pass: mỗi lần thắng mở một bậc khó mới, bậc cộng dồn, mỗi bậc một luật. Người dùng chốt **cấp Kiếp**: thắng run ở cấp k mở cấp k+1 **cho nhân vật đó**, 10 cấp cộng dồn, mỗi cấp một luật khó trong dữ liệu. Không cộng sức mạnh vĩnh viễn: Kiếp chỉ làm khó hơn.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM (luật chạm nhiều điểm: tạo trận, bản đồ, thưởng, nghỉ, kinh tế)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Dữ liệu cấp (`assets/data/kiep_levels.json`, mới, có trong `schema.md`)**

- [ ] `levels`: mảng 10 phần tử (cấp 1..10; cấp 0 = thường, không có dòng), mỗi phần tử `{level, name_key, desc_key, rule: {type, params}}`. Cấp k áp **mọi** luật cấp 1..k. Không có luật nào ở cấp 0.
- [ ] Mười luật khởi điểm (thứ tự và số chỉnh bằng mô phỏng; `type` là một trong tập cố định dưới đây):

  | Cấp | `type` | Khởi điểm | Điểm áp |
  |---|---|---|---|
  | 1 | `boss_extra_trait` | boss vùng thêm 1 trait seeded từ `trait_pool` (ví dụ `row_burner`, `seal_caster`, `thorn_field`, `slam`), không trùng trait đã có | tạo trận |
  | 2 | `node_weight` | nút `danger` ×2 trọng số trong cột nhánh | sinh bản đồ vùng |
  | 3 | `rest_heal_mult` | Nghỉ ở trại hồi ×0,67 (0,30 → 0,20) | trại nghỉ |
  | 4 | `player_drop_mult` | nhịp rơi mảnh người chơi ×1,15 (chậm hơn) | tạo trận |
  | 5 | `gold_mult` | vàng rơi ×0,75 | kinh tế (Story 033) |
  | 6 | `boss_swing_mult` | boss niệm nhanh hơn: `swing_speed_mult` ×1,10 | tạo trận |
  | 7 | `floor_heal_mult` | hồi khi sang tầng ×0,5 (0,25 → 0,125) | sang tầng |
  | 8 | `max_hp_mult` | máu tối đa nhân vật ×0,85 cả run | bắt đầu run |
  | 9 | `floor_shift` | địch dùng hệ số `floor_scaling` của tầng kế (tầng 5 và trận cuối dùng `final` + `extra` khởi điểm hp ×1,1) | tạo trận |
  | 10 | `shop_price_mult` + `boss_extra_trait` | giá cửa hàng ×1,2 và trận cuối thêm 1 trait | kinh tế, tạo trận |

- [ ] Luật là **danh sách loại cố định trong mã** (`KiepRules`, lớp thuần), số trong JSON; thêm cấp mới chỉ cần dòng JSON nếu `type` đã có. `type` lạ → cảnh báo, bỏ qua dòng đó, không crash.

**Phần B — Áp luật (một điểm cho mỗi loại)**

- [ ] `KiepRules.apply_match(match_cfg, level, ctx)`, `apply_map_spec(region_spec, level)`, `apply_run_start(character, level)`, `rest_heal_ratio(base, level)`, `floor_heal_ratio(base, level)`, `economy_mult(key, level)` — thuần, test được không cần cây node. Gọi từ đúng một chỗ mỗi loại: `RunConfig.from_node` (trận), `ChapterMapGen` qua `ChaptersConfig.region_spec` (bản đồ), `RunSession.begin` (máu), `RunSession.rest_heal` / chuyển tầng (hồi), lớp kinh tế của Story 033 (vàng, giá).
- [ ] Trait thêm (`boss_extra_trait`) chọn seeded theo `hash([run_seed, floor, match_id])`: cùng seed cùng trait; tên trait hiện ở intro trận như trait thường.
- [ ] Hệ số nhân dồn theo thứ tự cấp, kẹp theo cận an toàn trong JSON (`clamp`: ví dụ máu tối đa ≥ 40 % gốc, nhịp rơi ≤ ×1,5) để cộng dồn về sau không phá game.

**Phần C — Mở cấp và lưu**

- [ ] `ProgressState` (tăng version, file cũ nạp với mọi nhân vật ở cấp mở = 0): `kiep_unlocked[character_id]` (cấp cao nhất được chọn, 0..10) và `kiep_best_won[character_id]` (cấp cao nhất đã thắng, −1 = chưa thắng). Thắng run ở cấp k: `best_won = max(best_won, k)`, `unlocked = max(unlocked, min(k + 1, 10))`. Thắng ở cấp thấp hơn cấp đã mở không đổi gì. Thua không đổi gì.
- [ ] `RunSession` lưu `kiep_level` (save tăng version; save cũ nạp với 0). Cấp không đổi được giữa run.

**Phần D — Màn chọn nhân vật và HUD (chạm)**

- [ ] `CharacterSelectView`: mỗi thẻ nhân vật hiện huy hiệu "Kiếp N" = `kiep_best_won` (ẩn khi −1). Dưới thẻ đang chọn có **thanh chọn cấp**: nút **−** và **+** lớn ở hai mép (mỗi nút ≥ 96 px, trong tầm ngón cái), số cấp to ở giữa; cấp chưa mở không chọn được (nút + mờ, chạm vào hiện một dòng "Thắng Kiếp N để mở"). Mặc định chọn **cấp cao nhất đã mở**.
- [ ] Dưới thanh cấp: danh sách luật đang bật (cấp 1..k, mỗi luật một dòng ngắn từ `desc_key`), luật mới của cấp k tô nổi. Danh sách dài hơn chỗ thì kéo dọc bằng một ngón (không cần thanh cuộn nhỏ).
- [ ] HUD run (`RunHudView`) và `WorldMapView` hiện "Kiếp k" cạnh dòng tầng khi k > 0; màn kết thúc/thua ghi cấp; khi thắng mở cấp mới, màn kết thúc thêm dòng "Đã mở Kiếp k+1".

**Phần E — Kiểm chứng**

- [ ] Test mới `tests/unit/run/kiep_rules_test.gd`: từng `type` áp đúng số tại cấp của nó và **không** áp ở cấp thấp hơn; cộng dồn cấp 10 đúng thứ tự và đúng kẹp; trait thêm seeded, không trùng; `type` lạ bị bỏ qua có cảnh báo; cấp 0 = cấu hình không đổi (so byte với không có Kiếp).
- [ ] Test mới `tests/unit/run/kiep_progress_test.gd`: mở cấp theo luật Phần C (thắng ở k mở k+1, trần 10, thắng cấp thấp không đổi, thua không đổi); riêng từng nhân vật; round-trip save; file cũ nạp được.
- [ ] Chạy lại: suite run/flow, `character_test`, `run_session_v5_test` (và bản tăng version), `reward_run_test`, suite kinh tế của Story 033, `i18n`, parse-check.
- [ ] **Mô phỏng** (deck_sim `--world --kiep=0..10`, 70 seed × 3 nhân vật, build, fate theo mặc định của Story 035): bảng tỉ lệ thắng run theo cấp. Mục tiêu khởi điểm: tỉ lệ thắng **giảm theo cấp** — `win(k) ≤ win(k−1) + 3` điểm (dung sai nhiễu 70 seed) và `win(k) < win(k−2)` với mọi k ≥ 2; cấp 10 vẫn **thắng được** (Kiếm sĩ build ≥ 3 %); không cấp đơn nào làm tụt > 12 điểm so với cấp trước (tránh bậc nhảy). Thêm bảng **từng luật riêng lẻ** (`--kiep-only=k`) để thấy mỗi luật khó thêm bao nhiêu; luật nào không làm khó đo được (< 1 điểm) thì đổi số hoặc thứ tự trong JSON. Thời gian run ước tính ở cấp 10 ≤ 55 phút.
- [ ] Ảnh trong `production/qa/evidence/kiep-levels/`: màn chọn nhân vật cấp 0 chưa mở gì (vi); cấp 3 đã chọn với danh sách 3 luật, luật mới tô nổi (en); chạm vào + khóa hiện dòng "Thắng Kiếp N để mở"; huy hiệu Kiếp trên thẻ nhân vật; HUD trong trận có "Kiếp k"; intro trận boss có trait thêm của cấp 1; màn kết thúc có "Đã mở Kiếp k+1".
- [ ] Không hằng số gameplay trong mã; chuỗi mới là khóa với vi và en (`kiep.level.N.name`, `kiep.level.N.desc`, `ui.character_select.kiep_*`).

---

## Implementation Notes

- File chạm: mới `src/run/kiep_rules.gd` (`class_name KiepRules`) và `assets/data/kiep_levels.json`; `src/run/run_config.gd`, `chapters_config.gd`, `run_session.gd`, `progress_state.gd`, `character_select_view.gd`, `run_hud_view.gd`, `world_map_view.gd` (Story 031), `ending_view.gd` (Story 035), lớp kinh tế của Story 033; `assets/data/schema.md`; `assets/i18n/strings.csv`; `tools/balance/deck_sim.gd` + `README.md`.
- Cờ dev: `--kiep=N` (bắt đầu run ở cấp N, bỏ qua khóa), `--progress=kiep3` (save có Kiếm sĩ thắng Kiếp 2, mở 3) cho chụp ảnh.
- Luật kinh tế (cấp 5, 10) cần Story 033; nếu 033 chưa xong khi làm story này, dời hai luật đó xuống cuối bảng và thay tạm bằng loại đã có, ghi ở Completion Notes.

---

## Out of Scope

- Thưởng riêng cho cấp Kiếp (đồ trang trí, danh hiệu), bảng xếp hạng, tự chọn luật trước run (để sau theo brief), Kiếp dùng chung giữa nhân vật, thành tựu theo Kiếp (037 có thể thêm sau), luật Kiếp thay đổi core loop trận (ví dụ bỏ Tập trung).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/kiep-levels/` (danh sách Phần E); bảng mô phỏng theo cấp và theo luật `simulation-kiep.md` + raw.

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 031 (run 5 tầng, `floor_scaling`), Story 035 (trận cuối thật, màn kết thúc), Story 037 (khung mở khóa và ProgressState theo nhân vật); dùng Story 033 cho hai luật kinh tế
- Unlocks: Story 040 (cân bằng lại cả run bằng mô phỏng, gồm đường cong Kiếp)
