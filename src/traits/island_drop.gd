class_name IslandDropTrait
extends BossTrait
## Trait `island_drop` (Story 039 Part C, Long Vuong Gio / storm_dragon): every `interval_sec` one ISLAND of the
## player's half falls: `TileHazards.drop_cells(PLAYER, <island cells>, fall_sec, warn_sec)` (crack warning for
## `warn_sec`, then fallen for `fall_sec`). Never the last standing island: with fewer than 2 islands nothing falls
## (TileHazards.drop_cells enforces the same rule and the leave-a-path rule on its side).
## Islands: the components of TileHazards.islands(PLAYER) (the real, non-fallen cells, 4-neighbour). Because an arena
## joins its islands by 1-cell BRIDGES (which make one connected component), a component is split further here at
## exactly the arena's bridge cells (ArenaValidator.bridge_cells of the full half, fixed for the match): they separate the
## islands and are NEVER dropped, so the surviving
## islands stay joined and the player keeps a way off a falling island. A pure-crumble arena without bridges simply gives
## one island per component. Islands that are already cracking are not picked again.
## The vent / crumble API of TileHazards is reached through has_method (inert on a build without it).
## Params (match trait entry): `interval_sec` (default 11), `fall_sec` (default 4), `warn_sec` (default 1.2),
## `first_delay_sec` (default = interval).
## HUD: [method get_drop_cells], [method get_drop_warn_left].
## Implements: Story 039 (Part C).

## An island began to fall: [param cells] kept by TileHazards.drop_cells.
signal dropped(cells: Array[Vector2i])

const ID: String = "island_drop"
const DEFAULT_INTERVAL_SEC: float = 11.0
const DEFAULT_FALL_SEC: float = 4.0
const DEFAULT_WARN_SEC: float = 1.2
const _SEED_OFFSET: int = 9677
## An island has at least this many cells (Story 039 arenas: every island >= 2 cells).
const _MIN_ISLAND_CELLS: int = 2
## Float slack for timers counted down in fixed steps.
const _EPS: float = 0.000001

var _interval_sec: float = DEFAULT_INTERVAL_SEC
var _fall_sec: float = DEFAULT_FALL_SEC
var _warn_sec: float = DEFAULT_WARN_SEC
var _first_delay_sec: float = DEFAULT_INTERVAL_SEC
var _timer: float = DEFAULT_INTERVAL_SEC
var _drop_cells: Array[Vector2i] = []
var _warn_left: float = 0.0
var _drop_count: int = 0
var _bridges: Array[Vector2i] = []
var _bridges_ready: bool = false


func get_id() -> String:
	return ID


func seed_offset() -> int:
	return _SEED_OFFSET


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_interval_sec = maxf(param_float("interval_sec", DEFAULT_INTERVAL_SEC), 0.1)
	_fall_sec = maxf(param_float("fall_sec", DEFAULT_FALL_SEC), 0.1)
	_warn_sec = maxf(param_float("warn_sec", DEFAULT_WARN_SEC), 0.0)
	_first_delay_sec = maxf(param_float("first_delay_sec", _interval_sec), 0.0)


func on_match_start() -> void:
	_timer = _first_delay_sec
	_drop_cells = []
	_warn_left = 0.0
	_drop_count = 0


func on_tick(step: float) -> void:
	if _warn_left > 0.0:
		_warn_left -= step
		if _warn_left <= _EPS:
			_warn_left = 0.0
			_drop_cells = []
	_timer -= step
	if _timer > _EPS:
		return
	_timer = _interval_sec
	_drop()


## The cells of the island that is about to fall (during its warning), else [].
func get_drop_cells() -> Array[Vector2i]:
	return _drop_cells.duplicate()


## Seconds until the island starts to fall while its warning shows, else 0.
func get_drop_warn_left() -> float:
	return maxf(_warn_left, 0.0)


## Seconds until the next drop.
func get_next_drop_left() -> float:
	return maxf(_timer, 0.0)


## Drops so far this match.
func get_drop_count() -> int:
	return _drop_count


## The islands of the player's half as this trait sees them (see the class doc): an Array of Array[Vector2i], bridge
## cells excluded. Empty without the TileHazards API.
func get_islands() -> Array:
	var hazards: TileHazards = get_context().get("hazards") as TileHazards
	if hazards == null or not hazards.has_method("islands"):
		return []
	var out: Array = []
	for comp_variant: Variant in hazards.call("islands", CombatState.Side.PLAYER) as Array:
		var comp: Array[Vector2i] = []
		for cell: Variant in comp_variant as Array:
			comp.append(cell as Vector2i)
		out.append_array(_split_at_bridges(comp))
	return out


func get_debug() -> Dictionary:
	return {"id": ID, "drops": _drop_count, "warn_left": get_drop_warn_left(), "cells": _drop_cells.size()}


func teardown() -> void:
	_drop_cells = []
	_warn_left = 0.0
	super()


func _drop() -> void:
	var hazards: TileHazards = get_hazards()
	if hazards == null or not hazards.has_method("drop_cells"):
		return
	var islands: Array = get_islands()
	if islands.size() < 2:
		return  # never the last standing island
	var candidates: Array = []
	for island_variant: Variant in islands:
		var island: Array[Vector2i] = []
		for cell: Variant in island_variant as Array:
			island.append(cell as Vector2i)
		if not _is_cracking(hazards, island):
			candidates.append(island)
	# The picked island is not the only one left standing: another (non-cracking or cracking) island must remain.
	if candidates.is_empty():
		return
	var picked: Array[Vector2i] = []
	picked.assign(candidates[rng.randi_range(0, candidates.size() - 1)] as Array)
	var kept: Array[Vector2i] = []
	kept.assign(hazards.call("drop_cells", CombatState.Side.PLAYER, picked, _fall_sec, _warn_sec) as Array)
	if kept.is_empty():
		return
	_drop_count += 1
	_drop_cells = kept
	_warn_left = _warn_sec
	dropped.emit(kept.duplicate())


# True when any cell of [param island] is already cracking (it is not picked twice).
func _is_cracking(hazards: TileHazards, island: Array[Vector2i]) -> bool:
	if not hazards.has_method("is_crumble_warning"):
		return false
	for cell: Vector2i in island:
		if bool(hazards.call("is_crumble_warning", CombatState.Side.PLAYER, cell)):
			return true
	return false


# Splits one connected [param comp] at exactly the ARENA's bridge cells ([method _arena_bridges], fixed for the match, so
# a bridge whose island already fell stays a bridge and is never dropped as part of the next island): the islands are
# the components left. A component without a bridge comes back whole. Bridge cells belong to no island; parts under [constant
# _MIN_ISLAND_CELLS] (a corridor stub) are not islands.
func _split_at_bridges(comp: Array[Vector2i]) -> Array:
	var bridges: Array[Vector2i] = []
	for bridge: Vector2i in _arena_bridges():
		if comp.has(bridge):
			bridges.append(bridge)
	if bridges.is_empty():
		return [comp]
	var rest: Array[Vector2i] = comp.duplicate()
	for bridge: Vector2i in bridges:
		rest.erase(bridge)
	var out: Array = []
	for part: Variant in ArenaValidator.components_of(rest):
		if (part as Array).size() >= _MIN_ISLAND_CELLS:
			var island: Array[Vector2i] = []
			island.assign(part as Array)
			out.append(island)
	return out


# The bridge cells of the player's half of the full arena (ArenaValidator.bridge_cells: 1-cell-wide corridors whose
# removal splits the half), computed once per match from ctx `grid`; [] without a grid.
func _arena_bridges() -> Array[Vector2i]:
	if not _bridges_ready:
		_bridges_ready = true
		var grid: BoardGrid = get_context().get("grid") as BoardGrid
		_bridges = ArenaValidator.bridge_cells(grid, true) if grid != null else ([] as Array[Vector2i])
	return _bridges
