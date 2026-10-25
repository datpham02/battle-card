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
## final match (`world.final_match`); every match RunConfig.from_node(..., floor); a region boss gives the
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
##        godot --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --characters=kiem_si

const SimCore = preload("res://tools/balance/sim_core.gd")

const DEFAULT_SEEDS: int = 70
const POLICIES: Array[String] = ["always_skip", "build"]
const CHARACTERS: Array[String] = ["kiem_si", "phap_su", "sat_thu"]
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
const REGION_PICKS: Array[String] = ["random", "first"]
## Story 031 targets (Part F), build policy.
const WORLD_MINUTES_TARGET: Array = [40.0, 50.0]
const WORLD_WIN_TARGET: Dictionary = {"kiem_si": [20.0, 40.0], "sat_thu": [20.0, 40.0], "phap_su": [10.0, 100.0]}
const WORLD_REGION_SPREAD_MAX: float = 15.0
const WORLD_FLOOR_DEATH_SHARE_MAX: float = 40.0
## Regions entered fewer times than this at a floor are left out of the spread check (too few runs).
const WORLD_REGION_MIN_N: int = 5
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
var _policies_given: bool = false
var _relic_policy: String = "none"


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

	func luck(config: Dictionary = {}) -> float:
		return float(config.get("luck_start", 0.0)) + float(config.get("luck_per_node", 1.0)) * float(nodes_cleared)

	func reward_seed() -> int:
		return hash([run_seed, floor, region_id, column, nodes_cleared]) & 0x7fffffff

	func rest_heal(max_hp: float, config: Dictionary) -> float:
		var before: float = max_hp if hp < 0.0 else minf(hp, max_hp)
		var after: float = minf(before + float(config.get("rest_heal_ratio", 0.3)) * max_hp, max_hp)
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
	var rest: PackedStringArray = _core.apply_args(OS.get_cmdline_user_args())
	var seeds: int = DEFAULT_SEEDS
	for arg: String in rest:
		var v: String = arg.get_slice("=", 1) if arg.contains("=") else ""
		if arg.begins_with("--seeds="):
			seeds = maxi(int(v), 1)
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
				if CHARACTERS.has(c.strip_edges()):
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
		elif arg == "--world":
			_world = true
		elif arg.begins_with("--region-pick="):
			if REGION_PICKS.has(v.strip_edges()):
				_region_pick = v.strip_edges()
			else:
				print("--region-pick: '%s' unknown, using %s (one of %s)" % [v, _region_pick, str(REGION_PICKS)])
		elif arg.begins_with("--node-overhead="):
			_node_overhead = maxf(float(v), 0.0)
		elif arg.begins_with("--world-set="):
			for item: String in v.split(","):
				if not item.strip_edges().is_empty():
					_world_set.append(item.strip_edges())
		elif arg.begins_with("--relic-policy="):
			if RELIC_POLICIES.has(v.strip_edges()):
				_relic_policy = v.strip_edges()
			else:
				print("--relic-policy: '%s' unknown, using %s (one of %s)" % [v, _relic_policy, str(RELIC_POLICIES)])
		elif arg.begins_with("--trace="):
			if v.is_valid_int():
				_trace_n = int(v)
			else:
				_trace_id = v
		else:
			print("unknown flag %s (see tools/balance/README.md)" % arg)
	_core.load_configs()
	_chapters = ChaptersConfig.load_from_file() if _world_set.is_empty() else _chapters_with_overrides(_world_set)
	_reward_config = RewardRoller.load_config()
	_max_level = int(_reward_config["max_card_level"])
	_min_deck_size = int(_reward_config["min_deck_size"])
	if _world:
		_run_world_mode(seeds)
		print("runtime: %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
		quit(0)
		return
	print("deck_sim (Story 026, v5 pieces): seeds=%d timeout=%.0fs policies=%s characters=%s chapters=%s cleared_bosses=%d (always_skip + %s onboarding on chapter 1 only)" % [
		seeds, SimCore.MATCH_TIMEOUT_SEC, str(_policies), str(_characters_run), str(_chapter_list), CLEARED_BOSSES_MAIN, ONBOARDING_CHARACTER])
	print(_core.describe())
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
	var cfg: Dictionary = _reward_config.duplicate(true)
	cfg["offer_count"] = offers
	var reward_seed: int = (session as WorldRun).reward_seed() if session is WorldRun else (hash([session.run_seed, session.chapter_index, session.column, session.cleared_nodes.size()]) & SEED_MASK)
	var levels: Dictionary = session.deck_levels()
	var excluded: Array[String] = _core.zone_card_ids() if bool(_core.ov["no_zone_cards"]) else ([] as Array[String])
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


func _run_world_mode(seeds: int) -> void:
	var pols: Array[String] = _policies.duplicate() if _policies_given else ([VERDICT_POLICY] as Array[String])
	var w: Dictionary = _chapters.world_spec()
	var floors: int = _chapters.world_floors()
	print("deck_sim --world (Story 031): seeds=%d timeout=%.0fs policies=%s characters=%s cleared_bosses=%d region-pick=%s node-overhead=%.0fs (ASSUMPTION: node pick + reward + reading, per node) world-set=%s" % [
		seeds, SimCore.MATCH_TIMEOUT_SEC, str(pols), str(_characters_run), CLEARED_BOSSES_MAIN, _region_pick, _node_overhead,
		",".join(PackedStringArray(_world_set)) if not _world_set.is_empty() else "none"])
	print(_core.describe())
	print("relics: start=%s relic-policy=%s (pick = relic row over card row at treasure, rarest first; damage cap %.1f)" % [
		",".join(PackedStringArray(_core.ov["relics"])) if not (_core.ov["relics"] as Array).is_empty() else "none", _relic_policy, _core.relic_config.relic_damage_mult_cap])
	print("world: floors=%d choices=%d pool=%s columns=%d heal=%.2f final=%s tiers=%s" % [floors, int(w["choices_per_floor"]),
		str(w["region_pool"]), (w["region_columns"] as Array).size(), _chapters.floor_heal_ratio(), str(_chapters.final_match()), str(w["floor_tiers"])])
	for f: int in floors + 1:
		print("  floor_scaling %s: %s" % ["final" if f == floors else str(f + 1), str(_chapters.floor_scaling(f))])
	for id: String in _chapters.region_ids():
		print("  region_normalize %s: %s" % [id, str(_chapters.region_normalize(id))])
	print("node policy: rest when HP < %.0f%%, else treasure > rest (heal < %.0f%% else forge) > miniboss at >= %.0f%% HP > battle > danger; boss when alone. Region boss: boss reward + token + floor heal. Run time = (sum of match REAL seconds + overhead x nodes) / 60." % [
		100.0 * REST_HEAL_BELOW, 100.0 * REST_HEAL_BELOW, 100.0 * MINIBOSS_MIN_HP])
	for char_id: String in _characters_run:
		for p: String in pols:
			_world_report(char_id, p, seeds, floors)


func _world_report(char_id: String, policy: String, seeds: int, floors: int) -> void:
	var t_c: int = Time.get_ticks_msec()
	var runs: Array[Dictionary] = []
	for s: int in seeds:
		runs.append(_run_world(s + 1, char_id, policy, floors))
		if (s + 1) % 10 == 0:
			print("  ... %s %d/%d seeds, %.1f s" % [char_id, s + 1, seeds, (Time.get_ticks_msec() - t_c) / 1000.0])
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
		for f: int in path.size():
			var key: String = "%d|%s" % [f, str(path[f])]
			if not by_region.has(key):
				by_region[key] = [0, 0]
			by_region[key][0] = int(by_region[key][0]) + 1
			if int(r["floors_cleared"]) > f:
				by_region[key][1] = int(by_region[key][1]) + 1
		for f: int in (r["hp_in"] as Array).size():
			(hp_in[f] as Array).append(float(r["hp_in"][f]))
		for f: int in (r["hp_out"] as Array).size():
			(hp_out[f] as Array).append(float(r["hp_out"][f]))
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
	var offer: Array[String] = RelicRoller.roll(RelicRoller.SOURCE_TREASURE, owned, rng, _core.relic_config)
	if offer.is_empty():
		return false
	var best: String = offer[0]
	for id: String in offer:
		if RelicConfig.rarity_rank(str(_core.relic_config.get_relic(id)["rarity"])) > RelicConfig.rarity_rank(str(_core.relic_config.get_relic(best)["rarity"])):
			best = id
	owned.append(best)
	return true


func _field(runs: Array, key: String) -> Array:
	var out: Array = []
	for r: Variant in runs:
		out.append(float((r as Dictionary)[key]))
	return out


# One world run: floors x (offer -> pick -> region map column by column) then the final match.
func _run_world(seed_value: int, char_id: String, policy: String, floors: int) -> Dictionary:
	var character: Dictionary = _core.prepare_character(_core.characters.get_character(char_id))
	var max_hp: float = float(character["max_hp"])
	var w := WorldRun.new()
	w.run_seed = seed_value
	w.removal_tokens = int(_reward_config.get("starting_removals", 0))
	w.relics.assign(_core.ov["relics"] as Array)
	for id: Variant in character.get("starter_deck", []) as Array:
		w.deck.append({"id": str(id), "level": 1})
	var bot_rng := RandomNumberGenerator.new()
	bot_rng.seed = hash([seed_value, char_id]) & SEED_MASK
	# Region picks do not depend on the character: same seed -> same path while alive.
	var pick_rng := RandomNumberGenerator.new()
	pick_rng.seed = hash([seed_value, "region_pick"]) & SEED_MASK
	var out: Dictionary = {"won": false, "death_floor": -1, "death_kind": "", "floors_cleared": 0, "path": [], "hits": 0.0,
		"matches": 0.0, "nodes": 0.0, "real_sec": 0.0, "sim_sec": 0.0, "timeouts": 0.0, "hp_in": [], "hp_out": [],
		"rest_heal": 0.0, "rest_forge": 0.0, "treasure": 0.0, "tokens": 0.0, "zpicks": 0.0, "relic_trig": {}}
	var choices: int = int(_chapters.world_spec().get("choices_per_floor", 2))
	var path: Array[String] = []
	var lost: bool = false
	for f: int in floors + 1:
		w.floor = f
		var map: Array[Dictionary] = []
		if f < floors:
			var offer: Array[String] = WorldMapGen.offer_for_floor(_chapters.region_ids(), seed_value, f, path, choices)
			if offer.is_empty():
				break
			var region: String = offer[0] if _region_pick == "first" else offer[pick_rng.randi_range(0, offer.size() - 1)]
			path.append(region)
			w.region_id = region
			map = _chapters.generate_region_map(region, seed_value, f, CLEARED_BOSSES_MAIN)
		else:
			var fm: Dictionary = _chapters.final_match()
			if fm.is_empty():
				break
			w.region_id = str(fm["region"])
			map = [{"index": 0, "tier": 0, "nodes": [{"kind": ChapterMapGen.KIND_BOSS, "match_id": str(fm["match_id"])}]}]
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
			var node: Dictionary = _world_choose_node(nodes, w, max_hp)
			var kind: String = str(node.get("kind", ""))
			out["nodes"] = float(out["nodes"]) + 1.0
			if kind == ChapterMapGen.KIND_REST:
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
				if not _take_relic(w.relics, policy, hash([seed_value, f, col, int(node["node_index"]), RELIC_SEED_TAG]) & SEED_MASK):
					_apply_policy(w, policy, kind, out)
				w.nodes_cleared += 1
				continue
			var run_config: RunConfig = RunConfig.from_node(_chapters, w.region_id, str(node.get("match_id", "")), kind, seed_value, f)
			var m: Dictionary = _core.prepare_match(run_config.matches[0])
			m["chapter_id"] = w.region_id
			var match_seed: int = hash([seed_value, f, w.region_id, col, int(node["node_index"])]) & SEED_MASK
			_core.invulnerable = false
			_core.time_limit_sec = SimCore.MATCH_TIMEOUT_SEC
			_core.trace = (_trace_n >= 0 and _matches_seen == _trace_n) or (not _trace_id.is_empty() and str(m.get("id", "")) == _trace_id)
			if _core.trace and not _trace_id.is_empty():
				_trace_id = ""
			_matches_seen += 1
			_core.relic_ids = w.relics.duplicate()
			var r: Dictionary = _core.play_match(m, character, w.deck_entries(), w.hp, match_seed, bot_rng)
			out["matches"] = float(out["matches"]) + 1.0
			for rid: Variant in (r["relic_trig"] as Dictionary).keys():
				out["relic_trig"][rid] = int((out["relic_trig"] as Dictionary).get(rid, 0)) + int(r["relic_trig"][rid])
			out["hits"] = float(out["hits"]) + float(r["bhits"])
			out["real_sec"] = float(out["real_sec"]) + float(r["real_sec"])
			out["sim_sec"] = float(out["sim_sec"]) + float(r["sec"])
			if bool(r["timeout"]):
				out["timeouts"] = float(out["timeouts"]) + 1.0
			if not bool(r["won"]):
				lost = true
				out["death_floor"] = f
				out["death_kind"] = "final" if f == floors else kind
				break
			w.hp = minf(float(r["hp_end"]) + maxf(float(r["passive_heal"]), 0.0), max_hp)
			w.nodes_cleared += 1
			if kind == ChapterMapGen.KIND_BOSS:
				w.removal_tokens += int(_reward_config.get("boss_removal_tokens", 1))
			_apply_policy(w, policy, kind, out)
		if lost:
			break
		(out["hp_out"] as Array).append(_hp_ratio(w, max_hp))
		out["floors_cleared"] = f + 1
		if f < floors:
			var before: float = max_hp if w.hp < 0.0 else minf(w.hp, max_hp)
			w.hp = minf(before + maxf(_chapters.floor_heal_ratio(), 0.0) * max_hp, max_hp)
	out["won"] = not lost and int(out["floors_cleared"]) == floors + 1
	out["path"] = path
	out["relics"] = w.relics.duplicate()
	out["relic_n"] = w.relics.size()
	out["luck"] = w.luck(_reward_config)
	out["minutes"] = (float(out["real_sec"]) + _node_overhead * float(out["nodes"])) / 60.0
	out["size"] = w.deck.size()
	var level_sum: int = 0
	for e: Dictionary in w.deck:
		level_sum += int(e["level"])
	out["levels"] = level_sum
	return out


# Story 022 node policy plus Story 031's "take rest when HP < REST_HEAL_BELOW" (rest before treasure then).
func _world_choose_node(nodes: Array[Dictionary], w: WorldRun, max_hp: float) -> Dictionary:
	if _hp_ratio(w, max_hp) < REST_HEAL_BELOW:
		for n: Dictionary in nodes:
			if str(n.get("kind", "")) == ChapterMapGen.KIND_REST:
				return n
	return _bot_choose_node(nodes, w, max_hp)
