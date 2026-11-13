extends SceneTree
## EnemySkillsConfig loader / validator (phase 2 spec P2.2, section 10 bullet 1; ADR-0001 D7 / A4).
## Covers: fixture data loads with no problems; refusals with clear messages (no delivery -> refused, never SKY;
## unknown anchor; followup below 0.75 s; unknown status; bad rotation); enemies referencing refused skills drop them;
## phase thresholds must fall; per-phase overrides; per-enemy ai override; data-driven defaults; a 1-phase shorthand.
## Pure logic: no file I/O (dictionaries built in code).
## Run: godot --headless --path . -s res://tests/unit/combat/enemy_skills_config_test.gd

const Fx = preload("res://tests/unit/combat/pattern_fixtures.gd")

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_fixture_loads_clean()
	test_refusals()
	test_enemy_validation()
	test_overrides_and_defaults()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _has_problem(c: EnemySkillsConfig, needle: String) -> bool:
	for p: String in c.problems:
		if p.contains(needle):
			return true
	return false


func test_fixture_loads_clean() -> void:
	var c: EnemySkillsConfig = Fx.config()
	_check("fixture: no problems", c.problems.is_empty(), str(c.problems))
	_check("fixture: 9 skills", c.skills.size() == 9)
	_check("fixture: 3x7 enemy has 3 phases", (c.get_enemy("fx3x7")["phases"] as Array).size() == 3)
	_check("fixture: 4x9 enemy last phase has 9 skills", ((c.get_enemy("fx4x9")["phases"] as Array)[3]["skills"] as Array).size() == 9)
	var fx2: Dictionary = c.skills["fx_2"]
	_check("delivery normalized", str((fx2["delivery"] as Dictionary)["type"]) == "CASTER_TO_TARGET")
	_check("rotations parsed", (fx2["pattern"] as Dictionary)["rotations"] == [0, 90, 180, 270])
	_check("on_player must cover player by default", bool((fx2["pattern"] as Dictionary)["must_cover_player"]))
	_check("root default sec from data", is_equal_approx(float(c.skills["fx_1"]["effects"]["status"]["sec"]), 0.6))
	_check("slow default from statuses", is_equal_approx(float(c.skills["fx_5"]["effects"]["status"]["step_mult"]), 1.3) \
		and is_equal_approx(float(c.skills["fx_5"]["effects"]["status"]["sec"]), 1.5))


func test_refusals() -> void:
	var skills: Dictionary = Fx.skills()
	var bad: Dictionary = (skills["fx_1"] as Dictionary).duplicate(true)
	bad.erase("delivery")
	skills["no_delivery"] = bad
	var anchor_bad: Dictionary = (skills["fx_1"] as Dictionary).duplicate(true)
	anchor_bad["pattern"] = {"offsets": [[0, 0]], "anchor": "on_moon"}
	skills["bad_anchor"] = anchor_bad
	var short_fu: Dictionary = (skills["fx_7"] as Dictionary).duplicate(true)
	(short_fu["followup"] as Dictionary)["warning_sec"] = 0.5
	skills["short_followup"] = short_fu
	var bad_status: Dictionary = (skills["fx_1"] as Dictionary).duplicate(true)
	# Monster Skill Phase 0 made `poison` a real status; `plague` stays unknown.
	bad_status["effects"] = {"damage": 5, "status": {"id": "plague", "sec": 2}}
	skills["bad_status"] = bad_status
	var bad_rot: Dictionary = (skills["fx_2"] as Dictionary).duplicate(true)
	(bad_rot["pattern"] as Dictionary)["rotations"] = [45]
	skills["bad_rot"] = bad_rot
	var no_warn: Dictionary = (skills["fx_1"] as Dictionary).duplicate(true)
	no_warn.erase("warning_sec")
	skills["no_warning"] = no_warn
	var bad_type: Dictionary = (skills["fx_1"] as Dictionary).duplicate(true)
	bad_type["delivery"] = {"type": "TELEPORT"}
	skills["bad_type"] = bad_type
	var c: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"skills": skills, "enemies": {"e": {"skills": ["fx_1", "no_delivery"]}}})
	_check("no delivery refused", not c.skills.has("no_delivery") and _has_problem(c, "no_delivery: no delivery"))
	_check("never patched to SKY", not c.skills.has("no_delivery"))
	_check("unknown anchor refused", not c.skills.has("bad_anchor") and _has_problem(c, "anchor 'on_moon' unknown"))
	_check("short followup refused", not c.skills.has("short_followup") and _has_problem(c, "below fairness.followup_min_warning_sec"))
	_check("unknown status refused", not c.skills.has("bad_status") and _has_problem(c, "status id 'plague' unknown"))
	_check("bad rotation refused", not c.skills.has("bad_rot") and _has_problem(c, "45 not in 0/90/180/270"))
	_check("attack without warning refused", not c.skills.has("no_warning") and _has_problem(c, "needs warning_sec"))
	_check("unknown delivery type refused", not c.skills.has("bad_type") and _has_problem(c, "delivery type 'TELEPORT'"))
	_check("enemy drops refused skill", (c.get_enemy("e")["phases"] as Array)[0]["skills"] == ["fx_1"] and _has_problem(c, "skill 'no_delivery' unknown or refused"))
	_check("good skills kept", c.skills.has("fx_1") and c.skills.has("fx_9"))


func test_enemy_validation() -> void:
	var c: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"skills": Fx.skills(), "enemies": {
		"rising": {"phases": [{"id": "a", "skills": ["fx_1"]}, {"id": "b", "enter_hp_ratio": 0.5, "skills": ["fx_2"]},
			{"id": "c", "enter_hp_ratio": 0.7, "skills": ["fx_3"]}]},
		"empty": {"phases": []},
		"bad_nth": {"phases": [{"id": "a", "skills": ["fx_1"], "every_nth": {"skill": "fx_9", "n": 3}}]},
	}})
	_check("rising threshold phase refused", (c.get_enemy("rising")["phases"] as Array).size() == 2 and _has_problem(c, "phase c enter_hp_ratio"))
	_check("enemy without phases refused", c.get_enemy("empty").is_empty() and _has_problem(c, "enemy empty: no usable phase"))
	_check("every_nth must name a phase skill", ((c.get_enemy("bad_nth")["phases"] as Array)[0]["every_nth"] as Dictionary).is_empty())
	var t: Dictionary = (c.get_enemy("rising")["phases"] as Array)[1]["transition"]
	_check("transition sec defaults to data 1.5 (D14)", is_equal_approx(float(t["sec"]), 1.5))


func test_overrides_and_defaults() -> void:
	var data: Dictionary = Fx.data({"o": {"ai": {"noise": 0.0}, "phases": [
		{"id": "a", "skills": ["fx_1", "fx_4"], "overrides": {"fx_4": {"count": 2}, "fx_1": {"effects": {"damage": 20}}}}]}})
	data["defaults"] = {"windup_sec": 0.7}
	data["skills"]["plain"] = {"pattern": {"offsets": [[0, 0]]}, "warning_sec": 1.0, "delivery": Fx.DM, "effects": {"damage": 1}}
	var c: EnemySkillsConfig = EnemySkillsConfig.from_dictionary(data)
	var phase: Dictionary = (c.get_enemy("o")["phases"] as Array)[0]
	_check("override count", int((c.skill_for_phase("fx_4", phase)["pattern"] as Dictionary)["count"]) == 2)
	_check("override nested damage", is_equal_approx(float(c.skill_for_phase("fx_1", phase)["effects"]["damage"]), 20.0))
	_check("override does not leak to base", is_equal_approx(float(c.skills["fx_1"]["effects"]["damage"]), 8.0))
	_check("per-enemy ai override", is_equal_approx(float(c.get_enemy("o")["ai"]["noise"]), 0.0) and is_equal_approx(float(c.get_enemy("o")["ai"]["punish_standing_still"]), 1.2))
	_check("data default windup", is_equal_approx(float(c.skills["plain"]["windup_sec"]), 0.7))
	_check("default interruptible true (D9)", bool(c.skills["plain"]["interruptible"]))
	_check("fx_5 non-interruptible", not bool(c.skills["fx_5"]["interruptible"]))
	var single: EnemySkillsConfig = Fx.config()
	_check("1-phase shorthand", (single.get_enemy("fx_single")["phases"] as Array).size() == 1)
