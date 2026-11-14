# Character system — F1 / F2 / F3 evidence

Design: `docs/design/character-system/CHARACTER-SYSTEM-REDESIGN.md` and `F3-PASSIVE-FEEDBACK.md`.

## Reading these screenshots

This checkout is shared by a dozen sessions, so **a capture shows whatever every session happened to
have in the tree at that second**, not only the work it was taken for. What is mine and what is not:

| In the frame | Whose |
|---|---|
| Accent-coloured **damage number** on a passive-boosted hit | **Mine** (F3, `quick_blade`) |
| Two-segment **violet link** from the bursting enemy cell to the "+N" | **Mine** (F3, `prayer`) |
| Brighter, coarser **charge steps** on a qualifying cast | **Mine** (F3, `wide_caster`) |
| The green **"+N"** itself | Pre-existing, Story 037 — not built by F3 |
| "Rạn ×N" in the boss status strip | Pre-existing, Story 023 |
| The top-left **HP plate / bar styling** in anything shot after 2026-11-14 10:28 | **Not mine** — the UI-style session's restyle (uncommitted, but **approved by the user** off a mockup, per that session). See `production/qa/evidence/ui-style-2026-11-14/README.md`, which carries its own capture time |

Verified by timestamp, not assumed: `combat_view.gd` was last written 10:28:48 and the `f3-prayer`
captures ran 10:30:13–10:30:41, so that session's stone plate is in them.

## Folders

- `f3-wide-caster/` — first cue attempt (accent tint + 1 px outline). **Failed the readability gate**:
  the only visible difference between the A/B legs is the cast's cell count. Kept deliberately as the
  record of a negative result.
- `f3-wide-caster/rhythm/` — second attempt, the one that works. 4 cells (cue on) against 3 cells
  (cue off), same card `hoa_xa`, same seed, frames 30/50/70/90. At frame 30 the qualifying charge is
  already bright while the ordinary one is still dim; from frame 50 both are full, so the mark lives
  in the first half of the windup.
- `f3-prayer/` — the heal link. Frame 30 shows the "+N" with the link **hidden behind the Benediction
  banner**; frame 80 shows it clearly. Worth knowing: a signature banner can swallow a board cue for
  about a second.

## Two gates, and why both

Every cue here is judged twice, because one gate cannot do the other's job:

- **Correctness** — `tests/unit/combat/passive_cue_test.gd` walks 1..9 cells and asserts the cue
  agrees with the rule it marks, thresholds read from `characters.json`. A screenshot cannot show
  this: a cue can be perfectly visible and mark the wrong casts.
- **Readability** — the A/B captures above. A test cannot show this: the first `wide_caster` attempt
  passed every test and was invisible.
