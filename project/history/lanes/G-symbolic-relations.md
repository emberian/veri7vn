# Requested professions in relation questions

## Root integration at wrap-up

The profession parser is now connected to the existing checked
`QueryPropertyClass 106 roots` interpreter. It retains all earlier city roots
(the parked parser had an older city list), the complete remaining entity name,
and suffixes in question frames such as “born” and “play”. Explicit composer
and journalist constraints retain the narrower roots described below.

Ordinary unqualified birthplace, death-place and instrument questions remain
on the original reader path. An initial normalization of those questions caused
60 extra shipped refusals because individual reader forms are deliberately
dropped in some specs. The final repair preserves the original forms. All
2,797 panel replies across the fourteen readers now have identical status,
value, response and path to the pre-change baseline: **2,623 right, zero wrong,
zero false yes, 174 remaining withholds**. The other harness criteria were not
fully measured; this is not a whole-system completion claim.

All fourteen profession-qualified source questions were rerun. The five
reference answers below now pass through the actual relation front door and
full default dispatcher. The other nine remain withheld. Seven wrong-role,
compound or qualified-name controls also withhold. Thus the 21 source questions
produce five correct answers and sixteen withholds, not 21 answered capabilities.

Fourteen direct kernel evidence controls pass, including wrong profession,
missing alternative closure/rows, unrelated closure identity, literal versus
entity occupation rows, and conflicting eligible locations. The first composer
positive fixture mistakenly used a P19 form explicitly dropped by that reader;
the retained diagnostic correctly declined it. The final fixtures use enabled
P20. All 39 relation unit tests and 41 prior identity checks pass.

No new theorem or native was needed. The actual unchanged native is
`bdacf372cae82d237e3cba0f3d5b95746f40d84c4d8a5fa7fb2a438653170c38`,
bound to `var/relations/native-attempts/20261018T104204Z-b3051c0bc9f0/compile-inputs.json`.
The verifier confirms current proof/runtime source consistency. The consumed
`queried_forward_answer` theorem requires the accepted candidate's exact stored
answer and query predicate, and classification coverage for every original
candidate. `query_genre_witness`, despite its historical name, is generic in the
property and supplies the exact P106 occupation/object-ancestry witness here.
English profession interpretation and source ontology meaning/completeness
remain assumptions; missing alternative evidence never creates uniqueness.

Changed files: `tools/relations/query_request.py`, `test_query_request.py`,
`profession_probes.py`, this report and project tracking. Evidence is under
`var/root-relation-professions/`; `integration.json` binds the checks and source.
Relations still depends on external stores and checkout imports. No standalone
package or new Linux-native claim is made. No jobs remain from this change.

## Historical staged proposal (superseded above)

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
