extends SceneTree
## Skill v2 V3 DeliveryFx: every layer is empty outside its window, deterministic, draws inside it, and the standing
## layers never go below the ground line.
## Run: godot --headless --path . -s res://tests/unit/art/delivery_fx_test.gd

const CELL := Rect2i(100, 60, 64, 46)
const BASE := Vector2i(300, 200)

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _above(items: Array[Dictionary], ground: int) -> bool:
	for it: Dictionary in items:
		if (it["rect"] as Rect2i).end.y > ground + 6:
			return false
	return true


func _initialize() -> void:
	# sky
	ck("sky_floor: [] outside the target window", DeliveryFx.sky_floor(CELL, -0.01).is_empty() and DeliveryFx.sky_floor(CELL, 0.31).is_empty())
	ck("sky_floor: draws and closes in", DeliveryFx.sky_floor(CELL, 0.25).size() > 0
		and (DeliveryFx.sky_floor(CELL, 0.02)[0]["rect"] as Rect2i).size.x < (DeliveryFx.sky_floor(CELL, 0.25)[0]["rect"] as Rect2i).size.x)
	ck("sky_standing: [] outside [0, drop]", DeliveryFx.sky_standing(BASE, 64, -0.01, 0.12, 3).is_empty() and DeliveryFx.sky_standing(BASE, 64, 0.13, 0.12, 3).is_empty())
	var high: Array[Dictionary] = DeliveryFx.sky_standing(BASE, 64, 0.12, 0.12, 3)
	var low: Array[Dictionary] = DeliveryFx.sky_standing(BASE, 64, 0.0, 0.12, 3)
	ck("sky_standing: falls toward the base and stays above it", (high[0]["rect"] as Rect2i).position.y < (low[0]["rect"] as Rect2i).position.y and _above(low, BASE.y))
	ck("sky_standing: deterministic", high == DeliveryFx.sky_standing(BASE, 64, 0.12, 0.12, 3))
	# ground
	var a := Vector2i(100, 80)
	var b := Vector2i(300, 80)
	ck("ground_floor: [] outside [0, arrive]", DeliveryFx.ground_floor(a, b, -0.01, 0.3).is_empty() and DeliveryFx.ground_floor(a, b, 0.31, 0.3).is_empty())
	var g1: Array[Dictionary] = DeliveryFx.ground_floor(a, b, 0.15, 0.3)
	ck("ground_floor: the front is halfway and light", not g1.is_empty() and bool(g1[0]["light"]) and absi((g1[0]["rect"] as Rect2i).get_center().x - 200) <= 3)
	ck("ground_floor: deterministic", g1 == DeliveryFx.ground_floor(a, b, 0.15, 0.3))
	ck("ground_dust: draws above the front and never below the ground", not DeliveryFx.ground_dust(BASE, Vector2(-1, 0), 64, 0.5, 3).is_empty()
		and _above(DeliveryFx.ground_dust(BASE, Vector2(-1, 0), 64, 0.5, 3), BASE.y))
	# chain
	var c0: Array[Dictionary] = DeliveryFx.chain_standing(BASE, BASE + Vector2i(64, 0), 64, 0.5)
	ck("chain_standing: lifted at the middle, [] outside", not c0.is_empty() and (c0[0]["rect"] as Rect2i).position.y < BASE.y - 20
		and DeliveryFx.chain_standing(BASE, BASE + Vector2i(64, 0), 64, 1.01).is_empty())
	ck("chain_standing: a tail follows the head", DeliveryFx.chain_standing(BASE, BASE + Vector2i(64, 0), 64, 0.6).size() > DeliveryFx.chain_standing(BASE, BASE + Vector2i(64, 0), 64, 0.05).size())
	# streak
	ck("streak: head + core + tail + sparks, [] outside", DeliveryFx.streak(a, b, 0.5).size() == 7 and DeliveryFx.streak(a, b, -0.1).is_empty() and DeliveryFx.streak(a, a, 0.5).is_empty())
	# gather
	ck("gather_floor: [] outside, converges", DeliveryFx.gather_floor(CELL, 0.21).is_empty()
		and (DeliveryFx.gather_floor(CELL, 0.02)[0]["rect"] as Rect2i).get_center().distance_to(CELL.get_center()) < (DeliveryFx.gather_floor(CELL, 0.18)[0]["rect"] as Rect2i).get_center().distance_to(CELL.get_center()))
	ck("gather_standing: drops in and stays above the base", not DeliveryFx.gather_standing(BASE, 64, 0.1).is_empty() and _above(DeliveryFx.gather_standing(BASE, 64, 0.0), BASE.y)
		and DeliveryFx.gather_standing(BASE, 64, 0.3).is_empty())
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)
