# Story 043: Tên riêng nhóm 5 — lá phép, Thức Tỉnh, bảo vật, đặc tính boss, nội tại (EN + VI)

> **Epic**: Kaiten Duel (v6)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: —
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/glossary.md` (mục "Nhóm 5"), `design/world-context.md` (thế giới Tessera, năm nhân vật), `design/game-mechanics.md` (hiệu ứng từng lá), `design/art/art-bible.md` (Mục 3 bảng 6 loại VFX; Mục 5 tên Thức Tỉnh)
**Requirement**:
- **Hiện trạng:**
  - Story 042 đã đổi mọi thuật ngữ nhóm 1–4. Tên riêng vẫn là tên đời trước Tessera.
  - Nhiều tên trùng hoặc lệch với từ khóa mới, ví dụ lá "Frost Breath" / "Hàn khí" trong khi từ khóa là Chill / Giá Lạnh, lá "Seal Ward" / "Kết giới" trong khi từ khóa là Wall / Tường, lá "Thorn Field" / "Trận gai".
  - Nhiều tên mang chữ "Ấn" của thế giới cũ.
  - Tên Thức Tỉnh là Hán-Việt kiểu kiếm hiệp: Trảm, Thiên Hỏa, Ảnh Bộ, Vây Bắt, Thánh Ấn.
  - `tests/unit/ui/terminology_scan_test.gd` đang giữ khoảng 29 ngoại lệ cho các tên này.
- **Phạm vi (khóa `*.name` trong `assets/i18n/strings.csv`, cả vi và en):**

  | Nhóm | Số tên |
  |---|---|
  | Lá phép `card.*.name` | 36 |
  | Thức Tỉnh `signature.*.name` | 5 |
  | Bảo vật `relic.*.name` | 16 |
  | Đặc tính boss `trait.*.name` | 15 |
  | Nội tại `passive.*.name` | 5 |

  Kèm theo là các câu mô tả nhắc đến những tên này: bộ khởi đầu ở màn chọn nhân vật, thành tựu, mô tả bảo vật.
- **Hướng đặt tên** (glossary nhóm 5, cùng sở thích của người dùng):
  - Đặt theo **hiệu ứng**, dễ hiểu, hợp fantasy phương Tây trầm lặng của Tessera.
  - **Tiếng Anh là ngôn ngữ chính**: tên tiếng Anh phải hay và tự nhiên. Tên tiếng Việt cùng nghĩa, tự nhiên, đa dạng, không dịch máy.
  - Không kiếm hiệp, không Hán-Việt sáo rỗng kiểu "Đại X", "Thiên X".
  - Không trùng từ khóa: lá gây Đóng Băng không được tên đúng là "Đóng Băng" / "Frozen".
  - Có thể dùng hình ảnh khối, ô vuông, lưới, Hình Gốc.
- **Tên nhân vật** (Kiếm sĩ, Pháp sư, Sát thủ, Thợ săn, Giáo sĩ) và **tên quái / Kẻ Gác**: giữ nguyên, ngoài phạm vi.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.6 | **Risk**: LOW–MEDIUM (chỉ đổi giá trị chuỗi; tên tiếng Anh dài có thể tràn thẻ lá hay thanh Thức Tỉnh; test đang khóa tên cũ)
**Engine Notes**: none

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

**Phần A — Đề xuất và duyệt tên**

- [x] Agent `writer` đề xuất **tên mới EN + VI** cho cả 77 tên, kèm một dòng lý do mỗi tên. Đề xuất chia theo nhóm: lá (theo loại hiệu ứng: Chém, Đẩy, Cháy, Băng, Rạn, Dựng, khác), Thức Tỉnh, bảo vật, đặc tính boss, nội tại. Mỗi tên nêu rõ hiệu ứng nó gọi ra (đọc từ dữ liệu và mô tả hiện có).
- [x] Không tên nào trùng một từ khóa trong glossary nhóm 1–4. Không hai tên trùng nhau trong cùng nhóm.
- [x] Người dùng **duyệt từng nhóm** trước khi ghi. Tên bị loại thì soạn lại tới khi được duyệt.

**Phần B — Ghi vào game**

- [x] `assets/i18n/strings.csv` cập nhật các khóa `*.name` của 5 nhóm trên cùng mọi chuỗi nhắc tới những tên đó (bộ khởi đầu, mô tả, thành tựu…). Ghi bằng module `csv` của Python, giữ 3 cột `keys,vi,en`, không đổi khóa, giữ mọi placeholder; chạy `--import` sau khi sửa.
- [x] `tests/unit/ui/terminology_scan_test.gd`: bỏ các ngoại lệ không còn cần. Test đang báo lỗi khi có ngoại lệ thừa. Test vẫn `FAILS=0`.
- [x] Mọi test đang kiểm tên cũ được cập nhật. Toàn bộ test headless và windowed chạy `FAILS=0`.
- [x] Tài liệu thiết kế đổi theo tên mới:
  - `design/art/art-bible.md` Mục 5 (bảng Thức Tỉnh) và Mục 3 (bảng VFX liệt kê tên lá);
  - `design/world-context.md`;
  - `design/glossary.md`: thay mục "Nhóm 5: chưa chốt" bằng bảng tên đã chốt.

**Phần C — Kiểm tra bằng mắt**

- [x] **Ảnh chụp EN và VI** lưu ở `production/qa/evidence/group5-names/`:
  - màn chọn nhân vật (bộ khởi đầu, Thức Tỉnh, nội tại);
  - phần thưởng chọn lá;
  - chiến lợi phẩm bảo vật;
  - nút Thức Tỉnh trong trận;
  - một trận có đặc tính boss hiện tên;
  - cửa hàng.
- [x] Không tên nào tràn thẻ, nút hay thanh ở cả hai ngôn ngữ.

---

## Implementation Notes

- Writer đọc `assets/data/cards.json`, `relics.json`, `characters.json`, `bosses.json` (hoặc file tương ứng) để biết hiệu ứng thật, không đoán từ tên cũ.
- Áp bằng script Python có danh sách khóa → tên rõ ràng, in bảng cũ → mới trước khi ghi. Không find/replace mù.
- Với chuỗi nhắc tên trong câu (bộ khởi đầu "Kiếm khí ×1 · …"), tìm theo tên cũ chính xác trong cùng khóa, sửa theo bảng đã duyệt.

## Out of Scope

- Tên nhân vật, tên quái, tên Kẻ Gác, tên vùng, tên sân.
- Đổi khóa, id, dữ liệu số hay hiệu ứng của lá, bảo vật, đặc tính.
- Font, bố cục giao diện (trừ khi một tên mới bị tràn và cách duy nhất là co chữ tại chỗ, như Story 042).

## Completion Notes
**Completed**: 2026-10-29
**Criteria**: 11/11 passing.
**Deviations**: none from the story. Approved choices that differ from the writers' first drafts: Awakening "Vung Hết Sức / Full Swing" (Kiếm sĩ) and "Ban Phước / Benediction" (Giáo sĩ); relic gai_ran "Đinh Cong / Bent Nails"; trait thorn_field vi "Gai Níu Chân". Three names kept as they were (Gánh Nặng / Dead Weight, Chỉ Khâu / Stitch Thread, Túi Rộng / Wide Pouch).
**Test Evidence**: UI. 16 EN + VI screenshots in `production/qa/evidence/group5-names/` (character select, card reward incl. the longest card names, execute spoils relics, shop, Awakening button, Heavy Mist label). `tests/unit/ui/terminology_scan_test.gd` (36 exceptions removed, 6 kept) and `i18n_test.gd`. Final sweep: 108/108 headless suites FAILS=0, 256/256 parse, 5/5 windowed FAILS=0.
**Code Review**: Skipped (review_mode solo).
**Notes**:
- The 15 trait `*.name` strings are not displayed on any screen yet (only the "Heavy Mist" HUD label); nothing to observe.
- Names not on a screenshot: Lingering Grudge / Mối Hận, Three-Link Chain, Mason's Mortar, Parrying Dagger, Gambler's Coin. All ≤ 16 characters; relic names auto-shrink to fit.
**Tech debt**: TD-039..TD-042 (description/data mismatches found while naming, added in this story).
