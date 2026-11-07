# Skill v2 — Phase 2: skill bible (proposed roster)

**Date:** 2026-11-07 · **Status:** PROPOSED · design only.
All numbers are **starting values for the balance sim**, not final. Names are working names (Q9).
Mechanic ids (M01…, R1…) refer to `02-mechanics-catalog.md`; VFX module ids (V…) to `02-vfx-concepts.md`.

**Roster:** 60 playable MVP cards = 32 existing (4 reworked) + 28 new. Curses (`ganh_nang`, `oan_hon`) are separate
and unchanged. Then an Expansion list (12) and an Experimental list (5).

| | Shared open | Hero-only | Shared unlockable | Total |
|---|---|---|---|---|
| Existing | 27 | 1 (`do_kiem`) | 4 | 32 |
| New | 6 | 14 | 8 | 28 |
| **MVP** | **33** | **15** | **12** | **60** |

Complexity: **S** data + existing code · **M** one new rule on a built mechanic · **H** a new mechanic.

Entry format: owner · rarity · role | min cells · shapes | damage · cooldown | mode · delivery · impact timing.

---

## 1. Hero cards (15)

### Kiếm sĩ — "read the telegraph, answer with steel"
Passive Lấy Lại Sức, Awakening Vung Hết Sức (cells ×2, lifesteal). Identity: parry → Pin → crits on pinned; long
straight lines toward the boss. Combos: Đỡ Kiếm pins → Xé toạc / Lia ngang crit; Trảm Địa's burst pins; Hích Tường
slams into Tường Đá pillars (R3).

#### `do_kiem` — Đỡ Kiếm *(built, keep)*
Hero · common · counter | 1 · any | dpc 3 · cd 6 | parry · caster→target · instant.
- **v2 clause:** a `line_v` piece (a vertical bar, a raised shield) → guard window +0.2 s.
- Everything else as built (`ParryGuard`). VFX: keep the steel release; add the **ĐỠ** flash (V12).

#### `tram_dia` — Trảm Địa (Earth-Splitting Wave) · *new*
Hero Knight · rare · finisher on lines | 3 · any (best `line_h`) | dpc 6 · cd 6 | direct · CASTER_TO_TARGET · arrival.
- **Effect:** a sword wave flies to the first mask cell and **bursts** there (×1.5 if the boss stands on it, Pin
  0.4 s), then surges cell to cell through the rest of the mask (M03 `burst_first`).
- **Shape clause:** a `line_h` piece turns the spread into a straight surge: each cell it travels before reaching the
  boss adds +15 % (cap +45 %).
- **Status / reactions:** the burst Pin sets up `target_pinned` crits and R2 Vỡ Băng with Rạn.
- **Combos:** Đỡ Kiếm → Trảm Địa (pinned burst crit); Hích Tường slam afterwards.
- **Counterplay:** a boss at the far end of a long mask can step out before the surge arrives.
- **Cast:** the Knight lowers the blade, then drags it up and forward in one rising cut.
- **Delivery:** a stepped steel wave skims the floor toward the first cell.
- **Impact:** a large square burst on the first cell, then smaller bursts cell by cell; a crack line of square
  shards follows the surge.
- **Aftermath:** steel stamps fade on each cell; square shards settle and vanish.
- **Engine:** M01, M02, M03, M16. **Complexity:** M. **Source:** pack `atk_003` + `atk_018`; user example.

#### `ngan_kiem` — Ngàn Kiếm (Thousand Blades) · *new*
Hero Knight · epic · zone denial | 4 · any (best `T`, `plus`) | 12 per blade hit · cd 10 | direct · SKY_TO_TARGET ·
per-drop.
- **Effect:** a blade appears point-down above **each** mask cell (0.5 s shadow telegraph), then they drop one by one
  from the centre outward, 0.12 s apart. Each drop hits the unit on its cell; a unit can be hit up to **3 times** if
  it stays or moves inside the mask (M05 `max_hits` 3). Per-hit damage is fixed, not × cells.
- **Shape clause:** `branched` (T, plus, Y) → the branch tips fall first and the centre last at ×1.5 (closing pincer).
- **Status / reactions:** with Pin (Đỡ Kiếm, Bẫy Kẹp) all 3 hits land; Awakening Trảm adds +1 max hit (cells ×2
  does not apply to fixed hits).
- **Counterplay:** leave the mask during the 0.5 s hover; hits are capped.
- **Cast:** the Knight raises the sword overhead and holds it up while the blades appear.
- **Delivery:** steel blades fade in above the cells, hang, tremble, then drop in sequence.
- **Impact:** each blade stabs into its slab with a sharp square splash.
- **Aftermath:** the blades stay stuck in the floor for 0.6 s, then crumble into squares.
- **Engine:** M02, M05 (multi-drop, `max_hits`), M06 `from_centre`, M16. **Complexity:** M–H. **Source:** user
  example ("multiple blades appear above the battlefield"); pack `atk_005`.

### Pháp sư — "place fire where the boss will be, then detonate"
Passive Tay Vững (≥ 4 cells swing ×0.75), Awakening Bùng Nổ (detonate burns ×2, reset burn cards, ignite Engraving).
Identity: delayed fuses, burning terrain that herds the boss, detonation. Combos: Hỏa Tuyến walls → boss pushed onto
Hỏa Lôi fuses → Bùng Nổ; Hàn from any card → R1 Hơi Nước on burning cells.

#### `hoa_loi` — Hỏa Lôi (Fire Mine) · *new, as specified in the rhythm spec*
Hero Mage · common · setup | 2 · any (best `square`) | dpc 6 · cd 5 | delayed · DIRECT_MANIFESTATION · fuse 1.5 s.
- **Effect:** mask cells become fuse cells (3-2-1 countdown). At the end, a unit on a fuse cell takes
  `dpc × cells × 2.0` and the cells burn as Tia lửa. Empty cells: nothing but the burn.
- **Shape clause:** `square` → a heavy charge: fuse 1.8 s, ×2.5.
- **Status / reactions:** crit `target_burning` ×1.5; burning cells feed R1 and Bùng Nổ.
- **Combos:** Hỏa Tuyến / Tường Đá / Vũng Lầy herd or slow the boss onto fuses.
- **Counterplay:** the boss brain sees fuses as an incoming swing and steps off.
- **Cast:** the Mage taps the open book, then flicks the palm down at the floor.
- **Delivery:** a charcoal sigil burns into each target slab (no projectile).
- **Impact:** at zero the sigils collapse inward, then erupt as stepped flame columns.
- **Aftermath:** cells keep burning (existing burning-cell pack) with ember marks.
- **Engine:** M07 (zone `fuse`, brain cost), M19 `target_burning`. **Complexity:** M. **Source:** rhythm spec; pack
  `atk_020`, `status_005`.

#### `thien_thach` — Thiên Thạch (Meteor) · *new*
Hero Mage · epic · burst | 4 · any (best `plus`, `square`) | dpc 7 · cd 9 | direct · SKY_TO_TARGET shockwave · 0.6 s.
- **Effect:** a meteor falls on the **centre** cell (growing shadow, 0.6 s); the centre is hit ×1.5, then a
  shockwave reaches the other mask cells ring by ring (0.1 s per ring). All mask cells burn 2 s.
- **Shape clause:** `plus` → every arm is reached at once and the centre is ×2; `square` → the meteor lands on the
  shared corner and all four cells are the centre.
- **Status / reactions:** burning cells for R1 and Bùng Nổ; Tay Vững shortens the swing on 4+ cells.
- **Combos:** Tường Đá pillars keep the boss near the centre; Lốc Cuốn pulls it in.
- **Counterplay:** read the shadow; the ring reaches the outer cells late.
- **Cast:** the Mage raises the book high, the free hand pointing straight up.
- **Delivery:** a burning block of squares falls with a stepped trail; its shadow grows on the centre slab.
- **Impact:** a heavy square crater burst on the centre, then a ring of square shards rolling outward across the mask.
- **Aftermath:** a cracked crater frame on the centre slab (1 s), burning cells around it.
- **Engine:** M05 shockwave, M16 centre. **Complexity:** M. **Source:** user example (meteor + outward shockwave);
  pack `atk_008`.

#### `hoa_tuyen` — Hỏa Tuyến (Fire Line) · *new*
Hero Mage · rare · terrain / herding | 3 · any (best `line`) | dpc 4 · cd 8 | direct · GROUND_PROPAGATION · arrival.
- **Effect:** fire runs along the floor from the mask cell nearest the hero through the mask (stopped by holes), hits
  and burns the cells 3 s.
- **Shape clause:** a `line` piece's cells become a **fire wall** for 3 s: burning cells that block the boss's
  movement (M11, always leaving an exit).
- **Status / reactions:** R1 with Hàn; Bùng Nổ detonates the wall.
- **Combos:** walls steer the boss onto Hỏa Lôi fuses or under Thiên Thạch.
- **Counterplay:** the boss walks around the wall; walls never seal it in.
- **Cast:** the Mage sweeps the palm low, left to right, as if drawing a line on the floor.
- **Delivery:** a stepped flame front runs slab to slab along the floor.
- **Impact:** each reached cell flares with a small stepped flame.
- **Aftermath:** wall cells keep tall, flickering flame columns (taller than normal burning cells), then sink.
- **Engine:** M04, M11 (burning blocks boss), `fit_cells`. **Complexity:** M. **Source:** pack `atk_013`.

### Sát thủ — "small shapes, many hits, marks and executions"
Passive Nhát Gọn (≤ 4 cells ×1.4), Awakening Bóng Lướt (free steps, ≤ 3 cells ×1.75). Identity: combos, marks that
echo, executions. Combos: Song Đao 3rd-hit crits; Dấu Tử echoes the next big hit; Phi Tiêu applies Rạn on the corner.

#### `song_dao` — Song Đao (Twin Blades) · *new, as specified*
Hero Assassin · common · sustained damage | 1 · any (best `mono`, `domino`) | dpc 3 × 3 hits · cd 3 | combo ·
DIRECT_MANIFESTATION · 3 hits, 0.12 s apart.
- **Effect:** three full hits on the same cells; crit `combo_3` ×2.0 on the 3rd.
- **Shape clause:** `mono` or a 2-cell `line` → 4 hits.
- **Status / reactions:** each hit consumes one Rạn; each hit pays defense.
- **Combos:** Nhát Gọn ×1.4 on every hit; Bóng Lướt ×1.75; Dấu Tử echoes it.
- **Counterplay:** Guard and defense shave every hit; leaving after the first hit.
- **Cast:** a quick cross-slash, then two snaps back and forth with both daggers.
- **Delivery:** none (in place): the slashes appear on the cells.
- **Impact:** X-shaped square slash marks, the third larger and white-hot; stacked damage numbers.
- **Aftermath:** thin X scars on the slab for 0.4 s.
- **Engine:** M02 waves, M08, M19 `combo_3`. **Complexity:** M. **Source:** rhythm spec; pack `atk_002`, `atk_026`.

#### `phi_tieu` — Phi Tiêu Liên Hoàn (Dagger Fan) · *new*
Hero Assassin · rare · tracking | 2 · any (best `L`) | dpc 5 · cd 5 | direct · CASTER_TO_TARGET + chain · 0.08 s per
dagger.
- **Effect:** one dagger per mask cell flies in sequence (nearest first). Daggers **bounce**: a dagger whose cell is
  empty re-targets the mask cell the unit moved to; at most 2 hits per cast.
- **Shape clause:** `L` → the corner cell's dagger flies first and applies Rạn before the rest land.
- **Status / reactions:** Rạn → R2 with a pinned target.
- **Combos:** Nhát Gọn on small fans; Song Đao after the Rạn.
- **Counterplay:** 2-hit cap; leaving the mask entirely.
- **Cast:** a fast backhand throw, fanning the off hand.
- **Delivery:** small steel-teal square daggers fly in a staggered fan, each a 2-square streak.
- **Impact:** a sharp pin-point burst per dagger; a bounced dagger shows a short square kink in its path.
- **Aftermath:** daggers stuck in the slabs flicker out.
- **Engine:** M03 + M06 `bounce`, `max_hits`, M16. **Complexity:** M. **Source:** pack `atk_036`, `atk_026`.

#### `dau_tu` — Dấu Tử (Death Mark) · *new*
Hero Assassin · epic · setup / execute | 1 · any (best `mono`) | dpc 2 · cd 10 | direct · DIRECT · instant.
- **Effect:** if it hits, the target carries **Dấu Tử** for 3 s: the next damaging cast on it echoes once at 60 %
  (M14, attached to the target) and that cast executes ×2 under 30 % HP.
- **Shape clause:** `mono` → the mark lasts 5 s.
- **Status / reactions:** the echo is tagged `echo` (no Rạn double-spend, no Engraving, no Awakening charge).
- **Combos:** Dấu Tử → Song Đao (each hit can't echo, only the cast once) or → Nhát cuối.
- **Counterplay:** visible mark; it expires; the boss can dodge the follow-up.
- **Cast:** the Assassin taps two fingers to the lips, then points at the target.
- **Delivery:** in place: a thin teal diamond sigil snaps open above the target.
- **Impact:** the sigil locks around the target as a square bracket.
- **Aftermath:** the bracket stays over the target, ticking down; on the echo it shatters into teal squares.
- **Engine:** M14 (target-attached echo), M19 execute. **Complexity:** M–H. **Source:** pack `atk_028`, `status_024`.

### Thợ săn — "own the ground: traps, thorns, pulls into them"
Passive Dấu Con Mồi (thorn entry → Rạn), Awakening Bẫy Sập (longer, wider thorns; Rạn ×2). Identity: traps, thorn
fields, forced movement. Combos: Móc Kéo pulls onto thorns / traps → R3 + Rạn; Gai Nổ detonates the field.

#### `bay_kep` — Bẫy Kẹp (Jaw Trap) · *new, as specified*
Hero Hunter · common · control | 2 · any (best `line_v`) | dpc 6 · cd 6 | trap · DIRECT · on entry.
- **Effect:** mask cells become trap cells for 8 s. The first enemy entry fires every trap cell of the cast:
  `dpc × trap cells under the footprint` + Pin 1.2 s. Cast on the enemy's own cell, it fires at once.
- **Shape clause:** `line_v` → a column trap: entering any cell fires all and Pin is 1.6 s.
- **Status / reactions:** Pin → crits `target_pinned`, R2.
- **Combos:** Móc Kéo / Bẫy Lò Xo push the boss in; Thợ săn's `target_on_hazard` crits.
- **Counterplay:** visible jaws; boss path cost; it waits them out.
- **Cast:** the Hunter kneels and slaps a palm on the floor.
- **Delivery:** in place: square jaws fold up out of each slab, open.
- **Impact (trigger):** the jaws snap shut with a square bite and a spray of wood chips.
- **Aftermath:** closed jaws hold the boss while Pin lasts, then splinter.
- **Engine:** M09 (zone `trap`, entry event, brain cost). **Complexity:** M. **Source:** rhythm spec; pack `atk_034`.

#### `moc_keo` — Móc Kéo (Hook Pull) · *new*
Hero Hunter · rare · spatial | 2 · any (best `line_h`) | dpc 4 · cd 7 | direct · CASTER_TO_TARGET · arrival.
- **Effect:** a hook flies to the first mask cell; if it hits, it **pulls** the unit up to 2 cells along its row
  toward the divider, step by step. A blocked step → R3 Va Đập. Ending on a thorn or trap cell triggers it.
- **Shape clause:** `line_h` → pull +1 cell.
- **Status / reactions:** R3; thorn entry → Dấu Con Mồi Rạn.
- **Combos:** pull onto Bẫy Kẹp, Bụi rậm, fuses; into Tường Đá for a slam.
- **Counterplay:** the pull path is **telegraphed** (`path_rule`) the moment the hook lands; a boss behind a pillar
  barely moves.
- **Cast:** the Hunter spins a rope overhead and casts it forward.
- **Delivery:** a jade-rope line of squares unrolls to the first cell, the hook a square claw.
- **Impact:** the claw bites, then the rope snaps taut and drags the target cell by cell (squares sparking on the
  slab edges).
- **Aftermath:** drag marks on the slabs the boss crossed, fading.
- **Engine:** M03, M12 `pull` (`force_move`), M15 R3, `path_rule` telegraph. **Complexity:** H. **Source:** new (the
  pack has no pull).

#### `gai_no` — Gai Nổ (Thorn Burst) · *new*
Hero Hunter · epic · payoff | 3 · any (best `branched`) | 6 per detonated cell · cd 9 | direct · DIRECT · instant.
- **Effect:** detonates every player thorn and trap cell inside the mask: each detonated cell deals 6 to the unit on
  it (one hit per unit, max), +1 Rạn per detonated cell under its footprint; the zones are consumed.
- **Shape clause:** `branched` → branch-tip cells re-grow thorns for 2 s after the blast.
- **Status / reactions:** Rạn stacks → R2 with Pin; Bẫy Sập's Rạn ×2 doubles the payoff.
- **Combos:** Bụi rậm / Bẫy chông / Dây úa / Bẫy Kẹp fields first.
- **Counterplay:** the boss leaving the field before the cast; no field, no damage.
- **Cast:** the Hunter yanks a rope back with both hands.
- **Delivery:** in place: thorn cells swell and glow amber at their edges.
- **Impact:** thorns burst into flying square splinters (outward from each cell).
- **Aftermath:** bare scorched slabs; on branch tips, thorns grow back.
- **Engine:** zone queries (`thorns_at`, trap zones), M16. **Complexity:** M. **Source:** pack `atk_029`.

### Giáo sĩ — "hold your ground, build Hàn, ring the bell"
Passive Lời Cầu Được Đáp (+8 HP per Hàn burst), Awakening Ban Phước (+1 Hàn per hit, burst ×1.5). Identity: own-half
wards, repeated light, frost bursts. Combos: Chuông Thánh's three rings stack Hàn → burst → heal; Thánh Thuẫn turns
damage taken into Hàn.

#### `thanh_thuan` — Thánh Thuẫn (Holy Ward) · *new, as specified*
Hero Cleric · common · defense | 2 · any (best `square`), placed as usual then **re-anchored on the hero** (A2) |
— · cd 8 | ward · DIRECT · 4 s.
- **Effect:** the cast's shape is re-anchored around the Cleric's cell on the own half; those cells become ward cells
  for 4 s: standing on one, incoming damage ×0.5 and +2 HP/s. The enemy is not hit by this cast.
- **Shape clause:** `square` → each hit the ward reduces gives the attacker +1 Hàn.
- **Status / reactions:** Hàn bursts → prayer heal.
- **Combos:** Ban Phước; any Hàn card.
- **Counterplay:** enemy telegraphs on the ward force the hero off it.
- **Cast:** the Cleric plants the staff and raises the free hand, palm out.
- **Delivery:** in place on the own half: ivory frames draw themselves around each slab.
- **Impact:** a slow ivory pulse rises from the ward cells.
- **Aftermath:** the frames thin out over the last second and fade.
- **Engine:** M10 (self placement, zone `ward`). **Complexity:** M–H (placement half switch). **Source:** rhythm spec;
  pack `def_016`, `def_017`.

#### `chuong_thanh` — Chuông Thánh (Holy Bell) · *new*
Hero Cleric · rare · repeat | 3 · any (best `square`) | dpc 4 · cd 7 | direct · DIRECT + echo · 0 / 0.6 / 1.2 s.
- **Effect:** hits now, then **echoes twice** on the same cells at 0.6 s intervals at 50 %; each wave that hits adds
  +1 Hàn.
- **Shape clause:** `square` → three echoes.
- **Status / reactions:** three Hàn in one cast → frost burst → prayer heal; R1 on burning cells.
- **Combos:** Ban Phước (+1 Hàn per hit) makes the burst arrive on the second ring.
- **Counterplay:** the echo outlines are visible; leaving between rings.
- **Cast:** the Cleric swings the staff like striking a bell.
- **Delivery:** in place: a square bell outline rings above the cells.
- **Impact:** each ring sends a square ripple across the cells, ivory then pale blue.
- **Aftermath:** frost rime squares at the cell corners after the last ring.
- **Engine:** M14 echo waves. **Complexity:** M. **Source:** pack `odd_011`, `combo_003`.

#### `thien_quang` — Thiên Quang (Heaven's Light) · *new*
Hero Cleric · epic · area control | 4 · any (best `plus`) | dpc 5 · cd 10 | direct · SKY_TO_TARGET · 0.7 s.
- **Effect:** a light pillar comes down on each mask cell after a 0.7 s shadow; a unit hit by a pillar gains +1 Hàn
  (max 2 per cast; one damage hit per cast).
- **Shape clause:** `plus` → the centre pillar lands first; if it hits, the Cleric heals 6.
- **Status / reactions:** Hàn bursts; R1 on burning cells.
- **Combos:** Thánh Thuẫn keeps the Cleric safe while channelling; Chuông Thánh on the same cells.
- **Counterplay:** read the shadows.
- **Cast:** the Cleric lifts the staff with both hands, head tilted up.
- **Delivery:** square shafts of ivory light descend, stepped (three widths), onto each cell.
- **Impact:** a square flash on the slab and a ring of pale squares.
- **Aftermath:** a faint ivory cross mark on each slab for 0.8 s.
- **Engine:** M05. **Complexity:** M. **Source:** pack `atk_040`, `atk_039`.

---

## 2. New shared cards (14: 6 open, 8 unlockable)

#### `dia_chan` — Địa Chấn (Tremor) · open
Shared · common · push | 3 · any (best `line`) | dpc 5 · cd 6 | direct · GROUND · arrival.
- **Effect:** a tremor runs through the mask from the cell nearest the hero (stopped by holes); on hit, push 1.
- **Shape:** `line` → push 2. **Reactions:** blocked push → R3. **Combos:** Tường Đá, thorns.
- **Counterplay:** stand behind a hole. **Complexity:** M (M04 + push).
- **VFX:** cast — stamp the foot / weapon butt; delivery — a raised ridge of slabs rippling forward; impact — slabs
  jolt up one pixel row and drop; aftermath — dust squares settle. **Source:** pack `atk_008` (re-cast as ground).

#### `vung_lay` — Vũng Lầy (Mire) · open
Shared · common · slow | 3 · any | dpc 2 · cd 7 | direct · GROUND · arrival.
- **Effect:** mask cells become mire for 4 s (step ×1.6; existing hazard).
- **Shape:** `compact` → 5 s. **Combos:** fuses, sky drops, shockwaves. **Counterplay:** short duration; exits kept.
- **Complexity:** S–M (`TileHazards.add_mire`).
- **VFX:** cast — a downward push of the palm; delivery — dark water seeps slab to slab; impact — bubbles of square
  mud; aftermath — glossy mire tiles that dry out. **Source:** pack `status_018`.

#### `lien_tram` — Liên Trảm (Double Slash) · open
Shared · common · combo | 2 · any (best `line`) | dpc 4 × 2 hits · cd 4 | combo · DIRECT · 0.15 s.
- **Shape:** `line` → 3 hits. **Combos:** Rạn stacks, Nhát Gọn. **Counterplay:** defense per hit.
- **Complexity:** S once M08 exists.
- **VFX:** two crossing square slashes, the second mirrored; scars fade. **Source:** pack `atk_002`.

#### `khien_thep` — Khiên Thép (Steel Ward) · open
Shared · common · defense | 2 · any, re-anchored on the hero (A2) | — · cd 8 | ward · DIRECT · 4 s.
- **Effect:** ward cells give the hero Guard 6 (flat damage reduction) while standing on them.
- **Shape:** `line_v` → also immune to push while on it. **Complexity:** S once M10 exists.
- **VFX:** cast — weapon held crosswise; delivery — steel plates slide up around the slabs; impact — a clank flash;
  aftermath — plates sink. **Source:** pack `def_001`, `def_016`.

#### `thuong_xuyen` — Thương Xuyên (Piercing Lance) · open
Shared · common · line payoff | 2 · **requires a `line` piece** | dpc 5 (+1 per line cell beyond 2, cap +3) · cd 4 |
direct · CASTER_TO_TARGET · arrival.
- **Effect:** a lance flies along the line and pierces every cell of it in order.
- **Combos:** Lia ngang, Trảm Địa lines. **Counterplay:** lines are easy to read.
- **Complexity:** M (shape requirement in `SkillAvailability`).
- **VFX:** a long stepped steel lance streak, each pierced slab spitting a square splinter; a thin scored line remains.
  **Source:** pack `atk_032`, `atk_038`.

#### `dap_vo` — Đập Vỡ (Guard Breaker) · open
Shared · common · anti-armour | 2 · any (best `compact`) | dpc 6 · cd 5 | direct · SKY · instant.
- **Effect:** removes the enemy's Guard and deals ×1.5 if it had Guard. **Shape:** `compact` → also 1 Rạn.
- **Counterplay:** wasted on unguarded enemies. **Complexity:** S–M (Guard is a pattern status today).
- **VFX:** a heavy square hammer head drops; the enemy's Guard plates crack apart. **Source:** pack `atk_007`,
  `atk_004`.

#### `chuoi_set` — Chuỗi Sét (Chain Spark) · unlockable
Shared · rare · scaling chain | 4 · any (best `S`) | dpc 5 · cd 7 | direct · SEQUENTIAL_CHAIN · 0.1 s per link.
- **Effect:** each link after the first adds +15 % to the hit (cap +60 %); the unit is hit at the link that finds it.
- **Shape:** `S` → links every 0.06 s. **Counterplay:** standing on an early link. **Complexity:** M (M06 ramp).
- **VFX:** a bright square spark hops link to link, each hop leaving a square afterglow; the hit link flashes white.
  **Source:** pack `atk_037`, `combo_008`. *(Lightning conduction R4 is Expansion.)*

#### `loc_cuon` — Lốc Cuốn (Vortex) · unlockable
Shared · rare · spatial | 4 · any (best `square`) | dpc 4 · cd 8 | direct · DIRECT · instant.
- **Effect:** pulls a unit inside or next to the mask 1 cell toward the mask centre, then hits.
- **Shape:** `square` → pull 2 and Pin 0.4 s. **Reactions:** blocked pull → R3.
- **Counterplay:** standing far from the mask. **Complexity:** M (M12 pull).
- **VFX:** squares spiral inward (clockwise, stepped) to the centre slab; a short square implosion. **Source:** new.

#### `tuong_da` — Tường Đá (Stone Wall) · unlockable
Shared · rare · terrain | 2 · any (best `line`) | — · cd 9 | direct · DIRECT · instant.
- **Effect:** empty mask cells become stone pillars for 3 s (blocked; never under a unit; an exit always remains).
- **Shape:** `line` → 4 s. **Reactions:** pillars cause R3 slams. **Counterplay:** short, exits guaranteed.
- **Complexity:** M (zone `pillar`, mover blockers, brain costs).
- **VFX:** stone blocks rise out of the slabs in two steps with falling grit; they sink back cracking.
  **Source:** new (pack `def_023` inverse).

#### `bay_lo` — Bẫy Lò Xo (Spring Trap) · unlockable
Shared · common · trap push | 2 · any | dpc 3 · cd 7 | trap · DIRECT · on entry.
- **Effect:** trap cells for 8 s; on entry, push 2 away from the divider (R3 if blocked).
- **Combos:** walls, thorns behind. **Complexity:** S once M09 + M12 exist.
- **VFX:** coiled square springs in the slabs; on trigger a plate snaps up and flings. **Source:** pack `status_019`.

#### `hoi_am` — Hồi Âm (Echo) · unlockable
Shared · epic · repeat | 3 · any (best `square`) | dpc 5 · cd 9 | direct · DIRECT + echo · 0 / 0.6 s.
- **Effect:** hits now, then one echo at 60 % on the same shape shifted 1 cell toward the enemy's back edge (if all
  shifted cells are valid; else in place). The echo mask is outlined from the first hit.
- **Shape:** `square` → two echoes. **Counterplay:** read the outline. **Complexity:** M (M14).
- **VFX:** the first impact leaves a translucent square copy of the mask that slides one cell and re-stamps.
  **Source:** pack `block_027`, `odd_011`.

#### `min_tre` — Mìn Trễ (Delay Mine) · unlockable
Shared · common · delayed | 2 · any | dpc 5 · cd 6 | delayed · DIRECT · fuse 1.2 s.
- **Effect:** fuse ×1.6; detonation pushes 1. **Complexity:** S once M07 exists.
- **VFX:** a square mine plate with a ticking light, then a square pop-burst. **Source:** pack `status_005`.

#### `bang_vo` — Băng Vỡ (Shatter) · unlockable
Shared · rare · reaction payoff | 3 · any | dpc 5 · cd 6 | direct · SKY · instant.
- **Effect:** applies Rạn before the damage, so a pinned target triggers R2 Vỡ Băng on this hit.
- **Combos:** any Pin (Đỡ Kiếm, Bẫy Kẹp, Lặng yên). **Complexity:** S once R2 exists.
- **VFX:** an ice spike drops; on R2 the ice around the target bursts into big square shards. **Source:** pack
  `status_013`, `atk_016`.

#### `hoa_bang` — Hỏa Băng (Frostfire) · unlockable
Shared · epic · reaction enabler | 4 · any (best `branched`) | dpc 3 · cd 10 | direct · DIRECT · instant.
- **Effect:** ignites the mask cells **and** adds 1 Hàn on hit → R1 Hơi Nước on the target's cell.
- **Shape:** `branched` → tip cells burn 2 s longer. **Complexity:** S once R1 exists.
- **VFX:** two-tone squares (amber and pale blue) spiral together and burst into stepped steam squares.
  **Source:** pack `odd_018` (adapted).

---

## 3. Reworked existing cards (4; ids kept)

| Id | New name | New rule | Shape clause | Delivery / timing | Complexity |
|---|---|---|---|---|---|
| `chan_phong` | Hích Tường (Shove) | push 1; blocked → R3 Va Đập; crit `target_pinned` kept | `line_h` → push 2 | caster→target, arrival | M |
| `suong_mong` | Mặt Băng (Ice Floor) | Pin 0.8 s if the unit stands in the mask; the cells become ice floor 4 s (entering pins 0.4 s, ICD 2 s) | `compact` → 5 s | direct, instant | M |
| `kiem_than` | Lưỡi Đầu (First Edge) | crit `first_strike` ×1.6 (target not hit for 3 s) | `mono` → cd −1 s | caster→target, instant | S |
| `ran_van` | Đường Nứt (Fault Line) | Rạn stacks = number of pieces in the cast (+1 for a `line` piece), ground front stopped by holes | as rule | ground, arrival | M |

VFX for reworks: Hích Tường = a shoulder-shove square shock that slams the boss into a wall flash (R3); Mặt Băng =
slabs glaze over with pale-blue squares that crack when stepped on; Lưỡi Đầu = a single clean white slash with a
small star square on crit; Đường Nứt = a crack line runs through the slabs, branching per piece.

## 4. Existing cards: v2 clauses (28) — intentional behaviour changes, enabled per card in B7

Every row below changes behaviour. Through B1–B6 all 32 existing cards stay exactly as today (golden test); §8 lists
each change with its gameplay and damage difference and its regression tests.

| Id | Name | Clause / resolve change (v2) |
|---|---|---|
| `kiem_khi` | Rạch nhẹ | none (baseline, cast-timeout fallback); leaves the starters (Q10) |
| `hoa_xa` | Tia lửa | ground arrival, stopped by holes; `line` → burn +1 s |
| `hoa_tinh` | Tro hồng | sky arrival with shadows; crit `target_burning` |
| `hoa_tran` | Lò than | `square` → the burn starts with 2 stacks; crit `target_burning` |
| `liet_hoa` | Lửa rừng | ground arrival; `branched` → tips burn +1 s |
| `thien_hoa` | Giàn thiêu | sky arrival; `plus` → +1 burn stack |
| `bang_chau` | Mưa đá | chain; `S` → faster links |
| `han_khi` | Rùng mình | `line` → +1 Hàn |
| `han_kiem` | Rét cắt | crit `self_hp_high` (rhythm spec) |
| `thanh_thuy` | Sương bạc | chain; `square` → heal +2 |
| `bang_phong` | Lặng yên | `square` → Pin +0.3 s |
| `han_phong` | Bão trắng | chain `from_centre` |
| `han_tran` | Tuyết rơi | sky arrival; `plus` → +1 Hàn |
| `xung_kich` | Xô lùi | ground arrival; blocked push → R3 |
| `cuong_phong` | Cú húc | blocked push → R3 |
| `thien_lang` | Sạt lở | sky shockwave from the centre; blocked push → R3 |
| `gai_doc` | Bẫy chông | `branched` → thorns +1 s; crit `target_on_hazard` |
| `ran_kich` | Nứt chân chim | ground arrival; `line` → +1 Rạn |
| `bang_tam` | Buốt xương | chain ramp (+10 %/link, cap +30 %) |
| `han_bang` | Tảng băng | sky shockwave from the centre (sets up R2) |
| `kiem_vu` | Xé toạc | sky arrival; `T` → the stem cell first ×1.25 |
| `thiet_kiem` | Lia ngang | `line_h` → +1 dpc |
| `dai_dao` | Bổ nặng | chain; a `line` of length ≥ 4 → ramp +10 %/link |
| `song_kiem` | Nêm sắt | `compact` → bonus vs Rạn ×1.75 |
| `tu_kiem` | Nhát cuối | `mono` → execute threshold 35 % |
| `tran_gai` | Bụi rậm | `line` → thorns 4 s; crit `target_on_hazard` |
| `gai_nguyen` | Dây úa | `branched` → +1 Rạn on entry |
| `do_kiem` | Đỡ Kiếm | see §1 |

## 5. Starters (6 cards; Kiếm Khí replaced, Q10)

| Hero | Starter v2 |
|---|---|
| Kiếm sĩ | `do_kiem`, `tram_dia`, `kiem_vu` ×2, `thiet_kiem`, `chan_phong` |
| Pháp sư | `hoa_loi`, `hoa_xa`, `hoa_tinh` ×2, `hoa_tran`, `bang_phong` |
| Sát thủ | `song_dao`, `lien_tram`, `kiem_vu`, `thiet_kiem`, `bang_chau`, `han_kiem` |
| Thợ săn | `bay_kep`, `tran_gai` ×2, `gai_doc`, `ran_kich`, `dia_chan` |
| Giáo sĩ | `thanh_thuan`, `han_khi` ×2, `han_kiem` ×2, `thanh_thuy` |

The rare / epic hero cards enter the hero's reward pool only (Q3). `kiem_khi` stays the internal fallback
(`default_card`), cast when no drawn card is available; starter validation per cell count is in
`02-design-decisions.md` §9.

---

## 6. Expansion (after MVP playtests; 12)

| Id (working) | Name | Owner | Mechanic | Why not MVP | Source |
|---|---|---|---|---|---|
| `no_gac` | Nỏ Gác (Sentry Crossbow) | Hunter | summon on an own-half cell, fires along its row 3× (each shot telegraphed) | M13 constructs | new |
| `tru_bang` | Trụ Băng (Frost Totem) | Cleric | construct pulsing +1 Hàn to adjacent cells | M13 | pack `status_011` |
| `set_dan` | Sét Dẫn (Conduction) | Shared | charges tiles; lightning chains through charged tiles (R4) | new element + tile mark | pack `atk_014` |
| `hoan_vi` | Hoán Vị (Swap) | Shared | swap the hero with a mirrored own-half cell | M12 swap | pack `def_022` |
| `doc_tieu` | Độc Tiêu (Poison Dart) | Assassin | Poison stacks (new status) | poison family | pack `status_006` |
| `doc_no` | Độc Nở (Venom Bloom) | Assassin | poison spreads at 3 stacks | poison family | pack `status_007` |
| `phan_an` | Phản Ấn (Retaliation Stamp) | Knight | after a parry, re-stamp the last shape at 50 % | needs last-shape memory | pack `atk_010` |
| `luc_giac` | Lục Giác (Odd Hexa) | Shared | 6-cell Odd only, each cell hits | Odd card rules | pack `odd_001` |
| `xich_tu` | Xích Tử Chuỗi (Magenta Relay) | Shared | Odd cells resolve as a 0.25 s chain | Odd + chain | pack `odd_003` |
| `bung_vo` | Bùng Vỡ (Primal Fracture) | Shared | shards add a small hit per hit cell | multi-hit scaling | pack `odd_012` |
| `cau_ivory` | Cầu Ngà (Ivory Bridge) | Cleric | restore 2 own-half holes for 2 s | player terrain repair | pack `odd_013` |
| `mau_cuoi` | Mẫu Cuối (Last Pattern) | Shared | 5th distinct shape in a match adds a hit | shape history | pack `odd_025` |

## 7. Experimental (prototype first; 5)

| Id (working) | Name | Mechanic | Risk |
|---|---|---|---|
| `gap_khong` | Gấp Không Gian (Fold) | two telegraphed cells linked: a hit on one lands on both | readability, AI |
| `dao_thoi` | Đảo Thời (Time Fold) | swaps the resolve order of the next two casts | timing clarity (pack `odd_016`) |
| `ren_hinh` | Rèn Hình (Reforge) | reshape a piece to bar / L / T before placing | shape identity (pack `block_010–015`) |
| `tach_khoi` | Tách Khối (Split) | split a 4+ piece into two placed pieces | input on touch (pack `block_005/006`) |
| `guong_hinh` | Gương Hình (Mirror) | allow one mirrored placement | rotation-only rule (pack `block_004`, `odd_004`) |

---

## 8. Legacy migration table (revision 2) — every existing card

"Current" = today's build: **all cells resolve at the swing end, one hit test, one wave**. Timing terms: *ground* =
front by BFS distance × `step_sec`, stopped by holes / missing / locked cells; *sky* = per-cell shadow then drop at
`fall_sec` + index × `stagger_sec`; *chain* = link i at i × `step_sec`. "Dodge" = a boss can now leave a cell before
its event. Every row is an intentional change, enabled in B7 card by card; golden expectations change only for that
card in that commit. Shared regression tests for every row: golden diff limited to the card, sim band
(ch1 40 seeds), card text fits.

| Card | Current | v2 | Gameplay difference | Damage / status difference | Card-specific regression tests |
|---|---|---|---|---|---|
| `kiem_khi` Rạch nhẹ | instant | **unchanged**; leaves the starters, stays `default_card` | fallback path faster (0.5 s auto-cast) | none | fallback tests (decisions §13) |
| `do_kiem` Đỡ Kiếm | instant parry | `line_v` piece → guard window +0.2 s | longer window with a vertical bar | none on damage | window length with `bar3` vertical vs `bar3` horizontal |
| `hoa_xa` Tia lửa | instant; all cells ignite | ground; `line` → burn +1 s | cells behind a hole not hit / ignited; far cells later (dodge) | hit rate ↓ on holed arenas; burn +1 s with lines | front stops at a hole; arrival order; line burn duration |
| `hoa_tinh` Tro hồng | instant | sky with shadows; crit `target_burning` ×1.5 | boss can step out of a shadow | fewer hits vs dodging bosses; ×1.5 on burning targets | shadow escape; crit only when burning |
| `hoa_tran` Lò than | instant | timing unchanged; `square` → ignites at 2 stacks; crit `target_burning` | — | burn ticks +1 with a square; ×1.5 on burning | stack count with square vs l4 |
| `liet_hoa` Lửa rừng | instant | ground; `branched` → tips burn +1 s | as Tia lửa | longer burn on tips | hole cut; tip durations |
| `thien_hoa` Giàn thiêu | instant | sky; `plus` → +1 stack | dodge window | +1 stack with plus | shadow escape; stack with plus5 |
| `suong_mong` → **Mặt Băng** | instant Pin 0.8 s if inside | Pin as before + ice floor 4 s (entry Pin 0.4 s, ICD 2 s) | adds terrain the boss avoids | extra pins on entry | ice entry pin; ICD; zone conflicts (catalog §G) |
| `bang_chau` Mưa đá | instant Pin | chain; `S` → faster links | late links can be dodged | hit rate ↓ on long chains | chain order and timing |
| `han_khi` Rùng mình | instant | `line` → +1 Hàn | — | +1 Hàn with a line | stacks with bar vs square |
| `han_kiem` Rét cắt | instant | crit `self_hp_high` ×1.5 | rewards staying healthy | ×1.5 at ≥ 70 % HP | crit at 70 % / 69 % HP |
| `thanh_thuy` Sương bạc | instant | chain; `square` → heal +2 | late links dodgeable | heal 6 with a square | chain timing; heal amount |
| `bang_phong` Lặng yên | instant | `square` → Pin +0.3 s | — | Pin 1.5 s with a square | pin length |
| `han_phong` Bão trắng | instant | chain `from_centre` | order changes | timing only | order from centre |
| `han_tran` Tuyết rơi | instant | sky; `plus` → +1 Hàn | dodge window | +1 Hàn with plus | shadow escape; stacks |
| `chan_phong` → **Hích Tường** | instant push 1 | projectile arrival; blocked push → R3; `line_h` → push 2 | slams into walls / edges | +8 dmg and Pin 0.6 s when blocked | R3 on edge, hole, pillar; push 2 with line |
| `xung_kich` Xô lùi | instant push 2 | ground; blocked push → R3 | holes stop the front; slams | R3 bonus | hole cut; R3 |
| `cuong_phong` Cú húc | instant push 1 | timing unchanged; blocked push → R3 | slams | R3 bonus | R3 |
| `thien_lang` Sạt lở | instant push 2 | sky shockwave from the centre; R3 | ring timing, dodge | R3 bonus | ring order; R3 |
| `gai_doc` Bẫy chông | instant zone | `branched` → thorns +1 s; crit `target_on_hazard` | — | longer field; ×1.5 on hazard | thorn duration; crit |
| `ran_kich` Nứt chân chim | instant 1 Rạn | ground; `line` → +1 Rạn | hole cut | 2 Rạn with a line | front; stacks |
| `ran_van` → **Đường Nứt** | instant 2 Rạn | Rạn = pieces in the cast (+1 with a line); ground front | single-piece casts give **1** Rạn (today 2) | ↓ for 1 piece, ↑ for 2 pieces + line (max 3) | stacks per piece count; hole cut |
| `bang_tam` Buốt xương | instant | chain ramp +10 %/link (cap +30 %) | later links hit harder | up to ×1.3 (shape group S) | ramp cap |
| `han_bang` Tảng băng | instant Pin + 2 Rạn | sky shockwave from the centre | ring timing, dodge | sets up R2 | ring order; R2 trigger |
| `kiem_vu` Xé toạc | instant | sky; `T` → stem cell first ×1.25 | dodge window | ×1.25 on the stem (S) | shadow escape; stem bonus |
| `thiet_kiem` Lia ngang | instant | `line_h` → +1 dpc | rewards horizontal bars | 21 → 24 on 3 cells (E2) | dpc with bar3 horizontal / vertical |
| `dai_dao` Bổ nặng | instant | chain; `line` ≥ 4 → ramp +10 %/link | late links dodgeable, ramp | up to ×1.3 (S) | ramp only with length ≥ 4 |
| `kiem_than` → **Lưỡi Đầu** | instant dpc 8 | crit `first_strike` ×1.6; `mono` → cd −1 s | rewards opening hits | ×1.6 when the target was not hit for 3 s | first_strike timer |
| `song_kiem` Nêm sắt | instant, ×1.5 vs Rạn | `compact` → ×1.75 vs Rạn | — | +0.25 vs Rạn with compact shapes | multiplier by shape |
| `tu_kiem` Nhát cuối | instant, execute < 25 % | `mono` → execute < 35 % | rewards single-cell finishers | earlier execute window | threshold by shape |
| `tran_gai` Bụi rậm | instant hit + thorns 3 s | `line` → thorns 4 s; crit `target_on_hazard` | — | longer field; ×1.5 on hazard | duration; crit |
| `gai_nguyen` Dây úa | instant zone | `branched` → +1 Rạn on entry | — | 4 Rạn per entry with branched | entry stacks |
