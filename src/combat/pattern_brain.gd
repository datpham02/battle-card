class_name PatternBrain
extends RefCounted
## The pattern brain's CHOICE (spec 3.7, pack 06 section 6): among the skills that passed the filters (cooldown,
## conditions, a valid plan that passes FairnessCheck), pick the phase's every_nth skill when it is due, else one by
## seeded weighted random: weight x punish_standing_still (player still >= standing_still_sec and the plan covers the
## player) x avoid_repeat_last_skill (same as the last skill) x favor_phase_mechanic (the phase's mechanic) x
## (1 +- noise). All factors come from enemy_skills.json `ai` (per-enemy override). Deterministic for a seed.
## Implements: design/quick-specs/phase2-misty-forest-2026-11-01.md 3.7 (P2.2).

var _ai: Dictionary
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Last choice breakdown for the AI debug overlay / decision log: [{skill, weight}] and the pick.
var last_breakdown: Array[Dictionary] = []


## [param ai] = the enemy's merged `ai` numbers; [param seed_value] < 0 = random.
func _init(ai: Dictionary, seed_value: int = -1) -> void:
	_ai = ai
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


## Pure: the noise-free weight of [param skill] with [param plan]. [param ctx]: player_cell, player_still_sec,
## last_skill, mechanic (the phase's mechanic id).
static func weight_for(skill: Dictionary, plan: Dictionary, ctx: Dictionary, ai: Dictionary) -> float:
	var w: float = float(skill.get("weight", 1.0))
	if float(ctx.get("player_still_sec", 0.0)) >= float(ai["standing_still_sec"]) \
			and (plan.get("cells", []) as Array).has(ctx.get("player_cell")):
		w *= float(ai["punish_standing_still"])
	if str(skill["id"]) == str(ctx.get("last_skill", "")):
		w *= float(ai["avoid_repeat_last_skill"])
	if not str(ctx.get("mechanic", "")).is_empty() and str(skill["id"]) == str(ctx.get("mechanic", "")):
		w *= float(ai["favor_phase_mechanic"])
	# Monster Skill Phase 0 (design §5.2): the skill's `weights` blocks x the fight's state the controller hands over
	# (player_statuses / player_zones / self_statuses: Array[String]; allies_alive: int). Every matching entry multiplies;
	# a missing block or an empty ctx list changes nothing, so the 11 forest enemies (no `weights`) score as before.
	var weights: Dictionary = skill.get("weights", {}) as Dictionary
	for block_key: String in ["player_status", "player_on_zone", "self_status"]:
		var ctx_key: String = str({"player_status": "player_statuses", "player_on_zone": "player_zones", "self_status": "self_statuses"}[block_key])
		if typeof(weights.get(block_key)) != TYPE_DICTIONARY:
			continue
		var have: Array = ctx.get(ctx_key, []) as Array
		for id: Variant in (weights[block_key] as Dictionary):
			if have.has(str(id)):
				w *= float((weights[block_key] as Dictionary)[id])
	if weights.has("allies_alive") and int(ctx.get("allies_alive", 0)) > 0:
		w *= float(weights["allies_alive"])
	return w


## One plan of [param plans] (non-empty): plans covering [param player_cell] first, then a seeded pick among them.
func pick_plan(plans: Array[Dictionary], player_cell: Vector2i) -> Dictionary:
	var covering: Array[Dictionary] = []
	for p: Dictionary in plans:
		if (p["cells"] as Array).has(player_cell):
			covering.append(p)
	var pool: Array[Dictionary] = covering if not covering.is_empty() else plans
	return pool[_rng.randi_range(0, pool.size() - 1)]


## Chooses among [param candidates] ([{skill, plans}], every plan already valid). [param ctx] as [method weight_for]
## plus forced_skill (the due every_nth id, "" = none). Returns {skill, plan} or {} when there is no candidate.
func choose(candidates: Array[Dictionary], ctx: Dictionary) -> Dictionary:
	last_breakdown.clear()
	if candidates.is_empty():
		return {}
	var forced: String = str(ctx.get("forced_skill", ""))
	if not forced.is_empty():
		for c: Dictionary in candidates:
			if str((c["skill"] as Dictionary)["id"]) == forced:
				last_breakdown.append({"skill": forced, "weight": -1.0, "forced": true})
				return {"skill": c["skill"], "plan": pick_plan(c["plans"] as Array[Dictionary], ctx.get("player_cell", BoardGrid.NO_CELL))}
	var picks: Array[Dictionary] = []
	var total: float = 0.0
	var noise: float = clampf(float(_ai["noise"]), 0.0, 0.99)
	for c: Dictionary in candidates:
		var plan: Dictionary = pick_plan(c["plans"] as Array[Dictionary], ctx.get("player_cell", BoardGrid.NO_CELL))
		var w: float = weight_for(c["skill"] as Dictionary, plan, ctx, _ai) * (1.0 + noise * (_rng.randf() * 2.0 - 1.0))
		w = maxf(w, 0.0)
		picks.append({"skill": c["skill"], "plan": plan, "w": w})
		total += w
		last_breakdown.append({"skill": str((c["skill"] as Dictionary)["id"]), "weight": w})
	if total <= 0.0:
		return {}
	var roll: float = _rng.randf() * total
	for p: Dictionary in picks:
		roll -= float(p["w"])
		if roll <= 0.0:
			return {"skill": p["skill"], "plan": p["plan"]}
	var last: Dictionary = picks[picks.size() - 1]
	return {"skill": last["skill"], "plan": last["plan"]}
