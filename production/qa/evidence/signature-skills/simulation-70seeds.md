# Story 021 — Mô phỏng chính sách "theo tuyệt kỹ" (Phần C)

Cùng bộ mô phỏng của Story 020 (`deck_sim.gd`, logic thật, bot người chơi), thêm tuyệt kỹ nối y hệt `CombatView` (nạp theo ô đã thi triển, kích hoạt theo luật bot, hook sát thương và bước) và chính sách thứ tư `signature`. 70 seed × 3 nhân vật × 4 chính sách, dt 0,05 s, chương 1; chạy hai đợt vì giới hạn 10 phút một lượt (A: skip/build/signature 493 s; B: random 171 s), cùng seed nên so sánh được. Dữ liệu JSON không đổi. Ngày 2026-10-24. Raw: `simulation-70seeds-raw.txt`.

## Kết quả (thắng chương %, máu cuối run thắng, số lần kích tuyệt kỹ mỗi run, tỉ lệ sát thương từ tuyệt kỹ)

| Nhân vật | Chính sách | Thắng % | Máu cuối | Kích/run | Sát thương TK % |
|---|---|---|---|---|---|
| kiem_si | luôn bỏ qua | 27,1 | 54,0 | 7,96 | 4,8 |
| kiem_si | ngẫu nhiên | 25,7 | 42,9 | 7,13 | 4,5 |
| kiem_si | theo build | **44,3** | 61,0 | 7,09 | 4,7 |
| kiem_si | theo tuyệt kỹ | 30,0 | 67,6 | 6,61 | 4,4 |
| phap_su | luôn bỏ qua | 1,4 | 22,0 | 3,03 | 0,9 |
| phap_su | ngẫu nhiên | 5,7 | 46,8 | 3,56 | 2,0 |
| phap_su | theo build | 2,9 | 30,5 | 3,31 | 1,1 |
| phap_su | theo tuyệt kỹ | 4,3 | 44,3 | 3,54 | 1,9 |
| sat_thu | luôn bỏ qua | 20,0 | 40,9 | 5,90 | 0,0 |
| sat_thu | ngẫu nhiên | 21,4 | 37,6 | 5,43 | 0,2 |
| sat_thu | theo build | 32,9 | 32,3 | 4,91 | 0,2 |
| sat_thu | theo tuyệt kỹ | **37,1** | 32,7 | 5,17 | 0,5 |

Chênh "theo tuyệt kỹ" − "luôn bỏ qua": kiem_si +2,9, phap_su +2,9, sat_thu +17,1 (ngưỡng ≥ 25: không đạt). Khác biệt bộ cuối giữa ba nhân vật cùng seed: 0,657 (ngưỡng > 0,5: đạt).

So với Story 020 cùng seed (khi chưa có tuyệt kỹ): luôn-bỏ-qua kiem_si 18,6 → 27,1 %, build kiem_si 38,6 → 44,3 %. **Trảm một mình nâng Kiếm sĩ 6–9 điểm.** Thiên Hỏa và Ảnh Bộ không nâng được bot.

## Diễn giải

- Tuyệt kỹ được dùng 3–8 lần mỗi run nhưng chiếm dưới 5 % sát thương. Trảm 3 s chỉ bắt được ~1 lần thi triển của bot. Thiên Hỏa cần bộ nhiều lửa mà bot ít đốt. Ảnh Bộ trong sim gần như luôn kích khi chưa ghim nên nhân ×2 hiếm khi áp dụng; lợi ích của nó là bước tự do, không đo được bằng sát thương.
- Chính sách chọn lá "theo tuyệt kỹ" cho Kiếm sĩ (ưu tiên sát thương mỗi ô cao nhất) **kém** chính sách "theo build" (ưu tiên nâng cấp lá đã có) 14 điểm: nâng cấp lá sẵn có mạnh hơn nhặt lá mới. Đây là tín hiệu thiết kế thật, không phải lỗi bot.
- Giới hạn bot như TD-001: chỉ đánh 1–2 ô trước boss né, không dùng được phần lớn pool.

## Ghi chú cân bằng cho chơi thử

1. Trảm có tác dụng đo được; Thiên Hỏa và Ảnh Bộ cần điều kiện (nhiều ô cháy, địch đang bị ghim) mà bot không tạo ra; người thật có thể, cần xem khi chơi.
2. Ảnh Bộ: cân nhắc cho ×2 áp dụng với mọi lá ≤ 3 ô trong lúc hiệu lực, không cần ghim, nếu chơi thử thấy yếu.
3. Nâng cấp lá đã có đáng giá hơn lá mới: UI nên làm nổi lựa chọn nâng cấp.
