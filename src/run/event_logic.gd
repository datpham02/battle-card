class_name EventLogic
extends RefCounted
## Pure data + rules of the EVENT node (Story 033 Part C). Events live in assets/data/events.json
## (schema.md `events.json`); this class picks one for a node, describes it for the view (which choices
## are greyed out and why, which need a second tap) and resolves a choice into changes on the RunSession
## with a CLOSED effect vocabulary ([constant EFFECT_TYPES]). No nodes, no flow, no files except the
## events.json read; every number (costs, chances, rewards) is in the data.
##
## Determinism: an outcome is drawn from `hash([seed, floor, column, node_index, event_id, choice])`
## where seed defaults to `run.run_seed`, so resolving the same node and choice after a save / load
## gives the same result. Effects that need a PLAYER pick (choose 1 of 3 cards, upgrade which card,
## remove which card) are not applied by [method resolve]: they come back in `pending_picks` and are
## finished by [method complete_pick].
##
## `opts` (every public function; all keys optional): "events" Array (fixture instead of the shipped
## file), "cards" SkillConfig, "relic_config" RelicConfig, "reward_config" Dictionary (rewards.json),
## "seed" int (instead of run.run_seed), "args" Dictionary (resolve: {"relic_id": String} = the relic the
## player gives up in `swap_relic`).

const DEFAULT_PATH: String = "res://assets/data/events.json"
## The closed effect vocabulary of events.json.
const EFFECT_TYPES: Array[String] = [
	"gold", "hp", "relic", "card_offer", "curse", "remove_card", "upgrade_card", "fight", "run_modifier",
	"swap_relic",
]
## Relic rarity that `requires.relic: "non_boss"` and `swap_relic` exclude.
const BOSS_RARITY: String = "boss"
const REQ_NON_BOSS: String = "non_boss"

const KEY_NEED_GOLD: String = "ui.event.need_gold"
const KEY_NEED_RELIC: String = "ui.event.need_relic"
const KEY_NEED_HP: String = "ui.event.need_hp"
const KEY_NEED_CARDS: String = "ui.event.need_cards"
const KEY_NEED_UPGRADABLE: String = "ui.event.need_upgradable"
const KEY_BAD_CHOICE: String = "ui.event.bad_choice"

static var _shared_events: Array[Dictionary] = []
static var _shared_loaded: bool = false
static var _shared_cards: SkillConfig = null


## The validated events of [param path] (the shipped file by default; cached for the default path).
## A bad file gives [] (warning); a bad event or choice is dropped, an unknown effect type is dropped
## with a warning, never a crash.
static func load_events(path: String = DEFAULT_PATH) -> Array[Dictionary]:
	if path == DEFAULT_PATH and _shared_loaded:
		return _shared_events
	var out: Array[Dictionary] = []
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY and typeof((parsed as Dictionary).get("events")) == TYPE_ARRAY:
			for raw: Variant in (parsed as Dictionary)["events"] as Array:
				var event: Dictionary = _clean_event(raw)
				if not event.is_empty():
					out.append(event)
		else:
			push_warning("EventLogic: %s has no `events` array, no events" % path)
	else:
		push_warning("EventLogic: file not found: %s, no events" % path)
	if path == DEFAULT_PATH:
		_shared_events = out
		_shared_loaded = true
	return out


## Forgets the cached shipped events (the next call reloads the file).
static func reset_shared() -> void:
	_shared_events = []
	_shared_loaded = false
	_shared_cards = null


## Every event id in file order.
static func event_ids(opts: Dictionary = {}) -> Array[String]:
	var ids: Array[String] = []
	for event: Dictionary in _events(opts):
		ids.append(str(event["id"]))
	return ids


## The event [param event_id] ({} when unknown).
static func get_event(event_id: String, opts: Dictionary = {}) -> Dictionary:
	for event: Dictionary in _events(opts):
		if str(event["id"]) == event_id:
			return event
	return {}


## The event of the node ([param floor], [param column], [param node_index]) of the run [param run_seed]:
## seeded, never one of [param used_ids] while an unused one is left (when every event was seen the pool
## restarts). "" without events. Same inputs = same id.
static func pick_event(run_seed: int, floor: int, column: int, node_index: int, used_ids: Array,
		opts: Dictionary = {}) -> String:
	var all: Array[String] = event_ids(opts)
	if all.is_empty():
		return ""
	var pool: Array[String] = []
	for id: String in all:
		if not used_ids.has(id):
			pool.append(id)
	if pool.is_empty():
		pool = all
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, floor, column, node_index, "event"])
	return pool[rng.randi_range(0, pool.size() - 1)]


## What the view shows: {"id", "title_key", "body_key", "choices": [{"index", "id", "label_key",
## "cost_key", "enabled": bool, "reason_key": String, "reason_args": Array, "needs_confirm": bool}]}.
## A choice whose `requires` (or an implied need, e.g. a card that can be upgraded) fails is
## `enabled: false` with the reason key and its printf args ("" and [] when enabled). {} for an unknown
## event. [param max_hp] is the player's max HP (HP costs are ratios of it).
static func describe(event_id: String, run: RunSession, max_hp: float, opts: Dictionary = {}) -> Dictionary:
	var event: Dictionary = get_event(event_id, opts)
	if event.is_empty():
		return {}
	var choices: Array = []
	var list: Array = event["choices"]
	for i: int in list.size():
		var choice: Dictionary = list[i]
		var check: Dictionary = check_requires(choice, run, max_hp, opts)
		choices.append({
			"index": i, "id": str(choice["id"]), "label_key": str(choice["label_key"]),
			"cost_key": str(choice["cost_key"]), "enabled": bool(check["ok"]),
			"reason_key": str(check["reason_key"]), "reason_args": check["reason_args"],
			"needs_confirm": bool(choice["confirm"]),
		})
	return {"id": str(event["id"]), "title_key": str(event["title_key"]), "body_key": str(event["body_key"]), "choices": choices}


## Whether [param choice] (an events.json choice) can be taken now: {"ok", "reason_key", "reason_args"}.
## Checks `requires` (gold, relic "non_boss", hp_cost_ratio = current HP must stay above the cost,
## cards = minimum deck size) plus the needs its effects imply (upgrade_card: an upgradable card).
static func check_requires(choice: Dictionary, run: RunSession, max_hp: float, opts: Dictionary = {}) -> Dictionary:
	var req: Dictionary = choice.get("requires", {})
	if req.has("gold") and run.gold < int(req["gold"]):
		return _need(KEY_NEED_GOLD, [int(req["gold"])])
	if req.has("relic") and str(req["relic"]) == REQ_NON_BOSS and _swappable_relics(run, opts).is_empty():
		return _need(KEY_NEED_RELIC, [])
	if req.has("hp_cost_ratio"):
		var cost: float = float(req["hp_cost_ratio"]) * max_hp
		if _current_hp(run, max_hp) <= cost:
			return _need(KEY_NEED_HP, [ceili(cost)])
	if req.has("cards") and run.deck.size() < int(req["cards"]):
		return _need(KEY_NEED_CARDS, [int(req["cards"])])
	if _choice_has_effect(choice, "upgrade_card") and upgradable_indices(run, opts).is_empty():
		return _need(KEY_NEED_UPGRADABLE, [])
	return {"ok": true, "reason_key": "", "reason_args": []}


## Resolves [param choice_index] of [param event_id]: re-checks the requirements (refused: {"ok": false,
## "reason_key", "reason_args"}, nothing changes), draws the outcome by its `chance` (seeded, see class
## doc) and applies its effects to [param run]. Result: {"ok": true, "outcome_index": int, "text_key":
## the outcome's result key, "effects_applied": [{"type", ...}] (what actually happened, e.g. {"type":
## "gold", "amount": -30}, {"type": "hp", "delta": -45.0}, {"type": "relic", "id"}, {"type": "curse",
## "id"}, {"type": "run_modifier", "id"}, {"type": "swap_relic", "lost", "gained"}, {"type":
## "remove_card", "tokens"}), "pending_picks": [{"type": "card_offer", "ids"} | {"type": "remove_card"} |
## {"type": "upgrade_card", "levels"}] for [method complete_pick], "pending_fight": {} or {"event_id",
## "kind", "tier_add", "then_effects"} (the flow plays the extra match and calls [method finish_fight])}.
static func resolve(event_id: String, choice_index: int, run: RunSession, max_hp: float, opts: Dictionary = {}) -> Dictionary:
	var event: Dictionary = get_event(event_id, opts)
	var list: Array = event.get("choices", [])
	if event.is_empty() or choice_index < 0 or choice_index >= list.size():
		return {"ok": false, "reason_key": KEY_BAD_CHOICE, "reason_args": []}
	var choice: Dictionary = list[choice_index]
	var check: Dictionary = check_requires(choice, run, max_hp, opts)
	if not bool(check["ok"]):
		return {"ok": false, "reason_key": check["reason_key"], "reason_args": check["reason_args"]}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(opts.get("seed", run.run_seed)), run.floor, run.column, run.node_index, event_id, choice_index])
	var outcomes: Array = choice["outcomes"]
	var pick: float = rng.randf()
	var chosen: int = outcomes.size() - 1
	for i: int in outcomes.size():
		pick -= float((outcomes[i] as Dictionary)["chance"])
		if pick < 0.0:
			chosen = i
			break
	var outcome: Dictionary = outcomes[chosen]
	var result: Dictionary = {"ok": true, "outcome_index": chosen, "text_key": str(outcome["result_key"]),
		"effects_applied": [], "pending_picks": [], "pending_fight": {}}
	for effect: Dictionary in outcome["effects"]:
		_apply(effect, event_id, run, max_hp, rng, opts, result)
	return result


## The extra match of a `fight` effect ended. [param won] false: {"ok": false} (the run is over, the
## caller handles the death). Won: applies the fight's `then_effects` (seeded by the node and event, so a
## reload gives the same prize) and returns {"ok": true, "text_key": "event.<id>.fight_won",
## "effects_applied", "pending_picks", "pending_fight": {}}.
static func finish_fight(run: RunSession, pending_fight: Dictionary, won: bool, max_hp: float, opts: Dictionary = {}) -> Dictionary:
	if not won:
		return {"ok": false, "effects_applied": [], "pending_picks": [], "pending_fight": {}, "text_key": ""}
	var event_id: String = str(pending_fight.get("event_id", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(opts.get("seed", run.run_seed)), run.floor, run.column, run.node_index, event_id, "fight"])
	var result: Dictionary = {"ok": true, "text_key": "event.%s.fight_won" % event_id,
		"effects_applied": [], "pending_picks": [], "pending_fight": {}}
	for effect: Variant in pending_fight.get("then_effects", []) as Array:
		if typeof(effect) == TYPE_DICTIONARY:
			_apply(effect as Dictionary, event_id, run, max_hp, rng, opts, result)
	result["pending_fight"] = {}
	return result


## Deck indices a card upgrade may target: not a curse and below SkillConfig.MAX_LEVEL.
static func upgradable_indices(run: RunSession, opts: Dictionary = {}) -> Array[int]:
	var cards: SkillConfig = _cards(opts)
	var out: Array[int] = []
	for i: int in run.deck.size():
		var entry: Dictionary = run.deck[i]
		if not cards.is_curse(str(entry["id"])) and int(entry["level"]) < SkillConfig.MAX_LEVEL:
			out.append(i)
	return out


## Finishes one of the `pending_picks` of a result. `card_offer`: [param arg] = the chosen card id ("" =
## skip); `remove_card`: arg = deck index (never leaves fewer than `min_deck_size` non-curse cards;
## a curse may always go); `upgrade_card`: arg = deck index of an upgradable card. Result {"ok": bool,
## "reason_key": String}; refused changes nothing.
static func complete_pick(run: RunSession, pick: Dictionary, arg: Variant, opts: Dictionary = {}) -> Dictionary:
	var cards: SkillConfig = _cards(opts)
	match str(pick.get("type", "")):
		"card_offer":
			var id: String = str(arg)
			if id.is_empty():
				return {"ok": true, "reason_key": ""}
			if not (pick.get("ids", []) as Array).has(id):
				return _refused("ui.event.bad_pick")
			run.add_card(id)
			return {"ok": true, "reason_key": ""}
		"remove_card":
			var index: int = int(arg)
			if index < 0 or index >= run.deck.size():
				return _refused("ui.event.bad_pick")
			if not cards.is_curse(str(run.deck[index]["id"])):
				var min_size: int = int(RewardRoller.clean_config(opts.get("reward_config", {}))["min_deck_size"])
				var normal: int = 0
				for e: Dictionary in run.deck:
					if not cards.is_curse(str(e["id"])):
						normal += 1
				if normal <= min_size:
					return _refused("ui.shop.reason.min_deck")
			run.deck.remove_at(index)
			return {"ok": true, "reason_key": ""}
		"upgrade_card":
			var target: int = int(arg)
			if not upgradable_indices(run, opts).has(target):
				return _refused("ui.event.bad_pick")
			var entry: Dictionary = run.deck[target]
			entry["level"] = mini(int(entry["level"]) + maxi(int(pick.get("levels", 1)), 1), SkillConfig.MAX_LEVEL)
			return {"ok": true, "reason_key": ""}
	return _refused("ui.event.bad_pick")


# --- effects -------------------------------------------------------------------------------------

# Applies one effect to the run and records it in [param result] (effects_applied / pending_*).
static func _apply(effect: Dictionary, event_id: String, run: RunSession, max_hp: float,
		rng: RandomNumberGenerator, opts: Dictionary, result: Dictionary) -> void:
	var applied: Array = result["effects_applied"]
	match str(effect.get("type", "")):
		"gold":
			var amount: int = int(effect.get("amount", 0))
			if amount >= 0:
				run.add_gold(amount)
			else:
				amount = -mini(-amount, run.gold)
				run.spend_gold(-amount)
			applied.append({"type": "gold", "amount": amount})
		"hp":
			var before: float = _current_hp(run, max_hp)
			var after: float = clampf(before + float(effect.get("ratio", 0.0)) * max_hp, minf(1.0, max_hp), max_hp)
			run.hp = after
			applied.append({"type": "hp", "delta": after - before})
		"relic":
			applied.append({"type": "relic", "id": _grant_relic(effect, run, rng, opts)})
		"card_offer":
			var ids: Array[String] = _card_offer(effect, run, rng, opts)
			(result["pending_picks"] as Array).append({"type": "card_offer", "ids": ids})
			applied.append({"type": "card_offer", "ids": ids})
		"curse":
			var id: String = str(effect.get("id", ""))
			if not _cards(opts).is_curse(id):
				push_warning("EventLogic: event '%s' gives '%s' which is not a curse card, ignored" % [event_id, id])
				return
			run.add_card(id, 1)  # max level 1: a curse never levels, a second one is a second copy
			applied.append({"type": "curse", "id": id})
		"remove_card":
			var tokens: int = int(effect.get("tokens", 0))
			if tokens > 0:
				run.removal_tokens += tokens
				applied.append({"type": "remove_card", "tokens": tokens})
			else:
				(result["pending_picks"] as Array).append({"type": "remove_card"})
				applied.append({"type": "remove_card", "tokens": 0})
		"upgrade_card":
			var levels: int = maxi(int(effect.get("levels", 1)), 1)
			(result["pending_picks"] as Array).append({"type": "upgrade_card", "levels": levels})
			applied.append({"type": "upgrade_card", "levels": levels})
		"fight":
			result["pending_fight"] = {
				"event_id": event_id, "kind": str(effect.get("kind", "danger")),
				"tier_add": int(effect.get("tier_add", 0)),
				"then_effects": (effect.get("then_effects", []) as Array).duplicate(true),
			}
			applied.append({"type": "fight", "kind": str(effect.get("kind", "danger")), "tier_add": int(effect.get("tier_add", 0))})
		"run_modifier":
			if run.add_run_modifier(effect):
				applied.append({"type": "run_modifier", "id": str(effect.get("id", "")), "matches_left": int(effect.get("matches_left", 0))})
		"swap_relic":
			applied.append(_swap_relic(effect, run, rng, opts))
		_:
			push_warning("EventLogic: unknown effect type '%s' in event '%s', ignored" % [str(effect.get("type", "")), event_id])


# Rolls one relic of [param effect] (source, min_rarity) not owned and adds it; when the floor leaves no
# candidate the floor drops to common. "" when nothing could be given.
static func _grant_relic(effect: Dictionary, run: RunSession, rng: RandomNumberGenerator, opts: Dictionary) -> String:
	var cfg: RelicConfig = opts.get("relic_config", null)
	var source: String = str(effect.get("source", RelicRoller.SOURCE_EVENT))
	var floor_name: String = str(effect.get("min_rarity", ""))
	var ids: Array[String] = RelicRoller.roll(source, run.relic_ids(), rng, cfg, 1, floor_name)
	if ids.is_empty() and not floor_name.is_empty():
		ids = RelicRoller.roll(source, run.relic_ids(), rng, cfg, 1, RelicConfig.RARITIES[0])
	if ids.is_empty():
		return ""
	run.add_relic(ids[0])
	return ids[0]


# The pick-1-of-N card ids of a `card_offer` effect (rarity floor, never a curse).
static func _card_offer(effect: Dictionary, run: RunSession, rng: RandomNumberGenerator, opts: Dictionary) -> Array[String]:
	var cards: SkillConfig = _cards(opts)
	var cfg: Dictionary = RewardRoller.clean_config(opts.get("reward_config", {}))
	cfg["offer_count"] = maxi(int(effect.get("count", cfg["offer_count"])), 1)
	var ids: Array[String] = RewardRoller.roll(cards, cfg, rng.randi(), [] as Array[String], run.deck_levels(),
		run.luck(opts.get("reward_config", {})), str(effect.get("rarity", "common")))
	var out: Array[String] = []
	for id: String in ids:
		if not cards.is_curse(id):
			out.append(id)
	return out


# `swap_relic`: the player's chosen relic (opts.args.relic_id) or a seeded one of the non-boss relics is
# replaced by a relic `rarity_up` tiers higher (capped at the highest rarity a treasure draws, epic) that
# is not owned. Nothing is lost when no such relic exists.
static func _swap_relic(effect: Dictionary, run: RunSession, rng: RandomNumberGenerator, opts: Dictionary) -> Dictionary:
	var cfg: RelicConfig = opts.get("relic_config", null)
	if cfg == null:
		cfg = RelicRegistry.shared_config()
	var swappable: Array[String] = _swappable_relics(run, opts)
	var lost: String = str((opts.get("args", {}) as Dictionary).get("relic_id", ""))
	if not swappable.has(lost):
		lost = swappable[rng.randi_range(0, swappable.size() - 1)] if not swappable.is_empty() else ""
	if lost.is_empty():
		return {"type": "swap_relic", "lost": "", "gained": ""}
	var top: int = RelicConfig.rarity_rank("epic")
	var rank: int = mini(RelicConfig.rarity_rank(str(cfg.get_relic(lost).get("rarity", "common"))) + maxi(int(effect.get("rarity_up", 1)), 1), top)
	var pool: Array[String] = []
	for entry: Dictionary in cfg.relics:
		if RelicConfig.rarity_rank(str(entry["rarity"])) == rank and not run.relics.has(str(entry["id"])):
			pool.append(str(entry["id"]))
	if pool.is_empty():
		return {"type": "swap_relic", "lost": "", "gained": ""}
	var gained: String = pool[rng.randi_range(0, pool.size() - 1)]
	run.relics.erase(lost)
	run.add_relic(gained)
	return {"type": "swap_relic", "lost": lost, "gained": gained}


# --- helpers -------------------------------------------------------------------------------------

# Owned relic ids that are not of the boss rarity.
static func _swappable_relics(run: RunSession, opts: Dictionary) -> Array[String]:
	var cfg: RelicConfig = opts.get("relic_config", null)
	if cfg == null:
		cfg = RelicRegistry.shared_config()
	var out: Array[String] = []
	for id: String in run.relic_ids():
		var data: Dictionary = cfg.get_relic(id)
		if not data.is_empty() and str(data["rarity"]) != BOSS_RARITY:
			out.append(id)
	return out


# Player HP now (a negative run.hp means full).
static func _current_hp(run: RunSession, max_hp: float) -> float:
	return max_hp if run.hp < 0.0 else minf(run.hp, max_hp)


static func _need(key: String, args: Array) -> Dictionary:
	return {"ok": false, "reason_key": key, "reason_args": args}


static func _refused(key: String) -> Dictionary:
	return {"ok": false, "reason_key": key}


# True when any outcome of [param choice] has an effect of [param type].
static func _choice_has_effect(choice: Dictionary, type: String) -> bool:
	for outcome: Dictionary in choice.get("outcomes", []):
		for effect: Dictionary in outcome.get("effects", []):
			if str(effect.get("type", "")) == type:
				return true
	return false


static func _events(opts: Dictionary) -> Array:
	if opts.has("events"):
		return opts["events"] as Array
	return load_events()


static func _cards(opts: Dictionary) -> SkillConfig:
	if opts.has("cards"):
		return opts["cards"] as SkillConfig
	if _shared_cards == null:
		_shared_cards = SkillConfig.load_from_file()
	return _shared_cards


# A validated event ({} when unusable): every choice gets id / keys / requires / confirm / outcomes.
static func _clean_event(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = raw as Dictionary
	var id: String = str(d.get("id", ""))
	if id.is_empty() or typeof(d.get("choices")) != TYPE_ARRAY:
		push_warning("EventLogic: an event without id or choices, dropped")
		return {}
	var choices: Array = []
	for rc: Variant in d["choices"] as Array:
		if typeof(rc) != TYPE_DICTIONARY or typeof((rc as Dictionary).get("outcomes")) != TYPE_ARRAY:
			continue
		var outcomes: Array = []
		for ro: Variant in (rc as Dictionary)["outcomes"] as Array:
			if typeof(ro) != TYPE_DICTIONARY:
				continue
			var effects: Array = []
			for re: Variant in (ro as Dictionary).get("effects", []) as Array:
				if typeof(re) == TYPE_DICTIONARY and EFFECT_TYPES.has(str((re as Dictionary).get("type", ""))):
					effects.append((re as Dictionary).duplicate(true))
				else:
					push_warning("EventLogic: event '%s' has an unknown effect, dropped" % id)
			outcomes.append({"chance": maxf(float((ro as Dictionary).get("chance", 1.0)), 0.0),
				"result_key": str((ro as Dictionary).get("result_key", "")), "effects": effects})
		if outcomes.is_empty():
			continue
		choices.append({
			"id": str((rc as Dictionary).get("id", "choice%d" % choices.size())),
			"label_key": str((rc as Dictionary).get("label_key", "")),
			"cost_key": str((rc as Dictionary).get("cost_key", "")),
			"requires": ((rc as Dictionary).get("requires", {}) as Dictionary).duplicate(true) if typeof((rc as Dictionary).get("requires", {})) == TYPE_DICTIONARY else {},
			"confirm": bool((rc as Dictionary).get("confirm", false)),
			"outcomes": outcomes,
		})
	if choices.is_empty():
		push_warning("EventLogic: event '%s' has no usable choice, dropped" % id)
		return {}
	return {"id": id, "title_key": str(d.get("title_key", "event.%s.title" % id)),
		"body_key": str(d.get("body_key", "event.%s.body" % id)), "choices": choices}
