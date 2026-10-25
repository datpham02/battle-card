# Story 032: Bảo vật — đồ bị động đổi luật gắn với mảnh, ghép, trận đồ, vùng và từ khóa; mang theo cả run

> **Epic**: Kaiten Duel (v6)
> **Status**: Complete
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

**Status**: Created — production/qa/evidence/relics/ (01-09 screenshots, simulation-relics.md + raw)

---

## Dependencies

- Depends on: Story 031 (bản đồ thế giới v6: tầng, vùng, nút kho báu, save run v6)
- Unlocks: Story 033 (cửa hàng/sự kiện bán và trao bảo vật), Story 035 (Giết boss trao bảo vật tier `boss`)

---

## Completion Notes
**Completed**: 2026-10-25
**Criteria**: 16/16 pass, 0 failing; five pass with notes (B1 two relics changed after the simulation, B2 the damage order differs from the story text, D1 no screenshot of the pause-screen strip, E2 part of the relics cannot be measured by the bot, and the pair an_don + phan_don sits just above the target). DEFERRED (needs real play): how appealing each relic is against a card at a treasure node, whether the one-letter icons read, the real run effect of the relics (bot dodge 0.85 is the TD-006 default). New suites not mutation-checked.
**What changed**: `assets/data/relics.json` (16 relics, `rarity_weights` 60/30/10, `source_rules`, `relic_damage_mult_cap` 3.0) with the section in `schema.md`; `src/relics/` (`RelicRegistry`, `BaseRelic`, `ConfigModRelic`, `RelicConfig`, `RelicRoller`, one script per conditional relic); `RunSession.relics` and `pending_relic_offer` in the run save; treasure node = ONE screen with a card row OR a relic row (either choice, or skip, closes both; resume reopens both); `CombatView._setup_relics` builds the relics before drops, bag, focus, status, formation exist and merges the config overrides once (player side only; seal seconds and thorn Ran are applied after the card's own value); ONE damage point (`SwingArbiter.player_relic_modifier` → `CutEffects.apply`, after the featured step, product capped) and ONE windup point (`CutActor.cast_time_modifier`); `on_cast_landed`, `on_join`, `on_interrupt_by_player`; join limit from `tam_hop` (3 pieces, `join_extra_sec` again); `an_chu` featured multiplier; `HoldSlots` and `HoldSlotsView` take a slot count (`tui_rong` = 4); `RelicStrip` (interactive on the map, world map, pause screen with a tooltip card and horizontal scroll; display-only in matches with a 0.4 s flash); treasure screen with two rows; dev flags `--relics=`, `--run=relic_treasure`; `deck_sim --relics= / --relic-policy=pick / --relic-set=`.
**Damage order as implemented**: card damage per cell x cells x card conditions -> Ghim -> Ran -> featured shape -> relics (product capped by `relic_damage_mult_cap`) -> execute -> passive -> signature -> flat defense. Story text had "featured -> relics -> passive -> signature -> keywords"; every step before flat defense is a multiplication, so the number is the same, and the existing steps were not moved (that would risk the balance). Proven through the real `CutEffects.apply`: `an_don` + Sat thu (`quick_blade`) on a Ran target = 7 x 1.5 x 2 x 1.25 = 26.25.
**Simulation** (`deck_sim --world`, 70 seeds x 3 characters, build policy, bot dodge 0.85 = TD-006 default; baseline run win Kiem si / Phap su / Sat thu 30.0 / 18.6 / 5.7 %; the baseline of Kiem si is 23.8 % at 210 seeds, so single-character cells have about +-7 points of noise, the 3-character mean about +-4): relic alone, mean change over the three characters: an_don +4.3, chi_khau +0.9, phong_an +1.4, gai_ran 0.0 (inert), manh_tuoi +8.1 (Phap su +25.7), dinh_tam 0.0 (inert), la_ban +4.3, tam_huong -1.4, tui_rong -16.2, dau_than 0.0 (inert), khoi_the +4.8, phan_don +6.2 (Kiem si +14.3 at 70 seeds, +10.5 at 210), han_ky +2.9, huyet_an -17.6, an_chu +0.9, tam_hop +1.9. Pairs: an_don + phan_don +12.4, tui_rong + tam_hop -16.2, la_ban + tam_huong +3.3. `--relic-policy=pick`: -0.0 (the rarest-first bot takes the negative Huyet An in 16-21 of 70 runs). Diagnosis: the world run is piece-supply bound (a 25 % slower drop costs 10-27 points; one extra start piece is worth +16 for Phap su). Applied: `tui_rong` lost `piece_spawn_interval x1.25`; `manh_tuoi` lost `start_pieces +1`. Re-measured with shipped data, run win Kiem si / Phap su / Sat thu: tui_rong 28.6 / 18.6 / 5.7 (mean -0.5), manh_tuoi 20.0 / 22.9 / 5.7 (mean -1.9). Tables: `production/qa/evidence/relics/simulation-relics.md` and `-raw.txt`.
**Deviations**: ADVISORY (TD-028): `tui_rong` has no drawback any more and `manh_tuoi` no start piece (data changed from the story table after the simulation; the user did not approve that separately; a different drawback for `tui_rong` is a design question). ADVISORY: damage order differs from the story text (see above). ADVISORY (TD-028): the simulation cannot measure `gai_ran`, `dinh_tam`, `dau_than` (results identical to baseline: the bot hardly uses thorns, burn, or runs out of Focus), nor `an_chu` and `tam_hop` (the bot rarely fits a featured union or a third piece); `manh_tuoi` stays -10 for Kiem si (about 1.5 SE, repeats the -7 of the full relic, cause not verified); `an_don` + `phan_don` +12.4 on the mean, a little over the 12-point target (the pair is driven by the free pieces of `phan_don`; lowering `an_don` to x1.6 only gives +11.9); `huyet_an` (epic, negative) is a trap at -17.6 (the x1.3 part is worth nothing to the bot and even 1 HP per cast sinks it; outside the story's thresholds, which cover common and rare only; no change made, proposal in the evidence file). ADVISORY (TD-028): icons are the first letter of the name, so An Don and An Chu both read "A"; the numbers in the rule text are written into the strings, so changing `relics.json` needs the strings changed too; the pause-screen strip has no screenshot (no dev flag for a paused state) and the strip has no keyboard or gamepad focus; `--relics=` applies only to a new run, and the single-match DemoArgs path (`--match=` / `--demo=`) does not pass relics into the match (shots 06 to 08 use their own demo flags); `RelicRegistry.has_id` checks script ids, not relic ids (a naming trap). ADVISORY: the map tiles shrank from 172 to 148 px to make room for the strip, so older map evidence differs. Scope: touched beyond the story text: `hold_slots.gd`, `hold_slots_view.gd`, `cut_actor.gd`, `run_controller.gd`, `screen_layout.gd`, `reward_view.gd`, `run_hud_view.gd`, `world_map_view.gd`, `chapter_map_view.gd`, `cut_hud_view.gd`, `tools/balance/*`, `tests/unit/relics/relic_registry_test.gd` and `src/ui/relic_strip.gd` (an i18n constant renamed after `i18n_test` failed).
**Test Evidence**: Integration; tests waived at `qa.level: minimal` but present and run on the final code: new suites `tests/unit/relics/{relic_registry,relic_conditional,relic_roller,relic_strings,relic_combat}_test.gd` (`relic_combat_test` 49 checks) and `tests/unit/run/run_session_relics_test.gd` (48); parse-check 170/170; 57 headless and 4 windowed suites all FAILS=0 with 0 SCRIPT ERROR (two suites failed in the last sweep, `i18n_test` and `relic_registry_test`, and were fixed and re-run); `main.tscn` launched windowed with `--quit-after 300`, 0 error lines. Retained screenshots `production/qa/evidence/relics/01-09*.png` (all opened and checked) plus `simulation-relics.md` and `simulation-relics-raw.txt`.
**Code Review**: Skipped (solo mode).
**Not verified**: feel on a phone, the relics against a human, the three inert relics and the two the bot cannot use, the pause-screen strip on screen.
**Carries forward**: gate 8 playtest (first real 5-floor run with relics on a phone: run length, region choice, relic against card at a treasure node, HP sawtooth, anchor the bot dodge TD-006); Story 033 (gold, shop, events: shops sell relics through `RelicRoller`) and Story 035 (Giet boss gives a `boss` tier relic); TD-001..006, 008..016, 018, 020, 021, 023..028.
