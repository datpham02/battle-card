# Skill v2 — Ngàn Kiếm overall acceptance (real battle)

**Date:** 2026-11-08 · **Status:** **APPROVED by the user (2026-11-08) as a completed technical prototype**:
animation (`cast_summon`), tile-summon VFX, gameplay and Cast Commitment. Full suite **212/212** green (§8).
**Pending, not blocking:** real Android device QA and a human playtest (§8).
**Build:** committed on top of f554a9b · **Scope:** animation, VFX and gameplay in real battles. No PixelLab calls.

**Setup:** `--character=kiem_si --seed=1 --match=1 --arena=rect --demo=tram_live --no-autopause --live-card=ngan_kiem`,
60 fps fixed, 240 frames per scenario.
**Evidence:** `production/qa/evidence/skill-v2-ngan-kiem/acceptance/`.

## 1. Gameplay (authoritative events vs the frozen baselines in `sequences/*.events.txt`)

| Scenario | Shape | Drops | Hits | vs baseline |
|---|---|---|---|---|
| cross_plus5 | Plus (branched; finale ×1.5) | 5 | 1 (finale, 18) | **identical** |
| branch_t4 | T rot 2 (branched) | 4 | 1 (finale, 18) | **identical** |
| l_shape_l4 | L rot 1 | 4 | 1 (12) | **identical** |
| straight_bar4 | straight line | 4 | 1 (12) | **identical** |
| moving_boss | line, boss steps +1 mid-cast | 4 | 2 (12 + 12, two different drops) | **identical** |
| boss_2x2 | L, 2×2 pattern boss | 4 | 1 (one hit per drop under the boss) | **identical** |
| locked_cell | line with (6,1) locked | **3** (no drop on the locked tile) | 1 (12) | rule respected (no older baseline) |

- **Identical** means the same clock times, cells, order, kinds, hits, damage and boss move.
- Damage, cooldown, hit caps, drop order, the hero-only reward and boss interaction are unchanged.
- **Also covered by tests:** `ngan_kiem_test` (14 groups: Awakening +1 hit, defense, interruption, determinism,
  pattern interrupt), `hero_card_pool_test`, `skill_v2_golden_test`.

## 2. Animation (`cast_summon`, bound by `card_casts.ngan_kiem`)

| Beat | Slot / time | In battle | Result |
|---|---|---|---|
| Guard | 0 | F0–F5 | PASS |
| Crouch (anticipation) | 1 / 0.083 s | F5–F9 | PASS |
| **Sword raised high** | 2–3 / 0.166 s | F10 | PASS: clear one-handed raise |
| **Summon hold** | 4 / 0.33 s → command | held past the swing end, until the command | PASS |
| **Pull-down = command** | 5, at first fall − 0.12 s | plus5 F104, line / L / T F89 | PASS |
| Command pose, return, guard | 6–8 | | PASS. The return is a short re-lift of the sword before the guard. |

- **Feet:** x32–38 on the bottom row in all 9 slots (no slide).
- **Identity:** face, silver hair, armour, navy cape and gold trim, sword. The torso opens toward the camera on the
  raise (the head stays 3/4): accepted, but noted.
- **When the enemy hits the hero after the command:** plus5 at 1.70 s, a correct play, because the first damaging
  sword lands after the goblin's warning. The hit flash and hit pose replace the recovery. The hold and the command
  have already played (`02-plus5-hero-hold-command-hit-2x.png`).

## 3. VFX

| Check | Result |
|---|---|
| Swords form on the TARGET tiles from the raise (shadow, gathering steel, sword built part by part, hover) | PASS on all 7 scenarios |
| Untargeted tiles show nothing; a locked tile gets no sword | PASS |
| Branched finale bigger (Plus, T) | PASS |
| Lock-on at the command (white flash, 4 px cock-up), then each stab at its own `at` | PASS (`test_on_tile_summon`) |
| Ground impact, floor stamp, finale board shake | PASS |
| Nothing flies from the Knight (no beam, no projectile, no sky column, no release streak) | PASS |
| Cleanup: no sword left after the last shatter; the cast dropped → pending swords vanish | PASS (captures + `sky_drop_fx_test`) |
| Gameplay untouched by drawing | PASS (identical events; the preview runs the same resolver, visual only) |

## 4. Tests

- Full suite **209/209** green, 0 script errors, golden unchanged. This was the last run after the last code change;
  only docs and evidence changed since.
- New / updated this round: `sky_drop_fx_test` (`test_on_tile_summon`: 9 checks, mutation-checked);
  `sheet_export_test` and `sprite_sheet_test` (96×92 frame, prototype clips); `unit_sprites_test` (frame size).

## 5. Not passed / not tested

1. **ACCEPTED by the user (2026-11-08): top-row HUD.** The raised pose overlaps the HUD on 3 of 4 top-row cells:
   column 0 the HP panel / relic column, columns 2–3 the title. Column 1 is clear
   (`04-hud-top-row-raised-hold-2x.png`). The user chose to ignore it; no change.
2. **Superseded by Cast Commitment (§7, §8).** The first version of the movement rule is kept below for history;
   `cast_root_lead_sec` and `ngan_kiem_root_test.gd` were removed, replaced by the channel / commit lock and by
   `ngan_kiem_commitment_test.gd` + `ngan_kiem_full_flow_test.gd`.
   *History* — movement during the cast (user rule 2026-11-08: no step while the sword is raised; no cancel after
   the pull-down; free while the swords fall), first set in data as:
   - `cards.json` `ngan_kiem.cast_root_lead_sec` 0.22 roots the hero from the swing start until 0.22 s before the
     first scheduled hit, the same instant as the visual pull-down;
   - `CombatView.is_cast_rooted` / `is_step_locked` refuse steps (the d-pad dims). Focus and Awakening locks are
     untouched;
   - nothing cancels the cast; other cards never root;
   - the schedule is unchanged (plus5 and bar4 events identical to the baselines).
   - **Test:** `tests/integration/run/ngan_kiem_root_test.gd`, 13 checks in a real CombatView, mutation-checked.
3. **Reduce motion:** checked by unit tests only (no tremble, no trails, no shake, fewer fragments); no battle
   capture.
4. **Android real-device QA:** PENDING.
5. **Done (2026-11-08, user-approved cleanup):**
   - the chosen clip was renamed `cast_command_proto` → `cast_summon`;
   - the unused `cast_overhead` (v1) and `cast_summon_proto` clips were removed from the sheet, along with their
     source frames and candidate copies;
   - the Knight sheet is back to 15 clips (872×1394), and the other 92 frames are pixel-identical;
   - the rejected candidate art (`cast-overhead/`, `cast-overhead-v2/`, `cast-summon-proto/`) is kept on disk, out
     of any commit.

## 6. Verdict

**Gameplay: PASS. VFX: PASS. Animation: PASS. Cast Commitment: PASS** (the top-row HUD overlap was accepted by the
user). The movement rules are implemented as Cast Commitment (§7) and the clip cleanup is done (§5.5).
**APPROVED by the user 2026-11-08** as a completed technical prototype. Pending, non-blocking: Android device QA and a
human playtest.

## 7. Cast Commitment prototype (2026-11-08)

This replaces the root rule of §5.2:
- channel +0.28 s, hover 0.22 s, commit at the swing end with the pull-down, a 0.13 s lock;
- cancel policy "spent".

See `design/quick-specs/cast-commitment-ngan-kiem-2026-11-08.md` §10.

Evidence: `production/qa/evidence/skill-v2-ngan-kiem/cast-commitment/` (scenarios A–E, controls, videos, balance
probe).


## 8. Final QA (2026-11-08)

- **Full player flow** (`tests/integration/run/ngan_kiem_full_flow_test.gd`, 33/33 PASS): take a Block from the
  real bag → place → confirm → Tung phép → Ngàn Kiếm → Hủy during the channel.
  - The Block is gone from the bag; `cancel_placement` has nothing to return.
  - The full cooldown keeps running and the card is unavailable.
  - Nothing is scheduled and no damage lands.
  - Commit path: channel 1.48 s; first stab 0.22 s after the commit; the joystick is back at 1.61 s; damage dealt.
- **Mobile controls:**
  - The Hủy touch area is 178×114, on the right above the bag, and overlaps no bag slot.
  - A tap in the first 0.15 s is ignored.
  - The d-pad is locked during the channel and the commit lock, and the hero can step on the very next tick
    after a cancel.
  - The 6 labels are correct in Vietnamese and English.
- **Continuous gameplay, Vietnamese** (frames 05–08 in the evidence folder):
  - raise → swords form above the tiles → Hủy → ĐÃ HỦY, the swords scatter and the hero steps;
  - and the commit run: pull-down → stabs → final hit.
  - The event times are identical to scenarios B and C.
- **Regression:** 212/212 test files green; golden unchanged.
- **Playtest checklist:** `production/qa/ngan-kiem-cast-commitment-playtest-checklist.md`.
- **Pending, non-blocking tasks** (the user approved the prototype without them, 2026-11-08):
  - **Real Android device QA:** Hủy reach with the right thumb, readability of the cost line and ĐÃ HỦY / ĐÃ CHỐT,
    the joystick lock and restore on touch (`production/qa/android-device-qa-skill-v2.md`);
  - **Human playtest:** the bot almost never cancels, so whether the cancel is worth losing the Block and the
    cooldown is unproven; run `production/qa/ngan-kiem-cast-commitment-playtest-checklist.md`. If players tank
    hits instead of cancelling, consider cancel policy B (spec §5).
