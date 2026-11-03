# Quick Design Spec: Đội hình Rừng Sương hoàn chỉnh — goblin và sói sang não `pattern`

**Type**: Addition
**System**: Đội hình Rừng Sương (`ch1`), não `pattern`, `enemy_skills.json`
**GDD Reference**: `design/quick-specs/phase2-misty-forest-2026-11-01.md` (mô hình chiêu §3, luật công bằng §4, công thức máu §5.1, pool §5.5), `design/world-context.md` (Rừng Sương: goblin, sói), `design/game-brief.md`
**Date**: 2026-11-03
**Trạng thái**: Đã duyệt (người dùng, 2026-11-03: hướng "Goblin + sói, não mới", rồi "Duyệt, ghi vào dự án")

> Mọi con số là **số khởi đầu, chơi thử rồi chỉnh**, như spec 01/11. Thời gian tính bằng giây. Mọi chiêu phải qua luật công bằng F1–F10 của spec 01/11; spec này không đổi luật nào.

---

## 1. Change Summary

1. Rừng Sương chỉ còn quái có sprite và não `pattern`: **6 quái cây/nấm** đã có + **goblin và sói** theo lore (`world-context.md`).
2. **Goblin Trinh Sát** (đã có sprite) chuyển sang não `pattern`: 0 gen.
3. Bốn con được làm lại theo não `pattern` và cần sprite:
   - **Goblin Vu Sư**: boss tầng 1–2, đứng 2×2 ô trên sân `boss_hall`, 2 pha.
   - **Sói Đầu Đàn**: tinh anh bậc 1–2.
   - **Goblin Cung Thủ**: quái thường bậc 1–2, ô nguy hiểm.
   - **Sói Dữ**: quái thường bậc 1–2, ô nguy hiểm.
4. Năm con não khối cũ ra khỏi pool `ch1`: Goblin Chiến Binh, Sói, Goblin Lực Sĩ, Goblin Thủ Lĩnh, Goblin Pháp Sư. Dữ liệu trận của chúng giữ nguyên trong `chapters.json`, nên test và dev flag cũ không gãy.
5. Hai việc code nhỏ:
   - `pattern.variants`: một chiêu có nhiều mẫu ô, rút theo seed.
   - Hiệu ứng tự thân `haste`: chiêu hồi nhanh hơn trong N giây.

## 2. Motivation

- **Boss tầng 1 là boss đầu tiên mọi người chơi mới gặp.** `onboarding_tier_cap` = 1 kẹp mọi bậc về 1 khi save chưa hạ boss nào. Người mới vì thế gặp Goblin Vu Sư ở **mọi** tầng cho tới khi thắng một boss. Hiện con này vẫn là hình tạm và não khối cũ.
- 9 trong 16 quái của Rừng Sương chưa có sprite; trận tinh anh và trận khó gặp chúng thường xuyên.
- Giữ goblin và sói vì hai lý do:
  - Lore của vùng ghi rõ goblin và sói.
  - Ba dáng **người nhỏ / thú bốn chân / cây** khác nhau ngay từ hình bóng. Nếu thêm 4 con cây nữa, đội hình sẽ dễ lẫn (luật: mỗi quái phải khác nhau).
- Mỗi con dạy **một kỹ năng né chưa con nào dạy**:

| Con | Dạy |
|---|---|
| Rootling | đừng đứng yên |
| Mossbound Sentry | né vuông góc thanh |
| Greycap Sporeling | rời góc chữ L |
| Ancient Root Sentinel | mốc quyết định hàng bị đánh |
| Mistbriar Matron | chờ ô đỏ thứ hai |
| **Goblin Trinh Sát** | ô đỏ = bước ra (bài đầu tiên) |
| **Goblin Cung Thủ** | đường chéo; đổi hàng khi bị ngắm |
| **Sói Dữ** | né xong phải né tiếp (đòn đuổi) |
| **Sói Đầu Đàn** | ngắt tiếng hú bằng Phá phép |
| **Goblin Vu Sư** | đọc khối 4 ô như khối của chính mình; tìm ô ngoài hai khối |

---

## 3. Quái

Toạ độ, anchor, delivery, followup: theo spec 01/11 §3. "C" = chiêu chính.

### 3.1 Goblin Trinh Sát (`goblin_scout`) — quái thường bậc 0, sân `square`

Sprite đã có (idle, step, windup, hit, down): **0 gen**. Đây là bài đầu tiên, nên cảnh báo dài hơn quái khác.

| Chiêu | Mẫu / anchor | windup | warning | Delivery | Hiệu ứng | Hồi | Cách né |
|---|---|---|---|---|---|---|---|
| `scout_stab` (C) | 1 ô `on_player` | 0,5 | **1,2** | `CASTER_TO_TARGET`, `square_streak`, impact `slash` | 8 | 2,6 | bước 1 ô bất kỳ |
| `scout_hop` | `self`: dời 1 hàng (`move.to: adjacent_row`, như `creep`) | 0,8 (ô đích viền Ngà) | — | — | không; `counts_as_cast: false` | 5,0 | — |

### 3.2 Goblin Cung Thủ (`goblin_archer`) — quái thường bậc 1–2, ô nguy hiểm; sân `rect`

| Chiêu | Mẫu / anchor | windup | warning | Delivery | Hiệu ứng | Hồi | Cách né |
|---|---|---|---|---|---|---|---|
| `aimed_shot` (C) | cả hàng `row_of_player` (`clip`, tối thiểu 2) | **0,9** (giương cung, dáng rõ) | 1,0 | `CASTER_TO_TARGET` dọc hàng, `square_streak`, impact `slash` | 14 | 3,2 | đổi hàng |
| `volley` | đường chéo 3 ô `[[0,0],[1,1],[2,2]]`, `on_player`, xoay 0/90/180/270, `clip` tối thiểu 2 | 0,5 | 1,1 | `SKY_TO_TARGET`, `falling_squares`, impact `slash` | 10 mỗi ô | 3,0 | bước thẳng ngang hoặc dọc (ô kề thẳng không bao giờ thuộc đường chéo) |

F2 trên `rect` (12 ô, trần 6): hàng 4 ô = 33 %, chéo 3 ô = 25 %.

### 3.3 Sói Dữ (`dire_wolf`) — quái thường bậc 1–2, ô nguy hiểm; sân `rect`

| Chiêu | Mẫu / anchor | windup | warning | Delivery | Hiệu ứng | Hồi | Cách né |
|---|---|---|---|---|---|---|---|
| `chase_bite` (C) | 1 ô `on_player`; **followup** 1 ô `relative_to: player` (ô người chơi **lúc đòn đầu trúng**) | 0,4 | 0,9; followup 0,75 | `SKY_TO_TARGET` (vồ), impact `slash` | 10; followup 10 | 3,0 | né lần một, rồi bước tiếp khi ô đỏ thứ hai hiện dưới chân |
| `prowl` | `self`, dời 1 hàng | 0,6 | — | — | không; `counts_as_cast: false` | 4,0 | — |

Followup chọn ô và qua F1 lúc đòn đầu trúng (spec 01/11 §3.5); không qua thì bỏ. Khác Matron: nhánh của Matron bám ô đầu, đòn đuổi của Sói **bám người chơi**.

### 3.4 Sói Đầu Đàn (`wolf_alpha`) — tinh anh bậc 1–2; sân `rect`

Combo: hú (ngắt được) → nếu không bị ngắt, nó vào trạng thái hăng máu, các chiêu hồi nhanh hơn.

| Chiêu | Mẫu / anchor | windup | warning | Delivery | Hiệu ứng | Hồi | Cách né |
|---|---|---|---|---|---|---|---|
| `alpha_howl` (mechanic) | `self`, viền Ngà quanh ô Sói, **không đỏ** | **1,4** (ngửa đầu hú), `interruptible: true` | — | — | xong windup: **`haste`** hồi chiêu ×0,5 trong 6 s; bị Phá phép thì không có gì và Sói **choáng 1,0 s** | 12,0 | thả khối trúng Sói trong 1,4 s |
| `rending_rush` (C) | 3 ô liền `row_of_player` (`clip`, tối thiểu 2) | 0,6 | 1,2 | `GROUND_PROPAGATION` từ ranh giới, `floor_run`, impact `slash` | 16 + **Làm chậm** 1,5 s (hồi bước ×1,3, D4) | 4,5 | đổi hàng |
| `chase_bite` | dùng chung với Sói Dữ (`owner: shared`) | 0,4 | 0,9; followup 0,75 | như 3.3 | 12; followup 12 | 3,0 | như 3.3 |

- Khi đang `haste`:
  - Viền Ngà mờ quanh ô Sói suốt 6 s.
  - `warning_sec` **không đổi** (sàn công bằng); chỉ `cooldown_sec` giảm.
  - F5 (0,4 s giữa hai cảnh báo) vẫn giữ.
- `teach_after`: `dire_wolf` (đòn đuổi), `goblin_archer` (đổi hàng khi bị ngắm).

### 3.5 Goblin Vu Sư (`goblin_warlock`) — boss tầng 1–2

**Thông số chung:**
- Đứng **2×2 ô** (`footprint` như Phù thủy) trên sân `boss_hall` 6×4 mỗi bên. Đổi từ `staircase`.
- Bỏ trait `row_burner`.
- `brain_set` `balanced`.

**Chủ đề:** goblin trộm Khối của lưới và ném **khối 4 ô giống hệt khối người chơi dùng**. Người chơi đọc đòn của nó bằng chính hiểu biết về khối của mình.

| # | Chiêu | Loại | Mẫu / anchor | windup | warning | Delivery | Hiệu ứng | recovery | Hồi | Cách né |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `hex_bolt` | C | 1 ô `on_player` | 0,4 | 0,9 | `CASTER_TO_TARGET`, `square_streak`, impact `curse` | 8 + 1 Rạn | 0,6 | 2,8 | bước 1 ô |
| 2 | `stolen_shape` | mechanic p1 | **khối 4 ô**: `pattern.variants` = L `[[0,0],[0,1],[0,2],[1,2]]`, T `[[0,0],[1,0],[2,0],[1,1]]`, S `[[1,0],[2,0],[0,1],[1,1]]`, rút theo seed; `near_player`, phải chứa ô người chơi; xoay 4 hướng | 0,8 | 1,4 | `SKY_TO_TARGET`, `falling_squares`, impact `burst` | 16 | 1,2 | 5,0 | đọc hình khối, bước ra phía mở |
| 3 | `curse_lane` | C | 3 ô liền `row_of_player` (`clip`, tối thiểu 2) | 0,7 | 1,3 | `GROUND_PROPAGATION` từ ranh giới, `floor_run`, impact `curse` | 12 + Làm chậm 1,5 s | 0,8 | 6,0 | đổi hàng |
| 4 | `warlock_blink` | self | dời 1 hàng (như `witch_shift`), khung Ngà quanh 4 ô đích | 0,8 | — | — | `counts_as_cast: false` | 0,4 | 8,0 | — |
| 5 | `twin_shapes` | mechanic p2 | **hai khối 4 ô** (variants như #2): khối 1 `near_player` chứa ô người chơi; khối 2 `show_with_first: true` (sọc chờ), đặt kề khối 1, không trùng ô; đỏ đầy khi khối 1 trúng | 0,9 | 1,5; khối 2 trúng sau khối 1 **0,75 s** | `SKY_TO_TARGET`, `falling_squares`, impact `burst` | 16 mỗi khối | **1,5** | 7,0 | đứng ô ngoài **cả hai** khối, đã thấy từ đầu |

**Pha:**

| Pha | Máu | Chiêu | Cơ chế (`favor_phase_mechanic`) |
|---|---|---|---|
| 1 | > 50 % | hex_bolt, stolen_shape, curse_lane, warlock_blink | `stolen_shape` |
| 2 | ≤ 50 % | + twin_shapes | `twin_shapes` |

- Chuyển pha: bất tử 1,5 s, tắt mọi cảnh báo, không gây sát thương (D14).
- `stolen_shape` và `twin_shapes` có `interruptible: false` (viền Ngà); ba chiêu kia Phá phép được (D9).
- Kiểm tra F2 trên `boss_hall` (24 ô, trần 12): một khối = 4 ô (17 %), hai khối = 8 ô (33 %), hàng 3 ô = 13 %.
- So với Phù thủy: Vu Sư có 2 pha × 5 chiêu, Phù thủy có 3 pha × 8 chiêu. Vu Sư không có mốc, không Trói, không Guard.

---

## 4. Máu (công thức spec 01/11 §5.1; `H` = 200, tầng tham chiếu 3, `k` = 0,6375)

| Quái | Tỉ lệ | Máu thật tầng 3 | Máu viết (`boss_max_hp`) | Tầng 1 (×0,525) | Tầng 2 (×0,6) | Tầng 5 (×0,8625) |
|---|---|---|---|---|---|---|
| `goblin_scout` | 0,55 × `H` | 110 | **170** (đang 86) | 89 | 102 | 147 |
| `goblin_archer` | 0,65 × `H` | 130 | **200** (đang 108) | 105 | 120 | 173 |
| `dire_wolf` | 0,75 × `H` | 150 | **240** (đang 119) | 126 | 144 | 207 |
| `wolf_alpha` (tinh anh) | 2,0 × 140 | 280 | **440** (đang 151) | — | 264 | 380 |
| `goblin_warlock` (boss) | 4,0 × 140 | 560 | **880** (đang 146) | **462** | **528** | — (chỉ tầng 1–2; người mới có thể gặp ở tầng 3–5 do trần bậc: 561 / 693 / 759) |

So sánh: Phù thủy Rừng ở 5,5 × 140 (tầng 3: 771). Vu Sư thấp hơn để boss đầu tiên dễ hơn.

## 5. Pool `ch1` (thay khối `pools`)

| Pool | Bậc 0 | Bậc 1 | Bậc 2 |
|---|---|---|---|
| `battle` | goblin_scout, rootling, mossbound_sentry | rootling, mossbound_sentry, greycap_sporeling, goblin_archer, dire_wolf | greycap_sporeling, mossbound_sentry, goblin_archer, dire_wolf |
| `danger` | — | greycap_sporeling, goblin_archer, dire_wolf | mossbound_sentry, goblin_archer, dire_wolf |
| `miniboss` | — | ancient_root_sentinel, wolf_alpha | ancient_root_sentinel, mistbriar_matron, wolf_alpha |
| `boss` | — | goblin_warlock | forest_witch |

- Ra khỏi pool (dữ liệu trận giữ nguyên): `goblin_warrior`, `wolf`, `goblin_brute`, `goblin_chief`, `goblin_shaman`.
- `teach_after` của `wolf_alpha`: xem 3.4. Luật ép cột dạy của spec 01/11 §5.5 áp nguyên.
- Đo lại trên 100 000 bản đồ `ch1` (20 000 seed × 5 tầng), như bảng tần suất của spec 01/11.

## 6. Code cần thêm (nhỏ)

| Việc | Chỗ | Ghi chú |
|---|---|---|
| `pattern.variants` | `PatternPlanner` + loader `enemy_skills.json` | danh sách mẫu ô; mỗi lần ra chiêu rút 1 bằng RNG có seed của trận, rồi dựng kế hoạch như `offsets`. Một mẫu không đặt được thì thử mẫu khác trước khi coi chiêu không dùng được |
| `effects.haste` `{cooldown_mult, sec}` | `PatternController` | nhân `cooldown_sec` của chiêu ra **trong** thời gian hiệu lực; không nhân `windup_sec`, `warning_sec`, `recovery_sec` |
| `effects.on_interrupt.stun_sec` | `PatternController` | choáng khi bị Phá phép trong windup (Sói Đầu Đàn); Sentinel đã có choáng khi vỡ mốc, dùng lại cách đứng yên đó |
| `variant` của sân cho Sói Dữ / Cung Thủ | `chapters.json` | `rect` có `variant: true` nếu FairnessCheck qua 200 biến thể |

Không đổi: `FairnessCheck`, `SkillDelivery`, trạng thái (`root`, `slow`, `fragile`, `guard`), mô hình pha.

## 7. Nhu cầu hình (mỗi lần gọi PixelLab người dùng duyệt riêng)

Quy trình như đội hình 02/11 (`design/assets/specs/misty-forest-roster-assets.md`):
- `create_character_pro_flash` 64×64, góc nhìn thấp từ trên xuống, 8 hướng.
- Style lấy từ rotation south của Goblin v3; khóa palette.
- Anchor là hướng tây nam.
- Clip làm bằng `animate_character` PixMiniMax.

Mỗi hình gốc đều **nêu nhân vật nổi tiếng giống nhất** và ghi điểm khác biệt vào prompt trước khi xin duyệt. Không màu đỏ, không phát sáng trên thân.

| Quái | Cỡ (luật cỡ theo bậc) | Clip | Ước tính |
|---|---|---|---|
| Goblin Cung Thủ | ~0,7 Kiếm sĩ, khung 64×52 | idle, step, windup (giương cung), hit, down | ~11 gen |
| Sói Dữ | ~0,7, khung 64×52, bốn chân | idle, step, windup (hạ thấp người), hit, down | ~11 gen (thêm 1–2 nếu thú bốn chân lệch style) |
| Sói Đầu Đàn | ~0,95, khung 64×64 | idle, step, windup, **howl**, hit, down | ~12 gen |
| Goblin Vu Sư | boss 2×2 ô, khung ~160×130 như Phù thủy | idle, step (4 hướng như Phù thủy, hoặc 1 clip), windup, windup_heavy, phase_shift, hit, down | ~20–28 gen |
| **Tổng** | | | **~55–62 gen**; gen **1 con trước** (Cung Thủ, rẻ nhất, cùng loài goblin với mẫu style) rồi mới làm các con sau |

Vẽ bằng code: viền Ngà khi hú / hăng máu, sọc chờ của khối 2, mọi ô đỏ.

## 8. Thứ tự làm

| Bước | Việc | Test |
|---|---|---|
| R1 | `pattern.variants`, `haste`, choáng khi bị ngắt | unit: rút variant theo seed tất định; haste nhân đúng cooldown, không nhân warning; choáng khi bị Phá phép |
| R2 | dữ liệu 5 con trong `enemy_skills.json` + trận trong `chapters.json` (máu, `brain`, `enemy`, sân, `footprint`) | mỗi chiêu qua F1–F3 trên mọi sân `ch1` + 200 biến thể; bot né hoàn hảo nhận 0 sát thương trong 60 s (Vu Sư: 120 s mỗi pha); bot đứng yên mất máu |
| R3 | pool mới + `teach_after` của Sói Đầu Đàn | 10 000 seed: không con nào ngoài pool mới xuất hiện ở `ch1`; Sói Đầu Đàn luôn sau quái dạy nó |
| R4 | hình (mục 7), từng lần gen được duyệt | ảnh giữ lại trong `production/qa/evidence/misty-forest-roster-v2/`: mỗi con một ảnh trong trận; Vu Sư: khối 1, hai khối, chuyển pha |

R1–R3 không tốn gen và chơi được ngay với hình tạm; R4 làm sau, theo từng con.

## 9. Acceptance Criteria

- [ ] Pool `ch1` chỉ gồm 11 con ở mục 5; mọi con dùng `"brain": "pattern"`.
- [ ] Mỗi con trong 5 con ở mục 3: bot né hoàn hảo nhận 0 sát thương; bot đứng yên mất máu.
- [ ] `stolen_shape` / `twin_shapes`: ô bị đánh đúng là một trong 3 khối L/T/S (đã xoay); hai khối không trùng ô; F2 ≤ 50 %.
- [ ] Sói Đầu Đàn: bị Phá phép trong lúc hú thì không có `haste` và bị choáng 1,0 s; khi đang `haste` thì `warning_sec` của mọi chiêu không đổi.
- [ ] Đòn đuổi của Sói: followup nằm đúng ô người chơi lúc đòn đầu trúng, hoặc bị bỏ nếu không qua F1.
- [ ] Vu Sư: chuyển pha ở 50 %, bất tử 1,5 s, cảnh báo tắt.
- [ ] Hồi quy: trận não khối cũ ở các vùng khác chạy y như trước; dữ liệu trận của 5 con bị bỏ khỏi pool vẫn tải được.
- [ ] Playtest: sau trận đầu, người chơi nói được mỗi con mới "làm gì, né thế nào".
- [ ] Playtest: boss tầng 1 không ai thua vì một đòn "không hiểu tại sao".

## 10. Affected Systems

| Hệ | Ảnh hưởng | Việc |
|---|---|---|
| `assets/data/enemy_skills.json` | 5 địch, ~11 chiêu | thêm dữ liệu |
| `assets/data/chapters.json` (`ch1`) | 5 trận đổi số / não / sân; pool mới | sửa dữ liệu |
| `PatternPlanner`, `PatternController` | `variants`, `haste`, choáng khi bị ngắt | sửa nhỏ + test |
| Bộ sinh bản đồ | `teach_after` (đã có) | chỉ dữ liệu |
| `assets/i18n/strings.csv` | mô tả / "cách né" của 5 con | thêm chuỗi |
| `UnitLayer` | clip `howl`, Vu Sư 2×2 | dùng lại đường của Phù thủy |

## 11. GDD Update Required?

Có, sau khi duyệt:
- **Đã áp dụng 2026-11-03.** `design/world-context.md` Rừng Sương: danh sách quái thành 6 quái cây/nấm + Goblin Trinh Sát, Goblin Cung Thủ, Goblin Vu Sư (boss tầng 1–2), Sói Dữ, Sói Đầu Đàn; Kẻ Gác vẫn là Phù thủy Rừng.
- **Đã áp dụng 2026-11-03.** `design/quick-specs/phase2-misty-forest-2026-11-01.md` §5.4–5.5: ghi chú trỏ sang spec này.
