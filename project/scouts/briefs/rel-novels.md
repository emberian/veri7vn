Prototype a verified relation reader for ONE of Oracle7's 161 `rel-*` specialists: `rel-novels`
(`upstream/root/specialists/rel-novels/`, class RelationOrganV2). The shipped reader needs
`names_v1.sqlite3` and `relations_v2.sqlite3`, which never shipped; only `relations_v1.sqlite3`
(schema: entity(qid,label,enwiki), fact(s,p,o,lit)) is available. Lane F already proved the exact
router's decision over fetched rows (`src/isabelle/reader/Relation_Reader.thy`, `tools/reader/`);
reuse its shape: verified decision over rows, untrusted sqlite fetch asserting completeness.
Find out what rel-novels actually asks (its manifest, panel, scorer, the properties it reads),
build the smallest prototype that answers its panel from the v1 store, score it with the harness,
and report what the v1 store can and cannot serve, so root can decide whether the 161 readers are
one lane or blocked for good.
