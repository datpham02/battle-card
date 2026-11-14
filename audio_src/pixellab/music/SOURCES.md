# PixelLab music, batch 1 (2026-11-13), raw takes, not in the game yet

Tool: PixelLab `create_music` (Tier 2 subscription, 10 generations per call, 40 total). Licence: commercial use allowed (see the Licence note at the end)
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

## Batch 3 (2026-11-13, user "Có, chạy đợt 3"): region explore themes, 70 gens
| File | song_id | Length | Loudness | Peak |
|---|---|---|---|---|
| dungeon_t1_33a1a90a.mp3 | 33a1a90a-c37c-47af-9471-45125388128a | 119 s | -15.3 LUFS | -1.9 dBFS |
| dungeon_t2_12d4fb51.mp3 | 12d4fb51-5117-49d6-8991-ea39ecd53af1 | 119 s | -14.2 LUFS | -0.7 dBFS |
| tower_t1_794f4d10.mp3 | 794f4d10-3ea1-446e-980b-cb40114ba1e7 | 119 s | -13.7 LUFS | -0.7 dBFS |
| tower_t2_ad69099c.mp3 | ad69099c-32bf-43bf-9394-d01333e06343 | 119 s | -15.1 LUFS | -2.2 dBFS |
| swamp_t1_5c9d8e47.mp3 | 5c9d8e47-265b-463a-96b8-1f8eed694895 | 119 s | -15.1 LUFS | -0.4 dBFS |
| swamp_t2_fa5c7470.mp3 | fa5c7470-d4e5-4ea5-8056-ec0a0fbeee1c | 119 s | -14.5 LUFS | -0.4 dBFS |
| desert_t1_2a2743dc.mp3 | 2a2743dc-4034-4691-b105-e7d6c5c9bd9a | 119 s | -14.1 LUFS | -0.5 dBFS |
| desert_t2_7dee2ce8.mp3 | 7dee2ce8-7269-44e2-bd96-408615c521f7 | 120 s | -14.9 LUFS | -0.5 dBFS |
| hellfire_t1_9acca246.mp3 | 9acca246-b91f-41c1-be6e-4429c65b4052 | 119 s | -14.4 LUFS | -0.6 dBFS |
| hellfire_t2_5a4338f0.mp3 | 5a4338f0-b2e1-49f7-af3d-48ff25598d32 | 119 s | -14.9 LUFS | -1.0 dBFS |
| sky_t1_a7c9d545.mp3 | a7c9d545-da29-4ff4-9104-7ab642af340d | 119 s | -14.3 LUFS | -1.2 dBFS |
| sky_t2_96128549.mp3 | 96128549-d361-45b1-9fda-ae727c7f8896 | 119 s | -14.3 LUFS | -0.8 dBFS |
| heart_t1_84fadde9.mp3 | 84fadde9-2d8c-4ea0-a8c2-1c836fafc631 | 119 s | -15.1 LUFS | -2.2 dBFS |
| heart_t2_1843c729.mp3 | 1843c729-96a3-48ed-9021-4df7f8a0de05 | 119 s | -14.6 LUFS | -1.2 dBFS |

Picks (user): take 1 for all seven regions (dungeon 33a1a90a, tower 794f4d10, swamp 5c9d8e47, desert 2a2743dc, hellfire 9acca246, sky a7c9d545, heart 84fadde9).

## Batch 4 (2026-11-14, user "Có, chạy đợt 4"): 6 battle restyles (take 1 used, except swamp take 2) + 13 loops, 112 gens
Two loop jobs failed ("No loop could be made", not charged): swamp battle take 1, desert explore first try; retried.
Battle restyle take ids: dungeon 83fc70e7, tower db66ce52, swamp aae0200c / e2ede014, desert ec5f2a50, hellfire a3333fee, sky e1cf6b52.

| Raw file | Loop song id | Loop |
|---|---|---|
| dungeon_explore_loop_322de371.mp3 | 322de371-8523-437c-814a-8774a1029273 | 54.915 -> 195.241 s |
| dungeon_battle_loop_d1d52d7f.mp3 | d1d52d7f-48a5-4eb9-8a40-87a4c711a2a6 | 48.089 -> 170.365 s |
| tower_explore_loop_4fdde865.mp3 | 4fdde865-6207-429b-822f-b3eb1ff89308 | 60.140 -> 175.437 s |
| tower_battle_loop_4049947f.mp3 | 4049947f-4042-47ff-aa77-3b72ffeaca3c | 58.932 -> 179.277 s |
| swamp_explore_loop_78c4684e.mp3 | 78c4684e-a075-4974-ae55-1ce7ebd0bad9 | 60.906 -> 164.835 s |
| swamp_battle_loop_ba1663ac.mp3 | ba1663ac-3d0c-4323-b0ca-b52541b3b1ae | 58.421 -> 170.543 s |
| desert_battle_loop_dbcc14fb.mp3 | dbcc14fb-a815-4eca-affc-f99b41d0974a | 50.805 -> 145.735 s |
| desert_explore_loop_cd3f8391.mp3 | cd3f8391-e975-4681-99ab-7303b06ccd23 | 58.003 -> 167.859 s |
| hellfire_explore_loop_7ef3729d.mp3 | 7ef3729d-cc57-4f07-86ff-5a959d391f29 | 59.884 -> 168.834 s |
| hellfire_battle_loop_8ad305c6.mp3 | 8ad305c6-303e-4dec-840f-f07f8d05ad20 | 60.372 -> 179.667 s |
| sky_explore_loop_ece898dc.mp3 | ece898dc-2034-4b21-bf90-ffd25cec95cd | 60.883 -> 187.487 s |
| sky_battle_loop_76dd460f.mp3 | 76dd460f-e817-4c0b-889a-b21f6493d3fc | 62.485 -> 180.469 s |
| heart_loop_8f39866f.mp3 | 8f39866f-6cb0-409a-84da-937231771131 | 56.262 -> 160.100 s |

Batch 3/4 raw takes stay local only (about 50 MB); every take can be fetched again from PixelLab by the song ids above.

## Licence
Commercial use allowed: PixelLab ToS 1.3 (user owns the outputs; commercial and non-commercial use without further permission; no attribution required); paid Tier 2 plan; checked 2026-11-14, user confirmed. Open points: the ToS text names images / outputs, not music or sound by name, and clause 4.1 points to the Open RAIL-M licence (not reviewed). Not allowed: training other models on the outputs.
