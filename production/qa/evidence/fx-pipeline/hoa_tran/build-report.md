# fxc build: hoa_tran (Fire Mage - Square Flame Impact (prototype 2))

## gather_flame_charcoal

gather_flame_charcoal: square_gather, 8 frames x 50 ms, 72x56, floor

```
  info stats: 8 frames x 50 ms = 400 ms, 72x56, up to 10 clusters a frame, 0 single-px specks in all
```

## gather_flame_charcoal_c43x31

gather_flame_charcoal_c43x31: square_gather, 8 frames x 50 ms, 50x38, floor

```
  info stats: 8 frames x 50 ms = 400 ms, 50x38, up to 10 clusters a frame, 0 single-px specks in all
```

## impact_flame_burn

impact_flame_burn: flame_burst, 7 frames x 50 ms, 94x116, overlay

```
  info stats: 7 frames x 50 ms = 350 ms, 94x116, up to 17 clusters a frame, 0 single-px specks in all
```

## impact_flame_burn_c43x31

impact_flame_burn_c43x31: flame_burst, 7 frames x 50 ms, 62x80, overlay

```
  info stats: 7 frames x 50 ms = 350 ms, 62x80, up to 18 clusters a frame, 0 single-px specks in all
```

## mark_embers_burn

mark_embers_burn: square_mark, 7 frames x 50 ms, 64x46, floor

```
  info stats: 7 frames x 50 ms = 350 ms, 64x46, up to 4 clusters a frame, 0 single-px specks in all
```

## mark_embers_burn_c43x31

mark_embers_burn_c43x31: square_mark, 7 frames x 50 ms, 44x32, floor

```
  info stats: 7 frames x 50 ms = 350 ms, 44x32, up to 4 clusters a frame, 0 single-px specks in all
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
   "to": 1.45
  },
  {
   "what": "impact first cell [1, 0]",
   "at": 1.45
  },
  {
   "what": "impact spread cell [0, 1]",
   "at": 1.45
  },
  {
   "what": "impact spread cell [1, 1]",
   "at": 1.45
  },
  {
   "what": "impact spread cell [2, 1]",
   "at": 1.45
  },
  {
   "what": "impact spread cell [1, 2]",
   "at": 1.45
  }
 ],
 "ends": 1.45,
 "hit": {
  "unit": "goblin_scout",
  "at": 1.45,
  "flash_sec": 0.1,
  "shake_px": 2,
  "freeze_sec": 0
 }
}
```

