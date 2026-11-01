# W6-26 space-memory: `decline_text` split

## What changed

`src/extract/space/Space.thy` only. `decline_text` was a `fun` with nine overlapping clauses over
27 request constructors times 6 decline constructors; Isabelle's function package completes such
patterns into hundreds of cases, which is what cost the memory. It is now a plain `definition`
that cases on the decline and calls one small text function per kind:
`need_text` (unchanged), `nosync_text`, `impossible_text` (now a `definition`, was a `fun`),
`unknown_text`, `novalue_text`. Each of the new ones is a `case` over the request with one special
constructor and a default. Every exported constant fusion uses keeps its name and type
(`decline_text`, `reply_of`, `kernel`, ...); nothing in `Fusion_Nodes.thy` changed. The wording of
every reply is the same strings in the same order.

## Memory and time (persvati, fresh `-f` builds, `-j 1 -o threads=2`, sampled VmHWM of the Isabelle poly process every 0.5 s)

| session | peak before | peak after | build time before | build time after |
|---|---|---|---|---|
| Veri7vn_Space | 6.55 GB | 3.24 GB | 4:16 | 1:04 |
| Veri7vn_Fusion | 10.25 GB | 4.06 GB | 5:32 | 2:04 |

(Space_Base 2.3 to 2.5 GB and Quantity_Base 2.2 to 2.5 GB are the floor of any session in the
chain.) The Fusion figure is a few percent over the 4 GB target; the upstream Quantity session
that Fusion needs peaked at 4.4 GB in the before run and 7.0 GB in the after run, so poly's heap
growth on the shared box is noisy at that size and that session is not this lane's. The cgroup
`memory.peak` of the whole scope (which also counts the JVM, about 5 GB, and page cache) read
12.8 GB before and 8.0 GB after for the Space build. The script is `var/space/w626-measure.sh`.

## Checks

- `VERI7VN_SPACE PASS theorems=104 oracles=0` on persvati (marker last, same theorem count as W6-22).
- `VERI7VN_FUSION PASS` on persvati from the same tree.
- Space binary rebuilt from the remote export (`src/extract/space/build.sh`, 745,208 bytes);
  `tools/parity/harness.py` over all eight specialists, both splits: 1,185 replies, 0 changed against
  `var/space/parity-w6-after` (reply text, value, kind, path and provenance compared; only the timing
  fields differ).
- Fusion's generated SML is byte-identical to the previous `var/fusion/build/fusion_generated.sml`
  (fusion exports no code from `decline_text`); the fusion binary was relinked anyway.
  `tools/fusion/measure.py`: core network items 101/102 same text, 1 declined (needs geometry-v4), 12 validity same, space panels
  composed 1155 right of 1185, verdict changed 0.

## Not done

Nothing is claimed about the astronomy heldout wrongs (unchanged). Fusion's peak is 4.06 GB, not strictly under 4.
