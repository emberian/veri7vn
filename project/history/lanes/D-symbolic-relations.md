# Requested subjects in inverse relation questions

Status: stable requested-subject packet, awaiting root integration. The actual
extracted checker now rejects the three examined wrong-role/gender answers and
preserves the positive stored assertions. All 161 shipped specialist panels retain
16,284 correct scores and zero wrong out of 18,976 items. These scores include
correct refusals; the positive-only panels do not establish false-positive behavior.
The six-criteria harness reports INCOMPLETE for all 322 split verdicts because
DOMAIN, FALSE YES, LANE, SELF and full BUDGET are not measured by this run.

Fresh proof: `var/request/remote-attempts/20261018T075214Z-d4f8b425d1be/receipt.json`,
on persvati, actual target Finished in 6 seconds, five scanned theorem roots and
zero oracles. The first actual proof `a15e5f3107d7` failed in 12 seconds because an
existing inverse-direction fact was omitted from a simplification. The repair
supplies it; the theorem statement is unchanged. No failed export was consumed.

Final native: `var/relations/native-attempts/20261018T080229Z-bb8df9b37229/compile-inputs.json`,
SHA-256 `3338287ef3923be34906081cb3c8451f50cb0be6d99c2136f12c31aa57299413`.
The shared compiler froze the actual generated ML and driver and validated the
passed proof dependency closure. The scratch candidate and published executable
have identical hashes. The adapter checks the kernel's requested-scope version;
older kernels refuse inverse questions while retaining forward behavior.

Checks on this executable:

- 10 raw-evidence kernel cases and 12 actual-source questions: 22/22, including
  Dublin → Ireland and Riga → Latvia, role/gender refusals, missing coverage flags,
  missing scope, overflow and multiple qualifying actors.
  `var/symbolic/relations-d/checked-request-probes.json`.
- Actual dispatcher with a competing computing family: 12/12 in head order and
  12/12 in front order, including terminal inverse refusals.
  `var/symbolic/relations-d/dispatcher-probes.json`.
- Existing general adapter positives 6/6, negative abstentions 20/20, zero errors;
  13 narrow merge/recognition unit tests pass.
- Both shipped splits of all 161 IDs, through their own scorers:
  `var/symbolic/relations-d/panels/`. No score changes from the preceding kernel.

`requested_inverse_answer` states that an actual inverse answer comes from an
original fetched subject that satisfies both the specialist domain and the typed
requested-subject constraint, with its stored row pointing to the top target's
label. `requested_forward_unchanged` proves equality with the existing decision
for entirely forward attempts. The occupation/property witness lemmas expose the
exact supplied class closure/property row used. None proves the recognizer,
ontology, source truth, fetch completeness, all-target identity, or omission-free
querying. The next all-target model below remains active work.

## Concrete defects and current boundary

The preceding general adapter answered Pierre Curie to both an actor question and a
king question about Marie Curie's spouse. It answered John Lennon to a woman question
about Yoko Ono's spouse. The requested subject kind is absent from the old decision.
The implemented constraint checks class/occupation closure or exact property rows;
name-based gender guesses are not used. The current store lacks P21 rows for the
examined people, so the gender-specific questions remain unanswered.

The actual extracted checker rejects those three wrong answers and preserves John Lennon for the
actor question, Beyoncé for the singer married to Jay-Z, Mel Ferrer for the actor
married to Audrey Hepburn, and Pierre Curie for the unqualified person question.
These are stored relation assertions, not claims about present marital status.

The old inverse fetch queried only eight subjects of the top linked target.
Dublin has ten actual subjects and only one current country (Ireland); the larger
limit 256 with LIMIT 257 overflow detection reaches that row. Euro has 111
subjects and 28 current countries, so still cannot answer a singular-country
question. The top-linked-target restriction remains until the follow-through below.
Forward values still project entity objects to display labels. Alias completeness,
closure correctness, factual truth and temporal interpretation remain unproved.

## Follow-through on target identity

A source audit of twenty common names found five with different spouse pools
for distinct linked target IDs. John Williams Q131285 has Barbara Ruick as a
stored spouse subject; John Williams Q370293 has Sue Cook. John Smith and William
Morris likewise expose different subjects for different linked identities.
Receipt: `var/symbolic/relations-d/target-ambiguities.json`.

An all-target prototype now queries every supplied target ID and retains entity
IDs in the subjects' raw relation rows. It exposes another necessary boundary:
Teio Q75463865 is human and holds a spouse edge to John Adams Q453382, but has no
occupation rows. A union of the existing specialist domains would silently omit
her and answer Abigail Adams for the popular John Adams. Thus checking each
specialist pool alone is insufficient for a general person request. The next
checked model needs uniqueness across every supplied subject satisfying the
requested kind before specialist ownership can authorize an answer. It must also
preserve the current-country exclusion of dissolved states when checking capital
questions. These are active implementation requirements, not solved by the
current requested-subject theorem. The untrusted prototype is recorded in
`var/symbolic/relations-d/all-targets-prototype.json`.

Separately, exact object/label row inspection on the first six own panel rows of
every specialist covered 965 distinct entity/property pairs. It found no same-label
multiple-object collision in that bounded sample; this does not establish that
label projection is injective. Receipt: `var/symbolic/relations-d/object-label-audit.json`.

## Per-specialist examination ledger

Each row identifies the actual reader configuration and the bounded current review.
A shared implementation does not establish that all of its readers' questions mean
what the underlying property says. Rows marked unexamined remain work, not green status.
The prototype receipt is `var/symbolic/relations-d/scoped-prototype.json`.

| Specialist | Source domain | Reader properties | Current examination |
| --- | --- | --- | --- |
| `rel-actors` | `actors` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype changed Which woman is married to Yoko Ono? answer→silent |
| `rel-aircraft` | `aircraft` | P176, P287 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-airlines` | `airlines` | P112, P159, P571, P17 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-airports` | `airports` | P931, P17 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-albums` | `albums` | P175, P577, P264 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-animators` | `animators` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-anime` | `anime` | P449, P170 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-architects` | `architects` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-asteroids` | `asteroids` | P61, P575 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-astronauts` | `astronauts` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-astronomers` | `astronomers` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-athletes` | `athletes` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-awards` | `awards` | P1027 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-ballets` | `ballets` | P86 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-bands` | `bands` | P571, P495 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-baseball` | `baseball` | P19, P20, P569, P570, P27, P26, P22, P25, P413 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-basketball` | `basketball` | P19, P20, P569, P570, P27, P26, P22, P25, P413 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-battles` | `battles` | P585, P361, P17 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-biathletes` | `biathletes` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-biologists` | `biologists` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-bloggers` | `bloggers` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-boxers` | `boxers` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-brands` | `brands` | P749, P17, P571, P112 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-breeds` | `breeds` | P495 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-bridges` | `bridges` | P177, P84, P1619, P17 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-business` | `business` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-carbrands` | `carbrands` | P749, P17, P112, P571 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-carmodels` | `carmodels` | P176 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-castles` | `castles` | P17, P571 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-channels` | `channels` | P571, P17, P749, P159 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-characters` | `characters` | P170, P1080 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-chefs` | `chefs` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-chemists` | `chemists` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype changed Which actor is married to Marie Curie? answer→silent; Which king was married to Marie Curie? answer→silent |
| `rel-chess` | `chess` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-churches` | `churches` | P84, P17 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-comedians` | `comedians` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-comics` | `comics` | P170, P123, P50 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-companies` | `companies` | P112, P159, P571, P17, P749 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-composers` | `composers` | P19, P20, P569, P570, P27, P26, P22, P25, P1303 | Prototype changed Which actor is married to Yoko Ono? silent→answer; Which actress is married to John Lennon? answer→silent |
| `rel-compounds` | `compounds` | P61, P575 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-computerscientists` | `computerscientists` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-countries-v2` | `countries2` | P36, P38, P37, P30, P1082, P85, P610 | Prototype examined 2 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-cricketers` | `cricketers` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-criminals` | `criminals` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-crosscountry` | `crosscountry` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-curlers` | `curlers` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-cyclists` | `cyclists` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-dancers` | `dancers` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-diplomats` | `diplomats` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-directors` | `directors` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-diseases` | `diseases` | P828 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-dishes` | `dishes` | P495 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-drivers` | `drivers` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-economists` | `economists` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-editors` | `editors` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-engineers` | `engineers` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-equestrians` | `equestrians` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-explorers` | `explorers` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-fencers` | `fencers` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-fieldhockey` | `fieldhockey` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-films-v2` | `films` | P57, P58, P86, P577, P144, P840, P156 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-footballclubs` | `footballclubs` | P115, P118, P571 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-footballers` | `footballers` | P19, P20, P569, P570, P27, P26, P22, P25, P413, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-galaxies` | `galaxies` | P59, P61, P575 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-genres` | `genres` | P495 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-geologists` | `geologists` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-golfers` | `golfers` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-graphicartists` | `graphicartists` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype changed Which actor is married to Yoko Ono? silent→answer |
| `rel-gridiron` | `gridiron` | P19, P20, P569, P570, P27, P26, P22, P25, P413 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-gymnasts` | `gymnasts` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-handball` | `handball` | P19, P20, P569, P570, P27, P26, P22, P25, P413 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-historians` | `historians` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-hotels` | `hotels` | P84, P1619 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-icehockey` | `icehockey` | P19, P20, P569, P570, P27, P26, P22, P25, P413 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-illustrators` | `illustrators` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-instruments` | `instruments` | P61, P495 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-islands` | `islands` | P17, P36, P610 | Prototype examined 1 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-journalists` | `journalists` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype changed Which actress is married to John Lennon? answer→silent |
| `rel-lakes` | `lakes` | P17 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-languages` | `languages` | P282 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-lawyers` | `lawyers` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-leagues` | `leagues` | P17, P571 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-libraries` | `libraries` | P17, P571, P84 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-linguists` | `linguists` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-mathematicians` | `mathematicians` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-military` | `military` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-militaryunits` | `militaryunits` | P571, P17 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-missionaries` | `missionaries` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-models` | `models` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-monarchs` | `monarchs` | P19, P20, P569, P570, P27, P26, P22, P25, P53, P1366, P1365, P140 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-monuments` | `monuments` | P84, P17, P571 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-moons` | `moons` | P397, P61, P575 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-mountains` | `mountains` | P17, P4552 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-museums` | `museums` | P84, P571, P17 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-musicians` | `musicians` | P19, P20, P569, P570, P27, P26, P22, P25, P1303, P463 | Prototype changed Which actor is married to Yoko Ono? silent→answer; Which actress is married to John Lennon? answer→silent |
| `rel-mythology` | `mythology` | P22, P25, P26 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-newspapers` | `newspapers` | P123, P291, P571, P112 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-novelists` | `novelists` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-novels` | `novels` | P50, P577, P840, P156, P144 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-nurses` | `nurses` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-observatories` | `observatories` | P17, P571 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-operas` | `operas` | P86, P87 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-organisations` | `organisations` | P571, P112, P159 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-painters` | `painters` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype changed Which actress is married to John Lennon? answer→silent |
| `rel-paintings` | `paintings` | P170, P195 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-parks` | `parks` | P17 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-parties` | `parties` | P571, P112, P17 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-pharmacists` | `pharmacists` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-philosophers` | `philosophers` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype changed Which woman is married to Yoko Ono? answer→silent; Which actress is married to John Lennon? answer→silent |
| `rel-photographers` | `photographers` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype changed Which actress is married to John Lennon? answer→silent |
| `rel-physicians` | `physicians` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype changed Which actor is married to Audrey Hepburn? answer→silent |
| `rel-physicists` | `physicists` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype changed Which actor is married to Marie Curie? answer→silent; Which king was married to Marie Curie? answer→silent |
| `rel-planets` | `planets` | P61, P575 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-playwrights` | `playwrights` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-poems` | `poems` | P50 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-poets` | `poets` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype changed Which woman is married to Yoko Ono? answer→silent |
| `rel-police` | `police` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-politicians` | `politicians` | P19, P20, P569, P570, P27, P26, P22, P25, P102 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-printmakers` | `printmakers` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-psychologists` | `psychologists` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-racketsports` | `racketsports` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-religions` | `religions` | P112, P571 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-rivers` | `rivers` | P403, P885 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-rowers` | `rowers` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-rugby` | `rugby` | P19, P20, P569, P570, P27, P26, P22, P25, P413 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-sculptors` | `sculptors` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype changed Which actress is married to John Lennon? answer→silent |
| `rel-sculptures` | `sculptures` | P170, P195 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-ships` | `ships` | P176 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-shooters` | `shooters` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-singers` | `singers` | P19, P20, P569, P570, P27, P26, P22, P25, P1303, P463 | Prototype changed Which woman is married to Yoko Ono? answer→silent; Which actress is married to John Lennon? answer→silent |
| `rel-skaters` | `skaters` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-skiers` | `skiers` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-skyscrapers` | `skyscrapers` | P84, P1619, P17 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-snooker` | `snooker` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-software` | `software` | P178, P287, P571 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-songs` | `songs` | P175, P86, P676, P577 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-spacecraft` | `spacecraft` | P176 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-speedskaters` | `speedskaters` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-spies` | `spies` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-sportsevents` | `sportsevents` | P1346, P276, P17 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-sportsteams` | `sportsteams` | P115, P118, P571 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-stadiums` | `stadiums` | P1619, P17, P84 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-stations` | `stations` | P17, P1619 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-statisticians` | `statisticians` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-swimmers` | `swimmers` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-temples` | `temples` | P17, P84, P571 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-tennis` | `tennis` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-theatres` | `theatres` | P84, P1619, P17 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-themeparks` | `themeparks` | P1619 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-theologians` | `theologians` | P19, P20, P569, P570, P27, P26, P22, P25, P1366, P1365 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-tradeunionists` | `tradeunionists` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-translators` | `translators` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-triathletes` | `triathletes` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-tvproducers` | `tvproducers` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-tvseries-v2` | `tvseries` | P170, P449, P580, P582, P840, P144 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-universities` | `universities` | P571, P112, P17 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-videogames` | `videogames` | P178, P123, P577 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-volleyball` | `volleyball` | P19, P20, P569, P570, P27, P26, P22, P25, P413 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-wars` | `wars` | P580, P582 | Forward-only reader configuration inspected; independent question/attribute semantics not yet reviewed. Shipped positive panels are not that review. |
| `rel-waterpolo` | `waterpolo` | P19, P20, P569, P570, P27, P26, P22, P25, P1532 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
| `rel-youtubers` | `youtubers` | P19, P20, P569, P570, P27, P26, P22, P25 | Prototype examined 8 matching inverse questions; no outcome change in this specialist. Its domain/property meanings need independent examination. |
