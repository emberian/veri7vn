# Publication and release dates for work-year questions

The U3 addition supplies 11 bounded P577 work records, retaining 26 selected
claims and 24 exact JSON/RDF/store bindings. The merged sidecar has 211 pairs
and is 2,627,008 bytes. All 200 U2 records are preserved unchanged. Public source
snapshots and actual store-binding receipts are under `var/u3-dates/`; no store,
immutable candidate or upstream tree was modified.

The new `date_precision_v1.publication_intervals(value, subject)` operation
returns per-statement positive publication/release witnesses. Each has `interval`
(calendar, lower date, upper date), `source`, `statement_id`, `qualifiers`, exact
literal and subject/property identity. It applies only to P577 and to a condition
asking whether some recorded release/publication occurred in the year, with no
place, format, edition or first-release restriction.

Typed P291 publication-place qualifiers remain in each witness: a release in a
particular place still supports the existence of a release. Format P437,
unknown edition/modifier qualifiers, circa and malformed context are unsupported.
The operation neither resolves a title nor proves there were no other releases.
The original strict `interval` operation is not relaxed and does
not use these regional dates for unqualified chronological ordering. Callers
must retain the publication witness's scope in their receipts.

| Source work | Bound publication/release evidence | Positive witnesses |
| --- | --- | ---: |
| Hamlet film Q27178 | 1948, Gregorian year precision; 28 September 1948 in Sweden | 2 |
| Hamlet play Q41567 | 1602 and 1623, Gregorian year precision; separate from the film | 2 |
| Pride and Prejudice novel Q170583 | 28 January 1813, Gregorian | 1 |
| Emma Q223880 | 23 December 1815, Gregorian | 1 |
| The Hobbit Q74287 | Preferred 21 September 1937, Gregorian; normal 1937/1938 claims retained but not substituted | 1 |
| Nineteen Eighty-Four Q208460 | 1949, Gregorian year precision | 1 |
| The Lord of the Rings Q15228 | 1954, Gregorian year precision; no claim about every volume/edition | 1 |
| Casablanca Q132689 | 26 November 1942 NYC; 23 January 1943 US; 11 October 1943 Sweden; 23 May 1947 France | 4 |
| The Shawshank Redemption Q172241 | Five regional/festival dates in 1994 and 1995 | 5 |
| Pride & Prejudice film Q270385 | Four regional dates in 2005/2006; another 2005 statement with P437 format is retained but unsupported by this API | 4 |
| Pride and Prejudice film Q940014 | 1940, Gregorian year precision | 1 |

All listed records came from official Wikidata entity JSON and RDF at the same
revision; their selected statements, qualifiers, references, revision URLs and
hashes are retained in the sidecar. The 23 positive witnesses are checked against
the immutable relation store in `var/u3-dates/actual-work-bindings-v1.json`.
Before this addition none of these 11 P577 pairs had source precision metadata.
These are data/API coverage counts, not full-engine or specialist-panel scores.

Independent institutional sources corroborate representative identities/dates:
[BFI's Hamlet record](https://www.bfi.org.uk/film/0f1a5830-5ccf-555e-a1d7-d6bebc12b9d8/hamlet)
identifies Olivier's 1948 film; [the Tolkien Estate](https://www.tolkienestate.com/writing/john-d-rateliff-the-hobbit/)
gives the Hobbit's 21 September 1937 publication; and
[Jane Austen's House](https://janeaustens.house/jane-austen/novels/pride-and-prejudice/)
gives Pride and Prejudice's January 1813 publication.

Edition identity matters. [Jane Austen's House's first-edition record](https://janeaustens.house/object/emma-first-edition/)
explains that Emma appeared on 23 December 1815 but its title page says 1816.
An absent bound 1816 publication witness therefore must not be presented as proof
that an “1816 Emma” premise is false. The metadata deliberately does not replace
one date role with another. Similarly, a regional film release is not a claim
about its first release everywhere.

## Reproduce the bounded extension

```sh
.venv/bin/python -B tools/usage/dates/import_precision.py \
  --runtime var/usage-20261027/candidate-final-v3 \
  --selection tools/usage/dates/selection-works.json \
  --base-sidecar var/usage-20261027/candidate-final-v3/root/relstore/date_precision_v1.json \
  --cache var/u3-dates \
  --out var/u3-dates/new-merged-sidecar.json \
  --fetch --workers 4
```

Omit `--fetch` to use retained snapshots only. Existing outputs are never
overwritten. `--base-sidecar` requires the same schema and declared store
identity, rejects duplicate identities/failed base imports, preserves existing
records, and replaces only explicitly selected pairs. Existing size and record
bounds apply to the merged result.

Validation: 44 focused date/import/consumer tests pass. New tests cover scoped
P291 witnesses, malformed places, unsupported edition/format/uncertainty
qualifiers, preserved precision/calendar, property/literal mismatch, strict ordering, and safe sidecar merging. No theorem changed or Isabelle build
ran. No full engine was started in this lane; service owns the live consumer
probe after integration. The premise lane owns `premise_v3.py` and w571 and wires
this API into their positive condition receipt.

Twelve proposed live consumer inputs and before-run source expectations are in
`work-cases.json` and `work-expectations.json`. Ten have a matching positive work
and year witness; Hamlet1949 and Emma1816 are insufficient-bound-evidence controls.
Earlier title/relation routing can still fail independently of these source
conditions. Whole-title candidates must be checked against kind and source-bound
year; the most popular sense is not automatically the requested edition.

Frozen private runtime files are only `root/wander-train/date_precision_v1.py`
and `root/relstore/date_precision_v1.json`, with identities in
`var/u3-dates/frozen-hashes-v2.json`. The owned importer, selection, test and usage
files are ready for root integration. Broader work/date coverage remains open.


Final hardening also rejects unrecognized P4241 date refinements as interval
premises. Only the known beginning/middle/end/half markers may retain the wider
source interval; an unfamiliar calendar-year descriptor remains visible when
rendering but gives no ordering or publication witness. The eleven added work
records have no P4241 qualifiers, so their 23 positive witnesses are unchanged.

The premise lane found existing P7937 (form of creative work) assertions for the
novels. This supplies positive novel classification without misclassifying every
literary work or fiction genre as a novel. That reader repair belongs to the
premise lane; no extra class data were invented or imported here.
