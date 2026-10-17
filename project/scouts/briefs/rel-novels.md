Prototype a verified relation reader for ONE of Oracle7's 161 `rel-*` specialists: `rel-novels`
(`upstream/root/specialists/rel-novels/`, class RelationOrganV2). The shipped reader needs
`names_v1.sqlite3` and `relations_v2.sqlite3`, which never shipped; only `relations_v1.sqlite3`
(schema: entity(qid,label,enwiki), fact(s,p,o,lit)) is available. Lane F already proved the exact
router's decision over fetched rows (`src/isabelle/reader/Relation_Reader.thy`, `tools/reader/`);
reuse its shape: verified decision over rows, untrusted sqlite fetch asserting completeness.

A previous scout attempt in THIS worktree already found: the shipped organ over relations_v1 plus a
norm-index stand-in for the missing linker scores 84/120 panel items right, 0 wrong, 36 withheld
because property P144 is absent from the v1 store altogether (see the committed probe under
`tools/reader-novels/`: build_norm_index.py, probe.py, probe_port.py, and the uncommitted draft
`src/extract/rel-novels/Novel_Reader.thy`). It ran out of context before writing its report.
Start by writing SCOUT_REPORT.md from what is already here (commit it immediately), then continue:
finish the HOL decision theory, build it remotely (`tools/dev/remote-build hbox src/extract/rel-novels <Session> --expect '<MARKER>'`),
wire an answerer, score with the harness, and update the report. Keep your context small: grep
before reading, read files in parts, never print whole panels. Commit often.
