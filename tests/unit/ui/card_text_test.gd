extends SceneTree
## TD-026 (texts): card descriptions take their numbers from the card data through CardText.
## Every card description formats without a leftover placeholder in vi and en at every level, no
## card description template hard-codes a digit, a changed number in a fixture SkillConfig /
## CombatConfig shows up in the text (card values, combat.json zone fallbacks, keyword numbers), level
## upgrades show, numbers use the locale's decimal separator, and the card screens call the helper.
## Prints PASS/FAIL lines and FAILS=n.

const VIEWS: Array[String] = ["res://src/run/reward_view.gd", "res://src/run/shop_view.gd", "res://src/run/event_view.gd"]
const LOCALES: Array[String] = ["vi", "en"]

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	var previous: String = TranslationServer.get_locale()
	_real_cards()
	_fixture_numbers()
	_levels()
	_number_format()
	_views_use_helper()
	TranslationServer.set_locale(previous)
	print("FAILS=%d" % _fails)
	quit(1 if _fails > 0 else 0)


# Every real card, both locales, every level: translated, no leftover placeholder; templates have no digit.
func _real_cards() -> void:
	var skills: SkillConfig = SkillConfig.load_from_file()
	var combat: CombatConfig = CombatConfig.load_from_file()
	var leftover := RegEx.create_from_string(CardText.PLACEHOLDER_PATTERN)
	var placeholder := RegEx.create_from_string("\\{[^}]*\\}")
	var digit := RegEx.create_from_string("[0-9]")
	for locale: String in LOCALES:
		TranslationServer.set_locale(locale)
		var bad: Array[String] = []
		var untranslated: Array[String] = []
		var hard_coded: Array[String] = []
		for id: Variant in skills.cards.keys():
			var key: String = str(skills.get_skill(str(id)).get("desc_key", ""))
			var template: String = str(TranslationServer.translate(key))
			if template == key or template.is_empty():
				untranslated.append(str(id))
			if digit.search(placeholder.sub(template, "", true)) != null:
				hard_coded.append("%s: %s" % [str(id), template])
			for level: int in range(1, SkillConfig.MAX_LEVEL + 1):
				var text: String = CardText.describe(str(id), level, skills, combat)
				if text.is_empty() or leftover.search(text) != null or text.contains("{") or text.contains("}"):
					bad.append("%s L%d: %s" % [str(id), level, text])
		_check(skills.cards.size() >= 30, "%s: %d cards checked" % [locale, skills.cards.size()])
		_check(untranslated.is_empty(), "%s: every card desc is translated (missing: %s)" % [locale, str(untranslated)])
		_check(bad.is_empty(), "%s: no leftover placeholder at any level (bad: %s)" % [locale, str(bad)])
		_check(hard_coded.is_empty(), "%s: no card desc template hard-codes a digit (found: %s)" % [locale, str(hard_coded)])
	TranslationServer.set_locale("en")
	_check(CardText.describe("hoa_tinh", 1, skills, combat).contains("%s s" % CardText.format_number(float(skills.resolved("hoa_tinh", 1)["burn_duration_sec"]), "en")), "real hoa_tinh shows its cards.json burn seconds")
	_check(CardText.describe("no_such_card", 1, skills, combat).is_empty(), "unknown card: empty text")


# A changed number in fixture data shows up in the text.
func _fixture_numbers() -> void:
	var skills: SkillConfig = SkillConfig.from_dictionary(_fixture_cards())
	var combat: CombatConfig = CombatConfig.from_dictionary({
		"zones": {"seal_sec": 4.0, "thorn_sec": 9.0, "thorn_damage": 11.0, "thorn_fragile_stacks": 4},
		"fragile_mult": 1.75, "fragile_max_stacks": 3, "frost_stacks_to_burst": 5, "frost_burst_damage": 31,
		"execute_ratio": 0.4,
	})
	TranslationServer.set_locale("en")
	var burn: String = CardText.describe("hoa_tinh", 1, skills, combat)
	_check(burn.contains("7.5 s"), "en burn seconds from the card: %s" % burn)
	var thorns: String = CardText.describe("tran_gai", 1, skills, combat)
	_check(thorns.contains("9 s") and thorns.contains("11 HP") and thorns.contains("4 Fragile"), "en thorn numbers from combat zones: %s" % thorns)
	var own: String = CardText.describe("gai_nguyen", 1, skills, combat)
	_check(own.contains("6.5 s") and not own.contains("9 s") and own.contains("2 Fragile") and not own.contains("4 Fragile"),
		"en card zone numbers win over combat zones: %s" % own)
	var frost: String = CardText.describe("han_khi", 1, skills, combat)
	_check(frost.contains("3 Chill") and frost.contains("At 5 stacks") and frost.contains("bursts for 31"), "en frost stacks + combat burst numbers: %s" % frost)
	var fragile: String = CardText.describe("ran_kich", 1, skills, combat)
	_check(fragile.contains("×1.75"), "en Ran multiplier from combat: %s" % fragile)
	var execute: String = CardText.describe("tu_kiem", 1, skills, combat)
	_check(execute.contains("40 %"), "en execute threshold from combat: %s" % execute)
	var curse: String = CardText.describe("oan_hon", 1, skills, combat)
	_check(curse.contains("lose 5 HP"), "en curse draw damage from the card: %s" % curse)
	TranslationServer.set_locale("vi")
	var burn_vi: String = CardText.describe("hoa_tinh", 1, skills, combat)
	_check(burn_vi.contains("7,5 s"), "vi burn seconds with a decimal comma: %s" % burn_vi)
	var thorns_vi: String = CardText.describe("tran_gai", 1, skills, combat)
	_check(thorns_vi.contains("9 giây") and thorns_vi.contains("11 máu") and thorns_vi.contains("Rạn 4 tầng"), "vi thorn numbers from combat zones: %s" % thorns_vi)


# Level upgrades (the reward / shop screens show the upgraded level) change the numbers.
func _levels() -> void:
	var skills: SkillConfig = SkillConfig.from_dictionary(_fixture_cards())
	var combat: CombatConfig = CombatConfig.from_dictionary({})
	TranslationServer.set_locale("en")
	var l1: String = CardText.describe("suong_mong", 1, skills, combat)
	var l2: String = CardText.describe("suong_mong", 2, skills, combat)
	var l3: String = CardText.describe("suong_mong", 3, skills, combat)
	_check(l1.contains("0.8 s") and l2.contains("1.1 s") and l3.contains("1.4 s"), "pin seconds per level: %s / %s / %s" % [l1, l2, l3])
	var cells: String = CardText.describe("song_kiem", 2, skills, combat)
	_check(cells.begins_with("4 cells"), "min_cells upgrade shown at level 2: %s" % cells)
	var resolved: String = CardText.describe_resolved(skills.resolved("suong_mong", 2), combat)
	_check(resolved == l2, "describe_resolved(resolved dict) == describe(id, level)")
	var real: SkillConfig = SkillConfig.load_from_file()
	_check(CardText.describe("suong_mong", 2, real, combat) != CardText.describe("suong_mong", 1, real, combat), "real suong_mong level 2 text differs from level 1")


func _number_format() -> void:
	_check(CardText.format_number(2.0, "en") == "2", "whole number without decimals")
	_check(CardText.format_number(2.5, "vi") == "2,5" and CardText.format_number(2.5, "en") == "2.5", "decimal separator per locale")
	_check(CardText.format_number(0.8 + 0.3, "en") == "1.1", "float noise trimmed: %s" % CardText.format_number(0.8 + 0.3, "en"))
	_check(CardText.format_number(1.75, "en") == "1.75", "two decimals kept")


# The card screens call the helper, not tr(desc_key) directly.
func _views_use_helper() -> void:
	for path: String in VIEWS:
		var src: String = FileAccess.get_file_as_string(path)
		_check(src.contains("CardText.describe_resolved(") and not src.contains("tr(str(skill.get(\"desc_key\""), "%s shows card text through CardText" % path.get_file())


func _card(effect: String, extra: Dictionary) -> Dictionary:
	var card: Dictionary = {"effect": effect, "min_cells": 2, "cooldown_sec": 5.0, "damage_per_cell": 0.0, "rarity": "common", "upgrade": {"cooldown_sec": -1.0}, "implemented": true}
	card.merge(extra, true)
	return card


func _fixture_cards() -> Dictionary:
	return {
		"default_card": "hoa_tinh",
		"cards": {
			"hoa_tinh": _card("burn", {"burn_duration_sec": 7.5, "burn_tick_sec": 0.5, "burn_damage_per_tick": 1.0}),
			"tran_gai": _card("thorns", {}),
			"gai_nguyen": _card("thorns", {"thorn_sec": 6.5, "thorn_fragile_stacks": 2}),
			"han_khi": _card("frost", {"frost_stacks": 3}),
			"ran_kich": _card("fragile", {"fragile_stacks": 1}),
			"tu_kiem": _card("damage", {"damage_per_cell": 8.0, "execute": true}),
			"oan_hon": {"effect": "damage", "min_cells": 1, "cooldown_sec": 0.0, "damage_per_cell": 0.0, "rarity": "curse", "draw_damage": 5.0},
			"suong_mong": _card("pin", {"pin_duration_sec": 0.8, "upgrade": {"pin_duration_sec": 0.3}}),
			"song_kiem": _card("damage", {"min_cells": 5, "damage_per_cell": 8.0, "bonus_vs_fragile_mult": 1.5, "upgrade": {"min_cells": -1}}),
		},
	}
