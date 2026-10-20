# Story 013: Hồ sơ boss theo trận và nhịp theo sân

> **Epic**: Kaiten Duel (v3)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-20

## Context

**GDD**: `design/game-brief.md` (v3)
**Requirement**: Phản hồi chơi thử sau Story 012: (a) boss di chuyển trông ngẫu nhiên, người chơi phải "đoán mò"; người dùng muốn **mỗi boss đi một kiểu, trận càng cao càng khó đoán**, và **không** muốn dấu hiệu/nhãn/"!" báo ý định; (b) né quá dễ vì vung (≥ 0,95 s) dài hơn hẳn bước (0,45 s) nên luôn có 2 bước thoát; muốn né phải **tính**; (c) cooldown bước phải **theo sân**: sân nhỏ cooldown dài, sân lớn ngắn.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần 1 — Hồ sơ di chuyển theo bộ não** (`boss_brain.json`, khối `movement` trong từng bộ trọng số; `run.json` đã gán bộ cho từng trận và được phép ghi đè khối `movement` theo trận):

- [ ] **Cam kết đích**: khi quyết định đi, brain chọn **ô đích** (điểm cần nhặt, ô an toàn khi né, hoặc cột lùi) và đi hết đường tới đó theo `path_style`; mỗi lần nghĩ lại chỉ đổi đích với xác suất `1 − move_commitment`, hoặc ngay lập tức khi đích mất nghĩa (điểm ôi/bị nhặt, ô đích cháy, đòn của người chơi sắp trúng ô đang đứng hoặc ô kế tiếp trên đường đi).
- [ ] `move_noise` tách khỏi nhiễu của đòn cắt; với `move_noise` = 0 và cùng tình huống, nước đi **luôn giống nhau** (hòa điểm phá theo luật cố định: giữ hàng hiện tại trước, rồi gần vạch giữa hơn).
- [ ] `reaction_sec` chuyển thành **theo bộ** (giá trị chung hiện tại làm mặc định).
- [ ] `path_style`: `row_first` (đi ngang hết rồi mới dọc), `shortest` (Manhattan, hòa thì theo luật cố định), `mixed` (mỗi đích chọn ngẫu nhiên một trong hai, seeded).
- [ ] `juke_chance`: sau khi né xong, xác suất bước thêm một ô theo hướng vuông góc (nếu ô tồn tại và an toàn).
- [ ] `wander_when_idle`: không có việc thì đứng yên (false) hay đi tới một ô ngẫu nhiên an toàn bên mình (true).
- [ ] Giá trị khởi điểm (chỉnh sau chơi thử): cautious = cam kết 1,0 / nhiễu 0 / phản ứng 0,6 / `row_first` / juke 0 / không lang thang; balanced = 0,7 / 0,15 / 0,35 / `shortest` / 0,2 / lang thang; aggressive = 0,5 / 0,3 / 0,25 / `mixed` / 0,4 / lang thang. Trận 2 ghi đè trong `run.json`: cam kết 0,9, nhiễu 0,05, phản ứng 0,45.
- [ ] **Không** vẽ đích, đường đi, nhãn ý định hay dấu "!" (quyết định người dùng).

**Phần 2 — Chấm điểm theo đường thoát** (`boss_brain.json`, trọng số theo bộ):

- [ ] Với mỗi đòn ứng viên, brain tính **số ô người chơi tới được trong thời gian vung** (số bước = floor(vung / cooldown bước của người chơi), BFS trên nửa sân người chơi, bỏ ô cháy) mà **nằm ngoài** vùng cắt → `escape_cells`. Điểm cộng `escape_penalty / (1 + escape_cells)` (số trong JSON); `cut_hit_now` giảm vai trò tương ứng.
- [ ] Test xác định: người chơi ở góc, boss cầm A1 + B1 (hoặc tổ hợp tương đương) phải chọn đòn để lại ít đường thoát hơn đòn chỉ "trúng ngay"; người chơi ở giữa thì không có đòn đơn nào để lại 0 đường thoát trên 3×3 (ghi nhận bằng số).
- [ ] **Cổng chơi thử trong story**: sau Phần 1 + 2 (và 5), chơi thử; nếu né đã đủ phải tính thì Phần 3 lùi sang backlog (ghi rõ trong Completion Notes).

**Phần 3 — Đòn nối (combo)** (chỉ khi cổng ở trên yêu cầu):

- [ ] Boss có ≥ 2 điểm có thể **tuyên bố hai đòn cùng lúc**: đòn 2 bắt đầu vung khi đòn 1 rơi và rơi sau đó `combo_gap_sec` (0,4–0,6 s); brain chọn đòn 2 để phủ các ô thoát của đòn 1 (cùng phép tính đường thoát). Cả hai hiện cùng lúc với hai sắc đỏ và hai đồng hồ; ngắt đòn 1 thì đòn 2 hủy theo. Tần suất theo bộ (`combo_chance`: cautious 0, balanced 0,25, aggressive 0,6).
- [ ] Người chơi không có đòn nối; `CutActor` của người chơi không đổi.

**Phần 4 — Tốc vung theo boss**:

- [ ] `swing_speed_mult` trong `run.json` theo trận (1,0 / 1,0 / 0,9 / 0,8): nhân vào khoảng vung của **boss** (không của người chơi); đồng hồ hiển thị đúng.

**Phần 5 — Cooldown bước theo sân** (`combat.json`):

- [ ] `step_cooldown_ref_sec` (0,45), `step_cooldown_ref_steps` (2), `step_cooldown_exponent` (0,75), `step_cooldown_min_sec` (0,18), `step_cooldown_max_sec` (0,60). Với `bước_qua_sân = max(side_cols, side_rows) − 1`: `cooldown = ref × (ref_steps / bước_qua_sân) ^ exponent`, kẹp [min, max]. Áp cho người chơi; boss lấy cùng giá trị rồi nhân `boss_step_cooldown_mult` theo trận (thay `boss_step_cooldown_sec` tuyệt đối trong `run.json`; nếu còn khóa cũ thì dùng và cảnh báo).
- [ ] Test xác định: 2×2 → 0,60; 3×3 → 0,45; 4×3 → 0,33; 6×6 → 0,23; 10×10 → 0,18.
- [ ] Phép tính đường thoát ở Phần 2 dùng cooldown đã tính theo sân.

**Chung**:
- [ ] Mọi số/cờ mới trong JSON và ghi `schema.md`; không hằng số gameplay trong mã.
- [ ] Mô phỏng xác định (seeded): cùng seed → cùng nhật ký hành động; bộ cautious với nhiễu 0 cho nhật ký **di chuyển** giống hệt khi đổi seed (di chuyển không phụ thuộc RNG).
- [ ] Ảnh chụp: boss đang đi theo `row_first` (hai ảnh: ngang rồi dọc); đòn do đường thoát chọn khi người chơi ở góc; (nếu làm) đòn nối với hai đồng hồ; lưới 6×6 với vòng cooldown ngắn hơn. Giữ trong `production/qa/evidence/boss-profiles/`.

---

## Implementation Notes

- Phần 1 sống trong `BossBrain` (đích hiện tại + luật bỏ đích) và `BossBrainConfig` (khối `movement` theo bộ); `RunController`/`CombatView` cho phép ghi đè theo trận qua `match_params`.
- Phần 2: hàm thuần `EscapeAnalysis.reachable_cells(grid, status, from_cell, steps) -> Array[Vector2i]` tách riêng để test; `BossBrain` gọi với `steps = floor(duration / player_step_cooldown)`.
- Phần 3: `CutActor` boss cần hàng đợi 1 phần tử (`queue_swing`); `SwingArbiter` khởi động đòn 2 khi đòn 1 rơi và hủy nó khi đòn 1 bị ngắt; HUD vẽ hai lớp.
- Phần 5: hàm thuần `step_cooldown_for(grid)` trong `CombatConfig`; `UnitMover` nhận giá trị đã tính.
- Giữ `max_tick_sec`, Tập trung (Story 012) và trọng tài ngắt đòn nguyên vẹn.
- Story lớn: triển khai theo thứ tự 5 → 1 → 2 → (chơi thử) → 4 → 3.

---

## Out of Scope

- Dấu hiệu/nhãn ý định của boss (đã từ chối).
- Đòn "bám theo" (vùng cắt đổi theo người chơi): từ chối vì cảm giác gian lận trên cảm ứng.
- Cân bằng số tổng thể (đợt cân bằng riêng sau story này).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshot trong `production/qa/evidence/boss-profiles/`.
- Integration: `tests/integration/combat/boss_profiles_test.gd` — khuyến nghị, không bắt buộc ở `minimal`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 009, Story 011, Story 012
- Unlocks: đợt cân bằng
