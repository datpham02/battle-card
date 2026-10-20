# Epic: Kaiten Duel

> **Source**: `design/game-brief.md` (minimal tier — no GDD/ADR; epic synthesized from the brief)
> **Goal (v3)**: Đấu thời gian thực trên hai lưới 3×3 đối mặt; bạn và boss chạy nhặt điểm cắt rơi xuống sân mình, nối thành đường dao chém xuống bàn đối thủ; càng phủ nhiều ô đòn càng nặng nhưng càng lâu ra; ai chém trúng trước thì ngắt đòn của người kia.
> **Engine**: Godot 4.6 (GDScript), landscape 1280x720 | **Risk**: HIGH (per `docs/engine-reference/godot/VERSION.md`)

## Pivot v2 — 2026-10-18

Sau cổng chơi thử 2 (bản v1 có băng chuyền + địch đánh theo mẫu cố định), người dùng quyết định:
- **bỏ băng chuyền**: thao tác với vật thể chuyển động làm độ khó xử lý quá cao;
- **bỏ đòn tự động theo giờ**: chu kỳ cố định nhàm → boss cũng chơi bằng luật trọng số, khoảng vung là báo đòn;
- **3 làn → hai lưới 3×3** kiểu Mega Man Battle Network.

Story 001–003 và 005 (v1) giữ trạng thái Complete làm lịch sử; code của chúng là nền để làm lại. Story 004/006/007 (v1) bị xóa khỏi epic (số 004 không dùng lại).

**v2.1 (cùng ngày, sau khi Story 006 xong):** quầy sushi chung → thẻ rơi xuống ô của mỗi bên; thẻ Step → nút di chuyển 4 hướng một ô mỗi lần.

## Pivot v3 — 2026-10-18 (trước Story 007)

Thẻ đánh theo hình dạng tầm, Guard và Parry/Posture bị thay bằng **hệ cắt**:
- thứ rơi là **điểm cắt** mang nhãn chu vi bàn đối thủ (A/B/C/D × 1–3); 1 điểm chém ngay sang điểm đối diện; 2–4 điểm vẽ đoạn/đa giác trên bàn đối thủ;
- **sát thương và khoảng vung theo số ô phủ**; số ô cũng mở **kỹ năng** (Chém/Đẩy/Đốt/Ghim) trong menu làm chậm thời gian;
- **ngắt đòn hai chiều** thay Parry: đòn nào chạm ô đối thủ trước thì hủy đòn đối thủ đang vung;
- rơi điểm theo **túi xáo 12 nhãn** + nhịp gắn với trận (bù khi đói, rơi được dưới đường dao);
- cooldown bước 0,45 s, không nhớ lệnh.

Story 007 viết lại; 008 (boss chơi thẻ) → **hệ cắt của người chơi**; 009 (Parry) → **boss cắt + ngắt đòn**; 010/011 sửa theo. Story 006 giữ In Progress: lưới và khung đòn là nền; Step/Guard/shapes của nó bị gỡ ở 007–008.

## Scope

Sáu mục MVP của brief v3. Ngoài phạm vi: Parry/Posture, Guard/giáp, thẻ hình dạng tầm, băng chuyền, quầy chung, ghép thẻ, AI học máy, meta progression, quảng cáo/IAP, nhiều nhân vật/map, online/PvP, accessibility, đa ngôn ngữ.

## Ordering (build order của brief v3)

1. Lưới + khung đòn (006)
2. Nút di chuyển + điểm rơi, gỡ băng chuyền và thẻ cũ (007)
3. Hệ cắt của người chơi + menu kỹ năng (008)
4. Boss đi nhặt và cắt, ngắt đòn (009) → **Cổng quyết định 3: trận đấu đầu tiên có thật — chơi thử trước khi làm 010–011**
5. Bảng cân bằng + Đốt/Ghim + boss học (010)
6. Cấu trúc run (011)

**Cổng quyết định 1 (sau 003, v1):** "tạm ổn", thiếu áp lực → đi tiếp.
**Cổng quyết định 2 (sau 005, v1):** băng chuyền khó thao tác, địch theo giờ nhàm, 3 làn basic → pivot v2.
**Cổng quyết định 3 (sau 009, v3, 2026-10-20):** lõi chơi "khá thú vị"; quá khó (boss ép); vừa di chuyển vừa nối điểm làm hai ngón cái quá tải. Quyết định: **hoàn thiện trước, cân bằng sau** → làm 010–011 với số hiện tại, rồi một đợt cân bằng riêng (nhịp boss trận 1, ý tưởng "Tập trung" làm chậm 0,5× khi đang chọn điểm, xem backlog).

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Băng chuyền sinh thẻ, trôi và biến mất (v1) | Logic | Complete | N/A (minimal) |
| 002 | Ô giữ thẻ và kéo thẻ vào ô (v1) | UI | Complete | N/A (minimal) |
| 003 | Dùng thẻ ra sân + recovery, đánh địch giả (v1) | Logic | Complete | N/A (minimal) |
| 005 | Địch báo trước đòn trên 3 làn (v1) | Integration | Complete | N/A (minimal) |
| 006 | Hai lưới 3×3, Step, đánh theo hình dạng tầm (refit; nền cho v3) | Logic | Complete | N/A (minimal) |
| 007 | Nút di chuyển 4 hướng + điểm cắt rơi (gỡ băng chuyền, thẻ cũ) | UI | Complete | N/A (minimal) |
| 008 | Hệ cắt của người chơi: 1 điểm, 2–4 điểm, menu kỹ năng | Logic | Complete | N/A (minimal) |
| 009 | Boss đi nhặt và cắt, brain trọng số, ngắt đòn hai chiều | Integration | Complete | N/A (minimal) |
| 010 | Bảng cân bằng cắt + Đốt, Ghim + boss học bằng bộ đếm | Logic | Complete | N/A (minimal) |
| 011 | Run 3 trận + boss, thắng/thua, chơi lại | Integration | Complete | N/A (minimal) |
| 012 | Tập trung: dừng hẳn trận khi nối điểm (giới hạn + cooldown) | Integration | Complete | N/A (minimal) |
| 013 | Hồ sơ boss theo trận (di chuyển, đường thoát, đòn nối, tốc vung) + cooldown bước theo sân | Integration | Ready | N/A (minimal) |
