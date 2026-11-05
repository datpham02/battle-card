class_name SkillAvailability
extends RefCounted
## Decides whether a skill can be chosen for a cut, with a reason for the menu.
## Implements: Story 008.

## Key of [param context] in [method check]: true while an enemy attack telegraph is up (ParryGuard.enemy_telegraph).
const CTX_ENEMY_TELEGRAPH: String = "enemy_telegraph"


## Returns {available: bool, reason: String, need_cells: int, cooldown_left: float}.
## reason is "" (available), "not_implemented" (also unknown ids), "curse" (Story 033: a curse card is
## locked, never available), "need_cells", "cooldown" or "no_telegraph", checked in that order. need_cells is the skill's min_cells at [param level] (Story 020; 0 if unknown).
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
	result["available"] = true
	return result
