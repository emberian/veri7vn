# Answerer contract

An **answerer** is any process that answers questions the way Oracle7 does: it
either answers or withholds, and it says which path produced the reply. The
parity harness (`tools/parity/`) drives every answerer through this one
contract, so Oracle7 itself, a single Oracle7 specialist composed in front of the
head, the packaged veri7vn, and an extracted veri7vn binary all score on the same
board.

## Protocol

The harness starts the answerer as a subprocess and speaks JSON lines over
stdin/stdout. One request per line in, one reply per line out, same order.
The answerer flushes stdout after every reply and exits cleanly on EOF.
Anything the answerer wants to log goes to stderr.

Request:

```json
{"id": "acoustics:heldout:3", "q": "What is the speed of sound in air at 0 degrees C?", "session": "exam-acoustics-3"}
```

Reply:

```json
{"id": "acoustics:heldout:3", "status": "answered", "response": "The speed of sound in air at 0 C is 331.3 m/s (v = 331.3 sqrt(1 + T/273.15)).", "path": "specialist:acoustics>speed"}
```

Fields:

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | echoed from the request |
| `status` | yes | a string: `answered` is an answer; every other status counts as withheld (including clarification prompts) |
| `response` | yes | the reply text the scorer reads; a withheld reply may explain the refusal or use an empty string |
| `path` | yes | the route trace, in Oracle7's `organ:...>STEP>STEP` style when there is one |
| `value` | no | a machine-readable result when the reply states one |
| `kind` | no | the specialist move (`beat`, `doppler`, `underspecified`, ...) |
| `provenance` | no | sources, store rows, runtime observations and declared evidence boundaries; theorem names alone do not prove this answer |
| `error` | no | set instead of `status` when the answerer crashed on this item; the harness scores it as withheld and records the error |

The scorer sees exactly `{"status", "response"}` plus whatever else is present,
so a reply that satisfies a shipped `*_scorer.py` here satisfies it in Oracle7's
own exam.

## Taking or passing a turn

Extracted specialists set `provenance.taken` to `false` when they did not
recognize the question. That reply can fall through to another stage. They
set it to `true` when they recognized a request, including a request whose
inputs the kernel refuses. A refusal accepted by that specialist's declared operation kinds, or by its
`declines_in_domain` rule with matching context, ends its turn. A normal
operation kind remains accepted when its kernel withholds; clarification text
is preserved as a non-answer. Trying another answerer after such a
refusal can turn a correct refusal into a false answer.

The dispatcher applies the specialist's acceptance rule before arbitration.
The shipped manifest is the starting rule. A family can extend its own
specialists through `src/extract/<family>/capabilities.json`; the dispatcher
and the exported organ package use the same loader in
`tools/runtime_contract.py`. Entries in `src/extract/families.json` declare
which executable owns each specialist and its role. A guard or document
stage is not a specialist merely because an executable exists in `var/`.

An extension has this shape (the values here are illustrative):

```json
{
  "schema_version": 1,
  "family": "example",
  "specialists": {
    "example-v2": {
      "accept": {
        "kinds": ["new_calculation"],
        "declines_in_domain": ["impossible"]
      },
      "context_regex_additions": ["new subject"],
      "evidence": {
        "computation": "Exact arithmetic on the parsed request",
        "assumptions": ["The stated model applies"],
        "untrusted": ["Natural-language recognition"]
      }
    }
  }
}
```

The loader adds explicitly named kinds and refusals, and combines extra
context patterns with the original pattern using OR. It rejects unknown
fields, specialist IDs owned by another family, and invalid patterns. It
does not grant acceptance to arbitrary kinds. The `evidence` object is a
declaration about a capability, not evidence that any particular check ran.
When a reply includes it, it belongs under
`provenance.evidence.declaration`; runtime observations must be separate.
Neither an entry in the registry nor a declaration says that a local binary
was rebuilt from current source.

For the discount-then-tax operation, a producer can also attach
`provenance.evidence.checked_computation`. It contains the actual parsed
price, each discount percentage, tax rate, and exact result as rational
`{"num":"...","den":"..."}` objects. The finance kernel's
`check_discount_tax` computes its acceptance flag. The consumer independently
recalculates the product, checks the ordinary nonnegative input domain,
rounds the exact result to cents, and compares that amount with both `value`
and the final-price sentence. Changing the inputs, result, or displayed final
amount without changing the others makes the consumer withhold the reply.

The consumer records its result in
`provenance.evidence.consumer_validation`. A `consistent` result means these
particular arithmetic and display checks ran; it does not mean the Python
checker is formally verified or that the parser understood the question.
The packet remains inspectable alongside the checks and their explanation.
An answer without a packet receives no such claim.

## Sessions

`session` is a conversation id. Items from one panel use distinct sessions
unless the panel says otherwise, matching `upstream/workbench/exam.py`, which
gives each item its own session.

## Reference answerers

| Answerer | Command | What it is |
|---|---|---|
| Oracle7 head | `tools/parity/answerers/oracle7.py` | the shipped core, `upstream/oracle7.py`'s `Engine`, state in a scratch directory |
| Oracle7 + one specialist | `tools/parity/answerers/oracle7.py --specialist <dir>` | the head, then the specialist only where the head declined for lack of a reading, exactly as `exam.py`'s `Loaded` composes it |
| veri7vn dispatcher | `python3 tools/dispatch/dispatch.py` | composes the explicitly registered extracted kernels and route stages |
| extracted binary | the binary itself | an MLton-compiled kernel that speaks this protocol natively |

The generated specialist folders use Oracle7's Python organ interface;
`tools/organs/package_smoke.py` checks them through their packaged manifests.
The older `veri7vn_packaged.py` adapter targets the removed revision-2 launch
system and is not a command for the current package.

An answerer must never write into `upstream/`. Oracle7's own exam runner burns
a held-out set and writes verdict files into the specialist folder; the harness
reimplements the scoring loop read-only instead of calling it.
