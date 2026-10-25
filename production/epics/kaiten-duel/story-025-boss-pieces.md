# Story 025: Boss dùng mảnh ấn — chấm điểm vị trí và hướng xoay, boss đứng yên khi niệm, vòng hồi bước hiện khóa

> **Epic**: Kaiten Duel (v5)
> **Status**: In Progress
> **Layer**: Core
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md` (v5, mục "Core loop — mảnh ấn", "Boss")
**Requirement**: Sau Story 024 người chơi dùng mảnh còn boss vẫn nối ấn; hai bên phải cùng một hệ để luật đọc được (người chơi né đòn boss theo đúng hình mình cũng dùng). Cùng đợt bàn 2026-10-24, hai việc được chọn để có **cửa sổ phản công** dễ đọc: boss không bước khi đang niệm (hiện boss vừa niệm vừa bước được, `boss_controller.gd` không chặn) và vòng hồi bước của boss (mẹo "đánh ngay khi boss vừa bước" lên gần 100 % trúng với quái thường). **Đính chính 2026-10-25:** vòng hồi bước của boss ĐÃ có từ trước (`CombatView._draw_boss_ring`: cung đỏ mỏng quanh thân boss, đầy lúc vừa bước rồi cạn, ẩn khi sẵn sàng); nhận định ban đầu "hiện vô hình" là sai. Phần mới duy nhất là trạng thái **khóa khi đang niệm** và làm vòng dễ thấy hơn nếu ảnh chụp cho thấy nó mờ.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH (viết lại phần chọn đòn của não boss)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

> **Tạm dừng 2026-10-25** sau khi người dùng chốt Story 028–029: não boss viết một lần theo luật cuối. Bổ sung khi làm tiếp: boss được ghép **tối đa 2 mảnh** một đòn như người chơi (Story 028) và cộng điểm chấm `featured_bonus_weight` (mới, `boss_brain.json`) khi hợp ô trùng hình chủ đạo của trận. Phần đã làm dở trước khi tạm dừng (chưa kiểm): `boss_controller.gd`, `unit_mover.gd`, `boss_brain_config.gd`, `boss_brain.json` — dùng tiếp, kiểm lại trước khi viết thêm.

**Phần A — Boss nhặt và đặt mảnh**

- [ ] Boss nhặt mảnh trên đất mình bằng cùng hệ rơi mảnh của Story 024 (trọng số hình theo chương, nhịp nhân `boss_drop_interval_mult` như cũ), túi 3.
- [ ] Não boss chấm điểm **(mảnh, vị trí, hướng xoay)** trên đất người chơi thay cho tập nhãn: dùng lại trọng số hiện có (`cut_hit_now`, `cut_per_cell`, `cut_duration_penalty`, `escape_penalty`, `cut_interrupt_bonus`, `min_runes_penalty` đổi nghĩa thành số ô tối thiểu, …) và `EscapeAnalysis` để đếm ô thoát của người chơi trong thời gian niệm. Số ứng viên giới hạn (`max_placements_scored` trong `boss_brain.json`) để mỗi lượt nghĩ rẻ.
- [ ] `boss_min_runes` (Story 023) đổi nghĩa thành **số ô tối thiểu của mảnh** boss ưu tiên; tên khóa giữ nguyên để không vỡ `chapters.json`, ghi rõ trong `schema.md`.
- [ ] Đòn nối (combo), giả đòn (feint), học theo bộ đếm (`BossLearning`) chạy với mảnh như với nhãn.
- [ ] Trait `rotten_thrower` ném mảnh nguyền (Story 024) không đổi; `row_burner`, `slam`, `fuse_cannon`, `step_reactor`, `frost_aura`, `phase_shift` không phụ thuộc nhãn và chạy như cũ.

**Phần B — Cửa sổ phản công**

- [ ] **Boss đứng yên khi đang niệm**: cờ `boss_root_while_swinging` (mặc định `true` trong `boss_brain.json`, ghi đè theo trận trong `chapters.json`). Khi bật, não không chọn bước và `UnitMover` của boss từ chối bước trong lúc `actor.is_swinging()`; đòn bị hủy (phá phép, giả đòn) thì bước lại được ngay.
- [ ] **Vòng hồi bước của boss** (đã có, `_draw_boss_ring`) thêm trạng thái **khóa**: khi boss đang niệm và bị khóa bước thì vòng đổi sang màu riêng (đủ khác màu thường, nét liền); xem ảnh chụp và làm vòng dày/sáng hơn nếu nhìn khó thấy trên màn nhỏ. Không tạo vòng thứ hai.

**Phần C — Kiểm chứng**

- [ ] Test: vị trí boss chọn luôn hợp lệ trên đất người chơi (kể cả sân có lỗ); điểm chấm thích ứng (người chơi đứng góc → boss ưu tiên mảnh phủ góc và ô kề); `boss_min_runes` loại mảnh nhỏ hơn; boss không bước khi đang niệm lúc cờ bật và bước được khi cờ tắt; hủy đòn mở khóa bước; vòng đổi trạng thái khóa đúng lúc boss niệm và trở lại thường khi hết niệm.
- [ ] Suite `tests/unit/combat/` về não boss (`profiles`, `learning`, `arbiter`, …) cập nhật sang mảnh và chạy xanh; không suite nào đỏ thêm so với baseline sau Story 024.
- [ ] `hit_probe.gd` thêm chế độ **phản công** (đặt mảnh vào boss ngay khi boss bắt đầu niệm): báo tỉ lệ trúng 1–5 ô cho 11 địch chương 1 vào Completion Notes, kèm số đòn boss trúng người chơi khi người chơi đứng yên (để thấy boss mảnh mạnh hay yếu hơn boss nối ấn).
- [ ] Ảnh trong `production/qa/evidence/boss-pieces/`: boss đang niệm một mảnh trên đất người chơi; vòng hồi bước boss bình thường và khi khóa; người chơi phản công trúng boss đang niệm; boss ném mảnh nguyền.
- [ ] Không hằng số gameplay trong mã; chuỗi mới là khóa `TEXT_*` với vi và en.

---

## Implementation Notes

- Giữ nguyên giao diện `BossBrain.decide(ctx)` → `{type: "cut", cells, skill_id, …}` để `BossController._do_cut` và `SwingArbiter` không đổi; chỉ đổi cách sinh ứng viên (từ tập nhãn sang vị trí mảnh).
- Khóa bước khi niệm đặt ở **một** điểm (`UnitMover.blocked_fn` hoặc kiểm tra trong `BossController.tick` trước `try_step`), không rải trong não.
- `--demo=boss_placing|boss_rooted` cho chụp ảnh.

---

## Out of Scope

- Gỡ code nối ấn và chuyển `deck_sim` (Story 026). Kết giới / Trận gai (Story 027). Hiện ý định bước của boss, trợ giúp theo chương.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/boss-pieces/`.
- Bảng tỉ lệ trúng chế độ phản công trong Completion Notes.

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 024 (mảnh, rơi mảnh, `PiecePlacement`), **Story 028 (đòn 2 mảnh, hình chủ đạo), Story 029 (trận đồ)**, Story 013 (hồ sơ boss), Story 009 (não trọng số)
- Unlocks: Story 026, Story 027
