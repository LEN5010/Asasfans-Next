Frame times in ms, P50 / P95 / P99 (share over the 16.7 ms budget). UI and raster are separate threads; never add them.

#### cold/scroll

| run | commit | tier | frames | UI build | raster |
|---|---|---|---|---|---|
| r1-premium-rep1 | 2a91d3a | premium | 3556 | 1.6 / 3.5 / 5.1 (0.0%) | 1.0 / 2.0 / 2.4 (0.0%) |
| r1-premium-rep2 | 2a91d3a | premium | 3526 | 1.7 / 2.9 / 4.9 (0.0%) | 1.1 / 1.8 / 2.2 (0.0%) |
| r2-solid-rep1 | 2a91d3a | solid | 3527 | 1.7 / 4.6 / 6.2 (0.0%) | 0.7 / 1.5 / 2.0 (0.0%) |
| r2-solid-rep2 | 2a91d3a | solid | 3533 | 1.8 / 3.9 / 5.5 (0.0%) | 0.7 / 1.3 / 1.7 (0.0%) |
| r3-solid-tabs-rep1 | 60470d9 | solid | 3545 | 1.6 / 3.6 / 5.3 (0.0%) | 0.6 / 1.1 / 1.6 (0.0%) |
| r3-solid-tabs-rep2 | 60470d9 | solid | 3533 | 2.0 / 5.2 / 7.9 (0.0%) | 0.7 / 1.8 / 2.3 (0.0%) |
| r4-solid-tabs-covers-rep1 | 64f2408 | solid | 3384 | 1.7 / 3.9 / 5.3 (0.0%) | 0.6 / 1.2 / 1.6 (0.0%) |
| r4-solid-tabs-covers-rep2 | 64f2408 | solid | 3368 | 2.1 / 5.3 / 7.7 (0.0%) | 0.7 / 1.8 / 2.2 (0.0%) |
| r5-solid-tabs-covers-budget-rep1 | 1577302 | solid | 3396 | 1.6 / 3.3 / 4.7 (0.0%) | 0.6 / 1.1 / 1.4 (0.0%) |
| r5-solid-tabs-covers-budget-rep2 | 1577302 | solid | 3362 | 2.2 / 5.3 / 8.3 (0.0%) | 0.7 / 1.9 / 2.2 (0.0%) |

#### warm/scroll

| run | commit | tier | frames | UI build | raster |
|---|---|---|---|---|---|
| r1-premium-rep1 | 2a91d3a | premium | 3526 | 1.6 / 3.9 / 10.2 (0.0%) | 1.1 / 1.8 / 2.5 (0.0%) |
| r1-premium-rep2 | 2a91d3a | premium | 3535 | 1.6 / 3.4 / 5.7 (0.0%) | 1.1 / 1.9 / 2.3 (0.0%) |
| r2-solid-rep1 | 2a91d3a | solid | 3537 | 1.8 / 4.8 / 8.6 (0.0%) | 0.7 / 1.5 / 2.1 (0.0%) |
| r2-solid-rep2 | 2a91d3a | solid | 3540 | 1.8 / 4.6 / 7.4 (0.0%) | 0.7 / 1.3 / 2.0 (0.0%) |
| r3-solid-tabs-rep1 | 60470d9 | solid | 3533 | 1.8 / 4.1 / 6.9 (0.0%) | 0.7 / 1.2 / 1.6 (0.0%) |
| r3-solid-tabs-rep2 | 60470d9 | solid | 3531 | 1.9 / 5.4 / 9.2 (0.0%) | 0.7 / 1.7 / 2.1 (0.0%) |
| r4-solid-tabs-covers-rep1 | 64f2408 | solid | 3454 | 1.7 / 4.1 / 6.5 (0.0%) | 0.7 / 1.2 / 1.5 (0.0%) |
| r4-solid-tabs-covers-rep2 | 64f2408 | solid | 3433 | 2.0 / 5.3 / 8.6 (0.0%) | 0.7 / 1.8 / 2.2 (0.0%) |
| r5-solid-tabs-covers-budget-rep1 | 1577302 | solid | 3452 | 1.7 / 3.8 / 6.2 (0.0%) | 0.7 / 1.1 / 1.6 (0.0%) |
| r5-solid-tabs-covers-budget-rep2 | 1577302 | solid | 3458 | 2.2 / 5.3 / 13.2 (0.2%) | 0.7 / 1.8 / 2.1 (0.0%) |

#### cold/long-image

| run | commit | tier | frames | UI build | raster |
|---|---|---|---|---|---|
| r1-premium-rep1 | 2a91d3a | premium | 156 | 0.5 / 2.5 / 4.2 (0.0%) | 1.1 / 2.5 / 6.6 (0.0%) |
| r1-premium-rep2 | 2a91d3a | premium | 192 | 0.5 / 2.5 / 3.4 (0.0%) | 0.9 / 2.6 / 9.0 (0.0%) |
| r2-solid-rep1 | 2a91d3a | solid | 137 | 0.2 / 0.8 / 3.4 (0.0%) | 0.6 / 2.0 / 3.2 (0.0%) |
| r2-solid-rep2 | 2a91d3a | solid | 136 | 0.2 / 1.1 / 3.9 (0.0%) | 0.6 / 2.6 / 16.2 (0.7%) |
| r3-solid-tabs-rep1 | 60470d9 | solid | 137 | 0.3 / 1.4 / 4.9 (0.0%) | 0.9 / 2.6 / 6.7 (0.0%) |
| r3-solid-tabs-rep2 | 60470d9 | solid | 121 | 0.4 / 1.6 / 4.5 (0.0%) | 1.0 / 2.9 / 7.5 (0.0%) |
| r4-solid-tabs-covers-rep1 | 64f2408 | solid | 123 | 0.3 / 1.0 / 3.2 (0.0%) | 0.7 / 2.2 / 6.7 (0.0%) |
| r4-solid-tabs-covers-rep2 | 64f2408 | solid | 121 | 0.3 / 1.1 / 2.4 (0.0%) | 0.9 / 2.7 / 6.4 (0.0%) |
| r5-solid-tabs-covers-budget-rep1 | 1577302 | solid | 168 | 0.4 / 2.8 / 5.2 (0.0%) | 0.7 / 2.2 / 6.6 (0.0%) |
| r5-solid-tabs-covers-budget-rep2 | 1577302 | solid | 122 | 0.4 / 1.0 / 4.3 (0.0%) | 1.0 / 2.7 / 6.1 (0.0%) |

#### warm/long-image

| run | commit | tier | frames | UI build | raster |
|---|---|---|---|---|---|
| r1-premium-rep1 | 2a91d3a | premium | 117 | 0.4 / 1.7 / 5.1 (0.0%) | 0.9 / 4.0 / 6.9 (0.0%) |
| r1-premium-rep2 | 2a91d3a | premium | 191 | 0.4 / 2.8 / 6.5 (0.0%) | 1.0 / 2.5 / 9.7 (0.0%) |
| r2-solid-rep1 | 2a91d3a | solid | 135 | 0.3 / 1.3 / 4.0 (0.7%) | 0.7 / 2.8 / 5.8 (0.0%) |
| r2-solid-rep2 | 2a91d3a | solid | 131 | 0.3 / 1.1 / 3.4 (0.0%) | 0.7 / 2.1 / 5.2 (0.0%) |
| r3-solid-tabs-rep1 | 60470d9 | solid | 133 | 0.3 / 1.2 / 4.0 (0.0%) | 0.7 / 1.9 / 5.5 (0.0%) |
| r3-solid-tabs-rep2 | 60470d9 | solid | 134 | 0.3 / 1.1 / 4.7 (0.0%) | 1.0 / 2.8 / 6.2 (0.0%) |
| r4-solid-tabs-covers-rep1 | 64f2408 | solid | 117 | 0.3 / 1.4 / 3.3 (0.9%) | 0.6 / 2.7 / 4.6 (0.0%) |
| r4-solid-tabs-covers-rep2 | 64f2408 | solid | 130 | 0.3 / 1.1 / 3.7 (0.0%) | 1.0 / 2.3 / 6.3 (0.0%) |
| r5-solid-tabs-covers-budget-rep1 | 1577302 | solid | 116 | 0.3 / 1.5 / 3.6 (0.0%) | 0.6 / 2.3 / 4.7 (0.0%) |
| r5-solid-tabs-covers-budget-rep2 | 1577302 | solid | 141 | 0.4 / 4.5 / 14.9 (0.7%) | 1.0 / 2.1 / 3.6 (0.0%) |

#### cold/channels-and-tabs

| run | commit | tier | frames | UI build | raster |
|---|---|---|---|---|---|
| r1-premium-rep1 | 2a91d3a | premium | 245 | 0.6 / 4.3 / 43.7 (2.9%) | 1.3 / 4.5 / 7.0 (0.0%) |
| r1-premium-rep2 | 2a91d3a | premium | 253 | 0.8 / 2.6 / 18.7 (1.2%) | 1.6 / 4.2 / 6.5 (0.0%) |
| r2-solid-rep1 | 2a91d3a | solid | 146 | 0.7 / 9.4 / 23.9 (2.7%) | 1.3 / 4.7 / 6.1 (0.0%) |
| r2-solid-rep2 | 2a91d3a | solid | 144 | 1.0 / 8.6 / 27.9 (2.1%) | 1.4 / 5.0 / 8.7 (0.0%) |
| r3-solid-tabs-rep1 | 60470d9 | solid | 136 | 1.2 / 12.6 / 17.8 (1.5%) | 1.0 / 4.0 / 6.2 (0.0%) |
| r3-solid-tabs-rep2 | 60470d9 | solid | 138 | 1.0 / 14.4 / 32.9 (2.9%) | 1.0 / 4.1 / 6.6 (0.0%) |
| r4-solid-tabs-covers-rep1 | 64f2408 | solid | 123 | 1.3 / 12.1 / 24.8 (2.4%) | 0.9 / 3.2 / 4.4 (0.0%) |
| r4-solid-tabs-covers-rep2 | 64f2408 | solid | 117 | 1.2 / 14.5 / 30.2 (4.3%) | 1.3 / 4.0 / 4.9 (0.0%) |
| r5-solid-tabs-covers-budget-rep1 | 1577302 | solid | 123 | 1.0 / 8.9 / 20.0 (1.6%) | 0.8 / 3.2 / 5.2 (0.0%) |
| r5-solid-tabs-covers-budget-rep2 | 1577302 | solid | 112 | 2.1 / 24.5 / 52.2 (7.1%) | 0.9 / 3.3 / 4.6 (0.0%) |

#### warm/channels-and-tabs

| run | commit | tier | frames | UI build | raster |
|---|---|---|---|---|---|
| r1-premium-rep1 | 2a91d3a | premium | 247 | 0.8 / 3.7 / 49.8 (1.6%) | 1.2 / 3.3 / 4.5 (0.0%) |
| r1-premium-rep2 | 2a91d3a | premium | 250 | 0.8 / 2.9 / 12.9 (0.8%) | 1.4 / 3.3 / 4.1 (0.0%) |
| r2-solid-rep1 | 2a91d3a | solid | 142 | 0.9 / 4.5 / 14.8 (0.7%) | 0.7 / 2.1 / 3.5 (0.0%) |
| r2-solid-rep2 | 2a91d3a | solid | 142 | 1.2 / 4.7 / 32.3 (2.1%) | 0.8 / 3.4 / 4.3 (0.0%) |
| r3-solid-tabs-rep1 | 60470d9 | solid | 134 | 0.9 / 7.8 / 12.4 (0.7%) | 0.7 / 2.0 / 3.4 (0.0%) |
| r3-solid-tabs-rep2 | 60470d9 | solid | 138 | 1.0 / 10.7 / 27.5 (2.2%) | 0.8 / 2.6 / 6.6 (0.0%) |
| r4-solid-tabs-covers-rep1 | 64f2408 | solid | 117 | 1.2 / 8.9 / 22.5 (1.7%) | 0.7 / 2.1 / 3.4 (0.0%) |
| r4-solid-tabs-covers-rep2 | 64f2408 | solid | 115 | 1.5 / 9.8 / 30.3 (2.6%) | 0.9 / 3.0 / 5.4 (0.0%) |
| r5-solid-tabs-covers-budget-rep1 | 1577302 | solid | 117 | 1.2 / 5.3 / 23.4 (1.7%) | 0.7 / 2.3 / 4.1 (0.0%) |
| r5-solid-tabs-covers-budget-rep2 | 1577302 | solid | 112 | 2.0 / 17.4 / 53.1 (5.4%) | 0.6 / 2.3 / 3.4 (0.0%) |

#### Memory and images

| run | host footprint max sampled / peak (MB) | RSS end of cold scroll (MB) | image cache end of cold scroll (MB) | long strip tile decode | detail decode | tap → detail image (ms) |
|---|---|---|---|---|---|---|
| r1-premium-rep1 | 884.0 / 1145.0 | 191 | 75 | 512x15360 | 273x8192 | 555 |
| r1-premium-rep2 | 828.0 / 1271.0 | 200 | 77 | 512x15360 | 273x8192 | 554 |
| r2-solid-rep1 | 628.0 / 934.0 | 187 | 77 | 512x15360 | 273x8192 | 544 |
| r2-solid-rep2 | 591.0 / 1130.0 | 198 | 77 | 512x15360 | 273x8192 | 552 |
| r3-solid-tabs-rep1 | 533.0 / 925.0 | 182 | 77 | 512x15360 | 273x8192 | 543 |
| r3-solid-tabs-rep2 | 573.0 / 1034.0 | 188 | 77 | 512x15360 | 273x8192 | 531 |
| r4-solid-tabs-covers-rep1 | 608.0 / 1037.0 | 196 | 77 | 512x15360 | 273x8192 | 549 |
| r4-solid-tabs-covers-rep2 | 619.0 / 1123.0 | 190 | 77 | 512x15360 | 273x8192 | 549 |
| r5-solid-tabs-covers-budget-rep1 | 602.0 / 904.0 | 183 | 98 | 264x7931 | 273x8192 | 548 |
| r5-solid-tabs-covers-budget-rep2 | 562.0 / 780.0 | 183 | 100 | 264x7931 | 273x8192 | 554 |
