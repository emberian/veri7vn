# RC1 native linkage probe

Run from repository root through the shared serialized driver:

```
python3 tools/dev/check-native --timeout 90 --session Native_Linkage_Probe \
  --session-root experiments/native-linkage \
  --expect 'LINKAGE class_normalized_private_transport PASS'
```

Coordinate the build slot with the integration build steward during fan-out.
The base session uses warm HOL, one build job/two ML threads (driver enforced)
and `record_proofs=2` for the small transport child only. It has no Analysis dependency.

The theory contains real HOL refinements, generated heterogeneous execution,
fixed-bundle native association checks, generation guard tests, registered
certificate reconstruction, controlled native definition elaboration and a
bounded native-proof roundtrip into an earlier receiver context. Assertions
raise errors; a successful driver exit also requires the transport marker and
stable input hashes. This is feasibility evidence, not a production gate.

See [the design report](../../docs/design/native-linkage-feasibility.md) for exact
statements, exercised boundaries, measurements and outstanding consumers.

Strict receiver-known class normalization follow-up passes the original private nat alias (3,237-byte complete checked proof). See evidence/class-normalized-receipt.json and the design report; arbitrary missing proof bodies remain unsupported.
