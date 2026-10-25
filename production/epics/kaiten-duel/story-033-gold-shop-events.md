# Story 033: Vàng, cửa hàng và sự kiện — tiền rơi sau trận, nút cửa hàng, 8 sự kiện có rủi ro, lá nguyền

> **Epic**: Kaiten Duel (v6)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md` (v6, mục "Run v6 — mô hình OSFE" → "Xây build trong run": vàng, cửa hàng, sự kiện), `design/reference/osfe-reference.md` (§9.2 Cửa hàng `ShopCtrl`: giá theo độ hiếm 35/20, bỏ lá 65 tối đa 1/shop, hiến máu; tiền rơi lính 2–4, elite 10, boss 20–30; Pact thử thách/thưởng)
**Requirement**: v6 cần một tài nguyên thứ hai để nút trên bản đồ khác nhau về giá trị (nguy hiểm đáng đi vì nhiều vàng hơn) và một nơi tiêu nó. Sự kiện đưa lựa chọn rủi ro (đổi máu, nhận lá nguyền, cược) để mỗi run có câu chuyện riêng. Lá nguyền là khái niệm mới: lá chiếm chỗ trong menu phép.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH (hai loại nút mới trong luồng `GameFlow`, trận thêm từ sự kiện, lá nguyền trong menu phép, save run)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Vàng**

- [ ] `RunSession.gold: int` (khởi đầu `starting_gold`, khởi điểm 20), API `add_gold(n)`, `spend_gold(n) -> bool` (từ chối khi thiếu, không bao giờ âm). Lưu khóa `gold` trong save run; thiếu khóa = `starting_gold`.
- [ ] Vàng rơi khi **thắng** một nút trận, theo loại nút, số trong `assets/data/economy.json` (file mới; mô tả trong `schema.md`): `battle` 12, `danger` 22, `miniboss` 25 (nếu Story 031 còn giữ loại này), `boss` (boss vùng) 35, `treasure` 15 (không đánh), mỗi giá trị ±20 % seeded theo run. Hệ số theo tầng `gold_floor_mult` (khởi điểm [1,0; 1,1; 1,2; 1,3; 1,4]). Màn thưởng hiện "+N vàng" trước phần chọn lá.
- [ ] Ngân sách mục tiêu (khởi điểm, kiểm bằng mô phỏng): một run trung bình kiếm 350–450 vàng, đủ cho khoảng 4–6 món ở cửa hàng; trung vị vàng thừa khi run kết thúc (thắng) < 100.
- [ ] HUD bản đồ và màn thưởng hiện số vàng (biểu tượng vẽ bằng code + số). Trong trận không hiện.

**Phần B — Nút cửa hàng (`shop`)**

- [ ] Loại nút `shop` thêm vào generator của Story 031 (cạnh `ChapterMapGen.KINDS`), trọng số xuất hiện trong dữ liệu; luật: mỗi vùng tối đa 1 cửa hàng, mỗi run **ít nhất 2** cửa hàng ở hai tầng khác nhau (seeded, kiểm bằng test sinh 200 seed).
- [ ] Hàng bán (seeded theo run + cột): 3 lá (độ hiếm theo may mắn như `RewardRoller`), 2 bảo vật (`RelicRoller.roll("shop", …)` của Story 032, không trùng món đang có), và 2 dịch vụ:
  - **Bỏ một lá**: tối đa 1 lần mỗi cửa hàng, bỏ ngay một lá đã chọn (không qua token), giá 60;
  - **Hồi máu**: hồi 25 % máu tối đa, tối đa 1 lần mỗi cửa hàng, giá 40.
- [ ] Giá trong `economy.json` (khởi điểm, tỉ lệ theo OSFE: lá rẻ bằng khoảng nửa bảo vật): lá thường 40 / hiếm 60 / sử thi 85; bảo vật common 75 / rare 100 / epic 130; `price_floor_mult` theo tầng (khởi điểm 1,0 → 1,2). Món đã mua biến mất; mua lá đã có = nâng cấp như `RunSession.add_card`.
- [ ] Rời cửa hàng không cần mua gì; trạng thái cửa hàng (hàng còn lại, dịch vụ đã dùng) được lưu nếu thoát giữa chừng và vào lại cùng nút.

**Phần C — Nút sự kiện (`event`) và lá nguyền**

- [ ] Loại nút `event` trong generator (trọng số trong dữ liệu; mỗi vùng tối đa 1). `assets/data/events.json` (mô tả trong `schema.md`): `events: [{id, title_key, body_key, choices: [{label_key, requires, outcomes: [{chance, effects: [...]}]}]}]`. Hiệu ứng là danh sách nhỏ, đóng: `gold`, `hp` (± tỉ lệ máu tối đa), `relic` (nguồn + sàn độ hiếm), `card_offer` (độ hiếm), `curse` (id lá), `remove_card`, `upgrade_card`, `fight` (trận thêm), `run_modifier`. Kết quả ngẫu nhiên seeded theo run + cột (load lại không đổi kết quả).
- [ ] 8 sự kiện khởi điểm (mọi số là khởi điểm), lựa chọn cuối luôn là **Rời đi** (không mất gì):

| id | Tên (vi) | Lựa chọn rủi ro |
|---|---|---|
| `ban_tho_mau` | Bàn thờ máu | Mất 15 % máu tối đa (máu hiện tại) → 1 bảo vật, sàn `rare` |
| `ke_buon_nguyen` | Kẻ buôn lá nguyền | Nhận lá nguyền *Gánh Nặng* → chọn 1 trong 3 lá sử thi |
| `song_bac` | Sòng bạc ven đường | Cược 30 vàng: 50 % nhận 75, 50 % mất; hoặc cược 60: 40 % nhận 160 |
| `tran_thach` | Lời thách đấu | Đánh thêm một trận nguy hiểm của tầng này (+1 bậc khó) → thắng: 1 bảo vật + 25 vàng |
| `suoi_tinh` | Suối tĩnh | Hồi 25 % máu, **hoặc** mất 10 % máu tối đa để nâng cấp 1 lá |
| `ke_lang_thang` | Kẻ lang thang | Đổi 1 bảo vật đang có lấy 1 bảo vật ngẫu nhiên cao hơn một bậc độ hiếm (cần ≥ 1 bảo vật không phải `boss`) |
| `mo_hoang` | Mộ hoang | Đào mộ: 60 % nhận 40 vàng, 40 % nhận lá nguyền *Oán Hồn* |
| `loi_the` | Lời thề | Hai trận kế tiếp bước chậm hơn 20 % → +1 token bỏ lá và 30 vàng |

- [ ] Lựa chọn thiếu điều kiện (`requires`: đủ vàng, có bảo vật, máu > chi phí) hiện mờ kèm lý do, không bấm được. Không lựa chọn nào giết người chơi: chi phí máu không đưa máu dưới 1.
- [ ] `run_modifier` (chỉ dùng cho `loi_the` trong story này): `RunSession.run_modifiers: [{id, matches_left, params}]`, giảm 1 sau mỗi trận đã đánh, áp vào cấu hình trận như override của Story 032; lưu trong save.
- [ ] **Lá nguyền** (khái niệm mới, `cards.json` độ hiếm `curse`): không bao giờ có trong pool thưởng/cửa hàng, không nâng cấp, không có trong bộ boss. Trong menu phép, lá nguyền **chiếm một chỗ trong 4 lá rút**, hiện khóa (viền tím, không bấm được). Hai lá khởi điểm: *Gánh Nặng* (`ganh_nang`, chỉ chiếm chỗ) và *Oán Hồn* (`oan_hon`, chiếm chỗ và người chơi mất 2 máu mỗi lần nó được rút). Luật an toàn: nếu bộ còn lá thường, menu luôn có ít nhất 1 lá không nguyền (rút lại chỗ thứ tư); hết giờ vẫn tự *Kiếm khí* như nay. Lá nguyền không tính vào `min_deck_size`. Bỏ được bằng token bỏ lá, dịch vụ cửa hàng, hoặc `suoi_tinh`/sự kiện.

**Phần D — UI chạm (mobile ngang, ngón cái)**

- [ ] Màn cửa hàng: hàng lá và hàng bảo vật ở giữa màn (thẻ lớn, vùng chạm ≥ 64 dp), dịch vụ thành hai nút lớn bên phải; chạm một món → món nổi lên và nút **Mua (N vàng)** hiện ở góc dưới phải (vùng ngón cái phải); **Rời cửa hàng** góc dưới trái. Giá đỏ khi thiếu vàng. Chạm giữ một thẻ = xem mô tả đầy đủ.
- [ ] Màn sự kiện: khung chữ nửa trên (tối đa khoảng 300 ký tự mỗi ngôn ngữ, không cuộn), lựa chọn là 2–4 nút rộng ở nửa dưới, mỗi nút ghi rõ giá phải trả bằng màu đỏ trước khi bấm. Lựa chọn mất máu hoặc nhận lá nguyền cần chạm lần hai để xác nhận (nút đổi chữ "Chạm lần nữa để xác nhận" 2 s). Kết quả hiện một màn ngắn rồi về bản đồ.
- [ ] Biểu tượng nút cửa hàng và sự kiện trên bản đồ vẽ bằng code, khác hẳn các nút khác.

**Phần E — Kiểm chứng**

- [ ] Test (`tests/unit/run/`): vàng theo loại nút và tầng (seeded, xác định), `spend_gold` không âm; cửa hàng: hàng xác định theo seed, dịch vụ 1 lần/shop, mua lá trùng thì nâng cấp, mua bảo vật thì `RunSession.has_relic`; generator: ≤ 1 shop/vùng, ≥ 2 shop/run trên 200 seed; sự kiện: mỗi `effects` áp đúng, `requires` chặn đúng, máu không dưới 1, kết quả không đổi sau save/load; lá nguyền: chiếm chỗ, không bấm được, luật ít nhất 1 lá thường, *Oán Hồn* trừ máu khi rút; `run_modifier` hết sau 2 trận; save/load giữ `gold`, trạng thái cửa hàng, `run_modifiers`, lá nguyền.
- [ ] **Mô phỏng**: `deck_sim` thêm chính sách mua đơn giản (`--shop-policy=greedy`: mua bảo vật đắt nhất mua được, rồi lá, hồi máu khi máu < 50 %; sự kiện: chọn lựa chọn rủi ro khi máu > 60 %, ngược lại Rời đi). Báo: vàng kiếm/tiêu/thừa mỗi run (trung vị, P10, P90), số món mua mỗi cửa hàng, tỉ lệ thắng run có và không có cửa hàng/sự kiện, tỉ lệ chết trong trận thêm của `tran_thach`. Chỉnh `economy.json` nếu vàng thừa trung vị ≥ 100 hoặc người chơi trung bình không mua nổi 1 món ở cửa hàng thứ nhất. Bảng trong Completion Notes và `production/qa/evidence/gold-shop-events/simulation-economy.md`.
- [ ] Ảnh trong `production/qa/evidence/gold-shop-events/`: bản đồ có nút cửa hàng và sự kiện + số vàng (vi); màn cửa hàng (vi và en); món đang chọn với nút Mua; màn sự kiện `ban_tho_mau` (vi và en) với một lựa chọn mờ vì thiếu điều kiện; màn xác nhận lần hai; menu phép có một lá nguyền khóa (vi và en); màn thưởng có "+N vàng".
- [ ] Không hằng số gameplay trong mã; mọi chuỗi mới (`event.<id>.*`, `shop.*`, `card.ganh_nang.*`, `card.oan_hon.*`, `TEXT_GOLD_*`) có vi và en.

---

## Implementation Notes

- Mẫu thưởng và độ hiếm: `src/run/reward_roller.gd`, `src/run/reward_view.gd`, `assets/data/rewards.json` (`node_rewards`, may mắn). Thêm `shop`, `event` vào `node_rewards` với `offers: 0` để màn thưởng sau trận không chạy cho hai nút này.
- Trận thêm của `tran_thach` đi qua cùng đường trận của `GameFlow`/`RunController` như nút `danger`, nhưng **không** tiến cột: thắng thì về lại nút sự kiện để nhận thưởng rồi mới tiến; thua là chết như mọi trận.
- Lá nguyền: rút bài theo túi xáo ở `Deck`/`SkillConfig`; cờ `SkillConfig.is_curse(id)`; `RewardRoller.roll` và bộ boss (`boss_card_order()`) loại lá nguyền.
- `--demo=shop|event_altar|curse_in_menu|gold_reward` cho chụp ảnh.

---

## Out of Scope

- Làm mới hàng (refill), nâng cấp mua ở cửa hàng, bán đồ, hiến máu lấy vàng, cửa hàng đen; sự kiện nhiều bước hoặc có NPC lặp lại; pact đầy đủ của OSFE (chỉ `loi_the` làm mẫu); vàng mang sang run sau; hình mảnh ở cửa hàng (để Story 034 thêm dịch vụ "Xóa hình" khi xong).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/gold-shop-events/` (màn mới có bản vi và en); `simulation-economy.md` + raw.

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 031 (bản đồ thế giới v6: vùng, nhánh, loại nút, save run v6), Story 032 (bảo vật, `RelicRoller`)
- Unlocks: Story 034 thêm dịch vụ "Xóa hình" vào cửa hàng; Story 035 (Tha/Giết) có thể dùng vàng làm phần thưởng
