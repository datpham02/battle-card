## Overall (all chapters, 20 matched seeds per encounter)

| set-up | n | win % [95% CI] | mean s ± CI | HL casts/match | chosen when offered | HL hit % [CI] | HL share % (hit+burn) | hit share | burn share | dmg/cast | dmg/hit | armed cells/blast | casts in boss busy |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| BASE | 1460 | 97.3 [96.4–98.0] | 55.5 ± 1.6 | 0.00 | 0% | 0.0 [0.0–0.0] | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.00 | 0% |
| baseline/x2.6 | 1460 | 97.4 [96.4–98.1] | 55.1 ± 1.7 | 5.98 | 97% | 28.8 [27.9–29.8] | 44.5 | 40.0 | 4.5 | 9.7 | 34.0 | 3.68 | 26% |
| predict/x2.6 | 1460 | 97.4 [96.4–98.1] | 53.5 ± 1.6 | 1.92 | 12% | 49.5 [47.6–51.3] | 23.7 | 21.3 | 2.4 | 16.5 | 33.7 | 3.10 | 30% |

## Paired vs BASE (same encounter + seed)

| set-up | pairs | Δ win pts ± CI | Δ mean s ± CI | Δ mean s, mobile | Δ rooted | Δ mixed | Δ multi-cell |
|---|---|---|---|---|---|---|---|
| baseline/x2.6 | 1460 | +0.1 ± 1.0 | -0.47 ± 1.48 | +3.1 ± 3.1 | -5.1 ± 2.2 | +1.0 ± 2.0 | -35.3 ± 5.3 |
| predict/x2.6 | 1460 | +0.1 ± 1.0 | -1.98 ± 1.30 | -0.1 ± 2.9 | -4.6 ± 2.2 | -1.3 ± 1.7 | -17.9 ± 4.8 |

## By archetype: HL share % / hit % / Δ s vs BASE

Encounters: mixed 33, mobile 24, multi-cell 2, rooted 14 (mobile >= 66.3 steps/min, rooted >= 21% busy)

| set-up | mobile | rooted | mixed | multi-cell |
|---|---|---|---|---|
| baseline/x2.6 | 33% / 16% | 50% / 55% | 35% / 25% | 79% / 89% |
| predict/x2.6 | 18% / 31% | 24% / 74% | 21% / 50% | 41% / 94% |

## By chapter: mean s (Δ vs BASE) / HL share %

| set-up | ch1 | ch2 | ch3 | an_dai | swamp | desert | hellfire | sky_isles |
|---|---|---|---|---|---|---|---|---|
| BASE | 58 | 39 | 48 | 100 | 58 | 58 | 53 | 70 |
| baseline/x2.6 | 52 (-7) / 58% | 40 (+0) / 40% | 44 (-4) / 35% | 96 (-4) / 31% | 60 (+2) / 43% | 63 (+4) / 31% | 54 (+1) / 37% | 74 (+4) / 28% |
| predict/x2.6 | 54 (-5) / 29% | 37 (-2) / 28% | 43 (-5) / 22% | 91 (-9) / 17% | 61 (+3) / 25% | 59 (+1) / 15% | 53 (+0) / 15% | 67 (-3) / 19% |

## Square (2x2 clause) vs ordinary fields — blasts, hit %, dmg/hit

| set-up | square: all | square vs 1-cell boss | square vs 2x2 boss | square vs mobile | square vs rooted | ordinary: all | ordinary vs 1-cell | ordinary vs 2x2 |
|---|---|---|---|---|---|---|---|---|
| baseline/x2.6 | 646 / 27% / 43.2 | 610 / 24% / 36.3 | 36 / 89% / 74.5 | 254 / 10% / 36.8 | 128 / 50% / 36.7 | 8043 / 29% / 33.3 | 7693 / 26% / 30.4 | 350 / 89% / 52.1 |
| predict/x2.6 | 234 / 61% / 37.0 | 231 / 60% / 36.2 | 3 / 100% / 74.9 | 89 / 40% / 36.5 | 52 / 81% / 36.5 | 2548 / 48% / 33.3 | 2370 / 45% / 30.2 | 178 / 94% / 53.3 |

## Card selection: offered / match, chosen %, skipped (predict p<0.4) / match, cards cast instead (top 4)

- baseline/x2.6: offered 6.19/match, chosen 97%, skipped 0.00/match; instead: hoa_tinh 51%, hoa_xa 25%, hoa_tran 23%, kiem_khi 0%
- predict/x2.6: offered 9.82/match, chosen 12%, skipped 9.48/match; instead: hoa_tinh 35%, hoa_tran 22%, hoa_xa 21%, kiem_khi 12%

## Damage per hit by armed cells n (predict bot)

| set-up | n=2 | n=3 | n=4 | n=5 | n=6 | n=7 |
|---|---|---|---|---|---|---|
| baseline/x2.6 | 30.9 (310/1487) | 33.1 (706/2442) | 35.1 (760/2681) | 34.1 (551/1612) | 36.3 (162/420) | 50.0 (17/47) |
| predict/x2.6 | 30.6 (229/817) | 31.6 (566/1076) | 33.6 (476/728) | 48.9 (77/121) | 58.6 (25/33) | 78.0 (3/7) |

rows=4380
