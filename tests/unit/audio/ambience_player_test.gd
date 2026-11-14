extends SceneTree
## Region ambience player (docs/design/audio/ambience-plan.md), headless with a silent player: region beds crossfade,
## unknown regions fade to silence, a fight lowers the bed and stops one-shots, Reduced audio stops one-shots, one-shots
## come at the data's gaps, background freezes everything; and the game data: every region has a bed and 2 one-shots,
## every file exists and every bed loads as a looping OGG.
## Run: godot --headless --path . -s res://tests/unit/audio/ambience_player_test.gd

const Ambience: GDScript = preload("res://src/audio/ambience_player.gd")
const FADE: float = 2.0
const GAP_MIN: float = 10.0
const GAP_MAX: float = 20.0
const BATTLE_DB: float = -6.0

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_run()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _bank() -> AudioBank:
	return AudioBank.new({"ambience": {"fade_sec": FADE, "battle_db": BATTLE_DB, "battle_fade_sec": 1.0,
		"gap_min_sec": GAP_MIN, "gap_max_sec": GAP_MAX, "regions": {
			"ch1": {"bed": "a.ogg", "oneshots": ["bird.ogg", "drip.ogg"]},
			"ch2": {"bed": "b.ogg", "oneshots": ["chain.ogg"]}}}})


func _gain(a: Node, region: String) -> float:
	for v: Dictionary in a.beds():
		if v["region"] == region:
			return float(v["gain"])
	return -1.0


func _step(a: Node, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.0001:
		a.advance(0.1)
		t += 0.1


func _run() -> void:
	var a: Node = Ambience.new(_bank(), true)
	ck("starts silent", a.current_region() == "" and a.beds().all(func(v: Dictionary) -> bool: return v["region"] == ""))
	a.set_region("ch1")
	_step(a, FADE)
	ck("a region's bed fades in to full", a.current_region() == "ch1" and is_equal_approx(_gain(a, "ch1"), 1.0))
	a.set_region("ch2")
	_step(a, FADE / 2.0)
	ck("half way through a region change both beds sound", _gain(a, "ch1") > 0.0 and _gain(a, "ch1") < 1.0
		and _gain(a, "ch2") > 0.0, str(a.beds()))
	_step(a, FADE)
	ck("after the crossfade only the new bed sounds", _gain(a, "ch1") < 0.0 and is_equal_approx(_gain(a, "ch2"), 1.0))
	a.set_region("nowhere")
	_step(a, FADE)
	ck("a region without ambience fades to silence", a.current_region() == "" and _gain(a, "ch2") < 0.0)
	a.free()

	# one-shots
	var b: Node = Ambience.new(_bank(), true)
	b.set_region("ch1")
	var first_gap: float = b.gap_left()
	ck("the first one-shot waits a gap from the data", first_gap >= GAP_MIN and first_gap <= GAP_MAX, str(first_gap))
	_step(b, 120.0)
	var n: int = b.oneshot_log.size()
	ck("two minutes outside a fight bring %d one-shots (between 120/max and 120/min)" % n, n >= 120 / int(GAP_MAX) and n <= 120 / int(GAP_MIN) + 1)
	ck("one-shots come from the region's list", b.oneshot_log.all(func(e: Dictionary) -> bool:
		return e["region"] == "ch1" and e["file"] in ["bird.ogg", "drip.ogg"]))
	b.set_battle(true)
	_step(b, 1.0)
	ck("a fight lowers the bed by battle_db", is_equal_approx(_gain(b, "ch1"), db_to_linear(BATTLE_DB)), str(_gain(b, "ch1")))
	var during: int = b.oneshot_log.size()
	_step(b, 120.0)
	ck("no one-shot during a fight", b.oneshot_log.size() == during)
	b.set_battle(false)
	_step(b, 1.0)
	ck("after the fight the bed comes back to full", is_equal_approx(_gain(b, "ch1"), 1.0))
	b.set_reduced(true)
	var reduced: int = b.oneshot_log.size()
	_step(b, 120.0)
	ck("Reduced audio: no one-shot", b.oneshot_log.size() == reduced)
	b.set_reduced(false)
	b.set_background(true)
	var bg: int = b.oneshot_log.size()
	var gap_bg: float = b.gap_left()
	_step(b, 120.0)
	ck("backgrounded: nothing moves", b.oneshot_log.size() == bg and is_equal_approx(b.gap_left(), gap_bg))
	b.set_background(false)
	b.free()
	var c: Node = Ambience.new(_bank(), true)
	var d: Node = Ambience.new(_bank(), true)
	c.set_region("ch1")
	d.set_region("ch1")
	_step(c, 90.0)
	_step(d, 90.0)
	ck("same seed, same one-shots (deterministic)", str(c.oneshot_log) == str(d.oneshot_log) and not c.oneshot_log.is_empty())
	c.free()
	d.free()

	# the game data
	var bank := AudioBank.load_from_file()
	var errs: Array[String] = bank.validate(true)
	ck("the game data validates (ambience files included)", errs.is_empty(), str(errs.slice(0, 5)))
	var regions: Dictionary = bank.ambience().get("regions", {})
	var rules: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/region_rules.json"))
	var known: Dictionary = (rules as Dictionary).get("regions", {}) if rules is Dictionary else {}
	ck("every real region has ambience", known.keys().all(func(r: Variant) -> bool: return regions.has(str(r))),
		str(known.keys()))
	var real: Node = Ambience.new(bank, false)
	for r: String in regions.keys():
		var bed: AudioStream = real._stream(str(regions[r]["bed"]), true)
		ck("%s: a looping OGG bed and 2 one-shots" % r, bed is AudioStreamOggVorbis and (bed as AudioStreamOggVorbis).loop
			and (regions[r]["oneshots"] as Array).size() == 2 and bed.get_length() > 10.0)
	real.free()
