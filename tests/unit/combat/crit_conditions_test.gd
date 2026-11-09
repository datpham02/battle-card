extends SceneTree
## Skill v2 M19 crit conditions (CritRules): each new condition holds exactly when its rule says, and cards still load
## their crit (normalize keeps the known ids, drops unknown ones). Pure checks on a small board.
## Run: godot --headless --path . -s res://tests/unit/combat/crit_conditions_test.gd

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 100.0, 100.0, Vector2i(1, 1), Vector2i(5, 1))
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	var ctx := {"state": state, "status": fx, "target_side": CombatState.Side.ENEMY}
	ck("every condition id is known", CritRules.CONDITIONS.size() == 8)
	ck("target_burning: no burn -> false", not CritRules.holds("target_burning", ctx))
	fx.ignite([Vector2i(5, 1)] as Array[Vector2i], 2.0, 0.5, 1.0)
	ck("target_burning: the boss's cell burns -> true", CritRules.holds("target_burning", ctx))
	ck("target_on_hazard: a burning cell is a hazard -> true", CritRules.holds("target_on_hazard", ctx))
	state.set_enemy_cell(Vector2i(6, 1))
	ck("target_burning / on_hazard: boss off the fire -> false", not CritRules.holds("target_burning", ctx)
		and not CritRules.holds("target_on_hazard", ctx))
	ck("target_marked: no Rạn -> false", not CritRules.holds("target_marked", ctx))
	fx.apply_fragile(CombatState.Side.ENEMY, 1)
	ck("target_marked: 1 Rạn -> true", CritRules.holds("target_marked", ctx))
	ck("self_hp_high: hero at 100 % -> true", CritRules.holds("self_hp_high", ctx))
	state.damage(CombatState.Side.PLAYER, 40.0)
	ck("self_hp_high: hero at 60 % -> false", not CritRules.holds("self_hp_high", ctx))
	ck("combo_3: waves 0 and 1 -> false, wave 2 -> true", not CritRules.holds("combo_3", {"wave_index": 1})
		and CritRules.holds("combo_3", {"wave_index": 2}))
	var line4 := {"pieces": [{"tags": ["line", "line_h"], "cells": [Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0)]}]}
	var line3 := {"pieces": [{"tags": ["line", "line_h"], "cells": [Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0)]}]}
	ck("line_full: a 4-cell line -> true, 3-cell -> false", CritRules.holds("line_full", {"cast_context": line4})
		and not CritRules.holds("line_full", {"cast_context": line3}))
	ck("first_strike: unknown -> false; 3 s -> true; 1 s -> false", not CritRules.holds("first_strike", {})
		and CritRules.holds("first_strike", {"since_target_hit": 3.0}) and not CritRules.holds("first_strike", {"since_target_hit": 1.0}))
	ck("normalize keeps a new condition", CritRules.normalize({"when": "target_burning", "mult": 1.5}).get("when", "") == "target_burning")
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)
