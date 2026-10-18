# Epic: Kaiten Duel

> **Source**: `design/game-brief.md` (minimal tier — no GDD/ADR; epic synthesized from the brief)
> **Goal (v2)**: Đấu bài thời gian thực trên hai lưới 3×3 đối mặt; bạn và boss cùng giành đĩa sushi trên một quầy chung; dùng thẻ để bước, đánh theo hình dạng tầm, parry đúng lúc để làm boss loạng choạng.
> **Engine**: Godot 4.6 (GDScript), landscape 1280x720 | **Risk**: HIGH (per `docs/engine-reference/godot/VERSION.md`)

## Pivot v2 — 2026-10-18

Sau cổng chơi thử 2 (bản v1 có băng chuyền + địch đánh theo mẫu cố định), người dùng quyết định:
- **bỏ băng chuyền**: thao tác với vật thể chuyển động làm độ khó xử lý quá cao → thay bằng **quầy sushi chung** có độ tươi, chạm để lấy, boss cũng lấy;
- **bỏ đòn tự động theo giờ**: chu kỳ cố định nhàm → **boss cũng chơi thẻ** bằng luật trọng số, khoảng vung là báo đòn;
- **3 làn → hai lưới 3×3** kiểu Mega Man Battle Network; thẻ có hình dạng tầm; cả hai bên di chuyển và tấn công bằng thẻ;
- thêm **Parry/Counter với hậu quả hai chiều** và thanh Posture.

Story 001–003 và 005 (v1) giữ trạng thái Complete làm lịch sử; code của chúng là nền để làm lại. Story 004/006/007 (v1) bị xóa khỏi epic (số 004 không dùng lại); ý tưởng ghép thẻ về backlog.

## Scope

Bảy mục MVP của brief v2. Ngoài phạm vi: băng chuyền, ghép thẻ, AI học máy, meta progression, quảng cáo/IAP, nhiều nhân vật/map, online/PvP, accessibility, đa ngôn ngữ.

## Ordering (build order của brief v2)

1. Lưới + Step + đánh theo hình dạng (006)
2. Quầy chung thay băng chuyền (007)
3. Boss chơi thẻ với khoảng vung (008) → **Cổng quyết định 3: trận đấu đầu tiên có thật — chơi thử trước khi làm 009–011**
4. Parry/Counter/Posture (009)
5. Bộ thẻ đầy đủ + boss học bằng bộ đếm (010)
6. Cấu trúc run (011)

**Cổng quyết định 1 (sau 003, v1):** "tạm ổn", thiếu áp lực → đi tiếp.
**Cổng quyết định 2 (sau 005, v1):** băng chuyền khó thao tác, địch theo giờ nhàm, 3 làn basic → pivot v2.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Băng chuyền sinh thẻ, trôi và biến mất (v1) | Logic | Complete | N/A (minimal) |
| 002 | Ô giữ thẻ và kéo thẻ vào ô (v1) | UI | Complete | N/A (minimal) |
| 003 | Dùng thẻ ra sân + recovery, đánh địch giả (v1) | Logic | Complete | N/A (minimal) |
| 005 | Địch báo trước đòn trên 3 làn (v1) | Integration | Complete | N/A (minimal) |
| 006 | Hai lưới 3×3, Step, đánh theo hình dạng tầm (refit) | Logic | Ready | N/A (minimal) |
| 007 | Quầy sushi chung thay băng chuyền | UI | Ready | N/A (minimal) |
| 008 | Boss chơi thẻ: tay bài, quầy, khoảng vung, brain | Integration | Ready | N/A (minimal) |
| 009 | Parry/Counter, Posture, hậu quả hai chiều | Logic | Ready | N/A (minimal) |
| 010 | Bộ 10–12 thẻ + boss học bằng bộ đếm | Logic | Ready | N/A (minimal) |
| 011 | Run 3 trận + boss, thắng/thua, chơi lại | Integration | Ready | N/A (minimal) |
