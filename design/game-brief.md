# Game Brief: Kaiten Duel

**One-sentence pitch:** Một game card battler 2D thời gian thực trên mobile, nơi các võ sĩ vui nhộn giành lấy đòn đánh từ băng chuyền sushi, ghép thẻ giống nhau để mạnh hơn và đọc đòn báo trước của địch để sống sót qua từng trận.

## Core loop
- Thẻ trôi trên băng chuyền → chọn thẻ nào giữ (3–4 ô), thẻ không lấy sẽ trôi mất.
- Ghép 2 thẻ giống nhau thành thẻ mạnh hơn (số lần ghép có giới hạn).
- Địch báo trước đòn (biểu tượng + làn + đếm ngược) → kéo thẻ phù hợp ra sân để đánh, né, đỡ hoặc ngắt đòn.
- Mỗi thẻ có recovery riêng (không dùng được thẻ khác trong lúc đó, băng chuyền vẫn chạy) → thắng trận, đi tiếp, lặp lại.

## Player goal & fail state — what "working" looks like
- Mục tiêu: vượt hết một run (3 trận thường + 1 boss) bằng cách đọc đòn địch và chọn đúng thẻ.
- Thua khi HP về 0. Một run cảm giác hoàn chỉnh trong khoảng 8–12 phút.

## MVP — what must exist to be the game
1. Băng chuyền sinh thẻ, thẻ trôi qua và biến mất nếu không lấy.
2. 3–4 ô giữ thẻ, kéo thẻ từ băng chuyền vào ô giữ.
3. Ghép 2 thẻ giống nhau thành thẻ nâng cấp.
4. Kéo thẻ ra sân để kích hoạt, mỗi thẻ có recovery riêng.
5. 10–12 loại thẻ (đánh, đỡ, Dash Strike, Sidestep, Knockback…).
6. Địch với đòn báo trước (biểu tượng, làn, đếm ngược) trên 3 làn cố định.
7. Một run ngắn: 3 trận + boss, có màn thắng/thua.

## Out of scope — not building this
- Tiến trình meta (mở khóa thẻ/kỹ năng, nâng cấp nhân vật, tỷ lệ rơi thẻ) — thêm sau khi vòng chơi đã vui.
- Quảng cáo, mua trong ứng dụng, gacha.
- Nhiều nhân vật, nhiều map, cốt truyện.
- Online, PvP, xếp hạng.
- Thẻ có windup/bị ngắt, thẻ di chuyển độc lập.
- Đa ngôn ngữ, tùy chọn accessibility (làm chậm băng chuyền) — để sau.

## Build order
1. Băng chuyền + ô giữ + kéo thẻ đánh một địch giả, chưa có làn (prototype 30 giây: có vui không?).
2. Ghép thẻ + recovery.
3. Địch với đòn báo trước và đếm ngược.
4. 3 làn cố định + thẻ Dash/Sidestep/Knockback.
5. Cấu trúc run: 3 trận + boss, màn thắng/thua.
6. Chỉ sau đó mới xét tiến trình meta.

---
**Who it's for / what they feel:** Người chơi mobile phương Tây thích roguelite/deckbuilder, muốn run ngắn; cảm giác gấp gáp nhưng đọc được, "mình vừa chọn đúng thẻ vào đúng lúc".

**Art & audio direction:** 2D cartoon tươi sáng, nhà hàng sushi làm đấu trường, võ sĩ vui nhộn nét dày; SFX giòn, nhạc jazz/lo-fi vui tai.

**Reference game:** Slay the Spire — giữ khoảng 10%: đòn địch hiện ý định trước và cấu trúc run; không giữ lượt chơi, thay bằng băng chuyền thời gian thực.
