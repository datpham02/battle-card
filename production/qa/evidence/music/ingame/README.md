# Music in game (2026-11-14)

Captured with `tools/audio/music_capture.gd` (Movie Maker, 30 fps, --audio-driver Dummy), one fresh run per region:
map 7 s -> first battle node, fight 9 s -> every enemy killed -> reward screen -> back to explore.

| Region | Map | Battle | After the win |
|---|---|---|---|
| ch1 (Rừng Sương) | explore | battle | victory stinger, then explore |
| hellfire | hellfire_explore | hellfire_battle | victory stinger, then hellfire_explore |
| sky_isles | sky_explore | sky_battle | victory stinger, then sky_explore |

Track names are the MusicPlayer log printed by the driver at each step. In music_hellfire.mp4 the victory stinger
was located in the recorded audio by cross-correlation with music_victory.ogg: peak 0.40 at 18.95 s (the battle part
of the same file peaks at 0.08). The enemies die at ~17 s; match_ended comes ~2 s later with the death animation,
then the reward screen (frames hellfire_t19.png / t22.png). The driver's "WON" line is printed 1 s after the kill,
before match_ended, so it still shows the battle track.
