# Native interpretation and rendering boundary

`src/isabelle/language/model/Veri7vn_Interpretation.thy` implements the
interpretation core for C03/C04, D20/D21 and PO-01/04. It is an executable HOL
model, not a production natural-language recognizer or proof of human intent.

The input carrier is parametric: bytes may be retained without pretending that
Isabelle characters implement a Unicode codec. Codepoint consumers need a
separate admitted decoding boundary. Half-open spans count that carrier.
`Language span replacement` explicitly permits normalized, deleted and expanded
language segments; `Literal span` always reads the original slice.
`well_mapped` requires a contiguous complete source partition and valid spans.
The source is an input to every projection, never replaced by the derived view.
`literal_never_normalized` and `valid_slice_length` state the corresponding
literal and boundary properties. The model does not yet validate an external
source-map producer, encoding codec, JSON parser or hash implementation.

A typed grammar table associates exact retained surfaces with native goals and
open conditions. `elaborate` enumerates all matching declared rules.
`elaborate_sound` establishes that emitted derivations name an actual rule,
matching surface, originating span, goal and unchanged conditions;
`elaborate_complete` retains every matching rule. Rule admission and policy
versioning belong to the registry/interpretation integration boundary.
`recognize` distinguishes no reading, one reading and multiple readings;
`ambiguity_retains_all` rules out discarding alternatives. An explicit selection
receipt preserves alternatives, choice and decision identity. It proves only
membership, never that a selected reading is the human's unexpressed intention.

The regression theory uses byte-number fixtures to distinguish two spaces from
one, retain a newline at its original JSON-relative position, preserve allele
case, distinguish title `You` from pronoun `you`, and permit mapped deletion of
a language segment. These repair the pressure observed directly in
`upstream/root/specialists/dataformats/organ_formats_v1.py:32–74` (whitespace
collapse before payload extraction) and the case-sensitive genotype extraction
in `genetics-v2/organ_genetics_v1.py:117–136`. They are input-boundary proofs,
not claims that those domain algorithms have been lifted.

The literal/grammar core has an independent `Veri7vn_Interpretation_Core` HOL
session; the renderer imports both that session and the shared authority session.

Current build command (updated for D31 and the renderer ROOT split):

```
python3 tools/dev/check-native --session Veri7vn_Interpretation_Tests \
  --session-root src/isabelle/codegen \
  --session-root src/isabelle/model \
  --session-root src/isabelle/language/model \
  --session-root src/isabelle/language/model/rendering \
  --session-root tests/language/model
```

No production consumer is integrated yet. Remaining consumers include native
registry codec/profile admission, the actual recognizer, request elaboration,
routing policy, runtime event transport, source-map producers and client display.
The finite grammar core deliberately supplies a real executable declared
fragment without claiming unrestricted natural-language coverage.

`Veri7vn_Rendering.thy` imports the operational lane's actual `claim`, `outcome`,
`subgoal` and `blocker` types; it introduces no second claim universe. Its renderer
expands each claim into mandatory identity, qualification, coverage, conditions,
dependencies and generation clauses. `read_claim` is a strict structured-display
interpreter. `claim_rendering_correspondence` reconstructs the complete claim,
including all qualifiers, from that expanded syntax. Dropping a conditions clause
is rejected; replacing a premise or modality fails exact licensing. This is a
bridge to a structured presentation vocabulary, not yet to HTML or arbitrary
natural-language text. A final emitter must preserve its interpreted semantics.
The claim target ID still depends on faithful native proposition association;
this model cannot discover an unrecorded model/source premise hidden behind an ID.

`render_parts` is explicitly historical/status display; it does not publish current
authority from old Accepted tags. Historical access still requires current
retention/access authorization; this raw helper is not a public runtime entry. It keeps goal identity, interpretation, dependency edges and each
outcome. Its correspondence theorem recovers the original outcome for every
rendered part; a failed part prevents `all_parts_accepted`. Help, questions,
acknowledgements, instructions, references, fiction and candidate deliveries have
separate structures. Their embedded assertions use the same claim renderer.
The controlled emitted act has an act template and structured assertions only.
`proposed_commentary` is untrusted draft text and is absent from that output type.
Artifact delivery is not activation/execution. The artifact record is vocabulary;
current content/lifecycle authorization and an actual artifact emitter are not yet
integrated.

Routing directly uses the authority model's `unblocked` judgment. A live
interpretation-scoped blocker prevents every fallback to that interpretation
while permitting unrelated readings. There is no second language-side discharge
algorithm; discharge metadata alone cannot remove a machine blocker.

`Veri7vn_Grammar.thy` extends the exact-table seed with typed executable parser
combinators for tokens, partial-codec captures, sequence, choice and typed
projection. Soundness composes independently stated relational grammar meanings.
The primitive capture theorem assumes only codec soundness for its returned
native value; it proves source span association and consumption bounds itself.
The specialist-language instance composes an operation keyword, quoted literal,
partial typed capture and closing delimiter. `specialist_literal_sound` links
its returned native value to the exact original absolute span, while rejecting
missing delimiters. Tests instantiate this with a two-space hash request and an
ambiguous entity/role grammar that retains two readings. This is a meaningful
declared syntax fragment; broad Oracle7 entity/quantity/follow-up grammars,
delimiter discovery and domain codecs remain unfinished consumers.

`authoritative_render` takes the current authority state and request ID. Its
assertion pool is extracted from visible bindings that pass the current shared
`binding_licensed` check, so old Accepted tags after blockers, cancellation or
revocation are insufficient. `authoritative_render_live` associates every emitted
assertion with such a currently licensed visible binding. This does not establish
the truth of source data or the native gate's target association by metadata.

TB-05 must bind these controlled templates/clauses to the actual output bytes,
including escaping and target/profile text projection. No HTML/prose emitter is
integrated here, and metadata round trips prove no fidelity property of arbitrary
prose. Proposed commentary must remain visibly untrusted/proposed and cannot be
merged into an authoritative answer by a client. A runtime consumer must also
pin/recheck the authority epoch across emission to avoid a later concurrent
revocation making a previously checked display appear current.

Registry co-review produced `src/isabelle/registry/native_literals.ML`: an opaque
immutable byte input owner and checked half-open slices with actual original
substring equality. This supplies a concrete ownership API; it is not yet a
refinement of the HOL list slice. The outstanding bridge relates SML byte strings
and checked integer offsets to `take (stop-start) (drop start original_bytes)`.
A Unicode decoder and normalized-view source-map producer need their own laws.

The execution-dependency migration preserves the actual
`NoExecution | ExecutableGeneration n` value in the mandatory generations clause;
rendering does not apply the authority model's semantic-target normalization.
Per-part status displays also carry the requested claim's clauses, so failed or
inconclusive parts retain their requested target/conditions even without acceptance.

The higher-order codec parameter is a native HOL library abstraction. A deployed
family must instantiate it with its admitted concrete codec and soundness theorem;
this is not a public runtime callback-registration interface or permission to
attach a proof name to an independently replaceable function.

The standalone `Veri7vn_Language` SML export exercises reachable code generation;
it is not a dynamic ABI bridge to a separately generated authority module.
Production must jointly export the authority/renderer/codec definitions in the
finite linked bundle so shared datatypes really are shared. That runtime consumer
and its native object/byte associations are not integrated by this lane's export.

Checked evidence, 2026-10-15: the complete `Veri7vn_Interpretation_Tests` session
passed before the D31 setup and ROOT split against the migrated authority API, with stable input hashes, native
proofs and reachable SML export. Receipt:
`var/native-scaffold/sessions/fa891a04b65e8f63/receipt.json` (ephemeral, not committed).
Native build elapsed 39 seconds; full driver 43.877 seconds. Rendering theory
reported 8.864 seconds cumulative proof/command time; final renderer fixtures
0.525 seconds. This is development-build evidence, not deployed request latency.
The original `fun read_claim` pattern declaration hit a 90-second build timeout;
its nonrecursive definition/case replacement passed without changing the claim
syntax or weakening the correspondence statement.

The checked handoff to the host is
`authoritative_render :: authority_state ⇒ nat ⇒ response_act ⇒ rendered_act option`
from theory `Veri7vn_Interpretation.Veri7vn_Rendering`. Central host aliasing in the
single generated ML datatype universe is assigned to the runtime owner and is
not established by this standalone session. Final actual-byte/profile projection,
retention/epoch enforcement, artifact emission and broad family-language consumers
remain integration work; this evidence does not close PO-01/04 or the entire
interpretation-model work package.

Production continuation (draft, not checked by the receipt above):
`Natural_Mathematics` captures original signed integer byte spans in the audited
sum/difference/product/quotient/subtract-from phrases and constructs the native
math expression directly. The 256-byte input bound is an explicit operational
limit. This is a first specialist grammar, not full coverage of the original
system's mathematical language. Its generated expression reflection feeds
`native_interpreted_request.ML`, which prepares `closed_expression_run` and
retains the parameterized `closed_expression_meaning` requirement before the
answer is known. A trusted workspace policy supplies the actual admitted family
instance and executable pin; interpretation itself grants neither truth nor
execution permission. Request, input, and family payload releases are explicit.

`HTML_Bytes` defines a bounded canonical escape/decoder pair;
`Controlled_Templates` gives fixed integer/rational sentence patterns native
mathematical meanings; `Checked_Statements` reparses a proposed fixed sentence
and requires its complete typed template view to match before escaping it. A
changed result or operation therefore cannot borrow another template's meaning.
These definitions do not establish that a displayed result was computed: the
runtime must consume the actual same-request family output association through
D34, then recheck the current binding and input retention under the host's single
coordinator at byte handoff. The current kernel descriptor emitter is a draft
consumer, not the completed ordinary-computation route.

`Natural_Source_Rows` retains the ambiguity between observed-snapshot count and
full-source total for an unqualified question. An explicit observed-row question
can bind only an existing native declaration's unchanged acquisition and query
requirements, including schema, column count, population policy and conditions.
Full-source total stays a coverage obligation. Production source-name resolution,
source request reservations and output associations remain required consumers;
no bare display name or declared materialization flag establishes world coverage.

The escape law is a byte-level canonical entity law. It does not supply a Unicode
decoder, establish browser charset policy, or justify arbitrary rich text. The
first mathematical sentence and integer captures are ASCII. Wider literal and
source-name display must validate a declared text encoding or use an explicitly
encoded artifact view before claiming a text rendering law.

Checked continuation evidence: `Veri7vn_HTML_Bytes` and
`Veri7vn_HTML_Bytes_Tests` both finished in the paired native run recorded at
`var/native-scaffold/sessions/212eacad56b067fe/receipt.json`, with stable inputs.
The parent took 17 seconds (theory 2.994 seconds); fixtures took 14 seconds
(theory 0.289 seconds). The overall paired receipt is failed because the separate
SourceImport target failed; this is positive evidence for the named HTML sessions,
not a successful whole-batch result. The NL, controlled-statement and production
request/emitter drafts are not covered by this receipt.

D34 consumer migration: historical `render_parts` also preserves each goal's
optional output slot ID alongside its immutable requested claim and outcome. A
pending parameterized requirement must not appear to be a concrete answer target.
Current authoritative assertions still come only from shared `binding_licensed`,
which owns the actual slot specialization and current dependency checks. The
renderer session ROOT now lives in `language/model/rendering`; the Core ROOT
remains independent HOL, so grammar-only builds need no authority registration.

Recipient boundary: the older kernel emitter's native target/premise XML is an
owner-oriented prototype, not a safe recipient view. In particular, a premise may
contain source observations that must stay private. Ordinary math recipient output
uses the finite managed family view and controlled sentence/literal projection;
source output uses the generated count/diagnostic summary. The host must authorize
the actual destination and condition projection before publishing either view.

The paired natural-math and controlled-template native run is checked separately:
`var/native-scaffold/sessions/728db9f3780ff908/attempts/3a8ba69a8e8e46d0a3adc04d650265bd`
records stable inputs and successful parent and fixture sessions (64 seconds
combined). This checks the closed typed reading derivation, selected-expression
link, native arithmetic template laws and checked sentence/escape fixtures. It
does not qualify Mathematics_Bundle, interpreted-request ML, the refined output
bridge or actual service publication. A subsequent diagnostic refinement reports
only failed literal captures; that small change awaits its next scoped check.

The fixed display bridge is now a separate admission consumer. Its closed
`fixed_math_display_contract` retains selected grammar derivations, original
integer capture semantics, generated whole-expression construction, saved result
view roundtrip and exact rational semantics, plus the conditional whole-sentence
and escaping law. The execution-view clause also connects the actual generated
`closed_expression_run` through its view decoder to the native outcome meaning.
Admitting this universal contract alone does not discharge its premises for a
particular output.

The opaque native bridge attaches to one actual math instance and its native
semantic generation, the math execution pin and the exact central statement
checker pin/code context. `prepare bridge request output` checks the same live
instance and same-request output. At candidate projection it resolves the original
owned slices, compares the generated captured whole AST with the selected AST,
and reconstructs the immutable input and outcome predicate for exact native term
comparison. It consumes the saved family view and checks the complete sentence
against the original operation/captures and actual numerator/denominator. A fresh
instance with equal fields, a swapped checker pin, or a released bridge cannot
supply this association.

The workspace owner retains distinct bridge and statement-code identities;
output evidence and managed retention carry that pair. Protected reconstruction
must recheck the fixed native contract and executable associations before reusing
the saved pair. There is no caller-selected renderer, theorem, or truth flag.
The root owns the corresponding decision entry. These new bridge consumers and
its strengthened theorem await native and service composition checks; the earlier
NL/template receipt does not cover them. Request lease/canonical input migration
is owned by assembly during the shared D40 migration, including the single final
owner for math-instance teardown.

The source relation language child now proposes the existing
`SnapshotRelationQuery` from exact whole-question byte patterns and versioned
label/reader declarations. `who wrote TITLE?` comes from
`upstream/root/wander-train/relation_readers_v1.py` P50 forward patterns; the
retained v1 fixture binds Pride and Prejudice to Q170583. The declared generic
property fragment preserves multiple property bindings as multiple readings.
Titles and offsets remain original UTF-8 octets; there is no implicit case fold
or guessed alias resolver. Authored ambiguity and café fixtures are regression
data, not claims about an unavailable v2 alias corpus.

Utterance and declaration have distinct logical roles/occurrences with their own
association. Their physical input identity may be shared under D40; inequality of
bytes or physical input handles is not a semantic prerequisite. The initial
fixture uses separate owned inputs. Actual protected declaration/query ownership
and association with the SAME K/RI recipe remain host consumers.

`answer_relation_question_sound` retains the shared relation result and proves
`structured_relation_snapshot_meaning` with the explicit
`DeclaredFiniteSnapshotOnly` response qualifier. Duplicate equal witnesses use
the shared distinct-value semantics; absent property is finite-snapshot absence,
and incomplete/schema-rejected results cannot become a negative world answer.
This child is source-ready, awaiting its native session and actual K/RI consumer
checks; no service registration or unrestricted natural-language parity is claimed.
