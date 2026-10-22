# Ideas Backlog — Kaiten Duel

Ý tưởng đã **đồng ý** nhưng chưa nằm trong MVP (brief v3, 2026-10-18). Không bắt đầu mục
"Sau MVP" trước cổng chơi thử 3 (sau Story 009). Mỗi mục ghi vấn đề nó giải quyết.

## Đã vào MVP v3 (ghi để truy vết)
- Boss dùng cùng hệ với người chơi bằng luật trọng số, không học máy → Story 009.
- Boss "học" trong trận bằng bộ đếm (né sớm → feint; chờ đòn to → đòn nhanh) → Story 010.
- Vị trí có ý nghĩa cho cả công lẫn thủ → lưới 3×3 + tập ô phủ, Story 006/008.
- Tell nhiều lớp (từ Punch-Out) → khoảng vung theo số ô + nhãn điểm boss giơ, Story 009.
- "Dùng đúng lúc" → ngắt đòn hai chiều (đua đồng hồ), Story 009.
- Ngẫu nhiên có kiểm soát cho điểm rơi → túi xáo + nhịp gắn với trận, Story 007.

## Sau MVP (đã đồng ý, chưa làm)

### Đợt cân bằng sau Story 011 (từ cổng chơi thử 3) — **đóng ở cổng 4 (2026-10-20): sau 012–014 người dùng thấy "ổn và cân bằng hơn", không cần đợt riêng**
Kết quả cổng 3: lõi chơi hấp dẫn, boss ép quá, vừa di chuyển vừa nối điểm quá tải. Người dùng chọn hoàn thiện trước. Việc để dành: (1) nhịp boss trận 1 chậm hơn qua `boss_brain.json` (bước 0,70 s, nghĩ 0,50 s, phản ứng 0,60 s, rơi điểm chậm hơn, bộ cautious), tăng dần các trận sau; (2) **Tập trung** đã chuyển thành Story 012 (dừng hẳn 4 s, cooldown 8 s theo yêu cầu người chơi); (3) cân nhắc chạm đúp để chém ngay 1 điểm. Không tự động Chốt (mất quyền đổi ý).


### Thủ đoạn rơi của boss (lớp 3 của luật rơi)
Mỗi boss tác động vào điểm rơi theo cách riêng: điểm ôi nhanh hơn khi boss nổi giận; boss ném *điểm hỏng* sang sân bạn (chiếm ô tay nếu lỡ nhặt); boss "hút" điểm về phía mình; rơi theo nhịp nhạc (từ NecroDancer, nhẹ). Đây là nơi mỗi boss khác nhau mà không cần đổi luật. Gắn với Story 011 nhưng làm sau.

### Hiện trước nhãn sắp rơi
Ô "tiếp theo" nhỏ cạnh tay. Giảm căng thẳng, nên **chỉ thêm nếu** chơi thử thấy quá bực vì đói đúng nhãn dù đã có túi xáo và bù đói.

### Ô lưới có trạng thái (mở rộng từ Đốt)
Ô có thuộc tính theo chủ đề: *wasabi* (đòn ×2, nhận thêm sát thương), *trà nóng* (hồi HP chậm), *nước tương* (trơn, không bước được 2 s). Boss có thể "đổ" trạng thái lên lưới bạn. Đốt (Story 010) là bản đầu tiên của khung này.

### Kỹ năng thứ 5+ và kỹ năng theo hình
Ví dụ: tam giác → *Xiên* (đẩy 2 ô), hình chữ nhật → *Lồng* (ghim 2 s). Chỉ sau khi 4 kỹ năng MVP được cân bằng; nguy cơ làm menu quá tải.

### Điểm lăn từ bên boss sang bên bạn (và ngược lại)
Giữ lại chút "tranh giành" của ý quầy chung đã loại: vài điểm rơi ở cột giữa rồi lăn dần sang nửa sân bên kia; ai bước lên trước thì được.

### Elixir ngược
Mỗi đòn chốt làm điểm trên sân ôi nhanh hơn trong 3 s: spam đòn thì tự làm mình đói. Tự cân bằng không cần luật cấm. Thử bằng một số trong JSON.

### Rơi theo kịch bản (phương án lùi)
Nếu túi xáo vẫn cho những ván "không ra gì", thử kịch bản nửa cố định: 12 lần rơi đầu theo thứ tự thiết kế, sau đó mới túi xáo. Mất tính chơi lại, nên là phương án lùi.

### Cấu trúc chương / tầng → **Story 015 (viết 2026-10-20)**
Đã chốt thêm ở cổng 4: thua giữa tầng → chơi lại **đúng trận đã thua** (cùng sân, máu ≥ 50%); pool rút **từng trận**; save data = tầng đã xong + tầng đang dở theo mốc trận. **v4 (2026-10-22) thay luật chơi lại bằng chết-là-hết-run (Story 019); màn chọn tầng thành chọn chương.** Phần còn lại giữ nguyên bên dưới làm truy vết.

Người dùng muốn người chơi vượt chương/tầng: mỗi tầng N trận rồi boss. Một run hiện nay = một tầng, nên `run.json` sẽ thành `chapters: [{id, tên, matches, boss}]` và `RunState` nhận một chương; thêm màn chọn chương và màn qua tầng; thắng boss tầng N mở tầng N+1 (cần lưu ít nhất tầng cao nhất → kéo một phần meta progression vào). Quyết định tạm: tầng thấp dùng **một hình cố định cho cả tầng** để học được; tầng cao rút **ngẫu nhiên từ nhóm hình** (`arena_pool`) kèm biến thể có kiểm (Story 014) nên mỗi lần vào là một sân khác; **máu không mang qua tầng**, mỗi tầng bắt đầu đầy, trong tầng mang như hiện nay. Story 013/014 (sân, hồ sơ, trait theo trận) là nền cho tầng khác nhau.

### Meta progression bằng "thực đơn" → **Story 017–019 (v4, 2026-10-22)**
Đã thành lớp roguelike: lá bài (017), nhân vật (018), thưởng lá và run (019); **bỏ khái niệm "lớp"** (2026-10-22) → bộ bài có sức nặng: sát thương theo lá, nâng cấp khi nhặt trùng, bỏ lá, Ghim/Đốt (020) và tuyệt kỹ nhân vật khuếch đại bộ bài (021). Còn lại cho sau: xem bộ bài trong run, cửa hàng và tiền, sự kiện giữa trận, **item hồi sinh** (người dùng: chết là hết trước, hồi sinh thêm sau), mở pool lá theo `seen_cards`, kháng/yếu theo kẻ địch, pool 16–20 lá tới cuối chương 2, mở khóa nhân vật 4–5 (Thợ săn, Giáo sĩ).

### Daily Counter
Túi xáo có seed theo ngày; mọi người gặp cùng chuỗi điểm, so điểm. Offline hoàn toàn; bảng xếp hạng online là tùy chọn sau. Cần điểm số và Story 011.

### Ghép thẻ theo công thức (từng là MVP v1)
Không còn khớp với hệ điểm; giữ dòng này làm lịch sử, nhiều khả năng bỏ hẳn.

## Đã cân nhắc và loại
- **Parry/Counter/Posture/Focus** (v3, 2026-10-18): cần căn thời gian 0,5 s trên màn cảm ứng và thêm thẻ/nút riêng; thay bằng **ngắt đòn**: dùng chính hệ cắt, tự cân bằng với "càng nhiều ô càng mạnh nhưng càng lâu".
- **Guard và giáp** (v3): với sát thương theo số ô và đua đồng hồ, giáp làm mờ phép tính; phòng thủ là di chuyển và ra đòn sớm.
- **Thẻ đánh theo hình dạng tầm** (Strike/Cannon/Wide Slash, v3): bị thay bởi hình vẽ từ điểm; `AttackShape` của Story 006 là tiền thân của `CutResolver`.
- **Gate kỹ năng theo số điểm nối** (v3): người dùng chốt gate theo **số ô phủ**; số ô hiện trước khi chốt để người chơi biết.
- **Menu kỹ năng dừng hẳn**: mặc định chậm 0,2× để không ai dùng menu làm nút tạm dừng; dừng hẳn là một số trong JSON nếu cần.
- **Quầy sushi chung** (v2): thay bằng điểm rơi trên ô của mỗi bên (v2.1) vì rơi làm vị trí có thêm mục đích và gỡ được một vùng UI.
- **Thẻ Step để di chuyển**: tạo vòng lặp chết với điểm rơi; thay bằng nút 4 hướng một ô mỗi lần.
- Phương án C "băng chuyền là chiến trường", băng chuyền v1: thao tác với vật thể chuyển động quá khó.
- AI học máy cho boss: không đọc được, không cân bằng được; dùng luật trọng số + bộ đếm.
- PvP thời gian thực, nhiều nhân vật từ đầu, combo chuỗi kiểu fighting game: như v1.
