# TESSERA — Design knowledge pack for Claude

**Purpose:** Produce a coherent roguelike, real-time grid-combat mobile game design. Treat these files as a *design proposal and data seed*, not as already implemented gameplay. Canon marked `LOCKED` must not be silently altered. All balance numbers are `PROPOSED / TUNE IN PLAYTEST`.

## Read order
1. `01_CANON_AND_COMBAT_SYSTEM.md` — setting, style rules, combat grammar and card/block interaction.
2. `02_ROGUELIKE_MAP_AND_ECONOMY.md` — tiers, branching rooms, choices, reward/shop/events and safeguards.
3. `03_ENEMY_ROSTER.md` — normal and elite monsters per Warden, moves and counters.
4. `04_WARDENS_AND_BOSS_SKILLS.md` — all eight bosses, distinct phases and skill telegraphs.
5. `05_PLAYER_CARDS.md` — 180 proposed player cards, split into six categories.
6. `06_DATA_MODEL_AND_IMPLEMENTATION.md` — ready-to-code typed data, generation and AI rules, tests.
7. `07_CLAUDE_TASKS.md` — exact prompts/tasks to give Claude for incremental implementation.

Supporting data: `cards.json`, `enemies.json`, `bosses.json`; optional for programmatic import. Source of conceptual truth is Markdown. The machine-readable examples are seed designs, not final balance data.

## Important design decisions
- **Skill Card ≠ Block Token.** A Skill Card defines *what happens*; a Block Token (1–7 connected square cells) defines *where it happens*. Their composition creates build diversity. This separation is a **PROPOSAL**, not confirmed canon, and should be validated before implementation.
- Tessera is a **mobile landscape active battle game**, not automatically a turn-based deckbuilder. `beats`/`seconds`, cooldowns, card-bar flow, and stamina in this pack are proposals.
- Common and elite enemies attack through the exact same square-grid grammar as bosses. There are **23 regular enemy archetypes and 16 elites** across 8 regions (including the summit), with **8 Warden bosses**.
- Every boss has its own enemies, elite variants, and traversal choices. No generic filler encounter should overpower region identity.
- The prior map concept called for *five tiers with two lands per tier*, but only seven regional Wardens + the summit are canon. The map plan uses **two choices of route** in tiers four and five rather than inventing new Warden lands. This preserves the named world.

## Constraints for Claude
- Reuse exact color and pixel guidelines. Do not introduce wuxia/xianxia, red attacks (except warning tiles), round spell explosions, beams, glowing scenery, floor perspective, runes or letters in rendered art. Traveling square-based skill visuals are allowed under the skill casting rules (`01` §1A, 2026-11-01); the gameplay Block object is never thrown.
- An `L` pattern needs an explicit number of cells; there are L-shaped triominoes (3) and tetrominoes (4). Do not interchange them.
- A card effect must specify pattern, target rules, timing, stacking, status interactions, telegraph, counterplay, and upgrade path before implementation.
- Never assume an attack can target a pit. Pit tiles are not valid attack/support locations unless a move *explicitly* changes terrain.
- Don't have character sprites hold or throw Blocks when using hero magic: the target cells illuminate as the cell mask, and the skill's delivery (`01` §1A: caster-to-target, sky-to-target, ground propagation, direct manifestation or sequential chain) carries the visual from its origin to those cells. Normal monsters may telegraph overhead flat block per canon; particular boss cast poses have **empty hands**.

## Suggested implementation sequence
1. Deterministic grid and polyomino placement; selection and overlapping-characters warning rendering.
2. Timed telegraph/cast/resolve pipeline; unified abilities and status rules.
3. One land vertical slice: Misty Forest, 3 common + 2 elite + Warden; branch/shop/reward/rest.
4. Player card & block token system and build screen, starting with a small tested subset.
5. Expand content land-by-land with data-driven assets, localization and balancing.
6. Full 180-card pool only after telemetry, card-draw flow, and encounter pacing stabilize.
