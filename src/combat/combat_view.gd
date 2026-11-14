class_name CombatView
extends Node2D
## Owns the combat logic objects (CombatState, the player's UnitMover, the player half's FieldDrops),
## ticking them from _process with one shared (capped) delta, and draws the HUD band and the step rings.
## Layout (landscape): a thin HUD band (player HP left, boss HP right), then the board (size
## and shape from CombatConfig.grid): player's half left of a divider, boss's half right.
## Story 047: the board and both units are drawn by the BattleCanvas layers (FloorLayer / UnitLayer),
## which read this view; [method get_battle_canvas] is null when the view runs alone (unit suites).
## The boss walks, picks up points and cuts (BossController); swings resolve via SwingArbiter.
## A cooldown ring under the player's feet shows the step cooldown. Placeholder art.
## Stepping onto a cell with a field point picks it up into the hand (HoldSlots).
## Story 014: owns ONE TraitHost per battle (boss traits from match_params["traits"]), wired
## to the arbiter / boss actor / both drops, ticked after the arbiter with the scaled step while
## both units live, torn down when the battle leaves the tree; ticks the hand's rot.
## Story 016: [method can_pause] tells the run whether the pause button / Esc may freeze the
## battle now; [member debug_overlay] gates the HUD's debug text.
## Story 041: both sides' drops use the `odd_blocks` block of field_drops.json, merged with the match key
## `odd_blocks`; DEV arg `--odd-chance=X` (0..1, user args after `--`) then overrides the chance of both
## sides (captures/tests).
## Implements: Story 003, Story 005, Story 006, Story 007, Story 014, Story 016, Story 041.

const ENEMY_COLOR: Color = Color(0.7, 0.3, 0.3)
const BAR_BACK: Color = Color(0.2, 0.17, 0.15, 0.8)
const HP_COLOR: Color = Color(0.85, 0.2, 0.2)
const PLAYER_HP_COLOR: Color = Color(0.3, 0.75, 0.35)
const TEXT_COLOR: Color = Color(0.15, 0.12, 0.1)
const DEFEAT_COLOR: Color = Color(0.9, 0.1, 0.1)
const VICTORY_COLOR: Color = Color(0.1, 0.5, 0.2)
const RING_COLOR: Color = Color(0.95, 0.6, 0.1)
const RING_BACK_COLOR: Color = Color(0.15, 0.12, 0.1, 0.25)
const PAD: float = 10.0
const BAR_HEIGHT: float = 22.0
const FONT_SIZE: int = 24
const BIG_FONT_SIZE: int = 72
## Player marker radius as a share of the cell height: the cooldown ring sits this far (plus RING_GAP_RATIO)
## from the unit's body centre. The marker itself is drawn by UnitLayer since Story 047 (same ratio there).
const MARKER_RADIUS_RATIO: float = 0.33
## Cooldown ring: gap outside the marker (of cell height), line width, arc point count.
const RING_GAP_RATIO: float = 0.06
const RING_WIDTH: float = 6.0
const RING_POINTS: int = 48
## Gap between the HUD's left and right halves as a share of arena width.
const HUD_GAP_RATIO: float = 0.04
## Boss hand tags (HUD band): tag size, gap, top offset from the text row's top, label font,
## width kept free for the right-aligned boss HP text.
const HAND_TAG_WIDTH: float = 52.0
const HAND_TAG_HEIGHT: float = 30.0
const HAND_TAG_GAP: float = 6.0
const HAND_TAG_TOP_OFFSET: float = 0.0
const HAND_FONT_SIZE: int = 18
const HAND_TEXT_RESERVE: float = 300.0
const HAND_TAG_BACK: Color = Color(1.0, 1.0, 1.0, 0.92)
const HAND_EMPTY_COLOR: Color = Color(0.15, 0.12, 0.1, 0.3)
## Boss cooldown ring radius as a share of cell height (around its body), line width.
const BOSS_RING_RADIUS_RATIO: float = 0.5
const BOSS_RING_WIDTH: float = 7.0
## Story 025: the ring while the boss is rooted by its own swing: a solid steel-blue ring (never the red arc).
const BOSS_RING_LOCKED_COLOR: Color = Color(0.3, 0.5, 0.85)
const BOSS_RING_LOCKED_WIDTH: float = 9.0
## Boss hand piece (Story 025): mini shape padding inside its slot box and the largest square.
const HAND_PIECE_PAD: float = 2.0
const HAND_PIECE_MAX_UNIT: float = 13.0
const HAND_ROTTEN_GREY: Color = Color(0.55, 0.55, 0.55)
const HAND_ROTTEN_X: Color = Color(0.2, 0.2, 0.22, 0.9)
## Story 046 Part B: the sharp Z1 header (art bible 7.4 / 7.5, mock asset-slice1-art-check/58). Numbers in px at
## 720p, scaled by height / HUD_REF_HEIGHT; the trail timing is data (combat.json hud.hp_trail_sec).
## 2026-10-31 (user, OSFE reference): the two panels moved flush into the top corners and shrank to 52 px tall
## (ScreenLayout.hud_panel_rect), three rows: name (+ number / boss hand), HP bar, Engraving / boss number.
const HUD_REF_HEIGHT: float = 720.0
## 45-degree cut of the panel corner nearest the screen centre (bottom-right / bottom-left).
const HUD_PANEL_CUT: float = 20.0
const HUD_PANEL_ALPHA: float = 0.92
## Left / right inner padding of a header panel.
const HUD_INSET: float = 12.0
const HUD_NAME_FONT: int = 20
const HUD_NUMBER_FONT: int = 18
const HUD_SMALL_FONT: int = 14
## Row 1 baseline (name, player number), HP bar top and height, Engraving bar top and height, row 3 baseline
## (Engraving count, boss number), all below the panel top.
const HUD_NAME_BASELINE: float = 20.0
const HUD_BAR_TOP: float = 26.0
const HUD_BAR_HEIGHT: float = 10.0
const HUD_ENGRAVING_TOP: float = 41.0
const HUD_ENGRAVING_HEIGHT: float = 5.0
const HUD_ENGRAVING_SEGMENTS: int = 7
const HUD_ROW3_BASELINE: float = 49.0
## Room kept right of the Engraving bar for its "lit/total" count (and clear of the panel's cut corner).
const HUD_ENGRAVING_COUNT_ROOM: float = 64.0
## 2026-11-14 stone-plate HUD panels (HudSkin.stone_panel): the rows are measured from the plate's CONTENT rect
## (inside its inner gold line) rather than from the panel rect, so the plate's rim never crowds them. Row 1
## baseline below the content top, and the HP bar's height; the bar sits on the content's bottom edge, and has no
## frame of its own because the plate already is one.
const HUD_PLATE_NAME_BASELINE: float = 16.0
const HUD_PLATE_BAR_HEIGHT: float = 7.0
## Gap between a number and the text or bar beside it.
const HUD_NUMBER_GAP: float = 8.0
## Smallest name font (720p px) a long name shrinks to before it is clipped.
const HUD_NAME_MIN_FONT: int = 14
## "current/max" of the HP numbers and the Engraving count (digits only, no words to translate).
const HUD_NUMBER_FORMAT: String = "%d/%d"
## Boss hand tiles (art bible 7.5 Z1b), left of the boss name on row 1 of the boss panel.
const HUD_TILE_SIZE: Vector2 = Vector2(22.0, 17.0)
const HUD_TILE_TOP: float = 5.0
const HUD_TILE_GAP: float = 6.0
const HUD_TILE_CUT: float = 5.0
const HUD_TILE_FONT: int = 13
const HUD_TILE_TEXT_LIFT: float = 4.0
const HUD_TILE_EMPTY_ALPHA: float = 0.5
## Enemy blocks: flat #CFC6B4 with an Ink edge (art bible 4).
const HUD_ENEMY_BLOCK: Color = Color("CFC6B4")
## Seed for the field drops RNG; negative = random. Dev/capture only (DemoArgs sets it).
const RANDOM_SEED: int = -1
## Story 041 DEV-ONLY user arg prefix: `--odd-chance=X` overrides the odd block chance of both sides.
const DEV_ODD_CHANCE_ARG: String = "--odd-chance="

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
## ADR-0002 floor perspective (DemoArgs `--floor-perspective=<r>`): overrides combat.json `floor.perspective.back_ratio`
## when >= 0 (0 = force flat); negative = not set. Read by [method floor_back_ratio].
var floor_perspective_override: float = -1.0
## DEV overlay flag (Story 016): the HUD draws its debug text (boss learning line) only when true.
## Set by DemoArgs from the --debug user arg.
var debug_overlay: bool = false
## Story 041: true = the first Odd Block that reaches the player's bag shows the first-pickup hint. False by default;
## GameFlow sets it at match start while progress has not seen "hint:odd_block" (DemoArgs odd_hint forces it).
var odd_hint_enabled: bool = false
## Story 041: the first-pickup hint fired in this match (see [signal odd_hint_shown]).
var _odd_hint_fired: bool = false

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
## Story 032: one entry per joined piece after the first (2nd, then 3rd with tam_hop), in join order.
var _join_points: Array[FieldPoint] = []
var _join_slots: Array[int] = []
var _join_refusal: Dictionary = {}
## Quick spec menu-la-giua-man-hinh-2026-11-01: true from the first piece committed on the enemy half until the card
## menu opens (Tung phép pressed or the place window ran out): the PLACED stage, where more pieces may join the cast.
## _place_left is the REAL seconds left of the place window (ignored while the window is unlimited).
var _placed: bool = false
var _place_left: float = 0.0
# 2026-11-04: REAL seconds left to land the first piece picked up (-1 = not picking); see _tick_pick_window.
var _pick_left: float = -1.0
# 2026-11-04: the piece being placed was lifted off the cast (lift_placed_piece); the clock running out puts it back.
var _lifted: bool = false
## Accessibility "Thời gian chọn lá" for this match (SettingsStore.CARD_TIMES value); "" = read
## SettingsStore.shared() in _ready. Tests set it before _ready or call [method set_card_time].
var card_time_mode: String = ""
var _time_mult: float = 1.0
## True while the pending piece is being taken out of the bag, so the slot-cleared hook does not
## auto-pick a piece lying under the player into the slot that must stay free for a cancel.
var _consuming: bool = false
## Story 024 touch-first placing: true while a finger / the left mouse button drags a piece, and the
## last pointer position of that drag (viewport pixels, the finger itself, not the lifted ghost).
var _dragging: bool = false
var _drag_point: Vector2 = Vector2.ZERO
var _boss: BossController
var _arbiter: SwingArbiter
## Last resolved boss cut, drawn on the player's half: same shape as [member _feedback]. Unit 0 (legacy).
var _boss_feedback: Dictionary = {}
## Multi-enemy Phase 4 (step 4): number-only feedback records of the OTHER units a single player cut hit, one per
## unit past the first, each over its own cell. Empty with one enemy unit.
var _unit_feedback: Array[Dictionary] = []
## Multi-enemy Phase 4 (step 4): resolved cuts of the enemy units that are NOT unit 0, so two units striking the
## player in the same breath keep their own marker instead of overwriting one another. Empty with one enemy unit.
var _boss_feedback_extra: Array[Dictionary] = []
## Last interrupt flash {side (victim), cells, time_left}; empty = none.
var _interrupt_flash: Dictionary = {}
## Story 048: the floor-VFX clock and one-shot queue (created on first use; see [method get_floor_vfx]).
var _floor_vfx: FloorVfx = null
## OSFE hit feel: CombatState.Side -> seconds the side's hit flash waits (take_hit_delay).
var _hit_delay: Dictionary = {}
## The hero's wave flowing through the last cut's cells (user 2026-11-01): {"plan": CastVfx.flow_plan, "start":
## FloorVfx clock at the resolve, "pack": cast pack id}; {} when none runs.
var _cast_flow: Dictionary = {}
## Skill v2 (Trảm Địa): the surge cells drawn now, one per fired impact event of a scheduled player cast: {cell, from
## ((-1, -1) for a start cell), kind (burst / landing / surge), start (FloorVfx clock), hit}; pruned after SURGE_FX_SEC.
var _surge_fx: Array[Dictionary] = []
## Skill v2: the impact events of the player's scheduled casts fired so far (presentation order check, tests).
var _impact_log: Array[Dictionary] = []
## Skill v2 (Trảm Địa): the player's scheduled surge events on the arbiter clock (SwingArbiter.cast_scheduled), read
## to draw the incoming fronts exactly on the authoritative times; [] when none.
var _surge_plan: Array[Dictionary] = []
## Skill v2 (Ngàn Kiếm, SkyDropFx): the player's scheduled sky drops {cell, at, t0, final, seed, cast_id} on the arbiter
## clock (from SwingArbiter.cast_scheduled), drawn by the overlay; pruned once finished.
var _sky_plan: Array[Dictionary] = []
## Skill v2 Cast Commitment (Ngàn Kiếm prototype): taps on Hủy in the first CHANNEL_CANCEL_GUARD_SEC of a channel are
## ignored (the finger that chose the card cannot cancel it).
const CHANNEL_CANCEL_GUARD_SEC: float = 0.15
## The COMMIT lock: the hero may not step until this arbiter-clock time (swing end + commit_lock_sec); -1 = none.
var _commit_lock_until: float = -1.0
## Skill v2 Hỏa Lôi H2: the fire-seal records (FuseFx.records_from_cast) of the player's armed fields, from the
## authoritative schedule; marked fired / fizzled by the matching impact event; pruned once drawn out.
var _fuse_fx: Array[Dictionary] = []
## The committed (scheduled) cast of the last channel, for the RESOLUTION phase; -1 = none.
var _commit_cast: int = -1
## A Hủy / Esc request waiting for the next tick: it is resolved AFTER the arbiter tick, so a commit in that tick wins.
var _cancel_requested: bool = false
## Cast Commitment feedback: {cells, refused (bool), time_left}; {} when none.
var _channel_flash: Dictionary = {}
## Skill v2 (Ngàn Kiếm on-tile summon): the swing's preview {skill, cells, from, command_at, records}; {} otherwise.
var _sky_summon: Dictionary = {}
## Skill v2 (Ngàn Kiếm on-tile summon): the Knight's visual summon hold {skill, until (clock), cell}: the cast clip keeps
## its summon pose until `until` (the command), then pulls down. Cleared when the player moves. {} otherwise.
var _summon_hold: Dictionary = {}
## ADR-0001 Task 5: the player's last resolved cast for the code-drawn travel ({} = none): {cells, delivery, caster,
## arrive, start (FloorVfx clock at the resolve)}.
var _cast_travel: Dictionary = {}
## Batch 4 (Móc Kéo): the pull path telegraph {cells, start (FloorVfx clock), sec}; {} when none.
var _pull_telegraph: Dictionary = {}
## How long the pull path stays drawn after the hook's first event.
const PULL_TELEGRAPH_TAIL_SEC: float = 0.25
## Skill v2 V1 (2026-11-11): a SCHEDULED cast (arrival / waves / delayed) never records `_cast_travel`, so its
## impacts are recorded event by event here instead (same shape, arrival 0 at `start`), one record per resolved
## player event; OverlayLayer reads them with event_impacts_now() and drops them after its tail.
var _event_impacts: Array[Dictionary] = []
## Task 5 item 4: the boss's last resolved cast, same form as _cast_travel.
var _boss_travel: Dictionary = {}
## ADR-0001 Task 5 item 6: side -> true once that unit died by falling into a hole (UnitLayer plays its `fall` clip).
var _fell: Dictionary = {}
## Last feint flash {cells, time_left}; empty = none.
var _feint_flash: Dictionary = {}
var _status: StatusEffects
var _learning: BossLearning
## The boss traits of this match (Story 014); built in _ready, torn down in _exit_tree.
var _trait_host: TraitHost
## Phase 2: the pattern brain's skill lifecycle (match key `brain` == "pattern"); null for every block-brain match.
var _pattern: PatternController = null
## Multi-enemy Phase 3 (MULTI-ENEMY-PHASE3-5-PLAN.md 1.3): the shared threat book (D1) and the agents of units 1+
## (unit 0 stays `_boss` / `_pattern`, wired exactly as before). Empty with one unit.
var _threat: ThreatBoard = null
var _extra_agents: Array[EnemyAgent] = []
## Phase 3: every unit's mover by unit key (0 = the hero, 1 = unit 0, 2+ = extra units); the status hooks read it.
var _movers_by_key: Dictionary = {}
## Phase 3: simulation seconds, and when each enemy unit died (the pattern ally conditions read it).
var _sim_time: float = 0.0
var _unit_died_at: Dictionary = {}
## Monster Skill Phase 0: the match's pattern tempo before any phase `tempo_mult` (phases multiply it, never compound).
var _pattern_base_tempo: float = 1.0
## Phase 0 (G5): the traits the CURRENT pattern phase added (torn down when the next phase starts).
var _pattern_phase_traits: Array[BossTrait] = []
## Phase 0 (G4): skill ids already warned about for a missing / unknown delivery (one warning each).
var _pattern_vfx_warned: Dictionary = {}
## Story 036: the tile hazard model (mire, sand, wind); null before setup.
var _hazards: TileHazards
## F2 (characters.json `attributes.hazard_resist_mult`): multiplies hazard damage the PLAYER takes.
## 1.0 (the default, and the value without a character) leaves every number exactly as it was.
var _hazard_resist_mult: float = 1.0
## The character passive of this match (Story 018); null without a character or with an unknown id.
var _passive: BasePassive = null
var _passive_heal: float = 0.0
## The character signature skill of this match (Story 021); null without one or with an unknown id.
var _signature: BaseSignature = null
## Story 032: the run's relics of this match (received order), their merged config overrides
## (RelicRegistry.merge_overrides), the cast being swung ({pieces, cells, joined, featured, card_id, hit};
## {} when none) and the piece library used by give_piece (loaded on first use).
var _relics: Array[BaseRelic] = []
var _relic_overrides: Dictionary = {}
var _cast_info: Dictionary = {}
var _relic_pieces: PieceLibrary = null
## Story 034: the player's piece weights from the run's deck ({} = original library weights) and
## whether the "always a shape that fits" fallback replaced them for this arena.
var _player_piece_weights: Dictionary = {}
var _piece_deck_fallback: bool = false
## Formation map of the enemy half (Story 029); null without a signature (it only feeds the signature).
var _formation: FormationMap = null
## True once the formation map completed and the signature has not been activated yet.
var _signature_ready_flag: bool = false
## Seconds left of the completion flash (real time); 0 = none.
var _formation_flash_left: float = 0.0
## Skill v2 V4 feel pass (CastVfx.hit_feel): the simulation pause and the board shake when the player's cast lands on
## the boss. `_hit_stop_at` = the floor-vfx time of the first arrival of the pending player hit (-1 = none);
## `_hit_stop_left` / `_hit_shake_left` run on REAL time. Presentation: the boss and every clock stop together for
## hit_stop_sec, so no scheduled time changes relative to another.
var _hit_stop_at: float = -1.0
var _hit_stop_left: float = 0.0
var _hit_shake_left: float = 0.0
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
## boss_step_cooldown_mult (x the player's computed step cooldown; deprecated absolute: boss_step_cooldown_sec), boss_think_interval_sec, boss_reaction_sec, boss_drop_interval_mult, player_drop_interval_mult (Story 038, the player's piece drop interval x),
## odd_blocks (Story 041: object with keys of field_drops.json `odd_blocks`, merged over it for BOTH sides)
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
## A bag piece was picked and PLACING started (audio: block.select). Not emitted for a rotate of the same slot.
signal piece_selected(slot: int)
## A piece was committed onto the cast: the first one (place window) or a later join. [param cells] are that piece's.
signal piece_placed(slot: int, cells: Array[Vector2i])
## The placed cast was locked and the card menu opened on it (Tung phép or the place-window timeout).
signal placement_confirmed(cells: Array[Vector2i])
## Story 021: the player activated the signature [param id] (the charge was reset).
signal signature_activated(id: String)
## Story 021: the timed effect of the signature [param id] ran out.
signal signature_ended(id: String)
## Story 029: the signature just became ready through the map (every real enemy cell lit at once and
## the cooldown over — reached on a cover or when the cooldown ran out). The map is NOT reset here
## (Phần D: activation resets it).
signal formation_completed
## Story 032: the relic [param relic_id] acted (HUD flash).
signal relic_triggered(relic_id: String)
## Story 033: a curse card with draw_damage was drawn into the card menu and hurt the player.
signal curse_drawn(card_id: String, damage: float)
## Story 041: the first Odd Block of the match reached the player's bag while [member odd_hint_enabled]: the HUD
## shows the first-pickup hint now (GameFlow marks progress "hint:odd_block" seen). Emitted at most once per match.
signal odd_hint_shown

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

## Story 035: match_params key, true for a REGION boss match (set by the run for a region's `boss` node; never for
## a miniboss, a normal match or the final match). Such a boss is DOWNED at 0 HP instead of dying (see
## [method is_boss_downed]); absent/false keeps the plain dead-boss behaviour.
const PARAM_BOSS_CAN_DOWN: String = "boss_can_down"
var _downed: bool = false
## Story 047: the battle art canvas that draws the board and the units (set by BattleCanvas when it binds;
## null when a CombatView runs alone, as the unit suites do, and the rings fall back to the cell centre).
var _canvas: BattleCanvas = null
## Story 035 match stats (see [method get_match_stats]); counted from the existing hooks only.
var _stats: Dictionary = {"hits_taken": 0, "casts": 0, "joins": 0, "featured_casts": 0, "signatures_used": 0,
	"frost_bursts": 0, "boss_thorn_steps": 0, "max_cast_cells": 0, "vents_dodged": 0}
## Story 037: the last passive heal ({amount, time_left}) for the HUD "+N" flash; {} when none.
var _heal_flash: Dictionary = {}
## Cast rhythm spec 2026-11-05 (Knight parry): the hero's guard (opened by a `parry` card, ticked in match time) and the
## flash of the last parry ({cell, reflected, time_left}; empty when none shows).
var _parry_guard: ParryGuard = ParryGuard.new()
var _parry_flash: Dictionary = {}
## Story 046 Part B: damage trails of the Z1 HP bars, [player, boss]: shrink from / to ratio and seconds
## since the last drop (to < 0 = not started). Presentation state only.
var _hp_trail_from: Array[float] = [1.0, 1.0]
var _hp_trail_to: Array[float] = [-1.0, -1.0]
var _hp_trail_t: Array[float] = [0.0, 0.0]
var _hp_trail_sec: float = 0.0


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
	_setup_relics(_relic_ids())
	var player_max_hp: float = maxf(float(character.get("max_hp", _config.player_max_hp)), 1.0)
	# Multi-enemy Phase 3: one unit per resolved `enemies[]` entry (a plain match = the single unit 0, as _init)
	var state_params: Dictionary = match_params.duplicate()
	state_params["boss_max_hp"] = boss_max_hp
	_state = CombatState.from_match_params(
		_grid, player_max_hp, state_params, _config.player_start_cell, _config.enemy_start_cell
	)
	var start_hp: float = float(match_params.get("player_hp", -1.0))
	if start_hp >= 0.0:
		_state.set_player_hp(start_hp)
	_state.enemy_died.connect(_on_enemy_died)
	_base_step_cooldown = _config.step_cooldown_for(_grid)
	# Story 033: run modifiers (event `loi_the`: step_cooldown x1.2 for 2 matches) on top of the character.
	_player_step_cooldown = RelicRegistry.apply_override(_base_step_cooldown * _step_mult(character),
		match_params.get("run_modifiers", {}), "step_cooldown")
	_mover = UnitMover.new(_state, CombatState.Side.PLAYER, _player_step_cooldown)
	_drops_config = FieldDropsConfig.load_from_file(drops_config_path)
	_apply_odd_overrides(_drops_config)
	var boss_drops_config: FieldDropsConfig = _drops_config.copy()
	var boss_drop_mult: float = maxf(float(match_params.get("boss_drop_interval_mult", 1.0)), 0.01)
	boss_drops_config.spawn_interval_sec *= boss_drop_mult
	boss_drops_config.piece_spawn_interval_sec *= boss_drop_mult # Story 025: the boss drops pieces too
	_apply_drop_overrides()
	# Story 038 (Kiep 4): the PLAYER's piece drop interval x match key `player_drop_interval_mult` (default 1.0 = untouched;
	# the boss copy above is made before, so it never sees this).
	var player_drop_mult: float = maxf(float(match_params.get("player_drop_interval_mult", 1.0)), 0.01)
	if not is_equal_approx(player_drop_mult, 1.0):
		_drops_config.piece_spawn_interval_sec *= player_drop_mult
	_drops = FieldDrops.new(_drops_config, _grid.player_cells(), drops_seed)
	# Story 024: the player's half drops puzzle pieces (the boss's drops stay classic labels).
	# Story 034: a run's piece deck (match_params["piece_deck"]) gives the PLAYER side its own weights;
	# absent/empty keeps today's call (original library weights).
	var player_pieces: PieceLibrary = PieceLibrary.load_from_file()
	var piece_deck: Variant = match_params.get("piece_deck", {})
	if typeof(piece_deck) == TYPE_DICTIONARY and not (piece_deck as Dictionary).is_empty():
		var deck_weights: Dictionary = PieceDeck.weights_for_match(piece_deck as Dictionary, player_pieces,
			str(match_params.get("chapter_id", "")), _grid, PieceDeckConfig.load_from_file(), match_params.get("locked_pieces", []) as Array)
		_piece_deck_fallback = bool(deck_weights["fallback"])
		_player_piece_weights = deck_weights["weights"]
		_drops.enable_pieces(player_pieces, str(match_params.get("chapter_id", "")), _grid, drops_seed, true, _player_piece_weights)
	else:
		_drops.enable_pieces(player_pieces, str(match_params.get("chapter_id", "")), _grid, drops_seed)
	_drops.place_start_pieces(_state.player_cell)
	_placement = PlacementController.new(_grid)
	_plan.init(get_max_join_pieces(), _config.max_cast_cells)
	_featured = ArenaLibrary.load_from_file().featured_for_match(match_params, _grid)
	_state.cell_changed.connect(_on_cell_changed)
	_cut_config = CutConfig.load_from_file()
	_skill_config = SkillConfig.load_from_file()
	_cooldowns = SkillCooldowns.new()
	_deck = Deck.from_array(_deck_ids(),drops_seed if drops_seed >= 0 else randi())
	_focus = FocusController.new(_skill_config)
	if character.has("focus_max_sec"):
		_focus.set_max_sec_override(float(character["focus_max_sec"]))
	if _relic_overrides.has("focus_sec"):
		_focus.set_max_sec_override(maxf(_override(_focus.get_max_sec(), "focus_sec"), 0.0))
	_cut_actor = CutActor.new(_cut_config, CombatState.Side.PLAYER)
	_cut_flow = CutFlow.new(_skill_config, _cooldowns)
	_cut_flow.level_of = Callable(self, "get_card_level")
	_cut_flow.availability_context_fn = Callable(self, "get_availability_context")
	# 2026-11-07 (user: drop the "Thời gian chọn lá" setting, use the default): every match uses the normal card time;
	# a value saved earlier is ignored. Tests may still set card_time_mode.
	set_card_time(card_time_mode if not card_time_mode.is_empty() else SettingsStore.CARD_TIME_NORMAL)
	_cut_flow.skill_chosen.connect(_on_skill_chosen)
	var brain_config: BossBrainConfig = BossBrainConfig.load_from_file()
	_apply_brain_params(brain_config)
	# Multi-enemy Phase 3 (D3): with N enemy units every unit thinks base x sqrt(N), clamped 0.05..1.0 s (N = 1: unchanged)
	brain_config.think_interval_sec = _scaled_think(brain_config.think_interval_sec)
	var hold_config: HoldSlotsConfig = HoldSlotsConfig.load_from_file()
	if hold_config == null:
		hold_config = HoldSlotsConfig.new()
	_apply_hold_override(hold_config)
	_boss = BossController.new(
		_state, _grid, _cut_config, _skill_config, brain_config, boss_drops_config, hold_config,
		drops_seed + 1 if drops_seed >= 0 else -1
	)
	# Story 025: the boss plays pieces too (placement checked on the player's half).
	# Phase 2 (spec 3.7): a pattern-brain enemy picks up no pieces, so nothing drops on its half.
	if not is_pattern_brain():
		_boss.enable_pieces(
			PieceLibrary.load_from_file(), str(match_params.get("chapter_id", "")), drops_seed + 2 if drops_seed >= 0 else -1,
			_config.max_pieces_per_cast
		)
	_boss.set_player_step_cooldown(_player_step_cooldown)
	_boss.get_brain().cards = _boss_card_ids()
	_boss.get_actor().duration_mult = maxf(float(match_params.get("swing_speed_mult", 1.0)), 0.01)
	if not boss_set_override.is_empty() and not _boss.get_brain().use_set(boss_set_override):
		push_warning("CombatView: unknown boss weight set '%s'" % boss_set_override)
	_status = StatusEffects.new()
	_apply_status_overrides()
	_config.configure_status(_status)
	_mover.set_status(_status)
	_boss.set_status(_status)
	_learning = BossLearning.new(brain_config.learning)
	_boss.set_learning(_learning)
	_boss.feinted.connect(_on_boss_feinted)
	_boss.get_actor().swing_started.connect(_on_boss_swing_started)
	_boss.get_actor().swing_cancelled.connect(_on_boss_swing_cancelled)
	_cut_actor.swing_cancelled.connect(_on_player_swing_cancelled)
	_cut_actor.channel_extend_fn = func(id: String) -> float:
		return float(_skill_config.get_skill(id).get("channel_extend_sec", 0.0)) if _skill_config != null else 0.0
	# Skill v2 cast profile: a card's fixed cast time (cards.json cast_time_sec; Hỏa Lôi 0.45 s).
	_cut_actor.cast_time_fn = func(id: String) -> float:
		return float(_skill_config.get_skill(id).get("cast_time_sec", -1.0)) if _skill_config != null else -1.0
	_arbiter = SwingArbiter.new(_state, _grid, _cut_actor, _boss.get_actor(), _cut_config, _skill_config, _status)
	_arbiter.player_guard = _parry_guard
	# Skill v2 B1.5: the `arrival` resolve reads the same delivery timing as the cast visuals.
	_arbiter.delivery_timing = delivery_timing()
	_parry_guard.parried.connect(_on_parried)
	# Story 023: flat boss defense (match key boss_defense), default execute threshold, brain min runes.
	_arbiter.boss_defense = maxf(float(match_params.get("boss_defense", 0.0)), 0.0)
	_arbiter.execute_ratio = _config.execute_ratio
	# User 2026-11-01: the Vay Bat extra thorn cell is random, from the match's seed (drops_seed + 3; random when < 0).
	_arbiter.zone_rng = RandomNumberGenerator.new()
	if drops_seed >= 0:
		_arbiter.zone_rng.seed = drops_seed + 3
	else:
		_arbiter.zone_rng.randomize()
	_boss.get_brain().min_runes = maxi(int(match_params.get("boss_min_runes", 0)), 0)
	_wire_zones()
	_setup_hazards()
	_wire_relics()
	_arbiter.swing_resolved.connect(_on_swing_resolved)
	_arbiter.swing_interrupted.connect(_on_swing_interrupted)
	_arbiter.impact_resolved.connect(_on_impact_resolved)
	_arbiter.cast_scheduled.connect(_on_cast_scheduled)
	# Skill v2 (Trảm Địa): the boss reads the surge still running on the same clock (BossBrain pending threat).
	_boss.pending_threat_fn = _arbiter.pending_cells.bind(CombatState.Side.PLAYER)
	# Skill v2 delayed (Hỏa Lôi): a running delayed swing's threat comes fuse_sec after its end.
	_boss.cast_delay_fn = func(actor: CutActor) -> float:
		return CastResolver.threat_delay(_skill_config.get_skill(actor.get_skill_id()), actor.get_cast_context())
	# Skill v2 (Ngàn Kiếm): an active Awakening raises a card's max hits (awakening_extra_hits).
	_arbiter.player_awakening_fn = is_signature_active
	# Skill v2 fix: a scheduled cast breaks a pattern windup / warning at its first damaging impact.
	# Multi-enemy Phase 3 (A3): the hit unit's own pattern controller only
	_arbiter.pattern_hit_fn = func(key: int) -> void:
		var hit_pattern: PatternController = _pattern_of(key)
		if hit_pattern != null:
			hit_pattern.on_enemy_hit()
	_drops.point_spawned.connect(_on_point_spawned.bind(CombatState.Side.PLAYER))
	_boss.get_drops().point_spawned.connect(_on_point_spawned.bind(CombatState.Side.ENEMY))
	_trait_host = TraitHost.new(make_trait_ctx(), _trait_specs(), drops_seed)
	_trait_host.on_match_start()
	_setup_pattern_brain(brain_config)
	_setup_extra_units(boss_drops_config, hold_config)
	_setup_attributes(character)
	_setup_passive(character)
	_setup_signature(character)
	_wire_status_hooks()
	for relic: BaseRelic in _relics:
		relic.on_match_start()


# Story 037: the ONE point where the status events of the boss reach the match stats and the passive:
# a Han burst on the boss (frost_bursts, passive.on_frost_burst), the boss stepping onto one of the player's
# thorn cells (boss_thorn_steps, passive.on_boss_thorn_step) and a zone the player forms on the boss's half
# (passive.on_player_zone_formed).
func _wire_status_hooks() -> void:
	_status.frost_burst.connect(_on_status_frost_burst)
	_status.thorn_entered.connect(_on_status_thorn_entered)
	_status.zone_applied.connect(_on_status_zone_applied)
	_status.zone_expired.connect(_on_status_zone_expired)


func _on_status_frost_burst(side: int, damage: float) -> void:
	if side != CombatState.Side.ENEMY:
		return
	_stats["frost_bursts"] = int(_stats["frost_bursts"]) + 1
	if _passive != null:
		_passive.on_frost_burst(damage)


func _on_status_thorn_entered(side: int, cell: Vector2i, _damage: float) -> void:
	get_floor_vfx().play("thorn_spikes", cell, side)  # Story 048 F9
	if side != CombatState.Side.ENEMY:
		return
	_stats["boss_thorn_steps"] = int(_stats["boss_thorn_steps"]) + 1
	if _passive != null:
		_passive.on_boss_thorn_step(cell)


func _on_status_zone_applied(kind: String, side: int, cells: Array[Vector2i]) -> void:
	_mark_floor_dirty()
	if side == CombatState.Side.ENEMY and _passive != null:
		_passive.on_player_zone_formed(kind, cells)


# Story 047 Part B: a seal / thorn cell expired (or was cleared): the floor redraws without it.
func _on_status_zone_expired(_kind: String, _side: int, _cell: Vector2i) -> void:
	_mark_floor_dirty()


# Story 047 Part B: the FloorLayer draws thorns and seals and redraws only on request (art bible 8.6);
# this is the one place the zone events reach it. No-op when the view runs without a canvas.
func _mark_floor_dirty() -> void:
	if _canvas != null and _canvas.get_floor_layer() != null:
		_canvas.get_floor_layer().mark_dirty()


# Story 037: the passive's heal (prayer): heals the player, clamped to max HP, and starts the "+N" HUD flash
# with the HP actually gained (nothing when already full or dead).
func _passive_heal_player(amount: float) -> void:
	if amount <= 0.0 or _state.is_player_dead():
		return
	var before: float = _state.player_hp
	_relic_heal_player(amount)
	var gained: float = _state.player_hp - before
	if gained <= 0.0:
		return
	var total: float = gained + (float(_heal_flash.get("amount", 0.0)) if not _heal_flash.is_empty() else 0.0)
	_heal_flash = {"amount": total, "time_left": FEEDBACK_SEC}


## Story 037: the last passive heal as {amount: float, time_left: float} for the HUD; {} when none is showing.
func get_heal_flash() -> Dictionary:
	return _heal_flash


# Story 027: sealed cells block stepping for BOTH movers (OR-ed with cracks and any other blocker via
# UnitMover.add_blocker), and the arbiter gets the zone numbers and each side's blocked test for the
# seal leave-a-path rule.
func _wire_zones() -> void:
	var status: StatusEffects = _status
	var movers: Dictionary = {CombatState.Side.PLAYER: _mover, CombatState.Side.ENEMY: _boss.get_mover()}
	# Phase 3: extra units add their movers here (_setup_extra_units); the hooks below read this dictionary by unit key
	_movers_by_key = movers
	for side: int in movers:
		var mover: UnitMover = movers[side] as UnitMover
		var seal_side: int = side
		# Drop tiles (Ô rớt rule 4): an open hole cannot be entered; a cracking cell stays enterable (rule 3).
		mover.add_blocker(func(cell: Vector2i) -> bool: return status.is_hole(seal_side, cell))
		# Skill v2 batch 3 (M11): a pillar of the unit's own half blocks its step; a fire wall blocks the ENEMY only.
		mover.add_blocker(func(cell: Vector2i) -> bool: return status.is_pillar(seal_side, cell))
		if side == CombatState.Side.ENEMY:
			mover.add_blocker(func(cell: Vector2i) -> bool: return status.is_fire_wall(cell))
		_arbiter.blocked_cell_fns[side] = Callable(mover, "is_cell_blocked")
	_arbiter.zone_numbers = _config.zone_numbers()
	_arbiter.reactions = _config.reactions()
	# Drop tiles (rule 6): a rooted unit holds the crack under it like a Frozen one; a non-lethal fall lands on a cell
	# its mover accepts.
	status.step_locked_fn = func(side: int) -> bool: return (movers[side] as UnitMover).is_step_locked()
	status.hole_blocked_fn = func(side: int, cell: Vector2i) -> bool: return (movers[side] as UnitMover).is_cell_blocked(cell)
	status.hole_cracked.connect(func(_side: int, _cells: Array[Vector2i]) -> void: _mark_floor_dirty())
	status.hole_fell.connect(func(side: int, _cell: Vector2i, victim: bool) -> void:
		if victim and _state != null and (_state.is_player_dead() if side == CombatState.Side.PLAYER else _state.is_enemy_dead()):
			_fell[side] = true
		_mark_floor_dirty())
	status.hole_restored.connect(func(_side: int, _cell: Vector2i) -> void: _mark_floor_dirty())


# Story 036 Part A: builds the TileHazards of this match. Numbers = combat.json `hazards` overlaid by the match
# keys of the same names; the arena shape (ArenaLibrary.hazards_for_match) says which hazards run. Both movers get
# the sand blocker and the mire step cost; mire damage hits the unit standing in it (match key mire_immune frees
# the boss); sand buries field pieces, the wind drifts them and offsets new drops. With no hazard data nothing here
# draws a random number or changes a tick.
func _setup_hazards() -> void:
	var merged: Dictionary = _config.hazards()
	for key: String in merged.keys():
		if match_params.has(key):
			merged[key] = match_params[key]
	_hazards = TileHazards.new(_grid, drops_seed)
	_hazards.configure(merged)
	_hazards.return_fade_sec = _config.hole_return_fade_sec
	_hazards.bind_state(_state)
	# Drop tiles with zones.hole_fall_lethal false lose fall_damage, match overrides included.
	_status.hole_fall_damage = _hazards.config_value("fall_damage")
	# Story 036 (W4): the boss brain prices mire, treats sand as blocked and leads drifting pieces.
	if _boss != null and _boss.has_method("set_hazards"):
		_boss.set_hazards(_hazards)
	if _arbiter != null:
		_arbiter.tile_hazards = _hazards
	var status: StatusEffects = _status
	var boss_mover: UnitMover = _boss.get_mover()
	var movers: Dictionary = {CombatState.Side.PLAYER: _mover, CombatState.Side.ENEMY: boss_mover}
	var hazards: TileHazards = _hazards
	for side: int in movers:
		var mover: UnitMover = movers[side] as UnitMover
		var hazard_side: int = side
		# Story 039: a fallen (crumbled) cell is the fourth blocker source (crack, seal, sand, fall) of the same callable.
		mover.add_blocker(func(cell: Vector2i) -> bool:
			return hazards.is_sanded(hazard_side, cell) or hazards.is_fallen(hazard_side, cell))
		mover.step_cost_fn = func(from_cell: Vector2i) -> float: return hazards.step_cost_mult(hazard_side, from_cell)
	# Leave-a-path sees seals and cracks through the movers' own blocked test.
	_hazards.extra_blocked_fn = func(side: int, cell: Vector2i) -> bool:
		return (movers[side] as UnitMover).is_cell_blocked(cell)
	_hazards.set_mire_immune(CombatState.Side.ENEMY, bool(match_params.get("mire_immune", false)))
	var arena: Dictionary = ArenaLibrary.hazards_for_match(match_params, _grid)
	var mire_player: Array[Vector2i] = []
	var mire_enemy: Array[Vector2i] = []
	mire_player.assign(arena.get("mire_player", []))
	mire_enemy.assign(arena.get("mire_enemy", []))
	_hazards.set_mire(CombatState.Side.PLAYER, mire_player)
	_hazards.set_mire(CombatState.Side.ENEMY, mire_enemy)
	_hazards.enable_sand(bool(arena.get("sand", false)))
	_hazards.enable_wind(bool(arena.get("wind", false)))
	# Story 039: lava vents and crumbling cells (has()/get() with defaults: arenas without them change nothing).
	_hazards.set_vents(CombatState.Side.PLAYER, arena.get("vents_player", []) as Array)
	_hazards.set_vents(CombatState.Side.ENEMY, arena.get("vents_enemy", []) as Array)
	_hazards.enable_crumble(bool(arena.get("crumble", false)))
	_hazards.vent_erupted.connect(_on_vent_erupted)
	_hazards.cell_fell.connect(_on_cell_fell)
	_hazards.mire_damage.connect(_on_mire_damage)
	_hazards.sand_filled.connect(_on_sand_filled)
	_hazards.drift_due.connect(_on_drift_due)
	var wind_fn: Callable = func() -> Vector2i: return hazards.wind_dir()
	_drops.wind_offset_fn = wind_fn
	_boss.get_drops().wind_offset_fn = wind_fn


# The unit standing in mire takes the tick damage (CombatState keeps its own invulnerability rules).
func _on_mire_damage(side: int, amount: float) -> void:
	_state.damage(side, _hazard_amount(side, amount))


# Story 039: a vent erupts: its cells burn through the SAME StatusEffects burning cell as row_burner / Hoa tran (units
# standing there take the tick damage, the boss brain's burn handling already avoids them) and the field pieces lying
# there are burnt (lost).
func _on_vent_erupted(side: int, _vent_index: int, cells: Array[Vector2i]) -> void:
	# World Map v2 objectives (03 section 5): an eruption on the player's half that the player is not standing in.
	if side == CombatState.Side.PLAYER and _state != null and not cells.has(_state.player_cell):
		_stats["vents_dodged"] = int(_stats["vents_dodged"]) + 1
	# Quick spec 2026-11-01: a vent is region terrain, not a zone effect (terrain = true: no lock, no replacement).
	# F2: the vent's burn is applied per CELL by StatusEffects, not per unit, so the resist is scaled
	# here using the half the vent erupted on. That is exact only because the board is two facing
	# halves and a unit never stands on the other side's cells (BoardGrid: player half = cols
	# 0..side_cols-1). If an enemy unit can ever occupy the player's half, this needs a per-unit
	# resist at the burn tick instead — the one place in F2 where the attribute is applied by half
	# rather than by target.
	_status.ignite(cells, _hazards.config_value("vent_sec"), _hazards.config_value("vent_tick_sec"),
		_hazard_amount(side, _hazards.config_value("vent_tick_damage")), true)
	_drops_of(side).bury_cells(cells)


# Story 039: a cell fell: the pieces on it are lost; a unit the model pushed off it takes fall_damage.
func _on_cell_fell(side: int, cell: Vector2i, occupant_pushed: bool) -> void:
	var lost: Array[Vector2i] = [cell]
	_drops_of(side).bury_cells(lost)
	if occupant_pushed:
		_state.damage(side, _hazard_amount(side, _hazards.config_value("fall_damage")))


# Sand filled on [param cells] of [param side]: field pieces lying there are buried.
func _on_sand_filled(side: int, cells: Array[Vector2i]) -> void:
	_drops_of(side).bury_cells(cells)


# The wind moves the field pieces of both halves one cell (a piece never drifts into sand).
func _on_drift_due() -> void:
	var dir: Vector2i = _hazards.wind_dir()
	var dragged: Array[Vector2i] = []  # pieces are placed from the hold bag, never dragged on the field
	for side: int in [CombatState.Side.PLAYER, CombatState.Side.ENEMY]:
		var drift_side: int = side
		var hazards: TileHazards = _hazards
		_drops_of(side).drift_pieces(dir, func(cell: Vector2i) -> bool: return hazards.is_sanded(drift_side, cell), dragged)


func _drops_of(side: int) -> FieldDrops:
	return _drops if side == CombatState.Side.PLAYER else _boss.get_drops()


## Story 036: the tile hazard model of this match (mire, sand, wind); null before setup. Traits get it as
## ctx["hazards"], the HUD and tests read it here.
func get_hazards() -> TileHazards:
	return _hazards


# Cells that refuse new drops: [param base] (burning) plus, when sand is active, the sand and sand-warning cells.
func _drop_blocked_cells(base: Array[Vector2i], side: int) -> Array[Vector2i]:
	if _hazards == null:
		return base
	var sand: Array[Vector2i] = _hazards.sand_cells(side)
	var warning: Array[Vector2i] = _hazards.sand_warning_cells(side)
	var fallen: Array[Vector2i] = _hazards.fallen_cells(side)
	if sand.is_empty() and warning.is_empty() and fallen.is_empty():
		return base
	var out: Array[Vector2i] = base.duplicate()
	for cell: Vector2i in sand + warning + fallen:
		if not out.has(cell):
			out.append(cell)
	return out


func _exit_tree() -> void:
	if _trait_host != null:
		_trait_host.teardown_all()
	if _hazards != null:
		# Story 036: extra_blocked_fn holds the movers and the movers' sand blocker / step cost hold the hazards;
		# break that RefCounted cycle so a finished match does not leak its TileHazards.
		_hazards.extra_blocked_fn = Callable()
	if _status != null:
		# Drop tiles: the status hooks hold the movers; break that cycle too.
		_status.step_locked_fn = Callable()
		_status.hole_blocked_fn = Callable()
		for mover: UnitMover in [_mover, _boss.get_mover() if _boss != null else null]:
			if mover != null:
				mover.step_cost_fn = Callable()
	if _passive != null:
		_passive.teardown()
	for relic: BaseRelic in _relics:
		relic.teardown()
	_relics.clear()
	_cast_info = {}
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
	_formation = FormationMap.new().init(
		enemy_cells, maxf(_override(_config.formation_fade_for(enemy_cells.size()), "formation_fade"), 0.0))
	_signature.setup(
		{"state": _state, "grid": _grid, "boss": _boss, "status": _status,
			"skill_config": _skill_config, "cut_config": _cut_config, "cooldowns": _cooldowns,
				"formation": _formation},
		(params as Dictionary) if typeof(params) == TYPE_DICTIONARY else {})
	_signature_name_key = str(dict.get("name_key", ""))
	var cooldown: Variant = dict.get("cooldown_sec", 0.0)
	_signature_cooldown_sec = maxf(float(cooldown), 0.0) if (typeof(cooldown) == TYPE_FLOAT or typeof(cooldown) == TYPE_INT) else 0.0
	_signature_cooldown_sec = maxf(_override(_signature_cooldown_sec, "signature_cooldown"), 0.0)
	_signature_cooldown_left = 0.0
	_arbiter.player_cells_modifier = Callable(_signature, "modify_cells")
	_arbiter.player_signature_modifier = Callable(_signature, "modify_damage")
	_mover.cooldown_scale = Callable(_signature, "step_cooldown_scale")
	# Story 037: the three hooks of the zone / Ran / Han signatures (the base returns the neutral value).
	_arbiter.player_zone_sec_mult_fn = Callable(_signature, "zone_sec_mult")
	_arbiter.player_extra_thorn_cells_fn = Callable(_signature, "extra_thorn_cells")
	_status.fragile_mult_fn = Callable(_signature, "fragile_mult_override")
	_status.frost_burst_mult_fn = Callable(_signature, "frost_burst_mult")


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
	if _cut_flow.is_menu_open() or _placed:
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
	_stats["signatures_used"] = int(_stats["signatures_used"]) + 1
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
	for cell: Vector2i in _formation.lit_cells():
		get_floor_vfx().play("engraving_complete", cell, CombatState.Side.ENEMY)  # Story 048 F3
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
# F2 (pillar 2 "Base Attributes", OD-2 approved 2026-11-13): the character's two new multipliers.
# Called BEFORE _setup_passive on purpose: `cast_speed_mult` rides the PLAYER actor's `duration_mult`,
# which CutActor.begin_swing applies BEFORE the passive's `duration_modifier` — the approved order is
# base -> attribute -> passive -> signature. `duration_mult` is free for the player: it is otherwise
# only ever set on boss / enemy actors (their per-match swing speed).
# NOTE (OD-10, approved): `cast_time_fn` and `duration_override` OVERWRITE the windup later in
# begin_swing, so a card with a fixed cast_time_sec ignores this multiplier, exactly as it already
# ignores the passive. That is intended: a fixed cast time stays fixed.
# Both multipliers default to 1.0, so a match without a character is byte-identical to before F2.
func _setup_attributes(character: Dictionary) -> void:
	var cast_speed: float = float(character.get("cast_speed_mult", 1.0))
	if cast_speed > 0.0:
		_cut_actor.duration_mult = cast_speed
	var resist: float = float(character.get("hazard_resist_mult", 1.0))
	_hazard_resist_mult = resist if resist > 0.0 else 1.0


# F2: hazard damage [param amount] aimed at [param side], scaled by the character's
# `hazard_resist_mult` when — and only when — the target is the PLAYER.
# The guard is load-bearing: since multi-enemy Phase 4 `side` is a UNIT KEY, not a board half, so
# applying the player's attribute to whatever arrives would hand it to enemy units as well.
func _hazard_amount(side: int, amount: float) -> float:
	return amount * _hazard_resist_mult if side == CombatState.Side.PLAYER else amount


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
			"skill_config": _skill_config, "cut_config": _cut_config,
			"heal_player": Callable(self, "_passive_heal_player")},
		(params as Dictionary) if typeof(params) == TYPE_DICTIONARY else {})
	_cut_actor.duration_modifier = Callable(_passive, "modify_swing_duration")
	_arbiter.player_damage_modifier = Callable(_passive, "modify_damage")
	_passive.on_match_start()


## Story 032: the run's relics of this match, in received order (empty without relics). For the HUD strip;
## each relic's own `triggered` signal is re-emitted as [signal relic_triggered].
func get_relics() -> Array[BaseRelic]:
	return _relics


## Story 032: the merged config overrides of this match's relics (RelicRegistry.merge_overrides form).
func get_relic_overrides() -> Dictionary:
	return _relic_overrides


## Story 032: how many pieces may be joined into one cast: combat.json max_pieces_per_cast, raised by a
## relic's max_join_pieces (tam_hop).
func get_max_join_pieces() -> int:
	return maxi(_config.max_pieces_per_cast, RelicRegistry.max_join_pieces(_relics))


# Story 032: match_params["relics"] as relic ids (non-strings and empty ids skipped).
func _relic_ids() -> Array[String]:
	var ids: Array[String] = []
	var raw: Variant = match_params.get("relics", [])
	if typeof(raw) != TYPE_ARRAY:
		return ids
	for entry: Variant in raw as Array:
		if typeof(entry) == TYPE_STRING and not (entry as String).is_empty():
			ids.append(entry as String)
	return ids


# Story 032: builds the relics (RelicRegistry.instantiate; unknown ids warn and are skipped), merges their
# config overrides ONCE (before FieldDrops, the bag, FormationMap and StatusEffects are built) and sets them
# up with the match ctx: heal_player / damage_player (through CombatState) and give_piece (into the bag).
# The ctx Callables resolve lazily, so this can run before the match objects exist.
func _setup_relics(relic_ids: Array[String]) -> void:
	_relics.clear()
	for relic_id: String in relic_ids:
		var relic: BaseRelic = RelicRegistry.instantiate(relic_id)
		if relic == null:
			continue
		_relics.append(relic)
	_relic_overrides = RelicRegistry.merge_overrides(_relics)
	var ctx: Dictionary = {
		"heal_player": Callable(self, "_relic_heal_player"),
		"damage_player": Callable(self, "_relic_damage_player"),
		"give_piece": Callable(self, "_relic_give_piece"),
	}
	for relic: BaseRelic in _relics:
		relic.setup(ctx, relic.get_params())
		relic.triggered.connect(_on_relic_triggered)


# Story 032: [param base] after the relics' override of config [param key] (unchanged without one).
func _override(base: float, key: String) -> float:
	return RelicRegistry.apply_override(base, _relic_overrides, key)


# Story 032: the player's piece drops (a copy separate from the boss's): freshness, start pieces, interval.
# A non-positive result keeps the config's value.
func _apply_drop_overrides() -> void:
	if _relic_overrides.is_empty():
		return
	var fresh: float = _override(_drops_config.piece_freshness_sec, "piece_freshness_sec")
	if fresh > 0.0:
		_drops_config.piece_freshness_sec = fresh
	_drops_config.start_pieces = maxi(roundi(_override(float(_drops_config.start_pieces), "start_pieces")), 0)
	var interval: float = _override(_drops_config.piece_spawn_interval_sec, "piece_spawn_interval")
	if interval > 0.0:
		_drops_config.piece_spawn_interval_sec = interval


# Story 041: the match key `odd_blocks` (merged over the file block), then the DEV arg --odd-chance=X, on
# [param config] BEFORE the boss copy is made (both sides get the same odd tuning).
func _apply_odd_overrides(config: FieldDropsConfig) -> void:
	var raw: Variant = match_params.get("odd_blocks", null)
	if raw is Dictionary:
		config.odd = config.odd.with_overrides(raw as Dictionary)
	elif raw != null:
		push_warning("CombatView: match odd_blocks must be an object, ignored")
	var dev_chance: float = dev_odd_chance()
	if dev_chance >= 0.0:
		config.odd.chance = dev_chance


## Story 041 DEV-ONLY: the chance given by the user arg `--odd-chance=X` (clamped 0..1), or -1 when absent.
static func dev_odd_chance() -> float:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(DEV_ODD_CHANCE_ARG):
			return clampf(arg.substr(DEV_ODD_CHANCE_ARG.length()).to_float(), 0.0, 1.0)
	return -1.0


# Story 032: the bag's slot count (hold_slots.json piece_slot_count, then the relics' hold_slots).
func _apply_hold_override(hold_config: HoldSlotsConfig) -> void:
	if not _relic_overrides.has("hold_slots"):
		return
	var view := get_node_or_null(hold_slots_view_path) as HoldSlotsView
	if view != null:
		view.set_slot_count_override(maxi(roundi(_override(float(hold_config.piece_slot_count), "hold_slots")), 1))


# Story 032: burn stack cap and Han burst stacks / damage on this match's config copy, before
# configure_status hands them to StatusEffects.
func _apply_status_overrides() -> void:
	if _relic_overrides.is_empty():
		return
	_config.burn_max_stacks = maxi(roundi(_override(float(_config.burn_max_stacks), "burn_max_stacks")), 1)
	_config.frost_stacks_to_burst = maxi(roundi(_override(float(_config.frost_stacks_to_burst), "han_stacks")), 1)
	_config.frost_burst_damage = maxf(_override(_config.frost_burst_damage, "han_damage"), 0.0)


# Story 032: hooks the relics into the arbiter (damage, zones) and the player actor (windup).
func _wire_relics() -> void:
	_arbiter.player_zone_overrides = _relic_overrides
	if _relics.is_empty():
		return
	_arbiter.player_relic_modifier = Callable(self, "_relic_damage")
	_cut_actor.cast_time_modifier = Callable(self, "_relic_cast_time")


# Story 032: cast_info of a player cast ({pieces, cells, joined, featured, card_id, hit}).
func _make_cast_info(card_id: String, cells: Array[Vector2i], pieces: Array[String], joined: bool, featured: bool) -> Dictionary:
	return {"pieces": pieces.duplicate(), "cells": cells.size(), "joined": joined, "featured": featured,
		"card_id": card_id, "hit": false}


# Story 032: the ONE relic damage point (SwingArbiter.player_relic_modifier -> CutEffects).
func _relic_damage(cells: int, damage: float) -> float:
	var info: Dictionary = _cast_info.duplicate()
	info["cells"] = cells
	return RelicRegistry.fold_damage(_relics, info, damage)


# Story 032: the ONE relic windup point (CutActor.cast_time_modifier, once per begun player swing).
func _relic_cast_time(cells: int, sec: float) -> float:
	var info: Dictionary = _cast_info.duplicate()
	info["cells"] = cells
	return RelicRegistry.fold_cast_time(_relics, info, sec)


func _relic_heal_player(amount: float) -> void:
	if amount > 0.0 and not _state.is_player_dead():
		_state.set_player_hp(_state.player_hp + amount)


func _relic_damage_player(amount: float) -> void:
	_state.damage_player(amount)


# Story 032: puts one piece of [param shape_id] into the first free bag slot; false when the bag is full,
# missing or the shape unknown.
func _relic_give_piece(shape_id: String) -> bool:
	var hold: HoldSlots = _get_hold()
	if hold == null or hold.is_full() or _state.is_player_dead():
		return false
	if _relic_pieces == null:
		_relic_pieces = PieceLibrary.load_from_file()
	var piece: Piece = _relic_pieces.make_piece(shape_id)
	if piece == null:
		return false
	var point := FieldPoint.new()
	point.label = piece.shape_id
	point.cell = _state.player_cell
	point.piece = piece
	return hold.place_in_first_free(point) >= 0


func _on_relic_triggered(relic_id: String) -> void:
	relic_triggered.emit(relic_id)


# Story 032: a player swing resolved (hit or miss): on_cast_landed, and an_chu's flash when its featured
# override was used on a featured hit.
func _relics_on_cast_landed(result: Dictionary) -> void:
	if _relics.is_empty():
		_cast_info = {}
		return
	var info: Dictionary = _cast_info.duplicate()
	info["hit"] = bool(result.get("hit", false))
	var cast_cells: Array = result.get("cells", [])
	info["cells"] = cast_cells.size()
	_cast_info = {}
	if bool(result.get("featured", false)):
		for relic: BaseRelic in _relics:
			if relic.featured_mult_override() > 0.0 and relic.has_method("flash"):
				relic.call("flash")
	for relic: BaseRelic in _relics:
		relic.on_cast_landed(info)


## Public-API context the traits work through (BossTrait documents the keys): the same
## dictionary the match's TraitHost was built with. Logic-free; DemoArgs uses it to set up a
## trait by hand for captures.
func make_trait_ctx() -> Dictionary:
	return {
		"state": _state, "grid": _grid, "player_drops": _drops, "boss_drops": _boss.get_drops(),
		"boss": _boss, "status": _status, "arbiter": _arbiter, "hold_getter": Callable(self, "get_hold"), "player_mover": _mover,
		"skill_config": _skill_config, "cut_config": _cut_config,
		"hazards": _hazards, "placement": _placement,
		# Monster Skill Phase 0 (G6): the pattern brain's controller, read lazily (it is built after the host): burrow /
		# rebirth pause it, shroud reads its stage. Null in block-brain matches.
		"pattern_getter": Callable(self, "get_pattern_controller"),
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
func _apply_brain_params(brain_config: BossBrainConfig, params: Variant = null) -> void:
	# Multi-enemy Phase 3 (A2): [param params] = a unit's resolved `ai` block (null = the match's own keys, unit 0)
	var mp: Dictionary = self.match_params if params == null else params as Dictionary
	if mp.has("boss_step_cooldown_sec"):
		push_warning("CombatView: boss_step_cooldown_sec is deprecated, use boss_step_cooldown_mult")
		brain_config.step_cooldown_sec = maxf(float(mp["boss_step_cooldown_sec"]), 0.0)
	elif mp.has("boss_step_cooldown_mult"):
		brain_config.step_cooldown_sec = maxf(_base_step_cooldown * float(mp["boss_step_cooldown_mult"]), 0.0)
	brain_config.think_interval_sec = maxf(float(mp.get("boss_think_interval_sec", brain_config.think_interval_sec)), 0.0)
	brain_config.reaction_sec = maxf(float(mp.get("boss_reaction_sec", brain_config.reaction_sec)), 0.0)
	if mp.has("boss_root_while_swinging"):
		brain_config.root_while_swinging = bool(mp["boss_root_while_swinging"])
	var wanted: String = str(mp.get("brain_set", ""))
	if not wanted.is_empty():
		if brain_config.has_set(wanted):
			brain_config.active_set = wanted
		else:
			push_warning("CombatView: unknown brain_set '%s' in match params" % wanted)
	if mp.has("boss_reaction_sec"):
		# The match value is more specific than the set's own movement.reaction_sec.
		brain_config.override_movement(brain_config.active_set, {"reaction_sec": brain_config.reaction_sec})
	if float(mp.get("combo_chance", -1.0)) >= 0.0:
		brain_config.override_weight(brain_config.active_set, "combo_chance", float(mp["combo_chance"]))
	if float(mp.get("combo_gap_sec", -1.0)) >= 0.0:
		brain_config.override_weight(brain_config.active_set, "combo_gap_sec", float(mp["combo_gap_sec"]))
	var movement_override: Variant = mp.get("movement")
	if typeof(movement_override) == TYPE_DICTIONARY and not (movement_override as Dictionary).is_empty():
		brain_config.override_movement(brain_config.active_set, movement_override as Dictionary)


# Counts REAL time after a death, then emits match_ended once.
func _tick_end(delta: float) -> void:
	if _end_emitted or _state == null:
		return
	if _end_timer < 0.0:
		# Multi-enemy Phase 3: the match ends when the hero or EVERY required enemy unit is down (one unit: unit 0)
		if not (_state.is_player_dead() or _state.all_required_dead()):
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
	# Story 048: the floor effects run on the combat's scaled time (Focus / pause freeze them).
	get_floor_vfx().tick(scaled_delta(delta))
	_tick_hp_trail(delta)
	_tick_end(delta)
	_hook_hold()
	_check_odd_hint()
	if not freeze_time:
		# Cap the step so a frame hitch cannot skip a whole timing window.
		var real_step: float = minf(delta, _config.max_tick_sec)
		# The menu countdown runs on REAL time; it may close the menu this frame.
		_cut_flow.tick_real(real_step)
		# The place window (real time too) may press Tung phép this frame.
		_tick_place_window(real_step)
		_tick_pick_window(real_step)
		_age_refusal(real_step)
		# Simulation time is scaled down while the skill menu is open (slow motion); the boss
		# lives in the same scaled time.
		_update_focus(real_step)
		_formation_flash_left = maxf(_formation_flash_left - real_step, 0.0)
		_hit_shake_left = maxf(_hit_shake_left - real_step, 0.0)
		if _hit_stop_at >= 0.0 and get_floor_vfx().elapsed() >= _hit_stop_at:
			var feel: Dictionary = CastVfx.hit_feel()
			_hit_stop_at = -1.0
			_hit_stop_left = float(feel.get("hit_stop_sec", 0.0))
			_hit_shake_left = 0.0 if SettingsStore.shared().get_reduce_motion() else float(feel.get("board_shake_sec", 0.0))
		var step: float = real_step * _sim_scale()
		if _hit_stop_left > 0.0:
			# V4 hit-stop: the whole simulation holds for hit_stop_sec of real time, then carries on.
			_hit_stop_left = maxf(_hit_stop_left - real_step, 0.0)
			step = 0.0
		if step <= 0.0:
			# Full stop (Focus with scale 0): nothing in the simulation moves; real-time
			# things (menu, Focus clocks, match end) already ran above.
			queue_redraw()
			return
		_status.tick(step, _state)
		_hazards.tick(step, _state)
		_tick_signature(step)
		if _passive != null:
			_passive.tick(step)
		if _formation != null:
			_formation.tick(step)
		_mover.tick(step)
		var hold: HoldSlots = _get_hold()
		var held: int = 0 if hold == null else hold.get_occupied_count()
		_learning.tick(step, hold != null and hold.is_full())
		var burning: Array[Vector2i] = _status.burning_cells()
		_drops.set_blocked_cells(_drop_blocked_cells(burning, CombatState.Side.PLAYER))
		_boss.get_drops().set_blocked_cells(_drop_blocked_cells(burning, CombatState.Side.ENEMY))
		# Each side's drops avoid the cells the opponent's swing is about to cut.
		var boss_actor: CutActor = _boss.get_actor()
		_drops.set_danger_cells(boss_actor.get_cells() if boss_actor.is_swinging() else _no_cells())
		_boss.get_drops().set_danger_cells(_cut_actor.get_cells() if _cut_actor.is_swinging() else _no_cells())
		_drops.tick(step, _state.player_cell, held)
		_cooldowns.tick(step)
		_parry_guard.tick(step)
		_boss.tick(step, _cut_actor)
		if _pattern != null:
			_pattern.tick(step)
		# Multi-enemy Phase 3: units 1+ by index (deterministic order), then the shared threat clock
		for agent: EnemyAgent in _extra_agents:
			agent.controller.tick(step, _cut_actor)
			if agent.pattern != null:
				agent.pattern.tick(step)
		if _threat != null:
			_threat.tick(step)
		_sim_time += step
		_arbiter.tick(step)
		_resolve_channel_cancel()
		if hold != null:
			hold.tick_rot(step)
		# Traits run after the arbiter (they see this frame's resolutions) and only while both live.
		if not (_state.is_player_dead() or _state.is_enemy_dead()):
			_trait_host.on_tick(step)
		_age_flash(_feedback, step)
		_age_flash(_boss_feedback, step)
		# Multi-enemy Phase 4 (step 4): the per-unit records age on the same clock, then drop when they run out.
		for extra: Dictionary in _unit_feedback:
			_age_flash(extra, step)
		for extra: Dictionary in _boss_feedback_extra:
			_age_flash(extra, step)
		_unit_feedback = _live_records(_unit_feedback)
		_boss_feedback_extra = _live_records(_boss_feedback_extra)
		_age_flash(_interrupt_flash, step)
		_age_flash(_channel_flash, step)
		_age_flash(_feint_flash, step)
		_age_flash(_heal_flash, step)
		_age_flash(_parry_flash, step)
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
	elif selected and _focus.is_ready() and not _cut_flow.is_menu_open() and not _placed:
		# Focus keeps its own rules: it starts for the FIRST piece only (a joined piece is placed slowed, as before).
		_focus.try_start()


# Simulation speed factor this frame: skill menu, else Focus, else 1.
func _sim_scale() -> float:
	if _cut_flow.is_menu_open():
		return _skill_config.menu_time_scale
	if _focus.is_active():
		return _focus.get_time_scale()
	if _placed:
		# The place window: the match runs slowed like the card menu.
		return _skill_config.menu_time_scale
	if _placement != null and _placement.is_placing():
		# Story 024: PLACING without Focus (on cooldown) still slows the match.
		return _skill_config.menu_time_scale
	return 1.0


func _no_cells() -> Array[Vector2i]:
	return []


# Counts a feedback dictionary's time_left down; clears it in place when over. A "wait" (seconds) is spent first:
# the HIT marker of a wave cast waits for the wave to reach the target (user 2026-11-01).
# Multi-enemy Phase 4 (step 4): the records of [param list] that _age_flash has not emptied yet. A typed loop, not
# Array.filter, which hands back an untyped array.
func _live_records(list: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rec: Dictionary in list:
		if not rec.is_empty():
			out.append(rec)
	return out


func _age_flash(flash: Dictionary, step: float) -> void:
	if flash.is_empty():
		return
	var wait: float = float(flash.get("wait", 0.0))
	if wait > 0.0:
		flash["wait"] = wait - step
		return
	flash["time_left"] = float(flash["time_left"]) - step
	if float(flash["time_left"]) <= 0.0:
		flash.clear()


## How long the HIT/MISS marker stays on screen (UI timing, real-ish seconds of sim time).
const FEEDBACK_SEC: float = 0.8
## Cast rhythm spec 2026-11-05: match seconds the ĐỠ / PARRY label and the reflected number stay over the enemy.
const PARRY_FLASH_SEC: float = 0.9


## Story 016: true when the run may be paused now: not while the skill menu is open (nor in the place window
## before it, 2026-11-01: both run on real time) and not while the player's or the boss's swing has [member CombatConfig.pause_lockout_sec] or less
## left. No state change.
func can_pause() -> bool:
	if _cut_flow == null or _boss == null:
		return false
	if _cut_flow.is_menu_open() or _placed:
		return false
	var lockout: float = _config.pause_lockout_sec if _config != null else 0.0
	for actor: CutActor in [_cut_actor, _boss.get_actor()]:
		if actor.is_swinging() and actor.get_time_left() <= lockout:
			return false
	# Cast Commitment: never during the commit lock.
	if is_commit_locked():
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


## ADR-0002: the back ratio of the trapezoid board this match draws with ([member
## floor_perspective_override] when set, else combat.json's); FloorPerspective.OFF = flat. See FloorPerspective.of.
func floor_back_ratio() -> float:
	if floor_perspective_override >= 0.0:
		return floor_perspective_override
	return _config.floor_perspective_back_ratio if _config != null else FloorPerspective.OFF


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
# Story 027: zone cards (seal / thorns) are never the boss's (SkillConfig.boss_card_order).
func _boss_card_ids(params: Variant = null) -> Array[String]:
	# Multi-enemy Phase 3 (A2): [param params] = a unit's resolved `ai` block (null = the match's own keys, unit 0)
	var mp: Dictionary = self.match_params if params == null else params as Dictionary
	var ids: Array[String] = []
	var raw: Variant = mp.get("boss_cards", [])
	if typeof(raw) == TYPE_ARRAY:
		for id: Variant in raw as Array:
			if _skill_config.is_curse(str(id)):
				push_warning("CombatView: boss_cards '%s' is a curse card (the boss never has curses), dropped" % str(id))
			elif _skill_config.is_zone_card(str(id)):
				push_warning("CombatView: boss_cards '%s' is a zone card (the boss gets zones only through traits), dropped" % str(id))
			elif _skill_config.has_skill(str(id)) and not ids.has(str(id)):
				ids.append(str(id))
	elif mp.has("boss_cards"):
		push_warning("CombatView: mp boss_cards must be an array, using the basics")
	if ids.is_empty():
		ids = _skill_config.boss_card_order()
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
## does PLACING. 2026-11-04 (user: "trong quá trình cast thì ko có nhân vật hay quái nào được di chuyển"): also the
## place window and the open card menu, so nobody moves from picking a piece up until the card is chosen.
func is_movement_locked() -> bool:
	if _focus != null and _focus.is_active() and _focus.locks_movement():
		return true
	return is_casting()


## 2026-11-04: true from picking a piece up until the card is chosen (PLACING, the place window or the open menu).
## The match runs at cards.json menu_time_scale (0 = stopped) and the d-pad is locked the whole time.
func is_casting() -> bool:
	return is_placing() or _placed or (_cut_flow != null and _cut_flow.is_menu_open())


## Story 024: the piece being placed in its current rotation, null when not placing.
func get_placing_piece() -> Piece:
	return _placement.get_piece() if is_placing() else null


## True when the CONFIRM ("Tung phép") button should be on screen: a piece is being placed or pieces are placed
## (the place window runs), the card menu is closed and nobody is dead. (It is dimmed while [method can_cast] is false.)
func is_confirm_visible() -> bool:
	if _placement == null or _state == null or _cut_flow.is_menu_open():
		return false
	if _state.is_player_dead() or _state.is_enemy_dead():
		return false
	return _placement.is_placing() or _placed


## True when [method confirm_placement] would commit the ghost now: the first piece (ghost on a valid placement, no
## own swing running) or, in the place window, a joined piece (room in the cast, cell cap). Never while the card
## menu is open.
func can_confirm_placement() -> bool:
	if _cut_flow.is_menu_open() or not is_placing():
		return false
	if _placed:
		return can_join_piece() and _placement.can_confirm() and _fits_cap(_placement.get_cells())
	return is_confirm_visible() and _placement.can_confirm() and not _cut_actor.is_swinging()


## True when pressing Tung phép ([method press_cast]) would open the card menu now: pieces are placed, or the first
## piece's ghost sits on a valid placement; no own swing running.
func can_cast() -> bool:
	if not is_confirm_visible() or _cut_actor.is_swinging():
		return false
	return _placed or can_confirm_placement()


## True in the place window: at least one piece committed on the enemy half, the card menu not open yet.
func is_placed() -> bool:
	return _placed


## REAL seconds left of the place window (0 outside it; 0 too while it has no limit).
func get_place_time_left() -> float:
	return maxf(_place_left, 0.0) if _placed and not is_place_unlimited() else 0.0


## Dev/capture only: sets the REAL seconds left of the running place window (no effect outside it).
func debug_set_place_time_left(sec: float) -> void:
	if _placed:
		_place_left = maxf(sec, 0.0)


## Length of the place window: cuts.json place_window_sec x the card time setting (0 = no limit).
func get_place_duration() -> float:
	return 0.0 if is_place_unlimited() or _cut_config == null else _cut_config.place_window_sec * _time_mult


## True while the place window never runs out (card time "không giới hạn").
func is_place_unlimited() -> bool:
	return _time_mult <= 0.0


## Applies the "Thời gian chọn lá" value [param mode] (SettingsStore.CARD_TIMES) to this match: the card menu's
## choose time and the place window both use its multiplier (0 = no limit). Unknown values count as normal.
func set_card_time(mode: String) -> void:
	card_time_mode = mode
	_time_mult = SettingsStore.card_time_mult(mode)
	if _cut_flow != null:
		_cut_flow.time_mult = _time_mult


## Story 024: selects the piece in bag slot [param index] and enters PLACING (the selection set of the
## hand holds exactly that slot, so Focus starts / ends through _update_focus as before). Selecting
## the slot that is already being placed rotates the piece instead when [param rotate_if_selected].
## Returns false (nothing changes) for an empty / rotten slot, an open menu or a dead unit.
func select_piece(index: int, rotate_if_selected: bool = true) -> bool:
	var hold: HoldSlots = _get_hold()
	var joining: bool = _placed
	if hold == null or _state.is_player_dead() or _state.is_enemy_dead():
		return false
	# 2026-11-01: no piece is taken from the bag while the card menu is open (joins happen before Tung phép).
	if _cut_flow.is_menu_open():
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
	_lifted = false
	var blocked: Array[Vector2i] = []
	if joining:
		blocked = _plan.cells()
	var began: bool = _placement.begin(index, piece, blocked)
	if began:
		piece_selected.emit(index)
	return began


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
	# ADR-0002: the finger is on the drawn board; BoardGeometry maps it back to the model (flat) board to aim.
	var geo: BoardGeometry = board_geometry()
	var model_pos: Vector2 = geo.to_model(pos)
	var point: Vector2 = geo.to_model(Vector2(pos.x, pos.y - lift))
	var board: Rect2 = geo.flat_board_rect()
	if lift > 0.0 and board.has_point(model_pos) and point.y < board.position.y:
		point.y = board.position.y + 1.0
	return _placement.move_to(geo.cell_at_model(point))


## ADR-0002: the board geometry this battle draws with (BoardGeometry.of; flat when outside the tree).
func board_geometry() -> BoardGeometry:
	var geo: BoardGeometry = BoardGeometry.of(self)
	if geo == null:
		geo = BoardGeometry.make(_grid, get_viewport_rect().size, floor_back_ratio())
	return geo


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


## Finger lifted at [param pos]: when the ghost sits on the enemy half the piece is committed (the first one
## starts the place window, a later one joins the cast; the card menu does NOT open, returns true); anywhere else
## the piece goes back (PLACING ends, returns false).
func end_drag(pos: Vector2) -> bool:
	if not _dragging:
		return false
	drag_to(pos)
	_dragging = false
	if can_confirm_placement() and confirm_placement():
		return true
	if _placed:
		_note_refusal()
	_drop_placement()
	_close_empty_window()
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
	return board_geometry().cell_center(cell) + Vector2(0.0, get_drag_lift_px())


## Commits the ghost (quick spec menu-la-giua-man-hinh-2026-11-01): the FIRST piece leaves the bag and starts the
## place window (cuts.json place_window_sec, real time, the match slowed); in the place window a later piece joins
## the cast (Story 028/032 join rules, no time added). The card menu does NOT open here: see [method press_cast].
## Returns false (nothing changes) unless [method can_confirm_placement].
func confirm_placement() -> bool:
	var hold: HoldSlots = _get_hold()
	if hold == null or not can_confirm_placement():
		return false
	if _placed:
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
	hold.clear_selection()
	_plan.init(get_max_join_pieces(), _config.max_cast_cells)
	_plan.add_piece(slot, piece, cells)
	_join_points.clear()
	_join_slots.clear()
	_join_refusal = {}
	_placed = true
	_place_left = get_place_duration()
	_notify_pattern_aim()
	piece_placed.emit(slot, cells.duplicate())
	return true


## Tung phép: commits a valid ghost still being placed (the first piece, or a join in the place window; an invalid
## join ghost goes back to the bag), then opens the card menu on the placed cast: 4 cards drawn, menu_choose_sec of
## real time (x the card time setting), the match slowed, the basic slash on timeout. Returns false (nothing changes)
## unless [method can_cast].
func press_cast() -> bool:
	if not can_cast():
		return false
	if is_placing():
		if can_confirm_placement():
			confirm_placement()
		else:
			_drop_placement()
	if not _placed:
		return false
	return _open_card_menu()


# Opens the card menu on the placed cast (the place window ends): any piece still being placed goes back to the bag.
# 2026-11-04: one cast clock (place_window_sec) covers placing AND choosing: the menu gets what is left of it.
func _open_card_menu() -> bool:
	_drop_placement()
	if _plan.piece_count() == 0:
		# 2026-11-04: every piece was lifted off and left in the bag: nothing to cast, no card is drawn.
		_close_empty_window()
		return false
	var left: float = -1.0 if is_place_unlimited() else maxf(_place_left, 0.0)
	_placed = false
	_place_left = 0.0
	# Story 033: the menu hand keeps at least one non-curse card while the deck has one; a drawn curse
	# with draw_damage (oan_hon) hurts the player once per draw.
	var hand: Array[String] = _deck.draw_menu(_skill_config.hand_size, Callable(_skill_config, "is_curse"))
	var cast_cells: Array[Vector2i] = _plan.cells()
	if not _cut_flow.open_menu(_plan_labels(), cast_cells, hand, left):
		return false
	placement_confirmed.emit(cast_cells.duplicate())
	_apply_curse_draw_damage(hand)
	return true


# Counts the cast clock down on REAL time. At zero in the place window the pieces on the floor stay as they are (a
# piece still being dragged goes back to the bag) and a random available card of the drawn hand is cast at once
# (user 2026-11-04). Never with the window unlimited, and not once a unit is dead.
func _tick_place_window(real_step: float) -> void:
	if not _placed or is_place_unlimited() or _state == null:
		return
	if _state.is_player_dead() or _state.is_enemy_dead():
		return
	_place_left -= real_step
	if _place_left <= 0.0:
		_place_left = 0.0
		# A lifted piece (lift_placed_piece) whose ghost still sits on a valid spot goes back into the cast as it is.
		if _lifted and is_placing() and can_confirm_placement():
			confirm_placement()
		if _open_card_menu():
			_cut_flow.tick_real(0.0)
		else:
			_close_empty_window()


# 2026-11-04: picking the FIRST piece up stops the match too, so it is capped by the same cast clock (real time): when
# it runs out before the piece lands, the piece goes back to the bag and the match runs again.
func _tick_pick_window(real_step: float) -> void:
	if _placed or not is_placing() or is_place_unlimited() or _cut_flow.is_menu_open():
		_pick_left = -1.0
		return
	if _pick_left < 0.0:
		_pick_left = get_place_duration()
	_pick_left -= real_step
	if _pick_left <= 0.0:
		_pick_left = -1.0
		_drop_placement()


# Story 033: each curse in [param hand] with draw_damage > 0 costs the player that much HP now
# (CombatState.damage_player; one hit per copy drawn). Emits curse_drawn per hit.
func _apply_curse_draw_damage(hand: Array[String]) -> void:
	for id: String in hand:
		var dmg: float = _skill_config.draw_damage(id)
		if dmg > 0.0 and _state != null:
			_state.damage_player(dmg)
			curse_drawn.emit(id, dmg)


## Story 028: true while the placed cast still has room for another piece (max_pieces_per_cast; Story 032 tam_hop:
## 3): in the place window (before Tung phép) the bag stays live and a piece dragged from it joins the cast. Never
## while the card menu is open (2026-11-01).
func can_join_piece() -> bool:
	if _cut_flow == null or _plan == null or not _placed or _cut_flow.is_menu_open():
		return false
	if _state.is_player_dead() or _state.is_enemy_dead():
		return false
	# 2026-11-04: a lifted piece may leave the plan empty for a moment; it can still be put back.
	return not _plan.is_full()


## Story 028: the cast being built (from the first piece placed until the card is chosen; empty otherwise).
func get_cast_plan() -> CastPlan:
	return _plan


## Story 028: the featured shape of this match ({cells, bonus}; empty = feature off on this board).
func get_featured() -> Dictionary:
	return _featured


## Story 028: true when the placed plan (place window or open menu) is a two-piece cast whose union equals the
## featured shape.
func is_plan_featured() -> bool:
	return _cut_flow != null and (_placed or _cut_flow.is_menu_open()) and not _featured.is_empty() \
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


## 2026-11-04 (user: "đặt mảnh khối xuống rồi thì ko thể điều chỉnh nó nữa"): index of the placed piece of the cast
## covering board cell [param cell] in the place window (nothing being placed, menu closed); -1 otherwise.
func placed_piece_at(cell: Vector2i) -> int:
	if not _placed or is_placing() or _cut_flow.is_menu_open():
		return -1
	for i: int in _plan.piece_count():
		if _plan.piece_cells(i).has(cell):
			return i
	return -1


## [method placed_piece_at] for a screen point (BoardGeometry.cell_at, the drawn board).
func placed_piece_at_screen(pos: Vector2) -> int:
	return placed_piece_at(board_geometry().cell_at(pos))


## 2026-11-04: lifts the placed piece [param index] off the cast back into PLACING, its ghost on the same cells and
## in the same rotation (the piece goes back to its bag slot as the selected one). Then it moves like any piece being
## placed: drag / tap a cell to move it, Xoay to rotate, release / tap the ghost to put it back into the cast, release
## off the enemy half to leave it in the bag. The cast clock keeps running. False (nothing changes) outside the place
## window or for a bad index.
func lift_placed_piece(index: int) -> bool:
	var hold: HoldSlots = _get_hold()
	if hold == null or not _placed or is_placing() or _cut_flow.is_menu_open() or index < 0 or index >= _plan.piece_count():
		return false
	var cells: Array[Vector2i] = _plan.piece_cells(index)
	var piece: Piece = _plan.pieces()[index]
	var point: FieldPoint = null
	var slot: int = -1
	if index == 0:
		point = _pending_piece
		slot = _pending_slot
		if _join_points.is_empty():
			_pending_piece = null
			_pending_slot = -1
		else:
			_pending_piece = _join_points.pop_front()
			_pending_slot = _join_slots.pop_front()
	elif index - 1 < _join_points.size():
		point = _join_points[index - 1]
		slot = _join_slots[index - 1]
		_join_points.remove_at(index - 1)
		_join_slots.remove_at(index - 1)
	_plan.remove_piece(index)
	if point == null:
		return false
	point.piece = piece
	var at: int = hold.place(point, slot) if slot >= 0 else -1
	if at < 0:
		at = hold.place_in_first_free(point)
	if at < 0 or not select_piece(at, false):
		return false
	_placement.place_on(cells)
	_lifted = true
	return true


## Story 028: takes the LAST joined piece off the cast (the second; Story 032 tam_hop: the third first) and
## puts it back into its bag slot (place window only, the place timer keeps running). False when the cast has a
## single piece or the card menu is open.
func detach_second_piece() -> bool:
	if not _placed or _cut_flow.is_menu_open() or _plan.piece_count() < 2:
		return false
	_plan.remove_piece(_plan.piece_count() - 1)
	var point: FieldPoint = _join_points.pop_back() if not _join_points.is_empty() else null
	var slot: int = _join_slots.pop_back() if not _join_slots.is_empty() else -1
	var hold: HoldSlots = _get_hold()
	if point != null and hold != null and hold.place(point, slot) < 0:
		hold.place_in_first_free(point)
	return true


# Attaches the piece being placed as the cast's next piece (place window; Story 032: up to get_max_join_pieces). The
# piece leaves the bag; the cast is the union of the cells (no time is added). A refused plan keeps the piece in the bag.
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
	_lifted = false
	_consuming = true
	_join_slots.append(slot)
	_join_points.append(hold.remove(slot))
	_consuming = false
	hold.clear_selection()
	piece_placed.emit(slot, cells.duplicate())
	if not _relics.is_empty():
		var info: Dictionary = _make_cast_info("", _plan.cells(), _plan_labels(), true, is_plan_featured())
		for relic: BaseRelic in _relics:
			relic.on_join(info)
	_notify_pattern_aim()
	return true


# P2.3: a block was just placed on the enemy half; the pattern brain learns where the cast aims (Rootling creep fires
# only right after a block was placed over its cell).
func _notify_pattern_aim() -> void:
	if _pattern != null:
		_pattern.on_player_aim(_plan.cells())
	for agent: EnemyAgent in _extra_agents:
		if agent.pattern != null:
			agent.pattern.on_player_aim(_plan.cells())


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


## Esc / cancel button. While PLACING the first piece: leaves the mode (piece stays in its slot). In the place
## window or while the card menu is open: every placed piece goes back into its slot (or the first free one), a
## piece still being placed too, and the menu closes (its cards go back to the front of the bag).
## Returns true when something was cancelled.
func cancel_placement() -> bool:
	if _placed and not _cut_flow.is_menu_open():
		_drop_placement()
		_placed = false
		_place_left = 0.0
		_return_join_piece()
		_return_pending_piece()
		_plan.clear()
		return true
	if _cut_flow.is_menu_open():
		# Story 028: Cancel returns BOTH pieces (and ends a second piece still being dragged).
		_drop_placement()
		_cut_flow.cancel_menu()
		# TD-013: the drawn menu cards go back to the front of the bag, so a retry offers them again.
		if _deck != null:
			_deck.return_last_draw()
		_return_join_piece()
		_return_pending_piece()
		_plan.clear()
		return true
	if not is_placing():
		return false
	_drop_placement()
	return true


# 2026-11-04: ends the place window when every piece of the cast was lifted off and left in the bag (nothing is
# being placed): the match runs again.
func _close_empty_window() -> void:
	if not _placed or is_placing() or _plan.piece_count() > 0:
		return
	_placed = false
	_place_left = 0.0
	_plan.clear()
	_return_join_piece()
	_return_pending_piece()


# Leaves PLACING and clears the bag selection (Focus ends through _update_focus: DESELECTED).
func _drop_placement() -> void:
	_dragging = false
	_lifted = false
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


# Story 028: puts the attached pieces 2.. back into the bag (Story 032: every joined piece).
func _return_join_piece() -> void:
	var points: Array[FieldPoint] = _join_points.duplicate()
	var slots: Array[int] = _join_slots.duplicate()
	_join_points.clear()
	_join_slots.clear()
	var hold: HoldSlots = _get_hold()
	if hold == null:
		return
	for i: int in points.size():
		var point: FieldPoint = points[i]
		if point != null and hold.place(point, slots[i] if i < slots.size() else -1) < 0:
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
	_join_points.clear()
	_join_slots.clear()
	# Story 028: the featured bonus rides on the swing only for a two-piece cast matching the shape; a
	# second piece still being dragged when the menu times out goes back to the bag.
	var bonus: Dictionary = {}
	if not _featured.is_empty() and _plan.is_featured(_featured["cells"] as Array[Vector2i]):
		bonus = (_featured["bonus"] as Dictionary).duplicate(true)
		# Story 032: an_chu replaces the featured multiplier (its flash fires when the swing lands).
		var featured_override: float = RelicRegistry.featured_mult_override(_relics)
		if featured_override > 0.0:
			bonus["damage_mult"] = featured_override
	var info: Dictionary = _make_cast_info(skill_id, cells, _plan_labels(), _plan.piece_count() >= 2, not bonus.is_empty())
	# Skill v2 B1 (CastContext, M01): the pieces, their cells and shape tags, read before the plan is cleared.
	var piece_cells: Array = []
	for i: int in _plan.piece_count():
		piece_cells.append(_plan.piece_cells(i))
	# B1.5: plus the cast-time snapshot (cast mode, featured bonus details, the damage cell count after the signature's
	# cell rule, the arbiter clock).
	var effective: int = cells.size()
	if _arbiter != null and _arbiter.player_cells_modifier.is_valid():
		effective = maxi(int(_arbiter.player_cells_modifier.call(cells.size())), 0)
	var ctx: Dictionary = CastContext.build(skill_id, get_card_level(skill_id), _plan.pieces(), piece_cells,
		delivery_for(skill_id), not bonus.is_empty(), CombatState.Side.PLAYER, _state.player_cell,
		{"cast_mode": _skill_config.cast_mode(skill_id), "featured_bonus": bonus, "effective_cells": effective,
			"t_cast": _arbiter.clock() if _arbiter != null else 0.0})
	_plan.clear()
	_drop_placement()
	# Skill v2 batch 3 (M10, option A2): a self-anchored card (ward) casts on its shape re-anchored on the hero's own half.
	if _skill_config.is_self_anchored(skill_id):
		cells = WardAnchor.remap(cells, _state.player_cell, _grid, _status)
	_begin_cut(skill_id, cells, bonus, info, ctx)
	_try_pick_up_under_player()


# Story 032: [param cast_info] is the relics' view of the cast (_make_cast_info); empty = a bare cast of
# [param cells] with no pieces (tests / dev paths). It is kept until the swing resolves.
func _begin_cut(skill_id: String, cells: Array[Vector2i], featured_bonus: Dictionary = {}, cast_info: Dictionary = {}, cast_context: Dictionary = {}) -> void:
	var level: int = get_card_level(skill_id)
	_cast_info = cast_info if not cast_info.is_empty() else _make_cast_info(
		skill_id, cells, [] as Array[String], false, not featured_bonus.is_empty())
	if _cut_actor.begin_swing(cells, skill_id, true, level, -1.0, featured_bonus, cast_context):
		_cooldowns.start(skill_id, float(_resolved_card(skill_id, level).get("cooldown_sec", 0.0)))
		# Cast rhythm spec 2026-11-05: a parry card opens the guard now; the card was chosen at the end of the cast stop,
		# so its parry_sec runs from the moment the match runs again (the guard ticks on match time only).
		if _skill_config.is_parry_card(skill_id):
			_parry_guard.open_from_card(_resolved_card(skill_id, level))
		if _signature != null:
			_signature.on_cast(skill_id, cells.size())


## Story 020: the player's level of card [param skill_id] (highest copy in the deck; 1 when the
## deck has no levels or does not hold the card).
func get_card_level(skill_id: String) -> int:
	if _deck != null and _deck.has_method("level_of"):
		return maxi(int(_deck.call("level_of", skill_id)), 1)
	return 1


## Story 020 HUD hook: burn stacks on the boss's half (highest over its burning cells; 0 = none).
## Multi-enemy Phase 4 (step 3): with [param key] the burn on THAT unit's own cells (so a chip belongs to the unit it
## is drawn under); the default -1 keeps the legacy answer, the strongest burn anywhere on the enemy half.
func get_burn_stacks(key: int = -1) -> int:
	var cells: Array[Vector2i] = []
	if key >= 0 and key != CombatState.Side.PLAYER:
		var own: Array[Vector2i] = _state.unit_cells(key)
		for cell: Vector2i in _status.burning_cells():
			if own.has(cell):
				cells.append(cell)
		return _status.max_stacks_on(cells)
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


## Cast rhythm spec 2026-11-05: the SkillAvailability context of the match now (CutFlow, the card menu greying, the
## timeout pick): {enemy_telegraph: true while a pattern enemy winds up / warns an attack or the block-brain boss swings}.
func get_availability_context() -> Dictionary:
	var ctx: Dictionary = {SkillAvailability.CTX_ENEMY_TELEGRAPH: ParryGuard.enemy_telegraph(_pattern, _boss.get_actor() if _boss != null else null)}
	# Skill v2 delayed (Hỏa Lôi): the armed-field cap and the cells a delayed card could still arm on the open cut.
	if _arbiter != null:
		var arb: SwingArbiter = _arbiter
		var st: StatusEffects = _status
		# batch 3: a trap card's cap counts its armed trap casts on the enemy half
		ctx[SkillAvailability.CTX_ARMED_COUNT_FN] = func(id: String) -> int: return arb.armed_cast_count(CombatState.Side.PLAYER, id) \
			+ (st.trap_cast_count(CombatState.Side.ENEMY, id) if st != null else 0)
		if _cut_flow != null and _cut_flow.is_menu_open():
			ctx[SkillAvailability.CTX_DELAYED_OPEN_CELLS] = SkillAvailability.delayed_open_cells(_cut_flow.menu_cells(),
				_arbiter.armed_cells(CombatState.Side.PLAYER), _status)
	# Skill v2 batch 1 (Thương Xuyên): the placed pieces' shape tags while the menu is open (requires_shape).
	if _cut_flow != null and _cut_flow.is_menu_open() and _plan != null and _state != null:
		ctx[SkillAvailability.CTX_PIECE_TAGS] = SkillAvailability.piece_tags_of(_plan, _state.player_cell)
	return ctx


## Cast rhythm spec 2026-11-05: the hero's parry guard (never null).
func get_parry_guard() -> ParryGuard:
	return _parry_guard


## Cast rhythm spec 2026-11-05: the last parry's flash ({cell, reflected, time_left}; empty when none shows).
func get_parry_flash() -> Dictionary:
	return _parry_flash


# A parry landed: the HUD shows ĐỠ / PARRY and the reflected number over the enemy (its hit flash comes from the
# reflect damage itself); counted in the match stats.
func _on_parried(_blocked: float, reflected: float, _pin_sec: float) -> void:
	_parry_flash = {"cell": _state.enemy_cell, "reflected": reflected, "time_left": PARRY_FLASH_SEC}
	_stats["parries"] = int(_stats.get("parries", 0)) + 1


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
		"skill_id": str(result.get("skill_id", "")),
		"crit": bool(result.get("crit", false)),
	}
	# Multi-enemy Phase 4 (step 4): one cut may hit several units. The merged result carries the TOTAL damage at the
	# first hit unit's cell, which would print one wrong number over one unit; split it back per unit, so each unit
	# shows its own number over its own cell. A single-unit result has no `unit_results` and is untouched.
	# The split belongs to the player's cut only, and the clear must stay inside that branch: clearing it for every
	# resolved swing would wipe the numbers of the player's last cut the moment any enemy unit resolves its own.
	# A scheduled cast already printed each impact through _on_impact_resolved, so it is skipped here as well.
	var scheduled: bool = bool(result.get("scheduled", false))
	if side == CombatState.Side.PLAYER and not scheduled and result.has("unit_results"):
		_unit_feedback.clear()
		var own: Array = []
		for raw: Variant in result["unit_results"] as Array:
			var r: Dictionary = raw as Dictionary
			if not bool(r.get("hit", false)) or float(r.get("damage", 0.0)) <= 0.0:
				continue
			own.append(r)
		if own.size() == 1:
			feedback["damage"] = float((own[0] as Dictionary).get("damage", feedback["damage"]))
		elif own.size() > 1:
			# The marker (cells, HIT / MISS, featured) stays on the first hit unit and carries its own number; every
			# further unit gets a number-only record over its own cell.
			feedback["damage"] = float((own[0] as Dictionary).get("damage", 0.0))
			feedback["cell"] = (own[0] as Dictionary).get("cell", feedback["cell"])
			feedback["crit"] = bool((own[0] as Dictionary).get("crit", false))
			for i: int in range(1, own.size()):
				var r2: Dictionary = own[i] as Dictionary
				_unit_feedback.append({
					"cells": [] as Array[Vector2i], "hit": true, "damage": float(r2.get("damage", 0.0)),
					"cell": r2.get("cell", feedback["cell"]), "time_left": FEEDBACK_SEC,
					"pin_bonus": bool(r2.get("pin_bonus", false)), "featured": false, "featured_mult": 1.0,
					"featured_effect": "", "skill_id": str(result.get("skill_id", "")),
					"crit": bool(r2.get("crit", false)), "number_only": true,
				})
	# Skill v2: a scheduled cast drew its impacts event by event (_on_impact_resolved) and its HIT marker showed at the
	# hitting event; only a whole miss still shows its marker here, at the cast's end.
	if not scheduled:
		_play_cut_vfx(side, feedback)
	if side == CombatState.Side.PLAYER:
		# Skill v2 batch 3: a field-zone card that formed its zone without a hit (a ward, a pillar, an armed trap) is not a
		# MISS: no marker (the zone itself is the feedback).
		var zone_only: bool = not bool(result["hit"]) and ["ward", "pillar", "trap"].has(str(result.get("zone_kind", "")))
		if not (scheduled and bool(result["hit"])) and not zone_only:
			_feedback = feedback
		_count_cast(_cast_info)
		_relics_on_cast_landed(result)
		# Story 029: the one cover point (hit or miss; interrupted / cancelled swings never resolve).
		var cast_cells: Array[Vector2i] = []
		cast_cells.assign(result["cells"] as Array)
		_cover_formation(cast_cells)
		if _signature != null and bool(result["hit"]):
			_signature.on_hit(str(result.get("skill_id", "")), float(result["damage"]))
		if _pattern != null:
			# Phase 2: every player cast may break markers; a hit interrupts an interruptible windup / warning (D9).
			_pattern.on_player_cast(cast_cells)
			# Skill v2 fix 2026-11-08: a scheduled cast interrupted the pattern at its FIRST damaging impact
			# (SwingArbiter.pattern_hit_fn), as the interruption policy says; not again at the cast's end.
			# Multi-enemy Phase 2 (decision 5): the pattern brain belongs to unit 0 and reacts to a hit on unit 0 only.
			if CutEffects.hit_unit0(result) and not bool(result.get("no_interrupt", false)) and not bool(result.get("scheduled", false)):
				_pattern.on_enemy_hit()
		# Multi-enemy Phase 3: the extra units' patterns: every cast may break their markers; a hit reaches the hit unit's
		# own pattern only (A3)
		var hit_keys: Array = result.get("unit_keys_hit", []) as Array
		for agent: EnemyAgent in _extra_agents:
			if agent.pattern == null:
				continue
			agent.pattern.on_player_cast(cast_cells)
			if hit_keys.has(agent.key) and not bool(result.get("no_interrupt", false)) and not bool(result.get("scheduled", false)):
				agent.pattern.on_enemy_hit()
		_trait_host.on_player_swing_resolved(result)
		# Phase 2: the traits belong to unit 0: they hear the damage unit 0 took (the whole damage with one unit)
		_trait_host.on_boss_damaged(float(result.get("unit0_damage", result["damage"])))
	else:
		# Multi-enemy Phase 4 (step 4): unit 0 keeps the legacy single record; every other attacking unit adds its own,
		# so a second unit striking in the same breath does not erase the first one's marker.
		if side == CombatState.Side.ENEMY:
			_boss_feedback = feedback
		else:
			# Every enemy cut resolves on the PLAYER's cell, so two units striking inside FEEDBACK_SEC would stack
			# two whole markers on one anchor. The extra ones print their number only, lifted one line per record,
			# so the player reads "two blows landed" instead of an unreadable pile.
			feedback["number_only"] = true
			feedback["stack"] = _boss_feedback_extra.size() + 1
			_boss_feedback_extra.append(feedback)
		if bool(result["hit"]) and not bool(result.get("parried", false)):
			_stats["hits_taken"] = int(_stats["hits_taken"]) + 1
		# Phase 3 (A1): the learning record of the unit that swung; the traits belong to unit 0 (Phase 5)
		_learning.on_boss_swing_resolved(bool(result["hit"]), side)
		if side == CombatState.Side.ENEMY:
			_trait_host.on_boss_swing_resolved(result)


func _on_swing_interrupted(victim_side: int, cells: Array[Vector2i], _skill_id: String) -> void:
	_interrupt_flash = {"side": victim_side, "cells": cells, "time_left": FEEDBACK_SEC}
	for cell: Vector2i in cells:
		get_floor_vfx().play("interrupt", cell, victim_side)  # Story 048 F8
	if victim_side != CombatState.Side.PLAYER:
		_learning.on_player_interrupted_boss()
		for relic: BaseRelic in _relics:
			relic.on_interrupt_by_player()


func _on_boss_swing_started(cells: Array[Vector2i], skill_id: String, _duration: float) -> void:
	_learning.on_boss_swing_started(cells, _state.player_cell)
	if _trait_host != null:
		_trait_host.on_boss_swing_started(cells, skill_id)


func _on_boss_swing_cancelled(_cells: Array[Vector2i], _skill_id: String) -> void:
	_learning.on_boss_swing_cancelled()


func _on_boss_feinted(cells: Array[Vector2i], _labels: Array[String]) -> void:
	_feint_flash = {"cells": cells, "time_left": FEEDBACK_SEC}


# Story 035: one resolved player cast for the match stats ([param info] = the cast's _make_cast_info).
func _count_cast(info: Dictionary) -> void:
	_stats["casts"] = int(_stats["casts"]) + 1
	# World Map v2 objectives (03 section 5): the largest cast of the match, in cells.
	_stats["max_cast_cells"] = maxi(int(_stats["max_cast_cells"]), int(info.get("cells", 0)))
	if bool(info.get("joined", false)):
		_stats["joins"] = int(_stats["joins"]) + 1
	if bool(info.get("featured", false)):
		_stats["featured_casts"] = int(_stats["featured_casts"]) + 1


# Story 035: a REGION boss (match_params boss_can_down) reaching 0 HP is DOWNED: it stays drawn (kneeling),
# stops deciding / moving / dropping, its field pieces are removed and its zones and burns on the player's
# half stop and clear. The match ends as before (_tick_end, end_delay_sec, match_ended).
func _on_enemy_died() -> void:
	if not can_boss_down() or _downed:
		return
	_downed = true
	_boss.set_active(false)
	_boss.get_actor().cancel()
	var boss_drops: FieldDrops = _boss.get_drops()
	boss_drops.set_blocked_cells(_no_cells())
	for point: FieldPoint in boss_drops.get_points():
		boss_drops.pick_up_at(point.cell, true)
	_status.clear_zones(CombatState.Side.PLAYER)
	var burning: Array[Vector2i] = []
	for cell: Vector2i in _status.burning_cells():
		if _grid.is_player_cell(cell):
			burning.append(cell)
	if not burning.is_empty():
		_status.clear_burn(burning)


## Story 035: true when this match's boss is a region boss that is downed (not removed) at 0 HP
## (match_params [constant PARAM_BOSS_CAN_DOWN]).
func can_boss_down() -> bool:
	return bool(match_params.get(PARAM_BOSS_CAN_DOWN, false))


## Story 035: true once the region boss reached 0 HP and is downed (stays drawn behind the FATE screen).
func is_boss_downed() -> bool:
	return _downed


## Story 035: this match's numbers for the run stats: {damage_dealt (HP the boss lost), damage_taken (HP the
## player lost), hits_taken (boss swings that hit the player), casts (player swings that resolved), joins (of
## them, casts of joined pieces), featured_casts (casts of the arena's featured shape), signatures_used,
## frost_bursts (Han bursts on the boss, Story 037), boss_thorn_steps (times the boss stepped onto one of the
## player's thorn cells, Story 037), max_cast_cells (World Map v2: the largest player cast, in cells), vents_dodged
## (World Map v2: vent eruptions on the player's half the player was not standing in)}.
## All 0 before anything happened. Read-only.
func get_match_stats() -> Dictionary:
	var out: Dictionary = _stats.duplicate()
	# Multi-enemy Phase 2 (decision 6): the damage dealt to EVERY enemy unit (one unit: enemy_damage_taken)
	var dealt: float = 0.0
	if _state != null:
		for u: EnemyUnit in _state.units:
			dealt += u.damage_taken
	out["damage_dealt"] = dealt
	out["damage_taken"] = _state.player_damage_taken if _state != null else 0.0
	return out


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


## Multi-enemy Phase 3: the agents of units 1+ (index order; [] with one unit).
func get_extra_agents() -> Array[EnemyAgent]:
	return _extra_agents


## Multi-enemy Phase 3: the shared threat book (D1).
func get_threat_board() -> ThreatBoard:
	return _threat


## Multi-enemy Phase 3: the BossController of the unit [param key] (unit 0 = get_boss()); null when unknown.
func controller_of(key: int) -> BossController:
	if key == CombatState.Side.ENEMY:
		return _boss
	for agent: EnemyAgent in _extra_agents:
		if agent.key == key:
			return agent.controller
	return null


## Multi-enemy Phase 3: the PatternController of the unit [param key] (unit 0 = get_pattern_controller()); null for a
## block-brain unit or an unknown key.
## Multi-enemy Phase 4 (step 1): the PatternController of the unit [param key] for the view layers (null for a
## block-brain unit, the player or an unknown key). Public face of [method _pattern_of].
func pattern_of(key: int) -> PatternController:
	return _pattern_of(key)


func _pattern_of(key: int) -> PatternController:
	if key == CombatState.Side.ENEMY:
		return _pattern
	for agent: EnemyAgent in _extra_agents:
		if agent.key == key:
			return agent.pattern
	return null


# Multi-enemy Phase 3 (D3): think interval x sqrt(N) for N >= 2 enemy units, clamped 0.05..1.0 s; N = 1 unchanged.
func _scaled_think(base: float) -> float:
	var n: int = _state.unit_count() if _state != null else 1
	if n <= 1:
		return base
	return clampf(base * sqrt(float(n)), 0.05, 1.0)


# Multi-enemy Phase 3: builds the threat book and, with 2+ units, one agent per unit 1+ (MULTI-ENEMY-PHASE3-5-PLAN.md
# 1.1b): its own BossBrainConfig from its `ai` block (A2), a BossController on the SHARED half drops (D4) with its own
# hand (D5), a PatternController for a pattern-brain unit (its key, the shared F2 / F5 / tokens), its actor in the
# arbiter, the same zone / hazard blockers as unit 0, its learning record (A1). Unit 0 keeps every legacy wire.
func _setup_extra_units(boss_drops_config: FieldDropsConfig, hold_config: HoldSlotsConfig) -> void:
	var n: int = _state.unit_count()
	_threat = ThreatBoard.new(int(match_params.get("attack_slots", 1)), n)
	_threat.extra_red_fn = Callable(self, "trait_warning_cells")
	_boss.threat_board = _threat
	if _pattern != null:
		_pattern.threat_board = _threat
	_state.unit_died.connect(_on_unit_died)
	if n <= 1:
		return
	var e: int = CombatState.Side.ENEMY
	_threat.register_red(e, _red_cells_of.bind(_boss, _pattern))
	if _pattern != null:
		_pattern.external_red_fn = func() -> Array: return _threat.red_cells(e)
		_pattern.allies_fn = _allies_of.bind(e)
	var shared: FieldDrops = _boss.get_drops()
	var drops_enabled: bool = not is_pattern_brain()
	var chapter: String = str(match_params.get("chapter_id", ""))
	var skills_config: EnemySkillsConfig = null
	var status: StatusEffects = _status
	var hazards: TileHazards = _hazards
	for i: int in range(1, n):
		var unit: EnemyUnit = _state.get_unit(i)
		var key: int = CombatState.unit_key(i)
		var ai: Dictionary = unit.source.get("ai", {}) as Dictionary
		var cfg: BossBrainConfig = BossBrainConfig.load_from_file()
		_apply_brain_params(cfg, ai)
		cfg.think_interval_sec = _scaled_think(cfg.think_interval_sec)
		var pattern_unit: bool = str(unit.source.get("brain", "")) == RunConfig.BRAIN_PATTERN \
				and not str(unit.source.get("enemy", "")).is_empty()
		var seed_i: int = drops_seed + 10 * i if drops_seed >= 0 else -1
		var ctrl := BossController.new(_state, _grid, _cut_config, _skill_config, cfg, boss_drops_config, hold_config,
			seed_i, key, shared)
		if not pattern_unit:
			ctrl.enable_pieces(PieceLibrary.load_from_file(), chapter, seed_i + 2 if seed_i >= 0 else -1, _config.max_pieces_per_cast)
			if not drops_enabled:
				# the shared half drops start dropping pieces once a block-brain unit is on the team
				shared.enable_pieces(PieceLibrary.load_from_file(), chapter, _grid, seed_i + 2 if seed_i >= 0 else -1, false)
				drops_enabled = true
		ctrl.threat_board = _threat
		ctrl.set_player_step_cooldown(_player_step_cooldown)
		ctrl.get_brain().cards = _boss_card_ids(ai)
		ctrl.get_brain().min_runes = maxi(int(ai.get("boss_min_runes", 0)), 0)
		ctrl.get_actor().duration_mult = maxf(float(ai.get("swing_speed_mult", 1.0)), 0.01)
		ctrl.set_status(_status)
		ctrl.set_learning(_learning)
		ctrl.set_hazards(_hazards)
		ctrl.pending_threat_fn = _arbiter.pending_cells.bind(CombatState.Side.PLAYER)
		ctrl.cast_delay_fn = func(actor: CutActor) -> float:
			return CastResolver.threat_delay(_skill_config.get_skill(actor.get_skill_id()), actor.get_cast_context())
		ctrl.feinted.connect(_on_boss_feinted)
		var actor: CutActor = ctrl.get_actor()
		actor.swing_started.connect(_on_extra_swing_started.bind(key))
		actor.swing_cancelled.connect(_on_extra_swing_cancelled.bind(key))
		_arbiter.add_enemy_actor(key, actor)
		# the same step blockers as unit 0 (holes, pillars, fire walls, sand, fallen cells) and its own mire cost
		var mover: UnitMover = ctrl.get_mover()
		_movers_by_key[key] = mover
		mover.add_blocker(func(cell: Vector2i) -> bool: return status.is_hole(e, cell))
		mover.add_blocker(func(cell: Vector2i) -> bool: return status.is_pillar(e, cell))
		mover.add_blocker(func(cell: Vector2i) -> bool: return status.is_fire_wall(cell))
		mover.add_blocker(func(cell: Vector2i) -> bool: return hazards.is_sanded(e, cell) or hazards.is_fallen(e, cell))
		var mover_key: int = key
		mover.step_cost_fn = func(from_cell: Vector2i) -> float: return hazards.step_cost_mult(mover_key, from_cell)
		_hazards.set_mire_immune(key, bool(ai.get("mire_immune", false)))
		var pattern: PatternController = null
		if pattern_unit:
			if skills_config == null:
				skills_config = EnemySkillsConfig.load_from_file()
			pattern = PatternController.new(_state, _grid, skills_config, str(unit.source["enemy"]), _status,
				drops_seed + 4 + 10 * i if drops_seed >= 0 else -1, key)
			pattern.think_interval_sec = maxf(cfg.think_interval_sec, 0.05)
			pattern.tempo_mult = maxf(float(ai.get("pattern_tempo_mult", 1.0)), 0.01)
			pattern.player_step_cd = _player_step_cooldown
			pattern.player_step_left_fn = Callable(_mover, "get_cooldown_remaining")
			var red_key: int = key
			pattern.external_red_fn = func() -> Array: return _threat.red_cells(red_key)
			pattern.allies_fn = _allies_of.bind(key)
			pattern.player_guard = _parry_guard
			pattern.threat_board = _threat
			pattern.hazards = _hazards
			pattern.player_blocked_fn = Callable(_mover, "is_cell_blocked")
			pattern.reactions = _config.reactions() if _config != null else {}
			pattern.markers_changed.connect(_mark_floor_dirty)
			# Multi-enemy fix (2026-11-13): bind THIS unit's key, so its VFX leaves its own cells.
			pattern.skill_resolved.connect(_on_pattern_skill_resolved.bind(key))
			ctrl.extra_step_lock_fn = Callable(pattern, "is_busy")
		_threat.register_red(key, _red_cells_of.bind(ctrl, pattern))
		_extra_agents.append(EnemyAgent.new(key, unit, ctrl, pattern, cfg))
	# D4: the shared drops' "hungry" rule reads the emptiest block-brain hand of the team
	_boss.hand_count_fn = _min_block_hand
	# every enemy unit plans around and refuses EVERY pattern marker on the half (markers are cells of the shared half)
	var all_marks: Callable = _all_marker_cells
	_boss.get_brain().extra_own_blocked_fn = all_marks
	_boss.get_mover().add_blocker(func(cell: Vector2i) -> bool: return (all_marks.call() as Array).has(cell))
	for agent: EnemyAgent in _extra_agents:
		agent.controller.get_brain().extra_own_blocked_fn = all_marks
		agent.controller.get_mover().add_blocker(func(cell: Vector2i) -> bool: return (all_marks.call() as Array).has(cell))


# Phase 3 (F2): the red / queued cells the unit behind [param ctrl] / [param pattern] shows now.
func _red_cells_of(ctrl: BossController, pattern: PatternController) -> Array:
	var out: Array = []
	if pattern != null:
		out.append_array(pattern.telegraph_cells())
		out.append_array(pattern.queued_cells())
		return out
	var actor: CutActor = ctrl.get_actor()
	if actor.is_swinging():
		out.append_array(actor.get_cells())
	if actor.has_queued():
		out.append_array(actor.get_queued_cells())
	return out


# Phase 3: the pattern ally conditions for the unit [param key]: {alive: other living units, died_within_sec: seconds
# since another unit died (INF when none), min_hp_ratio: the lowest HP ratio among the other living units (1 = none)}.
func _allies_of(key: int) -> Dictionary:
	var alive: int = 0
	var min_ratio: float = 1.0
	for other: int in _state.enemy_keys(true):
		if other == key:
			continue
		alive += 1
		min_ratio = minf(min_ratio, _state.hp_of(other) / maxf(_state.max_hp_of(other), 0.001))
	var since: float = INF
	for dead: Variant in _unit_died_at.keys():
		if int(dead) != key:
			since = minf(since, _sim_time - float(_unit_died_at[dead]))
	return {"alive": alive, "died_within_sec": since, "min_hp_ratio": min_ratio}


# Phase 3 (D4): the fewest pieces held by a living block-brain unit (unit 0 included when it is block brain).
func _min_block_hand() -> int:
	var best: int = -1
	if not is_pattern_brain() and not _state.is_unit_dead(0):
		best = _boss.get_hand().get_occupied_count()
	for agent: EnemyAgent in _extra_agents:
		if agent.is_block_brain() and not _state.is_key_dead(agent.key):
			var held: int = agent.controller.get_hand().get_occupied_count()
			best = held if best < 0 else mini(best, held)
	return maxi(best, 0)


# Phase 3: the marker cells of every pattern unit (unit 0 first).
func _all_marker_cells() -> Array:
	var out: Array = []
	if _pattern != null:
		out.append_array(_pattern.marker_cells())
	for agent: EnemyAgent in _extra_agents:
		if agent.pattern != null:
			out.append_array(agent.pattern.marker_cells())
	return out


# Phase 3 (A1): an extra unit's swing started / was cancelled: its own learning record.
func _on_extra_swing_started(cells: Array[Vector2i], _skill_id: String, _duration: float, key: int) -> void:
	_learning.on_boss_swing_started(cells, _state.player_cell, key)


func _on_extra_swing_cancelled(_cells: Array[Vector2i], _skill_id: String, key: int) -> void:
	_learning.on_boss_swing_cancelled(key)


# Phase 3: a unit died: its attack token goes back and an extra unit's agent stops (unit 0 keeps ticking its owned
# drops; its brain and pattern stop on their own death checks).
func _on_unit_died(index: int) -> void:
	var key: int = CombatState.unit_key(index)
	_unit_died_at[key] = _sim_time
	if _threat != null:
		_threat.release(key)
	if index == 0:
		return
	for agent: EnemyAgent in _extra_agents:
		if agent.key == key:
			agent.controller.set_active(false)
			agent.controller.get_actor().cancel()


## Phase 2: true when this match runs the pattern brain (match_params `brain` == "pattern" with an `enemy` id).
func is_pattern_brain() -> bool:
	return str(match_params.get("brain", "")) == RunConfig.BRAIN_PATTERN and not str(match_params.get("enemy", "")).is_empty()


## Phase 2: the pattern brain's controller, or null for a block-brain match.
func get_pattern_controller() -> PatternController:
	return _pattern


## Phase 2: cells the TRAITS are warning about on the player's half right now (traits exposing get_warning_cells:
## row_burner, slam, fuse_cannon). The pattern brain counts them for the red ceiling (F2) and as unsafe (F1, spec 3.9).
## Board coordinates (the same as CombatState.player_cell); only cells of the player's half are returned.
func trait_warning_cells() -> Array:
	var out: Array = []
	if _trait_host == null or _grid == null:
		return out
	for t: BossTrait in _trait_host.get_traits():
		if t != null and t.has_method("get_warning_cells"):
			for cell: Vector2i in t.call("get_warning_cells") as Array:
				if _grid.is_player_cell(cell) and not out.has(cell):
					out.append(cell)
	return out


# Phase 2: builds the PatternController for a `brain: "pattern"` match (spec 3.1, 3.7, 3.9): the enemy from
# enemy_skills.json, the match's think interval, the player's step cooldown and step-left clock, the floor tempo
# (`pattern_tempo_mult`), the trait warnings as external red, and the boss's mover held still while a skill runs.
# Movement between skills stays the BossBrain's. An unknown enemy id warns and leaves the match on the block brain's
# movement only (no skills).
func _setup_pattern_brain(brain_config: BossBrainConfig) -> void:
	if not is_pattern_brain():
		return
	var enemy_id: String = str(match_params["enemy"])
	var skills_config: EnemySkillsConfig = EnemySkillsConfig.load_from_file()
	if skills_config.get_enemy(enemy_id).is_empty():
		push_warning("CombatView: pattern enemy '%s' not in enemy_skills.json" % enemy_id)
	_pattern = PatternController.new(_state, _grid, skills_config, enemy_id, _status, drops_seed + 4 if drops_seed >= 0 else -1)
	_pattern.think_interval_sec = maxf(brain_config.think_interval_sec, 0.05)
	_pattern.tempo_mult = maxf(float(match_params.get("pattern_tempo_mult", 1.0)), 0.01)
	_pattern.player_step_cd = _player_step_cooldown
	_pattern.player_step_left_fn = Callable(_mover, "get_cooldown_remaining")
	_pattern.external_red_fn = Callable(self, "trait_warning_cells")
	_pattern.player_guard = _parry_guard
	_boss.extra_step_lock_fn = Callable(_pattern, "is_busy")
	_pattern.markers_changed.connect(_mark_floor_dirty)
	# P2.4 (spec 7.1): the boss never steps onto its own markers: the brain plans around them and the mover refuses them.
	var pattern: PatternController = _pattern
	_boss.get_brain().extra_own_blocked_fn = Callable(pattern, "marker_cells")
	_boss.get_mover().add_blocker(func(cell: Vector2i) -> bool: return pattern.marker_cells().has(cell))
	# Monster Skill Phase 0 (docs/design/world-map-v2/MONSTER-SKILL-DESIGN.md §5.2, §11 step 0): the effects that reuse
	# existing code reach the controller through the same public objects the traits use.
	_pattern_base_tempo = _pattern.tempo_mult
	_pattern.hazards = _hazards
	_pattern.player_blocked_fn = Callable(_mover, "is_cell_blocked")
	_pattern.reactions = _config.reactions() if _config != null else {}
	if _trait_host != null:
		_trait_host.extra_untargetable_fn = Callable(pattern, "is_evading")
		_trait_host.extra_forecast_blocked_fn = Callable(pattern, "is_shrouded")
		_trait_host.extra_reaction_immune_fn = Callable(pattern, "reaction_immune")
	# G4: the strike's delivery drives its travel / impact VFX (presentation only, after the damage was applied).
	_pattern.skill_resolved.connect(_on_pattern_skill_resolved)
	# G5: a phase's traits / brain_set / tempo_mult are applied when it starts; the HUD banner hears it too.
	_pattern.phase_started.connect(_on_pattern_phase_started)
	_apply_pattern_phase(0)


# Phase 0 (G4): plays a resolved pattern ATTACK through the cards' cut VFX path with the SKILL's delivery (the cards'
# delivery_for only knows cards.json). A skill without a usable delivery plays the SkillDelivery fallback and warns once.
## Multi-enemy fix (2026-11-13): [param key] names the unit whose skill resolved. _play_cut_vfx takes the caster's
## cast origin from it, so a travelling effect leaves the unit that cast it. Without the key every pattern unit's VFX
## flew out of unit 0 — out of a corpse once unit 0 had died.
func _on_pattern_skill_resolved(skill_id: String, result: Dictionary, key: int = CombatState.Side.ENEMY) -> void:
	var feedback: Dictionary = PatternController.vfx_feedback(result)
	if feedback.is_empty():
		return
	if bool(feedback.get("delivery_fallback", false)) and not _pattern_vfx_warned.has(skill_id):
		_pattern_vfx_warned[skill_id] = true
		push_warning("CombatView: enemy skill '%s' has no usable delivery, the fallback VFX is played" % skill_id)
	_play_cut_vfx(key, feedback, feedback["delivery"] as Dictionary)


# Phase 0 (G5): the pattern enemy entered phase [param index]: the previous phase's traits go, the new phase's come
# (TraitHost.add_trait, the phase_shift mechanism), the movement brain switches set, the tempo follows the phase, and
# the HUD banner fires through the host (PHA n, n = index + 1, as boss_phases announces it).
func _on_pattern_phase_started(index: int, _phase_id: String) -> void:
	_apply_pattern_phase(index)
	if _trait_host != null and index > 0:
		_trait_host.announce_phase(index + 1)


func _apply_pattern_phase(index: int) -> void:
	if _pattern == null:
		return
	if _trait_host != null:
		for t: BossTrait in _pattern_phase_traits:
			_trait_host.remove_trait(t)
		_pattern_phase_traits.clear()
		for spec: Variant in _pattern.phase_traits(index):
			var d: Dictionary = spec as Dictionary
			var added: BossTrait = _trait_host.add_trait(str(d.get("id", "")), d.get("params", {}) as Dictionary)
			if added != null:
				_pattern_phase_traits.append(added)
	var set_name: String = _pattern.phase_brain_set(index)
	if not set_name.is_empty() and _boss != null and _boss.get_brain() != null:
		_boss.get_brain().use_set(set_name)
	_pattern.tempo_mult = _pattern_base_tempo * _pattern.phase_tempo_mult(index)


## Story 025: true while the boss is rooted by its own swing (see BossController.is_step_locked).
func is_boss_step_locked() -> bool:
	return _boss.is_step_locked()


## Multi-enemy Phase 4 (step 5): true when the unit of [param key] is rooted by its own running swing (the foot-lock
## seal, F10). Unit 0 answers exactly as [method is_boss_step_locked].
func is_step_locked_of(key: int) -> bool:
	var ctrl: BossController = controller_of(key)
	return ctrl != null and ctrl.is_step_locked()


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


## Multi-enemy Phase 4 (step 4): the number-only records of the other units a single player cut hit (one per unit past
## the first, each over its own cell). Empty with one enemy unit.
func get_unit_feedback() -> Array[Dictionary]:
	return _unit_feedback


## Multi-enemy Phase 4 (step 4): resolved cuts of the attacking units that are not unit 0. Empty with one enemy unit.
func get_boss_feedback_extra() -> Array[Dictionary]:
	return _boss_feedback_extra


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


## Story 034: the weights the player's drops use, from match_params["piece_deck"]
## (PieceDeck.weights_for_match); empty when the match has no deck (original library weights).
func get_player_piece_weights() -> Dictionary:
	return _player_piece_weights.duplicate()


## Story 034: true when none of the deck's shapes fits this arena's enemy half, so the player's drops
## fell back to the original weights of the shapes that fit (the HUD shows ui.piece_deck.fallback).
func is_piece_deck_fallback() -> bool:
	return _piece_deck_fallback


## Story 041: true once the first-pickup Odd Block hint fired in this match (the HUD shows it then).
func is_odd_hint_fired() -> bool:
	return _odd_hint_fired


## Story 041: shape ids of the pieces of the player's RUNNING cast ("odd:<key>" for an Odd Block); [] when no cast
## info is kept (no swing, or a bare dev swing). The HUD marks an odd cast with it.
func get_cast_piece_ids() -> Array[String]:
	var ids: Array[String] = []
	if _cut_actor != null and _cut_actor.is_swinging():
		for id: Variant in _cast_info.get("pieces", []):
			ids.append(str(id))
	return ids


# Story 041: fires the first-pickup hint the first frame an Odd Block sits in the player's bag (scanned, so every
# path into the bag counts and nothing depends on when the bag's signals are connected).
func _check_odd_hint() -> void:
	if not odd_hint_enabled or _odd_hint_fired:
		return
	var hold: HoldSlots = _get_hold()
	if hold == null:
		return
	for i: int in hold.get_slot_count():
		var point: FieldPoint = hold.get_point(i)
		if point != null and point.piece != null and point.piece.is_odd() and not point.rotten:
			_odd_hint_fired = true
			odd_hint_shown.emit()
			return


## Drop tuning in use (freshness total etc.).
func get_drops_config() -> FieldDropsConfig:
	return _drops_config


## Tries one step of the player in [param direction] (Vector2i.UP/DOWN/LEFT/RIGHT).
## Returns false on cooldown, wall, when dead, while Focus locks movement or a Cast Commitment channel / commit lock
## holds the hero (Ngàn Kiếm, [method is_cast_rooted]); nothing is queued.
func try_step_player(direction: Vector2i) -> bool:
	if is_step_locked():
		return false
	var from_cell: Vector2i = _state.player_cell
	var stepped: bool = _mover.try_step(direction)
	if stepped and _trait_host != null:
		_trait_host.on_player_stepped(from_cell, _state.player_cell)
	if stepped and _pattern != null:
		_pattern.on_player_stepped()  # Phase 0: conditions.player_steps_since
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


## Story 047: the BattleCanvas bound to this view, or null (a CombatView running alone). Named get_battle_canvas:
## CanvasItem already owns get_canvas() -> RID, which a script may not override.
func get_battle_canvas() -> BattleCanvas:
	return _canvas


## Story 047: called by BattleCanvas once its layers are bound to this view.
func set_canvas(canvas: BattleCanvas) -> void:
	_canvas = canvas
	queue_redraw()


# Story 047: the board, the player and the boss are drawn by the BattleCanvas layers (Floor / Unit); this
# view keeps the HUD band and the two step rings (Story 046 and the VFX story move them later).
func _draw() -> void:
	if _state == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	_draw_hud(vp)
	_draw_boss_ring(vp)
	_draw_cooldown_ring(vp)


# Story 047: screen-px centre of the unit of [param side]'s body: the UnitLayer's feet anchor (bottom-centre,
# FEET_INSET_ART art px above the cell's front edge) raised by half a cell minus that inset, i.e. the cell
# centre routed through the anchor, so the rings follow the unit when Part C moves the anchor. The cell
# centre itself when no canvas is bound.
func _unit_center(_vp: Vector2, side: int) -> Vector2:
	# The rings sit on the cell centre; the feet moved to FEET_DEPTH_RATIO of the cell (OSFE stance, 2026-10-31),
	# so they are no longer derived from the feet anchor.
	# ADR-0002: the drawn centres (BoardGeometry).
	if side == CombatState.Side.PLAYER:
		return board_geometry().cell_center(_state.player_cell)
	# P2.2b: the centre of the footprint's bounding rect (the cell centre for a 1-cell enemy).
	return board_geometry().cells_center(_state.enemy_footprint_cells())


# Story 046 Part B: the sharp Z1 header, drawn at screen resolution with HudSkin (never through the art
# canvas). 2026-10-31 (user, OSFE reference): both panels sit flush in the top corners
# (ScreenLayout.hud_panel_rect, 52 px at 720p). Player, top-left, cut bottom-right: row 1 name + "hp/max"
# right-aligned, row 2 the HP bar with the damage trail, row 3 the segmented Engraving bar + "lit/total".
# Boss, top-right, cut bottom-left: row 1 its held points as small tiles + name right-aligned, row 2 the Ivory
# HP bar with the half-HP notch, row 3 "hp/max" right-aligned. Sizes are 720p numbers times S = height / 720.
func _draw_hud(vp: Vector2) -> void:
	var s: float = vp.y / HUD_REF_HEIGHT
	if _config == null or not _config.hud_corner_panels:
		if _config != null and _config.hud_player_panel:
			_draw_player_panel(vp, s)
		_draw_floating_boss_hand(vp, s)
		return
	var cut: float = HUD_PANEL_CUT * s
	var left: Rect2 = ScreenLayout.hud_panel_rect(vp, 0)
	var right: Rect2 = ScreenLayout.hud_panel_rect(vp, 1)
	HudSkin.panel(self, left, [0.0, 0.0, cut, 0.0], Color(HudSkin.NIGHT_STONE, HUD_PANEL_ALPHA), HudSkin.MIST)
	HudSkin.panel(self, right, [0.0, 0.0, 0.0, cut], Color(HudSkin.NIGHT_STONE, HUD_PANEL_ALPHA), HudSkin.MIST)
	var inset: float = HUD_INSET * s
	var gap: float = HUD_NUMBER_GAP * s
	var name_size: int = roundi(HUD_NAME_FONT * s)
	var number_size: int = roundi(HUD_NUMBER_FONT * s)
	var small_size: int = roundi(HUD_SMALL_FONT * s)
	var name_y: float = left.position.y + HUD_NAME_BASELINE * s
	var row3_y: float = left.position.y + HUD_ROW3_BASELINE * s
	var bar_h: float = maxf(roundf(HUD_BAR_HEIGHT * s), 1.0)
	var bar_y: float = floorf(left.position.y + HUD_BAR_TOP * s)
	# --- player
	var bar := Rect2(Vector2(left.position.x + inset, bar_y), Vector2(floorf(left.size.x - inset * 2.0), bar_h))
	var hp_text: String = HUD_NUMBER_FORMAT % [ceili(_state.player_hp), ceili(_state.player_max_hp)]
	var hp_w: float = HudSkin.text_width(hp_text, number_size, true)
	HudSkin.text(self, Vector2(bar.end.x - hp_w, name_y), hp_text, number_size, HudSkin.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	var player_room: float = maxf(bar.size.x - hp_w - gap, 0.0)
	var player_name: String = get_player_name()
	HudSkin.text(self, Vector2(bar.position.x, name_y), player_name, _fit_font(player_name, name_size, roundi(HUD_NAME_MIN_FONT * s), player_room), HudSkin.TEXT, HORIZONTAL_ALIGNMENT_LEFT, player_room)
	HudSkin.hp_bar(self, bar, _hp_ratio(0), _hp_trail_shown(0), HudSkin.HP_FILL, false)
	var engraving := Rect2(Vector2(bar.position.x, floorf(left.position.y + HUD_ENGRAVING_TOP * s)), Vector2(maxf(floorf(bar.size.x - HUD_ENGRAVING_COUNT_ROOM * s), 1.0), maxf(roundf(HUD_ENGRAVING_HEIGHT * s), 1.0)))
	_draw_engraving(engraving, small_size, s, row3_y)
	# --- boss
	var bbar := Rect2(Vector2(right.position.x + inset, bar_y), Vector2(floorf(right.size.x - inset * 2.0), bar_h))
	var boss_name: String = tr(TEXT_UNIT_DEAD) % get_boss_name() if _state.is_enemy_dead() else get_boss_name()
	var tiles_w: float = _draw_boss_hand(Vector2(bbar.position.x, right.position.y + HUD_TILE_TOP * s), s)
	var name_room: float = maxf(bbar.size.x - tiles_w - gap, 0.0)
	HudSkin.text(self, Vector2(bbar.end.x - name_room, name_y), boss_name, _fit_font(boss_name, name_size, roundi(HUD_NAME_MIN_FONT * s), name_room), HudSkin.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, name_room)
	HudSkin.hp_bar(self, bbar, _hp_ratio(1), _hp_trail_shown(1), HudSkin.BOSS_HP_FILL, true)
	var boss_hp: String = HUD_NUMBER_FORMAT % [ceili(_state.enemy_hp), ceili(_state.enemy_max_hp)]
	HudSkin.text(self, Vector2(bbar.position.x, row3_y), boss_hp, small_size, HudSkin.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, bbar.size.x, true)


# 2026-11-03 (combat.json hud.player_panel): the player's own corner panel, top-left of the safe area
# (ScreenLayout.hud_player_panel_rect): row 1 name + "hp/max", row 2 the HP bar with the damage trail. No Engraving
# row: its count stays on the Awaken button. The boss has no panel (its HP stays on the plate under its feet).
func _draw_player_panel(vp: Vector2, s: float) -> void:
	var panel: Rect2 = ScreenLayout.hud_player_panel_rect(vp)
	# 2026-11-14 (user approved option B of production/qa/evidence/ui-style-2026-11-14/option-B-and-F.png): the
	# ancient stone plate instead of the 1 px Sương border. The panel rect is unchanged, so no layout and no touch
	# target moves; only the frame and the bar's own frame change.
	var content: Rect2 = HudSkin.stone_panel(self, panel)
	var name_size: int = roundi(HUD_NAME_FONT * s)
	var number_size: int = roundi(HUD_NUMBER_FONT * s)
	var name_y: float = floorf(content.position.y + HUD_PLATE_NAME_BASELINE * s)
	var bar_h: float = maxf(roundf(HUD_PLATE_BAR_HEIGHT * s), 1.0)
	var bar := Rect2(Vector2(content.position.x, floorf(content.end.y - bar_h)), Vector2(floorf(content.size.x), bar_h))
	var hp_text: String = HUD_NUMBER_FORMAT % [ceili(_state.player_hp), ceili(_state.player_max_hp)]
	var hp_w: float = HudSkin.text_width(hp_text, number_size, true)
	HudSkin.text(self, Vector2(bar.end.x - hp_w, name_y), hp_text, number_size, HudSkin.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	var room: float = maxf(bar.size.x - hp_w - HUD_NUMBER_GAP * s, 0.0)
	var player_name: String = get_player_name()
	HudSkin.text(self, Vector2(bar.position.x, name_y), player_name, _fit_font(player_name, name_size, roundi(HUD_NAME_MIN_FONT * s), room), HudSkin.TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, room)
	HudSkin.groove_bar(self, bar, _hp_ratio(0), _hp_trail_shown(0), HudSkin.HP_FILL)


# 2026-10-31 (combat.json hud.corner_panels = false): no corner panels; the boss's held points float on the
# top HUD row (ScreenLayout.hud_top_row_rect), right-aligned just left of the run's gold (left of the pause tile)
# (RunHudView), centred on the row; the HP lives on the numbers under the units' feet (CutHudView._draw_hp_plates).
func _draw_floating_boss_hand(vp: Vector2, s: float) -> void:
	if _boss == null or _boss.get_hand() == null:
		return
	var count: int = _boss.get_hand().get_slot_count()
	var tile: Vector2 = (HUD_TILE_SIZE * s).floor()
	var width: float = maxf(count * (tile.x + HUD_TILE_GAP * s) - HUD_TILE_GAP * s, 0.0)
	var row: Rect2 = ScreenLayout.hud_top_row_rect(vp)
	# Controls v3: left of the gold, which sits left of the pause tile in the top-right corner.
	var right: float = ScreenLayout.hud_gold_rect(vp).position.x - ScreenLayout.TOP_RIGHT_GAP_PX * s
	_draw_boss_hand(Vector2(floorf(right - width), floorf(row.get_center().y - tile.y * 0.5)), s)


# The largest font size from [param size] down to [param min_size] at which [param content] fits [param room]
# px (HudSkin SemiBold); min_size when nothing fits (the draw then clips at the room).
static func _fit_font(content: String, size: int, min_size: int, room: float) -> int:
	var fit: int = size
	while fit > min_size and HudSkin.text_width(content, fit) > room:
		fit -= 1
	return fit


# Story 046 Part B: the Engraving bar under the player's HP bar: HUD_ENGRAVING_SEGMENTS gold segments lit in
# proportion to the formation map's lit cells (all lit once the signature is ready) and "lit/total" right of
# it: the same source and total as CutHudView's "Engraving n/N" (FormationMap.lit_count / total). Nothing
# without a formation map (no signature this match).
func _draw_engraving(rect: Rect2, font_size: int, s: float, baseline: float) -> void:
	if _formation == null:
		return
	var total: int = maxi(_formation.total(), 1)
	var lit: int = _formation.lit_count()
	var filled: int = HUD_ENGRAVING_SEGMENTS if is_signature_ready() else floori(float(lit * HUD_ENGRAVING_SEGMENTS) / total)
	HudSkin.segments(self, rect, HUD_ENGRAVING_SEGMENTS, filled, HudSkin.GRID_LIGHT)
	var pos := Vector2(rect.end.x + HUD_NUMBER_GAP * s, baseline)
	HudSkin.text(self, pos, HUD_NUMBER_FORMAT % [lit, _formation.total()], font_size, HudSkin.GRID_LIGHT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)


# Story 046 Part B: the boss's held points as small chamfered tiles (HUD_TILE_SIZE at 720p), left to right
# from [param origin]; empty slots are faint frames, a point without a piece shows its label. Returns the
# row's width.
func _draw_boss_hand(origin: Vector2, s: float) -> float:
	if _pattern != null:
		return 0.0  # Phase 2 spec 3.7: a pattern-brain enemy holds no blocks, its slots are hidden.
	var hand: HoldSlots = _boss.get_hand()
	var count: int = hand.get_slot_count()
	var tile: Vector2 = (HUD_TILE_SIZE * s).floor()
	var gap: float = HUD_TILE_GAP * s
	var cuts: Array = [0.0, HUD_TILE_CUT * s, 0.0, 0.0]
	for i: int in count:
		var rect := Rect2(Vector2(floorf(origin.x + i * (tile.x + gap)), floorf(origin.y)), tile)
		var point: FieldPoint = hand.get_point(i)
		if point == null:
			HudSkin.panel(self, rect, cuts, Color(HudSkin.NIGHT_STONE, HUD_TILE_EMPTY_ALPHA), Color(HudSkin.MIST, HUD_TILE_EMPTY_ALPHA), 1.0)
			continue
		HudSkin.panel(self, rect, cuts, HudSkin.NIGHT_STONE_LIGHT, HudSkin.MIST, 1.0)
		if point.piece != null:
			_draw_boss_hand_piece(point.piece, rect)
			continue
		HudSkin.text(self, Vector2(rect.position.x, rect.end.y - HUD_TILE_TEXT_LIFT * s), point.label, roundi(HUD_TILE_FONT * s), HudSkin.TEXT, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	return maxf(count * (tile.x + gap) - gap, 0.0)


# Story 025: a held piece as a mini shape inside its slot tile; a rotten one is grey with a dark X.
func _draw_boss_hand_piece(piece: Piece, rect: Rect2) -> void:
	var area: Rect2 = rect.grow(-HAND_PIECE_PAD)
	if piece.is_rotten():
		PieceDraw.draw_shape(self, piece, area, Color(HAND_ROTTEN_GREY, 0.85), Color(0.0, 0.0, 0.0, 0.0), HAND_PIECE_MAX_UNIT)
		var x_rect: Rect2 = PieceDraw.shape_rect(piece, area, HAND_PIECE_MAX_UNIT).grow(HAND_PIECE_PAD)
		draw_line(x_rect.position, x_rect.end, HAND_ROTTEN_X, 2.0)
		draw_line(Vector2(x_rect.end.x, x_rect.position.y), Vector2(x_rect.position.x, x_rect.end.y), HAND_ROTTEN_X, 2.0)
		return
	if piece.is_odd():
		# Story 041: an Odd Block in the boss's hand row: odd fill and edge (the tile is too small for the mark).
		PieceDraw.draw_odd_shape(self, piece, area, PieceDraw.ODD_FILL, HAND_PIECE_MAX_UNIT, 1.0)
		return
	PieceDraw.draw_shape(self, piece, area, HUD_ENEMY_BLOCK, HudSkin.TEXT_OUTLINE, HAND_PIECE_MAX_UNIT)


# HP ratio 0..1 of index 0 (player) or 1 (boss).
func _hp_ratio(index: int) -> float:
	if index == 0:
		return clampf(_state.player_hp / maxf(_state.player_max_hp, 1.0), 0.0, 1.0)
	return clampf(_state.enemy_hp / maxf(_state.enemy_max_hp, 1.0), 0.0, 1.0)


# Story 046 Part B: advances the two damage trails by [param real_step] (real seconds). A drop restarts the
# shrink from where the trail is drawn now to the new ratio over hud.hp_trail_sec (0 under reduce motion:
# art bible 7.6, the trail is instant); a heal moves the trail with the fill. Presentation only.
func _tick_hp_trail(real_step: float) -> void:
	if _state == null or _config == null:
		return
	for i: int in 2:
		var ratio: float = _hp_ratio(i)
		if _hp_trail_to[i] < 0.0 or ratio > _hp_trail_to[i]:
			_hp_trail_from[i] = ratio
			_hp_trail_to[i] = ratio
			_hp_trail_t[i] = 0.0
		elif ratio < _hp_trail_to[i]:
			_hp_trail_from[i] = _hp_trail_shown(i)
			_hp_trail_to[i] = ratio
			_hp_trail_t[i] = 0.0
		else:
			_hp_trail_t[i] += real_step
	_hp_trail_sec = 0.0 if SettingsStore.shared().get_reduce_motion() else _config.hud_hp_trail_sec


# The trail ratio drawn this frame for index [param index] (the fill ratio before the first tick).
func _hp_trail_shown(index: int) -> float:
	if _hp_trail_to[index] < 0.0:
		return _hp_ratio(index)
	return HudSkin.trail_ratio(_hp_trail_from[index], _hp_trail_to[index], _hp_trail_t[index], _hp_trail_sec)


# Ring around the player's feet: full right after a step, shrinks to nothing; hidden when ready.
func _draw_cooldown_ring(vp: Vector2) -> void:
	if _config == null or not _config.hud_step_rings:
		return  # 2026-10-31: no step-cooldown ring (combat.json hud.step_rings)
	var fraction: float = _mover.get_cooldown_fraction()
	if fraction <= 0.0:
		return
	var c: Vector2 = _unit_center(vp, CombatState.Side.PLAYER)
	var radius: float = ScreenLayout.cell_size(_grid, vp).y * (MARKER_RADIUS_RATIO + RING_GAP_RATIO)
	draw_arc(c, radius, 0.0, TAU, RING_POINTS, RING_BACK_COLOR, RING_WIDTH)
	draw_arc(c, radius, -PI * 0.5, -PI * 0.5 + TAU * fraction, RING_POINTS, RING_COLOR, RING_WIDTH)


# Ring around the boss's body: full right after its step, shrinks to nothing; hidden when ready.
func _draw_boss_ring(vp: Vector2) -> void:
	if _state.is_enemy_dead():
		return
	var c: Vector2 = _unit_center(vp, CombatState.Side.ENEMY)
	var radius: float = ScreenLayout.cell_size(_grid, vp).y * BOSS_RING_RADIUS_RATIO
	# Story 025: rooted by its own swing = one solid steel-blue ring (the same ring, a different state).
	if _boss.is_step_locked():
		# Playtest 2026-11-01: the floor layer draws the F10 foot-lock seal instead; the ring is only the fallback.
		if not get_floor_vfx().has_pack("root_seal"):
			draw_arc(c, radius, 0.0, TAU, RING_POINTS, BOSS_RING_LOCKED_COLOR, BOSS_RING_LOCKED_WIDTH)
		return
	if _config == null or not _config.hud_step_rings:
		return  # 2026-10-31: no step-cooldown ring (combat.json hud.step_rings); the rooted ring above stays
	var fraction: float = _boss.get_mover().get_cooldown_fraction()
	if fraction <= 0.0:
		return
	draw_arc(c, radius, 0.0, TAU, RING_POINTS, RING_BACK_COLOR, BOSS_RING_WIDTH)
	draw_arc(c, radius, -PI * 0.5, -PI * 0.5 + TAU * fraction, RING_POINTS, HP_COLOR, BOSS_RING_WIDTH)


## Story 047 Part D: match seconds this frame's [param delta] advances the simulation by, the same step
## _process feeds StatusEffects.tick (capped at max_tick_sec, scaled by the skill menu / Focus): 0 while
## freeze_time or at Focus's full stop. Pure; the art layers run their status clocks on it.
## Story 048: the battle's floor-VFX state (pack index, effects clock, one-shot queue); never null.
func get_floor_vfx() -> FloorVfx:
	if _floor_vfx == null:
		_floor_vfx = FloorVfx.new()
	return _floor_vfx


# Story 048: the one-shots of a resolved cut by [param side]: F6 hit_impact (overlay) on the target's cell, F7
# miss_dust (floor) on every cell of a miss. ADR-0001 A1: every cell's effect waits for the card's delivery to reach
# it (SkillDelivery.arrival_times); the impact per cell is the delivery's impact (CastVfx.impact_pack); the travel
# cells only get the travel's visual. Presentation only: the damage was already applied to the mask by CutEffects.
## [param delivery_override] (Phase 0): the delivery to draw with when the caster is not a card (a pattern enemy's
## skill carries its own); {} = the card's delivery by skill id.
func _play_cut_vfx(side: int, feedback: Dictionary, delivery_override: Dictionary = {}) -> void:
	var vfx: FloorVfx = get_floor_vfx()
	var target_side: int = CombatState.Side.ENEMY if side == CombatState.Side.PLAYER else CombatState.Side.PLAYER
	var cells: Array = feedback.get("cells", [])
	var state: CombatState = get_state()
	var caster: Vector2i = Vector2i(-1, -1)
	if state != null:
		caster = state.cast_origin(side)
	var delivery: Dictionary = delivery_override if not delivery_override.is_empty() else delivery_for(str(feedback.get("skill_id", "")))
	var delays: Dictionary = SkillDelivery.arrival_times(delivery, cells, caster, delivery_timing()) if not cells.is_empty() else {}
	_play_delivery_travel(delivery, cells, caster, target_side)
	# Task 5 item 5 (design/quick-specs/mot-o-mot-hieu-ung-2026-11-01.md): a locked cell (cracking / hole) takes nothing,
	# so it shows no impact either. Presentation only: the damage path (CutEffects over unlocked_cells) is untouched.
	var shown: Array = unlocked_for_vfx(cells)
	if not cells.is_empty():
		# Task 5 item 4: the boss's casts are recorded too (its travel squares / impacts drawn on the cells it hits).
		var rec: Dictionary = {"cells": shown, "delivery": delivery, "caster": caster, "arrive": delays,
			"start": vfx.elapsed(), "hit": bool(feedback.get("hit", false)), "skill_id": str(feedback.get("skill_id", ""))}
		# V4 feel pass: the player's landing hit stops the match for a beat and shakes the board, at its first arrival.
		if side == CombatState.Side.PLAYER and bool(feedback.get("hit", false)) and float(feedback.get("damage", 0.0)) > 0.0:
			var first: float = INF
			for c: Vector2i in delays:
				first = minf(first, float(delays[c]))
			_hit_stop_at = vfx.elapsed() + (first if first < INF else 0.0)
		if side == CombatState.Side.PLAYER:
			_cast_travel = rec
		else:
			_boss_travel = rec
	if not bool(feedback.get("hit", false)):
		for cell: Vector2i in shown:
			vfx.play("miss_dust", cell, target_side, float(delays.get(cell, 0.0)))
		return
	if state == null:
		return
	# P2.2b: a hit on a multi-cell boss lands on the covered footprint cell nearest its centre (CombatState.enemy_hit_cell).
	var target: Vector2i = state.enemy_hit_cell(cells) if side == CombatState.Side.PLAYER else state.player_cell
	var impact: String = CastVfx.impact_pack(str(delivery.get("impact", "")))
	var peak: float = 0.0
	if _hero_wave(side, delivery) and not cells.is_empty():
		peak = _play_hero_wave(cells, caster, delays, impact, shown, str(delivery.get("impact", "")))
	elif not impact.is_empty():
		# 2026-11-04: an impact with a floor mark (impact_marks, the Mage's embers) leaves it on each hit cell too.
		var mark: String = CastVfx.impact_mark(str(delivery.get("impact", "")))
		for cell: Vector2i in shown:
			if not (impact == "hit_impact" and cell == target):
				vfx.play(impact, cell, target_side, float(delays.get(cell, 0.0)))
				if not mark.is_empty():
					vfx.play(mark, cell, target_side, float(delays.get(cell, 0.0)))
	var wait: float = float(delays.get(target, 0.0))
	# The hit flash / HIT marker show when the delivery reaches the target's cell, not at the resolve.
	if float(feedback.get("damage", 0.0)) > 0.0:
		_hit_delay[target_side] = wait + peak
	feedback["wait"] = wait
	if is_cell_locked(target):
		return
	if cells.has(target):
		vfx.play("hit_impact", target, target_side, wait)
	else:
		vfx.play("hit_impact", feedback.get("cell", target), target_side)


## Seconds a surge cell's code-drawn crack / shockwave stays (CastFloorFx.crack_rects / shock_rects).
const SURGE_FX_SEC: float = 0.6


# Skill v2 (Trảm Địa, docs/skill-v2/02-vfx-concepts.md §8.1): one AUTHORITATIVE impact event of a scheduled cast fired
# (SwingArbiter.impact_resolved). Its ground burst plays now, on its own cell: the landing burst (big steel) on the
# `burst` cell, the small steel burst on every other cell, each with its stamp; the crack from the cell the surge came
# from and the shockwave are code-drawn (get_surge_fx). Damage feedback (HIT marker, hit_impact) only when the event
# damaged the target. Presentation only: the arbiter already applied the event.
func _on_impact_resolved(side: int, event: Dictionary, hit: bool) -> void:
	if side != CombatState.Side.PLAYER:
		return
	# Hỏa Lôi: mark the seals first (an event whose every cell fizzled has no cells left, and still shows its fizzle).
	if str(event.get("kind", "")) == CastResolver.KIND_FUSE:
		_mark_fuse(event, hit)
	var cells: Array = event.get("cells", []) as Array
	if cells.is_empty():
		return
	var cell: Vector2i = cells[0]
	var kind: String = str(event.get("kind", "hit"))
	var vfx: FloorVfx = get_floor_vfx()
	_impact_log.append({"index": int(event.get("index", 0)), "cell": cell, "kind": kind, "hit": hit, "at": event.get("at", 0.0)})
	var hero_id: String = str(UnitLayer.unit_ids_for(match_params).get(CombatState.Side.PLAYER, ""))
	var skill_id: String = str(event.get("skill_id", ""))
	var ctx: Dictionary = event.get("context", {}) as Dictionary
	var delivery: Dictionary = ctx.get("delivery", {}) as Dictionary
	if delivery.is_empty():
		delivery = delivery_for(skill_id)
	# 2026-11-08: the card's own cast overrides (Trảm Địa: the eruption pack + its floor mark on the burst cell).
	var entry: Dictionary = CastVfx.entry_for(hero_id, str(delivery.get("impact", "")), skill_id)
	var sky: bool = kind == CastResolver.KIND_DROP or kind == CastResolver.KIND_DROP_FINAL
	# V1 impacts for scheduled casts: every resolved event (except a Hỏa Lôi fuse, drawn by FuseFx) is a record the
	# overlay draws like a resolved instant cut: its cells arrive now. A landing player hit also stops the match a beat.
	if kind != CastResolver.KIND_FUSE:
		var shown: Array = unlocked_for_vfx(cells)
		var arrive: Dictionary = {}
		for c: Vector2i in shown:
			arrive[c] = 0.0
		_event_impacts.append({"cells": shown, "delivery": delivery, "caster": _state.cast_origin(CombatState.Side.PLAYER) if _state != null else Vector2i(-1, -1),
			"arrive": arrive, "start": vfx.elapsed(), "hit": hit, "skill_id": skill_id, "kind": kind, "event": true})
		if hit and float(event.get("damage", 0.0)) > 0.0:
			_hit_stop_at = vfx.elapsed()
	# Hỏa Lôi: the sigils, blast and fizzle are FuseFx (floor + overlay), driven by this very event.
	if kind == CastResolver.KIND_FUSE:
		pass
	elif sky and not is_cell_locked(cell):
		# Ngàn Kiếm: the blade, its impact and shatter are SkyDropFx (overlay); only the floor stamp is a pack here.
		var stamp: String = str(entry.get("impact_mark" if kind == CastResolver.KIND_DROP_FINAL else "cell_mark", ""))
		if not stamp.is_empty():
			vfx.play(stamp, cell, CombatState.Side.ENEMY)
	elif not is_cell_locked(cell):
		var big: bool = kind == CastResolver.KIND_BURST
		var burst: String = str(entry.get("impact" if big else "cell_burst", ""))
		var mark: String = str(entry.get("impact_mark" if big else "cell_mark", ""))
		if not burst.is_empty():
			vfx.play(burst, cell, CombatState.Side.ENEMY)
		if not mark.is_empty():
			vfx.play(mark, cell, CombatState.Side.ENEMY)
		_surge_fx.append({"cell": cell, "from": event.get("from", CastResolver.NO_CELL), "kind": kind,
			"start": vfx.elapsed(), "hit": hit})
	if not hit:
		return
	var target: Vector2i = event.get("target_cell", cell)
	vfx.play("hit_impact", target, CombatState.Side.ENEMY)
	_hit_delay[CombatState.Side.ENEMY] = 0.0
	_feedback = {"cells": cells, "hit": true, "damage": float(event.get("damage", 0.0)), "cell": target,
		"time_left": FEEDBACK_SEC, "pin_bonus": false, "featured": false, "featured_mult": 1.0, "featured_effect": "",
		"skill_id": skill_id, "crit": bool(event.get("crit", false))}


# Skill v2 (Trảm Địa): keeps the player's scheduled events (cell, from, at on the arbiter clock) for the fronts.
func _on_cast_scheduled(side: int, cast: Dictionary) -> void:
	if side != CombatState.Side.PLAYER:
		return
	# Cast Commitment: the swing end IS the commit; the hero stays locked commit_lock_sec more.
	var lock: float = float(_skill_config.get_skill(str(cast.get("skill_id", ""))).get("commit_lock_sec", -1.0)) \
		if _skill_config != null else -1.0
	if lock >= 0.0 and _arbiter != null:
		_commit_lock_until = _arbiter.clock() + lock
		_commit_cast = int(cast.get("cast_id", -1))
	# Hỏa Lôi: a delayed card's armed cells become FuseFx records (same cells, same authoritative `at`).
	if _skill_config != null and str(_skill_config.get_skill(str(cast.get("skill_id", ""))).get("resolve", "")) 			== CastResolver.RESOLVE_DELAYED and _arbiter != null:
		_fuse_fx.append_array(FuseFx.records_from_cast(cast, _arbiter.clock()))
	# Ngàn Kiếm: a SKY_TO_TARGET card's drops become SkyDropFx records (same cells, same authoritative `at`); the
	# enemy's cells at the swing end only pick the visual hover (over_enemy), never a target.
	# 2026-11-11: only a card whose cast entry asks for the summoned blades (`summon_fx`, Ngàn Kiếm) gets SkyDropFx;
	# every other scheduled sky card (Thiên Thạch, Băng Vỡ, Đập Vỡ) draws its own ImpactFx / DeliveryFx instead.
	var hero_for_sky: String = str(UnitLayer.unit_ids_for(match_params).get(CombatState.Side.PLAYER, ""))
	if str(delivery_for(str(cast.get("skill_id", ""))).get("type", "")) == SkillDelivery.SKY_TO_TARGET \
			and bool(CastVfx.entry_for(hero_for_sky, "", str(cast.get("skill_id", ""))).get("summon_fx", false)):
		var enemy_cells: Array = _state.enemy_footprint_cells() if _state != null else []
		var recs: Array[Dictionary] = SkyDropFx.records_from_cast(cast, _arbiter.clock() if _arbiter != null else 0.0, enemy_cells)
		# on-tile summon card: the same re-timing the swing preview used, so the formed swords are the falling ones
		if not _sky_summon.is_empty() and str(_sky_summon.get("skill", "")) == str(cast.get("skill_id", "")):
			# the pull-down and the lock-on happen AT the commit (this tick: the swing end)
			var command_at: float = _arbiter.clock() if _arbiter != null else 0.0
			recs = SkyDropFx.summon_records(recs, float(_sky_summon["from"]), command_at)
			_summon_hold = {"skill": str(cast.get("skill_id", "")), "until": command_at,
				"cell": _state.player_cell if _state != null else Vector2i.ZERO}
		_sky_summon = {}
		_sky_plan.append_array(recs)
		return
	# batch 4 (Móc Kéo): the pull path (SwingArbiter `pull_path`) is telegraphed on the floor from the swing end until
	# the hook's first event lands, plus PULL_TELEGRAPH_TAIL_SEC
	var path: Array = cast.get("pull_path", []) as Array
	if not path.is_empty() and _arbiter != null:
		var first_at: float = INF
		for e: Dictionary in cast.get("events", []) as Array:
			first_at = minf(first_at, float(e["at"]))
		var sec: float = (maxf(first_at - _arbiter.clock(), 0.0) if first_at < INF else 0.0) + PULL_TELEGRAPH_TAIL_SEC
		_pull_telegraph = {"cells": path.duplicate(), "start": get_floor_vfx().elapsed(), "sec": sec}
	_surge_plan = []
	for e: Dictionary in cast.get("events", []) as Array:
		_surge_plan.append({"cell": (e["cells"] as Array)[0], "from": e.get("from", CastResolver.NO_CELL), "at": float(e["at"]),
			"kind": str(e.get("kind", ""))})


## Batch 4 (Móc Kéo): the pull path telegraph to draw now: {cells, t (seconds since the swing end)}; {} when none
## or it has run out (the record is dropped then).
func pull_telegraph_now() -> Dictionary:
	if _pull_telegraph.is_empty():
		return {}
	var t: float = get_floor_vfx().elapsed() - float(_pull_telegraph["start"])
	if t > float(_pull_telegraph["sec"]):
		_pull_telegraph = {}
		return {}
	return {"cells": _pull_telegraph["cells"], "t": t}


## Skill v2 (Ngàn Kiếm): the sky drops to draw now (SkyDropFx.drops_now on the arbiter clock; a dropped cast's
## pending blades vanish); finished records are pruned.
func get_sky_drops() -> Array[Dictionary]:
	if _arbiter == null:
		return []
	var now: float = _arbiter.clock()
	var preview: Array[Dictionary] = _sky_summon_preview(now)
	if not preview.is_empty():
		return preview
	if _sky_plan.is_empty():
		return []
	var keep: Array[Dictionary] = []
	for d: Dictionary in _sky_plan:
		if now < float(d["at"]) + SkyDropFx.end_after_impact():
			keep.append(d)
	_sky_plan = keep
	return SkyDropFx.drops_now(_sky_plan, now, _arbiter.has_cast)


# Skill v2 (Ngàn Kiếm on-tile summon, card_casts `summon_fx`): while the player's swing of such a card runs, its swords
# assemble on the target tiles from the cast clip's raise frame. The plan is the SAME resolver call the arbiter makes
# at the swing end (this swing's cells, cast context, locked cells now); `at` is predicted from the swing end. Visual
# only: the real schedule replaces it at the swing end with the same re-timing. [] when no such swing runs.
func _sky_summon_preview(now: float) -> Array[Dictionary]:
	if _cut_actor == null or not _cut_actor.is_swinging() or _skill_config == null:
		return []
	var id: String = _cut_actor.get_skill_id()
	if str(delivery_for(id).get("type", "")) != SkillDelivery.SKY_TO_TARGET:
		return []
	var hero_id: String = str(UnitLayer.unit_ids_for(match_params).get(CombatState.Side.PLAYER, ""))
	var entry: Dictionary = CastVfx.entry_for(hero_id, "", id)
	if not bool(entry.get("summon_fx", false)):
		return []
	var left: float = _cut_actor.get_time_left()
	var swing_from: float = now - (_cut_actor.get_duration() - left)
	var cells: Array[Vector2i] = _cut_actor.get_cells()
	if _sky_summon.is_empty() or str(_sky_summon.get("skill", "")) != id or _sky_summon.get("cells", []) != cells \
			or absf(float(_sky_summon.get("swing_from", -1.0)) - swing_from) > 0.001:
		var blocked: Array = []
		for c: Vector2i in cells:
			if is_cell_locked(c):
				blocked.append(c)
		var plan: Dictionary = CastResolver.plan(_skill_config.get_skill(id), cells, _cut_actor.get_cast_context(),
			delivery_timing(), blocked)
		var swing_end: float = now + left
		var events: Array = []
		for e: Variant in plan.get("events", []) as Array:
			var ev: Dictionary = (e as Dictionary).duplicate()
			ev["at"] = swing_end + float(ev.get("t", 0.0))
			events.append(ev)
		var from: float = swing_from + float(entry.get("summon_focus_from_sec", 0.0))
		var recs: Array[Dictionary] = SkyDropFx.records_from_cast({"events": events, "cast_id": -1, "skill_id": id}, swing_end,
			_state.enemy_footprint_cells() if _state != null else [])
		# Cast Commitment: the pull-down comes at the commit (the swing end); a card without a channel keeps the
		# visual command lead before its first stab.
		var command_at: float = swing_end if is_commitment_card(id) else SkyDropFx.summon_command_at(recs)
		_sky_summon = {"skill": id, "cells": cells, "swing_from": swing_from, "from": from, "command_at": command_at,
			"records": SkyDropFx.summon_records(recs, from, command_at)}
		_summon_hold = {"skill": id, "until": command_at, "cell": _state.player_cell if _state != null else Vector2i.ZERO}
	var shown: Array[Dictionary] = []
	for d: Dictionary in _sky_summon["records"] as Array:
		if now >= float(d["t0"]):
			shown.append(d)
	return shown


## Cast Commitment phases of the player's channel card (design/quick-specs/cast-commitment-ngan-kiem-2026-11-08.md).
const PHASE_NONE: String = ""
const PHASE_CHANNELING: String = "channeling"
const PHASE_COMMIT: String = "commit"
const PHASE_RESOLUTION: String = "resolution"


## True when [param skill_id] is a Cast Commitment card (cards.json commit_lock_sec >= 0; Ngàn Kiếm only today).
func is_commitment_card(skill_id: String) -> bool:
	return _skill_config != null and float(_skill_config.get_skill(skill_id).get("commit_lock_sec", -1.0)) >= 0.0


## The Cast Commitment phase now: CHANNELING while a channel card's swing runs; COMMIT from its swing end for
## commit_lock_sec; RESOLUTION while its committed events are still on the clock; "" otherwise (PLANNING is the
## existing cast stop: placing / the place window / the card menu).
func channel_phase() -> String:
	if _cut_actor != null and _cut_actor.is_swinging() and is_commitment_card(_cut_actor.get_skill_id()):
		return PHASE_CHANNELING
	if _arbiter == null:
		return PHASE_NONE
	if _commit_lock_until >= 0.0 and _arbiter.clock() < _commit_lock_until:
		return PHASE_COMMIT
	if _commit_cast >= 0 and _arbiter.has_cast(_commit_cast):
		return PHASE_RESOLUTION
	return PHASE_NONE


## True while the hero may not step because of a channel card: CHANNELING and the COMMIT lock. Only steps: Focus and
## Awakening are not blocked by it.
func is_cast_rooted() -> bool:
	var phase: String = channel_phase()
	return phase == PHASE_CHANNELING or phase == PHASE_COMMIT or is_cast_locked()


## Skill v2 cast profile "lock" (Hỏa Lôi): true while the hero's swing of a `cast_root: "lock"` card runs. The hero is
## rooted for the swing only: no Hủy, no commit lock, free again at the swing end.
func is_cast_locked() -> bool:
	return _cut_actor != null and _cut_actor.is_swinging() and _skill_config != null \
		and str(_skill_config.get_skill(_cut_actor.get_skill_id()).get("cast_root", "none")) == "lock"


## True during the COMMIT lock (the release gesture): no step, no pause, no cancel.
func is_commit_locked() -> bool:
	return channel_phase() == PHASE_COMMIT


## Seconds the current channel has run (0 when none).
func channel_elapsed() -> float:
	if channel_phase() != PHASE_CHANNELING:
		return 0.0
	return _cut_actor.get_duration() - _cut_actor.get_time_left()


## True when the Hủy button of the channel is shown (CHANNELING).
func is_channel_cancel_shown() -> bool:
	return channel_phase() == PHASE_CHANNELING


## True when a Hủy press would be taken now (CHANNELING, past the accidental-tap guard).
func can_cancel_channel() -> bool:
	return is_channel_cancel_shown() and channel_elapsed() >= CHANNEL_CANCEL_GUARD_SEC


## Hủy / Esc on a channel. CHANNELING past the guard: the cancel is queued and done after the next arbiter tick (so a
## commit in that very tick wins) -> true. Inside the guard: ignored -> false. COMMIT / RESOLUTION: refused with the
## "committed" feedback -> false. Otherwise false.
func request_channel_cancel() -> bool:
	var phase: String = channel_phase()
	if phase == PHASE_CHANNELING:
		if channel_elapsed() < CHANNEL_CANCEL_GUARD_SEC:
			return false
		_cancel_requested = true
		return true
	if phase == PHASE_COMMIT or phase == PHASE_RESOLUTION:
		_channel_flash = {"cells": _last_channel_cells(), "refused": true, "time_left": FEEDBACK_SEC}
	return false


# After the arbiter tick: a queued cancel stops the channel if it is still CHANNELING (policy "spent": the pieces were
# spent at the card choice and the cooldown started with the swing; both stay so). If the swing resolved (COMMIT) in
# this same tick, commit wins: the request is refused.
func _resolve_channel_cancel() -> void:
	if not _cancel_requested:
		return
	_cancel_requested = false
	if channel_phase() == PHASE_CHANNELING:
		var cells: Array[Vector2i] = _cut_actor.get_cells()
		# the summoned swords to disperse are this frame's preview, whether or not it has been drawn yet
		if _arbiter != null:
			_sky_summon_preview(_arbiter.clock())
		_cut_actor.cancel()
		_channel_flash = {"cells": cells, "refused": false, "time_left": FEEDBACK_SEC}
	else:
		_channel_flash = {"cells": _last_channel_cells(), "refused": true, "time_left": FEEDBACK_SEC}


func _last_channel_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for d: Dictionary in _sky_plan:
		if not cells.has(d["cell"]):
			cells.append(d["cell"])
	return cells


## Cast Commitment feedback to draw: {cells, refused, time_left}; {} when none.
func get_channel_flash() -> Dictionary:
	return _channel_flash


# The player's swing was cancelled (Hủy, a boss interrupt, a death): a channel's uncommitted swords disperse in place
# (no impact, no damage); the summon hold and any queued request end.
func _on_player_swing_cancelled(_cells: Array[Vector2i], skill_id: String) -> void:
	_cancel_requested = false
	if not _sky_summon.is_empty() and str(_sky_summon.get("skill", "")) == skill_id and _arbiter != null:
		var now: float = _arbiter.clock()
		for d: Dictionary in _sky_summon["records"] as Array:
			if now >= float(d["t0"]):
				_sky_plan.append(SkyDropFx.dispersed(d, now))
	_sky_summon = {}
	_summon_hold = {}


## True when a step is refused now: [method is_movement_locked] (Focus, placing, the card menu) or a Cast Commitment
## channel / commit lock ([method is_cast_rooted]).
func is_step_locked() -> bool:
	return is_movement_locked() or is_cast_rooted()


## Skill v2 (Ngàn Kiếm on-tile summon): the clock time until which the Knight's cast clip holds its summon pose (the
## command: the commit, i.e. the swing end, for a Cast Commitment card); -1 when no summon hold runs or it has passed.
## Visual only.
func summon_hold_until() -> float:
	if _summon_hold.is_empty() or _arbiter == null:
		return -1.0
	var until: float = float(_summon_hold["until"])
	return until if _arbiter.clock() < until else -1.0


## Skill v2 (Ngàn Kiếm on-tile summon): the card whose summon hold / pull-down the Knight is playing ("" otherwise); it
## outlives the swing by the clip's release and recovery so the clip does not switch mid-way.
func summon_skill() -> String:
	if _summon_hold.is_empty() or _arbiter == null:
		return ""
	return str(_summon_hold["skill"]) if _arbiter.clock() < float(_summon_hold["until"]) + 0.6 else ""


## Skill v2 (Ngàn Kiếm): the arbiter clock the sky drops are drawn on (0 without an arbiter).
func combat_clock() -> float:
	return _arbiter.clock() if _arbiter != null else 0.0


## Skill v2 V1: the player's resolved scheduled-cast events still drawn (see `_event_impacts`), each as a travel-shaped
## record with "rel" = seconds since it resolved; records older than their last arrival + [param tail] are dropped.
func event_impacts_now(tail: float = 0.3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _event_impacts.is_empty():
		return out
	var now: float = get_floor_vfx().elapsed()
	var keep: Array[Dictionary] = []
	for rec: Dictionary in _event_impacts:
		var rel: float = now - float(rec["start"])
		if rel > tail:
			continue
		keep.append(rec)
		var r: Dictionary = rec.duplicate()
		r["rel"] = rel
		r["swinging"] = false
		out.append(r)
	_event_impacts = keep
	return out


## V4 feel pass: the visual-only board offset of the hit shake now (CastVfx.hit_feel board_shake_px, flipping side
## every 0.03 s), Vector2i.ZERO at rest. BattleCanvas applies it like the Ngàn Kiếm finale shake.
func hit_shake_offset() -> Vector2i:
	if _hit_shake_left <= 0.0:
		return Vector2i.ZERO
	var px: int = int(CastVfx.hit_feel().get("board_shake_px", 0))
	return Vector2i(px if int(_hit_shake_left / 0.03) % 2 == 0 else -px, 0)


## V4 feel pass: true while the hit-stop holds the simulation.
func is_hit_stopped() -> bool:
	return _hit_stop_left > 0.0


## Skill v2 (Trảm Địa): the incoming steel fronts to draw now: [{from, to, f}] for every planned surge step whose source
## cell has fired and whose own event has not (f = fraction of the way on the ARBITER clock, so a front reaches its
## cell exactly when that cell's authoritative event fires). [] when no surge runs.
func get_surge_fronts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _surge_plan.is_empty() or _arbiter == null:
		return out
	var now: float = _arbiter.clock()
	var at_of: Dictionary = {}
	var last: float = 0.0
	for e: Dictionary in _surge_plan:
		at_of[e["cell"]] = float(e["at"])
		last = maxf(last, float(e["at"]))
	if now > last + 0.05:
		_surge_plan = []
		return out
	for e: Dictionary in _surge_plan:
		var from: Vector2i = e["from"]
		if from == CastResolver.NO_CELL or not at_of.has(from):
			continue
		var t0: float = float(at_of[from])
		var t1: float = float(e["at"])
		if now >= t0 and now < t1 and t1 > t0:
			out.append({"from": from, "to": e["cell"], "f": (now - t0) / (t1 - t0)})
	return out


## Skill v2 (Trảm Địa targeting preview): while the card menu is open with an AVAILABLE scheduled-surge card in the
## hand, the surge it would make on the placed cells right now: {card, events: CastResolver.surge_events (kind, step,
## from, t), blocked: the placed cells locked now}; {} otherwise. The same resolver the cast uses (locked cells now).
## Also while the player's swing of such a card winds up (the menu covers the board while open): then it is the
## swing's own cells and card, the telegraph of the surge to come.
func get_surge_preview() -> Dictionary:
	if _cut_flow == null or _skill_config == null or _state == null:
		return {}
	var cells: Array[Vector2i] = []
	var hand: Array[String] = []
	if _cut_flow.is_menu_open():
		cells = _cut_flow.get_cells()
		hand = _cut_flow.get_hand()
	elif _cut_actor != null and _cut_actor.is_swinging():
		cells = _cut_actor.get_cells()
		hand = [_cut_actor.get_skill_id()]
	if cells.is_empty():
		return {}
	var swinging: bool = not _cut_flow.is_menu_open()
	for id: String in hand:
		var skill: Dictionary = _skill_config.get_skill(id)
		if str(skill.get("resolve", "instant")) != CastResolver.RESOLVE_ARRIVAL:
			continue
		var delivery: Dictionary = skill.get("delivery", {}) as Dictionary
		if str(delivery.get("type", "")) != SkillDelivery.CASTER_TO_TARGET:
			continue
		if not swinging and not bool(SkillAvailability.check(_skill_config, _cooldowns, id, cells.size(), _cut_flow.card_level(id),
				_cut_flow.availability_context())["available"]):
			continue
		var blocked: Array = []
		for c: Vector2i in cells:
			if is_cell_locked(c):
				blocked.append(c)
		var ctx: Dictionary = {"delivery": delivery, "caster_cell": _state.player_cell}
		return {"card": id, "events": CastResolver.surge_events(skill, cells, ctx, delivery_timing(), blocked), "blocked": blocked}
	return {}


## Skill v2 (Trảm Địa): the surge cells to draw now: [{cell, from, kind, age (s), hit}], pruned past SURGE_FX_SEC.
func get_surge_fx() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _surge_fx.is_empty():
		return out
	var now: float = get_floor_vfx().elapsed()
	var keep: Array[Dictionary] = []
	for r: Dictionary in _surge_fx:
		var age: float = now - float(r["start"])
		if age <= SURGE_FX_SEC:
			keep.append(r)
			var d: Dictionary = r.duplicate()
			d["age"] = age
			out.append(d)
	_surge_fx = keep
	return out


## Skill v2: the player's scheduled impact events fired so far ({index, cell, kind, hit, at}), oldest first.
func get_impact_log() -> Array[Dictionary]:
	return _impact_log


## ADR-0001 A1: the normalized delivery of card [param skill_id] (SkillDelivery form); the fallback when unknown.
func delivery_for(skill_id: String) -> Dictionary:
	if _skill_config == null:
		return SkillDelivery.FALLBACK.duplicate(true)
	var d: Variant = _skill_config.get_skill(skill_id).get("delivery", null)
	return d as Dictionary if d is Dictionary else SkillDelivery.FALLBACK.duplicate(true)


## ADR-0001 A1: the delivery timing table (combat.json timing.delivery; built-in defaults without a config).
func delivery_timing() -> Dictionary:
	return _config.delivery_timing if _config != null else SkillDelivery.DEFAULT_TIMING


# The hero's cast pack draws a CASTER_TO_TARGET delivery with travel hero_pack (the sword wave, user 2026-11-01).
func _hero_wave(side: int, delivery: Dictionary) -> bool:
	return side == CombatState.Side.PLAYER and str(delivery.get("type", "")) == SkillDelivery.CASTER_TO_TARGET 		and str(delivery.get("travel", "")) == "hero_pack"


# The sword wave: the pack's landing impact on the first cell, the delivery's impact on every other cell as the spread
# reaches it, and the flood shards. Returns the blast peak the hit flash adds.
## [param impact_id] = the card's delivery impact (picks the hero's pack for it, CastVfx.entry_for); [param impact] is
## that impact's FloorVfx pack ("" when none).
func _play_hero_wave(cells: Array, caster: Vector2i, delays: Dictionary, impact: String, shown: Array, impact_id: String = "") -> float:
	var hero_id: String = str(UnitLayer.unit_ids_for(match_params).get(CombatState.Side.PLAYER, ""))
	var entry: Dictionary = CastVfx.entry_for(hero_id, impact_id)
	if entry.is_empty():
		return 0.0
	var first: Vector2i = SkillDelivery.nearest_cell(cells, caster)
	var t: Dictionary = delivery_timing().get(SkillDelivery.CASTER_TO_TARGET, {})
	var step: float = maxf(float(t.get("spread_step_sec", CastVfx.DEFAULT_FLOW_STEP_SEC)), 0.01)
	var plan: Dictionary = CastVfx.flow_plan(cells, first, step,
		float(entry.get("flow_tail_sec", CastVfx.DEFAULT_FLOW_TAIL_SEC)), float(t.get("first_hold_sec", 0.0)))
	_cast_flow = {"plan": plan, "start": get_floor_vfx().elapsed(), "pack": str(entry.get("id", ""))}
	var landing: String = str(entry.get("impact", ""))
	if not landing.is_empty() and shown.has(first):
		get_floor_vfx().play(landing, first, CombatState.Side.ENEMY)
	var burst: String = impact if not impact.is_empty() else str(entry.get("cell_burst", ""))
	if not burst.is_empty():
		for cell: Vector2i in shown:
			if cell != first:
				get_floor_vfx().play(burst, cell, CombatState.Side.ENEMY, float(delays.get(cell, 0.0)))
	# 2026-11-02 (tools/fx-pipeline): the squares left on the floor of every reached cell (floor layer, under the units).
	var first_mark: String = str(entry.get("impact_mark", ""))
	var cell_mark: String = str(entry.get("cell_mark", ""))
	for cell: Vector2i in shown:
		var mark: String = first_mark if cell == first else cell_mark
		if not mark.is_empty():
			get_floor_vfx().play(mark, cell, CombatState.Side.ENEMY, float(delays.get(cell, 0.0)))
	return CastVfx.blast_peak_sec(entry)


# The travel's visual on the floor cells it crosses outside the mask (animation only; no effect on them).
func _play_delivery_travel(delivery: Dictionary, cells: Array, caster: Vector2i, target_side: int) -> void:
	var pack: String = CastVfx.travel_pack(str(delivery.get("travel", "")), str(delivery.get("impact", "")))
	if pack.is_empty() or cells.is_empty():
		return
	var ground: bool = str(delivery.get("type", "")) == SkillDelivery.GROUND_PROPAGATION
	for cell: Vector2i in SkillDelivery.travel_cells(delivery, cells, caster):
		var at: float = SkillDelivery.ground_time(delivery, cells, caster, cell, delivery_timing()) if ground else 0.0
		get_floor_vfx().play(pack, cell, target_side, at)


## Task 5 item 5: true while [param cell] is locked (cracking or an open hole, StatusEffects.is_locked).
func is_cell_locked(cell: Vector2i) -> bool:
	return _status != null and _status.is_locked(cell)


## Task 5 item 5: [param cells] without the locked ones (the cells a cast's visuals may be drawn on), order kept.
func unlocked_for_vfx(cells: Array) -> Array:
	var out: Array = []
	for c: Vector2i in cells:
		if not is_cell_locked(c):
			out.append(c)
	return out


## Task 5 item 6: true once [param side]'s unit died by falling into a hole.
func died_by_fall(side: int) -> bool:
	return bool(_fell.get(side, false))


## ADR-0001 Task 5: [param side]'s cast travel to draw now (the player by default; Task 5 item 4: the boss too), timed on
## the resolve: {"rel" (seconds after the resolve; negative while the swing still runs), "cells" (the mask minus locked
## cells), "delivery", "caster", "arrive" (cell -> seconds after the resolve, SkillDelivery.arrival_times), "swinging",
## "hit" (after the resolve: the cut hit)}. While the side swings it is computed from its CutActor; after the resolve
## from the recorded cast until [param tail] s past the last arrival. {} when none.
func cast_travel_now(tail: float = 0.3, side: int = CombatState.Side.PLAYER) -> Dictionary:
	var state: CombatState = get_state()
	if state == null:
		return {}
	var boss: bool = side != CombatState.Side.PLAYER
	var actor: CutActor = get_cut_actor() if not boss else (_boss.get_actor() if _boss != null else null)
	var caster: Vector2i = state.cast_origin(CombatState.Side.ENEMY if boss else CombatState.Side.PLAYER)
	if actor != null and actor.is_swinging() and not actor.get_cells().is_empty():
		var cells: Array = []
		cells.assign(actor.get_cells())
		var delivery: Dictionary = delivery_for(actor.get_skill_id())
		return {"rel": -actor.get_time_left(), "cells": unlocked_for_vfx(cells), "delivery": delivery,
			"caster": caster, "swinging": true, "hit": false,
			"arrive": SkillDelivery.arrival_times(delivery, cells, caster, delivery_timing())}
	var rec: Dictionary = _boss_travel if boss else _cast_travel
	if rec.is_empty():
		return {}
	var rel: float = get_floor_vfx().elapsed() - float(rec["start"])
	var last: float = 0.0
	for c: Vector2i in rec["arrive"]:
		last = maxf(last, float(rec["arrive"][c]))
	if rel > last + tail:
		if boss:
			_boss_travel = {}
		else:
			_cast_travel = {}
		return {}
	var out: Dictionary = rec.duplicate()
	out["rel"] = rel
	out["swinging"] = false
	return out


# Hỏa Lôi: the fuse event of a cast fired: its records blast (every armed cell of the cast at once), a cell that was
# locked since the cast fizzles instead.
func _mark_fuse(event: Dictionary, hit: bool) -> void:
	var id: int = int(event.get("cast_id", -1))
	var gone: Array = event.get("fizzled_cells", []) as Array
	for rec: Dictionary in _fuse_fx:
		if int(rec["cast_id"]) != id:
			continue
		rec["fired"] = true
		rec["hit"] = hit
		rec["fizzled"] = gone.has(rec["cell"])


## Skill v2 Hỏa Lôi H2: the fire-seal records to draw now (FuseFx), after dropping the ones drawn out and the armed
## ones whose cast was cleared (caster death, match end: nothing fires, nothing shows).
func get_fuse_fx() -> Array[Dictionary]:
	if _arbiter == null:
		return _fuse_fx
	var now: float = _arbiter.clock()
	var keep: Array[Dictionary] = []
	for rec: Dictionary in _fuse_fx:
		if now >= FuseFx.end_time(rec):
			continue
		if not bool(rec["fired"]) and not _arbiter.has_cast(int(rec["cast_id"])):
			continue
		keep.append(rec)
	_fuse_fx = keep
	return _fuse_fx


## The stain flooding the last cut's area now: {"cells": CastVfx.flood_cells, "style": CastVfx.flood_style};
## {} when none is showing (user 2026-11-01: it explodes on the first cell, then one stain floods back over the area).
func get_cast_flood() -> Dictionary:
	if _cast_flow.is_empty():
		return {}
	var entry: Dictionary = CastVfx.pack_entry(str(_cast_flow["pack"]))
	var style: Dictionary = CastVfx.flood_style(entry)
	var step: float = CastVfx.flow_step_sec(entry)
	var plan: Dictionary = _cast_flow["plan"]
	var age: float = get_floor_vfx().elapsed() - float(_cast_flow["start"])
	if age > CastVfx.flood_end(plan, step, float(style["hold_sec"]), float(style["fade_sec"])):
		_cast_flow = {}
		return {}
	return {"cells": CastVfx.flood_cells(plan, age, step, float(style["hold_sec"]), float(style["fade_sec"])), "style": style}


## OSFE hit feel: seconds the hit flash of [param side] should wait (its own cell's blast delay plus the blast
## peak), then 0 again: the UnitLayer takes it once, on the damage it flashes for. 0 when no blast was played.
func take_hit_delay(side: int) -> float:
	var d: float = float(_hit_delay.get(side, 0.0))
	_hit_delay[side] = 0.0
	return d


func scaled_delta(delta: float) -> float:
	if freeze_time or _config == null or _hit_stop_left > 0.0:
		return 0.0
	return maxf(minf(delta, _config.max_tick_sec) * _sim_scale(), 0.0)
