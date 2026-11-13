# PixelLab music, batch 1 (2026-11-13), raw takes, not in the game yet

Tool: PixelLab `create_music` (Tier 2 subscription, 10 generations per call, 40 total). Licence: UNCONFIRMED
(user has not stated the PixelLab plan terms). Prompts: see docs/design/audio/music-plan.md.

| File | song_id | Length | Loudness | Peak |
|---|---|---|---|---|
| explore_t1_e1c87520.mp3 | e1c87520-0e74-4f06-988a-a1dbae532eef | 119.6 s | -14.6 LUFS | -1.2 dBFS |
| explore_t2_50ad161d.mp3 | 50ad161d-5c38-454c-ad8f-032732b9ac9b | 119.6 s | -13.9 LUFS | -0.4 dBFS |
| boss_t1_bf26f41b.mp3 | bf26f41b-3699-4b23-bbc2-d8b6a90fccc4 | 88.8 s | -13.2 LUFS | -0.2 dBFS |
| boss_t2_756d9cae.mp3 | 756d9cae-ada6-48ba-8fac-b95b781f1a78 | 90.0 s | -14.2 LUFS | -0.4 dBFS |
| victory_t1_598b784e.mp3 | 598b784e-ff49-45cc-b77a-b55d7499f068 | 9.8 s | -14.6 LUFS | -3.4 dBFS |
| victory_t2_d099075c.mp3 | d099075c-07d1-4cad-a8d5-f2a2e53b48a4 | 8.8 s | -13.6 LUFS | -2.7 dBFS |
| defeat_t1_0df4dd7c.mp3 | 0df4dd7c-be26-434f-b2d1-3df8189fab81 | 9.9 s | -14.9 LUFS | -2.9 dBFS |
| defeat_t2_43cd0487.mp3 | 43cd0487-eeea-4726-b955-ff98a16336e1 | 8.8 s | -14.5 LUFS | -4.1 dBFS |

All takes are ~-14 LUFS; in game they will be brought down to about -24 LUFS so music sits under the SFX.

## Picks (user, 2026-11-13): take 1 for all four
explore e1c87520, boss bf26f41b, victory 598b784e, defeat 0df4dd7c.
Stingers: both play full until ~6.5 s and decay naturally to ~9 s (RMS per 0.5 s measured); a 5 s cut needs a
1.5 s fade (previews in production/qa/evidence/music/batch1/).

## Batch 2 (2026-11-13, user "Có, chạy đợt 2"): 18 of 22 gens spent so far (battle restyle 10 + 2 loops x4)
| File | song_id | Note |
|---|---|---|
| battle_t1_01346308.mp3 | 01346308-f427-49b0-a7a9-cf3889f6a74c | restyle of e1c87520, 119.2 s, -15.0 LUFS |
| battle_t2_52d820e3.mp3 | 52d820e3-6772-4a29-a128-16da3440efa1 | restyle of e1c87520, 119.9 s, -14.4 LUFS |
| explore_loop_t1_706952a8.mp3 | 706952a8-8061-4332-b8f5-60366b662b7a | 222.2 s, loop 56.355 -> 158.954 s |
| explore_loop_t2_53375376.mp3 | 53375376-5c75-4369-86ac-fc844ca1e114 | 222.2 s, loop 56.355 -> 158.954 s |
| boss_loop_t1_4341eb14.mp3 | 4341eb14-cdcf-4558-8d85-d3b3c7c8a0cd | 167.7 s, loop 43.282 -> 122.178 s |
| boss_loop_t2_4246ae38.mp3 | 4246ae38-42f3-4a45-b3c7-8966443c1bf5 | 167.7 s, loop 42.005 -> 120.864 s |
Seam previews (6 s before loop end + 6 s from loop start): production/qa/evidence/music/batch2/*_seam.mp3.
Battle loop (4 gens) waits for the user's battle take pick.
| battle_loop_t1_d0462fbb.mp3 | d0462fbb-05d2-40b4-86bc-692ea3256905 | 225.3 s, loop 52.570 -> 158.661 s |
| battle_loop_t2_c44ccef5.mp3 | c44ccef5-f6bf-4efe-b2f2-97c311c1f951 | 225.1 s, loop 53.104 -> 159.031 s |
Batch 2 complete: 22 gens. Picks (user): battle t1, explore loop t1, boss loop t1.

Git keeps only the raw takes the game files are built from (explore/battle/boss loop take 1, victory/defeat take 1);
the other takes stay local and can be fetched again from PixelLab by song id.
