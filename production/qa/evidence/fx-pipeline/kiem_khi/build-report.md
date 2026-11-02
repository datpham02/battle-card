# fxc build: kiem_khi (Knight - Square Sword Wave (prototype 1))

## release_square_slash_steel

release_square_slash_steel: square_slash, 4 frames x 50 ms, 86x28, overlay

```
  info stats: 4 frames x 50 ms = 200 ms, 86x28, up to 5 clusters a frame, 0 single-px specks in all
```

## travel_square_wave_steel

travel_square_wave_steel: square_wave, 4 frames x 50 ms, 72x54, overlay

```
  info stats: 4 frames x 50 ms = 200 ms, 72x54, up to 18 clusters a frame, 0 single-px specks in all
```

## impact_burst_big_steel

impact_burst_big_steel: square_burst, 7 frames x 50 ms, 106x88, overlay

```
  info stats: 7 frames x 50 ms = 350 ms, 106x88, up to 10 clusters a frame, 0 single-px specks in all
```

## impact_burst_big_steel_c43x31

impact_burst_big_steel_c43x31: square_burst, 7 frames x 50 ms, 72x66, overlay

```
  info stats: 7 frames x 50 ms = 350 ms, 72x66, up to 12 clusters a frame, 0 single-px specks in all
```

## impact_burst_small_steel

impact_burst_small_steel: square_burst, 5 frames x 50 ms, 106x74, overlay

```
  info stats: 5 frames x 50 ms = 250 ms, 106x74, up to 7 clusters a frame, 0 single-px specks in all
```

## impact_burst_small_steel_c43x31

impact_burst_small_steel_c43x31: square_burst, 5 frames x 50 ms, 72x56, overlay

```
  info stats: 5 frames x 50 ms = 250 ms, 72x56, up to 6 clusters a frame, 0 single-px specks in all
```

## mark_stamp_big_steel

mark_stamp_big_steel: square_mark, 9 frames x 50 ms, 64x46, floor

```
  info stats: 9 frames x 50 ms = 450 ms, 64x46, up to 8 clusters a frame, 0 single-px specks in all
```

## mark_stamp_big_steel_c43x31

mark_stamp_big_steel_c43x31: square_mark, 9 frames x 50 ms, 44x32, floor

```
  info stats: 9 frames x 50 ms = 450 ms, 44x32, up to 8 clusters a frame, 0 single-px specks in all
```

## mark_stamp_small_steel

mark_stamp_small_steel: square_mark, 7 frames x 50 ms, 64x46, floor

```
  info stats: 7 frames x 50 ms = 350 ms, 64x46, up to 4 clusters a frame, 0 single-px specks in all
```

## mark_stamp_small_steel_c43x31

mark_stamp_small_steel_c43x31: square_mark, 7 frames x 50 ms, 44x32, floor

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
   "to": 1.2
  },
  {
   "what": "travel hand -> first cell",
   "from": 1.05,
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

