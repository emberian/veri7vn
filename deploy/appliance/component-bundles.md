# Selected components in an appliance

Components are optional source bundles, selected by the operator before building
a new appliance. A bundle never grants authority, installs Python packages,
fetches assets, or runs source code while provisioning. The query/analysis,
builder, and network-builder profiles are packaging declarations. The current
service exposes all packaged providers; it does not enforce separate component
profiles. Mini controls the appliance's grants, without per-component runtime
authorization. These declarations must not be treated as isolation boundaries.

`provision.py` consumes a **frozen manifest plus its SHA-256**:

```sh
python deploy/appliance/provision.py --source "$ORACLE_GIT" \
  --target "$NEW_CANDIDATE" --cache "$CACHE" --adapter tools/appliance \
  --component-bundle trafficcop.bundle.json "$TRAFFICCOP_MANIFEST_SHA256"
```

Repeat `--component-bundle` for other selections. Existing candidates remain
untouched. Each selected Git source is exported from an exact commit, patched
with exact reviewed patch bytes, and reduced to the selected file allowlist.
Live checkout edits and untracked files never enter that export. Every selected
file must match its final hash, size and executable bit. Unresolved LFS pointers
are refused; no component download is implicit.

## Freeze a reviewed selection

Start with explicit file names and local input paths:

```json
{
  "id": "trafficcop",
  "status": "available",
  "profile": "analysis",
  "requirements": [],
  "unavailable_reasons": [],
  "source": {
    "repository": "https://huggingface.co/psiloceyeben/oracle7-trafficcop",
    "checkout": "../../var/u3-sibling-decisions/oracle7-trafficcop",
    "revision": "08a9f1e70b8e78d9078b4bd9f308b99b9800bcb0",
    "patches": ["patches/siblings/decision-trafficcop.patch"],
    "files": ["LICENSE", "README.md", "trafficcop/__init__.py", "trafficcop/model.py"],
    "notices": ["LICENSE", "README.md"]
  },
  "adapter_files": {
    "component_operations.py": {"path": "../../tools/oracle_components/decisions.py"}
  }
}
```

Paths in an input selection are relative to that selection's directory. Adjust
them for its actual location; they are operator inputs, never request fields.
The source commit is mandatory. Patch entries may instead be objects containing
`path` and `sha256` to require an already-reviewed patch identity.

```sh
python deploy/appliance/provision.py --freeze-component selection.json \
  --out trafficcop.bundle.json
```

This writes a new file, prints its SHA-256, and does **not** construct an
appliance. It replaces source-file lists with final byte identities, pins the
patches and local provider files, and expresses local locator paths relative to
the output manifest. Repeating an unchanged selection in the same directory
produces the same manifest bytes. Existing output files are never overwritten.
A changed provider, source selection or patch requires a newly reviewed manifest.

For an adapter-only component such as Workbench, omit `source`. Select only
`adapter_files`. Additional assets can be selected through an `assets` mapping
with the same `{path: local_input}` shape and an `asset_notices` list naming its
included license/notice files. Asset destinations are isolated below that
component's `assets/`; no caller chooses a host file or download URL.

## Installed layout and receipt

```text
adapter/operations.py
adapter/workbench_operations.py
adapter/component_operations.py
adapter/visual_operations.py
adapter/builder_operations.py
components/<id>/source/<selected upstream path>
components/<id>/assets/<selected asset path>
```

The provider filenames are explicit manifest entries, not a recursive copy of
an adapter workspace. Multiple components may share one identical provider file;
conflicting contents are refused. No component can overwrite a file supplied by
the base Oracle source, patches, or legacy `--adapter` selection. When using
`--adapter tools/appliance`, its existing `serve.py` and README are retained;
select the new `operations.py` through an adapter-only manifest. Alternatively,
an adapter-only manifest may explicitly select all three files without
`--adapter`.

`APPLIANCE.components[id]` contains:

- The frozen manifest hash, `status`, `profile`, `requirements`, and explicit
  `unavailable_reasons`, plus optional `execution_notes` describing behavior
  such as Composer's temporary execution of its own generated programs.
- `source_root: "components/<id>/source"`, and source repository, commit, patch
  hashes, selected `files` identities and `notices`; both source fields are null
  for adapter-only components.
- Provider and asset identities. Local checkout/input paths are omitted.

The ordinary `APPLIANCE.files` map also covers all installed component files;
`APPLIANCE.adapter_files` includes every installed provider hash. The receipt
establishes composition and byte identity, not dependency import success,
capability correctness, or permission to act.

## Requirements and unavailable functions

`status` is `available`, `partial`, or `unavailable`. Partial/unavailable bundles
must state reasons; missing source or asset bytes are not silently replaced.
These declarations describe the selected component's scope. The service still
checks actual runtime dependencies and reports operation-specific availability.

Every requirement has `kind` and `name`. A Python requirement additionally needs
an exact `version`, for example:

```json
{"kind": "python", "name": "Pillow", "version": "11.3.0"}
```

Provisioning records this requirement and does not run pip. Add its pinned wheel
to a separately qualified target rootfs before enabling operations that need it.
The visual components can use supplied exemplars and sprites; absent pretrained
libraries and OCR assets remain explicit limitations, not automatic downloads.

A dependency on repaired Oracle source may use `kind: "appliance-file"` and its
runtime-relative `name`. The selection supplies a local `path`; freezing records
its SHA-256 and size, and staging checks those exact bytes in the patched base
runtime. This prevents accidentally bundling a new provider with an old core
module. Other dependency descriptions are retained as declarations; a requirement
with `available: false` must explain `reason`.

No component manifest broadens Mini grants. An operator needing separate
authorization for analysis and builder operations must provide separate
appliances or add an enforcement mechanism; the profile field alone does not
provide it. All bundled providers currently share the appliance's authority.

## Reproduce the U3 candidate

The reviewed selections are in `components/*.selection.json`; their frozen byte
identities and local, repository-relative input locations are in
`components/locked-u3-v1/`. These manifests include six sibling source bundles
and the Workbench and core operations providers. Chameleon and Workbench also
pin the repaired core modules they consume.

`candidate-u3-v1.recipe.json` records the ordered command arguments, exact base
commit, and construction-input hashes. Run from the o7vn repository after
preparing the listed Git checkouts, patches, verified data cache, and kernel
overlay. The named target must not exist. To verify the inputs before executing
the recorded command:

```sh
python3 - <<'PY'
import hashlib, json, pathlib, subprocess
recipe = json.loads(pathlib.Path('deploy/appliance/candidate-u3-v1.recipe.json').read_text())
for name, expected in recipe['input_sha256'].items():
    if hashlib.sha256(pathlib.Path(name).read_bytes()).hexdigest() != expected:
        raise SystemExit('Construction input changed: ' + name)
subprocess.run(recipe['argv'], check=True)
PY
```

The materializer additionally checks every frozen component input, final patched
core dependency, store and kernel. A successful construction produces
`APPLIANCE.json` inside the new target; this describes byte identity and
composition, not service acceptance or mathematical correctness. Python
dependencies are supplied by the separately qualified rootfs.

The completed construction is recorded in
[`candidate-u3-v1.receipt.json`](candidate-u3-v1.receipt.json): 8 components,
31 selected upstream source/notice files, and 46 component/provider/core files
rechecked after publication. Its full `APPLIANCE.json` SHA-256 is
`7dbb6899ff72490cdfc5f5e383dda4a7671656ac47747a453c4026a1c1504a23`.
Service and Mini acceptance are separate checks.

### U3 v2: discover the full-engine query operation

The subsequent candidate adds `core.query` to the operation catalog so callers
can use the complete engine's guards, composition and conversation through the
same discovery interface. Its frozen inputs are in `components/locked-u3-v2/`;
use `candidate-u3-v2.recipe.json` in the reproduction command above.
[`candidate-u3-v2.receipt.json`](candidate-u3-v2.receipt.json) records its result.
Only `adapter/operations.py` and `adapter/README.md` differ from v1. The v1
candidate, recipe, locks and receipt are preserved.

The v2 `APPLIANCE.json` SHA-256 is
`e87aaadc39a6d7767e88aa34cd5b593f718ecd7256591e462865c9f6b2a003ec`.
Its 46 component/provider/core files were rechecked after publication. This is
composition evidence; service and Mini acceptance are recorded separately.

### U3 v3: revised premise and title routing

`candidate-u3-v3.recipe.json` retains the v2 component locks and adapters. It
replaces the fourth ordered patch with
`patches/oracle7-slim-4.9-operations-v3.patch`; do not apply both versions of that
patch. The earlier patch remains available for reproducing v1 and v2.
[`candidate-u3-v3.receipt.json`](candidate-u3-v3.receipt.json) records five changed
core/test files and confirms unchanged component, adapter and store identities.
The v3 `APPLIANCE.json` SHA-256 is
`05c15112339540e3d1329babbbd86f231c2a91722b360379090ddf98b61092fa`.
