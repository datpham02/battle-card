# Ngàn Kiếm: full-timeline audio audition (2026-11-09)

Status: **listening aid, NOT production audio.** All sounds are the procedural placeholders except the two ElevenLabs
charge takes (raw, unapproved, licence unconfirmed). No file under `assets/` was changed.

## How it was made
1. `tools/audio/skill_timeline_dump.gd` runs ONE real cast headless through the same path as
   `tests/unit/audio/combat_audio_sync_test.gd` (cards.json, CastContext from a real piece, SwingArbiter clock, CutActor
   with the game's channel_extend / cast_time hooks, swing length from the game: `duration_override = -1`), with the
   CombatAudioBridge and a silent AudioDirector (lead 0 so each body lands on its event time). Output: every cue the
   director fired, with the arbiter clock. No timing was invented or edited.
2. `tools/audio/skill_audition.py` renders that cue list with the director's mix rules (event gain, step gain/pitch,
   tier gain, loops held until the bridge stops them). Random pitch/gain jitter is left out; variants are taken in order.
   `--override skill.ngan_kiem.charge=<take> --match-rms` swaps the charge for an ElevenLabs take at the placeholder's RMS.

## Files (each WAV starts 0.5 s before the cast; t below = time in the file)
| Cast | Placeholder only | Take A as charge | Take B as charge |
|---|---|---|---|
| T4 (branched, 4 swords, centre last ×1.5) | `ngan_kiem_t4_1_placeholder.wav` | `ngan_kiem_t4_2_takeA.wav` | `ngan_kiem_t4_3_takeB.wav` |
| Plus 5 (5 swords, centre last ×1.5) | `ngan_kiem_plus5_1_placeholder.wav` | `ngan_kiem_plus5_2_takeA.wav` | `ngan_kiem_plus5_3_takeB.wav` |

Also: `*_timeline.json` (raw cue dump), `*.json` beside each WAV (layer table, peak, RMS), `stems_t4/`, `stems_plus5/`
(one WAV per event, same time base), `ngan_kiem_t4_*.png` (spectrograms, 0-16 kHz).

## Authoritative timeline (T4; Plus 5 in brackets)
| t in file | Gameplay beat (source) | Audio event | Visual (sky_drop_fx.gd, index.json) |
|---|---|---|---|
| 0.50 | swing_started: Knight raises the sword | `charge` (0.42 s) + `channel_loop` starts | nothing yet |
| 0.67 → 1.30 [1.36] | — | (only the quiet loop) | sword i starts assembling over its tile at 0.166 + i × 0.06 s, 0.45 s each |
| 1.98 [2.23] | cast_scheduled = swing end (1.48 [1.73] s): COMMIT, pull-down | loop stops; `commit` | lock-on flash + cock-up |
| 2.20, 2.32, 2.44 [2.45 … 2.81] | drops, 0.12 s apart (sky_hover 0.22 s after commit) | `impact` ×3 [×4] (+ hit layers on the drop that hits) | swords stab their tiles |
| 2.56 [2.93] | `drop_final` ×1.5, centre | `impact_final` | centre sword |

## What the analysis shows (measured, before your ears)
1. **The commit is a slash.** Its spectrogram is a broadband noise burst with a tone sweeping DOWN from ~4.5 to ~2 kHz:
   the textbook "shing / whoosh". It is also the loudest early event (peak −6 dBFS). This is the most likely reason the
   whole cast reads as one sword stroke.
2. **The impacts are thin clicks, not stabs.** Each drop is a 0.145 s click + a tiny downward chirp (2.3 → 1.8 kHz),
   almost no energy under 200 Hz, all three variants nearly identical: four quick ticks in 0.36 s that sound like
   the tail of the commit's swing, not blades going into stone.
3. **The summon has no presence.** The charge is one 0.42 s sparkle at t = 0, mostly above 5 kHz, peak −13 dBFS; it
   ends before most swords are visible (they form 0.17 → 0.80 s, one by one). Then ~1 s of a quiet three-sine hum
   (peak −20 dBFS) that reads as an organ chord, not hovering steel.
4. **Placeholder defects:** the channel loop clicks at its seam (vertical line at t ≈ 1.5 s in every spectrogram);
   the final impact is a bell ring with no low body.
5. **ElevenLabs takes A and B:** both are a dense broadband wash (A ≈ 0.7 s, B ≈ 0.4 s of energy up to 16 kHz) with
   few separable transients: a "metal shower", not discrete swords appearing at separate tiles. Both end abruptly at
   1.2 s (click at t ≈ 1.7 s in the file): any use needs a fade-out.

## Which layers need ElevenLabs (recommendation)
| Layer | Verdict | Why |
|---|---|---|
| `impact` (steel blade into stone) | **YES, first priority** | the identity of the skill; real material (steel + stone crunch) is what synthesis does worst. 4 takes → variants. |
| `impact_final` | build from an `impact` take + synthesised low body and ring; EL only if that fails | saves credits, keeps the family |
| `commit` (divine command) | **synthesise, no EL first** | must NOT be a whoosh; a tonal motif (a struck resonant chord / bell-gong accent, no noise sweep) is the signature layer and should be ours |
| `channel_loop` | EL with `loop: true`, second priority | hovering singing steel is hard to synthesise convincingly; the loop flag gives a seamless loop |
| `charge` | **change the approach before the prompt** | one sound for all swords cannot match swords forming one by one; a short single-sword materialise sound, played once per tile at the visual stagger, matches the choreography (needs a small bridge change in `src/audio`, listening only) |
| `cancel` | later | not in this audition |

The revised charge prompt is held until you have listened to the audition.
