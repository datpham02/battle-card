extends SceneTree
## Quick spec menu-la-giua-man-hinh-2026-11-01 (card pick in the centre, LoL cooldowns), headless through the REAL
## piece path (bag slot -> select_piece -> aim_at_cell -> confirm_placement -> press_cast -> CutFlow.choose):
## - dropping piece 1 opens NO card menu: the place window starts, Tung phép shows;
## - piece 2 joins before Tung phép (no time added; the Resonant shape bonus still rides on the swing);
## - Tung phép opens the menu; no piece can join while it is open; detach / cancel work in the place window;
## - the place window runs out -> Tung phép is pressed automatically; the menu runs out -> the basic slash;
## - accessibility "Thời gian chọn lá": 6 s doubles both windows, "không giới hạn" never auto-presses / auto-picks;
## - cooldowns: SkillCooldowns keeps the use order and the full length, the HUD column lists the cards cooling down
##   and drops them when ready; CooldownPie reveals clockwise from 12 o'clock (0 at the use -> 1 when ready); a card
##   on cooldown in the hand cannot be picked;
## - SettingsStore persists card_time (temp file).
## Time is frozen (freeze_time): the real-time windows are advanced through CombatView._tick_place_window (the
## seam _process calls each frame) and CutFlow.tick_real. Numbers come from cuts.json / cards.json at run time.
## Prints PASS/FAIL lines and FAILS=n.

const BIG_HP: float = 1000000.0
const EPS: float = 0.001

var fails: int = 0
var _lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_lib = PieceLibrary.load_from_file()
	await _test_drop_join_cast()
	await _test_place_window_timeout()
	await _test_menu_timeout_basic_slash()
	await _test_card_time_setting()
	await _test_cooldowns_in_hand_and_column()
	_test_pie_maths()
	_test_skill_cooldowns_order()
	_test_settings_store()
	await process_frame
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ fixtures

# A headless match (HoldSlotsView + CombatView + CutHudView, time frozen), card time [param card_time], the boss
# parked on the middle of its half and inactive, featured shape off, player-half drops blocked.
func _match(card_time: String = SettingsStore.CARD_TIME_NORMAL) -> Node:
	var holder := Node.new()
	var bag := HoldSlotsView.new()
	bag.name = "HoldSlotsView"
	holder.add_child(bag)
	var v := CombatView.new()
	v.name = "CombatView"
	v.match_params = {"boss_max_hp": BIG_HP}
	v.drops_seed = 7
	v.freeze_time = true
	v.card_time_mode = card_time
	holder.add_child(v)
	var hud := CutHudView.new()
	hud.name = "CutHudView"
	holder.add_child(hud)
	root.add_child(holder)
	await process_frame
	v.get_boss().set_active(false)
	v._featured = {}
	var drops: FieldDrops = v.get_drops()
	for cell: Vector2i in v.get_grid().player_cells():
		drops.pick_up_at(cell, true)
	drops.set_blocked_cells(v.get_grid().player_cells())
	v.get_state().set_enemy_cell(_ec(v, 1, 1))
	return holder


func _cv(holder: Node) -> CombatView:
	return holder.get_node("CombatView") as CombatView


func _drop(holder: Node) -> void:
	root.remove_child(holder)
	holder.free()


# Enemy-half cell at column offset [param dx] (0..2) and row [param y].
func _ec(v: CombatView, dx: int, y: int) -> Vector2i:
	return Vector2i(v.get_grid().side_cols + dx, y)


# Bag: bar3 / bar2 / mono in slots 0..2; deck: [param deck].
func _fill(v: CombatView, deck: Array[String]) -> void:
	var hold: HoldSlots = v.get_hold()
	for i: int in hold.get_slot_count():
		hold.remove(i)
	var shapes: Array[String] = ["bar3", "bar2", "mono"]
	for i: int in shapes.size():
		var p := FieldPoint.new()
		p.uid = -100 - i
		p.freshness_left = 0.0
		p.piece = _lib.make_piece(shapes[i], 0)
		p.label = shapes[i]
		hold.place(p, i)
	v._deck = Deck.from_array(deck, 1)


# Places bag slot [param slot] with its ghost aimed at [param cell] (select, aim, commit).
func _place(v: CombatView, slot: int, cell: Vector2i) -> bool:
	return v.select_piece(slot, false) and v.aim_at_cell(cell) and v.confirm_placement()


func _sorted(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = cells.duplicate()
	out.sort()
	return out


# ------------------------------------------------------------------ tests

func _test_drop_join_cast() -> void:
	var h: Node = await _match()
	var v: CombatView = _cv(h)
	var flow: CutFlow = v.get_cut_flow()
	var hold: HoldSlots = v.get_hold()
	var cut_cfg: CutConfig = v.get_cut_config()
	_fill(v, ["kiem_khi", "kiem_khi", "kiem_khi", "kiem_khi"] as Array[String])
	_check("press_cast with nothing placed does nothing", not v.press_cast() and not flow.is_menu_open())
	# Piece 1: bar3 across row 1 of the enemy half.
	_check("piece 1 committed", _place(v, 0, _ec(v, 1, 1)))
	_check("no card menu after the drop (no cards drawn)", not flow.is_menu_open() and flow.get_hand().is_empty())
	_check("place window started, Tung phép visible", v.is_placed() and v.is_confirm_visible() and v.can_cast())
	_check("place window length = cuts.json place_window_sec", absf(v.get_place_duration() - cut_cfg.place_window_sec) < EPS \
		and absf(v.get_place_time_left() - cut_cfg.place_window_sec) < EPS, "%.2f" % v.get_place_time_left())
	_check("piece 1 left the bag, bag still live for a join", hold.get_piece(0) == null and v.can_join_piece())
	_check("no pause and no signature in the place window", not v.can_pause() and not v.can_activate_signature())
	# Resonant shape: the 3x2 block (bar3 over bar2), set as the match's featured shape (test seam).
	var block: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)]
	v._featured = {"cells": block, "bonus": {"damage_mult": 1.5, "effect": "", "stacks": 0, "sec": 0.0}}
	v._tick_place_window(0.5)
	var left_before: float = v.get_place_time_left()
	_check("piece 2 joins before Tung phép (bar2 under bar3's left end)", _place(v, 1, _ec(v, 0, 2)) and v.get_cast_plan().piece_count() == 2)
	_check("join adds no time to the place window", absf(v.get_place_time_left() - left_before) < EPS, "%.2f vs %.2f" % [v.get_place_time_left(), left_before])
	_check("joined plan is the Resonant shape", v.is_plan_featured())
	_check("still no menu after the join", not flow.is_menu_open() and v.is_placed())
	# Detach + re-join in the place window.
	_check("detach the joined piece in the place window", v.detach_second_piece() and v.get_cast_plan().piece_count() == 1 and hold.get_piece(1) != null)
	_check("re-join", _place(v, 1, _ec(v, 0, 2)) and v.get_cast_plan().piece_count() == 2)
	var union: Array[Vector2i] = v.get_cast_plan().cells()
	# Tung phép.
	_check("Tung phép opens the menu on the union", v.press_cast() and flow.is_menu_open() and _sorted(flow.get_cells()) == _sorted(union), str(flow.get_cells()))
	_check("4 cards drawn on Tung phép", flow.get_hand().size() == v.get_skill_config().hand_size, str(flow.get_hand()))
	_check("Tung phép hidden while the menu is open", not v.is_confirm_visible() and not v.is_placed())
	_check("no join while the menu is open: can_join_piece false", not v.can_join_piece())
	_check("no join while the menu is open: the bag cannot be selected", not v.select_piece(2, false) and not v.is_placing())
	_check("no detach while the menu is open", not v.detach_second_piece() and v.get_cast_plan().piece_count() == 2)
	# Choose: the swing is the union and carries the Resonant bonus.
	_check("card chosen", flow.choose("kiem_khi") and not flow.is_menu_open())
	var actor: CutActor = v.get_cut_actor()
	_check("swing cells == the joined union", actor.is_swinging() and _sorted(actor.get_cells()) == _sorted(union))
	_check("Resonant bonus kept on a join made before Tung phép", float(actor.get_featured_bonus().get("damage_mult", 0.0)) == 1.5, str(actor.get_featured_bonus()))
	v.get_arbiter().tick(actor.get_time_left() + 0.01)
	# Cancel in the place window returns every piece.
	_fill(v, ["kiem_khi", "kiem_khi", "kiem_khi", "kiem_khi"] as Array[String])
	_place(v, 0, _ec(v, 1, 1))
	_place(v, 1, _ec(v, 0, 2))
	_check("cancel in the place window returns both pieces", v.cancel_placement() and not v.is_placed() and hold.get_piece(0) != null \
		and hold.get_piece(1) != null and v.get_cast_plan().piece_count() == 0 and not flow.is_menu_open())
	# Tung phép straight from a valid first ghost (the tap-to-aim path): commit + menu in one press.
	_check("Tung phép on a valid first ghost commits it and opens the menu", v.select_piece(0, false) and v.aim_at_cell(_ec(v, 1, 1)) \
		and v.press_cast() and flow.is_menu_open() and v.get_cast_plan().piece_count() == 1)
	_check("cancel in the menu returns the piece", v.cancel_placement() and not flow.is_menu_open() and hold.get_piece(0) != null)
	_drop(h)


func _test_place_window_timeout() -> void:
	var h: Node = await _match()
	var v: CombatView = _cv(h)
	var flow: CutFlow = v.get_cut_flow()
	var window: float = v.get_cut_config().place_window_sec
	_fill(v, ["kiem_khi", "kiem_khi", "kiem_khi", "kiem_khi"] as Array[String])
	_place(v, 0, _ec(v, 1, 1))
	v._tick_place_window(window - 0.1)
	_check("place window: still placing just before the end", v.is_placed() and not flow.is_menu_open())
	# A second piece still in the finger when the window runs out goes back to the bag.
	v.begin_drag(1, Vector2.ZERO)
	v.drag_to(v.drag_point_for_cell(_ec(v, 0, 2)))
	_check("second piece being dragged", v.is_dragging())
	v._tick_place_window(0.2)
	_check("place window ran out: Tung phép pressed, menu open", flow.is_menu_open() and not v.is_placed())
	_check("the dragged piece went back to the bag", not v.is_placing() and v.get_hold().get_piece(1) != null and v.get_cast_plan().piece_count() == 1)
	_drop(h)


func _test_menu_timeout_basic_slash() -> void:
	var h: Node = await _match()
	var v: CombatView = _cv(h)
	var flow: CutFlow = v.get_cut_flow()
	var cfg: SkillConfig = v.get_skill_config()
	_fill(v, ["dai_dao", "dai_dao", "dai_dao", "dai_dao"] as Array[String])
	_place(v, 0, _ec(v, 1, 1))
	v.press_cast()
	_check("menu duration = cards.json menu_choose_sec", absf(flow.get_duration() - cfg.menu_choose_sec) < EPS)
	flow.tick_real(cfg.menu_choose_sec - 0.1)
	_check("menu still open just before its end", flow.is_menu_open())
	flow.tick_real(0.2)
	var actor: CutActor = v.get_cut_actor()
	_check("menu timeout plays the basic slash", not flow.is_menu_open() and actor.is_swinging() and actor.get_skill_id() == cfg.default_card, actor.get_skill_id())
	v.get_arbiter().tick(actor.get_time_left() + 0.01)
	_drop(h)


func _test_card_time_setting() -> void:
	var h: Node = await _match(SettingsStore.CARD_TIME_LONG)
	var v: CombatView = _cv(h)
	var flow: CutFlow = v.get_cut_flow()
	var window: float = v.get_cut_config().place_window_sec
	var choose: float = v.get_skill_config().menu_choose_sec
	_fill(v, ["kiem_khi", "kiem_khi", "kiem_khi", "kiem_khi"] as Array[String])
	_check("6 s setting: place window doubled", absf(v.get_place_duration() - window * 2.0) < EPS, "%.2f" % v.get_place_duration())
	_place(v, 0, _ec(v, 1, 1))
	v._tick_place_window(window + 0.1)
	_check("6 s setting: no auto Tung phép after the normal window", v.is_placed() and not flow.is_menu_open())
	v._tick_place_window(window)
	_check("6 s setting: auto Tung phép after the doubled window", flow.is_menu_open())
	_check("6 s setting: menu time doubled", absf(flow.get_duration() - choose * 2.0) < EPS)
	flow.tick_real(choose + 0.1)
	_check("6 s setting: menu still open after the normal time", flow.is_menu_open())
	flow.tick_real(choose)
	_check("6 s setting: basic slash after the doubled time", not flow.is_menu_open() and v.get_cut_actor().is_swinging())
	v.get_arbiter().tick(v.get_cut_actor().get_time_left() + 0.01)
	# Unlimited: never auto-presses, never auto-picks.
	v.set_card_time(SettingsStore.CARD_TIME_UNLIMITED)
	_fill(v, ["kiem_khi", "kiem_khi", "kiem_khi", "kiem_khi"] as Array[String])
	_place(v, 0, _ec(v, 1, 1))
	v._tick_place_window(1000.0)
	_check("unlimited: no auto Tung phép", v.is_placed() and not flow.is_menu_open() and v.is_place_unlimited() and v.get_place_duration() == 0.0)
	_check("unlimited: the player presses Tung phép", v.press_cast() and flow.is_menu_open() and flow.is_unlimited())
	flow.tick_real(1000.0)
	_check("unlimited: the menu waits for a card", flow.is_menu_open() and not v.get_cut_actor().is_swinging())
	_check("unlimited: a card is still chosen by the player", flow.choose("kiem_khi") and v.get_cut_actor().is_swinging())
	v.get_arbiter().tick(v.get_cut_actor().get_time_left() + 0.01)
	_drop(h)


func _test_cooldowns_in_hand_and_column() -> void:
	var h: Node = await _match()
	var v: CombatView = _cv(h)
	var flow: CutFlow = v.get_cut_flow()
	var hud: CutHudView = h.get_node("CutHudView") as CutHudView
	var cds: SkillCooldowns = v.get_skill_cooldowns()
	var cfg: SkillConfig = v.get_skill_config()
	var cd_a: float = float(cfg.get_skill("kiem_vu").get("cooldown_sec", 0.0))
	var cd_b: float = float(cfg.get_skill("chan_phong").get("cooldown_sec", 0.0))
	_check("fixture: kiem_vu and chan_phong have cooldowns, kiem_vu the shorter", cd_a > 0.0 and cd_b > cd_a, "%.1f %.1f" % [cd_a, cd_b])
	_check("cooldown column empty at the start", hud.get_cooldown_column_ids().is_empty())
	# Use kiem_vu, then chan_phong through the real path.
	for card: String in ["kiem_vu", "chan_phong"]:
		_fill(v, [card, card, card, card] as Array[String])
		_place(v, 0, _ec(v, 1, 1))
		v.press_cast()
		_check("%s chosen" % card, flow.choose(card))
		v.get_arbiter().tick(v.get_cut_actor().get_time_left() + 0.01)
	_check("column lists the used cards in use order", hud.get_cooldown_column_ids() == (["kiem_vu", "chan_phong"] as Array[String]), str(hud.get_cooldown_column_ids()))
	_check("cooldown totals kept", absf(cds.total("kiem_vu") - cd_a) < EPS and absf(cds.total("chan_phong") - cd_b) < EPS)
	# A card on cooldown drawn into the hand is shown but cannot be picked.
	_fill(v, ["kiem_vu", "kiem_vu", "kiem_vu", "kiem_vu"] as Array[String])
	_place(v, 0, _ec(v, 1, 1))
	v.press_cast()
	var check: Dictionary = SkillAvailability.check(cfg, cds, "kiem_vu", flow.get_cells().size())
	_check("cooldown card in the hand: reason cooldown", flow.get_hand().has("kiem_vu") and str(check["reason"]) == "cooldown")
	_check("cooldown card in the hand cannot be picked", not flow.choose("kiem_vu") and flow.is_menu_open())
	v.cancel_placement()
	# Ready -> the icon leaves the column.
	cds.tick(cd_a + 0.01)
	_check("ready card leaves the column", hud.get_cooldown_column_ids() == (["chan_phong"] as Array[String]), str(hud.get_cooldown_column_ids()))
	cds.tick(cd_b)
	_check("column empty once every card is ready", hud.get_cooldown_column_ids().is_empty())
	# Controls v3 (user 2026-11-02): the Focus recharge sits in the same column, first, and leaves when ready.
	var focus: FocusController = v.get_focus()
	while focus.is_on_cooldown():
		focus.tick_real(1.0)
	_check("focus ready: no focus entry in the column", not hud.get_cooldown_column_entries().has(CutHudView.COOLDOWN_FOCUS_ID))
	_check("focus starts from READY", focus.try_start())
	focus.end("test")
	_check("focus on cooldown after end", focus.is_on_cooldown() and focus.get_cooldown_sec() > 0.0)
	_check("focus entry first in the column", hud.get_cooldown_column_entries() == ([CutHudView.COOLDOWN_FOCUS_ID] as Array[String]), str(hud.get_cooldown_column_entries()))
	_check("card ids leave the focus entry out", hud.get_cooldown_column_ids().is_empty())
	focus.tick_real(focus.get_cooldown_sec() + 0.01)
	_check("focus ready again: entry leaves the column", hud.get_cooldown_column_entries().is_empty(), str(hud.get_cooldown_column_entries()))
	_drop(h)


func _test_pie_maths() -> void:
	_check("pie: 0 recovered at the use", CooldownPie.recovered_fraction(8.0, 8.0) == 0.0)
	_check("pie: 1 when ready", CooldownPie.recovered_fraction(0.0, 8.0) == 1.0)
	_check("pie: a quarter after 2 of 8 s", absf(CooldownPie.recovered_fraction(6.0, 8.0) - 0.25) < EPS)
	_check("pie: no length counts as ready", CooldownPie.recovered_fraction(3.0, 0.0) == 1.0)
	_check("pie: shade starts at 12 o'clock at the use", absf(CooldownPie.shade_angles(0.0).x - (-PI * 0.5)) < EPS)
	var r := Rect2(0, 0, 100, 100)
	var full: float = _area(CooldownPie.shade_polygons(r, 0.0))
	_check("pie: the whole icon is shaded at the use", absf(full - 10000.0) < 1.0, "%.1f" % full)
	_check("pie: nothing shaded when ready", CooldownPie.shade_polygons(r, 1.0).is_empty())
	var q: float = _area(CooldownPie.shade_polygons(r, 0.25))
	_check("pie: 3/4 of the icon shaded at a quarter", absf(q - 7500.0) < 25.0, "%.1f" % q)
	# Clockwise from 12 o'clock: the top-RIGHT quarter is revealed first, the top-left one last.
	_check("pie: clockwise - top-right revealed at a quarter", not CooldownPie.is_shaded(r, 0.25, Vector2(75, 25)))
	_check("pie: clockwise - bottom-right still shaded at a quarter", CooldownPie.is_shaded(r, 0.25, Vector2(75, 75)))
	_check("pie: clockwise - top-left still shaded at three quarters", CooldownPie.is_shaded(r, 0.74, Vector2(25, 25)) \
		and not CooldownPie.is_shaded(r, 0.74, Vector2(25, 75)))
	_check("pie: seconds rounded up", CooldownPie.seconds_text(2.1) == "3" and CooldownPie.seconds_text(3.0) == "3" and CooldownPie.seconds_text(0.0) == "")


func _area(polys: Array[PackedVector2Array]) -> float:
	var total: float = 0.0
	for poly: PackedVector2Array in polys:
		var a: float = 0.0
		for i: int in poly.size():
			var p: Vector2 = poly[i]
			var n: Vector2 = poly[(i + 1) % poly.size()]
			a += p.x * n.y - n.x * p.y
		total += absf(a) * 0.5
	return total


func _test_skill_cooldowns_order() -> void:
	var c := SkillCooldowns.new()
	c.start("a", 4.0)
	c.start("b", 6.0)
	c.start("zero", 0.0)
	_check("running ids in use order, a zero cooldown never listed", c.running_ids() == (["a", "b"] as Array[String]))
	c.tick(1.0)
	_check("recovered fraction 1/4 of a", absf(c.recovered_fraction("a") - 0.25) < EPS)
	c.start("a", 4.0)
	_check("a card used again moves to the end", c.running_ids() == (["b", "a"] as Array[String]) and c.total("a") == 4.0 and c.remaining("a") == 4.0)
	c.clear("b")
	_check("clear drops the card and its total", c.running_ids() == (["a"] as Array[String]) and c.total("b") == 0.0)
	c.tick(5.0)
	_check("ready cards leave", c.running_ids().is_empty() and c.total("a") == 0.0)


func _test_settings_store() -> void:
	var path: String = "user://card_pick_flow_test_settings.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var store := SettingsStore.new(path)
	_check("card time defaults to normal (3 s)", store.get_card_time() == SettingsStore.CARD_TIME_NORMAL and SettingsStore.card_time_mult(store.get_card_time()) == 1.0)
	_check("cycle: normal -> long -> unlimited -> normal", store.cycle_card_time() == SettingsStore.CARD_TIME_LONG \
		and store.cycle_card_time() == SettingsStore.CARD_TIME_UNLIMITED and store.cycle_card_time() == SettingsStore.CARD_TIME_NORMAL)
	store.set_card_time(SettingsStore.CARD_TIME_UNLIMITED)
	store.set_card_time("bogus")
	var again := SettingsStore.new(path)
	_check("card time persisted, unknown value ignored", again.get_card_time() == SettingsStore.CARD_TIME_UNLIMITED)
	_check("multipliers: 6 s = x2, unlimited = 0", SettingsStore.card_time_mult(SettingsStore.CARD_TIME_LONG) == 2.0 \
		and SettingsStore.card_time_mult(SettingsStore.CARD_TIME_UNLIMITED) == 0.0 and SettingsStore.card_time_mult("bogus") == 1.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
