# Story 022 — Mô phỏng ngân sách đòn trúng trên bản đồ 7 cột (Phần D)

Bộ mô phỏng `deck_sim.gd` (logic thật: BossBrain, SwingArbiter, CutEffects, StatusEffects, Deck, RewardRoller, RunSession v4, tuyệt kỹ; người chơi là bot "đánh ngay sau khi boss bước", né 85 % đòn có báo trước) được chuyển sang bản đồ 7 cột: sinh bản đồ bằng `ChapterMapGen`, bot chọn nút (kho báu > trại nghỉ khi máu < 50 %, còn lại Rèn > boss giữa khi máu ≥ 70 % > trận trước nguy hiểm), trận qua `RunConfig.from_node`, thưởng theo `reward_for_node` với may mắn và sàn hiếm, token bỏ lá, không hồi tự động, máu 300/240/270. 70 seed × 3 nhân vật × {luôn bỏ qua, theo build}, dt 0,05 s, chương 1, `cleared_bosses` = 1 (cộng một hàng Kiếm sĩ onboarding với 0). Ngày 2026-10-24. Raw: `simulation-70seeds-raw.txt` (lần đầu + 6 thí nghiệm chẩn đoán).

## Mục tiêu story: 15–30 đòn trúng mỗi run thắng (ngân sách OSFE)

| Nhân vật | Chính sách | Lần đo 1: thắng % / đòn trúng mỗi run thắng | Sau chỉnh dữ liệu: thắng % / đòn trúng | Sát thương mỗi đòn (% máu) |
|---|---|---|---|---|
| kiem_si | luôn bỏ qua | 100 / 7,0 | 100 / 8,6 | 5,6 |
| kiem_si | theo build | 100 / 7,6 | 100 / 8,7 | 5,8 |
| phap_su | luôn bỏ qua | 81 / 9,0 | 76 / 9,8 | 6,9 |
| phap_su | theo build | 84 / 8,3 | 73 / 9,7 | 7,0 |
| sat_thu | luôn bỏ qua | 100 / 5,8 | 94 / 7,0 | 5,9 |
| sat_thu | theo build | 100 / 5,3 | 99 / 6,0 | 6,4 |

**Kết luận: không đạt** (6–10 đòn, bằng một nửa ngưỡng). Sát thương mỗi đòn 5,6–7,0 % máu đã nằm đúng dải OSFE 3–12 %; thiếu là **số lần trúng**: boss vung ~45–60 lần mỗi run nhưng chỉ trúng 14–21 %, và bot né đánh nhờ kho báu.

## Chỉnh dữ liệu đã áp dụng (giữ lại vì đúng ý thiết kế)

- `chapters.json → defaults.columns`: kho báu chỉ còn là nút phụ ở cột 1; cột 4 là trại nghỉ + trận (trước là trại nghỉ + kho-báu-hoặc-trận). Kho báu mỗi run 2,2 → 0,83; số trận mỗi run 4,3 → 5,2.
- Bốn lính bậc 1–2 của chương 1 (`wolf`, `dire_wolf`, `goblin_archer`, `goblin_warrior`) đổi `brain_set` "cautious" → "balanced". Boss giữa và boss vốn đã balanced/aggressive; `goblin_scout` bậc 0 giữ cautious cho người mới.

## Thí nghiệm chẩn đoán (20 seed, một đòn bẩy mỗi lần, không áp dụng)

| Đòn bẩy | Đòn trúng kiem_si (thắng %) | Đọc |
|---|---|---|
| boss nghĩ và phản ứng ×0,7 | 17,0 (5 %) | boss nhanh hơn làm bot không còn đánh được, trận hết giờ; **không hạ** `boss_think_interval_sec`/`boss_reaction_sec` |
| combo 0,5 mọi trận | 6,0 (100) | không tác dụng, combo bị né hoặc ngắt |
| không nhặt kho báu | 10,4 (100) | +37 % đòn trúng |
| bot né 0,85 → 0,6 | 12,9 (95) | **đòn bẩy lớn nhất là kỹ năng né giả định của bot** |
| máu ×1,5 | 7,3 (100) | máu không đổi số đòn trúng |

## Diễn giải và khuyến nghị

1. Số đòn trúng phụ thuộc chủ yếu vào hằng số né 0,85 của bot, được chuẩn hóa ở Story 020 khi máu còn 100 để bot thắng 20–45 %. Với máu ×3 mốc đó không còn: bot thắng 100 % kể cả không nhặt lá. Nếu người chơi trên điện thoại né khoảng 60–70 % đòn báo trước thì game đã gần mục tiêu hơn con số trên (≈13 đòn). Cần chuẩn hóa lại bot theo một buổi chơi thật trước khi chỉnh thêm dữ liệu (xem TD-001).
2. Máu ×3 có vẻ quá rộng rãi: hai nhân vật thắng 100 % với chính sách "luôn bỏ qua", làm tiêu chí "chọn lá đổi kết quả" của Story 020 trở nên vô nghĩa ở mức bot này. **Khuyến nghị cho buổi chơi thử: thử máu ×2** (200/160/180); sát thương mỗi đòn khi đó ≈ 8,5–10,5 %, vẫn trong dải OSFE.
3. Pháp sư vẫn yếu nhất (73–76 %), nhất quán với TD-002.
4. Trại nghỉ: bot tới cột 4 với máu > 50 % trong 93–100 % run nên hầu như luôn chọn Rèn; "Nghỉ" chỉ có nghĩa khi số đòn trúng tăng.

## Lần đo 3 — máu ×2 (quyết định của người dùng 2026-10-24: "làm khó hơn")

Máu 200/160/180 (thay vì ×3 = 300/240/270 như story viết), Hơi thở thứ hai 30 → 20. Cùng 70 seed, cùng dữ liệu chương đã chỉnh. Raw: `deck_sim.s022.hp2.out` trong scratchpad (bảng chính chép dưới).

| Nhân vật | Chính sách | Thắng % | Đòn trúng mỗi run thắng | Sát thương mỗi đòn (% máu) | Máu cuối (run thắng) |
|---|---|---|---|---|---|
| kiem_si | luôn bỏ qua | 92,9 | 8,0 | 8,4 | 137 |
| kiem_si | theo build | 95,7 | 8,2 | 8,7 | 135 |
| phap_su | luôn bỏ qua | 47,1 | 8,5 | 10,5 | 46 |
| phap_su | theo build | 44,3 | 7,8 | 10,6 | 54 |
| sat_thu | luôn bỏ qua | 85,7 | 6,0 | 9,1 | 79 |
| sat_thu | theo build | 90,0 | 5,5 | 9,5 | 87 |
| kiem_si onboarding | theo build | 87,1 | 8,5 | 8,2 | 129 |

Đọc: với bot né 85 %, run không còn "thắng chắc": Pháp sư thua hơn nửa, hai nhân vật cận chiến thua 4–10 %, boss cuối là nơi thua chính (Pháp sư 58 %). Người thật trên điện thoại né ít hơn bot nên độ khó thực tế cao hơn bảng này; thí nghiệm bot né 0,6 cho thấy số đòn trúng tăng ~70 %. Vì thế **dừng chỉnh ở ×2**, buổi chơi thử sẽ là trọng tài. Tiêu chí 15–30 đòn trúng vẫn không đạt về mặt số (6–8), do mô hình né của bot (xem TD-001, TD-006).
