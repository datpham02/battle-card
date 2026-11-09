class_name AudioDirector
extends Node
## Skill v2 audio (docs/skill-v2/10-audio-system-design.md §2, §4, §6, §9): plays audio cues. Owns the [VoicePool], a
## fixed set of pre-created AudioStreamPlayers (no node per sound), the stream cache, the bus volumes and the duck,
## pause and the pending cues.
##
## Cues come from [AudioEventRules] through [method apply] (or [method play]). A cue may start:
## - now;
## - at an ARBITER clock time ([member clock_fn], [method SwingArbiter.clock]) minus the output-latency lead
##   ([method lead_sec]: AudioServer output latency clamped to timing.latency_lead_max_sec), so the transient lands on
##   the impact tick; it waits while the clock does not advance (pause, menus);
## - after a delay of LOCAL match time (advanced by [method advance], frozen while paused, scaled by
##   [member local_scale_fn]).
## Gameplay never reads the director, and the director never writes gameplay state or the global RNG (variants use its
## own RandomNumberGenerator): removing it changes nothing in a match.
##
## Like [SettingsStore]: inject an instance where it is needed, or use [method shared] in scenes. A SILENT director
## ([method silent]; also [method shared] when headless) runs the same pool logic and log but creates no player and
## never touches AudioServer or vibration: tests and the balance sim.

## Bus groups paused by [method set_paused] (UI keeps answering taps in the pause menu).
const PAUSABLE_BUSES: Array[String] = ["Skill", "Combat", "SFX", "Warning", "Ambience"]
## Buses stopped by a match end.
const COMBAT_BUSES: Array[String] = ["Skill", "Combat", "SFX", "Warning"]
## The play log keeps this many entries (oldest dropped).
const LOG_LIMIT: int = 512
## Percent at which a volume is muted.
const MUTE_PERCENT: int = 0

static var _shared: AudioDirector = null

## Returns the arbiter clock now (seconds); invalid = arbiter cues wait.
var clock_fn: Callable = Callable()
## Returns the match time scale for LOCAL delays (card menu slow motion); invalid = 1.
var local_scale_fn: Callable = Callable()
## Latency lead in seconds; < 0 = from AudioServer (see [method lead_sec]).
var lead_override: float = -1.0
## Reduced audio (settings): reducible events (ambience one-shots, aftermaths, skill-ready tones) are not played.
var reduced_audio: bool = false
## Vibration on cues with vibrate_ms (Critical warnings), Android only.
var vibration_enabled: bool = true
## Every play / merge / drop / vibrate, newest last (up to [constant LOG_LIMIT]).
var play_log: Array[Dictionary] = []

var _bank: AudioBank
var _pool: VoicePool
var _silent: bool
var _players: Array[AudioStreamPlayer] = []
var _handle_player: Dictionary = {}
var _streams: Dictionary = {}
var _pending: Array[Dictionary] = []
var _next_seq: int = 0
var _local: float = 0.0
var _paused: bool = false
var _background: bool = false
var _rng := RandomNumberGenerator.new()
var _volumes: Dictionary = {}
var _duck_left: float = 0.0


## A director on [param bank] (the game file when null); [param silent] = no players, no AudioServer.
func _init(bank: AudioBank = null, silent_mode: bool = false) -> void:
	_bank = bank if bank != null else AudioBank.load_from_file()
	_pool = VoicePool.new(_bank)
	_silent = silent_mode
	_rng.seed = 0x7E55E2A
	name = "AudioDirector"
	process_mode = Node.PROCESS_MODE_ALWAYS


## A silent director (tests, balance sim): same decisions and log, no sound.
static func silent(bank: AudioBank = null) -> AudioDirector:
	return AudioDirector.new(bank, true)


## The game's director, created on first use (silent when running headless). The caller adds it to the tree.
static func shared() -> AudioDirector:
	if _shared == null or not is_instance_valid(_shared):
		_shared = AudioDirector.new(null, DisplayServer.get_name() == "headless")
	return _shared


## Installs [param director] as the shared one (tests); null drops it.
static func set_shared(director: AudioDirector) -> void:
	_shared = director


## Drops the shared instance (tests).
static func reset_shared() -> void:
	_shared = null


func _exit_tree() -> void:
	if _shared == self:
		_shared = null


func _process(delta: float) -> void:
	advance(delta)


## True for a silent director.
func is_silent() -> bool:
	return _silent


## The bank this director plays from.
func get_bank() -> AudioBank:
	return _bank


## The voice pool (read-only use: tests, debug).
func get_pool() -> VoicePool:
	return _pool


## Local match time (seconds advanced while unpaused).
func local_time() -> float:
	return _local


## The latency lead of arbiter cues: [member lead_override] when >= 0, else AudioServer's output latency, clamped to
## [0, timing.latency_lead_max_sec].
func lead_sec() -> float:
	var max_lead: float = _bank.timing("latency_lead_max_sec", 0.08)
	var raw: float = lead_override if lead_override >= 0.0 else (0.0 if _silent else AudioServer.get_output_latency())
	return clampf(raw, 0.0, max_lead)


## Runs a list of [AudioEventRules] cues.
func apply(cues: Array[Dictionary]) -> void:
	for cue: Dictionary in cues:
		match str(cue.get("op", "")):
			"play":
				play(str(cue["id"]), cue)
			"at", "after":
				var entry: Dictionary = cue.duplicate()
				entry["seq"] = _next_seq
				_next_seq += 1
				if entry["op"] == "after":
					entry["due_local"] = _local + maxf(float(cue.get("delay", 0.0)), 0.0)
				_pending.append(entry)
			"stop":
				stop_tag(str(cue.get("tag", "")))
			"cancel":
				cancel_tag(str(cue.get("tag", "")))
			"stop_all":
				stop_buses(COMBAT_BUSES)
			"cancel_all":
				_pending.clear()
	_fire_due()


## Starts event [param id] now. [param params]: cells, tier, step, tag (see [method VoicePool.request]).
## Returns the voice handle, or [constant VoicePool.NO_VOICE] when dropped.
func play(id: String, params: Dictionary = {}) -> int:
	var def: Dictionary = _bank.get_event(id)
	if def.is_empty():
		_log({"op": "drop", "id": id, "reason": "unknown"}, params)
		return VoicePool.NO_VOICE
	if reduced_audio and bool(def.get("reducible", false)):
		_log({"op": "drop", "id": id, "reason": "reduced"}, params)
		return VoicePool.NO_VOICE
	if _background:
		_log({"op": "drop", "id": id, "reason": "background"}, params)
		return VoicePool.NO_VOICE
	var tier: String = str(params.get("tier", _bank.size_tier(int(params.get("cells", 1)))))
	var stream: AudioStream = _stream_for(id, tier)
	var duration: float = stream.get_length() if stream != null and stream.get_length() > 0.0 \
		else _bank.timing("default_sound_sec", 0.6)
	var req: Dictionary = params.duplicate()
	# An explicit tier is fixed; without one the pool may raise it when same-tick repeats merge.
	if not params.has("tier"):
		req.erase("tier")
	var r: Dictionary = _pool.request(id, _local, duration, req)
	for h: int in r["stolen"]:
		_stop_player(h)
	match str(r["action"]):
		"drop":
			_log({"op": "drop", "id": id, "reason": r["reason"]}, params)
			return VoicePool.NO_VOICE
		"merge":
			_log({"op": "merge", "id": id, "tier": r["tier"], "handle": r["handle"], "retier": r["retier"]}, params)
			if bool(r["retier"]):
				_start_player(int(r["handle"]), id, str(r["tier"]), params, true)
			return int(r["handle"])
	_log({"op": "play", "id": id, "tier": r["tier"], "handle": r["handle"]}, params)
	_start_player(int(r["handle"]), id, str(r["tier"]), params, false)
	if bool(def.get("duck", false)):
		_start_duck()
	var vib: int = int(def.get("vibrate_ms", 0))
	if vib > 0 and vibration_enabled:
		_log({"op": "vibrate", "id": id, "ms": vib}, params)
		if not _silent and OS.has_feature("mobile"):
			Input.vibrate_handheld(vib)
	return int(r["handle"])


## Advances the director by [param delta] real seconds: local time (unless paused), the duck, pool expiry and every
## cue that became due. Called by _process; tests call it with a fake clock.
func advance(delta: float) -> void:
	if not _paused and not _background:
		var scale: float = float(local_scale_fn.call()) if local_scale_fn.is_valid() else 1.0
		_local += maxf(delta, 0.0) * maxf(scale, 0.0)
	if _duck_left > 0.0:
		_duck_left -= delta
		if _duck_left <= 0.0:
			_apply_bus_volumes()
	for h: int in _pool.expire(_local):
		_handle_player.erase(h)
	_fire_due()


## Pending (not yet started) cues, oldest first (copies).
func pending() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in _pending:
		out.append(p.duplicate())
	return out


## Stops the playing voices tagged [param tag].
func stop_tag(tag: String) -> void:
	if tag.is_empty():
		return
	for h: int in _pool.release_tag(tag):
		_stop_player(h)


## Drops the pending cues tagged [param tag].
func cancel_tag(tag: String) -> void:
	if tag.is_empty():
		return
	for i: int in range(_pending.size() - 1, -1, -1):
		if str(_pending[i].get("tag", "")) == tag:
			_pending.remove_at(i)


## Stops every voice on [param buses] (every voice when empty).
func stop_buses(buses: Array[String] = []) -> void:
	for h: int in _pool.release_buses(buses):
		_stop_player(h)


## Drops every pending cue and stops every voice (a battle closes).
func reset_combat() -> void:
	_pending.clear()
	stop_buses(COMBAT_BUSES)
	clock_fn = Callable()
	local_scale_fn = Callable()


## Pauses (gameplay pause): combat voices hold, local time stops, arbiter cues wait. UI keeps playing.
func set_paused(paused: bool) -> void:
	_paused = paused
	_set_streams_paused()


## True while paused by [method set_paused].
func is_paused() -> bool:
	return _paused


## App in the background: every voice holds and nothing new starts.
func set_background(background: bool) -> void:
	_background = background
	_set_streams_paused()


## Applies the audio settings of [param store]: the five volumes, reduced audio, vibration.
func apply_settings(store: SettingsStore) -> void:
	for bus: String in _bank.volume_buses():
		_volumes[bus] = store.get_volume(bus)
	reduced_audio = store.get_reduced_audio()
	vibration_enabled = store.get_vibration()
	_apply_bus_volumes()


## Sets one bus volume in percent (0 = mute) and applies it.
func set_volume_percent(bus: String, percent: int) -> void:
	_volumes[bus] = clampi(percent, 0, 100)
	_apply_bus_volumes()


## The volume in dB a bus gets for [param percent] (0 % = -80 dB); pure.
static func percent_to_db(percent: int) -> float:
	if percent <= MUTE_PERCENT:
		return -80.0
	return linear_to_db(float(clampi(percent, 0, 100)) / 100.0)


## Seconds of duck still running.
func duck_left() -> float:
	return maxf(_duck_left, 0.0)


# --- internals ----------------------------------------------------------------


func _fire_due() -> void:
	if _pending.is_empty():
		return
	var clock_ok: bool = clock_fn.is_valid()
	var clock: float = float(clock_fn.call()) if clock_ok else 0.0
	var lead: float = lead_sec()
	var due: Array[Dictionary] = []
	for i: int in range(_pending.size() - 1, -1, -1):
		var p: Dictionary = _pending[i]
		var is_due: bool = false
		if p["op"] == "after":
			is_due = _local >= float(p["due_local"]) - 0.0000001
		elif clock_ok and not _paused:
			is_due = clock >= float(p["at"]) - lead - 0.0000001
		if is_due:
			due.append(p)
			_pending.remove_at(i)
	due.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["seq"]) < int(b["seq"]))
	for p: Dictionary in due:
		play(str(p["id"]), p)


func _log(entry: Dictionary, params: Dictionary) -> void:
	entry["local"] = _local
	entry["clock"] = float(clock_fn.call()) if clock_fn.is_valid() else -1.0
	for k: String in ["at", "step", "tag", "cells"]:
		if params.has(k):
			entry[k] = params[k]
	if not entry.has("tier") and params.has("tier"):
		entry["tier"] = params["tier"]
	play_log.append(entry)
	if play_log.size() > LOG_LIMIT:
		play_log.remove_at(0)


func _stream_for(id: String, tier: String) -> AudioStream:
	if _silent:
		return null
	var files: Array[String] = _bank.files_for(id, tier)
	if files.is_empty():
		return null
	var path: String = files[_rng.randi_range(0, files.size() - 1)]
	if not _streams.has(path):
		var s: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
		# Loop events are imported as forward loops (sfx_synth.py --qoa); force one only if the import did not.
		if s is AudioStreamWAV and bool(_bank.get_event(id).get("loop", false)) \
				and (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
			var wav := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
			s = wav
		_streams[path] = s
	return _streams[path]


func _ensure_players() -> void:
	if _silent or not _players.is_empty():
		return
	for i: int in maxi(_bank.voice_cap("total"), 1):
		var p := AudioStreamPlayer.new()
		p.name = "Voice%02d" % i
		add_child(p)
		_players.append(p)


func _start_player(handle: int, id: String, tier: String, params: Dictionary, restart: bool) -> void:
	if _silent:
		return
	_ensure_players()
	var player: AudioStreamPlayer = _handle_player.get(handle, null)
	if player == null:
		for p: AudioStreamPlayer in _players:
			if not _handle_player.values().has(p):
				player = p
				break
	if player == null:
		return
	var stream: AudioStream = _stream_for(id, tier)
	if stream == null:
		_handle_player[handle] = player
		return
	var def: Dictionary = _bank.get_event(id)
	var step: int = int(params.get("step", 0))
	var jitter: float = float(def.get("pitch_semitones", 0.0))
	var semis: float = _rng.randf_range(-jitter, jitter) + float(def.get("step_pitch_semitones", 0.0)) * step
	var gj: float = float(def.get("gain_jitter_db", 0.0))
	var db: float = float(def.get("gain_db", 0.0)) + _rng.randf_range(-gj, gj) + float(def.get("step_gain_db", 0.0)) * step
	if not _bank.has_tier_files(id):
		db += _bank.tier_gain_db(tier)
	player.stream = stream
	player.bus = StringName(str(def.get("bus", "Master")))
	player.volume_db = db
	player.pitch_scale = pow(2.0, semis / 12.0)
	_handle_player[handle] = player
	if not player.is_inside_tree():
		return
	if restart or not player.playing:
		player.play()
	player.stream_paused = _background or (_paused and PAUSABLE_BUSES.has(str(def.get("bus", ""))))


func _stop_player(handle: int) -> void:
	var player: AudioStreamPlayer = _handle_player.get(handle, null)
	_handle_player.erase(handle)
	if player != null:
		player.stop()


func _set_streams_paused() -> void:
	for p: AudioStreamPlayer in _players:
		p.stream_paused = _background or (_paused and PAUSABLE_BUSES.has(str(p.bus)))


func _start_duck() -> void:
	_duck_left = float(_bank.duck().get("sec", 0.0))
	_apply_bus_volumes()


func _apply_bus_volumes() -> void:
	if _silent:
		return
	var duck_db: Dictionary = _bank.duck().get("buses_db", {}) if _duck_left > 0.0 else {}
	for bus: String in _bank.bus_names():
		var idx: int = AudioServer.get_bus_index(StringName(bus))
		if idx < 0:
			continue
		var db: float = percent_to_db(int(_volumes.get(bus, 100))) if _volumes.has(bus) else 0.0
		db += float(duck_db.get(bus, 0.0))
		AudioServer.set_bus_volume_db(idx, db)
		AudioServer.set_bus_mute(idx, _volumes.has(bus) and int(_volumes[bus]) <= MUTE_PERCENT)
