# Fleet performance

Every verified family binary under `src/extract/`, and Oracle7's own head, measured on the shipped specialist panels by `tools/perf/fleet.py` on 2026-10-18T00:03:20Z. One row per binary; the appendix has per-specialist numbers and Oracle7's per-family breakdown.

## What the columns mean

- **KiB** is the MLton binary on disk. **cold ms** is process start to the first reply (median; every specialist panel starts its own fresh process, plus three one-question starts). **p50/p95/max ms** are per-question round trips, warm (after the first question of each process).
- **peak MiB** is resident memory: the exact `ru_maxrss` of the process, or the ps sample of its whole tree when it spawns children (Oracle7, fusion, stores). **budget ms** is the tightest `latency_p50_ms` the family's manifests declare; **fit** says whether the measured p50 respects it. **store MB** is the tightest `store_mb` budget. **a/w/e** are answered / withheld / error counts over the questions asked; withheld counts every non-answered reply (stores' `clarify` and Oracle7's `clarification` score as withheld, as the contract says).
- Questions: every item of the dev and heldout panels of each specialist the family serves, asked the way its lane scored it (`--specialist <id>`). Oracle7 answered the same questions in the same order through one head process (`tools/parity/answerers/oracle7.py`).

| Binary | KiB | questions | cold ms | p50 ms | p95 ms | max ms | peak MiB | budget ms | fit | store MB | a/w/e |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|
| `materials` | 756 | 347 | 2.20 | 0.12 | 49.8 | 182.4 | 5.0 | 50.0 | yes | 1 | 317/30/0 |
| `trades` | 792 | 357 | 2.47 | 0.16 | 36.8 | 114.9 | 4.7 | 50.0 | yes | 1 | 318/39/0 |
| `life` | 722 | 179 | 218.4 | 0.11 | 32.2 | 149.1 | 4.9 | 50.0 | yes | 1 | 157/22/0 |
| `acoustics` | 418 | 139 | 8.96 | 9.74 | 31.1 | 31.7 | 4.2 | 50.0 | yes | 1 | 131/8/0 |
| `emoptics` | 742 | 1253 | 80.3 | 0.11 | 28.9 | 67.8 | 4.9 | 50.0 | yes | 1 | 1157/96/0 |
| `climate` | 605 | 306 | 39.0 | 0.10 | 21.2 | 29.7 | 4.6 | 50.0 | yes | 1 | 259/47/0 |
| `space` | 702 | 1185 | 154.7 | 0.12 | 20.3 | 74.0 | 5.7 | 50.0 | yes | 1 | 1108/77/0 |
| `geostats` | 585 | 1456 | 13.9 | 0.15 | 7.38 | 8.89 | 4.3 | 50.0 | yes | 1 | 1369/87/0 |
| `mechanics` | 638 | 1264 | 21.1 | 0.14 | 5.49 | 10.3 | 4.6 | 50.0 | yes | 1 | 1211/53/0 |
| `stores` | 550 | 2476 | 78.6 | 0.43 | 1.69 | 4.83 | 91.7 | 50.0 | yes | 5 | 2219/257/0 |
| `facts` | 326 | 428 | 2.12 | 0.20 | 0.98 | 2.32 | 7.0 | 50.0 | yes | 1 | 375/53/0 |
| `fusion` *(batteries, via its untrusted answerer wrapper)* | 395 | 396 | 49.3 | 0.47 | 0.91 | 1.61 | 24.9 | - | - | - | 316/80/0 |
| `chemistry` | 760 | 1206 | 65.5 | 0.11 | 0.33 | 53.0 | 5.4 | 50.0 | yes | 1 | 1046/160/0 |
| `variants` | 565 | 402 | 5.93 | 0.10 | 0.31 | 0.52 | 9.8 | 50.0 | yes | 1 | 349/53/0 |
| `energy` | 742 | 569 | 4.64 | 0.12 | 0.25 | 4.64 | 4.3 | 50.0 | yes | 1 | 524/45/0 |
| `computing` | 1249 | 1364 | 12.5 | 0.05 | 0.23 | 20.6 | 5.9 | 50.0 | yes | 1 | 1223/141/0 |
| `quantity` | 531 | 641 | 5.47 | 0.09 | 0.22 | 3.86 | 9.8 | 50.0 | yes | 1 | 607/34/0 |
| `anatomyagri` | 394 | 156 | 2.03 | 0.12 | 0.21 | 0.25 | 3.8 | 50.0 | yes | 1 | 136/20/0 |
| `discrete` | 869 | 508 | 2.13 | 0.07 | 0.21 | 35.0 | 4.4 | 50.0 | yes | 1 | 486/22/0 |
| `oracle7-head` *(one head process, every panel)* | - | 14632 | 3565 | 140.2 | 821.7 | 8417 | 1959.1 | - | - | - | 12005/2627/0 |

## The binaries

| Binary | built | sha256 (first 16) |
|---|---|---|
| `acoustics` | 2026-10-16 20:12 | `e325a6821fc6be40` |
| `anatomyagri` | 2026-10-17 17:08 | `4ad134980306d1d3` |
| `chemistry` | 2026-10-17 16:31 | `f0118ddb6a6cd5c7` |
| `climate` | 2026-10-17 16:01 | `915e23081e9e4651` |
| `computing` | 2026-10-17 18:28 | `fb520e1d514923ee` |
| `discrete` | 2026-10-17 18:49 | `1a93f8c59585d563` |
| `emoptics` | 2026-10-17 16:32 | `0cf8523d9c4debce` |
| `energy` | 2026-10-17 15:53 | `cb27b52673a579f4` |
| `facts` | 2026-10-17 17:19 | `f56946b92019451f` |
| `fusion` | 2026-10-17 17:45 | `2ab6d51624d3aea1` |
| `geostats` | 2026-10-17 17:40 | `1b257677f5128ccd` |
| `life` | 2026-10-17 16:46 | `2b66ec3571216341` |
| `materials` | 2026-10-17 16:46 | `c28d581b7ff396dd` |
| `mechanics` | 2026-10-17 16:07 | `d5aacea4f51b0494` |
| `quantity` | 2026-10-17 00:31 | `b9a57826d21906aa` |
| `space` | 2026-10-17 17:10 | `1a9c93cbff800391` |
| `stores` | 2026-10-17 17:40 | `980a045fba1e6280` |
| `trades` | 2026-10-17 18:48 | `b2e968c9a7848752` |
| `variants` | 2026-10-17 00:32 | `eb35ba38e6d5bde7` |

Oracle7 head: `/Users/ember/dev/o7vn/.venv/bin/python /Users/ember/dev/o7vn/var/scout-wt/perf-envelope/tools/parity/answerers/oracle7.py`, Python /Users/ember/dev/o7vn/.venv/bin/python.

## Outliers

- Cold starts above 100 ms: `life` 218.4 ms, `space` 154.7 ms (everything else is 80 ms or less).
- Warm questions above 5 ms p50, all of them interval arithmetic (`HOL-Decision_Procs.Approximation`), everything else in the fleet is 0.05-0.5 ms: `emoptics` on `wiring` dev 35.2 ms; `life` on `ecology` dev 27.6 ms; `life` on `ecology` heldout 27.2 ms; `space` on `spacecraft` dev 26.7 ms; `space` on `orbits` dev 20.3 ms; `space` on `orbits` heldout 20.1 ms; `climate` on `climate` heldout 14.0 ms; `acoustics` on `acoustics` dev 9.77 ms; `acoustics` on `acoustics` heldout 9.71 ms; `emoptics` on `wiring` heldout 8.72 ms; `climate` on `climate` dev 8.59 ms; `emoptics` on `electrical` dev 5.21 ms; `emoptics` on `electrical` heldout 5.19 ms.
- `computing` is the largest binary at 1.2 MiB.
- `stores` peaks at 92 MiB resident (its python fetcher child counts too).
- `oracle7-head` has a question above one second (max 8417 ms). Slowest family for it: `space`.
- `oracle7-head` peaks at 1959 MiB resident.

## Appendix: per specialist panel

| Family | Specialist | Split | n | cold ms | p50 ms | p95 ms | max ms | budget ms | answered / withheld / error |
|---|---|---|---:|---:|---:|---:|---:|---:|---|
| `acoustics` | `acoustics` | dev | 70 | 8.96 | 9.77 | 30.9 | 31.7 | 50.0 | 66 / 4 / 0 |
| `acoustics` | `acoustics` | heldout | 69 | 9.59 | 9.71 | 31.2 | 31.5 | 50.0 | 65 / 4 / 0 |
| `anatomyagri` | `anatomy` | dev | 11 | 2.03 | 0.07 | 0.19 | 0.19 | 50.0 | 10 / 1 / 0 |
| `anatomyagri` | `anatomy` | heldout | 11 | 2.04 | 0.09 | 0.15 | 0.15 | 50.0 | 9 / 2 / 0 |
| `anatomyagri` | `anatomy-r2` | dev | 11 | 1.98 | 0.08 | 0.25 | 0.25 | 50.0 | 10 / 1 / 0 |
| `anatomyagri` | `anatomy-r2` | heldout | 11 | 1.41 | 0.08 | 0.17 | 0.17 | 50.0 | 9 / 2 / 0 |
| `anatomyagri` | `agriculture-v2` | dev | 17 | 2.17 | 0.14 | 0.22 | 0.22 | 50.0 | 15 / 2 / 0 |
| `anatomyagri` | `agriculture-v2` | heldout | 17 | 2.11 | 0.14 | 0.25 | 0.25 | 50.0 | 15 / 2 / 0 |
| `anatomyagri` | `gardening` | dev | 15 | 2.37 | 0.12 | 0.21 | 0.21 | 50.0 | 13 / 2 / 0 |
| `anatomyagri` | `gardening` | heldout | 15 | 1.52 | 0.11 | 0.18 | 0.18 | 50.0 | 13 / 2 / 0 |
| `anatomyagri` | `nutrition-label-v2` | dev | 32 | 2.27 | 0.12 | 0.21 | 0.21 | 50.0 | 28 / 4 / 0 |
| `anatomyagri` | `nutrition-label-v2` | heldout | 16 | 1.68 | 0.16 | 0.22 | 0.22 | 50.0 | 14 / 2 / 0 |
| `chemistry` | `chemistry` | dev | 225 | 65.5 | 0.09 | 0.17 | 0.34 | 50.0 | 218 / 7 / 0 |
| `chemistry` | `chemistry` | heldout | 281 | 67.0 | 0.08 | 0.17 | 0.29 | 50.0 | 218 / 63 / 0 |
| `chemistry` | `chemistry-v3` | dev | 225 | 65.9 | 0.15 | 0.21 | 0.31 | 50.0 | 218 / 7 / 0 |
| `chemistry` | `chemistry-v3` | heldout | 281 | 67.9 | 0.13 | 0.22 | 0.30 | 50.0 | 218 / 63 / 0 |
| `chemistry` | `decay` | dev | 42 | 67.3 | 0.29 | 51.7 | 52.4 | 50.0 | 40 / 2 / 0 |
| `chemistry` | `decay` | heldout | 42 | 65.9 | 0.28 | 52.1 | 53.0 | 50.0 | 32 / 10 / 0 |
| `chemistry` | `labsolutions` | dev | 28 | 65.5 | 0.24 | 0.39 | 0.39 | 50.0 | 26 / 2 / 0 |
| `chemistry` | `labsolutions` | heldout | 27 | 64.8 | 0.28 | 0.43 | 0.43 | 50.0 | 25 / 2 / 0 |
| `chemistry` | `labsolutions-r2` | dev | 28 | 64.3 | 0.26 | 0.42 | 0.42 | 50.0 | 26 / 2 / 0 |
| `chemistry` | `labsolutions-r2` | heldout | 27 | 65.5 | 0.30 | 0.49 | 0.49 | 50.0 | 25 / 2 / 0 |
| `climate` | `carboncapture` | dev | 14 | 38.7 | 0.10 | 0.12 | 0.12 | 50.0 | 12 / 2 / 0 |
| `climate` | `carboncapture` | heldout | 14 | 38.5 | 0.12 | 0.13 | 0.13 | 50.0 | 12 / 2 / 0 |
| `climate` | `airquality` | dev | 38 | 38.3 | 0.13 | 0.32 | 0.32 | 50.0 | 35 / 3 / 0 |
| `climate` | `airquality` | heldout | 38 | 38.9 | 0.12 | 0.39 | 0.39 | 50.0 | 27 / 11 / 0 |
| `climate` | `climate` | dev | 24 | 42.5 | 8.59 | 29.7 | 29.7 | 50.0 | 21 / 3 / 0 |
| `climate` | `climate` | heldout | 24 | 43.8 | 14.0 | 27.8 | 27.8 | 50.0 | 21 / 3 / 0 |
| `climate` | `carbonmat` | dev | 17 | 50.6 | 0.07 | 21.2 | 21.2 | 50.0 | 16 / 1 / 0 |
| `climate` | `carbonmat` | heldout | 17 | 50.3 | 0.08 | 21.0 | 21.0 | 50.0 | 16 / 1 / 0 |
| `climate` | `coldchain` | dev | 30 | 39.0 | 0.08 | 0.14 | 0.14 | 50.0 | 28 / 2 / 0 |
| `climate` | `coldchain` | heldout | 30 | 38.6 | 0.08 | 0.15 | 0.15 | 50.0 | 16 / 14 / 0 |
| `climate` | `coldchain-v2` | dev | 30 | 38.2 | 0.10 | 0.20 | 0.20 | 50.0 | 28 / 2 / 0 |
| `climate` | `coldchain-v2` | heldout | 30 | 38.9 | 0.12 | 0.22 | 0.22 | 50.0 | 27 / 3 / 0 |
| `computing` | `networking` | dev | 74 | 13.0 | 0.09 | 0.20 | 0.25 | 50.0 | 70 / 4 / 0 |
| `computing` | `networking` | heldout | 71 | 12.5 | 0.11 | 0.23 | 0.32 | 50.0 | 64 / 7 / 0 |
| `computing` | `embedded` | dev | 25 | 12.3 | 0.11 | 0.19 | 0.19 | 50.0 | 24 / 1 / 0 |
| `computing` | `embedded` | heldout | 25 | 11.9 | 0.10 | 0.22 | 0.22 | 50.0 | 24 / 1 / 0 |
| `computing` | `cyber` | dev | 20 | 12.9 | 0.16 | 10.2 | 10.2 | 50.0 | 17 / 3 / 0 |
| `computing` | `cyber` | heldout | 20 | 12.2 | 0.09 | 10.3 | 10.3 | 50.0 | 14 / 6 / 0 |
| `computing` | `linux-v2` | dev | 42 | 12.8 | 0.07 | 0.17 | 0.21 | 50.0 | 39 / 3 / 0 |
| `computing` | `linux-v2` | heldout | 42 | 12.1 | 0.06 | 0.16 | 0.19 | 50.0 | 39 / 3 / 0 |
| `computing` | `git` | dev | 10 | 12.3 | 0.08 | 0.22 | 0.22 | 50.0 | 9 / 1 / 0 |
| `computing` | `git` | heldout | 10 | 12.3 | 0.08 | 0.19 | 0.19 | 50.0 | 7 / 3 / 0 |
| `computing` | `sql` | dev | 61 | 12.5 | 0.16 | 0.24 | 0.31 | 50.0 | 59 / 2 / 0 |
| `computing` | `sql` | heldout | 61 | 13.0 | 0.22 | 0.33 | 0.42 | 50.0 | 59 / 2 / 0 |
| `computing` | `python` | dev | 198 | 12.8 | 0.05 | 0.09 | 0.11 | 50.0 | 193 / 5 / 0 |
| `computing` | `python` | heldout | 224 | 12.1 | 0.04 | 0.08 | 0.15 | 50.0 | 181 / 43 / 0 |
| `computing` | `python-r2` | dev | 198 | 11.9 | 0.04 | 0.08 | 0.11 | 50.0 | 193 / 5 / 0 |
| `computing` | `python-r2` | heldout | 224 | 12.1 | 0.05 | 0.09 | 0.11 | 50.0 | 181 / 43 / 0 |
| `computing` | `robotics-v2` | dev | 36 | 14.4 | 0.13 | 20.6 | 20.6 | 50.0 | 32 / 4 / 0 |
| `computing` | `robotics-v2` | heldout | 23 | 14.6 | 0.28 | 20.1 | 20.1 | 50.0 | 18 / 5 / 0 |
| `discrete` | `games-v3` | dev | 51 | 1.48 | 0.10 | 0.20 | 0.21 | 50.0 | 48 / 3 / 0 |
| `discrete` | `games-v3` | heldout | 18 | 1.75 | 0.13 | 0.24 | 0.24 | 50.0 | 17 / 1 / 0 |
| `discrete` | `logic-v3` | dev | 33 | 1.31 | 0.06 | 0.51 | 0.51 | 50.0 | 30 / 3 / 0 |
| `discrete` | `logic-v3` | heldout | 12 | 2.21 | 0.07 | 0.14 | 0.14 | 50.0 | 11 / 1 / 0 |
| `discrete` | `dataformats` | dev | 93 | 2.13 | 0.05 | 34.8 | 34.9 | 50.0 | 90 / 3 / 0 |
| `discrete` | `dataformats` | heldout | 93 | 2.19 | 0.05 | 34.8 | 35.0 | 50.0 | 90 / 3 / 0 |
| `discrete` | `algorithms` | dev | 42 | 2.37 | 0.09 | 0.17 | 0.19 | 50.0 | 40 / 2 / 0 |
| `discrete` | `algorithms` | heldout | 42 | 2.53 | 0.10 | 0.18 | 0.19 | 50.0 | 40 / 2 / 0 |
| `discrete` | `calculus` | dev | 62 | 1.71 | 0.08 | 0.14 | 0.17 | 50.0 | 60 / 2 / 0 |
| `discrete` | `calculus` | heldout | 62 | 1.39 | 0.07 | 0.14 | 0.19 | 50.0 | 60 / 2 / 0 |
| `emoptics` | `electrical` | dev | 24 | 59.8 | 5.21 | 12.0 | 12.0 | 50.0 | 22 / 2 / 0 |
| `emoptics` | `electrical` | heldout | 24 | 60.1 | 5.19 | 12.1 | 12.1 | 50.0 | 20 / 4 / 0 |
| `emoptics` | `electronics` | dev | 111 | 55.4 | 0.10 | 0.13 | 0.16 | 50.0 | 108 / 3 / 0 |
| `emoptics` | `electronics` | heldout | 111 | 54.8 | 0.10 | 0.13 | 0.19 | 50.0 | 108 / 3 / 0 |
| `emoptics` | `electronics-r2` | dev | 111 | 54.1 | 0.09 | 0.14 | 0.16 | 50.0 | 108 / 3 / 0 |
| `emoptics` | `electronics-r2` | heldout | 111 | 55.5 | 0.09 | 0.14 | 0.15 | 50.0 | 108 / 3 / 0 |
| `emoptics` | `wiring` | dev | 42 | 63.5 | 35.2 | 67.7 | 67.8 | 50.0 | 39 / 3 / 0 |
| `emoptics` | `wiring` | heldout | 45 | 64.3 | 8.72 | 67.6 | 67.8 | 50.0 | 42 / 3 / 0 |
| `emoptics` | `optics` | dev | 70 | 80.3 | 0.12 | 28.5 | 28.8 | 50.0 | 67 / 3 / 0 |
| `emoptics` | `optics` | heldout | 61 | 83.1 | 0.12 | 28.3 | 28.7 | 50.0 | 58 / 3 / 0 |
| `emoptics` | `optics-v2` | dev | 68 | 83.3 | 0.14 | 28.4 | 28.6 | 50.0 | 65 / 3 / 0 |
| `emoptics` | `optics-v2` | heldout | 66 | 81.6 | 0.11 | 29.0 | 29.3 | 50.0 | 63 / 3 / 0 |
| `emoptics` | `optics-v3` | dev | 64 | 84.0 | 0.16 | 28.5 | 29.3 | 50.0 | 61 / 3 / 0 |
| `emoptics` | `optics-v3` | heldout | 67 | 83.5 | 0.12 | 28.9 | 29.0 | 50.0 | 50 / 17 / 0 |
| `emoptics` | `optics-v5` | dev | 74 | 82.4 | 0.17 | 28.9 | 29.5 | 50.0 | 71 / 3 / 0 |
| `emoptics` | `optics-v5` | heldout | 65 | 83.9 | 0.13 | 28.8 | 29.4 | 50.0 | 48 / 17 / 0 |
| `emoptics` | `optics-v5-r2` | dev | 74 | 82.5 | 0.18 | 29.1 | 31.9 | 50.0 | 71 / 3 / 0 |
| `emoptics` | `optics-v5-r2` | heldout | 65 | 87.2 | 0.15 | 29.6 | 30.6 | 50.0 | 48 / 17 / 0 |
| `energy` | `thermo` | dev | 44 | 4.64 | 0.10 | 0.18 | 0.23 | 50.0 | 40 / 4 / 0 |
| `energy` | `thermo` | heldout | 50 | 3.61 | 0.10 | 0.16 | 0.23 | 50.0 | 46 / 4 / 0 |
| `energy` | `energy-v2` | dev | 68 | 4.76 | 0.12 | 0.20 | 0.24 | 50.0 | 64 / 4 / 0 |
| `energy` | `energy-v2` | heldout | 74 | 3.78 | 0.11 | 0.20 | 0.26 | 50.0 | 70 / 4 / 0 |
| `energy` | `energy-v3` | dev | 74 | 4.06 | 0.12 | 0.20 | 0.24 | 50.0 | 70 / 4 / 0 |
| `energy` | `energy-v3` | heldout | 70 | 4.64 | 0.11 | 0.21 | 0.25 | 50.0 | 66 / 4 / 0 |
| `energy` | `hvac` | dev | 41 | 3.95 | 0.13 | 0.23 | 0.29 | 50.0 | 38 / 3 / 0 |
| `energy` | `hvac` | heldout | 42 | 3.61 | 0.13 | 0.19 | 0.22 | 50.0 | 39 / 3 / 0 |
| `energy` | `renewables` | dev | 26 | 8.57 | 0.19 | 4.36 | 4.36 | 50.0 | 23 / 3 / 0 |
| `energy` | `renewables` | heldout | 26 | 7.76 | 0.19 | 4.64 | 4.64 | 50.0 | 20 / 6 / 0 |
| `energy` | `iot` | dev | 27 | 4.90 | 0.14 | 0.30 | 0.30 | 50.0 | 24 / 3 / 0 |
| `energy` | `iot` | heldout | 27 | 5.25 | 0.13 | 0.34 | 0.34 | 50.0 | 24 / 3 / 0 |
| `facts` | `literature-v2` | dev | 18 | 2.58 | 0.37 | 1.99 | 1.99 | 50.0 | 16 / 2 / 0 |
| `facts` | `literature-v2` | heldout | 12 | 1.79 | 0.43 | 0.90 | 0.90 | 50.0 | 10 / 2 / 0 |
| `facts` | `worldhistory` | dev | 11 | 2.19 | 0.13 | 0.48 | 0.48 | 50.0 | 10 / 1 / 0 |
| `facts` | `worldhistory` | heldout | 11 | 1.11 | 0.15 | 0.39 | 0.39 | 50.0 | 10 / 1 / 0 |
| `facts` | `arthistory` | dev | 11 | 2.00 | 0.10 | 0.34 | 0.34 | 50.0 | 10 / 1 / 0 |
| `facts` | `arthistory` | heldout | 11 | 0.91 | 0.13 | 0.28 | 0.28 | 50.0 | 10 / 1 / 0 |
| `facts` | `medicine-r2` | dev | 9 | 1.19 | 0.29 | 0.49 | 0.49 | 50.0 | 8 / 1 / 0 |
| `facts` | `medicine-r2` | heldout | 9 | 2.32 | 0.27 | 0.61 | 0.61 | 50.0 | 8 / 1 / 0 |
| `facts` | `medicine` | dev | 9 | 1.23 | 0.25 | 0.47 | 0.47 | 50.0 | 8 / 1 / 0 |
| `facts` | `medicine` | heldout | 9 | 1.66 | 0.25 | 0.59 | 0.59 | 50.0 | 8 / 1 / 0 |
| `facts` | `law` | dev | 9 | 1.00 | 0.20 | 0.32 | 0.32 | 50.0 | 8 / 1 / 0 |
| `facts` | `law` | heldout | 9 | 2.45 | 0.19 | 0.39 | 0.39 | 50.0 | 8 / 1 / 0 |
| `facts` | `psychology` | dev | 9 | 2.50 | 0.24 | 0.30 | 0.30 | 50.0 | 8 / 1 / 0 |
| `facts` | `psychology` | heldout | 9 | 2.17 | 0.27 | 0.59 | 0.59 | 50.0 | 8 / 1 / 0 |
| `facts` | `sociology` | dev | 9 | 1.91 | 0.34 | 0.43 | 0.43 | 50.0 | 8 / 1 / 0 |
| `facts` | `sociology` | heldout | 9 | 0.87 | 0.34 | 0.60 | 0.60 | 50.0 | 8 / 1 / 0 |
| `facts` | `linguistics` | dev | 11 | 2.22 | 0.13 | 0.36 | 0.36 | 50.0 | 10 / 1 / 0 |
| `facts` | `linguistics` | heldout | 11 | 1.49 | 0.13 | 0.19 | 0.19 | 50.0 | 10 / 1 / 0 |
| `facts` | `poetry` | dev | 9 | 1.20 | 0.14 | 0.42 | 0.42 | 50.0 | 8 / 1 / 0 |
| `facts` | `poetry` | heldout | 9 | 2.41 | 0.13 | 0.25 | 0.25 | 50.0 | 8 / 1 / 0 |
| `facts` | `botany` | dev | 9 | 2.39 | 0.16 | 0.27 | 0.27 | 50.0 | 8 / 1 / 0 |
| `facts` | `botany` | heldout | 9 | 2.48 | 0.15 | 0.28 | 0.28 | 50.0 | 6 / 3 / 0 |
| `facts` | `entomology` | dev | 9 | 1.96 | 0.13 | 0.21 | 0.21 | 50.0 | 8 / 1 / 0 |
| `facts` | `entomology` | heldout | 9 | 2.25 | 0.14 | 0.19 | 0.19 | 50.0 | 8 / 1 / 0 |
| `facts` | `marinebio` | dev | 9 | 1.30 | 0.15 | 0.24 | 0.24 | 50.0 | 8 / 1 / 0 |
| `facts` | `marinebio` | heldout | 9 | 2.16 | 0.15 | 0.22 | 0.22 | 50.0 | 6 / 3 / 0 |
| `facts` | `ornithology` | dev | 9 | 2.25 | 0.11 | 0.22 | 0.22 | 50.0 | 8 / 1 / 0 |
| `facts` | `ornithology` | heldout | 9 | 1.29 | 0.12 | 0.42 | 0.42 | 50.0 | 6 / 3 / 0 |
| `facts` | `mycology` | dev | 9 | 2.38 | 0.12 | 0.31 | 0.31 | 50.0 | 8 / 1 / 0 |
| `facts` | `mycology` | heldout | 9 | 2.26 | 0.17 | 0.28 | 0.28 | 50.0 | 8 / 1 / 0 |
| `facts` | `mycelial` | dev | 7 | 2.15 | 0.18 | 0.27 | 0.27 | 50.0 | 6 / 1 / 0 |
| `facts` | `mycelial` | heldout | 7 | 1.95 | 0.24 | 0.25 | 0.25 | 50.0 | 6 / 1 / 0 |
| `facts` | `pets` | dev | 9 | 1.72 | 0.35 | 0.55 | 0.55 | 50.0 | 8 / 1 / 0 |
| `facts` | `pets` | heldout | 9 | 1.57 | 0.21 | 0.83 | 0.83 | 50.0 | 8 / 1 / 0 |
| `facts` | `childdev` | dev | 9 | 2.24 | 0.30 | 0.45 | 0.45 | 50.0 | 8 / 1 / 0 |
| `facts` | `childdev` | heldout | 9 | 2.48 | 0.42 | 0.54 | 0.54 | 50.0 | 8 / 1 / 0 |
| `facts` | `etiquette` | dev | 9 | 3.01 | 1.07 | 1.74 | 1.74 | 50.0 | 8 / 1 / 0 |
| `facts` | `etiquette` | heldout | 9 | 1.81 | 1.00 | 2.32 | 2.32 | 50.0 | 8 / 1 / 0 |
| `facts` | `firesafety-v2` | dev | 18 | 1.06 | 0.55 | 1.27 | 1.27 | 50.0 | 16 / 2 / 0 |
| `facts` | `firesafety-v2` | heldout | 10 | 1.19 | 0.59 | 1.31 | 1.31 | 50.0 | 9 / 1 / 0 |
| `facts` | `firstaid` | dev | 9 | 1.65 | 0.31 | 0.56 | 0.56 | 50.0 | 8 / 1 / 0 |
| `facts` | `firstaid` | heldout | 9 | 0.98 | 0.28 | 0.69 | 0.69 | 50.0 | 8 / 1 / 0 |
| `facts` | `javascript` | dev | 10 | 2.56 | 0.40 | 0.74 | 0.74 | 50.0 | 9 / 1 / 0 |
| `facts` | `javascript` | heldout | 10 | 1.02 | 0.36 | 0.47 | 0.47 | 50.0 | 9 / 1 / 0 |
| `fusion` | `lane-h+h2 battery` | - | 396 | 49.3 | 0.47 | 0.91 | 1.61 | - | 316 / 80 / 0 |
| `geostats` | `geometry` | dev | 106 | 13.9 | 1.24 | 2.79 | 3.08 | 50.0 | 102 / 4 / 0 |
| `geostats` | `geometry` | heldout | 97 | 14.4 | 1.16 | 2.57 | 2.74 | 50.0 | 85 / 12 / 0 |
| `geostats` | `geometry-v3` | dev | 100 | 16.2 | 3.73 | 8.40 | 8.68 | 50.0 | 96 / 4 / 0 |
| `geostats` | `geometry-v3` | heldout | 100 | 16.2 | 3.53 | 8.27 | 8.69 | 50.0 | 89 / 11 / 0 |
| `geostats` | `geometry-v4` | dev | 100 | 17.3 | 3.60 | 8.31 | 8.80 | 50.0 | 96 / 4 / 0 |
| `geostats` | `geometry-v4` | heldout | 93 | 16.0 | 3.65 | 7.88 | 8.89 | 50.0 | 89 / 4 / 0 |
| `geostats` | `statistics` | dev | 142 | 13.8 | 0.09 | 2.96 | 3.18 | 50.0 | 140 / 2 / 0 |
| `geostats` | `statistics` | heldout | 142 | 13.7 | 0.09 | 3.03 | 3.15 | 50.0 | 126 / 16 / 0 |
| `geostats` | `statistics-v2` | dev | 144 | 13.4 | 0.11 | 3.08 | 3.18 | 50.0 | 140 / 4 / 0 |
| `geostats` | `statistics-v2` | heldout | 144 | 12.9 | 0.10 | 3.07 | 3.21 | 50.0 | 126 / 18 / 0 |
| `geostats` | `statistics-v3` | dev | 144 | 13.5 | 0.10 | 3.09 | 3.24 | 50.0 | 140 / 4 / 0 |
| `geostats` | `statistics-v3` | heldout | 144 | 13.4 | 0.11 | 3.10 | 3.25 | 50.0 | 140 / 4 / 0 |
| `life` | `genetics-v2` | dev | 20 | 236.9 | 0.14 | 23.2 | 23.2 | 50.0 | 19 / 1 / 0 |
| `life` | `genetics-v2` | heldout | 20 | 230.4 | 0.12 | 22.4 | 22.4 | 50.0 | 14 / 6 / 0 |
| `life` | `biology` | dev | 15 | 217.4 | 0.06 | 0.07 | 0.07 | 50.0 | 14 / 1 / 0 |
| `life` | `biology` | heldout | 15 | 217.5 | 0.05 | 0.09 | 0.09 | 50.0 | 14 / 1 / 0 |
| `life` | `ecology` | dev | 13 | 348.0 | 27.6 | 149.1 | 149.1 | 50.0 | 13 / 0 / 0 |
| `life` | `ecology` | heldout | 13 | 335.5 | 27.2 | 121.3 | 121.3 | 50.0 | 13 / 0 / 0 |
| `life` | `forestry` | dev | 16 | 217.4 | 0.13 | 32.5 | 32.5 | 50.0 | 15 / 1 / 0 |
| `life` | `forestry` | heldout | 16 | 217.5 | 0.11 | 32.2 | 32.2 | 50.0 | 13 / 3 / 0 |
| `life` | `wildlife` | dev | 9 | 217.5 | 0.17 | 0.32 | 0.32 | 50.0 | 7 / 2 / 0 |
| `life` | `wildlife` | heldout | 9 | 218.1 | 0.12 | 0.24 | 0.24 | 50.0 | 5 / 4 / 0 |
| `life` | `microbiology-v2` | dev | 20 | 218.8 | 0.11 | 0.17 | 0.17 | 50.0 | 18 / 2 / 0 |
| `life` | `microbiology-v2` | heldout | 13 | 215.0 | 0.11 | 0.17 | 0.17 | 50.0 | 12 / 1 / 0 |
| `materials` | `additive-v2` | dev | 32 | 2.28 | 0.12 | 14.9 | 14.9 | 50.0 | 30 / 2 / 0 |
| `materials` | `additive-v2` | heldout | 20 | 2.29 | 0.12 | 13.6 | 13.6 | 50.0 | 19 / 1 / 0 |
| `materials` | `materials-v2` | dev | 34 | 51.3 | 0.18 | 51.7 | 51.7 | 50.0 | 28 / 6 / 0 |
| `materials` | `materials-v2` | heldout | 24 | 16.3 | 0.19 | 50.6 | 50.6 | 50.0 | 21 / 3 / 0 |
| `materials` | `soil` | dev | 36 | 1.44 | 0.09 | 0.20 | 0.20 | 50.0 | 33 / 3 / 0 |
| `materials` | `soil` | heldout | 36 | 0.96 | 0.09 | 0.24 | 0.24 | 50.0 | 33 / 3 / 0 |
| `materials` | `soil-r2` | dev | 36 | 0.83 | 0.09 | 0.26 | 0.26 | 50.0 | 33 / 3 / 0 |
| `materials` | `soil-r2` | heldout | 36 | 0.99 | 0.10 | 0.27 | 0.27 | 50.0 | 33 / 3 / 0 |
| `materials` | `water` | dev | 46 | 1.23 | 0.15 | 181.0 | 182.4 | 50.0 | 43 / 3 / 0 |
| `materials` | `water` | heldout | 47 | 1.36 | 0.14 | 177.8 | 178.5 | 50.0 | 44 / 3 / 0 |
| `mechanics` | `physics` | dev | 123 | 21.7 | 0.12 | 5.00 | 5.17 | 50.0 | 120 / 3 / 0 |
| `mechanics` | `physics` | heldout | 123 | 21.4 | 0.12 | 4.91 | 5.03 | 50.0 | 120 / 3 / 0 |
| `mechanics` | `physics-r2` | dev | 123 | 20.8 | 0.17 | 9.88 | 10.3 | 50.0 | 120 / 3 / 0 |
| `mechanics` | `physics-r2` | heldout | 123 | 19.9 | 0.19 | 9.65 | 10.3 | 50.0 | 120 / 3 / 0 |
| `mechanics` | `physics-r3` | dev | 123 | 21.0 | 0.19 | 9.94 | 10.3 | 50.0 | 120 / 3 / 0 |
| `mechanics` | `physics-r3` | heldout | 123 | 20.4 | 0.19 | 9.82 | 10.2 | 50.0 | 120 / 3 / 0 |
| `mechanics` | `mechanisms` | dev | 54 | 20.1 | 0.10 | 1.38 | 1.61 | 50.0 | 51 / 3 / 0 |
| `mechanics` | `mechanisms` | heldout | 64 | 19.8 | 0.10 | 1.27 | 1.29 | 50.0 | 54 / 10 / 0 |
| `mechanics` | `mechanisms-v2` | dev | 63 | 21.5 | 0.12 | 2.52 | 2.93 | 50.0 | 60 / 3 / 0 |
| `mechanics` | `mechanisms-v2` | heldout | 55 | 20.2 | 0.12 | 2.44 | 2.62 | 50.0 | 52 / 3 / 0 |
| `mechanics` | `bodies-v2` | dev | 38 | 21.1 | 2.70 | 4.11 | 4.11 | 600.0 | 36 / 2 / 0 |
| `mechanics` | `bodies-v2` | heldout | 38 | 20.2 | 2.65 | 4.07 | 4.07 | 600.0 | 36 / 2 / 0 |
| `mechanics` | `sports` | dev | 19 | 20.9 | 0.13 | 0.21 | 0.21 | 50.0 | 18 / 1 / 0 |
| `mechanics` | `sports` | heldout | 19 | 21.1 | 0.13 | 0.27 | 0.27 | 50.0 | 18 / 1 / 0 |
| `mechanics` | `fleet` | dev | 54 | 21.4 | 0.12 | 0.19 | 0.51 | 50.0 | 51 / 3 / 0 |
| `mechanics` | `fleet` | heldout | 54 | 21.1 | 0.12 | 0.27 | 0.53 | 50.0 | 51 / 3 / 0 |
| `mechanics` | `fluids-r2` | dev | 34 | 21.0 | 0.12 | 0.23 | 0.23 | 50.0 | 32 / 2 / 0 |
| `mechanics` | `fluids-r2` | heldout | 34 | 21.5 | 0.14 | 0.60 | 0.60 | 50.0 | 32 / 2 / 0 |
| `quantity` | `densities` | dev | 51 | 5.76 | 0.14 | 0.26 | 0.27 | 50.0 | 48 / 3 / 0 |
| `quantity` | `densities` | heldout | 51 | 5.83 | 0.14 | 0.22 | 0.31 | 50.0 | 48 / 3 / 0 |
| `quantity` | `units` | dev | 76 | 5.72 | 0.05 | 0.11 | 0.15 | 50.0 | 72 / 4 / 0 |
| `quantity` | `units` | heldout | 76 | 4.91 | 0.06 | 0.15 | 0.27 | 50.0 | 72 / 4 / 0 |
| `quantity` | `units-v3` | dev | 76 | 5.79 | 0.08 | 0.23 | 0.43 | 50.0 | 72 / 4 / 0 |
| `quantity` | `units-v3` | heldout | 75 | 5.79 | 0.09 | 0.26 | 0.48 | 50.0 | 71 / 4 / 0 |
| `quantity` | `springs` | dev | 42 | 4.81 | 0.11 | 3.53 | 3.61 | 50.0 | 40 / 2 / 0 |
| `quantity` | `springs` | heldout | 42 | 4.88 | 0.13 | 3.59 | 3.86 | 50.0 | 40 / 2 / 0 |
| `quantity` | `fluids` | dev | 34 | 4.80 | 0.10 | 0.16 | 0.16 | 50.0 | 32 / 2 / 0 |
| `quantity` | `fluids` | heldout | 34 | 4.72 | 0.11 | 0.20 | 0.20 | 50.0 | 32 / 2 / 0 |
| `quantity` | `fuels` | dev | 42 | 4.97 | 0.12 | 0.18 | 0.23 | 50.0 | 40 / 2 / 0 |
| `quantity` | `fuels` | heldout | 42 | 5.54 | 0.12 | 0.21 | 0.24 | 50.0 | 40 / 2 / 0 |
| `space` | `orbits` | dev | 35 | 165.8 | 20.3 | 74.0 | 74.0 | 50.0 | 32 / 3 / 0 |
| `space` | `orbits` | heldout | 35 | 167.6 | 20.1 | 73.9 | 73.9 | 50.0 | 32 / 3 / 0 |
| `space` | `planetary` | dev | 18 | 153.3 | 3.01 | 7.75 | 7.75 | 50.0 | 16 / 2 / 0 |
| `space` | `planetary` | heldout | 18 | 152.7 | 3.03 | 7.66 | 7.66 | 50.0 | 16 / 2 / 0 |
| `space` | `spacecraft` | dev | 21 | 179.0 | 26.7 | 35.9 | 35.9 | 50.0 | 20 / 1 / 0 |
| `space` | `spacecraft` | heldout | 21 | 181.8 | 0.20 | 36.6 | 36.6 | 50.0 | 13 / 8 / 0 |
| `space` | `spacecomms` | dev | 32 | 154.1 | 0.14 | 58.0 | 58.0 | 50.0 | 30 / 2 / 0 |
| `space` | `spacecomms` | heldout | 36 | 150.2 | 0.16 | 57.6 | 57.6 | 50.0 | 34 / 2 / 0 |
| `space` | `astronomy` | dev | 60 | 151.1 | 0.09 | 0.14 | 0.15 | 50.0 | 54 / 6 / 0 |
| `space` | `astronomy` | heldout | 81 | 155.0 | 0.08 | 0.15 | 0.16 | 50.0 | 77 / 4 / 0 |
| `space` | `astronomy-v2` | dev | 138 | 153.6 | 0.09 | 0.15 | 0.22 | 50.0 | 131 / 7 / 0 |
| `space` | `astronomy-v2` | heldout | 138 | 152.0 | 0.11 | 0.18 | 0.21 | 50.0 | 131 / 7 / 0 |
| `space` | `astronomy-v3` | dev | 138 | 154.7 | 0.11 | 0.19 | 0.20 | 50.0 | 131 / 7 / 0 |
| `space` | `astronomy-v3` | heldout | 138 | 150.8 | 0.12 | 0.17 | 0.27 | 50.0 | 130 / 8 / 0 |
| `space` | `astronomy-v3-r2` | dev | 138 | 152.4 | 0.11 | 0.17 | 0.20 | 50.0 | 131 / 7 / 0 |
| `space` | `astronomy-v3-r2` | heldout | 138 | 153.4 | 0.13 | 0.18 | 0.22 | 50.0 | 130 / 8 / 0 |
| `stores` | `cooking` | dev | 202 | 78.6 | 0.41 | 0.52 | 2.95 | 150.0 | 191 / 11 / 0 |
| `stores` | `cooking` | heldout | 218 | 77.5 | 0.39 | 0.58 | 3.56 | 150.0 | 148 / 70 / 0 |
| `stores` | `cooking-v2` | dev | 210 | 82.9 | 0.40 | 0.53 | 3.51 | 150.0 | 199 / 11 / 0 |
| `stores` | `cooking-v2` | heldout | 210 | 80.7 | 0.42 | 0.51 | 3.28 | 150.0 | 145 / 65 / 0 |
| `stores` | `cooking-v3` | dev | 192 | 78.7 | 0.41 | 0.54 | 3.65 | 150.0 | 182 / 10 / 0 |
| `stores` | `cooking-v3` | heldout | 228 | 76.4 | 0.39 | 0.56 | 3.40 | 150.0 | 216 / 12 / 0 |
| `stores` | `cooking-v3-r2` | dev | 192 | 74.7 | 0.39 | 0.49 | 2.81 | 150.0 | 182 / 10 / 0 |
| `stores` | `cooking-v3-r2` | heldout | 228 | 78.6 | 0.39 | 0.56 | 3.36 | 150.0 | 216 / 12 / 0 |
| `stores` | `warehouse` | dev | 199 | 33.5 | 0.74 | 2.07 | 4.83 | 50.0 | 185 / 14 / 0 |
| `stores` | `warehouse` | heldout | 199 | 31.7 | 0.78 | 1.96 | 4.66 | 50.0 | 185 / 14 / 0 |
| `stores` | `warehouse-r2` | dev | 199 | 31.2 | 0.74 | 1.92 | 4.64 | 50.0 | 185 / 14 / 0 |
| `stores` | `warehouse-r2` | heldout | 199 | 30.4 | 0.89 | 1.82 | 4.71 | 50.0 | 185 / 14 / 0 |
| `trades` | `architecture` | dev | 10 | 2.47 | 0.16 | 0.27 | 0.27 | 50.0 | 9 / 1 / 0 |
| `trades` | `architecture` | heldout | 10 | 1.15 | 0.12 | 0.23 | 0.23 | 50.0 | 9 / 1 / 0 |
| `trades` | `printing` | dev | 39 | 7.33 | 0.15 | 5.53 | 5.53 | 50.0 | 36 / 3 / 0 |
| `trades` | `printing` | heldout | 36 | 8.82 | 0.16 | 5.95 | 5.95 | 50.0 | 27 / 9 / 0 |
| `trades` | `printing-v2` | dev | 36 | 9.17 | 0.18 | 8.27 | 8.27 | 50.0 | 33 / 3 / 0 |
| `trades` | `printing-v2` | heldout | 37 | 10.1 | 0.16 | 9.03 | 9.03 | 50.0 | 34 / 3 / 0 |
| `trades` | `safety` | dev | 44 | 18.9 | 0.42 | 114.2 | 114.9 | 50.0 | 40 / 4 / 0 |
| `trades` | `safety` | heldout | 45 | 21.8 | 0.26 | 113.5 | 114.5 | 50.0 | 41 / 4 / 0 |
| `trades` | `woodworking` | dev | 36 | 1.50 | 0.12 | 13.7 | 13.7 | 50.0 | 33 / 3 / 0 |
| `trades` | `woodworking` | heldout | 36 | 1.84 | 0.10 | 14.2 | 14.2 | 50.0 | 30 / 6 / 0 |
| `trades` | `crafts` | dev | 14 | 1.98 | 0.12 | 0.24 | 0.24 | 50.0 | 13 / 1 / 0 |
| `trades` | `crafts` | heldout | 14 | 0.80 | 0.11 | 0.37 | 0.37 | 50.0 | 13 / 1 / 0 |
| `variants` | `densities-r2` | dev | 51 | 5.93 | 0.23 | 0.33 | 0.42 | 50.0 | 48 / 3 / 0 |
| `variants` | `densities-r2` | heldout | 51 | 6.37 | 0.26 | 0.37 | 0.45 | 50.0 | 48 / 3 / 0 |
| `variants` | `units-v2` | dev | 75 | 6.68 | 0.10 | 0.27 | 0.46 | 50.0 | 71 / 4 / 0 |
| `variants` | `units-v2` | heldout | 74 | 5.48 | 0.08 | 0.18 | 0.36 | 50.0 | 39 / 35 / 0 |
| `variants` | `units-v3-r2` | dev | 76 | 5.76 | 0.10 | 0.19 | 0.33 | 50.0 | 72 / 4 / 0 |
| `variants` | `units-v3-r2` | heldout | 75 | 6.03 | 0.09 | 0.27 | 0.52 | 50.0 | 71 / 4 / 0 |

### Oracle7 head, per family (the same questions, one process)

| Family | n | p50 ms | p95 ms | max ms |
|---|---:|---:|---:|---:|
| `space` | 1185 | 278.7 | 1491 | 8417 |
| `life` | 179 | 137.0 | 1469 | 1922 |
| `climate` | 306 | 78.6 | 1393 | 2486 |
| `facts` | 428 | 103.0 | 1348 | 6776 |
| `computing` | 1364 | 204.2 | 1305 | 2331 |
| `stores` | 2476 | 160.0 | 1132 | 2034 |
| `trades` | 357 | 174.8 | 1023 | 3432 |
| `discrete` | 508 | 75.3 | 978.3 | 2572 |
| `chemistry` | 1206 | 459.6 | 909.5 | 1023 |
| `materials` | 347 | 130.9 | 897.1 | 1502 |
| `variants` | 402 | 171.4 | 593.5 | 882.8 |
| `quantity` | 641 | 137.7 | 551.1 | 816.9 |
| `geostats` | 1456 | 103.0 | 548.8 | 1063 |
| `emoptics` | 1253 | 103.1 | 536.5 | 2465 |
| `energy` | 569 | 103.5 | 522.4 | 1404 |
| `anatomyagri` | 156 | 61.0 | 502.2 | 1382 |
| `mechanics` | 1264 | 128.3 | 466.9 | 1472 |
| `acoustics` | 139 | 56.4 | 180.5 | 3565 |
| `fusion` | 396 | 89.1 | 139.0 | 335.3 |

*Generated by `tools/perf/fleet.py` (JSON sidecar: fleet.json).*
