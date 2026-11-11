# Cast presentation

Visual only. It does not change delivery, damage, timing, or targeting.

`cast_presentation` on a card: `weapon`, `hand`, `throw`, `body`, `special`. Absent means `weapon`.

A `card_casts` clip still wins. Trảm Địa stays `cast_forward`. Ngàn Kiếm stays `cast_summon`. Hỏa Lôi stays the Mage `cast_gesture`.

`hand` plays sheet clip `cast_hand` when that clip exists.

| Body | `cast_gesture` frames | Hand cast |
|---|---|---|
| `kiem_si` | 9 frames, 96×92, `cast_gesture` 0–8. Sword raise and horizontal cut. `cast_forward` and `cast_summon` are also sword poses. | No `cast_hand` row. A hand cast holds idle. |
| `sat_thu` | 9 frames, 96×70, `cast_gesture` 0–8. Dual daggers, then a slash. | No `cast_hand` row. A hand cast holds idle. |
| `tho_san` | 9 frames, 96×72, `cast_gesture` 0–8. Crossbow raise, aim, shot. | No `cast_hand` row. A hand cast holds idle. |
| `giao_si` | 9 frames, 96×72, `cast_gesture` 0–8. Staff raised the whole clip. | No `cast_hand` row. A hand cast holds idle. |
| `phap_su` | 9 frames, 96×70, `cast_gesture` 0–8. Book in one hand, the other hand opens toward the target. | That clip is the hand cast. No `cast_hand` row. |

Sheets face right. Left facing is the existing flip. No hero sheet has a `cast_hand` row (dropped 2026-11-11).

`vung_lay` is `hand`. Delivery stays `floor_run`.

## Playable cards, by the action, not by the element

Wired: `vung_lay` only. The other hand-classified cards stay on their current clip until this pose is visually approved.

**weapon** — the action is a strike with the equipped weapon: `kiem_khi`, `kiem_vu`, `thiet_kiem`, `dai_dao`, `kiem_than`, `song_kiem`, `tu_kiem`, `han_kiem`, `do_kiem`, `song_dao`, `lien_tram`.

**special** — approved choreography, leave it: `tram_dia`, `ngan_kiem`, `hoa_loi`.

**hand** — the action is magic from an open hand: `vung_lay`, `hoa_tran`, `hoa_tinh`, `hoa_xa`, `liet_hoa`, `thien_hoa`, `bang_phong`, `suong_mong`, `bang_chau`, `han_bang`, `han_khi`, `han_phong`, `han_tran`, `thanh_thuy`, `bang_tam`.

**body** — a shove, charge, or planting, not a blade and not a spell: `chan_phong`, `xung_kich`, `cuong_phong`, `thien_lang`, `tran_gai`, `gai_nguyen`, `gai_doc`.

**throw** — none of the playable cards. `phi_tieu` is still unbuilt.
