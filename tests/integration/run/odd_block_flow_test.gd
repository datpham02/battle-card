extends SceneTree
## Story 041 Part F integration: odd blocks ("Khoi La") through FieldDrops (fixed seeds: chance 1 = only odd after the
## start piece, chance 0 = the classic sequence unchanged, the share at the shipped chance), a real CombatView match
## where the BOSS picks up and casts an odd piece (damage = per-cell x cells, windup = base + per-cell x cells), an
## odd + classic join that matches the featured shape, and the piece deck (weights / ink / remove) never seeing an
## odd id. Headless, deterministic. Prints PASS/FAIL lines and FAILS=N.

const DT: float = 0.05
const BOSS_SIM_LIMIT_SEC: float = 150.0
const BIG_HP: float = 1.0e9
const DROPS_SEED: int = 7
const SPAWN_TICKS: int = 4000
const SHARE_TICKS: int = 12000

var fails: int = 0
var lib: PieceLibrary
var arenas: ArenaLibrary


func ck(name: String, cond: bool, extra: String = "") -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name + ("" if extra.is_empty() else " " + extra))


func _initialize() -> void:
	lib = PieceLibrary.load_from_file()
	arenas = ArenaLibrary.load_from_file()
	_test_chance_one()
	_test_chance_zero_unchanged()
	_test_shipped_share()
	_test_featured_join()
	_test_piece_deck_never_odd()
	await _test_boss_casts_odd()
	print("FAILS=%d" % fails)
	quit(fails)


func _grid(shape_id: String) -> BoardGrid:
	return ArenaValidator.build_grid(arenas.get_shape(shape_id))


# Fast pacing so many spawns happen in few ticks; points rot fast so the field never stays full.
func _config(odd: OddBlockConfig) -> FieldDropsConfig:
	var c := FieldDropsConfig.new()
	c.initial_delay_sec = 0.0
	c.piece_spawn_interval_sec = 0.01
	c.piece_max_on_field = 3
	c.piece_freshness_sec = 0.05
	c.start_pieces = 1
	if odd != null:
		c.odd = odd
	return c


func _file_odd(overrides: Dictionary = {}) -> OddBlockConfig:
	return FieldDropsConfig.load_from_file().odd.with_overrides(overrides)


# Spawn log "shape/rotation/cell" of start pieces + [param ticks] ticks.
func _run(drops: FieldDrops, grid: BoardGrid, ticks: int) -> Array[String]:
	var log: Array[String] = []
	drops.point_spawned.connect(func(p: FieldPoint) -> void:
		log.append("%s/%d/%s" % [p.piece.shape_id, p.piece.rotation, p.cell]))
	drops.place_start_pieces(grid.default_player_cell())
	for _i: int in ticks:
		drops.tick(0.02, grid.default_player_cell(), 1)
	return log


func _drops(grid: BoardGrid, config: FieldDropsConfig) -> FieldDrops:
	var d := FieldDrops.new(config, grid.player_cells(), 11)
	d.enable_pieces(lib, "", grid, 11)
	return d


func _test_chance_one() -> void:
	var grid: BoardGrid = _grid("pillars")
	var drops: FieldDrops = _drops(grid, _config(_file_odd({"chance": 1.0})))
	var log: Array[String] = _run(drops, grid, SPAWN_TICKS)
	var classic_ticks: int = 0
	for i: int in range(1, log.size()):
		if not log[i].begins_with(Piece.ODD_PREFIX):
			classic_ticks += 1
	# A classic tick spawn only happens as a counted fallback (all max_tries generations failed), and rarely.
	var rest_odd: bool = log.size() > 20 and classic_ticks == drops.get_odd_fallbacks() and classic_ticks * 100 < log.size()
	ck("chance 1: the start piece is classic", not log.is_empty() and not log[0].begins_with(Piece.ODD_PREFIX), log[0] if not log.is_empty() else "")
	ck("chance 1: every tick spawn is odd (or a counted fallback, < 1 %)", rest_odd, "%d spawns, %d classic" % [log.size(), classic_ticks])
	ck("chance 1: counters (total = 1 start + odd + fallbacks)",
		drops.get_total_spawned() == log.size() and drops.get_odd_spawned() + drops.get_odd_fallbacks() == log.size() - 1,
		"total %d odd %d fallbacks %d" % [drops.get_total_spawned(), drops.get_odd_spawned(), drops.get_odd_fallbacks()])
	ck("chance 1: odd enabled, max size 7 on a 21-cell half", drops.is_odd_enabled() and drops.get_odd_max_size() == 7)


func _test_chance_zero_unchanged() -> void:
	var grid: BoardGrid = _grid("cross_wide")
	var zero: FieldDrops = _drops(grid, _config(_file_odd({"chance": 0.0})))
	var none: FieldDrops = _drops(grid, _config(null)) # FieldDropsConfig.new(): no odd block at all
	var log_zero: Array[String] = _run(zero, grid, SPAWN_TICKS)
	var log_none: Array[String] = _run(none, grid, SPAWN_TICKS)
	ck("chance 0: same classic sequence as no odd block", log_zero == log_none and log_zero.size() > 20, "%d spawns" % log_zero.size())
	ck("chance 0: no odd spawned, odd off", zero.get_odd_spawned() == 0 and not zero.is_odd_enabled() and zero.get_odd_fallbacks() == 0)


func _test_shipped_share() -> void:
	var grid: BoardGrid = _grid("square")
	var cfg: OddBlockConfig = _file_odd()
	var drops: FieldDrops = _drops(grid, _config(cfg))
	var log: Array[String] = _run(drops, grid, SHARE_TICKS)
	var share: float = float(drops.get_odd_spawned()) / float(maxi(drops.get_total_spawned() - 1, 1))
	var sizes_ok: bool = true
	for p: FieldPoint in drops.get_points():
		if p.piece != null and p.piece.is_odd():
			sizes_ok = sizes_ok and p.piece.cell_count() == 5
	ck("shipped chance %.2f on square: odd share of tick spawns near it" % cfg.chance, absf(share - cfg.chance) < 0.08,
		"share %.3f of %d (fallbacks %d)" % [share, drops.get_total_spawned() - 1, drops.get_odd_fallbacks()])
	ck("square: odd blocks are 5 cells", sizes_ok and drops.get_odd_max_size() == 5)
	var odd_logged: int = 0
	for entry: String in log:
		if entry.begins_with(Piece.ODD_PREFIX):
			odd_logged += 1
	ck("odd counter equals odd spawns seen", odd_logged == drops.get_odd_spawned())


func _test_featured_join() -> void:
	# A 6-cell featured shape (cross_wide): find a cell whose removal leaves a 5-cell NON-library shape (an odd
	# block), then join that odd piece with a classic mono on the removed cell.
	var featured: Array[Vector2i] = ArenaLibrary.parse_featured_cells(arenas.get_shape("cross_wide")["featured_shape"])
	var odd_cells: Array[Vector2i] = []
	var mono_cell: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in featured:
		var rest: Array[Vector2i] = featured.duplicate()
		rest.erase(cell)
		if PieceLibrary._is_connected(rest) and not lib.has_equivalent_shape(rest):
			odd_cells = rest
			mono_cell = cell
			break
	ck("featured split into odd (5) + mono found", odd_cells.size() == 5, str(odd_cells))
	if odd_cells.size() != 5:
		return
	var odd: Piece = Piece.make(Piece.ODD_PREFIX + Piece.canonical_key(odd_cells), odd_cells)
	var anchor := Vector2i(10, 3) # anywhere: featured matching is translation invariant
	var placed_odd: Array[Vector2i] = []
	for c: Vector2i in odd_cells:
		placed_odd.append(c + anchor)
	var plan := CastPlan.new().init(2, 7)
	var ok_a: bool = plan.add_piece(0, odd, placed_odd)
	var ok_b: bool = plan.add_piece(1, lib.make_piece("mono"), [mono_cell + anchor] as Array[Vector2i])
	ck("odd + mono join (touching, 6 cells)", ok_a and ok_b and plan.total_cells() == 6)
	ck("the joined union passes the featured check", plan.is_featured(featured))
	var plan2 := CastPlan.new().init(2, 7)
	plan2.add_piece(0, odd, placed_odd)
	ck("the odd piece alone is not featured (one piece)", not plan2.is_featured(featured))


func _test_piece_deck_never_odd() -> void:
	var cfg: PieceDeckConfig = PieceDeckConfig.load_from_file()
	var state: Dictionary = PieceDeck.initial(lib)
	var any_odd: bool = false
	for grid_id: String in ["square", "pillars", "twin_isles"]:
		var w: Dictionary = PieceDeck.weights_for_match(state, lib, "", _grid(grid_id), cfg)
		for id: Variant in (w["weights"] as Dictionary).keys():
			any_odd = any_odd or str(id).begins_with(Piece.ODD_PREFIX)
	ck("weights_for_match never holds an odd id", not any_odd)
	var offer_odd: bool = false
	for s: int in 30:
		for id: String in PieceDeck.roll_ink_offer(state, lib, cfg, s):
			offer_odd = offer_odd or id.begins_with(Piece.ODD_PREFIX)
	ck("ink offers never hold an odd id", not offer_odd)
	var odd_id: String = OddBlock.generate(lib, _grid("pillars"), true, _file_odd(), _rng(1)).shape_id
	ck("an odd id cannot be inked or removed", not PieceDeck.can_ink(state, odd_id, lib, cfg)
		and not bool(PieceDeck.can_remove(state, odd_id, lib, cfg)["ok"]) and not lib.has_shape(odd_id))


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func _test_boss_casts_odd() -> void:
	var v := CombatView.new()
	v.match_params = {"boss_max_hp": BIG_HP, "player_hp": -1.0, "odd_blocks": {"chance": 1.0}}
	v.drops_seed = DROPS_SEED
	v.freeze_time = true
	root.add_child(v)
	await process_frame
	v.set_process(false)
	v.freeze_time = false
	var boss: BossController = v.get_boss()
	var state: CombatState = v.get_state()
	ck("match key odd_blocks reaches both sides", v.get_drops().is_odd_enabled() and boss.get_drops().is_odd_enabled()
		and is_equal_approx(v.get_drops_config().odd.chance, 1.0))
	var casts: Array = [] # {labels, cells, skill, duration}
	var durations: Array[float] = [] # swing_started fires before cut_started
	boss.get_actor().swing_started.connect(func(_c: Array[Vector2i], _k: String, duration: float) -> void:
		durations.append(duration))
	boss.cut_started.connect(func(labels: Array[String], cells: Array[Vector2i], skill: String) -> void:
		casts.append({"labels": labels.duplicate(), "cells": cells.size(), "skill": skill,
			"duration": durations[durations.size() - 1] if not durations.is_empty() else -1.0}))
	var resolved: Array = []
	v.get_arbiter().swing_resolved.connect(func(side: int, result: Dictionary) -> void:
		if side == CombatState.Side.ENEMY:
			resolved.append(result.duplicate()))
	var odd_cast: Dictionary = {}
	var odd_result: Dictionary = {}
	var t: float = 0.0
	while t < BOSS_SIM_LIMIT_SEC and odd_result.is_empty():
		state.set_player_hp(state.player_max_hp)
		var before: int = resolved.size()
		v._process(DT)
		t += DT
		if odd_cast.is_empty():
			for cast: Dictionary in casts:
				for label: String in cast["labels"]:
					if label.begins_with(Piece.ODD_PREFIX):
						odd_cast = cast
		elif resolved.size() > before:
			odd_result = resolved[resolved.size() - 1]
	print("INFO boss odd spawned %d of %d, fallbacks %d; casts %d" % [boss.get_drops().get_odd_spawned(),
		boss.get_drops().get_total_spawned(), boss.get_drops().get_odd_fallbacks(), casts.size()])
	ck("boss half received odd pieces", boss.get_drops().get_odd_spawned() > 0)
	ck("boss brain started an odd cast within %.0f sim s" % BOSS_SIM_LIMIT_SEC, not odd_cast.is_empty(), str(odd_cast))
	ck("the odd cast resolved", not odd_result.is_empty(), str(odd_result))
	if odd_cast.is_empty() or odd_result.is_empty():
		v.queue_free()
		return
	var cells: int = (odd_result["cells"] as Array).size()
	ck("odd cast covers >= 5 cells", cells >= 5 and int(odd_cast["cells"]) == cells, "%d cells" % cells)
	var expected_dur: float = v.get_cut_config().swing_duration(cells) * boss.get_actor().duration_mult
	ck("windup = base + per-cell x cells", odd_cast.has("duration") and absf(float(odd_cast["duration"]) - expected_dur) < 0.01,
		"%s vs %.2f" % [odd_cast.get("duration", "?"), expected_dur])
	if bool(odd_result.get("hit", false)) and not bool(odd_result.get("pin_bonus", false)) and not bool(odd_result.get("fragile_hit", false)) \
			and not bool(odd_result.get("executed", false)):
		var skill: Dictionary = v.get_skill_config().get_skill(str(odd_result["skill_id"]))
		var cut_cfg: CutConfig = v.get_cut_config()
		var per_cell: float = float(skill.get("damage_per_cell", cut_cfg.base_damage_per_cell * float(skill.get("damage_multiplier", 1.0))))
		ck("odd hit damage = per-cell x cells", absf(float(odd_result["damage"]) - per_cell * cells) < 0.001,
			"%.2f vs %.2f x %d" % [float(odd_result["damage"]), per_cell, cells])
	else:
		print("INFO odd cast missed or was modified, damage not compared: %s" % odd_result)
	v.queue_free()
