# World Map v2 — Tactical Action Roguelike redesign of Tessera's run

Date: 2026-11-11 (second pass) · HEAD audited: `de6f88a` · Status: **design complete, awaiting the user's approval**.
No gameplay source, game data, test or save format was modified for these documents. Nothing in them is approved
until the user says so; every number is a starting value gated by the validation plan.

**Start here:** `08-approval-package.md` (the review summary with the decision table), then the documents it cites.

## What this is

Tessera's run today is 7 fixed regions, each a 7-column map whose paths differ only by which enemy id was rolled,
with no preview, no route identity and region mechanics that live inside single fights. This design keeps the
combat (pick up blocks → place a polyomino on the enemy's floor → cast), the roster, the climb order and every
reward table, and replaces the *map* with authored **routes**: three lanes per region with declared archetypes
(Safe, Treasure, Peril, Elite, Mystery — 3 of 5 per map), a hub, an approach (prepare / gamble), the warden. Every
node shows what it is, what it costs and what it pays before the player commits. Each region gets one **rule**
expressed through keys the combat already understands. The vertical slice is **Hellfire (floor 2) with the Heat
gauge**, run inside an otherwise unchanged game through one graph API that wraps the old maps.

## Documents

| File | Content | Read when |
|---|---|---|
| `08-approval-package.md` | experience A–Z, architecture, plan, validation, **decision table D1–D15**, verified facts vs proposals vs unverified assumptions, readiness | reviewing |
| `00-current-state-audit.md` | what the code does today, verified; reusable vs limiting; gaps; roster appendix; the column/index assumptions | judging any proposal |
| `01-game-design-spec.md` | run structure, graph and routes, archetypes, pack constraint mapping, forge, information design, rewards by tier, build progression, UX, acceptance criteria | the design |
| `02-region-design.md` | the Region Rule system; Heat in detail; six proposals | region identity |
| `03-encounter-system.md` | encounter profile = roster match + arena + modifiers + objective + tier; why not multi-enemy; modifier catalogue; forge flow | encounters |
| `04-technical-architecture.md` | data model, new modules, interfaces, seeds, save v8, fallbacks, migration (two generators, per-region switch), file lists | before coding |
| `05-implementation-plan.md` | the concrete Hellfire graph (every node and edge), 10 steps by concern, dependencies, played checks, risks | planning |
| `06-validation-plan.md` | baseline (what the sim really does), BLOCK vs INFO metrics with denominators, net value, oracle policy, paired comparisons, 31 unit + 3 integration tests, edge cases | definition of done |
| `07-consistency-review.md` | 20 discrepancies across the sources, what the code does, resolution, which need the user | checking nothing was resolved silently |

## Key decisions made in the documents (and why)

1. **Authored lanes, not random links** — few long fights per region means every node must carry a readable
   meaning (01 §B2).
2. **No multi-enemy fights** — the combat core is 1v1 by construction; depth comes from composition (03 §1).
   **Superseded 2026-11-13:** multi-enemy encounters are the Phase 3 direction (`MULTI-ENEMY-ENCOUNTER-AUDIT.md`,
   03 §1 change note); single-enemy encounters stay compatible. Phase 0 (data schema) is implemented.
3. **One Region Rule system, seven configs; six need no new combat code** (02 §9).
4. **Rewards gain a tier; tier 1 equals today** — nothing is retuned before the simulation (01 §E).
5. **Keep the fixed 7-region climb** (user 2026-11-07, this brief) over ADR-0001 D3's "5 tiers × 2 lands" (user
   2026-11-01); everything D3 asked for *inside* a land is kept (01 §A1b, §B7, §B8) — the user confirms this as D2.
6. **Two generators behind one graph API, flipped per region** — the slice ships without touching six regions (04 §9).
7. **Save v8; v5–v7 saves restart** instead of a converter (04 §6; ADR-0001's rollout note already says so).
8. **Baseline before any v2 number** — the shipped simulator picks regions at random, so step 0 adds one tool flag
   and records the real 7-floor climb (06 §1).

## Decisions that require the user's approval

See `08-approval-package.md` §E: **D1–D15** with options, recommendation and consequences, plus the region questions
D-R1..D-R4. The most consequential are D2 (world structure vs ADR-0001 D3), D1 (layout), D4 (slice), D5 (saves), D11
and D13 (forge node and the prepare slot).

Source documents behind these: `design/game-brief.md` "Run v6", ADR-0001 D3 / Phase 3 notes, and the design pack
chapter `02_ROGUELIKE_MAP_AND_ECONOMY.md` (`TESSERA_ALL_IN_ONE_FOR_CLAUDE.md`, in the user's Downloads, outside the
repo). The pack's node types, constraints 1–7, rhythm, weights and task E were checked against the spec (01 §B7). Its
Elite "+ optional helper normal" and Primal Shard progression are not adopted (07 C16).

## Implementation status (2026-11-12)

**The Hellfire vertical slice is implemented** (D1–D15 approved by the user; Phases 0–9 of the autonomous brief).
The authoritative record is `production/qa/evidence/world-map-v2/final-implementation-report.md` (results, exact
commands, evidence paths, known limitations, recommendation) with the per-phase checkpoint
`autonomous-progress.md` next to it. What the code does where it differs from these documents is listed at the top
of `04-technical-architecture.md` ("As implemented"). The other six regions keep their v1 maps and no new mechanic
(D8): their rules exist only as `_proposed_rule` text in `assets/data/region_rules.json`.
