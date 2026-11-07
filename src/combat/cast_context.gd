class_name CastContext
extends RefCounted
## Skill v2 (docs/skill-v2/02-mechanics-catalog.md M01): the record of ONE cast, built when the card is chosen (before
## the cast plan is cleared) and carried by the swing to its resolve (CutActor -> SwingArbiter -> CutEffects options
## `cast_context`).
## Plain Dictionary so it duplicates and serialises freely:
##   {schema, card, level, side (= caster_side), caster_side, caster_cell, t_cast, cast_mode,
##    pieces: [{shape_id, canonical_key, rotation, cells, tags, odd}], cells (union), cell_count,
##    effective_cells, delivery, featured (bool), featured_bonus (the bonus details, {} when none)}
## B1.5: the context is a SNAPSHOT of cast time. SwingArbiter [method freeze]s it when the swing resolves, so scheduled
## impact events (and listeners) all read the same values and cannot change them. Nothing in the damage path reads it
## yet (the golden test pins that). Missing keys = today's behaviour (callers may pass {}).

## Context layout version (bumped when a field changes meaning).
const SCHEMA: int = 2


## Builds the context of card [param card] at [param level] cast by [param side] standing on [param caster_cell] from
## the placed [param pieces] and their board cells [param piece_cells] (parallel arrays, as CastPlan keeps them).
## [param extras] (all optional): cast_mode (String, default "direct"), featured_bonus (Dictionary, deep-copied),
## effective_cells (int, the damage cell count after the signature's cell rule; default = cell_count), t_cast (float,
## the arbiter clock at the cast; default 0.0).
static func build(card: String, level: int, pieces: Array[Piece], piece_cells: Array, delivery: Dictionary,
		featured: bool, side: int, caster_cell: Vector2i, extras: Dictionary = {}) -> Dictionary:
	var entries: Array = []
	var union: Array[Vector2i] = []
	for i: int in pieces.size():
		var cells: Array[Vector2i] = []
		if i < piece_cells.size():
			cells.assign(piece_cells[i])
		var piece: Piece = pieces[i]
		var odd: bool = piece != null and piece.shape_id.begins_with("odd:")
		entries.append({
			"shape_id": piece.shape_id if piece != null else "",
			"canonical_key": Piece.canonical_key(cells) if not cells.is_empty() else "",
			"rotation": piece.rotation if piece != null else 0,
			"cells": cells.duplicate(),
			"tags": ShapeTags.tags_for(cells, odd, caster_cell)["tags"],
			"odd": odd,
		})
		for c: Vector2i in cells:
			if not union.has(c):
				union.append(c)
	var bonus: Dictionary = {}
	if extras.get("featured_bonus") is Dictionary:
		bonus = (extras["featured_bonus"] as Dictionary).duplicate(true)
	return {
		"schema": SCHEMA,
		"card": card,
		"level": level,
		"side": side,
		"caster_side": side,
		"caster_cell": caster_cell,
		"t_cast": float(extras.get("t_cast", 0.0)),
		"cast_mode": str(extras.get("cast_mode", "direct")),
		"pieces": entries,
		"cells": union,
		"cell_count": union.size(),
		"effective_cells": maxi(int(extras.get("effective_cells", union.size())), 0),
		"delivery": delivery.duplicate(true),
		"featured": featured,
		"featured_bonus": bonus,
	}


## Makes [param context] and everything nested in it read-only, in place, and returns it. A frozen context can still
## be [method Dictionary.duplicate]d into a writable copy. Writing to a frozen one is refused by the engine.
static func freeze(context: Dictionary) -> Dictionary:
	_freeze(context)
	return context


## True when [param context] and every array / dictionary nested in it is read-only.
static func is_frozen(context: Dictionary) -> bool:
	return _is_frozen(context)


static func _freeze(v: Variant) -> void:
	if v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			_freeze((v as Dictionary)[k])
		(v as Dictionary).make_read_only()
	elif v is Array:
		for e: Variant in v as Array:
			_freeze(e)
		(v as Array).make_read_only()


static func _is_frozen(v: Variant) -> bool:
	if v is Dictionary:
		if not (v as Dictionary).is_read_only():
			return false
		for k: Variant in (v as Dictionary).keys():
			if not _is_frozen((v as Dictionary)[k]):
				return false
	elif v is Array:
		if not (v as Array).is_read_only():
			return false
		for e: Variant in v as Array:
			if not _is_frozen(e):
				return false
	return true


## True when at least one placed piece of [param context] carries [param tag] (clause scope `any_piece`).
static func has_tag(context: Dictionary, tag: String) -> bool:
	for p: Variant in context.get("pieces", []) as Array:
		if ((p as Dictionary).get("tags", []) as Array).has(tag):
			return true
	return false
