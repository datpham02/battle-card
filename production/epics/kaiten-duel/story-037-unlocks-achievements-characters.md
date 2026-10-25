# Story 037: Mở khóa theo cột mốc, 22 thành tựu, nhân vật Thợ săn và Giáo sĩ — chỉ thêm lựa chọn, không thêm sức mạnh

> **Epic**: Kaiten Duel (v6)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md` (v6, mục "Run v6 — mô hình OSFE" › "Chơi lại (thay cho 'vượt chương')", "Tha hay Giết"; v4 "Nhân vật (018, 021) — không có 'lớp'"), `design/reference/osfe-reference.md` (§6.1 `RewardType.Unlock`, §4.2 bản sắc hero)
**Requirement**: Run v6 bỏ "vượt chương", nên lý do chơi lại phải đến từ **mở khóa theo cột mốc** và **thành tựu**, như OSFE. Luật cứng của brief: **chỉ mở thêm lựa chọn, không cộng sức mạnh vĩnh viễn**. Hiện `ProgressState` (`src/run/progress_state.gd`, `VERSION` 4) chỉ lưu `cleared_chapters`, `seen_cards`, `cleared_bosses`; nhân vật mở/khóa là cờ tĩnh `unlocked` trong `assets/data/characters.json` mà `character_select_view.gd` đọc. Story này thêm sổ cột mốc, 22 thành tựu có thưởng nội dung, nội dung bị khóa lúc đầu (2 nhân vật, 4 lá, 3 hình mảnh, 4 bảo vật), và hai nhân vật mới.

**Nhân vật — cùng khuôn với ba người có sẵn**: mỗi tuyệt kỹ **khuếch đại một hướng bộ bài**, không tự mạnh (Trảm → lá sát thương cao; Thiên Hỏa → Đốt chồng; Ảnh Bộ → Ghim + lá nhỏ). Hai hướng còn trống trong pool là **vùng + Rạn** (lá `ket_gioi`, `long_an`, `tran_gai`, `gai_nguyen`, `ran_kich`, `ran_van`) và **Hàn** (`han_khi`, `han_phong`, `han_tran`, `han_kiem`) — giao cho Thợ săn và Giáo sĩ.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM (đổi phiên bản save; hai nội tại và hai tuyệt kỹ mới chạm `CutEffects`/`StatusEffects`)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Sổ cột mốc trong ProgressState**

- [ ] `ProgressState` lên `VERSION` 5: thêm `milestones` (từ điển khóa → số nguyên) và `achievements` (danh sách id đã đạt). Khóa cột mốc: `region_boss:<region_id>` (số lần hạ), `reached_final`, `runs_won`, `runs_won:<character_id>`, `kills_total`, `spares_total`, `ending:<ending_id>` (ba kết thúc của Story 035). Save v4 vẫn nạp: `cleared_bosses` giữ nguyên; mỗi `cleared_chapters` cũ tính là đã hạ boss vùng tương ứng (`ch1`→vùng Rừng Sương… theo ánh xạ của Story 031); không trao thành tựu nào khác hồi tố. Save v5 nạp ở bản này không mất trường nào (test vòng to_json → from_json).
- [ ] Đánh giá nằm trong một lớp thuần (`src/run/unlock_rules.gd` hoặc tương đương, không phụ thuộc scene): nhận sự kiện run (`region_boss_cleared(region, verdict)`, `final_reached`, `run_ended(won, ending)`, và bộ đếm trong run) và `ProgressState`, trả danh sách thành tựu mới đạt. Bộ đếm **trong run** (đòn trùng hình chủ đạo, lần Hàn nổ trong trận, lần boss vào gai) nằm trong snapshot `RunSession` để tiếp tục run không mất tiến độ.
- [ ] Cột mốc chỉ ghi ở điểm lưu (cuối nút, cuối run); bỏ run giữa chừng không trao gì cho nút chưa xong.

**Phần B — Thành tựu và nội dung bị khóa (dữ liệu)**

- [ ] File mới `assets/data/achievements.json`, mỗi mục: `id`, `name_key`, `desc_key`, `condition` (`type` + `params`), `rewards` (danh sách `{kind: character|card|piece|relic|region, id}`, có thể rỗng), `hidden` (mặc định false). Có trong `assets/data/schema.md`. Khóa `unlock_by` (id thành tựu) thêm vào mục lá (`cards.json`), hình (`pieces.json`), bảo vật (dữ liệu của Story 032), vùng (dữ liệu của Story 031), nhân vật (`characters.json`, thay cờ tĩnh `unlocked`); không có `unlock_by` = mở từ đầu.
- [ ] **22 thành tựu** (khởi điểm; tên vi/en):

| id | Điều kiện | Thưởng |
|---|---|---|
| `first_region_boss` | hạ boss vùng đầu tiên | lá `gai_doc` |
| `reach_an_dai` | lần đầu tới Ấn Đài | hình `w5` |
| `first_run_won` | thắng run lần đầu | 1 bảo vật |
| `hunter_path` | Giết tổng 3 boss vùng | nhân vật **Thợ săn** |
| `mercy_path` | Tha tổng 3 boss vùng | nhân vật **Giáo sĩ** |
| `ending_mercy` | xem kết thúc tha hết | 1 bảo vật |
| `ending_middle` | xem kết thúc lưng chừng | lá `bang_tam` |
| `ending_slaughter` | xem kết thúc giết hết | 1 bảo vật |
| `boss_forest` | hạ boss vùng Rừng Sương | hình `y5` |
| `boss_dungeon` | hạ boss vùng Hầm Ngục | lá `luoi_san` |
| `boss_frost` | hạ boss vùng Tháp Sương | lá `thanh_thuy` |
| `zone_trap` | boss bước vào gai 5 lần trong một run | hình `n5` |
| `frost_burst_5` | 5 lần Hàn nổ trong một trận | 1 bảo vật |
| `win_kiem_si` … `win_giao_si` (5) | thắng run với từng nhân vật | — |
| `burn_build` | hạ boss vùng với ≥ 4 lá Đốt trong bộ | — |
| `featured_10` | 10 đòn trùng hình chủ đạo trong một run | — |
| `no_hit_boss` | hạ boss vùng không nhận đòn nào | — |
| `small_deck` | thắng run với bộ ≤ 8 lá | — |

- [ ] Bốn bảo vật thưởng là 4 mục trong danh sách của Story 032, chọn lúc làm (ưu tiên bảo vật đổi luật hợp với Thợ săn/Giáo sĩ), ghi id vào Completion Notes. Thành tựu vùng của Story 036/039 do các story đó thêm theo cùng mẫu (ngoài phạm vi ở đây).
- [ ] **Không cộng sức mạnh vĩnh viễn** (luật cứng): nội dung mở chỉ vào **pool** (thưởng lá `RewardRoller`, pool hình mảnh, pool bảo vật, pool vùng, màn chọn nhân vật). Test: với cùng nhân vật và seed, trạng thái đầu run (máu, bộ khởi đầu, bảo vật, vàng, bộ mảnh, túi) giống hệt giữa save trống và save mở hết.
- [ ] Pool lúc đầu không nghèo đi: không lá, hình, bảo vật có sẵn nào bị khóa lại; mọi thứ bị khóa là nội dung **mới** của story này hoặc 032.

**Phần C — Nội dung mới bị khóa**

- [ ] **4 lá** trong `cards.json` (`name_key`/`desc_key` vi/en, `unlock_by`; số khởi điểm, cùng đường cong độ hiếm của 023):
  - `gai_doc` (*Gai độc*, thường): `thorns`, `min_cells` 3, `damage_per_cell` 2, `thorn_fragile_stacks` 1, cooldown 6 s.
  - `luoi_san` (*Lưới săn*, hiếm): `seal`, `min_cells` 2, `seal_sec` 2,0, `fragile_stacks` 1 khi đòn trúng boss, cooldown 7 s.
  - `thanh_thuy` (*Thánh thủy*, thường): `frost`, `min_cells` 3, `frost_stacks` 1, khóa mới `heal_self` 4 (hồi cho người niệm khi đòn tới nơi, trúng hay trượt), cooldown 6 s.
  - `bang_tam` (*Băng tâm*, hiếm): `damage`, `min_cells` 4, `damage_per_cell` 5, `frost_stacks` 2, cooldown 6 s.
- [ ] **3 hình mảnh 5 ô** trong `pieces.json`: `w5`, `y5`, `n5`, trọng số 0,5–1 trong mỗi `weights` (khởi điểm), `unlock_by`; đặt vừa ít nhất một sân của mỗi vùng.
- [ ] Lá dùng trường mới (`heal_self`, kết hợp `seal` + `fragile_stacks`) đi qua `CutEffects` ở đúng một điểm như các trường cũ.

**Phần D — Thợ săn và Giáo sĩ**

- [ ] **Thợ săn** (`tho_san`, `characters.json`, `unlock_by: hunter_path`): `max_hp` 190, `step_cooldown_mult` 0,95, `focus_max_sec` 4,0. Bộ khởi đầu: `kiem_khi`, `kiem_khi`, `ket_gioi`, `tran_gai`, `ran_kich`, `chan_phong`.
  - Nội tại `hunter_mark` (*Dấu săn*, `src/passives/hunter_mark.gd`, đăng ký trong `PassiveRegistry`): khi boss bước vào ô gai của ta, hoặc đang đứng kề một ô kết giới của ta lúc vùng hình thành, boss nhận `fragile_stacks` 1 tầng Rạn; thời gian chờ nội `icd_sec` 3 s.
  - Tuyệt kỹ `vay_bat` (*Vây Bắt*, `src/signatures/vay_bat.gd`, theo `timed_signature.gd`): `cooldown_sec` 20; trong `duration_sec` 4 s mọi vùng ta tạo kéo dài × `zone_sec_mult` 1,5 và mỗi tầng Rạn bị tiêu nhân × `fragile_mult` 2,0 thay vì 1,5. Không có lá vùng/Rạn thì tuyệt kỹ gần như vô dụng — đúng khuôn "khuếch đại bộ bài".
- [ ] **Giáo sĩ** (`giao_si`, `unlock_by: mercy_path`): `max_hp` 210, `step_cooldown_mult` 1,05, `focus_max_sec` 4,5. Bộ khởi đầu: `kiem_khi`, `kiem_khi`, `han_khi`, `han_khi`, `han_kiem`, `bang_phong`.
  - Nội tại `prayer` (*Lời nguyện*, `src/passives/prayer.gd`): mỗi lần Hàn nổ trên boss, ta hồi `heal_per_burst` 8 máu.
  - Tuyệt kỹ `thanh_an` (*Thánh Ấn*, `src/signatures/thanh_an.gd`): `cooldown_sec` 22; trong `duration_sec` 4 s mỗi đòn tới nơi trúng boss thêm `extra_frost_stacks` 1 tầng Hàn và Hàn nổ trong lúc này gây × `burst_mult` 1,5. Khuếch đại bộ Hàn; nội tại cho bộ đó sức bền thay vì sát thương.
- [ ] Tên, mô tả, tên/mô tả nội tại và tuyệt kỹ có khóa vi/en (`character.<id>.*`, `passive.<id>.*`, `signature.<id>.*`). Đúng luật "không có lớp": không lá nào gắn với nhân vật, thưởng không nghiêng theo nhân vật.

**Phần E — Màn hình (chạm bằng ngón cái, ngang)**

- [ ] **Màn chọn nhân vật** (`src/run/character_select_view.gd`): 5 thẻ; thẻ khóa vẫn xám có ổ khóa, **chạm vào** thì hiện điều kiện mở và tiến độ ("Giết 3 boss vùng — 1/3") trong một dải dưới thẻ thay vì bỏ qua chạm. Thẻ mở như cũ.
- [ ] **Màn thành tựu** (mới, `src/run/achievements_view.gd`, nút "Thành tựu" trên title): lưới 4 cột, cuộn dọc bằng kéo ngón cái có quán tính; mỗi ô có biểu tượng, tên, trạng thái (đạt / tiến độ n/N / ẩn "???" khi `hidden`) và biểu tượng loại thưởng; chạm một ô mở bảng chi tiết (điều kiện, thưởng, tiến độ). Bộ đếm "x/22" ở đầu. Nút Về ở góc dưới trái (tầm ngón cái trái). Vùng chạm không nhỏ hơn thẻ nhân vật hiện có.
- [ ] **Báo mở khóa**: không bao giờ trong trận. Hiện ở màn sau nút boss vùng và màn kết thúc run: danh sách "Mới mở" (tên + loại); chạm để bỏ qua. Lá/hình/bảo vật mới có dấu "Mới" lần đầu xuất hiện trong thưởng.
- [ ] `--progress=all` mở hết (cột mốc và thành tựu), thêm `--progress=none`; dùng cho chụp ảnh và mô phỏng.

**Phần F — Kiểm chứng**

- [ ] Test (`tests/unit/run/unlock_rules_test.gd`, `tests/unit/run/progress_state_v5_test.gd`, `tests/unit/run/character_unlock_test.gd`, mở rộng `tests/unit/combat/signature_test.gd` và test nội tại): mỗi loại điều kiện trao đúng thành tựu đúng một lần; nạp save v4 và v5; nội dung khóa không có trong pool trước khi mở và có sau khi mở (lá, hình, bảo vật, vùng — vùng thử bằng dữ liệu giả); trạng thái đầu run giống nhau giữa save trống và mở hết; `hunter_mark` cho Rạn đúng hai trường hợp và tôn trọng `icd_sec`; `vay_bat` kéo dài vùng và đổi hệ số Rạn chỉ trong thời gian hiệu lực; `prayer` hồi khi Hàn nổ; `thanh_an` thêm tầng và nhân nổ; 4 lá mới; đủ khóa i18n vi/en.
- [ ] **Mô phỏng** (`tools/balance/deck_sim.gd`, thêm nhân vật vào `--characters` và cờ `--progress=none|all`): (1) tỉ lệ thắng run của **Thợ săn** và **Giáo sĩ** nằm trong ±10 điểm so với trung bình ba nhân vật cũ (cùng chính sách build, cùng seed); (2) mỗi nhân vật, chênh tỉ lệ thắng giữa `--progress=none` và `--progress=all` ≤ 10 điểm (mở khóa là bề rộng, không phải sức mạnh); (3) số run trung bình để mở mỗi nhân vật mới với chính sách Tha/Giết xen kẽ là 1–3 run (đếm từ sổ cột mốc của sim). Bot dùng tuyệt kỹ mới theo luật đơn giản ghi trong `tools/balance/README.md` (Vây Bắt ngay sau khi một vùng hình thành; Thánh Ấn khi boss có ≥ 1 tầng Hàn). Không đạt thì chỉnh JSON. Bảng vào Completion Notes và `production/qa/evidence/unlocks-achievements/simulation-characters.md` (+ raw).
- [ ] Ảnh trong `production/qa/evidence/unlocks-achievements/`: màn chọn nhân vật 5 thẻ với Thợ săn khóa và dải điều kiện; màn thành tựu (vi và en) có ô đạt, ô tiến độ, ô ẩn; bảng chi tiết một thành tựu; màn "Mới mở" sau boss vùng; Thợ săn đang Vây Bắt (vùng có viền tuyệt kỹ); Giáo sĩ đang Thánh Ấn với Hàn nổ và số hồi máu; thẻ thưởng có dấu "Mới".
- [ ] Không hằng số gameplay trong mã; chuỗi mới là khóa trong `assets/i18n/strings.csv` với vi và en; JSON chỉ `name_key`/`desc_key`.

---

## Implementation Notes

- `CharactersConfig.unlocked_ids()` (đang được `GameFlow` và `character_select_view.gd` gọi) đổi thành hỏi `ProgressState` + `unlock_by`; giữ chữ ký để không vỡ caller. Cờ `unlocked` cũ: `true` hiểu là "không `unlock_by`", bỏ khỏi JSON sau khi chuyển.
- `RewardRoller.roll` đã có danh sách loại trừ (Story 027 dùng cho lá vùng): nội dung khóa đi qua cùng đường đó.
- Thứ tự làm: A → B (khung dữ liệu, test không cần nội dung) → C → D → E → F.

---

## Out of Scope

- Cấp Kiếp (Story 038). Thử thách ngày, đồ trang trí, tự chọn luật (brief "để sau"). Thành tựu nền tảng (Google Play Games). Thành tựu vùng mới (036/039 tự thêm). Thêm lá ngoài 4 lá trên. Sức mạnh vĩnh viễn dưới mọi hình thức.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: minimal`: tests are waived (advisory), but the retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Retained screenshots trong `production/qa/evidence/unlocks-achievements/`; bảng mô phỏng nhân vật và mở khóa.

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 031 (vùng, Ấn Đài, sự kiện run), Story 035 (Tha/Giết, ba kết thúc); dùng danh sách bảo vật của Story 032
- Unlocks: Story 038 (cấp Kiếp theo nhân vật), Story 039 (mục mở khóa cho vùng mới), Story 040 (cân bằng 5 nhân vật)
