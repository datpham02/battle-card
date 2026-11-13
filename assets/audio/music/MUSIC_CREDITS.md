# Music credits

| File | Source | Song id (raw take in audio_src/pixellab/music/) | Processing | Licence |
|---|---|---|---|---|
| `music_forest_explore.ogg` | PixelLab `make_music_loop` of create_music e1c87520 | 706952a8-8061-4332-b8f5-60366b662b7a | cut at loop end 158.954 s, -8.4 dB (-23 LUFS), Vorbis q2; loops from 56.355 s | UNCONFIRMED (PixelLab plan terms not recorded yet) |
| `music_forest_battle.ogg` | PixelLab `make_music_loop` of restyle 01346308 (same melody as explore) | d0462fbb-05d2-40b4-86bc-692ea3256905 | cut at 158.661 s, -7.7 dB (-23 LUFS); loops from 52.570 s | UNCONFIRMED |
| `music_boss.ogg` | PixelLab `make_music_loop` of create_music bf26f41b | 4341eb14-cdcf-4558-8d85-d3b3c7c8a0cd | cut at 122.178 s, -8.2 dB (-22 LUFS); loops from 43.282 s | UNCONFIRMED |
| `music_victory.ogg` | PixelLab create_music | 598b784e-ff49-45cc-b77a-b55d7499f068 | full 9.8 s, -6.4 dB (-21 LUFS), no loop | UNCONFIRMED |
| `music_defeat.ogg` | PixelLab create_music | 0df4dd7c-be26-434f-b2d1-3df8189fab81 | full 9.9 s, -6.1 dB (-21 LUFS), no loop | UNCONFIRMED |

Prompts and plan: docs/design/audio/music-plan.md. Played by src/audio/music_player.gd from the `music` section of
assets/data/audio_events.json.

## Region music (batch 4, 2026-11-14)

| File | Loop of | Loop song id | Loop | Licence |
|---|---|---|---|---|
| `music_dungeon_explore.ogg` | 33a1a90a | 322de371-8523-437c-814a-8774a1029273 | 54.915 -> 195.241 s, cut at loop end, -23 LUFS | UNCONFIRMED |
| `music_dungeon_battle.ogg` | 83fc70e7 (restyle of 33a1a90a) | d1d52d7f-48a5-4eb9-8a40-87a4c711a2a6 | 48.089 -> 170.365 s, cut at loop end, -23 LUFS | UNCONFIRMED |
| `music_tower_explore.ogg` | 794f4d10 | 4fdde865-6207-429b-822f-b3eb1ff89308 | 60.140 -> 175.437 s, cut at loop end, -23 LUFS | UNCONFIRMED |
| `music_tower_battle.ogg` | db66ce52 (restyle of 794f4d10) | 4049947f-4042-47ff-aa77-3b72ffeaca3c | 58.932 -> 179.277 s, cut at loop end, -23 LUFS | UNCONFIRMED |
| `music_swamp_explore.ogg` | 5c9d8e47 | 78c4684e-a075-4974-ae55-1ce7ebd0bad9 | 60.906 -> 164.835 s, cut at loop end, -23 LUFS | UNCONFIRMED |
| `music_swamp_battle.ogg` | e2ede014 take 2 (restyle of 5c9d8e47; the take-1 loop failed) | ba1663ac-3d0c-4323-b0ca-b52541b3b1ae | 58.421 -> 170.543 s, cut at loop end, -23 LUFS | UNCONFIRMED |
| `music_desert_battle.ogg` | ec5f2a50 (restyle of 2a2743dc) | dbcc14fb-a815-4eca-affc-f99b41d0974a | 50.805 -> 145.735 s, cut at loop end, -23 LUFS | UNCONFIRMED |
| `music_desert_explore.ogg` | 2a2743dc | cd3f8391-e975-4681-99ab-7303b06ccd23 | 58.003 -> 167.859 s, cut at loop end, -23 LUFS | UNCONFIRMED |
| `music_hellfire_explore.ogg` | 9acca246 | 7ef3729d-cc57-4f07-86ff-5a959d391f29 | 59.884 -> 168.834 s, cut at loop end, -23 LUFS | UNCONFIRMED |
| `music_hellfire_battle.ogg` | a3333fee (restyle of 9acca246) | 8ad305c6-303e-4dec-840f-f07f8d05ad20 | 60.372 -> 179.667 s, cut at loop end, -23 LUFS | UNCONFIRMED |
| `music_sky_explore.ogg` | a7c9d545 | ece898dc-2034-4b21-bf90-ffd25cec95cd | 60.883 -> 187.487 s, cut at loop end, -23 LUFS | UNCONFIRMED |
| `music_sky_battle.ogg` | e1cf6b52 (restyle of a7c9d545) | 76dd460f-e817-4c0b-889a-b21f6493d3fc | 62.485 -> 180.469 s, cut at loop end, -23 LUFS | UNCONFIRMED |
| `music_heart.ogg` | 84fadde9 (restyle of Rừng Sương e1c87520) | 8f39866f-6cb0-409a-84da-937231771131 | 56.262 -> 160.100 s, cut at loop end, -23 LUFS | UNCONFIRMED |

All tracks re-encoded 2026-11-14 from the raw takes as Vorbis q2 (~96 kbps) for size: 45 MB -> 27 MB.
