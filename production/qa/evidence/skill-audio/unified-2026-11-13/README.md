# Unified sound set: rebuild and whole-game audio test (2026-11-13)

User: "xóa các sound cũ đi, làm lại hết sound" + "test toàn bộ âm thanh trong game: tất cả skill, chuyển động, tap
touch, âm thanh nền". Direction: docs/design/audio/unified-audio-identity.md (approved 2026-11-13).

## What changed
- All 160 old SFX files (80 WAV + imports, incl. the 11 ElevenLabs takes) deleted; 85 new files synthesised by
  `tools/audio/sfx_synth.py` from one palette (tick, knock, thump, ting, puff, short crackle) on one C-major
  pentatonic scale. Every file <= 0.4 s (stingers <= 0.7 s), median 0.12 s, no loop, no riser, no reverb. Free, no
  AI generation. Raw ElevenLabs takes stay in audio_src/ (git) if ever wanted back.
- Events: 69 (was 67): +4 approved (move.step, pickup.point, status.apply, status.expire), -2 approved
  (block.confirm, block.slot_full). The three reference cards keep their own events (doc §8 item 1).
- No drone: Ngàn Kiếm summon and the burning-ground cue are now one-shots (loop false).
- No extra hit layer: archetype `hit` = "" (impact material + body thump only); song_dao went from 15 to under 12
  sounds per second.
- Wired (src/audio, listen-only): hero step, unit death, crit, boss recovery window, terrain vent warning,
  pin / mark / poison / thorn-zone status apply + expire (one pitch step per kind), enemy taking a field point,
  impact material for INSTANT cards (about 30 cards had only a wind-up before), and hits on enemy units 1+ in
  multi-enemy fights (were silent).
- Not wired (no gameplay signal exists): combat.lock, block.invalid (doc §8.1 keeps them).
- Background audio: none in the game. Regional ambience is deferred by the approved doc (§8 item 4); music (A8)
  deferred since the foundation.

## Evidence
- `sheet_1_ui.wav` ... `sheet_5_three_cards.wav` + `SHEETS.md`: every file of every event, at its event gain.
- `all_skills/all_skills_sheet.wav` + `ALL_SKILLS.md`: all 62 cards, real cast timelines, max peak -1.1 dBFS.
- In game (Movie Maker, engine audio): `tram_dia_bar4.mp4`, `ngan_kiem_t4.mp4`, `hoa_loi_plus5.mp4`,
  `battle_kiem_si_bot.mp4` (tools/qa/play_bot.gd: real touch-API play, 15 steps, 10 casts, lifts, menu, win in 29 s),
  `ui_map_taps.mp4` (tests/integration/ui/map_flow_test.gd taps, FAILS=0).

## Tests
- `tests/unit/audio/all_skills_audio_test.gd` (new): every card casts, sounds, resolves known files, no spam.
- `tests/unit/audio/unified_cues_test.gd` (new): step, death, recovery, vent, statuses, instant impact + crit,
  enemy pick-up, multi-enemy unit 2 hit (watched failing without the fix).
- `audio_bank_test`: no looping event, every file short. Others updated for the no-hit-layer / no-drone rules.
