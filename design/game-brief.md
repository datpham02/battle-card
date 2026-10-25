# Game Brief: Ấn Kiếm (tên làm việc; repo vẫn là Kaiten Duel)

> **v4 — 2026-10-22.** Sau cổng chơi thử 4 và khi cả 16 story đã xong, người dùng quyết định hai việc: (1) **bỏ chủ đề bếp sushi, dựng thế giới fantasy**; (2) **thêm lớp roguelike**: 3–5 nhân vật với bộ bài khởi đầu, nội tại và tuyệt kỹ riêng (không có "lớp"), đi tầng để nhặt lá và build bộ bài, **chết là hết run** (hồi sinh là item thêm sau). Cơ chế lõi của v3 giữ nguyên, chỉ đổi vỏ: điểm cắt → **ấn**, đường dao → **trận pháp**, kỹ năng → **phép** (lá bài). Lịch sử: v1 băng chuyền (`2f4e31b`), v2 lưới 3×3 + quầy chung (`be73d17`), v3 hệ cắt (`e9efe25`), v3 hoàn thiện đến Story 016 (`0974bd9`).

> **v5 — 2026-10-24 (mảnh ấn, Story 024–027).** Sau lần chơi thử đầu, người dùng thấy đánh trúng boss quá khó và việc nối ấn đòi nhớ quy ước chu vi. Phép đo (40 đòn mỗi ô, logic game thật) cho thấy boss thường né 50–100 % đòn từ 3 ô trở lên, ô giữa sân chỉ trúng được bằng trận pháp ≥ 3 ô. Quyết định: **bỏ nối ấn, thay bằng mảnh ấn** — mỗi ấn rơi là một mảnh hình sẵn (1–5 ô, xoay được), người chơi chọn mảnh, đặt lên chỗ bất kỳ vừa khít trên đất địch, rồi chọn lá. Mỗi lần nhặt là một vùng, nhiều mảnh nối nhau để dồn boss. Mục "Core loop" bên dưới là luật v5; luật nối ấn v3 là lịch sử (`980b372`).

**One-sentence pitch:** Đấu phép thời gian thực trên hai trận địa đối mặt: bạn chạy nhặt những **mảnh ấn** rơi xuống đất mình, đặt một mảnh lên đúng chỗ bạn đoán địch sẽ đứng rồi thi triển một **lá phép**; mảnh càng nhiều ô phép càng mạnh nhưng niệm càng lâu, ai thi triển trước thì phá phép của người kia; mỗi run chọn một nhân vật, nhặt lá qua từng tầng, **chết là hết**.

## Thế giới (vỏ, không đổi cơ chế)
- Hai lưới đối mặt là hai **trận địa**. Thứ rơi xuống là **ấn** (rune) mang tọa độ chu vi trận địa đối thủ. Nối ấn = vẽ **trận pháp**; bấm **Thi triển** = niệm; khoảng vung = thời gian niệm, hiện đỏ trên đất địch; **phá phép** = ngắt đòn hai chiều.
- **Lá phép** (card) là biến thể trên cùng trận pháp: *Kiếm khí* (Chém), *Chấn phong* (Đẩy), *Hỏa trận* (Đốt), *Băng phong* (Ghim). Hiệu ứng y nguyên bảng v3.
- **Đặc điểm boss** (trait, Story 014) đổi tên: hàng cháy → *Hỏa tức* (hơi thở lửa quét một hàng), điểm hỏng → *Ấn nguyền* (ấn bị nguyền, chiếm chỗ trong túi ấn, tự tan sau vài giây).
- **Chương** = vùng đất. Chương 1 *Rừng Sương* (sân vuông, chữ nhật; goblin, sói), chương 2 *Hầm Ngục* (sân có lỗ, hai đảo; quỷ, xác sống), chương 3 *Tháp Pháp Sư* (vòng, kim cương, biến thể; pháp sư tà đạo, golem). Tên boss, trait và số của chương 2–3 là nội dung, làm dần.
- Tên nhân vật, lá, chương, boss, vùng đất là **dữ liệu** (`characters.json`, `cards.json`, `chapters.json`) dưới dạng **khóa dịch** (`name_key`); chữ hiển thị nằm trong `assets/i18n/strings.csv`.

## Đa ngôn ngữ (2026-10-22, từ Story 017)
- Hệ dịch của Godot: `assets/i18n/strings.csv` (`keys,vi,en`), code gọi `tr(khóa)`; mọi `TEXT_*` trong mã là khóa, JSON chỉ giữ `name_key`. Hai ngôn ngữ ngay từ đầu: **vi** (mặc định, fallback) và **en**. Nút VI/EN ở title, lưu trong `progress.json`. Ngôn ngữ thứ ba = thêm một cột CSV. Thiếu khóa thì hiện khóa thô để lộ lỗi; một test quét khóa trong mã và JSON đối chiếu CSV.

## Core loop (v5 — mảnh ấn, Story 024–027)

### Sân và di chuyển
- Hai lưới đối mặt; mỗi bên đi trong nửa của mình. **Kích thước và hình lưới là dữ liệu** (`side_cols`, `side_rows`, `missing_cells`; thư viện 8 hình trong `arenas.json`, biến thể seeded có kiểm).
- **Nút di chuyển 4 hướng**, một ô mỗi lần, không nhớ lệnh. **Cooldown bước theo sân**: `0,45 × (2 / (max(cột, hàng) − 1)) ^ 0,75`, kẹp [0,18; 0,60]. Bước lên ô có mảnh là nhặt (tự khóa mình một cooldown).

### Mảnh ấn rơi (Story 024)
- **Bộ hình** (`pieces.json`): khoảng 12 hình chuẩn 1–5 ô — ô đơn; thanh 2; thanh 3, L3; vuông 2×2, T, L, S, thanh 4; vài hình 5 ô (chữ thập, chữ U, thanh 5). Mỗi hình có `weight` theo chương (chương 1 nhiều mảnh nhỏ, mảnh 5 ô hiếm). Hình không đặt vừa ở đâu trên đất địch của trận hiện tại thì không rơi.
- Mảnh rơi xuống ô trống ngẫu nhiên bên mình với **hướng xoay ngẫu nhiên**, nhịp, số tối đa trên sân và độ tươi trong `field_drops.json` (khởi điểm 3,0 s, 3, 8 s; chỉnh bằng mô phỏng). Vào trận có sẵn `start_pieces` mảnh (khởi điểm 1). **Túi mảnh tối đa 3.**
- Mảnh nhỏ nhìn ngay trên sân (hình thu nhỏ, không có chữ).

### Đặt mảnh và phép
- **Chọn mảnh** trong túi (chạm / kéo / phím 1–3) → vào **chế độ đặt**: nếu **Tập trung** sẵn sàng thì trận **dừng hẳn** tối đa 4 s (cooldown 8 s, như v3), nếu không thì chậm 0,2×. D-pad khóa khi đặt.
- **Bóng mảnh** theo con trỏ / ngón tay, hít vào lưới đất địch; chỉ đặt được khi **mọi ô** rơi vào ô thật của đất địch. **Xoay 90°**: phím R, chuột phải, hoặc chạm lại vào mảnh đang chọn. Không lật.
- **Báo trúng**: bóng mảnh xanh khi ô boss đang đứng nằm trong mảnh, đỏ khi không. Số ô và sát thương dự kiến hiện cạnh bóng.
- Thả / chạm xác nhận → **menu phép** như v4 (rút 4 lá, chậm 0,2×, 3 s, hết giờ tự *Kiếm khí*; lá chưa đủ ô hiện khóa "cần N ô"). Hủy (Esc / nút hủy) trả mảnh về túi.
- **Mỗi đòn 1–2 mảnh** (Story 028; trước đó 1); mảnh dùng xong mất. **Sát thương = sát thương mỗi ô của lá × tổng số ô của đòn**; **thời gian niệm = 0,2 s + 0,25 s × tổng số ô**; đang niệm vẫn đi được; mỗi bên một phép đang niệm.
- **Phá phép**: ai chạm ô đối thủ trước thì hủy phép đối thủ đang niệm; mảnh của bên bị hủy mất luôn.
- `min_cells` của lá ≤ 5 (mảnh lớn nhất). Lá cần 6–7 ô của v4 hạ xuống trong Story 024.

| Lá phép (cơ bản) | Cần | Cooldown | Hiệu ứng |
|---|---|---|---|
| Kiếm khí | bất kỳ | không | sát thương × số ô |
| Chấn phong | ≥ 3 ô | 6 s | đẩy lùi 1 ô + sát thương nhẹ |
| Hỏa trận | ≥ 5 ô | 8 s | tập ô cháy 3 s, đứng trong mất máu dần; chặn đường |
| Băng phong | ≥ 4 ô (v4: 7) | 10 s | đóng băng 1,2 s |

### Ghép mảnh và hình chủ đạo (Story 028, chốt 2026-10-25)
- Thả mảnh đầu vẫn mở menu phép ngay. Trong lúc menu mở (chậm 0,2×) kéo thêm **một** mảnh lên đất địch để gắn vào đòn (+1,5 s thời gian chọn lá); hai mảnh không chồng ô, chạm cạnh hay rời nhau đều được. Không ghép trong túi. Không giới hạn cứng số ô (túi 3, tối đa 2 mảnh, niệm theo tổng ô); khóa dự phòng `max_cast_cells` mặc định tắt.
- Mỗi sân có một **hình chủ đạo** 5–7 ô gợi dáng sân (`arenas.json`, trận ghi đè được), hiện nhỏ trên HUD. Đòn **2 mảnh** có hợp ô trùng hình chủ đạo (xoay được, không lật) được **×1,5 sát thương + một hiệu ứng theo chủ đề trận** (Rạn / Ghim / Đốt / Hàn). Mỗi sân phải ghép được hình của nó từ ít nhất 2 cặp mảnh.

### Trận đồ (Story 029, chốt 2026-10-25)
- Mỗi đòn người chơi tới nơi (trúng hay trượt) làm sáng các ô nó phủ trên đất địch; ô sáng **phai** sau `5 s + 0,8 s × số ô đất địch` (3×3 ≈ 12,2 s; chỉnh 2026-10-25 từ 4 s + 0,6 s theo đo bằng bot). **Mọi ô cùng sáng** = trận đồ hoàn thành. Tuyệt kỹ **sẵn sàng khi trận đồ đủ VÀ đã hết thời gian hồi** (riêng từng nhân vật, `cooldown_sec` trong `characters.json`; tuyệt kỹ có hiệu lực theo thời gian hồi sau khi hiệu lực hết). Dùng tuyệt kỹ thì trận đồ xóa; hồi và tích trận đồ mới chạy song song (chốt 2026-10-25). Trận đồ **thay thanh nạp 18 ô**. Không đồng hồ đếm ngược chung: phai từng ô là giới hạn.

### Vùng: Kết giới và Trận gai (Story 027)
- **Kết giới**: ô của mảnh không bước vào được trong thời gian ngắn. **Trận gai**: bước vào được nhưng mất máu hoặc dính Rạn — đánh đổi máu để né. Cả người chơi (lá) và boss (trait chương 2–3) đều dùng. Luật cứng: luôn chừa ít nhất 1 ô bước được cho bên bị nhốt; tường và gai có hình khác hẳn nhau.

### Boss
- **Đến hết Story 024** boss vẫn nối ấn kiểu v3 trên đất người chơi. **Từ Story 025** boss nhặt và đặt **mảnh** bằng cùng hệ: não trọng số chấm điểm (mảnh, vị trí, hướng xoay) theo đường thoát của người chơi; **boss đứng yên khi đang niệm** (cửa sổ phản công, cờ dữ liệu theo trận); vòng hồi bước của boss (đã có) hiện thêm trạng thái khóa khi niệm. Hồ sơ di chuyển theo trận, đòn nối, trait cắm được. Boss dùng **bộ phép cố định theo trận** (`boss_cards`), không rút bài.

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
| Nhịp rơi, tối đa trên sân, độ tươi (mảnh, v5) | 3,0 s, 3, 8 s (khởi điểm, chỉnh bằng mô phỏng) | `field_drops.json` |
| Bộ hình mảnh, trọng số theo chương, mảnh lúc vào trận | ~12 hình 1–5 ô; 1 | `pieces.json` |
| Túi mảnh | 3 | `hold_slots.json` |
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
17. **Mảnh ấn** (v5, 2026-10-24): **024** mảnh phía người chơi (rơi, nhặt, túi 3, đặt, xoay, báo trúng, hạ `min_cells`) → **cổng chơi thử 7**; **028** ghép tối đa 2 mảnh + hình chủ đạo; **029** trận đồ thay thanh nạp; **025** boss dùng và ghép mảnh, nhắm hình chủ đạo, đứng yên khi niệm, vòng hồi bước hiện khóa; **026** gỡ hệ nối ấn, chuyển test và mô phỏng, đo lại cân bằng; **027** Kết giới / Trận gai.
18. Cửa hàng/pact → lên Android → hình và âm.

---
**Who it's for / what they feel:** Người chơi mobile thích Mega Man Battle Network và Slay the Spire, chơi ngang hai tay, phiên 15–25 phút một run; cảm giác "mình đoán đúng chỗ địch chạy tới, đặt mảnh chặn đầu, rút đúng lá và nó ra kịp".

**Art & audio direction:** 2D fantasy sáng, hơi cartoon; hai trận địa là nền đá khắc; ấn là ký tự phát sáng; trận pháp vẽ sáng rồi bùng. SFX phép giòn, nhạc orchestral nhẹ. Placeholder vẽ bằng code cho tới phase hình.

**Reference game:** Mega Man Battle Network (hai lưới, một ô mỗi bước, màn chọn làm chậm thời gian) + Slay the Spire (chọn 1 trong 3 lá, chết là hết, nhặt trùng = nâng cấp) + Hades (nhân vật là cá nhân với tuyệt kỹ riêng, mọi vật phẩm dùng chung). Mảnh ấn đặt tự do lên đất địch, đoán bước né của địch, sát thương theo số ô là phần riêng (v3–v4 dùng nhãn chu vi và nối ấn).
