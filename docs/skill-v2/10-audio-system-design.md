# Skill v2 — Audio System & Sound Design (proposal)

**Date:** 2026-11-08 · **Status:** PROPOSED — design and audit only. No audio was generated, bought or added; no
code, data, bus or setting was changed. No paid tool was used.
**Scope:** a shared audio system for Tessera (Godot 4.6, Android-first, 640×360 art), the audio of the three
reference skills, warnings, UI, music and ambience, and the roadmap phase that delivers it.

---

## 1. Current audio audit

**Summary: the game has no audio at all.** (`design/accessibility-requirements.md:147`: "Game chưa có âm thanh nào".)

| Area | Status | Evidence |
|---|---|---|
| Audio files | **Absent.** One stray QA capture track: `production/qa/evidence/guard-stance/cast/f.wav` (not game content) | no `assets/audio/`; `entity-inventory.md:172` "no audio yet" |
| Buses / mixing | **Absent** — no `default_bus_layout.tres`, no `[audio]` in `project.godot` | — |
| Playback code, audio manager, pooling, randomizer | **Absent** — no AudioStreamPlayer anywhere in `src/`; no autoloads | `settings_view.gd:12` "There is no audio in the game yet" |
| Volume settings | **Absent** — `SettingsStore` holds hints, reduce motion, card time, locale, last slot | `src/settings/settings_store.gd` |
| Combat event hooks | **Partial** — signals exist, nothing listens for audio | below |
| Skill animation / VFX sync points | **Implemented** for VFX: `cast_scheduled` (all event `at` times), `impact_resolved`, `swing_started/cancelled`, Commitment phases | `swing_arbiter.gd` 26–38, `cut_actor.gd` 9–15, `combat_view.gd` 3121–3206 |
| Boss telegraph hooks | **Partial** — `warning_started(skill, cells, queued, warning_sec)`, `warning_cleared`, `skill_resolved`, `stunned`; **no signal for WINDUP start or RECOVERY entry** (only `get_stage()`) | `pattern_controller.gd` 15–29, 117 |
| UI hooks | **Partial** — `cut_flow.skill_chosen`, hold slots `slot_filled/cleared`, pickups; **no signal** for piece select / place / confirm or menu open | `cut_flow.gd:14`, `hold_slots.gd:15` |
| Pause / background | **Implemented** for gameplay (`RunController.set_paused` → `PROCESS_MODE_DISABLED`; `NOTIFICATION_APPLICATION_PAUSED`, focus out) — no audio handling | `run_controller.gd:187`, `game_flow.gd:641` |
| Planned in docs | accessibility: Music + Effects sliders (0–100 %, default 80 %) **before audio ships**, in Settings and Pause; no cue only above 4 kHz; vibration alternative; SFX list (boss attack start, player hit, NGẮT!, Thức Tỉnh ready, low HP, phase change, terrain warning, relic). HUD spec: every P1/P2 notification has a sound, never replacing the visual. Game brief: "SFX phép giòn, nhạc orchestral nhẹ" | `accessibility-requirements.md:151–172, 289`, `ux/hud.md:380,426,437`, `game-brief.md:156` |
| Android audio settings | **Absent** — engine defaults, no export preset in the repo | — |

---

## 2. Proposed architecture

```
gameplay signals ──► AudioBridges (combat, ui, flow) ──► AudioEventRules (pure: signal → event ids + params)
                                                              │
assets/data/audio_events.json ──► AudioBank (load, validate) ─┤
                                                              ▼
                                   AudioDirector ──► VoicePool (per-category limits, priority, cooldowns)
                                        │                 └─► AudioStreamPlayer nodes on buses
                                        └─► MusicPlayer (stems, crossfade), AmbiencePlayer (loops)
```

| Component | Role | Testable how |
|---|---|---|
| `AudioEventRules` (pure, static) | maps a gameplay fact (signal + payload) to event ids and params (size tier, side, hit/miss) | unit tests, no nodes |
| `AudioBank` | loads `audio_events.json`, resolves fallbacks (card → archetype → default), validates ids, buses, files | unit test on the data |
| `VoicePool` | fixed pool of players; per-category voice caps; priority stealing; same-event cooldown; size-tier merging | unit test with a fake clock |
| `AudioDirector` | owns the pool, buses, ducking, pause; plays an event now or **at an arbiter time** | integration test |
| `CombatAudioBridge` | listens to `CombatView`, `SwingArbiter`, `CutActor`, `PatternController`, `StatusEffects`, `TileHazards` | integration test in a real CombatView |
| `UiAudioBridge`, `FlowAudioBridge` | menus, cards, Blocks, map, victory / defeat | integration tests |

**Pattern:** like `SettingsStore`: an instance passed in (dependency injection), with a `shared()` accessor for
scenes; `memory()`-style **silent** mode for tests and the balance sim. No gameplay code calls audio; bridges only
listen. Removing audio never changes gameplay.

**One configuration for 60 cards (no per-card code).** `audio_events.json`:
- `archetypes`: sounds per **delivery × impact × phase** (e.g. `SKY_TO_TARGET.slash.impact`, `*.burn.aftermath`),
  mirroring how `CastVfx` already picks packs by impact (`impact_packs`, `travel_impact_packs`).
- `cards`: optional overrides per card and phase (only reference / hero cards).
- `events`: the event definitions (files, variants, bus, priority, gain, pitch range, max voices, cooldown).

A new card gets correct sound from its delivery and impact with zero entries; a hero card adds overrides.

---

## 3. Audio event taxonomy

`<category>.<subject>.<action>` — ids are data keys; files follow §9 naming.

| Category | Examples | Bus | Priority |
|---|---|---|---|
| `warn` boss telegraphs | `warn.boss.windup`, `warn.boss.imminent`, `warn.boss.recovery`, `warn.terrain.vent` | Warning | Critical / High |
| `combat` | `combat.hit.player`, `combat.hit.enemy`, `combat.interrupt` (NGẮT!), `combat.parry`, `combat.crit`, `combat.death`, `combat.hp_low` | SFX | High / Normal |
| `skill` (phases, §4) | `skill.<card>.windup`, `.charge`, `.commit`, `.travel`, `.impact`, `.impact_final`, `.aftermath`, `.cancel`, `.fizzle` | Skill | Normal (impact High) |
| `move` | `move.hero.step`, `move.boss.step`, `move.dash` | SFX | Low |
| `block` | `block.pickup`, `block.select`, `block.rotate`, `block.place`, `block.invalid`, `block.confirm`, `block.slot_full` | UI | Normal |
| `card` | `card.menu_open`, `card.highlight`, `card.choose`, `card.unavailable`, `card.ready` | UI | Normal |
| `status` | `status.burn.ignite`, `status.burn.loop`, `status.pin`, `status.frost`, `status.awaken_ready` | SFX | Low / Normal |
| `ui` | `ui.tap`, `ui.back`, `ui.toggle`, `ui.map_node`, `ui.reward`, `ui.achievement` | UI | Normal |
| `flow` | `flow.victory`, `flow.defeat`, `flow.boss_intro`, `flow.phase_change` | Music (stingers) | High |
| `amb` | `amb.<region>.loop`, `amb.<region>.oneshot` | Ambience | Low |
| `music` | `music.<region>.explore/battle`, `music.boss.<id>` | Music | — |

---

## 4. Skill audio phases and synchronization

| Phase | Trigger (authoritative source) | Notes |
|---|---|---|
| 1 Anticipation / wind-up | `swing_started` | may follow the animation |
| 2 Channeling / charging | Commitment CHANNELING, or a scheduled field's life (`cast_scheduled` → `at`) | loops stop on the phase end, never on a clip frame |
| 3 Commitment / release | swing end = `cast_scheduled` (Ngàn Kiếm: COMMIT) | — |
| 4 Projectile / scheduled effect | event times from `cast_scheduled` | pre-scheduled on the arbiter clock |
| 5 Impact / explosion | **body** pre-scheduled at the event `at`; **hit layer** on `impact_resolved(hit=true)` | the body plays hit or miss; the hit layer confirms the hit |
| 6 Aftermath | zone creation (`ignite`, embers) / end (zone expiry) | culled first under load |
| 7 Cancel / interrupt | `swing_cancelled`, `swing_interrupted`, Commitment CANCELLED, fizzle | distinct from a miss |

Rules:
- **Gameplay timing never comes from audio or animation.** Audio reads `cast_scheduled` / `impact_resolved` only.
- **Latency lead:** scheduled bodies are started at `at − AudioServer.get_output_latency()` (clamped 0–80 ms) so the
  transient lands on the impact tick on Android; un-scheduled cues (hits, UI) play at once.
- **Time scale:** cues follow the arbiter clock, so Focus slow-motion and the card menu's time scale apply; pitch is
  not bent by time scale (readability).

---

## 5. Reference skill audio storyboards

Times relative to the authoritative events; distinct sound families: **Trảm Địa = earth and grinding steel, low and
heavy; Ngàn Kiếm = bright resonant steel, high and glassy; Hỏa Lôi = ember crackle, rising pressure, deep whump.**

### 5.1 Trảm Địa (approved; swing 0.2 + 0.25 × cells)

| t | Beat | Sound | Event |
|---|---|---|---|
| `swing_started` → swing end | blade lowered, coil | low steel scrape + a short breath of tension (rising 1 semitone) | `skill.tram_dia.windup` |
| swing end | release, wave launches | heavy whoosh with a gritty floor-drag tail | `skill.tram_dia.commit` |
| travel to first cell | wave skims the floor | short grinding rumble, follows the scheduled arrival | `skill.tram_dia.travel` |
| first-cell event | big steel eruption (burst) | deep thud + split-rock crack + bright steel ring (largest layer) | `skill.tram_dia.impact_final` (tier L) |
| each surge step | smaller bursts cell by cell | small rock cracks, pitch +1 step per cell, −3 dB each | `skill.tram_dia.impact` (tier S) |
| +0.4 s | stamps fade, shards settle | pebble trickle, steel ring decay | `skill.tram_dia.aftermath` |

### 5.2 Ngàn Kiếm (approved prototype; channel 1.48–1.73 s)

| t | Beat | Sound | Event |
|---|---|---|---|
| channel start | sword raised; fragments gather above the tiles | soft metallic tinkles **at the tiles** (small, staggered with the summon records `t0 = raise + i × 0.06`) | `skill.ngan_kiem.charge` |
| channel, swords assembled | hovering swords | a sustained, quiet steel resonance (hum + shimmer), loops until the commit | `skill.ngan_kiem.channel_loop` |
| commit (pull-down) | the command | sharp downward "shing" + air cut, short, dry | `skill.ngan_kiem.commit` |
| each drop (`at`, 0.12 s apart) | swords stab | blade whistle (very short) + stab into stone; pitch varies per drop | `skill.ngan_kiem.impact` |
| `drop_final` (×1.5) | centre blade | heavier stab + stone crack + ring | `skill.ngan_kiem.impact_final` |
| CANCELLED | swords disperse | resonance cut off with a descending glassy scatter; ĐÃ HỦY | `skill.ngan_kiem.cancel` |
| commit refused (ĐÃ CHỐT) | — | a dull locked click (UI) | `card.unavailable` |

No sound suggests a beam to the sky: no rising laser, no upward sweep from the Knight; every gather sound sits on
the tiles.

### 5.3 Hỏa Lôi (proposed, see `09-hoa-loi-design.md`)

| t | Beat | Sound | Event |
|---|---|---|---|
| `swing_started` (0.45 s) | book, glyph | page flick + small ember spark | `skill.hoa_loi.windup` |
| swing end | seals burn into the slabs | a low "brand" sizzle at each seal (one merged sound, size tier by cell count) | `skill.hoa_loi.seal` |
| fuse | seals charge 3-2-1 | a soft crackle bed + **3 rising ticks**, one per countdown step, pitched up each step | `skill.hoa_loi.charge`, `.tick` |
| last 0.3 s | final pulse | short pressure inhale (rising hiss) — the escalating warning | `skill.hoa_loi.prime` |
| detonation (`at`) | columns erupt together | deep whump + roaring flame burst; **one** sound for all seals, tier S/M/L by cell count; hit layer on hit | `skill.hoa_loi.impact` |
| burning cells | aftermath | quiet crackling loop per field (max 1 loop per field) | `status.burn.loop` |
| burn expiry | embers out | soft hiss-out | `skill.hoa_loi.aftermath_end` |
| fizzle (locked cell) | no fire | small dry pop | `skill.hoa_loi.fizzle` |

---

## 6. Tactical readability and warning priorities

| Cue | Sound | Priority | Visual counterpart (exists?) |
|---|---|---|---|
| Boss wind-up | low drum hit + cloth/armour shift | High | windup pose / tell (yes) |
| Boss imminent attack (WARNING last 0.5 s) | 2-note rising alarm, mid frequencies (1–3 kHz) | **Critical** | red stripe telegraph + countdown (yes) |
| Boss recovery opportunity | soft descending exhale "opening" chime | Normal | needs a recovery indicator on the boss (**gap**: no RECOVERY signal or marker today) |
| Player channeling | the skill's charge loop | Normal | dimmed joystick, Hủy (yes) |
| Successful commitment | short bright lock "clink" | Normal | ĐÃ CHỐT (yes) |
| Interrupted cast (NGẮT!) | broken whoosh + thud | High | NGẮT! text (yes) |
| Voluntary cancellation | descending scatter | Normal | ĐÃ HỦY (yes) |
| Skill ready | soft tone per card leaving cooldown (rate-limited 1 / 0.5 s) | Low | card face (yes) |
| Skill unavailable | dull click | Normal | greyed card (yes) |
| Player hit / low HP | body hit; low-HP heartbeat under 25 % | High | HP bar flash (yes) |

Priority classes: **Critical** (never culled; ducks Skill/SFX −6 dB and Music −8 dB for 0.4 s), **High** (steals
Low/Normal voices), **Normal**, **Low** (culled first). Boss warnings use the Warning bus, which is never ducked.
Every critical cue has a visual counterpart; playing muted loses nothing essential (HUD spec rule). No cue lives
only above 4 kHz (accessibility). Optional vibration on Critical cues (setting, default on, per accessibility doc).

---

## 7. Block / UI feedback sounds

| Action | Sound | Note |
|---|---|---|
| pick up a Block (slot filled) | stone clack | per Block size: 3 pitch tiers |
| select from bag | light lift | — |
| drag over valid / invalid cells | silent / one muted buzz on first invalid hover | no spam while dragging |
| place | firm stone set | — |
| confirm | two-stone lock | — |
| bag full / pickup blocked | dull knock | — |
| card menu open | paper flip / rune hum | time scale already slows |
| card highlight / choose | soft tick / bright confirm | — |
| map node, reward, achievement plate | UI family (wood / stone, not sci-fi) | — |

---

## 8. Music and ambience direction

Direction: melancholic high fantasy, small ensemble (solo strings, low winds, harp / dulcimer, frame drum, soft
choir pad), modal (Dorian / Aeolian), slow 70–90 bpm in exploration. "Nhạc orchestral nhẹ" from the brief. Combat
music keeps **mid frequencies (1–4 kHz) sparse** so warnings sit there; rhythm lives in low drums, melody in a
narrow register.

| Use | Structure |
|---|---|
| Exploration / climb map | region theme, sparse, 2–3 min loop |
| Normal battle | same theme as **stems** (pad, rhythm, melody); battle adds the rhythm stem — crossfade, no restart |
| Boss battle | boss stem set; phase change adds a layer; last 25 % HP adds percussion |
| Victory / defeat stingers | 3–5 s; victory resolves to major, defeat a falling minor phrase |
| Ambience | per-region loops + rare one-shots, under music, culled first |

| Region (repo) | Ambience palette | Music colour |
|---|---|---|
| Rừng Sương / forest | wind in leaves, distant birds, drip | harp + flute, mist pad |
| Dungeon | stone room tone, water drips, chains | low strings, slow drum |
| Ice tower | wind howl, ice creak | glass harmonics, celesta |
| Swamp | frogs, bubbles, insects | low clarinet, detuned plucks |
| Sands (desert) | dry wind, sand hiss | oud-like plucks, frame drum |
| Hellfire (citadel) | distant fire roar, rumble | brass drones, war drums |
| Sky isles (floating islands) | high wind, wind chimes | airy choir, harp |
| Lattice heart (summit) | resonant hum, crystalline tones | full ensemble, the main theme |

---

## 9. Mixing, mobile performance, production workflow

**Buses** (`default_bus_layout.tres`): Master (limiter −1 dBTP) ← Music, Ambience, SFX (← Skill, Combat), UI,
Warning. Ducking: compressors on Music and SFX side-chained to Warning.

**Mobile:**
- Settings sliders: **Master, Music, SFX, UI, Ambience** (0–100 %, default 80 %), in Settings **and** Pause
  (accessibility requires at least Music + Effects); a **Reduced audio** toggle (drops ambience one-shots,
  aftermath loops and skill-ready tones; keeps warnings).
- Voice limits: total 24; Skill 8, Combat 6, UI 4, Warning 2 (reserved), Ambience 2 loops + 2 one-shots, Music
  streams separate.
- Same-event cooldown 30–60 ms; **size tiers** instead of stacking: one Hỏa Lôi detonation of 5 cells plays one L
  sound, not five; Ngàn Kiếm drops are staggered by design but capped at 3 overlapping.
- Variation: `AudioStreamRandomizer` (2–4 variants, ±1.5 semitone, ±2 dB).
- Pooling: the `VoicePool` pre-creates players; no node creation per sound.
- Latency: lead compensation (§4); keep SFX short and transient-first.
- Formats: SFX **WAV mono 44.1 kHz, imported as QOA** (cheap decode, small); music and ambience **Ogg Vorbis**
  stereo, streamed, 96–128 kbps, loop points set on import.
- Memory budget: SFX bank ≤ 6 MB decoded; music streamed.
- Pause / background: on `paused_changed` and `NOTIFICATION_APPLICATION_PAUSED` pause combat voices and fade music
  to −12 dB; resume on return; nothing plays while backgrounded.

**Loudness:** music −16 LUFS integrated; ambience −24 LUFS; SFX peaks ≤ −3 dBFS, warnings mixed 3 dB above the
skill bed; master limiter catches the rest.

**Workflow:**
- Original sound design in a free DAW (Reaper evaluation / Audacity), layering recorded foley (stone, metal, paper,
  cloth) + synthesis.
- Procedural tools where it fits (UI, ticks, placeholders): sfxr / jsfxr / ChipTone (free, output usable without
  credit).
- Libraries: only royalty-free with clear terms (e.g. Sonniss GDC bundles, CC0 on Freesound); **no CC-NC**, no
  unlicensed or ripped game audio.
- AI generators (e.g. ElevenLabs SFX, Stable Audio): **paid**, used only after an explicit yes per batch and a
  licence check; not needed for the MVP placeholders.
- Music: a composer commission or an owned composition; licence must allow commercial mobile use.
- Naming: `sfx_<category>_<subject>_<action>_<nn>.wav`, `mus_<region>_<state>.ogg`, `amb_<region>_<loop|os>_<nn>.ogg`.
- Folders: `assets/audio/{sfx,music,ambience,ui}`; sources (DAW sessions, raw recordings) in `audio_src/` (not
  exported); `assets/audio/CREDITS.md`: one line per file (source, licence, author, edits).
- Version control: exported files in git (small); large raw sources outside git or in LFS (decision D7).

---

## 10. File-by-file implementation plan

| File | Kind | Change |
|---|---|---|
| `default_bus_layout.tres` | new | buses, limiter, side-chain compressors |
| `assets/data/audio_events.json` | new | events, archetypes, card overrides, voice caps |
| `src/audio/audio_event_rules.gd` | new | pure signal → event mapping |
| `src/audio/audio_bank.gd` | new | load / validate / fallback |
| `src/audio/voice_pool.gd` | new | pooled players, caps, priority, cooldown, tiers |
| `src/audio/audio_director.gd` | new | play now / at arbiter time, ducking, pause, silent mode |
| `src/audio/music_player.gd` | new | stems and crossfades, stingers, ambience |
| `src/audio/combat_audio_bridge.gd`, `ui_audio_bridge.gd`, `flow_audio_bridge.gd` | new | listen and post |
| `src/combat/pattern_controller.gd` | extension | `stage_changed(stage, skill_id)` signal (WINDUP, RECOVERY) |
| `src/combat/combat_view.gd` | extension | `piece_selected`, `piece_placed`, `placement_confirmed`, `channel_phase_changed` signals |
| `src/combat/cut_flow.gd` | extension | `menu_opened`, `card_highlighted` |
| `src/settings/settings_store.gd` | extension | 5 volumes, reduced audio, vibration |
| `src/run/settings_view.gd`, pause menu | extension | sliders and toggles |
| `assets/i18n/strings.csv` | extension | setting labels vi/en |
| `src/run/game_flow.gd` / `run_controller.gd` | extension | create the director, pass it in; pause hooks |
| `tools/balance/sim_core.gd` | none | runs with audio silent (no bridge) |

---

## 11. Audio QA and synchronization tests

| Test | Level | Checks |
|---|---|---|
| `audio_bank_test` | unit | every event id resolves; files exist; buses exist; archetype fallback for all 36 cards |
| `audio_event_rules_test` | unit | each combat / UI signal maps to the right ids; cancel ≠ miss; tiers by cell count |
| `voice_pool_test` | unit | caps per category; Critical never culled; Low stolen first; 5 same-tick impacts → 1 tiered voice |
| `combat_audio_sync_test` | integration | scheduled bodies start at `at − lead` on the arbiter clock for Trảm Địa, Ngàn Kiếm (and Hỏa Lôi later); hit layer only when `impact_resolved(hit)`; Ngàn Kiếm cancel plays the cancel cue and no impact |
| `audio_pause_test` | integration | pause / background stops combat voices; resume restores |
| `settings_audio_test` | unit | volumes saved, defaults 80 %, applied to buses; never writes the real settings file |
| golden / regression | suite | gameplay events identical with audio on and off |
| device check | manual | latency on Android (tap-to-sound), loudness, no clipping with 5 impacts + warning |

---

## 12. Estimated asset inventory (MVP)

| Group | Count (× variants) |
|---|---|
| UI + Block + card | ~22 (× 2) |
| Movement + generic combat (hits, interrupt, parry, crit, death, low HP) | ~15 (× 3) |
| Boss warnings (shared) + per-boss signature sounds | ~8 shared + ~2 per boss |
| Skill archetypes (delivery × impact × phase, shared by most cards) | ~30 (× 3) |
| Reference skills (Trảm Địa, Ngàn Kiếm, Hỏa Lôi) | ~22 (× 2–3) |
| Statuses / hazards (burn, pin, frost, thorns, vents, crumble) | ~12 |
| Stingers (victory, defeat, boss intro, phase) | 4–6 |
| Music | MVP 4 (title/map, battle stems, boss stems, one region set); full 8 regions + bosses later |
| Ambience | 8 region loops + ~16 one-shots |

Roughly **110 SFX** (~300 files with variants), 4–14 music pieces, 8 ambience beds.

---

## 13. Roadmap integration

| Phase | Content | Audio work in it |
|---|---|---|
| 1 Combat audit | done (`01-current-system-audit.md`) | audio audit (this document §1) |
| 2 Skill v2 design | done (02 docs) | — |
| 3 Reference skills: mechanics, animation, VFX | Trảm Địa ✔, Ngàn Kiếm ✔, Hỏa Lôi (proposed) | **run alongside:** missing signals (`stage_changed`, piece / menu signals), `AudioEventRules` + `VoicePool` + silent director with tests, bus layout, settings sliders, **placeholder sfxr cues** for the three reference skills to validate timing, warnings and readability during their playtests |
| 4 Shared Audio System + reference skill sound design | full director, music / ambience players, final sounds for warnings, UI, Blocks and the 3 reference skills, Android latency check | — |
| 5 Expansion toward the 60-card MVP | batches B2–B7 | each card ships with archetype audio (no new code); hero cards add overrides |
| 6 Balancing, Android optimization, human playtesting | sim, device QA, playtests | loudness / voice-limit tuning on device; muted-play check |

---

## 14. Decisions requiring approval

| # | Decision | Recommendation |
|---|---|---|
| A1 | Architecture: data-driven events + pure rules + voice pool + director, listening only | **Yes** |
| A2 | Buses: Master / Music / Ambience / SFX (Skill, Combat) / UI / Warning, warnings never ducked | **Yes** |
| A3 | Five sliders + Reduced audio + vibration (beyond the accessibility minimum of two) | **Yes** |
| A4 | Formats: WAV→QOA for SFX, Ogg streamed for music / ambience | **Yes** |
| A5 | Start Phase 3 audio tasks now (signals, rules, pool, buses, placeholders) | **Yes**, alongside Hỏa Lôi |
| A6 | Sourcing: original + free procedural + royalty-free CC0 only; paid AI SFX only with a yes per batch | **Yes** |
| A7 | Large raw audio sources: outside git (or Git LFS) | outside git for now |
| A8 | Music: commission vs. own composition; MVP 4 pieces first | decide before Phase 4 |
| A9 | Recovery-window indicator (visual + sound) for bosses — a new HUD element | design it with the boss telegraph team; needed for Hỏa Lôi's counterplay too |
