# Proposed upstream discussion: Oracle7/veri7vn appliance and agent-facing interfaces

Status: published after root review: [https://huggingface.co/psiloceyeben/oracle7-slim/discussions/5](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/5).
Created: `2026-10-27T18:01:52+00:00`. Returned body verified; HF removed only the terminal newline.
Published body SHA256: `027fd36b667acee1a997fa796504a34383c7e12971f43cc54f5b4b077f1c108b`.
Submitted body SHA256 (with terminal newline): `5b269d6c949ce2e1e64ddc211028ccb2c994ee2f1a426e3358bfbe9ee370e96c`.
The published body is the text below the separator, stripped at both ends.
Target: `https://huggingface.co/psiloceyeben/oracle7-slim/discussions`
Title: **Building a shared Oracle7/veri7vn appliance for users and agents — interfaces and collaboration**

---

Hello! We wanted to connect the individual bug reports with the larger thing
we're building: a reusable Oracle7/veri7vn appliance for people and agents in
Mini/Dreggnet, with a browser interface and direct, discoverable operations.
Thank you for incorporating the first veri7vn/runtime repairs into 10.0. We
would like this work to remain useful upstream rather than become a disconnected
packaging fork.

The current appliance has three parts:

- A pinned runtime containing Oracle7, reviewed source repairs, selected
  veri7vn kernels, and optional companion providers.
- About **15 GB of shared public data**, published once with an inventory digest
  and mounted read-only. Runtime and data have separate identities, so each
  user's state does not need another corpus copy.
- Private conversation and request journals. Mini supplies authenticated caller
  identity, package admission and resource authority; the Oracle adapter runs
  calculations and preserves their returned evidence.

The serving surface includes conversational `/query`, paginated operation
search/inspection, and `/invoke` with explicit operation arguments. Discovery
comes from the running registration/implementation chain, not a count of every
specialist directory. Descriptors distinguish directly callable, text-only and
unavailable operations and expose inputs, units, examples and limits. The
browser page uses the same routes as agent tools; it is not a second execution
or authorization path.

We're adding shared hosting with separate tenant workspaces and a bounded pool
of resident Engine processes. Mini derives tenant scope from the authenticated
principal and source session; request bodies cannot select another tenant.
The initial memory-constrained package allows **one resident worker and up to
128 persistent workspaces**, with busy capacity refused rather than queued
without a bound. This is a configuration being qualified, not a throughput
claim. Exact completed requests replay from disk. Because Oracle does not
restore all conversation context after worker retirement, a new turn in an
old conversation explicitly requires a fresh conversation and supplied context;
we don't silently rebuild it by replaying old effects.

Our current serving candidate is still **4.9-based with pinned repairs**, not a
qualified 10.0 appliance. Hosted source/component tests pass; the next signed
v6 package and its complete receiving journey are pending. Earlier real Mini
runs installed and queried separate grains with isolated state, but the retained
agent lifecycle/recovery journey remains incomplete. A historical-lookup
transport/recovery fix is under review. No public deployment or complete
lifecycle success is being claimed.

The verification boundary matters to us: theorem-backed arithmetic or source-row
properties do not prove an English interpretation, source completeness or every
statement in a displayed answer. The adapter retains complete kernel replies,
scoped comparison outcomes and declared provenance without promoting a label
into general authority. Unsupported inputs and uncertain execution remain
visible. No old admission verdict is rewritten to qualify changed code.

We are using empowered coding subagents for broad source review, independent
expected-answer cases, real-consumer tests and repair integration. The output we
want to share is portable counterexamples, narrow patches and reproducible
receipts—not an agent's declaration that a whole system is correct. Two current
Terra lanes are reviewing relation/source semantics, and two Sol lanes are
checking relevant primary literature using Scry/Kagi; these are ongoing
investigations, not established new findings.

The concrete contributions are [the 10.0 usage/conversation/geometry PR #2](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/2),
[counted orbital years #3](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/3)
and [date precision #4](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/4).
Companion fixes are also proposed for
[Trafficcop](https://huggingface.co/psiloceyeben/oracle7-trafficcop/discussions/1),
[DeepSpace](https://huggingface.co/psiloceyeben/oracle7-deepspace/discussions/1),
[Infrastructure](https://huggingface.co/psiloceyeben/oracle7-infrastructure/discussions/1),
[Vision](https://huggingface.co/psiloceyeben/oracle7-vision/discussions/1) and
[Artist](https://huggingface.co/psiloceyeben/oracle7-artist/discussions/1).
Those each carry their own measured scope; packaging them does not establish
unrestricted capabilities.

Implementation references:

- [Service contract and operation discovery](https://github.com/emberian/veri7vn/blob/c171f6f1bd8e4e07a3a9d78b73dff40f8fc14264/tools/appliance/README.md)
- [Shared-hosting design and acceptance work](https://github.com/emberian/veri7vn/blob/32f54983f8ab2bd16369757b4a6fc76706f810dd/project/HOSTED-2026-10-27.md)
- [Mini appliance overview](https://github.com/emberian/minidregg/blob/30268be06e4f758ccee58c54dafcfe042cdd6336/docs/oracle-appliance.md)

We would welcome alignment on a few interfaces before migrating the appliance
to 10.0: a stable operation/capability schema, complete reply and refusal evidence,
versioned data manifests that retain source precision and qualifiers, release
pins/dependency profiles, and an explicit contract for conversation save/restore.
Which parts would be most useful to standardize upstream, and is there a
preferred route for submitting small independently reviewable repairs and
qualification cases? We can keep host-specific Mini policy separate while
making the Oracle-facing contracts and checks reusable elsewhere.
