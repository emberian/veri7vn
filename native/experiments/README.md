# Native design experiments

These implementations explore possible next steps. They are outside the main
workspace and packaged service. Each crate compiles, passes `cargo clippy
-D warnings`, and passes its authored fixtures and tests on macOS arm64
([receipt](../evidence/2026-10-29-experiments-execution.json)). The expectations are hand-traced, not compared with an
independent implementation. Nothing is benchmarked, no performance result or
specialist-panel score applies, and none is registered in the service.

| Experiment | Question | Constraint exposed by writing it |
| --- | --- | --- |
| [Streaming queries](streaming-query/README.md) | Can shared integer postings and pull operators avoid string/evidence copies for scalar queries? | Relation projection changes order. Shared subplans and language admission still need explicit materialization or evaluation. |
| [Maintained views](maintained-views/README.md) | Can requested consequences persist across source changes without copying the public graph per tenant? | Insertions can propagate; deletions must rederive affected roots so cycles cannot justify themselves. Cache capacity must not dictate source truth. |
| [Conditional formulas](conditional-symbolics/README.md) | Can exact rational formulas share work and simplify under explicit domain assumptions? | Rewrites must preserve singularities and units. The current conservative domain check evaluates the original formula, so it adds work. |
| [Nonmonotonic scenarios](../oracle-logic/DEMOS.md) | Can agents revise evidence, reason with defaults and examine alternative plans? | Evidence withdrawal changes the program. A possible action is not a committed action; inconsistent evidence needs an explicit repair policy. |

The stable-model core used by the last experiment has its own executed checks.
The new scenario builder and examples do not inherit that qualification.

The production executor already uses SQL pushdown and shared subplans. A new
representation must improve a real consumer while preserving its semantics;
implementation language and the word “streaming” establish neither property.
Keep the existing implementations as references when choosing a narrow next
experiment. See the [current backlog](../../project/NATIVE-EXPANSION-2026-10-29.md)
for the work these prototypes do not replace.
