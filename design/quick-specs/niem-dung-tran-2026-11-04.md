# Quick Design Spec: Niệm là dừng trận

**Type**: Tweak
**System**: Cast flow (piece placement, card menu, Focus)
**GDD Reference**: `design/game-brief.md` (no GDD at `workflow: minimal`); replaces part of Story 012 (`production/epics/kaiten-duel/story-012-focus-pause.md`) and the place window of `design/quick-specs/menu-la-giua-man-hinh-2026-11-01.md`
**Date**: 2026-11-04

## Change Summary

Every cast stops the match: from picking a piece up until the card is chosen, nobody moves (hero, enemies,
projectiles, clocks) and the d-pad is locked. One 4 s clock covers adjusting the pieces and choosing the card; when it
runs out the pieces stay as they are and a random card of the hand that meets its conditions is cast.

## Motivation

User 2026-11-04: "trong quá trình cast thì ko có nhân vật hay quái nào được di chuyển"; "khi đặt các khối xuống sàn là
dừng cả trận lại với tg 4s để người ta chỉnh và chọn lá cast"; "hết 4s thì sẽ đặt khối với hiện trạng lúc đó và cast
random lá bài thỏa điều kiện"; while dragging a piece from the bag: "Cũng dừng hẳn".

Before: the place window (3 s) and the card menu (3 s) ran the match at 0.2x, so enemies and projectiles kept
creeping; only Focus (once per 8 s cooldown) stopped it, and only while picking. The d-pad was locked only while
dragging. The menu timeout always cast Kiếm Khí.

## Design Delta

Story 012 says Focus stops the match when points are selected, at most 4 s, then an 8 s cooldown during which
selecting does not stop it. Quick spec 2026-11-01: place window 3 s then card menu 3 s, the match slowed 0.2x, the
basic slash on menu timeout.

This spec changes that to:

1. **Stop**: while a piece is picked up (PLACING), in the place window and while the card menu is open, the
   simulation runs at `cards.json menu_time_scale` = **0** (stopped). Every cast; Focus has no cooldown
   (`focus_cooldown_sec` 0).
2. **No movement**: `CombatView.is_movement_locked()` is true for the whole cast (`is_casting()`).
3. **One clock**: `cuts.json place_window_sec` = **4 s** real time (x the "Thời gian chọn lá" setting; unlimited = no
   clock) starts when the first piece lands on the floor and covers joining pieces AND choosing the card. Tung phép
   pressed early opens the menu with what is left.
4. **Timeout**: in the place window the placed pieces stay, a piece still dragged goes back to the bag, the hand is
   drawn and a **random available card of the hand** (cell minimum, cooldown, not a curse) is cast at once. In the menu
   the same random pick. No available card: Kiếm Khí as before.
5. **Pick cap**: picking the first piece up stops the match too, so it is capped by the same length; when it runs out
   before the piece lands, the piece goes back to the bag and the match runs again.

## Tuning Knobs

| Knob | File | Old | New |
|---|---|---|---|
| `menu_time_scale` | cards.json | 0.2 | 0.0 |
| `focus.focus_cooldown_sec` | cards.json | 8.0 | 0.0 |
| `place_window_sec` | cuts.json | 3.0 | 4.0 |

`menu_choose_sec` (3 s) now only applies to a menu opened on its own (tests, tools).

## Acceptance Criteria

- [ ] From picking a piece up until the card is chosen, enemy cell, enemy stage clocks, projectiles and cooldowns do
      not advance, and `try_step_player` is refused.
- [ ] Tung phép at 1 s left of the 4 s gives the card menu 1 s.
- [ ] The clock running out in the place window casts a card of the drawn hand that is available, never a curse or a
      card under its cell minimum; with a seeded RNG the pick is deterministic.
- [ ] No regression: after the card is chosen the match runs at 1x and the hero can step (cast_gesture, then step
      clips, fix 37a725d).
- [ ] Screenshot: card menu open, match stopped, in `production/qa/evidence/cast-stop/`.

## GDD Update Required?

No GDD at `workflow: minimal`. `assets/data/schema.md` updated (place_window_sec, menu_time_scale, menu_choose_sec,
focus_cooldown_sec).
