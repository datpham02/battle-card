# Card art — audit và chuẩn bị prompt (2026-11-13)

> **Batch3 xong 2026-11-13:** 38 ảnh cài, 10 card bị chặn (palette), cuong_phong chưa đạt — `batch3/REPORT-2026-11-13.md`.

> **Cập nhật 2026-11-13:** người dùng đã chốt Q1–Q8. Luật hiện hành nằm ở Master Reference
> `design/assets/references/ui/card-art.md`; nó thắng file này. Một số hex trong §5–§6 dưới đây nằm ngoài
> `tessera_master.gpl` (`#A6EEFF`, `#A8C83A`, `#4E4A2A`, `#7D8896`, `#E4DAFF`) — xem Master Reference §4.2.
> Registry đã thêm 12 card + candidate batch2/v2 (Q8). Prompt Pilot: `pilot-prompts-2026-11-13.md`.

Chỉ là tài liệu. Không gen, không cài, không đổi trạng thái registry, không sửa code/data/test, không chạy Godot.
Mọi lượt gen sau này cần người dùng nói "yes" rõ ràng **cho từng lần gọi**.

Nguồn đã đọc: `assets/data/cards.json` (62 card), `assets/i18n/strings.csv`, `design/assets/asset-registry.yaml`
(13 asset `card.*` + 37 dòng backlog `card.*`), `design/assets/candidates/ui/card-art/prompts.md`,
`docs/art/RENDER-STANDARDS.md` (không có bản ở `design/assets/`), `design/assets/specs/` (không có spec card),
`design/assets/references/` (chỉ có nhân vật), `src/ui/card_face.gd`, `docs/skill-v2/02-vfx-concepts.md`,
`design/art/art-bible.md` §8.

---

## 1. Kết luận nhanh

| Mục | Số |
|---|---|
| Card trong `cards.json` | **62** (45 trong `card_order` = pool thưởng; 15 card riêng anh hùng; 2 card nguyền) |
| Có artwork trong `assets/art/cards/` | **13** |
| Chưa có artwork (vẽ cửa sổ bằng code) | **49** |
| Trong registry dạng asset | 13 (`status: installed`) |
| Trong registry dạng backlog | 37 |
| **Không có mặt trong registry** | **12**: bay_kep, bay_lo, gai_no, thanh_thuan, khien_thep, tuong_da, hoa_tuyen, chuong_thanh, thien_quang, dau_tu, phi_tieu, moc_keo |
| Có prompt trong `prompts.md` | 33 card còn sống (+3 dòng đã xóa) — **29 card không có prompt** |
| Trạng thái duyệt của 13 art đã cài | 0 `approved`; 1 `acceptance: accepted` (hoa_xa, "approved style"); 12 `acceptance: unknown` |
| Master Reference cho card art | **absent** |
| Palette khóa cho card art | **undefined** (xem §4) |
| Tool gen đã dùng | **undefined** — prompts.md ghi `create_image_pixflux`, registry ghi `create_image_pro_flash`, gens `null` |

---

## 2. Danh sách 62 card và trạng thái art

Cột *Reg*: `A` = asset installed, `B` = backlog, `—` = không có trong registry. Cột *Prompt*: có dòng trong prompts.md.
Nhóm (batch) xem §5.

### 2.1 Đã có art (13) — đều `installed`, chưa ai `approved`

| id | Tên VI / EN | Hiệu ứng | Nguồn file (so byte) | Acceptance |
|---|---|---|---|---|
| kiem_khi | Rạch nhẹ / Nick | damage | batch1/kiem_khi.png | unknown |
| chan_phong | Hích nhẹ / Nudge | push | batch1/chan_phong.png | unknown |
| kiem_vu | Xé toạc / Gash | damage | batch1/kiem_vu.png | unknown |
| thiet_kiem | Lia ngang / Cleave | damage | batch1/thiet_kiem.png | unknown |
| dai_dao | Bổ nặng / Broad Stroke | damage | batch1/dai_dao.png | unknown |
| xung_kich | Xô lùi / Shove | push | batch1/xung_kich.png | unknown |
| hoa_tinh | Tro hồng / Cinder | burn | batch1/hoa_tinh.png | unknown |
| hoa_xa | Tia lửa / Spark | burn | **hoa_xa_v2.png** | accepted ("approved style", không ghi ngày) |
| hoa_tran | Lò than / Brazier | burn | batch1/hoa_tran.png | unknown |
| suong_mong | Men băng / Glaze | pin | batch1/suong_mong.png | unknown |
| bang_chau | Mưa đá / Hailstone | pin | batch1/bang_chau.png | unknown |
| ran_kich | Nứt chân chim / Hairline | fragile | batch1/ran_kich.png | unknown |
| han_khi | Rùng mình / Shiver | frost | batch1/han_khi.png | unknown |

### 2.2 Chưa có art (49)

| id | Tên VI / EN | Hero | Độ hiếm | Hiệu ứng | Reg | Prompt | Batch |
|---|---|---|---|---|---|---|---|
| do_kiem | Đỡ Kiếm / Parry | kiem_si | common | damage (parry) | B | — | H-KS |
| ngan_kiem | Ngàn Kiếm / Thousand Blades | kiem_si | epic | damage | B | — | H-KS |
| tram_dia | Trảm Địa / Earth-Splitting Wave | kiem_si | rare | damage | B | — | H-KS |
| hoa_loi | Hỏa Lôi / Fire Mine | phap_su | common | damage | B | — | H-PS |
| hoa_tuyen | Hỏa Tuyến / Fire Line | phap_su | rare | damage | — | — | H-PS |
| thien_thach | Thiên Thạch / Meteor | phap_su | epic | damage | B | — | H-PS |
| song_dao | Song Đao / Twin Blades | sat_thu | common | damage | B | — | H-ST |
| phi_tieu | Phi Tiêu Liên Hoàn / Dagger Fan | sat_thu | rare | damage | — | — | H-ST |
| dau_tu | Dấu Tử / Death Mark | sat_thu | epic | damage | — | — | H-ST |
| bay_kep | Bẫy Kẹp / Jaw Trap | tho_san | common | trap | — | — | H-TS |
| moc_keo | Móc Kéo / Hook Pull | tho_san | rare | damage | — | — | H-TS |
| gai_no | Gai Nổ / Thorn Burst | tho_san | epic | damage | — | — | H-TS |
| thanh_thuan | Thánh Thuẫn / Holy Ward | giao_si | common | ward | — | — | H-GS |
| chuong_thanh | Chuông Thánh / Holy Bell | giao_si | rare | damage | — | — | H-GS |
| thien_quang | Thiên Quang / Heaven's Light | giao_si | epic | damage | — | — | H-GS |
| lien_tram | Liên Trảm / Double Slash | — | common | damage | B | — | G2 |
| vung_lay | Vũng Lầy / Mire | — | common | damage | B | — | G2 |
| thuong_xuyen | Thương Xuyên / Piercing Lance | — | common | damage | B | — | G2 |
| dap_vo | Đập Vỡ / Guard Breaker | — | common | damage | B | — | G2 |
| min_tre | Mìn Trễ / Delay Mine | — | common | damage | B | — | G2 |
| dia_chan | Địa Chấn / Tremor | — | common | push | B | — | G2 |
| bay_lo | Bẫy Lò Xo / Spring Trap | — | common | trap | — | — | G2 |
| khien_thep | Khiên Thép / Steel Ward | — | common | ward | — | — | G2 |
| chuoi_set | Chuỗi Sét / Chain Spark | — | rare | damage | B | — | G2 |
| loc_cuon | Lốc Cuốn / Vortex | — | rare | damage | B | — | G2 |
| bang_vo | Băng Vỡ / Shatter | — | rare | damage | B | — | G2 |
| tuong_da | Tường Đá / Stone Wall | — | rare | pillar | — | — | G2 |
| hoa_bang | Hỏa Băng / Frostfire | — | epic | damage | B | — | G2 |
| hoi_am | Hồi Âm / Echo | — | epic | damage | B | — | G2 |
| liet_hoa | Lửa rừng / Wildfire | — | rare | burn | B | có | E-Fire (*candidate batch2 đã có*) |
| thien_hoa | Giàn thiêu / Pyre | — | epic | burn | B | có | E-Fire (*candidate batch2 đã có*) |
| bang_phong | Lặng yên / Stillness | — | rare | pin | B | có | E-Ice |
| han_bang | Tảng băng / Glacier | — | epic | pin | B | có | E-Ice |
| han_kiem | Rét cắt / Rime Edge | — | common | damage+chill | B | có | E-Frost |
| thanh_thuy | Sương bạc / Silver Dew | — | common | frost | B | có | E-Frost |
| han_phong | Bão trắng / Whiteout | — | rare | frost | B | có | E-Frost |
| han_tran | Tuyết rơi / Snowfall | — | rare | damage+chill | B | có | E-Frost |
| bang_tam | Buốt xương / Winter's Bite | — | rare | damage+chill | B | có | E-Frost |
| cuong_phong | Cú húc / Ram | — | rare | push | B | có | E-Push |
| thien_lang | Sạt lở / Landslide | — | rare | push | B | có | E-Push |
| kiem_than | Lưỡi sắc / Keen Edge | — | rare | damage | B | có | E-Blade |
| song_kiem | Nêm sắt / Wedge | — | epic | damage | B | có | E-Blade |
| tu_kiem | Nhát cuối / Last Verdict | — | epic | damage (execute) | B | có | E-Blade |
| ran_van | Đứt gãy / Fault Line | — | rare | fragile | B | có | E-Blade |
| tran_gai | Bụi rậm / Briar Patch | — | common | thorns | B | có | E-Thorn |
| gai_doc | Bẫy chông / Caltrops | — | common | thorns | B | có | E-Thorn |
| gai_nguyen | Dây úa / Witherbriar | — | rare | thorns | B | có | E-Thorn |
| ganh_nang | Gánh Nặng / Dead Weight | — | curse | — | B | có | Curse |
| oan_hon | Mối Hận / Lingering Grudge | — | curse | — | B | có | Curse |

---

## 3. Lệch giữa registry, đĩa và prompt (chỉ ghi, không sửa)

1. **12 card không có trong registry** (cả asset lẫn backlog) — toàn card Skill v2 thêm sau bootstrap 2026-11-11. Không tạo
   registry thứ hai; người giữ registry thêm 12 dòng backlog bằng `asset_registry.py` khi người dùng đồng ý.
2. **Backlog ghi "code-drawn until generated" cho liet_hoa, thien_hoa** nhưng `candidates/ui/card-art/batch2/` đã có
   `liet_hoa.png`, `thien_hoa.png` (gen 2026-11-01). Chúng là candidate chưa đăng ký. Batch2 còn có `dai_dao`,
   `hoa_tinh`, `kiem_khi`, `xung_kich` (bản thứ hai, không được cài).
3. **Candidate v2 không đăng ký**: `kiem_khi_v2.png`, `chan_phong_v2.png`, `slash_v1.png`. Ảnh `v2_in_shop.png` cho thấy
   kiem_khi bản trăng khuyết — nhưng file đang cài là **batch1** (thanh kiếm vàng), không phải v2. Chỉ hoa_xa dùng v2.
4. **Tool gen không thống nhất**: prompts.md = `create_image_pixflux` + `color_image_url` từ `ui_icons_55.png`;
   registry `generation.tool` = `create_image_pro_flash`; audit 2026-11-11 ghi "13 × Pro Flash". Không có job id, gens `null`.
5. **Số card thiếu bị đếm lệch**: active.md ghi "36 cards", audit 2026-11-11 ghi "37 card arts / 13 of 50". Thực tế 49/62.
6. **Không có spec card trong `design/assets/specs/`**; spec trong registry trỏ `prompts.md`.

### Quan sát trên 13 art đã cài (xem `batch1_sheet_x5.png`) — để người dùng xem lại, không tự kết luận

- **kiem_khi**: nền đen loang lổ, khác nền phẳng của các ô khác; kết quả là thanh kiếm vàng, không phải "vệt chém chéo" như prompt.
- **kiem_khi / thiet_kiem / dai_dao**: ba thanh kiếm đứng, khó phân biệt — trái quy tắc "cùng họ khác chủ thể" của prompts.md.
- **hoa_tinh**: có điểm hồng/tím rõ — gần màu tín hiệu Khối Lạ `#E04CD0` (RENDER-STANDARDS §4).
- Màu nền mỗi ô khác nhau (navy, xám, đen).

---

## 4. Kiểm tra prompt hiện có (`prompts.md`)

| # | Vấn đề | Dòng / card | Đề xuất |
|---|---|---|---|
| P1 | Thiếu 29 card (toàn bộ Skill v2 + 12 card mới) | — | §6 của file này |
| P2 | Tool mâu thuẫn với registry | đầu file | Người dùng chọn 1 tool (Q2) |
| P3 | Palette ép từ `ui_icons_55.png`, không phải `tessera_master.gpl`; không có palette card khóa | đầu file | **undefined** — Q3 |
| P4 | Template không nói vùng an toàn 28 px (card ancient chỉ hiện giữa 28 px, `ANCIENT_PICTURE_PX`) | template | Thêm "subject inside the central 28x28" |
| P5 | Từ cấm theo RENDER §3 ("glow", đỏ): kiem_vu "glowing red-orange", dai_dao "glowing gold edge", tu_kiem "red glow", ran_van "glowing purple crack", thien_hoa "crimson-gold", hoa_xa "white-hot core" | các dòng tương ứng | Đổi sang màu phẳng có tên hex; §6.3 viết lại liet_hoa→tu_kiem |
| P6 | Tím/hồng trùng tín hiệu Khối Lạ `#E04CD0`: ran_kich, ran_van "purple crack" | 2 dòng | Đổi vết nứt sang Mực + Ngà (Q5) |
| P7 | "thick dark outline" ≠ RENDER §2 (1 px `#1B1722`) — RENDER không phủ UI card nên **undefined** | template | Q4 |
| P8 | Nền "dark navy" không có hex; kết quả lệch nhau | template | Một hex nền cố định (Q4) |
| P9 | Chưa áp màu khối anh hùng cho card riêng anh hùng (RENDER §4) | — | §5 |
| P10 | Chưa có câu chống giống vũ khí nổi tiếng / chống wuxia (luật người dùng) | — | Checklist §7 |
| P11 | 3 dòng đã xóa (ket_gioi, long_an, luoi_san) vẫn nằm trong bảng | cuối bảng | Dọn khi người dùng cho sửa prompts.md |
| P12 | Không có tham chiếu ảnh style anchor (chỉ ghi chữ "hoa_xa") | — | Q1: dùng `assets/art/cards/hoa_xa.png` làm style ref |
| P13 | Prompt viết phủ định có thể phản tác dụng (bài học PixMiniMax: "no red" vẽ ra đỏ) | — | Chỉ mô tả tích cực; loại trừ để ở trường negative nếu tool hỗ trợ |

Không có lệch tên: 33 tên trong prompts.md khớp `strings.csv`.

---

## 5. Art direction đề xuất (chờ người dùng chốt)

**Đề xuất chính:** giữ style đã accept của **Tia lửa (hoa_xa)** — một chủ thể đậm, giữa khung, nền phẳng tối — và thêm
dấu Tessera: **phép là khối hình học**, nên mỗi card phép (lửa, băng, sét, ánh sáng) có ít nhất một mảnh **vuông/bậc thang**
trong chủ thể (tia lửa bậc, mảnh băng vuông, cột sáng vuông). Vũ khí thì dáng Tây phương (kiếm thẳng, rìu, dao găm),
không kiếm cong / tua kiếm kiểu wuxia.

| Hạng mục | Đề xuất | Trạng thái |
|---|---|---|
| Khung xuất | 32×32 PNG RGBA, chủ thể nằm trong **28×28 giữa**, hiện x2 trên card ancient | khớp `card_face.gd` |
| Alpha | 0/255, không pixel nửa trong | RENDER §1 |
| Nền | **một hex phẳng** cho mọi card (đề xuất `#2C2A35` trong master palette) | **undefined** — Q4 |
| Viền | 1 px Mực `#1B1722` quanh chủ thể | **undefined** — Q4 (RENDER §2 chỉ phủ đơn vị/Khối) |
| Sáng | trên-trái, ≤ 3 bậc bóng mỗi chất liệu, không gradient mượt, không dither | RENDER §2–3 |
| Palette | `tessera_master.gpl` (47 màu) **hoặc** `ui_icons_55.png` như batch1 | **undefined** — Q3 |
| Màu cấm | `#E5293B` (đỏ báo đòn), `#E04CD0` (Khối Lạ) | RENDER §4 |
| Màu nhấn anh hùng (card riêng) | Kiếm sĩ `#8FA3B8`/`#EEF4FA`; Pháp sư `#3A2A26`/`#F0A030`; Sát thủ `#BFF3EC`; Thợ săn `#8A5A33`/`#46D6A4`; Giáo sĩ `#E4DAFF`/`#B8BCC8` | RENDER §4 bảng khối |
| Màu họ hiệu ứng | Lửa `#FF7A1F`/`#FFB21F`; Băng/Đóng băng `#A6EEFF`; Giá Lạnh `#3A5CF0`; Lầy `#A8C83A`/`#4E4A2A`; Đá/Rạn: Đá `#4A4640`, Ngà `#EFE6D2`, Mực | RENDER §4 |
| Phân biệt | Trong một họ, mỗi card khác **dáng** (không chỉ khác màu) — tô đen vẫn phân biệt | RENDER §6.1 |
| Chữ / số / rune | không có | RENDER §5 |
| Master Reference card art | **absent** — đề xuất: sau khi chốt Q1–Q4, file ref = hoa_xa + 2 card pilot | Q1 |

**Template prompt đề xuất (v2, chỉ câu tích cực):**

```
game icon: <SUBJECT>, centered inside the middle 28x28 of a 32x32 canvas, one bold subject,
flat solid <BG HEX> background, 1px <OUTLINE HEX> outline around the subject, flat pixel colours
with up to 3 shades lit from top-left, hard pixel edges, clean readable silhouette, angular shapes,
Western fantasy, <ACCENT COLOURS>
```
Ô `negative_description` (nếu tool có): `text, letters, runes, glow, soft gradient, red, magenta, curved oriental sabre, tassel`.
Style reference: `assets/art/cards/hoa_xa.png` (nếu tool nhận ảnh tham chiếu).

---

## 6. Prompt cho 49 card thiếu

Chỉ ghi `SUBJECT` + `ACCENT`; ghép vào template §5. Chưa gen. Mỗi dòng 1 gen dự kiến.

### 6.1 Card anh hùng (15) — batch H, mỗi anh hùng 3 card

| id | SUBJECT | ACCENT | Đọc khác với |
|---|---|---|---|
| do_kiem | a steel kite shield with a straight sword blade crossing in front of it, a small square spark where they meet | steel `#8FA3B8`, white `#EEF4FA` | mọi card kiếm đơn |
| ngan_kiem | five small straight sword blades falling point-down in a staggered column, each with a short stepped trail | `#8FA3B8`, `#EEF4FA` | kiem_khi (1 kiếm) |
| tram_dia | a straight sword driven point-first into a stone slab, a stepped crack running right from it | `#8FA3B8`, stone `#4A4640` | thiet_kiem |
| hoa_loi | a square fire sigil plate on the ground with three small stepped flames rising from its corners | dark `#3A2A26`, amber `#F0A030`, `#FF7A1F` | hoa_tran (bát lửa) |
| hoa_tuyen | a low straight wall of stepped square flames running left to right | `#F0A030`, `#FF7A1F` | liet_hoa (lửa lan rộng) |
| thien_thach | a square-cut burning rock falling diagonally with a stepped flame trail | `#3A2A26`, `#F0A030` | thien_lang (đá lăn ngang) |
| song_dao | two short daggers crossed in an X, blades up | pale cyan `#BFF3EC`, Ink | kiem_vu (vết cào) |
| phi_tieu | three throwing knives fanned out flying right, small square trails | `#BFF3EC` | chan_phong (mũi tên) |
| dau_tu | a diamond-shaped mark with a small skull inside, four bracket corners around it | `#BFF3EC`, Ink, Ivory `#EFE6D2` | tu_kiem |
| bay_kep | an open iron jaw trap with square teeth seen from the front | brown `#8A5A33`, teal `#46D6A4` | gai_doc (chông) |
| moc_keo | a grappling hook with three angular prongs and a taut rope going to the left | `#8A5A33`, `#46D6A4` | — |
| gai_no | a cluster of wooden thorn spikes bursting outward from a centre square, splinters flying | `#8A5A33`, `#46D6A4` | tran_gai (dây gai) |
| thanh_thuan | a square heater shield with a pale square ward frame glowing around it as flat light bands | lilac `#E4DAFF`, silver `#B8BCC8` | khien_thep |
| chuong_thanh | a silver bell with two square ripple rings beside it | `#E4DAFF`, `#B8BCC8` | — |
| thien_quang | a vertical square-edged shaft of pale light falling onto a stone tile | `#E4DAFF`, `#B8BCC8` | thien_hoa (cột lửa) |

(thanh_thuan: bỏ chữ "glowing" khi ghép — viết "flat pale light bands".)

### 6.2 Card chung Skill v2 (14) — batch G2

| id | SUBJECT | ACCENT |
|---|---|---|
| lien_tram | two parallel horizontal slash streaks stacked one above the other | steel `#8FA3B8`, white `#EEF4FA` |
| vung_lay | a flat muddy puddle with two square bubbles on top | `#4E4A2A`, `#A8C83A` |
| thuong_xuyen | a long spear lance pointing right, piercing through three square tiles in a row | steel, Ivory |
| dap_vo | a heavy square-headed war hammer smashing down onto a cracked shield | stone `#4A4640`, steel |
| min_tre | a square iron mine with a short fuse and three tick notches on its face | stone, `#FF7A1F` fuse tip |
| dia_chan | a stone slab lifting up in stepped layers, three short shock lines to the right | stone `#4A4640`, Ivory |
| bay_lo | a coiled metal spring under a square plate, launching upward | steel, `#8A7350` |
| khien_thep | a square steel tower shield seen front-on with four rivets | steel `#8FA3B8`, `#5F6F82` |
| chuoi_set | a zig-zag lightning bolt made of linked square segments | pale yellow `#E8D9A8`, white |
| loc_cuon | a stepped square spiral vortex turning inward | Mist `#7D8896`, Ivory |
| bang_vo | an ice spike stabbing into a shattering square ice block, shards flying | `#A6EEFF`, white |
| tuong_da | two upright square stone pillars side by side | stone `#4A4640`, `#2C2925` |
| hoa_bang | a square block split in half, left half flame, right half ice | `#FF7A1F`, `#A6EEFF` |
| hoi_am | one square stamp mark and a fainter offset copy of it beside it | Ivory, Mist |

### 6.3 Card cũ đã có prompt (18) — prompt sửa để hết vấn đề P5/P6

| id | SUBJECT (bản sửa) | Ghi chú |
|---|---|---|
| liet_hoa | a wide low wall of stepped orange flames spreading sideways | **có candidate batch2** — xem trước khi gen |
| thien_hoa | a tall pillar of stepped orange and amber fire with rising square sparks | bỏ "crimson"; **có candidate batch2** |
| bang_phong | a cube of clear blue ice with a white snowflake frozen inside | giữ nguyên |
| han_bang | a cluster of big jagged blue ice spikes with a crack | giữ nguyên |
| han_kiem | a straight sword blade coated in white frost with an icy blue edge | thêm "straight" |
| thanh_thuy | a single silver-blue water droplet with a small square sparkle | |
| han_phong | a white swirling blizzard cloud full of square snowflakes | |
| han_tran | a small grey cloud with square snowflakes falling below it | |
| bang_tam | a pair of icy blue fangs biting down | giữ nguyên |
| cuong_phong | a bronze ram head charging to the right | giữ nguyên |
| thien_lang | a tumble of three grey square-cut boulders rolling to the right | |
| kiem_than | a slim silver straight blade pointing up with a small four-point star at its tip | khác kiem_khi bằng dáng mảnh + sao |
| song_kiem | a steel wedge driven into a cracked grey stone | giữ nguyên |
| tu_kiem | a dark broad executioner sword pointing down with an ivory edge line | bỏ "red glow" |
| ran_van | a grey stone split by a deep dark crack with ivory edges | bỏ "glowing purple" (Q5) |
| tran_gai | a curling green thorny bramble vine | dùng rêu `#5E6B55`, không lục tươi |
| gai_doc | three spiked iron caltrops on the ground | giữ nguyên |
| gai_nguyen | a dark withered brown thorn branch | bỏ "purple" |

### 6.4 Card nguyền (2) — batch Curse

| id | SUBJECT | Ghi chú |
|---|---|---|
| ganh_nang | a heavy dull iron ball on a short chain | giữ nguyên |
| oan_hon | a small pale grey-green ghostly wisp with two angry eyes | giữ nguyên; Q6 có cần nền riêng cho nguyền |

---

## 7. Thứ tự tạo và cách kiểm tra

### Kế hoạch batch (sau khi người dùng cho phép, mỗi lần gọi một "yes")

| Bước | Nội dung | Gen dự kiến |
|---|---|---|
| 0 | Người dùng trả lời Q1–Q7. Viết Master Reference card art (file ref + checklist khóa). Không gen | 0 |
| 1 | **Pilot 3 card** khác họ: do_kiem (kiếm sĩ), hoa_loi (phép lửa), khien_thep (vật). Chụp trong shop + tay bài, người dùng chốt style | 3 |
| 2 | H-KS, H-PS, H-ST, H-TS, H-GS (12 card còn lại của batch H, theo từng anh hùng) | 12 |
| 3 | G2 (14 card chung Skill v2, nhiều nhất trong pool thưởng mới) | 13 (khien_thep đã ở pilot) |
| 4 | E-Fire (xem 2 candidate batch2 trước — có thể 0 gen), E-Ice, E-Frost, E-Push, E-Blade, E-Thorn | ≤ 18 |
| 5 | Curse | 2 |
| 6 | (tách riêng, cần quyết định) xem lại 13 art đã cài: kiem_khi nền, 3 kiếm giống nhau, hoa_tinh màu hồng | 0 cho tới khi người dùng chọn |

Tổng: **~48–49 gen** nếu 1 gen/card, không re-roll vòng lặp. Lần làm lại nào cũng hỏi riêng.

### Kiểm tra chất lượng mỗi card (trước khi đưa người dùng xem)

1. 32×32 RGBA, alpha 0/255, một cỡ pixel, chủ thể trong 28×28 giữa.
2. Màu nằm trong palette đã khóa (Q3); không `#E5293B`, không `#E04CD0`; không gradient mượt, không glow.
3. Đặt cạnh card cùng họ trên một sheet x4: tô đen vẫn phân biệt từng card.
4. Không giống vũ khí/biểu tượng nổi tiếng (gọi tên hình gần nhất trước khi duyệt — luật "no lookalike"); không kiếm cong / tua wuxia.
5. Không chữ, số, rune.
6. Không sửa tay chi tiết trên ảnh gen (chỉ chỉnh cơ học: crop, ép palette, dọn nền).
7. Ảnh chụp trong game ở shop, phần thưởng, tay bài, cột hồi chiêu (720p) lưu ở `production/qa/evidence/card-art/`.
8. Registry: file gen về → `candidate` (qua `asset_registry.py`); chỉ người dùng chuyển `accepted`/`approved`, kèm câu trích.

---

## 8. Câu hỏi cho người dùng

| # | Quyết định | Đề xuất của tôi |
|---|---|---|
| Q1 | Master Reference card art: lấy hoa_xa làm style anchor? | Có — hoa_xa là card duy nhất đã accept |
| Q2 | Tool: `create_image_pixflux` (32×32, ép palette bằng ảnh) hay `create_image_pro_flash` | pixflux — prompts.md đã chạy với nó, ép palette được |
| Q3 | Palette card: `tessera_master.gpl` hay `ui_icons_55.png` | tessera_master — một nguồn màu cho cả game |
| Q4 | Nền + viền: một hex nền phẳng (đề xuất `#2C2A35`) + viền 1 px `#1B1722`? | Có |
| Q5 | Vết nứt Rạn (ran_kich, ran_van): bỏ tím để tránh trùng Khối Lạ? | Có, đổi sang Mực + Ngà |
| Q6 | Card nguyền có nền riêng (tối hơn) không? | Không — dùng chung, khung đã báo nguyền |
| Q7 | 13 art đã cài: xem lại kiem_khi / 3 kiếm giống nhau / hoa_tinh trước hay sau batch mới? | Sau pilot — khi style đã chốt mới biết cần làm lại cái nào |
| Q8 | 12 card chưa vào registry + candidate batch2/v2 chưa đăng ký: cho người giữ registry thêm vào backlog/candidate? | Có, trước bước 1 |
