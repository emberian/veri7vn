# Package descriptor structure

[C01](../docs/contracts/package.md) descriptors use pinned `jsonschema` Draft2020-12 with duplicate-key rejection and offline validation. Python≥3.10:

```sh
python3 -m venv .venv
uv pip install --python .venv/bin/python -r schemas/requirements.txt
```

Reuse an existing environment. Without `uv`, install with:

```sh
.venv/bin/python -m pip install -r schemas/requirements.txt
```

```sh
.venv/bin/python schemas/check.py
.venv/bin/python schemas/check.py path/to/specialist.json
```

Windows substitutes `.venv\Scripts\python.exe`. A uv-created environment may omit pip.

Fixtures cover complete/unfinished capabilities, libraries, data and documentation-only packages. Empty exports are allowed; exports require a native session. Example names are illustrative. Negative fixtures reject invented fields, unknown formats and unsafe lexical paths.

Validation establishes structure, not admission. Loaders must resolve symlink containment, exports/kinds, projected-ID/path uniqueness, imports, files and reproducibility. Semantic safety and C02–C05 native authority require their respective consumers.
