# Native linkage probe

Obtain the steward's slot; run from repository root:

```
python3 tools/dev/check-native --timeout 90 --session Native_Linkage_Probe \
  --session-root experiments/native-linkage \
  --expect 'LINKAGE class_normalized_private_transport PASS'
```

Warm HOL, one job/two ML threads; only the transport child uses `record_proofs=2`. Assertions cover HOL refinement, generated dispatch, native associations, generation guards, definitions and certificate reconstruction. Success requires the marker and stable hashes.

`evidence/class-normalized-receipt.json` records receiver-known normalization of a private nat alias: 3,237-byte complete checked proof. Missing arbitrary proof bodies remain unsupported. [Statements and boundaries](../../docs/design/native-linkage-feasibility.md) define this feasibility evidence's scope.
