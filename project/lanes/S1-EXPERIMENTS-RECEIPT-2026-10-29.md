# S1-EXPERIMENTS-RECEIPT, 2026-10-29

Consumer: root integration. Root still owns `project/HANDOFF-CLAUDE-2026-10-29.md`
and `project/NATIVE-EXPANSION-2026-10-29.md`, which keep the old "never compiled
or run" wording until root edits them.

## What this establishes

The four Rust design prototypes compile, pass `cargo clippy --all-targets -- -D
warnings`, and pass their authored fixtures and tests on macOS 27.0.1 arm64
(rustc 1.98.0-nightly 2026-06-21). Receipt:
`native/evidence/2026-10-29-experiments-execution.json`. Logs (one per crate and
step, plus `.exit` files) are in `/Users/ember/dev/o7vn/var/s1-experiments/`.

## Checks and exact results (all exit 0)

| Crate | fmt --check | clippy -D warnings | fixture run | cargo test |
|---|---|---|---|---|
| streaming-query | clean | no warnings | `cargo run` printed the fixture line | 10 passed (`tests/fixture.rs`) |
| maintained-views | clean | no warnings | `cargo run --example transitions`, silent | 4 passed (`tests/transitions.rs`) |
| conditional-symbolics | clean | no warnings | `cargo run` printed "authored conditional-symbolics fixtures reached end" | 7 passed (`tests/fixture.rs`) |
| oracle-logic | clean | no warnings | `cargo run --example reasoning_lab` printed 13 JSON readouts | 19 passed, 2 ignored (3 new in `tests/demo_consistency.rs`; the 2 ignored need `CLINGO_EXECUTABLE`) |

No lint was weakened; no `allow` attribute was added. No source needed a lint fix.

The `maintained-views` example prints nothing. It contains 18 lines of
`assert!`/`assert_eq!`/`assert_ne!` that executed, so exit 0 means they held.
The same four README traces are now also tests.

`oracle-logic`: `tests/demo_consistency.rs` runs the example binary in default
mode (no solver) and checks, for the thirteen readouts: titles, status and model
lists match the DEMOS.md table; every handwritten model has no unsupported atoms,
nothing further derivable and no violated constraint under the builder's rules;
the handwritten skeptical/credulous answers equal what the handwritten models
imply; the two inconsistent readouts list no models and have null answers. This
is a consistency check of the demo layer. It cannot show a model list is
complete, and it is not a solver result.

## Changed files

- New tests: `native/experiments/streaming-query/tests/fixture.rs`,
  `native/experiments/conditional-symbolics/tests/fixture.rs`,
  `native/experiments/maintained-views/tests/transitions.rs`,
  `native/oracle-logic/tests/demo_consistency.rs`.
- New lockfiles: `Cargo.lock` in the three experiment crates (oracle-logic had one).
- `.gitignore`: `native/experiments/*/target/`, `native/oracle-logic/target/`.
- Receipt: `native/evidence/2026-10-29-experiments-execution.json`.
- Header comments only (no behavior change): the first line of
  `streaming-query/src/{lib,main}.rs`, `maintained-views/src/lib.rs`,
  `maintained-views/examples/transitions.rs`, `conditional-symbolics/src/{lib,main}.rs`;
  in `oracle-logic/examples/support/mod.rs` one doc line and the `qualification`
  string in the printed JSON (now "demo layer: handwritten expectations, no solver
  executed").
- Caveats rewritten with a link to the receipt: `native/experiments/README.md`,
  `REVIEW.md`, the three experiment READMEs, `native/oracle-logic/DEMOS.md`,
  `native/docs/CAPABILITIES.md`, root `README.md`. Other limitations in those
  paragraphs (quadratic sort, no solver, no budgets on rational arithmetic) are untouched.

## Not established, still to do

- No benchmark of any crate; the SQLite comparison named in the streaming-query
  README is not done.
- No specialist-panel numbers.
- No solver (clingo) execution; the oracle-logic `--solver` mode and the two
  ignored tests remain unrun on this laptop.
- macOS only; no Linux run.
- Expectations are the authors' hand traces; no independent implementation
  (for example a plain BFS against maintained-views) cross-checks them.
- None is registered in the service or joined to `native/Cargo.toml`.
- Root: update the two project documents named above.
