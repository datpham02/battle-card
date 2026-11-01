# Copy-and-paste tasks for Claude

## A. Initial architecture audit
> Read all files in this directory in README order. Separate LOCKED canon from PROPOSED mechanics. Summarize contradictions or unanswered high-impact decisions (especially Skill Card vs Block Token, active battle timing and 5 tiers/2 choices). Do not implement anything yet. Produce a 1-page architecture decision record with safe defaults and risks.

## B. Vertical slice / playable demo
> Implement one playable vertical slice of Tessera: Misty Forest region, deterministic 3×3 two-sided grids, Knight + Mage starter skills, 3 normal monsters + 2 elite monsters + Forest Witch Warden, 5-node branching map with Common Battle/Elite/Chest/Merchant/Camp/Boss, and 20 representative player cards from `05_PLAYER_CARDS.md`. Start with pure unit-testable grid/shape math, then telegraphed combat, then presentation. Keep canon art rules. Produce unit tests and debug seed logs. Do not silently implement remaining 160 cards.

## C. Enemy expansion by land
> Add one region at a time from `03_ENEMY_ROSTER.md` and its Warden from `04_WARDENS_AND_BOSS_SKILLS.md`. For each enemy write data (HP, cooldown, warning cells, behavior state machine), telegraph animation sheet spec and one counterplay test. Add at least one generated encounter involving each new normal + elite. Check no undodgeable warning patterns.

## D. Full card-system spec
> Read `cards.json` (180 proposed ideas) and derive a data-driven schema. Find duplicates, vague effects and contradictions; rank a subset of 60 MVP candidates for five heroes and shared deck. Implement trigger caps, Block/token compatibility, hero-affinity, upgrade transformations and a weighting algorithm for bar drops. Produce a balance workbook only if requested, otherwise JSON plus markdown implementation notes.

## E. Map generator
> Use `02_ROGUELIKE_MAP_AND_ECONOMY.md` to implement five-tier route selection and seeded 5-row DAG node generation. Each chosen land has 3 normal + 2 elite archetypes (Summit 2 normal + 2 elite), its named Warden, merchant, chest, camp, event, and optional elite. Validate every generated route offers a path to boss, one early coin source, no forced elite, a late camp or forge and viable deck growth. Test at least 10k seeds. Do not invent additional canon lands without approval.

## F. Asset and UI handoff
> Turn each monster, Warden and card into a PixelLab-ready asset specification: small true-size frame dimensions, 6x nearest-neighbor inspection scale, palette, silhouette, two-frame readable windup, square-only impact frames, warning mask coordinates, and layered background. Distinguish concept illustration from production sprite sheet. Avoid decorative runes/text and glowing environment.

## G. Skill delivery pass
> For every player card, enemy skill and boss skill, fill in delivery type, origin, travel animation, impact animation and affected cell mask per `01_CANON_AND_COMBAT_SYSTEM.md` §1A. Do not default to `SKY_TO_TARGET`. Add a test that a delivery path never applies damage or status outside the cell mask, and that no skill throws the gameplay Block object.

## What to decide with designer before coding
1. Is the card bar a stream of **Skill Cards**, **Block Tokens**, or a combined sequence?
2. Are Skill Cards consumable, cooldown-based, or permanently equipped actions during a battle?
3. How many simultaneous player Block/Skill slots are allowed on a 640×360 phone screen?
4. Is a run expected to clear all five tiers, or can players checkpoint/shorten to three tiers?
5. Should all 5 heroes share an 180-card pool or use 100 shared + 80 hero-specific as a starting ratio?
6. Is the canonical Warden boss arena 3×3, 5×4, or variable by land?
7. Does a defeated boss grant a new Block material, artifact, or a permanent meta-progression option?

These are **open design questions**, not blockers for the initial prototype; choose temporary documented defaults if the user wants coding immediately.
