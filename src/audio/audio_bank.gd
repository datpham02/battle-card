class_name AudioBank
extends RefCounted
## Skill v2 audio (docs/skill-v2/10-audio-system-design.md §2, §3, §9): the audio data of the game, read from
## [constant DEFAULT_PATH] ([code]assets/data/audio_events.json[/code]). Holds the event definitions (files or size-tier
## files, bus, priority, gain, pitch range, voice cap, cooldown, loop, reducible, vibration, duck), the per-card phase
## overrides and the archetype fallbacks per delivery x impact x phase, the voice caps, the size tiers and the timing
## constants. Pure data: no node, no AudioServer, no file other than the JSON (stream loading is the director's).
##
## A card phase resolves in this order (first hit wins, an empty string = deliberately silent):
## [code]cards[id][phase][/code] -> [code]archetypes[delivery][impact][phase][/code] -> [code]archetypes[delivery]["*"][phase][/code]
## -> [code]archetypes["*"][impact][phase][/code] -> [code]archetypes["*"]["*"][phase][/code]; then the same chain for
## [code]phase_fallbacks[phase][/code] (impact_final -> impact). So a new card sounds right with zero entries.

## The game's audio data file.
const DEFAULT_PATH: String = "res://assets/data/audio_events.json"
## Priority classes (design §6): Critical is never culled, High steals Low / Normal, Low is culled first.
const PRIORITY_LOW: int = 0
const PRIORITY_NORMAL: int = 1
const PRIORITY_HIGH: int = 2
const PRIORITY_CRITICAL: int = 3
## Size tiers (design §9): one merged sound per event group, picked by its cell count.
const TIER_S: String = "S"
const TIER_M: String = "M"
const TIER_L: String = "L"
const TIERS: Array[String] = [TIER_S, TIER_M, TIER_L]
## The wildcard key of the archetype table.
const ANY: String = "*"

var _data: Dictionary = {}
var _events: Dictionary = {}
var _defaults: Dictionary = {}
## Messages of the last [method validate] (empty = valid).
var errors: Array[String] = []


## Builds a bank from an already parsed dictionary (tests build small banks this way).
func _init(data: Dictionary = {}) -> void:
	_data = data
	_defaults = data.get("defaults", {}) if data.get("defaults", {}) is Dictionary else {}
	_events = {}
	var raw: Variant = data.get("events", {})
	if raw is Dictionary:
		for id: String in (raw as Dictionary).keys():
			var def: Variant = (raw as Dictionary)[id]
			if def is Dictionary:
				var merged: Dictionary = _defaults.duplicate(true)
				merged.merge(def as Dictionary, true)
				merged["id"] = id
				_events[id] = merged


## Loads [param path]; a missing or broken file gives an empty bank with one error (every event then resolves silent).
static func load_from_file(path: String = DEFAULT_PATH) -> AudioBank:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if not (parsed is Dictionary):
		var empty := AudioBank.new({})
		empty.errors.append("AudioBank: cannot read %s" % path)
		return empty
	return AudioBank.new(parsed as Dictionary)


## True when [param id] is a defined event.
func has_event(id: String) -> bool:
	return _events.has(id)


## The event id of UI cue [param cue_name] (data "cues"; "" when not listed = silent).
func cue(cue_name: String) -> String:
	return str((_data.get("cues", {}) as Dictionary).get(cue_name, ""))


## Every event id, sorted.
func event_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _events.keys():
		ids.append(id)
	ids.sort()
	return ids


## The event definition merged over the defaults (with its "id"); empty for an unknown id.
func get_event(id: String) -> Dictionary:
	return _events.get(id, {})


## The bus of event [param id] ("" for an unknown id).
func bus_of(id: String) -> String:
	return str(get_event(id).get("bus", ""))


## The priority rank ([constant PRIORITY_LOW] .. [constant PRIORITY_CRITICAL]) of event [param id] (Normal if unknown).
func priority_of(id: String) -> int:
	var name: String = str(get_event(id).get("priority", "normal"))
	return int((_data.get("priorities", {}) as Dictionary).get(name, PRIORITY_NORMAL))


## The bus names the layout must provide.
func bus_names() -> Array[String]:
	var out: Array[String] = []
	for b: Variant in _data.get("buses", []):
		out.append(str(b))
	return out


## The buses that have a player volume setting (Master, Music, SFX, UI, Ambience).
func volume_buses() -> Array[String]:
	var out: Array[String] = []
	for b: Variant in _data.get("volume_buses", []):
		out.append(str(b))
	return out


## The voice cap of [param category] (a bus name), or of all voices for "total"; 0 = no cap listed.
func voice_cap(category: String) -> int:
	return int((_data.get("voice_caps", {}) as Dictionary).get(category, 0))


## Voices kept free for [param category] only (the Warning bus), 0 when none.
func reserved_voices(category: String) -> int:
	return int((_data.get("reserved_voices", {}) as Dictionary).get(category, 0))


## A timing constant of [code]timing[/code] ([param fallback] when absent).
func timing(key: String, fallback: float = 0.0) -> float:
	return float((_data.get("timing", {}) as Dictionary).get(key, fallback))


## The duck settings {sec, buses_db: {bus: db}} played with a [code]duck[/code] event (Critical warnings).
func duck() -> Dictionary:
	return _data.get("duck", {"sec": 0.0, "buses_db": {}})


## The music settings {crossfade_sec, stop_fade_sec, stinger_hold_sec, tracks: {id: {file, loop_start, gain_db}}}
## read by [MusicPlayer]; empty when the data has none.
func music() -> Dictionary:
	return _data.get("music", {}) if _data.get("music", {}) is Dictionary else {}


## Event kinds that make an impact group the cast's big final layer (burst, drop_final).
func final_kinds() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in _data.get("final_kinds", []):
		out.append(str(k))
	return out


## True when card [param skill_id]'s override lists [param phase] as "" (silent by design), as opposed to not listing
## it (which falls back to the archetypes).
func card_silences(skill_id: String, phase: String) -> bool:
	var cards: Dictionary = _data.get("cards", {})
	return cards.has(skill_id) and (cards[skill_id] as Dictionary).has(phase) and str(cards[skill_id][phase]).is_empty()


## The skill phase names the archetype table may use.
func skill_phases() -> Array[String]:
	var out: Array[String] = []
	for p: Variant in _data.get("skill_phases", []):
		out.append(str(p))
	return out


## Pure: the size tier of a sound covering [param cells] cells (S below the M threshold, L from the L threshold).
func size_tier(cells: int) -> String:
	var tiers: Dictionary = _data.get("size_tiers", {"S": 1, "M": 3, "L": 5})
	if cells >= int(tiers.get(TIER_L, 5)):
		return TIER_L
	if cells >= int(tiers.get(TIER_M, 3)):
		return TIER_M
	return TIER_S


## Extra gain of size tier [param tier] for an event without tier files.
func tier_gain_db(tier: String) -> float:
	return float((_data.get("tier_gain_db", {}) as Dictionary).get(tier, 0.0))


## The files of event [param id] for size tier [param tier]: its tier files when it has them (the nearest smaller tier
## when that one is missing), else its plain variant files.
func files_for(id: String, tier: String = TIER_M) -> Array[String]:
	var def: Dictionary = get_event(id)
	var out: Array[String] = []
	var tiered: Variant = def.get("tier_files", null)
	if tiered is Dictionary and not (tiered as Dictionary).is_empty():
		var order: Array[String] = [tier, TIER_M, TIER_S, TIER_L]
		for t: String in order:
			if (tiered as Dictionary).has(t):
				for f: Variant in (tiered as Dictionary)[t]:
					out.append(str(f))
				return out
	for f: Variant in def.get("files", []):
		out.append(str(f))
	return out


## True when event [param id] has a separate file per size tier.
func has_tier_files(id: String) -> bool:
	var tiered: Variant = get_event(id).get("tier_files", null)
	return tiered is Dictionary and not (tiered as Dictionary).is_empty()


## Every file the bank references (tier files included), sorted, without duplicates.
func all_files() -> Array[String]:
	var out: Array[String] = []
	for id: String in event_ids():
		for t: String in TIERS:
			for f: String in files_for(id, t):
				if not out.has(f):
					out.append(f)
	out.sort()
	return out


## The event id of phase [param phase] of card [param skill_id] whose delivery type is [param delivery_type] and
## impact is [param impact] (see the class doc for the order); "" = silent.
func resolve_skill(skill_id: String, delivery_type: String, impact: String, phase: String) -> String:
	var found: Variant = _resolve_phase(skill_id, delivery_type, impact, phase)
	if found == null:
		var fallback: String = str((_data.get("phase_fallbacks", {}) as Dictionary).get(phase, ""))
		if not fallback.is_empty():
			found = _resolve_phase(skill_id, delivery_type, impact, fallback)
	return "" if found == null else str(found)


# The first entry of the chain for one phase; null = not listed anywhere ("" = listed as silent).
func _resolve_phase(skill_id: String, delivery_type: String, impact: String, phase: String) -> Variant:
	var cards: Dictionary = _data.get("cards", {})
	if cards.has(skill_id) and (cards[skill_id] as Dictionary).has(phase):
		return (cards[skill_id] as Dictionary)[phase]
	var arche: Dictionary = _data.get("archetypes", {})
	for d: String in [delivery_type, ANY]:
		if not arche.has(d):
			continue
		for i: String in [impact, ANY]:
			var row: Variant = (arche[d] as Dictionary).get(i, null)
			if row is Dictionary and (row as Dictionary).has(phase):
				return (row as Dictionary)[phase]
	return null


## Checks the data: every event has a known bus and priority and at least one file, every referenced id (cards,
## archetypes) exists, every file exists when [param check_files]. Fills and returns [member errors].
func validate(check_files: bool = true) -> Array[String]:
	errors = []
	if _events.is_empty():
		errors.append("no events")
	var buses: Array[String] = bus_names()
	var prios: Dictionary = _data.get("priorities", {})
	for id: String in event_ids():
		var def: Dictionary = _events[id]
		if not buses.has(str(def.get("bus", ""))):
			errors.append("%s: unknown bus '%s'" % [id, def.get("bus", "")])
		if not prios.has(str(def.get("priority", ""))):
			errors.append("%s: unknown priority '%s'" % [id, def.get("priority", "")])
		var files: Array[String] = []
		for t: String in TIERS:
			for f: String in files_for(id, t):
				if not files.has(f):
					files.append(f)
		if files.is_empty():
			errors.append("%s: no file" % id)
		if check_files:
			for f: String in files:
				if not FileAccess.file_exists(f) and not ResourceLoader.exists(f):
					errors.append("%s: missing file %s" % [id, f])
	for card: String in (_data.get("cards", {}) as Dictionary).keys():
		for phase: String in (_data["cards"][card] as Dictionary).keys():
			_check_ref("cards.%s.%s" % [card, phase], str(_data["cards"][card][phase]))
	for c: String in (_data.get("cues", {}) as Dictionary).keys():
		if not has_event(cue(c)):
			errors.append("cues.%s: unknown event '%s'" % [c, cue(c)])
	var tracks: Variant = music().get("tracks", {})
	if tracks is Dictionary:
		for t: String in (tracks as Dictionary).keys():
			var f: String = str((tracks as Dictionary)[t].get("file", "")) if (tracks as Dictionary)[t] is Dictionary else ""
			if f.is_empty():
				errors.append("music.tracks.%s: no file" % t)
			elif check_files and not FileAccess.file_exists(f) and not ResourceLoader.exists(f):
				errors.append("music.tracks.%s: missing file %s" % [t, f])
	var arche: Dictionary = _data.get("archetypes", {})
	for d: String in arche.keys():
		for i: String in (arche[d] as Dictionary).keys():
			for phase: String in (arche[d][i] as Dictionary).keys():
				_check_ref("archetypes.%s.%s.%s" % [d, i, phase], str(arche[d][i][phase]))
	return errors


func _check_ref(where: String, id: String) -> void:
	if not id.is_empty() and not has_event(id):
		errors.append("%s: unknown event '%s'" % [where, id])
	var phases: Array[String] = skill_phases()
	var phase: String = where.get_slice(".", where.get_slice_count(".") - 1)
	if not phases.is_empty() and not phases.has(phase):
		errors.append("%s: unknown phase '%s'" % [where, phase])
