class_name RunSession
extends RefCounted
## Pure data + rules of one ROGUELIKE RUN (Story 019): one character walks one chapter, floor by
## floor. Holds what must survive between matches and in the save: deck, HP, position, seed,
## clock and the pending card offer. No nodes, no files. HP rules: starts full (hp = -1); after
## a won match +heal_between_matches, after a floor boss +heal_between_floors, plus the passive
## heal; never refilled on a new floor; no minimum. Death simply ends the run (caller discards it).

## Character id (CharacterConfig).
var character_id: String = ""
## Index into ChaptersConfig of the chapter being run.
var chapter_index: int = 0
## Current floor of the chapter (0-based).
var floor_index: int = 0
## Current match of the floor (0-based).
var match_index: int = 0
## Player HP at the START of the current match; negative = full HP.
var hp: float = -1.0
## Card ids of the deck (duplicates allowed).
var deck_ids: Array[String] = []
## Seed of the whole run (floor seeds derive from it).
var run_seed: int = 0
## Seconds of PLAYING time of the run (written by the flow).
var elapsed_sec: float = 0.0
## Card ids offered after the last won match and not yet picked / skipped; [] when none.
var pending_reward: Array[String] = []
## Revive tokens (from chapters defaults; reserved, unused).
var revives: int = 0
var _won: bool = false
# Config the session was built with (ids for [method to_dict]).
var _chapters: ChaptersConfig = null


## New run: floor 0, match 0, full HP, deck = the character's starter_deck, revives from
## `defaults.revive_tokens`. [param character] is [method CharacterConfig.get_character].
static func begin(chapters: ChaptersConfig, character: Dictionary, chapter_index: int, run_seed: int) -> RunSession:
	var s := RunSession.new()
	s._chapters = chapters
	s.character_id = str(character.get("id", ""))
	s.chapter_index = clampi(chapter_index, 0, chapters.chapter_count() - 1)
	s.run_seed = run_seed
	for id: Variant in character.get("starter_deck", []) as Array:
		s.deck_ids.append(str(id))
	s.revives = int(chapters.defaults().get("revive_tokens", 0))
	return s


## Seed of the current floor (arena shapes: pass to ChaptersConfig.resolved_floor):
## ChaptersConfig.arena_seed_for(run_seed, chapter_index * 100 + floor_index). Stable, non-negative.
func floor_seed() -> int:
	return ChaptersConfig.arena_seed_for(run_seed, chapter_index * 100 + floor_index)


## "chapter id/floor id" of the current floor (e.g. "ch1/f2").
func floor_key(chapters: ChaptersConfig) -> String:
	return chapters.floor_key(chapter_index, floor_index)


## True on the last floor of the chapter.
func is_last_floor(chapters: ChaptersConfig) -> bool:
	return chapters.is_last_floor_of_chapter(chapter_index, floor_index)


## True when the current match is the floor's boss match (last match).
func is_boss_match(chapters: ChaptersConfig) -> bool:
	return match_index == chapters.match_count(chapter_index, floor_index) - 1


## Adds a card to the deck.
func add_card(id: String) -> void:
	deck_ids.append(id)


## Applies a WON match. [param hp_end] = player HP when the fight ended. Non-boss:
## hp = min(hp_end + heal_between_matches + passive_heal, max_hp); boss: hp = min(hp_end +
## heal_between_floors + passive_heal, max_hp). Then advances: non-boss -> match_index + 1; boss ->
## next floor (match 0) or, on the last floor, [method is_run_won] becomes true (hp is still set).
func apply_match_won(hp_end: float, max_hp: float, chapters: ChaptersConfig, is_boss_match: bool, passive_heal: float) -> void:
	var defaults: Dictionary = chapters.defaults()
	var heal: float = float(defaults["heal_between_floors" if is_boss_match else "heal_between_matches"])
	hp = minf(hp_end + heal + passive_heal, max_hp)
	if not is_boss_match:
		match_index += 1
	elif is_last_floor(chapters):
		_won = true
	else:
		floor_index += 1
		match_index = 0


## True once the last floor's boss was beaten.
func is_run_won() -> bool:
	return _won


## Stores the offer waiting for a pick.
func set_pending_reward(ids: Array[String]) -> void:
	pending_reward = ids.duplicate()


## Forgets the offer (picked or skipped).
func clear_pending_reward() -> void:
	pending_reward = []


## True while an offer waits for a pick.
func has_pending_reward() -> bool:
	return not pending_reward.is_empty()


## Save form: {character, chapter (id), floor (id), match_index, hp, deck, run_seed, elapsed,
## pending_reward, revives}.
func to_dict() -> Dictionary:
	return {
		"character": character_id, "chapter": _chapters.chapter_id(chapter_index),
		"floor": _chapters.floor_id(chapter_index, floor_index), "match_index": match_index, "hp": hp,
		"deck": deck_ids.duplicate(), "run_seed": run_seed, "elapsed": elapsed_sec,
		"pending_reward": pending_reward.duplicate(), "revives": revives,
	}


## Rebuilds from [method to_dict]; null on bad data (unknown chapter / floor, match out of range,
## no known card left in the deck). Unknown cards are dropped (warning). [param cards] is optional:
## without it card ids are not validated.
static func from_dict(d: Dictionary, chapters: ChaptersConfig, cards: SkillConfig = null) -> RunSession:
	var ci: int = -1
	for i: int in chapters.chapter_count():
		if chapters.chapter_id(i) == str(d.get("chapter", "")):
			ci = i
	if ci < 0:
		push_warning("RunSession: unknown chapter '%s', run dropped" % str(d.get("chapter", "")))
		return null
	var fi: int = -1
	for i: int in chapters.floor_count(ci):
		if chapters.floor_id(ci, i) == str(d.get("floor", "")):
			fi = i
	if fi < 0:
		push_warning("RunSession: unknown floor '%s', run dropped" % str(d.get("floor", "")))
		return null
	var mi: int = int(d.get("match_index", 0))
	if mi < 0 or mi >= chapters.match_count(ci, fi):
		push_warning("RunSession: match %d out of range, run dropped" % mi)
		return null
	var s := RunSession.new()
	s._chapters = chapters
	s.character_id = str(d.get("character", ""))
	s.chapter_index = ci
	s.floor_index = fi
	s.match_index = mi
	s.hp = float(d.get("hp", -1.0))
	s.run_seed = int(d.get("run_seed", 0))
	s.elapsed_sec = maxf(float(d.get("elapsed", 0.0)), 0.0)
	s.revives = maxi(int(d.get("revives", 0)), 0)
	s.deck_ids = _known_ids(d.get("deck", []), cards)
	s.pending_reward = _known_ids(d.get("pending_reward", []), cards)
	if s.character_id.is_empty() or s.deck_ids.is_empty():
		push_warning("RunSession: no character or empty deck, run dropped")
		return null
	return s


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
