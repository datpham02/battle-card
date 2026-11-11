# Skill v2 MVP matrix (2026-11-09)

Playable with a visible effect: **38/60**. Missing: **22**. Deadline 2026-11-22.

Trảm Địa stays the current forward MVP. Final backward choreography is deferred in `16-deferred-tram-dia-direction.md`. Ngàn Kiếm and Hỏa Lôi are untouched.

| Band | Cards | What they have |
|---|---|---|
| Dedicated | `tram_dia`, `ngan_kiem`, `hoa_loi` | Own cast / delivery / impact. Trảm Địa not artistically signed off. |
| Generic, playable | `kiem_khi` `chan_phong` `hoa_tran` `bang_phong` `kiem_vu` `thiet_kiem` `dai_dao` `xung_kich` `hoa_tinh` `hoa_xa` `suong_mong` `bang_chau` `cuong_phong` `liet_hoa` `kiem_than` `song_kiem` `thien_lang` `han_bang` `thien_hoa` `tu_kiem` `ran_kich` `han_khi` `ran_van` `han_phong` `han_kiem` `han_tran` `tran_gai` `gai_nguyen` `gai_doc` `thanh_thuy` `bang_tam` `do_kiem` `song_dao` `lien_tram` | Registered, targeted, effects resolve. Shared cast + the delivery pack already on the card (slash, floor run, sky squares, chain spark, knockback). |
| Batch 1 | `vung_lay` | Instant damage 2/cell, mask becomes mire 4 s (existing `TileHazards`, step ×1.6). Ground `floor_run` plus the mire tile draw. |

## 22 blocked — mechanic is not in the engine

Do not invent these.

| Card | Spec | Blocker |
|---|---|---|
| `thien_thach` | Centre meteor, ring shockwave, burn | M05 shockwave |
| `hoa_tuyen` | Floor fire, line becomes a wall that blocks the boss | M11 wall |
| `phi_tieu` | Daggers, bounce, 2-hit cap, L applies Rạn | M06 bounce |
| `dau_tu` | Mark, next cast echoes 60 %, execute under 30 % | M14 target echo |
| `bay_kep` | Trap cells, entry fires the cast, Pin | M09 trap zone |
| `moc_keo` | Hook, pull up to 2 along the row | M12 pull |
| `gai_no` | Detonate thorn and trap cells in the mask | Trap zones + zone query on a cast |
| `thanh_thuan` | Shape re-anchored on the hero, ward ×0.5 and heal | M10 self-anchor ward |
| `chuong_thanh` | Hit now, two echoes at 50 %, Hàn per wave | M14 echo waves |
| `thien_quang` | Pillar per cell, +1 Hàn (max 2), plus heals 6 | Per-cast Hàn cap and centre heal are not card fields. Sky drop itself exists. |
| `dia_chan` | Ground run, push 1 (line push 2) | Push is a card effect, not a payload on a ground wave |
| `khien_thep` | Self-anchor, Guard 6 while standing there | M10 |
| `thuong_xuyen` | Requires a line piece, pierce in order | Shape requirement in `SkillAvailability` |
| `dap_vo` | Strip Guard, ×1.5 if it had Guard | No card field strips Guard |
| `chuoi_set` | Chain, +15 % per link after the first | M06 ramp |
| `loc_cuon` | Pull 1 toward centre, then hit | M12 pull |
| `tuong_da` | Empty cells become pillars | Pillar zone |
| `bay_lo` | Trap, entry pushes 2 | M09 + M12 |
| `hoi_am` | Echo shifted 1 cell | M14 |
| `min_tre` | Fuse 1.2 s ×1.6, detonation pushes 1 | Fuse path exists (`hoa_loi`). `event_payload` keys are ignite only, so the push is not data. |
| `bang_vo` | Apply Rạn, then R2 if pinned | R2 |
| `hoa_bang` | Ignite and +1 Hàn so R1 fires | R1 |

`vung_lay` still missing from the bible, on purpose: compact → 5 s is not a `shape_clause` key, and the instant resolver does not stop the mask on holes.

## Deferred after 60/60 (user decision 2026-11-11)

Open items of Skill v2 batch 2 (`19-batch2-report.md`). All PENDING, none blocks 60/60. In priority order:

1. **Reaction ICD 1.0 s per unit per reaction id + `immune_status` / `burn_eater` checks** (M15 rules) — must land
   before the balance pass.
2. **R1–R3 card-listed or global** — a balance decision after 60/60, leaning global; needs the 33 legacy cards
   re-measured and `skill_v2_golden_test` re-recorded (`hit3_ran_pinned`, `edge_push` change under global R2 / R3).
3. **The boss drawing the 5 new shared cards** (`dia_chan`, `loc_cuon`, `bang_vo`, `hoa_bang`, `hoi_am`) — tune in the
   sim during the balance pass.
4. **Several shape clauses on one card** (Thiên Thạch `square` → every cell is the centre; the `hub_all` clause key
   exists) — low priority.
5. **R1 when a unit with Hàn enters a burning cell; R3 when a forced move ends on a thorn cell** — low priority.

### Added by batch 3 (2026-11-11, same decision: PENDING, none blocks 60/60)

6. **Ward ghost preview in the card menu** (the highlighted ward card shows where the shape lands around the hero,
   M10 "needs") — HUD work in `cut_hud_view.gd`; the remap itself is pure (`WardAnchor.remap`).
7. **Floor drawing for the field zones** (trap jaws, ward frames, pillars, fire-wall columns) — the VFX session's
   `FloorLayer`; `StatusEffects.zone_applied` / `zone_expired` already carry the kinds `trap` / `ward` / `pillar`,
   `StatusEffects.wall_cells()` the wall.
8. **Trap damage through the defense path** — a snapping trap deals `dpc × cells` straight to HP like a thorn toll
   (`boss_defense` is not subtracted); decide with the balance pass.
9. **Bùng Nổ detonating a fire wall; a trap fling into a pillar as R3** — low priority.
