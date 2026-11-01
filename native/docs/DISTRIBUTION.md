# Package the standalone Rust appliance

Use the Rust [host](HOST.md) for the current standalone appliance. It serves
private loopback HTTP without Mini, a source checkout or an Oracle7 Engine.
The bundle contains the selected host binary, launcher, derived descriptors and
any explicitly admitted solver, extracted organs and Engine bridge helpers.
Public images and stores, an optional pinned Engine checkout and Python
environment, and every tenant journal/session remain outside the bundle. Supply
a separate absolute `--state-root` at each deployment.

The [31 October checkpoint](../../project/history/lanes/COHERENT-NATIVE-2026-10-31.md)
records a current Linux archive and its relocated qualification through all six
providers, the data runtime and supported real-U8 conversation routes.

## Quick start

These paths are examples for operator-supplied artifacts, not published download
locations. Obtain the frozen Linux host through the controlled build process,
with `reasoning,science,incremental,bio,statistics,logic` enabled. Create the
output parent directories first. For all six compiled providers without Oracle
images or corpora, generate configuration from the host and an admitted solver:

```sh
python3 -B native/oracle-host/tools/make_config.py \
  --host /operator/build/oracle-host --out /operator/config/host.json \
  --journal /operator/state/current/journal.sqlite3 \
  --pure reasoning,science,incremental,bio,statistics,logic \
  --solver /operator/build/clingo
```

The supplied-data computations use rows, sequences, models and graphs in each
request. Logic solving needs the admitted solver; selecting a feature alone does
not supply that executable. No Oracle7 checkout or data is needed for this mode.

For the intended runtime-plus-six-provider release, add these options to the
same command, using the actual admitted public image and its measured digest:

```sh
  --image /operator/data/image.sqlite --image-sha256 ACTUAL_IMAGE_SHA256 \
  --state /operator/state/current/sessions.sqlite3
```

The helper asks the exact host binary to declare its runtime release. Keep the
image at its external read-only location; the package does not copy it. Optional
Engine and extracted-organ arguments are described in [HOST.md](HOST.md).
Engine configuration must name a pinned materialization receipt and a usable
external Python environment. It is unnecessary for native-only operation.

Add `--conversation-profile native-v1` for bounded native entity and quantity
follow-ups with atomic state/reply recovery. This profile requires the native
image and excludes Engine configuration. An admitted extracted quantity binary
can supply numerical answers and their structured units without an Engine.

For a prepared Engine, keep the admitted public reader artifact external too.
The generated launcher accepts `--prepared-root /absolute/shared/public-reader`
to relocate that exact manifest and payload pair. Packaging verifies their hashes
with bounded streaming reads and does not copy the tables into the bundle.
The host independently admits their source binding and initializes prepared
workers before the executable announces readiness. See the [host lifecycle](HOST.md#public-preparation-for-legacy-python).

Next create the measured `release-input.json`, package, relocate and launch using
the commands below. Qualification applies only to the exact frozen artifact,
configuration and external resources that were exercised.

## Manufacture and qualify the Rust release

The current release path is `tools/appliance/package_host.py`. It needs no Mini
checkout or account. The older Python-extension format is documented below for
compatibility. Freeze source first; central validation builds `oracle-host` with
`reasoning,science,incremental,bio,statistics,logic` and uses
`native/oracle-host/tools/make_config.py` to admit the external image and select
those profiles. Its `--pure` value is that comma-separated list. Add `--solver`
only with a measured solver. Engine and extracted organs use that helper's
explicit options; neither is required. `--conversation-profile readonly-v1`
requires an image. Add `--conversation-entity-namespace wikidata` only for an
image whose entity identifiers the operator explicitly maps to Wikidata. The
helper forwards both options to the host manifest declaration and records them
in deployment configuration. Regenerate descriptors with the existing
`snapshot_descriptors.py` process before freezing when provider catalogs changed.

Create an external `release-input.json` with these measured fields:

```json
{
  "source_revision": "FULL_40_CHARACTER_FROZEN_GIT_REVISION",
  "source_archive": {"path": "/operator/source/frozen.tar.gz", "sha256": "ACTUAL_SHA256"},
  "target": "x86_64-unknown-linux-gnu",
  "features": ["reasoning", "science", "incremental", "bio", "statistics", "logic"],
  "toolchain": {"rustc": "ACTUAL_RUSTC_VERBOSE_VERSION", "cargo": "ACTUAL_CARGO_VERSION", "build_command": "ACTUAL_COMMAND"},
  "descriptors": {"path": "/operator/source/native/oracle-host/descriptors/pure.json", "sha256": "ACTUAL_SHA256"}
}
```

This records operator declarations and verifies the named input bytes; it cannot
prove that a binary was compiled from those sources. Keep the exact frozen source
archive alongside the release. A dirty-tree archive needs its own exact digest;
a Git revision alone does not identify uncommitted work.

```sh
python3 -B tools/appliance/package_host.py \
  --host /operator/build/oracle-host --sha256 ACTUAL_HOST_SHA256 \
  --config /operator/config/host.json --release-input /operator/config/release-input.json \
  --output /operator/releases/current --archive /operator/releases/current.tar.gz
mv /operator/releases/current '/operator/releases/relocated current'
cd /operator/unrelated
python3 -I -B -S '/operator/releases/relocated current/bin/oracle-host' \
  --state-root /operator/state/current --port 0
```

The archive has fixed `oracle-host/` entries, deterministic metadata, executable
host/solver/organ modes and exclusive publication. Its digest is returned beside
the payload manifest digest. Archive publication precedes directory publication;
a later directory collision leaves the archive for inspection. Images, stores,
Engine materialization, Python environment and all persistent state stay external.
The manifest includes requested profiles, source/build declarations, derived
catalog hashes, solver/organ hashes and Engine receipt identity. Hashing the
Python executable does not bind its standard library or installed packages.
Receiving-host dynamic libraries and optional Engine dependencies need separate
admission. This is an unsigned, nonhermetic artifact.

Central qualification supplies independent case data and starts the relocated
bundle from an unrelated directory. With the printed loopback address:

```sh
python3 -B /operator/source/tools/appliance/qualify_host.py \
  --bundle '/operator/releases/relocated current' --url http://127.0.0.1:PRINTED_PORT \
  --cases /operator/config/release-cases.json --out /operator/receipts/current-calls.json
```

Cases are a JSON array. Each contains `provider`, `operation_id`, `arguments` and
nonempty `expected` JSON-pointer/value assertions against the full reply. Use
`provider: "runtime"` for image-backed operations and the configured profile name
for compiled computations. Engine/extracted cases instead contain `text`, with
provider `engine` or `organ:ID`; assert the expected answer and actual route.
Every enabled provider needs a real call with an independently justified result.
The helper discovers every operation page, binds the running host digest to the
bundle, checks pure operation ownership through the bundled derived descriptors,
and records complete discovery and calls. It assumes trusted operator case data.
It does not infer correctness from a successful HTTP status. Central separately
records relocation, tenant separation, exact retry/restart, selected specialist
controls and receiving-host dependencies on these same artifacts. No new shipped
specialist-panel score or formal theorem is claimed by packaging.

For an enabled read-only Engine profile the package also copies the admitted
`conversation_adapter.py` beside `engine_worker.py`; both are manifest-bound,
and the adapter artifact is independently admitted by the host. No source
checkout adapter import is needed after relocation.

## Python-extension compatibility distribution

The distribution builder creates a local directory that runs without a source
checkout, Oracle7, Mini, an account or a network installer. It contains the exact
operator-selected extension and explicitly listed Python adapter files.
The interpreter and system libraries come from the receiving host. This is not a
hermetic operating-system image or a signed release.

It serves the [standalone private HTTP service](STANDALONE.md), including optional
[durable data runtime](RUNTIME-HOST.md) providers. Supplied-argument profiles need
no dataset. Runtime providers need a separately admitted image, complete release
declaration and persistent journal outside the bundle. Packaging copies none of
those resources and never reads an operator's private configuration.

## Manufacture a local artifact

First obtain the built extension through the project's controlled build process.
The builder does not build or execute native code. Pass its exact path, expected
SHA-256, new output directory and each desired profile explicitly:

```sh
python3 -B tools/appliance/package_native.py \
  --extension /operator/build/liboracle_native.so \
  --sha256 ACTUAL_EXTENSION_SHA256 \
  --output /operator/releases/native-2026-10-29 \
  --profile reasoning --profile science --profile incremental \
  --profile bio --profile statistics \
  --archive /operator/releases/native-2026-10-29.tar.gz
```

`runtime` is another allowed profile. Request it only when supplying its external
image, release and state configuration. A requested profile is not a claim that
the binary implements it. The builder records `profiles_requested` and leaves
`profiles_export_qualified` empty. Starting the service checks the admitted
extension's actual exports and catalogs; an unsupported profile fails startup.
Central qualification must exercise the resulting artifact before its profiles
are described as working.

Both output parents must exist. Existing destinations, symlink components,
traversal through `..`, nonregular inputs, incorrect digests and archives inside
the output directory are rejected. On macOS, `/tmp` and `/var` are commonly
symlinks; use their real paths, such as `/private/tmp`, rather than passing those
aliases. The extension may end in `.so` or `.dylib`; the copied file has the
importable name `lib/oracle_native.so`. The builder checks its bytes, without
claiming to recognize its architecture or provenance.

Each destination is published atomically and exclusively. A directory uses
Linux `renameat2(RENAME_NOREPLACE)` or macOS `renamex_np(RENAME_EXCL)`; an archive
uses an exclusive link in its destination filesystem. There is no overwriting
fallback. If both are requested, the archive is published first. Publication of
the two paths is not one transaction: if the directory then collides or fails,
the successfully published archive remains. Inspect the two destinations after
a publication error.

The archive uses a fixed top-level name, sorted entries, zero timestamps and
owner IDs, fixed modes and an empty gzip filename. The same payload produces the
same archive bytes. Rebuilding after source or checkout revision changes produces
a different manifest. No interpreter, corpus, credential, cache, `var/` directory
or general repository tree is copied.

## Contents and identity

```text
native-2026-10-29/
  bin/oracle-native
  lib/oracle_native.so
  python/appliance/
    native_service.py  native_pool.py  native_worker.py
    native_runtime.py  operations.py   serve.py
  python/oracle_components/
    reasoning.py  native_science.py  native_incremental.py
    native_bio.py  native_statistics.py  native_runtime_adapter.py
  operator.example.json
  README.txt
  MANIFEST.json
```

The launcher verifies the SHA-256, size and complete file set before importing
any bundled code. It refuses extra files, missing files and symlinks. The
manifest binds every included Python file, the extension, generated launcher,
example and instructions. It also records the builder's format/version and
source hash, the checkout revision, declared native workspace version and the
explicit import audit. These are declarations about the packaging inputs; they
do not establish that the selected binary was built from that checkout. The
extension's expected `API_VERSION` is read from the Python export source and
marked unverified. Its observed value belongs in central qualification, rather
than being guessed from a filename or the workspace's version.

The launcher runs with Python isolation, disabled bytecode and disabled site
packages (`-I -B -S`). It re-executes itself with these flags if they were omitted.
It sets the two fixed bundled adapter paths itself. Python workers use the
service's existing isolated subprocess protocol and fixed sibling runtime
loader. No `PYTHONPATH` setting or source checkout is needed.

The closure audit checks every static import and the three existing dynamic
loaders. The shared `serve.py` and `operations.py` also contain dormant Engine
paths. Their `tenant_pool` and `sympy` imports are explicitly listed as dormant;
the native entrypoint never calls `serve.main` and constructs `Operations(None)`.
The distribution does not expose the upstream Engine/workbench loaders. An
unreviewed dependency or changed dynamic-loader inventory fails packaging.
This inventory is not a proof of Python reachability or a Python sandbox.

The manifest is unsigned and cannot authenticate itself. Keep its directory and
operator sidecars protected from untrusted replacement, and retain the manifest
digest through the operator's release process. Hashes attest bytes included in
this distribution; they do not attest the interpreter, standard library,
linked libraries, source-to-binary build or host kernel. The host must admit
trusted native code.

## Relocate, configure and run

Copy or extract the directory to its final location. The launcher locates its
payload from its own path, so the working directory is unrelated:

```sh
python3 -I -B -S /operator/releases/native-2026-10-29/bin/oracle-native --verify

python3 -I -B -S /operator/releases/native-2026-10-29/bin/oracle-native \
  --write-config /operator/config/native.json

python3 -I -B -S /operator/releases/native-2026-10-29/bin/oracle-native \
  --config /operator/config/native.json
```

`--write-config` creates a new file with mode `0600`; it never overwrites one. It
writes the absolute bundled extension path and supplied digest. To relocate
again, regenerate/update that external config. Alternatively, copy the bundled
`operator.example.json` to an external configuration path and retain its
`@bundle/extension` marker: the launcher resolves that marker at each start.
All providers must use this bundle's digest, extension and requested profiles.

Pure profiles can use the generated example directly. Runtime examples contain
explicit placeholders and cannot start until replaced with a complete admitted
release and real hashes. Runtime `image` and `state` must be absolute external
paths. `manifest_json` preserves exact release JSON numbers as text; use the
runtime host contract for admission, core limits and durable retry behavior.
The launcher makes a temporary `0600` configuration inside a private directory
to reuse the service's existing parser, then removes it. Images, journals and
corpora remain at their operator-owned locations across worker/service restart.

The service prints its loopback address after successful admission. Port zero
selects an available port. Calls use the existing standalone HTTP protocol and
host-assigned tenant routing header. That header does not authenticate a user;
an authenticated outer gateway and isolation from untrusted local clients remain
the host's responsibility. Packaging does not install a service, change system
configuration or deploy a public endpoint.

## Receiving-host requirements

Use CPython 3.12 or newer on Linux or macOS. The project builds the PyO3 extension
for `abi3-py312`, but the supplied artifact must actually match that ABI and the
receiving host's operating system and CPU architecture. The builder records its
own OS/architecture as context, not as an inspection of the extension target.
The shared service imports POSIX `fcntl` and uses process groups and `resource`;
Windows is not supported by this distribution.

Supply the extension's actual dynamic dependencies on the receiving host.
Inspect the admitted artifact with `ldd` on Linux or `otool -L` on macOS and test
there. The archive does not copy system libraries or a Python interpreter. No
network dependency installation runs at packaging or startup. Worker containment
and its platform limits remain those described in the standalone service docs;
this package adds no filesystem/network sandbox.

## Central qualification

The central integrator runs the scoped manufactured contracts:

```sh
python3 -B -m unittest discover -s tests/appliance -p test_package_native.py -v
```

With an actual combined artifact, the same suite also manufactures a tiny reader
image, packages into a temporary directory outside the checkout, moves it to a
path containing spaces and launches from an unrelated directory with poisoned
`PYTHONPATH`. It discovers bio, statistics, graph and reader operations; calls
alignment, regression, supplied MST and graph query; then checks exact durable
reader retry across a fresh service start with the same external journal:

```sh
ORACLE_NATIVE_TEST_EXTENSION=/operator/build/liboracle_native.so \
  python3 -B -m unittest discover -s tests/appliance -p test_package_native.py -v
```

The actual case requires reasoning, science, incremental, bio, statistics and
runtime support. The inert-extension cases never import their manufactured
binary. Integrity verification alone is not native export qualification. These
are distribution/runtime fixtures, with no specialist-panel score or new formal
theorem claim.

The [29 October stable qualification receipt](../evidence/2026-10-29-stable-appliance-validation.json)
records a passing actual relocated package journey on hbox for code commit
`77731632484d0c7129362dca150eb5310cb70233`, extension SHA-256
`f875fc2e217cbe5b7b4de196d546b717a105b28e9767b49905570f1893ae2a37` and observed
`API_VERSION` `0.2`. That journey exercised discovery, alignment, regression,
supplied MST, graph query and exact durable reader retry after service restart.
The [lane report](../../project/history/lanes/NDIST-2026-10-29.md) records the seven
manufactured checks and retained archive details. The archive is
`var/expanded-runtime-20261029/native-appliance-linux-x86_64.tar.gz`; its digest,
payload manifest digest and remote directory are in the receipt. Manufacture
metadata does not qualify itself: this separate result applies to the exact
tested frozen closure and artifact. Receiving-host interpreter, platform and
system-library requirements still apply, and images, journals and credentials
remain external.
