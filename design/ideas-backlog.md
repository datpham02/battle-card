# Ideas Backlog — Kaiten Duel

Ý tưởng đã **đồng ý** nhưng chưa nằm trong MVP (brief v2, 2026-10-18). Không bắt đầu mục
"Sau MVP" trước cổng chơi thử 3 (sau Story 008). Mỗi mục ghi vấn đề nó giải quyết.

## Đã vào MVP v2 (ghi để truy vết)
- Thẻ "đúng lúc" (Counter/Parry) → Story 009, mở rộng thành hệ Parry/Posture.
- Boss dùng thẻ hiệu quả bằng luật trọng số, không học máy → Story 008.
- Boss "học" trong trận bằng bộ đếm (né sớm → feint; spam đánh → Guard) → Story 010.
- Vị trí có ý nghĩa cho cả công lẫn thủ (từng là phương án A "khoảng cách") → trả lời bằng lưới 3×3 + hình dạng tầm, Story 006.
- Tell nhiều lớp (từ Punch-Out) → một phần của khoảng vung + cửa sổ parry, Story 008/009.

## Sau MVP (đã đồng ý, chưa làm)

### Ghép thẻ theo công thức (từng là MVP v1)
Ghép 2 thẻ trong tay theo bảng `merge_rules.json` (A + A = A nâng cấp; sau đó A + B = C như Strike + Step = Dash).
Lý do lùi: v2 đã có đủ quyết định mỗi giây; thêm ghép sau khi quầy chung và boss ổn.

### Ô lưới có trạng thái (phương án B)
Ô có thuộc tính theo chủ đề và thay đổi theo thời gian: *wasabi* (đòn ×2, nhận thêm sát thương), *trà nóng* (hồi giáp), *nước tương* (trơn, không bước được 2 s). Boss có thể "đổ" trạng thái lên lưới bạn. Data-driven; làm vị trí thành tài nguyên phải tranh.

### Thanh Posture cho người chơi + buff Focus
Đối xứng với boss: người chơi cũng có Posture; parry thành công có thể cho *Focus* 3 s (đòn +50%) thay cho "xóa recovery". Chọn sau chơi thử Story 009.

### Boss thay đổi quầy
Thủ đoạn riêng mỗi boss tác động vào quầy chung: đĩa ôi nhanh hơn khi boss nổi giận; boss "ăn" đĩa; boss đặt *Rotten Sushi* (chiếm ô tay nếu lỡ lấy, *Chef's Knife* cắt được); dọn đĩa theo nhịp nhạc (từ NecroDancer, nhẹ). Gắn với Story 011 nhưng làm sau.

### Elixir ngược
Mỗi thẻ chơi làm đĩa trên quầy ôi nhanh hơn trong 3 s: spam thẻ thì tự làm mình đói bài. Tự cân bằng không cần luật cấm. Thử bằng một số trong JSON.

### Custom Gauge (phương án lùi)
Nếu cổng chơi thử 3 cho thấy quầy chung vẫn quá tải: cứ ~8 s trận dừng 2 s để sắp xếp tay (kiểu Mega Man Battle Network). Giữ làm phương án lùi, không làm trước.

### Meta progression bằng "thực đơn"
Hướng chính thức: mở khóa món mới (thẻ) và chọn "thực đơn" 8–10 thẻ trước mỗi run (deckbuilding nhẹ) thay cho nâng chỉ số. Cần Story 011 và bộ thẻ lớn hơn 10–12.

### Daily Counter
Quầy có seed theo ngày; mọi người gặp cùng chuỗi đĩa, so điểm. Offline hoàn toàn; bảng xếp hạng online là tùy chọn sau. Cần điểm số và Story 011.

## Đã cân nhắc và loại
- Phương án C "băng chuyền là chiến trường" (đĩa độc chạy trên băng): bị thay bởi quầy chung + boss cướp bài, giữ được ý "hai hệ nhập một" mà không cần vật thể chuyển động.
- Băng chuyền v1: bỏ vì thao tác với vật thể chuyển động quá khó.
- AI học máy cho boss: không đọc được, không cân bằng được; dùng luật trọng số + bộ đếm.
- PvP thời gian thực, nhiều nhân vật từ đầu, combo chuỗi kiểu fighting game: như v1.
