# Deployment inputs

Use [`tools/deploy/stage.py`](../tools/deploy/stage.py) to stage and verify local packages; see [operations](../docs/deployment/local-staging.md).

A `veri7vn-local-deployment/1` spec declares target (`macOS-ARM64` or `Linux-x86_64`), `Veri7vn_Runtime_Service`, launch argv and explicit artifacts. Each artifact has a regular-file source, normalized package path, SHA256, role, component, origin, license disposition and optional executable flag. No directory expansion or network fetch is implicit.

`missing` blocks launch; `qualification_notes` records product/platform/licensing limits. Inventory runtime, heaps, host, source and licenses. Exclude workspace history, credentials and private source derivatives. Generated toolchains/heaps/JARs stay local. Redistribution requires D19 closure.
