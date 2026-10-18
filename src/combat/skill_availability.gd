class_name SkillAvailability
extends RefCounted
## Decides whether a skill can be chosen for a cut, with a reason for the menu.
## Implements: Story 008.

## Returns {available: bool, reason: String, need_cells: int, cooldown_left: float}.
## reason is "" (available), "not_implemented" (also unknown ids), "need_cells" or
## "cooldown", checked in that order. need_cells is the skill's min_cells (0 if unknown).
static func check(config: SkillConfig, cooldowns: SkillCooldowns, skill_id: String, cell_count: int) -> Dictionary:
	var result: Dictionary = {"available": false, "reason": "", "need_cells": 0, "cooldown_left": 0.0}
	var skill: Dictionary = config.get_skill(skill_id)
	if skill.is_empty() or not bool(skill["implemented"]):
		result["reason"] = "not_implemented"
		result["need_cells"] = int(skill.get("min_cells", 0))
		return result
	result["need_cells"] = int(skill["min_cells"])
	if cell_count < int(skill["min_cells"]):
		result["reason"] = "need_cells"
		return result
	if not cooldowns.is_ready(skill_id):
		result["reason"] = "cooldown"
		result["cooldown_left"] = cooldowns.remaining(skill_id)
		return result
	result["available"] = true
	return result
