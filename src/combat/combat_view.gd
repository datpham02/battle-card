class_name CombatView
extends Node2D
## Draws the arena and owns the combat logic objects (CombatState, the player's UnitMover,
## the player half's FieldDrops), ticking them from _process with one shared (capped) delta.
## Layout (landscape): a thin HUD band (player HP left, boss HP right), then the board (size
## and shape from CombatConfig.grid): player's half left of a divider, boss's half right.
## The boss walks, picks up points and cuts (BossController); swings resolve via SwingArbiter.
## A cooldown ring under the player's feet shows the step cooldown. Placeholder art.
## Stepping onto a cell with a field point picks it up into the hand (HoldSlots).
## Story 014: owns ONE TraitHost per battle (boss traits from match_params["traits"]), wired
## to the arbiter / boss actor / both drops, ticked after the arbiter with the scaled step while
## both units live, torn down when the battle leaves the tree; ticks the hand's rot.
## Story 016: [method can_pause] tells the run whether the pause button / Esc may freeze the
## battle now; [member debug_overlay] gates the HUD's debug text.
## Implements: Story 003, Story 005, Story 006, Story 007, Story 014, Story 016.

const ENEMY_COLOR: Color = Color(0.7, 0.3, 0.3)
const ENEMY_DEAD_COLOR: Color = Color(0.45, 0.45, 0.45)
const BAR_BACK: Color = Color(0.2, 0.17, 0.15, 0.8)
const HP_COLOR: Color = Color(0.85, 0.2, 0.2)
const PLAYER_HP_COLOR: Color = Color(0.3, 0.75, 0.35)
const TEXT_COLOR: Color = Color(0.15, 0.12, 0.1)
const GRID_LINE_COLOR: Color = Color(0.15, 0.12, 0.1, 0.35)
const PLAYER_HALF_TINT: Color = Color(0.3, 0.55, 0.95, 0.12)
const ENEMY_HALF_TINT: Color = Color(0.85, 0.25, 0.25, 0.12)
const DIVIDER_COLOR: Color = Color(0.15, 0.12, 0.1, 0.9)
const PLAYER_COLOR: Color = Color(0.25, 0.6, 0.9)
const DEFEAT_COLOR: Color = Color(0.9, 0.1, 0.1)
const VICTORY_COLOR: Color = Color(0.1, 0.5, 0.2)
const RING_COLOR: Color = Color(0.95, 0.6, 0.1)
const RING_BACK_COLOR: Color = Color(0.15, 0.12, 0.1, 0.25)
const PAD: float = 10.0
const BAR_HEIGHT: float = 22.0
const FONT_SIZE: int = 24
const BIG_FONT_SIZE: int = 72
## In-cell elements scale from the cell size: player marker radius (of cell height),
## enemy body width / height (of cell width / height).
const MARKER_RADIUS_RATIO: float = 0.33
## Marker label font size as a share of the marker radius (so it shrinks with the grid).
const MARKER_FONT_RATIO: float = 0.6
## Player marker text fit (Story 018: the character name replaces "BẠN"): the font shrinks from
## MARKER_FONT_RATIO down to this size until the text fits MARKER_TEXT_FILL of the diameter; if it
## still does not fit, only the first word is drawn.
const MARKER_MIN_FONT_SIZE: int = 10
const MARKER_TEXT_FILL: float = 0.92
const ENEMY_BODY_WIDTH_RATIO: float = 0.6
const ENEMY_BODY_HEIGHT_RATIO: float = 0.8
## Cooldown ring: gap outside the marker (of cell height), line width, arc point count.
const RING_GAP_RATIO: float = 0.06
const RING_WIDTH: float = 6.0
const RING_POINTS: int = 48
## Gap between the HUD's left and right halves as a share of arena width.
const HUD_GAP_RATIO: float = 0.04
## Boss hand tags (HUD band): tag size, gap, top offset from the text row's top, label font,
## width kept free for the right-aligned boss HP text.
const HAND_TAG_WIDTH: float = 44.0
const HAND_TAG_HEIGHT: float = 26.0
const HAND_TAG_GAP: float = 6.0
const HAND_TAG_TOP_OFFSET: float = 0.0
const HAND_FONT_SIZE: int = 18
const HAND_TEXT_RESERVE: float = 300.0
const HAND_TAG_BACK: Color = Color(1.0, 1.0, 1.0, 0.92)
const HAND_EMPTY_COLOR: Color = Color(0.15, 0.12, 0.1, 0.3)
## Boss cooldown ring radius as a share of cell height (around its body), line width.
const BOSS_RING_RADIUS_RATIO: float = 0.5
const BOSS_RING_WIDTH: float = 5.0
## Seed for the field drops RNG; negative = random. Dev/capture only (DemoArgs sets it).
const RANDOM_SEED: int = -1

@export_file("*.json") var config_path: String = CombatConfig.DEFAULT_PATH
@export_file("*.json") var drops_config_path: String = FieldDropsConfig.DEFAULT_PATH
## The hand (its view owns the HoldSlots instance).
@export var hold_slots_view_path: NodePath = NodePath("../HoldSlotsView")
## Dev/capture only: when true time does not advance, so screenshots are deterministic.
var freeze_time: bool = false
## Dev/capture only: field drops RNG seed (negative = random). Set before _ready.
var drops_seed: int = RANDOM_SEED
## Dev/capture only: replaces the board from combat.json (DemoArgs --grid). Set before _ready.
var grid_override: BoardGrid = null
## DEV overlay flag (Story 016): the HUD draws its debug text (boss learning line) only when true.
## Set by DemoArgs from the --debug user arg.
var debug_overlay: bool = false

var _config: CombatConfig
## Arena of this match for the HUD: {shape, variant, seed} (shape "" = the combat.json board).
var _arena_info: Dictionary = {"shape": "", "variant": false, "seed": -1}
var _grid: BoardGrid
var _state: CombatState
var _mover: UnitMover
var _player_step_cooldown: float = 0.45
## Board-scaled step cooldown BEFORE the character multiplier; the boss's own cooldown derives from it.
var _base_step_cooldown: float = 0.45
var _drops: FieldDrops
var _drops_config: FieldDropsConfig
var _cut_config: CutConfig
var _skill_config: SkillConfig
var _deck: Deck
var _cooldowns: SkillCooldowns
var _focus: FocusController
var _cut_actor: CutActor
var _cut_flow: CutFlow
## Last resolved player cut for the HIT/MISS marker: {cells, hit, damage, cell, time_left}; empty = none.
var _feedback: Dictionary = {}
var _hold_hooked: bool = false
var _boss: BossController
var _arbiter: SwingArbiter
## Last resolved boss cut, drawn on the player's half: same shape as [member _feedback].
var _boss_feedback: Dictionary = {}
## Last interrupt flash {side (victim), cells, time_left}; empty = none.
var _interrupt_flash: Dictionary = {}
## Last feint flash {cells, time_left}; empty = none.
var _feint_flash: Dictionary = {}
var _status: StatusEffects
var _learning: BossLearning
## The boss traits of this match (Story 014); built in _ready, torn down in _exit_tree.
var _trait_host: TraitHost
## The character passive of this match (Story 018); null without a character or with an unknown id.
var _passive: BasePassive = null
var _passive_heal: float = 0.0
## Dev/capture only: weight set name for the boss brain (empty = from boss_brain.json).
var boss_set_override: String = ""
## Per-match settings from the run (set BEFORE _ready; empty = the plain single-match setup).
## Keys (all optional): player_hp (start HP, used when >= 0), boss_max_hp, brain_set,
## boss_step_cooldown_mult (x the player's computed step cooldown; deprecated absolute: boss_step_cooldown_sec), boss_think_interval_sec, boss_reaction_sec, boss_drop_interval_mult
## (applied to a copy of the drops config for the boss only), movement (object merged over the
## match set's movement profile of boss_brain.json), end_delay_sec (default 1.5),
## name_key (boss name in the HUD, translated; legacy display_name literal), match_label, arena (object: {shape[, variant]} or a direct
## {side_cols, side_rows, missing_cells}; see ArenaLibrary.grid_for_spec), arena_seed (int, variants),
## traits (array of {id, params}; see TraitRegistry.SCRIPTS and schema.md, Story 014),
## character (Story 018: {max_hp, step_cooldown_mult, focus_max_sec, passive: {id, params}}; absent =
## the combat.json player and no passive).
var match_params: Dictionary = {}

## Emitted ONCE, end_delay_sec of real time after either unit died.
signal match_ended(player_won: bool, player_hp: float)

## Real seconds between a death and [signal match_ended] when match_params has no end_delay_sec.
const DEFAULT_END_DELAY_SEC: float = 1.5
const DEFAULT_BOSS_NAME: String = "DUMMY"
## HUD keys (Story 017): the player marker / HP label (used when the match has no character, see
## [method get_player_name]), the HP line and the dead line of a unit.
const TEXT_YOU: String = "ui.hud.you"
const TEXT_UNIT_HP: String = "ui.hud.unit_hp"
const TEXT_UNIT_DEAD: String = "ui.hud.unit_dead"

var _end_timer: float = -1.0
var _end_emitted: bool = false


func _ready() -> void:
	_config = CombatConfig.load_from_file(config_path)
	if _config == null:
		push_warning("CombatView: using built-in default config")
		_config = CombatConfig.new()
	_apply_arena()
	if grid_override != null:
		_config.use_grid(grid_override)
		_arena_info = {"shape": "", "variant": false, "seed": -1}
	_grid = _config.grid
	var boss_max_hp: float = maxf(float(match_params.get("boss_max_hp", _config.enemy_max_hp)), 1.0)
	var character: Dictionary = _character()
	var player_max_hp: float = maxf(float(character.get("max_hp", _config.player_max_hp)), 1.0)
	_state = CombatState.new(
		_grid, player_max_hp, boss_max_hp, _config.player_start_cell, _config.enemy_start_cell
	)
	var start_hp: float = float(match_params.get("player_hp", -1.0))
	if start_hp >= 0.0:
		_state.set_player_hp(start_hp)
	_base_step_cooldown = _config.step_cooldown_for(_grid)
	_player_step_cooldown = _base_step_cooldown * _step_mult(character)
	_mover = UnitMover.new(_state, CombatState.Side.PLAYER, _player_step_cooldown)
	_drops_config = FieldDropsConfig.load_from_file(drops_config_path)
	var boss_drops_config: FieldDropsConfig = _drops_config.copy()
	boss_drops_config.spawn_interval_sec *= maxf(float(match_params.get("boss_drop_interval_mult", 1.0)), 0.01)
	_drops = FieldDrops.new(_drops_config, _grid.player_cells(), _grid.perimeter_labels(), drops_seed)
	_state.cell_changed.connect(_on_cell_changed)
	_cut_config = CutConfig.load_from_file()
	_skill_config = SkillConfig.load_from_file()
	_cooldowns = SkillCooldowns.new()
	_deck = Deck.new(_deck_ids(), drops_seed if drops_seed >= 0 else randi())
	_focus = FocusController.new(_skill_config)
	if character.has("focus_max_sec"):
		_focus.set_max_sec_override(float(character["focus_max_sec"]))
	_cut_actor = CutActor.new(_cut_config, CombatState.Side.PLAYER)
	_cut_flow = CutFlow.new(_skill_config, _cooldowns)
	_cut_flow.skill_chosen.connect(_on_skill_chosen)
	var brain_config: BossBrainConfig = BossBrainConfig.load_from_file()
	_apply_brain_params(brain_config)
	var hold_config: HoldSlotsConfig = HoldSlotsConfig.load_from_file()
	if hold_config == null:
		hold_config = HoldSlotsConfig.new()
	_boss = BossController.new(
		_state, _grid, _cut_config, _skill_config, brain_config, boss_drops_config, hold_config,
		drops_seed + 1 if drops_seed >= 0 else -1
	)
	_boss.set_player_step_cooldown(_player_step_cooldown)
	_boss.get_brain().cards = _boss_card_ids()
	_boss.get_actor().duration_mult = maxf(float(match_params.get("swing_speed_mult", 1.0)), 0.01)
	if not boss_set_override.is_empty() and not _boss.get_brain().use_set(boss_set_override):
		push_warning("CombatView: unknown boss weight set '%s'" % boss_set_override)
	_status = StatusEffects.new()
	_mover.set_status(_status)
	_boss.set_status(_status)
	_learning = BossLearning.new(brain_config.learning)
	_boss.set_learning(_learning)
	_boss.feinted.connect(_on_boss_feinted)
	_boss.get_actor().swing_started.connect(_on_boss_swing_started)
	_boss.get_actor().swing_cancelled.connect(_on_boss_swing_cancelled)
	_arbiter = SwingArbiter.new(_state, _grid, _cut_actor, _boss.get_actor(), _cut_config, _skill_config, _status)
	_arbiter.swing_resolved.connect(_on_swing_resolved)
	_arbiter.swing_interrupted.connect(_on_swing_interrupted)
	_drops.point_spawned.connect(_on_point_spawned.bind(CombatState.Side.PLAYER))
	_boss.get_drops().point_spawned.connect(_on_point_spawned.bind(CombatState.Side.ENEMY))
	_trait_host = TraitHost.new(make_trait_ctx(), _trait_specs(), drops_seed)
	_trait_host.on_match_start()
	_setup_passive(character)


func _exit_tree() -> void:
	if _trait_host != null:
		_trait_host.teardown_all()
	if _passive != null:
		_passive.teardown()


## The character passive of this match; null when none (Story 018).
func get_passive() -> BasePassive:
	return _passive


## Extra HP the passive heals after a WON match (computed when [signal match_ended] fires; 0 before
## that, after a loss, or without a passive). RunController adds it to the between-match heal.
func get_passive_heal() -> float:
	return _passive_heal


# match_params["character"] as a dictionary ({} when absent or not a dictionary).
func _character() -> Dictionary:
	var raw: Variant = match_params.get("character")
	if typeof(raw) == TYPE_DICTIONARY:
		return raw as Dictionary
	return {}


# Character step cooldown multiplier (> 0, else 1).
func _step_mult(character: Dictionary) -> float:
	var mult: float = float(character.get("step_cooldown_mult", 1.0))
	return mult if mult > 0.0 else 1.0


# Creates the character's passive and hooks it in at the two single points: the player actor's
# swing duration and the arbiter's player damage. Unknown id: PassiveRegistry warns, no passive.
func _setup_passive(character: Dictionary) -> void:
	var spec: Variant = character.get("passive")
	if typeof(spec) != TYPE_DICTIONARY:
		return
	var id: String = str((spec as Dictionary).get("id", ""))
	if id.is_empty():
		return
	_passive = PassiveRegistry.create(id)
	if _passive == null:
		return
	var params: Variant = (spec as Dictionary).get("params", {})
	_passive.setup(
		{"state": _state, "grid": _grid, "boss": _boss, "status": _status,
			"skill_config": _skill_config, "cut_config": _cut_config},
		(params as Dictionary) if typeof(params) == TYPE_DICTIONARY else {})
	_cut_actor.duration_modifier = Callable(_passive, "modify_swing_duration")
	_arbiter.player_damage_modifier = Callable(_passive, "modify_damage")
	_passive.on_match_start()


## Public-API context the traits work through (BossTrait documents the keys): the same
## dictionary the match's TraitHost was built with. Logic-free; DemoArgs uses it to set up a
## trait by hand for captures.
func make_trait_ctx() -> Dictionary:
	return {
		"state": _state, "grid": _grid, "player_drops": _drops, "boss_drops": _boss.get_drops(),
		"boss": _boss, "status": _status, "arbiter": _arbiter, "hold_getter": Callable(self, "get_hold"),
		"skill_config": _skill_config, "cut_config": _cut_config,
	}


# match_params["traits"] as an array ([] when absent; a non-array warns and counts as none).
func _trait_specs() -> Array:
	var raw: Variant = match_params.get("traits", [])
	if typeof(raw) != TYPE_ARRAY:
		push_warning("CombatView: match_params traits must be an array, ignored")
		return []
	return raw as Array


## The boss traits of this match (Story 014); empty host when the match has none.
func get_trait_host() -> TraitHost:
	return _trait_host


# A point landed on a half (bound side appended by the connect): traits hear it.
func _on_point_spawned(point: FieldPoint, side: int) -> void:
	if _trait_host != null:
		_trait_host.on_point_spawned(side, point)


# Builds the match's board from match_params["arena"] (Story 014) and installs it into the
# config; no-op without an arena or when it is unusable (the combat.json board stays).
func _apply_arena() -> void:
	var raw: Variant = match_params.get("arena")
	if typeof(raw) != TYPE_DICTIONARY or (raw as Dictionary).is_empty():
		return
	var spec: Dictionary = raw as Dictionary
	var arena_seed: int = int(match_params["arena_seed"]) if match_params.has("arena_seed") else randi()
	var arena_grid: BoardGrid = ArenaLibrary.grid_for_spec(spec, ArenaLibrary.load_from_file(), arena_seed)
	if arena_grid == null:
		return
	_config.use_grid(arena_grid)
	_arena_info = {"shape": str(spec.get("shape", "direct")), "variant": bool(spec.get("variant", false)), "seed": arena_seed}


## Arena of this match for the HUD: {shape (id, "direct" for an inline block, "" for the
## combat.json board), variant (bool), seed (int, -1 when none), cells_per_side (int)}.
func get_arena_info() -> Dictionary:
	var info: Dictionary = _arena_info.duplicate()
	info["cells_per_side"] = _grid.player_cells().size()
	return info


# Run match settings onto the freshly loaded brain config (before the BossController exists).
func _apply_brain_params(brain_config: BossBrainConfig) -> void:
	if match_params.has("boss_step_cooldown_sec"):
		push_warning("CombatView: boss_step_cooldown_sec is deprecated, use boss_step_cooldown_mult")
		brain_config.step_cooldown_sec = maxf(float(match_params["boss_step_cooldown_sec"]), 0.0)
	elif match_params.has("boss_step_cooldown_mult"):
		brain_config.step_cooldown_sec = maxf(_base_step_cooldown * float(match_params["boss_step_cooldown_mult"]), 0.0)
	brain_config.think_interval_sec = maxf(float(match_params.get("boss_think_interval_sec", brain_config.think_interval_sec)), 0.0)
	brain_config.reaction_sec = maxf(float(match_params.get("boss_reaction_sec", brain_config.reaction_sec)), 0.0)
	var wanted: String = str(match_params.get("brain_set", ""))
	if not wanted.is_empty():
		if brain_config.has_set(wanted):
			brain_config.active_set = wanted
		else:
			push_warning("CombatView: unknown brain_set '%s' in match params" % wanted)
	if match_params.has("boss_reaction_sec"):
		# The match value is more specific than the set's own movement.reaction_sec.
		brain_config.override_movement(brain_config.active_set, {"reaction_sec": brain_config.reaction_sec})
	if float(match_params.get("combo_chance", -1.0)) >= 0.0:
		brain_config.override_weight(brain_config.active_set, "combo_chance", float(match_params["combo_chance"]))
	if float(match_params.get("combo_gap_sec", -1.0)) >= 0.0:
		brain_config.override_weight(brain_config.active_set, "combo_gap_sec", float(match_params["combo_gap_sec"]))
	var movement_override: Variant = match_params.get("movement")
	if typeof(movement_override) == TYPE_DICTIONARY and not (movement_override as Dictionary).is_empty():
		brain_config.override_movement(brain_config.active_set, movement_override as Dictionary)


# Counts REAL time after a death, then emits match_ended once.
func _tick_end(delta: float) -> void:
	if _end_emitted or _state == null:
		return
	if _end_timer < 0.0:
		if not (_state.is_player_dead() or _state.is_enemy_dead()):
			return
		_end_timer = maxf(float(match_params.get("end_delay_sec", DEFAULT_END_DELAY_SEC)), 0.0)
	_end_timer -= delta
	if _end_timer <= 0.0:
		_end_emitted = true
		var won: bool = not _state.is_player_dead()
		_passive_heal = maxf(_passive.on_match_won(), 0.0) if (won and _passive != null) else 0.0
		match_ended.emit(won, _state.player_hp)


## The player's (board-scaled) step cooldown in seconds.
func get_player_step_cooldown() -> float:
	return _player_step_cooldown


## Player HP right now.
func get_player_hp() -> float:
	return _state.player_hp


## Boss name for the HUD: match_params name_key (translated), a legacy literal display_name, or "DUMMY".
func get_boss_name() -> String:
	var boss_name: String = RunConfig.match_name(match_params)
	return boss_name if not boss_name.is_empty() else DEFAULT_BOSS_NAME


## Story 018: the player's HUD name — the character's translated name when match_params["character"]
## has a name_key, else tr(TEXT_YOU) ("BẠN" / "YOU"). Used by the HP label and the unit marker.
func get_player_name() -> String:
	var name_key: String = str(_character().get("name_key", ""))
	return tr(name_key) if not name_key.is_empty() else tr(TEXT_YOU)


## Match label such as "Trận 2/4" from match_params (empty when none).
func get_match_label() -> String:
	return str(match_params.get("match_label", ""))


func _process(delta: float) -> void:
	_tick_end(delta)
	_hook_hold()
	if not freeze_time:
		# Cap the step so a frame hitch cannot skip a whole timing window.
		var real_step: float = minf(delta, _config.max_tick_sec)
		# The menu countdown runs on REAL time; it may close the menu this frame.
		_cut_flow.tick_real(real_step)
		# Simulation time is scaled down while the skill menu is open (slow motion); the boss
		# lives in the same scaled time.
		_update_focus(real_step)
		var step: float = real_step * _sim_scale()
		if step <= 0.0:
			# Full stop (Focus with scale 0): nothing in the simulation moves; real-time
			# things (menu, Focus clocks, match end) already ran above.
			queue_redraw()
			return
		_status.tick(step, _state)
		_mover.tick(step)
		var hold: HoldSlots = _get_hold()
		var held: int = 0 if hold == null else hold.get_occupied_count()
		_learning.tick(step, hold != null and hold.is_full())
		var burning: Array[Vector2i] = _status.burning_cells()
		_drops.set_blocked_cells(burning)
		_boss.get_drops().set_blocked_cells(burning)
		# Each side's drops avoid the cells the opponent's swing is about to cut.
		var boss_actor: CutActor = _boss.get_actor()
		_drops.set_danger_cells(boss_actor.get_cells() if boss_actor.is_swinging() else _no_cells())
		_boss.get_drops().set_danger_cells(_cut_actor.get_cells() if _cut_actor.is_swinging() else _no_cells())
		_drops.tick(step, _state.player_cell, held)
		_cooldowns.tick(step)
		_boss.tick(step, _cut_actor)
		_arbiter.tick(step)
		if hold != null:
			hold.tick_rot(step)
		# Traits run after the arbiter (they see this frame's resolutions) and only while both live.
		if not (_state.is_player_dead() or _state.is_enemy_dead()):
			_trait_host.on_tick(step)
		_age_flash(_feedback, step)
		_age_flash(_boss_feedback, step)
		_age_flash(_interrupt_flash, step)
		_age_flash(_feint_flash, step)
	queue_redraw()


# Real-time Focus bookkeeping for this frame: clocks, auto start, deselect / death ends.
func _update_focus(real_step: float) -> void:
	_focus.tick_real(real_step)
	var hold: HoldSlots = _get_hold()
	if _state.is_player_dead() or _state.is_enemy_dead():
		_focus.end(FocusController.REASON_DEATH)
		return
	var selected: bool = hold != null and not hold.get_selected_indices().is_empty()
	if _focus.is_active() and not selected:
		_focus.end(FocusController.REASON_DESELECTED)
	elif selected and _focus.is_ready() and not _cut_flow.is_menu_open():
		_focus.try_start()


# Simulation speed factor this frame: skill menu, else Focus, else 1.
func _sim_scale() -> float:
	if _cut_flow.is_menu_open():
		return _skill_config.menu_time_scale
	if _focus.is_active():
		return _focus.get_time_scale()
	return 1.0


func _no_cells() -> Array[Vector2i]:
	return []


# Counts a feedback dictionary's time_left down; clears it in place when over.
func _age_flash(flash: Dictionary, step: float) -> void:
	if flash.is_empty():
		return
	flash["time_left"] = float(flash["time_left"]) - step
	if float(flash["time_left"]) <= 0.0:
		flash.clear()


## How long the HIT/MISS marker stays on screen (UI timing, real-ish seconds of sim time).
const FEEDBACK_SEC: float = 0.8


## Story 016: true when the run may be paused now: not while the skill menu is open and not
## while the player's or the boss's swing has [member CombatConfig.pause_lockout_sec] or less
## left. No state change.
func can_pause() -> bool:
	if _cut_flow == null or _boss == null:
		return false
	if _cut_flow.is_menu_open():
		return false
	var lockout: float = _config.pause_lockout_sec if _config != null else 0.0
	for actor: CutActor in [_cut_actor, _boss.get_actor()]:
		if actor.is_swinging() and actor.get_time_left() <= lockout:
			return false
	return true


## The player's cut swing (one at a time).
func get_cut_actor() -> CutActor:
	return _cut_actor


## The skill-menu flow (IDLE / MENU).
func get_cut_flow() -> CutFlow:
	return _cut_flow


## Skill definitions and menu timing.
func get_skill_config() -> SkillConfig:
	return _skill_config


## Cut numbers (damage per cell, swing timing).
func get_cut_config() -> CutConfig:
	return _cut_config


## The player's Focus (pause while connecting points).
func get_focus() -> FocusController:
	return _focus


## The player's deck (shuffle bag; match_params["deck"] or the default deck).
func get_deck() -> Deck:
	return _deck


## The cards of the open card menu in order (empty when the menu is closed).
func get_hand() -> Array[String]:
	return _cut_flow.get_hand()


# match_params["deck"] ids that exist in cards.json; absent, invalid or empty = default deck.
func _deck_ids() -> Array[String]:
	var ids: Array[String] = []
	var raw: Variant = match_params.get("deck", [])
	if typeof(raw) == TYPE_ARRAY:
		for id: Variant in raw as Array:
			if _skill_config.has_skill(str(id)):
				ids.append(str(id))
			else:
				push_warning("CombatView: deck card '%s' unknown, dropped" % str(id))
	elif match_params.has("deck"):
		push_warning("CombatView: match_params deck must be an array, using the default deck")
	if ids.is_empty():
		ids = _skill_config.default_deck.duplicate()
	return ids


# match_params["boss_cards"] ids that exist; absent, invalid or empty = the basics (card_order).
func _boss_card_ids() -> Array[String]:
	var ids: Array[String] = []
	var raw: Variant = match_params.get("boss_cards", [])
	if typeof(raw) == TYPE_ARRAY:
		for id: Variant in raw as Array:
			if _skill_config.has_skill(str(id)) and not ids.has(str(id)):
				ids.append(str(id))
	elif match_params.has("boss_cards"):
		push_warning("CombatView: match_params boss_cards must be an array, using the basics")
	if ids.is_empty():
		ids = _skill_config.card_order.duplicate()
	return ids


## The player's skill cooldowns.
func get_skill_cooldowns() -> SkillCooldowns:
	return _cooldowns


## The hand (null until the hold view is ready).
func get_hold() -> HoldSlots:
	return _get_hold()


## Last resolved player cut for the HIT/MISS marker ({cells, hit, damage, cell, time_left});
## empty when nothing is showing.
func get_cut_feedback() -> Dictionary:
	return _feedback


## Labels of the current selection that a cut would use: the first hand_max_points in
## selection order (extra selected points are left selected).
func get_cut_selection_labels() -> Array[String]:
	var labels: Array[String] = []
	var hold: HoldSlots = _get_hold()
	if hold == null:
		return labels
	for index: int in hold.get_selected_indices():
		if labels.size() >= _cut_config.hand_max_points:
			break
		labels.append(hold.get_point(index).label)
	return labels


## True when the CONFIRM button should be on screen: >= 1 point selected, no menu open and
## nobody dead. (While a swing runs it is shown dimmed and pressing it does nothing.)
func is_confirm_visible() -> bool:
	var hold: HoldSlots = _get_hold()
	if hold == null or _state == null or _cut_flow.is_menu_open():
		return false
	if _state.is_player_dead() or _state.is_enemy_dead():
		return false
	return not hold.get_selected_indices().is_empty()


## Confirms the current selection as a cut. Returns false (nothing changes) when blocked
## (menu open, own swing running, dead, nothing selected) or when every covered cell is
## missing. Otherwise the used points leave the hand NOW (more than hand_max_points selected:
## the first hand_max_points in selection order are used, the rest stay selected); one
## point with single_point_opens_menu == false swings slash at once, else the skill menu opens.
func confirm_selection() -> bool:
	var hold: HoldSlots = _get_hold()
	if hold == null or not is_confirm_visible() or _cut_actor.is_swinging():
		return false
	var labels: Array[String] = get_cut_selection_labels()
	var cells: Array[Vector2i] = CutResolver.resolve_on_board(_grid, true, labels)
	if cells.is_empty():
		return false
	_focus.end(FocusController.REASON_CONFIRMED)
	var used: Array[int] = []
	for index: int in hold.get_selected_indices():
		if used.size() >= labels.size():
			break
		used.append(index)
	for index: int in used:
		hold.remove(index)
	if labels.size() == 1 and not _cut_config.single_point_opens_menu:
		_begin_cut(SkillConfig.FALLBACK_SKILL, cells)
	else:
		_cut_flow.open_menu(labels, cells, _deck.draw(_skill_config.hand_size))
	return true


# Hand slot cleared while the player stands on a field point: pick it up right away.
func _hook_hold() -> void:
	if _hold_hooked:
		return
	var hold: HoldSlots = _get_hold()
	if hold == null:
		return
	_hold_hooked = true
	hold.slot_cleared.connect(_on_slot_cleared)


func _on_slot_cleared(_index: int, _point: FieldPoint) -> void:
	var hold: HoldSlots = _get_hold()
	if hold == null or _state.is_player_dead():
		return
	var point: FieldPoint = _drops.pick_up_at(_state.player_cell, true)
	if point != null:
		hold.place_in_first_free(point)


func _on_skill_chosen(skill_id: String, _labels: Array[String], cells: Array[Vector2i]) -> void:
	_begin_cut(skill_id, cells)


func _begin_cut(skill_id: String, cells: Array[Vector2i]) -> void:
	if _cut_actor.begin_swing(cells, skill_id, true):
		_cooldowns.start(skill_id, float(_skill_config.get_skill(skill_id).get("cooldown_sec", 0.0)))


# Arbiter result of either side: stores the HIT/MISS marker for that side's cut.
func _on_swing_resolved(side: int, result: Dictionary) -> void:
	var feedback: Dictionary = {
		"cells": result["cells"], "hit": bool(result["hit"]), "damage": float(result["damage"]),
		"cell": result["cell"], "time_left": FEEDBACK_SEC,
	}
	if side == CombatState.Side.PLAYER:
		_feedback = feedback
		_trait_host.on_player_swing_resolved(result)
		_trait_host.on_boss_damaged(float(result["damage"]))
	else:
		_boss_feedback = feedback
		_learning.on_boss_swing_resolved(bool(result["hit"]))
		_trait_host.on_boss_swing_resolved(result)


func _on_swing_interrupted(victim_side: int, cells: Array[Vector2i], _skill_id: String) -> void:
	_interrupt_flash = {"side": victim_side, "cells": cells, "time_left": FEEDBACK_SEC}
	if victim_side == CombatState.Side.ENEMY:
		_learning.on_player_interrupted_boss()


func _on_boss_swing_started(cells: Array[Vector2i], skill_id: String, _duration: float) -> void:
	_learning.on_boss_swing_started(cells, _state.player_cell)
	if _trait_host != null:
		_trait_host.on_boss_swing_started(cells, skill_id)


func _on_boss_swing_cancelled(_cells: Array[Vector2i], _skill_id: String) -> void:
	_learning.on_boss_swing_cancelled()


func _on_boss_feinted(cells: Array[Vector2i], _labels: Array[String]) -> void:
	_feint_flash = {"cells": cells, "time_left": FEEDBACK_SEC}


## The shared burning cells / pins.
func get_status() -> StatusEffects:
	return _status


## What the boss has learned about the player.
func get_learning() -> BossLearning:
	return _learning


## Last feint ({cells, time_left}); empty when nothing is showing.
func get_feint_flash() -> Dictionary:
	return _feint_flash


## The boss agent (hand, drops, mover, actor, brain).
func get_boss() -> BossController:
	return _boss


## The boss's queued second swing of a combo ({cells, duration}); empty when none is queued.
func get_boss_queued_swing() -> Dictionary:
	var actor: CutActor = _boss.get_actor()
	if not actor.has_queued():
		return {}
	return {"cells": actor.get_queued_cells(), "duration": actor.get_queued_duration()}


## The swing arbiter (time order and interrupt).
func get_arbiter() -> SwingArbiter:
	return _arbiter


## Last resolved boss cut, to show on the player's half ({cells, hit, damage, cell,
## time_left}); empty when nothing is showing.
func get_boss_feedback() -> Dictionary:
	return _boss_feedback


## Last interrupt ({side = victim side, cells = cancelled swing's cells, time_left}); empty
## when nothing is showing. The view draws "NGẮT" from it.
func get_interrupt_flash() -> Dictionary:
	return _interrupt_flash


## The board (size, shape, halves) every view of the arena shares.
func get_grid() -> BoardGrid:
	return _grid


## The combat numbers and unit cells.
func get_state() -> CombatState:
	return _state


## The player's step mover (cooldown).
func get_mover() -> UnitMover:
	return _mover


## Field points of the player's half.
func get_drops() -> FieldDrops:
	return _drops


## Drop tuning in use (freshness total etc.).
func get_drops_config() -> FieldDropsConfig:
	return _drops_config


## Tries one step of the player in [param direction] (Vector2i.UP/DOWN/LEFT/RIGHT).
## Returns false on cooldown, wall, when dead, or while Focus locks movement; nothing is queued.
func try_step_player(direction: Vector2i) -> bool:
	if _focus.is_active() and _focus.locks_movement():
		return false
	return _mover.try_step(direction)


func _get_hold() -> HoldSlots:
	var view := get_node_or_null(hold_slots_view_path) as HoldSlotsView
	return null if view == null else view.get_slots()


# Stepping onto a point picks it up into the first free hand slot.
func _on_cell_changed(side: int, _old_cell: Vector2i, new_cell: Vector2i) -> void:
	if side != CombatState.Side.PLAYER:
		return
	_learning.on_player_moved(new_cell)
	var hold: HoldSlots = _get_hold()
	if hold == null:
		return
	var point: FieldPoint = _drops.pick_up_at(new_cell, not hold.is_full())
	if point != null:
		hold.place_in_first_free(point)


func _draw() -> void:
	if _state == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	_draw_board(vp)
	_draw_hud(vp)
	_draw_enemy(vp)
	_draw_boss_ring(vp)
	_draw_cooldown_ring(vp)
	_draw_player_marker(vp)


func _draw_board(vp: Vector2) -> void:
	var board: Rect2 = ScreenLayout.board_rect(_grid, vp)
	# Cell by cell; missing cells are simply not drawn (the board looks cut out there).
	for cell: Vector2i in _grid.player_cells():
		_draw_cell(ScreenLayout.cell_rect(_grid, vp, cell), PLAYER_HALF_TINT)
	for cell: Vector2i in _grid.enemy_cells():
		_draw_cell(ScreenLayout.cell_rect(_grid, vp, cell), ENEMY_HALF_TINT)
	var dx: float = ScreenLayout.divider_x(_grid, vp)
	draw_line(Vector2(dx, board.position.y - 6.0), Vector2(dx, board.end.y + 6.0), DIVIDER_COLOR, 6.0)


func _draw_cell(rect: Rect2, tint: Color) -> void:
	draw_rect(rect, tint)
	draw_rect(rect, GRID_LINE_COLOR, false, 2.0)


# Top band: player HP bar on the left half, boss HP bar on the right half.
func _draw_hud(vp: Vector2) -> void:
	var hud: Rect2 = ScreenLayout.hud_rect(vp)
	var gap: float = hud.size.x * HUD_GAP_RATIO
	var half_w: float = (hud.size.x - gap) * 0.5 - PAD * 2.0
	var text_y: float = hud.position.y + PAD + FONT_SIZE
	var bar_y: float = text_y + 8.0
	var left_x: float = hud.position.x + PAD
	var right_x: float = hud.position.x + PAD + half_w + PAD * 2.0 + gap
	var hp_text: String = tr(TEXT_UNIT_HP) % [get_player_name(), ceili(_state.player_hp), ceili(_state.player_max_hp)]
	_draw_text(hp_text, Vector2(left_x, text_y), half_w, HORIZONTAL_ALIGNMENT_LEFT)
	_draw_bar(Rect2(Vector2(left_x, bar_y), Vector2(half_w, BAR_HEIGHT)), _state.player_hp / _state.player_max_hp, PLAYER_HP_COLOR)
	var enemy_text: String = tr(TEXT_UNIT_DEAD) % get_boss_name()
	if not _state.is_enemy_dead():
		enemy_text = tr(TEXT_UNIT_HP) % [get_boss_name(), ceili(_state.enemy_hp), ceili(_state.enemy_max_hp)]
	_draw_text(enemy_text, Vector2(right_x, text_y), half_w, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_bar(Rect2(Vector2(right_x, bar_y), Vector2(half_w, BAR_HEIGHT)), _state.enemy_hp / _state.enemy_max_hp, HP_COLOR)
	_draw_boss_hand(Vector2(right_x, text_y), half_w)


# The boss's held points as small tags in the HUD band, in the text row above its HP bar,
# left-aligned at [param origin].x (its HP text is right-aligned, so they do not collide as
# long as hand_size * (tag + gap) fits the left of the text). Empty slots are faint outlines.
func _draw_boss_hand(origin: Vector2, width: float) -> void:
	var hand: HoldSlots = _boss.get_hand()
	var count: int = hand.get_slot_count()
	var tag_w: float = HAND_TAG_WIDTH
	var top: float = origin.y - FONT_SIZE + HAND_TAG_TOP_OFFSET
	var room: float = width - HAND_TEXT_RESERVE
	if count * (tag_w + HAND_TAG_GAP) > room:
		tag_w = maxf(room / count - HAND_TAG_GAP, 12.0)
	for i: int in count:
		var rect := Rect2(Vector2(origin.x + i * (tag_w + HAND_TAG_GAP), top), Vector2(tag_w, HAND_TAG_HEIGHT))
		var point: FieldPoint = hand.get_point(i)
		if point == null:
			draw_rect(rect, HAND_EMPTY_COLOR, false, 2.0)
			continue
		draw_rect(rect, HAND_TAG_BACK)
		draw_rect(rect, HP_COLOR, false, 2.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, HAND_TAG_HEIGHT * 0.5 + HAND_FONT_SIZE * 0.35), point.label, HORIZONTAL_ALIGNMENT_CENTER, tag_w, HAND_FONT_SIZE, TEXT_COLOR)


func _draw_enemy(vp: Vector2) -> void:
	var dead: bool = _state.is_enemy_dead()
	var cell: Vector2 = ScreenLayout.cell_size(_grid, vp)
	var body_size := Vector2(cell.x * ENEMY_BODY_WIDTH_RATIO, cell.y * ENEMY_BODY_HEIGHT_RATIO)
	var body := Rect2(ScreenLayout.cell_center(_grid, vp, _state.enemy_cell) - body_size * 0.5, body_size)
	draw_rect(body, ENEMY_DEAD_COLOR if dead else ENEMY_COLOR)
	draw_rect(body, TEXT_COLOR, false, 3.0)
	if dead:
		draw_line(body.position, body.end, TEXT_COLOR, 6.0)
		draw_line(Vector2(body.end.x, body.position.y), Vector2(body.position.x, body.end.y), TEXT_COLOR, 6.0)


# Ring around the player's feet: full right after a step, shrinks to nothing; hidden when ready.
func _draw_cooldown_ring(vp: Vector2) -> void:
	var fraction: float = _mover.get_cooldown_fraction()
	if fraction <= 0.0:
		return
	var c: Vector2 = ScreenLayout.cell_center(_grid, vp, _state.player_cell)
	var radius: float = _marker_radius(vp) + ScreenLayout.cell_size(_grid, vp).y * RING_GAP_RATIO
	draw_arc(c, radius, 0.0, TAU, RING_POINTS, RING_BACK_COLOR, RING_WIDTH)
	draw_arc(c, radius, -PI * 0.5, -PI * 0.5 + TAU * fraction, RING_POINTS, RING_COLOR, RING_WIDTH)


# Ring around the boss's body: full right after its step, shrinks to nothing; hidden when ready.
func _draw_boss_ring(vp: Vector2) -> void:
	var fraction: float = _boss.get_mover().get_cooldown_fraction()
	if fraction <= 0.0 or _state.is_enemy_dead():
		return
	var c: Vector2 = ScreenLayout.cell_center(_grid, vp, _state.enemy_cell)
	var radius: float = ScreenLayout.cell_size(_grid, vp).y * BOSS_RING_RADIUS_RATIO
	draw_arc(c, radius, 0.0, TAU, RING_POINTS, RING_BACK_COLOR, BOSS_RING_WIDTH)
	draw_arc(c, radius, -PI * 0.5, -PI * 0.5 + TAU * fraction, RING_POINTS, HP_COLOR, BOSS_RING_WIDTH)


func _draw_player_marker(vp: Vector2) -> void:
	var c: Vector2 = ScreenLayout.cell_center(_grid, vp, _state.player_cell)
	var radius: float = _marker_radius(vp)
	var color: Color = ENEMY_DEAD_COLOR if _state.is_player_dead() else PLAYER_COLOR
	draw_circle(c, radius, color)
	draw_arc(c, radius, 0.0, TAU, 32, TEXT_COLOR, 3.0)
	var font_size: int = maxi(int(radius * MARKER_FONT_RATIO), 8)
	var text: String = get_player_name()
	var max_width: float = radius * 2.0 * MARKER_TEXT_FILL
	# Auto-fit (Story 018): shrink the font to MARKER_MIN_FONT_SIZE, then fall back to the first word.
	while font_size > MARKER_MIN_FONT_SIZE and _text_width(text, font_size) > max_width:
		font_size -= 1
	if _text_width(text, font_size) > max_width and text.contains(" "):
		text = text.get_slice(" ", 0)
	draw_string(ThemeDB.fallback_font, c + Vector2(-radius, font_size * 0.4), text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, Color.WHITE)


func _marker_radius(vp: Vector2) -> float:
	return ScreenLayout.cell_size(_grid, vp).y * MARKER_RADIUS_RATIO


# Pixel width of [param text] in the fallback font at [param font_size].
func _text_width(text: String, font_size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x


func _draw_bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, BAR_BACK)
	var fill := Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)
	draw_rect(Rect2(rect.position, fill), color)
	draw_rect(rect, TEXT_COLOR, false, 2.0)


func _draw_text(text: String, pos: Vector2, width: float, align: HorizontalAlignment) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, align, width, FONT_SIZE, TEXT_COLOR)
