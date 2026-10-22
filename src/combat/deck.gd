class_name Deck
extends RefCounted
## The player's deck: a seeded shuffle bag of card ids (duplicates allowed). The whole deck
## is shuffled into a bag; hands are dealt from the bag in order; when the bag runs out a
## fresh shuffled bag is made (same rng keeps going). Pure logic, deterministic per seed.
## Implements: Story 017 part A.

var _cards: Array[String] = []
var _bag: Array[String] = []
var _rng := RandomNumberGenerator.new()


func _init(cards: Array[String] = [], seed_value: int = 0) -> void:
	_cards = cards.duplicate()
	reset_bag(seed_value)


## Builds a deck from [param cards] (copied) with [param seed_value].
static func from_array(cards: Array[String], seed_value: int = 0) -> Deck:
	return Deck.new(cards, seed_value)


## Reseeds the rng and refills the bag with a fresh shuffle of the whole deck.
func reset_bag(seed_value: int) -> void:
	_rng.seed = seed_value
	_refill()


## Deals a hand of up to [param n] cards: from the remaining bag; if the bag is short, the
## remainder is dealt, then a fresh shuffled bag tops it up. A hand never holds more cards
## than the deck has (so never more copies of an id than the deck owns). Empty deck: [].
func draw(n: int) -> Array[String]:
	var hand: Array[String] = []
	var want: int = mini(maxi(n, 0), _cards.size())
	while hand.size() < want:
		if _bag.is_empty():
			_refill()
		hand.append(_bag.pop_front())
	return hand


## Number of cards in the deck.
func size() -> int:
	return _cards.size()


## Adds a copy of [param id] to the deck (it joins the bag at the next refill).
func add(id: String) -> void:
	_cards.append(id)


## Removes the card at [param index] from the deck (out of range: ignored). The current bag is
## rebuilt from the remaining deck order-free, so a removed card is never dealt again.
func remove_at(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	var id: String = _cards[index]
	_cards.remove_at(index)
	var at: int = _bag.find(id)
	if at >= 0:
		_bag.remove_at(at)


## A copy of the deck's card ids (deck order, not bag order).
func to_array() -> Array[String]:
	return _cards.duplicate()


## How many copies of [param id] the deck holds.
func count_of(id: String) -> int:
	return _cards.count(id)


func _refill() -> void:
	_bag = _cards.duplicate()
	# Fisher-Yates with the owned rng (Array.shuffle would use the global one).
	for i: int in range(_bag.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: String = _bag[i]
		_bag[i] = _bag[j]
		_bag[j] = tmp
