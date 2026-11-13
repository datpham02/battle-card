extends SceneTree
## The cues wired for the unified audio identity (docs/design/audio/unified-audio-identity.md §4, §8.1; user
## 2026-11-13 "test every sound in the game: skills, movement, touch"). Real signal sources, a CombatAudioBridge and a
## silent AudioDirector; each signal is emitted the way its owner emits it:
## - the hero moving to a cell plays move.step; an enemy moving plays nothing;
## - any unit dying plays combat.death (unit_died and player_died);
## - the pattern boss entering RECOVERY plays warn.boss.recovery; WINDUP still plays warn.boss.windup;
## - a terrain vent warning plays warn.terrain.vent;
## - pin / mark / poison / non-burn zones play status.apply / status.expire, one pitch step per kind;
## - an instant card landing plays its impact material (+ combat.crit on a crit); a scheduled one does not double it;
## - the enemy picking a field point plays pickup.point (rule level: BossController needs a full battle).
## Run: godot --headless --path . -s res://tests/unit/audio/unified_cues_test.gd

const Fx = preload("res://tests/unit/combat/pattern_fixtures.gd")

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_movement_death_status_and_vent()
	test_boss_recovery()
	test_multi_enemy_warnings_are_per_unit()
	test_boss_windup_has_one_source()
	test_instant_card_impact_and_crit()
	test_enemy_pickup_rule()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _plays(d: AudioDirector, id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in d.play_log:
		if e["op"] == "play" and str(e["id"]) == id:
			out.append(e)
	return out


func test_movement_death_status_and_vent() -> void:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 100.0, 100.0, Vector2i(1, 1), Vector2i(5, 1))
	var fx := StatusEffects.new()
	var hazards := TileHazards.new(grid, 1)
	var d := AudioDirector.silent()
	var bridge := CombatAudioBridge.new(d)
	bridge.attach({"state": state, "status": fx, "hazards": hazards})
	state.cell_changed.emit(CombatState.Side.PLAYER, Vector2i(1, 1), Vector2i(2, 1))
	ck("the hero's step plays move.step", _plays(d, "move.step").size() == 1)
	state.cell_changed.emit(CombatState.Side.ENEMY, Vector2i(5, 1), Vector2i(6, 1))
	ck("an enemy step plays nothing", _plays(d, "move.step").size() == 1)
	state.unit_damaged.emit(2, 5.0)
	d.advance(0.01)
	ck("a hit on enemy unit 2 (multi-enemy) plays the enemy body hit (was silent)", _plays(d, "combat.hit.enemy").size() == 1)
	state.unit_damaged.emit(0, 5.0)
	d.advance(0.01)
	ck("unit 0 is not doubled through unit_damaged (it sounds through damaged)", _plays(d, "combat.hit.enemy").size() == 1)
	state.unit_died.emit(1)
	ck("a unit dying plays combat.death", _plays(d, "combat.death").size() == 1)
	d.advance(0.5)
	state.player_died.emit()
	ck("the player dying plays combat.death", _plays(d, "combat.death").size() == 2)
	fx.pinned.emit(CombatState.Side.ENEMY)
	d.advance(0.5)
	fx.mark_applied.emit(CombatState.Side.ENEMY, 3.0)
	d.advance(0.5)
	fx.poisoned.emit(CombatState.Side.ENEMY)
	var applied: Array[Dictionary] = _plays(d, "status.apply")
	ck("pin, mark and poison play status.apply with their own pitch step (0, 1, 2)", applied.size() == 3
		and applied.map(func(e: Dictionary) -> int: return int(e["step"])) == [0, 1, 2], str(applied))
	d.advance(0.5)
	fx.poison_ended.emit(CombatState.Side.ENEMY)
	ck("a status ending plays status.expire", _plays(d, "status.expire").size() == 1 and int(_plays(d, "status.expire")[0]["step"]) == 2)
	var cells: Array[Vector2i] = [Vector2i(4, 0)]
	d.advance(0.5)
	fx.zone_applied.emit("burn", CombatState.Side.ENEMY, cells)
	ck("a burn zone is not a status cue (fire has its own)", _plays(d, "status.apply").size() == 3)
	fx.zone_applied.emit("thorns", CombatState.Side.ENEMY, cells)
	ck("a thorn zone plays status.apply at the zone step (3)", _plays(d, "status.apply").size() == 4
		and int(_plays(d, "status.apply")[3]["step"]) == 3)
	hazards.vent_warned.emit(CombatState.Side.PLAYER, 0, cells)
	ck("a vent warning plays warn.terrain.vent", _plays(d, "warn.terrain.vent").size() == 1)
	bridge.detach()
	bridge.free()
	d.free()


func test_boss_recovery() -> void:
	var cfg: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({
		"skills": Fx.skills(), "enemies": {"solo": {"ai": {"noise": 0.0}, "skills": ["fx_1"]}},
	})
	var w: Dictionary = Fx.world(BoardGrid.new(3, 3), cfg, "solo", 1)
	var ctrl: PatternController = w["ctrl"]
	var d := AudioDirector.silent()
	var bridge := CombatAudioBridge.new(d)
	bridge.attach({"pattern": ctrl})
	ctrl.stage_changed.emit(PatternController.Stage.RECOVERY, "fx_1")
	ck("the boss's recovery window plays warn.boss.recovery", _plays(d, "warn.boss.recovery").size() == 1)
	ctrl.stage_changed.emit(PatternController.Stage.WINDUP, "fx_1")
	ck("WINDUP still plays warn.boss.windup", _plays(d, "warn.boss.windup").size() == 1)
	bridge.detach()
	bridge.free()
	d.free()


# Multi-enemy item B (docs/design/audio/unified-audio-identity.md §6): two units warning the SAME skill; unit 1 is
# stunned (warning_cleared). Unit 2's imminent alarm must still sound. With one tag per skill, unit 1's clear cancelled
# both alarms.
func test_multi_enemy_warnings_are_per_unit() -> void:
	var cfg: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({
		"skills": Fx.skills(), "enemies": {"solo": {"ai": {"noise": 0.0}, "skills": ["fx_1"]}},
	})
	var c1: PatternController = Fx.world(BoardGrid.new(3, 3), cfg, "solo", 1)["ctrl"]
	var c2: PatternController = Fx.world(BoardGrid.new(3, 3), cfg, "solo", 2)["ctrl"]
	var d := AudioDirector.silent()
	var bridge := CombatAudioBridge.new(d)
	bridge.attach({"patterns": [[1, c1], [2, c2]]})
	var none: Array[Vector2i] = []
	c1.warning_started.emit("fx_1", none, none, 1.0)
	c2.warning_started.emit("fx_1", none, none, 1.0)
	c1.warning_cleared.emit("fx_1", "stun")
	for i: int in 30:
		d.advance(0.05)
	ck("unit 1 stunned: unit 2's imminent alarm for the same skill still sounds", _plays(d, "warn.boss.imminent").size() == 1,
		str(_plays(d, "warn.boss.imminent").size()))
	c2.warning_started.emit("fx_1", none, none, 1.0)
	c2.warning_cleared.emit("fx_1", "stun")
	for i: int in 30:
		d.advance(0.05)
	ck("a unit's own clear still cancels its own alarm", _plays(d, "warn.boss.imminent").size() == 1)
	bridge.detach()
	bridge.free()
	d.free()


# Item C: a pattern boss telegraphs through stage_changed (WINDUP); its actor's swing start must not sound the
# wind-up cue a second time. A boss without a pattern brain keeps the swing-start cue.
func test_boss_windup_has_one_source() -> void:
	var cfg: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({
		"skills": Fx.skills(), "enemies": {"solo": {"ai": {"noise": 0.0}, "skills": ["fx_1"]}},
	})
	var ctrl: PatternController = Fx.world(BoardGrid.new(3, 3), cfg, "solo", 1)["ctrl"]
	var actor := CutActor.new(CutConfig.load_from_file(), CombatState.Side.ENEMY)
	var cells: Array[Vector2i] = [Vector2i(1, 1)]
	var d := AudioDirector.silent()
	var bridge := CombatAudioBridge.new(d)
	bridge.attach({"pattern": ctrl, "enemy_actor": actor})
	actor.swing_started.emit(cells, "fx_1", 1.0)
	var from_swing: int = d.play_log.filter(func(e: Dictionary) -> bool: return str(e["id"]) == "warn.boss.windup").size()
	ck("pattern boss: the actor's swing start does not sound the wind-up", from_swing == 0, str(from_swing))
	ctrl.stage_changed.emit(PatternController.Stage.WINDUP, "fx_1")
	ck("pattern boss: stage WINDUP sounds it once", _plays(d, "warn.boss.windup").size() == 1)
	bridge.detach()
	var d2 := AudioDirector.silent()
	var b2 := CombatAudioBridge.new(d2)
	b2.attach({"enemy_actor": actor})
	actor.swing_started.emit(cells, "fx_1", 1.0)
	ck("a boss without a pattern brain keeps the swing-start wind-up", _plays(d2, "warn.boss.windup").size() == 1)
	b2.detach()
	b2.free()
	bridge.free()
	d.free()
	d2.free()


func test_instant_card_impact_and_crit() -> void:
	var bank: AudioBank = AudioBank.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var cells: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1)]
	var r: Dictionary = {"skill_id": "kiem_vu", "cells": cells, "hit": true, "crit": true}
	var c: Array[Dictionary] = AudioEventRules.on_swing_resolved(bank, AudioEventRules.SIDE_PLAYER, r, "kiem_vu", sc.get_skill("kiem_vu"))
	var ids: Array = c.filter(func(x: Dictionary) -> bool: return x["op"] == "play").map(func(x: Dictionary) -> String: return str(x["id"]))
	ck("an instant card plays its impact material and the crit ting", ids == ["skill.card.kiem_vu.impact", "combat.crit"], str(ids))
	r["scheduled"] = true
	ck("a scheduled cast's end plays nothing more (its impacts already sounded)",
		AudioEventRules.on_swing_resolved(bank, AudioEventRules.SIDE_PLAYER, r, "kiem_vu", sc.get_skill("kiem_vu")).is_empty())
	r.erase("scheduled")
	ck("an enemy swing's end plays nothing here (heard as combat.hit.player)",
		AudioEventRules.on_swing_resolved(bank, AudioEventRules.SIDE_ENEMY, r, "kiem_vu", sc.get_skill("kiem_vu")).is_empty())
	var hit: Array[Dictionary] = AudioEventRules.on_impact_resolved(bank, AudioEventRules.SIDE_PLAYER,
		{"cells": cells, "crit": true}, true, "kiem_vu", sc.get_skill("kiem_vu"))
	ck("a scheduled impact that crits adds combat.crit", hit.any(func(x: Dictionary) -> bool: return x.get("id", "") == "combat.crit"))


func test_enemy_pickup_rule() -> void:
	var c: Array[Dictionary] = AudioEventRules.on_enemy_picked_point()
	ck("the enemy taking a field point plays pickup.point", c.size() == 1 and c[0]["id"] == "pickup.point")
