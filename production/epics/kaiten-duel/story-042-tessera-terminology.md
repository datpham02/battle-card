# Story 042: Thuật ngữ Tessera — đổi chữ hiển thị nhóm 1–4 sang tên mới, tiếng Anh làm chính

> **Epic**: Kaiten Duel (v6)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/glossary.md` (nhóm 1–4, mục "Đổi theo kéo"), `design/world-context.md` (lore Biến Cố, Hình Gốc, Tâm Lưới), `design/game-brief.md` (mục "Đa ngôn ngữ")
**Requirement**:
- **Hiện trạng:**
  - Chữ trong game vẫn dùng tên đời trước Tessera: Ấn Kiếm, mảnh, trận đồ, tuyệt kỹ, kết giới, trận gai, Ghim, Hàn, Kiếp, Ấn Đài, Cột, Tiểu boss, Thi triển, run…
  - Quét `assets/i18n/strings.csv` ngày 2026-10-29: khoảng **166 / 837 khóa** dính tên cũ. Chúng nằm ở các nhóm achievement, arena, boss, card, chapter, character, ending, event, keyword, kiep, match, node, passive, phase, piece_deck, region, relic, run, signature, title, trait, ui, unlock.
- **Quyết định của người dùng:**
  - 2026-10-29: tiếng Anh là ngôn ngữ chính. Đã làm ở commit `8228527`: locale mặc định và dự phòng là `en`.
  - 2026-10-29, cho story này:
    - **Niệm = Channel / Channeling**, **Phá phép = Interrupt** (biểu ngữ NGẮT! = "INTERRUPT!").
    - **Phạm vi:** nhóm 1–4 cộng mục "Đổi theo kéo". Nhóm 5 (tên riêng của lá, Thức Tỉnh, bảo vật, đặc tính boss) để story sau.
    - **Lore có "Ấn Đài" viết lại:** writer soạn tiếng Anh trước rồi tiếng Việt; người dùng duyệt từng đoạn trước khi ghi vào CSV.
- **Bảng đổi:** cột "Mới (vi / en)" của `design/glossary.md` nhóm 1–4 là nguồn duy nhất. Không tự đặt tên mới ngoài bảng; thiếu tên thì hỏi người dùng.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: MEDIUM. Chữ tiếng Anh dài hơn có thể tràn ô hoặc nút. Một số tên cũ đồng thời là tên riêng nhóm 5 (ví dụ lá "Hàn khí"), nên dễ sửa lan. Lore viết lại cần người dùng duyệt.
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Thuật ngữ nhóm 1–4**

- [x] Mọi giá trị **vi** và **en** trong `assets/i18n/strings.csv` dùng thuật ngữ nhóm 1–4 đều theo cột "Mới" của glossary:
  - Cốt lõi: Khối / Block, Túi khối / Block bag, Bộ khối / Block set, Học hình / Learn shape, Quên hình + Lượt quên hình / Forget shape + Forget tokens, Khối Lạ / Odd Block, Lá phép / Spell card, Tung phép / Cast, Chuyến leo / Climb, Giao Kèo / Pact (điều khoản / term), Tâm Lưới / The Lattice Heart.
  - Trong trận: Bản Khắc / Engraving, Hình Cộng Hưởng / Resonant shape, Ghép / Join, Thức Tỉnh / Awakening, Nội tại / Passive, Tập trung / Focus, **Niệm / Channel**, **Phá phép / Interrupt**, Tường / Wall, Bãi Gai / Thorns.
  - Trạng thái: Cháy / Burn, Đóng Băng / Frozen, Giá Lạnh / Chill, Rạn / Fragile, Pierce, Execute.
  - Bản đồ: Chặng / Stage, Kẻ Gác / Warden (trận cuối vẫn gọi Boss), Tinh Anh / Elite, Mảnh Gốc / Primal Shard, Lượt bỏ lá / Card removals, Sa Mạc Cát Vùi / The Buried Sands.
  - Lore: Biến Cố / The Cataclysm, Hình Gốc / The Primal Form, Người Giữ Tâm Lưới / Heart Keeper.
- [x] Tên game ở `title.name` là **TESSERA** ở cả hai ngôn ngữ.
- [x] Một test mới (hoặc mở rộng `tests/unit/ui/i18n_test.gd`) quét mọi giá trị CSV và **báo lỗi nếu còn tên cũ** của nhóm 1–4 trong chữ hiển thị. Danh sách tên cũ lấy từ cột "Cũ" của glossary. Test cho phép các ngoại lệ có ghi lý do, ví dụ tên riêng nhóm 5 chứa chữ cũ, hay "Boss" ở trận cuối. Ngoại lệ nằm trong một danh sách có chú thích, không bỏ qua ngầm.
- [x] Không đổi **khóa**, id trong JSON hay tên biến trong code (`piece_deck.*` vẫn giữ). Chỉ đổi giá trị hiển thị.
- [x] Mọi placeholder (`{n}`, `%s`, `{cells}`…) giữ nguyên, đúng số lượng ở cả hai cột.

**Phần B — Đổi theo kéo**

- [x] Biểu ngữ pha 2 của trận cuối: **"Tâm Lưới bừng sáng" / "The Lattice Heart awakens"** hoặc tương đương. Không dùng chữ "Thức Tỉnh / Awakening" để khỏi trùng tên kỹ năng. Câu cuối cùng do người dùng duyệt.
- [x] Gợi ý vào trận: **"Nhặt khối · đặt lên đất địch · Tung phép"** / **"Pick up blocks · place on enemy ground · Cast"**.
- [x] Mô tả của lá, bảo vật và thành tựu có nhắc mảnh, trận đồ, hình chủ đạo, kết giới, Ghim, Hàn: đổi chữ trong mô tả theo bảng. Tên riêng của chúng (nhóm 5) giữ nguyên.

**Phần C — Lore viết lại**

- [x] Lời vào, lời kết của Tâm Lưới, ba đoạn kết, và các câu lore vùng có nhắc "Ấn Đài" (ví dụ câu "Phía trên, màn sương đang chờ" của Hầm Ngục) được **writer** viết lại theo `design/world-context.md`:
  - Tiếng Anh viết trước, tiếng Việt sau.
  - Không kiếm hiệp, không chữ Hán-Việt sáo rỗng kiểu "Đại X".
  - Giữ độ dài gần bản cũ để vừa khung.
- [x] Người dùng **duyệt từng đoạn** trước khi ghi vào CSV. Đoạn chưa duyệt thì giữ bản cũ đã thay từ, ghi vào ghi chú hoàn thành.

**Phần D — Kiểm tra**

- [x] `strings.csv` ghi bằng module `csv` của Python, đúng 3 cột `keys,vi,en`. Chạy `--import` sau khi sửa.
- [x] Toàn bộ test headless chạy `FAILS=0`. Test nào kiểm chữ cũ (ví dụ `i18n_test` đang kiểm "ẤN KIẾM") thì cập nhật cho khớp.
- [x] **Ảnh chụp** (UI story) lưu ở `production/qa/evidence/tessera-terminology/`, **cả EN và VI**: màn tiêu đề, trận đấu (gợi ý vào trận, HUD có Bản Khắc/Thức Tỉnh), bản đồ chuyến leo, màn Học/Quên hình, màn Giao Kèo, một kết thúc. Chữ không tràn ô hay nút ở cả hai ngôn ngữ.

---

## Implementation Notes

- Quét bằng script Python (`csv`), in ra danh sách khóa và giá trị cũ → mới để người dùng xem trước khi ghi. Không thay chuỗi mù bằng find/replace: "Hàn" còn nằm trong từ khác, "run" nằm trong "running", "Seal" có thể là một phần tên riêng.
- Tiếng Anh viết theo kiểu Title Case cho tên thuật ngữ (Block, Engraving), chữ thường trong câu khi ngữ pháp cần ("place blocks").
- Writer cho Phần C: agent `writer`, kèm `design/world-context.md` và `design/glossary.md`.

## Out of Scope

- Nhóm 5: tên riêng của ~40 lá, 5 Thức Tỉnh, 16 bảo vật, đặc tính boss.
- Đổi tên khóa, id hay biến trong code.
- Font mới (Noto Sans / font pixel) và mọi thay đổi bố cục HUD theo art bible.
- Ngôn ngữ thứ ba.

## Completion Notes
**Completed**: 2026-10-29
**Criteria**: 14/14 passing (D5 passed after fixing two map headers during /story-done).
**Deviations**:
- Ngoài danh sách file: `src/run/world_map_view.gd` và `src/run/chapter_map_view.gd`. Tiêu đề hai màn bản đồ giờ vẽ trong khoảng giữa nút "Block set" và số vàng, tự co chữ (tối thiểu 22 px). Sửa để đạt D5: "Giao Kèo" dài hơn "Kiếp", và tiêu đề EN vốn đã bị nút đè.
- Phần C: người dùng duyệt lore theo nhóm ("Duyệt hết như bản nháp"), không từng đoạn.
- Lời vào và lời kết Rừng Sương (`chapter.ch1.*`) writer có soạn nhưng không thêm vào game: chưa có chỗ hiển thị, nằm ngoài phạm vi.
**Test Evidence**: UI. 24 ảnh EN + VI ở `production/qa/evidence/tessera-terminology/` (tiêu đề, chọn nhân vật/Giao Kèo, bản đồ thế giới, bản đồ vùng, vào trận, học hình, bộ khối, Tha/Giết, chiến lợi phẩm, chuyến leo kết thúc, kết thúc Cán Cân). Test quét `tests/unit/ui/terminology_scan_test.gd` (12 check). Sweep cuối: 108/108 suite FAILS=0, 256/256 parse.
**Code Review**: Skipped (review_mode solo).
**Việc để sau** (không chặn story):
- Tên riêng nhóm 5 còn chữ cũ (lá "Frost Breath", "Seal Ward", "Hàn khí"; quái "Frost Sprite"). Lệch với từ khóa Chill/Wall. Làm ở story nhóm 5.
- Nút tiếng Việt "Về title" lẫn chữ tiếng Anh (có từ trước).
- Chữ thường giữa câu chưa thống nhất: "stage 1/3", "chặng 1/3", "thorns".
- Comment trong `src/` còn nhắc tên cũ (không hiện trong game).
