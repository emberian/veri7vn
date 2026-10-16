# Local native deployment staging

`python3 tools/deploy/local_inventory.py var/deployment-local` stages an exact
allowlist of the actual compiled host jar, its exact eight-source producer snapshot and
installed Isabelle RC1 launch scripts/component declarations/license material. This is an inspectable incomplete package. Its manifest
names missing host, final heap, toolchain, qualification and redistribution work;
launch refuses incomplete packages. The inventory does not copy user history,
workspace state, corpora, credentials, caches or native build receipts.

`python3 tools/deploy/stage.py verify var/deployment-local/current` verifies hashes
and modes. Package identities hash canonical manifests; source paths are excluded
from manifests. Components carry explicit origin/license dispositions. D19 remains
open: these packages are local-only, with no inferred redistribution grant.

For a complete artifact spec, `stage.py stage SPEC INSTALLATION` copies only explicit
regular files with expected SHA256, component, origin, role and license fields.
Required roles are runtime, heap, host, source and license. Enumerate every file
in the actual dependency closure, including Isabelle build databases/session roots,
transitive heaps and component licenses; a role label alone cannot establish closure.
No directory traversal/copy or network fetch is implicit. Host compilation and heap
construction happen before staging through coordinated developer tooling.

`stage.py launch INSTALLATION --state STATE` checks selected artifact identity and
host target before executing the specified package executable. Launch argv uses
`{package}` and `{state}` placeholders. Mutable workspace and deployment images
belong outside immutable package generations. Host61's agreed public launch contract
is a fixed `Veri7vn_Runtime_Service` session, `--workspace STATE/workspace`,
`--images STATE/images` and repeated `--session-root PACKAGE/sessions/...`.
The real public main jar is staged with its exact producer source bodies. Its first
producer compiled a wrong session pin; the corrected producer remains a dependency.
There is currently no qualified complete launch spec. Isabelle's actual bundled Scala classpath is
required; guessing plain Java invocation is not a substitute.

Staging serializes installers with a local lock. It fsyncs copied files and nested
directories bottom-up, persists the renamed generation before selecting it, then
persists the selection directory. It copies and verifies a private
incomplete generation, then atomically switches `current`. A rejected update leaves
the old pointer intact. Interrupted incomplete directories are inert and preserved;
rerun staging to obtain the same manifest identity. Other sessions' directories
are never garbage collected. Completed previous generations remain available for
operator inspection; switching an immutable package does not restore authority
state, replay actions, revoke capabilities or migrate workspace journals.

macOS ARM64 is the current inspection host. Linux x86_64 remains a supported target
requiring an actual Linux build and clean launch trial. Neither target has passed
complete installed offline search/edit/admission acceptance. No end-user HOL-Analysis
build, downloader, package manager or network dependency is introduced by this
launcher; the eventual pinned application/runtime closure must independently pass
that requirement. Artifact verification is deployment integrity, not theorem or
native admission evidence.

Checks: `python3 -m unittest discover -s tests/deployment -v` covers deterministic
selection, failed-update preservation, interrupted staging, traversal, symlink and
artifact corruption rejection. These controlled fixtures do not qualify an actual
runtime. The actual incomplete inventory provides source/toolchain inspection only.

`stage.py plan INSTALLATION --state STATE` prints the actual argv and environment
without starting a process. The manifest pins CLASSPATH to the staged host jar and
USER_HOME to isolated mutable state. Launch strips inherited Isabelle/ML/JVM setup
so unrelated user initialization does not choose the runtime. The staged runtime
is explicitly only an inspection subset; a full relocatable runtime and saved
heap/build-database/source association remain required. A historical green log
without a saved successful build record is insufficient. The public jar is never
paired with later mutable Scala sources as if those were checked.

`native_readiness.py --heap HEAP --database DB --receipt RECEIPT` performs read-only
prerequisite diagnosis without starting Isabelle: it checks the receipt source hashes
against the workspace and reports the saved successful session build row. The first
inspection of historical e4829 found an existing Runtime_Service heap but an empty
build-metadata table and six later source changes; it cannot qualify a deployment.
The initial a907 host jar likewise retains its historical wrong session pin and
is inspection-only. The host producer now refuses to pass packaging until the
actual saved session build metadata is successful.

## Actual toolchain and captured native closure

`local_package.py INSTALL --prepare-runtime` stages the full installed public
Isabelle distribution, including its prebuilt system heaps, component trees,
notices, sources and internal links. Each regular file is hashed; explicit internal
symlinks are preserved and escaping links rejected. This is toolchain preparation,
not an executable application qualification. The completed preparation is under
`var/deployment-public-runtime/current` (local and uncommitted).

The steward runs `export_closure.scala` against `deployment/production-roots.txt`.
That explicit production-root inventory comes from the actual qualified build094
command; it excludes unrelated draft sessions. Capture records successful build
UUIDs, exact heap/database paths and saved source bytes. It also records the actual
imported session ROOT closure for recipient navigation. Each capture gets its own
UUID directory and leaves earlier successful or interrupted captures intact.
Capture starts no native resident and performs no production build.

After a repaired native image and refreshed actual host package pass their consumer:

```sh
python3 tools/deploy/local_package.py var/deployment-application \
  --host-archive PRODUCER_ARCHIVE --closure CAPTURE/closure.json \
  --runtime-cache var/deployment-public-runtime/current
python3 tools/deploy/stage.py plan var/deployment-application --state var/deployed-workspace
```

The package copies actual heaps and build databases into its own runtime heap store.
Native theory/ML bytes come from the saved build database, so later checkout edits
are not mislabeled as checked. Other source files are explicitly navigation-only;
the staged ROOTS index contains only captured production imports. The jar keeps its
own exact eight-source compile snapshot. The real launch uses the staged Isabelle
`java` tool, not `scala`, `build` or a theory-generation command.

`missing` identifies structural/runtime prerequisites and always blocks launch;
callers cannot override it. `qualification_notes` separately records D19, Linux
and product acceptance work without preventing authorized local diagnosis. A runnable
local diagnostic package is not declared transferable or recipient-ready. Root and
the steward still authorize and serialize actual native launch/restart checks.
The historical captured image's synchronous reader deadlock is explicitly known;
it must not be used as successful deployed reasoning evidence.

The first full staged launch (attempt `7af9670c06964b01a3b47f5012b7ed0c`)
failed before native startup: `ML_Settings.ml_platform` omits the Poly/ML version,
so the first builder used the wrong heap-store directory. The builder now preserves
that directory verbatim from the captured heap path. `repair_heap_layout.py`
repackages the initial immutable generation using only its captured bytes and
metadata; it never consults later source or live build state. The repaired local
application generation is `40ac45e74c0be18732a81bff246817cfb2cbe9de91abfc7c8a7ccfc234ec98bd`.
The repaired generation ran that workload successfully: the first public Main
process returned the expected sum HTML and exited zero; a second process opened
the same nonempty workspace, returned the expected product HTML, and exited zero.
The result is recorded in
`var/deployment-launch-check-4cc408de-8bd0-432b-8bd9-d5addb5f7e3e/result.json`.
The harness restart interrupted the supervising driver's final receipt, which is
preserved as interrupted evidence. The subprocess results establish this actual
launch/restart path, not broader offline, authoring, search or platform acceptance.

Owned verified immutable cache files can be shared by read-only hardlinks between
staged generations; native artifacts are first copied from the producer. Each
resulting generation has its own directory entries, and content/mode verification
still precedes selection. Removing an older generation would not remove linked
content from a surviving generation. The tooling performs no generation deletion.
