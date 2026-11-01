# G — finite integer/list programs from actual examples

Wrap-up preservation: the unfinished eleven-file draft is committed and pushed
on `codex/parked-codeorgan-integer-20261018`, commit `7c3cafa`. Its branch-only
`project/parked/codeorgan-integer-20261018.json` records exact file hashes and
the blocker. Active checkout files now match the committed working predecessor;
the draft is no longer left dirty. No functionality or proof completion is
claimed by archiving it. Local copies and original failed receipts are retained.

Owner: codeorgan_sol. This succeeds `345f77b`. Runtime owns the independent
shared consumer. **No code-organ specialist panel is shipped.** These are
scoped route checks, not a specialist scoreboard result.

## Behavior and boundaries

The route now accepts a single structured or literal prose example, without
inventing another. The response explicitly says that this example does not
determine behavior on other inputs. Existing additional bounded observations
still check candidate ambiguity; they do not prove equivalence or discover a
user's intended total function.

The finite language adds signed integer gcd and factorial for inputs 0 through
100. Gcd results are nonnegative and gcd(0,0) is zero. The emitted factorial
source checks its domain before calling math.factorial. Strict input guards
reject Boolean arguments. The native transport now carries expected results
up to magnitude 10**240; initial input magnitude remains 10**30.

Existing moves also support doubling integer lists, merging and sorting two
lists, and ranked elements with explicit duplicate policy. Ambiguous second
largest examples without repeated values are withheld because distinct-value
and duplicate-counting candidates disagree on other observations. Unsupported
strings and Celsius/Fahrenheit conversion remain outside this integer/list
language. Request text, supplied definitions and stored source are never run.

The actual upstream source is
`upstream/root/fable-content/oracle-m-series-2026-08-15/self_loop/code_library_v1.json`.
Its 15 stored descriptions, read as data, are included unchanged in the new
probe corpus. Supported prose examples retain exactly their single supplied
case. This is a bounded comparison with stored requests, not an upstream
specialist scorer or an independent held-out English benchmark.

## New theorem statements

The successful proof scans six new oracle-free roots, in addition to the previous 16:

- If running Combine GcdInt on Number a and Number b returns Number d, then
  0 <= d, d divides a, d divides b, and every common divisor c divides d.
- Combine GcdInt on zero and zero returns zero.
- Negating both gcd arguments leaves the result unchanged.
- Factorial on Number n returns Number y iff 0 <= n <= 100 and
  y = int(fact(nat n)).
- Factorial on zero returns one.
- For natural n < 100, factorial on int(Suc n) returns
  int(Suc n) * int(fact n).

The generated evaluator is the native checker's actual operator computation.
`check_every_example` connects an accepted nonempty case set to every supplied
result. The statements do not verify English interpretation, candidate choice,
Python rendering, framing or the external consumer. Those remain untrusted;
the dispatcher independently replays each packet and checks exact displayed
source and request binding.

## Actual result: not integrated

The final managed proof passed, completed uncancelled, and exported its durable
marker: `VERI7VN_CODEORGAN PASS theorems=22 oracles=0`.

- Proof: `var/codeorgan/remote-attempts/20261018T102705Z-9acda4c0d283/receipt.json`.
- Native: `var/codeorgan/native-attempts/20261018T103836Z-2c36b6a15f94/compile-inputs.json`.
- Immutable native binary SHA-256:
  `36792b28bb523e798c1e25d1166d1cd5d9f49faac1293e0c9c35d73f00736bbf`.
- Generated evaluator SHA-256:
  `8c7f3f6a43c60c0afaac4d3dde3d6c884e297c3ef99d6e723f1f76ed4e35d828`.
- Frontdoor SHA-256:
  `f3153b1a4fb4e4ee84ffe8ff81ee512c2cda25d8ca4b57e56e6903653453a9ed`.
- `var/codeorgan-sol/integer-closure.json` records that every current proof
  dependency and native source matched the captured manifest before restoration.

The complete factorial native gate **failed**. Its first batch, inputs 0 through
49, produced no reply within the existing five-second owned-child limit.
`Kernel.check` raised `RuntimeError: code checker timed out; request was not
replayed`, and closed/reaped its exact child. The generated evaluator computes
factorial with `fold_atLeastAtMost_nat times_nata`; `times_nata` multiplies unary
`Zero_nat`/`Suc` values before converting the result to an integer. Thus the
mathematical bound 100 is not a practical native bound in this export.
`var/codeorgan-sol/integer-failure.json` preserves the failed command and gate.

Because this failure occurred first, the complete 101-factorial, 200-gcd,
41-authored, 120-reserved and 41-full-default checks were **not completed**.
Those prepared counts are not passing results. The 41-request corpus intends
18 supported, 12 withheld valid and 11 invalid refusals; the actual stored
upstream subset intends 7 supported of 15. Those are expectations, not measured
successes. Exact stored descriptions and source SHA are recorded in
`var/codeorgan-sol/integer-upstream-source.json`.

Measured checks that did run against the fresh native:

- Existing 360 independent evaluator references pass: 348 defined and 12
  undefined cases, split across authored/reserved seeds.
- Existing 56 producer controls: 36 supported, 10 withheld valid, 10 invalid
  refused, zero wrong/false yes. The one-example control intentionally becomes
  supported. `var/codeorgan-sol/check.json` records these results.
- Actual JSONL producer and independent shared consumer: all 56 IDs match,
  36 answers replay consistently, 20 refuse, injection marker absent.
  Receipt: `var/codeorgan-sol/consumer.json`.
- Runtime's 14 shared-consumer methods pass, including gcd, factorial source
  guards, large expected results and mutations. These are fixture evidence.
- Runtime's independently authored eight full-default requests achieve only
  **5/8 requested outcomes**: gcd, ranked distinct selection and doubling answer;
  factorial zero and six produce withheld stage errors; sorted-merge is a valid
  refusal; two invalid controls refuse. Three actual answered packets pass 12
  mutation rejections. Receipt: `var/runtime-default/code-integer-final.json`.
  This is further evidence that the packet is not ready, rather than a green
  bounded-domain result.

## Preservation, operational restoration and resume

Root explicitly stopped further proof attempts and integration for this drain.
All dirty source remains available. The new 22-root proof, native inputs and
binary remain immutable. Only this lane's canonical operational native,
generated-export and compile-receipt aliases were restored to the committed
predecessor after runtime's owned eight-request process finished. Restored
native SHA is `d781175bec2637a13ad9b2a26843d8c2cd7857899072719d1571a4e28f2f6fae`;
manifest is
`var/codeorgan/native-attempts/20261018T084706Z-ad14887c769b/compile-inputs.json`.
The new compatibility export was retained as
`var/codeorgan/export-remote/Veri7vn_CodeOrgan.withheld-integer-20261018T103836Z-2c36b6a15f94`.
`var/codeorgan-sol/integer-restoration.json` checks all restored alias hashes.
Current operational tests must use committed producer and consumer snapshots,
not the uncommitted integer draft. Runtime owns that shared-consumer boundary.

The required next repair is an **efficient proved code equation**, not a longer
timeout or a hand-edited generated evaluator. A bounded natural countdown with
an integer accumulator can calculate the result without materializing its
factorial value as a unary natural. Prove that helper equals
`int(fact(nat n))` on the admitted domain, connect it to Factorial's generated
computation, and inspect the actual export for integer accumulator arithmetic.
After that repair, submit a new managed proof attempt and compile from that
exact passed receipt; do not reuse the current export as repaired computation.
Then rerun only these remaining gates:

```sh
tools/dev/remote-build persvati src/extract/codeorgan Veri7vn_CodeOrgan --expect 'VERI7VN_CODEORGAN PASS theorems=22 oracles=0'
src/extract/codeorgan/build.sh /absolute/path/to/new/passed/receipt.json
python3 src/extract/codeorgan/check_integer.py
python3 src/extract/codeorgan/check.py
python3 src/extract/codeorgan/check_consumer.py
```

Coordinate runtime's independent full-default gate again only after the complete
factorial domain passes; inspect the sorted-merge refusal if it remains. No new
successor or scope expansion is part of this handoff.
