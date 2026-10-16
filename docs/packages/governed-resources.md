# Governed dataset access and exposure

This is the package/host integration contract being wired to the canonical authority
model. It does not create a second permission ledger in the package layer. Existing
managed source storage checks association membership and retirement; those checks
alone do not establish held-out eligibility.

A governed producer binds an actual protected source association and exact dataset/
split membership to resource identities for the material that can reveal an item:
question/input, expected answer, explanation, scorer, and any other declared reveal
closure. The host assigns identities from actual protected objects and known alias/
overlap mappings. Dataset labels, candidate versions and run identifiers cannot create
new resource identities. Unknown membership, classification, provenance or disjointness
prevents a FreshHoldout claim.

The finite authority input is a producer-bound membership artifact and a reveal intent:

- Membership: dataset/split/source association and pin, exact member/reveal resource
  identities, producer provenance and registered alias/overlap closure.
- Reveal: membership identity, exact selected resource identities, governed observer/
  learner scope identities, purpose (inspect, export or run), source pin, optional
  attempt identity and operation identity.

These are protected association references, not editable proof declarations or asserted
hash lists. Canonical generated constructors, guards and events belong to the authority
owner. The host verifies the descriptor against actual source membership; package UI/
runner code cannot claim that an arbitrary resource list was the registered population.

Every governed reveal follows the same sequence: resolve actual membership and the
route's audience policy; stage exposure against the exact authority revision/epoch;
persist the generated delta and receive its exact durable acknowledgment; then read
only the leased members through the host's protected callback. The callback still
checks current association access and retirement. No bytes, answer-bearing preview,
export ZIP or worker lease may precede that acknowledgment. Cancellation and a crash
after consumption do not restore freshness. A measured result can also be spent.
Qualification eligibility binds the pre-reveal exposure state; the completed run binds
its appended exposure state and actual resource observations.

## Audiences and claim limits

Audience scope is governed independently of candidate and run IDs. Policy can name a
program learning lineage, an authoring group, a recipient or another explicitly managed
observer group. A new candidate/version cannot reset the lineage's exposure. The route
policy decides which governed audiences receive the material:

| Route | Material revealed | Required audience treatment |
| --- | --- | --- |
| Author source inspection | Original panel, examples, scorer and history | Record known governed membership before reveal; imported/unclassified originals remain accessible as author source with Unknown/spent eligibility |
| Learner or scorer run | Exact registered input/answer/scorer closure | Consume the actual learner/scorer observer scopes before dispatch; bind the candidate/run separately |
| Example/answer preview | Selected item or answer-bearing derivative | Include the observer scopes governed by the preview policy and its known derivative closure |
| Export | Selected governed resources and curated derivatives | Consume the governed export/recipient scope before reading ZIP inputs; preserve sender exposure attribution |

“Fresh” means eligible under this registered resource population, recorded exposure
history and governed audience policy. It does not mean no human anywhere has seen a
similar question. Known aliases and overlaps propagate spent status before access.
The protocol does not detect arbitrary reencoded semantic duplicates. When provenance
is insufficient, the operational result is Unknown, not a claim of novelty.

Imported Oracle7 originals retain panel/log/verdict/scorer bytes and sender attribution.
An absent log, renamed dataset, new candidate ID or deleted receipt cannot make those
originals a fresh recipient holdout. Unknown expected values remain proposals/questions;
they are not scored as correct or converted into training truth.

## Forget and reimport

Normal Forget removes requested content and its identity/hash associations. It retains
only minimal opaque spent/unknown lineage metadata allowed by the declared retention
policy. No concealed content fingerprint is retained to defeat erasure. If the remaining
metadata cannot establish nonexposure, the affected scope/resource is Unknown. Reimport
is Unknown by default; new labels cannot launder a forgotten membership into Fresh.
Fresh eligibility needs actual authorized new-resource provenance and disjointness under
the governed protocol.

Storage erasure, generated retirement and native/private-worker root release remain
separate acknowledgments in full Forget. Previously returned external copies and public
commitments are outside managed erasure. Package/source/view caches that remain managed
must participate in the same lifecycle closure.

## Current implementation boundary

`ManagedDrafts` is an inert internal source-store consumer, not a governed dataset access
endpoint. Its original/source snapshots may include answers and sender history. A service
must place the governed producer/access transaction above those reads before exposing
known protected resources through inspect/export/runner routes. The same requirement
applies to native build materialization when its source closure contains governed data.
The canonical authority events and opaque host reveal capability are coordinated with
their owners; this document does not claim that the current storage tests already prove
freshness, permission or full native forgetting.
