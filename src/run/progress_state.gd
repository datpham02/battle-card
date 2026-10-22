class_name ProgressState
extends RefCounted
## Pure save data (v2, Story 019): UI locale, cleared chapters, seen cards and at most one run in
## progress (a [RunSession] snapshot dictionary). The per-floor ladder API of Story 015 (cleared
## floors, in_progress) stays in memory only and is deprecated: it is NOT saved any more.
## No scene or file dependency; [ProgressStore] moves the JSON. Schema: assets/data/schema.md.

const VERSION: int = 2
## Locale saved when none is in the file (v1 saves have no `locale`).
const DEFAULT_LOCALE: String = "vi"

var _cleared: Array[String] = []
var _in_progress: Dictionary = {}
var _locale: String = DEFAULT_LOCALE
var _cleared_chapters: Array[String] = []
var _seen_cards: Array[String] = []
var _run: Dictionary = {}


## True when chapter [param chapter_id] has been cleared by any character.
func is_chapter_cleared(chapter_id: String) -> bool:
	return _cleared_chapters.has(chapter_id)


## Marks a chapter cleared (no duplicates).
func mark_chapter_cleared(chapter_id: String) -> void:
	if not _cleared_chapters.has(chapter_id):
		_cleared_chapters.append(chapter_id)


## Copy of the cleared chapter ids.
func get_cleared_chapters() -> Array[String]:
	return _cleared_chapters.duplicate()


## Chapter [param ci] can be started: chapter 0 always, else the previous chapter is cleared.
func is_chapter_unlocked(config: ChaptersConfig, ci: int) -> bool:
	if ci < 0 or ci >= config.chapter_count():
		return false
	return ci == 0 or is_chapter_cleared(config.chapter_id(ci - 1))


## Records that a card was seen (offered or owned). Write-only for now.
func mark_card_seen(card_id: String) -> void:
	if not _seen_cards.has(card_id):
		_seen_cards.append(card_id)


## Copy of the seen card ids.
func get_seen_cards() -> Array[String]:
	return _seen_cards.duplicate()


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


## Deprecated (Story 019): superseded by [method is_chapter_unlocked]. Floor (ci, fi) is playable:
## the first floor of the first chapter, or the previous floor in linear order is cleared.
func is_unlocked(config: ChaptersConfig, ci: int, fi: int) -> bool:
	var index: int = config.linear_index(ci, fi)
	if index < 0:
		return false
	if index == 0:
		return true
	var previous: Vector2i = config.floor_at_linear(index - 1)
	return is_cleared(config.floor_key(previous.x, previous.y))


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


## Serialises to {"version":2,"locale","cleared_chapters","seen_cards","run_in_progress":{...}|null}.
func to_json() -> String:
	return JSON.stringify({
		"version": VERSION, "locale": _locale, "cleared_chapters": _cleared_chapters,
		"seen_cards": _seen_cards, "run_in_progress": null if _run.is_empty() else _run,
	})


## Parses saved text. Never null: empty, corrupt, non-object or unknown-version text gives an empty
## state (warning). Version 1 files load silently (only `locale` is read). With [param config],
## unknown chapter ids are dropped and an invalid run is dropped (warning).
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
	if version != 1 and version != VERSION:
		push_warning("ProgressState: unsupported save version, starting empty")
		return state
	state.set_locale(str(data.get("locale", DEFAULT_LOCALE)))
	if version == 1:
		return state
	var raw_cleared: Variant = data.get("cleared_chapters", [])
	if typeof(raw_cleared) == TYPE_ARRAY:
		for entry: Variant in raw_cleared as Array:
			var id: String = str(entry)
			if config != null and not _has_chapter(config, id):
				push_warning("ProgressState: cleared chapter '%s' no longer exists, dropped" % id)
			else:
				state.mark_chapter_cleared(id)
	else:
		push_warning("ProgressState: cleared_chapters must be an array, ignored")
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


## Dev (--progress=all): every floor except the very last is cleared (legacy floor API) and every
## chapter except the last is cleared.
static func unlocked_everything(config: ChaptersConfig) -> ProgressState:
	var state := ProgressState.new()
	for i: int in config.total_floors() - 1:
		var pos: Vector2i = config.floor_at_linear(i)
		state._cleared.append(config.floor_key(pos.x, pos.y))
	for ci: int in config.chapter_count() - 1:
		state.mark_chapter_cleared(config.chapter_id(ci))
	return state


static func _has_chapter(config: ChaptersConfig, id: String) -> bool:
	for ci: int in config.chapter_count():
		if config.chapter_id(ci) == id:
			return true
	return false
