# Local native deployment staging

`python3 tools/deploy/local_inventory.py var/deployment-local` stages an exact
allowlist of the actual compiled host jar, its exact producer source snapshot and
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
The real public main jar is staged with its exact producer source bodies. Its historical first
producer compiled a wrong session pin; the corrected producer is used by the
qualified immutable 40ac generation. Later source requires a new captured producer.
The repaired immutable 40ac generation below has passed the finite public CLI launch/restart check. Isabelle's actual bundled Scala classpath is
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
so unrelated user initialization does not choose the runtime. The `local_inventory.py` output is only an inspection subset; `local_package.py` below assembles the captured application and full installed toolchain. A historical green log
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
own exact compile-source snapshot. The real launch uses the staged Isabelle
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


## Packaged shared workbench

New application manifests advertise `surfaces.workbench` only when the actual host
JAR contains ResidentWorkbench, Browser, Authoring and ResidentExecution, all four
producer sources and RuntimeMain are recorded in the producer receipt, and that
RuntimeMain routes `--workbench` to the shared service. The inventory checks every
producer source digest before staging. Historical public-only generations remain
public-only; appending an option does not make their missing classes appear.

```
python3 tools/deploy/stage.py launch --state PRIVATE_STATE --surface workbench INSTALL -- serve
python3 tools/deploy/stage.py launch --state PRIVATE_STATE --surface workbench INSTALL -- run 'the sum of -2 and 3'
python3 tools/deploy/stage.py launch --state PRIVATE_STATE --surface workbench INSTALL -- result REQUEST_ID
```

The browser prints its loopback address and stays open until Enter. It and these
CLI commands share the resident runtime's managed sources and authority workspace.
Run one workspace owner at a time. The captured Browser uses embedded HTML/CSS;
no CDN, JavaScript package manager, remote font or downloaded UI component is
required. Packaging rejects literal HTML subresources and CSS imports/URLs until
an explicit asset inventory is supplied. This conservative source preflight and
class inventory are dependency inspection, not a network-disabled execution test.
Native interpreted Run, result inspection, cancellation and confirmed Forget are
available as implemented by the captured host. Build/admit controls remain absent
until their actual service consumer is integrated.

The exclusive native build steward can qualify a newly staged generation with:

```
python3 tools/deploy/workbench_check.py INSTALL --output var/deployment-workbench-UNIQUE --steward-slot SLOT
```

This finite actual consumer runs a sum through the packaged shared workbench,
extracts its real request ID, closes the process, then inspects the retained result
through a fresh process using the same nonempty state. It pins an installation
facade to one immutable generation, writes local logs/results, applies a 150-second
process deadline and bounded process-group termination on timeout. Obtain the
steward slot and hold the project build lock throughout. Do not run beside a native
build or resident check. Passing establishes that specific CLI/restart consumer;
HTTP authoring, native build/admission, network-disabled recipient workflow,
Linux qualification and D19 redistribution remain separate requirements.


An explicit `source` surface selects `veri7vn.cli.Workbench` from the same produced
JAR, using `STATE/workspace`, the same managed-source store and writer lock. It
opens no RuntimeService and starts no native heap. This is an explicit choice;
a failed resident launch never falls back silently. It is advertised only when
the actual JAR includes Workbench and its shared authoring/store classes and the
producer records the source main. Run the source browser with:

```
python3 tools/deploy/stage.py launch --state PRIVATE_STATE --surface source INSTALL -- serve
python3 tools/deploy/stage.py launch --state PRIVATE_STATE --surface source INSTALL -- list
python3 tools/deploy/source_check.py INSTALL --output var/deployment-source-UNIQUE
```

The source fixture starts separate actual packaged JVM processes for original
source import, captured revision/edit-token inspection, exact-byte edit, and
reopened source readback. It never compiles source or starts Isabelle's native
authority. Coordinate JVM/runtime checks with the build steward. Source and
resident processes cannot simultaneously own the same workspace. The installed
application still requires its complete declared runtime/heap closure at staging;
this surface does not turn an incomplete application into a launchable package.
A dedicated source-only distribution without native heaps is a separate envelope.

## Existing-state upgrades

D44 corrects shared-input ownership while the checkpoint codec label remains the
same. An old 40ac checkpoint can consequently fail the new runtime's exact
reconstruction check. Codec equality, artifact hashes and successful empty/current
runtime restarts do not establish compatibility with an existing workspace.

For an update, use `local_package.py ... --candidate-only` (or
`stage.py stage SPEC INSTALL --candidate-only`). This persists and verifies the
candidate generation while leaving `current` unchanged. The selected old generation
and original mutable state remain available. This is preparation, not migration.
Do not switch the pointer to infer whether a candidate can restore old state.

The required next gate is a protected consistent private snapshot under the host's
actual workspace writer control, followed by bounded old/new pinned-launcher
compatibility checks on copies. Snapshot/probe artifacts must stay local because
they contain source material, retained native state and lifecycle tombstones.
Ordinary live-directory copying is insufficient for the SQLite/WAL/blob boundary.
No checkpoint graph or managed dependency row is rewritten by deployment tooling.
If the candidate rejects restoration, retain the old selected generation and original
state; allocator changes in a rejected private probe do not authorize changes to
the live store. Promotion must also recheck the captured state identity under the
writer boundary so an intervening source edit, Forget or revocation cannot be lost.

The host snapshot boundary, guarded migration event and actual 40ac-to-D44 consumer
are under integration. There is no completed live replacement transaction or
claimed successful migration. The candidate-only fixture checks artifact selection
preservation; the actual rejection/old-runtime recovery check belongs to the native
build steward's serialized slot. Restoring or probing must not replay external
actions, restart retired acquisition, or recover forgotten source bytes.

Existing-generation replacement now fails closed in `stage`: a different verified
candidate is retained, but `current` stays unchanged and staging reports that a
guarded compatibility transaction is required. Fresh installations and exact
same-generation reruns remain supported. There is no bypass flag for selecting an
unqualified replacement. `--candidate-only` stages an update without that selection
error. This guard preserves the original installation; it does not prove the new
runtime can restore its workspace.

## Independently captured source client

The source-authoring producer may be captured separately from a new native host.
Its archive has `veri7vn-source-workbench.jar`, `artifact.json` with its SHA256,
`receipt.json` with attempt identity and exact `sources_sha256`, and the matching
`source-snapshot` bodies. The source route requires the actual Workbench main and
shared authoring/store classes. All producer bodies and the JAR are verified.

```
python3 tools/deploy/source_overlay.py OLD_IMMUTABLE_GENERATION SOURCE_ARCHIVE FRESH_INSTALL
python3 tools/deploy/source_check.py FRESH_INSTALL --output var/deployment-source-check-UNIQUE
```

The overlay reuses the old native package's exact verified immutable artifacts;
it does not pair a later native source tree with the old heap. It adds a distinct
source client JAR and source snapshot. Only the `source` surface selects that JAR
as its application classpath; resident launch keeps its original host JAR. Both
use the staged Isabelle Java dependency closure. This creates a fresh installation
for testing and preserves the old selected generation and state. It is a full
native package with an independently captured source interface, not a claim to
have qualified a new native runtime or a heap-free distribution. The equivalent
`local_package.py --source-archive ARCHIVE` option attaches that producer while
assembling a newly captured native package.

`upgrade_check.py` is the finite strict-rejection consumer for D51. Its
`--helper-command` file is an explicit JSON argv invoking the host's qualified
closed-workspace snapshot helper, with `{source}` and `{snapshot}` placeholders.
The helper must acquire the actual Java writer lock, reject unsafe resident or
resource ownership, return a single READY JSON line identifying both paths, and
retain its lease until stdin closes. A JSON record alone is not a snapshot safety
proof; the actual host implementation and its qualified artifact are required.

The harness runs the old and candidate immutable public launchers with EOF against
separate copies of that protected snapshot and fresh private image caches. The old
restore must succeed; the candidate must fail with the explicit
`--expected-rejection` diagnostic. An arbitrary crash does not pass. While the
lease is held, it checks the original file fingerprint and selected old generation
remain unchanged. After releasing the lease, it requires the selected old runtime
to restore the actual original controlled state. EOF sends no new proposal.
It never promotes a generation or changes checkpoint rows. Run only in the
steward's exclusive slot; snapshots and logs stay private and local.

The orchestration regression uses a synthetic readiness helper and substituted
process outcomes. It checks preserved selection/original bytes and rejects an
unrelated candidate crash. It does not establish host snapshot safety or native
cross-generation compatibility. The real 40ac/D44 regression remains pending the
qualified host snapshot helper and candidate artifacts.

The actual first independent overlay is local generation
`8cb3859a898e4a20df58d8a9ad5b183dbf3600a17a08c0c5a2de3ebef3c7f41c`
at `var/deployment-source-0006b59c/current`. It combines the unchanged 40ac native
runtime with source producer `0006b59c6f6840e28ba1affe763f48cd`, whose JAR SHA256 is
`b8a1388bebb2528aa4dcd69442e7019515f8f4e1716c881e3a5b834d825be72a`.
Staging verified 25,129 artifacts, including the independent producer's 22 pinned
source files. The native host JAR remains
`8486c19bca61025ac0f15f5ca3aa9dcf68f0652fba33c388405fa4eb379785f0`.
This records actual packaging; installed source workflow qualification is the
separate steward-run `source_check.py` consumer.

The actual installed source consumer passed in steward slot2, with result at
`var/deployment-source-check-0006b59c-slot2/result.json`: four separate packaged
JVM invocations imported the original-format fixture, inspected its captured
revision/edit token, committed an exact-byte edit, and reopened precisely the
replacement bytes. All four exited zero. The inspected Python remains
`UnresolvedExecutable`; the original-format fixture has no native `package.json`,
and inspection correctly reports that missing native descriptor. Import/edit
success does not claim conversion, executable admission or native execution.
The fixture's first slot was rejected for missing `manifest.json`; slot2 fixed the
fixture to obey the existing intake contract. No intake validation was relaxed.
The steward held the shared build lock and started no native authority for either
source-client attempt. Installed browser interaction, independent recipient
usability and Linux remain separate checks.

The independent source client captures the current host-side storage implementation,
whereas this first overlay retains the older 40ac resident host. The installed
source test establishes its own repeated source-store reopen path. Alternating
that source-edited workspace into the older resident host is not qualified by
these checks; schema and lifecycle compatibility need their own controlled-state
probe. Use a dedicated source-test workspace for this overlay. The later current
combined resident/browser test is distinct from this older installed resident
artifact, and must not be attributed to it.

The concise checked-in
[installed source evidence record](../../tests/deployment/evidence/source-install-0006b59c.json)
records the exact producer/package identities, four results and hashes of retained
local logs. Private state remains outside Git.

`source_browser_check.py` separately exercises the actual installed `source serve`
entrypoint: it keeps stdin open, reads the loopback URL, fetches the source-only
home page, opens the committed fixture through the real CSRF form, compares the
editor's decoded source to the exact expected bytes, and presses Enter for normal
shutdown. This checks packaged JDK HTTP-server and process-lifetime dependencies.
It does not visually inspect the page, edit source, run native execution or stand
in for an independent recipient trial. Its actual steward result is separate from
the four-command CLI result.

The installed source-browser transport check subsequently passed at
`var/deployment-source-browser-0006b59c-slot1/result.json`, using the same immutable
8cb385 generation and previously edited slot2 source state. Source-only home,
CSRF Open with exact committed bytes, and normal Enter shutdown all passed; the
process exited zero. Its hashes/results are in the same compact evidence record.
This is an actual installed HTTP consumer, while visual presentation and recipient
usability remain untested.


Bundled workshop sources are explicitly inventoried in
`deployment/tutorial-sources.json`: six retained-identity source/data/obligation
files and four branch-review source/obligation files. A package records their exact
hashes under `tutorials/`; these editable examples are not admitted capabilities.
Use `stage.py locate INSTALL --tutorial retained-identity` to obtain the verified
immutable source directory, then pass that exact printed path to `import-native`.
The current workshop overlay is local generation
`5945df55e408ddaf0847b63bcc3d4ebeb9ebefe360ae122351d89840530f90d5`
at `var/deployment-workshop-0006b59c/current`; its application/native JAR pins are
unchanged from the preceding source overlay. `workshop_check.py` checks the actual
bundled identity import, two browser saves that each yield a new source revision,
and exact source readback from a fresh CLI process. Its result is separate from
the earlier Open-only HTTP check.

Initial native/UI candidate `0e524e73e632a3416802d6e5252cfecc092aeb616c4ba1bbb18c514089737257`
was staged without changing the selected 40ac installation. It pins native capture
`db6edb9e17021542dd1f0617f44630e194c952dd315b5124ccab4a72e8fd3cac`
and UI JAR `a6f836eed91e5769170bf0fa00f34fe0d37a26fe9695a8a4d6f9b10caef83c56`.
The builder verifies every preserved heap/database hash and takes navigation ROOTs
from the steward's 23 immutable snapshots. It ships 76 exact DB-saved project
native sources and 31 exact UI producer sources. It excludes unrelated live draft
sources: the first attempted staging detected a changing supplemental navigation
file and preserved the old selected generation. Current native captures do not
sweep those mutable drafts into the package. Actual current installed native/UI
and protected failed-upgrade consumers remain separately recorded results.

These integration harnesses currently invoke the checkout's Python staging driver;
they are not checkout-independent recipient launch evidence. A separate pinned
bootstrap JAR and packaged `bin/veri7vn` are being qualified for standalone dispatch.
Its shell/JVM/Isabelle startup executes before manifest verification. Its own JAR
hash is not an independent trust root, and the package must remain immutable while
executing. Full manifest checks establish the stated integrity boundary, not a
signed-distribution or native theorem guarantee. D19 remains unresolved.


The first actual D51 trial of 0e524e restored the old clone successfully but rejected
the candidate before native restore because captured ROOT declarations referenced
six absent navigation-only theory siblings. This is a malformed source-navigation
closure, not the expected native compatibility refusal. The original selected 40ac
installation remained unchanged. The replacement candidate
`cb4e8d6efaf786211f10cddf677c11ac5b1ad4db5a4f282527aa024e8b065144`
adds only those six explicitly inventoried ROOT-declared source siblings, captured
privately before staging. None occurs in the 6c02 qualified source-pin map; they
are labeled unqualified header-navigation-only and are not admitted by bundling.
Exact native DB-saved sources always take precedence. Captured ROOT descriptions,
UI JAR, heaps and native evidence identities are unchanged. The replacement's
actual native and failed-upgrade consumers still require separate qualification.

The first standalone candidate is local generation
`dea4b0326b84e774fd35213fd9919b365f7d38675e2b1e86d9ea8e6ef8da6018`
at `var/deployment-ui-d44-standalone-101a005f/current`. It adds only launcher
producer `101a005f148c4d58b9b8ad2b1665745d` (bootstrap JAR, shell and five source
pins) to the cb4e8d native/UI package. Its shipped entrypoint is
`INSTALL/current/bin/veri7vn`; no checkout script is part of that entrypoint.
The new launcher-attached manifest declares `fresh-owned-temporary/1` with
`USER_HOME={bootstrap_home}`. Inspection and launch use a private temporary setup
home, while workspace and deployment images remain explicit durable state.
Persistent state-home `etc/settings` is not a startup authority. The Python oracle
retains the unresolved token in plans and allocates/cleans its own temporary home
only at launch; legacy packages retain their historical startup policy. Actual
standalone parity and installed source/native trials remain required.

The actual bundled workshop consumer passed at
`var/deployment-workshop-check-5945df-slot1/result.json`: installed identity import
committed, both browser saves produced new revisions and exact text, normal
shutdown exited zero, and a fresh packaged CLI read precisely the second saved
source. The compact [workshop evidence record](../../tests/deployment/evidence/workshop-install-5945df.json)
keeps results and log hashes; state and browser CSRF-bearing HTML stay local.
This is an established automated developer rehearsal of the installed source
workflow. It still uses the checkout's Python launch driver and is not a human
recipient trial, standalone launch, or native admission of the edited theory.

The corrected actual failed-upgrade preservation trial passed in slot3 at
`var/deployment-upgrade-d44-cb4e8d-slot3/result.json`. Under the qualified bounded
host snapshot lease, the old 40ac clone restored successfully, cb4e8d rejected the
other clone with the exact observed host diagnostic `native restore closure unavailable`,
and the original workspace fingerprint and selected 40ac generation stayed
unchanged. After helper release (exit zero), the old selected runtime restored the
actual original state successfully. The compact
[failed-upgrade record](../../tests/deployment/evidence/failed-upgrade-cb4e8d.json)
contains results and log hashes; snapshots/state stay local.

The rejection cause remains **unclassified**. A matching host error does not
identify the failed native association or prove the predicted D44 retained-row
cause. Slot2 failed the then-configured internal error-tag expectation; slot3 used
the exact observed host diagnostic and did not accept an arbitrary crash. This
establishes preservation for a controlled nonempty local mathematics workspace,
not successful migration, candidate promotion, general external-action replay
safety, or all private-data lifecycle cases. A positive fresh candidate consumer
remains a separate requirement.
