extends SceneTree
## Monster Skill Phase 1 groups A + B + C + D: for each Dấu Tro enemy (imp, ember_hound, ash_golem) on the arena of its OWN hellfire
## chapters.json match (ArenaLibrary, seeded variants where the match asks for one), a headless 60 s match per seed through
## PatternController with the real StatusEffects / UnitMover: the perfect dodger takes 0 damage FROM SKILLS (no TileHazards
## are wired, so the forge / caldera vents, which are terrain, never count), the standing-still bot is damaged, and every
## skill of every enemy fires at least once over the seeds. The hellfire matches must carry `brain: pattern` + `enemy`.
## Run: godot --headless --path . -s res://tests/integration/run/pattern_hellfire_dodge_test.gd

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const ENEMIES: Array[String] = ["imp", "ember_hound", "ash_golem", "flame_cultist", "magma_slug", "hell_knight", "fire_eater", "ash_phoenix", "inferno_lord"]
const SEEDS: Array[int] = [1, 2, 3]
const MATCH_SEC: float = 60.0
const START_HP: float = 300.0
const AIM_EVERY_SEC: float = 1.5

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	var cfg: EnemySkillsConfig = EnemySkillsConfig.load_from_file()
	_check("shipped enemy_skills.json has no problems", cfg.problems.is_empty(), str(cfg.problems))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chapters.json"))
	var hellfire: Dictionary = {}
	for chapter: Variant in data["chapters"]:
		if str((chapter as Dictionary).get("id", "")) == "hellfire":
			hellfire = chapter
	var library: ArenaLibrary = ArenaLibrary.load_from_file()
	for enemy_id: String in ENEMIES:
		var match_def: Dictionary = (hellfire["matches"] as Dictionary).get(enemy_id, {}) as Dictionary
		var spec: Dictionary = match_def.get("arena", {}) as Dictionary
		_check("%s has a hellfire arena" % enemy_id, not spec.is_empty())
		_check("%s match runs the pattern brain with its own enemy id" % enemy_id,
			str(match_def.get("brain", "")) == "pattern" and str(match_def.get("enemy", "")) == enemy_id, str(match_def.get("brain", "")))
		var fired: Dictionary = {}
		for s: int in SEEDS:
			var key: String = "%s/%s/%d" % [enemy_id, str(spec.get("shape", "")), s]
			var dodge: Dictionary = _play(cfg, enemy_id, ArenaLibrary.grid_for_spec(spec, library, s), s, "dodge")
			var dstate: CombatState = dodge["state"]
			_check("%s dodger takes 0 damage in %d s" % [key, int(MATCH_SEC)], is_equal_approx(dstate.player_hp, START_HP),
				"hp=%.1f hits=%s" % [dstate.player_hp, str(_hits(dodge["ctrl"]))])
			for ev: Dictionary in (dodge["ctrl"] as PatternController).event_log:
				if str(ev.get("event", "")) == "resolve":
					fired[str(ev["skill"])] = true
			var still: Dictionary = _play(cfg, enemy_id, ArenaLibrary.grid_for_spec(spec, library, s), s, "still")
			_check("%s standing still is damaged" % key, (still["state"] as CombatState).player_hp < START_HP,
				"hp=%.1f" % (still["state"] as CombatState).player_hp)
		var skills: Array[String] = []
		for phase: Dictionary in cfg.get_enemy(enemy_id)["phases"]:
			for sid: String in phase["skills"]:
				skills.append(sid)
		var silent: Array[String] = skills.filter(func(sid: String) -> bool: return not fired.has(sid))
		_check("%s: every skill fired in the dodger matches" % enemy_id, silent.is_empty(), "silent=%s" % str(silent))
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _play(cfg: EnemySkillsConfig, enemy_id: String, grid: BoardGrid, seed_value: int, bot: String) -> Dictionary:
	var w: Dictionary = Fx.world(grid, cfg, enemy_id, seed_value, 1000.0)
	var state: CombatState = w["state"]
	state.player_hp = START_HP
	state.player_max_hp = START_HP
	var ctrl: PatternController = w["ctrl"]
	var next_aim: Array[float] = [AIM_EVERY_SEC]
	var hurt: Array[bool] = [false]
	var on_tick: Callable = func(t: float) -> void:
		if t >= next_aim[0]:
			next_aim[0] += AIM_EVERY_SEC
			ctrl.on_player_aim(state.enemy_footprint_cells())
		# Group B / C / D: the Knight's bulwark, the Phoenix's pyre and the Inferno Lord's phase 2 need < 50 % HP.
		if (enemy_id == "hell_knight" or enemy_id == "ash_phoenix" or enemy_id == "inferno_lord") and t >= MATCH_SEC * 0.5 and not hurt[0]:
			hurt[0] = true
			state.enemy_hp = state.enemy_max_hp * 0.45
	Fx.run(ctrl, state, w["status"], w["mover"], MATCH_SEC, bot, 0.05, on_tick)
	return w


func _hits(ctrl: PatternController) -> Array:
	var out: Array = []
	for ev: Dictionary in ctrl.event_log:
		if bool(ev.get("hit", false)):
			out.append("%s@%.2f" % [ev["skill"], float(ev["t"])])
	return out
