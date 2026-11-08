# Ngàn Kiếm — Cast Commitment: human playtest checklist

**Build:** working tree after the final QA (2026-11-08), not committed.
**Spec:** `design/quick-specs/cast-commitment-ngan-kiem-2026-11-08.md` (prototype as built, §10).
**Why a human test:** the balance bot almost never cancels (probe: `production/qa/evidence/skill-v2-ngan-kiem/cast-commitment/balance-probe-ch1-12seeds.txt`), so the
tactical value and the cost of the cancel can only be judged by people.

## Setup

- 3–5 players; at least 2 who have **not** played Ngàn Kiếm before. Real Android phone, landscape, thumbs only.
- Kiếm sĩ with Ngàn Kiếm in the deck; chapter 1 boss and one chapter 2 boss (different attack rhythms).
- Do **not** explain the cancel. Let each player find the Hủy button first; explain it after match 1 only if nobody found it.
- Per player: 3 matches. Note the times by hand or record the screen.

## Timing reference (what the player should feel)

| Shape | Channel (rooted, Hủy allowed after 0.15 s) | Commit lock (no Hủy, no step) | First stab after the choice |
|---|---|---|---|
| 4 cells (bar4, t4) | 1.48 s | 0.13 s | 1.70 s |
| plus5 (5 cells) | 1.73 s | 0.13 s | 1.95 s |

## 1. Is a channel of 1.48–1.73 s fair?

- [ ] Count how often a boss attack lands **during** the channel without the player reacting (hit while rooted).
- [ ] Ask: "When you raised the sword, did you feel you had time to decide, or were you stuck?" (1 = stuck, 5 = in control)
- [ ] Ask: "Did the 5-cell cast feel worse than the 4-cell cast?" (if yes, it points to the per-cell 0.25 s)
- [ ] Watch for players who stop using Ngàn Kiếm after match 1 (a sign the root feels unfair).
- **Pass if:** median score ≥ 3, and hits-while-rooted are mostly attacks that were telegraphed before the cast.

## 2. Is cancelling understandable?

- [ ] Does the player find the red **Hủy** (right side, above the Block bag) without help? At which match?
- [ ] After the first cancel, ask: "What did you lose?" Expected answer: the Blocks and the card's cooldown.
      Check it against the line above the button ("mất khối · thẻ vẫn hồi chiêu") and the **ĐÃ HỦY** text.
- [ ] Ask: "When could you no longer cancel?" Expected: once the sword is pulled down (**ĐÃ CHỐT**).
- [ ] Accidental cancels: count presses on Hủy the player did not mean (ask right after any cancel).
- [ ] Left thumb on the joystick during the channel: does the player try to walk and get confused that nothing moves?
- **Pass if:** ≥ 2/3 of players state the cost correctly unaided, and accidental cancels are 0–1 over all matches.

## 3. Can players see the boss recovery windows?

- [ ] Ask before the match: "When is it safe to cast?" Then watch whether casts start right after a boss attack ends.
- [ ] Count casts started during a boss recovery vs during a boss telegraph.
- [ ] Ask: "Did you wait for the boss before casting?" and "What told you it was safe?"
- **Pass if:** by match 3, most casts start in a recovery window, and players can name a visual cue for it.
  If not, the issue is the boss telegraph/recovery readability, not Ngàn Kiếm's timing.

## 4. Is losing the Block and the cooldown too punishing?

- [ ] After each cancel ask: "Was cancelling worth it?" (yes / no / didn't matter)
- [ ] Count: cancels that saved HP (dodged an attack) vs cancels that wasted a good cast.
- [ ] Watch for players who never cancel even when an attack is clearly coming (they take the hit to keep the cast).
- [ ] Ask: "Would you rather keep the Blocks and lose only the cooldown?" (the policy B alternative from the spec)
- **Pass if:** most players use the cancel at least once by match 3 and call it "worth it" more often than not.
  If players always tank the hit instead, the cost is too high; consider policy B (spec §5).

## 5. Phone checks (with the same players)

- [ ] Hủy is reachable with the right thumb without covering the bag; the left thumb never hits it.
- [ ] The cost line and ĐÃ HỦY / ĐÃ CHỐT are readable at arm's length, in Vietnamese and English.
- [ ] After a cancel, the very first joystick drag moves the hero (no dead input).
- [ ] After the commit, the hero can walk while the swords fall (after 0.13 s).

## Record

| Player | New? | Match | Casts | Cancels (meant / accidental) | Hits while rooted | Q1 score | Cost stated right? | Worth it? | Notes |
|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | |
