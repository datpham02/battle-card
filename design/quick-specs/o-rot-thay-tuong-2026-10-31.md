# Quick Design Spec: Ô rớt thay cho Tường, chỉ boss dùng, đứng trên là rơi chết

**Type**: Addition
**System**: Vùng (Tường / Bãi Gai), trait boss `seal_caster`
**GDD Reference**: `design/game-mechanics.md` §2.6 (Từ khóa trạng thái), §3 (nhóm lá), bảng nhân vật (Thợ săn), bảng bảo vật — không có `design/gdd/` ở `workflow: minimal`
**Date**: 2026-10-31
**Người dùng chốt**: 2026-10-31 — Tường thành ô rớt; chỉ boss có; đứng trên mà không né là rơi chết; cảnh báo 0,8 s
**Hình tham chiếu**: `prototypes/art-check` `--hole` / `--seq=hole`, ảnh `production/qa/evidence/asset-slice1-art-check/76`–`79`, `anim/hole-drop-v3.gif`; `design/assets/specs/misty-forest-assets.md` ASSET-006 (Superseded)

## Change Summary

Tường không còn là khối đứng trên ô mà là **ô rớt mất**. Chỉ boss có chiêu này. Ô nứt cảnh báo 0,8 s rồi rơi; ai còn đứng trên đó lúc rơi thì **rơi xuống và chết**.

## Motivation

Khối tường đứng không hợp góc nhìn của sân (dựng thử 2026-10-31); ô rớt đọc rõ hơn và biến chiêu của boss thành một mối nguy phải né thay vì một chướng ngại.

## Design Delta

`design/game-mechanics.md` §2.6 hiện ghi:

> | **Tường** | Ô của khối không bước vào được | 1,2 s |
>
> Luật cứng cho Tường và Bãi Gai: luôn chừa ít nhất 1 ô bước được cho bên bị nhốt.

Spec này đổi thành các luật dưới đây.

## New Rules / Values

1. **Ai dùng**: chỉ boss và Kẻ Gác, qua trait `seal_caster` (Ấn phong tỏa). Nhóm lá Tường (Kết giới, Lồng ấn, Lưới săn) **rời khỏi bộ lá của người chơi**.
2. **Chọn ô**: boss chọn `cells_min`–`cells_max` (2–3) ô trên nửa người chơi như hiện tại, **được phép gồm cả ô người chơi đang đứng** (luật cũ "không bao giờ ô của người chơi" bỏ).
3. **Cảnh báo**: các ô được chọn **nứt dần trong `hole_warn_sec` = 0,8 s** (vết nứt lan + độ đậm đỏ tăng dần như ô báo đòn, không chữ). Trong 0,8 s ô vẫn bước vào và bước ra được.
4. **Rơi**: hết cảnh báo các ô vỡ và thành hố trong `seal_sec` = 1,2 s; hố không bước vào được. Hết hạn thì ô hiện lại từ trắng đậm dần rồi bước được.
5. **Rơi chết**: đơn vị nào đứng trên ô lúc nó rơi thì rơi xuống hố, máu về 0. Với người chơi là **thua trận, hết chuyến leo** ("Chết là hết chuyến leo"). Hình: khung `fall` của anh hùng.
6. **Luật công bằng** (thay "luôn chừa ít nhất 1 ô bước được"):
   - lúc bắt đầu nứt phải còn **ít nhất một ô kề bước được, không nứt, không hố** (qua `ZoneRules`, điểm áp luật duy nhất);
   - ô của người chơi chỉ được chọn khi người chơi **bước kịp**: hồi bước còn lại ≤ `hole_warn_sec` − `hole_reaction_margin_sec` (0,8 − 0,2 = 0,6 s); đang Đóng Băng, bị trói chân, hay hồi bước (kể cả ô lầy) vượt mức thì ô đó **không được chọn**;
   - người chơi bị Đóng Băng hoặc trói chân **trong lúc** ô đang nứt dưới chân: ô đó nứt tiếp nhưng **không rơi** cho tới khi người chơi rời đi;
   - Tập trung (Focus) dừng thời gian trận nên dừng luôn đồng hồ nứt.
7. **Bãi Gai** giữ nguyên luật (hình mới: phủ nguyên ô, ASSET-007 v2). "Luật cứng" cũ không còn áp cho Bãi Gai vì gai vốn bước được.

### Thay Tường trong bộ của người chơi (Thợ săn được dựng quanh Tường + Gai)

| Hiện tại | Mới |
|---|---|
| Bộ khởi đầu Thợ săn: Kiếm khí ×2, **Kết giới ×2**, Trận gai, Rạn kích | Kiếm khí ×2, **Trận gai ×2, Gai độc**, Rạn kích |
| Dấu săn: "địch bước vào gai của bạn **hoặc đứng kề tường vừa dựng** thì +1 Rạn (chờ 3 s)" | "địch bước vào gai của bạn **hoặc đứng kề gai vừa rải** thì +1 Rạn (chờ 3 s)" |
| Vây Bắt: "4 s, **Tường** và Bãi Gai kéo dài ×1,5, tiêu Rạn ×2" | "4 s, Bãi Gai kéo dài ×1,5 **và rải thêm 1 ô**, tiêu Rạn ×2" |
| Bảo vật Phong Ấn Dài: Tường +1 s | **Gai Dai**: Bãi Gai +1 s (giữ điều kiện mở `ending_mercy`) |
| Thành tựu `boss_dungeon` thưởng lá Lưới săn | thưởng lá **Gai nguyền** |

## Tuning Knobs

| Khóa | Mặc định | Khoảng | Nơi | Ghi chú |
|---|---|---|---|---|
| `zones.hole_warn_sec` | 0,8 | 0,6–1,2 | `assets/data/combat.json` | người dùng chốt 0,8 |
| `zones.seal_sec` | 1,2 | giữ | `combat.json` | thời gian hố mở |
| `zones.hole_reaction_margin_sec` | 0,2 | 0,1–0,3 | `combat.json` | phần phản xạ trừ khỏi cảnh báo khi xét "bước kịp" |
| `zones.hole_fall_lethal` | true | bool | `combat.json` | false = rơi mất `fall_damage` như ô nứt Không Đảo (đường lùi khi playtest thấy quá gắt) |
| `seal_caster.may_target_player_cell` | true | bool | `chapters.json` params | false = hành vi cũ (chỉ ô thoát) |

## Affected Systems

| Hệ | Ảnh hưởng | Việc cần làm |
|---|---|---|
| Trait `seal_caster` (4 chương + Kiếp) | chọn ô mới, cảnh báo 0,8 s, rơi chết | sửa trait |
| `ZoneRules.fit_cells` / `cast_seal`, `StatusEffects` | luật công bằng mới, trạng thái nứt → hố | sửa + test đơn vị |
| `CombatState` / kết thúc trận | chết vì rơi = thua (người chơi) | nối vào đường thua hiện có |
| `cards.json`, `characters.json`, `relics.json`, `achievements.json`, chuỗi vi/en | gỡ Tường khỏi người chơi, thay theo bảng trên | sửa dữ liệu + chuỗi |
| `passives/hunter_mark.gd` | Dấu săn đổi điều kiện | sửa + test |
| `boss_brain` | boss không đứng trên nửa người chơi nên không cần né | không |
| `CutHudView` (ô ấn tím hiện tại) | thay bằng ô nứt → hố → hiện lại từ trắng | story hình (nối với Story 046 / sàn) |
| Art bible §3, §6.3 | câu về Tường | sửa câu |

## Acceptance Criteria

- [ ] Người chơi không còn nhận Kết giới, Lồng ấn, Lưới săn từ bất kỳ nguồn nào (bộ khởi đầu, thưởng, cửa hàng, thành tựu, Kiếp); bộ khởi đầu Thợ săn theo bảng trên.
- [ ] Boss có `seal_caster` nứt 2–3 ô 0,8 s rồi rơi; ô có thể gồm ô người chơi khi luật công bằng cho phép.
- [ ] Người chơi đứng yên trên ô nứt tới khi rơi thì thua trận; bước ra trong 0,8 s thì không mất máu.
- [ ] Luôn còn ít nhất một ô kề an toàn khi bắt đầu nứt; không bao giờ chọn ô của người chơi đang Đóng Băng / bị trói / hồi bước > 0,6 s; Đóng Băng giữa chừng thì ô dưới chân không rơi.
- [ ] Focus dừng đồng hồ nứt.
- [ ] Dấu săn kích hoạt khi địch đứng kề gai vừa rải; Vây Bắt rải thêm 1 ô gai.
- [ ] Không hồi quy: Bãi Gai, các trận không có `seal_caster`, đường thắng/thua hiện có.
- [ ] Test đơn vị cho luật chọn ô, luật công bằng, rơi chết và Dấu săn mới (không ngẫu nhiên, không I/O).

## GDD Update Required?

Có — `design/game-mechanics.md`: §2.6 dòng Tường và câu "Luật cứng"; §3 dòng Tường trong bảng nhóm lá; bảng nhân vật dòng Thợ săn; bảng bảo vật dòng Phong Ấn Dài; §1 dòng "Ấn phong tỏa (dựng Tường chặn đường thoát)". Ghi riêng sau khi người dùng duyệt.
