# Specialist coverage inventory tool

`tools/dev/specialist-coverage.py` reconciles the specialist IDs in
`src/extract/families.json` with the read-only Oracle7 manifests, then emits a
JSON inventory or a Markdown view. It makes one row per manifest ID, so repeat
panels and probes do not inflate specialist counts. Run it from the repository:

```sh
python3 tools/dev/specialist-coverage.py --format json
python3 tools/dev/specialist-coverage.py --format markdown
python3 tools/dev/specialist-coverage.py --json-out var/coverage/inventory.json \
  --markdown-out var/coverage/inventory.md \
  --backlog-out var/coverage/semantic-audit-backlog.json
```

The default includes offline validation of the selected compile-input receipt
for each family. `--no-receipts` skips those reads. The command never runs a
scorer or a specialist binary. It exits nonzero when registry and upstream
specialist identity sets fail to reconcile. With any output-file option it
prints only concise counts and destination paths; without output-file options,
the selected `--format` is written to stdout.

The full JSON inventory includes `semantic_audit_backlog`; `--backlog-out`
writes that view separately. It lists IDs without an explicit exact-ID
semantic/gap reference in the searched reports, their family and current owner
group, any other missing text-cue references, and any existing cited text rows.
Family owners follow the current deputy areas in
`project/CODEX-2026-10-18.md`; relation readers map to symbolic. This is a set of
retrieval leads, not a completed semantic audit or a claim that no work exists.
The current generated snapshot is in `var/coverage/semantic-audit-backlog.json`:
24 IDs, grouped under 9 physical and 15 symbolic owner leads, with no unmapped
families.

The default audit directory is now tracked `project/audits/`. The first nine
partial records and their compact observations are committed there; see its README
for scope and actual open defects. `--audit-dir` still accepts a separate directory.
The original template is `var/coverage/audits/record-template.json`; replace its
placeholders before saving `<specialist-id>.audit.json` in the selected directory.
The machine-readable schema is `var/coverage/audits/record.schema.json`. A
concise record looks like:

```json
{
  "schema_version": 1,
  "specialist_id": "example-id",
  "family": "example-family",
  "examined_surface": {
    "request_types": ["..."],
    "model_scope": "..."
  },
  "cases": [{
    "case_id": "...",
    "kind": "counterexample",
    "request": "...",
    "expected_boundary": "...",
    "observed_behavior": "..."
  }],
  "actual_receipt": "var/.../receipt.json",
  "native_binding": null,
  "current_unresolved_limits": ["..."],
  "reviewer": "...",
  "owner": "...",
  "author_claims": {"summary": "..."}
}
```

`kind` may instead be `independently_checked_case`, which also requires an
`independent_check` description. `native_binding` can name a
`compile_inputs_manifest` and optional `registered_binary`; the tool runs its
offline native-input verifier and reports immutable receipt validity and
current source status separately. `actual_receipt` must resolve to an existing
repository file. The tool preserves the submitted object under `author_claims`
and puts shape/path/hash checks under tool-generated `validation`; it never
turns a record into a completion claim. Unknown IDs, duplicate IDs, malformed
records, and missing receipt paths are reported and make the command exit
nonzero.

The generated inventory has a separate `explicit_audit_records` section and
Markdown column; these records do not count as ordinary keyword references.
The original tool-only snapshot had **0 explicit audit records**; the later
root review added nine partial records. The template and schema are examples,
not evidence. Producers should include one file per specialist
they examined, keep `author_claims` as their own account, and leave the
tool-generated `validation` field out of the submitted file.

## Inventory at 2026-10-18

The live registry has **144 non-relation specialists**, matching all 144
non-relation upstream manifests. The upstream tree has **161 distinct relation
reader manifests**, for **305 unique specialist IDs** in total; identity
reconciliation reports no issues.

| Surface | IDs | Panel and verdict files present | Semantic ledger/report reference | Counterexample text | Change text | Same-line measured delta text | Limitation text |
|---|---:|---:|---:|---:|---:|---:|---:|
| Non-relation specialists | 144 | 129 | 134 | 40 | 82 | 0 | 98 |
| Relation readers | 161 | 161 | 147 | 0 | 1 | 0 | 0 |

For the 144 non-relation specialists, 14 more have a readable panel but are
missing at least one shipped verdict file, and one has no readable panel file.
All 161 relation readers have panel and verdict files. These are baseline file
availability counts, not a fresh veri7vn score. The tool also found
upstream-generated panel source files for 105 IDs; that is source availability,
not evidence that those versions are current.

The semantic column counts exact-ID references in every Markdown lane report,
regardless of wave letter, and in `semantic-gaps.md` ledgers. Ten
non-relation IDs have no such reference: `bodies-v2`, `calculus`,
`densities-r2`, `mechanisms`, `mechanisms-v2`, `physics-r2`, `physics-r3`,
`units-v2`, `units-v3`, and `units-v3-r2`. Fourteen relation-reader IDs also have no
reference: `rel-actors`, `rel-chemists`, `rel-composers`, `rel-graphicartists`,
`rel-journalists`, `rel-musicians`, `rel-painters`, `rel-philosophers`,
`rel-photographers`, `rel-physicians`, `rel-physicists`, `rel-poets`,
`rel-sculptors`, and `rel-singers`. The tags for counterexamples, changes, and
limitations are conservative keyword cues with source lines, not reviewed
judgments. Counterexample cues require a failure description; a score such as
“zero wrong” alone does not qualify. A delta counts only when the same exact-ID
line names a change, a before/after cue, and a measured `n/n` result; none of the retrieved lines meets
all three conditions. Family-level prose that does not name a specialist ID on
the same line is deliberately left unattributed. These are missing explicit
references in the searched files, not claims that the specialists lack
coverage or improvement evidence.

The offline receipt check found **15 `current_verified` family receipts**, **6
`verified_source_drift` receipts**, and **1 receipt with both binary mismatch
and source drift**, including the shared relations kernel. A `current_verified`
receipt passes immutable input checks, its registered binary matches the
receipt hash, and current proof/runtime sources match. `verified_source_drift`
means the receipt is valid and its registered binary matches, while current
sources differ. The combined status identifies a registered binary mismatch
as well as source drift. Other statuses distinguish an invalid immutable
receipt or unavailable current sources. The receipt's proof-source context
(`current_checkout`, `receipt_snapshot`, or unspecified) and current runtime
and proof differences are reported separately, so a retained proof snapshot
does not imply that the next/current sources match. These checks establish hash
consistency only: they do not establish theorem truth, natural-language
correctness, or complete dispatcher behavior. Receipt status is repeated on
specialist rows for navigation but is counted once per family in the summary.

Each JSON specialist row keeps its evidence separate. For example,
`semantic_evidence.semantic_reference` is `reference_found` or `unknown`, while
`records` contains the matching source path, line, section heading, tags, and a
short excerpt. Counterexample/change/delta/limitation fields are independent;
an upstream capability declaration cannot set them. Receipt status is a
family-level association and does not change semantic-reference status.

Capability files and relation manifests are displayed as declarations. Their
presence does not count as semantic evaluation or completion. The inventory is
intended to show where evidence is recorded and where the current file-based
search still has gaps, not to claim full-system coverage.

The counts above are a point-in-time snapshot. Rerun the tool after lane reports
or build receipts change.
