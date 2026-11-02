# Quick Design Spec: 7-column floors with OSFE branch links

**Type**: Tweak (run structure)
**System**: Run map (ChapterMapGen, RunSession, ChapterMapView)
**GDD Reference**: `design/game-brief.md` "Run"; `design/reference/osfe-reference.md` section 9.3
**Date**: 2026-11-03

## Change Summary

A floor's region map grows from 3 columns (battle, 2-3 choices, warden) to 7 columns like one OSFE world, and its
nodes are joined by branch links: a player may only move to a node linked from the node they just cleared.

## Motivation

User 2026-11-02/03: a map "obviously" has more steps than the 3-column floor. OSFE 1.6.2, read from its code
(`RunCtrl.GenerateRandomWorldList`, `WorldBar.GenerateWorldBar`, `S.zonesPerWorld = 7`, decompiled with ilspycmd 8.2,
read only): a run walks every `Pool` world except the hero's own (7-8 of the 8) then an ending world; each world is
7 zones (1 battle, 5 columns of 2-3 zones with columns 1 and 4 always 3, the boss) plus a next-world column. A run is
about 50-56 zones. Tessera keeps 5 floors (35 nodes + the final match): its fights are longer (pick, rotate, place
blocks), and the floor count is a tuning knob to revisit after playtests.

## Design Delta

Current data (`chapters.json` `world.region_columns`): column 0 battle; column 1 2-3 of battle / danger / miniboss
(floor >= 2) with a rest or treasure; column 2 the warden. Any node of a column can be chosen after any node of the
column before.

New rules:

1. `world.region_columns` has 7 columns:
   - 0: 1 battle.
   - 1: 3 nodes, battle / danger.
   - 2: 2-3 nodes, battle / danger, one of them treasure or battle.
   - 3: 2-3 nodes, battle / danger, plus an elite (miniboss) from floor 2 (OSFE's column 3 miniboss).
   - 4: 3 nodes: a rest, a treasure or battle, one battle / danger (OSFE's column 4 campsite).
   - 5: 2-3 nodes, battle / danger; the shop / event pass (`world.special_nodes.column`) works here.
   - 6: the warden.
   `floor_tiers` keep their [first, middle, warden] meaning; every middle column uses the middle tier.
2. Links (OSFE `GenerateWorldBar` order), per pair of columns A -> B: A's first node links B's first, A's last links
   B's last; when B has more nodes, each B node without a link in gets one from a random A node; when the counts are
   equal, A's unlinked nodes pair with B's unlinked nodes from the bottom; when B has fewer, each A node without a
   link out goes to a random B node. From column 3 to 4 the middle node of column 4 also gets a link (from A's first
   node, else its last). Every node has a way in and a way out. The links use their own seeded stream, so the nodes
   drawn are the same as without them.
3. A node stores its links as `next` (indices into the next column). `RunSession.available_nodes` lists only the
   nodes linked from the node cleared in the previous column; column 0, a map without `next` (saves from before this
   change) or a missing cleared node keep every node available.
4. The map screen draws only real links: the path taken, the fan from the hero's node to its linked nodes, and each
   node's links ahead. Nodes of the current column that are not linked are dimmed and cannot be chosen.

## Affected Systems

| System | Impact | Action |
|---|---|---|
| `assets/data/chapters.json` | region frame 3 -> 7 columns, special column 1 -> 5 | data |
| ChapterMapGen | link pass, `next` on nodes | code + tests |
| RunSession | availability by links, save keeps `next` | code + tests |
| ChapterMapView | lines from links, unlinked nodes dim | code + capture |
| Rewards / balance | a run is ~2.3x longer (gold, cards, removals, luck per node) | playtest, tune after |

## Acceptance Criteria

- [ ] Every generated floor has 7 columns; columns 1 and 4 hold 3 nodes, column 6 the warden; column 4 holds a rest.
- [ ] Every node of columns 0-5 has at least one link out, every node of columns 1-6 at least one link in.
- [ ] After clearing a node, only its linked nodes can be chosen (tap and `choose_node`).
- [ ] A save from before the change (no `next`) still loads and lets every node of the column be chosen.
- [ ] The map screen draws only the links; a 3-node column with one unlinked node shows it dimmed.
- [ ] No regression: the full suite passes.

## GDD Update Required?

No GDD at `workflow: minimal`; `design/game-brief.md` "Run" gets one line on the 7-column floors when committed.
