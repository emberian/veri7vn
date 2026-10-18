# Lane W5-04: every landed family on Linux

Status: done. 22 families built on Linux, scored with the lane A harness against the shipped panels, and every panel reply compared with the macOS binary: 15,743 panel items, 16,667 panel replies (fusion's 924 core questions included), 0 divergent. Receipts: `docs/deploy/linux/<slug>.md` and the table in `docs/deploy/linux/README.md`. The 22 are quantity, acoustics, mechanics, fusion, space, earth, emoptics, climate, energy, chemistry, materials, life, anatomyagri, geostats, discrete, finance, trades, computing, humanities, stores, facts, variants. rel-novels is build-only.

## What was done

- `tools/deploy/linux-family.py <slug> <host>` (new; generalises the scout's `linux-build.sh`): remote-build of the session, MLton step with the MLB read from the family's own `build.sh` (so humanities' rules.sml, stores' config.sml and variants' recognizer rewrite are handled), harness on the host, cold start, pull, per-item comparison with the macOS run. It stages sources and the fetched export under `~/veri7vn-deploy/stage` because remote-build now deletes its tree. Hosts alternated: persvati took quantity, acoustics, mechanics, space, earth, climate, chemistry, life, humanities, facts, computing; hbox the rest.
- macOS baselines: the same harness flags, run into `var/linux/macos/<slug>` (not committed). For chemistry and computing the macOS binary in `var/` was older than the sources, so the baseline binary was rebuilt from the same export into `var/linux/macbin/`.
- The generated SML is sha256-identical to the macOS export for 20 of 22 (computing and geostats macOS build dirs were older); Isabelle code generation is host-independent as the scout found.

## Findings

1. Zero divergence once baselines are current. Without a rebuild, chemistry showed 124 diverging replies (the macOS binary withheld items the current recognizer answers).
2. computing at HEAD (15395f7) does not build on Linux: `Sql.thy` line 400 and `Numerics.thy` line 80 "Failed to finish proof" (log `var/linux/computing-fail-HEAD.log`, not committed). The receipt is for 32dd0ff. It is not known whether this is Linux-specific; lane W6-05 owns it.
3. The PASS marker is only in the log of a fresh build on RC1; the new remote-build (whole stored log, `--expect`) finds it.
4. Other lanes build the same sessions on the same hosts. Before the per-session lock this produced sqlite constraint errors and empty exports; the driver retries.
5. Cold starts of life 194 ms, space 154 ms, stores 74 ms are over the 50 ms budget on the Linux hosts (the others are 1 to 31 ms); I did not check them against macOS.
6. Incident, mine: I ran `isabelle build -f` on hbox once to get a marker. `-f` forces parents, so it started rebuilding Pure and HOL in the shared user-state and died on an sqlite error. A following `build -n` showed all sessions up to date and later builds ran, but root may want to check hbox's HOL heap.

## Not covered

One host per family (the other host only for acoustics, quantity at the scout stage). No libgmp-free or older-glibc run. Fusion has no panel of its own. The rel-novels panel was not run on Linux.

## Cleanup

hbox and persvati `~/veri7vn-deploy/{build,stage,bin,out,assert}` were removed at the end; the tool and receipts are the record. Worktree `var/linux/wt-computing` removed.
