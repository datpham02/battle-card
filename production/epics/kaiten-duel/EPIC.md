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

## Pivot v4 — 2026-10-22 (sau Story 016, cả 16 story xong)

Người dùng quyết định: **bỏ chủ đề bếp sushi, dựng thế giới fantasy** (ấn, trận pháp, phép; chương là vùng đất) và **thêm lớp roguelike**: 3–5 nhân vật theo lớp với bộ bài khởi đầu, menu phép rút 4 lá từ bộ, chọn 1 trong 3 lá sau mỗi trận, máu là tài nguyên cả run, **chết là hết run** (hồi sinh là item thêm sau). Luật "chơi lại trận đã thua" của Story 015 bị thay ở 019. Cơ chế lõi v3 không đổi. Brief v4 là bản ghi; tên làm việc "Ấn Kiếm", repo giữ tên.

**Bổ sung 2026-10-24 (sau 021):** người dùng muốn nội dung dày hơn trước khi chơi thử; tài liệu tham chiếu `design/reference/osfe-reference.md` (One Step From Eden, đọc bằng REA + ILSpy) đưa ra khung bản đồ 7 cột, token bỏ lá, thưởng theo loại nút, độ hiếm trôi theo may mắn, giáp phẳng, địch phá luật → Story 022 (bản đồ + kinh tế) rồi 023 (nội dung chương 2–3).

**Bổ sung 2026-10-22 (sau khi đóng 019):** người dùng muốn **chọn lá phải đổi kết quả trận** và **bỏ khái niệm "lớp"**. Chốt: nhân vật là cá nhân với bộ khởi đầu, nội tại và một **tuyệt kỹ** chủ động mạnh lên theo bộ bài (Kiếm sĩ Trảm, Pháp sư Thiên Hỏa, Sát thủ Ảnh Bộ); không lá nào gắn nhân vật, thưởng không nghiêng trọng số; sức nặng của bộ đến từ sát thương theo lá, nâng cấp khi nhặt trùng, bỏ lá và hai từ khóa Ghim/Đốt dùng chung → Story 020 (bộ bài) rồi 021 (tuyệt kỹ), đo bằng mô phỏng ba chính sách chọn thưởng (chênh ≥ 25 điểm phần trăm).

## Pivot v5 — 2026-10-24 (sau cổng chơi thử 6)

Chơi thử run đủ nội dung: người dùng thấy **đánh trúng boss rất khó**, nối ấn "đòi nhớ vị trí và quy ước", phải nhặt 3–4 ấn mới có một vùng. Đo bằng logic game thật (`hit_probe.gd`, 40 đòn mỗi ô, 11 địch chương 1): quái thường nối đại trúng 25–60 %, canh lúc boss vừa bước trúng gần 100 %; miniboss/boss nối đại 0–30 %, chỉ đòn 1 ô ổn định; ô giữa sân chỉ trúng được bằng trận pháp ≥ 3 ô. Người dùng quyết định **bỏ nối ấn, thay bằng mảnh ấn**: mỗi ấn rơi là một mảnh hình sẵn 1–5 ô (bộ hình chọn lọc, rút theo trọng số chương, xoay được), chọn mảnh → đặt lên chỗ bất kỳ vừa khít trên đất địch (Tập trung dừng trận như cũ) → chọn lá; mỗi đòn một mảnh. Kèm theo: báo trúng xanh/đỏ, boss đứng yên khi niệm, vòng hồi bước boss hiện khóa (vòng đã có sẵn), và **Kết giới / Trận gai** để đấu trí bằng vùng → Story 024–027. Brief v5 là bản ghi.

## Scope

Sáu mục MVP của brief v3. Ngoài phạm vi: Parry/Posture, Guard/giáp, thẻ hình dạng tầm, băng chuyền, quầy chung, ghép thẻ, AI học máy, meta progression (ngoại lệ từ 015: lưu tầng đã mở), quảng cáo/IAP, nhiều nhân vật/map, online/PvP, accessibility, đa ngôn ngữ.

## Ordering (build order của brief v3)

1. Lưới + khung đòn (006)
2. Nút di chuyển + điểm rơi, gỡ băng chuyền và thẻ cũ (007)
3. Hệ cắt của người chơi + menu kỹ năng (008)
4. Boss đi nhặt và cắt, ngắt đòn (009) → **Cổng quyết định 3: trận đấu đầu tiên có thật — chơi thử trước khi làm 010–011**
5. Bảng cân bằng + Đốt/Ghim + boss học (010)
6. Cấu trúc run (011)
7. Tập trung (012), hồ sơ boss + cooldown theo sân (013), khung boss: sân + trait (014) → **Cổng quyết định 4**
8. Chương và tầng + lưu tiến độ (015)
9. Vỏ game: title, tạm dừng, back, debug (016)
10. Lá bài và bộ bài + đổi vỏ fantasy (017)
11. Nhân vật theo lớp (018)
12. Run roguelike (019) → **Cổng quyết định 5: run đầu tiên có thật**
13. Bộ bài có sức nặng (020), tuyệt kỹ nhân vật (021) — mô phỏng: chọn lá nhân đôi tỉ lệ thắng nhưng dưới ngưỡng 25 điểm (TD-001, TD-004); người dùng hoãn chơi thử vì nội dung mỏng
14. Bản đồ chương + kinh tế thưởng (022), nội dung chương 2–3 + địch phá luật (023), theo `design/reference/osfe-reference.md` → **Cổng quyết định 6: run đầu tiên đủ nội dung**
15. Mảnh ấn (v5): mảnh phía người chơi (024) → **Cổng quyết định 7: chơi lại với mảnh** (2026-10-25: người dùng muốn dùng nhiều mảnh, ghép mảnh, ghép thành hình sân → 028, 029); ghép mảnh + hình chủ đạo (028); trận đồ thay thanh nạp (029); boss dùng và ghép mảnh + cửa sổ phản công (025, tạm dừng tới khi 028–029 xong); gỡ nối ấn + đo lại cân bằng (026); Kết giới / Trận gai (027)
16. Cửa hàng/pact, lên Android, hình và âm

**Cổng quyết định 1 (sau 003, v1):** "tạm ổn", thiếu áp lực → đi tiếp.
**Cổng quyết định 2 (sau 005, v1):** băng chuyền khó thao tác, địch theo giờ nhàm, 3 làn basic → pivot v2.
**Cổng quyết định 3 (sau 009, v3, 2026-10-20):** lõi chơi "khá thú vị"; quá khó (boss ép); vừa di chuyển vừa nối điểm làm hai ngón cái quá tải. Quyết định: **hoàn thiện trước, cân bằng sau** → làm 010–011 với số hiện tại, rồi một đợt cân bằng riêng (nhịp boss trận 1, ý tưởng "Tập trung" làm chậm 0,5× khi đang chọn điểm, xem backlog).
**Cổng quyết định 4 (sau 014, 2026-10-20):** sau Tập trung (012), hồ sơ boss + cooldown theo sân (013) và sân/trait theo trận (014), người dùng chơi thử: "ổn và cân bằng hơn rồi". Đợt cân bằng riêng **không cần nữa**; chuyển sang phase vỏ game: chương/tầng + lưu tiến độ (015), title/tạm dừng (016), rồi nội dung chương (017) và lên máy thật (018).
**Cổng quyết định 6 (sau 023, 2026-10-24):** run đủ ba chương chơi được, nhưng đánh trúng quá khó và nối ấn khó học → pivot v5 (mảnh ấn, Story 024–027).

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
| 013 | Hồ sơ boss theo trận (di chuyển, đường thoát, đòn nối, tốc vung) + cooldown bước theo sân | Integration | Complete | N/A (minimal) |
| 014 | Khung boss: sân riêng theo trận + đặc điểm (trait) cắm được, 2 trait mẫu | Integration | Complete | N/A (minimal) |
| 015 | Chương và tầng: một run là một tầng, sân cố định/pool theo tầng, lưu tầng đã mở, màn chọn tầng và qua tầng | Integration | Complete | N/A (minimal) |
| 016 | Vỏ game: màn title, tạm dừng, nút back, tắt dòng debug | UI | Complete | N/A (minimal) |
| 017 | Lá bài và bộ bài: cards.json, Deck, menu rút 4 lá; đổi vỏ fantasy (dữ liệu, chuỗi) | Integration | Complete | N/A (minimal) |
| 018 | Nhân vật theo lớp: characters.json, nội tại cắm được, bộ khởi đầu, màn chọn nhân vật | Integration | Complete | N/A (minimal) |
| 019 | Run roguelike: thưởng 1 trong 3 lá, máu cả run, chết là hết, chọn chương, save run | Integration | Complete | N/A (minimal) |
| 020 | Bộ bài có sức nặng: sát thương theo lá, nâng cấp khi nhặt trùng, bỏ lá, từ khóa Ghim/Đốt, bỏ khái niệm lớp | Logic | Complete | N/A (minimal) |
| 021 | Tuyệt kỹ nhân vật: thanh nạp, nút riêng, Trảm / Thiên Hỏa / Ảnh Bộ khuếch đại bộ bài | Integration | Complete | N/A (minimal) |
| 022 | Bản đồ chương và kinh tế thưởng: 7 cột khung cố định + nhánh 2–3, token bỏ lá, thưởng theo loại nút, độ hiếm trôi theo may mắn, trại nghỉ, máu ×3 | Integration | Complete | N/A (minimal) |
| 023 | Nội dung chương 2–3: boss/trait mới, địch phá luật (Bóng Ma, Kẻ Phản Ứng, Pháo Ngòi), lá sử thi có điều kiện, Rạn/Hàn, pool 24 | Integration | Complete | N/A (minimal) |
| 024 | Mảnh ấn phía người chơi: mảnh rơi, túi 3, đặt và xoay lên đất địch, báo trúng, hạ min_cells | Integration | Complete | N/A (minimal) |
| 025 | Boss dùng mảnh ấn: chấm điểm vị trí và hướng xoay, boss đứng yên khi niệm, vòng hồi bước hiện khóa | Integration | Complete | N/A (minimal) |
| 026 | Gỡ hệ nối ấn, chuyển test và mô phỏng sang mảnh, đo lại cân bằng ba chương | Integration | Complete | N/A (minimal) |
| 027 | Kết giới và Trận gai: vùng chặn và vùng thu phí đặt bằng mảnh, cho cả người chơi và boss | Integration | Complete | N/A (minimal) |
| 028 | Ghép mảnh trên sân và hình chủ đạo: tối đa 2 mảnh một đòn, thưởng ×1,5 + hiệu ứng khi ghép đúng hình của trận | Integration | Complete | N/A (minimal) |
| 029 | Trận đồ: ô sáng khi được phủ, phai dần, sáng đủ cùng lúc thì tuyệt kỹ sẵn sàng (thay thanh nạp 18 ô) | Integration | Complete | N/A (minimal) |
| 030 | Làm lại Thiên Hỏa và Ảnh Bộ: Thiên Hỏa đốt cả trận đồ, Ảnh Bộ nhân đôi mọi đòn nhỏ, cân bằng giá trị mỗi phút ≤ ~2 : 1 | Integration | Complete | N/A (minimal) |
