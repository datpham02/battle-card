# Skill v2 — Phase 2: design decisions

**Date:** 2026-11-07 · **Status:** PROPOSED (awaiting user approval) · **Phase:** design only
**Inputs:** `01-current-system-audit.md`, ADR-0001 (D1–D7, A1–A6), `TESSERA_CLAUDE_DESIGN_PACK/tessera_claude_pack`
(01 §1A–§4, 05, `cards.json` 180 entries), `design/quick-specs/nhip-ra-chieu-2026-11-05.md`, `design/game-mechanics.md`.
**Companion docs:** `02-mechanics-catalog.md`, `02-skill-bible.md`, `02-vfx-concepts.md`, `02-implementation-roadmap.md`.

ADR-0001 stays the governing decision. Nothing here replaces the design pack silently: every card in the bible names
the pack entries it comes from (or says it is new), and every deviation is listed in §6 for approval.

---

## 1. Reconciling the 180-card pack, the 34 built cards and the 60-card MVP

### 1.1 What the pack is
180 PROPOSED entries: Attack 40, Block manipulation 35, Status 30, Defense 25, Combo/economy 25, Odd/legendary 25.
Affinity: 90 Neutral, 24 Rogue, 18 Ranger, 17 Knight, 16 Mage, 15 Cleric. 107 have shape rule `any`, 27 `self`.
They were written for the pack's **proposed** energy + card-bar model, which ADR-0001 D1 rejected.

### 1.2 Fit of the pack against D1 (no energy, keep pickup / placement / 4-card menu / min cells + cooldown)

| Pack bucket | Count | Verdict |
|---|---|---|
| Energy / economy cards (`combo_001/002/006/010/014/023/025`, `block_031`, `odd_007`, `status_010`) | 10 | **Incompatible as written.** Rewrite as cooldown refunds or drop. |
| Meta / shop cards (`combo_018–020`) | 3 | **Not cards.** Become relics or shop rules (Expansion). |
| Token / hand manipulation (`block_017/018/021/025/028/029/030/035`, `combo_011/012/017`, `odd_020/022`) | 13 | Our pieces come from the field, not a bar. Mostly **relics / system features**; a few become card effects later. |
| Placement assists (`block_020` Edge Snap, `block_022` Ghost Preview, `block_034` Grid Fit, `def_013` Bridge Sense) | 4 | **UI features, not cards** (the forecast already does part of it). |
| Shape reforging (`block_010–015` Forge, `block_026`, `odd_017`) | 8 | Conflicts with "the shape is what you placed". **Expansion**, as rare rule-breakers at most. |
| Self-grid defense (`def_*`, 25) | 25 | Needs the `ward` self-half placement (rhythm spec). MVP takes 3–4; the rest Expansion. |
| Attack, status, combo, odd that fit D1 | ~117 | Source pool for the MVP and later batches. |

### 1.3 Pack concepts already built (equivalents)

| Pack entry | Built as |
|---|---|
| `atk_001` First Cut | `kiem_khi` Rạch nhẹ |
| `atk_011` Amber Flicker, `status_001` Burn Seed | `hoa_xa`, `hoa_tinh`, `hoa_tran` (burn per cell) |
| `atk_027` Sap Strike, `status_021` Mark Target | `ran_kich` (Rạn = our Mark/Fragile hybrid: next hit ×1.5) |
| `atk_016` Thermal Fracture, `status_013` Cold Shatter, `atk_035` Snare Breaker | crit `target_pinned` on `kiem_vu`, `thiet_kiem`, `chan_phong` |
| `atk_018` Volcanic Ledge | the Knight wave's first-cell burst + spread (visual only today) |
| `atk_037` Rain of Squares | `SEQUENTIAL_CHAIN` delivery (visual only today) |
| `def_004` Guard Counter | `do_kiem` Đỡ Kiếm (parry) |
| `status_018` Mud Step | mire hazard exists (`TileHazards`), no card |
| `atk_020` Cinder Wake, `status_005` Flare Clock | planned `hoa_loi` Hỏa Lôi (delayed), not built |
| Resonant shape (pack §2 shapes) | `FeaturedShape` + arena `featured_bonus` |

### 1.4 Duplicates and near-duplicates inside the pack (merge candidates)

| Mechanic | Pack entries | Proposal |
|---|---|---|
| Straight-line bonus | `atk_003`, `atk_013`, `atk_032`, `atk_038` | one shared line card (`thuong_xuyen`) + line clauses on existing cards |
| Mark then consume | `atk_021`, `atk_033`, `status_021`, `status_022`, `status_024` | reuse **Rạn** as the mark; one Assassin card (`dau_tu`) |
| Echo / repeat at 50 % | `atk_028`, `status_028`, `block_027`, `odd_011`, `odd_015`, `combo_003`, `combo_015` | one echo mechanic (M14), two cards in MVP |
| Burn → extra hit | `atk_015`, `status_002`, `atk_019` | covered by the Steam reaction + Mage detonation |
| Frozen payoff | `atk_016`, `status_012`, `status_013` | reaction R2 Vỡ Băng + card `bang_vo` |
| Guard self-buff | `def_001`, `def_016`, `status_020`, `atk_039` | one ward card per hero family |
| Short dodge / step | `def_003`, `def_006`, `def_008`, `def_009`, `def_022` | movement is the joystick; **not cards** (Expansion relic at most) |
| Trap variants | `atk_029`, `atk_034`, `status_017`, `status_019`, `def_010`, `def_015`, `odd_006` | trap mechanic (M09) + 3 MVP cards |

### 1.5 Planned mechanics in the pack that the game lacks
Delayed (fuse), multi-hit combo, trap, ward / self-grid, echo, chain order rules, Mark (we have Rạn), Poison, Root and
Slow on player cards, Guard for the player, guard-break, terrain creation by the player, split / merge / mirror of
shapes, 6–7-cell regular pieces, rule-breaking legendaries.

### 1.6 Playable cards vs curses
- **Playable:** 32 player cards in `cards.json` today (31 shared + `do_kiem`).
- **Curses:** `ganh_nang`, `oan_hon` — rarity `curse`, never in pools, not counted in any roster number below.
- **Not implemented:** the three wall cards (removed 2026-10-31). Not counted.

### 1.7 Decision proposed: **60 playable MVP cards = 32 existing (4 reworked) + 28 new**
- Matches ADR-0001 D2's number (60) and replaces the earlier "34 + 34" idea, which would have given 68 and kept six
  near-duplicates. The 34 new ideas discussed before are folded in: 28 make the MVP and the rest go to Expansion.
- **No card id is removed**, so saves and decks need no migration. The 4 reworks keep their ids and get a new rule
  (`chan_phong`, `suong_mong`, `kiem_than`, `ran_van`).
- The other 28 existing cards get **light v2 clauses** (a shape bonus, a resolve rule from their delivery, or a crit
  condition) without changing their role.
- Split of the 60 (pack §4 targets ~55 % shared / 25 % hero / 20 % unlockable):

| Group | Cards | Share |
|---|---|---|
| Shared, open | 33 | 55 % |
| Hero-only (3 per hero) | 15 | 25 % |
| Shared, unlockable (achievements) | 12 | 20 % |

- **Expansion roadmap** (after MVP playtests): batches of 10–12 from the pack's remaining fitting entries plus the
  Expansion list in the bible (summons, conduction, swap, poison family, odd 6–7 legendaries), each batch with its
  own sim pass.
- **Experimental** (only with a prototype first): portal fold, time fold, shape reforging, split / merge of pieces.

## 2. Core rules decided in this phase (proposed)

1. **Shape, delivery and impact stay separate** (pack §1A). A card may add a *shape clause*; delivery may add a
   *resolve rule*; impact stays the per-cell visual.
2. **Shape tags are computed from the physical cells** of each placed piece (never from effective cells such as
   Trảm's ×2). See mechanics M16.
3. **Shape clause ≠ Resonance.** Resonance (Featured Shape) stays an arena puzzle: exactly two pieces whose union is
   the arena's 5–7-cell shape, numeric ×1.5 + the arena effect. A shape clause is a card rule that changes behaviour
   (pierce, ring, branch, extra echo), checked per piece by default. Both may apply. Caps: see §10 (shape-clause
   group ×2.0 only; existing multipliers and the relic ×3 cap unchanged).
4. **Authoritative impact schedule.** Every cast produces timed impact events; gameplay resolves events, VFX follows
   them. A `direct` card with no new fields produces one event at the swing end and behaves exactly as today
   (back-compat golden test).
5. **One hit per unit per wave.** A multi-cell boss covered by several cells of one wave takes one hit. Extra hits
   come only from explicit multi-hit rules (combo hits, echo waves, chain links that land after the unit moved,
   separate sky drops), each capped per card.
6. **Path damage only if telegraphed.** Travel never damages outside the mask unless the card has a `path_rule` that
   draws those cells on the floor first (existing dormant gate).
7. **Delivery gets real rules only on cards that opt in** (`resolve: "arrival"`). All 32 existing cards stay instant
   through B1–B6; the changes listed for them are intentional behaviour changes enabled per card in B7 (§8 and the
   bible's migration table).
8. **No energy, no new resource.** Combo points, marks and echo charges are status / zone state with caps.
9. **Hero cards appear in rewards for their hero only** (today `RewardRoller` skips them for everyone).
10. **Regular pieces stay 1–5 cells**; 6–7 cells remain Odd blocks. Raising `PieceLibrary.MAX_CELLS` is Expansion.

## 3. Hero identities (summary; full kits in the bible)

| Hero | Identity | Hero cards (MVP) | Planned card used |
|---|---|---|---|
| Kiếm sĩ | Reads telegraphs, answers with steel; lines and pins | `do_kiem`, `tram_dia`, `ngan_kiem` | Đỡ Kiếm (built) |
| Pháp sư | Places fire where the boss will be; detonates | `hoa_loi`, `thien_thach`, `hoa_tuyen` | Hỏa Lôi as specified |
| Sát thủ | Small fast shapes, many hits, marks and executions | `song_dao`, `phi_tieu`, `dau_tu` | Song Đao as specified |
| Thợ săn | Owns the ground: traps, thorns, pulls into them | `bay_kep`, `moc_keo`, `gai_no` | Bẫy Kẹp as specified |
| Giáo sĩ | Holds own ground, builds Hàn, echoes light | `thanh_thuan`, `chuong_thanh`, `thien_quang` | Thánh Thuẫn as specified |

The four planned cards are kept with their spec numbers as starting values; the bible adds shape clauses and VFX.

## 4. Status reactions (summary; rules in the catalog M15)
MVP: **R1 Hơi Nước** (Burn cell + Hàn), **R2 Vỡ Băng** (Pinned + Rạn), **R3 Va Đập** (push blocked / into thorns).
Expansion: **R4 Dẫn Điện** (lightning + charged tiles) — needs a new element and tile mark.
Anti-loop: reaction events cannot trigger reactions, echoes, relic `on_cast` hooks or Awakening charge; per-unit
internal cooldown; priority R2 > R1 > R3; one reaction per event.

## 5. Risks
- **Resolver refactor** (per-cell schedule) touches `SwingArbiter` / `CutEffects`, the most tested code. Mitigation:
  golden back-compat test over all 32 cards before any new card lands.
- **Multi-hit vs flat defense:** each hit pays defense; combo cards will underperform on armoured enemies (intended
  counterplay, but tune with the sim).
- **Boss AI:** new floor objects (fuses, traps, pillars, mire) need path costs in `BossBrain` and `PatternController`
  or bosses walk into everything. Every new zone kind ships with its brain cost.
- **Readability on a phone:** more floor marks at once. Rule: one zone per cell, one icon per cell, centred.
- **Sim parity:** `sim_core.cast_value` re-implements damage; it must call the real resolver before tuning.
- **Uncommitted Mage work:** the fireball pack (`fire_bolt_burn`, `unit_impacts`, `travel_impact_packs`, overlay
  colour change, `square_fireball` component) is in the working tree. Phase 3 must commit or shelve it first and must
  not reset or overwrite it.

## 6. Final decision matrix (revision 2, after the user's Phase 2 review, 2026-11-07)

| # | Question | Status | Final proposed resolution |
|---|---|---|---|
| Q1 | MVP 60 = 32 existing ids + 28 new | **Approved** | as §1.7; 12 Expansion + 5 Experimental kept for later |
| Q2 | 4 reworks keep their ids | **Approved** | `chan_phong`, `suong_mong`, `kiem_than`, `ran_van` (migration table, bible §8) |
| Q3 | Hero cards only in their hero's rewards | **Approved** | 3 per hero, 15 total |
| Q4 | Rạn as the generic mark | **Approved with conditions** | §7: Rạn stays the generic fragile / mark; **Dấu Tử is a separate timed card effect**; rules for Rạn and multi-hit below |
| Q5 | Poison family → Expansion | **Approved** | — |
| Q6 | Resolve timing of existing cards | **Revised** | §8: every existing card stays **instant** through B1–B6 (golden baseline). Each listed timing / clause change is an **intentional behaviour change**, enabled per card in B7 with its own regression tests (bible §8 migration table). None is described as unchanged. |
| Q7 | Shape tags mirror-invariant | **Approved** | — |
| Q8 | Regular pieces ≤ 5 cells | **Approved** | — |
| Q9 | Working names | **Approved** | names may still change per card |
| Q10 | Rạch nhẹ out of the starters | **Revised, pending validation** | §9: `kiem_khi` stays the **internal fallback** (`cards.json default_card`), outside the starters; starters validated per hero; add a short no-option auto-cast (0.5 s) so a dead menu never waits 3 s. Final only after the B1 fallback tests pass. |
| Q11 | Reactions R1–R3 in MVP, R4 later | **Approved** | — |
| Q12 | Multiplier cap | **Approved with conditions → revised** | §10: **no global ×3 cap.** Existing chain (Rạn, crit, Resonance, relics with their existing ×3 relic cap, execute, passives, Awakenings) unchanged. New **shape-clause group** capped at ×2.0, additive dpc clauses capped at +3. Worked examples in §10. |
| Q13 | Self-half ward placement | **Revised** | §11: **Option A2** — place on the enemy half as usual; choosing a ward card **re-anchors** the placed shape onto the hero's own half around the hero's cell (previewed when the card is highlighted). No new placement mode; ward cards never become dead after placement. |

## 7. Q4 — Rạn and Dấu Tử

- **Rạn** (existing): per-side stacks ≤ 3; each damage or push **event** consumes one stack for ×`fragile_mult` (1.5).
  It remains the only generic fragile / mark status in MVP.
- **Dấu Tử** (new, card-specific): a timed target status `death_mark {left 3 s (5 s with mono), echo_mult 0.6,
  execute_ratio 0.30}`. It is **not** a Rạn stack and is never consumed by Rạn logic.
- **Trigger:** the first damaging **cast** (not hit) on the marked target after the mark was applied. Dấu Tử's own hit
  never consumes the mark it applies. Re-casting refreshes the duration; no stacking.
- **Effect:** that cast resolves normally; 0.6 s after its last event, **one echo wave** of that cast (same mask)
  resolves at ×0.6; the mark is then removed. The cast's hits execute ×2 when the target is at or under 30 % HP.
- **With Rạn:** parent hits consume Rạn normally (one stack per damage event). The echo is tagged `echo`: it neither
  consumes Rạn nor receives the Rạn multiplier, so a stack is never spent twice.
- **With multi-hit (combo):** the mark triggers once per cast. The echo repeats **one** wave (the cast's last hit) at
  ×0.6. `combo_3` crit and execute never apply to the echo.
- **With other echoes** (Chuông Thánh, Hồi Âm): the mark adds +1 echo wave; a cast never exceeds 3 echo waves.
- **Snapshots:** the echo uses the parent's cast-time modifiers (Bóng Lướt active at cast → ×1.75 on the echo too;
  activating it after does not count). Echoes never charge Engraving or the Awakening.

### 7.1 Addendum (batch 5, 2026-11-11) — echo waves and Rạn, measured

`tools/balance/echo_ran_probe.gd` compared the shipped rule **A** (an echo wave neither spends Rạn nor takes the ×1.5)
with the looser reading **B** (an echo wave is a damage event like any other) on a 1000 HP boss, bar3 casts:

| Case | Rạn before | A total | B total | B / A | stacks left A / B |
|---|---|---|---|---|---|
| Hồi Âm (hit + echo 0.6) | 0 / 1 / 3 | 24.0 / 31.5 / 31.5 | 24.0 / 31.5 / 36.0 | 1.00 / 1.00 / 1.14 | 0 / 0 / 2 vs 0 / 0 / 1 |
| Chuông Thánh (hit + 2 echoes 0.5) | 0 / 1 / 3 | 48.0 / 54.0 / 54.0 | 48.0 / 54.0 / 60.0 | 1.00 / 1.00 / 1.11 | 0 / 0 / 2 vs 0 / 0 / 0 |
| Kiếm Khí on a marked boss (hit + mark echo 0.6) | 0 / 1 / 3 | 28.8 / 37.8 / 37.8 | 28.8 / 37.8 / 43.2 | 1.00 / 1.00 / 1.14 | 0 / 0 / 2 vs 0 / 0 / 1 |

With 0 or 1 stack the readings are identical; only a 2+ stack bank differs, by 11–14 % of the cast, and B eats the
bank (Chuông Thánh spends all three in one cast). **Rule A stays.** An echo repeats the base hit; the stacks stay for
the next cast, so Rạn remains a per-cast resource the player spends on purpose rather than a bank an echoing card
drains by itself. The signature snapshot of the "Snapshots" bullet is implemented (`SwingArbiter` `sig_factor`,
`swing_arbiter_signature_snapshot_test.gd`); reactions (R1–R3) do fire on echo waves like on any damage event, gated by
the M15 ICD (batch 5, `22-deferred-report.md`).

## 8. Q6 — legacy behaviour changes
Through B1–B6 every one of the 32 existing cards resolves exactly as today (all cells at the swing end, one hit test).
The golden test pins this. In B7, each change in the bible §8 migration table is turned on card by card (data flag
`resolve` / clause fields), with that card's golden expectations updated in the same commit and the listed regression
tests added. A card whose migration fails its sim band is reverted to instant.

## 9. Q10 — fallback safety and starter validation

**Code today (verified):** `CutFlow.tick_real` at timeout casts a random available hand card; with none, it casts
`default_card` (`kiem_khi`) **whether or not the deck holds it**, then `SkillConfig.FALLBACK_SKILL`. `kiem_khi` has
min 1 cell, cooldown 0, no telegraph condition, so it is always castable on any valid placement.

**Proposal:**
1. Keep `kiem_khi` as `default_card` (internal fallback). It leaves the starters (the hero's first card takes its slot).
2. **No-option auto-cast:** when the drawn hand has no available card for the placed cells, the menu shows the 4 cards
   greyed and casts the fallback after `menu_no_option_sec` 0.5 s (data), labelled "Rạch nhẹ". This replaces a dead
   3 s wait. (Behaviour change, approved per this decision.)
3. Ward cards (Q13) are always available after any enemy-half placement with enough cells, so placement never makes
   the whole hand dead by itself.

**Starter validation** (playable starter cards by placed cell count, cooldowns ignored; F = fallback only):

| Hero (starter v2) | 1 cell | 2 cells | 3 cells | 4–5 cells |
|---|---|---|---|---|
| Kiếm sĩ: do_kiem, tram_dia, kiem_vu ×2, thiet_kiem, chan_phong | do_kiem *(only during an enemy telegraph)*, else F | kiem_vu (+do_kiem) | + tram_dia, thiet_kiem, chan_phong | same |
| Pháp sư: hoa_loi, hoa_xa, hoa_tinh ×2, hoa_tran, bang_phong | F | hoa_loi, hoa_xa | + hoa_tinh | + hoa_tran, bang_phong |
| Sát thủ: song_dao, lien_tram, kiem_vu, thiet_kiem, bang_chau, han_kiem | song_dao | + lien_tram, kiem_vu | + thiet_kiem, bang_chau, han_kiem | same |
| Thợ săn: bay_kep, tran_gai ×2, gai_doc, ran_kich, dia_chan | F | bay_kep | + tran_gai, gai_doc, ran_kich, dia_chan | same |
| Giáo sĩ: thanh_thuan, han_khi ×2, han_kiem ×2, thanh_thuy | F | thanh_thuan *(ward, A2)*, han_khi | + han_kiem, thanh_thuy | same |

- **All cooldowns running** (worst case after several casts): every hero falls back to `kiem_khi` (cd 0) → the cast
  always completes.
- **Hand of 4 drawn from 6**: at 3+ cells every hero has ≥ 3 distinct playable cards, so a drawn hand of 4 always
  holds ≥ 1 playable card unless they are all on cooldown.
- **1-cell casts**: today `kiem_khi` is in every starter (1–2 copies), so a 1-cell cast picks it only when it is drawn
  (≈ 67 % with one copy). v2 casts the same card through the fallback every time → same damage, faster with the 0.5 s
  auto-cast. Knight / Assassin also gain 1-cell options (Đỡ Kiếm during telegraphs, Song Đao).
- The B1 tests below must pass before Q10 is final.

## 10. Q12 — multiplier groups and worked examples

**Order (unchanged) in `CutEffects.apply`:** base `dpc × effective_cells` → bonus vs Rạn → pinned (1.0) → consume Rạn
(×1.5) → crit → Resonance `damage_mult` → relic fold (**existing cap ×3, unchanged**) → execute ×2 → passive →
Awakening → defense (flat, floor 1).

**New in v2:** one **shape-clause group** S = product of the card's v2 clause multipliers (burst-first, surge, ramp,
centre, T-stem…) **capped at ×2.0**, applied right after crit; additive dpc clauses (Lia ngang +1, Thương Xuyên +1/cell)
capped at **+3 dpc** and added to the base. Nothing else is capped or changed. Effective cells (Trảm ×2) never change
shape tags.

| # | Case | Before (today) | After (v2) |
|---|---|---|---|
| E1 | Rạch nhẹ, 3 cells, no modifiers | 6 × 3 = **18** | **18** (no clause) |
| E2 | Lia ngang, `bar3` horizontal, target pinned (crit ×1.5) with 1 Rạn | 7 × 3 = 21 × 1.5 × 1.5 = **47.25** | B1–B6: **47.25**; after its B7 migration (+1 dpc on `line_h`): 8 × 3 × 1.5 × 1.5 = **54** |
| E3 | Lia ngang under Vung Hết Sức (cells ×2) | 7 × 6 = **42** | B7: 8 × 6 = **48** (tags from the 3 physical cells) |
| E4 | Trảm Địa (new), `bar4` horizontal, boss on the far cell, 1 Rạn | — | 6 × 4 = 24 × S 1.45 (surge 3 cells) × 1.5 = **52.2** |
| E5 | Trảm Địa, boss on the first cell, 1 Rạn | — | 24 × S 1.5 (burst) × 1.5 = **54**, + Pin 0.4 s |
| E6 | Thiên Thạch (new), `plus5`, centre hit, 1 Rạn, relic Huyết Ấn (5+ cells ×1.3) | — | 7 × 5 = 35 × S 2.0 × 1.5 × 1.3 = **136.5** (S at its cap) |
| E7 | Same as E6 if a future clause pushed S to ×3.0 | — | S capped at 2.0 → still **136.5** |
| E8 | Song Đao (new), `mono` → 4 hits, Nhát Gọn ×1.4, boss defense 2 | — | hits 1–2: 3 × 1.4 − 2 = 2.2 each; hits 3–4 (`combo_3` ×2): 8.4 − 2 = 6.4 each → **17.2** total (defense 0: **25.2**) |
| E9 | Đòn Resonance today: two pieces = arena shape, Rạn, relic An Chú (featured ×2) | dpc × cells × 1.5 × 2 (An Chú replaces the ×1.5) — unchanged | **unchanged** |

## 11. Q13 — ward targeting

| | A1 mirror across the divider | **A2 re-anchor on the hero (recommended)** | B self-half placement first |
|---|---|---|---|
| Flow | place on the enemy half → pick a ward → the shape is mirrored to the same rows on the own half | place on the enemy half → pick a ward → the shape (mirrored to face the hero's side) is moved so its centre cell sits on the **hero's cell** | drag the piece onto the own half → menu shows ward cards only |
| Touch | unchanged | unchanged | new drop zone; easy to drop on the wrong half |
| Preview | ghost on own half when a ward card is highlighted | ghost around the hero when a ward card is highlighted | direct |
| Usefulness | the ward may land far from the hero | **the ward is where the hero stands** | exact |
| Deck / dead menus | none | none | a self placement with no ward card drawn → dead menu → needs a self fallback card and draw rules |
| Timing | same 4 s clock | same | same |
| Complexity | low | low–medium (translate + clip) | high (placement mode, menu filtering, fallback) |

**A2 rules:** remap at choose time (the hero's cell then); cells off the own half, missing cells and locked cells are
trimmed; if every cell is trimmed the ward card shows "cần ô" greyed (rare: only on tiny broken boards). The enemy-half
cells of that cast are **not** hit and do not light Engraving. The 4-card menu, min cells and cooldown rules are
unchanged.

**Example flows (A2):**
1. Cleric places `square` on the enemy half → menu: Thánh Thuẫn (2+ cells) is available → the player highlights it → a
   pale ivory 2×2 ghost appears around the Cleric → tap → the four own-half cells become wards.
2. Same, but the Cleric stands in a corner → two cells fall off the grid → the ward covers the two valid cells.
3. Knight places `bar3` → menu draws Khiên Thép and two attacks → picking Khiên Thép puts a vertical 3-cell steel
   ward through the Knight's cell (the bar mirrored) → the enemy is not hit this cast.

## 12. Uncommitted Mage work — checkpoint strategy (nothing done yet)

**Inventory (git diff, 2026-11-07):**
- 10 modified files (+196 / −28):
  - `assets/art/vfx/cast/index.json`
  - `assets/art/vfx/floor/index.json`
  - `src/art/cast_vfx.gd`
  - `src/battle/overlay_layer.gd`
  - `src/battle/unit_layer.gd`
  - `src/combat/combat_view.gd`
  - `tests/unit/art/cast_vfx_test.gd`
  - `tests/unit/art/floor_vfx_test.gd`
  - `tools/fx-pipeline/components/__init__.py`
  - `tools/fx-pipeline/components/fire.py`
- New packs and their `.import` files:
  - `assets/art/vfx/cast/charge_flame_burn/`
  - `assets/art/vfx/cast/travel_fireball_burn/`
  - `assets/art/vfx/floor/impact_flame_small_burn{,_c43x31}/`
- New recipe: `tools/fx-pipeline/recipes/phap_su_hoa_cau.fx.json`.
- Build candidates under `design/assets/candidates/fx-pipeline/`.
- Evidence:
  - `production/qa/evidence/fx-pipeline/phap_su_hoa_cau/`
  - `production/qa/evidence/mage-cast/`
- `src/dev/demo_args.gd` shows only a line-ending difference (not this work; leave it).

**Options:**

| Option | How | Risk |
|---|---|---|
| **1. Dedicated commit on `main` (recommended)** | run the full suite first (the last full run predates the ice-card fix), stage exactly the files above by path, one commit | none to the work; needs your "commit" |
| 2. Branch checkpoint | `git switch -c wip/mage-fireball`, commit there, return to `main`, merge later | B1 would start on `main` without the Mage work, then conflict in `combat_view.gd` / `overlay_layer.gd` |
| 3. `git stash -u` | stash everything | untracked packs and evidence are easy to lose; not recommended |

Nothing is reset, discarded, regenerated or committed until you say so.

## 13. Acceptance criteria (Phase 3 gates)

**Fallback safety**
- [ ] With every hand card unavailable (cooldown, `need_cells`, parry without telegraph), the cast completes with
  `kiem_khi` for 1-cell, 2-cell and 5-cell placements, for each of the 5 starters (test per hero).
- [ ] `kiem_khi` is cast even when no deck holds it; `FALLBACK_SKILL` path still covered.
- [ ] No-option auto-cast fires at 0.5 s; a hand with ≥ 1 available card never auto-casts early.
- [ ] Bot matrix: 0 "stuck menu" events across 40 seeds × 5 heroes.

**Ward targeting (A2)**
- [ ] A ward card is available after any enemy-half placement meeting its min cells.
- [ ] Remap centres on the hero's cell at choose time; trims off-grid / missing / locked cells; never touches the enemy
  half; the enemy is not hit and Engraving is not lit by that cast.
- [ ] Highlighting a ward card shows the own-half ghost before the tap; un-highlighting removes it.
- [ ] Menu, min cells and cooldown behaviour for non-ward cards are unchanged (golden test).

**Legacy-card behaviour changes**
- [ ] Golden test pins all 32 cards' events (cells, times, damage, statuses, zones) on fixed boards before B1 code.
- [ ] B1–B6 keep the golden test green with no expectation edits.
- [ ] Each B7 migration changes only its own card's expectations, adds the listed regression tests, and passes its sim
  band (else reverted).

**Multiplier caps**
- [ ] E1–E9 reproduced as unit tests.
- [ ] Relic fold cap stays ×3 and independent; Resonance, execute, passives and Awakenings unchanged.
- [ ] Shape-clause group capped at ×2.0; additive dpc clauses capped at +3; tags ignore effective cells.

**Zone replacement** (rules in the mechanics catalog §G)
- [ ] One zone per cell holds for every new kind; locked cells refuse all.
- [ ] Replacing a fuse or trap cancels its trigger with a fizzle visual and no damage; armed-zone protection holds
  against the player's own zones.
- [ ] Mage, Hunter and Cleric combo checks: a fire wall next to a fuse keeps both; Gai Nổ consumes thorns and traps;
  a ward survives the player's own zones on the enemy half (different halves).
- [ ] Old zone visuals are removed on replacement (no overlapping zone sprites).

**Visual readability**
- [ ] Each pilot skill passes an in-game check at 1× (1280×720) and on a phone-size viewport: every beat (cast,
  delivery, impact, aftermath) identifiable in a frame strip by someone who did not build it.
- [ ] Telegraphs tile-exact on the floor layer, never `#E5293B`; floor effects centred; labels unboxed.
- [ ] No two MVP cards share all of delivery motion, impact silhouette and aftermath.
- [ ] No PixelLab clip is generated before the fxkit version of that skill passed this check.

**Backward compatibility**
- [ ] Saves with existing decks load unchanged (no id removed or renamed).
- [ ] Boss card use (`boss_card_order`) unchanged for existing cards.
- [ ] Full suite green and bot matrix 0 violations after every batch.
- [ ] The Mage fireball work is preserved (checkpoint first; none of its files reset or regenerated).
