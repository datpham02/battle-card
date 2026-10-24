extends SceneTree

var fails: int = 0
var reasons: Array[String] = []


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _on_ended(r: String) -> void:
	reasons.append(r)


func _initialize() -> void:
	var cfg := SkillConfig.from_json_text('{"focus": {"focus_time_scale": 0.0, "focus_max_sec": 4.0, "focus_cooldown_sec": 8.0, "focus_locks_movement": true}}')
	var f := FocusController.new(cfg)
	f.ended.connect(_on_ended)
	_check("starts READY", f.is_ready() and not f.is_active())
	f.end("confirmed")
	_check("end when not active is a no-op", f.is_ready() and reasons.is_empty())
	_check("try_start from READY", f.try_start() and f.is_active())
	_check("try_start while ACTIVE fails", not f.try_start())
	_check("time scale 0 passes through", f.get_time_scale() == 0.0)
	_check("locks movement", f.locks_movement())
	f.tick_real(3.9)
	_check("still active at 3.9", f.is_active() and absf(f.get_time_left() - 0.1) < 0.001)
	f.tick_real(0.2)
	_check("timeout ends it", not f.is_active() and reasons == ["timeout"], str(reasons))
	_check("cooldown 8.0", f.is_on_cooldown() and absf(f.get_cooldown_left() - 8.0) < 0.001)
	_check("try_start fails on cooldown", not f.try_start())
	f.tick_real(7.9)
	_check("not ready at 7.9", f.is_on_cooldown())
	f.tick_real(0.2)
	_check("READY after cooldown", f.is_ready())
	f.try_start()
	f.end("confirmed")
	_check("confirmed starts cooldown", f.is_on_cooldown() and reasons == ["timeout", "confirmed"])
	f.end("death")
	_check("end during cooldown no-op", reasons.size() == 2)
	var slow := SkillConfig.from_json_text('{"focus": {"focus_time_scale": 0.5}}')
	_check("scale 0.5 passes through", FocusController.new(slow).get_time_scale() == 0.5)
	var bad := SkillConfig.from_json_text('{"focus": {"focus_time_scale": "x", "focus_max_sec": -1, "focus_cooldown_sec": -3, "focus_locks_movement": 5}}')
	_check("bad data -> defaults", bad.focus_time_scale == 0.0 and bad.focus_max_sec == 4.0 and bad.focus_cooldown_sec == 8.0 and bad.focus_locks_movement)
	var clamp := SkillConfig.from_json_text('{"focus": {"focus_time_scale": 7}}')
	_check("scale clamped to 1", clamp.focus_time_scale == 1.0)
	var none := SkillConfig.from_json_text('{}')
	_check("missing focus -> defaults", none.focus_max_sec == 4.0)
	var file := SkillConfig.load_from_file()
	_check("cards.json focus loaded", file.focus_max_sec == 4.0 and file.focus_cooldown_sec == 8.0)
	print("FAILS=%d" % fails)
	quit(fails)
