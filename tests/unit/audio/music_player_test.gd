extends SceneTree
## MusicPlayer (docs/design/audio/music-plan.md), headless with a silent player: which track a flow state wants,
## crossfades, resume position (explore ↔ battle do not restart), the stinger hold, unknown ids, background; and the
## game data: every track file exists, loop tracks loop from loop_start inside the file, stingers do not loop.
## Run: godot --headless --path . -s res://tests/unit/audio/music_player_test.gd

const XFADE: float = 1.5
const HOLD: float = 7.0

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
	var tracks: Dictionary = {}
	for id: String in ["explore", "battle", "boss", "victory", "defeat"]:
		tracks[id] = {"file": "res://x/%s.ogg" % id, "loop_start": -1.0 if id in ["victory", "defeat"] else 1.0}
	return AudioBank.new({"music": {"crossfade_sec": XFADE, "stop_fade_sec": 0.5, "stinger_hold_sec": HOLD,
		"tracks": tracks}})


func _gain(m: MusicPlayer, track: String) -> float:
	for v: Dictionary in m.voices():
		if v["track"] == track:
			return float(v["gain"])
	return -1.0


func _step(m: MusicPlayer, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.0001:
		m.advance(0.1)
		t += 0.1


func _run() -> void:
	# track_for
	ck("outside a match the flow wants explore", MusicPlayer.track_for(false, "boss") == "explore")
	ck("a fought boss node wants boss", MusicPlayer.track_for(true, GameFlow.KIND_BOSS) == "boss")
	ck("any other fought node wants battle", MusicPlayer.track_for(true, "miniboss") == "battle"
		and MusicPlayer.track_for(true, "") == "battle")

	# crossfade explore -> battle
	var m := MusicPlayer.new(_bank(), true)
	m.request("explore")
	_step(m, XFADE)
	ck("explore fades in to full over the crossfade", m.current_track() == "explore" and is_equal_approx(_gain(m, "explore"), 1.0))
	_step(m, 10.0)
	m.request("battle")
	_step(m, XFADE / 2.0)
	ck("half way, explore is fading out and battle in", _gain(m, "explore") > 0.0 and _gain(m, "explore") < 1.0
		and _gain(m, "battle") > 0.0 and _gain(m, "battle") < 1.0, str(m.voices()))
	_step(m, XFADE)
	ck("after the crossfade only battle sounds", m.current_track() == "battle" and is_equal_approx(_gain(m, "battle"), 1.0)
		and _gain(m, "explore") < 0.0, str(m.voices()))
	var explore_at: float = m.position_of("explore")
	ck("explore remembers where it was left", explore_at >= 11.0, str(explore_at))
	m.request("explore")
	_step(m, XFADE)
	ck("going back to explore resumes it, not from 0", m.position_of("explore") >= explore_at)
	m.request("explore")
	ck("asking for the playing track changes nothing", m.current_track() == "explore" and is_equal_approx(_gain(m, "explore"), 1.0))

	# stinger
	m.request("battle")
	_step(m, XFADE)
	m.play_stinger(true)
	ck("a won match plays the victory stinger at once", is_equal_approx(_gain(m, "victory"), 1.0) and m.current_track() == ""
		and is_equal_approx(m.hold_left(), HOLD))
	_step(m, 0.6)
	ck("the battle loop fades out fast under the stinger", _gain(m, "battle") < 0.0, str(m.voices()))
	m.request("explore")
	_step(m, 1.0)
	ck("a request during the hold waits", m.current_track() == "" and m.wanted_track() == "explore")
	_step(m, HOLD + XFADE)
	ck("after the hold the wanted track comes back", m.current_track() == "explore" and _gain(m, "victory") < 0.0)
	m.play_stinger(false)
	ck("a lost match plays the defeat stinger", is_equal_approx(_gain(m, "defeat"), 1.0))

	# unknown / silence / background
	var n := MusicPlayer.new(_bank(), true)
	n.request("explore")
	n.request("nope")
	ck("an unknown track is ignored", n.current_track() == "explore" and n.wanted_track() == "explore")
	n.request("")
	_step(n, XFADE)
	ck("NONE fades to silence", n.current_track() == "" and n.voices().all(func(v: Dictionary) -> bool: return v["track"] == ""))
	n.request("explore")
	n.set_background(true)
	_step(n, 5.0)
	ck("nothing moves while backgrounded", is_equal_approx(_gain(n, "explore"), 0.0))
	n.set_background(false)
	n.free()
	m.free()

	# the game data
	var bank := AudioBank.load_from_file()
	var errs: Array[String] = bank.validate(true)
	ck("the game data validates (music files included)", errs.is_empty(), str(errs.slice(0, 5)))
	var tracks: Dictionary = bank.music().get("tracks", {})
	for id: String in ["explore", "battle", "boss", "victory", "defeat"]:
		ck("music has track %s" % id, tracks.has(id))
	var real := MusicPlayer.new(bank, false)
	for id: String in tracks.keys():
		var s: AudioStream = real._stream_for(id)
		var ls: float = float(tracks[id].get("loop_start", -1.0))
		var ok: bool = s is AudioStreamOggVorbis
		if ok and ls >= 0.0:
			ok = (s as AudioStreamOggVorbis).loop and is_equal_approx((s as AudioStreamOggVorbis).loop_offset, ls) \
				and ls < s.get_length() - 30.0
		elif ok:
			ok = not (s as AudioStreamOggVorbis).loop
		ck("track %s loads as OGG and %s" % [id, "loops from %.3f s" % ls if ls >= 0.0 else "does not loop"], ok,
			"len=%.1f" % (s.get_length() if s != null else -1.0))
	real.free()
