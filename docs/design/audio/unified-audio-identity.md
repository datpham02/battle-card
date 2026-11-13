# Bản sắc âm thanh thống nhất — hướng mới (2026-11-13)

> Thay thế hướng "audio theo từng unit" của Phase 4 multi-enemy.
> Trạng thái: **đề xuất, chờ người dùng duyệt.** Chưa sinh file âm thanh, chưa sửa code.

## 1. Quyết định của người dùng

- Cả game dùng **một bản sắc âm thanh duy nhất**, theo triết lý Minecraft: đơn giản,
  dễ nhận ra, dễ chịu, tối giản — không điện ảnh, không kịch tính hoá.
- **Không có bộ âm riêng cho từng quái, từng unit hay từng chỉ số index.**
- Hành động khác nhau **vẫn được** có tiếng khác nhau, miễn cùng một ngôn ngữ thiết kế.
- Không định tuyến audio theo index quái, trừ khi một mục đích gameplay khác bắt buộc.
- Tránh phát quá nhiều tiếng: cân nhắc tần suất, chồng lấn, biến thiên cao độ, độ ưu tiên.
- Kiến trúc giữ đơn giản, dễ bảo trì. Không nạp sẵn một kho âm thanh lớn.

## 2. Hiện trạng đã kiểm (13/11/2026)

### 2.1 Kiến trúc

`GameFlow` → `AudioRig` → `AudioDirector` (+ `AudioBank`, `VoicePool`) → `UiAudioBridge`
và `CombatAudioBridge`. Các bridge **chỉ nghe tín hiệu**, không ghi gameplay và không
đụng RNG toàn cục (`combat_audio_sync_test` chứng minh log va chạm, HP và đồng hồ giống
hệt nhau khi bật và tắt audio).

Kết luận quan trọng: **hệ hiện tại vốn đã toàn cục và không theo vị trí.**
`AudioDirector._ensure_players` dựng sẵn `AudioStreamPlayer` thường — không phải 2D,
không pan, không toạ độ. Cue không mang vị trí. Vì vậy hướng mới **không phải xây thêm**,
mà là **bỏ bớt** phần định tuyến theo unit đã dự kiến cho Phase 4.

### 2.2 Kho âm thanh

| Số liệu | Giá trị |
|---|---|
| Event khai báo trong `assets/data/audio_events.json` | 67 |
| File `.wav` khác nhau | 74 |
| Cách sinh file | `tools/audio/sfx_synth.py` — thư viện chuẩn, tất định, có `--check` |
| Event thực sự được phát bởi code | 50 |
| Event khai báo nhưng **chưa nối** | 17 |

17 event chưa nối: `block.confirm`, `block.invalid`, `block.slot_full`, `card.highlight`,
`card.unavailable`, `card.ready`, `combat.crit`, `combat.death`, `combat.lock`,
`warn.boss.recovery`, `warn.terrain.vent`, `skill.hoa_loi.charge / prime / seal / tick`,
`skill.ngan_kiem.charge / commit`.

### 2.3 Cơ chế đã có, hợp với hướng mới

| Cơ chế | Nơi khai báo | Vì sao hợp |
|---|---|---|
| Lệch cao độ ngẫu nhiên ±1.5 nửa cung | `defaults.pitch_semitones` | Đúng thủ pháp Minecraft: ít file, nghe không lặp |
| Lệch âm lượng ±2 dB | `defaults.gain_jitter_db` | Như trên |
| Nhiều file biến thể mỗi event | `events[].files` | `combat.hit.enemy` đã có 2 biến thể |
| Gộp theo cooldown | `voice_pool.gd` `_last_start` | Nhiều nguồn cùng lúc → **một** tiếng to hơn, không chồng |
| Trần voice theo event / bus / tổng | `max_voices`, `voice_caps` | Chặn bùng nổ tiếng |
| Ducking 0.4 s | `duck` | Giữ tiếng quan trọng nổi lên |
| Lớp archetype `delivery × impact × phase` | `archetypes` | Đúng tinh thần "dùng lại một bộ nhỏ" |

Nói cách khác, **bốn trong sáu yêu cầu của hướng mới đã có sẵn trong kiến trúc.**
Việc còn lại là kỷ luật nội dung, không phải code.

### 2.4 Chỗ lệch hướng mới

| Vấn đề | Vị trí | Nhận xét |
|---|---|---|
| 22/67 event là bộ riêng của **ba lá bài** (`tram_dia` 6, `ngan_kiem` 7, `hoa_loi` 9) | `cards` | Đi ngược "một bộ nhỏ dùng lại". Nhưng Trảm Địa đã được người dùng **duyệt**, nên cần quyết định riêng — xem §6. |
| 9 biến thể `skill.impact.*` | `archetypes` | Đây là 9 **chất liệu va chạm**, không phải 9 con quái. Giữ được, nhưng có thể gộp còn 6. |
| Hai đường cùng phát `warn.boss.windup` | `combat_audio_bridge` `_on_swing_started` và `_on_stage_changed` | Hiện chỉ nhờ cooldown 150 ms che đi. Nên chọn một nguồn. |

## 3. Nguyên tắc bản sắc chung

1. **Ngắn.** Tiếng phản hồi ≤ 200 ms, tiếng cảnh báo ≤ 400 ms. Không drone chờ.
2. **Một chất liệu, nhiều cao độ.** Thà một tiếng gõ dùng lại với pitch khác nhau còn hơn
   năm tiếng gõ khác nhau.
3. **Không mô phỏng điện ảnh.** Không swell, không riser, không reverb hội trường.
4. **Phân biệt bằng hành động, không bằng chủ thể.** Người chơi nghe "có cú đánh trúng",
   không nghe "con quái số 2 bị đánh".
5. **Im lặng là mặc định.** Một sự kiện chỉ có tiếng khi người chơi cần biết nó vừa xảy ra
   mà mắt có thể bỏ lỡ.
6. **Ưu tiên rõ ràng.** Cảnh báo > phản hồi đòn > UI > nền. Trần bus Warning đang là 2 voice,
   phù hợp để chuông cảnh báo không bị lấp.

## 4. Bộ âm tối thiểu theo nhóm

| Nhóm | Đang có | Thiếu | Đề xuất |
|---|---|---|---|
| UI | `ui.tap`, `ui.toggle`, `ui.back`, `card.menu_open`, `card.choose` | — | Đủ. Nối hoặc xoá 3 event card chưa dùng |
| Di chuyển / tương tác | `block.pickup`, `block.select`, `block.place` | **tiếng bước của hero khi sang ô** | Thêm **1** event `move.step`, pitch jitter, cooldown ~80 ms |
| Kích hoạt bài / chiêu | `card.choose`, `skill.generic.windup`, `skill.generic.commit` | — | Đủ |
| Va chạm đòn | `skill.impact.*` (9) | — | Giữ, cân nhắc gộp còn 6 chất liệu |
| Sát thương / trúng đòn | `combat.hit.enemy`, `combat.hit.player`, `combat.hp_low` | — | Đủ. `combat.crit` nên nối hoặc xoá |
| Chặn / đỡ | `combat.parry`, `combat.interrupt` | tiếng **dựng Guard** | Dùng lại `combat.parry` ở cao độ thấp hơn, không thêm file |
| Nhặt vật phẩm | — | **nhặt điểm rơi trên sân** | Thêm **1** event `pickup.point` |
| Trạng thái | `status.burn.*` (4) | Rạn, Hàn, poison, mark, ward, trap | Thêm **2** event chung `status.apply` / `status.expire`, phân biệt bằng cao độ theo loại — **không** một tiếng cho mỗi trạng thái |
| Chuyển lượt | — | — | Không áp dụng: trận đánh là thời gian thực, không có lượt |
| Thắng / thua | `flow.victory`, `flow.defeat` | — | Đủ |
| Nền | — | lớp nền theo vùng | **Hoãn.** Chỉ làm sau khi bộ SFX ổn định |

**Tổng số event mới cần thêm: 4** (`move.step`, `pickup.point`, `status.apply`,
`status.expire`). Mỗi event 2 biến thể, sinh bằng `sfx_synth.py` → khoảng 8 file.
Đây là mức tăng nhỏ, đúng yêu cầu "không nạp kho lớn quá sớm".

## 5. Quy tắc thêm tiếng mới

Một event mới chỉ được thêm khi trả lời "có" cho cả ba câu:

1. Người chơi cần biết việc này ngay cả khi không nhìn vào chỗ đó?
2. Không event nào đang có diễn tả được nó, kể cả khi đổi cao độ hoặc tầng kích thước?
3. Nó xuất hiện ở nhiều hệ thống, không chỉ một lá bài hoặc một con quái?

Nếu câu 3 là "không", dùng lớp `archetypes`, không tạo bộ riêng.

## 6. Ảnh hưởng tới Phase 4 multi-enemy

### Bỏ khỏi Phase 4

- Định tuyến audio theo unit key.
- Tag `swing:` / `channel:` / `body:` tách theo từng unit.
- Cue windup, cancel, channel riêng cho actor của unit 1+.
- Đặt vị trí / pan theo ô của từng unit.
- Test "audio nhận cue windup từ actor unit k một lần".

Một lỗi mà hướng mới **tự xoá**: `audio_event_rules.on_impact_resolved` tính nạn nhân là
`SIDE_ENEMY` nên khi người chơi đánh unit 2 nó huỷ body tag của unit 1. Khi cả phe địch
là **một nguồn âm thanh duy nhất**, cách tính đó trở thành đúng theo định nghĩa.

### Giữ lại trong Phase 4 (ba việc nhỏ, không thêm file âm thanh)

| # | Việc | Vì sao |
|---|---|---|
| A | Nối `CombatState.unit_damaged` vào **chính** `combat.hit.enemy` | Hiện chỉ unit 0 có tiếng trúng đòn; unit 1+ im lặng. Cooldown 60 ms tự gộp nhiều unit thành một tiếng. |
| B | Cảnh báo của mọi PatternController dùng **một tag chung + đếm tham chiếu** | Hiện chỉ pattern của unit 0 tới được audio. Nếu nối thẳng, `warning_cleared` của một unit sẽ tắt chuông của unit còn lại, vì tag chỉ khoá theo `skill_id`. Đây là việc khó duy nhất. |
| C | Chọn một nguồn duy nhất cho `warn.boss.windup` | Bỏ đường trùng, không còn dựa vào cooldown để che. |

Cả ba đều nằm trong `src/audio/`, **không** đụng code gameplay.

## 7. Quyền sở hữu

`src/audio/*` thuộc phiên audio foundation (stream C). Phase 4 cần **bàn giao** trước khi
sửa `combat_audio_bridge.gd` và `audio_event_rules.gd`. Hiện các file này sạch trong git.

## 8. Quyết định đã duyệt (người dùng, 13/11/2026)

Người dùng duyệt cả bốn hướng dưới đây, **kèm điều kiện kiểm tra tham chiếu trước khi xoá**.
Đây là định hướng audio chính thức để Phase 4 triển khai.

1. **Giữ ba bộ âm riêng** của Trảm Địa, Ngàn Kiếm, Hoả Lôi. Từ nay `archetypes` là mặc định:
   chiêu mới không được có bộ âm riêng trừ khi §5 cho phép.
2. **Nối `combat.crit`, `block.invalid`, `warn.terrain.vent`**; phần còn lại xử lý theo §8.1.
3. **Duyệt 4 event mới** ở §4 (`move.step`, `pickup.point`, `status.apply`, `status.expire`),
   khoảng 8 file sinh bằng `sfx_synth.py`.
4. **Hoãn lớp nền theo vùng** tới sau Phase 4.

### 8.1 Kết quả kiểm tra tham chiếu (13/11/2026) — chỉ 2 event được xoá, không phải 14

Đã quét toàn repo (`.gd`, `.py`, `.sh`, `.md`, `.json`) cho từng id, cộng mọi chuỗi trong
`audio_events.json` ngoài chính mục của nó, cộng rủi ro ghép id động qua bảng `cues` và
`archetypes` / `cards`. Khuyến nghị "xoá 14" trong bản trước là **sai**; đây là số đúng:

| Nhóm | Event | Vì sao |
|---|---|---|
| **Xoá được (2)** | `block.confirm`, `block.slot_full` | Không nơi nào tham chiếu, chỉ có tên trong tài liệu và `CREDITS.md` |
| **Nối, đừng xoá (3)** | `combat.death`, `combat.lock`, `warn.boss.recovery` | Đã có file, đã có chỗ dùng rõ ràng: quái chết, bị khoá bước, cửa sổ hở sau đòn. Đều là thông tin người chơi cần nghe |
| **Giữ nguyên, tắt có chủ ý (6)** | `skill.hoa_loi.charge / prime / seal / tick`, `skill.ngan_kiem.charge / commit` | **Không phải code chết.** `audio_event_rules_test` khẳng định chúng *không* kêu ("silent by design", đúng luật "không drone chờ"), rồi bật lại qua bảng `cards` để chứng minh cơ chế vẫn chạy. Còn 300+ dòng trong timeline QA `production/qa/evidence/skill-audio/`. Xoá là làm hỏng test và mất một khả năng đã được kiểm chứng |
| **Giữ, thuộc API cue (3)** | `card.highlight`, `card.unavailable`, `card.ready` | Gọi được qua bảng `cues`; `card.ready` còn là chủ thể của một test chế độ giảm âm |

Tức là 6 event "chưa nối" thực ra là **đã tắt có chủ ý và có test khoá lại**, đúng tinh thần
§3 nguyên tắc 5. Chúng ở lại.

### 8.2 Việc còn lại sau khi duyệt

- Bộ âm mới (§4) và 5 event cần nối ở §8.1 **chưa triển khai**: chờ Phase 4 và chờ bàn giao
  `src/audio/*` từ phiên audio foundation (stream C).
- `docs/skill-v2/10-audio-system-design.md` nên có một dòng trỏ sang tài liệu này. File đó
  thuộc phiên khác nên multi-enemy không tự sửa.

## 9. Quyết định mới (người dùng, 13/11/2026): mỗi skill một giọng riêng, chung chất liệu

Thay §8 mục 1 ("archetype là mặc định, chiêu mới không có bộ âm riêng"). Người dùng hỏi "các âm thanh đều khớp với
hiệu ứng skill chứ, không tái sử dụng cho toàn bộ skill?" và chọn **làm biến thể**:

- Mỗi skill có **tiếng vung và tiếng va chạm của riêng nó** (`skill.card.<id>.windup` / `.impact`), sinh miễn phí
  bằng `tools/audio/sfx_synth.py` từ bảng `tools/audio/card_voices.json`.
- Bảng đó do `tools/audio/card_voices.py` dựng **từ dữ liệu VFX**: hình dạng va chạm (`impact_variants.form`:
  ring, double, stab4, bell, jaw, spring...) → cùng cử chỉ bằng âm thanh; mỗi nhóm chất liệu một quãng, mỗi skill
  một bậc riêng trên cùng thang ngũ cung; độ dài theo thời lượng VFX (≤ 0,4 s); tiếng vung theo `cast_presentation`
  hoặc kiểu phóng.
- Vẫn **một bản sắc chung**: cùng năm chất liệu, cùng thang âm, cùng giới hạn độ dài, không drone, không riser.
- Lớp `archetypes` giữ lại làm **dự phòng** cho chiêu mới chưa có giọng; `card_voices.py --check` báo khi thiếu.
- Ba bộ tay của Trảm Địa, Ngàn Kiếm, Hoả Lôi giữ nguyên.
