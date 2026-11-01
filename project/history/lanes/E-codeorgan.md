# E — code organ

Owner: codeorgan_sol. Paths: `src/extract/codeorgan/` and this report.
Scratch: `var/codeorgan-sol/`. Runtime owns registry, dispatch and independent
consumer replay; build owns the managed drivers.

Changed files under `src/extract/codeorgan/`: `ROOT`, `CodeOrgan.thy`,
`CodeOrgan_Export.thy`, `main.sml`, `build.sh`, `answerer.py`, `README.md`,
`probes.json`, `check.py`, `check_consumer.py`, `compare_upstream.py` and
`test_lifecycle.py`; plus this report. Shared runtime changes belong to its
separate owner and packet.

## Completion measure

**No shipped code-organ specialist panel exists**, so this lane has no shipped
specialist-panel score. This head route is not a newly invented specialist ID.
Authored route checks and direct Oracle7 code chat comparisons are reported
separately below when native verification completes.

## Implemented capability

A closed typed-data library builds small functions from one argument or a
binary combination of two arguments, followed by up to four named moves.
Examples must contain bounded literal integers/lists; Boolean outputs remain
a distinct type. Search never treats an expected output as a program constant.
User code is not executed. The response only claims consistency with all
supplied examples. Competing fits that disagree on extra observations receive
a clarification prompt; agreeing observations do not establish equivalence.

The native checker is generated from HOL; the Python recognizer, source
renderer, JSON framing and independent consumer replay are untrusted. A packet
carries the AST, examples, results and displayed source rather than presenting
static theorem names as evidence for an individual response.

## Actual statements

The 16 oracle-scan roots include these mathematical statements (variables are
universally quantified):

- `check_program p cases ==> cases ~= []`.
- `check_program p cases ==> (args,want) : set cases ==> run p args = Some want`.
- Membership of an example whose `run` returns `None`, or a different value,
  implies the checker rejects the program.
- `steps (xs@ys) v = (case steps xs v of None => None | Some w => steps ys w)`.
- `lookup args n = Some v ==> n < length args & args ! n = v`.
- Sorting an integer list produces a sorted list with the same multiset.
- Deduplicating an integer list produces a distinct list with the same set.
- For every integer list `xs`, running `[KeepEven,SquareEach,Sum]` on argument
  zero returns `Some (Number (sum_list (map (%x. x*x) (filter even xs))))`.
- Squaring every element then taking length preserves the original length.
- Concatenating two lists then taking length returns the sum of their lengths.
- Adding two integer arguments returns their mathematical sum.
- Reversing twice is the identity; maximum/minimum on an empty list return
  `None`; squaring a Boolean returns `None`.

See `CodeOrgan.thy` for exact syntax and all statements. No theorem says that
English descriptions were interpreted correctly, examples are a complete
specification, or rendered Python was formally proved equivalent.

## Proof and native checks

The successful managed proof is
`var/codeorgan/remote-attempts/20261018T084300Z-b323751ec5fc/receipt.json`:
status `passed`, completed and uncancelled; 16 theorem roots, zero oracles,
self-test and durable assertion `VERI7VN_CODEORGAN PASS theorems=16 oracles=0`.
The source snapshot digest is
`3768696c27dc6bb00bba32c3f696c45e38899a6693947e42a4a070f3fca39726`.
Earlier attempts found an incomplete lookup induction and an unimported `mset`
notation; both were repaired before native use. Sorting now explicitly
preserves `count_list` for every element rather than relying on a free name.

The immutable native capture is
`var/codeorgan/native-attempts/20261018T084706Z-ad14887c769b/compile-inputs.json`.
It records `compile_ok: true`, current proof source context, and the exact
consumed generated export (`3b0a824f903dc9323a279a4dcaccd8e73ddcf8d56182e7101e366f183a13c571`),
shared commons and typed native framing. The binary is
`var/codeorgan/bin/codeorgan-kernel`, SHA-256
`d781175bec2637a13ad9b2a26843d8c2cd7857899072719d1571a4e28f2f6fae`.
The Python frontdoor is a separate untrusted input, captured by the actual
consumer check, not represented as part of the generated native theorem.

`python3 src/extract/codeorgan/check.py` passes 360 independent-reference
native cases: 348 defined results match and 12 undefined programs are refused.
The author split has 195 defined / 5 undefined, and the reserved seed has
153 defined / 7 undefined. It also passes 56 frontdoor requests: **35 supported,
11 withheld valid, 10 invalid refused, zero wrong, zero false yes**. Receipts
are in `var/codeorgan-sol/check.json`. The reserved arithmetic generator is
independent of the candidate recognizer, but this is not an untouched English
benchmark or a shipped specialist panel.

`python3 src/extract/codeorgan/check_consumer.py` drives the actual Python
frontdoor and native process through JSON lines. All 56 IDs/statuses match;
35 answer packets independently replay through `tools/code_evidence.py` and
have matching displayed source; 21 requests withhold; process exit is zero.
The request-injection sentinel is absent. `var/codeorgan-sol/consumer.json`
records full replies, actual script hash
`05bb3ef0c6a8333057ba77d638ac2fb996dca51a6afea22d4f88adcd4030f3cf`,
consumer hash and binary hash. Emitted source has strict type guards and
refuses function names that would shadow template globals. Actual responses
state deduplication's last-occurrence order and pairwise truncation when used.

The eight scoped independent-consumer tests pass. Runtime also repeated six
independently authored actual answer packets and seven packet mutations; the
former pass and the mutations reject. Its receipt is
`var/C-runtime-consumers/code-native-final.json`. Three real subprocess tests
also pass: native EOF, a checker ignoring EOF, and an in-flight checker ignoring
SIGTERM. Cleanup signals only the exact owned child, reaps it within the
adapter's two-second termination grace, and never replays an uncertain request.
See `var/codeorgan-sol/lifecycle.log`.

The bounded direct comparison with isolated Oracle7 `CodeChat` instances is
`var/codeorgan-sol/upstream-comparison.json`: 46 authored valid requests;
Oracle7 returned 37 programs, 29 marked confident. This route supports 35 and
withholds 11. Five supported operations had no upstream program on these
requests: multiplication, negating a list, pairwise multiplication, a lower
threshold filter and dropping a prefix. Oracle7's program counts are example
fits, not correctness scores on unspecified inputs. No upstream file was
written and no full head run is inferred.

## Consumer and remaining work

The Python answerer emits `kind: code_program`,
`path: organ:code>checked_examples`, and the standard checked-computation
packet to the dispatcher. Runtime's mandatory packet/request binding, independent replay, deterministic
source comparison and head-route registration now reach the actual dispatcher.
`var/codeorgan-sol/dispatch-final.json` records all 56 requests through the
normal CLI with Computing enabled and guards active: 35 checked answers,
11 withheld valid, 10 invalid refused, all IDs matching, zero wrong/false yes
in that scope. Every answer has `consumer_validation: consistent`.

Independent cross-family checks initially found two wrong-target numeric
interceptions: a request for a kilogram-conversion function received 5000 g,
and a request for a sound-speed function received 343.2 m/s. Runtime moved the
code stage before numerical families and network, so recognized program
requests take a terminal turn. The final check repeats six overlapping program
requests and three ordinary numerical controls in **both** head and front
orders: all six code requests refuse correctly, while normal conversion,
sound-speed and gcd questions still return 5000 g, 343.2 m/s and 6. These are
nine requests per mode, not a full-head or fleet score. Earlier failed
observations remain in `dispatch-overlap-more.json` for comparison.

Strings, arbitrary control flow, recursion and a growing persistent library
remain outside this initial integer/list fragment. Ordinary first-occurrence
deduplication deserves an explicit next operation rather than inheriting the
current last-occurrence convention; this remains active capability work. A scratch-only prototype at
`var/codeorgan-sol/next/answerer_first_unique.py` uses the existing
Reverse/Unique/Reverse AST; 80 native list cases and seven descriptor/ambiguity
controls pass. It has not changed the frozen production frontdoor or inherited
this packet's consumer counts. It also narrows function-name removal to the
declaration, avoiding erasure of operation words such as a function named
`cube`. No full Oracle7 head or
fleet success is inferred.
