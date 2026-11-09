extends SceneTree
## The combat cues the audio bridge used to poll now come from signals
## (docs/skill-v2/10-audio-system-design.md §10): PatternController.stage_changed (WINDUP),
## CutFlow.menu_opened, CombatView.piece_selected / piece_placed / placement_confirmed.
## The bridge plays the same cues and does not poll. Run:
## godot --headless --path . -s res://tests/unit/audio/combat_cue_signals_test.gd

const Fx = preload("res://tests/unit/combat/pattern_fixtures.gd")
const STEP: float = 0.05
const BIG_HP: float = 1000000.0

var fails: int = 0
var _lib: PieceLibrary


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_lib = PieceLibrary.load_from_file()
	_test_windup_signal_plays_boss_windup()
	_test_menu_opened_plays_menu_cue()
	await _test_piece_signals()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _ids(director: AudioDirector) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in director.play_log:
		if e["op"] == "play":
			out.append(str(e["id"]))
	return out


func _test_windup_signal_plays_boss_windup() -> void:
	var skills: Dictionary = Fx.skills()
	var cfg: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({
		"skills": skills, "enemies": {"solo": {"ai": {"noise": 0.0}, "skills": ["fx_1"]}},
	})
	var w: Dictionary = Fx.world(BoardGrid.new(3, 3), cfg, "solo", 1)
	var ctrl: PatternController = w["ctrl"]
	var seen: Array[Dictionary] = []
	ctrl.stage_changed.connect(func(stage: int, skill_id: String) -> void:
		seen.append({"stage": stage, "skill_id": skill_id}))
	var director := AudioDirector.silent()
	var bridge := CombatAudioBridge.new(director)
	bridge.attach({"pattern": ctrl})
	var t: float = 0.0
	while t < 3.0 and ctrl.get_stage() != PatternController.Stage.WINDUP:
		ctrl.tick(STEP)
		t += STEP
	ck("pattern reaches WINDUP", ctrl.get_stage() == PatternController.Stage.WINDUP)
	var wind: Array = seen.filter(func(e: Dictionary) -> bool: return int(e["stage"]) == PatternController.Stage.WINDUP)
	ck("stage_changed fired WINDUP with the skill id", wind.size() == 1 and str(wind[0]["skill_id"]) == "fx_1", str(seen))
	ck("bridge played warn.boss.windup from the signal (no poll)", _ids(director).has("warn.boss.windup"), str(_ids(director)))
	bridge.detach()
	bridge.free()
	director.free()


func _test_menu_opened_plays_menu_cue() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var flow := CutFlow.new(sc, SkillCooldowns.new())
	var opened: Array = []
	flow.menu_opened.connect(func(cells: Array[Vector2i], hand: Array[String]) -> void:
		opened.append({"cells": cells.size(), "hand": hand}))
	var director := AudioDirector.silent()
	var bridge := CombatAudioBridge.new(director)
	bridge.attach({"cut_flow": flow, "skills": sc})
	var cells: Array[Vector2i] = [Vector2i(2, 1)]
	ck("menu opens", flow.open_menu(["mono"] as Array[String], cells, ["kiem_khi"] as Array[String]))
	ck("menu_opened fired once with the cells and the hand", opened.size() == 1 and int(opened[0]["cells"]) == 1
		and (opened[0]["hand"] as Array) == ["kiem_khi"])
	ck("bridge played the menu_open cue", _ids(director).has(director.get_bank().cue("menu_open")), str(_ids(director)))
	bridge.detach()
	bridge.free()
	director.free()


func _test_piece_signals() -> void:
	var holder := Node.new()
	var bag := HoldSlotsView.new()
	bag.name = "HoldSlotsView"
	holder.add_child(bag)
	var v := CombatView.new()
	v.name = "CombatView"
	v.match_params = {"boss_max_hp": BIG_HP}
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
	var hold: HoldSlots = v.get_hold()
	for i: int in hold.get_slot_count():
		hold.remove(i)
	var p := FieldPoint.new()
	p.uid = -100
	p.freshness_left = 0.0
	p.piece = _lib.make_piece("mono", 0)
	p.label = "mono"
	hold.place(p, 0)
	v._deck = Deck.from_array(["kiem_khi", "kiem_khi", "kiem_khi", "kiem_khi"], 1)
	var selected: Array[int] = []
	var placed: Array[int] = []
	var confirmed: Array[int] = []
	v.piece_selected.connect(func(slot: int) -> void: selected.append(slot))
	v.piece_placed.connect(func(slot: int, cells: Array[Vector2i]) -> void: placed.append(cells.size()))
	v.placement_confirmed.connect(func(cells: Array[Vector2i]) -> void: confirmed.append(cells.size()))
	var director := AudioDirector.silent()
	var bridge := CombatAudioBridge.new(director)
	bridge.attach({"view": v, "cut_flow": v.get_cut_flow(), "skills": v.get_skill_config()})
	var cell := Vector2i(v.get_grid().side_cols + 1, 1)
	ck("select + place the mono", v.select_piece(0, false) and v.aim_at_cell(cell) and v.confirm_placement())
	ck("piece_selected and piece_placed fired", selected == [0] and placed == [1], "sel %s placed %s" % [str(selected), str(placed)])
	ck("select plays block.select, place plays block.place", _ids(director).has("block.select") and _ids(director).has("block.place"),
		str(_ids(director)))
	ck("Tung phép confirms the cast", v.press_cast())
	ck("placement_confirmed fired with the cell", confirmed == [1], str(confirmed))
	ck("menu_opened played the menu cue", _ids(director).has(director.get_bank().cue("menu_open")))
	bridge.detach()
	bridge.free()
	director.free()
	root.remove_child(holder)
	holder.free()
