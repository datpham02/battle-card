class_name ProgressState
extends RefCounted
## Pure save data (v8, Story 038; v1..v7 files still load): UI locale, regions whose boss was ever
## beaten, best floor reached, seen cards, bosses beaten and at most one run in progress (a
## [RunSession] snapshot dictionary). Chapter unlocking is gone (Run v6: every region is open); the
## per-floor ladder API of Story 015 (cleared floors, in_progress) stays in memory only and is
## deprecated: it is NOT saved. No scene or file dependency; [ProgressStore] moves the JSON.
## Story 037 adds the milestone ledger, the earned achievements and the unlocks the player has seen.
## Schema: assets/data/schema.md.

const VERSION: int = 8
## Story 038: highest Kiep level (cap of `kiep_unlocked`, the levels in assets/data/kiep_levels.json are 1..10).
const KIEP_MAX: int = 10
## Locale saved when none is in the file (v1 saves have no `locale`).
const DEFAULT_LOCALE: String = "en"
## Highest value [method record_floor] stores: floors 1..7 plus the final match (Story 031; 7 floors since the
## 2026-11-07 climb). A structural bound of the run layout, not a tuning value.
const BEST_FLOOR_MAX: int = 8
## Story 037 milestone keys ([method get_milestone]); `region_boss:<region_id>`, `runs_won:<character_id>`
## and `ending:<ending_id>` are built from these prefixes.
const MS_REGION_BOSS_PREFIX: String = "region_boss:"
const MS_REACHED_FINAL: String = "reached_final"
const MS_RUNS_WON: String = "runs_won"
const MS_RUNS_WON_PREFIX: String = "runs_won:"
const MS_KILLS_TOTAL: String = "kills_total"
const MS_SPARES_TOTAL: String = "spares_total"
const MS_ENDING_PREFIX: String = "ending:"

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
## Story 035: match ids of region bosses ever spared / executed (insertion order, no duplicates; a boss can be in both).
var _spared_bosses: Array[String] = []
var _executed_bosses: Array[String] = []
## Story 035: total Spare / Execute choices ever made (every choice counts, repeats included).
var _spare_total: int = 0
var _execute_total: int = 0
## Story 035: ending ids ever reached ("spare", "execute", "balance"; no duplicates).
var _endings_seen: Array[String] = []
## Story 037: the milestone ledger {key: int > 0}, the earned achievement ids (earned order) and the
## unlocked content the player has already seen ("kind:id").
var _milestones: Dictionary = {}
var _achievements: Array[String] = []
var _seen_unlocks: Array[String] = []
## Story 038: per character id the highest Kiep level the player may pick (0..KIEP_MAX) and the highest Kiep level
## ever won (-1 = never won). A missing id reads as 0 / -1.
var _kiep_unlocked: Dictionary = {}
var _kiep_best_won: Dictionary = {}
## Save slots (2026-11-07): seconds of finished / dropped runs (run clocks banked by [method clear_run] and by a new
## run replacing an old one in [method set_run]) and the unix time of the last save (0 = never). Optional keys
## `play_time_banked` / `saved_at`, read from any version (no version bump: older builds ignore them).
var _play_time_banked: float = 0.0
var _saved_at: int = 0


## True when the boss of region [param region_id] was ever beaten.
func has_region_boss_beaten(region_id: String) -> bool:
	return _regions_boss_beaten.has(region_id)


## Records that the boss of region [param region_id] was beaten. Dedup; empty ids are ignored.
## Story 037: every call also adds 1 to the milestone `region_boss:<region_id>` (the list stays deduped).
func add_region_boss_beaten(region_id: String) -> void:
	if region_id.is_empty():
		return
	if not _regions_boss_beaten.has(region_id):
		_regions_boss_beaten.append(region_id)
	add_milestone(MS_REGION_BOSS_PREFIX + region_id)


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


## Story 035: records one Spare / Execute choice on boss [param match_id] ("spare" | "execute", see FateLogic):
## the id joins [method get_spared_bosses] / [method get_executed_bosses] (dedup, empty ids not stored) and the
## matching total +1 (Story 037: and the milestone `spares_total` / `kills_total` +1). An unknown fate is ignored (warning).
func record_fate(match_id: String, fate: String) -> void:
	match fate:
		FateLogic.FATE_SPARE:
			_spare_total += 1
			add_milestone(MS_SPARES_TOTAL)
			if not match_id.is_empty() and not _spared_bosses.has(match_id):
				_spared_bosses.append(match_id)
		FateLogic.FATE_EXECUTE:
			_execute_total += 1
			add_milestone(MS_KILLS_TOTAL)
			if not match_id.is_empty() and not _executed_bosses.has(match_id):
				_executed_bosses.append(match_id)
		_:
			push_warning("ProgressState: unknown fate '%s' ignored" % fate)


## Story 035: records that ending [param id] was reached (dedup of the list; empty ids ignored).
## Story 037: every call adds 1 to the milestone `ending:<id>`.
func record_ending(id: String) -> void:
	if id.is_empty():
		return
	if not _endings_seen.has(id):
		_endings_seen.append(id)
	add_milestone(MS_ENDING_PREFIX + id)


## Story 035: copy of the match ids of bosses ever spared.
func get_spared_bosses() -> Array[String]:
	return _spared_bosses.duplicate()


## Story 035: copy of the match ids of bosses ever executed.
func get_executed_bosses() -> Array[String]:
	return _executed_bosses.duplicate()


## Story 035: total Spare choices ever made.
func get_spare_total() -> int:
	return _spare_total


## Story 035: total Execute choices ever made.
func get_execute_total() -> int:
	return _execute_total


## Story 035: copy of the ending ids ever reached.
func get_endings_seen() -> Array[String]:
	return _endings_seen.duplicate()


## Story 037: value of milestone [param key] (0 when never written).
func get_milestone(key: String) -> int:
	return int(_milestones.get(key, 0))


## Story 037: adds [param n] to milestone [param key]. Empty keys and n < 1 are ignored.
## Callers write milestones only at save points (end of a boss node, end of a run).
func add_milestone(key: String, n: int = 1) -> void:
	if key.is_empty() or n < 1:
		return
	_milestones[key] = get_milestone(key) + n


## Story 037: copy of the milestone ledger.
func get_milestones() -> Dictionary:
	return _milestones.duplicate()


## Story 037: true when achievement [param id] was earned.
func has_achievement(id: String) -> bool:
	return _achievements.has(id)


## Story 037: records achievement [param id] as earned. Returns true when it was new (dedup; empty ids ignored).
func add_achievement(id: String) -> bool:
	if id.is_empty() or _achievements.has(id):
		return false
	_achievements.append(id)
	return true


## Story 037: copy of the earned achievement ids (earned order).
func get_achievements() -> Array[String]:
	return _achievements.duplicate()


## Story 037: true when content ([param kind] character|card|piece|relic|region, [param id]) was unlocked by an
## earned achievement and the player has not seen it yet (drives the "New" mark). Open-from-the-start content is never new.
## [param cfg] defaults to [method AchievementsConfig.shared].
func is_new_unlock(kind: String, id: String, cfg: AchievementsConfig = null) -> bool:
	if _seen_unlocks.has(kind + ":" + id):
		return false
	var config: AchievementsConfig = cfg if cfg != null else AchievementsConfig.shared()
	var owner_id: String = config.reward_owner(kind, id)
	return not owner_id.is_empty() and has_achievement(owner_id)


## Story 041: true when [param kind]:[param id] is in the seen list (e.g. "hint", "odd_block" for the first-pickup
## Odd Block hint). Plain lookup: no achievement check, unlike [method is_new_unlock].
func is_unlock_seen(kind: String, id: String) -> bool:
	return _seen_unlocks.has(kind + ":" + id)


## Story 037: records that the player has seen unlocked content (dedup; empty ids ignored).
func mark_unlock_seen(kind: String, id: String) -> void:
	if kind.is_empty() or id.is_empty():
		return
	var key: String = kind + ":" + id
	if not _seen_unlocks.has(key):
		_seen_unlocks.append(key)


## Story 037: copy of the seen unlocks ("kind:id", first-seen order).
func get_seen_unlocks() -> Array[String]:
	return _seen_unlocks.duplicate()


## Story 037: a run was won with [param character_id]: `runs_won` +1 and `runs_won:<character_id>` +1.
func record_run_won(character_id: String) -> void:
	add_milestone(MS_RUNS_WON)
	if not character_id.is_empty():
		add_milestone(MS_RUNS_WON_PREFIX + character_id)


## Story 037: the final match was reached: `reached_final` +1.
func record_final_reached() -> void:
	add_milestone(MS_REACHED_FINAL)


## Story 038: highest Kiep level [param character_id] may pick (0..10; 0 for an unknown character or an old save).
func get_kiep_unlocked(character_id: String) -> int:
	return int(_kiep_unlocked.get(character_id, 0))


## Story 038: highest Kiep level [param character_id] ever won; -1 when never won (or an old save).
func get_kiep_best_won(character_id: String) -> int:
	return int(_kiep_best_won.get(character_id, -1))


## Story 038: a run of [param character_id] ended at Kiep [param level]. A win at k: best_won = max(best_won, k),
## unlocked = max(unlocked, min(k + 1, 10)); winning below the unlocked level changes nothing more; a loss changes
## nothing. Levels outside 0..10 and empty ids are ignored.
func record_kiep_result(character_id: String, level: int, won: bool) -> void:
	if character_id.is_empty() or not won or level < 0 or level > KIEP_MAX:
		return
	_kiep_best_won[character_id] = maxi(get_kiep_best_won(character_id), level)
	_kiep_unlocked[character_id] = maxi(get_kiep_unlocked(character_id), mini(level + 1, KIEP_MAX))


## Dev (--progress=all / kiep3): every id in [param character_ids] gets Kiep [param level] (default 10) unlocked and won
## (best_won = level, unlocked = min(level + 1, 10)); never lowers a value.
func mark_all_kiep(character_ids: Array, level: int = KIEP_MAX) -> void:
	for id: Variant in character_ids:
		var cid: String = str(id)
		if not cid.is_empty():
			record_kiep_result(cid, clampi(level, 0, KIEP_MAX), true)


## Dev (--progress=all): every region boss beaten (in [param region_ids]), every `milestone` / `milestone_sum`
## condition of [param cfg] met, every achievement earned and its rewards marked seen.
func mark_all_unlocked(cfg: AchievementsConfig, region_ids: Array) -> void:
	for id: Variant in region_ids:
		var region_id: String = str(id)
		if region_id.is_empty():
			continue
		if not _regions_boss_beaten.has(region_id):
			add_region_boss_beaten(region_id)
		elif get_milestone(MS_REGION_BOSS_PREFIX + region_id) < 1:
			add_milestone(MS_REGION_BOSS_PREFIX + region_id)
	for aid: String in cfg.ids():
		var def: Dictionary = cfg.get_def(aid)
		var cond: Dictionary = def["condition"]
		var params: Dictionary = cond["params"]
		match str(cond["type"]):
			"milestone":
				var key: String = str(params["key"])
				var deficit: int = int(params["min"]) - get_milestone(key)
				if deficit > 0:
					add_milestone(key, deficit)
			"milestone_sum":
				var prefix: String = str(params["prefix"])
				var sum: int = 0
				for k: Variant in _milestones:
					if str(k).begins_with(prefix):
						sum += int(_milestones[k])
				if sum < int(params["min"]):
					add_milestone(prefix + "dev", int(params["min"]) - sum)
			"best_floor":
				record_floor(int(params["min"])) # Story 039: reach_floor_4 / reach_floor_5
	for aid: String in cfg.ids():
		add_achievement(aid)
		for reward: Dictionary in cfg.get_def(aid)["rewards"]:
			mark_unlock_seen(str(reward["kind"]), str(reward["id"]))


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
## A different run (other seed or character) replacing the stored one banks the old run's clock first.
func set_run(session: RunSession) -> void:
	var next: Dictionary = session.to_dict()
	if not _run.is_empty() and (_run.get("run_seed") != next.get("run_seed") or _run.get("character") != next.get("character")):
		_bank_run_time()
	_run = next


## Forgets the run in progress (its clock is banked into the play time).
func clear_run() -> void:
	_bank_run_time()
	_run = {}


## Save slots: total play time in seconds (banked runs + the clock of the run in progress).
func get_play_time_sec() -> float:
	return _play_time_banked + _run_elapsed()


## Save slots: adds [param sec] (>= 0) to the banked play time.
func add_play_time(sec: float) -> void:
	_play_time_banked += maxf(sec, 0.0)


## Save slots: unix time of the last save (0 = never saved).
func get_saved_at() -> int:
	return _saved_at


## Save slots: stamps the last-save time (ProgressStore.save_state does it on every save).
func set_saved_at(unix_sec: int) -> void:
	_saved_at = maxi(unix_sec, 0)


func _run_elapsed() -> float:
	var raw: Variant = _run.get("elapsed", 0.0)
	return maxf(float(raw), 0.0) if typeof(raw) in [TYPE_INT, TYPE_FLOAT] else 0.0


func _bank_run_time() -> void:
	_play_time_banked += _run_elapsed()


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


## Serialises to {"version":8,"locale","regions_boss_beaten","best_floor","seen_cards",
## "cleared_bosses","spared_bosses","executed_bosses","spare_total","execute_total","endings_seen",
## "milestones":{key:int},"achievements":[id],"seen_unlocks":["kind:id"],"kiep_unlocked":{id:int},"kiep_best_won":{id:int},
## "run_in_progress":{...}|null}.
func to_json() -> String:
	return JSON.stringify({
		"version": VERSION, "locale": _locale, "regions_boss_beaten": _regions_boss_beaten,
		"best_floor": _best_floor, "seen_cards": _seen_cards, "cleared_bosses": _cleared_bosses,
		"spared_bosses": _spared_bosses, "executed_bosses": _executed_bosses,
		"spare_total": _spare_total, "execute_total": _execute_total, "endings_seen": _endings_seen,
		"milestones": _milestones, "achievements": _achievements, "seen_unlocks": _seen_unlocks,
		"kiep_unlocked": _kiep_unlocked, "kiep_best_won": _kiep_best_won,
		"run_in_progress": null if _run.is_empty() else _run,
		"play_time_banked": _play_time_banked, "saved_at": _saved_at,
	})


## Parses saved text. Never null: empty, corrupt, non-object or unknown-version text gives an empty
## state (warning). Version 1 files load silently (only `locale` is read). v2..v4 files load with
## `cleared_chapters` migrated into `regions_boss_beaten` (the old chapter ids are the region ids). Files below v6
## load with the Story 035 keys empty / 0. Files below v7 (Story 037) migrate the ledger: `region_boss:<r>` = 1 per
## beaten region, `spares_total` / `kills_total` from `spare_total` / `execute_total`, `ending:<id>` = 1 per ending
## seen; no achievement is granted retroactively. Files below v8 (Story 038) load with every character at Kiep 0 unlocked / -1 best won.
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
	state._play_time_banked = maxf(_to_float(data.get("play_time_banked", 0.0)), 0.0)
	state._saved_at = maxi(_to_int(data.get("saved_at", 0)), 0)
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
			var region_id: String = str(entry)
			if not region_id.is_empty() and not state._regions_boss_beaten.has(region_id):
				state._regions_boss_beaten.append(region_id)
	else:
		push_warning("ProgressState: %s must be an array, ignored" % regions_key)
	if version >= 6:
		state._spared_bosses = _clean_ids(data.get("spared_bosses", []))
		state._executed_bosses = _clean_ids(data.get("executed_bosses", []))
		state._spare_total = maxi(_to_int(data.get("spare_total", 0)), 0)
		state._execute_total = maxi(_to_int(data.get("execute_total", 0)), 0)
		state._endings_seen = _clean_ids(data.get("endings_seen", []))
	if version >= 7:
		state._milestones = _clean_milestones(data.get("milestones", {}))
		state._achievements = _clean_ids(data.get("achievements", []))
		state._seen_unlocks = _clean_ids(data.get("seen_unlocks", []))
	else:
		state._migrate_ledger()
	if version >= 8:
		state._kiep_unlocked = _clean_kiep(data.get("kiep_unlocked", {}), 0)
		state._kiep_best_won = _clean_kiep(data.get("kiep_best_won", {}), -1)
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


# Story 037: builds the milestone ledger of a pre-v7 file from the older fields (no achievements).
func _migrate_ledger() -> void:
	_milestones = {}
	for region_id: String in _regions_boss_beaten:
		add_milestone(MS_REGION_BOSS_PREFIX + region_id)
	add_milestone(MS_SPARES_TOTAL, _spare_total)
	add_milestone(MS_KILLS_TOTAL, _execute_total)
	for ending_id: String in _endings_seen:
		add_milestone(MS_ENDING_PREFIX + ending_id)


# Story 038: {character_id: int} from a saved object, values clamped to [floor_value, KIEP_MAX]; entries equal to the
# default ([param floor_value]) and bad entries are dropped ({} for anything else).
static func _clean_kiep(raw: Variant, floor_value: int) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var src: Dictionary = raw as Dictionary
	for key: Variant in src:
		var value: Variant = src[key]
		if typeof(value) in [TYPE_INT, TYPE_FLOAT] and not str(key).is_empty():
			var v: int = clampi(int(value), floor_value, KIEP_MAX)
			if v != floor_value:
				out[str(key)] = v
	return out


# Story 037: {key: int > 0} from a saved object ({} for anything else; bad entries dropped).
static func _clean_milestones(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var src: Dictionary = raw as Dictionary
	for key: Variant in src:
		var value: Variant = src[key]
		if typeof(value) in [TYPE_INT, TYPE_FLOAT] and not str(key).is_empty() and int(value) > 0:
			out[str(key)] = int(value)
	return out


# Story 035: unique non-empty ids from a saved array ([] for anything else).
static func _clean_ids(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for entry: Variant in raw as Array:
		var id: String = str(entry)
		if not id.is_empty() and not out.has(id):
			out.append(id)
	return out


static func _to_int(value: Variant) -> int:
	return int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else 0


static func _to_float(value: Variant) -> float:
	return float(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else 0.0
