# Exact ConceptNet source chains

The original corpus is locally retained under
`upstream/root/fable-content/oracle-m-series-2026-08-15/m13e5_conceptnet_build_a_v1/`.
Use `ConceptNetObservation.observe` to produce the existing bounded source-row/2
input, then acquire it with the fixed source producer. Request exact UTF8 labels
through `ConceptNetQuery`; a numeric graph surrogate is not this profile.

The native regression uses `robin -> bird -> meat`. Both edges are present in the
original corpus. This is intentionally an example of the remaining sense ambiguity:
the result reports those source rows, with confidence, dataset, surface text and
part-of-speech cells preserved. It supplies no unconditional world IsA assertion.
A failed bounded search or a truncated neighborhood is inconclusive.

See [source profile](../../../docs/sources/conceptnet.md) for the extraction,
ranking, dictionary, lifecycle and coverage boundaries and reproducible checks.
