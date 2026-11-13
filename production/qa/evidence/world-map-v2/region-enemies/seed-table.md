# Seed -> enemy table (dev launch), 2026-11-13

Generated headless by mirroring GameFlow's `--node` walk (first available node per column, no fights, cleared_bosses = floors walked),
seeds 1..60, fresh run. Launch: `godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -- --node=<node> --seed=<seed> --lang=vi --character=kiem_si --shot=<png>`.
A real dev boot reads the user's progress.json (cleared bosses -> onboarding tier cap), so confirm the enemy in the floor title line.

| Region | Id | Seed | --node | Kind |
|---|---|---|---|---|
| ch1 | `goblin_scout` | 1 | `f1/ch1/c0/n0` | battle |
| ch1 | `wolf` | — | not reachable in a fresh run (forest elite/boss t2 or pool orphan) | — |
| ch1 | `goblin_chief` | — | not reachable in a fresh run (forest elite/boss t2 or pool orphan) | — |
| ch1 | `goblin_warrior` | — | not reachable in a fresh run (forest elite/boss t2 or pool orphan) | — |
| ch1 | `dire_wolf` | 1 | `f1/ch1/c1/n0` | battle |
| ch1 | `goblin_shaman` | — | not reachable in a fresh run (forest elite/boss t2 or pool orphan) | — |
| ch1 | `wolf_alpha` | — | not reachable in a fresh run (forest elite/boss t2 or pool orphan) | — |
| ch1 | `goblin_archer` | 2 | `f1/ch1/c1/n2` | battle |
| ch1 | `goblin_brute` | — | not reachable in a fresh run (forest elite/boss t2 or pool orphan) | — |
| ch1 | `goblin_warlock` | 1 | `f1/ch1/c6/n0` | boss |
| ch1 | `forest_witch` | — | not reachable in a fresh run (forest elite/boss t2 or pool orphan) | — |
| ch1 | `rootling` | 1 | `f1/ch1/c1/n1` | battle |
| ch1 | `mossbound_sentry` | 2 | `f1/ch1/c0/n0` | battle |
| ch1 | `greycap_sporeling` | 1 | `f1/ch1/c1/n2` | battle |
| ch1 | `ancient_root_sentinel` | — | not reachable in a fresh run (forest elite/boss t2 or pool orphan) | — |
| ch1 | `mistbriar_matron` | — | not reachable in a fresh run (forest elite/boss t2 or pool orphan) | — |
| ch2 | `skeleton` | 1 | `f5/ch2/c4/n1` | battle |
| ch2 | `zombie` | 1 | `f5/ch2/c3/n0` | battle |
| ch2 | `bat_swarm` | 4 | `f5/ch2/c0/n0` | battle |
| ch2 | `slime` | 1 | `f5/ch2/c1/n1` | battle |
| ch2 | `cultist` | 1 | `f5/ch2/c1/n2` | danger |
| ch2 | `rat_king_guard` | 1 | `f5/ch2/c1/n0` | battle |
| ch2 | `ghost` | 4 | `f5/ch2/c3/n0` | danger |
| ch2 | `reacter` | 1 | `f5/ch2/c0/n0` | battle |
| ch2 | `jailer` | 2 | `f5/ch2/c3/n0` | miniboss |
| ch2 | `ogre_king` | 1 | `f5/ch2/c6/n0` | boss |
| ch3 | `frost_sprite` | 1 | `f6/ch3/c4/n1` | battle |
| ch3 | `wisp` | 2 | `f6/ch3/c4/n1` | battle |
| ch3 | `stone_sentry` | 1 | `f6/ch3/c0/n0` | battle |
| ch3 | `snow_wolf` | 1 | `f6/ch3/c2/n0` | battle |
| ch3 | `rime_archer` | 1 | `f6/ch3/c1/n0` | danger |
| ch3 | `ice_golem` | 1 | `f6/ch3/c3/n0` | danger |
| ch3 | `ghost_elite` | 1 | `f6/ch3/c1/n2` | danger |
| ch3 | `fuse_golem` | 1 | `f6/ch3/c1/n1` | battle |
| ch3 | `frost_mage` | 5 | `f6/ch3/c3/n0` | miniboss |
| ch3 | `mist_lord` | 1 | `f6/ch3/c6/n0` | boss |
| an_dai | `an_dai_keeper` | 1 | `f8/an_dai/c1/n0` | boss |
| swamp | `bog_rat` | 1 | `f4/swamp/c0/n0` | battle |
| swamp | `mire_slug` | 1 | `f4/swamp/c3/n0` | battle |
| swamp | `swamp_lizard` | 1 | `f4/swamp/c1/n1` | battle |
| swamp | `marsh_toad` | 1 | `f4/swamp/c2/n0` | danger |
| swamp | `reed_witch` | 1 | `f4/swamp/c1/n2` | danger |
| swamp | `bog_hound` | 1 | `f4/swamp/c1/n0` | battle |
| swamp | `spore_cap` | 7 | `f4/swamp/c3/n0` | miniboss |
| swamp | `leap_frog` | 3 | `f4/swamp/c3/n0` | miniboss |
| swamp | `toad_matriarch` | 1 | `f4/swamp/c6/n0` | boss |
| desert | `dune_jackal` | 1 | `f3/desert/c1/n0` | battle |
| desert | `sand_beetle` | 1 | `f3/desert/c0/n0` | battle |
| desert | `dust_nomad` | 1 | `f3/desert/c5/n0` | danger |
| desert | `mirage_sprite` | 1 | `f3/desert/c1/n1` | battle |
| desert | `scarab_guard` | 1 | `f3/desert/c1/n2` | danger |
| desert | `sun_archer` | 5 | `f3/desert/c2/n0` | danger |
| desert | `sand_burrower` | 6 | `f3/desert/c3/n1` | miniboss |
| desert | `scorpion` | 4 | `f3/desert/c3/n0` | miniboss |
| desert | `sand_sphinx` | 1 | `f3/desert/c6/n0` | boss |
| hellfire | `imp` | 1 | `f2/hellfire/c0/n0` | battle |
| hellfire | `ember_hound` | 1 | `f2/hellfire/c1/n0` | battle |
| hellfire | `ash_golem` | 1 | `f2/hellfire/c2/n0` | battle |
| hellfire | `flame_cultist` | 2 | `f2/hellfire/c1/n0` | battle |
| hellfire | `magma_slug` | 1 | `f2/hellfire/c1/n2` | danger |
| hellfire | `hell_knight` | 3 | `f2/hellfire/c1/n2` | battle |
| hellfire | `fire_eater` | 1 | `f2/hellfire/c5/n1` | miniboss |
| hellfire | `ash_phoenix` | 2 | `f2/hellfire/c2/n0` | miniboss |
| hellfire | `inferno_lord` | 1 | `f2/hellfire/c6/n0` | boss |
| sky_isles | `cloud_sprite` | 4 | `f7/sky_isles/c4/n0` | battle |
| sky_isles | `harpy` | 1 | `f7/sky_isles/c0/n0` | battle |
| sky_isles | `wind_monk` | 2 | `f7/sky_isles/c1/n2` | battle |
| sky_isles | `storm_eagle` | 1 | `f7/sky_isles/c1/n1` | battle |
| sky_isles | `sky_sentinel` | 1 | `f7/sky_isles/c1/n0` | danger |
| sky_isles | `thunder_shaman` | 1 | `f7/sky_isles/c1/n2` | battle |
| sky_isles | `gale_bird` | 20 | `f7/sky_isles/c3/n1` | miniboss |
| sky_isles | `cloud_veil` | 2 | `f7/sky_isles/c3/n0` | miniboss |
| sky_isles | `storm_dragon` | 1 | `f7/sky_isles/c6/n0` | boss |
