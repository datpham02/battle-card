extends SceneTree
## Story 040 Part C2: every character's starter deck leans into the direction of its signature (>= 3 of 6 cards in
## that direction, at most 2 `kiem_khi`), and any two characters share at most 3 cards (duplicates counted).
## Pure data check on assets/data/characters.json and cards.json. The direction sets below are the test's fixture.

const MIN_DIRECTION: int = 3
const MAX_BASE_CARDS: int = 2
const MAX_SHARED: int = 3
const BASE_CARD: String = "kiem_khi"
## Direction cards per character (Slash Fury / Heaven's Fire / Shadow Step / Trap Net / Holy Seal).
const DIRECTION: Dictionary = {
	"kiem_si": ["kiem_vu", "thiet_kiem", "kiem_than", "dai_dao", "song_kiem", "tu_kiem"],
	"phap_su": ["hoa_xa", "hoa_tinh", "hoa_tran", "liet_hoa", "thien_hoa"],
	"sat_thu": ["bang_chau", "suong_mong", "bang_phong", "kiem_vu", "thiet_kiem", "han_kiem", "han_bang"],
	"tho_san": ["ket_gioi", "long_an", "tran_gai", "gai_nguyen", "ran_kich", "ran_van", "luoi_san", "gai_doc"],
	"giao_si": ["han_khi", "han_phong", "han_tran", "han_kiem", "thanh_thuy", "bang_tam"],
}

var fails: int = 0


func _init() -> void:
	var config: CharacterConfig = CharacterConfig.load_from_file()
	var ids: Array[String] = config.ids()
	ck("five characters", ids.size() == 5)
	for id: String in ids:
		var deck: Array[String] = config.deck_of(id)
		ck("%s: starter deck has 6 cards" % id, deck.size() == 6)
		var direction: int = 0
		var base: int = 0
		for card: String in deck:
			if card == BASE_CARD:
				base += 1
			elif (DIRECTION.get(id, []) as Array).has(card):
				direction += 1
		ck("%s: >= %d cards in its direction (got %d)" % [id, MIN_DIRECTION, direction], direction >= MIN_DIRECTION)
		ck("%s: at most %d %s (got %d)" % [id, MAX_BASE_CARDS, BASE_CARD, base], base <= MAX_BASE_CARDS)
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var shared: int = _shared(config.deck_of(ids[i]), config.deck_of(ids[j]))
			ck("%s / %s share at most %d cards (got %d)" % [ids[i], ids[j], MAX_SHARED, shared], shared <= MAX_SHARED)
	print("FAILS=%d" % fails)
	quit(fails)


# Size of the multiset intersection of two decks.
func _shared(a: Array[String], b: Array[String]) -> int:
	var counts: Dictionary = {}
	for card: String in b:
		counts[card] = int(counts.get(card, 0)) + 1
	var shared: int = 0
	for card: String in a:
		if int(counts.get(card, 0)) > 0:
			counts[card] = int(counts[card]) - 1
			shared += 1
	return shared


func ck(label: String, ok: bool) -> void:
	if ok:
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)
