# fxc build: phap_su_hoa_cau (Mage - Square Fireball (2026-11-07, user: Mage cast and skill effects first))

## charge_flame_burn

charge_flame_burn: square_gather, 6 frames x 50 ms, 46x46, overlay

```
  info stats: 6 frames x 50 ms = 300 ms, 46x46, up to 7 clusters a frame, 0 single-px specks in all
```

## travel_fireball_burn

travel_fireball_burn: square_fireball, 4 frames x 50 ms, 94x42, overlay

```
  info stats: 4 frames x 50 ms = 200 ms, 94x42, up to 6 clusters a frame, 0 single-px specks in all
```

## impact_flame_small_burn

impact_flame_small_burn: flame_burst, 6 frames x 50 ms, 94x102, overlay

```
  info stats: 6 frames x 50 ms = 300 ms, 94x102, up to 11 clusters a frame, 0 single-px specks in all
```

## impact_flame_small_burn_c43x31

impact_flame_small_burn_c43x31: flame_burst, 6 frames x 50 ms, 62x72, overlay

```
  info stats: 6 frames x 50 ms = 300 ms, 62x72, up to 11 clusters a frame, 0 single-px specks in all
```

## timeline

```json
{
 "sequence": "player_cast",
 "t0": "0 = the timeline's action start (pre_sec trimmed)",
 "events": [
  {
   "what": "swing / charge on the target cells",
   "from": 0.0,
   "to": 1.2
  },
  {
   "what": "travel hand -> first cell",
   "from": 1.0,
   "to": 1.2
  },
  {
   "what": "impact first cell [0, 1]",
   "at": 1.2
  },
  {
   "what": "impact spread cell [1, 1]",
   "at": 1.41
  },
  {
   "what": "impact spread cell [2, 1]",
   "at": 1.49
  },
  {
   "what": "impact spread cell [1, 0]",
   "at": 1.49
  }
 ],
 "ends": 1.49,
 "hit": {
  "unit": "goblin_scout",
  "at": 1.41,
  "flash_sec": 0.1,
  "shake_px": 2,
  "freeze_sec": 0
 }
}
```

