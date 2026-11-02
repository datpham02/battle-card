extends SceneTree
## ADR-0002 static guard: board-space geometry has ONE definition. No script under res://src outside the facade and
## the layout it wraps may ask ScreenLayout for flat board cells (cell_rect / cells_rect / cell_center / cell_at /
## board_rect / player_half_rect / signature_timer_rect) or build its own FloorPerspective: a consumer that did would
## draw the flat cell over the perspective floor. Allowed: BoardGeometry itself, ScreenLayout (defines the flat model),
## FloorPerspective (the homography), FloorLayer (draws the flat floor the shader warps) and BattleCanvas (feeds the
## shader its homography). Comment lines are ignored. Reads the source tree only (a static check, no game state).
## Run: godot --headless --path . -s res://tests/unit/layout/board_geometry_consumers_test.gd

const ROOT: String = "res://src"
const ALLOWED: Array[String] = [
	"res://src/layout/board_geometry.gd",
	"res://src/layout/screen_layout.gd",
	"res://src/layout/floor_perspective.gd",
	"res://src/battle/floor_layer.gd",
	"res://src/battle/battle_canvas.gd",
]
const FORBIDDEN: Array[String] = [
	"ScreenLayout.cell_rect(", "ScreenLayout.cells_rect(", "ScreenLayout.cell_center(", "ScreenLayout.cell_at(",
	"ScreenLayout.board_rect(", "ScreenLayout.player_half_rect(", "ScreenLayout.signature_timer_rect(",
	"FloorPerspective.of(", "FloorPerspective.make(",
]

var fails: int = 0


func check(name: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	var files: Array[String] = []
	_collect(ROOT, files)
	check("test_found_source_files_%d" % files.size(), files.size() > 50)
	var offenders: Array[String] = []
	for path: String in files:
		if ALLOWED.has(path):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		var n: int = 0
		for line: String in text.split("\n"):
			n += 1
			var code: String = line.strip_edges()
			if code.begins_with("#"):
				continue
			var hash_at: int = code.find(" # ")
			if hash_at >= 0:
				code = code.substr(0, hash_at)
			for needle: String in FORBIDDEN:
				if code.contains(needle):
					offenders.append("%s:%d %s" % [path, n, needle])
	for o: String in offenders:
		print("  board geometry outside BoardGeometry: " + o)
	check("test_no_board_cell_geometry_outside_board_geometry_got_%d" % offenders.size(), offenders.is_empty())
	# The facade is what the consumers use.
	for path: String in ["res://src/combat/cut_hud_view.gd", "res://src/drops/field_drops_view.gd", "res://src/battle/unit_layer.gd",
			"res://src/battle/overlay_layer.gd", "res://src/combat/combat_view.gd", "res://src/pieces/piece_draw.gd"]:
		check("test_%s_uses_board_geometry" % path.get_file(), FileAccess.get_file_as_string(path).contains("BoardGeometry"))
	print("FAILS=%d" % fails)
	quit(fails)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for f: String in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d: String in dir.get_directories():
		_collect(dir_path.path_join(d), out)
