# Story 023 — Mô phỏng ba chương (Phần D)

Bộ mô phỏng `deck_sim.gd` (logic thật: BossBrain, SwingArbiter, CutEffects, StatusEffects với Rạn/Hàn, giáp phẳng, năm trait mới, tuyệt kỹ, thưởng; người chơi là bot) chạy từng chương như một run độc lập với bộ bài khởi đầu, `cleared_bosses` = 1. 70 seed × 3 nhân vật, dt 0,05 s, chính sách theo build, máu 200/160/180. Ngày 2026-10-24. Raw: `simulation-70seeds-raw.txt` (dữ liệu chưa chỉnh).

## Dữ liệu như đã giao (chưa chỉnh)

| Chương | Kiếm sĩ | Pháp sư | Sát thủ | Mục tiêu story |
|---|---|---|---|---|
| 1 | 91,4 % | 45,7 % | 84,3 % | 40–60 % |
| 2 | 0 % | 0 % | 0 % | 25–45 % |
| 3 | 0 % | 0 % | 0 % | 15–35 % |

**Chương 2 và 3 chưa thắng được lần nào với dữ liệu hiện tại.** Đây là vấn đề dữ liệu, không chỉ do bot.

## Nguyên nhân (đo, không suy đoán)

`CombatConfig.step_cooldown_for` co cooldown bước của boss theo cỡ sân: 0,45 s (vuông) → 0,33 (chữ nhật, chữ thập) → 0,27 (5×5) → 0,23 (vòng). Cộng với leo thang −0,1 mỗi chương, bước hiệu lực của boss sân lớn là 0,23–0,29 s so với 0,37–0,80 s ở chương 1: ogre_king 0,23, rat_king_guard 0,25, ghost_elite 0,24, ice_golem và mist_lord 0,27. Boss gần như né mọi đòn. Mọi trận 0 % hay hết giờ 180 s đều nằm trên sân lớn; giáp, Rạn/Hàn, trait và máu không phải điểm nghẽn (ghost trên sân chữ nhật vẫn thắng 20–41 % nhờ lửa).

Thí nghiệm chẩn đoán `--step-mult` (20 seed): ×1,5 đưa chương 2 lên 55/10/80 % và chương 3 lên 35/5/20 %; ×2,0 quá tay.

## Bộ chỉnh đã đo, chưa áp dụng

Nhân bước từng trận (file `chapters.json`), giữ nguyên mọi thứ khác: ogre_king 1,01 → 1,5 và máu 260 → 290; rat_king_guard 1,12 → 1,6; bat_swarm 1,34 → 1,7; ghost 1,0 → 1,3; ghost_elite 0,9 → 1,3; stone_sentry 1,24 → 1,9 và move_commitment 0,9 → 0,7; snow_wolf 1,1 → 1,6; ice_golem 1,02 → 1,5; rime_archer 1,1 → 1,4; frost_mage 1,1 → 1,6 và máu 190 → 210; mist_lord 1,0 → 1,5; jailer 1,12 → 1,3.

Kết quả đo lại, 70 seed:

| Chương | Kiếm sĩ | Pháp sư | Sát thủ | Mục tiêu |
|---|---|---|---|---|
| 2 | 58,6 % | 7,1 % | 58,6 % | 25–45 % |
| 3 | 20,0 % | 0,0 % | 18,6 % | 15–35 % |

Chương 3 vào dải mục tiêu cho Kiếm sĩ và Sát thủ; chương 2 hơi dễ cho hai nhân vật này. Pháp sư không thắng nổi ở cả hai chương: xem TD-008.

## Cân bằng nhân vật (tiêu chí tương đối, quyết định của người dùng)

Chênh lệch tỷ lệ thắng giữa nhân vật cao nhất và thấp nhất: chương 1 là 46 điểm, chương 2 là 51 điểm (có bộ chỉnh), chương 3 là 20 điểm. Pháp sư lệch ở cả ba chương. Đã thử: máu Pháp sư 180/200 (chương 1 lên 62,9/70,0 %, chương 2 lên 18,6 %, chương 3 vẫn 0 %), giảm máu Kiếm sĩ và Sát thủ (chương 2–3 không thắng được), thay một Hỏa trận 5 ô bằng Hỏa tinh 3 ô (không đổi). Nguyên nhân nằm ở nội tại wide_caster và tuyệt kỹ Thiên Hỏa. Người dùng chọn chờ buổi chơi thử trước khi chỉnh (TD-008).

## Giới hạn của phép đo

- Bot chỉ đánh 1–2 ô trước boss né, hằng số né 85 % chuẩn từ Story 020 với máu 100 (TD-006): số tuyệt đối chỉ để so sánh tương đối.
- Số đòn trúng mỗi run thắng là 8–11, thấp hơn mục tiêu 15–30 như ở Story 022.
- Rule-breaker đo riêng: Bóng Ma hay hết giờ (6 trong 17 trận cho Kiếm sĩ), Kẻ Phản Ứng và Pháo Ngòi thắng 90–100 %, Quỷ Khổng Lồ và Pháp Sư Sương 0 % với dữ liệu chưa chỉnh do vấn đề tốc độ bước.
