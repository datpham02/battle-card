extends SceneTree

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _initialize() -> void:
	var cfg: RunConfig = RunConfig.load_from_file()
	var s := RunState.new(cfg)
	_check("4 matches", s.get_match_count() == 4)
	_check("initial INTRO idx0", s.get_phase() == RunState.Phase.INTRO and s.get_match_index() == 0)
	_check("carried negative at start", s.get_carried_hp() < 0.0)
	s.tick(5.0)
	_check("no tick in INTRO", s.get_elapsed_sec() == 0.0)
	var boss_flags: Array[bool] = []
	var hps: Array[float] = [30.0, 90.0, 60.0]
	for i: int in 3:
		_check("match %d not boss" % i, not s.is_boss_match())
		s.begin_playing()
		_check("PLAYING", s.get_phase() == RunState.Phase.PLAYING)
		s.tick(10.0)
		s.on_match_won(hps[i], 100.0)
		_check("BETWEEN %d" % i, s.get_phase() == RunState.Phase.BETWEEN)
		var want: float = minf(hps[i] + cfg.heal_between_matches, 100.0)
		_check("carry %d = %s" % [i, want], is_equal_approx(s.get_carried_hp(), want), str(s.get_carried_hp()))
		s.tick(5.0)
		s.advance()
		_check("next INTRO", s.get_phase() == RunState.Phase.INTRO and s.get_match_index() == i + 1)
	_check("last is boss", s.is_boss_match())
	s.begin_playing()
	s.on_match_won(50.0, 100.0)
	_check("WON", s.get_phase() == RunState.Phase.WON)
	_check("elapsed 30 (3x10, not in INTRO/BETWEEN)", is_equal_approx(s.get_elapsed_sec(), 30.0), str(s.get_elapsed_sec()))
	s.restart()
	_check("restart", s.get_match_index() == 0 and s.get_phase() == RunState.Phase.INTRO and s.get_elapsed_sec() == 0.0 and s.get_carried_hp() < 0.0)
	s.begin_playing()
	s.on_match_lost()
	_check("LOST", s.get_phase() == RunState.Phase.LOST)
	s.tick(3.0)
	_check("no tick when LOST", s.get_elapsed_sec() == 0.0)
	var t := RunState.new(cfg)
	t.begin_playing()
	t.tick(462.0)
	_check("text 7:42", t.get_elapsed_text() == "7:42", t.get_elapsed_text())
	t.tick(-462.0 + 5.0)
	_check("text 0:05", t.get_elapsed_text() == "0:05", t.get_elapsed_text())
	var bad: RunConfig = RunConfig.from_json_text("{nope")
	_check("bad json => 1 default match", bad.match_count() == 1 and bad.intro_sec > 0.0)
	var missing: RunConfig = RunConfig.load_from_file("res://nope.json")
	_check("missing => defaults", missing.match_count() == 1)
	var clamp: RunConfig = RunConfig.from_json_text('{"intro_sec": -3, "matches": [{"boss_max_hp": -5}]}')
	_check("clamp", clamp.intro_sec == 0.0 and float(clamp.matches[0]["boss_max_hp"]) > 0.0)
	var mono: bool = true
	for i: int in range(1, cfg.match_count()):
		var a: Dictionary = cfg.matches[i - 1]
		var b: Dictionary = cfg.matches[i]
		mono = mono and float(b["boss_max_hp"]) >= float(a["boss_max_hp"])
		mono = mono and float(b["boss_step_cooldown_mult"]) <= float(a["boss_step_cooldown_mult"])
		mono = mono and float(b["boss_think_interval_sec"]) <= float(a["boss_think_interval_sec"])
		mono = mono and float(b["boss_reaction_sec"]) <= float(a["boss_reaction_sec"])
		mono = mono and float(b["boss_drop_interval_mult"]) <= float(a["boss_drop_interval_mult"])
	_check("monotone difficulty", mono)
	var brain: BossBrainConfig = BossBrainConfig.load_from_file()
	var sets_ok: bool = true
	for m: Dictionary in cfg.matches:
		sets_ok = sets_ok and brain.has_set(str(m["brain_set"]))
	_check("brain sets exist", sets_ok)
	print("FAILS=%d" % fails)
	quit(fails)
