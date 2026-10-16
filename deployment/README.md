# Deployment inputs

Canonical local tooling is `tools/deploy/stage.py`; the inspectable inventory
builder is `tools/deploy/local_inventory.py`. Operational instructions and current
qualification gaps are in `docs/deployment/local-staging.md`.

A complete spec has schema `veri7vn-local-deployment/1`, target `macOS-ARM64` or
`Linux-x86_64`, session `Veri7vn_Runtime_Service`, an argv array `launch`, and an
`artifacts` array. Each artifact names an explicit local regular-file `source`,
normalized package-relative `path`, lowercase SHA256 `sha256`, `role`, `component`,
pinned `origin`, explicit `license` disposition and optional `executable` boolean.
All source/build inputs and component licenses belong in the explicit inventory.
No automatic directory or home-directory expansion is supported. `qualification_notes` records nonblocking licensing/platform/product acceptance work.
`missing` names unfinished structural/runtime closure prerequisites; a package with any missing obligation
is inspectable but cannot launch. An empty launch is likewise never executable.

Package sources are durable developments, not workspace journals or explanations
of private interactions. Toolchains, heaps and generated jars remain uncommitted
local artifacts. The project license remains undecided (D19).
