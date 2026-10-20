# Game Brief: Kaiten Duel

> **v3 — 2026-10-18.** Pivot lần ba, trước khi làm Story 007. Thẻ đánh theo hình dạng tầm, Guard và Parry/Posture bị thay bằng **hệ cắt (Pattern Draw)**: thứ rơi xuống sân là **điểm cắt** mang tọa độ chu vi bàn đối thủ; nối điểm thành đường dao chém thẳng xuống bàn boss; càng phủ nhiều ô đòn càng nặng nhưng càng lâu ra. Lịch sử: v1 băng chuyền (`2f4e31b`), v2 lưới 3×3 + quầy chung (`be73d17`), v2.1 điểm rơi + nút di chuyển (chưa commit, gộp vào v3).

**One-sentence pitch:** Đấu thời gian thực trên hai lưới 3×3 đối mặt, nơi bạn chạy nhặt những điểm cắt rơi xuống sân mình rồi nối chúng thành đường dao chém thẳng xuống bàn của boss; hình càng phủ nhiều ô đòn càng nặng nhưng càng lâu ra, và boss cũng làm y hệt với bạn.

## Core loop

### Sân và di chuyển
- Hai lưới 3×3 đối mặt (bàn 6×3). Mỗi bên chỉ đi trong nửa sân của mình. **Kích thước và hình lưới là dữ liệu** (`side_cols`, `side_rows`, `missing_cells`): chữ nhật hoặc hình ghép từ ô vuông có ô khuyết (chữ thập, kim cương, có lỗ); hai bên luôn cùng hình, đối xứng qua vạch giữa; lục giác/tròn không làm. Nhãn chu vi sinh theo lưới (A/C có `side_cols` điểm, B/D có `side_rows` điểm). Mọi số cân bằng dưới đây là cho 3×3; lưới khác phải chỉnh lại.
- **Nút di chuyển 4 hướng** ở góc dưới trái, mỗi lần bấm đi **một ô**, cooldown bước **0,45 s**. Bấm trong lúc cooldown thì **mất, không nhớ lệnh**. Thanh cooldown hiện dưới chân nhân vật.
- Bước lên ô có điểm là nhặt, nên mỗi lần đi nhặt là tự khóa mình 0,45 s ở ô đó. Đây là rủi ro có chủ ý.

### Điểm cắt rơi
- **Điểm** rơi xuống **ô trống ngẫu nhiên bên nửa sân mình**, không rơi vào ô đang đứng. Mỗi điểm mang một **nhãn tọa độ trên chu vi ô vuông 3×3 của đối thủ**: cạnh **A** trên, **B** phải, **C** dưới, **D** trái; số **1–3**. A và C đánh số theo cột (A1 trên cột 1, C1 dưới cột 1); B và D đánh số theo hàng (D2 trái hàng 2, B2 phải hàng 2). Vì thế A1→C1 là cả cột 1, D2→B2 là cả hàng 2.
- Điểm trên sân có **độ tươi 7 s**, đổi màu khi sắp ôi, hết giờ thì biến mất. **Trong tay không ôi.** Tay tối đa **4 điểm**; tay đầy thì điểm nằm lại trên ô.
- **Luật rơi** (ba lớp, lớp 1–2 là MVP):
  1. **Túi xáo**: mỗi bên một túi đủ 12 nhãn; mỗi lần rơi rút một nhãn, hết túi xáo lại. Không nhãn nào vắng quá 12 lần rơi; người chơi học được "D2 chưa ra thì sắp ra".
  2. **Nhịp gắn với trận**: nhịp nền **1,8 s** một điểm, tối đa **4 điểm** trên nửa sân; điểm **được phép rơi vào ô đang nằm trong đường dao** của đối thủ (nhặt hay không là quyết định liều); **bù khi đói**: tay trống quá **4 s** thì nhịp nhân **0,6** đến khi nhặt được.
  3. **Thủ đoạn của boss** (sau MVP, xem backlog): ôi nhanh hơn khi nổi giận, ném điểm hỏng, hút điểm.
- Boss dùng **đúng túi và đúng nhịp** như bạn, trên nửa sân của nó.
- Không hiện trước nhãn sắp rơi; không rơi theo kịch bản cố định.

### Cắt
- **1 điểm**: chọn 1 điểm rồi bấm **Chốt** là **chém ngay, không menu**: đường thẳng từ điểm đó sang điểm đối diện (A1→C1, D2→B2), phủ 3 ô. Đây là đòn nhanh của game.
- **2–4 điểm**: chạm lần lượt các điểm trong tay (thứ tự chạm là thứ tự nối) rồi bấm **Chốt**; 2 điểm là đoạn thẳng, 3–4 điểm là đa giác, vẽ **trực tiếp trên bàn đối thủ**. **Tập ô phủ** = ô mà cạnh đi qua + ô nằm trong lòng đa giác. Bản xem trước hiện tập ô sáng lên và **số ô đang phủ** theo thời gian thực, trước khi chốt. Chốt là tốn điểm, không hủy.
- **Sát thương = sát thương cơ bản × số ô phủ**, trúng nếu ô đối thủ nằm trong tập lúc chém. Đường cắt nằm trên bàn đối thủ, **không phụ thuộc mình đứng đâu**.
- **Khoảng vung = 0,2 s + 0,25 s × số ô** (3 ô ≈ 0,95 s, 9 ô ≈ 2,45 s). Trong khoảng vung tập ô sáng **đỏ trên bàn đối thủ**, đếm ngược rồi mới chém. **Đang vung vẫn di chuyển được.** Mỗi bên chỉ một đòn đang vung tại một thời điểm.
- Không có Guard, không có giáp, không có Parry. **Phòng thủ = bước ra khỏi tập ô, hoặc đua đồng hồ** (xem Ngắt đòn).

### Tập trung (dừng khi nối điểm, từ phản hồi chơi thử, 2026-10-20)
- Khi Tập trung sẵn sàng, chọn điểm đầu tiên trong tay **dừng hẳn** trận (boss, đồng hồ vung, điểm rơi, mọi cooldown). Tối đa **4 s thật** (thanh đếm cạnh nút Chốt); hết giờ trận chạy lại và giữ nguyên điểm đã chọn; bấm Chốt hoặc bỏ chọn hết thì kết thúc sớm. Sau đó **cooldown 8 s**, trong lúc đó chọn điểm không dừng trận nên đòn 1 điểm vẫn nhanh. **Không di chuyển được khi đang dừng.** Boss không có Tập trung. Số trong `skills.json` (`focus_time_scale` 0 = dừng hẳn, > 0 = chậm).

### Menu kỹ năng
- Sau khi chốt 2–4 điểm, menu kỹ năng hiện và game **chậm còn 0,2×** (`skill_menu_time_scale`; đặt 0 là dừng hẳn kiểu Mega Man Battle Network). Có **3 s thật** để chọn; hết giờ **tự chọn Chém**. Boss cũng chọn trong khoảng chậm đó, không được nghĩ lâu hơn bạn.
- Kỹ năng là **biến thể trên cùng tập ô**; **điều kiện mở là số ô phủ**; kỹ năng chưa đủ ô vẫn hiện nhưng khóa và ghi "cần N ô". Sau khi chọn, khoảng vung vẫn chạy như thường.

| Kỹ năng | Cần | Cooldown | Hiệu ứng |
|---|---|---|---|
| Chém | bất kỳ | không | sát thương × số ô |
| Đẩy | ≥ 3 ô | 6 s | trúng thì đẩy đối thủ lùi 1 ô theo hướng cắt (nếu có chỗ) + sát thương nhẹ |
| Đốt | ≥ 5 ô | 8 s | tập ô cháy 3 s, đứng trong ăn sát thương dần; chặn đường |
| Ghim | ≥ 7 ô | 10 s | trúng thì đối thủ đứng yên 1,2 s |

- 1 điểm luôn là Chém ngay dù phủ 3 ô đủ điều kiện Đẩy; muốn Đẩy thì nối 2 điểm. Cờ `single_point_opens_menu` trong dữ liệu để đổi nếu chơi thử thấy thiếu.

### Ngắt đòn (thay Parry)
- Cả hai bên vung theo **cùng công thức**. **Đòn nào chạm ô đối thủ trước thì hủy đòn đối thủ đang vung**; điểm đã dùng của bên bị hủy mất luôn. Đòn to vung lâu nên dễ bị ngắt; đòn 1 điểm nhanh nhưng yếu. Người chơi chọn giữa "đánh to" và "đánh kịp".
- Phản xạ đúng khi thấy boss vung: đã có đòn đang đếm và sắp xong thì đứng yên chịu đua; chưa có gì thì bước ra. Ngắt đòn là phần thưởng cho người ra đòn sớm, không phải nút phản xạ.
- Một bên chết thì mọi đòn đang đếm bị hủy.

### Boss
- Boss **đi nhặt** điểm bên nửa sân nó (cooldown bước **0,55 s** trận đầu, giảm dần các trận sau) và **cắt bằng cùng hệ**: brain là bảng trọng số trong JSON (ô người chơi có nằm trong tập không, số ô so với khoảng vung và đồng hồ đang đếm của người chơi, có nên đi nhặt điểm đang nằm dưới đường dao, kỹ năng nào đang sẵn). Không học máy; mọi thứ đọc được bằng mắt.
- Hạ boss → trận kế, lặp lại.

## Player goal & fail state — what "working" looks like
- Vượt một run gồm 3 trận + 1 boss bằng cách nhặt đúng điểm đúng lúc, nối hình đủ lớn để mở kỹ năng, và thắng những cuộc đua đồng hồ.
- Thua khi HP về 0. Một run cảm giác hoàn chỉnh trong khoảng 8–12 phút.

## MVP — what must exist to be the game
1. Hai lưới 3×3 đối mặt với khung đòn/recovery đọc từ dữ liệu (Story 006, xong; Step, Guard và thẻ hình dạng tầm của nó bị gỡ ở 007–008).
2. **Nút di chuyển 4 hướng** (một ô, cooldown, không nhớ lệnh) và **điểm cắt rơi** theo túi xáo + nhịp + độ tươi; nhặt bằng bước lên; tay 4 điểm ở góc dưới phải (007).
3. **Hệ cắt của người chơi**: 1 điểm chém ngay; 2–4 điểm vẽ đoạn/đa giác với xem trước và số ô; sát thương và khoảng vung theo số ô; menu kỹ năng chậm 0,2× với Chém và Đẩy (008).
4. **Boss đi nhặt và cắt** bằng brain trọng số; vung đỏ trên bàn bạn; **ngắt đòn hai chiều** (009) → cổng chơi thử 3.
5. **Bảng cân bằng cắt** + Đốt, Ghim + boss học bằng bộ đếm trong trận (010).
6. Một run: 3 trận + boss, màn thắng/thua, chơi lại không cần thoát (011).

## Số khởi điểm (tất cả trong `assets/data/`, chỉnh sau cổng chơi thử 3)

| Tham số | Khởi điểm | File |
|---|---|---|
| Cooldown bước người chơi / boss trận đầu | 0,45 s / 0,55 s | `combat.json`, `boss_brain.json` |
| Nhịp rơi nền, tối đa trên sân, độ tươi | 1,8 s, 4, 7 s | `field_drops.json` |
| Ngưỡng đói, hệ số bù | 4 s, ×0,6 | `field_drops.json` |
| Tay tối đa (số ô tay) | 4 | `hold_slots.json` |
| Vung cơ bản, vung mỗi ô | 0,2 s, 0,25 s | `cuts.json` |
| Sát thương cơ bản mỗi ô | 6 (HP 100) | `cuts.json` |
| Time scale menu, thời gian chọn | 0,2, 3 s | `skills.json` |
| Ngưỡng ô và cooldown kỹ năng | bảng trên | `skills.json` |

## Out of scope — not building this
- **Đã loại ở v3**: Parry/Counter/Posture/Focus (thay bằng ngắt đòn), Guard và giáp, thẻ đánh theo hình dạng tầm (Strike/Cannon/Wide Slash), thẻ Step/Dash (di chuyển là nút).
- Băng chuyền, quầy chung, Custom Gauge dừng trận; di chuyển chéo hoặc nhiều ô một lần.
- Hiện trước nhãn sắp rơi; rơi theo kịch bản cố định mỗi trận (giữ trong backlog làm phương án lùi).
- Ghép thẻ; AI học máy; meta progression (hướng "thực đơn"), quảng cáo/IAP/gacha.
- Nhiều nhân vật, nhiều map, cốt truyện; online/PvP/xếp hạng; đa ngôn ngữ, accessibility — để sau.

## Build order
1. Lưới + khung đòn (006, xong).
2. Nút di chuyển + điểm rơi, gỡ băng chuyền/thẻ cũ (007).
3. Hệ cắt của người chơi + menu kỹ năng (008).
4. Boss đi nhặt và cắt, ngắt đòn (009) → **cổng chơi thử 3: trận đấu đầu tiên có thật**.
5. Bảng cân bằng + Đốt/Ghim + boss học (010).
6. Cấu trúc run (011).

---
**Who it's for / what they feel:** Người chơi mobile thích Mega Man Battle Network và game giải đố nối điểm, chơi ngang hai tay (trái di chuyển, phải chọn điểm), phiên 10 phút; cảm giác "mình gom đủ điểm, vẽ một nhát to và nó ra kịp".

**Art & audio direction:** 2D cartoon tươi sáng; hai thớt gỗ 3×3 đối mặt là đấu trường; điểm cắt là dấu khắc trên thớt; đường dao vẽ sáng rồi chém xuống. SFX dao giòn, nhạc jazz/lo-fi vui tai.

**Reference game:** Mega Man Battle Network — giữ ~10%: hai lưới 3×3, di chuyển một ô, và màn chọn làm chậm thời gian; **không** giữ chip folder hay Custom Gauge theo chu kỳ. Nhãn tọa độ chu vi, nối điểm thành hình và sát thương theo số ô phủ là phần riêng của game này.
