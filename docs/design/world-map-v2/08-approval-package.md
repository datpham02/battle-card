# 08 — Approval package: World Map v2 (2026-11-11)

Entry point for the user's review. Status: **design complete, awaiting approval**. No gameplay source, game data,
test or save format was modified. Implementation starts only after the decisions in §E are answered.

## A. The proposed experience, start to finish

1. **Title → character → climb screen.** The Tower Ascent strip shows seven islands in the fixed order Misty Forest
   (1), Hellfire (2), Buried Sands (3), Poison Swamp (4), Dungeon (5), Ice Tower (6), Sky Isles (7) and the Lattice
   Heart summit. Tapping the current island opens a **briefing**: the region's rule in one line, its gauge if any,
   the warden's name, trait names and phase count, the spare/execute tally so far, whether this floor's hub holds a
   shop. Tap "Enter".
2. **Region map.** A fixed layout of 14 nodes in 7 depths: one entry battle; three **lanes** (2 nodes each) with a
   declared archetype — Safe, Treasure, Peril, Elite or Mystery (3 of the 5 per map, never three hostile ones); a
   **hub** every lane passes through (rest, shop or event; shop on shop-plan floors); one more lane node; an
   **approach** of two nodes (prepare = rest or forge, gamble = elite fight); the **warden**. Every node is visible
   with its kind, archetype band and reward tier; tapping a node shows its preview (enemy, arena, modifiers,
   reward, objective). Region rules may hide the enemy of far nodes (Mist, Sandstorm) but never the kind or tier.
3. **Choosing.** Tap a lane's first node, tap again or "Enter". Committing to a lane means two nodes before the hub;
   at the hub the player may switch lanes for the last node; at the approach they choose between preparing and
   gambling. A region visit is 7 nodes, as today.
4. **Resolving.** Fights use the existing roster through an **encounter profile**: the match id drawn from the same
   pools and tiers, its own arena, 0–1 modifiers from the region's pool (0–2 before the 2026-11-12 tuning pass) (all existing traits or hazard numbers),
   an optional objective, a reward tier. Non-fight nodes keep their current screens; **forge** is the new one
   (ink choice + one free shape removal). Rewards: today's tables at tier 1; Peril and Elite nodes pay tier 2–3
   (more gold, a rarity floor, a relic row on the top tier).
5. **Region rule.** Hellfire's **Heat** gauge (0–4) rises with fights and falls at rest/shop; it shortens vent
   intervals, raises burn ticks, adds a vent surge at 4 — and lifts the reward tier of the next fight at 3+. The
   player sees the heat before and after every node. The other six regions get one rule each (Mist, Sandstorm,
   Sink, Locks, Cold, Gale) built after the slice.
6. **Warden → fate → climb.** Unchanged: fate (spare/execute), boss reward, 60 % heal, next island. Build
   progression comes from what lanes offer (gold and luck on Peril, a relic and rare floor on Elite, inks on
   Treasure/Forge, events on Mystery, HP on Safe), not from new systems.
7. **Summit.** Unchanged: the final prelude shop, then the Lattice Heart keeper; the ending by spare ratio.

Why it is better than today in one sentence each: lanes make a node choice a *route* choice; previews make risk
legible; tiers make risk pay; the rule gives each region a lever the player pulls; nothing in combat changes.

## B. Architecture

| Component | Kind | Owns |
|---|---|---|
| `MapGraph` **(new)** | pure data wrapper | nodes by id, edges, depth/lane lookups, `to_dict`/`from_dict`/`clean` |
| `RegionMapGen` **(new)** | pure, seeded | archetypes → lanes/hub/approach/warden → match ids (the existing draw rules, moved) → modifiers, objectives, tiers → region map effect → edges |
| `MapValidator` **(new)** | pure | every BLOCK rule of `06` §2 + metrics |
| `EncounterComposer` **(new)** | pure | node ids → match patch / arena patch / preview / objective check |
| `RegionRules` **(new)** | config | `region_rules.json`: rule per region, gauge steps, combat patch by gauge, modifier catalogue |
| `RunSession` (existing) | run state | position by `node_id` + `cleared_ids`, `rule_state`, save v8; v1 column path kept behind the wrapper |
| `RunConfig.from_node(…, profile)` (existing) | scaling pipeline | applies the profile patch beside the danger step; `_clean_match` + one key |
| `GameFlow` (existing) | orchestration | node-id API, seeds by node id, forge flow, objective recording, per-region `map_gen` switch |
| `ChapterMapView` / `WorldMapView` (existing files) | views | lanes, preview panel, gauge meter; briefing |
| `ChapterMapGen` (existing) | legacy generator | kept, deprecated after sign-off |

Data flow: `chapters.json` + `route_archetypes.json` + `region_rules.json` → `RegionMapGen.generate(spec, seed)` →
`MapGraph` (saved) → `RunSession` position → `EncounterComposer.profile(node, gauge)` → `RunConfig.from_node(profile)`
→ `RunController` → `CombatView` (unchanged) → `get_match_stats()` → objective → rewards by tier.

Save/load: `RunSession.SAVE_VERSION` 8; both map forms; v5–v7 saves take the existing `needs_restart` path (ADR-0001's
rollout note already prescribes "start a new run on version change"); every existing save point kept; resume at
every exit point tested (U25, I3). v1 regions keep byte-identical arena seeds.

Migration: two generators behind one graph API, switched **per region** (`region_rules.<id>.map_gen`), so the slice
runs Hellfire on v2 inside an otherwise v1 run. Full flip only after `06`'s gates.

## C. Implementation plan (summary of `05`)

| Step | Concern | Exit criterion | Deliverable |
|---|---|---|---|
| 0 | tooling | 7-floor v1 baseline recorded (needs `--region-pick=order`, D15) | `baseline-7floor-v1.md` |
| 1 | graph | wrapper turns every v1 map into a valid graph (200 seeds × 7 pairs) | `MapGraph`, loaders, validator |
| 2 | graph | 10 000 seeds × 7 pairs valid; Hellfire route metrics | `RegionMapGen`, `map_sim` |
| 3 | encounter | existing flows green with an empty profile; Peril profile applies | `EncounterComposer`, `from_node(profile)` |
| 4 | run state | save v8 round-trips at every exit point; mixed v1/v2; old saves restart | RunSession v2 + save |
| 5 | flow | slice runs headless end to end with saves | GameFlow node-id API, forge |
| 6 | rule | heat 4 → vent 4 s in a real match | Heat |
| 7 | rewards | Peril net value ≥ Safe + 25 % with HP cost in band | tiers, elite relic, objective bonus |
| 8 | UI | retained screenshots E1–E6 | lanes, preview, gauge, briefing |
| 9 | validation | BLOCK metrics met or deviations documented → flip decision | reports |

Dependencies: 0 ∥ (1 → 2 → 3); 4 needs 1–2; 5 needs 3–4; 6 needs 3, 5; 7 needs 5–6; 8 needs 5 (6–7 for gauge/tier
previews); 9 needs 0, 2, 7, 8. Each step closes with the report format the user asked for.

## D. Validation strategy (summary of `06`)

- **Baseline first** on the real climb order (the shipped sim picks regions at random; one tool flag fixes that).
- **Technical correctness [BLOCK]**: reachability, slots, pools, tiers, shop plan, determinism, p50/p95 generation
  time, save round trips, old-save restart, mixed generators, full suite green, parse check.
- **Balance and risk/reward [BLOCK]**: paired v1/v2 on 70 seeds × 5 characters; net value in gold-equivalent (gold,
  cards, relics *acquired*, inks, combat HP loss, route HP cost, death risk × run value); Peril vs Safe; Heat
  reachability and warden win % by heat; run-level guard (TD-027).
  *Post-approval note (B1, 2026-11-12):* the approved warden hook "`vent_surge.vents` 3 at heat ≥ 3" could not take
  effect (the caldera has 2 vents per half; `TileHazards.trigger_vents` clamps); the shipped hook is now
  `vent_surge {interval_sec 7, first_delay_sec 10}` with 2.5 s eruptions at heat 4 and the 1.0 s warning unchanged —
  `production/qa/evidence/world-map-v2/warden-heat-hook-investigation-2026-11-12.md`. Proposed for the human playtest,
  not balance confirmed by it.
- **Replayability [INFO]**: distinct archetype triples, distinct lane profiles, distinct match ids per map.
- **Information sufficiency [INFO]**: two oracles restricted to pre-decision information (preview-only, expert),
  agreement with hindsight.
- **Gameplay quality**: played checks per step (lane legibility, Heat changing decisions, floor-2 route felt on
  floor 3, "just a stat" modifiers removed) — recorded, never claimed as numbers.
- No target is reported as met without the output file that proves it.

## E. Decisions requiring the user's approval

| ID | Question | Options | Recommendation | Consequences |
|---|---|---|---|---|
| D1 | Region layout: 3 lanes (2+1 nodes) + hub + approach (prepare/gamble) + warden, 14 nodes, 7 visits | (a) as proposed · (b) pack's 5 rows × 2–3 random candidates · (c) keep 7 columns, add previews only | **(a)** | (a) readable routes, same run length; (b) texture without identity (today's problem); (c) smallest change, no route identity |
| D2 | World level: fixed 7-region climb (code, user 2026-11-07, this brief) vs ADR-0001 D3 "5 tiers × 2 lands" (user 2026-11-01) | (a) keep the climb, amend D3's world line · (b) return to 5 tiers × 2 · (c) 7 regions but "1 of 2" order per floor | **(a)** | (a) no world-screen work; (b) 5 lands per run, two regions never seen, climb screen redone; (c) `offer_for_floor` already exists, briefing gains a choice; shop plan and floor scaling unchanged |
| D3 | The five archetypes and their templates (`03` §3) | (a) as proposed · (b) three archetypes (safe/treasure/peril) first | **(a)** as starting templates | (b) loses the elite/relic lane and the event lane; fewer distinct triples |
| D4 | Vertical slice = Hellfire floor 2 with Heat; Heat numbers as sim starting values | (a) Hellfire · (b) Misty Forest floor 1 (pack's suggestion) | **(a)** | (b) entangles onboarding and the pattern-brain roster; no gauge mechanic available without new combat code |
| D5 | Save v8; v5–v7 saves restart with the existing notice (no converter) | (a) restart · (b) write a v7→v8 converter | **(a)** (ADR-0001 rollout note agrees) | (b) ≈ 1 session of work for in-development saves |
| D6 | Reward tier table, luck per tier, elite relic offer (`01` §E2–E3), all gated by S2 | (a) as proposed · (b) tiers without luck bonus | **(a)** | luck bonus reaches the 31/35/34 anchor ~10 nodes earlier on full-Peril runs; (b) safer, less payoff |
| D7 | Modifier catalogue (`03` §4) and objectives; two objectives need two new CombatView counters | (a) all four objectives (small combat change) · (b) only `no_hit_3`, `joiner` in the slice | **(a)** | (b) no Heat-specific objective (`vent_dancer`) in the slice |
| D8 | Rules for the other six regions (`02` §3–§8) as direction only | (a) approve direction · (b) defer entirely | **(a)** | nothing is built for them in the slice either way; (a) lets the data schema carry their map effects |
| D9 | Region questions: D-R1 Heat numbers; D-R2 Mist hides on floor 1 (recommend **no**); D-R3 Swamp toll HP vs gold (recommend HP); D-R4 Dungeon collapse permanent vs regrow (recommend permanent) | per item | as noted | D-R2 affects onboarding; D-R3 decides whether Swamp or Desert is the economy region; D-R4 is the only new combat code among the six |
| D10 | New data files `route_archetypes.json`, `region_rules.json`; `world.map_gen`, `world.depth_layout` | (a) approve · (b) fold into `chapters.json` | **(a)** | (b) grows a 2 000-line file; harder to diff |
| D11 | `forge` node kind (ink + free removal) in the slice; its display name (rest's "Rèn" is taken) | (a) in the slice, name e.g. "Lò Khối" · (b) after the slice | **(a)** | (a) one new screen state (reward screen without cards — unverified, fallback exists); satisfies ADR D3 |
| D12 | Record the approved design as ADR-0003 and amend ADR-0001 D3's world line at step 1 | (a) yes · (b) no ADR (`modes.workflow: minimal`) | **(a)** | (b) leaves D3 contradicting the code |
| D13 | Prepare slot when the hub is a rest | (a) `forge` · (b) a second `rest` · (c) `event` · (d) `shop` regardless of the plan | **(a)** | (b) doubles the heal budget vs today; (c) random cost before the warden; (d) breaks "≤ 5 shops" |
| D14 | `economy.json` `gold_floor_mult` / `price_floor_mult` have 5 entries for 7 floors | (a) keep the clamp (no data change) until S2 · (b) extend to 7 entries now | **(a)** | (b) is a gameplay-data change this task is not allowed to make; (a) means floors 5–7 share ×1.4 as today |
| D15 | Tool changes to `deck_sim` (`--region-pick=order`, `--route-policy=`) — tool code, not gameplay | (a) allowed as step 0 · (b) baseline with random order | **(a)** | (b) the baseline would not represent the shipped climb |

Open region questions D-R1..D-R4 are repeated under D9 so nothing hides in `02`.

## F. Risks and assumptions

### F1. Verified current-source facts (audit `00`, consistency `07`)
7 floors, fixed order, 7-column OSFE-linked maps; node = `{kind, match_id, next}` by `(column, index)`; save v7 /
progress v8, three slots, `needs_restart` below v5; combat 1v1; hazards on arena shapes; `_clean_match` whitelist
(`MATCH_KEYS`, 19 `HAZARD_OVERRIDE_KEYS`); 22 registered traits incl. `vent_surge {interval_sec, vents}`;
`TileHazards.clean` validates `vent_interval_sec` / `vent_tick_damage`; `RelicRoller.roll(source, owned, rng, config,
count, min_rarity, locked)`; `RunSession.remove_shape(id, spend_token, …)`; `GameFlow.remove_shape` spends a token;
ink row lives in `RewardView`; `CombatView.get_match_stats()` keys; `deck_sim` flags and its random region pick; 271
SceneTree tests; all balance evidence is 5-floor.

### F2. Design proposals (this package)
Lanes/archetypes/hub/approach layout; encounter profiles; reward tiers; Region Rule system and seven configurations;
forge node; preview contract; UX rules; every number in `01`–`03` and `06`.

### F3. Unverified technical assumptions — and how each is verified
| Assumption | Verified when |
|---|---|
| `RewardView` renders a reward with 0 card offers and an ink row (forge screen) | step 5, U31; fallback: ink row on the piece-deck screen |
| Per-match hazard overrides reach `TileHazards.configure` in a spawned battle (comment at `combat_view.gd:621` says so; not stepped through) | step 6, I2 asserts the cfg values in a real match |
| `KiepRules.apply_map_spec` can grow a v2 branch without touching the v1 branch | step 2, U8 (Kiep 3 case) |
| `ArtAssets.area_for(column, size, kind)` accepts depth as column for v2 maps | step 5, I1 (art area per node) |
| `ChapterMapView` can draw 3 lane bands + preview inside `ScreenLayout.map_route_rect` at 720p with ≥ 64 px hit rects | step 8, E2 screenshot + hit-rect assertion |
| Two new `CombatView` counters (`max_cast_cells`, `vent_cells_stood`) are cheap to add where casts/vents resolve | step 3, U16 |
| `deck_sim` world mode can take `region_order` and a route policy without disturbing its tables | step 0, S0 (old output byte-equal without the new flags, as the tool's own rule) |
| Save size < 32 KB with profiles on 14 nodes | step 4, U27 |

### F4. Risks that need a prototype or a playtest
- Whether three lanes read as different *in play*, not only on paper (step 5 played check).
- Whether Heat changes standing and casting rather than only damage taken (step 6 played check).
- Whether Peril's payoff is felt on floor 3 (step 7 paired probe + played check).
- Bot-dependence of every balance number (TD-006 dodge 0.85; `--dodge` sweep in §6 of `06`).
- Run length: 7 visits per region keeps today's count, but tier rewards and the forge may lengthen the out-of-match
  time; the baseline minutes are the yardstick.

## G. Implementation readiness

**Ready for approval.** Nothing technical blocks step 0–2 (tooling and pure generators). Steps 3+ depend on
D1–D7, D10–D13 being answered; D2 and D12 decide one ADR amendment; D14–D15 decide a data clamp and a tool flag.
No decision in §E is pre-empted by the documents: every number is a starting value gated by `06`, every proposal is
marked, and no test or simulation result is claimed.

Documents: `README.md`, `00-current-state-audit.md`, `01-game-design-spec.md`, `02-region-design.md`,
`03-encounter-system.md`, `04-technical-architecture.md`, `05-implementation-plan.md`, `06-validation-plan.md`,
`07-consistency-review.md`, this file.
