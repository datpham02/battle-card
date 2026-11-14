extends Node2D

## The passive victory cue (F3 §2.1, `second_wind`): the hero's body lights green, then a "+20hp"
## damage-number-style text rises beside him.
##
## [b]Why this is its own node with [constant Node.PROCESS_MODE_ALWAYS].[/b] The cue fires on the
## frame the match is won, and `RunController._on_match_ended` immediately calls `_freeze_battle()`,
## which sets `Battle.process_mode = PROCESS_MODE_DISABLED` (`run_controller.gd:401-403`). That
## freezes the WHOLE battle subtree — `CutHudView` and `UnitLayer` included, both being children of
## `Battle` (`src/battle/battle.tscn`). A cue drawn by either of them would appear and then hang
## motionless for the three seconds the frozen board stays on screen, and it would look perfectly
## correct in code review. Only a node that processes regardless of its parents can animate here.
##
## [b]Do not reuse the hit-flash path for the glow.[/b] `UnitLayer._flash_left` is driven by
## `_tick_flash_wait` inside the simulation STEP loop, so it is broken twice over at this moment:
## once by the disabled process mode and once by the stopped step clock. Fixing only the first is
## the trap. This node keeps its own real-time countdown, taken from the unscaled frame delta.
##
## Owns no state about the match: [code]UnitLayer[/code] draws through it, this node only clocks it.

## Seconds the body stays lit. The glow leads the text so the eye lands on the hero first.
const GLOW_SEC: float = 0.35
## Seconds the number spends rising, started [constant TEXT_DELAY_SEC] after the glow.
const TEXT_SEC: float = 0.80
const TEXT_DELAY_SEC: float = 0.15

## Seconds elapsed since the cue started; -1.0 when idle.
var _elapsed: float = -1.0
## Which unit key the cue plays on.
var _side: int = 0
## The healed amount shown in the text.
var _amount: int = 0
## Drawn with BLEND_MODE_ADD, for the body glow only — the text must not be additive or it washes
## out against a bright sprite.
var _glow: Node2D = null


func _ready() -> void:
	_build()
	visible = false


## Builds the additive glow child. Called from [method _ready] AND from
## [method glow_canvas], because `_ready` only runs when the node enters the TREE -- adding it
## to a parent that is not itself in the tree does not run it. The owner connects to the glow's
## draw signal right after add_child, and for a while that connection was silently skipped
## because the child did not exist yet. Building on demand makes the null case impossible.
func _build() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _glow != null:
		return
	_glow = Node2D.new()
	_glow.name = "PassiveGlow"
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	add_child(_glow)


## The additive child the body glow is drawn on. Null before [method _ready].
func glow_canvas() -> Node2D:
	_build()
	return _glow


## Starts the cue for [param side] showing [param amount] HP. Restarts a cue already playing.
func play(side: int, amount: int) -> void:
	_side = side
	_amount = maxi(amount, 0)
	_elapsed = 0.0
	visible = true
	queue_redraw()
	if _glow != null:
		_glow.queue_redraw()


## True while the cue is on screen.
func is_playing() -> bool:
	return _elapsed >= 0.0


## Seconds into the cue, or -1.0 when idle.
func elapsed() -> float:
	return _elapsed


## The unit key the cue is playing on.
func side() -> int:
	return _side


## The HP figure the text shows.
func amount() -> int:
	return _amount


## Unscaled: the cue runs on real time precisely because match time has stopped by now.
func _process(delta: float) -> void:
	if _elapsed < 0.0:
		return
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= TEXT_DELAY_SEC + TEXT_SEC:
		_elapsed = -1.0
		visible = false
	queue_redraw()
	if _glow != null:
		_glow.queue_redraw()


## 0..1 glow strength, full at once and falling away. 0.0 when the glow is over.
func glow_fade() -> float:
	if _elapsed < 0.0 or _elapsed >= GLOW_SEC:
		return 0.0
	return clampf(1.0 - _elapsed / GLOW_SEC, 0.0, 1.0)


## 0..1 of the text's rise, or -1.0 when the text is not on screen yet or is finished.
func text_progress() -> float:
	if _elapsed < TEXT_DELAY_SEC:
		return -1.0
	var t: float = (_elapsed - TEXT_DELAY_SEC) / TEXT_SEC
	return t if t <= 1.0 else -1.0
