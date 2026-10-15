# Package descriptor schema

This developer-side check validates **structure only**. It neither loads Isabelle
nor resolves exports, executes code, grants assurance, or establishes file safety.
The corresponding integration contract is [C01](../docs/contracts/package.md).

Use Python 3.10 or newer. From the repository root, reuse the existing `.venv` if
present. For a fresh checkout without that environment, create it once:

```sh
python3 -m venv .venv
```

Install the developer dependency using either `uv`, if already installed:

```sh
uv pip install --python .venv/bin/python -r schemas/requirements.txt
```

or Python's bundled `pip` tooling:

```sh
.venv/bin/python -m pip install -r schemas/requirements.txt
```

Then run the fixtures or validate an individual descriptor:

```sh
.venv/bin/python schemas/check.py
.venv/bin/python schemas/check.py path/to/specialist.json
```

Do not recreate an existing environment merely to run these checks. Some project
environments created by `uv` omit `pip`; use the `uv` command in that case. Windows
uses `.venv\Scripts\python.exe` in place of `.venv/bin/python` for this schema-only
tool. Native Isabelle deployment has its own platform requirements.

The validator is the standard `jsonschema` implementation of Draft 2020-12; its
developer dependency is pinned. The runner also rejects duplicate JSON object
keys instead of silently keeping the last value. No network schema lookup is
required for validation.

The valid fixtures show complete declarations, unfinished capabilities, a theory
library, a data package and a blank development with documentation only. Empty
capability exports are permitted; a native session is required only when exports
are present. This allows support packages without dummy HOL capabilities.
Their native names and package files are illustrative and **do not resolve to an
implemented specialist**. They must not become deployment fixtures by accident.
The negative fixtures reject invented verification fields, misspelled properties,
unknown formats and unsafe/nonportable lexical paths. Path components currently
use a restricted ASCII spelling; actual loaders must additionally check resolved
filesystem containment, including symlinks.

This does not impose a product-wide wire schema. Native objects remain native;
future portable request/result codecs must implement C02–C05 without pretending
that JSON contains native theorem authority.

Current limits are intentional and tracked in C01: the schema cannot enforce
uniqueness of projected IDs/paths, native export kinds, import closure, source file
existence, build reproducibility or semantics. A valid descriptor may describe an
unfinished or unsafe development. It is suitable for editing and diagnosis, not
automatic admission.
