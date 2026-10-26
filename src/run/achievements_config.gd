class_name AchievementsConfig
extends RefCounted
## The achievements of Story 037 (22) and 039 (24 with `reach_floor_4` / `reach_floor_5`) from assets/data/achievements.json: id, name / description keys, condition
## (`type` + `params`), rewards (content they unlock) and the `hidden` flag. The `rewards` lists are the SINGLE runtime
## source of what is locked at the start: content that is not the reward of any achievement is open from the start.
## Pure data, no scene. A bad entry is dropped with a warning. Schema: assets/data/schema.md `achievements.json`.
## Evaluation of the conditions is [UnlockRules].

const DEFAULT_PATH: String = "res://assets/data/achievements.json"
## Reward kinds an achievement can unlock.
const REWARD_KINDS: Array[String] = ["character", "card", "piece", "relic", "region"]
## Condition types ([UnlockRules] evaluates them) and the params each one needs (name -> "string" | "int").
const CONDITION_PARAMS: Dictionary = {
	"milestone": {"key": "string", "min": "int"},
	"milestone_sum": {"prefix": "string", "min": "int"},
	"best_floor": {"min": "int"},
	"run_counter": {"key": "string", "min": "int"},
	"match_counter": {"key": "string", "min": "int"},
	"boss_clear_deck": {"min_cards": "int"},
	"boss_clear_no_hit": {},
	"run_won_deck_max": {"max": "int"},
}

static var _shared: AchievementsConfig = null

var _order: Array[String] = []
# id -> cleaned definition {id, name_key, desc_key, condition, rewards, hidden}
var _defs: Dictionary = {}
# "kind:id" -> achievement id
var _owners: Dictionary = {}


## The lazily loaded shared instance of the shipped achievements.json (read once per process).
static func shared() -> AchievementsConfig:
	if _shared == null:
		_shared = load_from_file()
	return _shared


## Drops the cached shared instance (tests).
static func reset_shared() -> void:
	_shared = null


## Loads a JSON file. Never null (empty config + warning when missing or bad).
static func load_from_file(path: String = DEFAULT_PATH) -> AchievementsConfig:
	if not FileAccess.file_exists(path):
		push_warning("AchievementsConfig: file not found: %s" % path)
		return from_dictionary({})
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("AchievementsConfig: JSON root must be an object")
		return from_dictionary({})
	return from_dictionary(parsed as Dictionary)


## Builds a config from parsed JSON ({"achievements": [...]}). Never null; a bad entry (missing id, duplicate id,
## unknown condition type, missing / bad param, unknown reward kind, content already rewarded by an earlier
## achievement) is dropped with a warning.
static func from_dictionary(d: Dictionary) -> AchievementsConfig:
	var cfg := AchievementsConfig.new()
	var raw: Variant = d.get("achievements", [])
	if typeof(raw) != TYPE_ARRAY:
		push_warning("AchievementsConfig: 'achievements' must be an array")
		return cfg
	for entry: Variant in raw as Array:
		cfg._add_entry(entry)
	return cfg


## Achievement ids in file order.
func ids() -> Array[String]:
	return _order.duplicate()


## True when achievement [param id] exists.
func has(id: String) -> bool:
	return _defs.has(id)


## Copy of the definition {id, name_key, desc_key, condition:{type, params}, rewards: Array[{kind, id}], hidden}; {} when unknown.
func get_def(id: String) -> Dictionary:
	if not _defs.has(id):
		return {}
	return (_defs[id] as Dictionary).duplicate(true)


## Id of the achievement whose reward is the content ([param kind], [param id]); "" = open from the start.
func reward_owner(kind: String, id: String) -> String:
	return str(_owners.get(kind + ":" + id, ""))


## True when the content is open from the start or its owner achievement is earned in [param progress].
func is_unlocked(kind: String, id: String, progress: ProgressState) -> bool:
	var owner_id: String = reward_owner(kind, id)
	if owner_id.is_empty():
		return true
	return progress != null and progress.has_achievement(owner_id)


## The content still locked in [param progress]: {kind: Array[String]} (kinds with nothing locked are omitted).
func locked_content(progress: ProgressState) -> Dictionary:
	var out: Dictionary = {}
	for achievement_id: String in _order:
		for reward: Dictionary in _defs[achievement_id]["rewards"]:
			var kind: String = str(reward["kind"])
			var content_id: String = str(reward["id"])
			if is_unlocked(kind, content_id, progress):
				continue
			if not out.has(kind):
				var list: Array[String] = []
				out[kind] = list
			(out[kind] as Array[String]).append(content_id)
	return out


## Flat [{kind, id, achievement}] of the rewards of the achievements in [param achievement_ids] (the "Newly unlocked" list).
func rewards_of(achievement_ids: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for aid: Variant in achievement_ids:
		var key: String = str(aid)
		if not _defs.has(key):
			continue
		for reward: Dictionary in _defs[key]["rewards"]:
			out.append({"kind": reward["kind"], "id": reward["id"], "achievement": key})
	return out


## Every reward of every achievement, file order: [{kind, id, achievement}].
func all_rewards() -> Array[Dictionary]:
	return rewards_of(_order)


func _add_entry(entry: Variant) -> void:
	if typeof(entry) != TYPE_DICTIONARY:
		push_warning("AchievementsConfig: entry is not an object, dropped")
		return
	var e: Dictionary = entry as Dictionary
	var id: String = str(e.get("id", "")).strip_edges()
	if id.is_empty():
		push_warning("AchievementsConfig: entry without id, dropped")
		return
	if _defs.has(id):
		push_warning("AchievementsConfig: duplicate id '%s', dropped" % id)
		return
	var condition: Dictionary = _clean_condition(e.get("condition"))
	if condition.is_empty():
		push_warning("AchievementsConfig: '%s' has a bad condition, dropped" % id)
		return
	var rewards: Array[Dictionary] = []
	var raw_rewards: Variant = e.get("rewards", [])
	if typeof(raw_rewards) != TYPE_ARRAY:
		push_warning("AchievementsConfig: '%s' rewards must be an array, dropped" % id)
		return
	for r: Variant in raw_rewards as Array:
		if typeof(r) != TYPE_DICTIONARY:
			push_warning("AchievementsConfig: '%s' has a bad reward, dropped" % id)
			return
		var kind: String = str((r as Dictionary).get("kind", ""))
		var content_id: String = str((r as Dictionary).get("id", ""))
		if not REWARD_KINDS.has(kind) or content_id.is_empty():
			push_warning("AchievementsConfig: '%s' has a bad reward (%s:%s), dropped" % [id, kind, content_id])
			return
		var owner_id: String = str(_owners.get(kind + ":" + content_id, ""))
		if not owner_id.is_empty():
			push_warning("AchievementsConfig: '%s' rewards %s:%s already owned by '%s', dropped" % [id, kind, content_id, owner_id])
			return
		for done: Dictionary in rewards:
			if done["kind"] == kind and done["id"] == content_id:
				push_warning("AchievementsConfig: '%s' lists %s:%s twice, dropped" % [id, kind, content_id])
				return
		rewards.append({"kind": kind, "id": content_id})
	_defs[id] = {
		"id": id,
		"name_key": str(e.get("name_key", "achievement.%s.name" % id)),
		"desc_key": str(e.get("desc_key", "achievement.%s.desc" % id)),
		"condition": condition,
		"rewards": rewards,
		"hidden": bool(e.get("hidden", false)),
	}
	_order.append(id)
	for reward: Dictionary in rewards:
		_owners[str(reward["kind"]) + ":" + str(reward["id"])] = id


# {type, params} with the params checked and normalised, or {} when bad.
static func _clean_condition(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var type: String = str((raw as Dictionary).get("type", ""))
	if not CONDITION_PARAMS.has(type):
		return {}
	var raw_params: Variant = (raw as Dictionary).get("params", {})
	if typeof(raw_params) != TYPE_DICTIONARY:
		return {}
	var params: Dictionary = {}
	var spec: Dictionary = CONDITION_PARAMS[type]
	for pname: String in spec:
		var value: Variant = (raw_params as Dictionary).get(pname)
		if spec[pname] == "string":
			if typeof(value) != TYPE_STRING or str(value).is_empty():
				return {}
			params[pname] = str(value)
		else:
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or int(value) < 1:
				return {}
			params[pname] = int(value)
	return {"type": type, "params": params}
