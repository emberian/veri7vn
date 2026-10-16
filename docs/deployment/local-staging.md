# Local native deployment staging

Use the shipped `INSTALL/current/bin/veri7vn` for recipient operations; use Python tooling to assemble, inspect and qualify developer candidates. Packages are immutable artifact closures; mutable workspace/images stay outside the installation. [Workshop](../tutorials/installed-source-workshop.md) · [runtime profile](runtime-closure.md) · [operation reference](../reference/recipient-operations.md).

## Actual toolchain and captured native closure

A complete `veri7vn-local-deployment/1` spec inventories explicit regular files with package path, SHA256, role, component, origin and license. Runtime/heap/host/source/license roles are required; role labels do not establish dependency closure. Include transitive heaps/build databases, captured ROOT/ROOTS navigation and component notices. No implicit directory copying, home expansion or network fetch occurs. `missing` blocks launch; `qualification_notes` records remaining platform/product/licensing limits. D19 permits local diagnosis, not inferred redistribution.

```sh
python3 tools/deploy/local_inventory.py var/deployment-local
python3 tools/deploy/stage.py verify var/deployment-local/current
python3 tools/deploy/local_package.py var/deployment-application --prepare-runtime
python3 tools/deploy/local_package.py var/deployment-application --host-archive PRODUCER_ARCHIVE --closure CAPTURE/closure.json --runtime-cache var/deployment-public-runtime/current
python3 tools/deploy/stage.py plan var/deployment-application --state /absolute/private/state
python3 -m unittest discover -s tests/deployment -v
```

The local inventory is deliberately incomplete. Runtime preparation hashes the installed Isabelle closure, retaining internal links and rejecting escapes. The steward captures successful session records with `export_closure.scala` and `deployment/production-roots.txt`; theory/ML bytes come from saved build databases, host bytes from the immutable producer archive. Later checkout edits cannot stand in for either. `native_readiness.py --heap HEAP --database DB --receipt RECEIPT` diagnoses saved-build/source prerequisites without launching Isabelle.

Staging locks installers, verifies/copies into a private generation, fsyncs files/directories and preserves the generation before selection. Interrupted incomplete directories are inert; prior generations remain available. It deletes no sessions/caches. Manifest identity, modes, content and links are verified before launch. Read-only hardlink reuse retains per-generation entries and full verification; it is not OS-enforced immutability against the owning principal.

The public native main uses fixed `Veri7vn_Runtime_Service`, explicit workspace/images and captured session roots through bundled Isabelle `java`. Heap-store directories preserve captured platform/version layout. No generated theory/build occurs per request. macOS ARM64 has finite execution evidence; Linux x86_64, complete offline editing/search/admission and redistribution remain separate gates.

## Packaged shared workbench

```sh
V7=/absolute/path/to/installation/current/bin/veri7vn
"$V7" verify
"$V7" locate --tutorial retained-identity
"$V7" plan --state /absolute/private/source-state --surface source -- serve
"$V7" launch --state /absolute/private/source-state --surface source -- serve
"$V7" launch --state /absolute/private/native-state --surface workbench -- run 'the sum of -2 and 3'
```

`source` selects the packaged Workbench JAR and managed source writer without a native resident. `workbench` starts the pinned native service and shared authoring UI. There is no silent fallback. Close a workspace's writer before another process opens it. `locate` verifies inventoried tutorial assets; those assets are editable candidates, not admitted capabilities.

The standalone shell/JVM bootstrap runs before manifest verification and is part of the trusted startup image. It uses fresh invocation-owned settings home (`fresh-owned-temporary/1`), controlled PATH/user identity and inherited-environment filtering. State cannot overlap the recognized generation container. Its own hash is not an independent trust root; no signed-distribution or hostile-concurrent-write guarantee is implied.

| Evidence | Established finite consumer |
|---|---|
| [Standalone AAE](../../tests/deployment/evidence/standalone-aae0d7dd.json) | Generation `2fd159a898d0b7648dfce893f35a9a61f7ac0df05f7fa25314a29e001750cf45`: shell outside checkout imports/reopens source, runs native sum, restores same result in fresh process; 27 parity cases |
| Same standalone workshop | Bundled identity locate/import/Open, two Saves/new revisions, normal shutdown, exact fresh CLI readback |
| [Source overlay](../../tests/deployment/evidence/source-install-0006b59c.json) | Packaged source import/inspect/edit/reopen and HTTP Open |
| [Workshop](../../tests/deployment/evidence/workshop-install-5945df.json) | Earlier installed two-Save source rehearsal |
| [Failed upgrade](../../tests/deployment/evidence/failed-upgrade-cb4e8d.json) | Old controlled state survives candidate refusal; no successful migration |

These developer conformance checks do not admit edited source, establish human usability or qualify later Build/search/family drafts. Current performance variants have separate [measurement records](../performance/installed-runtime-pilot.md).

## Existing-state upgrades

Stage replacements with `--candidate-only`; an existing different generation cannot replace `current` without a guarded compatibility transaction. Fresh installations and identical-generation reruns remain supported. Codec labels/hash agreement do not prove old-state compatibility: D44 changed retained-input associations while preserving a codec label.

D51 requires a consistent private snapshot under the actual host writer lock, bounded old/new probes on separate copies and promotion rechecking the captured live state identity. Ordinary SQLite/WAL/blob copying is insufficient. Probe state stays local; do not rewrite checkpoint graphs or managed dependency rows. Rejected probes cannot alter original allocator/state or selection. Restore never replays effects/acquisition or revives forgotten bytes.

`upgrade_check.py --helper-command FILE` consumes a JSON argv with `{source}`/`{snapshot}` placeholders. The qualified helper holds the writer lease, checks unsafe resource ownership, emits one READY line and retains the lease until stdin closes. The harness requires old-clone restore success, candidate rejection with the selected exact diagnostic, unchanged original fingerprint/selection, then old-runtime restore of original state. EOF proposes no work. The actual cb4e8d trial passed preservation with `native restore closure unavailable`; its underlying rejection cause remains unclassified. It proves neither successful migration nor general effect/privacy recovery.

## Independently captured source client

```sh
python3 tools/deploy/source_overlay.py OLD_IMMUTABLE_GENERATION SOURCE_ARCHIVE FRESH_INSTALL
python3 tools/deploy/source_check.py FRESH_INSTALL --output var/deployment-source-UNIQUE
python3 tools/deploy/workbench_check.py INSTALL --output var/deployment-workbench-UNIQUE --steward-slot SLOT
```

A source archive includes its JAR, artifact/receipt hashes and exact compile-source snapshot. The overlay adds that separately pinned client while retaining the old native JAR/heaps/source bytes; it creates a fresh installation. Alternating a newer source store with an older resident requires its own compatibility check. `local_package.py --source-archive ARCHIVE` attaches the same producer during assembly.

Native/runtime qualification commands run only in the steward's exclusive build slot/lock. `source_browser_check.py` tests loopback HTTP/CSRF Open/normal close; `workshop_check.py` adds two Saves and fresh reopen. Each has explicit scope; transport tests are not visual/accessibility trials. Private state, snapshots, CSRF-bearing HTML, heaps and generated JARs remain outside commits.
