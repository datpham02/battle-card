# 01 — World Map v2: game design specification

Status: **Proposed** (needs the user's approval; see README "Decisions required").
Audit basis: `00-current-state-audit.md`. Region details: `02-region-design.md`. Encounter architecture:
`03-encounter-system.md`. Technical design: `04-technical-architecture.md`.

Design goal in one line: **every node choice is a trade the player can read** — the map stops being "which fight
next" and becomes "which route, at what cost, for what".

Terms used below: *region* = one floor's land (chapters.json chapter); *warden* = region boss (`boss` kind);
*route* = a lane of nodes through a region with a declared archetype; *crossing* = a depth where routes join;
*encounter profile* = what a fight node resolves into (`03`).

---

## A. Run structure

### A1. What stays

- One run = character → **7 regions in the climb order** `ch1 → hellfire → desert → swamp → ch2 → ch3 → sky_isles` →
  Lattice Heart (`an_dai_keeper`, after one shop). The order is the user's 2026-11-07 decision; the slice keeps it.
- HP, gold, deck, relics, piece deck, removal tokens and fates carry across the run; warden kill heals 60 % max HP.
- Difficulty by **floor** (`floor_scaling`, `floor_tiers`), not by region; Kiep on top. Unchanged numbers.
- Fate (spare / execute) after every warden; three endings.

### A1b. Relation to ADR-0001 decision D3 (the design pack) — **conflict to resolve**

`docs/architecture/adr-0001-tessera-design-pack-alignment.md` D3 (Accepted 2026-11-01) adopted the pack's run
structure: **5 tiers, each a choice of two lands** (I Forest/Dungeon, II Tower/Swamp, III Sands/Hellfire, IV Sky Isles
two routes, V Lattice Heart two routes), "~5-row DAG per land + Warden, separate Forge node". Six days later
(2026-11-07) the user chose the **fixed 7-region climb** that ships today (`world.region_order`, the Tower Ascent
screen), and this task's brief says "keep the seven-region journey as the initial design framework". The two are
incompatible at the world level (5 tiers of pairs visits 5 lands; the climb visits all 7).

This spec follows the **later decision and the brief**: 7 fixed regions. What it keeps from D3 is everything *inside*
a land: the seeded DAG with the pack's generation constraints (B7), the Forge node (B8), the 10k-seed validation
(06). Decision D2 in the README asks the user to confirm this and to amend ADR-0001 D3's world line in one sentence
when approving. If the user instead wants the pack's tier pairs back, the region map design below is unchanged —
only the climb screen and `WorldMapGen.offer_for_floor` (which already implements "1 of 2") are affected.

### A2. What changes

| Today | v2 |
|---|---|
| A region is 7 independent columns; paths differ by match id only | A region is **3 routes** with declared archetypes, joined at **2 crossings**, then an **approach** and the warden |
| The player sees node icons; nothing about the fight, its arena, its modifiers or its reward | Every node shows a **preview card**: enemy, arena, modifiers, reward tier, risk glyphs (G) |
| Node reward = f(kind) | Node reward = f(kind, **reward tier**, objective) — risk and payoff are declared on the node (E) |
| Region mechanics live inside single matches | Each region has a **rule with run-scoped state** that the map and the fights both read (02) |
| Climb screen = progress strip | Climb screen = progress strip + **next-region briefing** (rule, warden, what to prepare) |

### A3. Entering and leaving a region

1. Climb screen → tap the floor's island → briefing panel (region rule in one line, warden name + fate status, the
   region's pressure gauge if any, "Enter"). Tap "Enter" → region map.
2. Region map: entry node (depth 0, one battle, as today — it teaches the region's first enemy) → route choice at
   depth 1 → … → warden at the last depth.
3. Warden falls → fate → boss reward → heal → climb screen with the next island lit. Unchanged flow
   (`GameFlow._after_fate → _return_to_map → WORLD_MAP`).
4. The region's rule state resets when the region is left (heat, cold, etc. are per region, never per run), so a
   region never punishes the player for a previous region's choices. Reason: the brief's "region transitions affect
   build preparation" is served by the *briefing* and by what the player buys / rests before entering, not by
   carrying a debuff across regions, which would make the climb feel like attrition instead of choice.

### A4. Difficulty progression

Unchanged scaling pipeline. Two additions, both data:

- **Route modifiers add difficulty inside a floor** (Peril and Elite routes carry modifiers, see E/03); the floor row
  stays the baseline so the Safe route of floor N is exactly today's floor N.
- **Onboarding** keeps `onboarding_tier_cap`; in addition, on floor 1 the generator never offers the Peril archetype
  (data: `archetype_min_floor`), matching the existing "floor 1 teaches before it tests" rule
  (`first_floor_map_test`).

### A5. The final

Unchanged: `final_prelude` shop → `an_dai_keeper`. The last region's **approach** depth (see B2) is where the player
prepares; the climb-screen briefing for the summit lists the keeper's two phases (already in data).

---

## B. World map and route design

### B1. Graph model (player-facing)

A region map is a **layered directed graph** drawn left → right, 7 depths (same length as today, so pace, gold and
luck baselines move as little as possible):

```
depth:   0        1        2        3        4        5        6
       entry   route    route   CROSSING  route   APPROACH  warden
                 ┌─ R1 ─── R1 ──┐ ┌── R1 ──┐
       [B] ──────┼─ R2 ─── R2 ──┼─┼── R2 ──┼── [A1 | A2] ── [W]
                 └─ R3 ─── R3 ──┘ └── R3 ──┘
```

- **Entry** (depth 0): one `battle`, tier 0 (teaches the region, as today).
- **Routes** (depths 1–2 and 4): three lanes R1–R3, each with an **archetype** (B3). A lane is 2 nodes, then a
  crossing, then 1 more node. Lanes are drawn top-to-bottom in a fixed visual order so the player learns "top = safer"
  is *not* a rule — the archetype icon is the rule.
- **Crossing** (depth 3): a single-node depth every lane passes through. It is the region's **hub**: one `rest`,
  `shop` or `event` node (which one is decided by the shop plan and the region, B5). At the crossing the player may
  continue on any lane (edges from the hub to all three depth-4 nodes). This is the one place the player can change
  their mind after seeing how the first half went.
- **Approach** (depth 5): two nodes, **A1 prepare** (`rest` or `shop`, whichever the hub was not) and **A2 gamble**
  (`miniboss` from floor 2, `event` on floor 1 — the existing `min_floor` / `max_floor` rules, now on a named slot).
  Every depth-4 node links to both.
- **Warden** (depth 6): one `boss`; both approach nodes link to it.

Edges: within a lane, depth d → d+1 of the same lane. Cross-lane edges exist only **into** the crossing (all lanes →
hub) and **out of** it (hub → all lanes), plus depth 4 → both approach nodes. Lane switching between depths 1→2 is
*not* allowed: committing to a route for two nodes is what gives the choice weight. (OSFE-style 1–2 random links are
dropped: they produce "paths" nobody can tell apart; the audit showed this is exactly today's problem.)

Counts: 1 + 3·2 + 1 + 3 + 2 + 1 = **14 nodes** per region map, **7 visited** per region (entry, 2 lane, hub, 1 lane,
1 approach, warden) — identical to today's 7 visits per floor, so the run length baseline (≈ 51 visits) holds.

### B2. Why not keep OSFE's random links

OSFE's `WorldBar` creates branching by random adjacency; the player reads it as texture, not strategy, because the
zone *types* behind the links are rolled independently. Slay the Spire achieves readable routes with authored
templates and icon legibility. Tessera's fights are long (2–4 min) so a region has few nodes; with few nodes every
node must carry meaning. Hence authored lanes. Randomness moves to *which archetypes appear*, *which enemies and
modifiers fill them*, *which hub kind*, and *the seeds inside each node* — enough variety per seed (B6) without
losing legibility.

### B3. Route archetypes

Each lane has exactly one archetype. The table is the design intent; exact node templates are in `03` §3 and the
numbers are tuning knobs (`04` data schema).

| Archetype | Icon (angular, bare) | Lane template (depth 1, 2, 4) | Promise to the player | Cost |
|---|---|---|---|---|
| **Safe / Recovery** `safe` | shield chevron | battle (tier −1 pool when it exists) · battle · battle-or-rest | low HP loss; one extra heal opportunity | lowest gold, no rare floor, no relic |
| **Treasure / Economy** `treasure` | chest | battle · **treasure** · battle (gold ×1.5) **or forge** (B8) | more gold, a relic row, an ink, the block-deck node | fights are normal; nothing else |
| **Peril / High risk** `peril` | flame triangle | danger · danger (+1 modifier) · danger (+1 modifier, objective; was +2 — tuned 2026-11-12, see `production/qa/evidence/world-map-v2/balance-validation-2026-11-12.md`) | reward tier +1 on every node, luck +2 per node, an **objective bonus** | more HP loss, modifiers that fight the build |
| **Elite / Challenge** `elite` | skull | battle · **miniboss** · battle | a rare-floor offer **and** a relic offer from the elite | the elite is a tier-up fight with a signature trait |
| **Mystery / Exploration** `mystery` | question diamond | **event** · battle · event-or-treasure | two events (the only lane with two), one may be a bargain | variance; events can cost HP or gold |

Rules:
- A region draws **3 distinct archetypes** from the five, weighted per region and floor (`region_rules.archetype_weights`,
  `archetype_min_floor`). Floor 1: never `peril`; `elite` only from floor 2 (existing `miniboss min_floor 2`).
- At least one of `safe` / `treasure` is always present (a "breathing" lane), so a run never faces three hostile lanes.
- The lane order on screen is seeded (top/middle/bottom), not sorted by archetype.

### B4. Information the player sees before choosing

On the region map (always, no fog by default):
- The whole graph, every node's **kind icon** and **archetype band** behind each lane.
- Per node, on tap (preview panel, G): enemy name + role, arena shape thumbnail, modifier icons with one-line text,
  reward tier (★ / ★★ / ★★★) and what it contains (cards / gold range / relic / ink), objective if any.
- Per lane, in the band header: archetype name + its 2–3 glyphs (HP risk, gold, rarity, relic).
- What stays hidden: the *exact* enemy of nodes two or more steps ahead when a region rule hides it (Misty Forest's
  mist, Desert's sandstorm — 02), the content of events, the shop stock, and the warden's phases (shown as "2 phases"
  only). Reason: the brief wants informed choice "without knowing every hidden outcome"; risk is legible, outcomes
  are not spoiled.

### B5. Guarantees and dead-end prevention

- Every node has ≥1 edge out (except the warden) and ≥1 edge in (except the entry). The validator (`04` §6) rejects a
  map otherwise; generation is constructive so this cannot fail, the validator is a regression guard.
- Every region has: 1 entry battle, 1 hub (`rest` | `shop` | `event`), 1 prepare node (`rest` | `shop`, the other
  kind), ≥1 treasure on *some* lane (`treasure` lane, or the `safe` lane's depth-4 `rest`-or-`treasure`), the gamble
  node, the warden. So **rest is always reachable** (hub or prepare) and the shop plan's guaranteed shops land on the
  hub or prepare slot.
- Shop plan: unchanged (`WorldMapGen.shop_floors`, floor 1 always, 3 more floors, final prelude). On a shop floor the
  hub is a `shop` and prepare is `rest`. On other floors the hub is `rest` or `event` (seeded 50/50); prepare is
  `rest` when the hub is not a rest, and **`forge`** when the hub is a rest (decision D13: never two heals in one
  region, always a non-combat node before the warden). Shops per run stay ≤ 5.
- Event cap: ≤ 2 per region (both on the `mystery` lane) — today's "one event per region" rises to two only when the
  player picks that lane.
- Boss accessibility: the warden has edges from both approach nodes; both approach nodes from every depth-4 node;
  trivially reachable from every lane. Validated across seeds (06).

### B6. Randomness vs authored design

| Authored (data, never random) | Seeded random |
|---|---|
| depth layout 0–6, node counts, which depths cross | which 3 archetypes, their screen order |
| archetype templates (kind per slot, reward tier per slot) | enemies drawn from the existing pools / tiers (unchanged draw rules, unused ids first) |
| guarantees in B5 | hub kind (rest/event) on non-shop floors, gamble kind by floor |
| region rule and its numbers | which modifiers fill the peril slots (from the region's modifier pool), arena variants |
| | event ids, shop stock, reward rolls (all existing streams) |

Seeds: one stream per concern, hashed from `(run_seed, region_id, floor, "<concern>")`, as today (`04` §5).

### B7. The pack's generation constraints, mapped (ADR-0001 D3, pack `02` §3 / `06` §4)

| Pack constraint | Where the layout satisfies it |
|---|---|
| 1. route starts with one common battle; no elite before its teaching normal | entry node (depth 0, tier 0); `teach_after` pass over the graph; `elite` archetype min floor 2 |
| 2. every route has ≥ 1 of merchant / treasure / rest; a shop follows a coin source | hub (depth 3) is rest / shop / event on every lane; every lane has ≥ 2 nodes before the hub, at least one a fight or treasure (the `mystery` lane's depth-2 node is always a battle) |
| 3. pre-boss row offers a non-combat alternative | approach: prepare (rest / shop) beside gamble (miniboss) |
| 4. elite optional; one ordinary route always available | elite only on the `elite` lane; the `safe` / `treasure` guarantee |
| 5. no dead ends; links never cross confusingly; risk icon visible at each fork | validator; lanes never cross except into / out of the hub; archetype band + glyphs |
| 6. run seed; no forced elite in the only remaining path | one stream per concern (04 §5); the gamble is a sibling of prepare, never alone |
| 7. few visible decisions at once; region choice and in-land choice on separate UI levels | 3 lanes; climb screen vs region map |
| pack rhythm `battle → {battle|treasure|event} → {battle|shop|elite} → {camp|forge|battle} → {elite|battle|treasure} → boss` | the same beats, assigned to lanes instead of rows so each lane reads as one promise (B2) |
| "5 nodes + Warden; 2–3 candidates per decision" | 6 visits + warden (one more than the pack, equal to today's run length); 3 candidates at the fork, 2 at the approach |
| 10k-seed generator test | 06 §2 |

### B8. Forge node (pack "Shrine / Forge", ADR-0001 D3 "separate Forge node")

Tessera's block tokens are the **piece deck** (`PieceDeck`: shape weights, inks, run-only shapes, removals). Today the
piece deck is touched only through ink rows after fights and the shop's `remove_shape` service; the pack and D3 want
it to be a *destination*. v2 adds the node kind **`forge`**: on entry the player gets one ink offer (2 shapes, the
existing `pending_ink_offer` row that `RewardView` already draws) **and** one free shape removal this visit
(`RunSession.remove_shape(id, spend_token = false)` exists; `GameFlow.remove_shape` gains a `free` flag). The screen
is the reward screen with no card row and the ink row plus a "remove a shape (free)" action — whether `RewardView`
draws correctly with zero card offers is unverified (`08` §F); the fallback is an ink row on the piece-deck screen.
No new economy: two existing actions move onto a node the player can route to. Placement: the `treasure` lane's
depth-4 slot (50/50 with the gold battle) and the prepare slot when the hub is a rest (D13). Reward tier 1, no gold.
Name: the rest node's "Rèn" already means *card* forge in the strings, so this node needs its own key
(`node.forge.*`, e.g. "Lò Khối"; D11). The forge is the block-deck build's lane marker the same way the elite is the
relic build's.

---

## C. Encounter system (summary; full in 03)

A fight node resolves to an **encounter profile**:

```
profile = roster match (unchanged pools / tiers)
        + arena (match's shape; region rule may add a hazard overlay)
        + modifiers[] (0–2 ids from the region modifier pool, chosen by archetype slot)
        + objective (optional, Peril lane only at first)
        + reward tier (from the archetype template slot)
        + region rule state (e.g. Hellfire heat level)
```

Modifiers are **BossTraits or arena overlays that change decisions on the grid** (where to stand, when to cast, which
shape to pick), never stat-only. Examples that already exist as traits: `row_burner`, `frost_aura`, `shroud`,
`seal_caster`, `thorn_field`; new ones in 03 §4. Multi-enemy fights are **out of scope** (the combat core is 1v1 by
construction, audit §1.4); variety comes from composition of the above.

---

## D. Region identity (summary; full in 02)

One reusable system — **Region Rule** = `{ gauge?, map_effect, combat_effect, warden_hook }` with per-region
configuration — rather than seven systems:

| Region | Rule name | One-line identity |
|---|---|---|
| ch1 Misty Forest | **Mist** | information: nodes beyond the next depth hide their enemy; in combat the enemy's telegraph is shown late on misted rows |
| hellfire | **Heat** (vertical slice) | a region gauge: fights raise heat; heat shortens vent intervals **and** raises reward tier; rest/shop cool it |
| desert | **Sandstorm** | a drifting buried lane: one lane's nodes are "buried" (reveal on adjacency, +gold when dug); wind in combat |
| swamp | **Sink** | every lane has a toll: longer lanes cost HP to walk; mire spreads with each cast in combat |
| ch2 Dungeon | **Locks** | one lane is gated behind a key found on another; arenas collapse cells permanently per hit |
| ch3 Ice Tower | **Cold** | a gauge in the other direction: cold accumulates per node, slows the player's drops; warm nodes (rest, event brazier) reset it |
| sky_isles | **Gale** | the map tilts: after each node, the wind closes one unvisited edge; crumble in combat |

Only **Heat** is implemented in the slice; the rest are proposals with their gameplay impact argued in 02.

---

## E. Rewards and economy

### E1. Keep

Card offers (3), luck drift, rarity tables, gold bases, shop stock and prices, services, relic sources, ink offers,
fate offers, removal tokens. **No number changes without the simulation in 06.**

### E2. Change: reward tier on the node

Today `RewardRoller.reward_for_node(kind)`; v2 passes `(kind, tier)` where tier ∈ {1, 2, 3} comes from the archetype
template slot (default = today's values at tier 1). Proposed table (initial values = today's numbers, so a Safe route
is exactly the current game):

| Tier | Cards | min rarity | Gold mult | Relic row | Luck |
|---|---|---|---|---|---|
| 1 (safe, treasure fights) | 3 | common | ×1.0 | — | +1 |
| 2 (peril d1–d2, elite fights) | 3 | common | ×1.3 | — | +2 |
| 3 (peril d4 with objective, elite's miniboss) | 3 | rare | ×1.6 | 1 relic (event source rule) | +3 |

Objective bonus (Peril d4 only at first): meet the objective → tier +1 effects on *that* node's reward (gold ×1.3 extra
and the relic row). Objectives are spatial (03 §5): "win with ≥ 1 vent eruption survived on an enemy cell", "cast a
≥ 4-cell shape", "take no row_burner hit".

### E3. Change: lane-level economy

- `treasure` lane: depth 2 is a true `treasure` node (free offer + relic row + ink, as today) — one per region at most,
  on this lane; the depth-4 fight pays gold ×1.5.
- `elite` lane: the miniboss keeps its rare floor and **adds** a 1-relic offer (fills the dead `boss_kill`-style gap
  with the existing `event` source rule; `relics.json` untouched).
- Hellfire Heat: reward tier of the next fight = template tier + heat bonus (0/+1), capped at 3 (02).

### E4. Economy balance checks

Risk-adjusted expectation must hold: for a mid-floor region, **E[gold + card value] of Peril ≥ Safe + 25 %** while
**E[HP loss] of Peril ≈ Safe + 15–25 % max HP**; Elite and Treasure sit between; Mystery has the highest variance with
Safe's mean. These are *targets to measure*, not tuned constants (06 §3). Anti-inflation guards: the tier table only
raises gold multipliers and rarity floors, never offer counts; relic rows stay ≤ 1 per node; luck per node is capped so
a full-Peril run reaches luck 70 at about node 25 instead of 35 (the clamp already exists).

### E5. Fit of shops, treasure, events, rest, boss

- Shop: hub on shop floors (spend before the second half) — a *position* decision the player can plan from the
  briefing ("this region has a shop at the crossing").
- Treasure: the economy lane's middle; the safe lane's optional end.
- Events: the mystery lane; also the hub on some non-shop floors.
- Rest: always at the hub or prepare; never two in a region (keeps HP as a budget).
- Warden: unchanged reward + fate; the approach gamble (miniboss) is the "do I need more before the boss" question.

---

## F. Build and run progression

Routes feed builds through *what they offer*, not through new systems:

- **Peril** → more gold and higher luck → more rares earlier → the big-zone / burn / frost builds that scale with
  rarity; its modifiers punish greedy casts (row_burner, shroud), so a spatial-control build (push / pillars / traps)
  takes Peril cheaper.
- **Elite** → a guaranteed rare-floor offer and a relic — the lane for a build that needs one key card (e.g. han_ky for
  frost, tam_hop for joining).
- **Treasure** → relics and inks: the piece-deck build (shape clauses: line / square / plus / branched) is the one that
  most wants inks, so Treasure is its lane.
- **Safe** → HP preserved for a build that wins by attrition (thorns, wards, chi_khau healing).
- **Mystery** → events: curses-for-epics (`ke_buon_nguyen`), relic swaps (`ke_lang_thang`), removal tokens
  (`loi_the`) — deck-thinning builds.
- **Warden prep**: the approach gamble (miniboss) vs prepare (rest / shop); the briefing names the warden's traits so
  the player can shop for an answer (e.g. `burn_eater` warns a burn deck).

Nothing new is added to cards, relics or characters by this design.

---

## G. UX and player information

### G1. Screens

1. **Climb screen** (`WorldMapView`): keep the island strip. Replace the info panel with the **briefing**: region
   name, rule line with its icon, gauge preview (Heat: "starts at 0; fights +1, rest −1"), warden name + "2 phases" +
   fate status, shop-floor marker. Tap island = select, tap again / "Enter" = enter. Unchanged input model.
2. **Region map** (`ChapterMapView`, redrawn): HUD bar unchanged (HP, deck, blocks, gold, removals, gear). Route area:
   7 depths, 3 lanes as angular bands (parallelograms, no boxes around nodes, bare icons); hub and approach centred;
   edges as straight segments; cleared nodes ticked; available nodes bright; the selected node's preview panel in the
   bottom band where the info band is today; Enter button unchanged. Region gauge (if any) top-centre as an angular
   meter.
3. **Preview panel** (new content in the existing band): left the node icon + name; middle 3 rows: *Enemy* (name,
   role, "2×2" if footprint), *Arena* (shape thumbnail 5×5 pixel glyph), *Modifiers* (icons + 1 line each); right:
   reward tier stars and reward contents; objective line when present.
4. **Encounter intro band** (in battle, exists): add the modifier icons so the preview and the fight agree.

### G2. Touch rules (user's standing rules applied)

- Every input is a tap or drag; tap-select then tap-confirm on the same node or the Enter button (existing pattern).
- Hit rects ≥ 64 px at 720p (`ScreenLayout.CONTROL_HIT_PX`); lane bands are tappable to scroll the preview between
  the lane's nodes.
- Angular shapes only (parallelogram bands, diamond plates as today, chevron meters); no circles; bare icons on
  nodes, no boxes; stat glyphs as icon + number; effect text bare (no chips).
- Desktop extras (arrows, Enter, Escape) stay as dev conveniences.

### G3. What is shown vs hidden, and why

| Shown | Hidden | Why |
|---|---|---|
| whole graph, kinds, archetypes, reward tiers, modifiers, enemy name + role of the next depth | exact enemy ≥ 2 depths ahead **only** under a region rule (Mist / Sandstorm) | risk must be legible; discovery stays for region flavour |
| arena shape | arena variant (holes) | shape informs the build choice; the variant is combat texture |
| warden name, trait names, phase count | phase thresholds | prepare without a script |
| gauge value and its effect on the *next* node | gauge effect on the warden (shown as "warden: heat matters") | one-step lookahead keeps decisions local |
| shop presence (hub/prepare) | stock | planning gold, not min-maxing |

---

## H. Acceptance criteria (design-level; test mapping in 06)

1. For every region, floor and ≥ 1000 seeds: the graph has 14 nodes, 7 depths, 3 distinct archetypes, a hub, a
   prepare, a gamble, a warden reachable from every node, no dead ends. (automated)
2. The three lanes of any map differ in at least two of: expected gold, expected HP loss, rarity floor, relic
   access. (automated, from the templates)
3. A player on the region map can read, for every available node, its kind, archetype, enemy name, arena, modifiers
   and reward tier without entering it. (screenshot evidence)
4. The Hellfire Heat gauge changes vent timing in combat and reward tier on the map, and the player can see both
   before committing. (integration test + screenshot)
5. Same seed → identical map, identical profiles, identical rewards. (automated)
6. A v7 save loads as `needs_restart` with the existing notice; a v8 save resumes at every exit point. (automated)
7. Run length, gold earned and win rate across 70 seeds stay within the measured 7-floor baseline ± noise unless a
   tuning decision says otherwise. (simulation, 06)
