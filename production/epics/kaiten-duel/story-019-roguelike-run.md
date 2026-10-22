# Story 019: Run roguelike — thưởng lá sau mỗi trận, máu cả run, chết là hết, save run

> **Epic**: Kaiten Duel (v4)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-22

## Context

**GDD**: `design/game-brief.md` (v4, mục "Run")
**Requirement**: Người dùng chốt: một run = chọn nhân vật rồi đi hết một chương; sau mỗi trận thắng chọn 1 trong 3 lá; **chết là hết run** (hồi sinh là item thêm sau); tiếp tục được run đang dở sau khi tắt app. Story này thay luật "chơi lại trận đã thua" của Story 015 bằng luật run, biến màn chọn tầng thành chọn chương, và thêm màn thưởng lá.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Run và máu**

- [ ] `RunState` mở rộng thành **run cả chương**: nhân vật, bộ bài (`Deck`), chỉ số chương/tầng/trận, máu hiện tại (tài nguyên cả run), seed run. Tầng đi tuần tự; thắng boss tầng → tầng kế (sân mới theo seed), không về màn chọn; thắng boss tầng cuối → **RUN THẮNG**.
- [ ] Máu: đầy khi bắt đầu run; hồi `heal_between_matches` sau mỗi trận thắng, `heal_between_floors` (40, `chapters.json → defaults`) sau boss tầng; không đầy lại khi sang tầng. Nội tại `second_wind` cộng thêm ở cùng mốc.
- [ ] **Chết là hết**: màn "RUN KẾT THÚC" (nhân vật, chương, tầng/trận gục, số lá trong bộ, thời gian), một nút *Về title*. Không nút chơi lại trận, không giữ bộ bài. `RunState.retry_match` giữ trong mã cho item hồi sinh sau này; `revive_tokens` (0) trong `chapters.json → defaults`, chưa dùng.

**Phần B — Thưởng lá**

- [ ] `assets/data/rewards.json`: `offer_count` (3), `rarity_weights` {common 70, rare 25, epic 5}, `class_tag_bonus` (×2 trọng số cho lá có thẻ lớp của nhân vật), `allow_skip` (true), `pool_excludes_defaults` (false). `RewardRoller` (thuần, seeded): từ `cards.json` (implemented) rút `offer_count` lá **không trùng nhau** theo trọng số; test xác định.
- [ ] Sau mỗi trận thắng **không phải boss tầng cuối**: màn **THƯỞNG** thay màn "THẮNG TRẬN" hiện nay: 3 thẻ lá (tên, cần N ô, cooldown, một dòng hiệu ứng, độ hiếm bằng màu viền), nút *Bỏ qua*. Chọn → lá vào bộ, sang trận kế. Boss tầng (không phải tầng cuối) cũng cho thưởng. Không tự động chuyển sau N giây (bỏ `between_sec` tự động ở màn này).
- [ ] Nhãn bộ bài: một dòng nhỏ trong HUD "Bộ: 8 lá" (chạm để xem? **không**, xem bộ là story sau).

**Phần C — Chọn chương, save, mở khóa**

- [ ] Màn chọn tầng (015) thành **chọn chương**: một ô mỗi chương (khóa / mở / đã thắng), chương N+1 mở khi chương N đã thắng bằng bất kỳ nhân vật. Luồng: title → chọn nhân vật → chọn chương → run.
- [ ] **Save run** (`progress.json` v2): `run_in_progress` {character, chapter, floor, match, hp, deck (ids), run_seed, floor_seed, elapsed} ghi ở mốc bắt đầu mỗi trận và sau khi chọn thưởng; xóa khi run kết thúc (thắng hoặc chết). Title *Tiếp tục* và ô chương đang dở → tiếp tục đúng trận với máu và bộ đã lưu, **không có luật máu tối thiểu** (máu đúng như lúc vào trận). Vĩnh viễn: `cleared_chapters` [], `seen_cards` [] (chỉ ghi, chưa dùng). Đọc được file v1 cũ: bỏ qua phần không còn dùng, không crash.
- [ ] Bỏ `in_progress` theo tầng và nút "Chơi lại trận"; `--progress=demo` cập nhật cho dữ liệu mới; `--floor=` giữ cho chụp ảnh (vào thẳng tầng với nhân vật mặc định và bộ khởi đầu).
- [ ] Test: run thắng 3 tầng với máu mang qua (số kiểm được), thưởng vào bộ và tay rút sau đó có lá mới, chết → `run_in_progress` null và `cleared_chapters` không đổi, thắng → chương vào `cleared_chapters` và chương 2 mở, save/nạp giữa trận 2 tầng 2 giữ đúng bộ 9 lá và máu 57, file v1 nạp không lỗi.
- [ ] Ảnh trong `production/qa/evidence/roguelike-run/`: màn thưởng 3 lá; màn chọn chương (khóa/mở/thắng); RUN KẾT THÚC; RUN THẮNG; HUD với "Bộ: N lá"; title với Tiếp tục run.
- [ ] Không hằng số gameplay trong mã; chuỗi `TEXT_*`.

---

## Implementation Notes

- Giữ `RunController` là "một tầng" bên trong; `GameFlow` giữ `RunState` cả run và tạo `RunController` cho từng tầng với máu/bộ hiện tại. Hoặc gộp: chọn cách ít đụng `RunController` nhất và ghi vào Completion Notes.
- Màn thưởng là view mới (`RewardView`) dưới `GameFlow`, hiện khi `RunController` báo trận thắng và chờ `reward_chosen`/`reward_skipped` rồi mới cho tầng tiếp tục.
- `ProgressState` v2: thêm `run_in_progress`, `cleared_chapters`, `seen_cards`; giữ `from_json` chịu được v1.

---

## Out of Scope

- Bỏ/nâng lá, xem bộ bài giữa run, cửa hàng, tiền, sự kiện, item hồi sinh, Daily seed, mở khóa lá vào pool theo `seen_cards`.
- Nội dung chương 2–3 (boss, trait, lá mới).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/roguelike-run/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 017 (Deck, cards.json), Story 018 (nhân vật), Story 015 (chapters, progress)
- Unlocks: cổng chơi thử 5, nội dung chương 2–3, item hồi sinh
