class_name VentSurgeTrait
extends BossTrait
## Trait `vent_surge` (Story 039 Part B, Chua Quy Lua / inferno_lord): every `interval_sec` the boss makes `vents` lava
## vents of the PLAYER's half erupt at once (TileHazards.trigger_vents: the vents holding the player's cell first, then
## seeded), each after the hazards' own warning (`vent_warn_sec`). The boss's phase 2 (the existing `phase_shift` trait,
## param `vent_interval_mult` 0.7) speeds up the arena's regular vent rhythm through TileHazards.set_vent_interval_mult.
## The vent API of TileHazards is reached through has_method so the trait is inert on a build without it.
## Params (match trait entry): `interval_sec` (default 10), `vents` (default 2), `first_delay_sec` (default = interval).
## HUD: [method get_next_surge_left], [method get_surge_count].
## Implements: Story 039 (Part B).

## A surge fired; [param count] vents were set off.
signal surged(count: int)

const ID: String = "vent_surge"
const DEFAULT_INTERVAL_SEC: float = 10.0
const DEFAULT_VENTS: int = 2
const _SEED_OFFSET: int = 9547
## Float slack for timers counted down in fixed steps.
const _EPS: float = 0.000001

var _interval_sec: float = DEFAULT_INTERVAL_SEC
var _vents: int = DEFAULT_VENTS
var _first_delay_sec: float = DEFAULT_INTERVAL_SEC
var _timer: float = DEFAULT_INTERVAL_SEC
var _surge_count: int = 0
var _last_count: int = 0


func get_id() -> String:
	return ID


func seed_offset() -> int:
	return _SEED_OFFSET


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_interval_sec = maxf(param_float("interval_sec", DEFAULT_INTERVAL_SEC), 0.1)
	_vents = maxi(param_int("vents", DEFAULT_VENTS), 1)
	_first_delay_sec = maxf(param_float("first_delay_sec", _interval_sec), 0.0)


func on_match_start() -> void:
	_timer = _first_delay_sec
	_surge_count = 0
	_last_count = 0


func on_tick(step: float) -> void:
	_timer -= step
	if _timer > _EPS:
		return
	_timer = _interval_sec
	_surge()


## Seconds until the next surge.
func get_next_surge_left() -> float:
	return maxf(_timer, 0.0)


## Surges so far this match.
func get_surge_count() -> int:
	return _surge_count


## Vents the last surge set off (0 when the side has none).
func get_last_count() -> int:
	return _last_count


func get_debug() -> Dictionary:
	return {"id": ID, "surges": _surge_count, "next_left": get_next_surge_left()}


func _surge() -> void:
	var hazards: TileHazards = get_hazards()
	var state: CombatState = get_context().get("state") as CombatState
	if hazards == null or state == null or not hazards.has_method("trigger_vents"):
		return
	_last_count = int(hazards.call("trigger_vents", CombatState.Side.PLAYER, _vents, state.player_cell))
	if _last_count <= 0:
		return
	_surge_count += 1
	surged.emit(_last_count)
