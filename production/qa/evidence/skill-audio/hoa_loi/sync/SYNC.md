# Hỏa Lôi: animation-synchronised audio (2026-11-09)

Rule (user, all 60 skills): audio follows the real animation, VFX and authoritative events; silence is fine where the
picture is still; no drone just because a phase is waiting.

## Sources of the visual timeline
- Code: `src/art/fuse_fx.gd` (seal draw-in 0.25 s, 3 countdown steps at fuse/3, final flicker FINAL_SEC 0.35, collapse
  0.08 s, blast at `at` with no pre-roll), `src/battle/unit_layer.gd` + `assets/art/units/unit_phap_su_sheet.json`
  (Mage `cast_gesture`, not stretched: f0 0.000, coil f4 0.332-0.390, palm out f5 0.390, end 0.756), burning cells end
  on `cell_burned_out` with no fade.
- Video: `hoa_loi_{plus5,square}_sync.avi` (Movie Maker, 60 fps, `--boss-idle`), frames read in
  `../ingame/hoa_loi_plus5_events_sheet.png`. Each visible change lands 1 frame (17 ms) after the code time (drawn the
  frame after the tick that changes it).

## Cue changes (src/audio + audio_events.json; no gameplay, VFX or timing change)
- `seal` now at release + `timing.seal_lock_delay_sec` 0.25 (rings appear = armed), was at the release.
- Countdown pulses at the two ring drops (fuse/3, 2fuse/3) and the final flicker (`timing.final_warning_sec` 0.35
  before `at`); was 0, 1/3, 2/3 of the fuse (the first pulse sat on the release, the last on nothing visible).
- `charge` (fuse drone) and `prime` (rising hiss) silent for hoa_loi: the picture shows neither.
- From the previous pass: no generic commit whoosh, no hit layer / body thump on the blast, burn ticks = light sizzle,
  burning loop only while cells burn, embers-out on the burn-out tick.

## Measured in game (engine audio, placeholder sounds, new timing), plus5 / square
| Phase | Visual event | Code time (s) | Video frame (s) | Audio onset (s) | Diff vs frame |
|---|---|---|---|---|---|
| Cast | Mage gesture start (f0) | 0.000 | 0.000 | 0.061 / 0.061 | +61 ms (placeholder's soft start) |
| Armed | seal rings appear | 0.700 | 0.700 | 0.731 / 0.731 | +31 ms |
| Countdown | ring drop 1 | 0.950 / 1.050 | 0.967 / — | 0.977 / 1.072 | +10 ms (plus5) |
| Countdown | ring drop 2 | 1.450 / 1.650 | 1.467 / — | 1.478 / 1.681 | +11 ms (plus5) |
| Countdown | final flicker | 1.600 / 1.900 | 1.617 / — | 1.628 / 1.927 | +11 ms (plus5) |
| Impact | first flame frame | 1.950 / 2.250 | 1.950 / 2.250 | 1.949 / 2.248 | -1 / -2 ms |
| Aftermath | first burn tick | 2.450 / 2.750 | — | — / 2.755 | +5 ms |
| Aftermath | flames end | 3.950 / 4.250 | 3.950 / — | masked (soft cue) | — |
Scheduled cues land 1-2 frames after their tick in Movie Maker (no output-latency lead there); on a device the
director starts them `AudioServer.get_output_latency()` early (clamped 0-80 ms).

## Videos
- `hoa_loi_{plus5,square}_sync_ingame_audio.mp4`: what the game plays now (placeholder sounds, new timing).
- `hoa_loi_{plus5,square}_sync_mockup_audio.mp4`: the same frames with the free electrical mockups
  (`tools/audio/hoa_loi_mockups.py`: elec_cast, elec_lock, elec_pulse) mixed on the same cue timeline (rendered from the
  headless dump of the same cast; the blast lands within 1 frame of the in-game one). The blast is still the old
  placeholder until the thunderstrike takes are approved and generated.

## Integrated (user picks 2026-11-09): fire cast + one burst, silent fuse, thunderstrike take B
Game data: windup = fire build (sfx_skill_hoa_loi_windup_fb_01, gain -4), commit = `skill.hoa_loi.ignite` burst at
cast_scheduled (gain -4), seal / tick / charge / prime "", impact = ElevenLabs take B 2GhvmghqO026bpy8NPih as tiers
L 0.80 s, M 0.65 s -2 dB, S 0.50 s -4 dB (gain +2), burn loop -20. Built by tools/audio/sfx_import.py (manifest).
Measured in game (`../final/hoa_loi_{plus5,square}_final.avi`, engine audio):
| Phase | Visual event | Frame (s) | Audio onset (s) | Diff |
|---|---|---|---|---|
| Cast | gesture start | 0.000 | 0.065 | +65 ms (the build fades in by design) |
| Release | seals appear | 0.467 | 0.462 | -5 ms |
| Fuse | countdown rings | 0.70-1.88 | silence (max -180 dBFS) | - |
| Impact | first flame frame | 1.950 / 2.250 | 1.949 / 2.248 | -1 / -2 ms |
| Aftermath | first burn tick | 2.450 / 2.750 | 2.454 / 2.754 | +4 ms |
| Aftermath | flames end | 3.950 / 4.250 | 3.950 / 4.249 | 0 / -1 ms |
Engine peak -5.0 dBFS (plus5, tier L), -7.1 (square, tier M): the Skill bus compressor and master limiter sit lower than
the offline audition (-1.6); loudness balance across skills is a later mix pass.
