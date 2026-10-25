# Story 032: Bảo vật — đồ bị động đổi luật gắn với mảnh, ghép, trận đồ, vùng và từ khóa; mang theo cả run

> **Epic**: Kaiten Duel (v6)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md` (v6, mục "Run v6 — mô hình OSFE" → "Xây build trong run"; nền cơ chế: mục "Core loop (v5)"), `design/reference/osfe-reference.md` (§ Artifact: schema `App`, tag `Negative`/`Boss`/`Miniboss`, độ hiếm 0–3, giá shop)
**Requirement**: Build trong run hiện chỉ có lá bài và nâng cấp. OSFE cho thấy thứ làm hai run khác nhau là **artifact đổi luật** (không chỉ cộng số). Ấn Kiếm cần một lớp bảo vật bám vào cơ chế riêng của mình (cỡ mảnh, ghép 2 mảnh, hình chủ đạo, trận đồ, kết giới/gai, Ghim/Đốt/Rạn/Hàn, túi mảnh, Tập trung, phá phép). Không có bảo vật theo nhân vật. Story này dựng hệ (dữ liệu, registry, móc vào trận, HUD, save) và 16 món khởi điểm; nguồn cửa hàng/sự kiện là Story 033, phần thưởng Giết boss là Story 035.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH (móc vào nhiều điểm của `CombatView`/`CutEffects`/`FieldDrops`, thứ tự nhân sát thương, save run)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Dữ liệu và registry**

- [ ] `assets/data/relics.json` mới: `relics: [{id, rarity, tags, name_key, desc_key, script, params}]`, `rarity_weights` (khởi điểm common 60 / rare 30 / epic 10), `source_rules` (`treasure`: 1 trong 3 không trùng món đang có, sàn `common`; `boss_kill`: 1 món từ tier `boss`, hết thì `epic`). `rarity` ∈ {`common`, `rare`, `epic`, `boss`}; `tags` dùng {`negative`, `stackable`}. Mô tả đầy đủ trong `assets/data/schema.md` (mục mới `relics.json`).
- [ ] `src/relics/relic_registry.gd` (`class_name RelicRegistry`) theo đúng mẫu `PassiveRegistry` / `TraitRegistry`: `SCRIPTS` id-script → `create(script_id)`, `has_id`, `known_ids`; id lạ → `null` + `push_warning`, không crash. `src/relics/base_relic.gd` (`class_name BaseRelic`) với các móc mặc định trung tính (trả nguyên giá trị): `setup(ctx, params)`, `on_match_start()`, `modify_cast_damage(cast_info, damage)`, `modify_cast_time(cast_info, sec)`, `on_cast_landed(cast_info)`, `on_join(cast_info)`, `on_interrupt_by_player()`, `config_overrides() -> Dictionary`, `teardown()`. `cast_info` gồm ít nhất `{pieces: [shape_id], cells: int, joined: bool, featured: bool, card_id, hit: bool}`.
- [ ] Một script dùng chung `ConfigModRelic` cho các món chỉ đổi số cấu hình (túi, nhịp rơi, thời gian kết giới, trần Đốt, phai trận đồ, cooldown tuyệt kỹ, Tập trung) — đọc `params` dạng `{key: {mul|add: x}}`; món có điều kiện mới cần script riêng. Thêm một món kiểu cấu hình = chỉ thêm JSON.
- [ ] Chuỗi người chơi là khóa i18n trong `assets/i18n/strings.csv`, đủ vi và en: `relic.<id>.name`, `relic.<id>.desc`, cộng `TEXT_RELIC_*` cho HUD/tooltip. Mô tả ghi số khớp `params` (test so số trong mô tả với `params` cho các món kiểu cấu hình).

**Phần B — 16 bảo vật khởi điểm (mọi số là khởi điểm, chỉnh bằng mô phỏng)**

- [ ] Có đủ 16 món, mỗi món đổi một luật gắn với cơ chế riêng:

| id | Tên (vi) | Độ hiếm | Luật | Số (params) |
|---|---|---|---|---|
| `an_don` | Ấn Đơn | common | Đòn chỉ gồm 1 mảnh `mono`: sát thương ×2 | `mult: 2.0` |
| `chi_khau` | Chỉ Khâu | common | Mỗi đòn ghép 2 mảnh hồi máu | `heal: 3`, `max_heal_per_match: 15` |
| `phong_an` | Phong Ấn Dài | common | Kết giới của người chơi kéo dài hơn | `seal_sec add: 1.0` |
| `gai_ran` | Gai Rạn | common | Địch bước vào ô gai của người chơi nhận thêm Rạn | `thorn_ran add: 1` |
| `manh_tuoi` | Mảnh Tươi | common | Mảnh trên sân tươi lâu hơn; vào trận thêm 1 mảnh | `piece_freshness_sec add: 4`, `start_pieces add: 1` |
| `dinh_tam` | Định Tâm | common | Tập trung dài hơn | `focus_sec add: 1.0` |
| `la_ban` | La Bàn Trận Đồ | rare | Ô trận đồ phai chậm hơn | `formation_fade mul: 1.3` |
| `tam_huong` | Tâm Hương | rare | Cooldown tuyệt kỹ ngắn hơn | `signature_cooldown mul: 0.8` |
| `tui_rong` | Túi Rộng | rare | Túi mảnh 4 ô nhưng mảnh rơi chậm hơn | `hold_slots add: 1`, `piece_spawn_interval mul: 1.25` |
| `dau_than` | Dầu Thần | rare | Đốt chồng thêm một tầng | `burn_max_stacks add: 1` |
| `khoi_the` | Khởi Thế | rare | Phép đầu tiên mỗi trận không có thời gian niệm | `first_casts: 1` |
| `phan_don` | Phản Đòn | rare | Phá phép boss thì nhận ngay 1 mảnh `mono` vào túi (nếu còn chỗ) | `shape: mono` |
| `han_ky` | Hàn Khí | epic | Hàn nổ ở 2 tầng thay vì 3, nhưng nổ yếu hơn | `han_stacks: 2`, `han_damage mul: 0.67` |
| `huyet_an` | Huyết Ấn | epic, `negative` | Đòn ≥ 5 ô +30 % sát thương; mỗi đòn của người chơi mất máu | `min_cells: 5`, `mult: 1.3`, `self_damage: 2` |
| `an_chu` | Ấn Chủ | boss | Thưởng hình chủ đạo ×2,0 thay vì ×1,5 | `featured_mult: 2.0` |
| `tam_hop` | Tam Hợp | boss | Được ghép mảnh thứ ba vào đòn (+1,5 s chọn lá nữa) | `max_join_pieces: 3` |

- [ ] **Thứ tự nhân sát thương** viết rõ trong `schema.md` và theo đúng trong mã: sát thương mỗi ô × số ô → hình chủ đạo → bảo vật (nhân với nhau) → nội tại → tuyệt kỹ → từ khóa (Rạn/Ghim). Tích hệ số của bảo vật bị kẹp bởi `relic_damage_mult_cap` (khởi điểm 3,0, trong `relics.json`). Test: `an_don` + Sát thủ (`quick_blade`) trên địch bị Rạn cho đúng con số tính tay.
- [ ] Mặc định không trùng: đã có thì không được đưa ra lại (trừ tag `stackable`; 16 món khởi điểm đều không `stackable`).

**Phần C — Móc vào trận và vào run**

- [ ] `RunSession` giữ `relics: Array[String]` (thứ tự nhận), API `add_relic(id) -> bool` (từ chối trùng / id lạ), `has_relic(id)`, `relic_ids()`. Lưu trong `to_dict()` khóa `relics`, `from_dict()` bỏ id lạ có cảnh báo; save cũ thiếu khóa = không có bảo vật (không crash). Nếu Story 031 chưa nâng version save thì nâng ở đây.
- [ ] `CombatView` tạo bảo vật ở cùng chỗ tạo nội tại/tuyệt kỹ (`_setup_passive`, `_setup_signature`) qua một hàm `_setup_relics(relic_ids)`; `config_overrides()` của mọi món gộp vào cấu hình trận **trước** khi `FieldDrops`, túi mảnh, `FormationMap`, `StatusEffects` được tạo; `teardown()` gọi ở cùng chỗ teardown nội tại. Không bảo vật nào sửa file JSON hay trạng thái run giữa trận (trừ máu qua API của `CombatState`).
- [ ] Móc sát thương và thời gian niệm đi qua **một** điểm cho mỗi loại (cạnh `player_signature_modifier` của arbiter / `CutEffects.apply`), không rải điều kiện bảo vật vào nhiều file.
- [ ] Nguồn nhận trong story này: nút **kho báu** đưa ra "chọn 1 trong 3 lá" **hoặc** "chọn 1 trong 3 bảo vật" (một màn, hai hàng; chọn một hàng), theo `source_rules.treasure`. API `RelicRoller.roll(source, owned, rng)` seeded, xác định, dùng chung cho Story 033 (cửa hàng/sự kiện) và 035 (Giết boss). Boss không có bảo vật.

**Phần D — HUD và chạm (mobile ngang, ngón cái)**

- [ ] Bản đồ, màn thưởng, màn tạm dừng: dải biểu tượng bảo vật (vẽ bằng code: ký tự + viền màu độ hiếm, tag `negative` viền đỏ). Chạm một biểu tượng → thẻ mô tả (tên, độ hiếm, luật, số); chạm ra ngoài để đóng. Vùng chạm mỗi biểu tượng ≥ 48 dp; quá 8 món thì cuộn ngang bằng kéo.
- [ ] Trong trận: dải nhỏ ở mép trên, **xa** d-pad và túi mảnh, **chỉ hiển thị** (không nhận chạm, tránh chạm nhầm); món nào kích hoạt (ví dụ `an_don` nhân đòn, `chi_khau` hồi, `phan_don` cho mảnh) thì biểu tượng nháy sáng 0,4 s.
- [ ] Màn chọn bảo vật ở kho báu: 3 thẻ lớn giữa màn, chạm chọn rồi nút xác nhận góc dưới phải; "Bỏ qua" góc dưới trái.
- [ ] `tui_rong`: giao diện túi vẽ đủ 4 ô không chồng d-pad ở bố cục ngang (kiểm trên cả tỉ lệ 16:9 và 20:9).

**Phần E — Kiểm chứng**

- [ ] Test (`tests/unit/relics/`): registry (id lạ, tạo đúng lớp); `ConfigModRelic` áp `mul`/`add` đúng; từng món trong bảng đổi đúng luật trong một trận dựng sẵn; kẹp `relic_damage_mult_cap`; `chi_khau` dừng hồi ở `max_heal_per_match`; `khoi_the` chỉ áp cho phép đầu; `tam_hop` cho mảnh thứ ba và không cho thứ tư; `RelicRoller` xác định theo seed và không đưa món trùng; save/load giữ bảo vật, bỏ id lạ.
- [ ] **Mô phỏng**: `tools/balance/deck_sim.gd` thêm `--relics=id,...` (bot có sẵn các món đó từ đầu) và `--relic-policy=pick` (bot nhặt bảo vật ở kho báu theo quy tắc đơn giản: hiếm hơn trước). Đo tỉ lệ thắng run/vùng cho mỗi món **đứng một mình** so với không bảo vật, 70 seed × 3 nhân vật. Không món nào làm tỉ lệ thắng tăng **quá 12 điểm** (khởi điểm); không món common/rare nào làm giảm quá 3 điểm (món vô dụng). Đo thêm 3 cặp nghi cộng dồn: `an_don`+`phan_don`, `tui_rong`+`tam_hop`, `la_ban`+`tam_huong`. Bảng trước/sau trong Completion Notes và `production/qa/evidence/relics/simulation-relics.md`; chỉnh số trong `relics.json` nếu vượt ngưỡng.
- [ ] Ảnh trong `production/qa/evidence/relics/`: dải bảo vật trên bản đồ (vi), thẻ mô tả mở (vi và en), màn chọn bảo vật ở kho báu (vi và en), dải trong trận khi một món nháy sáng, túi 4 ô với `tui_rong`.
- [ ] Không hằng số gameplay trong mã (fallback chỉ ở một bảng `DEFAULTS` như `RunSession.CONFIG_DEFAULTS`); chuỗi mới có vi và en.

---

## Implementation Notes

- Mẫu registry: `src/passives/passive_registry.gd`, `src/traits/trait_registry.gd`; mẫu vòng đời: `BasePassive` (`setup`, `on_match_start`, `modify_damage`, `modify_swing_duration`, `teardown`).
- Điểm nối: `src/combat/combat_view.gd` (`_setup_passive`, `_setup_signature`, `_wire_zones`, tạo `FieldDrops` ở dòng khởi tạo), `src/combat/cut_effects.gd` (`apply`, `_apply_keywords`, `_apply_featured_effect`), `src/combat/formation_map.gd` (thời gian phai), `src/drops/field_drops.gd` (`interval_scale`, `start_pieces`), `hold_slots.json` (số ô túi), `combat.json` `zones`.
- Chỗ nào đang đọc số trực tiếp từ config (ví dụ `seal_sec` theo lá ở Story 027) thì áp override **sau** số theo lá, không thay nó.
- `--demo=relic_strip|relic_tooltip|relic_treasure|relic_bag4` cho chụp ảnh.
- Schema `app{trigger, effect, amount…}` chung của OSFE (khuyến nghị "Hợp nhất schema hiệu ứng" trong `osfe-reference.md`) **không** làm ở đây; registry + params là bước trung gian.

---

## Out of Scope

- Cửa hàng, sự kiện, giá (Story 033); bảo vật Giết boss và Tha/Giết (Story 035); mở khóa bảo vật theo cột mốc (story chơi lại); bảo vật cho boss/địch; bảo vật theo nhân vật; bảo vật chủ động (bấm dùng); bán bảo vật.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/relics/` (màn mới có bản vi và en); `simulation-relics.md` + raw.

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 031 (bản đồ thế giới v6: tầng, vùng, nút kho báu, save run v6)
- Unlocks: Story 033 (cửa hàng/sự kiện bán và trao bảo vật), Story 035 (Giết boss trao bảo vật tier `boss`)
