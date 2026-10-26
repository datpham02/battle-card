class_name UnlockRules
extends RefCounted
## Story 037: evaluates the achievements of an [AchievementsConfig] against a [ProgressState] and a run event, and
## adds the newly earned ones to the progress. Pure: no scene, no file access except the card definitions
## ([constant CARDS_PATH]) read once for the burn-deck rule.
##
## Events (`event["type"]`), built by GameFlow AFTER it wrote the milestones of a completed node / ended run:
## [codeblock]
## {"type": "match_won", "character_id", "region_id", "is_region_boss": bool, "is_final": bool,
##  "match_stats": Dictionary, "run_stats": Dictionary, "deck_ids": Array}
## {"type": "final_reached"}
## {"type": "run_ended", "won": bool, "ending_id": String, "character_id": String,
##  "run_stats": Dictionary, "deck_ids": Array}
## [/codeblock]
## `milestone` / `milestone_sum` / `best_floor` (Story 039: ProgressState best floor >= `min`) conditions are re-evaluated on
## EVERY event (a missed event self-heals); the
## contextual types only react to their own event: `boss_clear_deck` / `boss_clear_no_hit` on `match_won` with
## `is_region_boss` (the final match counts only when the caller also sets `is_region_boss`), `run_counter` on
## `match_won` and `run_ended`, `match_counter` on `match_won`, `run_won_deck_max` on `run_ended` with `won`.
## Nothing is granted retroactively: a contextual achievement needs its own event.

const CARDS_PATH: String = "res://assets/data/cards.json"
## Event type names.
const EVENT_MATCH_WON: String = "match_won"
const EVENT_FINAL_REACHED: String = "final_reached"
const EVENT_RUN_ENDED: String = "run_ended"

static var _burn_cards: Dictionary = {}
static var _burn_loaded: bool = false


## Evaluates every achievement of [param cfg] not yet earned in [param progress] against the progress and
## [param event]; adds the new ones (add_achievement) and returns their ids in file order.
static func process(cfg: AchievementsConfig, progress: ProgressState, event: Dictionary) -> Array[String]:
	var earned: Array[String] = []
	for id: String in cfg.ids():
		if progress.has_achievement(id):
			continue
		var cond: Dictionary = cfg.get_def(id)["condition"]
		if _met(str(cond["type"]), cond["params"], progress, event):
			if progress.add_achievement(id):
				earned.append(id)
	return earned


## {"current", "target", "done"} of achievement [param id]. Milestone types: current = min(value, target) (target =
## `min`); every other type: target 1, current 0 until earned. `done` = earned. Unknown id: {0, 1, false}.
static func progress_of(cfg: AchievementsConfig, id: String, progress: ProgressState) -> Dictionary:
	if not cfg.has(id):
		return {"current": 0, "target": 1, "done": false}
	var done: bool = progress.has_achievement(id)
	var cond: Dictionary = cfg.get_def(id)["condition"]
	var params: Dictionary = cond["params"]
	match str(cond["type"]):
		"milestone":
			var target: int = int(params["min"])
			return {"current": target if done else mini(progress.get_milestone(str(params["key"])), target), "target": target, "done": done}
		"milestone_sum":
			var target_sum: int = int(params["min"])
			return {"current": target_sum if done else mini(_sum_prefix(progress, str(params["prefix"])), target_sum), "target": target_sum, "done": done}
		"best_floor":
			var target_floor: int = int(params["min"])
			return {"current": target_floor if done else mini(progress.get_best_floor(), target_floor), "target": target_floor, "done": done}
		_:
			return {"current": 1 if done else 0, "target": 1, "done": done}


## Translation key of the condition text of [param id] (the UI appends " - current/target").
static func requirement_text_key(cfg: AchievementsConfig, id: String) -> String:
	if not cfg.has(id):
		return ""
	return str(cfg.get_def(id)["desc_key"])


## True when [param card_id] counts as a burn card for `boss_clear_deck`: its definition in cards.json has the
## effect `burn` or a `burn_stacks` value above 0.
static func is_burn_card(card_id: String) -> bool:
	_load_burn_cards()
	return _burn_cards.has(card_id)


## Number of cards of [param deck_ids] (ids, or {"id": ...} entries; duplicates count) that are burn cards.
static func burn_card_count(deck_ids: Array) -> int:
	var n: int = 0
	for entry: Variant in deck_ids:
		var card_id: String = str((entry as Dictionary).get("id", "")) if typeof(entry) == TYPE_DICTIONARY else str(entry)
		if is_burn_card(card_id):
			n += 1
	return n


static func _met(type: String, params: Dictionary, progress: ProgressState, event: Dictionary) -> bool:
	var ev: String = str(event.get("type", ""))
	match type:
		"milestone":
			return progress.get_milestone(str(params["key"])) >= int(params["min"])
		"milestone_sum":
			return _sum_prefix(progress, str(params["prefix"])) >= int(params["min"])
		"best_floor":
			return progress.get_best_floor() >= int(params["min"])
		"run_counter":
			if ev != EVENT_MATCH_WON and ev != EVENT_RUN_ENDED:
				return false
			return _stat(event.get("run_stats"), str(params["key"])) >= int(params["min"])
		"match_counter":
			if ev != EVENT_MATCH_WON:
				return false
			return _stat(event.get("match_stats"), str(params["key"])) >= int(params["min"])
		"boss_clear_deck":
			if not _is_boss_clear(event):
				return false
			var deck: Variant = event.get("deck_ids")
			return typeof(deck) == TYPE_ARRAY and burn_card_count(deck as Array) >= int(params["min_cards"])
		"boss_clear_no_hit":
			var ms: Variant = event.get("match_stats")
			return _is_boss_clear(event) and typeof(ms) == TYPE_DICTIONARY and (ms as Dictionary).has("hits_taken") and _stat(ms, "hits_taken") == 0
		"run_won_deck_max":
			if ev != EVENT_RUN_ENDED or not bool(event.get("won", false)):
				return false
			var deck_list: Variant = event.get("deck_ids")
			if typeof(deck_list) != TYPE_ARRAY:
				return false
			var size: int = (deck_list as Array).size()
			return size >= 1 and size <= int(params["max"])
	return false


static func _is_boss_clear(event: Dictionary) -> bool:
	return str(event.get("type", "")) == EVENT_MATCH_WON and bool(event.get("is_region_boss", false))


static func _stat(stats: Variant, key: String) -> int:
	if typeof(stats) != TYPE_DICTIONARY:
		return 0
	var value: Variant = (stats as Dictionary).get(key, 0)
	return int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else 0


static func _sum_prefix(progress: ProgressState, prefix: String) -> int:
	var sum: int = 0
	var ledger: Dictionary = progress.get_milestones()
	for key: Variant in ledger:
		if str(key).begins_with(prefix):
			sum += int(ledger[key])
	return sum


# Reads cards.json once: the ids of the burn cards.
static func _load_burn_cards() -> void:
	if _burn_loaded:
		return
	_burn_loaded = true
	_burn_cards = {}
	if not FileAccess.file_exists(CARDS_PATH):
		push_warning("UnlockRules: %s not found, no burn cards" % CARDS_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARDS_PATH))
	if typeof(parsed) != TYPE_DICTIONARY or typeof((parsed as Dictionary).get("cards")) != TYPE_DICTIONARY:
		push_warning("UnlockRules: cards.json has no 'cards' object, no burn cards")
		return
	var cards: Dictionary = (parsed as Dictionary)["cards"]
	for card_id: Variant in cards:
		var def: Variant = cards[card_id]
		if typeof(def) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = def as Dictionary
		var stacks: Variant = d.get("burn_stacks", 0)
		if str(d.get("effect", "")) == "burn" or (typeof(stacks) in [TYPE_INT, TYPE_FLOAT] and float(stacks) > 0.0):
			_burn_cards[str(card_id)] = true
