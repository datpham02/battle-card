extends RefCounted
## Shared match harness and v5 player bot for the balance tools (tools/balance/deck_sim.gd,
## tools/balance/hit_probe.gd). Tool code only: the game never loads it and the test suite never runs it.
## See tools/balance/README.md for the flags and how to read the output.
##
## [method play_match] builds ONE match the way CombatView._ready does: CombatConfig (+ arena board via
## ArenaLibrary.grid_for_spec), CombatState, the player's UnitMover, FieldDrops with puzzle pieces
## (enable_pieces + place_start_pieces), the 3-slot piece bag (HoldSlots.create_piece_hand), Deck, CutFlow
## (card menu), FocusController, CastPlan (join up to max_pieces_per_cast), the featured shape
## (ArenaLibrary.featured_for_match), BossController with pieces (enable_pieces, rooted while swinging),
## StatusEffects, BossLearning, SwingArbiter (boss_defense, execute_ratio), TraitHost, the passive, the
## signature with its FormationMap and per-character cooldown_sec. It then runs CombatView._process's tick
## order headless: the loop advances REAL time by dt and the simulation by dt x scale (card menu or
## placing = cards.json menu_time_scale, Focus = focus_time_scale, else 1).
##
## The PLAYER is a bot ([method _bot_tick]): it walks onto pieces to fill the bag, dodges telegraphed
## boss swings with probability [code]bot.dodge[/code], places the best (piece, rotation, anchor) covering the
## boss's cell and its neighbours (wind-up fitted to the time the boss cannot move), may join a second
## piece during the card menu, counters when the boss starts a swing (the boss is rooted while it swings),
## gets Focus automatically when it starts placing (as the game does), picks the best card of the drawn
## hand and fires the signature when ready (rules below). Human time is modelled in REAL seconds:
## place_sec per drag, join_sec per joined piece, choose_sec per card pick.
## A driver object (hit_probe) may replace the bot: it gets probe_tick(core) every loop step.
##
## Story 027 zones: the match gets CombatView._wire_zones's wiring (seal blocker on both movers, each side's
## UnitMover.is_cell_blocked as the arbiter's leave-a-path test, CombatConfig.zone_numbers on the arbiter)
## and the boss never gets zone cards (SkillConfig.boss_card_order). Zone-card rule of the bot
## ([method _zone_choice]): in the card menu, with the cast cells already placed, it picks
## - a SEAL card when the boss has at most ZONE_SEAL_MAX_EXITS open exits (enemy-half neighbours it may
##   step into) and the cast covers all of them but one (at least one): the seal closes the escape cells
##   and the leave-a-path rule leaves at most one open;
## - else a THORNS card when the cast covers at least ZONE_THORN_MIN_COVER open exits (the boss's dodge
##   cells);
## - never when an available damage card in the hand would kill the boss, and never as the follow-up.
## After a zone forms the bot follows up at once (no gap, no strike wait, aimed at the boss) while the zone
## lasts, and its placement scores only OPEN neighbours of the boss (sealed ones 0, thorned ones half), so
## the follow-up covers the boss cell and the exit still open. On its own half it treats sealed cells as
## blocked and walks around thorns (dodges into them only when nothing else is free).
## --no-zone-cards drops the zone cards from the match decks (deck_sim also drops them from the reward pool).

const PLAYER: int = CombatState.Side.PLAYER
const ENEMY: int = CombatState.Side.ENEMY
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## Story 036: extra path cost (in steps) the bot gives a step INTO mire; it walks around mire unless the detour
## is longer than this many steps. A bot assumption, not game data.
const MIRE_STEP_EXTRA: float = 2.0
## Story 036: the player's step cooldown of this match, sim seconds since the last wind drift, and whether the
## arena has mire (cell count) / sand / wind (printed by deck_sim --region).
var _player_cd: float = 0.0
var _drift_since: float = 0.0
var _haz_mire: int = 0
var _haz_sand: bool = false
var _haz_wind: bool = false
## Story 039: vent lines of both halves (count), whether the arena crumbles, seconds the bot stands on one cell on
## a crumble arena before it steps off (a bot assumption: crumble_after_sec is 2.0, a move about every 1.5 s),
## the cell it stands on and since when (sim seconds), and when it last stood on each cell (to pick the stalest).
const CRUMBLE_LEAVE_SEC: float = 1.5
## Story 039: seconds a vent line has been warning before the bot notices it and leaves (a human reaction). The bot
## also leaves an erupting (burning) cell at once, so vent damage stays near 0 whatever this is (README, Story 039).
const VENT_REACT_SEC: float = 0.4
## The two bot numbers above as run values (flags --vent-react=S, --crumble-leave=S).
var vent_react_sec: float = VENT_REACT_SEC
var crumble_leave_sec: float = CRUMBLE_LEAVE_SEC
var _haz_vents: int = 0
var _haz_crumble: bool = false
var _haz_cfg: Dictionary = {}
var _stand_cell: Vector2i = Vector2i(-1, -1)
var _stand_since: float = 0.0
var _visit_t: Dictionary = {}
const SEED_MASK: int = 0x7fffffff
## Simulation seconds before a match counts as a timeout (lost).
const MATCH_TIMEOUT_SEC: float = 180.0
## Real-time guard (slow motion stretches real time; a stuck menu can never hang the tool).
const REAL_TIMEOUT_SEC: float = 3600.0
## The old (rune-era) bot's dodge chance; TD-006 has not re-anchored it on a playtest yet.
const LEGACY_DODGE_P: float = 0.85
## Bot model defaults. Each key is a CLI flag (see README): --dodge=, --gap=min,max, --aim=, --counter=,
## --place-sec=, --choose-sec=, --join-sec=, --join=, --hold=, --aware=, --aware-min=, --sig=off|ready|rules.
const DEFAULT_BOT: Dictionary = {
	"dodge": LEGACY_DODGE_P,  # chance to step out of a telegraphed boss swing aimed at the bot's cell
	"dodge_reaction": 0.2,  # sim seconds between the telegraph and the dodge step
	"gap_min": 0.6,  # sim seconds between the end of the bot's swing and its next placement, uniform
	"gap_max": 1.6,
	"aim": 0.9,  # chance a cast is aimed at the boss's cell (else at a random enemy cell)
	"counter": 0.5,  # chance to cast at once when the boss starts a swing (old RETARGET_P)
	"place_sec": 1.2,  # REAL seconds to drag and drop one piece
	"join_sec": 1.0,  # REAL seconds to drag the second piece of a join
	"choose_sec": 0.8,  # REAL seconds to tap a card
	"join": 1.0,  # chance to join a second piece when the planner says the union scores higher
	"hold": 1,  # placeable pieces held before a non-counter cast (2 = wait for a joinable pair; a full bag casts anyway)
	"wait_step": 0.8,  # strike: wait up to this long (sim) for the boss to step before casting anyway
	"strike_fresh": 0.15,  # a strike counts as fresh this soon after the boss's step
	"strike_margin": 0.05,
	"think_frac": 0.5,  # share of the boss's think interval counted as its dodge latency
	"aware": 0.0,  # chance a placement is chosen to light dark formation-map cells instead
	"aware_min": 3,  # smallest piece the formation-aware placement uses
	"sig": "rules",  # off | ready | rules (Story 021 timing rules, see _bot_signature)
	"sig_tram_min_cells": 3,
	"sig_tram_boss_hp": 0.4,
	"sig_th_min_burn": 15.0,
	"sig_th_min_cells": 2,
	"sig_th_hold": 6.0,
	"sig_thanh_an_min_stacks": 1,  # Story 037: Thanh An fires when the boss has this many Han stacks
}
## Placement score weights (planner): covering the target, each covered neighbour (escape cell), each
## cell, a featured two-piece union, Anh Bo small cut, per second of wind-up beyond the strike budget.
const SCORE_TARGET: float = 1000.0
const SCORE_NEIGHBOUR: float = 30.0
const SCORE_CELL: float = 2.0
const SCORE_FEATURED: float = 80.0
const SCORE_ANH_BO_SMALL: float = 50.0
const SCORE_OVER_BUDGET_PER_SEC: float = 40.0
## Singles kept as the first piece of a pair candidate.
const PAIR_SEEDS: int = 8
## Card value model (ported from the rune-era deck_sim).
const BURN_EXPECT: float = 0.6
const BURN_STACK_MULT: float = 2.0
const FROST_EXPECT: float = 0.8
const AVG_CELLS: float = 3.5
const PIN_FOLLOWUP: float = 1.0
const PIN_CELLS: int = 5

## Story 027 zone-card rule (see [method _zone_choice]): seal only when the boss has at most this many open
## exits; thorns only when the cast covers at least this many open exits; a cast started at most
## POST_SEAL_SEC after a seal formed counts as a post-seal cast (ps_res / ps_hits).
const ZONE_SEAL_MAX_EXITS: int = 3
const ZONE_THORN_MIN_COVER: int = 2
const POST_SEAL_SEC: float = 2.0
## Neighbour score share of a thorned neighbour (the boss avoids thorns but may cross them).
const THORN_NEIGHBOUR_SHARE: float = 0.5

enum Phase { IDLE, PLACING, MENU, MENU_WAIT }

## Bot parameters (DEFAULT_BOT plus CLI overrides).
var bot: Dictionary = DEFAULT_BOT.duplicate()
## In-memory data overrides (never written to disk): hp_mult, boss_hp_mult, think_mult, combo, step_mult,
## drop_mult, boss_drop_mult, root (-1 data / 0 off / 1 on), sig_cd {signature or character id -> sec},
## match_set {match key -> value}.
var ov: Dictionary = {
	"hp_mult": 1.0, "boss_hp_mult": 1.0, "think_mult": 1.0, "combo": -1.0, "step_mult": 1.0,
	"drop_mult": 1.0, "boss_drop_mult": 1.0, "root": -1, "sig_cd": {}, "match_set": {}, "passive_set": {}, "hp_ids": [], "hp_ids_mult": 1.0,
	"no_zone_cards": false, "card_set": {}, "relics": [], "relic_set": [],
}
## Story 032: relic ids the player owns in the NEXT match (deck_sim sets it per run from its run state;
## apply_args seeds it from --relics=). Instances, merged config overrides and the running cast's
## cast_info live below; see [method _setup_relics].
var relic_ids: Array[String] = []
## Story 037: `--progress=none|all` (default all). `none` = an empty save: [member locked] is
## AchievementsConfig.locked_content(ProgressState.new()); `all` = nothing locked (every sim before Story 037
## is unchanged). deck_sim's unlock-runs mode replaces [member locked] before each run from its ledger.
var progress_mode: String = "all"
## {kind: Array[String]} of the ids locked in the NEXT run (character, card, piece, relic, region), the
## RunSession.locked form. deck_sim filters its pools through it; sim_core filters the player's piece drops.
var locked: Dictionary = {}
## Story 037 bot rules: set when a player zone (seal / thorns) formed, cleared when Vay Bat fires or the zone follow-up ends.
var _zone_formed_pending: bool = false
## Story 033: the run modifiers' override table of the NEXT match (RunSession.run_modifier_overrides, the
## form RunController puts in match_params["run_modifiers"]); deck_sim sets it per match. Key in use:
## `step_cooldown` (event loi_the, {mul: 1.2}), folded onto the player's step cooldown as CombatView does.
var run_modifiers: Dictionary = {}
var relic_config: RelicConfig
## Story 034: presets of --piece-deck (README "Piece deck in the sim"). `base` = the start deck through
## PieceDeck.weights_for_match, the baseline the other two are compared with.
const PIECE_DECK_PRESETS: Dictionary = {
	"base": "", "small_out": "remove:mono,bar2,bar3", "big_out": "remove:plus5,u5,bar5",
}
## Story 034: the raw --piece-deck value ("" = flag absent: the player's drops use enable_pieces' default
## weights exactly as before the story). Resolved by [method _build_piece_deck] in [method load_configs].
var piece_deck_spec: String = ""
## The fixed PieceDeck state of the player for the whole run (no ink offers, no removals in play).
var piece_deck_state: Dictionary = {}
var piece_deck_cfg: PieceDeckConfig
## The raw --piece-weight-set value ("" = flag absent: pieces.json weights untouched). `id:value` sets the
## base drop weight of shape id in EVERY weights map (default, ch1..ch3); `id:xF` multiplies it. Applied
## in memory to [member piece_lib] by [method _apply_piece_weight_set], so the player's and the boss's
## drops (both read piece_lib) see it. README "Piece drop weights in the sim".
var piece_weight_spec: String = ""
## Warnings of --piece-weight-set (unknown or run_only ids, bad values), echoed by [method describe_piece_weight_set].
var piece_weight_warnings: Array[String] = []
## Story 041 (README "Story 041: odd blocks"): `--odd=on|off` ("" = flag absent = on, the data's chance;
## off = chance 0 on both sides) and `--odd-chance=X` (0..1 on both sides, -1 = absent). Both are applied in
## [method _setup] AFTER the match key `odd_blocks` (merged over the file block), as CombatView applies its
## DEV arg --odd-chance after it.
var odd_mode: String = ""
var odd_chance_override: float = -1.0
## Largest value `--aware-min` accepts: odd blocks reach 7 cells (OddBlockConfig size_max), above
## PieceLibrary.MAX_CELLS (5) of the library shapes.
const AWARE_MIN_MAX: int = 7
## Matches set up with a piece deck, and those where PieceDeck.weights_for_match fell back to the
## original weights (no deck shape fits the arena). Callers diff them around a batch.
var piece_deck_matches: int = 0
var piece_deck_fallbacks: int = 0
var _piece_fallback: bool = false
var relics: Array = []
var relic_merged: Dictionary = {}
var _cast_info: Dictionary = {}
var _max_join: int = 2
## Loop step in REAL seconds.
var dt: float = 0.05
## Probe knobs (hit_probe): keep the player at full HP, stop after this many sim seconds.
var invulnerable: bool = false
var time_limit_sec: float = MATCH_TIMEOUT_SEC
## Print an event log of the next match when true (cleared after it).
var trace: bool = false

# Shared read-only configs.
var cards: SkillConfig
var cut_config: CutConfig
var brain_data: Dictionary = {}
var drops_config: FieldDropsConfig
var hold_config: HoldSlotsConfig
var arena_library: ArenaLibrary
var piece_lib: PieceLibrary
var characters: CharacterConfig

# Per-match objects (public so a probe driver can read them).
var combat: CombatConfig
var grid: BoardGrid
var state: CombatState
var status: StatusEffects
var actor: CutActor
var mover: UnitMover
var drops: FieldDrops
var bag: HoldSlots
var deck: Deck
var cooldowns: SkillCooldowns
var focus: FocusController
var flow: CutFlow
var plan: CastPlan
var featured: Dictionary = {}
var boss: BossController
var arbiter: SwingArbiter
var learning: BossLearning
var trait_host: TraitHost
## Story 036: the match's TileHazards (mire, sand, wind); null outside a match.
var hazards: TileHazards = null
var passive: BasePassive = null
var signature: BaseSignature = null
var formation: FormationMap = null
var rng: RandomNumberGenerator
## Simulation time (t) and real time (real) of the running match.
var t: float = 0.0
var real: float = 0.0
## Match counters (see [method play_match] for the keys).
var ms: Dictionary = {}
## Time of the boss's last step (-1 none) and whether a boss swing started this loop step.
var boss_step_at: float = -1.0
var boss_swing_started_now: bool = false

var _driver: Object = null
var _boss_defense: float = 0.0
var _boss_think: float = 0.0
var _fuse: FuseCannonTrait = null
var _slam: SlamTrait = null
var _anchor_cache: Dictionary = {}
# Story 041: cells of the odd blocks spawned this match, [player, boss].
var _odd_cells: Array = [0, 0]
var _consuming: bool = false
# Signature state (mirrors CombatView).
var _sig_id: String = ""
var _sig_ready_flag: bool = false
var _sig_cd_sec: float = 0.0
var _sig_cd_left: float = 0.0
var _sig_was_active: bool = false
var _sig_ready_since: float = -1.0
var _sig_pending_extra: float = 0.0
# Bot state.
var _phase: int = Phase.IDLE
var _phase_left: float = 0.0
var _choose_left: float = 0.0
var _cast: Dictionary = {}
var _next_cast: float = 0.0
var _dodge_at: float = -1.0
var _force_aim: bool = false
var _wait_since: float = -1.0
# Story 027 zone state: follow-up after a zone (until sim time), last seal time, the running cast's start
# time and whether it is a zone card.
var _zone_follow_until: float = -1.0
var _last_seal_at: float = -1.0
var _cast_t: float = -1.0
var _cast_zone: bool = false


## Loads every shared config once.
func load_configs() -> void:
	cards = SkillConfig.load_from_file()
	_apply_card_set()
	cut_config = CutConfig.load_from_file()
	brain_data = JSON.parse_string(FileAccess.get_file_as_string(BossBrainConfig.DEFAULT_PATH)) as Dictionary
	drops_config = FieldDropsConfig.load_from_file()
	hold_config = HoldSlotsConfig.load_from_file()
	if hold_config == null:
		hold_config = HoldSlotsConfig.new()
	arena_library = ArenaLibrary.load_from_file()
	piece_lib = PieceLibrary.load_from_file()
	_apply_piece_weight_set()
	characters = CharacterConfig.load_from_file()
	_load_relic_config()
	_build_piece_deck()
	set_locked_from_progress(ProgressState.new() if progress_mode == "none" else null)


## Story 037: [member locked] for the next run. A [param progress] gives AchievementsConfig.locked_content of it;
## null = nothing locked.
func set_locked_from_progress(progress: ProgressState) -> void:
	locked = {} if progress == null else AchievementsConfig.shared().locked_content(progress)


## Story 037: the locked ids of [param kind] ([] when none), as a typed array (exclusion lists).
func locked_ids(kind: String) -> Array[String]:
	var out: Array[String] = []
	for v: Variant in locked.get(kind, []) as Array:
		out.append(str(v))
	return out


## Story 037: true when [param id] of [param kind] is locked in the next run.
func is_locked(kind: String, id: String) -> bool:
	return (locked.get(kind, []) as Array).has(id)


## Story 037 header text: "progress=none locked: card[...] ..." ("" with --progress=all).
func describe_progress() -> String:
	if progress_mode != "none":
		return ""
	var parts: Array[String] = []
	for kind: Variant in locked.keys():
		parts.append("%s[%s]" % [str(kind), ",".join(PackedStringArray(locked[kind] as Array))])
	return "progress=none (Story 037, empty save): locked %s" % (" ".join(PackedStringArray(parts)) if not parts.is_empty() else "nothing")


# Story 034: resolves --piece-deck (a preset or `remove:a,b|add:c,d`, sections applied in the order written)
# into piece_deck_state. remove -> PieceDeck.remove when PieceDeck.can_remove is ok, else one WARNING line
# naming the shape and the reason and the deck is kept; add -> PieceDeck.apply_ink once per listed id.
func _build_piece_deck() -> void:
	piece_deck_state = {}
	if piece_deck_spec.is_empty():
		return
	piece_deck_cfg = PieceDeckConfig.load_from_file()
	var st: Dictionary = PieceDeck.initial(piece_lib)
	var spec: String = str(PIECE_DECK_PRESETS.get(piece_deck_spec, piece_deck_spec))
	for section: String in spec.split("|", false):
		var op: String = section.get_slice(":", 0).strip_edges()
		if not section.contains(":") or (op != "remove" and op != "add"):
			print("--piece-deck: WARNING section '%s' ignored (remove:id,... or add:id,... or a preset %s)" % [section, str(PIECE_DECK_PRESETS.keys())])
			continue
		for raw: String in section.get_slice(":", 1).split(",", false):
			var id: String = raw.strip_edges()
			if id.is_empty():
				continue
			if op == "remove":
				var verdict: Dictionary = PieceDeck.can_remove(st, id, piece_lib, piece_deck_cfg)
				if not bool(verdict["ok"]):
					print("--piece-deck: WARNING remove '%s' refused: %s (min_shapes=%d, active now %d); the run continues with it" % [
						id, str(verdict["reason"]), piece_deck_cfg.min_shapes, PieceDeck.active_ids(st, piece_lib).size()])
					continue
				st = PieceDeck.remove(st, id, piece_lib, piece_deck_cfg)
			else:
				if not PieceDeck.can_ink(st, id, piece_lib, piece_deck_cfg):
					print("--piece-deck: WARNING add '%s' refused: %s" % [id,
						"unknown shape" if not piece_lib.has_shape(id) else "mult already at mult_max %.1f" % piece_deck_cfg.mult_max])
					continue
				st = PieceDeck.apply_ink(st, id, piece_lib, piece_deck_cfg)
	piece_deck_state = st


# --piece-weight-set: overrides piece_lib's base drop weights in memory, in every weights map. The tool
# writes PieceLibrary._weights directly (no public setter exists; src/ is not changed for a sim flag).
# `id:xF` multiplies the weight in each map that lists the id; `id:N` sets it in every map. Negative
# results clamp to 0 like PieceLibrary._read_weights. Unknown / run_only ids and bad values -> warning.
func _apply_piece_weight_set() -> void:
	piece_weight_warnings = []
	if piece_weight_spec.is_empty():
		return
	for kv: String in piece_weight_spec.split(",", false):
		var id: String = kv.get_slice(":", 0).strip_edges()
		var raw: String = kv.get_slice(":", 1).strip_edges() if kv.contains(":") else ""
		var mul: bool = raw.begins_with("x")
		var num: String = raw.trim_prefix("x")
		if not piece_lib.has_shape(id) or piece_lib.is_run_only(id) or not num.is_valid_float():
			piece_weight_warnings.append("'%s' ignored (%s)" % [kv.strip_edges(),
				"unknown shape" if not piece_lib.has_shape(id) else ("run_only shape has no table weight" if piece_lib.is_run_only(id) else "value must be N or xF")])
			continue
		for key: Variant in piece_lib._weights.keys():
			var map: Dictionary = piece_lib._weights[key] as Dictionary
			if mul:
				if map.has(id):
					map[id] = maxf(float(map[id]) * float(num), 0.0)
			else:
				map[id] = maxf(float(num), 0.0)


## --piece-weight-set: one header line echoing the override and the resulting weights per map, or "" when
## the flag is absent (the output is then unchanged).
func describe_piece_weight_set() -> String:
	if piece_weight_spec.is_empty():
		return ""
	var maps: Array[String] = []
	var keys: Array = piece_lib._weights.keys()
	keys.sort()
	for key: Variant in keys:
		var parts: Array[String] = []
		for kv: String in piece_weight_spec.split(",", false):
			var id: String = kv.get_slice(":", 0).strip_edges()
			if (piece_lib._weights[key] as Dictionary).has(id) and not parts.has("%s %s" % [id, str(snappedf(float((piece_lib._weights[key] as Dictionary)[id]), 0.001))]):
				parts.append("%s %s" % [id, str(snappedf(float((piece_lib._weights[key] as Dictionary)[id]), 0.001))])
		maps.append("%s{%s}" % [str(key), ", ".join(PackedStringArray(parts))])
	return "piece-weight-set: %s -> %s (in memory, player and boss drops)%s" % [piece_weight_spec, " ".join(PackedStringArray(maps)),
		"" if piece_weight_warnings.is_empty() else "; WARNING " + "; ".join(PackedStringArray(piece_weight_warnings))]


## Story 034: one header line with the --piece-deck spec, the resolved active shapes (x mult when not 1)
## and the removed ones; "" when the flag is absent (so the output without it is unchanged).
func describe_piece_deck() -> String:
	if piece_deck_spec.is_empty():
		return ""
	var spec: String = piece_deck_spec
	if PIECE_DECK_PRESETS.has(piece_deck_spec):
		spec = "%s (= %s)" % [piece_deck_spec, str(PIECE_DECK_PRESETS[piece_deck_spec]) if not str(PIECE_DECK_PRESETS[piece_deck_spec]).is_empty() else "start deck"]
	var active: Array[String] = PieceDeck.active_ids(piece_deck_state, piece_lib)
	var cells: Array[String] = []
	for id: String in active:
		var m: float = PieceDeck.mult_of(piece_deck_state, id)
		cells.append(id if is_equal_approx(m, 1.0) else "%s x%.1f" % [id, m])
	var removed: Array[String] = []
	for id: String in piece_lib.base_shape_ids():
		if not active.has(id):
			removed.append(id)
	return "piece deck (Story 034): spec=%s | active %d: %s | removed: %s | min_shapes=%d run_only_weight=%.1f | fixed for the whole run (no ink offers, no removals in play); boss drops keep the original weights" % [
		spec, active.size(), ", ".join(PackedStringArray(cells)), ", ".join(PackedStringArray(removed)) if not removed.is_empty() else "none",
		piece_deck_cfg.min_shapes, piece_deck_cfg.run_only_weight]


# Story 032: relics.json in memory with the --relic-set overrides (relics.json is never written); drops
# unknown --relics ids with a message and seeds relic_ids.
func _load_relic_config() -> void:
	relic_config = RelicConfig.load_from_file()
	for item: Variant in ov["relic_set"] as Array:
		var path: PackedStringArray = str(item[0]).split(".")
		var entry: Dictionary = {}
		for e: Dictionary in relic_config.relics:
			if str(e["id"]) == path[0]:
				entry = e
		if entry.is_empty() or path.size() < 2:
			print("--relic-set: '%s' unknown relic or no param, ignored" % str(item[0]))
			continue
		var node: Dictionary = entry["params"]
		for i: int in range(1, path.size() - 1):
			if typeof(node.get(path[i])) != TYPE_DICTIONARY:
				node[path[i]] = {}
			node = node[path[i]]
		node[path[path.size() - 1]] = item[1]
	relic_ids = []
	for id: Variant in ov["relics"] as Array:
		if relic_config.get_relic(str(id)).is_empty():
			print("--relics: '%s' is not a relics.json id, ignored" % str(id))
		elif not relic_ids.has(str(id)):
			relic_ids.append(str(id))
	ov["relics"] = relic_ids.duplicate()


## Story 027: the zone cards (SkillConfig.is_zone_card) in card_order order.
func zone_card_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in cards.card_order:
		if cards.is_zone_card(id):
			out.append(id)
	return out


# --card-set: writes id.key = value into the loaded SkillConfig in memory (cards.json is never touched).
# Must run before the configs are used; apply_args runs before load_configs in both tools.
func _apply_card_set() -> void:
	var sets: Dictionary = ov["card_set"]
	for id: Variant in sets.keys():
		var skill: Dictionary = cards.get_skill(str(id))
		if skill.is_empty():
			push_warning("sim_core: --card-set unknown card %s" % str(id))
			continue
		for k: Variant in (sets[id] as Dictionary).keys():
			var val: Variant = sets[id][k]
			skill[k] = int(val) if (str(k) == "min_cells" or str(k) == "thorn_fragile_stacks") else val


## Applies the shared flags (bot model and data overrides) and returns the arguments it did not know.
func apply_args(args: PackedStringArray) -> PackedStringArray:
	var rest: PackedStringArray = []
	for arg: String in args:
		var v: String = arg.get_slice("=", 1) if arg.contains("=") else ""
		if arg.begins_with("--dodge="):
			bot["dodge"] = clampf(float(v), 0.0, 1.0)
		elif arg.begins_with("--gap="):
			bot["gap_min"] = maxf(float(v.get_slice(",", 0)), 0.0)
			bot["gap_max"] = maxf(float(v.get_slice(",", 1)) if v.contains(",") else float(bot["gap_min"]), float(bot["gap_min"]))
		elif arg.begins_with("--aim="):
			bot["aim"] = clampf(float(v), 0.0, 1.0)
		elif arg.begins_with("--counter="):
			bot["counter"] = clampf(float(v), 0.0, 1.0)
		elif arg.begins_with("--place-sec="):
			bot["place_sec"] = maxf(float(v), 0.0)
		elif arg.begins_with("--choose-sec="):
			bot["choose_sec"] = maxf(float(v), 0.0)
		elif arg.begins_with("--join-sec="):
			bot["join_sec"] = maxf(float(v), 0.0)
		elif arg.begins_with("--join="):
			bot["join"] = clampf(float(v), 0.0, 1.0)
		elif arg.begins_with("--hold="):
			bot["hold"] = clampi(int(v), 1, HoldSlots.MAX_SLOTS)
		elif arg.begins_with("--aware="):
			bot["aware"] = clampf(float(v), 0.0, 1.0)
		elif arg.begins_with("--aware-min="):
			# Story 041: up to the largest odd block (7 cells), not PieceLibrary.MAX_CELLS (5).
			bot["aware_min"] = clampi(int(v), 1, AWARE_MIN_MAX)
		elif arg.begins_with("--sig="):
			bot["sig"] = v if v in ["off", "ready", "rules"] else "rules"
		elif arg.begins_with("--odd="):
			# Story 041: on = the data's odd block chance (default), off = chance 0 on both sides.
			odd_mode = "off" if v.strip_edges() == "off" else "on"
		elif arg.begins_with("--odd-chance="):
			odd_chance_override = clampf(float(v), 0.0, 1.0)
		elif arg.begins_with("--vent-react="):
			vent_react_sec = maxf(float(v), 0.0)
		elif arg.begins_with("--crumble-leave="):
			crumble_leave_sec = maxf(float(v), 0.0)
		elif arg.begins_with("--dt="):
			dt = maxf(float(v), 0.005)
		elif arg.begins_with("--hp-mult="):
			ov["hp_mult"] = maxf(float(v), 0.05)
		elif arg.begins_with("--boss-hp-mult="):
			ov["boss_hp_mult"] = maxf(float(v), 0.05)
		elif arg.begins_with("--think-mult="):
			ov["think_mult"] = maxf(float(v), 0.05)
		elif arg.begins_with("--combo="):
			ov["combo"] = clampf(float(v), 0.0, 1.0)
		elif arg.begins_with("--step-mult="):
			ov["step_mult"] = maxf(float(v), 0.05)
		elif arg.begins_with("--drop-mult="):
			ov["drop_mult"] = maxf(float(v), 0.05)
		elif arg.begins_with("--boss-drop-mult="):
			ov["boss_drop_mult"] = maxf(float(v), 0.05)
		elif arg.begins_with("--root="):
			ov["root"] = 1 if v == "on" else (0 if v == "off" else -1)
		elif arg.begins_with("--sig-cd="):
			for kv: String in v.split(","):
				if kv.contains(":"):
					(ov["sig_cd"] as Dictionary)[kv.get_slice(":", 0).strip_edges()] = maxf(float(kv.get_slice(":", 1)), 0.0)
		elif arg.begins_with("--hp-ids="):
			for id: String in v.split(","):
				(ov["hp_ids"] as Array).append(id.strip_edges())
		elif arg.begins_with("--hp-ids-mult="):
			ov["hp_ids_mult"] = maxf(float(v), 0.05)
		elif arg.begins_with("--passive-set="):
			for kv: String in v.split(","):
				if kv.contains(":"):
					(ov["passive_set"] as Dictionary)[kv.get_slice(":", 0).strip_edges()] = float(kv.get_slice(":", 1))
		elif arg == "--no-zone-cards":
			ov["no_zone_cards"] = true
		elif arg.begins_with("--card-set="):
			# id.key:value,... e.g. --card-set=ket_gioi.cooldown_sec:8,tran_gai.min_cells:4
			for kv: String in v.split(","):
				if kv.contains(":") and kv.get_slice(":", 0).contains("."):
					var path: String = kv.get_slice(":", 0).strip_edges()
					var cid: String = path.get_slice(".", 0)
					if not (ov["card_set"] as Dictionary).has(cid):
						(ov["card_set"] as Dictionary)[cid] = {}
					var raw2: String = kv.get_slice(":", 1).strip_edges()
					(ov["card_set"] as Dictionary)[cid][path.get_slice(".", 1)] = float(raw2) if raw2.is_valid_float() else raw2
		elif arg.begins_with("--relics="):
			# Story 032: the player owns these relics in every match (deck_sim: from the start of the run).
			for id: String in v.split(","):
				if not id.strip_edges().is_empty():
					(ov["relics"] as Array).append(id.strip_edges())
		elif arg.begins_with("--relic-set="):
			# Story 032: id.param:value or id.param.field:value in memory, e.g. an_don.mult:1.6,la_ban.formation_fade.mul:1.2
			for kv: String in v.split(","):
				if kv.contains(":") and kv.get_slice(":", 0).contains("."):
					var raw3: String = kv.get_slice(":", 1).strip_edges()
					(ov["relic_set"] as Array).append([kv.get_slice(":", 0).strip_edges(), float(raw3) if raw3.is_valid_float() else raw3])
		elif arg.begins_with("--progress="):
			# Story 037: none = empty save (locked content stays out of every pool), all = nothing locked.
			progress_mode = v.strip_edges() if v.strip_edges() in ["none", "all"] else "all"
		elif arg.begins_with("--piece-deck="):
			# Story 034: preset (base, small_out, big_out) or remove:mono,bar2|add:y5,square.
			piece_deck_spec = arg.trim_prefix("--piece-deck=").strip_edges()
		elif arg.begins_with("--piece-weight-set="):
			# Base drop weights in memory, every chapter map: mono:x0.5,bar2:x0.5 (multiply) or bar5:2 (set).
			piece_weight_spec = arg.trim_prefix("--piece-weight-set=").strip_edges()
		elif arg.begins_with("--match-set="):
			for kv: String in v.split(","):
				if kv.contains(":"):
					var raw: String = kv.get_slice(":", 1).strip_edges()
					(ov["match_set"] as Dictionary)[kv.get_slice(":", 0).strip_edges()] = float(raw) if raw.is_valid_float() else raw
		else:
			rest.append(arg)
	return rest


## One line naming every bot parameter and every active override (for the output header).
func describe() -> String:
	var parts: Array[String] = []
	parts.append("dodge=%.2f%s" % [float(bot["dodge"]), " (TD-006 legacy default, not re-anchored)" if is_equal_approx(float(bot["dodge"]), LEGACY_DODGE_P) else " (override)"])
	parts.append("gap=%.2f-%.2fs aim=%.2f counter=%.2f place=%.2fs join=%.2f/%.2fs hold=%d choose=%.2fs aware=%.2f sig=%s dt=%.3f" % [
		float(bot["gap_min"]), float(bot["gap_max"]), float(bot["aim"]), float(bot["counter"]), float(bot["place_sec"]),
		float(bot["join"]), float(bot["join_sec"]), int(bot["hold"]), float(bot["choose_sec"]), float(bot["aware"]), str(bot["sig"]), dt])
	var o: Array[String] = []
	for k: String in ["hp_mult", "boss_hp_mult", "think_mult", "step_mult", "drop_mult", "boss_drop_mult"]:
		if float(ov[k]) != 1.0:
			o.append("%s=%.2f" % [k, float(ov[k])])
	if float(ov["combo"]) >= 0.0:
		o.append("combo=%.2f" % float(ov["combo"]))
	if int(ov["root"]) >= 0:
		o.append("root=%s" % ("on" if int(ov["root"]) == 1 else "off"))
	if not (ov["sig_cd"] as Dictionary).is_empty():
		o.append("sig_cd=%s" % str(ov["sig_cd"]))
	if not (ov["match_set"] as Dictionary).is_empty():
		o.append("match_set=%s" % str(ov["match_set"]))
	if not (ov["hp_ids"] as Array).is_empty():
		o.append("hp_ids=%s x%.2f" % [",".join(PackedStringArray(ov["hp_ids"])), float(ov["hp_ids_mult"])])
	if not (ov["passive_set"] as Dictionary).is_empty():
		o.append("passive_set=%s" % str(ov["passive_set"]))
	if bool(ov["no_zone_cards"]):
		o.append("no_zone_cards")
	if not (ov["card_set"] as Dictionary).is_empty():
		o.append("card_set=%s" % str(ov["card_set"]))
	if not is_equal_approx(vent_react_sec, VENT_REACT_SEC):
		o.append("vent_react=%.2fs" % vent_react_sec)
	if not is_equal_approx(crumble_leave_sec, CRUMBLE_LEAVE_SEC):
		o.append("crumble_leave=%.2fs" % crumble_leave_sec)
	if not (ov["relics"] as Array).is_empty():
		o.append("relics=%s" % ",".join(PackedStringArray(ov["relics"])))
	if not (ov["relic_set"] as Array).is_empty():
		o.append("relic_set=%s" % str(ov["relic_set"]))
	return "bot: %s | overrides: %s | %s" % [" ".join(parts), ", ".join(o) if not o.is_empty() else "none", describe_odd()]


## Story 041: `odd=on chance=0.25 (data)` / `odd=on chance=1.00 (--odd-chance)` / `odd=off` (flag or chance 0)
## plus the size rule of the file block. A chapter match key `odd_blocks` can still change one match.
func describe_odd() -> String:
	if odd_mode == "off":
		return "odd=off (--odd=off: chance 0 on both sides)"
	var cfg: OddBlockConfig = drops_config.odd if drops_config != null and drops_config.odd != null else null
	var chance: float = odd_chance_override if odd_chance_override >= 0.0 else (cfg.chance if cfg != null else 0.0)
	if chance <= 0.0:
		return "odd=off (chance 0%s)" % (" from --odd-chance" if odd_chance_override >= 0.0 else " in data")
	var rule: String = ""
	if cfg != null:
		rule = " sizes %d..%d max=clamp(cells/%d+%d, %d, %d) weights=%s tries=%d" % [cfg.min_cells, cfg.size_max,
			cfg.size_divisor, cfg.size_add, cfg.size_min, cfg.size_max, str(cfg.size_weights), cfg.max_tries]
	return "odd=on chance=%.2f (%s)%s" % [chance, "--odd-chance" if odd_chance_override >= 0.0 else "data", rule]


# Story 041: the odd block tuning of one side's drops config: the match key `odd_blocks` merged over the file
# block (CombatView._apply_odd_overrides), then --odd=off / --odd-chance=X.
func _apply_odd_overrides(cfg: FieldDropsConfig, m: Dictionary) -> void:
	if cfg.odd == null:
		cfg.odd = OddBlockConfig.new()
	var raw: Variant = m.get("odd_blocks", null)
	if raw is Dictionary:
		cfg.odd = cfg.odd.with_overrides(raw as Dictionary)
	if odd_mode == "off":
		cfg.odd.chance = 0.0
	elif odd_chance_override >= 0.0:
		cfg.odd.chance = odd_chance_override


## Copy of [param character] with the hp_mult / sig_cd / passive_set overrides applied.
func prepare_character(character: Dictionary) -> Dictionary:
	var c: Dictionary = character.duplicate(true)
	c["max_hp"] = maxf(float(c.get("max_hp", 100.0)), 1.0) * float(ov["hp_mult"])
	var passive: Variant = c.get("passive")
	if typeof(passive) == TYPE_DICTIONARY and typeof((passive as Dictionary).get("params")) == TYPE_DICTIONARY:
		var params: Dictionary = (passive as Dictionary)["params"]
		for k: Variant in (ov["passive_set"] as Dictionary).keys():
			if params.has(k):
				params[k] = ov["passive_set"][k]
	var spec: Variant = c.get("signature")
	if typeof(spec) == TYPE_DICTIONARY:
		var cds: Dictionary = ov["sig_cd"]
		for key: String in [str((spec as Dictionary).get("id", "")), str(c.get("id", ""))]:
			if cds.has(key):
				(spec as Dictionary)["cooldown_sec"] = float(cds[key])
	return c


## Copy of match dictionary [param m] with the match-level overrides applied.
func prepare_match(m: Dictionary) -> Dictionary:
	var out: Dictionary = m.duplicate(true)
	var sets: Dictionary = ov["match_set"]
	for k: Variant in sets.keys():
		out[k] = sets[k]
	if float(ov["think_mult"]) != 1.0:
		out["boss_think_interval_sec"] = float(out.get("boss_think_interval_sec", 0.3)) * float(ov["think_mult"])
		out["boss_reaction_sec"] = float(out.get("boss_reaction_sec", 0.35)) * float(ov["think_mult"])
	if float(ov["combo"]) >= 0.0:
		out["combo_chance"] = float(ov["combo"])
	if float(ov["step_mult"]) != 1.0 and not out.has("boss_step_cooldown_sec"):
		out["boss_step_cooldown_mult"] = float(out.get("boss_step_cooldown_mult", 1.0)) * float(ov["step_mult"])
	if float(ov["boss_hp_mult"]) != 1.0 and out.has("boss_max_hp"):
		out["boss_max_hp"] = float(out["boss_max_hp"]) * float(ov["boss_hp_mult"])
	if (ov["hp_ids"] as Array).has(str(out.get("id", ""))) and out.has("boss_max_hp"):
		out["boss_max_hp"] = float(out["boss_max_hp"]) * float(ov["hp_ids_mult"])
	return out


# ================================================================ one match


## Plays one match. [param m] = a RunConfig match dictionary (+ chapter_id), [param character] from
## [method prepare_character], [param deck_entries] = [{id, level}], [param start_hp] < 0 = full.
## [param driver] null = the bot plays; else driver.probe_tick(core) is called every loop step.
## Returns {won, timeout, sec, real_sec, hp_end, passive_heal, casts, resolved, hits, dealt, taken, bstarts, bswings,
## bhits (boss swing + fuse/slam hits), shits (boss swing hits only), bdmg (boss swing damage), interrupts, counters, sig_acts, sig_dmg, sig_first, focus_uses, joins, featured, cells}.
func play_match(m: Dictionary, character: Dictionary, deck_entries: Array, start_hp: float, match_seed: int,
		p_rng: RandomNumberGenerator, driver: Object = null) -> Dictionary:
	_driver = driver
	rng = p_rng
	if bool(ov["no_zone_cards"]):
		var kept: Array = []
		for e: Variant in deck_entries:
			if not cards.is_zone_card(str((e as Dictionary).get("id", ""))):
				kept.append(e)
		deck_entries = kept
	_setup(m, character, deck_entries, start_hp, match_seed)
	var timeout: bool = false
	while true:
		if state.is_player_dead() or state.is_enemy_dead():
			break
		if t >= time_limit_sec or real >= REAL_TIMEOUT_SEC:
			timeout = true
			break
		if _driver != null and _driver.has_method("probe_done") and bool(_driver.call("probe_done", self)):
			break
		_loop_step()
	var won: bool = state.is_enemy_dead() and not state.is_player_dead()
	var heal: float = maxf(passive.on_match_won(), 0.0) if (won and passive != null) else 0.0
	var out: Dictionary = ms.duplicate()
	out["won"] = won
	out["timeout"] = timeout
	out["sec"] = t
	out["real_sec"] = real
	out["hp_end"] = state.player_hp
	# Story 035: boss HP left as a share of its max (0 when killed), read by deck_sim --fate for the final match.
	out["boss_hp_end_ratio"] = maxf(state.enemy_hp, 0.0) / maxf(state.enemy_max_hp, 1.0)
	out["passive_heal"] = heal
	# Story 035: the boss_phases phase (1-based) the match ended in, 0 without that trait (read before teardown).
	var phases_trait: BossTrait = trait_host.get_trait(RunConfig.BOSS_PHASES_TRAIT_ID) if trait_host != null else null
	out["boss_phase"] = (phases_trait as BossPhasesTrait).get_phase() if phases_trait is BossPhasesTrait else 0
	# Story 039: TileHazards.stats() {pushes, vent_ticks, fall_damage_total} when the model has it (a cross-check of
	# the sim's own vent_hp / fall_hp / pushed counters) and 1 when the boss's rebirth was used up.
	out["haz_stats"] = (hazards.call("stats") as Dictionary) if hazards != null and hazards.has_method("stats") else {}
	var rebirth: BossTrait = trait_host.get_trait("rebirth") if trait_host != null else null
	# Story 041: odd block counters of both sides (FieldDrops getters; cells from point_spawned): odd spawns, all
	# piece spawns (start pieces included), failed generations that fell back to a classic piece, odd cells, and
	# whether odd blocks could drop on that half at all (the size rule allows no size on a small half).
	var bdrops: FieldDrops = boss.get_drops()
	out["odd_p"] = drops.get_odd_spawned()
	out["drops_p"] = drops.get_total_spawned()
	out["odd_fb_p"] = drops.get_odd_fallbacks()
	out["odd_cells_p"] = int(_odd_cells[0])
	out["odd_on_p"] = 1 if drops.is_odd_enabled() else 0
	out["odd_b"] = bdrops.get_odd_spawned()
	out["drops_b"] = bdrops.get_total_spawned()
	out["odd_fb_b"] = bdrops.get_odd_fallbacks()
	out["odd_cells_b"] = int(_odd_cells[1])
	out["odd_on_b"] = 1 if bdrops.is_odd_enabled() else 0
	out["rebirth_used"] = 1 if (rebirth != null and rebirth.has_method("lives_left") and int(rebirth.call("lives_left")) <= 0) else 0
	_teardown()
	trace = false
	return out


func _setup(m: Dictionary, character: Dictionary, deck_entries: Array, start_hp: float, match_seed: int) -> void:
	combat = CombatConfig.load_from_file()
	if combat == null:
		combat = CombatConfig.new()
	var arena: Variant = m.get("arena")
	if typeof(arena) == TYPE_DICTIONARY and not (arena as Dictionary).is_empty():
		var g: BoardGrid = ArenaLibrary.grid_for_spec(arena as Dictionary, arena_library, int(m.get("arena_seed", 0)))
		if g != null:
			combat.use_grid(g)
	grid = combat.grid
	_anchor_cache = {}
	_relic_config_overrides()
	var boss_max_hp: float = maxf(float(m.get("boss_max_hp", combat.enemy_max_hp)), 1.0)
	var player_max_hp: float = maxf(float(character.get("max_hp", combat.player_max_hp)), 1.0)
	state = CombatState.new(grid, player_max_hp, boss_max_hp, combat.player_start_cell, combat.enemy_start_cell)
	if start_hp >= 0.0:
		state.set_player_hp(start_hp)
	var base_cd: float = combat.step_cooldown_for(grid)
	var step_mult: float = float(character.get("step_cooldown_mult", 1.0))
	var player_cd: float = base_cd * (step_mult if step_mult > 0.0 else 1.0)
	# Story 033: mirrors CombatView._ready (run modifiers on top of the character's step multiplier).
	player_cd = RelicRegistry.apply_override(player_cd, run_modifiers, "step_cooldown")
	_player_cd = player_cd
	mover = UnitMover.new(state, PLAYER, player_cd)
	var chapter_id: String = str(m.get("chapter_id", ""))
	var player_drops_config: FieldDropsConfig = drops_config.copy()
	player_drops_config.piece_spawn_interval_sec *= float(ov["drop_mult"])
	_apply_drop_overrides(player_drops_config)
	# Story 038 (Kiep 4): the PLAYER's piece drop interval x the match key `player_drop_interval_mult`, after the relic overrides
	# exactly as CombatView does; absent / 1.0 = untouched, so a sim without a Kiep level is unchanged.
	var kiep_drop_mult: float = maxf(float(m.get("player_drop_interval_mult", 1.0)), 0.01)
	if not is_equal_approx(kiep_drop_mult, 1.0):
		player_drops_config.piece_spawn_interval_sec *= kiep_drop_mult
	var boss_drops_config: FieldDropsConfig = drops_config.copy()
	# Story 041: both sides get the same odd block tuning (match key, then the --odd / --odd-chance flags).
	_apply_odd_overrides(player_drops_config, m)
	_apply_odd_overrides(boss_drops_config, m)
	var boss_drop_mult: float = maxf(float(m.get("boss_drop_interval_mult", 1.0)), 0.01) * float(ov["boss_drop_mult"])
	boss_drops_config.spawn_interval_sec *= boss_drop_mult
	boss_drops_config.piece_spawn_interval_sec *= boss_drop_mult
	drops = FieldDrops.new(player_drops_config, grid.player_cells(), match_seed)
	_piece_fallback = false
	var locked_pieces: Array[String] = locked_ids("piece")
	if piece_deck_spec.is_empty() and locked_pieces.is_empty():
		drops.enable_pieces(piece_lib, chapter_id, grid, match_seed)
	elif piece_deck_spec.is_empty():
		# Story 037: a locked shape is not drawable for the player (the boss keeps the library weights below).
		var open_weights: Dictionary = {}
		for pid: String in piece_lib.base_shape_ids():
			if not locked_pieces.has(pid):
				open_weights[pid] = piece_lib.weight(pid, chapter_id)
		drops.enable_pieces(piece_lib, chapter_id, grid, match_seed, true, open_weights)
	else:
		# Story 034: the player's drops follow the run's piece deck (CombatView._setup); the boss call below is untouched.
		var wm: Dictionary = PieceDeck.weights_for_match(piece_deck_state, piece_lib, chapter_id, grid, piece_deck_cfg)
		_piece_fallback = bool(wm["fallback"])
		piece_deck_matches += 1
		if _piece_fallback:
			piece_deck_fallbacks += 1
		var deck_weights: Dictionary = (wm["weights"] as Dictionary).duplicate()
		for pid: String in locked_pieces:
			deck_weights.erase(pid)
		drops.enable_pieces(piece_lib, chapter_id, grid, match_seed, true, deck_weights)
	drops.place_start_pieces(state.player_cell)
	# Story 041: odd block sizes per side (the shares come from the FieldDrops counters in play_match).
	_odd_cells = [0, 0]
	drops.point_spawned.connect(_on_odd_point_spawned.bind(PLAYER))
	var slots: int = hold_config.piece_slot_count
	if relic_merged.has("hold_slots"):
		slots = maxi(roundi(_relic_value(float(slots), "hold_slots")), 1)
	bag = HoldSlots.create_piece_hand(slots)
	bag.slot_cleared.connect(_on_bag_slot_cleared)
	_max_join = maxi(combat.max_pieces_per_cast, RelicRegistry.max_join_pieces(relics))
	plan = CastPlan.new().init(_max_join, combat.max_cast_cells)
	featured = arena_library.featured_for_match(m, grid)
	state.cell_changed.connect(_on_cell_changed)
	cooldowns = SkillCooldowns.new()
	deck = Deck.from_array(deck_entries, match_seed)
	focus = FocusController.new(cards)
	if character.has("focus_max_sec"):
		focus.set_max_sec_override(float(character["focus_max_sec"]))
	if relic_merged.has("focus_sec"):
		focus.set_max_sec_override(maxf(_relic_value(focus.get_max_sec(), "focus_sec"), 0.0))
	actor = CutActor.new(cut_config, PLAYER)
	flow = CutFlow.new(cards, cooldowns)
	flow.level_of = Callable(self, "card_level")
	flow.skill_chosen.connect(_on_skill_chosen)
	var brain_config: BossBrainConfig = BossBrainConfig.from_dictionary(brain_data)
	_apply_brain_params(brain_config, m, base_cd)
	boss = BossController.new(state, grid, cut_config, cards, brain_config, boss_drops_config, hold_config, match_seed + 1)
	boss.enable_pieces(piece_lib, chapter_id, match_seed + 2, combat.max_pieces_per_cast)
	boss.get_drops().point_spawned.connect(_on_odd_point_spawned.bind(ENEMY))
	boss.set_player_step_cooldown(player_cd)
	boss.get_brain().cards = _boss_card_ids(m)
	boss.get_actor().duration_mult = maxf(float(m.get("swing_speed_mult", 1.0)), 0.01)
	status = StatusEffects.new()
	combat.configure_status(status)
	mover.set_status(status)
	boss.set_status(status)
	learning = BossLearning.new(brain_config.learning)
	boss.set_learning(learning)
	boss.get_actor().swing_started.connect(_on_boss_swing_started)
	boss.get_actor().swing_cancelled.connect(_on_boss_swing_cancelled)
	arbiter = SwingArbiter.new(state, grid, actor, boss.get_actor(), cut_config, cards, status)
	arbiter.boss_defense = maxf(float(m.get("boss_defense", 0.0)), 0.0)
	arbiter.execute_ratio = combat.execute_ratio
	_boss_defense = arbiter.boss_defense
	# boss_min_runes is set through set() so this tool keeps parsing if Story 026 removes the property.
	var brain: BossBrain = boss.get_brain()
	if "min_runes" in brain:
		brain.set("min_runes", maxi(int(m.get("boss_min_runes", 0)), 0))
	_wire_zones()
	_setup_hazards(m, match_seed)
	status.thorn_entered.connect(_on_thorn_entered)
	status.frost_burst.connect(_on_frost_burst)
	status.zone_applied.connect(_on_zone_applied)
	arbiter.swing_resolved.connect(_on_swing_resolved)
	arbiter.swing_interrupted.connect(_on_swing_interrupted)
	actor.swing_resolved.connect(_on_player_swing_done)
	actor.swing_cancelled.connect(_on_player_swing_done)
	var ctx: Dictionary = {
		"state": state, "grid": grid, "player_drops": drops, "boss_drops": boss.get_drops(),
		"boss": boss, "status": status, "arbiter": arbiter, "hold_getter": Callable(self, "get_bag"), "player_mover": mover,
		"skill_config": cards, "cut_config": cut_config,
		"hazards": hazards,
	}
	var traits: Variant = m.get("traits", [])
	trait_host = TraitHost.new(ctx, (traits as Array) if typeof(traits) == TYPE_ARRAY else [], match_seed)
	trait_host.on_match_start()
	_fuse = trait_host.get_trait("fuse_cannon") as FuseCannonTrait
	if _fuse != null:
		_fuse.blast_fired.connect(_on_blast_fired)
	_slam = trait_host.get_trait("slam") as SlamTrait
	if _slam != null:
		_slam.slam_landed.connect(_on_slam_landed)
	_setup_passive(character)
	_setup_signature(character)
	_setup_relics()
	t = 0.0
	real = 0.0
	boss_step_at = -1.0
	_boss_think = brain_config.think_interval_sec
	_phase = Phase.IDLE
	_cast = {}
	_dodge_at = -1.0
	_force_aim = false
	_wait_since = -1.0
	_zone_follow_until = -1.0
	_stand_cell = state.player_cell
	_stand_since = 0.0
	_visit_t = {}
	_last_seal_at = -1.0
	_zone_formed_pending = false
	_cast_t = -1.0
	_cast_zone = false
	_next_cast = rng.randf_range(float(bot["gap_min"]), float(bot["gap_max"]))
	ms = {
		"casts": 0, "resolved": 0, "hits": 0, "dealt": 0.0, "taken": 0.0, "bstarts": 0, "bswings": 0, "bhits": 0, "shits": 0, "bdmg": 0.0,
		"interrupts": 0, "counters": 0, "sig_acts": 0, "sig_dmg": 0.0, "sig_first": -1.0, "focus_uses": 0,
		"joins": 0, "featured": 0, "cells": 0,
		# Story 033: curse cards dealt into the card menu, and the HP their draw_damage took.
		"curse_draws": 0, "curse_dmg": 0.0,
		# Story 027: zone casts, seals / thorns that formed and their cells, boss / player thorn entries and
		# damage, hit counts of non-zone casts started <= POST_SEAL_SEC after a seal (ps_) and of the others (o_).
		"zone_casts": 0, "seals": 0, "seal_cells": 0, "thorns": 0, "thorn_cells": 0, "bthorn": 0, "bthorn_dmg": 0.0,
		"pthorn": 0, "pthorn_dmg": 0.0, "ps_res": 0, "ps_hits": 0, "o_res": 0, "o_hits": 0,
		# Story 032: relic `triggered` signals by relic id.
		"relic_trig": {},
		# Story 034: player casts resolved / hit by cast size (cells), interrupts the player SUFFERED (the
		# boss broke the player's swing; "interrupts" counts the ones the player landed), deck fallback (0/1).
		"size_res": {}, "size_hits": {}, "interrupted": 0, "piece_fallback": 1 if _piece_fallback else 0,
		# Story 036: player / boss mire entries and the HP mire took (the player's is also in "taken"), field
		# pieces buried by sand and drifted by the wind (player / boss half), sand cells filled on the player's half.
		"mire_in": 0, "mire_dmg": 0.0, "bmire_in": 0, "bmire_dmg": 0.0, "buried": 0, "bburied": 0,
		"drifted": 0, "bdrifted": 0, "sand_cells": 0,
		# Story 039: HP the player lost standing in an erupting vent / to a cell falling under it, times the
		# player / boss was pushed off a falling cell, vents that erupted, cells that fell, boss HP healed by burn_eater.
		"vent_hp": 0.0, "fall_hp": 0.0, "pushed": 0, "bpushed": 0, "vent_erupts": 0, "cell_falls": 0, "boss_heal": 0.0,
		# Story 037: Han bursts that fired on the boss (CombatView match stat `frost_bursts`).
		"frost_bursts": 0,
	}
	_tr("match start %s boss_hp=%.0f player_hp=%.0f player=%s boss=%s player_cd=%.2f featured=%s" % [
		str(m.get("id", "")), boss_max_hp, state.player_hp, str(state.player_cell), str(state.enemy_cell), player_cd, str(not featured.is_empty())])


func _teardown() -> void:
	for r: Variant in relics:
		(r as BaseRelic).teardown()
	relics = []
	relic_merged = {}
	if trait_host != null:
		trait_host.teardown_all()
	if passive != null:
		passive.teardown()
	if signature != null:
		signature.teardown()
	signature = null
	formation = null
	passive = null
	trait_host = null
	_fuse = null
	_slam = null
	_driver = null
	# Break the TileHazards <-> mover closure cycle (extra_blocked_fn holds the movers) so matches do not leak.
	if hazards != null:
		hazards.extra_blocked_fn = Callable()
	hazards = null


# Mirrors CombatView._apply_brain_params (+ the --root override).
func _apply_brain_params(bc: BossBrainConfig, m: Dictionary, base_cd: float) -> void:
	if m.has("boss_step_cooldown_sec"):
		bc.step_cooldown_sec = maxf(float(m["boss_step_cooldown_sec"]), 0.0)
	elif m.has("boss_step_cooldown_mult"):
		bc.step_cooldown_sec = maxf(base_cd * float(m["boss_step_cooldown_mult"]), 0.0)
	bc.think_interval_sec = maxf(float(m.get("boss_think_interval_sec", bc.think_interval_sec)), 0.0)
	bc.reaction_sec = maxf(float(m.get("boss_reaction_sec", bc.reaction_sec)), 0.0)
	if m.has("boss_root_while_swinging"):
		bc.root_while_swinging = bool(m["boss_root_while_swinging"])
	if int(ov["root"]) >= 0:
		bc.root_while_swinging = int(ov["root"]) == 1
	var wanted: String = str(m.get("brain_set", ""))
	if not wanted.is_empty() and bc.has_set(wanted):
		bc.active_set = wanted
	if m.has("boss_reaction_sec"):
		bc.override_movement(bc.active_set, {"reaction_sec": bc.reaction_sec})
	if float(m.get("combo_chance", -1.0)) >= 0.0:
		bc.override_weight(bc.active_set, "combo_chance", float(m["combo_chance"]))
	if float(m.get("combo_gap_sec", -1.0)) >= 0.0:
		bc.override_weight(bc.active_set, "combo_gap_sec", float(m["combo_gap_sec"]))
	var movement_override: Variant = m.get("movement")
	if typeof(movement_override) == TYPE_DICTIONARY and not (movement_override as Dictionary).is_empty():
		bc.override_movement(bc.active_set, movement_override as Dictionary)


# Mirrors CombatView._wire_zones (Story 027): seals block stepping for both movers (OR-ed via add_blocker),
# the arbiter gets each side's blocked test (seal leave-a-path rule) and the zone numbers.
func _wire_zones() -> void:
	var st: StatusEffects = status
	var movers: Dictionary = {PLAYER: mover, ENEMY: boss.get_mover()}
	for side: int in movers:
		var mv: UnitMover = movers[side] as UnitMover
		var seal_side: int = side
		mv.add_blocker(func(cell: Vector2i) -> bool: return st.is_sealed(seal_side, cell))
		arbiter.blocked_cell_fns[side] = Callable(mv, "is_cell_blocked")
	arbiter.zone_numbers = combat.zone_numbers()


# Mirrors CombatView._boss_card_ids: zone cards are never the boss's (SkillConfig.boss_card_order).
func _boss_card_ids(m: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var raw: Variant = m.get("boss_cards", [])
	if typeof(raw) == TYPE_ARRAY:
		for id: Variant in raw as Array:
			if cards.has_skill(str(id)) and not cards.is_zone_card(str(id)) and not ids.has(str(id)):
				ids.append(str(id))
	if ids.is_empty():
		ids = cards.boss_card_order()
	return ids


func _setup_passive(character: Dictionary) -> void:
	passive = null
	var spec: Variant = character.get("passive")
	if typeof(spec) != TYPE_DICTIONARY:
		return
	var id: String = str((spec as Dictionary).get("id", ""))
	if id.is_empty() or not PassiveRegistry.has_id(id):
		return
	passive = PassiveRegistry.create(id)
	if passive == null:
		return
	var params: Variant = (spec as Dictionary).get("params", {})
	passive.setup({"state": state, "grid": grid, "boss": boss, "status": status, "skill_config": cards, "cut_config": cut_config,
		"heal_player": Callable(self, "_relic_heal_player")},
		(params as Dictionary) if typeof(params) == TYPE_DICTIONARY else {})
	actor.duration_modifier = Callable(passive, "modify_swing_duration")
	arbiter.player_damage_modifier = Callable(passive, "modify_damage")
	passive.on_match_start()


# Mirrors CombatView._setup_signature (FormationMap of the real enemy cells, cooldown_sec >= 0).
func _setup_signature(character: Dictionary) -> void:
	signature = null
	formation = null
	_sig_id = ""
	_sig_ready_flag = false
	_sig_cd_left = 0.0
	_sig_was_active = false
	_sig_ready_since = -1.0
	var spec: Variant = character.get("signature")
	if typeof(spec) != TYPE_DICTIONARY:
		return
	var dict: Dictionary = spec as Dictionary
	var id: String = str(dict.get("id", ""))
	if id.is_empty():
		return
	signature = SignatureRegistry.create(id)
	if signature == null:
		return
	var enemy_cells: Array[Vector2i] = grid.enemy_cells()
	formation = FormationMap.new().init(enemy_cells, maxf(_relic_value(combat.formation_fade_for(enemy_cells.size()), "formation_fade"), 0.0))
	var params: Variant = dict.get("params", {})
	signature.setup({"state": state, "grid": grid, "boss": boss, "status": status, "skill_config": cards,
		"cut_config": cut_config, "cooldowns": cooldowns, "formation": formation},
		(params as Dictionary) if typeof(params) == TYPE_DICTIONARY else {})
	_sig_id = id
	var cooldown: Variant = dict.get("cooldown_sec", 0.0)
	_sig_cd_sec = maxf(float(cooldown), 0.0) if (typeof(cooldown) == TYPE_FLOAT or typeof(cooldown) == TYPE_INT) else 0.0
	_sig_cd_sec = maxf(_relic_value(_sig_cd_sec, "signature_cooldown"), 0.0)
	arbiter.player_cells_modifier = Callable(signature, "modify_cells")
	arbiter.player_signature_modifier = Callable(self, "_sig_mod_wrap")
	mover.cooldown_scale = Callable(signature, "step_cooldown_scale")
	# Story 037: the zone / Ran / Han hooks of the signatures (the base returns the neutral value).
	arbiter.player_zone_sec_mult_fn = Callable(signature, "zone_sec_mult")
	status.fragile_mult_fn = Callable(signature, "fragile_mult_override")
	status.frost_burst_mult_fn = Callable(signature, "frost_burst_mult")


# ---------------------------------------------------------------- Story 032 relics (CombatView._setup_relics port)


# Value of config [param key] after the relics' merged overrides (RelicRegistry.apply_override).
func _relic_value(base_value: float, key: String) -> float:
	return RelicRegistry.apply_override(base_value, relic_merged, key) if not relic_merged.is_empty() else base_value


# Mirrors the first half of CombatView._setup_relics + _apply_status_overrides: instantiates relic_ids
# (RelicRegistry.instantiate with the --relic-set config), merges their config overrides and writes the
# status keys (burn_max_stacks, han_stacks -> frost_stacks_to_burst, han_damage -> frost_burst_damage) into
# this match's CombatConfig copy BEFORE configure_status. The other keys are applied where their object is
# built, as CombatView does: piece_* / start_pieces (_apply_drop_overrides), hold_slots (bag), focus_sec
# (FocusController), formation_fade (FormationMap), signature_cooldown (_sig_cd_sec); seal_sec / thorn_ran
# reach CutEffects through arbiter.player_zone_overrides (after the card's own value).
func _relic_config_overrides() -> void:
	relics = []
	relic_merged = {}
	for id: String in relic_ids:
		var r: BaseRelic = RelicRegistry.instantiate(id, relic_config)
		if r != null:
			relics.append(r)
	relic_merged = RelicRegistry.merge_overrides(relics)
	if relic_merged.is_empty():
		return
	combat.burn_max_stacks = maxi(roundi(_relic_value(float(combat.burn_max_stacks), "burn_max_stacks")), 1)
	combat.frost_stacks_to_burst = maxi(roundi(_relic_value(float(combat.frost_stacks_to_burst), "han_stacks")), 1)
	combat.frost_burst_damage = maxf(_relic_value(combat.frost_burst_damage, "han_damage"), 0.0)


# Mirrors CombatView._apply_drop_overrides (a non-positive result keeps the config value).
func _apply_drop_overrides(cfg: FieldDropsConfig) -> void:
	if relic_merged.is_empty():
		return
	var fresh: float = _relic_value(cfg.piece_freshness_sec, "piece_freshness_sec")
	if fresh > 0.0:
		cfg.piece_freshness_sec = fresh
	cfg.start_pieces = maxi(roundi(_relic_value(float(cfg.start_pieces), "start_pieces")), 0)
	var interval: float = _relic_value(cfg.piece_spawn_interval_sec, "piece_spawn_interval")
	if interval > 0.0:
		cfg.piece_spawn_interval_sec = interval


# Mirrors the second half of CombatView._setup_relics + _wire_relics: the real ctx (heal / hurt the
# player through CombatState, give a piece to the bag), arbiter.player_zone_overrides, the ONE damage
# point (arbiter.player_relic_modifier, right after the featured multiplier) and the ONE windup point
# (CutActor.cast_time_modifier); the triggered signals are counted.
func _setup_relics() -> void:
	_cast_info = {}
	arbiter.player_zone_overrides = relic_merged
	if relics.is_empty():
		return
	var ctx: Dictionary = {
		"heal_player": Callable(self, "_relic_heal_player"),
		"damage_player": Callable(self, "_relic_damage_player"),
		"give_piece": Callable(self, "_relic_give_piece"),
	}
	for r: Variant in relics:
		var relic: BaseRelic = r as BaseRelic
		relic.setup(ctx, relic.get_params())
		relic.triggered.connect(_on_relic_triggered)
		relic.on_match_start()
	arbiter.player_relic_modifier = Callable(self, "_relic_damage")
	actor.cast_time_modifier = Callable(self, "_relic_cast_time")


func _relic_damage(cells: int, damage: float) -> float:
	var info: Dictionary = _cast_info.duplicate()
	info["cells"] = cells
	return RelicRegistry.fold_damage(relics, info, damage, relic_config)


func _relic_cast_time(cells: int, sec: float) -> float:
	var info: Dictionary = _cast_info.duplicate()
	info["cells"] = cells
	return RelicRegistry.fold_cast_time(relics, info, sec)


func _relic_heal_player(amount: float) -> void:
	if amount > 0.0 and not state.is_player_dead():
		state.set_player_hp(state.player_hp + amount)


func _relic_damage_player(amount: float) -> void:
	state.damage_player(amount)


# phan_don's give_piece (CombatView._relic_give_piece): one piece into the first free bag slot.
func _relic_give_piece(shape: String) -> bool:
	if bag.is_full() or state.is_player_dead():
		return false
	var piece: Piece = piece_lib.make_piece(shape)
	if piece == null:
		return false
	var p := FieldPoint.new()
	p.label = piece.shape_id
	p.cell = state.player_cell
	p.piece = piece
	return bag.place_in_first_free(p) >= 0


func _on_relic_triggered(relic_id: String) -> void:
	var trig: Dictionary = ms["relic_trig"]
	trig[relic_id] = int(trig.get(relic_id, 0)) + 1


# cast_info (CombatView._make_cast_info): the plan's pieces, cells, joined, featured.
func _make_cast_info(skill_id: String, cells: int, joined: bool, featured_on: bool) -> Dictionary:
	var shapes: Array[String] = []
	for p: Piece in plan.pieces():
		shapes.append(p.shape_id)
	return {"pieces": shapes, "cells": cells, "joined": joined, "featured": featured_on, "card_id": skill_id, "hit": false}


## The player's piece bag (TraitHost hold_getter).
func get_bag() -> HoldSlots:
	return bag


## Level of card [param id] in the match deck (CutFlow.level_of).
func card_level(id: String) -> int:
	return maxi(deck.level_of(id), 1) if deck != null else 1


# ---------------------------------------------------------------- the loop (CombatView._process)


func _loop_step() -> void:
	real += dt
	boss_swing_started_now = false
	flow.tick_real(dt)
	_update_focus(dt)
	var step: float = dt * _sim_scale()
	if step > 0.0:
		_world_tick(step)
	if state.is_player_dead() or state.is_enemy_dead():
		return
	if _driver != null:
		_driver.call("probe_tick", self)
	else:
		_bot_tick(dt)


func _world_tick(step: float) -> void:
	t += step
	# Story 039: HP the player loses to burn ticks while standing in an erupting vent, boss HP a burn tick healed.
	var vent_here: bool = _haz_vents > 0 and bool(hazards.call("is_venting", PLAYER, state.player_cell))
	var php0: float = state.player_hp
	var bhp0: float = state.enemy_hp
	status.tick(step, state)
	if vent_here:
		var vent_lost: float = maxf(php0 - state.player_hp, 0.0)
		ms["vent_hp"] = float(ms["vent_hp"]) + vent_lost
		ms["taken"] = float(ms["taken"]) + vent_lost
	if state.enemy_hp > bhp0:
		ms["boss_heal"] = float(ms["boss_heal"]) + state.enemy_hp - bhp0
	_drift_since += step
	hazards.tick(step, state)
	_tick_signature(step)
	if passive != null:
		passive.tick(step)
	if formation != null:
		formation.tick(step)
	mover.tick(step)
	learning.tick(step, bag.is_full())
	var burning: Array[Vector2i] = status.burning_cells()
	drops.set_blocked_cells(_drop_blocked(burning, PLAYER))
	boss.get_drops().set_blocked_cells(_drop_blocked(burning, ENEMY))
	var boss_actor: CutActor = boss.get_actor()
	drops.set_danger_cells(boss_actor.get_cells() if boss_actor.is_swinging() else ([] as Array[Vector2i]))
	boss.get_drops().set_danger_cells(actor.get_cells() if actor.is_swinging() else ([] as Array[Vector2i]))
	drops.tick(step, state.player_cell, bag.get_occupied_count())
	cooldowns.tick(step)
	boss.tick(step, actor)
	arbiter.tick(step)
	bag.tick_rot(step)
	if not (state.is_player_dead() or state.is_enemy_dead()):
		trait_host.on_tick(step)
	if invulnerable and not state.is_player_dead():
		state.set_player_hp(state.player_max_hp)


# Mirrors CombatView._update_focus: the bot "selects" a slot exactly while it is PLACING.
func _update_focus(real_step: float) -> void:
	focus.tick_real(real_step)
	if state.is_player_dead() or state.is_enemy_dead():
		focus.end(FocusController.REASON_DEATH)
		return
	var selected: bool = _phase == Phase.PLACING
	if focus.is_active() and not selected:
		focus.end(FocusController.REASON_DESELECTED)
	elif selected and focus.is_ready() and not flow.is_menu_open():
		if focus.try_start():
			ms["focus_uses"] = int(ms["focus_uses"]) + 1


# Mirrors CombatView._sim_scale.
func _sim_scale() -> float:
	if flow.is_menu_open():
		return cards.menu_time_scale
	if focus.is_active():
		return focus.get_time_scale()
	if _phase == Phase.PLACING:
		return cards.menu_time_scale
	return 1.0


# ---------------------------------------------------------------- signature (CombatView port)


func _check_sig_ready() -> void:
	if signature == null or formation == null or _sig_ready_flag or signature.is_active():
		return
	if _sig_cd_left > 0.0 or not formation.is_complete():
		return
	_sig_ready_flag = true
	_sig_ready_since = t
	_tr("SIG ready")


func _end_sig_effect() -> void:
	_sig_was_active = false
	_sig_cd_left = _sig_cd_sec
	if _sig_cd_left <= 0.0:
		_check_sig_ready()


func _tick_signature(step: float) -> void:
	if signature == null:
		return
	if _sig_cd_left > 0.0:
		_sig_cd_left = maxf(_sig_cd_left - step, 0.0)
		if _sig_cd_left <= 0.0:
			_check_sig_ready()
	signature.tick(step)
	if _sig_was_active and not signature.is_active():
		_end_sig_effect()


## Arbiter hook around the signature's modify_damage (same result) that also records the signature's
## share of this hit (ported from the scratch sigbal probe): Tram = damage with multiplied cells minus damage
## with the real cells, Anh Bo = the multiplied part; capped at the boss HP left. Credited on resolve.
func _sig_mod_wrap(card_id: String, cells: int, damage: float, pinned: bool) -> float:
	var out: float = float(signature.modify_damage(card_id, cells, damage, pinned))
	var base: float = damage
	if signature is TramSignature and signature.is_active():
		var mult: float = signature.param_float("cell_mult", TramSignature.DEFAULT_CELL_MULT)
		var eff: int = int(roundf(float(cells) * maxf(mult, 0.0)))
		if eff > 0 and eff != cells:
			base = damage * float(cells) / float(eff)
	_sig_pending_extra = maxf(minf(out, state.enemy_hp) - minf(base, state.enemy_hp), 0.0)
	return out


## True when the signature could be activated now (CombatView.can_activate_signature).
func sig_can_activate() -> bool:
	if signature == null or not _sig_ready_flag or signature.is_active():
		return false
	if state.is_player_dead() or state.is_enemy_dead() or flow.is_menu_open():
		return false
	if focus.is_active() and focus.locks_movement():
		return false
	return _phase != Phase.PLACING


# CombatView.activate_signature plus the counters (Thien Hoa's instant damage counts as dealt).
func _activate_signature(reason: String) -> bool:
	if not sig_can_activate():
		return false
	var hp_before: float = state.enemy_hp
	signature.activate()
	_sig_ready_flag = false
	formation.reset()
	_sig_was_active = signature.is_active()
	ms["sig_acts"] = int(ms["sig_acts"]) + 1
	if float(ms["sig_first"]) < 0.0:
		ms["sig_first"] = t
	var instant: float = maxf(hp_before - state.enemy_hp, 0.0)
	ms["sig_dmg"] = float(ms["sig_dmg"]) + instant
	ms["dealt"] = float(ms["dealt"]) + instant
	_tr("PLAYER signature %s (%s) instant_dmg=%.1f boss_hp=%.0f" % [_sig_id, reason, instant, state.enemy_hp])
	if not _sig_was_active:
		_end_sig_effect()
	return true


# Bot activation, per-tick part. rules: Thien Hoa on enough burn on the enemy half (or after holding it
# sig_th_hold s); Anh Bo when the boss is pinned or a dodge is pending; Tram is fired at cast start.
func _bot_signature() -> void:
	var mode: String = str(bot["sig"])
	if mode == "off" or not sig_can_activate():
		return
	if mode == "ready":
		_activate_signature("ready")
		return
	match _sig_id:
		"thien_hoa":
			var total: float = 0.0
			var n: int = 0
			for cell: Vector2i in status.burning_cells():
				if grid.is_enemy_cell(cell):
					n += 1
					total += status.remaining_burn_damage(cell)
			if total >= float(bot["sig_th_min_burn"]) or n >= int(bot["sig_th_min_cells"]):
				_activate_signature("burn %.1f on %d cells" % [total, n])
			elif _sig_ready_since >= 0.0 and t - _sig_ready_since >= float(bot["sig_th_hold"]):
				_activate_signature("held %.1fs" % (t - _sig_ready_since))
		"anh_bo":
			if status.is_pinned(ENEMY):
				_activate_signature("boss pinned")
			elif _dodge_at >= 0.0:
				_activate_signature("dodge")
		"vay_bat":
			# Story 037: right after a player zone (seal / thorns) formed, so the follow-up casts of that zone
			# and the zones cast in the next seconds are in the window. The flag lapses with the zone.
			if _zone_formed_pending:
				if t <= _zone_follow_until:
					_activate_signature("zone formed")
				_zone_formed_pending = false
		"thanh_an":
			# Story 037: when the boss carries at least one Han stack (the extra stack then reaches the burst sooner).
			if status.frost_stacks(ENEMY) >= int(bot["sig_thanh_an_min_stacks"]):
				_activate_signature("boss han %d" % status.frost_stacks(ENEMY))


# Rules, cast-start part: Tram before a cast of >= sig_tram_min_cells cells or once the boss is low;
# Anh Bo (not fired yet) at the next cast.
func _bot_signature_at_cast(cells: int) -> void:
	if str(bot["sig"]) != "rules" or not sig_can_activate():
		return
	if _sig_id == "tram" and (cells >= int(bot["sig_tram_min_cells"]) or state.enemy_hp <= float(bot["sig_tram_boss_hp"]) * state.enemy_max_hp):
		_activate_signature("before cast n=%d" % cells)
	elif _sig_id == "anh_bo":
		_activate_signature("next cast")


# ---------------------------------------------------------------- signal handlers


func _tr(msg: String) -> void:
	if trace:
		print("  [%7.2f | real %7.2f] %s" % [t, real, msg])


func _on_swing_resolved(side: int, result: Dictionary) -> void:
	var damage: float = float(result["damage"])
	var cells: Array[Vector2i] = []
	cells.assign(result["cells"] as Array)
	_tr("%s swing resolved hit=%s dmg=%.1f cells=%s player=%s boss=%s" % ["PLAYER" if side == PLAYER else "BOSS", str(result["hit"]), damage, str(cells), str(state.player_cell), str(state.enemy_cell)])
	if side == PLAYER:
		if formation != null:
			formation.cover(cells)
			_check_sig_ready()
		if signature != null and bool(result["hit"]):
			signature.on_hit(str(result.get("skill_id", "")), damage)
			ms["sig_dmg"] = float(ms["sig_dmg"]) + _sig_pending_extra
		_sig_pending_extra = 0.0
		trait_host.on_player_swing_resolved(result)
		trait_host.on_boss_damaged(damage)
		_relics_on_cast_landed(result)
		ms["dealt"] = float(ms["dealt"]) + damage
		ms["resolved"] = int(ms["resolved"]) + 1
		var size_res: Dictionary = ms["size_res"]
		size_res[cells.size()] = int(size_res.get(cells.size(), 0)) + 1
		if bool(result["hit"]):
			ms["hits"] = int(ms["hits"]) + 1
			var size_hits: Dictionary = ms["size_hits"]
			size_hits[cells.size()] = int(size_hits.get(cells.size(), 0)) + 1
		_count_zone_result(result)
	else:
		learning.on_boss_swing_resolved(bool(result["hit"]))
		trait_host.on_boss_swing_resolved(result)
		ms["taken"] = float(ms["taken"]) + damage
		ms["bswings"] = int(ms["bswings"]) + 1
		if bool(result["hit"]):
			ms["bhits"] = int(ms["bhits"]) + 1
			ms["shits"] = int(ms["shits"]) + 1
			ms["bdmg"] = float(ms["bdmg"]) + damage


# Mirrors CombatView._relics_on_cast_landed (an_chu flashes on a featured hit).
func _relics_on_cast_landed(result: Dictionary) -> void:
	if relics.is_empty():
		_cast_info = {}
		return
	var info: Dictionary = _cast_info.duplicate()
	info["hit"] = bool(result.get("hit", false))
	info["cells"] = (result.get("cells", []) as Array).size()
	_cast_info = {}
	if bool(result.get("featured", false)):
		for r: Variant in relics:
			if (r as BaseRelic).featured_mult_override() > 0.0 and (r as BaseRelic).has_method("flash"):
				(r as BaseRelic).call("flash")
	for r: Variant in relics:
		(r as BaseRelic).on_cast_landed(info)


# Story 027 counters of one resolved player swing, and the zone follow-up trigger.
func _count_zone_result(result: Dictionary) -> void:
	var hit: bool = bool(result["hit"])
	var kind: String = str(result.get("zone_kind", ""))
	var placed: Array = result.get("zone_cells", []) as Array
	if kind.is_empty() and not _cast_zone:
		var post: bool = _last_seal_at >= 0.0 and _cast_t >= _last_seal_at and _cast_t - _last_seal_at <= POST_SEAL_SEC
		var pre: String = "ps_" if post else "o_"
		ms[pre + "res"] = int(ms[pre + "res"]) + 1
		if hit:
			ms[pre + "hits"] = int(ms[pre + "hits"]) + 1
		return
	if placed.is_empty():
		return
	var first: Vector2i = placed[0]
	if kind == StatusEffects.KIND_SEAL:
		ms["seals"] = int(ms["seals"]) + 1
		ms["seal_cells"] = int(ms["seal_cells"]) + placed.size()
		_last_seal_at = t
		_zone_follow_until = t + status.seal_left(ENEMY, first)
	elif kind == StatusEffects.KIND_THORNS:
		ms["thorns"] = int(ms["thorns"]) + 1
		ms["thorn_cells"] = int(ms["thorn_cells"]) + placed.size()
		_zone_follow_until = t + status.thorn_left(ENEMY, first)
	if _zone_follow_until > t:
		_next_cast = t
		_zone_formed_pending = true
	_tr("PLAYER zone %s formed %s follow-up until %.2f" % [kind, str(placed), _zone_follow_until])


func _on_thorn_entered(side: int, cell: Vector2i, damage: float) -> void:
	_tr("THORN entered by %s at %s dmg=%.1f" % ["BOSS" if side == ENEMY else "PLAYER", str(cell), damage])
	if side == ENEMY:
		if passive != null:
			passive.on_boss_thorn_step(cell)
		ms["bthorn"] = int(ms["bthorn"]) + 1
		ms["bthorn_dmg"] = float(ms["bthorn_dmg"]) + damage
		ms["dealt"] = float(ms["dealt"]) + damage
	else:
		ms["pthorn"] = int(ms["pthorn"]) + 1
		ms["pthorn_dmg"] = float(ms["pthorn_dmg"]) + damage
		ms["taken"] = float(ms["taken"]) + damage


# Story 037: a Han burst on the boss counts as the match stat `frost_bursts` (achievement frost_burst_5).
func _on_frost_burst(side: int, damage: float) -> void:
	_tr("FROST burst on %s dmg=%.1f" % ["BOSS" if side == ENEMY else "PLAYER", damage])
	if side == ENEMY and ms.has("frost_bursts"):
		ms["frost_bursts"] = int(ms["frost_bursts"]) + 1
		if passive != null:
			passive.on_frost_burst(damage)


# Story 037 (CombatView._on_status_zone_applied): a zone the player forms on the boss half reaches the passive.
func _on_zone_applied(kind: String, side: int, cells: Array[Vector2i]) -> void:
	if side == ENEMY and passive != null:
		passive.on_player_zone_formed(kind, cells)


func _on_blast_fired(cells: Array[Vector2i], hit: bool) -> void:
	_tr("FUSE blast cells=%s hit=%s" % [str(cells), str(hit)])
	if hit and _fuse != null:
		ms["taken"] = float(ms["taken"]) + _fuse.param_float("fuse_damage", FuseCannonTrait.DEFAULT_FUSE_DAMAGE)
		ms["bhits"] = int(ms["bhits"]) + 1


func _on_slam_landed(cells: Array[Vector2i], damaged: bool) -> void:
	_tr("SLAM cells=%s damaged=%s" % [str(cells), str(damaged)])
	if damaged and _slam != null:
		ms["taken"] = float(ms["taken"]) + _slam.param_float("slam_damage", SlamTrait.DEFAULT_SLAM_DAMAGE)
		ms["bhits"] = int(ms["bhits"]) + 1


func _on_swing_interrupted(victim_side: int, _cells: Array[Vector2i], _skill_id: String) -> void:
	_tr("interrupted victim=%s" % ("PLAYER" if victim_side == PLAYER else "BOSS"))
	if victim_side == ENEMY:
		ms["interrupts"] = int(ms["interrupts"]) + 1
		learning.on_player_interrupted_boss()
		for r: Variant in relics:
			(r as BaseRelic).on_interrupt_by_player()
	else:
		ms["interrupted"] = int(ms["interrupted"]) + 1


func _on_boss_swing_started(cells: Array[Vector2i], skill_id: String, duration: float) -> void:
	learning.on_boss_swing_started(cells, state.player_cell)
	trait_host.on_boss_swing_started(cells, skill_id)
	ms["bstarts"] = int(ms["bstarts"]) + 1
	boss_swing_started_now = true
	_tr("BOSS swing start %s cells=%s dur=%.2f player=%s rooted=%s" % [skill_id, str(cells), duration, str(state.player_cell), str(boss.is_step_locked())])
	if _driver != null:
		return
	if cells.has(state.player_cell) and rng.randf() < float(bot["dodge"]):
		_dodge_at = t + float(bot["dodge_reaction"])
	# Counter: the boss is rooted by its own swing -> cast at its cell now.
	if not actor.is_swinging() and _phase == Phase.IDLE and rng.randf() < float(bot["counter"]):
		_force_aim = true
		_next_cast = minf(_next_cast, t)


func _on_boss_swing_cancelled(_cells: Array[Vector2i], _skill_id: String) -> void:
	learning.on_boss_swing_cancelled()
	_dodge_at = -1.0


func _on_cell_changed(side: int, _old_cell: Vector2i, new_cell: Vector2i) -> void:
	if side == PLAYER:
		# Story 039: how long the bot has stood on this cell (crumble) and when it last stood on each cell.
		_stand_cell = new_cell
		_stand_since = t
		_visit_t[new_cell] = t
	if hazards != null and hazards.is_mire(side, new_cell):
		var mk: String = "mire_in" if side == PLAYER else "bmire_in"
		ms[mk] = int(ms[mk]) + 1
	if side != PLAYER:
		boss_step_at = t
		return
	learning.on_player_moved(new_cell)
	var point: FieldPoint = drops.pick_up_at(new_cell, not bag.is_full())
	if point != null:
		bag.place_in_first_free(point)


# Story 041: adds an odd block's cells to its side's total (start pieces are never odd).
func _on_odd_point_spawned(point: FieldPoint, side: int) -> void:
	if point.piece != null and point.piece.is_odd():
		_odd_cells[0 if side == PLAYER else 1] = int(_odd_cells[0 if side == PLAYER else 1]) + point.piece.cell_count()


func _on_bag_slot_cleared(_index: int, _point: FieldPoint) -> void:
	if _consuming or state.is_player_dead():
		return
	var point: FieldPoint = drops.pick_up_at(state.player_cell, true)
	if point != null:
		bag.place_in_first_free(point)


func _on_player_swing_done(_cells: Array[Vector2i], _skill_id: String) -> void:
	var gap: float = rng.randf_range(float(bot["gap_min"]), float(bot["gap_max"]))
	_next_cast = t if _zone_follow_until > t else t + gap


# CombatView._on_skill_chosen + _begin_cut: the featured bonus rides only on a featured two-piece cast.
func _on_skill_chosen(skill_id: String, _labels: Array[String], cells: Array[Vector2i]) -> void:
	var bonus: Dictionary = {}
	if not featured.is_empty() and plan.is_featured(featured["cells"] as Array[Vector2i]):
		bonus = (featured["bonus"] as Dictionary).duplicate(true)
	var fm: float = RelicRegistry.featured_mult_override(relics)
	if fm > 0.0 and not bonus.is_empty():
		bonus["damage_mult"] = fm
	_cast_info = _make_cast_info(skill_id, cells.size(), plan.pieces().size() >= 2, not bonus.is_empty())
	plan.clear()
	_phase = Phase.IDLE
	var level: int = card_level(skill_id)
	_tr("PLAYER cast %s n=%d cells=%s boss=%s featured=%s" % [skill_id, cells.size(), str(cells), str(state.enemy_cell), str(not bonus.is_empty())])
	if actor.begin_swing(cells, skill_id, true, level, -1.0, bonus):
		cooldowns.start(skill_id, float(cards.resolved(skill_id, level).get("cooldown_sec", 0.0)))
		if signature != null:
			signature.on_cast(skill_id, cells.size())
		ms["casts"] = int(ms["casts"]) + 1
		ms["cells"] = int(ms["cells"]) + cells.size()
		_cast_t = t
		_cast_zone = cards.is_zone_card(skill_id)
		if _cast_zone:
			ms["zone_casts"] = int(ms["zone_casts"]) + 1
		if not bonus.is_empty():
			ms["featured"] = int(ms["featured"]) + 1
	else:
		_next_cast = t + float(bot["gap_min"])
	_on_bag_slot_cleared(-1, null)


# ---------------------------------------------------------------- bot


func _bot_tick(real_step: float) -> void:
	match _phase:
		Phase.IDLE:
			_bot_idle()
		Phase.PLACING:
			_phase_left -= real_step
			if _phase_left <= 0.0:
				_confirm_placement()
		Phase.MENU:
			if not flow.is_menu_open():
				_phase = Phase.IDLE
				plan.clear()
				return
			if _phase_left > 0.0:
				_phase_left -= real_step
				if _phase_left <= 0.0:
					_join_piece()
				return
			_choose_left -= real_step
			if _choose_left <= 0.0:
				_choose_card()
		Phase.MENU_WAIT:
			if not flow.is_menu_open():
				_phase = Phase.IDLE
				plan.clear()


func _bot_idle() -> void:
	_bot_signature()
	if _fire_dodge():
		return
	if _dodge_at >= 0.0:
		_telegraph_dodge()
		return
	if _mire_exit():
		return
	if _crumble_exit():
		return
	if not actor.is_swinging() and t >= _next_cast and _ready_to_cast() and _try_start_cast():
		return
	_walk_to_piece()


# Enough placeable pieces held: >= bot.hold, or >= 1 when countering or when the bag is full.
func _ready_to_cast() -> bool:
	var n: int = 0
	for i: int in bag.get_slot_count():
		var p: Piece = bag.get_piece(i)
		if p != null and p.placeable():
			n += 1
	if n <= 0:
		return false
	return n >= int(bot["hold"]) or _force_aim or bag.is_full() or _zone_follow_until > t


# One real step through the mover; a success is forwarded to the TraitHost (CombatView.try_step_player).
func _bot_step(d: Vector2i) -> bool:
	var from: Vector2i = state.player_cell
	if not mover.try_step(d):
		return false
	trait_host.on_player_stepped(from, state.player_cell)
	return true


func _warned_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var rb: RowBurnerTrait = trait_host.get_trait("row_burner") as RowBurnerTrait
	if rb != null:
		out.append_array(rb.get_warning_cells())
	var fuse: FuseCannonTrait = trait_host.get_trait("fuse_cannon") as FuseCannonTrait
	if fuse != null:
		out.append_array(fuse.get_warning_cells())
	if _haz_vents > 0 or _haz_crumble:
		out.append_array(_haz_warned())
	return out


# Story 039: cells of the player's half the bot must leave or keep off: a vent line in its warning phase (an
# erupting vent is a burning cell, status.is_burning covers it) and a cracking cell (about to fall).
func _haz_warned() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _haz_vents > 0:
		var warn_total: float = float(_haz_cfg.get("vent_warn_sec", 1.0))
		for c: Vector2i in hazards.call("vent_cells", PLAYER) as Array[Vector2i]:
			if bool(hazards.call("is_vent_warning", PLAYER, c)) and float(hazards.call("vent_warn_left", PLAYER, c)) <= warn_total - vent_react_sec:
				out.append(c)
	if _haz_crumble:
		for c: Vector2i in grid.player_cells():
			if bool(hazards.call("is_crumble_warning", PLAYER, c)):
				out.append(c)
	return out


# Story 039: on a crumble arena the bot never camps: after CRUMBLE_LEAVE_SEC on one cell (the unit only stands
# still when it casts or waits) it steps to the neighbour it stood on longest ago, a piece first. Not while its own
# swing runs (it is rooted). True when it stepped.
func _crumble_exit() -> bool:
	if not _haz_crumble or not mover.is_ready() or actor.is_swinging():
		return false
	if t - _stand_since < crumble_leave_sec:
		return false
	var here: Vector2i = state.player_cell
	var warned: Array[Vector2i] = _warned_cells()
	var danger: Array[Vector2i] = boss.get_actor().get_cells() if boss.get_actor().is_swinging() else ([] as Array[Vector2i])
	var piece_cells: Dictionary = {}
	for p: FieldPoint in drops.get_points():
		if not p.rotten:
			piece_cells[p.cell] = true
	var best: Vector2i = Vector2i.ZERO
	var best_score: float = -INF
	for d: Vector2i in DIRS:
		var c: Vector2i = here + d
		if not grid.is_player_cell(c) or warned.has(c) or danger.has(c) or status.is_burning(c) or _step_blocked(c):
			continue
		if not status.thorns_at(PLAYER, c).is_empty():
			continue
		var score: float = -float(_visit_t.get(c, -100.0)) - (0.5 if hazards.is_mire(PLAYER, c) else 0.0)
		if piece_cells.has(c) and not bag.is_full():
			score += 1000.0
		if score > best_score:
			best_score = score
			best = d
	if best_score == -INF:
		return false
	return _bot_step(best)


# Story 039: no adjacent safe cell: one step along the shortest way to the nearest cell that is neither in
# [param bad] nor burning (BFS over the player's half, blocked cells and fallen cells excluded). True when it stepped.
func _step_toward_safe(bad: Array[Vector2i]) -> bool:
	var start: Vector2i = state.player_cell
	var first: Dictionary = {start: Vector2i.ZERO}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur != start and not bad.has(cur) and not status.is_burning(cur):
			return _bot_step(first[cur] as Vector2i)
		for d: Vector2i in DIRS:
			var nb: Vector2i = cur + d
			if first.has(nb) or not grid.is_player_cell(nb) or _step_blocked(nb):
				continue
			first[nb] = d if cur == start else first[cur]
			queue.append(nb)
	return false


func _step_blocked(c: Vector2i) -> bool:
	if mover.is_cell_blocked(c):
		return true
	var slam: SlamTrait = trait_host.get_trait("slam") as SlamTrait
	return slam != null and (slam.is_cracked(c) or slam.get_warning_cells().has(c))


# Leaves a row_burner / fuse_cannon warning or a burning cell when possible. True when it stepped or is
# standing in such a cell (waiting for the mover).
func _fire_dodge() -> bool:
	var here: Vector2i = state.player_cell
	var warned: Array[Vector2i] = _warned_cells()
	if not warned.has(here) and not status.is_burning(here):
		return false
	if not mover.is_ready():
		return true
	for d: Vector2i in DIRS:
		var c: Vector2i = here + d
		if grid.is_player_cell(c) and not warned.has(c) and not status.is_burning(c) and not _step_blocked(c):
			if _bot_step(d):
				return true
	if _haz_vents > 0 and _step_toward_safe(warned):
		return true
	return false


# After dodge_reaction, steps to an adjacent player cell outside the boss's telegraphed cells.
func _telegraph_dodge() -> void:
	if t < _dodge_at:
		return
	var boss_actor: CutActor = boss.get_actor()
	var here: Vector2i = state.player_cell
	if not boss_actor.is_swinging() or not boss_actor.get_cells().has(here):
		_dodge_at = -1.0
		return
	if not mover.is_ready():
		return
	var danger: Array[Vector2i] = boss_actor.get_cells()
	var options: Array[Vector2i] = []
	var thorned: Array[Vector2i] = []
	for d: Vector2i in DIRS:
		var c: Vector2i = here + d
		if grid.is_player_cell(c) and not danger.has(c) and not status.is_burning(c) and not _step_blocked(c):
			if status.thorns_at(PLAYER, c).is_empty():
				options.append(d)
			else:
				thorned.append(d)
	if options.is_empty():
		options = thorned
	if options.is_empty() or _bot_step(options[rng.randi_range(0, options.size() - 1)]):
		_dodge_at = -1.0


# Walks one step (when the mover is ready) toward the nearest non-rotten piece on the player's half,
# around burning / warned / cracked cells and the boss's telegraphed cells. Only while the bag has room.
func _walk_to_piece() -> void:
	if bag.is_full() or not mover.is_ready():
		return
	var targets: Dictionary = {}
	for p: FieldPoint in drops.get_points():
		if not p.rotten and p.piece != null and p.piece.placeable():
			targets[p.cell] = true
	if targets.is_empty():
		return
	var avoid: Array[Vector2i] = _warned_cells()
	avoid.append_array(status.burning_cells())
	avoid.append_array(status.thorn_cells(PLAYER))
	if boss.get_actor().is_swinging():
		avoid.append_array(boss.get_actor().get_cells())
	if hazards != null and (hazards.wind_enabled() or not hazards.mire_cells(PLAYER).is_empty()):
		_walk_weighted(targets, avoid)
		return
	var start: Vector2i = state.player_cell
	var first: Dictionary = {start: Vector2i.ZERO}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur != start and targets.has(cur):
			_bot_step(first[cur] as Vector2i)
			return
		for d: Vector2i in DIRS:
			var nb: Vector2i = cur + d
			if first.has(nb) or not grid.is_player_cell(nb) or avoid.has(nb) or _step_blocked(nb):
				continue
			first[nb] = d if cur == start else first[cur]
			queue.append(nb)


# Seconds the boss cannot leave its cell from now: rooted = rest of its swing (+ queued combo) plus its
# reaction latency; else the later of its step cooldown and its reaction latency; minus the margin.
func _strike_budget() -> float:
	var latency: float = boss.get_brain().get_reaction_sec() + float(bot["think_frac"]) * _boss_think
	var b_actor: CutActor = boss.get_actor()
	if boss.is_step_locked():
		var left: float = b_actor.get_time_left() + (b_actor.get_queued_duration() if b_actor.has_queued() else 0.0)
		return left + latency - float(bot["strike_margin"])
	return maxf(boss.get_mover().get_cooldown_remaining(), latency) - float(bot["strike_margin"])


# Sim seconds the bot's human time costs before the swing starts (Focus freezes placing when ready).
func _latency_estimate(join: bool) -> float:
	var scale: float = cards.menu_time_scale
	var place: float = float(bot["place_sec"]) * (focus.get_time_scale() if focus.is_ready() else scale)
	return place + (float(bot["join_sec"]) if join else 0.0) * scale + float(bot["choose_sec"]) * scale


func _swing_sec(n: int) -> float:
	var dur: float = cut_config.swing_duration(n) * actor.duration_mult
	if passive != null:
		dur = float(passive.modify_swing_duration(n, dur))
	return dur


# Starts a cast: chooses the target and the plan, fires Tram / Anh Bo under the rules, enters PLACING.
func _try_start_cast() -> bool:
	var forced: bool = _force_aim
	var follow: bool = _zone_follow_until > t
	if not forced and not follow and boss.get_brain().get_reaction_sec() > 0.0 and not boss.is_step_locked():
		var fresh: bool = boss_step_at >= 0.0 and t - boss_step_at <= float(bot["strike_fresh"])
		if not fresh and (_wait_since < 0.0 or t - _wait_since < float(bot["wait_step"])):
			if _wait_since < 0.0:
				_wait_since = t
			return false
	_wait_since = -1.0
	_force_aim = false
	var enemy: Array[Vector2i] = grid.enemy_cells()
	var aimed: bool = forced or follow or rng.randf() < float(bot["aim"])
	var target: Vector2i = state.enemy_cell if aimed else enemy[rng.randi_range(0, enemy.size() - 1)]
	var c: Dictionary = _plan_cast(target, _strike_budget() - _latency_estimate(false), true)
	if c.is_empty():
		_next_cast = t + 0.2
		return false
	_bot_signature_at_cast((c["cells"] as Array).size())
	_cast = c
	_cast["target_aimed"] = aimed
	_cast["target"] = target
	if forced:
		ms["counters"] = int(ms["counters"]) + 1
	_phase = Phase.PLACING
	_phase_left = float(bot["place_sec"])
	_tr("PLAYER placing %s cells=%s join=%s target=%s" % [str(c["piece"].shape_id), str(c["cells"]), str(c.has("join")), str(target)])
	return true


# Drop: re-aims the same piece at the boss's current cell (a human adjusts the drag), removes it from the
# bag, ends Focus (confirmed) and opens the card menu with a drawn hand.
func _confirm_placement() -> void:
	var slot: int = int(_cast["slot"])
	var piece: Piece = bag.get_piece(slot)
	if piece == null or not piece.placeable() or actor.is_swinging():
		_phase = Phase.IDLE
		_next_cast = t + 0.2
		return
	var target: Vector2i = _cast["target"]
	if bool(_cast["target_aimed"]):
		target = state.enemy_cell
	var best: Dictionary = _best_single([slot], target, _strike_budget() - _latency_estimate(_cast.has("join")))
	if best.is_empty():
		_phase = Phase.IDLE
		_next_cast = t + 0.2
		return
	focus.end(FocusController.REASON_CONFIRMED)
	_consuming = true
	bag.remove(slot)
	_consuming = false
	plan.init(_max_join, combat.max_cast_cells)
	var cells: Array[Vector2i] = []
	cells.assign(best["cells"])
	plan.add_piece(slot, best["piece"] as Piece, cells)
	# Story 033: mirrors CombatView: curse-aware deal (at least one non-curse card while the deck has one),
	# then each drawn curse's draw_damage hurts the player.
	var hand: Array[String] = deck.draw_menu(cards.hand_size, Callable(cards, "is_curse"))
	flow.open_menu([(best["piece"] as Piece).shape_id] as Array[String], cells, hand)
	for id: String in hand:
		if cards.is_curse(id):
			ms["curse_draws"] = int(ms["curse_draws"]) + 1
			var dmg: float = cards.draw_damage(id)
			if dmg > 0.0:
				state.damage_player(dmg)
				ms["curse_dmg"] = float(ms["curse_dmg"]) + dmg
	_cast["target"] = target
	_phase = Phase.MENU
	_phase_left = float(bot["join_sec"]) if (_cast.has("join") and rng.randf() < float(bot["join"])) else 0.0
	_choose_left = float(bot["choose_sec"])


# Second piece: the best remaining bag piece whose union with the plan scores higher than the plan alone.
func _join_piece() -> void:
	var slots: Array[int] = []
	for i: int in bag.get_slot_count():
		var p: Piece = bag.get_piece(i)
		if p != null and p.placeable():
			slots.append(i)
	if slots.is_empty() or plan.is_full():
		return
	var target: Vector2i = _cast["target"]
	var budget: float = _strike_budget() - float(bot["choose_sec"]) * cards.menu_time_scale
	var base: Array[Vector2i] = plan.cells()
	var base_score: float = _score(base, target, budget, false)
	var best: Dictionary = {}
	var best_score: float = base_score + 1.0
	for slot: int in slots:
		for turns: int in 4:
			var piece: Piece = bag.get_piece(slot).rotated(turns)
			for cells: Array[Vector2i] in _placements(piece):
				var union: Array[Vector2i] = _union(base, cells)
				if union.is_empty() or (combat.max_cast_cells > 0 and union.size() > combat.max_cast_cells):
					continue
				var s: float = _score(union, target, budget, true)
				if s > best_score:
					best_score = s
					best = {"slot": slot, "piece": piece, "cells": cells}
	if best.is_empty():
		return
	var cells2: Array[Vector2i] = best["cells"]
	if not plan.add_piece(int(best["slot"]), best["piece"] as Piece, cells2):
		return
	_consuming = true
	bag.remove(int(best["slot"]))
	_consuming = false
	var labels: Array[String] = []
	for p: Piece in plan.pieces():
		labels.append(p.shape_id)
	flow.update_cut(labels, plan.cells(), combat.join_extra_sec)
	ms["joins"] = int(ms["joins"]) + 1
	if not relics.is_empty():
		var jinfo: Dictionary = _make_cast_info("", plan.total_cells(), true, not featured.is_empty() and plan.is_featured(featured["cells"] as Array[Vector2i]))
		for r: Variant in relics:
			(r as BaseRelic).on_join(jinfo)
		# tam_hop: another join attempt (greedy, same rule) while the plan has room.
		if not plan.is_full():
			_phase_left = float(bot["join_sec"])
	_tr("PLAYER joined %s -> %d cells featured=%s" % [(best["piece"] as Piece).shape_id, plan.total_cells(), str(not featured.is_empty() and plan.is_featured(featured["cells"] as Array[Vector2i]))])


# Picks the best available card of the drawn hand; none available = wait for the menu timeout (default card).
func _choose_card() -> void:
	var count: int = plan.total_cells()
	var zone: String = _zone_choice(count)
	if not zone.is_empty() and flow.choose(zone):
		return
	var best: String = ""
	var best_value: float = -INF
	for id: String in flow.get_hand():
		if not bool(SkillAvailability.check(cards, cooldowns, id, count, card_level(id))["available"]):
			continue
		if cards.is_zone_card(id):
			continue
		var v: float = cast_value(id, card_level(id), count)
		if v > best_value:
			best_value = v
			best = id
	if best.is_empty() or not flow.choose(best):
		_phase = Phase.MENU_WAIT


# Enemy-half neighbours of the boss's cell it may step into now (its mover's blockers: seals...).
func _boss_open_exits() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var b_mover: UnitMover = boss.get_mover()
	for d: Vector2i in DIRS:
		var c: Vector2i = state.enemy_cell + d
		if grid.is_enemy_cell(c) and not b_mover.is_cell_blocked(c):
			out.append(c)
	return out


# Story 027 zone-card rule (see the file header): the zone card to pick for the placed cast, or "".
# Among available zone cards of the hand the higher damage_per_cell / Ran stacks wins.
func _zone_choice(count: int) -> String:
	if _zone_follow_until > t:
		return ""
	var seal: String = ""
	var thorn: String = ""
	var seal_key: float = -1.0
	var thorn_key: float = -1.0
	var kill_hp: float = -INF
	for id: String in flow.get_hand():
		var level: int = card_level(id)
		if not bool(SkillAvailability.check(cards, cooldowns, id, count, level)["available"]):
			continue
		if not cards.is_zone_card(id):
			kill_hp = maxf(kill_hp, cast_value(id, level, count))
			continue
		var c: Dictionary = cards.resolved(id, level)
		var key: float = float(c.get("damage_per_cell", 0.0)) + float(c.get("thorn_fragile_stacks", 0))
		if str(c["effect"]) == "seal" and key > seal_key:
			seal = id
			seal_key = key
		elif str(c["effect"]) == "thorns" and key > thorn_key:
			thorn = id
			thorn_key = key
	if (seal.is_empty() and thorn.is_empty()) or kill_hp >= state.enemy_hp:
		return ""
	var exits: Array[Vector2i] = _boss_open_exits()
	var cells: Array[Vector2i] = plan.cells()
	var covered: int = 0
	for c: Vector2i in exits:
		if cells.has(c):
			covered += 1
	if not seal.is_empty() and not exits.is_empty() and exits.size() <= ZONE_SEAL_MAX_EXITS and covered >= maxi(1, exits.size() - 1):
		_tr("PLAYER zone rule: seal %s exits=%s covered=%d" % [seal, str(exits), covered])
		return seal
	if not thorn.is_empty() and covered >= ZONE_THORN_MIN_COVER:
		_tr("PLAYER zone rule: thorns %s exits=%s covered=%d" % [thorn, str(exits), covered])
		return thorn
	return ""


# ---------------------------------------------------------------- placement planner


func _placements(piece: Piece) -> Array:
	var key: String = "%s|%d" % [piece.shape_id, piece.rotation]
	if piece.is_odd():
		# Story 041: two odd blocks of one canonical key can be grown in different base orientations, so
		# (shape_id, rotation) does not fix their cells; key on the turned cells instead.
		key = "%s|%s" % [piece.shape_id, str(piece.relative_cells())]
	if not _anchor_cache.has(key):
		var list: Array = []
		for anchor: Vector2i in PiecePlacement.valid_anchors(grid, piece):
			list.append(piece.cells_at(anchor))
		_anchor_cache[key] = list
	return _anchor_cache[key]


static func _union(a: Array[Vector2i], b: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = a.duplicate()
	for c: Vector2i in b:
		if out.has(c):
			return [] as Array[Vector2i]
		out.append(c)
	return out


func _score(cells: Array[Vector2i], target: Vector2i, budget: float, pair: bool) -> float:
	var s: float = SCORE_CELL * cells.size()
	if cells.has(target):
		s += SCORE_TARGET
	for d: Vector2i in DIRS:
		var nb: Vector2i = target + d
		if cells.has(nb) and not status.is_sealed(ENEMY, nb):
			s += SCORE_NEIGHBOUR * (1.0 if status.thorns_at(ENEMY, nb).is_empty() else THORN_NEIGHBOUR_SHARE)
	var over: float = _swing_sec(cells.size()) - maxf(budget, 0.0)
	if over > 0.0:
		s -= SCORE_OVER_BUDGET_PER_SEC * over
	if pair and not featured.is_empty() and FeaturedShape.matches(featured["cells"] as Array[Vector2i], cells):
		s += SCORE_FEATURED
	if signature is AnhBoSignature and signature.is_active() and cells.size() <= signature.param_int("small_cells", AnhBoSignature.DEFAULT_SMALL_CELLS):
		s += SCORE_ANH_BO_SMALL
	return s


# Best single placement among bag [param slots] (any rotation). Formation-aware with probability aware.
func _best_single(slots: Array[int], target: Vector2i, budget: float) -> Dictionary:
	var aware: bool = formation != null and not _sig_ready_flag and float(bot["aware"]) > 0.0 \
			and not (signature is AnhBoSignature and signature.is_active()) and rng.randf() < float(bot["aware"])
	var best: Array = []
	var best_score: float = -INF
	for slot: int in slots:
		var held: Piece = bag.get_piece(slot)
		if held == null or not held.placeable():
			continue
		for turns: int in 4:
			var piece: Piece = held.rotated(turns)
			for cells: Array[Vector2i] in _placements(piece):
				var s: float = 0.0
				if aware:
					if cells.size() < int(bot["aware_min"]) and held.cell_count() >= int(bot["aware_min"]):
						continue
					for c: Vector2i in cells:
						s += 1.0 - formation.fraction_left(c)
					s += 0.5 if cells.has(target) else 0.0
				else:
					s = _score(cells, target, budget, false)
				if s > best_score + 0.0001:
					best_score = s
					best = [{"slot": slot, "piece": piece, "cells": cells, "score": s}]
				elif absf(s - best_score) <= 0.0001:
					best.append({"slot": slot, "piece": piece, "cells": cells, "score": s})
	if best.is_empty():
		return {}
	return best[rng.randi_range(0, best.size() - 1)]


# The cast plan: the best single over the whole bag, plus a planned join when a two-piece union (first =
# one of the PAIR_SEEDS best singles) scores higher. {slot, piece, cells, score[, join]}.
func _plan_cast(target: Vector2i, budget: float, allow_join: bool) -> Dictionary:
	var slots: Array[int] = []
	for i: int in bag.get_slot_count():
		var p: Piece = bag.get_piece(i)
		if p != null and p.placeable():
			slots.append(i)
	var single: Dictionary = _best_single(slots, target, budget)
	if single.is_empty() or not allow_join or slots.size() < 2 or combat.max_pieces_per_cast < 2 or float(bot["join"]) <= 0.0:
		return single
	var singles: Array = []
	for slot: int in slots:
		for turns: int in 4:
			var piece: Piece = bag.get_piece(slot).rotated(turns)
			for cells: Array[Vector2i] in _placements(piece):
				singles.append({"slot": slot, "piece": piece, "cells": cells, "score": _score(cells, target, budget, false)})
	singles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	var pair_budget: float = budget - float(bot["join_sec"]) * cards.menu_time_scale
	var best_pair: float = float(single["score"]) + 1.0
	var chosen: Dictionary = {}
	for i: int in mini(PAIR_SEEDS, singles.size()):
		var a: Dictionary = singles[i]
		for slot: int in slots:
			if slot == int(a["slot"]):
				continue
			for turns: int in 4:
				var piece: Piece = bag.get_piece(slot).rotated(turns)
				for cells: Array[Vector2i] in _placements(piece):
					var union: Array[Vector2i] = _union(a["cells"] as Array[Vector2i], cells)
					if union.is_empty() or (combat.max_cast_cells > 0 and union.size() > combat.max_cast_cells):
						continue
					var s: float = _score(union, target, pair_budget, true)
					if s > best_pair:
						best_pair = s
						chosen = a.duplicate()
						chosen["score"] = s
						chosen["join"] = {"slot": slot}
	return chosen if not chosen.is_empty() else single


## Probe helper: the best placement of a pieces.json shape with exactly [param n] cells (any rotation)
## covering [param target], most covered neighbours first, ties by rng. Empty when none fits.
func best_piece_cells(target: Vector2i, n: int) -> Array[Vector2i]:
	var best: Array = []
	var best_score: int = -1
	for id: String in piece_lib.shape_ids():
		if piece_lib.shape_cells(id).size() != n:
			continue
		for turns: int in 4:
			for cells: Array[Vector2i] in _placements(piece_lib.make_piece(id, turns)):
				if not cells.has(target):
					continue
				var s: int = 0
				for d: Vector2i in DIRS:
					if cells.has(target + d):
						s += 1
				if s > best_score:
					best_score = s
					best = [cells]
				elif s == best_score:
					best.append(cells)
	var out: Array[Vector2i] = []
	if not best.is_empty():
		out.assign(best[rng.randi_range(0, best.size() - 1)])
	return out


## Probe helper: the best union of TWO pieces.json placements (no shared cell) with exactly [param n]
## cells covering [param target], most covered neighbours first, ties by rng. Empty when none fits.
func best_pair_cells(target: Vector2i, n: int) -> Array[Vector2i]:
	var all: Array = []
	var seen: Dictionary = {}
	for id: String in piece_lib.shape_ids():
		for turns: int in 4:
			for cells: Array[Vector2i] in _placements(piece_lib.make_piece(id, turns)):
				var sorted: Array = cells.duplicate()
				sorted.sort()
				if not seen.has(str(sorted)):
					seen[str(sorted)] = true
					all.append(cells)
	var best: Array = []
	var best_score: int = -1
	for a: Array[Vector2i] in all:
		if not a.has(target) or a.size() >= n:
			continue
		for b: Array[Vector2i] in all:
			if a.size() + b.size() != n:
				continue
			var u: Array[Vector2i] = _union(a, b)
			if u.is_empty():
				continue
			var s: int = 0
			for d: Vector2i in DIRS:
				if u.has(target + d):
					s += 1
			if s > best_score:
				best_score = s
				best = [u]
			elif s == best_score:
				best.append(u)
	var out: Array[Vector2i] = []
	if not best.is_empty():
		out.assign(best[rng.randi_range(0, best.size() - 1)])
	return out


# ---------------------------------------------------------------- card value (ported)


func _deck_best_dpc() -> float:
	var best: float = 0.0
	for id: String in deck.to_array():
		var c: Dictionary = cards.resolved(id, card_level(id))
		if str(c["effect"]) == "damage" or str(c["effect"]) == "push":
			best = maxf(best, float(c["damage_per_cell"]))
	return best


func _after_defense(dmg: float, c: Dictionary) -> float:
	if _boss_defense <= 0.0 or dmg <= 0.0 or bool(c.get("pierce_defense", false)):
		return dmg
	return maxf(dmg - _boss_defense, minf(dmg, CutEffects.MIN_DAMAGE_AFTER_DEFENSE))


func _frost_value(stacks: int) -> float:
	if stacks <= 0 or combat.frost_stacks_to_burst <= 0:
		return 0.0
	if status.frost_stacks(ENEMY) + stacks >= combat.frost_stacks_to_burst:
		return combat.frost_burst_damage
	return combat.frost_burst_damage * float(stacks) / float(combat.frost_stacks_to_burst) * FROST_EXPECT


func _fragile_value(stacks: int) -> float:
	var room: int = mini(stacks, combat.fragile_max_stacks - status.fragile_stacks(ENEMY))
	if room <= 0:
		return 0.0
	return float(room) * (combat.fragile_mult - 1.0) * _deck_best_dpc() * AVG_CELLS


## Bot value of casting card [param id] at [param level] on [param count] cells now (same order as
## CutEffects.apply: signature cells, vs-Ran bonus, Ghim, Ran, execute, passive, signature, defense).
func cast_value(id: String, level: int, count: int) -> float:
	var c: Dictionary = cards.resolved(id, level)
	var effect: String = str(c["effect"])
	if effect == "damage" or effect == "push":
		var eff_cells: int = maxi(signature.modify_cells(count), 0) if signature != null else count
		var dmg: float = float(c["damage_per_cell"]) * eff_cells
		if status.fragile_stacks(ENEMY) > 0 and float(c.get("bonus_vs_fragile_mult", 1.0)) > 1.0:
			dmg *= float(c["bonus_vs_fragile_mult"])
		dmg *= status.damage_mult_against(ENEMY)
		dmg *= status.fragile_mult_against(ENEMY)
		var ratio: float = float(c.get("execute_ratio", 0.0))
		if ratio <= 0.0 and bool(c.get("execute", false)):
			ratio = combat.execute_ratio
		if ratio > 0.0 and state.enemy_hp <= ratio * state.enemy_max_hp:
			dmg *= CutEffects.EXECUTE_MULT
		if passive != null:
			dmg = passive.modify_damage(count, dmg)
		if signature != null:
			dmg = signature.modify_damage(id, count, dmg, status.is_pinned(ENEMY))
		return _after_defense(dmg, c) + _frost_value(int(c.get("frost_stacks", 0))) + _fragile_value(int(c.get("fragile_stacks", 0)))
	if effect == "burn":
		var v: float = float(c["burn_duration_sec"]) / maxf(float(c["burn_tick_sec"]), 0.01) * float(c["burn_damage_per_tick"]) * BURN_EXPECT
		return v * (BURN_STACK_MULT if status.is_burning(state.enemy_cell) else 1.0)
	if effect == "pin":
		var dpc: float = _deck_best_dpc()
		if dpc <= 0.0:
			return 0.0
		return _after_defense(dpc * PIN_CELLS * maxf(combat.pinned_damage_mult, 1.0), {}) * PIN_FOLLOWUP + _fragile_value(int(c.get("fragile_stacks", 0)))
	if effect == "fragile":
		return _fragile_value(int(c.get("fragile_stacks", 0)))
	if effect == "frost":
		return _frost_value(int(c.get("frost_stacks", 0)))
	return 0.0


# --- Story 036: tile hazards (mirrors CombatView._setup_hazards and its handlers) ---------------------

# Builds the TileHazards of this match: combat.json `hazards` overlaid by the match keys of the same names,
# arena mire / sand / wind from ArenaLibrary.hazards_for_match, the sand blocker and the mire step cost on both
# movers, the boss's mire immunity, the wind offset of new drops. With no hazard data nothing here draws a
# random number of the sim or changes a tick, so no-hazard runs stay byte-identical.
func _setup_hazards(m: Dictionary, match_seed: int) -> void:
	var merged: Dictionary = combat.hazards()
	for key: String in merged.keys():
		if m.has(key):
			merged[key] = m[key]
	hazards = TileHazards.new(grid, match_seed)
	hazards.configure(merged)
	hazards.bind_state(state)
	var h: TileHazards = hazards
	var st: StatusEffects = status
	var movers: Dictionary = {PLAYER: mover, ENEMY: boss.get_mover()}
	for side: int in movers:
		var mv: UnitMover = movers[side] as UnitMover
		var hazard_side: int = side
		mv.add_blocker(func(cell: Vector2i) -> bool: return h.is_sanded(hazard_side, cell))
		mv.step_cost_fn = func(from_cell: Vector2i) -> float: return h.step_cost_mult(hazard_side, from_cell)
		# Story 039: a fallen (crumbled) cell is the fourth blocker source on both movers (W1 model; older builds skip it).
		if h.has_method("is_fallen"):
			mv.add_blocker(func(cell: Vector2i) -> bool: return bool(h.call("is_fallen", hazard_side, cell)))
	hazards.extra_blocked_fn = func(side: int, cell: Vector2i) -> bool:
		return st.is_sealed(side, cell) or (movers[side] as UnitMover).is_cell_blocked(cell)
	hazards.set_mire_immune(ENEMY, bool(m.get("mire_immune", false)))
	var arena: Dictionary = ArenaLibrary.hazards_for_match(m, grid)
	var mire_player: Array[Vector2i] = []
	var mire_enemy: Array[Vector2i] = []
	mire_player.assign(arena.get("mire_player", []))
	mire_enemy.assign(arena.get("mire_enemy", []))
	hazards.set_mire(PLAYER, mire_player)
	hazards.set_mire(ENEMY, mire_enemy)
	hazards.enable_sand(bool(arena.get("sand", false)))
	hazards.enable_wind(bool(arena.get("wind", false)))
	hazards.mire_damage.connect(_on_mire_damage)
	hazards.sand_filled.connect(_on_sand_filled)
	hazards.drift_due.connect(_on_drift_due)
	var wind_fn: Callable = func() -> Vector2i: return h.wind_dir()
	drops.wind_offset_fn = wind_fn
	boss.get_drops().wind_offset_fn = wind_fn
	# Story 039: lava vents (burn through the SAME StatusEffects burning cells) and crumbling cells.
	_haz_cfg = merged
	_haz_vents = 0
	_haz_crumble = false
	if hazards.has_method("set_vents"):
		var vents_player: Array = arena.get("vents_player", []) as Array
		var vents_enemy: Array = arena.get("vents_enemy", []) as Array
		hazards.call("set_vents", PLAYER, vents_player)
		hazards.call("set_vents", ENEMY, vents_enemy)
		_haz_vents = vents_player.size() + vents_enemy.size()
		_haz_crumble = bool(arena.get("crumble", false))
		hazards.call("enable_crumble", _haz_crumble)
		hazards.connect("vent_erupted", _on_vent_erupted)
		hazards.connect("cell_fell", _on_cell_fell)
	# W4 adds BossController.set_hazards; older builds run without it.
	if boss.has_method("set_hazards"):
		boss.call("set_hazards", hazards)
	_drift_since = 0.0
	_haz_mire = mire_player.size() + mire_enemy.size()
	_haz_sand = bool(arena.get("sand", false))
	_haz_wind = bool(arena.get("wind", false))


# The unit standing in mire takes the tick damage (CombatState keeps its own invulnerability rules). The HP
# actually lost is counted (mire_dmg / bmire_dmg) and the player's also goes into "taken".
func _on_mire_damage(side: int, amount: float) -> void:
	var before: float = state.player_hp if side == PLAYER else state.enemy_hp
	state.damage(side, amount)
	var lost: float = maxf(before - (state.player_hp if side == PLAYER else state.enemy_hp), 0.0)
	if side == PLAYER:
		ms["mire_dmg"] = float(ms["mire_dmg"]) + lost
		ms["taken"] = float(ms["taken"]) + lost
	else:
		ms["bmire_dmg"] = float(ms["bmire_dmg"]) + lost
	_tr("%s mire damage %.1f" % ["PLAYER" if side == PLAYER else "BOSS", lost])


# Sand filled on [param cells] of [param side]: field pieces lying there are buried.
func _on_sand_filled(side: int, cells: Array[Vector2i]) -> void:
	var fd: FieldDrops = drops if side == PLAYER else boss.get_drops()
	var n: int = fd.bury_cells(cells)
	var key: String = "buried" if side == PLAYER else "bburied"
	ms[key] = int(ms[key]) + n
	if side == PLAYER:
		ms["sand_cells"] = int(ms["sand_cells"]) + cells.size()


# Story 039: a vent erupts: its cells burn through StatusEffects (the combat.json hazards numbers vent_sec /
# vent_tick_sec / vent_tick_damage, like row_burner's burn) and the field pieces lying there are burnt.
func _on_vent_erupted(side: int, _vent_index: int, cells: Array[Vector2i]) -> void:
	status.ignite(cells, float(_haz_cfg.get("vent_sec", 2.0)), float(_haz_cfg.get("vent_tick_sec", 0.5)),
		float(_haz_cfg.get("vent_tick_damage", 2.0)))
	var fd: FieldDrops = drops if side == PLAYER else boss.get_drops()
	var n: int = fd.bury_cells(cells)
	var key: String = "buried" if side == PLAYER else "bburied"
	ms[key] = int(ms[key]) + n
	if side == PLAYER:
		ms["vent_erupts"] = int(ms["vent_erupts"]) + 1
	_tr("vent erupted side=%d cells=%s" % [side, str(cells)])


# Story 039: a cell fell: the pieces on it are lost; the unit that stood on it was already moved to a steppable
# neighbour by the model and takes fall_damage here (the HP actually lost is counted, the player's also in "taken").
func _on_cell_fell(side: int, cell: Vector2i, occupant_pushed: bool) -> void:
	var fd: FieldDrops = drops if side == PLAYER else boss.get_drops()
	var n: int = fd.bury_cells([cell] as Array[Vector2i])
	var key: String = "buried" if side == PLAYER else "bburied"
	ms[key] = int(ms[key]) + n
	if side == PLAYER:
		ms["cell_falls"] = int(ms["cell_falls"]) + 1
	if not occupant_pushed:
		return
	var before: float = state.player_hp if side == PLAYER else state.enemy_hp
	state.damage(side, float(_haz_cfg.get("fall_damage", 8.0)))
	var lost: float = maxf(before - (state.player_hp if side == PLAYER else state.enemy_hp), 0.0)
	if side == PLAYER:
		ms["pushed"] = int(ms["pushed"]) + 1
		ms["fall_hp"] = float(ms["fall_hp"]) + lost
		ms["taken"] = float(ms["taken"]) + lost
	else:
		ms["bpushed"] = int(ms["bpushed"]) + 1
	_tr("%s pushed off cell %s, fall damage %.1f" % ["PLAYER" if side == PLAYER else "BOSS", str(cell), lost])


# The wind moves the field pieces of both halves one cell (a piece never drifts into sand). No piece is
# dragged on the field (pieces are placed from the bag), as in CombatView.
func _on_drift_due() -> void:
	_drift_since = 0.0
	var dir: Vector2i = hazards.wind_dir()
	var dragged: Array[Vector2i] = []
	var h: TileHazards = hazards
	for side: int in [PLAYER, ENEMY]:
		var drift_side: int = side
		var fd: FieldDrops = drops if side == PLAYER else boss.get_drops()
		var n: int = fd.drift_pieces(dir, func(cell: Vector2i) -> bool: return h.is_sanded(drift_side, cell), dragged)
		var key: String = "drifted" if side == PLAYER else "bdrifted"
		ms[key] = int(ms[key]) + n


# Cells that refuse new drops: [param base] (burning) plus, when sand is active, the sand and sand-warning
# cells of [param side] (CombatView._drop_blocked_cells). Without sand it returns [param base] itself.
func _drop_blocked(base: Array[Vector2i], side: int) -> Array[Vector2i]:
	if hazards == null:
		return base
	var sand: Array[Vector2i] = hazards.sand_cells(side)
	var warning: Array[Vector2i] = hazards.sand_warning_cells(side)
	# Story 039: fallen cells refuse drops too (CombatView._drop_blocked_cells; only when the model has them).
	var fallen: Array[Vector2i] = (hazards.call("fallen_cells", side) as Array[Vector2i]) if _haz_crumble else ([] as Array[Vector2i])
	if sand.is_empty() and warning.is_empty() and fallen.is_empty():
		return base
	var out: Array[Vector2i] = base.duplicate()
	for c: Vector2i in sand + warning + fallen:
		if not out.has(c):
			out.append(c)
	return out


# Story 036 bot walk on a hazard map (mire or wind present; the plain BFS above runs otherwise). Dijkstra over
# the player's half: a step costs 1, a step INTO mire 1 + MIRE_STEP_EXTRA, so the bot walks around mire unless
# the way round is much longer (like thorns, but by cost). Sand is blocked through the mover's sand blocker
# (_step_blocked). With the wind on, a piece the bot cannot reach before the next drift (steps x step cooldown
# > time to the drift) is chased at the cell it drifts to (when that cell can take it).
func _walk_weighted(targets: Dictionary, avoid: Array[Vector2i]) -> void:
	var start: Vector2i = state.player_cell
	var cost: Dictionary = {start: 0.0}
	var steps: Dictionary = {start: 0}
	var first: Dictionary = {start: Vector2i.ZERO}
	var done: Dictionary = {}
	var open: Array[Vector2i] = [start]
	while not open.is_empty():
		var bi: int = 0
		for i: int in range(1, open.size()):
			if float(cost[open[i]]) < float(cost[open[bi]]):
				bi = i
		var cur: Vector2i = open[bi]
		open.remove_at(bi)
		if done.has(cur):
			continue
		done[cur] = true
		for d: Vector2i in DIRS:
			var nb: Vector2i = cur + d
			if done.has(nb) or not grid.is_player_cell(nb) or avoid.has(nb) or _step_blocked(nb):
				continue
			var c: float = float(cost[cur]) + 1.0 + (MIRE_STEP_EXTRA if hazards.is_mire(PLAYER, nb) else 0.0)
			if not cost.has(nb) or c < float(cost[nb]):
				cost[nb] = c
				steps[nb] = int(steps[cur]) + 1
				first[nb] = d if cur == start else first[cur]
				open.append(nb)
	var wind: Vector2i = Vector2i.ZERO
	var drift_left: float = INF
	var occupied: Dictionary = {}
	if hazards.wind_enabled():
		wind = hazards.wind_dir()
		var dbg: Dictionary = hazards.get_debug()
		var interval: float = float((dbg.get("cfg", {}) as Dictionary).get("drift_sec", 2.0)) * float(dbg.get("drift_mult", 1.0))
		drift_left = maxf(interval - _drift_since, 0.0)
		for p: FieldPoint in drops.get_points():
			occupied[p.cell] = true
	var best: Vector2i = start
	var best_cost: float = INF
	for cell: Vector2i in targets.keys():
		var goal: Vector2i = cell
		if wind != Vector2i.ZERO and (not steps.has(cell) or float(int(steps[cell])) * _player_cd > drift_left):
			var next: Vector2i = cell + wind
			if next != start and grid.is_player_cell(next) and not occupied.has(next) and not hazards.is_sanded(PLAYER, next):
				goal = next
		if goal != start and cost.has(goal) and float(cost[goal]) < best_cost:
			best_cost = float(cost[goal])
			best = goal
	if best != start:
		_bot_step(first[best] as Vector2i)


# Story 036: standing in mire, the bot steps out to a dry neighbour that is safe (not burning, warned, thorned,
# blocked or under the boss's swing) before anything else, as a player would. Not while its own swing runs.
# True when it stepped. Without mire (hazards absent or no mire cell under the bot) it does nothing.
func _mire_exit() -> bool:
	if hazards == null or not hazards.is_mire(PLAYER, state.player_cell) or not mover.is_ready() or actor.is_swinging():
		return false
	var here: Vector2i = state.player_cell
	var warned: Array[Vector2i] = _warned_cells()
	var danger: Array[Vector2i] = boss.get_actor().get_cells() if boss.get_actor().is_swinging() else ([] as Array[Vector2i])
	for d: Vector2i in DIRS:
		var c: Vector2i = here + d
		if not grid.is_player_cell(c) or hazards.is_mire(PLAYER, c) or warned.has(c) or danger.has(c):
			continue
		if status.is_burning(c) or not status.thorns_at(PLAYER, c).is_empty() or _step_blocked(c):
			continue
		return _bot_step(d)
	return false
