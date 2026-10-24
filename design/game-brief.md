# Game Brief: Ấn Kiếm (tên làm việc; repo vẫn là Kaiten Duel)

> **v4 — 2026-10-22.** Sau cổng chơi thử 4 và khi cả 16 story đã xong, người dùng quyết định hai việc: (1) **bỏ chủ đề bếp sushi, dựng thế giới fantasy**; (2) **thêm lớp roguelike**: 3–5 nhân vật với bộ bài khởi đầu, nội tại và tuyệt kỹ riêng (không có "lớp"), đi tầng để nhặt lá và build bộ bài, **chết là hết run** (hồi sinh là item thêm sau). Cơ chế lõi của v3 giữ nguyên, chỉ đổi vỏ: điểm cắt → **ấn**, đường dao → **trận pháp**, kỹ năng → **phép** (lá bài). Lịch sử: v1 băng chuyền (`2f4e31b`), v2 lưới 3×3 + quầy chung (`be73d17`), v3 hệ cắt (`e9efe25`), v3 hoàn thiện đến Story 016 (`0974bd9`).

**One-sentence pitch:** Đấu phép thời gian thực trên hai trận địa đối mặt: bạn chạy nhặt những **ấn** rơi xuống đất mình, nối chúng thành **trận pháp** vẽ thẳng lên đất địch rồi thi triển một **lá phép**; trận pháp càng phủ nhiều ô phép càng mạnh nhưng niệm càng lâu, ai thi triển trước thì phá phép của người kia; mỗi run chọn một nhân vật, nhặt lá qua từng tầng, **chết là hết**.

## Thế giới (vỏ, không đổi cơ chế)
- Hai lưới đối mặt là hai **trận địa**. Thứ rơi xuống là **ấn** (rune) mang tọa độ chu vi trận địa đối thủ. Nối ấn = vẽ **trận pháp**; bấm **Thi triển** = niệm; khoảng vung = thời gian niệm, hiện đỏ trên đất địch; **phá phép** = ngắt đòn hai chiều.
- **Lá phép** (card) là biến thể trên cùng trận pháp: *Kiếm khí* (Chém), *Chấn phong* (Đẩy), *Hỏa trận* (Đốt), *Băng phong* (Ghim). Hiệu ứng y nguyên bảng v3.
- **Đặc điểm boss** (trait, Story 014) đổi tên: hàng cháy → *Hỏa tức* (hơi thở lửa quét một hàng), điểm hỏng → *Ấn nguyền* (ấn bị nguyền, chiếm chỗ trong túi ấn, tự tan sau vài giây).
- **Chương** = vùng đất. Chương 1 *Rừng Sương* (sân vuông, chữ nhật; goblin, sói), chương 2 *Hầm Ngục* (sân có lỗ, hai đảo; quỷ, xác sống), chương 3 *Tháp Pháp Sư* (vòng, kim cương, biến thể; pháp sư tà đạo, golem). Tên boss, trait và số của chương 2–3 là nội dung, làm dần.
- Tên nhân vật, lá, chương, boss, vùng đất là **dữ liệu** (`characters.json`, `cards.json`, `chapters.json`) dưới dạng **khóa dịch** (`name_key`); chữ hiển thị nằm trong `assets/i18n/strings.csv`.

## Đa ngôn ngữ (2026-10-22, từ Story 017)
- Hệ dịch của Godot: `assets/i18n/strings.csv` (`keys,vi,en`), code gọi `tr(khóa)`; mọi `TEXT_*` trong mã là khóa, JSON chỉ giữ `name_key`. Hai ngôn ngữ ngay từ đầu: **vi** (mặc định, fallback) và **en**. Nút VI/EN ở title, lưu trong `progress.json`. Ngôn ngữ thứ ba = thêm một cột CSV. Thiếu khóa thì hiện khóa thô để lộ lỗi; một test quét khóa trong mã và JSON đối chiếu CSV.

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
- `cards.json` thay `skills.json`: mỗi lá có id, tên, hiệu ứng, số ô cần, cooldown, tham số, **độ hiếm** (thường / hiếm / sử thi) và (từ 020) **sát thương mỗi ô riêng** cùng bảng **nâng cấp** 3 cấp. Không có thẻ lớp. Bốn lá cơ bản là bản đầu; lá mới = thêm JSON + (nếu hiệu ứng mới) một lớp hiệu ứng đăng ký như trait.
- **Bộ bài** của người chơi: danh sách lá (6–12). Mỗi lần Thi triển 2–4 ấn, menu **rút 4 lá theo túi xáo** từ bộ (hết túi xáo lại; seeded). Lá rút rồi không trả lại cho đến khi hết túi. Lá trùng được phép (hai *Kiếm khí* trong bộ = ra thường hơn). Cooldown tính theo id lá như nay.
- Hết giờ chọn → *Kiếm khí* cơ bản dù tay không có lá đó (luật, không phải lá).

### Nhân vật (018, 021) — không có "lớp"
- `characters.json`: id, tên, mô tả, máu, hệ số cooldown bước, thời gian Tập trung, **nội tại** (passive id + tham số), **bộ khởi đầu** (danh sách id lá), đã mở khóa hay chưa.
- Ba nhân vật đầu: **Kiếm sĩ** (máu 100, bộ 2 Kiếm khí 2 Chấn phong 1 Hỏa trận 1 Băng phong, nội tại: hồi thêm máu sau mỗi trận), **Pháp sư** (máu 80, Tập trung 5 s, bộ nặng Hỏa trận và phép diện rộng, nội tại: trận pháp ≥ 5 ô niệm nhanh hơn 15 %), **Sát thủ** (máu 90, bước nhanh hơn 10 %, bộ nặng Băng phong và đòn 1–2 ấn, nội tại: phép ≤ 3 ô mạnh hơn 25 %). Thợ săn, Giáo sĩ là nhân vật 4–5, mở sau. Số là khởi điểm, chỉnh sau chơi thử.
- Nội tại là lớp nhỏ đăng ký như trait (`PassiveRegistry`), đọc/ghi qua API công khai.
- **Không có "lớp" (quyết định 2026-10-22):** không lá nào gắn nhân vật, thưởng không nghiêng theo nhân vật. Nhân vật nào cũng chơi được mọi bộ; thứ lái người chơi là **tuyệt kỹ** (021): một kỹ năng chủ động nạp theo số ô đã Thi triển, **mạnh lên theo bộ bài** chứ không tự mạnh. **Kiếm sĩ — Trảm** (3 s, ô ×2, hút máu 20 %: khuếch đại lá sát thương cao); **Pháp sư — Thiên Hỏa** (kích nổ cháy ×2, đặt lại cooldown lá đốt: khuếch đại lửa chồng); **Sát thủ — Ảnh Bộ** (2 s bước không cooldown, địch bị ghim ăn ×2 từ lá ≤ 3 ô: khuếch đại ghim + lá nhỏ). Đa dạng đến từ pool lá (cần 16–20 lá tới cuối chương 2) và hai từ khóa dùng chung **Ghim** (địch bị ghim ăn ×1,5 từ đòn kiếm) và **Đốt** (cháy chồng tối đa 3 tầng).

### Run (019) — mở rộng ở 022/023 theo tham chiếu OSFE
- **Bản đồ chương (022):** một chương = **7 cột**, mỗi cột 1–3 nút để chọn, khung cố định + ngẫu nhiên seeded: cột 0 một trận; cột 1–2 và 5 là 2–3 nút {trận, nguy hiểm, kho báu}; cột 3 có đúng một **boss giữa**; cột 4 có đúng một **trại nghỉ**; cột 6 **boss**. Pool trận theo loại nút và bậc cột; người chưa thắng boss nào luôn gặp bậc dễ (onboarding ẩn, OSFE `CalculateStageNum`).
- **Thưởng theo loại nút (022):** trận/nguy hiểm → 1 trong 3 lá; kho báu → 1 trong 3 lá không cần đánh; boss giữa → 3 lá sàn hiếm; boss → 3 lá + **1 token bỏ lá**. Bỏ lá là token (khởi đầu 1), không còn miễn phí mỗi trận. Độ hiếm **trôi theo may mắn** tích lũy +1 mỗi nút (70/25/5 % → 31/35/34 % ở 70).
- **Máu (022):** không hồi tự động sau trận; chỉ hồi ở **trại nghỉ** (Nghỉ 30 % máu hoặc Rèn +1 cấp một lá). Máu tối đa ×3 (300/240/270) để một đòn ≈ 4–15 % máu, mục tiêu 15–30 đòn trúng một run (ngân sách OSFE).
- **Độ hiếm không mua sát thương (023):** sử thi 8 sát thương/ô kèm điều kiện (Hành quyết dưới 25 %, ×1,5 khi Rạn); hiếm 7–8; thường 6–7. Từ khóa dùng chung: **Ghim** (khống chế), **Rạn** (×1,5 đòn kế tiếp, 3 tầng), **Hàn** (3 tầng nổ 24 xuyên giáp), **Đốt** (chồng 3). Pool 24 lá.
- **Địch phá luật (023):** mỗi chương 2 kẻ ép đổi lối chơi: Bóng Ma (máu thấp, giáp phẳng cao: cần Đốt/xuyên giáp), Kẻ Phản Ứng (vung khi ta bước: thưởng đứng yên), Pháo Ngòi (ngòi 12 s: kiểm tra DPS). Địch leo thang 4 trục: máu, nhịp bước, giáp, cỡ trận pháp.

### Run (019) — luật gốc
- **Một run = chọn nhân vật → một chương** (3 tầng, mỗi tầng N trận rồi boss) → thắng boss tầng cuối là thắng run. Tầng trong chương đi tuần tự; màn chọn tầng thành **chọn chương** (chương mở khi chương trước đã thắng bằng bất kỳ nhân vật nào).
- Sau mỗi trận thắng: **chọn 1 trong 3 lá** (rút từ pool theo độ hiếm, seeded; không nghiêng theo nhân vật), hoặc bỏ qua, hoặc (từ 020) **bỏ 1 lá**. Lá vào bộ ngay; nhặt lá đã có = **nâng cấp** (tối đa +2).
- **Máu là tài nguyên của cả run**: hồi `heal_between_matches` sau mỗi trận, `heal_between_floors` sau boss tầng, không đầy lại khi sang tầng.
- **Chết là hết run**: màn "RUN KẾT THÚC" (tầng, trận, số lá, thời gian), về title. Không chơi lại trận, không giữ bộ bài. Hồi sinh (item, mạng dự phòng) là cơ chế thêm sau; `revive_tokens` trong JSON để sẵn, mặc định 0.
- **Save**: run đang dở (nhân vật, bộ bài, chương, tầng, trận, máu, seed) ghi ở mốc trận, nút *Tiếp tục* trên title. Vĩnh viễn: chương đã thắng, nhân vật đã mở, lá đã thấy (để mở pool dần, làm sau).
- Để sau (backlog): sự kiện giữa trận, tiền và cửa hàng, item hồi sinh, Daily seed.

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
| Bộ khởi đầu, máu, nội tại, tuyệt kỹ theo nhân vật | bảng trên | `characters.json` |
| Thưởng: số lá đưa ra, trọng số độ hiếm | 3; thường 70 / hiếm 25 / sử thi 5 | `rewards.json` |
| Hồi máu sau trận / sau tầng | 25 / 40 | `chapters.json` |

## Out of scope
- Đã loại: Parry/Guard/giáp, thẻ hình dạng tầm, băng chuyền, quầy chung, ghép thẻ, AI học máy, Custom Gauge.
- v4 chưa làm: bỏ/nâng lá, cửa hàng, tiền, sự kiện, item hồi sinh, Daily seed, PvP, online, cốt truyện dài, accessibility, ngôn ngữ thứ ba trở đi (khung đa ngôn ngữ có từ 017).

## Build order
1–9. v1→v3 (Story 001–016, xong 2026-10-21): lưới, di chuyển, ấn rơi, trận pháp, boss, phép, Tập trung, hồ sơ boss, sân và trait, chương/tầng + save, title/tạm dừng.
10. **Lá bài và bộ bài + đa ngôn ngữ vi/en + đổi vỏ fantasy** (017).
11. **Nhân vật + nội tại + màn chọn nhân vật** (018).
12. **Run roguelike: thưởng lá, máu cả run, chết là hết, save run** (019) → **cổng chơi thử 5: run đầu tiên có thật**.
13. **Bộ bài có sức nặng** (020): sát thương theo lá, nâng cấp khi nhặt trùng, bỏ lá, từ khóa Ghim/Đốt, bỏ khái niệm lớp.
14. **Tuyệt kỹ nhân vật** (021): thanh nạp, Trảm / Thiên Hỏa / Ảnh Bộ, khuếch đại bộ bài.
15. **Bản đồ chương và kinh tế thưởng** (022): 7 cột, khung cố định + nhánh 2–3, token bỏ lá, thưởng theo loại nút, độ hiếm trôi theo may mắn, trại nghỉ thay hồi 25/40, máu ×3.
16. **Nội dung chương 2–3** (023): boss/trait mới, địch phá luật, lá sử thi có điều kiện, Rạn/Hàn, pool 24 → **cổng chơi thử 6: run đầu tiên đủ nội dung**.
17. Cửa hàng/pact → lên Android → hình và âm.

---
**Who it's for / what they feel:** Người chơi mobile thích Mega Man Battle Network và Slay the Spire, chơi ngang hai tay, phiên 15–25 phút một run; cảm giác "mình gom đủ ấn, vẽ một trận pháp to, rút đúng lá và nó ra kịp".

**Art & audio direction:** 2D fantasy sáng, hơi cartoon; hai trận địa là nền đá khắc; ấn là ký tự phát sáng; trận pháp vẽ sáng rồi bùng. SFX phép giòn, nhạc orchestral nhẹ. Placeholder vẽ bằng code cho tới phase hình.

**Reference game:** Mega Man Battle Network (hai lưới, một ô mỗi bước, màn chọn làm chậm thời gian) + Slay the Spire (chọn 1 trong 3 lá, chết là hết, nhặt trùng = nâng cấp) + Hades (nhân vật là cá nhân với tuyệt kỹ riêng, mọi vật phẩm dùng chung). Nhãn chu vi, nối ấn thành hình, sát thương theo số ô là phần riêng.
