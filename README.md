# veri7vn

A native Isabelle environment for engineering, reasoning about, and deploying
Oracle7-style specialists. The intended product supports authoring, interpretation,
debugging, composition, proof search, synthesis, refinement, and continued growth
on the end-user machine.

**Current status: native implementation underway.** Foundation and
[architecture revision 2](docs/ARCHITECTURE_PROPOSAL.md) are agreed; the first scoped
implementation lanes are active. The platform and
comprehensive metatheory are not yet implemented. The superseded Python
expression/DAG/C prototype has been removed;
the [cleanup record](docs/design/prototype-cleanup.md) identifies its recoverable
Git history. Native feasibility probes and upstream audit tools are retained.

## Start here

- [Project plan and completion criteria](project/PLAN.md)
- [Work board](project/BOARD.md), generated from [tasks.json](project/tasks.json)
- [Design decisions](project/DECISIONS.md)
- [Mandatory proof obligations](project/PROOF_OBLIGATIONS.md)
- [Preimplementation omissions audit](docs/review/PREIMPLEMENTATION.md)
- [Architecture synthesis](docs/ARCHITECTURE_PROPOSAL.md)
- [Interface contracts](docs/contracts/README.md)
- [Product acceptance](docs/product/ACCEPTANCE.md) and [coverage](docs/coverage/README.md)
- [Working agreement for agents](AGENTS.md)
- [Foundation validation](project/VALIDATION.md)

The task ledger is the source of status and dependencies. From the repository root:

```sh
python3 tools/project.py check
python3 tools/project.py ready
python3 tools/project.py board > project/BOARD.md
```

[Native development checks](tools/dev/README.md) and
[package-schema checks](schemas/README.md) are the current scaffold entrypoints.
See the validation record for the exact commands exercised on the current checkout.

## Repository map

| Path | Role |
|---|---|
| `project/` | Work graph, decisions, integration criteria, validation |
| `docs/contracts/`, `schemas/` | Shared semantic boundaries and structural package validation |
| `docs/product/`, `docs/coverage/`, `audit/coverage/` | Authoring requirements, recovered capability coverage, evidence gaps |
| `src/isabelle/`, `tools/dev/`, `tests/scaffold/` | New native platform scaffold and scoped checks |
| `docs/research/`, `experiments/` | Research reports and isolated feasibility experiments |
| `audit/results/`, `tools/probe_*`, `tools/inventory.py` | Upstream audit evidence and reproduction tools |
| `upstream/` | Ignored checkout of the downloaded Oracle7 release |
| `var/`, `.venv/` | Ignored local artifacts and development dependencies |

Oracle7's pinned release is `c5d6a29d5bc5e2525078e5a53afa1abf659e4d69`.
Some advertised relation/name dependencies were absent from the inspected
distribution. Source data is not installed as unconditional HOL truth. Corpus
provenance, coverage, licensing, and dependency closure are part of the work.

No production service is installed by this scaffold. Prebuilt native deployment,
continued authoring, and serious deployed search are project requirements.
