# Supplied DNA alignment

`oracle-bio` compares two supplied DNA strings. It returns one highest-scoring
alignment under the caller's scoring rule, the positions it covers, its edit
path, and two independent checks. Rust-Bio proposes the path. Separate Rust
code replays that path and computes the best score again with a rolling-row
dynamic program. This is checked integer computation, without an Isabelle
theorem or an inference about the sequences' biological meaning.

The first consumer is the native service's operation registry. This crate does
not register itself, choose a genome, fetch data, read files, or infer intent
from a sentence. Host integration and its qualification belong to root.

## Interface

```rust,ignore
oracle_bio::catalog() -> serde_json::Value
oracle_bio::call(request: &str, limits: &Limits, cancel: &AtomicBool) -> Result<String>
oracle_bio::align_pairwise(input: &AlignmentInput, limits: &Limits, cancel: &AtomicBool)
oracle_bio::check_alignment(input: &AlignmentInput, candidate: &Candidate,
                            limits: &Limits, cancel: &AtomicBool)
```

`call` accepts `{"operation":"bio.align_pairwise","arguments":{...}}`.
See [the teaching example](examples/teaching-alignment.json). For query `ACGT`
and reference `TTACGTAA`, the example's expected score is 8, query interval
`[0,4)`, reference interval `[2,6)`, and four matches. These are invented
teaching strings, without an organism or disease association.

Required arguments:

- `query`, `reference`: nonempty, case-insensitive DNA strings. Whitespace,
  FASTA headers, gaps, RNA `U`, and Unicode lookalikes are refused.
- `mode`: `global` consumes both strings; `local` selects an interval in each;
  `query_global` consumes the whole query and clips reference ends freely.
- `scoring`: integer `match_score`, `mismatch_score`, `gap_open`, `gap_extend`.
  A gap run of length k scores `gap_open + (k-1)*gap_extend`. Require
  `1 <= match_score <= 1000`, `-1000 <= mismatch_score <= 0`, and
  `-1000 <= gap_open <= gap_extend <= -1`. This last restriction ensures
  reopening a contiguous gap cannot beat extension of that run.
- Optional `ambiguity`: `reject` by default. `always_mismatch` admits IUPAC
  `RYSWKMBDHVN`; every such base scores as a mismatch, including `N` versus
  `N`. It does not treat letters as sets of possible matching bases.

Coordinates are zero-based half-open intervals in the original supplied
orientation. `insertion` consumes a query base; `deletion` consumes a reference
base. Every path column has an explicit edit; free clips are represented by
coordinates. A zero-score local optimum uses empty intervals `[0,0)`. A tie
returns one representative; the checker accepts other optimal representatives.
There is no reverse-complement search, protein scoring, significance estimate,
genome mapping, clinical interpretation, or sequence-design operation.

Result fields include the scoring and mode, candidate score/intervals/edits,
replayed score, independently computed optimal score, counts of the four edit
types and gap runs, input lengths, declared coordinate convention, and resource
estimates. `Error::code()` gives `invalid_input`, `resource_limit`,
`candidate_check_failed`, `cancelled`, or `invalid_json`.

## Bounds and cancellation

Admission happens before provider-owned normalization and matrix allocation:
at most 4,096 bases per string, 1,048,576 DP cells including the border, and
16 MiB estimated working buffers. Operator limits may lower these values.
The estimate is `8*cells + 256*(query_length+reference_length+2) + 65536`.
It conservatively covers the pinned aligner's two-byte traceback cells, its
linear rows, checker rows, normalized strings, edit path, and serialization
allowance. It is an admission estimate, without an allocator or process RSS
guarantee. JSON parsing is separately preceded by a fixed 256 KiB request cap.

The unbanded search and independent checker each take O(query*reference)
time. They execute serially without a thread pool or retained state. Rust-Bio's
traceback matrix is released before the checker pass. Cancellation is checked
before and after Rust-Bio, during traceback replay, and between checker rows;
Rust-Bio's call itself cannot be interrupted. Hard deadlines and memory
containment require the service's owned process workers.

## Current source and qualification

The dependency is pinned to `bio = 4.0.1`, with default features disabled.
Current official documentation and source were read on 29 October 2026:

- [Rust-Bio Aligner](https://docs.rs/bio/4.0.1/bio/alignment/pairwise/struct.Aligner.html)
  describes unbanded global, local and query-global (`semiglobal`) modes.
- [Scoring](https://docs.rs/bio/4.0.1/bio/alignment/pairwise/struct.Scoring.html)
  and [implementation](https://docs.rs/bio/4.0.1/src/bio/alignment/pairwise/mod.rs.html)
  establish the first-base gap-open convention and buffer representation.
- [Alignment](https://docs.rs/bio/4.0.1/bio/alignment/struct.Alignment.html)
  describes query/reference coordinates and edit directions.

Authored tests include exhaustive edit-path enumeration for every pair of
nonempty binary DNA strings up to length three, under all three modes and
three scoring profiles. This includes mismatches that cost more than two
opposite gaps. Other cases cover affine gaps, coordinate clipping, ties,
ambiguity, tampered and suboptimal paths, malformed inputs, fixed/lowered
resource caps, cancellation, and the JSON contract. This lane ran only
`rustfmt`, successfully. Root must compile and run the focused tests centrally.
There are no new specialist-panel numbers yet, and no new theorem statements.

## Existing specialists and next consumers

Read-only inventory found that the shipped `biology` already covers codons,
complement/reverse complement, transcription, translation and GC content.
`genetics-v2` covers Mendelian crosses and Hardy-Weinberg calculations.
`microbiology-v2` covers growth, generation times, plate counts and dilutions.
The older genetics/microbiology cards explicitly say they were superseded.
Their recorded historical panel results are not new measurements of this crate.
Pairwise alignment is a distinct addition; it does not replace those readers.

Useful next work is ordered by a consumer and its checking boundary:

1. Add a sentence reader for explicit alignment requests and a specialist
   panel with benign teaching and plant-fragment examples. Keep mode, strand,
   ambiguity and scoring visible; recognize missing declarations and decline.
2. Support bounded local FASTA/FASTQ import with caller-owned content, record
   and base budgets, identifier provenance, and explicit quality encoding.
3. Add bounded BAM interval summaries through
   [noodles](https://docs.rs/noodles/0.118.0/noodles/), after choosing policies
   for secondary/supplementary/duplicate reads, mapping quality, CIGAR handling,
   coordinate conversion and indexed-region completeness. Counts require a
   declared file/reference/index pair and coverage, not a pile of sample rows.
4. Add VCF filtering/counting only after defining assembly and sample identity,
   multiallelic records, missing genotypes, normalization and filtered versus
   unfiltered records. File decoding does not establish variant significance.
5. Evaluate exact bounded k-mer counting or seed lookup using Rust-Bio's
   [q-gram index](https://docs.rs/bio/4.0.1/bio/data_structures/qgram_index/index.html).
   Choose strand/canonicalization and ambiguity policy, bound `4^k` index
   allocation and occurrence output, and distinguish seed hits from alignment
   or homology. Add the dependency only when a concrete consumer needs it.

No noodles dependency, retained sequence store, biological design feature, or
file-format parser is introduced in this checkpoint.
