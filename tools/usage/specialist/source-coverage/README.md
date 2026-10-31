# Relation coverage over a declared image domain

This native consumer counts distinct relation target IDs, detects absence and
checks uniqueness for explicitly supplied canonical subject IDs in one immutable
native image. It scans actual `edges` cursors; reaching EOF for every existing
subject establishes traversal of that declared snapshot domain and exact filter.
A traversal limit that cuts off one extra row produces an incomplete receipt.
Missing subjects also produce incomplete receipts. Missing properties produce
only absence **in this snapshot**, including when the original source omitted
that property entirely. Duplicate target names never collapse distinct IDs.

`Image::relation_coverage` returns a live, non-deserializable handle. Its
`count`, `absent` and `unique` consumers require the exact image revision and
request. A serialized receipt, caller boolean or digest cannot create a handle.
There is no merge or retraction API: revising the source requires opening the new
image and scanning again. Immutable image custody remains the Image host premise.

Supplied-row visitation, recognizer-candidate exhaustion and a declared closed
world assumption have separate report types and confer no native traversal
permission. Canonical IDs must come from the caller's interpretation; this does
not prove that all aliases or all real-world entities were found. The qualifier
filter compares the entire JSON object exactly. It does not interpret current,
past or missing temporal qualifiers.

Useful workflow: a host receives a curated set of source IDs and a relation,
then returns a count/absence/unique answer with the source and domain receipt.
The `oracle-coverage IMAGE_SQLITE IMAGE_SHA256` executable reads a request
from stdin and returns the receipt plus answers only when traversal completed.
A sample request is `tools/usage/specialist/source-coverage/request.example.json`.
The Python adapter at `tools/usage/source_coverage.py` supplies the request; it
cannot verify the native response. Example:

```sh
python3 tools/usage/source_coverage.py --host native/target/release/oracle-coverage \
  --image /data/image.sqlite --image-sha256 SHA256 --subject Q1 \
  --predicate knows --limit 10000
```

Coverage binds the private verified image hash, even if a caller changes the
legacy public display identity. It cannot prevent an operator from modifying
the backing file in place: immutable artifact custody remains required.
The shared-budget API preserves the host's cancellation, fuel and memory ledger.

No new Isabelle theorem is claimed. `Relation_Reader.answer_requires_coverage`
proves that an Answer requires every selected candidate's `complete` flag. It
assumes the flag and does not establish a database traversal. This module does
not set that flag or widen the extracted reader's admitted domain.

Panel numbers: none. Independent authored tests cover final-row truncation,
exact-limit EOF, absent property, missing subject, duplicate names, stale image
binding, qualifier changes and retracted subject domain. No tests/builds were
run by this implementation lane; central validation owns execution.
