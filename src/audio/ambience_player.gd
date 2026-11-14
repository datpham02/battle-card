extends Node
## Region ambience (docs/design/audio/ambience-plan.md): one looping bed per region on the Ambience bus, crossfaded when
## the region changes, plus rare one-shots at random gaps. In a fight the bed drops by battle_db and the one-shots stop;
## Reduced audio also stops them. Data: the [code]ambience[/code] section of audio_events.json
## ([method AudioBank.ambience]). [AudioRig] drives it ([method set_region], [method set_battle], [method set_reduced]);
## gameplay never calls it. A silent player (headless, tests) keeps the same decisions and logs its one-shots.
## No class_name on purpose: AudioRig preloads this script, so adding it never leaves other sessions' runs waiting for
## a class-cache rebuild.

## No region (silence).
const NONE: String = ""
## Gain under which a fading bed is stopped (linear).
const OFF_GAIN: float = 0.001

## Every one-shot played, as {region, file} (tests read it).
var oneshot_log: Array[Dictionary] = []

var _silent: bool = false
var _settings: Dictionary = {}
var _regions: Dictionary = {}
## Two bed voices for the crossfade: {region, gain, target, rate, player}.
var _beds: Array[Dictionary] = []
var _oneshot: AudioStreamPlayer = null
var _region: String = NONE
var _battle: bool = false
var _reduced: bool = false
var _background: bool = false
var _gap_left: float = 0.0
var _rng := RandomNumberGenerator.new()
var _streams: Dictionary = {}


## A player on [param bank]'s ambience data; [param silent_mode] = no AudioStreamPlayers; [param rng_seed] fixes the
## one-shot gaps and picks.
func _init(bank: AudioBank = null, silent_mode: bool = false, rng_seed: int = 0x0A3B1E) -> void:
	var b: AudioBank = bank if bank != null else AudioBank.load_from_file()
	_settings = b.ambience()
	_regions = _settings.get("regions", {}) if _settings.get("regions", {}) is Dictionary else {}
	_silent = silent_mode
	_rng.seed = rng_seed
	name = "AmbiencePlayer"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in 2:
		_beds.append({"region": NONE, "gain": 0.0, "target": 0.0, "rate": 0.0, "player": null})


func _ready() -> void:
	if _silent:
		return
	for v: Dictionary in _beds:
		var p := AudioStreamPlayer.new()
		p.bus = &"Ambience"
		add_child(p)
		v["player"] = p
	_oneshot = AudioStreamPlayer.new()
	_oneshot.bus = &"Ambience"
	add_child(_oneshot)


func _process(delta: float) -> void:
	advance(delta)


## True when the data has ambience for [param region].
func has_region(region: String) -> bool:
	return _regions.has(region)


## The region whose bed plays (or fades in) now; [constant NONE] when silent.
func current_region() -> String:
	return _region


## The beds as {region, gain, target} (tests).
func beds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v: Dictionary in _beds:
		out.append({"region": v["region"], "gain": v["gain"], "target": v["target"]})
	return out


## Seconds until the next one-shot may play.
func gap_left() -> float:
	return _gap_left


## Switches to [param region]'s bed (crossfade fade_sec); a region without ambience fades to silence.
func set_region(region: String) -> void:
	var id: String = region if has_region(region) else NONE
	if id == _region:
		return
	var fade: float = float(_settings.get("fade_sec", 2.0))
	for v: Dictionary in _beds:
		if v["region"] != NONE and v["region"] != id:
			_fade(v, 0.0, fade)
	_region = id
	_gap_left = _next_gap()
	if id == NONE:
		return
	var slot: Dictionary = _bed_with(id)
	if slot.is_empty():
		slot = _free_bed()
		_start(slot, id)
	_fade(slot, _bed_target(), fade)


## A match is being fought: the bed drops by battle_db and the one-shots stop.
func set_battle(fighting: bool) -> void:
	if fighting == _battle:
		return
	_battle = fighting
	var v: Dictionary = _bed_with(_region)
	if not v.is_empty():
		_fade(v, _bed_target(), float(_settings.get("battle_fade_sec", 1.0)))


## Reduced audio (Settings): no one-shots.
func set_reduced(reduced: bool) -> void:
	_reduced = reduced


## Pauses every ambience stream while the app is in the background.
func set_background(background: bool) -> void:
	_background = background
	for v: Dictionary in _beds:
		var p: AudioStreamPlayer = v["player"]
		if p != null:
			p.stream_paused = background
	if _oneshot != null:
		_oneshot.stream_paused = background


## Steps fades and the one-shot timer by [param delta] seconds.
func advance(delta: float) -> void:
	if _background:
		return
	for v: Dictionary in _beds:
		if v["region"] == NONE:
			continue
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
	if _region == NONE or _battle or _reduced:
		return
	_gap_left -= delta
	if _gap_left <= 0.0:
		_play_oneshot()
		_gap_left = _next_gap()


func _bed_target() -> float:
	return db_to_linear(float(_settings.get("battle_db", -6.0))) if _battle else 1.0


func _next_gap() -> float:
	return _rng.randf_range(float(_settings.get("gap_min_sec", 15.0)), float(_settings.get("gap_max_sec", 40.0)))


func _play_oneshot() -> void:
	var list: Array = (_regions[_region] as Dictionary).get("oneshots", [])
	if list.is_empty():
		return
	var file: String = str(list[_rng.randi_range(0, list.size() - 1)])
	oneshot_log.append({"region": _region, "file": file})
	if _oneshot == null:
		return
	_oneshot.stream = _stream(file, false)
	_oneshot.volume_db = float(_settings.get("oneshot_db", 0.0))
	_oneshot.play()


func _bed_with(region: String) -> Dictionary:
	for v: Dictionary in _beds:
		if v["region"] == region and region != NONE:
			return v
	return {}


func _free_bed() -> Dictionary:
	for v: Dictionary in _beds:
		if v["region"] == NONE:
			return v
	var quiet: Dictionary = _beds[0] if float(_beds[0]["gain"]) <= float(_beds[1]["gain"]) else _beds[1]
	_stop(quiet)
	return quiet


func _fade(v: Dictionary, target: float, sec: float) -> void:
	v["target"] = target
	v["rate"] = INF if sec <= 0.0 else 1.0 / sec


func _start(v: Dictionary, region: String) -> void:
	v["region"] = region
	v["gain"] = 0.0
	var p: AudioStreamPlayer = v["player"]
	if p == null:
		return
	p.stream = _stream(str((_regions[region] as Dictionary).get("bed", "")), true)
	_apply_volume(v)
	p.play()
	p.stream_paused = _background


func _stop(v: Dictionary) -> void:
	v["region"] = NONE
	v["gain"] = 0.0
	v["target"] = 0.0
	var p: AudioStreamPlayer = v["player"]
	if p != null:
		p.stop()


func _apply_volume(v: Dictionary) -> void:
	var p: AudioStreamPlayer = v["player"]
	if p != null:
		p.volume_db = linear_to_db(maxf(float(v["gain"]), OFF_GAIN)) + float(_settings.get("bed_db", 0.0))


func _stream(path: String, loop: bool) -> AudioStream:
	var key: String = path + ("#loop" if loop else "")
	if _streams.has(key):
		return _streams[key]
	var s: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	if s is AudioStreamOggVorbis:
		var ogg := (s as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
		ogg.loop = loop
		ogg.loop_offset = 0.0
		s = ogg
	_streams[key] = s
	return s
