# Story 032 — Relic simulation (Phần E "Mô phỏng")

**Date**: 2026-10-25 · **Tool**: `tools/balance/deck_sim.gd --world` (Story 031 world run: 5 floors + final), build policy.
**Raw output**: `simulation-relics-raw.txt` (same folder). It holds every run, including the follow-up runs.

## How it was measured

- **Configs.** Each config × character ran as its own process: `--world --seeds=70 --characters=<c>`.
  - `baseline`: no relics.
  - Each of the 16 relics alone: `--relics=<id>`. The bot owns the relic from the start of the run, and the relic is in every match.
  - The 3 pairs.
  - `--relic-policy=pick`: no starting relic. At a treasure node the bot takes the relic row, rarest first.
- **Seeds.** 70 seeds × 3 characters for every config, as specified. The 40-seed fallback was not needed. Seeds 1..70 are the same in every config, so region paths and match seeds match until a run diverges.
- **How relics reach the sim.** `sim_core.relic_ids` is set per match from the run's relic list. `sim_core._relic_config_overrides` / `_setup_relics` port `CombatView._setup_relics` as written by the combat wave (checked against `src/combat/combat_view.gd` at 19:52):
  - `RelicRegistry.instantiate` and `merge_overrides`.
  - The status keys go into the match's CombatConfig copy before `configure_status`.
  - Drop overrides follow `_apply_drop_overrides`: a non-positive result keeps the config value.
  - The bag slot count, Focus, FormationMap fade and signature cooldown are applied where each object is built.
  - `arbiter.player_zone_overrides` (seal / thorn after the card's own value).
  - The ONE damage point is `arbiter.player_relic_modifier` (after featured, before passive). It uses `fold_damage` with the 3.0 cap.
  - The ONE windup point is `CutActor.cast_time_modifier`.
  - `an_chu` replaces the featured `damage_mult`.
  - `on_cast_landed` / `on_join` / `on_interrupt_by_player` are called at the same points as in CombatView.
  - `heal_player`, `damage_player` and `give_piece` work as in CombatView.
- **Bot assumptions.**
  - Dodge 0.85 is the TD-006 legacy default and has not been re-anchored on a playtest.
  - Other defaults: hold=1 (casts with 1 placeable piece), join 1.0, aim 0.9, counter 0.5, place 1.2 s / join 1.0 s / choose 0.8 s real.
  - With `tam_hop`, the bot tries one more greedy join (same scoring) while the plan has room.
  - With `pick`, the bot takes the rarest relic offered. This includes the `negative` `huyet_an`, and the bot never compares it with the card row.
  - Node overhead is 25 s per node (Story 031 assumption).
- **Noise.** Each relic run is compared with its own 70-seed baseline. After the first changed event, a run's trajectory is effectively independent. At p ≈ 0.25, the standard error of a single-character Δ is about **±7 points**, and of the 3-character mean about **±4 points**. The **−3 point** "useless" threshold is therefore below what 70 seeds can resolve, and the +12 threshold is only resolved for the mean.
  - Example: the kiem_si baseline is 30.0 % at 70 seeds and **23.8 %** at 210 seeds.
  - Single-character values below are read as "clearly beyond noise" only when |Δ| ≥ ~15.

## Result table: run win % (Δ vs baseline), 70 seeds per character

| Config | Rarity | kiem_si | phap_su | sat_thu | mean Δ | Flag |
|---|---|---|---|---|---|---|
| baseline | | 30.0 | 18.6 | 5.7 | | |
| an_don | common | 37.1 (+7.1) | 21.4 (+2.8) | 8.6 (+2.9) | +4.3 | |
| chi_khau | common | 30.0 (+0.0) | 20.0 (+1.4) | 7.1 (+1.4) | +0.9 | |
| phong_an | common | 32.9 (+2.9) | 21.4 (+2.8) | 4.3 (−1.4) | +1.4 | |
| gai_ran | common | 30.0 (+0.0) | 18.6 (+0.0) | 5.7 (+0.0) | +0.0 | inert in sim |
| manh_tuoi | common | 22.9 (−7.1) | **44.3 (+25.7)** | 11.4 (+5.7) | +8.1 | **VIOLATION > +12 (phap_su)** |
| dinh_tam | common | 30.0 (+0.0) | 18.6 (+0.0) | 5.7 (+0.0) | +0.0 | inert in sim |
| la_ban | rare | 32.9 (+2.9) | 22.9 (+4.3) | 11.4 (+5.7) | +4.3 | |
| tam_huong | rare | 28.6 (−1.4) | 15.7 (−2.9) | 5.7 (+0.0) | −1.4 | |
| tui_rong | rare | **2.9 (−27.1)** | **2.9 (−15.7)** | 0.0 (−5.7) | **−16.2** | **VIOLATION: lowers by > 3** |
| dau_than | rare | 30.0 (+0.0) | 18.6 (+0.0) | 5.7 (+0.0) | +0.0 | inert in sim |
| khoi_the | rare | 31.4 (+1.4) | 28.6 (+10.0) | 8.6 (+2.9) | +4.8 | |
| phan_don | rare | **44.3 (+14.3)** | 25.7 (+7.1) | 2.9 (−2.8) | +6.2 | borderline (> +12 on kiem_si; see 210-seed check) |
| han_ky | epic | 31.4 (+1.4) | 22.9 (+4.3) | 8.6 (+2.9) | +2.9 | |
| huyet_an | epic, negative | 1.4 (−28.6) | 0.0 (−18.6) | 0.0 (−5.7) | −17.6 | outside the targets (epic); trap, see below |
| an_chu | boss | 31.4 (+1.4) | 20.0 (+1.4) | 5.7 (+0.0) | +0.9 | |
| tam_hop | boss | 32.9 (+2.9) | 20.0 (+1.4) | 7.1 (+1.4) | +1.9 | |
| an_don + phan_don | pair | 38.6 (+8.6) | 35.7 (+17.1) | 17.1 (+11.4) | **+12.4** | stacks past +12 on the mean |
| tui_rong + tam_hop | pair | 4.3 (−25.7) | 1.4 (−17.2) | 0.0 (−5.7) | −16.2 | carried by tui_rong |
| la_ban + tam_huong | pair | 31.4 (+1.4) | 22.9 (+4.3) | 10.0 (+4.3) | +3.3 | no stacking |
| relic-policy=pick | policy | 24.3 (−5.7) | 22.9 (+4.3) | 7.1 (+1.4) | −0.0 | rarest-first takes huyet_an in 16–21 of 70 runs |

**Trigger counts per run** (`WORLD RELICS` lines in the raw file):

| Relic | Triggers / run |
|---|---|
| an_don | 6–7 |
| khoi_the | 8.6 |
| chi_khau | 3.5 |
| phan_don | 24.8 |
| huyet_an | 85 |
| an_chu | 0.2 |
| tam_hop | 0.0–0.1 |

The bot almost never fits a featured union or a third piece, so the sim cannot value `an_chu` or `tam_hop`.

`gai_ran`, `dinh_tam` and `dau_than` give **byte-identical** results to baseline. The bot's runs rarely hold a thorns or burn card. Focus is never the bottleneck: the bot's 1.2 s placing ends inside the base Focus. "Δ = 0" here means **the sim cannot measure them**, not that they are useless. They need a playtest.

## Follow-up runs (diagnosis and proposal checks, in memory via `--relic-set`)

| Run | kiem_si | phap_su | sat_thu | Reading |
|---|---|---|---|---|
| baseline, **210 seeds** | 23.8 | | | the 70-seed baseline was +6 high |
| phan_don, **210 seeds** | 34.3 (**+10.5**) | | | under +12 at 3× the seeds: not a confirmed violation |
| tui_rong slots only (`piece_spawn_interval.mul:1.0`) | 28.6 (−1.4) | 18.6 (+0.0) | — | the 4th slot is ~neutral for the bot |
| tui_rong interval only (`hold_slots.add:0`) | 2.9 (−27.1) | 2.9 (−15.7) | — | **the ×1.25 spawn interval alone causes the collapse** |
| tui_rong `piece_spawn_interval.mul:1.1` | 15.7 (−14.3) | 8.6 (−10.0) | 5.7 (+0.0) | still far below baseline |
| manh_tuoi start piece only (`piece_freshness_sec.add:0`) | — | 34.3 (+15.7) | — | **+1 start piece drives the phap_su spike** |
| manh_tuoi freshness only (`start_pieces.add:0`) | 20.0 (−10.0) | 22.9 (+4.3) | 5.7 (+0.0) | mean −1.9; kiem_si negative (see below) |
| an_don + phan_don with `an_don.mult:1.6` | 44.3 (+14.3) | 34.3 (+15.7) | 11.4 (+5.7) | mean +11.9: an_don is not the driver of the pair |
| huyet_an `self_damage:0` | 30.0 (+0.0) | | | the ×1.3 on ≥ 5 cells is worth nothing for the bot |
| huyet_an `self_damage:1` | 8.6 (−21.4) | 1.4 (−17.2) | | the cost alone sinks it |

**Reading.** The world run is **piece-supply bound**: 25 % slower drops (or 10 %) cost 10–27 points, and one extra start piece is worth +16 for phap_su. Both violations come from that one knob.

Longer piece freshness hurts kiem_si in both manh_tuoi runs (−7, −10). One plausible cause, **not verified**: stale pieces occupy the field cap (`piece_max_on_field`) longer and block new spawns.

## Violations and proposals (NOT applied; relics.json is unchanged)

1. **`tui_rong` (rare) lowers win rate by 16 points on the mean.**
   - **Proposal:** `piece_spawn_interval: {mul: 1.25}` → **remove it** (or `mul: 1.0`). Measured slots-only: kiem_si −1.4, phap_su +0.0. sat_thu was not measured slots-only.
   - A ×1.1 interval is still −14 / −10, so there is no safe small slowdown.
   - If the design wants a drawback, it should be a different one, for example a shorter piece freshness (needs measuring).
2. **`manh_tuoi` (common) is +25.7 on phap_su.**
   - **Proposal:** `start_pieces: {add: 1}` → **remove it**, keeping `piece_freshness_sec: {add: 4}`. Measured freshness-only: kiem_si −10.0, phap_su +4.3, sat_thu +0.0, mean −1.9.
   - The start piece is an integer step, so it cannot be tuned smaller. Without it the relic is within the +12 target.
   - kiem_si's −10 is within 1.5 SE of noise, but it repeats the −7 of the full relic. Before shipping, reconfirm with 210 seeds or redesign the freshness part (see the Reading above).
3. **`phan_don` (rare): +14.3 on kiem_si at 70 seeds; +10.5 at 210 seeds.**
   - **No change proposed.** It is not confirmed over +12.
   - Watch the **`an_don + phan_don` pair** (+12.4 mean). Lowering `an_don.mult` to 1.6 only moves it to +11.9, because the pair is driven by phan_don's free pieces. That fits the supply-bound reading.
   - If the pair must come down: limit phan_don per match. This needs a new param and code, so it is the gameplay owner's call.
4. **`huyet_an` (epic, negative) is outside the story's thresholds (common/rare only), but it is a trap** (−17.6 mean). The mult part is worthless to the bot (sd0 = baseline), and even 1 HP per cast sinks it.
   - **Proposal (unverified):** `min_cells: 5 → 4`, `mult: 1.3 → 1.5`, `self_damage: 2 → 1`, OR self-damage only on a hit.
   - The rarest-first bot takes it in about 25 % of pick runs. That is why `relic-policy=pick` nets −0.0.
5. **Inert in the sim:** `gai_ran`, `dinh_tam`, `dau_than` (Δ exactly 0). They do not violate the target, but they are unmeasured. The playtest should judge them.

All other single relics are within +12 / −3 on the 3-character mean.

## Shipped after the simulation (2026-10-25, applied to `relics.json`)

Proposals 1 and 2 were applied; 3–5 were not (no data change).

| Relic | Change | kiem_si | phap_su | sat_thu | mean Δ |
|---|---|---|---|---|---|
| `tui_rong` | `piece_spawn_interval {mul: 1.25}` removed (slots only) | 28.6 (−1.4) | 18.6 (+0.0) | 5.7 (+0.0) | −0.5 |
| `manh_tuoi` | `start_pieces {add: 1}` removed (freshness only) | 20.0 (−10.0) | 22.9 (+4.3) | 5.7 (+0.0) | −1.9 |

Both are now within the story targets on the 3-character mean (+12 / −3). `manh_tuoi` on kiem_si stays −10
(1.5 SE, repeats the −7 of the full relic): flagged for the playtest. `tui_rong` no longer has a drawback;
the brief described one ("mảnh rơi chậm hơn") — a different drawback is a design question. Descriptions
(`relic.tui_rong.desc`, `relic.manh_tuoi.desc`) were updated to match. Raw: `final_*` runs in the session
scratch `relics/` folder, same command as above with `--relics=<id>`.

