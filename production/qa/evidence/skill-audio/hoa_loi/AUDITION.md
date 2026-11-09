# Hỏa Lôi: placeholder audition and audio plan (2026-11-09)

Status: listening aid, NOT production audio. Timelines from `tools/audio/skill_timeline_dump.gd` (real arbiter,
StatusEffects and bridge); renders by `tools/audio/skill_audition.py`. Each WAV starts 0.5 s before the cast.

## Files
`hoa_loi_{bar2,bar4,square,plus5}_1_placeholder.wav` (tiers S, M, M + square clause, L), `*_timeline.json`, `stems_*/`,
`hoa_loi_plus5_1_placeholder.png` (spectrogram), `old_placeholders/` (backups of every hoa_loi WAV before any change).

## Authoritative timeline (bar4 / plus5; square in brackets)
| Clock | Beat | Cue |
|---|---|---|
| 0.00 | cast starts (fixed 0.45 s, rooted) | `skill.hoa_loi.windup` |
| 0.45 | seals become authoritative | `skill.generic.commit` + `seal` + `charge` + tick 1 (four cues in one instant) |
| 0.97 [1.07] / 1.47 [1.67] | countdown | tick 2, tick 3 (+2 semitones, +1 dB per step) |
| 1.67 [1.97] | last 0.3 s | `prime` (rising hiss) |
| 1.95 [2.25] | detonation, all seals at once | `impact` tier S/M/L + hit layers |
| 1.95 → 3.93 [2.25 → 4.23] | cells burn 2.0 s | `status.burn.loop` (NEW), burn tick hits every 0.5 s (`combat.hit.enemy`) |
| 3.93 [4.23] | last cell burns out | `status.burn.out` (NEW, was a fixed +0.4 s after the blast) |

## Fixed in this pass
- The embers-out cue played 0.4 s after the detonation while the fire burns 2.0 s. Now the bridge counts burning cells
  (StatusEffects cell_ignited / cell_burned_out): loop on the first ignite, stop + embers-out on the last burn-out.
  Test: combat_audio_sync_test `test_hoa_loi_burn_loop_follows_the_burning_cells` (watched failing first).

## Measured observations
1. The seal instant stacks 4 cues; `skill.generic.commit` is a whoosh (melee swing family) on a trap-placing spell.
2. The fuse has no body: `charge` peaks at -24 dBFS in the mix (crest 28 dB), so between the ticks there is silence;
   no heat or pressure build-up is audible.
3. Ticks are 1 kHz pips (0.06 s): readable, but UI-like (risk of the "playful" feel rejected on Ngàn Kiếm).
4. The detonation is a synthetic low whump + noise (70 % of energy < 200 Hz): weak on phone speakers, no flame texture.
5. Burn damage ticks play `combat.hit.enemy` (body thump, -10 dBFS) every 0.5 s over a quiet burn loop (-23 dBFS):
   four identical thumps after the blast.

## Plan
ElevenLabs (real material): the detonation (core identity) and the burning-ground loop first; then the seal brand and
the fuse build-up. Synthesised (signature, cheap): ticks, prime, fizzle, embers-out.

## v2 (user direction 2026-11-09: cast stamp, restrained seal, 3 subtle pulses, ONE sudden blast, no thumps)
In the game data now: hoa_loi `commit` "" (no generic whoosh), `hit` "" and `body_hit` "" (no hit layer, no body
thump on the blast); every burn tick (any source) plays `status.burn.hurt` (light sizzle) instead of a body thump
(the bridge defers body hits by 1 ms and the damage source cancels them). Tests: audio_event_rules_test,
combat_audio_sync_test (no thump anywhere in a hoa_loi cast, 4 sizzles after the blast).

Free mockups (`tools/audio/hoa_loi_mockups.py` -> `audio_src/derived/hoa_loi_mockups/`, NOT in the game):
cast_stamp_A (stone stamp), cast_stamp_B (arcane brand), cast_stamp_C (dark lock), seal_armed (restrained hum),
pulse (dark countdown pulse). Auditions in `v2/` (timelines re-dumped with the new data):
- `hoa_loi_plus5_stamp{A,B,C}.wav`: stamp as the cast, seal_armed -4 dB, pulses, prime muted, placeholder blast.
- `hoa_loi_plus5_stampA_withPrime.wav`: same with the old rising prime kept, to compare.
- `hoa_loi_{bar2,square}_stampA.wav`: S tier and the 1.8 s square fuse.
Explosion request prepared, NOT run: node nFCQ0P8xJRigyIzpsGYw, 0.8 s, influence 0.6, 4 takes, estimate 32 credits.
