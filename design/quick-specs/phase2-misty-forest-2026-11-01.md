# Quick Design Spec: Phase 2 — Mô hình chiêu theo mẫu ô của địch + lát cắt Rừng Sương

**Type**: Addition
**System**: Não địch mới `pattern` (bên cạnh `BossBrain`), chiêu của địch, pha boss, đội hình Rừng Sương (`ch1`), Phù thủy Rừng
**GDD Reference**: `docs/architecture/adr-0001-tessera-design-pack-alignment.md` (Phase 2, D4, D5, D7, A1, A2, A4, A6), `design/game-mechanics.md` §2.1, §2.6, §2.8, §5.1; design pack `03` (Land 1 + Shared monster standard, encounter budgeting), `04` §1 + "AI decision logic", `01` §1A, `06` §3, §5, §6; `design/quick-specs/o-rot-thay-tuong-2026-10-31.md`, `design/quick-specs/mot-o-mot-hieu-ung-2026-11-01.md`
**Date**: 2026-11-01
**Trạng thái**: Đã duyệt (người dùng, 2026-11-01, với các chốt ở cuối file)

> Mọi con số trong spec là **đề xuất có thể chỉnh**; số của design pack là PROPOSED và ở đây được đổi thành số cụ thể. Thời gian viết bằng **giây**; một "beat" của pack = `timing.beat_sec` (0,5 s, `combat.json`), không bao giờ hard-code (A6). Chỗ nào spec phải chọn giữa nhiều cách mà người dùng chưa chốt thì ghi **[Quyết định Dn]** và gom ở cuối file.

---

## 1. Change Summary

1. Thêm **não `pattern`**: địch không nhặt và đặt khối nữa mà dùng **chiêu có mẫu ô cố định** (anchor + xoay + offset), theo vòng đời của pack `06` §3: `IDLE → WINDUP → WARNING → DELIVERY → RESOLVE → (FOLLOWUP) → RECOVERY`. Toàn bộ chiêu, pha và trọng số AI nằm trong **một file dữ liệu mới** `assets/data/enemy_skills.json`.
2. Não khối hiện tại (`BossBrain`) **giữ nguyên**: mọi trận đang có (Goblin Scout, Sói, các goblin, các tinh anh cũ) không đổi hành vi. Mỗi địch trong một trận dùng **đúng một** não.
3. Rừng Sương thêm 3 quái thường (Rootling, Mossbound Sentry, Greycap Sporeling), 2 tinh anh (Ancient Root Sentinel, Mistbriar Matron), và **Phù thủy Rừng** đổi sang 3 pha × 7 chiêu.
4. Một bộ **luật công bằng** kiểm được bằng test: mọi cảnh báo đều chừa ô an toàn bước tới kịp, đỏ không quá 50 % sàn, không khóa chân chồng nhau, cảnh báo không bao giờ bị giấu.
5. Mô hình pha/chiêu chỉ là dữ liệu: số pha và số chiêu không có giới hạn trong code, nên Người Giữ Tâm Lưới lên 3 pha × 7 chiêu sau này **không cần sửa code** (A4).

## 2. Motivation

- Địch đặt khối hiện nay đều "chơi giống người chơi"; khác nhau chủ yếu ở số máu và tốc độ. Pack muốn mỗi loài có **một mẫu ô đọc được**, dạy một kỹ năng né riêng (Rootling dạy "đừng đứng yên", Sentry dạy "né vuông góc thanh", Matron dạy "theo dõi nhánh thứ hai"). Điều này khớp với yêu cầu của người dùng: mỗi nhân vật/quái phải khác nhau ngay từ trận đầu.
- MDA: aesthetic chính là **Challenge** (né có tính toán) + **Discovery** (học mẫu của từng loài). SDT: **Competence** — người chơi luôn biết vì sao trúng đòn vì ô đỏ = đúng ô bị đánh.
- Luật công bằng biến "đòn không né được" từ lỗi khó phát hiện thành test đỏ.

---

## 3. Mô hình chiêu theo mẫu ô (P2.2)

### 3.1 Dữ liệu nằm ở đâu

**Khuyến nghị: file mới `assets/data/enemy_skills.json`** **[Quyết định D1]**.

- Lý do: `chapters.json` đã gần 2000 dòng và chia theo vùng; chiêu dùng lại giữa nhiều trận (một Rootling có thể xuất hiện ở trận thường và trong pha của boss), pha boss cần chỗ riêng. Tên file theo luật `[system]_[name].json`.
- `chapters.json` vẫn là nơi khai báo **trận**: máu, sân, `brain_set` (di chuyển), nhịp. Trận dùng não mới chỉ thêm hai khóa:

```json
"rootling": {
  "id": "rootling",
  "name_key": "boss.rootling.name",
  "boss_max_hp": 190,
  "brain": "pattern",
  "enemy": "rootling",
  "brain_set": "balanced",
  "boss_step_cooldown_mult": 1.44,
  "boss_think_interval_sec": 0.4,
  "boss_reaction_sec": 0.45,
  "arena": {"shape": "square"}
}
```

- `brain` vắng mặt = `"block"` (não hiện tại). Không trận cũ nào phải sửa.

### 3.2 Cấu trúc `enemy_skills.json`

```json
{
  "version": 1,
  "fairness": {
    "reaction_margin_sec": 0.25,
    "max_red_ratio": 0.5,
    "cc_grace_sec": 1.0,
    "min_gap_between_warnings_sec": 0.4,
    "followup_min_warning_sec": 0.75
  },
  "ai": {
    "punish_standing_still": 1.2,
    "standing_still_sec": 1.5,
    "avoid_repeat_last_skill": 0.45,
    "favor_phase_mechanic": 1.25,
    "noise": 0.1,
    "cancel_cooldown_ratio": 0.5
  },
  "skills": { "<skill_id>": { ... } },
  "enemies": { "<enemy_id>": { ... } }
}
```

### 3.3 Một chiêu (`skills.<id>`)

| Khóa | Kiểu | Ý nghĩa | Mặc định |
|---|---|---|---|
| `id` | string | trùng khóa | — |
| `owner` | string | id địch sở hữu (chỉ để kiểm tra dữ liệu; một chiêu có thể dùng chung nếu `owner` = `"shared"`) | — |
| `kind` | enum | `attack` (đánh ô bên người chơi), `self` (lên chính nó: Guard, di chuyển), `marker` (đặt mốc rễ bên nửa địch) | `attack` |
| `pattern.offsets` | `[[dc, dr], …]` | các ô tương đối với anchor, ở hướng xoay 0 | — |
| `pattern.anchor` | enum | `on_player`, `near_player`, `row_of_player`, `column_of_player`, `row_of_anchor`, `fixed`, `self_cell`, `enemy_half_empty` (xem 3.4) | `on_player` |
| `pattern.must_cover_player` | bool | kế hoạch phải chứa ô người chơi lúc cảnh báo bắt đầu | `true` với `on_player`, `false` còn lại |
| `pattern.rotations` | `[0, 90, 180, 270]` con | các hướng xoay được phép | `[0]` |
| `pattern.clip` | bool | ô rơi ra ngoài sàn bị bỏ thay vì làm chiêu không dùng được | `false` |
| `pattern.min_cells` | int | số ô tối thiểu sau khi cắt (chỉ khi `clip`) | số offset |
| `target_side` | enum | `player` / `enemy` / `self` | `player` |
| `windup_sec` | float | tư thế niệm 2 khung, **không đỏ**, địch đứng yên | 0,5 |
| `warning_sec` | float | ô đỏ = đúng ô sẽ trúng; **chốt ô lúc cảnh báo bắt đầu** | — |
| `followup` | object / null | đòn thứ hai, có **cảnh báo mới** trước khi trúng (3.5) | null |
| `delivery` | object | `{type, origin, travel, impact, chain_order}` theo `SkillDelivery` (A1) | bắt buộc, không có mặc định SKY |
| `effects` | object | `damage`, `status` `{id, sec | stacks}`, `zone` `{id, sec}` | — |
| `recovery_sec` | float | sau RESOLVE (hoặc sau followup) địch đứng yên, không ra chiêu: cửa sổ phản công | 0,6 |
| `cooldown_sec` | float | tính từ RESOLVE cuối | — |
| `weight` | float | trọng số gốc cho AI | 1,0 |
| `interruptible` | bool | đòn của người chơi trúng địch trong WINDUP/WARNING thì hủy chiêu (luật Phá phép hiện có) | `true` **[Quyết định D9]** |
| `conditions` | object | `phases` (danh sách id pha), `hp_below` / `hp_above` (tỉ lệ), `once`, `requires_anchor` (int), `player_still_sec` | `{}` |
| `counter_key` | string | khóa chữ "Cách né" cho bảng bestiary/tooltip | — |

Luật cho `effects`:
- `damage` là **số cố định mỗi lần trúng** (không nhân số ô như đòn khối). Áp cho đơn vị nào đứng trên một ô của mẫu lúc RESOLVE.
- `zone` theo spec "Mỗi ô một hiệu ứng": vùng mới thay vùng cũ; **ô khóa** (đang nứt / hố) bị bỏ khỏi mẫu; không đặt vùng lên ô khóa.
- `status` chỉ dùng trạng thái **đang có** trong game hoặc các trạng thái được chốt ở mục 6.

### 3.4 Luật anchor

Toạ độ trên nửa người chơi: `col` 0 là cột **sát nửa địch** ("cột trước"), tăng ra xa; `row` 0 ở trên. Hai nửa đặt cạnh nhau nên **hàng thẳng nhau** giữa hai nửa (dùng cho mốc rễ).

| Anchor | Cách chọn ô gốc lúc cảnh báo bắt đầu |
|---|---|
| `on_player` | ô người chơi đang đứng |
| `near_player` | một ô sàn khoảng cách Manhattan 1 với người chơi (AI chọn theo 3.7) |
| `row_of_player` | cả hàng của người chơi; nếu mẫu ngắn hơn hàng thì chọn **cửa sổ liền nhau có chứa ô người chơi** |
| `column_of_player` | như trên, theo cột |
| `row_of_anchor` | hàng của mốc rễ còn sống mới nhất (mục 7); không có mốc thì rơi về `row_of_player` |
| `fixed` | danh sách ô viết sẵn trong `pattern.offsets` (toạ độ tuyệt đối) |
| `self_cell` | ô của chính địch (Guard, di chuyển) |
| `enemy_half_empty` | ô trống bên nửa địch, không phải ô của địch, không hố, không có mốc khác; với `pattern.row: "player"` chỉ lấy ô trên hàng hiện tại của người chơi nếu hàng đó còn ô trống (cột ngẫu nhiên có seed), không có thì ô trống bất kỳ |

Mặc định "lưới nào" theo ADR: **nửa người chơi** trừ khi chiêu ghi `target_side: "enemy"`/`"self"`.

Ô không hợp lệ cho một mẫu: ô thiếu của sân, hố, ô đang nứt (ô khóa). Không `clip` mà có ô không hợp lệ thì hướng xoay/anchor đó bị loại; hết lựa chọn thì chiêu **không dùng được lúc này** (`canCast` = false), không ép.

### 3.5 Followup

- Followup có `offsets` + `relative_to` (`first_cells`, `first_end`, `first_center`, `player`), `warning_sec` (≥ `fairness.followup_min_warning_sec` = 0,75 s), `effects` riêng.
- **Ô của followup được chọn và hiện ngay lúc đòn đầu RESOLVE**, rồi đi qua cùng bộ kiểm công bằng (3.6) với vị trí người chơi lúc đó. Không qua kiểm thì followup **bị bỏ** (không đánh), không đổi sang ô khác ngầm.
- Ngoại lệ "hai làn hiện cùng lúc" (`followup.show_with_first: true`, dùng cho Withered Crown): làn sau hiện ngay từ đầu bằng **sọc chờ** (`telegraph.queued_stripe_alpha` đã có) và chuyển đỏ đầy lúc làn đầu RESOLVE. Ô của cả hai làn chốt từ đầu.

### 3.6 Vòng đời của một chiêu (khớp pack `06` §3)

| Bước | Chuyện gì xảy ra | Ai thấy gì |
|---|---|---|
| CHOOSE | AI chọn chiêu theo 3.7, dựng kế hoạch (ô, xoay), chạy kiểm công bằng | không |
| WINDUP | `windup_sec`, địch đứng yên, clip `windup` 2 khung | dáng niệm; với `interruptible: false` thêm viền Ngà quanh ô địch |
| WARNING | **chụp ô** (immutable); ô đỏ sọc `warning_sec` | ô đỏ đúng các ô sẽ trúng |
| DELIVERY | hoạt ảnh `SkillDelivery`, **không gây sát thương trên đường đi** (A1) | vệt vuông |
| RESOLVE | sát thương/trạng thái/vùng trên đúng các ô đã chụp, trừ ô vừa thành ô khóa | va chạm ô vuông |
| FOLLOWUP | cảnh báo mới (3.5) rồi RESOLVE lần hai | đỏ mới |
| RECOVERY | `recovery_sec`, địch không ra chiêu, vẫn có thể bị đánh | — |

- Ô trong cảnh báo bắt đầu nứt giữa chừng: **mất đỏ ngay** và không bị đánh (luật 4 của spec "Mỗi ô một hiệu ứng"). Không bao giờ dời mục tiêu ngầm.
- Bị hủy (Phá phép, chỉ khi `interruptible`): đỏ tắt ngay, chiêu vào hồi `cooldown_sec × ai.cancel_cooldown_ratio`.
- Thời gian trận chậm 0,2× / dừng (Tập trung) thì mọi đồng hồ của chiêu chậm/dừng theo.
- Nhịp theo tầng (`floor_scaling.step_mult`, "Nhịp") **nhân `windup_sec`, `cooldown_sec`, `recovery_sec`**, **không bao giờ nhân `warning_sec`** — cảnh báo là sàn công bằng. `size_add` ("Đòn +1 ô") **không áp** cho mẫu ô.

### 3.7 AI chọn chiêu (pack `06` §6)

```
mỗi boss_think_interval_sec, nếu không đang ở WINDUP/WARNING/RECOVERY:
  ứng viên = chiêu của pha hiện tại
           lọc: hết hồi, đủ conditions, cách cảnh báo trước ≥ min_gap_between_warnings_sec
           dựng kế hoạch (mọi anchor × xoay hợp lệ; ưu tiên kế hoạch chứa ô người chơi nếu must_cover_player)
           lọc: plan.valid và canHeroRespond(plan)   # 3.8 + mục 4
  nếu có chiêu "every_nth" của pha đến lượt và hợp lệ: chọn nó
  ngược lại nếu rỗng: không ra chiêu, giao cho phần DI CHUYỂN của BossBrain (né, đi lang thang)
  ngược lại: chọn có trọng số (RNG có seed của trận)
     w = weight
       × punish_standing_still  nếu người chơi đứng yên ≥ standing_still_sec và kế hoạch chứa ô người chơi
       × avoid_repeat_last_skill nếu trùng chiêu vừa dùng
       × favor_phase_mechanic   nếu là chiêu "mechanic" của pha
       × (1 ± noise)
```

- Giữa các chiêu, địch **di chuyển trên nửa mình** bằng phần di chuyển của `BossBrain` hiện có (theo `brain_set`, né đòn người chơi). Não `pattern` không nhặt khối: **không có khối rơi bên nửa địch** và ô "khối boss" trên HUD ẩn với địch dùng não này.
- Mọi trọng số đọc từ `enemy_skills.json` `ai` (ghi đè được theo từng địch trong `enemies.<id>.ai`).

### 3.8 Một địch (`enemies.<id>`) và pha

```json
"forest_witch": {
  "tier": "warden",
  "logical_tiles": 1,
  "ai": {},
  "phases": [
    {"id": "p1", "enter_hp_ratio": 1.0,  "skills": ["root_nail", "branch_lattice", "root_anchor", "entangled_row"],
     "mechanic": "root_anchor", "overrides": {"root_anchor": {"count": 1}}},
    {"id": "p2", "enter_hp_ratio": 0.65, "skills": ["root_nail", "branch_lattice", "root_anchor", "entangled_row", "moss_guard", "withered_crown"],
     "mechanic": "withered_crown", "overrides": {"root_anchor": {"count": 2}},
     "transition": {"sec": 1.5, "on_enter": [{"skill": "root_anchor"}]}},
    {"id": "p3", "enter_hp_ratio": 0.30, "skills": ["root_nail", "branch_lattice", "root_anchor", "entangled_row", "moss_guard", "withered_crown", "forest_last_knot"],
     "mechanic": "forest_last_knot", "every_nth": {"skill": "forest_last_knot", "n": 3},
     "transition": {"sec": 1.5}}
  ]
}
```

- Địch thường/tinh anh không có `phases` dài: một pha mặc định `{"id": "main", "skills": [...]}`.
- **Chuyển pha**: khi máu ≤ `enter_hp_ratio` của pha kế: mọi cảnh báo đang hiện **tắt ngay** (thấy được), địch đứng yên `transition.sec` với hiệu ứng hạt vuông, **không gây sát thương**, sau đó chạy `on_enter`. Sát thương của người chơi vẫn trúng, nhưng **máu bị kẹp ở ngưỡng**: một đòn không thể nhảy qua hai pha; đòn vượt ngưỡng dừng ở ngưỡng, pha sau xếp hàng chờ **[Quyết định D14]**.
- `overrides`: tham số của một chiêu được ghi đè theo pha (số mốc, sát thương, số làn…) — cùng một chiêu, khác pha, không cần chiêu trùng.
- `traits` (trait hiện có như `seal_caster`, `row_burner`) được phép trong từng pha, giống `phases` của Người Giữ Tâm Lưới hiện nay, để trait cũ và chiêu mẫu sống chung.

**A4 — vì sao không cần sửa code để lên 3 pha × 7 chiêu (hay hơn):**
- `phases` là mảng độ dài bất kỳ; `skills` là danh sách id độ dài bất kỳ; ngưỡng, chuyển pha, chiêu cơ chế, `every_nth`, `overrides`, `traits` đều là dữ liệu.
- Code chỉ biết các **loại** (anchor, delivery, status, zone, followup) — thêm chiêu mới là thêm dữ liệu dùng các loại có sẵn.
- Người Giữ Tâm Lưới giữ 2 pha hiện tại (A4). Khi lên 3 × 7: đổi trận `an_dai_keeper` sang `"brain": "pattern"` + một mục `enemies.an_dai_keeper`. Test bắt buộc: một địch giả trong fixture 3 pha × 7 chiêu và một địch 4 pha × 9 chiêu chạy hết vòng đời mà không đụng code.

### 3.9 Sống chung với `BossBrain` và trait

- Một trận = một địch = một não (`block` hoặc `pattern`). Goblin Scout, Sói, Sói Dữ, Goblin Chiến binh / Cung thủ / Đô vật và các tinh anh cũ (Goblin Chief, Goblin Shaman, Sói Đầu Đàn) **giữ não khối**.
- Trait vẫn chạy với cả hai não. Cảnh báo của trait (Hàng Lửa, Chặn Lối…) **tính chung vào trần đỏ** (mục 4); não `pattern` coi ô trait đang cảnh báo là ô không an toàn và chờ nếu vượt trần.
- `boss_drop_interval_mult`, `boss_min_runes` bị bỏ qua với não `pattern` (không có tay khối).

---

## 4. Luật công bằng (test được)

### 4.1 Công thức "bước tới kịp"

```
step_cd   = CombatConfig.step_cooldown_for(board) × hệ số bước hiện tại của người chơi (ô lầy, nội tại Sát thủ…)
lock_left = max(hồi bước còn lại, thời gian Đóng Băng còn lại, thời gian Trói còn lại)
t_need(k) = lock_left + (k − 1) × step_cd + reaction_margin_sec          (k ≥ 1 bước)
hợp lệ   ⇔ người chơi KHÔNG đứng trong mẫu
          hoặc ∃ ô an toàn c có khoảng cách BFS k với t_need(k) ≤ warning_sec
```

- **Ô an toàn**: ô sàn, không thuộc mẫu, không thuộc cảnh báo nào khác đang hiện (của chiêu hay trait), không hố, không đang nứt, không Bãi Gai/ô cháy. Đường đi được đi qua ô đỏ (chưa trúng) nhưng không qua hố.
- `reaction_margin_sec` = **0,25 s** (khoảng 0,2–0,3).
- Hồi bước của các sân Rừng Sương (`0,45 × (2/(max(cột,hàng)−1))^0,75`, kẹp [0,18; 0,60]):

| Sân (`ch1`) | Nửa người chơi | step_cd | Bước 1 cần (hồi bước sẵn sàng) | Bước 1 cần (vừa bước xong) |
|---|---|---|---|---|
| `square` | 3×3, 9 ô | 0,45 s | 0,25 s | 0,70 s |
| `rect` | 4×3, 12 ô | 0,33 s | 0,25 s | 0,58 s |
| `u_shape` | 4×3 thiếu 1, 11 ô | 0,33 s | 0,25 s | 0,58 s |
| `cross` | 4×4 thiếu 4 góc, 12 ô | 0,33 s | 0,25 s | 0,58 s |
| `staircase` | 4×4 thiếu 6, 10 ô | 0,33 s | 0,25 s | 0,58 s |

Hệ quả: cảnh báo ≥ 0,9 s luôn cho đủ **một bước** kể cả khi vừa bước xong trên sân 3×3; followup 0,75 s đủ một bước trên mọi sân Rừng Sương.

### 4.2 Các luật

| # | Luật | Số |
|---|---|---|
| F1 | Mọi kế hoạch qua 4.1 lúc cảnh báo bắt đầu; followup qua 4.1 lúc nó bắt đầu | — |
| F2 | **Trần đỏ**: tổng ô đang cảnh báo (mọi nguồn, kể cả sọc chờ) ≤ `max_red_ratio` × sàn dùng được của người chơi (trừ ô thiếu, hố, ô đang nứt) | 0,5 (khoảng 0,45–0,6); 3×3 → tối đa 4 ô |
| F3 | Sau RESOLVE, vùng chiêu để lại (gai…) không được làm người chơi hết ô bước được kề bên | ≥ 1 ô kề bước được |
| F4 | **Không khóa chồng**: đang Trói hoặc Đóng Băng thì Trói/Đóng Băng mới từ địch bị bỏ; sau khi khóa hết, `cc_grace_sec` không nhận khóa mới từ địch | 1,0 s |
| F5 | Hai cảnh báo của địch cách nhau ≥ `min_gap_between_warnings_sec` lúc bắt đầu | 0,4 s |
| F6 | **Cảnh báo không bao giờ bị giấu**: không trait nào (`shroud`…) che ô đỏ của chiêu mẫu; ô đỏ vẽ trên mọi VFX sàn; chế độ Giảm chuyển động vẫn đỏ đầy | — |
| F7 | Ô khóa (nứt/hố) không bao giờ nằm trong mẫu; ô bắt đầu nứt giữa cảnh báo mất đỏ ngay | theo spec 01/11 |
| F8 | Nguồn mới (Ô rớt của `seal_caster`, trait) bắt đầu khi một chiêu đang cảnh báo phải để lại ≥ 1 ô an toàn ngoài **cả hai**; không được thì nguồn đến sau **chờ** | — |
| F9 | Không chiêu nào lấy ô người chơi làm đích khi `lock_left + reaction_margin > warning_sec` (chính 4.1) — tức là địch không thể "đánh người đang bị trói" | — |
| F10 | Sau chiêu nặng (`recovery_sec` ≥ 1,2 s) người chơi có ít nhất một hành động có nghĩa (một bước hoặc thả một khối) trước cảnh báo kế | — |

---

## 5. Đội hình Rừng Sương

### 5.1 Quy mô máu

**Chốt D8 của người dùng (2026-11-01): "Máu theo ngân sách của pack, chơi thử rồi chỉnh".** Năm quái mới lấy máu theo ngân sách pack; quái giữ lại (goblin, sói…) giữ nguyên số.

Công thức:

- Máu chuẩn anh hùng `H` = 200 (`kiem_si`).
- Máu thật trong trận = `boss_max_hp` × `region_normalize.hp_mult` (0,75 ở `ch1`) × `floor_scaling.hp_mult` (0,7 / 0,8 / 0,85 / 1,05 / 1,15 cho tầng 1–5).
- Tầng tham chiếu: **tầng 3**, hệ số `k` = 0,75 × 0,85 = **0,6375**.
- Quái thường: máu thật mục tiêu `T` = `r` × `H`, `r` trong 0,55–0,85. Tinh anh: `T` = `e` × một quái thường, `e` trong 1,5–2,2, quái thường gốc = 140 (Greycap, 0,70 × `H`).
- Máu viết = `T` / `k`, làm tròn tới số chục gần nhất.

| Quái | Tỉ lệ | Máu thật mục tiêu (tầng 3) | Máu viết (`boss_max_hp`) | Tầng 1 (×0,525) | Tầng 3 (×0,6375) | Tầng 5 (×0,8625) |
|---|---|---|---|---|---|---|
| `rootling` | 0,60 × `H` | 120 | **190** | 100 | 121 | 164 |
| `greycap_sporeling` | 0,70 × `H` | 140 | **220** | 116 | 140 | 190 |
| `mossbound_sentry` | 0,80 × `H` | 160 | **250** | 131 | 159 | 216 |
| `mistbriar_matron` (tinh anh) | 1,8 × 140 | 252 | **400** | — (tinh anh từ tầng 2) | 255 | 345 |
| `ancient_root_sentinel` (tinh anh) | 1,9 × 140 | 266 | **420** | — (tinh anh từ tầng 2) | 268 | 362 |

Quái thường hiện có (86–130 viết, 45–68 ở tầng 1, 74–112 ở tầng 5) **không đổi**; Phù thủy Rừng thuộc P2.4 (mục 7).

**Phù thủy Rừng (P2.4, D8, 2026-11-02):** boss = 4–7 × một quái thường (quái thường gốc 140 máu thật ở tầng 3). Chọn **5,5 × 140 = 770** máu thật tầng 3 → máu viết 770 / 0,6375 = 1208 → làm tròn **1210** (`boss_max_hp`). Tầng 1 (×0,525) 635, tầng 3 (×0,6375) 771, tầng 5 (×0,8625) 1044. Số khởi đầu, chơi thử rồi chỉnh. Đây là số khởi đầu, chơi thử rồi chỉnh (chỉ sửa `boss_max_hp` trong `chapters.json`).

~~Bảng cũ (đã thay bằng chốt D8 ở trên): spec **neo theo đội hình đang có** chứ không theo máu anh hùng (180–210).~~

| ~~Bậc~~ | ~~Máu viết (`boss_max_hp`)~~ | ~~Tầng 1 (×0,525)~~ | ~~Tầng 5 (×0,8625)~~ |
|---|---|---|---|
| ~~Quái thường hiện có~~ | ~~86–130~~ | ~~45–68~~ | ~~74–112~~ |
| ~~Quái thường mới~~ | ~~80–110~~ | ~~42–58~~ | ~~69–95~~ |
| ~~Tinh anh mới (≈ 1,6 × thường, pack 1,5–2,2)~~ | ~~155–165~~ | ~~—~~ | ~~134–142~~ |
| ~~Phù thủy Rừng~~ | ~~**300** (đang 162)~~ | ~~—~~ | ~~259~~ |

Sát thương neo theo đòn khối hiện có: 6 sát thương/ô → đòn 3 ô = 18. Chiêu thường 8–14, tinh anh 14–18, Phù thủy 8–22.

### 5.2 Quái thường mới (não `pattern`)

Cảnh báo 0,9–1,2 s. Một chiêu chính + một chiêu phụ.

**Rootling** (`rootling`) — 190 máu viết (5.1), sân `square`, `brain_set` `balanced`. Dạy: đừng đứng yên.

| Chiêu | Mẫu / anchor | windup | warning | Delivery | Hiệu ứng | Hồi | Cách né |
|---|---|---|---|---|---|---|---|
| `root_prick` | 1 ô, `on_player` | 0,4 | 0,9 | `GROUND_PROPAGATION` từ ô Rootling, `floor_run`, impact `thorns` | 8 sát thương + **Trói 0,7 s** [D2] | 2,4 | bước 1 ô bất kỳ |
| `creep` | `self`: dời 1 ô sang hàng kề trên nửa mình | 1,2 (ô đích viền Ngà, không đỏ) | — | — | không | 4,0 | đánh vào ô đích đã hiện |

`root_prick` weight 1,0; `creep` weight 0,5, chỉ khi người chơi vừa thả khối nhắm vào ô Rootling.

**Mossbound Sentry** (`mossbound_sentry`) — 250 máu viết (5.1), sân `rect`. Dạy: né vuông góc với thanh.

| Chiêu | Mẫu / anchor | windup | warning | Delivery | Hiệu ứng | Hồi | Cách né |
|---|---|---|---|---|---|---|---|
| `slab_tap` | thanh 2 ô `[[0,0],[1,0]]`, `on_player`, xoay 0/90/180/270 | 0,5 | 1,0 | `CASTER_TO_TARGET`, `square_streak`, impact `slash` | 14 | 2,8 | bước vuông góc với thanh |
| `brace` | `self` | 0,6 (cúi người rõ) | — | — | **Guard** +3 giáp trong 3 s [D5]; ô Sentry viền Ngà | 7,0 | Xuyên giáp, đánh trước khi cúi xong (phá phép), hoặc chờ 3 s |

**Greycap Sporeling** (`greycap_sporeling`) — 220 máu viết (5.1), sân `square` / `u_shape`. Dạy: tránh góc, vùng để lại.

| Chiêu | Mẫu / anchor | windup | warning | Delivery | Hiệu ứng | Hồi | Cách né |
|---|---|---|---|---|---|---|---|
| `spore_squares` | L 3 ô `[[0,0],[1,0],[0,1]]`, `on_player`, xoay 4 hướng | 0,5 | 1,1 | `SKY_TO_TARGET`, `falling_squares`, impact `poison` (hình) | 10 + **1 Rạn** (thay Độc) [D3] | 3,0 | rời góc; bước ra phía mở của chữ L |
| `seedbed` | 1 ô, `near_player`, không phải ô người chơi | 0,5 | 1,0 | `DIRECT_MANIFESTATION`, impact `thorns` | vùng **Bãi Gai** 3 s (6 sát thương, +1 Rạn — số hiện có) [D3] | 6,0 | đừng bước vào; F3 giữ lối ra |

### 5.3 Tinh anh mới (não `pattern`)

Cảnh báo 1,2–1,8 s cho chiêu phức tạp. Mỗi con **một cơ chế combo**, không nhân đôi sát thương. Mốc rễ dùng chung luật ở mục 7.

**Ancient Root Sentinel** (`ancient_root_sentinel`) — 420 máu viết (5.1), sân `rect`. Combo: mốc rễ → lưới cành theo hàng của mốc → lặp lại nếu mốc còn.

| Chiêu | Mẫu / anchor | windup | warning | Delivery | Hiệu ứng | Hồi | Cách né |
|---|---|---|---|---|---|---|---|
| `sentinel_anchor` (`marker`) | 1 mốc rễ, `enemy_half_empty`, `row: player` (ô trống trên **hàng hiện tại của người chơi** nếu có, cột ngẫu nhiên có seed; không có thì ô trống bất kỳ như cũ) | 0,6 | — (mốc hiện ngay) | `DIRECT_MANIFESTATION` | mốc sống 10 s; **chỉ vỡ với đòn ≥ 2 ô** phủ ô mốc | 9,0 | thả khối ≥ 2 ô lên mốc |
| `branch_net` | 3 ô liền trên `row_of_anchor`, bắt đầu từ cột trước, `clip` min 2 | 0,7 | 1,4 | `GROUND_PROPAGATION` từ ô mốc qua ranh giới, `floor_run`, impact `thorns` | 16; **Trói 0,8 s chỉ khi ô đầu (cột trước) trúng** [D2]; followup: lặp lại cùng hàng sau 2,5 s nếu mốc còn (cảnh báo 1,2 s) | 5,0 | rời hàng của mốc; phá mốc trước lần lặp |
| `bark_shift` | 1 ô, `near_player`, không phải ô người chơi | 0,5 | 1,2 | `DIRECT_MANIFESTATION`, impact `thorns` | vùng **Bãi Gai** 3 s thay cho "rào chắn" [D6] | 7,0 | không bước vào; né sang hướng còn lại |

Phần thưởng khi phá mốc: Sentinel **choáng 1,0 s** (đứng yên, không ra chiêu) và followup bị hủy.

**Mistbriar Matron** (`mistbriar_matron`) — 400 máu viết (5.1), sân `cross` (biến thể). Combo: một ô → hai nhánh vuông góc ở beat sau.

| Chiêu | Mẫu / anchor | windup | warning | Delivery | Hiệu ứng | Hồi | Cách né |
|---|---|---|---|---|---|---|---|
| `thorn_fork` | 1 ô `on_player`; followup 2 ô kề ô đầu theo **một trục** (trái+phải hoặc trên+dưới, AI chọn trục theo 3.7), `relative_to: first_cells` | 0,6 | 1,2; followup 0,75 | `SEQUENTIAL_CHAIN` từ ô Matron, `chain_spark`, impact `thorns` | 12; followup 12 mỗi ô | 4,5 | rời ô đầu theo **trục còn lại**; nhìn đỏ thứ hai rồi mới chạy |
| `wreath_guard` | `self` + 1 mốc vòng hoa `enemy_half_empty` | 0,8 | — | `DIRECT_MANIFESTATION` | `once`, khi máu ≤ 50 %: **Guard +5 giáp** đến khi mốc vỡ (tối đa 8 s) [D5]; mốc vỡ với đòn ≥ 1 ô | — | đập mốc vòng hoa; Xuyên giáp |

### 5.4 Quái giữ lại

`goblin_scout`, `wolf`, `goblin_warrior`, `dire_wolf`, `goblin_archer`, `goblin_brute`, tinh anh `goblin_chief`, `goblin_shaman`, `wolf_alpha`: **không đổi** (não khối, số như hiện tại). Không thêm chiêu mẫu cho chúng ở Phase 2.

### 5.5 Pool, độ đe dọa và thứ tự xuất hiện

Phase 2 giữ **một địch mỗi trận** [D7]. Ngân sách đe dọa của pack `06` §5 đọc theo một địch:

| Nút | Ngân sách | Thành phần |
|---|---|---|
| Trận (`battle`) | ≤ 1,0 | 1 quái thường |
| Hiểm địa (`danger`) | ≤ 1,6 | 1 quái thường (1,0) + trait vùng `row_burner` (0,5) |
| Tinh anh (`miniboss`) | ≤ 1,9 | 1 tinh anh; không ghép trait vùng |
| Kẻ Gác | — | Phù thủy (luật boss) |

Pool `ch1` đề xuất (thay khối `pools` hiện có):

| Pool | Bậc 0 | Bậc 1 | Bậc 2 |
|---|---|---|---|
| `battle` | goblin_scout, goblin_warrior, **rootling**, **mossbound_sentry** | wolf, dire_wolf, goblin_archer, goblin_warrior, **rootling**, **mossbound_sentry**, **greycap_sporeling** | dire_wolf, goblin_archer, goblin_brute, wolf, **greycap_sporeling**, **mossbound_sentry** |
| `danger` | — | wolf, goblin_archer, **greycap_sporeling** | dire_wolf, goblin_brute, goblin_warrior, **mossbound_sentry** |
| `miniboss` | — | goblin_chief, **ancient_root_sentinel** | goblin_shaman, wolf_alpha, **ancient_root_sentinel**, **mistbriar_matron** |
| `boss` | — | goblin_warlock | **forest_witch** [D11] |

**Tinh anh chỉ sau quái dạy nó** [D10]: khóa mới trong trận tinh anh `"teach_after": [...]`; bộ sinh bản đồ chỉ chọn tinh anh đó nếu trong chuyến leo đã đánh ít nhất một trận có id trong danh sách, ngược lại chọn tinh anh khác cùng bậc.

**Sửa sau P2.3 (người dùng duyệt, 2026-11-01): tinh anh rút được thì cột trận đầu phải dạy nó.** Bản đầu đổi tinh anh sang con khác khi cột đầu không tình cờ là quái dạy, nên Matron chỉ ở ~1 % bản đồ. Nay bộ sinh rút tinh anh như mọi id khác trong pool; nếu một tinh anh có `teach_after` được rút mà chưa có cột nào trước nó dạy, bộ sinh **ép cột sớm nhất trước nó gồm toàn nút `battle` / `danger`** (mọi nút trong cột, nên mọi đường đều qua một quái dạy) thành quái trong danh sách dạy, **hợp lệ trong pool của nút đó** ở bậc của cột (không có thì bậc thấp hơn gần nhất). Nút đã là quái dạy thì giữ; hai tinh anh trên cùng bản đồ dùng chung cột qua phần giao (Rootling dạy cả hai). Chỉ khi không cột nào dạy được mới đổi tinh anh sang con khác cùng bậc như cũ. Sau khi ép, nút `battle` / `danger` phía sau mà giờ trùng id với nút trước được rút lại trong pool của nó (giữ luật "không lặp khi pool còn"). Phép ép và rút lại dùng luồng rng riêng, nên luồng chính không đổi (khung cột, loại nút, nghỉ / kho báu / boss, tinh anh khác giữ nguyên) và vùng không có `teach_after` sinh y như trước; lượt cửa hàng / sự kiện không bao giờ thay nút của cột dạy.

Tần suất đo trên 100 000 bản đồ `ch1` (20 000 seed × 5 tầng, đã hạ 1 boss):

| | Trước | Sau |
|---|---|---|
| Bản đồ có Matron | 1 091 (1,1 %; 8,1 % các nút tinh anh bậc 2) | 3 369 (3,4 %; 24,9 % các nút tinh anh bậc 2) |
| Bản đồ có Sentinel | 2 236 (2,2 %; tầng 2: 24 % nút tinh anh bậc 1) | 5 584 (5,6 %; tầng 2: 49 % nút tinh anh bậc 1) |
| Cột đầu là Rootling / Mossbound / Greycap | 18,6 % / 18,6 % / 8,5 % | 25,7 % / 21,0 % / 10,0 % |

Chỉ ~22,5 % bản đồ tầng 2–5 có nút tinh anh (nút `miniboss` là một lựa chọn ngẫu nhiên của cột giữa), nên một tinh anh trong pool bậc 2 có 4 con chạm trần ~5,6 % bản đồ tầng 3–5; Matron nay ở đúng trần đó: 5,6 % bản đồ tầng 3–5 (trước 1,8 %). Muốn nhiều hơn nữa thì phải đổi trọng số pool hoặc tần suất nút `miniboss` (chưa làm).

| Tinh anh | `teach_after` | Lý do |
|---|---|---|
| `ancient_root_sentinel` | `rootling`, `mossbound_sentry` | Trói + thanh/hàng |
| `mistbriar_matron` | `greycap_sporeling`, `rootling` | vùng + "theo ô đỏ thứ hai" |

---

## 6. Trạng thái pack chưa có trong game

Không tự chế hệ mới. Mỗi mục là một **quyết định của người dùng**, có phương án nhỏ nhất được khuyến nghị:

| Pack | Có gì trong game | Khuyến nghị (nhỏ nhất) | Phương án khác |
|---|---|---|---|
| **Root** (Trói) | khóa bước `is_step_locked` (mover `step_lock_fn`), Ô rớt đã coi "bị trói" như Đóng Băng | **D2**: trạng thái `root` = khóa bước của người chơi trong N giây, vẫn thả khối được; chip riêng (rễ), tính là khóa cùng nhóm với Đóng Băng cho F4/F9; không có hệ số sát thương | Dùng thẳng Đóng Băng (rẻ hơn nhưng lẫn với Giá Lạnh/Ban Phước) |
| **Poison** (Độc) | không có (chỉ có hình impact `poison`) | **D3**: hoãn Độc sang Phase 4; Phase 2 dùng **Rạn 1 tầng** cho `spore_squares`, **Bãi Gai** cho `seedbed` | Làm Độc ngay (thêm hệ tick + trần + tương tác) |
| **Slow** (Chậm) | hệ số bước của ô lầy (`mire_step_mult`) | **D4**: Phase 2 thay bằng **Giá Lạnh 1 tầng** cho `entangled_row` | Chậm = nhân hồi bước ×1,3 trong 1,5 s qua đường ô lầy |
| **Guard** | giáp phẳng `boss_defense` + Xuyên giáp bỏ qua giáp | **D5**: Guard = **+giáp tạm thời** (+3 thường, +5 tinh anh, +6 Phù thủy); Xuyên giáp xuyên qua — có sẵn khắc chế | Khiên hút sát thương (cần mở rộng giáp của người chơi sang địch) |
| **Barrier** không phải hố (`bark_shift`) | Tường đã bị bỏ 31/10 | **D6**: dùng **Bãi Gai** 1 ô | Bỏ chiêu; hoặc đưa lại ô chặn (trái với spec 31/10) |

---

## 7. Phù thủy Rừng (`forest_witch`)

Sân `cross` biến thể (12 ô mỗi nửa, step_cd 0,33 s). Máu viết **300** [D8]. Logic 1 ô. `brain_set` `aggressive` cho phần di chuyển. **Bỏ trait `rotten_thrower`** khỏi Phù thủy (ném khối hỏng thuộc về Jailer và Reed Witch, không thuộc chủ đề rễ) [D12].

> **Ghi chú triển khai P2.4 (2026-11-02) — các chốt D8/D9/D13/D14 thay chữ cũ trong mục 7:** sân **`boss_hall` 6×4 mỗi bên** (D13; không còn `cross` / "logic 1 ô"), Phù thủy đứng **2×2 ô** (`footprint`), máu viết **1210** (D8, công thức ở 5.1), **bất tử 1,5 s** mỗi lần chuyển pha (D14, `transition.sec` 1,5 → `enemy_invulnerable_left`; máu vẫn kẹp ở ngưỡng nên một đòn không nhảy hai pha), `entangled_row` dùng **Làm chậm** (D4: hồi bước ×1,3 trong 1,5 s) thay Giá Lạnh. Các chỗ phải diễn giải:
> - Mốc rễ đặt trên ô trống bất kỳ của nửa Phù thủy (`row: any`), không dưới 4 ô của nó; khi một lần đặt 2 mốc (pha 2–3) thì 2 mốc ở **2 hàng khác nhau** nếu được, để `entangled_row` có hai hàng. Phù thủy không bước lên mốc (BossBrain coi ô mốc như hố, mover từ chối).
> - `entangled_row`: cửa sổ 3 ô liền bất kỳ trên hàng của mốc (không ép bắt đầu ở cột trước — sân 6 cột thì cột sau sẽ luôn an toàn), `clip` tối thiểu 2 ô; pha 2–3 `anchor_rows: 2` = cùng cửa sổ trên 2 hàng mốc mới nhất, giữ 2 hàng nếu qua F1/F2, không thì 1 hàng.
> - `branch_lattice`: L = `[[0,0],[0,1],[1,1]]`, followup 1 ô mới **kề ô cuối của L** (không trùng L), ưu tiên ô làm gần hàng mốc mới nhất; không mốc (hoặc đã nằm trên hàng mốc) thì AI chọn trong các ô kề.
> - `withered_crown`: làn 2 = thanh của làn 1 dời 1 hàng/cột vuông góc (`relative_to: first_shift`, xoay theo làn 1), hiện sọc chờ từ đầu, đỏ đầy khi làn 1 trúng, trúng sau 0,75 s.
> - `forest_last_knot`: `weight` 0 nên **chỉ** ra ở lần thứ 3, 6… của pha 3 (`every_nth` 3); "còn mốc" xét lúc RESOLVE (đập mốc trong lúc cảnh báo làm đòn còn 11 và bỏ followup).
> - Viền Ngà quanh 4 ô của Phù thủy hiện suốt windup **và** cảnh báo của 3 chiêu nặng (lúc Phá phép có tác dụng), không chỉ windup.
> - Chuyển pha: không có hạt vuông "rễ sẫm lại" riêng (hình thuộc P2.5); hiện tại thấy được bằng đỏ tắt + đứng yên 1,5 s.

### 7.1 Mốc rễ (cơ chế của pha)

- Mốc đặt trên **nửa của Phù thủy** (ô trống, không phải ô của nó, không hố) để người chơi đập được bằng khối; vẽ bằng code: ô vuông màu gỗ/hổ phách tối, **không đỏ, không phát sáng**.
- Hai nửa thẳng hàng nên mốc ở hàng r = **"hàng r bên bạn đang bị rễ nhắm"**: chiêu có anchor `row_of_anchor` đánh hàng đó.
- Mốc vỡ khi một đòn của người chơi có **ít nhất 1 ô** phủ ô mốc (pack: khối 1 ô khởi đầu phải phá được một mốc). Mốc sống 12 s.
- Phù thủy di chuyển không đi vào ô mốc.

### 7.2 Bảy chiêu

| # | Chiêu | Loại | Mẫu / anchor | windup | warning | Delivery | Hiệu ứng | recovery | Hồi | Cách né |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `root_nail` | C | 1 ô `on_player` | 0,4 | 0,9 (pack "1 beat" = 0,5 s, kéo lên cho F1) | `DIRECT_MANIFESTATION`, impact `thorns` | 8 + Trói 0,6 s [D2] | 0,6 | 3,0 | bước sang ngang |
| 2 | `branch_lattice` | C | L 3 ô `on_player`, xoay 4 hướng; followup 1 ô nối từ đầu L **về phía hàng của mốc** (không mốc: hướng AI chọn) | 0,5 | 1,2; followup 0,75 | `GROUND_PROPAGATION` từ ô đầu L, `floor_run`, impact `thorns` | 12; followup 8 | 0,8 | 4,0 | theo ô đỏ, không đoán hướng |
| 3 | `entangled_row` | H | 3 ô liền `row_of_anchor` (không mốc: `row_of_player`), `clip` min 2; pha 2–3 với 2 mốc: **hai hàng** nếu F2 cho phép, không thì một | 0,8 | 1,5 | `GROUND_PROPAGATION` từ ranh giới, `floor_run`, impact `thorns` | 18 + Giá Lạnh 1 tầng [D4] | 1,2 | 6,0 | sang hàng khác; phá mốc để đổi hàng |
| 4 | `moss_guard` | utility | `self`, viền Ngà, **không đỏ** | 0,6 | — | `DIRECT_MANIFESTATION`, impact `guard` | Guard +6 giáp khi còn ≥ 1 mốc, tối đa 10 s [D5]; `requires_anchor: 1` | 0,6 | 12,0 | đập mốc; Xuyên giáp |
| 5 | `root_anchor` | mechanic | `marker`, `enemy_half_empty`, `count` 1 (pha 1) / 2 (pha 2–3) | 0,6 | — | `DIRECT_MANIFESTATION` | đặt mốc (7.1) | 0,6 | 8,0 | đập mốc bằng khối bất kỳ |
| 6 | `withered_crown` | P2 | 2 làn, mỗi làn thanh 2 ô `on_player` xoay 0/90; làn 2 song song kề làn 1, `show_with_first: true` (sọc chờ) | 0,6 | 1,2; làn 2 trúng sau làn 1 **0,75 s** | `CASTER_TO_TARGET`, `square_streak`, impact `slash` | 12 mỗi làn | 1,2 | 5,0 | ra khỏi làn 1 về **phía không có** làn 2 |
| 7 | `forest_last_knot` | P3 finisher | T 4 ô `near_player` (phải chứa ô người chơi), xoay 4 hướng; followup ô giữa T | 0,9 | 1,6; followup 0,75 | `SEQUENTIAL_CHAIN` (`authored`: ba ô ngang rồi ô chân), `chain_spark`, impact `burst` | còn mốc: 22 + followup 14; **không còn mốc: 11, không followup** | 1,5 | — (`every_nth` 3) | phá mốc trước, hoặc đứng ô an toàn đã thấy |

Kiểm tra F2 trên sân `cross` 12 ô: trần 6 ô. T 4 ô (33 %), hai làn 4 ô (33 %), hai hàng × 3 ô = 6 (50 %, chạm trần — biến thể làm mất ô thì chỉ một hàng).

### 7.3 Pha

| Pha | Máu | Chiêu | Cơ chế (`favor_phase_mechanic`) | Ghi chú |
|---|---|---|---|---|
| 1 — dạy mốc | > 65 % | root_nail, branch_lattice, root_anchor (1), entangled_row | root_anchor | 4 chiêu |
| 2 — hai mốc + nhánh | 65–30 % | + moss_guard, withered_crown; root_anchor (2) | withered_crown | vào pha: đứng yên 1,5 s, "rễ sẫm lại" bằng hạt vuông, không sát thương, rồi đặt 2 mốc |
| 3 — nút thắt | < 30 % | + forest_last_knot | forest_last_knot | mỗi **lần ra chiêu thứ 3** là `forest_last_knot` nếu hợp lệ; vào pha: đứng yên 1,5 s |

Cửa sổ hồi sau chiêu nặng: `entangled_row` 1,2 s, `withered_crown` 1,2 s, `forest_last_knot` 1,5 s (F10). `entangled_row`, `withered_crown`, `forest_last_knot`: `interruptible: false` (viền Ngà khi niệm); bốn chiêu còn lại phá phép được [D9].

### 7.4 Thay đổi trong `chapters.json` của Phù thủy

- `boss_max_hp` 162 → 300; thêm `"brain": "pattern"`, `"enemy": "forest_witch"`; bỏ `traits: rotten_thrower`; `boss_drop_interval_mult` không còn tác dụng (giữ cho não khối nếu quay lại).
- `boss_step_cooldown_mult`, `boss_think_interval_sec`, `boss_reaction_sec`, `arena` giữ nguyên.

---

## 8. Nhu cầu hình (chỉ liệt kê — mỗi lần gọi PixelLab người dùng duyệt riêng)

Khung theo art bible: **quái thường 64×52** (mẫu tỉ lệ OSFE của Goblin Scout v3, chân ở hàng cuối, tâm chân x = 32, cao ~46). Tinh anh và Kẻ Gác cao hơn — kích thước khung là **[Quyết định D13]** (đề xuất tinh anh 64×64, Phù thủy 96×80). Không màu đỏ trên thân; không phát sáng. Trước khi duyệt hình gốc: nêu nhân vật nổi tiếng giống nhất và khác biệt hóa trong prompt.

| Địch | Clip (khung) | Ghi chú |
|---|---|---|
| Rootling | idle 2, move 2, windup 2, hit 2, defeat 4 (tan thành ô vuông) | nút rễ nhỏ, xám rêu #5E6B55 |
| Mossbound Sentry | idle 2, move 2, windup 2, **brace 2**, hit 2, defeat 4 | đá thấp, rêu trên vai |
| Greycap Sporeling | idle 2, move 2, windup 2, hit 2, defeat 4 | cụm nấm tím xám đục |
| Ancient Root Sentinel | idle 2, move 2, windup 2, hit 2, **stunned 2**, defeat 4 | thân dài, tán khối; đầu rễ hổ phách nằm ở mốc, không trên thân |
| Mistbriar Matron | idle 2, move 2, windup 2, **guard 2**, hit 2, defeat 4 | hình nộm vỏ cây trùm đầu, tay dây leo khô |
| Phù thủy Rừng | idle 2, move 2, windup_common 2, windup_heavy 2, phase_shift 3, hit 2, defeat 4 | mũ rễ cong, gậy rễ để bên hông, áo rêu dài; mảnh Primal Shard vàng lưới trên đầu |

**Vẽ bằng code, không cần gen:** ô đỏ sọc và sọc chờ (đã có), viền Ngà "không phá được" và Guard, mốc rễ / mốc vòng hoa (ô vuông 2×2 art-px), ô đích của `creep`, va chạm theo các gói `FloorVfx` có sẵn (`thorns`, `slash`, `burst`, `guard`, `poison`), hạt vuông chuyển pha. **Cần vẽ/gen (nhỏ):** chip trạng thái Trói 12×12 (có thể vẽ tay trong workbench miễn phí).

---

## 9. Thứ tự làm

Mỗi bước xong và xanh test mới sang bước sau (luật ADR).

| Bước | Việc | Test |
|---|---|---|
| **P2.2** Mô hình + AI | `enemy_skills.json` + loader có kiểm schema (báo lỗi rõ: chiêu thiếu `delivery`, anchor lạ, followup quá ngắn); dựng kế hoạch (anchor, xoay, clip); `FairnessCheck` thuần (4.1, F1–F10); `PatternBrain` (3.7) với RNG có seed; vòng đời (3.6) trong controller; pha + chuyển pha + kẹp ngưỡng; nhánh `brain` trong dựng trận; trạng thái Trói (nếu D2 duyệt) | unit: mỗi anchor, xoay, clip; snapshot (ô trúng = ô đỏ); ô nứt giữa cảnh báo bị bỏ và mất đỏ; 4.1 với hồi bước còn lại / bị khóa / ô lầy; trần đỏ; F4 không khóa chồng; trọng số AI tất định theo seed; nhịp tầng không nhân `warning_sec`; fixture 3 pha × 7 chiêu và 4 pha × 9 chiêu chạy hết, không sửa code (A4); hồi quy: mọi trận não khối cũ cho kết quả như trước |
| **P2.3** 5 quái mới | dữ liệu 5 địch + 15 trận/pool `ch1`; `teach_after` (nếu D10 duyệt); tên/mô tả `name_key` | mỗi chiêu qua F1–F3 trên **mọi sân `ch1` + 200 biến thể có seed mỗi sân**; mô phỏng không đầu 60 s mỗi địch: **bot né hoàn hảo** (đi theo đường FairnessCheck) nhận 0 sát thương, **bot đứng yên** nhận sát thương; generator 10 000 seed: không tinh anh mới nào trước quái dạy nó |
| **P2.4** Phù thủy | dữ liệu 7 chiêu, 3 pha, mốc rễ, Guard; cập nhật mục trận | ngưỡng 65/30 %, một đòn không vượt hai pha; chuyển pha không sát thương và tắt cảnh báo; mỗi lần thứ 3 ở pha 3 là `forest_last_knot`; đòn 1 ô phá được mốc; không mốc thì nút thắt 11 và không followup; `moss_guard` không dùng khi không có mốc; bot né hoàn hảo 0 sát thương 180 s mỗi pha |
| **P2.5** Hình | theo mục 8, từng lần gen được duyệt; ảnh gốc trước, chưa gen hàng loạt | ảnh giữ lại `production/qa/evidence/phase2-misty-forest/`: cảnh báo, followup, sọc chờ, mốc, Guard, chuyển pha, defeat — mỗi loài một ảnh trong trận |

---

## 10. Acceptance Criteria

- [ ] `enemy_skills.json` hợp lệ JSON, mọi chiêu có `delivery` đủ 4 phần; loader từ chối dữ liệu sai với thông báo rõ, không rơi về SKY_TO_TARGET.
- [ ] Trận không có `brain` (hoặc `"block"`) chạy y như trước Phase 2 (suite cũ xanh).
- [ ] Ô bị đánh lúc RESOLVE = ô đỏ chụp lúc cảnh báo bắt đầu, trừ ô vừa thành ô khóa (và ô đó mất đỏ ngay).
- [ ] Đường đi của delivery không gây sát thương ngoài ô của mẫu.
- [ ] Mọi kế hoạch và followup được dùng đều qua 4.1 với `reaction_margin_sec` 0,25 s; test có trường hợp vừa bước xong, đang Trói còn 0,5 s, đứng trên ô lầy.
- [ ] Không lúc nào ô đỏ (mọi nguồn) vượt 50 % sàn dùng được của người chơi.
- [ ] Không có Trói/Đóng Băng mới từ địch khi đang bị khóa hoặc trong 1,0 s sau khi hết khóa.
- [ ] Nhịp tầng 5 (×0,8) làm windup/hồi ngắn đi nhưng `warning_sec` không đổi.
- [ ] Mỗi trong 5 quái mới: bot né hoàn hảo 0 sát thương trong 60 s trên mọi sân `ch1` + 200 biến thể; bot đứng yên mất máu.
- [ ] Phù thủy: 3 pha ở 65 % / 30 %, chuyển pha 1,5 s không sát thương; bot né hoàn hảo 0 sát thương mỗi pha.
- [ ] Fixture 3 pha × 7 chiêu và 4 pha × 9 chiêu chạy hết mà không thêm code (A4).
- [ ] Không tinh anh mới nào xuất hiện trước quái dạy nó (10 000 seed), nếu D10 duyệt.
- [ ] Playtest: người chơi nói được "con này làm gì, né thế nào" sau trận đầu với mỗi loài mới (5/5 loài, ít nhất 3 người thử).
- [ ] Playtest: không ai gặp một đòn "không né được" mà không giải thích được bằng ô đỏ.
- [ ] Ảnh bằng chứng có trong `production/qa/evidence/phase2-misty-forest/` cho mọi thứ thấy được ở P2.3–P2.5.

## 11. Affected Systems

| Hệ | Ảnh hưởng | Việc |
|---|---|---|
| `assets/data/enemy_skills.json` (mới) | chiêu, địch, pha, AI, công bằng | thêm + schema trong spec này |
| `assets/data/chapters.json` (`ch1`) | 5 trận mới, pool mới, Phù thủy | sửa dữ liệu |
| `BossController` / dựng trận | nhánh theo `brain` | sửa + test |
| `BossBrain` | không đổi; phần di chuyển được gọi từ não mới | test hồi quy |
| `SkillDelivery`, `CutEffects`, `StatusEffects`, `ZoneRules` | dùng lại; thêm Trói (D2), Guard (D5) | sửa nhỏ + test |
| Bộ sinh bản đồ | `teach_after` (D10) | sửa nhỏ + test |
| HUD | ẩn ô khối boss với não `pattern`; chip Trói | sửa + ảnh |

## 12. GDD Update Required?

Có, sau khi duyệt: `design/game-mechanics.md` §2.6 (Trói, Guard nếu duyệt), §2.8 (hai loại não, luật công bằng), bảng quái Rừng Sương; `design/art/art-bible.md` nếu D13 đổi khung.

---

## 13. Quyết định cho người dùng

1. **D1 — Chỗ để dữ liệu chiêu.** Khuyến nghị: file mới `assets/data/enemy_skills.json`, trận trong `chapters.json` chỉ thêm `brain` + `enemy`. Khác: nhét tất cả vào `chapters.json`.
2. **D2 — Trói (Root).** Khuyến nghị: trạng thái `root` = khóa bước có sẵn (`is_step_locked`), vẫn thả khối được, chip riêng, cùng nhóm khóa với Đóng Băng. Khác: dùng thẳng Đóng Băng.
3. **D3 — Độc (Poison).** Khuyến nghị: hoãn sang Phase 4; `spore_squares` gây 1 Rạn, `seedbed` đặt Bãi Gai. Khác: làm Độc ngay.
4. **D4 — Chậm (Slow).** Khuyến nghị: thay bằng Giá Lạnh 1 tầng cho `entangled_row`. Khác: Chậm = hồi bước ×1,3 trong 1,5 s.
5. **D5 — Guard.** Khuyến nghị: +giáp tạm thời (+3 / +5 / +6), Xuyên giáp xuyên qua. Khác: khiên hút sát thương.
6. **D6 — "Rào chắn" của Root Sentinel.** Khuyến nghị: 1 ô Bãi Gai. Khác: bỏ chiêu; hoặc đưa lại ô chặn (ngược spec 31/10).
7. **D7 — Một địch mỗi trận ở Phase 2.** Khuyến nghị: có; trận hai địch ("Rootling + Sentry", "tinh anh + phụ") để sau map v2. Khác: làm trận nhiều địch ngay (cần chọn mục tiêu, HUD, ngân sách hai não).
8. **D8 — Quy mô máu.** Khuyến nghị: neo theo đội hình đang có (thường 80–110, tinh anh 155–165, Phù thủy 162 → 300). Khác: theo pack (thường 0,55–0,85 × máu anh hùng, boss 4–7 × thường) — sẽ làm mọi trận dài gấp 2–4 lần.
9. **D9 — Phá phép với chiêu mẫu.** Khuyến nghị: chiêu thường và tinh anh phá được trong windup/cảnh báo; ba chiêu nặng của Phù thủy không phá được (viền Ngà). Khác: không chiêu mẫu nào phá được; hoặc tất cả đều phá được.
10. **D10 — Tinh anh sau quái dạy nó.** Khuyến nghị: thêm `teach_after` vào bộ sinh bản đồ ngay ở Phase 2 (sửa nhỏ). Khác: chờ map v2 (Phase 3), tạm thời chỉ cho tinh anh mới vào pool bậc 2.
11. **D11 — Pool Kẻ Gác Rừng Sương.** Khuyến nghị: bậc 1 giữ `goblin_warlock`, bậc 2 chỉ `forest_witch`. Khác: giữ như hiện tại (bậc 2 rút ngẫu nhiên warlock/witch).
12. **D12 — Trait `rotten_thrower` của Phù thủy.** Khuyến nghị: bỏ (lệch chủ đề rễ). Khác: giữ ở pha 1.
13. **D13 — Khung hình tinh anh và Phù thủy.** Đề xuất: tinh anh 64×64, Phù thủy 96×80 (quái thường 64×52 theo Goblin v3). Cần người dùng chốt trước khi gen.
14. **D14 — Sát thương lúc chuyển pha.** Khuyến nghị: đòn vẫn trúng nhưng máu kẹp ở ngưỡng (không nhảy hai pha). Khác: Phù thủy bất khả xâm phạm 1,5 s.


## Chốt của người dùng (2026-11-01)

| # | Chốt |
|---|---|
| D1 | File mới `assets/data/enemy_skills.json` |
| D2 | Trói chân = cơ chế khóa bước như Đóng Băng, hình dây rễ; không chồng với Đóng Băng |
| D3 | Độc để Phase 4 |
| D4 | Làm chậm = hồi bước ×1,3 trong 1,5 s (số trong dữ liệu) |
| D5 | Guard = giáp tạm thời; Xuyên giáp bỏ qua hoàn toàn |
| D6 | "Rào chắn" của Ancient Root Sentinel đổi thành **ô rớt** (nứt 0,8 s, theo luật công bằng spec 31/10) — tinh anh này được dùng ô rớt |
| D7 | Một quái mỗi trận trong Phase 2; nhiều quái cùng lúc làm ở Phase 3 |
| D8 | Máu theo ngân sách của pack (chơi thử rồi chỉnh) — số và công thức ở 5.1 (máu viết 190 / 220 / 250 / 400 / 420, tham chiếu tầng 3) |
| D9 | Đồng ý (3 chiêu nặng của Phù thủy không bị phá phép, viền ngà) |
| D10 | Làm `teach_after` ngay trong Phase 2 — sửa sau P2.3: tinh anh rút được thì ép cột trận đầu thành quái dạy nó (5.5) |
| D11 | Đồng ý |
| D12 | Đồng ý (bỏ `rotten_thrower`) |
| D13 | **Boss to gấp 2–3 lần nhân vật và đứng trên nhiều ô** (thay luật "1 ô" của pack). Phù thủy rừng chiếm **2×2 ô**, sprite ~192×140; sân boss to hơn sân thường, đề xuất **6×4 mỗi bên** (dữ liệu, kiểm tra độ dễ nhìn trên điện thoại bằng ảnh chụp). Mỗi đòn trúng boss chỉ tính 1 lần dù phủ nhiều ô |
| D14 | Đổi giai đoạn: Phù thủy bất tử 1,5 s |
