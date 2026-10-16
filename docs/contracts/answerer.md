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
| `status` | yes | `answered` or `withheld`; anything else counts as withheld |
| `response` | yes | the reply text the scorer reads; empty string when withheld |
| `path` | yes | the route trace, in Oracle7's `organ:...>STEP>STEP` style when there is one |
| `value` | no | a machine-readable result when the reply states one |
| `kind` | no | the specialist move (`beat`, `doppler`, `underspecified`, ...) |
| `provenance` | no | free-form object: sources, theorem names, store rows |
| `error` | no | set instead of `status` when the answerer crashed on this item; the harness scores it as withheld and records the error |

The scorer sees exactly `{"status", "response"}` plus whatever else is present,
so a reply that satisfies a shipped `*_scorer.py` here satisfies it in Oracle7's
own exam.

## Sessions

`session` is a conversation id. Items from one panel use distinct sessions
unless the panel says otherwise, matching `upstream/workbench/exam.py`, which
gives each item its own session.

## Reference answerers

| Answerer | Command | What it is |
|---|---|---|
| Oracle7 head | `tools/parity/answerers/oracle7.py` | the shipped core, `upstream/oracle7.py`'s `Engine`, state in a scratch directory |
| Oracle7 + one specialist | `tools/parity/answerers/oracle7.py --specialist <dir>` | the head, then the specialist only where the head declined for lack of a reading, exactly as `exam.py`'s `Loaded` composes it |
| veri7vn packaged | `tools/parity/answerers/veri7vn_packaged.py <generation>` | wraps `bin/veri7vn launch ... -- run` |
| extracted binary | the binary itself | an MLton-compiled kernel that speaks this protocol natively |

An answerer must never write into `upstream/`. Oracle7's own exam runner burns
a held-out set and writes verdict files into the specialist folder; the harness
reimplements the scoring loop read-only instead of calling it.
