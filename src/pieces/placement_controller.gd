class_name PlacementController
extends RefCounted
## Pure logic of the PLACING mode (Story 024 part B): one piece is picked from a bag slot, a ghost
## of it follows the pointer over the ENEMY half and snaps to a valid placement
## ([PiecePlacement.snap]); it can be rotated 90 degrees; confirming hands back the ghost's cells.
## No nodes, no input: CombatView / the input views feed it cells and read its state.
## States: IDLE (no piece) and PLACING. Rotating keeps the anchor when it is still valid for the
## new rotation, else re-snaps to the last aimed cell.
## Implements: Story 024 (Part B).

enum State { IDLE, PLACING }

var _grid: BoardGrid
var _state: State = State.IDLE
var _slot: int = -1
var _piece: Piece = null
## Last cell the pointer aimed at (NO_CELL = pointer is not over the enemy half).
var _target: Vector2i = BoardGrid.NO_CELL
var _anchor: Vector2i = BoardGrid.NO_CELL
var _cells: Array[Vector2i] = []
## Story 028: cells the ghost must not cover (the first piece of a cast while the second one is placed).
var _blocked: Array[Vector2i] = []
## Story 039 (shroud): Callable() -> bool; true = the HIT FORECAST (green / red ghost, the "hit" / "miss" tag) is hidden.
## TraitHost wires it to hit_forecast_blocked(). Invalid = never blocked. [method hits] stays the pure geometry.
var forecast_blocked_fn: Callable = Callable()


func _init(grid: BoardGrid) -> void:
	_grid = grid


## Enters PLACING with [param piece] taken from bag slot [param slot]. Returns false (state
## unchanged) for a null, rotten or unplaceable piece. The ghost starts on the first valid anchor
## nearest the centre of the enemy half. Story 028: [param blocked] lists cells the ghost may never
## cover (the plan's first piece when a second one is placed); it is forgotten by [method cancel].
func begin(slot: int, piece: Piece, blocked: Array[Vector2i] = []) -> bool:
	if piece == null or not piece.placeable():
		return false
	_blocked = blocked.duplicate()
	_state = State.PLACING
	_slot = slot
	_piece = piece
	_aim(Vector2i(_grid.side_cols + int(_grid.side_cols * 0.5), int(_grid.rows * 0.5)))
	return true


## Leaves PLACING (the piece stays wherever the caller keeps it).
func cancel() -> void:
	_state = State.IDLE
	_slot = -1
	_piece = null
	_target = BoardGrid.NO_CELL
	_anchor = BoardGrid.NO_CELL
	_cells = []
	_blocked = []


## True while a piece is being placed.
func is_placing() -> bool:
	return _state == State.PLACING


## Bag slot of the piece being placed (-1 when idle).
func get_slot() -> int:
	return _slot


## The piece in its current rotation (null when idle).
func get_piece() -> Piece:
	return _piece


## Aims the ghost at board cell [param cell]. A cell outside the enemy half (or NO_CELL) puts the
## ghost off the board: no cells, [method can_confirm] false. Returns true when the ghost sits on a
## valid placement.
func move_to(cell: Vector2i) -> bool:
	if not is_placing():
		return false
	return _aim(cell)


## Rotates the piece 90 degrees clockwise AROUND THE CELL UNDER THE FINGER: the ghost cell nearest the
## aimed cell (the aimed cell itself when the ghost covers it) keeps its place on the board. When the
## turned piece no longer fits there it snaps to the nearest valid anchor of the aimed cell. Off the
## board it only turns. Returns false when idle.
func rotate() -> bool:
	if not is_placing():
		return false
	var old_rel: Array[Vector2i] = _piece.relative_cells()
	var old_anchor: Vector2i = _anchor
	var had_cells: bool = not _cells.is_empty()
	var target: Vector2i = _target
	_piece = _piece.rotated(1)
	if not had_cells:
		# Off the board: nothing to keep; stay off until the pointer comes back.
		return true
	var pivot: Vector2i = _pivot_cell(target)
	var pivot_rel: Vector2i = pivot - old_anchor
	# Same transform as Piece.relative_cells (90 degrees clockwise, y down), then re-normalised.
	var turned: Array[Vector2i] = []
	var min_x: int = 1000000
	var min_y: int = 1000000
	for c: Vector2i in old_rel:
		var t := Vector2i(-c.y, c.x)
		turned.append(t)
		min_x = mini(min_x, t.x)
		min_y = mini(min_y, t.y)
	var new_pivot_rel := Vector2i(-pivot_rel.y - min_x, pivot_rel.x - min_y)
	var new_anchor: Vector2i = pivot - new_pivot_rel
	if anchors_avoiding(_grid, _piece, _blocked).has(new_anchor):
		_anchor = new_anchor
		_cells = _piece.cells_at(new_anchor)
	else:
		_aim(target)
	return true


## Cells the ghost covers (empty when off the board or idle).
func get_cells() -> Array[Vector2i]:
	return _cells.duplicate()


## Top-left anchor of the ghost (NO_CELL when off the board).
func get_anchor() -> Vector2i:
	return _anchor


## Last cell the pointer aimed at (NO_CELL when off the enemy half or never aimed).
func get_target() -> Vector2i:
	return _target


## True when the ghost sits on a valid placement (confirming is allowed).
func can_confirm() -> bool:
	return is_placing() and not _cells.is_empty()


## True when [param enemy_cell] (where the boss stands) is one of the ghost's cells.
func hits(enemy_cell: Vector2i) -> bool:
	return can_confirm() and PiecePlacement.covers(_cells, enemy_cell)


## Story 039: true while the hit forecast must NOT be shown (a Shroud match, boss neither pinned nor casting). The HUD
## draws the neutral grey ghost and the cloud icon then; [method hits] itself is unchanged.
func forecast_blocked() -> bool:
	return forecast_blocked_fn.is_valid() and bool(forecast_blocked_fn.call())


## Number of cells of the piece being placed (0 when idle).
func cell_count() -> int:
	return _piece.cell_count() if _piece != null else 0


## Ends PLACING and returns the ghost's cells ([] and no state change when [method can_confirm] is
## false). The caller consumes the piece from slot [method get_slot] BEFORE calling this.
func confirm() -> Array[Vector2i]:
	if not can_confirm():
		return []
	var out: Array[Vector2i] = _cells.duplicate()
	cancel()
	return out


# The ghost cell that is the rotation pivot: [param target] when the ghost covers it, else the ghost
# cell nearest to it (the first cell when nothing was aimed).
func _pivot_cell(target: Vector2i) -> Vector2i:
	if _cells.has(target):
		return target
	var best: Vector2i = _cells[0]
	if target == BoardGrid.NO_CELL:
		return best
	var best_dist: int = -1
	for c: Vector2i in _cells:
		var d: int = (c - target).length_squared()
		if best_dist < 0 or d < best_dist:
			best_dist = d
			best = c
	return best


# Snaps to [param cell] when it lies on the enemy half's bounding area; else goes off the board.
func _aim(cell: Vector2i) -> bool:
	_target = BoardGrid.NO_CELL
	_anchor = BoardGrid.NO_CELL
	_cells = []
	if cell == BoardGrid.NO_CELL or cell.x < _grid.side_cols or cell.x >= _grid.total_cols \
			or cell.y < 0 or cell.y >= _grid.rows:
		return false
	_target = cell
	var snapped: Dictionary = snap_avoiding(_grid, _piece, cell, _blocked)
	if snapped.is_empty():
		return false
	_anchor = snapped["anchor"]
	_cells.assign(snapped["cells"])
	return true


## Story 028 (pure): every valid anchor of [param piece] (current rotation) on the ENEMY half whose
## cells share no cell with [param blocked]. With an empty [param blocked] it equals
## [method PiecePlacement.valid_anchors]. Row by row, left to right.
static func anchors_avoiding(grid: BoardGrid, piece: Piece, blocked: Array[Vector2i]) -> Array[Vector2i]:
	var all: Array[Vector2i] = PiecePlacement.valid_anchors(grid, piece, true)
	if blocked.is_empty() or piece == null:
		return all
	var rel: Array[Vector2i] = piece.relative_cells()
	var out: Array[Vector2i] = []
	for anchor: Vector2i in all:
		var clear: bool = true
		for cell: Vector2i in rel:
			if blocked.has(cell + anchor):
				clear = false
				break
		if clear:
			out.append(anchor)
	return out


## Story 028 (pure): [method PiecePlacement.snap] restricted to [method anchors_avoiding]. Returns
## {anchor, cells} or an empty dictionary when nothing fits around the blocked cells.
static func snap_avoiding(grid: BoardGrid, piece: Piece, target_cell: Vector2i, blocked: Array[Vector2i]) -> Dictionary:
	if blocked.is_empty():
		return PiecePlacement.snap(grid, piece, target_cell, true)
	var anchors: Array[Vector2i] = anchors_avoiding(grid, piece, blocked)
	if anchors.is_empty():
		return {}
	var box: Vector2i = piece.size()
	var rel: Array[Vector2i] = piece.relative_cells()
	var best: Vector2i = anchors[0]
	var best_dist: int = -1
	var best_covers: bool = false
	for anchor: Vector2i in anchors:
		var dx: int = anchor.x * 2 + box.x - 1 - target_cell.x * 2
		var dy: int = anchor.y * 2 + box.y - 1 - target_cell.y * 2
		var dist: int = dx * dx + dy * dy
		var covers: bool = rel.has(target_cell - anchor)
		var better: bool = best_dist < 0 or (covers and not best_covers) or (covers == best_covers and dist < best_dist)
		if better:
			best_dist = dist
			best = anchor
			best_covers = covers
	return {"anchor": best, "cells": piece.cells_at(best)}
