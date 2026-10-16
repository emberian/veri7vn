# Registry checks

Obtain the steward slot:

```
python3 tools/dev/check-native --session Veri7vn_Registry \
  --session-root src/isabelle/registry --timeout 90 \
  --input src/isabelle/registry --expect 'REGISTRY native_objects PASS' \
  --expect 'REGISTRY generation_guard PASS'
```

`Registry_Tests.thy` checks objects/generations; lookup grants no authority.
