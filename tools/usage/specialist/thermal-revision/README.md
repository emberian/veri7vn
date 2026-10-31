# A corrected measurement changes a thermal decision

This consumer connects the existing hosted evidence workspace to the existing
thermal calculation. It asks whether a supplied chip stays at or below 306 K.
A 300 K ideal sink and a 2 W/K link give 304 K at 8 W. Correcting the load to
16 W changes the answer to 308 K: reject. Correcting the link to 4 W/K gives
304 K: accept. These are calculations about supplied data, not a forecast.

`example.json` declares each measurement's value, unit, target, source, source
revision and support atom. The atoms contain no numerical encoding. The package
explicitly supplies the association between an evidence atom and a measurement;
the evidence engine does not check the measurement's provenance or its accuracy.
Even an unrelated rule deriving the support atom selects that caller-declared
measurement; the adapter does not match its source labels to observation sources.
Source revision is the supplied source's label, not a workspace revision.

Every declared target requires at least one skeptically supported measurement.
Multiple supported records with exactly equal values are alternative supports.
A disagreement withholds the decision; there is no vote or automatic preference
for a later source. Withdrawing one agreeing support preserves the other.
Withdrawing every support withholds, without falling back to the base model.
The coverage rule requires the supplied coverage record, so withdrawing that
record also withholds. Coverage is an explicit supplied premise, never evidence
that all measurements in the real world have been collected.

The output binds the evidence receipt (including exact revision and snapshot),
complete supplied measurement package identity, complete adapted model identity,
and numerical network identity. The consumer reconstructs the exact evidence query from the host support
templates and checks its compiler, request and program identities plus answer
atom IDs before selecting records. The numerical consumer checks the returned
original-node power balances independently and retains node temperatures and
reservoir exchanges. A later concurrent revision cannot alter that result; the
result does not claim to be the latest when it returns. A content hash detects
changed input; it does not authenticate a source. The JSON input uses the strict
existing parser, rejecting duplicate keys and nonfinite constants.

Run against a native host with logic/clingo and science enabled:

```
python3 tools/usage/thermal_revision.py --url http://127.0.0.1:8000 --cursor var/thermal-revision/cursor.json
python3 tools/usage/specialist/thermal-revision/scorer.py --url http://127.0.0.1:8000
```

The first command can resume its exact pending evidence mutation using the
existing durable client cursor. Solve or numerical transport failure leaves
committed evidence in place; restarting repeats calculation for that snapshot.
The cursor is bound to the complete plan, tenant, conversation and host runtime.
The scorer creates a new isolated conversation and checks seven revisions plus
an injected numerical transport timeout, unchanged host checkpoint and exact
retry. That injection tests client failure after evidence commit, not a host
solver deadline or process crash. Use the existing evidence recovery tooling for those
separate boundaries. Central qualification ran all eight checks successfully, with zero wrong answers
or execution errors ([receipt](../../../../native/evidence/2026-10-31-coherent-native-validation.json)).
These are supplied-model workflow cases, not shipped Oracle7 panel numbers.

Each call freshly prepares the complete adapted network and executes the existing
thermal scenario operation. Conductance, topology or fixed-boundary membership
changes therefore always reprepare. Load-only changes could reuse valid factors
through the native prepared API, but this HTTP consumer does not retain factors
across requests or claim that optimization. Fresh execution remains the reference.
Within each operation, the existing thermal scenario code uses its retained
factorization and original-node checks.

Run the narrow adapter checks with
`python3 tools/usage/specialist/thermal-revision/test_contract.py`. They cover
strict targets, conflicting target key orders, swapped answers, altered request
templates, units and free-node targeting. The central receipt records the executed contracts and live workflow separately.

The numerical code and adapter are untrusted and add no Isabelle theorem. Units
are explicitly W and W/K; conversion is intentionally absent. The model assumes
steady passive linear conduction and cannot establish cooling capacity, physical
measurement accuracy, uncertainty bounds or transient safety. Hosted execution
must be qualified on the designated remote build host before publication; a
local fixture or syntax check is not that qualification.
