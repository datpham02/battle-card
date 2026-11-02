extends SceneTree
## TD-033 (Story 037 Part E): drives the real achievements screen with touch / mouse events (local coords).
## Windowed only: --windowed --resolution 1280x720 -s res://tests/integration/ui/achievements_flow_test.gd
## -- --no-autopause. Intents: tap "Thanh tuu" on the title -> ACHIEVEMENTS at scroll 0; a finger drag up
## scrolls the grid by exactly the finger travel (past TAP_SLOP) and clamps at max_scroll / 0; a tap on a
## (scrolled) cell opens that cell's detail; a tap anywhere closes it, a tap on "Ve" while the detail is
## open only closes the detail; "Ve" returns to the title; reopening (GameFlow.open_achievements) starts
## at scroll 0 again; desktop extra: a mouse click on a cell opens its detail. Memory progress store (no
## save touched). Prints PASS/FAIL lines and FAILS=n.

const RealMouseGuard = preload("res://tests/integration/ui/real_mouse_guard.gd")

var fails: int = 0
const VP: Vector2 = Vector2(1280, 720)

var flow: GameFlow
var view: AchievementsView
var title: TitleView


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = pressed
	ev.position = pos
	root.push_input(ev, true)
	await process_frame


func _touch_drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	root.push_input(ev, true)
	await process_frame


func _tap(pos: Vector2) -> void:
	await _touch(0, pos, true)
	await _touch(0, pos, false)


func _mouse_button(p: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.device = RealMouseGuard.TEST_DEVICE
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = p
	ev.global_position = p
	root.push_input(ev, true)
	await process_frame


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


# Centre of cell [param index] on screen at the current scroll.
func _cell_center(index: int) -> Vector2:
	var rect: Rect2 = AchievementsView.cell_rect(VP, index)
	rect.position.y -= view.get_scroll()
	return rect.get_center()


func _initialize() -> void:
	var main: Node = load("res://src/main.tscn").instantiate()
	flow = main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	root.add_child(RealMouseGuard.new())
	await _frames(3)
	view = flow.get_node("AchievementsView") as AchievementsView
	title = flow.get_node("TitleView") as TitleView
	var ids: Array = AchievementsConfig.shared().ids()
	_check("starts on the title", flow.get_phase() == GameFlow.Phase.TITLE and not view.is_open())

	# --- Title -> achievements by tapping its button.
	var labels: Array[String] = title._button_labels()
	var idx: int = labels.find(TitleView.TEXT_ACHIEVEMENTS)
	_check("title shows the achievements button", idx >= 0, str(labels))
	var btn: Rect2 = ScreenLayout.title_button_rects(VP, labels.size())[maxi(idx, 0)]
	await _tap(btn.get_center())
	await _frames(2)
	_check("tap on the title button opens ACHIEVEMENTS", flow.get_phase() == GameFlow.Phase.ACHIEVEMENTS and view.is_open())
	_check("opens at scroll 0, no detail", view.get_scroll() == 0.0 and view.detail_id() == "")
	var max_s: float = view.max_scroll(VP)
	_check("the grid is taller than the screen (max_scroll > 0)", max_s > 0.0 and ids.size() > 0, "max=%.1f cells=%d" % [max_s, ids.size()])

	# --- Drag-scroll: the grid follows the finger exactly while it is down, clamped at both ends.
	var grid: Rect2 = AchievementsView.grid_rect(VP)
	var start := Vector2(VP.x * 0.5, grid.end.y - 20.0)
	var travel: float = minf(100.0, max_s * 0.5)
	await _touch(0, start, true)
	await _touch_drag(0, start + Vector2(0, -AchievementsView.TAP_SLOP - 6.0))
	await _touch_drag(0, start + Vector2(0, -travel))
	_check("drag up scrolls by the finger travel", is_equal_approx(view.get_scroll(), travel) and view.detail_id() == "", "%.2f vs %.2f" % [view.get_scroll(), travel])
	await _touch_drag(0, start + Vector2(0, -(max_s + 400.0)))
	_check("dragging past the end clamps at max_scroll", is_equal_approx(view.get_scroll(), max_s), "%.2f vs %.2f" % [view.get_scroll(), max_s])
	await _touch_drag(0, start + Vector2(0, 300.0))
	_check("dragging back past the top clamps at 0", view.get_scroll() == 0.0, "%.2f" % view.get_scroll())
	await _touch_drag(0, start + Vector2(0, -travel))
	await _touch(0, start + Vector2(0, -travel), false)
	await _frames(30)
	_check("a drag release never opens a detail", view.detail_id() == "" and view.is_open())
	_check("scroll stays inside 0..max after the release (inertia clamped)", view.get_scroll() >= 0.0 and view.get_scroll() <= max_s, "%.2f" % view.get_scroll())

	# --- Tap a cell of the scrolled grid: its detail opens.
	view.set_scroll(minf(120.0, max_s))
	await process_frame
	var target: int = mini(5, ids.size() - 1)
	var c: Vector2 = _cell_center(target)
	_check("cell_at agrees with cell_rect at the current scroll", view.cell_at(c, VP) == target and grid.has_point(c), "cell_at=%d at %s" % [view.cell_at(c, VP), str(c)])
	await _tap(c)
	_check("tap on a scrolled cell opens that cell's detail", view.detail_id() == str(ids[target]), "'%s' vs '%s'" % [view.detail_id(), str(ids[target])])

	# --- Tap anywhere closes the detail (no scroll change, still on the screen).
	var scroll_before: float = view.get_scroll()
	await _tap(AchievementsView.panel_rect(VP).get_center())
	_check("a tap closes the detail", view.detail_id() == "" and view.is_open())
	_check("closing the detail keeps the scroll", is_equal_approx(view.get_scroll(), scroll_before))

	# --- "Ve" while a detail is open only closes the detail.
	view.open_detail(str(ids[0]))
	var back_c: Vector2 = AchievementsView.back_rect(VP).get_center()
	await _tap(back_c)
	_check("tap on Ve with the detail open closes the detail, screen stays", view.detail_id() == "" and flow.get_phase() == GameFlow.Phase.ACHIEVEMENTS)

	# --- "Ve" returns to the title.
	await _tap(back_c)
	await _frames(2)
	_check("tap on Ve returns to the title", flow.get_phase() == GameFlow.Phase.TITLE and not view.is_open())

	# --- Reopen (GameFlow.open_achievements): scroll reset to 0.
	flow.open_achievements()
	await _frames(2)
	_check("reopened through GameFlow.open_achievements at scroll 0", view.is_open() and view.get_scroll() == 0.0 and view.detail_id() == "", "%.2f" % view.get_scroll())

	# --- Desktop extra (mouse): click a cell -> detail; click -> closed.
	var m: Vector2 = _cell_center(0)
	await _mouse_button(m, true)
	await _mouse_button(m, false)
	_check("mouse: click on a cell opens its detail", view.detail_id() == str(ids[0]), view.detail_id())
	await _mouse_button(m, true)
	await _mouse_button(m, false)
	_check("mouse: click closes the detail", view.detail_id() == "")
	flow.close_achievements()
	await _frames(2)
	_check("GameFlow.close_achievements returns to the title", flow.get_phase() == GameFlow.Phase.TITLE)

	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)
