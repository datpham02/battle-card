# Game Brief: Kaiten Duel

> **v2 — 2026-10-18.** Pivot sau cổng chơi thử 2: bỏ băng chuyền (thao tác với vật thể chuyển động quá khó), bỏ địch đánh tự động theo giờ (nhàm), chuyển sang hai lưới 3×3 kiểu Mega Man Battle Network, quầy sushi chung và boss cũng chơi thẻ. v1 nằm trong lịch sử git (commit `2f4e31b`).

**One-sentence pitch:** Đấu bài thời gian thực trên hai lưới 3×3 đối mặt, nơi bạn và boss cùng giành những đĩa sushi đang nguội dần trên một quầy chung, rồi dùng thẻ để bước, đánh theo hình dạng tầm, và parry đúng lúc để làm boss loạng choạng.

## Core loop
- Đĩa (thẻ) dọn ra **quầy chung** giữa hai lưới, mỗi đĩa có đồng hồ độ tươi; ôi thì biến mất, đĩa mới dọn ra. Chạm để lấy vào tay (4 ô). **Boss cũng với tay lấy đĩa từ quầy này**, và bạn thấy nó với tới đĩa nào.
- Dùng thẻ: *Step* kéo lên ô kề để bước; thẻ đánh chạm để dùng, trúng theo **hình dạng tầm** tính từ ô bạn đứng (ô trước mặt, cả hàng, quét cột…); *Guard* cộng giáp. Mỗi thẻ có recovery riêng; không có cast time.
- Boss chơi thẻ của nó với **khoảng vung**: bạn thấy lá bài nó giơ và vùng tầm sáng lên trên lưới của bạn → bước ra khỏi vùng, đỡ, hoặc **Parry/Counter trong cửa sổ cuối**.
- Parry thành công: boss rơi thẻ, bị choáng, thanh **Posture** tăng; đầy thì boss loạng choạng vài giây (đòn của bạn gấp đôi). Bạn được xóa recovery ngay. Hạ boss → trận kế, lặp lại.

## Player goal & fail state — what "working" looks like
- Vượt một run gồm 3 trận + 1 boss bằng cách đọc thẻ boss, giành đĩa đúng lúc và parry đúng nhịp.
- Thua khi HP về 0. Một run cảm giác hoàn chỉnh trong khoảng 8–12 phút.

## MVP — what must exist to be the game
1. Hai lưới 3×3 đối mặt; thẻ *Step* di chuyển người chơi; thẻ đánh/đỡ dùng bằng chạm với hình dạng tầm đọc từ dữ liệu; recovery theo thẻ (làm lại trên nền Story 003/005).
2. Quầy sushi chung: 6 đĩa đứng yên, đồng hồ độ tươi, dọn đĩa mới, chạm để lấy vào 4 ô tay (thay băng chuyền).
3. Boss chơi thẻ: tay bài riêng rút từ cùng quầy; thẻ giơ lên + khoảng vung + vùng tầm hiện trên lưới bạn là báo đòn; luật chọn thẻ theo trọng số trong JSON; không còn đòn tự động theo giờ.
4. Parry/Counter: cửa sổ cuối khoảng vung; boss rơi thẻ + choáng; thanh Posture → loạng choạng; người chơi xóa recovery.
5. Bộ 10–12 thẻ có hình dạng tầm (Step, Guard, Strike, Cannon, Wide Slash, Dash, Parry, Counter…), tất cả trong dữ liệu.
6. Boss "học" bằng bộ đếm trong trận (né sớm nhiều → feint nhiều; spam đánh → giữ Guard).
7. Một run: 3 trận + boss, màn thắng/thua, chơi lại không cần thoát.

## Out of scope — not building this
- Băng chuyền (bỏ hẳn); di chuyển tự do bằng d-pad; Custom Gauge dừng trận.
- Ghép thẻ — chuyển sang sau MVP (hướng `merge_rules.json` giữ trong backlog).
- AI học máy; boss phải đọc được bằng luật.
- Meta progression (hướng "thực đơn", xem `design/ideas-backlog.md`), quảng cáo/IAP/gacha.
- Nhiều nhân vật, nhiều map, cốt truyện; online/PvP/xếp hạng.
- Đa ngôn ngữ, tùy chọn accessibility — để sau.

## Build order
1. Lưới + Step + đánh theo hình dạng trên nền code hiện có (chứng minh vị trí có ý nghĩa).
2. Quầy chung thay băng chuyền.
3. Boss chơi thẻ với khoảng vung → **cổng chơi thử 3: trận đấu đầu tiên có thật**.
4. Parry/Counter/Posture.
5. Bộ thẻ đầy đủ + boss học bằng bộ đếm.
6. Cấu trúc run.

---
**Who it's for / what they feel:** Người chơi mobile thích Mega Man Battle Network và deckbuilder, chơi ngang hai tay, phiên 10 phút; cảm giác "mình đọc được nó và cướp đúng đĩa nó cần".

**Art & audio direction:** 2D cartoon tươi sáng, quầy sushi là đấu trường, hai võ sĩ ngồi đối diện qua quầy; SFX giòn, nhạc jazz/lo-fi vui tai.

**Reference game:** Mega Man Battle Network — giữ ~10%: hai lưới 3×3 và đòn có hình dạng tầm; **không** giữ Custom Gauge hay di chuyển tự do. Quầy chung và boss cướp bài là phần riêng của game này.
