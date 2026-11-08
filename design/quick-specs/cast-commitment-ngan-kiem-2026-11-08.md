# Cast Commitment: design proposal (prototype: Ngàn Kiếm)

**Type:** new small system · **Date:** 2026-11-08 · **Status:** PROTOTYPE IMPLEMENTED for Ngàn Kiếm only (user-approved
2026-11-08; §10 lists what was built and measured). Other cards: not applied.

**Scope:** Tessera stays a real-time *tactical* game. This system gives one choice a clear cost: "commit to this cast
now?". It does not add reflex tests.

## 1. Audit of what exists today (file:line in `src/combat/`)

| Topic | Today |
|---|---|
| **Planning time** | From the piece pickup until a card is chosen, the simulation is **stopped** (`menu_time_scale` 0, `focus_time_scale` 0; combat_view `_sim_scale`). The place window (4.0 s) and the menu run on real time; the boss and the clocks are frozen. |
| **Pieces (Blocks)** | Leave the bag at placement / join (CV:1774, 2007). `Hủy` returns them in the place window or the menu (CV:2060). They are **spent at card choice** (CV:2187-2191) and are never returned on a swing cancel or interrupt. |
| **Cooldown** | Starts at **swing start**, right after `begin_swing` (CV:2227-2228). It ticks on simulation time. **No refund anywhere** on cancel or interrupt (the only clear is the thien_hoa signature). |
| **Voluntary cancel** | **None once the swing runs.** `Hủy` / Esc covers PLACING, the place window and the menu only. |
| **Interrupts of the player's swing** | 1) a block-boss swing or scheduled event that hits the hero (swing_arbiter 281-289, 423-435): pieces and cooldown are lost; 2) death of either side (`_cancel_all` + `clear_scheduled`). **Pattern-enemy attacks, hazards and traits never interrupt** the player's swing (they only deal damage). |
| **Scheduled casts (Skill v2)** | Created at the swing end (`at = clock + t`). They survive the caster being hit; only death clears them. |
| **Movement** | Locked by Focus / placing / the menu. Ngàn Kiếm (`cast_root_lead_sec` 0.22) roots the hero for its whole swing and until 0.22 s before its first hit. A step during any other swing does not affect that swing. |
| **Pause** | Refused in the menu or place window, and in the last 0.5 s of either side's swing (`pause_lockout_sec`). |
| **Block-brain boss** | Sees the player's swing cells after `reaction_sec` 0.35 s (0.25 s aggressive) and dodges a visible swing (step cooldown 0.55 s; rooted while it swings itself). Cells it saw stay "incoming" while scheduled. |
| **Pattern enemy** | Windup 0.4–0.9 s, warning 0.9–1.6 s (never tempo-scaled), recovery 0.2–1.5 s. The player's first damaging hit interrupts an interruptible tell (cooldown × 0.5); RECOVERY cannot be interrupted. Fairness: `reaction_margin_sec` 0.25, `min_gap_between_warnings_sec` 0.4. |
| **Mobile controls** | Floating joystick (left); piece bag; bottom-left row while placing: Tung phép · Xoay · Hủy; card menu (Hủy moves to Tung phép's corner); signature button; pause tile. **No control exists for cancelling a running swing.** |

### Ngàn Kiếm today (plus5, 5 cells): the timing problem

| Time | Gameplay | What the player sees |
|---|---|---|
| 0.00 | swing starts (cooldown starts, hero rooted) | guard → crouch |
| 0.166 | — | sword raised; swords start forming on the tiles |
| 1.45 | **swing end = the cast is scheduled (authoritatively committed)** | still holding the sword up |
| 1.73 | root ends (first hit − 0.22) | **pull-down** (looks like the commitment) |
| 1.85 / 1.95 | first sword falls / hits | stab |
| … 2.43 | last hit (finale) | |

- **Does movement during the hold trigger the command or the damage?**
  - **Not now:** every step is refused from 0.00 to 1.73.
  - **Before the root rule:** a step after 1.45 cleared the visual hold and **played the pull-down early (visual only)**.
    The damage was never triggered by movement: it was already scheduled at 1.45.
  - **The real defect: the authoritative commitment (1.45) and the visual one (1.73) differ by 0.28 s.** During that
    window the player sees "still channeling", but the attack can no longer be stopped.

## 2. State machine

```text
        ┌──────────── Hủy (pieces back) ───────────┐
        ▼                                           │
     IDLE ──pick piece──► PLANNING (time stopped) ──choose card──► CHANNELING ──channel time reached──► COMMIT
       ▲                                                           │   │                                │
       │                                       Cancel (button) ────┘   └── interrupted (block-boss hit) │
       │                                                ▼                          ▼                    ▼
       │                                           CANCELLED                 INTERRUPTED          RESOLUTION
       │                                   (no attack; cost: §4)      (no attack; same cost)  (hero free; committed
       └───────────────────────────────────────────────┴──────────────────────────┴────────── events run on the clock)
   Death of either side: from any state → everything cleared (as today).
```

| State | Time | Hero | Attack | Inputs |
|---|---|---|---|---|
| PLANNING | stopped | — | none | as today (place, rotate, Hủy, choose a card) |
| CHANNELING | runs | **rooted**, casting pose, the summon visible on the tiles | not yet committed | **Cancel** only (the joystick is dimmed) |
| COMMIT | instant, + `commit_lock_sec` | locked during the release gesture | **scheduled now** (authoritative) | none |
| RESOLUTION | runs | **free** | committed events fire at their `at` | everything (a new cast may be planned) |

The transitions are evaluated on the arbiter clock tick. **The commit is exactly the tick the channel time is
reached**; a Cancel arriving in the same tick or later is ignored, so commit wins ties.

## 3. Ngàn Kiếm phase timeline (proposed; the impact times are unchanged)

The fix aligns the authoritative commit with the pull-down. It moves 0.28 s of the post-swing hover INTO the
channel, so every impact still lands at the same time after the card choice.

| Value (cards.json) | Today | Proposed |
|---|---|---|
| channel (swing) length | 0.2 + 0.25 × cells (plus5 1.45) | the same + `channel_extend_sec` **0.28** (plus5 1.73) |
| `sky_hover_sec` (commit → first hit) | 0.50 | **0.22** |
| `cast_root_lead_sec` | 0.22 | replaced by `commit_lock_sec` **0.13** (release frames 5–6) |

| Time (plus5) | Phase | Hero | Tiles |
|---|---|---|---|
| 0.00 | CHANNELING | crouch | — |
| 0.166 | CHANNELING | sword raised (summon) | swords form in schedule order |
| 0.33 → 1.73 | CHANNELING | summon hold, can Cancel | swords hover, shadows darken |
| **1.73** | **COMMIT** | **pull-down** | lock-on flash |
| 1.73 → 1.86 | COMMIT lock | release gesture | — |
| 1.86 → | RESOLUTION | **free** | first sword falls at 1.85, hits at **1.95** (unchanged); the last at 2.43 (unchanged) |

- The pull-down now *is* the commitment, and the stab follows 0.22 s later.
- The boss's view is unchanged: it saw the cells from 0.35 s into the channel, and its time to impact is the same as
  today.

## 4. Cancellation and its cost: three alternatives

A cancel in CHANNELING never deals damage, and the swords disperse. What it costs:

| | A. Spent (= interrupt today) | B. Pieces back, cooldown runs | C. Cost by progress |
|---|---|---|---|
| Pieces | spent | returned to the bag (first free slots; a full bag drops the extra) | spent |
| Card cooldown | full | full | `cooldown × (0.5 + 0.5 × channel progress)` |
| What cancel buys | movement now (escape a misread telegraph) | escape + keep the board plan | escape; an early read is cheaper |
| Abuse risk | none | **baiting**: channel to make the boss dodge, cancel, re-place on its new cell at no piece cost | some baiting; cheaper early cancels |
| Readability | simple, consistent with interrupts | simple | needs a UI hint (fuse) |
| **Recommendation** | **prototype** | second test if cancels are never used | not now |

**Recommended: A.** The cancel is an emergency exit ("I misread the telegraph: get out"), never a free retry.
Interrupts and cancels cost the same, so neither is the better way to lose a cast.

## 5. Boss interaction and fairness

- **Block-brain boss:** the summoned swords are a true telegraph.
  - It reacts after 0.35 s, and a 1.73 s channel gives it time to step out (step cooldown 0.55 s).
  - Counterplay for the player: choose cells where the boss will be (its path, corners), or channel while the boss
    is rooted in its own swing (`root_while_swinging`). That is the "predict enemy positions" pillar.
- **Example 1:**
  - The boss stands on the Plus centre.
  - The player channels and the boss reacts at 0.35 s, stepping right at about 0.6 s.
  - The player sees it leave: commit anyway (the swords on the right arm may still hit) or cancel (cost A: the
    cooldown and pieces are lost, but the hero is free).
- **Example 2:**
  - The player channels while the boss winds up its own swing.
  - The boss is rooted, so the swords land.
  - Its swing may hit the rooted hero first: an interrupt, same cost as A.
  - Hence the rule: **read the boss's swing before you channel.**
- **Pattern enemy:** its warning (0.9–1.6 s) can start during the channel, and its attacks do not interrupt the
  player.
  - The hero, rooted, sees the warning and decides: Cancel and step out (≥ 0.65 s of the warning left after
    `reaction_margin` 0.25 + the step), or commit and take the hit.
  - The first damaging sword still interrupts an interruptible tell (as today), so a well-timed commit can cancel
    the enemy's attack. That is a calculated-risk trade.

**Fairness rules:**
1. Commit wins ties: a Cancel in the commit tick is ignored and stated so in the UI.
2. Pattern-enemy hits never interrupt the channel (as today), so the player's commitment is not broken by
   untelegraphed chip damage.
3. A warning that starts during a channel must leave ≥ `reaction_margin_sec` + the step cooldown + 0.1 s before it
   lands; every current warning (≥ 0.9 s) already does.
4. While the hero is rooted, the joystick is visibly dimmed, so being unable to move is never a surprise.

## 6. Mobile input flow

1. PLANNING: as today (drag pieces, Tung phép, choose a card).
2. CHANNELING:
   - The bottom action row shows **one angular "Hủy" button** in the Tung phép slot (the right thumb, far from the
     floating joystick on the left).
   - The joystick dims and ignores drags.
   - **Accidental-tap guard:** Hủy ignores taps for the first 0.15 s of the channel, so the finger that chose the
     card cannot cancel it.
   - Desktop: Esc.
3. COMMIT: the Hủy button collapses with the pull-down. Nothing is tappable for `commit_lock_sec`.
4. RESOLUTION: the joystick lights up; the normal controls return.
5. Pause: allowed in the channel except the last 0.5 s (the existing lockout), never during the commit lock.

## 7. Risks and edge cases

- **The boss or the hero dies during the channel:** everything is cleared, with no cost to resolve (as today).
- **Awakening during the channel:** allowed (it does not move the hero). Its extra hit is read at the commit.
- **Cells locked during the channel:** the preview already drops them; the commit uses the cells locked at that
  moment (the same resolver).
- **Pickups:** a rooted hero cannot step onto pickups; their timers keep running (an intended cost of channeling).
- **Network or replays:** none (single player); the commit is on the deterministic arbiter clock.
- **Swing-time relics / passives** (`cast_time_modifier`): they scale the swing part; `channel_extend_sec` is added
  after them so the stab gap stays fixed.
- **Sim / bots:** `tools/balance/sim_core` must implement the same commit and root, or balance runs will disagree
  with the game.
- **Other cards:** unaffected unless their data opts in (`commitment` block per card).

## 8. Recommended first playable prototype

Ngàn Kiếm only, data-driven, behind its own card fields:
- `cards.json` `ngan_kiem`: `channel_extend_sec` 0.28, `sky_hover_sec` 0.22, `commit_lock_sec` 0.13,
  `cancel_policy` "spent" (A). Remove `cast_root_lead_sec`.
- **Code:**
  - the swing duration adds `channel_extend_sec`;
  - a CHANNELING cancel path (a player CutActor cancel and its cost; pieces and cooldown per policy);
  - the commit lock;
  - the Hủy button during the channel;
  - the joystick dims while rooted.
- **Visuals:** the hold already exists; the pull-down moves to the swing end (simpler than today's post-swing hold);
  "the swords disperse" on cancel (the existing shatter).

## 9. Tests and playtest plan

**Automated** (unit + headless CombatView, deterministic):
- States: PLANNING → CHANNELING → COMMIT → RESOLUTION; CHANNELING → CANCELLED; CHANNELING → INTERRUPTED.
- Cancel deals 0 damage and schedules nothing; the cost matches the policy (pieces, cooldown); a commit-tick cancel
  is ignored.
- Impact times identical to today's baselines (plus5 1.95 … 2.43, bar4 1.70 …); first hit = commit + 0.22.
- Root during the channel; locked for `commit_lock_sec` after the commit; free afterwards.
- The pause lockout respected; death in each state clears everything.
- The boss's seen-cells timing unchanged; the pattern tell interrupted by the first damaging sword (as today).

**Playtest metrics** (per Ngàn Kiếm cast):
- cancel rate, and the reason (a warning seen / the boss moved / accidental);
- the share of casts that hit ≥ 1 time; damage per cast; damage taken while rooted;
- the boss's dodge rate during the channel; time to kill vs today;
- accidental-cancel reports (target: 0); "did the pull-down read as the commitment?" (yes / no).

**Approval needed:** the phase values (§3), the cancel policy (§4), and adding a channel-cancel path (§6).

## 10. Prototype as built (2026-11-08)

**Data** (`cards.json` `ngan_kiem`): `channel_extend_sec` 0.28, `sky_hover_sec` 0.22, `commit_lock_sec` 0.13,
`cancel_policy` "spent"; `cast_root_lead_sec` removed.

**Code:**
- `CutActor.channel_extend_fn` adds the extension after every swing-time modifier. CombatView and sim_core wire it.
- **CombatView:**
  - `channel_phase` (channeling / commit / resolution), `is_cast_rooted`, `is_commit_locked`;
  - `request_channel_cancel`: queued and resolved AFTER the arbiter tick, so commit wins ties; a 0.15 s guard;
  - `can_pause` is refused during the commit lock;
  - a cancel disperses the summoned swords (`SkyDropFx.dispersed`: shatter where they hovered, no impact);
  - the pull-down and the lock-on happen at the commit.
- **CutHudView:** a red Hủy on the RIGHT above the Block bag (`ScreenLayout.channel_cancel_rect`; Tung phép's slot is
  on the joystick side), with the cost line "mất khối · thẻ vẫn hồi chiêu". Esc. ĐÃ HỦY / ĐÃ CHỐT feedback. The
  joystick dims through `is_step_locked`.
- **sim_core:** the same extension, root and commit lock; a bot cancel policy ("never" / "on_warning"); `ch_*`
  metrics. Probe: `tools/balance/ngan_kiem_probe.gd`.

**Timing (measured in battle, identical to the baselines on the clock):**
- bar4: commit 1.48, first impact 1.700;
- plus5: commit 1.73, impacts 1.950 … 2.430.

**Balance probe** (chapter 1, 16 matches × 12 seeds, starter + 2× Ngàn Kiếm; bot):

| Set-up | Win % | Mean s | NK casts | Interrupted | Committed | Casts that hit % | Damage / committed | HP lost channeling / cast | Cast in enemy recovery % |
|---|---|---|---|---|---|---|---|---|---|
| PREV (root to −0.22, no cancel) | 92 | 76.9 | 781 | 51 (6.5 %) | 729 | 60 | 10.2 | 2.29 | 23 |
| COMMIT | 93 | 76.3 | 786 | 76 (9.7 %) | 710 | 62 | 10.8 | 3.48 | 24 |
| COMMIT + cancel on warning | 93 | 76.4 | 787 | 74 | 709 | 62 | 10.8 | 3.42 | 24 |

- **Reading:** outcomes are unchanged (win %, match length).
- **The new cost:** +3 % of casts interrupted (the channel is 0.28 s longer and interruptible) and about 1.2 HP more
  lost per cast while channeling.
- **The new benefit:** slightly more casts that hit (the commit comes later, closer to the impact).
- **Bot cancels:** only 4 of 787 casts. The bot's warning test rarely fires during a channel, so cancel frequency and
  accidental cancels need human playtests.

