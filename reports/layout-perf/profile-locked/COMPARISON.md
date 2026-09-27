Frame times in ms, P50 / P95 / P99 (share over the 16.7 ms budget). UI and raster are separate threads; never add them.

#### cold/scroll

| run | commit | tier | frames | UI build | raster |
|---|---|---|---|---|---|
| locked-base-rep1 | 2a91d3a+dirty | solid | 847 | 1.9 / 5.6 / 7.7 (0.0%) | 0.6 / 2.0 / 2.5 (0.0%) |
| locked-base-rep2 | 2a91d3a+dirty | solid | 840 | 1.9 / 5.3 / 6.8 (0.0%) | 0.6 / 2.0 / 2.4 (0.0%) |
| locked-base-rep3 | 2a91d3a+dirty | solid | 842 | 1.8 / 5.4 / 8.1 (0.0%) | 0.6 / 2.0 / 2.6 (0.0%) |
| locked-base-rep4 | 2a91d3a+dirty | solid | 846 | 1.8 / 5.3 / 7.7 (0.0%) | 0.6 / 2.0 / 2.6 (0.0%) |
| locked-base-rep5 | 2a91d3a+dirty | solid | 847 | 1.8 / 5.2 / 7.0 (0.0%) | 0.6 / 1.9 / 2.3 (0.0%) |
| locked-base-rep6 | 2a91d3a+dirty | solid | 848 | 1.7 / 5.2 / 6.8 (0.0%) | 0.6 / 1.8 / 2.2 (0.0%) |
| locked-cap-rep1 | 7b08f8b | solid | 860 | 2.0 / 5.7 / 6.7 (0.0%) | 0.7 / 1.6 / 2.3 (0.0%) |
| locked-cap-rep2 | 7b08f8b | solid | 864 | 2.0 / 5.2 / 6.5 (0.0%) | 0.7 / 1.7 / 2.1 (0.0%) |
| locked-final-rep1 | e92664f | solid | 895 | 2.7 / 4.9 / 6.9 (0.0%) | 0.7 / 1.1 / 2.0 (0.0%) |
| locked-final-rep2 | e92664f | solid | 894 | 2.7 / 4.8 / 7.4 (0.0%) | 0.8 / 1.2 / 2.1 (0.0%) |
| locked-fixed-rep1 | 360bc2d | solid | 861 | 2.0 / 5.7 / 7.0 (0.0%) | 0.7 / 1.8 / 2.4 (0.0%) |
| locked-fixed-rep2 | 360bc2d | solid | 862 | 2.1 / 5.5 / 7.2 (0.0%) | 0.7 / 1.7 / 2.4 (0.0%) |
| probe-locked | 2583df8+dirty | solid | 591 | 2.7 / 5.1 / 7.4 (0.0%) | 0.8 / 1.2 / 1.6 (0.0%) |

#### warm/scroll

| run | commit | tier | frames | UI build | raster |
|---|---|---|---|---|---|
| locked-base-rep1 | 2a91d3a+dirty | solid | 738 | 6.8 / 20.0 / 32.2 (7.3%) | 3.2 / 8.7 / 15.0 (0.5%) |
| locked-base-rep2 | 2a91d3a+dirty | solid | 804 | 5.6 / 15.4 / 23.6 (3.9%) | 2.2 / 7.4 / 13.2 (0.5%) |
| locked-base-rep3 | 2a91d3a+dirty | solid | 787 | 7.5 / 15.2 / 25.4 (3.9%) | 3.1 / 6.1 / 11.0 (0.3%) |
| locked-base-rep4 | 2a91d3a+dirty | solid | 770 | 7.7 / 17.5 / 26.2 (5.7%) | 3.1 / 7.2 / 11.9 (0.5%) |
| locked-base-rep5 | 2a91d3a+dirty | solid | 788 | 7.8 / 16.9 / 25.6 (5.2%) | 3.1 / 7.2 / 12.0 (0.3%) |
| locked-base-rep6 | 2a91d3a+dirty | solid | 799 | 7.8 / 16.2 / 24.1 (4.9%) | 3.2 / 6.3 / 9.8 (0.0%) |
| locked-cap-rep1 | 7b08f8b | solid | 835 | 8.6 / 14.6 / 26.1 (3.4%) | 3.1 / 6.5 / 9.7 (0.0%) |
| locked-cap-rep2 | 7b08f8b | solid | 831 | 8.8 / 15.0 / 20.5 (3.4%) | 3.1 / 7.1 / 11.9 (0.0%) |
| locked-final-rep1 | e92664f | solid | 711 | 13.1 / 30.6 / 46.3 (28.3%) | 4.0 / 10.3 / 16.9 (1.3%) |
| locked-final-rep2 | e92664f | solid | 718 | 12.7 / 30.0 / 43.1 (26.2%) | 3.9 / 10.6 / 17.3 (1.3%) |
| locked-fixed-rep1 | 360bc2d | solid | 839 | 8.6 / 15.5 / 23.2 (4.2%) | 3.1 / 6.1 / 9.5 (0.0%) |
| locked-fixed-rep2 | 360bc2d | solid | 824 | 8.8 / 16.3 / 27.2 (4.9%) | 3.2 / 6.7 / 13.7 (0.5%) |
| probe-locked | 2583df8+dirty | solid | 448 | 16.6 / 28.6 / 48.3 (49.1%) | 4.8 / 8.6 / 12.3 (0.7%) |

#### cold/long-image

| run | commit | tier | frames | UI build | raster |
|---|---|---|---|---|---|
| locked-base-rep1 | 2a91d3a+dirty | solid | 141 | 0.4 / 3.5 / 5.6 (0.0%) | 1.0 / 2.9 / 7.0 (0.0%) |
| locked-base-rep2 | 2a91d3a+dirty | solid | 141 | 0.4 / 3.9 / 5.7 (0.0%) | 1.1 / 2.7 / 4.5 (0.0%) |
| locked-base-rep3 | 2a91d3a+dirty | solid | 141 | 0.3 / 1.4 / 3.8 (0.0%) | 0.6 / 1.8 / 3.9 (0.0%) |
| locked-base-rep4 | 2a91d3a+dirty | solid | 140 | 0.3 / 3.9 / 5.4 (0.0%) | 0.8 / 2.3 / 4.5 (0.0%) |
| locked-base-rep5 | 2a91d3a+dirty | solid | 141 | 0.3 / 2.5 / 6.4 (0.0%) | 0.7 / 2.9 / 5.4 (0.0%) |
| locked-base-rep6 | 2a91d3a+dirty | solid | 141 | 0.4 / 4.0 / 5.2 (0.0%) | 0.8 / 2.6 / 5.4 (0.0%) |
| locked-cap-rep1 | 7b08f8b | solid | 122 | 0.3 / 1.7 / 3.9 (0.0%) | 1.0 / 3.0 / 6.6 (0.0%) |
| locked-cap-rep2 | 7b08f8b | solid | 123 | 0.2 / 1.1 / 4.2 (0.0%) | 0.7 / 2.7 / 5.6 (0.0%) |
| locked-final-rep1 | e92664f | solid | 121 | 0.4 / 1.7 / 4.8 (0.0%) | 1.3 / 3.0 / 5.8 (0.0%) |
| locked-final-rep2 | e92664f | solid | 121 | 0.4 / 1.1 / 4.6 (0.0%) | 1.1 / 2.5 / 6.1 (0.0%) |
| locked-fixed-rep1 | 360bc2d | solid | 122 | 0.3 / 1.5 / 3.8 (0.0%) | 0.9 / 2.6 / 5.6 (0.0%) |
| locked-fixed-rep2 | 360bc2d | solid | 138 | 0.3 / 1.6 / 5.1 (0.0%) | 0.9 / 2.5 / 5.6 (0.0%) |
| probe-locked | 2583df8+dirty | solid | 123 | 0.3 / 1.6 / 4.3 (0.0%) | 0.8 / 2.2 / 4.7 (0.0%) |

#### warm/long-image

| run | commit | tier | frames | UI build | raster |
|---|---|---|---|---|---|
| locked-base-rep1 | 2a91d3a+dirty | solid | 97 | 1.0 / 11.9 / 21.7 (3.1%) | 2.7 / 23.3 / 33.3 (11.3%) |
| locked-base-rep2 | 2a91d3a+dirty | solid | 117 | 0.8 / 4.7 / 11.9 (0.9%) | 2.2 / 17.0 / 21.0 (6.8%) |
| locked-base-rep3 | 2a91d3a+dirty | solid | 120 | 1.2 / 8.7 / 14.1 (0.8%) | 2.6 / 15.2 / 23.6 (3.3%) |
| locked-base-rep4 | 2a91d3a+dirty | solid | 134 | 1.3 / 9.6 / 17.1 (1.5%) | 2.6 / 14.0 / 19.4 (2.2%) |
| locked-base-rep5 | 2a91d3a+dirty | solid | 126 | 1.4 / 9.3 / 24.2 (3.2%) | 2.8 / 16.2 / 20.1 (3.2%) |
| locked-base-rep6 | 2a91d3a+dirty | solid | 120 | 1.2 / 8.4 / 15.7 (0.8%) | 2.7 / 15.3 / 21.8 (3.3%) |
| locked-cap-rep1 | 7b08f8b | solid | 136 | 1.2 / 11.6 / 13.6 (0.0%) | 3.2 / 13.9 / 24.4 (3.7%) |
| locked-cap-rep2 | 7b08f8b | solid | 136 | 1.2 / 9.6 / 16.2 (0.0%) | 2.8 / 15.4 / 22.7 (4.4%) |
| locked-final-rep1 | e92664f | solid | 88 | 1.0 / 7.3 / 17.1 (1.1%) | 3.1 / 22.3 / 93.6 (8.0%) |
| locked-final-rep2 | e92664f | solid | 95 | 0.9 / 4.9 / 18.6 (1.1%) | 2.5 / 21.2 / 53.8 (11.6%) |
| locked-fixed-rep1 | 360bc2d | solid | 130 | 1.1 / 9.0 / 13.9 (0.8%) | 3.0 / 15.6 / 23.5 (3.1%) |
| locked-fixed-rep2 | 360bc2d | solid | 136 | 1.2 / 11.0 / 20.2 (2.2%) | 3.1 / 15.4 / 24.2 (4.4%) |
| probe-locked | 2583df8+dirty | solid | 98 | 1.1 / 6.4 / 16.8 (1.0%) | 3.1 / 18.4 / 35.6 (5.1%) |

#### cold/channels-and-tabs

| run | commit | tier | frames | UI build | raster |
|---|---|---|---|---|---|
| locked-base-rep1 | 2a91d3a+dirty | solid | 136 | 2.5 / 23.7 / 82.4 (7.4%) | 5.0 / 31.6 / 40.8 (10.3%) |
| locked-base-rep2 | 2a91d3a+dirty | solid | 148 | 2.0 / 25.0 / 53.0 (6.1%) | 3.6 / 16.8 / 30.2 (6.1%) |
| locked-base-rep3 | 2a91d3a+dirty | solid | 143 | 1.8 / 37.3 / 70.1 (8.4%) | 4.6 / 21.5 / 42.2 (9.8%) |
| locked-base-rep4 | 2a91d3a+dirty | solid | 144 | 1.9 / 37.4 / 75.9 (8.3%) | 4.0 / 18.4 / 28.6 (6.2%) |
| locked-base-rep5 | 2a91d3a+dirty | solid | 142 | 2.4 / 25.5 / 67.3 (7.7%) | 4.1 / 19.0 / 50.2 (12.7%) |
| locked-base-rep6 | 2a91d3a+dirty | solid | 144 | 2.2 / 42.8 / 73.3 (11.1%) | 4.4 / 24.4 / 44.4 (15.3%) |
| locked-cap-rep1 | 7b08f8b | solid | 144 | 1.6 / 20.3 / 65.4 (5.6%) | 3.0 / 19.0 / 26.4 (8.3%) |
| locked-cap-rep2 | 7b08f8b | solid | 142 | 1.7 / 15.8 / 85.8 (4.9%) | 2.9 / 23.6 / 26.6 (11.3%) |
| locked-final-rep1 | e92664f | solid | 125 | 1.9 / 25.9 / 173.7 (8.0%) | 4.1 / 16.3 / 23.0 (4.8%) |
| locked-final-rep2 | e92664f | solid | 124 | 2.1 / 32.6 / 344.1 (10.5%) | 3.9 / 18.1 / 26.4 (8.9%) |
| locked-fixed-rep1 | 360bc2d | solid | 146 | 1.7 / 22.4 / 83.7 (8.2%) | 3.2 / 20.4 / 22.3 (7.5%) |
| locked-fixed-rep2 | 360bc2d | solid | 140 | 1.7 / 39.4 / 76.4 (7.1%) | 3.0 / 24.5 / 31.2 (12.9%) |
| probe-locked | 2583df8+dirty | solid | 158 | 1.0 / 14.0 / 57.2 (3.8%) | 2.5 / 16.7 / 28.1 (5.1%) |

#### warm/channels-and-tabs

| run | commit | tier | frames | UI build | raster |
|---|---|---|---|---|---|
| locked-base-rep1 | 2a91d3a+dirty | solid | 155 | 2.3 / 13.0 / 38.3 (4.5%) | 2.7 / 14.2 / 27.1 (3.9%) |
| locked-base-rep2 | 2a91d3a+dirty | solid | 154 | 2.3 / 14.3 / 51.3 (3.9%) | 2.5 / 11.2 / 21.6 (3.9%) |
| locked-base-rep3 | 2a91d3a+dirty | solid | 169 | 2.1 / 12.5 / 58.4 (3.0%) | 3.2 / 9.4 / 29.4 (1.2%) |
| locked-base-rep4 | 2a91d3a+dirty | solid | 159 | 2.3 / 14.4 / 68.3 (3.8%) | 3.0 / 10.7 / 20.2 (1.9%) |
| locked-base-rep5 | 2a91d3a+dirty | solid | 167 | 2.3 / 11.7 / 64.9 (3.0%) | 2.9 / 9.1 / 22.0 (1.8%) |
| locked-base-rep6 | 2a91d3a+dirty | solid | 175 | 2.2 / 12.5 / 82.5 (2.3%) | 3.0 / 11.8 / 22.9 (1.7%) |
| locked-cap-rep1 | 7b08f8b | solid | 136 | 2.2 / 12.4 / 123.4 (3.7%) | 2.8 / 12.0 / 20.9 (1.5%) |
| locked-cap-rep2 | 7b08f8b | solid | 133 | 2.0 / 17.2 / 91.9 (5.3%) | 2.8 / 14.6 / 19.4 (1.5%) |
| locked-final-rep1 | e92664f | solid | 118 | 2.3 / 27.9 / 104.4 (5.1%) | 2.6 / 9.4 / 15.9 (0.8%) |
| locked-final-rep2 | e92664f | solid | 117 | 2.1 / 21.8 / 69.6 (6.0%) | 2.3 / 10.3 / 12.8 (0.0%) |
| locked-fixed-rep1 | 360bc2d | solid | 137 | 2.0 / 14.3 / 61.3 (3.6%) | 2.9 / 10.5 / 20.8 (2.2%) |
| locked-fixed-rep2 | 360bc2d | solid | 135 | 1.9 / 19.7 / 70.3 (5.2%) | 2.7 / 11.5 / 27.0 (3.0%) |
| probe-locked | 2583df8+dirty | solid | 114 | 2.5 / 19.2 / 174.7 (5.3%) | 3.3 / 13.8 / 17.7 (1.8%) |

#### Memory and images

| run | host footprint max sampled / peak (MB) | RSS end of cold scroll (MB) | image cache end of cold scroll (MB) | long strip tile decode | detail decode | tap → detail image (ms) |
|---|---|---|---|---|---|---|
| locked-base-rep1 | 767.0 / 1170.0 | 215 | 75 | 512x15360 | 273x8192 | 539 |
| locked-base-rep2 | 686.0 / 1121.0 | 222 | 75 | 512x15360 | 273x8192 | 543 |
| locked-base-rep3 | 980.0 / 1122.0 | 215 | 75 | 512x15360 | 273x8192 | 557 |
| locked-base-rep4 | 1026.0 / 1133.0 | 215 | 75 | 512x15360 | 273x8192 | 550 |
| locked-base-rep5 | 903.0 / 1227.0 | 220 | 75 | 512x15360 | 273x8192 | 547 |
| locked-base-rep6 | 974.0 / 1106.0 | 218 | 75 | 512x15360 | 273x8192 | 547 |
| locked-cap-rep1 | 664.0 / 1028.0 | 216 | 98 | 264x7931 | 273x8192 | 546 |
| locked-cap-rep2 | 776.0 / 1016.0 | 216 | 98 | 264x7931 | 273x8192 | 559 |
| locked-final-rep1 | 901.0 / 1013.0 | 227 | 98 | 264x7931 | 273x8192 | 555 |
| locked-final-rep2 | 665.0 / 1024.0 | 226 | 98 | 264x7931 | 273x8192 | 543 |
| locked-fixed-rep1 | 793.0 / 1004.0 | 215 | 98 | 264x7931 | 273x8192 | 538 |
| locked-fixed-rep2 | 667.0 / 985.0 | 217 | 98 | 264x7931 | 273x8192 | 548 |
| probe-locked | 647.0 / 1065.0 | 225 | 97 | 264x7931 | 273x8192 | 546 |
