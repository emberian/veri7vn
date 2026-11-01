# G Materials — joint feasibility of exact mesh counts

Final live source and canonical native are frozen for root integration/capture.
The replacement is `259636f08d2971dd44d88e988e6110ba6993cea9ec884ada2d1bc653ce7e9e6b`. It corrects the held `094799ad` candidate;
the old source, binary, reports and counterexample evidence remain preserved.

## What changed and what is proved

Exact count/genus parsing and the corrected F scaling operations remain. One
shared mesh guard now validates the whole implied Euler/incidence tuple for
vertex, edge and face requests. Asking only for edges can no longer bypass a
negative or zero implied vertex count. Four faces and genus 100 are refused;
four faces and genus zero still give four vertices and six edges.

The three binding statements `mesh_vertices_discrete`, `mesh_edges_discrete`
and `mesh_faces_discrete` establish the named result kind, positive integral
counts and nonnegative integral genus, with `2E=3F` and `V-E+F=2-2g`. The edge
statement explicitly includes positive integral implied vertices and Euler's
equation. Existing inverse/count laws remain connected to the same kernel.
The new inverse helper rewrites faces back to vertices; no premise was weakened.

These are algebraic count conditions, not a geometric existence theorem. The
model allows general triangular cell gluings and does not certify a simple
triangulation or embedding. The reader requires closed/watertight and triangular,
facet or STL context, preserves exact signed/scientific/fractional numerals,
and checks unique source/target roles. Multiple supplied counts and unsupported
topologies are withheld. English recognition and rendering remain untrusted.

## Final measurements

Both isolated specialist and whole-family modes give:

| Set | Right | Wrong | False yes | Valid withheld |
| --- | ---: | ---: | ---: | ---: |
| Shipped mapped panels | 439/440 | 0 | 0 | 1 |
| Fresh seed 20280518 | 455/456 | 0 | 0 | 1 |
| Untouched seed 20280619 | 441/442 | 0 | 0 | 1 |
| 161 authored probes | 152/161 | 0 | 0 | 9 |

The held `094799ad` on these same 161 probes gives 150 right, zero wrong,
two false yes and nine valid withheld. The two false accepts are edge requests
whose implied vertex count is negative or zero. All nine separate refusal-policy
assertions pass; valid unsupported requests still count as withheld-valid.

The ordinary current CLI passes **22/22**, using the live capability loader and
canonical binary: both impossible joint-count cases, feasible tetrahedron and
torus controls, plus existing mesh and scaling cases. Refusals are decisive.
The official scoped harness gives **346/347**, zero wrong and zero false yes.
Its verdict remains INCOMPLETE because full-head six-criteria tests were not run.
Water-r3 has no independent panel; its inherited 93 rows appear in mapped counts.

The one deliberate scorer disagreement is the generic genus-one watertight
mesh with 600 faces: triangular faces are not supplied, so 300 vertices cannot
be inferred. A toroidal 20×15 triangulated grid has F600/V300/E900, while a
20×30 quadrilateral grid has F600/V600/E1200. Both satisfy Euler zero. The
implementation withholds; the scorer is unchanged. Fresh generator templates
have the same ambiguous case and are not independent language design.

MacOS cold starts (ms): 142.11, 4.32, 3.76, 4.07, 4.20;
median **4.20 ms**, first launch retained. No Linux delivery claim is made.

## Exact handoff

Proof: `var/materials/remote-attempts/20261018T102745Z-f01e7e53440c/receipt.json` — **84 roots, zero oracles, exit 0**.
Export SHA256: `234b2131f3d4b3a261de42443d872fdab6895c16bd5c3fe65e3d630fdeb567ed`.
Native manifest: `var/materials/native-attempts/20261018T104005Z-026703f3bf16/compile-inputs.json`. The main shared helper verified current proof
closure, captured actual inputs, and published the canonical executable and
manifest. Both family build scripts retain mode 100755.

Exact eight changed source paths and hashes are in `var/G-materials/ready.json`,
with ordinary frozen copies in `var/G-materials/joint-final-source`:
Materials.thy, Materials_Export.thy, recognizer.sml, main.sml, capabilities.json,
probes.json, score.py and README.md under `src/extract/materials/`. The report
itself is `project/lanes/G-materials.md`.

Evidence: `joint-shipped.json`, `joint-fresh.json`, `joint-untouched.json`,
`joint-summary.json`, `joint-consumer.json`, `joint-parity/` and
`before-0947-joint.json` under `var/G-materials/`. Earlier proof failures were
local algebra tactic errors and one stale self-test refusal reason: fractional
vertices now imply odd faces and hit that shared guard first. The final marker
covers the corrected expectation and the root counterexample. No further work
is being launched under the drain instruction.
