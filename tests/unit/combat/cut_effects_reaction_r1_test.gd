extends SceneTree
## Skill v2 batch 2, Hỏa Băng (hoa_bang) and R1 Hơi Nước (M15, card-listed): a hit that gives Hàn to a unit standing
## on a burning cell bursts r1.burst_damage straight to its HP (ignores defense), puts that cell's fire out and spends
## 1 Hàn. The card ignites its cells through its event payload AFTER the hit, so SwingArbiter re-checks R1 once the
## payload lit the cell (CutEffects.try_r1). A target already on fire reacts inside CutEffects.apply; a miss ignites
## but never reacts; a card without r1 (han_kiem) chills on a burning cell without a burst.
## Run: godot --headless --path . -s res://tests/unit/combat/cut_effects_reaction_r1_test.gd

const ID: String = "hoa_bang"
const HERO := Vector2i(1, 1)
const STEP: float = 0.01

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_data()
	test_hit_ignites_then_reacts()
	test_target_already_burning_reacts_in_apply()
	test_miss_ignites_without_reaction()
	test_card_without_r1_reacts_globally()
	test_determinism()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _world(boss: Vector2i, defense: float = 0.0) -> Dictionary:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, HERO, boss)
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	var enemy := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, player, enemy, cc, sc, fx)
	arb.reactions = CombatConfig.load_from_file().reactions()
	arb.boss_defense = defense
	var log: Array = []
	arb.impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"cells": ev["cells"], "at": arb.clock(), "hit": hit, "dmg": float(ev.get("damage", 0.0)),
			"reaction": str(ev.get("reaction", "")), "ignited": ev.get("ignited", [])}))
	var done: Array = []
	arb.swing_resolved.connect(func(_side: int, r: Dictionary) -> void: done.append(r))
	return {"grid": grid, "state": state, "cc": cc, "sc": sc, "fx": fx, "player": player, "arb": arb, "log": log, "done": done}


# Runs the swing (0.2 + 0.25 s x cells) plus [param sec] seconds after its end.
func _cast(w: Dictionary, cells: Array[Vector2i], skill_id: String = ID, sec: float = 2.0) -> void:
	(w["player"] as CutActor).begin_swing(cells, skill_id, true, 1, -1.0, {}, {})
	var t: float = 0.0
	sec += (w["player"] as CutActor).get_duration()
	while t < sec:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


const BAR4: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]


func test_data() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("shared epic card: damage 3/cell, +1 Hàn, ignite payload 2 s, reaction r1, waves x1, no errors", s["rarity"] == "epic"
		and is_equal_approx(float(s["damage_per_cell"]), 3.0) and int(s["frost_stacks"]) == 1
		and is_equal_approx(float(s["event_payload"]["ignite"]["sec"]), 2.0) and (s["reactions"] as Array) == ["r1"]
		and s["resolve"] == "waves" and (s["resolve_errors"] as Array).is_empty(), str(s["resolve_errors"]))
	ck("min 4, cd 10", int(s["min_cells"]) == 4 and is_equal_approx(float(s["cooldown_sec"]), 10.0))
	var bad: Dictionary = CastResolver.validate("x", {"event_payload": {"ignite": {"sec": 1.0}}}, "damage")
	ck("a payload on an instant card is still rejected", not (bad["errors"] as Array).is_empty())
	ck("combat.json r1 burst 12", is_equal_approx(CombatConfig.load_from_file().r1_burst_damage, 12.0))


func test_hit_ignites_then_reacts() -> void:
	# the hit (12 before defense 2 = 10) gives Hàn, the payload lights the cells, R1 bursts 12 ignoring defense
	var w: Dictionary = _world(Vector2i(5, 1), 2.0)
	_cast(w, BAR4, ID, 0.9)
	var fx: StatusEffects = w["fx"]
	ck("hit 10 (defense 2) + R1 burst 12 (no defense) = 22, Hàn spent, the boss's cell put out, 3 cells still burning",
		is_equal_approx(_lost(w), 22.0 + _burn_ticks(w)) and fx.frost_stacks(CombatState.Side.ENEMY) == 0
		and not fx.is_burning(Vector2i(5, 1)) and fx.burning_cells().size() == 3, "%.1f burning=%s" % [_lost(w), str(fx.burning_cells())])
	var ev: Dictionary = (w["log"] as Array)[0]
	ck("the event reports reaction r1 and the 4 ignited cells", ev["reaction"] == "r1" and (ev["ignited"] as Array).size() == 4, str(ev))
	ck("the card-level result carries reaction r1", str((w["done"] as Array)[0].get("reaction", "")) == "r1")


# Burn ticks the boss took on its (now unlit) cell during the run: none, the cell is put out on the hit.
func _burn_ticks(_w: Dictionary) -> float:
	return 0.0


func test_target_already_burning_reacts_in_apply() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	(w["fx"] as StatusEffects).ignite([Vector2i(5, 1)] as Array[Vector2i], 5.0, 10.0, 0.0)
	_cast(w, BAR4, ID, 0.3)
	ck("standing on fire before the cast: 12 + 12 = 24, reaction r1, cell put out then re-lit by the payload",
		is_equal_approx(_lost(w), 24.0) and str((w["done"] as Array)[0].get("reaction", "")) == "r1"
		and (w["fx"] as StatusEffects).frost_stacks(CombatState.Side.ENEMY) == 0, "%.1f" % _lost(w))


func test_miss_ignites_without_reaction() -> void:
	var w: Dictionary = _world(Vector2i(5, 2))
	_cast(w, BAR4, ID, 0.3)
	ck("miss: no damage, 4 cells burning, no Hàn, no reaction", is_zero_approx(_lost(w)) and (w["fx"] as StatusEffects).burning_cells().size() == 4
		and (w["fx"] as StatusEffects).frost_stacks(CombatState.Side.ENEMY) == 0 and str((w["done"] as Array)[0].get("reaction", "")).is_empty(),
		"%.1f" % _lost(w))


func test_card_without_r1_reacts_globally() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	(w["fx"] as StatusEffects).ignite([Vector2i(5, 1)] as Array[Vector2i], 5.0, 10.0, 0.0)
	_cast(w, BAR4, "han_kiem", 0.3)
	# batch 5 (Deferred 2): reactions are GLOBAL (combat.json reactions.global): a card that does not list r1 reacts too
	ck("han_kiem (Hàn, no r1 listed) on a burning cell: 6 x 4 = 24 + the global R1 burst 12 = 36, the Hàn spent, the fire out",
		is_equal_approx(_lost(w), 36.0) and (w["fx"] as StatusEffects).frost_stacks(CombatState.Side.ENEMY) == 0
		and not (w["fx"] as StatusEffects).is_burning(Vector2i(5, 1)), "%.1f" % _lost(w))
	# the card-listed rule is still there as data: reactions.global false
	var w2: Dictionary = _world(Vector2i(5, 1))
	var listed: Dictionary = CombatConfig.load_from_file().reactions()
	listed["global"] = false
	(w2["arb"] as SwingArbiter).reactions = listed
	(w2["fx"] as StatusEffects).ignite([Vector2i(5, 1)] as Array[Vector2i], 5.0, 10.0, 0.0)
	_cast(w2, BAR4, "han_kiem", 0.3)
	ck("reactions.global false: han_kiem deals 24 only, Hàn 1 stays, the cell still burns", is_equal_approx(_lost(w2), 24.0)
		and (w2["fx"] as StatusEffects).frost_stacks(CombatState.Side.ENEMY) == 1 and (w2["fx"] as StatusEffects).is_burning(Vector2i(5, 1)), "%.1f" % _lost(w2))


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(5, 1))
	_cast(a, BAR4, ID, 0.9)
	var b: Dictionary = _world(Vector2i(5, 1))
	_cast(b, BAR4, ID, 0.9)
	ck("two identical runs: same log and HP", str(a["log"]) == str(b["log"]) and is_equal_approx(_lost(a), _lost(b)))
