extends SceneTree
## Story 035 Part A bullet 1 + "Match stats": a REGION boss (match_params boss_can_down) at 0 HP is DOWNED in
## CombatView: it stays on the board, stops deciding, its field pieces are removed and its drop tiles / thorns / burns
## on the player's half clear; match_ended still fires after end_delay_sec. A miniboss / normal match (no key) and
## the final match (boss_phases, no key) keep today's dead-boss behaviour. get_match_stats counts damage dealt /
## taken, hits taken, casts, joins, featured casts and signatures from the existing hooks. Headless; FAILS=N.
## Deterministic: fixed drops seed, time frozen (only the real-time end delay runs).

const SEED: int = 7
const BOSS_HP: float = 50.0
const LETHAL: float = 999999.0
const ZONE_SEC: float = 30.0

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _initialize() -> void:
	await process_frame
	await _test_region_boss_downed()
	await _test_miniboss_keeps_dead_behaviour()
	await _test_final_match_phases_not_downed()
	await _test_match_stats()
	await process_frame
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ fixtures

# A headless match (HoldSlotsView + CombatView + CutHudView in one holder, time frozen).
func _match(params: Dictionary) -> Node:
	var holder := Node.new()
	var bag := HoldSlotsView.new()
	bag.name = "HoldSlotsView"
	holder.add_child(bag)
	var v := CombatView.new()
	v.name = "CombatView"
	v.match_params = params
	v.drops_seed = SEED
	v.freeze_time = true
	holder.add_child(v)
	var hud := CutHudView.new()
	hud.name = "CutHudView"
	holder.add_child(hud)
	root.add_child(holder)
	await process_frame
	return holder


func _view(holder: Node) -> CombatView:
	return holder.get_node("CombatView") as CombatView


func _drop(holder: Node) -> void:
	root.remove_child(holder)
	holder.free()


# The boss's drop tile (cracking) + thorns + a burning cell on the player's half, and one boss piece lying on its
# half. The litter cells avoid the player's own cell.
func _litter(v: CombatView) -> void:
	var grid: BoardGrid = v.get_grid()
	var player_cells: Array[Vector2i] = grid.player_cells()
	player_cells.erase(v.get_state().player_cell)
	var status: StatusEffects = v.get_status()
	status.apply_drop(CombatState.Side.PLAYER, [player_cells[0]] as Array[Vector2i], ZONE_SEC, ZONE_SEC)
	status.apply_thorns(CombatState.Side.PLAYER, [player_cells[1]] as Array[Vector2i], ZONE_SEC, 1.0, 0)
	status.ignite([player_cells[2]] as Array[Vector2i], ZONE_SEC, 1.0, 1.0)
	var enemy_cells: Array[Vector2i] = grid.enemy_cells()
	var free_cell: Vector2i = enemy_cells[0] if enemy_cells[0] != v.get_state().enemy_cell else enemy_cells[1]
	v.get_boss().get_drops().debug_place("boss_piece", free_cell, ZONE_SEC)


func _player_litter_count(v: CombatView) -> int:
	var status: StatusEffects = v.get_status()
	var side: int = CombatState.Side.PLAYER
	var count: int = status.crack_cells(side).size() + status.hole_cells(side).size() + status.thorn_cells(side).size()
	for cell: Vector2i in status.burning_cells():
		if v.get_grid().is_player_cell(cell):
			count += 1
	return count


# Waits a few frames for the (0 s) end delay; returns the match_ended results seen.
func _await_end(v: CombatView, ended: Array) -> void:
	for i: int in 4:
		await process_frame
	if ended.is_empty():
		push_warning("boss_downed_test: match_ended not seen")


# ------------------------------------------------------------------ tests

func _test_region_boss_downed() -> void:
	# Arrange
	var holder: Node = await _match({"boss_can_down": true, "boss_max_hp": BOSS_HP, "end_delay_sec": 0.0})
	var v: CombatView = _view(holder)
	var ended: Array = []
	v.match_ended.connect(func(won: bool, _hp: float) -> void: ended.append(won))
	_litter(v)
	var cell: Vector2i = v.get_state().enemy_cell
	_check("region: litter present before", _player_litter_count(v) == 3 and v.get_boss().get_drops().get_points().size() == 1)
	_check("region: can_boss_down", v.can_boss_down() and not v.is_boss_downed())
	# Act
	v.get_state().damage(CombatState.Side.ENEMY, LETHAL)
	# Assert
	_check("region: downed at 0 HP", v.is_boss_downed())
	_check("region: boss stays on its cell", v.get_state().enemy_cell == cell)
	_check("region: boss stops deciding / moving", not v.get_boss().is_active() and not v.get_boss().get_actor().is_swinging())
	_check("region: its field pieces are gone", v.get_boss().get_drops().get_points().is_empty())
	_check("region: drop tiles, thorns, burns on the player's half cleared", _player_litter_count(v) == 0, str(_player_litter_count(v)))
	await _await_end(v, ended)
	_check("region: match_ended still fires (won)", ended == [true], str(ended))
	_drop(holder)


func _test_miniboss_keeps_dead_behaviour() -> void:
	# Arrange
	var holder: Node = await _match({"boss_max_hp": BOSS_HP, "end_delay_sec": 0.0})
	var v: CombatView = _view(holder)
	var ended: Array = []
	v.match_ended.connect(func(won: bool, _hp: float) -> void: ended.append(won))
	_litter(v)
	# Act
	v.get_state().damage(CombatState.Side.ENEMY, LETHAL)
	# Assert
	_check("miniboss: not downed", not v.can_boss_down() and not v.is_boss_downed() and v.get_state().is_enemy_dead())
	_check("miniboss: nothing cleared (today's behaviour)", _player_litter_count(v) == 3 and v.get_boss().get_drops().get_points().size() == 1)
	await _await_end(v, ended)
	_check("miniboss: match_ended fires (won)", ended == [true], str(ended))
	_drop(holder)


func _test_final_match_phases_not_downed() -> void:
	# Arrange: a final-match-like boss with two phases, built from our own params.
	var phases: Array = [
		{"traits": [{"id": "seal_caster", "params": {}}], "brain_set": "balanced"},
		{"at_hp_ratio": 0.5, "phase_shift_sec": 0.0, "traits": [{"id": "row_burner", "params": {}}], "brain_set": "aggressive"},
	]
	var holder: Node = await _match({"boss_max_hp": 100.0, "end_delay_sec": 0.0,
		"traits": [{"id": "boss_phases", "params": {"phases": phases}}]})
	var v: CombatView = _view(holder)
	var host: TraitHost = v.get_trait_host()
	var t: BossPhasesTrait = host.get_trait(BossPhasesTrait.ID) as BossPhasesTrait
	_check("final: boss_phases live with phase 1 traits", t != null and host.get_trait("seal_caster") != null)
	# Act: a lethal hit is clamped at the threshold, then (phase 2, no shift) a second one kills.
	v.get_state().damage(CombatState.Side.ENEMY, LETHAL)
	host.on_boss_damaged(LETHAL)
	_check("final: lethal hit clamped at 50", is_equal_approx(v.get_state().enemy_hp, 50.0), str(v.get_state().enemy_hp))
	_check("final: phase 2 traits", t.get_phase() == 2 and host.get_trait("row_burner") != null and host.get_trait("seal_caster") == null, str(host.get_ids()))
	v.get_state().damage(CombatState.Side.ENEMY, LETHAL)
	# Assert
	_check("final: dies, not downed", v.get_state().is_enemy_dead() and not v.is_boss_downed())
	_drop(holder)


func _test_match_stats() -> void:
	# Arrange
	var holder: Node = await _match({"boss_max_hp": BOSS_HP})
	var v: CombatView = _view(holder)
	var zero: Dictionary = v.get_match_stats()
	var keys: Array[String] = ["damage_dealt", "damage_taken", "hits_taken", "casts", "joins", "featured_casts", "signatures_used", "frost_bursts", "boss_thorn_steps"]
	var all_zero: bool = true
	for key: String in keys:
		all_zero = all_zero and zero.has(key) and is_zero_approx(float(zero[key]))
	_check("stats: 9 keys (Story 037 adds frost_bursts, boss_thorn_steps), all 0 at start", all_zero and zero.size() == keys.size(), str(zero))
	var cell: Vector2i = v.get_state().enemy_cell
	var cells: Array[Vector2i] = [cell]
	# Act: 10 HP off the boss, 5 HP off the player, one joined featured cast resolving, one boss hit, one miss.
	v.get_state().damage(CombatState.Side.ENEMY, 10.0)
	v.get_state().damage(CombatState.Side.PLAYER, 5.0)
	v.set("_cast_info", {"pieces": [], "cells": 1, "joined": true, "featured": true, "card_id": "", "hit": false})
	v.get_arbiter().swing_resolved.emit(CombatState.Side.PLAYER,
		{"cells": cells, "hit": false, "damage": 0.0, "cell": cell, "skill_id": SkillConfig.FALLBACK_SKILL})
	v.get_arbiter().swing_resolved.emit(CombatState.Side.ENEMY,
		{"cells": cells, "hit": true, "damage": 0.0, "cell": cell, "skill_id": SkillConfig.FALLBACK_SKILL})
	v.get_arbiter().swing_resolved.emit(CombatState.Side.ENEMY,
		{"cells": cells, "hit": false, "damage": 0.0, "cell": cell, "skill_id": SkillConfig.FALLBACK_SKILL})
	v.get_state().damage(CombatState.Side.ENEMY, LETHAL)
	var s: Dictionary = v.get_match_stats()
	# Assert
	_check("stats: damage_dealt is clamped HP", is_equal_approx(float(s["damage_dealt"]), BOSS_HP), str(s["damage_dealt"]))
	_check("stats: damage_taken", is_equal_approx(float(s["damage_taken"]), 5.0), str(s["damage_taken"]))
	_check("stats: hits_taken counts hits only", int(s["hits_taken"]) == 1, str(s["hits_taken"]))
	_check("stats: casts / joins / featured", int(s["casts"]) == 1 and int(s["joins"]) == 1 and int(s["featured_casts"]) == 1, str(s))
	_check("stats: no signature used", int(s["signatures_used"]) == 0)
	_drop(holder)
