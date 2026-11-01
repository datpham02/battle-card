extends SceneTree
## Phase 2 P2.2 (spec design/quick-specs/phase2-misty-forest-2026-11-01.md): the SHIPPED enemy_skills.json loads clean,
## no chapters.json match plays a `dev` enemy, and on every ch1 arena (chapters.json -> arenas.json, the real
## ArenaLibrary board, a few seeds) the dev fixture enemy `dev_pattern_dummy` leaves the perfect-dodger bot untouched and
## damages the standing-still bot. Runs the PatternController path with the real StatusEffects / UnitMover (CombatView
## adds the BossBrain's own cuts and the match traits, which would make "0 damage" a test of other systems).
## Run: godot --headless --path . -s res://tests/integration/run/pattern_dodge_test.gd

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const ENEMY: String = "dev_pattern_dummy"
const SEEDS: Array[int] = [1, 2, 3]
const MATCH_SEC: float = 30.0
const START_HP: float = 100.0

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	var cfg: EnemySkillsConfig = EnemySkillsConfig.load_from_file()
	_check("shipped enemy_skills.json has no problems", cfg.problems.is_empty(), str(cfg.problems))
	_check("dev enemy present", not cfg.get_enemy(ENEMY).is_empty())
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chapters.json"))
	var dev_used: Array[String] = []
	var ch1_arenas: Array[Dictionary] = []
	for chapter: Variant in data.get("chapters", []):
		var matches: Variant = (chapter as Dictionary).get("matches", {})
		var list: Array = (matches as Dictionary).values() if typeof(matches) == TYPE_DICTIONARY else matches as Array
		for m: Variant in list:
			var md: Dictionary = m as Dictionary
			var enemy_id: String = str(md.get("enemy", ""))
			if not enemy_id.is_empty() and bool(cfg.get_enemy(enemy_id).get("dev", false)):
				dev_used.append(str(md.get("id", "")))
			if str((chapter as Dictionary).get("id", "")) == "ch1" and md.has("arena"):
				ch1_arenas.append(md["arena"] as Dictionary)
	_check("no chapters.json match plays a dev enemy", dev_used.is_empty(), str(dev_used))
	_check("ch1 arenas found", not ch1_arenas.is_empty())
	var library: ArenaLibrary = ArenaLibrary.load_from_file()
	var seen: Dictionary = {}
	for spec: Dictionary in ch1_arenas:
		for s: int in SEEDS:
			var grid: BoardGrid = ArenaLibrary.grid_for_spec(spec, library, s)
			var key: String = "%s/%d" % [str(spec.get("shape", "")), s]
			if grid == null or seen.has(key):
				continue
			seen[key] = true
			var dodge: Dictionary = Fx.world(grid, cfg, ENEMY, s, START_HP)
			Fx.run(dodge["ctrl"], dodge["state"], dodge["status"], dodge["mover"], MATCH_SEC, "dodge")
			_check("%s dodger untouched" % key, is_equal_approx((dodge["state"] as CombatState).player_hp, START_HP),
				"hp=%s events=%d" % [(dodge["state"] as CombatState).player_hp, (dodge["ctrl"] as PatternController).event_log.size()])
			var still: Dictionary = Fx.world(ArenaLibrary.grid_for_spec(spec, library, s), cfg, ENEMY, s, START_HP)
			Fx.run(still["ctrl"], still["state"], still["status"], still["mover"], MATCH_SEC, "still")
			_check("%s standing still is damaged" % key, (still["state"] as CombatState).player_hp < START_HP,
				"hp=%s" % (still["state"] as CombatState).player_hp)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)
