# Skill v2 — 60-card completion sprint (Nov 9–22, 2026): audit, dependency map, plan, dashboard

**Created:** 2026-11-09.

- **Roster (source of truth):** `02-skill-bible.md`. 60 cards = 32 existing (including 4 reworks) + 28 new. Curses
  and enemy cards are excluded.
- **Definition of done:** the sprint brief's 12 points:
  1. gameplay;
  2. Block shapes;
  3. timing, interruption and movement;
  4. cast animation;
  5. finished VFX;
  6. synchronized SFX;
  7. statuses, zones and boss interactions;
  8. card texts in Vietnamese and English;
  9. integration into progression;
  10. automated tests;
  11. in-game validation;
  12. no critical defect.

## 1. Dashboard (updated at the end of every batch)

| Metric | 2026-11-09 (start) |
|---|---|
| Total cards | 60 |
| **COMPLETE (all 12 points)** | **1: Ngàn Kiếm**: gameplay committed in `0472896`, sound in `7336f78`; animation + audio approved 2026-11-09; ElevenLabs licence line still to record |
| Presentation approved, other points pending | Hỏa Lôi: animation + audio approved, gameplay / VFX / Model C committed in `7319996`, sound in `7336f78`; multiplier + rewards pending |
| SFX done, audio sign-off pending | Trảm Địa |
| Legacy-playable, v2 upgrade pending | 32 existing cards (old instant cast path, generic impact packs, shared `cast_gesture`) |
| Not built | 25 new cards |
| In progress | Hỏa Lôi multiplier tuning (Model C) |
| Blocked | nothing technical; parallel workstreams need a committed baseline (see §4) |
| Tests | fresh full suite 2026-11-09: **228 / 228 test files green in one run** (incl. 8 new audio test files) |
| Critical bugs | 0 known in shipped behaviour. 1 balance-sim parity defect fixed today: sim swings had no CastContext, so shape clauses never applied in the sim |
| Audio coverage | 3 / 60 card-specific (Trảm Địa, Ngàn Kiếm, Hỏa Lôi; partly ElevenLabs, licence unconfirmed) + generic archetype sounds for the rest |
| VFX coverage (finished, card-specific) | 3 / 60, plus 32 cards with generic impact packs |
| Remaining workload | about 52 stream-days (§3) |

## 2. 60-card inventory

- **Est. days** = remaining stream-days per card, counted after its shared systems exist. It covers gameplay data
  and the card-specific rule, VFX composition, SFX composition, texts, tests and capture.
- **"golden ✓ / v2 ✗"** means the old behaviour is pinned by the golden test, but the v2 clause or rework is not built.
- Module ids are from `02-mechanics-catalog.md`.

| # | Card | Name | Owner | Gameplay now | Missing gameplay (v2) | Anim | VFX now | SFX | Tests | Est. days | Depends on |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `kiem_khi` | Rạch nhẹ | shared | legacy instant ✓ | none (baseline, cast-timeout fallback); leaves the starters (Q10) | cast_gesture (shared) | impact pack `burst` (generic) | ✗ | golden ✓ / v2 ✗ | 0.15 | — |
| 2 | `chan_phong` | Hích nhẹ | shared | legacy instant ✓ | REWORK → Hích Tường (Shove): push 1; blocked → R3 Va Đập; crit `target_pinned` kept | cast_gesture (shared) | impact pack `knockback` (generic) | ✗ | golden ✓ / v2 ✗ | 0.6 | M12, R3 |
| 3 | `hoa_tran` | Lò than | shared | legacy instant ✓ | `square` → the burn starts with 2 stacks; crit `target_burning` | cast_gesture (shared) | impact pack `burn` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M19, clause |
| 4 | `bang_phong` | Lặng yên | shared | legacy instant ✓ | `square` → Pin +0.3 s | cast_gesture (shared) | impact pack `freeze` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | clause |
| 5 | `kiem_vu` | Xé toạc | shared | legacy instant ✓ | sky arrival; `T` → the stem cell first ×1.25 | cast_gesture (shared) | impact pack `slash` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M05 |
| 6 | `thiet_kiem` | Lia ngang | shared | legacy instant ✓ | `line_h` → +1 dpc | cast_gesture (shared) | impact pack `slash` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | clause |
| 7 | `dai_dao` | Bổ nặng | shared | legacy instant ✓ | chain; a `line` of length ≥ 4 → ramp +10 %/link | cast_gesture (shared) | impact pack `slash` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M06 ramp |
| 8 | `xung_kich` | Xô lùi | shared | legacy instant ✓ | ground arrival; blocked push → R3 | cast_gesture (shared) | impact pack `knockback` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M04, M12, R3 |
| 9 | `hoa_tinh` | Tro hồng | shared | legacy instant ✓ | sky arrival with shadows; crit `target_burning` | cast_gesture (shared) | impact pack `burn` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M05 shadows, M19 |
| 10 | `hoa_xa` | Tia lửa | shared | legacy instant ✓ | ground arrival, stopped by holes; `line` → burn +1 s | cast_gesture (shared) | impact pack `burn` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M04, M19 |
| 11 | `suong_mong` | Men băng | shared | legacy instant ✓ | REWORK → Mặt Băng (Ice Floor): Pin 0.8 s if the unit stands in the mask; the cells become i | cast_gesture (shared) | impact pack `freeze` (generic) | ✗ | golden ✓ / v2 ✗ | 0.6 | M11 ice_floor |
| 12 | `bang_chau` | Mưa đá | shared | legacy instant ✓ | chain; `S` → faster links | cast_gesture (shared) | impact pack `freeze` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M06 |
| 13 | `cuong_phong` | Cú húc | shared | legacy instant ✓ | blocked push → R3 | cast_gesture (shared) | impact pack `knockback` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M12, R3 |
| 14 | `liet_hoa` | Lửa rừng | shared | legacy instant ✓ | ground arrival; `branched` → tips burn +1 s | cast_gesture (shared) | impact pack `burn` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M04 |
| 15 | `kiem_than` | Lưỡi sắc | shared | legacy instant ✓ | REWORK → Lưỡi Đầu (First Edge): crit `first_strike` ×1.6 (target not hit for 3 s) | cast_gesture (shared) | impact pack `slash` (generic) | ✗ | golden ✓ / v2 ✗ | 0.6 | M19 first_strike |
| 16 | `song_kiem` | Nêm sắt | shared | legacy instant ✓ | `compact` → bonus vs Rạn ×1.75 | cast_gesture (shared) | impact pack `slash` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | clause |
| 17 | `thien_lang` | Sạt lở | shared | legacy instant ✓ | sky shockwave from the centre; blocked push → R3 | cast_gesture (shared) | impact pack `knockback` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M05 shockwave, R3 |
| 18 | `han_bang` | Tảng băng | shared | legacy instant ✓ | sky shockwave from the centre (sets up R2) | cast_gesture (shared) | impact pack `shatter` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M05 shockwave |
| 19 | `thien_hoa` | Giàn thiêu | shared | legacy instant ✓ | sky arrival; `plus` → +1 burn stack | cast_gesture (shared) | impact pack `burn` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M05 |
| 20 | `tu_kiem` | Nhát cuối | shared | legacy instant ✓ | `mono` → execute threshold 35 % | cast_gesture (shared) | impact pack `slash` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | clause |
| 21 | `ran_kich` | Nứt chân chim | shared | legacy instant ✓ | ground arrival; `line` → +1 Rạn | cast_gesture (shared) | impact pack `shatter` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M04 |
| 22 | `han_khi` | Rùng mình | shared | legacy instant ✓ | `line` → +1 Hàn | cast_gesture (shared) | impact pack `freeze` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | clause |
| 23 | `ran_van` | Đứt gãy | shared | legacy instant ✓ | REWORK → Đường Nứt (Fault Line): Rạn stacks = number of pieces in the cast (+1 for a `line` p | cast_gesture (shared) | impact pack `shatter` (generic) | ✗ | golden ✓ / v2 ✗ | 0.6 | M04, pieces count |
| 24 | `han_phong` | Bão trắng | shared | legacy instant ✓ | chain `from_centre` | cast_gesture (shared) | impact pack `freeze` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M06 from_centre |
| 25 | `han_kiem` | Rét cắt | shared | legacy instant ✓ | crit `self_hp_high` (rhythm spec) | cast_gesture (shared) | impact pack `freeze` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M19 self_hp_high |
| 26 | `han_tran` | Tuyết rơi | shared | legacy instant ✓ | sky arrival; `plus` → +1 Hàn | cast_gesture (shared) | impact pack `freeze` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M05 |
| 27 | `tran_gai` | Bụi rậm | shared | legacy instant ✓ | `line` → thorns 4 s; crit `target_on_hazard` | cast_gesture (shared) | impact pack `thorns` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | clause, M19 |
| 28 | `gai_nguyen` | Dây úa | shared | legacy instant ✓ | `branched` → +1 Rạn on entry | cast_gesture (shared) | impact pack `thorns` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | clause |
| 29 | `gai_doc` | Bẫy chông | shared | legacy instant ✓ | `branched` → thorns +1 s; crit `target_on_hazard` | cast_gesture (shared) | impact pack `poison` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | clause, M19 |
| 30 | `thanh_thuy` | Sương bạc | shared | legacy instant ✓ | chain; `square` → heal +2 | cast_gesture (shared) | impact pack `freeze` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M06 |
| 31 | `bang_tam` | Buốt xương | shared | legacy instant ✓ | chain ramp (+10 %/link, cap +30 %) | cast_gesture (shared) | impact pack `shatter` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | M06 ramp |
| 32 | `do_kiem` | Đỡ Kiếm | kiem_si | legacy instant ✓ | see §1 | cast_gesture (shared) | impact pack `burst` (generic) | ✗ | golden ✓ / v2 ✗ | 0.3 | clause (line_v) |
| 33 | `tram_dia` | Trảm Địa | Hero Knight · rare · finishe | ✓ approved | audio, rewards | cast_forward ✓ | eruption ✓ | ✗ | ✓ | 0.3 | audio |
| 34 | `ngan_kiem` | Ngàn Kiếm | Hero Knight · epic · zone de | ✓ approved | audio, rewards | cast_summon ✓ | SkyDropFx ✓ | ✗ | ✓ | 0.3 | audio |
| 35 | `hoa_loi` | Hỏa Lôi | Hero Mage · common · setup | ✓ Model C (mult tuning) | mult final, audio, rewards | cast_gesture + glyph | FuseFx ✓ | ✗ | ✓ | 0.6 | audio, tuning, rewards |
| 36 | `thien_thach` | Thiên Thạch | Hero Mage · epic · burst | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 1.0 | M05 shockwave |
| 37 | `hoa_tuyen` | Hỏa Tuyến | Hero Mage · rare · terrain / | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 1.0 | M04, M11 fire wall |
| 38 | `song_dao` | Song Đao | Hero Assassin · common · sus | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.6 | M08, M19 combo_3 |
| 39 | `phi_tieu` | Phi Tiêu Liên Hoàn | Hero Assassin · rare · track | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.8 | M03+M06 chain |
| 40 | `dau_tu` | Dấu Tử | Hero Assassin · epic · setup | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 1.0 | M14 mark echo |
| 41 | `bay_kep` | Bẫy Kẹp | Hero Hunter · common · contr | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.9 | M09 trap |
| 42 | `moc_keo` | Móc Kéo | Hero Hunter · rare · spatial | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 1.0 | M12 pull, R3 |
| 43 | `gai_no` | Gai Nổ | Hero Hunter · epic · payoff | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.8 | M09, thorns consume |
| 44 | `thanh_thuan` | Thánh Thuẫn | Hero Cleric · common · defen | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 1.0 | M10 ward A2 |
| 45 | `chuong_thanh` | Chuông Thánh | Hero Cleric · rare · repeat | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.7 | M14 echo |
| 46 | `thien_quang` | Thiên Quang | Hero Cleric · epic · area co | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.6 | M05 |
| 47 | `dia_chan` | Địa Chấn | Shared · common · push | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.7 | M04, M12, R3 |
| 48 | `vung_lay` | Vũng Lầy | Shared · common · slow | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.5 | M11 mire |
| 49 | `lien_tram` | Liên Trảm | Shared · common · combo | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.4 | M08 |
| 50 | `khien_thep` | Khiên Thép | Shared · common · defense | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.5 | M10 |
| 51 | `thuong_xuyen` | Thương Xuyên | Shared · common · line payof | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.6 | shape requirement, M03 |
| 52 | `dap_vo` | Đập Vỡ | Shared · common · anti-armou | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.5 | Guard break |
| 53 | `chuoi_set` | Chuỗi Sét | Shared · rare · scaling chai | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.6 | M06 ramp |
| 54 | `loc_cuon` | Lốc Cuốn | Shared · rare · spatial | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.8 | M12 pull |
| 55 | `tuong_da` | Tường Đá | Shared · rare · terrain | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.9 | M11 pillar |
| 56 | `bay_lo` | Bẫy Lò Xo | Shared · common · trap push | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.5 | M09, M12 |
| 57 | `hoi_am` | Hồi Âm | Shared · epic · repeat | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.7 | M14 |
| 58 | `min_tre` | Mìn Trễ | Shared · common · delayed | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.4 | M07 ✓ |
| 59 | `bang_vo` | Băng Vỡ | Shared · rare · reaction pay | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.5 | R2 |
| 60 | `hoa_bang` | Hỏa Băng | Shared · epic · reaction ena | ✗ not built | full card (new) | ✗ (reuse cast_gesture) | ✗ | ✗ | ✗ | 0.5 | R1 |

## 3. Shared systems → cards they unlock (build order)

| # | Module | State | Est. days | Unlocks |
|---|---|---|---|---|
| 0 | Audio foundation (`10-audio-system-design.md`) + procedural SFX library | not built | 4.0 | all 60 (no card can be COMPLETE without it) |
| 1 | M19 crit conditions (target_burning, target_on_hazard, self_hp_high, first_strike, target_marked, combo_3, line_full) | only target_pinned | 0.5 | hoa_xa, hoa_tinh, hoa_tran, gai_doc, tran_gai, han_kiem, kiem_than, song_dao |
| 2 | M08 combo waves + combo_3 | engine ✓ (resolve `waves`), cards ✗ | 0.5 | song_dao, lien_tram |
| 3 | M07 delayed | ✓ (Hỏa Lôi) | — | min_tre |
| 4 | M04 ground arrival stopped by holes | partial | 0.5 | hoa_xa, liet_hoa, xung_kich, ran_kich, ran_van, dia_chan, vung_lay, hoa_tuyen |
| 5 | M05 sky arrival + shadows + shockwave | sky drops ✓, shockwave ✗ | 0.75 | thien_thach, thien_quang, thien_lang, han_bang, hoa_tinh, han_tran, kiem_vu, thien_hoa, dap_vo, bang_vo |
| 6 | M06 chain ramp / from_centre / faster links | order ✓, ramp ✗ | 0.5 | chuoi_set, phi_tieu, bang_chau, thanh_thuy, han_phong, bang_tam, dai_dao |
| 7 | M12 force move (push / pull) + R3 Va Đập | push ✓ (old path), pull ✗, R3 ✗ | 1.25 | moc_keo, loc_cuon, dia_chan, bay_lo, min_tre, chan_phong, xung_kich, cuong_phong, thien_lang |
| 8 | M09 trap zone + entry trigger | ✗ (thorn entry code reusable) | 1.0 | bay_kep, bay_lo, gai_no |
| 9 | M10 ward re-anchor A2 | ✗ | 1.25 | thanh_thuan, khien_thep |
| 10 | M11 terrain: pillar, ice floor, fire wall, card mire | mire hazard ✓ | 1.5 | tuong_da, suong_mong, hoa_tuyen, vung_lay |
| 11 | M14 echo (+ mark-attached echo) | ✗ | 1.0 | hoi_am, chuong_thanh, dau_tu |
| 12 | M15 reactions R1 Hơi Nước, R2 Vỡ Băng | ✗ | 0.75 | hoa_bang, bang_vo, han_bang |
| 13 | Small rules: Guard break, `line` shape requirement | ✗ | 0.25 | dap_vo, thuong_xuyen |
| 14 | S6 roster: hero reward pools, 8 unlockables, starters v2, texts | hero pools ✓ | 1.25 | integration of every new card |
| 15 | VFX family library (code-drawn components like FuseFx / SkyDropFx) | 3 families ✓ | 4.0 | all |
| 16 | Per-hero balance pass + full-roster regression + showcase build | tools ✓ | 2.5 | all |

The VFX library (row 15) covers: slash, ground ripple, chain spark, trap jaw, ward frame, pillar, ice glaze, echo copy,
pull vortex and reaction bursts.

- Foundations and shared systems: about **22.5 stream-days**.
- Per-card completion (table above): about **29.4 stream-days**.
- **Total: about 52 stream-days.**

## 4. Feasibility (honest)

- **What one stream can do.** There are 14 calendar days. This session alone delivers about 14 stream-days, which is
  about **27 % of the scope**. Prioritising cards that share systems, one stream reaches roughly **15–20 COMPLETE
  cards** by Nov 22: the audio foundation, the 3 reference skills and the cheapest families.
- **What 60/60 needs.** 52 stream-days / 14 days ≈ **3.7 parallel streams at 100 % efficiency**, or about **4.5–5
  streams** with 25 % integration, review and rework overhead.
- **Shortfall with one stream:** about 38 stream-days, i.e. about 40–45 cards.
- **Requirements to keep 60/60 feasible:**
  1. **A checkpoint commit now** (needs your approval). Parallel worktree sessions start from the last commit, so
     today's uncommitted work would be invisible to them: Hỏa Lôi H1 / H2, Model C, the audio design and the tests.
  2. **4 parallel workstreams from Nov 10**, each in its own worktree and owning its own files:
     - A: mechanics and data (combat core), with this session as integrator;
     - B: VFX family library (`src/art`, overlay and floor layers);
     - C: audio (`src/audio`, buses, settings);
     - D: QA, sim and balance, plus a second mechanics stream for the Assassin, Hunter and Cleric hero cards.
  3. **Your review cadence:** one batch review per day (640 and 2× contact sheets, short videos, audio clips), since
     every COMPLETE card needs a visual and audio sign-off.
  4. **An animation decision.** Either:
     - accept the existing hero clips (`cast_gesture` for the Mage, Assassin, Hunter and Cleric; the Knight's three
       clips) with code-drawn hand glyphs per family; or
     - approve paid archetype clips: about 4 heroes × 2 clips = 8 PixMiniMax generations, 1 credit each, plus review
       time.

     Without approval every card uses the existing clips, which the brief allows if they look intentional.
  5. **Audio sourcing:** original sounds synthesised in the repo by a script, plus CC0 where needed. No paid tools.
- **Even with all of the above, the deadline is high-risk.** The realistic outcome with 4–5 streams is 45–60 cards.

## 5. Daily plan

The last column is the target COMPLETE count at the end of each day: with 4 streams / with 1 stream.

| Date | Stream A (mechanics, integrator) | Stream B (VFX) | Stream C (audio) | Stream D (QA / 2nd mechanics) | Target COMPLETE |
|---|---|---|---|---|---|
| Nov 9 | audit and plan; Hỏa Lôi Model C tuning | — | design ready | tuning matrix | 0 / 0 |
| Nov 10 | M19 crits, M08 combo (song_dao, lien_tram), min_tre | slash and combo-hit family, glyph kit | foundation: rules, bank, voice pool, director, buses | sim parity tests for new modules | 0 / 0 |
| Nov 11 | M04 ground + M06 chain ramp (clauses of the existing ground and chain cards) | ground ripple, chain spark | settings, bridges; SFX synth tool and first 40 SFX | QA batch 1 | 6 / 3 |
| Nov 12 | M05 shockwave (thien_thach, thien_quang, thien_lang, han_bang) | sky shadow, shockwave ring | SFX for the 3 reference skills | M12 push / pull + R3 (moc_keo, loc_cuon, dia_chan) | 14 / 5 |
| Nov 13 | M09 traps (bay_kep, bay_lo, gai_no) | trap jaw, spring, thorn burst | warnings, UI, Block sounds | M15 R1 / R2 (hoa_bang, bang_vo) | 22 / 7 |
| Nov 14 | M10 wards (thanh_thuan, khien_thep) | ward frame | per-family SFX | M11 terrain (tuong_da, vung_lay, suong_mong) | 30 / 9 |
| Nov 15 | M14 echo (hoi_am, chuong_thanh, dau_tu) | echo copy, pillar, ice glaze | per-family SFX | v2 clauses of existing cards, batch 1 (14) | 40 / 11 |
| Nov 16–17 | remaining hero cards (hoa_tuyen, phi_tieu, thuong_xuyen, dap_vo, chuoi_set) | fire wall, lance, hammer | remaining SFX | v2 clauses batch 2 (14) + reworks | 50 / 14 |
| Nov 18–19 | S6 roster: rewards, unlocks, starters | polish pass on all 60 at 640 and 2× | mix pass, ducking, reduced audio | per-hero balance sims | 56 / 16 |
| Nov 20–21 | interaction fixes, regressions | showcase scene | audio QA | full-roster sim + boss matrix | 60 / 18 |
| Nov 22 | final regression, playable build, evidence of every card | | | | 60 / 18–20 |

## 6. Batch log

| Date | Cards COMPLETE (cumulative) | Systems | Tests | Evidence | Blockers |
|---|---|---|---|---|---|
| Nov 9 | 0 | Model C (data-driven `damage_cells_rule`), square ratio form, sim CastContext parity fix, model-aware evaluation bot, M19 crit conditions (7 new), audio foundation started (stream C session: bus layout, bank, event rules, voice pool, director, settings; 8 test files) | fresh full suite **228/228 files green in one run** | tuning: 21,900 matches (`14-hoa-loi-multiplier-tuning.md`) | approvals: Hỏa Lôi ×2.6 + square ratio 1.2; checkpoint commit; parallel streams; animation decision |
