class_name ConveyorBelt
extends RefCounted
## Pure-logic conveyor belt: spawns cards at a fixed interval, moves them at
## constant speed, expires them at the far end. No scene/node dependency.
## Runs continuously; nothing the player does affects it.
## Implements: design/game-brief.md MVP feature 1 (Story 001).

## Emitted when a card appears at the spawn end.
signal card_spawned(card: ConveyorCard)
## Emitted when a card reaches the far end un-taken; it is removed from the belt.
signal card_expired(card: ConveyorCard)

## Emitted when a card is removed from the belt by [method take_card] (not an expiry).
signal card_taken(card: ConveyorCard)

var _held: Dictionary = {} # uid -> true, cards currently being dragged
var _config: ConveyorConfig
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _cards: Array[ConveyorCard] = []
var _next_uid: int = 0
var _spawn_timer: float = 0.0
var _total_weight: float = 0.0


## [param config] supplies interval/speed/card table. [param seed_value] makes
## card-type selection deterministic; pass a negative value for a random seed.
func _init(config: ConveyorConfig, seed_value: int = -1) -> void:
	_config = config
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	for entry: Dictionary in _config.cards:
		_total_weight += maxf(float(entry.get("weight", 1.0)), 0.0)
	# First card spawns on the first tick.
	_spawn_timer = _config.spawn_interval_sec


## Cards currently on the belt, ordered oldest (far end) to newest.
## Returns a shallow copy: adding/removing entries has no effect on the belt (use
## [method take_card]). The [ConveyorCard] objects are shared; callers must treat
## them as read-only (positions are owned by [method tick]).
func get_cards() -> Array[ConveyorCard]:
	return _cards.duplicate()


## The card with [param uid] if it is on the belt, else null (same read-only rule as [method get_cards]).
func find_card(uid: int) -> ConveyorCard:
	var index: int = _index_of(uid)
	return _cards[index] if index != -1 else null


## Removes the card with [param uid] from the belt and returns it; null if it is not on the belt.
## Emits [signal card_taken]. Works whether or not the card is held.
func take_card(uid: int) -> ConveyorCard:
	var index: int = _index_of(uid)
	if index == -1:
		return null
	var card: ConveyorCard = _cards[index]
	_cards.remove_at(index)
	_held.erase(uid)
	card_taken.emit(card)
	return card


## Marks a card as held (being dragged) or releases it. A held card keeps moving
## with the belt (its position stays true) but is never expired: on reaching the far
## end it waits there at exactly [code]belt_length[/code]. When released at the far end
## it expires on the next [method tick] like any other card. Returns false if not on the belt.
func set_card_held(uid: int, held: bool) -> bool:
	if _index_of(uid) == -1:
		return false
	if held:
		_held[uid] = true
	else:
		_held.erase(uid)
	return true


## True if the card is currently marked held.
func is_card_held(uid: int) -> bool:
	return _held.has(uid)


## Advances the simulation by [param delta] seconds.
func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	# Move existing cards (held ones stop at the far end), then expire those past it.
	var step: float = _config.belt_speed * delta
	for card: ConveyorCard in _cards:
		card.position += step
		if card.position > _config.belt_length and _held.has(card.uid):
			card.position = _config.belt_length
	# Cards stay ordered oldest-first (largest position first), so stop at the first
	# card still on the belt. Held cards at the far end are skipped, not expired.
	var i: int = 0
	while i < _cards.size() and _cards[i].position >= _config.belt_length:
		if _held.has(_cards[i].uid):
			i += 1
			continue
		var expired: ConveyorCard = _cards[i]
		_cards.remove_at(i)
		card_expired.emit(expired)
	# Spawn; a large delta may yield several cards, each aged by its own leftover time.
	_spawn_timer += delta
	while _spawn_timer >= _config.spawn_interval_sec:
		_spawn_timer -= _config.spawn_interval_sec
		var card := _spawn_card()
		card.position = _spawn_timer * _config.belt_speed
		if card.position >= _config.belt_length:
			continue # Would already be off the belt; never shown.
		_cards.append(card)
		card_spawned.emit(card)


## Runs [param duration_sec] of simulation in fixed steps (used to start populated).
func prewarm(duration_sec: float, step_sec: float = 0.05) -> void:
	var remaining: float = duration_sec
	while remaining > 0.0:
		var dt: float = minf(step_sec, remaining)
		tick(dt)
		remaining -= dt


func _index_of(uid: int) -> int:
	for i: int in _cards.size():
		if _cards[i].uid == uid:
			return i
	return -1


func _spawn_card() -> ConveyorCard:
	var card := ConveyorCard.new()
	card.uid = _next_uid
	_next_uid += 1
	card.type_id = _pick_type_id()
	return card


func _pick_type_id() -> String:
	var roll: float = _rng.randf() * _total_weight
	var acc: float = 0.0
	for entry: Dictionary in _config.cards:
		acc += maxf(float(entry.get("weight", 1.0)), 0.0)
		if roll < acc:
			return str(entry.get("id", ""))
	return str(_config.cards[_config.cards.size() - 1].get("id", ""))
