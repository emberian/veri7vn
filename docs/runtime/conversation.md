# Retained conversation consumer

A conversation is the existing native authority's `session_view` and its current
observation. `ConversationClient` holds no transcript database, accepted-answer
cache, or execution replay queue. Creation, adoption, expiry, and Forget use the
workspace's single durable authority writer.

The consumer files are under `src/runtime/conversation/`. The native metadata,
wire helpers, source ownership and closed native consumer are implemented there;
the original-parent session pin, resident
commands, durable host facade, and installed workbench integration are still
being connected by their shared owners. The presence of this codec is not a
claim that an installed conversation or restart path has passed.

`Conversation_Metadata.thy` defines an initial explicitly timeless
observation, exact current-context lookup, original request-pin matcher, guarded
utterance recording, final adoption proposal, historical quotation guard, and
checkpoint consistency checks. Its ML wire producer is a bounded projection; it
cannot mint an accepted witness or alter authority.

## Original session pin and adoption

Create allocates the session ID from the existing durable allocator and commits
one `UpdateObservation` through the existing writer. There is no artificial native
payload for the numeric session ID. Initial mathematics
turns explicitly have no clock dependence or source reads. A later context retains
its actual complete clock and read fields; its source/version pairs cannot be
silently replaced by the machine's present wall clock.

The newly captured utterance input is a distinct `SessionLocal sid` source owner,
with session/read dependencies, its actual native source-context closure, and
`RequireAccess` for the captured observation.
The parameter and retained output copy that same access requirement when reading
the input/parameter. This preserves access across conversational CAS advances while
still checking the original read/clock conditions. Generic shared raw inputs retain
their existing ownership; the same physical input is never registered a second
time under conflicting session ownership.

Before constructing a semantic parent, the native owner captures an opaque pin
from `conversation_context`. The parent and its protected recovery association
carry that exact context. The caller's `(session, expected revision)` is only a
lookup/CAS request. It cannot construct a session or accepted context. Every child
and the native requirement retain the session and read dependencies from original
construction. Patching a stateless reservation afterwards is insufficient.
The fresh-event adapters require that the native request, claim, slot, parameter
and output already carry the complete source closure. Missing dependencies refuse
adaptation. They set the original session observation and copy its access
requirement before the first persistence; they do not invent claim dependencies.

The early `Veri7vn_Original_Session_Source` module supplies the static source type
needed below Scope and interpreted requests. Its private Roots issuer captures
the actual input, source owner, observation pin and native development from an
independently retained source Entry. It derives the complete dependencies itself.
Scope owns a counted capsule view from original parent construction, so releasing
the producer cannot remove the context needed by a child. Its only callback
releases that retained Entry; no callback supplies data, permissions or an Owner
query. Final cleanup runs outside the capsule monitor, records failed tasks for
retry and never resurrects a released view. The lower session and its source
lifetime fixture still require designated native qualification.

Utterance recording does not adopt an answer. The native finalizer waits until all
children have terminal outcomes, selects accepted parts by exhaustive native typed
output cases, derives that request's actual matching licensed bindings, and submits
`StageAdoption` only for a nonempty accepted set. For mathematics, only `Exact`
enters that set; `Undefined`, missing parameters, syntax and budget outcomes remain
recorded nonaccepted parts. The helper rejects invented or repeated bindings and repeated
adoption of that request. The generated reducer rechecks the session observation,
same-request binding identities, current license and expected revision. Only the
durable acknowledgement installs the adoption and advances the session revision.
Artifact delivery is retained as its distinct per-child outcome.

Adoption makes the old request's exact observation CAS stale. History therefore
uses the separate `conversation_quotable` gate: actual adopted membership, retained
visible binding, accessible native evidence and managed dependencies, all retained
managed access requirements, the original
request/goal association, and current session access. The resident additionally
requires the exact live/reconstructed native display witness. Quotation preserves
the original observation and complete claim, including premises, source dependencies,
modality, coverage, assurance route and actual executable provenance. It is labeled
historical and supplies no current execution or assertion authority.

## Closed resident protocol

These operation names and shapes are the intended fixed resident bridge; shared
installation and composed qualification remain required.

| Operation | Request payload/artifacts | Reply |
| --- | --- | --- |
| `conversation_create` | empty; no artifacts | `conversation_queued`, `token,sid`; no artifacts |
| `conversation_list` | empty; no artifacts | `conversation_list`, `1`; one bounded YXML frame |
| `conversation_open` | positive session ID; no artifacts | `conversation_view`, same ID; one bounded YXML frame |
| `propose_conversation_math` | `sid,expected_revision,selection`; original bytes artifact | `proposed`, request ID; no artifacts |
| `conversation_expire` | positive session ID; no artifacts | `lifecycle_queued`, exact token; no artifacts |
| existing `forget` | positive session ID; no artifacts | existing durable lifecycle receipt |

An empty selection field asks the installed reader to choose its unambiguous
reading; a nonempty field is an index from 0 through 255. Original input is at most
256 bytes. Creation and expiry wait on the existing exact-token durable receipt
watcher before returning success. Opening or listing never proposes a request,
reruns a question, starts a worker, or advances a session observation.

The YXML schema is version 1, at most 262144 UTF-8 bytes. The index root is
`veri7vn-conversations(version,complete)`, containing at most 128
`conversation(id,revision,status,utterances,adopted)` summaries. `complete=false`
means this is a bounded prefix, not an exhaustive inventory.

A view root is `veri7vn-conversation(version,id,revision,status,complete)`. An
active view starts with `observation(session,version)`, followed by at most 128
turns. Each observation contains `clock-unused` or
`clock(kind,origin_hex,ticks)`, then `reads` containing exact
`read(object,version)` pairs. Clock kinds are `wall`, `monotonic`, and
`source_event`; ticks are canonical signed decimal. Clock origin is hex-encoded
original bytes. There is no implicitly sampled clock.

Each `turn(request,utterance)` contains `input(encoding=hex,source_encoding)` with original bytes,
that original parent's `observation`, and one to 64 `part(goal,slot,status)` children.
Nonaccepted turns retain their original observation too. Total parts are bounded at 1024.
The source encoding is preserved exactly as `UTF-8`, `binary`, or `native-term/1`;
hex is only transport encoding. Binary/native-term bytes are never implicitly
decoded as conversation text. The current mathematics ingress captures UTF-8.
Part statuses are `pending`, `historical`, `declined`, `inconclusive`, `failed`,
`cancelled`, `unavailable`, and `artifact`. Only `historical` contains a
`quotation`. Every part begins with `predecessors`, containing the original native
`dependency(kind,goal)` edges, whose kind is `logical` or `artifact`. A scalar part
has an empty predecessor list. Original part identities and ordering survive scoped
denial as unavailable placeholders, so subsequent edges keep their actual meaning.
A bounded display is an explicitly incomplete topological prefix: every displayed
dependency has its earlier identity placeholder. Unadopted pending/refused work
cannot carry a historical answer.

The quotation attributes are `claim,target,interpretation,evidence,
semantic_generation,executable_generation,route,kind,modality,collection,optimality`.
Its children are mandatory `premises`, `dependencies`, original `observation`, and
`answer`. The quotation observation must equal its turn's original observation.
Reference lists use `ref(id)`. Executable generation is `none` or a
positive ID. Collection scope is `scalar`, `complete`, or `prefix:N`; optimality is
`unspecified`, `feasible`, `optimal`, or `impossible`. These fields describe the
actual native claim; none are acceptance credentials. The answer contains only
the native gate's fixed HTML rendering and is bounded at 32768 bytes.

Expired/unavailable views contain no observation or turn payload. Native expiry
uses existing `Revoke sid`; it denies further invocation/quotation while retaining
the defined non-content history. Forget uses the managed dependency closure,
removes the session view and observation, denies dependent native associations,
and releases their managed payloads through the existing cleanup barrier. The
client stores no private copy to revive on reopen. The workbench must discard its
displayed view and pending selections after either operation.

## Native integration seam

`native_conversation_consumer.ML` contains a fixed private Roots functor over pure
Frame builders, the actual source Entry and context owner, followed by a fixed
Frontdoor functor over the same Roots and actual Owner queries. Roots is
instantiated before the Owner so its opaque event type can enter the closed gate
sum. The Frontdoor is instantiated after that same Owner. Its generative private
construction capability stays inside the sealed service. It builds a full original input, its
independent native context, the owner-minted observation pin, one Scope parent
and child, and the interpreted request. The first profile is a single whole-input
mathematics turn. It does not treat an arbitrary source slice as complete
question decomposition. The original producer child and parent views are released
after the interpreted request has retained its own child view.

Its opaque Create, Source, Record, Adopt and Expire descriptors enter the existing
service gate sum. Intrinsic gate liveness never queries the Owner while the Owner
holds its acknowledgement monitor. The Frontdoor first reads the complete current
observation. During staging the Owner independently matches the descriptor's
canonical original observation against its exact current observation and access;
the existing candidate version CAS then rejects an intervening authority transition. The actual-Owner regression must change the
same session observation between staging and acknowledgement, reject the old
candidate, and exercise an intrinsic-only Gate.live path. Source material is exported from the same descriptor-owned Entry
and durably registered before reservation; the later mathematics input step must
preserve that SessionLocal row. Record follows actual reservation. Only
acknowledgement of the same Source descriptor transfers an independent physical
root into the source owner. Adoption takes the actual prepared turn and native
Exact tokens; the Frame derives the currently licensed bindings itself. No raw
binding list is an adoption credential.

The parent owns scheduling and actual request entries. It releases prepared and
event views after their existing cancellation/cleanup barriers, forwards generated
dependency invalidation to the source owner, and installs restored source owners
only from the fixed checked witness after atomic native identity registration.
The consumer's source lookup checks the generated recorded/current-access predicate
before returning original bytes. Its physical root table contains no session
versions, answer statuses or accepted binding authority.

The leaf remains unreferenced until the shared Scope, Frame/Owner and resident
hooks join it. In particular, restored Scope pins still require authenticated
original parent/plan/source correspondence; source restoration cannot infer it.

## Independent source restoration (D65)

A recorded utterance has its own governed source lease. Releasing every child
request does not remove its original bytes. The source owner keeps the real native
input identity and original observation; it creates neither a session nor an
accepted answer. The generated session view and exact SessionLocal retained row
remain the authority for reading it.

The distinct required-session-input inventory includes both durably registered
pending sources and recorded utterances. Its source requirements contain no
invented semantic generation. The fixed `native-session-input/1` material carries
the actual positive native context head, complete original source/context
closure, bounded physical input bytes with their exact encoding, and original
observation. The existing recovery ledger stores it; there is no second
conversation database. Graph code sources retain their strict UTF-8 contract;
original binary input is carried separately.

Recovery checks the committed role, hashes, image, executable pin, exact retained
row and actual reconstructed native context before acquiring source ownership
through the common pool. Registration of the graph and input identities is atomic.
Only the fixed checked witness can create a restored source owner; restoration
cannot mint a current observation pin, record the source, dispatch work or adopt
an answer. A pending source stays absent from transcript projection. Recorded
membership, matching session identity and current access are checked separately
at use. Forget of the session, physical input or native context removes its
requirement and prevents restoration.

The session Scope restart join must compare its authenticated original-source
requirement against the restored Entry's entire native dependency closure, original
observation, physical identity, encoding and bytes before constructing the original
source capsule. The Scope requirement comes from its own protected checkpoint;
matching an input ID against an independently older source checkpoint is
insufficient. The recreated pin and capsule preserve original attribution only.

These source files are still awaiting native integration and designated checks.
The completion gate includes no-child source survival, pending-registration crash
recovery, and context-Forget denial as actual consumers, in addition to the
resident restart and lifecycle trial below.

The native CAS fixture assembles the actual Roots, Frontdoor and Owner locally.
It stages a real source descriptor, advances the same session's clock at the same
session version, and requires both the old acknowledgement and restaging to fail.
Physical source liveness remains independent from current authority. A fresh
request under the changed observation can register its source, which stays absent
from the transcript until RecordUtterance. The same fixture then consumes the real
scoped reservation and pure command, executes native mathematics, publishes the
actual refined witness and adopts its typed Exact outcome. It requires historical
quotation after the original binding's CAS license becomes stale. The witness's
retained request view cannot dispatch work. It also exercises a failing final
source destructor through Scope and request release, with retry and no repeated
destruction. This fixture remains unqualified until the shared SessionObservation
Scope path loads; it adds no production test opcode.

History joins a recorded source to the actual native request's original input
identity and issuer-checked observation. A dependency edge can denote an observed
earlier utterance and cannot substitute for this association. Missing or ambiguous
native attribution makes the projection explicitly incomplete. A retained denied
child may still supply its original attribution and unavailable part identities;
that historical getter never grants current dispatch or quotation permission.

## Qualification

The model tests exercise absent sessions, full read/observation pins, final-child
adoption ordering, post-adoption staleness, retained native evidence and Forget.
The ML producer and Scala decoder test original whitespace/newline bytes, negative
source clocks, conditional/prefix claims, historical observations, rejected pending
quotations, wrong-session references, original nonaccepted contexts, typed predecessor
edges with unavailable placeholders, dangling references, expired payloads, duplicate children, bounds,
and incomplete indexes. These are component checks.

The completion gate is an actual resident/workbench trial: create/open/list; submit
two real native turns with advancing adoption revisions; quote both under their
original conditions; close the resident and writer; reopen the same workspace and
recover identical history without a new journal entry or execution; reject stale
session selection; expire and deny payload access; Forget and verify durable
unavailability across another restart, with an unrelated conversation surviving.
Only the designated build owner runs native, Scala and runtime checks.

## Temporary recall-reader expiry audit

The upstream default concerns a derived saved-conversation reader. In
`upstream/workbench/server.py:987`, `/api/conv/specialist` defaults to seven days,
clamps explicit values to 1–365 days, and persists `time.time() + days * 86400`
as the temporary reader's expiration. Ordinary conversation JSON and the default
`keep_conversations=True` setting at lines 67–110 have no automatic TTL.
`ConversationOrgan` in `sources.py:363` recalls answered, non-workbench turns after
an explicit recall request and preserves their original date and route.

The pronoun path at `server.py:419` invokes a cached reader before the expiration
filter at line 430. The native repair must check the same lease before every
reader route, including cached/pronoun use, selection and late publication.
Explicitly revoking a conversation is a separate operation and does not implement
this default reader policy.

The approved D73 reader policy requires a distinct managed ReaderLease referencing its
source conversation, with a persisted creation reading and deadline under a fixed
UTC wall-clock origin and explicit integer tick unit. Seven days is the reader
default; the source conversation retains its own policy. Native clock observations,
`clock_reading` and `freshness_window` supply the typed check; the current source
has no installed authority-bearing native wall-clock sampler yet. A client timer
or a host cleanup timestamp cannot replace it. Expiry revokes the reader ID and
its dependents, preserving the source conversation. Restart keeps the original
deadline and rechecks it before enabling use; it does not renew a lease. The native
clock origin is an explicit environmental assumption and provides no elapsed-time
monotonic guarantee across wall-clock changes. This policy still needs shared
modeled/native integration and is not implemented by the explicit-expiry consumer.

The reviewed clock boundary separates the persisted lease/source policy from an
opaque current-clock witness issued only by the fixed native sampler. Creation
and every staging check use that sampler; a caller timestamp never authorizes a
reader. The modeled query requires exactly one intact lease, the same basis and
source association, and `created <= now < deadline`. Missing or duplicate leases
and a changed basis refuse use. The deadline is exclusive, including at the exact
expiration tick.

A staging sample cannot authorize a later acknowledgement. The native gate must
sample again immediately before acknowledgement and installation against the
retained exact policy projection. The existing Owner version check protects
intervening modeled lease/source transitions; the late clock guard handles time
passing without such a transition. Intrinsic gate liveness must not query the
Owner while its acknowledgement monitor is held. This boundary is reviewed design,
not a claim that a reader clock witness or modeled lease schema is installed.
