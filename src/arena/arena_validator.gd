class_name ArenaValidator
extends RefCounted
## Pure checks on an arena spec {side_cols, side_rows, missing_cells (side coordinates, as
## [col, row] pairs or Vector2i)}. Used for the shipped library and for generated variants.
## Rules (from arenas.json "rules"): min_cells_per_side. A spec passes when
##  - the size is valid and every hole is inside the side rectangle,
##  - each half has at least min_cells_per_side real cells,
##  - each half is 4-connected,
##  - both default cells exist,
##  - the halves mirror each other across the divider,
##  - every real cell of each half can be covered by at least one placement of a piece from
##    pieces.json, and at least one shape of >= MIN_BIG_PIECE_CELLS cells fits on each half,
##  - from each half's default cell, EVERY single placement of a piece of at most
##    ESCAPE_MAX_PIECE_CELLS cells on that half leaves at least one uncovered cell reachable in
##    1 step (EscapeAnalysis). Bigger pieces are skipped on purpose: a 3-5 cell piece can seal the
##    whole neighbourhood of a default cell with 2-4 neighbours on shipped arenas too (ring,
##    staircase, every open board for the plus), so it says nothing about a broken arena. With
##    1-2 cells the check means "the default cell is not a dead end".
## Implements: Story 014 (arena validator); piece-placement checks: Story 026 (replaced the
## perimeter-label cut checks).

## Used only when [param rules] lacks the key (arenas.json normally supplies it).
const FALLBACK_MIN_CELLS: int = 6
## A half must fit at least one piece of this many cells (a bigger shape than the mono/bar2).
const MIN_BIG_PIECE_CELLS: int = 3
## Largest piece the escape check tries (see the class doc).
const ESCAPE_MAX_PIECE_CELLS: int = 2
## Steps the escape check allows (a single-point cut is judged with one step).
const ESCAPE_STEPS: int = 1
const _DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## Library loaded on first use when [method validate] gets no [param pieces] (pieces.json).
static var _default_pieces: PieceLibrary = null


## Returns {ok: bool, reasons: Array[String]}; reasons lists every failing check. [param pieces]
## is the shape library the placement checks use (null = pieces.json, loaded once and cached).
static func validate(spec: Dictionary, rules: Dictionary, pieces: PieceLibrary = null) -> Dictionary:
	var reasons: Array[String] = []
	var side_cols: int = int(spec.get("side_cols", 0))
	var side_rows: int = int(spec.get("side_rows", 0))
	if side_cols < 1 or side_rows < 1:
		reasons.append("size %dx%d is invalid" % [side_cols, side_rows])
		return {"ok": false, "reasons": reasons}
	var holes: Array[Vector2i] = parse_cells(spec.get("missing_cells"))
	for hole: Vector2i in holes:
		if hole.x < 0 or hole.x >= side_cols or hole.y < 0 or hole.y >= side_rows:
			reasons.append("hole %s is outside the %dx%d side" % [hole, side_cols, side_rows])
	if holes.size() >= side_cols * side_rows:
		reasons.append("every cell is missing")
	if not reasons.is_empty():
		return {"ok": false, "reasons": reasons}
	var grid := BoardGrid.new(side_cols, side_rows, holes)
	var min_cells: int = int(rules.get("min_cells_per_side", FALLBACK_MIN_CELLS))
	var player_cells: Array[Vector2i] = grid.player_cells()
	var enemy_cells: Array[Vector2i] = grid.enemy_cells()
	if player_cells.size() < min_cells:
		reasons.append("only %d cells per side (min %d)" % [player_cells.size(), min_cells])
	if not _is_connected(grid, player_cells, true):
		reasons.append("player half is not connected")
	if not _is_connected(grid, enemy_cells, false):
		reasons.append("boss half is not connected")
	var player_default: Vector2i = grid.default_player_cell()
	var enemy_default: Vector2i = grid.default_enemy_cell()
	if player_default == BoardGrid.NO_CELL or not grid.is_player_cell(player_default):
		reasons.append("no default player cell")
	if enemy_default == BoardGrid.NO_CELL or not grid.is_enemy_cell(enemy_default):
		reasons.append("no default boss cell")
	if not _is_symmetric(grid, player_cells, enemy_cells):
		reasons.append("halves are not mirror images")
	var library: PieceLibrary = pieces if pieces != null else _library()
	var placements_player: Array[Array] = _placements(grid, library, false)
	var placements_enemy: Array[Array] = _placements(grid, library, true)
	_check_coverage(player_cells, placements_player, library, "player", reasons)
	_check_coverage(enemy_cells, placements_enemy, library, "boss", reasons)
	if player_default != BoardGrid.NO_CELL:
		_check_escapes(grid, player_default, true, placements_player, reasons)
	if enemy_default != BoardGrid.NO_CELL:
		_check_escapes(grid, enemy_default, false, placements_enemy, reasons)
	return {"ok": reasons.is_empty(), "reasons": reasons}


## Parses missing_cells ([[col,row], ...] or Vector2i entries); bad entries are skipped.
static func parse_cells(raw: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if typeof(raw) != TYPE_ARRAY:
		return cells
	for item: Variant in raw as Array:
		if typeof(item) == TYPE_VECTOR2I:
			cells.append(item as Vector2i)
		elif typeof(item) == TYPE_ARRAY and (item as Array).size() == 2:
			cells.append(Vector2i(int((item as Array)[0]), int((item as Array)[1])))
	return cells


## Builds the BoardGrid of a spec (no validation; BoardGrid clamps/ignores nonsense).
static func build_grid(spec: Dictionary) -> BoardGrid:
	return BoardGrid.new(
		int(spec.get("side_cols", 1)), int(spec.get("side_rows", 1)), parse_cells(spec.get("missing_cells"))
	)


static func _is_connected(grid: BoardGrid, cells: Array[Vector2i], player_half: bool) -> bool:
	if cells.is_empty():
		return false
	var seen: Dictionary = {cells[0]: true}
	var queue: Array[Vector2i] = [cells[0]]
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for dir: Vector2i in _DIRECTIONS:
			var next: Vector2i = cell + dir
			var on_half: bool = grid.is_player_cell(next) if player_half else grid.is_enemy_cell(next)
			if on_half and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen.size() == cells.size()


static func _is_symmetric(grid: BoardGrid, player_cells: Array[Vector2i], enemy_cells: Array[Vector2i]) -> bool:
	if player_cells.size() != enemy_cells.size():
		return false
	for cell: Vector2i in player_cells:
		if not grid.is_enemy_cell(Vector2i(grid.total_cols - 1 - cell.x, cell.y)):
			return false
	return true


static func _library() -> PieceLibrary:
	if _default_pieces == null:
		_default_pieces = PieceLibrary.load_from_file()
	return _default_pieces


## Every placement of every shape (all 4 rotations) on one half: an array of
## {cells: Array[Vector2i], size: int}. Duplicate cell sets (symmetric shapes) are kept once.
static func _placements(grid: BoardGrid, library: PieceLibrary, boss_half: bool) -> Array[Array]:
	var out: Array[Array] = []
	var seen: Dictionary = {}
	for id: String in library.shape_ids():
		var base: Piece = library.make_piece(id)
		for turns: int in 4:
			var piece: Piece = base.rotated(turns)
			for anchor: Vector2i in PiecePlacement.valid_anchors(grid, piece, boss_half):
				var cells: Array[Vector2i] = piece.cells_at(anchor)
				var key: String = str(cells)
				if not seen.has(key):
					seen[key] = true
					out.append([cells, piece.cell_count()])
	return out


static func _check_coverage(
	cells: Array[Vector2i], placements: Array[Array], library: PieceLibrary, half_name: String, reasons: Array[String]
) -> void:
	var covered: Dictionary = {}
	var has_big: bool = false
	for entry: Array in placements:
		for cell: Vector2i in entry[0] as Array[Vector2i]:
			covered[cell] = true
		if int(entry[1]) >= MIN_BIG_PIECE_CELLS:
			has_big = true
	for cell: Vector2i in cells:
		if not covered.has(cell):
			reasons.append("no piece placement covers the %s cell %s" % [half_name, cell])
	if not has_big:
		reasons.append("no piece of %d+ cells fits on the %s half" % [MIN_BIG_PIECE_CELLS, half_name])


static func _check_escapes(
	grid: BoardGrid, from_cell: Vector2i, player_half: bool, placements: Array[Array], reasons: Array[String]
) -> void:
	var half_name: String = "player" if player_half else "boss"
	for entry: Array in placements:
		if int(entry[1]) > ESCAPE_MAX_PIECE_CELLS:
			continue
		var covered: Array[Vector2i] = entry[0]
		var escapes: Array[Vector2i] = EscapeAnalysis.escape_cells(grid, from_cell, ESCAPE_STEPS, player_half, covered)
		if escapes.is_empty():
			reasons.append("no escape from the %s default cell %s against the piece at %s" % [half_name, from_cell, covered])
			return
