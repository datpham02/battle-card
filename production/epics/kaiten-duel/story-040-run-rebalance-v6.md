# Story 040: Cân bằng lại cả run v6 bằng mô phỏng — 5 tầng + Ấn Đài, bảo vật, vàng, bộ mảnh, Tha/Giết, cấp Kiếp; chỉ chỉnh dữ liệu

> **Epic**: Kaiten Duel (v6)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Config/Data
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md` (v6, mục "Run v6 — mô hình OSFE" toàn bộ; "Player goal & fail state"; "Số khởi điểm"), `design/reference/osfe-reference.md` (§5.4, §5.5 ngân sách đòn trúng, §9.6 Hell Pass), `tools/balance/README.md`
**Requirement**: Story 031–039 mỗi story tự đo phần của mình; chưa ai đo **cả run**: 5 tầng × (3 cột vùng) + trận cuối Ấn Đài, với bảo vật, vàng/cửa hàng/sự kiện, bộ mảnh, Tha/Giết và cấp Kiếp cùng lúc. Các vòng lặp tăng trưởng (bảo vật đổi luật, xóa lá, bỏ hình mảnh) có thể cộng dồn thành chiến lược trội; `deck_sim.gd` hiện chỉ chạy chương 1–3 kiểu cũ với mục tiêu 40–60 / 25–45 / 15–35 %. Story này mở rộng công cụ mô phỏng cho run v6, đặt mục tiêu cả run, và **chỉ chỉnh dữ liệu** (`assets/data/*.json`) tới khi đạt. Mọi con số đều phụ thuộc giả định né của bot (TD-006, `--dodge=0.85` từ thời nối ấn), nên neo lại tỉ lệ né từ lần chơi thử là một phần của story.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM (thời gian chạy mô phỏng dài; kết quả phụ thuộc bot)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Neo lại bot (TD-006)**

- [ ] Từ log của lần chơi thử gần nhất (cổng chơi thử 8 sau Story 031, hoặc buổi chơi thử riêng cho story này): đếm đòn boss có cảnh báo nhắm ô người chơi và số lần người chơi né được → **tỉ lệ né người thật**; đo thêm thời gian kéo-thả một mảnh và thời gian chọn lá trung bình. Ghi cách đếm và cỡ mẫu (≥ 100 đòn boss) vào Completion Notes, cập nhật `DEFAULT_BOT` trong `tools/balance/sim_core.gd` và mục "The TD-006 dodge assumption" của `tools/balance/README.md`.
- [ ] Nếu chưa có dữ liệu chơi thử: chạy mọi bảng ở `--dodge=0.7`, `0.85`, `0.95` và báo độ nhạy; tiêu chí neo ghi **DEFERRED** (không được ghi PASS), TD-006 giữ mở.

**Phần B — Mở rộng công cụ (`tools/balance/`, không phải mã game)**

- [ ] `deck_sim.gd` chạy **run v6**: chọn vùng mỗi tầng theo luật của Story 031 (seeded, chính sách chọn vùng: ngẫu nhiên giữa 2 lựa chọn), 5 tầng + Ấn Đài, máu mang qua tầng và hồi một phần theo dữ liệu. Cờ mới: `--run=v6` (mặc định khi có dữ liệu 031), `--floors=1..5`, `--final=on|off`.
- [ ] Chính sách bot cho phần build, mỗi chính sách là một luật đơn giản ghi trong README: **bảo vật** (lấy bảo vật đầu tiên theo bảng giá trị tĩnh trong sim; cờ `--relic=value|random|none`), **vàng/cửa hàng/sự kiện** (mua xóa lá khi bộ > 10 lá, mua bảo vật nếu đủ vàng, nhận sự kiện khi máu > 50 %; cờ `--shop=on|off`), **bộ mảnh** (bỏ hình 5 ô không vừa sân hay gặp, thêm hình 2–3 ô; `--pieces=on|off`), **Tha/Giết** (`--mercy=kill|spare|mixed`), **cấp Kiếp** (`--kiep=0..10`), **nhân vật** (5 nhân vật nếu Story 037 xong).
- [ ] Bảng ra mới: `RUN | character | policy | kiep | win % | deaths by floor (1..5, final) | hits taken / won run | run minutes (est.) | gold earned / spent | relics / run | deck size | piece set size`; `REGION x FLOOR` (tỉ lệ thắng mỗi vùng ở mỗi tầng); `RELIC LIFT` (tỉ lệ thắng khi bảo vật X có từ tầng ≤ 2 so với không có); `SHOP` (tần suất mua mỗi món); `VERDICT run` theo mục tiêu ở Phần C. Mỗi dòng có header `bot: ... | overrides: ...` như hiện nay.
- [ ] **Thời lượng run ước tính** = tổng giây trận mô phỏng (thời gian sim, đã gồm thời gian chậm 0,2× của menu) + thời gian ngoài trận theo hằng số trong sim (khởi điểm: bản đồ 8 s/nút, chọn thưởng 15 s, cửa hàng 45 s, sự kiện 30 s, trại nghỉ 10 s, chọn Tha/Giết 10 s, intro/kết trận theo `intro_sec`/`end_delay_sec`). Hằng số ngoài trận nằm ở đầu `deck_sim.gd` và in ra header.

**Phần C — Mục tiêu (khởi điểm; người dùng chốt lại sau lần chơi thử)**

- [ ] **Tỉ lệ thắng run ở Kiếp 0**, chính sách build, bot đã neo, Tha/Giết `mixed`: **30–45 %** cho mỗi nhân vật; chênh giữa nhân vật cao nhất và thấp nhất ≤ 20 điểm. Dòng onboarding (save trống, `cleared_bosses` 0): ≥ 20 %.
- [ ] **Độ khó tăng dần theo tầng**: xác suất chết ở tầng *n* khi đã tới tầng *n* không giảm từ tầng 1 tới tầng 5 (cho phép lùi ≤ 3 điểm do nhiễu); chết ở tầng 1 ≤ 10 % số run; thắng Ấn Đài khi đã tới: 50–70 %.
- [ ] **Thời lượng run thắng** (ước tính Phần B): trung vị **40–50 phút**; run thua trung vị ≥ 15 phút (thua không quá sớm).
- [ ] **Số đòn boss trúng mỗi run thắng: 15–30** (ngân sách OSFE của Story 022/023); một đòn boss trung bình 4–15 % máu tối đa.
- [ ] **Vùng**: ở mỗi tầng, tỉ lệ thắng trận của mọi vùng trong ±10 điểm so với trung bình tầng đó (không vùng nào là "vùng tránh" hay "vùng chọn chắc").
- [ ] **Không chiến lược trội** (kiểm Sirlin "chơi để thắng"): chênh tỉ lệ thắng run giữa `--mercy=kill` và `--mercy=spare` ≤ 10 điểm; không bảo vật nào có `RELIC LIFT` > +15 điểm; không món cửa hàng nào được mua < 2 % lượt vào cửa hàng (món "không bao giờ đáng mua"); chính sách `--pieces=on` không hơn `off` quá 10 điểm.
- [ ] **Kinh tế vàng**: vàng tiêu ≥ 70 % vàng kiếm trong run thắng; vàng tồn ở Ấn Đài trung vị ≤ giá một bảo vật cửa hàng (không tích vàng vô dụng).
- [ ] **Cấp Kiếp** (nếu Story 038 xong): tỉ lệ thắng giảm đơn điệu từ Kiếp 0 tới Kiếp 10 (cho phép lùi ≤ 3 điểm); Kiếp 10 ≥ 3 % với bot đã neo; không cấp nào làm tụt > 12 điểm một mình.

**Phần C2 — Bản sắc bộ khởi đầu (yêu cầu của người dùng, 2026-10-26)**

Mỗi nhân vật phải có "sắc màu" riêng ngay từ trận đầu, không chỉ khác tỉ lệ của cùng 4 lá. Luật "không có lớp" vẫn giữ: lá nào cũng nằm trong pool chung, chỉ bộ khởi đầu nghiêng về hướng mà tuyệt kỹ của nhân vật khuếch đại.

- [ ] Bộ khởi đầu (`assets/data/characters.json` `starter_deck`) của mỗi nhân vật có **≥ 3 / 6 lá thuộc hướng của nó**: Kiếm sĩ → lá sát thương cao (Trảm); Pháp sư → lá Đốt (Thiên Hỏa); Sát thủ → Ghim + lá nhỏ (Ảnh Bộ); Thợ săn → vùng + Rạn (Vây Bắt); Giáo sĩ → Hàn (Thánh Ấn). `kiem_khi` (lá nền) tối đa 2 lá mỗi bộ.
- [ ] Hai nhân vật bất kỳ chung **≤ 3 lá** trong bộ khởi đầu (đếm cả lá trùng), để không bộ nào là bản sao đổi tỉ lệ của bộ khác. Hiện tại Kiếm sĩ / Pháp sư / Sát thủ dựng từ cùng 4 lá (Kiếm khí, Chấn phong, Hỏa trận, Băng phong); Kiếm sĩ không có lá sát thương cao nào dù Trảm khuếch đại hướng đó.
- [ ] Kiểm chứng: test dữ liệu cho hai luật trên; mô phỏng Phần E chạy sau khi đổi bộ, và mục tiêu tỉ lệ thắng của Phần C áp dụng cho bộ mới (đổi bộ là chỉnh dữ liệu, theo Phần D).

**Phần D — Chỉ chỉnh dữ liệu**

- [ ] Mọi thay đổi để đạt Phần C nằm trong `assets/data/*.json` (máu, nhịp bước, giáp, cỡ đòn của trận; hệ số theo tầng của 031; hồi máu khi sang tầng; giá và lượng vàng; trọng số thưởng/bảo vật/hình mảnh; tham số Kiếp). Không đổi mã game; nếu một mục tiêu chỉ đạt được bằng mã thì ghi TD mới và để mục đó DEFERRED.
- [ ] Mỗi thay đổi một dòng trong Completion Notes: khóa, giá trị cũ → mới, lý do (bảng nào lệch). Số mới vẫn là "khởi điểm" cho tới khi người dùng chơi thử; `design/game-brief.md` mục "Số khởi điểm" cần cập nhật bởi người dùng hoặc story sau (story này không sửa brief).

**Phần E — Kiểm chứng**

- [ ] **Mô phỏng** cuối: 70 seed × mỗi nhân vật × chính sách build, Kiếp 0, `--mercy=mixed`, cộng các lượt so sánh ở Phần C (mercy kill/spare, pieces on/off, relic none, Kiếp 0–10 với 30 seed); kèm smoke 5 seed để đo thời gian chạy và ghi vào README. Bảng tóm tắt vào Completion Notes; đầy đủ vào `production/qa/evidence/run-v6-balance/simulation-run-v6.md` và `simulation-run-v6-raw.txt`, có header bot và overrides.
- [ ] Smoke sau khi chỉnh dữ liệu: toàn bộ suite headless và windowed chạy, FAILS=0 (test có ngưỡng số cũ được cập nhật theo dữ liệu mới, ghi tên test vào Completion Notes); `main.tscn` chạy cửa sổ `--quit-after 300`, 0 dòng lỗi.
- [ ] Ảnh trong `production/qa/evidence/run-v6-balance/` (dữ liệu đổi thì thứ người chơi thấy đổi): bản đồ thế giới tầng 1 và tầng 5 với số máu địch đã chỉnh; một boss vùng ở tầng 5; trận cuối Ấn Đài; màn kết thúc run thắng có thời lượng; cửa hàng với giá mới.
- [ ] Không hằng số gameplay mới trong mã game.

---

## Implementation Notes

- Run đầy đủ có thể kéo dài nhiều giờ (README: ~1,6 s cho một run một chương; run v6 ~ 6 lần): chia lô theo nhân vật, chạy có timeout, gom kết quả; dùng `hit_probe.gd --modes=bot` để soi một vùng/tầng lệch trước khi chạy lại cả run.
- Thứ tự chỉnh khuyến nghị (từ gốc tới ngọn): hệ số theo tầng (độ dốc) → máu/hồi máu sang tầng (ngân sách đòn) → kinh tế vàng → bảo vật/món cửa hàng trội → vùng lệch → Kiếp.
- Đổi seed tập giữa lượt chỉnh và lượt chốt để tránh khớp quá mức với một tập seed.

---

## Out of Scope

- Thay đổi luật hay mã gameplay (story riêng nếu mô phỏng chỉ ra cần). Cân bằng theo người thật ngoài phần neo bot. Thử thách ngày. Nội dung mới. Sửa `design/game-brief.md`.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Config/Data
**Required evidence**:
- Smoke check pass; bảng mô phỏng và retained screenshots trong `production/qa/evidence/run-v6-balance/`.

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 031–039 (bản đồ thế giới, bảo vật, vàng/cửa hàng/sự kiện, bộ mảnh, Tha/Giết và boss cuối, hai đợt vùng, mở khóa và nhân vật, cấp Kiếp); dữ liệu chơi thử cho Phần A (TD-006)
- Unlocks: lên Android, cổng chơi thử run v6 đầy đủ
