# Story 035: Tha hay Giết boss vùng, boss cuối Ấn Đài, ba kết thúc và thống kê run

> **Epic**: Kaiten Duel (v6)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md` (v6, mục "Run v6 — mô hình OSFE" → "Tha hay Giết", "Chơi lại"), `design/reference/osfe-reference.md` (§5.2 boss dùng lá người chơi, `BossHealShot`; §9.3 `ZoneType` Pacifist / Normal / Genocide)
**Requirement**: Sau Story 031 run có 5 boss vùng và một trận cuối tạm (boss chương 3 tăng cấp). Người dùng chốt: hạ boss vùng xong chọn **Giết** (nhận ngay một bảo vật mạnh) hay **Tha** (không nhận gì ngay, mở nội dung về sau qua Story 037); tổng Tha/Giết quyết định **một trong ba kết thúc** ở Ấn Đài. Story này thêm lựa chọn đó, boss cuối Ấn Đài thật, màn kết thúc và thống kê run. Lựa chọn là một quyết định đạo đức có giá (Tha = bỏ sức mạnh ngay để lấy thứ khác về lâu dài), không phải nút bấm cho có.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM (boss mới có hai pha; một màn chọn không đảo ngược phải chịu được thoát app giữa chừng)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Tha hay Giết**

- [ ] Khi máu boss vùng về 0, boss **quỵ** (không biến mất, không đánh, mảnh của nó trên sân tan, mọi vùng/cháy của nó dừng); trận dừng; mở màn **Tha / Giết** trước màn thưởng lá. Áp cho nút `boss` của vùng, không cho miniboss, trận thường hay trận cuối.
- [ ] **Giết**: chọn 1 trong `execute_artifact_offers` (khởi điểm 3) bảo vật, độ hiếm tối thiểu `execute_min_rarity` (khởi điểm `rare`) từ pool bảo vật của Story 032 (`RewardRoller` hoặc lớp bảo vật của 032; luck run áp như lá). Được bỏ qua (không lấy) nhưng vẫn tính là Giết.
- [ ] **Tha**: không nhận gì ngay. Cả hai lựa chọn vẫn nhận thưởng boss của Story 022/031 (3 lá + 1 token bỏ lá) sau màn này — Tha/Giết chỉ thêm hoặc không thêm bảo vật.
- [ ] `RunSession` ghi `boss_fates`: mỗi phần tử `{floor, region_id, match_id, fate: "spare"|"execute"}`; `pending_fate` = true từ lúc boss quỵ tới lúc chọn xong. Save v6 (tăng `SAVE_VERSION`; v5 nạp được với `boss_fates` rỗng): thoát app ở màn Tha/Giết rồi *Tiếp tục* → về đúng màn đó, không chơi lại trận, không mất lựa chọn.
- [ ] `ProgressState` (tăng version, file cũ nạp được): `spared_bosses` (tập id boss từng tha), `executed_bosses`, `spare_total`, `execute_total`, `endings_seen`. Story 037 đọc các khóa này làm cột mốc; story này chỉ ghi.

**Phần B — Trận cuối Ấn Đài (boss mới)**

- [ ] Trận cuối là một match mới trong vùng riêng `an_dai` (khối `chapters` mới, **không** vào `world.region_pool`): id khởi điểm `an_dai_keeper`, `name_key`/`desc_key` vi/en (tên và lời thoại thật do narrative-director cung cấp; tạm dùng khóa có chữ giữ chỗ), `world.final_match` trỏ tới nó thay `mist_lord`. Hệ số `floor_scaling.final` của Story 031 vẫn áp.
- [ ] **Sân riêng**: một hình mới trong `arenas.json` (ví dụ bệ tròn có lỗ giữa) có `featured_shape` 5–7 ô và qua `ArenaValidator`; ghép được hình chủ đạo từ ≥ 2 cặp mảnh (luật Story 028).
- [ ] **Hai pha** (dữ liệu `phases` trên match, đọc qua `RunConfig`): pha 1 từ đầu; pha 2 khi máu ≤ `at_hp_ratio` (khởi điểm 0,5). Mỗi pha khai báo `traits`, `brain_set`, `boss_step_cooldown_mult`, `boss_cards`, `root_while_swinging`. Chuyển pha: boss bất khả xâm phạm `phase_shift_sec` (khởi điểm 1,0 s), đòn đang niệm của nó bị hủy, banner tên pha, trận đồ người chơi **giữ nguyên**. Khởi điểm: pha 1 dùng `seal_caster` + bộ phép cân bằng; pha 2 thêm `thorn_field` + `row_burner`, `brain_set` `aggressive`.
- [ ] Hồ sơ não mới `final` trong `boss_brain.json` nếu cần (trọng số ghi vào `schema.md`); nếu dùng lại bộ có sẵn thì ghi lý do ở Completion Notes.
- [ ] Trận cuối **không** có màn Tha/Giết; thắng → màn kết thúc (Phần C).

**Phần C — Ba kết thúc**

- [ ] Kết thúc chọn theo `boss_fates` của run, luật trong `chapters.json → world.endings` (khởi điểm): `spare` khi **mọi** boss vùng đã gặp đều được tha; `execute` khi **mọi** boss đều bị giết; `balance` (lưng chừng) còn lại. Một run 5 tầng luôn có 5 lựa chọn; nếu sau này số tầng đổi, luật vẫn tính theo tỉ lệ (`spare_ratio` = 1 / = 0 / giữa).
- [ ] **Màn kết thúc** (`EndingView` mới, vẽ bằng code): tiêu đề kết thúc, 3–5 dòng chữ (khóa `ending.<id>.title`, `ending.<id>.line1..N`, vi và en; chữ thật do narrative-director, tạm chữ giữ chỗ), rồi thống kê run (Phần D), rồi nút **Về màn chính** lớn ở nửa dưới. Chữ hiện từng dòng, chạm bất kỳ đâu để hiện hết ngay (không bắt chờ). `endings_seen` cập nhật.

**Phần D — Thống kê run**

- [ ] `RunSession` đếm (lưu trong save): thời gian chơi, nhân vật, đường vùng, tầng tới được, số trận thắng, sát thương gây ra / nhận, số đòn trúng nhận, số đòn ghép và đòn hình chủ đạo, số lần dùng tuyệt kỹ, số lá cuối và lá cấp cao nhất, bảo vật đã có, Tha/Giết theo boss. Hiện trên màn kết thúc **và** màn thua (thay màn RUN KẾT THÚC hiện có: thêm tầng/vùng nơi chết và boss giết mình).
- [ ] Bố cục thống kê đọc được trên màn ngang điện thoại: hai cột, chữ ≥ cỡ `SMALL_FONT_SIZE` hiện có, không cần cuộn ở 1280×720 logic; nếu quá dài thì trang 2 bằng một chạm (nút ≥ 96 px).

**Phần E — Chạm**

- [ ] Màn Tha/Giết: hai nút lớn ở nửa dưới, **Tha** bên trái, **Giết** bên phải (mỗi ngón cái một nút), mỗi nút ≥ 35 % chiều rộng, có một dòng hệ quả ("Không nhận gì lúc này" / "Chọn 1 trong 3 bảo vật"). Vì không đảo ngược: **giữ để xác nhận** `fate_hold_sec` (khởi điểm 0,6 s) với vòng tiến độ quanh nút; nhả sớm thì hủy. Bàn phím/chuột chỉ là phụ (phím ←/→ + giữ Enter).
- [ ] Màn chọn bảo vật khi Giết dùng cùng bố cục thẻ chạm của `RewardView` (3 thẻ, chạm chọn, chạm lại xác nhận).

**Phần F — Kiểm chứng**

- [ ] Test mới `tests/unit/run/boss_fate_test.gd`: quỵ chỉ ở boss vùng; Giết mở offer bảo vật đúng số và sàn độ hiếm; Tha không cho gì nhưng vẫn có thưởng lá + token; `boss_fates` và `pending_fate` round-trip save; ProgressState cộng đúng và nạp file cũ; luật kết thúc ở 5/0, 0/5, 3/2, 1/4 (Tha/Giết).
- [ ] Test mới `tests/unit/combat/final_boss_phase_test.gd`: chuyển pha đúng ngưỡng một lần; bất khả xâm phạm đúng thời gian; đòn đang niệm của boss bị hủy; trait pha 2 bật, pha 1 tắt; sát thương vượt ngưỡng trong một đòn vẫn chuyển pha (không bỏ qua pha 2, máu kẹp ở ngưỡng).
- [ ] Chạy lại: các suite run/flow của Story 031, `reward_run_test`, `trait_test`, `arena_test`, `i18n` (quét khóa), parse-check.
- [ ] **Mô phỏng** (deck_sim `--world`, thêm `--fate=execute|spare|alternate`, 70 seed × 3 nhân vật, build): báo tỉ lệ thắng run theo chính sách fate, tỉ lệ thắng trận cuối khi đã tới, phân bố cái chết theo tầng. Mục tiêu khởi điểm: thắng trận cuối khi đã tới 35–55 %; trận cuối ≤ 40 % số lần chết; **Giết hết** hơn **Tha hết** 8–20 điểm thắng run (Giết phải đáng giá nhưng Tha không phải tự sát). Ngoài dải thì chỉnh dữ liệu (`execute_artifact_offers`, `execute_min_rarity`, máu/pha boss cuối), ghi ở Completion Notes.
- [ ] Ảnh trong `production/qa/evidence/spare-execute-endings/`: boss vùng quỵ + màn Tha/Giết (vi); nút đang giữ với vòng tiến độ (en); offer bảo vật sau Giết; sân Ấn Đài pha 1; banner chuyển pha 2; ba màn kết thúc (vi cho hai, en cho một); màn thua có thống kê mới; màn Tha/Giết sau khi *Tiếp tục* từ save.
- [ ] Không hằng số gameplay trong mã; chuỗi mới là khóa với vi và en.

---

## Implementation Notes

- File chạm: `src/run/run_session.gd` (fates, stats, save v6), `progress_state.gd`, `game_flow.gd` (bước `FATE` giữa thắng boss vùng và thưởng; cờ `--run=fate|ending_spare|ending_balance|ending_execute|final`), `reward_view.gd` (offer bảo vật), mới `src/run/fate_view.gd`, `src/run/ending_view.gd`, `run_hud_view.gd` (màn thua), `run_config.gd` (`phases`), lớp boss/`TraitHost` cho chuyển pha, `assets/data/chapters.json` (vùng `an_dai`, `world.endings`, `world.fate`), `arenas.json`, `boss_brain.json`, `schema.md`, `assets/i18n/strings.csv`. `src/dev/demo_args.gd`: `--demo=boss_downed`, `--demo=final_phase2`.
- Số Tha/Giết đặt trong `chapters.json → world.fate` (`execute_artifact_offers`, `execute_min_rarity`, `fate_hold_sec`) — một chỗ, ghi vào schema.
- Không làm biến thể trận cuối theo kết thúc ở story này. Người dùng (2026-10-25): **để sau** — ý tưởng "tuyến Giết hết gặp boss cuối mạnh hơn hoặc khác, như Genocide của OSFE" nằm trong backlog v6 của brief.

---

## Out of Scope

- Nội dung Tha mở ra (037), thành tựu (037), cấp Kiếp (038), biến thể trận cuối theo kết thúc, cắt cảnh/hình kết thúc (phase hình), lời thoại boss trong trận, hồi máu khi Tha.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/spare-execute-endings/` (danh sách Phần F); bảng mô phỏng theo chính sách fate `simulation-fate.md` + raw.

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 031 (thế giới 5 tầng, boss vùng, trận cuối tạm, save v5), Story 032 (bảo vật: pool, độ hiếm, offer)
- Unlocks: Story 037 (cột mốc Tha/Giết, kết thúc đã xem), Story 038 (cấp Kiếp cần trận cuối thật)
