extends SceneTree
## Skill v2 Hỏa Lôi boss counterplay (docs/skill-v2/09-hoa-loi-design.md §8; BossBrain ctx.pending_threat.armed and
## ctx.player_cast_delay): a visible armed seal is an URGENT threat only inside the set's fuse_react_sec (0.8 s default),
## earlier only a soft path cost; a delayed swing threatens its fuse later than its end; a boss with no safe reachable
## cell does not "escape" into another seal; the window is per weight set (bosses differ); a direct swing still dodges
## at once (legacy). The brain is driven directly (no clock), so each case is one decision.
## Run: godot --headless --path . -s res://tests/unit/combat/boss_fuse_awareness_test.gd

const SEED: int = 7
const THINK_SEC: float = 1.0
const BOSS := Vector2i(4, 1)

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _initialize() -> void:
	test_early_seal_is_not_urgent()
	test_late_seal_is_dodged()
	test_full_cover_leaves_no_safe_cell()
	test_delayed_swing_is_not_urgent_yet()
	test_direct_swing_still_dodged()
	test_per_set_window()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _config(react: float = 0.8) -> BossBrainConfig:
	return BossBrainConfig.from_dictionary({
		"step_cooldown_sec": 0.55, "think_interval_sec": 0.0, "reaction_sec": 0.0, "noise": 0.0,
		"active_set": "t",
		"sets": {"t": {
			"dodge_danger": 10.0, "idle_bias": 0.2, "retreat_bonus": 0.0, "pickup_value": 0.0,
			"combo_chance": 0.0, "fuse_react_sec": react, "fuse_avoid": 1.0,
			"movement": {
				"move_commitment": 1.0, "move_noise": 0.0, "reaction_sec": 0.0, "path_style": "shortest",
				"juke_chance": 0.0, "wander_when_idle": false,
			},
		}},
	})


func _world(react: float = 0.8) -> Dictionary:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 1.0e6, 1.0e6, Vector2i(1, 1), BOSS)
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var drops_config := FieldDropsConfig.new()
	drops_config.initial_delay_sec = 1.0e9
	var cfg: BossBrainConfig = _config(react)
	var brain := BossBrain.new(cfg, grid, cc, sc, SEED)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	var ctx: Dictionary = {
		"state": state, "hand": HoldSlots.create_piece_hand(3), "drops": FieldDrops.new(drops_config, grid.enemy_cells(), SEED),
		"mover": UnitMover.new(state, CombatState.Side.ENEMY, cfg.step_cooldown_sec),
		"actor": CutActor.new(cc, CombatState.Side.ENEMY), "cooldowns": SkillCooldowns.new(),
		"player_actor": player, "status": StatusEffects.new(),
	}
	return {"brain": brain, "ctx": ctx, "state": state, "player": player}


func _decide(w: Dictionary, swinging: bool) -> Dictionary:
	var brain: BossBrain = w["brain"]
	brain.tick(THINK_SEC, swinging)
	return brain.decide(w["ctx"])


func _armed(cells: Array, left: float) -> Dictionary:
	var c: Array[Vector2i] = []
	for p: Variant in cells:
		c.append(p as Vector2i)
	return {"armed": [{"cast_id": 1, "skill_id": "hoa_loi", "cells": c, "time_left": left}]}


func _dest(action: Dictionary) -> Vector2i:
	return BOSS + (action["direction"] as Vector2i) if str(action.get("type", "")) == "move" else BOSS


const LONE: Array = [Vector2i(4, 1)]
const PLUS: Array = [Vector2i(4, 1), Vector2i(3, 1), Vector2i(5, 1), Vector2i(4, 0), Vector2i(4, 2)]


func test_early_seal_is_not_urgent() -> void:
	var w: Dictionary = _world()
	w["ctx"]["pending_threat"] = _armed(LONE, 1.4)
	var a: Dictionary = _decide(w, false)
	_check("a seal 1.4 s from detonation (> 0.8 s window): the boss does not dodge yet", str(a.get("type", "")) != "move", str(a))


func test_late_seal_is_dodged() -> void:
	var w: Dictionary = _world()
	w["ctx"]["pending_threat"] = _armed(LONE, 0.6)
	var a: Dictionary = _decide(w, false)
	_check("a lone seal inside the last 0.8 s with open exits: the boss steps off", str(a.get("type", "")) == "move"
		and not LONE.has(_dest(a)), str(a))


func test_full_cover_leaves_no_safe_cell() -> void:
	var w: Dictionary = _world()
	w["ctx"]["pending_threat"] = _armed(PLUS, 0.6)
	var a: Dictionary = _decide(w, false)
	_check("a plus field over the boss and every exit: it finds no safe cell (stays inside the field)", PLUS.has(_dest(a)), str(a))


func test_delayed_swing_is_not_urgent_yet() -> void:
	var w: Dictionary = _world()
	var player: CutActor = w["player"]
	var cells: Array[Vector2i] = [Vector2i(4, 1)]
	player.begin_swing(cells, "hoa_loi", true, 1, 0.45)
	w["ctx"]["player_cast_delay"] = 1.5
	var a: Dictionary = _decide(w, true)
	_check("a visible delayed swing (0.45 + 1.5 s away): no dodge yet", str(a.get("type", "")) != "move", str(a))


func test_direct_swing_still_dodged() -> void:
	var w: Dictionary = _world()
	var player: CutActor = w["player"]
	var cells: Array[Vector2i] = [Vector2i(4, 1)]
	player.begin_swing(cells, "kiem_khi", true, 1, 0.45)
	var a: Dictionary = _decide(w, true)
	_check("a direct swing on the same cell: dodged at once (legacy)", str(a.get("type", "")) == "move" and _dest(a) != BOSS, str(a))


func test_per_set_window() -> void:
	var w: Dictionary = _world(2.0)
	w["ctx"]["pending_threat"] = _armed(LONE, 1.4)
	var a: Dictionary = _decide(w, false)
	_check("a set reading fire early (fuse_react_sec 2.0) dodges the 1.4 s seal", str(a.get("type", "")) == "move"
		and not LONE.has(_dest(a)), str(a))
