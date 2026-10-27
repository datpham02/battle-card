extends SceneTree
## Full-run balance simulator (Story 026 port of the Story 022/023 scratch deck_sim to the v5 rules).
## Each run = one chapter map with the starter deck: ChaptersConfig.generate_map -> RunSession.begin ->
## per column the bot's node choice -> a match (RunConfig.from_node, played by the v5 bot in sim_core.gd)
## or rest / treasure -> RunSession.complete_node -> the reward of the node kind (RewardRoller) under the
## policy. Runs seeds x characters x chapters and prints the same tables as the rune-era sim so old and new
## numbers can be compared, plus a few v5 columns at the end of the main table.
## Policies: always_skip (rolls every reward, takes nothing; chapter 1 only) and build (upgrade the best
## damage card; else remove the weakest card with a token when the deck is big; else the best new damage
## card; else the deck's keyword). Node policy: treasure > rest (heal below REST_HEAL_BELOW of max HP,
## else forge) > miniboss at >= MINIBOSS_MIN_HP > battle > danger (danger first with >= DANGER_BURN_CARDS
## burn cards) > miniboss / boss when alone.
## Story 027: the build policy takes an offered zone card (seal / thorns) right after an upgrade pick, at
## most ZONE_PER_EFFECT per effect in the deck (seal before thorns, higher damage_per_cell first);
## --no-zone-cards drops the zone cards from the reward pool and the decks (the "before" measurement).
## Story 031 --world: a run = `world.floors` floors (pick 1 of the WorldMapGen offer per floor, bot pick
## --region-pick=random|first, seeded) of short region maps (ChaptersConfig.generate_region_map), then the
## final floor (TD-029: the `world.final_prelude` columns, a shop, through the same shop / node policy as
## the region maps, then the final match `world.final_match`); every match RunConfig.from_node(..., floor); a region boss gives the
## boss reward and heals `floor_heal_ratio` x max HP instead of ending the run. Runs its own run state
## (WorldRun below), not RunSession. --world-set=key:value overrides the `world` / `region_normalize`
## data in memory (chapters.json is never written).
## Story 032 relics: --relics=id,... (sim_core) = the bot owns these relics from the start of every run, and
## every match of the run gets the run's relics (sim_core.relic_ids -> sim_core._setup_relics, the port of
## CombatView._setup_relics). --relic-policy=pick: at a treasure node the bot takes the RELIC row
## (RelicRoller.roll("treasure", owned, rng), rng seeded like GameFlow: hash([run_seed, floor, column,
## node_index, "relic"])) over the card row, rarest first (boss > epic > rare > common, then offer order);
## an empty relic row falls back to the card row. Default --relic-policy=none (card row only).
## Tool code only (not game code, not in the test suite). Flags and output: tools/balance/README.md.
## Usage: godot --headless --path . -s res://tools/balance/deck_sim.gd -- --seeds=70 --chapters=0,1,2 --policies=build
## Story 033 economy (world mode): every won match node and every treasure drops gold through EconomyConfig
## exactly like GameFlow._drop_gold (kind, floor, seed hash([run_seed, floor, column, node_index, "gold"]));
## --shop-policy=greedy|none and --event-policy=risky|leave drive the SHOP / EVENT nodes through ShopLogic /
## EventLogic on a RunSession proxy of the WorldRun (see _session_of). Curse cards are dealt and hurt in
## sim_core like CombatView; run modifiers (loi_the) reach sim_core.run_modifiers. --economy-set=key:value
## overrides economy.json in memory (README).
##        godot --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --characters=kiem_si
## Story 040 (README "Story 040"): `--run=v6 --floors=a..b --final=on|off --mercy=kill|spare|mixed --shop=on|off --pieces=on|off
## --relic=value|random|none --dodge=a,b,c --tables=v6|none` (world mode). They add bot policies (value / random relic pick, a
## piece-deck policy, shop extras), the v6 out-of-match time table and the RUN / REGION x FLOOR / RELIC LIFT / SHOP / VERDICT run /
## DODGE SENSITIVITY tables (the block at the end of this file). No such flag = the old output, byte for byte.

const SimCore = preload("res://tools/balance/sim_core.gd")

const DEFAULT_SEEDS: int = 70
const POLICIES: Array[String] = ["always_skip", "build"]
const CHARACTERS: Array[String] = ["kiem_si", "phap_su", "sat_thu"]
## Story 037: the two milestone characters. `--characters` accepts them; the default list stays the three open ones,
## so every older command line is unchanged.
const NEW_CHARACTERS: Array[String] = ["tho_san", "giao_si"]
## Story 037 unlock-runs mode: defaults and the story target (mean runs to open a new character).
const UNLOCK_DEFAULT_REPS: int = 30
const UNLOCK_TARGET_RUNS: Array[float] = [1.0, 3.0]
## Story 037 Part F: a new character's run win % must sit within this many points of the mean of the three open ones.
const NEW_CHARACTER_WIN_BAND: float = 10.0
## Main runs use cleared_bosses = 1 (tier 2 exists); one onboarding set (cleared_bosses = 0) is reported
## for ONBOARDING_CHARACTER on chapter 1.
const CLEARED_BOSSES_MAIN: int = 1
const ONBOARDING_CHARACTER: String = "kiem_si"
const ONBOARDING_SUFFIX: String = " (onboarding)"
const REST_HEAL_BELOW: float = 0.5
const DANGER_BURN_CARDS: int = 2
const MINIBOSS_MIN_HP: float = 0.7
## Story 023 / 026 targets: boss hits per WON run, chapter win % (build policy) per chapter index.
const HITS_TARGET_MIN: float = 15.0
const HITS_TARGET_MAX: float = 30.0
const WIN_TARGETS: Array = [[40.0, 60.0], [25.0, 45.0], [15.0, 35.0]]
const VERDICT_POLICY: String = "build"
const KIND_ORDER: Array[String] = ["battle", "danger", "miniboss", "boss", "treasure", "rest"]
## build policy: deck size above which a reward without an upgrade pick removes the weakest card.
const REMOVE_OVER: int = 7
const NEW_CARD_MAX_MIN_CELLS: int = 4
## build policy (Story 027): zone cards of one effect (seal / thorns) the deck may hold.
const ZONE_PER_EFFECT: int = 1
## Largest min_cells the bot can reach with one cast (two pieces of up to 5 cells; the rune bot used 5).
const CELLS_MAX: int = 5
const AVG_CELLS: float = 3.5
const BURN_EXPECT: float = 0.6
const SEED_MASK: int = 0x7fffffff
## Story 031 world mode. Seconds per node outside the match (node pick, reward, reading the screen):
## an ASSUMPTION (story Part F), printed in the header; --node-overhead=S.
const DEFAULT_NODE_OVERHEAD_SEC: float = 25.0
## Story 032 treasure policies (see the header).
const RELIC_POLICIES: Array[String] = ["none", "pick"]
const RELIC_SEED_TAG: String = "relic"
## Story 035 --fate: what the bot does at each region boss (none given = no fate, today's output).
const FATE_POLICIES: Array[String] = ["execute", "spare", "alternate"]
const FATE_SEED_TAG: String = "fate"
## Story 035 F4 targets: final-match win % when the final is reached, and the final's max share of deaths.
const FATE_FINAL_WIN_TARGET: Array[float] = [35.0, 55.0]
const FATE_FINAL_DEATH_SHARE_MAX: float = 40.0
## Story 035 F4: execute should beat spare by this many run-win points (needs two runs; printed as a reminder).
const FATE_EXECUTE_EDGE_TARGET: Array[float] = [8.0, 20.0]
## Story 033 shop / event policies (see the header and README) and the bot's thresholds.
const SHOP_POLICIES: Array[String] = ["greedy", "eager", "none"]
const EVENT_POLICIES: Array[String] = ["risky", "leave"]
## greedy: the bot walks into a shop node only with at least this much gold.
const SHOP_MIN_GOLD: int = 60
## greedy: the heal service is bought below this share of max HP.
const SHOP_HEAL_BELOW: float = 0.5
## risky: above this share of max HP the first enabled non-heal choice is taken; at or below it a pure
## heal choice (suoi_tinh "drink") when there is one, else the last choice (Rời đi).
const EVENT_RISKY_ABOVE: float = 0.6
## Seed salts of GameFlow (GOLD_SEED_TAG, EVENT_FIGHT_SEED_TAG).
const GOLD_SEED_TAG: String = "gold"
const EVENT_FIGHT_SEED_TAG: String = "event_fight"
## Story 033 Part A targets (simulation-checked starting numbers).
const ECON_EARNED_TARGET: Array = [350.0, 450.0]
const ECON_ITEMS_TARGET: Array = [4.0, 6.0]
const ECON_LEFT_WON_MAX: float = 100.0
const REGION_PICKS: Array[String] = ["random", "first"]
## Story 038 Kiep levels (README "Story 038"): the story's checks. win(k) <= win(k-1) + KIEP_STEP_TOLERANCE, win(k) < win(k-2),
## no drop above KIEP_MAX_DROP points between neighbours, the level-10 win % floor per character (only Kiem si is gated), level 10
## est. minutes (WON run mean) <= KIEP_MINUTES_MAX; an --kiep-only rule that moves the win % less than KIEP_NO_EFFECT_PTS is "NO EFFECT".
const KIEP_STEP_TOLERANCE: float = 3.0
const KIEP_MAX_DROP: float = 12.0
const KIEP_WIN10_MIN: Dictionary = {"kiem_si": 3.0}
const KIEP_MINUTES_MAX: float = 55.0
const KIEP_NO_EFFECT_PTS: float = 1.0
## Story 031 targets (Part F), build policy.
const WORLD_MINUTES_TARGET: Array = [40.0, 50.0]
const WORLD_WIN_TARGET: Dictionary = {"kiem_si": [20.0, 40.0], "sat_thu": [20.0, 40.0], "phap_su": [10.0, 100.0]}
const WORLD_REGION_SPREAD_MAX: float = 15.0
const WORLD_FLOOR_DEATH_SHARE_MAX: float = 40.0
## Regions entered fewer times than this at a floor are left out of the spread check (too few runs).
const WORLD_REGION_MIN_N: int = 5
## Story 040 (README "Story 040"): out-of-match seconds of the v6 run-time estimate. ASSUMPTIONS (TD-006 family), printed in the
## v6 header. A match adds its own intro_sec + end_delay_sec (RunConfig). `--node-overhead=S` replaces the whole table with
## S per node (the old formula, no intro / end delay).
const OOM_MAP_SEC: float = 8.0
const OOM_REWARD_SEC: float = 15.0
const OOM_SHOP_SEC: float = 45.0
const OOM_EVENT_SEC: float = 30.0
const OOM_REST_SEC: float = 10.0
const OOM_FATE_SEC: float = 10.0
## Story 040 Part C targets (starting values; the user re-fixes them after a playtest).
const V6_WIN_TARGET: Array[float] = [30.0, 45.0]
const V6_WIN_SPREAD_MAX: float = 20.0
const V6_DEATH_STEP_TOLERANCE: float = 3.0
const V6_FLOOR1_DEATH_MAX: float = 10.0
const V6_FINAL_WIN_TARGET: Array[float] = [50.0, 70.0]
const V6_MINUTES_WON_TARGET: Array[float] = [40.0, 50.0]
const V6_MINUTES_LOST_MIN: float = 15.0
const V6_HITS_TARGET: Array[float] = [15.0, 30.0]
const V6_BOSS_HIT_PCT_TARGET: Array[float] = [4.0, 15.0]
const V6_GOLD_SPENT_MIN_PCT: float = 70.0
const V6_REGION_BAND: float = 10.0
const V6_MERCY_EDGE_MAX: float = 10.0
const V6_PIECES_EDGE_MAX: float = 10.0
const V6_RELIC_LIFT_MAX: float = 15.0
const V6_SHOP_MIN_PCT: float = 2.0
## Cells (matches / runs) below which a REGION x FLOOR, RELIC LIFT or SHOP cell is marked small and left out of its check.
const V6_REGION_MIN_N: int = 20
const V6_LIFT_MIN_N: int = 10
const V6_SHOP_MIN_OFFERS: int = 10
const V6_SHOP_MIN_VISITS: int = 20
## `--relic=value`: the static value of an offered relic = rarity rank x 10 + this bonus (ASSUMPTION; a relic not listed = 0).
## Printed in the v6 header. huyet_an is negative (self damage) so it is never the first pick.
const RELIC_VALUE_BONUS: Dictionary = {
	"an_don": 3.0, "chi_khau": 2.0, "tui_rong": 3.0, "tam_hop": 3.0, "khoi_the": 2.0, "tam_huong": 2.0, "an_chu": 2.0,
	"phan_don": 1.0, "dau_than": 1.0, "manh_tuoi": 1.0, "dinh_tam": 1.0, "han_ky": 1.0, "huyet_an": -50.0,
}
const RELIC_MODES: Array[String] = ["value", "random", "none"]
## `--pieces=on` bot rule: inks only shapes of this many cells (smallest first), removes 5-cell shapes (see _pieces_remove_pick).
const PIECES_INK_MIN_CELLS: int = 2
const PIECES_INK_MAX_CELLS: int = 3
const PIECES_REMOVE_CELLS: int = 5
const INK_SEED_TAG: String = "ink"
## `--shop=on`: the bot also buys the remove-card service while the deck holds more than this many cards.
const SHOP_REMOVE_CARD_OVER: int = 10
const MERCY_ALIASES: Dictionary = {"kill": "execute", "spare": "spare", "mixed": "alternate"}
const METRICS: Array[String] = [
	"win", "cols", "hits_won", "hits_all", "dmg_hit_pct", "hp_win", "rest_heal", "rest_forge", "treasure",
	"tokens", "size", "levels", "sec", "timeouts", "matches", "taken", "dealt", "sig_acts", "bswings",
	"casts", "resolved", "phits", "focus", "joins", "featured", "counters", "interrupts",
	"zpicks", "zdeck", "zone_casts", "seals", "seal_cells", "thorns", "thorn_cells", "bthorn", "bthorn_dmg", "pthorn",
	"ps_res", "ps_hits", "o_res", "o_hits",
]
const RUN_SUMS: Array[String] = [
	"rest_heal", "rest_forge", "treasure", "tokens", "size", "levels", "sec", "timeouts", "matches", "taken",
	"dealt", "sig_acts", "bswings", "casts", "resolved", "phits", "focus", "joins", "featured", "counters", "interrupts",
	"zpicks", "zdeck", "zone_casts", "seals", "seal_cells", "thorns", "thorn_cells", "bthorn", "bthorn_dmg", "pthorn",
	"ps_res", "ps_hits", "o_res", "o_hits",
]

var _core: SimCore
var _chapters: ChaptersConfig
var _reward_config: Dictionary = {}
var _max_level: int = 3
var _min_deck_size: int = 4
var _policies: Array[String] = POLICIES.duplicate()
var _characters_run: Array[String] = CHARACTERS.duplicate()
var _chapter_list: Array[int] = [0]
var _no_treasure: bool = false
var _trace_n: int = -1
var _trace_id: String = ""
var _matches_seen: int = 0
var _kind_stats: Dictionary = {}
var _match_stats: Dictionary = {}
# Story 031 world mode.
var _world: bool = false
var _region_pick: String = "random"
var _node_overhead: float = DEFAULT_NODE_OVERHEAD_SEC
var _world_set: Array[String] = []
## Story 040: `--char-set=<id>.<key path>:<X|xF>[,...]` overrides characters.json in memory (e.g.
## phap_su.max_hp:210, phap_su.signature.params.burn_damage_per_tick:x1.5), so character probes run side by side.
var _char_set: Array[String] = []
var _policies_given: bool = false
var _relic_policy: String = "none"
# Story 035: "" (no --fate) or one of FATE_POLICIES.
var _fate_policy: String = ""
# Story 033 economy.
var _shop_policy: String = "greedy"
var _event_policy: String = "risky"
var _economy_set: Array[String] = []
var _economy: EconomyConfig
## Story 036: --region=<id,...> (region / chapter ids) and --floor=1,3,5 (1-based floors) of the region mode.
var _regions: Array[String] = []
var _region_floors: Array[int] = []
## Story 039: --region-freq=N (0 = off): N seeded world-map runs counting how often each region is offered / chosen.
var _region_freq: int = 0
## Story 037: --unlock-runs=N (0 = off) consecutive runs on one ProgressState per repetition, --unlock-reps=R
## repetitions, --unlock-full = play all N runs even after both new characters are open.
var _unlock_runs: int = 0
var _unlock_reps: int = UNLOCK_DEFAULT_REPS
var _unlock_full: bool = false
## "character|policy" -> {win, wins, n} of the world runs, for the WORLD CHARACTERS comparison line.
var _world_wins: Dictionary = {}
## Story 038: `--kiep=<list|a..b>` (stacked rules of levels 1..k) or `--kiep-only=<list|a..b>` (level k's own rules alone, a
## single-rule table through KiepRules.set_only), `--kiep-full` (several levels: print every level's full WORLD tables).
## [member _kiep_active] = one of the two flags was given (no flag: nothing below runs and the output is the old one).
var _kiep_levels: Array[int] = []
var _kiep_only: bool = false
var _kiep_active: bool = false
var _kiep_full: bool = false
## Story 040: `--seed-offset=N` runs seeds N+1..N+seeds (world mode), so a final check can use a seed set the tuning
## rounds never saw.
var _seed_offset: int = 0
## The level the world runs in progress play at (0 = the normal game) and whether the per-level WORLD tables are suppressed.
var _kiep_level: int = 0
var _kiep_compact: bool = false
## One row per (level, character, policy), see [method _kiep_note].
var _kiep_rows: Array[Dictionary] = []
## Story 040 (README "Story 040"): the run v6 aliases and the v6 tables. All of it is off by default (then the output is the old one).
## [member _v6] = the v6 tables are printed (any alias flag, or `--tables=v6`; `--tables=none` forces them off).
var _v6: bool = false
var _tables_forced_off: bool = false
## `--floors=a..b` (`_f_from` = a - 1; `_floors_b` = b, -1 = the default 5) and `--final=on|off` (off = no final match), see [method _f_range].
var _f_from: int = 0
var _floors_b: int = -1
var _final_on: bool = true
## `--relic=value|random|none` ("" = the legacy `--relic-policy`): how a relic is chosen from an offer.
var _relic_mode: String = ""
## `--pieces=on` bot piece-deck policy (see `_pieces_*`), `--shop=on` extras (remove card / remove shape).
var _pieces_on: bool = false
var _shop_extras: bool = false
## Lists (`--dodge=a,b,c`, `--mercy=kill,spare`, `--pieces=on,off`): the same seeds run once per combination.
var _dodge_list: Array[float] = []
var _mercy_list: Array[String] = []
var _pieces_list: Array[bool] = []
var _node_overhead_given: bool = false
## The runs of the variant in progress (RELIC LIFT / SHOP) and, per variant, {label, dodge, mercy, pieces, wins: {character: win %}}.
var _v6_runs: Array[Dictionary] = []
var _v6_summary: Array[Dictionary] = []
var _variant_label: String = ""
var _orig_piece_spec: String = ""
var _orig_piece_state: Dictionary = {}
var _pieces_flag: bool = false
## `--relic=value|random` pick seed of the call in progress is passed explicitly; nothing global.


## Story 031 world mode: a run's state (the parts of RunSession the bot and the reward policy read), so the
## sim does not depend on the RunSession save/flow API. Same rules as RunSession v5: hp < 0 = full, luck
## from nodes cleared over the whole run, Deck.add semantics for add_card.
class WorldRun:
	extends RefCounted
	var run_seed: int = 0
	var hp: float = -1.0
	var deck: Array[Dictionary] = []
	var removal_tokens: int = 0
	var nodes_cleared: int = 0
	var floor: int = 0
	var region_id: String = ""
	var chapter_index: int = 0
	var column: int = 0
	var cleared_nodes: Array = []
	## Story 032: owned relic ids in received order.
	var relics: Array[String] = []
	## Story 033: gold, active run modifiers ({id, matches_left, params}), event ids seen this run.
	var gold: int = 0
	var run_modifiers: Array[Dictionary] = []
	var event_used: Array = []
	## Story 038: the run's Kiep level (0 = the normal game).
	var kiep_level: int = 0
	## Story 040 (`--pieces=on` only): the run's piece deck and its shape-removal tokens (see RunSession).
	var piece_deck: Dictionary = {}
	var shape_removals: int = 0

	func luck(config: Dictionary = {}) -> float:
		return float(config.get("luck_start", 0.0)) + float(config.get("luck_per_node", 1.0)) * float(nodes_cleared)

	func reward_seed() -> int:
		return hash([run_seed, floor, region_id, column, nodes_cleared]) & 0x7fffffff

	func rest_heal(max_hp: float, config: Dictionary) -> float:
		var before: float = max_hp if hp < 0.0 else minf(hp, max_hp)
		var ratio: float = float(config.get("rest_heal_ratio", 0.3))
		if kiep_level > 0:
			ratio = KiepRules.shared().rest_heal_ratio(ratio, kiep_level)
		var after: float = minf(before + ratio * max_hp, max_hp)
		hp = after
		return after - before

	func rest_forge(index: int, config: Dictionary) -> void:
		if index < 0 or index >= deck.size():
			return
		var e: Dictionary = deck[index]
		e["level"] = mini(int(e["level"]) + int(config.get("rest_forge_levels", 1)), SkillConfig.MAX_LEVEL)

	func add_card(id: String, max_level: int = SkillConfig.MAX_LEVEL) -> void:
		for e: Dictionary in deck:
			if str(e["id"]) == id and int(e["level"]) < max_level:
				e["level"] = int(e["level"]) + 1
				return
		deck.append({"id": id, "level": 1})

	func remove_card_at(index: int, min_deck_size: int) -> bool:
		if removal_tokens <= 0 or index < 0 or index >= deck.size() or deck.size() <= min_deck_size:
			return false
		removal_tokens -= 1
		deck.remove_at(index)
		return true

	func deck_levels() -> Dictionary:
		var out: Dictionary = {}
		for e: Dictionary in deck:
			out[str(e["id"])] = maxi(int(out.get(str(e["id"]), 0)), int(e["level"]))
		return out

	func deck_entries() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for e: Dictionary in deck:
			out.append(e.duplicate())
		return out


func _init() -> void:
	var t0: int = Time.get_ticks_msec()
	_core = SimCore.new()
	# Story 040: `--dodge=a,b,c` runs the same seeds at each value; the bot core only sees the first one.
	var core_args: PackedStringArray = []
	for raw: String in OS.get_cmdline_user_args():
		if raw.begins_with("--dodge=") and raw.contains(","):
			for item: String in raw.get_slice("=", 1).split(","):
				if item.strip_edges().is_valid_float():
					_dodge_list.append(clampf(float(item.strip_edges()), 0.0, 1.0))
			core_args.append("--dodge=%s" % (str(_dodge_list[0]) if not _dodge_list.is_empty() else "0.85"))
			if _dodge_list.size() > 1:
				_v6 = true
		else:
			core_args.append(raw)
	var rest: PackedStringArray = _core.apply_args(core_args)
	var seeds: int = DEFAULT_SEEDS
	for arg: String in rest:
		var v: String = arg.get_slice("=", 1) if arg.contains("=") else ""
		if arg.begins_with("--seeds="):
			seeds = maxi(int(v), 1)
		elif arg.begins_with("--seed-offset="):
			_seed_offset = maxi(int(v), 0)
		elif arg.begins_with("--policies="):
			_policies_given = true
			_policies = []
			for p: String in v.split(","):
				if POLICIES.has(p.strip_edges()):
					_policies.append(p.strip_edges())
			if _policies.is_empty():
				_policies = POLICIES.duplicate()
		elif arg.begins_with("--characters="):
			_characters_run = []
			for c: String in v.split(","):
				if CHARACTERS.has(c.strip_edges()) or NEW_CHARACTERS.has(c.strip_edges()):
					_characters_run.append(c.strip_edges())
			if _characters_run.is_empty():
				_characters_run = CHARACTERS.duplicate()
		elif arg.begins_with("--chapters="):
			_chapter_list = []
			for c: String in v.split(","):
				if c.strip_edges().is_valid_int():
					_chapter_list.append(int(c.strip_edges()))
			if _chapter_list.is_empty():
				_chapter_list = [0]
		elif arg == "--no-treasure":
			_no_treasure = true
		elif arg.begins_with("--region="):
			for r: String in v.split(","):
				if not r.strip_edges().is_empty():
					_regions.append(r.strip_edges())
		elif arg.begins_with("--floor="):
			for fl: String in v.split(","):
				if fl.strip_edges().is_valid_int() and int(fl.strip_edges()) >= 1:
					_region_floors.append(int(fl.strip_edges()))
		elif arg.begins_with("--region-freq="):
			_region_freq = maxi(int(v), 0)
		elif arg.begins_with("--unlock-runs="):
			_unlock_runs = maxi(int(v), 0)
		elif arg.begins_with("--unlock-reps="):
			_unlock_reps = maxi(int(v), 1)
		elif arg == "--unlock-full":
			_unlock_full = true
		elif arg == "--world":
			_world = true
		elif arg.begins_with("--kiep-only="):
			_kiep_levels = _parse_kiep_levels(v)
			_kiep_only = true
			_kiep_active = true
		elif arg.begins_with("--kiep="):
			_kiep_levels = _parse_kiep_levels(v)
			_kiep_only = false
			_kiep_active = true
		elif arg == "--kiep-full":
			_kiep_full = true
		elif arg.begins_with("--region-pick="):
			if REGION_PICKS.has(v.strip_edges()):
				_region_pick = v.strip_edges()
			else:
				print("--region-pick: '%s' unknown, using %s (one of %s)" % [v, _region_pick, str(REGION_PICKS)])
		elif arg.begins_with("--node-overhead="):
			_node_overhead = maxf(float(v), 0.0)
			_node_overhead_given = true
		elif arg.begins_with("--char-set="):
			for item: String in v.split(","):
				if not item.strip_edges().is_empty():
					_char_set.append(item.strip_edges())
		elif arg.begins_with("--world-set="):
			for item: String in v.split(","):
				if not item.strip_edges().is_empty():
					_world_set.append(item.strip_edges())
		elif arg.begins_with("--relic-policy="):
			if RELIC_POLICIES.has(v.strip_edges()):
				_relic_policy = v.strip_edges()
			else:
				print("--relic-policy: '%s' unknown, using %s (one of %s)" % [v, _relic_policy, str(RELIC_POLICIES)])
		elif arg.begins_with("--fate="):
			if FATE_POLICIES.has(v.strip_edges()):
				_fate_policy = v.strip_edges()
			else:
				print("--fate: '%s' unknown, no fate is taken (one of %s)" % [v, str(FATE_POLICIES)])
		elif arg.begins_with("--shop-policy="):
			if SHOP_POLICIES.has(v.strip_edges()):
				_shop_policy = v.strip_edges()
			else:
				print("--shop-policy: '%s' unknown, using %s (one of %s)" % [v, _shop_policy, str(SHOP_POLICIES)])
		elif arg.begins_with("--event-policy="):
			if EVENT_POLICIES.has(v.strip_edges()):
				_event_policy = v.strip_edges()
			else:
				print("--event-policy: '%s' unknown, using %s (one of %s)" % [v, _event_policy, str(EVENT_POLICIES)])
		elif arg.begins_with("--economy-set="):
			for item: String in arg.trim_prefix("--economy-set=").split(","):
				if not item.strip_edges().is_empty():
					_economy_set.append(item.strip_edges())
		elif arg.begins_with("--trace="):
			if v.is_valid_int():
				_trace_n = int(v)
			else:
				_trace_id = v
		elif _parse_v6_flag(arg, v):
			pass
		else:
			print("unknown flag %s (see tools/balance/README.md)" % arg)
	_core.load_configs()
	if not _char_set.is_empty():
		_core.characters = _characters_with_overrides(_char_set)
	_v6_setup()
	_chapters = ChaptersConfig.load_from_file() if _world_set.is_empty() else _chapters_with_overrides(_world_set)
	_reward_config = RewardRoller.load_config()
	_economy = EconomyConfig.shared() if _economy_set.is_empty() else _economy_with_overrides(_economy_set)
	_max_level = int(_reward_config["max_card_level"])
	_min_deck_size = int(_reward_config["min_deck_size"])
	if _kiep_active and (not _world or _unlock_runs > 0 or not _regions.is_empty() or _kiep_levels.is_empty()):
		print("KIEP: --kiep / --kiep-only need --world (and no --region / --unlock-runs) and at least one valid level 0..%d; ignored" % KiepRules.shared().max_level())
		_kiep_active = false
	if _unlock_runs > 0:
		_run_unlock_mode()
		print("runtime: %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
		quit(0)
		return
	if _region_freq > 0:
		_run_region_freq(_region_freq)
		print("runtime: %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
		quit(0)
		return
	if not _regions.is_empty():
		_run_region_mode(seeds)
		print("runtime: %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
		quit(0)
		return
	if _world:
		_run_world_mode(seeds)
		print("runtime: %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
		quit(0)
		return
	print("deck_sim (Story 026, v5 pieces): seeds=%d timeout=%.0fs policies=%s characters=%s chapters=%s cleared_bosses=%d (always_skip + %s onboarding on chapter 1 only)" % [
		seeds, SimCore.MATCH_TIMEOUT_SEC, str(_policies), str(_characters_run), str(_chapter_list), CLEARED_BOSSES_MAIN, ONBOARDING_CHARACTER])
	print(_core.describe())
	if not _core.describe_progress().is_empty():
		print(_core.describe_progress())
	if not _core.describe_piece_deck().is_empty():
		print(_core.describe_piece_deck())
	if not _core.describe_piece_weight_set().is_empty():
		print(_core.describe_piece_weight_set())
	if _no_treasure:
		print("EXPERIMENT: no-treasure")
	print("node policy: treasure > rest (heal < %.0f%% HP else forge) > miniboss at >= %.0f%% HP > battle > danger (danger first with >= %d burn cards); boss when alone. passive heal on win; no other heal." % [
		100.0 * REST_HEAL_BELOW, 100.0 * MINIBOSS_MIN_HP, DANGER_BURN_CARDS])
	var all_pass: bool = true
	for ci: int in _chapter_list:
		if ci < 0 or ci >= _chapters.chapter_count():
			print("chapter %d: out of range (chapter_count=%d), skipped" % [ci + 1, _chapters.chapter_count()])
			continue
		all_pass = _run_chapter(ci, seeds) and all_pass
	if _policies.has(VERDICT_POLICY):
		print("RESULT: %s" % ("ALL PASS" if all_pass else "FAIL"))
	if not _core.piece_deck_spec.is_empty():
		print("PIECE DECK %s: fallback matches %d of %d (no deck shape fit the arena; original weights used)" % [
			_core.piece_deck_spec, _core.piece_deck_fallbacks, _core.piece_deck_matches])
	print("runtime: %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


# One chapter: every seed x label x policy, then the tables. Returns false when a verdict row misses its win target.
func _run_chapter(ci: int, seeds: int) -> bool:
	var columns: int = _chapters.column_count(ci)
	var labels: Array[String] = _characters_run.duplicate()
	if ci == 0 and _characters_run.has(ONBOARDING_CHARACTER):
		labels.append(ONBOARDING_CHARACTER + ONBOARDING_SUFFIX)
	var pols: Array[String] = []
	for p: String in _policies:
		if p != "always_skip" or ci == 0:
			pols.append(p)
	var agg: Dictionary = {}
	for label: String in labels:
		agg[label] = {}
		for p: String in pols:
			var a: Dictionary = {}
			for k: String in METRICS:
				a[k] = []
			agg[label][p] = a
	var t_ch: int = Time.get_ticks_msec()
	print("")
	print("=== CHAPTER %d (%s): %d columns, policies %s ===" % [ci + 1, _chapters.chapter_id(ci), columns, str(pols)])
	for s: int in seeds:
		for label: String in labels:
			var onboarding: bool = label.ends_with(ONBOARDING_SUFFIX)
			for p: String in pols:
				var r: Dictionary = _run(s + 1, label.trim_suffix(ONBOARDING_SUFFIX), p, 0 if onboarding else CLEARED_BOSSES_MAIN, label, ci)
				var a: Dictionary = agg[label][p]
				(a["win"] as Array).append(1.0 if bool(r["won"]) else 0.0)
				(a["cols"] as Array).append(float(r["cols"]))
				(a["hits_all"] as Array).append(float(r["hits"]))
				if bool(r["won"]):
					(a["hits_won"] as Array).append(float(r["hits"]))
					(a["hp_win"] as Array).append(float(r["hp_end"]))
				if int(r["hits"]) > 0:
					(a["dmg_hit_pct"] as Array).append(100.0 * float(r["taken"]) / float(r["hits"]) / float(r["max_hp"]))
				for k: String in RUN_SUMS:
					(a[k] as Array).append(float(r[k]))
		if (s + 1) % 10 == 0:
			print("  ... ch%d %d/%d seeds, %.1f s" % [ci + 1, s + 1, seeds, (Time.get_ticks_msec() - t_ch) / 1000.0])
	print("")
	print("CH%d | character | policy | chapter win %% | mean columns cleared (of %d) | hits taken / WON run | hits taken / run (all) | dmg per hit %% max HP | HP at end (wins) | rest: heal | rest: forge | treasure / run | tokens spent / run | final deck size | deck level sum | mean match sec | matches / run | timeouts / run | dmg taken / match | dmg dealt / match | boss swings / run | boss hit rate | sig acts / run | casts / match | player hit %% | focus / match | joins / match | featured / match | counters / match | interrupts / match |" % [ci + 1, columns])
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for label: String in labels:
		for p: String in pols:
			var a: Dictionary = agg[label][p]
			var mm: float = maxf(_mean(a["matches"]), 1.0)
			print("| %s | %s | %.1f | %.2f | %.1f (n=%d) | %.1f | %.1f | %.1f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.1f | %.2f | %.2f | %.1f | %.1f | %.1f | %.2f | %.2f | %.1f | %.0f | %.2f | %.2f | %.2f | %.2f | %.2f |" % [
				label, p, 100.0 * _mean(a["win"]), _mean(a["cols"]), _mean(a["hits_won"]), (a["hits_won"] as Array).size(), _mean(a["hits_all"]),
				_mean(a["dmg_hit_pct"]), _mean(a["hp_win"]), _mean(a["rest_heal"]), _mean(a["rest_forge"]), _mean(a["treasure"]), _mean(a["tokens"]),
				_mean(a["size"]), _mean(a["levels"]), _mean(a["sec"]), _mean(a["matches"]), _mean(a["timeouts"]),
				_mean(a["taken"]) / mm, _mean(a["dealt"]) / mm, _mean(a["bswings"]), _mean(a["hits_all"]) / maxf(_mean(a["bswings"]), 1.0), _mean(a["sig_acts"]),
				_mean(a["casts"]) / mm, 100.0 * _mean(a["phits"]) / maxf(_mean(a["resolved"]), 1.0), _mean(a["focus"]) / mm, _mean(a["joins"]) / mm,
				_mean(a["featured"]) / mm, _mean(a["counters"]) / mm, _mean(a["interrupts"]) / mm])
	print("")
	print("CH%d ZONES: | character | policy | zone cards picked / run | zone cards in final deck | zone casts / match | seals formed / match | seal cells / seal | thorns formed / match | thorn cells / thorns | boss thorn entries / match | thorn dmg to boss / match | player thorn entries / match | hit %% <= %.0fs after a seal (n) | hit %% other non-zone casts (n) | player hit %% (all) |" % [ci + 1, SimCore.POST_SEAL_SEC])
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for label: String in labels:
		for p: String in pols:
			var a: Dictionary = agg[label][p]
			var mm: float = maxf(_mean(a["matches"]), 1.0)
			var ps_n: float = _sum(a["ps_res"])
			var o_n: float = _sum(a["o_res"])
			print("| %s | %s | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.1f | %.2f | %s | %s | %.1f |" % [
				label, p, _mean(a["zpicks"]), _mean(a["zdeck"]), _mean(a["zone_casts"]) / mm, _mean(a["seals"]) / mm,
				_sum(a["seal_cells"]) / maxf(_sum(a["seals"]), 1.0), _mean(a["thorns"]) / mm, _sum(a["thorn_cells"]) / maxf(_sum(a["thorns"]), 1.0),
				_mean(a["bthorn"]) / mm, _mean(a["bthorn_dmg"]) / mm, _mean(a["pthorn"]) / mm,
				("%.1f (n=%d)" % [100.0 * _sum(a["ps_hits"]) / ps_n, int(ps_n)]) if ps_n > 0.0 else "- (n=0)",
				("%.1f (n=%d)" % [100.0 * _sum(a["o_hits"]) / o_n, int(o_n)]) if o_n > 0.0 else "- (n=0)",
				100.0 * _mean(a["phits"]) / maxf(_mean(a["resolved"]), 1.0)])
	print("")
	print("CH%d NODE KIND BREAKDOWN: | character | policy | kind | played | win %% | hits taken / node | dmg taken / node | mean sec | timeouts | deaths | deaths %% of char deaths |" % (ci + 1))
	print("|---|---|---|---|---|---|---|---|---|---|---|")
	for label: String in labels:
		for p: String in pols:
			var key: String = "%s|%s|%d" % [label, p, ci]
			if not _kind_stats.has(key):
				continue
			var total_deaths: int = _deaths(_kind_stats[key])
			for kind: String in KIND_ORDER:
				if (_kind_stats[key] as Dictionary).has(kind):
					print(_stat_row([label, p, kind], _kind_stats[key][kind], total_deaths))
	print("")
	print("CH%d PER-MATCH: | character | policy | match | kind | played | win %% | hits taken / match | dmg taken / match | mean sec | timeouts | deaths | deaths %% of char deaths |" % (ci + 1))
	print("|---|---|---|---|---|---|---|---|---|---|---|---|")
	for label: String in labels:
		for p: String in pols:
			var key: String = "%s|%s|%d" % [label, p, ci]
			if not _match_stats.has(key):
				continue
			var total_deaths: int = _deaths(_match_stats[key])
			var ids: Array = (_match_stats[key] as Dictionary).keys()
			ids.sort()
			for id: String in ids:
				var b: Dictionary = _match_stats[key][id]
				print(_stat_row([label, p, id, str(b["kind"])], b, total_deaths))
	print("")
	var target: Array = WIN_TARGETS[mini(ci, WIN_TARGETS.size() - 1)]
	var ok_all: bool = true
	for label: String in labels:
		for p: String in pols:
			var a: Dictionary = agg[label][p]
			var hits: float = _mean(a["hits_won"])
			var n_won: int = (a["hits_won"] as Array).size()
			var win_pct: float = 100.0 * _mean(a["win"])
			var win_ok: bool = win_pct >= float(target[0]) and win_pct <= float(target[1])
			var hits_ok: bool = n_won > 0 and hits >= HITS_TARGET_MIN and hits <= HITS_TARGET_MAX
			var is_verdict: bool = p == VERDICT_POLICY and not label.ends_with(ONBOARDING_SUFFIX)
			if is_verdict:
				ok_all = ok_all and win_ok
			print("%s ch%d %s/%s: win %.1f%% (target %.0f-%.0f) %s; hits taken per WON run %.1f (target %.0f-%.0f, %d wins of %d) %s; all runs %.1f; dmg/hit %.1f%% max HP; timeouts/run %.2f" % [
				"VERDICT" if is_verdict else "INFO", ci + 1, label, p, win_pct, float(target[0]), float(target[1]), "PASS" if win_ok else ("TOO EASY" if win_pct > float(target[1]) else "TOO HARD"),
				hits, HITS_TARGET_MIN, HITS_TARGET_MAX, n_won, (a["win"] as Array).size(), ("PASS" if hits_ok else "FAIL") if n_won > 0 else "NO WINS",
				_mean(a["hits_all"]), _mean(a["dmg_hit_pct"]), _mean(a["timeouts"])])
	return ok_all


func _deaths(by_key: Dictionary) -> int:
	var total: int = 0
	for k: Variant in by_key.keys():
		total += int(by_key[k]["deaths"])
	return total


func _stat_row(head: Array, b: Dictionary, total_deaths: int) -> String:
	var n: float = maxf(float(b["n"]), 1.0)
	var cells: Array[String] = []
	for h: Variant in head:
		cells.append(str(h))
	return "| %s | %d | %.1f | %.2f | %.1f | %.1f | %d | %d | %.0f |" % [" | ".join(cells), int(b["n"]), 100.0 * float(b["won"]) / n,
		float(b["hits"]) / n, float(b["taken"]) / n, float(b["sec"]) / n, int(b["timeouts"]), int(b["deaths"]),
		100.0 * float(b["deaths"]) / maxf(float(total_deaths), 1.0)]


func _sum(values: Variant) -> float:
	var total: float = 0.0
	for v: Variant in values as Array:
		total += float(v)
	return total


func _mean(values: Variant) -> float:
	var arr: Array = values as Array
	if arr.is_empty():
		return 0.0
	var total: float = 0.0
	for v: Variant in arr:
		total += float(v)
	return total / arr.size()


# ---------------------------------------------------------------- one run (chapter map, column by column)


# Mirrors GameFlow: choose_node -> (match via RunConfig.from_node | rest | treasure) -> complete_node
# (passive heal only) -> reward of the node kind -> next column.
func _run(seed_value: int, char_id: String, policy: String, cleared_bosses: int, label: String, ci: int) -> Dictionary:
	var character: Dictionary = _core.prepare_character(_core.characters.get_character(char_id))
	var max_hp: float = float(character["max_hp"])
	var map: Array[Dictionary] = _chapters.generate_map(ci, seed_value, cleared_bosses)
	var session: RunSession = RunSession.begin(_chapters, character, ci, seed_value, map, int(_reward_config.get("starting_removals", 0)))
	session.locked = _core.locked.duplicate(true)
	var bot_rng := RandomNumberGenerator.new()
	bot_rng.seed = hash([seed_value, char_id]) & SEED_MASK
	var out: Dictionary = {"won": false, "cols": 0, "hp_end": 0.0, "max_hp": max_hp, "hits": 0}
	for k: String in RUN_SUMS:
		out[k] = 0.0
	var stats_key: String = "%s|%s|%d" % [label, policy, ci]
	var run_relics: Array[String] = []
	run_relics.assign(_core.ov["relics"] as Array)
	var lost: bool = false
	var boss_won: bool = false
	while not session.is_run_won() and session.column < session.map.size():
		var nodes: Array[Dictionary] = session.available_nodes()
		if nodes.is_empty():
			break
		var node: Dictionary = _bot_choose_node(nodes, session, max_hp)
		if not session.choose_node(int(node["node_index"])):
			push_warning("deck_sim: choose_node refused at column %d" % session.column)
			break
		var kind: String = str(node.get("kind", ""))
		if kind == ChapterMapGen.KIND_REST:
			var forge_index: int = _forge_index(session)
			if _hp_ratio(session, max_hp) < REST_HEAL_BELOW or forge_index < 0:
				session.rest_heal(max_hp, _reward_config)
				out["rest_heal"] = float(out["rest_heal"]) + 1.0
			else:
				session.rest_forge(forge_index, _reward_config)
				out["rest_forge"] = float(out["rest_forge"]) + 1.0
			_record(_kind_stats, stats_key, kind, kind, true, 0, 0.0, 0.0, false)
			session.complete_node(session.hp, max_hp, kind, _reward_config, 0.0)
			continue
		if kind == ChapterMapGen.KIND_TREASURE:
			out["treasure"] = float(out["treasure"]) + 1.0
			if not _take_relic(run_relics, policy, hash([seed_value, 0, session.column, int(node["node_index"]), RELIC_SEED_TAG]) & SEED_MASK):
				_apply_policy(session, policy, kind, out)
			_record(_kind_stats, stats_key, kind, kind, true, 0, 0.0, 0.0, false)
			session.complete_node(session.hp, max_hp, kind, _reward_config, 0.0)
			continue
		var run_config: RunConfig = RunConfig.from_node(_chapters, session.chapter_index, str(node.get("match_id", "")), kind, seed_value)
		var m: Dictionary = _core.prepare_match(run_config.matches[0])
		m["chapter_id"] = _chapters.chapter_id(ci)
		var match_seed: int = hash([seed_value, session.column, int(node["node_index"])]) & SEED_MASK
		_core.invulnerable = false
		_core.time_limit_sec = SimCore.MATCH_TIMEOUT_SEC
		_core.trace = (_trace_n >= 0 and _matches_seen == _trace_n) or (not _trace_id.is_empty() and str(m.get("id", "")) == _trace_id)
		if _core.trace and not _trace_id.is_empty():
			_trace_id = ""
		_matches_seen += 1
		_core.relic_ids = run_relics.duplicate()
		var r: Dictionary = _core.play_match(m, character, session.deck_entries(), session.hp, match_seed, bot_rng)
		out["matches"] = float(out["matches"]) + 1.0
		out["hits"] = int(out["hits"]) + int(r["bhits"])
		for pair: Array in [["taken", "taken"], ["dealt", "dealt"], ["sec", "sec"], ["sig_acts", "sig_acts"], ["bswings", "bswings"],
				["casts", "casts"], ["resolved", "resolved"], ["phits", "hits"], ["focus", "focus_uses"], ["joins", "joins"],
				["featured", "featured"], ["counters", "counters"], ["interrupts", "interrupts"],
				["zone_casts", "zone_casts"], ["seals", "seals"], ["seal_cells", "seal_cells"], ["thorns", "thorns"],
				["thorn_cells", "thorn_cells"], ["bthorn", "bthorn"], ["bthorn_dmg", "bthorn_dmg"], ["pthorn", "pthorn"],
				["ps_res", "ps_res"], ["ps_hits", "ps_hits"], ["o_res", "o_res"], ["o_hits", "o_hits"]]:
			out[pair[0]] = float(out[pair[0]]) + float(r[pair[1]])
		if bool(r["timeout"]):
			out["timeouts"] = float(out["timeouts"]) + 1.0
		_record(_kind_stats, stats_key, kind, kind, bool(r["won"]), int(r["bhits"]), float(r["taken"]), float(r["sec"]), bool(r["timeout"]))
		_record(_match_stats, stats_key, str(m.get("id", "")), kind, bool(r["won"]), int(r["bhits"]), float(r["taken"]), float(r["sec"]), bool(r["timeout"]))
		if not bool(r["won"]):
			lost = true
			break
		var done: Dictionary = session.complete_node(float(r["hp_end"]), max_hp, kind, _reward_config, float(r["passive_heal"]))
		_apply_policy(session, policy, kind, out)
		# Story 031: a region boss no longer wins a RunSession; in chapter mode the chapter boss still ends the run.
		if bool(done.get("run_won", false)) or kind == ChapterMapGen.KIND_BOSS:
			boss_won = kind == ChapterMapGen.KIND_BOSS or bool(done.get("run_won", false))
			break
	out["won"] = (session.is_run_won() or boss_won) and not lost
	out["cols"] = session.cleared_nodes.size()
	out["hp_end"] = (max_hp if session.hp < 0.0 else session.hp) if bool(out["won"]) else 0.0
	out["sec"] = float(out["sec"]) / maxf(float(out["matches"]), 1.0)
	out["size"] = session.deck.size()
	var level_sum: int = 0
	for e: Dictionary in session.deck:
		level_sum += int(e["level"])
	out["levels"] = level_sum
	out["zdeck"] = 0.0
	for e: Dictionary in session.deck:
		if _core.cards.is_zone_card(str(e["id"])):
			out["zdeck"] = float(out["zdeck"]) + 1.0
	return out


# "deaths" = lost matches (a timeout counts as a death: the run ends there too).
static func _record(stats: Dictionary, key: String, id: String, kind: String, won: bool, hits: int, taken: float, sec: float, timeout: bool) -> void:
	if not stats.has(key):
		stats[key] = {}
	if not (stats[key] as Dictionary).has(id):
		stats[key][id] = {"n": 0, "won": 0, "hits": 0, "taken": 0.0, "sec": 0.0, "timeouts": 0, "deaths": 0, "kind": kind}
	var b: Dictionary = stats[key][id]
	b["n"] = int(b["n"]) + 1
	b["won"] = int(b["won"]) + (1 if won else 0)
	b["hits"] = int(b["hits"]) + hits
	b["taken"] = float(b["taken"]) + taken
	b["sec"] = float(b["sec"]) + sec
	b["timeouts"] = int(b["timeouts"]) + (1 if timeout else 0)
	b["deaths"] = int(b["deaths"]) + (0 if won else 1)


func _hp_ratio(session, max_hp: float) -> float:
	if session.hp < 0.0:
		return 1.0
	return clampf(session.hp / max_hp, 0.0, 1.0)


func _count_effect(session, effect: String) -> int:
	var n: int = 0
	for e: Dictionary in session.deck:
		if str(_core.cards.get_skill(str(e["id"])).get("effect", "")) == effect:
			n += 1
	return n


func _bot_choose_node(nodes: Array[Dictionary], session, max_hp: float) -> Dictionary:
	var by_kind: Dictionary = {}
	for n: Dictionary in nodes:
		var k: String = str(n.get("kind", ""))
		if not by_kind.has(k):
			by_kind[k] = n
	if by_kind.has(ChapterMapGen.KIND_TREASURE) and (not _no_treasure or by_kind.size() == 1):
		return by_kind[ChapterMapGen.KIND_TREASURE]
	if by_kind.has(ChapterMapGen.KIND_REST):
		return by_kind[ChapterMapGen.KIND_REST]
	if by_kind.has(ChapterMapGen.KIND_MINIBOSS) and _hp_ratio(session, max_hp) >= MINIBOSS_MIN_HP:
		return by_kind[ChapterMapGen.KIND_MINIBOSS]
	var order: Array[String] = [ChapterMapGen.KIND_BATTLE, ChapterMapGen.KIND_DANGER]
	if _count_effect(session, "burn") >= DANGER_BURN_CARDS:
		order = [ChapterMapGen.KIND_DANGER, ChapterMapGen.KIND_BATTLE]
	for k: String in order:
		if by_kind.has(k):
			return by_kind[k]
	for k: String in [ChapterMapGen.KIND_MINIBOSS, ChapterMapGen.KIND_BOSS]:
		if by_kind.has(k):
			return by_kind[k]
	return nodes[0]


# Rèn target: the damage/push card with the highest damage_per_cell below max level; -1 when none.
func _forge_index(session) -> int:
	var best: int = -1
	var best_dpc: float = 0.0
	for i: int in session.deck.size():
		var e: Dictionary = session.deck[i]
		if int(e["level"]) >= _max_level:
			continue
		var c: Dictionary = _core.cards.resolved(str(e["id"]), int(e["level"]))
		if str(c["effect"]) != "damage" and str(c["effect"]) != "push":
			continue
		if float(c["damage_per_cell"]) > best_dpc:
			best_dpc = float(c["damage_per_cell"])
			best = i
	return best


# ---------------------------------------------------------------- reward policies (ported unchanged)


func _apply_policy(session, policy: String, kind: String, out: Dictionary) -> void:
	var info: Dictionary = RewardRoller.reward_for_node(kind, _reward_config)
	var offers: int = int(info.get("offers", 0))
	if offers <= 0:
		return
	if out.has("oo_sec"):
		out["oo_sec"] = float(out["oo_sec"]) + OOM_REWARD_SEC
	var cfg: Dictionary = _reward_config.duplicate(true)
	cfg["offer_count"] = offers
	var reward_seed: int = (session as WorldRun).reward_seed() if session is WorldRun else (hash([session.run_seed, session.chapter_index, session.column, session.cleared_nodes.size()]) & SEED_MASK)
	var levels: Dictionary = session.deck_levels()
	var excluded: Array[String] = _core.zone_card_ids() if bool(_core.ov["no_zone_cards"]) else ([] as Array[String])
	# Story 037: locked cards are not rolled (RunSession.locked["card"], the RewardRoller exclusion list).
	for locked_card: String in _core.locked_ids("card"):
		if not excluded.has(locked_card):
			excluded.append(locked_card)
	var offer: Array[String] = RewardRoller.roll(_core.cards, cfg, reward_seed, excluded, levels, session.luck(cfg), str(info.get("min_rarity", "common")))
	if policy == "always_skip" or offer.is_empty():
		return
	var pick: String = _pick_upgrade(offer, levels)
	if pick.is_empty():
		pick = _pick_zone(offer, session)
		if not pick.is_empty():
			out["zpicks"] = float(out["zpicks"]) + 1.0
	if pick.is_empty() and session.deck.size() > REMOVE_OVER and session.removal_tokens > 0:
		var index: int = _lowest_value_index(session)
		if index >= 0 and session.remove_card_at(index, _min_deck_size):
			out["tokens"] = float(out["tokens"]) + 1.0
			return
	if pick.is_empty():
		pick = _pick_new_damage(offer)
	if pick.is_empty():
		pick = _pick_keyword(offer, session)
	if not pick.is_empty():
		session.add_card(pick, _max_level)


func _pick_upgrade(offer: Array[String], levels: Dictionary) -> String:
	var best: String = ""
	var best_dpc: float = 0.0
	for id: String in offer:
		if not RewardRoller.is_upgrade(id, levels, _max_level):
			continue
		var c: Dictionary = _core.cards.resolved(id, int(levels[id]))
		if float(c["damage_per_cell"]) > best_dpc and int(c["min_cells"]) <= CELLS_MAX:
			best_dpc = float(c["damage_per_cell"])
			best = id
	return best


# Story 027: an offered zone card whose effect the deck holds fewer than ZONE_PER_EFFECT of; seal before
# thorns, then the higher damage_per_cell / thorn_fragile_stacks. "" with --no-zone-cards.
func _pick_zone(offer: Array[String], session) -> String:
	if bool(_core.ov["no_zone_cards"]):
		return ""
	var best: String = ""
	var best_key: float = -INF
	for id: String in offer:
		if not _core.cards.is_zone_card(id):
			continue
		var c: Dictionary = _core.cards.resolved(id, 1)
		var effect: String = str(c["effect"])
		if _count_effect(session, effect) >= ZONE_PER_EFFECT or int(c["min_cells"]) > CELLS_MAX:
			continue
		var key: float = (100.0 if effect == "seal" else 0.0) + float(c.get("damage_per_cell", 0.0)) + float(c.get("thorn_fragile_stacks", 0))
		if key > best_key:
			best_key = key
			best = id
	return best


func _pick_new_damage(offer: Array[String]) -> String:
	var best: String = ""
	var best_key: Array = []
	for id: String in offer:
		var c: Dictionary = _core.cards.resolved(id, 1)
		if str(c["effect"]) != "damage" and str(c["effect"]) != "push":
			continue
		if float(c["damage_per_cell"]) <= 0.0 or int(c["min_cells"]) > NEW_CARD_MAX_MIN_CELLS:
			continue
		var key: Array = [-float(c["damage_per_cell"]), int(c["min_cells"]), float(c["cooldown_sec"])]
		if best.is_empty() or _key_less(key, best_key):
			best = id
			best_key = key
	return best


func _pick_keyword(offer: Array[String], session) -> String:
	var burn: int = _count_effect(session, "burn")
	var pin: int = _count_effect(session, "pin")
	if burn == 0 and pin == 0:
		return ""
	var keyword: String = "burn" if burn >= pin else "pin"
	var best: String = ""
	var best_value: float = -1.0
	for id: String in offer:
		if str(_core.cards.get_skill(id).get("effect", "")) != keyword:
			continue
		var v: float = _entry_value(id, 1)
		if v > best_value:
			best_value = v
			best = id
	return best


func _lowest_value_index(session) -> int:
	var best: int = -1
	var best_value: float = INF
	for i: int in session.deck.size():
		var e: Dictionary = session.deck[i]
		var v: float = _entry_value(str(e["id"]), int(e["level"]))
		if v < best_value:
			best_value = v
			best = i
	return best


# Rough standalone value of a card (remove / keyword picks only).
func _entry_value(id: String, level: int) -> float:
	var c: Dictionary = _core.cards.resolved(id, level)
	var effect: String = str(c["effect"])
	var v: float = 0.0
	var combat: CombatConfig = CombatConfig.load_from_file() if _core.combat == null else _core.combat
	if effect == "damage" or effect == "push":
		v = float(c["damage_per_cell"]) * AVG_CELLS
	elif effect == "burn":
		v = float(c["burn_duration_sec"]) / maxf(float(c["burn_tick_sec"]), 0.01) * float(c["burn_damage_per_tick"]) * BURN_EXPECT
	elif effect == "fragile":
		v = float(c.get("fragile_stacks", 0)) * (combat.fragile_mult - 1.0) * float(_core.cards.resolved(_core.cards.default_card, 1).get("damage_per_cell", 0.0)) * AVG_CELLS
	elif effect == "frost":
		v = float(c.get("frost_stacks", 0)) / float(maxi(combat.frost_stacks_to_burst, 1)) * combat.frost_burst_damage
	else:
		v = 1.0 + float(c.get("pin_duration_sec", 0.0))
	if int(c["min_cells"]) > CELLS_MAX:
		v *= 0.1
	return v


static func _key_less(a: Array, b: Array) -> bool:
	for i: int in a.size():
		if float(a[i]) != float(b[i]):
			return float(a[i]) < float(b[i])
	return false


# ---------------------------------------------------------------- Story 031: world mode (5 floors + final)


# Builds ChaptersConfig from chapters.json with the --world-set overrides applied to the raw dictionary in
# memory. Keys: heal:X (world.floor_heal_ratio); scale.<row|*>.<axis>:X (floor_scaling row "1".."5" /
# "final" / * = every row; X sets, xF multiplies); norm.<region>.<axis>:X (region_normalize, X or xF);
# mid_columns:N (N copies of the middle region column between the first and the boss column);
# battle_columns:N (N extra copies of the first, battle-only column).
func _chapters_with_overrides(items: Array[String]) -> ChaptersConfig:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ChaptersConfig.DEFAULT_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		print("--world-set: chapters.json did not parse, overrides ignored")
		return ChaptersConfig.load_from_file()
	var data: Dictionary = parsed as Dictionary
	var world: Dictionary = data.get("world", {})
	for item: String in items:
		var key: String = item.get_slice(":", 0)
		var raw_value: String = item.get_slice(":", 1)
		var mul: bool = raw_value.begins_with("x")
		var value: float = float(raw_value.trim_prefix("x"))
		var parts: PackedStringArray = key.split(".")
		if key == "heal":
			world["floor_heal_ratio"] = value
		elif parts.size() == 3 and parts[0] == "scale":
			var rows: Dictionary = world.get("floor_scaling", {})
			for row: Variant in rows.keys():
				if parts[1] == "*" or str(row) == parts[1]:
					var r: Dictionary = rows[row]
					var base: float = float(r.get(parts[2], 1.0 if parts[2].ends_with("mult") else 0.0))
					r[parts[2]] = base * value if mul else value
		elif parts.size() == 3 and parts[0] == "norm":
			for chapter: Variant in data.get("chapters", []) as Array:
				if str((chapter as Dictionary).get("id", "")) == parts[1]:
					var nz: Dictionary = (chapter as Dictionary).get("region_normalize", {})
					var base_n: float = float(nz.get(parts[2], 1.0 if parts[2].ends_with("mult") else 0.0))
					nz[parts[2]] = base_n * value if mul else value
					(chapter as Dictionary)["region_normalize"] = nz
		elif key == "mid_columns":
			var cols: Array = world.get("region_columns", [])
			if cols.size() >= 3:
				var new_cols: Array = [cols[0]]
				for i: int in maxi(int(value), 0):
					new_cols.append((cols[1] as Dictionary).duplicate(true))
				new_cols.append(cols[cols.size() - 1])
				world["region_columns"] = new_cols
		elif key == "final_prelude" and raw_value == "none":
			# TD-029: no columns before the final boss (the pre-TD-029 one-column final map).
			world["final_prelude"] = []
		elif key == "battle_columns":
			# N extra copies of the first (battle-only) column right after it: more fights per region.
			var bcols: Array = world.get("region_columns", [])
			if not bcols.is_empty():
				for i: int in maxi(int(value), 0):
					bcols.insert(1, (bcols[0] as Dictionary).duplicate(true))
				world["region_columns"] = bcols
		else:
			print("--world-set: unknown key '%s' ignored" % item)
	data["world"] = world
	return ChaptersConfig.from_dictionary(data)


# Story 040: CharacterConfig from characters.json with the --char-set overrides applied to the raw dictionary
# (key = <character id>.<dictionary path>; X sets, xF multiplies a number). Printed once so the run header shows it.
func _characters_with_overrides(items: Array[String]) -> CharacterConfig:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CharacterConfig.DEFAULT_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		print("--char-set: characters.json did not parse, overrides ignored")
		return _core.characters
	var data: Dictionary = parsed as Dictionary
	for item: String in items:
		var parts: PackedStringArray = item.get_slice(":", 0).split(".")
		var raw_value: String = item.get_slice(":", 1)
		var target: Dictionary = {}
		for c: Variant in data.get("characters", []) as Array:
			if typeof(c) == TYPE_DICTIONARY and str((c as Dictionary).get("id", "")) == parts[0]:
				target = c
		for i: int in range(1, parts.size() - 1):
			target = target.get(parts[i], {}) if typeof(target.get(parts[i], {})) == TYPE_DICTIONARY else {}
		var leaf: String = parts[parts.size() - 1]
		if parts.size() < 2 or not target.has(leaf):
			print("--char-set: unknown key '%s' ignored" % item)
			continue
		var value: float = float(raw_value.trim_prefix("x"))
		target[leaf] = float(target[leaf]) * value if raw_value.begins_with("x") else value
		print("--char-set: %s = %s" % [item.get_slice(":", 0), str(target[leaf])])
	return CharacterConfig.from_dictionary(data)


func _run_world_mode(seeds: int) -> void:
	var pols: Array[String] = _policies.duplicate() if _policies_given else ([VERDICT_POLICY] as Array[String])
	var w: Dictionary = _chapters.world_spec()
	var floors: int = _chapters.world_floors()
	print("deck_sim --world (Story 031): seeds=%d timeout=%.0fs policies=%s characters=%s cleared_bosses=%d region-pick=%s node-overhead=%.0fs (ASSUMPTION: node pick + reward + reading, per node) world-set=%s" % [
		seeds, SimCore.MATCH_TIMEOUT_SEC, str(pols), str(_characters_run), CLEARED_BOSSES_MAIN, _region_pick, _node_overhead,
		",".join(PackedStringArray(_world_set)) if not _world_set.is_empty() else "none"])
	print(_core.describe())
	if not _core.describe_progress().is_empty():
		print(_core.describe_progress())
	if not _core.describe_piece_deck().is_empty() and not _pieces_on:
		print(_core.describe_piece_deck())
	if not _core.describe_piece_weight_set().is_empty():
		print(_core.describe_piece_weight_set())
	print("relics: start=%s relic-policy=%s (pick = relic row over card row at treasure, rarest first; damage cap %.1f)" % [
		",".join(PackedStringArray(_core.ov["relics"])) if not (_core.ov["relics"] as Array).is_empty() else "none", _relic_policy, _core.relic_config.relic_damage_mult_cap])
	print("economy (Story 033): shop-policy=%s event-policy=%s economy-set=%s | start gold %d | shop entered with >= %d gold; greedy = heal below %.0f%% HP, then the dearest affordable relic (repeat), then the cards the build policy picks while affordable; risky = first enabled non-heal choice above %.0f%% HP, else a pure heal choice, else Rời đi" % [
		_shop_policy, _event_policy, ",".join(PackedStringArray(_economy_set)) if not _economy_set.is_empty() else "none",
		_economy.starting_gold(), SHOP_MIN_GOLD, 100.0 * SHOP_HEAL_BELOW, 100.0 * EVENT_RISKY_ABOVE])
	print("world: floors=%d choices=%d pool=%s columns=%d heal=%.2f final=%s tiers=%s" % [floors, int(w["choices_per_floor"]),
		str(w["region_pool"]), (w["region_columns"] as Array).size(), _chapters.floor_heal_ratio(), str(_chapters.final_match()), str(w["floor_tiers"])])
	if not _chapters.final_prelude().is_empty():
		print("final prelude (TD-029): %s before the final boss column" % str(_chapters.final_prelude()))
	for f: int in floors + 1:
		print("  floor_scaling %s: %s" % ["final" if f == floors else str(f + 1), str(_chapters.floor_scaling(f))])
	for id: String in _chapters.region_ids():
		print("  region_normalize %s: %s" % [id, str(_chapters.region_normalize(id))])
	print("node policy: rest when HP < %.0f%%, else treasure > rest (heal < %.0f%% else forge) > miniboss at >= %.0f%% HP > battle > danger; boss when alone. Region boss: boss reward + token + floor heal. Run time = (sum of match REAL seconds + overhead x nodes) / 60." % [
		100.0 * REST_HEAL_BELOW, 100.0 * REST_HEAL_BELOW, 100.0 * MINIBOSS_MIN_HP])
	if _v6:
		_v6_header(floors)
	if _kiep_active:
		_run_kiep_levels(pols, seeds, floors)
		return
	var combos: Array[Dictionary] = _v6_combos()
	for combo: Dictionary in combos:
		if _v6:
			_v6_apply(combo)
			if combos.size() > 1:
				print("")
				print("=== VARIANT %s ===" % _variant_label)
				print(_core.describe())
		_v6_runs = []
		for char_id: String in _characters_run:
			for p: String in pols:
				_world_report(char_id, p, seeds, floors)
		if _v6:
			_v6_aggregate_report(combo, floors)
	_world_characters_report(pols)
	if _v6:
		_v6_compare_report(combos)


func _world_report(char_id: String, policy: String, seeds: int, floors: int) -> void:
	var t_c: int = Time.get_ticks_msec()
	var runs: Array[Dictionary] = []
	for s: int in seeds:
		runs.append(_run_world(s + 1 + _seed_offset, char_id, policy, floors))
		if (s + 1) % 10 == 0:
			print("  ... %s %d/%d seeds, %.1f s%s" % [char_id, s + 1, seeds, (Time.get_ticks_msec() - t_c) / 1000.0, (" (kiep %d%s)" % [_kiep_level, " only" if _kiep_only else ""]) if _kiep_active else ""])
	if _v6:
		for tagged: Dictionary in runs:
			tagged["character"] = char_id
			tagged["policy"] = policy
	if _kiep_active:
		_kiep_note(char_id, policy, runs, floors)
		if _kiep_compact:
			return
	var n: float = float(runs.size())
	var wins: Array = []
	var deaths_by_floor: Array = []
	deaths_by_floor.resize(floors + 1)
	deaths_by_floor.fill(0)
	var by_region: Dictionary = {}
	var deaths_kind: Dictionary = {}
	var hp_in: Array = []
	var hp_out: Array = []
	for f: int in floors + 1:
		hp_in.append([])
		hp_out.append([])
	for r: Dictionary in runs:
		if bool(r["won"]):
			wins.append(r)
		else:
			var df: int = int(r["death_floor"])
			deaths_by_floor[df] = int(deaths_by_floor[df]) + 1
			var dk: String = "f%s/%s" % ["final" if df == floors else str(df + 1), str(r["death_kind"])]
			deaths_kind[dk] = int(deaths_kind.get(dk, 0)) + 1
		var path: Array = r["path"]
		var f0: int = int(r.get("f_from", 0))
		for f: int in path.size():
			var key: String = "%d|%s" % [f + f0, str(path[f])]
			if not by_region.has(key):
				by_region[key] = [0, 0]
			by_region[key][0] = int(by_region[key][0]) + 1
			if int(r["floors_cleared"]) > f + f0:
				by_region[key][1] = int(by_region[key][1]) + 1
		for f: int in (r["hp_in"] as Array).size():
			(hp_in[mini(f + f0, floors)] as Array).append(float(r["hp_in"][f]))
		for f: int in (r["hp_out"] as Array).size():
			(hp_out[mini(f + f0, floors)] as Array).append(float(r["hp_out"][f]))
	var total_deaths: int = runs.size() - wins.size()
	var win_pct: float = 100.0 * wins.size() / maxf(n, 1.0)
	var won_min: Array = _field(wins, "minutes")
	var all_min: Array = _field(runs, "minutes")
	var luck_mean: float = _mean(_field(runs, "luck"))
	var weights: Dictionary = RewardRoller.luck_rarity_weights(_reward_config, luck_mean)
	var real_sum: float = _sum(_field(runs, "real_sec"))
	var sim_sum: float = _sum(_field(runs, "sim_sec"))
	var match_n: float = maxf(_sum(_field(runs, "matches")), 1.0)
	var hits_won: String = ("%.1f" % _mean(_field(wins, "hits"))) if not wins.is_empty() else "-"
	var won_min_text: String = ("%.1f (%.1f-%.1f)" % [_mean(won_min), won_min.min(), won_min.max()]) if not won_min.is_empty() else "-"
	print("")
	print("=== WORLD %s / %s: %d runs ===" % [char_id, policy, runs.size()])
	print("WORLD SUMMARY | character | policy | run win % | wins | boss hits / WON run | hits / run (all) | matches / run | nodes / run | mean match real sec | mean match sim sec | timeouts / run | est. minutes WON run mean (min-max) | est. minutes all runs | final luck (all runs) | rarity weights c/r/e at that luck | final deck size | deck level sum | tokens spent | rest heal / rest forge / treasure per run |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	print("| %s | %s | %.1f | %d | %s | %.1f | %.2f | %.2f | %.1f | %.1f | %.2f | %s | %.1f | %.1f | %.0f/%.0f/%.0f | %.2f | %.2f | %.2f | %.2f / %.2f / %.2f |" % [
		char_id, policy, win_pct, wins.size(), hits_won, _mean(_field(runs, "hits")),
		_mean(_field(runs, "matches")), _mean(_field(runs, "nodes")), real_sum / match_n, sim_sum / match_n, _mean(_field(runs, "timeouts")),
		won_min_text, _mean(all_min), luck_mean,
		float(weights.get("common", 0.0)), float(weights.get("rare", 0.0)), float(weights.get("epic", 0.0)),
		_mean(_field(runs, "size")), _mean(_field(runs, "levels")), _mean(_field(runs, "tokens")),
		_mean(_field(runs, "rest_heal")), _mean(_field(runs, "rest_forge")), _mean(_field(runs, "treasure"))])
	print("")
	print("WORLD FLOORS | character | floor | alive after % | deaths | deaths % of all deaths | clear % of runs entering | mean HP % entering | mean HP % after boss (before heal) |")
	print("|---|---|---|---|---|---|---|---|")
	var alive: int = runs.size()
	var max_share: float = 0.0
	var alive_list: Array = []
	for f: int in floors + 1:
		var entering: int = alive
		alive -= int(deaths_by_floor[f])
		alive_list.append(100.0 * alive / maxf(n, 1.0))
		var share: float = 100.0 * int(deaths_by_floor[f]) / maxf(float(total_deaths), 1.0)
		max_share = maxf(max_share, share)
		print("| %s | %s | %.1f | %d | %.1f | %.1f | %.1f | %.1f |" % [char_id, "final" if f == floors else str(f + 1), 100.0 * alive / maxf(n, 1.0),
			int(deaths_by_floor[f]), share, 100.0 * alive / maxf(float(entering), 1.0), 100.0 * _mean(hp_in[f]), 100.0 * _mean(hp_out[f])])
	print("")
	print("WORLD REGIONS | character | floor | region | entered | cleared | clear % |")
	print("|---|---|---|---|---|---|")
	var max_spread: float = 0.0
	for f: int in floors:
		var lo: float = INF
		var hi: float = -INF
		for id: String in _chapters.region_ids():
			var key: String = "%d|%s" % [f, id]
			if not by_region.has(key):
				continue
			var e: int = int(by_region[key][0])
			var c: int = int(by_region[key][1])
			var pct: float = 100.0 * c / maxf(float(e), 1.0)
			print("| %s | %d | %s | %d | %d | %.1f |" % [char_id, f + 1, id, e, c, pct])
			if e >= WORLD_REGION_MIN_N:
				lo = minf(lo, pct)
				hi = maxf(hi, pct)
		if hi >= lo:
			max_spread = maxf(max_spread, hi - lo)
	print("")
	var dk_keys: Array = deaths_kind.keys()
	dk_keys.sort()
	var dk_cells: Array[String] = []
	for k: Variant in dk_keys:
		dk_cells.append("%s=%d" % [k, int(deaths_kind[k])])
	print("WORLD DEATHS BY FLOOR/KIND %s: %s" % [char_id, ", ".join(PackedStringArray(dk_cells))])
	_world_relic_report(char_id, policy, runs)
	_world_economy_report(char_id, policy, runs)
	if not _core.piece_deck_spec.is_empty():
		_world_piece_report(char_id, policy, runs, win_pct)
	if not _fate_policy.is_empty():
		_world_fate_report(char_id, policy, runs, floors, win_pct)
	_world_wins["%s|%s" % [char_id, policy]] = {"win": win_pct, "wins": wins.size(), "n": runs.size()}
	var t_win: Array = WORLD_WIN_TARGET.get(char_id, [20.0, 40.0])
	var win_ok: bool = win_pct >= float(t_win[0]) and win_pct <= float(t_win[1])
	var min_mean: float = _mean(won_min)
	var min_ok: bool = not won_min.is_empty() and min_mean >= float(WORLD_MINUTES_TARGET[0]) and min_mean <= float(WORLD_MINUTES_TARGET[1])
	var min_verdict: String = "PASS" if min_ok else ("NO WINS" if won_min.is_empty() else ("TOO SHORT" if min_mean < float(WORLD_MINUTES_TARGET[0]) else "TOO LONG"))
	var decreasing: bool = true
	for f: int in range(1, alive_list.size()):
		decreasing = decreasing and float(alive_list[f]) < float(alive_list[f - 1])
	print("WORLD VERDICT %s/%s: run win %.1f%% (target %.0f-%.0f) %s; est. minutes won run %s (target %.0f-%.0f) %s; max region spread at a floor %.1f pts (target <= %.0f, n >= %d) %s; max floor share of deaths %.1f%% (target <= %.0f) %s; survival strictly decreasing %s; boss hits / won run %s" % [
		char_id, policy, win_pct, float(t_win[0]), float(t_win[1]), "PASS" if win_ok else ("TOO EASY" if win_pct > float(t_win[1]) else "TOO HARD"),
		("%.1f" % min_mean) if not won_min.is_empty() else "-", float(WORLD_MINUTES_TARGET[0]), float(WORLD_MINUTES_TARGET[1]), min_verdict,
		max_spread, WORLD_REGION_SPREAD_MAX, WORLD_REGION_MIN_N, "PASS" if max_spread <= WORLD_REGION_SPREAD_MAX else "FAIL",
		max_share, WORLD_FLOOR_DEATH_SHARE_MAX, "PASS" if max_share <= WORLD_FLOOR_DEATH_SHARE_MAX else "FAIL",
		"PASS" if decreasing else "FAIL (a floor with no deaths)", hits_won])
	if _v6:
		_v6_runs.append_array(runs)
		_v6_run_report(char_id, policy, runs, floors, win_pct)


# Story 034 (only with --piece-deck): the D2 measures of one character/policy over its world runs, every
# match of the run summed (tran_thach extra fights included). Hit % by cast cells = hits / resolved player
# casts of that many cells; join % and featured % are per cast; region clear % = regions cleared / entered.
func _world_piece_report(char_id: String, policy: String, runs: Array[Dictionary], win_pct: float) -> void:
	var t: Dictionary = {}
	for k: String in ["matches", "p_casts", "p_cells", "p_res", "p_hits", "p_joins", "p_feat", "p_int", "p_intd", "p_fallback"]:
		t[k] = _sum(_field(runs, k))
	var size_res: Dictionary = {}
	var size_hits: Dictionary = {}
	var entered: float = 0.0
	var cleared: float = 0.0
	for r: Dictionary in runs:
		for size: Variant in (r["p_size_res"] as Dictionary).keys():
			size_res[int(size)] = int(size_res.get(int(size), 0)) + int(r["p_size_res"][size])
		for size: Variant in (r["p_size_hits"] as Dictionary).keys():
			size_hits[int(size)] = int(size_hits.get(int(size), 0)) + int(r["p_size_hits"][size])
		entered += float((r["path"] as Array).size())
		cleared += float(mini(int(r["floors_cleared"]), (r["path"] as Array).size()))
	var sizes: Array = size_res.keys()
	sizes.sort()
	var by_size: Array[String] = []
	for size: Variant in sizes:
		var n_res: int = int(size_res[size])
		by_size.append("%d:%.0f(%d)" % [int(size), 100.0 * int(size_hits.get(size, 0)) / maxf(float(n_res), 1.0), n_res])
	var mm: float = maxf(float(t["matches"]), 1.0)
	var casts: float = maxf(float(t["p_casts"]), 1.0)
	print("")
	print("WORLD PIECES | character | policy | piece deck | fallback matches / matches | casts / match | cells / cast | player hit % | hit % by cast cells (resolved n) | joins / match (% of casts) | featured / match (% of casts) | interrupts landed / match | interrupts suffered / match | region clear % (cleared/entered) | run win % |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	print("| %s | %s | %s | %d / %d | %.2f | %.2f | %.1f | %s | %.2f (%.0f) | %.2f (%.0f) | %.2f | %.2f | %.1f (%d/%d) | %.1f |" % [
		char_id, policy, _core.piece_deck_spec.replace("|", " + "), int(t["p_fallback"]), int(t["matches"]), float(t["p_casts"]) / mm,
		float(t["p_cells"]) / casts, 100.0 * float(t["p_hits"]) / maxf(float(t["p_res"]), 1.0), " ".join(PackedStringArray(by_size)),
		float(t["p_joins"]) / mm, 100.0 * float(t["p_joins"]) / casts, float(t["p_feat"]) / mm, 100.0 * float(t["p_feat"]) / casts,
		float(t["p_int"]) / mm, float(t["p_intd"]) / mm, 100.0 * cleared / maxf(entered, 1.0), int(cleared), int(entered), win_pct])


# Story 032: one line per character/policy: relics owned at run end (mean), how many runs owned each relic
# at the end and the relic triggers per run (the relics' `triggered` signals, summed over the run's matches).
func _world_relic_report(char_id: String, policy: String, runs: Array[Dictionary]) -> void:
	var owned: Dictionary = {}
	var trig: Dictionary = {}
	for r: Dictionary in runs:
		for id: Variant in r["relics"] as Array:
			owned[id] = int(owned.get(id, 0)) + 1
		for id: Variant in (r["relic_trig"] as Dictionary).keys():
			trig[id] = int(trig.get(id, 0)) + int(r["relic_trig"][id])
	var n: float = maxf(float(runs.size()), 1.0)
	var owned_cells: Array[String] = []
	var trig_cells: Array[String] = []
	for id: String in _core.relic_config.ids():
		if owned.has(id):
			owned_cells.append("%s=%d" % [id, int(owned[id])])
		if trig.has(id):
			trig_cells.append("%s=%.1f" % [id, float(trig[id]) / n])
	print("WORLD RELICS %s/%s: relic-policy=%s mean relics at end %.2f | owned at end (runs): %s | triggers / run: %s" % [char_id, policy, _relic_policy,
		_mean(_field(runs, "relic_n")), ", ".join(PackedStringArray(owned_cells)) if not owned_cells.is_empty() else "none",
		", ".join(PackedStringArray(trig_cells)) if not trig_cells.is_empty() else "none"])


# Story 032 --relic-policy=pick at a treasure node: rolls the relic row and adds the rarest offered relic
# to [param owned]. False (the card row is used) with relic-policy none, the always_skip policy or an
# empty relic row.
func _take_relic(owned: Array[String], policy: String, relic_seed: int) -> bool:
	if _relic_policy != "pick" or policy == "always_skip":
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = relic_seed
	# Story 037: a locked relic is not rolled; it is passed as "owned", which RelicRoller already never offers.
	var offer: Array[String] = RelicRoller.roll(RelicRoller.SOURCE_TREASURE, _owned_or_locked(owned), rng, _core.relic_config)
	if offer.is_empty():
		return false
	owned.append(_rarest_relic(offer, relic_seed))
	return true


# Story 037: the owned relics plus the ones still locked (a fresh array; [param owned] is not changed).
func _owned_or_locked(owned: Array[String]) -> Array[String]:
	var out: Array[String] = owned.duplicate()
	for id: String in _core.locked_ids("relic"):
		if not out.has(id):
			out.append(id)
	return out


# The relic --relic-policy=pick takes from a non-empty [param offer]: the rarest, the first on a tie.
func _rarest_relic(offer: Array[String], pick_seed: int = 0) -> String:
	if _relic_mode == "value":
		return _value_relic(offer)
	if _relic_mode == "random":
		var pick_rng := RandomNumberGenerator.new()
		pick_rng.seed = hash([pick_seed, "relic_pick"]) & SEED_MASK
		return offer[pick_rng.randi_range(0, offer.size() - 1)]
	var best: String = offer[0]
	for id: String in offer:
		if RelicConfig.rarity_rank(str(_core.relic_config.get_relic(id)["rarity"])) > RelicConfig.rarity_rank(str(_core.relic_config.get_relic(best)["rarity"])):
			best = id
	return best


# Story 035 --fate: the bot's fate at a downed region boss (the [param fate_index]-th of the run, 0-based):
# execute -> FateLogic.roll_execute_offer (world.fate of the chapters in use, the sim's relic config) and one
# relic of it is taken (the rarest with --relic-policy=pick, else the first offered); spare -> nothing;
# alternate -> execute, spare, execute, ... The boss reward (cards + token) is applied by the caller as today.
# Story 037: added to the fate index of --fate=alternate; --unlock-runs sets it to the ledger's choices so far, so the
# alternation continues across runs (0 everywhere else: unchanged).
var _fate_offset: int = 0


func _take_fate(w: WorldRun, fate_index: int, fate_seed: int, out: Dictionary) -> String:
	var fate: String = _fate_policy
	if fate == "alternate":
		fate = FateLogic.FATE_EXECUTE if (fate_index + _fate_offset) % 2 == 0 else FateLogic.FATE_SPARE
	if fate == FateLogic.FATE_SPARE:
		out["fate_spare"] = float(out["fate_spare"]) + 1.0
		return fate
	out["fate_exec"] = float(out["fate_exec"]) + 1.0
	var offer: Array[String] = FateLogic.roll_execute_offer(w.relics, _chapters.fate_config(), _core.relic_config, fate_seed, 0.0, _core.locked_ids("relic"))
	if offer.is_empty():
		return fate
	w.relics.append(_rarest_relic(offer, fate_seed) if _relic_policy == "pick" else offer[0])
	out["fate_relics"] = float(out["fate_relics"]) + 1.0
	return fate


# Story 035 F4 (only with --fate): run win, final-match win when reached, the final's share of deaths,
# deaths by floor, fates and relics from executes per run, how many final matches reached phase 2, and
# the FATE TARGETS line. The "execute beats spare" target compares two runs (the orchestrator does).
func _world_fate_report(char_id: String, policy: String, runs: Array[Dictionary], floors: int, win_pct: float) -> void:
	var n: float = maxf(float(runs.size()), 1.0)
	var reached: int = 0
	var final_won: int = 0
	var phase2: int = 0
	var boss_hp_left: Array = []
	var deaths: int = 0
	var by_floor: Array = []
	by_floor.resize(floors + 1)
	by_floor.fill(0)
	for r: Dictionary in runs:
		if bool(r["final_reached"]):
			reached += 1
			if bool(r["won"]):
				final_won += 1
			if int(r["final_phase"]) >= 2:
				phase2 += 1
			boss_hp_left.append(100.0 * float(r["final_boss_hp"]))
		if not bool(r["won"]):
			deaths += 1
			var df: int = clampi(int(r["death_floor"]), 0, floors)
			by_floor[df] = int(by_floor[df]) + 1
	var floor_cells: Array[String] = []
	for f: int in floors + 1:
		floor_cells.append("%s=%d" % ["final" if f == floors else "f%d" % (f + 1), int(by_floor[f])])
	var final_deaths: int = int(by_floor[floors])
	var final_pct: float = 100.0 * final_won / maxf(float(reached), 1.0)
	var share: float = 100.0 * final_deaths / maxf(float(deaths), 1.0)
	print("")
	print("WORLD FATE | character | policy | fate | relic-policy | run win % | wins | final reached | final won | final-match win % when reached | deaths | final deaths | final % of deaths | executes / run | spares / run | relics from executes / run |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	print("| %s | %s | %s | %s | %.1f | %d | %d | %d | %s | %d | %d | %s | %.2f | %.2f | %.2f |" % [char_id, policy, _fate_policy, _relic_policy,
		win_pct, runs.size() - deaths, reached, final_won, ("%.1f" % final_pct) if reached > 0 else "-", deaths, final_deaths,
		("%.1f" % share) if deaths > 0 else "-", _mean(_field(runs, "fate_exec")), _mean(_field(runs, "fate_spare")), _sum(_field(runs, "fate_relics")) / n])
	print("FATE DEATHS BY FLOOR %s/%s (fate=%s): %s" % [char_id, policy, _fate_policy, ", ".join(PackedStringArray(floor_cells))])
	print("FATE FINAL PHASES %s/%s: final phase 2 reached in %d of %d final matches | final boss HP %% left at the end: mean %s, min %s" % [
		char_id, policy, phase2, reached, ("%.1f" % _mean(boss_hp_left)) if reached > 0 else "-", ("%.1f" % float(boss_hp_left.min())) if reached > 0 else "-"])
	var win_verdict: String = "NO DATA (final never reached)"
	if reached > 0:
		win_verdict = "PASS" if final_pct >= FATE_FINAL_WIN_TARGET[0] and final_pct <= FATE_FINAL_WIN_TARGET[1] else ("TOO EASY" if final_pct > FATE_FINAL_WIN_TARGET[1] else "TOO HARD")
	var share_verdict: String = "NO DEATHS" if deaths == 0 else ("PASS" if share <= FATE_FINAL_DEATH_SHARE_MAX else "FAIL")
	print("FATE TARGETS %s/%s (fate=%s): final-match win when reached %s%% (%d/%d) in %.0f-%.0f: %s | final share of deaths %s%% (%d/%d) <= %.0f: %s | run win %.1f%% (execute beats spare by %.0f-%.0f pts: compare the --fate=execute and --fate=spare run wins)" % [
		char_id, policy, _fate_policy, ("%.1f" % final_pct) if reached > 0 else "-", final_won, reached, FATE_FINAL_WIN_TARGET[0], FATE_FINAL_WIN_TARGET[1], win_verdict,
		("%.1f" % share) if deaths > 0 else "-", final_deaths, deaths, FATE_FINAL_DEATH_SHARE_MAX, share_verdict,
		win_pct, FATE_EXECUTE_EDGE_TARGET[0], FATE_EXECUTE_EDGE_TARGET[1]])


func _field(runs: Array, key: String) -> Array:
	var out: Array = []
	for r: Variant in runs:
		out.append(float((r as Dictionary)[key]))
	return out


# One world run: floors x (offer -> pick -> region map column by column) then the final match.
func _run_world(seed_value: int, char_id: String, policy: String, floors: int) -> Dictionary:
	var base_character: Dictionary = _core.characters.get_character(char_id)
	if _kiep_level > 0:
		# Story 038 (Kiep 8): the run's max HP = the character's x max_hp_mult (GameFlow's _character_dict), before the sim's --hp-mult.
		base_character = KiepRules.shared().apply_run_start(base_character, _kiep_level)
	var character: Dictionary = _core.prepare_character(base_character)
	var max_hp: float = float(character["max_hp"])
	var w := WorldRun.new()
	w.run_seed = seed_value
	w.kiep_level = _kiep_level
	w.removal_tokens = int(_reward_config.get("starting_removals", 0))
	w.relics.assign(_core.ov["relics"] as Array)
	w.gold = _economy.starting_gold()
	for id: Variant in character.get("starter_deck", []) as Array:
		w.deck.append({"id": str(id), "level": 1})
	var bot_rng := RandomNumberGenerator.new()
	bot_rng.seed = hash([seed_value, char_id]) & SEED_MASK
	# Region picks do not depend on the character: same seed -> same path while alive.
	var pick_rng := RandomNumberGenerator.new()
	pick_rng.seed = hash([seed_value, "region_pick"]) & SEED_MASK
	var out: Dictionary = {"won": false, "death_floor": -1, "death_kind": "", "floors_cleared": 0, "path": [], "hits": 0.0,
		"matches": 0.0, "nodes": 0.0, "real_sec": 0.0, "sim_sec": 0.0, "timeouts": 0.0, "hp_in": [], "hp_out": [],
		"rest_heal": 0.0, "rest_forge": 0.0, "treasure": 0.0, "tokens": 0.0, "zpicks": 0.0, "relic_trig": {},
		# Story 033 economy.
		"gold_drop": 0.0, "gold_event_in": 0.0, "gold_event_out": 0.0, "gold_spent": 0.0, "gold_left": 0.0,
		"shops": 0.0, "shop_items": [], "first_shop_items": -1.0, "first_shop_gold": -1.0,
		"seen_shop_gold": -1.0, "seen_shop_afford": -1.0, "seen_shop_floor": -1.0,
		"relics_bought": 0.0, "cards_bought": 0.0, "heals_bought": 0.0,
		"events": 0.0, "event_risky": 0.0, "event_picks": {}, "tt_fights": 0.0, "tt_deaths": 0.0,
		"curses": 0.0, "curse_draws": 0.0, "curse_dmg": 0.0, "mod_matches": 0.0,
		# Story 034 (printed only with --piece-deck): player casts, cells, resolved, hits, joins, featured,
		# interrupts landed / suffered, resolved / hits by cast cells, matches where the deck fell back.
		"p_casts": 0.0, "p_cells": 0.0, "p_res": 0.0, "p_hits": 0.0, "p_joins": 0.0, "p_feat": 0.0,
		"p_int": 0.0, "p_intd": 0.0, "p_size_res": {}, "p_size_hits": {}, "p_fallback": 0.0,
		# Story 035 (printed only with --fate): fates taken, relics from executes, the final match reached
		# and the highest boss_phases phase entered in it.
		# Story 037 (read by the unlock-runs mode only): one entry per match node played, in order, see _match_record.
		"match_log": [],
		"fate_exec": 0.0, "fate_spare": 0.0, "fate_relics": 0.0, "final_reached": false, "final_phase": 0,
		"final_boss_hp": 0.0,
		# Story 040 (read by the v6 tables only): out-of-match seconds, the matches' intro + end delay, the boss swing hits and
		# damage, the per-match log [floor, region, won, kind], the per-shop log, the relics owned when floor 2 ended, the
		# gold when the final floor was entered, the run's first floor index, max HP, piece-deck policy counters.
		"oo_sec": 0.0, "match_extra_sec": 0.0, "shits": 0.0, "bdmg": 0.0, "mlog": [], "shop_log": [], "relics_f2": [],
		"gold_at_final": -1.0, "f_from": 0, "max_hp": max_hp, "ink_taken": 0.0, "shape_removed": 0.0, "piece_n": 0.0}
	var choices: int = int(_chapters.world_spec().get("choices_per_floor", 2))
	var path: Array[String] = []
	var lost: bool = false
	var f_range: Vector2i = _f_range(floors)
	out["f_from"] = f_range.x
	out["relics_f2"] = w.relics.duplicate()
	if _pieces_on:
		w.piece_deck = PieceDeck.initial(_core.piece_lib)
		w.shape_removals = _core.piece_deck_cfg.shape_removals_start
		_pieces_use_tokens(w, out)
	for f: int in range(f_range.x, f_range.y + 1):
		w.floor = f
		var map: Array[Dictionary] = []
		if f < floors:
			var offer: Array[String] = WorldMapGen.offer_for_floor(_open_region_ids(), seed_value, f, path, choices)
			if offer.is_empty():
				break
			var region: String = offer[0] if _region_pick == "first" else offer[pick_rng.randi_range(0, offer.size() - 1)]
			path.append(region)
			w.region_id = region
			map = _chapters.generate_region_map(region, seed_value, f, CLEARED_BOSSES_MAIN, _kiep_level)
		else:
			var fm: Dictionary = _chapters.final_match()
			if fm.is_empty():
				break
			w.region_id = str(fm["region"])
			# TD-029: the `world.final_prelude` columns (a shop) come first, through the same node policy.
			map = _chapters.final_map()
			out["final_reached"] = true
		w.chapter_index = _chapters.region_index(w.region_id)
		(out["hp_in"] as Array).append(_hp_ratio(w, max_hp))
		for col: int in map.size():
			w.column = col
			var nodes: Array[Dictionary] = []
			var raw_nodes: Array = map[col].get("nodes", [])
			for i: int in raw_nodes.size():
				var nd: Dictionary = (raw_nodes[i] as Dictionary).duplicate()
				nd["node_index"] = i
				nodes.append(nd)
			if nodes.is_empty():
				continue
			_note_first_shop(nodes, w, out)
			var node: Dictionary = _world_choose_node(nodes, w, max_hp)
			var kind: String = str(node.get("kind", ""))
			out["nodes"] = float(out["nodes"]) + 1.0
			out["oo_sec"] = float(out["oo_sec"]) + OOM_MAP_SEC
			if kind == ChapterMapGen.KIND_SHOP:
				out["oo_sec"] = float(out["oo_sec"]) + OOM_SHOP_SEC
				_visit_shop(w, int(node["node_index"]), policy, max_hp, out)
				w.nodes_cleared += 1
				continue
			if kind == ChapterMapGen.KIND_EVENT:
				out["oo_sec"] = float(out["oo_sec"]) + OOM_EVENT_SEC
				if not _visit_event(w, int(node["node_index"]), int(map[col].get("tier", 0)), max_hp, character, bot_rng, out):
					lost = true
					out["death_floor"] = f
					out["death_kind"] = "event_fight"
					break
				w.nodes_cleared += 1
				continue
			if kind == ChapterMapGen.KIND_REST:
				out["oo_sec"] = float(out["oo_sec"]) + OOM_REST_SEC
				var forge_index: int = _forge_index(w)
				if _hp_ratio(w, max_hp) < REST_HEAL_BELOW or forge_index < 0:
					w.rest_heal(max_hp, _reward_config)
					out["rest_heal"] = float(out["rest_heal"]) + 1.0
				else:
					w.rest_forge(forge_index, _reward_config)
					out["rest_forge"] = float(out["rest_forge"]) + 1.0
				w.nodes_cleared += 1
				continue
			if kind == ChapterMapGen.KIND_TREASURE:
				out["treasure"] = float(out["treasure"]) + 1.0
				_drop_gold(w, kind, int(node["node_index"]), out)
				if not _take_relic(w.relics, policy, hash([seed_value, f, col, int(node["node_index"]), RELIC_SEED_TAG]) & SEED_MASK):
					_apply_policy(w, policy, kind, out)
				else:
					out["oo_sec"] = float(out["oo_sec"]) + OOM_REWARD_SEC
				w.nodes_cleared += 1
				_pieces_after_node(w, kind, out)
				continue
			var match_seed: int = hash([seed_value, f, w.region_id, col, int(node["node_index"])]) & SEED_MASK
			if f == floors:
				out["gold_at_final"] = float(w.gold)
			var r: Dictionary = _world_match(w, kind, str(node.get("match_id", "")), match_seed, character, bot_rng, out)
			var rec: Dictionary = _match_record(r, w, kind, str(node.get("match_id", "")), f == floors)
			(out["match_log"] as Array).append(rec)
			if f == floors:
				out["final_phase"] = int(r.get("boss_phase", 0))
				out["final_boss_hp"] = float(r.get("boss_hp_end_ratio", 0.0))
			if not bool(r["won"]):
				lost = true
				out["death_floor"] = f
				out["death_kind"] = "final" if f == floors else kind
				break
			w.hp = minf(float(r["hp_end"]) + maxf(float(r["passive_heal"]), 0.0), max_hp)
			# Story 033: GameFlow._complete_match_node = gold drop, then the run modifiers tick.
			_drop_gold(w, kind, int(node["node_index"]), out)
			_tick_modifiers(w)
			w.nodes_cleared += 1
			if kind == ChapterMapGen.KIND_BOSS:
				w.removal_tokens += int(_reward_config.get("boss_removal_tokens", 1))
				if _pieces_on:
					w.shape_removals += maxi(_core.piece_deck_cfg.shape_removals_per_boss, 0)
			# Story 035: the fate of a downed region boss comes before its reward (GameFlow order).
			if not _fate_policy.is_empty() and FateLogic.is_boss_fate_node(kind, f == floors):
				rec["fate"] = _take_fate(w, int(float(out["fate_exec"]) + float(out["fate_spare"])),
					hash([seed_value, f, w.region_id, FATE_SEED_TAG]) & SEED_MASK, out)
				out["oo_sec"] = float(out["oo_sec"]) + OOM_FATE_SEC
			_apply_policy(w, policy, kind, out)
			_pieces_after_node(w, kind, out)
			rec["deck_ids"] = _deck_ids(w)
		if f == 1 or (lost and f <= 1):
			out["relics_f2"] = w.relics.duplicate()
		if lost:
			break
		(out["hp_out"] as Array).append(_hp_ratio(w, max_hp))
		out["floors_cleared"] = f + 1
		if f < floors:
			var before: float = max_hp if w.hp < 0.0 else minf(w.hp, max_hp)
			var heal_ratio: float = _chapters.floor_heal_ratio()
			if _kiep_level > 0:
				heal_ratio = KiepRules.shared().floor_heal_ratio(heal_ratio, _kiep_level)
			w.hp = minf(before + maxf(heal_ratio, 0.0) * max_hp, max_hp)
	out["won"] = not lost and int(out["floors_cleared"]) == f_range.y + 1
	out["deck_ids"] = _deck_ids(w)
	out["path"] = path
	out["relics"] = w.relics.duplicate()
	out["relic_n"] = w.relics.size()
	out["gold_left"] = float(w.gold)
	out["luck"] = w.luck(_reward_config)
	out["minutes"] = (float(out["real_sec"]) + _node_overhead * float(out["nodes"])) / 60.0
	# Story 040: the v6 estimate = match real seconds + the out-of-match table (+ each match's intro / end delay); `--node-overhead`
	# given = the old formula. The WORLD SUMMARY keeps `minutes` above, so the old output is unchanged.
	out["minutes_est"] = float(out["minutes"]) if _node_overhead_given else (float(out["real_sec"]) + float(out["oo_sec"]) + float(out["match_extra_sec"])) / 60.0
	out["piece_n"] = float(PieceDeck.active_ids(w.piece_deck, _core.piece_lib).size()) if _pieces_on else float(_core.piece_lib.base_shape_ids().size())
	out["size"] = w.deck.size()
	var level_sum: int = 0
	for e: Dictionary in w.deck:
		level_sum += int(e["level"])
	out["levels"] = level_sum
	return out


# Story 022 node policy plus Story 031's "take rest when HP < REST_HEAL_BELOW" (rest before treasure then).
# Story 033: shop / event are treasure-level options: rest (HP low) > treasure > shop (greedy, gold >=
# SHOP_MIN_GOLD) > event (risky) > the Story 022 order over the other nodes. With --shop-policy=none /
# --event-policy=leave those nodes are only entered when the column has nothing else (walked past).
func _world_choose_node(nodes: Array[Dictionary], w: WorldRun, max_hp: float) -> Dictionary:
	if _hp_ratio(w, max_hp) < REST_HEAL_BELOW:
		for n: Dictionary in nodes:
			if str(n.get("kind", "")) == ChapterMapGen.KIND_REST:
				return n
	var by_kind: Dictionary = {}
	var others: Array[Dictionary] = []
	for n: Dictionary in nodes:
		var k: String = str(n.get("kind", ""))
		if not by_kind.has(k):
			by_kind[k] = n
		if k != ChapterMapGen.KIND_SHOP and k != ChapterMapGen.KIND_EVENT:
			others.append(n)
	# eager: a shop beats a treasure once the bot holds SHOP_MIN_GOLD (greedy takes the treasure first).
	if _shop_policy == "eager" and by_kind.has(ChapterMapGen.KIND_SHOP) and w.gold >= SHOP_MIN_GOLD:
		return by_kind[ChapterMapGen.KIND_SHOP]
	if by_kind.has(ChapterMapGen.KIND_TREASURE) and not _no_treasure:
		return by_kind[ChapterMapGen.KIND_TREASURE]
	if _shop_policy == "greedy" and by_kind.has(ChapterMapGen.KIND_SHOP) and w.gold >= SHOP_MIN_GOLD:
		return by_kind[ChapterMapGen.KIND_SHOP]
	if _event_policy == "risky" and by_kind.has(ChapterMapGen.KIND_EVENT):
		return by_kind[ChapterMapGen.KIND_EVENT]
	if others.is_empty():
		return nodes[0]
	return _bot_choose_node(others, w, max_hp)


# ---------------------------------------------------------------- Story 038 Kiep levels


# "0..10", "3", "0,2,5" or "0,3..5" -> the distinct levels 0..KiepRules.max_level() in ascending order (bad items skipped).
func _parse_kiep_levels(v: String) -> Array[int]:
	var top: int = KiepRules.shared().max_level()
	var seen: Dictionary = {}
	for item: String in v.split(","):
		var s: String = item.strip_edges()
		if s.is_empty():
			continue
		var lo: int = -1
		var hi: int = -1
		if s.contains(".."):
			var a: String = s.get_slice("..", 0).strip_edges()
			var b: String = s.get_slice("..", 1).strip_edges()
			if a.is_valid_int() and b.is_valid_int():
				lo = int(a)
				hi = int(b)
		elif s.is_valid_int():
			lo = int(s)
			hi = lo
		if lo < 0 or hi < lo or hi > top:
			print("KIEP: '%s' is not a level or range inside 0..%d, skipped" % [s, top])
			continue
		for k: int in range(lo, hi + 1):
			seen[k] = true
	var out: Array[int] = []
	for k: Variant in seen.keys():
		out.append(int(k))
	out.sort()
	return out


# Every level in turn on the same seeds (a level 0 run is the normal game). --kiep-only sets KiepRules.set_only(k) first (that level's
# own rules alone). Several levels = compact (the KIEP tables only) unless --kiep-full.
func _run_kiep_levels(pols: Array[String], seeds: int, floors: int) -> void:
	var rules: KiepRules = KiepRules.shared()
	_kiep_compact = _kiep_levels.size() > 1 and not _kiep_full
	print("KIEP: %s levels=%s seeds=%d characters=%s policies=%s (same seeds at every level; %s)" % [
		"ONLY (each level's own rules alone)" if _kiep_only else "STACKED (rules of levels 1..k)", str(_kiep_levels), seeds,
		str(_characters_run), str(pols), "compact: the KIEP tables only (--kiep-full = every level's WORLD tables)" if _kiep_compact else "full WORLD tables per level"])
	for k: int in _kiep_levels:
		_kiep_level = k
		rules.set_only(k if _kiep_only else 0)
		print("")
		print("=== KIEP LEVEL %d%s ===" % [k, " (only its own rules)" if _kiep_only and k > 0 else ""])
		for char_id: String in _characters_run:
			for p: String in pols:
				_world_report(char_id, p, seeds, floors)
	rules.set_only(0)
	_kiep_level = 0
	if _kiep_levels.size() == 1:
		_world_characters_report(pols)
	_kiep_report(pols, floors)


# Records the row of one (level, character, policy): win %, wins, deaths by floor, est. minutes (WON run mean and all runs), boss hits per WON run.
func _kiep_note(char_id: String, policy: String, runs: Array[Dictionary], floors: int) -> void:
	var deaths: Array[int] = []
	deaths.resize(floors + 1)
	deaths.fill(0)
	var won: Array[Dictionary] = []
	for r: Dictionary in runs:
		if bool(r["won"]):
			won.append(r)
		else:
			var df: int = clampi(int(r["death_floor"]), 0, floors)
			deaths[df] += 1
	_kiep_rows.append({"character": char_id, "policy": policy, "level": _kiep_level, "n": runs.size(), "wins": won.size(),
		"win": 100.0 * won.size() / maxf(float(runs.size()), 1.0), "deaths": deaths,
		"min_won": _mean(_field(won, "minutes")) if not won.is_empty() else -1.0, "min_all": _mean(_field(runs, "minutes")),
		"hits_won": _mean(_field(won, "hits")) if not won.is_empty() else -1.0})


func _kiep_row(char_id: String, policy: String, level: int) -> Dictionary:
	for row: Dictionary in _kiep_rows:
		if str(row["character"]) == char_id and str(row["policy"]) == policy and int(row["level"]) == level:
			return row
	return {}


# The rule type names of level [param k] from kiep_levels.json ("shop_price_mult+boss_extra_trait").
func _kiep_rule_names(k: int) -> String:
	var names: Array[String] = []
	for rule: Variant in KiepRules.shared().level_def(k).get("rules", []) as Array:
		names.append(str((rule as Dictionary).get("type", "?")))
	return "+".join(PackedStringArray(names)) if not names.is_empty() else "none"


# The KIEP table (every row), then KIEP CHECK lines (stacked, 2+ levels) or KIEP ONLY lines (per-rule deltas vs level 0).
func _kiep_report(pols: Array[String], floors: int) -> void:
	var floor_names: Array[String] = []
	for f: int in floors + 1:
		floor_names.append("final" if f == floors else "f%d" % (f + 1))
	print("")
	print("KIEP | character | policy | level%s | run win %% | wins / runs | deaths by floor (%s) | est. minutes WON run mean | est. minutes all runs | boss hits / WON run |" % [
		" (only)" if _kiep_only else "", " ".join(PackedStringArray(floor_names))])
	for char_id: String in _characters_run:
		for p: String in pols:
			for k: int in _kiep_levels:
				var row: Dictionary = _kiep_row(char_id, p, k)
				if row.is_empty():
					continue
				var cells: Array[String] = []
				for f: int in floors + 1:
					cells.append(str((row["deaths"] as Array)[f]))
				print("KIEP | %s | %s | %d | %.1f | %d / %d | %s | %s | %.1f | %s |" % [char_id, p, k, float(row["win"]), int(row["wins"]), int(row["n"]),
					" ".join(PackedStringArray(cells)), ("%.1f" % float(row["min_won"])) if float(row["min_won"]) >= 0.0 else "-", float(row["min_all"]),
					("%.1f" % float(row["hits_won"])) if float(row["hits_won"]) >= 0.0 else "-"])
	if _kiep_only:
		_kiep_only_lines(pols)
	elif _kiep_levels.size() >= 2:
		_kiep_checks(pols)


# --kiep-only: one line per level: the rule, the win % and the change vs level 0 (when level 0 ran too), with 1 sd of the win %
# (sqrt(p(1-p)/n)) so a delta inside the noise is not read as an effect.
func _kiep_only_lines(pols: Array[String]) -> void:
	print("")
	print("KIEP ONLY | character | policy | level | rule | run win % | +-1 sd | vs level 0 (pts) | verdict | wins / runs |")
	for char_id: String in _characters_run:
		for p: String in pols:
			var base: Dictionary = _kiep_row(char_id, p, 0)
			for k: int in _kiep_levels:
				var row: Dictionary = _kiep_row(char_id, p, k)
				if row.is_empty():
					continue
				var pr: float = float(row["win"]) / 100.0
				var sd: float = 100.0 * sqrt(pr * (1.0 - pr) / maxf(float(row["n"]), 1.0))
				var delta_text: String = "-"
				var verdict: String = "BASELINE" if k == 0 else "no level 0 in this run"
				if k > 0 and not base.is_empty():
					var delta: float = float(row["win"]) - float(base["win"])
					delta_text = "%+.1f" % delta
					if delta <= -KIEP_NO_EFFECT_PTS:
						verdict = "HARDER"
					elif delta < KIEP_NO_EFFECT_PTS:
						verdict = "NO EFFECT (< %.0f pt: change the number or the order in kiep_levels.json)" % KIEP_NO_EFFECT_PTS
					else:
						verdict = "EASIER (noise or a bug)"
				print("KIEP ONLY | %s | %s | %d | %s | %.1f | %.1f | %s | %s | %d / %d |" % [char_id, p, k, _kiep_rule_names(k), float(row["win"]), sd,
					delta_text, verdict, int(row["wins"]), int(row["n"])])


# The story's checks per character / policy over the levels that ran (a check needing a level that did not run is skipped, said so).
func _kiep_checks(pols: Array[String]) -> void:
	print("")
	var all_ok: bool = true
	for char_id: String in _characters_run:
		for p: String in pols:
			var win: Dictionary = {}
			var minutes: Dictionary = {}
			var curve: Array[String] = []
			for k: int in _kiep_levels:
				var row: Dictionary = _kiep_row(char_id, p, k)
				if row.is_empty():
					continue
				win[k] = float(row["win"])
				minutes[k] = float(row["min_won"]) if float(row["min_won"]) >= 0.0 else -float(row["min_all"])
				curve.append("%d=%.1f" % [k, float(row["win"])])
			print("KIEP CHECK curve %s/%s: run win %% by level: %s" % [char_id, p, " ".join(PackedStringArray(curve))])
			var step_bad: Array[String] = []
			var skip_bad: Array[String] = []
			var drop_bad: Array[String] = []
			var worst_drop: float = 0.0
			var step_n: int = 0
			var skip_n: int = 0
			for k: int in _kiep_levels:
				if k >= 1 and win.has(k) and win.has(k - 1):
					step_n += 1
					if float(win[k]) > float(win[k - 1]) + KIEP_STEP_TOLERANCE:
						step_bad.append("k=%d (%.1f > %.1f + %.0f)" % [k, float(win[k]), float(win[k - 1]), KIEP_STEP_TOLERANCE])
					var drop: float = float(win[k - 1]) - float(win[k])
					worst_drop = maxf(worst_drop, drop)
					if drop > KIEP_MAX_DROP:
						drop_bad.append("k=%d (-%.1f)" % [k, drop])
				if k >= 2 and win.has(k) and win.has(k - 2):
					skip_n += 1
					if not float(win[k]) < float(win[k - 2]):
						skip_bad.append("k=%d (%.1f not < %.1f)" % [k, float(win[k]), float(win[k - 2])])
			var fails: int = 0
			fails += _kiep_check_line("monotone step %s/%s: win(k) <= win(k-1) + %.0f over %d pairs" % [char_id, p, KIEP_STEP_TOLERANCE, step_n], step_n, step_bad)
			fails += _kiep_check_line("monotone skip %s/%s: win(k) < win(k-2) over %d pairs" % [char_id, p, skip_n], skip_n, skip_bad)
			fails += _kiep_check_line("no big drop %s/%s: no drop > %.0f pts between neighbours (worst %.1f)" % [char_id, p, KIEP_MAX_DROP, worst_drop], step_n, drop_bad)
			var top: int = KiepRules.shared().max_level()
			if win.has(top):
				if KIEP_WIN10_MIN.has(char_id):
					var ok10: bool = float(win[top]) >= float(KIEP_WIN10_MIN[char_id])
					fails += 0 if ok10 else 1
					print("KIEP CHECK winnable %s/%s: level %d run win %.1f%% >= %.0f%%: %s" % [char_id, p, top, float(win[top]), float(KIEP_WIN10_MIN[char_id]), "PASS" if ok10 else "FAIL"])
				else:
					print("KIEP CHECK winnable %s/%s: level %d run win %.1f%% (INFO: the >= %.0f%% target is the Kiem si build's)" % [char_id, p, top, float(win[top]), float(KIEP_WIN10_MIN["kiem_si"])])
				var m10: float = float(minutes[top])
				var m_ok: bool = m10 > 0.0 and m10 <= KIEP_MINUTES_MAX
				fails += 0 if m_ok else 1
				print("KIEP CHECK minutes %s/%s: level %d est. minutes %s %.1f <= %.0f: %s" % [char_id, p, top, "(WON run mean)" if m10 > 0.0 else "(NO WINS: all-runs mean)", absf(m10), KIEP_MINUTES_MAX, "PASS" if m_ok else "FAIL"])
			else:
				print("KIEP CHECK winnable / minutes %s/%s: SKIPPED (level %d not in this run)" % [char_id, p, top])
			all_ok = all_ok and fails == 0
			print("KIEP CHECK RESULT %s/%s: %s" % [char_id, p, "ALL PASS" if fails == 0 else "FAIL (%d check(s))" % fails])
	print("KIEP CHECK RESULT: %s" % ("ALL PASS" if all_ok else "FAIL"))


# One KIEP CHECK line: SKIPPED when [param n] = 0 pairs, PASS when [param bad] is empty, else FAIL with the offenders. Returns 1 on FAIL.
func _kiep_check_line(label: String, n: int, bad: Array[String]) -> int:
	if n == 0:
		print("KIEP CHECK %s: SKIPPED (the needed levels did not run)" % label)
		return 0
	if bad.is_empty():
		print("KIEP CHECK %s: PASS" % label)
		return 0
	print("KIEP CHECK %s: FAIL at %s" % [label, ", ".join(PackedStringArray(bad))])
	return 1


# ---------------------------------------------------------------- Story 033 economy


# Plays one match of the world run (a node's or an event's extra fight) with the run's relics and run
# modifiers and adds its numbers to [param out]. Returns SimCore.play_match's result.
func _world_match(w: WorldRun, kind: String, match_id: String, match_seed: int, character: Dictionary,
		bot_rng: RandomNumberGenerator, out: Dictionary) -> Dictionary:
	var run_config: RunConfig = RunConfig.from_node(_chapters, w.region_id, match_id, kind, w.run_seed, w.floor, w.kiep_level)
	var m: Dictionary = _core.prepare_match(run_config.matches[0])
	m["chapter_id"] = w.region_id
	_core.invulnerable = false
	_core.time_limit_sec = SimCore.MATCH_TIMEOUT_SEC
	_core.trace = (_trace_n >= 0 and _matches_seen == _trace_n) or (not _trace_id.is_empty() and str(m.get("id", "")) == _trace_id)
	if _core.trace and not _trace_id.is_empty():
		_trace_id = ""
	_matches_seen += 1
	_core.relic_ids = w.relics.duplicate()
	_core.run_modifiers = _session_of(w, 0).run_modifier_overrides()
	if not _core.run_modifiers.is_empty():
		out["mod_matches"] = float(out["mod_matches"]) + 1.0
	if _pieces_on:
		_core.piece_deck_state = w.piece_deck
	var r: Dictionary = _core.play_match(m, character, w.deck_entries(), w.hp, match_seed, bot_rng)
	_core.run_modifiers = {}
	out["matches"] = float(out["matches"]) + 1.0
	# Story 040: the v6 run time (a match's intro + end delay) and the per-match log of the REGION x FLOOR table.
	out["match_extra_sec"] = float(out["match_extra_sec"]) + run_config.intro_sec + run_config.end_delay_sec
	out["shits"] = float(out["shits"]) + float(r["shits"])
	out["bdmg"] = float(out["bdmg"]) + float(r["bdmg"])
	(out["mlog"] as Array).append([w.floor, w.region_id, bool(r["won"]), kind])
	for rid: Variant in (r["relic_trig"] as Dictionary).keys():
		out["relic_trig"][rid] = int((out["relic_trig"] as Dictionary).get(rid, 0)) + int(r["relic_trig"][rid])
	out["hits"] = float(out["hits"]) + float(r["bhits"])
	out["real_sec"] = float(out["real_sec"]) + float(r["real_sec"])
	out["sim_sec"] = float(out["sim_sec"]) + float(r["sec"])
	out["curse_draws"] = float(out["curse_draws"]) + float(r.get("curse_draws", 0))
	out["curse_dmg"] = float(out["curse_dmg"]) + float(r.get("curse_dmg", 0.0))
	if bool(r["timeout"]):
		out["timeouts"] = float(out["timeouts"]) + 1.0
	for pair: Array in [["p_casts", "casts"], ["p_cells", "cells"], ["p_res", "resolved"], ["p_hits", "hits"], ["p_joins", "joins"],
			["p_feat", "featured"], ["p_int", "interrupts"], ["p_intd", "interrupted"], ["p_fallback", "piece_fallback"]]:
		out[pair[0]] = float(out[pair[0]]) + float(r.get(pair[1], 0))
	for k: String in ["size_res", "size_hits"]:
		var into: Dictionary = out["p_" + k]
		for size: Variant in (r.get(k, {}) as Dictionary).keys():
			into[size] = int(into.get(size, 0)) + int(r[k][size])
	return r


# Story 037: the region pool without the locked regions (RunSession.roll_offer's rule: an all-locked pool keeps the full one).
func _open_region_ids() -> Array[String]:
	var ids: Array[String] = _chapters.region_ids()
	if _core.locked_ids("region").is_empty():
		return ids
	var open: Array[String] = []
	for id: String in ids:
		if not _core.is_locked("region", id):
			open.append(id)
	return open if not open.is_empty() else ids


# A RunSession carrying the WorldRun's state for ShopLogic / EventLogic (arrays are shared, scalars copied;
# [method _sync_back] copies everything back). [param node_index] = the node being visited.
func _session_of(w: WorldRun, node_index: int) -> RunSession:
	var rs := RunSession.new()
	rs.run_seed = w.run_seed
	rs.floor = w.floor
	rs.region_id = w.region_id
	rs.chapter_index = w.chapter_index
	rs.column = w.column
	rs.node_index = node_index
	rs.nodes_cleared = w.nodes_cleared
	rs.hp = w.hp
	rs.deck = w.deck
	rs.relics = w.relics
	rs.gold = w.gold
	rs.removal_tokens = w.removal_tokens
	rs.run_modifiers = w.run_modifiers
	rs.cards_config = _core.cards
	rs.locked = _core.locked.duplicate(true)
	rs.kiep_level = w.kiep_level
	if _pieces_on:
		rs.piece_deck = w.piece_deck.duplicate(true)
		rs.shape_removals = w.shape_removals
	return rs


func _sync_back(rs: RunSession, w: WorldRun) -> void:
	w.hp = rs.hp
	w.deck = rs.deck
	w.relics = rs.relics
	w.gold = rs.gold
	w.removal_tokens = rs.removal_tokens
	w.run_modifiers = rs.run_modifiers
	if _pieces_on:
		w.piece_deck = rs.piece_deck
		w.shape_removals = rs.shape_removals


# GameFlow._drop_gold: EconomyConfig.gold_for(kind, floor, hash([run_seed, floor, column, node_index, "gold"])).
func _drop_gold(w: WorldRun, kind: String, node_index: int, out: Dictionary) -> void:
	var g: int = _economy.gold_for(kind, w.floor, hash([w.run_seed, w.floor, w.column, node_index, GOLD_SEED_TAG]) & SEED_MASK)
	if w.kiep_level > 0:
		# Story 038 (Kiep 5): GameFlow's drop x economy_mult("gold"), rounded, at least 0.
		g = maxi(roundi(float(g) * KiepRules.shared().economy_mult("gold", w.kiep_level)), 0)
	w.gold += g
	out["gold_drop"] = float(out["gold_drop"]) + float(g)


# One match was played (GameFlow: RunSession.tick_run_modifiers).
func _tick_modifiers(w: WorldRun) -> void:
	var rs: RunSession = _session_of(w, 0)
	rs.tick_run_modifiers()
	w.run_modifiers = rs.run_modifiers


func _event_opts() -> Dictionary:
	return {"cards": _core.cards, "reward_config": _reward_config, "relic_config": _core.relic_config}


func _shop_state(w: WorldRun, node_index: int) -> Dictionary:
	return ShopLogic.build(w.run_seed, w.floor, w.column, node_index, w.luck(_reward_config), w.relics,
		_core.cards, _reward_config, _core.relic_config, _economy, _core.locked, w.kiep_level)


# The first column of the run that OFFERS a shop (entered or not): the gold in hand and whether it buys
# the cheapest card / relic of that shop's stock (the "can the average player afford 1 item" target).
func _note_first_shop(nodes: Array[Dictionary], w: WorldRun, out: Dictionary) -> void:
	if float(out["seen_shop_gold"]) >= 0.0:
		return
	for n: Dictionary in nodes:
		if str(n.get("kind", "")) != ChapterMapGen.KIND_SHOP:
			continue
		var state: Dictionary = _shop_state(w, int(n["node_index"]))
		var cheapest: int = 1 << 30
		for row: Dictionary in (state["cards"] as Array) + (state["relics"] as Array):
			cheapest = mini(cheapest, int(row["price"]))
		out["seen_shop_gold"] = float(w.gold)
		out["seen_shop_floor"] = float(w.floor)
		out["seen_shop_afford"] = 1.0 if w.gold >= cheapest else 0.0
		return


# SHOP node. greedy: heal service below SHOP_HEAL_BELOW, then the dearest affordable relic (repeat), then
# the cards the build policy's offer pickers want, while affordable. none: walks past.
func _visit_shop(w: WorldRun, node_index: int, policy: String, max_hp: float, out: Dictionary) -> void:
	var rs: RunSession = _session_of(w, node_index)
	var state: Dictionary = _shop_state(w, node_index)
	var gold_in: int = rs.gold
	var bought: int = 0
	var offered_ids: Array[String] = []
	var bought_ids: Array[String] = []
	for row: Dictionary in state["cards"] as Array:
		offered_ids.append("card:%s" % str(row["id"]))
	for row: Dictionary in state["relics"] as Array:
		offered_ids.append("relic:%s" % str(row["id"]))
	for service: String in ShopLogic.SERVICES:
		offered_ids.append("service:%s" % service)
	if _shop_policy != "none" and policy != "always_skip":
		if _hp_ratio(rs, max_hp) < SHOP_HEAL_BELOW:
			if bool(ShopLogic.use_service(state, rs, ShopLogic.SERVICE_HEAL, max_hp, _core.cards)["ok"]):
				bought += 1
				bought_ids.append("service:%s" % ShopLogic.SERVICE_HEAL)
				out["heals_bought"] = float(out["heals_bought"]) + 1.0
		while true:
			var best_id: String = ""
			var best_price: int = -1
			for row: Dictionary in state["relics"] as Array:
				if not bool(row["sold"]) and int(row["price"]) <= rs.gold and int(row["price"]) > best_price:
					best_price = int(row["price"])
					best_id = str(row["id"])
			if best_id.is_empty() or not bool(ShopLogic.buy(state, rs, ShopLogic.KIND_RELIC, best_id)["ok"]):
				break
			bought += 1
			bought_ids.append("relic:%s" % best_id)
			out["relics_bought"] = float(out["relics_bought"]) + 1.0
		while true:
			var offer: Array[String] = []
			for row: Dictionary in state["cards"] as Array:
				if not bool(row["sold"]) and int(row["price"]) <= rs.gold:
					offer.append(str(row["id"]))
			var pick: String = _offer_pick(offer, rs, false)
			if pick.is_empty() or not bool(ShopLogic.buy(state, rs, ShopLogic.KIND_CARD, pick)["ok"]):
				break
			bought += 1
			bought_ids.append("card:%s" % pick)
			out["cards_bought"] = float(out["cards_bought"]) + 1.0
		if _shop_extras:
			bought += _visit_shop_extras(rs, state, bought_ids)
	_sync_back(rs, w)
	(out["shop_log"] as Array).append({"offered": offered_ids, "bought": bought_ids})
	out["gold_spent"] = float(out["gold_spent"]) + float(gold_in - w.gold)
	out["shops"] = float(out["shops"]) + 1.0
	(out["shop_items"] as Array).append(bought)
	if float(out["first_shop_items"]) < 0.0:
		out["first_shop_items"] = float(bought)
		out["first_shop_gold"] = float(gold_in)


# The card the build policy takes from [param offer] (upgrade > zone > new damage > keyword); "" = none.
# [param must] = take the first card when no rule wants one (a paid-for event offer).
func _offer_pick(offer: Array[String], session, must: bool) -> String:
	if offer.is_empty():
		return ""
	var pick: String = _pick_upgrade(offer, session.deck_levels())
	if pick.is_empty():
		pick = _pick_zone(offer, session)
	if pick.is_empty():
		pick = _pick_new_damage(offer)
	if pick.is_empty():
		pick = _pick_keyword(offer, session)
	if pick.is_empty() and must:
		pick = offer[0]
	return pick


# EVENT node (GameFlow._open_event + event_choose + the extra fight + picks). False = died in the extra fight.
func _visit_event(w: WorldRun, node_index: int, col_tier: int, max_hp: float, character: Dictionary,
		bot_rng: RandomNumberGenerator, out: Dictionary) -> bool:
	var opts: Dictionary = _event_opts()
	var id: String = EventLogic.pick_event(w.run_seed, w.floor, w.column, node_index, w.event_used, opts)
	if id.is_empty():
		return true
	if not w.event_used.has(id):
		w.event_used.append(id)
	out["events"] = float(out["events"]) + 1.0
	var rs: RunSession = _session_of(w, node_index)
	var view: Dictionary = EventLogic.describe(id, rs, max_hp, opts)
	var choice: int = _event_choice(id, view, rs, max_hp, opts)
	var choices: Array = view.get("choices", [])
	var label: String = "%s/%s" % [id, str((choices[choice] as Dictionary).get("id", choice)) if choice >= 0 and choice < choices.size() else "?"]
	out["event_picks"][label] = int((out["event_picks"] as Dictionary).get(label, 0)) + 1
	if choice < choices.size() - 1:
		out["event_risky"] = float(out["event_risky"]) + 1.0
	var res: Dictionary = EventLogic.resolve(id, choice, rs, max_hp, opts)
	if not bool(res.get("ok", false)):
		_sync_back(rs, w)
		return true
	_event_effects(res, out)
	_event_picks(res, rs, opts)
	_sync_back(rs, w)
	var fight: Dictionary = res.get("pending_fight", {})
	if fight.is_empty():
		return true
	# GameFlow._start_event_fight: the fight's kind at the column tier + tier_add, drawn from the region pool.
	out["tt_fights"] = float(out["tt_fights"]) + 1.0
	var kind: String = str(fight.get("kind", ChapterMapGen.KIND_DANGER))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([w.run_seed, w.floor, w.column, node_index, EVENT_FIGHT_SEED_TAG]) & SEED_MASK
	var used: Array[String] = []
	var match_id: String = ChapterMapGen._draw_match(_chapters.region_spec(w.region_id, w.floor, w.kiep_level), kind,
		col_tier + int(fight.get("tier_add", 0)), used, rng)
	var match_seed: int = hash([w.run_seed, w.floor, w.region_id, w.column, node_index, EVENT_FIGHT_SEED_TAG]) & SEED_MASK
	var r: Dictionary = _world_match(w, kind, match_id, match_seed, character, bot_rng, out)
	if not bool(r["won"]):
		out["tt_deaths"] = float(out["tt_deaths"]) + 1.0
		return false
	# GameFlow._finish_event_fight: modifiers tick, HP carries (+ passive heal), the prize is applied.
	_tick_modifiers(w)
	w.hp = minf(float(r["hp_end"]) + maxf(float(r["passive_heal"]), 0.0), max_hp)
	rs = _session_of(w, node_index)
	var won: Dictionary = EventLogic.finish_fight(rs, fight, true, max_hp, opts)
	_event_effects(won, out)
	_event_picks(won, rs, opts)
	_sync_back(rs, w)
	return true


# --event-policy: leave = the last choice; risky = above EVENT_RISKY_ABOVE the first enabled choice that is
# not a pure heal, else the first enabled pure heal choice, else the last (Rời đi).
func _event_choice(id: String, view: Dictionary, rs: RunSession, max_hp: float, opts: Dictionary) -> int:
	var choices: Array = view.get("choices", [])
	var leave: int = choices.size() - 1
	if _event_policy != "risky" or leave <= 0:
		return leave
	var raw: Array = EventLogic.get_event(id, opts).get("choices", [])
	var high: bool = _hp_ratio(rs, max_hp) > EVENT_RISKY_ABOVE
	for i: int in leave:
		if not bool((choices[i] as Dictionary).get("enabled", false)) or i >= raw.size():
			continue
		if _is_pure_heal(raw[i] as Dictionary) != high:
			return i
	return leave


func _is_pure_heal(choice: Dictionary) -> bool:
	var any: bool = false
	for outcome: Dictionary in choice.get("outcomes", []):
		for effect: Dictionary in outcome.get("effects", []):
			if str(effect.get("type", "")) != "hp" or float(effect.get("ratio", 0.0)) <= 0.0:
				return false
			any = true
	return any


func _event_effects(res: Dictionary, out: Dictionary) -> void:
	for e: Dictionary in res.get("effects_applied", []):
		match str(e.get("type", "")):
			"gold":
				var amount: int = int(e.get("amount", 0))
				if amount >= 0:
					out["gold_event_in"] = float(out["gold_event_in"]) + float(amount)
				else:
					out["gold_event_out"] = float(out["gold_event_out"]) - float(amount)
			"curse":
				out["curses"] = float(out["curses"]) + 1.0


# Finishes the pending picks like a player of the build policy: card offer = the build pick (else the
# first card), upgrade = the Rèn target (else the first upgradable), remove = a curse, else the weakest.
func _event_picks(res: Dictionary, rs: RunSession, opts: Dictionary) -> void:
	for pick: Dictionary in res.get("pending_picks", []):
		match str(pick.get("type", "")):
			"card_offer":
				var ids: Array[String] = []
				ids.assign(pick.get("ids", []) as Array)
				EventLogic.complete_pick(rs, pick, _offer_pick(ids, rs, true), opts)
			"upgrade_card":
				var ok_idx: Array[int] = EventLogic.upgradable_indices(rs, opts)
				var idx: int = _forge_index(rs)
				if not ok_idx.has(idx):
					idx = ok_idx[0] if not ok_idx.is_empty() else -1
				if idx >= 0:
					EventLogic.complete_pick(rs, pick, idx, opts)
			"remove_card":
				var target: int = -1
				for i: int in rs.deck.size():
					if _core.cards.is_curse(str(rs.deck[i]["id"])):
						target = i
						break
				if target < 0:
					target = _lowest_value_index(rs)
				if target >= 0:
					EventLogic.complete_pick(rs, pick, target, opts)


# economy.json with --economy-set overrides, in memory. key = a dotted path (`gold_drops.battle`,
# `shop.relic_prices.common`, `gold_floor_mult`); the last part may be `*` (every key of that object).
# value = a number, `xF` (multiply the current number / every element of an array), or `a/b/c` (an array).
func _economy_with_overrides(items: Array[String]) -> EconomyConfig:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EconomyConfig.DEFAULT_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		print("--economy-set: economy.json did not parse, overrides ignored")
		return EconomyConfig.shared()
	var data: Dictionary = parsed as Dictionary
	for item: String in items:
		if not item.contains(":"):
			print("--economy-set: '%s' is not key:value, ignored" % item)
			continue
		var key: String = item.get_slice(":", 0).strip_edges()
		var text: String = item.get_slice(":", 1).strip_edges()
		var parts: PackedStringArray = key.split(".")
		var node: Variant = data
		for i: int in parts.size() - 1:
			node = (node as Dictionary).get(parts[i]) if typeof(node) == TYPE_DICTIONARY else null
		if typeof(node) != TYPE_DICTIONARY:
			print("--economy-set: unknown key '%s' ignored" % key)
			continue
		var last: String = parts[parts.size() - 1]
		var targets: Array = (node as Dictionary).keys() if last == "*" else [last]
		for k: Variant in targets:
			if not (node as Dictionary).has(k):
				print("--economy-set: unknown key '%s' ignored" % key)
				continue
			(node as Dictionary)[k] = _economy_value((node as Dictionary)[k], text)
	print("economy-set result: %s" % JSON.stringify(data))
	return EconomyConfig.from_dictionary(data)


static func _economy_value(old: Variant, text: String) -> Variant:
	var mul: bool = text.begins_with("x")
	var f: float = float(text.substr(1)) if mul else 0.0
	if typeof(old) == TYPE_ARRAY:
		var out: Array = []
		if mul:
			for v: Variant in old as Array:
				out.append(float(v) * f)
		else:
			for p: String in text.split("/"):
				out.append(float(p))
		return out
	var value: float = float(old) * f if mul else float(text)
	return roundi(value) if typeof(old) == TYPE_INT else value


static func _pct(values: Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var s: Array = values.duplicate()
	s.sort()
	var pos: float = p * float(s.size() - 1)
	var lo: int = floori(pos)
	var hi: int = mini(lo + 1, s.size() - 1)
	return lerpf(float(s[lo]), float(s[hi]), pos - float(lo))


func _dist(values: Array) -> String:
	if values.is_empty():
		return "-"
	return "%.0f (%.0f-%.0f)" % [_pct(values, 0.5), _pct(values, 0.1), _pct(values, 0.9)]


func _world_economy_report(char_id: String, policy: String, runs: Array[Dictionary]) -> void:
	var wins: Array[Dictionary] = []
	for r: Dictionary in runs:
		if bool(r["won"]):
			wins.append(r)
	var earned_all: Array = []
	var earned_won: Array = []
	var items_run: Array = []
	var per_shop: Array = []
	var first: Array = []
	var seen_gold: Array = []
	var afford: Array = []
	var picks: Dictionary = {}
	for r: Dictionary in runs:
		var e: float = float(r["gold_drop"]) + float(r["gold_event_in"])
		earned_all.append(e)
		if bool(r["won"]):
			earned_won.append(e)
		var n_items: float = 0.0
		for b: Variant in r["shop_items"] as Array:
			per_shop.append(float(b))
			n_items += float(b)
		items_run.append(n_items)
		if float(r["first_shop_items"]) >= 0.0:
			first.append(float(r["first_shop_items"]))
		if float(r["seen_shop_gold"]) >= 0.0:
			seen_gold.append(float(r["seen_shop_gold"]))
			afford.append(100.0 * float(r["seen_shop_afford"]))
		for k: Variant in (r["event_picks"] as Dictionary).keys():
			picks[k] = int(picks.get(k, 0)) + int(r["event_picks"][k])
	var tt_n: float = _sum(_field(runs, "tt_fights"))
	var tt_d: float = _sum(_field(runs, "tt_deaths"))
	var left_won: Array = _field(wins, "gold_left")
	print("")
	print("WORLD ECONOMY | character | policy | shop | event | run win % | gold earned / run all (median P10-P90) | mean | earned / WON run (median P10-P90) | drops / event gold in / event gold lost (mean) | spent at shop all (median P10-P90) | left all | left WON runs (n) | shops / run | items / shop (mean) | items / first shop (mean, n) | items / run (mean; WON) | relics / cards / heals bought per run | gold at first shop offered (median P10-P90, n) | affords 1 item there % |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	print("| %s | %s | %s | %s | %.1f | %s | %.0f | %s | %.0f / %.0f / %.0f | %s | %s | %s (%d) | %.2f | %.2f | %.2f (%d) | %.2f; %.2f | %.2f / %.2f / %.2f | %s (%d) | %.0f |" % [
		char_id, policy, _shop_policy, _event_policy, 100.0 * wins.size() / maxf(float(runs.size()), 1.0),
		_dist(earned_all), _mean(earned_all), _dist(earned_won),
		_mean(_field(runs, "gold_drop")), _mean(_field(runs, "gold_event_in")), _mean(_field(runs, "gold_event_out")),
		_dist(_field(runs, "gold_spent")), _dist(_field(runs, "gold_left")), _dist(left_won), left_won.size(),
		_mean(_field(runs, "shops")), _mean(per_shop), _mean(first), first.size(), _mean(items_run), _mean(_field_items(wins)),
		_mean(_field(runs, "relics_bought")), _mean(_field(runs, "cards_bought")), _mean(_field(runs, "heals_bought")),
		_dist(seen_gold), seen_gold.size(), _mean(afford)])
	var pick_cells: Array[String] = []
	var keys: Array = picks.keys()
	keys.sort()
	for k: Variant in keys:
		pick_cells.append("%s=%d" % [str(k), int(picks[k])])
	print("WORLD EVENTS | %s | %s | events / run %.2f | non-leave choices / run %.2f | tran_thach extra fights %d, deaths %d (%.1f%%) | curses picked up / run %.2f | curse draws / run %.2f | curse dmg / run %.1f | matches slowed by loi_the / run %.2f | picks: %s" % [
		char_id, policy, _mean(_field(runs, "events")), _mean(_field(runs, "event_risky")), int(tt_n), int(tt_d),
		100.0 * tt_d / maxf(tt_n, 1.0), _mean(_field(runs, "curses")), _mean(_field(runs, "curse_draws")), _mean(_field(runs, "curse_dmg")),
		_mean(_field(runs, "mod_matches")), ", ".join(PackedStringArray(pick_cells)) if not pick_cells.is_empty() else "none"])
	print("ECONOMY RAW %s/%s: per run earned|spent|left|won|items|first_shop_items|seen_shop_gold = %s" % [char_id, policy,
		" ".join(PackedStringArray(_raw_cells(runs)))])
	print("ECONOMY TARGETS %s/%s (shop=%s event=%s): earned/run %.0f in %.0f-%.0f: %s | items/run %.2f in %.0f-%.0f: %s | median left WON < %.0f: %s | affords 1 item at first shop (median gold >= cheapest) %.0f%%: %s" % [
		char_id, policy, _shop_policy, _event_policy, _mean(earned_all), ECON_EARNED_TARGET[0], ECON_EARNED_TARGET[1],
		"PASS" if _mean(earned_all) >= ECON_EARNED_TARGET[0] and _mean(earned_all) <= ECON_EARNED_TARGET[1] else "MISS",
		_mean(items_run), ECON_ITEMS_TARGET[0], ECON_ITEMS_TARGET[1],
		"PASS" if _mean(items_run) >= ECON_ITEMS_TARGET[0] and _mean(items_run) <= ECON_ITEMS_TARGET[1] else "MISS",
		ECON_LEFT_WON_MAX, ("PASS" if _pct(left_won, 0.5) < ECON_LEFT_WON_MAX else "MISS") if not left_won.is_empty() else "n/a (no wins)",
		_mean(afford), "PASS" if _mean(afford) >= 50.0 else "MISS"])


func _field_items(runs: Array) -> Array:
	var out: Array = []
	for r: Variant in runs:
		var n: float = 0.0
		for b: Variant in (r as Dictionary)["shop_items"] as Array:
			n += float(b)
		out.append(n)
	return out


func _raw_cells(runs: Array[Dictionary]) -> Array[String]:
	var cells: Array[String] = []
	var items: Array = _field_items(runs)
	for i: int in runs.size():
		var r: Dictionary = runs[i]
		cells.append("%d|%d|%d|%d|%d|%d|%d" % [int(float(r["gold_drop"]) + float(r["gold_event_in"])), int(r["gold_spent"]),
			int(r["gold_left"]), 1 if bool(r["won"]) else 0, int(items[i]), int(r["first_shop_items"]), int(r["seen_shop_gold"])])
	return cells


# --- Story 036: --region / --floor mode --------------------------------------------------------------

# Chapter index of region / chapter id [param id] (any chapters.json entry, ch1..ch3 included); -1 unknown.
func _region_ci(id: String) -> int:
	return _chapters.region_index(id)


# Pool kind of every match of chapter [param ci] (pools.<kind>.<tier>; the first kind wins; "battle" default).
func _region_match_kinds(ci: int) -> Dictionary:
	var kinds: Dictionary = {}
	var pools: Variant = _chapters.get_map_spec(ci).get("pools", {})
	if typeof(pools) != TYPE_DICTIONARY:
		return kinds
	for kind: Variant in (pools as Dictionary).keys():
		var tiers: Variant = (pools as Dictionary)[kind]
		if typeof(tiers) != TYPE_DICTIONARY:
			continue
		for tier: Variant in (tiers as Dictionary).keys():
			for id: Variant in (tiers as Dictionary)[tier] as Array:
				if not kinds.has(str(id)):
					kinds[str(id)] = str(kind)
	return kinds


# Story 036 Part E: every match of each --region played on its own at each --floor (Story 031 scaling through
# RunConfig.from_node: region_normalize then floor_scaling row N), N seeds per match, full HP, the character's
# starter deck, --relics if given. One REGION row per match and floor, one REGION MEAN row per region and floor
# (unweighted mean over the matches), then a REGION CHECK line against the story targets. Nothing else runs.
func _run_region_mode(seeds: int) -> void:
	var floors: Array[int] = _region_floors.duplicate()
	if floors.is_empty():
		floors = [1]
	var relics: Array[String] = []
	relics.assign(_core.ov["relics"] as Array)
	print("deck_sim --region (Story 036): regions=%s floors=%s seeds=%d characters=%s timeout=%.0fs; each match alone, full HP, starter deck, floor N = floor_scaling row N after region_normalize" % [
		str(_regions), str(floors), seeds, str(_characters_run), SimCore.MATCH_TIMEOUT_SEC])
	print(_core.describe())
	if not _core.describe_progress().is_empty():
		print(_core.describe_progress())
	print("columns: match | kind | n | win % | timeout % | hits landed/match | boss hits/match | HP taken/match | mire entries/match | mire HP/match | mire share of HP taken % | pieces buried/match | pieces drifted/match | boss mire entries/match | sand cells/match | arena hazards")
	for char_id: String in _characters_run:
		var character: Dictionary = _core.prepare_character(_core.characters.get_character(char_id))
		var deck_entries: Array = []
		for id: Variant in character.get("starter_deck", []) as Array:
			deck_entries.append({"id": str(id), "level": 1})
		for region: String in _regions:
			var ci: int = _region_ci(region)
			if ci < 0:
				print("--region: '%s' is not a chapters.json id, skipped" % region)
				continue
			var kinds: Dictionary = _region_match_kinds(ci)
			for f: int in floors:
				var rows: Array[Dictionary] = []
				for id: String in _chapters.match_ids(ci):
					var kind: String = str(kinds.get(id, "battle"))
					var a: Dictionary = {"n": 0.0, "won": 0.0, "timeout": 0.0, "hits": 0.0, "bhits": 0.0, "taken": 0.0, "mire_in": 0.0,
						"mire_dmg": 0.0, "buried": 0.0, "drifted": 0.0, "bmire_in": 0.0, "sand_cells": 0.0,
						"resolved": 0.0, "vent_hp": 0.0, "fall_hp": 0.0, "pushed": 0.0, "vent_erupts": 0.0, "cell_falls": 0.0, "boss_heal": 0.0, "rebirth": 0.0}
					var haz: String = ""
					var trait_ids: Array[String] = []
					var h039: bool = false
					for s: int in seeds:
						var run_config: RunConfig = RunConfig.from_node(_chapters, ci, id, kind, s, f - 1)
						var m: Dictionary = _core.prepare_match(run_config.matches[0])
						m["chapter_id"] = region
						_core.invulnerable = false
						_core.time_limit_sec = SimCore.MATCH_TIMEOUT_SEC
						_core.relic_ids = relics.duplicate()
						var bot_rng := RandomNumberGenerator.new()
						bot_rng.seed = hash([s, char_id, region, id, f]) & SEED_MASK
						var r: Dictionary = _core.play_match(m, character, deck_entries, -1.0, hash([s, region, id, f, "m"]) & SEED_MASK, bot_rng)
						haz = "mire %d cells%s%s" % [_core._haz_mire, ", sand" if _core._haz_sand else "", ", wind" if _core._haz_wind else ""]
						h039 = _core._haz_vents > 0 or _core._haz_crumble
						if h039:
							haz += " | vents %d%s" % [_core._haz_vents, ", crumble" if _core._haz_crumble else ""]
						if trait_ids.is_empty():
							for te: Variant in m.get("traits", []) as Array:
								if typeof(te) == TYPE_DICTIONARY:
									trait_ids.append(str((te as Dictionary).get("id", "")))
						a["n"] = float(a["n"]) + 1.0
						a["won"] = float(a["won"]) + (1.0 if bool(r["won"]) else 0.0)
						a["timeout"] = float(a["timeout"]) + (1.0 if bool(r["timeout"]) else 0.0)
						for k: String in ["hits", "bhits", "taken", "mire_in", "mire_dmg", "buried", "drifted", "bmire_in", "sand_cells", "resolved", "vent_hp", "fall_hp", "pushed", "vent_erupts", "cell_falls", "boss_heal"]:
							a[k] = float(a[k]) + float(r.get(k, 0))
						a["rebirth"] = float(a["rebirth"]) + float(r.get("rebirth_used", 0))
					var n: float = maxf(float(a["n"]), 1.0)
					var row: Dictionary = {"id": id, "kind": kind, "win": 100.0 * float(a["won"]) / n, "hits": float(a["hits"]) / n,
						"mire_in": float(a["mire_in"]) / n, "mire_dmg": float(a["mire_dmg"]) / n, "taken": float(a["taken"]) / n,
						"buried": float(a["buried"]) / n, "drifted": float(a["drifted"]) / n,
						# Story 039 fields (not printed by the Story 036 lines).
						"hit_rate": 100.0 * float(a["hits"]) / maxf(float(a["resolved"]), 1.0), "vent_hp": float(a["vent_hp"]) / n,
						"fall_hp": float(a["fall_hp"]) / n, "pushed": float(a["pushed"]) / n, "traits": trait_ids, "h039": h039}
					rows.append(row)
					print("REGION %s | %s | floor %d | %s | %s | %d | %.0f | %.0f | %.1f | %.1f | %.1f | %.2f | %.1f | %.1f | %.2f | %.2f | %.2f | %.2f | %s" % [
						char_id, region, f, id, kind, int(a["n"]), row["win"], 100.0 * float(a["timeout"]) / n, row["hits"],
						float(a["bhits"]) / n, row["taken"], row["mire_in"], row["mire_dmg"],
						100.0 * float(a["mire_dmg"]) / maxf(float(a["taken"]), 0.001), row["buried"], row["drifted"],
						float(a["bmire_in"]) / n, float(a["sand_cells"]) / n, haz])
					if float(a["vent_erupts"]) + float(a["cell_falls"]) + float(a["boss_heal"]) + float(a["rebirth"]) > 0.0:
						print("REGION 039 | %s | %s | floor %d | %s | vent HP/match %.1f | fall HP/match %.1f | times pushed/match %.2f | vents erupted/match %.2f | cells fallen/match %.2f | boss HP healed by burn/match %.1f | rebirth used %.0f %% | player hit %% %.1f" % [
							char_id, region, f, id, row["vent_hp"], row["fall_hp"], row["pushed"], float(a["vent_erupts"]) / n,
							float(a["cell_falls"]) / n, float(a["boss_heal"]) / n, 100.0 * float(a["rebirth"]) / n, row["hit_rate"]])
				_region_mean(char_id, region, f, rows)
				_region_039_lines(char_id, region, f, rows)


# REGION MEAN (unweighted over the matches) + REGION CHECK (story 036 E3 targets that one region run can show:
# floor-1 match win in 15-95 %, mire HP <= 15 % of HP taken; the +-10 points vs ch1-ch3 needs those runs too).
func _region_mean(char_id: String, region: String, f: int, rows: Array[Dictionary]) -> void:
	if rows.is_empty():
		return
	var sums: Dictionary = {"win": 0.0, "hits": 0.0, "mire_in": 0.0, "mire_dmg": 0.0, "taken": 0.0, "buried": 0.0, "drifted": 0.0}
	var outside: Array[String] = []
	for row: Dictionary in rows:
		for k: String in sums.keys():
			sums[k] = float(sums[k]) + float(row[k])
		if float(row["win"]) > 95.0 or float(row["win"]) < 15.0:
			outside.append("%s %.0f%%" % [row["id"], row["win"]])
	var n: float = float(rows.size())
	var share: float = 100.0 * float(sums["mire_dmg"]) / maxf(float(sums["taken"]), 0.001)
	print("REGION MEAN %s | %s | floor %d | matches %d | win %% %.1f | hits landed/match %.1f | HP taken/match %.1f | mire entries/match %.2f | mire HP/match %.1f | mire share %.1f %% | buried/match %.2f | drifted/match %.2f" % [
		char_id, region, f, rows.size(), float(sums["win"]) / n, float(sums["hits"]) / n, float(sums["taken"]) / n,
		float(sums["mire_in"]) / n, float(sums["mire_dmg"]) / n, share, float(sums["buried"]) / n, float(sums["drifted"]) / n])
	var win_note: String = "n/a (floor %d)" % f
	if f == 1:
		win_note = ("none" if outside.is_empty() else ", ".join(outside))
	print("REGION CHECK %s | %s | floor %d | matches outside 15-95 %% win at floor 1: %s | mire share %.1f %% (target <= 15): %s | compare win %% %.1f with the ch1-ch3 REGION MEAN at this floor (target +-10 pts)" % [
		char_id, region, f, win_note, share, "PASS" if share <= 15.0 else "MISS", float(sums["win"]) / n])


# Story 039: the extra REGION lines of a (region, floor): REGION MEAN 039 (vent / fall HP and pushes per match, mean
# over the matches, only when some match of the region has vents or a crumbling arena), REGION 039 SHROUD (the
# hit rate of the match with the `shroud` trait vs the region's other matches: the hit forecast is hidden there,
# the bot never uses the forecast, so a gap is only the cloud match's own difficulty) and REGION 039 FIRE EATER
# (the Phap su starter deck's win % in the `burn_eater` match at floor 1, story target >= 25 %). Nothing is
# printed for a region without those, so the Story 036 output is unchanged.
func _region_039_lines(char_id: String, region: String, f: int, rows: Array[Dictionary]) -> void:
	if rows.is_empty():
		return
	var has_hazard: bool = false
	var sums: Dictionary = {"vent_hp": 0.0, "fall_hp": 0.0, "pushed": 0.0, "hit_rate": 0.0}
	for row: Dictionary in rows:
		has_hazard = has_hazard or bool(row.get("h039", false))
		for k: String in sums.keys():
			sums[k] = float(sums[k]) + float(row[k])
	var n: float = float(rows.size())
	if has_hazard:
		print("REGION MEAN 039 %s | %s | floor %d | matches %d | vent HP/match %.2f | fall HP/match %.2f | HP lost to vents + falls/match %.2f | times pushed/match %.2f | player hit %% (mean of matches) %.1f" % [
			char_id, region, f, rows.size(), float(sums["vent_hp"]) / n, float(sums["fall_hp"]) / n,
			(float(sums["vent_hp"]) + float(sums["fall_hp"])) / n, float(sums["pushed"]) / n, float(sums["hit_rate"]) / n])
	for row: Dictionary in rows:
		var ids: Array = row.get("traits", []) as Array
		if ids.has("shroud"):
			var others: float = 0.0
			var cnt: int = 0
			for o: Dictionary in rows:
				if o != row:
					others += float(o["hit_rate"])
					cnt += 1
			var other_mean: float = others / float(maxi(cnt, 1))
			print("REGION 039 SHROUD %s | %s | floor %d | match %s | player hit %% %.1f | the region's other matches %.1f | all matches %.1f | delta vs others %+.1f pts" % [
				char_id, region, f, row["id"], row["hit_rate"], other_mean, float(sums["hit_rate"]) / n, float(row["hit_rate"]) - other_mean])
		if ids.has("burn_eater") and f == 1:
			var win: float = float(row["win"])
			var verdict: String = "PASS" if win >= 25.0 else "MISS"
			if char_id != "phap_su":
				verdict = "INFO (the story target is for phap_su)"
			print("REGION 039 FIRE EATER %s | %s | floor %d | match %s | win %% %.1f (story target >= 25 for phap_su): %s" % [
				char_id, region, f, row["id"], win, verdict])


# Story 039 `--region-freq=N`: N seeded runs of the world map generator the way the game does it (RunSession.begin_world,
# then roll_offer every floor, the pool of `world.region_pool` minus the locked regions). The bot picks at random between
# the offered regions (seeded); a run walks the floors 0..world.floors-1 (no match is played). Prints the share of
# choice events each region was OFFERED in (story target 20-40 %: with 2 offers out of 7 regions the mean is 28.6 %) and
# CHOSEN in, the offers by floor, and the number of runs that repeat a region.
func _run_region_freq(runs: int) -> void:
	var character: Dictionary = _core.characters.get_character(_characters_run[0] if not _characters_run.is_empty() else "kiem_si")
	var locked: Dictionary = {"region": _core.locked_ids("region")}
	var pool: Array[String] = _open_region_ids()
	var floors: int = _chapters.world_floors()
	var choices: int = int(_chapters.world_spec().get("choices_per_floor", ChaptersConfig.DEFAULT_CHOICES_PER_FLOOR))
	print("deck_sim --region-freq (Story 039): runs=%d floors=%d choices_per_floor=%d pool=%s locked=%s; no match is played, the bot picks at random between the offers" % [
		runs, floors, choices, str(pool), str(locked["region"])])
	var offered: Dictionary = {}
	var chosen: Dictionary = {}
	var offered_at: Dictionary = {}
	for id: String in pool:
		offered[id] = 0
		chosen[id] = 0
		offered_at[id] = []
		for f: int in floors:
			(offered_at[id] as Array).append(0)
	var events: int = 0
	var repeat_runs: int = 0
	var short_runs: int = 0
	for s: int in runs:
		var run_seed: int = hash([s, "region_freq"]) & SEED_MASK
		var pick_rng := RandomNumberGenerator.new()
		pick_rng.seed = hash([run_seed, "region_pick"]) & SEED_MASK
		var session: RunSession = RunSession.begin_world(_chapters, character, run_seed, 0, locked)
		var seen: Dictionary = {}
		var repeated: bool = false
		var f: int = 0
		while f < floors:
			var offer: Array[String] = session.region_offer
			if offer.is_empty():
				short_runs += 1
				break
			events += 1
			for id: String in offer:
				offered[id] = int(offered.get(id, 0)) + 1
				if offered_at.has(id):
					(offered_at[id] as Array)[f] = int((offered_at[id] as Array)[f]) + 1
			var pick: String = offer[pick_rng.randi_range(0, offer.size() - 1)]
			chosen[pick] = int(chosen.get(pick, 0)) + 1
			if seen.has(pick):
				repeated = true
			seen[pick] = true
			if not session.choose_region(pick, CLEARED_BOSSES_MAIN):
				short_runs += 1
				break
			# GameFlow / RunSession._clear_floor: the region boss fell, next floor, next offer.
			session.floor += 1
			session.region_offer = session.roll_offer()
			f += 1
		if repeated:
			repeat_runs += 1
	var ev: float = float(maxi(events, 1))
	print("REGION FREQ | region | offered in N choice events | offered %% of choice events | chosen | chosen %% of choice events | offered per floor (f1..f%d) |" % floors)
	var worst_lo: float = 100.0
	var worst_hi: float = 0.0
	var out_of_band: Array[String] = []
	for id: String in pool:
		var share: float = 100.0 * float(int(offered[id])) / ev
		worst_lo = minf(worst_lo, share)
		worst_hi = maxf(worst_hi, share)
		if share < 20.0 or share > 40.0:
			out_of_band.append("%s %.1f%%" % [id, share])
		var per_floor: Array[String] = []
		for c: Variant in offered_at[id] as Array:
			per_floor.append(str(int(c)))
		print("REGION FREQ | %s | %d of %d | %.1f | %d | %.1f | %s |" % [id, int(offered[id]), events, share, int(chosen[id]),
			100.0 * float(int(chosen[id])) / ev, " ".join(per_floor)])
	print("REGION FREQ CHECK offered share 20-40 %% of choice events per region: %s (min %.1f %%, max %.1f %%%s)" % [
		"PASS" if out_of_band.is_empty() else "MISS", worst_lo, worst_hi, "" if out_of_band.is_empty() else "; outside: " + ", ".join(out_of_band)])
	print("REGION FREQ CHECK runs that repeat a region: %d of %d (%.1f %%), runs cut short (no offer): %d" % [
		repeat_runs, runs, 100.0 * float(repeat_runs) / float(maxi(runs, 1)), short_runs])


# ---------------------------------------------------------------- Story 037: unlocks, characters, unlock-runs


# Story 037: one match node of a world run as the unlock replay needs it: {won, kind, region, match_id, final,
# boss (a REGION boss: FateLogic.is_boss_fate_node), fate (set by the caller after a region boss), deck_ids, stats}.
# `stats` has the keys of CombatView.get_match_stats() that the achievements read.
func _match_record(r: Dictionary, w: WorldRun, kind: String, match_id: String, is_final: bool) -> Dictionary:
	return {
		"won": bool(r["won"]), "kind": kind, "region": w.region_id, "match_id": match_id, "final": is_final,
		"boss": FateLogic.is_boss_fate_node(kind, is_final), "fate": "", "deck_ids": _deck_ids(w),
		"stats": {
			"hits_taken": int(r["bhits"]), "casts": int(r["casts"]), "joins": int(r["joins"]),
			"featured_casts": int(r["featured"]), "signatures_used": int(r["sig_acts"]),
			"frost_bursts": int(r.get("frost_bursts", 0)), "boss_thorn_steps": int(r["bthorn"]),
			"damage_dealt": float(r["dealt"]), "damage_taken": float(r["taken"]),
		},
	}


# The card ids of the world run's deck (RunSession.deck_ids form), in deck order.
func _deck_ids(w: WorldRun) -> Array[String]:
	var ids: Array[String] = []
	for e: Dictionary in w.deck:
		ids.append(str(e["id"]))
	return ids


# Story 037 Part F: the run win % of every new character against the mean of the open ones, same policy and
# progress mode, only when a new character was played in this invocation.
func _world_characters_report(pols: Array[String]) -> void:
	for p: String in pols:
		for cid: String in NEW_CHARACTERS:
			var key: String = "%s|%s" % [cid, p]
			if not _world_wins.has(key):
				continue
			var base: Array[float] = []
			for open_id: String in CHARACTERS:
				var ok: String = "%s|%s" % [open_id, p]
				if _world_wins.has(ok):
					base.append(float((_world_wins[ok] as Dictionary)["win"]))
			var mine: Dictionary = _world_wins[key]
			if base.is_empty():
				print("WORLD CHARACTERS | progress=%s | %s | %s | run win %.1f%% (%d/%d) | no open character in this run to compare (add --characters=kiem_si,phap_su,sat_thu,%s)" % [
					_core.progress_mode, p, cid, float(mine["win"]), int(mine["wins"]), int(mine["n"]), cid])
				continue
			var mean_open: float = _mean(base)
			var delta: float = float(mine["win"]) - mean_open
			print("WORLD CHARACTERS | progress=%s | %s | %s | run win %.1f%% (%d/%d) | mean of %d open characters %.1f%% | delta %+.1f pts (band +-%.0f): %s" % [
				_core.progress_mode, p, cid, float(mine["win"]), int(mine["wins"]), int(mine["n"]), base.size(), mean_open, delta,
				NEW_CHARACTER_WIN_BAND, "PASS" if absf(delta) <= NEW_CHARACTER_WIN_BAND else "FAIL"])


# Story 037 `--unlock-runs=N [--unlock-reps=R]`: for each open character, R repetitions of up to N consecutive world runs
# on ONE ProgressState (empty at the start), the `build` policy and an alternating Spare / Execute fate (execute, spare,
# execute, ... per run, as `--fate=alternate`; `--fate=execute|spare` is honoured). Before each run the locked content is
# the ledger's (AchievementsConfig.locked_content of the progress), as in the game. After each run the ledger gets the writes
# GameFlow makes and UnlockRules.process the events (see _unlock_apply_run). A repetition stops once both new characters
# are open unless --unlock-full. Output lines start with `UNLOCK RUNS`.
func _run_unlock_mode() -> void:
	var cfg: AchievementsConfig = AchievementsConfig.shared()
	var floors: int = _chapters.world_floors()
	if _fate_policy.is_empty():
		_fate_policy = "alternate"
	var players: Array[String] = []
	for c: String in _characters_run:
		if CHARACTERS.has(c):
			players.append(c)
	if players.is_empty():
		players = CHARACTERS.duplicate()
	var targets: Array[Dictionary] = []
	for cid: String in NEW_CHARACTERS:
		targets.append({"character": cid, "achievement": cfg.reward_owner("character", cid)})
	var target_names: Array[String] = []
	for t0: Dictionary in targets:
		target_names.append("%s via %s" % [t0["character"], t0["achievement"]])
	print("deck_sim --unlock-runs (Story 037): runs<=%d reps=%d players=%s fate=%s policy=%s stop-when-both-open=%s seeds=rep*1000+run | new characters: %s" % [
		_unlock_runs, _unlock_reps, str(players), _fate_policy, VERDICT_POLICY, str(not _unlock_full), ", ".join(PackedStringArray(target_names))])
	print(_core.describe())
	for char_id: String in players:
		var t_c: int = Time.get_ticks_msec()
		var opened_at: Dictionary = {}
		for t1: Dictionary in targets:
			opened_at[str(t1["character"])] = []
		var new_by_run: Array = []
		var earned_in: Dictionary = {}
		var runs_played: int = 0
		var runs_won: int = 0
		var totals: Array[float] = []
		for rep: int in _unlock_reps:
			var progress := ProgressState.new()
			var opened: Dictionary = {}
			var per_run: Array[int] = []
			var wins_row: String = ""
			for run_idx: int in range(1, _unlock_runs + 1):
				_core.set_locked_from_progress(progress)
				_fate_offset = progress.get_spare_total() + progress.get_execute_total()
				var out: Dictionary = _run_world(rep * 1000 + run_idx, char_id, VERDICT_POLICY, floors)
				var new_ids: Array[String] = _unlock_apply_run(cfg, progress, char_id, out)
				runs_played += 1
				if bool(out["won"]):
					runs_won += 1
				wins_row += "W" if bool(out["won"]) else "L"
				per_run.append(new_ids.size())
				while new_by_run.size() < run_idx:
					new_by_run.append([])
				(new_by_run[run_idx - 1] as Array).append(float(new_ids.size()))
				for t2: Dictionary in targets:
					var cid2: String = str(t2["character"])
					if not opened.has(cid2) and cfg.is_unlocked("character", cid2, progress):
						opened[cid2] = run_idx
				if not _unlock_full and opened.size() == targets.size():
					break
			var opened_cells: Array[String] = []
			for t3: Dictionary in targets:
				var cid3: String = str(t3["character"])
				(opened_at[cid3] as Array).append(int(opened.get(cid3, -1)))
				opened_cells.append("%s@%s" % [cid3, str(opened.get(cid3, "-"))])
			for aid: String in progress.get_achievements():
				earned_in[aid] = int(earned_in.get(aid, 0)) + 1
			totals.append(float(progress.get_achievements().size()))
			print("UNLOCK RUNS RAW %s rep %d: runs %s | opened %s | new achievements per run %s | total %d" % [
				char_id, rep + 1, wins_row, ", ".join(PackedStringArray(opened_cells)), str(per_run), progress.get_achievements().size()])
		_unlock_report(char_id, targets, opened_at, new_by_run, earned_in, runs_played, runs_won, totals, cfg)
		print("  ... %s unlock-runs done in %.1f s" % [char_id, (Time.get_ticks_msec() - t_c) / 1000.0])
	_core.set_locked_from_progress(null)


# The `UNLOCK RUNS` summary of one player character: mean run index at which each new character opened (over the
# repetitions that opened it, and with a never-opened repetition counted as N+1), the story target 1-3, the
# achievements earned per run index and how many repetitions earned each achievement.
func _unlock_report(char_id: String, targets: Array[Dictionary], opened_at: Dictionary, new_by_run: Array,
		earned_in: Dictionary, runs_played: int, runs_won: int, totals: Array[float], cfg: AchievementsConfig) -> void:
	print("")
	for t: Dictionary in targets:
		var cid: String = str(t["character"])
		var idx: Array = opened_at[cid]
		var got: Array = []
		var capped: Array = []
		for v: Variant in idx:
			if int(v) > 0:
				got.append(float(int(v)))
				capped.append(float(int(v)))
			else:
				capped.append(float(_unlock_runs + 1))
		var sorted_got: Array = got.duplicate()
		sorted_got.sort()
		var median: String = "-" if sorted_got.is_empty() else ("%.1f" % float(sorted_got[sorted_got.size() / 2]))
		var max_idx: String = "-" if sorted_got.is_empty() else ("%d" % int(sorted_got.back()))
		var mean_capped: float = _mean(capped)
		var ok: bool = mean_capped >= UNLOCK_TARGET_RUNS[0] and mean_capped <= UNLOCK_TARGET_RUNS[1]
		print("UNLOCK RUNS SUMMARY %s | %s (via %s) | opened in %d of %d reps | mean run index %s (median %s, max %s) | mean with never-opened = %d: %.2f | target %.0f-%.0f runs: %s" % [
			char_id, cid, str(t["achievement"]), got.size(), idx.size(), ("%.2f" % _mean(got)) if not got.is_empty() else "-",
			median, max_idx, _unlock_runs + 1, mean_capped, UNLOCK_TARGET_RUNS[0], UNLOCK_TARGET_RUNS[1], "PASS" if ok else "FAIL"])
	var per_cells: Array[String] = []
	for i: int in new_by_run.size():
		per_cells.append("run%d=%.2f (n=%d)" % [i + 1, _mean(new_by_run[i]), (new_by_run[i] as Array).size()])
	print("UNLOCK RUNS ACHIEVEMENTS %s | new achievements per run index (mean over the reps that played it): %s | mean held at the end of a rep %.2f of %d | run win %% over all runs %.1f (%d/%d)" % [
		char_id, ", ".join(PackedStringArray(per_cells)), _mean(totals), cfg.ids().size(),
		100.0 * float(runs_won) / maxf(float(runs_played), 1.0), runs_won, runs_played])
	var earn_cells: Array[String] = []
	for aid: String in cfg.ids():
		earn_cells.append("%s=%d" % [aid, int(earned_in.get(aid, 0))])
	print("UNLOCK RUNS EARNED %s | reps that held each achievement at the end of the rep: %s" % [char_id, ", ".join(PackedStringArray(earn_cells))])


# Story 037: the milestone writes GameFlow makes for one finished world run, then UnlockRules.process on the events
# in the order the flow raises them. Per match (in order): a won REGION boss = record_boss_clear, add_region_boss_beaten,
# record_fate (the fate the bot took), then a `match_won` event for EVERY won match (frost_burst_5 reads every match);
# `final_reached` just before the first final-floor match; at the end of the run record_run_won + record_ending on a
# win, and the `run_ended` event (won or lost). A lost match adds its stats to the run totals (GameFlow does on a
# defeat). tran_thach extra fights are not events (their stats are not in the log). Returns every achievement id
# earned by this run, in order.
func _unlock_apply_run(cfg: AchievementsConfig, progress: ProgressState, char_id: String, out: Dictionary) -> Array[String]:
	var earned: Array[String] = []
	var run_stats: Dictionary = {}
	var fates: Array = []
	var final_noted: bool = false
	for rec: Dictionary in out["match_log"] as Array:
		var stats: Dictionary = rec["stats"]
		for k: Variant in stats.keys():
			run_stats[k] = run_stats.get(k, 0) + stats[k]
		if bool(rec["final"]) and not final_noted:
			final_noted = true
			progress.record_final_reached()
			earned.append_array(UnlockRules.process(cfg, progress, {"type": "final_reached"}))
		if not bool(rec["won"]):
			continue
		var is_region_boss: bool = bool(rec["boss"])
		if is_region_boss:
			progress.record_boss_clear()
			progress.add_region_boss_beaten(str(rec["region"]))
			var fate: String = str(rec["fate"])
			if not fate.is_empty():
				progress.record_fate(str(rec["match_id"]), fate)
				fates.append({"fate": fate, "match_id": str(rec["match_id"])})
		earned.append_array(UnlockRules.process(cfg, progress, {
			"type": "match_won", "character_id": char_id, "region_id": str(rec["region"]), "is_region_boss": is_region_boss,
			"is_final": bool(rec["final"]), "match_stats": stats.duplicate(), "run_stats": run_stats.duplicate(),
			"deck_ids": (rec["deck_ids"] as Array).duplicate()}))
	var won: bool = bool(out["won"])
	var ending_id: String = ""
	if won:
		ending_id = FateLogic.ending_for(fates, _chapters.endings_config())
		progress.record_run_won(char_id)
		progress.record_ending(ending_id)
	earned.append_array(UnlockRules.process(cfg, progress, {
		"type": "run_ended", "won": won, "ending_id": ending_id, "character_id": char_id,
		"run_stats": run_stats.duplicate(), "deck_ids": (out["deck_ids"] as Array).duplicate()}))
	return earned


# ================================================================ Story 040: run v6 aliases, bot policies and tables
# README "Story 040". Everything below is reached only through the new flags, so a run without them is the old output.


# The Story 040 alias flags. True when [param arg] is one of them (handled here, [param v] = the text after "=").
# Every alias also turns on world mode and the v6 tables (`--tables=none` turns the tables off again).
func _parse_v6_flag(arg: String, v: String) -> bool:
	var val: String = v.strip_edges()
	if arg.begins_with("--run="):
		if val != "v6":
			print("--run: '%s' unknown (only v6), ignored" % val)
	elif arg.begins_with("--floors="):
		var lo: int = 1
		var hi: int = 5
		if val.contains(".."):
			lo = int(val.get_slice("..", 0).strip_edges())
			hi = int(val.get_slice("..", 1).strip_edges())
		elif val.is_valid_int():
			lo = int(val)
			hi = lo
		if lo < 1 or hi < lo:
			print("--floors: '%s' is not a or a..b with 1 <= a <= b, using 1..5" % val)
			lo = 1
			hi = 5
		_f_from = lo - 1
		_floors_b = hi
	elif arg.begins_with("--final="):
		if val == "on" or val == "off":
			_final_on = val == "on"
		else:
			print("--final: '%s' unknown (on|off), keeping %s" % [val, "on" if _final_on else "off"])
	elif arg.begins_with("--mercy="):
		var list: Array[String] = []
		for item: String in val.split(","):
			if MERCY_ALIASES.has(item.strip_edges()):
				list.append(str(MERCY_ALIASES[item.strip_edges()]))
			else:
				print("--mercy: '%s' unknown (kill|spare|mixed), skipped" % item)
		if not list.is_empty():
			_fate_policy = list[0]
			_mercy_list = list if list.size() > 1 else ([] as Array[String])
	elif arg.begins_with("--shop="):
		if val == "on":
			_shop_policy = "greedy"
			_shop_extras = true
		elif val == "off":
			_shop_policy = "none"
		else:
			print("--shop: '%s' unknown (on|off), ignored" % val)
	elif arg.begins_with("--pieces="):
		var flags: Array[bool] = []
		for item: String in val.split(","):
			if item.strip_edges() == "on" or item.strip_edges() == "off":
				flags.append(item.strip_edges() == "on")
			else:
				print("--pieces: '%s' unknown (on|off|on,off), skipped" % item)
		if not flags.is_empty():
			_pieces_flag = true
			_pieces_on = flags[0]
			_pieces_list = flags if flags.size() > 1 else ([] as Array[bool])
	elif arg.begins_with("--relic="):
		if RELIC_MODES.has(val):
			_relic_mode = val
			_relic_policy = "none" if val == "none" else "pick"
		else:
			print("--relic: '%s' unknown (value|random|none), ignored" % val)
	elif arg.begins_with("--tables="):
		if val == "v6":
			_v6 = true
			_world = true
		elif val == "none" or val == "old":
			_tables_forced_off = true
		else:
			print("--tables: '%s' unknown (v6|none), ignored" % val)
		return true
	else:
		return false
	_world = true
	_v6 = true
	return true


# After the data is loaded: `--tables=none` wins over the aliases; `--pieces=` gets its piece-deck config and state.
func _v6_setup() -> void:
	if _tables_forced_off:
		_v6 = false
	_orig_piece_spec = _core.piece_deck_spec
	_orig_piece_state = _core.piece_deck_state
	if _pieces_flag:
		if not _orig_piece_spec.is_empty():
			print("--pieces: --piece-deck=%s is given too; an `on` variant uses the policy deck, an `off` variant keeps that spec" % _orig_piece_spec)
		_core.piece_deck_cfg = PieceDeckConfig.load_from_file()
		_set_pieces(_pieces_on)


# `--pieces=on|off`: on = the sim_core piece-deck branch with a per-run state (set before every match in [method _world_match]);
# off = whatever `--piece-deck` gave (nothing by default).
func _set_pieces(on: bool) -> void:
	_pieces_on = on
	if on:
		_core.piece_deck_spec = "run_v6_policy"
		_core.piece_deck_state = PieceDeck.initial(_core.piece_lib)
	else:
		_core.piece_deck_spec = _orig_piece_spec
		_core.piece_deck_state = _orig_piece_state


# The floor indices a run plays: Vector2i(first, last) of 0-based indices; index `floors` is the final match. `--floors=a..b` =
# a-1 .. b-1; the final match is played when the range ends at the last floor (or is the default) and `--final` is not off.
func _f_range(floors: int) -> Vector2i:
	var a: int = clampi(_f_from, 0, floors)
	var last_region: int = floors - 1 if _floors_b < 0 else clampi(_floors_b, 1, floors) - 1
	var to: int = last_region
	if last_region == floors - 1 and _final_on:
		to = floors
	return Vector2i(a, maxi(to, a))


# `--relic=value`: the offered relic with the best rarity rank x 10 + RELIC_VALUE_BONUS (the first one on a tie).
func _value_relic(offer: Array[String]) -> String:
	var best: String = offer[0]
	var best_score: float = -INF
	for id: String in offer:
		var rank: int = RelicConfig.rarity_rank(str(_core.relic_config.get_relic(id)["rarity"]))
		var score: float = 10.0 * float(rank) + float(RELIC_VALUE_BONUS.get(id, 0.0))
		if score > best_score:
			best_score = score
			best = id
	return best


# ---- `--pieces=on`: the bot's piece-deck policy. Ink rows are rolled exactly as GameFlow._roll_ink_for (chance after a battle /
# danger, always after a treasure, same seed salt); the bot inks the offered shape of 2..3 cells with the fewest cells (none = skip).
# Shape removals (the start token, +1 per region boss, the shop service under `--shop=on`) take the 5-cell default shape with the
# biggest bounding box first (a static stand-in for "fits the arenas least"), never below min_shapes.


# After a won match node or a treasure ([param kind]): the ink row, then the removal tokens.
func _pieces_after_node(w: WorldRun, kind: String, out: Dictionary) -> void:
	if not _pieces_on:
		return
	var cfg: PieceDeckConfig = _core.piece_deck_cfg
	if kind == ChapterMapGen.KIND_BATTLE or kind == ChapterMapGen.KIND_DANGER or kind == ChapterMapGen.KIND_TREASURE:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([w.run_seed, w.floor, w.region_id, w.column, w.nodes_cleared, INK_SEED_TAG]) & SEED_MASK
		var hit: bool = rng.randf() < cfg.ink_offer_chance
		if kind == ChapterMapGen.KIND_TREASURE or hit:
			var offer: Array[String] = PieceDeck.roll_ink_offer(w.piece_deck, _core.piece_lib, cfg, rng.randi() & SEED_MASK, _core.locked_ids("piece"))
			var pick: String = _ink_pick(offer)
			if not pick.is_empty():
				w.piece_deck = PieceDeck.apply_ink(w.piece_deck, pick, _core.piece_lib, cfg)
				out["ink_taken"] = float(out["ink_taken"]) + 1.0
	_pieces_use_tokens(w, out)


# The ink the bot takes from [param offer]: 2..3 cells, fewest cells first, the first on a tie; "" = skip.
func _ink_pick(offer: Array[String]) -> String:
	var best: String = ""
	var best_cells: int = 1 << 30
	for id: String in offer:
		var cells: int = _core.piece_lib.shape_cells(id).size()
		if cells >= PIECES_INK_MIN_CELLS and cells <= PIECES_INK_MAX_CELLS and cells < best_cells:
			best_cells = cells
			best = id
	return best


# Spends every shape-removal token the bot holds on [method _pieces_remove_pick].
func _pieces_use_tokens(w: WorldRun, out: Dictionary) -> void:
	while w.shape_removals > 0:
		var pick: String = _pieces_remove_pick(w.piece_deck)
		if pick.is_empty():
			return
		w.piece_deck = PieceDeck.remove(w.piece_deck, pick, _core.piece_lib, _core.piece_deck_cfg)
		w.shape_removals -= 1
		out["shape_removed"] = float(out["shape_removed"]) + 1.0


# The shape to remove from [param state]: an active default-pool 5-cell shape (biggest bounding box, then id order) that
# PieceDeck.can_remove accepts; "" = none.
func _pieces_remove_pick(state: Dictionary) -> String:
	var best: String = ""
	var best_area: int = -1
	for id: String in PieceDeck.active_ids(state, _core.piece_lib):
		if _core.piece_lib.is_run_only(id):
			continue
		var cells: Array[Vector2i] = _core.piece_lib.shape_cells(id)
		if cells.size() != PIECES_REMOVE_CELLS:
			continue
		var lo := Vector2i(1 << 20, 1 << 20)
		var hi := Vector2i(-(1 << 20), -(1 << 20))
		for c: Vector2i in cells:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		var area: int = (hi.x - lo.x + 1) * (hi.y - lo.y + 1)
		if area > best_area and bool(PieceDeck.can_remove(state, id, _core.piece_lib, _core.piece_deck_cfg)["ok"]):
			best_area = area
			best = id
	return best


# `--shop=on` extras after the greedy buys: the remove-card service while the deck holds more than SHOP_REMOVE_CARD_OVER cards
# (the lowest-value card), and with `--pieces=on` the remove-shape service. Returns the number of services bought.
func _visit_shop_extras(rs: RunSession, state: Dictionary, bought_ids: Array[String]) -> int:
	var n: int = 0
	if rs.deck.size() > SHOP_REMOVE_CARD_OVER:
		var index: int = _lowest_value_index(rs)
		if index >= 0 and bool(ShopLogic.use_service(state, rs, ShopLogic.SERVICE_REMOVE_CARD, index, _core.cards)["ok"]):
			n += 1
			bought_ids.append("service:%s" % ShopLogic.SERVICE_REMOVE_CARD)
	if _pieces_on:
		var pick: String = _pieces_remove_pick(rs.piece_deck)
		if not pick.is_empty():
			var res: Dictionary = ShopLogic.use_service(state, rs, ShopLogic.SERVICE_REMOVE_SHAPE, pick, null,
				{"piece_library": _core.piece_lib, "piece_config": _core.piece_deck_cfg})
			if bool(res["ok"]):
				n += 1
				bought_ids.append("service:%s" % ShopLogic.SERVICE_REMOVE_SHAPE)
	return n


# The variants of one invocation: the cartesian product of the `--dodge` / `--mercy` / `--pieces` lists (a flag without a
# list = one value). Without the v6 tables: one empty variant, nothing is applied.
func _v6_combos() -> Array[Dictionary]:
	var combos: Array[Dictionary] = []
	if not _v6:
		combos.append({})
		return combos
	var dodges: Array[float] = []
	if _dodge_list.size() > 1:
		dodges.append_array(_dodge_list)
	else:
		dodges.append(float(_core.bot["dodge"]))
	var mercies: Array[String] = []
	if _mercy_list.size() > 1:
		mercies.append_array(_mercy_list)
	else:
		mercies.append(_fate_policy)
	var pieces: Array[bool] = []
	if _pieces_list.size() > 1:
		pieces.append_array(_pieces_list)
	else:
		pieces.append(_pieces_on)
	for d: float in dodges:
		for m: String in mercies:
			for pc: bool in pieces:
				combos.append({"dodge": d, "mercy": m, "pieces": pc})
	return combos


# The mercy name of a fate policy for output ("" = no fate).
func _mercy_name(fate: String) -> String:
	for key: Variant in MERCY_ALIASES.keys():
		if str(MERCY_ALIASES[key]) == fate:
			return str(key)
	return "none"


# Applies one variant to the shared state (bot dodge, fate policy, piece policy) and sets its label.
func _v6_apply(combo: Dictionary) -> void:
	_core.bot["dodge"] = float(combo["dodge"])
	_fate_policy = str(combo["mercy"])
	if _pieces_flag:
		_set_pieces(bool(combo["pieces"]))
	_variant_label = "dodge=%.2f mercy=%s pieces=%s" % [float(combo["dodge"]), _mercy_name(_fate_policy), "on" if _pieces_on else "off"]


# The `policy` cell of the RUN table: the build policy plus the Story 040 policy flags in force.
func _policy_tag(policy: String) -> String:
	return "%s [mercy=%s shop=%s pieces=%s relic=%s dodge=%.2f]" % [policy, _mercy_name(_fate_policy),
		("on" if _shop_extras else _shop_policy), "on" if _pieces_on else "off",
		_relic_mode if not _relic_mode.is_empty() else "legacy:" + _relic_policy, float(_core.bot["dodge"])]


# Header lines of the v6 tables: the flags, the out-of-match seconds and the relic value table.
func _v6_header(floors: int) -> void:
	var fr: Vector2i = _f_range(floors)
	print("v6 (Story 040): floors=%d..%d%s | final=%s | mercy=%s%s | shop=%s%s | pieces=%s%s | relic=%s | dodge=%s | kiep=%s" % [
		fr.x + 1, mini(fr.y, floors - 1) + 1, "" if _floors_b < 0 else " (--floors)", "on" if fr.y == floors else "off",
		_mercy_name(_fate_policy), (" (list " + ",".join(PackedStringArray(_mercy_list)) + ")") if not _mercy_list.is_empty() else "",
		"on" if _shop_extras else _shop_policy, " (+ remove card over %d cards, remove shape with pieces on)" % SHOP_REMOVE_CARD_OVER if _shop_extras else "",
		"on" if _pieces_on else "off", " (list)" if not _pieces_list.is_empty() else "",
		_relic_mode if not _relic_mode.is_empty() else "legacy:" + _relic_policy,
		",".join(PackedStringArray(_dodge_list.map(func(x: float) -> String: return "%.2f" % x))) if _dodge_list.size() > 1 else "%.2f" % float(_core.bot["dodge"]),
		str(_kiep_levels) if _kiep_active else "0"])
	if _seed_offset > 0:
		print("v6 seeds start at %d (--seed-offset=%d), not 1" % [_seed_offset + 1, _seed_offset])
	if _node_overhead_given:
		print("v6 run time: --node-overhead=%.0f s per node (the old formula) replaces the out-of-match table below; no intro / end delay" % _node_overhead)
	print("v6 run time (ASSUMPTIONS, TD-006 family): out-of-match seconds map %.0f / node, reward pick %.0f, shop %.0f, event %.0f, rest %.0f, fate choice %.0f; + intro_sec + end_delay_sec of every match; est. minutes = (match real sec + out-of-match sec) / 60" % [
		OOM_MAP_SEC, OOM_REWARD_SEC, OOM_SHOP_SEC, OOM_EVENT_SEC, OOM_REST_SEC, OOM_FATE_SEC])
	var cells: Array[String] = []
	for id: String in _core.relic_config.ids():
		cells.append("%s=%+.0f" % [id, float(RELIC_VALUE_BONUS.get(id, 0.0))])
	print("v6 relic value (--relic=value: first best of the offer by rarity rank x 10 + bonus; ASSUMPTION): %s" % " ".join(PackedStringArray(cells)))
	print("v6 pieces policy (--pieces=on): ink a 2-3 cell shape (fewest cells) when offered, remove 5-cell shapes (biggest bounding box first) with every shape-removal token; shop extras (--shop=on): remove-card over %d cards, remove-shape when pieces on" % SHOP_REMOVE_CARD_OVER)


# ---- the v6 tables. Every line starts with RUN, REGION x FLOOR, RELIC LIFT, SHOP, DODGE SENSITIVITY or VERDICT run.


# "PASS" / "FAIL" for a value against an inclusive [lo, hi] range.
func _in_band(value: float, band: Array[float]) -> String:
	return "PASS" if value >= band[0] and value <= band[1] else "FAIL"


# One VERDICT line of the run table: `VERDICT run <character>/<policy> | <what> | <value text> | PASS|FAIL|DEFERRED`.
func _v6_verdict(char_id: String, policy: String, what: String, text: String, result: String) -> void:
	print("VERDICT run %s/%s | %s | %s | %s" % [char_id, policy, what, text, result])


# Per character and policy, after the old WORLD tables: the RUN table, its detail line, REGION x FLOOR and the VERDICT run lines.
func _v6_run_report(char_id: String, policy: String, runs: Array[Dictionary], floors: int, win_pct: float) -> void:
	var n: int = runs.size()
	var fr: Vector2i = _f_range(floors)
	var won_runs: Array[Dictionary] = []
	var lost_runs: Array[Dictionary] = []
	var deaths: Array[int] = []
	deaths.resize(floors + 1)
	deaths.fill(0)
	for r: Dictionary in runs:
		if bool(r["won"]):
			won_runs.append(r)
		else:
			lost_runs.append(r)
			deaths[clampi(int(r["death_floor"]), 0, floors)] += 1
	var entering: Array[int] = []
	entering.resize(floors + 1)
	var alive: int = n
	for f: int in floors + 1:
		entering[f] = alive if f >= fr.x else 0
		alive -= deaths[f]
	var death_cells: Array[String] = []
	for f: int in floors + 1:
		death_cells.append(str(deaths[f]))
	var minutes_won: Array = _field(won_runs, "minutes_est")
	var minutes_lost: Array = _field(lost_runs, "minutes_est")
	var earned: Array = []
	for r: Dictionary in runs:
		earned.append(float(r["gold_drop"]) + float(r["gold_event_in"]))
	var earned_won: Array = []
	for r: Dictionary in won_runs:
		earned_won.append(float(r["gold_drop"]) + float(r["gold_event_in"]))
	var spent: Array = _field(runs, "gold_spent")
	var spent_won: Array = _field(won_runs, "gold_spent")
	var hits_won: float = _mean(_field(won_runs, "hits"))
	print("")
	print("=== RUN v6 %s / %s: %d runs, %s ===" % [char_id, policy, n, _variant_label if not _variant_label.is_empty() else "kiep %d" % _kiep_level])
	print("RUN | character | policy | kiep | win % | deaths by floor (f1 f2 f3 f4 f5 final) | hits taken / won run | run minutes (est., won median / lost median) | gold earned / spent (all runs; won runs) | relics / run | deck size | piece set size |")
	print("RUN | %s | %s | %d | %.1f | %s | %s | %s / %s | %.0f / %.0f; %.0f / %.0f | %.2f | %.2f | %.1f |" % [
		char_id, _policy_tag(policy), _kiep_level, win_pct, "/".join(PackedStringArray(death_cells)),
		("%.1f" % hits_won) if not won_runs.is_empty() else "-",
		("%.1f" % _pct(minutes_won, 0.5)) if not won_runs.is_empty() else "-", ("%.1f" % _pct(minutes_lost, 0.5)) if not lost_runs.is_empty() else "-",
		_mean(earned), _mean(spent), _mean(earned_won), _mean(spent_won),
		_mean(_field(runs, "relic_n")), _mean(_field(runs, "size")), _mean(_field(runs, "piece_n"))])
	# Death probability per floor given the floor was entered, final-match win when reached, mean boss swing hit, gold at the final.
	var prob_cells: Array[String] = []
	var probs: Array[float] = []
	var small_floor: bool = false
	for f: int in floors:
		if entering[f] <= 0:
			probs.append(-1.0)
			prob_cells.append("-")
			continue
		var p: float = 100.0 * float(deaths[f]) / float(entering[f])
		probs.append(p)
		prob_cells.append("%.1f" % p)
		if f >= fr.x and f <= fr.y and entering[f] < 10:
			small_floor = true
	var reached: int = 0
	var final_won: int = 0
	for r: Dictionary in runs:
		if bool(r["final_reached"]):
			reached += 1
			if bool(r["won"]):
				final_won += 1
	var final_pct: float = 100.0 * float(final_won) / maxf(float(reached), 1.0)
	var swing_hits: float = _sum(_field(runs, "shits"))
	var boss_hit_pct: float = 100.0 * _sum(_field(runs, "bdmg")) / maxf(swing_hits, 1.0) / maxf(_mean(_field(runs, "max_hp")), 1.0)
	var gold_final: Array = []
	for r: Dictionary in won_runs:
		if float(r["gold_at_final"]) >= 0.0:
			gold_final.append(float(r["gold_at_final"]))
	var relic_price: int = _economy.price_relic("common", maxi(floors - 1, 0))
	print("RUN DETAIL %s/%s: death %% of runs entering floor f1..f%d: %s | final reached %d, won %d (%.1f %%) | mean boss swing hit %.1f %% of max HP (%d swing hits) | gold at the final median %s (cheapest shop relic %d at the last floor) | wins %d / %d" % [
		char_id, policy, floors, "/".join(PackedStringArray(prob_cells)), reached, final_won, final_pct, boss_hit_pct, int(swing_hits),
		("%.0f" % _pct(gold_final, 0.5)) if not gold_final.is_empty() else "-", relic_price, won_runs.size(), n])
	var region_state: String = _v6_region_floor(char_id, policy, runs, floors)
	var sd: float = 100.0 * sqrt(maxf(win_pct / 100.0 * (1.0 - win_pct / 100.0), 0.0) / maxf(float(n), 1.0))
	# The Part C lines. A comparison that needs a second run is printed by _v6_compare_report.
	_v6_verdict(char_id, policy, "run win %% %.0f-%.0f" % [V6_WIN_TARGET[0], V6_WIN_TARGET[1]], "%.1f %% (+-%.1f sd, n=%d)" % [win_pct, sd, n], _in_band(win_pct, V6_WIN_TARGET))
	var step_bad: Array[String] = []
	for f: int in range(maxi(fr.x, 0) + 1, floors):
		if probs[f] >= 0.0 and probs[f - 1] >= 0.0 and probs[f] < probs[f - 1] - V6_DEATH_STEP_TOLERANCE:
			step_bad.append("f%d %.1f < f%d %.1f" % [f + 1, probs[f], f, probs[f - 1]])
	var steps_text: String = "death prob by floor %s (allow -%.0f pts)" % ["/".join(PackedStringArray(prob_cells)), V6_DEATH_STEP_TOLERANCE]
	if fr.y - fr.x < 1:
		_v6_verdict(char_id, policy, "death probability non-decreasing f1..f5", "fewer than two floors played", "DEFERRED")
	elif small_floor:
		_v6_verdict(char_id, policy, "death probability non-decreasing f1..f5", steps_text + "; a floor was entered < 10 times (small n)", "DEFERRED")
	else:
		_v6_verdict(char_id, policy, "death probability non-decreasing f1..f5", steps_text + (("; falls: " + ", ".join(PackedStringArray(step_bad))) if not step_bad.is_empty() else ""), "PASS" if step_bad.is_empty() else "FAIL")
	if fr.x > 0:
		_v6_verdict(char_id, policy, "floor-1 deaths <= %.0f %% of runs" % V6_FLOOR1_DEATH_MAX, "floor 1 not played (--floors)", "DEFERRED")
	else:
		var f1_pct: float = 100.0 * float(deaths[0]) / maxf(float(n), 1.0)
		_v6_verdict(char_id, policy, "floor-1 deaths <= %.0f %% of runs" % V6_FLOOR1_DEATH_MAX, "%.1f %%" % f1_pct, "PASS" if f1_pct <= V6_FLOOR1_DEATH_MAX else "FAIL")
	if reached == 0:
		_v6_verdict(char_id, policy, "final-match win when reached %.0f-%.0f %%" % [V6_FINAL_WIN_TARGET[0], V6_FINAL_WIN_TARGET[1]], "the final was never reached (or --final=off)", "DEFERRED")
	else:
		_v6_verdict(char_id, policy, "final-match win when reached %.0f-%.0f %%" % [V6_FINAL_WIN_TARGET[0], V6_FINAL_WIN_TARGET[1]], "%.1f %% (%d / %d)" % [final_pct, final_won, reached], _in_band(final_pct, V6_FINAL_WIN_TARGET))
	if won_runs.is_empty():
		_v6_verdict(char_id, policy, "won-run minutes median %.0f-%.0f" % [V6_MINUTES_WON_TARGET[0], V6_MINUTES_WON_TARGET[1]], "no won run", "DEFERRED")
		_v6_verdict(char_id, policy, "boss hits per won run %.0f-%.0f" % [V6_HITS_TARGET[0], V6_HITS_TARGET[1]], "no won run", "DEFERRED")
		_v6_verdict(char_id, policy, "gold spent >= %.0f %% of earned (won runs)" % V6_GOLD_SPENT_MIN_PCT, "no won run", "DEFERRED")
		_v6_verdict(char_id, policy, "gold left at the final median <= one shop relic", "no won run", "DEFERRED")
	else:
		var med_won: float = _pct(minutes_won, 0.5)
		_v6_verdict(char_id, policy, "won-run minutes median %.0f-%.0f" % [V6_MINUTES_WON_TARGET[0], V6_MINUTES_WON_TARGET[1]], "%.1f min (%d won runs)" % [med_won, won_runs.size()], _in_band(med_won, V6_MINUTES_WON_TARGET))
		_v6_verdict(char_id, policy, "boss hits per won run %.0f-%.0f" % [V6_HITS_TARGET[0], V6_HITS_TARGET[1]], "%.1f" % hits_won, _in_band(hits_won, V6_HITS_TARGET))
		var spent_pct: float = 100.0 * _sum(spent_won) / maxf(_sum(earned_won), 1.0)
		_v6_verdict(char_id, policy, "gold spent >= %.0f %% of earned (won runs)" % V6_GOLD_SPENT_MIN_PCT, "%.1f %% (%.0f of %.0f per run)" % [spent_pct, _mean(spent_won), _mean(earned_won)], "PASS" if spent_pct >= V6_GOLD_SPENT_MIN_PCT else "FAIL")
		if gold_final.is_empty():
			_v6_verdict(char_id, policy, "gold left at the final median <= one shop relic", "the final was not played", "DEFERRED")
		else:
			var left_med: float = _pct(gold_final, 0.5)
			_v6_verdict(char_id, policy, "gold left at the final median <= one shop relic", "%.0f <= %d" % [left_med, relic_price], "PASS" if left_med <= float(relic_price) else "FAIL")
	if lost_runs.is_empty():
		_v6_verdict(char_id, policy, "lost-run minutes median >= %.0f" % V6_MINUTES_LOST_MIN, "no lost run", "DEFERRED")
	else:
		var med_lost: float = _pct(minutes_lost, 0.5)
		_v6_verdict(char_id, policy, "lost-run minutes median >= %.0f" % V6_MINUTES_LOST_MIN, "%.1f min (%d lost runs)" % [med_lost, lost_runs.size()], "PASS" if med_lost >= V6_MINUTES_LOST_MIN else "FAIL")
	if swing_hits <= 0.0:
		_v6_verdict(char_id, policy, "mean boss hit %.0f-%.0f %% of max HP" % [V6_BOSS_HIT_PCT_TARGET[0], V6_BOSS_HIT_PCT_TARGET[1]], "no boss swing hit", "DEFERRED")
	else:
		_v6_verdict(char_id, policy, "mean boss hit %.0f-%.0f %% of max HP" % [V6_BOSS_HIT_PCT_TARGET[0], V6_BOSS_HIT_PCT_TARGET[1]], "%.1f %% (swing hits only)" % boss_hit_pct, _in_band(boss_hit_pct, V6_BOSS_HIT_PCT_TARGET))
	_v6_verdict(char_id, policy, "regions within +-%.0f pts of the floor mean" % V6_REGION_BAND, "see REGION x FLOOR CHECK", region_state)
	if _core.describe_progress().is_empty():
		_v6_verdict(char_id, policy, "onboarding (empty save) win >= 20 %", "this run has every unlock open (--progress=all)", "DEFERRED (run with --progress=none)")
	else:
		_v6_verdict(char_id, policy, "onboarding (empty save) win >= 20 %", "%.1f %% under --progress=none" % win_pct, "PASS" if win_pct >= 20.0 else "FAIL")
	_v6_verdict(char_id, policy, "bot anchored on a playtest (Part A, TD-006)", "dodge=%.2f%s" % [float(_core.bot["dodge"]), " (legacy default)" if is_equal_approx(float(_core.bot["dodge"]), SimCore.LEGACY_DODGE_P) else " (override)"], "DEFERRED (no playtest log: DEFAULT_BOT stays, TD-006 open; read the DODGE SENSITIVITY run)")


# REGION x FLOOR: per region and floor the matches entered and the match win %, from every match of the runs (event fights
# included, the final match left out). The check: a region with >= V6_REGION_MIN_N matches sits within +-V6_REGION_BAND of
# the floor's mean match win %. Returns PASS / FAIL / DEFERRED for the VERDICT line.
func _v6_region_floor(char_id: String, policy: String, runs: Array[Dictionary], floors: int) -> String:
	var by: Dictionary = {}
	var by_floor: Dictionary = {}
	for r: Dictionary in runs:
		for e: Array in r["mlog"] as Array:
			var f: int = int(e[0])
			if f >= floors:
				continue
			var key: String = "%d|%s" % [f, str(e[1])]
			if not by.has(key):
				by[key] = [0, 0]
			by[key][0] = int(by[key][0]) + 1
			by[key][1] = int(by[key][1]) + (1 if bool(e[2]) else 0)
			if not by_floor.has(f):
				by_floor[f] = [0, 0]
			by_floor[f][0] = int(by_floor[f][0]) + 1
			by_floor[f][1] = int(by_floor[f][1]) + (1 if bool(e[2]) else 0)
	print("REGION x FLOOR | character | floor | region | matches entered | match win % |")
	var bad: Array[String] = []
	var checked: int = 0
	var small: int = 0
	var cells: Array[String] = []
	for f: int in floors:
		if not by_floor.has(f):
			continue
		var mean_pct: float = 100.0 * float(by_floor[f][1]) / maxf(float(by_floor[f][0]), 1.0)
		cells.append("f%d mean %.1f (n=%d)" % [f + 1, mean_pct, int(by_floor[f][0])])
		for id: String in _chapters.region_ids():
			var key: String = "%d|%s" % [f, id]
			if not by.has(key):
				continue
			var m: int = int(by[key][0])
			var pct: float = 100.0 * float(by[key][1]) / maxf(float(m), 1.0)
			var note: String = ""
			if m < V6_REGION_MIN_N:
				note = " small (n < %d)" % V6_REGION_MIN_N
				small += 1
			else:
				checked += 1
				if absf(pct - mean_pct) > V6_REGION_BAND:
					bad.append("f%d %s %.1f vs mean %.1f" % [f + 1, id, pct, mean_pct])
			print("REGION x FLOOR | %s | %d | %s | %d | %.1f |%s" % [char_id, f + 1, id, m, pct, note])
	var state: String = "DEFERRED" if checked == 0 else ("PASS" if bad.is_empty() else "FAIL")
	print("REGION x FLOOR CHECK %s/%s: floors %s | regions within +-%.0f pts of the floor mean (cells with n >= %d: %d checked, %d small): %s%s" % [
		char_id, policy, "; ".join(PackedStringArray(cells)) if not cells.is_empty() else "none", V6_REGION_BAND, V6_REGION_MIN_N, checked, small, state,
		(" | outside: " + ", ".join(PackedStringArray(bad))) if not bad.is_empty() else ""])
	return state


# Per variant, over every run of the invocation's characters and policies: RELIC LIFT, SHOP, the spread between characters.
func _v6_aggregate_report(combo: Dictionary, _floors: int) -> void:
	var runs: Array[Dictionary] = _v6_runs
	if runs.is_empty():
		return
	var total: int = runs.size()
	var total_wins: int = 0
	var by_char: Dictionary = {}
	for r: Dictionary in runs:
		var won: int = 1 if bool(r["won"]) else 0
		total_wins += won
		var key: String = str(r["character"])
		if str(r["policy"]) != VERDICT_POLICY and _policies_given_has_verdict():
			continue
		if not by_char.has(key):
			by_char[key] = [0, 0]
		by_char[key][0] = int(by_char[key][0]) + 1
		by_char[key][1] = int(by_char[key][1]) + won
	var wins_by_char: Dictionary = {}
	var runs_by_char: Dictionary = {}
	for key: Variant in by_char.keys():
		wins_by_char[key] = 100.0 * float(by_char[key][1]) / maxf(float(by_char[key][0]), 1.0)
		runs_by_char[key] = int(by_char[key][0])
	_v6_summary.append({"label": _variant_label, "dodge": float(combo.get("dodge", _core.bot["dodge"])), "mercy": _fate_policy,
		"pieces": _pieces_on, "wins": wins_by_char, "runs": runs_by_char})
	print("")
	print("=== RUN v6 AGGREGATE (%s): %d runs of %s ===" % [_variant_label, total, str(wins_by_char.keys())])
	# RELIC LIFT.
	var with_n: Dictionary = {}
	var with_w: Dictionary = {}
	for r: Dictionary in runs:
		var seen: Dictionary = {}
		for id: Variant in r["relics_f2"] as Array:
			seen[str(id)] = true
		for id: Variant in seen.keys():
			with_n[id] = int(with_n.get(id, 0)) + 1
			with_w[id] = int(with_w.get(id, 0)) + (1 if bool(r["won"]) else 0)
	print("RELIC LIFT | relic | runs with it by floor <= 2 | win % with | win % without | lift (pts) | note |")
	var lift_bad: Array[String] = []
	var lift_small: Array[String] = []
	var lift_max: float = -INF
	var lift_max_id: String = ""
	var ids: Array = with_n.keys()
	ids.sort()
	for id: Variant in ids:
		var n_with: int = int(with_n[id])
		var n_wo: int = total - n_with
		var pct_with: float = 100.0 * float(with_w[id]) / maxf(float(n_with), 1.0)
		var pct_wo: float = 100.0 * float(total_wins - int(with_w[id])) / maxf(float(n_wo), 1.0)
		var lift: float = pct_with - pct_wo
		var small: bool = n_with < V6_LIFT_MIN_N or n_wo < V6_LIFT_MIN_N
		if small:
			lift_small.append(str(id))
		else:
			if lift > lift_max:
				lift_max = lift
				lift_max_id = str(id)
			if lift > V6_RELIC_LIFT_MAX:
				lift_bad.append("%s %+.1f" % [id, lift])
		print("RELIC LIFT | %s | %d | %.1f | %s | %+.1f |%s" % [id, n_with, pct_with, ("%.1f" % pct_wo) if n_wo > 0 else "-", lift if n_wo > 0 else 0.0, " small (n < %d)" % V6_LIFT_MIN_N if small else ""])
	var lift_state: String = "DEFERRED" if lift_max_id.is_empty() else ("PASS" if lift_bad.is_empty() else "FAIL")
	print("RELIC LIFT CHECK: no relic above +%.0f pts (cells with >= %d runs with and without): max %s%s | %s%s" % [
		V6_RELIC_LIFT_MAX, V6_LIFT_MIN_N, ("%+.1f (%s)" % [lift_max, lift_max_id]) if not lift_max_id.is_empty() else "none checked", "" if lift_bad.is_empty() else " | above: " + ", ".join(PackedStringArray(lift_bad)),
		lift_state, (" | small cells: " + ",".join(PackedStringArray(lift_small))) if not lift_small.is_empty() else ""])
	print("VERDICT run all | no relic lift > +%.0f pts | max %s | %s" % [V6_RELIC_LIFT_MAX, ("%+.1f (%s)" % [lift_max, lift_max_id]) if not lift_max_id.is_empty() else "none checked", lift_state])
	# SHOP.
	var visits: int = 0
	var offered: Dictionary = {}
	var bought: Dictionary = {}
	for r: Dictionary in runs:
		for visit: Dictionary in r["shop_log"] as Array:
			visits += 1
			for id: Variant in visit["offered"] as Array:
				offered[id] = int(offered.get(id, 0)) + 1
			for id: Variant in visit["bought"] as Array:
				bought[id] = int(bought.get(id, 0)) + 1
	print("SHOP | item | bought | offered | bought % of shop visits | bought % of offers |")
	var items: Array = offered.keys()
	items.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ba: int = int(bought.get(a, 0))
		var bb: int = int(bought.get(b, 0))
		return ba > bb or (ba == bb and str(a) < str(b)))
	var rare_items: Array[String] = []
	var dead_items: Array[String] = []
	for id: Variant in items:
		var b: int = int(bought.get(id, 0))
		var o: int = int(offered[id])
		var of_visits: float = 100.0 * float(b) / maxf(float(visits), 1.0)
		var of_offers: float = 100.0 * float(b) / maxf(float(o), 1.0)
		if of_visits < V6_SHOP_MIN_PCT:
			rare_items.append("%s %d/%d" % [id, b, o])
		if o >= V6_SHOP_MIN_OFFERS and of_offers < V6_SHOP_MIN_PCT:
			dead_items.append("%s %d/%d" % [id, b, o])
		print("SHOP | %s | %d | %d | %.1f | %.1f |" % [id, b, o, of_visits, of_offers])
	var shop_state: String = "DEFERRED" if visits < V6_SHOP_MIN_VISITS else ("PASS" if dead_items.is_empty() else "FAIL")
	print("SHOP CHECK: %d shop visits | literal rule, bought in < %.0f %% of shop visits: %d of %d items (a relic / card that is rarely in stock lands here; read the next line) | never worth buying, offered >= %d times and bought < %.0f %% of those offers: %d items%s | %s" % [
		visits, V6_SHOP_MIN_PCT, rare_items.size(), items.size(), V6_SHOP_MIN_OFFERS, V6_SHOP_MIN_PCT, dead_items.size(),
		(" (" + ", ".join(PackedStringArray(dead_items)) + ")") if not dead_items.is_empty() else "", shop_state])
	print("VERDICT run all | no shop item bought < %.0f %% of its offers (offered >= %d times) | %d visits, %d items flagged | %s" % [V6_SHOP_MIN_PCT, V6_SHOP_MIN_OFFERS, visits, dead_items.size(), shop_state])
	# Spread between characters.
	if wins_by_char.size() > 1:
		var lo: float = INF
		var hi: float = -INF
		for key: Variant in wins_by_char.keys():
			lo = minf(lo, float(wins_by_char[key]))
			hi = maxf(hi, float(wins_by_char[key]))
		print("VERDICT run all | spread between characters <= %.0f pts | %.1f (max %.1f, min %.1f over %s) | %s" % [
			V6_WIN_SPREAD_MAX, hi - lo, hi, lo, str(wins_by_char.keys()), "PASS" if hi - lo <= V6_WIN_SPREAD_MAX else "FAIL"])
	else:
		print("VERDICT run all | spread between characters <= %.0f pts | one character | DEFERRED (run --characters=kiem_si,phap_su,sat_thu,tho_san,giao_si)" % V6_WIN_SPREAD_MAX)


# True when the invocation plays the verdict policy (the spread and the compare lines count that policy's rows only then).
func _policies_given_has_verdict() -> bool:
	return not _policies_given or _policies.has(VERDICT_POLICY)


# After every variant: the DODGE SENSITIVITY summary, the kill-vs-spare and pieces on-vs-off comparisons (PASS / FAIL when both
# variants ran in this invocation, else DEFERRED with the command) and the Kiep line.
func _v6_compare_report(_combos: Array[Dictionary]) -> void:
	print("")
	if _dodge_list.size() > 1:
		print("DODGE SENSITIVITY | character | dodge | win % | variant |")
		for entry: Dictionary in _v6_summary:
			for key: Variant in (entry["wins"] as Dictionary).keys():
				print("DODGE SENSITIVITY | %s | %.2f | %.1f | mercy=%s pieces=%s (n=%d) |" % [key, float(entry["dodge"]), float((entry["wins"] as Dictionary)[key]),
					_mercy_name(str(entry["mercy"])), "on" if bool(entry["pieces"]) else "off", int((entry["runs"] as Dictionary)[key])])
	var cmd: String = "godot --headless --path . -s res://tools/balance/deck_sim.gd -- --run=v6 --seeds=70"
	var kill_spare: bool = _mercy_list.has("execute") and _mercy_list.has("spare")
	var pieces_pair: bool = _pieces_list.has(true) and _pieces_list.has(false)
	if not kill_spare:
		print("VERDICT run all | kill vs spare win gap <= %.0f pts | needs both runs | DEFERRED (%s --mercy=kill,spare)" % [V6_MERCY_EDGE_MAX, cmd])
	if not pieces_pair:
		print("VERDICT run all | pieces on not above off by > %.0f pts | needs both runs | DEFERRED (%s --pieces=on,off)" % [V6_PIECES_EDGE_MAX, cmd])
	for entry: Dictionary in _v6_summary:
		for other: Dictionary in _v6_summary:
			if not is_equal_approx(float(entry["dodge"]), float(other["dodge"])):
				continue
			if kill_spare and str(entry["mercy"]) == "execute" and str(other["mercy"]) == "spare" and bool(entry["pieces"]) == bool(other["pieces"]):
				for key: Variant in (entry["wins"] as Dictionary).keys():
					if not (other["wins"] as Dictionary).has(key):
						continue
					var gap: float = absf(float((entry["wins"] as Dictionary)[key]) - float((other["wins"] as Dictionary)[key]))
					print("VERDICT run %s | kill vs spare win gap <= %.0f pts | kill %.1f vs spare %.1f = %.1f (dodge %.2f pieces %s) | %s" % [
						key, V6_MERCY_EDGE_MAX, float((entry["wins"] as Dictionary)[key]), float((other["wins"] as Dictionary)[key]), gap, float(entry["dodge"]),
						"on" if bool(entry["pieces"]) else "off", "PASS" if gap <= V6_MERCY_EDGE_MAX else "FAIL"])
			if pieces_pair and bool(entry["pieces"]) and not bool(other["pieces"]) and str(entry["mercy"]) == str(other["mercy"]):
				for key: Variant in (entry["wins"] as Dictionary).keys():
					if not (other["wins"] as Dictionary).has(key):
						continue
					var edge: float = float((entry["wins"] as Dictionary)[key]) - float((other["wins"] as Dictionary)[key])
					print("VERDICT run %s | pieces on not above off by > %.0f pts | on %.1f vs off %.1f = %+.1f (dodge %.2f mercy %s) | %s" % [
						key, V6_PIECES_EDGE_MAX, float((entry["wins"] as Dictionary)[key]), float((other["wins"] as Dictionary)[key]), edge, float(entry["dodge"]),
						_mercy_name(str(entry["mercy"])), "PASS" if edge <= V6_PIECES_EDGE_MAX else "FAIL"])
	print("VERDICT run all | Kiep win %% monotone 0..10, Kiep 10 >= 3 %% | see the KIEP CHECK lines | DEFERRED (%s --kiep=0..10 --seeds=30 --characters=kiem_si)" % cmd)
