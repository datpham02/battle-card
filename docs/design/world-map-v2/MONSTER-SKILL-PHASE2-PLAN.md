# Monster Skill Phase 2 — Sa Mạc + Đầm Lầy (kế hoạch, chưa triển khai)

Bước 2 của lộ trình `MONSTER-SKILL-DESIGN.md` §11: chuyển 18 quái của hai vùng sang pattern brain.
Thiết kế skill đã có sẵn ở §4.3 (Sa Mạc, 9 quái) và §4.4 (Đầm Lầy, 9 quái). Tài liệu này là **research +
planning**, chưa sửa dòng code hay dòng data nào.

Tiền đề: Phase 0 (nền) và Phase 1 (Hỏa Ngục) đã xong và đã push — `1d859a17` và `0effb9c9`.

---

## 1. Hiện trạng 18 quái

Cả 18 đều **đã có trong `chapters.json`** và đang chạy **block brain**. Chưa quái nào có entry trong
`enemy_skills.json`. Arena thiết kế yêu cầu (`dunes`, `oasis`, `bog`, `reed_maze`) **đều đã tồn tại**
trong `arenas.json`, nên không phải dựng arena mới.

### Sa Mạc (`desert`, tầng 3) — 9 quái

| id | tier | arena | HP | trait hiện có | skill thiết kế |
|---|---|---|---|---|---|
| `dune_jackal` | Normal | dunes | 90 | — | jackal_pack_nip |
| `sand_beetle` | Normal, def 2 | dunes | 106 | — | beetle_sand_spray |
| `dust_nomad` | Normal | oasis | 116 | — | nomad_ambush, nomad_veil_step |
| `mirage_sprite` | Normal | dunes var | 124 | — | sprite_mirage, sprite_shimmer_lash |
| `scarab_guard` | Normal, def 2 | oasis var | 140 | — | scarab_shield_wall, scarab_spear |
| `sun_archer` | Normal | dunes var | 152 | `row_burner` | archer_blinding_arc |
| `sand_burrower` | Elite | dunes | 84 | `burrow` | burrower_undertow, burrower_sinkhole |
| `scorpion` | Elite | oasis | 96 | `riposte` | scorpion_venom_sting, scorpion_pincer_hold |
| `sand_sphinx` | Boss | oasis var | 175 | `sandstorm` | sphinx_gaze, sphinx_claw, sphinx_bury, sphinx_shift, sphinx_sandfall |

### Đầm Lầy (`swamp`, tầng 4) — 9 quái

| id | tier | arena | HP | trait hiện có | skill thiết kế |
|---|---|---|---|---|---|
| `bog_rat` | Normal | bog | 88 | — | rat_gnaw |
| `mire_slug` | Normal | bog | 104 | — | slug_slime_trail |
| `swamp_lizard` | Normal | reed_maze | 112 | — | lizard_tail_sweep, lizard_drag_bite |
| `marsh_toad` | Normal | bog var | 126 | — | toad_tongue |
| `reed_witch` | Normal | reed_maze var | 138 | `rotten_thrower` | witch_rot_cloud |
| `bog_hound` | Normal | bog var | 150 | `row_burner` | hound_mire_chase |
| `spore_cap` | Elite | bog | 70 | `spore_burst` | spore_puff, spore_regrow |
| `leap_frog` | Elite | reed_maze | 80 | `hop_skip` | frog_leap_slam, frog_croak |
| `toad_matriarch` | Boss | bog var | 170 | `bog_spread`, `seal_caster` | matriarch_spit, matriarch_tongue_lash, matriarch_sink, matriarch_toxic_croak, matriarch_regrow |

---

## 2. Engine: Phase 0 đã đủ, **không cần code nền mới**

Đã đối chiếu từng cơ chế hai vùng cần với `pattern_controller.gd` / `pattern_planner.gd` /
`enemy_skills_config.gd` hiện tại:

| Cơ chế thiết kế dùng | Trạng thái |
|---|---|
| zone `sand` (Bọ Cát lấp ô), zone `mire` (Sên Lầy) | có — `burn` / `mire` / `sand` / `fall` đều hỗ trợ |
| status `poison` (dùng ở cả hai vùng) | có — Phase 0 |
| `heal` (spore_regrow, matriarch_regrow) | có — tức thời hoặc hồi dần, bị huỷ khi choáng |
| `evade` / `shroud` (Ảo Ảnh, Màn Bụi) | có |
| `push` / `pull` (burrower_undertow) | có, kèm R3 reaction gate và ICD |
| anchor `on_player`, `near_player`, `row_of_player`, `self_cell`, `far_cell` | có đủ |
| `followup` `relative_to: player` (jackal cắn đuổi) | có |
| điều kiện `allies_alive_min` (bầy ×1,5) | có |
| điều kiện `player_still_sec` (phục kích người đứng yên) | có |
| phases + `every_nth` + `transition.on_enter` (Sphinx, Matriarch) | có — Hỏa Ngục đã dùng |

**Kết luận: Phase 2 là data + strings, đúng như lộ trình §11 dự kiến.** Không có đề xuất sửa code nền nào.

---

## 3. Thang damage — việc quan trọng nhất phải quyết TRƯỚC khi triển khai

Đây là bài học đắt nhất của Phase 1. Giá trị damage trong tài liệu thiết kế của **cả ba vùng** nằm trên
cùng một thang, dù chúng ở ba tầng khác nhau:

| mục §4 | vùng | tầng | min | max | trung bình |
|---|---|---|---|---|---|
| 4.2 | Hỏa Ngục | 2 | 6 | 14 | 10,8 |
| 4.3 | Sa Mạc | 3 | 6 | 16 | 10,5 |
| 4.4 | Đầm Lầy | 4 | 6 | 14 | 10,6 |

Hỏa Ngục ở thang gốc (×1) cho kết quả sai hẳn: 100 % run qua vùng, máu mất 15 thay vì 63 mỗi tuyến, và
phải chạy lại sim 2 giờ. Cuối cùng chốt **×3,5**. Sa Mạc và Đầm Lầy ở tầng sâu hơn mà thang damage y hệt,
nên **gần như chắc chắn sẽ lặp lại đúng lỗi đó** nếu triển khai nguyên giá trị thiết kế.

### Mốc khó dễ từng tầng (B1, block brain, trung bình 5 nhân vật × 2 seed set)

| tầng | vùng | qua tầng % | HP % vào tầng | HP % sau boss | HP mất trong tầng (điểm) |
|---|---|---|---|---|---|
| 2 | hellfire | 84,6 | 99,4 | 49,7 | **49,7** |
| 3 | desert | 94,7 | 93,7 | 63,6 | **30,1** |
| 4 | swamp | 70,9 | 97,6 | 47,1 | **50,5** |

Đọc bảng này: dưới block brain, **Sa Mạc là tầng dễ nhất** trong ba tầng, còn **Đầm Lầy khó ngang Hỏa Ngục**.
Vậy không nên dùng chung một hệ số cho hai vùng.

### Hệ số đề xuất

Suy ra từ tỉ lệ HP mất so với Hỏa Ngục (tầng 2 = 49,7 điểm ứng với ×3,5):

| vùng | tỉ lệ so tầng 2 | hệ số đề xuất | trần do gate đòn chết ngay | ghi chú |
|---|---|---|---|---|
| Sa Mạc | 30,1 / 49,7 = 0,61 | **×2,0 – ×2,5** | ×3,5 (max thiết kế 16 → 56 ≤ 56,6) | tầng dễ, đừng ép bằng tầng 2 |
| Đầm Lầy | 50,5 / 49,7 = 1,02 | **×3,5** | ×4,0 (max thiết kế 14 → 56 ≤ 56,6) | khó ngang tầng 2 |

Trần tính theo gate đã có: không đòn nào, kể cả nhân 1,5 vì Rạn, được chạm nửa máu hero thấp nhất
(Pháp Sư 170 → ngưỡng 85 → đòn gốc tối đa 56,6).

**Quy trình đề xuất, giống Phase 1 nhưng làm sớm hơn một bước:** triển khai data ở hệ số đề xuất → chạy
sim hiệu chỉnh 2 nhân vật mỗi vùng (~25 phút) → chỉnh hệ số nếu lệch → mới chạy sim đầy đủ 10 job. Phase 1
làm đúng vòng này và nó cứu một lần chạy sai; khác biệt duy nhất là lần này **không bắt đầu từ ×1**.

Script có sẵn, dùng lại được: `production/qa/evidence/monster-skill-hellfire/tuning/scale_hellfire_damage.py`
(luôn tính từ giá trị thiết kế gốc nên chạy lại bao nhiêu lần cũng được; cần viết bản tương tự cho 2 vùng này).

---

## 4. Trait chồng chéo — cần người dùng quyết từng con

Mỗi quái dưới đây đang mang trait, trong khi thiết kế lại cho nó skill làm việc tương tự. Phase 1 đã gặp
đúng tình huống này với Inferno Lord và người dùng chọn **giữ cả hai** (`vent_surge` + `phase_shift` song
song với `phases[]`). Nhưng ở Phase 2 có một con **không thể giữ**:

### 4.1 `seal_caster` của Cóc Chúa — HỎNG trên pattern brain, bắt buộc chuyển thành skill

Đã kiểm code: `src/traits/seal_caster.gd` đọc `boss.get_actor()` và chỉ kích hoạt khi
`actor.is_swinging()` với nhát đánh đủ `min_swing_cells` ô. Quái pattern **không vung nhát theo kiểu block
boss**, nó niệm skill theo pattern. Vì vậy trait này sẽ **arm rồi không bao giờ bắn** — trơ hoàn toàn, im
lặng, không báo lỗi. Cùng loại lỗi với `big_hands` / `quick_blocks` trơ ở Phase 1 (R6).

Thiết kế §4.4 đã ghi sẵn "seal_caster của Cóc Chúa chuyển thành skill", và audit này xác nhận lý do.
**Đề xuất: bỏ `seal_caster` khỏi match Cóc Chúa, chuyển thành skill `matriarch_sink`.**

*Kiểm lại 2026-11-14 (sau Phase 5 bước 1 của session multi-enemy):* không phải lỗi nhầm unit. `seal_caster` lấy boss
qua ctx (`get_context().get("boss")`, dòng 103), mà từ bước 1 ctx đã trả đúng controller của từng unit — không có
`Side.ENEMY` hay bí danh state nào trong file. Nghĩa là nó **hỏi đúng quái** và vẫn không bao giờ bắn, vì
`is_swinging()` luôn false với quái pattern: quái pattern niệm qua `PatternController`, không điều khiển cut actor.
Hai nguyên nhân khác nhau, kết luận không đổi.

### 4.2 Các trait khác — chạy bình thường trên pattern, chỉ là câu hỏi thiết kế

Đã kiểm hook của từng trait:

| trait | quái | hook | chạy được? | câu hỏi |
|---|---|---|---|---|
| `burrow` | sand_burrower | đã biết pattern (Phase 0 G6) | có | giữ song song skill `burrower_undertow`? |
| `riposte` | scorpion | `on_player_swing_resolved` (phía người chơi) | có | giữ song song `scorpion_pincer_hold`? |
| `spore_burst` | spore_cap | `on_tick` + khi boss trúng đòn | có | trùng ý với skill `spore_puff` — giữ cả hai? |
| `sandstorm` | sand_sphinx | `on_tick` | có | trùng ý với `sphinx_sandfall` — giữ cả hai? |
| `bog_spread` | toad_matriarch | `on_tick` | có | trùng ý với zone mire của Cóc Chúa — giữ cả hai? |
| `row_burner` | sun_archer, bog_hound | `on_tick` | có | thiết kế ghi "giữ" — xác nhận |
| `rotten_thrower` | reed_witch | `on_tick` | có | thiết kế ghi "giữ" — xác nhận |
| `hop_skip` | leap_frog | `on_tick` | có | trùng ý với `frog_leap_slam` — giữ cả hai? |

**Đề xuất mặc định:** giữ nguyên tất cả trừ `seal_caster`, giống quyết định Inferno Lord — trait cho nhịp
nền định kỳ, skill cho đòn có cảnh báo né được. Nhưng 5 con có trùng ý (`spore_cap`, `sand_sphinx`,
`toad_matriarch`, `leap_frog`, và `scorpion`) nên được xác nhận từng con, vì giữ cả hai làm tăng mật độ
đòn và đó chính là thứ sim sẽ đo.

---

## 5. Kế hoạch theo nhóm

Chia như Phase 1 (nhóm nhỏ, dừng được sau mỗi nhóm, có ảnh chụp và test riêng). 18 quái là gấp đôi Hỏa
Ngục nên **đề xuất làm Sa Mạc trước, xong hẳn rồi mới sang Đầm Lầy**, thay vì trộn hai vùng.

| nhóm | quái | ghi chú |
|---|---|---|
| S-A | dune_jackal, sand_beetle, dust_nomad | zone `sand` lần đầu; followup `relative_to: player` lần đầu |
| S-B | mirage_sprite, scarab_guard, sun_archer | `evade` / `shroud` lần đầu; def 2 |
| S-C | sand_burrower, scorpion | hai elite mang trait rủi ro (`burrow`, `riposte`) |
| S-D | sand_sphinx | boss, phases |
| **S-E** | **sim hiệu chỉnh + sim đầy đủ Sa Mạc** | so với B1 tầng 3 |
| W-A | bog_rat, mire_slug, swamp_lizard | zone `mire` lần đầu; nhiều nguồn độc nhỏ |
| W-B | marsh_toad, reed_witch, bog_hound | |
| W-C | spore_cap, leap_frog | `heal` lần đầu (spore_regrow) |
| W-D | toad_matriarch | boss, phases, **bỏ `seal_caster`** |
| **W-E** | **sim hiệu chỉnh + sim đầy đủ Đầm Lầy** | so với B1 tầng 4 |

Mỗi nhóm: data + strings → test đơn vị cho từng cơ chế mới → test công bằng / né → ảnh chụp windowed →
dừng cho người dùng xem.

---

## 6. Rủi ro đã nhận diện

1. **Thang damage sai** (§3) — rủi ro lớn nhất, đã có cách xử lý: hiệu chỉnh trước khi chạy sim đầy đủ.
2. **`seal_caster` trơ** (§4.1) — đã xác minh bằng code, có cách xử lý.
3. **Độc dùng chung hai vùng:** thiết kế nói Sa Mạc dùng độc "ít mà mạnh" (bọ cạp 1,5 dmg × 3 s = 9),
   Đầm Lầy "nhiều nguồn nhỏ" (chuột 1 dmg × 2 s = 4). Luật chồng độc Phase 0 là **lấy max thời lượng, max
   sát thương, min nhịp** — tức hai con chuột không thành 2× độc, đúng ý thiết kế. Nhưng một con chuột cộng
   một con bọ cạp thì ra nhịp nhanh nhất và sát thương cao nhất. Hai vùng không gặp nhau trong một trận nên
   **chưa phải vấn đề hôm nay**, song sẽ thành vấn đề khi multi-enemy trộn vùng.
4. **Mật độ đòn khi giữ cả trait lẫn skill** (§4.2) — sim sẽ đo, nhưng cần quyết trước khi chạy.
5. **`mire_immune`** của `mire_slug` và Cóc Chúa: cần kiểm quái pattern có tự dính lầy của chính nó không,
   giống việc đã kiểm "Lord không tự đốt" ở Phase 1.
6. **Sa Mạc là tầng dễ nhất** dưới block brain (qua 94,7 %). Nếu chỉnh cho khó bằng Hỏa Ngục thì **đổi đường
   cong khó của cả run**, không chỉ đổi brain. Đề xuất giữ nguyên độ khó tương đối giữa các tầng.

---

## 7. Danh sách cần người dùng xác nhận trước khi triển khai

1. **Hệ số damage khởi điểm:** Sa Mạc ×2,0–2,5 và Đầm Lầy ×3,5 — hay muốn số khác?
2. **Giữ hay bỏ trait trùng ý** với 5 con: `spore_cap`, `sand_sphinx`, `toad_matriarch`, `leap_frog`,
   `scorpion` (đề xuất: giữ, trừ `seal_caster` bắt buộc bỏ).
3. **Thứ tự:** Sa Mạc trước rồi Đầm Lầy (đề xuất), hay làm song song hai vùng?
4. **HP / defense / pool / arena:** giữ nguyên như Phase 1 chứ? (Phase 1 không đổi gì trong số này.)
5. **Mức dừng:** dừng cho người dùng xem sau mỗi nhóm như Phase 1, hay gộp lại ít điểm dừng hơn?

---

## 8. Quyết định của người dùng (2026-11-14)

| câu hỏi §7 | quyết định |
|---|---|
| 1. hệ số damage | **Sa Mạc ×2,5, Đầm Lầy ×3,5** (chốt; Sa Mạc lấy đầu trên của khoảng đề xuất) |
| 2. trait trùng ý | giữ tất cả, **trừ `seal_caster`** của Cóc Chúa (bắt buộc bỏ, §4.1) — mặc định đề xuất |
| 3. thứ tự | **Sa Mạc trước**, xong hẳn rồi mới Đầm Lầy |
| 4. HP / defense / pool / arena | giữ nguyên, không đổi — như Phase 1 |
| 5. mức dừng | dừng cho người dùng xem **sau mỗi nhóm**, như Phase 1 |

Vẫn giữ quy trình hiệu chỉnh: triển khai ở ×2,5 → sim hiệu chỉnh 2 nhân vật → chỉnh nếu lệch → sim đầy đủ. Lượt Hỏa Ngục
cho thấy số suy từ thiết kế lệch xa thực tế, nên không bỏ bước xác nhận bằng sim.

---

## 9. Nhóm S-A — đang triển khai (2026-11-14)

Data đã vào (`jackal_pack_nip` 18, followup 15; `beetle_sand_spray` 20; `nomad_ambush` 30; `nomad_veil_step` tự thân),
3 trận chuyển sang pattern, 8 dòng strings, test `tests/unit/combat/pattern_sands_group_a_test.gd`.

**Lỗi đã sửa trong lúc triển khai:** `beetle_sand_spray` đặt `delivery.origin: caster`, nhưng `GROUND_PROPAGATION` chỉ
nhận `origin_cell` / `first_cell`; config **từ chối cả skill** và kéo theo 6 kiểm tra fail. Các skill thanh mặt đất khác
(`hound_ember_charge`, `lord_cinder_lane`) đều dùng `origin_cell`. Đã sửa.

**Phát hiện: `zone.cells` không cần thiết.** §3 của tài liệu này từng lo rằng thiết kế "lấp cát MỘT ô, ô xa người chơi
nhất" không diễn đạt được bằng data. Thực ra engine tự làm: `TileHazards._schedule` **từ chối mọi ô đang có người đứng**,
nên vùng neo `on_player` không bao giờ lấp được ô hero đứng — phần còn lại của thanh chính là "ô xa người chơi nhất".
Không cần sửa engine, không cần lệch thiết kế.

**Đã xong, cát vẫn rơi bình thường.** Nghi ngờ "cát không rơi" hoá ra là **lỗi trong test của tôi**, không phải trong
data hay engine: test đọc `ev.get("zone_cells")` từ `event_log`, mà `PatternController._record` chỉ ghi 8 trường và
không có trường đó — phép đọc luôn rỗng nên nhánh ấy **không bao giờ có thể xanh**. Bài dò in từng bộ lọc một chỉ ra
ô cát nằm trong bảng cảnh báo cát ngay sau cú húc. Test đã sửa để đọc thẳng `TileHazards`.

**Một nhánh vô nghĩa thứ hai, trong suite công bằng mới.** `pattern_sands_fairness_test` lúc đầu không nối `TileHazards`
(chép từ suite Hỏa Ngục, nơi vùng là lửa và mạch phun là địa hình kiểm ở chỗ khác). Không có hazards thì `_apply_zone`
bỏ qua vùng cát và đẩy cảnh báo, nên nhánh F3 "vùng luôn chừa lối thoát" đọc một mảng rỗng và **xanh mà không kiểm gì**.
Dấu hiệu là log in `FAILS=0` kèm **4422 WARNING**. Nối hazards vào: cảnh báo về 0, F3 có nghĩa.

**Kết quả nhóm S-A:** `pattern_sands_group_a` FAILS=0; `pattern_sands_fairness_test` (3 quái × 2 sân × 201 lưới)
FAILS=0, 0 script error, 0 cảnh báo; `enemy_skills_config`, `pattern_roster_mechanics`, `pattern_phase0_effects`,
`terminology_scan` FAILS=0. Ảnh: `production/qa/evidence/monster-skill-sands/group-a/` (7 ảnh + README).

## 10. Nhóm S-B — đã triển khai (2026-11-14, chưa commit)

3 quái: `mirage_sprite` (bóng cát + roi khoá sau bóng), `scarab_guard` (khiên +4 / đâm giáo dọc), `sun_archer`
(chữ thập 5 ô + làm chậm). 5 skill ở ×2,5: roi 25, giáo 30, cung 25. 10 dòng strings. Test
`tests/unit/combat/pattern_sands_group_b_test.gd`; suite công bằng mở rộng lên đủ 6 quái Sa Mạc.

**Lệch thiết kế, đã ghi:** §4.3 nói khiên của Bọ Hung nên nặng ký khi `allies_alive >= 1` **hoặc** `hp_below 0,6`.
Khối `weights` của engine chỉ nhận `player_status` / `player_on_zone` / `self_status` / `allies_alive` — **không có
điều kiện theo máu**. Dùng đúng cách Ash Golem đã dùng ở Phase 1 (`weight` 0,3 + `weights.allies_alive` 4,0 = 1,2);
vế máu thấp hiện **không có tác dụng**. Muốn có thì phải thêm khoá vào `weights`, tức sửa code nền.

**Kết quả:** 6 suite đều FAILS=0, 0 script error, 0 cảnh báo — `terminology_scan`, `i18n`, nhóm A, nhóm B,
`enemy_skills_config`, `pattern_sands_fairness`.

*Mức chắc chắn của câu "6 quái × 2 sân":* ban đầu con số này suy từ hằng `ENEMIES` trong file nguồn, không phải từ
output lần chạy — log chỉ giữ dòng tổng kết. **Đã đóng lại ở nhóm S-C:** lệnh chạy giờ đếm số dòng PASS có tên quái,
và lần chạy 8 quái in **80 dòng** = 8 quái × 2 sân × 5 nhánh. Coverage giờ đọc được từ kết quả, không phải suy ra.

### 10.1 Một suite tôi tưởng đã chạy nhưng chưa từng chạy

Nhóm S-A tôi báo "terminology sạch". Sai: lệnh của tôi ghi `tests/unit/combat/terminology_scan_test.gd`, file thật ở
`tests/unit/ui/`. Godot nhận đường dẫn không tồn tại thì **không in dòng nào, không báo lỗi, thoát 0** — cột kết quả
trống và đọc thành sạch. Chạy đúng đường dẫn thì nó bắt ngay một vi phạm thật trong chuỗi S-A: từ "Ghim" (bảng thuật
ngữ #22 đã thay bằng "Đóng Băng"). Đã đổi thành "đánh nó trước khi bụi tan", sửa cả trong script sinh chuỗi.

Lệnh chạy test từ đây về sau: kiểm tra file tồn tại **trước** khi gọi engine, in `*** KHÔNG CÓ KẾT QUẢ ***` khi suite
không in dòng FAILS, và bắt cả `Parse Error` chứ không chỉ `SCRIPT ERROR`. Lý do: **một suite chưa từng chạy trông y
hệt một suite đã qua**, nếu kết quả được suy ra từ việc không thấy lỗi.

## 11. Quy tắc phối hợp máy, rút ra khi làm nhóm S-B (2026-11-14)

Hôm nay có lúc **hai tiến trình Godot cùng chạy trên project**, vi phạm quy tắc cứng của người dùng. Không ai phá
luật: lượt máy được chuyền tay qua ba session (tôi → multi-enemy → character), trong khi tôi **vẫn đang giữ máy để
chụp ảnh**. Mỗi bên đều tin mình được trao hợp lệ.

**Ba thứ bị gọi chung một tên.** Mượn một *file*, giữ yên cả *cây mã*, và chiếm *tiến trình* Godot là ba loại đặt chỗ
khác nhau. Câu "của bạn rồi" có nghĩa là cái nào, tuỳ người hỏi đang nghĩ tới cái nào. Một session cho mượn
`combat_view.gd` và tin rằng thế là đủ; ảnh chụp lại đọc cả cây mã, nên bốn thay đổi ở file trait khác vẫn phá bộ ảnh.

**Quy tắc từ giờ:**
1. **Trả lượt về người điều phối, không chuyền ngang cho người hỏi kế tiếp.** Một lượt có thể tặng tiếp thì không có
   người giữ duy nhất, và không ai trả lời đúng được câu "ai đang giữ".
2. **"Máy đang trống" chỉ đúng khi phát ra từ người vừa giữ máy.** Tự nhìn danh sách tiến trình không đủ: trong một
   loạt chụp, khoảng trống giữa hai khung trông y hệt máy rảnh. Kiểm hai lần cách nhau ~30 s nếu buộc phải tự quyết.
3. **Nói rõ lượt bao gồm gì:** chỉ tiến trình, hay cả cây mã. Lượt chụp ảnh và lượt chạy suite dài cần cả hai.
4. **Lấy dấu vân tay cây mã trước và sau** mỗi lượt chụp hoặc chạy dài (`git status --porcelain -- src | md5sum`),
   **sau bước import** hoặc loại `.import` / `.uid`, nếu không sẽ báo động giả.
5. **Không kill tiến trình Godot theo số hiệu khi không chắc nó của ai.** Trong loạt chụp mỗi khung là một tiến trình
   riêng, số hiệu đổi liên tục; kill nhầm là phá bộ ảnh của người khác để cứu bộ của mình.

## 12. Nhóm S-C — đã triển khai (2026-11-14, chưa commit)

2 elite: `sand_burrower` (Cát Cuốn dọc cột + Hố Sụt khi yếu máu) và `scorpion` (Chích Độc + Kẹp Càng). 4 skill ở ×2,5:
Cát Cuốn 30, Chích Độc 20, Kẹp Càng 25; Hố Sụt không gây damage, chỉ làm sụp ô. 8 dòng strings. Test
`tests/unit/combat/pattern_sands_group_c_test.gd`; suite công bằng mở rộng lên đủ 8 quái Sa Mạc.

**Lệch thiết kế, đã ghi:** §4.3 viết Hố Sụt là `near_player count 2 exclude_player`. Trong engine `pattern.count`
chỉ được đọc trong nhánh `kind == "marker"` (`pattern_controller.gd:1057`), nên một đòn tấn công mang `count: 2`
sẽ **âm thầm chỉ đặt một ô** — schema vẫn hợp lệ, không lớp nào báo. Viết lại thành thanh 2 ô bằng `offsets`.

**Hai trait của hai elite** (`burrow`, `riposte`) không kiểm ở suite này: burrow tạm dừng pattern brain đã có
`pattern_phase0_pause_test` và `region_traits_test`, riposte có `region_traits_test`. Suite này là bất biến của SKILL.

### 12.1 Lỗi toạ độ đảo trục — đã lọt vào nhóm S-B và được sửa ở đây

`PatternPlanner` dịch offset của neo `column_of_player` thành `Vector2i(player.x - off.y, start + off.x)`
(`pattern_planner.gd:87`): **`off.x` đi dọc cột, `off.y` đi ngang**. `scarab_spear` của nhóm S-B viết
`[[0,0],[0,1]]` nên tạo ra **thanh ngang**, không phải mũi giáo dọc. Cùng lỗi, cùng chỗ, với `eater_ember_belch`
ở Hỏa Ngục.

**Vì sao test không bắt:** skill dùng `clip` + `min_cells: 1`, nên ô sai hướng thường bị cắt, để lại **một ô**; mà
nhánh kiểm "mọi ô cùng cột với hero" **luôn đúng với mảng một phần tử**. Test xanh *chính vì* dữ liệu sai đủ để bị cắt.
Ảnh chụp một ô đỏ cũng trông hợp lý. Đã sửa `scarab_spear` → `[[0,0],[1,0]]`, và siết nhánh kiểm: phải thấy một lần
đánh **không bị cắt** đủ 2 ô và hai ô **khác y**.

**Quy tắc:** khi khẳng định về *hình dạng* một tập ô, khẳng định **kích thước tập** trước. Mọi vị từ "mọi phần tử
đều…" đều đúng với tập rỗng và thường đúng với tập một phần tử.

**Kết quả nhóm S-C:** 6 suite FAILS=0, 0 script error, 0 cảnh báo (config, nhóm A, nhóm B, nhóm C, terminology,
fairness 8 quái với 80 dòng PASS theo quái). Một lỗi trong lượt đầu là **test sai, không phải data sai**:
`_normalize_effects` luôn ghi khoá `damage` (0 khi data không có), nên phép kiểm "không có khoá damage" sai với mọi
skill; đã đổi thành khẳng định damage bằng 0.

## 13. Việc nên sửa ở code nền (ngoài phạm vi Phase 2, cần người dùng duyệt)

### 13.1 `pattern.count` bị bỏ qua lặng lẽ với skill không phải marker — ƯU TIÊN

`PatternController._resolve` chỉ đọc `pattern.count` trong nhánh `kind == "marker"` (`:1057`). Một skill **attack**
mang `count: 2` vẫn hợp lệ với schema, không lớp nào báo, và **âm thầm đặt một ô**.

Đã gặp **hai lần trong hai nhóm liên tiếp**: `burrower_sinkhole` (§12) và `sphinx_bury` (§14) — cả hai thiết kế đều
viết `count 2 exclude_player`, cả hai phải viết lại thành `offsets` hai ô. Thiết kế các vùng sau (Đầm Lầy §4.4, Hầm
Ngục §4.5…) cũng dùng lối viết đó.

Hai là trùng hợp; lần thứ ba sẽ do người chưa đọc ghi chú nào của chúng tôi viết. **Đề xuất, rẻ nhất trước:**
`EnemySkillsConfig` **từ chối hoặc cảnh báo** khi một skill không phải marker mang `count` — biến một lỗi im lặng
thành một dòng trong `problems`, mà mọi suite pattern đều đã khẳng định là rỗng. Không cần đổi hành vi runtime.

### 13.1b Giới hạn test của chính tôi: `phases[].traits` chỉ được kiểm ở mức DỮ LIỆU

`pattern_fixtures.gd` chỉ dựng `PatternController` — không `CombatView`, không `TraitHost`. Nên test nhóm S-D khẳng
định **hình dạng dữ liệu** của `phases[].traits` (đúng id `sandstorm`, đúng `interval_sec` 9, p1 không có override)
và **không** khẳng định rằng trait thật sự được gắn/gỡ khi đổi pha — đường đó nằm trong `CombatView._apply_pattern_phase`.
Ghi ra vì đây là dữ liệu đầu tiên dùng đường G5, nên nó dễ bị đọc nhầm là "đã kiểm xong".

### 13.2 `phases[].traits` chỉ chạy cho unit 0 (phát hiện khi làm S-D)

`phase_started` chỉ được nối trên controller của unit 0 (`combat_view.gd:3207`), và `_apply_pattern_phase` thêm trait
qua `_trait_host` — host của unit 0, ghi cứng (`:3244`). Với Nhân Sư đánh một mình thì **đúng**: nó chính là unit 0.
Nhưng khi multi-enemy đặt một quái pattern có phases ở vị trí 1+, **trait theo pha của nó không bao giờ được áp**.

Hỏng **im lặng** chứ không hỏng sai, nên là vế đỡ tệ hơn — nhưng cùng họ với §13.1: một đường đúng với một hình thái
trận và lặng lẽ không làm gì với hình thái khác. Session multi-enemy ghi vào kế hoạch Phase 5 của họ như một residue.

### 13.3 `weights` không có điều kiện theo máu (§10)

Khiên của Bọ Hung lẽ ra nặng ký khi `hp_below 0,6`; khối `weights` chỉ nhận `player_status` / `player_on_zone` /
`self_status` / `allies_alive`. Hiện chỉ vế đồng đội chạy. Nhẹ nhất trong ba mục này.

## 14. Nhóm S-D — đã triển khai (2026-11-14, chưa commit)

**Quái:** `sand_sphinx` (boss Sa Mạc). Nhân ×2,5 như cả vùng.

| Kỹ năng | Damage (thiết kế → data) | Hình |
|---|---|---|
| `sphinx_gaze` | 10 → **25** + 1 Rạn | 1 ô trên hero |
| `sphinx_claw` | 14 → **35** | chữ T phủ hero |
| `sphinx_bury` | 0 (chỉ vùng) | 2 ô CẠNH hero, cát 4 s |
| `sphinx_sandfall` | 16 → **40**, đòn hai 12 → **30** | 2×2 phủ hero, rồi lệch một hàng |

Hai pha: p1 cơ chế `sphinx_bury`; p2 mở ở 0,5 máu, thêm `sphinx_sandfall` (weight 0 — chỉ ép ra), `every_nth 3`,
chuyển pha 1,5 s với `on_enter` là sandfall, và `phases[].traits` ghi đè `sandstorm` thành `interval_sec` 9.

**Suite:** `tests/unit/combat/pattern_sands_group_d_test.gd` — 56 PASS, FAILS=0. `sand_sphinx` đã thêm vào
`pattern_sands_fairness_test` (9 quái, 91 PASS, 0 WARNING).

**Lượt chạy xác nhận:** 5 suite Sa Mạc, manifest `git hash-object` hai đầu `c48877c3…` giống nhau → TREE STABLE.
A 52 / B 60 / C 52 / D 56 / fairness 91, tất cả FAILS=0.

**Ảnh:** `production/qa/evidence/monster-skill-sands/group-d/` — 4 khung, vân tay `afe1c704…` hai đầu.

### 14.1 Bốn lỗi, cả bốn nằm trong test

Chi tiết trong README nhóm D §4. Hai điều đáng nhớ cho các nhóm sau:

1. **Cùng một thông báo lỗi, hai nguyên nhân khác nhau.** Sửa nguyên nhân thứ nhất không đổi gì trên màn hình —
   đúng lúc dễ kết luận "engine hỏng" và đi sửa `enemy_skills.json` nhất. Dữ liệu đúng suốt từ đầu.
2. **Bản sửa sinh ra lỗi kế tiếp.** Nâng `weight` để một kỹ năng `weight: 0` chịu tung ra là cần thiết, nhưng kỹ
   năng đó có `cooldown_sec: 0`, nên lần tung kế tiếp rơi vào mọi cửa sổ đo. Với kỹ năng ép-ra: đọc damage ghi
   trong event log và lọc `followup_strike`, đừng đo hiệu máu qua một cửa sổ.

### 14.2 `--shot-frame=N` không phải dòng thời gian (ảnh hưởng mọi nhóm)

`N` đếm khung đã dựng, không đếm giây mô phỏng; mỗi ảnh một tiến trình, nên ánh xạ khung→giây trượt theo tải máy.
Bằng chứng: 4 khung Nhân Sư cho máu hero **175 → 200 → 200 → 165** theo số khung tăng dần.

Dữ kiện trong MỘT khung vẫn dùng được; câu bắc qua HAI khung thì không. Đã sửa 7 câu trong README nhóm A/B/C
(§"đã bị lấp", "cắn rồi cắn đuổi", "giảm đúng 30", "khung muộn", "sau Chích Độc", và hai câu "sau cú X = đúng N
damage" nay nói rõ đó là TỔNG máu đã mất và vì sao quy được về kỹ năng đó).

Nhóm A–C còn một đính chính nữa: vân tay cây mã ở các nhóm đó dùng `git status --porcelain | md5sum`, **băm tên
file chứ không băm nội dung** — không phát hiện được sửa nội dung một file vốn đã ở trạng thái ` M`. Từ nhóm D
dùng manifest `git hash-object`.
