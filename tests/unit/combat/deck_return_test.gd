extends SceneTree
## TD-013: Deck.return_last_draw — a cancelled card menu puts its drawn cards back so the next
## draw offers them again; curse rule (Story 033) kept; no copy duplicated or lost.

const HAND: int = 4

var fails: int = 0


func ck(label: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("PASS: ", label)
	else:
		fails += 1
		print("FAIL: ", label, " ", extra)


func _is_curse(id: String) -> bool:
	return id.begins_with("curse_")


func _twelve() -> Array[String]:
	var a: Array[String] = []
	for i: int in 5:
		a.append("kiem_khi")
	for i: int in 4:
		a.append("chan_phong")
	for i: int in 2:
		a.append("hoa_tran")
	a.append("bang_phong")
	return a


# Five curses + one normal card: a raw 4-card deal is all curses about a third of the time.
func _cursed() -> Array[String]:
	var a: Array[String] = ["kiem_khi"]
	for i: int in 5:
		a.append("curse_%d" % i)
	return a


# Bag holds no duplicate copy index and only valid ones.
func _bag_ok(d: Deck) -> bool:
	var seen: Dictionary = {}
	for i: int in d._bag:
		if seen.has(i) or i < 0 or i >= d.size():
			return false
		seen[i] = true
	return true


func _has_non_curse(hand: Array[String]) -> bool:
	for id: String in hand:
		if not _is_curse(id):
			return true
	return false


func _initialize() -> void:
	var curse := Callable(self, "_is_curse")

	# Cancel returns the four cards; the retry offers the same hand.
	var d := Deck.new(_twelve(), 42)
	var before: int = d._bag.size()
	var h1: Array[String] = d.draw_menu(HAND, curse)
	ck("cancel returns 4 cards", d.return_last_draw() == HAND)
	ck("bag size restored after return", d._bag.size() == before, "%d vs %d" % [d._bag.size(), before])
	ck("retry offers the same hand", d.draw_menu(HAND, curse) == h1, str(h1))
	ck("second return without a new draw does nothing", d.return_last_draw() == HAND and d.return_last_draw() == 0)

	# Deterministic per seed with returns in the sequence.
	var a := Deck.new(_twelve(), 7)
	var b := Deck.new(_twelve(), 7)
	var same: bool = true
	for i: int in 30:
		if a.draw_menu(HAND, curse) != b.draw_menu(HAND, curse):
			same = false
		if i % 3 == 0:
			a.return_last_draw()
			b.return_last_draw()
	ck("same seed same sequence with returns", same)

	# A hand that straddles a bag refill: returned copies are moved, never duplicated.
	var s := Deck.new(["kiem_khi", "chan_phong", "hoa_tran", "bang_phong", "kiem_khi", "chan_phong"], 3)
	s.draw(HAND)
	s.draw(HAND)
	# Across a refill the same copy can be dealt twice (pre-existing Deck behaviour); it goes back once.
	var uniq: Array[int] = []
	for i: int in s._last_dealt:
		if not uniq.has(i):
			uniq.append(i)
	var expect_ids: Array[String] = []
	for i: int in uniq:
		expect_ids.append(str(s._cards[i]["id"]))
	s.return_last_draw()
	ck("straddle: bag full and unique after return", _bag_ok(s) and s._bag.size() == s.size(), str(s._bag))
	ck("straddle: retry offers the returned copies first", s.draw(uniq.size()) == expect_ids)

	# Curse rule kept: every menu hand holds the non-curse card, also after a return.
	var curse_ok: bool = true
	var redraw_same: bool = true
	var all_curse_raw_seen: bool = false
	for seed_value: int in 40:
		var c := Deck.new(_cursed(), seed_value)
		var raw: Array[String] = Deck.new(_cursed(), seed_value).draw(HAND)
		if not _has_non_curse(raw):
			all_curse_raw_seen = true
		var hand: Array[String] = c.draw_menu(HAND, curse)
		c.return_last_draw()
		var again: Array[String] = c.draw_menu(HAND, curse)
		if not _has_non_curse(hand) or not _has_non_curse(again):
			curse_ok = false
		if hand != again:
			redraw_same = false
		if not _bag_ok(c):
			curse_ok = false
	ck("curse fixture hits the all-curse redraw case", all_curse_raw_seen)
	ck("curse rule kept across returns", curse_ok)
	ck("curse redraw: retry offers the same hand", redraw_same)

	# Many draw/return cycles: no copy duplicated or lost (bag size accounts for every copy).
	var m := Deck.new(_twelve(), 99)
	var conserved: bool = true
	for i: int in 300:
		var size_before: int = m._bag.size()
		m.draw_menu(HAND, curse)
		if i % 2 == 0:
			m.return_last_draw()
			var expect: int = size_before if size_before >= HAND else m.size()
			if m._bag.size() != expect:
				conserved = false
		if not _bag_ok(m):
			conserved = false
	ck("300 draw/return cycles keep every copy exactly once", conserved)
	var counts: Dictionary = {}
	for id: String in m.to_array():
		counts[id] = int(counts.get(id, 0)) + 1
	ck("deck contents untouched", counts == {"kiem_khi": 5, "chan_phong": 4, "hoa_tran": 2, "bang_phong": 1})

	# A removed card invalidates the pending return (indexes shifted).
	var r := Deck.new(_twelve(), 5)
	r.draw(HAND)
	r.remove_at(0)
	ck("remove_at clears the pending return", r.return_last_draw() == 0 and _bag_ok(r))

	print("FAILS=", fails)
	quit(1 if fails > 0 else 0)
