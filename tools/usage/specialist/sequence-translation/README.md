# Translate declared coding intervals

A user supplies ordered DNA records and explicitly declares each interval, strand
and frame. The result gives its literal standard-code protein and maps every amino
acid back to exactly three original source bases. This operation does not select
an ORF, infer a gene, recode a start codon or infer protein function.

The named code `ncbi-standard-1-2024-09-23` uses the ordinary amino-acid row of
[NCBI's standard genetic code table 1](https://www.ncbi.nlm.nih.gov/Taxonomy/Utils/wprintgc.cgi#SG1),
whose source page states its September 23, 2024 update. The table and its distinction
between ordinary codon assignments and initiator assignments were checked live on
October 31, 2026. Only this code is admitted. `literal_codon` means TTG and CTG
remain leucine, including at the first codon. Selecting this table is a supplied
assumption; the consumer cannot choose the proper code from an organism's name.

Every feature refers to a record ordinal and `[start,end)` in the original forward
sequence. Labels are provenance and may repeat. `frame` is an explicit skip of
0, 1 or 2 bases from the feature's oriented 5-prime end. A reverse feature reads
`end-1` first and complements its bases; emitted codon intervals therefore descend
in original coordinates. The mapping records strand and the oriented DNA codon.
`frame_skipped` records skipped bases. `trailing_bases` records the 0–2 bases left
after the chosen frame's complete codons. The two omission intervals remain in
original coordinates.

All policies are required. `remainder=reject` refuses incomplete final codons;
`drop` retains their omitted interval. `stops=include` emits `*` and its mapping;
`terminate` excludes the first stop from the protein, retains its separate
`termination_stop` mapping and reports the original interval after it as
`untranslated_after_stop`; `reject` refuses any encountered in-frame stop. A
trailing-base interval can overlap the untranslated suffix after a stop: the
first describes frame geometry and the second describes policy termination.
Remainder admission applies before termination, including bases after a stop.
`complete=true` means all features finished under these declared policies, even
if terminate deliberately leaves a suffix untranslated. No partial success is
returned on resource refusal or rejected content.

The source accepts only DNA IUPAC letters, with case normalization and no U,
whitespace, gaps or FASTA. `ambiguity=reject` requires every supplied source base,
including unselected records and intervals, to be ACGT. `unknown` emits `X` for
any codon containing ambiguity. It deliberately does not resolve even unanimous
expansions such as GCN, or recognize ambiguous stops such as TAR. Reverse mapping
preserves the proper IUPAC complement in the reported codon.

`oracle-translation-source-v1` is separate from the exact-search collection
schema: translation's declared ambiguity handling does not change exact search's
ACGT-only contract. Its SHA256 covers original ordered source bytes and labels.
The request SHA256 also covers the code, policies and complete ordered feature
fields. `PreparedTranslationSource::prepare` creates immutable shared normalized
records; `translate_prepared` reuses them across caller-owned batches with the
same source identity. There is no global registry. HTTP calls rebuild the source
per request. No new dependencies are needed.

Bounds: 131072 source bases, 256 records, 256 features, 256 UTF-8 bytes per label,
and 16384 potential codons summed across all features. Potential codons are capped
before translation even when stop termination would reduce output. Computation
is linear in source bytes plus admitted codons/features. Normalized source bytes
are stored once; mapping/protein output is O(admitted codons), with at most 256
additional stop/omission records. Shared `WorkControl` charges source admission
and each translated codon. Allocator metadata, caller-owned input and process RSS
are outside these structural buffer bounds. The provider's JSON byte cap still
applies. Client response reads are capped at 8 MiB.

With a translation-enabled native host running:

```
python3 tools/usage/sequence_translation.py native/oracle-bio/examples/translation-supplied.json
python3 tools/usage/specialist/sequence-translation/run_panel.py --url http://127.0.0.1:8765
```

The consumer independently replays the complete returned protein/codon/source map
against the original input and a separately grouped codon dictionary. The new
panel has 8 dev and 12 held-out cases with literal protein and coordinate gold,
including asymmetric reverse mapping, alternate frames, remainder, all stop
policies, literal initiation, conservative ambiguous codons and rejected RNA.
The native tests independently tabulate all 64 standard codons by families.
This is handwritten checked computation, not an Isabelle theorem. No test run,
new-panel score or six-criterion admission result is claimed at authoring time.
The shipped biology/genetics panels remain separate comparison controls.

Transport/host execution failures are explicitly reported as `execution_failure`,
separate from a locally established `invalid_input` refusal. The scorer accepts
only the latter for negative gold cases; an outage cannot score a refusal right.
The client also checks exact integer types for every ordinal and source coordinate
rather than relying on Python's bool/float-compatible dictionary equality.
