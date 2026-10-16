Native executable checks currently live in
`src/isabelle/registry/Registry_Tests.thy`, beside the standalone HOL-only ROOT.
Run only after obtaining the project build steward's serialized slot:

```
python3 tools/dev/check-native --session Veri7vn_Registry \
  --session-root src/isabelle/registry --timeout 90 \
  --input src/isabelle/registry --expect 'REGISTRY native_objects PASS' \
  --expect 'REGISTRY generation_guard PASS'
```

No current-authority or acceptance claims are inferred from successful lookup.
