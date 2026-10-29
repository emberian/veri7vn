# Biology transcription direction — 29 October 2026

Published [upstream PR #8](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/8)
after root review. It remains open; no upstream acceptance is claimed. The PR
commit is `feb6ab9ad937a45c4e531a7ca23f90f2c3f07921`.
The current slim main was fetched fresh at
`c473d28914e480425adb29b4f7f42485b8cfb4e3` (10.1). Its seven public discussion
titles and the tracked contribution list contain no existing biology report.

The actual biology organ answers `UCCGUA` to “Transcribe the DNA template strand
3'-TACGGA-5' into mRNA.” The correct 5′→3′ transcript is `AUGCCU`. It always
reverses template strands, even when the supplied template is already written
3′→5′. Coding strands have the corresponding missing normalization.

The patch binds adjacent end labels to the sequence chosen by the existing
reader and respects their orientation. It declines contradictory end labels,
leaves the existing unlabelled 5′→3′ convention in place, and states that
convention in the module contract. It does not interpret output-direction words
elsewhere as input labels. The consumer is the `biology` manifest's
`organ_biology_v1.BiologyOrgan`, accepting its existing `transcribe` kind. The
fresh Git tree has one biology implementation, with no second organ copy.

Changed files in the isolated contribution checkout only:

- `root/specialists/biology/organ_biology_v1.py`
- `tests/biology/test_transcription_direction.py`

Scratch and review artifacts live in `var/upstream-domain-20261029/`:
`biology-transcription-direction.patch`, `pr-description.md`, `results.json`,
`tests-baseline.txt`, `tests-patched.txt`, and the selective `checkout/`.
The original `upstream/`, appliance, native families and other lanes are unchanged.

The actual shipped biology panel scored with its own scorer before and after:

| Split | Right | Wrong | False yes | Correct decline | Changed replies |
| --- | ---: | ---: | ---: | ---: | ---: |
| dev | 14 | 0 | 0 | 1 | 0 |
| heldout | 14 | 0 | 0 | 1 | 0 |

All 11 focused unittest methods pass after the repair. The same suite against
the exact pinned source has 259 failing assertions/subtests across seven
methods. Independent checks include typed expected transcripts, both roles and
orientations, prime/separator spellings, conflicting labels, unrelated output
direction, and all 256 four-base templates in both written orientations (512
checks). `git diff --check` and reverse patch applicability pass. The ordinary
panel has no template-polarity cases; its unchanged score alone cannot detect
this defect.

Biological source: [OpenStax Biology 2e §15.2, figure 15.7](https://openstax.org/books/biology-2e/pages/15-2-prokaryotic-transcription)
and [Genomes, figure 3.4](https://www.ncbi.nlm.nih.gov/books/NBK21121/).
RNA is made 5′→3′ against the complementary template read 3′→5′.

No theorem changed or was claimed. This Python organ is untrusted; the portable
tests say so. No whole Engine, native build, admission gate, or new fleet score
was run. Root published the two-file patch under the existing user authorization
and verified that discussion #8 is an open pull request. Upstream acceptance
remains outstanding.
