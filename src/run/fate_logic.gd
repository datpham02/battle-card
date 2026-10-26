class_name FateLogic
extends RefCounted
## Pure rules of the SPARE / EXECUTE choice after a region boss and of the three endings (Story 035,
## design/game-brief.md "Tha hay Giet"). No nodes, no files: it takes plain Dictionaries (the `fate` and
## `endings` blocks of chapters.json `world`, read by ChaptersConfig) so tests and the balance sim can
## drive it without any config class.
##
## Ending rule: `spare_ratio = spared / (spared + executed)`; `>= spare_min_ratio` -> "spare";
## `<= execute_max_ratio` -> "execute"; else "balance"; no fates at all -> "balance".

const FATE_SPARE: String = "spare"
const FATE_EXECUTE: String = "execute"
const ENDING_SPARE: String = "spare"
const ENDING_EXECUTE: String = "execute"
const ENDING_BALANCE: String = "balance"
## Node kind of a region boss (RunSession.KIND_BOSS); only this kind can raise a fate choice.
const KIND_BOSS: String = "boss"
## Documented fallbacks for the `world.fate` / `world.endings` keys (chapters.json wins; mirrors the shipped file).
const FATE_DEFAULTS: Dictionary = {"execute_artifact_offers": 3, "execute_min_rarity": "rare", "fate_hold_sec": 0.6}
const ENDING_DEFAULTS: Dictionary = {"spare_min_ratio": 1.0, "execute_max_ratio": 0.0}


## True for a fate id the run accepts ("spare" or "execute").
static func is_valid_fate(fate: String) -> bool:
	return fate == FATE_SPARE or fate == FATE_EXECUTE


## spared / (spared + executed) over [param fates] (entries `{fate: "spare"|"execute", ...}`): 1.0 when all
## were spared, 0.0 when all were executed. Entries with another fate are ignored. Returns -1.0 when there is
## nothing to count (empty): 0.5 is NOT used, callers must treat -1.0 as "no choices made".
static func spare_ratio(fates: Array) -> float:
	var spared: int = 0
	var executed: int = 0
	for entry: Variant in fates:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		match str((entry as Dictionary).get("fate", "")):
			FATE_SPARE:
				spared += 1
			FATE_EXECUTE:
				executed += 1
	if spared + executed == 0:
		return -1.0
	return float(spared) / float(spared + executed)


## Ending id for [param fates] by [param endings_cfg] (`{spare_min_ratio, execute_max_ratio}`, missing keys
## fall back to [constant ENDING_DEFAULTS]): "spare", "execute" or "balance" (also when there are no fates).
static func ending_for(fates: Array, endings_cfg: Dictionary) -> String:
	var ratio: float = spare_ratio(fates)
	if ratio < 0.0:
		return ENDING_BALANCE
	var spare_min: float = float(endings_cfg.get("spare_min_ratio", ENDING_DEFAULTS["spare_min_ratio"]))
	var execute_max: float = float(endings_cfg.get("execute_max_ratio", ENDING_DEFAULTS["execute_max_ratio"]))
	if ratio >= spare_min:
		return ENDING_SPARE
	if ratio <= execute_max:
		return ENDING_EXECUTE
	return ENDING_BALANCE


## The relic offer of an EXECUTE: `execute_artifact_offers` DIFFERENT relic ids of rarity >= `execute_min_rarity`
## (both from [param fate_cfg], the `world.fate` block), never one of [param owned_relics], drawn through
## RelicRoller (source `treasure`, whose rarity-weighted draw takes the floor as its `min_rarity` argument; no
## separate relics.json source is needed) with a generator seeded by [param rng_seed]: same inputs, same offer.
## Fewer ids when the pool is short. [param relic_cfg] is a RelicConfig, a relics.json-shaped Dictionary
## (RelicConfig.from_dictionary) or null / {} for the shared relics.json.
## [param luck] is accepted for the API of the contract: RelicRoller has no luck input for relics, so it does
## not change the draw today.
static func roll_execute_offer(owned_relics: Array, fate_cfg: Dictionary, relic_cfg: Variant, rng_seed: int,
		luck: float = 0.0) -> Array[String]:
	var _unused_luck: float = luck
	var count: int = int(fate_cfg.get("execute_artifact_offers", FATE_DEFAULTS["execute_artifact_offers"]))
	var floor_name: String = str(fate_cfg.get("execute_min_rarity", FATE_DEFAULTS["execute_min_rarity"]))
	var cfg: RelicConfig = null
	if relic_cfg is RelicConfig:
		cfg = relic_cfg as RelicConfig
	elif typeof(relic_cfg) == TYPE_DICTIONARY and not (relic_cfg as Dictionary).is_empty():
		cfg = RelicConfig.from_dictionary(relic_cfg as Dictionary)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return RelicRoller.roll(RelicRoller.SOURCE_TREASURE, owned_relics, rng, cfg, count, floor_name)


## True only for the `boss` node of a REGION: the final match ([param is_final]) and every other kind
## (battle, miniboss, ...) never raise the Spare / Execute choice.
static func is_boss_fate_node(kind: String, is_final: bool) -> bool:
	return kind == KIND_BOSS and not is_final
