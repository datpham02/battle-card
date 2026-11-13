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
| `sfx/sfx_block_invalid_01.wav` | `block.invalid` | sfx_synth.py (procedural) | CC0-equivalent, original | invalid: two dull low knocks (a soft 'no') |
| `sfx/sfx_block_pickup_l_01.wav` | `block.pickup` | sfx_synth.py (procedural) | CC0-equivalent, original | Block pick-up: knock, smaller Block higher (tier L) |
| `sfx/sfx_block_pickup_m_01.wav` | `block.pickup` | sfx_synth.py (procedural) | CC0-equivalent, original | Block pick-up: knock, smaller Block higher (tier M) |
| `sfx/sfx_block_pickup_s_01.wav` | `block.pickup` | sfx_synth.py (procedural) | CC0-equivalent, original | Block pick-up: knock, smaller Block higher (tier S) |
| `sfx/sfx_block_place_01.wav` | `block.place` | sfx_synth.py (procedural) | CC0-equivalent, original | Block place: low stone knock with a soft thump (variant 1) |
| `sfx/sfx_block_place_02.wav` | `block.place` | sfx_synth.py (procedural) | CC0-equivalent, original | Block place: low stone knock with a soft thump (variant 2) |
| `sfx/sfx_block_select_01.wav` | `block.select` | sfx_synth.py (procedural) | CC0-equivalent, original | Block select: light tick |
| `sfx/sfx_card_choose_01.wav` | `card.choose` | sfx_synth.py (procedural) | CC0-equivalent, original | card choose: two quick tings (E5, G5) |
| `sfx/sfx_card_highlight_01.wav` | `card.highlight` | sfx_synth.py (procedural) | CC0-equivalent, original | card highlight: soft high tick |
| `sfx/sfx_card_menu_open_01.wav` | `card.menu_open` | sfx_synth.py (procedural) | CC0-equivalent, original | card menu: short paper puff and a soft ting |
| `sfx/sfx_card_ready_01.wav` | `card.ready` | sfx_synth.py (procedural) | CC0-equivalent, original | card ready: one soft high ting |
| `sfx/sfx_card_unavailable_01.wav` | `card.unavailable` | sfx_synth.py (procedural) | CC0-equivalent, original | card unavailable: one dull knock |
| `sfx/sfx_combat_crit_01.wav` | `combat.crit` | sfx_synth.py (procedural) | CC0-equivalent, original | crit: thump with a high ting on top |
| `sfx/sfx_combat_death_01.wav` | `combat.death` | sfx_synth.py (procedural) | CC0-equivalent, original | death: longer low thump and a soft puff of dust |
| `sfx/sfx_combat_hit_enemy_01.wav` | `combat.hit.enemy` | sfx_synth.py (procedural) | CC0-equivalent, original | enemy hit: thump and a click (variant 1) |
| `sfx/sfx_combat_hit_enemy_02.wav` | `combat.hit.enemy` | sfx_synth.py (procedural) | CC0-equivalent, original | enemy hit: thump and a click (variant 2) |
| `sfx/sfx_combat_hit_player_01.wav` | `combat.hit.player` | sfx_synth.py (procedural) | CC0-equivalent, original | player hit: low thump and a short crunch (variant 1) |
| `sfx/sfx_combat_hit_player_02.wav` | `combat.hit.player` | sfx_synth.py (procedural) | CC0-equivalent, original | player hit: low thump and a short crunch (variant 2) |
| `sfx/sfx_combat_hp_low_01.wav` | `combat.hp_low` | sfx_synth.py (procedural) | CC0-equivalent, original | low HP: two soft heartbeat thumps |
| `sfx/sfx_combat_interrupt_01.wav` | `combat.interrupt` | sfx_synth.py (procedural) | CC0-equivalent, original | interrupt (NGẮT!): low knock cut by a puff |
| `sfx/sfx_combat_lock_01.wav` | `combat.lock` | sfx_synth.py (procedural) | CC0-equivalent, original | lock: high tick and a small knock |
| `sfx/sfx_combat_parry_01.wav` | `combat.parry` | sfx_synth.py (procedural) | CC0-equivalent, original | parry: bright metal ting over a knock |
| `sfx/sfx_flow_defeat_01.wav` | `flow.defeat` | sfx_synth.py (procedural) | CC0-equivalent, original | defeat: G4 E4 C4, soft |
| `sfx/sfx_flow_victory_01.wav` | `flow.victory` | sfx_synth.py (procedural) | CC0-equivalent, original | victory: C5 E5 G5 C6 |
| `sfx/sfx_move_step_01.wav` | `move.step` | sfx_synth.py (procedural) | CC0-equivalent, original | hero step to a cell: soft low stone tick (variant 1) |
| `sfx/sfx_move_step_02.wav` | `move.step` | sfx_synth.py (procedural) | CC0-equivalent, original | hero step to a cell: soft low stone tick (variant 2) |
| `sfx/sfx_pickup_point_01.wav` | `pickup.point` | sfx_synth.py (procedural) | CC0-equivalent, original | pick up a field point: one pleasant ting (variant 1) |
| `sfx/sfx_pickup_point_02.wav` | `pickup.point` | sfx_synth.py (procedural) | CC0-equivalent, original | pick up a field point: one pleasant ting (variant 2) |
| `sfx/sfx_skill_card_bang_chau_impact_01.wav` | `skill.card.bang_chau.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | bang_chau impact: cluster (VFX form cluster) |
| `sfx/sfx_skill_card_bang_chau_windup_01.wav` | `skill.card.bang_chau.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | bang_chau wind-up: chain |
| `sfx/sfx_skill_card_bang_phong_impact_01.wav` | `skill.card.bang_phong.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | bang_phong impact: frame (VFX form frame) |
| `sfx/sfx_skill_card_bang_phong_windup_01.wav` | `skill.card.bang_phong.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | bang_phong wind-up: hand |
| `sfx/sfx_skill_card_bang_tam_impact_01.wav` | `skill.card.bang_tam.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | bang_tam impact: shards (VFX form shards) |
| `sfx/sfx_skill_card_bang_tam_windup_01.wav` | `skill.card.bang_tam.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | bang_tam wind-up: chain |
| `sfx/sfx_skill_card_bang_vo_impact_01.wav` | `skill.card.bang_vo.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | bang_vo impact: iceburst (VFX form iceburst) |
| `sfx/sfx_skill_card_bang_vo_windup_01.wav` | `skill.card.bang_vo.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | bang_vo wind-up: hand |
| `sfx/sfx_skill_card_bay_kep_impact_01.wav` | `skill.card.bay_kep.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | bay_kep impact: jaw (VFX form jaw) |
| `sfx/sfx_skill_card_bay_kep_windup_01.wav` | `skill.card.bay_kep.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | bay_kep wind-up: body |
| `sfx/sfx_skill_card_bay_lo_impact_01.wav` | `skill.card.bay_lo.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | bay_lo impact: spring (VFX form spring) |
| `sfx/sfx_skill_card_bay_lo_windup_01.wav` | `skill.card.bay_lo.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | bay_lo wind-up: body |
| `sfx/sfx_skill_card_chan_phong_impact_01.wav` | `skill.card.chan_phong.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | chan_phong impact: column (VFX form column) |
| `sfx/sfx_skill_card_chan_phong_windup_01.wav` | `skill.card.chan_phong.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | chan_phong wind-up: throw |
| `sfx/sfx_skill_card_chuoi_set_impact_01.wav` | `skill.card.chuoi_set.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | chuoi_set impact: spark4 (VFX form -) |
| `sfx/sfx_skill_card_chuoi_set_windup_01.wav` | `skill.card.chuoi_set.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | chuoi_set wind-up: hand |
| `sfx/sfx_skill_card_chuong_thanh_impact_01.wav` | `skill.card.chuong_thanh.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | chuong_thanh impact: bell (VFX form bell) |
| `sfx/sfx_skill_card_chuong_thanh_windup_01.wav` | `skill.card.chuong_thanh.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | chuong_thanh wind-up: weapon |
| `sfx/sfx_skill_card_cuong_phong_impact_01.wav` | `skill.card.cuong_phong.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | cuong_phong impact: column2 (VFX form column) |
| `sfx/sfx_skill_card_cuong_phong_windup_01.wav` | `skill.card.cuong_phong.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | cuong_phong wind-up: throw |
| `sfx/sfx_skill_card_dai_dao_impact_01.wav` | `skill.card.dai_dao.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | dai_dao impact: double (VFX form double) |
| `sfx/sfx_skill_card_dai_dao_windup_01.wav` | `skill.card.dai_dao.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | dai_dao wind-up: chain |
| `sfx/sfx_skill_card_dap_vo_impact_01.wav` | `skill.card.dap_vo.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | dap_vo impact: smash (VFX form -) |
| `sfx/sfx_skill_card_dap_vo_windup_01.wav` | `skill.card.dap_vo.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | dap_vo wind-up: weapon |
| `sfx/sfx_skill_card_dau_tu_impact_01.wav` | `skill.card.dau_tu.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | dau_tu impact: deathmark (VFX form deathmark) |
| `sfx/sfx_skill_card_dau_tu_windup_01.wav` | `skill.card.dau_tu.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | dau_tu wind-up: hand |
| `sfx/sfx_skill_card_dia_chan_impact_01.wav` | `skill.card.dia_chan.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | dia_chan impact: quake (VFX form quake) |
| `sfx/sfx_skill_card_dia_chan_windup_01.wav` | `skill.card.dia_chan.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | dia_chan wind-up: body |
| `sfx/sfx_skill_card_do_kiem_impact_01.wav` | `skill.card.do_kiem.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | do_kiem impact: ring2 (VFX form ring2) |
| `sfx/sfx_skill_card_do_kiem_windup_01.wav` | `skill.card.do_kiem.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | do_kiem wind-up: throw |
| `sfx/sfx_skill_card_gai_doc_impact_01.wav` | `skill.card.gai_doc.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | gai_doc impact: bubbles (VFX form bubbles) |
| `sfx/sfx_skill_card_gai_doc_windup_01.wav` | `skill.card.gai_doc.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | gai_doc wind-up: ground |
| `sfx/sfx_skill_card_gai_nguyen_impact_01.wav` | `skill.card.gai_nguyen.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | gai_nguyen impact: vine (VFX form spikes) |
| `sfx/sfx_skill_card_gai_nguyen_windup_01.wav` | `skill.card.gai_nguyen.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | gai_nguyen wind-up: ground |
| `sfx/sfx_skill_card_gai_no_impact_01.wav` | `skill.card.gai_no.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | gai_no impact: splinter (VFX form splinter) |
| `sfx/sfx_skill_card_gai_no_windup_01.wav` | `skill.card.gai_no.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | gai_no wind-up: body |
| `sfx/sfx_skill_card_ganh_nang_impact_01.wav` | `skill.card.ganh_nang.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | ganh_nang impact: curse_low (VFX form -) |
| `sfx/sfx_skill_card_ganh_nang_windup_01.wav` | `skill.card.ganh_nang.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | ganh_nang wind-up: hand |
| `sfx/sfx_skill_card_han_bang_impact_01.wav` | `skill.card.han_bang.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | han_bang impact: chunks (VFX form chunks) |
| `sfx/sfx_skill_card_han_bang_windup_01.wav` | `skill.card.han_bang.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | han_bang wind-up: sky |
| `sfx/sfx_skill_card_han_khi_impact_01.wav` | `skill.card.han_khi.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | han_khi impact: cross (VFX form cross) |
| `sfx/sfx_skill_card_han_khi_windup_01.wav` | `skill.card.han_khi.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | han_khi wind-up: throw |
| `sfx/sfx_skill_card_han_kiem_impact_01.wav` | `skill.card.han_kiem.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | han_kiem impact: spike_tilt (VFX form spike) |
| `sfx/sfx_skill_card_han_kiem_windup_01.wav` | `skill.card.han_kiem.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | han_kiem wind-up: throw |
| `sfx/sfx_skill_card_han_phong_impact_01.wav` | `skill.card.han_phong.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | han_phong impact: cross_diag (VFX form cross) |
| `sfx/sfx_skill_card_han_phong_windup_01.wav` | `skill.card.han_phong.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | han_phong wind-up: chain |
| `sfx/sfx_skill_card_han_tran_impact_01.wav` | `skill.card.han_tran.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | han_tran impact: spike2 (VFX form spike) |
| `sfx/sfx_skill_card_han_tran_windup_01.wav` | `skill.card.han_tran.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | han_tran wind-up: hand |
| `sfx/sfx_skill_card_hoa_bang_impact_01.wav` | `skill.card.hoa_bang.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | hoa_bang impact: steam (VFX form steam) |
| `sfx/sfx_skill_card_hoa_bang_windup_01.wav` | `skill.card.hoa_bang.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | hoa_bang wind-up: hand |
| `sfx/sfx_skill_card_hoa_tinh_impact_01.wav` | `skill.card.hoa_tinh.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | hoa_tinh impact: sparks_fall (VFX form -) |
| `sfx/sfx_skill_card_hoa_tinh_windup_01.wav` | `skill.card.hoa_tinh.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | hoa_tinh wind-up: sky |
| `sfx/sfx_skill_card_hoa_tran_impact_01.wav` | `skill.card.hoa_tran.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | hoa_tran impact: fire_field (VFX form -) |
| `sfx/sfx_skill_card_hoa_tran_windup_01.wav` | `skill.card.hoa_tran.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | hoa_tran wind-up: hand |
| `sfx/sfx_skill_card_hoa_tuyen_impact_01.wav` | `skill.card.hoa_tuyen.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | hoa_tuyen impact: firewall (VFX form firewall) |
| `sfx/sfx_skill_card_hoa_tuyen_windup_01.wav` | `skill.card.hoa_tuyen.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | hoa_tuyen wind-up: hand |
| `sfx/sfx_skill_card_hoa_xa_impact_01.wav` | `skill.card.hoa_xa.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | hoa_xa impact: floor_fire (VFX form -) |
| `sfx/sfx_skill_card_hoa_xa_windup_01.wav` | `skill.card.hoa_xa.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | hoa_xa wind-up: ground |
| `sfx/sfx_skill_card_hoi_am_impact_01.wav` | `skill.card.hoi_am.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | hoi_am impact: echo (VFX form echo) |
| `sfx/sfx_skill_card_hoi_am_windup_01.wav` | `skill.card.hoi_am.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | hoi_am wind-up: hand |
| `sfx/sfx_skill_card_khien_thep_impact_01.wav` | `skill.card.khien_thep.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | khien_thep impact: plate (VFX form plate) |
| `sfx/sfx_skill_card_khien_thep_windup_01.wav` | `skill.card.khien_thep.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | khien_thep wind-up: weapon |
| `sfx/sfx_skill_card_kiem_khi_impact_01.wav` | `skill.card.kiem_khi.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | kiem_khi impact: ring (VFX form ring) |
| `sfx/sfx_skill_card_kiem_khi_windup_01.wav` | `skill.card.kiem_khi.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | kiem_khi wind-up: throw |
| `sfx/sfx_skill_card_kiem_than_impact_01.wav` | `skill.card.kiem_than.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | kiem_than impact: cross_x (VFX form cross_x) |
| `sfx/sfx_skill_card_kiem_than_windup_01.wav` | `skill.card.kiem_than.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | kiem_than wind-up: throw |
| `sfx/sfx_skill_card_kiem_vu_impact_01.wav` | `skill.card.kiem_vu.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | kiem_vu impact: arc_v (VFX form arc_v) |
| `sfx/sfx_skill_card_kiem_vu_windup_01.wav` | `skill.card.kiem_vu.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | kiem_vu wind-up: sky |
| `sfx/sfx_skill_card_lien_tram_impact_01.wav` | `skill.card.lien_tram.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | lien_tram impact: chain3 (VFX form -) |
| `sfx/sfx_skill_card_lien_tram_windup_01.wav` | `skill.card.lien_tram.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | lien_tram wind-up: hand |
| `sfx/sfx_skill_card_liet_hoa_impact_01.wav` | `skill.card.liet_hoa.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | liet_hoa impact: firewall (VFX form -) |
| `sfx/sfx_skill_card_liet_hoa_windup_01.wav` | `skill.card.liet_hoa.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | liet_hoa wind-up: ground |
| `sfx/sfx_skill_card_loc_cuon_impact_01.wav` | `skill.card.loc_cuon.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | loc_cuon impact: vortex (VFX form vortex) |
| `sfx/sfx_skill_card_loc_cuon_windup_01.wav` | `skill.card.loc_cuon.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | loc_cuon wind-up: hand |
| `sfx/sfx_skill_card_min_tre_impact_01.wav` | `skill.card.min_tre.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | min_tre impact: knock_puff (VFX form -) |
| `sfx/sfx_skill_card_min_tre_windup_01.wav` | `skill.card.min_tre.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | min_tre wind-up: throw |
| `sfx/sfx_skill_card_moc_keo_impact_01.wav` | `skill.card.moc_keo.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | moc_keo impact: hook (VFX form hook) |
| `sfx/sfx_skill_card_moc_keo_windup_01.wav` | `skill.card.moc_keo.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | moc_keo wind-up: throw |
| `sfx/sfx_skill_card_oan_hon_impact_01.wav` | `skill.card.oan_hon.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | oan_hon impact: ghost (VFX form -) |
| `sfx/sfx_skill_card_oan_hon_windup_01.wav` | `skill.card.oan_hon.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | oan_hon wind-up: hand |
| `sfx/sfx_skill_card_phi_tieu_impact_01.wav` | `skill.card.phi_tieu.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | phi_tieu impact: dagger (VFX form dagger) |
| `sfx/sfx_skill_card_phi_tieu_windup_01.wav` | `skill.card.phi_tieu.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | phi_tieu wind-up: throw |
| `sfx/sfx_skill_card_ran_kich_impact_01.wav` | `skill.card.ran_kich.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | ran_kich impact: crack (VFX form crack) |
| `sfx/sfx_skill_card_ran_kich_windup_01.wav` | `skill.card.ran_kich.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | ran_kich wind-up: ground |
| `sfx/sfx_skill_card_ran_van_impact_01.wav` | `skill.card.ran_van.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | ran_van impact: crack_web (VFX form crack) |
| `sfx/sfx_skill_card_ran_van_windup_01.wav` | `skill.card.ran_van.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | ran_van wind-up: hand |
| `sfx/sfx_skill_card_song_dao_impact_01.wav` | `skill.card.song_dao.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | song_dao impact: twin (VFX form -) |
| `sfx/sfx_skill_card_song_dao_windup_01.wav` | `skill.card.song_dao.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | song_dao wind-up: hand |
| `sfx/sfx_skill_card_song_kiem_impact_01.wav` | `skill.card.song_kiem.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | song_kiem impact: double (VFX form double) |
| `sfx/sfx_skill_card_song_kiem_windup_01.wav` | `skill.card.song_kiem.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | song_kiem wind-up: chain |
| `sfx/sfx_skill_card_suong_mong_impact_01.wav` | `skill.card.suong_mong.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | suong_mong impact: frame_sparse (VFX form frame) |
| `sfx/sfx_skill_card_suong_mong_windup_01.wav` | `skill.card.suong_mong.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | suong_mong wind-up: hand |
| `sfx/sfx_skill_card_thanh_thuan_impact_01.wav` | `skill.card.thanh_thuan.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | thanh_thuan impact: ward (VFX form ward) |
| `sfx/sfx_skill_card_thanh_thuan_windup_01.wav` | `skill.card.thanh_thuan.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | thanh_thuan wind-up: hand |
| `sfx/sfx_skill_card_thanh_thuy_impact_01.wav` | `skill.card.thanh_thuy.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | thanh_thuy impact: drops3 (VFX form cross) |
| `sfx/sfx_skill_card_thanh_thuy_windup_01.wav` | `skill.card.thanh_thuy.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | thanh_thuy wind-up: chain |
| `sfx/sfx_skill_card_thien_hoa_impact_01.wav` | `skill.card.thien_hoa.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | thien_hoa impact: fire_sky (VFX form -) |
| `sfx/sfx_skill_card_thien_hoa_windup_01.wav` | `skill.card.thien_hoa.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | thien_hoa wind-up: sky |
| `sfx/sfx_skill_card_thien_lang_impact_01.wav` | `skill.card.thien_lang.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | thien_lang impact: slam (VFX form slam) |
| `sfx/sfx_skill_card_thien_lang_windup_01.wav` | `skill.card.thien_lang.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | thien_lang wind-up: sky |
| `sfx/sfx_skill_card_thien_quang_impact_01.wav` | `skill.card.thien_quang.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | thien_quang impact: lightpillar (VFX form lightpillar) |
| `sfx/sfx_skill_card_thien_quang_windup_01.wav` | `skill.card.thien_quang.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | thien_quang wind-up: hand |
| `sfx/sfx_skill_card_thien_thach_impact_01.wav` | `skill.card.thien_thach.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | thien_thach impact: crater (VFX form crater) |
| `sfx/sfx_skill_card_thien_thach_windup_01.wav` | `skill.card.thien_thach.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | thien_thach wind-up: hand |
| `sfx/sfx_skill_card_thiet_kiem_impact_01.wav` | `skill.card.thiet_kiem.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | thiet_kiem impact: arc_h (VFX form arc_h) |
| `sfx/sfx_skill_card_thiet_kiem_windup_01.wav` | `skill.card.thiet_kiem.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | thiet_kiem wind-up: throw |
| `sfx/sfx_skill_card_thuong_xuyen_impact_01.wav` | `skill.card.thuong_xuyen.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | thuong_xuyen impact: pierce (VFX form -) |
| `sfx/sfx_skill_card_thuong_xuyen_windup_01.wav` | `skill.card.thuong_xuyen.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | thuong_xuyen wind-up: weapon |
| `sfx/sfx_skill_card_tran_gai_impact_01.wav` | `skill.card.tran_gai.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | tran_gai impact: spikes (VFX form spikes) |
| `sfx/sfx_skill_card_tran_gai_windup_01.wav` | `skill.card.tran_gai.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | tran_gai wind-up: ground |
| `sfx/sfx_skill_card_tu_kiem_impact_01.wav` | `skill.card.tu_kiem.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | tu_kiem impact: stab4 (VFX form stab4) |
| `sfx/sfx_skill_card_tu_kiem_windup_01.wav` | `skill.card.tu_kiem.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | tu_kiem wind-up: hand |
| `sfx/sfx_skill_card_tuong_da_impact_01.wav` | `skill.card.tuong_da.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | tuong_da impact: pillar (VFX form pillar) |
| `sfx/sfx_skill_card_tuong_da_windup_01.wav` | `skill.card.tuong_da.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | tuong_da wind-up: body |
| `sfx/sfx_skill_card_vung_lay_impact_01.wav` | `skill.card.vung_lay.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | vung_lay impact: wide (VFX form -) |
| `sfx/sfx_skill_card_vung_lay_windup_01.wav` | `skill.card.vung_lay.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | vung_lay wind-up: hand |
| `sfx/sfx_skill_card_xung_kich_impact_01.wav` | `skill.card.xung_kich.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | xung_kich impact: wedge (VFX form wedge) |
| `sfx/sfx_skill_card_xung_kich_windup_01.wav` | `skill.card.xung_kich.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | xung_kich wind-up: ground |
| `sfx/sfx_skill_generic_cancel_01.wav` | `skill.generic.cancel` | sfx_synth.py (procedural) | CC0-equivalent, original | cancel: two soft tings down (C6, G5) |
| `sfx/sfx_skill_generic_commit_01.wav` | `skill.generic.commit` | sfx_synth.py (procedural) | CC0-equivalent, original | release: puff with a small thump |
| `sfx/sfx_skill_generic_fizzle_01.wav` | `skill.generic.fizzle` | sfx_synth.py (procedural) | CC0-equivalent, original | fizzle: tiny dry puff |
| `sfx/sfx_skill_generic_hit_01.wav` | `skill.generic.hit` | sfx_synth.py (procedural) | CC0-equivalent, original | hit confirm: small knock |
| `sfx/sfx_skill_generic_travel_01.wav` | `skill.generic.travel` | sfx_synth.py (procedural) | CC0-equivalent, original | travel: very soft short air |
| `sfx/sfx_skill_generic_windup_01.wav` | `skill.generic.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | wind-up: soft low puff and a tick (variant 1) |
| `sfx/sfx_skill_generic_windup_02.wav` | `skill.generic.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | wind-up: soft low puff and a tick (variant 2) |
| `sfx/sfx_skill_hoa_loi_charge_01.wav` | `skill.hoa_loi.charge` | sfx_synth.py (procedural) | CC0-equivalent, original | Hoa Loi fuse (silent by design): tiny crackle |
| `sfx/sfx_skill_hoa_loi_fizzle_01.wav` | `skill.hoa_loi.fizzle` | sfx_synth.py (procedural) | CC0-equivalent, original | Hoa Loi fizzle: tiny puff |
| `sfx/sfx_skill_hoa_loi_ignite_01.wav` | `skill.hoa_loi.ignite` | sfx_synth.py (procedural) | CC0-equivalent, original | Hoa Loi release (seals appear): one short puff and thump |
| `sfx/sfx_skill_hoa_loi_impact_l_01.wav` | `skill.hoa_loi.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | Hoa Loi blast, one per cast: crack, thump and crackle (bigger tier lower and longer) (tier L) |
| `sfx/sfx_skill_hoa_loi_impact_m_01.wav` | `skill.hoa_loi.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | Hoa Loi blast, one per cast: crack, thump and crackle (bigger tier lower and longer) (tier M) |
| `sfx/sfx_skill_hoa_loi_impact_s_01.wav` | `skill.hoa_loi.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | Hoa Loi blast, one per cast: crack, thump and crackle (bigger tier lower and longer) (tier S) |
| `sfx/sfx_skill_hoa_loi_prime_01.wav` | `skill.hoa_loi.prime` | sfx_synth.py (procedural) | CC0-equivalent, original | Hoa Loi prime (silent by design): puff |
| `sfx/sfx_skill_hoa_loi_seal_01.wav` | `skill.hoa_loi.seal` | sfx_synth.py (procedural) | CC0-equivalent, original | Hoa Loi seal (silent by design): tick |
| `sfx/sfx_skill_hoa_loi_tick_01.wav` | `skill.hoa_loi.tick` | sfx_synth.py (procedural) | CC0-equivalent, original | Hoa Loi countdown (silent by design): tick |
| `sfx/sfx_skill_hoa_loi_windup_01.wav` | `skill.hoa_loi.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | Hoa Loi cast: soft crackle, fire catching |
| `sfx/sfx_skill_impact_burn_01.wav` | `skill.impact.burn` | sfx_synth.py (procedural) | CC0-equivalent, original | impact burn: thump and a short crackle |
| `sfx/sfx_skill_impact_burst_01.wav` | `skill.impact.burst` | sfx_synth.py (procedural) | CC0-equivalent, original | impact burst: thump and puff |
| `sfx/sfx_skill_impact_curse_01.wav` | `skill.impact.curse` | sfx_synth.py (procedural) | CC0-equivalent, original | impact curse: low thump and a low ting (dark, short) |
| `sfx/sfx_skill_impact_freeze_01.wav` | `skill.impact.freeze` | sfx_synth.py (procedural) | CC0-equivalent, original | impact freeze: high ting and a crisp tick |
| `sfx/sfx_skill_impact_knockback_01.wav` | `skill.impact.knockback` | sfx_synth.py (procedural) | CC0-equivalent, original | impact knockback: low thump and air |
| `sfx/sfx_skill_impact_poison_01.wav` | `skill.impact.poison` | sfx_synth.py (procedural) | CC0-equivalent, original | impact poison: two soft bubble blips |
| `sfx/sfx_skill_impact_shatter_01.wav` | `skill.impact.shatter` | sfx_synth.py (procedural) | CC0-equivalent, original | impact shatter: three quick high ticks |
| `sfx/sfx_skill_impact_slash_01.wav` | `skill.impact.slash` | sfx_synth.py (procedural) | CC0-equivalent, original | impact slash: high puff and a short steel ting |
| `sfx/sfx_skill_impact_thorns_01.wav` | `skill.impact.thorns` | sfx_synth.py (procedural) | CC0-equivalent, original | impact thorns: three quick knocks |
| `sfx/sfx_skill_ngan_kiem_cancel_01.wav` | `skill.ngan_kiem.cancel` | sfx_synth.py (procedural) | CC0-equivalent, original | Ngan Kiem dispersal: three tings down |
| `sfx/sfx_skill_ngan_kiem_channel_loop_01.wav` | `skill.ngan_kiem.channel_loop` | sfx_synth.py (procedural) | CC0-equivalent, original | Ngan Kiem summon: three soft steel tings at the tiles, one shot (no drone) |
| `sfx/sfx_skill_ngan_kiem_charge_01.wav` | `skill.ngan_kiem.charge` | sfx_synth.py (procedural) | CC0-equivalent, original | Ngan Kiem gather (silent by design): soft ting |
| `sfx/sfx_skill_ngan_kiem_commit_01.wav` | `skill.ngan_kiem.commit` | sfx_synth.py (procedural) | CC0-equivalent, original | Ngan Kiem command (silent by design): knock |
| `sfx/sfx_skill_ngan_kiem_impact_01.wav` | `skill.ngan_kiem.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | Ngan Kiem drop: steel ting into a stone knock (variant 1) |
| `sfx/sfx_skill_ngan_kiem_impact_02.wav` | `skill.ngan_kiem.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | Ngan Kiem drop: steel ting into a stone knock (variant 2) |
| `sfx/sfx_skill_ngan_kiem_impact_03.wav` | `skill.ngan_kiem.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | Ngan Kiem drop: steel ting into a stone knock (variant 3) |
| `sfx/sfx_skill_ngan_kiem_impact_final_01.wav` | `skill.ngan_kiem.impact_final` | sfx_synth.py (procedural) | CC0-equivalent, original | Ngan Kiem centre blade: thump, knock and a lower ting |
| `sfx/sfx_skill_tram_dia_aftermath_01.wav` | `skill.tram_dia.aftermath` | sfx_synth.py (procedural) | CC0-equivalent, original | Tram Dia aftermath: two pebble ticks |
| `sfx/sfx_skill_tram_dia_commit_01.wav` | `skill.tram_dia.commit` | sfx_synth.py (procedural) | CC0-equivalent, original | Tram Dia release: puff and thump |
| `sfx/sfx_skill_tram_dia_impact_01.wav` | `skill.tram_dia.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | Tram Dia surge step: small rock knock (variant 1) |
| `sfx/sfx_skill_tram_dia_impact_02.wav` | `skill.tram_dia.impact` | sfx_synth.py (procedural) | CC0-equivalent, original | Tram Dia surge step: small rock knock (variant 2) |
| `sfx/sfx_skill_tram_dia_impact_final_01.wav` | `skill.tram_dia.impact_final` | sfx_synth.py (procedural) | CC0-equivalent, original | Tram Dia first eruption (biggest): deep thump, rock knock, low steel ting |
| `sfx/sfx_skill_tram_dia_travel_01.wav` | `skill.tram_dia.travel` | sfx_synth.py (procedural) | CC0-equivalent, original | Tram Dia wave: low short puff |
| `sfx/sfx_skill_tram_dia_windup_01.wav` | `skill.tram_dia.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | Tram Dia wind-up: low stone knock and a soft thump |
| `sfx/sfx_status_apply_01.wav` | `status.apply` | sfx_synth.py (procedural) | CC0-equivalent, original | a status lands: two quick tings up (pitch by status at runtime) (variant 1) |
| `sfx/sfx_status_apply_02.wav` | `status.apply` | sfx_synth.py (procedural) | CC0-equivalent, original | a status lands: two quick tings up (pitch by status at runtime) (variant 2) |
| `sfx/sfx_status_burn_hurt_01.wav` | `status.burn.hurt` | sfx_synth.py (procedural) | CC0-equivalent, original | burn tick on a unit: tiny sizzle |
| `sfx/sfx_status_burn_ignite_01.wav` | `status.burn.ignite` | sfx_synth.py (procedural) | CC0-equivalent, original | fire catches: short crackle |
| `sfx/sfx_status_burn_loop_01.wav` | `status.burn.loop` | sfx_synth.py (procedural) | CC0-equivalent, original | burning starts (any source): short soft crackle, one shot (no drone) |
| `sfx/sfx_status_burn_out_01.wav` | `status.burn.out` | sfx_synth.py (procedural) | CC0-equivalent, original | fire out: short soft puff |
| `sfx/sfx_status_expire_01.wav` | `status.expire` | sfx_synth.py (procedural) | CC0-equivalent, original | a status ends: two quick tings down (variant 1) |
| `sfx/sfx_status_expire_02.wav` | `status.expire` | sfx_synth.py (procedural) | CC0-equivalent, original | a status ends: two quick tings down (variant 2) |
| `sfx/sfx_ui_back_01.wav` | `ui.back` | sfx_synth.py (procedural) | CC0-equivalent, original | back: two ticks, second lower |
| `sfx/sfx_ui_tap_01.wav` | `ui.tap` | sfx_synth.py (procedural) | CC0-equivalent, original | tap: dry tick (variant 1) |
| `sfx/sfx_ui_tap_02.wav` | `ui.tap` | sfx_synth.py (procedural) | CC0-equivalent, original | tap: dry tick (variant 2) |
| `sfx/sfx_ui_toggle_01.wav` | `ui.toggle` | sfx_synth.py (procedural) | CC0-equivalent, original | toggle: two ticks, second higher |
| `sfx/sfx_warn_boss_imminent_01.wav` | `warn.boss.imminent` | sfx_synth.py (procedural) | CC0-equivalent, original | boss imminent: two notes up (G5, C6), clear and short |
| `sfx/sfx_warn_boss_recovery_01.wav` | `warn.boss.recovery` | sfx_synth.py (procedural) | CC0-equivalent, original | boss recovery (opening): two notes down (C6, G5), soft |
| `sfx/sfx_warn_boss_windup_01.wav` | `warn.boss.windup` | sfx_synth.py (procedural) | CC0-equivalent, original | boss wind-up: low thump and a knock-tick at 1.5 kHz |
| `sfx/sfx_warn_terrain_vent_01.wav` | `warn.terrain.vent` | sfx_synth.py (procedural) | CC0-equivalent, original | terrain vent: short 1-3 kHz puff over a low thump |
