# Story 020 — Mô phỏng ba chính sách chọn thưởng (Phase D)

Script: scratch `deck_sim.gd` (SceneTree headless, mô phỏng ở mức logic với BossBrain, SwingArbiter, CutEffects, StatusEffects, Deck, RewardRoller, RunSession thật; người chơi là bot). 70 seed × 3 nhân vật × 3 chính sách = 210 run mỗi chính sách, dt 0,05 s, chương 1 đủ 3 tầng, chạy 477,6 s ngày 2026-10-24. Dữ liệu JSON không bị chỉnh trong lần đo này.

## Kết quả

| Nhân vật | Chính sách | Thắng chương % | Tầng qua TB | Máu cuối (run thắng) | Bộ cuối | Tổng cấp lá | Trận thắng TB | Tỉ lệ trúng của bot |
|---|---|---|---|---|---|---|---|---|
| kiem_si | luôn bỏ qua | 18,6 | 1,57 | 38,0 | 6,00 | 6,00 | 7,20 | 0,69 |
| kiem_si | ngẫu nhiên | 17,1 | 1,40 | 40,4 | 9,79 | 11,87 | 6,80 | 0,68 |
| kiem_si | theo build | **38,6** | 1,91 | 38,7 | 7,50 | 11,54 | 8,13 | 0,68 |
| phap_su | luôn bỏ qua | 2,9 | 0,93 | 22,0 | 6,00 | 6,00 | 5,06 | 0,70 |
| phap_su | ngẫu nhiên | 4,3 | 0,96 | 31,0 | 9,04 | 10,66 | 5,30 | 0,69 |
| phap_su | theo build | **7,1** | 1,13 | 42,6 | 7,39 | 10,41 | 5,81 | 0,68 |
| sat_thu | luôn bỏ qua | 20,0 | 1,71 | 34,1 | 6,00 | 6,00 | 7,89 | 0,69 |
| sat_thu | ngẫu nhiên | 20,0 | 1,67 | 33,6 | 10,43 | 12,74 | 7,74 | 0,69 |
| sat_thu | theo build | **41,4** | 2,03 | 42,8 | 7,53 | 11,84 | 8,67 | 0,68 |

Chênh "theo build" − "luôn bỏ qua": kiem_si +20,0 điểm, sat_thu +21,4 điểm, phap_su +4,3 điểm (ngưỡng story: ≥ 25). Máu cuối của "theo build" cao hơn ở cả ba. Khác biệt bộ cuối giữa ba nhân vật cùng seed (Jaccard đa tập): 0,562 trên 210 cặp (ngưỡng > 0,5: đạt).

## Bot (giả định, ghi để diễn giải đúng)

- Đứng yên ở ô mặc định; né đòn boss với xác suất 0,85 sau 0,2 s; nhịp thi triển 1,2–2,2 s; ngắm boss 0,9; bao ô lân cận boss trước.
- "Đánh ngay sau khi boss bước": trong 0,15 s sau một bước của boss, chọn số ô lớn nhất có thời gian vung nằm trong cooldown bước còn lại (trừ 0,05 s). Với boss phản ứng 0,35–0,45 s, chỉ đòn 1–2 ô là chắc trúng, nên phần lớn lá thưởng (≥ 3 ô, ghim, đốt) hiếm khi được bot dùng. Lợi thế của "theo build" vì thế đến chủ yếu từ nâng cấp Kiếm khí.
- Lá cần > 5 ô không bao giờ được bot dùng. Ghim gần như vô giá trị với bot. Pháp sư (3 Hỏa trận cần 5 ô, máu 80) đo ra yếu nhất một phần vì bot không đánh 5 ô như người.
- dt 0,1 làm bot thiệt (boss bước và đòn chạm cùng tick, boss xử lý trước); dùng 0,05.

## Diễn giải

Chọn lá theo build nhân đôi tỉ lệ thắng chương cho hai nhân vật dùng được bộ của mình, và điều kiện máu cùng điều kiện khác biệt bộ đều đạt. Ngưỡng 25 điểm chưa chạm (thiếu 4–5 điểm) với một bot không dùng được 2/3 pool; không chỉnh JSON để làm vừa lòng bot. Kết luận thật sự thuộc về cổng chơi thử sau Story 021 và nội dung chương 2–3. Ghi chú cân bằng: bộ khởi đầu Pháp sư và lá Băng phong (7 ô) trong mọi bộ khởi đầu.
