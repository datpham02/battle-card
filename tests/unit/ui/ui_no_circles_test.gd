extends SceneTree
## 2026-11-02 rule (user): Tessera's UI is angular (any shape with corners), no circles except the movement joystick.
## Scans the menu / run screen and shared UI scripts (src/run, src/ui, src/hold) and fails on any draw_circle or
## draw_arc call; the angular stand-ins are HudSkin.regular_points / perimeter_trace / flame_points / shackle_points.
## The battle HUD and board effects (src/combat, src/battle) are out of this scan: the joystick lives there.
## Reads only res:// source files. Prints PASS/FAIL lines and FAILS=n, exit code 1 on failure.
## Run: godot --headless --path . -s res://tests/unit/ui/ui_no_circles_test.gd

const SCAN_DIRS: Array[String] = ["res://src/run", "res://src/ui", "res://src/hold"]
const ROUND_CALLS: Array[String] = ["draw_circle(", "draw_arc("]

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_menu_scripts_draw_no_circles()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_menu_scripts_draw_no_circles() -> void:
	var scripts: Array[String] = []
	for dir: String in SCAN_DIRS:
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				scripts.append(dir.path_join(file))
	_check("test_scan_found_the_menu_scripts", scripts.size() > 10, "(%d scripts)" % scripts.size())
	var hits: Array[String] = []
	for path: String in scripts:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			var code: String = lines[i].get_slice("#", 0)
			for call: String in ROUND_CALLS:
				if code.contains(call):
					hits.append("%s:%d" % [path.get_file(), i + 1])
	_check("test_menu_scripts_draw_no_circle_or_arc", hits.is_empty(), str(hits))
