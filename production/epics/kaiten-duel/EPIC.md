# Epic: Kaiten Duel

> **Source**: `design/game-brief.md` (minimal tier — no GDD/ADR; epic synthesized from the brief)
> **Goal**: Game card battler 2D thời gian thực trên mobile, nơi võ sĩ giành đòn đánh từ băng chuyền sushi, ghép thẻ và đọc đòn báo trước của địch để sống sót qua một run.
> **Engine**: Godot 4.6 (GDScript) | **Risk**: HIGH (per `docs/engine-reference/godot/VERSION.md`)

## Scope

Bảy mục MVP của brief, mỗi mục một story. Ngoài phạm vi: meta progression, quảng cáo/IAP, nhiều nhân vật/map, online/PvP, thẻ có windup, accessibility, đa ngôn ngữ.

## Ordering

Theo Build order của brief, thứ cốt lõi/rủi ro trước:

1. Băng chuyền + ô giữ + đánh địch giả, chưa có làn (prototype 30 giây: có vui không?)
2. Ghép thẻ + recovery
3. Địch với đòn báo trước
4. 3 làn cố định + thẻ Dash/Sidestep/Knockback
5. Cấu trúc run

**Cổng quyết định:** sau story 003, chơi thử. Nếu vòng chơi cốt lõi không vui thì dừng và quay lại `/brainstorm` trước khi làm 005–007.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Băng chuyền sinh thẻ, trôi và biến mất | Logic | Complete | N/A (minimal) |
| 002 | Ô giữ thẻ và kéo thẻ vào ô | UI | Complete | N/A (minimal) |
| 003 | Dùng thẻ ra sân + recovery, đánh địch giả | Logic | Complete | N/A (minimal) |
| 004 | Ghép 2 thẻ giống nhau | Logic | Ready | N/A (minimal) |
| 005 | Địch báo trước đòn trên 3 làn | Integration | Ready | N/A (minimal) |
| 006 | Bộ 10–12 thẻ (Dash/Sidestep/Knockback) | Logic | Ready | N/A (minimal) |
| 007 | Một run: 3 trận + boss, thắng/thua | Integration | Ready | N/A (minimal) |
