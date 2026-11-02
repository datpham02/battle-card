# fxc build: branch_lattice (Forest Witch - Root Propagation (prototype 3))

## windup_gather_ivory

windup_gather_ivory: square_gather, 8 frames x 50 ms, 40x40, overlay

```
  info stats: 8 frames x 50 ms = 400 ms, 40x40, up to 5 clusters a frame, 0 single-px specks in all
```

## root_crawl_wood_from_e

root_crawl_wood_from_e: root_crawl, 14 frames x 50 ms, 64x46, floor

```
  info stats: 14 frames x 50 ms = 700 ms, 64x46, up to 2 clusters a frame, 0 single-px specks in all
```

## root_crawl_wood_from_w

root_crawl_wood_from_w: root_crawl, 14 frames x 50 ms, 64x46, floor

```
  info stats: 14 frames x 50 ms = 700 ms, 64x46, up to 2 clusters a frame, 0 single-px specks in all
```

## root_crawl_wood_from_n

root_crawl_wood_from_n: root_crawl, 14 frames x 50 ms, 64x46, floor

```
  info stats: 14 frames x 50 ms = 700 ms, 64x46, up to 2 clusters a frame, 1 single-px specks in all
```

## root_crawl_wood_from_s

root_crawl_wood_from_s: root_crawl, 14 frames x 50 ms, 64x46, floor

```
  info stats: 14 frames x 50 ms = 700 ms, 64x46, up to 2 clusters a frame, 1 single-px specks in all
```

## root_crawl_wood_from_e_c45x39

root_crawl_wood_from_e_c45x39: root_crawl, 14 frames x 50 ms, 46x40, floor

```
  info stats: 14 frames x 50 ms = 700 ms, 46x40, up to 2 clusters a frame, 1 single-px specks in all
```

## root_crawl_wood_from_w_c45x39

root_crawl_wood_from_w_c45x39: root_crawl, 14 frames x 50 ms, 46x40, floor

```
  info stats: 14 frames x 50 ms = 700 ms, 46x40, up to 2 clusters a frame, 1 single-px specks in all
```

## root_crawl_wood_from_n_c45x39

root_crawl_wood_from_n_c45x39: root_crawl, 14 frames x 50 ms, 46x40, floor

```
  info stats: 14 frames x 50 ms = 700 ms, 46x40, up to 2 clusters a frame, 3 single-px specks in all
```

## root_crawl_wood_from_s_c45x39

root_crawl_wood_from_s_c45x39: root_crawl, 14 frames x 50 ms, 46x40, floor

```
  info stats: 14 frames x 50 ms = 700 ms, 46x40, up to 2 clusters a frame, 3 single-px specks in all
```

## root_spike_wood

root_spike_wood: root_spike, 7 frames x 50 ms, 84x84, overlay

```
  info stats: 7 frames x 50 ms = 350 ms, 84x84, up to 6 clusters a frame, 0 single-px specks in all
```

## root_spike_wood_c45x39

root_spike_wood_c45x39: root_spike, 7 frames x 50 ms, 60x74, overlay

```
  info stats: 7 frames x 50 ms = 350 ms, 60x74, up to 5 clusters a frame, 0 single-px specks in all
```

## timeline

```json
{
 "sequence": "enemy_skill",
 "t0": "0 = the timeline's action start (pre_sec trimmed)",
 "events": [
  {
   "what": "windup (holds still, ivory squares at the hand)",
   "from": 0.0,
   "to": 0.5
  },
  {
   "what": "warning: red cells darken",
   "from": 0.5,
   "to": 1.7
  },
  {
   "what": "root reaches cell [5, 2] from e, spike",
   "at": 1.7
  },
  {
   "what": "root reaches cell [4, 2] from e, spike",
   "at": 1.76
  },
  {
   "what": "root reaches cell [4, 1] from s, spike",
   "at": 1.82
  },
  {
   "what": "followup warning",
   "from": 1.7,
   "to": 2.45
  },
  {
   "what": "root reaches cell [3, 1] from e, spike",
   "at": 2.45
  }
 ],
 "ends": 2.45,
 "hit": {
  "unit": "kiem_si",
  "at": 1.76,
  "flash_sec": 0.1,
  "shake_px": 2,
  "freeze_sec": 0
 }
}
```

