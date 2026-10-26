class_name RunSession
extends RefCounted
## Pure data + rules of one ROGUELIKE RUN (Story 019, map model Story 022, WORLD model Story 031 / save
## v5): one character climbs [method floors] FLOORS; at each floor it picks one of the offered REGIONS
## ([member region_offer], WorldMapGen) and walks that region's short MAP (columns of nodes, one node
## taken per column). The region boss does NOT win the run: it moves to the next floor, heals
## `world.floor_heal_ratio` x max HP (clamped) and rolls the next offer. After the last floor the run
## stands at the FINAL match (`world.final_match`, a one-node map); winning it wins the run. Holds what
## must survive between nodes and in the save: deck, HP, floor, region, offer, path, map position, seed,
## clock, pending card offer, removal tokens and cleared nodes. No nodes, no files. HP rules (Story 022):
## starts full (hp = -1); NO automatic heal after a node (only passive/card heal passed in, the rest
## node, the floor heal, cards); hp never exceeds max. Death simply ends the run (caller discards it).
## Map shape (built by ChapterMapGen, Story 022 Part 1a): Array of columns
## {"index": int, "tier": int, "nodes": [{"kind": String, "match_id": String}]}.
## A "region" is a chapter of chapters.json (never `zone`: that word is the seals/thorns of Story 027).
## While a floor's offer is open the previous region's (finished) map stays in [member map] so a
## pending boss offer can still be shown over it; [method choose_region] replaces it.

## Save format version written by [method to_dict] (v6, Story 035: boss_fates, pending_fate, stats).
const SAVE_VERSION: int = 6
## Oldest save [method from_dict] still loads as a live run (a v5 save gets the Story 035 fields at their
## defaults); anything older loads as [member needs_restart].
const MIN_LOADABLE_VERSION: int = 5
## Restart reason key for a pre-v5 (chapter / floor) run found in a save (shown as one line by the flow).
const RESTART_OLD_SAVE: String = "run.restart.old_save"
## Node kind that ends a region (and grants a removal token).
const KIND_BOSS: String = "boss"
## Documented fallbacks for the economy keys of rewards.json (the single place; the file wins).
## Story 034: refusal key of a shape removal with no `shape_removals` token left.
const REASON_NO_TOKEN: String = "piece_deck.reason.no_token"
## Story 035: counters of [member stats] that are HP sums (floats); the others are counts (ints).
const STAT_DAMAGE_KEYS: Array[String] = ["damage_dealt", "damage_taken"]
const STAT_COUNT_KEYS: Array[String] = ["hits_taken", "casts", "joins", "featured_casts", "signatures_used"]
const CONFIG_DEFAULTS: Dictionary = {
	"starting_removals": 1, "luck_start": 0.0, "luck_per_node": 1.0,
	"rest_heal_ratio": 0.3, "rest_forge_levels": 1, "boss_removal_tokens": 1,
}

## Character id (CharacterConfig).
var character_id: String = ""
## Story 031: 0-based floor (0..floors-1); == [method floors] at the final match.
var floor: int = 0
## Story 031: id of the region being walked (the last one walked while [member region_offer] is open;
## "" before the first pick). At the final match: `world.final_match.region`.
var region_id: String = ""
## Story 031: region ids offered at [member floor]; [] once one is chosen (and at the final match).
var region_offer: Array[String] = []
## Story 031: region ids chosen so far, one per floor (index = floor).
var region_path: Array[String] = []
## Index into ChaptersConfig of [member region_id] (kept in sync; -1 without a region).
var chapter_index: int = 0
## The current region's map (see class doc); [] before the first region is chosen.
var map: Array[Dictionary] = []
## Current column index (0-based); == map.size() once the last column is done.
var column: int = 0
## Chosen node in the current column; -1 = none chosen yet.
var node_index: int = -1
## Nodes already passed in the CURRENT region: {column, node_index, kind}.
var cleared_nodes: Array = []
## Story 031: nodes cleared over the whole run (luck counts these; a new region resets [member cleared_nodes]).
var nodes_cleared: int = 0
## Story 031: kind of the node completed last ("" before any); the flow derives an open offer's kind.
var last_node_kind: String = ""
## Story 031: HP the last region boss healed (the floor-clear banner); 0 before any.
var last_floor_heal: float = 0.0
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
## Seed of the whole run (offers, map and arena seeds derive from it).
var run_seed: int = 0
## Seconds of PLAYING time of the run (written by the flow).
var elapsed_sec: float = 0.0
## Card ids offered after the last won node and not yet picked / skipped; [] when none.
var pending_reward: Array[String] = []
## Story 032: relic ids owned, in the order received (unique; RelicRegistry ids).
var relics: Array[String] = []
## Story 032: relic ids offered on the open treasure screen (the second row next to [member pending_reward]);
## [] when none. Picking a card or a relic, or skipping, closes BOTH rows.
var pending_relic_offer: Array[String] = []
## Story 034: the run's PIECE DECK (PieceDeck state {mult: {shape_id: float}, added: [shape_id]}); starts as
## PieceDeck.initial (every default-pool shape at mult 1.0, nothing added). Saved under `piece_deck`.
var piece_deck: Dictionary = PieceDeck.initial(piece_library())
## Story 034: tokens that remove a shape from [member piece_deck] at the piece deck screen (start value and
## shape_removals_per_boss per boss, both from rewards.json `piece_rewards`). Saved under `shape_removals`.
var shape_removals: int = piece_config().shape_removals_start
## Story 034: shape ids offered on the open reward screen's ink row ([] when none). Saved under
## `pending_ink_offer`. Picking an ink keeps the card / relic choice open; every other way to close the
## reward screen clears it (GameFlow).
var pending_ink_offer: Array[String] = []
## Story 033: gold of the run (never negative; starts at EconomyConfig `starting_gold`). Dropped by won
## nodes (GameFlow), spent at the shop / events; not carried to the next run.
var gold: int = EconomyConfig.shared().starting_gold()
## Story 033: temporary rules of the run [{id, matches_left, params}] (event `run_modifier`, e.g. the pledge
## `loi_the`): -1 per match played ([method tick_run_modifiers]), dropped at 0. `params` is a config override
## per key in RelicRegistry.merge_overrides form, e.g. {"step_cooldown": {"mul": 1.2}}.
var run_modifiers: Array[Dictionary] = []
## Story 033: opaque shop state of the node being visited (stored / returned as is; written by the shop
## logic, {} = none). Saved under `shop_state`.
var shop_state: Dictionary = {}
## Story 033: opaque event state of the node being visited (as [member shop_state]). Saved under `event_state`.
var event_state: Dictionary = {}
## Story 033: gold the node completed last dropped (the reward screen's "+N vàng"); saved under
## `last_gold_gain` so a resumed reward screen still shows it (absent = 0).
var last_gold_gain: int = 0
## Story 033: card data used by the curse-aware deck rules ([method remove_card_at], [method rest_forge]).
## Injected by the flow ([method from_dict] sets it from its `cards` argument); null = the shared
## cards.json (loaded once, see [method _cards_config]).
var cards_config: SkillConfig = null
static var _shared_cards: SkillConfig = null
static var _shared_pieces: PieceLibrary = null
static var _shared_piece_config: PieceDeckConfig = null
## Story 035: one entry per region boss met, in order: {floor: int, region_id: String, match_id: String,
## fate: "spare"|"execute"}. Saved under `boss_fates`; decides the ending ([method ending_id]).
var boss_fates: Array[Dictionary] = []
## Story 035: true from the moment a region boss is downed until a fate is chosen ([method begin_fate] ..
## [method record_fate]); a saved run with it set resumes on the Spare / Execute screen, no match replay.
var pending_fate: bool = false
## Story 035: the boss waiting for a fate: {floor, region_id, match_id} ({} when not [member pending_fate]).
var pending_fate_match: Dictionary = {}
## Story 035: run counters (all in the save): matches_won, damage_dealt, damage_taken, hits_taken, casts,
## joins, featured_casts, signatures_used (numbers, start 0) and `death` ({} or {floor, region_id, match_id,
## boss_name_key}). Filled by [method add_match_stats] / [method record_death].
var stats: Dictionary = _new_stats()
## Revive tokens (from chapters defaults; reserved, unused).
var revives: int = 0
## True when this session came from a pre-v5 save: the flow must start a fresh world run for
## [member character_id] (map empty, deck/hp meaningless).
var needs_restart: bool = false
## Localisation key of the one-line restart notice ("" when not [member needs_restart]).
var restart_reason: String = ""
var _won: bool = false
# Config the session was built with (world rules, region ids).
var _chapters: ChaptersConfig = null


## Story 031: new WORLD run: floor 0, the floor-0 [member region_offer] rolled, no region yet (empty
## map), full HP, deck = the character's starter_deck, revives from `defaults.revive_tokens`.
## [param starting_removals] = rewards.json starting_removals.
static func begin_world(chapters: ChaptersConfig, character: Dictionary, run_seed: int,
		starting_removals: int = 0) -> RunSession:
	var s := RunSession.new()
	s._chapters = chapters
	s.character_id = str(character.get("id", ""))
	s.run_seed = run_seed
	s.region_id = ""
	s.chapter_index = -1
	s.removal_tokens = maxi(starting_removals, 0)
	for id: Variant in character.get("starter_deck", []) as Array:
		s.deck.append({"id": str(id), "level": 1})
	s.revives = int(chapters.defaults().get("revive_tokens", 0))
	s.region_offer = s.roll_offer()
	return s


## Legacy / test entry (Story 022): a run already INSIDE chapter (= region) [param chapter_index] at
## floor 0 with the given [param map] (no offer, path = [that region]). Its boss moves to floor 1 like
## any region boss.
static func begin(chapters: ChaptersConfig, character: Dictionary, chapter_index: int, run_seed: int,
		map: Array[Dictionary] = [], starting_removals: int = 0) -> RunSession:
	var s := begin_world(chapters, character, run_seed, starting_removals)
	s.chapter_index = clampi(chapter_index, 0, chapters.chapter_count() - 1)
	s.region_id = chapters.chapter_id(s.chapter_index)
	s.region_offer = []
	s.region_path = [s.region_id]
	s.map = map.duplicate(true)
	return s


## Story 031: floors before the final match (`world.floors`; the fallback without a config).
func floors() -> int:
	return _chapters.world_floors() if _chapters != null else ChaptersConfig.DEFAULT_WORLD_FLOORS


## Story 031: true while the run stands at (or plays) the final match.
func is_final_floor() -> bool:
	return floor >= floors()


## Story 031: true while [member region_offer] waits for [method choose_region].
func is_choosing_region() -> bool:
	return not region_offer.is_empty()


## Story 031: the offer of [member floor] (WorldMapGen.offer_for_floor over `world.region_pool`,
## `choices_per_floor` ids, seeded by run seed / floor / path). [] at the final floor or without config.
func roll_offer() -> Array[String]:
	if _chapters == null or is_final_floor():
		return [] as Array[String]
	var pool: Array[String] = _chapters.region_ids()
	if pool.is_empty() and _chapters.chapter_count() > 0:
		pool = [_chapters.chapter_id(0)]
	var choices: int = int(_chapters.world_spec().get("choices_per_floor", ChaptersConfig.DEFAULT_CHOICES_PER_FLOOR))
	return WorldMapGen.offer_for_floor(pool, run_seed, floor, region_path, choices)


## Story 031: picks [param id] from [member region_offer]: its map is generated for this floor
## (ChaptersConfig.generate_region_map, tier capped while [param cleared_bosses] is 0), column 0, the
## region joins [member region_path], the offer closes. False (no change) when [param id] is not offered,
## an offer is still pending a pick, or the region has no map.
func choose_region(id: String, cleared_bosses: int) -> bool:
	if not region_offer.has(id) or _chapters == null or has_pending_reward():
		return false
	var new_map: Array[Dictionary] = _chapters.generate_region_map(id, run_seed, floor, cleared_bosses)
	if new_map.is_empty():
		return false
	_enter_region(id, new_map)
	region_path.append(id)
	region_offer = []
	return true


# Puts the run at column 0 of region [param id] with [param new_map].
func _enter_region(id: String, new_map: Array[Dictionary]) -> void:
	region_id = id
	chapter_index = _chapters.region_index(id) if _chapters != null else chapter_index
	map = new_map.duplicate(true)
	column = 0
	node_index = -1
	cleared_nodes = []


# The final floor's map (ChaptersConfig.final_map): the `world.final_prelude` columns (TD-029: a shop
# before the final) then the final match's boss column; [] when `world.final_match` is not set. Only the
# boss column holds a match; the prelude nodes complete like region shop / rest nodes (column + 1).
func _final_map() -> Array[Dictionary]:
	if _chapters == null:
		return [] as Array[Dictionary]
	return _chapters.final_map()


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
## second_wind, 0 by default). Records {column, node_index, kind} in [member cleared_nodes] (and counts
## [member nodes_cleared] for luck), resets [member node_index] to -1 and moves to the next column. A
## [constant KIND_BOSS] node grants `boss_removal_tokens` (1) removal tokens and counts in
## [member cleared_bosses_this_run]; Story 031: a REGION boss does not win the run: [member floor] +1,
## heal `world.floor_heal_ratio` x [param max_hp] (clamped, [member last_floor_heal]) and the next
## [member region_offer] is rolled (after the last floor: the final match's one-node map instead); the
## FINAL match's boss wins the run. Returns {"advanced": bool, "run_won": bool, "floor_cleared": bool,
## "healed": float, "region": String (the region whose node completed)}; no node chosen ->
## {advanced:false} and nothing changes. [param node_kind] overrides the chosen node's kind when not empty.
func complete_node(hp_end: float, max_hp: float, node_kind: String, config: Dictionary, passive_heal: float = 0.0) -> Dictionary:
	if node_index < 0 or current_column().is_empty():
		return {"advanced": false, "run_won": is_run_won(), "floor_cleared": false, "healed": 0.0, "region": region_id}
	var kind: String = node_kind if not node_kind.is_empty() else str(current_node().get("kind", ""))
	var region_done: String = region_id
	hp = minf(hp_end + maxf(passive_heal, 0.0), max_hp)
	cleared_nodes.append({"column": column, "node_index": node_index, "kind": kind})
	nodes_cleared += 1
	last_node_kind = kind
	node_index = -1
	column += 1
	var floor_cleared: bool = false
	var healed: float = 0.0
	if kind == KIND_BOSS:
		removal_tokens += int(cfg(config, "boss_removal_tokens"))
		shape_removals += maxi(piece_config().shape_removals_per_boss, 0)
		cleared_bosses_this_run += 1
		if is_final_floor():
			_won = true
		else:
			healed = _clear_floor(max_hp)
			floor_cleared = true
	return {"advanced": true, "run_won": is_run_won(), "floor_cleared": floor_cleared, "healed": healed, "region": region_done}


# A region boss fell: heal floor_heal_ratio x max_hp (clamped; a full hp heals nothing), next floor,
# next offer (or the final map after the last floor). Returns the HP healed.
func _clear_floor(max_hp: float) -> float:
	var ratio: float = _chapters.floor_heal_ratio() if _chapters != null else ChaptersConfig.DEFAULT_FLOOR_HEAL_RATIO
	var before: float = max_hp if hp < 0.0 else minf(hp, max_hp)
	var after: float = minf(before + maxf(ratio, 0.0) * max_hp, max_hp)
	hp = after
	last_floor_heal = after - before
	floor += 1
	if is_final_floor():
		region_offer = []
		var final_map: Array[Dictionary] = _final_map()
		if final_map.is_empty():
			push_warning("RunSession: world.final_match not set, the run is won after the last floor")
			_won = true
		else:
			_enter_region(str(_chapters.final_match().get("region", region_id)), final_map)
	else:
		region_offer = roll_offer()
		if region_offer.is_empty():
			push_warning("RunSession: no region to offer at floor %d, the run is won" % floor)
			_won = true
	return last_floor_heal


## True once the FINAL match was won (Story 031: a region boss never wins the run).
func is_run_won() -> bool:
	return _won


## Run luck = luck_start + luck_per_node x nodes cleared over the whole run (rewards.json via [param config]).
func luck(config: Dictionary = {}) -> float:
	return cfg(config, "luck_start") + cfg(config, "luck_per_node") * float(nodes_cleared)


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
	if level >= SkillConfig.MAX_LEVEL or is_curse_card(str(e["id"])):
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
## token spent) with no token, a bad index or when a NON-curse card would leave [param min_deck_size]
## (default: rewards.json min_deck_size) or fewer non-curse cards. Story 033: curse cards do not count
## toward the minimum and a curse can always be removed. True when removed.
func remove_card_at(index: int, min_deck_size: int = -1) -> bool:
	var floor_size: int = min_deck_size if min_deck_size >= 0 else int(RewardRoller.load_config()["min_deck_size"])
	if removal_tokens <= 0 or not can_remove_card_at(index, floor_size):
		return false
	removal_tokens -= 1
	deck.remove_at(index)
	return true


## Story 033: whether the deck card at [param index] may leave the deck under the minimum-size rule
## (tokens not checked): always for a curse card; for any other card only while more than
## [param min_deck_size] non-curse cards remain. False for a bad index.
func can_remove_card_at(index: int, min_deck_size: int) -> bool:
	if index < 0 or index >= deck.size():
		return false
	if is_curse_card(str(deck[index]["id"])):
		return true
	return non_curse_count() > min_deck_size


## Story 033: count of deck cards that are not curses.
func non_curse_count() -> int:
	var n: int = 0
	for e: Dictionary in deck:
		if not is_curse_card(str(e["id"])):
			n += 1
	return n


## Story 033: true when [param id] is a curse card ([member cards_config], else the shared cards.json).
func is_curse_card(id: String) -> bool:
	var cards: SkillConfig = _cards_config()
	return cards != null and cards.is_curse(id)


func _cards_config() -> SkillConfig:
	if cards_config != null:
		return cards_config
	if _shared_cards == null:
		_shared_cards = SkillConfig.load_from_file()
	return _shared_cards


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


## Story 033: adds [param n] gold (a non-positive [param n] changes nothing). Returns the new total.
func add_gold(n: int) -> int:
	if n > 0:
		gold += n
	return gold


## Story 033: spends [param n] gold. False (nothing changes) when the run has less than [param n]; gold never
## goes below 0. A non-positive [param n] spends nothing and returns true.
func spend_gold(n: int) -> bool:
	if n <= 0:
		return true
	if gold < n:
		return false
	gold -= n
	return true


## Story 033: adds a run modifier {id, matches_left, params}. False (no change, warning) with an empty id or
## `matches_left` < 1; the entry is stored as a deep copy (`matches_left` int, `params` object).
func add_run_modifier(mod: Dictionary) -> bool:
	var id: String = str(mod.get("id", ""))
	var left: int = int(mod.get("matches_left", 0))
	if id.is_empty() or left < 1:
		push_warning("RunSession: run modifier '%s' with matches_left %d ignored" % [id, left])
		return false
	var params: Dictionary = {}
	if typeof(mod.get("params")) == TYPE_DICTIONARY:
		params = (mod["params"] as Dictionary).duplicate(true)
	run_modifiers.append({"id": id, "matches_left": left, "params": params})
	return true


## Story 033: one match was played: every modifier loses 1 match; those that reach 0 are dropped. Returns
## the ids that expired. Call once per match played (GameFlow does it when a match node closes).
func tick_run_modifiers() -> Array[String]:
	var expired: Array[String] = []
	var kept: Array[Dictionary] = []
	for m: Dictionary in run_modifiers:
		m["matches_left"] = int(m["matches_left"]) - 1
		if int(m["matches_left"]) <= 0:
			expired.append(str(m["id"]))
		else:
			kept.append(m)
	run_modifiers = kept
	return expired


## Story 033: true while a modifier of [param id] is active.
func has_run_modifier(id: String) -> bool:
	for m: Dictionary in run_modifiers:
		if str(m["id"]) == id:
			return true
	return false


## Story 033: the active modifiers' override of config [param key] folded like RelicRegistry.merge_overrides:
## {add: sum, mul: product[, set: last]}; {} when no active modifier touches [param key]. Apply it with
## RelicRegistry.apply_override(base, {key: result}, key). Key in use: `step_cooldown` (the player's step
## cooldown, `{mul: 1.2}` = 20 % slower).
func active_modifier_params(key: String) -> Dictionary:
	var slot: Dictionary = {}
	for m: Dictionary in run_modifiers:
		var entry: Variant = (m["params"] as Dictionary).get(key)
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if slot.is_empty():
			slot = {"add": 0.0, "mul": 1.0}
		slot["add"] = float(slot["add"]) + float((entry as Dictionary).get("add", 0.0))
		slot["mul"] = float(slot["mul"]) * float((entry as Dictionary).get("mul", 1.0))
		if (entry as Dictionary).has("set"):
			slot["set"] = float((entry as Dictionary)["set"])
	return slot


## Story 033: the whole override table of the active modifiers: key -> [method active_modifier_params] (the
## `merge_overrides` form; what GameFlow / RunController hand to the match as `run_modifiers`).
func run_modifier_overrides() -> Dictionary:
	var keys: Array[String] = []
	for m: Dictionary in run_modifiers:
		for k: Variant in (m["params"] as Dictionary).keys():
			if not keys.has(str(k)):
				keys.append(str(k))
	var out: Dictionary = {}
	for k: String in keys:
		var slot: Dictionary = active_modifier_params(k)
		if not slot.is_empty():
			out[k] = slot
	return out


## Story 034: the shared piece library (pieces.json, loaded once per process).
static func piece_library() -> PieceLibrary:
	if _shared_pieces == null:
		_shared_pieces = PieceLibrary.load_from_file()
	return _shared_pieces


## Story 034: the shared piece-deck rules (rewards.json `piece_rewards`, loaded once per process).
static func piece_config() -> PieceDeckConfig:
	if _shared_piece_config == null:
		_shared_piece_config = PieceDeckConfig.load_from_file()
	return _shared_piece_config


## Story 034: inks shape [param id] into [member piece_deck] (PieceDeck.apply_ink: a new run-only shape joins,
## a removed one returns at mult 1.0, others gain mult_step up to mult_max). False (no change) when the shape
## is unknown or already at the ceiling. [param lib] / [param cfg] default to the shipped data.
func apply_ink(id: String, lib: PieceLibrary = null, cfg: PieceDeckConfig = null) -> bool:
	var l: PieceLibrary = lib if lib != null else piece_library()
	var c: PieceDeckConfig = cfg if cfg != null else piece_config()
	if not PieceDeck.can_ink(piece_deck, id, l, c):
		return false
	piece_deck = PieceDeck.apply_ink(piece_deck, id, l, c)
	return true


## Story 034: whether shape [param id] may be removed now: {"ok": bool, "reason": String}. With
## [param spend_token] a token is needed ([constant REASON_NO_TOKEN] at 0 [member shape_removals]); then
## PieceDeck.can_remove (unknown, already removed, would leave fewer than `min_shapes` active shapes).
func can_remove_shape(id: String, spend_token: bool, lib: PieceLibrary = null, cfg: PieceDeckConfig = null) -> Dictionary:
	var l: PieceLibrary = lib if lib != null else piece_library()
	var c: PieceDeckConfig = cfg if cfg != null else piece_config()
	if spend_token and shape_removals <= 0:
		return {"ok": false, "reason": REASON_NO_TOKEN}
	var verdict: Dictionary = PieceDeck.can_remove(piece_deck, id, l, c)
	return {"ok": bool(verdict.get("ok", false)), "reason": str(verdict.get("reason", ""))}


## Story 034: removes shape [param id] from [member piece_deck] (mult 0). With [param spend_token] true it
## also spends one [member shape_removals] token; the shop service passes false (it charges gold instead).
## Refused (nothing changes) when [method can_remove_shape] says no. Returns {"ok": bool, "reason": String}
## (reason is a translation key, "" when ok).
func remove_shape(id: String, spend_token: bool, lib: PieceLibrary = null, cfg: PieceDeckConfig = null) -> Dictionary:
	var l: PieceLibrary = lib if lib != null else piece_library()
	var c: PieceDeckConfig = cfg if cfg != null else piece_config()
	var verdict: Dictionary = can_remove_shape(id, spend_token, l, c)
	if not bool(verdict["ok"]):
		return verdict
	piece_deck = PieceDeck.remove(piece_deck, id, l, c)
	if spend_token:
		shape_removals -= 1
	return {"ok": true, "reason": ""}


## Story 034: stores the ink row of the open reward screen.
func set_pending_ink_offer(ids: Array[String]) -> void:
	pending_ink_offer = ids.duplicate()


## Story 034: closes the ink row (picked, skipped or the reward screen closed another way).
func clear_pending_ink_offer() -> void:
	pending_ink_offer = []


## Story 034: true while an ink row waits for a pick.
func has_pending_ink_offer() -> bool:
	return not pending_ink_offer.is_empty()


## Story 035: a REGION boss was downed: the run now waits for a fate. [param match_info] = {floor, region_id,
## match_id} (a missing key defaults to the run's [member floor], [member region_id] and ""). Sets
## [member pending_fate] / [member pending_fate_match]; call it BEFORE [method complete_node] (which moves the floor).
func begin_fate(match_info: Dictionary) -> void:
	pending_fate = true
	pending_fate_match = {
		"floor": int(match_info.get("floor", floor)),
		"region_id": str(match_info.get("region_id", region_id)),
		"match_id": str(match_info.get("match_id", "")),
	}


## Story 035: the player chose [param fate] ("spare" | "execute") for the pending boss: appends the entry to
## [member boss_fates] and clears the pending state. False (no change) when no fate is pending or the fate is unknown.
func record_fate(fate: String) -> bool:
	if not pending_fate or not FateLogic.is_valid_fate(fate):
		return false
	boss_fates.append({
		"floor": int(pending_fate_match.get("floor", floor)),
		"region_id": str(pending_fate_match.get("region_id", region_id)),
		"match_id": str(pending_fate_match.get("match_id", "")),
		"fate": fate,
	})
	pending_fate = false
	pending_fate_match = {}
	return true


## Story 035: true while a fate waits for a choice.
func is_fate_pending() -> bool:
	return pending_fate


## Story 035: adds one match's counters ([param d] = CombatView.get_match_stats(): damage_dealt, damage_taken,
## hits_taken, casts, joins, featured_casts, signatures_used; missing keys count 0, negatives are ignored) to
## [member stats]; `matches_won` +1 when [param won].
func add_match_stats(d: Dictionary, won: bool) -> void:
	for k: String in STAT_DAMAGE_KEYS:
		stats[k] = float(stats.get(k, 0.0)) + maxf(float(d.get(k, 0.0)), 0.0)
	for k: String in STAT_COUNT_KEYS:
		stats[k] = int(stats.get(k, 0)) + maxi(int(d.get(k, 0)), 0)
	if won:
		stats["matches_won"] = int(stats.get("matches_won", 0)) + 1


## Story 035: stores where and to whom the run fell: [param info] = {floor, region_id, match_id, boss_name_key}
## (missing keys default to the run's floor / region and ""). Saved in [member stats] under `death`.
func record_death(info: Dictionary) -> void:
	stats["death"] = {
		"floor": int(info.get("floor", floor)),
		"region_id": str(info.get("region_id", region_id)),
		"match_id": str(info.get("match_id", "")),
		"boss_name_key": str(info.get("boss_name_key", "")),
	}


## Story 035: the ending of this run ([member boss_fates] through FateLogic.ending_for with
## [param endings_cfg] = `world.endings`): "spare", "execute" or "balance".
func ending_id(endings_cfg: Dictionary) -> String:
	return FateLogic.ending_for(boss_fates, endings_cfg)


## Story 035: everything the ending and defeat screens show: {character, elapsed_sec, region_path (Array[String]),
## floor_reached (1-based: [member floor] + 1, so 6 at the final match), matches_won, damage_dealt, damage_taken,
## hits_taken, casts, joins, featured_casts, signatures_used, deck_size, highest_card_level (0 for an empty
## deck), relics (Array[String]), fates (Array[Dictionary], copies of [member boss_fates]), death (Dictionary,
## {} when the run did not end in a defeat)}.
func stats_summary() -> Dictionary:
	var highest: int = 0
	for e: Dictionary in deck:
		highest = maxi(highest, int(e["level"]))
	var fates: Array[Dictionary] = []
	for f: Dictionary in boss_fates:
		fates.append(f.duplicate())
	return {
		"character": character_id, "elapsed_sec": elapsed_sec, "region_path": region_path.duplicate(),
		"floor_reached": floor + 1, "matches_won": int(stats.get("matches_won", 0)),
		"damage_dealt": float(stats.get("damage_dealt", 0.0)), "damage_taken": float(stats.get("damage_taken", 0.0)),
		"hits_taken": int(stats.get("hits_taken", 0)), "casts": int(stats.get("casts", 0)),
		"joins": int(stats.get("joins", 0)), "featured_casts": int(stats.get("featured_casts", 0)),
		"signatures_used": int(stats.get("signatures_used", 0)), "deck_size": deck.size(),
		"highest_card_level": highest, "relics": relics.duplicate(), "fates": fates,
		"death": (stats.get("death", {}) as Dictionary).duplicate(),
	}


# Story 035: the zeroed counters ([member stats] at the start of a run).
static func _new_stats() -> Dictionary:
	var out: Dictionary = {"matches_won": 0, "death": {}}
	for k: String in STAT_DAMAGE_KEYS:
		out[k] = 0.0
	for k: String in STAT_COUNT_KEYS:
		out[k] = 0
	return out


# Story 035: counters from a save (JSON numbers are floats): known keys only, negatives -> 0, `death` cleaned.
static func _clean_stats(raw: Variant) -> Dictionary:
	var out: Dictionary = _new_stats()
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = raw as Dictionary
	for k: String in STAT_DAMAGE_KEYS:
		out[k] = maxf(float(d.get(k, 0.0)), 0.0)
	for k: String in STAT_COUNT_KEYS:
		out[k] = maxi(int(d.get(k, 0)), 0)
	out["matches_won"] = maxi(int(d.get("matches_won", 0)), 0)
	if typeof(d.get("death")) == TYPE_DICTIONARY and not (d["death"] as Dictionary).is_empty():
		var dd: Dictionary = d["death"] as Dictionary
		out["death"] = {"floor": int(dd.get("floor", 0)), "region_id": str(dd.get("region_id", "")),
			"match_id": str(dd.get("match_id", "")), "boss_name_key": str(dd.get("boss_name_key", ""))}
	return out


# Story 035: boss_fates from a save: entries with a known fate only.
static func _clean_fates(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for entry: Variant in raw as Array:
		if typeof(entry) != TYPE_DICTIONARY or not FateLogic.is_valid_fate(str((entry as Dictionary).get("fate", ""))):
			continue
		out.append({"floor": int((entry as Dictionary).get("floor", 0)),
			"region_id": str((entry as Dictionary).get("region_id", "")),
			"match_id": str((entry as Dictionary).get("match_id", "")),
			"fate": str((entry as Dictionary)["fate"])})
	return out


## Story 032: adds relic [param id] (received order). False (no change) for a duplicate or an id unknown
## to RelicRegistry (warning).
func add_relic(id: String) -> bool:
	if id.is_empty() or relics.has(id):
		return false
	if not _relic_known(id):
		push_warning("RunSession: unknown relic '%s' not added" % id)
		return false
	relics.append(id)
	return true


## Story 032: true when relic [param id] is owned.
func has_relic(id: String) -> bool:
	return relics.has(id)


## Story 032: copy of the owned relic ids, in received order.
func relic_ids() -> Array[String]:
	return relics.duplicate()


## Story 032: stores the relic row of the open treasure offer.
func set_pending_relic_offer(ids: Array[String]) -> void:
	pending_relic_offer = ids.duplicate()


## Story 032: closes the relic row (picked or skipped).
func clear_pending_relic_offer() -> void:
	pending_relic_offer = []


## Story 032: true while a relic row waits for a pick.
func has_pending_relic_offer() -> bool:
	return not pending_relic_offer.is_empty()


# Story 032: [param id] is a relic of relics.json (RelicRegistry.info is not empty).
static func _relic_known(id: String) -> bool:
	return not RelicRegistry.info(id).is_empty()


## Seed of the current column's arena (Story 031):
## ChaptersConfig.arena_seed_for(run_seed, floor * 100 + column).
func floor_seed() -> int:
	return ChaptersConfig.arena_seed_for(run_seed, floor * 100 + column)


## Deprecated shim: "<region>/f<floor>/c<column>".
func floor_key(_chapters_unused: ChaptersConfig = null) -> String:
	return "%s/f%d/c%d" % [region_id, floor, column]


## Deprecated shim: true on the last column of the map.
func is_last_floor(_chapters_unused: ChaptersConfig) -> bool:
	return not map.is_empty() and column >= map.size() - 1


## Deprecated shim: true when the chosen node is a boss.
func is_boss_match(_chapters_unused: ChaptersConfig) -> bool:
	return str(current_node().get("kind", "")) == KIND_BOSS


## Save form (v6, Story 035; v5 added by Story 031): {version, character, floor, region, region_offer, region_path, map,
## column, node_index, cleared_nodes, nodes_cleared, last_node_kind, last_floor_heal, hp,
## deck [{id, level}], run_seed, elapsed, pending_reward, revives, removal_tokens,
## cleared_bosses_this_run, won, relics [id], pending_relic_offer [id], gold, run_modifiers [{id,
## matches_left, params}], shop_state {}, event_state {}, piece_deck {mult, added}, shape_removals,
## pending_ink_offer [id]} (Story 034 added the last three, optional like the rest: a save lacking them loads
## with PieceDeck.initial, `piece_rewards.shape_removals_start` and []) (relics..event_state are optional: Stories 032 / 033
## added them without a version bump; a save lacking them loads with no relics, `starting_gold`, [], {}, {}).
## Story 035 (v6) added `boss_fates` [{floor, region_id, match_id, fate}], `pending_fate` bool,
## `pending_fate_match` {floor, region_id, match_id} and `stats` {matches_won, damage_dealt, damage_taken,
## hits_taken, casts, joins, featured_casts, signatures_used, death}; a v5 save loads with [], false, {} and zeros.
## A [member needs_restart] session saves only
## {version, character, needs_restart, restart_reason, map: []}.
func to_dict() -> Dictionary:
	if needs_restart:
		return {"version": SAVE_VERSION, "character": character_id,
			"needs_restart": true, "restart_reason": restart_reason, "map": []}
	return {
		"version": SAVE_VERSION, "character": character_id, "floor": floor, "region": region_id,
		"region_offer": region_offer.duplicate(), "region_path": region_path.duplicate(),
		"map": map.duplicate(true), "column": column, "node_index": node_index,
		"cleared_nodes": cleared_nodes.duplicate(true), "nodes_cleared": nodes_cleared,
		"last_node_kind": last_node_kind, "last_floor_heal": last_floor_heal, "hp": hp,
		"deck": deck_entries(), "run_seed": run_seed, "elapsed": elapsed_sec,
		"pending_reward": pending_reward.duplicate(), "revives": revives,
		"removal_tokens": removal_tokens, "cleared_bosses_this_run": cleared_bosses_this_run,
		"won": _won, "relics": relics.duplicate(),
		"pending_relic_offer": pending_relic_offer.duplicate(),
		"gold": gold, "run_modifiers": run_modifiers.duplicate(true),
		"shop_state": shop_state.duplicate(true), "event_state": event_state.duplicate(true),
		"last_gold_gain": last_gold_gain,
		"piece_deck": piece_deck.duplicate(true), "shape_removals": shape_removals,
		"pending_ink_offer": pending_ink_offer.duplicate(),
		"boss_fates": boss_fates.duplicate(true), "pending_fate": pending_fate,
		"pending_fate_match": pending_fate_match.duplicate(true), "stats": stats.duplicate(true),
	}


## Rebuilds from [method to_dict] (v5 and v6 saves). Null on bad data (unknown region, floor out of range, bad map /
## position, an offer at the final floor, no known card in the deck, no character). A pre-v5 run
## (v2..v4 chapter / floor saves, version < [constant MIN_LOADABLE_VERSION]) or a saved needs_restart run gives a session with
## [member needs_restart] true, [member restart_reason] [constant RESTART_OLD_SAVE], an empty map and an
## empty deck (the flow starts a fresh world run for that character). Unknown cards are dropped
## (warning). [param cards] is optional: without it card ids are not validated.
static func from_dict(d: Dictionary, chapters: ChaptersConfig, cards: SkillConfig = null) -> RunSession:
	var s := RunSession.new()
	s._chapters = chapters
	s.character_id = str(d.get("character", ""))
	if int(d.get("version", 0)) < MIN_LOADABLE_VERSION or bool(d.get("needs_restart", false)):
		if s.character_id.is_empty():
			push_warning("RunSession: old run without character, dropped")
			return null
		s.needs_restart = true
		s.restart_reason = RESTART_OLD_SAVE
		s.chapter_index = -1
		return s
	s.floor = int(d.get("floor", 0))
	if s.floor < 0 or s.floor > s.floors():
		push_warning("RunSession: floor %d out of range, run dropped" % s.floor)
		return null
	s.region_id = str(d.get("region", ""))
	s.chapter_index = -1
	if not s.region_id.is_empty():
		s.chapter_index = chapters.region_index(s.region_id)
		if s.chapter_index < 0:
			push_warning("RunSession: unknown region '%s', run dropped" % s.region_id)
			return null
	s.region_offer = _string_list(d.get("region_offer", []))
	for id: String in s.region_offer:
		if chapters.region_index(id) < 0:
			push_warning("RunSession: unknown offered region '%s', run dropped" % id)
			return null
	s.region_path = _string_list(d.get("region_path", []))
	s.map = _clean_map(d.get("map", []))
	s.column = int(d.get("column", 0))
	s.node_index = int(d.get("node_index", -1))
	if s.region_offer.is_empty():
		if s.region_id.is_empty() or s.map.is_empty() or s.column < 0 or s.column > s.map.size():
			push_warning("RunSession: bad region map or column %d, run dropped" % s.column)
			return null
	elif s.is_final_floor() or s.node_index != -1 or s.column < 0 or s.column > s.map.size():
		push_warning("RunSession: region offer in a bad position, run dropped")
		return null
	if s.node_index != -1 and (s.column >= s.map.size() or s.node_index < 0
			or s.node_index >= (s.map[s.column]["nodes"] as Array).size()):
		push_warning("RunSession: node %d out of range, run dropped" % s.node_index)
		return null
	s.cleared_nodes = _clean_cleared(d.get("cleared_nodes", []))
	s.nodes_cleared = maxi(int(d.get("nodes_cleared", s.cleared_nodes.size())), 0)
	s.last_node_kind = str(d.get("last_node_kind", ""))
	s.last_floor_heal = maxf(float(d.get("last_floor_heal", 0.0)), 0.0)
	s.removal_tokens = maxi(int(d.get("removal_tokens", 0)), 0)
	s.cleared_bosses_this_run = maxi(int(d.get("cleared_bosses_this_run", 0)), 0)
	s._won = bool(d.get("won", false))
	s.hp = float(d.get("hp", -1.0))
	s.run_seed = int(d.get("run_seed", 0))
	s.elapsed_sec = maxf(float(d.get("elapsed", 0.0)), 0.0)
	s.revives = maxi(int(d.get("revives", 0)), 0)
	s.deck = _known_entries(d.get("deck", []), cards)
	s.pending_reward = _known_ids(d.get("pending_reward", []), cards)
	s.relics = _known_relics(d.get("relics", []), true)
	s.pending_relic_offer = _known_relics(d.get("pending_relic_offer", []), false)
	s.gold = maxi(int(d.get("gold", EconomyConfig.shared().starting_gold())), 0)
	s.run_modifiers = _clean_modifiers(d.get("run_modifiers", []))
	s.shop_state = (d["shop_state"] as Dictionary).duplicate(true) if typeof(d.get("shop_state")) == TYPE_DICTIONARY else {}
	s.event_state = (d["event_state"] as Dictionary).duplicate(true) if typeof(d.get("event_state")) == TYPE_DICTIONARY else {}
	s.last_gold_gain = maxi(int(d.get("last_gold_gain", 0)), 0)
	s.cards_config = cards
	s.piece_deck = PieceDeck.sanitize(d["piece_deck"], piece_library()) if typeof(d.get("piece_deck")) == TYPE_DICTIONARY else PieceDeck.initial(piece_library())
	s.shape_removals = maxi(int(d.get("shape_removals", piece_config().shape_removals_start)), 0)
	s.pending_ink_offer = _known_shapes(d.get("pending_ink_offer", []))
	s.boss_fates = _clean_fates(d.get("boss_fates", []))
	s.stats = _clean_stats(d.get("stats"))
	s.pending_fate = bool(d.get("pending_fate", false))
	if s.pending_fate:
		var pm: Dictionary = (d["pending_fate_match"] as Dictionary) if typeof(d.get("pending_fate_match")) == TYPE_DICTIONARY else {}
		s.pending_fate_match = {"floor": int(pm.get("floor", s.floor)), "region_id": str(pm.get("region_id", s.region_id)),
			"match_id": str(pm.get("match_id", ""))}
	if s.character_id.is_empty() or s.deck.is_empty():
		push_warning("RunSession: no character or empty deck, run dropped")
		return null
	return s


static func _string_list(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for v: Variant in raw as Array:
		out.append(str(v))
	return out


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


# Story 033: run modifiers from a save (JSON numbers are floats): entries with an id and matches_left >= 1.
static func _clean_modifiers(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for entry: Variant in raw as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id: String = str((entry as Dictionary).get("id", ""))
		var left: int = int((entry as Dictionary).get("matches_left", 0))
		if id.is_empty() or left < 1:
			continue
		var params: Dictionary = {}
		if typeof((entry as Dictionary).get("params")) == TYPE_DICTIONARY:
			params = ((entry as Dictionary)["params"] as Dictionary).duplicate(true)
		out.append({"id": id, "matches_left": left, "params": params})
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


# Story 034: shape ids of a saved ink offer: unknown ids dropped (warning), duplicates dropped.
static func _known_shapes(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for entry: Variant in raw as Array:
		var id: String = str(entry)
		if not piece_library().has_shape(id):
			push_warning("RunSession: unknown ink shape '%s' dropped" % id)
		elif not out.has(id):
			out.append(id)
	return out


# Story 032: relic ids from a save: unknown ids dropped (warning); [param unique] also drops duplicates.
static func _known_relics(raw: Variant, unique: bool) -> Array[String]:
	var out: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for entry: Variant in raw as Array:
		var id: String = str(entry)
		if id.is_empty() or not _relic_known(id):
			push_warning("RunSession: unknown relic '%s' dropped" % id)
		elif not (unique and out.has(id)):
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
