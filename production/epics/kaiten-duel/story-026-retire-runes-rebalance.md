# Story 026: Gỡ hệ nối ấn, chuyển test và mô phỏng sang mảnh, đo lại cân bằng ba chương

> **Epic**: Kaiten Duel (v5)
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-24

## Context

**GDD**: `design/game-brief.md` (v5)
**Requirement**: Sau Story 024–025 không bên nào còn nối ấn, nhưng code nhãn chu vi, túi ấn, đường nối và các test cũ vẫn còn. Số cân bằng ba chương (Story 023) được đo với bot nối ấn nên không còn đúng: mảnh cho vùng rẻ hơn nhiều (mỗi lần nhặt một vùng) và boss đứng yên khi niệm. Story này dọn hệ cũ và đo lại để có con số mới trước khi người dùng chơi run đầy đủ.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM (xóa code; cân bằng chỉ chỉnh dữ liệu)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Gỡ hệ nối ấn**

- [ ] Xóa code chỉ phục vụ nối ấn và không còn ai gọi: `CutResolver` (nhãn → ô), `BoardGrid.perimeter_labels`, túi nhãn trong `FieldDrops`, vẽ nhãn và đường nối trong `cut_hud_view.gd`, khóa `hand_max_points` / `single_point_opens_menu` trong `cuts.json`, chuỗi `TEXT_*` không còn dùng. Mỗi xóa kiểm bằng tìm tham chiếu trước; gì còn người gọi thì giữ và ghi lý do.
- [ ] Gỡ cùng lượt phần thừa của mô hình tầng cũ (TD-007) nếu không đụng mảnh: `ChaptersConfig` floor API, `RunConfig.from_floor`, shim `floor_index`/`match_index`, `legacy_floors`, các no-op trong `GameFlow`.
- [ ] `schema.md` khớp dữ liệu sau khi gỡ.

**Phần B — Test**

- [ ] Suite trong `tests/` chuyển hết sang mảnh: suite chỉ kiểm nối ấn (ví dụ `cut_test` phần nhãn) thì viết lại theo `PiecePlacement` hoặc xóa có ghi lý do trong `tests/README.md`.
- [ ] Hai suite hỏng sẵn (TD-011: `pace_test`, `run_state_test`) cập nhật theo mô hình hiện tại hoặc gỡ như `floor_flow_test`; TD-011 đóng.
- [ ] Toàn bộ suite chạy xanh theo lệnh trong `tests/README.md` (headless và windowed); cập nhật danh sách "known failing" về rỗng.

**Phần C — Mô phỏng và cân bằng**

- [ ] `deck_sim.gd` chuyển bot sang mảnh: nhặt mảnh, chọn (mảnh, vị trí, hướng xoay) phủ ô boss và ô kề, phản công khi boss niệm, Tập trung khi sẵn. **Neo lại tỉ lệ né của bot** (TD-006): dùng ước lượng từ lần chơi thử của người dùng nếu có, không thì ghi giả định trong Completion Notes.
- [ ] Đo 70 seed × 3 nhân vật × chương 1–3 (chính sách build). Mục tiêu giữ như Story 023: **ch1 40–60 %, ch2 25–45 %, ch3 15–35 %**, 15–30 đòn boss trúng mỗi run thắng; khoảng cách giữa ba nhân vật theo tỉ lệ tương đối (TD-008, không cần bằng nhau). Không đạt thì chỉnh **dữ liệu** (nhịp và trọng số mảnh, máu boss, `boss_step_cooldown_mult`, `min_cells`), không chỉnh mã. TD-001, TD-004, TD-006, TD-009 đo lại và đóng hoặc cập nhật.
- [ ] Bảng số vào Completion Notes và `production/qa/evidence/pieces-balance/simulation-70seeds.md` (kèm `*-raw.txt`).

**Phần D — Kiểm chứng**

- [ ] Parse-check toàn bộ `src/` và `tests/` sạch.
- [ ] Ảnh trong `production/qa/evidence/pieces-balance/`: một trận mỗi chương sau cân bằng (giữa trận, có mảnh trên sân và đòn đang niệm); màn thưởng có lá đã đổi `min_cells`.

---

## Implementation Notes

- Làm Phần A theo từng nhóm file, chạy parse-check và suite sau mỗi nhóm; không xóa file nào chưa kiểm tham chiếu.
- `hit_probe.gd` (scratch) cập nhật cùng `deck_sim.gd` để giữ được phép đo tỉ lệ trúng.

---

## Out of Scope

- Kết giới / Trận gai (Story 027). Thay runner test bằng gdUnit4 và CI (TD-010). Nội dung mới.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Bảng mô phỏng ba chương; retained screenshots trong `production/qa/evidence/pieces-balance/`.

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 024, Story 025
- Unlocks: Story 027, cổng chơi thử run đầy đủ với mảnh
