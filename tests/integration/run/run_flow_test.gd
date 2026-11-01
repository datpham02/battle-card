extends SceneTree

const CFG: String = "res://tests/fixtures/fast_run.json"

var fails: int = 0
var rc: RunController


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _wait_phase(phase: int, max_frames: int = 900) -> bool:
	for _i: int in max_frames:
		if rc.get_state().get_phase() == phase:
			return true
		await process_frame
	return false


func _view() -> CombatView:
	return rc.get_battle().get_node("CombatView") as CombatView


func _check_match(index: int, spec: Dictionary) -> void:
	_check("m%d PLAYING" % (index + 1), await _wait_phase(RunState.Phase.PLAYING))
	_check("m%d index" % (index + 1), rc.get_state().get_match_index() == index)
	var v: CombatView = _view()
	_check("m%d boss hp" % (index + 1), is_equal_approx(v.get_state().enemy_max_hp, float(spec["boss_max_hp"])))
	_check("m%d brain set" % (index + 1), v.get_boss().get_brain().get_set_name() == str(spec["brain_set"]), v.get_boss().get_brain().get_set_name())
	_check("m%d name" % (index + 1), v.get_boss_name() == TranslationServer.translate(str(spec["name_key"])), v.get_boss_name())


func _initialize() -> void:
	var main: Node = load("res://src/main.tscn").instantiate()
	var flow := main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	rc = flow.enter_test_floor(RunConfig.load_from_file(CFG))
	await process_frame
	var cfg: RunConfig = rc.get_config()
	_check("config 4", cfg.match_count() == 4)
	var prev_hp: float = -1.0
	for i: int in 4:
		await _check_match(i, cfg.matches[i])
		var v: CombatView = _view()
		if i == 0:
			_check("m1 full hp", is_equal_approx(v.get_player_hp(), v.get_state().player_max_hp))
			v.get_state().damage(CombatState.Side.PLAYER, 40.0)
		else:
			var want: float = minf(prev_hp + cfg.heal_between_matches, v.get_state().player_max_hp)
			_check("m%d carried hp %s" % [i + 1, want], is_equal_approx(v.get_player_hp(), want), str(v.get_player_hp()))
			v.get_state().damage(CombatState.Side.PLAYER, 10.0)
		prev_hp = v.get_player_hp()
		v.get_state().damage(CombatState.Side.ENEMY, 99999.0)
		var target: int = RunState.Phase.BETWEEN if i < 3 else RunState.Phase.WON
		_check("m%d -> %d" % [i + 1, target], await _wait_phase(target))
		_check("only one battle child", _battle_count(main) == 1)
		if i < 3:
			var old: Node = rc.get_battle()
			await _wait_phase(RunState.Phase.INTRO, 5)
			await _wait_phase(RunState.Phase.PLAYING)
			_check("new battle node", rc.get_battle() != old)
	_check("WON", rc.get_state().get_phase() == RunState.Phase.WON)
	# restart
	var old_battle: Node = rc.get_battle()
	rc.restart_requested()
	_check("restart idx0", rc.get_state().get_match_index() == 0 and rc.get_state().get_phase() == RunState.Phase.INTRO)
	_check("restart new battle", rc.get_battle() != old_battle)
	await _check_match(0, cfg.matches[0])
	var v2: CombatView = _view()
	_check("restart full hp", is_equal_approx(v2.get_player_hp(), v2.get_state().player_max_hp))
	_check("restart hand empty", v2.get_hold().get_occupied_count() == 0)
	_check("restart no burn", v2.get_status().burning_cells().is_empty())
	_check("restart boss hand empty", v2.get_boss().get_hand().get_occupied_count() == 0)
	_check("restart elapsed small", rc.get_state().get_elapsed_sec() < 1.0)
	var learn: BossLearning = v2.get_learning()
	_check("restart learning 0", learn.get_dodge_streak() == 0 and learn.get_interrupt_count() == 0)
	_check("one battle after restart", _battle_count(main) == 1)
	# lose
	v2.get_state().damage(CombatState.Side.PLAYER, 99999.0)
	_check("LOST", await _wait_phase(RunState.Phase.LOST))
	_check("lost battle frozen", rc.get_battle().process_mode == Node.PROCESS_MODE_DISABLED)
	rc.restart_requested()
	await _check_match(0, cfg.matches[0])
	_check("restart after loss full hp", is_equal_approx(_view().get_player_hp(), _view().get_state().player_max_hp))
	_check("one battle at end", _battle_count(main) == 1)
	print("FAILS=%d" % fails)
	quit(fails)


func _battle_count(main: Node) -> int:
	var n: int = 0
	for child: Node in rc.get_children():
		if child.name.begins_with("Battle") or child.get_node_or_null("CombatView") != null:
			n += 1
	return n
