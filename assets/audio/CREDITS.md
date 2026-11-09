# Audio credits

Files marked `sfx_synth.py (procedural)` are ORIGINAL, synthesised by `tools/audio/sfx_synth.py` (Python
standard library: oscillators, filtered noise, envelopes; no samples, recordings, paid tools or generator
services). Author: the Tessera project. Licence: CC0-equivalent (public-domain dedication; no attribution
required). Regenerate with `python -X utf8 -I tools/audio/sfx_synth.py`.

Files with another source are built by `tools/audio/sfx_import.py` from the raw material listed in
`tools/audio/external_sfx.json` (raw takes in `audio_src/`, not exported); their licence is the one in that row.
Format of every file: 16-bit mono 44.1 kHz WAV, imported as QOA.

| File | Event | Source | Licence | Description |
|---|---|---|---|---|
| `sfx/sfx_block_confirm_01.wav` | `block.confirm` | sfx_synth.py (procedural) | CC0-equivalent, original | two-stone lock |
| `sfx/sfx_block_invalid_01.wav` | `block.invalid` | sfx_synth.py (procedural) | CC0-equivalent, original | one muted buzz |
| `sfx/sfx_block_pickup_l_01.wav` | `block.pickup` | sfx_synth.py (procedural) | CC0-equivalent, original | stone clack, pitch by Block size (tier L) |
| `sfx/sfx_block_pickup_m_01.wav` | `block.pickup` | sfx_synth.py (procedural) | CC0-equivalent, original | stone clack, pitch by Block size (tier M) |
| `sfx/sfx_block_pickup_s_01.wav` | `block.pickup` | sfx_synth.py (procedural) | CC0-equivalent, original | stone clack, pitch by Block size (tier S) |
| `sfx/sfx_block_place_01.wav` | `block.place` | sfx_synth.py (procedural) | CC0-equivalent, original | firm stone set: low thud and clack (variant 1) |
| `sfx/sfx_block_place_02.wav` | `block.place` | sfx_synth.py (procedural) | CC0-equivalent, original | firm stone set: low thud and clack (variant 2) |
| `sfx/sfx_block_select_01.wav` | `block.select` | sfx_synth.py (procedural) | CC0-equivalent, original | light lift, airy rising tone |
| `sfx/sfx_block_slot_full_01.wav` | `block.slot_full` | sfx_synth.py (procedural) | CC0-equivalent, original | dull knock, twice |
| `sfx/sfx_card_choose_01.wav` | `card.choose` | sfx_synth.py (procedural) | CC0-equivalent, original | bright confirm bell |
| `sfx/sfx_card_highlight_01.wav` | `card.highlight` | sfx_synth.py (procedural) | CC0-equivalent, original | soft tick |
| `sfx/sfx_card_menu_open_01.wav` | `card.menu_open` | sfx_synth.py (procedural) | CC0-equivalent, original | paper flip and soft rune hum |
| `sfx/sfx_card_ready_01.wav` | `card.ready` | sfx_synth.py (procedural) | CC0-equivalent, original | soft ready tone |
| `sfx/sfx_card_unavailable_01.wav` | `card.unavailable` | sfx_synth.py (procedural) | CC0-equivalent, original | dull locked click |
| `sfx/sfx_combat_crit_01.wav` | `combat.crit` | sfx_synth.py (procedural) | CC0-equivalent, original | sharp crack, ping and thump |
| `sfx/sfx_combat_death_01.wav` | `combat.death` | sfx_synth.py (procedural) | CC0-equivalent, original | falling low tone with dust |
| `sfx/sfx_combat_hit_enemy_01.wav` | `combat.hit.enemy` | sfx_synth.py (procedural) | CC0-equivalent, original | impact smack (variant 1) |
| `sfx/sfx_combat_hit_enemy_02.wav` | `combat.hit.enemy` | sfx_synth.py (procedural) | CC0-equivalent, original | impact smack (variant 2) |
| `sfx/sfx_combat_hit_player_01.wav` | `combat.hit.player` | sfx_synth.py (procedural) | CC0-equivalent, original | body hit: low thump and crunch (variant 1) |
| `sfx/sfx_combat_hit_player_02.wav` | `combat.hit.player` | sfx_synth.py (procedural) | CC0-equivalent, original | body hit: low thump and crunch (variant 2) |
| `sfx/sfx_combat_hp_low_01.wav` | `combat.hp_low` | sfx_synth.py (procedural) | CC0-equivalent, original | heartbeat lub-dub |
| `sfx/sfx_combat_interrupt_01.wav` | `combat.interrupt` | sfx_synth.py (procedural) | CC0-equivalent, original | broken whoosh cut by a thud (NGAT!) |
| `sfx/sfx_combat_lock_01.wav` | `combat.lock` | sfx_synth.py (procedural) | CC0-equivalent, original | short bright lock clink |
| `sfx/sfx_combat_parry_01.wav` | `combat.parry` | sfx_synth.py (procedural) | CC0-equivalent, original | metallic clang |
| `sfx/sfx_flow_defeat_01.wav` | `flow.defeat` | sfx_synth.py (procedural) | CC0-equivalent, original | falling minor phrase over a low drone |
| `sfx/sfx_flow_victory_01.wav` | `flow.victory` | sfx_synth.py (procedural) | CC0-equivalent, original | major arpeggio stinger |
| `sfx/sfx_skill_generic_cancel_01.wav` | `skill.generic.cancel` | sfx_synth.py (procedural) | CC0-equivalent, original | descending scatter |
| `sfx/sfx_skill_generic_commit_01.wav` | `skill.generic.commit` | sfx_synth.py (procedural) | CC0-equivalent, original | release whoosh with a thump |
| `sfx/sfx_skill_generic_fizzle_01.wav` | `skill.generic.fizzle` | sfx_synth.py (procedural) | CC0-equivalent, original | dry pop |
| `sfx/sfx_skill_generic_hit_01.wav` | `skill.generic.hit` | sfx_synth.py (procedural) | CC0-equivalent, original | crunchy hit confirm |
| `sfx/sfx_skill_generic_travel_01.wav` | `skill.generic.travel` | sfx_synth.py (procedural) | CC0-equivalent, original | soft air rush |
| `sfx/sfx_skill_generic_windup_01.wav` | `skill.generic.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | rising wind-up whoosh (variant 1) |
| `sfx/sfx_skill_generic_windup_02.wav` | `skill.generic.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | rising wind-up whoosh (variant 2) |
| `sfx/sfx_skill_hoa_loi_charge_01.wav` | `skill.hoa_loi.charge` | sfx_synth.py (procedural) | CC0-equivalent, original | Hoa Loi fuse bed: soft crackle |
| `sfx/sfx_skill_hoa_loi_fizzle_01.wav` | `skill.hoa_loi.fizzle` | sfx_synth.py (procedural) | CC0-equivalent, original | Hoa Loi fizzle: small dry pop |
| `sfx/sfx_skill_hoa_loi_prime_01.wav` | `skill.hoa_loi.prime` | sfx_synth.py (procedural) | CC0-equivalent, original | Hoa Loi last pulse: short rising pressure hiss |
| `sfx/sfx_skill_hoa_loi_seal_01.wav` | `skill.hoa_loi.seal` | sfx_synth.py (procedural) | CC0-equivalent, original | Hoa Loi brand: low sizzle at the seals |
| `sfx/sfx_skill_hoa_loi_tick_01.wav` | `skill.hoa_loi.tick` | sfx_synth.py (procedural) | CC0-equivalent, original | Hoa Loi countdown tick (pitched up per step at runtime) |
| `sfx/sfx_skill_impact_burn_01.wav` | `skill.impact.burn` | sfx_synth.py (procedural) | CC0-equivalent, original | burn: whump and crackle |
| `sfx/sfx_skill_impact_burst_01.wav` | `skill.impact.burst` | sfx_synth.py (procedural) | CC0-equivalent, original | burst: deep thud and blast |
| `sfx/sfx_skill_impact_curse_01.wav` | `skill.impact.curse` | sfx_synth.py (procedural) | CC0-equivalent, original | curse: dark beating drone with a reverse swell |
| `sfx/sfx_skill_impact_freeze_01.wav` | `skill.impact.freeze` | sfx_synth.py (procedural) | CC0-equivalent, original | freeze: crystalline chime and crack |
| `sfx/sfx_skill_impact_knockback_01.wav` | `skill.impact.knockback` | sfx_synth.py (procedural) | CC0-equivalent, original | knockback: heavy punch and air |
| `sfx/sfx_skill_impact_poison_01.wav` | `skill.impact.poison` | sfx_synth.py (procedural) | CC0-equivalent, original | poison: bubbling chirps |
| `sfx/sfx_skill_impact_shatter_01.wav` | `skill.impact.shatter` | sfx_synth.py (procedural) | CC0-equivalent, original | shatter: glassy breaks |
| `sfx/sfx_skill_impact_slash_01.wav` | `skill.impact.slash` | sfx_synth.py (procedural) | CC0-equivalent, original | slash: sharp swish and blade ring |
| `sfx/sfx_skill_impact_thorns_01.wav` | `skill.impact.thorns` | sfx_synth.py (procedural) | CC0-equivalent, original | thorns: three quick spiked stabs |
| `sfx/sfx_skill_ngan_kiem_cancel_01.wav` | `skill.ngan_kiem.cancel` | sfx_synth.py (procedural) | CC0-equivalent, original | Ngan Kiem dispersal: resonance cut, descending glassy scatter |
| `sfx/sfx_skill_ngan_kiem_charge_01.wav` | `skill.ngan_kiem.charge` | sfx_synth.py (procedural) | CC0-equivalent, original | Ngan Kiem gather: staggered metallic tinkles at the tiles |
| `sfx/sfx_skill_ngan_kiem_commit_01.wav` | `skill.ngan_kiem.commit` | sfx_synth.py (procedural) | CC0-equivalent, original | Ngan Kiem command: sharp downward shing and air cut |
| `sfx/sfx_skill_tram_dia_aftermath_01.wav` | `skill.tram_dia.aftermath` | sfx_synth.py (procedural) | CC0-equivalent, original | Tram Dia aftermath: pebble trickle and fading ring |
| `sfx/sfx_skill_tram_dia_commit_01.wav` | `skill.tram_dia.commit` | sfx_synth.py (procedural) | CC0-equivalent, original | Tram Dia release: heavy whoosh with a gritty floor-drag tail |
| `sfx/sfx_skill_tram_dia_impact_01.wav` | `skill.tram_dia.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | Tram Dia surge step: small rock crack (variant 1) |
| `sfx/sfx_skill_tram_dia_impact_02.wav` | `skill.tram_dia.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | Tram Dia surge step: small rock crack (variant 2) |
| `sfx/sfx_skill_tram_dia_impact_final_01.wav` | `skill.tram_dia.impact_final` | sfx_synth.py (procedural) | CC0-equivalent, original | Tram Dia eruption: deep thud, split-rock crack, bright steel ring |
| `sfx/sfx_skill_tram_dia_travel_01.wav` | `skill.tram_dia.travel` | sfx_synth.py (procedural) | CC0-equivalent, original | Tram Dia wave: short grinding floor rumble |
| `sfx/sfx_skill_tram_dia_windup_01.wav` | `skill.tram_dia.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | Tram Dia wind-up: low steel scrape and a rising breath of tension |
| `sfx/sfx_status_burn_hurt_01.wav` | `status.burn.hurt` | sfx_synth.py (procedural) | CC0-equivalent, original | Burn tick on a unit: short light sizzle (no body thump) |
| `sfx/sfx_status_burn_ignite_01.wav` | `status.burn.ignite` | sfx_synth.py (procedural) | CC0-equivalent, original | ignition whoosh and embers |
| `sfx/sfx_status_burn_loop_01.wav` | `status.burn.loop` | sfx_synth.py (procedural) | CC0-equivalent, original | Burning ground: steady ember crackle over a low fire bed (1.5 s, seamless loop) |
| `sfx/sfx_status_burn_out_01.wav` | `status.burn.out` | sfx_synth.py (procedural) | CC0-equivalent, original | Burning ground out (last burning cell burned out): soft hiss-out |
| `sfx/sfx_ui_back_01.wav` | `ui.back` | sfx_synth.py (procedural) | CC0-equivalent, original | two descending wood ticks |
| `sfx/sfx_ui_tap_01.wav` | `ui.tap` | sfx_synth.py (procedural) | CC0-equivalent, original | short wood tick (variant 1) |
| `sfx/sfx_ui_tap_02.wav` | `ui.tap` | sfx_synth.py (procedural) | CC0-equivalent, original | short wood tick (variant 2) |
| `sfx/sfx_ui_toggle_01.wav` | `ui.toggle` | sfx_synth.py (procedural) | CC0-equivalent, original | two quick rising ticks |
| `sfx/sfx_warn_boss_imminent_01.wav` | `warn.boss.imminent` | sfx_synth.py (procedural) | CC0-equivalent, original | two-note rising alarm, 1.1 then 1.65 kHz |
| `sfx/sfx_warn_boss_recovery_01.wav` | `warn.boss.recovery` | sfx_synth.py (procedural) | CC0-equivalent, original | soft descending exhale chime (opening) |
| `sfx/sfx_warn_boss_windup_01.wav` | `warn.boss.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | low drum hit, armour shift and rattle (1-2.5 kHz) |
| `sfx/sfx_warn_terrain_vent_01.wav` | `warn.terrain.vent` | sfx_synth.py (procedural) | CC0-equivalent, original | vent hiss over a rising rumble (1-3 kHz) |
| `sfx/sfx_skill_hoa_loi_ignite_01.wav` | `skill.hoa_loi.ignite` | procedural mockup, tools/audio/hoa_loi_mockups.py (CC0-equivalent, original), generation `fire_ignite`, 2026-11-09; raw `audio_src/derived/hoa_loi_mockups/fire_ignite.wav`; prompt in `tools/audio/hoa_loi_mockups.py` | CC0-equivalent, original | Hoa Loi release: one short fire burst when the seals appear (cast_scheduled), not played if the cast is interrupted |
| `sfx/sfx_skill_hoa_loi_impact_el_l_01.wav` | `skill.hoa_loi.impact` | ElevenLabs eleven_text_to_sound_v2, generation `2GhvmghqO026bpy8NPih`, 2026-11-09; raw `audio_src/elevenlabs/hoa_loi/thunder/hoa_loi_thunder_v1_takeB_2GhvmghqO026bpy8NPih.mp3`; prompt in `audio_src/elevenlabs/hoa_loi/thunder/generations.json` | UNCONFIRMED (depends on the ElevenLabs plan; not yet provided by the user) | Hoa Loi thunderstrike (take B, approved by ear 2026-11-09), tier L: 0.80 s, +0 dB |
| `sfx/sfx_skill_hoa_loi_impact_el_m_01.wav` | `skill.hoa_loi.impact` | ElevenLabs eleven_text_to_sound_v2, generation `2GhvmghqO026bpy8NPih`, 2026-11-09; raw `audio_src/elevenlabs/hoa_loi/thunder/hoa_loi_thunder_v1_takeB_2GhvmghqO026bpy8NPih.mp3`; prompt in `audio_src/elevenlabs/hoa_loi/thunder/generations.json` | UNCONFIRMED (depends on the ElevenLabs plan; not yet provided by the user) | Hoa Loi thunderstrike (take B, approved by ear 2026-11-09), tier M: 0.65 s, -2 dB |
| `sfx/sfx_skill_hoa_loi_impact_el_s_01.wav` | `skill.hoa_loi.impact` | ElevenLabs eleven_text_to_sound_v2, generation `2GhvmghqO026bpy8NPih`, 2026-11-09; raw `audio_src/elevenlabs/hoa_loi/thunder/hoa_loi_thunder_v1_takeB_2GhvmghqO026bpy8NPih.mp3`; prompt in `audio_src/elevenlabs/hoa_loi/thunder/generations.json` | UNCONFIRMED (depends on the ElevenLabs plan; not yet provided by the user) | Hoa Loi thunderstrike (take B, approved by ear 2026-11-09), tier S: 0.50 s, -4 dB |
| `sfx/sfx_skill_hoa_loi_windup_fb_01.wav` | `skill.hoa_loi.windup` | procedural mockup, tools/audio/hoa_loi_mockups.py (CC0-equivalent, original), generation `fire_build`, 2026-11-09; raw `audio_src/derived/hoa_loi_mockups/fire_build.wav`; prompt in `tools/audio/hoa_loi_mockups.py` | CC0-equivalent, original | Hoa Loi cast: fire catching over the Mage's 0.45 s gesture, crackles thicken (approved by ear 2026-11-09) |
| `sfx/sfx_skill_ngan_kiem_channel_loop_el_01.wav` | `skill.ngan_kiem.channel_loop` | ElevenLabs eleven_text_to_sound_v2 (loop: true), generation `kigG56gQWrYufmIk7h7u`, 2026-11-09; raw `audio_src/elevenlabs/ngan_kiem/channel_loop/ngan_kiem_channel_loop_v1_takeB_kigG56gQWrYufmIk7h7u.mp3`; prompt in `audio_src/elevenlabs/ngan_kiem/channel_loop/generations.json` | UNCONFIRMED (depends on the ElevenLabs plan; not yet provided by the user) | Ngan Kiem summon + channel (the whole summon sound): take B as recorded up to 1.65 s, then a seamless sustain built from its 1.35-1.75 s tail so channels longer than 1.65 s (5+ cells) hold steady (approved by ear 2026-11-09) |
| `sfx/sfx_skill_ngan_kiem_impact_el_01.wav` | `skill.ngan_kiem.impact` | ElevenLabs eleven_text_to_sound_v2, generation `hC6J5kSKKandCtVQHWIi`, 2026-11-09; raw `audio_src/elevenlabs/ngan_kiem/impact/ngan_kiem_impact_v1_takeA_hC6J5kSKKandCtVQHWIi.mp3`; prompt in `audio_src/elevenlabs/ngan_kiem/impact/generations.json` | UNCONFIRMED (depends on the ElevenLabs plan; not yet provided by the user) | Ngan Kiem drop: heavy steel blade stabbing a stone tile (take A, approved by ear 2026-11-09) |
| `sfx/sfx_skill_ngan_kiem_impact_el_02.wav` | `skill.ngan_kiem.impact` | ElevenLabs eleven_text_to_sound_v2, generation `wK46mLNLpCyHBxEloQAD`, 2026-11-09; raw `audio_src/elevenlabs/ngan_kiem/impact/ngan_kiem_impact_v1_takeB_wK46mLNLpCyHBxEloQAD.mp3`; prompt in `audio_src/elevenlabs/ngan_kiem/impact/generations.json` | UNCONFIRMED (depends on the ElevenLabs plan; not yet provided by the user) | Ngan Kiem drop: heavy steel blade stabbing a stone tile (take B, approved by ear 2026-11-09) |
| `sfx/sfx_skill_ngan_kiem_impact_el_03.wav` | `skill.ngan_kiem.impact` | ElevenLabs eleven_text_to_sound_v2, generation `udvF7Xs2CLR86C8UhkJv`, 2026-11-09; raw `audio_src/elevenlabs/ngan_kiem/impact/ngan_kiem_impact_v1_takeC_udvF7Xs2CLR86C8UhkJv.mp3`; prompt in `audio_src/elevenlabs/ngan_kiem/impact/generations.json` | UNCONFIRMED (depends on the ElevenLabs plan; not yet provided by the user) | Ngan Kiem drop: heavy steel blade stabbing a stone tile (take C, approved by ear 2026-11-09) |
| `sfx/sfx_skill_ngan_kiem_impact_el_04.wav` | `skill.ngan_kiem.impact` | ElevenLabs eleven_text_to_sound_v2, generation `oFSOThm9Y12k0wZawMsf`, 2026-11-09; raw `audio_src/elevenlabs/ngan_kiem/impact/ngan_kiem_impact_v1_takeD_oFSOThm9Y12k0wZawMsf.mp3`; prompt in `audio_src/elevenlabs/ngan_kiem/impact/generations.json` | UNCONFIRMED (depends on the ElevenLabs plan; not yet provided by the user) | Ngan Kiem drop: heavy steel blade stabbing a stone tile (take D, approved by ear 2026-11-09) |
| `sfx/sfx_skill_ngan_kiem_impact_final_el_01.wav` | `skill.ngan_kiem.impact_final` | ElevenLabs eleven_text_to_sound_v2, generation `hC6J5kSKKandCtVQHWIi`, 2026-11-09; raw `audio_src/elevenlabs/ngan_kiem/impact/ngan_kiem_impact_v1_takeA_hC6J5kSKKandCtVQHWIi.mp3`; prompt in `audio_src/elevenlabs/ngan_kiem/impact/generations.json` | UNCONFIRMED (depends on the ElevenLabs plan; not yet provided by the user) | Ngan Kiem centre blade: the stab take A held longer (0.6 s), the event mixes it at -8 dB vs the audition reference (approved by ear 2026-11-09) |
