# Region ambience in game (2026-11-14)

Captured with `tools/audio/music_capture.gd` (Movie Maker, 30 fps, --audio-driver Dummy) after the ambience OGGs were
imported (the first `--import` segfaulted, exit 139; the retry imported all files). Same path as the music captures:
map 7 s -> first battle node -> every enemy killed -> back to explore.

| Region | Map | Battle | After |
|---|---|---|---|
| ch1 | music explore, ambience ch1 | music battle, ambience ch1 (bed -6 dB, no one-shots) | explore, ambience ch1 |
| hellfire | hellfire_explore, ambience hellfire | hellfire_battle, ambience hellfire | hellfire_explore, ambience hellfire |

Logged by the driver from MusicPlayer / AmbiencePlayer. On the map (first 6 s) the hellfire capture measures
-29.5 LUFS against -30.7 LUFS for the music-only capture of the same path (production/qa/evidence/music/ingame/), so the
bed is in the mix about 8 dB under the music. Tests: tests/unit/audio 13/13 FAILS=0, no SCRIPT ERROR.
