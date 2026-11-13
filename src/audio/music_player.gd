class_name MusicPlayer
extends Node
## Music MVP (docs/design/audio/music-plan.md): one looping track per flow state on the Music bus, crossfaded, plus the
## victory / defeat stingers. Data: the [code]music[/code] section of audio_events.json ([method AudioBank.music]).
## Gameplay never calls it: [AudioRig] asks for the track the flow state wants ([method request]) and plays the
## stinger when a match ends ([method play_stinger]).
## A track left and later asked for again resumes where it was (explore ↔ battle do not restart). A silent player
## (headless, tests) keeps the same decisions and a simulated clock but creates no AudioStreamPlayer.

## No track (silence).
const NONE: String = ""
const EXPLORE: String = "explore"
const BATTLE: String = "battle"
const BOSS: String = "boss"
const VICTORY: String = "victory"
const DEFEAT: String = "defeat"
## Gain under which a fading voice is stopped (linear).
const OFF_GAIN: float = 0.001

var _bank: AudioBank
var _silent: bool = false
var _settings: Dictionary = {}
var _tracks: Dictionary = {}
## Two voices for the crossfade: {track, gain, target, rate, player}.
var _voices: Array[Dictionary] = []
var _current: String = NONE
var _wanted: String = NONE
var _hold_left: float = 0.0
var _positions: Dictionary = {}
var _background: bool = false
var _streams: Dictionary = {}


## A player on [param bank] (the game data when null); [param silent_mode] = no AudioStreamPlayers.
func _init(bank: AudioBank = null, silent_mode: bool = false) -> void:
	_bank = bank if bank != null else AudioBank.load_from_file()
	_silent = silent_mode
	_settings = _bank.music()
	_tracks = _settings.get("tracks", {}) if _settings.get("tracks", {}) is Dictionary else {}
	name = "MusicPlayer"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in 2:
		_voices.append({"track": NONE, "gain": 0.0, "target": 0.0, "rate": 0.0, "player": null})


func _ready() -> void:
	if _silent:
		return
	for v: Dictionary in _voices:
		var p := AudioStreamPlayer.new()
		p.bus = &"Music"
		add_child(p)
		v["player"] = p


func _process(delta: float) -> void:
	advance(delta)


## The track a flow state wants: [param in_battle] (a match is being fought) → boss for a boss node, else battle;
## anything else → explore. Pure.
static func track_for(in_battle: bool, node_kind: String) -> String:
	if in_battle:
		return BOSS if node_kind == GameFlow.KIND_BOSS else BATTLE
	return EXPLORE


## True when the data has track [param id].
func has_track(id: String) -> bool:
	return _tracks.has(id)


## The track playing (or fading in) now; [constant NONE] when silent or during a stinger hold.
func current_track() -> String:
	return _current


## The track that will play once the stinger hold is over.
func wanted_track() -> String:
	return _wanted


## Seconds the stinger still holds the loops back.
func hold_left() -> float:
	return _hold_left


## Where track [param id] resumes (seconds into the file), 0 when never played.
func position_of(id: String) -> float:
	return float(_positions.get(id, 0.0))


## The voices as {track, gain, target} (tests).
func voices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v: Dictionary in _voices:
		out.append({"track": v["track"], "gain": v["gain"], "target": v["target"]})
	return out


## Asks for track [param id] ([constant NONE] = fade to silence). Same track: nothing. During a stinger hold the
## request waits for the hold to end. Unknown ids are ignored with a warning.
func request(id: String) -> void:
	if id != NONE and not has_track(id):
		push_warning("MusicPlayer: unknown track '%s'" % id)
		return
	_wanted = id
	if _hold_left > 0.0 or id == _current:
		return
	_switch_to(id, float(_settings.get("crossfade_sec", 1.5)))


## A match ended: the loops fade out fast and the stinger plays once; the wanted track comes back after
## stinger_hold_sec.
func play_stinger(won: bool) -> void:
	var id: String = VICTORY if won else DEFEAT
	_save_position()
	var fade: float = float(_settings.get("stop_fade_sec", 0.6))
	for v: Dictionary in _voices:
		_fade(v, 0.0, fade)
	_current = NONE
	if not has_track(id):
		return
	var slot: Dictionary = _free_voice()
	_start(slot, id, 0.0)
	slot["gain"] = 1.0
	_fade(slot, 1.0, 0.0)
	_hold_left = float(_settings.get("stinger_hold_sec", 7.0))


## Pauses every music stream while the app is in the background.
func set_background(background: bool) -> void:
	_background = background
	for v: Dictionary in _voices:
		var p: AudioStreamPlayer = v["player"]
		if p != null:
			p.stream_paused = background


## Steps fades, the stinger hold and the silent clock by [param delta] seconds.
func advance(delta: float) -> void:
	if _background:
		return
	if _hold_left > 0.0:
		_hold_left = maxf(0.0, _hold_left - delta)
		if _hold_left <= 0.0:
			_switch_to(_wanted, float(_settings.get("crossfade_sec", 1.5)))
	for v: Dictionary in _voices:
		if v["track"] == NONE:
			continue
		if _silent and v["track"] == _current:
			_positions[_current] = position_of(_current) + delta
		var g: float = v["gain"]
		var t: float = v["target"]
		if g != t:
			var rate: float = v["rate"]
			if is_inf(rate):
				g = t
			else:
				g = minf(t, g + rate * delta) if t > g else maxf(t, g - rate * delta)
			v["gain"] = g
		if g <= OFF_GAIN and t <= 0.0:
			_stop(v)
		else:
			_apply_volume(v)


func _switch_to(id: String, fade: float) -> void:
	_save_position()
	for v: Dictionary in _voices:
		if v["track"] != NONE and v["track"] != id:
			_fade(v, 0.0, fade)
	_current = id
	if id == NONE:
		return
	var slot: Dictionary = _voice_with(id)
	if slot.is_empty():
		slot = _free_voice()
		_start(slot, id, position_of(id))
	_fade(slot, 1.0, fade)


func _save_position() -> void:
	if _current == NONE or _silent:
		return
	var v: Dictionary = _voice_with(_current)
	var p: AudioStreamPlayer = null if v.is_empty() else v["player"]
	if p != null and p.playing:
		_positions[_current] = p.get_playback_position()


func _voice_with(id: String) -> Dictionary:
	for v: Dictionary in _voices:
		if v["track"] == id:
			return v
	return {}


# A voice with no track, else the quieter one (it is cut).
func _free_voice() -> Dictionary:
	for v: Dictionary in _voices:
		if v["track"] == NONE:
			return v
	var quiet: Dictionary = _voices[0] if float(_voices[0]["gain"]) <= float(_voices[1]["gain"]) else _voices[1]
	_stop(quiet)
	return quiet


func _fade(v: Dictionary, target: float, sec: float) -> void:
	v["target"] = target
	v["rate"] = INF if sec <= 0.0 else 1.0 / sec


func _start(v: Dictionary, id: String, from_sec: float) -> void:
	v["track"] = id
	v["gain"] = 0.0
	var p: AudioStreamPlayer = v["player"]
	if p == null:
		return
	p.stream = _stream_for(id)
	_apply_volume(v)
	p.play(from_sec)
	p.stream_paused = _background


func _stop(v: Dictionary) -> void:
	v["track"] = NONE
	v["gain"] = 0.0
	v["target"] = 0.0
	var p: AudioStreamPlayer = v["player"]
	if p != null:
		p.stop()


func _apply_volume(v: Dictionary) -> void:
	var p: AudioStreamPlayer = v["player"]
	if p == null:
		return
	var def: Dictionary = _tracks.get(v["track"], {})
	p.volume_db = linear_to_db(maxf(float(v["gain"]), OFF_GAIN)) + float(def.get("gain_db", 0.0))


# The track's stream; a loop track loops from loop_start to the end of the file.
func _stream_for(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var def: Dictionary = _tracks.get(id, {})
	var path: String = str(def.get("file", ""))
	var s: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	var loop_start: float = float(def.get("loop_start", -1.0))
	if s is AudioStreamOggVorbis:
		var ogg := (s as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
		ogg.loop = loop_start >= 0.0
		ogg.loop_offset = maxf(loop_start, 0.0)
		s = ogg
	_streams[id] = s
	return s
