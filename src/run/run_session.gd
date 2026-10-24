class_name RunSession
extends RefCounted
## Pure data + rules of one ROGUELIKE RUN (Story 019, map model Story 022 / save v4): one character
## walks one chapter MAP (columns of nodes, one node taken per column). Holds what must survive
## between nodes and in the save: deck, HP, map position, seed, clock, pending card offer, removal
## tokens and cleared nodes. No nodes, no files. HP rules (Story 022): starts full (hp = -1); NO
## automatic heal after a node (only passive/card heal passed in, the rest node, cards); hp never
## exceeds max. Death simply ends the run (caller discards it).
## Map shape (built by ChapterMapGen, Story 022 Part 1a): Array of columns
## {"index": int, "tier": int, "nodes": [{"kind": String, "match_id": String}]}.

## Save format version written by [method to_dict].
const SAVE_VERSION: int = 4
## Restart reason key for a pre-v4 (floor/match) run found in a save (shown as one line by the flow).
const RESTART_OLD_SAVE: String = "run.restart.old_save"
## Node kind that ends the chapter and grants a removal token.
const KIND_BOSS: String = "boss"
## Documented fallbacks for the economy keys of rewards.json (the single place; the file wins).
const CONFIG_DEFAULTS: Dictionary = {
	"starting_removals": 1, "luck_start": 0.0, "luck_per_node": 1.0,
	"rest_heal_ratio": 0.3, "rest_forge_levels": 1, "boss_removal_tokens": 1,
}

## Character id (CharacterConfig).
var character_id: String = ""
## Index into ChaptersConfig of the chapter being run.
var chapter_index: int = 0
## The chapter map (see class doc); fixed for the run.
var map: Array[Dictionary] = []
## Current column index (0-based); == map.size() once the last column is done.
var column: int = 0
## Chosen node in the current column; -1 = none chosen yet.
var node_index: int = -1
## Nodes already passed: {column, node_index, kind}.
var cleared_nodes: Array = []
## Tokens that allow removing a card from the deck at a reward screen.
var removal_tokens: int = 0
## Bosses beaten in THIS run (the permanent total lives in ProgressState).
var cleared_bosses_this_run: int = 0
## Player HP at the START of the current node; negative = full HP.
var hp: float = -1.0
## The deck: {id, level} entries (duplicates allowed, level 1..SkillConfig.MAX_LEVEL).
var deck: Array[Dictionary] = []
## Card ids of the deck in order (view of [member deck]; assigning ids sets level-1 entries).
var deck_ids: Array[String]:
	get:
		var ids: Array[String] = []
		for e: Dictionary in deck:
			ids.append(str(e["id"]))
		return ids
	set(value):
		deck = []
		for id: String in value:
			deck.append({"id": id, "level": 1})
## Seed of the whole run (map and arena seeds derive from it).
var run_seed: int = 0
## Seconds of PLAYING time of the run (written by the flow).
var elapsed_sec: float = 0.0
## Card ids offered after the last won node and not yet picked / skipped; [] when none.
var pending_reward: Array[String] = []
## Revive tokens (from chapters defaults; reserved, unused).
var revives: int = 0
## True when this session came from a pre-v4 save: the flow must restart the chapter for
## [member character_id] from a fresh run (map empty, deck/hp meaningless).
var needs_restart: bool = false
## Localisation key of the one-line restart notice ("" when not [member needs_restart]).
var restart_reason: String = ""
var _won: bool = false
# Config the session was built with (chapter id for [method to_dict]).
var _chapters: ChaptersConfig = null

## Deprecated (Story 022): alias of [member column] kept so unported callers compile.
var floor_index: int:
	get:
		return column
	set(value):
		column = value
## Deprecated (Story 022): alias of [member node_index] kept so unported callers compile.
var match_index: int:
	get:
		return node_index
	set(value):
		node_index = value


## New run: column 0, no node chosen, full HP, deck = the character's starter_deck, revives from
## `defaults.revive_tokens`. [param character] is [method CharacterConfig.get_character];
## [param map] the generated chapter map; [param starting_removals] = rewards.json starting_removals.
## (Deviation from the brief: keeps the chapters+character form so the existing caller compiles;
## max HP is not needed here.)
static func begin(chapters: ChaptersConfig, character: Dictionary, chapter_index: int, run_seed: int,
		map: Array[Dictionary] = [], starting_removals: int = 0) -> RunSession:
	var s := RunSession.new()
	s._chapters = chapters
	s.character_id = str(character.get("id", ""))
	s.chapter_index = clampi(chapter_index, 0, chapters.chapter_count() - 1)
	s.run_seed = run_seed
	s.map = map.duplicate(true)
	s.removal_tokens = maxi(starting_removals, 0)
	for id: Variant in character.get("starter_deck", []) as Array:
		s.deck.append({"id": str(id), "level": 1})
	s.revives = int(chapters.defaults().get("revive_tokens", 0))
	return s


## Reads economy key [param key] from [param config] (rewards.json), else [constant CONFIG_DEFAULTS].
static func cfg(config: Dictionary, key: String) -> float:
	return float(config.get(key, CONFIG_DEFAULTS[key]))


## The column at [member column] ({} when past the end or the map is empty).
func current_column() -> Dictionary:
	if column < 0 or column >= map.size():
		return {}
	return map[column]


## Nodes of the current column not yet cleared, each a copy with an added "node_index" (its index
## in the column, the argument of [method choose_node]).
func available_nodes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var col: Dictionary = current_column()
	if col.is_empty():
		return out
	var nodes: Array = col.get("nodes", [])
	for i: int in nodes.size():
		if _is_cleared(column, i):
			continue
		var n: Dictionary = (nodes[i] as Dictionary).duplicate()
		n["node_index"] = i
		out.append(n)
	return out


## Chooses node [param i] of the current column. False (no change) when a node is already chosen,
## the column does not exist, [param i] is out of range or that node was cleared.
func choose_node(i: int) -> bool:
	if node_index != -1 or current_column().is_empty():
		return false
	if i < 0 or i >= (current_column().get("nodes", []) as Array).size() or _is_cleared(column, i):
		return false
	node_index = i
	return true


## The chosen node ({"kind","match_id"}); {} when none is chosen.
func current_node() -> Dictionary:
	var col: Dictionary = current_column()
	if node_index < 0 or col.is_empty():
		return {}
	var nodes: Array = col.get("nodes", [])
	if node_index >= nodes.size():
		return {}
	return (nodes[node_index] as Dictionary).duplicate()


## Completes the chosen node. [param hp_end] = player HP when it ended; NO automatic heal:
## hp = min(hp_end + passive_heal, max_hp) ([param passive_heal] = passive/card heal such as
## second_wind, 0 by default). Records {column, node_index, kind} in [member cleared_nodes], resets
## [member node_index] to -1 and moves to the next column. A [constant KIND_BOSS] node grants
## `boss_removal_tokens` (1) removal tokens, counts in [member cleared_bosses_this_run] and wins the
## run. Returns {"advanced": bool, "run_won": bool}; no node chosen -> {advanced:false} and nothing
## changes. [param node_kind] overrides the chosen node's kind when not empty.
func complete_node(hp_end: float, max_hp: float, node_kind: String, config: Dictionary, passive_heal: float = 0.0) -> Dictionary:
	if node_index < 0 or current_column().is_empty():
		return {"advanced": false, "run_won": is_run_won()}
	var kind: String = node_kind if not node_kind.is_empty() else str(current_node().get("kind", ""))
	hp = minf(hp_end + maxf(passive_heal, 0.0), max_hp)
	cleared_nodes.append({"column": column, "node_index": node_index, "kind": kind})
	node_index = -1
	column += 1
	if kind == KIND_BOSS:
		removal_tokens += int(cfg(config, "boss_removal_tokens"))
		cleared_bosses_this_run += 1
		_won = true
	return {"advanced": true, "run_won": is_run_won()}


## True once the boss node was cleared (or every column is done).
func is_run_won() -> bool:
	return _won or (not map.is_empty() and column >= map.size())


## Run luck = luck_start + luck_per_node x nodes cleared (rewards.json via [param config]).
func luck(config: Dictionary = {}) -> float:
	return cfg(config, "luck_start") + cfg(config, "luck_per_node") * float(cleared_nodes.size())


## Spends one removal token. False (no change) at 0.
func spend_removal() -> bool:
	if removal_tokens <= 0:
		return false
	removal_tokens -= 1
	return true


## Rest node, "Nghi": hp += rest_heal_ratio x max_hp clamped to [param max_hp]. A negative hp
## (= full) counts as full and heals nothing. Returns the amount actually healed.
func rest_heal(max_hp: float, config: Dictionary) -> float:
	var before: float = max_hp if hp < 0.0 else minf(hp, max_hp)
	var after: float = minf(before + cfg(config, "rest_heal_ratio") * max_hp, max_hp)
	hp = after
	return after - before


## Rest node, "Ren": upgrades the deck entry at [param index] by rest_forge_levels, capped at
## SkillConfig.MAX_LEVEL. Returns {"ok": bool, "level": int}; ok false for a bad index or a card
## already at the cap (level = its current level, or 0 for a bad index).
func rest_forge(index: int, config: Dictionary) -> Dictionary:
	if index < 0 or index >= deck.size():
		return {"ok": false, "level": 0}
	var e: Dictionary = deck[index]
	var level: int = int(e["level"])
	if level >= SkillConfig.MAX_LEVEL:
		return {"ok": false, "level": level}
	e["level"] = mini(level + int(cfg(config, "rest_forge_levels")), SkillConfig.MAX_LEVEL)
	return {"ok": true, "level": int(e["level"])}


## Adds a card with Deck.add semantics: a copy below [param max_level] is upgraded by 1 (the first
## such copy), else a new level-1 copy joins. Returns {"upgraded", "level", "id"}.
func add_card(id: String, max_level: int = SkillConfig.MAX_LEVEL) -> Dictionary:
	for e: Dictionary in deck:
		if str(e["id"]) == id and int(e["level"]) < max_level:
			e["level"] = int(e["level"]) + 1
			return {"upgraded": true, "level": int(e["level"]), "id": id}
	deck.append({"id": id, "level": 1})
	return {"upgraded": false, "level": 1, "id": id}


## Removes the card at [param index], spending one removal token. Refused (nothing changes, no
## token spent) with no token, a bad index or when the deck would drop below [param min_deck_size]
## (default: rewards.json min_deck_size). True when removed.
func remove_card_at(index: int, min_deck_size: int = -1) -> bool:
	var floor_size: int = min_deck_size if min_deck_size >= 0 else int(RewardRoller.load_config()["min_deck_size"])
	if removal_tokens <= 0 or index < 0 or index >= deck.size() or deck.size() <= floor_size:
		return false
	removal_tokens -= 1
	deck.remove_at(index)
	return true


## id -> highest copy level in the deck.
func deck_levels() -> Dictionary:
	var out: Dictionary = {}
	for e: Dictionary in deck:
		out[str(e["id"])] = maxi(int(out.get(str(e["id"]), 0)), int(e["level"]))
	return out


## Copies of the deck entries ({id, level}).
func deck_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in deck:
		out.append(e.duplicate())
	return out


## Stores the offer waiting for a pick.
func set_pending_reward(ids: Array[String]) -> void:
	pending_reward = ids.duplicate()


## Forgets the offer (picked or skipped).
func clear_pending_reward() -> void:
	pending_reward = []


## True while an offer waits for a pick.
func has_pending_reward() -> bool:
	return not pending_reward.is_empty()


## Deprecated shim (Story 022, for the unported flow): seed of the current column,
## ChaptersConfig.arena_seed_for(run_seed, chapter_index * 100 + column).
func floor_seed() -> int:
	return ChaptersConfig.arena_seed_for(run_seed, chapter_index * 100 + column)


## Deprecated shim: "chapter id/c<column>".
func floor_key(chapters: ChaptersConfig) -> String:
	return "%s/c%d" % [chapters.chapter_id(chapter_index), column]


## Deprecated shim: true on the last column of the map.
func is_last_floor(_chapters_unused: ChaptersConfig) -> bool:
	return not map.is_empty() and column >= map.size() - 1


## Deprecated shim: true when the chosen node is a boss.
func is_boss_match(_chapters_unused: ChaptersConfig) -> bool:
	return str(current_node().get("kind", "")) == KIND_BOSS


## Deprecated shim for the old per-match flow: no automatic heal, only [param passive_heal]; does
## NOT advance the map (the flow must call [method complete_node]).
func apply_match_won(hp_end: float, max_hp: float, _chapters_unused: ChaptersConfig, _is_boss: bool, passive_heal: float) -> void:
	hp = minf(hp_end + passive_heal, max_hp)


## Save form (v4): {version, character, chapter (id), map, column, node_index, cleared_nodes, hp,
## deck [{id, level}], run_seed, elapsed, pending_reward, revives, removal_tokens,
## cleared_bosses_this_run}. A [member needs_restart] session saves only
## {version, character, chapter, needs_restart, restart_reason, map: []}.
func to_dict() -> Dictionary:
	var chapter_id: String = _chapters.chapter_id(chapter_index) if _chapters != null else ""
	if needs_restart:
		return {"version": SAVE_VERSION, "character": character_id, "chapter": chapter_id,
			"needs_restart": true, "restart_reason": restart_reason, "map": []}
	return {
		"version": SAVE_VERSION, "character": character_id, "chapter": chapter_id,
		"map": map.duplicate(true), "column": column, "node_index": node_index,
		"cleared_nodes": cleared_nodes.duplicate(true), "hp": hp,
		"deck": deck_entries(), "run_seed": run_seed, "elapsed": elapsed_sec,
		"pending_reward": pending_reward.duplicate(), "revives": revives,
		"removal_tokens": removal_tokens, "cleared_bosses_this_run": cleared_bosses_this_run,
	}


## Rebuilds from [method to_dict]. Null on bad data (unknown chapter, bad map / position, no known
## card in the deck, no character). A v2/v3 (floor/match) run or a saved needs_restart run gives a
## session with [member needs_restart] true, [member restart_reason] [constant RESTART_OLD_SAVE],
## an empty map and an empty deck. Unknown cards are dropped (warning). [param cards] is optional:
## without it card ids are not validated.
static func from_dict(d: Dictionary, chapters: ChaptersConfig, cards: SkillConfig = null) -> RunSession:
	var ci: int = -1
	for i: int in chapters.chapter_count():
		if chapters.chapter_id(i) == str(d.get("chapter", "")):
			ci = i
	if ci < 0:
		push_warning("RunSession: unknown chapter '%s', run dropped" % str(d.get("chapter", "")))
		return null
	var s := RunSession.new()
	s._chapters = chapters
	s.character_id = str(d.get("character", ""))
	s.chapter_index = ci
	if int(d.get("version", 0)) < SAVE_VERSION or bool(d.get("needs_restart", false)):
		if s.character_id.is_empty():
			push_warning("RunSession: old run without character, dropped")
			return null
		s.needs_restart = true
		s.restart_reason = RESTART_OLD_SAVE
		return s
	s.map = _clean_map(d.get("map", []))
	s.column = int(d.get("column", 0))
	s.node_index = int(d.get("node_index", -1))
	if s.map.is_empty() or s.column < 0 or s.column > s.map.size():
		push_warning("RunSession: bad map or column %d, run dropped" % s.column)
		return null
	if s.node_index != -1 and (s.column >= s.map.size() or s.node_index < 0
			or s.node_index >= (s.map[s.column]["nodes"] as Array).size()):
		push_warning("RunSession: node %d out of range, run dropped" % s.node_index)
		return null
	s.cleared_nodes = _clean_cleared(d.get("cleared_nodes", []))
	s.removal_tokens = maxi(int(d.get("removal_tokens", 0)), 0)
	s.cleared_bosses_this_run = maxi(int(d.get("cleared_bosses_this_run", 0)), 0)
	s._won = s.cleared_bosses_this_run > 0
	s.hp = float(d.get("hp", -1.0))
	s.run_seed = int(d.get("run_seed", 0))
	s.elapsed_sec = maxf(float(d.get("elapsed", 0.0)), 0.0)
	s.revives = maxi(int(d.get("revives", 0)), 0)
	s.deck = _known_entries(d.get("deck", []), cards)
	s.pending_reward = _known_ids(d.get("pending_reward", []), cards)
	if s.character_id.is_empty() or s.deck.is_empty():
		push_warning("RunSession: no character or empty deck, run dropped")
		return null
	return s


func _is_cleared(col: int, idx: int) -> bool:
	for c: Variant in cleared_nodes:
		if int((c as Dictionary)["column"]) == col and int((c as Dictionary)["node_index"]) == idx:
			return true
	return false


# Map from saved JSON (numbers come back as floats): {index, tier, nodes [{kind, match_id}]}; [] if malformed.
static func _clean_map(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for c: Variant in raw as Array:
		if typeof(c) != TYPE_DICTIONARY or typeof((c as Dictionary).get("nodes")) != TYPE_ARRAY:
			return [] as Array[Dictionary]
		var nodes: Array = []
		for n: Variant in (c as Dictionary)["nodes"] as Array:
			if typeof(n) != TYPE_DICTIONARY:
				return [] as Array[Dictionary]
			nodes.append({"kind": str((n as Dictionary).get("kind", "")), "match_id": str((n as Dictionary).get("match_id", ""))})
		if nodes.is_empty():
			return [] as Array[Dictionary]
		out.append({"index": int((c as Dictionary).get("index", out.size())), "tier": int((c as Dictionary).get("tier", 0)), "nodes": nodes})
	return out


static func _clean_cleared(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for c: Variant in raw as Array:
		if typeof(c) == TYPE_DICTIONARY:
			out.append({"column": int((c as Dictionary).get("column", 0)),
				"node_index": int((c as Dictionary).get("node_index", 0)), "kind": str((c as Dictionary).get("kind", ""))})
	return out


static func _known_ids(raw: Variant, cards: SkillConfig) -> Array[String]:
	var out: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for entry: Variant in raw as Array:
		var id: String = str(entry)
		if cards != null and not cards.has_skill(id):
			push_warning("RunSession: unknown card '%s' dropped" % id)
		else:
			out.append(id)
	return out


# Deck entries ([{id, level}] or id strings = level 1); unknown cards dropped.
static func _known_entries(raw: Variant, cards: SkillConfig) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for entry: Variant in raw as Array:
		var id: String = str((entry as Dictionary).get("id", "")) if typeof(entry) == TYPE_DICTIONARY else str(entry)
		var level: int = int((entry as Dictionary).get("level", 1)) if typeof(entry) == TYPE_DICTIONARY else 1
		if id.is_empty() or (cards != null and not cards.has_skill(id)):
			push_warning("RunSession: unknown card '%s' dropped" % id)
		else:
			out.append({"id": id, "level": clampi(level, 1, SkillConfig.MAX_LEVEL)})
	return out
