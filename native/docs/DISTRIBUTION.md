# Package the native appliance for another host

The distribution builder creates a local directory that runs without a source
checkout, Oracle7, Mini, an account or a network installer. It contains the exact
operator-selected extension and twelve explicitly listed Python adapter files.
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
theorem claim. Actual command results belong in the lane report and central
checkpoint receipt.
