extends SceneTree
## Music capture driver (docs/design/audio/music-plan.md): plays the music path of one region in the real game for a
## Movie Maker recording. Map (explore track) -> picks the first battle node -> fights a few seconds (battle track) ->
## kills every enemy (victory stinger, 7 s hold) -> back on the map (explore track resumes). Prints the music
## player's track at each step. A tool, not a test.
## Run (windowed, muted, frame-locked):
##   godot --path . --audio-driver Dummy --fixed-fps 30 --write-movie out.avi -s res://tools/audio/music_capture.gd
##       -- --region=<id> --no-autopause
## The region comes from GameFlow's own --region dev arg (a fresh run on that region's map).

const MAP_SEC: float = 7.0
const FIGHT_SEC: float = 9.0
const AFTER_WIN_SEC: float = 14.0

var _flow: GameFlow


func _initialize() -> void:
	_run()


func _wait(sec: float) -> void:
	var frames: int = int(sec * 30.0)
	for i: int in frames:
		await process_frame


func _music() -> String:
	var rig: AudioRig = AudioRig.of(_flow)
	if rig == null or rig.get_music() == null:
		return "?"
	var amb: Node = rig.get_ambience()
	return "%s ambience=%s" % [rig.get_music().current_track(), amb.current_region() if amb != null else "?"]


func _run() -> void:
	var main: Node = (load("res://src/main.tscn") as PackedScene).instantiate()
	_flow = main.get_node("GameFlow") as GameFlow
	root.add_child(main)
	await _wait(MAP_SEC)
	print("MAP phase=%d region=%s music=%s" % [_flow.get_phase(), _flow.get_run().region_id if _flow.get_run() != null else "-", _music()])
	var nodes: Array[Dictionary] = _flow.get_available_nodes()
	var pick: int = -1
	for i: int in nodes.size():
		if str(nodes[i].get("kind", "")) in ["battle", "danger"]:
			pick = i
			break
	if pick < 0:
		print("RESULT no battle node: ", nodes)
		quit(1)
		return
	_flow.choose_node(pick)
	var controller: RunController = _flow.get_controller()
	for i: int in 600:
		if controller != null and controller.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	await _wait(FIGHT_SEC)
	print("BATTLE music=%s" % _music())
	var view := controller.get_battle().get_node(RunController.COMBAT_VIEW_NODE) as CombatView
	for key: int in view.get_state().enemy_keys(true):
		view.get_state().damage_key(key, 1.0e9)
	await _wait(1.0)
	print("WON music=%s voices=%s" % [_music(), AudioRig.of(_flow).get_music().voices()])
	await _wait(AFTER_WIN_SEC)
	print("AFTER phase=%d music=%s" % [_flow.get_phase(), _music()])
	print("RESULT done")
	quit(0)
