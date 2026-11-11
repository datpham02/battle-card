# Skill v2 — animation and VFX audit of the 60 cards + implementation plan

**Date:** 2026-11-09 · **New priority (user):** animation completeness → visual quality → gameplay integration →
audio polish later. **Audio is frozen:** no ElevenLabs, no new SFX, no mix changes. Existing placeholder audio and all
generated files and metadata are kept. **Deadline:** Nov 22, 2026.
Evidence: `production/qa/evidence/skill-v2-animation-audit/`.

## 1. How the audit was done

The audit reads the real repository, not the test results:
- the cast index (`assets/art/vfx/cast/index.json`: hero packs, `card_casts`, impact packs, travel styles, impact
  styles);
- the floor packs;
- every card's delivery (`cards.json`);
- the hero sprite clips (`art_src/units/*/clips.json`);
- footage captured in the real battle scene.

**What exists today:**

| Layer | Present |
|---|---|
| Hero cast clips | **every hero** has `cast_gesture`; the Knight also has `cast_forward` (Trảm Địa) and `cast_summon` (Ngàn Kiếm) |
| Hero cast packs (hand charge + projectile) | Knight `square_wave_steel`, Mage `fire_bolt_burn` (burst / burn cards only); Assassin, Hunter and Cleric use the default pack |
| Delivery visuals (code-drawn, shared) | `square_streak`, `falling_squares`, `chain_spark`, `floor_run`, `flash`, `charge`, `pit` |
| Impact art packs | only **burn** (`impact_flame_burn`, `impact_flame_small_burn`, `mark_embers_burn`) and the steel / Trảm Địa packs; every other impact type (slash, burst, shatter, freeze, knockback, thorns, poison, guard, seal, curse) is a **code-drawn shard burst** (`impact_style`), the same shape for all cards of that type |
| Card-specific modules | Trảm Địa (front + eruption packs), Ngàn Kiếm (`SkyDropFx`), Hỏa Lôi (`FuseFx`) |

**Status legend:**
- **COMPLETE**: card-specific cast, delivery, impact and ending, approved.
- **PARTIAL**: works and is readable, but uses the shared generic delivery and impact for its type and has no card
  identity.
- **PLACEHOLDER**: data exists but the presentation is generic or does not match the design.
- **MISSING**: no card.

## 2. Inventory of all 60

| # | Card | Owner | Cast | Delivery VFX | Target tiles | Impact | Ending | Status |
|---|---|---|---|---|---|---|---|---|
| 1 | `tram_dia` Trảm Địa | Knight | `cast_forward` ✓ | steel wave flies to the first cell ✓ | ✓ | big eruption on the first cell, then smaller ones cell by cell ✓ | stamps fade ✓ | **COMPLETE per the approved design**, but see the **direction conflict** in §3 |
| 2 | `ngan_kiem` Ngàn Kiếm | Knight | `cast_summon` (raise, hold, pull down) ✓ | distinct swords summoned over each tile, suspended ✓ | ✓ | vertical plunges on the schedule ✓ | swords stuck, then shatter ✓ | **COMPLETE** (approved) |
| 3 | `hoa_loi` Hỏa Lôi | Mage | `cast_gesture` + glyph ✓ | ground seals, 3-2-1 arming ✓ | ✓ | simultaneous ground eruptions ✓ (no sky lightning, nothing anchored on the enemy) | burning ground ✓ | **COMPLETE** (approved; the palm points forward, not down) |
| 4–36 | the 32 existing cards + `vung_lay` | shared / per hero | `cast_gesture` (Knight: sword-wave pack; Mage: fireball pack on burst / burn) | shared code-drawn travel by delivery type | ✓ | shared impact for the type (burn has art; the rest are code-drawn shards) | flash / mark | **PARTIAL** (33 cards; detail below) |
| 37–60 | 24 new cards not built (thien_thach, hoa_tuyen, song_dao, phi_tieu, dau_tu, bay_kep, moc_keo, gai_no, thanh_thuan, chuong_thanh, thien_quang, dia_chan, lien_tram, khien_thep, thuong_xuyen, dap_vo, chuoi_set, loc_cuon, tuong_da, bay_lo, hoi_am, min_tre, bang_vo, hoa_bang) | — | — | — | — | — | — | **MISSING** (no gameplay either) |

**`vung_lay`:** it is in `cards.json` and `card_order` (`implemented: true`), but it was not added in this session.
It uses a generic `floor_run` / `knockback` presentation, while the design calls for mire tiles that seep and dry out.
**Check it before relying on it.**

**The 33 PARTIAL cards, grouped by shared look** (delivery → impact):

| Group | Cards | What they share today |
|---|---|---|
| Sky fall | kiem_vu (slash), hoa_tinh (burn), thien_lang (knockback), han_bang (shatter), thien_hoa (burn) | `falling_squares` + type impact |
| Ground run | xung_kich (knockback), hoa_xa (burn), liet_hoa (burn), ran_kich (shatter), tran_gai (thorns), gai_nguyen (thorns), gai_doc (poison), vung_lay (knockback) | `floor_run` + type impact |
| Chain | dai_dao (slash), song_kiem (slash), bang_chau (freeze), han_phong (freeze), thanh_thuy (freeze), bang_tam (shatter) | `chain_spark` / hero pack + type impact |
| Projectile | kiem_khi (burst), chan_phong (knockback), thiet_kiem (slash), cuong_phong (knockback), kiem_than (slash), han_khi (freeze), han_kiem (freeze), do_kiem (burst) | hero pack / `square_streak` + type impact |
| In place | hoa_tran (burn), bang_phong (freeze), suong_mong (freeze), tu_kiem (slash), ran_van (shatter), han_tran (freeze) | `flash` + type impact |

By impact type: **freeze 8**, slash 6, shatter 4, knockback 5, burn 5 (has art), thorns / poison 3, burst 2. Cards of
the same type and delivery currently look identical. The freeze cards, for example, all end in the same pale-blue
shard burst.

## 3. Trảm Địa — direction conflict

**DECISION (user, 2026-11-09): keep Trảm Địa as it is.** It counts as implemented for the MVP but is NOT artistically
approved in its final choreography. Nothing changes: burst_first ×1.5, Pin 0.4 s, target cell order and combat timing.

**Deferred design issue:** "Desired final choreography: sword wave reaches target, first ground tile erupts,
destructive energy propagates BACKWARD toward the Knight. Current MVP propagates forward. Changing this requires an
explicit gameplay design decision."

### Original analysis

**What the code and footage show:** `tram_dia_bar4_normal_speed.avi` and `tram_dia_direction_2x.png`.
- The Knight stands on column 2. The bar4 field covers (4,1)…(7,1).
- The wave flies to **(4,1), the field cell nearest the Knight**. It bursts there (×1.5, largest eruption, Pin 0.4 s).
- The surge then travels **away from the Knight**: (5,1) at +0.21 s, (6,1) at +0.29 s, (7,1) at +0.37 s, each
  stronger (+15 % per step on a `line_h`).
- The forecast chevrons on the tiles point the same way (→). **Visuals and gameplay agree.**

**Your brief asks for the opposite:** the propagation should run backward, toward the projectile's origin. That is
not possible without changing gameplay. The approved design (`02-skill-bible.md` Trảm Địa, `CastResolver` surge) fixes:
- the landing cell (nearest the caster);
- the order and times of the surge events;
- the per-step damage ramp (more damage further from the Knight);
- the counterplay ("a boss at the far end can step out before the surge arrives").

Reversing it changes which cell bursts, which cells are hit when, the damage ramp, the golden and Trảm Địa tests, and
balance.

**Options:**

| Option | What changes | Cost |
|---|---|---|
| **A (recommended)** Keep the approved gameplay and visuals: the projectile hits the near tile and the eruption **drives forward through the field** | nothing | 0 |
| B Visual only: show a backward ripple | the effect would contradict the authoritative event order (the damage would still move forward). **Not acceptable** under "timing must respect gameplay events" | — |
| C Change gameplay: the projectile flies over the field, lands on the **far** tile (largest eruption), and the surge runs back toward the Knight | the resolver landing cell (first_link → far cell), the surge order, the ramp direction, tests, balance re-check, new footage | about 0.5–1 day plus your re-approval |

## 4. Implementation order (grouped by reusable animation mechanics)

Each group is built once as a code-drawn component, like `FuseFx` / `SkyDropFx` (free, pixel-crisp, tile-centred,
driven by authoritative events). Each card then gets its own composition: colour, shape, size, timing and glyph.

| Step | Reusable component | Cards it upgrades or enables | Needs new gameplay? |
|---|---|---|---|
| 0 | Trảm Địa decision (§3) | tram_dia | only for option C |
| 1 | **Impact-type families** (code-drawn, one per type, with per-card variants): ice burst / crystal (freeze), clean slash arcs (slash), crack and splinter (shatter), shock ring and push streak (knockback), thorn spikes / poison bubbles (thorns, poison), square burst (burst) | all 28 non-burn PARTIAL cards | no |
| 2 | **Hero cast glyph kits** (like Hỏa Lôi's glyph, at the hand during `cast_gesture`): steel sigil (Knight), fire runes (Mage), dagger marks (Assassin), leaf / jade (Hunter), ivory halo (Cleric) | all cast animations | no |
| 3 | **Delivery upgrades**: sky shadow + falling object (reuse `SkyDropFx`), ground ripple of slabs (reuse the Trảm Địa front), chain hop with afterglow, projectile per element | the 33 PARTIAL cards' travel | no |
| 4 | **Combo hits** (multiple strikes on the same tile, numbered) | song_dao, lien_tram | yes (M08 cards) |
| 5 | **Trap objects** (jaws, spring, idle loop, snap) | bay_kep, bay_lo, gai_no | yes (M09) |
| 6 | **Ward frames** (own-half ivory / steel frames) | thanh_thuan, khien_thep | yes (M10) |
| 7 | **Terrain** (pillar rise / sink, ice glaze, mire seep, fire wall) | tuong_da, suong_mong (rework), vung_lay, hoa_tuyen | yes (M11) |
| 8 | **Force move** (pull vortex, push slam + R3 wall flash) | moc_keo, loc_cuon, dia_chan, chan_phong (rework) | yes (M12) |
| 9 | **Echo copy** (translucent mask copy that re-stamps) | hoi_am, chuong_thanh, dau_tu | yes (M14) |
| 10 | **Shockwave / meteor** (growing shadow, crater, rings) | thien_thach, thien_quang | yes (M05) |
| 11 | **Reaction bursts** (steam, shatter-on-pin) | hoa_bang, bang_vo | yes (M15) |
| 12 | Remaining: lance (thuong_xuyen), hammer (dap_vo), chain spark ramp (chuoi_set), delay mine (min_tre, reuse `FuseFx`), dagger fan (phi_tieu) | 5 cards | yes |

Steps 1–3 raise **33 cards** from PARTIAL toward COMPLETE with no gameplay change: the fastest path to visible
completeness. Steps 4–12 need the matching gameplay modules (`15-sprint-60-plan.md` §3), so their animation work
follows each module.

**Estimate (animation and VFX only):**
- steps 1–3: about 4–5 days;
- steps 4–12: about 0.5 day per family + 0.15 day per card, about 6–7 days;
- capture and review: about 0.1 day per card.

That is about **12–14 stream-days** for animation alone, but steps 4–12 also wait for their gameplay modules. The
Nov 22 target for all 60 still needs the parallel streams described in `15-sprint-60-plan.md` §4.

## 5. Quality rules (from the user and the project)

- Crisp pixels, consistent scale, readable at 640×360 and 2× (mobile).
- Muted fantasy palette; enemy red is reserved for enemy telegraphs.
- Effects on real tile centres; floor effects centred in the cell; readable from afar.
- Timing from authoritative events (`cast_scheduled`, `impact_resolved`), never from the clip.
- No paid PixelLab and no external assets without approval.
- Never change damage, targeting, rules or fuse timing to fit a VFX.
