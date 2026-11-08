class_name GameFlow
extends Node2D
## The thin layer above one roguelike RUN (Story 015, 016, 018, 019, 022, 031): chapters (= regions)
## data, the saved progress, ONE [RunSession] while a run is live and ONE RunController child per MAP
## NODE that plays a match (created when the node is chosen, freed when it is left). Phases: TITLE,
## CHARACTER_SELECT (CharacterSelectView), WORLD_MAP (WorldMapView: pick one of the floor's offered
## regions), MAP (the region map, ChapterMapView: pick a node of the current column), IN_NODE (a
## RunController plays the node's match; the run screens take over), REST (RestView: heal or forge) and
## Story 033's SHOP (ShopView: [method get_shop], [method shop_buy], [method shop_use_service],
## [method shop_leave]) and EVENT (EventView: [method get_event_view], [method event_choose],
## [method get_event_result], [method event_complete_pick], [method event_leave]).
## [method go_back] (Esc, Android back) acts per phase: IN_NODE toggles the pause (or leaves a finished
## run), WORLD_MAP / MAP / REST leave to the title keeping the save, CHARACTER_SELECT -> TITLE,
## TITLE -> quit. App pause / focus loss while IN_NODE force-pauses the battle. Draws nothing itself.
## Direct child of Main in main.tscn; RunHudView (a sibling) gets the controller through
## [signal controller_changed]. Views the flow talks to are optional: a missing view node never breaks
## the flow (everything goes through signals and getters).
##
## Story 033 nodes (production/epics/kaiten-duel/story-033-gold-shop-events.md Parts B, C): a SHOP node
## builds its stock with ShopLogic.build (seeded by run seed + floor + column + node; luck; owned relics)
## into RunSession.shop_state (tagged with the node's "node_key"; a resume at the same node restores it,
## sold / used flags included); every buy / service saves; [method shop_leave] completes the node (no
## reward, no gold). An EVENT node picks an event never seen this run (ids kept in
## RunSession.event_state["used"]); a choice resolves through EventLogic (seeded by the node) and its
## result is kept in event_state BEFORE the save, so a resume shows that result and never re-rolls;
## player picks ([method event_complete_pick]) finish one by one. A `fight` outcome (tran_thach) plays
## an extra match of the outcome's kind (danger) drawn from the region's pool at the column tier +
## tier_add, through the same controller path as a match node, WITHOUT completing the node or moving
## the column: winning ticks the run modifiers, applies EventLogic.finish_fight (relic + gold) and
## returns to EVENT; losing ends the run. [method event_leave] completes the node.
##
## Story 034 piece deck (production/epics/kaiten-duel/story-034-piece-deck.md Parts A, B): the run keeps a
## PIECE DECK (RunSession.piece_deck, PieceDeck rules, rewards.json `piece_rewards`). A won battle / danger
## node adds an INK row to its reward screen with chance `ink_offer_chance` (seeded by the position), a
## treasure always does ([method get_ink_offer], [method choose_ink] keeps the card / relic choice open,
## [method skip_ink_offer]; closing the reward screen any other way drops it). [method open_piece_deck] /
## [method close_piece_deck] show the PIECE_DECK screen from WORLD_MAP / MAP ([method get_piece_deck_rows],
## [method remove_shape] spends a `shape_removals` token; +shape_removals_per_boss per boss). Every player
## match of a run gets match_params["piece_deck"] (RunController.piece_deck -> CombatView). The shop sells
## the `remove_shape` service for gold.
##
## Run rules (Story 031, design/game-brief.md v6 "Run v6 — mô hình OSFE"): title -> character ->
## [method start_run] (a fresh world run: floor 1, RunSession.begin_world rolls the floor's region
## offer, saved at once) -> WORLD_MAP -> [method choose_region] generates that region's short map for
## the floor (ChaptersConfig.generate_region_map, tier capped while no boss was ever beaten) -> MAP.
## [method choose_node] per node kind: battle / danger / miniboss / boss spawn a RunController for
## RunConfig.from_node (one match scaled by region normalize + floor scaling, arena seed
## RunSession.floor_seed() = arena_seed_for(run_seed, floor * 100 + column), between_sec 0, no
## minimum-HP rule) and save; treasure opens a free offer at once (no fight; Story 032: ONE screen with a
## row of 3 cards and a row of 3 relics, picking either closes both, skipping closes both); rest opens the REST
## screen. A WON match completes the node (RunSession.complete_node: HP carried, no automatic heal) and
## rolls the offer of the node kind (RewardRoller.reward_for_node) with the run's luck; the flow WAITS
## for [method reward_chosen] / [method reward_skipped] / [method reward_remove_requested]. A REGION
## boss does not win the run: the floor goes up, floor_heal_ratio x max HP heals (clamped; the banner
## reads [method take_floor_clear_notice]), the boss reward is offered, then WORLD_MAP shows the next
## floor's offer. After the last floor the run stands at the FINAL match (a one-node MAP,
## `world.final_match`); winning it drops the save and shows the RUN WON result
## ([method get_run_result] = WON). Death drops the saved run at once (LOST); there is no retry.
## Progress: best_floor (ProgressState.record_floor) on every floor reached, the region boss in
## regions_boss_beaten. [method leave_run] (the one button of the result screens) shows the title.
##
## Leaving mid-run ([method leave_run_keep_save], the pause menu / map / world map back button): the
## controller is freed, the run stays saved and the title shows "Tiếp tục". Resume
## ([method continue_requested]) rebuilds the v5 save: node chosen and no offer open -> the match
## respawns at the saved HP; offer open -> MAP with the offer; region offer open -> WORLD_MAP; nothing
## chosen -> MAP; a rest node chosen -> REST. A pre-v5 save (RunSession.needs_restart) starts a fresh
## world run for the saved character and leaves a one-line notice in [method take_restart_notice].
##
## DEV-ONLY user args (after "--"):
##   --progress=none|all|demo|v4save
##                              memory store (never writes user://progress.json): empty / every region
##                              boss beaten (onboarding off) / a v5 saved run at floor 2 (region 1's
##                              boss beaten, 1 column of the floor-2 region cleared, HP 171) / a real v4
##                              (chapter) progress file parsed by ProgressState.from_json, starting on
##                              the TITLE: "Tiếp tục" shows the one-line restart notice
##   --region=<id>              fresh seeded run walking that region (at --at-floor, default floor 1),
##                              shown on its MAP (alias: --chapter=<id>)
##   --at-floor=N               1-based floor the dev run starts at (floors before cleared with the first
##                              offered region and first nodes; no --region: the WORLD_MAP of floor N)
##   --node=fF/<region>/cC/nN   skip the menus: fresh run at floor F in that region, columns before C
##                              cleared, node N of column C chosen (a match node spawns its controller;
##                              treasure opens its offer; rest -> REST). Legacy --node=chX/cC/nN = f1/chX
##   --floor=ch1/f2             legacy alias of --node=f1/ch1/c0/n0 (warning)
##   --title                    show the title even with --progress=... (without it --progress alone
##                              starts at the character select; no dev arg at all starts at the title)
##   --seed=N                   force the run seed (reproducible offers, maps, arenas and rewards)
##   --lang=vi|en               UI locale for this run only (not saved; captures)
##   --gold=N                   Story 033: every run starts with N gold (memory store)
##   --deck+=id,id,...          Story 033: every run's starting deck gets these cards (level 1; curses
##                              too, e.g. --deck+=oan_hon) (memory store)
##   --hp=N                     Story 033: every run starts at N HP (clamped to 1..max; e.g. the greyed
##                              "need HP" choice of --run=event=ban_tho_mau) (memory store)
##   --run=shop                 Story 033: standing in an open SHOP at floor 2 (--at-floor overrides) with
##                              at least DEV_SHOP_GOLD gold (--gold wins); the region's shop node, or the
##                              current column's first node turned into a shop when the region has none
##   --run=event=<id>           Story 033: standing in EVENT <id> (an events.json id) at floor 2, same
##                              node rule as --run=shop
##   --run=gold_reward          Story 033: a won battle's reward screen (the "+N vàng" line shows)
##   --shape-removals=N         Story 034: every run starts with N shape-removal tokens (memory store)
##   --piece-deck-state=SPEC    Story 034: every run's piece deck starts as SPEC, "|"-separated parts:
##                              remove:id,id (PieceDeck.remove, min_shapes respected, refusals warn) /
##                              mult:id=N,id=N (mult set to N, clamped to 0..mult_max; a run-only id joins) /
##                              add:id,id (one ink each), e.g. remove:mono|mult:bar3=3|add:y5 (memory store)
##   --run=piece_deck           Story 034: the PIECE_DECK screen of a started run (first region's MAP) with
##                              DEV_PIECE_DECK_REMOVALS tokens and DEV_PIECE_DECK_STATE (mono removed, bar3
##                              at mult 3); --shape-removals / --piece-deck-state win
##   --run=ink_offer            Story 034: a won battle's reward screen with the ink row open (rolled like a
##                              treasure's when the chance missed)
##   --run=ink_offer_capped     Story 034: as --run=ink_offer, with the deck's first shape at mult_max so the
##                              offer can never show it (captures of the "capped" rule)
##   --run=fate                 Story 035: a floor-1 region boss downed (won through the dev win) and the run
##                              standing on the FATE screen (Tha / Giết), the controller alive (boss drawn)
##   --run=fate_resumed         Story 035: as --run=fate, then left and resumed from the save: FATE again,
##                              no controller, no replay
##   --run=fate_offer           Story 035: as --run=fate with "execute" chosen: the artifact offer open
##   --run=ending_spare|ending_balance|ending_execute
##                              Story 035: the final match won on a run whose boss_fates give that ending
##                              (all spared / alternating / all executed) with DEV_ENDING_MATCHES x
##                              DEV_ENDING_STATS in the run stats: the ENDING screen
##   --demo=boss_downed         Story 035 (DemoArgs): the first offered region's boss node, its boss downed
##   --demo=final_phase2        Story 035 (DemoArgs): the final match right after the phase-2 banner
##   --relics=id,id,...         Story 032: every run starts owning these relics (RelicRegistry ids; unknown
##                              ids and duplicates are dropped with a warning)
##   --character=<id>           pick the character like the select screen would (Story 018)
##   --select=character         start in CHARACTER_SELECT with a memory store (captures)
##   --run=world|world3|floorclear|final
##                              world map captures: floor 1 offer / floor 3 offer (2 floors walked on a
##                              seeded path) / floor 2 offer right after a region boss (the floor-clear
##                              notice waits; the boss ends at DEV_FLOORCLEAR_HP_RATIO x max HP so the
##                              heal is non-zero) / standing on the final floor's MAP at column 0 (TD-029:
##                              the `world.final_prelude` shop column, then the final boss column; without
##                              a prelude the boss column alone)
##   --run=relic_treasure       Story 032: the treasure offer with BOTH rows open (3 cards + 3 relics)
##   --run=map|map3|rest|treasure|miniboss_reward|boss_reward|reward|runover|runwon
##                              run states for captures (first offered region chosen): the fresh map /
##                              every column but the boss cleared / the REST screen / a treasure offer /
##                              the miniboss offer (floor 2 unless --at-floor) / the region boss offer /
##                              a battle offer / the RUN KẾT THÚC result / the RUN THẮNG result (final won)
##   --match=, --run=intro|between|won|lost, --demo=, --arena=  (RunController / DemoArgs args) also
##                              switch to a memory store and, without --node, start a run in the first
##                              offered region with the first node chosen (so a controller exists)

## Emitted after the phase changed; [param phase] is a [enum Phase] value.
signal phase_changed(phase: int)
## Emitted when the RunController was created (after add_child) or is about to be freed (null).
signal controller_changed(controller: RunController)
## Story 019: emitted when the run's screen-relevant state changed: an offer appeared or was
## resolved, a node was chosen or completed, the run ended (WON / LOST), a run was left or resumed.
## Views may also poll the getters.
signal run_changed()

## IN_FLOOR is the Story 019 name of IN_NODE, kept for old callers and tests (same value). WORLD_MAP
## (Story 031) took the slot of the retired CHAPTER_SELECT.
## PIECE_DECK (Story 034) is the piece deck screen opened over WORLD_MAP / MAP.
## FATE (Story 035): Tha / Giết after a downed REGION boss, then (Giết) its artifact offer; ENDING (Story 035):
## the ending screen after the final match.
## ACHIEVEMENTS (Story 037): the achievements screen opened from the title ([method open_achievements]).
## SETTINGS (Main Menu pass, user 2026-11-01): the settings screen opened from the title ([method open_settings]).
## SAVE_SLOTS (save slots, user 2026-11-07): the save slot screen opened from the title ([method open_save_slots]).
enum Phase { TITLE, CHARACTER_SELECT, WORLD_MAP, IN_NODE, MAP, REST, SHOP, EVENT, PIECE_DECK, FATE, ENDING, ACHIEVEMENTS, SETTINGS, SAVE_SLOTS, IN_FLOOR = IN_NODE }
## Story 019: how the live run ended; NONE while it is still going (or when there is none).
enum RunResult { NONE, WON, LOST }

## Deprecated alias of Phase.IN_NODE (Story 022).
const IN_FLOOR: int = Phase.IN_NODE

const PROGRESS_ARG: String = "--progress="
## DEV-ONLY (Story 022): --node=chX/cC/nN.
const NODE_ARG: String = "--node="
## DEV-ONLY (Story 023): legacy alias of [constant REGION_ARG].
const CHAPTER_ARG: String = "--chapter="
## DEV-ONLY (Story 031): --region=<id> opens a fresh run walking that region on its MAP (captures).
const REGION_ARG: String = "--region="
## DEV-ONLY (Story 031): --at-floor=N (1-based) starts the dev run at that floor.
const AT_FLOOR_ARG: String = "--at-floor="
## DEV-ONLY legacy (Story 015): --floor=chX/fY, now an alias of --node=chX/c0/n0.
const FLOOR_ARG: String = "--floor="
const SEED_ARG: String = "--seed="
const TITLE_ARG: String = "--title"
## DEV-ONLY (Story 018): --character=<id> picks the character like the select screen would.
const CHARACTER_ARG: String = "--character="
## DEV-ONLY (Story 021): --signature=<id> gives the character the signature block of whichever
## character owns that id (scratch/demo captures only).
const SIGNATURE_ARG: String = "--signature="
## DEV-ONLY (Story 032): --relics=id,id,... the run starts owning these relics.
const RELICS_ARG: String = "--relics="
## DEV-ONLY (Story 033): --gold=N, --deck+=id,id,...
const GOLD_ARG: String = "--gold="
const DECK_ADD_ARG: String = "--deck+="
const HP_ARG: String = "--hp="
## DEV-ONLY (Story 034): --shape-removals=N, --piece-deck-state=SPEC (see the class doc).
const SHAPE_REMOVALS_ARG: String = "--shape-removals="
const PIECE_DECK_STATE_ARG: String = "--piece-deck-state="
## Story 034: seed salt of the ink row roll (hash of run seed, floor, region, column, nodes cleared, this tag).
const INK_SEED_TAG: String = "ink"
## Story 034: node kinds whose reward gets an ink row with `ink_offer_chance`, and those that always get one.
const INK_CHANCE_KINDS: Array[String] = ["battle", "danger"]
const INK_ALWAYS_KINDS: Array[String] = ["treasure"]
## Story 032: seed salt of the treasure relic row (hash of run seed, floor, column, node, this tag).
const RELIC_SEED_TAG: String = "relic"
## Story 033: seed salt of a node's gold drop (hash of run seed, floor, column, node, this tag).
const GOLD_SEED_TAG: String = "gold"
## Story 032: relic source id of the treasure node (RelicRoller source_rules key).
const RELIC_SOURCE_TREASURE: String = "treasure"
## DEV-ONLY: locale override for captures (never saved).
const LANG_ARG: String = "--lang="
## DEV-ONLY (Story 018): --select=character starts in CHARACTER_SELECT (memory store; captures).
const SELECT_ARG: String = "--select="
const SELECT_CHARACTER: String = "character"
## DEV-ONLY (Story 037): --screen=achievements opens the achievements screen (memory store);
## --screen=achievements_demo also seeds a few earned achievements and milestones (never saved);
## --screen=achievements_detail=<id> opens that detail (AchievementsView reads it too);
## --screen=unlock_toast / --screen=character_locked=<id> are read by their views.
const SCREEN_ARG: String = "--screen="
const SCREEN_ACHIEVEMENTS: String = "achievements"
const SCREEN_ACHIEVEMENTS_DEMO: String = "achievements_demo"
const SCREEN_ACHIEVEMENTS_DETAIL: String = "achievements_detail="
## DEV-ONLY: --screen=settings opens the settings screen (captures).
const SCREEN_SETTINGS: String = "settings"
## DEV-ONLY (save slots): --screen=slots opens the save slot screen; --screen=slots_demo also fills the memory slots
## (slot 1: the --progress=demo run, slot 2: progress without a run, slot 3: empty) for the captures.
const SCREEN_SLOTS: String = "slots"
const SCREEN_SLOTS_DEMO: String = "slots_demo"
## DEV-ONLY: --screen=slots_demo_confirm = slots_demo with the slot 1 delete confirmation open; slots_demo_new = the
## NEW mode ("Chơi"); slots_demo_abandon = NEW mode with the slot 1 abandon confirmation open.
const SCREEN_SLOTS_DEMO_CONFIRM: String = "slots_demo_confirm"
const SCREEN_SLOTS_DEMO_NEW: String = "slots_demo_new"
const SCREEN_SLOTS_DEMO_ABANDON: String = "slots_demo_abandon"
## DEV-ONLY: every --screen= value that opens the filled demo slots.
const SCREEN_SLOTS_DEMOS: Array[String] = ["slots_demo", "slots_demo_confirm", "slots_demo_new", "slots_demo_abandon"]
## DEV-ONLY (--screen=slots_demo): the fake last-save time, play times and the slot 2 character of the demo slots.
const DEV_SLOTS_SAVED_AT: int = 1793000000
const DEV_SLOTS_PLAY_TIME: Array[float] = [5025.0, 12840.0]
const DEV_SLOTS_SECOND_CHARACTER: String = "phap_su"
## Save slots: the slot card's primary action by slot state and mode (see [method slot_primary_action]).
const SLOT_ACTION_CONTINUE: String = "continue"
const SLOT_ACTION_PLAY: String = "play"
const SLOT_ACTION_NEW: String = "new"
const SLOT_ACTION_REDO: String = "redo"
const SLOT_ACTION_ABANDON: String = "abandon"
## Save slots: the slot screen's mode — LOAD from the title's "Tiếp tục", NEW from "Chơi".
const SLOT_MODE_LOAD: String = "load"
const SLOT_MODE_NEW: String = "new"
## Save slots: the two confirmations (delete the slot's file / drop the slot's run for a new one).
const SLOT_CONFIRM_DELETE: String = "delete"
const SLOT_CONFIRM_ABANDON: String = "abandon"
## Milestones the demo seeds, as {key: count}; the achievements they earn come from UnlockRules.
const DEV_ACHIEVEMENTS_DEMO_MILESTONES: Dictionary = {"region_boss:ch1": 1, "kills_total": 2, "spares_total": 1, "runs_won": 1}
## DEV-ONLY (Story 019 / 022): --run=<kind> values handled HERE (the others belong to RunController).
const RUN_ARG: String = "--run="
const FLOW_RUN_REWARD: String = "reward"
const FLOW_RUN_OVER: String = "runover"
const FLOW_RUN_WON: String = "runwon"
const FLOW_RUN_MAP: String = "map"
const FLOW_RUN_MAP3: String = "map3"
const FLOW_RUN_REST: String = "rest"
const FLOW_RUN_TREASURE: String = "treasure"
## Story 032: treasure offer with the card row and the relic row open.
const FLOW_RUN_RELIC_TREASURE: String = "relic_treasure"
const FLOW_RUN_MINIBOSS_REWARD: String = "miniboss_reward"
const FLOW_RUN_BOSS_REWARD: String = "boss_reward"
## Story 031 world captures.
const FLOW_RUN_WORLD: String = "world"
const FLOW_RUN_WORLD3: String = "world3"
const FLOW_RUN_FLOORCLEAR: String = "floorclear"
const FLOW_RUN_FINAL: String = "final"
## Story 033 captures: an open shop, an open event (--run=event=<id>), a battle reward with its gold line.
const FLOW_RUN_SHOP: String = "shop"
const FLOW_RUN_EVENT: String = "event"
const FLOW_RUN_EVENT_PREFIX: String = "event="
const FLOW_RUN_GOLD_REWARD: String = "gold_reward"
## Story 034 captures: the piece deck screen, a battle reward with the ink row (optionally a capped shape).
const FLOW_RUN_PIECE_DECK: String = "piece_deck"
const FLOW_RUN_INK_OFFER: String = "ink_offer"
const FLOW_RUN_INK_OFFER_CAPPED: String = "ink_offer_capped"
## Story 035 captures: the FATE screen (live / resumed), the execute offer, the three endings.
const FLOW_RUN_FATE: String = "fate"
const FLOW_RUN_FATE_RESUMED: String = "fate_resumed"
const FLOW_RUN_FATE_OFFER: String = "fate_offer"
const FLOW_RUN_ENDING_SPARE: String = "ending_spare"
const FLOW_RUN_ENDING_BALANCE: String = "ending_balance"
const FLOW_RUN_ENDING_EXECUTE: String = "ending_execute"
## DEV-ONLY (--run=ending_*): matches added to the run stats, and the numbers of each.
const DEV_ENDING_MATCHES: int = 12
const DEV_ENDING_STATS: Dictionary = {"damage_dealt": 640.0, "damage_taken": 85.0, "hits_taken": 4, "casts": 21,
	"joins": 6, "featured_casts": 3, "signatures_used": 2}
## Story 041: the progress seen_unlocks entry ("hint:odd_block") of the first-pickup Odd Block hint.
const ODD_HINT_KIND: String = "hint"
const ODD_HINT_ID: String = "odd_block"
## DEV-ONLY: the --demo= args GameFlow stages a match for (DemoArgs does the rest).
const DEMO_BOSS_DOWNED_ARG: String = "--demo=boss_downed"
const DEMO_FINAL_PHASE2_ARG: String = "--demo=final_phase2"
const DEV_DEMO_STAGE_FINAL: String = "final"
## Story 035: seed tag of the execute artifact offer.
const FATE_SEED_TAG: String = "fate"
## Story 035: lines of an ending (keys ending.<id>.line1..N in strings.csv).
const ENDING_LINE_COUNT: int = 4
## DEV-ONLY: tokens and deck --run=piece_deck sets up without --shape-removals / --piece-deck-state.
const DEV_PIECE_DECK_REMOVALS: int = 2
const DEV_PIECE_DECK_STATE: String = "remove:mono|mult:bar3=3"
## DEV-ONLY: 0-based floor --run=shop / --run=event=<id> start at without --at-floor (floor 2).
const DEV_SPECIAL_FLOOR: int = 1
## DEV-ONLY: gold --run=shop guarantees without --gold (enough for a relic and a service).
const DEV_SHOP_GOLD: int = 300
## --run= kinds that must NOT auto-pick a region (they stage the world map themselves).
const FLOW_RUN_WORLD_KINDS: Array[String] = [FLOW_RUN_WORLD, FLOW_RUN_WORLD3, FLOW_RUN_FLOORCLEAR, FLOW_RUN_FINAL]
const FLOW_RUN_KINDS: Array[String] = [
	FLOW_RUN_REWARD, FLOW_RUN_OVER, FLOW_RUN_WON, FLOW_RUN_MAP, FLOW_RUN_MAP3, FLOW_RUN_REST,
	FLOW_RUN_TREASURE, FLOW_RUN_MINIBOSS_REWARD, FLOW_RUN_BOSS_REWARD, FLOW_RUN_RELIC_TREASURE,
	FLOW_RUN_WORLD, FLOW_RUN_WORLD3, FLOW_RUN_FLOORCLEAR, FLOW_RUN_FINAL, FLOW_RUN_SHOP, FLOW_RUN_GOLD_REWARD,
	FLOW_RUN_PIECE_DECK, FLOW_RUN_INK_OFFER, FLOW_RUN_INK_OFFER_CAPPED,
	FLOW_RUN_FATE, FLOW_RUN_FATE_RESUMED, FLOW_RUN_FATE_OFFER,
	FLOW_RUN_ENDING_SPARE, FLOW_RUN_ENDING_BALANCE, FLOW_RUN_ENDING_EXECUTE,
]
## DEV-ONLY: columns --run=map3 clears (capped before the region's boss column).
const DEV_MAP3_COLUMNS: int = 2
## DEV-ONLY: 0-based floor --run=world3 shows (floor 3).
const DEV_WORLD3_FLOOR: int = 2
## DEV-ONLY: 0-based floor --run=miniboss_reward starts at without --at-floor (miniboss min_floor 2).
const DEV_MINIBOSS_FLOOR: int = 1
## DEV-ONLY: _dev_start region marker "pick the first offered region".
const DEV_FIRST_OFFERED: String = "*"
## DEV-ONLY: step cap of the dev floor walk (defensive against bad data).
const DEV_WALK_GUARD: int = 200
## DEV-ONLY: player HP the --run=*reward / --run=runwon captures end the match with (70 % of 300).
const DEV_FLOW_HP: float = 210.0
## Locales the CSV ships (Story 017); the title button cycles through them in this order.
const SUPPORTED_LOCALES: Array[String] = ["en", "vi"]
## DEV-ONLY: disables the auto-pause on focus loss (windowed scratch tests run unfocused).
const NO_AUTOPAUSE_ARG: String = "--no-autopause"
## Platforms without a Quit button (Apple rules): [method can_show_quit] is false there.
const NO_QUIT_OS_NAMES: Array[String] = ["iOS"]
## Legacy --floor suffix (Story 015); accepted and ignored.
const RESUME_SUFFIX: String = ":resume"
const PROGRESS_NONE: String = "none"
const PROGRESS_ALL: String = "all"
const PROGRESS_DEMO: String = "demo"
## DEV-ONLY (Story 031): --progress=v4save loads a genuine v4 progress file (restart notice capture).
const PROGRESS_V4SAVE: String = "v4save"
## DEV-ONLY (Story 038): --progress=kiep3 = Kiem si won Kiep 2 and has Kiep 3 open (in-memory save, for captures);
## --kiep=N starts the next run at Kiep N whatever is unlocked.
const PROGRESS_KIEP3: String = "kiep3"
const KIEP_ARG: String = "--kiep="
const DEV_KIEP3_CHARACTER: String = "kiem_si"
const DEV_KIEP3_WON_LEVELS: Array[int] = [1, 2]
## DEV-ONLY: the v4 run of --progress=v4save (chapter, column, HP, seed).
const DEV_V4_CHAPTER: String = "ch2"
const DEV_V4_COLUMN: int = 3
const DEV_V4_HP: float = 150.0
## DEV-ONLY: share of max HP the region boss of --run=floorclear ends with (banner shows a real heal).
const DEV_FLOORCLEAR_HP_RATIO: float = 0.6
## Dev args that put the game into a capture state; they always get a memory store.
const DEV_RUN_ARGS: Array[String] = ["--match=", "--run=", "--demo=", "--arena=", "--pattern="]
const CONTROLLER_NODE: String = "RunController"
## DEV-ONLY (--progress=demo): the saved demo run (0-based floor DEMO_RUN_FLOOR, this many columns of
## its region cleared, never the boss column).
const DEMO_RUN_FLOOR: int = 1
const DEMO_RUN_COLUMN: int = 1
const DEMO_RUN_HP: float = 171.0
const DEMO_RUN_SEED: int = 7
## Deprecated (Story 022): value of [method get_current_floor] outside a run.
const NO_FLOOR: Vector2i = Vector2i(-1, -1)
## One-line notice shown once when a pre-v5 save restarted as a new world run (Story 022 / 031).
const TEXT_RESTART_OLD_SAVE: String = "run.restart.old_save"
## Node kinds that play a match (the others never spawn a controller).
const MATCH_NODE_KINDS: Array[String] = ["battle", "danger", "miniboss", "boss"]
const KIND_TREASURE: String = "treasure"
const KIND_REST: String = "rest"
const KIND_BOSS: String = "boss"
const KIND_SHOP: String = ChapterMapGen.KIND_SHOP
const KIND_EVENT: String = ChapterMapGen.KIND_EVENT
const KIND_BATTLE: String = "battle"
## Story 033: seed salt of the extra match drawn for an event `fight`.
const EVENT_FIGHT_SEED_TAG: String = "event_fight"
## Story 033: keys of RunSession.event_state (the "used" list lives for the whole run; the others belong
## to the event node being visited and are dropped when it is left).
const EVENT_USED: String = "used"
const EVENT_NODE: String = "node_key"
const EVENT_ID: String = "event_id"
const EVENT_CHOICE: String = "choice"
const EVENT_RESULT: String = "result"
const EVENT_FIGHT: String = "fight"
const EVENT_FIGHT_ACTIVE: String = "fight_active"
## Story 033: refusal key of a second [method event_choose] at the same event.
const TEXT_EVENT_ALREADY_CHOSEN: String = "ui.event.already_chosen"
## Story 033: key of RunSession.shop_state tagging the node the stock belongs to.
const SHOP_NODE: String = "node_key"

var _config: ChaptersConfig
var _store: ProgressStore = null
var _progress: ProgressState
## Save slots (2026-11-07): the slot files, the machine settings (locale, last slot) and the active slot (0-based).
## Real files only without dev args and test hooks; otherwise memory slots and memory settings.
var _slots: SaveSlots = null
var _settings: SettingsStore = null
var _slot_index: int = 0
## Save slots: the slot screen's mode and the open confirmation ({} or {index, kind}).
var _slot_mode: String = SLOT_MODE_LOAD
var _slot_confirm: Dictionary = {}
## Story 037: achievement ids earned since the last [method take_new_unlocks] (the "Moi mo" toast queue).
var _new_unlocks: Array[String] = []
## Story 037: CombatView.get_match_stats() of the match just won (read by [method _complete_match_node]).
var _last_match_stats: Dictionary = {}
var _phase: Phase = Phase.TITLE
var _controller: RunController = null
var _dev_seed: int = -1
## DEV-ONLY: true with --no-autopause (see [constant NO_AUTOPAUSE_ARG]).
var _no_autopause: bool = false
## Locale in use (always one of SUPPORTED_LOCALES).
var _locale: String = ProgressState.DEFAULT_LOCALE
## DEV-ONLY: --lang= value ("" = use the save).
var _dev_locale: String = ""
## Selected character id (Story 018). Set by [method set_character] (the select screen, --character=,
## or the saved run on continue). Empty = none chosen yet: [method start_run] then falls back to
## CharacterConfig.default_id(), so a run is never character-less — only [method enter_test_floor]
## passes {} (plain combat.json numbers for the old tests).
var _character_id: String = ""
var _characters: CharacterConfig = null
var _cards: SkillConfig = null
var _reward_config: Dictionary = {}
## DEV-ONLY: --character= value, applied in _ready.
var _dev_character: String = ""
## Story 038: the Kiep level picked for the NEXT run (-1 = not picked: the selected character's unlocked level);
## reset to -1 whenever the selected character changes. DEV --kiep=N (-1 = none) bypasses the lock.
var _kiep_level: int = -1
var _dev_kiep: int = -1
## DEV-ONLY: --signature= value.
var _dev_signature: String = ""
## DEV-ONLY (Story 032): --relics= ids, given to every run started by _begin_run.
var _dev_relics: Array[String] = []
## Story 019: the live run; null outside a run (title, menus, test floors).
var _run: RunSession = null
var _run_result: RunResult = RunResult.NONE
## Story 019: true while a resumed match is held in INTRO until its saved offer is resolved (only
## reachable from a save that has both a match node chosen and an offer open; defensive).
var _reward_blocking: bool = false
## Run clock at the entry of the current node (the controller's RunState clock starts at 0).
var _elapsed_base: float = 0.0
## Story 022: kind of the node whose offer is open ("" when none).
var _pending_node_kind: String = ""
## Story 022: translated restart notice waiting for [method take_restart_notice] ("" when none).
var _restart_notice: String = ""
## Story 031: floor-clear notice waiting for [method take_floor_clear_notice] ({} when none).
var _floor_clear_notice: Dictionary = {}
## Story 033: gold dropped by the node completed last (see [method get_last_gold_gain]).
var _last_gold_gain: int = 0
## Story 038: the Kiep level the last finished run newly opened (0 = none), see [method get_kiep_new_unlock].
var _last_kiep_unlock: int = 0
## DEV-ONLY (Story 033): --gold= value (-1 = none), --deck+= ids, the event id of --run=event=<id>.
var _dev_gold: int = -1
## DEV-ONLY (Story 033): --hp= value (-1 = full).
var _dev_hp: float = -1.0
var _dev_deck_add: Array[String] = []
var _dev_event_id: String = ""
## DEV-ONLY (Story 034): --shape-removals= value (-1 = none), --piece-deck-state= spec ("" = none).
var _dev_shape_removals: int = -1
var _dev_piece_deck_state: String = ""
## Story 035: the ending screen's data ([method get_ending]); {} until a final match is won.
var _ending: Dictionary = {}
## Story 035: the stats summary of the last lost run ([method get_defeat_summary]); kept after the run is dropped.
var _defeat_summary: Dictionary = {}
## Story 035: match id of the live controller's match (death record).
var _live_match_id: String = ""
## DEV-ONLY (Story 035): the match a --demo=boss_downed / final_phase2 boot stages ("" = first node).
var _dev_demo_stage: String = ""
## Story 034: the phase [method close_piece_deck] returns to (WORLD_MAP or MAP).
var _piece_deck_return: Phase = Phase.MAP


## Test hook: installs the store BEFORE the node enters the tree (wins over --progress args).
func set_store_for_test(store: ProgressStore) -> void:
	_store = store


## Test hook (save slots): installs the slots (and optionally the settings; memory settings otherwise) BEFORE the
## node enters the tree; the active slot is the settings' last slot. Wins over --progress args.
func set_slots_for_test(slots: SaveSlots, settings: SettingsStore = null) -> void:
	_slots = slots
	_settings = settings


## Test hook (scratch flow tests): runs an ad-hoc single-floor RunConfig (the flat format read
## by RunConfig.load_from_file) as a throwaway match outside any run. No progress is written and no
## run exists (the run callbacks return early); the floor label is empty; the store installed by
## [method set_store_for_test] (or the real one) is left untouched.
func enter_test_floor(run_config: RunConfig) -> RunController:
	_free_controller()
	_run = null
	_run_result = RunResult.NONE
	_reward_blocking = false
	_pending_node_kind = ""
	var controller := RunController.new()
	controller.name = CONTROLLER_NODE
	controller.character = _character_dict()
	controller.configure(run_config, 0, -1.0)
	controller.match_started.connect(_on_match_started)
	controller.phase_changed.connect(_on_run_phase_changed)
	_controller = controller
	add_child(controller)
	_set_phase(Phase.IN_NODE)
	controller_changed.emit(controller)
	return controller


func _ready() -> void:
	_config = ChaptersConfig.load_from_file()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var progress_mode: String = ""
	var node_text: String = ""
	var region_text: String = ""
	var at_floor: int = 0
	var dev_run: bool = false
	var flow_run: String = ""
	var force_title: bool = false
	var select_mode: String = ""
	var screen_mode: String = ""
	for arg: String in args:
		if arg == TITLE_ARG:
			force_title = true
		elif arg.begins_with(SELECT_ARG):
			select_mode = arg.trim_prefix(SELECT_ARG)
		elif arg.begins_with(SCREEN_ARG):
			screen_mode = arg.trim_prefix(SCREEN_ARG)
		elif arg == NO_AUTOPAUSE_ARG:
			_no_autopause = true
		elif arg.begins_with(PROGRESS_ARG):
			progress_mode = arg.trim_prefix(PROGRESS_ARG)
		elif arg.begins_with(NODE_ARG):
			node_text = arg.trim_prefix(NODE_ARG)
		elif arg.begins_with(REGION_ARG):
			region_text = arg.trim_prefix(REGION_ARG)
		elif arg.begins_with(CHAPTER_ARG):
			region_text = arg.trim_prefix(CHAPTER_ARG)
		elif arg.begins_with(AT_FLOOR_ARG):
			at_floor = maxi(int(arg.trim_prefix(AT_FLOOR_ARG)), 1)
		elif arg.begins_with(FLOOR_ARG):
			var floor_text: String = arg.trim_prefix(FLOOR_ARG).trim_suffix(RESUME_SUFFIX)
			node_text = "f1/%s/c0/n0" % floor_text.get_slice("/", 0)
			push_warning("GameFlow: --floor=%s is deprecated (Story 022), using --node=%s" % [floor_text, node_text])
		elif arg.begins_with(SEED_ARG):
			_dev_seed = int(arg.trim_prefix(SEED_ARG)) & ChaptersConfig.SEED_MASK
		elif arg.begins_with(LANG_ARG):
			_dev_locale = arg.trim_prefix(LANG_ARG)
		elif arg.begins_with(CHARACTER_ARG):
			_dev_character = arg.trim_prefix(CHARACTER_ARG)
		elif arg.begins_with(KIEP_ARG):
			_dev_kiep = clampi(int(arg.trim_prefix(KIEP_ARG)), 0, KiepRules.shared().max_level())
		elif arg.begins_with(SIGNATURE_ARG):
			_dev_signature = arg.trim_prefix(SIGNATURE_ARG)
		elif arg.begins_with(RELICS_ARG):
			for rid: String in arg.trim_prefix(RELICS_ARG).split(",", false):
				_dev_relics.append(rid.strip_edges())
		elif arg.begins_with(GOLD_ARG):
			_dev_gold = maxi(int(arg.trim_prefix(GOLD_ARG)), 0)
		elif arg.begins_with(HP_ARG):
			_dev_hp = maxf(float(arg.trim_prefix(HP_ARG)), 1.0)
		elif arg.begins_with(SHAPE_REMOVALS_ARG):
			_dev_shape_removals = maxi(int(arg.trim_prefix(SHAPE_REMOVALS_ARG)), 0)
		elif arg.begins_with(PIECE_DECK_STATE_ARG):
			_dev_piece_deck_state = arg.trim_prefix(PIECE_DECK_STATE_ARG)
		elif arg.begins_with(DECK_ADD_ARG):
			for cid: String in arg.trim_prefix(DECK_ADD_ARG).split(",", false):
				_dev_deck_add.append(cid.strip_edges())
		else:
			if arg.begins_with(RUN_ARG) and FLOW_RUN_KINDS.has(arg.trim_prefix(RUN_ARG)):
				flow_run = arg.trim_prefix(RUN_ARG)
			elif arg.begins_with(RUN_ARG + FLOW_RUN_EVENT_PREFIX):
				flow_run = FLOW_RUN_EVENT
				_dev_event_id = arg.trim_prefix(RUN_ARG + FLOW_RUN_EVENT_PREFIX)
			if arg == DEMO_BOSS_DOWNED_ARG:
				_dev_demo_stage = KIND_BOSS
			elif arg == DEMO_FINAL_PHASE2_ARG:
				_dev_demo_stage = DEV_DEMO_STAGE_FINAL
			for prefix: String in DEV_RUN_ARGS:
				if arg.begins_with(prefix):
					dev_run = true
	if not select_mode.is_empty() and select_mode != SELECT_CHARACTER:
		push_warning("GameFlow: unknown --select=%s (character), ignored" % select_mode)
		select_mode = ""
	var dev_world: bool = dev_run or not node_text.is_empty() or not region_text.is_empty() or at_floor > 0
	var dev_memory: bool = (dev_world or not select_mode.is_empty() or not screen_mode.is_empty() or _dev_gold >= 0
		or not _dev_deck_add.is_empty() or _dev_hp > 0.0 or _dev_shape_removals >= 0
		or not _dev_piece_deck_state.is_empty() or not progress_mode.is_empty())
	_setup_slots(dev_memory)
	_progress = _load_progress(progress_mode)
	if SCREEN_SLOTS_DEMOS.has(screen_mode):
		_dev_fill_demo_slots()
	# Locale before anything draws or caches a translated name.
	_apply_locale(_dev_locale if SUPPORTED_LOCALES.has(_dev_locale) else _settings.get_locale())
	if not _dev_character.is_empty():
		set_character(_dev_character)
	# Start phase: TITLE without dev args (or with --title); --progress alone -> CHARACTER_SELECT;
	# --select=character -> CHARACTER_SELECT.
	_phase = Phase.TITLE
	if select_mode == SELECT_CHARACTER or (not progress_mode.is_empty() and not force_title and progress_mode != PROGRESS_V4SAVE):
		_phase = Phase.CHARACTER_SELECT
	if screen_mode == SCREEN_SETTINGS:
		_phase = Phase.SETTINGS
	if screen_mode == SCREEN_SLOTS or SCREEN_SLOTS_DEMOS.has(screen_mode):
		_phase = Phase.SAVE_SLOTS
		if screen_mode == SCREEN_SLOTS_DEMO_NEW or screen_mode == SCREEN_SLOTS_DEMO_ABANDON:
			_slot_mode = SLOT_MODE_NEW
		if screen_mode == SCREEN_SLOTS_DEMO_CONFIRM:
			_slot_confirm = {"index": 0, "kind": SLOT_CONFIRM_DELETE}
		elif screen_mode == SCREEN_SLOTS_DEMO_ABANDON:
			_slot_confirm = {"index": 0, "kind": SLOT_CONFIRM_ABANDON}
	if screen_mode.begins_with(SCREEN_ACHIEVEMENTS):
		_phase = Phase.ACHIEVEMENTS
		if screen_mode == SCREEN_ACHIEVEMENTS_DEMO:
			_dev_seed_achievements_demo()
	if not node_text.is_empty():
		_apply_dev_node(node_text)
	elif not region_text.is_empty():
		_dev_start(maxi(at_floor, 1) - 1, region_text)
	elif dev_world:
		var start_floor: int = at_floor - 1
		if start_floor < 0:
			start_floor = DEV_MINIBOSS_FLOOR if flow_run == FLOW_RUN_MINIBOSS_REWARD else 0
			if flow_run == FLOW_RUN_SHOP or flow_run == FLOW_RUN_EVENT:
				start_floor = DEV_SPECIAL_FLOOR
		var world_only: bool = FLOW_RUN_WORLD_KINDS.has(flow_run) or (at_floor > 0 and not dev_run)
		_dev_start(start_floor, "" if world_only else DEV_FIRST_OFFERED)
		if dev_run and flow_run.is_empty() and _run != null:
			# A RunController / DemoArgs arg: it needs a controller, so the first node is taken
			# (Story 035 demos: the region's boss node / the final match).
			if _dev_demo_stage == KIND_BOSS:
				_dev_advance_to_kind(KIND_BOSS)
			elif _dev_demo_stage == DEV_DEMO_STAGE_FINAL:
				_dev_advance_floors(_run.floors())
				# TD-029: past the `world.final_prelude` columns to the final boss node.
				_dev_advance_to_kind(KIND_BOSS)
			else:
				_dev_choose_first_available()
	if _dev_hp > 0.0 and _run != null and _controller == null:
		# Again after the dev floor walk (a region boss heals).
		_run.hp = minf(_dev_hp, _character_max_hp(_character_dict()))
	if not flow_run.is_empty() and _run != null:
		_apply_dev_flow_run(flow_run)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			go_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if _phase == Phase.IN_NODE and _controller != null and not _no_autopause:
				_controller.set_paused(true, true)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		go_back()


## Story 018: the character list (loaded once, lazily).
func get_characters() -> CharacterConfig:
	if _characters == null:
		_characters = CharacterConfig.load_from_file()
		# Story 037: a character with `unlock_by` is open when that achievement is earned (live progress).
		_characters.set_unlock_source(func(character_id: String) -> bool:
			return _progress == null or AchievementsConfig.shared().is_unlocked("character", character_id, _progress))
	return _characters


## Story 019: the card list (cards.json; loaded once, lazily). Reward pool and save validation.
func get_cards() -> SkillConfig:
	if _cards == null:
		_cards = SkillConfig.load_from_file()
	return _cards


## Story 019 / 022: the validated rewards.json dictionary (offer_count, rarity weights and luck
## anchors, allow_skip, allow_remove, min_deck_size, max_card_level, starting_removals, luck_*,
## rest_heal_ratio, rest_forge_levels, node_rewards); loaded once, lazily. Returned as a copy.
func get_reward_config() -> Dictionary:
	if _reward_config.is_empty():
		_reward_config = RewardRoller.load_config()
	return _reward_config.duplicate(true)


## Story 018: selects the character for the next run. Unknown id: warning, selection unchanged.
## An empty id clears the selection (back to the plain, character-less test floor).
func set_character(id: String) -> void:
	if id.is_empty():
		_character_id = ""
		_kiep_level = -1
		return
	if not get_characters().has(id):
		push_warning("GameFlow: unknown character '%s' (known: %s), ignored" % [id, ", ".join(get_characters().ids())])
		return
	if id != _character_id:
		_kiep_level = -1
	_character_id = id


## Story 018: the selected character id; "" when none was chosen.
func get_character_id() -> String:
	return _character_id


## Story 038: the highest Kiep level the character [param character_id] may start (0 when none / unknown).
func kiep_unlocked_for(character_id: String) -> int:
	if _progress == null or character_id.is_empty():
		return 0
	return _progress.get_kiep_unlocked(character_id)


## Story 038: the highest Kiep level the character won (-1 = never won a run).
func kiep_best_for(character_id: String) -> int:
	if _progress == null or character_id.is_empty():
		return -1
	return _progress.get_kiep_best_won(character_id)


## Story 038: the Kiep level of the NEXT run: the picked one, else the selected (or default) character's unlocked level.
func get_kiep_level() -> int:
	if _kiep_level >= 0:
		return _kiep_level
	if _dev_kiep >= 0:
		return _dev_kiep
	return kiep_unlocked_for(_kiep_character_id())


## Story 038: picks the Kiep level of the next run. False (selection unchanged) when it is above the selected
## character's unlocked level or outside 0..max (the dev --kiep=N flag bypasses the lock).
func set_kiep_level(level: int) -> bool:
	if level < 0 or level > KiepRules.shared().max_level():
		return false
	if _dev_kiep < 0 and level > kiep_unlocked_for(_kiep_character_id()):
		return false
	_kiep_level = level
	return true


## Story 038: the desc keys of the rules active at [param level] (levels 1..level, in order).
func get_kiep_rules_keys(level: int) -> Array[String]:
	return KiepRules.shared().rules_text_keys(level)


# Story 038: [param summary] (RunSession.stats_summary shape) with the run's Kiep level, for the ending / defeat stats.
func _stats_with_kiep(summary: Dictionary) -> Dictionary:
	if not summary.has("kiep_level"):
		summary["kiep_level"] = get_run_kiep_level()
	return summary


## Story 038: the Kiep level of the live run (0 outside a run).
func get_run_kiep_level() -> int:
	if _run == null:
		return 0
	return int(_run.get("kiep_level"))


# The selected character, or the default one when none was chosen yet (the select screen's focus).
func _kiep_character_id() -> String:
	return _character_id if not _character_id.is_empty() else get_characters().default_id()


# The selected character's dictionary for the controller; {} when none was chosen.
func _character_dict() -> Dictionary:
	if _character_id.is_empty():
		return {}
	var character: Dictionary = get_characters().get_character(_character_id)
	if not _dev_signature.is_empty():
		for other: String in get_characters().ids():
			var raw: Variant = get_characters().get_character(other).get("signature")
			if raw is Dictionary and str((raw as Dictionary).get("id", "")) == _dev_signature:
				character = character.duplicate(true)
				character["signature"] = raw
				break
	# Story 038 (Kiep 8): the ONE point where the run's max HP changes; the HUD, rest, events and matches all read this dict.
	var kiep: int = get_run_kiep_level()
	if kiep > 0:
		if not character.has("max_hp"):
			character = character.duplicate(true)
			character["max_hp"] = _character_max_hp(character)
		character = KiepRules.shared().apply_run_start(character, kiep)
	return character


## Current [enum Phase].
func get_phase() -> int:
	return _phase


## The chapters data.
func get_config() -> ChaptersConfig:
	return _config


## Story 037: the ids of the achievements earned since the last call (earned order), then forgets them: the
## "Moi mo" toast asks once per showing (after a region boss node's flow, on the ending / defeat screens).
## Content is shown with AchievementsConfig.rewards_of(ids).
func take_new_unlocks() -> Array[String]:
	var out: Array[String] = _new_unlocks.duplicate()
	_new_unlocks.clear()
	return out


# Story 037: evaluates the achievements against the progress (milestones already written by the caller) and
# [param event], queues the new ones for [method take_new_unlocks]. The caller saves right after.
func _process_unlocks(event: Dictionary) -> void:
	if _progress == null:
		return
	for id: String in UnlockRules.process(AchievementsConfig.shared(), _progress, event):
		if not _new_unlocks.has(id):
			_new_unlocks.append(id)


# Story 037: the `match_won` event of the match just won (see UnlockRules).
func _match_won_event(is_region_boss: bool, is_final: bool) -> Dictionary:
	return {"type": UnlockRules.EVENT_MATCH_WON, "character_id": _run.character_id, "region_id": _run.region_id,
		"is_region_boss": is_region_boss, "is_final": is_final, "match_stats": _last_match_stats.duplicate(),
		"run_stats": _run.stats.duplicate(true), "deck_ids": _run.deck_ids}


# Story 037: the `run_ended` event (win: ending id of the boss fates; loss: "").
func _run_ended_event(won: bool, ending_id: String) -> Dictionary:
	return {"type": UnlockRules.EVENT_RUN_ENDED, "won": won, "ending_id": ending_id, "character_id": _run.character_id,
		"run_stats": _run.stats.duplicate(true), "deck_ids": _run.deck_ids}


## The saved progress (live object; GameFlow writes it through the store).
func get_progress() -> ProgressState:
	return _progress


## The controller of the node being played; null outside IN_NODE.
func get_controller() -> RunController:
	return _controller


## Deprecated (Story 022; use [method get_current_column]): (chapter, column) of the live run while
## it is on the map, in a node or at a rest; [constant NO_FLOOR] otherwise (title, menus, test floors).
func get_current_floor() -> Vector2i:
	if _run == null or not [Phase.IN_NODE, Phase.MAP, Phase.REST, Phase.SHOP, Phase.EVENT, Phase.PIECE_DECK].has(_phase):
		return NO_FLOOR
	return Vector2i(_run.chapter_index, _run.column)


## Deprecated (Story 022): the run seed (arena seeds derive from it per node); 0 without a run.
func get_floor_seed() -> int:
	return 0 if _run == null else _run.run_seed


## Story 019: the live run (also after it ended, until [method leave_run]); null when none.
func get_run() -> RunSession:
	return _run


## Story 019: how the live run ended; NONE while it is going or when there is no run.
func get_run_result() -> int:
	return _run_result


## Story 022: the run's chapter map (deep copy): columns {index, tier, nodes [{kind, match_id}]};
## [] without a run.
func get_run_map() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _run == null:
		return out
	for column: Dictionary in _run.map:
		out.append(column.duplicate(true))
	return out


## Story 022: index of the column the run is at (== column count once the boss fell); -1 without a run.
func get_current_column() -> int:
	return -1 if _run == null else _run.column


## Story 022: nodes of the current column that can still be chosen, each with its "node_index"
## (the argument of [method choose_node]); [] without a run or past the last column.
func get_available_nodes() -> Array[Dictionary]:
	if _run == null:
		return []
	return _run.available_nodes()


## Story 022: the nodes already passed, {column, node_index, kind} each; [] without a run.
func get_cleared_nodes() -> Array:
	if _run == null:
		return []
	return _run.cleared_nodes.duplicate(true)


## Story 033: gold of the live run (0 without a run).
func get_gold() -> int:
	return 0 if _run == null else _run.gold


## Story 033: the active run modifiers' config overrides (RunSession.run_modifier_overrides: key -> {add, mul[,
## set]}); RunController puts them in match_params["run_modifiers"]. {} without a run or modifier.
func get_run_modifier_overrides() -> Dictionary:
	return {} if _run == null else _run.run_modifier_overrides()


## Story 033: readout for the reward screen: the gold the last won node dropped ("+N vàng"; 0 before any and
## for a node that drops none). Saved with the run (RunSession.last_gold_gain), so a resumed reward screen
## shows the same amount.
func get_last_gold_gain() -> int:
	return _last_gold_gain


## Story 022: removal tokens of the live run (the reward view shows "Bỏ 1 lá" only above 0).
func get_removal_tokens() -> int:
	return 0 if _run == null else _run.removal_tokens


## Story 022: the run's luck (luck_start + luck_per_node x nodes cleared); 0 without a run.
func get_luck() -> float:
	return 0.0 if _run == null else _run.luck(get_reward_config())


## Story 019: card ids of the offer waiting for [method reward_chosen] / [method reward_skipped];
## [] when none.
func get_pending_reward() -> Array[String]:
	if _run == null:
		return []
	return _run.pending_reward.duplicate()


## Story 022: kind of the node the open offer belongs to (battle, danger, treasure, miniboss,
## boss); "" when no offer is open.
func get_pending_reward_kind() -> String:
	if _run == null or not _run.has_pending_reward():
		return ""
	return _pending_node_kind


## Story 022: the reward rule of the open offer (RewardRoller.reward_for_node: offers, min_rarity,
## free, removal_token); {} when no offer is open.
func get_pending_reward_info() -> Dictionary:
	var kind: String = get_pending_reward_kind()
	if kind.is_empty():
		return {}
	return RewardRoller.reward_for_node(kind, get_reward_config())


## Story 019: true while a resumed run holds its match in INTRO until the saved offer is resolved.
func is_reward_blocking() -> bool:
	return _reward_blocking


## Story 022: the restart notice of a pre-v4 save, returned ONCE (then ""); "" when there is none.
func take_restart_notice() -> String:
	var notice: String = _restart_notice
	_restart_notice = ""
	return notice


## Story 031: the WORLD_MAP card of [param region_id] at the current floor: {region_id, name
## (translated), desc_key ("region.<id>.desc"; views tr() it and fall back to intro_key when the key is
## missing), intro_key (the chapter's intro line, may be ""), boss_name (translated names of the
## region's boss pool, " / "-joined), floor (0-based), floor_number (1-based), floor_scaling {hp_mult,
## step_mult, defense_add, size_add} of the floor}. {} for an unknown region.
func region_preview(region_id: String) -> Dictionary:
	var ci: int = _config.region_index(region_id)
	if ci < 0:
		return {}
	var at: int = get_floor()
	var spec: Dictionary = _config.region_spec(region_id, at, get_run_kiep_level())
	var names: Array[String] = []
	var boss_pool: Variant = (spec.get("pools", {}) as Dictionary).get(KIND_BOSS, {})
	var boss_ids: Array = []
	if boss_pool is Dictionary:
		for tier: Variant in (boss_pool as Dictionary).keys():
			var ids: Variant = (boss_pool as Dictionary)[tier]
			if ids is Array:
				boss_ids.append_array(ids as Array)
	elif boss_pool is Array:
		boss_ids = boss_pool as Array
	for id: Variant in boss_ids:
		var raw: Dictionary = _config.get_match_raw(ci, str(id))
		var key: String = str(raw.get("name_key", raw.get("name", str(id))))
		var shown: String = tr(key)
		if not names.has(shown):
			names.append(shown)
	return {
		"region_id": region_id, "name": region_name(region_id), "desc_key": "region.%s.desc" % region_id,
		"intro_key": _config.chapter_text_key(ci, "intro"), "boss_name": " / ".join(names),
		"floor": at, "floor_number": at + 1, "floor_scaling": _config.floor_scaling(at),
	}


## Story 031: starts a fresh WORLD run of the selected character (floor 1, the floor's region offer
## rolled, full HP, starter deck, starting removal tokens; any saved run is replaced — confirming that
## is the view's job) and shows the WORLD_MAP. With no character chosen the default one is used.
## [param _legacy_chapter] is ignored (chapters no longer start runs; kept for old callers).
func start_run(_legacy_chapter: int = -1) -> void:
	_begin_run()


## Story 022: the map view picked node [param node_index] of the current column. Battle / danger /
## miniboss / boss spawn the node's controller (phase IN_NODE); treasure opens its free offer at
## once (phase stays MAP); rest shows the REST screen; Story 033: shop opens SHOP, event opens EVENT
## (see the class doc). The run is saved. False with a warning
## outside MAP, without a run, or when RunSession.choose_node refuses (bad index, cleared node).
func choose_node(node_index: int) -> bool:
	if _run == null or _phase != Phase.MAP or _run_result != RunResult.NONE:
		push_warning("GameFlow: choose_node(%d) outside the map, ignored" % node_index)
		return false
	if not _run.choose_node(node_index):
		push_warning("GameFlow: choose_node(%d): no such node in column %d" % [node_index, _run.column])
		return false
	var kind: String = str(_run.current_node().get("kind", ""))
	if kind == KIND_TREASURE:
		_drop_gold(kind)
		_offer_reward(kind)
	elif kind == KIND_REST:
		_save_run()
		_set_phase(Phase.REST)
	elif kind == KIND_SHOP:
		_open_shop()
	elif kind == KIND_EVENT:
		_open_event()
	else:
		_enter_current_node()
	run_changed.emit()
	return true


## Story 022: REST "Nghỉ": heals rest_heal_ratio x max HP (clamped), completes the node and shows
## the MAP. Ignored with a warning outside REST.
func rest_heal_requested() -> void:
	if _run == null or _phase != Phase.REST:
		push_warning("GameFlow: rest_heal_requested() outside a rest node, ignored")
		return
	_run.rest_heal(_player_max_hp(), get_reward_config())
	_finish_rest()


## Story 022: REST "Rèn": upgrades the deck card at [param deck_index] (+rest_forge_levels, capped
## at SkillConfig.MAX_LEVEL), completes the node and shows the MAP. A bad index or a card already at
## the cap is refused with a warning and the REST screen stays.
func rest_forge_requested(deck_index: int) -> void:
	if _run == null or _phase != Phase.REST:
		push_warning("GameFlow: rest_forge_requested(%d) outside a rest node, ignored" % deck_index)
		return
	var result: Dictionary = _run.rest_forge(deck_index, get_reward_config())
	if not bool(result.get("ok", false)):
		push_warning("GameFlow: card %d cannot be forged (out of range or at max level)" % deck_index)
		return
	_finish_rest()


## Story 016: shows the title screen; frees the controller if a node was running. A run that
## already ended is dropped; a run still going stays live and saved (the title offers Continue).
func show_title() -> void:
	_free_controller()
	if _run_result != RunResult.NONE:
		_run = null
		_run_result = RunResult.NONE
	_reward_blocking = false
	_set_phase(Phase.TITLE)


## Story 031: shows the WORLD_MAP of the live run (frees the controller). Ignored without a run.
func show_world_map() -> void:
	if _run == null:
		push_warning("GameFlow: show_world_map() without a run, ignored")
		return
	_free_controller()
	_set_phase(Phase.WORLD_MAP)


## Story 018: shows the character select; frees the controller if a node was running.
func show_character_select() -> void:
	_free_controller()
	_set_phase(Phase.CHARACTER_SELECT)


## Story 018 / 031: the select screen's tap on card [param id]: selects it and starts a fresh world run
## (WORLD_MAP, floor 1). An unknown id (warning from [method set_character]) changes nothing.
func character_chosen(id: String) -> void:
	set_character(id)
	if not id.is_empty() and _character_id == id:
		start_run()


## Story 018: back to the character select (the selection is kept; a live run stays saved).
func back_to_character_select() -> void:
	show_character_select()


## Title "Chơi": TITLE -> CHARACTER_SELECT (Story 018). Ignored in other phases.
func start_requested() -> void:
	if _phase == Phase.TITLE:
		show_character_select()


## Story 037: title "Thành tựu": TITLE -> ACHIEVEMENTS. Ignored in other phases.
func open_achievements() -> void:
	if _phase != Phase.TITLE:
		return
	_set_phase(Phase.ACHIEVEMENTS)


## Story 037: the achievements screen's "Về": ACHIEVEMENTS -> TITLE. Ignored in other phases.
func close_achievements() -> void:
	if _phase != Phase.ACHIEVEMENTS:
		return
	_set_phase(Phase.TITLE)


## Main Menu pass (user 2026-11-01): title "Cài đặt": TITLE -> SETTINGS. Ignored in other phases.
func open_settings() -> void:
	if _phase != Phase.TITLE:
		return
	_set_phase(Phase.SETTINGS)


## The settings screen's "Về": SETTINGS -> TITLE. Ignored in other phases.
func close_settings() -> void:
	if _phase != Phase.SETTINGS:
		return
	_set_phase(Phase.TITLE)


## Story 037 (reward / relic offer cards): marks the unlock [param kind] / [param id] seen (the "Mới" badge
## goes away for good) and saves the progress.
func mark_unlock_seen(kind: String, id: String) -> void:
	_progress.mark_unlock_seen(kind, id)
	_store.save_state(_progress)


# DEV-ONLY (--screen=achievements_demo): fills a few milestones and earns what they open, in the memory store.
func _dev_seed_achievements_demo() -> void:
	for key: String in DEV_ACHIEVEMENTS_DEMO_MILESTONES:
		_progress.add_milestone(key, int(DEV_ACHIEVEMENTS_DEMO_MILESTONES[key]))
	UnlockRules.process(AchievementsConfig.shared(), _progress, {"type": "final_reached"})


# --- Save slots (user 2026-11-07) ------------------------------------------------
# User 2026-11-07 (second pass): no separate title button. "Tiếp tục" opens the slot screen in LOAD mode (pick the
# save to load), "Chơi" opens it in NEW mode (pick where the new run goes). One run in progress per slot; every
# character shares the slot's progress.


## The active save slot (0-based).
func get_active_slot() -> int:
	return _slot_index


## The slot files (read-only use by the views and tests).
func get_save_slots() -> SaveSlots:
	return _slots


## The machine settings this flow writes the locale and the last slot to.
func get_settings() -> SettingsStore:
	return _settings


## True when any slot has a file or the live progress holds a run (the title then shows "Tiếp tục").
func has_any_save() -> bool:
	if _progress != null and _progress.has_run():
		return true
	for i: int in SaveSlots.SLOT_COUNT:
		if _slots.has_file(i):
			return true
	return false


## Title "Tiếp tục": the slot screen in LOAD mode. Ignored outside TITLE.
func title_continue() -> void:
	open_save_slots(SLOT_MODE_LOAD)


## Title "Chơi": the slot screen in NEW mode. Ignored outside TITLE.
func title_play() -> void:
	open_save_slots(SLOT_MODE_NEW)


## TITLE -> SAVE_SLOTS in [param mode] (SLOT_MODE_LOAD / SLOT_MODE_NEW; unknown = LOAD). Ignored in other phases.
func open_save_slots(mode: String = SLOT_MODE_LOAD) -> void:
	if _phase != Phase.TITLE:
		return
	_slot_mode = mode if mode == SLOT_MODE_NEW else SLOT_MODE_LOAD
	_slot_confirm = {}
	_set_phase(Phase.SAVE_SLOTS)


## The slot screen's mode (SLOT_MODE_LOAD / SLOT_MODE_NEW).
func get_slot_mode() -> String:
	return _slot_mode


## The slot screen's "Về": SAVE_SLOTS -> TITLE. Ignored in other phases.
func close_save_slots() -> void:
	if _phase != Phase.SAVE_SLOTS:
		return
	_slot_confirm = {}
	_set_phase(Phase.TITLE)


## The card summary of slot [param index] (SaveSlots.summary) plus `active` (the slot in use) and `action`
## ([method slot_primary_action]).
func slot_summary(index: int) -> Dictionary:
	var out: Dictionary = _slots.summary(index)
	out["active"] = index == _slot_index
	out["action"] = _action_of(out)
	return out


## The primary action of slot [param index]'s card in the current mode: SLOT_ACTION_CONTINUE (LOAD, a run in
## progress), _PLAY (progress without a run: character select in that slot), _NEW (empty slot), _REDO (corrupt
## file: set aside, then a new game) or _ABANDON (NEW mode on a slot with a run: asks, then drops that run).
func slot_primary_action(index: int) -> String:
	return _action_of(_slots.summary(index))


func _action_of(info: Dictionary) -> String:
	match int(info["status"]):
		SaveSlots.Status.CORRUPT:
			return SLOT_ACTION_REDO
		SaveSlots.Status.EMPTY:
			return SLOT_ACTION_NEW
	if not bool(info["has_run"]):
		return SLOT_ACTION_PLAY
	return SLOT_ACTION_ABANDON if _slot_mode == SLOT_MODE_NEW else SLOT_ACTION_CONTINUE


## The card's primary button: makes [param index] the active slot (remembered in the settings), then continues
## its run (CONTINUE), opens the character select in it (PLAY / NEW / REDO) or asks before dropping its run
## (ABANDON). Ignored outside SAVE_SLOTS, for a bad index or while a confirmation is open.
func slot_open(index: int) -> void:
	if _phase != Phase.SAVE_SLOTS or not SaveSlots.is_valid_index(index) or not _slot_confirm.is_empty():
		return
	var action: String = slot_primary_action(index)
	if action == SLOT_ACTION_ABANDON:
		_slot_confirm = {"index": index, "kind": SLOT_CONFIRM_ABANDON}
		return
	_switch_slot(index, index != _slot_index or action == SLOT_ACTION_REDO)
	if action == SLOT_ACTION_CONTINUE:
		_set_phase(Phase.TITLE)
		continue_requested()
	else:
		show_character_select()


## The card's "Xóa": asks for the confirmation (the slot screen shows it). Ignored for an empty slot.
func request_slot_delete(index: int) -> void:
	if _phase != Phase.SAVE_SLOTS or not _slots.has_file(index) or not _slot_confirm.is_empty():
		return
	_slot_confirm = {"index": index, "kind": SLOT_CONFIRM_DELETE}


## The open confirmation: {} or {index, kind (SLOT_CONFIRM_DELETE / SLOT_CONFIRM_ABANDON)}.
func get_slot_confirm() -> Dictionary:
	return _slot_confirm.duplicate()


## The confirmation's red button. DELETE: removes the slot's file (the active progress starts empty when it was the
## active slot). ABANDON: the slot becomes active, its run is dropped (unlocks, Kiep and achievements stay) and the
## character select opens.
func confirm_slot() -> void:
	if _slot_confirm.is_empty():
		return
	var index: int = int(_slot_confirm["index"])
	var kind: String = str(_slot_confirm["kind"])
	_slot_confirm = {}
	if kind == SLOT_CONFIRM_ABANDON:
		_switch_slot(index, true)
		_progress.clear_run()
		_store.save_state(_progress)
		show_character_select()
		return
	if not _slots.delete_slot(index):
		return
	if index == _slot_index:
		_switch_slot(index, true)


## The confirmation's "Hủy": nothing changes.
func cancel_slot_confirm() -> void:
	_slot_confirm = {}


# Makes [param index] the active slot; with [param reload] the live run is dropped (it is already saved) and the
# slot's progress is loaded (a corrupt file is set aside first).
func _switch_slot(index: int, reload: bool) -> void:
	_slot_index = index
	_settings.set_last_slot(index)
	if not reload:
		return
	_free_controller()
	_run = null
	_run_result = RunResult.NONE
	_reward_blocking = false
	_pending_node_kind = ""
	_floor_clear_notice = {}
	_new_unlocks.clear()
	_slots.quarantine_if_corrupt(index)
	_store = _slots.store_for(index)
	_progress = _store.load_state(_config)


# DEV-ONLY (--screen=slots_demo): slot 1 = the --progress=demo run (or the run --progress gave), slot 2 = progress
# without a run, slot 3 empty; fixed times so the captures do not change.
func _dev_fill_demo_slots() -> void:
	var first: ProgressState = _progress if _progress.has_run() else _demo_progress()
	first.add_play_time(DEV_SLOTS_PLAY_TIME[0])
	var store: ProgressStore = _slots.store_for(0)
	store.clock = func() -> int: return DEV_SLOTS_SAVED_AT
	store.save_state(first)
	var second := ProgressState.new()
	second.record_floor(4)
	second.record_kiep_result(DEV_SLOTS_SECOND_CHARACTER, 0, true)
	second.add_play_time(DEV_SLOTS_PLAY_TIME[1])
	var store2: ProgressStore = _slots.store_for(1)
	store2.clock = func() -> int: return DEV_SLOTS_SAVED_AT - 86400 * 3
	store2.save_state(second)
	_slots.delete_slot(2)
	_slot_index = 0
	_store = _slots.store_for(0)
	_store.clock = func() -> int: return DEV_SLOTS_SAVED_AT
	_progress = _store.load_state(_config)


## True when the save holds a run in progress (Story 019).
func has_continue() -> bool:
	return _progress.has_run()


## Title "Tiếp tục": rebuilds the saved run (character, deck, floor, region offer / path, map, position,
## HP, tokens, pending offer) and restores its phase (see the class doc). A save that no longer fits the
## data (unknown region, bad map, character, no known card) is dropped with a warning and the title
## stays. A pre-v5 save starts a fresh world run for its character and leaves
## [method take_restart_notice]. Ignored without a saved run.
func continue_requested() -> void:
	if not has_continue():
		return
	var session: RunSession = RunSession.from_dict(_progress.get_run_dict(), _config, get_cards())
	if session == null or not get_characters().has(session.character_id):
		push_warning("GameFlow: the saved run cannot be resumed, dropped")
		_progress.clear_run()
		_store.save_state(_progress)
		show_title()
		return
	set_character(session.character_id)
	if session.needs_restart:
		var key: String = session.restart_reason if not session.restart_reason.is_empty() else TEXT_RESTART_OLD_SAVE
		_restart_notice = tr(key)
		push_warning("GameFlow: pre-v5 saved run, a new world run starts for '%s'" % session.character_id)
		_begin_run()
		return
	_free_controller()
	_run = session
	_run_result = RunResult.NONE
	_reward_blocking = false
	_floor_clear_notice = {}
	_elapsed_base = _run.elapsed_sec
	_last_gold_gain = _run.last_gold_gain
	_pending_node_kind = _pending_kind_from_run()
	_resume_position()
	run_changed.emit()


## Title "Thoát": quits the game.
func quit_requested() -> void:
	get_tree().quit()


## Locale in use ("en" / "vi").
func get_locale() -> String:
	return _locale


## The locale after the current one in [constant SUPPORTED_LOCALES] (cyclic).
func next_locale() -> String:
	var index: int = SUPPORTED_LOCALES.find(_locale)
	return SUPPORTED_LOCALES[(index + 1) % SUPPORTED_LOCALES.size()]


## Story 017: switches the UI locale (TranslationServer) and saves it in the machine settings (save slots
## 2026-11-07: no longer in the progress file). Unknown codes are ignored with a warning. Views draw every frame, so they follow at once;
## RunController.floor_label is cached per node entry (the title is the only place that switches).
func set_locale(code: String) -> void:
	if not SUPPORTED_LOCALES.has(code):
		push_warning("GameFlow: unsupported locale '%s' (en|vi)" % code)
		return
	_apply_locale(code)
	_settings.set_locale(code)


## Title VI / EN button: moves to [method next_locale].
func toggle_locale() -> void:
	set_locale(next_locale())


## False on platforms that must not show a Quit button (iOS).
func can_show_quit() -> bool:
	return not NO_QUIT_OS_NAMES.has(OS.get_name())


## Back / Esc by phase: IN_NODE toggles the pause (nothing when not pausable; leaves the run when
## it already ended), PIECE_DECK closes the piece deck screen (Story 034), WORLD_MAP / MAP / REST leave to
## the title keeping the save, CHARACTER_SELECT ->
## TITLE, TITLE -> quit (not on iOS).
func go_back() -> void:
	match _phase:
		Phase.IN_NODE:
			if _run_result != RunResult.NONE:
				leave_run()
			elif _controller != null:
				_controller.toggle_pause()
		Phase.PIECE_DECK:
			close_piece_deck()
		Phase.WORLD_MAP, Phase.MAP, Phase.REST, Phase.SHOP, Phase.EVENT:
			leave_run_keep_save()
		Phase.CHARACTER_SELECT:
			show_title()
		Phase.ACHIEVEMENTS:
			close_achievements()
		Phase.SETTINGS:
			close_settings()
		Phase.SAVE_SLOTS:
			if not _slot_confirm.is_empty():
				cancel_slot_confirm()
			else:
				close_save_slots()
		Phase.TITLE:
			if can_show_quit():
				quit_requested()


## Pause menu / map / rest "Về": leaves the run mid-way. The run stays saved where it is (its clock
## is updated), the controller is freed and the title shows (Continue resumes it). A run that
## already ended behaves like [method leave_run]; a test floor just returns to the title.
func leave_run_keep_save() -> void:
	if _run_result != RunResult.NONE:
		leave_run()
		return
	if _run != null:
		_save_run()
	_free_controller()
	_set_phase(Phase.TITLE)


## Deprecated name of [method leave_run_keep_save] (Story 019).
func leave_floor() -> void:
	leave_run_keep_save()


## Story 019: the one button of RUN KẾT THÚC / RUN THẮNG (also usable mid-run by dev tooling):
## frees the controller, drops the live run object (the save was already cleared by the result)
## and shows the title.
func leave_run() -> void:
	_free_controller()
	_run = null
	_run_result = RunResult.NONE
	_reward_blocking = false
	_pending_node_kind = ""
	_floor_clear_notice = {}
	_set_phase(Phase.TITLE)
	run_changed.emit()


## Story 019: the reward view picked card [param id] from the offer: it joins the deck (and the
## seen cards), the run is saved and goes on (the MAP, or the RUN THẮNG result after the boss).
## Ignored with a warning when no offer is open or the id is not in it.
func reward_chosen(id: String) -> void:
	if _run == null or not _run.has_pending_reward():
		push_warning("GameFlow: reward_chosen('%s') with no offer open, ignored" % id)
		return
	if not _run.pending_reward.has(id):
		push_warning("GameFlow: reward_chosen('%s') is not in the offer %s, ignored" % [id, str(_run.pending_reward)])
		return
	_run.add_card(id, int(get_reward_config().get("max_card_level", SkillConfig.MAX_LEVEL)))
	_progress.mark_card_seen(id)
	_run.clear_pending_reward()
	_run.clear_pending_relic_offer()
	_run.clear_pending_ink_offer()
	_save_run()
	run_changed.emit()
	_continue_after_reward(true)


## Story 019: the reward view's "Bỏ qua": no card, the run goes on. Ignored with a warning when no
## offer is open or rewards.json has allow_skip false.
func reward_skipped() -> void:
	if _run == null or not _run.has_pending_reward():
		push_warning("GameFlow: reward_skipped() with no offer open, ignored")
		return
	if not bool(get_reward_config().get("allow_skip", true)):
		push_warning("GameFlow: rewards.json allow_skip is false, the offer must be picked")
		return
	_run.clear_pending_reward()
	_run.clear_pending_relic_offer()
	_run.clear_pending_ink_offer()
	_save_run()
	run_changed.emit()
	_continue_after_reward(false)


## Story 020 / 022: the reward view asked to remove the deck card at [param index] ("Bỏ 1 lá"): spends
## one removal token (RunSession.remove_card_at). Refused with a warning with no token, below
## min_deck_size, when rewards.json allow_remove is false, or with no offer open; otherwise the
## card goes, the offer is cleared, the run is saved and goes on exactly like a skip.
func reward_remove_requested(index: int) -> void:
	if _run == null or not _run.has_pending_reward():
		push_warning("GameFlow: reward_remove_requested(%d) with no offer open, ignored" % index)
		return
	var cfg: Dictionary = get_reward_config()
	if not bool(cfg.get("allow_remove", true)):
		push_warning("GameFlow: rewards.json allow_remove is false, ignored")
		return
	if not _run.remove_card_at(index, int(cfg.get("min_deck_size", 4))):
		push_warning("GameFlow: card %d cannot be removed (no token, out of range or deck at minimum)" % index)
		return
	_run.clear_pending_reward()
	_run.clear_pending_relic_offer()
	_run.clear_pending_ink_offer()
	_save_run()
	run_changed.emit()
	_continue_after_reward(true)


## Story 035: true while a downed region boss waits for Tha / Giết (also on a resumed save).
func is_fate_pending() -> bool:
	return _run != null and _run.is_fate_pending()


## Story 035: what the FATE screen shows: {boss_name (translated), match_id, hold_sec (world.fate.fate_hold_sec),
## offers (execute_artifact_offers), min_rarity (execute_min_rarity)}. The boss is the pending one, else the
## last fate taken (the execute offer screen); boss_name "" without a run.
func get_fate_view() -> Dictionary:
	var cfg: Dictionary = _config.fate_config()
	var info: Dictionary = {}
	if _run != null:
		if _run.is_fate_pending():
			info = _run.pending_fate_match
		elif not _run.boss_fates.is_empty():
			info = _run.boss_fates.back()
	var match_id: String = str(info.get("match_id", ""))
	var key: String = _match_name_key(str(info.get("region_id", "")), match_id)
	return {
		"boss_name": "" if key.is_empty() else tr(key),
		"match_id": match_id,
		"hold_sec": float(cfg.get("fate_hold_sec", FateLogic.FATE_DEFAULTS["fate_hold_sec"])),
		"offers": int(cfg.get("execute_artifact_offers", FateLogic.FATE_DEFAULTS["execute_artifact_offers"])),
		"min_rarity": str(cfg.get("execute_min_rarity", FateLogic.FATE_DEFAULTS["execute_min_rarity"])),
	}


## Story 035: the FATE choice ([param fate] "spare" | "execute") for the pending region boss: recorded in the run
## (boss_fates) and the permanent progress. "spare" goes straight on to the boss reward (3 cards + token);
## "execute" opens the artifact offer ([method get_fate_offer]; FateLogic.roll_execute_offer with world.fate),
## or goes straight on when nothing can be offered. Ignored with a warning when no fate is pending or the fate
## is unknown.
func choose_fate(fate: String) -> void:
	if not is_fate_pending():
		push_warning("GameFlow: choose_fate('%s') with no fate pending, ignored" % fate)
		return
	var match_id: String = str(_run.pending_fate_match.get("match_id", ""))
	var fate_floor: int = int(_run.pending_fate_match.get("floor", _run.floor))
	if not _run.record_fate(fate):
		push_warning("GameFlow: choose_fate('%s') is not a known fate, ignored" % fate)
		return
	_progress.record_fate(match_id, fate)
	_process_unlocks({"type": "fate", "fate": fate}) # Story 037: kills_total / spares_total moved
	if fate == FateLogic.FATE_EXECUTE:
		var offer: Array[String] = FateLogic.roll_execute_offer(_run.relic_ids(), _config.fate_config(), null,
			hash([_run.run_seed, fate_floor, FATE_SEED_TAG]) & ChaptersConfig.SEED_MASK, _run.luck(get_reward_config()), _run.locked_ids("relic"))
		if not offer.is_empty():
			_run.clear_pending_reward()
			_run.set_pending_relic_offer(offer)
			_save_run()
			run_changed.emit()
			return
	_save_run()
	_after_fate()


## Story 035: true while the execute artifact offer is open (a relic offer with no card offer beside it).
func has_fate_offer() -> bool:
	return _run != null and not _run.is_fate_pending() and _run.has_pending_relic_offer() and not _run.has_pending_reward()


## Story 035: the relic ids of the open execute offer; [] when none is open.
func get_fate_offer() -> Array[String]:
	if not has_fate_offer():
		return []
	return _run.pending_relic_offer.duplicate()


## Story 035: takes relic [param id] of the execute offer, then the boss reward opens. Ignored with a warning
## when no offer is open, the id is not in it or the run refuses it.
func choose_fate_relic(id: String) -> void:
	if not has_fate_offer():
		push_warning("GameFlow: choose_fate_relic('%s') with no fate offer open, ignored" % id)
		return
	if not _run.pending_relic_offer.has(id):
		push_warning("GameFlow: choose_fate_relic('%s') is not in the offer %s, ignored" % [id, str(_run.pending_relic_offer)])
		return
	if not _run.add_relic(id):
		push_warning("GameFlow: choose_fate_relic('%s') was refused by the run (owned or unknown), ignored" % id)
		return
	_run.clear_pending_relic_offer()
	_save_run()
	_after_fate()


## Story 035: leaves the execute offer without a relic (still an execute), then the boss reward opens.
func skip_fate_relic() -> void:
	if not has_fate_offer():
		push_warning("GameFlow: skip_fate_relic() with no fate offer open, ignored")
		return
	_run.clear_pending_relic_offer()
	_save_run()
	_after_fate()


## Story 035: the ENDING screen's data: {id ("spare" | "balance" | "execute"), title_key (ending.<id>.title),
## line_keys (ending.<id>.line1..N), stats (RunSession.stats_summary())}; {} before a final match is won.
func get_ending() -> Dictionary:
	return _ending.duplicate(true)


## Story 035: the ENDING screen's "Về màn chính": the run (already dropped from the save) goes, TITLE shows.
func leave_ending() -> void:
	if _phase != Phase.ENDING:
		push_warning("GameFlow: leave_ending() outside the ENDING screen, ignored")
		return
	leave_run()


## Story 035: the lost screen's stats (RunSession.stats_summary() taken at death; `death` = {floor, region_id,
## match_id, boss_name_key}); kept after the run is dropped, {} before any defeat.
func get_defeat_summary() -> Dictionary:
	return _defeat_summary.duplicate(true)


# Story 035: the fate (and its offer) is resolved: the boss reward of Story 022/031 opens as today's boss path
# (IN_NODE over the live controller, or the MAP on a resumed run).
func _after_fate() -> void:
	_set_phase(Phase.IN_NODE if _controller != null else Phase.MAP)
	_offer_reward(KIND_BOSS)
	run_changed.emit()


# Story 035: name_key of [param match_id] in region [param region_id]; "" when unknown.
func _match_name_key(region_id: String, match_id: String) -> String:
	var ci: int = _config.region_index(region_id)
	if ci < 0 or match_id.is_empty():
		return ""
	return str(_config.get_match_def(ci, match_id).get("name_key", ""))


# Story 035: the live controller's CombatView, null without one.
func _live_view() -> CombatView:
	if _controller == null:
		return null
	var battle: Node = _controller.get_battle()
	return null if battle == null else battle.get_node_or_null(RunController.COMBAT_VIEW_NODE) as CombatView


## Story 032: relic ids owned by the live run, in received order; [] without a run.
func get_relics() -> Array[String]:
	if _run == null:
		return []
	return _run.relic_ids()


## Story 032: the relic row of the open treasure offer (3 ids at most); [] when no relic offer is open
## (the card row is [method get_pending_reward]).
func get_relic_offer() -> Array[String]:
	if _run == null:
		return []
	return _run.pending_relic_offer.duplicate()


## Story 032: true while a relic row is open on the treasure screen.
func has_relic_offer() -> bool:
	return _run != null and _run.has_pending_relic_offer()


## Story 032: the treasure screen's relic pick: [param id] must be in [method get_relic_offer]. It joins
## the run's relics, BOTH rows close, the run is saved and the node completes (back to the MAP). Ignored
## with a warning when no relic offer is open or the id is not in it.
func choose_relic(id: String) -> void:
	if _run == null or not _run.has_pending_relic_offer():
		push_warning("GameFlow: choose_relic('%s') with no relic offer open, ignored" % id)
		return
	if not _run.pending_relic_offer.has(id):
		push_warning("GameFlow: choose_relic('%s') is not in the offer %s, ignored" % [id, str(_run.pending_relic_offer)])
		return
	if not _run.add_relic(id):
		push_warning("GameFlow: choose_relic('%s') was refused by the run (owned or unknown), ignored" % id)
		return
	_run.clear_pending_reward()
	_run.clear_pending_relic_offer()
	_run.clear_pending_ink_offer()
	_save_run()
	run_changed.emit()
	_continue_after_reward(false)


## Story 032: "Bỏ qua" on the treasure screen: BOTH rows close, nothing is taken. Same rules as
## [method reward_skipped] (ignored with a warning when no relic offer is open or allow_skip is false).
func skip_relic_offer() -> void:
	if _run == null or not _run.has_pending_relic_offer():
		push_warning("GameFlow: skip_relic_offer() with no relic offer open, ignored")
		return
	if not bool(get_reward_config().get("allow_skip", true)):
		push_warning("GameFlow: rewards.json allow_skip is false, the offer must be picked")
		return
	_run.clear_pending_reward()
	_run.clear_pending_relic_offer()
	_run.clear_pending_ink_offer()
	_save_run()
	run_changed.emit()
	_continue_after_reward(false)


## Story 032: RelicRegistry.info(id) ({id, rarity, tags, name_key, desc_key, params}) plus the translated
## "name" and "desc"; {} for an unknown id.
func relic_info(id: String) -> Dictionary:
	var info: Dictionary = _relic_info_raw(id).duplicate(true)
	if info.is_empty():
		return {}
	info["name"] = tr(str(info.get("name_key", "")))
	info["desc"] = tr(str(info.get("desc_key", "")))
	return info


## Story 020: the run's deck as {id, level} entries ([] with no run).
func get_run_deck_entries() -> Array[Dictionary]:
	if _run == null:
		return []
	return _run.deck_entries()


## Story 020: id -> highest copy level of the run's deck ({} with no run).
func get_deck_levels() -> Dictionary:
	if _run == null:
		return {}
	return _run.deck_levels()


# ---- Story 034 piece deck API ----

## Story 034: a copy of the run's piece deck (PieceDeck state {mult, added}); {} without a run.
func get_piece_deck() -> Dictionary:
	return {} if _run == null else _run.piece_deck.duplicate(true)


## Story 034: shape-removal tokens of the live run (0 without a run).
func get_shape_removals() -> int:
	return 0 if _run == null else _run.shape_removals


## Story 034: the piece-deck rules (rewards.json `piece_rewards`; shared, read-only for the views).
func get_piece_deck_config() -> PieceDeckConfig:
	return RunSession.piece_config()


## Story 034: the shared piece library (pieces.json; read-only for the views).
func get_piece_library() -> PieceLibrary:
	return RunSession.piece_library()


## Story 034: the PIECE_DECK screen rows, library order: every default-pool shape, then the run-only shapes
## that are in the deck or offered on the open ink row. Each row: {id, name (translated), cells
## Array[Vector2i], mult float, dots int (ceil of mult, 0 when not in the deck), removed bool (a default shape
## at mult 0), run_only bool, percent float (PieceDeck.drop_percent of the effective weights for the current
## region, 0 when not drawable), can_remove bool, reason String (a translation key; "" when can_remove; tokens
## counted: `piece_deck.reason.no_token` at 0)}. [] without a run.
func get_piece_deck_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if _run == null:
		return rows
	var lib: PieceLibrary = RunSession.piece_library()
	var cfg: PieceDeckConfig = RunSession.piece_config()
	var state: Dictionary = _run.piece_deck
	var active: Array[String] = PieceDeck.active_ids(state, lib)
	var percent: Dictionary = PieceDeck.drop_percent(PieceDeck.effective_weights(state, lib, _run.region_id, cfg, _run.locked_ids("piece")))
	var ids: Array[String] = []
	for base_id: String in lib.base_shape_ids():
		if not _run.is_locked("piece", base_id): # Story 037: a locked shape is not listed
			ids.append(base_id)
	for id: String in lib.run_only_ids():
		if active.has(id) or _run.pending_ink_offer.has(id):
			ids.append(id)
	for id: String in ids:
		var in_deck: bool = active.has(id)
		var mult: float = PieceDeck.mult_of(state, id) if in_deck else 0.0
		var verdict: Dictionary = _run.can_remove_shape(id, true, lib, cfg)
		rows.append({
			"id": id, "name": tr(lib.name_key(id)), "cells": lib.shape_cells(id), "mult": mult,
			"dots": ceili(mult) if in_deck else 0, "removed": not in_deck and not lib.is_run_only(id),
			"run_only": lib.is_run_only(id), "percent": float(percent.get(id, 0.0)),
			"can_remove": bool(verdict["ok"]), "reason": str(verdict["reason"]),
		})
	return rows


## Story 034: whether shape [param id] can be removed with a token now ({ok, reason}; RunSession.can_remove_shape
## with the token rule). {ok false, reason piece_deck.reason.unknown} without a run.
func can_remove_shape(id: String) -> Dictionary:
	if _run == null:
		return {"ok": false, "reason": PieceDeck.REASON_UNKNOWN}
	return _run.can_remove_shape(id, true)


## Story 034: the PIECE_DECK screen's "Xóa hình": removes shape [param id] spending one shape-removal token;
## saves and emits [signal run_changed]. False (nothing changes, warning) when [method can_remove_shape] refuses.
func remove_shape(id: String) -> bool:
	if _run == null:
		push_warning("GameFlow: remove_shape('%s') without a run, ignored" % id)
		return false
	var result: Dictionary = _run.remove_shape(id, true)
	if not bool(result.get("ok", false)):
		push_warning("GameFlow: remove_shape('%s') refused (%s)" % [id, str(result.get("reason", ""))])
		return false
	_save_run()
	run_changed.emit()
	return true


## Story 034: shape ids of the open reward screen's ink row; [] when none.
func get_ink_offer() -> Array[String]:
	if _run == null:
		return [] as Array[String]
	return _run.pending_ink_offer.duplicate()


## Story 034: true while an ink row is open.
func has_ink_offer() -> bool:
	return _run != null and _run.has_pending_ink_offer()


## Story 034: picks ink [param id] from [method get_ink_offer]: RunSession.apply_ink, the ink row closes, the
## run is saved and [signal run_changed] emitted. The node does NOT advance: the card / relic choice of the
## same screen stays open. Ignored with a warning without an ink row, for an id not offered, or when the ink
## is refused (unknown shape or at the ceiling).
func choose_ink(id: String) -> void:
	if _run == null or not _run.has_pending_ink_offer():
		push_warning("GameFlow: choose_ink('%s') with no ink offer open, ignored" % id)
		return
	if not _run.pending_ink_offer.has(id):
		push_warning("GameFlow: choose_ink('%s') is not in the offer %s, ignored" % [id, str(_run.pending_ink_offer)])
		return
	if not _run.apply_ink(id):
		push_warning("GameFlow: choose_ink('%s') was refused (unknown or at mult_max), ignored" % id)
		return
	_run.clear_pending_ink_offer()
	_save_run()
	run_changed.emit()


## Story 034: "Bỏ qua" of the ink row: the row closes (nothing inked), the card / relic choice stays open.
## Ignored with a warning when no ink row is open.
func skip_ink_offer() -> void:
	if _run == null or not _run.has_pending_ink_offer():
		push_warning("GameFlow: skip_ink_offer() with no ink offer open, ignored")
		return
	_run.clear_pending_ink_offer()
	_save_run()
	run_changed.emit()


## Story 034: opens the PIECE_DECK screen from WORLD_MAP or MAP (the phase is remembered for
## [method close_piece_deck]); emits [signal run_changed]. Refused with a warning in any other phase, without
## a run or once the run ended.
func open_piece_deck() -> void:
	if _run == null or _run_result != RunResult.NONE or (_phase != Phase.WORLD_MAP and _phase != Phase.MAP):
		push_warning("GameFlow: open_piece_deck() outside the world map / map, ignored")
		return
	_piece_deck_return = _phase
	_set_phase(Phase.PIECE_DECK)
	run_changed.emit()


## Story 034: closes the PIECE_DECK screen back to the phase it was opened from; emits [signal run_changed].
## Ignored with a warning when the screen is not open.
func close_piece_deck() -> void:
	if _phase != Phase.PIECE_DECK:
		push_warning("GameFlow: close_piece_deck() while the piece deck is not open, ignored")
		return
	_set_phase(_piece_deck_return)
	run_changed.emit()


# Story 034: the ink row of the reward of a [param kind] node at the current position: with chance
# `ink_offer_chance` after a battle / danger, always after a treasure ([param force] too), else []. Seeded by
# hash([run_seed, floor, region, column, nodes_cleared, "ink"]) like [method _reward_seed]; the offer itself is
# saved, so a resume shows the same row.
func _roll_ink_for(kind: String, force: bool) -> Array[String]:
	var cfg: PieceDeckConfig = RunSession.piece_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_run.run_seed, _run.floor, _run.region_id, _run.column, _run.nodes_cleared, INK_SEED_TAG]) & ChaptersConfig.SEED_MASK
	var hit: bool = rng.randf() < cfg.ink_offer_chance
	if not (force or INK_ALWAYS_KINDS.has(kind) or (INK_CHANCE_KINDS.has(kind) and hit)):
		return [] as Array[String]
	return PieceDeck.roll_ink_offer(_run.piece_deck, RunSession.piece_library(), cfg, rng.randi() & ChaptersConfig.SEED_MASK, _run.locked_ids("piece"))


# DEV-ONLY (Story 034, --piece-deck-state / --run=piece_deck): applies SPEC ("|"-separated remove:id,id /
# mult:id=N,id=N / add:id,id) to the run's piece deck (see the class doc); bad parts warn.
func _dev_apply_piece_deck_state(spec: String) -> void:
	var lib: PieceLibrary = RunSession.piece_library()
	var cfg: PieceDeckConfig = RunSession.piece_config()
	for part: String in spec.split("|", false):
		var op: String = part.get_slice(":", 0).strip_edges()
		var items: PackedStringArray = part.trim_prefix(op + ":").split(",", false)
		for raw: String in items:
			var item: String = raw.strip_edges()
			match op:
				"remove":
					var r: Dictionary = _run.remove_shape(item, false, lib, cfg)
					if not bool(r["ok"]):
						push_warning("GameFlow: --piece-deck-state remove:%s refused (%s)" % [item, str(r["reason"])])
				"mult":
					var id: String = item.get_slice("=", 0).strip_edges()
					if not lib.has_shape(id) or not item.contains("="):
						push_warning("GameFlow: --piece-deck-state mult:%s ignored (use id=N, known shape)" % item)
						continue
					var state: Dictionary = _run.piece_deck.duplicate(true)
					(state[PieceDeck.KEY_MULT] as Dictionary)[id] = clampf(float(item.get_slice("=", 1)), 0.0, cfg.mult_max)
					if lib.is_run_only(id) and not (state[PieceDeck.KEY_ADDED] as Array).has(id):
						(state[PieceDeck.KEY_ADDED] as Array).append(id)
					_run.piece_deck = PieceDeck.sanitize(state, lib)
				"add":
					if not _run.apply_ink(item, lib, cfg):
						push_warning("GameFlow: --piece-deck-state add:%s refused (unknown or at mult_max)" % item)
				_:
					push_warning("GameFlow: --piece-deck-state part '%s' unknown (remove|mult|add), ignored" % part)
					break


# ---- Story 033 shop / event API ----

## Story 033: the open shop's ShopLogic state (a copy; see the ShopLogic header: "cards" / "relics" rows
## {id, price, sold}, "services" {remove_card, heal: {price, used}}, plus "node_key"); {} outside SHOP.
func get_shop() -> Dictionary:
	if _run == null or _phase != Phase.SHOP:
		return {}
	return _run.shop_state.duplicate(true)


## Story 033: buys [param id] of row [param kind] (ShopLogic.KIND_CARD / KIND_RELIC) in the open shop:
## the ShopLogic.buy result ({ok, reason, reason_key, price, kind, id[, upgraded, level]}); a bought
## card counts as seen. The run is saved on success. Outside SHOP: {ok false, reason "unknown"}.
func shop_buy(kind: String, id: String) -> Dictionary:
	if _run == null or _phase != Phase.SHOP:
		push_warning("GameFlow: shop_buy('%s', '%s') outside a shop, ignored" % [kind, id])
		return ShopLogic._refuse(ShopLogic.REASON_UNKNOWN, 0)
	var result: Dictionary = ShopLogic.buy(_run.shop_state, _run, kind, id)
	if bool(result.get("ok", false)):
		if kind == ShopLogic.KIND_CARD:
			_progress.mark_card_seen(id)
		_save_run()
		run_changed.emit()
	return result


## Story 033: uses service [param id] of the open shop once: ShopLogic.SERVICE_REMOVE_CARD with
## [param arg] = deck index (a curse may always go; other cards keep min_deck_size non-curse cards),
## ShopLogic.SERVICE_HEAL without arg (the flow passes the player's max HP), Story 034's
## ShopLogic.SERVICE_REMOVE_SHAPE with [param arg] = shape id (gold, not a token). The ShopLogic.use_service
## result; saved on success. Outside SHOP: {ok false, reason "unknown"}.
func shop_use_service(id: String, arg: Variant = null) -> Dictionary:
	if _run == null or _phase != Phase.SHOP:
		push_warning("GameFlow: shop_use_service('%s') outside a shop, ignored" % id)
		return ShopLogic._refuse(ShopLogic.REASON_UNKNOWN, 0)
	var service_arg: Variant = _player_max_hp() if id == ShopLogic.SERVICE_HEAL else arg
	var opts: Dictionary = {"piece_library": RunSession.piece_library(), "piece_config": RunSession.piece_config()}
	var result: Dictionary = ShopLogic.use_service(_run.shop_state, _run, id, service_arg, get_cards(), opts)
	if bool(result.get("ok", false)):
		_save_run()
		run_changed.emit()
	return result


## Story 033: "Rời cửa hàng": the shop node completes (no reward, no gold), the stock is dropped and the
## MAP shows (saved). Ignored with a warning outside SHOP.
func shop_leave() -> void:
	if _run == null or _phase != Phase.SHOP:
		push_warning("GameFlow: shop_leave() outside a shop, ignored")
		return
	_run.shop_state = {}
	_complete_plain_node(KIND_SHOP)


## Story 033: EventLogic.describe of the open event with the player's max HP ({id, title_key, body_key,
## choices [{index, id, label_key, cost_key, enabled, reason_key, reason_args, needs_confirm}]}) plus
## "chosen" (the index picked, -1 before a choice); {} outside EVENT.
func get_event_view() -> Dictionary:
	var cur: Dictionary = _current_event()
	if cur.is_empty() or _phase != Phase.EVENT:
		return {}
	var view: Dictionary = EventLogic.describe(str(cur[EVENT_ID]), _run, _player_max_hp(), _event_opts())
	if not view.is_empty():
		view["chosen"] = int(cur.get(EVENT_CHOICE, -1))
	return view


## Story 033: picks choice [param index] of the open event: the EventLogic.resolve result ({ok,
## outcome_index, text_key, effects_applied, pending_picks, pending_fight}). The result is stored in the
## run BEFORE the save (a resume shows it, never re-rolls). A `fight` outcome starts the extra match at
## once (phase IN_NODE; see the class doc). Refused (nothing changes): outside EVENT, a choice already
## made ({ok false, reason_key "ui.event.already_chosen"}) or a choice whose requirements fail.
func event_choose(index: int) -> Dictionary:
	var cur: Dictionary = _current_event()
	if cur.is_empty() or _phase != Phase.EVENT:
		push_warning("GameFlow: event_choose(%d) outside an event, ignored" % index)
		return {"ok": false, "reason_key": EventLogic.KEY_BAD_CHOICE, "reason_args": []}
	if int(cur.get(EVENT_CHOICE, -1)) >= 0:
		return {"ok": false, "reason_key": TEXT_EVENT_ALREADY_CHOSEN, "reason_args": []}
	var result: Dictionary = EventLogic.resolve(str(cur[EVENT_ID]), index, _run, _player_max_hp(), _event_opts())
	if not bool(result.get("ok", false)):
		return result
	cur[EVENT_CHOICE] = index
	cur[EVENT_RESULT] = result.duplicate(true)
	for effect: Variant in result.get("effects_applied", []) as Array:
		if typeof(effect) == TYPE_DICTIONARY and str((effect as Dictionary).get("type", "")) == "card_offer":
			for id: Variant in (effect as Dictionary).get("ids", []) as Array:
				_progress.mark_card_seen(str(id))
	var fight: Dictionary = result.get("pending_fight", {})
	if not fight.is_empty():
		cur[EVENT_FIGHT] = fight.duplicate(true)
		cur[EVENT_FIGHT_ACTIVE] = true
		_save_run()
		_start_event_fight()
		run_changed.emit()
		return result
	_save_run()
	run_changed.emit()
	return result


## Story 033: the result of the choice made at the open event (as [method event_choose] returned it,
## `pending_picks` = the picks still open); after a won extra fight, the EventLogic.finish_fight result
## (text_key "event.<id>.fight_won", its prize in effects_applied) with "fight_won" true. {} before a
## choice or outside EVENT.
func get_event_result() -> Dictionary:
	var cur: Dictionary = _current_event()
	if cur.is_empty() or _phase != Phase.EVENT:
		return {}
	return (cur.get(EVENT_RESULT, {}) as Dictionary).duplicate(true)


## Story 033: finishes the FIRST open pending pick of the event result with [param arg] (card_offer: the
## chosen card id, "" = skip; remove_card / upgrade_card: a deck index): the EventLogic.complete_pick
## result ({ok, reason_key}). On success the pick closes and the run is saved. {ok false} when no pick
## is open or outside EVENT.
func event_complete_pick(arg: Variant) -> Dictionary:
	var cur: Dictionary = _current_event()
	if cur.is_empty() or _phase != Phase.EVENT:
		push_warning("GameFlow: event_complete_pick() outside an event, ignored")
		return {"ok": false, "reason_key": "ui.event.bad_pick"}
	var result: Dictionary = cur.get(EVENT_RESULT, {})
	var picks: Array = result.get("pending_picks", [])
	if picks.is_empty():
		return {"ok": false, "reason_key": "ui.event.bad_pick"}
	var pick: Dictionary = picks[0]
	var done: Dictionary = EventLogic.complete_pick(_run, pick, arg, _event_opts())
	if bool(done.get("ok", false)):
		if str(pick.get("type", "")) == "card_offer" and not str(arg).is_empty():
			_progress.mark_card_seen(str(arg))
		picks.remove_at(0)
		_save_run()
		run_changed.emit()
	return done


## Story 033: leaves the event (any open pick is forfeited): the node completes (no reward, no gold), the
## node's event state is dropped (the seen-event list stays) and the MAP shows. Ignored with a warning
## outside EVENT.
func event_leave() -> void:
	if _run == null or _phase != Phase.EVENT:
		push_warning("GameFlow: event_leave() outside an event, ignored")
		return
	_clear_current_event()
	_complete_plain_node(KIND_EVENT)


# Story 033: the chosen node's position key "floor/column/node" (shop / event state tag).
func _node_key() -> String:
	return "%d/%d/%d" % [_run.floor, _run.column, _run.node_index]


# Story 033: opens the chosen SHOP node: restores RunSession.shop_state when it belongs to this node
# (resume), else builds the seeded stock; saves; phase SHOP.
func _open_shop() -> void:
	var key: String = _node_key()
	var state: Dictionary = {}
	if str(_run.shop_state.get(SHOP_NODE, "")) == key:
		state = ShopLogic.from_dict(_run.shop_state)
	if state.is_empty():
		var cfg: Dictionary = get_reward_config()
		state = ShopLogic.build(_run.run_seed, _run.floor, _run.column, _run.node_index, _run.luck(cfg),
			_run.relic_ids(), get_cards(), cfg, null, EconomyConfig.shared(), _run.locked, _run.kiep_level)
	state[SHOP_NODE] = key
	_run.shop_state = state
	_save_run()
	_set_phase(Phase.SHOP)


# Story 033: opens the chosen EVENT node: resumes the node's saved event (an extra fight still running
# respawns its match), else picks a fresh event (dev --run=event=<id> forces one) and records it as
# seen; saves; phase EVENT. No event at all: the node completes at once.
func _open_event() -> void:
	var key: String = _node_key()
	var cur: Dictionary = _current_event()
	if not cur.is_empty() and str(cur.get(EVENT_NODE, "")) == key and not EventLogic.get_event(str(cur[EVENT_ID]), _event_opts()).is_empty():
		_normalize_event_result(cur)
		if bool(cur.get(EVENT_FIGHT_ACTIVE, false)):
			_start_event_fight()
			return
		_save_run()
		_set_phase(Phase.EVENT)
		return
	var used: Array = _run.event_state.get(EVENT_USED, [])
	var id: String = ""
	if not _dev_event_id.is_empty():
		if EventLogic.get_event(_dev_event_id, _event_opts()).is_empty():
			push_warning("GameFlow: --run=event=%s: unknown event (known: %s)" % [_dev_event_id, ", ".join(EventLogic.event_ids(_event_opts()))])
		else:
			id = _dev_event_id
		_dev_event_id = ""
	if id.is_empty():
		id = EventLogic.pick_event(_run.run_seed, _run.floor, _run.column, _run.node_index, used, _event_opts())
	if id.is_empty():
		push_warning("GameFlow: no event to show, the event node completes")
		_complete_plain_node(KIND_EVENT)
		return
	if not used.has(id):
		used.append(id)
	_run.event_state = {
		EVENT_USED: used, EVENT_NODE: key, EVENT_ID: id, EVENT_CHOICE: -1, EVENT_RESULT: {},
		EVENT_FIGHT: {}, EVENT_FIGHT_ACTIVE: false,
	}
	_save_run()
	_set_phase(Phase.EVENT)


# Story 033: the event node being visited (the live RunSession.event_state Dictionary); {} without one.
func _current_event() -> Dictionary:
	if _run == null or str(_run.event_state.get(EVENT_ID, "")).is_empty():
		return {}
	return _run.event_state


# Story 033: drops the node's keys of RunSession.event_state, keeping the seen-event list.
func _clear_current_event() -> void:
	var used: Array = _run.event_state.get(EVENT_USED, [])
	_run.event_state = {EVENT_USED: used}


# Story 033: a resumed event state comes back from JSON (numbers as floats): restore the int fields.
func _normalize_event_result(cur: Dictionary) -> void:
	cur[EVENT_CHOICE] = int(cur.get(EVENT_CHOICE, -1))
	var result: Variant = cur.get(EVENT_RESULT, {})
	if typeof(result) != TYPE_DICTIONARY:
		cur[EVENT_RESULT] = {}
		return
	if (result as Dictionary).has("outcome_index"):
		(result as Dictionary)["outcome_index"] = int((result as Dictionary)["outcome_index"])
	if typeof((result as Dictionary).get("pending_picks")) != TYPE_ARRAY:
		(result as Dictionary)["pending_picks"] = []
	var fight: Variant = cur.get(EVENT_FIGHT, {})
	if typeof(fight) == TYPE_DICTIONARY and (fight as Dictionary).has("tier_add"):
		(fight as Dictionary)["tier_add"] = int((fight as Dictionary)["tier_add"])


# Story 033: options of every EventLogic call (the flow's card data and rewards.json).
func _event_opts() -> Dictionary:
	return {"cards": get_cards(), "reward_config": get_reward_config()}


# Story 033: true while the open event's extra fight is being played (or waits to respawn on resume).
func _is_event_fight_active() -> bool:
	var cur: Dictionary = _current_event()
	return not cur.is_empty() and bool(cur.get(EVENT_FIGHT_ACTIVE, false))


# Story 033: spawns the event's extra match through the match-node path: a match of the fight's kind
# drawn from the region's pool at the current column's tier + tier_add (seeded by the node, kept in the
# state so a resume replays the same match). The node and the column do not move.
func _start_event_fight() -> void:
	var cur: Dictionary = _current_event()
	var fight: Dictionary = cur.get(EVENT_FIGHT, {})
	var kind: String = str(fight.get("kind", "danger"))
	var match_id: String = str(fight.get("match_id", ""))
	if match_id.is_empty():
		var tier: int = int(_run.current_column().get("tier", 0)) + int(fight.get("tier_add", 0))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([_run.run_seed, _run.floor, _run.column, _run.node_index, EVENT_FIGHT_SEED_TAG]) & ChaptersConfig.SEED_MASK
		var used: Array[String] = []
		match_id = ChapterMapGen._draw_match(_config.region_spec(_run.region_id, _run.floor, _run.kiep_level), kind, tier, used, rng)
		fight["match_id"] = match_id
		cur[EVENT_FIGHT] = fight
	_spawn_match(match_id, kind)


# Story 033: the event's extra match was won: run modifiers tick (a match was played), the HP carries
# (plus passive heal, clamped), EventLogic.finish_fight applies the prize, the result becomes the fight
# result and the EVENT screen shows again (saved). The node is NOT completed.
func _finish_event_fight(hp_end: float, max_hp: float, passive_heal: float) -> void:
	var cur: Dictionary = _current_event()
	_run.tick_run_modifiers()
	_run.hp = minf(hp_end + maxf(passive_heal, 0.0), max_hp)
	var fight: Dictionary = cur.get(EVENT_FIGHT, {})
	var won: Dictionary = EventLogic.finish_fight(_run, fight, true, max_hp, _event_opts())
	var prev: Dictionary = cur.get(EVENT_RESULT, {})
	won["outcome_index"] = int(prev.get("outcome_index", 0))
	won["fight_won"] = true
	cur[EVENT_RESULT] = won
	cur[EVENT_FIGHT] = {}
	cur[EVENT_FIGHT_ACTIVE] = false
	_sync_elapsed()
	_free_controller()
	_save_run()
	_set_phase(Phase.EVENT)
	run_changed.emit()


# Story 033: completes a fight-less, reward-less node (shop, event) and goes back to the MAP.
func _complete_plain_node(kind: String) -> void:
	_run.complete_node(_run.hp, _player_max_hp(), kind, get_reward_config(), 0.0)
	if _run.is_run_won():
		_finish_run_won()
		return
	_return_to_map()


# Creates a fresh world run of the selected (or default) character with a fresh seed (or --seed):
# floor 1, its region offer rolled, no region yet; records floor 1 reached, saves, shows WORLD_MAP.
func _begin_run() -> void:
	if _character_id.is_empty():
		set_character(get_characters().default_id())
	_free_controller()
	var run_seed: int = _dev_seed if _dev_seed >= 0 else randi() & ChaptersConfig.SEED_MASK
	var starting_removals: int = int(get_reward_config().get("starting_removals", 0))
	# Story 037: the content still locked NOW is frozen into the run (unlocking mid-run changes nothing for it).
	_run = RunSession.begin_world(_config, _character_dict(), run_seed, starting_removals,
		AchievementsConfig.shared().locked_content(_progress), get_kiep_level())
	_run.cards_config = get_cards()
	for relic_id: String in _dev_relics:
		_run.add_relic(relic_id)
	if _dev_gold >= 0:
		_run.gold = _dev_gold
	if _dev_hp > 0.0:
		_run.hp = minf(_dev_hp, _character_max_hp(_character_dict()))
	if _dev_shape_removals >= 0:
		_run.shape_removals = _dev_shape_removals
	if not _dev_piece_deck_state.is_empty():
		_dev_apply_piece_deck_state(_dev_piece_deck_state)
	for card_id: String in _dev_deck_add:
		if get_cards().has_skill(card_id):
			_run.add_card(card_id, 1)
		else:
			push_warning("GameFlow: --deck+=: unknown card '%s', ignored" % card_id)
	_last_gold_gain = 0
	_last_kiep_unlock = 0
	_run_result = RunResult.NONE
	_reward_blocking = false
	_pending_node_kind = ""
	_floor_clear_notice = {}
	_elapsed_base = 0.0
	_ending = {}
	_defeat_summary = {}
	_progress.record_floor(_run.floor + 1)
	_save_run()
	_set_phase(Phase.WORLD_MAP)
	run_changed.emit()


# Spawns the controller of the run's chosen node (RunConfig.from_node: one match of the region scaled
# for the floor, arena seed RunSession.floor_seed(), danger traits) at the run's HP / deck. between_sec 0
# (the reward screen gates the advance) and no minimum-HP rule (retry_min_hp_ratio 0: the saved HP is
# the HP). A pending offer on a resumed match node holds the intro.
func _enter_current_node() -> void:
	var node: Dictionary = _run.current_node()
	_spawn_match(str(node.get("match_id", "")), str(node.get("kind", "")))


# The one match path (a match node, or Story 033's event extra fight): match [param match_id] of the
# current region scaled for the floor, played as a [param kind] node (danger traits), at the run's HP.
func _spawn_match(match_id: String, kind: String) -> void:
	_free_controller()
	_elapsed_base = _run.elapsed_sec
	var run_config: RunConfig = RunConfig.from_node(_config, _run.region_id, match_id, kind,
		_run.floor_seed(), _run.floor, _run.kiep_level)
	run_config.between_sec = 0.0
	run_config.retry_min_hp_ratio = 0.0
	var controller := RunController.new()
	controller.name = CONTROLLER_NODE
	controller.floor_label = tr(_node_name_key(kind))
	controller.chapter_id = _run.region_id
	controller.art_area = current_art_area(kind)
	controller.character = _character_dict()
	controller.deck = _run.deck_ids
	controller.deck_entries = _run.deck_entries()
	controller.piece_deck = _run.piece_deck.duplicate(true)
	controller.locked_pieces = _run.locked_ids("piece")
	controller.boss_can_down = FateLogic.is_boss_fate_node(kind, _run.is_final_floor()) and not _is_event_fight_active()
	_live_match_id = match_id
	controller.hold_intro = _reward_blocking
	controller.configure(run_config, 0, _run.hp)
	controller.match_started.connect(_on_match_started)
	controller.phase_changed.connect(_on_run_phase_changed)
	_controller = controller
	add_child(controller)
	_set_phase(Phase.IN_NODE)
	controller_changed.emit(controller)
	_save_run()


# Translation key of a node kind's display name (node.<kind>.name rows of strings.csv).
func _node_name_key(kind: String) -> String:
	return "node.%s.name" % kind


# Restores the phase of a resumed run from its position (see the class doc).
func _resume_position() -> void:
	if _run.is_fate_pending() or has_fate_offer():
		# Story 035: the region boss was downed (node already completed): FATE again, no replay.
		_set_phase(Phase.FATE)
		return
	var kind: String = str(_run.current_node().get("kind", ""))
	if kind.is_empty():
		if _run.is_run_won() and not _run.has_pending_reward():
			_finish_run_won()
			return
		if _run.is_choosing_region() and not _run.has_pending_reward():
			_set_phase(Phase.WORLD_MAP)
			return
		_set_phase(Phase.MAP)
	elif kind == KIND_REST:
		_set_phase(Phase.REST)
	elif kind == KIND_TREASURE:
		_set_phase(Phase.MAP)
		if not _run.has_pending_reward():
			_offer_reward(kind)
	elif kind == KIND_SHOP:
		_open_shop()
	elif kind == KIND_EVENT:
		_open_event()
	else:
		_reward_blocking = _run.has_pending_reward()
		_enter_current_node()


# Kind of the node an open offer belongs to, derived from the save: the chosen node (treasure) or
# the node completed last.
func _pending_kind_from_run() -> String:
	if not _run.has_pending_reward():
		return ""
	var chosen: String = str(_run.current_node().get("kind", ""))
	if not chosen.is_empty():
		return chosen
	return _run.last_node_kind


# Player max HP for the run rules outside a battle: the live controller, else the character, else
# combat.json.
func _player_max_hp() -> float:
	if _controller != null:
		return _controller.get_player_max_hp()
	return _character_max_hp(_character_dict())


static func _character_max_hp(character: Dictionary) -> float:
	if character.has("max_hp"):
		return maxf(float(character["max_hp"]), 1.0)
	return CombatConfig.load_from_file().player_max_hp


# Writes the live run (clock included) into the progress and saves through the store.
func _save_run() -> void:
	_sync_elapsed()
	_progress.set_run(_run)
	_store.save_state(_progress)


# Copies the controller's clock into the run (node entry base + this node's PLAYING time).
func _sync_elapsed() -> void:
	if _run != null and _controller != null and _controller.get_state() != null:
		_run.elapsed_sec = _elapsed_base + _controller.get_state().get_elapsed_sec()


func _free_controller() -> void:
	if _controller == null:
		return
	var old: RunController = _controller
	_controller = null
	controller_changed.emit(null)
	remove_child(old)
	old.queue_free()


func _set_phase(phase: Phase) -> void:
	_phase = phase
	phase_changed.emit(phase)


# A match entered PLAYING: the run is at that node with that HP at match start; save it.
func _on_match_started(_match_index: int, hp_at_match_start: float) -> void:
	if _run == null or _run_result != RunResult.NONE:
		return
	_run.hp = hp_at_match_start
	_save_run()
	_arm_odd_hint()


# Story 041: while progress has not seen "hint:odd_block", the live match shows the first-pickup Odd Block hint; when
# it fires the hint is marked seen (and saved), so it never shows again. Never turns a forced (demo) hint off.
func _arm_odd_hint() -> void:
	var view: CombatView = _live_view()
	if view == null or _progress == null or _progress.is_unlock_seen(ODD_HINT_KIND, ODD_HINT_ID):
		return
	view.odd_hint_enabled = true
	if not view.odd_hint_shown.is_connected(_on_odd_hint_shown):
		view.odd_hint_shown.connect(_on_odd_hint_shown)


func _on_odd_hint_shown() -> void:
	if _progress != null and not _progress.is_unlock_seen(ODD_HINT_KIND, ODD_HINT_ID):
		mark_unlock_seen(ODD_HINT_KIND, ODD_HINT_ID)


func _on_run_phase_changed(phase: int) -> void:
	if _run == null or _controller == null or _run_result != RunResult.NONE:
		return
	match phase:
		RunState.Phase.LOST:
			_finish_run_lost()
		RunState.Phase.BETWEEN, RunState.Phase.WON:
			_on_match_won()


# The node's match was won: complete the node (HP carried, boss token / clear) and roll its offer.
func _on_match_won() -> void:
	var passive_heal: float = 0.0
	var battle: Node = _controller.get_battle()
	var view: CombatView = null if battle == null else battle.get_node_or_null(RunController.COMBAT_VIEW_NODE) as CombatView
	if view != null:
		passive_heal = view.get_passive_heal()
		_last_match_stats = view.get_match_stats()
		_run.add_match_stats(_last_match_stats, true)
	else:
		_last_match_stats = {}
	if _is_event_fight_active():
		_process_unlocks(_match_won_event(false, false))
		_finish_event_fight(_controller.get_last_player_hp(), _controller.get_player_max_hp(), passive_heal)
		return
	_complete_match_node(_controller.get_last_player_hp(), _controller.get_player_max_hp(), passive_heal)


# Completes the chosen match node with the given end HP. A region boss: counts the boss, records the
# region in regions_boss_beaten and the new floor in best_floor, leaves the floor-clear notice, then
# opens the boss offer. The final match: the run is won at once (no offer). Others: their offer.
func _complete_match_node(hp_end: float, max_hp: float, passive_heal: float) -> void:
	var kind: String = str(_run.current_node().get("kind", ""))
	# Story 035: a REGION boss (not the final match) waits for its fate; begin_fate before complete_node.
	var fate_node: bool = FateLogic.is_boss_fate_node(kind, _run.is_final_floor())
	if fate_node:
		_run.begin_fate({"floor": _run.floor, "region_id": _run.region_id,
			"match_id": str(_run.current_node().get("match_id", ""))})
	_drop_gold(kind)
	_run.tick_run_modifiers()
	var result: Dictionary = _run.complete_node(hp_end, max_hp, kind, get_reward_config(), passive_heal)
	if kind == KIND_BOSS:
		_record_boss(result)
	# Story 037: milestones of this finished node are written (_record_boss); evaluate the achievements now.
	_process_unlocks(_match_won_event(fate_node, bool(result.get("run_won", false))))
	if bool(result.get("run_won", false)):
		_finish_run_won()
		return
	if fate_node:
		# The node is completed now (end HP / heal belong to the live match); the boss reward waits for the fate.
		_pending_node_kind = kind
		_save_run()
		_set_phase(Phase.FATE)
		run_changed.emit()
		return
	_offer_reward(kind)


# Story 033: the gold of the node being completed (position = floor / column / node, so a resume gives the
# same amount): EconomyConfig.gold_for(kind, floor, hash([run_seed, floor, column, node_index, "gold"])).
func _drop_gold(kind: String) -> void:
	var gold_seed: int = hash([_run.run_seed, _run.floor, _run.column, _run.node_index, GOLD_SEED_TAG]) & ChaptersConfig.SEED_MASK
	_last_gold_gain = EconomyConfig.shared().gold_for(kind, _run.floor, gold_seed)
	if _run.kiep_level > 0: # Story 038 (Kiep 5): gold x economy_mult("gold"), rounded, never below 0
		_last_gold_gain = maxi(roundi(float(_last_gold_gain) * KiepRules.shared().economy_mult("gold", _run.kiep_level)), 0)
	_run.last_gold_gain = _last_gold_gain
	_run.add_gold(_last_gold_gain)


# Rolls the offer of a node kind (RewardRoller.reward_for_node: count and rarity floor) with the
# run's luck, seeded by run seed + position, marks the cards seen, saves. offers 0 or an empty
# pool skips the offer and goes on.
func _offer_reward(kind: String) -> void:
	var cfg: Dictionary = get_reward_config()
	var info: Dictionary = RewardRoller.reward_for_node(kind, cfg)
	_pending_node_kind = kind
	var offers: int = int(info.get("offers", 0))
	if offers <= 0:
		_run.clear_pending_reward()
		_continue_after_reward(false)
		return
	cfg["offer_count"] = offers
	# Skill v2 Q3: the run hero's own `hero_reward` cards (Trảm Địa for the Knight) may be offered in its rewards.
	var offer: Array[String] = RewardRoller.roll(get_cards(), cfg, _reward_seed(), _run.locked_ids("card"), _run.deck_levels(),
		_run.luck(cfg), str(info.get("min_rarity", "common")), get_character_id())
	for id: String in offer:
		_progress.mark_card_seen(id)
	_run.set_pending_reward(offer)
	_run.clear_pending_relic_offer()
	if kind == KIND_TREASURE and not offer.is_empty():
		_run.set_pending_relic_offer(_roll_treasure_relics())
	_run.clear_pending_ink_offer()
	if not offer.is_empty():
		_run.set_pending_ink_offer(_roll_ink_for(kind, false))
	_save_run()
	run_changed.emit()
	if offer.is_empty():
		push_warning("GameFlow: no card to offer, continuing without a reward")
		_continue_after_reward(false)


# Story 032: the relic row of the treasure node being opened: RelicRoller.roll("treasure", owned, rng) with
# an rng seeded by hash([run_seed, floor, column, node_index, "relic"]); [] when nothing can be rolled.
func _roll_treasure_relics() -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_run.run_seed, _run.floor, _run.column, _run.node_index, RELIC_SEED_TAG]) & ChaptersConfig.SEED_MASK
	return _relic_roll(RELIC_SOURCE_TREASURE, _run.relic_ids(), rng)


# The two spots that touch the relic data classes (Story 032).
func _relic_roll(source: String, owned: Array[String], rng: RandomNumberGenerator) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in RelicRoller.roll(source, owned, rng, null, 3, "", _run.locked_ids("relic")):
		out.append(str(id))
	return out


func _relic_info_raw(id: String) -> Dictionary:
	return RelicRegistry.info(id)


# Deterministic offer seed: run seed and the position (floor, region, column, nodes cleared).
func _reward_seed() -> int:
	return hash([_run.run_seed, _run.floor, _run.region_id, _run.column, _run.nodes_cleared]) & ChaptersConfig.SEED_MASK


# The offer was resolved: release a held intro (defensive resume case), complete a fight-less node
# (treasure), then end a won run, show the WORLD_MAP after a region boss, or go back to the MAP.
func _continue_after_reward(deck_changed: bool) -> void:
	if _run == null:
		return
	if _reward_blocking and _controller != null:
		_reward_blocking = false
		if deck_changed:
			_enter_current_node()
		else:
			_controller.hold_intro = false
		return
	if _run.node_index >= 0:
		_run.complete_node(_run.hp, _player_max_hp(), "", get_reward_config(), 0.0)
	_pending_node_kind = ""
	if _run.is_run_won():
		_finish_run_won()
		return
	_return_to_map()


# The rest choice was made: complete the node and go back to the MAP.
func _finish_rest() -> void:
	_run.complete_node(_run.hp, _player_max_hp(), KIND_REST, get_reward_config(), 0.0)
	if _run.is_run_won():
		_finish_run_won()
		return
	_return_to_map()


# Frees the node's controller (clock synced first), shows the WORLD_MAP while a region offer is open,
# else the MAP, and saves.
func _return_to_map() -> void:
	_sync_elapsed()
	_free_controller()
	_set_phase(Phase.WORLD_MAP if _run.is_choosing_region() else Phase.MAP)
	_save_run()
	run_changed.emit()


# The final match fell: the saved run is dropped, result WON (best floor = the final). The RUN THẮNG
# panel lives on the IN_NODE screens.
func _finish_run_won() -> void:
	_sync_elapsed()
	_progress.record_floor(_run.floor + 1)
	# Story 035: the ending of the run's boss fates (world.endings), recorded, shown on the ENDING screen.
	var ending_id: String = _run.ending_id(_config.endings_config())
	_progress.record_ending(ending_id)
	_progress.record_run_won(_run.character_id) # Story 037: runs_won / runs_won:<character>
	_record_kiep_result(true) # Story 038: a win at Kiep k opens k + 1 for this character
	_process_unlocks(_run_ended_event(true, ending_id))
	var line_keys: Array[String] = []
	for i: int in ENDING_LINE_COUNT:
		line_keys.append("ending.%s.line%d" % [ending_id, i + 1])
	_ending = {"id": ending_id, "title_key": "ending.%s.title" % ending_id, "line_keys": line_keys,
		"stats": _stats_with_kiep(_run.stats_summary())}
	_progress.clear_run()
	_store.save_state(_progress)
	_run_result = RunResult.WON
	_set_phase(Phase.ENDING)
	run_changed.emit()


# Story 038: records the finished run's Kiep result into the progress (before it is saved) and remembers the level a win
# newly opened (0 otherwise) for the end screen.
func _record_kiep_result(won: bool) -> void:
	_last_kiep_unlock = 0
	var cid: String = _run.character_id
	var before: int = _progress.get_kiep_unlocked(cid)
	_progress.record_kiep_result(cid, _run.kiep_level, won)
	var after: int = _progress.get_kiep_unlocked(cid)
	if won and after > before:
		_last_kiep_unlock = after


## Story 038: the Kiep level the run that just ended newly opened for its character (the level number), 0 when none
## (a loss, a win below the unlocked level, or already at 10). For the ending screen line "Da mo Kiep k".
func get_kiep_new_unlock() -> int:
	return _last_kiep_unlock


# The player died: the saved run is dropped at once, result LOST (no retry).
func _finish_run_lost() -> void:
	if _run_result != RunResult.NONE:
		return
	_sync_elapsed()
	# Story 035: the match's numbers and where / to whom the run fell, before the save is dropped.
	var view: CombatView = _live_view()
	if view != null:
		_run.add_match_stats(view.get_match_stats(), false)
	_run.record_death({"floor": _run.floor, "region_id": _run.region_id, "match_id": _live_match_id,
		"boss_name_key": _match_name_key(_run.region_id, _live_match_id)})
	_defeat_summary = _stats_with_kiep(_run.stats_summary())
	_record_kiep_result(false) # Story 038: a loss changes nothing (the call keeps the new-unlock line at 0)
	_process_unlocks(_run_ended_event(false, ""))
	_progress.clear_run()
	_store.save_state(_progress)
	_run_result = RunResult.LOST
	run_changed.emit()


# Sets the TranslationServer locale; an unsupported code (old or edited save) falls back to the default.
func _apply_locale(code: String) -> void:
	_locale = code if SUPPORTED_LOCALES.has(code) else ProgressState.DEFAULT_LOCALE
	TranslationServer.set_locale(_locale)


# Save slots: the settings, the slots and the active slot's store. Real files (user://settings.json, user://saves/,
# the legacy progress migrated once) only when nothing was injected and [param dev_memory] is false.
func _setup_slots(dev_memory: bool) -> void:
	var injected: bool = _store != null or _slots != null
	var memory_mode: bool = injected or dev_memory
	if _settings == null:
		_settings = SettingsStore.memory() if memory_mode else SettingsStore.shared()
	if _slots == null:
		_slots = SaveSlots.memory() if memory_mode else SaveSlots.new()
	if not memory_mode:
		_slots.migrate_legacy(_settings)
	_slot_index = clampi(_settings.get_last_slot(), 0, SaveSlots.SLOT_COUNT - 1)
	if _store == null:
		_slots.quarantine_if_corrupt(_slot_index)
		_store = _slots.store_for(_slot_index)


func _load_progress(progress_mode: String) -> ProgressState:
	match progress_mode:
		PROGRESS_ALL:
			# Story 031: "every region boss beaten" (onboarding tier cap off).
			var all := ProgressState.new()
			all.mark_all_regions_beaten(_config.region_ids())
			for _id: String in _config.region_ids():
				all.record_boss_clear()
			# Story 037: every achievement earned and every unlock seen (nothing is locked in the runs of this save).
			all.mark_all_unlocked(AchievementsConfig.shared(), _config.region_ids())
			all.mark_all_kiep(get_characters().ids()) # Story 038: every Kiep level open and won for every character
			return all
		PROGRESS_DEMO:
			return _demo_progress()
		PROGRESS_KIEP3:
			var kiep := ProgressState.new()
			for won_level: int in DEV_KIEP3_WON_LEVELS:
				kiep.record_kiep_result(DEV_KIEP3_CHARACTER, won_level, true)
			return kiep
		PROGRESS_V4SAVE:
			var loaded: ProgressState = ProgressState.from_json(JSON.stringify(_v4_progress_file()), _config)
			_store.save_state(loaded)
			return loaded
		_:
			if progress_mode != PROGRESS_NONE and not progress_mode.is_empty():
				push_warning("GameFlow: unknown --progress=%s (none|all|demo), starting empty" % progress_mode)
			return _store.load_state(_config)


# DEV-ONLY (--progress=v4save): a Story 022 v4 progress file with a chapter run in progress (the shape
# RunSession v4 wrote: chapter id, 7-column map, column, hp, deck, seed).
func _v4_progress_file() -> Dictionary:
	var ci: int = maxi(_config.region_index(DEV_V4_CHAPTER), 0)
	var character: Dictionary = get_characters().get_character(get_characters().default_id())
	var deck: Array = []
	for id: Variant in character.get("starter_deck", []) as Array:
		deck.append({"id": str(id), "level": 1})
	var run: Dictionary = {
		"version": 4, "character": str(character.get("id", "")), "chapter": _config.chapter_id(ci),
		"map": _config.generate_map(ci, DEMO_RUN_SEED, 1), "column": DEV_V4_COLUMN, "node_index": -1,
		"cleared_nodes": [], "hp": DEV_V4_HP, "deck": deck, "run_seed": DEMO_RUN_SEED, "elapsed": 0.0,
		"pending_reward": [], "revives": 0, "removal_tokens": 1, "cleared_bosses_this_run": 0,
	}
	return {"version": 4, "locale": _progress_locale_default(), "cleared_chapters": [_config.chapter_id(0)],
		"seen_cards": [], "cleared_bosses": 1, "run_in_progress": run}


func _progress_locale_default() -> String:
	return _dev_locale if SUPPORTED_LOCALES.has(_dev_locale) else ProgressState.DEFAULT_LOCALE


# DEV-ONLY (--progress=demo): a v5 save at floor 2: the first offered region walked with first nodes and
# its boss beaten, the first floor-2 region chosen and DEMO_RUN_COLUMN columns of it cleared, HP
# DEMO_RUN_HP, a few cards added.
func _demo_progress() -> ProgressState:
	var state := ProgressState.new()
	var character: Dictionary = get_characters().get_character(get_characters().default_id())
	var max_hp: float = _character_max_hp(character)
	var cfg: Dictionary = get_reward_config()
	var session: RunSession = RunSession.begin_world(_config, character, DEMO_RUN_SEED, int(cfg.get("starting_removals", 0)))
	state.record_floor(1)
	while session.floor < DEMO_RUN_FLOOR and not session.is_run_won():
		if session.is_choosing_region():
			if not session.choose_region(session.region_offer[0], state.get_cleared_bosses()):
				break
			continue
		var nodes: Array[Dictionary] = session.available_nodes()
		if nodes.is_empty():
			break
		session.choose_node(int(nodes[0]["node_index"]))
		var result: Dictionary = session.complete_node(session.hp, max_hp, "", cfg, 0.0)
		if bool(result.get("floor_cleared", false)):
			state.record_boss_clear()
			state.add_region_boss_beaten(str(result.get("region", "")))
			state.record_floor(session.floor + 1)
	if session.is_choosing_region():
		session.choose_region(session.region_offer[0], state.get_cleared_bosses())
	for _c: int in DEMO_RUN_COLUMN:
		var nodes: Array[Dictionary] = session.available_nodes()
		if nodes.is_empty() or session.column >= session.map.size() - 1:
			break
		session.choose_node(int(nodes[0]["node_index"]))
		session.complete_node(session.hp, max_hp, "", cfg, 0.0)
	session.hp = DEMO_RUN_HP
	for id: String in RewardRoller.roll(get_cards(), cfg, DEMO_RUN_SEED, [], session.deck_levels(), session.luck(cfg)):
		session.add_card(id)
	state.set_run(session)
	return state


# DEV-ONLY: fresh run advanced to 0-based [param floor_index] (earlier floors walked with the first
# offered region and first nodes, no fights, no rewards). [param region]: "" = stay on that floor's
# WORLD_MAP; DEV_FIRST_OFFERED = pick the first offered region; an id = walk that region (forced into the
# offer when not offered; unknown id: warning, WORLD_MAP).
func _dev_start(floor_index: int, region: String) -> void:
	_begin_run()
	_dev_advance_floors(mini(floor_index, _run.floors() - 1))
	if region.is_empty() or not _run.is_choosing_region():
		_dev_settle_phase()
		return
	var id: String = _run.region_offer[0] if region == DEV_FIRST_OFFERED else region
	if _config.region_index(id) < 0:
		push_warning("GameFlow: unknown region in --region / --node: '%s' (known: %s)" % [id, ", ".join(_config.region_ids())])
		_dev_settle_phase()
		return
	if not _run.region_offer.has(id):
		_run.region_offer = [id] as Array[String]
	choose_region(id)


# DEV-ONLY: walks the run (first offered region, first available node, no fights, no offers) until
# 0-based [param target] floor is reached (the final floor = floors()), recording the progress a real
# boss clear would, then saves.
func _dev_advance_floors(target: int) -> void:
	var cfg: Dictionary = get_reward_config()
	var guard: int = 0
	while _run.floor < target and not _run.is_run_won() and guard < DEV_WALK_GUARD:
		guard += 1
		if _run.is_choosing_region():
			if not _run.choose_region(_run.region_offer[0], _progress.get_cleared_bosses()):
				break
			continue
		var nodes: Array[Dictionary] = _run.available_nodes()
		if nodes.is_empty():
			break
		_run.choose_node(int(nodes[0]["node_index"]))
		var kind: String = str(_run.current_node().get("kind", ""))
		var result: Dictionary = _run.complete_node(_run.hp, _player_max_hp(), kind, cfg, 0.0)
		if kind == KIND_BOSS:
			_record_boss(result)
	_floor_clear_notice = {}
	_save_run()


# DEV-ONLY: the phase of the run's position without an open offer: WORLD_MAP while choosing, else MAP.
func _dev_settle_phase() -> void:
	_set_phase(Phase.WORLD_MAP if _run.is_choosing_region() else Phase.MAP)
	run_changed.emit()


# DEV-ONLY (--node=fF/<region>/cC/nN, legacy chX/cC/nN = floor 1): fresh run at floor F in that region,
# columns before C cleared with their first node (C clamped to the boss column), node N of column C
# chosen (out of range: the first available, warning).
func _apply_dev_node(text: String) -> void:
	var parts: PackedStringArray = text.split("/")
	var floor_index: int = 0
	if parts.size() > 0 and parts[0].begins_with("f") and parts[0].trim_prefix("f").is_valid_int():
		floor_index = maxi(int(parts[0].trim_prefix("f")), 1) - 1
		parts.remove_at(0)
	if parts.is_empty() or _config.region_index(parts[0]) < 0:
		push_warning("GameFlow: unknown region in --node=%s (use e.g. f2/ch1/c1/n0)" % text)
		return
	var column: int = int(parts[1].trim_prefix("c")) if parts.size() > 1 else 0
	var n: int = int(parts[2].trim_prefix("n")) if parts.size() > 2 else 0
	_dev_start(floor_index, parts[0])
	if _run == null or _run.is_choosing_region():
		return
	if column > _run.map.size() - 1:
		push_warning("GameFlow: --node=%s: the region has %d columns, using c%d" % [text, _run.map.size(), _run.map.size() - 1])
		column = _run.map.size() - 1
	_dev_clear_columns(column)
	var nodes: Array[Dictionary] = _run.available_nodes()
	if nodes.is_empty():
		push_warning("GameFlow: --node=%s: column %d has no node" % [text, column])
		return
	if n < 0 or n >= nodes.size():
		push_warning("GameFlow: --node=%s: node %d out of range (column has %d), using n0" % [text, n, nodes.size()])
		n = 0
	choose_node(int(nodes[n]["node_index"]))


# DEV-ONLY: clears the next [param count] columns of the current region with their first available
# node (no fight, HP untouched), never its boss column, and saves.
func _dev_clear_columns(count: int, toward_kind: String = "") -> void:
	var cfg: Dictionary = get_reward_config()
	for _c: int in count:
		var nodes: Array[Dictionary] = _run.available_nodes()
		if nodes.is_empty() or _run.column >= _run.map.size() - 1:
			break
		var pick: int = int(nodes[0]["node_index"])
		if not toward_kind.is_empty():
			for node: Dictionary in nodes:
				if _dev_reaches_kind(_run.column, int(node["node_index"]), toward_kind):
					pick = int(node["node_index"])
					break
		_run.choose_node(pick)
		_run.complete_node(_run.hp, _player_max_hp(), "", cfg, 0.0)
	_save_run()


# DEV-ONLY (2026-11-03, linked columns): true when a node of [param kind] lies after node [param index] of
# column [param col] along its `next` links (a node without `next` reaches the whole next column).
func _dev_reaches_kind(col: int, index: int, kind: String) -> bool:
	if col + 1 >= _run.map.size():
		return false
	var node: Dictionary = (_run.map[col]["nodes"] as Array)[index]
	var following: Array = _run.map[col + 1].get("nodes", []) as Array
	var next: Array = node.get("next", range(following.size())) as Array
	for i: Variant in next:
		if str((following[int(i)] as Dictionary).get("kind", "")) == kind or _dev_reaches_kind(col + 1, int(i), kind):
			return true
	return false


# DEV-ONLY: chooses the first available node of the current column (false when none).
func _dev_choose_first_available() -> bool:
	var nodes: Array[Dictionary] = _run.available_nodes()
	if nodes.is_empty():
		return false
	return choose_node(int(nodes[0]["node_index"]))


# DEV-ONLY: walks the current region forward (clearing columns with their first node, never the boss
# column) until a node of [param kind] is available, then chooses it. False with a warning when none.
func _dev_advance_to_kind(kind: String) -> bool:
	while _run.column < _run.map.size():
		for node: Dictionary in _run.available_nodes():
			if str(node.get("kind", "")) == kind:
				return choose_node(int(node["node_index"]))
		if _run.column >= _run.map.size() - 1:
			break
		_dev_clear_columns(1, kind)
	push_warning("GameFlow: --run=: this region map has no '%s' node (try another --seed / --at-floor)" % kind)
	return false


# DEV-ONLY: the chosen match node is won on the spot (boss dead, phase WON, HP DEV_FLOW_HP) and
# completed like a real win (offer opened; the final match wins the run). [param _offer] is kept for
# old callers (a run is only won by the final match now). [param hp_ratio] >= 0 ends the match at that
# share of max HP instead of DEV_FLOW_HP.
func _dev_win_current_match(_offer: bool, hp_ratio: float = -1.0) -> void:
	if _controller == null:
		return
	var state: RunState = _controller.get_state()
	var battle: Node = _controller.get_battle()
	var view: CombatView = null if battle == null else battle.get_node_or_null(RunController.COMBAT_VIEW_NODE) as CombatView
	if view != null:
		view.get_state().damage(CombatState.Side.ENEMY, 999999.0)
	state.dev_jump(0, RunState.Phase.WON, RunController.DEV_ELAPSED_SEC, -1.0)
	var max_hp: float = _controller.get_player_max_hp()
	_complete_match_node(hp_ratio * max_hp if hp_ratio >= 0.0 else DEV_FLOW_HP, max_hp, 0.0)


# DEV-ONLY (Story 035, --run=ending_*): one boss fate per floor walked (all spare / alternating / all execute)
# and DEV_ENDING_MATCHES x DEV_ENDING_STATS in the run stats, so the ending screen has numbers.
func _dev_fill_fates(kind: String) -> void:
	var path: Array[String] = get_region_path()
	_run.boss_fates.clear()
	for i: int in _run.floors():
		var fate: String = FateLogic.FATE_SPARE
		if kind == FLOW_RUN_ENDING_EXECUTE or (kind == FLOW_RUN_ENDING_BALANCE and i % 2 == 1):
			fate = FateLogic.FATE_EXECUTE
		_run.boss_fates.append({"floor": i, "region_id": path[i] if i < path.size() else "", "match_id": "", "fate": fate})
	for _m: int in DEV_ENDING_MATCHES:
		_run.add_match_stats(DEV_ENDING_STATS, true)
	_save_run()


# DEV-ONLY (Story 033, --run=shop / --run=event=<id>): chooses the region's first [param kind] node
# (columns before it cleared); without one, the current column's first available node becomes that kind.
func _dev_open_special(kind: String) -> void:
	if _run.is_choosing_region():
		return
	for col: int in range(_run.column, _run.map.size() - 1):
		for node: Variant in (_run.map[col].get("nodes", []) as Array):
			if str((node as Dictionary).get("kind", "")) == kind:
				_dev_advance_to_kind(kind)
				return
	var nodes: Array[Dictionary] = _run.available_nodes()
	if nodes.is_empty():
		push_warning("GameFlow: --run=%s: no node to open" % kind)
		return
	var index: int = int(nodes[0]["node_index"])
	var target: Dictionary = (_run.map[_run.column]["nodes"] as Array)[index]
	target["kind"] = kind
	target["match_id"] = ""
	choose_node(index)


# DEV-ONLY (--run=<flow kind>): puts the freshly started run into a capture state.
func _apply_dev_flow_run(kind: String) -> void:
	match kind:
		FLOW_RUN_WORLD, FLOW_RUN_MAP:
			pass
		FLOW_RUN_WORLD3:
			_dev_advance_floors(maxi(_run.floor, DEV_WORLD3_FLOOR))
			_dev_settle_phase()
		FLOW_RUN_FLOORCLEAR:
			if _run.is_choosing_region():
				choose_region(_run.region_offer[0])
			if _dev_advance_to_kind(KIND_BOSS):
				_dev_win_current_match(true, DEV_FLOORCLEAR_HP_RATIO)
				if _run != null and _run.has_pending_reward():
					reward_skipped()
		FLOW_RUN_FINAL:
			_dev_advance_floors(_run.floors())
			_dev_settle_phase()
		FLOW_RUN_MAP3:
			_dev_clear_columns(DEV_MAP3_COLUMNS)
			run_changed.emit()
		FLOW_RUN_REST:
			_dev_advance_to_kind(KIND_REST)
		FLOW_RUN_TREASURE, FLOW_RUN_RELIC_TREASURE:
			_dev_advance_to_kind(KIND_TREASURE)
		FLOW_RUN_MINIBOSS_REWARD:
			if _dev_advance_to_kind("miniboss"):
				_dev_win_current_match(true)
		FLOW_RUN_BOSS_REWARD:
			if _dev_advance_to_kind(KIND_BOSS):
				_dev_win_current_match(true)
		FLOW_RUN_REWARD:
			if _dev_choose_first_available():
				_dev_win_current_match(true)
		FLOW_RUN_GOLD_REWARD:
			if _dev_advance_to_kind(KIND_BATTLE):
				_dev_win_current_match(true)
		FLOW_RUN_SHOP:
			if _dev_gold < 0:
				_run.gold = maxi(_run.gold, DEV_SHOP_GOLD)
			_dev_open_special(KIND_SHOP)
		FLOW_RUN_EVENT:
			_dev_open_special(KIND_EVENT)
		FLOW_RUN_PIECE_DECK:
			if _dev_shape_removals < 0:
				_run.shape_removals = DEV_PIECE_DECK_REMOVALS
			if _dev_piece_deck_state.is_empty():
				_dev_apply_piece_deck_state(DEV_PIECE_DECK_STATE)
			_save_run()
			open_piece_deck()
		FLOW_RUN_INK_OFFER, FLOW_RUN_INK_OFFER_CAPPED:
			if kind == FLOW_RUN_INK_OFFER_CAPPED:
				var first: String = RunSession.piece_library().base_shape_ids()[0]
				_dev_apply_piece_deck_state("mult:%s=%s" % [first, str(get_piece_deck_config().mult_max)])
			if _dev_advance_to_kind(KIND_BATTLE):
				_dev_win_current_match(true)
				if _run != null and _run.has_pending_reward() and not _run.has_pending_ink_offer():
					_run.set_pending_ink_offer(_roll_ink_for(KIND_BATTLE, true))
					_save_run()
					run_changed.emit()
		FLOW_RUN_OVER:
			if _dev_choose_first_available() and _controller != null:
				var battle: Node = _controller.get_battle()
				var view: CombatView = null if battle == null else battle.get_node_or_null(RunController.COMBAT_VIEW_NODE) as CombatView
				if view != null:
					view.get_state().damage(CombatState.Side.PLAYER, 999999.0)
				_controller.get_state().dev_jump(0, RunState.Phase.LOST, RunController.DEV_ELAPSED_SEC, -1.0)
				_finish_run_lost()
		FLOW_RUN_FATE, FLOW_RUN_FATE_RESUMED, FLOW_RUN_FATE_OFFER:
			if _dev_advance_to_kind(KIND_BOSS):
				_dev_win_current_match(true)
				if kind == FLOW_RUN_FATE_OFFER and is_fate_pending():
					choose_fate(FateLogic.FATE_EXECUTE)
				elif kind == FLOW_RUN_FATE_RESUMED and is_fate_pending():
					leave_run_keep_save()
					continue_requested()
		FLOW_RUN_ENDING_SPARE, FLOW_RUN_ENDING_BALANCE, FLOW_RUN_ENDING_EXECUTE:
			_dev_advance_floors(_run.floors())
			_dev_settle_phase()
			_dev_fill_fates(kind)
			# Story 038: past the `world.final_prelude` shop column to the final boss node (as FLOW_RUN_WON does).
			if _dev_advance_to_kind(KIND_BOSS):
				_dev_win_current_match(false)
		FLOW_RUN_WON:
			_dev_advance_floors(_run.floors())
			_dev_settle_phase()
			# TD-029: past the `world.final_prelude` columns to the final boss node.
			if _dev_advance_to_kind(KIND_BOSS):
				_dev_win_current_match(false)


# ---- Story 031 world API (published stubs; implemented in wave 2) ----

## Story 031: 0-based floor of the live run (0..floors-1; == [method get_floor_count] at the final
## match); 0 without a run.
func get_floor() -> int:
	return 0 if _run == null else _run.floor


## Story 031: floors before the final match (chapters.json `world.floors`, 5).
func get_floor_count() -> int:
	return _config.world_floors()


## Story 031: region ids offered at the current floor (WORLD_MAP cards, left to right); [] once one is
## chosen, at the final match or without a run.
func get_region_offer() -> Array[String]:
	if _run == null:
		return [] as Array[String]
	return _run.region_offer.duplicate()


## Story 031: region ids chosen so far, one per floor (index = 0-based floor); [] without a run. Also
## readable on the result screens (until [method leave_run]).
func get_region_path() -> Array[String]:
	if _run == null:
		return [] as Array[String]
	return _run.region_path.duplicate()


## Story 031: id of the region being walked; "" while a region offer is open or without a run. At the
## final match: `world.final_match.region`.
func get_current_region() -> String:
	if _run == null or _run.is_choosing_region():
		return ""
	return _run.region_id


## 2026-11-06: the art area of the region being walked at the current map column (ArtAssets.area_for), for a node
## of kind [param kind] ("" = the current column's first node kind); "" without a run or areas.
func current_art_area(kind: String = "") -> String:
	if _run == null or _run.region_id.is_empty():
		return ""
	var k: String = kind
	if k.is_empty():
		var nodes: Array = _run.current_column().get("nodes", [])
		k = str((nodes[0] as Dictionary).get("kind", "")) if not nodes.is_empty() else ""
	return ArtAssets.area_for(ArtAssets.region_for_chapter(_run.region_id), _run.column, _run.map.size(), k)


## Story 031: translated display name of region [param region_id] ("" when unknown).
func region_name(region_id: String) -> String:
	var ci: int = _config.region_index(region_id)
	return "" if ci < 0 else _config.chapter_name(ci)


## Story 031: WORLD_MAP pick of [param region_id] from the offer: its map is generated for the floor,
## the run is saved and the MAP shows. Ignored with a warning outside WORLD_MAP, without a run, while a
## card offer is still open, or for a region not offered.
func choose_region(region_id: String) -> void:
	if _run == null or _phase != Phase.WORLD_MAP or _run_result != RunResult.NONE:
		push_warning("GameFlow: choose_region('%s') outside the world map, ignored" % region_id)
		return
	if not _run.choose_region(region_id, _progress.get_cleared_bosses()):
		push_warning("GameFlow: choose_region('%s'): not offered (offer: %s), ignored" % [region_id, str(_run.region_offer)])
		return
	_floor_clear_notice = {}
	_save_run()
	_set_phase(Phase.MAP)
	run_changed.emit()


## Story 031: the notice of the last region boss, returned ONCE (then {}): {floor (0-based new floor,
## as [method get_floor]), floor_number (1-based), healed (HP healed, float), is_final (the next match
## is the final one)}; {} when none.
func take_floor_clear_notice() -> Dictionary:
	var notice: Dictionary = _floor_clear_notice
	_floor_clear_notice = {}
	return notice


## Story 031: true while the live run stands at (or plays) the final match.
func is_final_floor() -> bool:
	return _run != null and _run.is_final_floor()


# A boss node completed ([param result] of RunSession.complete_node): a REGION boss counts in the
# permanent progress (boss count, regions_boss_beaten, best_floor) and leaves the floor-clear notice.
func _record_boss(result: Dictionary) -> void:
	if not bool(result.get("floor_cleared", false)):
		return
	_progress.record_boss_clear()
	_progress.add_region_boss_beaten(str(result.get("region", "")))
	_progress.record_floor(_run.floor + 1)
	if _run.is_final_floor():
		_progress.record_final_reached() # Story 037: An Dai reached (the last region boss opens the final floor)
		_process_unlocks({"type": UnlockRules.EVENT_FINAL_REACHED})
	_floor_clear_notice = {
		"floor": _run.floor, "floor_number": _run.floor + 1,
		"healed": float(result.get("healed", 0.0)), "is_final": _run.is_final_floor(),
	}
