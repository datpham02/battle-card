class_name EnemyAgent
extends RefCounted
## Multi-enemy Phase 3 (docs/design/world-map-v2/MULTI-ENEMY-PHASE3-5-PLAN.md 1.3): the decision makers of ONE enemy unit
## of a match (units 1+; unit 0 keeps CombatView's legacy `_boss` / `_pattern` fields). Data only: CombatView builds,
## wires and ticks it.

## The unit KEY (1 + index; >= 2 for an extra unit).
var key: int = CombatState.Side.ENEMY
## The unit this agent drives (owned by CombatState.units).
var unit: EnemyUnit = null
## Movement / pickup / block-brain cuts of the unit (a pattern unit's controller only moves it).
var controller: BossController = null
## The skill lifecycle of a pattern-brain unit; null for a block-brain unit.
var pattern: PatternController = null
## The unit's own brain config (A2: an independent mutable copy, never shared).
var brain_config: BossBrainConfig = null


func _init(p_key: int, p_unit: EnemyUnit, p_controller: BossController, p_pattern: PatternController,
		p_brain_config: BossBrainConfig) -> void:
	key = p_key
	unit = p_unit
	controller = p_controller
	pattern = p_pattern
	brain_config = p_brain_config


## True for a block-brain unit (it plays pieces from its own HoldSlots).
func is_block_brain() -> bool:
	return pattern == null
