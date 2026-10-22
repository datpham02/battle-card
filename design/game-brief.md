# Game Brief: Ấn Kiếm (tên làm việc; repo vẫn là Kaiten Duel)

> **v4 — 2026-10-22.** Sau cổng chơi thử 4 và khi cả 16 story đã xong, người dùng quyết định hai việc: (1) **bỏ chủ đề bếp sushi, dựng thế giới fantasy**; (2) **thêm lớp roguelike**: 3–5 nhân vật theo lớp, bộ bài khởi đầu theo lớp, đi tầng để nhặt lá và build bộ bài, **chết là hết run** (hồi sinh là item thêm sau). Cơ chế lõi của v3 giữ nguyên, chỉ đổi vỏ: điểm cắt → **ấn**, đường dao → **trận pháp**, kỹ năng → **phép** (lá bài). Lịch sử: v1 băng chuyền (`2f4e31b`), v2 lưới 3×3 + quầy chung (`be73d17`), v3 hệ cắt (`e9efe25`), v3 hoàn thiện đến Story 016 (`0974bd9`).

**One-sentence pitch:** Đấu phép thời gian thực trên hai trận địa đối mặt: bạn chạy nhặt những **ấn** rơi xuống đất mình, nối chúng thành **trận pháp** vẽ thẳng lên đất địch rồi thi triển một **lá phép**; trận pháp càng phủ nhiều ô phép càng mạnh nhưng niệm càng lâu, ai thi triển trước thì phá phép của người kia; mỗi run chọn một nhân vật, nhặt lá qua từng tầng, **chết là hết**.

## Thế giới (vỏ, không đổi cơ chế)
- Hai lưới đối mặt là hai **trận địa**. Thứ rơi xuống là **ấn** (rune) mang tọa độ chu vi trận địa đối thủ. Nối ấn = vẽ **trận pháp**; bấm **Thi triển** = niệm; khoảng vung = thời gian niệm, hiện đỏ trên đất địch; **phá phép** = ngắt đòn hai chiều.
- **Lá phép** (card) là biến thể trên cùng trận pháp: *Kiếm khí* (Chém), *Chấn phong* (Đẩy), *Hỏa trận* (Đốt), *Băng phong* (Ghim). Hiệu ứng y nguyên bảng v3.
- **Đặc điểm boss** (trait, Story 014) đổi tên: hàng cháy → *Hỏa tức* (hơi thở lửa quét một hàng), điểm hỏng → *Ấn nguyền* (ấn bị nguyền, chiếm chỗ trong túi ấn, tự tan sau vài giây).
- **Chương** = vùng đất. Chương 1 *Rừng Sương* (sân vuông, chữ nhật; goblin, sói), chương 2 *Hầm Ngục* (sân có lỗ, hai đảo; quỷ, xác sống), chương 3 *Tháp Pháp Sư* (vòng, kim cương, biến thể; pháp sư tà đạo, golem). Tên boss, trait và số của chương 2–3 là nội dung, làm dần.
- Tên nhân vật, lá, chương, boss, vùng đất là **dữ liệu** (`characters.json`, `cards.json`, `chapters.json`), không có chuỗi chủ đề nào trong mã ngoài nhãn UI chung (nút, tiêu đề màn).

## Core loop (cơ chế v3, giữ nguyên số)

### Sân và di chuyển
- Hai lưới đối mặt; mỗi bên đi trong nửa của mình. **Kích thước và hình lưới là dữ liệu** (`side_cols`, `side_rows`, `missing_cells`; thư viện 8 hình trong `arenas.json`, biến thể seeded có kiểm). Nhãn chu vi sinh theo lưới (A/C theo cột, B/D theo hàng).
- **Nút di chuyển 4 hướng**, một ô mỗi lần, không nhớ lệnh. **Cooldown bước theo sân**: `0,45 × (2 / (max(cột, hàng) − 1)) ^ 0,75`, kẹp [0,18; 0,60]. Bước lên ô có ấn là nhặt (tự khóa mình một cooldown).

### Ấn rơi
- Rơi xuống ô trống ngẫu nhiên bên mình theo **túi xáo** đủ nhãn, **nhịp 1,8 s**, tối đa 4 trên sân, **độ tươi 7 s** (trong túi không ôi), bù khi đói (túi trống > 4 s → nhịp × 0,6). Túi ấn tối đa **4**. Boss dùng đúng túi và nhịp.
- Không hiện trước nhãn sắp rơi; không rơi theo kịch bản.

### Trận pháp và phép
- **1 ấn** + Thi triển = *Kiếm khí* ngay, đường thẳng sang điểm đối diện, không menu. **2–4 ấn**: chạm lần lượt (thứ tự chạm = thứ tự nối), xem trước tập ô và số ô, bấm Thi triển.
- **Sát thương = 6 × số ô phủ**; **thời gian niệm = 0,2 s + 0,25 s × số ô**; đang niệm vẫn đi được; mỗi bên một phép đang niệm.
- **Tập trung**: chọn ấn đầu tiên dừng hẳn trận tối đa 4 s, cooldown 8 s, không đi được khi dừng. Boss không có.
- **Menu phép** sau khi Thi triển 2–4 ấn: chậm 0,2×, 3 s chọn, hết giờ tự *Kiếm khí*. Lá chưa đủ ô hiện khóa "cần N ô". **v4: menu rút 4 lá từ bộ bài** (xem Roguelike) thay vì 4 phép cố định.
- **Phá phép**: ai chạm ô đối thủ trước thì hủy phép đối thủ đang niệm; ấn đã dùng của bên bị hủy mất luôn.

| Lá phép (cơ bản) | Cần | Cooldown | Hiệu ứng |
|---|---|---|---|
| Kiếm khí | bất kỳ | không | sát thương × số ô |
| Chấn phong | ≥ 3 ô | 6 s | đẩy lùi 1 ô theo hướng trận pháp + sát thương nhẹ |
| Hỏa trận | ≥ 5 ô | 8 s | tập ô cháy 3 s, đứng trong mất máu dần; chặn đường |
| Băng phong | ≥ 7 ô | 10 s | đóng băng 1,2 s |

### Boss
- Đi nhặt và thi triển bằng **cùng hệ**, não trọng số trong JSON, hồ sơ di chuyển theo trận, chấm điểm theo đường thoát, đòn nối ở trận cao, trait cắm được. Không dấu hiệu ý định. Boss dùng **bộ phép cố định theo trận** (`boss_cards`, mặc định 4 lá cơ bản), không rút bài.

## Roguelike (v4, Story 017–019)

### Lá bài và bộ bài (017)
- `cards.json` thay `skills.json`: mỗi lá có id, tên, hiệu ứng, số ô cần, cooldown, tham số, **độ hiếm** (thường / hiếm / sử thi) và **thẻ lớp** (lớp nào hay gặp). Bốn lá cơ bản là bản đầu; lá mới = thêm JSON + (nếu hiệu ứng mới) một lớp hiệu ứng đăng ký như trait.
- **Bộ bài** của người chơi: danh sách lá (6–12). Mỗi lần Thi triển 2–4 ấn, menu **rút 4 lá theo túi xáo** từ bộ (hết túi xáo lại; seeded). Lá rút rồi không trả lại cho đến khi hết túi. Lá trùng được phép (hai *Kiếm khí* trong bộ = ra thường hơn). Cooldown tính theo id lá như nay.
- Hết giờ chọn → *Kiếm khí* cơ bản dù tay không có lá đó (luật, không phải lá).

### Nhân vật theo lớp (018)
- `characters.json`: id, tên, mô tả, máu, hệ số cooldown bước, thời gian Tập trung, **nội tại** (passive id + tham số), **bộ khởi đầu** (danh sách id lá), đã mở khóa hay chưa.
- Ba lớp đầu: **Kiếm sĩ** (máu 100, bộ 2 Kiếm khí 2 Chấn phong 1 Hỏa trận 1 Băng phong, nội tại: hồi thêm máu sau mỗi trận), **Pháp sư** (máu 80, Tập trung 5 s, bộ nặng Hỏa trận và phép diện rộng, nội tại: trận pháp ≥ 5 ô niệm nhanh hơn 15 %), **Sát thủ** (máu 90, bước nhanh hơn 10 %, bộ nặng Băng phong và đòn 1–2 ấn, nội tại: phép ≤ 3 ô mạnh hơn 25 %). Thợ săn, Giáo sĩ là nhân vật 4–5, mở sau. Số là khởi điểm, chỉnh sau chơi thử.
- Nội tại là lớp nhỏ đăng ký như trait (`PassiveRegistry`), đọc/ghi qua API công khai.

### Run (019)
- **Một run = chọn nhân vật → một chương** (3 tầng, mỗi tầng N trận rồi boss) → thắng boss tầng cuối là thắng run. Tầng trong chương đi tuần tự; màn chọn tầng thành **chọn chương** (chương mở khi chương trước đã thắng bằng bất kỳ nhân vật nào).
- Sau mỗi trận thắng: **chọn 1 trong 3 lá** (rút từ pool theo độ hiếm và thẻ lớp, seeded), hoặc bỏ qua. Lá vào bộ ngay.
- **Máu là tài nguyên của cả run**: hồi `heal_between_matches` sau mỗi trận, `heal_between_floors` sau boss tầng, không đầy lại khi sang tầng.
- **Chết là hết run**: màn "RUN KẾT THÚC" (tầng, trận, số lá, thời gian), về title. Không chơi lại trận, không giữ bộ bài. Hồi sinh (item, mạng dự phòng) là cơ chế thêm sau; `revive_tokens` trong JSON để sẵn, mặc định 0.
- **Save**: run đang dở (nhân vật, bộ bài, chương, tầng, trận, máu, seed) ghi ở mốc trận, nút *Tiếp tục* trên title. Vĩnh viễn: chương đã thắng, nhân vật đã mở, lá đã thấy (để mở pool dần, làm sau).
- Để sau (backlog): bỏ lá / nâng lá giữa tầng, sự kiện giữa trận, tiền và cửa hàng, item hồi sinh, Daily seed.

## Player goal & fail state
- Thắng một run: đi hết chương với nhân vật đã chọn, bộ bài bạn tự nhặt, trong khoảng 15–25 phút.
- Thua khi máu về 0: run kết thúc, chỉ giữ mở khóa vĩnh viễn.

## Số khởi điểm (tất cả trong `assets/data/`)

| Tham số | Khởi điểm | File |
|---|---|---|
| Cooldown bước (3×3) người chơi / hệ số boss | 0,45 s / theo trận | `combat.json`, `chapters.json` |
| Nhịp rơi, tối đa trên sân, độ tươi, đói | 1,8 s, 4, 7 s, 4 s × 0,6 | `field_drops.json` |
| Túi ấn | 4 | `hold_slots.json` |
| Niệm cơ bản, niệm mỗi ô, sát thương mỗi ô | 0,2 s, 0,25 s, 6 | `cuts.json` |
| Menu: time scale, thời gian chọn, số lá rút | 0,2, 3 s, 4 | `cards.json` |
| Tập trung | 4 s, cooldown 8 s | `cards.json` |
| Bộ khởi đầu, máu, nội tại theo lớp | bảng trên | `characters.json` |
| Thưởng: số lá đưa ra, trọng số độ hiếm | 3; thường 70 / hiếm 25 / sử thi 5 | `rewards.json` |
| Hồi máu sau trận / sau tầng | 25 / 40 | `chapters.json` |

## Out of scope
- Đã loại: Parry/Guard/giáp, thẻ hình dạng tầm, băng chuyền, quầy chung, ghép thẻ, AI học máy, Custom Gauge.
- v4 chưa làm: bỏ/nâng lá, cửa hàng, tiền, sự kiện, item hồi sinh, Daily seed, PvP, online, cốt truyện dài, đa ngôn ngữ, accessibility.

## Build order
1–9. v1→v3 (Story 001–016, xong 2026-10-21): lưới, di chuyển, ấn rơi, trận pháp, boss, phép, Tập trung, hồ sơ boss, sân và trait, chương/tầng + save, title/tạm dừng.
10. **Lá bài và bộ bài + đổi vỏ fantasy** (017).
11. **Nhân vật theo lớp + nội tại + màn chọn nhân vật** (018).
12. **Run roguelike: thưởng lá, máu cả run, chết là hết, save run** (019) → **cổng chơi thử 5: run đầu tiên có thật**.
13. Nội dung chương 2–3 (boss, trait, lá mới) → lên Android → hình và âm.

---
**Who it's for / what they feel:** Người chơi mobile thích Mega Man Battle Network và Slay the Spire, chơi ngang hai tay, phiên 15–25 phút một run; cảm giác "mình gom đủ ấn, vẽ một trận pháp to, rút đúng lá và nó ra kịp".

**Art & audio direction:** 2D fantasy sáng, hơi cartoon; hai trận địa là nền đá khắc; ấn là ký tự phát sáng; trận pháp vẽ sáng rồi bùng. SFX phép giòn, nhạc orchestral nhẹ. Placeholder vẽ bằng code cho tới phase hình.

**Reference game:** Mega Man Battle Network (hai lưới, một ô mỗi bước, màn chọn làm chậm thời gian) + Slay the Spire (chọn 1 trong 3 lá, chết là hết, nhân vật theo lớp). Nhãn chu vi, nối ấn thành hình, sát thương theo số ô là phần riêng.
