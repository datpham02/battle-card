class_name RelicRegistry
extends RefCounted
## The one place that maps a relic script id (relics.json `script`) to its script and relic id to its
## data (Story 032). Adding a config-type relic = JSON only (`script: "config_mod"`); a conditional
## relic = one BaseRelic subclass + one line in [constant SCRIPTS].
##
## Config override order (applied by the combat wave to the real config before FieldDrops, the piece
## bag, FormationMap and StatusEffects are built): value = (base_or_set + sum of adds) x product of
## muls, see [method apply_override].
## Damage order: see [method fold_damage] and assets/data/schema.md `relics.json`.
## Implements: Story 032.

## Canonical config keys a relic may override.
const CONFIG_KEYS: Array[String] = [
	"thorn_sec", "thorn_ran", "piece_freshness_sec", "start_pieces", "focus_sec", "formation_fade",
	"signature_cooldown", "hold_slots", "piece_spawn_interval", "burn_max_stacks", "han_stacks",
	"han_damage",
]

## script id -> GDScript (every script must extend BaseRelic).
const SCRIPTS: Dictionary = {
	"config_mod": preload("res://src/relics/config_mod_relic.gd"),
	"an_don": preload("res://src/relics/an_don.gd"),
	"chi_khau": preload("res://src/relics/chi_khau.gd"),
	"khoi_the": preload("res://src/relics/khoi_the.gd"),
	"phan_don": preload("res://src/relics/phan_don.gd"),
	"huyet_an": preload("res://src/relics/huyet_an.gd"),
	"an_chu": preload("res://src/relics/an_chu.gd"),
	"tam_hop": preload("res://src/relics/tam_hop.gd"),
}

static var _shared_config: RelicConfig = null


## A fresh instance of the script [param script_id], or null (with a warning) for an unknown id.
static func create(script_id: String) -> BaseRelic:
	if not SCRIPTS.has(script_id):
		push_warning("RelicRegistry: unknown relic script '%s' (known: %s), none used" % [script_id, ", ".join(known_ids())])
		return null
	var instance: Object = (SCRIPTS[script_id] as GDScript).new()
	if not (instance is BaseRelic):
		push_warning("RelicRegistry: script '%s' does not extend BaseRelic" % script_id)
		return null
	return instance as BaseRelic


## True when [param script_id] is a registered script id.
static func has_id(script_id: String) -> bool:
	return SCRIPTS.has(script_id)


## Every registered script id, sorted.
static func known_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: Variant in SCRIPTS.keys():
		ids.append(str(key))
	ids.sort()
	return ids


## The shared relics.json config (loaded once; callers that take a `config` param accept a test one).
static func shared_config() -> RelicConfig:
	if _shared_config == null:
		_shared_config = RelicConfig.load_from_file()
	return _shared_config


## Forgets the shared config so the next call reloads the file.
static func reset_shared_config() -> void:
	_shared_config = null


## `{id, rarity, tags, name_key, desc_key, params}` of the relic [param relic_id] (plus `script`),
## or {} when unknown. A copy.
static func info(relic_id: String, config: RelicConfig = null) -> Dictionary:
	var cfg: RelicConfig = config if config != null else shared_config()
	return cfg.get_relic(relic_id).duplicate(true)


## Every relic id of relics.json in file order.
static func all_ids(config: RelicConfig = null) -> Array[String]:
	var cfg: RelicConfig = config if config != null else shared_config()
	return cfg.ids()


## A relic instance for [param relic_id] with its id and params set (`setup({}, params)` already ran,
## so [method BaseRelic.config_overrides] works before the match exists; CombatView calls `setup`
## again with the real ctx). Null (with a warning) for an unknown relic id or script.
static func instantiate(relic_id: String, config: RelicConfig = null) -> BaseRelic:
	var data: Dictionary = info(relic_id, config)
	if data.is_empty():
		push_warning("RelicRegistry: unknown relic id '%s', none used" % relic_id)
		return null
	var relic: BaseRelic = create(str(data["script"]))
	if relic == null:
		return null
	relic.set_relic_id(relic_id)
	relic.setup({}, data["params"] as Dictionary)
	return relic


## Folds the config overrides of every relic: per key `{add: sum of adds, mul: product of muls}` plus
## `set` (the last relic's absolute value) when any relic sets one. Relics are BaseRelic instances.
static func merge_overrides(relics: Array) -> Dictionary:
	var merged: Dictionary = {}
	for relic: Variant in relics:
		if not (relic is BaseRelic):
			continue
		var overrides: Dictionary = (relic as BaseRelic).config_overrides()
		for key: Variant in overrides.keys():
			var entry: Variant = overrides[key]
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var slot: Dictionary = merged.get(key, {"add": 0.0, "mul": 1.0})
			slot["add"] = float(slot["add"]) + float((entry as Dictionary).get("add", 0.0))
			slot["mul"] = float(slot["mul"]) * float((entry as Dictionary).get("mul", 1.0))
			if (entry as Dictionary).has("set"):
				slot["set"] = float((entry as Dictionary)["set"])
			merged[key] = slot
	return merged


## The final value of config [param key]: (base, or the merged `set`, + merged `add`) x merged `mul`.
## A key without an override returns [param base_value] unchanged.
static func apply_override(base_value: float, merged: Dictionary, key: String) -> float:
	var slot: Variant = merged.get(key)
	if typeof(slot) != TYPE_DICTIONARY:
		return base_value
	var start: float = float((slot as Dictionary)["set"]) if (slot as Dictionary).has("set") else base_value
	return (start + float((slot as Dictionary).get("add", 0.0))) * float((slot as Dictionary).get("mul", 1.0))


## Folds every relic's [method BaseRelic.modify_cast_damage] over [param damage] in order (each relic
## is called once). The PRODUCT of their factors is capped at `relic_damage_mult_cap`
## ([param config], default the shared relics.json), so the result is at most damage x cap.
## A damage <= 0 is returned unchanged (relics are still not called).
static func fold_damage(relics: Array, cast_info: Dictionary, damage: float, config: RelicConfig = null) -> float:
	if damage <= 0.0:
		return damage
	var cfg: RelicConfig = config if config != null else shared_config()
	var result: float = damage
	for relic: Variant in relics:
		if relic is BaseRelic:
			result = (relic as BaseRelic).modify_cast_damage(cast_info, result)
	return minf(result, damage * cfg.relic_damage_mult_cap)


## The windup seconds after every relic's [method BaseRelic.modify_cast_time], in order.
static func fold_cast_time(relics: Array, cast_info: Dictionary, sec: float) -> float:
	var result: float = sec
	for relic: Variant in relics:
		if relic is BaseRelic:
			result = (relic as BaseRelic).modify_cast_time(cast_info, result)
	return result


## The largest `max_join_pieces()` among [param relics] (at least the base 2).
static func max_join_pieces(relics: Array) -> int:
	var best: int = BaseRelic.BASE_JOIN_PIECES
	for relic: Variant in relics:
		if relic is BaseRelic:
			best = maxi(best, (relic as BaseRelic).max_join_pieces())
	return best


## The largest `featured_mult_override()` among [param relics], 0.0 when none imposes one.
static func featured_mult_override(relics: Array) -> float:
	var best: float = 0.0
	for relic: Variant in relics:
		if relic is BaseRelic:
			best = maxf(best, (relic as BaseRelic).featured_mult_override())
	return best
