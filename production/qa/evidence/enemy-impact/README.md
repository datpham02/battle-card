# Hiệu ứng chạm đất của quái — đo, và pack riêng đầu tiên cho boss

**Ngày:** 2026-11-17 ~00:3x–01:2x · phiên `monster-cast-anim` · Godot 4.6.3 · cây dùng chung với 15 phiên khác.
**Harness:** `tools/qa/enemy_impact_probe.gd`.

## 1. Hai chẩn đoán SAI trước khi tới chẩn đoán đúng

**Sai lần 1 — "bảng `impact_packs` rỗng, đó là lỗi".** Rỗng là **cố ý**: ghi chú trong `assets/art/vfx/cast/index.json`
nói từ 2026-11-01 các pack vẽ sẵn cho impact đã bị bỏ (chúng có đế hình thoi phát sáng nướng chết vào khung), thay
bằng `impact_style` — **mảnh vuông do code vẽ**, có đủ kiểu cho cả 11 impact và 4 travel. Con số "128/139 skill không
có hiệu ứng" của tôi **đếm bảng pack mà bỏ qua đường code**, tức đếm sai thứ.

**Sai lần 2 — "màu khối của quái quá nhạt nên chìm".** Đo thì ngược lại: sàn nơi đòn rơi xuống là `#5A5C57`,
**V = 0,35 — tối**, nên cặp `#CFC6B4`/`#EFE6D2` của quái có **tương phản cao nhất** trong năm cặp thử (3,99 / 5,45);
mọi cặp đậm và rực hơn tôi đề xuất đều **kém hơn**. Đổi màu sẽ làm hiệu ứng chìm thêm.

**Và một phép đo sai vật.** Lần đầu tôi diff toàn màn hình: 13–21 nghìn pixel đổi, trải khắp bàn cờ. Đó là **rung
bàn cờ** lúc trúng đòn, không phải hiệu ứng. Phải đếm **theo đúng màu của hiệu ứng** mới ra số có nghĩa.

## 2. Chẩn đoán đúng: khác nhau ở ĐẲNG CẤP hiệu ứng

| | Quái (trước) | Hero |
|---|---|---|
| Hiệu ứng chạm đất | mảnh vuông do code vẽ, **0,22 s** | mảnh vuông **+ pack vẽ riêng** |
| Khung hình | trong ô | **106×88 px**, gần gấp đôi ô 64×46 |
| Thời lượng | 0,22 s | **0,35 s** |

Hero có pack riêng cho kỹ năng đặc trưng (`impact_burst_big_steel`, `impact_flame_burn`,
`impact_eruption_tram_dia`); quái chỉ có hệ dùng chung. Đó là khác biệt **thiết kế**, không phải lỗi.

## 3. Thay đổi: mỗi skill được khai pack riêng

Bốn file, ~20 dòng:

| File | Sửa |
|---|---|
| `src/combat/skill_delivery.gd` | `normalize()` mang `delivery.impact_pack` đi tiếp |
| `src/art/cast_vfx.gd` | thêm `impact_pack_for(delivery)` — pack riêng trước, bảng `impact_packs` sau |
| `src/combat/combat_view.gd` | chọn pack bằng hàm mới |
| `src/battle/overlay_layer.gd` | hỏi **cùng** hàm ấy khi quyết "pack đã chiếm ô chưa" |

**Hai cái bẫy, không cái nào có tín hiệu báo:**

1. `normalize()` **vứt mọi khoá nó không biết**. Thêm `impact_pack` vào JSON mà không dạy hàm này thì dữ liệu biến
   mất lặng lẽ giữa file và engine — skill vẫn chạy, pack không bao giờ tới.
2. View và overlay **phải trả lời giống nhau** về "pack đã chiếm ô chưa". Lệch nhau thì mảnh-code vẽ chồng lên
   pack — hai hiệu ứng trên một ô. Vì vậy gom vào **một hàm duy nhất**, lý do ghi trong doc comment.

Pack đầu tiên: `ogre_club` (Ogre Vương) → `impact_smash_big_root`, dựng bằng `tools/fx-pipeline` (code vẽ, miễn phí,
tất định), qua hết phép kiểm của nó: alpha 0/255, màu trong bảng master, không chạm đỏ báo đòn `#E5293B`, viền
1 px, **0 pixel lẻ**, overlay ≤ 0,35 s.

## 4. Đo sau khi lắp — và phép thử hai chiều

Pack dùng ramp `root` (`#66523F`, `#9A7D5E`, `#B89A6A`). `#CFC6B4` là màu thân của mảnh-code và **không** nằm trong
ramp đó, nên nó tách sạch hai nguồn. (`#EFE6D2` nằm trong **cả hai**, nên nó không phân biệt được gì — ghi riêng.)

| Skill | `#CFC6B4` (chỉ mảnh-code) qua 6 khung |
|---|---|
| `ogre_club` — **có pack** | **+0 +0 +0 +0 +0 +0** |
| `scout_stab` — không pack | +220 +200 +344 +284 +256 +212 |

Mảnh-code **tắt hoàn toàn** đúng ở skill có pack, và **vẫn chạy** ở skill không có. Không vẽ chồng, và thay đổi
không phá đường cũ. Pack vẽ ra: `#B89A6A` **+1 576** px từ khung đầu, thêm `#9A7D5E` ở khung 4–6.

Đỉnh pack ≈ **3 900 px** so với đỉnh mảnh-code ≈ **1 760 px**, và kéo dài 0,35 s thay vì 0,22 s.

## 5. Một lần chụp sai, giữ lại làm bài học

Lần chụp đầu báo `SHOT after skill=ogre_grab impact=knockback` — **bắt nhầm skill**. Harness lấy skill đầu tiên
tung ra, mà Ogre túm trước khi đập. Ảnh **thật và vô dụng**: đúng kỹ thuật, nhầm kỹ năng. Nếu chỉ nhìn ảnh rồi đếm
pixel thì đã có một con số về `ogre_grab` được gọi là bằng chứng cho pack của `ogre_club`.

Đã thêm tham số `[skill_id]` và ghi lý do vào đầu harness. Bộ ảnh sai đã xoá.

## 6. Chưa làm

- **Năm boss còn lại chưa có pack**: `sphinx_sandfall` (shatter), `matriarch_toxic_croak` (poison),
  `mist_lord_whiteout` (freeze), `dragon_tempest` (burst), `lord_cinder_lane` (burn — đã có flame qua
  `travel_impact_packs`, cần xem có đủ chưa). Ramp `poison` và `freeze` **chưa tồn tại** trong
  `tools/fx-pipeline/palettes.json`; màu đã có sẵn trong `impact_style` nên thêm ramp là việc dữ liệu.
- Phép đo chỉ lấy ~0,1 s đầu của pack 0,35 s: 6 khung render ở ~16 ms chỉ phủ 2 khung VFX ở 50 ms.
- Chưa ai xem pack này **trong trận thật ở tốc độ thật** ngoài ba khung tĩnh.


---

## 7. Ảnh giữ lại, và ảnh đã xoá (2026-11-17 03:4x)

Lần đo này sinh ra 118 ảnh qua nhiều vòng sửa cả tính năng lẫn dụng cụ đo. Giữ hết thì thư mục bằng chứng
thành vô dụng — người đọc phải đoán tiền tố nào là bản đúng. Giữ lại **65 ảnh**, bốn bộ:

| Tiền tố | Nội dung |
|---|---|
| `before_scout_stab_*` | nền so sánh: mảnh vuông do code vẽ, trước khi có pack nào |
| `pack_*` (5 boss) | nhịp nổ, sau khi mỗi boss có pack riêng |
| `lead_*` | bản bốn nhịp hoàn chỉnh: tụ lực ở cuối cảnh báo, rơi, nổ, vết |
| `dbg2_*` | **giữ lại một bộ HỎNG làm hồ sơ**: ảnh "lúc báo đòn" chụp quá sớm nên không có cả vạch đỏ |
| `after_ogre_club_*` | lần đầu Ogre có pack riêng — bộ đo ra `#CFC6B4 = +0`, tức mảnh-code đã tắt |

Đã xoá 53 ảnh của các vòng đã bị thay thế (`after_ogre_grab_` — bộ chụp nhầm skill, `beats_`, `dbg_`, `dbg3_`, `three_`, `fall_`). Chúng
**dựng lại được** bằng chính harness trong repo với tham số ghi ở đầu file, nên xoá không mất thông tin nào:

```
godot --audio-driver Dummy --path . -s res://tools/qa/enemy_impact_probe.gd -- <out> <chapter> <match> <tag> [skill_id]
```

`dbg2_` được giữ lại có chủ ý. Nó là bằng chứng cho một kết luận SAI mà tôi suýt báo cáo ("nhịp tụ lực không
chạy"), và lý do nó sai — không có vạch đỏ trong ảnh — là thứ chỉ nhìn thấy được khi còn ảnh.


---

## 8. `ogre_club`: DIRECT_MANIFESTATION -> GROUND_PROPAGATION (2026-11-17 ~04:5x)

Người dùng: *"sao boss cầm vũ khí dơ lên đập xuống trong không khí rồi tự nhiên có hiệu ứng ở ô vậy?"*

**TÔI ĐÃ NÓI SAI HAI LẦN rằng đổi kiểu này đụng gameplay.** Chú thích trong `src/combat/skill_delivery.gd`
nói ngược lại: *"damage itself still lands at the resolve, D1 — these times only drive the per-cell impacts,
the hit flash and the HIT label"*. Thời gian theo kiểu giao đòn chỉ điều khiển **hình ảnh**. Tôi để người
dùng chờ qua hai lượt vì một rủi ro không tồn tại, trong một dòng chú thích lẽ ra phải đọc trước khi cảnh báo.

| | Trước | Sau |
|---|---|---|
| `type` | DIRECT_MANIFESTATION | **GROUND_PROPAGATION** |
| `origin` | target_cells | **origin_cell** (ô con Ogre đứng) |
| `travel` | none | **floor_run** + pack `travel_shock_root` |

### Đo: hiệu ứng có ĐI từ đâu tới đâu không

Đếm pixel màu nâu đá xuất hiện mới, theo **cột màn hình** (mỗi cột 80 px), từng khung:

| Khung | Cột sáng lên |
|---|---|
| f1–f3 | (chưa có) |
| f4 | **c8**: 32 px |
| f5 | **c8**: 56 px |
| f6 | **c7**: 84 px · **c8**: 152 px |

Bắt đầu ở cột 8 (phía con Ogre), lan sang cột 7 (phía hero). **Hiệu ứng có hướng và có điểm xuất phát** —
đó chính là thứ người dùng nói là đang thiếu. Phép đo này là về THỨ TỰ THỜI GIAN, không phải về số lượng
pixel; nó trả lời "đi từ đâu tới đâu", câu mà mọi phép đếm trước đó không chạm tới.

### Hệ quả về âm thanh, kiểm trước khi đổi

Bảng `audio_events.json` tra theo `delivery.type`. `DIRECT_MANIFESTATION` không có mục riêng nên rơi về `*`;
`GROUND_PROPAGATION` **có**, và nó thêm `skill.generic.travel`. Nên cú đập giờ vừa nhìn thấy vừa nghe thấy là
có thứ gì chạy tới. Trùng hợp có lợi, nhưng đã đi kiểm trước chứ không để nó tự lộ ra.

### Còn lại

32 skill khác vẫn khai `DIRECT_MANIFESTATION` trong khi đánh vào ô ở xa (`near_player` / `enemy_half_empty`).
Giờ đã biết việc đổi là **hình ảnh thuần tuý**, nên rào cản duy nhất còn lại là thẩm mỹ: không phải đòn nào
cũng nên chạy dọc sàn (một tiếng hét, một lời nguyền thì không).
