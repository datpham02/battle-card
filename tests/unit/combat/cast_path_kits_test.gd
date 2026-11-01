extends SceneTree
## TD-015 (Story 018 / 021 / 028 / 030 / 037): the character passives (second_wind, wide_caster,
## quick_blade, hunter_mark, prayer) and signatures (tram, thien_hoa, anh_bo, vay_bat, thanh_an) apply
## through the REAL piece cast path - bag slot -> select_piece -> aim_at_cell -> confirm_placement (card
## menu opens) -> [second piece: select / aim / confirm while the menu is open = the Story 028 JOIN] ->
## CutFlow.choose(card) -> CombatView._on_skill_chosen -> swing -> SwingArbiter resolves - and never
## only through _begin_cut. A joined cast counts its UNION cells (wide_caster, quick_blade, Anh Bo, Tram,
## the formation charge) and is ONE hit (Thanh An adds one Han, not one per piece).
## Headless (HoldSlotsView + CombatView + CutHudView, time frozen; nothing ticks unless the test does).
## Numbers come from characters.json / cards.json / combat.json at run time (never hard-coded).
## Test seams (as in join_flow_test): the featured shape is switched off (combat._featured = {}), the
## deck is replaced by copies of the card under test (combat._deck), drops on the player half blocked.
## Prints PASS/FAIL lines and FAILS=n.

const BIG_HP: float = 1000000.0
const EPS: float = 0.001

var fails: int = 0
var _cc: CharacterConfig
var _lib: PieceLibrary
var _cfg: CombatConfig


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _near(a: float, b: float) -> bool:
	return absf(a - b) < EPS


func _initialize() -> void:
	_cc = CharacterConfig.load_from_file()
	_lib = PieceLibrary.load_from_file()
	_cfg = CombatConfig.load_from_file()
	await _test_quick_blade_and_anh_bo()
	await _test_wide_caster()
	await _test_thien_hoa()
	await _test_tram_charge_and_cells()
	await _test_second_wind()
	await _test_hunter_mark()
	await _test_vay_bat()
	await _test_thanh_an_and_prayer()
	await process_frame
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ fixtures

# A headless match for [param character] (HoldSlotsView + CombatView + CutHudView, time frozen), the
# boss parked on the middle of its half, inactive, featured shape off, player-half drops blocked.
func _match(character: Dictionary) -> Node:
	var holder := Node.new()
	var bag := HoldSlotsView.new()
	bag.name = "HoldSlotsView"
	holder.add_child(bag)
	var v := CombatView.new()
	v.name = "CombatView"
	v.match_params = {"character": character, "boss_max_hp": BIG_HP, "player_hp": -1.0}
	v.drops_seed = 7
	v.freeze_time = true
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
	v.get_state().set_enemy_cell(_boss_cell(v))
	return holder


func _cv(holder: Node) -> CombatView:
	return holder.get_node("CombatView") as CombatView


func _drop(holder: Node) -> void:
	root.remove_child(holder)
	holder.free()


func _boss_cell(v: CombatView) -> Vector2i:
	return Vector2i(v.get_grid().side_cols + 1, 1)


# Enemy-half cell at column offset [param dx] (0..2) and row [param y].
func _ec(v: CombatView, dx: int, y: int) -> Vector2i:
	return Vector2i(v.get_grid().side_cols + dx, y)


# Activates the signature the way play does once it is ready (ready flag set by the dev seam; the
# activation itself needs unfrozen time, re-frozen right after - no frame runs in between).
func _activate(v: CombatView) -> bool:
	v.debug_set_signature_charge(1.0)
	v.freeze_time = false
	var ok: bool = v.activate_signature()
	v.freeze_time = true
	return ok


# The real cast: puts [param pieces] ([shape_id, anchor cell] each) into bag slots 0.., places the first
# (menu opens), joins the rest while the menu is open, chooses [param card] and resolves the swing.
# Returns {result, cells (menu cells), swing_cells, duration, pieces}; {} when a step was refused.
func _piece_cast(v: CombatView, pieces: Array, card: String = "kiem_khi") -> Dictionary:
	var hold: HoldSlots = v.get_hold()
	if v.get_cut_flow().is_menu_open() or v.is_placing():
		v.cancel_placement()
		v.cancel_placement()
	for i: int in hold.get_slot_count():
		hold.remove(i)
	for i: int in pieces.size():
		var p := FieldPoint.new()
		p.uid = -100 - i
		p.freshness_left = 0.0
		p.piece = _lib.make_piece(str(pieces[i][0]), 0)
		p.label = str(pieces[i][0])
		hold.place(p, i)
	v._deck = Deck.from_array([card, card, card, card], 1)
	v.get_skill_cooldowns().clear(card)
	for i: int in pieces.size():
		var ok: bool = v.select_piece(i, false) and v.aim_at_cell(pieces[i][1] as Vector2i) and v.confirm_placement()
		if not ok:
			_check("piece %d (%s) placed through the cast path" % [i, str(pieces[i][0])], false, str(pieces[i]))
			v.cancel_placement()
			v.cancel_placement()
			return {}
	var plan: CastPlan = v.get_cast_plan()
	var piece_count: int = plan.piece_count()
	var cells: Array[Vector2i] = v.get_cut_flow().get_cells()
	var got: Array[Dictionary] = [{}]
	var cb: Callable = func(side: int, result: Dictionary) -> void:
		if side == CombatState.Side.PLAYER:
			got[0] = result
	v.get_arbiter().swing_resolved.connect(cb)
	if not v.get_cut_flow().choose(card):
		v.get_arbiter().swing_resolved.disconnect(cb)
		_check("card %s chosen from the menu" % card, false, "hand=%s cells=%d" % [str(v.get_cut_flow().get_hand()), cells.size()])
		v.cancel_placement()
		return {}
	var actor: CutActor = v.get_cut_actor()
	var duration: float = actor.get_duration()
	var swing_cells: Array[Vector2i] = actor.get_cells()
	v.get_arbiter().tick(actor.get_time_left() + 0.01)
	v.get_arbiter().swing_resolved.disconnect(cb)
	return {"result": got[0], "cells": cells, "swing_cells": swing_cells, "duration": duration, "pieces": piece_count}


func _dmg(r: Dictionary) -> float:
	if r.is_empty():
		return -1.0
	return float((r["result"] as Dictionary).get("damage", -1.0))


func _hit(r: Dictionary) -> bool:
	return not r.is_empty() and bool((r["result"] as Dictionary).get("hit", false))


func _n(r: Dictionary) -> int:
	return -1 if r.is_empty() else (r["cells"] as Array).size()


func _per_cell(v: CombatView, skill: String = "kiem_khi") -> float:
	return float(v.get_skill_config().resolved(skill, v.get_card_level(skill))["damage_per_cell"])


# Shapes used (rotation 0): bar3 across row 1 (3 cells, boss inside), bar2 under its left end (the 3x2
# block of join_flow_test), bar2 on the boss, single monos.
func _bar3_boss(v: CombatView) -> Array:
	return ["bar3", _boss_cell(v)]


func _bar2_low(v: CombatView) -> Array:
	return ["bar2", _ec(v, 0, 2)]


func _bar2_boss(v: CombatView) -> Array:
	return ["bar2", _boss_cell(v)]


# ------------------------------------------------------------------ quick_blade + anh_bo (sat_thu)

func _test_quick_blade_and_anh_bo() -> void:
	var ch: Dictionary = _cc.get_character("sat_thu")
	var quick: float = float(ch["passive"]["params"]["damage_mult"])
	var max_cells: int = int(ch["passive"]["params"]["max_cells"])
	var small: float = float(ch["signature"]["params"]["small_mult"])
	var small_cells: int = int(ch["signature"]["params"]["small_cells"])
	var h: Node = await _match(ch)
	var v: CombatView = _cv(h)
	var per: float = _per_cell(v)
	_check("sat_thu: passive quick_blade, signature anh_bo", v.get_passive() != null and v.get_passive().get_id() == "quick_blade" and v.get_signature().get_id() == "anh_bo")
	# Inactive Anh Bo: Quick Blade only, on the cast's cell count.
	var r: Dictionary = _piece_cast(v, [_bar3_boss(v)])
	var q3: float = quick if 3 <= max_cells else 1.0
	_check("quick_blade: single bar3 cast (3 cells) hits for per x 3 x quick", _hit(r) and _n(r) == 3 and r["pieces"] == 1 and _near(_dmg(r), per * 3.0 * q3), "%.3f vs %.3f" % [_dmg(r), per * 3.0 * q3])
	r = _piece_cast(v, [_bar2_boss(v), _bar2_low(v)])
	var q4: float = quick if 4 <= max_cells else 1.0
	_check("quick_blade: JOINED bar2+bar2 counts the 4-cell union (x quick only if 4 <= max_cells %d)" % max_cells, _hit(r) and r["pieces"] == 2 and _n(r) == 4 and _near(_dmg(r), per * 4.0 * q4), "%.3f vs %.3f" % [_dmg(r), per * 4.0 * q4])
	r = _piece_cast(v, [_bar3_boss(v), _bar2_low(v)])
	var q5: float = quick if 5 <= max_cells else 1.0
	_check("quick_blade: JOINED bar3+bar2 = 5-cell union, no quick past max_cells", _hit(r) and r["pieces"] == 2 and _n(r) == 5 and _near(_dmg(r), per * 5.0 * q5), "%.3f vs %.3f" % [_dmg(r), per * 5.0 * q5])
	# Active Anh Bo.
	_check("anh_bo: activated", _activate(v) and v.is_signature_active())
	r = _piece_cast(v, [_bar3_boss(v)])
	var s3: float = small if 3 <= small_cells else 1.0
	_check("anh_bo active: single bar3 cast x small_mult x quick", _hit(r) and _near(_dmg(r), per * 3.0 * q3 * s3), "%.3f vs %.3f" % [_dmg(r), per * 3.0 * q3 * s3])
	r = _piece_cast(v, [_bar2_boss(v), ["mono", _ec(v, 0, 0)]])
	_check("anh_bo active: JOINED bar2+mono (3-cell union) x small_mult x quick", _hit(r) and r["pieces"] == 2 and _n(r) == 3 and _near(_dmg(r), per * 3.0 * q3 * s3), "%.3f vs %.3f" % [_dmg(r), per * 3.0 * q3 * s3])
	r = _piece_cast(v, [_bar2_boss(v), _bar2_low(v)])
	var s4: float = small if 4 <= small_cells else 1.0
	_check("anh_bo active: JOINED bar2+bar2 (4-cell union) is NOT small (two small pieces do not count apart)", _hit(r) and _n(r) == 4 and _near(_dmg(r), per * 4.0 * q4 * s4), "%.3f vs %.3f" % [_dmg(r), per * 4.0 * q4 * s4])
	r = _piece_cast(v, [_bar3_boss(v), _bar2_low(v)])
	_check("anh_bo active: JOINED 5-cell union = no small_mult, no quick", _hit(r) and _near(_dmg(r), per * 5.0 * q5), "%.3f vs %.3f" % [_dmg(r), per * 5.0 * q5])
	_drop(h)


# ------------------------------------------------------------------ wide_caster (phap_su)

func _test_wide_caster() -> void:
	var ch: Dictionary = _cc.get_character("phap_su")
	var min_cells: int = int(ch["passive"]["params"]["min_cells"])
	var mult: float = float(ch["passive"]["params"]["duration_mult"])
	var plain_ch: Dictionary = ch.duplicate(true)
	plain_ch.erase("passive")
	var h: Node = await _match(ch)
	var v: CombatView = _cv(h)
	var hb: Node = await _match(plain_ch)
	var b: CombatView = _cv(hb)
	_check("phap_su: passive wide_caster (baseline view has none)", v.get_passive() != null and v.get_passive().get_id() == "wide_caster" and b.get_passive() == null)
	var cases: Array = [
		["single bar3 (3 cells)", [_bar3_boss(v)], 3],
		["JOINED bar2+bar2 (4-cell union, each piece 2)", [_bar2_boss(v), _bar2_low(v)], 4],
		["JOINED bar3+bar2 (5-cell union)", [_bar3_boss(v), _bar2_low(v)], 5],
	]
	for c: Array in cases:
		var r: Dictionary = _piece_cast(v, c[1] as Array)
		var base: Dictionary = _piece_cast(b, c[1] as Array)
		var n: int = int(c[2])
		var want: float = (mult if n >= min_cells else 1.0)
		var ok: bool = not r.is_empty() and not base.is_empty() and _n(r) == n and _n(base) == n \
				and float(base["duration"]) > 0.0 and _near(float(r["duration"]), float(base["duration"]) * want)
		_check("wide_caster: %s swing duration = base x %.2f (min_cells %d)" % [str(c[0]), want, min_cells], ok,
			"" if r.is_empty() or base.is_empty() else "%.3f vs base %.3f" % [float(r["duration"]), float(base["duration"])])
	_drop(hb)
	_drop(h)


# ------------------------------------------------------------------ thien_hoa (phap_su)

func _test_thien_hoa() -> void:
	var h: Node = await _match(_cc.get_character("phap_su"))
	var v: CombatView = _cv(h)
	var status: StatusEffects = v.get_status()
	var r: Dictionary = _piece_cast(v, [_bar3_boss(v), _bar2_low(v)])
	var union: Array[Vector2i] = [] if r.is_empty() else (r["cells"] as Array[Vector2i])
	_check("thien_hoa: a JOINED 5-cell cast lights exactly its union on the formation map", _n(r) == 5 and v.get_formation().lit_count() == 5, "lit=%d" % v.get_formation().lit_count())
	_check("thien_hoa: activated", _activate(v))
	var sig := v.get_signature() as ThienHoaSignature
	_check("thien_hoa: ignites the 5 cells the joined cast lit", sig != null and sig.last_ignited_count() == 5, "" if sig == null else str(sig.last_ignited_count()))
	var exact: bool = true
	for cell: Vector2i in v.get_grid().enemy_cells():
		exact = exact and (status.is_burning(cell) == union.has(cell))
	_check("thien_hoa: burning enemy cells == the joined union (others untouched)", exact and not union.is_empty(), str(status.burning_cells()))
	_drop(h)


# ------------------------------------------------------------------ tram (kiem_si): charge + cells

func _test_tram_charge_and_cells() -> void:
	var ch: Dictionary = _cc.get_character("kiem_si")
	var cell_mult: float = float(ch["signature"]["params"]["cell_mult"])
	var lifesteal: float = float(ch["signature"]["params"]["lifesteal"])
	var h: Node = await _match(ch)
	var v: CombatView = _cv(h)
	var state: CombatState = v.get_state()
	var per: float = _per_cell(v)
	var total: int = v.get_formation().total()
	_check("test board: enemy half is 3x3", total == 9 and v.get_grid().side_cols == 3, str(total))
	_check("tram: charge 0 at start", v.get_signature_charge() == 0.0)
	var r: Dictionary = _piece_cast(v, [_bar3_boss(v), ["bar3", _ec(v, 1, 0)]])
	_check("tram charge: a JOINED bar3+bar3 cast (6 cells) charges 6/total", r.get("pieces", 0) == 2 and _n(r) == 6 and _near(v.get_signature_charge(), 6.0 / float(total)) and not v.is_signature_ready(), "charge=%.3f" % v.get_signature_charge())
	r = _piece_cast(v, [["bar3", _ec(v, 1, 2)]])
	_check("tram charge: a single bar3 on the last row completes the map -> ready", _n(r) == 3 and v.is_signature_ready() and v.get_signature_charge() == 1.0, "charge=%.3f" % v.get_signature_charge())
	v.freeze_time = false
	var activated: bool = v.activate_signature()
	v.freeze_time = true
	_check("tram: activated from the charge built by real casts", activated and v.is_signature_active())
	state.set_player_hp(50.0)
	var before: float = state.enemy_hp
	r = _piece_cast(v, [_bar3_boss(v), _bar2_low(v)])
	var counted: float = roundf(5.0 * cell_mult)
	_check("tram: JOINED 5-cell union counts as round(5 x cell_mult) cells", _hit(r) and _near(_dmg(r), per * counted), "%.3f vs %.3f" % [_dmg(r), per * counted])
	_check("tram: the joined swing still covers its 5 union cells", not r.is_empty() and (r["swing_cells"] as Array).size() == 5)
	_check("tram: boss took that damage", _near(before - state.enemy_hp, per * counted))
	_check("tram: lifesteal heals lifesteal x damage", _near(state.player_hp, 50.0 + lifesteal * per * counted), str(state.player_hp))
	r = _piece_cast(v, [_bar3_boss(v)])
	_check("tram: single bar3 cast counts as round(3 x cell_mult)", _hit(r) and _near(_dmg(r), per * roundf(3.0 * cell_mult)), "%.3f" % _dmg(r))
	_drop(h)


# ------------------------------------------------------------------ second_wind (kiem_si)

func _test_second_wind() -> void:
	var ch: Dictionary = _cc.get_character("kiem_si")
	var heal: float = float(ch["passive"]["params"]["heal_after_match"])
	var h: Node = await _match(ch)
	var v: CombatView = _cv(h)
	var state: CombatState = v.get_state()
	var ended: Array = []
	v.match_ended.connect(func(won: bool, _hp: float) -> void: ended.append(won))
	state.enemy_hp = 1.0
	var r: Dictionary = _piece_cast(v, [_bar3_boss(v), _bar2_low(v)])
	_check("second_wind: a JOINED cast kills the boss", _hit(r) and state.is_enemy_dead())
	_check("second_wind: no heal before the match ends", v.get_passive_heal() == 0.0)
	v._tick_end(10.0)
	_check("second_wind: match_ended(won) after the kill by a real cast", ended == [true], str(ended))
	_check("second_wind: passive heal = heal_after_match", _near(v.get_passive_heal(), heal), "%.2f vs %.2f" % [v.get_passive_heal(), heal])
	_drop(h)


# ------------------------------------------------------------------ hunter_mark (tho_san)

func _test_hunter_mark() -> void:
	var ch: Dictionary = _cc.get_character("tho_san")
	var stacks: int = int(ch["passive"]["params"]["fragile_stacks"])
	# Quick spec 2026-10-31: the mark comes from THORNS laid beside the boss (Walls left the player's kit).
	var h: Node = await _match(ch)
	var v: CombatView = _cv(h)
	# tran_gai needs 3 cells: one mono alone keeps it locked; the join unlocks it.
	var hold: HoldSlots = v.get_hold()
	var p := FieldPoint.new()
	p.uid = -300
	p.freshness_left = 0.0
	p.piece = _lib.make_piece("mono", 0)
	p.label = "mono"
	hold.place(p, 0)
	v._deck = Deck.from_array(["tran_gai", "tran_gai", "tran_gai", "tran_gai"], 1)
	var opened: bool = v.select_piece(0, false) and v.aim_at_cell(_ec(v, 2, 2)) and v.confirm_placement()
	_check("hunter_mark: a single mono cannot choose tran_gai (min_cells 3)", opened and not v.get_cut_flow().choose("tran_gai") and v.get_cut_flow().is_menu_open())
	v.cancel_placement()
	var r: Dictionary = _piece_cast(v, [_bar2_low(v), ["mono", _ec(v, 2, 0)]], "tran_gai")
	_check("hunter_mark: JOINED bar2+mono tran_gai (one cell beside the boss) lays 3 thorns", r.get("pieces", 0) == 2 and v.get_status().thorn_cells(CombatState.Side.ENEMY).size() == 3, str(v.get_status().thorn_cells(CombatState.Side.ENEMY)))
	_check("hunter_mark: thorns laid beside the boss give fragile_stacks Ran", v.get_fragile_stacks() == stacks, "%d vs %d" % [v.get_fragile_stacks(), stacks])
	_drop(h)


# ------------------------------------------------------------------ vay_bat (tho_san)

func _test_vay_bat() -> void:
	var ch: Dictionary = _cc.get_character("tho_san")
	var zone_mult: float = float(ch["signature"]["params"]["zone_sec_mult"])
	var fragile_mult: float = float(ch["signature"]["params"]["fragile_mult"])
	var h: Node = await _match(ch)
	var v: CombatView = _cv(h)
	var status: StatusEffects = v.get_status()
	var enemy: int = CombatState.Side.ENEMY
	# Quick spec 2026-10-31: Vay Bat stretches THORNS x zone_sec_mult and lays extra_thorn_cells more (no Wall part).
	var extra: int = int(ch["signature"]["params"]["extra_thorn_cells"])
	var r: Dictionary = _piece_cast(v, [_bar2_low(v), ["mono", _ec(v, 2, 0)]], "tran_gai")
	var thorned: Array[Vector2i] = status.thorn_cells(enemy)
	var base_sec: float = 0.0 if thorned.is_empty() else status.thorn_total_sec(enemy, thorned[0])
	_check("vay_bat inactive: joined tran_gai lays exactly its 3 cells", r.get("pieces", 0) == 2 and thorned.size() == 3 and base_sec > 0.0, str(thorned))
	status.clear_zones()
	_check("vay_bat: activated", _activate(v) and v.is_signature_active())
	r = _piece_cast(v, [_bar2_low(v), ["mono", _ec(v, 2, 0)]], "tran_gai")
	thorned = status.thorn_cells(enemy)
	var all_long: bool = thorned.size() == 3 + extra
	for cell: Vector2i in thorned:
		all_long = all_long and _near(status.thorn_total_sec(enemy, cell), base_sec * zone_mult)
	_check("vay_bat active: joined tran_gai lays 3 + extra_thorn_cells thorns, all x zone_sec_mult", extra == 1 and r.get("pieces", 0) == 2 and all_long, str(thorned))
	status.clear_zones()
	status.apply_fragile(enemy, 1)
	var per: float = _per_cell(v)
	r = _piece_cast(v, [_bar2_boss(v), ["mono", _ec(v, 0, 0)]])
	_check("vay_bat active: a JOINED 3-cell hit on a Ran'd boss deals x fragile_mult", _hit(r) and _n(r) == 3 and _near(_dmg(r), per * 3.0 * fragile_mult), "%.3f vs %.3f" % [_dmg(r), per * 3.0 * fragile_mult])
	_drop(h)


# ------------------------------------------------------------------ thanh_an + prayer (giao_si)

func _test_thanh_an_and_prayer() -> void:
	var ch: Dictionary = _cc.get_character("giao_si")
	var extra: int = int(ch["signature"]["params"]["extra_frost_stacks"])
	var burst_mult: float = float(ch["signature"]["params"]["burst_mult"])
	var heal: float = float(ch["passive"]["params"]["heal_per_burst"])
	var to_burst: int = _cfg.frost_stacks_to_burst
	var h: Node = await _match(ch)
	var v: CombatView = _cv(h)
	var status: StatusEffects = v.get_status()
	var state: CombatState = v.get_state()
	var enemy: int = CombatState.Side.ENEMY
	_check("giao_si: passive prayer, signature thanh_an", v.get_passive() != null and v.get_passive().get_id() == "prayer" and v.get_signature().get_id() == "thanh_an")
	_check("test data: extra Han per hit divides the burst threshold", extra > 0 and to_burst % extra == 0 and to_burst / extra >= 2, "extra=%d to_burst=%d" % [extra, to_burst])
	var r: Dictionary = _piece_cast(v, [_bar2_boss(v), ["mono", _ec(v, 0, 0)]])
	_check("thanh_an inactive: a joined hit adds no Han", _hit(r) and status.frost_stacks(enemy) == 0)
	_check("thanh_an: activated", _activate(v) and v.is_signature_active())
	state.set_player_hp(50.0)
	r = _piece_cast(v, [_bar2_boss(v), ["mono", _ec(v, 0, 0)]])
	_check("thanh_an active: a JOINED 2-piece hit is ONE hit -> extra Han once (not per piece)", _hit(r) and r["pieces"] == 2 and status.frost_stacks(enemy) == extra, str(status.frost_stacks(enemy)))
	@warning_ignore("integer_division")
	var hits_needed: int = to_burst / extra
	for _i: int in hits_needed - 2:
		_piece_cast(v, [_bar3_boss(v)])
	_check("thanh_an: one hit short of the burst", status.frost_stacks(enemy) == to_burst - extra, str(status.frost_stacks(enemy)))
	var before: float = state.enemy_hp
	r = _piece_cast(v, [_bar3_boss(v)])
	var hit_only: float = _dmg(r)
	var burst: float = _cfg.frost_burst_damage * burst_mult
	_check("thanh_an: the burst through a real cast is x burst_mult", _hit(r) and _near(before - state.enemy_hp, hit_only + burst), "dealt %.3f hit %.3f burst %.3f" % [before - state.enemy_hp, hit_only, burst])
	_check("thanh_an: stacks reset, burst counted", status.frost_stacks(enemy) == 0 and int(v.get_match_stats()["frost_bursts"]) == 1)
	_check("prayer: the burst heals heal_per_burst", _near(state.player_hp, 50.0 + heal), "%.2f vs %.2f" % [state.player_hp, 50.0 + heal])
	_drop(h)
