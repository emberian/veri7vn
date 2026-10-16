# Conservative headless runtime candidate

`tools/deploy/runtime_closure.py` builds the opt-in `isabelle2026-rc1-headless/1` inventory for the existing deployment builder. It preserves the input distribution and previous generations. Qualification of the assembled candidate remains required.

The profile pins upstream `etc/components` SHA256 `799e5102dd54db71f68efa39efb1897307bf24183f81deb5e473da65c5f98ee7`; changed catalogues or unknown top-level entries reject. It retains sources, ROOT/ROOTS, heaps/build databases, Java/Scala, PolyML, Isabelle/jEdit libraries and all supplied ATP/SMT/SAT/model-finding tools. A smaller file count alone proves neither dependency closure nor faster startup.

## Optional capability and dependency mapping

| Excluded payload | Capability unavailable in this profile |
|---|---|
| VSCodium 1.105.17075 and vscode_extension 20260918 | Upstream Electron/Node desktop and VSCode extension |
| Stack 2.15.7 | External Haskell/GHC setup/export |
| MLton 20241230-1 | External MLton export compiler |
| OPAM 2.0.7 | OCaml package management/setup |
| Elm 0.19.1 | Rebuilding Find Facts web assets |
| Naproche 20260903 | Separate controlled-language prover and settings subprocess |
| Find Facts `lib/isabelle.db` | Precomputed upstream search index; veri7vn proof search remains included |
| `lib/browser_info.db`, `browser_info/**` | Precomputed upstream HTML library browsing |

Notices inside omitted components remain inventoried at their original paths. Internal links retain exact text; escaping links or links into existing omitted payloads reject. Pre-existing dangling internal links are listed explicitly. No automatic download fills omissions. D19 governs redistribution.

## API, inspection and validation

```sh
python3 tools/deploy/runtime_closure.py ISABELLE_RESOURCES NEW_OUTPUT_DIRECTORY
python3 -m unittest discover -s tests/deployment/runtime_closure -v
```

`runtime_artifacts(home, generated_dir)` returns artifacts/report; output must be fresh and outside the input. Generated `runtime/etc/components`, original `deployment/upstream-components` and `deployment/runtime-closure.json` pin catalogue changes, exclusions, links and byte counts. Normal full launch verification remains mandatory.

Seven fixture tests pass. Read-only RC1 inventory selected 19,845 entries / 1,382,939,742 regular-file bytes, omitted 5,011 entries / 1,095,882,619 lstat bytes, and preserved twelve known dangling links. These are inventory sizes, not allocated disk or timing measurements.

Before adoption, stage an independent candidate and check source UI, native startup/build/admission, intended solvers/search, nonempty restart and corruption refusal. Compare identical workloads against the full distribution, separating verification, readiness and request costs.
