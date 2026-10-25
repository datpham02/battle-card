class_name PiecePlacement
extends RefCounted
## Pure placement rules for a [Piece] on one half of a [BoardGrid]. A placement is valid when
## EVERY cell of the piece is a real cell of that half (holes and off-board cells make it
## invalid). A rotten piece has no valid placement at all.
## Implements: Story 024 (Part A).


## Every valid anchor (top-left of the bounding box) for [param piece] in its CURRENT rotation,
## row by row (top first), left to right. [param target_is_enemy] true = the boss's half,
## false = the player's half.
static func valid_anchors(grid: BoardGrid, piece: Piece, target_is_enemy: bool = true) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if grid == null or piece == null or not piece.placeable():
		return out
	var rel: Array[Vector2i] = piece.relative_cells()
	var box: Vector2i = piece.size()
	var x_first: int = grid.side_cols if target_is_enemy else 0
	var x_last: int = grid.total_cols if target_is_enemy else grid.side_cols
	for y: int in range(0, grid.rows - box.y + 1):
		for x: int in range(x_first, x_last - box.x + 1):
			if _fits(grid, rel, Vector2i(x, y), target_is_enemy):
				out.append(Vector2i(x, y))
	return out


## True if ANY of the 4 rotations of [param piece] has a valid anchor.
static func has_any_placement(grid: BoardGrid, piece: Piece, target_is_enemy: bool = true) -> bool:
	if grid == null or piece == null or not piece.placeable():
		return false
	for turns: int in 4:
		if not valid_anchors(grid, piece.rotated(turns), target_is_enemy).is_empty():
			return true
	return false


## The valid anchor for [param target_cell]: anchors whose cells COVER the target come first;
## among them (or among all anchors when none covers it, e.g. the target is a hole or off the
## half) the one whose bounding-box centre is nearest wins (squared distance; ties go to the
## upper, then the left anchor). Returns {anchor: Vector2i, cells: Array[Vector2i]} or an empty
## dictionary when nothing fits.
static func snap(
	grid: BoardGrid, piece: Piece, target_cell: Vector2i, target_is_enemy: bool = true
) -> Dictionary:
	var anchors: Array[Vector2i] = valid_anchors(grid, piece, target_is_enemy)
	if anchors.is_empty():
		return {}
	var box: Vector2i = piece.size()
	var rel: Array[Vector2i] = piece.relative_cells()
	var best: Vector2i = anchors[0]
	var best_dist: int = -1
	var best_covers: bool = false
	for anchor: Vector2i in anchors:
		# Doubled coordinates keep the half-cell centres in integers.
		var dx: int = anchor.x * 2 + box.x - 1 - target_cell.x * 2
		var dy: int = anchor.y * 2 + box.y - 1 - target_cell.y * 2
		var dist: int = dx * dx + dy * dy
		var hit: bool = rel.has(target_cell - anchor)
		# Anchors come row by row, left to right, so a strict "better" keeps the upper/left tie-break.
		var better: bool = best_dist < 0 or (hit and not best_covers) or (hit == best_covers and dist < best_dist)
		if better:
			best_dist = dist
			best = anchor
			best_covers = hit
	return {"anchor": best, "cells": piece.cells_at(best)}


## True when [param cell] is one of [param cells].
static func covers(cells: Array[Vector2i], cell: Vector2i) -> bool:
	return cells.has(cell)


static func _fits(grid: BoardGrid, rel: Array[Vector2i], anchor: Vector2i, target_is_enemy: bool) -> bool:
	for cell: Vector2i in rel:
		var abs_cell: Vector2i = cell + anchor
		var ok: bool = grid.is_enemy_cell(abs_cell) if target_is_enemy else grid.is_player_cell(abs_cell)
		if not ok:
			return false
	return true
