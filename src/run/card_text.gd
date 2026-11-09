class_name CardText
extends RefCounted
## TD-026: the ONE place a card description (`card.<id>.desc` in assets/i18n/strings.csv) gets its
## numbers. The strings carry named placeholders (`{push_cells}`, `{burn_sec}`, ...) instead of
## hard-coded numbers; [method describe_resolved] fills them from the card's level-resolved data
## (SkillConfig.resolved: cards.json plus the `upgrade` deltas) and, for the global numbers, from
## CombatConfig (combat.json: Ran / Han / execute, and the `zones` seconds / damage a zone card does
## not set itself, the same fallback CutEffects uses). Every screen that shows a card description
## (reward, shop card + detail, event card offer) calls this, so a balance change in the data shows up
## in the text. Runtime-only modifiers (relics, signature zone multipliers) are not reflected.
##
## Placeholders (all filled for every card; a string uses the ones it needs):
## min_cells, push_cells, burn_sec, pin_sec, fragile_stacks, frost_stacks, fragile_bonus
## (card bonus_vs_fragile_mult), heal_self, draw_damage, seal_sec, thorn_sec, thorn_damage,
## thorn_fragile_stacks (card value, else combat.json zones), fragile_mult, frost_burst_stacks,
## frost_burst_damage, execute_pct (card execute_ratio, else combat.json execute_ratio, as a percent),
## execute_mult (CutEffects.EXECUTE_MULT).

## Locale prefixes that write decimals with a comma ("2,5 s").
const COMMA_DECIMAL_LOCALES: Array[String] = ["vi"]
## Decimals kept when a number is not whole (trailing zeros are dropped).
const MAX_DECIMALS: int = 2
## Matches a placeholder left unfilled (tests use it).
const PLACEHOLDER_PATTERN: String = "\\{[a-z_]+\\}"
## Key suffix of the shorter battle-menu wording of a card description (`card.<id>.desc_battle`).
const BATTLE_SUFFIX: String = "_battle"

# CombatConfig from combat.json, loaded once when a caller does not pass one.
static var _shared_combat: CombatConfig = null


## The description of card [param card_id] at [param level] (clamped by SkillConfig.resolved) in the
## current locale, numbers filled from [param skills] and [param combat] (null = combat.json, loaded
## once). Unknown card: "".
static func describe(card_id: String, level: int, skills: SkillConfig, combat: CombatConfig = null) -> String:
	if skills == null:
		return ""
	return describe_resolved(skills.resolved(card_id, level), combat)


## The description of an already resolved card dictionary (SkillConfig.resolved / get_skill output, as
## the views hold it) in the current locale. [param locale] "" = TranslationServer's locale; it only
## picks the decimal separator, the template is always translated in the current locale.
static func describe_resolved(skill: Dictionary, combat: CombatConfig = null, locale: String = "") -> String:
	var key: String = str(skill.get("desc_key", ""))
	if key.is_empty():
		return ""
	var template: String = str(TranslationServer.translate(key))
	return fill(template, skill, combat, locale)


## The text a card shows in the battle card menu (no detail panel there, only the card-choice seconds): the
## "<desc_key>_battle" string when strings.csv has one (a shorter wording of a long rule), else describe_resolved.
static func describe_battle(skill: Dictionary, combat: CombatConfig = null, locale: String = "") -> String:
	var key: String = str(skill.get("desc_key", ""))
	if key.is_empty():
		return ""
	var battle_key: String = key + BATTLE_SUFFIX
	var template: String = str(TranslationServer.translate(battle_key))
	if template == battle_key:
		return describe_resolved(skill, combat, locale)
	return fill(template, skill, combat, locale)


## Fills the placeholders of [param template] from [param skill] and [param combat] (null = combat.json).
## A template without placeholders comes back unchanged.
static func fill(template: String, skill: Dictionary, combat: CombatConfig = null, locale: String = "") -> String:
	if not template.contains("{"):
		return template
	return template.format(values(skill, combat, locale))


## The placeholder -> formatted number table for [param skill] (see the class doc for the keys).
static func values(skill: Dictionary, combat: CombatConfig = null, locale: String = "") -> Dictionary:
	var cc: CombatConfig = combat if combat != null else _combat()
	var loc: String = locale if not locale.is_empty() else TranslationServer.get_locale()
	var zones: Dictionary = cc.zone_numbers()
	var execute_ratio: float = float(skill.get("execute_ratio", 0.0))
	if execute_ratio <= 0.0:
		execute_ratio = cc.execute_ratio
	var out: Dictionary = {
		"min_cells": _num(float(skill.get("min_cells", 1)), loc),
		"push_cells": _num(float(skill.get("push_cells", 0)), loc),
		# Skill v2 delayed (Hỏa Lôi): a card whose burn comes from its event payload shows that burn.
		"burn_sec": _num(float(skill.get("burn_duration_sec", 0.0)) if float(skill.get("burn_duration_sec", 0.0)) > 0.0
			else float(((skill.get("event_payload", {}) as Dictionary).get("ignite", {}) as Dictionary).get("sec", 0.0)), loc),
		"fuse_sec": _num(float(skill.get("fuse_sec", 0.0)), loc),
		"fuse_mult": _num(float(skill.get("fuse_mult", 1.0)), loc),
		# Hỏa Lôi Model C: the extra cells counted beyond the foe's size (damage_cells_rule footprint).
		"cells_extra": _num(float((skill.get("damage_cells_rule", {}) as Dictionary).get("extra", 0)), loc),
		"pin_sec": _num(float(skill.get("pin_duration_sec", 0.0)), loc),
		"fragile_stacks": _num(float(skill.get("fragile_stacks", 0)), loc),
		"frost_stacks": _num(float(skill.get("frost_stacks", 0)), loc),
		"fragile_bonus": _num(float(skill.get("bonus_vs_fragile_mult", 1.0)), loc),
		"heal_self": _num(float(skill.get("heal_self", 0.0)), loc),
		"draw_damage": _num(float(skill.get("draw_damage", 0.0)), loc),
		"fragile_mult": _num(cc.fragile_mult, loc),
		"frost_burst_stacks": _num(float(cc.frost_stacks_to_burst), loc),
		"frost_burst_damage": _num(cc.frost_burst_damage, loc),
		"execute_pct": _num(float(roundi(execute_ratio * 100.0)), loc),
		"execute_mult": _num(CutEffects.EXECUTE_MULT, loc),
		# Cast rhythm spec 2026-11-05: the crit multiplier (1.2) and the parry numbers (1.1).
		"crit_mult": _num(float((skill.get("crit", {}) as Dictionary).get("mult", 1.0)), loc),
		"parry_sec": _num(float(skill.get("parry_sec", 0.0)), loc),
		"reflect_mult": _num(float(skill.get("reflect_mult", 0.0)), loc),
		"parry_pin_sec": _num(float(skill.get("parry_pin_sec", 0.0)), loc),
		# Skill v2 (Trảm Địa): the burst multiplier and Pin, and the surge clause in percent per step / cap.
		"burst_first": _num(float(skill.get("burst_first", 1.0)), loc),
		"burst_pin_sec": _num(float(skill.get("burst_pin_sec", 0.0)), loc),
		"surge_pct": _num(float(roundi(float((skill.get("shape_clause", {}) as Dictionary).get("surge_per_step", 0.0)) * 100.0)), loc),
		# Skill v2 (Ngàn Kiếm): the cast's hit cap and the branched centre multiplier.
		"max_hits": _num(float(skill.get("max_hits", 1)), loc),
		"centre_mult": _num(float((skill.get("shape_clause", {}) as Dictionary).get("centre_mult", 1.0)), loc),
		"surge_cap_pct": _num(float(roundi(float((skill.get("shape_clause", {}) as Dictionary).get("surge_cap", 0.0)) * 100.0)), loc),
	}
	for zone_key: String in SkillConfig.ZONE_KEYS:
		out[zone_key] = _num(float(skill.get(zone_key, zones.get(zone_key, 0.0))), loc)
	return out


## Formats [param value] for [param locale]: whole numbers without decimals, otherwise up to
## [constant MAX_DECIMALS] decimals without trailing zeros, comma separator for the
## [constant COMMA_DECIMAL_LOCALES].
static func format_number(value: float, locale: String) -> String:
	return _num(value, locale)


static func _num(value: float, locale: String) -> String:
	var text: String
	if is_equal_approx(value, roundf(value)):
		text = str(roundi(value))
	else:
		text = ("%." + str(MAX_DECIMALS) + "f") % value
		text = text.rstrip("0").rstrip(".")
	for prefix: String in COMMA_DECIMAL_LOCALES:
		if locale.begins_with(prefix):
			return text.replace(".", ",")
	return text


static func _combat() -> CombatConfig:
	if _shared_combat == null:
		_shared_combat = CombatConfig.load_from_file()
	return _shared_combat
