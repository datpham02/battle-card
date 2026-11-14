# F3 — Passive Feedback: making the five passives visible

**Status:** DESIGN ONLY. No code, no assets, nothing committed. Written while `combat_view.gd` and
`src/audio` are held by other sessions, so that when they are free the work is wiring, not deciding.
**Date:** 2026-11-14
**Parent:** `docs/design/character-system/CHARACTER-SYSTEM-REDESIGN.md` phase F3.
**Depends on:** F1 (identity, accent colours — shipped), F2 (attributes — green, awaiting commit).

---

## 1. The problem, stated precisely

The audit said pillar 3 was **mechanically complete and presentationally absent** — "not one line of
VFX, audio or icon anywhere in the repo".

> **That was overstated, corrected 2026-11-14 by reading the HUD rather than the passives.** Two of
> the five already have feedback:
> - **`prayer`** has a real cue today: `cut_hud_view.gd:1989` `_draw_heal_flash` rises a `+N` over the
>   player's cell and fades it (Story 037). And it is **bare text, no box** — the `back` rect is only a
>   centring box for `_draw_centered`, nothing is filled — so it already matches the project rule and
>   is the shape F3 would have built anyway. What `prayer` lacks is not a cue but the **link**: the
>   burst happens on the enemy, the `+N` appears on the player, and nothing joins them.
> - **`hunter_mark`** shows its *state*: "Rạn ×N" in the boss status strip (Story 023). What is missing
>   is the *moment* of marking, which is what tells the player a window just opened.
>
> The three with genuinely nothing are `second_wind`, `wide_caster` and `quick_blade`. The audit's
> error was inferring the absence of presentation from the absence of code *in the passive scripts* —
> the feedback lives in the HUD, keyed off `CombatView.get_heal_flash()` and the status strip, which is
> exactly where it belongs and exactly where I did not look.

So the honest problem is narrower than stated: three passives are invisible, one is visible but
disconnected from its cause, and one shows its result without its trigger.

The naive fix — "give each passive a cue" — is wrong, and it is worth saying why before the spec.

**The five passives do not fire at comparable rates.** Read from the scripts:

| Passive | Hook | Fires | Where the cause is | Where the effect lands |
|---|---|---|---|---|
| `second_wind` | `on_match_won()` | **Once per won match** | the match ending | the run's HP, after combat |
| `wide_caster` | `modify_swing_duration(cells, dur)` | **Every cast of ≥ `min_cells`** | the player, at cast start | that cast's windup |
| `quick_blade` | `modify_damage(cells, dmg)` | **Every hit of ≤ `max_cells`** | the player's hit | the enemy, at impact |
| `hunter_mark` | `on_boss_thorn_step` / `on_player_zone_formed` | On a thorn event, then **3 s ICD** | the enemy's cell | the enemy (Rạn stack) |
| `prayer` | `on_frost_burst(damage)` | **Per Chill burst** on the enemy | the enemy | **the player's HP** |

Two of these fire on almost every action. Giving `wide_caster` and `quick_blade` a burst effect each
time would not read as "my passive is working" — it would read as wallpaper, and it would compete for
attention with the skill VFX, which is the thing the player actually needs to watch. The screen's
attention budget is already spent on casts, telegraphs and the formation map.

**So the rule for this phase is: frequency decides the form.**

| Band | Passives | Form |
|---|---|---|
| **Rare, outside combat** | `second_wind` | A full cue. It can be slow and satisfying; nothing competes with it. |
| **Gated, in combat** | `hunter_mark` (3 s ICD), `prayer` (per burst) | A real cue sized from the cell. These are events; treat them as events. |
| **Constant, per action** | `wide_caster`, `quick_blade` | **No new effect.** Modify the cue the action already produces, so the enhanced version is visibly different from the plain one. |

The third row is the design decision of this document. A passive that fires on every action should be
read as *a property of the action*, not as a separate event.

---

## 2. Per-passive specification

Shared constraints, from the project's standing rules: VFX are sized from the **cell**, bright, and
judged at 1× and 2× (not from a still). Floor effects sit in the **middle of the cell**, never at the
feet or the front edge. Effect text is **bare emphasised text, never a bordered chip**. Shapes are
**angular — any polygon, no circles**. Red is reserved for enemy telegraphs; the player HP green is
reserved for HP. Each cue is tinted with its character's accent from F1.

### 2.1 `second_wind` — Kiếm sĩ, `#8FA8BE` steel

*Mechanism:* +N HP after a won match, added before the max-HP clamp.

*Moment:* the victory/reward screen, not the match. The heal has already happened in `RunSession`.

*Visual:* **the original plan has no home — corrected 2026-11-14 while implementing.**

> It called for a ring from the hero sprite plus "the HP bar's gained segment" lighting on the victory
> screen. There is no such thing: `reward_view.gd` draws **no HP at all** (grep: zero matches), so the
> segment this cue was supposed to light does not exist, and the hero sprite is not on that screen
> either. This is the third premise in this document to fail contact with the code, after the
> TelegraphPainter ownership and the accent-equals-block-colour contrast.
>
> **Replacement, and it is better than what it replaces.** The player's HP after a match appears in
> the run HUD as **text** — `run_hud_view.gd:669`, `"HP x/y"`. So the cue is a `+N` in the character's
> accent beside that figure, held for one beat as the map returns, bare emphasised text with no box.
> It inherits a **carrier**: text already carries HudSkin's ink outline against the background, which
> is precisely why `PIN_BONUS_TEXT` reads and why the first `wide_caster` attempt did not. It also
> lands where the player is already looking to learn what the match cost them.
>
> Needs plumbing: `passive_heal` exists at `game_flow.gd:2581-2600` and is handed to
> `_complete_match_node`, but nothing keeps it for the HUD to show. One stored value and one accessor.
> Both files are free.

> **DECIDED 2026-11-14 — the user chose the hexagon ring on the victory screen, relayed through the
> coordinator session (not witnessed here).** That overrides the `+N`-in-the-run-HUD replacement
> above, which was my proposal, not theirs. The replacement text stays on the page because the reason
> it was written has not gone away, and it is now the thing to solve rather than the thing to ship.
>
> **What the decision buys and what it leaves open.** The ring itself is buildable on that screen —
> it needs no hero sprite and no HP segment, only a centre and a radius. What is *not* buildable as
> originally specified is the part that carried the meaning: `reward_view.gd` has **zero** matches for
> `hp`, `HP` or `heal` (re-verified 2026-11-14), so there is no figure for the ring to point at.
>
> By this document's own test, a ring alone **is decoration** — see *Why this shape* immediately
> below, written before the decision and not revised to suit it. A hexagon that appears after every
> won match, next to nothing, teaches the player that they won. They already know.
>
> **So one thing still has to be settled before this is implementable: what number the ring carries.**
> The honest options are (a) draw `+N` inside or beside the ring on the victory screen — the ring
> becomes the thing that draws the eye, the number is the content, which is what the original design
> intended the HP segment to do; or (b) show the run's HP figure on the victory screen and let the
> ring frame it — more plumbing, more useful beyond this cue. **(a) is the cheaper one and I
> recommend it.** Either way `passive_heal` must reach the screen: it is computed at
> `combat_view.gd:1563`, read at `game_flow.gd:2585`, and dropped before any view sees it — one
> stored value and one accessor, as noted above.
>
> This is not a reversal of the user's choice. The ring is theirs and stays. The open part is what
> goes inside it, which nobody has been asked yet.
>
> **Two corrections to the paragraphs above, from looking at an actual capture
> (`production/qa/evidence/ui-style-2026-11-14/after-reward-shape-tiles.png`, 2026-11-14 10:34)
> instead of reading grep output.**
>
> 1. **The `+N`-beside-the-run-HUD replacement was built on a misread and is withdrawn outright.**
>    It cited `run_hud_view.gd:669` as the place a run shows `"HP x/y"`. That line is inside
>    `_draw_between`, whose own comment says it is the between-matches panel **for a floor outside a
>    run** — "a run floor shows the reward screen instead". A run never draws it. So the home I
>    proposed for the cue does not exist on the path the cue fires on. That is the *fourth* premise in
>    this document to fail contact with the code, and the second one I wrote myself while correcting
>    the first.
> 2. **There IS an HP figure on screen at reward time, and "zero matches in `reward_view.gd`" hid
>    it.** The reward screen is an overlay: the battle scene stays underneath, dimmed, and with it the
>    battle HP plate (`cut_hud_view.gd` `_draw_hp_plates`). The capture shows it top-left —
>    "Swordsman 200/200". My grep was scoped to one file and I reported its silence as the screen's
>    silence. **A file that does not draw something is not a screen that does not show it.**
>
> 3. **"The victory screen" is one view with at least three faces, and the capture happens to show
>    the busiest.** `reward_view.gd` draws `ui.reward.title` ("CHỌN MỘT LÁ"), `ui.reward.title_treasure`
>    ("KHO BÁU") and `ui.piece_deck.ink_title` ("Học hình") — card offer, treasure, shape offer. The
>    screenshot above is the **shape** face: title, two large framed tiles, two buttons. The ring must
>    work on all three, so it has to be placed against the busiest of them, not the emptiest. Judging
>    it on a treasure screen would flatter it.
>
> This widens the choice rather than settling it, and the widening is the user's to judge. The plate
> is real but it is **dimmed, in the corner, and competing with nothing — because the eye is at the
> centre**, on "LEARN A SHAPE" and two cards that demand a decision. A ring drawn around a dimmed
> corner plate points at the right number in the wrong place. A ring at the centre with its own `+N`
> owns the moment but duplicates a figure already on screen. Neither is obviously right; both are now
> stated with their cost, which the version above was not.

> **SETTLED 2026-11-14, by the user, in this session — and it replaces the ring as well as the `+N`.**
> *"lúc chiến thắng ấy là một hiệu ứng sáng lên ở char kiểu như một ánh sáng xanh rồi cái +20hp
> hiển lên là xong"*, then **green** when asked green-vs-steel.
>
> **The cue is: at the victory moment, on the COMBAT screen, the hero's body lights green and
> `+20hp` rises. Not on the reward screen, and not a hexagon ring.**
>
> **Why this is cheaper than everything above it on this page, including my own proposals.** The heal
> figure already exists at `combat_view.gd:1563`, in the combat view, at match end — it is only
> *discarded* on the way to the reward screen. Drawing the cue where the value already lives needs
> **no plumbing at all**. Every earlier option on this page, mine included, proposed carrying that
> number somewhere it wasn't.
>
> **And the hero is only visible at that moment.** On the reward screen the hero is behind the two
> card panels; the sprite still visible on the dimmed board is the **enemy** (Mossbound Sentry, the
> `132` beneath it is its HP). I had written that the hero "is not on that screen" — true, and for a
> reason I had not checked. The victory moment, before the overlay, is the one point where the hero
> is on screen unobstructed.
>
> **Green, and specifically `HudSkin.HP_FILL` `#58D468`** — the HP bar's own fill. Do not invent a
> new green. The game has already taught the player that this exact colour means health.
>
> **The cost of green, stated rather than buried:** `giao_si`'s `prayer` heal number already draws in
> this colour (`cut_hud_view.gd:303`, `HEAL_TEXT = HudSkin.HP_FILL`), so hue alone will not say
> *which* character acted — the thing an accent exists to do. I recommended the steel accent
> `#8FA8BE` for that reason and the user chose green, which buys instant legibility instead. **The
> distinctness has to come from somewhere else, and it does: nothing else in the game lights the
> entire hero body, and nothing else fires at the victory moment.** Shape and timing carry identity;
> colour carries meaning. Keep both of those properties or the choice stops working.

> **AMENDED 2026-11-14 — no hexagon ring at all. Relayed through the coordinator session, not
> witnessed here:** *"cái chữ +20hp fade up lên ở gần char đó như cái HIT ấy"*, then the button
> *"Bỏ vòng, chỉ chữ bay lên"*. So the cue is a **damage-number-style `+20hp` rising beside the
> hero**, reusing `TEXT_DAMAGE_NUMBER` / `HudSkin.text` (`cut_hud_view.gd:2114`, `:2234`) rather than
> anything new. **Every mention of a ring on this page is dead**, and with it the low chime that was
> specified "on the ring's first frame" — there is no such frame now.
>
> **The hero really is on screen, and the mechanism is worth writing down because two sessions
> guessed wrong about it before anyone read the code.** `run_controller.gd:386` `_on_match_ended`
> does not tear the battle down. It calls `_freeze_battle()`, which only sets
> `_battle.process_mode = Node.PROCESS_MODE_DISABLED` (`:401-403`) — the node stays in the tree and
> stays drawn. The hero is standing on his cell, frozen, for `between_sec` = **3.0 s**
> (`run_config.gd:45`, `chapters.json`). A 0.8 s rise fits with room to spare.
>
> ### The trap, and the correction to the fix that was proposed for it
>
> `PROCESS_MODE_DISABLED` stops `_process` for the **whole subtree**, so a node that animates by
> advancing time and calling `queue_redraw()` freezes with it. The fix offered to me was "let the HUD
> draw it, since the HUD is not inside the frozen tree."
>
> **That is false in this project.** `src/battle/battle.tscn:34` has `CutHudView` as a **child of
> `Battle`**, alongside `CombatView` and the rest. Freezing `Battle` freezes the HUD too. Drawing the
> cue "from the HUD" would produce a `+20hp` that appears and then hangs motionless for three seconds
> — and it would do so only at runtime, looking perfectly correct in review.
>
> **What actually works** is the other half of the same advice: the node that animates the cue must
> carry `PROCESS_MODE_ALWAYS`, which overrides the disabled parent. Prefer a small dedicated node for
> it over setting `ALWAYS` on `CutHudView` as a whole — that would un-freeze every other thing the
> HUD animates, which is the opposite of what `_freeze_battle` is for.
>
> *Audio:* **none.** The ring's chime is gone with the ring, and a once-per-match `+20hp` does not
> need a cue of its own on a screen that already has victory audio. Stated rather than left blank, so
> a later reader does not restore a sound that was dropped on purpose.
>
> **CLOSED 2026-11-14, witnessed here: "Có sáng xanh" — both.** The body lights green AND the
> `+20hp` rises. The two answers that looked contradictory were answering different questions.
>
> ### How to build it, after reading the drawing code rather than guessing
>
> **The green body glow needs no new rendering code.** `unit_layer.gd:1255` `_draw_flash()` already
> draws each unit's **current frame added over itself** on an add-blend child
> (`_ensure_flash_layer()`, `:1241-1250`), via
> `_draw_frame_bands(_flash, side, texture, src, feet, flip, pose, Color(1,1,1,alpha))`. The white is
> nothing but that `Color`. **A green glow is the same call with `Color(HudSkin.HP_FILL, alpha)`**,
> and it inherits the parts that are easy to get wrong for free: the glide, the shake offset, the
> recoil, the pose, the facing flip — all of which the flash already matches to the sprite.
>
> **What does NOT come for free is the clock**, and it is the same trap as the text:
> `unit_layer._process` (`:252-254`) is what calls `_flash.queue_redraw()`, and `_process` does not
> run under `PROCESS_MODE_DISABLED`. At the victory moment the whole layer is frozen, so the existing
> flash path would draw one green frame and hold it. The hit flash is additionally driven through
> `_tick_flash_wait` in the **step** loop (`:314`), which is step-gated — the same thing that froze
> the `hunter_mark` cue earlier in this document. **Do not reuse `_flash_left`.**
>
> So: one small add-blend node with `PROCESS_MODE_ALWAYS` owning its own real-time countdown, drawing
> (a) the glow through a new **public** method on `UnitLayer` that wraps `_draw_frame_bands` — it is
> private today — and (b) the rising `+20hp` with `TEXT_DAMAGE_NUMBER` / `HudSkin.text`. Everything
> else is reuse.
>
> *(Superseded question, kept because the reasoning still applies if either half is revisited:* The user described the cue here as
> a glow *plus* text and then chose **green** (`HudSkin.HP_FILL` `#58D468`) for it; the relayed answer
> dropped the ring and said "only the text rises", which was answering a ring-versus-text question and
> did not mention the glow. Those are not the same answer and this page will not pretend they are.
> Asked, not assumed.

> ### Built 2026-11-14 — written and gated, NOT yet seen on screen
>
> `src/battle/passive_cue_layer.gd` (new) and `src/battle/unit_layer.gd` (+104 lines, 0 removed).
> The glow reuses `_draw_frame_bands`, the same path `_draw_flash` whitens a hit with, so the glide,
> shake, recoil, pose and facing come along instead of being re-derived. The text uses
> `HudSkin.text` with a new key `ui.hud.passive_heal_number` = `+%dhp`.
>
> `tests/unit/battle/victory_cue_test.gd`: **FAILS=0**, parse check clean.
>
> **What is still unproven: how it LOOKS.** No capture exists, because no demo stops in the frozen
> window after a win — `--run=gold_reward` jumps past it to the reward screen. That needs a new dev
> flag. Until then this is a cue that is known to animate and not known to read.
>
> ### The control leg nearly took the whole premise down with it
>
> The test's control — the same node set to `PROCESS_MODE_INHERIT`, which must FAIL to advance under
> a frozen parent — came back **red**: it advanced. Read plainly that says the freeze trap does not
> exist, the whole design above is unnecessary, and the control should be relaxed.
>
> It was wrong, and finding out took a **third instrument**: a throwaway probe of eight cases using
> a plain node rather than the class under test. INHERIT under a `PROCESS_MODE_DISABLED` parent gets
> **0 ticks**; `ALWAYS` runs; freezing a parent after the child is already in the tree stops it dead.
> The premise holds exactly as written.
>
> The real cause, reproduced: **a node built in the first moments of `_initialize` reports
> `can_process() == true` for a couple of frames even with a disabled parent**, because the tree has
> not built its process lists yet. Identical code a few frames later reports `false`. The control leg
> sat in that window. Two burnt frames fix it, and it now separates cleanly — INHERIT frozen at
> `0.0000`, the shipped node running at `0.0207`.
>
> **Two things worth keeping from that.** A red control has two readings — "the gate is broken" and
> "the premise is wrong" — and they are the same colour; only an instrument independent of both can
> tell them apart, and the tempting move (relax the control until it is green) would have left a test
> that passes forever while explaining itself wrongly. And this failed **loudly**: had the startup
> window made the control *green* instead of red, nothing would ever have pointed at it, and the file
> would be guarding something it cannot guard.

*Why this shape:* the player must connect "I won" with "I got HP back". Lighting the gained segment
is the connection; the ring is only what draws the eye to it. Without the segment highlight, the cue
is decoration.

*Audio:* `passive.second_wind` — one low sustained chime, struck **on the ring's first frame**, decay
inside 0.6 s. Bus `Combat`, priority `normal`. No drone, no riser.

*Rank display (F5):* when passive ranks land, the number in the gained segment is the only thing that
changes; the cue does not grow louder with rank.

### 2.2 `wide_caster` — Pháp sư, `#E08A2E` ember

*Mechanism:* casts covering ≥ `min_cells` wind up `duration_mult` times as long (0.75 = 25 % faster).

*Moment:* cast start, on the player.

*Visual:* **no new effect — the player's windup is already drawn.**

> **CORRECTION, 2026-11-14 (found while implementing).** The first version of this section named
> `telegraph_painter.gd:54` as a second consumer of the player's windup. **It is not.** TelegraphPainter
> draws the **BOSS's** attack telegraph on the player's half, in the reserved enemy red `#E5293B`
> (`floor_layer.gd:146` passes `_combat.get_boss().get_actor()`). Recolouring it would have marked the
> enemy's attack with the player's accent. The error came from grepping for `get_progress()` consumers
> without checking whose actor each one reads. **Only one consumer draws the player's windup:**
> `floor_dynamic_layer.gd:177`, which reads `combat.get_cut_actor()` and paints the charge steps.

The charge is painted by `CastFloorFx.charge_colours(base, light, step, steps)` with
`base`/`light` from `CastVfx.block_colours(hero_id)` — i.e. **already per-character**. For a
qualifying cast the charge is marked; a non-qualifying one is unchanged.

**Readability problem to solve, not to paper over.** Tinting the charge with the character's accent
is nearly useless for the character that owns this passive: `phap_su`'s accent is ember `#E08A2E` and
its block colours are ember, so accent-on-accent is invisible — the exact "can't see it from afar"
failure the project has rejected before. So the mark must not rest on hue alone. First attempt: accent
tint plus an **outline one pixel thicker**, on the theory that thickness survives where hue does not.

> **MEASURED 2026-11-14 — that attempt FAILED the readability gate.** A/B capture at 1280×720, same
> card (`hoa_xa`), same seed, same frame, 4 cells (cue on) against 3 cells (cue off):
> `production/qa/evidence/character-system/f3-wide-caster/`. The only difference a viewer can see is
> the **number of charged cells**, which is the cast's size, not the passive's mark. The accent tint
> does nothing because it is the block colour, and +1 px of outline is imperceptible at this zoom.
>
> Correctness passed in the same run (`passive_cue_test`, FAILS=0) — the cue marks exactly the right
> casts. It is simply invisible. That is precisely why these are two gates: a cue can be perfectly
> correct and worthless, and a single "it works" would have hidden it.
>
> **Second attempt, 2026-11-14 — rhythm, not brightness.** The user chose "make the charge brighten
> faster". Implemented as a change of *rhythm*, because speed alone cannot be seen: a player watching
> one cast has no slow version beside it, which is the same structural flaw as an accent that equals
> the block colour — nothing to compare against. A qualifying cast brightens in **2 steps instead of
> 4**, so each jump is a visible tick rather than part of a smooth ramp, and that is perceptible in a
> single cast because what differs is the *character* of the animation, not a quantity.
>
> **Risk stated before running it, and MEASURED AGAINST.** The prediction was that the qualifying
> cast would stay *darker* for the first half (`charge_colours` ramps on `step / (steps - 1)`: 4 steps
> → 0.00 / 0.33 / 0.67 / 1.00, 2 steps → 0.00 / 1.00) and so read as sluggish, the opposite of the
> mechanic.
>
> **It did not happen, and the reason matters.** That analysis compared the legs *progress for
> progress*. The capture compares them *frame for frame* — wall clock — and the passive shortens the
> windup to ×0.75, so at the same frame the qualifying cast is further along. The two effects compound
> in the right direction instead of fighting.
>
> **Result — the readability gate PASSES.** `production/qa/evidence/character-system/f3-wide-caster/rhythm/`,
> same card (`hoa_xa`), same seed, frames 30/50/70/90:
> - **Frame 30:** 4 cells (cue on) is already bright orange with strong outlines; 3 cells (cue off) is
>   still dim brown with faint outlines. The difference is obvious at 1× without hunting for it.
> - **Frame 50 onward:** both are at full brightness — the cue converges.
>
> So the mark lives in the **first half of the windup** and then stops distinguishing. That is the
> right window rather than a limitation: it tells the player while the cast is still in flight, and it
> leaves the end state identical, so nothing has to be unlearned. Accept as shipped; the accent tint
> and the +1 px outline stay as harmless reinforcement, no longer load-bearing.
>
> **Do not reach for a brighter colour.** The next levers, in order: (1) animate — make the
> qualifying charge step through its palette *visibly faster*, which is the mechanic itself and needs
> no new colour; (2) change the outline's *shape*, e.g. corner ticks only, so the silhouette differs
> rather than the hue; (3) a one-frame snap at completion. Only if all three fail does this cue need
> something that is not already on screen — and at that point the honest answer may be that
> `wide_caster` cannot be read from the charge at all and needs its own mark.

The cue matches the mechanic either way: the passive makes the windup **shorter**, so what the player
sees is the charge they already know completing visibly sooner — the thing that actually changed.

*Why:* the player's question is never "did something happen?" — a cast is already loud. It is "was
*this* cast the fast one?". A colour difference on the thing they are already watching answers that;
a new particle does not.

*Audio:* **none.** Adding an event to every wide cast would spend a `Skill`-bus voice on information
the visual already carries. If an audible difference is wanted later, it should be a pitch offset on
the **existing** cast event rather than a new event — the mechanism and the right owner for it are an
open question (§4, Q2).

### 2.3 `quick_blade` — Sát thủ, `#6FD8E8` keen ice

*Mechanism:* hits covering ≤ `max_cells` deal `damage_mult` times damage.

*Moment:* impact, on the enemy.

*Visual:* **no new effect, and the codebase already contains the pattern to copy.**
`cut_hud_view.gd:2144` draws a hit's damage number in `PIN_BONUS_TEXT` ("pin blue") when Ghim
multiplied it — a keyword that boosted a hit already announces itself by **recolouring the number**.
`quick_blade` does exactly that in keen ice `#6FD8E8`. Nothing new is invented and the player already
knows how to read it.

Second beat, also existing: `UnitLayer` runs an OSFE hit feel (`CastVfx.hit_feel()`, white flash plus
shake per side, `get_flash_left`). For a boosted hit that flash is tinted keen ice instead of white.
One frame, inside the flash's own timeline.

*Why:* same argument as `wide_caster`, at the other end of the action. The impact is already the
loudest moment on screen; the passive should ride it, not follow it. And a convention the project has
already approved for Ghim beats a new convention invented for one passive.

*Audio:* **none**, for the same reason. The impact event already fires.

### 2.4 `hunter_mark` — Thợ săn, `#7FA64B` wood and cord

*Mechanism:* the enemy gains `fragile_stacks` Rạn when it steps onto the player's thorns, or when
thorns are laid on/next to its cell; then a `icd_sec` (3 s) internal cooldown.

*Moment:* on the enemy's cell, in combat. This is the one passive whose cue the player must read
**during** a fight, because it tells them a window has opened.

*Visual:* a floor mark, **centred in the enemy's cell** (standing rule — not at its feet, not at the
front edge): an angular bracket, two short wood-coloured strokes closing inward like a trap frame,
drawn over the cell for ~0.4 s, then handing off to the existing Rạn status indicator which persists.
Sized from the cell: the bracket spans roughly 70 % of the cell width so it reads at 1× from across
the board.

*Why a hand-off:* the mark is the *event*; Rạn is the *state*. The cue must not duplicate the status
indicator, or the player sees two things saying one thing.

*Audio:* `passive.hunter_mark` — one short wooden snap on the bracket's closing frame. Bus `Combat`,
priority `normal`, **`cooldown_ms: 400`** as a safety net (the 3 s ICD already gates it; the cooldown
exists so a future ICD change cannot turn it into a machine gun).

### 2.5 `prayer` — Giáo sĩ, `#C08FE8` stained glass

*Mechanism:* every Chill burst on the enemy heals the player `heal_per_burst` HP.

*Moment:* the burst happens **on the enemy**; the heal lands **on the player**. This is the only
passive whose cause and effect are in different places, and it is the one most likely to be missed.

*Visual:* a **connector**, not a flash. An angular line — two or three straight segments, no curve —
travels from the bursting cell across to the player's HP bar in `#C08FE8` over ~0.35 s, and the HP
bar's gained segment lights as it arrives. The existing Chill-burst effect is unchanged.

**Sized from the cell, not hairline.** The connector's stroke is **≥ 1/8 of a cell's width**, with a
brighter leading head about half a cell long. A one-pixel line is the single most likely way this cue
fails: it crosses the busiest part of the screen, and the project has already seen a VFX rejected for
being invisible from afar. It must be judged at 1× **and** 2× before it is called done — a still will
flatter it.

*Why:* without the connector the player sees a burst on the enemy and, separately, their own HP
rising, and never joins them. The whole informational content of this passive is the link.

*Audio:* `passive.prayer` — one short glass chime, struck **when the connector arrives** at the HP
bar, not when the burst fires. Bus `Combat`, priority `normal`, `cooldown_ms: 300`.

---

### 2.6 Standing-rule compliance, per cue

The user restated the cue rules when approving this phase. Mapping them to where each is honoured, so
a reviewer can check rather than trust:

| Rule | Where it binds in this spec |
|---|---|
| **Readable from afar, sized from the cell** | `second_wind` ring ≈ 2 cell widths · `hunter_mark` bracket ≈ 70 % of a cell · `prayer` connector stroke ≥ 1/8 cell with a half-cell head (§2.5) · `wide_caster` / `quick_blade` inherit the size of the telegraph and impact they recolour |
| **Judged at 1× and 2×, not from a still** | §2.5 explicitly, and acceptance criterion 1 requires a retained screenshot per passive at 1× |
| **Effect labels: bare emphasised text, no bordered chip** | `quick_blade`'s damage number (§2.3) — and it inherits the existing `PIN_BONUS_TEXT` treatment, which is already bare text |
| **Audio synced to a real frame, no waiting drone** | `second_wind` on the ring's first frame · `hunter_mark` on the bracket's closing frame · `prayer` on the connector's **arrival**, not on the burst · explicit "no drone, no riser" |
| **Angular shapes, no circles** | `second_wind` is a hexagon outline, stated as "not a circle" · `hunter_mark` is a two-stroke bracket · `prayer` is straight segments, "no curve" |
| **Floor VFX centred in the cell** | `hunter_mark` (§2.4) — the only floor effect here, centred, explicitly not at the feet or front edge |
| **No hand-painted details** | Icons are glyphs produced by script / workbench (§3), not painted over generated art |

### 2.7 One rule this phase cannot satisfy yet

**Audio must sync to real clip/VFX frames — but the VFX frames do not exist yet.** Every timing above
("first frame", "closing frame", "on arrival") is a *contract* for implementation, not a measurement.
When F3 is built, each cue's audio offset must be re-derived from the finished animation and proven
with an in-game capture plus a timing table, the way the skill audio was. Writing the numbers now
would be inventing them.

---

## 3. Icons

Five passive icons, one per passive, plus the five signature icons listed in the parent document.

- **Production: free only** (OD-6 approved) — scripted / `vfx_workbench` / `pixelfx`. No paid
  generation for icons.
- Flat angular glyph, no outline box (standing rule: icons over text, no borders), tinted with the
  character's accent, legible at **24 px** (HUD chip) and at select-card size.
- One glyph per mechanism, not per character: a closing bracket for `hunter_mark`, a struck chime for
  `prayer`, a short blade for `quick_blade`, a broad arc for `wide_caster`, a rising step for
  `second_wind`. A player who sees the icon on the select screen should recognise the cue in combat.
- Paths follow the F1 schema: `identity.passive.feedback.icon`, already specified in
  `assets/data/schema.md`.

---

## 4. Open questions — need an answer before implementation

| # | Question | Why it blocks | My recommendation |
|---|---|---|---|
| ~~Q1~~ | ~~Does the game show damage numbers on hits?~~ | — | **ANSWERED by reading the code, 2026-11-14.** Yes: `cut_hud_view.gd` `_draw_feedback_for` draws a per-hit damage number, and **already recolours it when a keyword multiplied the hit** — `PIN_BONUS_TEXT` for Ghim (`:2144`), a larger `CRIT_NUMBER_SCALE` for crits. So `quick_blade` follows an approved existing convention rather than needing a new one, and `UnitLayer`'s existing white hit flash (`CastVfx.hit_feel`) gives it a second beat for free. §2.3 is updated; no new system is required. |
| **Q2** | `wide_caster` / `quick_blade` audio: no new event, or a pitch offset on the existing cast/impact event? `audio_events.json` has `step_pitch_semitones` and `step_gain_db` in `defaults`, but I have not confirmed what they apply to. | It decides whether F3 touches `src/audio` at all, which is the audio session's file. | **No audio for either** in F3. Ship the visuals, play it, and only add sound if the passives still read as invisible. Adding sound is cheap later; removing it after players learn it is not. |
| **Q3** | Where does the passive chip live in the combat HUD? The parent document proposes icon + rank beside the signature readiness. | F6 owns the select screen; the combat HUD is not yet assigned to a phase. | Put the chip in F3 with the cues — a cue the player cannot connect to a named passive teaches nothing. It is one icon in an existing HUD row. |
| **Q4** | `second_wind`'s cue is on the victory screen, which is run UI, not combat. Is that in F3's scope or F6's? | Scope boundary only; the work is small either way. | Keep it in F3. The phase is "the player can see each passive"; splitting one of the five into another phase breaks that acceptance criterion. |

---

## 5. Acceptance criteria for F3

1. Each of the five passives has a cue a player can identify **from across the board at 1× speed**,
   with a retained screenshot per passive in `production/qa/evidence/character-system/`.
2. `wide_caster` and `quick_blade` add **no new on-screen object** — a qualifying action differs from
   a non-qualifying one, and that difference is visible in a side-by-side capture.
3. `prayer`'s connector is visible from burst to HP bar in one capture — the cause and the effect in
   the same frame.
4. `hunter_mark`'s floor mark is **centred in the cell** and hands off to the Rạn indicator without
   duplicating it.
5. Every cue is tinted with its character's accent from `characters.json` — **no colour is hardcoded
   in combat code** (the F2 rule, extended to presentation).
6. Each registered passive has an icon, and `passive_feedback_test.gd` fails if any passive is missing
   an icon, a vfx key or (where specified) an audio key.
7. No new audio event fires more than once per gating interval; the full suite reports **0 script
   errors**, read from the runner's `se` column, not only `FAILS=`.

---

## 6. What this phase deliberately does not do

- **No new status effects, no mechanic changes.** Every passive's numbers and triggers stay exactly as
  they are. F3 is presentation only; if a passive turns out to be weak, that is a balance question for
  the F5 slice, not a reason to change it while adding its cue.
- **No paid art.** Icons are free-produced (OD-6).
- **No audio for the two high-frequency passives** (Q2), pending play-testing.
