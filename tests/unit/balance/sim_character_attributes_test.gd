extends SceneTree
## F2 of the character-system redesign: the balance simulator must apply the character's two base
## attributes to the PLAYER and to nobody else. `tools/balance/sim_core.gd` mirrors CombatView's
## wiring with its own handlers, so without this the two can drift apart silently and the OD-2
## balance pass would measure a sim that does not model the feature it is measuring.
##
## Why a STRUCTURAL test and not a before/after sim diff (monster-skills, 2026-11-14): at the shipped
## values both multipliers are 1.0, and `x * 1.0` is bit-identical in IEEE 754 — so a sim diff comes
## back clean even if the attribute is wired to the ENEMY instead of the player. The diff cannot fail
## in the presence of the fault it is supposed to catch. These assertions can.
##
## Behavioural runs cannot isolate cast speed either: changing the player's windup moves the whole
## match trajectory, so no output field stays still. Hence asserting on the two actor objects
## directly — the sim builds exactly two, the player's (`actor`, CutActor.new(cut_config, PLAYER))
## and the boss's (`boss.get_actor()`, whose duration_mult comes from the match's swing_speed_mult).
##
## Deterministic, headless, no file is modified: the attributes are set on the prepared character
## dictionary in memory, never on assets/data/characters.json.
## Run: godot --headless --path . -s res://tests/unit/balance/sim_character_attributes_test.gd

const SimCore = preload("res://tools/balance/sim_core.gd")

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_cast_speed_reaches_the_player_actor_only()
	test_hazard_resist_scales_the_player_only()
	test_defaults_are_inert()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# Builds a core with [param attrs] merged into the prepared character. Returns {core, match}.
func _core(attrs: Dictionary) -> Dictionary:
	var core = SimCore.new()
	core.apply_args(PackedStringArray())
	core.load_configs()
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	var id: String = chapters.match_ids(0)[0]
	var m: Dictionary = core.prepare_match(RunConfig.from_node(chapters, 0, id, "battle", 1, -1).matches[0] as Dictionary)
	m["chapter_id"] = chapters.chapter_id(0)
	var character: Dictionary = core.prepare_character(core.characters.get_character("kiem_si"))
	for key: String in attrs:
		character[key] = attrs[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	core.rng = rng
	core._setup(m, character, [{"id": "kiem_khi", "level": 1}], -1.0, 11)
	return {"core": core, "match": m}


# The wiring test the sim diff cannot do. Wrong-side wiring fails the second assertion at once.
func test_cast_speed_reaches_the_player_actor_only() -> void:
	var built: Dictionary = _core({"cast_speed_mult": 2.0})
	var core = built["core"]
	var m: Dictionary = built["match"]
	ck("cast_speed_mult 2.0 reaches the PLAYER actor",
		is_equal_approx(core.actor.duration_mult, 2.0), str(core.actor.duration_mult))
	# swing_speed_mult is a MATCH key, so read the expectation from the match rather than assuming 1.0.
	var expected_boss: float = maxf(float(m.get("swing_speed_mult", 1.0)), 0.01)
	ck("the BOSS actor keeps the match's swing_speed_mult (%.2f)" % expected_boss,
		is_equal_approx(core.boss.get_actor().duration_mult, expected_boss),
		"got %s — a wrong-side wiring would show 2.0 here" % str(core.boss.get_actor().duration_mult))


# Hazard damage is attributed per side at the call site, so each side can be driven directly.
func test_hazard_resist_scales_the_player_only() -> void:
	var core = _core({"hazard_resist_mult": 0.5})["core"]
	core.invulnerable = false
	var player_before: float = core.state.player_hp
	core._on_mire_damage(SimCore.PLAYER, 10.0)
	var player_lost: float = player_before - core.state.player_hp
	ck("the PLAYER takes 10 x 0.5 = 5 mire damage", is_equal_approx(player_lost, 5.0), str(player_lost))

	var enemy_before: float = core.state.enemy_hp
	core._on_mire_damage(SimCore.ENEMY, 10.0)
	var enemy_lost: float = enemy_before - core.state.enemy_hp
	ck("the ENEMY still takes the full 10 (the attribute is the player's)",
		is_equal_approx(enemy_lost, 10.0), "%s — 5.0 here means it is wired to both sides" % str(enemy_lost))


# The shipped values. This is what makes the mirror safe to land ahead of any tuning.
func test_defaults_are_inert() -> void:
	var built: Dictionary = _core({})
	var core = built["core"]
	var m: Dictionary = built["match"]
	var expected_boss: float = maxf(float(m.get("swing_speed_mult", 1.0)), 0.01)
	ck("default cast_speed_mult leaves the player actor at 1.0",
		is_equal_approx(core.actor.duration_mult, 1.0), str(core.actor.duration_mult))
	ck("default leaves the boss actor at the match value",
		is_equal_approx(core.boss.get_actor().duration_mult, expected_boss), str(core.boss.get_actor().duration_mult))
	core.invulnerable = false
	var before: float = core.state.player_hp
	core._on_mire_damage(SimCore.PLAYER, 10.0)
	ck("default hazard_resist_mult takes the full 10", is_equal_approx(before - core.state.player_hp, 10.0),
		str(before - core.state.player_hp))
