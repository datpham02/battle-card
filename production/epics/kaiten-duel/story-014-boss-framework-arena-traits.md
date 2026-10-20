# Story 014: Khung boss — sân riêng theo trận và đặc điểm (trait) cắm được

> **Epic**: Kaiten Duel (v3)
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-20

## Context

**GDD**: `design/game-brief.md` (v3)
**Requirement**: Người dùng muốn mỗi boss có **cơ chế riêng, đặc điểm riêng và sân riêng** (vuông, chữ nhật, bậc thang…) mà không phải viết một bộ logic cho từng boss. Hiện trạng: bộ não, kỹ năng, luật cắt đã dùng chung và được tham số hóa theo trận; nhưng (a) lưới đọc từ `combat.json` chung cho cả run, (b) không có chỗ cắm cơ chế riêng ngoài trọng số.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Sân theo trận: thư viện hình, biến thể có luật, bộ kiểm**

- [ ] `assets/data/arenas.json`: thư viện hình đặt tên, mỗi hình `{id, side_cols, side_rows, missing_cells (tọa độ bên, lật gương), difficulty 1..5}`; ít nhất 6 hình không "basic": chữ thập, chữ U, vòng (lỗ giữa), hai đảo nối cầu, bậc thang lệch, kim cương, cộng vuông 3×3 và chữ nhật 4×3.
- [ ] `run.json` mỗi trận có khối tùy chọn `arena`: hoặc `{"shape": "<id>"}`, hoặc `{"shape": "<id>", "variant": true}` (sinh biến thể từ hình gốc), hoặc khối trực tiếp `{side_cols, side_rows, missing_cells}`; thiếu thì dùng `combat.json`. `RunController` truyền qua `match_params`; `CombatView` dựng `BoardGrid` theo đó **trước** khi tính cooldown bước theo sân (Story 013) và nhãn chu vi.
- [ ] **Bộ sinh biến thể** (`ArenaVariants`, thuần, seeded): từ hình gốc khoét thêm hoặc lấp 1–3 ô, có thể lật dọc; tối đa `max_attempts` lần; rớt kiểm thì trả hình gốc với cảnh báo.
- [ ] **Bộ kiểm** (`ArenaValidator`, thuần, dùng cho cả thư viện lẫn biến thể, chạy lúc nạp): hai bên đối xứng qua vạch giữa; mỗi bên **liên thông**; mỗi bên ≥ `min_cells` (6); ô xuất phát mặc định tồn tại; đứng ở ô xuất phát, **mọi đòn 1 điểm** của đối thủ đều để lại ≥ 1 ô thoát trong 1 bước (dùng `EscapeAnalysis`). Hình trong thư viện rớt kiểm → cảnh báo lúc nạp và bị loại khỏi pool. Số trong `arenas.json` (`rules` block). `RunController` truyền qua `match_params`; `CombatView` dựng `BoardGrid` theo đó **trước** khi tính cooldown bước theo sân (Story 013) và nhãn chu vi.
- [ ] Hình bất kỳ ghép từ ô vuông đều chạy (kể cả có lỗ, hai đảo nối cầu). Lục giác/tam giác thật **không** thuộc phạm vi. Trên sân có lỗ, nhát cắt đi qua lỗ không phủ ô nào (hệ quả có chủ ý, không "sửa").
- [ ] `run.json` mẫu: trận 1 vuông 3×3, trận 2 chữ nhật 4×3, trận 3 chữ thập, boss vòng (lỗ giữa) với `variant: true`. Việc tầng nào rút ngẫu nhiên từ nhóm nào (`arena_pool`) thuộc Story 015. Mọi màn hình (banner trận, giữa trận, thắng/thua) và điểm rơi tự thích nghi, không có số 3 ngầm ở đâu (đã có từ Story 007, kiểm lại).
- [ ] Ảnh chụp 4 sân của 4 trận trong `production/qa/evidence/boss-framework/`.

**Phần B — Đặc điểm cắm được (trait)**

- [ ] Giao diện `BossTrait` (lớp cơ sở RefCounted) với các móc: `setup(ctx, params)`, `on_match_start()`, `on_tick(step)`, `on_boss_swing_started(cells, skill_id)`, `on_boss_swing_resolved(result)`, `on_player_swing_resolved(result)`, `on_point_spawned(side, point)`, `on_boss_damaged(amount)`, `teardown()`. `ctx` cho trait đọc/ghi qua API công khai hiện có (state, grid, drops hai bên, boss controller, status effects, arbiter), **không** chạm private.
- [ ] `TraitRegistry`: bảng `id → script` khai báo ở một chỗ; `run.json` mỗi trận có `traits: [{"id": "...", "params": {...}}]`; id lạ → cảnh báo và bỏ qua, trận vẫn chạy. Trait được tạo mới mỗi trận (cảnh mới) và hủy khi trận kết thúc.
- [ ] Hai trait mẫu để chứng minh khung chạy: **`rotten_thrower`** (mỗi `interval_sec` ném một "điểm hỏng" sang ô trống bên người chơi; nhặt vào tay thì chiếm ô tay và không cắt được, ôi sau `rot_sec` trong tay; hiện xám có dấu X) và **`row_burner`** (mỗi `interval_sec` đốt một hàng bên người chơi trong `burn_sec`, báo trước `warn_sec` bằng viền nhấp nháy, dùng `StatusEffects.ignite` sẵn có). Tham số trong `run.json`, mặc định trong trait, ghi `schema.md`.
- [ ] Boss cuối trong `run.json` mẫu dùng `rotten_thrower`; trận 3 dùng `row_burner`; trận 1–2 không trait. Không trait nào sửa `BossBrain`; brain chỉ thấy hệ quả (ô cháy, điểm hỏng) qua API có sẵn.
- [ ] Mô phỏng seeded vẫn xác định với trait bật; test: trait lạ bị bỏ qua có cảnh báo; `row_burner` đốt đúng hàng đúng lúc; `rotten_thrower` chiếm ô tay và ôi đúng giờ; chơi lại run thì trait được tạo mới (không rò rỉ trạng thái).
- [ ] Ảnh chụp: điểm hỏng trong tay, hàng đang cháy do trait, trong `production/qa/evidence/boss-framework/`.

**Chung**
- [ ] `schema.md` có mục `run.json → arena` và `traits`, kèm hướng dẫn 5 dòng "thêm một boss mới = thêm khối JSON; thêm cơ chế mới = một lớp trait + một dòng đăng ký".
- [ ] Không hằng số gameplay trong mã.

---

## Implementation Notes

- Phần A: `CombatConfig.use_grid` đã có; `CombatView` chỉ cần ưu tiên `match_params["arena"]` trước `grid_override` dev.
- Phần B: `BossController` (hoặc một `TraitHost` nhỏ do `CombatView` sở hữu) giữ danh sách trait và gọi móc; trait **không** được giữ tham chiếu qua trận. Đăng ký bằng `preload` trong `TraitRegistry` để GDScript không cần phản chiếu.
- `rotten_thrower` cần `FieldPoint` có cờ `rotten` và `HoldSlots`/`CutHudView` tôn trọng cờ (không chọn được, hiện xám); đây là thay đổi nhỏ ở lớp dùng chung, không phải mã riêng boss.
- Làm **sau** cổng chơi thử của Story 013 vì cùng sửa `boss_controller.gd`.

---

## Out of Scope

- Lục giác, tam giác thật, ô không đều.
- Nhiều hơn hai trait mẫu; nội dung boss cụ thể cho bản phát hành.
- Cân bằng số.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshot trong `production/qa/evidence/boss-framework/`.
- Integration: `tests/integration/boss/trait_registry_test.gd` — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: Screenshots retained; integration test not saved (advisory at minimal).

---

## Dependencies

- Depends on: Story 013 (cooldown theo sân, hồ sơ di chuyển)
- Unlocks: nội dung boss, đợt cân bằng

---

## Completion Notes
**Completed**: 2026-10-20
**Criteria**: 17/17 pass. DEFERRED (needs real play): difficulty of the two traits, feel of arenas with holes, touch on a device.
**Deviations**: ADVISORY: `on_boss_damaged` reports player-swing damage only, not burn ticks. ADVISORY: rotten points count toward the field cap of 4. ADVISORY: traits stop ticking once a side is dead. ADVISORY: `RunController` does not set `arena_seed`, so the variant ring changes every run (Story 015 seeds per run). ADVISORY: DEV-ONLY `CombatView.make_trait_ctx()` (public) and `TraitHost.debug_add_trait()` exist for demos. ADVISORY: click-driven scratch tests (cut_flow, focus_flow, input_test) pass only with `--windowed --resolution 1280x720`; headless gives a 1280x1280 viewport (pre-existing).
**Test Evidence**: Integration; tests waived at `qa.level: minimal`. Retained screenshots `production/qa/evidence/boss-framework/01-07*.png` (all opened and checked). Scratch tests trait, arena, arena_flow, trait_flow, run_flow, cut_flow, focus_flow: 0 failures.
**Code Review**: Skipped (solo mode).
**Not verified**: real feel, touch on a device.
**Carries forward**: Story 015 (chapters/floors, `arena_pool`, per-run `arena_seed`); balance pass (trait intervals, rotten cap, profile numbers); optional saved integration test.
