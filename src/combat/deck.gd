class_name Deck
extends RefCounted
## The player's deck: a seeded shuffle bag of card COPIES, each {id, level} (duplicates allowed).
## The whole deck is shuffled into a bag of copy indexes; hands are dealt from the bag in order;
## when the bag runs out a fresh shuffled bag is made (same rng keeps going). Pure logic,
## deterministic per seed. Implements: Story 017 part A; card levels: Story 020.

var _cards: Array[Dictionary] = []
var _bag: Array[int] = []
var _rng := RandomNumberGenerator.new()


## [param cards] is an Array of ids (level 1) or of {id, level} dictionaries (copied).
func _init(cards: Array = [], seed_value: int = 0) -> void:
	for entry: Variant in cards:
		var e: Dictionary = _entry_of(entry)
		if not e.is_empty():
			_cards.append(e)
	reset_bag(seed_value)


## Builds a deck from [param cards] (ids or {id, level} dictionaries, copied) with [param seed_value].
static func from_array(cards: Array, seed_value: int = 0) -> Deck:
	return Deck.new(cards, seed_value)


## Reseeds the rng and refills the bag with a fresh shuffle of the whole deck.
func reset_bag(seed_value: int) -> void:
	_rng.seed = seed_value
	_refill()


## Deals a hand of up to [param n] card ids (see [method draw_entries]).
func draw(n: int) -> Array[String]:
	var hand: Array[String] = []
	for e: Dictionary in draw_entries(n):
		hand.append(str(e["id"]))
	return hand


## Deals a hand of up to [param n] {id, level} entries: from the remaining bag; if the bag is
## short, the remainder is dealt, then a fresh shuffled bag tops it up. A hand never holds more
## cards than the deck has (so never more copies of an id than the deck owns). Empty deck: [].
func draw_entries(n: int) -> Array[Dictionary]:
	var hand: Array[Dictionary] = []
	var want: int = mini(maxi(n, 0), _cards.size())
	while hand.size() < want:
		if _bag.is_empty():
			_refill()
		hand.append((_cards[_bag.pop_front()] as Dictionary).duplicate())
	return hand


## Number of cards (copies) in the deck.
func size() -> int:
	return _cards.size()


## Adds [param id]: if a copy below [param max_level] exists, the FIRST such copy is upgraded by 1
## instead; otherwise a new level-1 copy joins (at the next bag refill). Returns
## {"upgraded": bool, "level": resulting level of the touched copy, "id": id}.
func add(id: String, max_level: int = 3) -> Dictionary:
	for e: Dictionary in _cards:
		if str(e["id"]) == id and int(e["level"]) < max_level:
			e["level"] = int(e["level"]) + 1
			return {"upgraded": true, "level": int(e["level"]), "id": id}
	_cards.append({"id": id, "level": 1})
	return {"upgraded": false, "level": 1, "id": id}


## Removes the card at [param index] (out of range: ignored). That exact copy leaves the current
## bag too, so a removed card is never dealt again.
func remove_at(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	_cards.remove_at(index)
	var rebuilt: Array[int] = []
	for i: int in _bag:
		if i != index:
			rebuilt.append(i - 1 if i > index else i)
	_bag = rebuilt


## A copy of the deck's card ids (deck order, not bag order).
func to_array() -> Array[String]:
	var ids: Array[String] = []
	for e: Dictionary in _cards:
		ids.append(str(e["id"]))
	return ids


## Copies of the deck's {id, level} entries (deck order).
func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _cards:
		out.append(e.duplicate())
	return out


## How many copies of [param id] the deck holds.
func count_of(id: String) -> int:
	var n: int = 0
	for e: Dictionary in _cards:
		if str(e["id"]) == id:
			n += 1
	return n


## Highest level among the copies of [param id]; 0 if the deck has none.
func level_of(id: String) -> int:
	var best: int = 0
	for e: Dictionary in _cards:
		if str(e["id"]) == id:
			best = maxi(best, int(e["level"]))
	return best


# {id, level} from a String id or a dictionary; {} when unusable. Level is at least 1.
static func _entry_of(entry: Variant) -> Dictionary:
	if typeof(entry) == TYPE_DICTIONARY:
		var d: Dictionary = entry as Dictionary
		if not d.has("id"):
			return {}
		return {"id": str(d["id"]), "level": maxi(int(d.get("level", 1)), 1)}
	return {"id": str(entry), "level": 1}


func _refill() -> void:
	_bag = []
	for i: int in _cards.size():
		_bag.append(i)
	# Fisher-Yates with the owned rng (Array.shuffle would use the global one).
	for i: int in range(_bag.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: int = _bag[i]
		_bag[i] = _bag[j]
		_bag[j] = tmp
