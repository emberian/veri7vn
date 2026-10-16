# A specialist workshop in the installed source workbench

The environment we are building connects a specialist's editable source, meanings,
language, examples, assumptions and evidence to useful deployed behavior. This
workshop starts at that editable source. You will inspect a real candidate's
specification, make a durable revision, and find the remaining obligations before
it can become an ordinary callable capability.

The installed source workbench currently supports import, inspection and editing.
It does not admit or execute your edited native specialist. The newer combined
native build/admission package is being integrated. This workshop will extend
through that route once it exists; importing source is only its first segment.

## Open the installed workbench

Use the local macOS ARM64 installation supplied by the deployment owner. The
qualified standalone generation is
`2fd159a898d0b7648dfce893f35a9a61f7ac0df05f7fa25314a29e001750cf45`, locally at
`var/deployment-ui-d44-standalone-aae0d7dd`. Its shipped `bin/veri7vn` starts the
packaged application from outside the source checkout without system Python or a
source compiler. Use a fresh private source workspace for this exercise.
Redistribution remains unresolved and Linux execution is untested.

The workshop installation includes exact manifest-pinned source examples. Ask the
installation to locate them; do not guess a path inside its generation directories.
`locate` verifies the selected package and its inventoried tutorial closure. An
older source installation without workshop assets reports that the tutorial is
unavailable; use the workshop installation supplied by the deployment owner.

Set paths to that installation and a new private state
directory. The launch command uses the installed JAR and staged Java dependencies;
it does not compile the source client.

```sh
export V7_INSTALL=/absolute/path/to/deployment-ui-d44-standalone-aae0d7dd
V7_COMMAND="$V7_INSTALL/current/bin/veri7vn"
export V7_STATE=/absolute/private/my-specialist-workshop
"$V7_COMMAND" verify
V7_IDENTITY=$("$V7_COMMAND" locate --tutorial retained-identity)
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- list
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- import-native identity "$V7_IDENTITY" workshop-identity-import-1
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- inspect identity
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- serve
```

Use physical paths for imports; ancestors containing symlinks are rejected. Open
the loopback URL printed by `serve`. Keep the terminal open. One process owns the
workspace, so close this browser server with Enter before using a separate CLI
command on the same state.

## Revise a meaningful candidate

Inspect `identity` and read `OBLIGATIONS.md`, `samples.native` and
`Retained_Identity.thy`. The candidate is `Parameter 0`: it should return its input.
Its supplied observations are zero→zero and one→one. A constant-zero candidate
passes the first case and fails the second; neither example proves the universal
identity claim. The package deliberately has no callable exports.

Open `Retained_Identity.thy` and add an explanatory comment, keeping the actual
proposal and expert proof blocks intact. Save. Add a second comment and Save again.
The editor should continue from your newly committed revision. If it reports a
conflict, retain your proposed text, reopen the current source and reconcile it.

Close the server with Enter, then inspect the retained revision and source:

```sh
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- inspect identity
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- source identity Retained_Identity.thy
```

Check your comments survived. The new source revision and edit token locate this
exact version. They do not establish its theorem, empirical qualification or
activation. This candidate uses existing mathematical operations; native growth
should reuse the current executable bundle. Adding a new carrier, kernel or code
setup needs a separately qualified bundle.

For a second review exercise, locate `branch-review` with the same command and
import that directory under a distinct draft name. Open `Branch_Review.thy`: its
implementation returns `abs x`, while the proposed equality `branch_result x = x`
fails at `x = -1`.
Use the source-change review controls to compare a domain restriction with a
changed specification. Inspect the proposed text before Apply; source review
neither proves the changed statement nor adopts its assumptions.

For an existing specialist with real historical behavior, continue with the
[original paint import](first-specialist.md). Its recognized formula is a proposal;
inspect the rounding, unit, parser, zero-rate and source qualification obligations
before attempting a native lift. Original Python remains unresolved executable
source. A missing native `package.json` on an original import means the native
package description still needs authoring; retained source remains inspectable.

## Evidence and next join

The shipped launcher passed source import/reopen, a native licensed sum and a
fresh-process restored result outside the checkout. The bundled identity workshop
also passed import, exact-source Open, two Saves with successive revisions, normal
close and fresh-CLI exact source readback through that launcher. These are automated
developer rehearsals; visual and independent recipient usability remain untested.
See the [standalone evidence](../../tests/deployment/evidence/standalone-aae0d7dd.json)
and [rehearsal record](../handoff/recipient-rehearsal.md).

Next, the real native Build operation must capture this source revision, show a
useful proof/source diagnostic, retain its candidate across restart, and expose
admission separately from qualification and activation. Profiling, refinement and
package transfer then complete the workshop. None has been replaced with a manual
implementer-only theory load or a simulated successful control.

## Continue the lab: behavior, examples and conditions

Keep the imported `identity` revision as your baseline. Before editing its meaning,
write down what a proposed change should do at zero, one and minus one. Identity
returns each input; constant zero agrees at zero only; absolute value agrees at
zero and one but differs at minus one. This is why a passing example is useful
feedback without being the universal specification.

Use the bundled branch-review package as a separate draft for this comparison:

```sh
V7_BRANCH=$("$V7_COMMAND" locate --tutorial branch-review)
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- import-native branch-review "$V7_BRANCH" workshop-branch-import-1
```

In `Branch_Review.thy`, `branch_result x` is defined as `abs x`; the proved
nonnegativity lemma and the commented proposed equality `branch_result x = x`
are different statements. At minus one the definition returns one. Two coherent
repairs have different consequences: retain absolute value and restrict the
proposed equality to nonnegative input, or retain the all-integer identity goal
and change the implementation to return `x`. Decide which behavior you want
before changing the theory. A restriction changes which inputs your claim covers;
an implementation change affects existing users.

Expand **Review a source change** and use **Preview source change** to inspect the
proposed text. Check the displayed revision and the actual statement you intend to
change before **Apply reviewed change**. **Cancel reviewed change** discards the
proposal. These controls review source edits; they do not run a prover or discover
a counterexample. Do not convert the commented universal proposal into a claim
of a proved theorem. Native proof checking of this edited revision remains pending
the build join below.

Now compare that decision with the original paint specialist. Its native formula
proposal multiplies width, height and coats, then divides by spread rate. Inspect
the retained original source and migration report together. A zero spread rate
needs a scoped undefined/domain result. Positive dimension guards, foot conversion,
default rate and rounding need explicit choices. Changing an example to agree with
a new formula does not establish that the original behavior was preserved; record
whether you repaired behavior or changed its intended meaning. Historical panel
values remain attributed original examples, rather than new private holdouts.

The existing source surfaces let you retain those decisions and edit canonical
files. They do not yet offer controls that automatically rebuild this paint
proposal into an admitted family operation, run its historical panel natively or
show source-family query coverage. Continue inspecting installed mathematics
through the [operation reference](../reference/recipient-operations.md), using a
separate workspace and its actual matching resident package. Its licensed result,
selected reading, conditions and available owner inspection describe that request;
they do not certify your edited paint or branch-review package.

The next concrete backend join is the real D43 native construction service through
the D44 resident host: capture the managed draft's exact revision and source lease,
select its theory and retained parents, run the protected native producer, map
proof diagnostics to that captured source, and retain the actual candidate across
restart. The client must then expose selected theorem admission separately from
build success, qualification and active publication. Until that join is connected,
the lab ends with a reviewable durable revision and explicit obligations. The
subsequent lab steps must exercise that actual build/repair/admission route before
profiling, refinement and transferable deployment can be claimed.
