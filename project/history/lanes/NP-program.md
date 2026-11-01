# NP — whole KQA programs in the native runtime

Owner: native_program. Consumer: the Rust/PyO3 runtime request parser and the
reader's complete structured programs. Changed files:
`native/oracle-core/src/program.rs`,
`native/oracle-core/tests/program_contract.rs`, and this report.

There are **no specialist-panel numbers yet and no theorem statements** in
this lane. This is handwritten Rust, with executable contracts. Root runs the
centralized Linux checks; this lane did not run builds or tests. `rustfmt`
parsed and formatted both Rust files successfully. That is a syntax check,
not a passing contract-test claim.

## What it does

`Program` accepts the shipped list of `{function, dependencies, inputs}`
steps. An explicit 27-operation enum replaces method lookup. Its catalog
reports each operation's input count, dependency types and output type.
Unknown operations and fields fail admission. Dependencies must point to
earlier steps, input counts must match, and entity sets, typed values and
answers cannot be substituted for one another. All steps are checked, even
ones whose result is unused. Numeric and calendar literals use the bounded
native value parser. Invalid directions and selection/comparison operators
fail admission.

The compiler produces one native query graph. Entity branches retain sharing;
scalar steps become final projections. Indices are translated explicitly, so
an unused scalar step cannot shift an entity dependency. Target sets used only
by a final relation or selection projection remain graph dependencies. The
root-owned runtime entry points bind the original program bytes to retries;
this compiler does not replace those bytes with a serialized query plan.

The complete upstream operation mapping is:

| Upstream operations | Native operation |
| --- | --- |
| `FindAll`, `Find` | `all`, `find` nodes |
| `FilterConcept` | `filter_concept` node |
| `Relate` | `relate` node, explicit direction |
| `And`, `Or` | shared set intersection/union nodes |
| `FilterStr`, `FilterNum`, `FilterYear`, `FilterDate` | `filter_attribute`, explicit typed predicate |
| `QFilterStr`, `QFilterNum`, `QFilterYear`, `QFilterDate` | `filter_qualifier`, explicit typed predicate |
| `What`, `Count` | `unique_name`, `count` projections |
| `QueryAttr`, `QueryAttrUnderCondition` | `unique_attribute`, optional statement condition |
| `QueryAttrQualifier` | `attribute_qualifier` with attribute-value predicate |
| `QueryRelation`, `QueryRelationQualifier` | relation projections over two selections |
| `SelectAmong`, `SelectBetween` | selection projections, with explicit target for between |
| `VerifyStr`, `VerifyNum`, `VerifyYear`, `VerifyDate` | typed `verify` over a value projection |

All 27 operations defined by the pinned `steps_kb.KQA` have compiler mappings.
There is no fallback to Python. `QueryRelationQualifier` accepts exactly two
literal slots, relation and qualifier, following the actual implementation;
the source module's opening comment incorrectly mentions a direction slot.
Attribute-condition and qualifier-value predicates infer their kind from
the source statement because those KQA operations carry no type suffix.

## Deliberate semantic differences

The result is the native structured reply with selection, facts, typed values
and status. `What` refuses multiple entity candidates, including homonyms.
Typed value queries require agreement across matching statements. Selection
ties and ambiguous operands decline. Values from incompatible units remain
incomparable. These decisions intentionally replace upstream's arbitrary
first element or first statement. Empty sets remain usable in set expressions;
their count is zero. Root's host adapter can format a successful scalar reply
for a reader that needs a string.

This is the structured program front end, not the learned language reader,
its fragment search/cache, specialist dispatch, or an effect interpreter.
Those upstream capabilities remain outside this lane. Native value and
predicate semantics, including date precision, are documented and checked
in their owning lanes. No claim of full upstream language parity follows
from operation-name coverage.

## Checks and remaining work

The contract file has 14 checks with independent fixtures and adversarial cases for closed
operation admission, invalid dependencies and types, exact arity, invalid
operators and dates, request/node bounds, scalar-index translation, ambiguous
names/attributes, relation and attribute qualifier flow, statement conditions,
two-set projection dependencies, verification, unit incompatibility, selection
ties, and composition with empty sets. It also checks native lowering of the
typed filter and verification families.

Root must run these contracts together with the predicate/value/runtime
contracts on the designated build host, then record actual outcomes. Real
knowledge-base program qualification and specialist panels remain necessary;
this lane has not run them. No upstream operations from the pinned 27-operation
`steps_kb.KQA` surface are intentionally unsupported by the compiler. Unknown
operations and extensions are refused and must be added explicitly.

## Gold-program qualification tool

`native/tests/qualify_programs.py` is an untrusted Python measurement shim.
It has been implemented but not executed by this lane. It uses the existing
immutable image and runs the pinned Python source and native extension in
separate fresh processes. Default hashes bind the known knowledge base,
`val.json` (`b4aed6ab…98f3bb`) and pinned `steps_kb.py`
(`455fa3c7…16e3`).

The sample takes at most 20 programs per terminal operation, ranked by a stable
hash with a retained seed. Both implementations receive the same programs.
The receipt separately reports correct, wrong, withheld and unsupported answers
against the dataset, plus source/native disagreements. Comparison uses exact
answer strings: native unique values use their declared display, names use the
candidate name, counts use integer text, and verification uses `yes`/`no`.
Ambiguity and incompatibility remain withheld. The shim does not hide date,
unit, casing or numeric differences with normalization. A dataset disagreement
is a mechanical result that still needs semantic examination.

Use a new scratch directory and pass `--source`, `--validation`, `--steps`,
`--image`, `--image-receipt` and `--work`. `--extension` selects a particular
extension; otherwise the installed module is used. The tool writes its summary,
selected case identities, per-case observations, process diagnostics and at
most 30 mismatch examples by default. Retained mismatch records have a 16 KiB
detail bound and an explicit truncation marker when needed. Child failure or
timeout leaves an incomplete receipt. No corpus belongs in Git.

Coverage comes from live operations in the actual selected programs and the
observed native outcomes. The receipt names operations with no completed or
gold-correct program and reports terminal families separately. It explicitly
does not claim Rust line or branch instrumentation, or infer tested capability
from the native operation catalog. Root still needs to run the tool and record
the measured coverage and errors.

The qualification provenance now resolves the actual extension binary inside
an installed `oracle_native` package, validates its platform extension suffix,
and hashes that binary. The package wrapper path is retained separately; a
Python `__init__.py` is never reported as the extension binary.

`native/tests/test_python_program.py` adds four self-contained PyO3 integration
checks using a temporary tiny image and the installed module. They cover whole
program qualifier/value flow and ambiguity, restart and exact retry, tenant
state scope, query purity, retry separation between byte-identical bodies in
different dialects, and usable state/capacity after rejection or cancellation.
These additional checks have been authored but not executed by this lane.
