# C01 — Specialist package

Semantic revision 1. Descriptor format remains `veri7vn.package/0`.
Descriptor structure is implemented by
[`schemas/package.schema.json`](../../schemas/package.schema.json). Loading and
native export validation remain work for the packaging and admission lanes.

## Authoring model

A package contains ordinary editable source, examples, and explanatory material.
Its descriptor indexes that development; it does not restate HOL types, domains,
formulas, theorem statements or implementation relations in independently editable
JSON. Approachable rules/formulas may be the source from which native artifacts
are generated. The generation recipe and inputs must remain available; generated
output is not a second authoritative authoring surface.

The descriptor declares:

- a package ID, release version, title and description;
- package-relative files with source/example/documentation/data roles;
- exact package release dependencies (the loader later resolves immutable generations);
- an optional native Isabelle session and exported theories;
- named capability exports, each pointing to a native specification and optional
  contract theorem and executable-definition locators.

The capability list may be empty. Theory libraries, source-data packages, support
packages and unfinished developments do not need dummy capabilities. `native` is
required when any capability is exported; it is optional for an empty export list.
A package with a native theory library may declare its session without exporting
capabilities. Data-role files can hold a source corpus. Descriptor validity grants
none of these packages execution, import safety or proof authority.

All export locators are declarations to resolve, never evidence that their referents
exist or satisfy a contract. A partially developed package may declare no contract
theorems or executable definition. It can be edited and inspected, but cannot claim
an execution guarantee merely because its descriptor passes validation.

A `native_locator` is `{theory, name}`. `theory` selects an exported theory context
declared in `native.theories`; it does not assert that the referenced object was
originally defined in that theory. `name` is the fully qualified native lookup name.
Resolve it in the selected theory's context, preserve the native result, and verify
the resulting canonical name rather than accepting an unrelated short-name match.
Imported objects may be re-exported through that context with their original names.
Session-qualified theory lookup and native logical-name qualification are distinct:
do not generate one by blindly concatenating the other's strings.

IDs are package-local capability names and dotted package names, using lowercase
ASCII letters, digits, underscores and hyphens. A capability's portable name is
the tuple `(package_id, package_version, capability_id)`; the resolved generation
must additionally distinguish different contents under the same release label.
Do not concatenate this tuple using a delimiter that an ID could contain.

## Native loading obligations

1. Resolve files inside the package root after following symlinks; lexical path
   validation alone is insufficient. Reject duplicate file paths, capability IDs
   and dependency IDs. The schema cannot enforce these projected uniqueness rules.
2. Verify required files exist, declared theories belong to the selected session,
   dependency closure is resolved, and source paths have portable casing. Imports
   and selected code setup must be recorded in the generation's build manifest.
   The descriptor's source-role files identify editable package inputs, including
   its session description and local theories. This list is not the complete closure
   of transitive Isabelle imports, included ML files, runtime libraries or generated
   inputs. Resolve and record that closure through the actual build process; a
   smoke fixture can check its known local inputs without claiming a general loader.
3. Resolve each export in the approved theory context and check its actual kind.
   A specification is a native constant/term binding; a contract is a theorem;
   an executable definition is a candidate attachment requiring C02 validation.
4. Build through the controlled development process. An arbitrary Isabelle theory
   can run arbitrary ML or introduce axioms; a syntactically valid package is not
   safe to auto-admit. Ordinary declarative extensions and explicitly trusted native
   plugins require different admission policies.
5. Produce replayable sources and dependency/build records. Prebuilt heaps are
   runtime artifacts, not substitutes for editable development.

## Compatibility and author feedback

Adding an export does not establish that old dispatch behavior is preserved.
Interpretation overlap, default resolution, effects, dependency closure and code
setup are observable parts of a change. Replacing an implementation must retain
the established observation/refinement relation or explicitly publish a changed
capability generation. Bug repairs and upstream compatibility are separate claims.

Authoring diagnostics should point to the relevant source and failed obligation,
show concrete counterexamples when available, and preserve alternatives when a
repair changes intent. Native specifications, diagnostic source maps, tests,
performance records and build outputs should remain navigable from the package.

## Qualification, activation and transfer

Keep native semantic admission (C02), operational qualification and active publication
separate. A proved kernel can have an intrusive recognizer, regress abstention or miss
deployment requirements. Qualification records bind candidate and baseline artifacts,
interpretation/routing policy, learned state, source/state observations, exam/scorer,
dataset/split, runtime/resource conditions and exposure history. Preserve negative-space
and extension-interference tests alongside successful answers and measured cost.
Tests never substitute for proof, and proof does not waive product qualification.

Development runs, repeatable regressions and fresh held-out evaluation are distinct.
Imported exam history remains attributable sender evidence; rerunning an exposed set
does not become fresh recipient evidence by deleting its log. Aborted/spent runs must
not become measured successes or failures. Exact holdout discipline, thresholds and
activation criteria remain explicit policy decisions, not inherited accidents.

Feedback links an attributable event to the actual request/result/invocation and
distinguishes intended interpretation, factual correctness and route choice. It
proposes a versioned policy change, evaluated before atomic activation; failed
qualification leaves the previous policy active. Correction/undo and retention
apply to feedback and derived learning. A user's "right" mark is not a proof.
Gap-derived examples retain their original request/reason and proposal status;
an unanswered question or blank expected value is not training ground truth.

Exports select classified contents rather than copying every local file or relying
on a single private/source flag. Check transitive included artifacts: examples,
feedback, recall indexes and traces may contain private material. Credentials remain
references outside transferable packages. Integrity hashes, attribution/registration
and exam receipts are different from semantic proof. Transfer records the chosen
contents and recipient dependencies without promising authority or replayability for
material deliberately omitted under retention/export policy (C04). Exact publication
and external registry compatibility remain scoped product decisions.

These obligations come from [G05/G07/G08](../review/PREIMPLEMENTATION.md) and
[workbench findings 1–5/8](../review/workbench-gaps.md). They add no descriptor fields
in format 0 and do not claim a qualification or transfer engine already exists.

## Cross-lane acceptance

- Authoring: a fresh package can be created, built, inspected, repaired and rebuilt
  without editing generated semantics twice.
- Admission: descriptor strings resolve to exact native objects and unresolved
  or wrong-kind exports fail clearly.
- Deployment: a clean end-user installation can load the produced package and its
  pinned dependencies without an unexpected theory build.
- Migration: opaque Python adapters remain labeled adapters; descriptor conformance
  never counts as a completed formal lift.
