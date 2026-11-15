extends SceneTree
## Dash pass (2026-11-15, user: "vi la di chuyen qua cac o nen toi muon cai animation di chuyen no kieu nhu luot,
## nhay ... dash la chinh"): the pure arithmetic behind the dash -- the glide's ease exponent (UnitLayer.slide_offset,
## UnitMotion.dash_ease) and the fading trail behind the body (DashGhost). No tree, no sheet: every function under
## test is pure, which is the whole reason the trail math lives in its own file.
## Run: godot --headless --path . -s res://tests/unit/battle/dash_ghost_test.gd

const DashGhost = preload("res://src/battle/dash_ghost.gd")

## A 40 px step to the right, the shape of a real horizontal cell move (cells are 38-64 art px wide).
const FROM := Vector2i(100, 50)
const TO := Vector2i(140, 50)

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_dash_ease_brakes_less_than_the_slide()
	test_dash_ease_keeps_both_ends_exact()
	test_ghost_trails_behind_the_body()
	test_ghost_count_and_gap_are_respected()
	test_ghost_is_silent_when_there_is_nothing_to_trail()
	test_hero_profile_asks_for_a_dash()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# The exponent IS the dash: the old cubic has the unit 7/8 of the way across at half time (it is already braking),
# a dash exponent leaves it nearer the middle, still travelling. Both are measured at the same instant.
func test_dash_ease_brakes_less_than_the_slide() -> void:
	var slide: Vector2i = UnitLayer.slide_offset(FROM, TO, 0.06, 0.12, 3.0)
	var dash: Vector2i = UnitLayer.slide_offset(FROM, TO, 0.06, 0.12, 1.4)
	# Offsets are negative (behind the destination), so "further back" is a SMALLER number.
	_check("test_dash_is_further_back_at_half_time", dash.x < slide.x, "dash %s vs slide %s" % [dash.x, slide.x])
	_check("test_cubic_is_the_unchanged_default", UnitLayer.slide_offset(FROM, TO, 0.06, 0.12) == slide,
		"%s vs %s" % [UnitLayer.slide_offset(FROM, TO, 0.06, 0.12), slide])


# Whatever the exponent, the unit leaves the old cell exactly and lands on the new one exactly: the ease may only
# change the path between them. A dash that lands half a pixel off would drift the hero across a match.
func test_dash_ease_keeps_both_ends_exact() -> void:
	for ease: float in [1.0, 1.4, 3.0]:
		_check("test_start_is_the_whole_gap at ease %s" % ease,
			UnitLayer.slide_offset(FROM, TO, 0.12, 0.12, ease) == Vector2i(-40, 0))
		_check("test_end_is_exact at ease %s" % ease,
			UnitLayer.slide_offset(FROM, TO, 0.0, 0.12, ease) == Vector2i.ZERO)


# A ghost is where the body WAS, so it sits further back than the body, and the one behind it further back again.
func test_ghost_trails_behind_the_body() -> void:
	var left: float = 0.05
	var total: float = 0.12
	var now: Vector2i = UnitLayer.slide_offset(FROM, TO, left, total, 1.4)
	var ghosts: Array[Dictionary] = DashGhost.samples(FROM, TO, left, total, 1.4, 3, 0.035)
	_check("test_three_ghosts_mid_dash", ghosts.size() == 3, str(ghosts.size()))
	if ghosts.size() < 3:
		return
	var a: Vector2i = ghosts[0]["offset"]
	var b: Vector2i = ghosts[1]["offset"]
	var c: Vector2i = ghosts[2]["offset"]
	_check("test_each_ghost_is_further_back", a.x < now.x and b.x < a.x and c.x < b.x,
		"body %s then %s %s %s" % [now.x, a.x, b.x, c.x])
	_check("test_each_ghost_is_fainter", float(ghosts[0]["alpha"]) > float(ghosts[1]["alpha"])
		and float(ghosts[1]["alpha"]) > float(ghosts[2]["alpha"]),
		"%s %s %s" % [ghosts[0]["alpha"], ghosts[1]["alpha"], ghosts[2]["alpha"]])
	_check("test_no_ghost_is_opaque", float(ghosts[0]["alpha"]) > 0.0 and float(ghosts[0]["alpha"]) < 1.0,
		str(ghosts[0]["alpha"]))


# The profile's two knobs do what they say: count caps the trail (never past MAX_GHOSTS), and a wider gap spaces it out.
func test_ghost_count_and_gap_are_respected() -> void:
	_check("test_count_zero_draws_nothing", DashGhost.samples(FROM, TO, 0.05, 0.12, 1.4, 0, 0.035).is_empty())
	_check("test_count_one_draws_one", DashGhost.samples(FROM, TO, 0.05, 0.12, 1.4, 1, 0.02).size() == 1)
	_check("test_count_is_capped", DashGhost.samples(FROM, TO, 0.11, 0.12, 1.4, 99, 0.004).size() <= DashGhost.MAX_GHOSTS,
		str(DashGhost.samples(FROM, TO, 0.11, 0.12, 1.4, 99, 0.004).size()))
	var tight: Array[Dictionary] = DashGhost.samples(FROM, TO, 0.06, 0.12, 1.4, 1, 0.01)
	var wide: Array[Dictionary] = DashGhost.samples(FROM, TO, 0.06, 0.12, 1.4, 1, 0.04)
	_check("test_a_wider_gap_trails_further", (wide[0]["offset"] as Vector2i).x < (tight[0]["offset"] as Vector2i).x,
		"wide %s vs tight %s" % [wide[0]["offset"], tight[0]["offset"]])


# Nothing to trail, nothing drawn: standing still, a finished dash, a zero-length dash, and the first instant of a
# dash (every ghost's moment is still before it began).
func test_ghost_is_silent_when_there_is_nothing_to_trail() -> void:
	_check("test_no_trail_when_landed", DashGhost.samples(FROM, TO, 0.0, 0.12, 1.4, 3, 0.035).is_empty())
	_check("test_no_trail_without_a_dash", DashGhost.samples(FROM, TO, 0.05, 0.0, 1.4, 3, 0.035).is_empty())
	_check("test_no_trail_at_the_very_start", DashGhost.samples(FROM, TO, 0.12, 0.12, 1.4, 3, 0.035).is_empty())
	_check("test_no_trail_without_a_gap", DashGhost.samples(FROM, TO, 0.05, 0.12, 1.4, 3, 0.0).is_empty())
	_check("test_no_trail_when_the_unit_did_not_move",
		DashGhost.samples(FROM, FROM, 0.05, 0.12, 1.4, 3, 0.035).is_empty())


# The data, not just the maths: the hero is the unit the user asked for a dash, and nobody else was given one by
# accident. A profile change that silently drops the trail would otherwise pass every test above.
func test_hero_profile_asks_for_a_dash() -> void:
	var hero: UnitMotion = UnitMotion.for_unit("kiem_si")
	_check("test_hero_has_ghosts", hero.ghost_count > 0, str(hero.ghost_count))
	_check("test_hero_brakes_less_than_the_default", hero.dash_ease < 3.0, str(hero.dash_ease))
	_check("test_hero_has_a_gap", hero.ghost_gap > 0.0, str(hero.ghost_gap))
	var other: UnitMotion = UnitMotion.for_unit("")
	_check("test_default_unit_is_unchanged", other.ghost_count == 0 and is_equal_approx(other.dash_ease, 3.0),
		"ghosts %s ease %s" % [other.ghost_count, other.dash_ease])
