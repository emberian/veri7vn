# Governed resources and exposure

Governed access binds protected source membership to the resources that reveal an item: input, answer, explanation, scorer, and declared derivatives. Dataset names and candidate versions do not create fresh resources. The host resolves actual objects and known aliases/overlaps; unknown membership, provenance, classification, or disjointness yields **Unknown**, not FreshHoldout.

Protected associations describe:

- Membership identifies dataset/split, source pin, exact resources, producer provenance, and alias/overlap closure.
- Reveal identifies selected members, governed observer/learner audiences, purpose, source pin, and applicable attempt/operation.

These join the canonical ledger; package code cannot invent membership or maintain separate exposure authority.

Every inspect, preview, export, or run resolves membership and audience policy, stages exposure against the exact authority revision/epoch, persists the generated delta, and receives its durable acknowledgement **before** reading reveal-bearing bytes. The protected read still checks current association access and retirement. Cancellation or a crash after consumption does not restore freshness. Qualification binds the pre-reveal eligibility and the resulting exposure history.

Audience identity follows the managed learner lineage, authoring group, recipient, or other declared observer scope; a new candidate/run cannot reset it. Known aliases and overlaps propagate spent status. This protocol does not detect arbitrary semantic reencodings or prove that no human has seen a similar question.

Imported Oracle7 panels, scorer files, logs, and verdicts preserve sender attribution. A missing log or renamed dataset cannot establish a fresh recipient holdout. Unknown gold remains a question/proposal and is never scored correct.

## Forget and integration

Forget removes content and its identity/hash associations, retaining only policy-permitted opaque spent/unknown lineage metadata. It keeps no concealed content fingerprint. If remaining metadata cannot establish nonexposure, eligibility is Unknown; reimport defaults to Unknown unless authorized new-resource provenance establishes disjointness.

Complete managed Forget joins storage erasure, generated retirement, and native/private-worker cleanup. Managed previews/caches participate; external copies and public commitments lie outside this erasure boundary.

`ManagedDrafts` supplies internal source storage, not a governed reveal endpoint. Inspect/export/runner and native-build consumers must place the acknowledged exposure transaction above their reads. Canonical exposure events and opaque host reveal capabilities remain integration obligations; association membership and retirement alone do not establish held-out eligibility.
