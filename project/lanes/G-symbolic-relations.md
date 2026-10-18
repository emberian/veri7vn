# Requested professions in relation questions

Owner: Codex symbolic deputy. Staged successor to Relations F; no new native or shipped-panel result yet.

The actual source/whole-front-door review asks about each of 14 domains a named person’s birthplace, then asks the same whole question with an explicit profession. All 14 typed questions currently withhold. Five unqualified questions answer; the other nine have multiple stored locations, unresolved senses or a decisive reader refusal. The proposed parser preserves the whole name and turns the profession into a checked P106 row plus source ancestry constraint. It does not invent missing biographies.

The inherited composer domain admits conductors, and the journalist domain admits television presenters. The stored class closures do not identify those roots as composer or journalist. Explicit requested professions therefore use the narrower actual composer/journalist roots. Musician roots retain named instrumental professions; their semantic classification, and the finite source ontology, remain supplied premises.

| Reader ID | Examined whole-front-door request | Current result and boundary |
| --- | --- | --- |
| `rel-actors` | Where was the actor Audrey Hepburn born? | Untyped withholds: DECLINE:P19; explicit profession currently withholds. |
| `rel-chemists` | Where was the chemist Marie Curie born? | Untyped withholds: DECLINE:P19; explicit profession currently withholds. |
| `rel-composers` | Where was the composer Wolfgang Amadeus Mozart born? | Untyped withholds: DECLINE:P19; explicit profession currently withholds. |
| `rel-graphicartists` | Where was the graphic artist M. C. Escher born? | Untyped answers Leeuwarden; explicit profession currently withholds. |
| `rel-journalists` | Where was the journalist Nellie Bly born? | Untyped withholds: AMBIGUOUS; explicit profession currently withholds. |
| `rel-musicians` | Where was the musician Louis Armstrong born? | Untyped withholds: DECLINE:P19; explicit profession currently withholds. |
| `rel-painters` | Where was the painter Pablo Picasso born? | Untyped withholds: AMBIGUOUS; explicit profession currently withholds. |
| `rel-philosophers` | Where was the philosopher Immanuel Kant born? | Untyped answers Königsberg; explicit profession currently withholds. |
| `rel-photographers` | Where was the photographer Ansel Adams born? | Untyped withholds: AMBIGUOUS; explicit profession currently withholds. |
| `rel-physicians` | Where was the physician Hippocrates born? | Untyped answers Kos; explicit profession currently withholds. |
| `rel-physicists` | Where was the physicist Albert Einstein born? | Untyped answers Ulm; explicit profession currently withholds. |
| `rel-poets` | Where was the poet Walt Whitman born? | Untyped withholds: DECLINE:P19; explicit profession currently withholds. |
| `rel-sculptors` | Where was the sculptor Auguste Rodin born? | Untyped answers Paris; explicit profession currently withholds. |
| `rel-singers` | Where was the singer Ella Fitzgerald born? | Untyped withholds: DECLINE:P19; explicit profession currently withholds. |

Baseline with raw source row/occupation evidence: `var/symbolic/relations-g/profession-baseline.json`. Staged parser: `var/symbolic/relations-g/query_request.py`. An unproved supplied-row reference recovers the five already identifiable names under explicit profession wording (`profession-reference.json`); this is a development lead, not a native capability score.

Next implementation connects the staged parser to F’s property-class interpreter, tests wrong profession and missing alternative evidence, and measures the real front door. Any remaining valid unanswered question remains withheld-valid. No broad panel rerun is claimed or needed until the adapter change is executable.

Drain note: these are exact-ID source/domain review leads with whole-front-door outcomes, not isolated specialist measurements. Profession interpretation remains staged only; no new native/proof was submitted. Exact parked state and resume commands: `var/symbolic/relations-g/RESUME.md`.
