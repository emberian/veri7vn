# One front door for the extracted programs

The dispatcher accepts JSON lines with `id`, `q`, and `session`, and returns an
answer or refusal with its route. It is **untrusted Python glue** around the
extracted programs. Its stage order is a deliberate composition of the lifted
capabilities; it does not reproduce every fold of Oracle7's released head.

The registry in `src/extract/families.json` names every program's role and each
specialist's owner. Files found under `var` are never added automatically.
Specialist replies must name an ID owned by their family and pass the shared
acceptance contract: the original manifest plus explicit additions in that
family's `capabilities.json`. This makes new chemistry and finance kinds usable
without accepting arbitrary undeclared kinds.

## Running it

```sh
printf '%s\n' '{"id":"1","q":"Who wrote Leaves of Grass?","session":"demo"}' |
  python3 -B tools/dispatch/dispatch.py

# A specialist's own composition, with just its family and the network:
python3 -B tools/dispatch/dispatch.py --order front --organs chemistry \
  --specialist chemistry-v3 --no-reader --no-document --no-routes
  # Add --no-dialogue --no-code to isolate the older specialist/network stages.

python3 -B tools/dispatch/dispatch.py --selftest
python3 -B tools/dispatch/test_dispatch.py
python3 -B tools/dispatch/test_routes.py
python3 -B tools/dispatch/check_state.py
```

`--var-root` relocates registered binary paths. `--arb` selects the arbitration
binary. The document adapter requires the existing upstream Python dependencies;
`--adapter-python` defaults to this repository's `.venv/bin/python` when present.
Imports disable bytecode writes. Stores and source material under `upstream` are
read-only. Missing configured programs and malformed capability declarations
stop startup with an explanation.

## How a turn proceeds

The finite dialogue reader first selects a grounded follow-up question, or asks
for clarification when its reference is missing or ambiguous. Only that one
question is evaluated; a captured refusal is never replaced by another literal
interpretation. Explicit titles and self-contained questions keep their ordinary
reading. See `tools/dialogue/README.md` for the context boundary.

The code reader runs first for explicit program requests. Its answers require a
request-bound checked program/examples packet; unsupported program requests
remain refusals. An ordinary question falls through. Then the default asks the
network first, then specialist families. `--order front`
asks specialists first; when `--specialist ID` is supplied, its owning family is
asked alone before other families. Ownership comes from the registry, without
starting programs to guess which flags they accept.

An accepted reply selected by the extracted arbitration ends the turn. This
includes an in-domain refusal. A reply whose `taken` flag is false falls through.
When all existing ranking scores tie, a checked refusal with matching question
context now outranks an answer before registration order is considered. This
keeps a physical negative-fabric refusal from losing to a generic signed unit
conversion. It does not change the existing agreement shortcut or certify the
untrusted context/checked readings. Plain signed conversion remains valid when
no competing physical refusal is present.
An explicit `--specialist ID` pin supplies domain context for that ID's declared
decline kinds only when the reply is a nonanswer. A family filter (`--organs`)
does not. The reply must still be
taken, name the owned pinned ID, and declare an allowed kind; unknown kinds
remain rejected. Meaningful clarification text is retained as a terminal nonanswer.
The distinction deliberately repairs the old dispatcher, which could replace a
correct refusal with an answer from a later route. A stage failure is reported
as a withheld error, not treated as evidence that the question was unrecognized.

Build arbitration with `PROOF_RECEIPT=/absolute/path/to/receipt.json sh
tools/dispatch/build_arb.sh` after the managed Specialists proof passes. The
native driver holds the compiler lock and binds the actual generated export
and driver source. Set `ARB_OUTPUT` to test a candidate without replacing the
active binary; use `dispatch.py --arb PATH --selftest` to check its protocol.

After specialists and network come any registered arithmetic/algebra and word
problem stages, the general relation reader, and the document adapter. Captured
refusals from these routes also stop the turn. Math's reconstructed guard-only
fallback runs last. Precision guards inspect the **actual selected answer**
once, after routing. These guards currently model 20 of 87 catalogue codes;
store-dependent facts are marked unavailable unless supplied by an adapter.
`--no-routes`, `--no-reader`, `--no-document`, and `--no-code` support scoped checks. The
`stages_run` trace lists invoked stages, not disabled callbacks.

The general relation adapter asks matching readers through one shared kernel
and requires agreement across their decisive claims. Its source assertions,
entity linking and fetched-row completeness remain assumptions; those limits
travel with its reply. Document uses the anchor front door before its legacy
reader; both explicit binaries are required. Its source-supported cause,
process and date routes remain partial: recognizing a summary or timeline
request does not mean the system can generate it.

## State and evidence

A warehouse operation must not commit while merely competing for arbitration.
A registered stateful family with `preview_flag` runs speculatively with
`--preview`; this never persists warehouse state. Cooking answers remain usable.
Unpinned stock, location and sensor reads return their preview answers. If
arbitration selects an unpinned proposal, order or cancellation, the dispatcher
withholds and says an explicitly selected warehouse specialist is needed to
perform that operation.

Warehouse operations require `--order front --specialist warehouse-r2` (or
`warehouse`) with no competing specialist pin. This creates a preview child and
one committing child sharing a new private state file. The dispatcher serializes
the whole turn: preview, acceptance and selection, precision guards, then one
commit of the exact selected question if the preview remains accepted. The
preview reloads current committed state each time; the committing child is its
only writer. Other programs must not write that private file.

A guard-blocked proposal or confirmation changes no state. A committing error
is reported as uncertain and never automatically retried. The actual committing
reply is compared with its preview for diagnostics and returned without later
filtering that could hide an already performed operation. Pinned warehouse
reads also commit once after guards to retain conversation references: a stock
question can be followed by “Where is it?” in the same session. Unpinned reads
return the preview without retaining that reference. Cooking needs no warehouse
state. Each session has separate references and pending confirmation state. Counterfactual ranking never perturbs a stateful candidate.
The dialogue ledger records only the final post-guard/post-commit result. A
successfully committed warehouse receipt delegates its finite native item
follow-ups to the same pinned owner; it does not create a global entity ID.
Literal recall quotes the actual final reply and its provenance. `--no-dialogue`
disables history and contextual follow-ups.
`check_state.py` exercises this sequence against real children, including
injected guard rejection and uncertain commit outcomes.

Kernel declarations and theorem inventories are not proofs that a particular
English question was understood. The dispatcher keeps a producer's evidence
packet, adds clearly labelled capability declarations, and invokes the shared
consumer validator for supported checked-computation packets. That validator's
independent Python arithmetic is corroboration, not a new HOL theorem. Invalid
asserted packets are withheld. Original recognition, rendering, source data,
and Python stage composition remain outside the proof boundary.

## Evidence and remaining limits

The scoped composed run on 18 October scored chemistry-v3's held-out
panel **281/281 right, 0 wrong, 0 false yes**, and retail's **51/51 right, 0 wrong,
0 false yes** (`var/dispatch/c-runtime-final/panels`). It used pinned front order,
chemistry and finance families, with the other registered stages enabled. These
are specialist-panel results; head comparison, lane/self preservation and the
full budget criterion were not measured. Later route changes require their own
scoped consumer checks rather than inheriting these figures as a fleet score.

Cross-family interpretation remains imperfect. For the domain-neutral question
“What is the density of Mercury?”, chemistry and astronomy both answer; the
existing arbitration's wording ranking selects the element. A specialist pin
can choose astronomy explicitly, but the general question has not acquired a
proved disambiguation rule. Likewise, the precision guards are a partial model,
not a claim that all head overanswers are eliminated.
