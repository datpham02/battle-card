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
## Tool code only (not game code, not in the test suite). Flags and output: tools/balance/README.md.
## Usage: godot --headless --path . -s res://tools/balance/deck_sim.gd -- --seeds=70 --chapters=0,1,2 --policies=build

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
## Largest min_cells the bot can reach with one cast (two pieces of up to 5 cells; the rune bot used 5).
const CELLS_MAX: int = 5
const AVG_CELLS: float = 3.5
const BURN_EXPECT: float = 0.6
const SEED_MASK: int = 0x7fffffff
const METRICS: Array[String] = [
	"win", "cols", "hits_won", "hits_all", "dmg_hit_pct", "hp_win", "rest_heal", "rest_forge", "treasure",
	"tokens", "size", "levels", "sec", "timeouts", "matches", "taken", "dealt", "sig_acts", "bswings",
	"casts", "resolved", "phits", "focus", "joins", "featured", "counters", "interrupts",
]
const RUN_SUMS: Array[String] = [
	"rest_heal", "rest_forge", "treasure", "tokens", "size", "levels", "sec", "timeouts", "matches", "taken",
	"dealt", "sig_acts", "bswings", "casts", "resolved", "phits", "focus", "joins", "featured", "counters", "interrupts",
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
		elif arg.begins_with("--trace="):
			if v.is_valid_int():
				_trace_n = int(v)
			else:
				_trace_id = v
		else:
			print("unknown flag %s (see tools/balance/README.md)" % arg)
	_core.load_configs()
	_chapters = ChaptersConfig.load_from_file()
	_reward_config = RewardRoller.load_config()
	_max_level = int(_reward_config["max_card_level"])
	_min_deck_size = int(_reward_config["min_deck_size"])
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
	var lost: bool = false
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
		var r: Dictionary = _core.play_match(m, character, session.deck_entries(), session.hp, match_seed, bot_rng)
		out["matches"] = float(out["matches"]) + 1.0
		out["hits"] = int(out["hits"]) + int(r["bhits"])
		for pair: Array in [["taken", "taken"], ["dealt", "dealt"], ["sec", "sec"], ["sig_acts", "sig_acts"], ["bswings", "bswings"],
				["casts", "casts"], ["resolved", "resolved"], ["phits", "hits"], ["focus", "focus_uses"], ["joins", "joins"],
				["featured", "featured"], ["counters", "counters"], ["interrupts", "interrupts"]]:
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
		if bool(done.get("run_won", false)):
			break
	out["won"] = session.is_run_won() and not lost
	out["cols"] = session.cleared_nodes.size()
	out["hp_end"] = (max_hp if session.hp < 0.0 else session.hp) if bool(out["won"]) else 0.0
	out["sec"] = float(out["sec"]) / maxf(float(out["matches"]), 1.0)
	out["size"] = session.deck.size()
	var level_sum: int = 0
	for e: Dictionary in session.deck:
		level_sum += int(e["level"])
	out["levels"] = level_sum
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


func _hp_ratio(session: RunSession, max_hp: float) -> float:
	if session.hp < 0.0:
		return 1.0
	return clampf(session.hp / max_hp, 0.0, 1.0)


func _count_effect(session: RunSession, effect: String) -> int:
	var n: int = 0
	for e: Dictionary in session.deck:
		if str(_core.cards.get_skill(str(e["id"])).get("effect", "")) == effect:
			n += 1
	return n


func _bot_choose_node(nodes: Array[Dictionary], session: RunSession, max_hp: float) -> Dictionary:
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
func _forge_index(session: RunSession) -> int:
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


func _apply_policy(session: RunSession, policy: String, kind: String, out: Dictionary) -> void:
	var info: Dictionary = RewardRoller.reward_for_node(kind, _reward_config)
	var offers: int = int(info.get("offers", 0))
	if offers <= 0:
		return
	var cfg: Dictionary = _reward_config.duplicate(true)
	cfg["offer_count"] = offers
	var reward_seed: int = hash([session.run_seed, session.chapter_index, session.column, session.cleared_nodes.size()]) & SEED_MASK
	var levels: Dictionary = session.deck_levels()
	var offer: Array[String] = RewardRoller.roll(_core.cards, cfg, reward_seed, [], levels, session.luck(cfg), str(info.get("min_rarity", "common")))
	if policy == "always_skip" or offer.is_empty():
		return
	var pick: String = _pick_upgrade(offer, levels)
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


func _pick_keyword(offer: Array[String], session: RunSession) -> String:
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


func _lowest_value_index(session: RunSession) -> int:
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
