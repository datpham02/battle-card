class_name WardAnchor
extends RefCounted
## Skill v2 batch 3 (docs/skill-v2/02-mechanics-catalog.md M10, option A2): a ward card's pieces are placed on the enemy
## half like every card; when the card is chosen the cast's shape is RE-ANCHORED on the hero: mirrored across the
## divider (x flipped) so it faces the hero's side, its centre cell (ShapeTags centre, ties nearest the hero) put on
## the hero's cell, and every cell outside the own half or locked trimmed. Pure and deterministic.


## The own-half cells of [param cells] re-anchored on [param hero] (see the class doc). [param status] trims locked
## cells (null = none locked). Never empty when the hero's own cell is a player cell: it always keeps at least that.
static func remap(cells: Array[Vector2i], hero: Vector2i, grid: BoardGrid, status: StatusEffects = null) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if cells.is_empty():
		if grid.is_player_cell(hero):
			out.append(hero)
		return out
	var centre: Vector2i = ShapeTags.tags_for(cells, false, hero)["centre"]
	for c: Vector2i in cells:
		var off: Vector2i = c - centre
		var n: Vector2i = hero + Vector2i(-off.x, off.y)
		if not grid.is_player_cell(n) or (status != null and status.is_locked(n)) or out.has(n):
			continue
		out.append(n)
	if out.is_empty() and grid.is_player_cell(hero):
		out.append(hero)
	return out
