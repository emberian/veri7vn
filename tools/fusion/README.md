# tools/fusion: the untrusted side of specialist fusion

The fusion planner itself is a proved HOL function (`src/extract/fusion/Fusion.thy`), compiled
into `var/fusion/bin/fusion`. This folder holds the parts that are not proved.

- `answerer.py` speaks the [answerer contract](../../docs/contracts/answerer.md). It reads a
  question the way Oracle7's network does (a port of `network_v2.read_givens`, `read_goal`,
  `normalise` and `network_v3.read_flags_v3`, `attached`, `depth_attached`), with exact fractions
  instead of floating point. It sends the typed givens, goal and context facts to the binary, and
  writes the binary's decision as Oracle7's network replies read: `The answer is 1431 mj. (path:
  densities → fuels → core_math)`, with path `veri7vn:fusion>densities fuels core_math`.
  It decides nothing: which plan, whether plans agree, validity, the single-conversion and echo
  rules and every specialist value come from the binary.
  Options: `--agree pairwise` (default, every two shallowest plans must agree) or
  `--agree anchor` (network_v3 as shipped: every plan is compared with the first one found).
- `measure.py` compares the answerer with what Oracle7 answered on its network routes, re-asks
  every specialist call in English to lane G's binary, and scores lane G's six panels with and
  without fusion behind lane G. It writes `var/fusion/measure.json`.

What can go wrong here and is not caught by a proof: reading the question (units, roles, which
material an amount is attached to), and the layout of the reply text.

```sh
sh src/extract/fusion/build.sh
echo '{"id": "1", "q": "How much energy in MJ is released by burning 40 litres of diesel?"}' \
  | python3 tools/fusion/answerer.py
python3 tools/fusion/measure.py
```
