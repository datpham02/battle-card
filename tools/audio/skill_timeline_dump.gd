extends SceneTree
## Dumps the REAL audio event timeline of one skill cast (docs/skill-v2/10-audio-system-design.md §4-§5) to JSON, for
## tools/audio/skill_audition.py. Same path as tests/unit/audio/combat_audio_sync_test.gd: cards.json, a CastContext
## from a real piece, the SwingArbiter clock, CutActor with the game's channel_extend / cast_time hooks, the swing
## length the game uses (duration_override -1, as CombatView and the tram_live demo), a CombatAudioBridge and a silent
## AudioDirector advanced frame by frame. Read-only: no gameplay value is changed; nothing is written but the JSON.
##
## Output: every director log entry (play / merge / drop with clock, at, step, tier, cells), each voice's start and
## end (loops end when the bridge stops them), the scheduled events and the impact log.
## Run: godot --headless --path . -s res://tools/audio/skill_timeline_dump.gd -- --skill=ngan_kiem --shape=t4
##      [--rot=0] [--boss=5,1] [--sec=4] [--cancel-at=0.3] [--out=res://production/qa/evidence/skill-audio/x.json]

const HERO := Vector2i(1, 1)
const STEP: float = 1.0 / 60.0


func _arg(name: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return fallback


func _initialize() -> void:
	var skill_id: String = _arg("skill", "ngan_kiem")
	var shape: String = _arg("shape", "bar4")
	var rot: int = _arg("rot", "0").to_int()
	var bp: PackedStringArray = _arg("boss", "5,1").split(",")
	var boss := Vector2i(bp[0].to_int(), bp[1].to_int())
	var sec: float = _arg("sec", "4").to_float()
	var cancel_at: float = _arg("cancel-at", "-1").to_float()
	var out_path: String = _arg("out", "res://production/qa/evidence/skill-audio/%s_%s_timeline.json" % [skill_id, shape])

	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, HERO, boss)
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	player.channel_extend_fn = func(id: String) -> float: return float(sc.get_skill(id).get("channel_extend_sec", 0.0))
	player.cast_time_fn = func(id: String) -> float: return float(sc.get_skill(id).get("cast_time_sec", -1.0))
	var enemy := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, player, enemy, cc, sc, fx)
	var director := AudioDirector.silent()
	director.lead_override = 0.0 # audition: bodies land exactly on the event time
	var bridge := CombatAudioBridge.new(director)
	bridge.attach({"arbiter": arb, "player_actor": player, "enemy_actor": enemy, "state": state, "skills": sc, "status": fx})

	var impacts: Array = []
	arb.impact_resolved.connect(func(side: int, ev: Dictionary, hit: bool) -> void:
		impacts.append({"side": side, "kind": ev["kind"], "mult": ev["mult"], "cells": str(ev["cells"]), "clock": arb.clock(), "hit": hit}))
	var sched: Array = []
	arb.cast_scheduled.connect(func(_side: int, c: Dictionary) -> void:
		var evs: Array = []
		for e: Dictionary in c.get("events", []):
			evs.append({"at": e.get("at"), "kind": e.get("kind"), "step": e.get("step", e.get("index")), "cells": str(e.get("cells"))})
		sched.append({"clock": arb.clock(), "events": evs}))

	# --pieces=shape:rot@x,y;shape:rot@x,y places several pieces (a combined cast); else one piece over the boss,
	# inside the enemy half (cols 4..7, rows 0..2)
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var pieces: Array[Piece] = []
	var piece_cells: Array = []
	var cells: Array[Vector2i] = []
	var spec: String = _arg("pieces", "")
	if not spec.is_empty():
		for part: String in spec.split(";"):
			var sr: PackedStringArray = part.split("@")
			var sh: PackedStringArray = sr[0].split(":")
			var at: PackedStringArray = sr[1].split(",")
			var p: Piece = lib.make_piece(sh[0], sh[1].to_int() if sh.size() > 1 else 0)
			var pc: Array[Vector2i] = p.cells_at(Vector2i(at[0].to_int(), at[1].to_int()))
			pieces.append(p)
			piece_cells.append(pc)
			for c: Vector2i in pc:
				if not cells.has(c):
					cells.append(c)
		shape = spec.replace(";", "+").replace(":", "r").replace("@", "_").replace(",", "-")
	else:
		var piece: Piece = lib.make_piece(shape, rot)
		for x: int in range(0, 8):
			for y: int in range(-2, 3):
				var c: Array[Vector2i] = piece.cells_at(Vector2i(x, y))
				if c.all(func(v: Vector2i) -> bool: return grid.is_enemy_cell(v)) and c.has(boss):
					cells = c
					break
			if not cells.is_empty():
				break
		pieces.append(piece)
		piece_cells.append(cells)
	if cells.is_empty():
		push_error("no placement of %s over %s" % [shape, boss])
		quit(1)
		return
	if _arg("out", "").is_empty():
		out_path = "res://production/qa/evidence/skill-audio/%s_%s_timeline.json" % [skill_id, _arg("name", shape)]
	var ctx: Dictionary = CastContext.build(skill_id, 1, pieces, piece_cells, sc.get_skill(skill_id)["delivery"], false,
		CombatState.Side.PLAYER, HERO, {"cast_mode": "direct"})
	var started: bool = player.begin_swing(cells, skill_id, true, 1, -1.0, {}, ctx)
	var swing_start: float = arb.clock()

	# frame loop like the game; track voice lifetimes (loops end when the bridge stops them)
	var live: Dictionary = {}
	var spans: Array = []
	var t: float = 0.0
	var cancelled: bool = false
	while t < sec - 0.000001:
		if cancel_at >= 0.0 and not cancelled and t >= cancel_at:
			player.cancel()
			cancelled = true
		arb.tick(STEP)
		fx.tick(STEP, state)
		director.advance(STEP)
		t += STEP
		var now: Dictionary = {}
		for v: Dictionary in director.get_pool().voices():
			now[int(v["handle"])] = v
			if not live.has(int(v["handle"])):
				live[int(v["handle"])] = {"id": v["id"], "start": arb.clock(), "tier": v.get("tier", ""), "loop": v.get("loop", false)}
		for h: int in live.keys():
			if not now.has(h):
				var s: Dictionary = live[h]
				s["end"] = arb.clock()
				spans.append(s)
				live.erase(h)
	for h: int in live.keys():
		var s: Dictionary = live[h]
		s["end"] = -1.0
		spans.append(s)

	var log: Array = []
	for e: Dictionary in director.play_log:
		var row: Dictionary = {}
		for k: String in e.keys():
			row[k] = e[k] if (e[k] is float or e[k] is int or e[k] is String or e[k] is bool) else str(e[k])
		log.append(row)
	var skill: Dictionary = sc.get_skill(skill_id)
	var doc: Dictionary = {
		"skill": skill_id, "shape": shape, "rot": rot, "cells": str(cells), "boss": str(boss), "swing_started": started,
		"swing_start_clock": swing_start, "frame_sec": STEP, "cancel_at": cancel_at,
		"card_timing": {"channel_extend_sec": skill.get("channel_extend_sec"), "commit_lock_sec": skill.get("commit_lock_sec"),
			"sky_hover_sec": skill.get("sky_hover_sec"), "sky_stagger_sec": skill.get("sky_stagger_sec"), "drop_order": skill.get("drop_order"),
			"cast_time_sec": skill.get("cast_time_sec")},
		"scheduled": sched, "impacts": impacts, "log": log, "voices": spans}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path).get_base_dir())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  "))
	f.close()
	print("timeline: %s  cells %s  %d log rows, %d voices, %d impacts" % [out_path, str(cells), log.size(), spans.size(), impacts.size()])
	bridge.detach()
	bridge.free()
	director.free()
	quit(0)
