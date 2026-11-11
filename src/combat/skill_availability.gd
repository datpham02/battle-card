class_name SkillAvailability
extends RefCounted
## Decides whether a skill can be chosen for a cut, with a reason for the menu.
## Implements: Story 008.

## Key of [param context] in [method check]: true while an enemy attack telegraph is up (ParryGuard.enemy_telegraph).
const CTX_ENEMY_TELEGRAPH: String = "enemy_telegraph"
## Skill v2 delayed (Hỏa Lôi): context keys. CTX_ARMED_COUNT_FN = Callable(skill_id) -> int, the caster's casts of that
## card still armed; CTX_DELAYED_OPEN_CELLS = the placed cells a delayed card could still arm (not locked, not already
## armed). Absent keys skip the checks.
const CTX_ARMED_COUNT_FN: String = "armed_count_fn"
const CTX_DELAYED_OPEN_CELLS: String = "delayed_open_cells"
## Skill v2 batch 1 (Thương Xuyên): the ShapeTags tag lists of the placed pieces of the open cut, one Array[String] per
## piece (CombatView / the sim build it from the CastPlan). A card with `requires_shape` needs one; absent = unchecked.
const CTX_PIECE_TAGS: String = "piece_tags"


## Returns {available: bool, reason: String, need_cells: int, cooldown_left: float}.
## reason is "" (available), "not_implemented" (also unknown ids), "curse" (Story 033: a curse card is
## locked, never available), "need_cells", "cooldown", "no_telegraph", "need_shape" (batch 1: a `requires_shape` card
## whose tag no placed piece carries), then (delayed cards) "field_cap" and "no_valid_cells", checked in that order. need_cells is the skill's min_cells at [param level] (Story 020; 0 if unknown).
## Cast rhythm spec 2026-11-05: a `parry` card (SkillConfig.is_parry_card) is available only while
## [param context][[constant CTX_ENEMY_TELEGRAPH]] is true (an enemy skill winds up / warns); the caller injects the match's
## context (CombatView.get_availability_context, CutFlow.availability_context_fn). An empty context = no telegraph.
static func check(config: SkillConfig, cooldowns: SkillCooldowns, skill_id: String, cell_count: int, level: int = 1, context: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"available": false, "reason": "", "need_cells": 0, "cooldown_left": 0.0}
	var skill: Dictionary = config.call("resolved", skill_id, level) if config.has_method("resolved") else config.get_skill(skill_id)
	if skill.is_empty() or not bool(skill["implemented"]):
		result["reason"] = "not_implemented"
		result["need_cells"] = int(skill.get("min_cells", 0))
		return result
	result["need_cells"] = int(skill["min_cells"])
	if config.is_curse(skill_id):
		result["reason"] = "curse"
		return result
	if cell_count < int(skill["min_cells"]):
		result["reason"] = "need_cells"
		return result
	if not cooldowns.is_ready(skill_id):
		result["reason"] = "cooldown"
		result["cooldown_left"] = cooldowns.remaining(skill_id)
		return result
	if config.has_method("is_parry_card") and config.is_parry_card(skill_id) and not bool(context.get(CTX_ENEMY_TELEGRAPH, false)):
		result["reason"] = "no_telegraph"
		return result
	# Batch 1: a shape requirement (Thương Xuyên needs a `line` piece) is checked against the placed pieces' tags.
	var req: Dictionary = skill.get("requires_shape", {}) as Dictionary
	if not req.is_empty() and context.has(CTX_PIECE_TAGS) and not shape_satisfied(req, context[CTX_PIECE_TAGS] as Array):
		result["reason"] = "need_shape"
		return result
	# Skill v2 delayed: at most max_active armed fields of this card; never a cast that would arm no cell (it would
	# spend the Blocks and the cooldown for nothing). Batch 3: a trap card's max_active counts its armed trap casts
	# (the caller's CTX_ARMED_COUNT_FN adds StatusEffects.trap_cast_count).
	var cap: int = int(skill.get("max_active", 0))
	var count_fn: Variant = context.get(CTX_ARMED_COUNT_FN)
	if cap > 0 and count_fn is Callable and (count_fn as Callable).is_valid() and int((count_fn as Callable).call(skill_id)) >= cap:
		result["reason"] = "field_cap"
		return result
	if str(skill.get("resolve", "")) == "delayed":
		if context.has(CTX_DELAYED_OPEN_CELLS) and (context[CTX_DELAYED_OPEN_CELLS] as Array).is_empty():
			result["reason"] = "no_valid_cells"
			return result
	result["available"] = true
	return result


## Batch 1: true when the placed pieces' tag lists [param piece_tags] satisfy [param req] ({tag, scope}: any_piece =
## at least one piece carries the tag, all_pieces = every piece does). No pieces = false.
static func shape_satisfied(req: Dictionary, piece_tags: Array) -> bool:
	var tag: String = str(req.get("tag", ""))
	if tag.is_empty() or piece_tags.is_empty():
		return false
	var all: bool = str(req.get("scope", "any_piece")) == "all_pieces"
	for tags: Variant in piece_tags:
		var has: bool = (tags as Array).has(tag)
		if has and not all:
			return true
		if not has and all:
			return false
	return all


## Batch 1: the [constant CTX_PIECE_TAGS] value of [param plan] (a CastPlan) for a caster on [param caster_cell]:
## ShapeTags.tags_for of every placed piece's cells (odd pieces flagged). Shared by CombatView and the balance sim.
static func piece_tags_of(plan: CastPlan, caster_cell: Vector2i) -> Array:
	var out: Array = []
	if plan == null:
		return out
	var pieces: Array[Piece] = plan.pieces()
	for i: int in plan.piece_count():
		var piece: Piece = pieces[i] if i < pieces.size() else null
		out.append(ShapeTags.tags_for(plan.piece_cells(i), piece != null and piece.is_odd(), caster_cell)["tags"])
	return out


## Skill v2 delayed: the cells of [param cells] a delayed card could still arm: not locked ([param status] cracking /
## holes; null = none locked) and not already armed ([param armed]).
static func delayed_open_cells(cells: Array[Vector2i], armed: Array[Vector2i], status: StatusEffects = null) -> Array[Vector2i]:
	var open: Array[Vector2i] = status.unlocked_cells(cells) if status != null else cells.duplicate()
	var out: Array[Vector2i] = []
	for c: Vector2i in open:
		if not armed.has(c) and not out.has(c):
			out.append(c)
	return out
