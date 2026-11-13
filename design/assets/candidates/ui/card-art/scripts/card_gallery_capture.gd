## Card-art evidence capture (design tool, not game code): draws every card of assets/data/cards.json with the
## game's own CardFace (ancient style, the reward-screen face) at 1280x720, 12 cards per page, and saves one
## screenshot per page to production/qa/evidence/card-art/gallery-<n>.png.
## Run windowed and muted (repo root):
##   godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -s res://design/assets/candidates/ui/card-art/scripts/card_gallery_capture.gd
## Optional user arg: -- --locale=en (default vi).
extends SceneTree

const OUT_DIR: String = "res://production/qa/evidence/card-art"
const CARD_SIZE: Vector2 = Vector2(176, 256)
const COLS: int = 6
const ROWS: int = 2
const GAP: Vector2 = Vector2(24, 40)
const BG: Color = Color("#1B1722")


class Gallery extends Node2D:
	var cards: SkillConfig
	var ids: Array = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), BG)
		var total: Vector2 = Vector2(COLS * CARD_SIZE.x + (COLS - 1) * GAP.x, ROWS * CARD_SIZE.y + (ROWS - 1) * GAP.y)
		var origin: Vector2 = ((get_viewport_rect().size - total) * 0.5).round()
		for i in ids.size():
			var id: String = ids[i]
			var skill: Dictionary = cards.resolved(id, 1)
			var pos: Vector2 = origin + Vector2(i % COLS, i / COLS) * (CARD_SIZE + GAP)
			var rect := Rect2(pos, CARD_SIZE)
			CardFace.draw_skill(self, rect, skill, tr(str(skill.get("name_key", id))), "", CardText.describe_resolved(skill),
					false, false, false, [], id)
			draw_string(ThemeDB.fallback_font, pos + Vector2(0, CARD_SIZE.y + 16), id, HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x,
					12, Color("#EFE6D2"))


func _initialize() -> void:
	var locale: String = "vi"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--locale="):
			locale = arg.trim_prefix("--locale=")
	TranslationServer.set_locale(locale)
	_run.call_deferred()


func _run() -> void:
	var cards: SkillConfig = SkillConfig.load_from_file()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/cards.json"))
	var ids: Array = []
	for id in data.get("card_order", []):
		ids.append(str(id))
	for id in data.get("cards", {}).keys():
		if not ids.has(str(id)):
			ids.append(str(id))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var gallery := Gallery.new()
	gallery.cards = cards
	root.add_child(gallery)
	var per_page: int = COLS * ROWS
	var page: int = 0
	while page * per_page < ids.size():
		gallery.ids = ids.slice(page * per_page, (page + 1) * per_page)
		gallery.queue_redraw()
		for _f in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var path: String = "%s/gallery-%d.png" % [OUT_DIR, page + 1]
		img.save_png(ProjectSettings.globalize_path(path))
		print("saved ", path, " (", gallery.ids.size(), " cards)")
		page += 1
	quit()
