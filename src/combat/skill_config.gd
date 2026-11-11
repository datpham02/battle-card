class_name SkillConfig
extends RefCounted
## Card definitions, deck defaults and card-menu timing from assets/data/cards.json.
## (Class name kept from the v3 "skills" era; a skill is now a card.)
## Schema: assets/data/schema.md. Implements: Story 008 (skills data; burn/pin: Story 010),
## Story 017 part A (cards, hand_size, default deck).

const DEFAULT_PATH: String = "res://assets/data/cards.json"
## Card id used when nothing else is chosen; always present in [member cards].
const FALLBACK_SKILL: String = "kiem_khi"
## Reward / shop rarities (the pool tiers). `curse` is NOT one of them: curse cards never reach a pool.
const RARITIES: Array[String] = ["common", "rare", "epic"]
## Story 033: rarity id of a curse card (takes a menu slot, shown locked, never upgraded, never rewarded).
const CURSE_RARITY: String = "curse"
## Highest card level (levels are 1..MAX_LEVEL; Story 020).
const MAX_LEVEL: int = 3
## Batch 3 field effects: trap (M09), ward (M10, self-anchored), pillar (M11).
const EFFECTS: Array[String] = ["damage", "push", "burn", "pin", "fragile", "frost", "thorns", "trap", "ward", "pillar"]
## Batch 3: where a card's cells land: "enemy" (the placed cells, every card so far) or "self_anchor" (M10: the shape
## re-anchored on the hero's own half when the card is chosen, WardAnchor.remap).
const PLACEMENTS: Array[String] = ["enemy", "self_anchor"]
## Batch 2 (M15): the status reactions a card may list in `reactions`.
const REACTION_IDS: Array[String] = ["r1", "r2", "r3"]
## How the body casts. Not a delivery type. weapon = the equipped weapon clip.
const CAST_PRESENTATIONS: Array[String] = ["weapon", "hand", "throw", "body", "special"]
## Keys an `upgrade` table may change (additive deltas), with the floor each is clamped to.
const UPGRADE_FLOORS: Dictionary = {
	"damage_per_cell": 0.0, "min_cells": 1.0, "cooldown_sec": 0.0, "burn_damage_per_tick": 0.0,
	"burn_duration_sec": 0.0, "pin_duration_sec": 0.0, "push_cells": 0.0,
	"fragile_stacks": 0.0, "frost_stacks": 0.0,
	"thorn_sec": 0.0, "thorn_damage": 0.0, "thorn_fragile_stacks": 0.0,
	"parry_sec": 0.0, "reflect_mult": 0.0, "parry_pin_sec": 0.0,
	"link_ramp": 0.0, "guard_break_mult": 1.0,
	"trap_sec": 0.0, "ward_sec": 0.0, "pillar_sec": 0.0, "trap_pin_sec": 0.0,
}

## Story 027: the optional per-card zone number keys.
const ZONE_KEYS: Array[String] = ["thorn_sec", "thorn_damage", "thorn_fragile_stacks"]
## Story 027: card effects that form a zone (kept out of the boss's card list). Batch 3: the field zones too.
const ZONE_EFFECTS: Array[String] = ["thorns", "trap", "ward", "pillar"]
## Cast rhythm spec 2026-11-05 (design/quick-specs/nhip-ra-chieu-2026-11-05.md 1.1): how a card resolves. Only `direct`
## (the old behaviour, the default) and `parry` (the Knight's Do Kiem) are implemented; the other modes of the spec are
## later stories and an unknown mode falls back to `direct` (warning).
const CAST_MODE_DIRECT: String = "direct"
const CAST_MODE_PARRY: String = "parry"
## Batch 3 (M09): a trap card (its cells arm instead of hitting; fires on the first enemy entry).
const CAST_MODE_TRAP: String = "trap"
const CAST_MODES: Array[String] = [CAST_MODE_DIRECT, CAST_MODE_PARRY, CAST_MODE_TRAP]
## Parry numbers used when a `parry` card omits its own (cards.json normally carries them).
const PARRY_DEFAULTS: Dictionary = {"parry_sec": 0.8, "reflect_mult": 1.5, "parry_pin_sec": 1.2}

## Simulation speed factor while the card menu is open (0..1). Applied by the view.
var menu_time_scale: float = 0.2
## REAL seconds the player has to choose before the default card is auto-picked.
var menu_choose_sec: float = 3.0
## Skill v2 B1 fallback safety (docs/skill-v2/02-design-decisions.md §9): REAL seconds the menu waits when no card of
## the drawn hand is available for the placed cells before the fallback (default_card) is cast.
var menu_no_option_sec: float = 0.5
## Cards drawn into the menu hand per cut (>= 1).
var hand_size: int = 4
## Basic card chosen on timeout (a rule, not a card in the hand); always in [member cards].
var default_card: String = FALLBACK_SKILL
## Starting deck: card ids (duplicates allowed), all known; never empty.
var default_deck: Array[String] = [FALLBACK_SKILL]
## Focus: simulation speed factor while active (0 = full stop, 0..1).
var focus_time_scale: float = 0.0
## Focus: max REAL seconds one Focus lasts (> 0).
var focus_max_sec: float = 4.0
## Focus: REAL seconds before it can start again (>= 0).
var focus_cooldown_sec: float = 8.0
## Focus: true = the player cannot step while Focus is active.
var focus_locks_movement: bool = true
## Stable display order of the known NON-curse PLAYER card ids (also the boss's default card list and the
## reward / shop pool: Story 033 curse cards and `player_pool: false` cards (the boss-only Wall cards, quick
## spec o-rot-thay-tuong 2026-10-31) are never in it, whatever cards.json lists).
var card_order: Array[String] = [FALLBACK_SKILL]
## id -> {name_key, desc_key, effect, min_cells, cooldown_sec, damage_per_cell, push_cells,
## burn_*, pin_duration_sec, fragile_stacks, frost_stacks, pierce_defense, execute, execute_ratio,
## bonus_vs_fragile_mult, rarity, draw_damage, upgrade, implemented, player_pool, delivery, cast_mode, crit} (level 1
## values; see
## [method resolved]). `delivery` = SkillDelivery.parse of the card's `delivery` object (ADR-0001 D7 / A1).
## Story 033: rarity `curse` cards (ganh_nang, oan_hon) carry `draw_damage` (HP the player loses each
## time the card is drawn into the card menu; 0 = none).
## Story 027 zone cards (effect thorns) may also carry the optional per-card overrides
## thorn_sec, thorn_damage, thorn_fragile_stacks; a key the card omits is absent here and combat.json
## `zones` supplies the number.
var cards: Dictionary = {}
## Skill v2 B1.5: every invalid resolve configuration found while loading (CastResolver.validate messages). Such a card
## is put back on its legacy `instant` path, and the message is also pushed as an error; never silent.
var validation_errors: Array[String] = []


func _init() -> void:
	cards[FALLBACK_SKILL] = {
		"delivery": SkillDelivery.parse({"type": SkillDelivery.CASTER_TO_TARGET, "origin": "caster", "travel": "hero_pack", "impact": "burst"}),
		"effect": "damage", "burn_duration_sec": 0.0, "burn_tick_sec": 0.5,
		"burn_damage_per_tick": 0.0, "pin_duration_sec": 0.0,
		"name_key": "card.kiem_khi.name", "desc_key": "card.kiem_khi.desc", "min_cells": 1, "cooldown_sec": 0.0,
		"damage_per_cell": CutConfig.load_from_file().base_damage_per_cell, "push_cells": 0,
			"rarity": "common", "upgrade": {"damage_per_cell": 1.0}, "implemented": true,
	}


## Loads from a JSON file. Never null: a missing or bad file gives defaults (warning).
static func load_from_file(path: String = DEFAULT_PATH) -> SkillConfig:
	if not FileAccess.file_exists(path):
		push_warning("SkillConfig: file not found: %s, using defaults" % path)
		return SkillConfig.new()
	return from_json_text(FileAccess.get_file_as_string(path))


## Builds a config from JSON text. Never null (defaults + warning if invalid).
static func from_json_text(text: String) -> SkillConfig:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SkillConfig: JSON root must be an object, using defaults")
		return SkillConfig.new()
	return from_dictionary(parsed as Dictionary)


## Builds a config from a dictionary; missing keys keep defaults, values are clamped.
static func from_dictionary(data: Dictionary) -> SkillConfig:
	var config := SkillConfig.new()
	config.menu_time_scale = clampf(float(data.get("menu_time_scale", config.menu_time_scale)), 0.0, 1.0)
	config.menu_choose_sec = maxf(float(data.get("menu_choose_sec", config.menu_choose_sec)), 0.0)
	config.menu_no_option_sec = maxf(float(data.get("menu_no_option_sec", config.menu_no_option_sec)), 0.0)
	config.hand_size = maxi(int(data.get("hand_size", config.hand_size)), 1)
	config._read_focus(data.get("focus"))
	var raw_cards: Variant = data.get("cards")
	if typeof(raw_cards) == TYPE_DICTIONARY and not (raw_cards as Dictionary).is_empty():
		config.cards.clear()
		for id: Variant in (raw_cards as Dictionary).keys():
			var raw: Variant = (raw_cards as Dictionary)[id]
			if typeof(raw) != TYPE_DICTIONARY:
				push_warning("SkillConfig: card %s is not an object, ignored" % str(id))
				continue
			config.cards[str(id)] = _normalize(str(id), raw as Dictionary)
			for e: Variant in config.cards[str(id)].get("resolve_errors", []) as Array:
				config.validation_errors.append(str(e))
	else:
		push_warning("SkillConfig: no cards in data, using the built-in kiem_khi only")
	if config.cards.is_empty():
		config.cards = SkillConfig.new().cards
	config.card_order = []
	var raw_order: Variant = data.get("card_order")
	if typeof(raw_order) == TYPE_ARRAY:
		for id: Variant in raw_order as Array:
			if config.is_player_card(str(id)) and not config.card_order.has(str(id)):
				config.card_order.append(str(id))
	for id: Variant in config.cards.keys():
		if not config.card_order.has(str(id)) and config.is_player_card(str(id)):
			config.card_order.append(str(id))
	var wanted: String = str(data.get("default_card", FALLBACK_SKILL))
	if config.is_player_card(wanted):
		config.default_card = wanted
	else:
		push_warning("SkillConfig: default_card %s unknown, using the first card" % wanted)
		config.default_card = config.card_order[0]
	config.default_deck = []
	var raw_deck: Variant = data.get("default_deck")
	if typeof(raw_deck) == TYPE_ARRAY:
		for id: Variant in raw_deck as Array:
			if config.is_player_card(str(id)):
				config.default_deck.append(str(id))
			elif config.is_curse(str(id)):
				push_warning("SkillConfig: default_deck card %s is a curse, dropped" % str(id))
			elif config.cards.has(str(id)):
				push_warning("SkillConfig: default_deck card %s is not a player card (player_pool false), dropped" % str(id))
			else:
				push_warning("SkillConfig: default_deck card %s unknown, dropped" % str(id))
	if config.default_deck.is_empty():
		config.default_deck = [config.default_card]
	return config


## True if [param id] is a defined card.
func has_skill(id: String) -> bool:
	return cards.has(id)


## The definition of [param id] (see [member cards]); empty dictionary if unknown.
func get_skill(id: String) -> Dictionary:
	if cards.has(id):
		return cards[id] as Dictionary
	return {}


## True when the player may hold [param id]: a known, non-curse card whose `player_pool` is not false.
## `player_pool: false` keeps a card out of every player source (starter deck, reward, shop, event, achievement,
## Kiep); quick spec 2026-10-31. Its only users, the Wall cards (ket_gioi, long_an, luoi_san), were deleted on
## 2026-11-01 with the seal effect; the flag is kept (harmless, no card sets it today) for future boss-only cards.
func is_player_card(id: String) -> bool:
	return cards.has(id) and not is_curse(id) and bool((cards[id] as Dictionary).get("player_pool", true))


## Story 027: true when [param id] is a zone card (effect in [constant ZONE_EFFECTS]). The boss never
## plays these: it gets zones only through its traits (seal_caster, thorn_field).
func is_zone_card(id: String) -> bool:
	return ZONE_EFFECTS.has(str(get_skill(id).get("effect", "")))


## Story 027: [member card_order] without the zone cards: the boss's default card list. Cast rhythm spec 2026-11-05:
## also without the cards whose cast_mode is not `direct` (a parry answers the ENEMY's telegraph; the boss never has one
## to answer), see [method is_boss_playable].
func boss_card_order() -> Array[String]:
	var out: Array[String] = []
	for id: String in card_order:
		if is_boss_playable(id):
			out.append(id)
	return out


## True when the block-brain boss may hold card [param id]: a known card that is not a zone card, casts `direct` and is
## not a hero's own card (Skill v2: tram_dia is the Knight's; do_kiem was already out as a parry card).
func is_boss_playable(id: String) -> bool:
	return cards.has(id) and not is_zone_card(id) and cast_mode(id) == CAST_MODE_DIRECT and hero_of(id).is_empty()


## Cast rhythm spec 2026-11-05: the cast_mode of [param id] ("direct" for an unknown card).
func cast_mode(id: String) -> String:
	return str(get_skill(id).get("cast_mode", CAST_MODE_DIRECT))


## True when [param id] is a `parry` card (available only during an enemy telegraph, opens a guard; SkillAvailability,
## ParryGuard).
func is_parry_card(id: String) -> bool:
	return cast_mode(id) == CAST_MODE_PARRY


## Story 033: true when [param id] is a curse card (rarity `curse`). Curses take a card-menu slot and
## are shown locked, never upgrade, never appear in reward / shop pools or the boss deck, and do not
## count toward the run's min_deck_size. Unknown id: false.
## Cast rhythm spec 2026-11-05 (user: "Riêng Kiếm sĩ"): the hero id a hero card belongs to ("" = shared pool).
## A hero card is a player card (it may sit in that hero's starter deck) but never enters a reward / shop / event
## pool ([method is_pool_card]).
func hero_of(id: String) -> String:
	return str(get_skill(id).get("hero", ""))


## True when [param id] may be drawn from the shared pools (RewardRoller): a player card that is not a hero card.
func is_pool_card(id: String) -> bool:
	return is_player_card(id) and hero_of(id).is_empty()


func is_curse(id: String) -> bool:
	return str(get_skill(id).get("rarity", "")) == CURSE_RARITY


## Story 033: HP the player loses each time curse [param id] is drawn into the card menu (0 for any
## other card).
func draw_damage(id: String) -> float:
	return maxf(float(get_skill(id).get("draw_damage", 0.0)), 0.0)


## Story 033: ids of the curse cards in cards.json order.
func curse_ids() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in cards.keys():
		if is_curse(str(id)):
			out.append(str(id))
	return out


## Rarity of [param id] ("common" / "rare" / "epic" / "curse"); "common" if unknown.
func get_rarity(id: String) -> String:
	return str(get_skill(id).get("rarity", "common"))


## The card [param id] at [param level] (clamped to 1..MAX_LEVEL) with its `upgrade` deltas applied
## once per level above 1 (min_cells >= 1, cooldown >= 0, others >= 0). Same keys as
## [method get_skill] plus "level". Unknown id: {}. The single place upgrades are summed.
func resolved(id: String, level: int = 1) -> Dictionary:
	if not cards.has(id):
		return {}
	var card: Dictionary = (cards[id] as Dictionary).duplicate(true)
	# Story 033: a curse never levels.
	var lv: int = 1 if is_curse(id) else clampi(level, 1, MAX_LEVEL)
	var upgrade: Dictionary = card.get("upgrade", {}) as Dictionary
	for key: Variant in upgrade.keys():
		var floor_value: float = float(UPGRADE_FLOORS.get(str(key), 0.0))
		var value: float = maxf(float(card.get(key, 0.0)) + float(upgrade[key]) * float(lv - 1), floor_value)
		card[key] = int(value) if typeof(card.get(key, 0.0)) == TYPE_INT else value
	card["level"] = lv
	return card


# Parses the optional "focus" object; bad or missing values keep the defaults (warning if bad).
func _read_focus(raw: Variant) -> void:
	if raw == null:
		return
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("SkillConfig: focus must be an object, using defaults")
		return
	var focus: Dictionary = raw as Dictionary
	focus_time_scale = _number(focus, "focus_time_scale", focus_time_scale, 0.0, 1.0, true)
	focus_max_sec = _number(focus, "focus_max_sec", focus_max_sec, 0.0, INF, false)
	focus_cooldown_sec = _number(focus, "focus_cooldown_sec", focus_cooldown_sec, 0.0, INF, true)
	if focus.has("focus_locks_movement"):
		if typeof(focus["focus_locks_movement"]) == TYPE_BOOL:
			focus_locks_movement = bool(focus["focus_locks_movement"])
		else:
			push_warning("SkillConfig: focus_locks_movement must be true/false, using default")


# A numeric focus value: non-number => default (warning); clamped to [low, high]; when
# [param allow_low] is false the value must be > low, otherwise the default is used (warning).
static func _number(d: Dictionary, key: String, fallback: float, low: float, high: float, allow_low: bool) -> float:
	if not d.has(key):
		return fallback
	var v: Variant = d[key]
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		push_warning("SkillConfig: %s must be a number, using %s" % [key, fallback])
		return fallback
	var value: float = float(v)
	if is_nan(value) or value < low or (not allow_low and value <= low):
		push_warning("SkillConfig: %s is out of range, using %s" % [key, fallback])
		return fallback
	return clampf(value, low, high)


static func _normalize(id: String, raw: Dictionary) -> Dictionary:
	var tick: float = float(raw.get("burn_tick_sec", 0.5))
	if tick <= 0.0:
		push_warning("SkillConfig: card %s burn_tick_sec must be > 0, using 0.5" % id)
		tick = 0.5
	var rarity: String = str(raw.get("rarity", "common"))
	if not RARITIES.has(rarity) and rarity != CURSE_RARITY:
		push_warning("SkillConfig: card %s rarity '%s' unknown, using common" % [id, rarity])
		rarity = "common"
	var effect: String = str(raw.get("effect", "damage"))
	if not EFFECTS.has(effect):
		push_warning("SkillConfig: card %s effect '%s' unknown" % [id, effect])
	# Skill v2 B1.5: the resolve fields are validated (unknown modes / bad numbers are reported, the card stays instant).
	var resolve_check: Dictionary = CastResolver.validate(id, raw, effect, _cast_mode(id, raw))
	for e: Variant in resolve_check["errors"] as Array:
		push_error("SkillConfig: " + str(e))
	var upgrade: Dictionary = {}
	var raw_up: Variant = raw.get("upgrade")
	if rarity == CURSE_RARITY:
		pass  # Story 033: a curse has no upgrade table (never upgradable)
	elif typeof(raw_up) == TYPE_DICTIONARY:
		for key: Variant in (raw_up as Dictionary).keys():
			if UPGRADE_FLOORS.has(str(key)) and (typeof((raw_up as Dictionary)[key]) == TYPE_FLOAT or typeof((raw_up as Dictionary)[key]) == TYPE_INT):
				upgrade[str(key)] = float((raw_up as Dictionary)[key])
			else:
				push_warning("SkillConfig: card %s upgrade key '%s' invalid, ignored" % [id, str(key)])
	else:
		push_warning("SkillConfig: card %s has no upgrade table" % id)
	# Fallback for a card without damage_per_cell: the global cuts.json base_damage_per_cell; a burn card without it
	# has no hit damage (2026-11-05: a burn card's damage_per_cell is now dealt on a hit, CutEffects burn_hits_too).
	var dpc: float = 0.0
	if raw.has("damage_per_cell"):
		dpc = maxf(float(raw["damage_per_cell"]), 0.0)
	elif effect != "burn":
		dpc = CutConfig.load_from_file().base_damage_per_cell
	var out: Dictionary = {
		"effect": effect,
		"burn_duration_sec": maxf(float(raw.get("burn_duration_sec", 0.0)), 0.0),
		"burn_tick_sec": tick,
		"burn_damage_per_tick": maxf(float(raw.get("burn_damage_per_tick", 0.0)), 0.0),
		"pin_duration_sec": maxf(float(raw.get("pin_duration_sec", 0.0)), 0.0),
		"name_key": str(raw.get("name_key", "card.%s.name" % id)),
		"desc_key": str(raw.get("desc_key", "card.%s.desc" % id)),
		"min_cells": maxi(int(raw.get("min_cells", 1)), 1),
		"cooldown_sec": maxf(float(raw.get("cooldown_sec", 0.0)), 0.0),
		"damage_per_cell": dpc,
		"push_cells": maxi(int(raw.get("push_cells", 0)), 0),
		# Skill v2 Vũng Lầy: seconds the mask stays mire after the swing (0 = none). TileHazards.add_mire.
		"mire_sec": maxf(float(raw.get("mire_sec", 0.0)), 0.0),
		# Visual only. Delivery (floor_run, sky, chain) is separate. Unknown values fall back to weapon.
		"cast_presentation": _cast_presentation(id, raw),
		# Story 023: keyword stacks the card applies to a target it hits, defense piercing, execute
		# (execute_ratio > 0 = own threshold; execute true = combat.json default) and the Ran bonus.
		"fragile_stacks": maxi(int(raw.get("fragile_stacks", 0)), 0),
		"frost_stacks": maxi(int(raw.get("frost_stacks", 0)), 0),
		"pierce_defense": bool(raw.get("pierce_defense", false)),
		# Story 037: HP the CASTER heals when the cut lands (hit or miss); 0 = none.
		"heal_self": maxf(float(raw.get("heal_self", 0.0)), 0.0),
		"execute": bool(raw.get("execute", false)),
		"execute_ratio": clampf(float(raw.get("execute_ratio", 0.0)), 0.0, 1.0),
		"bonus_vs_fragile_mult": maxf(float(raw.get("bonus_vs_fragile_mult", 1.0)), 1.0),
		"rarity": rarity,
		"draw_damage": maxf(float(raw.get("draw_damage", 0.0)), 0.0) if rarity == CURSE_RARITY else 0.0,
		"upgrade": upgrade,
		"implemented": bool(raw.get("implemented", false)),
		"player_pool": bool(raw.get("player_pool", true)),
		"hero": str(raw.get("hero", "")),
		# Skill v2 Q3: a hero card offered in its own hero's rewards (RewardRoller hero_id); false = never drawn.
		"hero_reward": bool(raw.get("hero_reward", false)),
		# ADR-0001 D7 / A1: the card's delivery (origin, travel, impact, cell mask = the block shape); presentation
		# only - CutEffects never reads it (SkillDelivery).
		"delivery": SkillDelivery.parse(raw.get("delivery"), "card %s" % id),
		# Cast rhythm spec 2026-11-05 1.1 / 1.2: the cast mode and the optional crit ({} = none, CritRules.normalize).
		"cast_mode": _cast_mode(id, raw),
		"crit": CritRules.normalize(raw.get("crit"), "card %s" % id),
		# Skill v2 B1 schema (docs/skill-v2/02-mechanics-catalog.md): parsed with defaults that keep today's behaviour
		# (resolve: instant = one wave at the swing end). B1.5: resolve / hits / max_hits / hit_interval_sec / wave_mults
		# come from CastResolver.validate; resolve_errors lists what was rejected ([] for a valid card).
		"resolve": resolve_check["resolve"],
		"placement": _placement(id, raw),
		"hits": resolve_check["hits"],
		"max_hits": resolve_check["max_hits"],
		"hit_interval_sec": resolve_check["hit_interval_sec"],
		"wave_mults": resolve_check["wave_mults"],
		"resolve_errors": resolve_check["errors"],
		"shape_clause": resolve_check["shape_clause"],
		"burst_first": resolve_check["burst_first"],
		"burst_pin_sec": resolve_check["burst_pin_sec"],
		# Skill v2 (Ngàn Kiếm): sky drop timing / order, fixed per-hit damage, Awakening extra max hits.
		"sky_hover_sec": resolve_check["sky_hover_sec"],
		"sky_stagger_sec": resolve_check["sky_stagger_sec"],
		"drop_order": resolve_check["drop_order"],
		"fixed_hit": resolve_check["fixed_hit"],
		"awakening_extra_hits": resolve_check["awakening_extra_hits"],
		# Skill v2 Cast Commitment (design/quick-specs/cast-commitment-ngan-kiem-2026-11-08.md; Ngàn Kiếm only):
		# commit_lock_sec >= 0 makes the swing a CHANNEL (hero rooted, cancellable), the swing end the COMMIT (then
		# locked commit_lock_sec more), then RESOLUTION. channel_extend_sec lengthens the channel (added after every
		# swing-time modifier). cancel_policy "spent": a cancelled channel keeps its spent pieces and its cooldown.
		"commit_lock_sec": maxf(float(raw.get("commit_lock_sec", -1.0)), -1.0),
		"channel_extend_sec": maxf(float(raw.get("channel_extend_sec", 0.0)), 0.0),
		"cancel_policy": str(raw.get("cancel_policy", "spent")),
		# Skill v2 delayed (M07; Hỏa Lôi, docs/skill-v2/09-hoa-loi-design.md): fuse timing / multiplier, the cap of armed
		# fields of this card at once (0 = none) and the payload its events carry (CastResolver.validate).
		"fuse_sec": resolve_check["fuse_sec"],
		"fuse_mult": resolve_check["fuse_mult"],
		"max_active": resolve_check["max_active"],
		"event_payload": resolve_check["event_payload"],
		# Skill v2: how many cells a scheduled hit's damage counts (CastResolver.damage_cells; "all" by default).
		"damage_cells_rule": resolve_check["damage_cells_rule"],
		# Skill v2 cast profile: cast_time_sec > 0 fixes the swing time (replaces the per-cell formula and the passive's
		# duration modifier; relic cast-time hooks still apply); cast_root "lock" roots the hero for the swing only (no
		# Hủy, no commit lock). "none" = today's swing (the hero may step). Channel cards use commit_lock_sec instead.
		"cast_time_sec": maxf(float(raw.get("cast_time_sec", -1.0)), -1.0),
		"cast_root": str(raw.get("cast_root", "none")) if ["none", "lock"].has(str(raw.get("cast_root", "none"))) else "none",
		"tags": (raw.get("tags", []) as Array).duplicate() if raw.get("tags", []) is Array else [],
		# Skill v2 batch 1 (docs/skill-v2/18-batch1-report.md). Chuỗi Sét M06 ramp: +link_ramp of the damage per chain
		# link after the first, capped at link_ramp_cap (CastResolver.validate; 0 = the old chain rule).
		"link_ramp": resolve_check["link_ramp"],
		"link_ramp_cap": resolve_check["link_ramp_cap"],
		# Đập Vỡ: a hit strips the target's Guard first and deals x guard_break_mult when Guard was present (CutEffects).
		"guard_break": bool(raw.get("guard_break", false)),
		"guard_break_mult": maxf(float(raw.get("guard_break_mult", 1.0)), 1.0),
		# Thương Xuyên: the card is pickable only when a placed piece carries the tag ({} = no requirement;
		# SkillAvailability reason need_shape) and gets +per_cell damage per cell beyond from_cells, capped (CutEffects).
		"requires_shape": _requires_shape(id, raw),
		"dpc_bonus": _dpc_bonus(id, raw),
		# Skill v2 batch 2 (docs/skill-v2/19-batch2-report.md). reactions: the M15 reactions this card may trigger
		# (r1 Hơi Nước, r2 Vỡ Băng, r3 Va Đập; numbers in combat.json `reactions`); [] = none (CutEffects).
		"reactions": _reactions(id, raw),
		# Lốc Cuốn: cells a unit inside or next to the mask is pulled toward the mask's centre before the hit (0 = none).
		"pull_cells": clampi(int(raw.get("pull_cells", 0)), 0, CastResolver.MAX_FORCE_CELLS),
		# Băng Vỡ: when the card's Rạn lands - "after" the hit (every card so far) or "before" it (so R2 can fire).
		"fragile_timing": "before" if str(raw.get("fragile_timing", "after")) == "before" else "after",
		# Thiên Thạch (M05 shockwave) and Hồi Âm (M14 echo): CastResolver.validate.
		"sky_mode": resolve_check["sky_mode"],
		"ring_step_sec": resolve_check["ring_step_sec"],
		"hub_mult": resolve_check["hub_mult"],
		"echo": resolve_check["echo"],
		# Skill v2 batch 3 (docs/skill-v2/20-batch3-report.md). Trap (M09): seconds armed, the Pin on firing, the push on
		# firing (Bẫy Lò Xo). Gai Nổ: detonate the player's thorn / trap cells in the mask, Rạn per detonated cell.
		"trap_sec": maxf(float(raw.get("trap_sec", 8.0)), 0.0),
		"trap_pin_sec": maxf(float(raw.get("trap_pin_sec", 0.0)), 0.0),
		"trap_push_cells": clampi(int(raw.get("trap_push_cells", 0)), 0, CastResolver.MAX_FORCE_CELLS),
		"detonate_zones": bool(raw.get("detonate_zones", false)),
		"fragile_per_cell": maxi(int(raw.get("fragile_per_cell", 0)), 0),
		# Ward (M10): seconds the own-half cells stay a ward and its numbers (CutEffects / StatusEffects.ward_absorb).
		"ward_sec": maxf(float(raw.get("ward_sec", 4.0)), 0.0),
		"ward": _ward(id, raw),
		# Pillar (M11): seconds the empty mask cells block steps.
		"pillar_sec": maxf(float(raw.get("pillar_sec", 3.0)), 0.0),
		"id": id,
		# Skill v2 batch 4 (docs/skill-v2/21-batch4-report.md). Dấu Tử: the mark a hit leaves ({} = none; sec, echo_mult,
		# execute_ratio). Thiên Quang: events that may apply the card's keywords after max_hits is spent (0 = none).
		# Phi Tiêu: a chain link whose cell is empty re-targets the mask cell the unit moved to; link_step_sec = seconds
		# between links (CastResolver.validate; 0 = the delivery timing). Móc Kéo: cells the hit pulls the target along
		# its row toward the divider (CutEffects.pull_toward).
		"mark": _mark(id, raw),
		"keyword_hits_max": maxi(int(raw.get("keyword_hits_max", 0)), 0),
		"bounce": bool(raw.get("bounce", false)),
		"link_step_sec": resolve_check["link_step_sec"],
		"pull_row_cells": clampi(int(raw.get("pull_row_cells", 0)), 0, CastResolver.MAX_FORCE_CELLS),
	}
	if str(out["cast_mode"]) == CAST_MODE_PARRY:
		for key: String in PARRY_DEFAULTS.keys():
			out[key] = maxf(float(raw.get(key, PARRY_DEFAULTS[key])), 0.0)
	# Story 027: optional per-card zone numbers (absent = the combat.json `zones` block decides).
	for key: String in ZONE_KEYS:
		if raw.has(key):
			out[key] = maxi(int(raw[key]), 0) if key == "thorn_fragile_stacks" else maxf(float(raw[key]), 0.0)
	return out


# The card's cast_mode, `direct` when absent; an unknown mode is `direct` (warning).
static func _cast_mode(id: String, raw: Dictionary) -> String:
	var mode: String = str(raw.get("cast_mode", CAST_MODE_DIRECT))
	if not CAST_MODES.has(mode):
		push_warning("SkillConfig: card %s cast_mode '%s' unknown or not implemented, using direct" % [id, mode])
		return CAST_MODE_DIRECT
	return mode


# Batch 1: the card's requires_shape ({} = none): {tag: String, scope: any_piece | all_pieces}. A bad object is dropped
# with a warning (the card then needs no shape).
static func _requires_shape(id: String, raw: Dictionary) -> Dictionary:
	if not raw.has("requires_shape"):
		return {}
	var r: Variant = raw["requires_shape"]
	if not r is Dictionary or str((r as Dictionary).get("tag", "")).is_empty():
		push_warning("SkillConfig: card %s requires_shape needs {tag}, ignored" % id)
		return {}
	var scope: String = str((r as Dictionary).get("scope", "any_piece"))
	if not ["any_piece", "all_pieces"].has(scope):
		push_warning("SkillConfig: card %s requires_shape scope '%s' unknown, using any_piece" % [id, scope])
		scope = "any_piece"
	return {"tag": str((r as Dictionary)["tag"]), "scope": scope}


# Batch 4: the card's death mark ({} = none): {sec > 0, echo_mult >= 0 (default 0.6), execute_ratio 0..1 (default 0.3)}.
static func _mark(id: String, raw: Dictionary) -> Dictionary:
	if not raw.has("mark"):
		return {}
	var r: Variant = raw["mark"]
	if not r is Dictionary or float((r as Dictionary).get("sec", 0.0)) <= 0.0:
		push_warning("SkillConfig: card %s mark needs {sec > 0}, ignored" % id)
		return {}
	var d: Dictionary = r as Dictionary
	return {"sec": float(d["sec"]), "echo_mult": maxf(float(d.get("echo_mult", 0.6)), 0.0),
		"execute_ratio": clampf(float(d.get("execute_ratio", 0.3)), 0.0, 1.0)}


# Batch 3: the card's placement ("enemy" when absent; an unknown value falls back to enemy with a warning).
static func _placement(id: String, raw: Dictionary) -> String:
	var p: String = str(raw.get("placement", "enemy"))
	if not PLACEMENTS.has(p):
		push_warning("SkillConfig: card %s placement '%s' unknown, using enemy" % [id, p])
		return "enemy"
	return p


# Batch 3: the card's ward numbers ({} = none): damage_mult 0..1 (default 1), heal_per_sec >= 0, guard >= 0,
# push_immune bool, attacker_frost >= 0. A non-object is dropped with a warning.
static func _ward(id: String, raw: Dictionary) -> Dictionary:
	if not raw.has("ward"):
		return {}
	var r: Variant = raw["ward"]
	if not r is Dictionary:
		push_warning("SkillConfig: card %s ward must be an object, ignored" % id)
		return {}
	var d: Dictionary = r as Dictionary
	return {"damage_mult": clampf(float(d.get("damage_mult", 1.0)), 0.0, 1.0), "heal_per_sec": maxf(float(d.get("heal_per_sec", 0.0)), 0.0),
		"guard": maxf(float(d.get("guard", 0.0)), 0.0), "push_immune": bool(d.get("push_immune", false)),
		"attacker_frost": maxi(int(d.get("attacker_frost", 0)), 0)}


## Batch 3 (M10): true when [param id] re-anchors its cells on the hero when chosen (placement self_anchor).
func is_self_anchored(id: String) -> bool:
	return str(get_skill(id).get("placement", "enemy")) == "self_anchor"


# Batch 2: the card's reactions list ([] = none): only REACTION_IDS, unknown ids dropped with a warning.
static func _reactions(id: String, raw: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var r: Variant = raw.get("reactions", [])
	if not r is Array:
		push_warning("SkillConfig: card %s reactions must be a list, ignored" % id)
		return out
	for e: Variant in r as Array:
		var s: String = str(e)
		if not REACTION_IDS.has(s):
			push_warning("SkillConfig: card %s reaction '%s' unknown (known: %s), ignored" % [id, s, ", ".join(REACTION_IDS)])
		elif not out.has(s):
			out.append(s)
	return out


# Batch 1: the card's dpc_bonus ({} = none): {per_cell >= 0, from_cells >= 0, cap >= 0}; damage_per_cell grows by
# min((cells - from_cells) x per_cell, cap) for the cast. A bad object is dropped with a warning.
static func _dpc_bonus(id: String, raw: Dictionary) -> Dictionary:
	if not raw.has("dpc_bonus"):
		return {}
	var r: Variant = raw["dpc_bonus"]
	if not r is Dictionary:
		push_warning("SkillConfig: card %s dpc_bonus must be an object, ignored" % id)
		return {}
	var d: Dictionary = r as Dictionary
	return {"per_cell": maxf(float(d.get("per_cell", 0.0)), 0.0), "from_cells": maxi(int(d.get("from_cells", 0)), 0),
		"cap": maxf(float(d.get("cap", 0.0)), 0.0)}


static func _cast_presentation(id: String, raw: Dictionary) -> String:
	var presentation: String = str(raw.get("cast_presentation", "weapon"))
	if not CAST_PRESENTATIONS.has(presentation):
		push_warning("SkillConfig: card %s cast_presentation '%s' unknown, using weapon" % [id, presentation])
		return "weapon"
	return presentation
