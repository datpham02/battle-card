extends SceneTree
## Per-boss probe of one chapter (Story 026; replaces the scratch hit_probe / counter_probe /
## formation_probe / sigcd_probe / sigbal_probe family). Every match of the chapter is played on its own
## arena through the shared harness (sim_core.gd: real BossController with pieces, rooted while swinging,
## SwingArbiter, traits, FormationMap, signature cooldowns). Modes (--modes=a,b):
##   piece        cast a pieces.json shape of exactly n cells (any rotation, real anchors) covering the boss's
##                cell, most covered neighbours first, every PROBE_GAP s; no bag, no menu (best case).
##   piece_strike the same, cast the instant the boss has just stepped (fallback after PROBE_WAIT_MAX).
##   pair         two pieces (no shared cell) whose union has exactly n cells.
##   counter      cast only in the step the boss STARTS a swing (it is rooted while swinging).
##   counter_pair the same with a two-piece union.
##   idle         the player never casts and never moves: boss swing starts / hits / damage per minute (TD-022).
##   bot          the full deck_sim bot against each boss (bag, Focus, joins, featured shape, signature):
##                win %, casts and hits per minute, signature uses, first use (Story 029 measures).
## In the cast modes the player is invulnerable and the boss has PROBE_BOSS_HP. See README.md.
## Usage: godot --headless --path . -s res://tools/balance/hit_probe.gd -- --chapter=0 --modes=piece,counter --sizes=1,2,3

const SimCore = preload("res://tools/balance/sim_core.gd")

const CAST_MODES: Array[String] = ["piece", "piece_strike", "pair", "counter", "counter_pair"]
const ALL_MODES: Array[String] = ["piece", "piece_strike", "pair", "counter", "counter_pair", "idle", "bot"]
const PROBE_BOSS_HP: float = 1000000.0
const PROBE_TIMEOUT_SEC: float = 900.0
const PROBE_WAIT_MAX: float = 3.0
const PROBE_GAP_MIN: float = 0.6
const PROBE_GAP_MAX: float = 1.6
## The probe card (no cell minimum; damage is irrelevant against PROBE_BOSS_HP).
const PROBE_CARD: String = "kiem_khi"

var _core: SimCore
var _mode: String = ""
var _n: int = 1
var _trials: int = 40
var _next: float = 0.0
var _wait: float = -1.0
var _casts: int = 0
var _nofit: int = 0
var _busy: int = 0
var _fallback: int = 0


func _init() -> void:
	var t0: int = Time.get_ticks_msec()
	_core = SimCore.new()
	var rest: PackedStringArray = _core.apply_args(OS.get_cmdline_user_args())
	var ci: int = 0
	var modes: Array[String] = ["piece", "counter", "idle"]
	var sizes: Array[int] = [1, 2, 3, 4, 5]
	var only: PackedStringArray = []
	var seeds: int = 3
	var idle_sec: float = 600.0
	var char_id: String = "kiem_si"
	var immortal: bool = false
	for arg: String in rest:
		var v: String = arg.get_slice("=", 1) if arg.contains("=") else ""
		if arg.begins_with("--chapter="):
			ci = int(v)
		elif arg.begins_with("--modes="):
			modes = []
			for x: String in v.split(","):
				if ALL_MODES.has(x.strip_edges()):
					modes.append(x.strip_edges())
				else:
					print("unknown mode '%s' (known: %s)" % [x, str(ALL_MODES)])
		elif arg.begins_with("--sizes="):
			sizes = []
			for x: String in v.split(","):
				sizes.append(clampi(int(x), 1, 10))
		elif arg.begins_with("--trials="):
			_trials = maxi(int(v), 1)
		elif arg.begins_with("--only="):
			only = v.split(",")
		elif arg.begins_with("--seeds="):
			seeds = maxi(int(v), 1)
		elif arg.begins_with("--idle-sec="):
			idle_sec = maxf(float(v), 1.0)
		elif arg.begins_with("--char="):
			char_id = v
		elif arg == "--immortal":
			immortal = true
		elif arg == "--trace":
			_core.trace = true
		else:
			print("unknown flag %s (see tools/balance/README.md)" % arg)
	_core.load_configs()
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	if ci < 0 or ci >= chapters.chapter_count():
		print("chapter %d out of range (chapter_count=%d)" % [ci, chapters.chapter_count()])
		quit(1)
		return
	var chapter_id: String = chapters.chapter_id(ci)
	var character: Dictionary = _core.prepare_character(_core.characters.get_character(char_id))
	var deck_entries: Array = []
	for id: Variant in character.get("starter_deck", []):
		deck_entries.append({"id": str(id), "level": 1})
	print("hit_probe chapter=%d (%s) modes=%s sizes=%s trials=%d seeds=%d idle_sec=%.0f char=%s" % [ci + 1, chapter_id, str(modes), str(sizes), _trials, seeds, idle_sec, char_id])
	print(_core.describe())
	for mode: String in modes:
		_mode = mode
		print("")
		if CAST_MODES.has(mode):
			print("RESULT mode | match | root | reaction | think | boss_step_cd | n | windup | casts | resolved | hits | hit% resolved | hit% cast | nofit | busy | fallback")
		elif mode == "idle":
			print("RESULT IDLE | match | root | seeds | sim_sec | swing_starts | swings_resolved | swing_hits | swing_dmg | trait_hits | total_dmg_taken | starts/min | hits/min | dmg/min")
		else:
			print("RESULT BOT | match | char | seeds | win % | died % | timeout % | mean sec | casts/min | hit% resolved | boss starts/min | boss hits/min | dmg taken/min | interrupts/match | counters/match | focus/match | joins/match | featured/match | sig uses/match | first sig sec | sig dmg/use")
		for id: String in chapters.match_ids(ci):
			if not only.is_empty() and not only.has(id):
				continue
			var rc: RunConfig = RunConfig.from_node(chapters, ci, id, "battle", 1)
			var m: Dictionary = _core.prepare_match(rc.matches[0] as Dictionary)
			m["chapter_id"] = chapter_id
			var bc: BossBrainConfig = BossBrainConfig.from_dictionary(_core.brain_data)
			_core._apply_brain_params(bc, m, CombatConfig.load_from_file().step_cooldown_for(_grid_of(m)))
			if CAST_MODES.has(mode):
				_run_cast_mode(m, id, bc, character, deck_entries, sizes)
			elif mode == "idle":
				_run_idle(m, id, bc, character, deck_entries, seeds, idle_sec)
			else:
				_run_bot(m, id, character, deck_entries, seeds, immortal)
	print("")
	print("hit_probe done, runtime %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


func _grid_of(m: Dictionary) -> BoardGrid:
	var arena: Variant = m.get("arena")
	if typeof(arena) == TYPE_DICTIONARY and not (arena as Dictionary).is_empty():
		var g: BoardGrid = ArenaLibrary.grid_for_spec(arena as Dictionary, _core.arena_library, int(m.get("arena_seed", 0)))
		if g != null:
			return g
	return CombatConfig.load_from_file().grid


func _run_cast_mode(m: Dictionary, id: String, bc: BossBrainConfig, character: Dictionary, deck_entries: Array, sizes: Array[int]) -> void:
	var pm: Dictionary = m.duplicate(true)
	pm["boss_max_hp"] = PROBE_BOSS_HP
	for n: int in sizes:
		_n = n
		_casts = 0
		_nofit = 0
		_busy = 0
		_fallback = 0
		_next = 1.0
		_wait = -1.0
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([id, _mode, n]) & SimCore.SEED_MASK
		_core.invulnerable = true
		_core.time_limit_sec = PROBE_TIMEOUT_SEC
		var r: Dictionary = _core.play_match(pm, character, deck_entries, -1.0, hash([id, _mode, n, "m"]) & SimCore.SEED_MASK, rng, self)
		var resolved: int = int(r["resolved"]) + _nofit
		print("RESULT %s | %s | %s | %.2f | %.2f | %.2f | %d | %.2f | %d | %d | %d | %.0f | %.0f | %d | %d | %d" % [
			_mode, id, str(bc.root_while_swinging), bc.reaction_sec, bc.think_interval_sec, bc.step_cooldown_sec, n,
			_core.cut_config.swing_duration(n), _casts, resolved, int(r["hits"]),
			100.0 * float(r["hits"]) / float(maxi(resolved, 1)), 100.0 * float(r["hits"]) / float(maxi(_casts, 1)), _nofit, _busy, _fallback])


func _run_idle(m: Dictionary, id: String, bc: BossBrainConfig, character: Dictionary, deck_entries: Array, seeds: int, idle_sec: float) -> void:
	var pm: Dictionary = m.duplicate(true)
	pm["boss_max_hp"] = PROBE_BOSS_HP
	var acc: Dictionary = {"sec": 0.0, "starts": 0, "bswings": 0, "shits": 0, "sdmg": 0.0, "bhits": 0, "taken": 0.0}
	for s: int in seeds:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([id, "idle", s]) & SimCore.SEED_MASK
		_core.invulnerable = true
		_core.time_limit_sec = idle_sec
		var r: Dictionary = _core.play_match(pm, character, deck_entries, -1.0, hash([id, "idle", s, "m"]) & SimCore.SEED_MASK, rng, self)
		acc["sec"] = float(acc["sec"]) + float(r["sec"])
		acc["starts"] = int(acc["starts"]) + int(r["bstarts"])
		acc["bswings"] = int(acc["bswings"]) + int(r["bswings"])
		acc["shits"] = int(acc["shits"]) + int(r["shits"])
		acc["bhits"] = int(acc["bhits"]) + int(r["bhits"])
		acc["taken"] = float(acc["taken"]) + float(r["taken"])
		acc["sdmg"] = float(acc["sdmg"]) + float(r["bdmg"])
	var mins: float = maxf(float(acc["sec"]) / 60.0, 0.001)
	print("RESULT IDLE | %s | %s | %d | %.0f | %d | %d | %d | %.1f | %d | %.1f | %.2f | %.2f | %.1f" % [
		id, str(bc.root_while_swinging), seeds, float(acc["sec"]), int(acc["starts"]), int(acc["bswings"]), int(acc["shits"]),
		float(acc["sdmg"]), int(acc["bhits"]) - int(acc["shits"]), float(acc["taken"]), float(acc["starts"]) / mins,
		float(acc["shits"]) / mins, float(acc["taken"]) / mins])


func _run_bot(m: Dictionary, id: String, character: Dictionary, deck_entries: Array, seeds: int, immortal: bool) -> void:
	var keys: Array[String] = ["won", "died", "timeout", "sec", "casts", "resolved", "hits", "bstarts", "bhits", "taken", "interrupts", "counters", "focus_uses", "joins", "featured", "sig_acts", "sig_dmg"]
	var acc: Dictionary = {}
	for k: String in keys:
		acc[k] = 0.0
	var firsts: Array[float] = []
	for s: int in seeds:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([id, "bot", s]) & SimCore.SEED_MASK
		_core.invulnerable = immortal
		_core.time_limit_sec = SimCore.MATCH_TIMEOUT_SEC
		var r: Dictionary = _core.play_match(m, character, deck_entries, -1.0, hash([id, "bot", s, "m"]) & SimCore.SEED_MASK, rng, null)
		acc["won"] = float(acc["won"]) + (1.0 if bool(r["won"]) else 0.0)
		acc["timeout"] = float(acc["timeout"]) + (1.0 if bool(r["timeout"]) else 0.0)
		acc["died"] = float(acc["died"]) + (1.0 if (not bool(r["won"]) and not bool(r["timeout"])) else 0.0)
		for k: String in ["sec", "casts", "resolved", "hits", "bstarts", "bhits", "taken", "interrupts", "counters", "focus_uses", "joins", "featured", "sig_acts", "sig_dmg"]:
			acc[k] = float(acc[k]) + float(r[k])
		if float(r["sig_first"]) >= 0.0:
			firsts.append(float(r["sig_first"]))
	var n: float = float(seeds)
	var mins: float = maxf(float(acc["sec"]) / 60.0, 0.001)
	var first: float = -1.0
	if not firsts.is_empty():
		first = 0.0
		for f: float in firsts:
			first += f
		first /= firsts.size()
	print("RESULT BOT | %s | %s | %d | %.0f | %.0f | %.0f | %.1f | %.1f | %.0f | %.1f | %.2f | %.1f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.1f | %.1f" % [
		id, str(character.get("id", "")), seeds, 100.0 * float(acc["won"]) / n, 100.0 * float(acc["died"]) / n, 100.0 * float(acc["timeout"]) / n,
		float(acc["sec"]) / n, float(acc["casts"]) / mins, 100.0 * float(acc["hits"]) / maxf(float(acc["resolved"]), 1.0),
		float(acc["bstarts"]) / mins, float(acc["bhits"]) / mins, float(acc["taken"]) / mins, float(acc["interrupts"]) / n,
		float(acc["counters"]) / n, float(acc["focus_uses"]) / n, float(acc["joins"]) / n, float(acc["featured"]) / n,
		float(acc["sig_acts"]) / n, first, float(acc["sig_dmg"]) / maxf(float(acc["sig_acts"]), 1.0)])


## Driver hook (sim_core): true once the cast modes reached their trials and the last swing is over.
func probe_done(core: SimCore) -> bool:
	return CAST_MODES.has(_mode) and _casts >= _trials and not core.actor.is_swinging()


## Driver hook (sim_core), called every loop step instead of the bot.
func probe_tick(core: SimCore) -> void:
	if _mode == "idle" or _casts >= _trials:
		return
	var pair: bool = _mode.ends_with("pair")
	if _mode.begins_with("counter"):
		if not core.boss_swing_started_now:
			return
		if core.actor.is_swinging():
			_busy += 1  # still winding up the previous counter: this boss swing goes unanswered
			return
		_cast_at_boss(core, pair)
		return
	if core.actor.is_swinging() or core.t < _next:
		return
	if _mode == "piece_strike":
		var fresh: bool = core.boss_step_at >= 0.0 and core.t - core.boss_step_at <= float(core.bot["strike_fresh"])
		if not fresh:
			if _wait < 0.0:
				_wait = core.t
			if core.t - _wait < PROBE_WAIT_MAX:
				return
			_fallback += 1
		_wait = -1.0
	_cast_at_boss(core, pair)


func _cast_at_boss(core: SimCore, pair: bool) -> void:
	var cells: Array[Vector2i] = core.best_pair_cells(core.state.enemy_cell, _n) if pair else core.best_piece_cells(core.state.enemy_cell, _n)
	if cells.is_empty():
		# No shape (pair) of this size covers the boss's cell on this arena: the player cannot hit.
		_nofit += 1
		_casts += 1
		_next = core.t + core.rng.randf_range(PROBE_GAP_MIN, PROBE_GAP_MAX)
		return
	if core.actor.begin_swing(cells, PROBE_CARD, true, 1):
		_casts += 1
		_next = core.t + core.actor.get_duration() + core.rng.randf_range(PROBE_GAP_MIN, PROBE_GAP_MAX)
	else:
		_next = core.t + 0.2
