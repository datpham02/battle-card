# Android real-device QA — Skill v2 (pending)

**Status:** PENDING for `tram_dia` (Trảm Địa). Desktop 2× and native 640×360 renders are verified; no phone build has
been run. Fill in one row per device run; keep the screenshots / screen recording next to this file
(`production/qa/evidence/android-skill-v2/`).

## Devices to cover

- Low-end Android (720p or lower screen, Mali / Adreno 5xx class GPU).
- A mid-range phone at 1080p (the reference).
- A tall 20:9 screen with a notch / cutout (safe area).

## Checks for Trảm Địa

| # | Check | Pass when |
|---|---|---|
| 1 | Pick and cast | Placing a 3+ cell Block and tapping Trảm Địa in the menu works by touch alone |
| 2 | Wind-up preview | The landing corners, step chevrons and blocked X read at arm's length during `cast_forward`'s coil |
| 3 | Release sync | The wave leaves the blade on the release frame; no visible pop or slide of the Knight's feet |
| 4 | Eruption readability | The burst-cell eruption reads as steel blades rising up and forward and is clearly heavier than the surge bursts; no smear or blur (nearest filtering) |
| 5 | Surge order | On straight, L, T and Plus Blocks, the fronts follow the Block and the boss is hit when the front reaches it |
| 6 | Telegraph safety | Enemy red warnings stay readable during and after the eruption (overlay ≤ 0.35 s) |
| 7 | Performance | No frame drop below 60 fps (or the device's target) during the cast; note the GPU time if a drop shows |
| 8 | Text | The card's battle text fits (vi / en) at the device's real width |
| 9 | Pause / focus | Backgrounding the app mid-surge and returning does not double-apply damage or leave VFX stuck |

## Runs

| Date | Device / OS | Build | Result | Notes / evidence |
|---|---|---|---|---|
| — | — | — | PENDING | — |
