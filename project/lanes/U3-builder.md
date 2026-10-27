# Callable program construction and Chameleon inspection

The appliance now has four provider operations implemented for the shared
`/operations` and `/invoke` service. This lane implemented the provider; the
service and Mini receiving lanes own the live wire and package qualification.

| Operation | What executes |
| --- | --- |
| `builder.compose` | Oracle's actual typed arithmetic composer generates Python and JavaScript from named numeric examples, executes its generated Python in a separate interpreter, then checks disjoint caller-supplied examples. |
| `chameleon.plan` | Chameleon's actual bounded MicroFold search over an explicit transition model, followed by its independent scalar plan witness check. |
| `chameleon.validate_plan` | Replays a supplied plan against its exact model and evidence digest. |
| `chameleon.validate_contract` | Validates the real declarative browser-contract format and returns its canonical digest. It does not execute browser actions. |

These computations accept supplied JSON data. They cannot select host paths,
commands, imports, URLs or repair repositories. They do not install a specialist,
grant Mini authority, or claim that a predicted repair happened. A generated
program is a proposal returned to the caller, not an automatically trusted tool.

The composer permits 1–4 labeled numeric inputs, 2–16 development examples and
2–16 distinct validation examples, bounded finite values, a 128-expression bank,
and bank expressions of size at most 3. Its upstream meet-in-the-middle step can
combine two bank expressions; this is not a three-node final-program bound.
Fitted constants and learned-library entries are disabled in this profile.
Matching retains upstream's 0.5% relative tolerance. Caller-supplied validation
examples are not a sealed held-out exam. No generalization or six-criterion
specialist-admission claim follows from passing them.

Chameleon permits at most 63 facts and 128 operators, at most 10 search rounds
with a 1,000-pair batch budget. Plans remain conditional on the supplied model;
no external website/application steps execute. Full website reconstruction still
needs the separately provisioned browser, acquisition/build dependencies and an
isolated mutable job profile. The operation catalog exposes the live subset and
its required inputs instead of reporting that all Chameleon features are ready.

## Source repairs

The private Oracle source is `var/ap1-upstream-slim`, based on `2a42ed7`.
Changed only `workbench/swarm/composer_v3.py` and added its focused
`test_composer_safety.py`:

- Task titles were interpolated into a Python triple-quoted docstring. A title
  that closed and reopened that string executed code during read-back. Titles
  now use a Python string literal and an escaped JavaScript comment.
- Read-back accepted an empty output list through `all(zip(...))` and did not
  require a successful subprocess exit. It now checks result shape, exact count
  and exit code before comparing outputs.
- Observational deduplication discarded a physical input if another input had
  the same sample values but different units. Its key now includes dimension.
- Search has explicit bounds, and the bank cap is enforced at insertion.
- Negative positional conversion terminated neither in `_in_base` nor generated
  Python. Unsupported negative input now refuses promptly.

Chameleon was fetched into the private clone `var/u3-builder/chameleon` from
`https://huggingface.co/psiloceyeben/oracle7-chameleon`; upstream remained
`cac0c3bccff793b63a0907e8ef3f679fa75f6a14`. Its independent witness checker
accepted JSON booleans as integer state/cost because Python considers `True == 1`.
`microfold.py` now requires actual integers and a dictionary report.

Exportable patches are
`deploy/appliance/patches/siblings/builder-oracle-composer.patch` and
`builder-chameleon.patch`. They are proposed source fixes, not upstream merges.

## Checks and consumer

- **11 provider tests passed**, using the actual repaired composer and Chameleon
  modules; synthesis, validation disagreement, title injection, exact read-back,
  dimension identity, hard bank bounds, malformed inputs, plan witness types,
  browser-contract refusal and unavailable source are covered. Oversized positive
  and negative JSON integers refuse before module loading or execution; the
  catalog names the composer's bounded temporary-file execution explicitly.
- **5 portable upstream composer tests passed**. The title test actually executes
  the generated module in a separate interpreter; its marker stays absent.
- A retained before/after replay (`var/u3-builder/regressions.json`) confirms:
  the original source executes the title marker and accepts an empty result,
  while the repair does neither; distinct input dimensions retained rise 1 → 2.
- The Chameleon boolean-witness counterexample was observed accepted before the
  repair and rejected after it.
- No specialist panels, Isabelle or Lean theorem checks ran. No theorem statement
  is introduced. No Mini admission, full browser execution or public deployment
  is claimed by this lane.

Provider: `tools/oracle_components/builder.py`, class
`BuilderOperations(runtime, workspace)`. Packaging uses
`adapter/builder_operations.py`. Chameleon needs only its stdlib
`packages/core/chameleon_core/microfold.py`, `browser_contract.py`, `LICENSE`
and `README.md` under `components/chameleon/source/`. Oracle's composer stays in
its existing `workbench/swarm` location. Service construction checks source
loadability and the explicit bounded composer interface before advertising live
availability. Root assembles and qualifies the actual appliance and Mini calls.
