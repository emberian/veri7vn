# The relation ceiling: what any reader can reach over the shipped store

Oracle7 answers relation questions through 161 `rel-*` specialists, all one organ class
(RelationOrganV2, plus RelationOrganV2G = the same with a pronoun guard): a domain plus
hand-written reader phrasings per Wikidata property, plus for 23 of them mined patterns.
The shipped runtime read `relations_v2.sqlite3` and `names_v1.sqlite3`; neither is in the
drop. Only `relations_v1.sqlite3` is (47,999,065 facts over 98 properties). This table is
the ceiling that facts place on ANY reader of the shipped store - verified or not -
computed by `tools/rel-census/census.py` (read-only, one `GROUP BY p` census plus per-item
checks: panel entity present in the store, in the organ's domain, and a single stored
value for the panel's property).

## Headlines

- 161 specialists, 18976 panel items (all valid; every item is a FORWARD question - the
  inverse readers are never exercised by any shipped panel).
- 1814 items (9.6%) sit on 30 properties that have NO row anywhere in the shipped store:
  no reader over `relations_v1` can answer them, ever. The ceiling is 17162/18976 (90.4%).
- On every remaining item the panel entity exists, is in the organ's domain, and has
  exactly one stored value for the asked property, so the facts do not limit them. What
  does is the shipped decision and the linker: lane W5-02 (`project/lanes/W5-02-relations.md`)
  classifies its 878 withheld present-property items as dropped phrasings, agreement
  refusals, restating values and linker misses. This table does not model those rules.
- The shipped verdicts (measured over the never-shipped v2 store + names index) stand at
  17920 right / 21 wrong / 0 false-yes - above the v1 ceiling by 758 items, so at least
  that many of their right answers are on the absent properties.
- 52 of the 161 organ domains are in NEITHER shipped domains file
  (`relation_domains_v1.json` has 99 ids, `relation_domains_v2.json` 125; the release root
  had more). As dropped, those organs die on a KeyError and answer nothing; their domain
  is recoverable from each manifest's own `domain.roots`/`occupations`, which this census uses.

## The absent properties (all 30, by panel items lost)

| Property | Label | Items | Specialists (of 161) |
|---|---|---|---|
| P1532 | sports nationality | 574 | 25 |
| P1619 | opening date | 168 | 7 |
| P413 | speciality | 149 | 8 |
| P575 | time of invention | 116 | 5 |
| P144 | themed after | 72 | 3 |
| P115 | venue | 48 | 2 |
| P195 | series | 48 | 2 |
| P287 | has designer | 48 | 2 |
| P580 | validity | 48 | 2 |
| P582 | until | 48 | 2 |
| P610 | zenith | 48 | 2 |
| P1366 | territory split into | 33 | 2 |
| P1365 | supersedes | 28 | 2 |
| P53 | royal house | 24 | 1 |
| P59 | part of constellation | 24 | 1 |
| P85 | team anthem | 24 | 1 |
| P87 | libretto by | 24 | 1 |
| P102 | political party member | 24 | 1 |
| P177 | under | 24 | 1 |
| P282 | written form | 24 | 1 |
| P291 | where published | 24 | 1 |
| P397 | star | 24 | 1 |
| P403 | watercourse outflow | 24 | 1 |
| P828 | why | 24 | 1 |
| P885 | water source | 24 | 1 |
| P931 | train station serves | 24 | 1 |
| P1080 | universe | 24 | 1 |
| P1346 | won by | 24 | 1 |
| P4552 | system of mountains | 24 | 1 |
| P585 | year | 2 | 1 |

## Per-specialist ceiling

Columns: **panel** = items in `relation_panel_v2.json` (dev + heldout, all valid);
**absent** = items on properties with no row in the shipped store (the unanswerable);
**ceiling** = panel - absent; **shipped** = the release verdict's `domain.spec` right
count over the v2 store (dev + heldout; wrong in brackets when nonzero);
**dom\*** = the domain id is in neither shipped domains file (manifest fallback).

| Specialist | Domain | Readers | Panel | Absent (properties) | Ceiling v1 | Shipped v2 |
|---|---|---|---|---|---|---|
| rel-actors | actors | 8 | 192 | 0 | 192 | 167 |
| rel-aircraft | aircraft | 2 | 48 | 24 (P287) | 24 | 36 |
| rel-airlines | airlines | 4 | 94 | 0 | 94 | 84 |
| rel-airports | airports | 2 | 48 | 24 (P931) | 24 | 36 |
| rel-albums | albums | 3 | 72 | 0 | 72 | 56 [1 wrong] |
| rel-animators | animators* | 8 | 140 | 0 | 140 | 140 |
| rel-anime | anime* | 2 | 47 | 0 | 47 | 45 |
| rel-architects | architects | 8 | 184 | 0 | 184 | 181 |
| rel-asteroids | asteroids | 2 | 48 | 24 (P575) | 24 | 48 |
| rel-astronauts | astronauts | 8 | 192 | 0 | 192 | 192 |
| rel-astronomers | astronomers | 8 | 192 | 0 | 192 | 188 [1 wrong] |
| rel-athletes | athletes | 9 | 216 | 24 (P1532) | 192 | 209 |
| rel-awards | awards | 1 | 24 | 0 | 24 | 21 |
| rel-ballets | ballets | 1 | 21 | 0 | 21 | 17 |
| rel-bands | bands | 2 | 48 | 0 | 48 | 45 |
| rel-baseball | baseball | 9 | 101 | 4 (P413) | 97 | 101 |
| rel-basketball | basketball | 9 | 215 | 24 (P413) | 191 | 211 |
| rel-battles | battles | 3 | 47 | 2 (P585) | 45 | 33 |
| rel-biathletes | biathletes* | 9 | 112 | 24 (P1532) | 88 | 111 |
| rel-biologists | biologists | 8 | 192 | 0 | 192 | 187 |
| rel-bloggers | bloggers* | 8 | 153 | 0 | 153 | 151 |
| rel-boxers | boxers | 8 | 192 | 0 | 192 | 187 [1 wrong] |
| rel-brands | brands* | 4 | 96 | 0 | 96 | 84 |
| rel-breeds | breeds | 1 | 24 | 0 | 24 | 24 |
| rel-bridges | bridges | 4 | 85 | 48 (P177,P1619) | 37 | 76 |
| rel-business | business | 8 | 192 | 0 | 192 | 178 |
| rel-carbrands | carbrands | 4 | 64 | 0 | 64 | 53 |
| rel-carmodels | carmodels | 1 | 24 | 0 | 24 | 14 |
| rel-castles | castles | 2 | 48 | 0 | 48 | 48 |
| rel-channels | channels* | 4 | 77 | 0 | 77 | 63 |
| rel-characters | characters | 2 | 48 | 24 (P1080) | 24 | 42 |
| rel-chefs | chefs | 8 | 33 | 0 | 33 | 33 |
| rel-chemists | chemists | 8 | 192 | 0 | 192 | 192 |
| rel-chess | chess | 9 | 191 | 24 (P1532) | 167 | 186 |
| rel-churches | churches | 2 | 31 | 0 | 31 | 26 [1 wrong] |
| rel-comedians | comedians | 8 | 192 | 0 | 192 | 192 |
| rel-comics | comics | 3 | 66 | 0 | 66 | 61 |
| rel-companies | companies | 5 | 120 | 0 | 120 | 108 |
| rel-composers | composers | 9 | 216 | 0 | 216 | 188 [1 wrong] |
| rel-compounds | compounds | 2 | 44 | 20 (P575) | 24 | 42 |
| rel-computerscientists | computerscientists* | 8 | 180 | 0 | 180 | 180 |
| rel-countries-v2 | countries2 | 7 | 168 | 48 (P85,P610) | 120 | 155 |
| rel-cricketers | cricketers | 9 | 128 | 20 (P1532) | 108 | 124 |
| rel-criminals | criminals | 8 | 131 | 0 | 131 | 131 |
| rel-crosscountry | crosscountry* | 9 | 137 | 24 (P1532) | 113 | 136 |
| rel-curlers | curlers* | 9 | 52 | 15 (P1532) | 37 | 52 |
| rel-cyclists | cyclists | 9 | 211 | 24 (P1532) | 187 | 209 |
| rel-dancers | dancers | 8 | 192 | 0 | 192 | 191 |
| rel-diplomats | diplomats | 8 | 192 | 0 | 192 | 184 |
| rel-directors | directors | 8 | 192 | 0 | 192 | 177 |
| rel-diseases | diseases | 1 | 24 | 24 (P828) | 0 | 24 |
| rel-dishes | dishes | 1 | 24 | 0 | 24 | 24 |
| rel-drivers | drivers | 9 | 201 | 24 (P1532) | 177 | 200 |
| rel-economists | economists | 8 | 192 | 0 | 192 | 189 |
| rel-editors | editors* | 8 | 163 | 0 | 163 | 160 |
| rel-engineers | engineers | 8 | 192 | 0 | 192 | 188 |
| rel-equestrians | equestrians* | 9 | 75 | 16 (P1532) | 59 | 75 |
| rel-explorers | explorers | 8 | 180 | 0 | 180 | 178 |
| rel-fencers | fencers* | 9 | 182 | 24 (P1532) | 158 | 178 |
| rel-fieldhockey | fieldhockey* | 9 | 56 | 24 (P1532) | 32 | 56 |
| rel-films-v2 | films | 7 | 168 | 24 (P144) | 144 | 103 [1 wrong] |
| rel-footballclubs | footballclubs | 3 | 72 | 24 (P115) | 48 | 70 |
| rel-footballers | footballers | 10 | 240 | 48 (P413,P1532) | 192 | 223 |
| rel-galaxies | galaxies* | 3 | 72 | 48 (P59,P575) | 24 | 70 |
| rel-genres | genres | 1 | 24 | 0 | 24 | 23 |
| rel-geologists | geologists* | 8 | 184 | 0 | 184 | 184 |
| rel-golfers | golfers | 9 | 78 | 24 (P1532) | 54 | 77 |
| rel-graphicartists | graphicartists* | 8 | 192 | 0 | 192 | 189 |
| rel-gridiron | gridiron* | 9 | 91 | 15 (P413) | 76 | 88 |
| rel-gymnasts | gymnasts* | 9 | 159 | 24 (P1532) | 135 | 159 |
| rel-handball | handball* | 9 | 149 | 24 (P413) | 125 | 147 |
| rel-historians | historians | 8 | 192 | 0 | 192 | 188 |
| rel-hotels | hotels* | 2 | 48 | 24 (P1619) | 24 | 40 |
| rel-icehockey | icehockey | 9 | 192 | 12 (P413) | 180 | 188 |
| rel-illustrators | illustrators* | 8 | 192 | 0 | 192 | 187 |
| rel-instruments | instruments | 2 | 30 | 0 | 30 | 30 |
| rel-islands | islands | 3 | 72 | 24 (P610) | 48 | 60 |
| rel-journalists | journalists | 8 | 192 | 0 | 192 | 192 |
| rel-lakes | lakes | 1 | 24 | 0 | 24 | 24 |
| rel-languages | languages | 1 | 24 | 24 (P282) | 0 | 22 |
| rel-lawyers | lawyers | 8 | 192 | 0 | 192 | 189 |
| rel-leagues | leagues* | 2 | 39 | 0 | 39 | 31 |
| rel-libraries | libraries* | 3 | 44 | 0 | 44 | 43 |
| rel-linguists | linguists | 8 | 192 | 0 | 192 | 189 |
| rel-mathematicians | mathematicians | 8 | 191 | 0 | 191 | 191 |
| rel-military | military | 8 | 192 | 0 | 192 | 163 |
| rel-militaryunits | militaryunits* | 2 | 31 | 0 | 31 | 27 |
| rel-missionaries | missionaries* | 8 | 151 | 0 | 151 | 149 [1 wrong] |
| rel-models | models | 8 | 192 | 0 | 192 | 191 |
| rel-monarchs | monarchs | 12 | 288 | 72 (P53,P1365,P1366) | 216 | 224 [1 wrong] |
| rel-monuments | monuments* | 3 | 57 | 0 | 57 | 54 |
| rel-moons | moons | 3 | 72 | 48 (P397,P575) | 24 | 69 [1 wrong] |
| rel-mountains | mountains | 2 | 48 | 24 (P4552) | 24 | 38 |
| rel-museums | museums | 3 | 70 | 0 | 70 | 67 |
| rel-musicians | musicians | 10 | 240 | 0 | 240 | 211 |
| rel-mythology | mythology | 3 | 72 | 0 | 72 | 57 [1 wrong] |
| rel-newspapers | newspapers | 4 | 96 | 24 (P291) | 72 | 72 [1 wrong] |
| rel-novelists | novelists | 8 | 192 | 0 | 192 | 179 |
| rel-novels | novels | 5 | 120 | 24 (P144) | 96 | 104 |
| rel-nurses | nurses* | 8 | 123 | 0 | 123 | 111 |
| rel-observatories | observatories* | 2 | 32 | 0 | 32 | 31 |
| rel-operas | operas | 2 | 48 | 24 (P87) | 24 | 42 [1 wrong] |
| rel-organisations | organisations | 3 | 72 | 0 | 72 | 65 |
| rel-painters | painters | 8 | 192 | 0 | 192 | 188 |
| rel-paintings | paintings | 2 | 48 | 24 (P195) | 24 | 28 |
| rel-parks | parks | 1 | 24 | 0 | 24 | 24 |
| rel-parties | parties | 3 | 65 | 0 | 65 | 50 |
| rel-pharmacists | pharmacists* | 8 | 115 | 0 | 115 | 115 |
| rel-philosophers | philosophers | 8 | 192 | 0 | 192 | 177 |
| rel-photographers | photographers | 8 | 192 | 0 | 192 | 189 |
| rel-physicians | physicians | 8 | 192 | 0 | 192 | 178 |
| rel-physicists | physicists | 8 | 192 | 0 | 192 | 190 |
| rel-planets | planets | 2 | 48 | 24 (P575) | 24 | 48 |
| rel-playwrights | playwrights | 8 | 192 | 0 | 192 | 178 |
| rel-poems | poems | 1 | 24 | 0 | 24 | 24 |
| rel-poets | poets | 8 | 192 | 0 | 192 | 167 |
| rel-police | police* | 8 | 76 | 0 | 76 | 75 [1 wrong] |
| rel-politicians | politicians | 9 | 216 | 24 (P102) | 192 | 192 [1 wrong] |
| rel-printmakers | printmakers* | 8 | 174 | 0 | 174 | 172 |
| rel-psychologists | psychologists | 8 | 172 | 0 | 172 | 171 |
| rel-racketsports | racketsports* | 9 | 108 | 24 (P1532) | 84 | 108 |
| rel-religions | religions | 2 | 39 | 0 | 39 | 39 |
| rel-rivers | rivers | 2 | 48 | 48 (P403,P885) | 0 | 43 |
| rel-rowers | rowers* | 9 | 205 | 24 (P1532) | 181 | 202 [2 wrong] |
| rel-rugby | rugby | 9 | 78 | 22 (P413) | 56 | 77 |
| rel-sculptors | sculptors | 8 | 181 | 0 | 181 | 169 |
| rel-sculptures | sculptures | 2 | 48 | 24 (P195) | 24 | 47 |
| rel-ships | ships | 1 | 24 | 0 | 24 | 18 |
| rel-shooters | shooters* | 9 | 96 | 24 (P1532) | 72 | 95 |
| rel-singers | singers | 10 | 240 | 0 | 240 | 222 |
| rel-skaters | skaters* | 9 | 147 | 24 (P1532) | 123 | 144 |
| rel-skiers | skiers* | 9 | 173 | 24 (P1532) | 149 | 171 |
| rel-skyscrapers | skyscrapers | 3 | 70 | 24 (P1619) | 46 | 61 |
| rel-snooker | snooker* | 9 | 30 | 24 (P1532) | 6 | 30 |
| rel-software | software | 3 | 72 | 24 (P287) | 48 | 60 |
| rel-songs | songs | 4 | 96 | 0 | 96 | 74 [1 wrong] |
| rel-spacecraft | spacecraft* | 1 | 24 | 0 | 24 | 17 [1 wrong] |
| rel-speedskaters | speedskaters* | 9 | 142 | 24 (P1532) | 118 | 142 |
| rel-spies | spies* | 8 | 123 | 0 | 123 | 121 |
| rel-sportsevents | sportsevents | 3 | 72 | 24 (P1346) | 48 | 72 |
| rel-sportsteams | sportsteams | 3 | 72 | 24 (P115) | 48 | 69 |
| rel-stadiums | stadiums | 3 | 72 | 24 (P1619) | 48 | 67 |
| rel-stations | stations* | 2 | 48 | 24 (P1619) | 24 | 44 |
| rel-statisticians | statisticians* | 8 | 123 | 0 | 123 | 120 |
| rel-swimmers | swimmers | 9 | 216 | 24 (P1532) | 192 | 215 |
| rel-temples | temples* | 3 | 72 | 0 | 72 | 68 |
| rel-tennis | tennis | 9 | 215 | 24 (P1532) | 191 | 215 |
| rel-theatres | theatres* | 3 | 50 | 24 (P1619) | 26 | 44 |
| rel-themeparks | themeparks* | 1 | 24 | 24 (P1619) | 0 | 24 |
| rel-theologians | theologians | 10 | 201 | 13 (P1365,P1366) | 188 | 197 [2 wrong] |
| rel-tradeunionists | tradeunionists* | 8 | 140 | 0 | 140 | 140 |
| rel-translators | translators* | 8 | 192 | 0 | 192 | 190 |
| rel-triathletes | triathletes* | 9 | 30 | 19 (P1532) | 11 | 30 |
| rel-tvproducers | tvproducers* | 8 | 186 | 0 | 186 | 184 |
| rel-tvseries-v2 | tvseries | 6 | 144 | 72 (P144,P580,P582) | 72 | 116 [1 wrong] |
| rel-universities | universities | 3 | 72 | 0 | 72 | 70 |
| rel-videogames | videogames | 3 | 72 | 0 | 72 | 54 |
| rel-volleyball | volleyball* | 9 | 119 | 24 (P413) | 95 | 119 |
| rel-wars | wars | 2 | 48 | 48 (P580,P582) | 0 | 34 |
| rel-waterpolo | waterpolo* | 9 | 98 | 24 (P1532) | 74 | 98 |
| rel-youtubers | youtubers* | 8 | 118 | 0 | 118 | 116 |

Generated by `tools/rel-census/census.py`; machine-readable detail in
`var/rel-census/census.json` (not committed). Store: `relations_v1.sqlite3` read-only.
