extends SceneTree
## Every card's audio through the REAL path (docs/design/audio/unified-audio-identity.md, user 2026-11-13: "test all
## the sound in the game, every skill"). For each card of cards.json: a real piece of at least min_cells over the
## boss, CastContext, CutActor with the game's channel / cast-time hooks, the SwingArbiter clock, StatusEffects and a
## CombatAudioBridge + silent AudioDirector, 5 s of frames. Checks, per card:
## - the cast starts and plays at least one sound;
## - every played id is a known event with a file for its tier (no "unknown" drop);
## - no event repeats faster than its own cooldown allows (no spam), and at most 12 sounds per second in total.
## Prints one line per card (cues in order) so the result doubles as a listening checklist.
## Run: godot --headless --path . -s res://tests/unit/audio/all_skills_audio_test.gd

const HERO := Vector2i(1, 1)
const BOSS := Vector2i(5, 1)
const STEP: float = 1.0 / 60.0
const RUN_SEC: float = 5.0
const SHAPE_FOR_CELLS: Dictionary = {1: "mono", 2: "bar2", 3: "l3", 4: "t4", 5: "plus5"}
const MAX_PER_SEC: int = 12

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	var cards: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/cards.json"))["cards"]
	var silent: Array[String] = []
	var not_started: Array[String] = []
	var unknown: Array[String] = []
	var spam: Array[String] = []
	for id: String in cards.keys():
		var r: Dictionary = _cast(id, int(cards[id].get("min_cells", 1)))
		if not bool(r["started"]):
			not_started.append(id)
			print("CARD %-14s NOT STARTED (%s)" % [id, r["shape"]])
			continue
		print("CARD %-14s %-6s %s" % [id, r["shape"], ", ".join(r["ids"])])
		if (r["ids"] as Array).is_empty():
			silent.append(id)
		for u: String in r["unknown"]:
			unknown.append("%s:%s" % [id, u])
		if not str(r["spam"]).is_empty():
			spam.append("%s:%s" % [id, r["spam"]])
	ck("every card's cast starts on a fitting piece (%d cards)" % cards.size(), not_started.is_empty(), str(not_started))
	ck("every card plays at least one sound", silent.is_empty(), str(silent))
	ck("every played id is a known event with a file", unknown.is_empty(), str(unknown))
	ck("no sound spam (per-event cooldown respected, <= %d sounds / s)" % MAX_PER_SEC, spam.is_empty(), str(spam))
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _cast(id: String, min_cells: int) -> Dictionary:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, HERO, BOSS)
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	player.channel_extend_fn = func(k: String) -> float: return float(sc.get_skill(k).get("channel_extend_sec", 0.0))
	player.cast_time_fn = func(k: String) -> float: return float(sc.get_skill(k).get("cast_time_sec", -1.0))
	var enemy := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, player, enemy, cc, sc, fx)
	var director := AudioDirector.silent()
	director.lead_override = 0.0
	var bridge := CombatAudioBridge.new(director)
	bridge.attach({"arbiter": arb, "player_actor": player, "enemy_actor": enemy, "state": state, "skills": sc, "status": fx})
	var shape: String = str(SHAPE_FOR_CELLS.get(clampi(min_cells, 1, 5), "t4"))
	var piece: Piece = PieceLibrary.load_from_file().make_piece(shape, 0)
	var cells: Array[Vector2i] = []
	for x: int in range(0, 8):
		for y: int in range(-2, 3):
			var c: Array[Vector2i] = piece.cells_at(Vector2i(x, y))
			if c.all(func(v: Vector2i) -> bool: return grid.is_enemy_cell(v)) and c.has(BOSS):
				cells = c
				break
		if not cells.is_empty():
			break
	var started: bool = false
	if not cells.is_empty():
		var ctx: Dictionary = CastContext.build(id, 1, [piece] as Array[Piece], [cells], sc.get_skill(id)["delivery"], false,
			CombatState.Side.PLAYER, HERO, {"cast_mode": "direct"})
		started = player.begin_swing(cells, id, true, 1, -1.0, {}, ctx)
	var t: float = 0.0
	while started and t < RUN_SEC:
		arb.tick(STEP)
		fx.tick(STEP, state)
		director.advance(STEP)
		t += STEP
	var bank: AudioBank = director.get_bank()
	var ids: Array[String] = []
	var unknown: Array[String] = []
	var per_id: Dictionary = {}
	var times: Array[float] = []
	for e: Dictionary in director.play_log:
		var eid: String = str(e["id"])
		if e["op"] == "drop" and str(e.get("reason", "")) == "unknown":
			unknown.append(eid)
		if e["op"] != "play":
			continue
		ids.append(eid)
		times.append(float(e["local"]))
		if not bank.has_event(eid) or bank.files_for(eid, str(e.get("tier", "M"))).is_empty():
			unknown.append(eid)
		(per_id.get_or_add(eid, []) as Array).append(float(e["local"]))
	var spam: String = ""
	for eid: String in per_id.keys():
		var cd: float = float(bank.get_event(eid).get("cooldown_ms", 0)) / 1000.0
		var ts: Array = per_id[eid]
		for i: int in range(1, ts.size()):
			if float(ts[i]) - float(ts[i - 1]) < cd - 0.0001:
				spam = "%s repeats faster than its %.0f ms cooldown" % [eid, cd * 1000.0]
	for i: int in times.size():
		var n: int = times.filter(func(x: float) -> bool: return x >= times[i] and x < times[i] + 1.0).size()
		if n > MAX_PER_SEC:
			spam = "%d sounds in 1 s" % n
	bridge.detach()
	bridge.free()
	director.free()
	return {"started": started, "shape": shape, "ids": ids, "unknown": unknown, "spam": spam}
