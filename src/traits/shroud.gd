class_name ShroudTrait
extends BossTrait
## Trait `shroud` (Story 039 Part C, Than May / cloud_veil): the boss's cell is covered by cloud, so the HIT FORECAST of
## the piece placement preview (Story 024: the green / red ghost and its hit / miss tag) is OFF in this match, except
## while the boss is pinned (Ghim) or casting (standing still), when the cloud lifts. This is the model-level switch:
## TraitHost.hit_forecast_blocked() -> [method hit_forecast_blocked] -> PlacementController.forecast_blocked(); the HUD
## draws the grey ghost and the cloud icon from it. The placement itself and PlacementController.hits() are unchanged.
## No params, no RNG.
## HUD: [method is_shrouding] (the forecast is hidden right now), [method is_cloud_lifted] (pinned or casting).
## Implements: Story 039 (Part C).

const ID: String = "shroud"


func get_id() -> String:
	return ID


## The hook: hidden unless the boss is pinned or casting.
func hit_forecast_blocked() -> bool:
	return not is_cloud_lifted()


## True while the forecast is hidden (same as [method hit_forecast_blocked]; the HUD's "why is it grey" cue).
func is_shrouding() -> bool:
	return hit_forecast_blocked()


## True while the cloud lifts off the boss: it is pinned or its cut actor is swinging (a cast in progress).
func is_cloud_lifted() -> bool:
	var status: StatusEffects = get_context().get("status") as StatusEffects
	if status != null and status.is_pinned(CombatState.Side.ENEMY):
		return true
	var boss: BossController = get_context().get("boss") as BossController
	if boss != null and boss.get_actor() != null and boss.get_actor().is_swinging():
		return true
	# Phase 0 (G6): a pattern enemy "casts" through its controller, not the cut actor: the cloud lifts while a skill
	# winds up or warns (ctx `pattern_getter`, set by CombatView; absent in block-brain matches and most tests).
	var getter: Callable = get_context().get("pattern_getter", Callable()) as Callable
	if not getter.is_valid():
		return false
	var pattern: PatternController = getter.call() as PatternController
	return pattern != null and pattern.is_threatening()


func get_debug() -> Dictionary:
	return {"id": ID, "shrouding": is_shrouding()}
