extends SceneTree
## Story 029 (headless): the formation map ("Tran do") — pure FormationMap (cover, fade timing per board
## size, completion only when every real enemy cell is lit at once, holes, refresh, reset) and its
## CombatView wiring (resolved player swings cover hit or miss, interrupted / boss swings never cover,
## completion -> signature ready once + formation_completed + reset, no carry across matches).
## Prints PASS/FAIL lines and FAILS=n. Run: godot --headless --path . -s res://tests/unit/combat/formation_map_test.gd

const BIG_HP: float = 1000000.0
const EPS: float = 0.001
const BASE: float = 5.0
const PER_CELL: float = 0.8

var fails: int = 0
var _cc: CharacterConfig


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _near(a: float, b: float) -> bool:
	return absf(a - b) < EPS


func _config() -> CombatConfig:
	return CombatConfig.from_dictionary({"formation_fade_base_sec": BASE, "formation_fade_per_cell_sec": PER_CELL})


func _map_for(grid: BoardGrid) -> FormationMap:
	var cells: Array[Vector2i] = grid.enemy_cells()
	return FormationMap.new().init(cells, _config().formation_fade_for(cells.size()))


func _initialize() -> void:
	_cc = CharacterConfig.load_from_file()
	_test_config()
	_test_cover_and_holes()
	_test_fade_timing()
	_test_completion()
	await _test_view_cover()
	await _test_view_completion()
	await _test_view_no_carry_and_tick()
	await _test_view_cooldown_timed()
	await _test_view_cooldown_instant_and_sim_time()
	await process_frame
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _test_config() -> void:
	var cfg: CombatConfig = CombatConfig.load_from_file()
	_check("combat.json formation keys", _near(cfg.formation_fade_base_sec, 5.0) and _near(cfg.formation_fade_per_cell_sec, 0.8) and _near(cfg.formation_fade_warn_ratio, 0.25) and _near(cfg.formation_flash_sec, 0.5))
	var bad: CombatConfig = CombatConfig.from_dictionary({"formation_fade_base_sec": -1, "formation_fade_per_cell_sec": -2, "formation_fade_warn_ratio": 3, "formation_flash_sec": -1})
	_check("formation keys clamped", bad.formation_fade_base_sec == 0.0 and bad.formation_fade_per_cell_sec == 0.0 and bad.formation_fade_warn_ratio == 1.0 and bad.formation_flash_sec == 0.0)
	_check("fade_for 3x3 = 12.2", _near(cfg.formation_fade_for(9), 12.2))
	_check("fade_for 4x3 = 14.6", _near(cfg.formation_fade_for(12), 14.6))


func _test_cover_and_holes() -> void:
	# 3x3 half with one hole at side (1, 1): 8 real enemy cells.
	var grid := BoardGrid.new(3, 3, [Vector2i(1, 1)] as Array[Vector2i])
	var map: FormationMap = _map_for(grid)
	_check("holed 3x3: total 8", map.total() == 8)
	_check("starts dark", map.lit_count() == 0 and not map.is_complete())
	var enemy: Array[Vector2i] = grid.enemy_cells()
	var hole: Vector2i = Vector2i(grid.side_cols + 1, 1)
	var player_cell: Vector2i = grid.player_cells()[0]
	map.cover([enemy[0], hole, player_cell, Vector2i(99, 99)] as Array[Vector2i])
	_check("cover lights only real enemy cells", map.lit_count() == 1 and map.is_lit(enemy[0]) and not map.is_lit(hole) and not map.is_lit(player_cell))
	_check("fraction_left 1 when fresh, 0 for dark / foreign", _near(map.fraction_left(enemy[0]), 1.0) and map.fraction_left(enemy[1]) == 0.0 and map.fraction_left(hole) == 0.0)
	_check("lit_cells", map.lit_cells() == ([enemy[0]] as Array[Vector2i]))
	map.tick(map.get_fade_sec() * 0.5)
	_check("fraction_left halves", _near(map.fraction_left(enemy[0]), 0.5))
	map.cover([enemy[0]] as Array[Vector2i])
	_check("re-cover refreshes", _near(map.fraction_left(enemy[0]), 1.0))
	map.cover(enemy)
	_check("all 8 real cells lit -> complete (hole not needed)", map.is_complete() and map.lit_count() == 8)
	map.reset()
	_check("reset darkens all", map.lit_count() == 0 and not map.is_complete())
	var empty: FormationMap = FormationMap.new().init([] as Array[Vector2i], 5.0)
	_check("empty map never complete", not empty.is_complete() and empty.total() == 0)


# Lit for exactly fade_sec: still lit just before, dark at fade_sec.
func _fade_case(label: String, grid: BoardGrid, cells: int, expect_sec: float) -> void:
	var map: FormationMap = _map_for(grid)
	_check("%s: %d real enemy cells" % [label, cells], map.total() == cells, str(map.total()))
	_check("%s: fade_sec %.1f" % [label, expect_sec], _near(map.get_fade_sec(), expect_sec), str(map.get_fade_sec()))
	var cell: Vector2i = grid.enemy_cells()[0]
	map.cover([cell] as Array[Vector2i])
	map.tick(expect_sec - 0.01)
	_check("%s: lit just before fade_sec" % label, map.is_lit(cell))
	map.tick(0.01)
	_check("%s: dark at fade_sec" % label, not map.is_lit(cell) and map.fraction_left(cell) == 0.0)
	map.tick(5.0)
	_check("%s: clamped at 0" % label, map.fraction_left(cell) == 0.0)


func _test_fade_timing() -> void:
	_fade_case("3x3", BoardGrid.new(3, 3), 9, 12.2)
	_fade_case("4x3", BoardGrid.new(4, 3), 12, 14.6)
	# 5x5 ring: the 2x2 centre removed -> 21 cells.
	var ring_holes: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]
	_fade_case("ring", BoardGrid.new(5, 5, ring_holes), 21, 21.8)
	_fade_case("6x6", BoardGrid.new(6, 6), 36, 33.8)


func _test_completion() -> void:
	var grid := BoardGrid.new(3, 3)
	var map: FormationMap = _map_for(grid)
	var cells: Array[Vector2i] = grid.enemy_cells()
	# Cover one cell at a time with a gap long enough that the first ones fade first.
	var gap: float = map.get_fade_sec() / 4.0
	for cell: Vector2i in cells:
		map.cover([cell] as Array[Vector2i])
		map.tick(gap)
	_check("gap in time: early cells faded, not complete", not map.is_complete() and map.lit_count() < map.total(), "%d/%d" % [map.lit_count(), map.total()])
	map.reset()
	for i: int in cells.size() - 1:
		map.cover([cells[i]] as Array[Vector2i])
	_check("all but one lit -> not complete", not map.is_complete() and map.lit_count() == cells.size() - 1)
	map.cover([cells[cells.size() - 1]] as Array[Vector2i])
	_check("last one lit -> complete", map.is_complete())
	map.tick(map.get_fade_sec())
	_check("all faded -> not complete", not map.is_complete() and map.lit_count() == 0)


# --- CombatView wiring ---

func _view(character: Dictionary) -> CombatView:
	var v := CombatView.new()
	v.match_params = {"character": character, "boss_max_hp": BIG_HP, "player_hp": -1.0}
	v.drops_seed = 7
	v.freeze_time = true
	root.add_child(v)
	await process_frame
	v.freeze_time = false
	return v


func _drop(v: CombatView) -> void:
	root.remove_child(v)
	v.free()


# Casts over exactly [param cells] and resolves it (time injected into the arbiter); returns the result.
func _cast(v: CombatView, cells: Array[Vector2i]) -> Dictionary:
	var got: Array[Dictionary] = [{}]
	var cb: Callable = func(side: int, result: Dictionary) -> void:
		if side == CombatState.Side.PLAYER:
			got[0] = result
	v.get_arbiter().swing_resolved.connect(cb)
	v._begin_cut("kiem_khi", cells)
	v.get_arbiter().tick(v.get_cut_actor().get_time_left() + 0.01)
	v.get_arbiter().swing_resolved.disconnect(cb)
	return got[0]


# An enemy cell that is not the boss's cell (a miss when cut alone).
func _empty_enemy_cell(v: CombatView) -> Vector2i:
	for cell: Vector2i in v.get_grid().enemy_cells():
		if cell != v.get_state().enemy_cell:
			return cell
	return BoardGrid.NO_CELL


func _test_view_cover() -> void:
	var v: CombatView = await _view(_cc.get_character("kiem_si"))
	var map: FormationMap = v.get_formation()
	_check("view: map over the enemy half, fade from config", map != null and map.total() == v.get_grid().enemy_cells().size() and _near(map.get_fade_sec(), CombatConfig.load_from_file().formation_fade_for(map.total())))
	var boss_cell: Vector2i = v.get_state().enemy_cell
	var r: Dictionary = _cast(v, [boss_cell] as Array[Vector2i])
	_check("view: resolved hit covers", bool(r.get("hit", false)) and map.is_lit(boss_cell) and map.lit_count() == 1)
	var miss_cell: Vector2i = _empty_enemy_cell(v)
	r = _cast(v, [miss_cell] as Array[Vector2i])
	_check("view: resolved miss covers", not r.is_empty() and not bool(r["hit"]) and map.is_lit(miss_cell) and map.lit_count() == 2)
	# Interrupted / cancelled: the swing never resolves, nothing lit.
	map.reset()
	v._begin_cut("kiem_khi", [miss_cell] as Array[Vector2i])
	v.get_cut_actor().cancel()
	v.get_arbiter().tick(5.0)
	_check("view: cancelled swing covers nothing", map.lit_count() == 0)
	# A two-piece cast arrives as one swing over the union of its pieces.
	var enemy: Array[Vector2i] = v.get_grid().enemy_cells()
	var union: Array[Vector2i] = [enemy[0], enemy[1], enemy[3], enemy[4]]
	_cast(v, union)
	_check("view: joined cast covers its union", map.lit_count() == 4 and map.is_lit(enemy[4]))
	# Boss swings never cover (even when handed enemy-half cells).
	map.reset()
	v._on_swing_resolved(CombatState.Side.ENEMY, {"cells": enemy, "hit": false, "damage": 0.0, "cell": v.get_state().player_cell})
	_check("view: boss swing covers nothing", map.lit_count() == 0 and not v.is_signature_ready())
	_drop(v)


func _test_view_completion() -> void:
	var v: CombatView = await _view(_cc.get_character("kiem_si"))
	var map: FormationMap = v.get_formation()
	var completed: Array[int] = [0]
	v.formation_completed.connect(func() -> void: completed[0] += 1)
	var enemy: Array[Vector2i] = v.get_grid().enemy_cells()
	var half: Array[Vector2i] = enemy.slice(0, enemy.size() / 2)
	_cast(v, half)
	_check("view: partial -> charge lit/total, not ready", _near(v.get_signature_charge(), float(half.size()) / float(map.total())) and not v.is_signature_ready() and completed[0] == 0)
	_cast(v, enemy.slice(enemy.size() / 2))
	_check("view: complete -> ready, signal once, map kept lit (Phần D)", v.is_signature_ready() and completed[0] == 1 and map.is_complete() and v.get_signature_charge() == 1.0)
	_check("view: flash starts at 1", _near(v.get_formation_flash(), 1.0))
	_cast(v, enemy)
	_check("view: completing again while ready -> no second ready", completed[0] == 1 and map.is_complete() and v.is_signature_ready())
	_check("view: activate clears ready", v.activate_signature() and not v.is_signature_ready())
	_check("view: activation resets the map (Phần D)", map.lit_count() == 0)
	# tram is timed: while active, completion does not set ready.
	_cast(v, enemy)
	_check("view: complete while signature active -> nothing", v.is_signature_active() and completed[0] == 1 and not v.is_signature_ready())
	v._tick_signature(100.0)
	v._tick_signature(v.get_signature_cooldown_sec() + 0.01)
	_cast(v, enemy)
	_check("view: after the effect and cooldown end, completion readies again", completed[0] == 2 and v.is_signature_ready() and map.is_complete())
	v.debug_set_signature_charge(0.5)
	_check("view: debug 0.5 -> round(total/2) lit, not ready", map.lit_count() == roundi(0.5 * float(map.total())) and not v.is_signature_ready())
	v.debug_set_signature_charge(1.0)
	_check("view: debug 1.0 -> ready", v.is_signature_ready())
	_drop(v)
	# No signature: no map, charge 0.
	var ch: Dictionary = _cc.get_character("kiem_si")
	ch.erase("signature")
	v = await _view(ch)
	_cast(v, enemy)
	_check("view: no signature -> no map, never ready", v.get_formation() == null and v.get_signature_charge() == 0.0 and not v.is_signature_ready())
	_drop(v)


func _test_view_no_carry_and_tick() -> void:
	var v: CombatView = await _view(_cc.get_character("kiem_si"))
	var cell: Vector2i = _empty_enemy_cell(v)
	_cast(v, [cell] as Array[Vector2i])
	var map: FormationMap = v.get_formation()
	var fade: float = map.get_fade_sec()
	v.freeze_time = false
	v._process(0.05)
	_check("view: _process fades with sim time", _near(map.fraction_left(cell), 1.0 - 0.05 / fade), str(map.fraction_left(cell)))
	v.freeze_time = true
	v._process(0.05)
	_check("view: frozen -> no fade", _near(map.fraction_left(cell), 1.0 - 0.05 / fade))
	_drop(v)
	var v2: CombatView = await _view(_cc.get_character("kiem_si"))
	_check("view: new match -> dark map, not ready (no carry)", v2.get_formation() != map and v2.get_formation().lit_count() == 0 and not v2.is_signature_ready())
	_drop(v2)


# --- Story 029 Phần D: signature cooldown ---

# Halves of the cooldown are exact in binary, so "exactly when it hits 0" is a clean float test.
func _test_view_cooldown_timed() -> void:
	var v: CombatView = await _view(_cc.get_character("kiem_si"))
	var map: FormationMap = v.get_formation()
	var enemy: Array[Vector2i] = v.get_grid().enemy_cells()
	var completed: Array[int] = [0]
	v.formation_completed.connect(func() -> void: completed[0] += 1)
	var sec: float = v.get_signature_cooldown_sec()
	_check("cd: tram cooldown from characters.json (> 0), none left at match start", sec > 0.0 and v.get_signature_cooldown_left() == 0.0, str(sec))
	_cast(v, enemy)
	_check("cd: complete with no cooldown -> ready", v.is_signature_ready() and completed[0] == 1)
	_check("cd: activate -> map reset, timed effect running, cooldown not started yet", v.activate_signature() and map.lit_count() == 0 and v.is_signature_active() and v.get_signature_cooldown_left() == 0.0)
	_cast(v, enemy)
	v._tick_signature(1.0)
	_check("cd: during the effect: map complete but not ready, cooldown still 0", map.is_complete() and not v.is_signature_ready() and v.get_signature_cooldown_left() == 0.0)
	v._tick_signature(v.get_signature_duration())
	_check("cd: effect ended -> cooldown starts full", not v.is_signature_active() and _near(v.get_signature_cooldown_left(), sec) and not v.is_signature_ready(), str(v.get_signature_cooldown_left()))
	v._tick_signature(sec * 0.5)
	_cast(v, enemy)
	_check("cd: map complete during the cooldown -> not ready yet, cells still count", map.is_complete() and not v.is_signature_ready() and completed[0] == 1 and _near(v.get_signature_charge(), 1.0))
	v._tick_signature(sec * 0.5)
	_check("cd: map complete -> ready exactly when the cooldown hits 0 (+ formation_completed)", v.get_signature_cooldown_left() == 0.0 and v.is_signature_ready() and completed[0] == 2)
	map.tick(map.get_fade_sec())
	_check("cd: cells fading after ready do not revoke it", map.lit_count() == 0 and v.is_signature_ready() and v.can_activate_signature())
	# Second use: cooldown over with the map incomplete -> ready only once it completes.
	v.activate_signature()
	v._tick_signature(v.get_signature_duration() + 0.01)
	v._tick_signature(sec)
	_check("cd: cooldown over, map empty -> not ready", v.get_signature_cooldown_left() == 0.0 and not v.is_signature_ready() and completed[0] == 2)
	_cast(v, enemy.slice(0, enemy.size() / 2))
	_check("cd: half lit -> still not ready", not v.is_signature_ready())
	_cast(v, enemy.slice(enemy.size() / 2))
	_check("cd: map completes after the cooldown -> ready at that cover", v.is_signature_ready() and completed[0] == 3)
	# Dev hooks: a cooldown clears ready; debug charge 1.0 is ready regardless of the cooldown.
	v.debug_set_signature_cooldown(9.0)
	_check("cd: debug cooldown 9 -> 9 left, not ready", _near(v.get_signature_cooldown_left(), 9.0) and not v.is_signature_ready())
	v.debug_set_signature_charge(1.0)
	_check("cd: debug charge 1.0 during cooldown -> ready", v.is_signature_ready())
	_drop(v)
	var v2: CombatView = await _view(_cc.get_character("kiem_si"))
	_check("cd: new match -> no cooldown carried, not ready", v2.get_signature_cooldown_left() == 0.0 and not v2.is_signature_ready() and _near(v2.get_signature_cooldown_sec(), sec))
	_drop(v2)


func _test_view_cooldown_instant_and_sim_time() -> void:
	var v: CombatView = await _view(_cc.get_character("phap_su"))
	var ended: Array[int] = [0]
	v.signature_ended.connect(func(_id: String) -> void: ended[0] += 1)
	var sec: float = v.get_signature_cooldown_sec()
	v.debug_set_signature_charge(1.0)
	_check("cd instant: thien_hoa activates", v.activate_signature())
	_check("cd instant: cooldown starts at once (ended fired once), map reset", _near(v.get_signature_cooldown_left(), sec) and ended[0] == 1 and v.get_formation().lit_count() == 0 and not v.is_signature_ready(), str(v.get_signature_cooldown_left()))
	v.freeze_time = false
	v._process(0.05)
	_check("cd: cooldown ticks with sim time in _process", _near(v.get_signature_cooldown_left(), sec - 0.05), str(v.get_signature_cooldown_left()))
	v.freeze_time = true
	v._process(0.05)
	_check("cd: frozen -> cooldown holds", _near(v.get_signature_cooldown_left(), sec - 0.05))
	_drop(v)
	# Without a signature the getters read 0.
	var ch: Dictionary = _cc.get_character("kiem_si")
	ch.erase("signature")
	var v3: CombatView = await _view(ch)
	_check("cd: no signature -> cooldown getters 0", v3.get_signature_cooldown_left() == 0.0 and v3.get_signature_cooldown_sec() == 0.0)
	_drop(v3)
