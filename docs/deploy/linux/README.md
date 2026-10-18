# Linux deployment receipts

Lane W5-04. Each family under `src/extract/` was built from its HOL session on a Linux host (Isabelle2026-RC1, generated SML compiled by the MLton shipped inside it), its binary run through the lane A harness against the shipped panels staged on the host, and every per-item reply compared with the macOS binary on the same panels (timing fields `rtt_ms` and `provenance.specialist_ms` removed). One receipt per family sits next to this file; `tools/deploy/linux-family.py` reproduces a row.

| family | host | specialists | panel items | right | wrong | false yes | panel replies compared | divergent panel replies | verdicts equal | generated SML == macOS | Linux bytes | macOS bytes | cold start (min ms) | session build s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [acoustics](acoustics.md) | persvati | 1 | 139 | 139 | 0 | 0 | 139 | 0 | True | True | 904,168 | 429,016 | 4.6 | 86 |
| [anatomyagri](anatomyagri.md) | hbox | 5 | 156 | 154 | 0 | 0 | 156 | 0 | True | True | 885,864 | 405,112 | 1.7 | 121 |
| [chemistry](chemistry.md) | persvati | 5 | 1206 | 1206 | 0 | 0 | 1206 | 0 | True | True | 1,547,832 | 776,312 | 1.4 | 126 |
| [climate](climate.md) | persvati | 6 | 306 | 285 | 0 | 0 | 306 | 0 | True | True | 1,270,048 | 619,944 | 30.8 | 153 |
| [computing](computing.md) | persvati | 9 | 1364 | 1274 | 1 | 0 | 1364 | 0 | True | False | 2,633,864 | 1,295,736 | 8.3 | 222 |
| [discrete](discrete.md) | hbox | 5 | 508 | 508 | 0 | 0 | 508 | 0 | True | True | 1,970,256 | 891,032 | 1.4 | 152 |
| [earth](earth.md) | persvati | 8 | 554 | 549 | 0 | 0 | 554 | 0 | True | True | 1,833,800 | 918,936 | 589.5 | 123 |
| [emoptics](emoptics.md) | hbox | 9 | 1253 | 1196 | 13 | 0 | 1253 | 0 | True | True | 1,699,096 | 760,296 | 23.4 | 103 |
| [energy](energy.md) | hbox | 6 | 569 | 559 | 7 | 0 | 569 | 0 | True | True | 1,540,688 | 760,920 | 3.1 | 89 |
| [facts](facts.md) | persvati | 22 | 428 | 421 | 0 | 0 | 428 | 0 | True | True | 638,728 | 334,568 | 2.3 | 181 |
| [finance](finance.md) | hbox | 5 | 559 | 559 | 0 | 0 | 559 | 0 | True | False | 1,498,464 | 722,760 | 1.1 | 155 |
| [fusion](fusion.md) | hbox | 0 | 924 core | 119 answered | - | - | 924 | 0 | n/a | True | 842,216 | 386,568 | n/a | 573 |
| [geostats](geostats.md) | hbox | 6 | 1456 | 1413 | 0 | 0 | 1456 | 0 | True | False | 1,246,912 | 613,528 | 7.3 | 143 |
| [humanities](humanities.md) | persvati | 7 | 394 | 389 | 0 | 0 | 394 | 0 | True | True | 1,389,336 | 629,192 | 0.9 | 188 |
| [life](life.md) | persvati | 6 | 179 | 170 | 0 | 0 | 179 | 0 | True | True | 1,572,120 | 738,168 | 194.0 | 190 |
| [materials](materials.md) | hbox | 6 | 347 | 347 | 0 | 0 | 347 | 0 | True | True | 1,725,920 | 775,416 | 1.2 | 134 |
| [mechanics](mechanics.md) | persvati | 9 | 1264 | 1257 | 0 | 0 | 1264 | 0 | True | True | 1,422,464 | 655,928 | 14.8 | 190 |
| [quantity](quantity.md) | persvati | 6 | 641 | 641 | 0 | 0 | 641 | 0 | True | True | 1,246,760 | 545,864 | 3.8 | 12 |
| [space](space.md) | persvati | 8 | 1185 | 1155 | 21 | 0 | 1185 | 0 | True | True | 1,539,904 | 719,384 | 154.4 | 22 |
| [stores](stores.md) | hbox | 6 | 2476 | 2348 | 7 | 0 | 2476 | 0 | True | True | 1,328,312 | 564,184 | 74.1 | 12 |
| [trades](trades.md) | hbox | 6 | 357 | 348 | 0 | 0 | 357 | 0 | True | True | 1,757,288 | 812,104 | 1.5 | 168 |
| [variants](variants.md) | hbox | 3 | 402 | 371 | 0 | 0 | 402 | 0 | True | True | 1,297,592 | 578,360 | 3.1 | 157 |

Totals: 22 families, 15,743 panel items scored, 16,667 panel replies compared, 0 divergent.

Also: [rel-novels](rel-novels.md), build-only (no answerer binary; session builds on Linux, export sha1 equal to W5-01's).

## Reading the table

- "right" counts panel items the shipped scorer accepts; "wrong" and "false yes" are the same on macOS, item for item. Families with nonzero "wrong" (emoptics, energy, space, stores, computing) have exactly the same wrong items on macOS; this lane did not re-examine why.
- "divergent panel replies" is the number of panel items whose reply differs between the Linux and macOS binaries, after removing the timing fields. Every family has 0. The harness also replays the 924 core-panel questions per specialist and split; those replies (265,694 in all) were compared too and also match.
- "generated SML == macOS" is False for computing and geostats only because the macOS build directory held an older export than the source being built; replies still match (see their receipts).
- chemistry and computing: the macOS binary in `var/<slug>/bin` predates commits by other lanes, so the comparison baseline was rebuilt from the same export and sources (`var/linux/macbin/`). Without that, chemistry showed 124 diverging replies purely from the stale binary.
- computing was built from commit 32dd0ff. At HEAD the session fails to build on Linux (Sql.thy line 400, Numerics.thy line 80). Open item for lane W6-05.
- fusion has no panel of its own; its 924 questions are the core panel, answered through `tools/fusion/answerer.py`.
- Cold starts of life (194 ms), space (154 ms) and stores (74 ms) exceed the 50 ms budget on the Linux hosts; not compared with macOS cold starts here.
- Linux binaries are about 2.1 times the macOS ones (x86-64 code, unstripped) and need libgmp10.
