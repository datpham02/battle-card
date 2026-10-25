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
## Story 024: PLACING mode logic (piece ghost, rotation, snap); idle outside of it.
var _placement: PlacementController
## Story 024: the piece consumed when the card menu opened ({point, slot}); returned to its slot on cancel.
var _pending_piece: FieldPoint = null
var _pending_slot: int = -1
## Story 028: the pieces of the cast being built (piece 1 from the moment the card menu opens, piece 2 once
## joined), the featured shape of the match ({cells, bonus} or {} = off), the second piece's bag point /
## slot while it is attached, and the last refused join ({cells, reason, time_left}) for the red ghost.
var _plan: CastPlan = CastPlan.new()
var _featured: Dictionary = {}
var _join_point: FieldPoint = null
var _join_slot: int = -1
var _join_refusal: Dictionary = {}
## True while the pending piece is being taken out of the bag, so the slot-cleared hook does not
## auto-pick a piece lying under the player into the slot that must stay free for a cancel.
var _consuming: bool = false
## Story 024 touch-first placing: true while a finger / the left mouse button drags a piece, and the
## last pointer position of that drag (viewport pixels, the finger itself, not the lifted ghost).
var _dragging: bool = false
var _drag_point: Vector2 = Vector2.ZERO
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
## The character signature skill of this match (Story 021); null without one or with an unknown id.
var _signature: BaseSignature = null
## Formation map of the enemy half (Story 029); null without a signature (it only feeds the signature).
var _formation: FormationMap = null
## True once the formation map completed and the signature has not been activated yet.
var _signature_ready_flag: bool = false
## Seconds left of the completion flash (real time); 0 = none.
var _formation_flash_left: float = 0.0
var _signature_name_key: String = ""
var _signature_was_active: bool = false
## Story 029 Phần D: the character's signature cooldown (characters.json signature.cooldown_sec, >= 0)
## and the seconds of it left (scaled sim time; starts when the effect ends, 0 at match start).
var _signature_cooldown_sec: float = 0.0
var _signature_cooldown_left: float = 0.0
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
## Story 021: the player activated the signature [param id] (the charge was reset).
signal signature_activated(id: String)
## Story 021: the timed effect of the signature [param id] ran out.
signal signature_ended(id: String)
## Story 029: the signature just became ready through the map (every real enemy cell lit at once and
## the cooldown over — reached on a cover or when the cooldown ran out). The map is NOT reset here
## (Phần D: activation resets it).
signal formation_completed

## Real seconds between a death and [signal match_ended] when match_params has no end_delay_sec.
const DEFAULT_END_DELAY_SEC: float = 1.5
const DEFAULT_BOSS_NAME: String = "DUMMY"
## Real seconds the red "refused" ghost of a join stays on screen.
const JOIN_REFUSAL_SEC: float = 1.2
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
	var boss_drop_mult: float = maxf(float(match_params.get("boss_drop_interval_mult", 1.0)), 0.01)
	boss_drops_config.spawn_interval_sec *= boss_drop_mult
	boss_drops_config.piece_spawn_interval_sec *= boss_drop_mult # Story 025: the boss drops pieces too
	_drops = FieldDrops.new(_drops_config, _grid.player_cells(), _grid.perimeter_labels(), drops_seed)
	# Story 024: the player's half drops puzzle pieces (the boss's drops stay classic labels).
	_drops.enable_pieces(PieceLibrary.load_from_file(), str(match_params.get("chapter_id", "")), _grid, drops_seed)
	_drops.place_start_pieces(_state.player_cell)
	_placement = PlacementController.new(_grid)
	_plan.init(_config.max_pieces_per_cast, _config.max_cast_cells)
	_featured = ArenaLibrary.load_from_file().featured_for_match(match_params, _grid)
	_state.cell_changed.connect(_on_cell_changed)
	_cut_config = CutConfig.load_from_file()
	_skill_config = SkillConfig.load_from_file()
	_cooldowns = SkillCooldowns.new()
	_deck = Deck.from_array(_deck_ids(),drops_seed if drops_seed >= 0 else randi())
	_focus = FocusController.new(_skill_config)
	if character.has("focus_max_sec"):
		_focus.set_max_sec_override(float(character["focus_max_sec"]))
	_cut_actor = CutActor.new(_cut_config, CombatState.Side.PLAYER)
	_cut_flow = CutFlow.new(_skill_config, _cooldowns)
	_cut_flow.level_of = Callable(self, "get_card_level")
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
	# Story 025: the boss plays pieces too (placement checked on the player's half).
	_boss.enable_pieces(
		PieceLibrary.load_from_file(), str(match_params.get("chapter_id", "")), drops_seed + 2 if drops_seed >= 0 else -1
	)
	_boss.set_player_step_cooldown(_player_step_cooldown)
	_boss.get_brain().cards = _boss_card_ids()
	_boss.get_actor().duration_mult = maxf(float(match_params.get("swing_speed_mult", 1.0)), 0.01)
	if not boss_set_override.is_empty() and not _boss.get_brain().use_set(boss_set_override):
		push_warning("CombatView: unknown boss weight set '%s'" % boss_set_override)
	_status = StatusEffects.new()
	_config.configure_status(_status)
	_mover.set_status(_status)
	_boss.set_status(_status)
	_learning = BossLearning.new(brain_config.learning)
	_boss.set_learning(_learning)
	_boss.feinted.connect(_on_boss_feinted)
	_boss.get_actor().swing_started.connect(_on_boss_swing_started)
	_boss.get_actor().swing_cancelled.connect(_on_boss_swing_cancelled)
	_arbiter = SwingArbiter.new(_state, _grid, _cut_actor, _boss.get_actor(), _cut_config, _skill_config, _status)
	# Story 023: flat boss defense (match key boss_defense), default execute threshold, brain min runes.
	_arbiter.boss_defense = maxf(float(match_params.get("boss_defense", 0.0)), 0.0)
	_arbiter.execute_ratio = _config.execute_ratio
	_boss.get_brain().min_runes = maxi(int(match_params.get("boss_min_runes", 0)), 0)
	_arbiter.swing_resolved.connect(_on_swing_resolved)
	_arbiter.swing_interrupted.connect(_on_swing_interrupted)
	_drops.point_spawned.connect(_on_point_spawned.bind(CombatState.Side.PLAYER))
	_boss.get_drops().point_spawned.connect(_on_point_spawned.bind(CombatState.Side.ENEMY))
	_trait_host = TraitHost.new(make_trait_ctx(), _trait_specs(), drops_seed)
	_trait_host.on_match_start()
	_setup_passive(character)
	_setup_signature(character)


func _exit_tree() -> void:
	if _trait_host != null:
		_trait_host.teardown_all()
	if _passive != null:
		_passive.teardown()
	if _signature != null:
		_signature.teardown()
		_signature = null


# Story 021: creates the character's signature (characters.json `signature: {id, name_key, desc_key,
# params}`) and hooks it in: the arbiter's player cell-count / last damage modifiers, the player
# mover's step cooldown scale, and the hit callback. Unknown id: SignatureRegistry warns, none.
func _setup_signature(character: Dictionary) -> void:
	var spec: Variant = character.get("signature")
	if typeof(spec) != TYPE_DICTIONARY:
		return
	var dict: Dictionary = spec as Dictionary
	var id: String = str(dict.get("id", ""))
	if id.is_empty():
		return
	_signature = SignatureRegistry.create(id)
	if _signature == null:
		return
	var params: Variant = dict.get("params", {})
	var enemy_cells: Array[Vector2i] = _grid.enemy_cells()
	_formation = FormationMap.new().init(enemy_cells, _config.formation_fade_for(enemy_cells.size()))
	_signature.setup(
		{"state": _state, "grid": _grid, "boss": _boss, "status": _status,
			"skill_config": _skill_config, "cut_config": _cut_config, "cooldowns": _cooldowns,
				"formation": _formation},
		(params as Dictionary) if typeof(params) == TYPE_DICTIONARY else {})
	_signature_name_key = str(dict.get("name_key", ""))
	var cooldown: Variant = dict.get("cooldown_sec", 0.0)
	_signature_cooldown_sec = maxf(float(cooldown), 0.0) if (typeof(cooldown) == TYPE_FLOAT or typeof(cooldown) == TYPE_INT) else 0.0
	_signature_cooldown_left = 0.0
	_arbiter.player_cells_modifier = Callable(_signature, "modify_cells")
	_arbiter.player_signature_modifier = Callable(_signature, "modify_damage")
	_mover.cooldown_scale = Callable(_signature, "step_cooldown_scale")


## Story 021: the signature of this match; null without a character signature or with an unknown id.
func get_signature() -> BaseSignature:
	return _signature


## Story 029: the formation map of the enemy half (lit cells, fade ratios); null without a signature.
func get_formation() -> FormationMap:
	return _formation


## Story 029: completion flash 1..0 (1 right after the map completed, 0 = none / over); real time.
func get_formation_flash() -> float:
	var length: float = _config.formation_flash_sec
	if length <= 0.0 or _formation_flash_left <= 0.0:
		return 0.0
	return clampf(_formation_flash_left / length, 0.0, 1.0)


## Story 021 / 029: 0..1 progress to the signature: 1.0 when ready, else lit cells / real enemy cells of
## the formation map; 0 without a signature.
func get_signature_charge() -> float:
	if _signature == null or _formation == null:
		return 0.0
	if is_signature_ready():
		return 1.0
	return float(_formation.lit_count()) / float(maxi(_formation.total(), 1))


## Story 021 / 029: true once the signature became ready (map complete with the cooldown over; kept until
## used, fading cells do not revoke it) and no timed effect is running.
func is_signature_ready() -> bool:
	return _signature != null and _signature_ready_flag and not _signature.is_active()


## Story 029 Phần D: seconds of the signature cooldown left (0 when over, not started or no signature).
func get_signature_cooldown_left() -> float:
	return _signature_cooldown_left if _signature != null else 0.0


## Story 029 Phần D: full cooldown of this character's signature (characters.json signature.cooldown_sec).
func get_signature_cooldown_sec() -> float:
	return _signature_cooldown_sec if _signature != null else 0.0


## Story 021: true while the signature's timed effect runs (always false for instant ones).
func is_signature_active() -> bool:
	return _signature != null and _signature.is_active()


## Story 021: seconds of the timed effect left (0 when inactive / instant / none).
func get_signature_time_left() -> float:
	return _signature.time_left() if _signature != null else 0.0


## Story 021: full length of the timed effect (0 for instant skills or none).
func get_signature_duration() -> float:
	return _signature.duration() if _signature != null else 0.0


## Story 021: translated signature name ("" without one).
func get_signature_name() -> String:
	return tr(_signature_name_key) if not _signature_name_key.is_empty() else ""


## Story 021: true when [method activate_signature] would fire now: ready, both units alive, the
## battle not frozen, no skill menu open and Focus not locking the d-pad (the same lock as steps).
func can_activate_signature() -> bool:
	if not is_signature_ready() or freeze_time or _state == null:
		return false
	if _state.is_player_dead() or _state.is_enemy_dead():
		return false
	if _cut_flow.is_menu_open():
		return false
	if is_movement_locked():
		return false
	return true


## Story 021 / 029: activates the signature when [method can_activate_signature]; the ready flag clears,
## the formation map is reset (Phần D: every use needs a freshly completed map) and
## [signal signature_activated] fires. An instant signature ends at once (cooldown starts now); a timed
## one starts its cooldown when its effect ends. Returns false (nothing changes) otherwise.
func activate_signature() -> bool:
	if not can_activate_signature():
		return false
	_signature.activate()
	_signature_ready_flag = false
	_formation.reset()
	_signature_was_active = _signature.is_active()
	signature_activated.emit(_signature.get_id())
	if not _signature_was_active:
		_end_signature_effect()
	return true


## Dev/capture only (Story 021 / 029): ratio >= 1 sets the ready flag (and clears any cooldown); below 1
## it lights round(ratio x total) enemy cells (grid order) at a full timer and clears the ready flag.
func debug_set_signature_charge(ratio: float) -> void:
	if _formation == null:
		return
	if ratio >= 1.0:
		_signature_cooldown_left = 0.0
		_signature_ready_flag = true
		return
	_signature_ready_flag = false
	_formation.reset()
	var cells: Array[Vector2i] = _grid.enemy_cells()
	_formation.cover(cells.slice(0, roundi(clampf(ratio, 0.0, 1.0) * float(_formation.total()))))


## Dev/capture only (Story 029 Phần D): sets the cooldown left to [param sec] (>= 0). Above 0 it clears
## the ready flag (ready needs the cooldown over); 0 re-checks readiness at once.
func debug_set_signature_cooldown(sec: float) -> void:
	if _signature == null:
		return
	_signature_cooldown_left = maxf(sec, 0.0)
	if _signature_cooldown_left > 0.0:
		_signature_ready_flag = false
	else:
		_check_signature_ready()


# Story 029: a player swing arrived (hit or miss): lights its cells, then re-checks readiness (the map
# keeps building during the cooldown; Phần D: completion no longer resets it).
func _cover_formation(cells: Array[Vector2i]) -> void:
	if _formation == null:
		return
	_formation.cover(cells)
	_check_signature_ready()


# Story 029 Phần D: the one readiness check (on every cover and when the cooldown reaches 0): not yet
# ready, no effect running, cooldown over and the map fully lit -> ready (kept until used), flash and
# formation_completed.
func _check_signature_ready() -> void:
	if _signature == null or _formation == null or _signature_ready_flag or _signature.is_active():
		return
	if _signature_cooldown_left > 0.0 or not _formation.is_complete():
		return
	_signature_ready_flag = true
	_formation_flash_left = _config.formation_flash_sec
	formation_completed.emit()


# Story 021 / 029: the signature's effect ended (instant: right after activation; timed: when its timer
# ran out): reports it and starts the cooldown — the one place the cooldown starts.
func _end_signature_effect() -> void:
	_signature_was_active = false
	_signature_cooldown_left = _signature_cooldown_sec
	signature_ended.emit(_signature.get_id())
	if _signature_cooldown_left <= 0.0:
		_check_signature_ready()


# Ticks the signature's timer and cooldown with simulation time; reports the end of a timed effect.
# The cooldown reaching 0 re-checks readiness (map already full -> ready at once).
func _tick_signature(step: float) -> void:
	if _signature == null:
		return
	if _signature_cooldown_left > 0.0 and step > 0.0:
		_signature_cooldown_left = maxf(_signature_cooldown_left - step, 0.0)
		if _signature_cooldown_left <= 0.0:
			_check_signature_ready()
	_signature.tick(step)
	if _signature_was_active and not _signature.is_active():
		_end_signature_effect()


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
		"boss": _boss, "status": _status, "arbiter": _arbiter, "hold_getter": Callable(self, "get_hold"), "player_mover": _mover,
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
	if match_params.has("boss_root_while_swinging"):
		brain_config.root_while_swinging = bool(match_params["boss_root_while_swinging"])
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
		_age_refusal(real_step)
		# Simulation time is scaled down while the skill menu is open (slow motion); the boss
		# lives in the same scaled time.
		_update_focus(real_step)
		_formation_flash_left = maxf(_formation_flash_left - real_step, 0.0)
		var step: float = real_step * _sim_scale()
		if step <= 0.0:
			# Full stop (Focus with scale 0): nothing in the simulation moves; real-time
			# things (menu, Focus clocks, match end) already ran above.
			queue_redraw()
			return
		_status.tick(step, _state)
		_tick_signature(step)
		if _formation != null:
			_formation.tick(step)
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
		_drop_placement()
		return
	_sync_placement()
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
	if _placement != null and _placement.is_placing():
		# Story 024: PLACING without Focus (on cooldown) still slows the match.
		return _skill_config.menu_time_scale
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
## The combat config of this match (Story 021: the HUD reads the signature hotkey from it).
func get_config() -> CombatConfig:
	return _config


func get_focus() -> FocusController:
	return _focus


## The player's deck (shuffle bag; match_params["deck"] or the default deck).
func get_deck() -> Deck:
	return _deck


## The cards of the open card menu in order (empty when the menu is closed).
func get_hand() -> Array[String]:
	return _cut_flow.get_hand()


# match_params["deck"] ids that exist in cards.json; absent, invalid or empty = default deck.
func _deck_ids() -> Array:
	# Story 020: entries are ids (level 1) or {id, level} dictionaries; Deck.from_array takes both.
	var ids: Array = []
	var raw: Variant = match_params.get("deck", [])
	if typeof(raw) == TYPE_ARRAY:
		for entry: Variant in raw as Array:
			var id: String = str((entry as Dictionary).get("id", "")) if typeof(entry) == TYPE_DICTIONARY else str(entry)
			if _skill_config.has_skill(id):
				ids.append(entry)
			else:
				push_warning("CombatView: deck card '%s' unknown, dropped" % id)
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


## Story 024: the PLACING logic (ghost cells, rotation, state); never null after _ready.
func get_placement() -> PlacementController:
	return _placement


## Story 024: true while a piece is being placed (a bag slot is selected, the card menu is closed).
func is_placing() -> bool:
	return _placement != null and _placement.is_placing()


## Story 024: true when the d-pad / signature are locked: Focus locks movement while active, and so
## does PLACING (also when Focus is on cooldown and the match only runs slowed).
func is_movement_locked() -> bool:
	if _focus != null and _focus.is_active() and _focus.locks_movement():
		return true
	return is_placing()


## Story 024: the piece being placed in its current rotation, null when not placing.
func get_placing_piece() -> Piece:
	return _placement.get_piece() if is_placing() else null


## True when the CONFIRM button should be on screen: a piece is being placed, no menu open and
## nobody dead. (It is dimmed when the ghost is off the enemy half or while a swing runs.)
func is_confirm_visible() -> bool:
	if _placement == null or _state == null or _cut_flow.is_menu_open():
		return false
	if _state.is_player_dead() or _state.is_enemy_dead():
		return false
	return _placement.is_placing()


## True when confirming would open the card menu now: placing, ghost on a valid placement, no own
## swing running.
func can_confirm_placement() -> bool:
	if _cut_flow.is_menu_open():
		return can_join_piece() and is_placing() and _placement.can_confirm() and _fits_cap(_placement.get_cells())
	return is_confirm_visible() and _placement.can_confirm() and not _cut_actor.is_swinging()


## Story 024: selects the piece in bag slot [param index] and enters PLACING (the selection set of the
## hand holds exactly that slot, so Focus starts / ends through _update_focus as before). Selecting
## the slot that is already being placed rotates the piece instead when [param rotate_if_selected].
## Returns false (nothing changes) for an empty / rotten slot, an open menu or a dead unit.
func select_piece(index: int, rotate_if_selected: bool = true) -> bool:
	var hold: HoldSlots = _get_hold()
	var joining: bool = _cut_flow.is_menu_open()
	if hold == null or _state.is_player_dead() or _state.is_enemy_dead():
		return false
	if joining and not can_join_piece():
		return false
	var piece: Piece = hold.get_piece(index)
	if piece == null or not piece.placeable():
		return false
	if is_placing() and _placement.get_slot() == index:
		return rotate_piece() if rotate_if_selected else true
	hold.clear_selection()
	hold.toggle_selected(index)
	_join_refusal = {}
	var blocked: Array[Vector2i] = []
	if joining:
		blocked = _plan.cells()
	return _placement.begin(index, piece, blocked)


## Rotates the piece being placed 90 degrees (keeps the anchor if still valid, else re-snaps).
func rotate_piece() -> bool:
	if not is_placing():
		return false
	_placement.rotate()
	_store_rotation()
	return true


## Aims the ghost at board cell [param cell] (NO_CELL / own half = off the board).
func aim_at_cell(cell: Vector2i) -> bool:
	return is_placing() and _placement.move_to(cell)


## Aims the ghost at viewport point [param pos] (a tap). [param lift] raises the aimed point by that
## many pixels (a drag keeps the ghost above the finger); a point above the board but over it
## horizontally clamps to the board's top edge when the finger itself is on the board.
func aim_at_position(pos: Vector2, lift: float = 0.0) -> bool:
	if not is_placing():
		return false
	var vp: Vector2 = get_viewport_rect().size
	var point := Vector2(pos.x, pos.y - lift)
	var board: Rect2 = ScreenLayout.board_rect(_grid, vp)
	if lift > 0.0 and board.has_point(pos) and point.y < board.position.y:
		point.y = board.position.y + 1.0
	return _placement.move_to(ScreenLayout.cell_at(_grid, vp, point))


## Pixels the dragged ghost floats above the finger (hold_slots.json drag_lift_px).
func get_drag_lift_px() -> float:
	var view := get_node_or_null(hold_slots_view_path) as HoldSlotsView
	return 0.0 if view == null else view.get_config().drag_lift_px


## Touch-first: starts dragging the piece in bag slot [param slot] with the finger at [param pos]
## (selects it, enters PLACING and puts the ghost above the finger). False when the slot cannot be
## placed (nothing changes).
func begin_drag(slot: int, pos: Vector2) -> bool:
	if not select_piece(slot, false):
		return false
	_dragging = true
	_drag_point = pos
	_placement.move_to(BoardGrid.NO_CELL)
	aim_at_position(pos, get_drag_lift_px())
	return true


## Moves the finger of the running drag to [param pos]; the ghost follows, [member drag_lift_px] above.
func drag_to(pos: Vector2) -> bool:
	if not _dragging or not is_placing():
		return false
	_drag_point = pos
	return aim_at_position(pos, get_drag_lift_px())


## Finger lifted at [param pos]: when the ghost sits on the enemy half the placement is confirmed (the
## card menu opens, returns true); anywhere else the piece goes back (PLACING ends, returns false).
func end_drag(pos: Vector2) -> bool:
	if not _dragging:
		return false
	drag_to(pos)
	_dragging = false
	if can_confirm_placement() and confirm_placement():
		return true
	if _cut_flow.is_menu_open():
		_note_refusal()
	_drop_placement()
	return false


## True while a piece is being dragged by a finger / the mouse.
func is_dragging() -> bool:
	return _dragging and is_placing()


## Last finger position of the drag (the ghost is drawn get_drag_lift_px() above it).
func get_drag_point() -> Vector2:
	return _drag_point


## Viewport point where a finger must be for the lifted ghost to aim at board cell [param cell]
## (the cell's centre, drag_lift_px lower). For tests and dev demos emulating a drag.
func drag_point_for_cell(cell: Vector2i) -> Vector2:
	return ScreenLayout.cell_center(_grid, get_viewport_rect().size, cell) + Vector2(0.0, get_drag_lift_px())


## Confirms the placement: the piece leaves the bag, the card menu opens with its cells (0.2x, 3 s,
## default card on timeout). Returns false (nothing changes) unless [method can_confirm_placement].
func confirm_placement() -> bool:
	var hold: HoldSlots = _get_hold()
	if hold == null or not can_confirm_placement():
		return false
	if _cut_flow.is_menu_open():
		return _attach_piece(hold)
	var slot: int = _placement.get_slot()
	var piece: Piece = _placement.get_piece()
	var cells: Array[Vector2i] = _placement.confirm()
	if cells.is_empty():
		return false
	_dragging = false
	_focus.end(FocusController.REASON_CONFIRMED)
	_consuming = true
	_pending_slot = slot
	_pending_piece = hold.remove(slot)
	_consuming = false
	var labels: Array[String] = [piece.shape_id]
	_plan.init(_config.max_pieces_per_cast, _config.max_cast_cells)
	_plan.add_piece(slot, piece, cells)
	_join_point = null
	_join_slot = -1
	_join_refusal = {}
	_cut_flow.open_menu(labels, cells, _deck.draw(_skill_config.hand_size))
	return true


## Story 028: true while the open card menu still has room for another piece (max_pieces_per_cast):
## the bag stays live and a piece dragged from it is placed as the cast's next piece.
func can_join_piece() -> bool:
	if _cut_flow == null or _plan == null or not _cut_flow.is_menu_open():
		return false
	if _state.is_player_dead() or _state.is_enemy_dead():
		return false
	return _plan.piece_count() >= 1 and not _plan.is_full()


## Story 028: the cast being built (empty outside the card menu).
func get_cast_plan() -> CastPlan:
	return _plan


## Story 028: the featured shape of this match ({cells, bonus}; empty = feature off on this board).
func get_featured() -> Dictionary:
	return _featured


## Story 028: true when the open menu's plan is a two-piece cast whose union equals the featured shape.
func is_plan_featured() -> bool:
	return _cut_flow != null and _cut_flow.is_menu_open() and not _featured.is_empty() \
			and _plan.is_featured(_featured["cells"] as Array[Vector2i])


## Story 028: true when the plan plus [param extra] (the second ghost's cells) would be a featured
## two-piece cast. With an empty [param extra] it is [method is_plan_featured].
func joined_is_featured(extra: Array[Vector2i]) -> bool:
	if _featured.is_empty() or _plan.piece_count() == 0:
		return false
	if extra.is_empty():
		return is_plan_featured()
	if _plan.piece_count() != 1:
		return false
	var union: Array[Vector2i] = _plan.cells()
	for cell: Vector2i in extra:
		if union.has(cell):
			return false
		union.append(cell)
	return FeaturedShape.matches(_featured["cells"] as Array[Vector2i], union)


## Story 028: the last refused join ({cells, time_left}); empty when none is showing.
func get_join_refusal() -> Dictionary:
	return _join_refusal


## Story 028: takes the second piece off the cast and puts it back into its bag slot; the menu's cells
## shrink to the first piece (the time already added stays). False when the cast has no second piece.
func detach_second_piece() -> bool:
	if not _cut_flow.is_menu_open() or _plan.piece_count() < 2:
		return false
	_plan.remove_piece(1)
	var point: FieldPoint = _join_point
	var slot: int = _join_slot
	_join_point = null
	_join_slot = -1
	var hold: HoldSlots = _get_hold()
	if point != null and hold != null and hold.place(point, slot) < 0:
		hold.place_in_first_free(point)
	_cut_flow.update_cut(_plan_labels(), _plan.cells())
	return true


# Attaches the piece being placed as the cast's second piece (menu open). The piece leaves the bag; the
# menu gets the union of the cells and join_extra_sec more time. A refused plan keeps the piece in the bag.
func _attach_piece(hold: HoldSlots) -> bool:
	var slot: int = _placement.get_slot()
	var piece: Piece = _placement.get_piece()
	var cells: Array[Vector2i] = _placement.get_cells()
	if not _plan.add_piece(slot, piece, cells):
		_note_refusal()
		_drop_placement()
		return false
	_placement.cancel()
	_dragging = false
	_consuming = true
	_join_slot = slot
	_join_point = hold.remove(slot)
	_consuming = false
	hold.clear_selection()
	_cut_flow.update_cut(_plan_labels(), _plan.cells(), _config.join_extra_sec)
	return true


func _plan_labels() -> Array[String]:
	var labels: Array[String] = []
	for piece: Piece in _plan.pieces():
		labels.append(piece.shape_id)
	return labels


# True when [param cells] added to the plan stay within max_cast_cells (0 = no cap).
func _fits_cap(cells: Array[Vector2i]) -> bool:
	return _config.max_cast_cells <= 0 or _plan.total_cells() + cells.size() <= _config.max_cast_cells


# The ghost sat on the board but the cell cap refuses it: keep its cells for the red ghost + hint.
func _note_refusal() -> void:
	if is_placing() and _placement.can_confirm() and not _fits_cap(_placement.get_cells()):
		_join_refusal = {"cells": _placement.get_cells(), "time_left": JOIN_REFUSAL_SEC}


func _age_refusal(real_step: float) -> void:
	if _join_refusal.is_empty():
		return
	_join_refusal["time_left"] = float(_join_refusal["time_left"]) - real_step
	if float(_join_refusal["time_left"]) <= 0.0:
		_join_refusal = {}


## Kept name of the old API: confirms the piece placement (see [method confirm_placement]).
func confirm_selection() -> bool:
	return confirm_placement()


## Esc / cancel button. While PLACING: leaves the mode (piece stays in its slot). While the card
## menu is open: closes it and puts the piece back into its slot (or the first free one).
## Returns true when something was cancelled.
func cancel_placement() -> bool:
	if _cut_flow.is_menu_open():
		# Story 028: Cancel returns BOTH pieces (and ends a second piece still being dragged).
		_drop_placement()
		_cut_flow.cancel_menu()
		_return_join_piece()
		_return_pending_piece()
		_plan.clear()
		return true
	if not is_placing():
		return false
	_drop_placement()
	return true


# Leaves PLACING and clears the bag selection (Focus ends through _update_focus: DESELECTED).
func _drop_placement() -> void:
	_dragging = false
	if _placement != null and _placement.is_placing():
		_placement.cancel()
	var hold: HoldSlots = _get_hold()
	if hold != null:
		hold.clear_selection()


# Keeps the bag selection and the placement in step: if the selected slot changed or emptied from
# outside (tests), PLACING ends.
func _sync_placement() -> void:
	if _placement == null or not _placement.is_placing():
		return
	var hold: HoldSlots = _get_hold()
	var selected: Array[int] = [] if hold == null else hold.get_selected_indices()
	if selected.size() != 1 or selected[0] != _placement.get_slot() or hold.get_piece(selected[0]) == null:
		_placement.cancel()
		_dragging = false


# Stores the rotation of the piece being placed back on the bag's piece (so the slot shows it).
func _store_rotation() -> void:
	var hold: HoldSlots = _get_hold()
	if hold == null or not is_placing():
		return
	var point: FieldPoint = hold.get_point(_placement.get_slot())
	if point != null:
		point.piece = _placement.get_piece()


# Story 028: puts the attached second piece back into the bag.
func _return_join_piece() -> void:
	var point: FieldPoint = _join_point
	var slot: int = _join_slot
	_join_point = null
	_join_slot = -1
	var hold: HoldSlots = _get_hold()
	if point == null or hold == null:
		return
	if hold.place(point, slot) < 0:
		hold.place_in_first_free(point)


# Puts the pending (consumed) piece back into the bag after a cancelled menu.
func _return_pending_piece() -> void:
	var point: FieldPoint = _pending_piece
	var slot: int = _pending_slot
	_pending_piece = null
	_pending_slot = -1
	var hold: HoldSlots = _get_hold()
	if point == null or hold == null:
		return
	if hold.place(point, slot) < 0:
		hold.place_in_first_free(point)


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
	if _consuming:
		return
	_try_pick_up_under_player()


# A piece lying under the player (blocked by a full bag) goes into the first free slot.
func _try_pick_up_under_player() -> void:
	var hold: HoldSlots = _get_hold()
	if hold == null or _state.is_player_dead():
		return
	var point: FieldPoint = _drops.pick_up_at(_state.player_cell, true)
	if point != null:
		hold.place_in_first_free(point)


func _on_skill_chosen(skill_id: String, _labels: Array[String], cells: Array[Vector2i]) -> void:
	# The piece is spent for good once a card is chosen (a swing that gets interrupted loses it).
	_pending_piece = null
	_pending_slot = -1
	_join_point = null
	_join_slot = -1
	# Story 028: the featured bonus rides on the swing only for a two-piece cast matching the shape; a
	# second piece still being dragged when the menu times out goes back to the bag.
	var bonus: Dictionary = {}
	if not _featured.is_empty() and _plan.is_featured(_featured["cells"] as Array[Vector2i]):
		bonus = (_featured["bonus"] as Dictionary).duplicate(true)
	_plan.clear()
	_drop_placement()
	_begin_cut(skill_id, cells, bonus)
	_try_pick_up_under_player()


func _begin_cut(skill_id: String, cells: Array[Vector2i], featured_bonus: Dictionary = {}) -> void:
	var level: int = get_card_level(skill_id)
	if _cut_actor.begin_swing(cells, skill_id, true, level, -1.0, featured_bonus):
		_cooldowns.start(skill_id, float(_resolved_card(skill_id, level).get("cooldown_sec", 0.0)))
		if _signature != null:
			_signature.on_cast(skill_id, cells.size())


## Story 020: the player's level of card [param skill_id] (highest copy in the deck; 1 when the
## deck has no levels or does not hold the card).
func get_card_level(skill_id: String) -> int:
	if _deck != null and _deck.has_method("level_of"):
		return maxi(int(_deck.call("level_of", skill_id)), 1)
	return 1


## Story 020 HUD hook: burn stacks on the boss's half (highest over its burning cells; 0 = none).
func get_burn_stacks() -> int:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _status.burning_cells():
		if _grid.is_enemy_cell(cell):
			cells.append(cell)
	return _status.max_stacks_on(cells)


## Story 023 HUD hook: Ran (fragile) stacks on the boss (0 = none).
func get_fragile_stacks() -> int:
	return _status.get_fragile_stacks(CombatState.Side.ENEMY)


## Story 023 HUD hook: Han (frost) stacks on the boss (0 = none).
func get_frost_stacks() -> int:
	return _status.get_frost_stacks(CombatState.Side.ENEMY)


## Story 020 HUD hook: true while the boss is pinned (Ghim: player sword hits are multiplied).
func is_boss_pinned() -> bool:
	return _status.is_pinned(CombatState.Side.ENEMY)


## Story 020: true when the player's most recent resolved swing got the Ghim multiplier.
func get_last_hit_pin_bonus() -> bool:
	return bool(_feedback.get("pin_bonus", false))


# The card dict at [param level] (resolved when SkillConfig supports levels).
func _resolved_card(skill_id: String, level: int) -> Dictionary:
	if _skill_config.has_method("resolved"):
		return _skill_config.call("resolved", skill_id, level) as Dictionary
	return _skill_config.get_skill(skill_id)


# Arbiter result of either side: stores the HIT/MISS marker for that side's cut.
func _on_swing_resolved(side: int, result: Dictionary) -> void:
	var feedback: Dictionary = {
		"cells": result["cells"], "hit": bool(result["hit"]), "damage": float(result["damage"]),
		"cell": result["cell"], "time_left": FEEDBACK_SEC,
		"pin_bonus": bool(result.get("pin_bonus", false)),
		"featured": bool(result.get("featured", false)),
		"featured_mult": float(result.get("featured_mult", 1.0)),
		"featured_effect": str(result.get("featured_effect", "")),
	}
	if side == CombatState.Side.PLAYER:
		_feedback = feedback
		# Story 029: the one cover point (hit or miss; interrupted / cancelled swings never resolve).
		var cast_cells: Array[Vector2i] = []
		cast_cells.assign(result["cells"] as Array)
		_cover_formation(cast_cells)
		if _signature != null and bool(result["hit"]):
			_signature.on_hit(str(result.get("skill_id", "")), float(result["damage"]))
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
	if is_movement_locked():
		return false
	var from_cell: Vector2i = _state.player_cell
	var stepped: bool = _mover.try_step(direction)
	if stepped and _trait_host != null:
		_trait_host.on_player_stepped(from_cell, _state.player_cell)
	return stepped


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
