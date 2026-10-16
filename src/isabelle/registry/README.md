# Native object registry

Veri7vn_Native_Registry stores actual cterm/thm/Proof.context in persistent non-rebinding tables. Opaque generations capture immutable contexts/dependency records; lookup requires matching generation/snapshot. Interning preserves hypotheses/assumptions and can retain an unaccepted candidate. Only admission/generated Owner grants execution, publication or current access.

Lineage uses Context.subthy_id for trimmed theorem certificates and checked Thm.transfer_cterm feasibility; actual objects remain unchanged. Native_Literals retains immutable original UTF-8 bytes, checked slices/line columns, normalized views with source maps and lifecycle cells. Space/case-sensitive payloads survive; display names/bytes do not construct handles.

Veri7vn_Typed_Runtime_Store is a generative private functor over concrete typed value/continuation carriers and one fixed executable pin. Opaque handles cannot cross instantiations or be recreated from wire. Persistent snapshots retain their references; remove_value/remove_continuation affect only the new snapshot. Consumers must seal stores and drop every managed root on Forget, including old snapshots/jobs/caches. No evaluator/evidence callback or migration factory exists.

## Checks

```sh
python3 tools/dev/check-native --session Veri7vn_Registry \
  --session-root src/isabelle/registry --timeout 90 \
  --expect 'REGISTRY native_objects PASS' \
  --expect 'REGISTRY generation_guard PASS' --input src/isabelle/registry
```

Initial checked receipt:var/native-scaffold/sessions/76ddf458c506624c/receipt.json (Isabelle2026-RC1/macOS ARM64). Composed admission checks also passed trimmed theorem/cterm and typed bulk/continuation/generation/snapshot cases. Later per-handle removal requires its next composed Admission_Metadata check. These are actual ML implementation tests, not HOL proofs of registry/admission or completed native-registry/linking/codec/recovery gates.

[Recovery contract](RECOVERY.md) separates durable metadata from fresh native identity and managed storage from authorization.
