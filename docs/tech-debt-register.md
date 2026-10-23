## Technical Debt Register
Last updated: 2026-10-24
Total items: 3 | Estimated total effort: S+S+M

| ID | Category | Description | Files | Effort | Impact | Priority | Status | Added | Sprint |
|----|----------|-------------|-------|--------|--------|----------|--------|-------|--------|
| TD-001 | Test | Story 020 Phase D target (build beats always-skip by >= 25 pp) not met: kiem_si +20.0, sat_thu +21.4, phap_su +4.3. The bot only casts 1-2 cells to survive dodging bosses, so about two thirds of the pool is never used. JSON deliberately not tuned to fit a wrong bot. Re-measure with a bot that can use 3-5 cell cards, or at the playtest gate — from production/epics/kaiten-duel/story-020-deck-power.md | production/qa/evidence/deck-power/simulation-70seeds.md, assets/data/cards.json | M | Med | — | Open | 2026-10-24 | Backlog |
| TD-002 | Code Quality | Mage starter deck (3x hoa_tran needing 5 cells, 80 HP) is the weakest character under every policy and often draws three locked cards; tune starter deck or wide_caster after playtest — from production/epics/kaiten-duel/story-020-deck-power.md | assets/data/characters.json | S | Med | — | Open | 2026-10-24 | Backlog |
| TD-003 | Code Quality | bang_phong (pin, 7 cells) sits in every starter deck and is nearly uncastable; consider lowering min_cells or swapping it for a 3-4 cell pin — from production/epics/kaiten-duel/story-020-deck-power.md | assets/data/cards.json, assets/data/characters.json | S | Low | — | Open | 2026-10-24 | Backlog |
