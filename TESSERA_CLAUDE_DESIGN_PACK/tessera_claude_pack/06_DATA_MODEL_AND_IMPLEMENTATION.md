# Tessera — Data Model, Generation, AI and Validation for Claude

**Do not conflate proposed design with code already shipped.** The code snippets below define a possible language-agnostic domain model (TypeScript pseudotypes) translatable to Godot 4/GDScript, Flutter+Dart or any engine. The existing game engine has **not** been chosen by these docs.

## 1. Combat domain model
```ts
type Tile = { x: number; y: number }; // zero-based, left-to-right, back-to-front
type GridSide = 'hero' | 'enemy';
type TileState = 'solid' | 'pit' | 'temporary_blocked';
type Rarity = 'common' | 'uncommon' | 'rare' | 'legendary';
type Hero = 'knight' | 'mage' | 'rogue' | 'ranger' | 'cleric';

type BlockShape = {
  id: string;
  offsets: Tile[]; // unique connected cells via 4-neighbor adjacency, size 1..7
  material: 'steel'|'charcoal'|'ice'|'wood'|'glass'|'ivory'|'odd';
  rotationQuarterTurns: 0|1|2|3;
  canReflect?: boolean; // only if explicitly granted by card
};

type Status = {
  type: 'burn'|'poison'|'slow'|'freeze'|'root'|'mark'|'guard'|'fragile';
  stacks: number; expiresAtBeat?: number;
};

type DeliveryType = 'CASTER_TO_TARGET'|'SKY_TO_TARGET'|'GROUND_PROPAGATION'|'DIRECT_MANIFESTATION'|'SEQUENTIAL_CHAIN';

type Delivery = {               // 01 §1A, LOCKED 2026-11-01
  type: DeliveryType;
  origin: 'caster'|'sky'|'origin_cell'|'target_cells'|'first_cell';
  travelAnim: string;          // square-based visual id; never the gameplay Block object
  impactAnim: string;          // slash, burst, shatter, burn, freeze, poison, knockback, guard...
  cellMask: 'block_shape';     // only these cells are affected; the path deals no damage
  chainOrder?: 'nearest_first'|'row_major'|'authored'; // SEQUENTIAL_CHAIN only
};

type Ability = {
  id: string; name: string; tags: string[];
  owner: 'hero'|'normal'|'elite'|'boss';
  targetSide: GridSide | 'self';
  shapeRule: string; // e.g. any, L3, bar4, cross, line3, T4, dynamic
  windupBeats: number;
  resolvedEffects: Effect[]; // data-driven, no direct rendering logic
  warningMask: 'targeted_cells';
  delivery: Delivery;          // required for every player, enemy and boss skill
  cooldownBeats?: number;
  costs?: { energy?: number; token?: boolean };
  constraints?: { minSafeTiles?: number; needsValidPath?: boolean };
};

type Effect =
 | { kind:'damage'; amount:number; on:'each_target_actor_once' }
 | { kind:'apply_status'; status:Status }
 | { kind:'shield'; amount:number }
 | { kind:'push'; cells:number; rejectPit:true }
 | { kind:'terrain'; state:TileState; durationBeats:number; onlyEmpty:true }
 | { kind:'repeat'; delayBeats:number; damageMultiplier:number; noProcRecursion:true }
 | { kind:'gain_energy'; amount:number; capPerBeat:number };

type Enemy = {
  id: string; landId: string; tier: 'normal'|'elite'|'boss';
  logicalOccupiedTiles: 1; hp: number; skills: string[];
  visualSilhouette: string; counterplay: string;
};

type RoomNode = {
  id:string; type:'battle'|'elite'|'treasure'|'merchant'|'camp'|'event'|'forge'|'boss';
  tier:number; row:number; lane:number; linksTo:string[];
  encounterId?:string; rewards?:string[];
};
```

## 2. Grid and Block invariants (tests Claude must add)
- Grid X increases left-to-right and Y back-to-front; all slab rectangles identical; move, cast and effects reference **logical cells**, never image pixel positions.
- `assert 1 <= shape.length <= 7`, all unique offsets, orthogonally connected; rotation applies `(x,y) -> (-y,x)` then normalize min X/min Y to 0.
- `place(shape,anchor)` returns all cells in bounds, solid and not temporarily blocked; **no clipping** for player cards unless explicitly authored. Shape can be previewed in invalid state but not committed.
- Monster warning should be computed from resolved geometry; for a special skill that allows clipped masks, do so *at design time and show exact final cells*.
- Tile row/column counts are independent of sprite scaling; character's feet occupy 1 cell. A sprite may overlap row behind without changing logic occupancy.
- Rendering order: background -> back slabs -> characters on each row -> floor-target outlines/warning overlays that must be visible above character parts -> HUD. This order may need multiple overlay passes to keep warnings on top.
- Valid boss attack: at least 1 escape tile reachable for a movement-evadable move within windup time OR an accessible defense guaranteed. For team encounters, evaluate union of concurrent warnings.
- Terrain collapse: never convert currently occupied cell into pit without explicit fall-and-return design. In prototype restrict to empty cells, warn in advance, restore after N beats.

## 3. Data-driven attack lifecycle
```text
ENEMY_IDLE
  -> choosePattern(seed, heroTile, currentPhase, arenaSafeCells)
  -> validate(counterplayReachability)
  -> WINDUP (show animation, no hit)
  -> WARNING (same immutable set of tile coordinates as hit)
  -> DELIVERY (visual travel from the skill's origin; no damage on the path)
  -> RESOLVE (impact effect, damage/status on warned cells only)
  -> OPTIONAL FOLLOWUP (new warning before any secondary hit)
  -> RECOVERY -> IDLE
```

Patterns need explicit `anchor`, `rotation`, `offsets`, `targets`, `warningStart`, `resolutionBeat`. Snapshot at warning time. If a hazard invalidates cells after warning, cancel or visibly revise warning before hitting; never move target invisibly.

## 4. Suggested roguelike map generation algorithm
1. Seed RNG; choose one of two available **named regions/routes** for each tier based on prior user choice.
2. For selected region build 5 rows of 2–3 candidate nodes; start with guaranteed `battle`, end in `boss`; node types and edges generated under constraints.
3. Guarantee one source of coins before first `merchant`, and one `camp` or `forge` opportunity before boss. Optional elite lane with preview icon.
4. Link each node to one or two reachable next-row candidates; verify graph is acyclic, every node can reach the boss, no orphan nodes.
5. Generate encounters from land's enemy roster and tag difficulty; elite appearance after at least 1 normal teaching skill.
6. Final validate difficulty budget and note player route history; expose deterministic run seed for save/replay debugging.

Proposed node-type weight for nonfixed rows: `common 45%`, `elite 12%`, `treasure 14%`, `merchant 10%`, `camp 10%`, `event 6%`, `forge 3%`; **not independent probabilities across all rows**. Apply constraints first and sample only valid candidate types.

## 5. Proposed encounter budgets
`encounterThreat = sum(unitDanger) + boardHazardDanger + synergyDanger`.
- A single normal = 1.0; a second normal = +0.7; one elite = 1.9; elite + helper normal = 2.4; two elites **not supported by default**.
- No elite in first room; at least one safe route per region.
- Limit active red warned terrain cells per beat to ~45–60% of usable hero floor in ordinary encounters; exceptions must give accessible guard or staged warning with a known escape.
- Track per-enemy primary attack frequency; disallow excessive Root+Freeze overlap and two unavoidable pushes toward pits.

## 6. Combat AI pseudocode
```ts
function chooseEnemyMove(enemy, state, seededRng) {
  const candidates = enemy.skills
    .filter(id => isSkillAvailable(id, state))
    .map(id => ({id, plan: buildPlan(id, state)}))
    .filter(x => x.plan.valid && canHeroRespond(x.plan, state));
  if (!candidates.length) return {type:'wait'};
  return weightedChoose(candidates, seededRng, {
    punishStandingStill: 1.2,
    avoidRepeatLastSkill: 0.45,
    favorPhaseMechanic: 1.25,
    neverHideFinalWarning: true
  });
}
```
All selection weights need actual playtest tuning, never used to fabricate impossible unavoidable attacks.

## 7. Event hook discipline (prevent combo exploits)
Event envelope: `{actionId, parentActionId?, sourceCardId, owner, targetCells, flags}`. Rule `noProcRecursion` on echo/chain child attacks. Resource gains capped per beat and by source. If a card makes three separate tile hits, statuses should specify per tile, per target, or per cast explicitly.

## 8. Skill/art production schema
Each card/monster skill should have:
```yaml
id: forest_root_nail
land: misty_forest
owner: boss
shape: [{x: 0, y: 0}]
side: hero
telegraph_color: '#E5293B' # only on attacked floor tiles
telegraph_style: red_diagonal_2px_outline
cast_pose: boss_empty_hands_one_back_one_forward
windup_beats: 1.0
delivery: GROUND_PROPAGATION      # 01 §1A; not every skill is SKY_TO_TARGET
origin: caster_feet
travel_visual: root_squares_along_slabs
cell_mask: shape
impact_visual: square_shards_ivory
on_hit: [{type: damage, amount: 8}, {type: root, duration_beats: 1}]
recovery_beats: 0.8
counterplay: move_to_adjacent_unwarned_solid_cell
```

## 9. Test cases / acceptance criteria
- All 180 player cards have stable unique IDs, group, affinity, shape rule, rarity, effect, and tags.
- 8 lands have enemies with 23 normal and 16 elite archetypes; 8 bosses each have skills + phase behavior.
- All boss skills allow a valid response on each supported arena configuration, including 3×3 and 5×4 pit maps or explicitly restrict their arena size.
- No card spawns >7 connected cells, no skill targets an unannounced pit, no negative currency, no infinite proc loop.
- A generated run must produce playable paths in 10k seeded generation tests, guarantee shop access and rest/forge opportunity under the declared policy.
- Each attack VFX resolves into **tile squares**; no beam or circle VFX. Traveling visuals are square-based, never the gameplay Block, and never apply damage or status outside the cell mask. Every skill declares delivery type, origin, travel, impact and cell mask. Red used only for hostile warning cells.
- Screenshot tests: equal slab rectangle geometry, exact palette families, outlines on characters only, separate grids and fully visible warning overlays.

## 10. Balancing checklist before production
- Telegraph time vs input latency on actual Android devices (touch swipe, move responsiveness).
- Player starting damage vs earliest common/elite attack and survivability.
- Block-bar weighting: ensure any acquired skill can receive compatible shapes often enough, or provide a deterministic fallback token.
- Reward path: coin economy, merchant access, deck bloat and removal, dead card prevention.
- Advanced boss board shrink should be a **tactical puzzle**, never a no-solution death check.
- Add internal balance analytics: card pick-rate, win-rate by hero/build, elite path choose-rate, boss deaths by skill/pit, per-room duration, frequency of unavoidable situations.
