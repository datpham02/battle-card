extends SceneTree
## Multi-enemy Phase 1 (docs/design/world-map-v2/MULTI-ENEMY-PHASE1-DESIGN.md section 5): CombatState.units.
## A. one unit = the pre-Phase-1 behaviour; B. units are isolated; C. legacy signals report unit 0 only, new
## signals every unit; D. caps and occupancy; (E, the resolved config, lives in tests/unit/run/formations_config_test).

const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const HALL_ANCHOR: Vector2i = Vector2i(8, 1)
const SQUARE_2X2: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]

var fails: int = 0
var passes: int = 0
var _log: Array = []


func check(ok: bool, label: String, extra: String = "") -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label, "  ", extra)


func _grid(cols: int = 4, rows: int = 3) -> BoardGrid:
	return BoardGrid.new(cols, rows)


func _listen(s: CombatState) -> void:
	_log.clear()
	s.damaged.connect(func(side: int, amount: float) -> void: _log.append(["damaged", side, amount]))
	s.unit_damaged.connect(func(index: int, amount: float) -> void: _log.append(["unit_damaged", index, amount]))
	s.changed.connect(func() -> void: _log.append(["changed"]))
	s.enemy_died.connect(func() -> void: _log.append(["enemy_died"]))
	s.unit_died.connect(func(index: int) -> void: _log.append(["unit_died", index]))
	s.all_required_died.connect(func() -> void: _log.append(["all_required_died"]))
	s.enemy_healed.connect(func(amount: float) -> void: _log.append(["enemy_healed", amount]))
	s.unit_healed.connect(func(index: int, amount: float) -> void: _log.append(["unit_healed", index, amount]))
	s.cell_changed.connect(func(side: int, old: Vector2i, new_cell: Vector2i) -> void: _log.append(["cell_changed", side, old, new_cell]))
	s.unit_cell_changed.connect(func(index: int, old: Vector2i, new_cell: Vector2i) -> void: _log.append(["unit_cell_changed", index, old, new_cell]))


func _names() -> Array:
	var out: Array = []
	for e: Array in _log:
		out.append(e[0])
	return out


func _initialize() -> void:
	_test_a_single_unit()
	_test_b_isolation()
	_test_c_signals()
	_test_d_caps_and_occupancy()
	print("FAILS=%d PASSES=%d" % [fails, passes])
	quit(fails)


# --- A. Regression: one unit --------------------------------------------------------------------------------------

func _test_a_single_unit() -> void:
	var s: CombatState = CombatState.new(_grid(), 150.0, 80.0, Vector2i(1, 1), Vector2i(6, 2))
	check(s.unit_count() == 1 and s.get_unit(0) != null and s.get_unit(1) == null, "A: _init makes exactly one unit")
	check(CombatState.unit_key(0) == E and CombatState.unit_key(2) == 3 and CombatState.unit_index_of(P) == -1 and CombatState.unit_index_of(E) == 0, "A: unit_key(0) == Side.ENEMY, unit_index_of(PLAYER) == -1")
	check(s.enemy_cell == Vector2i(6, 2) and s.enemy_hp == 80.0 and s.enemy_max_hp == 80.0 and s.enemy_footprint == ([Vector2i.ZERO] as Array[Vector2i]), "A: legacy fields read units[0]")
	check(s.get_unit(0).cell == Vector2i(6, 2) and s.get_unit(0).hp == 80.0 and s.get_unit(0).id == "" and s.get_unit(0).required, "A: units[0] holds the values, id '' for a plain match")
	# Proxy writes (the direct writes of pattern_controller / boss_phases / trait_host / demo_args).
	s.enemy_invulnerable_left = 1.5
	s.enemy_hp_floor = 20.0
	s.enemy_hp = 50.0
	s.enemy_max_hp = 90.0
	s.enemy_cell = Vector2i(7, 0)
	var hook_hits: Array = []  # a lambda captures an int by value; an Array is shared
	s.enemy_death_hook_fn = func() -> bool:
		hook_hits.append(1)
		return true
	var u0: EnemyUnit = s.get_unit(0)
	check(u0.invulnerable_left == 1.5 and u0.hp_floor == 20.0 and u0.hp == 50.0 and u0.max_hp == 90.0 and u0.cell == Vector2i(7, 0) and u0.death_hook_fn.is_valid(), "A: legacy setters write units[0]")
	s.damage_enemy(10.0)
	check(s.enemy_hp == 50.0, "A: invulnerable: damage ignored through the proxy value")
	s.enemy_invulnerable_left = 0.0
	s.damage_enemy(100.0)
	check(s.enemy_hp == 20.0 and s.enemy_damage_taken == 30.0, "A: hp floor clamps through the proxy, damage_taken counts the clamped loss")
	s.enemy_hp_floor = 0.0
	s.damage_enemy(100.0)
	check(hook_hits.size() == 1 and s.enemy_hp == CombatState.HOLD_HP and not s.is_enemy_dead(), "A: death hook holds at HOLD_HP")
	s.enemy_death_hook_fn = Callable()
	s.damage_enemy(5.0)
	check(s.is_enemy_dead() and s.is_unit_dead(0) and s.all_required_dead() and not s.any_enemy_alive(), "A: one required unit dead = is_enemy_dead = all_required_dead")
	# Footprint behaviour unchanged (boss_footprint_test covers the rest): a 2x2 on the 6x4 hall.
	var hall: CombatState = CombatState.new(BoardGrid.new(6, 4), 100.0, 100.0)
	check(hall.set_enemy_footprint(SQUARE_2X2) and hall.enemy_cell == HALL_ANCHOR and hall.enemy_footprint_size() == 4, "A: 2x2 footprint on the hall: default anchor (8, 1)")
	check(hall.enemy_footprint_cells() == ([Vector2i(8, 1), Vector2i(9, 1), Vector2i(8, 2), Vector2i(9, 2)] as Array[Vector2i]) and hall.enemy_cast_origin() == Vector2i(8, 1) and hall.enemy_hit_cell([Vector2i(9, 2)]) == Vector2i(9, 2) and hall.footprint_extent() == Vector2i(2, 2), "A: footprint cells / cast origin / hit cell / extent as before")
	check(hall.enemy_fits(Vector2i(10, 2)) and not hall.enemy_fits(Vector2i(11, 0)) and not hall.enemy_fits(Vector2i(5, 1)) and hall.enemy_anchors().size() == 15 and hall.default_enemy_anchor() == HALL_ANCHOR, "A: fits / anchors / default anchor as before")
	check(hall.enemy_in([Vector2i(9, 2)]) and not hall.enemy_in([Vector2i(10, 2)]) and hall.is_enemy_at(Vector2i(8, 2)) and hall.unit_in(E, [Vector2i(8, 1)]) and hall.unit_at(E, Vector2i(9, 1)) and hall.unit_cells(E).size() == 4 and hall.cast_origin(E) == Vector2i(8, 1) and hall.cell_of(E) == HALL_ANCHOR, "A: enemy_in / is_enemy_at / unit_* read unit 0")
	# from_match_params without enemies == _init.
	var fm: CombatState = CombatState.from_match_params(_grid(), 150.0, {"boss_max_hp": 80.0, "id": "wolf"}, Vector2i(1, 1), Vector2i(6, 2))
	check(fm.unit_count() == 1 and fm.enemy_hp == 80.0 and fm.enemy_max_hp == 80.0 and fm.enemy_cell == Vector2i(6, 2) and fm.player_cell == Vector2i(1, 1) and fm.player_hp == 150.0 and fm.get_unit(0).id == "", "A: from_match_params without enemies == _init")
	var fm1: CombatState = CombatState.from_match_params(_grid(), 150.0, {"boss_max_hp": 80.0, "boss_defense": 2.0, "enemies": [{"id": "imp", "template_id": "imp", "max_hp": 80.0, "role": "attacker", "required": true}]})
	check(fm1.unit_count() == 1 and fm1.get_unit(0).id == "imp" and fm1.get_unit(0).role == "attacker" and fm1.get_unit(0).defense == 2.0 and fm1.enemy_hp == 80.0, "A: from_match_params with ONE entry: unit 0 takes id / role / defense, still one unit")


# --- B. Isolation between units -----------------------------------------------------------------------------------

func _two(grid: BoardGrid = _grid(), hp0: float = 100.0, hp1: float = 60.0) -> CombatState:
	var s: CombatState = CombatState.new(grid, 100.0, hp0)
	var i: int = s.add_unit("second", hp1)
	assert(i == 1)
	return s


func _test_b_isolation() -> void:
	var s: CombatState = _two()
	check(s.unit_count() == 2 and s.living_units() == ([0, 1] as Array[int]) and s.get_unit(1).id == "second" and s.get_unit(1).max_hp == 60.0 and s.get_unit(1).hp == 60.0, "B: add_unit appends unit 1 with its own HP")
	check(s.get_unit(1).cell != s.enemy_cell and s.grid.is_enemy_cell(s.get_unit(1).cell), "B: unit 1 spawns on a free enemy cell, not on unit 0 (%s vs %s)" % [s.get_unit(1).cell, s.enemy_cell])
	s.damage_unit(1, 25.0)
	check(s.enemy_hp == 100.0 and s.get_unit(1).hp == 35.0 and s.get_unit(1).damage_taken == 25.0 and s.enemy_damage_taken == 0.0, "B: damage_unit(1) leaves unit 0 untouched")
	s.damage(E, 30.0)
	check(s.enemy_hp == 70.0 and s.get_unit(1).hp == 35.0, "B: damage(ENEMY) hits unit 0 only")
	s.damage_key(CombatState.unit_key(1), 5.0)
	check(s.get_unit(1).hp == 30.0 and s.enemy_hp == 70.0, "B: damage_key(unit_key(1)) hits unit 1 only")
	check(s.heal_unit(1, 100.0) == 30.0 and s.get_unit(1).hp == 60.0 and s.enemy_hp == 70.0, "B: heal_unit(1) clamps to unit 1's max, unit 0 untouched")
	check(s.heal_enemy(5.0) == 5.0 and s.enemy_hp == 75.0 and s.get_unit(1).hp == 60.0, "B: heal_enemy heals unit 0 only")
	# Floors, invulnerability and hooks per unit.
	s.get_unit(1).hp_floor = 50.0
	s.damage_unit(1, 100.0)
	s.damage_unit(0, 100.0)
	check(s.get_unit(1).hp == 50.0 and s.enemy_hp == 0.0 and s.is_unit_dead(0) and not s.is_unit_dead(1), "B: unit 1's hp floor does not protect unit 0")
	var s2: CombatState = _two()
	s2.get_unit(1).invulnerable_left = 2.0
	s2.damage_unit(1, 10.0)
	s2.damage_unit(0, 10.0)
	check(s2.get_unit(1).hp == 60.0 and s2.enemy_hp == 90.0, "B: unit 1 invulnerable, unit 0 not")
	var s3: CombatState = _two()
	var hooks: Array = []
	s3.get_unit(1).death_hook_fn = func() -> bool:
		hooks.append(1)
		return true
	s3.damage_unit(0, 500.0)
	s3.damage_unit(1, 500.0)
	check(hooks == [1] and s3.is_unit_dead(0) and s3.get_unit(1).hp == CombatState.HOLD_HP, "B: unit 1's death hook fires for unit 1 only; unit 0 dies without it")
	# Occupancy.
	var s4: CombatState = _two()
	var c1: Vector2i = s4.get_unit(1).cell
	var c0: Vector2i = s4.enemy_cell
	check(not s4.set_enemy_cell(c1) and s4.enemy_cell == c0, "B: set_enemy_cell onto unit 1's cell refused")
	check(not s4.set_unit_cell(1, c0) and s4.get_unit(1).cell == c1, "B: set_unit_cell(1) onto unit 0's cell refused")
	check(not s4.unit_fits(0, c1) and not s4.unit_fits(1, c0) and s4.unit_fits(0, c0) and s4.unit_fits(1, c1), "B: unit_fits sees the other living unit")
	check(s4.enemies_in([c0]) == ([0] as Array[int]) and s4.enemies_in([c1]) == ([1] as Array[int]) and s4.enemies_in([c0, c1]) == ([0, 1] as Array[int]) and s4.enemies_in([Vector2i(0, 0)]).is_empty(), "B: enemies_in picks the covered units, ascending")
	check(s4.enemy_at(c0) == 0 and s4.enemy_at(c1) == 1 and s4.enemy_at(Vector2i(0, 0)) == -1, "B: enemy_at")
	check(s4.all_enemy_cells() == ([c0, c1] as Array[Vector2i]) and s4.cell_of_key(CombatState.unit_key(1)) == c1 and s4.unit_cells_of_key(CombatState.unit_key(1)) == ([c1] as Array[Vector2i]) and s4.cell_of_key(P) == s4.player_cell, "B: all_enemy_cells / key helpers")
	check(s4.enemy_in([c1]) == false and s4.unit_in(E, [c1]) == false and not s4.is_enemy_at(c1), "B: legacy enemy_in / unit_in / is_enemy_at still mean unit 0 only (Phase 1)")
	s4.damage_unit(1, 999.0)
	check(s4.is_unit_dead(1) and s4.set_enemy_cell(c1) and s4.enemy_cell == c1 and s4.enemies_in([c1]) == ([0] as Array[int]) and s4.enemy_at(c1) == 0 and s4.all_enemy_cells() == ([c1] as Array[Vector2i]) and s4.all_enemy_cells(false).size() == 2, "B: a dead unit frees its cells (enemies_in / enemy_at / all_enemy_cells skip it)")
	var dead_hp: float = s4.get_unit(1).hp
	s4.damage_unit(1, 1.0)
	check(not s4.set_unit_cell(1, Vector2i(7, 0)) and s4.get_unit(1).hp == dead_hp and s4.heal_unit(1, 5.0) == 0.0, "B: a dead unit neither moves, takes damage nor heals")
	# Footprint per unit: unit 1 becomes 2x2 on the hall; unit 0 keeps 1 cell and its anchor.
	var hall: CombatState = _two(BoardGrid.new(6, 4))
	var a0: Vector2i = hall.enemy_cell
	check(hall.set_unit_footprint(1, SQUARE_2X2) and hall.get_unit(1).footprint.size() == 4 and hall.enemy_footprint_size() == 1 and hall.enemy_cell == a0, "B: set_unit_footprint(1) never moves unit 0")
	var fp1: Array[Vector2i] = hall.get_unit(1).footprint_cells()
	check(not fp1.has(a0) and hall.enemies_in(fp1) == ([1] as Array[int]), "B: the 2x2 unit 1 sits clear of unit 0 (%s)" % str(fp1))


# --- C. Signals -----------------------------------------------------------------------------------------------------

func _test_c_signals() -> void:
	var s: CombatState = _two()
	_listen(s)
	s.damage_unit(1, 10.0)
	check(_log == [["unit_damaged", 1, 10.0], ["changed"]], "C: damage on unit 1: unit_damaged(1) + changed, NO damaged(ENEMY)", str(_log))
	_log.clear()
	s.damage_unit(0, 10.0)
	check(_log == [["unit_damaged", 0, 10.0], ["damaged", E, 10.0], ["changed"]], "C: damage on unit 0: unit_damaged, damaged(ENEMY), changed", str(_log))
	_log.clear()
	s.damage_unit(1, 999.0)
	check(_names() == ["unit_damaged", "changed", "unit_died"] and _log[2] == ["unit_died", 1], "C: unit 1 dies: unit_died(1), no enemy_died, no all_required_died while unit 0 lives", str(_log))
	_log.clear()
	s.damage_unit(0, 999.0)
	check(_names() == ["unit_damaged", "damaged", "changed", "unit_died", "enemy_died", "all_required_died"], "C: unit 0 dies last: legacy order damaged -> changed -> enemy_died kept, then all_required_died", str(_names()))
	_log.clear()
	s.damage_unit(0, 1.0)
	s.damage_unit(1, 1.0)
	check(_log.is_empty(), "C: dead units fire nothing (all_required_died once)")
	# Heal order for unit 0 and unit 1.
	var h: CombatState = _two()
	h.damage_unit(0, 20.0)
	h.damage_unit(1, 20.0)
	_listen(h)
	h.heal_unit(1, 5.0)
	check(_log == [["unit_healed", 1, 5.0], ["changed"]], "C: heal unit 1: unit_healed + changed, no enemy_healed", str(_log))
	_log.clear()
	h.heal_enemy(5.0)
	check(_log == [["unit_healed", 0, 5.0], ["changed"], ["enemy_healed", 5.0]], "C: heal unit 0: unit_healed, changed, enemy_healed", str(_log))
	# Cell change.
	var m: CombatState = _two()
	_listen(m)
	var c1: Vector2i = m.get_unit(1).cell
	var free: Vector2i = Vector2i(7, 0) if (c1 != Vector2i(7, 0) and m.enemy_cell != Vector2i(7, 0)) else Vector2i(7, 2)
	check(m.set_unit_cell(1, free) and _log == [["unit_cell_changed", 1, c1, free], ["changed"]], "C: unit 1 moves: unit_cell_changed only", str(_log))
	_log.clear()
	var c0: Vector2i = m.enemy_cell
	check(m.set_enemy_cell(c1) and _log == [["unit_cell_changed", 0, c0, c1], ["cell_changed", E, c0, c1], ["changed"]], "C: unit 0 moves: unit_cell_changed then legacy cell_changed(ENEMY)", str(_log))
	# required = false does not block the victory; the once-only emission across both orders.
	var r: CombatState = _two()
	r.get_unit(1).required = false
	_listen(r)
	r.damage_unit(0, 999.0)
	check(_names().count("all_required_died") == 1 and r.all_required_dead() and r.any_enemy_alive(), "C: a non-required living unit does not block all_required_died")
	_log.clear()
	r.damage_unit(1, 999.0)
	check(_names().count("all_required_died") == 0, "C: all_required_died is not repeated when the optional unit dies")
	# No required unit at all: the fallback is "every unit dead", never true at start.
	var n: CombatState = _two()
	n.get_unit(0).required = false
	n.get_unit(1).required = false
	_listen(n)
	check(not n.all_required_dead(), "C: no required unit: all_required_dead false at start")
	n.damage_unit(0, 999.0)
	check(not n.all_required_dead() and _names().count("all_required_died") == 0, "C: no required unit: one of two dead is not a win")
	n.damage_unit(1, 999.0)
	check(n.all_required_dead() and _names().count("all_required_died") == 1, "C: no required unit: every unit dead fires all_required_died once")
	# Single unit: the same order the locked test expects.
	var one: CombatState = CombatState.new(_grid(), 100.0, 10.0)
	_listen(one)
	one.damage_enemy(50.0)
	check(_names() == ["unit_damaged", "damaged", "changed", "unit_died", "enemy_died", "all_required_died"] and _log[1] == ["damaged", E, 10.0], "C: one unit: damaged -> changed -> enemy_died order kept, payload = the HP that was left", str(_log))


# --- D. Caps and occupancy ------------------------------------------------------------------------------------------

func _test_d_caps_and_occupancy() -> void:
	var s: CombatState = CombatState.new(BoardGrid.new(5, 3), 100.0, 100.0)
	check(s.add_unit("u1", 10.0) == 1 and s.add_unit("u2", 10.0) == 2 and s.add_unit("u3", 10.0) == 3, "D: units 1..3 added")
	var cells_before: Array[Vector2i] = s.all_enemy_cells()
	check(s.add_unit("u4", 10.0) == -1 and s.unit_count() == 4 and s.all_enemy_cells() == cells_before, "D: a 5th unit is refused and nothing moves")
	var distinct: Dictionary = {}
	for c: Vector2i in cells_before:
		distinct[c] = true
	check(distinct.size() == 4, "D: four units stand on four distinct cells (%s)" % str(cells_before))
	# A footprint that fits nowhere: 4 wide on a 3-column half.
	var small: CombatState = CombatState.new(BoardGrid.new(3, 3), 100.0, 100.0)
	var wide: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	var before0: Vector2i = small.enemy_cell
	check(small.add_unit("wide", 10.0, wide) == -1 and small.unit_count() == 1 and small.enemy_cell == before0, "D: add_unit with a footprint that fits nowhere returns -1, unit 0 untouched")
	# A footprint that fits only around the others: 2x2 on a 3x3 half with unit 0 in the centre.
	var sq: CombatState = CombatState.new(BoardGrid.new(3, 3), 100.0, 100.0)
	check(sq.enemy_cell == Vector2i(4, 1) and sq.add_unit("blk", 10.0, SQUARE_2X2) == -1 and sq.unit_count() == 1, "D: a 2x2 cannot fit beside a centred 1-cell unit on 3x3 and nothing moves")
	# 2x2 warden + 1 helper on boss_hall (6x4): the shipped arena shape.
	var lib: ArenaLibrary = ArenaLibrary.load_from_file()
	var hall_grid: BoardGrid = ArenaLibrary.grid_for_spec({"shape": "boss_hall"}, lib, 1)
	check(hall_grid != null and hall_grid.side_cols == 6 and hall_grid.side_rows == 4, "D: boss_hall grid 6x4 from arenas.json")
	var hall: CombatState = CombatState.from_match_params(hall_grid, 200.0, {"boss_max_hp": 900.0, "enemies": [
		{"id": "w", "template_id": "w", "max_hp": 900.0, "footprint": [[0, 0], [1, 0], [0, 1], [1, 1]], "required": true, "role": "disruptor"},
		{"id": "a", "template_id": "a", "max_hp": 30.0, "footprint": [[0, 0]], "required": true, "role": "attacker", "defense": 1.0}]})
	check(hall.unit_count() == 2 and hall.enemy_footprint_size() == 4 and hall.enemy_cell == HALL_ANCHOR and not hall.enemy_footprint_cells().has(hall.get_unit(1).cell), "D: from_match_params: unit 0 takes the entry's 2x2 at the hall anchor, unit 1 added beside it")
	check(hall.set_enemy_footprint(SQUARE_2X2) and hall.enemy_footprint_size() == 4 and hall.enemy_cell == HALL_ANCHOR, "D: PatternController re-setting the same footprint is idempotent")
	check(hall.get_unit(1).max_hp == 30.0 and hall.get_unit(1).defense == 1.0 and hall.get_unit(1).role == "attacker" and hall.get_unit(0).id == "w" and hall.get_unit(0).role == "disruptor", "D: entry numbers land on the right unit")
	check(hall.get_unit(0).cell != hall.get_unit(1).cell and hall.default_unit_anchor(1) != BoardGrid.NO_CELL and hall.unit_anchors(1).size() < hall_grid.enemy_cells().size(), "D: anchors are per unit and exclude the other unit's cells")
	# Anchor independence: moving unit 1 never moves unit 0 and vice versa.
	var a0: Vector2i = hall.enemy_cell
	var target: Vector2i = BoardGrid.NO_CELL
	for c: Vector2i in hall.unit_anchors(1):
		if c != hall.get_unit(1).cell:
			target = c
			break
	check(target != BoardGrid.NO_CELL and hall.set_unit_cell(1, target) and hall.enemy_cell == a0, "D: moving unit 1 leaves unit 0's anchor")
	# A 2x2 entry on a half where it fits nowhere is skipped with a warning, the fight still has unit 0.
	var skip: CombatState = CombatState.from_match_params(BoardGrid.new(3, 3), 100.0, {"boss_max_hp": 50.0, "enemies": [{"id": "x", "max_hp": 50.0}, {"id": "y", "max_hp": 10.0, "footprint": [[0, 0], [1, 0], [0, 1], [1, 1]]}, {"id": "z", "max_hp": 10.0}]})
	check(skip.unit_count() == 2 and skip.get_unit(1).id == "z" and skip.get_unit(1).index == 1, "D: an entry that fits nowhere is skipped; the next entry gets the next index")
