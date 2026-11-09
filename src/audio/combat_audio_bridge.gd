class_name CombatAudioBridge
extends Node
## Skill v2 audio (docs/skill-v2/10-audio-system-design.md §2, §4, §6): turns one battle's combat signals into audio
## cues. It ONLY LISTENS: it connects to existing signals, reads public getters, and posts the [AudioEventRules] cues to
## an injected [AudioDirector]. No combat code knows it exists; removing it changes nothing in a match.
##
## Signals: SwingArbiter cast_scheduled / impact_resolved / swing_interrupted, both CutActors swing_started /
## swing_cancelled, PatternController warning_started / warning_cleared / stage_changed (WINDUP), CombatState damaged,
## CombatView match_ended / piece_selected / piece_placed, CutFlow skill_chosen / menu_opened, HoldSlots slot_filled,
## ParryGuard parried. The director's arbiter clock is the arbiter's [method SwingArbiter.clock].
##
## Use [method attach_view] for a real battle, or [method attach] with parts (tests build an arbiter without a view).

var _director: AudioDirector
var _bank: AudioBank
var _parts: Dictionary = {}
var _skills: SkillConfig = null
var _links: Array[Array] = []
var _cast_skill: Dictionary = {}
## Cells burning now (StatusEffects cell_ignited / cell_burned_out), for the burning-ground loop.
var _burning: Dictionary = {}


## A bridge posting to [param director].
func _init(director: AudioDirector) -> void:
	_director = director
	_bank = director.get_bank()
	name = "CombatAudioBridge"


## Builds a bridge for [param view]'s battle (arbiter, actors, state, pattern brain, cut flow, hold slots) and adds it
## as a sibling-level child of the view's parent (freed with the battle). Returns it.
static func attach_view(director: AudioDirector, view: CombatView) -> CombatAudioBridge:
	var bridge := CombatAudioBridge.new(director)
	var parts: Dictionary = {
		"view": view, "arbiter": view.get_arbiter(), "player_actor": view.get_cut_actor(),
		"enemy_actor": view.get_boss().get_actor() if view.get_boss() != null else null,
		"state": view.get_state(), "pattern": view.get_pattern_controller(), "skills": view.get_skill_config(),
		"cut_flow": view.get_cut_flow(), "hold": view.get_hold(), "parry": view.get_parry_guard(),
		"status": view.get_status(),
	}
	bridge.attach(parts)
	var host: Node = view.get_parent() if view.get_parent() != null else view
	host.add_child(bridge)
	return bridge


## Connects to the given parts (any may be missing or null): view, arbiter, player_actor, enemy_actor, state, pattern,
## skills (SkillConfig), cut_flow, hold, parry (ParryGuard), status (StatusEffects: the burning-ground loop). Sets the
## director's arbiter clock.
func attach(parts: Dictionary) -> void:
	detach()
	_parts = parts
	_skills = parts.get("skills", null) as SkillConfig
	var arb: SwingArbiter = parts.get("arbiter", null) as SwingArbiter
	if arb != null:
		_link(arb.cast_scheduled, _on_cast_scheduled)
		_link(arb.impact_resolved, _on_impact_resolved)
		_link(arb.swing_interrupted, _on_swing_interrupted)
		_director.clock_fn = Callable(arb, "clock")
	for key: String in ["player_actor", "enemy_actor"]:
		var actor: CutActor = parts.get(key, null) as CutActor
		if actor != null:
			var side: int = AudioEventRules.SIDE_PLAYER if key == "player_actor" else AudioEventRules.SIDE_ENEMY
			_link(actor.swing_started, _on_swing_started.bind(side))
			_link(actor.swing_cancelled, _on_swing_cancelled.bind(side))
	var state: CombatState = parts.get("state", null) as CombatState
	if state != null:
		_link(state.damaged, _on_damaged)
	var pattern: PatternController = parts.get("pattern", null) as PatternController
	if pattern != null:
		_link(pattern.warning_started, _on_warning_started)
		_link(pattern.warning_cleared, _on_warning_cleared)
		_link(pattern.stage_changed, _on_stage_changed)
	var view: Object = parts.get("view", null)
	if view != null and view.has_signal("match_ended"):
		_link(view.match_ended, _on_match_ended)
		if view.has_signal("piece_selected"):
			_link(view.piece_selected, _on_piece_selected)
			_link(view.piece_placed, _on_piece_placed)
		if view.has_method("_sim_scale"):
			_director.local_scale_fn = Callable(view, "_sim_scale")
	var flow: CutFlow = parts.get("cut_flow", null) as CutFlow
	if flow != null:
		_link(flow.skill_chosen, _on_skill_chosen)
		_link(flow.menu_opened, _on_menu_opened)
	var hold: HoldSlots = parts.get("hold", null) as HoldSlots
	if hold != null:
		_link(hold.slot_filled, _on_slot_filled)
	var parry: ParryGuard = parts.get("parry", null) as ParryGuard
	if parry != null:
		_link(parry.parried, _on_parried)
	var status: StatusEffects = parts.get("status", null) as StatusEffects
	if status != null:
		_link(status.cell_ignited, _on_cell_ignited)
		_link(status.cell_burned_out, _on_cell_burned_out)
		_link(status.burn_hurt, _on_burn_hurt)


## Disconnects everything and clears the director's combat state (pending cues, combat voices, clock).
func detach() -> void:
	for l: Array in _links:
		var sig: Signal = l[0]
		if not sig.is_null() and sig.is_connected(l[1]):
			sig.disconnect(l[1])
	_links.clear()
	_cast_skill.clear()
	_burning.clear()
	# A battle freed after the next one attached must not wipe the new battle's clock.
	var arb: SwingArbiter = _parts.get("arbiter", null) as SwingArbiter
	if not _parts.is_empty() and (arb == null or _director.clock_fn == Callable(arb, "clock")):
		_director.reset_combat()
	_parts = {}


func _exit_tree() -> void:
	detach()


func _on_stage_changed(stage: int, _skill_id: String) -> void:
	if stage == PatternController.Stage.WINDUP:
		_director.apply(AudioEventRules.on_boss_windup())


func _on_menu_opened(_cells: Array, _hand: Array) -> void:
	_director.apply(AudioEventRules.ui_cue(_bank, "menu_open"))


func _on_piece_selected(_slot: int) -> void:
	_director.apply(AudioEventRules.ui("block.select"))


func _on_piece_placed(_slot: int, _cells: Array) -> void:
	_director.apply(AudioEventRules.ui("block.place"))


func _on_cell_ignited(cell: Vector2i) -> void:
	var before: int = _burning.size()
	_burning[cell] = true
	_director.apply(AudioEventRules.on_burning_changed(_bank, before, _burning.size()))


func _on_burn_hurt(side: int, _cell: Vector2i, _damage: float) -> void:
	_director.apply(AudioEventRules.on_burn_hurt(side))


func _on_cell_burned_out(cell: Vector2i) -> void:
	if not _burning.has(cell):
		return
	var before: int = _burning.size()
	_burning.erase(cell)
	_director.apply(AudioEventRules.on_burning_changed(_bank, before, _burning.size()))


func _link(sig: Signal, fn: Callable) -> void:
	if not sig.is_connected(fn):
		sig.connect(fn)
	_links.append([sig, fn])


func _skill_def(skill_id: String) -> Dictionary:
	return _skills.get_skill(skill_id) if _skills != null and not skill_id.is_empty() else {}


func _clock() -> float:
	var arb: SwingArbiter = _parts.get("arbiter", null) as SwingArbiter
	return arb.clock() if arb != null else 0.0


func _on_swing_started(cells: Array[Vector2i], skill_id: String, _duration: float, side: int) -> void:
	_director.apply(AudioEventRules.on_swing_started(_bank, side, skill_id, _skill_def(skill_id), cells.size()))


func _on_swing_cancelled(_cells: Array[Vector2i], skill_id: String, side: int) -> void:
	_director.apply(AudioEventRules.on_swing_cancelled(_bank, side, skill_id, _skill_def(skill_id)))


func _on_swing_interrupted(victim_side: int, _cells: Array[Vector2i], _skill_id: String) -> void:
	_director.apply(AudioEventRules.on_swing_interrupted(victim_side))


func _on_cast_scheduled(side: int, cast: Dictionary) -> void:
	var skill_id: String = str(cast.get("skill_id", ""))
	_cast_skill[int(cast.get("cast_id", -1))] = skill_id
	_director.apply(AudioEventRules.on_cast_scheduled(_bank, side, cast, _skill_def(skill_id), _clock()))


func _on_impact_resolved(side: int, event: Dictionary, hit: bool) -> void:
	var skill_id: String = str(_cast_skill.get(int(event.get("cast_id", -1)), ""))
	_director.apply(AudioEventRules.on_impact_resolved(_bank, side, event, hit, skill_id, _skill_def(skill_id)))


func _on_damaged(side: int, amount: float) -> void:
	var state: CombatState = _parts.get("state", null) as CombatState
	var ratio: float = state.player_hp / maxf(state.player_max_hp, 0.001) if state != null else 1.0
	_director.apply(AudioEventRules.on_damaged(_bank, side, amount, ratio))


func _on_warning_started(skill_id: String, _cells: Array[Vector2i], _queued: Array[Vector2i], warning_sec: float) -> void:
	_director.apply(AudioEventRules.on_warning_started(_bank, skill_id, warning_sec))


func _on_warning_cleared(skill_id: String, _reason: String) -> void:
	_director.apply(AudioEventRules.on_warning_cleared(skill_id))


func _on_match_ended(player_won: bool, _player_hp: float) -> void:
	_director.apply(AudioEventRules.on_match_ended(player_won))


func _on_skill_chosen(_skill_id: String, _labels: Array[String], _cells: Array[Vector2i]) -> void:
	_director.apply(AudioEventRules.ui_cue(_bank, "choose"))


func _on_slot_filled(_index: int, point: FieldPoint) -> void:
	var cells: int = point.piece.cell_count() if point != null and point.piece != null else 1
	_director.apply(AudioEventRules.on_block_pickup(_bank, cells))


func _on_parried(_blocked: float, _reflected: float, _pin_sec: float) -> void:
	_director.apply(AudioEventRules.ui("combat.parry"))
