# Conservative headless runtime candidate

`tools/deploy/runtime_closure.py` supplies the explicit
`isabelle2026-rc1-headless/1` profile to the existing deployment manifest builder.
It constructs new artifacts; it never edits the installed distribution, a prior
package, a heap, a producer archive or a cache. Root approved this profile's optional
backend separation. This is a candidate closure requiring actual installed checks,
not a declaration of complete recipient acceptance.

The reviewed upstream `etc/components` SHA256 is
`799e5102dd54db71f68efa39efb1897307bf24183f81deb5e473da65c5f98ee7`.
A changed catalogue or unknown top-level distribution entry rejects rather than
silently extending the profile. Every file under the reviewed top-level roots is
included except the exact exclusions below. The inventory lists every excluded
path and reason. This deliberately conservative rule retains all `src`, session
ROOT/ROOTS, heaps and databases, scripts, Isabelle jars, source UI assets, notices,
Java and Scala distributions, Poly/ML and native libraries. It retains all ATP/SMT,
SAT and model-finding tools, including E, Vampire, SPASS, cvc5, veriT, Z3,
zipperposition, Kodkodi, Minisat, Nunchaku and SMBC. Isabelle/jEdit and its jars stay:
headless Scala classes can reference GUI types, and removing their jars needs a
separate dependency investigation. Scala.js libraries and compiler jars also stay.

The generated `runtime/etc/components` retains upstream order and removes exactly
seven optional component registrations. Its own SHA256 and ordinary artifact entry
pin the change. `deployment/upstream-components` preserves the original catalogue;
`deployment/runtime-closure.json` records both digests, retained registrations,
capability availability, omitted paths, selected byte counts and original dangling
links. No producer/source/heap identity is rewritten. The normal package builder
still checks saved bundled source bytes against each captured heap database, so a
captured dependency on an omitted file must reject rather than acquire a false
source identity. The ordinary staging manifest, per-file hashes, link verification,
mode verification and full launch verification remain in force.

## Optional capability and dependency mapping

These capabilities remain project possibilities but are unavailable in this
profile. No automatic installation or network fallback is added.

| Exact exclusion | Unavailable capability and upstream consumers |
|---|---|
| `contrib/vscodium-1.105.17075` | Upstream VSCode desktop, Electron and embedded Node. `lib/Tools/electron`, `lib/Tools/node` and `src/Tools/VSCode/src/vscode_main.scala` check `ISABELLE_VSCODIUM_ELECTRON`; missing-component errors remain explicit. The veri7vn source web UI uses its packaged host assets, not this desktop. |
| `contrib/vscode_extension-20260918` | Upstream VSCode extension installation (`vscode_main.scala` uses `ISABELLE_VSCODE_VSIX`). |
| `contrib/stack-2.15.7` | External Haskell/GHC setup and code-export compiler. `lib/scripts/getfunctions` reports unknown `ISABELLE_STACK`; `lib/Tools/ghc_setup` uses that wrapper. This does not remove Isabelle's native Poly/ML or Scala build paths. |
| `contrib/mlton-20241230-1` | External MLton code-export compiler selected by `ISABELLE_MLTON`; code generator/export theories remain present. |
| `contrib/opam-2.0.7` | External OCaml package management; `lib/scripts/getfunctions` reports unknown `ISABELLE_OPAM`; OCaml setup/export remains unavailable. |
| `contrib/elm-0.19.1` | Building Find Facts web development assets; `src/Tools/Find_Facts/src/elm.scala` requires `ISABELLE_ELM_HOME`. Existing Find Facts web assets and Solr jars remain. |
| `contrib/naproche-20260903` | Separate Naproche controlled-language prover. Its settings register its own jar and execute its executable during every settings initialization. Removing its registration also avoids this unrelated startup subprocess. |
| `src/Tools/Find_Facts/lib/isabelle.db` | Precomputed upstream Find Facts index. Its retained `etc/settings` explicitly sets `FIND_FACTS_INDEXES` empty when absent. This does not exclude veri7vn native proof search. |
| `lib/browser_info.db`, `browser_info/**` | Precomputed upstream HTML library browsing. `src/Pure/Build/browser_info.scala` and `src/Pure/General/http.scala` use the default database. The upstream HTTP browser-info service cannot serve omitted entries; source viewing and native build/admission must be checked separately. Browser-info generation code remains. |

COPYRIGHT, COPYING, LICENSE, NOTICE and README-prefixed files inside optional
components are retained at their original paths, including nested notices. D19
redistribution review remains open. Ordinary internal symlinks retain their exact
link text. Existing upstream dangling internal source links are preserved and
listed; an external link or a link to an existing omitted target rejects. No
upstream dangling link is presented as a working runtime dependency.

## API, inspection and validation

`runtime_artifacts(home, generated_dir)` returns `(artifacts, report)` using the
existing `stage.py` artifact schema. The generated directory must be fresh,
caller-owned and outside the input distribution. The CLI writes an artifact list
without installing or executing Isabelle:

```
python3 tools/deploy/runtime_closure.py ISABELLE_RESOURCES NEW_OUTPUT_DIRECTORY
python3 -m unittest discover -s tests/deployment/runtime_closure -v
```

The seven fixture checks cover selected-byte identity and source immutability,
optional notices, generated catalogue identity, changed upstream catalogue,
unknown roots, malformed catalogue entries, escaping links and links into omitted
payloads. The actual read-only RC1 inventory succeeded at
`var/runtime-closure-headless-inspection-02`: 19,845 selected runtime entries,
1,382,939,742 regular-file bytes, and 5,011 omitted entries whose lstat sizes total
1,095,882,619 bytes; twelve upstream dangling internal links were preserved.
These are file-inventory counts, not installed allocated disk usage, elapsed
startup time or a comparison with a different historical runtime generation.

Deployment must assemble a new opt-in candidate around the same exact host,
producer snapshots, captured heaps and source UI before the steward executes it.
Qualification must cover source UI/native startup, source build/admission,
proof-search and intended tools, nonempty restart and negative integrity checks.
Performance compares identical workloads and conditions, separating full manifest
verification from exec-to-ready and request costs. The unchanged full-runtime
candidate remains available as the control. No timing improvement is claimed from
this inventory or from deleting files.
