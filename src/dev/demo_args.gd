class_name DemoArgs
extends Node
## DEV-ONLY capture hook: puts the screen into a deterministic state for screenshots.
## Godot user args go after "--":
##   godot --path . -- --demo=board     empty board, d-pad, empty hand (no points; time frozen)
##   godot --path . -- --demo=cooldown  player just stepped: cooldown ring visible, d-pad dimmed
##   godot --path . -- --demo=learning   BossLearning fed directly (3 early dodges, 2 interrupts): the debug line under
##                                      the boss HP bar reads "né: 3 | ngắt: 2 | giả: 15%" (with boss_brain.json numbers)
##   godot --path . -- --demo=cooldown --grid=6x6   "grid66_pace": the board-scaled step cooldown on a 6x6 half right
##                                      after a step (0.45 * (2/5)^0.75 = ~0.23 s with combat.json numbers): the ring is
##                                      visibly shorter than on 3x3 (0.45 s). Not a separate mode: the cooldown demo
##                                      takes the --grid override like every demo (verified headless)
##   godot --path . -- --demo=row_warn   Story 014: a RowBurnerTrait built by hand (TraitRegistry.create, setup with
##                                      CombatView.make_trait_ctx(), TraitHost.debug_add_trait) and ticked until it
##                                      announces the player's row with ~0.7 s of warning left: blinking amber
##                                      outline, shrinking top bar, "SẮP CHÁY" tag; the player stands in that row
##   godot --path . -- --demo=row_burning  as row_warn, ticked past the warning: the row is on fire through
##                                      StatusEffects.ignite (existing burn look), 1.0 s of burning elapsed
##   godot --path . -- --demo=formation_half|formation_warn|formation_complete   Story 029: formation map half lit / cells about to fade / completed (flash + banner); skips the intro
##   godot --path . -- --demo=signature_cooldown   Story 029 Phần D: 40% of the enemy cells lit, signature cooldown ~9 s left ("Hồi 9 s"); skips the intro
##   godot --path . -- --demo=signature_ready|signature_half  Story 021: signature charge full / half (needs CombatView.debug_set_signature_charge)
##   godot --path . --character=phap_su -- --demo=thien_hoa_fire   Story 030: the boss's cell already burning (as after a burn card), the
##                                           whole enemy board lit, Thien Hoa fired through the real activate_signature(): the old burn
##                                           detonates (boss HP drop, banner), then every lit cell is set on fire (burn hatch on the whole half)
##   godot --path . --character=phap_su -- --demo=thien_hoa_burning  Story 030: as thien_hoa_fire, then the burn advanced by
##                                           THIEN_HOA_BURNING_DEMO_SEC (StatusEffects.tick): the sea of fire still burning, its DoT on the boss
##   godot --path . --character=sat_thu -- --demo=anh_bo_hit  Story 030: Anh Bo active (blue border, banner) and a 2-cell piece cast resolved on
##                                           the boss: HIT and the doubled "-N"
##   godot --path . -- --character=tho_san --demo=vay_bat   Story 037: Vay Bat active (border, banner) and a real tran_gai cast beside the boss:
##                                           the thorns last 1.5x (zone bars) plus 1 extra thorn cell, hunter_mark put a Ran on the boss; skips the intro
##   godot --path . -- --character=giao_si --demo=thanh_an  Story 037: Thanh An active (border, banner), the boss at 2 Han, the player hurt; a real
##                                           hit adds the 3rd Han: the x1.5 burst damages the boss and Prayer heals ("+8" over the player); skips the intro
##   Story 024 piece demos (the player has a piece bag):
##   godot --path . -- --demo=pieces_hand    three pieces lying on the player's half (mini shapes, freshness bars) and a full bag
##   godot --path . -- --demo=placing_hit    PLACING with a piece (default l4, or --piece=<id>) over the boss's cell: green ghost,
##                                           cell count + damage, Focus active (tint, bar, d-pad locked)
##   godot --path . -- --demo=placing_miss   as placing_hit with the ghost on cells that do not cover the boss: red ghost
##   godot --path . -- --demo=placing_rotated as placing_hit after one 90-degree rotation (CombatView.rotate_piece)
##   godot --path . -- --demo=placing_center a single-cell piece (default mono) on the centre cell of the boss's half
##   godot --path . -- --demo=placing_drag   mid-drag: a simulated finger holds the piece, the ghost floats drag_lift_px above it
##                                           over the boss's cell (green), the "Xoay" button fills the d-pad area
##   godot --path . -- --demo=pieces_menu    the piece placed and Tung phép pressed: card menu open (piece consumed from the bag)
##   godot --path . -- --demo=rotten_piece   a ROTTEN piece on the player's half and in the bag (grey, X, countdown)
##   godot --path . -- --piece=<id>          DEV-ONLY: the shape (pieces.json id) the placing / menu demos use
##   Story 028 join demos (the cast of two pieces; the boss stays still):
##   godot --path . -- --demo=join_menu      place window: piece 1 placed, piece 2 mid-drag (ghost lifted, Xoay shown; no cards yet)
##   godot --path . -- --demo=join_featured  two pieces joined into the match's featured shape (needs --arena=<shape>): glow + label
##   godot --path . -- --demo=join_split     two separate pieces attached in the place window, the total cells shown
##   2026-11-01 card pick demos (quick spec menu-la-giua-man-hinh; real path: drop, join, Tung phép):
##   godot --path . -- --demo=card_placing   two pieces placed (place window, its bar ~60 % left), Tung phép shown, no cards
##   godot --path . -- --demo=card_pick      as card_placing, then Tung phép pressed: grey overlay, 4 cards in the centre
##   godot --path . -- --demo=card_cooldown  as card_pick with three cards on cooldown (started through SkillCooldowns.start and
##                                           ticked apart, one of them in the hand): the left cooldown column with its pies
##                                           and the dimmed hand card with the same pie
##   godot --path . -- --demo=card_cooldown_column  the same three cooldowns with the menu closed (column only, no overlay)
##   Controls v3 (design/quick-specs/bo-cuc-dieu-khien-v3-2026-11-02.md) demos, intro skipped:
##   godot --path . -- --demo=controls_idle      the bag filled, nothing selected (moving state)
##   godot --path . -- --demo=controls_placing   the featured shape's first piece placed, the second being placed over the
##       rest of it (gold ghost + resonance label), the place window at CARD_DEMO_PLACE_LEFT_RATIO (the fuse round Tung phép)
##   godot --path . -- --demo=controls_statuses  Root, Slow, Fragile x2 and Guard on the player part-way through (the
##       buff / debuff row with its pies), two cards cooling down (the column under the row), demo relics, the Slow
##       tooltip open
##   godot --path . -- --arena=<shape>       DEV-ONLY arena shape id of arenas.json (cross, u_shape, ring, ...): sets
##       match_params["arena"] before _ready, so the board and the featured-shape icon follow it. Works with or without --demo.
##   Story 025 boss piece demos (the boss casts puzzle pieces on the player's half and is rooted while it swings):
##   godot --path . -- --demo=boss_placing   the boss mid-swing with a 2-piece JOIN (l3 + bar2) telegraphed on the player's half;
##                                           its hand row shows the third piece, two field pieces lie on its half
##   godot --path . -- --demo=boss_ring_normal  the boss just stepped and is NOT swinging: the normal red cooldown arc, part spent
##   godot --path . -- --demo=boss_rooted    the boss swinging one piece: the ring is the solid steel-blue LOCKED ring
##   godot --path . -- --demo=boss_counter   the boss's swing running, the player casts a piece over the boss through the real path:
##                                           the player's swing resolves first: HIT "-N" on the boss and NGAT on the boss's cast
##   godot --path . -- --demo=boss_rotten    the boss's rotten_thrower (the real trait path) just threw a rotten piece onto the player's half
##   Story 027 zone demos (StatusEffects.apply_thorns called directly with the combat.json "zones" numbers, then
##   ZONE_DEMO_ELAPSED_RATIO of each zone's time ticked through StatusEffects.tick). The seal demos seal_on_boss /
##   boss_seal were deleted with the seal effect (2026-11-01):
##   godot --path . -- --demo=thorns_on_boss thorns on every orthogonal neighbour of the boss (boss half)
##   Story 036 hazard demos (the match's TileHazards, CombatView.get_hazards(), driven through its real calls and ticked in
##   TRAIT_STEP_SEC steps; trait demos use the match's own trait or one built with the region match's chapters.json params;
##   a missing trait prints a warning and the demo stages what it can). Pass --arena=bog|reed_maze|dunes|oasis for the board:
##   godot --path . -- --demo=mire        arena mire on both halves (seeded spread through set_mire when the arena has none);
##                                        the player moved onto a mire cell and ticked past the grace: one mire damage tick
##   godot --path . -- --demo=sand        2 filled sand cells per half (time bars draining) + 2 player cells in the warning blink
##   godot --path . -- --demo=wind        wind on, field pieces on both halves, one drift already run: the HUD wind arrow and a
##                                        streak on each piece the next drift moves
##   godot --path . -- --demo=spore       the player's real cast hits the boss: spore_burst (spore_cap) lays mire on the player's side
##   godot --path . -- --demo=hop         hop_skip (leap_frog): the boss steps through its real mover until a hop is announced: shadow
##   godot --path . -- --demo=burrow      burrow (sand_burrower) ticked until under the sand with the surface circle showing
##   godot --path . -- --demo=riposte     a 4-cell player cast hits the boss: riposte (scorpion) warns the player's cell
##   godot --path . -- --demo=bog_spread  bog_spread (toad_matriarch) ticked until it lays mire on the player's half
##   godot --path . -- --demo=sandstorm   sandstorm (sand_sphinx) ticked into a storm (haze, bar, extra sand) with wind and pieces
##   Story 039 hazard demos (same engine as the 036 ones). Pass --arena=forge|caldera (vents) or twin_isles|three_isles (crumble, islands):
##   godot --path . -- --demo=vent        vents on both halves (set through set_vents when the arena has none): one ERUPTING on the boss's
##                                        half, one in the WARNING on the player's half, the rest idle dark-red streaks
##   godot --path . -- --demo=crumble     crumble on (enable_crumble when the arena lacks it): a fallen cell (void + time bar), the boss's cell in
##                                        the crack warning, the player's cell with a half-grown crack
##   godot --path . -- --arena=twin_isles --demo=crumble --return-ratio=<0..1>   then crumble standing is switched off and
##                                        time runs until the fallen cell comes back, plus k x return_fade_sec: frozen mid
##                                        return fade (0 = full white, the moment it returns; 1 = fade over). Ignored elsewhere
##   godot --path . -- --demo=burn_eater  burn_eater (fire_eater): the boss at 60 % HP on a burning cell ticked once: it heals, green "+N" over it
##   godot --path . -- --demo=rebirth     rebirth (ash_phoenix): a lethal hit on the boss, which revives: the timer bar and ring (rebirth_life = the
##                                        "one life left" badge before the kill)
##   godot --path . -- --demo=gust        gust (gale_bird) ticked until its arrow warning shows on the player's cell
##   godot --path . -- --demo=island_drop island_drop (storm_dragon) ticked until an island of the player's half blinks before it falls
##   godot --path . -- --demo=shroud      shroud (cloud_veil): the placement preview aimed at the boss with the hit forecast blocked (grey shadow + cloud)
##   godot --path . -- --demo=boss_through_thorns  thorns on the boss's divider-side neighbour (and the cell beside it),
##                                           a player swing on the boss's cell, the boss steps into the thorns through its
##                                           real mover (dodge): thorn_entered fires (damage, Ran +1, entry flash)
##   godot --path . -- --demo=trait_seal     the REAL SealCasterTrait: the match's own (a jailer node, e.g. --node=chX/cC/nN
##                                           landing on the ch2 miniboss) or, on any other match, one built through
##                                           TraitRegistry with the jailer's chapters.json params (warning). It is made
##                                           ready at once (ticked past its delay), the boss swings a 3-cell row that ends on
##                                           the player (label off the player), then swing + trait are ticked until seal_cast:
##                                           the chosen cells (the player's own one included when rule 6 allows it) have
##                                           JUST started cracking (drop tile, crack at its first frame, faint red); the
##                                           drop_* demos below show the later moments
##   Drop tile demos (Ô rớt, design/quick-specs/o-rot-thay-tuong-2026-10-31.md; they also skip the intro). The numbers are
##   the seal_caster trait's (the match's own, or built with the jailer's chapters.json params as trait_seal does:
##   get_drop_numbers()); the crack starts through the REAL ZoneRules.cast_drop on the player's half, then
##   StatusEffects.tick runs the given time (time frozen afterwards). Cracked cells = the player's orthogonal neighbours
##   (up to DROP_DEMO_CELLS; cast_drop keeps one safe neighbour open):
##   godot --path . -- --demo=drop_crack     DROP_DEMO_CRACK_RATIO of hole_warn_sec ticked: the crack half spread, red fill mid-way
##   godot --path . -- --demo=drop_on_player the player's own cell (allowed through SealCasterTrait.player_cell_droppable) and one
##                                           neighbour cracking, DROP_DEMO_CRACK_RATIO of the warning ticked: crack under the hero
##   godot --path . -- --demo=drop_hole      the warning ticked out (the cells fell, nobody on them) plus DROP_DEMO_HOLE_RATIO of
##                                           seal_sec: open holes
##   godot --path . -- --demo=drop_return    the warning and seal_sec ticked out (the holes closed), then DROP_DEMO_RETURN_RATIO of
##                                           zones.hole_return_fade_sec: the cells fading back in from white
##   godot --path . -- --demo=drop_fall      ADR-0001 Task 5: as drop_on_player, the warning ticked out: the hero falls with its
##                                           cell (hole_fall_lethal) and time runs again, so the `fall` clip plays
##   godot --path . -- --demo=cast_live --cast-card=<card id> [--cast-cells=N]   ADR-0001 Task 5: the player's real
##                                           CutActor swing of that card over the boss's cell and up to N-1 of its
##                                           neighbours (default 3 cells), time RUNNING (boss inactive): capture a
##                                           frame sequence to see the charge, the delivery's travel and the impacts
##   godot --path . -- --demo=cast_live ... --cast-lock   the same, one non-foe target cell cracking first (locked: no
##                                           charge fill / check / impact drawn on it; Task 5 item 5)
##   godot --path . -- --demo=boss_cast_live --cast-card=<card id> [--cast-cells=N]   Task 5 item 4: the BOSS's real
##                                           CutActor swing of that card over the player's cell (+ neighbours), time
##                                           running: its travel squares / impacts in the enemy block colours
##   add --drop-on-mire (e.g. with --arena=bog, the swamp board) to lay timed mire under the drop cells first: the drop
##   tile must stay readable on mire (ADR-0001 Phase 1, 2026-11-01)
##   godot --path . -- --demo=trait_thorns  the REAL ThornFieldTrait (frost_mage's, or built with its chapters.json params):
##                                           the boss swings a 2x2 block (4 cells) beside the player; the trait lays thorns
##                                           through BossController's swing_started -> TraitHost path
##   godot --path . -- --demo=reward_zone_cards  the card offer forced to ZONE_REWARD_CARDS (GameFlow's run pending reward +
##                                           run_changed), so RewardView shows the zone keyword lines; use with --lang=vi|en
##   (every demo deactivates the boss: BossController.set_active(false); swings are fast-forwarded
##    through SwingArbiter.tick, the boss cuts through BossController's real cut path)
##   godot --path . -- --boss=<set>   DEV-ONLY boss weight set (balanced/aggressive/cautious, see
##       boss_brain.json); sets CombatView.boss_set_override before _ready. Works with or without --demo.
##   godot --path . -- --grid=<cols>x<rows>[:c,r;c,r...]   DEV-ONLY board override
##       <cols>x<rows> = columns x rows of ONE half; the optional list is missing cells in
##       side coordinates (col 0 = farthest from the divider; mirrored to the boss half),
##       e.g. --grid=4x3:0,0;0,2. Combines with any --demo (or none). Replaces side_cols /
##       side_rows / missing_cells of combat.json and clears the start-cell overrides.
##   godot --path . -- --deck=a,b,c    DEV-ONLY player deck (card ids of cards.json, repeats allowed) for the
##       battle: written into CombatView.match_params["deck"] before _ready (Story 017), e.g.
##       --demo=pieces_menu --deck=kiem_khi,chan_phong,hoa_tran shows a 3-card hand with one empty slot.
##   godot --path . -- --drops-seed=N  DEV-ONLY seed of the drops RNG AND the deck shuffle bag (default 7 in
##       every demo): --demo=pieces_menu --drops-seed=1 vs --drops-seed=2 give two different hands.
##   godot --path . -- --debug         DEV overlay: sets CombatView.debug_overlay (Story 016), so the HUD draws its
##       debug text (the boss learning line "né | ngắt | giả"); hidden by default. Works with or without --demo.
##   godot --path . -- --demo=boss_downed   Story 035: GameFlow stages the first offered region's boss node; the boss is hit to 0
##       HP one frame after the intro is skipped: DOWNED (dimmed / kneeling, still drawn), time frozen so the FATE screen never opens
##   godot --path . -- --demo=final_phase2  Story 035: GameFlow stages the final match (an_dai_keeper); one huge hit is clamped at the
##       phase-2 threshold: the phase-2 banner shows, the boss invulnerable, time frozen
##   Story 041 Odd Block (Khoi La) demos: odd pieces come from the REAL OddBlock.generate on the match's board, with the match's
##   odd_blocks config (chance forced to 1, one size kept: the largest or smallest the target half allows), rng seeded
##   ODD_DEMO_SEED + a fixed salt, so the same board gives the same shapes. Pass --arena=<shape> for a bigger board (6-7 cells):
##   godot --path . -- --demo=odd_field   an odd piece (largest size) and a classic one lying on the player's half, an odd piece on the boss's
##   godot --path . -- --demo=odd_bag     the bag: odd (largest size) + classic t4 + odd (smallest size), corner sparkle marks
##   godot --path . -- --demo=odd_place   mid-drag of an odd piece (largest size) from slot 0, the lifted ghost over the boss: green forecast
##                                        with the magenta odd edge and mark
##   godot --path . -- --demo=odd_boss    the boss's hand slot 0 holds an odd piece (largest size for the player's half), cast through the real
##                                        BossController._do_cut: the red telegraph on the player's half with the odd mark
##   godot --path . -- --demo=odd_hint    CombatView.odd_hint_enabled forced on and an odd piece put in the bag: the first-pickup hint line
##                                        under the HP bars (CutHudView.debug_odd_hint_hold keeps it up for the capture)
##   Story 047 art demos (they also skip the intro). Each one fires the real event, then advances the BattleCanvas UnitLayer
##   clock explicitly (UnitLayer.advance: once with 0 so the event starts its clip / overlay, then by the demo's seconds) and
##   freezes, so the sprite frame and the status overlay frame are fixed. They run deferred (after BattleCanvas binds its
##   layers, which happens after this node's _ready). Headless, the SubViewport never draws, so capture windowed:
##   godot --path . -- --demo=anim_step     the player stepped through try_step_player (cell_changed): `step` ART_DEMO_STEP_RATIO of
##                                          the way through its cooldown-long run (frame 2 of 4 on Kiem si at 0.45 s)
##   godot --path . -- --demo=anim_cast     the player's real CutActor swing on the boss's cell (swing_started): `cast_gesture`
##                                          ART_DEMO_ADVANCE_SEC in (frame 1); the swing never resolves (time frozen)
##   godot --path . -- --demo=anim_windup   the boss's CutActor swings on the player's cell (is_swinging, the HUD telegraph on
##                                          the player's half): `windup` held
##   godot --path . -- --demo=anim_windup --telegraph-k=<0..1>   DEV-ONLY (Story 046 Part C): after the boss swing starts,
##                                          CutActor.debug_set_progress(k) puts it k of the way through its windup (time left
##                                          (1-k) x duration), time frozen: the floor telegraph at that strength (0 faint,
##                                          1 = the moment the hit lands). Ignored by every other mode
##   godot --path . -- --demo=anim_hit      the boss hit for ART_DEMO_HIT (CombatState.damage_enemy -> damaged): `hit`
##                                          ART_DEMO_HIT_ADVANCE_SEC in
##   godot --path . -- --demo=anim_down     the boss hit to 0 HP (ART_DEMO_OVERKILL): `down` ART_DEMO_HOLD_ADVANCE_SEC in = its
##                                          last frame held; match_params.end_delay_sec is set to ART_DEMO_END_DELAY_SEC in
##                                          _enter_tree so the match stays on screen (CombatView._tick_end runs on real time)
##   godot --path . -- --demo=anim_defeat   the player hit to 0 HP: `defeat` held; same long end delay
##   godot --path . -- --demo=status_burn   the boss's cell ignited (StatusEffects.ignite, ART_DEMO_STATUS_SEC) and the player
##                                          pinned (StatusEffects.pin): Chay on the boss, Dong Bang on the player,
##                                          ART_DEMO_STATUS_ADVANCE_SEC into the packs (frame 3 at 83 ms)
##   godot --path . -- --demo=status_frozen the player pinned and the boss with ART_DEMO_FROST_STACKS frost stacks: Dong Bang on
##                                          the player, Gia Lanh on the boss
##   godot --path . -- --demo=reduce_motion status_burn with UnitLayer.set_reduce_motion(true): overlays and idle on frame 0
##   godot --path . -- --art-region=<id>    DEV-ONLY art region of the canvas (BattleCanvas.set_region_id, e.g. forest) for any
##                                          boot; named apart from GameFlow's --region=<id> (a fresh run in a world region)
##   godot --path . -- --draw-calls         DEV-ONLY: prints Performance RENDER_TOTAL_DRAW_CALLS_IN_FRAME and the unit ids
##                                          after DRAW_CALLS_FRAMES frames and again after DRAW_CALLS_LATE_FRAMES (intro gone);
##                                          with or without --demo
##   godot --path . -- --pattern=<enemy_id> DEV-ONLY Phase 2 (P2.2): the run's first match is played by the pattern brain:
##                                          match_params `brain` = "pattern" and `enemy` = <enemy_id> of enemy_skills.json
##                                          (e.g. dev_pattern_dummy), set in _enter_tree before CombatView._ready. Time is NOT
##                                          frozen and the boss stays active (a live match, not a demo); pattern_tempo_mult is
##                                          the match's own (1.0 when absent). GameFlow treats it as a dev run arg (a run starts).
##                                          Combine with --seed=<n> and --no-autopause for a reproducible capture
## Every demo freezes time (CombatView.freeze_time) so screenshots are deterministic, and
## seeds the drop RNG. No argument = normal game, this node does nothing. State is set in
## _ready, before the first frame (the seed and the grid in _enter_tree, before
## CombatView._ready). Demo cells are derived from the board, never hardcoded.

const DEMO_PREFIX: String = "--demo="
const GRID_PREFIX: String = "--grid="
## `--player-cell=c,r` (--demo=board): the player starts on that cell of its half, e.g. the back row of a
## 5x5 to check the v3 hero's head against the header (2026-10-31).
const PLAYER_CELL_PREFIX: String = "--player-cell="
const BOSS_PREFIX: String = "--boss="
const DEBUG_ARG: String = "--debug"
const DECK_PREFIX: String = "--deck="
const DROPS_SEED_PREFIX: String = "--drops-seed="
const PIECE_PREFIX: String = "--piece="
const ARENA_PREFIX: String = "--arena="
## Phase 2 (P2.2): `--pattern=<enemy_id>` runs the match on the pattern brain (see the header).
const PATTERN_PREFIX: String = "--pattern="
## `--return-ratio=k` (--demo=crumble only): freeze the fallen cell k of the way through its return fade
## (TileHazards.return_fade_sec; ADR-0001 Phase 1, 2026-11-01).
const RETURN_RATIO_PREFIX: String = "--return-ratio="
const DEMO_SEED: int = 7
## Uid base of the boss's synthetic hand pieces.
const BOSS_UID_BASE: int = -100
## Seconds the boss piece demos fast-forward the running swing (so the countdown is mid-way).
const SWING_ELAPSED_SEC: float = 0.3
## Story 035 final_phase2: frames waited at most for the HUD to connect TraitHost.phase_changed before the hit.
const HUD_CONNECT_MAX_FRAMES: int = 30
## Story 010 / 014 demos: seconds of burning elapsed in "row_burning" and the learning events fed by
## the "learning" demo.
const BURN_ELAPSED_SEC: float = 1.0
const LEARNING_DODGES: int = 3
const LEARNING_INTERRUPTS: int = 2
## Story 014 / 024 demos: the rotten piece's field freshness (s) and its rot countdown once held (s),
## the warning left (s) when "row_warn" is captured, the step used to walk a trait to its warning, and
## the walk's bound (steps) so a misconfigured trait cannot hang.
const ROTTEN_FIELD_FRESHNESS: float = 5.0
const ROTTEN_HAND_LEFT_SEC: float = 4.2
const ROW_WARN_LEFT_SEC: float = 0.7
const TRAIT_STEP_SEC: float = 0.05
const TRAIT_MAX_STEPS: int = 10000
## Story 024 piece demos: default shape of the placing demos and of the single-cell one, the bag
## contents of the other demos as [shape id, rotation], freshness (s) of the lying pieces, the slot
## the rotten piece sits in.
const PLACING_DEFAULT_PIECE: String = "l4"
const CENTER_DEFAULT_PIECE: String = "mono"
const BAG_PIECES: Array = [["t4", 0], ["bar3", 1], ["square", 0]]
const FIELD_PIECES: Array = [["l3", 0], ["bar2", 1], ["plus5", 0]]
const FIELD_PIECE_FRESHNESS: Array[float] = [7.0, 4.5, 2.5]
const ROTTEN_PIECE_SLOT: int = 1
## Story 024 demos that also skip the match intro banner (so the board is visible for a capture).
## Share of the Focus cooldown already recovered in the card cooldown demos.
const CARD_DEMO_FOCUS_RECOVERED: float = 0.35
const PIECE_DEMOS: Array[String] = ["boss_placing", "boss_ring_normal", "boss_rooted", "boss_counter", "boss_rotten", "pieces_hand", "placing_hit", "placing_miss", "placing_rotated", "placing_center", "placing_drag", "pieces_menu", "rotten_piece", "join_menu", "join_featured", "join_split", "card_placing", "card_pick", "card_cooldown", "card_cooldown_column", "controls_idle", "controls_placing", "controls_statuses", "formation_half", "formation_warn", "formation_complete", "signature_cooldown", "thien_hoa_fire", "thien_hoa_burning", "anh_bo_hit", "thorns_on_boss", "boss_through_thorns", "trait_seal", "trait_thorns", "reward_zone_cards"]
## Story 025 boss piece demos: the boss's hand (shape ids), how many of them each demo casts, the piece the counter-cast
## uses, the boss's field pieces as [shape id, rotation] with their freshness (s), and the share of the step cooldown
## still left in "boss_ring_normal".
const BOSS_DEMO_HAND: Array[String] = ["l3", "bar2", "square"]
const BOSS_DEMO_CAST_JOIN: int = 2
const BOSS_DEMO_CAST_SINGLE: int = 1
const BOSS_DEMO_FIELD: Array = [["t4", 0], ["bar3", 1]]
const BOSS_DEMO_FIELD_FRESHNESS: Array[float] = [6.0, 3.0]
const BOSS_DEMO_RING_LEFT: float = 0.65
const BOSS_DEMO_COUNTER_PIECE: String = "bar2"
## Story 030 demo: the piece of the "anh_bo_hit" cast (2 cells, <= Anh Bo's small_cells).
const ANH_BO_DEMO_PIECE: String = "bar2"
## Story 037 demos (they also skip the intro): Vay Bat (Hunter) and Thanh An (Priest), the share of max HP the Priest
## demo starts with and the Han stacks the boss already carries before the hit that bursts (dev capture only).
const SIGNATURE_DEMOS_037: Array[String] = ["vay_bat", "thanh_an"]
const THANH_AN_DEMO_HP_RATIO: float = 0.6
const THANH_AN_DEMO_FROST_STACKS: int = 2
const VAY_BAT_DEMO_ZONE_ELAPSED_RATIO: float = 0.2
## Story 029 Phần D demo: share of the enemy cells lit and the cooldown seconds left (dev capture only).
const SIGNATURE_COOLDOWN_DEMO_CHARGE: float = 0.4
const SIGNATURE_COOLDOWN_DEMO_SEC: float = 9.0
## Story 030 "thien_hoa_burning" demo: seconds of burn advanced after the activation (dev capture only).
const THIEN_HOA_BURNING_DEMO_SEC: float = 1.0
## Story 027 zone demos: share of each zone's duration (combat.json "zones") already elapsed when captured.
const ZONE_DEMO_ELAPSED_RATIO: float = 0.3
## Story 027 zone demos: orthogonal steps in preference order (the first one points toward the divider on the boss half).
const ZONE_DEMO_STEPS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT]
## Story 027 trait demos: the chapters.json matches whose trait params are used when the booted match lacks the
## trait, the cards forced into the "reward_zone_cards" offer, and the bound (steps) of the walk to seal_cast.
const CHAPTERS_PATH: String = "res://assets/data/chapters.json"
const SEAL_TRAIT_MATCH: String = "jailer"
const THORN_TRAIT_MATCH: String = "frost_mage"
## Quick spec 2026-10-31: the Wall cards are boss-only now, so the zone offer is thorn cards only.
const ZONE_REWARD_CARDS: Array[String] = ["tran_gai", "gai_doc", "gai_nguyen"]
## Drop tile demos (quick spec 2026-10-31, they also skip the intro): the most player neighbours cracked, the share of
## the crack warning ticked in drop_crack / drop_on_player, of the hole time in drop_hole, of the return fade in drop_return.
const DROP_DEMOS: Array[String] = ["drop_crack", "drop_on_player", "drop_hole", "drop_return", "drop_fall"]
## ADR-0001 Task 5 cast_live demo args.
const CAST_CARD_PREFIX: String = "--cast-card="
const CAST_CELLS_PREFIX: String = "--cast-cells="
const CAST_DEMO_CELLS: int = 3
## Task 5 item 5 evidence: `--cast-lock` cracks the first non-foe cell of the cast_live mask (StatusEffects.apply_drop
## on the enemy half) before the swing, so the cast runs over a locked cell.
const CAST_LOCK_ARG: String = "--cast-lock"
const CAST_LOCK_WARN_SEC: float = 5.0
const DROP_DEMO_CELLS: int = 3
## Dev flag for the drop demos: timed mire under the drop cells (seconds of mire long enough to outlast the demo).
const DROP_ON_MIRE_ARG: String = "--drop-on-mire"
const DROP_ON_MIRE_SEC: float = 600.0
const DROP_DEMO_CRACK_RATIO: float = 0.5
const DROP_DEMO_HOLE_RATIO: float = 0.3
const DROP_DEMO_RETURN_RATIO: float = 0.5
## Story 036 hazard demos (they also skip the intro), the trait each needs as [trait id, chapters.json match whose
## params build it when the booted match lacks it], the mire / sand cells staged per half, the share of the warning /
## sand / storm time already elapsed at capture, the cells of the riposte demo's cast and the boss-hit wait bound.
const HAZARD_DEMOS: Array[String] = ["mire", "sand", "wind", "spore", "hop", "burrow", "riposte", "bog_spread", "sandstorm",
	"vent", "crumble", "burn_eater", "rebirth", "rebirth_life", "gust", "island_drop", "shroud"]
const HAZARD_TRAITS: Dictionary = {
	"spore": ["spore_burst", "spore_cap"], "hop": ["hop_skip", "leap_frog"], "burrow": ["burrow", "sand_burrower"],
	"riposte": ["riposte", "scorpion"], "bog_spread": ["bog_spread", "toad_matriarch"], "sandstorm": ["sandstorm", "sand_sphinx"],
	"burn_eater": ["burn_eater", "fire_eater"], "rebirth": ["rebirth", "ash_phoenix"], "rebirth_life": ["rebirth", "ash_phoenix"],
	"gust": ["gust", "gale_bird"], "island_drop": ["island_drop", "storm_dragon"], "shroud": ["shroud", "cloud_veil"],
}
## Story 039 hazard demos: vent warning / eruption share staged, the burn_eater burn (duration, tick, damage per tick), how long the
## demo heal number stays up, the share of the revive time elapsed and the cells tried for the fallen cell.
const HAZARD_DEMO_VENT_ERUPT_RATIO: float = 0.3
const HAZARD_DEMO_VENT_WARN_RATIO: float = 0.6
const HAZARD_DEMO_CRUMBLE_RATIO: float = 0.5
const HAZARD_DEMO_BURN_SEC: float = 3.0
const HAZARD_DEMO_BURN_TICK_SEC: float = 0.5
const HAZARD_DEMO_BURN_DAMAGE: float = 5.0
const HAZARD_DEMO_BOSS_HP_RATIO: float = 0.6
const HAZARD_DEMO_HEAL_HOLD_SEC: float = 600.0
const HAZARD_DEMO_REVIVE_RATIO: float = 0.4
const HAZARD_DEMO_DROP_TRIES: int = 8
const HAZARD_DEMO_MIRE_CELLS: int = 3
const HAZARD_DEMO_SAND_CELLS: int = 2
const HAZARD_DEMO_WARN_RATIO: float = 0.4
const HAZARD_DEMO_ELAPSED_RATIO: float = 0.3
const HAZARD_DEMO_RIPOSTE_CELLS: int = 4
const HAZARD_DEMO_MAX_STEPS: int = 2000
## Story 041 odd demos (they also skip the intro): the generator seed, the salts of each odd piece, the classic pieces shown
## beside the odd ones and their freshness on the field.
const ODD_DEMOS: Array[String] = ["odd_field", "odd_bag", "odd_place", "odd_boss", "odd_hint"]
const ODD_DEMO_SEED: int = 4101
const ODD_SALT_PLAYER: int = 0
const ODD_SALT_SMALL: int = 1
const ODD_SALT_BOSS: int = 2
const ODD_DEMO_CLASSIC: String = "l3"
const ODD_DEMO_BAG_CLASSIC: String = "t4"
const ODD_DEMO_FRESHNESS: Array[float] = [7.0, 5.0, 6.0]
## Story 028 join demos: piece 1 and piece 2 of "join_menu" / "join_split" (--piece= overrides piece 1).
const JOIN_PIECE_1: String = "l3"
const JOIN_PIECE_2: String = "bar2"
## Slot of the second piece in the join demos' bag.
const JOIN_SLOT_2: int = 1
## 2026-11-01 card pick demos: the share of the place window left in the capture, the fallback cooldown of each demo
## the seconds ticked after each cooldown start (three cards; the first started recovers most).
const CARD_DEMO_PLACE_LEFT_RATIO: float = 0.6
## Controls v3 statuses demo: seconds each status is applied for, the seconds ticked after (so the pies are part-way),
## the Slow step multiplier, the Fragile stacks and the Guard amount, the cards put on cooldown and the relics shown.
const CONTROLS_ROOT_SEC: float = 4.0
const CONTROLS_SLOW_SEC: float = 6.0
const CONTROLS_GUARD_SEC: float = 8.0
const CONTROLS_TICK_SEC: float = 1.5
const CONTROLS_SLOW_MULT: float = 1.5
const CONTROLS_FRAGILE_STACKS: int = 2
const CONTROLS_GUARD_AMOUNT: float = 4.0
const CONTROLS_COOLDOWN_TICKS: Array[float] = [1.0, 3.0]
const CONTROLS_TOOLTIP_ID: String = "slow"
const CARD_DEMO_COOLDOWN_TICKS: Array[float] = [2.0, 1.5, 1.0]
## Story 047 art demos (they also skip the intro; see the header): the UnitLayer seconds advanced after the event (a once
## clip mid-way, a held clip past its end, a status overlay a few frames in), the hit size, the overkill of the death demos,
## the status duration and frost stacks, the end delay that keeps a finished match on screen, and the dev flags.
const ART_DEMO_ADVANCE_SEC: float = 0.1
const ART_DEMO_STEP_RATIO: float = 0.5
const ART_DEMO_HIT_ADVANCE_SEC: float = 0.05
const ART_DEMO_HOLD_ADVANCE_SEC: float = 0.5
const ART_DEMO_STATUS_ADVANCE_SEC: float = 0.3
const ART_DEMO_HIT: float = 5.0
const ART_DEMO_OVERKILL: float = 9999.0
const ART_DEMO_STATUS_SEC: float = 10.0
const ART_DEMO_FROST_STACKS: int = 2
const ART_DEMO_END_DELAY_SEC: float = 600.0
const ART_REGION_PREFIX: String = "--art-region="
## Story 046 Part C: `--telegraph-k=<0..1>` for --demo=anim_windup (see the header).
const TELEGRAPH_K_PREFIX: String = "--telegraph-k="
const DRAW_CALLS_ARG: String = "--draw-calls"
## Controls v3 captures: --shot=<png path> saves the root viewport's image (its real size, whatever the window) after
## --shot-frame=N frames (default SHOT_DEFAULT_FRAME) and quits. The movie writer records 1280x720 whatever
## --resolution says, so the 1600x720 / 2400x1080 evidence is taken this way.
const SHOT_ARG: String = "--shot="
const SHOT_FRAME_ARG: String = "--shot-frame="
const SHOT_DEFAULT_FRAME: int = 30
## --shot-size=WxH resizes the window from script first (the command line clamps --resolution to the monitor).
const SHOT_SIZE_ARG: String = "--shot-size="
var _shot_path: String = ""
var _shot_frame: int = SHOT_DEFAULT_FRAME
var _shot_count: int = 0
const DRAW_CALLS_FRAMES: int = 2
const DRAW_CALLS_LATE_FRAMES: int = 110

@export var hold_slots_view_path: NodePath = NodePath("../HoldSlotsView")
@export var combat_view_path: NodePath = NodePath("../CombatView")

var _mode: String = ""


## Story 032 demos: the bag size of relic_bag4 and the relics relic_flash shows (first one flashing).
const RELIC_BAG4_SLOTS: int = 4
const RELIC_FLASH_IDS: Array[String] = ["an_don", "chi_khau", "tui_rong", "huyet_an"]


func _enter_tree() -> void:
	_mode = _parse_mode()
	# Runs before any sibling _ready, so the grid and drops are created with these.
	var arena_id: String = _parse_arena()
	if not arena_id.is_empty():
		_combat().match_params["arena"] = {"shape": arena_id}
	var pattern_enemy: String = _parse_pattern()
	if not pattern_enemy.is_empty():
		_combat().match_params["brain"] = RunConfig.BRAIN_PATTERN
		_combat().match_params["enemy"] = pattern_enemy
		_apply_pattern_hints(pattern_enemy, arena_id.is_empty())
	if _mode != "":
		_combat().drops_seed = DEMO_SEED
	if _mode == "boss_downed":
		# Story 035: downing needs a region boss match; forced so the demo also works on a --match= boot.
		_combat().match_params[CombatView.PARAM_BOSS_CAN_DOWN] = true
	if _mode == "anim_down" or _mode == "anim_defeat":
		# Story 047: the match end timer runs on real time even while frozen; keep the dead unit on screen.
		_combat().match_params["end_delay_sec"] = ART_DEMO_END_DELAY_SEC
	_combat().grid_override = _parse_grid()
	_combat().boss_set_override = _parse_boss_set()
	_combat().debug_overlay = OS.get_cmdline_user_args().has(DEBUG_ARG)
	var deck: Array[String] = _parse_deck()
	if not deck.is_empty():
		_combat().match_params["deck"] = deck
	var drops_seed: int = _parse_drops_seed()
	if drops_seed >= 0:
		_combat().drops_seed = drops_seed


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(SHOT_ARG):
			_shot_path = arg.substr(SHOT_ARG.length())
		elif arg.begins_with(SHOT_FRAME_ARG):
			_shot_frame = maxi(int(arg.substr(SHOT_FRAME_ARG.length())), 1)
		elif arg.begins_with(SHOT_SIZE_ARG):
			var wh: PackedStringArray = arg.substr(SHOT_SIZE_ARG.length()).split("x")
			if wh.size() == 2:
				get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	set_process(not _shot_path.is_empty())
	if OS.get_cmdline_user_args().has(DRAW_CALLS_ARG):
		_print_draw_calls()
	if not _parse_art_region().is_empty():
		_apply_art_region.call_deferred()
	if _mode == "":
		return
	var combat: CombatView = _combat()
	combat.freeze_time = true
	# The boss stays still in every demo (no decisions, no clocks).
	combat.get_boss().set_active(false)
	var grid: BoardGrid = combat.get_grid()
	match _mode:
		"board":
			var start: Vector2i = _parse_player_cell()
			if start != BoardGrid.NO_CELL and not combat.get_state().set_player_cell(start):
				push_warning("DemoArgs: --player-cell %s is not a player cell" % start)
		"relic_bag4":
			# Story 032: the 4-slot bag (tui_rong) as CombatView sizes it; intro skipped for the capture.
			var view := get_node(hold_slots_view_path) as HoldSlotsView
			if view.has_method("set_slot_count_override"):
				view.call("set_slot_count_override", RELIC_BAG4_SLOTS)
			_skip_intro()
		"relic_flash":
			# Story 032: the in-match relic strip with one icon mid-flash (as on a `triggered`).
			_skip_intro()
			for hud: Node in get_tree().root.find_children("*", "CutHudView", true, false):
				var cut_hud := hud as CutHudView
				if cut_hud.get_relic_strip().get_relics().is_empty():
					cut_hud.debug_show_relics(RELIC_FLASH_IDS)
				cut_hud.call_deferred("_sync_relic_strip")
				cut_hud.get_relic_strip().set_relics(RELIC_FLASH_IDS)
				cut_hud.get_relic_strip().flash(RELIC_FLASH_IDS[0])
		"cooldown":
			if not combat.try_step_player(Vector2i.RIGHT):
				push_warning("DemoArgs: demo cooldown step failed")
		"learning":
			var learning: BossLearning = combat.get_learning()
			var here: Vector2i = combat.get_state().player_cell
			var away: Vector2i = _other_player_cell(grid, here)
			var swing_cells: Array[Vector2i] = [here]
			for _i: int in LEARNING_DODGES:
				learning.on_boss_swing_started(swing_cells, here)
				learning.on_player_moved(away)
				learning.on_boss_swing_resolved(false)
			for _i: int in LEARNING_INTERRUPTS:
				learning.on_player_interrupted_boss()
		"row_warn", "row_burning":
			var burner: RowBurnerTrait = _make_row_burner(combat)
			if burner != null:
				# Walk the trait (sim time) to its first warning; the player's row is the default pick.
				var steps: int = 0
				while burner.get_warning_cells().is_empty() and steps < TRAIT_MAX_STEPS:
					burner.on_tick(TRAIT_STEP_SEC)
					steps += 1
				if burner.get_warning_cells().is_empty():
					push_warning("DemoArgs: the row burner never warned for demo '%s'" % _mode)
				elif _mode == "row_warn":
					burner.on_tick(maxf(burner.get_warn_left() - ROW_WARN_LEFT_SEC, 0.0))
				else:
					burner.on_tick(burner.get_warn_left() + 0.001)
					combat.get_status().tick(BURN_ELAPSED_SEC, combat.get_state())
		"signature_ready", "signature_half":
			# Story 021: the signature charge bar full (ready) or half full; the dev hook is Part 1's
			# CombatView.debug_set_signature_charge(ratio).
			if combat.has_method("debug_set_signature_charge"):
				combat.call("debug_set_signature_charge", 1.0 if _mode == "signature_ready" else 0.5)
			else:
				push_warning("DemoArgs: CombatView.debug_set_signature_charge missing, signature demo skipped")
		"formation_half", "formation_warn", "formation_complete":
			_formation_demo(combat, grid)
		"signature_cooldown":
			# Story 029 Phần D: some cells lit and the signature cooldown ~9 s left ("Hồi 9 s" button).
			combat.debug_set_signature_charge(SIGNATURE_COOLDOWN_DEMO_CHARGE)
			combat.debug_set_signature_cooldown(SIGNATURE_COOLDOWN_DEMO_SEC)
		"thien_hoa_fire", "thien_hoa_burning":
			_thien_hoa_demo(combat, grid)
		"anh_bo_hit":
			_anh_bo_demo(combat, grid)
		"vay_bat":
			_vay_bat_demo(combat, grid)
		"thanh_an":
			_thanh_an_demo(combat, grid)
		"thorns_on_boss", "boss_through_thorns":
			_zone_demo(combat, grid)
		"trait_seal":
			_trait_seal_demo(combat, grid)
		"drop_crack", "drop_on_player", "drop_hole", "drop_return", "drop_fall":
			_drop_demo(combat, grid)
		"cast_live", "boss_cast_live":
			_skip_intro()
			_cast_live_demo.call_deferred()
		"trait_thorns":
			_trait_thorns_demo(combat, grid)
		"mire", "sand", "wind", "spore", "hop", "burrow", "riposte", "bog_spread", "sandstorm", \
		"vent", "crumble", "burn_eater", "rebirth", "rebirth_life", "gust", "island_drop", "shroud":
			_hazard_demo(combat, grid)
		"reward_zone_cards":
			_force_reward_offer.call_deferred()
		"boss_downed", "final_phase2":
			_final_boss_demo.call_deferred()
		"boss_placing", "boss_ring_normal", "boss_rooted", "boss_counter", "boss_rotten":
			_boss_piece_demo(combat, grid)
		"pieces_hand":
			var lib: PieceLibrary = PieceLibrary.load_from_file()
			var spots: Array[Vector2i] = _spread_cells(grid, FIELD_PIECES.size() + 1)
			var placed: int = 0
			for cell: Vector2i in spots:
				if cell == combat.get_state().player_cell or placed >= FIELD_PIECES.size():
					continue
				var spec: Array = FIELD_PIECES[placed]
				combat.get_drops().debug_place_piece(lib.make_piece(str(spec[0]), int(spec[1])), cell, FIELD_PIECE_FRESHNESS[placed])
				placed += 1
			_fill_bag(lib, -1)
		"placing_hit", "placing_miss", "placing_rotated", "placing_center", "placing_drag", "pieces_menu":
			_placing_demo(combat, grid)
		"join_menu", "join_featured", "join_split":
			_join_demo(combat, grid)
		"card_placing", "card_pick", "card_cooldown", "card_cooldown_column":
			_card_pick_demo(combat, grid)
		"controls_idle", "controls_placing", "controls_statuses":
			_controls_demo(combat, grid)
		"odd_field", "odd_bag", "odd_place", "odd_boss", "odd_hint":
			_odd_demo(combat, grid)
		"anim_step", "anim_cast", "anim_windup", "anim_hit", "anim_down", "anim_defeat", "status_burn", "status_frozen", "status_swap", "reduce_motion":
			# Deferred: BattleCanvas binds its layers (and the UnitLayer connects the match signals) in a deferred
			# call queued by its own _ready, which ran before this one.
			_art_demo.call_deferred()
		"rotten_piece":
			var lib2: PieceLibrary = PieceLibrary.load_from_file()
			var rotten_cell2: Vector2i = _other_player_cell(grid, combat.get_state().player_cell)
			if combat.get_drops().place_rotten_piece(rotten_cell2, ROTTEN_FIELD_FRESHNESS, ROTTEN_HAND_LEFT_SEC) == null:
				push_warning("DemoArgs: could not place the rotten piece on %s" % str(rotten_cell2))
			_fill_bag(lib2, ROTTEN_PIECE_SLOT)
		_:
			push_warning("DemoArgs: unknown demo mode '%s'" % _mode)
	if PIECE_DEMOS.has(_mode) or HAZARD_DEMOS.has(_mode) or SIGNATURE_DEMOS_037.has(_mode) or ODD_DEMOS.has(_mode) \
			or DROP_DEMOS.has(_mode):
		_skip_intro.call_deferred()


# Story 047 art demos (see the header): the real event, then the UnitLayer advanced by hand (0 to start what the event
# asked for, then the demo's seconds) with time frozen; prints the clips and overlays reached so a capture log shows them.
func _art_demo() -> void:
	_skip_intro()
	var combat: CombatView = _combat()
	var canvas: BattleCanvas = combat.get_battle_canvas()
	var units: UnitLayer = canvas.get_unit_layer() if canvas != null else null
	if units == null:
		push_warning("DemoArgs: no BattleCanvas / UnitLayer bound for demo '%s'" % _mode)
		return
	var grid: BoardGrid = combat.get_grid()
	var state: CombatState = combat.get_state()
	var status: StatusEffects = combat.get_status()
	var player: int = CombatState.Side.PLAYER
	var enemy: int = CombatState.Side.ENEMY
	var advance_sec: float = ART_DEMO_ADVANCE_SEC
	match _mode:
		"anim_step":
			var stepped: bool = false
			for dir: Vector2i in ZONE_DEMO_STEPS:
				if grid.is_player_cell(state.player_cell + dir) and combat.try_step_player(dir):
					stepped = true
					break
			if not stepped:
				push_warning("DemoArgs: the player could not step for demo '%s'" % _mode)
		"anim_cast":
			if not combat.get_cut_actor().begin_swing([state.enemy_cell] as Array[Vector2i], SkillConfig.FALLBACK_SKILL, true):
				push_warning("DemoArgs: the player swing did not start for demo '%s'" % _mode)
			# 2026-10-31: --telegraph-k=<0..1> also sets the player's swing progress (the cast projectile mid-flight).
			var cast_k: float = _parse_telegraph_k()
			if cast_k >= 0.0:
				combat.get_cut_actor().debug_set_progress(cast_k)
				print("DemoArgs: cast k=%.2f time_left=%.3f" % [cast_k, combat.get_cut_actor().get_time_left()])
		"anim_windup":
			var boss_actor: CutActor = combat.get_boss().get_actor()
			if not boss_actor.begin_swing([state.player_cell] as Array[Vector2i], SkillConfig.FALLBACK_SKILL, false):
				push_warning("DemoArgs: the boss swing did not start for demo '%s'" % _mode)
			var k: float = _parse_telegraph_k()
			if k >= 0.0:
				boss_actor.debug_set_progress(k)
				print("DemoArgs: telegraph k=%.2f progress=%.2f" % [k, boss_actor.get_progress()])
		"anim_hit":
			state.damage_enemy(ART_DEMO_HIT)
			advance_sec = ART_DEMO_HIT_ADVANCE_SEC
		"anim_down":
			state.damage_enemy(ART_DEMO_OVERKILL)
			advance_sec = ART_DEMO_HOLD_ADVANCE_SEC
		"anim_defeat":
			state.damage_player(ART_DEMO_OVERKILL)
			advance_sec = ART_DEMO_HOLD_ADVANCE_SEC
		"status_burn", "reduce_motion":
			status.ignite([state.enemy_cell] as Array[Vector2i], ART_DEMO_STATUS_SEC, HAZARD_DEMO_BURN_TICK_SEC, HAZARD_DEMO_BURN_DAMAGE)
			status.pin(player, ART_DEMO_STATUS_SEC)
			advance_sec = ART_DEMO_STATUS_ADVANCE_SEC
			if _mode == "reduce_motion":
				units.set_reduce_motion(true)
		"status_frozen":
			status.pin(player, ART_DEMO_STATUS_SEC)
			status.apply_frost(enemy, ART_DEMO_FROST_STACKS)
			advance_sec = ART_DEMO_STATUS_ADVANCE_SEC
		"status_swap":
			# 2026-10-31: the pack pairings the two demos above leave out: the hero burning and chilled, the boss frozen.
			status.ignite([state.player_cell] as Array[Vector2i], ART_DEMO_STATUS_SEC, HAZARD_DEMO_BURN_TICK_SEC, HAZARD_DEMO_BURN_DAMAGE)
			status.apply_frost(player, ART_DEMO_FROST_STACKS)
			status.pin(enemy, ART_DEMO_STATUS_SEC)
			advance_sec = ART_DEMO_STATUS_ADVANCE_SEC
	# The first update starts the clip / overlay the event asked for (as the next frame would); the second moves into it.
	units.advance(0.0)
	if _mode == "anim_step":
		# The step clip spans the step cooldown the layer just read: go to its middle.
		advance_sec = units.get_step_left(player) * ART_DEMO_STEP_RATIO
	units.advance(advance_sec)
	combat.freeze_time = true
	var line: String = "DemoArgs: %s" % _mode
	for side: int in [player, enemy]:
		var anim: UnitAnimator = units.get_animator(side)
		line += " | %s %s clip=%s frame=%d status=%s" % ["player" if side == player else "boss", units.get_unit_id(side),
			anim.current_clip() if anim != null else units.get_current_clip(side), anim.frame_index() if anim != null else 0,
			str(units.get_active_status_kinds(side))]
	print(line)


# --draw-calls: RENDER_TOTAL_DRAW_CALLS_IN_FRAME after DRAW_CALLS_FRAMES frames and after DRAW_CALLS_LATE_FRAMES (the intro
# banner gone by then), with the unit ids of the match; the game keeps running (quit with --quit-after).
func _print_draw_calls() -> void:
	var frames: int = 0
	for target: int in [DRAW_CALLS_FRAMES, DRAW_CALLS_LATE_FRAMES]:
		while frames < target:
			await get_tree().process_frame
			frames += 1
		var ids: Dictionary = UnitLayer.unit_ids_for(_combat().match_params)
		print("DemoArgs: draw_calls frame=%d total=%d units=%s vs %s" % [frames,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			ids[CombatState.Side.PLAYER], ids[CombatState.Side.ENEMY]])


# --art-region=<id>: switches the canvas region once BattleCanvas is bound (deferred after its own bind).
func _apply_art_region() -> void:
	var canvas: BattleCanvas = _combat().get_battle_canvas()
	if canvas == null:
		push_warning("DemoArgs: no BattleCanvas bound, --art-region ignored")
		return
	canvas.set_region_id(_parse_art_region())


# ADR-0001 Task 5: the player's real swing of --cast-card over the boss's cell (+ neighbours), time running; with
# boss_cast_live the boss's swing over the player's cell instead (item 4).
func _cast_live_demo() -> void:
	var combat: CombatView = _combat()
	var grid: BoardGrid = combat.get_grid()
	var card: String = SkillConfig.FALLBACK_SKILL
	var n: int = CAST_DEMO_CELLS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(CAST_CARD_PREFIX):
			card = arg.substr(CAST_CARD_PREFIX.length())
		elif arg.begins_with(CAST_CELLS_PREFIX):
			n = maxi(arg.substr(CAST_CELLS_PREFIX.length()).to_int(), 1)
	var boss: bool = _mode == "boss_cast_live"
	var foe: Vector2i = combat.get_state().player_cell if boss else combat.get_state().enemy_cell
	var cells: Array[Vector2i] = [foe]
	for d: Vector2i in [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]:
		var on_half: bool = grid.is_player_cell(foe + d) if boss else grid.is_enemy_cell(foe + d)
		if cells.size() < n and on_half:
			cells.append(foe + d)
	if OS.get_cmdline_user_args().has(CAST_LOCK_ARG) and cells.size() > 1 and combat.get_status() != null:
		var side: int = CombatState.Side.PLAYER if boss else CombatState.Side.ENEMY
		combat.get_status().apply_drop(side, [cells[1]] as Array[Vector2i], CAST_LOCK_WARN_SEC, CAST_LOCK_WARN_SEC)
		print("DemoArgs: cast_live locked %s" % str(cells[1]))
	var actor: CutActor = combat.get_boss().get_actor() if boss else combat.get_cut_actor()
	if not actor.begin_swing(cells, card, not boss):
		push_warning("DemoArgs: the swing did not start for demo '%s'" % _mode)
		return
	combat.freeze_time = false
	print("DemoArgs: %s card=%s cells=%s duration=%.3f delivery=%s" % [_mode, card, str(cells),
		actor.get_time_left(), str(combat.delivery_for(card))])


# --telegraph-k=<0..1> clamped; -1 when absent or not a number.
func _parse_telegraph_k() -> float:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(TELEGRAPH_K_PREFIX):
			var raw: String = arg.substr(TELEGRAPH_K_PREFIX.length())
			if raw.is_valid_float():
				return clampf(raw.to_float(), 0.0, 1.0)
			push_warning("DemoArgs: --telegraph-k needs a number 0..1, got '%s'" % raw)
	return -1.0


func _parse_art_region() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(ART_REGION_PREFIX):
			return arg.substr(ART_REGION_PREFIX.length())
	return ""


# Story 041 odd demos (see the header), through the real paths: debug_place_piece for the field, the bag's points, begin_drag /
# drag_to for the drag, BossController._do_cut for the boss's cast, CombatView's own bag scan for the hint.
func _odd_demo(combat: CombatView, grid: BoardGrid) -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	print("DemoArgs: %s on halves of %d (player) / %d (boss) cells" % [_mode, grid.player_cells().size(), grid.enemy_cells().size()])
	match _mode:
		"odd_field":
			var odd: Piece = _odd_piece(combat, lib, true, true, ODD_SALT_PLAYER)
			var spots: Array[Vector2i] = _spread_cells(grid, 3)
			var placed: int = 0
			for cell: Vector2i in spots:
				if cell == combat.get_state().player_cell or placed >= 2:
					continue
				var piece: Piece = odd if placed == 0 else lib.make_piece(ODD_DEMO_CLASSIC, 1)
				if piece != null:
					combat.get_drops().debug_place_piece(piece, cell, ODD_DEMO_FRESHNESS[placed])
				placed += 1
			var boss_odd: Piece = _odd_piece(combat, lib, false, true, ODD_SALT_BOSS)
			if boss_odd != null:
				combat.get_boss().get_drops().debug_place_piece(boss_odd, _free_enemy_cell(grid, combat, 0), ODD_DEMO_FRESHNESS[2])
		"odd_bag":
			_fill_bag(lib, -1)
			_set_bag_piece(0, _odd_piece(combat, lib, true, true, ODD_SALT_PLAYER))
			_set_bag_piece(1, lib.make_piece(ODD_DEMO_BAG_CLASSIC, 0))
			_set_bag_piece(2, _odd_piece(combat, lib, true, false, ODD_SALT_SMALL))
		"odd_place":
			_fill_bag(lib, -1)
			_set_bag_piece(0, _odd_piece(combat, lib, true, true, ODD_SALT_PLAYER))
			var boss_cell: Vector2i = combat.get_state().enemy_cell
			if not combat.begin_drag(0, _hold_slot_centre(0)):
				push_warning("DemoArgs: begin_drag failed for demo '%s'" % _mode)
				return
			var placement: PlacementController = combat.get_placement()
			# Walk the finger over the enemy cells (boss's cell first), turning the piece between walks, until the
			# lifted ghost covers the boss; an odd shape may need a turn to reach it.
			var targets: Array[Vector2i] = [boss_cell]
			targets.append_array(grid.enemy_cells())
			for _turn: int in 4:
				for cell: Vector2i in targets:
					combat.drag_to(combat.drag_point_for_cell(cell))
					if placement.hits(boss_cell):
						break
				if placement.hits(boss_cell):
					break
				combat.rotate_piece()
			if not placement.hits(boss_cell):
				push_warning("DemoArgs: the dragged odd ghost does not cover the boss for demo '%s'" % _mode)
		"odd_boss":
			var boss: BossController = combat.get_boss()
			_boss_piece_hand(boss, lib)
			var boss_odd2: Piece = _odd_piece(combat, lib, false, true, ODD_SALT_BOSS)
			var slot0: FieldPoint = boss.get_hand().get_point(0)
			if boss_odd2 == null or slot0 == null:
				return
			slot0.piece = boss_odd2
			slot0.label = boss_odd2.shape_id
			# A big odd shape may only fit over the player's cell: move the player to the first cell it can leave free.
			var player_cells: Array[Vector2i] = [combat.get_state().player_cell]
			player_cells.append_array(grid.player_cells())
			for cell: Vector2i in player_cells:
				if not _boss_piece_cells(grid, [boss_odd2] as Array[Piece], cell).is_empty():
					combat.get_state().set_player_cell(cell)
					break
			_boss_piece_cut(combat, grid, BOSS_DEMO_CAST_SINGLE)
			combat.get_arbiter().tick(SWING_ELAPSED_SEC)
		"odd_hint":
			combat.odd_hint_enabled = true
			for hud: Node in get_tree().root.find_children("*", "CutHudView", true, false):
				(hud as CutHudView).debug_odd_hint_hold = true
			var odd2: Piece = _odd_piece(combat, lib, true, false, ODD_SALT_SMALL)
			if odd2 != null:
				var point := FieldPoint.new()
				point.uid = -1
				point.freshness_left = 0.0
				point.piece = odd2
				point.label = odd2.shape_id
				_hold().place(point, 0)


# Story 041: puts [param piece] into the bag point of slot [param index] (filled by _fill_bag); no-op on null.
func _set_bag_piece(index: int, piece: Piece) -> void:
	var point: FieldPoint = _hold().get_point(index)
	if point == null or piece == null:
		return
	point.piece = piece
	point.label = piece.shape_id


# Story 041: an Odd Block for the target half ([param target_is_enemy]: the boss's half, as the player's drops) from the real
# OddBlock.generate, with the match's odd config (chance 1, only one size kept: the largest or smallest the half allows; when
# the generator gives up on it the next size is tried), rng seeded ODD_DEMO_SEED + [param salt]. Null + warning when none.
func _odd_piece(combat: CombatView, lib: PieceLibrary, target_is_enemy: bool, prefer_largest: bool, salt: int) -> Piece:
	var grid: BoardGrid = combat.get_grid()
	var base: OddBlockConfig = combat.get_drops_config().odd
	var target: int = grid.enemy_cells().size() if target_is_enemy else grid.player_cells().size()
	var sizes: Array[int] = base.allowed_sizes(target)
	if not prefer_largest:
		sizes.reverse()
	while not sizes.is_empty():
		var cfg: OddBlockConfig = base.copy()
		cfg.chance = 1.0
		var size: int = sizes.pop_back()
		cfg.size_weights = {size: 1.0}
		var rng := RandomNumberGenerator.new()
		rng.seed = ODD_DEMO_SEED + salt
		var piece: Piece = OddBlock.generate(lib, grid, target_is_enemy, cfg, rng)
		if piece != null:
			return piece
	push_warning("DemoArgs: no odd block fits the %s half for demo '%s'" % ["boss's" if target_is_enemy else "player's", _mode])
	return null


# Story 025 boss piece demos. The boss hand holds BOSS_DEMO_HAND as pieces; boss_placing casts a 2-piece join through
# the real BossController._do_cut (DEV-ONLY private call) with the player OUTSIDE the cells,
# boss_rooted casts one piece, boss_ring_normal only steps the boss (no cast), boss_counter casts and then runs the
# player's real cast over the boss, boss_rotten runs the real rotten_thrower trait.
func _boss_piece_demo(combat: CombatView, grid: BoardGrid) -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var boss: BossController = combat.get_boss()
	_boss_piece_hand(boss, lib)
	for i: int in BOSS_DEMO_FIELD.size():
		var spec: Array = BOSS_DEMO_FIELD[i]
		var cell: Vector2i = _free_enemy_cell(grid, combat, i)
		boss.get_drops().debug_place_piece(lib.make_piece(str(spec[0]), int(spec[1])), cell, BOSS_DEMO_FIELD_FRESHNESS[i])
	match _mode:
		"boss_placing":
			_boss_piece_cut(combat, grid, BOSS_DEMO_CAST_JOIN)
			combat.get_arbiter().tick(SWING_ELAPSED_SEC)
		"boss_rooted":
			_boss_piece_cut(combat, grid, BOSS_DEMO_CAST_SINGLE)
			combat.get_arbiter().tick(SWING_ELAPSED_SEC)
		"boss_ring_normal":
			var step: Vector2i = Vector2i.UP if grid.is_enemy_cell(combat.get_state().enemy_cell + Vector2i.UP) else Vector2i.DOWN
			if not boss.get_mover().try_step(step):
				push_warning("DemoArgs: the boss could not step for demo '%s'" % _mode)
			boss.get_mover().tick(boss.get_mover().get_cooldown_remaining() * (1.0 - BOSS_DEMO_RING_LEFT))
		"boss_counter":
			_boss_piece_cut(combat, grid, BOSS_DEMO_CAST_JOIN)
			_fill_bag(lib, -1)
			var held: FieldPoint = _hold().get_point(0)
			held.piece = lib.make_piece(BOSS_DEMO_COUNTER_PIECE, 0)
			held.label = BOSS_DEMO_COUNTER_PIECE
			if not combat.select_piece(0):
				push_warning("DemoArgs: select_piece failed for demo '%s'" % _mode)
				return
			_aim_hitting(combat, grid, combat.get_state().enemy_cell)
			if not combat.press_cast():
				push_warning("DemoArgs: press_cast failed for demo '%s'" % _mode)
				return
			if not combat.get_cut_flow().choose(SkillConfig.FALLBACK_SKILL):
				push_warning("DemoArgs: skill not available for demo '%s'" % _mode)
				return
			combat.get_arbiter().tick(combat.get_cut_actor().get_time_left() + 0.001)
		"boss_rotten":
			var thrower: RottenThrowerTrait = TraitRegistry.create(RottenThrowerTrait.ID) as RottenThrowerTrait
			if thrower == null:
				push_warning("DemoArgs: TraitRegistry could not create '%s'" % RottenThrowerTrait.ID)
				return
			thrower.setup(combat.make_trait_ctx(), {"first_delay_sec": 0.0, "field_freshness_sec": ROTTEN_FIELD_FRESHNESS}, DEMO_SEED)
			thrower.on_match_start()
			combat.get_trait_host().debug_add_trait(thrower)
			thrower.on_tick(TRAIT_STEP_SEC)
			if thrower.get_throw_count() == 0:
				push_warning("DemoArgs: the rotten thrower did not throw for demo '%s'" % _mode)


# Story 027 zone demos (see the header). Zones go straight through the StatusEffects API with the combat.json
# "zones" numbers; ZONE_DEMO_ELAPSED_RATIO of the duration is then ticked (time is frozen afterwards).
func _zone_demo(combat: CombatView, grid: BoardGrid) -> void:
	var status: StatusEffects = combat.get_status()
	var state: CombatState = combat.get_state()
	var cfg: CombatConfig = combat.get_config()
	var boss: BossController = combat.get_boss()
	var enemy: int = CombatState.Side.ENEMY
	match _mode:
		"thorns_on_boss":
			var around: Array[Vector2i] = _zone_neighbours(grid, state.enemy_cell, true, false)
			status.apply_thorns(enemy, around, cfg.thorn_sec, cfg.thorn_damage, cfg.thorn_fragile_stacks)
			status.tick(cfg.thorn_sec * ZONE_DEMO_ELAPSED_RATIO, state)
		"boss_through_thorns":
			var from: Vector2i = state.enemy_cell
			var around2: Array[Vector2i] = _zone_neighbours(grid, from, true, false)
			if around2.is_empty():
				push_warning("DemoArgs: no cell beside the boss for demo '%s'" % _mode)
				return
			var target: Vector2i = around2[0]
			var thorns: Array[Vector2i] = [target]
			for step: Vector2i in [Vector2i.UP, Vector2i.DOWN]:
				if grid.is_enemy_cell(target + step) and thorns.size() < 2:
					thorns.append(target + step)
			status.apply_thorns(enemy, thorns, cfg.thorn_sec, cfg.thorn_damage, cfg.thorn_fragile_stacks)
			# First tick only records where each unit stands (StatusEffects._check_thorn_entries).
			status.tick(0.0, state)
			if not combat.get_cut_actor().begin_swing([from] as Array[Vector2i], SkillConfig.FALLBACK_SKILL, true):
				push_warning("DemoArgs: the player swing did not start for demo '%s'" % _mode)
			if not boss.get_mover().try_step(target - from):
				push_warning("DemoArgs: the boss could not step into the thorns for demo '%s'" % _mode)
			status.tick(cfg.thorn_sec * ZONE_DEMO_ELAPSED_RATIO, state)


# Story 027: the real seal_caster on the boss's swing (see the header).
func _trait_seal_demo(combat: CombatView, grid: BoardGrid) -> void:
	var seal: SealCasterTrait = _zone_trait(combat, SealCasterTrait.ID, SEAL_TRAIT_MATCH) as SealCasterTrait
	if seal == null:
		return
	# Ready at once: tick the trait past its delay with no boss swing running (nothing is cast).
	seal.on_tick(seal.get_next_seal_left() + TRAIT_STEP_SEC)
	var here: Vector2i = combat.get_state().player_cell
	var swing: Array[Vector2i] = []
	for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if grid.is_player_cell(here + step) and grid.is_player_cell(here + step * 2):
			swing = [here + step * 2, here + step, here] as Array[Vector2i]
			break
	# Arenas without a straight 3-cell row through the player (the jailer's U): any 3 connected cells.
	if swing.is_empty():
		for first: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			for second: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var a: Vector2i = here + first
				var b: Vector2i = a + second
				if swing.is_empty() and b != here and grid.is_player_cell(a) and grid.is_player_cell(b):
					swing = [b, a, here] as Array[Vector2i]
	if swing.is_empty():
		push_warning("DemoArgs: no 3 connected cells through the player for demo '%s'" % _mode)
		return
	var actor: CutActor = combat.get_boss().get_actor()
	if not actor.begin_swing(swing, SkillConfig.FALLBACK_SKILL, false):
		push_warning("DemoArgs: the boss swing did not start for demo '%s'" % _mode)
		return
	var steps: int = 0
	while seal.get_seal_count() == 0 and actor.is_swinging() and steps < TRAIT_MAX_STEPS:
		combat.get_arbiter().tick(TRAIT_STEP_SEC)
		seal.on_tick(TRAIT_STEP_SEC)
		steps += 1
	if seal.get_seal_count() == 0:
		push_warning("DemoArgs: seal_caster never cast for demo '%s'" % _mode)
	else:
		print("DemoArgs: seal_cast ", seal.get_last_cells())


# Drop tile demos (see the header): the crack starts through the real ZoneRules.cast_drop with the seal_caster trait's
# numbers, then the real StatusEffects.tick runs the demo's time, phase by phase (time is frozen afterwards).
func _drop_demo(combat: CombatView, grid: BoardGrid) -> void:
	var status: StatusEffects = combat.get_status()
	var state: CombatState = combat.get_state()
	var cfg: CombatConfig = combat.get_config()
	var player: int = CombatState.Side.PLAYER
	var warn_sec: float = cfg.hole_warn_sec
	var hole_sec: float = cfg.seal_sec
	var seal: SealCasterTrait = _zone_trait(combat, SealCasterTrait.ID, SEAL_TRAIT_MATCH) as SealCasterTrait
	if seal != null:
		var numbers: Dictionary = seal.get_drop_numbers()
		warn_sec = float(numbers["warn_sec"])
		hole_sec = float(numbers["hole_sec"])
	var here: Vector2i = state.player_cell
	var cells: Array[Vector2i] = []
	var own_ok: bool = false
	if _mode == "drop_on_player" or _mode == "drop_fall":
		own_ok = seal != null and seal.player_cell_droppable()
		if not own_ok:
			push_warning("DemoArgs: the player's cell may not crack now (rule 6) for demo '%s'" % _mode)
		cells.append(here)
	for cell: Vector2i in _zone_neighbours(grid, here, false, false):
		if cells.size() < (2 if _mode == "drop_on_player" or _mode == "drop_fall" else DROP_DEMO_CELLS):
			cells.append(cell)
	if OS.get_cmdline_user_args().has(DROP_ON_MIRE_ARG) and combat.get_hazards() != null:
		combat.get_hazards().add_mire(player, cells, DROP_ON_MIRE_SEC)
	var mover: UnitMover = combat.make_trait_ctx().get("player_mover") as UnitMover
	var blocked: Callable = Callable(mover, "is_cell_blocked") if mover != null else Callable()
	var cracked: Array[Vector2i] = ZoneRules.cast_drop(state, grid, status, player, cells, warn_sec, hole_sec, own_ok, blocked)
	if cracked.is_empty():
		push_warning("DemoArgs: nothing started cracking for demo '%s'" % _mode)
		return
	match _mode:
		"drop_crack", "drop_on_player":
			status.tick(warn_sec * DROP_DEMO_CRACK_RATIO, state)
		"drop_fall":
			status.tick(warn_sec + 0.001, state)
			combat.freeze_time = false
		"drop_hole":
			status.tick(warn_sec, state)
			status.tick(hole_sec * DROP_DEMO_HOLE_RATIO, state)
		"drop_return":
			status.tick(warn_sec, state)
			status.tick(hole_sec, state)
			status.tick(status.hole_return_fade_sec * DROP_DEMO_RETURN_RATIO, state)
	print("DemoArgs: %s cells=%s crack=%s holes=%s returning=%s player=%s hp=%.1f" % [_mode, str(cracked),
		str(status.crack_cells(player)), str(status.hole_cells(player)), str(status.returning_cells(player)), str(here),
		state.player_hp])


# Story 027: the real thorn_field on a 4-cell boss swing beside the player (see the header).
func _trait_thorns_demo(combat: CombatView, grid: BoardGrid) -> void:
	var field: ThornFieldTrait = _zone_trait(combat, ThornFieldTrait.ID, THORN_TRAIT_MATCH) as ThornFieldTrait
	if field == null:
		return
	field.on_tick(field.get_cooldown_left() + TRAIT_STEP_SEC)
	var here: Vector2i = combat.get_state().player_cell
	var best: Array[Vector2i] = []
	var best_dist: float = INF
	for a: Vector2i in grid.player_cells():
		var block: Array[Vector2i] = [a, a + Vector2i.RIGHT, a + Vector2i.DOWN, a + Vector2i.ONE]
		var ok: bool = not block.has(here)
		for c: Vector2i in block:
			ok = ok and grid.is_player_cell(c)
		var dist: float = (Vector2(a) + Vector2(0.5, 0.5)).distance_to(Vector2(here))
		if ok and dist < best_dist:
			best = block
			best_dist = dist
	if best.is_empty():
		push_warning("DemoArgs: no 2x2 block beside the player for demo '%s'" % _mode)
		return
	if not combat.get_boss().get_actor().begin_swing(best, SkillConfig.FALLBACK_SKILL, false):
		push_warning("DemoArgs: the boss swing did not start for demo '%s'" % _mode)
	if field.get_field_count() == 0:
		push_warning("DemoArgs: thorn_field laid nothing for demo '%s'" % _mode)
	else:
		print("DemoArgs: thorns_laid ", field.get_last_cells())


# Story 036 hazard demos (see the header). Every number comes from the match's merged hazards config or the trait's params.
func _hazard_demo(combat: CombatView, grid: BoardGrid) -> void:
	var hazards: TileHazards = combat.get_hazards()
	if hazards == null:
		push_warning("DemoArgs: CombatView has no TileHazards for demo '%s'" % _mode)
		return
	var state: CombatState = combat.get_state()
	var cfg: Dictionary = hazards.get_debug().get("cfg", {}) as Dictionary
	var player: int = CombatState.Side.PLAYER
	var enemy: int = CombatState.Side.ENEMY
	var hazard_trait: BossTrait = null
	if HAZARD_TRAITS.has(_mode):
		var spec: Array = HAZARD_TRAITS[_mode]
		hazard_trait = _zone_trait(combat, str(spec[0]), str(spec[1]))
		if hazard_trait == null:
			push_warning("DemoArgs: trait '%s' missing, demo '%s' stages only the board" % [spec[0], _mode])
	match _mode:
		"mire":
			for side: int in [player, enemy]:
				if hazards.mire_cells(side).is_empty():
					hazards.set_mire(side, _hazard_spread(grid, side, HAZARD_DEMO_MIRE_CELLS, state))
			var mire: Array[Vector2i] = hazards.mire_cells(player)
			if not mire.is_empty() and not state.set_player_cell(mire[0]):
				push_warning("DemoArgs: could not move the player onto mire %s" % str(mire[0]))
			_tick_hazards(hazards, null, state, float(cfg.get("mire_grace_sec", 0.0)) + float(cfg.get("mire_tick_sec", 0.0)) + TRAIT_STEP_SEC)
		"sand":
			var warn: float = float(cfg.get("sand_warn_sec", 0.0))
			var sec: float = float(cfg.get("sand_sec", 0.0))
			var cells: Array[Vector2i] = _hazard_spread(grid, player, HAZARD_DEMO_SAND_CELLS * 2, state)
			var filled: Array[Vector2i] = []
			var warned: Array[Vector2i] = []
			for i: int in cells.size():
				(filled if i % 2 == 0 else warned).append(cells[i])
			hazards.add_sand(player, filled, sec, warn)
			hazards.add_sand(enemy, _hazard_spread(grid, enemy, HAZARD_DEMO_SAND_CELLS, state), sec, warn)
			_tick_hazards(hazards, null, state, warn + sec * HAZARD_DEMO_ELAPSED_RATIO)
			hazards.add_sand(player, warned, sec, warn)
			_tick_hazards(hazards, null, state, warn * HAZARD_DEMO_WARN_RATIO)
		"wind":
			_wind_with_pieces(combat, grid, hazards)
			_tick_hazards(hazards, null, state, float(cfg.get("drift_sec", 0.0)) + TRAIT_STEP_SEC)
		"spore":
			_player_cast_on_boss(combat, grid, 1)
			_tick_until(hazards, hazard_trait, state, func() -> bool: return not hazards.mire_cells(player).is_empty())
		"riposte":
			_player_cast_on_boss(combat, grid, hazard_trait.param_int("min_cells", HAZARD_DEMO_RIPOSTE_CELLS) if hazard_trait != null else HAZARD_DEMO_RIPOSTE_CELLS)
			_tick_until(hazards, hazard_trait, state, func() -> bool: return _trait_float(hazard_trait, "get_riposte_warn_left") > 0.0)
			_tick_hazards(hazards, hazard_trait, state, _trait_float(hazard_trait, "get_riposte_warn_left") * HAZARD_DEMO_ELAPSED_RATIO)
		"bog_spread":
			var before: int = hazards.mire_cells(player).size()
			_tick_until(hazards, hazard_trait, state, func() -> bool: return hazards.mire_cells(player).size() > before)
		"burrow":
			_tick_until(hazards, hazard_trait, state, func() -> bool: return _trait_float(hazard_trait, "get_surface_warn_left") > 0.0)
		"hop":
			var mover: UnitMover = combat.get_boss().get_mover()
			# hop_skip only announces for an active boss; time stays frozen, so the brain still never acts.
			combat.get_boss().set_active(true)
			var steps: int = 0
			while hazard_trait != null and not grid.is_enemy_cell(_trait_cell(hazard_trait, "get_hop_target")) and steps < HAZARD_DEMO_MAX_STEPS:
				# Ready the mover, let the trait look (it announces only while the boss could step), then step.
				mover.tick(mover.get_cooldown_remaining() + TRAIT_STEP_SEC)
				_tick_hazards(hazards, hazard_trait, state, TRAIT_STEP_SEC)
				steps += 1
				if grid.is_enemy_cell(_trait_cell(hazard_trait, "get_hop_target")):
					break
				for dir: Vector2i in ZONE_DEMO_STEPS:
					if mover.try_step(dir if steps % 2 == 0 else -dir):
						break
			if hazard_trait != null and not grid.is_enemy_cell(_trait_cell(hazard_trait, "get_hop_target")):
				push_warning("DemoArgs: hop_skip announced no hop for demo '%s'" % _mode)
		"sandstorm":
			_wind_with_pieces(combat, grid, hazards)
			_tick_until(hazards, hazard_trait, state, func() -> bool: return hazard_trait.has_method("is_storm") and bool(hazard_trait.call("is_storm")))
			_tick_hazards(hazards, hazard_trait, state, hazard_trait.param_float("storm_sec", 0.0) * HAZARD_DEMO_ELAPSED_RATIO if hazard_trait != null else 0.0)
		"vent":
			_vent_demo(hazards, grid, state)
		"crumble":
			_crumble_demo(hazards, grid, state)
		"burn_eater":
			_burn_eater_demo(combat, hazards, state)
		"rebirth", "rebirth_life":
			if _mode == "rebirth" and hazard_trait != null:
				state.damage_enemy(state.enemy_hp + 1.0)
				if state.is_enemy_dead():
					push_warning("DemoArgs: rebirth did not catch the lethal hit")
				_tick_hazards(hazards, hazard_trait, state, hazard_trait.param_float("revive_sec", 0.0) * HAZARD_DEMO_REVIVE_RATIO)
		"gust":
			_tick_until(hazards, hazard_trait, state, func() -> bool: return _trait_float(hazard_trait, "get_gust_warn_left") > 0.0)
			_tick_hazards(hazards, hazard_trait, state, _trait_float(hazard_trait, "get_gust_warn_left") * HAZARD_DEMO_ELAPSED_RATIO)
		"island_drop":
			if hazards.islands(player).size() < 2:
				push_warning("DemoArgs: the player's half has fewer than 2 islands, pass --arena=twin_isles or three_isles")
			_tick_until(hazards, hazard_trait, state, func() -> bool: return _trait_float(hazard_trait, "get_drop_warn_left") > 0.0)
			_tick_hazards(hazards, hazard_trait, state, _trait_float(hazard_trait, "get_drop_warn_left") * HAZARD_DEMO_ELAPSED_RATIO)
		"shroud":
			_placing_demo(combat, grid)
	print("DemoArgs: hazards ", hazards.get_debug())


# Story 039 "vent": vents are staged per half when the arena has none (a whole row each, side rows 0 and the last), then the boss
# half's first vent erupts and the player half's first vent is mid-warning.
func _vent_demo(hazards: TileHazards, grid: BoardGrid, state: CombatState) -> void:
	var player: int = CombatState.Side.PLAYER
	var enemy: int = CombatState.Side.ENEMY
	for side: int in [player, enemy]:
		if not hazards.vent_cells(side).is_empty():
			continue
		var cells: Array[Vector2i] = grid.player_cells() if side == player else grid.enemy_cells()
		var vents: Array = []
		for row: int in [0, grid.rows - 1]:
			var line: Array[Vector2i] = []
			for cell: Vector2i in cells:
				if cell.y == row:
					line.append(cell)
			if not line.is_empty():
				vents.append(line)
		hazards.set_vents(side, vents)
	var cfg: Dictionary = hazards.get_debug().get("cfg", {}) as Dictionary
	var warn: float = float(cfg.get("vent_warn_sec", 0.0))
	var erupt_sec: float = float(cfg.get("vent_sec", 0.0))
	if not hazards.trigger_vent(enemy, 0):
		push_warning("DemoArgs: the boss half has no vent for demo '%s'" % _mode)
	_tick_hazards(hazards, null, state, warn + erupt_sec * HAZARD_DEMO_VENT_ERUPT_RATIO)
	if not hazards.trigger_vent(player, 0):
		push_warning("DemoArgs: the player half has no vent for demo '%s'" % _mode)
	_tick_hazards(hazards, null, state, warn * HAZARD_DEMO_VENT_WARN_RATIO)


# Story 039 "crumble": one cell fallen, the boss's cell cracking (warning) and the player's cell half way to a crack.
func _crumble_demo(hazards: TileHazards, grid: BoardGrid, state: CombatState) -> void:
	var player: int = CombatState.Side.PLAYER
	if not hazards.crumble_enabled():
		push_warning("DemoArgs: the arena has no crumble, switching it on for demo '%s' (pass --arena=twin_isles)" % _mode)
		hazards.enable_crumble(true)
	var cfg: Dictionary = hazards.get_debug().get("cfg", {}) as Dictionary
	var after: float = float(cfg.get("crumble_after_sec", 0.0))
	var warn: float = float(cfg.get("crumble_warn_sec", 0.0))
	var fall: float = float(cfg.get("fall_sec", 0.0))
	var fell: bool = false
	for cell: Vector2i in _hazard_spread(grid, player, HAZARD_DEMO_DROP_TRIES, state):
		if not hazards.drop_cells(player, [cell] as Array[Vector2i], fall, warn).is_empty():
			fell = true
			break
	if not fell:
		push_warning("DemoArgs: no player cell could fall (leave-a-path rule) for demo '%s'" % _mode)
	var elapsed: float = warn + TRAIT_STEP_SEC + after * HAZARD_DEMO_CRUMBLE_RATIO
	_tick_hazards(hazards, null, state, warn + TRAIT_STEP_SEC)
	_tick_hazards(hazards, null, state, after * HAZARD_DEMO_CRUMBLE_RATIO)
	var here: Vector2i = state.player_cell
	for cell: Vector2i in _zone_neighbours(grid, here, false, false):
		if not hazards.is_fallen(player, cell) and state.set_player_cell(cell):
			break
	# The boss has stood since the start: it is half way through its crack warning, the player (moved) is part way to one.
	_tick_hazards(hazards, null, state, after + warn * 0.5 - elapsed)
	var ratio: float = _parse_return_ratio()
	var fallen: Array[Vector2i] = hazards.fallen_cells(player)
	if ratio < 0.0 or fallen.is_empty():
		return
	# --return-ratio: no new crumbles, run to the fallen cell's return, then k of the fade (time stays frozen there).
	var back_cell: Vector2i = fallen[0]
	hazards.enable_crumble(false)
	_tick_hazards(hazards, null, state, hazards.fallen_left(player, back_cell) + 0.0001)
	if hazards.return_fade_sec > 0.0:
		_tick_hazards(hazards, null, state, hazards.return_fade_sec * ratio)
	print("DemoArgs: crumble return cell %s fraction %.2f (fade %.2f s)" % [back_cell, hazards.return_fraction(player, back_cell), hazards.return_fade_sec])


# Parses --return-ratio=k (0..1); -1 when absent.
func _parse_return_ratio() -> float:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(RETURN_RATIO_PREFIX):
			return clampf(float(arg.substr(RETURN_RATIO_PREFIX.length())), 0.0, 1.0)
	return -1.0


# Story 039 "burn_eater": the boss hurt to HAZARD_DEMO_BOSS_HP_RATIO, its own cell burning, one burn tick: it heals (the HUD's
# green number comes from CombatState.enemy_healed; the number is also pinned by a dev hook so a capture finds it).
func _burn_eater_demo(combat: CombatView, hazards: TileHazards, state: CombatState) -> void:
	state.enemy_hp = state.enemy_max_hp * HAZARD_DEMO_BOSS_HP_RATIO
	state.changed.emit()
	combat.get_status().ignite([state.enemy_cell] as Array[Vector2i], HAZARD_DEMO_BURN_SEC, HAZARD_DEMO_BURN_TICK_SEC, HAZARD_DEMO_BURN_DAMAGE)
	var before: float = state.enemy_hp
	combat.get_status().tick(HAZARD_DEMO_BURN_TICK_SEC + TRAIT_STEP_SEC, state)
	var gained: float = state.enemy_hp - before
	if gained <= 0.0:
		push_warning("DemoArgs: the burn did not heal the boss (hp %s -> %s), showing the nominal tick" % [before, state.enemy_hp])
		gained = HAZARD_DEMO_BURN_DAMAGE
	for hud: Node in get_tree().root.find_children("*", "CutHudView", true, false):
		(hud as CutHudView).debug_show_boss_heal(gained, HAZARD_DEMO_HEAL_HOLD_SEC)


# Advances [param hazards] (and [param hazard_trait] when given) by [param sec] in TRAIT_STEP_SEC steps, like the match clock.
func _tick_hazards(hazards: TileHazards, hazard_trait: BossTrait, state: CombatState, sec: float) -> void:
	var left: float = sec
	while left > 0.0:
		var step: float = minf(TRAIT_STEP_SEC, left)
		if hazard_trait != null:
			hazard_trait.on_tick(step)
		hazards.tick(step, state)
		left -= step


# Ticks until [param done] is true (bounded by HAZARD_DEMO_MAX_STEPS); warns when it never is. No-op without the trait.
func _tick_until(hazards: TileHazards, hazard_trait: BossTrait, state: CombatState, done: Callable) -> void:
	if hazard_trait == null:
		return
	var steps: int = 0
	while not bool(done.call()) and steps < HAZARD_DEMO_MAX_STEPS:
		_tick_hazards(hazards, hazard_trait, state, TRAIT_STEP_SEC)
		steps += 1
	if not bool(done.call()):
		push_warning("DemoArgs: '%s' never reached its demo state" % hazard_trait.get_id())


func _trait_float(hazard_trait: BossTrait, getter: String) -> float:
	return float(hazard_trait.call(getter)) if hazard_trait != null and hazard_trait.has_method(getter) else 0.0


func _trait_cell(hazard_trait: BossTrait, getter: String) -> Vector2i:
	return hazard_trait.call(getter) if hazard_trait != null and hazard_trait.has_method(getter) else BoardGrid.NO_CELL


# Wind on (TileHazards.enable_wind) and the FIELD_PIECES / BOSS_DEMO_FIELD pieces spread over both halves.
func _wind_with_pieces(combat: CombatView, grid: BoardGrid, hazards: TileHazards) -> void:
	if not hazards.wind_enabled():
		hazards.enable_wind(true)
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var spots: Array[Vector2i] = _hazard_spread(grid, CombatState.Side.PLAYER, FIELD_PIECES.size(), combat.get_state())
	for i: int in spots.size():
		var spec: Array = FIELD_PIECES[i]
		combat.get_drops().debug_place_piece(lib.make_piece(str(spec[0]), int(spec[1])), spots[i], FIELD_PIECE_FRESHNESS[i])
	var enemy_spots: Array[Vector2i] = _hazard_spread(grid, CombatState.Side.ENEMY, BOSS_DEMO_FIELD.size(), combat.get_state())
	for i: int in enemy_spots.size():
		var spec2: Array = BOSS_DEMO_FIELD[i]
		combat.get_boss().get_drops().debug_place_piece(lib.make_piece(str(spec2[0]), int(spec2[1])), enemy_spots[i], BOSS_DEMO_FIELD_FRESHNESS[i])


# The player's real cast over the boss's cell plus orthogonal neighbours up to [param count] cells, resolved
# through the arbiter (damage, trait hooks), as in boss_counter.
func _player_cast_on_boss(combat: CombatView, grid: BoardGrid, count: int) -> void:
	var boss_cell: Vector2i = combat.get_state().enemy_cell
	var cells: Array[Vector2i] = [boss_cell]
	for cell: Vector2i in _zone_neighbours(grid, boss_cell, true, false):
		if cells.size() < count:
			cells.append(cell)
	var actor: CutActor = combat.get_cut_actor()
	if not actor.begin_swing(cells, SkillConfig.FALLBACK_SKILL, true):
		push_warning("DemoArgs: the player cast did not start for demo '%s'" % _mode)
		return
	var steps: int = 0
	while actor.is_swinging() and steps < HAZARD_DEMO_MAX_STEPS:
		combat.get_arbiter().tick(TRAIT_STEP_SEC)
		steps += 1


# [param count] cells of [param side]'s half spread evenly, never a unit's cell.
func _hazard_spread(grid: BoardGrid, side: int, count: int, state: CombatState) -> Array[Vector2i]:
	var all: Array[Vector2i] = []
	for cell: Vector2i in (grid.player_cells() if side == CombatState.Side.PLAYER else grid.enemy_cells()):
		if cell != state.player_cell and cell != state.enemy_cell:
			all.append(cell)
	var out: Array[Vector2i] = []
	for i: int in count:
		if all.is_empty():
			break
		var index: int = 0 if count <= 1 else roundi(float(all.size() - 1) * i / float(count - 1))
		if not out.has(all[index]):
			out.append(all[index])
	return out


# The match's own trait [param id] when the booted match has it; else one built through TraitRegistry with the
# params chapters.json gives it in match [param match_id], set up on this battle and added to its TraitHost.
func _zone_trait(combat: CombatView, id: String, match_id: String) -> BossTrait:
	var host: TraitHost = combat.get_trait_host()
	var own: BossTrait = host.get_trait(id)
	if own != null:
		print("DemoArgs: %s from the booted match" % id)
		return own
	push_warning("DemoArgs: the match has no '%s', building one with %s's params" % [id, match_id])
	var made: BossTrait = TraitRegistry.create(id)
	if made == null:
		push_warning("DemoArgs: TraitRegistry could not create '%s'" % id)
		return null
	made.setup(combat.make_trait_ctx(), _chapter_trait_params(match_id, id), DEMO_SEED)
	made.on_match_start()
	host.debug_add_trait(made)
	return made


# Params of trait [param id] in chapters.json match [param match_id] ({} when not found).
func _chapter_trait_params(match_id: String, id: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHAPTERS_PATH))
	if not data is Dictionary:
		return {}
	for chapter: Variant in (data as Dictionary).get("chapters", []):
		var matches: Dictionary = (chapter as Dictionary).get("matches", {}) as Dictionary
		if not matches.has(match_id):
			continue
		for t: Variant in (matches[match_id] as Dictionary).get("traits", []):
			if str((t as Dictionary).get("id", "")) == id:
				return (t as Dictionary).get("params", {}) as Dictionary
	return {}


# Story 027 "reward_zone_cards": forces the run's pending offer to ZONE_REWARD_CARDS and tells the views.
func _force_reward_offer() -> void:
	for n: Node in get_tree().root.find_children("*", "GameFlow", true, false):
		var flow: GameFlow = n as GameFlow
		if flow.get_run() == null:
			continue
		flow.get_run().set_pending_reward(ZONE_REWARD_CARDS)
		flow.run_changed.emit()
		return
	push_warning("DemoArgs: no GameFlow with a run for demo '%s'" % _mode)


# Real cells of one half ([param enemy_half]) next to [param cell]: the orthogonal ones in ZONE_DEMO_STEPS order,
# plus the diagonal ones when [param diagonal].
func _zone_neighbours(grid: BoardGrid, cell: Vector2i, enemy_half: bool, diagonal: bool) -> Array[Vector2i]:
	var steps: Array[Vector2i] = ZONE_DEMO_STEPS.duplicate()
	if diagonal:
		steps.append_array([Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)] as Array[Vector2i])
	var out: Array[Vector2i] = []
	for step: Vector2i in steps:
		var c: Vector2i = cell + step
		if grid.is_enemy_cell(c) if enemy_half else grid.is_player_cell(c):
			out.append(c)
	return out


# Fills the boss's piece hand with BOSS_DEMO_HAND (one piece per slot, as many as fit).
func _boss_piece_hand(boss: BossController, lib: PieceLibrary) -> void:
	var hand: HoldSlots = boss.get_hand()
	for i: int in mini(BOSS_DEMO_HAND.size(), hand.get_slot_count()):
		var point := FieldPoint.new()
		point.uid = BOSS_UID_BASE - i
		point.freshness_left = 0.0
		point.piece = lib.make_piece(BOSS_DEMO_HAND[i], 0)
		point.label = point.piece.shape_id
		hand.place(point, i)


# A free boss-half cell for field piece [param index], spread over the half, never the boss's own cell.
func _free_enemy_cell(grid: BoardGrid, combat: CombatView, index: int) -> Vector2i:
	var spread: Array[Vector2i] = _spread_enemy_cells(grid, BOSS_DEMO_FIELD.size() + 2)
	for k: int in spread.size():
		var cell: Vector2i = spread[(k + index * 2 + 1) % spread.size()]
		if cell != combat.get_state().enemy_cell and combat.get_boss().get_drops().is_cell_free(cell):
			return cell
	return combat.get_state().enemy_cell


# Commits the boss's cast of the first [param use] hand pieces through BossController's real cut path, over player
# cells found by _boss_piece_cells. Warns when no placement exists or the cut did not start.
func _boss_piece_cut(combat: CombatView, grid: BoardGrid, use: int) -> void:
	var boss: BossController = combat.get_boss()
	var pieces: Array[Piece] = []
	var indices: Array[int] = []
	for i: int in use:
		pieces.append(boss.get_hand().get_piece(i))
		indices.append(i)
	var cells: Array[Vector2i] = _boss_piece_cells(grid, pieces, combat.get_state().player_cell)
	if cells.is_empty():
		push_warning("DemoArgs: no boss placement for demo '%s'" % _mode)
		return
	boss.call("_do_cut", {"hand_indices": indices, "skill_id": SkillConfig.FALLBACK_SKILL, "cells": cells})
	if not boss.get_actor().is_swinging():
		push_warning("DemoArgs: the boss cut did not start for demo '%s'" % _mode)
	# On a narrow half the countdown label (centred on the cast's bounding box) would hide the player: move the
	# player to a cell outside that box when one exists.
	if _box_has(cells, combat.get_state().player_cell):
		for cell: Vector2i in grid.player_cells():
			if not _box_has(cells, cell) and combat.get_state().set_player_cell(cell):
				break


# Cells of [param pieces] (1 or 2) on the player's half: one piece anywhere, two joined by an edge without overlap;
# the union never covers [param avoid] (the player's cell). Empty when none fits.
func _boss_piece_cells(grid: BoardGrid, pieces: Array[Piece], avoid: Vector2i) -> Array[Vector2i]:
	# First pass also keeps the player out of the cast's bounding box (the countdown label is centred on it and
	# would hide the player); the second pass only keeps the player's cell uncovered.
	var strict: Array[Vector2i] = _boss_piece_cells_pass(grid, pieces, avoid, true)
	return strict if not strict.is_empty() else _boss_piece_cells_pass(grid, pieces, avoid, false)


func _boss_piece_cells_pass(grid: BoardGrid, pieces: Array[Piece], avoid: Vector2i, keep_box_clear: bool) -> Array[Vector2i]:
	for anchor_a: Vector2i in PiecePlacement.valid_anchors(grid, pieces[0], false):
		var cells_a: Array[Vector2i] = pieces[0].cells_at(anchor_a)
		if cells_a.has(avoid):
			continue
		if pieces.size() == 1:
			if not keep_box_clear or not _box_has(cells_a, avoid):
				return cells_a
			continue
		for anchor_b: Vector2i in PiecePlacement.valid_anchors(grid, pieces[1], false):
			var cells_b: Array[Vector2i] = pieces[1].cells_at(anchor_b)
			var ok: bool = not cells_b.has(avoid)
			var touching: bool = false
			for cell: Vector2i in cells_b:
				ok = ok and not cells_a.has(cell)
				for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					touching = touching or cells_a.has(cell + step)
			if ok and touching:
				var union: Array[Vector2i] = cells_a.duplicate()
				union.append_array(cells_b)
				if not keep_box_clear or not _box_has(union, avoid):
					return union
	return [] as Array[Vector2i]


# True when [param cell] lies inside the bounding box of [param cells].
func _box_has(cells: Array[Vector2i], cell: Vector2i) -> bool:
	var low: Vector2i = cells[0]
	var high: Vector2i = cells[0]
	for c: Vector2i in cells:
		low = Vector2i(mini(low.x, c.x), mini(low.y, c.y))
		high = Vector2i(maxi(high.x, c.x), maxi(high.y, c.y))
	return cell.x >= low.x and cell.x <= high.x and cell.y >= low.y and cell.y <= high.y


# Story 029 formation demos (FormationMap.set_cells, freeze_time keeps the fades still). half: the first
# half of the real enemy cells lit at mixed freshness. warn: every other cell lit, about half of those
# under the warn ratio (they draw faint + dashed). complete: covers every enemy cell through the real
# completion path (CombatView._cover_formation, DEV-ONLY): ready flag, flash and banner; time is
# frozen, so the flash holds at 1.
func _formation_demo(combat: CombatView, grid: BoardGrid) -> void:
	var map: FormationMap = combat.get_formation()
	if map == null:
		push_warning("DemoArgs: no formation map (character without a signature) for demo '%s'" % _mode)
		return
	var cells: Array[Vector2i] = grid.enemy_cells()
	if _mode == "formation_complete":
		combat.call("_cover_formation", cells)
		return
	var warn: float = combat.get_config().formation_fade_warn_ratio
	var fresh: Array[float] = [1.0, 0.8, 0.55, 0.35]
	var lit: int = 0
	for i: int in cells.size():
		if _mode == "formation_half":
			if i >= (cells.size() + 1) / 2:
				break
			map.set_cells([cells[i]] as Array[Vector2i], fresh[i % fresh.size()])
		else:
			if i % 2 == 1:
				continue
			var fraction: float = 0.9 if lit % 3 == 0 else warn * 0.5
			map.set_cells([cells[i]] as Array[Vector2i], fraction)
			lit += 1


# Story 030 Thien Hoa demos (needs --character=phap_su). The boss's cell is set burning first (the signature's own
# burn params, standing in for a burn card) so the detonation has something to blow up; the whole enemy board is
# lit on the formation map; the real activate_signature() detonates that burn, then sets every lit cell on fire.
# thien_hoa_burning then advances only the burn by THIEN_HOA_BURNING_DEMO_SEC (deterministic, time stays frozen).
func _thien_hoa_demo(combat: CombatView, grid: BoardGrid) -> void:
	var map: FormationMap = combat.get_formation()
	var sig: BaseSignature = combat.get_signature()
	if map == null or not sig is ThienHoaSignature:
		push_warning("DemoArgs: demo '%s' needs --character=phap_su (Thien Hoa signature)" % _mode)
		return
	var status: StatusEffects = combat.get_status()
	status.ignite([combat.get_state().enemy_cell] as Array[Vector2i],
		sig.param_float("burn_duration_sec", ThienHoaSignature.DEFAULT_BURN_DURATION_SEC),
		sig.param_float("burn_tick_sec", ThienHoaSignature.DEFAULT_BURN_TICK_SEC),
		sig.param_float("burn_damage_per_tick", ThienHoaSignature.DEFAULT_BURN_DAMAGE_PER_TICK))
	map.cover(grid.enemy_cells())
	_activate_signature_now(combat)
	if _mode == "thien_hoa_burning":
		status.tick(THIEN_HOA_BURNING_DEMO_SEC, combat.get_state())


# Story 030 "anh_bo_hit" (needs --character=sat_thu): Anh Bo activated (border, timer, banner), then a 2-cell
# piece cast through the real player path (select / aim / confirm / choose) resolved on the boss.
func _anh_bo_demo(combat: CombatView, grid: BoardGrid) -> void:
	if not combat.get_signature() is AnhBoSignature:
		push_warning("DemoArgs: demo '%s' needs --character=sat_thu (Anh Bo signature)" % _mode)
		return
	_activate_signature_now(combat)
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	_fill_bag(lib, -1)
	var held: FieldPoint = _hold().get_point(0)
	held.piece = lib.make_piece(ANH_BO_DEMO_PIECE, 0)
	held.label = ANH_BO_DEMO_PIECE
	if not combat.select_piece(0):
		push_warning("DemoArgs: select_piece failed for demo '%s'" % _mode)
		return
	_aim_hitting(combat, grid, combat.get_state().enemy_cell)
	if not combat.press_cast():
		push_warning("DemoArgs: press_cast failed for demo '%s'" % _mode)
		return
	var flow: CutFlow = combat.get_cut_flow()
	if not flow.choose(SkillConfig.FALLBACK_SKILL):
		push_warning("DemoArgs: skill '%s' not available for demo '%s'" % [SkillConfig.FALLBACK_SKILL, _mode])
		return
	combat.get_arbiter().tick(combat.get_cut_actor().get_time_left() + 0.001)


# Story 037 "vay_bat" (needs --character=tho_san): Vay Bat activated, then the real tran_gai cast (the dev
# CombatView._begin_cut path) over the cells around the boss except one (Vay Bat lays its extra thorn cell there or
# next to it): the thorns last zone_sec_mult x longer, hunter_mark marks the boss (Ran) because thorns were laid
# beside it (quick spec o-rot-thay-tuong 2026-10-31; the Wall card is boss-only now).
func _vay_bat_demo(combat: CombatView, grid: BoardGrid) -> void:
	if not combat.get_signature() is VayBatSignature:
		push_warning("DemoArgs: demo '%s' needs --character=tho_san (Vay Bat signature)" % _mode)
		return
	_activate_signature_now(combat)
	var state: CombatState = combat.get_state()
	var cells: Array[Vector2i] = _zone_neighbours(grid, state.enemy_cell, true, true)
	if cells.size() > 1:
		cells.pop_back()
	combat._begin_cut("tran_gai", cells)
	combat.get_arbiter().tick(combat.get_cut_actor().get_time_left() + 0.001)
	var status: StatusEffects = combat.get_status()
	var thorned: Array[Vector2i] = status.thorn_cells(CombatState.Side.ENEMY)
	if thorned.is_empty():
		push_warning("DemoArgs: no thorns formed for demo '%s'" % _mode)
		return
	status.tick(status.thorn_total_sec(CombatState.Side.ENEMY, thorned[0]) * VAY_BAT_DEMO_ZONE_ELAPSED_RATIO, state)


# Story 037 "thanh_an" (needs --character=giao_si): the player hurt (so the heal shows), the boss at
# THANH_AN_DEMO_FROST_STACKS Han, Thanh An activated, then a real 2-cell kiem_khi hit on the boss: Thanh An adds the
# next Han stack, the burst is x burst_mult, Prayer heals (the "+N" flash over the player).
func _thanh_an_demo(combat: CombatView, grid: BoardGrid) -> void:
	if not combat.get_signature() is ThanhAnSignature:
		push_warning("DemoArgs: demo '%s' needs --character=giao_si (Thanh An signature)" % _mode)
		return
	var state: CombatState = combat.get_state()
	state.set_player_hp(state.player_max_hp * THANH_AN_DEMO_HP_RATIO)
	combat.get_status().apply_frost(CombatState.Side.ENEMY, THANH_AN_DEMO_FROST_STACKS)
	_activate_signature_now(combat)
	var cells: Array[Vector2i] = [state.enemy_cell]
	var beside: Array[Vector2i] = _zone_neighbours(grid, state.enemy_cell, true, false)
	if not beside.is_empty():
		cells.append(beside[0])
	combat._begin_cut(SkillConfig.FALLBACK_SKILL, cells)
	combat.get_arbiter().tick(combat.get_cut_actor().get_time_left() + 0.001)


# Marks the signature ready and activates it through CombatView.activate_signature, which refuses while the
# demo freeze is on: the freeze is lifted for this one synchronous call and restored right after.
func _activate_signature_now(combat: CombatView) -> void:
	combat.debug_set_signature_charge(1.0)
	combat.freeze_time = false
	var fired: bool = combat.activate_signature()
	combat.freeze_time = true
	if not fired:
		push_warning("DemoArgs: activate_signature refused for demo '%s'" % _mode)


# Story 024: ends the match intro (walks up the parents to the RunController) so the banner does not cover
# the board; the demo's freeze_time keeps the simulation still. No-op without a controller above.
# Story 035 "boss_downed" / "final_phase2": intro skipped, then one huge hit on the boss: a region boss is downed at
# 0 HP; the phased final boss is clamped at its next threshold and enters phase 2 (banner, invulnerable).
func _final_boss_demo() -> void:
	_skip_intro()
	var combat: CombatView = _combat()
	if _mode == "final_phase2":
		# The HUD connects TraitHost.phase_changed in its own _process: hit only once someone listens, or the
		# phase-2 banner is missed (bounded wait so a HUD-less layout cannot hang).
		for _i: int in HUD_CONNECT_MAX_FRAMES:
			var host: TraitHost = combat.get_trait_host()
			if host != null and not host.phase_changed.get_connections().is_empty():
				break
			await get_tree().process_frame
	combat.get_state().damage(CombatState.Side.ENEMY, 999999.0)
	if _mode == "boss_downed":
		if not combat.is_boss_downed():
			push_warning("DemoArgs: boss_downed: the boss was not downed (not a region boss match?)")
		return
	var phased: bool = false
	for t: BossTrait in combat.get_trait_host().get_traits():
		if t.has_method("get_phase"):
			phased = true
			if int(t.call("get_phase")) < 2:
				t.on_tick(0.0)
	if not phased:
		push_warning("DemoArgs: final_phase2: the booted match has no boss_phases trait (not the final match?)")
		return
	var banners: int = 0
	for hud: Node in get_tree().root.find_children("*", "CutHudView", true, false):
		if float(hud.get("_phase_banner_left")) > 0.0:
			banners += 1
	if banners == 0:
		push_warning("DemoArgs: final_phase2: no HUD showed the phase banner")
	else:
		print("DemoArgs: final_phase2: phase banner shown on %d HUD(s)" % banners)


func _skip_intro() -> void:
	# Deferred (2026-10-31): called from _enter_tree, before RunController has stored the spawned battle and
	# disabled it for the intro; skipping then left the battle disabled in PLAYING (no _process, no canvas
	# bind, relic strip never laid out). One frame later _begin_playing re-enables it.
	call_deferred("_skip_intro_now")


func _skip_intro_now() -> void:
	var node: Node = get_parent()
	while node != null and not node is RunController:
		node = node.get_parent()
	var controller: RunController = node as RunController
	if controller != null and controller.get_state().get_phase() == RunState.Phase.INTRO:
		controller.call("_begin_playing")


# A RowBurnerTrait with default params, set up with the battle's real trait context, started,
# and registered on the match's TraitHost (DEV-ONLY debug_add_trait) so the HUD sees it.
# Null + warning when the registry cannot create it.
func _make_row_burner(combat: CombatView) -> RowBurnerTrait:
	var burner: RowBurnerTrait = TraitRegistry.create(RowBurnerTrait.ID) as RowBurnerTrait
	if burner == null:
		push_warning("DemoArgs: TraitRegistry could not create '%s'" % RowBurnerTrait.ID)
		return null
	burner.setup(combat.make_trait_ctx(), {}, DEMO_SEED)
	burner.on_match_start()
	combat.get_trait_host().debug_add_trait(burner)
	return burner


# Any player cell other than [param cell] (or [param cell] itself on a one-cell half).
func _other_player_cell(grid: BoardGrid, cell: Vector2i) -> Vector2i:
	for other: Vector2i in grid.player_cells():
		if other != cell:
			return other
	return cell


func _parse_boss_set() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(BOSS_PREFIX):
			return arg.substr(BOSS_PREFIX.length())
	return ""


# Like _spread_cells, over the boss's half.
func _spread_enemy_cells(grid: BoardGrid, count: int) -> Array[Vector2i]:
	var all: Array[Vector2i] = grid.enemy_cells()
	var out: Array[Vector2i] = []
	for i: int in count:
		var index: int = 0
		if count > 1:
			index = roundi(float(all.size() - 1) * i / float(count - 1))
		if not out.has(all[index]):
			out.append(all[index])
	return out


# Parses --deck=a,b,c into card ids (empty when absent; CombatView validates the ids).
func _parse_deck() -> Array[String]:
	var ids: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(DECK_PREFIX):
			for id: String in arg.substr(DECK_PREFIX.length()).split(",", false):
				ids.append(id.strip_edges())
	return ids


# Parses --drops-seed=N (negative when absent).
func _parse_drops_seed() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(DROPS_SEED_PREFIX):
			return maxi(int(arg.substr(DROPS_SEED_PREFIX.length())), 0)
	return -1


func _parse_mode() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(DEMO_PREFIX):
			return arg.substr(DEMO_PREFIX.length())
	return ""


# Parses --grid=<cols>x<rows>[:c,r;c,r...]. Returns null (warning) when absent or malformed.
func _parse_grid() -> BoardGrid:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with(GRID_PREFIX):
			continue
		var spec: String = arg.substr(GRID_PREFIX.length())
		var parts: PackedStringArray = spec.split(":", false, 1)
		var dims: PackedStringArray = (parts[0] if parts.size() > 0 else "").split("x")
		if dims.size() != 2 or not dims[0].is_valid_int() or not dims[1].is_valid_int():
			push_warning("DemoArgs: bad --grid '%s', expected <cols>x<rows>[:c,r;c,r...]" % spec)
			return null
		var missing: Array[Vector2i] = []
		if parts.size() > 1:
			for item: String in parts[1].split(";", false):
				var rc: PackedStringArray = item.split(",")
				if rc.size() == 2 and rc[0].is_valid_int() and rc[1].is_valid_int():
					missing.append(Vector2i(rc[0].to_int(), rc[1].to_int()))
				else:
					push_warning("DemoArgs: bad --grid cell '%s', ignored" % item)
		return BoardGrid.new(dims[0].to_int(), dims[1].to_int(), missing)
	return null


# Story 028: --arena=<shape id>, "" when absent.
func _parse_player_cell() -> Vector2i:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(PLAYER_CELL_PREFIX):
			var parts: PackedStringArray = arg.substr(PLAYER_CELL_PREFIX.length()).split(",")
			if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
				return Vector2i(parts[0].to_int(), parts[1].to_int())
	return BoardGrid.NO_CELL


func _parse_arena() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(ARENA_PREFIX):
			return arg.substr(ARENA_PREFIX.length())
	return ""


# P2.2b: the pattern enemy's own data drives the dev launch: its `arena` hint (enemy_skills.json, e.g. dev_pattern_boss ->
# boss_hall) becomes the match arena unless --arena= named one ([param use_arena_hint] false), and a MULTI-CELL enemy
# draws as itself (match `id` = the enemy id: no 1-cell sheet of the run's first match stretched over a 2x2 footprint;
# an enemy without a sheet keeps the placeholder). A 1-cell enemy (dev_pattern_dummy) keeps the old launch exactly.
func _apply_pattern_hints(enemy_id: String, use_arena_hint: bool) -> void:
	var enemy: Dictionary = EnemySkillsConfig.load_from_file().get_enemy(enemy_id)
	if enemy.is_empty():
		return
	var hint: String = str(enemy.get("arena", ""))
	if use_arena_hint and not hint.is_empty():
		_combat().match_params["arena"] = {"shape": hint}
	# P2.3: a roster (non-dev) enemy also draws as itself (its own sheet, or the placeholder until P2.5 art).
	if (enemy.get("footprint", []) as Array).size() > 1 or not bool(enemy.get("dev", false)):
		_combat().match_params["id"] = enemy_id


# Phase 2 (P2.2): --pattern=<enemy id>, "" when absent.
func _parse_pattern() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(PATTERN_PREFIX):
			return arg.substr(PATTERN_PREFIX.length()).strip_edges()
	return ""


func _combat() -> CombatView:
	return get_node(combat_view_path) as CombatView


func _hold() -> HoldSlots:
	return (get_node(hold_slots_view_path) as HoldSlotsView).get_slots()


# [param count] distinct player cells evenly spread over the player half (fewer if the half
# has fewer cells), first and last cell included.
func _spread_cells(grid: BoardGrid, count: int) -> Array[Vector2i]:
	var all: Array[Vector2i] = grid.player_cells()
	var out: Array[Vector2i] = []
	for i: int in count:
		var index: int = 0
		if count > 1:
			index = roundi(float(all.size() - 1) * i / float(count - 1))
		if not out.has(all[index]):
			out.append(all[index])
	return out


# Story 024: bag of the piece demos: BAG_PIECES in the slots (as many as fit); [param rotten_slot] >= 0
# swaps that slot for a ROTTEN piece (grey, counting down) instead.
func _fill_bag(lib: PieceLibrary, rotten_slot: int) -> void:
	for i: int in mini(BAG_PIECES.size(), _hold().get_slot_count()):
		var point := FieldPoint.new()
		point.uid = -1 - i
		point.freshness_left = 0.0
		if i == rotten_slot:
			point.piece = Piece.make_rotten()
			point.label = Piece.ROTTEN_ID
			point.rotten = true
			point.rot_in_hand_sec = ROTTEN_HAND_LEFT_SEC
		else:
			var spec: Array = BAG_PIECES[i]
			point.piece = lib.make_piece(str(spec[0]), int(spec[1]))
			point.label = point.piece.shape_id
		_hold().place(point, i)


# Story 024: the shape the placing demos use: --piece=<id>, else [param fallback].
func _piece_id(fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(PIECE_PREFIX):
			return arg.substr(PIECE_PREFIX.length())
	return fallback


# Story 024 placing demos, through the real player path: the bag, select_piece (slot 0), Focus started
# (time is frozen so _update_focus does not run), the ghost aimed with aim_at_cell, rotate_piece for
# "placing_rotated", press_cast (commit + Tung phép) for "pieces_menu".
func _placing_demo(combat: CombatView, grid: BoardGrid) -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	_fill_bag(lib, -1)
	var shape: String = _piece_id(CENTER_DEFAULT_PIECE if _mode == "placing_center" else PLACING_DEFAULT_PIECE)
	var held: FieldPoint = _hold().get_point(0)
	held.piece = lib.make_piece(shape, 0)
	held.label = shape
	if not combat.select_piece(0):
		push_warning("DemoArgs: select_piece failed for demo '%s'" % _mode)
		return
	var focus: FocusController = combat.get_focus()
	if not focus.try_start():
		push_warning("DemoArgs: Focus did not start for demo '%s'" % _mode)
	var boss_cell: Vector2i = combat.get_state().enemy_cell
	var placement: PlacementController = combat.get_placement()
	if _mode == "placing_center":
		combat.aim_at_cell(Vector2i(grid.side_cols + int(grid.side_cols * 0.5), int(grid.rows * 0.5)))
		return
	if _mode == "placing_drag":
		# Real drag path: the finger picks slot 0 up and moves to the point whose lifted ghost aims at the boss.
		var finger: Vector2 = combat.drag_point_for_cell(boss_cell)
		if not combat.begin_drag(0, _hold_slot_centre(0)):
			push_warning("DemoArgs: begin_drag failed for demo '%s'" % _mode)
			return
		combat.drag_to(finger)
		if not placement.hits(boss_cell):
			# The snap may settle on a position that misses the aimed cell (equal distance): walk the
			# enemy cells with the finger until the lifted ghost covers the boss.
			for cell: Vector2i in grid.enemy_cells():
				combat.drag_to(combat.drag_point_for_cell(cell))
				if placement.hits(boss_cell):
					break
		if not placement.hits(boss_cell):
			push_warning("DemoArgs: the dragged ghost does not cover the boss for demo '%s'" % _mode)
		return
	var want_hit: bool = _mode != "placing_miss"
	if _mode == "placing_rotated":
		combat.rotate_piece()
	combat.aim_at_cell(boss_cell)
	if placement.hits(boss_cell) != want_hit:
		for cell: Vector2i in grid.enemy_cells():
			combat.aim_at_cell(cell)
			if placement.can_confirm() and placement.hits(boss_cell) == want_hit:
				break
	if placement.hits(boss_cell) != want_hit:
		push_warning("DemoArgs: no ghost position gives hit=%s for demo '%s'" % [want_hit, _mode])
	if _mode == "pieces_menu":
		# 2026-11-01: the piece is committed and Tung phép pressed (the card menu opens on the press).
		if not combat.press_cast():
			push_warning("DemoArgs: press_cast failed for demo '%s'" % _mode)


# Centre of bag slot [param index] in viewport pixels (where a finger would pick the piece up).
func _hold_slot_centre(index: int) -> Vector2:
	return (get_node(hold_slots_view_path) as HoldSlotsView).get_slot_rect(index).get_center()


# Story 028 join demos through the real player path (select / aim / confirm, then the second piece).
# join_menu: piece 1 placed, the menu open, piece 2 mid-drag. join_split: piece 2 attached apart from
# piece 1. join_featured: the two pieces tile the match's featured shape (--arena=<shape>).
func _join_demo(combat: CombatView, grid: BoardGrid) -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	_fill_bag(lib, -1)
	var boss_cell: Vector2i = combat.get_state().enemy_cell
	var id_a: String = _piece_id(JOIN_PIECE_1)
	var id_b: String = JOIN_PIECE_2
	var turns_a: int = 0
	var turns_b: int = 0
	var anchor_a: Vector2i = BoardGrid.NO_CELL
	var anchor_b: Vector2i = BoardGrid.NO_CELL
	if _mode == "join_featured":
		var featured: Dictionary = combat.get_featured()
		if featured.is_empty():
			push_warning("DemoArgs: join_featured needs --arena=<shape> with a featured shape that fits the board")
			return
		var plan: Dictionary = _featured_tiling(lib, grid, featured["cells"] as Array[Vector2i], boss_cell)
		if plan.is_empty():
			push_warning("DemoArgs: no two-piece tiling of the featured shape found")
			return
		id_a = str(plan["id_a"])
		id_b = str(plan["id_b"])
		turns_a = int(plan["turns_a"])
		turns_b = int(plan["turns_b"])
		anchor_a = plan["anchor_a"]
		anchor_b = plan["anchor_b"]
	var first: FieldPoint = _hold().get_point(0)
	first.piece = lib.make_piece(id_a, turns_a)
	first.label = id_a
	var second: FieldPoint = _hold().get_point(JOIN_SLOT_2)
	second.piece = lib.make_piece(id_b, turns_b)
	second.label = id_b
	if not combat.select_piece(0):
		push_warning("DemoArgs: select_piece failed for demo '%s'" % _mode)
		return
	if anchor_a != BoardGrid.NO_CELL:
		_aim_anchor(combat, anchor_a)
	else:
		_aim_hitting(combat, grid, boss_cell)
	if not combat.confirm_placement():
		push_warning("DemoArgs: confirm_placement failed for demo '%s'" % _mode)
		return
	var placement: PlacementController = combat.get_placement()
	if _mode == "join_menu":
		if not combat.begin_drag(JOIN_SLOT_2, _hold_slot_centre(JOIN_SLOT_2)):
			push_warning("DemoArgs: begin_drag of the second piece failed")
			return
		for cell: Vector2i in grid.enemy_cells():
			combat.drag_to(combat.drag_point_for_cell(cell))
			if placement.can_confirm() and not combat.get_cast_plan().touches(placement.get_cells()):
				break
		return
	if not combat.select_piece(JOIN_SLOT_2):
		push_warning("DemoArgs: select_piece of the second piece failed")
		return
	if anchor_b != BoardGrid.NO_CELL:
		_aim_anchor(combat, anchor_b)
	else:
		for cell: Vector2i in grid.enemy_cells():
			combat.aim_at_cell(cell)
			if placement.can_confirm() and not combat.get_cast_plan().touches(placement.get_cells()):
				break
	if not combat.confirm_placement():
		push_warning("DemoArgs: attaching the second piece failed for demo '%s'" % _mode)


# 2026-11-01 card pick demos (see the header) through the real player path: piece 1 dropped over the boss, piece 2
# joined apart from it (the join_split path), then Tung phép pressed for card_pick / card_cooldown. card_cooldown
# starts three cooldowns through SkillCooldowns.start, ticked apart so the pies differ; the last of them is the drawn
# hand's card with the longest cooldown (its dimmed face shows the same pie).
func _card_pick_demo(combat: CombatView, grid: BoardGrid) -> void:
	var real_mode: String = _mode
	_mode = "join_split"
	_join_demo(combat, grid)
	_mode = real_mode
	if not combat.is_placed():
		push_warning("DemoArgs: the pieces were not placed for demo '%s'" % _mode)
		return
	combat.debug_set_place_time_left(combat.get_place_duration() * CARD_DEMO_PLACE_LEFT_RATIO)
	if _mode == "card_placing":
		return
	if _mode != "card_cooldown_column" and not combat.press_cast():
		push_warning("DemoArgs: press_cast failed for demo '%s'" % _mode)
		return
	if _mode == "card_pick":
		# Controls v3: the pick-time fuse part-burnt round the card frame.
		combat.get_cut_flow().debug_set_time_left(combat.get_cut_flow().get_duration() * CARD_DEMO_PLACE_LEFT_RATIO)
		return
	var cooldowns: SkillCooldowns = combat.get_skill_cooldowns()
	var config: SkillConfig = combat.get_skill_config()
	# The hand card with the longest cooldown is used LAST (it is still mostly covered in the capture).
	var hand_card: String = ""
	for id: String in combat.get_hand():
		if _demo_cooldown(combat, id) > _demo_cooldown(combat, hand_card):
			hand_card = id
	var ids: Array[String] = []
	for id: String in config.card_order:
		if ids.size() >= CARD_DEMO_COOLDOWN_TICKS.size() - (0 if hand_card.is_empty() else 1):
			break
		if _demo_cooldown(combat, id) > 0.0 and not config.is_curse(id) and not combat.get_hand().has(id):
			ids.append(id)
	if not hand_card.is_empty():
		ids.append(hand_card)
	for i: int in ids.size():
		cooldowns.start(ids[i], _demo_cooldown(combat, ids[i]))
		cooldowns.tick(CARD_DEMO_COOLDOWN_TICKS[i])
	# Controls v3: the column demos also show the Focus recharge, part-way through, above the card icons.
	if _mode == "card_cooldown_column" or _mode == "card_cooldown":
		var focus: FocusController = combat.get_focus()
		if focus.try_start():
			focus.end("demo")
			focus.tick_real(focus.get_cooldown_sec() * CARD_DEMO_FOCUS_RECOVERED)
	print("DemoArgs %s: hand=%s cooldowns=%s" % [_mode, str(combat.get_hand()), str(cooldowns.running_ids())])


# The cooldown of card [param id] at the player's level (0 for "" or a card without one).
func _demo_cooldown(combat: CombatView, id: String) -> float:
	if id.is_empty():
		return 0.0
	return float(combat.get_skill_config().resolved(id, combat.get_card_level(id)).get("cooldown_sec", 0.0))


# Aims the selected piece's ghost until its anchor is [param anchor] (walks the enemy cells).
func _aim_anchor(combat: CombatView, anchor: Vector2i) -> bool:
	var placement: PlacementController = combat.get_placement()
	for cell: Vector2i in combat.get_grid().enemy_cells():
		combat.aim_at_cell(cell)
		if placement.get_anchor() == anchor:
			return true
	push_warning("DemoArgs: no aim reaches anchor %s" % str(anchor))
	return false


# Aims the ghost so that it covers [param boss_cell] when any position does.
func _aim_hitting(combat: CombatView, grid: BoardGrid, boss_cell: Vector2i) -> void:
	var placement: PlacementController = combat.get_placement()
	combat.aim_at_cell(boss_cell)
	if placement.hits(boss_cell):
		return
	for cell: Vector2i in grid.enemy_cells():
		combat.aim_at_cell(cell)
		if placement.hits(boss_cell):
			return


# Splits the featured shape (placed on the enemy half, covering the boss cell when possible) into two
# library pieces: {id_a, turns_a, anchor_a, id_b, turns_b, anchor_b}; {} when none tiles it.
func _featured_tiling(lib: PieceLibrary, grid: BoardGrid, featured: Array[Vector2i], boss_cell: Vector2i) -> Dictionary:
	var shape: Piece = Piece.make("featured", featured)
	var anchors: Array[Vector2i] = PiecePlacement.valid_anchors(grid, shape, true)
	if anchors.is_empty():
		return {}
	var anchor: Vector2i = anchors[anchors.size() / 2]
	for candidate: Vector2i in anchors:
		if shape.cells_at(candidate).has(boss_cell):
			anchor = candidate
			break
	var target: Array[Vector2i] = shape.cells_at(anchor)
	for pair: Array in FeaturedShape.pair_compositions(lib, featured):
		for order: int in 2:
			var id_a: String = str(pair[order])
			var id_b: String = str(pair[1 - order])
			for turns_a: int in 4:
				var piece_a: Piece = lib.make_piece(id_a, turns_a)
				var rel_a: Array[Vector2i] = piece_a.relative_cells()
				for start: Vector2i in target:
					var origin: Vector2i = start - rel_a[0]
					var placed: Array[Vector2i] = []
					for cell: Vector2i in rel_a:
						placed.append(cell + origin)
					var inside: bool = true
					for cell: Vector2i in placed:
						inside = inside and target.has(cell)
					if not inside:
						continue
					var rest: Array[Vector2i] = []
					for cell: Vector2i in target:
						if not placed.has(cell):
							rest.append(cell)
					var norm: Array[Vector2i] = FeaturedShape.normalize(rest)
					for turns_b: int in 4:
						if lib.make_piece(id_b, turns_b).relative_cells() == norm:
							return {
								"id_a": id_a, "turns_a": turns_a, "anchor_a": origin,
								"id_b": id_b, "turns_b": turns_b, "anchor_b": _min_cell(rest),
							}
	return {}


func _min_cell(cells: Array[Vector2i]) -> Vector2i:
	var out := Vector2i(1000000, 1000000)
	for cell: Vector2i in cells:
		out = Vector2i(mini(out.x, cell.x), mini(out.y, cell.y))
	return out


# Controls v3 demos (see the header): the moving state with a full bag, the resonant second piece being placed with the
# place window's fuse burning, or the player's buff / debuff row with pies, the cooldown column and a tooltip.
func _controls_demo(combat: CombatView, grid: BoardGrid) -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	match _mode:
		"controls_idle":
			_fill_bag(lib, -1)
		"controls_placing":
			_controls_placing_demo(combat, grid, lib)
		"controls_statuses":
			_fill_bag(lib, -1)
			var status: StatusEffects = combat.get_status()
			var side: int = CombatState.Side.PLAYER
			status.root(side, CONTROLS_ROOT_SEC)
			status.slow(side, CONTROLS_SLOW_SEC, CONTROLS_SLOW_MULT)
			status.apply_fragile(side, CONTROLS_FRAGILE_STACKS)
			status.guard(side, CONTROLS_GUARD_AMOUNT, CONTROLS_GUARD_SEC)
			status.tick(CONTROLS_TICK_SEC, combat.get_state())
			var cooldowns: SkillCooldowns = combat.get_skill_cooldowns()
			var started: int = 0
			for id: String in combat.get_skill_config().card_order:
				if started >= CONTROLS_COOLDOWN_TICKS.size():
					break
				if _demo_cooldown(combat, id) > 0.0 and not combat.get_skill_config().is_curse(id):
					cooldowns.start(id, _demo_cooldown(combat, id))
					cooldowns.tick(CONTROLS_COOLDOWN_TICKS[started])
					started += 1
			for hud: Node in get_tree().root.find_children("*", "CutHudView", true, false):
				var cut_hud := hud as CutHudView
				cut_hud.debug_show_relics(RELIC_FLASH_IDS)
				cut_hud.debug_open_status_tooltip(CONTROLS_TOOLTIP_ID)
			print("DemoArgs controls_statuses: %s" % str(combat.get_status().active_statuses(side, combat.get_state().player_cell)))


# The match's featured shape tiled by two pieces (as join_featured): the first placed, the second selected and aimed
# over the rest of the shape but NOT confirmed (placing: the gold ghost and the resonance label), the place window set to
# CARD_DEMO_PLACE_LEFT_RATIO of its length.
func _controls_placing_demo(combat: CombatView, grid: BoardGrid, lib: PieceLibrary) -> void:
	_fill_bag(lib, -1)
	var featured: Dictionary = combat.get_featured()
	if featured.is_empty():
		push_warning("DemoArgs: controls_placing needs a match with a featured shape")
		return
	var plan: Dictionary = _featured_tiling(lib, grid, featured["cells"] as Array[Vector2i], combat.get_state().enemy_cell)
	if plan.is_empty():
		push_warning("DemoArgs: no two-piece tiling of the featured shape found")
		return
	var first: FieldPoint = _hold().get_point(0)
	first.piece = lib.make_piece(str(plan["id_a"]), int(plan["turns_a"]))
	first.label = first.piece.shape_id
	var second: FieldPoint = _hold().get_point(JOIN_SLOT_2)
	second.piece = lib.make_piece(str(plan["id_b"]), int(plan["turns_b"]))
	second.label = second.piece.shape_id
	if not combat.select_piece(0) or not _aim_anchor(combat, plan["anchor_a"]) or not combat.confirm_placement():
		push_warning("DemoArgs: placing the first piece failed for controls_placing")
		return
	if not combat.select_piece(JOIN_SLOT_2) or not _aim_anchor(combat, plan["anchor_b"]):
		push_warning("DemoArgs: aiming the second piece failed for controls_placing")
		return
	combat.debug_set_place_time_left(combat.get_place_duration() * CARD_DEMO_PLACE_LEFT_RATIO)
	print("DemoArgs controls_placing: placing=%s placed=%s featured=%s" % [combat.is_placing(), combat.is_placed(),
		combat.joined_is_featured(combat.get_placement().get_cells())])


# --shot= capture (see SHOT_ARG): counts frames, then saves the root viewport's image and quits.
func _process(_delta: float) -> void:
	_shot_count += 1
	if _shot_count < _shot_frame:
		return
	set_process(false)
	var image: Image = get_viewport().get_texture().get_image()
	var err: Error = image.save_png(_shot_path)
	print("DemoArgs shot %dx%d -> %s (%s)" % [image.get_width(), image.get_height(), _shot_path, error_string(err)])
	get_tree().quit()

