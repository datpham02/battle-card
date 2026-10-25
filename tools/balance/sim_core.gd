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
	"no_zone_cards": false, "card_set": {},
}
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
	characters = CharacterConfig.load_from_file()


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
			bot["aware_min"] = clampi(int(v), 1, PieceLibrary.MAX_CELLS)
		elif arg.begins_with("--sig="):
			bot["sig"] = v if v in ["off", "ready", "rules"] else "rules"
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
	return "bot: %s | overrides: %s" % [" ".join(parts), ", ".join(o) if not o.is_empty() else "none"]


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
	out["passive_heal"] = heal
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
	var boss_max_hp: float = maxf(float(m.get("boss_max_hp", combat.enemy_max_hp)), 1.0)
	var player_max_hp: float = maxf(float(character.get("max_hp", combat.player_max_hp)), 1.0)
	state = CombatState.new(grid, player_max_hp, boss_max_hp, combat.player_start_cell, combat.enemy_start_cell)
	if start_hp >= 0.0:
		state.set_player_hp(start_hp)
	var base_cd: float = combat.step_cooldown_for(grid)
	var step_mult: float = float(character.get("step_cooldown_mult", 1.0))
	var player_cd: float = base_cd * (step_mult if step_mult > 0.0 else 1.0)
	mover = UnitMover.new(state, PLAYER, player_cd)
	var chapter_id: String = str(m.get("chapter_id", ""))
	var player_drops_config: FieldDropsConfig = drops_config.copy()
	player_drops_config.piece_spawn_interval_sec *= float(ov["drop_mult"])
	var boss_drops_config: FieldDropsConfig = drops_config.copy()
	var boss_drop_mult: float = maxf(float(m.get("boss_drop_interval_mult", 1.0)), 0.01) * float(ov["boss_drop_mult"])
	boss_drops_config.spawn_interval_sec *= boss_drop_mult
	boss_drops_config.piece_spawn_interval_sec *= boss_drop_mult
	drops = FieldDrops.new(player_drops_config, grid.player_cells(), match_seed)
	drops.enable_pieces(piece_lib, chapter_id, grid, match_seed)
	drops.place_start_pieces(state.player_cell)
	bag = HoldSlots.create_piece_hand(hold_config.piece_slot_count)
	bag.slot_cleared.connect(_on_bag_slot_cleared)
	plan = CastPlan.new().init(combat.max_pieces_per_cast, combat.max_cast_cells)
	featured = arena_library.featured_for_match(m, grid)
	state.cell_changed.connect(_on_cell_changed)
	cooldowns = SkillCooldowns.new()
	deck = Deck.from_array(deck_entries, match_seed)
	focus = FocusController.new(cards)
	if character.has("focus_max_sec"):
		focus.set_max_sec_override(float(character["focus_max_sec"]))
	actor = CutActor.new(cut_config, PLAYER)
	flow = CutFlow.new(cards, cooldowns)
	flow.level_of = Callable(self, "card_level")
	flow.skill_chosen.connect(_on_skill_chosen)
	var brain_config: BossBrainConfig = BossBrainConfig.from_dictionary(brain_data)
	_apply_brain_params(brain_config, m, base_cd)
	boss = BossController.new(state, grid, cut_config, cards, brain_config, boss_drops_config, hold_config, match_seed + 1)
	boss.enable_pieces(piece_lib, chapter_id, match_seed + 2, combat.max_pieces_per_cast)
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
	status.thorn_entered.connect(_on_thorn_entered)
	arbiter.swing_resolved.connect(_on_swing_resolved)
	arbiter.swing_interrupted.connect(_on_swing_interrupted)
	actor.swing_resolved.connect(_on_player_swing_done)
	actor.swing_cancelled.connect(_on_player_swing_done)
	var ctx: Dictionary = {
		"state": state, "grid": grid, "player_drops": drops, "boss_drops": boss.get_drops(),
		"boss": boss, "status": status, "arbiter": arbiter, "hold_getter": Callable(self, "get_bag"), "player_mover": mover,
		"skill_config": cards, "cut_config": cut_config,
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
	_last_seal_at = -1.0
	_cast_t = -1.0
	_cast_zone = false
	_next_cast = rng.randf_range(float(bot["gap_min"]), float(bot["gap_max"]))
	ms = {
		"casts": 0, "resolved": 0, "hits": 0, "dealt": 0.0, "taken": 0.0, "bstarts": 0, "bswings": 0, "bhits": 0, "shits": 0, "bdmg": 0.0,
		"interrupts": 0, "counters": 0, "sig_acts": 0, "sig_dmg": 0.0, "sig_first": -1.0, "focus_uses": 0,
		"joins": 0, "featured": 0, "cells": 0,
		# Story 027: zone casts, seals / thorns that formed and their cells, boss / player thorn entries and
		# damage, hit counts of non-zone casts started <= POST_SEAL_SEC after a seal (ps_) and of the others (o_).
		"zone_casts": 0, "seals": 0, "seal_cells": 0, "thorns": 0, "thorn_cells": 0, "bthorn": 0, "bthorn_dmg": 0.0,
		"pthorn": 0, "pthorn_dmg": 0.0, "ps_res": 0, "ps_hits": 0, "o_res": 0, "o_hits": 0,
	}
	_tr("match start %s boss_hp=%.0f player_hp=%.0f player=%s boss=%s player_cd=%.2f featured=%s" % [
		str(m.get("id", "")), boss_max_hp, state.player_hp, str(state.player_cell), str(state.enemy_cell), player_cd, str(not featured.is_empty())])


func _teardown() -> void:
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
	passive.setup({"state": state, "grid": grid, "boss": boss, "status": status, "skill_config": cards, "cut_config": cut_config},
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
	formation = FormationMap.new().init(enemy_cells, combat.formation_fade_for(enemy_cells.size()))
	var params: Variant = dict.get("params", {})
	signature.setup({"state": state, "grid": grid, "boss": boss, "status": status, "skill_config": cards,
		"cut_config": cut_config, "cooldowns": cooldowns, "formation": formation},
		(params as Dictionary) if typeof(params) == TYPE_DICTIONARY else {})
	_sig_id = id
	var cooldown: Variant = dict.get("cooldown_sec", 0.0)
	_sig_cd_sec = maxf(float(cooldown), 0.0) if (typeof(cooldown) == TYPE_FLOAT or typeof(cooldown) == TYPE_INT) else 0.0
	arbiter.player_cells_modifier = Callable(signature, "modify_cells")
	arbiter.player_signature_modifier = Callable(self, "_sig_mod_wrap")
	mover.cooldown_scale = Callable(signature, "step_cooldown_scale")


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
	status.tick(step, state)
	_tick_signature(step)
	if formation != null:
		formation.tick(step)
	mover.tick(step)
	learning.tick(step, bag.is_full())
	var burning: Array[Vector2i] = status.burning_cells()
	drops.set_blocked_cells(burning)
	boss.get_drops().set_blocked_cells(burning)
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
		ms["dealt"] = float(ms["dealt"]) + damage
		ms["resolved"] = int(ms["resolved"]) + 1
		if bool(result["hit"]):
			ms["hits"] = int(ms["hits"]) + 1
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
	_tr("PLAYER zone %s formed %s follow-up until %.2f" % [kind, str(placed), _zone_follow_until])


func _on_thorn_entered(side: int, cell: Vector2i, damage: float) -> void:
	_tr("THORN entered by %s at %s dmg=%.1f" % ["BOSS" if side == ENEMY else "PLAYER", str(cell), damage])
	if side == ENEMY:
		ms["bthorn"] = int(ms["bthorn"]) + 1
		ms["bthorn_dmg"] = float(ms["bthorn_dmg"]) + damage
		ms["dealt"] = float(ms["dealt"]) + damage
	else:
		ms["pthorn"] = int(ms["pthorn"]) + 1
		ms["pthorn_dmg"] = float(ms["pthorn_dmg"]) + damage
		ms["taken"] = float(ms["taken"]) + damage


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
	if side != PLAYER:
		boss_step_at = t
		return
	learning.on_player_moved(new_cell)
	var point: FieldPoint = drops.pick_up_at(new_cell, not bag.is_full())
	if point != null:
		bag.place_in_first_free(point)


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
	return out


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
	plan.init(combat.max_pieces_per_cast, combat.max_cast_cells)
	var cells: Array[Vector2i] = []
	cells.assign(best["cells"])
	plan.add_piece(slot, best["piece"] as Piece, cells)
	flow.open_menu([(best["piece"] as Piece).shape_id] as Array[String], cells, deck.draw(cards.hand_size))
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
