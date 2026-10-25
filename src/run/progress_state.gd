class_name ProgressState
extends RefCounted
## Pure save data (v5, Story 031; v1..v4 files still load): UI locale, regions whose boss was ever
## beaten, best floor reached, seen cards, bosses beaten and at most one run in progress (a
## [RunSession] snapshot dictionary). Chapter unlocking is gone (Run v6: every region is open); the
## per-floor ladder API of Story 015 (cleared floors, in_progress) stays in memory only and is
## deprecated: it is NOT saved. No scene or file dependency; [ProgressStore] moves the JSON.
## Schema: assets/data/schema.md.

const VERSION: int = 5
## Locale saved when none is in the file (v1 saves have no `locale`).
const DEFAULT_LOCALE: String = "vi"
## Highest value [method record_floor] stores: floors 1..5 plus the final match (Story 031). A
## structural bound of the run layout, not a tuning value.
const BEST_FLOOR_MAX: int = 6

var _cleared: Array[String] = []
var _in_progress: Dictionary = {}
var _locale: String = DEFAULT_LOCALE
## Region ids that ever had their boss beaten (v4 `cleared_chapters` migrates here; the old chapter
## ids ch1/ch2/ch3 are the region ids). Insertion order kept, no duplicates.
var _regions_boss_beaten: Array[String] = []
var _seen_cards: Array[String] = []
var _run: Dictionary = {}
## Bosses ever beaten (permanent; clamps the map tier while 0, Story 022).
var _cleared_bosses: int = 0
## Highest floor ever reached, 1..[constant BEST_FLOOR_MAX]; 0 = none yet.
var _best_floor: int = 0


## True when the boss of region [param region_id] was ever beaten.
func has_region_boss_beaten(region_id: String) -> bool:
	return _regions_boss_beaten.has(region_id)


## Records that the boss of region [param region_id] was beaten. Dedup; empty ids are ignored.
func add_region_boss_beaten(region_id: String) -> void:
	if not region_id.is_empty() and not _regions_boss_beaten.has(region_id):
		_regions_boss_beaten.append(region_id)


## Copy of the region ids whose boss was ever beaten (first-beaten order).
func get_regions_boss_beaten() -> Array[String]:
	return _regions_boss_beaten.duplicate()


## Dev (--progress=all): marks the boss of every region in [param region_ids] beaten.
func mark_all_regions_beaten(region_ids: Array) -> void:
	for id: Variant in region_ids:
		add_region_boss_beaten(str(id))


## Highest floor ever reached (1..[constant BEST_FLOOR_MAX]); 0 = none yet.
func get_best_floor() -> int:
	return _best_floor


## Records that [param floor_reached] (1-based) was reached: monotonic max, clamped to
## [constant BEST_FLOOR_MAX]. Values below 1 are ignored (no floor reached).
func record_floor(floor_reached: int) -> void:
	if floor_reached < 1:
		return
	_best_floor = maxi(_best_floor, mini(floor_reached, BEST_FLOOR_MAX))


## Records that a card was seen (offered or owned). Write-only for now.
func mark_card_seen(card_id: String) -> void:
	if not _seen_cards.has(card_id):
		_seen_cards.append(card_id)


## Copy of the seen card ids.
func get_seen_cards() -> Array[String]:
	return _seen_cards.duplicate()


## Total bosses ever beaten (0 for a fresh or pre-v4 save).
func get_cleared_bosses() -> int:
	return _cleared_bosses


## Counts one more boss beaten.
func add_cleared_boss() -> void:
	_cleared_bosses += 1


## Call when a boss node completes (alias of [method add_cleared_boss]).
func record_boss_clear() -> void:
	add_cleared_boss()


## Stores the run in progress (a snapshot: [method RunSession.to_dict]).
func set_run(session: RunSession) -> void:
	_run = session.to_dict()


## Forgets the run in progress.
func clear_run() -> void:
	_run = {}


## True when a run is in progress.
func has_run() -> bool:
	return not _run.is_empty()


## Copy of the saved run dictionary ([method RunSession.from_dict] rebuilds it); {} when none.
func get_run_dict() -> Dictionary:
	return _run.duplicate(true)


## Deprecated (Story 019): not saved; the flow agent removes the callers.
func is_cleared(key: String) -> bool:
	return _cleared.has(key)


## Deprecated (Story 019): not saved. Marks a floor cleared; clears the in-progress record when it
## points at it.
func mark_cleared(key: String) -> void:
	if not _cleared.has(key):
		_cleared.append(key)
	if not _in_progress.is_empty() and str(_in_progress["floor"]) == key:
		_in_progress = {}


## Deprecated (Story 019): not saved. Copy of the cleared floor keys.
func get_cleared() -> Array[String]:
	return _cleared.duplicate()


## Deprecated (Story 019): not saved. Records the floor being played.
## [param hp_at_match_start] negative = full HP.
func set_in_progress(key: String, match_index: int, hp_at_match_start: float, floor_seed: int) -> void:
	_in_progress = {
		"floor": key, "match_index": match_index,
		"hp_at_match_start": hp_at_match_start, "floor_seed": floor_seed,
	}


## Deprecated (Story 019): not saved. Forgets the floor in progress.
func clear_in_progress() -> void:
	_in_progress = {}


## Deprecated (Story 019): not saved. True when a floor is in progress.
func has_in_progress() -> bool:
	return not _in_progress.is_empty()


## Deprecated (Story 019): not saved. Copy of {"floor", "match_index", "hp_at_match_start",
## "floor_seed"}, or {} when none.
func get_in_progress() -> Dictionary:
	return _in_progress.duplicate()


## Saved UI locale code ("vi" by default).
func get_locale() -> String:
	return _locale


## Stores the UI locale code (empty text keeps the default). Validation is the caller's (GameFlow).
func set_locale(code: String) -> void:
	_locale = code if not code.is_empty() else DEFAULT_LOCALE


## Serialises to {"version":5,"locale","regions_boss_beaten","best_floor","seen_cards",
## "cleared_bosses","run_in_progress":{...}|null}.
func to_json() -> String:
	return JSON.stringify({
		"version": VERSION, "locale": _locale, "regions_boss_beaten": _regions_boss_beaten,
		"best_floor": _best_floor, "seen_cards": _seen_cards, "cleared_bosses": _cleared_bosses,
		"run_in_progress": null if _run.is_empty() else _run,
	})


## Parses saved text. Never null: empty, corrupt, non-object or unknown-version text gives an empty
## state (warning). Version 1 files load silently (only `locale` is read). v2..v4 files load with
## `cleared_chapters` migrated into `regions_boss_beaten` (the old chapter ids are the region ids).
## With [param config] an invalid run is dropped (warning). Region ids are kept as saved (not
## validated against the config here).
static func from_json(text: String, config: ChaptersConfig = null) -> ProgressState:
	var state := ProgressState.new()
	if text.strip_edges().is_empty():
		return state
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("ProgressState: save is not a JSON object, starting empty")
		return state
	var data: Dictionary = parsed as Dictionary
	var version: int = -1
	if typeof(data.get("version")) in [TYPE_INT, TYPE_FLOAT]:
		version = int(data["version"])
	if version < 1 or version > VERSION:
		push_warning("ProgressState: unsupported save version, starting empty")
		return state
	state.set_locale(str(data.get("locale", DEFAULT_LOCALE)))
	if version == 1:
		return state
	if version >= 4:
		state._cleared_bosses = maxi(_to_int(data.get("cleared_bosses", 0)), 0)
	if version >= 5:
		state._best_floor = clampi(_to_int(data.get("best_floor", 0)), 0, BEST_FLOOR_MAX)
	var regions_key: String = "regions_boss_beaten" if version >= 5 else "cleared_chapters"
	var raw_regions: Variant = data.get(regions_key, [])
	if typeof(raw_regions) == TYPE_ARRAY:
		for entry: Variant in raw_regions as Array:
			state.add_region_boss_beaten(str(entry))
	else:
		push_warning("ProgressState: %s must be an array, ignored" % regions_key)
	var raw_seen: Variant = data.get("seen_cards", [])
	if typeof(raw_seen) == TYPE_ARRAY:
		for entry: Variant in raw_seen as Array:
			state.mark_card_seen(str(entry))
	var raw_run: Variant = data.get("run_in_progress")
	if typeof(raw_run) == TYPE_DICTIONARY:
		if config == null:
			state._run = (raw_run as Dictionary).duplicate(true)
		else:
			var session: RunSession = RunSession.from_dict(raw_run as Dictionary, config)
			if session != null:
				state._run = session.to_dict()
	elif raw_run != null:
		push_warning("ProgressState: run_in_progress must be an object or null, ignored")
	return state


static func _to_int(value: Variant) -> int:
	return int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else 0
