# Exact fragments in supplied DNA

This consumer asks which supplied fragments appear in an ordered collection of
supplied DNA records, in either strand. It consumes every page before reporting
absence. Every hit retains record and pattern ordinals, labels, strand and original
zero-based half-open coordinates. Labels may repeat. Overlapping matches count;
a reverse-complement palindrome appears once with strand `both`. Identical
patterns at different ordinals remain separate queries. Ambiguous DNA is rejected.
Empty records and collections are valid; empty patterns are not.

With a bio-enabled local native host running, from the repository root:

```
python3 tools/usage/sequence_collection.py native/oracle-bio/examples/supplied-fragments.json --reference
```

The ordinary client replays every reported hit against original record bytes.
The optional bounded naive reference also checks omissions on small inputs.
Client page/hit caps and native work exhaustion withhold a result; neither means
zero matches. The consumer bounds aggregate output to 16384 hits and 256 pages.

`panel.json` has 7 dev and 10 held-out cases. `scorer.py` compares literal
independently specified original coordinates, pattern ordinals, strands and absent
pattern ordinals. `organ_collection.py` accepts a complete `Find exact fragments: `
JSON request through the standard specialist interface and calls the fixed local
host. It does not implement a second search backend. These are new consumer panels,
not the shipped biology/genetics comparison panels. No panel run or score is
claimed in this implementation handoff. The normal six-criterion Workbench exam
still needs execution against actual host/core replies by the central runner.

The native representation stores one immutable normalized collection behind
shared ownership. `SequenceCollection::prepare` preserves a SHA256 identity of
ordered original source bytes and labels. `PreparedSearch::prepare` adds one
shared forward/reverse pattern trie; `.page` reuses both collection and trie.
Typed callers own their lifetime and may share these immutable values. No tenant
global registry or eviction policy is introduced. HTTP calls are stateless: each
page resends, reparses, normalizes and rebuilds the trie. Cursor identities cover
collection source bytes and pattern source bytes/order, but permit page-size
changes. A cursor is a suffix position, not authenticated proof that earlier pages
were read. `complete` means the remaining suffix was exhausted; clients must start
without a cursor and follow every continuation for collection-wide absence.

The search walks the trie once from each record position. A missing branch stops
that walk. Shared prefixes reduce repeated work across patterns; no dense 4^k
array, posting sort, frequency masking or boundary concatenation occurs. Worst
case is O(total record bases * longest pattern length), so a hard 16777216-transition
cap and inherited execution budget bound each page. This deliberately simple
choice fits the supplied short-fragment consumer; no faster-than-indexed-search
claim is made. Per-page scanning is a handwritten complete traversal, not a proof.

Admission bounds are 131072 collection bases, 256 records, 128 patterns, 4096 total
pattern bases, 256 UTF-8 bytes per label, and 1024 hits/page. The trie has at most
8193 nodes, per-position terminal candidates at most 256, and output sequence
bytes at most 1024*4096. Caller-owned inputs, allocator metadata and process RSS
are outside this structural buffer bound. JSON has the provider's separate 256 KiB
request cap. No alignment score, approximate match, organism identity, homology,
clinical meaning or Isabelle assurance follows.

The bioinformatics scout's Rust-Bio q-gram source audit motivated avoiding dense
alphabet-sized tables and masked seeds for complete occurrence queries. The local
Branchwater paper (Irber, Pierce-Ward and Brown, 2022, Methods, multithreaded search)
informed immutable shared query ownership; its sketch overlap statistics are not
used here. Other inspected paperbin papers concern approximate/global alignment,
minimizers and affine traceback, none of which establish complete exact-fragment
matches. The algorithm and its explicit small-input reference are the evidence.

A focused coordinate-panel diagnostic against the same running host is:

```
python3 tools/usage/specialist/sequence-collection/run_panel.py --url http://127.0.0.1:8765
```

It reports correct/wrong/withheld/false-yes counts for the new dev and held-out
cases. It is explicitly separate from the original six-criterion admission exam.
