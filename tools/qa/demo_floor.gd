extends SceneTree
## Demo driver: one hero plays a whole floor, for a --write-movie recording. A tool, not a test.
## Run (windowed, muted, frame-locked):
##   godot --path . --audio-driver Dummy --fixed-fps 30 --write-movie out.avi \
##     -s res://tools/qa/demo_floor.gd -- <hero> <seed> --no-autopause
## Prints one STEP line per phase change and one RESULT line. Never asserts: a demo, not a gate.

const FPS: float = 30.0
const MAX_SEC: float = 1500.0
const BATTLE_MAX_SEC: float = 150.0

var _flow: GameFlow
var _rng := RandomNumberGenerator.new()
var _lib: PieceLibrary
var _t: float = 0.0
var _log: Array[String] = []


func _initialize() -> void:
	_run()


func _wait(sec: float) -> void:
	var n: int = int(sec * FPS)
	for _i: int in n:
		_t += 1.0 / FPS
		await process_frame


func _say(s: String) -> void:
	_log.append(s)
	print("STEP t=%.1f %s" % [_t, s])


func _phase_name(p: int) -> String:
	var names := ["TITLE", "CHARACTER_SELECT", "WORLD_MAP", "IN_NODE", "MAP", "REST", "SHOP",
		"EVENT", "PIECE_DECK", "FATE", "ENDING", "ACHIEVEMENTS", "SETTINGS", "SAVE_SLOTS", "FORGE"]
	return names[p] if p >= 0 and p < names.size() else str(p)


## One battle, played through the same CombatView API the touch input uses (modelled on
## tools/qa/play_bot.gd). Returns when either unit dies or BATTLE_MAX_SEC passes.
func _play_battle(view: CombatView) -> void:
	var st: CombatState = view.get_state()
	view.set_card_time(SettingsStore.CARD_TIME_NORMAL)
	var t0: float = _t
	var next_step: float = 0.0
	var next_place: float = 0.0
	var picked: int = 0
	var dodges: int = 0
	var cards: int = 0
	while _t - t0 < BATTLE_MAX_SEC and not st.is_player_dead() and not st.is_enemy_dead():
		await process_frame
		_t += 1.0 / FPS
		if st.is_player_dead() or st.is_enemy_dead():
			break
		if view.is_casting() or view.get_cut_actor().is_swinging():
			continue
		var hold: HoldSlots = view.get_hold()

		# --- FIRST: get out of a telegraphed cell. The counterplay of every pattern enemy is to read
		# the warning and step off it; a bot that only walks to drops stands in the strike and dies.
		# The first recording lost the run at the column-3 danger node that way (hp 0/20).
		var pat: PatternController = view.get_pattern_controller()
		if pat != null and not view.is_movement_locked():
			# Dodge only when the strike is CLOSE. Dodging on every warning starved the attack: in the
			# smoke run battle 3 took 868 s and battle 4 timed out with the enemy on 116 hp, because
			# the bot stepped away on every telegraph and never got to place a piece. A real player
			# keeps working and leaves at the last moment.
			var hot: Array[Vector2i] = pat.threatened_cells()
			var imminent: bool = pat.is_threatening() and pat.strike_time_left() <= 1.4
			if imminent and hot.has(st.player_cell):
				if _t >= next_step:
					next_step = _t + 0.18
					for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						if hot.has(st.player_cell + d):
							continue
						if view.try_step_player(d):
							dodges += 1
							break
				continue

		# --- hands empty: WALK TO A DROP AND PICK IT UP.
		# The hero collects by stepping onto the cell (CombatView._try_pick_up_under_player); nothing
		# puts a piece in the hand for free. The first take of this demo fabricated a FieldPoint and
		# placed it straight into the hand - copied from play_bot.gd, which does that because it tests
		# the CAST RULES and needs to cast constantly. It is not how the game is played, and it showed:
		# a hero casting without ever collecting anything.
		if hold.get_piece(0) == null:
			if _t < next_step:
				continue
			next_step = _t + 0.22
			var pts: Array = view.get_drops().get_points()
			if pts.is_empty():
				continue                      # nothing on the board yet; drops keep spawning
			var here: Vector2i = st.player_cell
			var best: Vector2i = here
			var best_d: int = 1 << 30
			for pt: FieldPoint in pts:
				var d: int = absi(pt.cell.x - here.x) + absi(pt.cell.y - here.y)
				if d < best_d:
					best_d = d
					best = pt.cell
			if best == here:
				continue
			var dir := Vector2i.ZERO
			if best.x != here.x:
				dir = Vector2i(signi(best.x - here.x), 0)
			elif best.y != here.y:
				dir = Vector2i(0, signi(best.y - here.y))
			if dir != Vector2i.ZERO and not view.is_movement_locked():
				if view.try_step_player(dir):
					if view.get_hold().get_piece(0) != null:
						picked += 1
			continue

		# --- a piece in hand: aim it at the enemy, place it, let the cast clock fire the card
		if _t < next_place:
			continue
		var ok_sel: bool = view.select_piece(0, false)
		var ok_aim: bool = ok_sel and view.aim_at_cell(st.enemy_cell)
		for _r: int in 3:
			if ok_aim or not ok_sel:
				break
			view.rotate_piece()
			ok_aim = view.aim_at_cell(st.enemy_cell)
		if not (ok_aim and view.confirm_placement()):
			view.cancel_placement()
			next_place = _t + 0.4
			continue

		# --- placed: OPEN THE CARD MENU AND CHOOSE A CARD.
		# Letting the cast clock time out also casts, and that is what the first takes did - so the
		# video never showed the card menu at all, the step the player actually makes. The menu is
		# held on screen for a beat before choosing, because a menu that flashes is a menu nobody read.
		await _wait(0.45)
		if view.press_cast():
			await _wait(1.1)
			var flow: CutFlow = view.get_cut_flow()
			var card_id: String = ""
			for id: String in flow.get_hand():
				var av: Dictionary = SkillAvailability.check(
					view.get_skill_config(), view.get_skill_cooldowns(), id, flow.get_cells().size())
				if bool(av.get("available", false)):
					card_id = id
					break
			if card_id != "":
				cards += 1
				flow.choose(card_id)
			elif flow.is_menu_open():
				flow.tick_real(99.0)     # nothing castable: let the clock finish it
		next_place = _t + 1.2
	_say("  picked up %d pieces, dodged out of %d telegraphs, chose %d cards" % [picked, dodges, cards])


## Takes whatever offer is on screen. The chooser differs by reward kind, so try each and keep the
## one that moves the phase on - cheaper than guessing wrong and paying another recording run.
func _take_reward() -> bool:
	var ids: Array[String] = _flow.get_pending_reward()
	if ids.is_empty():
		return false
	var kind: String = _flow.get_pending_reward_kind()
	var pick: String = ids[0]
	_say("REWARD kind=%s offers=%s take=%s" % [kind, ids, pick])
	for fn: String in ["reward_chosen", "choose_relic", "choose_ink", "choose_fate", "choose_fate_relic"]:
		if not _flow.has_method(fn):
			continue
		_flow.call(fn, pick)
		await _wait(0.4)
		if _flow.get_pending_reward().is_empty():
			_say("REWARD taken by %s" % fn)
			return true
	# nothing took it: skip rather than spin on the same offer forever
	if _flow.has_method("reward_skipped"):
		_flow.reward_skipped()
		await _wait(0.4)
		if _flow.get_pending_reward().is_empty():
			_say("REWARD skipped")
			return true
	_say("REWARD stuck kind=%s" % kind)
	return false


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var hero: String = args[0] if args.size() > 0 else "kiem_si"
	_rng.seed = int(args[1]) if args.size() > 1 else 7
	_lib = PieceLibrary.load_from_file()

	var main: Node = (load("res://src/main.tscn") as PackedScene).instantiate()
	_flow = main.get_node("GameFlow") as GameFlow
	_flow.set_store_for_test(ProgressStore.memory_store())
	# Seed the RUN, not just the bot. Without this each attempt differs and a floor clear cannot be
	# reproduced for the recording: three attempts on "seed 7" reached column 5, column 3 and column 2.
	if _flow.has_method("set_seed_for_test"):
		_flow.set_seed_for_test(int(args[1]) if args.size() > 1 else 7)
	root.add_child(main)
	await process_frame
	_flow.set_character(hero)
	_say("hero=%s seed=%d" % [hero, _rng.seed])
	_flow.start_run()
	await _wait(2.5)

	var last_phase: int = -1
	var battles: int = 0
	var guard: int = 0
	while _t < MAX_SEC and guard < 600:
		guard += 1
		if _flow.get_run_result() != GameFlow.RunResult.NONE:
			_say("run result=%d - stopping" % _flow.get_run_result())
			await _wait(3.0)
			break
		var ph: int = _flow.get_phase()
		if ph != last_phase:
			_say("phase=%s col=%d" % [_phase_name(ph), _flow.get_current_column()])
			last_phase = ph
		if await _take_reward():
			continue
		match ph:
			GameFlow.Phase.WORLD_MAP:
				# the run starts on the world map; step into the first region so the floor begins
				var rid: String = "ch1"
				var cfg: ChaptersConfig = _flow.get_config()
				if cfg != null and cfg.has_method("region_ids"):
					var ids: Array = cfg.region_ids()
					if not ids.is_empty():
						rid = str(ids[0])
				_say("world map: enter region %s" % rid)
				await _wait(1.5)
				_flow.choose_region(rid)
				await _wait(1.5)
			GameFlow.Phase.MAP:
				var nodes: Array[Dictionary] = _flow.get_available_nodes()
				if nodes.is_empty():
					_say("map has no available node - floor done?")
					break
				# prefer a fight so the demo shows combat; otherwise take the first node
				# read every node in the column first, the way the map screen shows them
				var kinds: Array[String] = []
				for i: int in nodes.size():
					kinds.append(str(nodes[i].get("kind", "?")))
				_say("column offers %s" % str(kinds))
				var pick: int = _rng.randi_range(0, nodes.size() - 1)
				for i: int in nodes.size():
					var k: String = kinds[i]
					if k in ["boss", "miniboss"]:
						pick = i                      # the way on is the way on
						break
					if k in ["shop", "rest", "treasure"] and _rng.randf() < 0.6:
						pick = i                      # a player takes the safe node often, not always
						break
				_say("choose node %d kind=%s" % [pick, nodes[pick].get("kind", "?")])
				await _wait(1.2)          # let the viewer see the map before it moves on
				_flow.choose_node(pick)
				await _wait(1.0)
			GameFlow.Phase.IN_NODE:
				var rc: RunController = _flow.get_controller()
				if rc == null:
					await _wait(0.5)
					continue
				for _i: int in 600:
					if rc.get_state().get_phase() == RunState.Phase.PLAYING:
						break
					await process_frame
				var battle: Node = rc.get_battle()
				if battle == null:
					await _wait(0.5)
					continue
				var view := battle.get_node_or_null(RunController.COMBAT_VIEW_NODE) as CombatView
				if view == null:
					await _wait(0.5)
					continue
				if view.get_state().is_player_dead():
					_say("hero is dead - the run is over, stopping")
					await _wait(3.0)
					break
				battles += 1
				_say("battle %d begins" % battles)
				await _play_battle(view)
				_say("battle %d ends hp=%.0f/%.0f" % [battles, view.get_state().player_hp, view.get_state().enemy_hp])
				await _wait(3.0)          # victory beat, stinger, the hold before the map
			GameFlow.Phase.REST:
				_say("rest: heal")
				_flow.rest_heal_requested()
				await _wait(2.0)
			GameFlow.Phase.SHOP:
				# A player who walks into a shop and straight out again is not a player. Look at the
				# stock, buy what the purse allows, then leave.
				var shop: Dictionary = _flow.get_shop()
				await _wait(2.0)
				var bought: int = 0
				for kind: String in ["card", "relic", "ink", "service"]:
					var stock: Array = shop.get(kind + "s", shop.get(kind, []))
					if not (stock is Array):
						continue
					for entry: Variant in stock:
						var sid: String = str(entry.get("id", entry)) if entry is Dictionary else str(entry)
						var res: Dictionary = _flow.shop_buy(kind, sid)
						if bool(res.get("ok", false)):
							bought += 1
							_say("shop: bought %s %s (gold left %d)" % [kind, sid, _flow.get_gold()])
							await _wait(1.2)
							break
					if bought > 0:
						break
				if bought == 0:
					_say("shop: nothing affordable (gold %d, stock keys %s)" % [_flow.get_gold(), str(shop.keys())])
				await _wait(1.5)
				_flow.shop_leave()
				await _wait(1.0)
			GameFlow.Phase.EVENT:
				_say("event: first choice")
				await _wait(2.0)
				_flow.event_choose(0)
				await _wait(1.5)
			GameFlow.Phase.FATE:
				# Reaching the fate screen IS the end of the floor - the boss is down and the run is
				# offering the next step. The demo ends here. (Earlier this branch tried to pick a
				# fate from get_fate_view(); the key guess was wrong, it returned [] and the loop
				# reprinted "fate screen: []" for 790 s after the floor was already won.)
				_say("FLOOR CLEARED - the fate screen is up")
				await _wait(6.0)
				break
			GameFlow.Phase.ENDING:
				_say("ENDING reached")
				await _wait(4.0)
				break
			_:
				await _wait(0.5)

	_say("RESULT battles=%d phase=%s t=%.1f" % [battles, _phase_name(_flow.get_phase()), _t])
	quit(0)
